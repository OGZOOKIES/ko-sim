-- Client side of the Training Grounds. Everything here is presentation for this player only:
--
--   * bag labels, prompts and the progression board show *your* lock / in-use status
--   * the bag you approach gets a soft highlight, the bag you train with gets an outline
--   * using a bag: an unlocked bag is selected (server-checked), the selected bag trains
--   * when your Power goes up next to your bag, it swings and shows a small impact
--   * the Cosmic orbiters and the roof emblem rings turn slowly (only when nearby)
--
-- The server still decides which bags you may use and how much Power you get.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BagsConfig = require(Shared.Config.BagsConfig)
local TrainingAreaConfig = require(Shared.Config.TrainingAreaConfig)

local StarterPlayerScripts = script.Parent.Parent
local ClientState = require(StarterPlayerScripts.ClientState)
local UIController = require(script.Parent.UIController)
local TrainingController = require(script.Parent.TrainingController)

local Tags = TrainingAreaConfig.Tags
local P = TrainingAreaConfig.Palette

local PUNCH_RANGE = 14 -- how close you must stand to your bag for it to react
local ANIMATE_RANGE = 350 -- spinning details only animate within this distance of the camera

local GREEN = Color3.fromRGB(110, 235, 120)
local RED = Color3.fromRGB(255, 120, 110)

local TrainingAreaController = {}

local player = Players.LocalPlayer
local approachHighlight: Highlight
local selectedHighlight: Highlight
local swinging: { [Model]: RBXScriptConnection } = {}
local impactPart: Part
local impactEmitter: ParticleEmitter
local impactSound: Sound

type Status = "InUse" | "Unlocked" | "Next" | "Locked"

local function bagStatus(data, bag): Status
	if data.SelectedBag == bag.Id then
		return "InUse"
	elseif data.RebirthCount >= bag.RequiredRebirths then
		return "Unlocked"
	end
	-- The cheapest locked bag is the one to aim for next.
	for _, other in BagsConfig.List do
		if data.RebirthCount < other.RequiredRebirths then
			return if other.Id == bag.Id then "Next" else "Locked"
		end
	end
	return "Locked"
end

local function findBagModel(worldId: string, bagId: string): Model?
	for _, model in CollectionService:GetTagged(Tags.Bag) do
		if model:GetAttribute("WorldId") == worldId and model:GetAttribute("BagId") == bagId then
			return model
		end
	end
	return nil
end

-- Labels, prompts and boards

local function updateLabel(gui: Instance, data)
	local bag = BagsConfig.ById[gui:GetAttribute("BagId")]
	local frame = gui:FindFirstChildOfClass("Frame")
	local statusLabel = frame and frame:FindFirstChild("Status") :: TextLabel?
	local stroke = frame and frame:FindFirstChild("Stroke") :: UIStroke?
	if not bag or not statusLabel then
		return
	end
	local status = bagStatus(data, bag)
	if status == "InUse" then
		statusLabel.Text = "⭐ TRAINING HERE"
		statusLabel.TextColor3 = GREEN
	elseif status == "Unlocked" then
		statusLabel.Text = if bag.RequiredRebirths == 0 then "✅ FREE • Tap to use" else "✅ Unlocked • Tap to use"
		statusLabel.TextColor3 = P.Cyan
	else
		statusLabel.Text = `🔒 {bag.RequiredRebirths} Rebirths (you have {data.RebirthCount})`
		statusLabel.TextColor3 = if status == "Next" then P.Gold else RED
	end
	if stroke then
		stroke.Thickness = if status == "InUse" then 4 else 2
		stroke.Color = if status == "InUse" then GREEN elseif status == "Next" then P.Gold else TrainingAreaConfig.Bags[bag.Id].Mat
	end
end

local function updateBoard(gui: Instance, data)
	local rebirths = gui:FindFirstChild("Rebirths") :: TextLabel?
	if rebirths then
		rebirths.Text = `Your rebirths: {data.RebirthCount}`
	end
	local row = gui:FindFirstChild("Row")
	if not row then
		return
	end
	for _, bag in BagsConfig.List do
		local cell = row:FindFirstChild(bag.Id)
		local statusLabel = cell and cell:FindFirstChild("Status") :: TextLabel?
		local stroke = cell and cell:FindFirstChild("Stroke") :: UIStroke?
		if statusLabel then
			local status = bagStatus(data, bag)
			statusLabel.Text = if status == "InUse"
				then "IN USE"
				elseif status == "Unlocked" then "✅"
				elseif status == "Next" then "NEXT"
				else "🔒"
			statusLabel.TextColor3 = if status == "InUse" then GREEN elseif status == "Next" then P.Gold else Color3.new(1, 1, 1)
			if stroke then
				stroke.Color = if status == "InUse" then GREEN elseif status == "Next" then P.Gold else TrainingAreaConfig.Bags[bag.Id].Mat
				stroke.Thickness = if status == "InUse" or status == "Next" then 5 else 3
			end
		end
	end
end

local function updatePrompt(model: Instance, data)
	local bag = BagsConfig.ById[model:GetAttribute("BagId")]
	local body = model:FindFirstChild("Body")
	local prompt = body and body:FindFirstChildOfClass("ProximityPrompt")
	if not bag or not prompt then
		return
	end
	local status = bagStatus(data, bag)
	prompt.ActionText = if status == "InUse"
		then "Train"
		elseif status == "Unlocked" then "Use Bag"
		else `Locked ({bag.RequiredRebirths} Rebirths)`
end

local function updateSelectedHighlight(data)
	local model = findBagModel(data.CurrentWorld, data.SelectedBag)
	selectedHighlight.Adornee = model
end

local function refreshAll()
	local data = ClientState.Data
	if not data then
		return
	end
	for _, gui in CollectionService:GetTagged(Tags.Label) do
		updateLabel(gui, data)
	end
	for _, gui in CollectionService:GetTagged(Tags.Board) do
		updateBoard(gui, data)
	end
	for _, model in CollectionService:GetTagged(Tags.Bag) do
		updatePrompt(model, data)
	end
	updateSelectedHighlight(data)
end

-- Swing and impact

local function swing(model: Model, direction: Vector3)
	local pivotPosition = model:GetAttribute("PivotPosition")
	if typeof(pivotPosition) ~= "Vector3" then
		return
	end
	local base = CFrame.new(pivotPosition)
	local axis = Vector3.yAxis:Cross(direction)
	if axis.Magnitude < 0.01 then
		axis = Vector3.xAxis
	end
	axis = axis.Unit

	local previous = swinging[model]
	if previous then
		previous:Disconnect()
	end
	local started = os.clock()
	-- Damped swing away from the player: about 12 degrees, settling in ~1.4 seconds.
	swinging[model] = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		if t > 1.4 or not model.Parent then
			swinging[model]:Disconnect()
			swinging[model] = nil
			if model.Parent then
				model:PivotTo(base)
			end
			return
		end
		local angle = -math.rad(12) * math.exp(-3 * t) * math.sin(10 * t)
		model:PivotTo(base * CFrame.fromAxisAngle(axis, angle))
	end)
end

local function impact(position: Vector3, toward: Vector3)
	impactPart.CFrame = CFrame.lookAt(position, position + toward)
	impactEmitter:Emit(8)
	impactSound.PlaybackSpeed = 0.85 + math.random() * 0.25
	impactSound:Play()

	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(0.6, 0.6, 0.6)
	flash.Position = position
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 240, 200)
	flash.Transparency = 0.1
	flash.Parent = workspace
	local tween = TweenService:Create(flash, TweenInfo.new(0.16), { Size = Vector3.new(2.8, 2.8, 2.8), Transparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		flash:Destroy()
	end)
end

-- Called when this player's Power goes up from training.
local function onTrained(data)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local model = findBagModel(data.CurrentWorld, data.SelectedBag)
	local body = model and model:FindFirstChild("Body") :: BasePart?
	if not model or not body then
		return
	end
	local offset = body.Position - root.Position
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude > PUNCH_RANGE or flat.Magnitude < 0.01 then
		return
	end
	local direction = flat.Unit
	local radius = body.Size.Y / 2 -- cylinders lie along X, so Y is the diameter
	local hitPoint = Vector3.new(body.Position.X, math.clamp(root.Position.Y + 0.5, body.Position.Y - 2.5, body.Position.Y + 2.5), body.Position.Z)
		- direction * radius
	swing(model, direction)
	impact(hitPoint, -direction)
end

-- Using a bag from its prompt

local function useBag(bagId: string)
	local data = ClientState.Data
	if not data then
		return
	end
	if data.SelectedBag == bagId then
		TrainingController.TrainOnce()
		return
	end
	local result = UIController.Request("SelectBag", bagId)
	if result.ok then
		TrainingController.TrainOnce()
	end
end

-- Ambient animation

local function animate()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local focus = camera.CFrame.Position
	local t = os.clock()

	for _, part in CollectionService:GetTagged(Tags.Spin) do
		local center = part:GetAttribute("Center")
		local rotation = part:GetAttribute("BaseRotation")
		if typeof(center) == "Vector3" and typeof(rotation) == "CFrame" and (center - focus).Magnitude < ANIMATE_RANGE then
			local speed = part:GetAttribute("Speed") or 1
			part.CFrame = CFrame.new(center) * CFrame.Angles(0, t * speed, 0) * rotation
		end
	end

	for _, part in CollectionService:GetTagged(Tags.Orbiter) do
		local center = part:GetAttribute("Center")
		if typeof(center) == "Vector3" and (center - focus).Magnitude < ANIMATE_RANGE then
			local radius = part:GetAttribute("Radius") or 3
			local angle = t * (part:GetAttribute("Speed") or 1) + (part:GetAttribute("Phase") or 0)
			local tilt = part:GetAttribute("Tilt") or 0
			local offset = Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius * math.sin(tilt) + math.sin(t * 2 + tilt) * 0.4, math.sin(angle) * radius)
			part.Position = center + offset
		end
	end
end

function TrainingAreaController.Init()
	approachHighlight = Instance.new("Highlight")
	approachHighlight.Name = "BagApproachHighlight"
	approachHighlight.FillColor = P.Gold
	approachHighlight.FillTransparency = 0.85
	approachHighlight.OutlineColor = P.Gold
	approachHighlight.OutlineTransparency = 0.2
	approachHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	approachHighlight.Parent = workspace

	selectedHighlight = Instance.new("Highlight")
	selectedHighlight.Name = "BagSelectedHighlight"
	selectedHighlight.FillTransparency = 1
	selectedHighlight.OutlineColor = GREEN
	selectedHighlight.OutlineTransparency = 0.35
	selectedHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	selectedHighlight.Parent = workspace

	-- One reusable impact emitter and sound.
	impactPart = Instance.new("Part")
	impactPart.Name = "BagImpact"
	impactPart.Size = Vector3.new(0.2, 0.2, 0.2)
	impactPart.Transparency = 1
	impactPart.Anchored = true
	impactPart.CanCollide = false
	impactPart.CanQuery = false
	impactPart.CanTouch = false
	impactPart.Parent = workspace

	impactEmitter = Instance.new("ParticleEmitter")
	impactEmitter.Rate = 0
	impactEmitter.EmissionDirection = Enum.NormalId.Front
	impactEmitter.SpreadAngle = Vector2.new(40, 40)
	impactEmitter.Speed = NumberRange.new(8, 14)
	impactEmitter.Lifetime = NumberRange.new(0.2, 0.35)
	impactEmitter.Drag = 6
	impactEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	impactEmitter.Color = ColorSequence.new(Color3.fromRGB(255, 250, 230), P.Gold)
	impactEmitter.LightEmission = 0.7
	impactEmitter.Parent = impactPart

	impactSound = Instance.new("Sound")
	impactSound.SoundId = "rbxasset://sounds/swordhit.wav"
	impactSound.Volume = 0.25
	impactSound.Parent = impactPart
end

function TrainingAreaController.Start()
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt:GetAttribute("Bag") then
			approachHighlight.Adornee = prompt.Parent and prompt.Parent.Parent
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if prompt:GetAttribute("Bag") and approachHighlight.Adornee == (prompt.Parent and prompt.Parent.Parent) then
			approachHighlight.Adornee = nil
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local bagId = prompt:GetAttribute("Bag")
		if type(bagId) == "string" then
			useBag(bagId)
		end
	end)

	-- Parts can stream in after we start; style them as they arrive.
	for _, tag in { Tags.Label, Tags.Board, Tags.Bag } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function()
			task.defer(refreshAll)
		end)
	end

	ClientState.Changed:Connect(function(data, previous)
		if
			not previous
			or data.RebirthCount ~= previous.RebirthCount
			or data.SelectedBag ~= previous.SelectedBag
			or data.CurrentWorld ~= previous.CurrentWorld
		then
			refreshAll()
		end
		if previous and data.RebirthCount == previous.RebirthCount and data.Power > previous.Power then
			onTrained(data)
		end
	end)
	refreshAll()

	RunService.RenderStepped:Connect(animate)
end

return TrainingAreaController
