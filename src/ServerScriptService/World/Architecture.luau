-- Reusable architecture so every structure shares one design language:
-- warm stone plinths, deep navy pillars and roofs, thin gold trim, a restrained energy accent.
--
-- Everything is built in a local frame: `frame` sits on the floor at the structure's center and
-- its LookVector is the front (where players stand).
--
--   Architecture.Kiosk(parent, frame, env, options) -> { Model, Counter, Display }
--   Architecture.LampPost(parent, position, env, withLight)
--   Architecture.Arch(parent, frame, env, width, height, title)
--   Architecture.Pillar(parent, position, env, height, diameter)

local Parts = require(script.Parent.Parts)

local Architecture = {}

local V = Vector3.new

local function place(parent: Instance, frame: CFrame, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, collide: boolean?, className: string?): BasePart
	local props = { Name = name, Size = size, CFrame = frame * offset, Color = color, Material = material }
	if collide then
		return Parts.Part(parent, props, className)
	end
	return Parts.Decor(parent, props, className)
end

-- A navy column with a stone base and a gold-banded cap.
function Architecture.Pillar(parent: Instance, position: Vector3, env, height: number, diameter: number)
	Parts.Part(parent, { Name = "PillarBase", Size = V(diameter + 1, 1, diameter + 1), Position = position + V(0, 0.5, 0), Color = env.Stone, Material = env.StoneMaterial })
	Parts.Cylinder(parent, position + V(0, 1 + (height - 2) / 2, 0), height - 2, diameter, { Name = "PillarShaft", Color = env.Roof, Material = Enum.Material.SmoothPlastic, CastShadow = true }, true)
	Parts.Cylinder(parent, position + V(0, 1.15, 0), 0.3, diameter + 0.4, { Name = "PillarRing", Color = env.Trim, Material = Enum.Material.Foil })
	Parts.Part(parent, { Name = "PillarCap", Size = V(diameter + 1, 0.8, diameter + 1), Position = position + V(0, height - 0.6, 0), Color = env.Stone, Material = env.StoneMaterial })
	Parts.Decor(parent, { Name = "PillarCapTrim", Size = V(diameter + 1.3, 0.25, diameter + 1.3), Position = position + V(0, height - 0.08, 0), Color = env.Trim, Material = Enum.Material.Foil })
end

function Architecture.LampPost(parent: Instance, position: Vector3, env, withLight: boolean)
	Parts.Part(parent, { Name = "LampBase", Size = V(1.4, 0.8, 1.4), Position = position + V(0, 0.4, 0), Color = env.Stone, Material = env.StoneMaterial })
	Parts.Cylinder(parent, position + V(0, 4.3, 0), 7, 0.45, { Name = "LampPole", Color = env.Roof, Material = Enum.Material.Metal }, true)
	Parts.Decor(parent, { Name = "LampCap", Size = V(1.3, 0.3, 1.3), Position = position + V(0, 8.45, 0), Color = env.Trim, Material = Enum.Material.Foil })
	local glow = Parts.Decor(parent, { Name = "Lamp", Size = V(0.9, 1.1, 0.9), Position = position + V(0, 7.75, 0), Color = Color3.fromRGB(255, 214, 150), Material = Enum.Material.Neon })
	if withLight then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 140)
		light.Range = 18
		light.Brightness = 0.9
		light.Shadows = false
		light.Parent = glow
	end
end

-- A gateway with a sign board facing both ways. Width is the clear span between the pillars.
function Architecture.Arch(parent: Instance, frame: CFrame, env, width: number, height: number, title: string): Model
	local model = Instance.new("Model")
	model.Name = "Arch"
	model.Parent = parent
	for _, side in { -1, 1 } do
		local x = side * (width / 2 + 1.4)
		place(model, frame, "ArchBase", V(3.6, 1.2, 3.6), CFrame.new(x, 0.6, 0), env.Stone, env.StoneMaterial, true)
		place(model, frame, "ArchPillar", V(2.6, height - 1.2, 2.6), CFrame.new(x, 1.2 + (height - 1.2) / 2, 0), env.Roof, Enum.Material.SmoothPlastic, true)
		place(model, frame, "ArchBand", V(2.9, 0.3, 2.9), CFrame.new(x, height * 0.3, 0), env.Trim, Enum.Material.Foil)
		place(model, frame, "ArchBand", V(2.9, 0.3, 2.9), CFrame.new(x, height - 0.4, 0), env.Trim, Enum.Material.Foil)
		place(model, frame, "ArchGlow", V(0.2, height * 0.5, 0.2), CFrame.new(x, height * 0.55, -1.35), env.Energy, Enum.Material.Neon)
	end
	local span = width + 6
	place(model, frame, "ArchBeam", V(span, 2.4, 3), CFrame.new(0, height + 1.2, 0), env.Roof, Enum.Material.SmoothPlastic, true)
	place(model, frame, "ArchTrim", V(span + 0.2, 0.25, 3.1), CFrame.new(0, height + 0.05, 0), env.Trim, Enum.Material.Foil)
	place(model, frame, "ArchTrim", V(span + 0.2, 0.25, 3.1), CFrame.new(0, height + 2.45, 0), env.Trim, Enum.Material.Foil)
	local signWidth = math.min(width * 0.85, 34)
	local signHeight = math.clamp(signWidth * 0.2, 3.6, 6)
	local signY = height + 2.4 + signHeight / 2 + 0.3
	place(model, frame, "SignFrame", V(signWidth + 0.6, signHeight + 0.6, 0.6), CFrame.new(0, signY, 0), env.Trim, Enum.Material.Foil)
	local board = place(model, frame, "Sign", V(signWidth, signHeight, 0.8), CFrame.new(0, signY, 0), env.Roof, Enum.Material.SmoothPlastic)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local label = Parts.SurfaceText(board, face, title, env.Trim:Lerp(Color3.new(1, 1, 1), 0.2), 24)
		label.Size = UDim2.fromScale(0.94, 0.78)
		label.Position = UDim2.fromScale(0.03, 0.11)
	end
	return model
end

export type Kiosk = { Model: Model, Counter: BasePart, Display: CFrame }

export type KioskOptions = {
	Name: string,
	Title: string,
	Subtitle: string?,
	Width: number?,
	Depth: number?,
	Roof: string?, -- "Gable" | "Flat"
	Counter: boolean?,
}

-- A small open-front building: stone plinth, back wall with a navy panel, two pillars, a roof,
-- a sign on the fascia and (optionally) a counter. Returns the counter (for the prompt) and the
-- CFrame where the station's display piece should stand.
function Architecture.Kiosk(parent: Instance, frame: CFrame, env, options: KioskOptions): Kiosk
	local w = options.Width or 16
	local d = options.Depth or 12
	local model = Instance.new("Model")
	model.Name = options.Name
	model.Parent = parent

	-- Plinth and trim
	place(model, frame, "Plinth", V(w + 3, 0.8, d + 3), CFrame.new(0, 0.4, 0), env.Stone, env.StoneMaterial, true)
	place(model, frame, "PlinthTrim", V(w + 3.2, 0.14, 0.3), CFrame.new(0, 0.82, -(d + 3) / 2), env.Trim, Enum.Material.Foil)
	place(model, frame, "Step", V(w - 2, 0.4, 1.6), CFrame.new(0, 0.2, -(d + 3) / 2 - 0.8), env.StoneDark, env.StoneMaterial, true)

	-- Back wall with an inset panel and side walls
	place(model, frame, "BackWall", V(w, 10.6, 1), CFrame.new(0, 6.1, d / 2 - 0.5), env.Stone, env.StoneMaterial, true)
	place(model, frame, "BackPanel", V(w - 3, 7, 0.2), CFrame.new(0, 6, d / 2 - 1.05), env.Roof, Enum.Material.SmoothPlastic)
	place(model, frame, "BackPanelTrim", V(w - 2.6, 0.2, 0.25), CFrame.new(0, 9.6, d / 2 - 1.05), env.Trim, Enum.Material.Foil)
	for _, side in { -1, 1 } do
		place(model, frame, "SideWall", V(1, 10.6, d * 0.45), CFrame.new(side * (w / 2 - 0.5), 6.1, d / 2 - d * 0.225), env.Stone, env.StoneMaterial, true)
	end

	-- Front pillars
	for _, side in { -1, 1 } do
		local position = (frame * CFrame.new(side * (w / 2 - 0.8), 0.8, -d / 2 + 0.8)).Position
		Parts.Cylinder(model, position + V(0, 5.2, 0), 10.4, 1.4, { Name = "Pillar", Color = env.Roof, Material = Enum.Material.SmoothPlastic, CastShadow = true }, true)
		Parts.Cylinder(model, position + V(0, 0.35, 0), 0.5, 1.9, { Name = "PillarFoot", Color = env.Trim, Material = Enum.Material.Foil })
		Parts.Cylinder(model, position + V(0, 10.1, 0), 0.4, 1.8, { Name = "PillarCap", Color = env.Trim, Material = Enum.Material.Foil })
	end

	-- Fascia sign
	local fasciaY = 12.4
	local fascia = place(model, frame, "Fascia", V(w + 1, 2.4, 0.6), CFrame.new(0, fasciaY, -d / 2), env.Roof, Enum.Material.SmoothPlastic, true)
	place(model, frame, "FasciaTrim", V(w + 1.2, 0.18, 0.65), CFrame.new(0, fasciaY + 1.25, -d / 2), env.Trim, Enum.Material.Foil)
	place(model, frame, "FasciaTrim", V(w + 1.2, 0.18, 0.65), CFrame.new(0, fasciaY - 1.25, -d / 2), env.Trim, Enum.Material.Foil)
	place(model, frame, "FasciaGlow", V(w - 1, 0.12, 0.1), CFrame.new(0, fasciaY - 1.42, -d / 2 - 0.2), env.Energy, Enum.Material.Neon)
	local title = Parts.SurfaceText(fascia, Enum.NormalId.Front, options.Title, env.Trim:Lerp(Color3.new(1, 1, 1), 0.25), 26)
	title.Size = UDim2.fromScale(0.92, 0.74)
	title.Position = UDim2.fromScale(0.04, 0.13)

	-- Roof
	local eaveY = fasciaY + 1.6
	place(model, frame, "Eave", V(w + 2, 0.6, d + 2), CFrame.new(0, eaveY, 0.2), env.Roof, Enum.Material.SmoothPlastic, true)
	if (options.Roof or "Gable") == "Gable" then
		local half = (d + 2) / 2
		local height = 4
		place(model, frame, "RoofFront", V(w + 2, height, half), CFrame.new(0, eaveY + 0.3 + height / 2, 0.2 - half / 2), env.Roof, Enum.Material.Slate, true, "WedgePart")
		place(model, frame, "RoofBack", V(w + 2, height, half), CFrame.new(0, eaveY + 0.3 + height / 2, 0.2 + half / 2) * CFrame.Angles(0, math.pi, 0), env.Roof, Enum.Material.Slate, true, "WedgePart")
		local ridge = frame * CFrame.new(0, eaveY + 0.3 + height, 0.2)
		Parts.Decor(model, { Name = "Ridge", Shape = Enum.PartType.Cylinder, Size = V(w + 2.6, 0.7, 0.7), CFrame = ridge, Color = env.Trim, Material = Enum.Material.Foil })
	else
		place(model, frame, "Cornice", V(w + 2.6, 0.8, d + 2.6), CFrame.new(0, eaveY + 0.7, 0.2), env.Stone, env.StoneMaterial, true)
		place(model, frame, "CorniceTrim", V(w + 2.8, 0.15, d + 2.8), CFrame.new(0, eaveY + 1.15, 0.2), env.Trim, Enum.Material.Foil)
		place(model, frame, "RoofCap", V(w - 2, 0.8, d - 2), CFrame.new(0, eaveY + 1.6, 0.2), env.Roof, Enum.Material.SmoothPlastic)
	end
	place(model, frame, "EaveTrim", V(w + 2.2, 0.15, 0.25), CFrame.new(0, eaveY + 0.32, 0.2 - (d + 2) / 2), env.Trim, Enum.Material.Foil)

	-- Warm lantern under the fascia so the display reads at dusk.
	local lantern = place(model, frame, "Lantern", V(0.9, 1.1, 0.9), CFrame.new(0, fasciaY - 2.2, -d / 2 + 1.5), Color3.fromRGB(255, 214, 150), Enum.Material.Neon)
	place(model, frame, "LanternCap", V(1.2, 0.25, 1.2), CFrame.new(0, fasciaY - 1.55, -d / 2 + 1.5), env.Trim, Enum.Material.Foil)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 140)
	light.Range = 16
	light.Brightness = 0.8
	light.Shadows = false
	light.Parent = lantern

	-- Counter (the interaction point) or a plain floor marker.
	local counter: BasePart
	if options.Counter ~= false then
		counter = place(model, frame, "Counter", V(w - 6, 3, 1.8), CFrame.new(0, 2.3, -d / 2 + 2.4), env.Wood, Enum.Material.Wood, true)
		place(model, frame, "CounterTop", V(w - 5.6, 0.25, 2.2), CFrame.new(0, 3.92, -d / 2 + 2.4), env.Stone, env.StoneMaterial)
		place(model, frame, "CounterTrim", V(w - 5.5, 0.15, 0.1), CFrame.new(0, 3.2, -d / 2 + 1.45), env.Trim, Enum.Material.Foil)
		if options.Subtitle then
			local plaque = place(model, frame, "Plaque", V(w - 7, 1.4, 0.1), CFrame.new(0, 2.2, -d / 2 + 1.45), env.Roof, Enum.Material.SmoothPlastic)
			local label = Parts.SurfaceText(plaque, Enum.NormalId.Front, options.Subtitle, Color3.fromRGB(230, 230, 240), 30)
			label.Font = Enum.Font.GothamBold
			label.Size = UDim2.fromScale(0.94, 0.7)
			label.Position = UDim2.fromScale(0.03, 0.15)
		end
	else
		counter = place(model, frame, "Floor", V(w - 2, 0.1, d - 2), CFrame.new(0, 0.85, 0), env.Roof, Enum.Material.SmoothPlastic, true)
	end

	return {
		Model = model,
		Counter = counter,
		Display = frame * CFrame.new(0, 0.8, 1),
	}
end

return Architecture
