-- Opens panels from the stations' proximity prompts and sets each world's lighting.
-- (The launch prompt is handled on the server, so it's ignored here.)

local Lighting = game:GetService("Lighting")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnvironmentConfig = require(Shared.Config.EnvironmentConfig)
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

	-- Per-world colour grading and clouds.
	local env = EnvironmentConfig[worldId]
	if not env then
		return
	end
	local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if correction then
		TweenService:Create(correction, info, { TintColor = env.Sky.Tint }):Play()
	end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Parent = workspace.Terrain
	end
	clouds.Enabled = env.Sky.CloudCover > 0
	TweenService:Create(clouds, info, {
		Cover = env.Sky.CloudCover,
		Density = env.Sky.CloudDensity,
		Color = env.Sky.CloudColor,
	}):Play()
end

-- Gentle, game-wide polish: slightly richer colour, soft shadows, a light glow on neon accents.
-- Only creates effects that don't exist yet, so anything set up in Studio is left alone.
local function applyPolish()
	pcall(function()
		Lighting.ShadowSoftness = 0.25
		Lighting.EnvironmentDiffuseScale = 0.6
		Lighting.EnvironmentSpecularScale = 0.6
	end)
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local correction = Instance.new("ColorCorrectionEffect")
		correction.Saturation = 0.12
		correction.Contrast = 0.05
		correction.Brightness = 0.01
		correction.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.35
		bloom.Size = 20
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
	end
end

function WorldController.Init() end

function WorldController.Start()
	applyPolish()

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		-- Bag prompts are handled by TrainingAreaController.
		local panel = prompt:GetAttribute("Panel")
		if type(panel) == "string" then
			UIController.Open(panel)
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
