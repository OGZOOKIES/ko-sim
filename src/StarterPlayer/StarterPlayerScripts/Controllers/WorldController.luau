-- Opens panels from the stations' proximity prompts and sets each world's lighting.
-- (The launch prompt is handled on the server, so it's ignored here.)

local Lighting = game:GetService("Lighting")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldsConfig = require(Shared.Config.WorldsConfig)

local StarterPlayerScripts = script.Parent.Parent
local ClientState = require(StarterPlayerScripts.ClientState)
local UIController = require(script.Parent.UIController)

local WorldController = {}

local currentWorld: string? = nil

local function applyLighting(worldId: string)
	local world = WorldsConfig.ById[worldId]
	if not world then
		return
	end
	local theme = world.Theme.Lighting
	local info = TweenInfo.new(1.5)

	TweenService:Create(Lighting, info, {
		ClockTime = theme.ClockTime,
		Brightness = theme.Brightness,
		Ambient = theme.Ambient,
		OutdoorAmbient = theme.OutdoorAmbient,
	}):Play()

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	TweenService:Create(atmosphere, info, {
		Color = theme.AtmosphereColor,
		Decay = theme.AtmosphereDecay,
		Density = theme.AtmosphereDensity,
		Haze = theme.AtmosphereHaze,
	}):Play()
end

function WorldController.Init() end

function WorldController.Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local panel = prompt:GetAttribute("Panel")
		if type(panel) == "string" then
			UIController.Open(panel)
			return
		end
		local bag = prompt:GetAttribute("Bag")
		if type(bag) == "string" then
			UIController.Request("SelectBag", bag)
		end
	end)

	local function onData(data)
		if data.CurrentWorld ~= currentWorld then
			currentWorld = data.CurrentWorld
			applyLighting(data.CurrentWorld)
		end
	end
	ClientState.Changed:Connect(onData)
	if ClientState.Data then
		onData(ClientState.Data)
	end
end

return WorldController
