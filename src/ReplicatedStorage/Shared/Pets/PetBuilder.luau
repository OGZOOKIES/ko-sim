-- Builds pet models from PetsConfig (each species has a Form). Used for followers, the inventory
-- and the hatch reveal, so a pet always looks the same everywhere.
--
-- Pet space: origin at the body's centre, -Z is the face, about 2 studs tall at scale 1.
-- Tiers change the finish: Gold (foil), Diamond (crystal glass + sparkles), Rainbow (parts tagged
-- "Rainbow" have their colour cycled by the client).
--
--   PetBuilder.Build(speciesId, tier, scale?) -> Model  (anchored, non-colliding; PrimaryPart = root)

local PetsConfig = require(script.Parent.Parent.Config.PetsConfig)

local PetBuilder = {}

local V = Vector3.new
local rad = math.rad
local rgb = Color3.fromRGB

local BLACK = rgb(20, 20, 26)
local WHITE = rgb(255, 255, 255)
local BEAK = rgb(255, 170, 50)
local IVORY = rgb(240, 230, 205)
local GOLD = rgb(255, 205, 70)
local DIAMOND = rgb(170, 235, 255)

type Ctx = {
	Model: Model,
	Scale: number,
	Primary: Color3,
	Secondary: Color3,
	Dark: Color3,
	Accent: Color3,
	Material: Enum.Material,
}

local function rot(x: number, y: number, z: number): CFrame
	return CFrame.Angles(rad(x), rad(y), rad(z))
end

-- role: "Body" parts take the tier finish; "Detail" parts keep their colour.
local function add(ctx: Ctx, role: string, name: string, size: Vector3, cf: CFrame, color: Color3, options: { [string]: any }?): BasePart
	local className = if options and options.Class then options.Class else "Part"
	local part = Instance.new(className) :: BasePart
	if options and options.Shape then
		(part :: Part).Shape = options.Shape
	end
	part.Name = name
	part.Size = size * ctx.Scale
	part.CFrame = CFrame.new(cf.Position * ctx.Scale) * cf.Rotation
	part.Color = color
	part.Material = if options and options.Material then options.Material elseif role == "Body" then ctx.Material else Enum.Material.SmoothPlastic
	part.Transparency = if options and options.Transparency then options.Transparency else 0
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("Role", role)
	if options and options.Sphere then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Parent = ctx.Model
	return part
end

local function ell(ctx: Ctx, role: string, name: string, size: Vector3, position: Vector3, color: Color3, rotation: CFrame?, options: { [string]: any }?)
	local opts = options or {}
	opts.Sphere = true
	return add(ctx, role, name, size, CFrame.new(position) * (rotation or CFrame.identity), color, opts)
end

local function ball(ctx: Ctx, role: string, name: string, d: number, position: Vector3, color: Color3, options: { [string]: any }?)
	local opts = options or {}
	opts.Shape = Enum.PartType.Ball
	return add(ctx, role, name, V(d, d, d), CFrame.new(position), color, opts)
end

local function box(ctx: Ctx, role: string, name: string, size: Vector3, position: Vector3, color: Color3, rotation: CFrame?, options: { [string]: any }?)
	return add(ctx, role, name, size, CFrame.new(position) * (rotation or CFrame.identity), color, options)
end

local function wedge(ctx: Ctx, role: string, name: string, size: Vector3, position: Vector3, color: Color3, rotation: CFrame?)
	return add(ctx, role, name, size, CFrame.new(position) * (rotation or CFrame.identity), color, { Class = "WedgePart" })
end

-- Shared features

local function eyes(ctx: Ctx, center: Vector3, spread: number, size: number)
	for _, side in { -1, 1 } do
		local p = center + V(side * spread, 0, 0)
		ball(ctx, "Eye", "Eye", size, p, BLACK)
		ball(ctx, "Eye", "Glint", size * 0.38, p + V(side * size * 0.12 + 0.04, size * 0.18, -size * 0.36), WHITE)
	end
end

local function pointyEar(ctx: Ctx, x: number, y: number, z: number, height: number, color: Color3)
	wedge(ctx, "Body", "Ear", V(0.16, height, height * 0.62), V(x, y, z), color, rot(0, if x > 0 then -90 else 90, 0))
end

local function legs(ctx: Ctx, y: number, frontZ: number, backZ: number, spread: number, height: number, color: Color3)
	for _, z in { frontZ, backZ } do
		for _, side in { -1, 1 } do
			ell(ctx, "Body", "Leg", V(0.36, height, 0.38), V(side * spread, y, z), color)
		end
	end
end

-- Forms

local Forms = {}

function Forms.Bunny(ctx: Ctx)
	ell(ctx, "Body", "Body", V(1.6, 1.5, 1.7), V(0, -0.2, 0.15), ctx.Primary)
	ell(ctx, "Body", "Belly", V(1, 1, 0.5), V(0, -0.3, -0.55), ctx.Secondary)
	ball(ctx, "Body", "Head", 1.3, V(0, 0.65, -0.45), ctx.Primary)
	for _, side in { -1, 1 } do
		ell(ctx, "Body", "Ear", V(0.34, 1.15, 0.22), V(side * 0.26, 1.6, -0.35), ctx.Primary, rot(0, 0, -side * 10))
		ell(ctx, "Detail", "InnerEar", V(0.18, 0.85, 0.08), V(side * 0.26, 1.6, -0.46), rgb(255, 180, 200), rot(0, 0, -side * 10))
		ell(ctx, "Body", "Foot", V(0.5, 0.3, 0.75), V(side * 0.42, -0.92, -0.35), ctx.Secondary)
	end
	ball(ctx, "Body", "Tail", 0.55, V(0, -0.15, 1.0), ctx.Secondary)
	ball(ctx, "Detail", "Nose", 0.16, V(0, 0.52, -1.08), rgb(255, 140, 170))
	eyes(ctx, V(0, 0.8, -1.0), 0.3, 0.26)
end

local function birdBody(ctx: Ctx, wingScale: number)
	ell(ctx, "Body", "Body", V(1.5, 1.65, 1.5), V(0, 0, 0), ctx.Primary)
	ell(ctx, "Body", "Belly", V(1.1, 1.2, 0.55), V(0, -0.15, -0.52), ctx.Secondary)
	ell(ctx, "Detail", "Beak", V(0.36, 0.26, 0.6), V(0, 0.22, -0.86), BEAK)
	for _, side in { -1, 1 } do
		ell(ctx, "Body", "Wing", V(0.26, 0.95, 1.15) * wingScale, V(side * (0.76 + 0.1 * wingScale), 0, 0.08), ctx.Dark, rot(0, 0, side * 18))
		ell(ctx, "Detail", "Foot", V(0.3, 0.16, 0.42), V(side * 0.3, -0.85, -0.2), BEAK)
	end
	ell(ctx, "Body", "Tail", V(0.7, 0.22, 0.7), V(0, -0.3, 0.86), ctx.Dark, rot(30, 0, 0))
end

function Forms.Bird(ctx: Ctx)
	birdBody(ctx, 1)
	ell(ctx, "Body", "Tuft", V(0.2, 0.5, 0.2), V(0, 0.95, -0.2), ctx.Primary, rot(-20, 0, 0))
	eyes(ctx, V(0, 0.45, -0.66), 0.32, 0.24)
end

function Forms.Owl(ctx: Ctx)
	birdBody(ctx, 1)
	for _, side in { -1, 1 } do
		pointyEar(ctx, side * 0.45, 0.95, -0.2, 0.5, ctx.Dark)
		ball(ctx, "Detail", "EyeRing", 0.5, V(side * 0.32, 0.45, -0.6), rgb(255, 215, 90))
	end
	eyes(ctx, V(0, 0.45, -0.72), 0.32, 0.3)
end

function Forms.Phoenix(ctx: Ctx)
	birdBody(ctx, 1.35)
	for i, angle in { -25, 0, 25 } do
		wedge(ctx, "Detail", "Crest", V(0.12, 0.6 - math.abs(angle) / 100, 0.4), V(0, 1.05, -0.1 + i * 0.12), ctx.Accent, rot(0, 90, angle))
		ell(ctx, "Detail", "Plume", V(0.18, 0.18, 1.3), V((i - 2) * 0.25, -0.1, 1.3), ctx.Accent, rot(-15, (i - 2) * 15, 0), { Material = Enum.Material.Neon })
	end
	eyes(ctx, V(0, 0.45, -0.66), 0.32, 0.24)
	local light = Instance.new("PointLight")
	light.Color = ctx.Accent
	light.Range = 6
	light.Brightness = 0.8
	light.Parent = ctx.Model.PrimaryPart
end

local function quadruped(ctx: Ctx, bodySize: Vector3, headD: number, legHeight: number)
	ell(ctx, "Body", "Body", bodySize, V(0, -0.25, 0.25), ctx.Primary)
	ell(ctx, "Body", "Chest", V(bodySize.X * 0.75, bodySize.Y * 0.7, 0.6), V(0, -0.35, -0.5), ctx.Secondary)
	ball(ctx, "Body", "Head", headD, V(0, 0.45, -0.65), ctx.Primary)
	legs(ctx, -0.95, -0.25, 0.75, bodySize.X * 0.32, legHeight, ctx.Primary)
end

function Forms.Fox(ctx: Ctx)
	quadruped(ctx, V(1.2, 1.1, 1.8), 1.2, 0.6)
	ell(ctx, "Body", "Snout", V(0.55, 0.42, 0.62), V(0, 0.28, -1.22), ctx.Secondary)
	ball(ctx, "Detail", "Nose", 0.18, V(0, 0.36, -1.53), BLACK)
	pointyEar(ctx, 0.36, 1.15, -0.62, 0.62, ctx.Primary)
	pointyEar(ctx, -0.36, 1.15, -0.62, 0.62, ctx.Primary)
	ell(ctx, "Body", "Tail", V(0.62, 0.62, 1.3), V(0, -0.05, 1.25), ctx.Primary, rot(-30, 0, 0))
	ball(ctx, "Body", "TailTip", 0.5, V(0, 0.25, 1.78), ctx.Secondary)
	eyes(ctx, V(0, 0.6, -1.15), 0.28, 0.22)
end

function Forms.Dog(ctx: Ctx)
	quadruped(ctx, V(1.3, 1.15, 1.7), 1.25, 0.6)
	ell(ctx, "Body", "Snout", V(0.6, 0.45, 0.5), V(0, 0.25, -1.2), ctx.Secondary)
	ball(ctx, "Detail", "Nose", 0.2, V(0, 0.36, -1.45), BLACK)
	for _, side in { -1, 1 } do
		ell(ctx, "Body", "Ear", V(0.26, 0.65, 0.42), V(side * 0.62, 0.5, -0.6), ctx.Dark, rot(0, 0, side * 22))
	end
	ell(ctx, "Body", "Tail", V(0.24, 0.24, 0.8), V(0, 0.1, 1.15), ctx.Primary, rot(-45, 0, 0))
	eyes(ctx, V(0, 0.65, -1.18), 0.28, 0.24)
end

function Forms.Cat(ctx: Ctx)
	quadruped(ctx, V(1.15, 1.05, 1.6), 1.2, 0.55)
	ell(ctx, "Body", "Muzzle", V(0.5, 0.32, 0.3), V(0, 0.25, -1.18), ctx.Secondary)
	ball(ctx, "Detail", "Nose", 0.14, V(0, 0.38, -1.3), rgb(255, 140, 170))
	pointyEar(ctx, 0.34, 1.1, -0.6, 0.45, ctx.Primary)
	pointyEar(ctx, -0.34, 1.1, -0.6, 0.45, ctx.Primary)
	ell(ctx, "Body", "Tail", V(0.2, 0.2, 1), V(0, 0.05, 1.2), ctx.Primary, rot(-35, 0, 0))
	ell(ctx, "Body", "TailTip", V(0.2, 0.2, 0.7), V(0, 0.55, 1.55), ctx.Dark, rot(-75, 0, 0))
	eyes(ctx, V(0, 0.62, -1.12), 0.28, 0.24)
end

function Forms.Bear(ctx: Ctx)
	quadruped(ctx, V(1.7, 1.55, 1.85), 1.35, 0.55)
	ell(ctx, "Body", "Snout", V(0.62, 0.45, 0.42), V(0, 0.3, -1.25), ctx.Secondary)
	ball(ctx, "Detail", "Nose", 0.22, V(0, 0.42, -1.45), BLACK)
	for _, side in { -1, 1 } do
		ball(ctx, "Body", "Ear", 0.45, V(side * 0.48, 1.08, -0.55), ctx.Primary)
	end
	eyes(ctx, V(0, 0.7, -1.2), 0.3, 0.22)
end

function Forms.Camel(ctx: Ctx)
	ell(ctx, "Body", "Body", V(1.2, 1.1, 1.9), V(0, -0.1, 0.3), ctx.Primary)
	ell(ctx, "Body", "Hump", V(0.9, 0.8, 0.9), V(0, 0.55, 0.35), ctx.Primary)
	ell(ctx, "Body", "Neck", V(0.45, 1.1, 0.45), V(0, 0.55, -0.75), ctx.Primary, rot(-30, 0, 0))
	ell(ctx, "Body", "Head", V(0.62, 0.55, 0.95), V(0, 1.15, -1.15), ctx.Primary)
	ell(ctx, "Body", "Muzzle", V(0.5, 0.4, 0.4), V(0, 1.05, -1.62), ctx.Secondary)
	legs(ctx, -1, -0.3, 0.85, 0.36, 0.9, ctx.Primary)
	eyes(ctx, V(0, 1.3, -1.45), 0.24, 0.18)
end

local function deerBody(ctx: Ctx)
	quadruped(ctx, V(1.15, 1.05, 1.75), 1.1, 0.85)
	ell(ctx, "Body", "Snout", V(0.45, 0.38, 0.55), V(0, 0.3, -1.15), ctx.Secondary)
	ball(ctx, "Detail", "Nose", 0.15, V(0, 0.38, -1.42), BLACK)
	for _, side in { -1, 1 } do
		ell(ctx, "Body", "Ear", V(0.18, 0.5, 0.28), V(side * 0.55, 0.85, -0.55), ctx.Primary, rot(0, 0, side * 50))
	end
	eyes(ctx, V(0, 0.6, -1.08), 0.27, 0.2)
end

function Forms.Deer(ctx: Ctx)
	deerBody(ctx)
	for _, side in { -1, 1 } do
		box(ctx, "Detail", "Antler", V(0.12, 0.8, 0.12), V(side * 0.3, 1.35, -0.55), ctx.Dark, rot(0, 0, -side * 20))
		box(ctx, "Detail", "AntlerTine", V(0.1, 0.45, 0.1), V(side * 0.55, 1.5, -0.55), ctx.Dark, rot(0, 0, -side * 55))
	end
	for i = 1, 3 do
		ball(ctx, "Detail", "Spot", 0.18, V((i - 2) * 0.25, 0.25, 0.1 + i * 0.25), WHITE)
	end
end

function Forms.Unicorn(ctx: Ctx)
	deerBody(ctx)
	ell(ctx, "Detail", "Horn", V(0.16, 0.9, 0.16), V(0, 1.3, -0.9), GOLD, rot(-25, 0, 0), { Material = Enum.Material.Foil })
	for i = 0, 2 do
		ball(ctx, "Detail", "Mane", 0.38 - i * 0.04, V(0, 0.95 - i * 0.25, -0.35 + i * 0.3), ctx.Accent)
	end
	ell(ctx, "Detail", "Tail", V(0.35, 0.35, 0.9), V(0, -0.1, 1.2), ctx.Accent, rot(-40, 0, 0))
end

local function lizardBody(ctx: Ctx)
	ell(ctx, "Body", "Body", V(0.95, 0.62, 1.8), V(0, -0.5, 0), ctx.Primary)
	ell(ctx, "Body", "Head", V(0.75, 0.55, 0.85), V(0, -0.3, -1.15), ctx.Primary)
	ell(ctx, "Body", "Tail", V(0.5, 0.4, 1.05), V(0, -0.55, 1.25), ctx.Primary)
	ell(ctx, "Body", "TailTip", V(0.3, 0.28, 0.85), V(0, -0.6, 2.0), ctx.Dark)
	for _, z in { -0.5, 0.55 } do
		for _, side in { -1, 1 } do
			ell(ctx, "Body", "Leg", V(0.6, 0.22, 0.25), V(side * 0.6, -0.72, z), ctx.Dark, rot(0, 0, side * 20))
		end
	end
	for i = 0, 2 do
		wedge(ctx, "Detail", "Spike", V(0.1, 0.28, 0.3), V(0, -0.12, -0.4 + i * 0.45), ctx.Accent)
	end
	eyes(ctx, V(0, -0.12, -1.4), 0.26, 0.2)
end

function Forms.Lizard(ctx: Ctx)
	lizardBody(ctx)
end

function Forms.Serpent(ctx: Ctx)
	ball(ctx, "Body", "Coil", 1.5, V(0, -0.55, 0.25), ctx.Primary)
	ball(ctx, "Body", "Coil", 1.15, V(0.3, 0.2, 0.4), ctx.Dark)
	ell(ctx, "Body", "Neck", V(0.55, 0.9, 0.55), V(0, 0.65, -0.1), ctx.Primary, rot(-15, 0, 0))
	ell(ctx, "Body", "Head", V(0.85, 0.62, 0.95), V(0, 1.1, -0.35), ctx.Primary)
	ell(ctx, "Body", "Hood", V(1.3, 0.9, 0.15), V(0, 1.0, 0.1), ctx.Secondary)
	box(ctx, "Detail", "Tongue", V(0.08, 0.04, 0.35), V(0, 1.0, -0.9), rgb(230, 50, 60))
	eyes(ctx, V(0, 1.22, -0.7), 0.24, 0.18)
end

function Forms.Scorpion(ctx: Ctx)
	ell(ctx, "Body", "Body", V(1.25, 0.6, 1.45), V(0, -0.55, 0.1), ctx.Primary)
	ell(ctx, "Body", "Head", V(0.85, 0.45, 0.6), V(0, -0.5, -0.8), ctx.Dark)
	for _, side in { -1, 1 } do
		ell(ctx, "Body", "Arm", V(0.25, 0.25, 0.8), V(side * 0.6, -0.5, -1.05), ctx.Primary, rot(0, -side * 25, 0))
		ell(ctx, "Body", "Claw", V(0.45, 0.3, 0.5), V(side * 0.85, -0.45, -1.45), ctx.Dark)
		for i = 0, 2 do
			box(ctx, "Body", "Leg", V(0.6, 0.1, 0.1), V(side * 0.8, -0.72, -0.3 + i * 0.4), ctx.Dark, rot(0, 0, side * 25))
		end
	end
	local tail = { V(0, -0.3, 0.85), V(0, 0.15, 1.05), V(0, 0.65, 0.95), V(0, 1.0, 0.6) }
	for i, p in tail do
		ball(ctx, "Body", "TailSegment", 0.48 - i * 0.05, p, ctx.Primary)
	end
	box(ctx, "Detail", "Stinger", V(0.14, 0.4, 0.14), V(0, 1.05, 0.25), ctx.Accent, rot(-60, 0, 0))
	eyes(ctx, V(0, -0.35, -1.05), 0.18, 0.16)
end

function Forms.Beetle(ctx: Ctx)
	ell(ctx, "Body", "Shell", V(1.6, 1.0, 1.8), V(0, -0.35, 0.15), ctx.Primary)
	box(ctx, "Detail", "ShellLine", V(0.05, 0.5, 1.7), V(0, 0.08, 0.15), ctx.Dark)
	ell(ctx, "Body", "Head", V(0.8, 0.5, 0.6), V(0, -0.45, -0.85), ctx.Dark)
	ell(ctx, "Detail", "Horn", V(0.14, 0.5, 0.14), V(0, -0.15, -1.1), ctx.Accent, rot(-35, 0, 0))
	for _, side in { -1, 1 } do
		for i = 0, 2 do
			box(ctx, "Body", "Leg", V(0.6, 0.1, 0.1), V(side * 0.85, -0.75, -0.4 + i * 0.45), ctx.Dark, rot(0, 0, side * 30))
		end
	end
	eyes(ctx, V(0, -0.35, -1.1), 0.22, 0.16)
end

function Forms.Penguin(ctx: Ctx)
	ell(ctx, "Body", "Body", V(1.3, 1.85, 1.25), V(0, -0.05, 0), ctx.Primary)
	ell(ctx, "Body", "Belly", V(0.95, 1.45, 0.5), V(0, -0.15, -0.44), WHITE)
	ell(ctx, "Detail", "Beak", V(0.3, 0.2, 0.45), V(0, 0.42, -0.72), BEAK)
	for _, side in { -1, 1 } do
		ell(ctx, "Body", "Flipper", V(0.2, 0.9, 0.5), V(side * 0.7, -0.1, 0), ctx.Primary, rot(0, 0, side * 20))
		ell(ctx, "Detail", "Foot", V(0.36, 0.14, 0.5), V(side * 0.3, -1.0, -0.2), BEAK)
	end
	eyes(ctx, V(0, 0.65, -0.58), 0.27, 0.2)
end

function Forms.Yeti(ctx: Ctx)
	ell(ctx, "Body", "Body", V(1.8, 1.9, 1.6), V(0, -0.15, 0), ctx.Primary)
	ell(ctx, "Body", "Face", V(0.95, 0.8, 0.32), V(0, 0.45, -0.72), ctx.Secondary)
	for _, side in { -1, 1 } do
		ell(ctx, "Detail", "Horn", V(0.26, 0.75, 0.26), V(side * 0.58, 1.05, -0.2), IVORY, rot(0, 0, -side * 32))
		ell(ctx, "Body", "Arm", V(0.62, 1.15, 0.62), V(side * 1.0, -0.25, -0.1), ctx.Primary, rot(0, 0, side * 10))
	end
	ell(ctx, "Detail", "Mouth", V(0.4, 0.12, 0.08), V(0, 0.2, -0.88), BLACK)
	eyes(ctx, V(0, 0.55, -0.88), 0.22, 0.2)
end

function Forms.Dragon(ctx: Ctx)
	ell(ctx, "Body", "Body", V(1.3, 1.2, 1.7), V(0, -0.3, 0.2), ctx.Primary)
	ell(ctx, "Body", "Belly", V(0.9, 0.9, 0.6), V(0, -0.4, -0.45), ctx.Secondary)
	ell(ctx, "Body", "Head", V(0.95, 0.85, 1.1), V(0, 0.55, -0.95), ctx.Primary)
	ell(ctx, "Body", "Snout", V(0.6, 0.45, 0.5), V(0, 0.4, -1.5), ctx.Primary)
	for _, side in { -1, 1 } do
		ell(ctx, "Detail", "Horn", V(0.16, 0.6, 0.16), V(side * 0.3, 1.1, -0.75), IVORY, rot(40, 0, -side * 15))
		wedge(ctx, "Body", "Wing", V(0.1, 1.3, 1.4), V(side * 1.0, 0.45, 0.35), ctx.Dark, rot(0, 0, side * 35))
		ell(ctx, "Body", "Leg", V(0.38, 0.55, 0.42), V(side * 0.45, -0.95, -0.15), ctx.Primary)
	end
	ell(ctx, "Body", "Tail", V(0.4, 0.35, 1.2), V(0, -0.45, 1.3), ctx.Primary, rot(10, 0, 0))
	box(ctx, "Detail", "TailSpade", V(0.45, 0.08, 0.45), V(0, -0.55, 1.95), ctx.Accent, rot(0, 45, 0))
	for i = 0, 2 do
		wedge(ctx, "Detail", "Spike", V(0.1, 0.3, 0.32), V(0, 0.32, -0.15 + i * 0.4), ctx.Accent)
	end
	eyes(ctx, V(0, 0.75, -1.38), 0.27, 0.2)
end

function Forms.Slime(ctx: Ctx)
	ell(ctx, "Body", "Blob", V(1.9, 1.45, 1.9), V(0, -0.3, 0), ctx.Primary, nil, { Transparency = 0.12 })
	ball(ctx, "Detail", "Core", 0.8, V(0, -0.35, 0.1), ctx.Secondary, { Material = Enum.Material.Neon })
	ell(ctx, "Detail", "Shine", V(0.5, 0.25, 0.3), V(-0.4, 0.25, -0.5), WHITE, nil, { Transparency = 0.3 })
	ell(ctx, "Body", "Drip", V(0.35, 0.5, 0.35), V(0.6, -0.95, -0.4), ctx.Primary)
	eyes(ctx, V(0, 0.05, -0.85), 0.32, 0.28)
end

function Forms.Golem(ctx: Ctx)
	box(ctx, "Body", "Body", V(1.6, 1.5, 1.2), V(0, -0.35, 0), ctx.Primary, nil, { Material = Enum.Material.Basalt })
	box(ctx, "Body", "Head", V(1, 0.8, 0.9), V(0, 0.75, -0.1), ctx.Dark, nil, { Material = Enum.Material.Basalt })
	for _, side in { -1, 1 } do
		box(ctx, "Body", "Arm", V(0.6, 1.3, 0.62), V(side * 1.15, -0.4, -0.1), ctx.Dark, rot(0, 0, side * 8), { Material = Enum.Material.Basalt })
		box(ctx, "Detail", "Crack", V(0.08, 0.9, 0.05), V(side * 0.35, -0.35, -0.62), ctx.Accent, rot(0, 0, side * 15), { Material = Enum.Material.Neon })
	end
	for _, side in { -1, 1 } do
		box(ctx, "Detail", "Eye", V(0.2, 0.14, 0.06), V(side * 0.24, 0.8, -0.58), ctx.Accent, nil, { Material = Enum.Material.Neon })
	end
end

function Forms.Spirit(ctx: Ctx)
	ball(ctx, "Detail", "Core", 0.8, V(0, 0, 0), ctx.Accent, { Material = Enum.Material.Neon })
	ball(ctx, "Body", "Shell", 1.7, V(0, 0, 0), ctx.Primary, { Material = Enum.Material.Glass, Transparency = 0.45 })
	add(ctx, "Detail", "Halo", V(0.08, 1.4, 1.4), CFrame.new(0, 1.15, 0) * rot(0, 0, 90), GOLD, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon })
	for i = 1, 3 do
		ell(ctx, "Body", "Wisp", V(0.5 - i * 0.1, 0.6, 0.5 - i * 0.1), V(math.sin(i * 2) * 0.25, -0.75 - i * 0.35, 0.2 + i * 0.1), ctx.Primary, nil, { Transparency = 0.25 + i * 0.15 })
	end
	eyes(ctx, V(0, 0.15, -0.78), 0.26, 0.22)
end

function Forms.King(ctx: Ctx)
	ell(ctx, "Body", "Body", V(1.6, 1.55, 1.6), V(0, -0.2, 0), ctx.Primary)
	ell(ctx, "Body", "Belly", V(1.1, 1.0, 0.5), V(0, -0.35, -0.6), ctx.Secondary)
	add(ctx, "Detail", "CrownBand", V(0.4, 1.05, 1.05), CFrame.new(0, 0.72, 0) * rot(0, 0, 90), GOLD, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Foil })
	for i = 0, 4 do
		local angle = i * math.pi * 2 / 5
		box(ctx, "Detail", "CrownPoint", V(0.18, 0.32, 0.18), V(math.cos(angle) * 0.45, 1.02, math.sin(angle) * 0.45), GOLD, rot(0, 45, 0), { Material = Enum.Material.Foil })
	end
	ball(ctx, "Detail", "Gem", 0.2, V(0, 0.75, -0.53), ctx.Accent, { Material = Enum.Material.Neon })
	box(ctx, "Detail", "Cape", V(1.5, 1.35, 0.12), V(0, -0.15, 0.82), ctx.Accent:Lerp(rgb(140, 20, 40), 0.5), rot(10, 0, 0), { Material = Enum.Material.Fabric })
	eyes(ctx, V(0, 0.2, -0.78), 0.3, 0.24)
end

function Forms.Alien(ctx: Ctx)
	ell(ctx, "Body", "Head", V(1.4, 1.3, 1.25), V(0, 0.45, 0), ctx.Primary)
	ell(ctx, "Body", "Body", V(0.8, 0.9, 0.7), V(0, -0.65, 0), ctx.Secondary)
	for _, side in { -1, 1 } do
		ell(ctx, "Eye", "Eye", V(0.42, 0.6, 0.15), V(side * 0.32, 0.5, -0.58), BLACK, rot(0, 0, -side * 25))
		box(ctx, "Detail", "Antenna", V(0.06, 0.6, 0.06), V(side * 0.3, 1.3, 0), ctx.Dark, rot(0, 0, -side * 20))
		ball(ctx, "Detail", "AntennaTip", 0.2, V(side * 0.42, 1.6, 0), ctx.Accent, { Material = Enum.Material.Neon })
	end
end

function Forms.Jelly(ctx: Ctx)
	ell(ctx, "Body", "Dome", V(1.8, 1.25, 1.8), V(0, 0.3, 0), ctx.Primary, nil, { Material = Enum.Material.Glass, Transparency = 0.3 })
	ball(ctx, "Detail", "Glow", 0.7, V(0, 0.35, 0), ctx.Accent, { Material = Enum.Material.Neon })
	for i = 0, 4 do
		local angle = i * math.pi * 2 / 5
		ell(ctx, "Body", "Tentacle", V(0.18, 1.1, 0.18), V(math.cos(angle) * 0.55, -0.65, math.sin(angle) * 0.55), ctx.Secondary, rot(math.sin(angle) * 12, 0, math.cos(angle) * -12), { Transparency = 0.2 })
	end
	eyes(ctx, V(0, 0.35, -0.82), 0.28, 0.2)
end

function Forms.Whale(ctx: Ctx)
	ell(ctx, "Body", "Body", V(1.5, 1.2, 2.6), V(0, 0, 0.2), ctx.Primary)
	ell(ctx, "Body", "Belly", V(1.2, 0.8, 2.2), V(0, -0.35, 0.1), ctx.Secondary)
	for _, side in { -1, 1 } do
		ell(ctx, "Body", "Fluke", V(0.9, 0.12, 0.5), V(side * 0.45, 0.25, 1.65), ctx.Dark, rot(0, side * 30, 0))
		ell(ctx, "Body", "Fin", V(0.6, 0.1, 0.38), V(side * 0.85, -0.3, -0.2), ctx.Dark, rot(0, 0, -side * 30))
	end
	for i = 1, 3 do
		ball(ctx, "Detail", "Star", 0.14, V((i - 2) * 0.3, 0.6, 0.1 + i * 0.3), ctx.Accent, { Material = Enum.Material.Neon })
	end
	eyes(ctx, V(0, 0.1, -0.95), 0.55, 0.2)
end

-- Builder

function PetBuilder.Build(speciesId: string, tier: number, scale: number?): Model
	local species = PetsConfig.SpeciesById[speciesId]
	local rarity = species and PetsConfig.RaritiesById[species.Rarity]
	local model = Instance.new("Model")
	model.Name = if species then species.Name else "Pet"

	local root = Instance.new("Part")
	root.Name = "PetRoot"
	root.Size = V(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.Parent = model
	model.PrimaryPart = root

	local primary = if species then species.Color else rgb(200, 200, 200)
	local ctx: Ctx = {
		Model = model,
		Scale = (scale or 1) * (0.85 + (if rarity then rarity.Order else 1) * 0.05),
		Primary = primary,
		Secondary = primary:Lerp(WHITE, 0.45),
		Dark = primary:Lerp(BLACK, 0.35),
		Accent = if rarity then rarity.Color else WHITE,
		Material = Enum.Material.SmoothPlastic,
	}

	local form = species and Forms[species.Form] or Forms.Slime
	form(ctx)

	-- Tier finish on body parts.
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Role") == "Body" then
			if tier == 2 then
				part.Color = part.Color:Lerp(GOLD, 0.65)
				part.Material = Enum.Material.Foil
			elseif tier == 3 then
				part.Color = part.Color:Lerp(DIAMOND, 0.65)
				part.Material = Enum.Material.Glass
				part.Transparency = math.max(part.Transparency, 0.15)
			elseif tier == 4 then
				part:SetAttribute("Rainbow", true)
			end
		end
	end
	if tier == 3 then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = DIAMOND
		sparkles.Parent = root
	end
	if rarity and rarity.Order >= 5 and not model:FindFirstChildWhichIsA("PointLight", true) then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = 6
		light.Brightness = 0.7
		light.Parent = root
	end
	return model
end

-- The list of forms, for tests.
function PetBuilder.HasForm(form: string): boolean
	return Forms[form] ~= nil
end

return PetBuilder
