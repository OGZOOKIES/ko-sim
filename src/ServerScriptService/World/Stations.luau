-- The hub's stations, each a small building in the shared architecture with a themed centerpiece.
-- Prompts carry a Panel attribute; the client opens that panel when the prompt is triggered.
--
--   z = -70 row (facing +Z): World Portal (-250), Glove Shop (-190), Eggs (-130), Rebirth (-70)
--   z = +70 row (facing -Z): Pet Upgrader (-130), Upgrades (-70)

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EggsConfig = require(Shared.Config.EggsConfig)
local TrainingAreaConfig = require(Shared.Config.TrainingAreaConfig)
local GloveBuilder = require(Shared.Gloves.GloveBuilder)
local Format = require(Shared.Utilities.Format)
local Architecture = require(script.Parent.Architecture)
local Parts = require(script.Parent.Parts)

local Stations = {}

local V = Vector3.new
local rgb = Color3.fromRGB

local function facing(origin: Vector3, x: number, z: number, towardPositiveZ: boolean): CFrame
	local position = origin + V(x, 0, z)
	return CFrame.lookAt(position, position + (if towardPositiveZ then Vector3.zAxis else -Vector3.zAxis))
end

-- A spinning decoration (animated on the client by TrainingAreaController).
local function spin(part: BasePart, speed: number)
	part:SetAttribute("Center", part.Position)
	part:SetAttribute("BaseRotation", part.CFrame.Rotation)
	part:SetAttribute("Speed", speed)
	CollectionService:AddTag(part, TrainingAreaConfig.Tags.Spin)
end

local function pedestal(parent: Instance, base: CFrame, env, diameter: number, height: number): CFrame
	local position = base.Position
	Parts.Cylinder(parent, position + V(0, height / 2, 0), height, diameter, { Name = "Pedestal", Color = env.Stone, Material = env.StoneMaterial }, true)
	Parts.Cylinder(parent, position + V(0, height - 0.1, 0), 0.25, diameter + 0.3, { Name = "PedestalTrim", Color = env.Trim, Material = Enum.Material.Foil })
	Parts.Cylinder(parent, position + V(0, 0.15, 0), 0.3, diameter + 0.6, { Name = "PedestalFoot", Color = env.StoneDark, Material = env.StoneMaterial })
	return base * CFrame.new(0, height, 0)
end

local function prompt(part: BasePart, action: string, object: string, panel: string)
	local p = Parts.Prompt(part, action, object, { Panel = panel })
	p.MaxActivationDistance = 14
end

local function gloveShop(parent: Instance, origin: Vector3, env, world)
	local kiosk = Architecture.Kiosk(parent, facing(origin, -190, -70, true), env, {
		Name = "GloveShop",
		Title = "🥊 GLOVE SHOP",
		Subtitle = "Stronger gloves, harder punches",
	})
	-- The world's legendary glove pair on show.
	local top = pedestal(kiosk.Model, kiosk.Display, env, 3.6, 2.6)
	for _, side in { "Right", "Left" } do
		local glove = GloveBuilder.Build(`{world.Id}_10`, side, 1.5)
		local x = if side == "Right" then 1.5 else -1.5
		glove:PivotTo(top * CFrame.new(x, 3.3, 0) * CFrame.Angles(math.rad(-8), if side == "Right" then math.rad(-14) else math.rad(14), 0))
		glove.Parent = kiosk.Model
	end
	prompt(kiosk.Counter, "Open Shop", "Glove Shop", "Gloves")
end

local function eggStation(parent: Instance, origin: Vector3, env, world)
	local egg = EggsConfig.ByWorld[world.Id]
	local kiosk = Architecture.Kiosk(parent, facing(origin, -130, -70, true), env, {
		Name = "EggStation",
		Title = `🥚 {string.upper(egg.Name)}`,
		Subtitle = `{Format.Number(egg.Cost)} Wins per hatch`,
		Roof = "Flat",
	})
	local top = pedestal(kiosk.Model, kiosk.Display, env, 5.4, 1.6)
	local shellColor = world.Theme.Accent:Lerp(Color3.new(1, 1, 1), 0.45)
	local center = (top * CFrame.new(0, 3.4, 0)).Position
	Parts.Ellipsoid(kiosk.Model, center, V(4.6, 6.2, 4.6), { Name = "Egg", Color = shellColor, Material = Enum.Material.SmoothPlastic, CastShadow = true })
	Parts.Cylinder(kiosk.Model, center, 0.4, 4.75, { Name = "EggBand", Color = env.Trim, Material = Enum.Material.Foil })
	for i = 0, 5 do
		local angle = i * math.pi / 3
		local y = if i % 2 == 0 then 1.4 else -1.3
		local radius = math.sqrt(math.max(0, 1 - (y / 3.1) ^ 2)) * 2.3
		Parts.Ball(kiosk.Model, center + V(math.cos(angle) * radius, y, math.sin(angle) * radius), 0.9, { Name = "EggSpot", Color = world.Theme.Accent })
	end
	local glow = Parts.Decor(kiosk.Model, { Name = "EggGlow", Size = V(0.5, 0.5, 0.5), Transparency = 1, Position = center })
	local light = Instance.new("PointLight")
	light.Color = shellColor
	light.Range = 10
	light.Brightness = 0.7
	light.Parent = glow
	prompt(kiosk.Counter, "Hatch", egg.Name, "Eggs")
end

local function upgrader(parent: Instance, origin: Vector3, env)
	local kiosk = Architecture.Kiosk(parent, facing(origin, -130, 70, false), env, {
		Name = "PetUpgrader",
		Title = "✨ PET UPGRADER",
		Subtitle = "5 identical pets become 1 stronger pet",
	})
	local base = kiosk.Display
	local model = kiosk.Model
	local metal = rgb(70, 76, 92)
	Parts.Part(model, { Name = "MachineBase", Size = V(7, 1.6, 4.6), CFrame = base * CFrame.new(0, 0.8, 0), Color = metal, Material = Enum.Material.DiamondPlate })
	Parts.Decor(model, { Name = "MachineTrim", Size = V(7.2, 0.15, 4.8), CFrame = base * CFrame.new(0, 1.62, 0), Color = env.Trim, Material = Enum.Material.Foil })
	local chamberCenter = (base * CFrame.new(0, 4.1, 0)).Position
	Parts.Cylinder(model, chamberCenter, 4.6, 3.6, { Name = "Chamber", Color = rgb(200, 230, 255), Material = Enum.Material.Glass, Transparency = 0.55 })
	Parts.Ball(model, chamberCenter, 1.6, { Name = "Core", Color = env.Energy, Material = Enum.Material.Neon })
	Parts.Cylinder(model, chamberCenter + V(0, 2.5, 0), 0.5, 4, { Name = "ChamberCap", Color = metal, Material = Enum.Material.Metal })
	Parts.Cylinder(model, chamberCenter - V(0, 2.4, 0), 0.4, 4, { Name = "ChamberFoot", Color = env.Trim, Material = Enum.Material.Foil })
	Parts.Cylinder(model, chamberCenter + V(0, 3.4, 0), 1.4, 1.2, { Name = "Funnel", Color = metal, Material = Enum.Material.Metal })
	-- The three upgrade tiers on little stands.
	for i, color in { rgb(255, 205, 70), rgb(140, 230, 255), rgb(255, 130, 210) } do
		local stand = base * CFrame.new((i - 2) * 2.3, 1.6, -2.2)
		Parts.Cylinder(model, stand.Position + V(0, 0.4, 0), 0.8, 0.6, { Name = "OrbStand", Color = metal, Material = Enum.Material.Metal })
		Parts.Ball(model, stand.Position + V(0, 1.2, 0), 0.9, { Name = "TierOrb", Color = color, Material = Enum.Material.Neon })
	end
	local ring = Parts.Decor(model, {
		Name = "ChamberRing",
		Shape = Enum.PartType.Cylinder,
		Size = V(0.12, 5, 5),
		CFrame = CFrame.new(chamberCenter) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(20), 0, 0),
		Color = env.Energy,
		Material = Enum.Material.Neon,
		Transparency = 0.5,
	})
	spin(ring, 1.2)
	prompt(kiosk.Counter, "Upgrade Pets", "Pet Upgrader", "Fuse")
end

local function upgradeShop(parent: Instance, origin: Vector3, env)
	local kiosk = Architecture.Kiosk(parent, facing(origin, -70, 70, false), env, {
		Name = "UpgradeShop",
		Title = "⬆️ UPGRADES",
		Subtitle = "Spend Rebirth Tokens on permanent boosts",
		Roof = "Flat",
	})
	local model = kiosk.Model
	local base = kiosk.Display
	Parts.Part(model, { Name = "Console", Size = V(7, 3.4, 2.2), CFrame = base * CFrame.new(0, 1.7, 1), Color = env.Roof, Material = Enum.Material.SmoothPlastic })
	Parts.Decor(model, { Name = "ConsoleTrim", Size = V(7.2, 0.15, 2.4), CFrame = base * CFrame.new(0, 3.45, 1), Color = env.Trim, Material = Enum.Material.Foil })
	local screen = base * CFrame.new(0, 5.4, 1.6) * CFrame.Angles(math.rad(-12), 0, 0)
	Parts.Decor(model, { Name = "ScreenFrame", Size = V(6.4, 3.6, 0.3), CFrame = screen, Color = rgb(30, 34, 50), Material = Enum.Material.Metal })
	Parts.Decor(model, { Name = "Screen", Size = V(5.8, 3, 0.1), CFrame = screen * CFrame.new(0, 0, -0.18), Color = env.Energy, Material = Enum.Material.Neon, Transparency = 0.2 })
	-- Stacks of gold tokens on the counter.
	for i, height in { 3, 5, 2 } do
		for level = 1, height do
			local position = (kiosk.Counter.CFrame * CFrame.new((i - 2) * 1.6, 1.62 + level * 0.32, 0)).Position
			Parts.Cylinder(model, position, 0.3, 1.1, { Name = "Token", Color = env.Trim, Material = Enum.Material.Foil })
		end
	end
	prompt(kiosk.Counter, "Open", "Upgrade Shop", "Upgrades")
end

local function rebirthAltar(parent: Instance, origin: Vector3, env)
	local model = Instance.new("Model")
	model.Name = "RebirthAltar"
	model.Parent = parent
	local center = origin + V(-70, 0, -70)
	local purple = rgb(170, 100, 255)

	-- Three stone tiers with gold rims.
	local tierTop = 0
	for i, diameter in { 17, 12.5, 8 } do
		local height = 0.6
		Parts.Cylinder(model, center + V(0, tierTop + height / 2, 0), height, diameter, { Name = "Tier", Color = if i == 2 then env.StoneDark else env.Stone, Material = env.StoneMaterial }, true)
		Parts.Cylinder(model, center + V(0, tierTop + height - 0.05, 0), 0.12, diameter + 0.25, { Name = "TierRim", Color = env.Trim, Material = Enum.Material.Foil })
		tierTop += height
	end

	-- Obelisk with an inner energy core.
	local obeliskHeight = 13
	local obeliskCenter = center + V(0, tierTop + obeliskHeight / 2, 0)
	Parts.Part(model, { Name = "Obelisk", Size = V(2.4, obeliskHeight, 2.4), Position = obeliskCenter, Color = env.Roof, Material = Enum.Material.SmoothPlastic, CastShadow = true })
	for _, offset in { V(0, 0, -1.22), V(0, 0, 1.22), V(-1.22, 0, 0), V(1.22, 0, 0) } do
		local size = if offset.X ~= 0 then V(0.1, obeliskHeight - 3, 0.5) else V(0.5, obeliskHeight - 3, 0.1)
		Parts.Decor(model, { Name = "CoreLine", Size = size, Position = obeliskCenter + offset, Color = purple, Material = Enum.Material.Neon })
	end
	Parts.Part(model, { Name = "ObeliskCap", Size = V(3, 0.8, 3), Position = obeliskCenter + V(0, obeliskHeight / 2 + 0.4, 0), Color = env.Trim, Material = Enum.Material.Foil })
	Parts.Decor(model, {
		Name = "ObeliskTip",
		Size = V(1.8, 1.8, 1.8),
		CFrame = CFrame.new(obeliskCenter + V(0, obeliskHeight / 2 + 1.8, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Color = purple,
		Material = Enum.Material.Neon,
	})

	-- Two slowly turning halo rings.
	for i, tilt in { 15, -25 } do
		local ring = Parts.Decor(model, {
			Name = "Halo",
			Shape = Enum.PartType.Cylinder,
			Size = V(0.12, 6.5 + i, 6.5 + i),
			CFrame = CFrame.new(obeliskCenter + V(0, 1 + i * 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(tilt), 0, 0),
			Color = purple,
			Material = Enum.Material.Neon,
			Transparency = 0.45,
		})
		spin(ring, if i == 1 then 0.6 else -0.45)
	end

	local glow = Parts.Decor(model, { Name = "AltarLight", Size = V(0.5, 0.5, 0.5), Transparency = 1, Position = obeliskCenter })
	local light = Instance.new("PointLight")
	light.Color = purple
	light.Range = 16
	light.Brightness = 0.9
	light.Parent = glow

	-- Engraved tablet facing the path.
	local tablet = Parts.Part(model, { Name = "Tablet", Size = V(9, 3.4, 0.6), CFrame = CFrame.new(center + V(0, 1.7, 9.6)), Color = env.Stone, Material = env.StoneMaterial })
	Parts.Decor(model, { Name = "TabletTrim", Size = V(9.3, 0.2, 0.7), CFrame = CFrame.new(center + V(0, 3.45, 9.6)), Color = env.Trim, Material = Enum.Material.Foil })
	local label = Parts.SurfaceText(tablet, Enum.NormalId.Back, "♻️ REBIRTH ALTAR", env.Roof, 30)
	label.TextStrokeTransparency = 1
	label.Size = UDim2.fromScale(0.9, 0.6)
	label.Position = UDim2.fromScale(0.05, 0.2)

	local altarTop = model:FindFirstChild("Tier") :: BasePart
	prompt(altarTop, "Rebirth", "Rebirth Altar", "Rebirth")
end

local function worldPortal(parent: Instance, origin: Vector3, env)
	local model = Instance.new("Model")
	model.Name = "WorldPortal"
	model.Parent = parent
	local frame = facing(origin, -250, -70, true)
	local center = frame.Position

	Parts.Cylinder(model, center + V(0, 0.4, 0), 0.8, 16, { Name = "PortalBase", Color = env.Stone, Material = env.StoneMaterial }, true)
	Parts.Cylinder(model, center + V(0, 0.82, 0), 0.12, 16.3, { Name = "PortalBaseTrim", Color = env.Trim, Material = Enum.Material.Foil })

	-- A stone ring of 12 blocks standing upright, facing the path.
	local ringCenter = frame * CFrame.new(0, 8.2, 0)
	for i = 0, 11 do
		local angle = i * math.pi / 6
		local block = ringCenter * CFrame.Angles(0, 0, angle) * CFrame.new(0, 6.4, 0)
		Parts.Part(model, {
			Name = "PortalStone",
			Size = V(3.5, 2, 1.8),
			CFrame = block,
			Color = if i == 0 then env.Trim else env.Stone,
			Material = if i == 0 then Enum.Material.Foil else env.StoneMaterial,
		})
	end
	Parts.Part(model, { Name = "PortalFoot", Size = V(5, 1.4, 2.4), CFrame = frame * CFrame.new(0, 1.5, 0), Color = env.StoneDark, Material = env.StoneMaterial })

	-- The gateway itself: two layered glowing discs.
	for i, color in { env.Energy, env.Energy:Lerp(Color3.new(1, 1, 1), 0.4) } do
		Parts.Decor(model, {
			Name = "PortalSwirl",
			Shape = Enum.PartType.Cylinder,
			Size = V(0.2 + i * 0.05, 11.5 - i * 2.5, 11.5 - i * 2.5),
			CFrame = ringCenter * CFrame.Angles(0, math.rad(90), 0),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = if i == 1 then 0.45 else 0.25,
		})
	end
	local glow = Parts.Decor(model, { Name = "PortalLight", Size = V(0.5, 0.5, 0.5), Transparency = 1, CFrame = ringCenter })
	local light = Instance.new("PointLight")
	light.Color = env.Energy
	light.Range = 18
	light.Brightness = 1
	light.Parent = glow

	local plaque = Parts.Part(model, { Name = "Plaque", Size = V(8, 1.8, 0.4), CFrame = frame * CFrame.new(0, 1.1, -5.5) * CFrame.Angles(math.rad(-20), 0, 0), Color = env.Roof, Material = Enum.Material.SmoothPlastic })
	local label = Parts.SurfaceText(plaque, Enum.NormalId.Front, "🌍 WORLD PORTAL", env.Trim, 30)
	label.Size = UDim2.fromScale(0.92, 0.7)
	label.Position = UDim2.fromScale(0.04, 0.15)

	prompt(model:FindFirstChild("PortalBase") :: BasePart, "Travel", "World Portal", "Worlds")
end

function Stations.Build(parent: Instance, origin: Vector3, world, env)
	worldPortal(parent, origin, env)
	gloveShop(parent, origin, env, world)
	eggStation(parent, origin, env, world)
	rebirthAltar(parent, origin, env)
	upgrader(parent, origin, env)
	upgradeShop(parent, origin, env)
end

return Stations
