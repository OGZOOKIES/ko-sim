-- Themed scenery props, each built from a handful of shaped parts (all non-colliding).
-- Props.Place(parent, style, position, rng, colors) picks a prop that suits the world:
--   Groves     round and tall stylized trees, bushes, mossy rocks
--   Oasis      leaning palms, saguaro cacti, broken sandstone columns
--   Pines      snowy pines, ice crystals, snow-capped rocks
--   Volcanic   dead trees, obsidian spires, glowing lava rocks
--   Asteroids  floating crystal clusters and rock chunks

local Parts = require(script.Parent.Parts)

local Props = {}

local V = Vector3.new
local rgb = Color3.fromRGB

local function yaw(rng: Random): CFrame
	return CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
end

local function rock(parent: Instance, position: Vector3, size: number, color: Color3, material: Enum.Material, rng: Random): BasePart
	return Parts.Decor(parent, {
		Name = "Rock",
		Size = V(size, size * 0.62, size * 0.85),
		CFrame = CFrame.new(position + V(0, size * 0.2, 0)) * yaw(rng) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25)),
		Color = color,
		Material = material,
		CastShadow = true,
	})
end

-- Greenfield

local function roundTree(parent: Instance, p: Vector3, rng: Random, colors: { Color3 })
	local s = rng:NextNumber(0.85, 1.3)
	local trunk = 9 * s
	Parts.Cylinder(parent, p + V(0, 0.5, 0), 1, 3.2 * s, { Name = "Roots", Color = rgb(98, 68, 44), Material = Enum.Material.Wood })
	Parts.Cylinder(parent, p + V(0, trunk / 2, 0), trunk, 1.8 * s, { Name = "Trunk", Color = rgb(112, 78, 50), Material = Enum.Material.Wood, CastShadow = true })
	Parts.Ball(parent, p + V(0, trunk + 2.6 * s, 0), 10 * s, { Name = "Canopy", Color = colors[1], Material = Enum.Material.Grass, CastShadow = true })
	Parts.Ball(parent, p + V(3 * s, trunk + 1 * s, 1.4 * s), 7 * s, { Name = "Canopy", Color = colors[2], Material = Enum.Material.Grass, CastShadow = true })
	Parts.Ball(parent, p + V(-2.6 * s, trunk + 1.4 * s, -1.8 * s), 6.6 * s, { Name = "Canopy", Color = colors[3], Material = Enum.Material.Grass, CastShadow = true })
end

local function tallTree(parent: Instance, p: Vector3, rng: Random, colors: { Color3 })
	local s = rng:NextNumber(0.9, 1.25)
	Parts.Cylinder(parent, p + V(0, 4 * s, 0), 8 * s, 1.4 * s, { Name = "Trunk", Color = rgb(112, 78, 50), Material = Enum.Material.Wood, CastShadow = true })
	Parts.Ellipsoid(parent, p + V(0, 12 * s, 0), V(7, 15, 7) * s, { Name = "Canopy", Color = colors[3], Material = Enum.Material.Grass, CastShadow = true })
	Parts.Ellipsoid(parent, p + V(0.6, 14.5 * s, 0.4), V(5, 9, 5) * s, { Name = "Canopy", Color = colors[2], Material = Enum.Material.Grass })
end

local function bush(parent: Instance, p: Vector3, rng: Random, colors: { Color3 })
	for i = 1, 3 do
		local size = rng:NextNumber(2.6, 4.2)
		Parts.Ellipsoid(parent, p + V(rng:NextNumber(-2, 2), size * 0.3, rng:NextNumber(-2, 2)), V(size, size * 0.8, size), { Name = "Bush", Color = colors[(i % 3) + 1], Material = Enum.Material.Grass })
	end
end

-- Desert

local function palm(parent: Instance, p: Vector3, rng: Random, colors: { Color3 })
	local lean = yaw(rng)
	local top = p
	local tilt = 0
	for i = 1, 4 do
		tilt += rng:NextNumber(0.06, 0.12)
		local segment = CFrame.new(top) * lean * CFrame.Angles(tilt, 0, 0)
		local center = segment * CFrame.new(0, 2.2, 0)
		Parts.Decor(parent, {
			Name = "PalmTrunk",
			Shape = Enum.PartType.Cylinder,
			Size = V(4.6, 1.3 - i * 0.1, 1.3 - i * 0.1),
			CFrame = center * CFrame.Angles(0, 0, math.rad(90)),
			Color = rgb(150, 112, 70):Lerp(rgb(120, 88, 56), i / 4),
			Material = Enum.Material.Wood,
			CastShadow = true,
		})
		top = (segment * CFrame.new(0, 4.3, 0)).Position
	end
	for i = 0, 6 do
		local frond = CFrame.new(top) * CFrame.Angles(0, i * math.pi * 2 / 7, 0) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.new(0, 0, -3)
		Parts.Decor(parent, { Name = "Frond", Size = V(1.6, 0.2, 6.5), CFrame = frond, Color = colors[(i % 2) + 1], Material = Enum.Material.Grass, CastShadow = true })
	end
	for i = 0, 2 do
		Parts.Ball(parent, top + V(math.cos(i * 2.1) * 0.6, -0.5, math.sin(i * 2.1) * 0.6), 0.7, { Name = "Coconut", Color = rgb(110, 76, 44) })
	end
end

local function cactus(parent: Instance, p: Vector3, rng: Random, colors: { Color3 })
	local height = rng:NextNumber(8, 13)
	local green = colors[1]
	Parts.Cylinder(parent, p + V(0, height / 2, 0), height, 2.6, { Name = "Cactus", Color = green, Material = Enum.Material.Grass, CastShadow = true })
	Parts.Ball(parent, p + V(0, height, 0), 2.6, { Name = "CactusTop", Color = green, Material = Enum.Material.Grass })
	for _, side in { -1, 1 } do
		local armY = height * rng:NextNumber(0.4, 0.6)
		Parts.Decor(parent, { Name = "CactusArm", Size = V(2.4, 1.6, 1.6), Position = p + V(side * 1.8, armY, 0), Color = green, Material = Enum.Material.Grass })
		Parts.Cylinder(parent, p + V(side * 2.9, armY + 1.6, 0), 3.4, 1.6, { Name = "CactusArm", Color = green, Material = Enum.Material.Grass })
		Parts.Ball(parent, p + V(side * 2.9, armY + 3.3, 0), 1.6, { Name = "CactusArmTop", Color = green, Material = Enum.Material.Grass })
	end
end

local function column(parent: Instance, p: Vector3, rng: Random)
	local height = rng:NextNumber(6, 14)
	local sand = rgb(214, 180, 128)
	Parts.Decor(parent, { Name = "ColumnBase", Size = V(4, 1, 4), Position = p + V(0, 0.5, 0), Color = sand, Material = Enum.Material.Sandstone, CastShadow = true })
	Parts.Cylinder(parent, p + V(0, 1 + height / 2, 0), height, 2.8, { Name = "Column", Color = sand, Material = Enum.Material.Sandstone, CastShadow = true })
	if rng:NextNumber() < 0.5 then
		Parts.Decor(parent, { Name = "Capital", Size = V(3.8, 1, 3.8), Position = p + V(0, 1.5 + height, 0), Color = sand, Material = Enum.Material.Sandstone })
	else
		rock(parent, p + V(3, 0, 1), 2.6, sand, Enum.Material.Sandstone, rng)
	end
end

-- Frostbite

local function pine(parent: Instance, p: Vector3, rng: Random, colors: { Color3 })
	local s = rng:NextNumber(0.9, 1.4)
	Parts.Cylinder(parent, p + V(0, 2 * s, 0), 4 * s, 1.2 * s, { Name = "Trunk", Color = rgb(86, 62, 44), Material = Enum.Material.Wood })
	for tier = 0, 2 do
		local width = (7 - tier * 1.9) * s
		local y = (4 + tier * 3.6) * s
		Parts.Ellipsoid(parent, p + V(0, y, 0), V(width, 4.4 * s, width), { Name = "Needles", Color = colors[1], Material = Enum.Material.Grass, CastShadow = true })
		Parts.Ellipsoid(parent, p + V(0, y + 1.3 * s, 0), V(width * 0.8, 1.6 * s, width * 0.8), { Name = "Snow", Color = colors[2], Material = Enum.Material.Snow })
	end
end

local function iceCrystals(parent: Instance, p: Vector3, rng: Random, colors: { Color3 })
	for _ = 1, rng:NextInteger(3, 5) do
		local height = rng:NextNumber(3, 9)
		Parts.Decor(parent, {
			Name = "IceCrystal",
			Size = V(1.4, height, 1.4),
			CFrame = CFrame.new(p + V(rng:NextNumber(-2, 2), height / 2 - 0.5, rng:NextNumber(-2, 2)))
				* CFrame.Angles(rng:NextNumber(-0.35, 0.35), rng:NextNumber(0, math.pi), rng:NextNumber(-0.35, 0.35)),
			Color = colors[3],
			Material = Enum.Material.Glass,
			Transparency = 0.2,
		})
	end
end

-- Inferno

local function deadTree(parent: Instance, p: Vector3, rng: Random)
	local dark = rgb(38, 30, 28)
	local height = rng:NextNumber(8, 12)
	Parts.Cylinder(parent, p + V(0, height / 2, 0), height, 1.3, { Name = "DeadTrunk", Color = dark, Material = Enum.Material.Wood, CastShadow = true })
	for i = 1, 3 do
		local branch = CFrame.new(p + V(0, height * (0.45 + i * 0.15), 0)) * CFrame.Angles(0, i * 2.1 + rng:NextNumber(), 0) * CFrame.Angles(0, 0, math.rad(50)) * CFrame.new(0, 2, 0)
		Parts.Decor(parent, { Name = "Branch", Size = V(0.5, 4, 0.5), CFrame = branch, Color = dark, Material = Enum.Material.Wood })
	end
end

local function spire(parent: Instance, p: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(2, 3) do
		local height = rng:NextNumber(7, 16)
		Parts.Decor(parent, {
			Name = "ObsidianSpire",
			Size = V(2.2, height, 2.2),
			CFrame = CFrame.new(p + V(rng:NextNumber(-2.5, 2.5), height / 2 - 1, rng:NextNumber(-2.5, 2.5)))
				* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi), rng:NextNumber(-0.25, 0.25)),
			Color = rgb(22, 18, 26),
			Material = Enum.Material.Glass,
			CastShadow = true,
		})
	end
end

local function lavaRock(parent: Instance, p: Vector3, rng: Random, colors: { Color3 })
	local stone = rock(parent, p, rng:NextNumber(4, 7), rgb(54, 44, 42), Enum.Material.Basalt, rng)
	Parts.Decor(parent, { Name = "LavaCrack", Size = V(stone.Size.X * 0.8, 0.15, 0.3), CFrame = stone.CFrame * CFrame.new(0, stone.Size.Y / 2, 0), Color = colors[2], Material = Enum.Material.Neon })
end

-- Cosmic

local function crystalCluster(parent: Instance, p: Vector3, rng: Random, colors: { Color3 })
	local color = colors[rng:NextInteger(1, #colors)]
	Parts.Decor(parent, { Name = "CrystalRock", Size = V(5, 2, 5), CFrame = CFrame.new(p) * yaw(rng), Color = rgb(52, 46, 80), Material = Enum.Material.Slate })
	for _ = 1, rng:NextInteger(3, 5) do
		local height = rng:NextNumber(2.5, 7)
		Parts.Decor(parent, {
			Name = "SpaceCrystal",
			Size = V(1.1, height, 1.1),
			CFrame = CFrame.new(p + V(rng:NextNumber(-1.6, 1.6), height / 2 + 0.6, rng:NextNumber(-1.6, 1.6)))
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(-0.4, 0.4)),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		})
	end
end

function Props.Place(parent: Instance, style: string, position: Vector3, rng: Random, colors: { Color3 })
	local roll = rng:NextNumber()
	if style == "Groves" then
		if roll < 0.45 then
			roundTree(parent, position, rng, colors)
		elseif roll < 0.7 then
			tallTree(parent, position, rng, colors)
		elseif roll < 0.9 then
			bush(parent, position, rng, colors)
		else
			rock(parent, position, rng:NextNumber(3, 6), rgb(128, 126, 120), Enum.Material.Slate, rng)
		end
	elseif style == "Oasis" then
		if roll < 0.4 then
			palm(parent, position, rng, colors)
		elseif roll < 0.7 then
			cactus(parent, position, rng, colors)
		elseif roll < 0.85 then
			column(parent, position, rng)
		else
			rock(parent, position, rng:NextNumber(3, 7), rgb(196, 150, 100), Enum.Material.Sandstone, rng)
		end
	elseif style == "Pines" then
		if roll < 0.65 then
			pine(parent, position, rng, colors)
		elseif roll < 0.85 then
			iceCrystals(parent, position, rng, colors)
		else
			local stone = rock(parent, position, rng:NextNumber(3, 6), rgb(120, 128, 140), Enum.Material.Slate, rng)
			Parts.Ellipsoid(parent, stone.Position + V(0, stone.Size.Y * 0.4, 0), V(stone.Size.X * 0.9, 0.8, stone.Size.Z * 0.9), { Name = "SnowCap", Color = colors[2], Material = Enum.Material.Snow })
		end
	elseif style == "Volcanic" then
		if roll < 0.35 then
			deadTree(parent, position, rng)
		elseif roll < 0.7 then
			spire(parent, position, rng)
		else
			lavaRock(parent, position, rng, colors)
		end
	elseif style == "Asteroids" then
		crystalCluster(parent, position, rng, colors)
	end
end

-- A tree that suits the world, for lawns and planters around the hub.
function Props.Tree(parent: Instance, style: string, position: Vector3, rng: Random, colors: { Color3 })
	if style == "Groves" then
		roundTree(parent, position, rng, colors)
	elseif style == "Oasis" then
		palm(parent, position, rng, colors)
	elseif style == "Pines" then
		pine(parent, position, rng, colors)
	elseif style == "Volcanic" then
		deadTree(parent, position, rng)
	else
		crystalCluster(parent, position, rng, colors)
	end
end

return Props
