-- The punch-and-launch mechanic. The server decides everything that matters:
--
--   1. BeginCharge: the player holds the dummy's prompt (or presses Retry). The server checks they
--      are loaded, standing at the station, not already launching and off cooldown, then starts a
--      session and tells the client to show the meter.
--   2. Release: the client sends the charge it showed, or "auto" for a Quick Punch. A shown charge
--      is accepted only if the server's own meter passed through it within the player's ping
--      window; otherwise the server's value is used. Perfect is decided here, never by the client.
--      A punch left charging is released automatically as a Quick Punch.
--   3. Punch: everyone is told to play the punch (PunchFx). After LaunchConfig.ImpactDelay (when
--      the fist connects) the server launches.
--   4. Launch: the server spawns a ragdoll it simulates itself (network owner = server) and gives
--      it a velocity aimed at the distance from Formulas.LaunchDistance.
--   5. Flight: every frame the server measures the ragdoll's distance along the runway. The launch
--      ends when it settles, leaves the runway (the last on-runway distance counts) or hits the
--      time limit. The client never reports positions.
--   6. Finish: runs once per session (state check), awards Wins once, and removes the ragdoll.
--
-- Players leaving mid-launch get no reward and their ragdoll is removed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LaunchConfig = require(Shared.Config.LaunchConfig)
local PunchConfig = require(Shared.Config.PunchConfig)
local WorldsConfig = require(Shared.Config.WorldsConfig)
local Formulas = require(Shared.Logic.Formulas)
local Log = require(Shared.Utilities.Log)
local Net = require(ServerScriptService.Net)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local WorldService = require(ServerScriptService.Services.WorldService)
local ZoneRewardService = require(ServerScriptService.Services.ZoneRewardService)
local RagdollFactory = require(ServerScriptService.World.RagdollFactory)

local log = Log.new("Launch")

type Session = {
	Id: number,
	Player: Player,
	World: string,
	State: string, -- "Charging" | "Punching" | "Flying" | "Ended"
	ChargeStart: number,
	Cycle: number,
	Perfect: boolean,
	Quick: boolean,
	Ragdoll: Model?,
	Root: BasePart?,
	LaunchTime: number,
	LastValidDistance: number,
	SettleTimer: number,
	EndedAt: number,
}

local LaunchService = {}

local sessions: { [Player]: Session } = {}
local nextSessionId = 0
local rng = Random.new()
local ragdollFolder: Folder

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function removeRagdoll(session: Session, delaySeconds: number)
	local ragdoll = session.Ragdoll
	session.Ragdoll = nil
	session.Root = nil
	if ragdoll then
		if delaySeconds > 0 then
			task.delay(delaySeconds, function()
				ragdoll:Destroy()
			end)
		else
			ragdoll:Destroy()
		end
	end
end

local function finish(session: Session, distance: number, reason: string)
	if session.State ~= "Flying" then
		return
	end
	session.State = "Ended"
	session.EndedAt = os.clock()
	removeRagdoll(session, LaunchConfig.RagdollCleanupDelay)

	local player = session.Player
	if not player.Parent then
		return
	end
	local reward = ZoneRewardService.Award(player, session.World, distance)
	if not reward then
		return
	end
	Net.Fire("LaunchEnded", player, {
		SessionId = session.Id,
		World = session.World,
		Distance = reward.Distance,
		ZoneName = reward.Zone.Name,
		ZoneIndex = reward.Zone.Index,
		Wins = reward.Wins,
		Best = reward.Best,
		IsNewBest = reward.IsNewBest,
		Perfect = session.Perfect,
		Quick = session.Quick,
		Reason = reason,
	})
end

local function launch(session: Session, data, timingFactor: number)
	local player = session.Player
	local layout = WorldService.GetLayout(session.World)
	local world = WorldsConfig.ById[session.World]

	local targetDistance = Formulas.LaunchDistance(data, session.World, timingFactor)
	local spread = Formulas.LaunchSpread(data)
	local angle = math.rad(LaunchConfig.AngleDegrees + rng:NextNumber(-1, 1) * LaunchConfig.AngleSpreadDegrees * spread)
	local sideAngle = math.rad(rng:NextNumber(-1, 1) * LaunchConfig.SideSpreadDegrees * spread)

	-- Projectile range: R = v^2 * sin(2 * angle) / g, solved for v.
	local flightRange = math.max(targetDistance * LaunchConfig.FlightRangeFactor - layout.DummyOffset, 2)
	local speed = math.sqrt(flightRange * workspace.Gravity / math.sin(2 * angle))
	local horizontal = speed * math.cos(angle)
	local velocity = layout.Forward * (horizontal * math.cos(sideAngle))
		+ layout.Right * (horizontal * math.sin(sideAngle))
		+ Vector3.yAxis * (speed * math.sin(angle))

	local model, root = RagdollFactory.Create(layout.DummyCFrame, world.Theme.Accent, false)
	model.Name = `Ragdoll_{player.UserId}`
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	model.Parent = ragdollFolder

	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			pcall(function()
				part:SetNetworkOwner(nil)
			end)
			part.AssemblyLinearVelocity = velocity
		end
	end
	-- Tumble forward (around the sideways axis) with a little random twist.
	root.AssemblyAngularVelocity = layout.Right * rng:NextNumber(-14, -8) + Vector3.new(0, rng:NextNumber(-3, 3), 0)

	local sound = Instance.new("Sound")
	sound.SoundId = PunchConfig.Sounds.Ragdoll
	sound.Volume = 0.7
	sound.RollOffMaxDistance = 300
	sound.Parent = root
	sound:Play()

	session.State = "Flying"
	session.Ragdoll = model
	session.Root = root
	session.LaunchTime = os.clock()
	session.LastValidDistance = layout.DummyOffset
	session.SettleTimer = 0

	Net.Fire("LaunchStarted", player, {
		SessionId = session.Id,
		World = session.World,
		Ragdoll = model,
		Root = root,
		Origin = layout.Origin,
		Forward = layout.Forward,
		Right = layout.Right,
		Perfect = session.Perfect,
		Quick = session.Quick,
	})
	log.debug(`{player.Name} launched: timing x{math.floor(timingFactor * 100) / 100}, target {math.floor(targetDistance)} studs`)
end

local function updateFlight(session: Session, dt: number)
	local layout = WorldService.GetLayout(session.World)
	local root = session.Root
	if not root or not root.Parent then
		finish(session, session.LastValidDistance, "Lost")
		return
	end

	local offset = root.Position - layout.Origin
	local along = offset:Dot(layout.Forward)
	local sideways = offset:Dot(layout.Right)
	local inBounds = math.abs(sideways) <= layout.RunwayHalfWidth + LaunchConfig.OutOfBoundsSide
		and offset.Y > -LaunchConfig.OutOfBoundsDrop
		and along >= -30
		and along <= layout.RunwayLength + 20
	if not inBounds then
		finish(session, session.LastValidDistance, "OutOfBounds")
		return
	end
	session.LastValidDistance = math.clamp(along, 0, layout.RunwayLength)

	local flightTime = os.clock() - session.LaunchTime
	if flightTime >= LaunchConfig.MaxFlightTime then
		finish(session, session.LastValidDistance, "Timeout")
		return
	end

	if flightTime >= LaunchConfig.MinFlightTime and root.AssemblyLinearVelocity.Magnitude < LaunchConfig.SettleSpeed then
		session.SettleTimer += dt
		if session.SettleTimer >= LaunchConfig.SettleTime then
			finish(session, session.LastValidDistance, "Landed")
		end
	else
		session.SettleTimer = 0
	end
end

-- Returns the charge to use and whether it was a Quick Punch.
-- A shown charge is trusted only if the server's meter really showed it within the ping window.
local function validatedCharge(player: Player, session: Session, clientCharge: any): (number, boolean)
	if clientCharge == "auto" then
		return LaunchConfig.AutoCharge, true
	end
	local elapsed = os.clock() - session.ChargeStart
	local serverCharge = Formulas.ChargeAt(elapsed, session.Cycle)
	if type(clientCharge) ~= "number" or clientCharge ~= clientCharge or clientCharge < 0 or clientCharge > 1 then
		return serverCharge, false
	end

	local ok, ping = pcall(function()
		return player:GetNetworkPing()
	end)
	local window = math.clamp((if ok and type(ping) == "number" then ping else 0.1) * 1.5 + 0.1, 0.1, 0.5)
	for i = 0, 25 do
		local t = elapsed - window * i / 25
		if math.abs(Formulas.ChargeAt(t, session.Cycle) - clientCharge) <= 0.03 then
			return clientCharge, false
		end
	end
	return serverCharge, false
end

function LaunchService.BeginCharge(player: Player, worldId: string): (boolean, string?)
	local data = PlayerDataService.Get(player)
	if not data then
		return false, "Your data is still loading..."
	end
	if data.CurrentWorld ~= worldId then
		return false, nil
	end
	local layout = WorldService.GetLayout(worldId)
	if not layout then
		return false, nil
	end

	local existing = sessions[player]
	if existing and existing.State ~= "Ended" then
		return false, nil
	end
	if existing and os.clock() - existing.EndedAt < LaunchConfig.Cooldown then
		return false, "Get ready..."
	end

	local root = characterRoot(player)
	if not root or (root.Position - layout.StationPosition).Magnitude > LaunchConfig.StationRange then
		return false, "Walk up to the dummy to punch it!"
	end

	nextSessionId += 1
	local cycle = Formulas.ChargeCycle(data)
	local session: Session = {
		Id = nextSessionId,
		Player = player,
		World = worldId,
		State = "Charging",
		ChargeStart = os.clock(),
		Cycle = cycle,
		Perfect = false,
		Quick = false,
		Ragdoll = nil,
		Root = nil,
		LaunchTime = 0,
		LastValidDistance = 0,
		SettleTimer = 0,
		EndedAt = 0,
	}
	sessions[player] = session

	Net.Fire("ChargeStarted", player, {
		SessionId = session.Id,
		Cycle = cycle,
		SweetSpotMin = Formulas.SweetSpotMin(cycle),
		MaxChargeTime = LaunchConfig.MaxChargeTime,
		DummyPosition = layout.StationPosition,
	})

	task.delay(LaunchConfig.MaxChargeTime, function()
		if sessions[player] == session and session.State == "Charging" then
			LaunchService.Release(player, session.Id, "auto")
		end
	end)
	return true, nil
end

function LaunchService.Release(player: Player, sessionId: number, clientCharge: any): boolean
	local session = sessions[player]
	if not session or session.Id ~= sessionId or session.State ~= "Charging" then
		return false
	end
	local data = PlayerDataService.Get(player)
	if not data or data.CurrentWorld ~= session.World then
		session.State = "Ended"
		session.EndedAt = os.clock()
		return false
	end

	local charge, quick = validatedCharge(player, session, clientCharge)
	local perfect = not quick and Formulas.IsPerfect(charge, session.Cycle)
	local timingFactor = Formulas.TimingFactor(charge, perfect)
	session.State = "Punching"
	session.Perfect = perfect
	session.Quick = quick

	local layout = WorldService.GetLayout(session.World)
	Net.FireAll("PunchFx", {
		UserId = player.UserId,
		GloveId = data.EquippedGlove,
		Position = layout.StationPosition,
		Direction = layout.Forward,
		Perfect = perfect,
		Power = timingFactor,
		Delay = LaunchConfig.ImpactDelay,
	})

	-- Launch when the fist connects, if nothing changed in the meantime.
	task.delay(LaunchConfig.ImpactDelay, function()
		if sessions[player] ~= session or session.State ~= "Punching" or not player.Parent then
			return
		end
		local current = PlayerDataService.Get(player)
		if not current then
			session.State = "Ended"
			session.EndedAt = os.clock()
			return
		end
		launch(session, current, timingFactor)
	end)
	return true
end

function LaunchService.Init()
	RagdollFactory.SetupCollisionGroups()

	ragdollFolder = Instance.new("Folder")
	ragdollFolder.Name = "Ragdolls"
	ragdollFolder.Parent = workspace

	for _, world in WorldsConfig.List do
		local layout = WorldService.GetLayout(world.Id)
		layout.LaunchPrompt.Triggered:Connect(function(player)
			local ok, message = LaunchService.BeginCharge(player, world.Id)
			if not ok and message then
				Net.Notify(player, message, "Error")
			end
		end)
	end

	Net.Handle("StartLaunch", function(player)
		local data = PlayerDataService.Get(player)
		if not data then
			return Net.NotLoaded
		end
		local ok, message = LaunchService.BeginCharge(player, data.CurrentWorld)
		return { ok = ok, message = message }
	end, { RateLimit = 3 })

	Net.Handle("ReleasePunch", function(player, sessionId, charge)
		if type(sessionId) ~= "number" then
			return Net.Fail()
		end
		return { ok = LaunchService.Release(player, sessionId, charge) }
	end, { RateLimit = 4 })
end

function LaunchService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(RagdollFactory.AssignCharacter)
		if player.Character then
			RagdollFactory.AssignCharacter(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			session.State = "Ended"
			removeRagdoll(session, 0)
			sessions[player] = nil
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		for _, session in sessions do
			if session.State == "Flying" then
				updateFlight(session, dt)
			end
		end
	end)
end

return LaunchService
