-- The six punching bags hanging under the pavilion beam.
--
-- Each bag is a Model tagged TrainingBag (attributes BagId, WorldId, PivotPosition). The model's
-- pivot is its hanging ring, so the client can swing it locally with PivotTo; the server never
-- moves it. Bags don't collide, so a locally swinging bag can't push anyone around.
--
-- Fixed pieces (chain, floor mat, label, Cosmic orbiters) live outside the bag model.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BagsConfig = require(Shared.Config.BagsConfig)
local TrainingAreaConfig = require(Shared.Config.TrainingAreaConfig)
local Format = require(Shared.Utilities.Format)
local Parts = require(script.Parent.Parent.Parts)

local P = TrainingAreaConfig.Palette
local Layout = TrainingAreaConfig.Layout
local Tags = TrainingAreaConfig.Tags

local STRAP_HEIGHT = 1.6 -- from the top cap up to the ring
local CAP_HEIGHT = 0.6

local Bags = {}

local function bagBody(model: Model, visual, ring: Vector3): BasePart
	local diameter = visual.Diameter
	local capY = ring.Y - STRAP_HEIGHT
	local bodyTop = capY - CAP_HEIGHT / 2
	local bodyCenter = Vector3.new(ring.X, bodyTop - visual.Length / 2, ring.Z)
	local bodyBottom = bodyTop - visual.Length

	local body = Parts.Cylinder(model, bodyCenter, visual.Length, diameter, {
		Name = "Body",
		Color = visual.Body,
		Material = visual.BodyMaterial,
	})
	body.CanQuery = true -- lets the proximity prompt and highlight find it

	Parts.Cylinder(model, Vector3.new(ring.X, capY, ring.Z), CAP_HEIGHT, diameter * 0.94, { Name = "TopCap", Color = visual.Cap, Material = visual.CapMaterial })
	Parts.Cylinder(model, Vector3.new(ring.X, bodyBottom - CAP_HEIGHT / 2, ring.Z), CAP_HEIGHT, diameter * 0.94, { Name = "BottomCap", Color = visual.Cap, Material = visual.CapMaterial })
	Parts.Ellipsoid(model, Vector3.new(ring.X, bodyBottom - CAP_HEIGHT, ring.Z), Vector3.new(diameter * 0.8, 0.8, diameter * 0.8), { Name = "BottomDome", Color = visual.Cap, Material = visual.CapMaterial })

	-- Bands, evenly spaced down the body.
	local thin = visual.TrimMaterial == Enum.Material.Neon
	for i = 1, visual.Bands do
		local y = bodyTop - visual.Length * i / (visual.Bands + 1)
		Parts.Cylinder(model, Vector3.new(ring.X, y, ring.Z), if thin then 0.18 else 0.38, diameter + 0.14, { Name = "Band", Color = visual.Trim, Material = visual.TrimMaterial })
	end

	-- Vertical reinforcement ribs.
	if visual.Ribs then
		for i = 0, 3 do
			local angle = math.rad(45 + i * 90)
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (diameter / 2 + 0.06)
			Parts.Decor(model, { Name = "Rib", Size = Vector3.new(0.3, visual.Length - 0.4, 0.3), Position = bodyCenter + offset, Color = visual.Trim, Material = visual.TrimMaterial })
		end
	end

	-- A ring of studs on the top cap for the prestige tiers.
	if visual.Crown then
		for i = 0, 7 do
			local angle = i * math.pi / 4
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (diameter * 0.47)
			Parts.Ball(model, Vector3.new(ring.X, capY + 0.35, ring.Z) + offset, 0.5, { Name = "Stud", Color = visual.Trim, Material = visual.TrimMaterial })
		end
	end

	-- Four straps from the cap edge up to the ring.
	for i = 0, 3 do
		local angle = math.rad(45 + i * 90)
		local edge = Vector3.new(ring.X + math.cos(angle) * diameter * 0.38, capY + CAP_HEIGHT / 2, ring.Z + math.sin(angle) * diameter * 0.38)
		Parts.Between(model, edge, ring, 0.35, 0.18, { Name = "Strap", Color = visual.Strap, Material = Enum.Material.Leather })
	end
	Parts.Ball(model, ring, 0.7, { Name = "Ring", Color = P.Gold, Material = Enum.Material.Metal })

	if visual.Light then
		local light = Instance.new("PointLight")
		light.Color = visual.Light
		light.Range = 10
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = body
	end

	if visual.Particles then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Shape = Enum.ParticleEmitterShape.Cylinder
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		emitter.Rate = 5
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
		emitter.Speed = NumberRange.new(0.6, 1.4)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		emitter.Color = ColorSequence.new(visual.Particles)
		emitter.LightEmission = 0.8
		emitter.LightInfluence = 0
		emitter.Parent = body
	end

	return body
end

local function label(parent: Instance, bag, visual, position: Vector3, worldId: string)
	local anchor = Parts.Decor(parent, { Name = "LabelAnchor", Size = Vector3.one, Transparency = 1, Position = position })

	local gui = Instance.new("BillboardGui")
	gui.Name = "BagLabel"
	gui.Size = UDim2.fromScale(9.5, 3.8)
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui:SetAttribute("BagId", bag.Id)
	gui:SetAttribute("WorldId", worldId)
	gui.Parent = anchor

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = P.DeepNavy
	frame.BackgroundTransparency = 0.12
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.18, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = visual.Mat
	stroke.Thickness = 2
	stroke.Parent = frame

	local function line(name: string, text: string, color: Color3, y: number, height: number)
		local text_ = Instance.new("TextLabel")
		text_.Name = name
		text_.BackgroundTransparency = 1
		text_.Position = UDim2.fromScale(0.05, y)
		text_.Size = UDim2.fromScale(0.9, height)
		text_.Font = Enum.Font.FredokaOne
		text_.Text = text
		text_.TextScaled = true
		text_.TextColor3 = color
		text_.TextStrokeTransparency = 0.3
		text_.Parent = frame
	end
	line("Title", bag.Name, visual.Mat:Lerp(Color3.new(1, 1, 1), 0.35), 0.06, 0.36)
	line("Multiplier", `💪 {Format.Multiplier(bag.Multiplier)} Power`, P.Gold, 0.43, 0.26)
	local requirement = if bag.RequiredRebirths > 0 then `🔒 {bag.RequiredRebirths} Rebirths` else "FREE"
	line("Status", requirement, Color3.new(1, 1, 1), 0.7, 0.24)

	CollectionService:AddTag(gui, Tags.Label)
end

local function orbiters(parent: Instance, center: Vector3, colors: { Color3 })
	for i, color in colors do
		local orb = Parts.Ball(parent, center, 0.55, { Name = "Orbiter", Color = color, Material = Enum.Material.Neon })
		orb:SetAttribute("Center", center)
		orb:SetAttribute("Radius", 3.6)
		orb:SetAttribute("Speed", 1.6 + i * 0.25)
		orb:SetAttribute("Phase", (i - 1) * math.pi * 2 / #colors)
		orb:SetAttribute("Tilt", 0.35 * i)
		CollectionService:AddTag(orb, Tags.Orbiter)
	end
end

-- Builds every bag. `c` is the pavilion floor center at hub level.
function Bags.Build(parent: Instance, c: Vector3, worldId: string)
	local folder = Instance.new("Model")
	folder.Name = "Bags"
	folder.Parent = parent

	local count = #BagsConfig.List
	local floorY = c.Y + Layout.FloorHeight
	local beamY = c.Y + Layout.BeamBottom

	for i, bag in BagsConfig.List do
		local visual = TrainingAreaConfig.Bags[bag.Id]
		assert(visual, `TrainingAreaConfig is missing visuals for bag {bag.Id}`)

		local x = c.X + (i - (count + 1) / 2) * Layout.BagSpacing
		local bagBottom = floorY + Layout.BagBottom
		local ringY = bagBottom + CAP_HEIGHT * 1.5 + visual.Length + STRAP_HEIGHT
		local ring = Vector3.new(x, ringY, c.Z)

		-- Floor mat with a gold rim.
		-- (Sits just above the navy runner so the surfaces don't flicker.)
		Parts.Cylinder(folder, Vector3.new(x, floorY + 0.1, c.Z), 0.06, visual.Diameter + 5.6, { Name = "MatRim", Color = P.Gold, Material = Enum.Material.Foil })
		Parts.Cylinder(folder, Vector3.new(x, floorY + 0.14, c.Z), 0.06, visual.Diameter + 5, { Name = "Mat", Color = visual.Mat:Lerp(P.DeepNavy, 0.35), Material = Enum.Material.Fabric })

		-- Chain from the beam to the ring, with a gold mount on the beam.
		Parts.Cylinder(folder, Vector3.new(x, beamY - 0.2, c.Z), 0.4, 1.4, { Name = "Mount", Color = P.Gold, Material = Enum.Material.Foil })
		Parts.Between(folder, ring + Vector3.new(0, 0.3, 0), Vector3.new(x, beamY - 0.4, c.Z), 0.3, 0.3, { Name = "Chain", Color = Color3.fromRGB(60, 62, 70), Material = Enum.Material.Metal })

		local model = Instance.new("Model")
		model.Name = bag.Id .. "Bag"
		local body = bagBody(model, visual, ring)
		model.PrimaryPart = body
		model.WorldPivot = CFrame.new(ring)
		model:SetAttribute("BagId", bag.Id)
		model:SetAttribute("WorldId", worldId)
		model:SetAttribute("PivotPosition", ring)
		model.Parent = folder
		CollectionService:AddTag(model, Tags.Bag)

		local prompt = Parts.Prompt(body, "Use Bag", bag.Name, { Bag = bag.Id })
		prompt.MaxActivationDistance = 10
		prompt.UIOffset = Vector2.new(0, 40)

		label(folder, bag, visual, Vector3.new(x, ring.Y + 3.2, c.Z), worldId)

		if visual.Orbiters then
			orbiters(folder, Vector3.new(x, bagBottom + visual.Length / 2, c.Z), visual.Orbiters)
		end
	end
end

return Bags
