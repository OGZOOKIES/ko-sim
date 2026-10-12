-- Builds every pet model and checks every world has a complete environment.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnvironmentConfig = require(Shared.Config.EnvironmentConfig)
local PetsConfig = require(Shared.Config.PetsConfig)
local WorldsConfig = require(Shared.Config.WorldsConfig)
local PetBuilder = require(Shared.Pets.PetBuilder)

return function(t)
	t.test("every species has a real form and builds in every tier", function()
		for _, species in PetsConfig.Species do
			t.truthy(PetBuilder.HasForm(species.Form), `{species.Id} form {species.Form}`)
			for tier = 1, #PetsConfig.Tiers do
				local model = PetBuilder.Build(species.Id, tier)
				local parts, eyes = 0, 0
				for _, descendant in model:GetDescendants() do
					if descendant:IsA("BasePart") then
						parts += 1
						if descendant:GetAttribute("Role") == "Eye" or descendant.Name == "Eye" then
							eyes += 1
						end
					end
				end
				t.truthy(parts >= 6 and parts <= 40, `{species.Id} tier {tier} has {parts} parts`)
				t.truthy(eyes >= 2 or species.Form == "Golem", `{species.Id} has eyes`)
				local _, size = model:GetBoundingBox()
				t.truthy(size.Magnitude < 7, `{species.Id} stays pet-sized ({size})`)
				model:Destroy()
			end
		end
	end)

	t.test("every world has an environment", function()
		for _, world in WorldsConfig.List do
			local env = EnvironmentConfig[world.Id]
			t.truthy(env, `{world.Id} environment`)
			t.truthy(env.Terrain and env.Terrain.Ground and env.Terrain.Hills and env.Terrain.Cliff, `{world.Id} terrain materials`)
			t.truthy(#env.PropColors >= 3, `{world.Id} prop colours`)
			t.truthy(env.Sky and typeof(env.Sky.Tint) == "Color3", `{world.Id} sky`)
		end
	end)
end
