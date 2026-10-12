-- Client side of the punch and launch. Everything here is presentation; the server owns the
-- session, the timing check, the ragdoll and the reward.
--
--   Charge   hold E (or the prompt) / tap it. Your character turns to the dummy and winds up.
--            Release: let go of E, the RELEASE button, F, or gamepad R2.
--            Quick Punch (button or Q): no timing needed, a solid hit that is never Perfect.
--   Punch    your character strikes; everyone sees it (PunchFx).
--   Impact   flash, shockwave, sparks, sound, camera kick and shake.
--   Flight   follow camera (skippable), live distance, zone and Wins, and a runway progress bar.
--   Results  distance, zone, Wins, personal best and Perfect, counting up; Retry starts again.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LaunchConfig = require(Shared.Config.LaunchConfig)
local WorldsConfig = require(Shared.Config.WorldsConfig)
local Formulas = require(Shared.Logic.Formulas)
local Zones = require(Shared.Logic.Zones)
local Format = require(Shared.Utilities.Format)

local StarterPlayerScripts = script.Parent.Parent
local ClientState = require(StarterPlayerScripts.ClientState)
local Net = require(StarterPlayerScripts.Net)
local ImpactFx = require(StarterPlayerScripts.Effects.ImpactFx)
local PunchAnimator = require(StarterPlayerScripts.Effects.PunchAnimator)
local Components = require(StarterPlayerScripts.UI.Components)
local Theme = require(StarterPlayerScripts.UI.Theme)
local UIController = require(script.Parent.UIController)

local make = Components.Make

local CAMERA_BIND = "RagdollLaunchCamera"
local CAMERA_BACK = 28
local CAMERA_SIDE = 34
local CAMERA_UP = 14
local BASE_FOV = 70
local HOLD_TO_RELEASE = 0.3 -- holding E at least this long means letting go releases the punch

local LaunchController = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

type Charging = {
	SessionId: number,
	Cycle: number,
	Start: number,
	SweetSpotMin: number,
}

type Flight = {
	SessionId: number,
	World: string,
	Root: BasePart,
	Origin: Vector3,
	Forward: Vector3,
	Right: Vector3,
	Following: boolean,
	CameraPosition: Vector3,
	LookAt: Vector3,
	ShakeUntil: number,
	ShakeStrength: number,
}

local charging: Charging? = nil
local flight: Flight? = nil
local promptHeldSince: number? = nil
local savedMovement: { WalkSpeed: number, JumpPower: number, JumpHeight: number }? = nil

-- UI
local meter: Frame
local meterFill: Frame
local meterSweet: Frame
local meterLabel: TextLabel
local progress: Frame
local progressMarker: Frame
local skipButton: TextButton
local results: Frame
local resultLabels: { [string]: TextLabel } = {}

local function hud()
	return UIController.GetHud()
end

local function setBottomVisible(visible: boolean)
	hud().BottomArea.Visible = visible
end

local function humanoidAndRoot(): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return humanoid, root
end

-- Plant your feet while punching; give movement back afterwards.
local function lockMovement(locked: boolean)
	local humanoid = humanoidAndRoot()
	if not humanoid then
		return
	end
	if locked and not savedMovement then
		savedMovement = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, JumpHeight = humanoid.JumpHeight }
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	elseif not locked and savedMovement then
		humanoid.WalkSpeed = savedMovement.WalkSpeed
		humanoid.JumpPower = savedMovement.JumpPower
		humanoid.JumpHeight = savedMovement.JumpHeight
		savedMovement = nil
	end
end

local function bigText(text: string, color: Color3)
	local label = Components.Label({
		Text = text,
		TextColor3 = color,
		TextStrokeTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.34),
		Size = UDim2.fromScale(0.6, 0.11),
		MaxTextSize = 60,
		ZIndex = 15,
		Parent = UIController.GetRoot(),
	})
	local scale = make("UIScale", { Scale = 0.4, Parent = label })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.1, function()
		local fade = TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		label:Destroy()
	end)
end

-- The display dummy hides while your copy is flying, then pops back.
local function displayDummy(worldId: string): Model?
	local worlds = workspace:FindFirstChild("Worlds")
	local world = worlds and worlds:FindFirstChild(worldId)
	local station = world and world:FindFirstChild("LaunchStation")
	local dummy = station and station:FindFirstChild("DisplayDummy")
	return if dummy and dummy:IsA("Model") then dummy else nil
end

local function setDummyHidden(worldId: string, hidden: boolean)
	local dummy = displayDummy(worldId)
	if not dummy then
		return
	end
	for _, descendant in dummy:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

-- Charging

local function release(quick: boolean)
	local current = charging
	if not current then
		return
	end
	charging = nil
	promptHeldSince = nil
	local charge = Formulas.ChargeAt(os.clock() - current.Start, current.Cycle)
	meterLabel.Text = if quick
		then "QUICK PUNCH!"
		elseif Formulas.IsPerfect(charge, current.Cycle) then "PERFECT!"
		else `{math.floor(charge * 100)}%`

	local character = player.Character
	if character then
		PunchAnimator.Punch(character)
		local _, root = humanoidAndRoot()
		if root then
			ImpactFx.Whoosh(root)
		end
	end

	task.spawn(function()
		local result = Net.Invoke("ReleasePunch", current.SessionId, if quick then "auto" else charge)
		if not result.ok then
			meter.Visible = false
			setBottomVisible(true)
			lockMovement(false)
		end
	end)
	task.delay(0.35, function()
		if not charging then
			meter.Visible = false
		end
	end)
end

local function onChargeStarted(info)
	UIController.Close()
	results.Visible = false
	charging = {
		SessionId = info.SessionId,
		Cycle = info.Cycle,
		Start = os.clock(),
		SweetSpotMin = info.SweetSpotMin,
	}
	meterSweet.Position = UDim2.fromScale(info.SweetSpotMin, 0)
	meterSweet.Size = UDim2.fromScale(1 - info.SweetSpotMin, 1)
	meterLabel.Text = "Release in the gold zone!"
	meter.Visible = true
	setBottomVisible(false)

	-- Square up to the dummy and plant your feet.
	local _, root = humanoidAndRoot()
	if root and typeof(info.DummyPosition) == "Vector3" then
		local target = Vector3.new(info.DummyPosition.X, root.Position.Y, info.DummyPosition.Z)
		if (target - root.Position).Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, target)
		end
	end
	lockMovement(true)

	local session = info.SessionId
	task.delay((info.MaxChargeTime or 8) + 2, function()
		-- The server releases on its own after MaxChargeTime; tidy up if we never heard back.
		if charging and charging.SessionId == session then
			charging = nil
			meter.Visible = false
			setBottomVisible(true)
			lockMovement(false)
			if player.Character then
				PunchAnimator.SetWindUp(player.Character, 0)
			end
		end
	end)
end

-- Flight camera and readout

local function stopCamera()
	RunService:UnbindFromRenderStep(CAMERA_BIND)
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = BASE_FOV
	local humanoid = humanoidAndRoot()
	if humanoid then
		camera.CameraSubject = humanoid
	end
	if flight then
		flight.Following = false
	end
	skipButton.Visible = false
end

local function updateCamera(dt: number)
	local current = flight
	if not current or not current.Following then
		return
	end
	local root = current.Root
	if root.Parent then
		local velocity = root.AssemblyLinearVelocity
		local lead = if velocity.Magnitude > 60 then velocity.Unit * 60 else velocity
		local target = root.Position + lead * 0.12
		local desired = target - current.Forward * CAMERA_BACK + current.Right * CAMERA_SIDE + Vector3.yAxis * CAMERA_UP
		desired = Vector3.new(desired.X, math.max(desired.Y, current.Origin.Y + 6), desired.Z)
		current.CameraPosition = current.CameraPosition:Lerp(desired, 1 - math.exp(-dt * 5))
		current.LookAt = current.LookAt:Lerp(target, 1 - math.exp(-dt * 8))
	end

	local shake = Vector3.zero
	local remaining = current.ShakeUntil - os.clock()
	if remaining > 0 then
		local strength = current.ShakeStrength * remaining / 0.35
		shake = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * strength
	end
	camera.CFrame = CFrame.lookAt(current.CameraPosition + shake, current.LookAt)
end

local function buildProgressBar(worldId: string)
	Components.Clear(progress)
	local world = WorldsConfig.ById[worldId]
	local length = Formulas.RunwayLength(worldId)
	for i, zone in world.Zones do
		local stop = if i < #world.Zones then world.Zones[i + 1].Min else length
		make("Frame", {
			Position = UDim2.fromScale(zone.Min / length, 0),
			Size = UDim2.new((stop - zone.Min) / length, -1, 1, 0),
			BackgroundColor3 = Theme.Colors.Card:Lerp(Theme.Colors.Wins, (i - 1) / (#world.Zones - 1) * 0.7),
			BorderSizePixel = 0,
			Parent = progress,
		})
	end
	progressMarker = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 6, 1, 8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 3,
		Parent = progress,
	})
	Components.Corner(progressMarker, 3)
end

local function updateReadout()
	local current = flight
	if not current then
		return
	end
	local root = current.Root
	if not root.Parent then
		return
	end
	local data = ClientState.Data
	local distance = math.max(0, (root.Position - current.Origin):Dot(current.Forward))
	local zone = Zones.Find(current.World, distance)
	local wins = if data then Formulas.WinsForZone(data, zone) else zone.Wins
	hud().LaunchLabel.Text = `📏 {math.floor(distance)} studs  •  {zone.Name}  •  🏆 +{Format.Number(wins)}`
	if progressMarker then
		progressMarker.Position = UDim2.fromScale(math.clamp(distance / Formulas.RunwayLength(current.World), 0, 1), 0.5)
	end
end

local function onLaunchStarted(info)
	charging = nil
	meter.Visible = false
	setBottomVisible(false)

	local root = info.Root
	if not root and info.Ragdoll then
		root = info.Ragdoll:WaitForChild("Torso", 2)
	end
	if not root then
		lockMovement(false)
		return
	end

	-- Impact
	local data = ClientState.Data
	local intensity, tint = ImpactFx.ForGlove(data and data.EquippedGlove)
	ImpactFx.Play(root.Position - info.Forward * 1.2, info.Forward, intensity, tint, info.Perfect)
	if info.Perfect then
		bigText("PERFECT PUNCH! 💥", Theme.Colors.Wins)
	end
	setDummyHidden(info.World, true)
	task.delay(0.3, lockMovement, false)

	flight = {
		SessionId = info.SessionId,
		World = info.World,
		Root = root,
		Origin = info.Origin,
		Forward = info.Forward,
		Right = info.Right,
		Following = true,
		CameraPosition = camera.CFrame.Position,
		LookAt = root.Position,
		ShakeUntil = os.clock() + 0.35,
		ShakeStrength = 0.6 * intensity * (if info.Perfect then 1.4 else 1),
	}

	-- A quick field-of-view kick sells the hit without hiding anything.
	camera.FieldOfView = BASE_FOV - 10 * intensity
	TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = BASE_FOV }):Play()

	buildProgressBar(info.World)
	progress.Visible = true
	hud().LaunchLabel.Visible = true
	skipButton.Visible = true
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(CAMERA_BIND, Enum.RenderPriority.Camera.Value + 1, updateCamera)
end

-- Results

local function countUp(label: TextLabel, target: number, render: (number) -> string)
	local value = Instance.new("NumberValue")
	value.Changed:Connect(function(v)
		label.Text = render(v)
	end)
	label.Text = render(0)
	local tween = TweenService:Create(value, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = target })
	tween:Play()
	tween.Completed:Connect(function()
		label.Text = render(target)
		value:Destroy()
	end)
end

local function onLaunchEnded(result)
	local finishedFlight = flight
	hud().LaunchLabel.Text = `📏 {result.Distance} studs  •  {result.ZoneName}  •  🏆 +{Format.Number(result.Wins)}`

	task.delay(0.7, function()
		if finishedFlight and flight == finishedFlight then
			flight = nil
			stopCamera()
		end
		hud().LaunchLabel.Visible = false
		progress.Visible = false
		setDummyHidden(result.World, false)

		resultLabels.Title.Text = if result.IsNewBest then "🎉 NEW PERSONAL BEST!" else "LANDED!"
		resultLabels.Zone.Text = `Zone {result.ZoneIndex}: {result.ZoneName}`
		resultLabels.Best.Text = `Personal best: {result.Best} studs`
		resultLabels.Bonus.Text = if result.Perfect
			then `⭐ Perfect punch: {Format.Multiplier(LaunchConfig.TimingBonus)} distance`
			elseif result.Quick then "Quick Punch - time it for a Perfect bonus!"
			else ""
		countUp(resultLabels.Distance, result.Distance, function(v)
			return `📏 {math.floor(v)} studs`
		end)
		countUp(resultLabels.Wins, result.Wins, function(v)
			return `🏆 +{Format.Number(math.floor(v))} Wins`
		end)

		local scale = results:FindFirstChildOfClass("UIScale") :: UIScale
		scale.Scale = 0.85
		results.Visible = true
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
end

-- Other players' punches (and the sound of yours for everyone else)

local function onPunchFx(info)
	if info.UserId == player.UserId then
		return -- your own punch is animated the moment you release
	end
	local other = Players:GetPlayerByUserId(info.UserId)
	local character = other and other.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - camera.CFrame.Position).Magnitude > 250 then
		return
	end
	PunchAnimator.Punch(character)
	ImpactFx.Whoosh(root)
	local intensity, tint = ImpactFx.ForGlove(info.GloveId)
	task.delay(info.Delay or 0.12, function()
		ImpactFx.Play(info.Position - info.Direction * 1.2, info.Direction, intensity * 0.8, tint, info.Perfect)
	end)
end

-- UI construction

local function buildMeter(root: Instance)
	meter = make("Frame", {
		Name = "ChargeMeter",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(0.5, 0, 0, 176),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 6,
		Parent = root,
	})
	make("UISizeConstraint", { MinSize = Vector2.new(300, 176), MaxSize = Vector2.new(580, 176), Parent = meter })

	meterLabel = Components.Label({
		Text = "Release in the gold zone!",
		Size = UDim2.new(1, 0, 0, 26),
		TextColor3 = Theme.Colors.Wins,
		MaxTextSize = 24,
		Parent = meter,
	})

	local bar = make("Frame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Colors.Dark,
		Parent = meter,
	})
	Components.Corner(bar, 17)
	Components.Stroke(bar, Theme.Colors.Text, 2)
	meterSweet = make("Frame", {
		Name = "SweetSpot",
		Size = UDim2.fromScale(0.12, 1),
		Position = UDim2.fromScale(0.88, 0),
		BackgroundColor3 = Theme.Colors.Wins,
		BackgroundTransparency = 0.4,
		Parent = bar,
	})
	Components.Corner(meterSweet, 17)
	meterFill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Colors.Power,
		Parent = bar,
	})
	Components.Corner(meterFill, 17)

	Components.Label({
		Text = "Hold E and let go • F / tap RELEASE • Q for a Quick Punch",
		Position = UDim2.fromOffset(0, 68),
		Size = UDim2.new(1, 0, 0, 18),
		TextColor3 = Theme.Colors.SubText,
		MaxTextSize = 15,
		Parent = meter,
	})

	Components.Button({
		Text = "👊 RELEASE!",
		Color = Theme.Colors.Bad,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.66, -4, 0, 76),
		MaxTextSize = 36,
		CornerRadius = 18,
		OnClick = function()
			release(false)
		end,
		Parent = meter,
	})
	Components.Button({
		Text = "Quick Punch",
		Color = Theme.Colors.Neutral,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.34, -4, 0, 76),
		MaxTextSize = 22,
		CornerRadius = 18,
		OnClick = function()
			release(true)
		end,
		Parent = meter,
	})
end

local function buildFlightUi(root: Instance)
	progress = make("Frame", {
		Name = "RunwayProgress",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.new(0.5, 0, 0, 10),
		BackgroundColor3 = Theme.Colors.Dark,
		ClipsDescendants = false,
		Visible = false,
		Parent = root,
	})
	make("UISizeConstraint", { MinSize = Vector2.new(260, 10), MaxSize = Vector2.new(620, 10), Parent = progress })

	skipButton = Components.Button({
		Text = "Skip ⏭",
		Color = Theme.Colors.Neutral,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -150),
		Size = UDim2.fromOffset(120, 46),
		MaxTextSize = 22,
		Visible = false,
		OnClick = function()
			stopCamera()
		end,
		Parent = root,
	})
end

local function buildResults(root: Instance)
	results = make("Frame", {
		Name = "LaunchResults",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.42, 0.5),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		ZIndex = 8,
		Parent = root,
	})
	make("UISizeConstraint", { MinSize = Vector2.new(290, 300), MaxSize = Vector2.new(480, 350), Parent = results })
	make("UIScale", { Parent = results })
	Components.Corner(results, 18)
	Components.Stroke(results, Theme.Colors.Wins, 3)
	Components.Padding(results, 14)

	local rows = {
		{ Key = "Title", Size = 38, Color = Theme.Colors.Wins },
		{ Key = "Distance", Size = 34, Color = Theme.Colors.Text },
		{ Key = "Zone", Size = 26, Color = Theme.Colors.Tokens },
		{ Key = "Wins", Size = 32, Color = Theme.Colors.Wins },
		{ Key = "Best", Size = 20, Color = Theme.Colors.SubText },
		{ Key = "Bonus", Size = 18, Color = Theme.Colors.Wins },
	}
	local y = 0
	for _, row in rows do
		resultLabels[row.Key] = Components.Label({
			Size = UDim2.new(1, 0, 0, row.Size),
			Position = UDim2.fromOffset(0, y),
			TextColor3 = row.Color,
			MaxTextSize = row.Size,
			Parent = results,
		})
		y += row.Size + 4
	end

	Components.Button({
		Text = "🔁 Punch again",
		Color = Theme.Colors.Power,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.6, 0, 0, 52),
		MaxTextSize = 26,
		OnClick = function()
			results.Visible = false
			local result = Net.Invoke("StartLaunch")
			if not result.ok then
				setBottomVisible(true)
				if result.message then
					UIController.Toast(result.message, Theme.Colors.Bad)
				end
			end
		end,
		Parent = results,
	})
	Components.Button({
		Text = "Close",
		Color = Theme.Colors.Neutral,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.36, 0, 0, 52),
		MaxTextSize = 24,
		OnClick = function()
			results.Visible = false
			setBottomVisible(true)
		end,
		Parent = results,
	})
end

function LaunchController.Init()
	local root = UIController.GetRoot()
	buildMeter(root)
	buildFlightUi(root)
	buildResults(root)

	RunService.RenderStepped:Connect(function()
		local current = charging
		if current then
			local elapsed = os.clock() - current.Start
			local charge = Formulas.ChargeAt(elapsed, current.Cycle)
			meterFill.Size = UDim2.fromScale(charge, 1)
			meterFill.BackgroundColor3 = if charge >= current.SweetSpotMin then Theme.Colors.Wins else Theme.Colors.Power
			if player.Character then
				PunchAnimator.SetWindUp(player.Character, math.min(1, elapsed / 0.3) * (0.55 + 0.45 * charge))
			end
		end
		updateReadout()
	end)
end

function LaunchController.Start()
	Net.On("ChargeStarted", onChargeStarted)
	Net.On("LaunchStarted", onLaunchStarted)
	Net.On("LaunchEnded", onLaunchEnded)
	Net.On("PunchFx", onPunchFx)

	-- Hold-and-release on the dummy's prompt.
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Action") == "Launch" then
			promptHeldSince = os.clock()
		end
	end)
	ProximityPromptService.PromptTriggerEnded:Connect(function(prompt)
		if prompt:GetAttribute("Action") ~= "Launch" then
			return
		end
		local heldSince = promptHeldSince
		promptHeldSince = nil
		-- A quick tap keeps the meter running for the RELEASE button; a real hold releases now.
		if heldSince and charging and os.clock() - heldSince >= HOLD_TO_RELEASE and os.clock() - charging.Start > 0.15 then
			release(false)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not charging then
			return
		end
		if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
			release(false)
		elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonX then
			release(true)
		end
	end)

	-- If the character respawns mid-launch, give everything back.
	player.CharacterAdded:Connect(function()
		savedMovement = nil
		charging = nil
		meter.Visible = false
		if flight then
			setDummyHidden(flight.World, false)
			flight = nil
			stopCamera()
			hud().LaunchLabel.Visible = false
			progress.Visible = false
		end
		setBottomVisible(true)
	end)
end

return LaunchController
