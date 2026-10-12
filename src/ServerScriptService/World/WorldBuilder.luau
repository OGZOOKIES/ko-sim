-- Generates a playable world from its config using plain Parts, so no assets are needed.
-- Every world uses the same layout; only names, colors, materials and decorations change.
--
-- Layout (studs, relative to the world origin, runway pointing along +X):
--
--            z = -70:  Worlds   Gloves   Eggs   Rebirth
--   spawn ---- path (z = 0) ----------------------- launch pad | dummy | runway ->
--            z = +70:  Training bags      Fuse   Upgrades
--
--   x = -290 .. 0   hub
--   x = 0 .. end    runway, 80 studs wide, split into the ten landing zones

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BagsConfig = require(Shared.Config.BagsConfig)
local EggsConfig = require(Shared.Config.EggsConfig)
local Formulas = require(Shared.Logic.Formulas)
local Format = require(Shared.Utilities.Format)
local RagdollFactory = require(script.Parent.RagdollFactory)

export type Layout = {
	WorldId: string,
	Model: Model,
	Origin: Vector3, -- start of the runway, on the floor
	Forward: Vector3,
	Right: Vector3,
	RunwayLength: number,
	RunwayHalfWidth: number,
	SpawnLocation: SpawnLocation,
	DummyCFrame: CFrame,
	DummyOffset: number,
	StationPosition: Vector3,
	LaunchPrompt: ProximityPrompt,
}

local HUB_LENGTH = 290
local HUB_WIDTH = 260
local RUNWAY_HALF_WIDTH = 40
local FLOOR_THICKNESS = 20
local GROUND_WIDTH = 900
local MAX_PART_LENGTH = 2000
local DUMMY_OFFSET = 6

local WHITE = Color3.new(1, 1, 1)
local RUNWAY_PHYSICS = PhysicalProperties.new(0.7, 0.6, 0.2, 1, 1)

local rgb = Color3.fromRGB

local WorldBuilder = {}

-- Part helpers

local function newPart(parent: Instance, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		part.Shape = props.Shape
	end
	for key, value in props do
		if key ~= "Shape" then
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- Decoration: no collisions, no raycasts, no touches, no shadows. Keeps physics cheap.
local function decor(parent: Instance, props: { [string]: any }): Part
	local part = newPart(parent, props)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

-- An upright cylinder (Roblox cylinders lie along X, so it's rotated onto Y).
local function cylinder(parent: Instance, position: Vector3, height: number, diameter: number, props: { [string]: any }): Part
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return decor(parent, props)
end

-- A long box along X, split into pieces below Roblox's part size limit.
local function longBox(parent: Instance, name: string, center: Vector3, length: number, height: number, width: number, props: { [string]: any })
	local pieces = math.max(1, math.ceil(length / MAX_PART_LENGTH))
	local pieceLength = length / pieces
	local startX = center.X - length / 2
	for i = 0, pieces - 1 do
		local piece = table.clone(props)
		piece.Name = name
		piece.Size = Vector3.new(pieceLength, height, width)
		piece.Position = Vector3.new(startX + (i + 0.5) * pieceLength, center.Y, center.Z)
		newPart(parent, piece)
	end
end

local function sign(parent: Instance, position: Vector3, text: string, textColor: Color3, width: number, height: number, background: Color3?): TextLabel
	local anchor = decor(parent, {
		Name = "Sign",
		Size = Vector3.one,
		Transparency = 1,
		Position = position,
	})

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(width, height)
	gui.LightInfluence = 0
	gui.MaxDistance = 700
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = background or Color3.new(0, 0, 0)
	label.BackgroundTransparency = if background then 0.2 else 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = textColor
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.Parent = gui

	if background then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = label
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0.04, 0)
		padding.PaddingRight = UDim.new(0.04, 0)
		padding.PaddingTop = UDim.new(0.08, 0)
		padding.PaddingBottom = UDim.new(0.08, 0)
		padding.Parent = label
	end
	return label
end

local function prompt(parent: BasePart, actionText: string, objectText: string, attributes: { [string]: any }): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = actionText
	p.ObjectText = objectText
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	for key, value in attributes do
		p:SetAttribute(key, value)
	end
	p.Parent = parent
	return p
end

-- Stations

local function station(parent: Instance, name: string, origin: Vector3, x: number, z: number, title: string, subtitle: string, theme): (Model, Part, Vector3)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local center = origin + Vector3.new(x, 0, z)
	local base = newPart(model, {
		Name = "Base",
		Size = Vector3.new(16, 1, 16),
		Position = center + Vector3.new(0, 0.5, 0),
		Color = theme.Path,
		Material = Enum.Material.SmoothPlastic,
	})
	sign(model, center + Vector3.new(0, 18, 0), title, WHITE, 20, 4, theme.Accent:Lerp(Color3.new(0, 0, 0), 0.35))
	sign(model, center + Vector3.new(0, 14.5, 0), subtitle, WHITE, 18, 2)
	return model, base, center
end

local function buildGloveShop(parent, origin, theme)
	local model, base, c = station(parent, "GloveShop", origin, -190, -70, "🥊 Glove Shop", "Buy stronger gloves with Wins", theme)
	decor(model, { Name = "Counter", Size = Vector3.new(12, 4, 4), Position = c + Vector3.new(0, 3, 4), Color = rgb(130, 90, 55), Material = Enum.Material.Wood })
	for _, side in { -1, 1 } do
		decor(model, { Name = "Glove", Shape = Enum.PartType.Ball, Size = Vector3.new(3.2, 3.2, 3.2), Position = c + Vector3.new(side * 2.6, 6.6, 4), Color = theme.Accent })
	end
	prompt(base, "Open Shop", "Glove Shop", { Panel = "Gloves" })
end

local function buildEggStation(parent, origin, world, theme)
	local egg = EggsConfig.ByWorld[world.Id]
	local model, base, c = station(parent, "EggStation", origin, -130, -70, `🥚 {egg.Name}`, `{Format.Number(egg.Cost)} Wins per hatch`, theme)
	cylinder(model, c + Vector3.new(0, 2, 0), 2, 9, { Name = "Pedestal", Color = theme.Path:Lerp(Color3.new(0, 0, 0), 0.2) })
	local shell = decor(model, { Name = "Egg", Size = Vector3.new(7, 9, 7), Position = c + Vector3.new(0, 7.5, 0), Color = theme.Accent:Lerp(WHITE, 0.4) })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = shell
	for i = 1, 4 do
		local angle = i * math.pi / 2
		decor(model, {
			Name = "Spot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.6, 1.6, 1.6),
			Position = c + Vector3.new(math.cos(angle) * 3.1, 7.5 + (i % 2) * 1.5, math.sin(angle) * 3.1),
			Color = theme.Accent,
		})
	end
	prompt(base, "Hatch", egg.Name, { Panel = "Eggs" })
end

local function buildRebirthStation(parent, origin, theme)
	local model, base, c = station(parent, "RebirthStation", origin, -70, -70, "♻️ Rebirth", "Reset Power for a permanent boost", theme)
	cylinder(model, c + Vector3.new(0, 7, 0), 12, 4, { Name = "Pillar", Color = rgb(170, 90, 255), Material = Enum.Material.Neon })
	cylinder(model, c + Vector3.new(0, 1.2, 0), 0.4, 12, { Name = "Ring", Color = rgb(120, 60, 220), Material = Enum.Material.Neon, Transparency = 0.3 })
	prompt(base, "Rebirth", "Rebirth Altar", { Panel = "Rebirth" })
end

local function buildWorldPortal(parent, origin, theme)
	local model, base, c = station(parent, "WorldPortal", origin, -250, -70, "🌍 Worlds", "Unlock and travel to new worlds", theme)
	for _, side in { -1, 1 } do
		decor(model, { Name = "Pillar", Size = Vector3.new(2, 12, 2), Position = c + Vector3.new(side * 6, 7, 3), Color = theme.Path:Lerp(Color3.new(0, 0, 0), 0.3) })
	end
	decor(model, { Name = "Top", Size = Vector3.new(14, 2, 2), Position = c + Vector3.new(0, 14, 3), Color = theme.Path:Lerp(Color3.new(0, 0, 0), 0.3) })
	decor(model, { Name = "Portal", Size = Vector3.new(10, 11, 0.4), Position = c + Vector3.new(0, 7.5, 3), Color = rgb(90, 200, 255), Material = Enum.Material.Neon, Transparency = 0.35 })
	prompt(base, "Travel", "World Portal", { Panel = "Worlds" })
end

local function buildUpgrader(parent, origin, theme)
	local model, base, c = station(parent, "PetUpgrader", origin, -130, 70, "✨ Pet Upgrader", "5 identical pets = 1 stronger pet", theme)
	decor(model, { Name = "Machine", Size = Vector3.new(9, 7, 7), Position = c + Vector3.new(0, 4.5, -3), Color = rgb(70, 75, 90), Material = Enum.Material.DiamondPlate })
	cylinder(model, c + Vector3.new(0, 8.2, -3), 0.4, 6, { Name = "Glow", Color = rgb(255, 220, 80), Material = Enum.Material.Neon })
	local tierColors = { rgb(255, 210, 60), rgb(120, 230, 255), rgb(255, 120, 200) }
	for i, color in tierColors do
		decor(model, { Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), Position = c + Vector3.new((i - 2) * 2.6, 6, 0.6), Color = color, Material = Enum.Material.Neon })
	end
	prompt(base, "Upgrade Pets", "Pet Upgrader", { Panel = "Fuse" })
end

local function buildUpgradeShop(parent, origin, theme)
	local model, base, c = station(parent, "UpgradeShop", origin, -70, 70, "⬆️ Upgrades", "Spend Rebirth Tokens", theme)
	decor(model, { Name = "Kiosk", Size = Vector3.new(6, 8, 6), Position = c + Vector3.new(0, 5, -3), Color = rgb(40, 140, 200) })
	decor(model, { Name = "Screen", Size = Vector3.new(4.5, 3, 0.3), Position = c + Vector3.new(0, 6, -0.05), Color = rgb(80, 230, 255), Material = Enum.Material.Neon })
	prompt(base, "Open", "Upgrade Shop", { Panel = "Upgrades" })
end

local function buildTrainingArea(parent, origin, theme)
	local model = Instance.new("Model")
	model.Name = "TrainingArea"
	model.Parent = parent

	local count = #BagsConfig.List
	local spacing = 15
	local firstX = -250
	local z = 72
	local lastX = firstX + (count - 1) * spacing
	local midX = (firstX + lastX) / 2

	decor(model, { Name = "Mat", Size = Vector3.new(count * spacing + 6, 0.3, 22), Position = origin + Vector3.new(midX, 0.15, z), Color = rgb(60, 60, 70) })
	decor(model, { Name = "Beam", Size = Vector3.new(count * spacing + 2, 1.5, 1.5), Position = origin + Vector3.new(midX, 14, z), Color = rgb(90, 90, 100), Material = Enum.Material.Metal })
	for _, x in { firstX - 6, lastX + 6 } do
		decor(model, { Name = "Post", Size = Vector3.new(1.5, 14, 1.5), Position = origin + Vector3.new(x, 7, z), Color = rgb(90, 90, 100), Material = Enum.Material.Metal })
	end
	sign(model, origin + Vector3.new(midX, 23, z), "🏋️ Training Area", WHITE, 26, 5, theme.Accent:Lerp(Color3.new(0, 0, 0), 0.35))

	for i, bag in BagsConfig.List do
		local x = firstX + (i - 1) * spacing
		local position = origin + Vector3.new(x, 0, z)
		decor(model, { Name = "Rope", Size = Vector3.new(0.3, 3, 0.3), Position = position + Vector3.new(0, 11.75, 0), Color = rgb(40, 40, 40) })
		local bagPart = newPart(model, {
			Name = bag.Id .. "Bag",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(7, 4, 4),
			CFrame = CFrame.new(position + Vector3.new(0, 6.75, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = bag.Color,
			CanCollide = false,
			CanTouch = false,
		})
		local requirement = if bag.RequiredRebirths > 0 then `{bag.RequiredRebirths} Rebirths` else "Free"
		sign(model, position + Vector3.new(0, 18, 0), `{bag.Name}\n{Format.Multiplier(bag.Multiplier)} • {requirement}`, WHITE, 12, 3.5)
		prompt(bagPart, "Use Bag", bag.Name, { Bag = bag.Id })
	end
end

-- Decorations

local function placeProp(parent: Instance, decorKind: string, position: Vector3, rng: Random)
	local yaw = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)

	if decorKind == "Trees" then
		local height = rng:NextNumber(9, 16)
		cylinder(parent, position + Vector3.new(0, height / 2, 0), height, 2.4, { Name = "Trunk", Color = rgb(110, 75, 45), Material = Enum.Material.Wood })
		local leaves = rng:NextNumber(10, 15)
		decor(parent, {
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(leaves, leaves, leaves),
			Position = position + Vector3.new(0, height + leaves * 0.3, 0),
			Color = rgb(60, 150, 50):Lerp(rgb(110, 190, 70), rng:NextNumber()),
			Material = Enum.Material.Grass,
		})
	elseif decorKind == "Cacti" then
		if rng:NextNumber() < 0.3 then
			for i = 1, rng:NextInteger(2, 3) do
				local size = Vector3.new(rng:NextNumber(5, 10), rng:NextNumber(4, 9), rng:NextNumber(5, 10))
				decor(parent, {
					Name = "Ruin",
					Size = size,
					CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-4, 4), size.Y / 2 + (i - 1) * 3, rng:NextNumber(-4, 4))) * yaw,
					Color = rgb(200, 160, 110),
					Material = Enum.Material.Sandstone,
				})
			end
		else
			local height = rng:NextNumber(8, 14)
			local green = rgb(70, 140, 60)
			cylinder(parent, position + Vector3.new(0, height / 2, 0), height, 3, { Name = "Cactus", Color = green, Material = Enum.Material.Grass })
			local armSide = if rng:NextNumber() < 0.5 then -1 else 1
			decor(parent, { Name = "Arm", Size = Vector3.new(3, 1.8, 1.8), Position = position + Vector3.new(armSide * 2, height * 0.55, 0), Color = green, Material = Enum.Material.Grass })
			cylinder(parent, position + Vector3.new(armSide * 3.2, height * 0.55 + 2, 0), 4, 1.8, { Name = "Arm", Color = green, Material = Enum.Material.Grass })
		end
	elseif decorKind == "Pines" then
		if rng:NextNumber() < 0.35 then
			for _ = 1, 3 do
				local height = rng:NextNumber(4, 10)
				decor(parent, {
					Name = "Crystal",
					Size = Vector3.new(1.6, height, 1.6),
					CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-3, 3), height / 2, rng:NextNumber(-3, 3)))
						* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, math.pi), rng:NextNumber(-0.4, 0.4)),
					Color = rgb(120, 220, 255),
					Material = Enum.Material.Neon,
					Transparency = 0.25,
				})
			end
		else
			local height = rng:NextNumber(12, 20)
			cylinder(parent, position + Vector3.new(0, 2, 0), 4, 1.6, { Name = "Trunk", Color = rgb(90, 60, 40), Material = Enum.Material.Wood })
			for layer = 0, 2 do
				local size = (3 - layer) * height / 6
				decor(parent, {
					Name = "Needles",
					Size = Vector3.new(size, height / 3, size),
					CFrame = CFrame.new(position + Vector3.new(0, 4 + layer * height / 4 + height / 6, 0)) * CFrame.Angles(0, math.rad(45) + layer, 0),
					Color = rgb(40, 100, 70):Lerp(WHITE, 0.25 + layer * 0.15),
					Material = Enum.Material.Snow,
				})
			end
		end
	elseif decorKind == "Volcanic" then
		local roll = rng:NextNumber()
		if roll < 0.4 then
			cylinder(parent, position + Vector3.new(0, 0.2, 0), 0.4, rng:NextNumber(10, 22), { Name = "LavaPool", Color = rgb(255, 100, 20), Material = Enum.Material.Neon })
		elseif roll < 0.7 then
			local height = rng:NextNumber(8, 18)
			decor(parent, {
				Name = "Spike",
				Size = Vector3.new(3, height, 3),
				CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * yaw * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25)),
				Color = rgb(25, 20, 30),
				Material = Enum.Material.Glass,
			})
		else
			local size = Vector3.new(rng:NextNumber(5, 12), rng:NextNumber(3, 8), rng:NextNumber(5, 12))
			decor(parent, { Name = "Rock", Size = size, CFrame = CFrame.new(position + Vector3.new(0, size.Y / 2, 0)) * yaw, Color = rgb(55, 45, 45), Material = Enum.Material.Basalt })
		end
	elseif decorKind == "Space" then
		if rng:NextNumber() < 0.5 then
			local size = rng:NextNumber(14, 40)
			local planet = decor(parent, {
				Name = "Planet",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size, size),
				Position = position + Vector3.new(0, rng:NextNumber(60, 180), 0),
				Color = Color3.fromHSV(rng:NextNumber(), 0.5, 0.9),
			})
			if rng:NextNumber() < 0.4 then
				decor(parent, {
					Name = "Ring",
					Shape = Enum.PartType.Cylinder,
					Size = Vector3.new(0.3, size * 1.8, size * 1.8),
					CFrame = planet.CFrame * CFrame.Angles(0, 0, math.rad(90) + rng:NextNumber(-0.5, 0.5)),
					Color = rgb(220, 200, 255),
					Material = Enum.Material.Neon,
					Transparency = 0.5,
				})
			end
		else
			decor(parent, {
				Name = "FloatingPlatform",
				Size = Vector3.new(rng:NextNumber(8, 16), 1, rng:NextNumber(8, 16)),
				CFrame = CFrame.new(position + Vector3.new(0, rng:NextNumber(5, 40), 0)) * yaw,
				Color = if rng:NextNumber() < 0.5 then rgb(90, 230, 255) else rgb(200, 110, 255),
				Material = Enum.Material.Neon,
				Transparency = 0.2,
			})
		end
	end
end

local function decorate(parent: Instance, origin: Vector3, theme, runwayLength: number, seed: number)
	local folder = Instance.new("Model")
	folder.Name = "Decorations"
	folder.Parent = parent

	local rng = Random.new(seed)
	local groundY = -FLOOR_THICKNESS
	local x = -HUB_LENGTH - 60
	while x < runwayLength + 150 do
		for _, side in { -1, 1 } do
			-- Keep props clear of the hub and the runway.
			local minZ = if x < 10 then HUB_WIDTH / 2 + 20 else RUNWAY_HALF_WIDTH + 30
			local z = side * rng:NextNumber(minZ, minZ + 220)
			placeProp(folder, theme.Decor, origin + Vector3.new(x + rng:NextNumber(-15, 15), groundY, z), rng)
		end
		x += rng:NextNumber(60, 90)
	end
end

-- Runway

local function buildRunway(parent: Instance, origin: Vector3, world, runwayLength: number)
	local theme = world.Theme
	local model = Instance.new("Model")
	model.Name = "Runway"
	-- Always send the runway to every client so the far zones are visible while the camera
	-- follows a launch, even with StreamingEnabled.
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	model.Parent = parent

	local zones = world.Zones
	for i, zone in zones do
		local startX = zone.Min
		local endX = if i < #zones then zones[i + 1].Min else runwayLength
		local base = if i % 2 == 1 then theme.RunwayA else theme.RunwayB
		newPart(model, {
			Name = `Zone{i}`,
			Size = Vector3.new(endX - startX, FLOOR_THICKNESS, RUNWAY_HALF_WIDTH * 2),
			Position = origin + Vector3.new((startX + endX) / 2, -FLOOR_THICKNESS / 2, 0),
			Color = base:Lerp(theme.Accent, (i - 1) / (#zones - 1) * 0.3),
			Material = theme.RunwayMaterial,
			CustomPhysicalProperties = RUNWAY_PHYSICS,
		})

		if i > 1 then
			decor(model, {
				Name = "ZoneLine",
				Size = Vector3.new(1.2, 0.2, RUNWAY_HALF_WIDTH * 2),
				Position = origin + Vector3.new(startX, 0.1, 0),
				Color = WHITE,
				Material = Enum.Material.Neon,
			})
		end

		local range = if zone.Max == math.huge then `{zone.Min}+ studs` else `{zone.Min}-{zone.Max} studs`
		decor(model, {
			Name = "SignPost",
			Size = Vector3.new(1, 16, 1),
			Position = origin + Vector3.new(startX + 4, 8, -(RUNWAY_HALF_WIDTH + 5)),
			Color = theme.Accent,
		})
		sign(
			model,
			origin + Vector3.new(startX + 4, 20, -(RUNWAY_HALF_WIDTH + 5)),
			`{zone.Name}\n🏆 {Format.Number(zone.Wins)} Wins  •  {range}`,
			WHITE,
			32,
			8,
			theme.Accent:Lerp(Color3.new(0, 0, 0), 0.45)
		)
	end

	-- Distance markers: a line every 50 studs, a number every 100.
	for d = 50, runwayLength - 1, 50 do
		decor(model, {
			Name = "Marker",
			Size = Vector3.new(0.5, 0.15, RUNWAY_HALF_WIDTH * 2),
			Position = origin + Vector3.new(d, 0.08, 0),
			Color = WHITE,
			Transparency = 0.55,
		})
		if d % 100 == 0 then
			sign(model, origin + Vector3.new(d, 4, RUNWAY_HALF_WIDTH + 3), tostring(d), WHITE, 8, 4)
		end
	end

	-- Low rails keep most tumbling dummies on the runway.
	for _, side in { -1, 1 } do
		longBox(model, "Rail", origin + Vector3.new(runwayLength / 2, 1.5, side * (RUNWAY_HALF_WIDTH + 0.5)), runwayLength, 3, 1, {
			Anchored = true,
			Color = theme.Accent:Lerp(Color3.new(0, 0, 0), 0.3),
			Material = Enum.Material.SmoothPlastic,
			CustomPhysicalProperties = RUNWAY_PHYSICS,
		})
	end
end

-- World

function WorldBuilder.Build(world, origin: Vector3, parent: Instance): Layout
	local theme = world.Theme
	local model = Instance.new("Model")
	model.Name = world.Id
	model:SetAttribute("WorldId", world.Id)

	local runwayLength = Formulas.RunwayLength(world.Id)

	-- Ground far below, hub and runway raised on top of it.
	local groundStart = -HUB_LENGTH - 200
	local groundEnd = runwayLength + 250
	longBox(model, "Ground", origin + Vector3.new((groundStart + groundEnd) / 2, -FLOOR_THICKNESS - 2, 0), groundEnd - groundStart, 4, GROUND_WIDTH, {
		Color = theme.Ground,
		Material = theme.GroundMaterial,
	})
	newPart(model, {
		Name = "Hub",
		Size = Vector3.new(HUB_LENGTH, FLOOR_THICKNESS, HUB_WIDTH),
		Position = origin + Vector3.new(-HUB_LENGTH / 2, -FLOOR_THICKNESS / 2, 0),
		Color = theme.Hub,
		Material = theme.HubMaterial,
	})

	-- Paths: main path from spawn to the launch pad, plus branches to each station row.
	decor(model, { Name = "Path", Size = Vector3.new(262, 0.2, 14), Position = origin + Vector3.new(-134, 0.1, 0), Color = theme.Path })
	for _, x in { -250, -190, -130, -70 } do
		for _, side in { -1, 1 } do
			decor(model, { Name = "Path", Size = Vector3.new(10, 0.2, 56), Position = origin + Vector3.new(x, 0.1, side * 35), Color = theme.Path })
		end
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(14, 1, 14)
	spawnLocation.Position = origin + Vector3.new(-262, 0.5, 0)
	spawnLocation.Color = theme.Accent
	spawnLocation.Material = Enum.Material.SmoothPlastic
	spawnLocation.Duration = 0
	-- Only the first world's spawn is neutral. Other worlds are reached with RespawnLocation.
	spawnLocation.Neutral = world.Order == 1
	spawnLocation.Parent = model
	sign(model, spawnLocation.Position + Vector3.new(0, 14, 0), `{theme.Icon} {world.Name}`, WHITE, 30, 5, theme.Accent:Lerp(Color3.new(0, 0, 0), 0.4))

	local stations = Instance.new("Model")
	stations.Name = "Stations"
	stations.Parent = model
	buildWorldPortal(stations, origin, theme)
	buildGloveShop(stations, origin, theme)
	buildEggStation(stations, origin, world, theme)
	buildRebirthStation(stations, origin, theme)
	buildUpgrader(stations, origin, theme)
	buildUpgradeShop(stations, origin, theme)
	buildTrainingArea(stations, origin, theme)

	-- Launch station: a pad to stand on and a display dummy to punch.
	local launch = Instance.new("Model")
	launch.Name = "LaunchStation"
	launch.Parent = model
	decor(launch, { Name = "Pad", Size = Vector3.new(12, 0.3, 26), Position = origin + Vector3.new(-7, 0.15, 0), Color = theme.Accent })
	sign(launch, origin + Vector3.new(-7, 16, -14), "🥊 PUNCH THE DUMMY!\nCharge it up and launch it down the runway", WHITE, 30, 6, rgb(200, 40, 40))

	local dummyPosition = origin + Vector3.new(DUMMY_OFFSET, RagdollFactory.StandHeight, 0)
	-- Facing -X, toward the player.
	local dummyCFrame = CFrame.lookAt(dummyPosition, dummyPosition - Vector3.xAxis)
	local display, displayTorso = RagdollFactory.Create(dummyCFrame, theme.Accent, true)
	display.Name = "DisplayDummy"
	display.Parent = launch
	local launchPrompt = prompt(displayTorso, "Punch!", "Ragdoll Dummy", { Action = "Launch" })
	launchPrompt.MaxActivationDistance = 14

	buildRunway(model, origin, world, runwayLength)
	decorate(model, origin, theme, runwayLength, world.Order * 1000)

	model.Parent = parent

	return {
		WorldId = world.Id,
		Model = model,
		Origin = origin,
		Forward = Vector3.xAxis,
		Right = Vector3.zAxis,
		RunwayLength = runwayLength,
		RunwayHalfWidth = RUNWAY_HALF_WIDTH,
		SpawnLocation = spawnLocation,
		DummyCFrame = dummyCFrame,
		DummyOffset = DUMMY_OFFSET,
		StationPosition = dummyPosition,
		LaunchPrompt = launchPrompt,
	}
end

return WorldBuilder
