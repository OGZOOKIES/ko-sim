-- Client side of the launch: charge meter, release, follow camera, live distance and results.
-- Everything here is presentation. The server owns the session, the ragdoll and the reward.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Logic.Formulas)
local Zones = require(Shared.Logic.Zones)
local Format = require(Shared.Utilities.Format)

local StarterPlayerScripts = script.Parent.Parent
local ClientState = require(StarterPlayerScripts.ClientState)
local Net = require(StarterPlayerScripts.Net)
local Components = require(StarterPlayerScripts.UI.Components)
local Theme = require(StarterPlayerScripts.UI.Theme)
local UIController = require(script.Parent.UIController)

local make = Components.Make

local CAMERA_BIND = "RagdollLaunchCamera"
local CAMERA_BACK = 28
local CAMERA_SIDE = 34
local CAMERA_UP = 14

local LaunchController = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local meter: Frame
local meterFill: Frame
local meterLabel: TextLabel
local results: Frame

type Charging = { SessionId: number, Cycle: number, Start: number, SweetSpotMin: number }
type Flight = {
	SessionId: number,
	World: string,
	Root: BasePart,
	Origin: Vector3,
	Forward: Vector3,
	Right: Vector3,
	CameraPosition: Vector3,
	LookAt: Vector3,
}

local charging: Charging? = nil
local flight: Flight? = nil

local function setBottomVisible(visible: boolean)
	UIController.GetHud().BottomArea.Visible = visible
end

local function bigText(text: string, color: Color3)
	local label = Components.Label({
		Text = text,
		TextColor3 = color,
		TextStrokeTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.35),
		Size = UDim2.fromScale(0.6, 0.12),
		MaxTextSize = 64,
		ZIndex = 15,
		Parent = UIController.GetRoot(),
	})
	local scale = make("UIScale", { Scale = 0.4, Parent = label })
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.2, function()
		local fade = TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 })
		fade:Play()
		fade.Completed:Wait()
		label:Destroy()
	end)
end

local function shockwave(position: Vector3)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Ball
	ring.Size = Vector3.new(2, 2, 2)
	ring.Position = position
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 230, 120)
	ring.Transparency = 0.2
	ring.Parent = workspace
	local tween = TweenService:Create(ring, TweenInfo.new(0.35), { Size = Vector3.new(18, 18, 18), Transparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		ring:Destroy()
	end)
end

-- Charging

local function release()
	local current = charging
	if not current then
		return
	end
	charging = nil
	local charge = Formulas.ChargeAt(os.clock() - current.Start, current.Cycle)
	meterLabel.Text = if Formulas.IsPerfect(charge) then "PERFECT!" else `{math.floor(charge * 100)}%`
	task.spawn(function()
		Net.Invoke("ReleasePunch", current.SessionId, charge)
	end)
	task.delay(0.4, function()
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
	meter.Visible = true
	setBottomVisible(false)

	local session = info.SessionId
	task.delay((info.MaxChargeTime or 8) + 2, function()
		-- The server releases on its own after MaxChargeTime; tidy up if we never heard back.
		if charging and charging.SessionId == session then
			charging = nil
			meter.Visible = false
			setBottomVisible(true)
		end
	end)
end

-- Flight camera

local function stopCamera()
	RunService:UnbindFromRenderStep(CAMERA_BIND)
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function updateFlight(dt: number)
	local current = flight
	if not current then
		return
	end
	local root = current.Root
	if root.Parent then
		local target = root.Position
		local desired = target - current.Forward * CAMERA_BACK + current.Right * CAMERA_SIDE + Vector3.yAxis * CAMERA_UP
		current.CameraPosition = current.CameraPosition:Lerp(desired, 1 - math.exp(-dt * 5))
		current.LookAt = current.LookAt:Lerp(target, 1 - math.exp(-dt * 8))

		local data = ClientState.Data
		local distance = math.max(0, (target - current.Origin):Dot(current.Forward))
		local zone = Zones.Find(current.World, distance)
		local wins = if data then Formulas.WinsForZone(data, zone) else zone.Wins
		local readout = UIController.GetHud().LaunchLabel
		readout.Text = `📏 {math.floor(distance)} studs  •  {zone.Name}  •  🏆 +{Format.Number(wins)}`
	end
	camera.CFrame = CFrame.lookAt(current.CameraPosition, current.LookAt)
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
		return
	end

	shockwave(root.Position)
	if info.Perfect then
		bigText("PERFECT PUNCH! 💥", Theme.Colors.Wins)
	end

	flight = {
		SessionId = info.SessionId,
		World = info.World,
		Root = root,
		Origin = info.Origin,
		Forward = info.Forward,
		Right = info.Right,
		CameraPosition = camera.CFrame.Position,
		LookAt = root.Position,
	}
	UIController.GetHud().LaunchLabel.Visible = true
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(CAMERA_BIND, Enum.RenderPriority.Camera.Value + 1, updateFlight)
end

-- Results

local resultLabels: { [string]: TextLabel } = {}

local function buildResults(root: Instance)
	results = make("Frame", {
		Name = "LaunchResults",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.42, 0.46),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		ZIndex = 8,
		Parent = root,
	})
	make("UISizeConstraint", { MinSize = Vector2.new(280, 260), MaxSize = Vector2.new(480, 330), Parent = results })
	Components.Corner(results, 18)
	Components.Stroke(results, Theme.Colors.Wins, 3)
	Components.Padding(results, 14)

	local rows = {
		{ Key = "Title", Size = 40, Color = Theme.Colors.Wins },
		{ Key = "Distance", Size = 30, Color = Theme.Colors.Text },
		{ Key = "Zone", Size = 28, Color = Theme.Colors.Tokens },
		{ Key = "Wins", Size = 30, Color = Theme.Colors.Wins },
		{ Key = "Best", Size = 22, Color = Theme.Colors.SubText },
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
		Text = "🔁 Retry",
		Color = Theme.Colors.Power,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.58, 0, 0, 52),
		MaxTextSize = 28,
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
		Size = UDim2.new(0.38, 0, 0, 52),
		MaxTextSize = 24,
		OnClick = function()
			results.Visible = false
			setBottomVisible(true)
		end,
		Parent = results,
	})
end

local function onLaunchEnded(result)
	local readout = UIController.GetHud().LaunchLabel
	readout.Text = `📏 {result.Distance} studs  •  {result.ZoneName}  •  🏆 +{Format.Number(result.Wins)}`

	task.delay(0.9, function()
		if flight and flight.SessionId == result.SessionId then
			flight = nil
			stopCamera()
		end
		readout.Visible = false

		resultLabels.Title.Text = if result.IsNewBest then "🎉 NEW PERSONAL BEST!" else "LANDED!"
		resultLabels.Distance.Text = `📏 {result.Distance} studs`
		resultLabels.Zone.Text = `Zone {result.ZoneIndex}: {result.ZoneName}`
		resultLabels.Wins.Text = `🏆 +{Format.Number(result.Wins)} Wins`
		resultLabels.Best.Text = `Personal best: {result.Best} studs`
		results.Visible = true
	end)
end

function LaunchController.Init()
	local root = UIController.GetRoot()

	meter = make("Frame", {
		Name = "ChargeMeter",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(0.5, 0, 0, 150),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 6,
		Parent = root,
	})
	make("UISizeConstraint", { MinSize = Vector2.new(280, 150), MaxSize = Vector2.new(560, 150), Parent = meter })

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
	local sweet = make("Frame", {
		Name = "SweetSpot",
		Size = UDim2.fromScale(0.12, 1),
		Position = UDim2.fromScale(0.88, 0),
		BackgroundColor3 = Theme.Colors.Wins,
		BackgroundTransparency = 0.45,
		Parent = bar,
	})
	Components.Corner(sweet, 17)
	meterFill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Colors.Power,
		Parent = bar,
	})
	Components.Corner(meterFill, 17)

	Components.Button({
		Text = "👊 RELEASE!",
		Color = Theme.Colors.Bad,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0.8, 0, 0, 72),
		MaxTextSize = 36,
		CornerRadius = 18,
		OnClick = release,
		Parent = meter,
	})

	buildResults(root)

	RunService.RenderStepped:Connect(function()
		local current = charging
		if not current then
			return
		end
		sweet.Position = UDim2.fromScale(current.SweetSpotMin, 0)
		sweet.Size = UDim2.fromScale(1 - current.SweetSpotMin, 1)
		local charge = Formulas.ChargeAt(os.clock() - current.Start, current.Cycle)
		meterFill.Size = UDim2.fromScale(charge, 1)
		meterFill.BackgroundColor3 = if Formulas.IsPerfect(charge) then Theme.Colors.Wins else Theme.Colors.Power
	end)
end

function LaunchController.Start()
	Net.On("ChargeStarted", onChargeStarted)
	Net.On("LaunchStarted", onLaunchStarted)
	Net.On("LaunchEnded", onLaunchEnded)

	-- Keyboard / gamepad release.
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not charging then
			return
		end
		if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
			release()
		end
	end)

	-- If the character respawns mid-flight, give the camera back.
	player.CharacterAdded:Connect(function()
		if flight then
			flight = nil
			stopCamera()
			UIController.GetHud().LaunchLabel.Visible = false
			setBottomVisible(true)
		end
	end)
end

return LaunchController
