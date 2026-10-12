-- The launch arena where the hub meets the runway: a round punch platform with ring inlays,
-- small stands on both sides, the LAUNCH ZONE gate with spotlights, and the display dummy.

local Architecture = require(script.Parent.Architecture)
local Parts = require(script.Parent.Parts)
local RagdollFactory = require(script.Parent.RagdollFactory)

local LaunchArena = {}

LaunchArena.DummyOffset = 6

local V = Vector3.new

local function stands(parent: Instance, o: Vector3, side: number, env)
	-- Three stepped rows facing the punch platform.
	for row = 1, 3 do
		local z = side * (20 + row * 3)
		Parts.Part(parent, { Name = "Stand", Size = V(20, row, 3), Position = o + V(-14, row / 2, z), Color = env.Stone, Material = env.StoneMaterial })
		Parts.Decor(parent, { Name = "StandSeat", Size = V(20, 0.2, 1.4), Position = o + V(-14, row + 0.1, z - side * 0.6), Color = env.Roof, Material = Enum.Material.SmoothPlastic })
	end
	Parts.Decor(parent, { Name = "StandTrim", Size = V(20.2, 0.15, 0.2), Position = o + V(-14, 1.05, side * 21.45), Color = env.Trim, Material = Enum.Material.Foil })
end

export type Arena = { DummyCFrame: CFrame, StationPosition: Vector3, Prompt: ProximityPrompt }

function LaunchArena.Build(parent: Instance, o: Vector3, world, env): Arena
	local model = Instance.new("Model")
	model.Name = "LaunchStation"
	model.Parent = parent

	-- Punch platform: gold rim, cyan ring line, navy centre emblem.
	local pad = o + V(-11, 0, 0)
	Parts.Cylinder(model, pad + V(0, 0.2, 0), 0.4, 27, { Name = "PadRim", Color = env.Trim, Material = Enum.Material.Foil }, true)
	Parts.Cylinder(model, pad + V(0, 0.22, 0), 0.44, 26, { Name = "Pad", Color = env.Floor:Lerp(Color3.new(1, 1, 1), 0.1), Material = env.FloorMaterial }, true)
	Parts.Cylinder(model, pad + V(0, 0.24, 0), 0.46, 18.4, { Name = "PadRing", Color = env.Energy, Material = Enum.Material.Neon })
	Parts.Cylinder(model, pad + V(0, 0.25, 0), 0.48, 17.8, { Name = "PadInner", Color = env.Floor, Material = env.FloorMaterial })
	Parts.Cylinder(model, pad + V(0, 0.26, 0), 0.5, 8, { Name = "PadEmblem", Color = env.Roof, Material = Enum.Material.SmoothPlastic })
	Parts.Cylinder(model, pad + V(0, 0.27, 0), 0.52, 3, { Name = "PadEmblemCore", Color = env.Trim, Material = Enum.Material.Foil })

	stands(model, o, -1, env)
	stands(model, o, 1, env)

	-- The LAUNCH ZONE gate frames the runway start (behind the dummy, so nothing can hit it).
	local gatePosition = o + V(-1, 0, 0)
	Architecture.Arch(model, CFrame.lookAt(gatePosition, gatePosition + Vector3.xAxis), env, 92, 24, "🥊 LAUNCH ZONE 🥊")
	for _, z in { -12, 12 } do
		local holder = Parts.Decor(model, { Name = "Spotlight", Size = V(1.2, 1.2, 1.6), Position = o + V(-1, 23.2, z), Color = env.Roof, Material = Enum.Material.Metal })
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Color = Color3.fromRGB(255, 230, 190)
		light.Range = 34
		light.Angle = 50
		light.Brightness = 1.4
		light.Shadows = false
		light.Parent = holder
	end

	-- The dummy players punch (it hides locally while your copy flies).
	local dummyPosition = o + V(LaunchArena.DummyOffset, RagdollFactory.StandHeight, 0)
	local dummyCFrame = CFrame.lookAt(dummyPosition, dummyPosition - Vector3.xAxis) -- faces the player
	local display, torso = RagdollFactory.Create(dummyCFrame, world.Theme.Accent, true)
	display.Name = "DisplayDummy"
	display.Parent = model
	local prompt = Parts.Prompt(torso, "Hold to Punch", "Ragdoll Dummy", { Action = "Launch" })
	prompt.MaxActivationDistance = 14

	return { DummyCFrame = dummyCFrame, StationPosition = dummyPosition, Prompt = prompt }
end

return LaunchArena
