-- The moment a punch connects: a white flash, a shockwave ring along the punch, a burst of sparks
-- and a hit sound. Everything is local, short-lived (under half a second) and scaled by glove tier.
-- Perfect punches add a second gold ring.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GlovesConfig = require(Shared.Config.GlovesConfig)
local PunchConfig = require(Shared.Config.PunchConfig)
local GloveBuilder = require(Shared.Gloves.GloveBuilder)

local ImpactFx = {}

local GOLD = Color3.fromRGB(255, 210, 90)
local BASE_COLOR = Color3.fromRGB(255, 236, 190)

local emitterPart: Part? = nil
local sparks: ParticleEmitter

local function effectPart(): Part
	if emitterPart and emitterPart.Parent then
		return emitterPart
	end
	local part = Instance.new("Part")
	part.Name = "PunchImpact"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = workspace

	sparks = Instance.new("ParticleEmitter")
	sparks.Rate = 0
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.SpreadAngle = Vector2.new(55, 55)
	sparks.Speed = NumberRange.new(14, 26)
	sparks.Drag = 7
	sparks.Lifetime = NumberRange.new(0.18, 0.35)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	sparks.LightEmission = 0.8
	sparks.LightInfluence = 0
	sparks.Parent = part

	emitterPart = part
	return part
end

-- Effect strength and tint for a glove: stronger gloves hit harder and carry their glow colour.
function ImpactFx.ForGlove(gloveId: string?): (number, Color3)
	local glove = gloveId and GlovesConfig.ById[gloveId]
	local tier = if glove then glove.Tier else 1
	local intensity = PunchConfig.MinIntensity + (PunchConfig.MaxIntensity - PunchConfig.MinIntensity) * (tier - 1) / 49
	local design = GloveBuilder.GetDesign(gloveId or GlovesConfig.StarterGloveId)
	return intensity, design.Colors.Glow or BASE_COLOR
end

local function ring(cframe: CFrame, color: Color3, size: number, duration: number, delayTime: number)
	task.delay(delayTime, function()
		local part = Instance.new("Part")
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.12, 1, 1)
		part.CFrame = cframe
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = color
		part.Transparency = 0.15
		part.Parent = workspace
		local tween = TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.04, size, size),
			Transparency = 1,
		})
		tween:Play()
		tween.Completed:Connect(function()
			part:Destroy()
		end)
	end)
end

-- position: where the fist connects. direction: the way the punch travels.
function ImpactFx.Play(position: Vector3, direction: Vector3, intensity: number, tint: Color3, perfect: boolean)
	local look = CFrame.lookAt(position, position + direction)

	-- Flash
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(1, 1, 1)
	flash.Position = position
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.Material = Enum.Material.Neon
	flash.Color = BASE_COLOR
	flash.Parent = workspace
	local flashTween = TweenService:Create(flash, TweenInfo.new(0.14), { Size = Vector3.one * 3.6 * intensity, Transparency = 1 })
	flashTween:Play()
	flashTween.Completed:Connect(function()
		flash:Destroy()
	end)

	-- Shockwave rings travel along the punch (cylinders lie along X, so turn X onto the look axis).
	local ringFrame = look * CFrame.Angles(0, math.rad(90), 0)
	ring(ringFrame, tint, 10 * intensity, 0.32, 0)
	ring(ringFrame * CFrame.new(1.5, 0, 0), BASE_COLOR, 6 * intensity, 0.26, 0.04)
	if perfect then
		ring(ringFrame * CFrame.new(3, 0, 0), GOLD, 14 * intensity, 0.4, 0.07)
	end

	-- Sparks spray forward, along the punch.
	local part = effectPart()
	part.CFrame = look
	sparks.Color = ColorSequence.new(BASE_COLOR, if perfect then GOLD else tint)
	sparks:Emit(math.floor(10 * intensity + (if perfect then 8 else 0)))

	local sound = Instance.new("Sound")
	sound.SoundId = PunchConfig.Sounds.Impact
	sound.Volume = math.clamp(0.35 * intensity, 0.2, 0.6)
	sound.PlaybackSpeed = 0.62 - (intensity - 1) * 0.1 + math.random() * 0.06
	sound.RollOffMaxDistance = 250
	sound.Parent = part
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

function ImpactFx.Whoosh(parent: Instance)
	local sound = Instance.new("Sound")
	sound.SoundId = PunchConfig.Sounds.Whoosh
	sound.Volume = 0.4
	sound.PlaybackSpeed = 1.1
	sound.RollOffMaxDistance = 150
	sound.Parent = parent
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

return ImpactFx
