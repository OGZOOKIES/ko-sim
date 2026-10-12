-- Builds glove models from Config/GloveDesigns. The same builder makes the gloves characters wear
-- (server) and the shop previews (client), so what you buy is exactly what you wear.
--
-- How the shapes are made
--   There are no imported meshes in this project, so gloves are built from Roblox primitives,
--   chosen to stay smooth: every main volume is an ellipsoid (a Part with a sphere SpecialMesh),
--   thumbs and fingers are capsule-like ellipsoids aligned along their bones, and armour is
--   "lens" plates (very thin ellipsoids) that curve at the edges. Details are placed with
--   `surfaceFrame`, which finds a point and its normal on the glove's reference shell, so plates,
--   seams, rivets and emblems sit ON the surface and follow its curve instead of floating.
--
-- Glove space (right hand, before scaling), hand at the origin, arm hanging down:
--   +Y  wrist and cuff          -Y  fist end (the striking face when punching)
--   +X  back of the hand        -X  palm
--   -Z  thumb side (front)      +Z  little-finger side
-- Left gloves are mirrored across X. This matches R15 hands and R6 arms, so the thumb faces
-- forward and the back of the hand faces outward on both sides of the body.
--
-- API
--   GloveBuilder.Build(gloveId, side, scale?) -> Model     anchored, centred on the hand
--   GloveBuilder.BuildPair(gloveId, scale?) -> Model       both gloves, backs facing -Z, for display
--   GloveBuilder.Attach(character, gloveId)                replaces the character's gloves (R6/R15)

local GloveDesigns = require(script.Parent.Parent.Config.GloveDesigns)

local GloveBuilder = {}

local V = Vector3.new
local rad = math.rad

local OPENING = Color3.fromRGB(18, 16, 20)

type Ref = { C: Vector3, R: Vector3 }
type CuffSpec = { Y: number, D: number, H: number }
type ShellSpec = { Kind: string, Ref: Ref, Cuff: CuffSpec, Claws: boolean? }

-- Each shell's reference ellipsoid (the main hand volume) and cuff.
local SHELLS: { [string]: ShellSpec } = {
	Mitt = { Kind = "Padded", Ref = { C = V(0, -0.32, 0), R = V(0.66, 0.84, 0.72) }, Cuff = { Y = 0.3, D = 1.22, H = 0.78 } },
	Boxing = { Kind = "Padded", Ref = { C = V(0, -0.42, 0), R = V(0.72, 0.95, 0.8) }, Cuff = { Y = 0.34, D = 1.28, H = 0.86 } },
	Heavy = { Kind = "Padded", Ref = { C = V(0, -0.45, 0), R = V(0.8, 1, 0.88) }, Cuff = { Y = 0.36, D = 1.38, H = 0.92 } },
	Combat = { Kind = "Combat", Ref = { C = V(0, -0.3, 0), R = V(0.6, 0.8, 0.68) }, Cuff = { Y = 0.28, D = 1.14, H = 0.72 } },
	Gauntlet = { Kind = "Gauntlet", Ref = { C = V(0, -0.3, 0), R = V(0.62, 0.8, 0.7) }, Cuff = { Y = 0.3, D = 1.22, H = 0.98 } },
	Claw = { Kind = "Gauntlet", Ref = { C = V(0, -0.3, 0), R = V(0.62, 0.8, 0.7) }, Cuff = { Y = 0.3, D = 1.22, H = 0.98 }, Claws = true },
}

-- Knuckle row: four fingers across the back-bottom edge of the hand.
local KNUCKLE_THETAS = { 40, 13, -13, -40 }
local KNUCKLE_PHI = -48
local BACK_PHI = -6

type Ctx = {
	Model: Model,
	Design: GloveDesigns.Design,
	Shell: ShellSpec,
	Scale: number,
	Mirror: boolean,
}

-- Geometry helpers ------------------------------------------------------------------------

local function mirror(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

local function rot(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

-- A frame at `center` whose +Y points along `direction` (for capsules along a bone).
local function alongY(center: Vector3, direction: Vector3): CFrame
	local d = direction.Unit
	if math.abs(d.Y) > 0.999 then
		d = (d + V(0.001, 0, 0.001)).Unit
	end
	return CFrame.lookAt(center, center + d) * CFrame.Angles(-math.pi / 2, 0, 0)
end

-- Point and outward normal on a reference ellipsoid.
-- theta: angle around the hand from the back (+X, 0) toward the thumb side (-Z, 90).
-- phi: latitude (90 = top toward the wrist, -90 = bottom of the fist).
local function surface(ref: Ref, theta: number, phi: number, lift: number?): (Vector3, Vector3)
	local t, p = rad(theta), rad(phi)
	local d = V(math.cos(p) * math.cos(t), math.sin(p), -math.cos(p) * math.sin(t))
	local position = ref.C + d * ref.R
	local normal = V(d.X / ref.R.X, d.Y / ref.R.Y, d.Z / ref.R.Z).Unit
	return position + normal * (lift or 0), normal
end

-- A frame on the surface: Z = outward normal, X = around the hand, Y = up the surface.
local function surfaceFrame(ref: Ref, theta: number, phi: number, lift: number?, spin: number?): CFrame
	local position, normal = surface(ref, theta, phi, lift)
	local u = Vector3.yAxis:Cross(normal)
	if u.Magnitude < 1e-3 then
		u = Vector3.xAxis:Cross(normal)
	end
	u = u.Unit
	local v = normal:Cross(u).Unit
	local frame = CFrame.fromMatrix(position, u, v, normal)
	return if spin then frame * rot(0, 0, spin) else frame
end

-- Colour/material for a key. "Dark" is a deeper Secondary (grain, seams); "Glow" is always Neon.
local function resolve(ctx: Ctx, key: string): (Color3, Enum.Material)
	local design = ctx.Design
	if key == "Glow" then
		return design.Colors.Glow or design.Colors.Accent, Enum.Material.Neon
	elseif key == "Accent" then
		return design.Colors.Accent, Enum.Material.Fabric
	elseif key == "Dark" then
		return design.Colors.Secondary:Lerp(Color3.new(0, 0, 0), 0.4), design.Mats.Secondary
	elseif key == "PrimaryDark" then
		return design.Colors.Primary:Lerp(Color3.new(0, 0, 0), 0.3), design.Mats.Primary
	elseif key == "Opening" then
		return OPENING, Enum.Material.Fabric
	end
	return (design.Colors :: any)[key], (design.Mats :: any)[key]
end

type Options = { Shape: Enum.PartType?, Class: string?, Sphere: boolean?, Transparency: number? }

local function add(ctx: Ctx, name: string, size: Vector3, cf: CFrame, key: string, options: Options?): BasePart
	local part = Instance.new(if options and options.Class then options.Class else "Part") :: BasePart
	if options and options.Shape then
		(part :: Part).Shape = options.Shape
	end
	part.Name = name
	part.Size = size * ctx.Scale
	local placed = CFrame.new(cf.Position * ctx.Scale) * cf.Rotation
	part.CFrame = if ctx.Mirror then mirror(placed) else placed
	local color, material = resolve(ctx, key)
	part.Color = color
	part.Material = material
	if options and options.Transparency then
		part.Transparency = options.Transparency
	elseif material == Enum.Material.Glass or material == Enum.Material.Ice then
		part.Transparency = 0.1
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	if options and options.Sphere then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Parent = ctx.Model
	return part
end

-- Smooth ellipsoid volume.
local function ell(ctx: Ctx, name: string, size: Vector3, cf: CFrame, key: string, transparency: number?): BasePart
	return add(ctx, name, size, cf, key, { Sphere = true, Transparency = transparency })
end

-- Curved armour plate: a thin ellipsoid in a surface frame (Z = thickness along the normal).
local function lens(ctx: Ctx, name: string, frame: CFrame, width: number, height: number, thickness: number, key: string): BasePart
	return ell(ctx, name, V(width, height, thickness), frame, key)
end

-- A rounded bone from a to b (thumb segments, fingers, horns, tail).
local function capsule(ctx: Ctx, name: string, a: Vector3, b: Vector3, thickness: number, key: string): BasePart
	local length = (b - a).Magnitude
	return ell(ctx, name, V(thickness, length + thickness * 0.8, thickness * 0.95), alongY((a + b) / 2, b - a), key)
end

local function ball(ctx: Ctx, name: string, diameter: number, position: Vector3, key: string): BasePart
	return add(ctx, name, V(diameter, diameter, diameter), CFrame.new(position), key, { Shape = Enum.PartType.Ball })
end

-- A thin line along a polyline of points (seams, stitching, energy channels).
local function line(ctx: Ctx, name: string, points: { Vector3 }, width: number, key: string, dashed: boolean?)
	for i = 1, #points - 1 do
		if not dashed or i % 2 == 1 then
			local a, b = points[i], points[i + 1]
			local length = (b - a).Magnitude * (if dashed then 0.7 else 1.04)
			local frame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, rad(90), 0)
			add(ctx, name, V(length, width, width), frame, key, { Shape = Enum.PartType.Cylinder })
		end
	end
end

-- Points along the reference surface from (theta1, phi1) to (theta2, phi2).
local function surfacePath(ref: Ref, theta1: number, phi1: number, theta2: number, phi2: number, steps: number, lift: number): { Vector3 }
	local points = {}
	for i = 0, steps do
		local t = i / steps
		local p = surface(ref, theta1 + (theta2 - theta1) * t, phi1 + (phi2 - phi1) * t, lift)
		table.insert(points, p)
	end
	return points
end

-- An upright cylinder ring around the wrist, centred on the Y axis.
local function ring(ctx: Ctx, name: string, y: number, height: number, diameter: number, key: string, tilt: CFrame?): BasePart
	return add(ctx, name, V(height, diameter, diameter), CFrame.new(0, y, 0) * (tilt or CFrame.identity) * rot(0, 0, 90), key, { Shape = Enum.PartType.Cylinder })
end

-- Shells ------------------------------------------------------------------------------------

local function thumb(ctx: Ctx, ref: Ref, key: string, armored: boolean)
	-- Two segments curving down the thumb side toward the fist, half-sunk into the shell.
	local root = surface(ref, 98, 12, -0.16)
	local middle = surface(ref, 92, -22, -0.04)
	local tip = surface(ref, 76, -50, -0.08)
	capsule(ctx, "Thumb", root, middle, 0.5, key)
	capsule(ctx, "ThumbTip", middle, tip, 0.44, key)
	if armored then
		for i, pair in { { root, middle }, { middle, tip } } do
			local a, b = pair[1], pair[2]
			local center = (a + b) / 2
			local _, normal = surface(ref, 92 - (i - 1) * 12, -15 - (i - 1) * 30)
			local up = (b - a).Unit
			local outward = (normal - up * normal:Dot(up)).Unit
			local frame = CFrame.fromMatrix(center + outward * 0.2, up:Cross(outward), up, outward)
			lens(ctx, "ThumbPlate", frame, 0.36, (b - a).Magnitude * 0.95, 0.1, "Trim")
		end
	end
end

local function wristNeck(ctx: Ctx, ref: Ref)
	-- Smooths the hand into the cuff.
	ell(ctx, "Wrist", V(ref.R.X * 1.62, 0.72, ref.R.Z * 1.62), CFrame.new(0, ref.C.Y + ref.R.Y * 0.8, 0), "Primary")
end

local function paddedShell(ctx: Ctx, ref: Ref)
	local C, R = ref.C, ref.R
	ell(ctx, "Shell", R * 2, CFrame.new(C), "Primary")
	-- The rounded striking end: fuller toward the knuckles and the front.
	ell(ctx, "FistDome", V(R.X * 1.96, R.Y * 1.3, R.Z * 2.06), CFrame.new(C + V(0.02, -R.Y * 0.3, -0.04)), "Primary")
	-- A palm panel that shows as a separate leather section on the palm side.
	ell(ctx, "Palm", V(R.X * 0.92, R.Y * 1.55, R.Z * 1.6), CFrame.new(C + V(-R.X * 0.6, R.Y * 0.05, 0.04)), "Secondary")
	wristNeck(ctx, ref)
	thumb(ctx, ref, ctx.Design.Thumb or "Primary", false)
end

-- Curled fingers: proximal segments across the bottom, middle segments curling up the palm side.
local function fingers(ctx: Ctx, ref: Ref, key: string, plateKey: string?, claws: boolean)
	local C, R = ref.C, ref.R
	for i, theta in KNUCKLE_THETAS do
		local knuckle = surface(ref, theta, KNUCKLE_PHI, -0.06)
		local z = knuckle.Z
		local bottom = C + V(R.X * 0.05, -R.Y * 1.02, z * 0.95)
		local curl = C + V(-R.X * 0.6, -R.Y * 0.72, z * 0.88)
		local width = 0.3 - math.abs(i - 2.5) * 0.02
		capsule(ctx, "Finger", knuckle, bottom, width, key)
		capsule(ctx, "FingerTip", bottom, curl, width * 0.9, key)
		if plateKey then
			local up = (bottom - knuckle).Unit
			local outward = ((knuckle + bottom) / 2 - C)
			outward = (outward - up * outward:Dot(up)).Unit
			local frame = CFrame.fromMatrix((knuckle + bottom) / 2 + outward * width * 0.42, up:Cross(outward), up, outward)
			lens(ctx, "FingerPlate", frame, width * 1.1, (bottom - knuckle).Magnitude * 0.92, 0.08, plateKey)
		end
		if claws then
			local direction = V(0.25, -1, -0.12).Unit
			capsule(ctx, "Talon", bottom, bottom + direction * 0.55, 0.13, "Trim")
		end
	end
end

local function combatShell(ctx: Ctx, ref: Ref)
	local C, R = ref.C, ref.R
	ell(ctx, "Shell", R * 2, CFrame.new(C), "Primary")
	ell(ctx, "Palm", V(R.X * 0.9, R.Y * 1.5, R.Z * 1.55), CFrame.new(C + V(-R.X * 0.58, R.Y * 0.06, 0.02)), "Secondary")
	wristNeck(ctx, ref)
	fingers(ctx, ref, "Secondary", nil, false)
	thumb(ctx, ref, ctx.Design.Thumb or "Secondary", false)
end

local function gauntletShell(ctx: Ctx, ref: Ref)
	local C, R = ref.C, ref.R
	ell(ctx, "Shell", R * 2, CFrame.new(C), "Primary")
	ell(ctx, "Palm", V(R.X * 0.9, R.Y * 1.45, R.Z * 1.55), CFrame.new(C + V(-R.X * 0.58, R.Y * 0.08, 0.02)), "PrimaryDark")
	wristNeck(ctx, ref)
	fingers(ctx, ref, "PrimaryDark", "Secondary", ctx.Shell.Claws == true)
	thumb(ctx, ref, ctx.Design.Thumb or "PrimaryDark", true)
end

-- Knuckles -------------------------------------------------------------------------------

local function knuckleFrames(ref: Ref, lift: number): { CFrame }
	local frames = {}
	for _, theta in KNUCKLE_THETAS do
		table.insert(frames, surfaceFrame(ref, theta, KNUCKLE_PHI, lift))
	end
	return frames
end

local function guard(ctx: Ctx, ref: Ref)
	-- One curved plate over the whole knuckle row, on a slightly larger piped backing.
	local frame = surfaceFrame(ref, 0, KNUCKLE_PHI, 0.02)
	lens(ctx, "GuardPiping", frame, ref.R.Z * 1.9, 0.72, 0.14, "Dark")
	lens(ctx, "KnuckleGuard", frame * CFrame.new(0, 0, 0.04), ref.R.Z * 1.78, 0.62, 0.18, "Trim")
	return frame
end

local Knuckles = {}

function Knuckles.Padded(ctx: Ctx, ref: Ref)
	lens(ctx, "KnucklePad", surfaceFrame(ref, 0, KNUCKLE_PHI, 0.02), ref.R.Z * 1.7, 0.56, 0.34, "Secondary")
end

function Knuckles.Ridge(ctx: Ctx, ref: Ref)
	-- Rounded knuckles half-sunk into the shell so they read as part of it.
	for _, frame in knuckleFrames(ref, -0.06) do
		ell(ctx, "Knuckle", V(0.36, 0.42, 0.36), frame, "Primary")
	end
end

function Knuckles.Plates(ctx: Ctx, ref: Ref)
	for _, frame in knuckleFrames(ref, 0.04) do
		lens(ctx, "KnucklePlate", frame, 0.36, 0.44, 0.13, "Trim")
		ball(ctx, "Rivet", 0.09, (frame * CFrame.new(0, -0.12, 0.08)).Position, "Accent")
	end
	lens(ctx, "PlateBacking", surfaceFrame(ref, 0, KNUCKLE_PHI, 0), ref.R.Z * 1.8, 0.5, 0.12, "Secondary")
end

function Knuckles.Guard(ctx: Ctx, ref: Ref)
	guard(ctx, ref)
end

function Knuckles.Segmented(ctx: Ctx, ref: Ref)
	for i, phi in { -30, -48, -66 } do
		local frame = surfaceFrame(ref, 0, phi, 0.03)
		local width = ref.R.Z * (1.75 - i * 0.1)
		lens(ctx, "Segment", frame, width, 0.34, 0.15, "Secondary")
		lens(ctx, "SegmentEdge", frame * CFrame.new(0, 0.15, 0.03), width * 0.96, 0.06, 0.12, "Trim")
	end
end

function Knuckles.Spikes(ctx: Ctx, ref: Ref)
	guard(ctx, ref)
	for _, frame in knuckleFrames(ref, 0.12) do
		ell(ctx, "Spike", V(0.13, 0.13, 0.5), frame * CFrame.new(0, 0, 0.2), "Trim")
	end
end

function Knuckles.Crystal(ctx: Ctx, ref: Ref)
	lens(ctx, "CrystalSetting", surfaceFrame(ref, 0, KNUCKLE_PHI, 0.02), ref.R.Z * 1.8, 0.56, 0.14, "Trim")
	for i, frame in knuckleFrames(ref, 0.1) do
		local tilt = if i % 2 == 0 then rot(12, 0, 18) else rot(-10, 0, -14)
		add(ctx, "Crystal", V(0.24, 0.24, 0.46), frame * CFrame.new(0, 0, 0.12) * tilt * rot(0, 0, 45), "Secondary")
	end
end

function Knuckles.Rocks(ctx: Ctx, ref: Ref)
	lens(ctx, "RockBed", surfaceFrame(ref, 0, KNUCKLE_PHI, 0), ref.R.Z * 1.75, 0.5, 0.14, "Dark")
	for i, frame in knuckleFrames(ref, 0.05) do
		local tilt = rot(i * 17 % 30 - 15, i * 41 % 60, i * 23 % 40 - 20)
		add(ctx, "Rock", V(0.38, 0.34, 0.26), frame * tilt, "Secondary")
	end
end

function Knuckles.Horns(ctx: Ctx, ref: Ref)
	guard(ctx, ref)
	local frames = knuckleFrames(ref, 0.05)
	for _, frame in { frames[1], frames[4] } do
		local base = frame.Position
		local bend = (frame * CFrame.new(0, 0.35, 0.3)).Position
		local tip = (frame * CFrame.new(0, 0.8, 0.38)).Position
		capsule(ctx, "Horn", base, bend, 0.2, "Trim")
		capsule(ctx, "HornTip", bend, tip, 0.13, "Trim")
	end
end

function Knuckles.Bolt(ctx: Ctx, ref: Ref)
	local frame = guard(ctx, ref) * CFrame.new(0, 0, 0.13)
	-- A lightning bolt engraved across the guard.
	for _, stroke in { { -0.28, 0.1, 32 }, { -0.02, 0, -38 }, { 0.24, -0.1, 32 } } do
		add(ctx, "BoltInlay", V(0.07, 0.34, 0.05), frame * CFrame.new(stroke[1], stroke[2], 0) * rot(0, 0, stroke[3]), "Glow")
	end
end

function Knuckles.Blades(ctx: Ctx, ref: Ref)
	local frame = guard(ctx, ref)
	for _, x in { -0.36, 0, 0.36 } do
		add(ctx, "Blade", V(0.06, 0.34, 0.42), frame * CFrame.new(x, 0.05, 0.22) * rot(-25, 0, 0), "Trim", { Class = "WedgePart" })
	end
end

function Knuckles.Wood(ctx: Ctx, ref: Ref)
	-- Carved wooden knuckle guards on a wooden backing plate, with darker grain lines.
	local backing = surfaceFrame(ref, 0, KNUCKLE_PHI, 0.02)
	lens(ctx, "WoodBacking", backing, ref.R.Z * 1.78, 0.58, 0.18, "Secondary")
	for _, frame in knuckleFrames(ref, 0.07) do
		ell(ctx, "WoodKnuckle", V(0.34, 0.4, 0.26), frame, "Secondary")
	end
	for _, y in { -0.12, 0.1 } do
		lens(ctx, "Grain", backing * CFrame.new(0, y, 0.09), ref.R.Z * 1.5, 0.025, 0.02, "Dark")
	end
end

-- Back of the hand -----------------------------------------------------------------------

local Back = {}

function Back.None() end

function Back.Panel(ctx: Ctx, ref: Ref)
	local frame = surfaceFrame(ref, 0, BACK_PHI, 0)
	lens(ctx, "BackPiping", frame, ref.R.Z * 1.42, ref.R.Y * 1.02, 0.12, "Trim")
	lens(ctx, "BackPanel", frame * CFrame.new(0, 0, 0.03), ref.R.Z * 1.32, ref.R.Y * 0.92, 0.14, "Secondary")
end

function Back.Layered(ctx: Ctx, ref: Ref)
	for i, phi in { 22, 4, -14 } do
		local frame = surfaceFrame(ref, 0, phi, 0.03)
		local width = ref.R.Z * (1.5 - i * 0.08)
		lens(ctx, "BackPlate", frame, width, 0.44, 0.15, "Secondary")
		lens(ctx, "BackPlateEdge", frame * CFrame.new(0, -0.2, 0.03), width * 0.94, 0.05, 0.12, "Trim")
	end
end

function Back.Wood(ctx: Ctx, ref: Ref)
	local frame = surfaceFrame(ref, 0, BACK_PHI, 0.02)
	lens(ctx, "WoodPanel", frame, ref.R.Z * 1.36, ref.R.Y * 0.95, 0.2, "Secondary")
	for _, y in { -0.22, 0, 0.22 } do
		lens(ctx, "Grain", frame * CFrame.new(0, y, 0.1), ref.R.Z * 1.0, 0.025, 0.02, "Dark")
	end
	-- Leather straps holding the wood on, buckled on the little-finger side.
	for _, phi in { 16, -24 } do
		lens(ctx, "Strap", surfaceFrame(ref, 0, phi, 0.07), ref.R.Z * 1.75, 0.15, 0.06, "Trim")
		local buckle = surfaceFrame(ref, -55, phi, 0.07)
		add(ctx, "Buckle", V(0.16, 0.2, 0.06), buckle, "Accent")
	end
end

function Back.Scales(ctx: Ctx, ref: Ref)
	for row, phi in { 14, -6, -26 } do
		for _, theta in { -28, 0, 28 } do
			local offset = if row % 2 == 0 then 14 else 0
			lens(ctx, "Scale", surfaceFrame(ref, theta + offset - 7, phi, 0.03 + row * 0.01), 0.36, 0.32, 0.1, "Secondary")
		end
	end
end

function Back.Leaf(ctx: Ctx, ref: Ref)
	for _, spin in { -38, 0, 38 } do
		local frame = surfaceFrame(ref, 0, BACK_PHI, 0.04, spin)
		lens(ctx, "LeafPlate", frame * CFrame.new(0, 0.18, 0), 0.36, 0.95, 0.1, "Primary")
		lens(ctx, "LeafVein", frame * CFrame.new(0, 0.18, 0.05), 0.04, 0.82, 0.04, "Trim")
	end
	lens(ctx, "LeafBase", surfaceFrame(ref, 0, BACK_PHI - 14, 0.03), 0.62, 0.3, 0.12, "Trim")
end

function Back.Ribs(ctx: Ctx, ref: Ref)
	for _, theta in { -24, 0, 24 } do
		lens(ctx, "Rib", surfaceFrame(ref, theta, BACK_PHI, 0.03), 0.15, ref.R.Y * 1.05, 0.13, "Trim")
	end
end

function Back.Sun(ctx: Ctx, ref: Ref)
	local frame = surfaceFrame(ref, 0, BACK_PHI, 0.04)
	lens(ctx, "SunDisc", frame, 0.56, 0.56, 0.12, "Trim")
	for i = 0, 7 do
		local angle = i * 45
		lens(ctx, "SunRay", frame * rot(0, 0, angle) * CFrame.new(0, 0.42, 0), 0.09, 0.3, 0.08, "Trim")
	end
	lens(ctx, "SunCore", frame * CFrame.new(0, 0, 0.05), 0.26, 0.26, 0.06, if ctx.Design.Colors.Glow then "Glow" else "Accent")
end

function Back.Crystal(ctx: Ctx, ref: Ref)
	local frame = surfaceFrame(ref, 0, BACK_PHI, 0.02)
	lens(ctx, "CrystalBed", frame, ref.R.Z * 1.1, ref.R.Y * 0.8, 0.12, "Trim")
	for i, spot in { { -0.22, 0.12, 20 }, { 0.05, -0.05, -10 }, { 0.25, 0.18, 30 } } do
		add(ctx, "Crystal", V(0.22, 0.48 - i * 0.05, 0.22), frame * CFrame.new(spot[1], spot[2], 0.12) * rot(spot[3], 0, spot[3] * 0.6) * rot(0, 45, 0), "Secondary")
	end
end

-- Cuffs -------------------------------------------------------------------------------------

local function opening(ctx: Ctx, cuff: CuffSpec, top: number, diameter: number)
	-- The dark wrist opening, recessed inside the top rim.
	ring(ctx, "Opening", top - 0.02, 0.06, diameter - 0.18, "Opening")
end

local Cuffs = {}

function Cuffs.Wrap(ctx: Ctx, cuff: CuffSpec)
	ring(ctx, "CuffBase", cuff.Y + cuff.H / 2, cuff.H, cuff.D - 0.06, "PrimaryDark")
	for i = 0, 3 do
		local tilt = rot(if i % 2 == 0 then 4 else -3, 0, if i % 2 == 0 then -5 else 4)
		ring(ctx, "Wrap", cuff.Y + 0.12 + i * cuff.H * 0.24, 0.2, cuff.D + (i % 2) * 0.04, "Accent", tilt)
	end
	-- The tucked end of the wrap on the outer side.
	add(ctx, "WrapEnd", V(0.06, 0.32, 0.26), CFrame.new(cuff.D / 2 + 0.02, cuff.Y + cuff.H * 0.5, 0.15) * rot(0, 0, 8), "Accent")
	opening(ctx, cuff, cuff.Y + cuff.H, cuff.D)
end

function Cuffs.Lace(ctx: Ctx, cuff: CuffSpec)
	ring(ctx, "Cuff", cuff.Y + cuff.H / 2, cuff.H, cuff.D, "Primary")
	ring(ctx, "Piping", cuff.Y + cuff.H, 0.08, cuff.D + 0.06, "Trim")
	ring(ctx, "Piping", cuff.Y + 0.04, 0.08, cuff.D + 0.04, "Trim")
	-- Laces criss-crossing on the palm side.
	local x = -cuff.D / 2 - 0.01
	for i = 0, 2 do
		local y = cuff.Y + 0.2 + i * cuff.H * 0.25
		for _, angle in { 40, -40 } do
			add(ctx, "Lace", V(0.04, 0.32, 0.04), CFrame.new(x, y, 0) * rot(angle, 0, 0), "Accent")
		end
		for _, z in { -0.14, 0.14 } do
			ball(ctx, "Eyelet", 0.07, V(x, y + 0.1, z), "Trim")
		end
	end
	opening(ctx, cuff, cuff.Y + cuff.H, cuff.D)
end

function Cuffs.Strap(ctx: Ctx, cuff: CuffSpec)
	ring(ctx, "Cuff", cuff.Y + cuff.H / 2, cuff.H, cuff.D, "Primary")
	ring(ctx, "Piping", cuff.Y + cuff.H, 0.08, cuff.D + 0.06, "Trim")
	local strapY = cuff.Y + cuff.H * 0.42
	ring(ctx, "WristStrap", strapY, 0.3, cuff.D + 0.07, "Trim", rot(0, 0, 6))
	add(ctx, "Buckle", V(0.08, 0.24, 0.3), CFrame.new(cuff.D / 2 + 0.06, strapY + 0.05, 0), "Accent")
	opening(ctx, cuff, cuff.Y + cuff.H, cuff.D)
end

function Cuffs.Bracer(ctx: Ctx, cuff: CuffSpec)
	ring(ctx, "Bracer", cuff.Y + cuff.H * 0.28, cuff.H * 0.56, cuff.D, "Secondary")
	ring(ctx, "BracerUpper", cuff.Y + cuff.H * 0.76, cuff.H * 0.48, cuff.D + 0.1, "Secondary")
	for _, y in { cuff.Y + 0.03, cuff.Y + cuff.H * 0.53, cuff.Y + cuff.H } do
		ring(ctx, "BracerTrim", y, 0.07, cuff.D + 0.16, "Trim")
	end
	-- A shaped plate over the outer side of the wrist.
	local frame = CFrame.fromMatrix(V(cuff.D / 2 + 0.06, cuff.Y + cuff.H * 0.5, 0), V(0, 0, -1), V(0, 1, 0), V(1, 0, 0))
	lens(ctx, "BracerPlate", frame, 0.62, cuff.H * 0.7, 0.12, "Trim")
	opening(ctx, cuff, cuff.Y + cuff.H, cuff.D + 0.1)
end

function Cuffs.Flared(ctx: Ctx, cuff: CuffSpec)
	ring(ctx, "Cuff", cuff.Y + cuff.H * 0.25, cuff.H * 0.5, cuff.D, "Secondary")
	ring(ctx, "Flare", cuff.Y + cuff.H * 0.72, cuff.H * 0.45, cuff.D + 0.28, "Secondary")
	ring(ctx, "FlareRim", cuff.Y + cuff.H * 0.96, 0.08, cuff.D + 0.36, "Trim")
	ring(ctx, "FlareSeam", cuff.Y + cuff.H * 0.5, 0.06, cuff.D + 0.08, "Trim")
	opening(ctx, cuff, cuff.Y + cuff.H * 0.945, cuff.D + 0.28)
end

function Cuffs.Crown(ctx: Ctx, cuff: CuffSpec)
	Cuffs.Bracer(ctx, cuff)
	local radius = (cuff.D + 0.12) / 2
	local top = cuff.Y + cuff.H
	for i = 0, 5 do
		local angle = i * math.pi / 3 + math.pi / 6
		local base = V(math.cos(angle) * radius, top, math.sin(angle) * radius)
		local tip = base + V(math.cos(angle) * 0.08, 0.36, math.sin(angle) * 0.08)
		capsule(ctx, "CrownPoint", base, tip, 0.13, "Trim")
	end
end

function Cuffs.Rings(ctx: Ctx, cuff: CuffSpec)
	ring(ctx, "Cuff", cuff.Y + cuff.H / 2, cuff.H, cuff.D - 0.06, "Primary")
	for i = 0, 2 do
		ring(ctx, "CuffRing", cuff.Y + 0.14 + i * cuff.H * 0.34, 0.12, cuff.D + 0.08, "Trim")
	end
	opening(ctx, cuff, cuff.Y + cuff.H, cuff.D)
end

-- Emblems (built in a frame whose Z points out of the surface) ------------------------------

local function disc(ctx: Ctx, name: string, frame: CFrame, diameter: number, thickness: number, key: string)
	add(ctx, name, V(thickness, diameter, diameter), frame * rot(0, 90, 0), key, { Shape = Enum.PartType.Cylinder })
end

local function buildEmblem(ctx: Ctx, kind: string?, frame: CFrame)
	if not kind then
		return
	end
	local bright = if ctx.Design.Colors.Glow then "Glow" else "Accent"
	if kind == "Badge" then
		disc(ctx, "Badge", frame, 0.36, 0.05, "Trim")
		disc(ctx, "BadgeInset", frame * CFrame.new(0, 0, 0.02), 0.24, 0.05, "Dark")
	elseif kind == "Diamond" then
		add(ctx, "Emblem", V(0.34, 0.34, 0.05), frame * rot(0, 0, 45), "Trim")
		add(ctx, "EmblemInset", V(0.22, 0.22, 0.06), frame * CFrame.new(0, 0, 0.01) * rot(0, 0, 45), "Accent")
	elseif kind == "Sun" then
		disc(ctx, "Sun", frame, 0.28, 0.05, bright)
		for i = 0, 5 do
			add(ctx, "SunRay", V(0.05, 0.14, 0.04), frame * rot(0, 0, i * 60) * CFrame.new(0, 0.22, 0), "Trim")
		end
	elseif kind == "Star" then
		for _, angle in { 0, 45, 90, 135 } do
			add(ctx, "StarRay", V(0.07, 0.4, 0.04), frame * rot(0, 0, angle), "Trim")
		end
		ball(ctx, "StarCore", 0.1, (frame * CFrame.new(0, 0, 0.03)).Position, bright)
	elseif kind == "Snowflake" then
		for _, angle in { 0, 60, 120 } do
			add(ctx, "Flake", V(0.045, 0.42, 0.04), frame * rot(0, 0, angle), "Accent")
		end
		ball(ctx, "FlakeCore", 0.08, (frame * CFrame.new(0, 0, 0.02)).Position, "Trim")
	elseif kind == "Crest" then
		lens(ctx, "Crest", frame * CFrame.new(0, 0.04, 0), 0.4, 0.32, 0.07, "Trim")
		add(ctx, "CrestPoint", V(0.24, 0.24, 0.06), frame * CFrame.new(0, -0.1, 0) * rot(0, 0, 45), "Trim")
		lens(ctx, "CrestInset", frame * CFrame.new(0, 0.03, 0.03), 0.24, 0.18, 0.05, "Accent")
	elseif kind == "Orb" then
		disc(ctx, "OrbSetting", frame, 0.4, 0.05, "Trim")
		ell(ctx, "Orb", V(0.26, 0.26, 0.14), frame * CFrame.new(0, 0, 0.05), bright)
	elseif kind == "Ring" then
		disc(ctx, "RingOuter", frame, 0.42, 0.05, "Trim")
		disc(ctx, "RingInner", frame * CFrame.new(0, 0, 0.01), 0.28, 0.05, "Opening")
		ball(ctx, "RingCore", 0.1, (frame * CFrame.new(0, 0, 0.04)).Position, bright)
	elseif kind == "Leaf" then
		for _, spin in { -24, 24 } do
			lens(ctx, "Leaf", frame * rot(0, 0, spin) * CFrame.new(0, 0.08, 0), 0.15, 0.36, 0.05, "Accent")
		end
		add(ctx, "Stem", V(0.03, 0.16, 0.04), frame * CFrame.new(0, -0.14, 0), "Trim")
	end
end

-- Extras ------------------------------------------------------------------------------------

local function buildExtra(ctx: Ctx, kind: string, ref: Ref, cuff: CuffSpec)
	if kind == "Stitching" then
		-- Dashed stitching along the palm panel and around the wrist.
		line(ctx, "Stitch", surfacePath(ref, 128, 40, 128, -62, 12, 0.02), 0.035, "Accent", true)
		line(ctx, "Stitch", surfacePath(ref, -128, 40, -128, -62, 12, 0.02), 0.035, "Accent", true)
		line(ctx, "Stitch", surfacePath(ref, -150, 58, 150, 58, 18, 0.0), 0.035, "Accent", true)
	elseif kind == "Seams" then
		line(ctx, "Seam", surfacePath(ref, 62, 45, 62, -72, 10, 0.01), 0.03, "Dark")
		line(ctx, "Seam", surfacePath(ref, -62, 45, -62, -72, 10, 0.01), 0.03, "Dark")
	elseif kind == "Straps" then
		for _, phi in { 18, -24 } do
			lens(ctx, "Strap", surfaceFrame(ref, 0, phi, 0.04), ref.R.Z * 1.7, 0.14, 0.05, "Dark")
		end
	elseif kind == "Rivets" then
		for _, spot in { { -36, 20 }, { 36, 20 }, { -38, -24 }, { 38, -24 } } do
			ball(ctx, "Rivet", 0.1, surface(ref, spot[1], spot[2], 0.05), "Trim")
		end
	elseif kind == "Inlay" then
		for _, phi in { 26, -30 } do
			lens(ctx, "Inlay", surfaceFrame(ref, 0, phi, 0.07), ref.R.Z * 1.2, 0.04, 0.03, "Accent")
		end
	elseif kind == "Channels" then
		-- Energy channels set into the surface on either side of the back of the hand.
		for _, theta in { 30, -30 } do
			line(ctx, "Channel", surfacePath(ref, theta, 38, theta * 0.8, -62, 9, 0.03), 0.05, "Glow")
		end
	elseif kind == "Fins" then
		for _, phi in { 14, -16 } do
			add(ctx, "Fin", V(0.05, 0.34, 0.28), surfaceFrame(ref, -42, phi, 0.12) * rot(-30, 0, 0), "Trim", { Class = "WedgePart" })
		end
	elseif kind == "Tail" then
		local base = V(cuff.D / 2 + 0.02, cuff.Y + cuff.H * 0.4, 0.2)
		local points = { base, base + V(0.14, 0.3, 0.06), base + V(0.18, 0.62, -0.02), base + V(0.12, 0.86, -0.18) }
		for i = 1, #points - 1 do
			capsule(ctx, "TailSegment", points[i], points[i + 1], 0.2 - i * 0.03, "Secondary")
		end
		capsule(ctx, "Stinger", points[4], points[4] + V(-0.02, -0.12, -0.24), 0.08, "Accent")
	elseif kind == "Shards" then
		local radius = cuff.D / 2
		for _, degrees in { 200, 270, 340 } do
			local angle = rad(degrees)
			local base = V(math.cos(angle) * radius, cuff.Y + cuff.H, math.sin(angle) * radius)
			add(ctx, "Shard", V(0.14, 0.38, 0.14), CFrame.new(base + V(0, 0.12, 0)) * rot(math.sin(angle) * 14, 45, -math.cos(angle) * 14), "Secondary")
		end
	elseif kind == "Swirl" then
		-- A spiral of energy wound around the hand.
		local points = {}
		for i = 0, 14 do
			table.insert(points, (surface(ref, -110 + i * 24, 34 - i * 6.5, 0.04)))
		end
		line(ctx, "Swirl", points, 0.05, "Glow")
	end
end

-- Effects: a small light, plus a few motes for the effect types that call for them ---------------

local function buildEffect(ctx: Ctx, kind: string?, root: BasePart)
	if not kind then
		return
	end
	local glow = ctx.Design.Colors.Glow or ctx.Design.Colors.Accent
	local attachment = Instance.new("Attachment")
	attachment.Name = "EffectAttachment"
	local center = ctx.Shell.Ref.C + V(ctx.Shell.Ref.R.X * 0.6, 0, 0)
	attachment.Position = V(if ctx.Mirror then -center.X else center.X, center.Y, center.Z) * ctx.Scale
	attachment.Parent = root

	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 4.5 * ctx.Scale
	light.Brightness = 0.5
	light.Shadows = false
	light.Parent = attachment
	if kind == "Glow" then
		return
	end

	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 2.5
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(0.3, 1)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	emitter.Color = ColorSequence.new(glow)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	if kind == "Embers" then
		emitter.Acceleration = V(0, 3, 0)
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), glow)
	elseif kind == "Frost" then
		emitter.Acceleration = V(0, -1.5, 0)
		emitter.Color = ColorSequence.new(Color3.new(1, 1, 1), glow)
	elseif kind == "Heat" then
		emitter.Rate = 1.5
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.45) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.65), NumberSequenceKeypoint.new(1, 1) })
		emitter.LightEmission = 0.4
		emitter.Acceleration = V(0, 2, 0)
	elseif kind == "Sparks" then
		emitter.Speed = NumberRange.new(2, 4)
		emitter.Lifetime = NumberRange.new(0.12, 0.25)
		emitter.Rate = 3
	elseif kind == "Cosmic" then
		emitter.Color = ColorSequence.new(glow, Color3.new(1, 1, 1))
		emitter.Rotation = NumberRange.new(0, 360)
	end
	emitter.Parent = attachment
end

-- Public API ----------------------------------------------------------------------------------

function GloveBuilder.GetDesign(gloveId: string): GloveDesigns.Design
	return GloveDesigns[gloveId] or GloveDesigns.Greenfield_1
end

-- side: "Right" or "Left"
function GloveBuilder.Build(gloveId: string, side: string, scale: number?): Model
	local design = GloveBuilder.GetDesign(gloveId)
	local shell = SHELLS[design.Shell] or SHELLS.Boxing
	local model = Instance.new("Model")
	model.Name = `Glove{side}`
	model:SetAttribute("GloveId", gloveId)

	local ctx: Ctx = {
		Model = model,
		Design = design,
		Shell = shell,
		Scale = (scale or 1) * design.Scale,
		Mirror = side == "Left",
	}

	local root = Instance.new("Part")
	root.Name = "GloveRoot"
	root.Size = V(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.CFrame = CFrame.identity
	root.Parent = model
	model.PrimaryPart = root

	local ref = shell.Ref
	if shell.Kind == "Padded" then
		paddedShell(ctx, ref)
	elseif shell.Kind == "Combat" then
		combatShell(ctx, ref)
	else
		gauntletShell(ctx, ref)
	end
	;(Knuckles[design.Knuckles] or Knuckles.Padded)(ctx, ref)
	;(Back[design.Back] or Back.None)(ctx, ref)
	;(Cuffs[design.Cuff] or Cuffs.Strap)(ctx, shell.Cuff)

	if design.Emblem then
		local frame
		if design.EmblemOn == "Cuff" then
			local cuff = shell.Cuff
			frame = CFrame.fromMatrix(V(cuff.D / 2 + 0.07, cuff.Y + cuff.H * 0.5, 0), V(0, 0, -1), V(0, 1, 0), V(1, 0, 0))
		else
			local lift = if design.Back == "None" then 0.04 else 0.16
			frame = surfaceFrame(ref, 0, BACK_PHI + 4, lift)
		end
		buildEmblem(ctx, design.Emblem, frame)
	end
	for _, extra in design.Extras do
		buildExtra(ctx, extra, ref, shell.Cuff)
	end
	buildEffect(ctx, design.Effect, root)

	return model
end

-- Both gloves upright side by side with the backs of the hands facing -Z and thumbs turned in,
-- the way a pair is displayed. Used by the shop previews and the glove-shop counter.
function GloveBuilder.BuildPair(gloveId: string, scale: number?): Model
	local pair = Instance.new("Model")
	pair.Name = "GlovePair"
	local gap = 0.98 * (scale or 1) * GloveBuilder.GetDesign(gloveId).Scale
	for _, side in { "Right", "Left" } do
		local glove = GloveBuilder.Build(gloveId, side, scale)
		local x = if side == "Right" then gap else -gap
		local turn = if side == "Right" then 72 else -72
		glove:PivotTo(CFrame.new(x, 0, 0) * rot(0, turn, 0))
		glove.Parent = pair
	end
	pair.WorldPivot = CFrame.identity
	return pair
end

-- Hands for R15 and R6.
local HANDS = {
	Right = { "RightHand", "Right Arm" },
	Left = { "LeftHand", "Left Arm" },
}

-- Where the glove's origin sits on each kind of hand part, in that part's space.
-- R15: the hand's centre (the shell extends below it and the cuff over the wrist).
-- R6:  inside the bottom of the arm, which has no separate hand.
local function handOffset(hand: BasePart, isR6Arm: boolean, scale: number): CFrame
	if isR6Arm then
		return CFrame.new(0, -hand.Size.Y / 2 + 0.55 * scale, 0)
	end
	return CFrame.new(0, -0.05 * scale, 0)
end

-- Replaces any gloves on the character with this glove. Each glove is welded to its hand part,
-- so it follows every animation; a respawned character simply gets new gloves.
function GloveBuilder.Attach(character: Model, gloveId: string)
	for _, child in character:GetChildren() do
		if child.Name == "GloveRight" or child.Name == "GloveLeft" or child.Name == "GloveVisual" then
			child:Destroy()
		end
	end

	for side, names in HANDS do
		local hand = character:FindFirstChild(names[1]) or character:FindFirstChild(names[2])
		if hand and hand:IsA("BasePart") then
			local isR6Arm = hand.Name == names[2]
			local scale = math.clamp(hand.Size.X, 0.75, 1.4)
			local offset = handOffset(hand, isR6Arm, scale)

			local glove = GloveBuilder.Build(gloveId, side, scale)
			local root = glove.PrimaryPart :: BasePart
			glove:PivotTo(hand.CFrame * offset)

			for _, part in glove:GetDescendants() do
				if part:IsA("BasePart") and part ~= root then
					local weld = Instance.new("Weld")
					weld.Part0 = root
					weld.Part1 = part
					weld.C0 = root.CFrame:ToObjectSpace(part.CFrame)
					weld.Parent = part
				end
			end
			local handWeld = Instance.new("Weld")
			handWeld.Name = "HandWeld"
			handWeld.Part0 = hand
			handWeld.Part1 = root
			handWeld.C0 = offset
			handWeld.Parent = root

			for _, part in glove:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = false
				end
			end
			glove.Parent = character
		end
	end
end

return GloveBuilder
