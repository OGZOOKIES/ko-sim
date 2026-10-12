-- Builds glove models from Config/GloveDesigns.
--
-- The same builder makes the gloves characters wear (server) and the 3D shop previews (client),
-- so what you buy is what you see.
--
-- Glove space (one hand, before scaling), with the hand at the origin:
--   -Y  toward the fist end      +Y  toward the wrist and cuff
--   -Z  knuckle / front side     +Z  palm side
--   -X  thumb side (right hand)  +X  outer side
-- Left gloves are mirrored across X.
--
-- API
--   GloveBuilder.Build(gloveId, side, scale?) -> Model   anchored, centered on the hand
--   GloveBuilder.BuildPair(gloveId) -> Model             both hands side by side, for previews
--   GloveBuilder.Attach(character, gloveId)              replaces the character's gloves (R6 or R15)

local GloveDesigns = require(script.Parent.Parent.Config.GloveDesigns)

local GloveBuilder = {}

local V = Vector3.new
local rad = math.rad

local function rx(deg: number): CFrame
	return CFrame.Angles(rad(deg), 0, 0)
end
local function ry(deg: number): CFrame
	return CFrame.Angles(0, rad(deg), 0)
end
local function rz(deg: number): CFrame
	return CFrame.Angles(0, 0, rad(deg))
end

-- Where the knuckle armor sits and where the front surface is, per shell.
local SHELLS = {
	Mitt = { Knuckle = V(0, -0.78, -0.58), Front = -0.62 },
	Boxing = { Knuckle = V(0, -0.78, -0.8), Front = -0.76 },
	Armored = { Knuckle = V(0, -0.86, -0.92), Front = -0.9 },
	Gauntlet = { Knuckle = V(0, -0.98, -0.7), Front = -0.74 },
	Claw = { Knuckle = V(0, -0.98, -0.7), Front = -0.74 },
}

local EMBLEM = V(0, 0.78, -0.7)
local KNUCKLE_XS = { -0.45, -0.15, 0.15, 0.45 }

type Ctx = {
	Model: Model,
	Design: GloveDesigns.Design,
	Scale: number,
	Mirror: boolean,
}

local function mirror(cf: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

local function resolve(ctx: Ctx, key: string): (Color3, Enum.Material)
	local design = ctx.Design
	if key == "Glow" then
		return design.Colors.Glow or design.Colors.Accent, Enum.Material.Neon
	elseif key == "Accent" then
		return design.Colors.Accent, Enum.Material.SmoothPlastic
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
		part.Transparency = 0.12
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

local function box(ctx: Ctx, name: string, size: Vector3, position: Vector3, key: string, rotation: CFrame?)
	add(ctx, name, size, CFrame.new(position) * (rotation or CFrame.identity), key)
end

local function ellipsoid(ctx: Ctx, name: string, size: Vector3, position: Vector3, key: string, rotation: CFrame?)
	add(ctx, name, size, CFrame.new(position) * (rotation or CFrame.identity), key, { Sphere = true })
end

local function ball(ctx: Ctx, name: string, diameter: number, position: Vector3, key: string)
	add(ctx, name, V(diameter, diameter, diameter), CFrame.new(position), key, { Shape = Enum.PartType.Ball })
end

-- An upright ring around the wrist (a short cylinder along Y).
local function ring(ctx: Ctx, name: string, height: number, diameter: number, y: number, key: string, tilt: CFrame?)
	add(ctx, name, V(height, diameter, diameter), CFrame.new(0, y, 0) * (tilt or CFrame.identity) * rz(90), key, { Shape = Enum.PartType.Cylinder })
end

-- A flat disc facing -Z (emblems).
local function disc(ctx: Ctx, name: string, thickness: number, diameter: number, position: Vector3, key: string)
	add(ctx, name, V(thickness, diameter, diameter), CFrame.new(position) * ry(90), key, { Shape = Enum.PartType.Cylinder })
end

local function wedge(ctx: Ctx, name: string, size: Vector3, position: Vector3, key: string, rotation: CFrame?)
	add(ctx, name, size, CFrame.new(position) * (rotation or CFrame.identity), key, { Class = "WedgePart" })
end

-- Shells

local function buildShell(ctx: Ctx, kind: string)
	if kind == "Mitt" then
		ellipsoid(ctx, "Shell", V(1.3, 1.5, 1.3), V(0, -0.2, 0), "Primary")
		ellipsoid(ctx, "Palm", V(1.05, 1, 0.45), V(0, -0.25, 0.48), "Secondary")
		ellipsoid(ctx, "Thumb", V(0.5, 0.78, 0.55), V(-0.62, -0.05, -0.15), "Primary", rz(-20))
	elseif kind == "Boxing" or kind == "Armored" then
		ellipsoid(ctx, "Shell", V(1.45, 1.6, 1.5), V(0, -0.3, 0), "Primary")
		ellipsoid(ctx, "KnuckleBulge", V(1.32, 0.95, 0.72), V(0, -0.6, -0.45), "Primary")
		ellipsoid(ctx, "Thumb", V(0.55, 0.92, 0.6), V(-0.72, -0.08, -0.22), "Primary", rz(-15))
		ellipsoid(ctx, "PalmPad", V(1.1, 1.05, 0.4), V(0, -0.3, 0.62), "Secondary")
		if kind == "Armored" then
			box(ctx, "ArmorUpper", V(1.38, 0.48, 0.18), V(0, 0.02, -0.76), "Secondary", rx(-10))
			box(ctx, "ArmorLower", V(1.32, 0.42, 0.18), V(0, -0.4, -0.84), "Secondary", rx(-4))
			box(ctx, "ArmorTrim", V(1.4, 0.06, 0.2), V(0, 0.27, -0.73), "Trim", rx(-10))
		end
	else -- Gauntlet and Claw: hard-edged armored hands
		box(ctx, "Hand", V(1.28, 1.2, 1.25), V(0, -0.2, 0), "Primary")
		box(ctx, "Fingers", V(1.32, 0.58, 1.2), V(0, -1, -0.04), "Primary")
		ellipsoid(ctx, "FistCap", V(1.3, 0.5, 1.22), V(0, -1.3, -0.04), "Secondary")
		box(ctx, "Thumb", V(0.4, 0.82, 0.48), V(-0.78, -0.28, -0.18), "Secondary", rz(-12))
		box(ctx, "FrontPlate", V(1.34, 0.95, 0.16), V(0, -0.2, -0.68), "Secondary")
		box(ctx, "FrontTrim", V(1.36, 0.06, 0.18), V(0, 0.28, -0.69), "Trim")
		if kind == "Claw" then
			for _, x in KNUCKLE_XS do
				box(ctx, "Claw", V(0.17, 0.5, 0.17), V(x, -1.6, -0.34), "Trim", rx(28) * ry(45))
			end
		end
	end
end

-- Knuckle armor

local function buildKnuckles(ctx: Ctx, kind: string, k: Vector3)
	if kind == "Pad" then
		ellipsoid(ctx, "KnucklePad", V(1.15, 0.45, 0.32), k, "Secondary")
	elseif kind == "Plates" then
		box(ctx, "KnuckleBase", V(1.2, 0.42, 0.1), k + V(0, 0, 0.06), "Secondary")
		for _, x in KNUCKLE_XS do
			box(ctx, "KnucklePlate", V(0.27, 0.34, 0.18), k + V(x, 0, -0.02), "Trim", rx(-10))
		end
	elseif kind == "Rivets" then
		box(ctx, "KnucklePlate", V(1.22, 0.44, 0.14), k, "Secondary")
		for _, x in KNUCKLE_XS do
			ball(ctx, "Rivet", 0.14, k + V(x, 0, -0.08), "Trim")
		end
	elseif kind == "Ridge" then
		for _, x in KNUCKLE_XS do
			ellipsoid(ctx, "KnuckleRidge", V(0.28, 0.42, 0.32), k + V(x, 0, -0.02), "Secondary")
		end
	elseif kind == "Segmented" then
		for i, dy in { 0.24, 0, -0.24 } do
			box(ctx, "Segment", V(1.3, 0.2, 0.22), k + V(0, dy, -0.02 * i), "Secondary", rx(-14 + i * 7))
			box(ctx, "SegmentEdge", V(1.32, 0.04, 0.24), k + V(0, dy + 0.11, -0.02 * i), "Trim", rx(-14 + i * 7))
		end
	elseif kind == "Spikes" then
		box(ctx, "SpikePlate", V(1.2, 0.4, 0.14), k, "Secondary")
		for _, x in KNUCKLE_XS do
			box(ctx, "Spike", V(0.16, 0.16, 0.42), k + V(x, 0, -0.22), "Trim", rz(45))
		end
	elseif kind == "Crystal" then
		for _, spot in { { -0.38, 0.02, 20, -25 }, { 0, 0.1, 10, 5 }, { 0.38, 0, 25, 30 } } do
			box(ctx, "Crystal", V(0.32, 0.6, 0.32), k + V(spot[1], spot[2], -0.05), "Secondary", rx(spot[3]) * rz(spot[4]) * ry(45))
		end
	elseif kind == "Rocks" then
		for i, spot in { { -0.36, 0.02, 15, 30 }, { 0.02, -0.04, -20, 70 }, { 0.38, 0.03, 30, -40 } } do
			box(ctx, "Rock", V(0.44, 0.4, 0.34) * (1 - i * 0.04), k + V(spot[1], spot[2], -0.04), "Secondary", rx(spot[3]) * ry(spot[4]))
		end
	elseif kind == "Horns" then
		ellipsoid(ctx, "KnucklePad", V(1.15, 0.45, 0.32), k, "Secondary")
		for _, side in { -1, 1 } do
			wedge(ctx, "Horn", V(0.24, 0.75, 0.32), k + V(side * 0.6, 0.35, 0.05), "Trim", rz(-side * 28))
		end
	elseif kind == "Bolt" then
		box(ctx, "BoltPlate", V(1.2, 0.42, 0.12), k + V(0, 0, 0.02), "Secondary")
		box(ctx, "Bolt", V(0.1, 0.3, 0.06), k + V(-0.14, 0.1, -0.06), "Glow", rz(35))
		box(ctx, "Bolt", V(0.1, 0.32, 0.06), k + V(0.02, 0, -0.06), "Glow", rz(-40))
		box(ctx, "Bolt", V(0.1, 0.3, 0.06), k + V(0.17, -0.1, -0.06), "Glow", rz(35))
	elseif kind == "Blades" then
		box(ctx, "BladeBase", V(1.2, 0.42, 0.12), k + V(0, 0, 0.02), "Secondary")
		for _, x in { -0.36, 0, 0.36 } do
			box(ctx, "Blade", V(0.08, 0.5, 0.42), k + V(x, 0.02, -0.2), "Trim", rx(-20))
		end
	end
end

-- Wrist cuffs

local function bracer(ctx: Ctx)
	ring(ctx, "Bracer", 0.8, 1.34, 0.8, "Secondary")
	ring(ctx, "BracerTrim", 0.1, 1.42, 0.42, "Trim")
	ring(ctx, "BracerTrim", 0.1, 1.42, 1.18, "Trim")
end

local function buildCuff(ctx: Ctx, kind: string)
	if kind == "Wrap" then
		for i, y in { 0.48, 0.68, 0.88 } do
			ring(ctx, "Wrap", 0.2, 1.28 + (i % 2) * 0.05, y, "Accent", rz(if i % 2 == 0 then 5 else -5))
		end
	elseif kind == "Strap" then
		ring(ctx, "Cuff", 0.55, 1.3, 0.72, "Secondary")
		box(ctx, "Strap", V(0.32, 0.62, 0.06), V(0, 0.72, -0.66), "Trim")
		box(ctx, "Buckle", V(0.26, 0.2, 0.06), V(0, 0.72, -0.7), "Accent")
	elseif kind == "Bracer" then
		bracer(ctx)
	elseif kind == "Flared" then
		ring(ctx, "Cuff", 0.4, 1.3, 0.6, "Secondary")
		ring(ctx, "Flare", 0.45, 1.56, 0.98, "Secondary")
		ring(ctx, "FlareTrim", 0.08, 1.64, 1.22, "Trim")
	elseif kind == "Crown" then
		bracer(ctx)
		for i = 0, 5 do
			local angle = i * math.pi / 3 + math.pi / 6
			box(ctx, "CrownPoint", V(0.14, 0.34, 0.14), V(math.cos(angle) * 0.64, 1.36, math.sin(angle) * 0.64), "Trim", ry(45))
		end
	elseif kind == "Rings" then
		ring(ctx, "Cuff", 0.85, 1.2, 0.8, "Primary")
		for _, y in { 0.5, 0.8, 1.1 } do
			ring(ctx, "CuffRing", 0.12, 1.38, y, "Trim")
		end
	end
end

-- Emblems (on the front of the cuff)

local function buildEmblem(ctx: Ctx, kind: string?)
	local e = EMBLEM
	local bright = if ctx.Design.Colors.Glow then "Glow" else "Accent"
	if kind == "Badge" then
		disc(ctx, "Badge", 0.06, 0.44, e, "Trim")
		disc(ctx, "BadgeCenter", 0.07, 0.28, e + V(0, 0, -0.01), "Accent")
	elseif kind == "Diamond" then
		box(ctx, "Emblem", V(0.44, 0.44, 0.05), e, "Trim", rz(45))
		box(ctx, "EmblemCenter", V(0.3, 0.3, 0.06), e + V(0, 0, -0.01), "Accent", rz(45))
	elseif kind == "Sun" then
		disc(ctx, "Sun", 0.07, 0.34, e, bright)
		for i = 0, 5 do
			local angle = i * math.pi / 3
			box(ctx, "SunRay", V(0.07, 0.18, 0.05), e + V(math.cos(angle) * 0.27, math.sin(angle) * 0.27, 0), "Trim", rz(math.deg(angle) - 90))
		end
	elseif kind == "Star" then
		for _, angle in { 0, 45, 90, 135 } do
			box(ctx, "StarRay", V(0.1, 0.5, 0.05), e, "Accent", rz(angle))
		end
	elseif kind == "Snowflake" then
		for _, angle in { 0, 60, 120 } do
			box(ctx, "Flake", V(0.06, 0.5, 0.05), e, "Accent", rz(angle))
		end
		ball(ctx, "FlakeCenter", 0.1, e + V(0, 0, -0.02), "Trim")
	elseif kind == "Crest" then
		box(ctx, "Shield", V(0.42, 0.32, 0.06), e + V(0, 0.05, 0), "Trim")
		box(ctx, "ShieldTip", V(0.3, 0.3, 0.06), e + V(0, -0.12, 0), "Trim", rz(45))
		box(ctx, "ShieldCenter", V(0.26, 0.2, 0.07), e + V(0, 0.05, -0.01), "Accent")
	elseif kind == "Orb" then
		disc(ctx, "OrbMount", 0.05, 0.5, e, "Trim")
		ball(ctx, "Orb", 0.32, e + V(0, 0, -0.08), bright)
	elseif kind == "Ring" then
		disc(ctx, "RingOuter", 0.05, 0.52, e, "Trim")
		disc(ctx, "RingInner", 0.06, 0.36, e + V(0, 0, -0.01), "Primary")
		ball(ctx, "RingCore", 0.14, e + V(0, 0, -0.05), bright)
	elseif kind == "Leaf" then
		ellipsoid(ctx, "Leaf", V(0.18, 0.44, 0.06), e + V(-0.1, 0.02, 0), "Accent", rz(25))
		ellipsoid(ctx, "Leaf", V(0.18, 0.44, 0.06), e + V(0.1, 0.02, 0), "Accent", rz(-25))
		box(ctx, "Stem", V(0.04, 0.2, 0.05), e + V(0, -0.2, 0), "Trim")
	end
end

-- Extras

local function buildExtra(ctx: Ctx, kind: string, front: number)
	if kind == "Stitching" then
		for _, x in { -0.73, 0.73 } do
			box(ctx, "Stitch", V(0.04, 1, 0.04), V(x, -0.3, -0.05), "Accent")
		end
		box(ctx, "Stitch", V(0.9, 0.04, 0.04), V(0, 0.12, front - 0.02), "Accent")
	elseif kind == "Seams" then
		for _, x in { -0.38, 0.38 } do
			box(ctx, "Seam", V(0.03, 1.1, 0.03), V(x, -0.35, front - 0.03), "Trim")
		end
	elseif kind == "Plating" then
		box(ctx, "SidePlate", V(0.14, 0.9, 1), V(0.76, -0.25, 0), "Secondary")
		box(ctx, "SidePlateTrim", V(0.1, 0.55, 0.75), V(0.84, -0.3, 0), "Trim")
	elseif kind == "Inlay" then
		box(ctx, "Inlay", V(0.5, 0.07, 0.04), V(0, 1.02, -0.69), "Accent")
		box(ctx, "Inlay", V(0.07, 0.7, 0.04), V(0, -0.3, 0.76), "Accent")
	elseif kind == "Channels" then
		for _, x in { -0.32, 0.32 } do
			box(ctx, "Channel", V(0.06, 0.8, 0.04), V(x, -0.25, front - 0.05), "Glow")
		end
	elseif kind == "Fins" then
		box(ctx, "Fin", V(0.07, 0.55, 0.5), V(0.8, 0.05, 0.12), "Trim", rx(-25))
		box(ctx, "Fin", V(0.07, 0.45, 0.42), V(0.8, -0.45, 0.16), "Trim", rx(-25))
	elseif kind == "Tail" then
		ellipsoid(ctx, "TailSegment", V(0.24, 0.24, 0.24), V(0.62, 0.85, 0.3), "Secondary")
		ellipsoid(ctx, "TailSegment", V(0.22, 0.22, 0.22), V(0.68, 1.12, 0.38), "Secondary")
		ellipsoid(ctx, "TailSegment", V(0.2, 0.2, 0.2), V(0.66, 1.38, 0.22), "Secondary")
		box(ctx, "Stinger", V(0.08, 0.28, 0.08), V(0.62, 1.5, 0.02), "Accent", rx(-60))
	elseif kind == "Shards" then
		for _, degrees in { 210, 270, 330 } do
			local angle = rad(degrees)
			box(ctx, "Shard", V(0.16, 0.42, 0.16), V(math.cos(angle) * 0.6, 1.3, math.sin(angle) * 0.6), "Secondary", rz(math.cos(angle) * -15) * ry(45))
		end
	elseif kind == "Orbit" then
		for _, degrees in { 30, 150, 270 } do
			local angle = rad(degrees)
			ball(ctx, "OrbitStar", 0.14, V(math.cos(angle) * 0.98, 0.2 + math.sin(angle) * 0.3, math.sin(angle) * 0.98), "Glow")
		end
	elseif kind == "Swirl" then
		for i, degrees in { 40, 160, 280 } do
			local angle = rad(degrees)
			box(ctx, "Swirl", V(0.05, 0.05, 0.7), V(math.cos(angle) * 0.92, -0.4 + (i - 2) * 0.2, math.sin(angle) * 0.92), "Glow", ry(-degrees) * rx(17))
		end
	elseif kind == "Halo" then
		for i = 0, 5 do
			local angle = i * math.pi / 3
			ball(ctx, "Halo", 0.1, V(math.cos(angle) * 0.78, 1.38, math.sin(angle) * 0.78), "Glow")
		end
	end
end

-- Light and particles for high-tier gloves. Kept small: a soft light and a few motes.
local function buildEffect(ctx: Ctx, kind: string?, root: BasePart)
	if not kind then
		return
	end
	local glow = ctx.Design.Colors.Glow or ctx.Design.Colors.Accent
	local attachment = Instance.new("Attachment")
	attachment.Name = "EffectAttachment"
	attachment.Position = V(0, -0.5, -0.5) * ctx.Scale
	attachment.Parent = root

	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 5 * ctx.Scale
	light.Brightness = 0.6
	light.Shadows = false
	light.Parent = attachment

	if kind == "Glow" then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 3
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Speed = NumberRange.new(0.4, 1.2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
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
		emitter.Rate = 2
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.5) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
		emitter.LightEmission = 0.4
		emitter.Acceleration = V(0, 2, 0)
	elseif kind == "Sparks" then
		emitter.Speed = NumberRange.new(2, 4)
		emitter.Lifetime = NumberRange.new(0.15, 0.3)
		emitter.Rate = 4
	elseif kind == "Cosmic" then
		emitter.Color = ColorSequence.new(glow, Color3.new(1, 1, 1))
		emitter.Rotation = NumberRange.new(0, 360)
	end
	emitter.Parent = attachment
end

function GloveBuilder.GetDesign(gloveId: string): GloveDesigns.Design
	return GloveDesigns[gloveId] or GloveDesigns.Greenfield_1
end

-- side: "Right" or "Left"
function GloveBuilder.Build(gloveId: string, side: string, scale: number?): Model
	local design = GloveBuilder.GetDesign(gloveId)
	local model = Instance.new("Model")
	model.Name = `Glove{side}`
	model:SetAttribute("GloveId", gloveId)

	local ctx: Ctx = {
		Model = model,
		Design = design,
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

	local shell = SHELLS[design.Shell] or SHELLS.Boxing
	buildShell(ctx, design.Shell)
	buildKnuckles(ctx, design.Knuckles, shell.Knuckle)
	buildCuff(ctx, design.Cuff)
	buildEmblem(ctx, design.Emblem)
	for _, extra in design.Extras do
		buildExtra(ctx, extra, shell.Front)
	end
	buildEffect(ctx, design.Effect, root)

	return model
end

function GloveBuilder.BuildPair(gloveId: string): Model
	local pair = Instance.new("Model")
	pair.Name = "GlovePair"
	for _, side in { "Right", "Left" } do
		local glove = GloveBuilder.Build(gloveId, side)
		local x = if side == "Right" then 0.95 else -0.95
		glove:PivotTo(CFrame.new(x, 0, 0) * CFrame.Angles(0, if side == "Right" then rad(-12) else rad(12), 0))
		glove.Parent = pair
	end
	pair.WorldPivot = CFrame.identity
	return pair
end

-- Hands for R15 and R6, with where the glove root sits relative to that part.
local HANDS = {
	Right = { "RightHand", "Right Arm" },
	Left = { "LeftHand", "Left Arm" },
}

-- Replaces any gloves on the character with this glove. Welds keep them on through animations;
-- a new character (respawn) simply gets new gloves.
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
			local scale = math.clamp(hand.Size.X, 0.6, 1.5)
			local offset = if isR6Arm then CFrame.new(0, -hand.Size.Y / 2 + 0.3 * scale, 0) else CFrame.new(0, -0.05, 0)

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
