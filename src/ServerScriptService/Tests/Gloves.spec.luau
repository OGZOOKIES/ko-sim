-- Builds every glove for both hands to catch broken designs before a player equips them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GlovesConfig = require(Shared.Config.GlovesConfig)
local GloveBuilder = require(Shared.Gloves.GloveBuilder)

local MAX_PARTS_PER_HAND = 60

return function(t)
	t.test("every glove builds for both hands with a sensible part count", function()
		for _, glove in GlovesConfig.List do
			for _, side in { "Right", "Left" } do
				local model = GloveBuilder.Build(glove.Id, side)
				local parts = 0
				for _, descendant in model:GetDescendants() do
					if descendant:IsA("BasePart") then
						parts += 1
						t.truthy(descendant.Anchored, `{glove.Id} parts start anchored`)
						t.truthy(not descendant.CanCollide, `{glove.Id} parts never collide`)
					end
				end
				t.truthy(model.PrimaryPart ~= nil, `{glove.Id} has a root`)
				t.truthy(parts >= 8 and parts <= MAX_PARTS_PER_HAND, `{glove.Id} {side} has {parts} parts`)
				-- Gloves must stay hand-sized (a character's arm is about 2 studs long).
				local _, size = model:GetBoundingBox()
				t.truthy(size.X < 3.2 and size.Y < 5 and size.Z < 3.2, `{glove.Id} {side} is {size} studs`)
				model:Destroy()
			end
		end
	end)

	t.test("left and right gloves mirror each other", function()
		local right = GloveBuilder.Build("Greenfield_1", "Right")
		local left = GloveBuilder.Build("Greenfield_1", "Left")
		local rightThumb = right:FindFirstChild("Thumb") :: BasePart
		local leftThumb = left:FindFirstChild("Thumb") :: BasePart
		t.near(rightThumb.Position.X, -leftThumb.Position.X, 1e-4, "thumbs are on opposite sides")
		t.near(rightThumb.Position.Y, leftThumb.Position.Y, 1e-4)
		right:Destroy()
		left:Destroy()
	end)
end
