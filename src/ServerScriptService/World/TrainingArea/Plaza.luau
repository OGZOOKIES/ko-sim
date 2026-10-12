-- The plaza around the pavilion: extra floor behind it, a curved walkway with an entrance arch,
-- side paths to spawn and the Pet Upgrader, flower beds, planters, benches, trees, rocks and
-- far-off hills. All decoration is non-colliding, except the floor, paths, planters and benches.
--
-- Coordinates are relative to the world origin `o` (see WorldBuilder's layout).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainingAreaConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.TrainingAreaConfig)
local EnvironmentConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.EnvironmentConfig)
local Parts = require(script.Parent.Parent.Parts)

local P = TrainingAreaConfig.Palette
local Layout = TrainingAreaConfig.Layout

local FLOOR_THICKNESS = 20 -- matches WorldBuilder's hub
local HUB_EDGE_Z = 130 -- WorldBuilder's hub is 260 wide

local Plaza = {}

local function flat(o: Vector3, x: number, z: number, y: number?): Vector3
	return o + Vector3.new(x, y or 0, z)
end

-- A path made of straight slabs with round joints, plus optional gold lights along both edges.
local function path(parent: Instance, points: { Vector3 }, width: number, lights: boolean)
	for i = 1, #points - 1 do
		Parts.Between(parent, points[i], points[i + 1], width, 0.22, { Name = "Path", Color = P.Path, Material = Enum.Material.Pavement })
	end
	for i = 2, #points - 1 do
		Parts.Cylinder(parent, points[i], 0.22, width, { Name = "PathJoint", Color = P.Path, Material = Enum.Material.Pavement })
	end
	if not lights then
		return
	end
	for i = 2, #points - 1, 2 do
		local tangent = (points[i + 1] - points[i - 1]).Unit
		local normal = Vector3.new(-tangent.Z, 0, tangent.X)
		for _, side in { -1, 1 } do
			local base = points[i] + normal * side * (width / 2 + 0.9)
			Parts.Decor(parent, { Name = "PathLightPost", Size = Vector3.new(0.5, 1.2, 0.5), Position = base + Vector3.new(0, 0.6, 0), Color = P.Stone, Material = Enum.Material.Limestone })
			Parts.Decor(parent, { Name = "PathLight", Size = Vector3.new(0.6, 0.4, 0.6), Position = base + Vector3.new(0, 1.4, 0), Color = P.Gold, Material = Enum.Material.Neon })
		end
	end
end

local function entranceArch(parent: Instance, position: Vector3)
	-- Faces -Z, toward the main path.
	for _, x in { -8, 8 } do
		local base = position + Vector3.new(x, 0, 0)
		Parts.Part(parent, { Name = "ArchBase", Size = Vector3.new(2.8, 1, 2.8), Position = base + Vector3.new(0, 0.5, 0), Color = P.Stone, Material = Enum.Material.Limestone })
		Parts.Part(parent, { Name = "ArchPillar", Size = Vector3.new(2, 11, 2), Position = base + Vector3.new(0, 6.5, 0), Color = P.Navy, Material = Enum.Material.SmoothPlastic })
		Parts.Decor(parent, { Name = "ArchPillarTrim", Size = Vector3.new(2.3, 0.4, 2.3), Position = base + Vector3.new(0, 11.6, 0), Color = P.Gold, Material = Enum.Material.Foil })
		Parts.Decor(parent, { Name = "ArchGlow", Size = Vector3.new(0.2, 8, 0.2), Position = base + Vector3.new(0, 6.5, -1.05), Color = P.Cyan, Material = Enum.Material.Neon })
	end
	Parts.Part(parent, { Name = "ArchBeam", Size = Vector3.new(19, 1.6, 2.2), Position = position + Vector3.new(0, 12.6, 0), Color = P.Navy, Material = Enum.Material.SmoothPlastic })
	Parts.Decor(parent, { Name = "ArchTrim", Size = Vector3.new(19.2, 0.25, 2.3), Position = position + Vector3.new(0, 11.85, 0), Color = P.Gold, Material = Enum.Material.Foil })
	Parts.Decor(parent, { Name = "ArchSignFrame", Size = Vector3.new(17, 3.6, 0.5), Position = position + Vector3.new(0, 15.2, 0), Color = P.Gold, Material = Enum.Material.Foil })
	local board = Parts.Decor(parent, { Name = "ArchSign", Size = Vector3.new(16.2, 2.9, 0.3), Position = position + Vector3.new(0, 15.2, -0.35), Color = P.DeepNavy })
	local text = Parts.SurfaceText(board, Enum.NormalId.Front, "🏋️ TRAINING GROUNDS", P.Gold, 30)
	text.Size = UDim2.fromScale(0.94, 0.8)
	text.Position = UDim2.fromScale(0.03, 0.1)
end

local function tree(parent: Instance, position: Vector3, plants: { Color3 }, scale: number)
	Parts.Cylinder(parent, position + Vector3.new(0, 0.2, 0), 0.4, 4.2 * scale, { Name = "TreeRing", Color = P.Stone, Material = Enum.Material.Limestone })
	local trunk = 10 * scale
	Parts.Cylinder(parent, position + Vector3.new(0, trunk / 2, 0), trunk, 1.8 * scale, { Name = "Trunk", Color = P.Wood, Material = Enum.Material.Wood, CastShadow = true })
	Parts.Ball(parent, position + Vector3.new(0, trunk + 2.5 * scale, 0), 10 * scale, { Name = "Canopy", Color = plants[1], Material = Enum.Material.Grass, CastShadow = true })
	Parts.Ball(parent, position + Vector3.new(2.6 * scale, trunk + 0.6 * scale, 1.6 * scale), 7 * scale, { Name = "Canopy", Color = plants[2], Material = Enum.Material.Grass })
	Parts.Ball(parent, position + Vector3.new(-2.4 * scale, trunk + 1.2 * scale, -1.8 * scale), 6.5 * scale, { Name = "Canopy", Color = plants[3], Material = Enum.Material.Grass })
end

local function planter(parent: Instance, position: Vector3, plants: { Color3 }, flowers: { Color3 }, rng: Random)
	Parts.Part(parent, { Name = "Planter", Size = Vector3.new(5, 2.2, 5), Position = position + Vector3.new(0, 1.1, 0), Color = P.Stone, Material = Enum.Material.Limestone })
	Parts.Decor(parent, { Name = "PlanterRim", Size = Vector3.new(5.3, 0.18, 5.3), Position = position + Vector3.new(0, 2.25, 0), Color = P.Gold, Material = Enum.Material.Foil })
	Parts.Decor(parent, { Name = "Soil", Size = Vector3.new(4.4, 0.1, 4.4), Position = position + Vector3.new(0, 2.3, 0), Color = P.Soil, Material = Enum.Material.Ground })
	Parts.Ellipsoid(parent, position + Vector3.new(0, 3.5, 0), Vector3.new(4, 3, 4), { Name = "Shrub", Color = plants[1], Material = Enum.Material.Grass })
	for _ = 1, 4 do
		local offset = Vector3.new(rng:NextNumber(-1.6, 1.6), 0, rng:NextNumber(-1.6, 1.6))
		Parts.Ball(parent, position + offset + Vector3.new(0, 4.4 + rng:NextNumber(0, 0.6), 0), 0.7, { Name = "Flower", Color = flowers[rng:NextInteger(1, #flowers)] })
	end
end

local function flowerBed(parent: Instance, center: Vector3, length: number, plants: { Color3 }, flowers: { Color3 }, rng: Random)
	Parts.Decor(parent, { Name = "BedBorder", Size = Vector3.new(length, 0.7, 3), Position = center + Vector3.new(0, 0.35, 0), Color = P.Stone, Material = Enum.Material.Limestone, CastShadow = false })
	Parts.Decor(parent, { Name = "BedSoil", Size = Vector3.new(length - 0.5, 0.1, 2.5), Position = center + Vector3.new(0, 0.72, 0), Color = P.Soil, Material = Enum.Material.Ground })
	local count = math.floor(length / 1.3)
	for i = 1, count do
		local x = -length / 2 + (i - 0.5) * length / count
		for _, z in { -0.6, 0.6 } do
			local spot = center + Vector3.new(x + rng:NextNumber(-0.25, 0.25), 0, z + rng:NextNumber(-0.2, 0.2))
			Parts.Ellipsoid(parent, spot + Vector3.new(0, 0.95, 0), Vector3.new(1, 0.6, 1), { Name = "Leaves", Color = plants[(i % 3) + 1], Material = Enum.Material.Grass })
			Parts.Ball(parent, spot + Vector3.new(0, 1.35, 0), 0.6, { Name = "Flower", Color = flowers[rng:NextInteger(1, #flowers)] })
		end
	end
end

local function bench(parent: Instance, position: Vector3, yaw: number)
	local base = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	Parts.Part(parent, { Name = "BenchSeat", Size = Vector3.new(6, 0.4, 1.8), CFrame = base * CFrame.new(0, 1.6, 0), Color = P.Wood, Material = Enum.Material.Wood })
	Parts.Part(parent, { Name = "BenchBack", Size = Vector3.new(6, 1.4, 0.3), CFrame = base * CFrame.new(0, 2.7, 0.8), Color = P.Wood, Material = Enum.Material.Wood })
	for _, x in { -2.5, 2.5 } do
		Parts.Part(parent, { Name = "BenchLeg", Size = Vector3.new(0.5, 1.4, 1.6), CFrame = base * CFrame.new(x, 0.7, 0), Color = P.Navy, Material = Enum.Material.SmoothPlastic })
	end
	Parts.Decor(parent, { Name = "BenchTrim", Size = Vector3.new(6.1, 0.12, 0.35), CFrame = base * CFrame.new(0, 3.45, 0.8), Color = P.Gold, Material = Enum.Material.Foil })
end

local function rock(parent: Instance, position: Vector3, size: number, rng: Random)
	Parts.Decor(parent, {
		Name = "Rock",
		Size = Vector3.new(size, size * 0.6, size * 0.8),
		CFrame = CFrame.new(position + Vector3.new(0, size * 0.2, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
		Color = Color3.fromRGB(130, 128, 124),
		Material = Enum.Material.Slate,
	})
end

function Plaza.Build(parent: Instance, o: Vector3, theme, seed: number, worldId: string)
	local plants = TrainingAreaConfig.Plants[theme.Decor] or TrainingAreaConfig.Plants.Trees
	local flowers = TrainingAreaConfig.Flowers
	local rng = Random.new(seed)
	local c = o + Layout.Center

	local model = Instance.new("Model")
	model.Name = "Plaza"
	model.Parent = parent

	-- Extend the hub's stone plaza behind the pavilion (same foundation and paving as the hub).
	local env = EnvironmentConfig[worldId] or EnvironmentConfig.Greenfield
	local width = Layout.PlazaMaxX - Layout.PlazaMinX
	local depth = Layout.PlazaMaxZ - HUB_EDGE_Z
	local centerX = (Layout.PlazaMinX + Layout.PlazaMaxX) / 2
	Parts.Part(model, {
		Name = "PlazaFoundation",
		Size = Vector3.new(width, FLOOR_THICKNESS - 0.4, depth),
		Position = flat(o, centerX, HUB_EDGE_Z + depth / 2, -FLOOR_THICKNESS / 2 - 0.2),
		Color = env.StoneDark,
		Material = env.StoneMaterial,
	})
	Parts.Part(model, {
		Name = "PlazaFloor",
		Size = Vector3.new(width, 0.4, depth),
		Position = flat(o, centerX, HUB_EDGE_Z + depth / 2, -0.2),
		Color = env.Floor,
		Material = env.FloorMaterial,
	})

	-- A lawn border framing the pavilion.
	Parts.Decor(model, { Name = "Lawn", Size = Vector3.new(124, 0.1, 70), Position = c + Vector3.new(0, 0.05, 0), Color = plants[1], Material = Enum.Material.Grass })

	-- Curved walkway from the main path, through the arch, to the pavilion steps.
	local walkway = Parts.Bezier(flat(o, -212, 8, 0.11), flat(o, -212, 32, 0.11), flat(o, -240, 58, 0.11), flat(o, -212, 85, 0.11), 14)
	path(model, walkway, 10, true)
	entranceArch(model, flat(o, -212, 15))

	-- Side paths: spawn row to the pavilion's left, and the pavilion's right to the Pet Upgrader.
	path(model, { flat(o, -262, 8, 0.11), flat(o, -262, 84, 0.11) }, 8, false)
	path(model, Parts.Bezier(flat(o, -154, 108, 0.11), flat(o, -140, 100, 0.11), flat(o, -132, 92, 0.11), flat(o, -130, 78, 0.11), 6), 7, false)

	-- Entrance planting.
	planter(model, flat(o, -238, 84), plants, flowers, rng)
	planter(model, flat(o, -186, 84), plants, flowers, rng)
	flowerBed(model, flat(o, -249, 87), 14, plants, flowers, rng)
	flowerBed(model, flat(o, -175, 87), 14, plants, flowers, rng)
	planter(model, flat(o, -272, 156), plants, flowers, rng)
	planter(model, flat(o, -152, 156), plants, flowers, rng)

	bench(model, flat(o, -248, 78), 0)
	bench(model, flat(o, -282, 120), math.rad(-90))

	-- Trees frame the scene at the edges, never in the middle.
	tree(model, flat(o, -282, 178), plants, 1.1)
	tree(model, flat(o, -252, 185), plants, 0.9)
	tree(model, flat(o, -172, 185), plants, 1)
	tree(model, flat(o, -146, 176), plants, 1.15)
	tree(model, flat(o, -284, 146), plants, 0.85)
	tree(model, flat(o, -280, 60), plants, 0.9)

	rock(model, flat(o, -274, 168), 3.2, rng)
	rock(model, flat(o, -158, 162), 2.6, rng)
	rock(model, flat(o, -170, 40), 2.4, rng)
	rock(model, flat(o, -252, 40), 2.8, rng)

	-- Gentle grassy mounds along the back edge.
	Parts.Ellipsoid(model, flat(o, -232, 186, -0.6), Vector3.new(46, 5, 14), { Name = "Mound", Color = plants[1], Material = Enum.Material.Grass })
	Parts.Ellipsoid(model, flat(o, -168, 185, -0.6), Vector3.new(30, 4, 12), { Name = "Mound", Color = plants[3], Material = Enum.Material.Grass })
	-- (Far-off hills and mountains come from the world's terrain; see World/Landscape.)
end

return Plaza
