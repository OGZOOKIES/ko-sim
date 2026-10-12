-- Loads, holds and saves every player's data.
--
-- Safety rules:
--   * Data is read and written with UpdateAsync only.
--   * A session lock (data.Lock) stops two servers editing the same player at once. If another
--     server holds a fresh lock we wait and retry; after the last retry we take the lock over.
--   * If loading fails, the player is kicked and nothing is ever saved for them, so defaults can
--     never overwrite real progress.
--   * In Studio without API access, the player gets fresh data that is never saved ("offline").
--
-- API for other services:
--   PlayerDataService.Get(player) -> data | nil      (nil while loading)
--   PlayerDataService.MarkChanged(player)             (call after changing data; sends it to the client)
--   PlayerDataService.ProfileLoaded:Connect(function(player, data) end)
--   PlayerDataService.DataChanged:Connect(function(player, data) end)   (after each client update)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Utilities.Format)
local Log = require(Shared.Utilities.Log)
local Types = require(Shared.Types)
local DataTemplate = require(ServerScriptService.Logic.DataTemplate)
local Net = require(ServerScriptService.Net)

type PlayerData = Types.PlayerData

type Profile = {
	Data: PlayerData,
	CanSave: boolean,
	Dirty: boolean,
	Released: boolean,
}

local log = Log.new("PlayerData")

local LOAD_ATTEMPTS = 6
local LOCK_RETRY_SECONDS = 4
local LOCK_TIMEOUT_SECONDS = 180
local SAVE_ATTEMPTS = 3
local PUSH_INTERVAL = 0.15

local PlayerDataService = {}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil

local loadedEvent = Instance.new("BindableEvent")
PlayerDataService.ProfileLoaded = loadedEvent.Event

local changedEvent = Instance.new("BindableEvent")
PlayerDataService.DataChanged = changedEvent.Event

local function keyFor(userId: number): string
	return `Player_{userId}`
end

local function isStudioAccessError(message: any): boolean
	local text = tostring(message)
	return string.find(text, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(text, "publish", 1, true) ~= nil
		or string.find(text, "403", 1, true) ~= nil
end

local function lockIsHeldElsewhere(old: any): boolean
	return type(old) == "table" and type(old.Lock) == "table" and old.Lock.JobId ~= game.JobId
end

-- Returns "Ok" with the raw saved data, "Offline" (Studio without API access) or "Failed".
local function loadData(player: Player): (string, any)
	local dataStore = store
	if not dataStore then
		return if RunService:IsStudio() then "Offline" else "Failed", nil
	end

	local key = keyFor(player.UserId)
	for attempt = 1, LOAD_ATTEMPTS do
		if not player.Parent then
			return "Failed", nil
		end

		local lockedElsewhere = false
		local ok, result = pcall(function()
			return dataStore:UpdateAsync(key, function(old)
				lockedElsewhere = false
				local now = os.time()
				-- On the last attempt we take over the lock instead of waiting forever.
				if lockIsHeldElsewhere(old) and now - (tonumber(old.Lock.Time) or 0) < LOCK_TIMEOUT_SECONDS then
					if attempt < LOAD_ATTEMPTS then
						lockedElsewhere = true
						return nil
					end
				end
				local data = if type(old) == "table" then old else DataTemplate.New()
				data.Lock = { JobId = game.JobId, Time = now }
				return data
			end)
		end)

		if ok and not lockedElsewhere and type(result) == "table" then
			return "Ok", result
		end
		if not ok then
			log.warn(`Load attempt {attempt} failed for {player.Name}:`, result)
			if RunService:IsStudio() and isStudioAccessError(result) then
				return "Offline", nil
			end
		elseif lockedElsewhere then
			log.info(`{player.Name}'s data is open on another server, waiting...`)
		end
		if attempt < LOAD_ATTEMPTS then
			task.wait(if lockedElsewhere then LOCK_RETRY_SECONDS else attempt * 2)
		end
	end
	return "Failed", nil
end

-- Writes data back. With release = true the session lock is removed.
local function saveData(userId: number, profile: Profile, release: boolean): boolean
	local dataStore = store
	if not profile.CanSave or not dataStore then
		return true
	end

	local data = profile.Data
	local key = keyFor(userId)
	for attempt = 1, SAVE_ATTEMPTS do
		local lostLock = false
		local ok, err = pcall(function()
			dataStore:UpdateAsync(key, function(old)
				lostLock = false
				if lockIsHeldElsewhere(old) then
					lostLock = true
					return nil
				end
				-- An autosave that finishes after the player left must not re-take the lock.
				if not release and profile.Released then
					return nil
				end
				data.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
				return data
			end)
		end)
		if ok then
			if lostLock then
				-- Another server took over this player. Its copy is newer, so stop saving ours.
				log.warn(`Lost the session lock for user {userId}; this server will stop saving it.`)
				profile.CanSave = false
				return false
			end
			return true
		end
		log.warn(`Save attempt {attempt} failed for user {userId}:`, err)
		if attempt < SAVE_ATTEMPTS then
			task.wait(attempt * 2)
		end
	end
	return false
end

-- The client gets everything except the session lock.
local function snapshot(data: PlayerData): { [string]: any }
	local copy = {}
	for key, value in data :: any do
		if key ~= "Lock" then
			copy[key] = value
		end
	end
	return copy
end

local function setupLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, name in { "Power", "Wins", "Rebirths" } do
		local value = Instance.new("StringValue")
		value.Name = name
		value.Value = "0"
		value.Parent = folder
	end
	folder.Parent = player
end

local function updateLeaderstats(player: Player, data: PlayerData)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		return
	end
	local power = folder:FindFirstChild("Power") :: StringValue?
	local wins = folder:FindFirstChild("Wins") :: StringValue?
	local rebirths = folder:FindFirstChild("Rebirths") :: StringValue?
	if power then
		power.Value = Format.Number(data.Power)
	end
	if wins then
		wins.Value = Format.Number(data.Wins)
	end
	if rebirths then
		rebirths.Value = Format.Number(data.RebirthCount)
	end
end

local function push(player: Player, profile: Profile)
	Net.Fire("StateUpdated", player, snapshot(profile.Data))
	updateLeaderstats(player, profile.Data)
	changedEvent:Fire(player, profile.Data)
end

local function onPlayerAdded(player: Player)
	local status, raw = loadData(player)

	if not player.Parent then
		-- Left while loading: hand the lock straight back without changing anything.
		if status == "Ok" then
			saveData(player.UserId, { Data = raw, CanSave = true, Dirty = false, Released = true }, true)
		end
		return
	end

	if status == "Failed" then
		log.warn(`Could not load data for {player.Name}; kicking so nothing gets overwritten.`)
		player:Kick("We couldn't load your data. Please rejoin in a moment - your progress is safe.")
		return
	end

	local data: PlayerData
	if status == "Ok" then
		if (tonumber(raw.Version) or 0) > DataTemplate.Version then
			player:Kick("This server is out of date. Please rejoin to get the latest version.")
			return
		end
		data = DataTemplate.Prepare(raw)
	else
		data = DataTemplate.New()
		log.warn(
			`DataStores aren't available, so {player.Name}'s progress won't be saved this session. `
				.. "In Studio: Game Settings > Security > Enable Studio Access to API Services."
		)
	end

	local profile: Profile = {
		Data = data,
		CanSave = status == "Ok",
		Dirty = true,
		Released = false,
	}
	profiles[player] = profile
	setupLeaderstats(player)
	log.info(`Loaded {player.Name} ({if profile.CanSave then "saving on" else "offline, not saving"})`)
	loadedEvent:Fire(player, data)

	if not profile.CanSave then
		Net.Notify(player, "Saving is off in this test session (Studio API access is disabled).", "Warning")
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile or profile.Released then
		return
	end
	profile.Released = true
	saveData(player.UserId, profile, true)
	if profiles[player] == profile then
		profiles[player] = nil
	end
end

function PlayerDataService.Get(player: Player): PlayerData?
	local profile = profiles[player]
	return if profile and not profile.Released then profile.Data else nil
end

function PlayerDataService.MarkChanged(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Dirty = true
	end
end

function PlayerDataService.GetSnapshot(player: Player): { [string]: any }?
	local data = PlayerDataService.Get(player)
	return if data then snapshot(data) else nil
end

function PlayerDataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end)
	if ok then
		store = result
	else
		log.warn("DataStoreService is unavailable:", result)
	end

	Net.Handle("GetState", function(player)
		local data = PlayerDataService.GetSnapshot(player)
		if not data then
			return Net.NotLoaded
		end
		return Net.Ok(nil, { data = data })
	end, { RateLimit = 2 })
end

function PlayerDataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Send changed data to clients a few times a second.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < PUSH_INTERVAL then
			return
		end
		elapsed = 0
		for player, profile in profiles do
			if profile.Dirty and not profile.Released then
				profile.Dirty = false
				push(player, profile)
			end
		end
	end)

	-- Autosave
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveInterval)
			-- Copy first: players can join or leave while we wait between saves.
			local queue = {}
			for player, profile in profiles do
				table.insert(queue, { UserId = player.UserId, Profile = profile })
			end
			for _, entry in queue do
				if not entry.Profile.Released and entry.Profile.CanSave then
					task.spawn(saveData, entry.UserId, entry.Profile, false)
					task.wait(0.5)
				end
			end
		end
	end)

	-- Save everyone before the server shuts down.
	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			if not profile.Released then
				profile.Released = true
				pending += 1
				task.spawn(function()
					saveData(player.UserId, profile, true)
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerDataService
