-- Small helpers for building scenery out of Parts. Used by WorldBuilder and TrainingArea.
--
-- Part     anchored, collidable part (architecture, floors)
-- Decor    anchored, no collisions/queries/touches/shadows (details; keeps physics cheap)
-- Others build on those two.

local Parts = {}

local MAX_PART_LENGTH = 2000

function Parts.Part(parent: Instance, props: { [string]: any }, className: string?): BasePart
	local part = Instance.new(className or "Part") :: any
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		part.Shape = props.Shape
	end
	for key, value in props do
		if key ~= "Shape" then
			part[key] = value
		end
	end
	part.Parent = parent
	return part
end

function Parts.Decor(parent: Instance, props: { [string]: any }, className: string?): BasePart
	local part = Parts.Part(parent, props, className)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	if props.CastShadow == nil then
		part.CastShadow = false
	end
	return part
end

-- An upright cylinder (Roblox cylinders lie along X, so it's rotated onto Y).
function Parts.Cylinder(parent: Instance, position: Vector3, height: number, diameter: number, props: { [string]: any }, collide: boolean?): BasePart
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return if collide then Parts.Part(parent, props) else Parts.Decor(parent, props)
end

-- A box stretched between two points (straps, chains, path pieces).
function Parts.Between(parent: Instance, a: Vector3, b: Vector3, width: number, height: number, props: { [string]: any }, collide: boolean?): BasePart
	props.Size = Vector3.new(width, height, (b - a).Magnitude)
	props.CFrame = CFrame.lookAt((a + b) / 2, b)
	return if collide then Parts.Part(parent, props) else Parts.Decor(parent, props)
end

-- A stretched sphere (eggs, bushes, hills).
function Parts.Ellipsoid(parent: Instance, position: Vector3, size: Vector3, props: { [string]: any }): BasePart
	props.Size = size
	props.Position = position
	local part = Parts.Decor(parent, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

function Parts.Ball(parent: Instance, position: Vector3, diameter: number, props: { [string]: any }): BasePart
	props.Shape = Enum.PartType.Ball
	props.Size = Vector3.new(diameter, diameter, diameter)
	props.Position = position
	return Parts.Decor(parent, props)
end

-- A long box along X, split into pieces below Roblox's part size limit.
function Parts.LongBox(parent: Instance, name: string, center: Vector3, length: number, height: number, width: number, props: { [string]: any })
	local pieces = math.max(1, math.ceil(length / MAX_PART_LENGTH))
	local pieceLength = length / pieces
	local startX = center.X - length / 2
	for i = 0, pieces - 1 do
		local piece = table.clone(props)
		piece.Name = name
		piece.Size = Vector3.new(pieceLength, height, width)
		piece.Position = Vector3.new(startX + (i + 0.5) * pieceLength, center.Y, center.Z)
		Parts.Part(parent, piece)
	end
end

-- A floating label that always faces the camera. Width/height are in studs.
function Parts.Sign(parent: Instance, position: Vector3, text: string, textColor: Color3, width: number, height: number, background: Color3?): TextLabel
	local anchor = Parts.Decor(parent, {
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

-- Text painted on one face of a part.
function Parts.SurfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3, pixelsPerStud: number?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 20
	gui.LightInfluence = 0
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(10, 12, 30)
	label.Parent = gui
	return label
end

function Parts.Prompt(parent: BasePart, actionText: string, objectText: string, attributes: { [string]: any }): ProximityPrompt
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

-- Points along a cubic Bezier curve, for curved paths.
function Parts.Bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, samples: number): { Vector3 }
	local points = {}
	for i = 0, samples do
		local t = i / samples
		local u = 1 - t
		table.insert(points, p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t))
	end
	return points
end

return Parts
