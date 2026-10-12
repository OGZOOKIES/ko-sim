-- Train button: tap to train, hold to keep training. Shows "+Power" pop-ups when Power goes up.
-- The server decides the actual gain and rate; this only asks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Logic.Formulas)
local Format = require(Shared.Utilities.Format)

local StarterPlayerScripts = script.Parent.Parent
local ClientState = require(StarterPlayerScripts.ClientState)
local Net = require(StarterPlayerScripts.Net)
local Components = require(StarterPlayerScripts.UI.Components)
local Theme = require(StarterPlayerScripts.UI.Theme)
local UIController = require(script.Parent.UIController)

local TrainingController = {}

local holding = false
local lastSent = 0

local function trainOnce()
	local data = ClientState.Data
	if not data then
		return
	end
	local now = os.clock()
	if now - lastSent < Formulas.TrainingInterval(data) then
		return
	end
	lastSent = now
	Net.Fire("Train")
end

local function popText(text: string)
	local hud = UIController.GetHud()
	local label = Components.Label({
		Text = text,
		TextColor3 = Theme.Colors.Power,
		TextStrokeTransparency = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5 + (math.random() - 0.5) * 0.3, 0, 0, 0),
		Size = UDim2.new(0.5, 0, 0, 30),
		MaxTextSize = 28,
		ZIndex = 3,
		Parent = hud.BottomArea,
	})
	local tween = TweenService:Create(label, TweenInfo.new(0.8), {
		Position = label.Position - UDim2.fromOffset(0, 60),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		label:Destroy()
	end)
end

function TrainingController.Init() end

function TrainingController.Start()
	local hud = UIController.GetHud()
	local button: TextButton = hud.TrainButton

	button.MouseButton1Down:Connect(function()
		holding = true
		trainOnce()
		task.spawn(function()
			while holding do
				task.wait(0.05)
				trainOnce()
			end
		end)
	end)
	button.MouseButton1Up:Connect(function()
		holding = false
	end)
	button.MouseLeave:Connect(function()
		holding = false
	end)
	-- A finger lifted off-screen or outside the button still stops training.
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = false
		end
	end)

	hud.AutoButton.Activated:Connect(function()
		local data = ClientState.Data
		if data then
			UIController.Request("SetAutoTrain", not data.Settings.AutoTrain)
		end
	end)

	ClientState.Changed:Connect(function(data, previous)
		if previous and data.RebirthCount == previous.RebirthCount and data.Power > previous.Power then
			popText(`+{Format.Number(data.Power - previous.Power)} {Theme.Icons.Power}`)
		end
	end)
end

return TrainingController
