-- The hub: a raised stone plaza instead of a flat field.
--
--   * stone foundation with a paved top, lawn beds with curbs, trees and planters
--   * the main avenue with navy-and-gold borders, branch paths to every station
--   * a low perimeter wall with lit pillars, lamp posts and benches along the avenue
--   * the spawn plaza with a monument: a giant statue of the world's legendary glove
--   * a welcome arch over the avenue with the world's name
--
-- Coordinates are relative to the world origin (see WorldBuilder).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GlovesConfig = require(Shared.Config.GlovesConfig)
local GloveBuilder = require(Shared.Gloves.GloveBuilder)
local Architecture = require(script.Parent.Architecture)
local Parts = require(script.Parent.Parts)
local Props = require(script.Parent.Props)

local Hub = {}

Hub.Length = 290
Hub.Width = 260
Hub.FloorThickness = 20
Hub.SpawnX = -258

local V = Vector3.new

-- A lawn bed with a stone curb on every side.
local function lawn(parent: Instance, o: Vector3, minX: number, maxX: number, minZ: number, maxZ: number, env)
	local w, d = maxX - minX, maxZ - minZ
	local c = o + V((minX + maxX) / 2, 0, (minZ + maxZ) / 2)
	Parts.Decor(parent, { Name = "Lawn", Size = V(w, 0.24, d), Position = c + V(0, 0.12, 0), Color = env.Lawn, Material = env.LawnMaterial })
	for _, z in { -d / 2, d / 2 } do
		Parts.Part(parent, { Name = "Curb", Size = V(w + 1, 0.6, 1), Position = c + V(0, 0.3, z), Color = env.Stone, Material = env.StoneMaterial })
	end
	for _, x in { -w / 2, w / 2 } do
		Parts.Part(parent, { Name = "Curb", Size = V(1, 0.6, d), Position = c + V(x, 0.3, 0), Color = env.Stone, Material = env.StoneMaterial })
	end
end

local function bench(parent: Instance, frame: CFrame, env)
	Parts.Part(parent, { Name = "BenchSeat", Size = V(6, 0.4, 1.8), CFrame = frame * CFrame.new(0, 1.6, 0), Color = env.Wood, Material = Enum.Material.Wood })
	Parts.Part(parent, { Name = "BenchBack", Size = V(6, 1.4, 0.3), CFrame = frame * CFrame.new(0, 2.7, 0.8), Color = env.Wood, Material = Enum.Material.Wood })
	for _, x in { -2.5, 2.5 } do
		Parts.Part(parent, { Name = "BenchLeg", Size = V(0.5, 1.4, 1.6), CFrame = frame * CFrame.new(x, 0.7, 0), Color = env.Roof, Material = Enum.Material.Metal })
	end
	Parts.Decor(parent, { Name = "BenchTrim", Size = V(6.1, 0.12, 0.35), CFrame = frame * CFrame.new(0, 3.45, 0.8), Color = env.Trim, Material = Enum.Material.Foil })
end

local function planter(parent: Instance, position: Vector3, env, style: string, rng: Random)
	Parts.Part(parent, { Name = "Planter", Size = V(6, 2, 6), Position = position + V(0, 1, 0), Color = env.Stone, Material = env.StoneMaterial })
	Parts.Decor(parent, { Name = "PlanterRim", Size = V(6.3, 0.2, 6.3), Position = position + V(0, 2.08, 0), Color = env.Trim, Material = Enum.Material.Foil })
	Parts.Decor(parent, { Name = "Soil", Size = V(5.3, 0.1, 5.3), Position = position + V(0, 2.1, 0), Color = Color3.fromRGB(80, 60, 44), Material = Enum.Material.Ground })
	Props.Tree(parent, style, position + V(0, 2.1, 0), rng, env.PropColors)
end

-- The perimeter wall: low stone wall with a capstone and a lit pillar every so often.
local function wall(parent: Instance, from: Vector3, to: Vector3, env)
	local delta = to - from
	local length = delta.Magnitude
	local frame = CFrame.lookAt((from + to) / 2, to)
	Parts.Part(parent, { Name = "Wall", Size = V(1.2, 2.4, length), CFrame = frame * CFrame.new(0, 1.2, 0), Color = env.Stone, Material = env.StoneMaterial })
	Parts.Decor(parent, { Name = "WallCap", Size = V(1.7, 0.4, length), CFrame = frame * CFrame.new(0, 2.6, 0), Color = env.StoneDark, Material = env.StoneMaterial, CastShadow = true })
	local count = math.max(1, math.floor(length / 48))
	for i = 0, count do
		local position = from + delta * (i / count)
		Parts.Part(parent, { Name = "WallPillar", Size = V(2.2, 3.8, 2.2), Position = position + V(0, 1.9, 0), Color = env.Stone, Material = env.StoneMaterial })
		Parts.Decor(parent, { Name = "WallPillarCap", Size = V(2.6, 0.3, 2.6), Position = position + V(0, 3.95, 0), Color = env.Trim, Material = Enum.Material.Foil })
		Parts.Decor(parent, { Name = "WallLamp", Size = V(0.9, 0.9, 0.9), Position = position + V(0, 4.55, 0), Color = Color3.fromRGB(255, 214, 150), Material = Enum.Material.Neon })
	end
end

local function monument(parent: Instance, o: Vector3, world, env)
	local model = Instance.new("Model")
	model.Name = "Monument"
	model.Parent = parent
	local base = o + V(-280, 0, 0)

	Parts.Cylinder(model, base + V(0, 1, 0), 2, 10, { Name = "MonumentBase", Color = env.Stone, Material = env.StoneMaterial }, true)
	Parts.Cylinder(model, base + V(0, 2.05, 0), 0.2, 10.3, { Name = "MonumentTrim", Color = env.Trim, Material = Enum.Material.Foil })
	Parts.Cylinder(model, base + V(0, 3.6, 0), 3, 7.4, { Name = "MonumentDrum", Color = env.Roof, Material = Enum.Material.SmoothPlastic }, true)
	Parts.Cylinder(model, base + V(0, 5.25, 0), 0.3, 8, { Name = "MonumentTop", Color = env.Trim, Material = Enum.Material.Foil }, true)

	-- A giant statue of the world's legendary glove, fist raised, facing the spawn (+X).
	local gloveId = `{world.Id}_10`
	local scale = 3.8
	local statue = GloveBuilder.Build(gloveId, "Right", scale)
	local design = GloveBuilder.GetDesign(gloveId)
	-- Flipped so the fist points up and the back of the hand (+X in glove space) faces the spawn.
	local cuffTop = 1.35 * scale * design.Scale
	local center = base + V(0, 5.4 + cuffTop, 0)
	statue:PivotTo(CFrame.fromMatrix(center, Vector3.xAxis, -Vector3.yAxis, -Vector3.zAxis))
	statue.Name = "GloveStatue"
	statue.Parent = model

	local plaque = Parts.Part(model, { Name = "Plaque", Size = V(0.3, 1.6, 6), Position = base + V(3.75, 3.6, 0), Color = env.Roof, Material = Enum.Material.SmoothPlastic })
	local glove = GlovesConfig.ById[gloveId]
	local label = Parts.SurfaceText(plaque, Enum.NormalId.Right, `{world.Name}  •  {glove.Name}`, env.Trim, 30)
	label.Size = UDim2.fromScale(0.94, 0.7)
	label.Position = UDim2.fromScale(0.03, 0.15)

	local glow = Parts.Decor(model, { Name = "MonumentLight", Size = V(0.5, 0.5, 0.5), Transparency = 1, Position = base + V(4, 8, 0) })
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Left
	light.Color = Color3.fromRGB(255, 226, 180)
	light.Range = 24
	light.Angle = 70
	light.Brightness = 1.6
	light.Parent = glow
end

function Hub.Build(parent: Instance, o: Vector3, world, env): SpawnLocation
	local model = Instance.new("Model")
	model.Name = "Hub"
	model.Parent = parent
	local rng = Random.new(world.Order * 31)
	local length, width, thickness = Hub.Length, Hub.Width, Hub.FloorThickness

	-- Foundation and paved top.
	Parts.Part(model, {
		Name = "Foundation",
		Size = V(length, thickness - 0.4, width),
		Position = o + V(-length / 2, -thickness / 2 - 0.2, 0),
		Color = env.StoneDark,
		Material = env.StoneMaterial,
	})
	Parts.Part(model, {
		Name = "Plaza",
		Size = V(length, 0.4, width),
		Position = o + V(-length / 2, -0.2, 0),
		Color = env.Floor,
		Material = env.FloorMaterial,
	})
	for _, z in { -width / 2, width / 2 } do
		Parts.Decor(model, { Name = "EdgeTrim", Size = V(length, 0.3, 0.6), Position = o + V(-length / 2, -0.55, z), Color = env.Trim, Material = Enum.Material.Foil })
	end

	-- Main avenue with navy and gold borders.
	local avenueLength = 268
	local avenueX = -136
	Parts.Decor(model, { Name = "Avenue", Size = V(avenueLength, 0.24, 14), Position = o + V(avenueX, 0.12, 0), Color = env.Floor:Lerp(env.StoneDark, 0.35), Material = env.FloorMaterial })
	for _, side in { -1, 1 } do
		Parts.Decor(model, { Name = "AvenueBorder", Size = V(avenueLength, 0.26, 0.8), Position = o + V(avenueX, 0.13, side * 7.4), Color = env.Roof, Material = Enum.Material.SmoothPlastic })
		Parts.Decor(model, { Name = "AvenueTrim", Size = V(avenueLength, 0.27, 0.18), Position = o + V(avenueX, 0.135, side * 7.9), Color = env.Trim, Material = Enum.Material.Foil })
	end
	-- Branch paths to the stations (the Training Grounds bring their own on the +Z side).
	for _, x in { -250, -190, -130, -70 } do
		for _, side in { -1, 1 } do
			if side == -1 or x > -150 then
				Parts.Decor(model, { Name = "Path", Size = V(10, 0.22, 52), Position = o + V(x, 0.11, side * 34), Color = env.Floor:Lerp(env.StoneDark, 0.25), Material = env.FloorMaterial })
			end
		end
	end

	-- Lawns behind the station rows.
	lawn(model, o, -286, -40, -126, -86, env)
	lawn(model, o, -112, -40, 86, 126, env)
	for _, x in { -270, -222, -160, -100, -52 } do
		Props.Tree(model, env.Props, o + V(x + rng:NextNumber(-6, 6), 0.24, -106 + rng:NextNumber(-8, 8)), rng, env.PropColors)
	end
	for _, x in { -96, -56 } do
		Props.Tree(model, env.Props, o + V(x, 0.24, 106), rng, env.PropColors)
	end

	-- Perimeter wall (the Training Grounds plaza continues the +Z side west of x = -140).
	wall(model, o + V(-length + 1, 0, -width / 2 + 1), o + V(-4, 0, -width / 2 + 1), env)
	wall(model, o + V(-length + 1, 0, -width / 2 + 1), o + V(-length + 1, 0, width / 2 - 1), env)
	wall(model, o + V(-138, 0, width / 2 - 1), o + V(-4, 0, width / 2 - 1), env)

	-- Lamp posts and benches along the avenue, planters at the crossings.
	-- (Kept clear of the branch paths at x = -250, -190, -130 and -70.)
	for i, x in { -220, -160, -100, -46 } do
		for _, side in { -1, 1 } do
			Architecture.LampPost(model, o + V(x, 0, side * 11), env, i % 2 == 1 and side == 1)
		end
	end
	-- Benches face the avenue.
	for _, x in { -205, -110 } do
		bench(model, CFrame.lookAt(o + V(x, 0, -14), o + V(x, 0, -8)), env)
		bench(model, CFrame.lookAt(o + V(x, 0, 14), o + V(x, 0, 8)), env)
	end
	for _, x in { -160, -100, -40 } do
		planter(model, o + V(x, 0, -24), env, env.Props, rng)
	end
	planter(model, o + V(-40, 0, 24), env, env.Props, rng)

	-- Spawn plaza.
	local spawnCenter = o + V(Hub.SpawnX, 0, 0)
	Parts.Cylinder(model, spawnCenter + V(0, 0.16, 0), 0.32, 36, { Name = "SpawnPlazaRim", Color = env.Trim, Material = Enum.Material.Foil }, true)
	Parts.Cylinder(model, spawnCenter + V(0, 0.2, 0), 0.4, 35, { Name = "SpawnPlaza", Color = env.Floor:Lerp(Color3.new(1, 1, 1), 0.15), Material = env.FloorMaterial }, true)
	Parts.Cylinder(model, spawnCenter + V(0, 0.22, 0), 0.42, 17, { Name = "SpawnRing", Color = env.Roof, Material = Enum.Material.SmoothPlastic }, true)
	Parts.Cylinder(model, spawnCenter + V(0, 0.24, 0), 0.44, 15.6, { Name = "SpawnInner", Color = env.Floor, Material = env.FloorMaterial }, true)

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = V(9, 0.5, 9)
	-- Players spawn facing the welcome arch and the launch arena (+X).
	spawnLocation.CFrame = CFrame.lookAt(spawnCenter + V(0, 0.5, 0), spawnCenter + V(1, 0.5, 0))
	spawnLocation.Color = env.Trim
	spawnLocation.Material = Enum.Material.Foil
	spawnLocation.TopSurface = Enum.SurfaceType.Smooth
	spawnLocation.Duration = 0
	-- Only the first world's spawn is neutral. Other worlds are reached with RespawnLocation.
	spawnLocation.Neutral = world.Order == 1
	spawnLocation.Parent = model

	monument(model, o, world, env)

	local archPosition = o + V(-226, 0, 0)
	Architecture.Arch(model, CFrame.lookAt(archPosition, archPosition + Vector3.xAxis), env, 18, 13, `{world.Theme.Icon} {string.upper(world.Name)}`)

	return spawnLocation
end

return Hub
