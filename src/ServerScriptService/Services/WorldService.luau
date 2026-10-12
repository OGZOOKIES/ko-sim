-- Builds every world when the server starts, and handles unlocking and travelling between them.
--
-- API:
--   WorldService.GetLayout(worldId) -> WorldBuilder.Layout

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local WorldsConfig = require(Shared.Config.WorldsConfig)
local Log = require(Shared.Utilities.Log)
local Economy = require(ServerScriptService.Logic.Economy)
local Net = require(ServerScriptService.Net)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local RagdollFactory = require(ServerScriptService.World.RagdollFactory)
local WorldBuilder = require(ServerScriptService.World.WorldBuilder)

local log = Log.new("World")

local WorldService = {}

local layouts: { [string]: WorldBuilder.Layout } = {}

function WorldService.GetLayout(worldId: string): WorldBuilder.Layout
	return layouts[worldId]
end

-- Sets where the player respawns and moves their character there if they have one.
local function placePlayer(player: Player, worldId: string)
	local layout = layouts[worldId]
	if not layout then
		return
	end
	player.RespawnLocation = layout.SpawnLocation
	local character = player.Character
	if character and character.Parent then
		character:PivotTo(layout.SpawnLocation.CFrame + Vector3.new(0, 4, 0))
	end
end

function WorldService.Init()
	RagdollFactory.SetupCollisionGroups()

	local folder = Instance.new("Folder")
	folder.Name = "Worlds"
	folder.Parent = workspace

	local started = os.clock()
	for _, world in WorldsConfig.List do
		local origin = Vector3.new(0, GameConfig.WorldBaseHeight, (world.Order - 1) * GameConfig.WorldSpacing)
		layouts[world.Id] = WorldBuilder.Build(world, origin, folder)
	end
	log.info(`Built {#WorldsConfig.List} worlds in {math.floor((os.clock() - started) * 1000)} ms`)

	Net.Handle("UnlockWorld", function(player, worldId)
		local data = PlayerDataService.Get(player)
		if not data then
			return Net.NotLoaded
		end
		local ok, message = Economy.UnlockWorld(data, worldId)
		if ok then
			PlayerDataService.MarkChanged(player)
		end
		return { ok = ok, message = message }
	end)

	Net.Handle("TravelToWorld", function(player, worldId)
		local data = PlayerDataService.Get(player)
		if not data then
			return Net.NotLoaded
		end
		local ok, message = Economy.SetCurrentWorld(data, worldId)
		if not ok then
			return Net.Fail(message)
		end
		placePlayer(player, data.CurrentWorld)
		PlayerDataService.MarkChanged(player)
		return Net.Ok(`Welcome to {WorldsConfig.ById[data.CurrentWorld].Name}!`)
	end)
end

function WorldService.Start()
	PlayerDataService.ProfileLoaded:Connect(function(player, data)
		placePlayer(player, data.CurrentWorld)
	end)
end

return WorldService
