-- The training pavilion: a two-tier stone platform, eight pillars, a gabled navy roof with gold
-- trim, the TRAINING GROUNDS sign, lanterns, banners and the beam the bags hang from.
--
-- Built around `c`, the center of the floor at hub level. The front faces -Z (toward the main path).
--
--   platform  116 x 62 lower tier, 108 x 56 marble upper tier (top at y = 1.2)
--   pillars   x = -50, -18, 18, 50 at z = -24 and z = 24
--   roof      eave at y 22.4-23.6, ridge at y 32.6
--   beam      x = -51..51 at z = 0, underside at y = 21.2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local TrainingAreaConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.TrainingAreaConfig)
local Parts = require(script.Parent.Parent.Parts)

local P = TrainingAreaConfig.Palette
local Layout = TrainingAreaConfig.Layout

local PILLAR_X = { -50, -18, 18, 50 }
local PILLAR_Z = { -24, 24 }
local EAVE_Y = 23 -- center of the eave slab
local EAVE_DEPTH = 64
local EAVE_WIDTH = 120

local Pavilion = {}

local function platform(model: Instance, at: (number, number, number) -> Vector3)
	Parts.Part(model, { Name = "LowerTier", Size = Vector3.new(116, 0.6, 62), Position = at(0, 0.3, 0), Color = P.Stone, Material = Enum.Material.Limestone })
	Parts.Part(model, { Name = "Floor", Size = Vector3.new(108, 0.6, 56), Position = at(0, 0.9, 0), Color = P.Marble, Material = Enum.Material.Marble })
	Parts.Part(model, { Name = "EntranceStep", Size = Vector3.new(44, 0.3, 3), Position = at(0, 0.15, -32.5), Color = P.Stone, Material = Enum.Material.Limestone })

	-- Gold trim along both tiers and the step's nose.
	for _, z in { -31, 31 } do
		Parts.Decor(model, { Name = "Trim", Size = Vector3.new(116, 0.12, 0.4), Position = at(0, 0.66, z), Color = P.Gold, Material = Enum.Material.Foil })
	end
	for _, x in { -58, 58 } do
		Parts.Decor(model, { Name = "Trim", Size = Vector3.new(0.4, 0.12, 62), Position = at(x, 0.66, 0), Color = P.Gold, Material = Enum.Material.Foil })
	end
	for _, z in { -28, 28 } do
		Parts.Decor(model, { Name = "Trim", Size = Vector3.new(108, 0.12, 0.5), Position = at(0, 1.26, z), Color = P.Gold, Material = Enum.Material.Foil })
	end
	for _, x in { -54, 54 } do
		Parts.Decor(model, { Name = "Trim", Size = Vector3.new(0.5, 0.12, 56), Position = at(x, 1.26, 0), Color = P.Gold, Material = Enum.Material.Foil })
	end
	Parts.Decor(model, { Name = "StepNose", Size = Vector3.new(44, 0.1, 0.35), Position = at(0, 0.33, -33.8), Color = P.Gold, Material = Enum.Material.Foil })

	-- Navy runner under the bags, edged with thin cyan lines.
	Parts.Decor(model, { Name = "Runner", Size = Vector3.new(100, 0.06, 14), Position = at(0, 1.23, 0), Color = P.Navy, Material = Enum.Material.SmoothPlastic })
	for _, z in { -7, 7 } do
		Parts.Decor(model, { Name = "RunnerLine", Size = Vector3.new(100, 0.08, 0.25), Position = at(0, 1.24, z), Color = P.Cyan, Material = Enum.Material.Neon })
	end
	-- Entrance runner leading in from the step.
	Parts.Decor(model, { Name = "EntranceRunner", Size = Vector3.new(10, 0.06, 21), Position = at(0, 1.23, -17.5), Color = P.Navy, Material = Enum.Material.SmoothPlastic })
end

local function pillar(model: Instance, position: Vector3)
	local floor = Layout.FloorHeight
	Parts.Part(model, { Name = "PillarBase", Size = Vector3.new(4.6, 1.4, 4.6), Position = position + Vector3.new(0, floor + 0.7, 0), Color = P.Stone, Material = Enum.Material.Limestone })
	Parts.Cylinder(model, position + Vector3.new(0, floor + 1.57, 0), 0.35, 4, { Name = "PillarRing", Color = P.Gold, Material = Enum.Material.Foil })
	Parts.Cylinder(model, position + Vector3.new(0, 11.98, 0), 18.05, 3, { Name = "PillarShaft", Color = P.Navy, Material = Enum.Material.SmoothPlastic, CastShadow = true }, true)
	Parts.Cylinder(model, position + Vector3.new(0, 19.8, 0), 0.25, 3.15, { Name = "PillarGlow", Color = P.Cyan, Material = Enum.Material.Neon })
	Parts.Part(model, { Name = "PillarCap", Size = Vector3.new(4.6, 1, 4.6), Position = position + Vector3.new(0, 21.5, 0), Color = P.Stone, Material = Enum.Material.Limestone })
	Parts.Decor(model, { Name = "PillarCapTrim", Size = Vector3.new(5.2, 0.4, 5.2), Position = position + Vector3.new(0, 22.2, 0), Color = P.Gold, Material = Enum.Material.Foil })
end

local function lantern(model: Instance, top: Vector3, withLight: boolean)
	Parts.Decor(model, { Name = "LanternChain", Size = Vector3.new(0.2, 2, 0.2), Position = top - Vector3.new(0, 1, 0), Color = P.DeepNavy })
	Parts.Decor(model, { Name = "LanternCap", Size = Vector3.new(1.4, 0.3, 1.4), Position = top - Vector3.new(0, 2.15, 0), Color = P.Gold, Material = Enum.Material.Foil })
	local glow = Parts.Decor(model, { Name = "Lantern", Size = Vector3.new(1, 1.4, 1), Position = top - Vector3.new(0, 3, 0), Color = P.WarmLight, Material = Enum.Material.Neon })
	Parts.Decor(model, { Name = "LanternBase", Size = Vector3.new(1.2, 0.25, 1.2), Position = top - Vector3.new(0, 3.82, 0), Color = P.Gold, Material = Enum.Material.Foil })
	if withLight then
		local light = Instance.new("PointLight")
		light.Color = P.WarmLight
		light.Range = 16
		light.Brightness = 1
		light.Shadows = false
		light.Parent = glow
	end
end

local function roof(model: Instance, at: (number, number, number) -> Vector3)
	Parts.Part(model, { Name = "Eave", Size = Vector3.new(EAVE_WIDTH, 1.2, EAVE_DEPTH), Position = at(0, EAVE_Y, 0), Color = P.Navy, Material = Enum.Material.SmoothPlastic })

	-- Gold fascia strips around the eave and a cyan glow line under the front edge.
	for _, z in { -EAVE_DEPTH / 2, EAVE_DEPTH / 2 } do
		Parts.Decor(model, { Name = "EaveTrim", Size = Vector3.new(EAVE_WIDTH + 0.4, 0.35, 0.4), Position = at(0, EAVE_Y + 0.45, z), Color = P.Gold, Material = Enum.Material.Foil })
	end
	for _, x in { -EAVE_WIDTH / 2, EAVE_WIDTH / 2 } do
		Parts.Decor(model, { Name = "EaveTrim", Size = Vector3.new(0.4, 0.35, EAVE_DEPTH + 0.4), Position = at(x, EAVE_Y + 0.45, 0), Color = P.Gold, Material = Enum.Material.Foil })
	end
	Parts.Decor(model, { Name = "EaveGlow", Size = Vector3.new(EAVE_WIDTH - 2, 0.15, 0.3), Position = at(0, EAVE_Y - 0.65, -EAVE_DEPTH / 2 + 0.4), Color = P.Cyan, Material = Enum.Material.Neon })

	-- Gabled roof: two wedges meeting at a ridge along X. A wedge's high side is its back (+Z).
	local eaveTop = EAVE_Y + 0.6
	local height = 9
	local half = EAVE_DEPTH / 2
	Parts.Part(model, {
		Name = "RoofFront",
		Size = Vector3.new(EAVE_WIDTH, height, half),
		CFrame = CFrame.new(at(0, eaveTop + height / 2, -half / 2)),
		Color = P.Roof,
		Material = Enum.Material.Slate,
		CastShadow = true,
	}, "WedgePart")
	Parts.Part(model, {
		Name = "RoofBack",
		Size = Vector3.new(EAVE_WIDTH, height, half),
		CFrame = CFrame.new(at(0, eaveTop + height / 2, half / 2)) * CFrame.Angles(0, math.pi, 0),
		Color = P.Roof,
		Material = Enum.Material.Slate,
		CastShadow = true,
	}, "WedgePart")
	local ridgeY = eaveTop + height
	Parts.Decor(model, {
		Name = "Ridge",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(EAVE_WIDTH + 2, 1.6, 1.6),
		Position = at(0, ridgeY, 0),
		Color = P.Gold,
		Material = Enum.Material.Foil,
	})
	for _, x in { -EAVE_WIDTH / 2 - 1, EAVE_WIDTH / 2 + 1 } do
		Parts.Ball(model, at(x, ridgeY, 0), 2.2, { Name = "RidgeFinial", Color = P.Gold, Material = Enum.Material.Foil })
	end
	for _, x in { -EAVE_WIDTH / 2, EAVE_WIDTH / 2 } do
		for _, z in { -EAVE_DEPTH / 2, EAVE_DEPTH / 2 } do
			Parts.Ball(model, at(x, EAVE_Y + 0.9, z), 1.4, { Name = "CornerFinial", Color = P.Gold, Material = Enum.Material.Foil })
		end
	end

	-- Emblem on the ridge: a gold orb with two slowly spinning cyan rings (animated by the client).
	local emblemCenter = at(0, ridgeY + 3.4, 0)
	Parts.Cylinder(model, at(0, ridgeY + 1.2, 0), 1.6, 2.2, { Name = "EmblemStand", Color = P.Navy })
	Parts.Ball(model, emblemCenter, 2.6, { Name = "EmblemOrb", Color = P.Gold, Material = Enum.Material.Foil })
	for i, tilt in { math.rad(70), math.rad(-70) } do
		local base = CFrame.Angles(0, (i - 1) * math.pi / 2, 0) * CFrame.Angles(0, 0, tilt)
		local ring = Parts.Decor(model, {
			Name = "EmblemRing",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.18, 5, 5),
			CFrame = CFrame.new(emblemCenter) * base,
			Color = P.Cyan,
			Material = Enum.Material.Neon,
			Transparency = 0.25,
		})
		ring:SetAttribute("Center", emblemCenter)
		ring:SetAttribute("BaseRotation", base)
		ring:SetAttribute("Speed", 0.8)
		CollectionService:AddTag(ring, TrainingAreaConfig.Tags.Spin)
	end
end

local function facadeSign(model: Instance, at: (number, number, number) -> Vector3)
	local z = -EAVE_DEPTH / 2 - 0.3
	Parts.Part(model, { Name = "SignFrame", Size = Vector3.new(46, 7.4, 0.6), Position = at(0, 27.3, z), Color = P.Gold, Material = Enum.Material.Foil })
	local board = Parts.Part(model, { Name = "SignBoard", Size = Vector3.new(44.4, 6, 0.4), Position = at(0, 27.3, z - 0.45), Color = P.DeepNavy, Material = Enum.Material.SmoothPlastic })
	local label = Parts.SurfaceText(board, Enum.NormalId.Front, "TRAINING GROUNDS", P.Gold, 24)
	label.Size = UDim2.fromScale(0.94, 0.8)
	label.Position = UDim2.fromScale(0.03, 0.1)
end

local function banners(model: Instance, at: (number, number, number) -> Vector3)
	-- Navy banners with gold edges on the front face of each front pillar.
	for _, x in PILLAR_X do
		local center = at(x, 14, -24 - 1.65)
		local banner = Parts.Decor(model, { Name = "Banner", Size = Vector3.new(2.6, 7, 0.12), Position = center, Color = P.DeepNavy, Material = Enum.Material.Fabric })
		Parts.Decor(model, { Name = "BannerRod", Size = Vector3.new(3.2, 0.25, 0.25), Position = center + Vector3.new(0, 3.6, 0), Color = P.Gold, Material = Enum.Material.Foil })
		Parts.Decor(model, { Name = "BannerTip", Size = Vector3.new(2.6, 0.35, 0.14), Position = center - Vector3.new(0, 3.6, 0), Color = P.Gold, Material = Enum.Material.Foil })
		local icon = Parts.SurfaceText(banner, Enum.NormalId.Front, "🥊", P.Gold, 30)
		icon.Size = UDim2.fromScale(1, 0.4)
		icon.Position = UDim2.fromScale(0, 0.3)
	end
end

function Pavilion.Build(model: Instance, c: Vector3)
	local function at(x: number, y: number, z: number): Vector3
		return c + Vector3.new(x, y, z)
	end

	platform(model, at)
	for _, x in PILLAR_X do
		for _, z in PILLAR_Z do
			pillar(model, at(x, 0, z))
		end
	end
	roof(model, at)
	facadeSign(model, at)
	banners(model, at)

	-- Beam the bags hang from, tucked against the underside of the eave.
	Parts.Part(model, { Name = "BagBeam", Size = Vector3.new(102, 1.2, 1.6), Position = at(0, Layout.BeamBottom + 0.6, 0), Color = P.DeepNavy, Material = Enum.Material.SmoothPlastic })
	Parts.Decor(model, { Name = "BeamTrim", Size = Vector3.new(102.2, 0.2, 1.7), Position = at(0, Layout.BeamBottom + 0.1, 0), Color = P.Gold, Material = Enum.Material.Foil })

	-- Lanterns hang from the eave beside each pillar; only the front ones cast light.
	for _, x in PILLAR_X do
		lantern(model, at(x, EAVE_Y - 0.6, -EAVE_DEPTH / 2 + 1.5), true)
		lantern(model, at(x, EAVE_Y - 0.6, EAVE_DEPTH / 2 - 1.5), false)
	end

	-- Warm fill light under the roof so the bags read clearly.
	for _, x in { -26, 26 } do
		local anchor = Parts.Decor(model, { Name = "FillLight", Size = Vector3.one, Transparency = 1, Position = at(x, 17, 0) })
		local light = Instance.new("PointLight")
		light.Color = P.WarmLight
		light.Range = 36
		light.Brightness = 0.9
		light.Shadows = false
		light.Parent = anchor
	end
end

return Pavilion
