-- Builds every glove for both hands and checks the things that make a glove read as a glove:
-- anatomy (thumb at the front, palm inside, cuff above the hand), nothing floating loose,
-- proper mirroring, and sensible size. It can't judge how good it looks; that needs Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GlovesConfig = require(Shared.Config.GlovesConfig)
local GloveBuilder = require(Shared.Gloves.GloveBuilder)

local MAX_PARTS_PER_HAND = 90

local function parts(model: Model): { BasePart }
	local list = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "GloveRoot" then
			table.insert(list, descendant)
		end
	end
	return list
end

local function find(model: Model, name: string): BasePart?
	return model:FindFirstChild(name) :: BasePart?
end

-- Every part must touch the rest of the glove: build a graph of overlapping bounding spheres and
-- make sure it's all one piece starting from the shell.
local function floatingParts(list: { BasePart }, start: BasePart): { string }
	local reached = { [start] = true }
	local queue = { start }
	while #queue > 0 do
		local current = table.remove(queue) :: BasePart
		local r1 = current.Size.Magnitude / 2
		for _, other in list do
			if not reached[other] then
				local r2 = other.Size.Magnitude / 2
				if (current.Position - other.Position).Magnitude <= (r1 + r2) * 1.02 then
					reached[other] = true
					table.insert(queue, other)
				end
			end
		end
	end
	local loose = {}
	for _, part in list do
		if not reached[part] then
			table.insert(loose, part.Name)
		end
	end
	return loose
end

return function(t)
	t.test("every glove builds for both hands with a sensible part count", function()
		for _, glove in GlovesConfig.List do
			for _, side in { "Right", "Left" } do
				local model = GloveBuilder.Build(glove.Id, side)
				local list = parts(model)
				for _, part in list do
					t.truthy(part.Anchored and not part.CanCollide, `{glove.Id} parts start anchored and never collide`)
				end
				t.truthy(#list >= 12 and #list <= MAX_PARTS_PER_HAND, `{glove.Id} {side} has {#list} parts`)
				local _, size = model:GetBoundingBox()
				t.truthy(size.X < 3.2 and size.Y < 4.4 and size.Z < 3.2, `{glove.Id} {side} is hand-sized ({size})`)
				model:Destroy()
			end
		end
	end)

	t.test("every glove has a hand, a thumb, a wrist and a cuff in the right places", function()
		for _, glove in GlovesConfig.List do
			local model = GloveBuilder.Build(glove.Id, "Right")
			local shell = find(model, "Shell")
			local thumb = find(model, "Thumb")
			local thumbTip = find(model, "ThumbTip")
			local wrist = find(model, "Wrist")
			t.truthy(shell and thumb and thumbTip and wrist, `{glove.Id} has shell, thumb and wrist`)
			if shell and thumb and thumbTip and wrist then
				-- Thumb on the front (-Z) and slightly toward the palm, curving down toward the fist.
				t.truthy(thumb.Position.Z < shell.Position.Z - 0.3, `{glove.Id} thumb is at the front`)
				t.truthy(thumbTip.Position.Y < thumb.Position.Y, `{glove.Id} thumb curves toward the fist`)
				-- The wrist sits above the hand, the cuff above the wrist.
				t.truthy(wrist.Position.Y > shell.Position.Y, `{glove.Id} wrist above the hand`)
				local cuffTop = -math.huge
				for _, part in parts(model) do
					if part.Name == "Opening" then
						cuffTop = part.Position.Y
					end
				end
				t.truthy(cuffTop > wrist.Position.Y, `{glove.Id} cuff opening above the wrist`)
				-- Back-of-hand armour and the emblem face outward (+X), the palm panel inward.
				local palm = find(model, "Palm")
				if palm then
					t.truthy(palm.Position.X < shell.Position.X, `{glove.Id} palm on the inside`)
				end
			end
			model:Destroy()
		end
	end)

	t.test("no glove has floating, detached pieces", function()
		for _, glove in GlovesConfig.List do
			local model = GloveBuilder.Build(glove.Id, "Right")
			local list = parts(model)
			local loose = floatingParts(list, find(model, "Shell") :: BasePart)
			t.truthy(#loose == 0, `{glove.Id} has detached parts: {table.concat(loose, ", ")}`)
			model:Destroy()
		end
	end)

	t.test("left and right gloves are mirror images", function()
		for _, glove in GlovesConfig.List do
			local right = GloveBuilder.Build(glove.Id, "Right")
			local left = GloveBuilder.Build(glove.Id, "Left")
			for _, name in { "Thumb", "Palm", "Shell" } do
				local a, b = find(right, name), find(left, name)
				if a and b then
					t.near(a.Position.X, -b.Position.X, 1e-4, `{glove.Id} {name} mirrored in X`)
					t.near(a.Position.Y, b.Position.Y, 1e-4, `{glove.Id} {name} same height`)
					t.near(a.Position.Z, b.Position.Z, 1e-4, `{glove.Id} {name} same depth`)
				end
			end
			right:Destroy()
			left:Destroy()
		end
	end)

	t.test("the shop pair shows both gloves with backs toward the viewer", function()
		local pair = GloveBuilder.BuildPair("Greenfield_1")
		local right = pair:FindFirstChild("GloveRight") :: Model
		local left = pair:FindFirstChild("GloveLeft") :: Model
		t.truthy(right and left, "both gloves in the pair")
		-- Thumbs point toward the middle of the pair.
		local rightThumb = right:FindFirstChild("Thumb") :: BasePart
		local leftThumb = left:FindFirstChild("Thumb") :: BasePart
		t.truthy(rightThumb.Position.X < right:GetPivot().Position.X, "right thumb turned in")
		t.truthy(leftThumb.Position.X > left:GetPivot().Position.X, "left thumb turned in")
		pair:Destroy()
	end)

	t.test("glove looks never change glove stats", function()
		for _, glove in GlovesConfig.List do
			t.truthy(glove.Power > 0 and glove.LaunchForce >= 1, `{glove.Id} stats intact`)
		end
		t.equal(GlovesConfig.ById.Greenfield_1.Name, "Starter Mitts")
		t.equal(GlovesConfig.ById.Greenfield_10.Power, 175)
		t.equal(GlovesConfig.ById.Cosmic_10.Name, "Cosmic Annihilators")
	end)
end
