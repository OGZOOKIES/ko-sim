-- Small 3D previews (ViewportFrames) of pets for cards and reveals, using the same PetBuilder
-- models as the followers in the world.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PetBuilder = require(ReplicatedStorage:WaitForChild("Shared").Pets.PetBuilder)

local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)

local make = Components.Make

local Previews = {}

local PET_CAMERA = CFrame.lookAt(Vector3.new(1.3, 0.9, -4.4), Vector3.new(0, 0.05, 0))

function Previews.Pet(parent: Instance, speciesId: string, tier: number, size: UDim2, position: UDim2?, background: Color3?): (ViewportFrame, Model)
	local viewport = make("ViewportFrame", {
		Size = size,
		Position = position or UDim2.new(),
		BackgroundColor3 = background or Theme.Colors.Background,
		BackgroundTransparency = if background then 0.35 else 0.25,
		Ambient = Color3.fromRGB(160, 160, 175),
		LightColor = Color3.fromRGB(255, 248, 235),
		LightDirection = Vector3.new(-0.5, -1, 0.7),
		Parent = parent,
	})
	Components.Corner(viewport, 12)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = PET_CAMERA
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local model = PetBuilder.Build(speciesId, tier)
	model:PivotTo(CFrame.Angles(0, math.rad(-20), 0))
	model.Parent = viewport
	return viewport, model
end

return Previews
