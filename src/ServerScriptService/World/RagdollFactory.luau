-- Builds the punchable dummy: six parts joined by ball sockets, no Humanoid.
-- Cheap to simulate, and it flops around nicely when launched.
--
-- Collision groups:
--   Ragdolls   never collide with other ragdolls or with player characters,
--              so players can't block or push each other's launches.
--   Characters every player character part.

local PhysicsService = game:GetService("PhysicsService")

local RagdollFactory = {}

RagdollFactory.RagdollGroup = "Ragdolls"
RagdollFactory.CharacterGroup = "Characters"

-- Center of the torso above the floor when the dummy stands up.
RagdollFactory.StandHeight = 3.05

local SKIN = Color3.fromRGB(245, 205, 60)
local PANTS = Color3.fromRGB(50, 60, 90)
local PHYSICS = PhysicalProperties.new(0.7, 0.8, 0.25, 1, 1)

type Limb = {
	Name: string,
	Size: Vector3,
	Offset: Vector3, -- from the torso center
	Joint: Vector3, -- joint position, from the torso center
	Color: Color3,
	Ball: boolean?,
}

local LIMBS: { Limb } = {
	{ Name = "Head", Size = Vector3.new(1.3, 1.3, 1.3), Offset = Vector3.new(0, 1.65, 0), Joint = Vector3.new(0, 1, 0), Color = SKIN, Ball = true },
	{ Name = "LeftArm", Size = Vector3.new(1, 2, 1), Offset = Vector3.new(-1.5, 0, 0), Joint = Vector3.new(-1.5, 0.8, 0), Color = SKIN },
	{ Name = "RightArm", Size = Vector3.new(1, 2, 1), Offset = Vector3.new(1.5, 0, 0), Joint = Vector3.new(1.5, 0.8, 0), Color = SKIN },
	{ Name = "LeftLeg", Size = Vector3.new(1, 2, 1), Offset = Vector3.new(-0.5, -2, 0), Joint = Vector3.new(-0.5, -1, 0), Color = PANTS },
	{ Name = "RightLeg", Size = Vector3.new(1, 2, 1), Offset = Vector3.new(0.5, -2, 0), Joint = Vector3.new(0.5, -1, 0), Color = PANTS },
}

local groupsReady = false

function RagdollFactory.SetupCollisionGroups()
	if groupsReady then
		return
	end
	groupsReady = true
	for _, group in { RagdollFactory.RagdollGroup, RagdollFactory.CharacterGroup } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(RagdollFactory.RagdollGroup, RagdollFactory.RagdollGroup, false)
	PhysicsService:CollisionGroupSetCollidable(RagdollFactory.RagdollGroup, RagdollFactory.CharacterGroup, false)
end

-- Puts every part of a character (including ones added later, like hats) in the Characters group.
function RagdollFactory.AssignCharacter(character: Model)
	local function assign(instance: Instance)
		if instance:IsA("BasePart") then
			instance.CollisionGroup = RagdollFactory.CharacterGroup
		end
	end
	for _, descendant in character:GetDescendants() do
		assign(descendant)
	end
	character.DescendantAdded:Connect(assign)
end

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, anchored: boolean, ball: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	if ball then
		part.Shape = Enum.PartType.Ball
	end
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = anchored
	part.CustomPhysicalProperties = PHYSICS
	part.CollisionGroup = RagdollFactory.RagdollGroup
	part.CanTouch = false
	return part
end

-- rootCFrame is the torso's CFrame. Anchored dummies are for display and have no joints.
function RagdollFactory.Create(rootCFrame: CFrame, torsoColor: Color3, anchored: boolean): (Model, BasePart)
	RagdollFactory.SetupCollisionGroups()

	local model = Instance.new("Model")
	model.Name = "Ragdoll"

	local torso = makePart("Torso", Vector3.new(2, 2, 1), rootCFrame, torsoColor, anchored)
	torso.Parent = model

	for _, limb in LIMBS do
		local part = makePart(limb.Name, limb.Size, rootCFrame * CFrame.new(limb.Offset), limb.Color, anchored, limb.Ball)
		part.Parent = model

		if not anchored then
			local torsoAttachment = Instance.new("Attachment")
			torsoAttachment.Name = limb.Name .. "Joint"
			torsoAttachment.Position = limb.Joint
			torsoAttachment.Parent = torso

			local limbAttachment = Instance.new("Attachment")
			limbAttachment.Name = "Joint"
			limbAttachment.Position = limb.Joint - limb.Offset
			limbAttachment.Parent = part

			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = torsoAttachment
			socket.Attachment1 = limbAttachment
			socket.LimitsEnabled = true
			socket.UpperAngle = 60
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = -40
			socket.TwistUpperAngle = 40
			socket.Parent = part
		end

		if limb.Name == "Head" then
			local face = Instance.new("Decal")
			face.Texture = "rbxasset://textures/face.png"
			face.Face = Enum.NormalId.Front
			face.Parent = part
		end
	end

	model.PrimaryPart = torso
	return model, torso
end

return RagdollFactory
