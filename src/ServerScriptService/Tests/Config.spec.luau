-- Checks every config file for mistakes a designer could easily make.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local BagsConfig = require(Config.BagsConfig)
local EggsConfig = require(Config.EggsConfig)
local GloveDesigns = require(Config.GloveDesigns)
local GlovesConfig = require(Config.GlovesConfig)
local PetsConfig = require(Config.PetsConfig)
local TrainingAreaConfig = require(Config.TrainingAreaConfig)
local UpgradesConfig = require(Config.UpgradesConfig)
local WorldsConfig = require(Config.WorldsConfig)

return function(t)
	t.test("there are five worlds in order", function()
		t.equal(#WorldsConfig.List, 5)
		for i, world in WorldsConfig.List do
			t.equal(world.Order, i, `{world.Id} order`)
		end
	end)

	t.test("every world has ten contiguous zones with rising rewards", function()
		for _, world in WorldsConfig.List do
			t.equal(#world.Zones, 10, `{world.Id} zone count`)
			t.equal(world.Zones[1].Min, 0, `{world.Id} first zone starts at 0`)
			t.equal(world.Zones[10].Max, math.huge, `{world.Id} last zone is open-ended`)
			for i = 2, 10 do
				local previous, zone = world.Zones[i - 1], world.Zones[i]
				t.equal(zone.Min, previous.Max + 1, `{world.Id} zone {i} follows zone {i - 1} with no gap or overlap`)
				t.truthy(zone.Min > previous.Min, `{world.Id} zone {i} starts after zone {i - 1}`)
				t.truthy(zone.Wins > previous.Wins, `{world.Id} zone {i} pays more than zone {i - 1}`)
			end
		end
	end)

	t.test("greenfield zones match the design table", function()
		local expected = {
			{ "Starter Field", 0, 50, 1 },
			{ "Wooden Fence", 51, 100, 2 },
			{ "Hay Bale Hill", 101, 175, 4 },
			{ "Windmill Ridge", 176, 250, 7 },
			{ "Farmer's Bridge", 251, 350, 12 },
			{ "Apple Orchard", 351, 450, 20 },
			{ "Rolling Hills", 451, 575, 35 },
			{ "Waterfall Bend", 576, 700, 60 },
			{ "Giant Oak", 701, 850, 100 },
			{ "Meadow Summit", 851, math.huge, 175 },
		}
		for i, row in expected do
			local zone = WorldsConfig.ById.Greenfield.Zones[i]
			t.equal(zone.Name, row[1])
			t.equal(zone.Min, row[2], `{row[1]} min`)
			t.equal(zone.Max, row[3], `{row[1]} max`)
			t.equal(zone.Wins, row[4], `{row[1]} wins`)
		end
	end)

	t.test("later worlds' rewards match the design", function()
		local expected = {
			Desert = { 150, 225, 350, 500, 750, 1100, 1600, 2400, 3500, 5000 },
			Frostbite = { 4000, 6000, 9000, 13000, 19000, 28000, 42000, 62000, 90000, 135000 },
			Inferno = { 100000, 150000, 225000, 340000, 500000, 750000, 1100000, 1650000, 2500000, 3750000 },
			Cosmic = { 3000000, 4500000, 6750000, 10000000, 15000000, 22500000, 34000000, 51000000, 76000000, 115000000 },
		}
		for worldId, wins in expected do
			for i, amount in wins do
				t.equal(WorldsConfig.ById[worldId].Zones[i].Wins, amount, `{worldId} zone {i}`)
			end
		end
	end)

	t.test("every world has ten gloves with rising power and cost", function()
		for _, world in WorldsConfig.List do
			local gloves = GlovesConfig.ByWorld[world.Id]
			t.equal(#gloves, 10, `{world.Id} glove count`)
			for i = 2, 10 do
				t.truthy(gloves[i].Power > gloves[i - 1].Power, `{gloves[i].Name} is stronger than {gloves[i - 1].Name}`)
				t.truthy(gloves[i].Cost > gloves[i - 1].Cost, `{gloves[i].Name} costs more than {gloves[i - 1].Name}`)
			end
		end
		t.equal(#GlovesConfig.List, 50)
		t.equal(GlovesConfig.ById[GlovesConfig.StarterGloveId].Cost, 0, "starter glove is free")
	end)

	t.test("greenfield glove powers match the design", function()
		local powers = { 1, 2, 4, 7, 12, 20, 35, 60, 100, 175 }
		for i, power in powers do
			t.equal(GlovesConfig.ByWorld.Greenfield[i].Power, power, `glove {i}`)
		end
	end)

	t.test("glove and pet names are unique", function()
		local seen = {}
		for _, glove in GlovesConfig.List do
			t.truthy(not seen[glove.Name], `duplicate glove name {glove.Name}`)
			seen[glove.Name] = true
		end
		local seenPets = {}
		for _, species in PetsConfig.Species do
			t.truthy(not seenPets[species.Name], `duplicate pet name {species.Name}`)
			seenPets[species.Name] = true
		end
		t.equal(#PetsConfig.Species, 40)
	end)

	t.test("rarity probabilities add up to 100%", function()
		local total = 0
		for _, rarity in PetsConfig.Rarities do
			total += rarity.Probability
		end
		t.near(total, 100, 1e-9)
		t.equal(#PetsConfig.Rarities, 8)
	end)

	t.test("every egg has eight unique species, one of each rarity, from its world", function()
		t.equal(#EggsConfig.List, 5)
		for _, egg in EggsConfig.List do
			t.equal(#egg.Pets, 8, `{egg.Id} species count`)
			local rarities = {}
			local species = {}
			for _, speciesId in egg.Pets do
				local info = PetsConfig.SpeciesById[speciesId]
				t.truthy(info, `{egg.Id} contains unknown species {speciesId}`)
				t.equal(info.World, egg.World, `{speciesId} belongs to {egg.World}`)
				t.truthy(not species[speciesId], `{egg.Id} lists {speciesId} twice`)
				species[speciesId] = true
				rarities[info.Rarity] = true
			end
			for _, rarity in PetsConfig.Rarities do
				t.truthy(rarities[rarity.Id], `{egg.Id} has a {rarity.Id} pet`)
			end
		end
	end)

	t.test("later worlds have stronger pets", function()
		for i = 2, #WorldsConfig.List do
			local previous = PetsConfig.SpeciesByWorld[WorldsConfig.List[i - 1].Id]
			local current = PetsConfig.SpeciesByWorld[WorldsConfig.List[i].Id]
			for r = 1, 8 do
				t.truthy(current[r].Multiplier > previous[r].Multiplier, `{current[r].Name} beats {previous[r].Name}`)
			end
		end
	end)

	t.test("every glove has a complete, valid design", function()
		local valid = {
			Shell = { Mitt = true, Boxing = true, Gauntlet = true, Armored = true, Claw = true },
			Knuckles = { Pad = true, Plates = true, Rivets = true, Ridge = true, Segmented = true, Spikes = true, Crystal = true, Rocks = true, Horns = true, Bolt = true, Blades = true },
			Cuff = { Wrap = true, Strap = true, Bracer = true, Flared = true, Crown = true, Rings = true },
			Emblem = { Badge = true, Diamond = true, Sun = true, Star = true, Snowflake = true, Crest = true, Orb = true, Ring = true, Leaf = true },
			Extras = { Stitching = true, Seams = true, Plating = true, Inlay = true, Channels = true, Fins = true, Tail = true, Shards = true, Orbit = true, Swirl = true, Halo = true },
			Effect = { Glow = true, Sparks = true, Embers = true, Frost = true, Heat = true, Cosmic = true },
		}
		local signatures = {}
		for _, glove in GlovesConfig.List do
			local design = GloveDesigns[glove.Id]
			t.truthy(design, `{glove.Id} has a design`)
			t.truthy(valid.Shell[design.Shell], `{glove.Id} shell {design.Shell}`)
			t.truthy(valid.Knuckles[design.Knuckles], `{glove.Id} knuckles {design.Knuckles}`)
			t.truthy(valid.Cuff[design.Cuff], `{glove.Id} cuff {design.Cuff}`)
			t.truthy(design.Emblem == nil or valid.Emblem[design.Emblem], `{glove.Id} emblem`)
			t.truthy(design.Effect == nil or valid.Effect[design.Effect], `{glove.Id} effect`)
			for _, extra in design.Extras do
				t.truthy(valid.Extras[extra], `{glove.Id} extra {extra}`)
			end
			for _, key in { "Primary", "Secondary", "Trim", "Accent" } do
				t.truthy(typeof(design.Colors[key]) == "Color3", `{glove.Id} colour {key}`)
			end
			for _, key in { "Primary", "Secondary", "Trim" } do
				t.truthy(typeof(design.Mats[key]) == "EnumItem", `{glove.Id} material {key}`)
			end
			t.truthy(design.Effect == nil or design.Colors.Glow ~= nil or design.Effect == "Glow", `{glove.Id} has a glow colour for its effect`)

			-- No two gloves may be the same model in a different colour.
			local signature = `{design.Shell}|{design.Knuckles}|{design.Cuff}|{design.Emblem}|{table.concat(design.Extras, ",")}`
			t.truthy(not signatures[signature], `{glove.Id} has the same shape as {signatures[signature]}`)
			signatures[signature] = glove.Id
		end
	end)

	t.test("every bag has Training Grounds visuals", function()
		for _, bag in BagsConfig.List do
			local visual = TrainingAreaConfig.Bags[bag.Id]
			t.truthy(visual, `{bag.Id} has visuals`)
			t.truthy(visual.Length > 0 and visual.Diameter > 0, `{bag.Id} has a size`)
			-- The bag, ring and label must fit between the floor and the beam.
			local layout = TrainingAreaConfig.Layout
			local top = layout.FloorHeight + layout.BagBottom + 0.9 + visual.Length + 1.6
			t.truthy(top + 5 < layout.BeamBottom, `{bag.Id} and its label fit under the beam`)
			t.truthy(visual.Diameter + 5.6 < layout.BagSpacing - 4, `{bag.Id} leaves a walkway to its neighbours`)
		end
	end)

	t.test("bags and upgrades are well formed", function()
		t.equal(#BagsConfig.List, 6)
		t.equal(BagsConfig.ById[BagsConfig.DefaultBagId].RequiredRebirths, 0)
		for i = 2, #BagsConfig.List do
			t.truthy(BagsConfig.List[i].Multiplier > BagsConfig.List[i - 1].Multiplier, "bags get stronger")
		end
		t.equal(#UpgradesConfig.List, 8)
		for _, upgrade in UpgradesConfig.List do
			t.truthy(upgrade.MaxLevel >= 1, `{upgrade.Id} max level`)
			t.truthy(upgrade.BaseCost >= 1, `{upgrade.Id} costs at least one token`)
		end
	end)
end
