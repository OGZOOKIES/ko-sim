-- The runway: a stone track on a raised foundation, split into the ten landing zones.
--
--   * per zone: a stone foundation and a coloured running surface (the only physics surface)
--   * stone curbs with gold caps keep most tumbling dummies on the track
--   * a sign pylon at the start of each zone (far side, facing the camera) with the zone's
--     number, name, Wins and distance range; a glowing line across the track
--   * painted lane lines, distance lines every 50 studs and numbers every 100
--   * a finish backdrop past the last zone

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared").Utilities.Format)
local Parts = require(script.Parent.Parts)

local Runway = {}

Runway.HalfWidth = 40
Runway.Physics = PhysicalProperties.new(0.7, 0.6, 0.2, 1, 1)

local V = Vector3.new
local WHITE = Color3.new(1, 1, 1)

local function zoneSign(parent: Instance, position: Vector3, zone, color: Color3, env)
	-- Pylon, standing on the ground beside the raised track.
	Parts.Decor(parent, { Name = "PylonBase", Size = V(3.4, 2, 3.4), Position = position + V(0, -19, 0), Color = env.Stone, Material = env.StoneMaterial })
	Parts.Decor(parent, { Name = "Pylon", Size = V(1.6, 34.2, 1.6), Position = position + V(0, -0.9, 0), Color = env.Roof, Material = Enum.Material.SmoothPlastic, CastShadow = true })
	Parts.Decor(parent, { Name = "PylonBand", Size = V(1.9, 0.3, 1.9), Position = position + V(0, 0.2, 0), Color = env.Trim, Material = Enum.Material.Foil })
	Parts.Decor(parent, { Name = "PylonCap", Size = V(2, 0.4, 2), Position = position + V(0, 16.4, 0), Color = env.Trim, Material = Enum.Material.Foil })

	-- Panel facing the camera side (+Z).
	local panelCenter = position + V(7.5, 12.5, 0)
	Parts.Decor(parent, { Name = "PanelFrame", Size = V(15.6, 6.6, 0.4), Position = panelCenter, Color = env.Trim, Material = Enum.Material.Foil, CastShadow = true })
	local panel = Parts.Decor(parent, { Name = "Panel", Size = V(15, 6, 0.5), Position = panelCenter, Color = env.Roof, Material = Enum.Material.SmoothPlastic })

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = panel

	local badge = Instance.new("Frame")
	badge.Size = UDim2.fromScale(0.22, 0.78)
	badge.Position = UDim2.fromScale(0.03, 0.11)
	badge.BackgroundColor3 = color
	badge.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = badge
	local number = Instance.new("TextLabel")
	number.Size = UDim2.fromScale(1, 1)
	number.BackgroundTransparency = 1
	number.Text = tostring(zone.Index)
	number.TextScaled = true
	number.Font = Enum.Font.FredokaOne
	number.TextColor3 = WHITE
	number.TextStrokeTransparency = 0.3
	number.Parent = badge

	local function text(value: string, color: Color3, y: number, height: number)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.29, y)
		label.Size = UDim2.fromScale(0.68, height)
		label.Text = value
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.5
		label.Parent = gui
	end
	local range = if zone.Max == math.huge then `{zone.Min}+ studs` else `{zone.Min}–{zone.Max} studs`
	text(zone.Name, WHITE, 0.08, 0.38)
	text(`🏆 {Format.Number(zone.Wins)} Wins`, env.Trim, 0.48, 0.26)
	text(range, Color3.fromRGB(190, 200, 230), 0.76, 0.18)
end

function Runway.Build(parent: Instance, o: Vector3, world, env, runwayLength: number, thickness: number)
	local theme = world.Theme
	local model = Instance.new("Model")
	model.Name = "Runway"
	-- Always send the runway to every client so far zones are visible while the camera follows a
	-- launch, even with StreamingEnabled.
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	model.Parent = parent

	local half = Runway.HalfWidth
	local zones = world.Zones
	for i, zone in zones do
		local startX = zone.Min
		local endX = if i < #zones then zones[i + 1].Min else runwayLength
		local length = endX - startX
		local base = if i % 2 == 1 then theme.RunwayA else theme.RunwayB
		local color = base:Lerp(theme.Accent, (i - 1) / (#zones - 1) * 0.3)

		Parts.Part(model, {
			Name = `Foundation{i}`,
			Size = V(length, thickness - 1, half * 2),
			Position = o + V((startX + endX) / 2, -thickness / 2 - 0.5, 0),
			Color = env.StoneDark,
			Material = env.StoneMaterial,
			CustomPhysicalProperties = Runway.Physics,
		})
		Parts.Part(model, {
			Name = `Zone{i}`,
			Size = V(length, 1, half * 2),
			Position = o + V((startX + endX) / 2, -0.5, 0),
			Color = color,
			Material = theme.RunwayMaterial,
			CustomPhysicalProperties = Runway.Physics,
		})

		if i > 1 then
			Parts.Decor(model, { Name = "ZoneLine", Size = V(1, 0.12, half * 2), Position = o + V(startX, 0.06, 0), Color = WHITE, Material = Enum.Material.Neon })
		end
		zoneSign(model, o + V(startX + 4, 0, -(half + 6)), zone, color:Lerp(Color3.new(0, 0, 0), 0.2), env)
		-- A small marker post on the near side so the zone start reads from any angle.
		Parts.Decor(model, { Name = "NearPost", Size = V(1, 24, 1), Position = o + V(startX, -8, half + 4), Color = env.Roof, Material = Enum.Material.SmoothPlastic })
		Parts.Decor(model, { Name = "NearPostLight", Size = V(1.1, 0.5, 1.1), Position = o + V(startX, 4.2, half + 4), Color = color, Material = Enum.Material.Neon })
	end

	-- Painted lane lines and distance markings.
	for _, z in { -half / 2, half / 2 } do
		Parts.LongBox(model, "LaneLine", o + V(runwayLength / 2, 0.03, z), runwayLength, 0.06, 0.4, {
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Color = WHITE,
			Transparency = 0.55,
		})
	end
	for d = 50, runwayLength - 1, 50 do
		Parts.Decor(model, { Name = "DistanceLine", Size = V(0.5, 0.08, half * 2), Position = o + V(d, 0.04, 0), Color = WHITE, Transparency = 0.6 })
		if d % 100 == 0 then
			local plate = Parts.Decor(model, { Name = "DistanceNumber", Size = V(10, 0.05, 7), Position = o + V(d + 6, 0.03, half - 8), Transparency = 1 })
			local label = Parts.SurfaceText(plate, Enum.NormalId.Top, tostring(d), WHITE, 20)
			label.TextTransparency = 0.25
			label.TextStrokeTransparency = 1
		end
	end

	-- Curbs with gold caps (solid: they keep tumbling dummies on the track).
	for _, side in { -1, 1 } do
		Parts.LongBox(model, "Curb", o + V(runwayLength / 2, 1, side * (half + 0.8)), runwayLength, 2, 1.6, {
			Color = env.Stone,
			Material = env.StoneMaterial,
			CustomPhysicalProperties = Runway.Physics,
		})
		Parts.LongBox(model, "CurbCap", o + V(runwayLength / 2, 2.15, side * (half + 0.8)), runwayLength, 0.3, 1.8, {
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Color = env.Trim,
			Material = Enum.Material.Foil,
		})
		Parts.LongBox(model, "Foundation", o + V(runwayLength / 2, -thickness / 2, side * (half + 0.8)), runwayLength, thickness - 0.2, 1.6, {
			Color = env.StoneDark,
			Material = env.StoneMaterial,
		})
	end

	-- Finish backdrop beyond the last zone (non-colliding; landings past the end already count).
	local finish = o + V(runwayLength + 36, 0, 0)
	for _, z in { -36, 36 } do
		Parts.Decor(model, { Name = "FinishTower", Size = V(5, 44, 5), Position = finish + V(0, 22 - thickness, z), Color = env.Roof, Material = Enum.Material.SmoothPlastic, CastShadow = true })
		Parts.Decor(model, { Name = "FinishTowerCap", Size = V(6, 1, 6), Position = finish + V(0, 44.5 - thickness, z), Color = env.Trim, Material = Enum.Material.Foil })
	end
	local banner = Parts.Decor(model, { Name = "FinishBanner", Size = V(1, 8, 66), Position = finish + V(0, 18, 0), Color = env.Roof, Material = Enum.Material.SmoothPlastic })
	local label = Parts.SurfaceText(banner, Enum.NormalId.Left, `🏆 {string.upper(zones[#zones].Name)} 🏆`, env.Trim, 16)
	label.Size = UDim2.fromScale(0.94, 0.7)
	label.Position = UDim2.fromScale(0.03, 0.15)
end

return Runway
