-- Economy transactions: gloves, eggs, pet fusion, rebirths, upgrades, worlds and launch rewards.
-- Each test starts from fresh data, so nothing touches real players or DataStores.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetsConfig = require(Shared.Config.PetsConfig)
local Formulas = require(Shared.Logic.Formulas)
local DataTemplate = require(ServerScriptService.Logic.DataTemplate)
local Economy = require(ServerScriptService.Logic.Economy)

local function givePets(data, speciesId: string, tier: number, count: number)
	for _ = 1, count do
		Economy.AddPet(data, speciesId, tier)
	end
end

local function countPets(data, speciesId: string, tier: number): number
	local n = 0
	for _, pet in data.Pets do
		if pet.Species == speciesId and pet.Tier == tier then
			n += 1
		end
	end
	return n
end

return function(t)
	t.test("buying a glove spends Wins and keeps old gloves", function()
		local data = DataTemplate.New()
		data.Wins = 100
		local ok = Economy.BuyGlove(data, "Greenfield_2")
		t.truthy(ok, "purchase succeeds")
		t.equal(data.Wins, 90)
		t.truthy(data.OwnedGloves.Greenfield_1, "starter glove kept")
		t.truthy(data.OwnedGloves.Greenfield_2, "new glove owned")
		t.equal(data.EquippedGlove, "Greenfield_2", "new glove equipped")
	end)

	t.test("glove purchases are validated", function()
		local data = DataTemplate.New()
		data.Wins = 5
		t.truthy(not Economy.BuyGlove(data, "Greenfield_2"), "not enough Wins")
		t.equal(data.Wins, 5, "nothing spent on failure")
		data.Wins = 1e9
		t.truthy(not Economy.BuyGlove(data, "Greenfield_3"), "must buy in order")
		t.truthy(not Economy.BuyGlove(data, "Desert_1"), "world must be unlocked")
		t.truthy(not Economy.BuyGlove(data, "Greenfield_1"), "can't rebuy")
		t.truthy(not Economy.BuyGlove(data, "Nope"), "unknown id")
		t.truthy(not Economy.BuyGlove(data, 42), "wrong type")
		t.equal(data.Wins, 1e9, "nothing spent on any failure")
		t.truthy(not Economy.EquipGlove(data, "Greenfield_5"), "can't equip unowned glove")
	end)

	t.test("hatching spends Wins, adds one pet and respects capacity", function()
		local data = DataTemplate.New()
		data.Wins = 1000
		local ok, _, pet = Economy.HatchEgg(data, "GreenfieldEgg", Random.new(1))
		t.truthy(ok and pet, "hatch succeeds")
		t.equal(data.Wins, 975)
		t.equal(Formulas.PetCount(data), 1)
		t.equal(#data.EquippedPets, 1, "auto-equipped into a free slot")

		givePets(data, "Greenfield_Common", 1, PetsConfig.InventoryCapacity - 1)
		local wins = data.Wins
		local full = Economy.HatchEgg(data, "GreenfieldEgg", Random.new(2))
		t.truthy(not full, "full inventory blocks hatching")
		t.equal(data.Wins, wins, "no Wins spent when full")
		t.truthy(not Economy.HatchEgg(data, "DesertEgg", Random.new(3)), "locked world's egg")
	end)

	t.test("five identical pets fuse into exactly one next-tier pet", function()
		local data = DataTemplate.New()
		givePets(data, "Greenfield_Legendary", 1, 7)
		givePets(data, "Greenfield_Common", 1, 2)
		local ok, _, pet = Economy.FusePets(data, "Greenfield_Legendary", 1)
		t.truthy(ok and pet, "fusion succeeds")
		t.equal(pet.Tier, 2)
		t.equal(countPets(data, "Greenfield_Legendary", 1), 2, "exactly five consumed")
		t.equal(countPets(data, "Greenfield_Legendary", 2), 1, "exactly one created")
		t.equal(countPets(data, "Greenfield_Common", 1), 2, "other pets untouched")
		t.near(Formulas.PetMultiplier(pet.Species, pet.Tier), 10, nil, "gold is 2x base")
	end)

	t.test("fusion is validated and never consumes pets on failure", function()
		local data = DataTemplate.New()
		givePets(data, "Greenfield_Rare", 1, 4)
		givePets(data, "Greenfield_Rare", 2, 1)
		t.truthy(not Economy.FusePets(data, "Greenfield_Rare", 1), "four is not enough")
		t.equal(countPets(data, "Greenfield_Rare", 1), 4)
		t.truthy(not Economy.FusePets(data, "Greenfield_Rare", 2), "tiers don't mix")
		givePets(data, "Greenfield_Rare", 4, 5)
		t.truthy(not Economy.FusePets(data, "Greenfield_Rare", 4), "rainbow is the top tier")
		t.equal(countPets(data, "Greenfield_Rare", 4), 5)
		t.truthy(not Economy.FusePets(data, "Greenfield_Rare", 1.5), "fractional tier")
		t.truthy(not Economy.FusePets(data, "Nope", 1), "unknown species")
	end)

	t.test("fusion prefers unequipped pets and keeps the result equipped", function()
		local data = DataTemplate.New()
		givePets(data, "Greenfield_Epic", 1, 6)
		data.EquippedPets = { "1" }
		Economy.FusePets(data, "Greenfield_Epic", 1)
		t.truthy(data.Pets["1"], "the equipped pet was kept")
		t.equal(countPets(data, "Greenfield_Epic", 1), 1)

		local data2 = DataTemplate.New()
		givePets(data2, "Greenfield_Epic", 1, 5)
		data2.EquippedPets = { "1", "2", "3" }
		local _, _, pet = Economy.FusePets(data2, "Greenfield_Epic", 1)
		t.equal(#data2.EquippedPets, 1, "consumed pets were unequipped")
		t.equal(data2.EquippedPets[1], pet.Id, "the new pet took the slot")
	end)

	t.test("full upgrade chain: 125 normal pets make one rainbow", function()
		local data = DataTemplate.New()
		givePets(data, "Greenfield_Common", 1, 125)
		for _ = 1, 25 do
			t.truthy(Economy.FusePets(data, "Greenfield_Common", 1), "normal -> gold")
		end
		for _ = 1, 5 do
			t.truthy(Economy.FusePets(data, "Greenfield_Common", 2), "gold -> diamond")
		end
		t.truthy(Economy.FusePets(data, "Greenfield_Common", 3), "diamond -> rainbow")
		t.equal(Formulas.PetCount(data), 1)
		t.equal(countPets(data, "Greenfield_Common", 4), 1)
	end)

	t.test("rebirth resets Power only and grants one token", function()
		local data = DataTemplate.New()
		data.Power = 1000
		t.truthy(not Economy.Rebirth(data), "not enough Power")
		t.equal(data.Power, 1000)

		data.Power = Formulas.RebirthCost(0)
		data.Wins = 50
		data.OwnedGloves.Greenfield_2 = true
		Economy.AddPet(data, "Greenfield_Rare", 1)
		data.Upgrades.WinBonus = 2
		t.truthy(Economy.Rebirth(data), "rebirth succeeds")
		t.equal(data.Power, 0)
		t.equal(data.RebirthCount, 1)
		t.equal(data.RebirthTokens, 1)
		t.equal(data.Wins, 50, "Wins kept")
		t.truthy(data.OwnedGloves.Greenfield_2, "gloves kept")
		t.equal(Formulas.PetCount(data), 1, "pets kept")
		t.equal(data.Upgrades.WinBonus, 2, "upgrades kept")

		data.Power = Formulas.RebirthCost(0)
		t.truthy(not Economy.Rebirth(data), "the second rebirth costs more")
	end)

	t.test("spending tokens never lowers rebirth count or multiplier", function()
		local data = DataTemplate.New()
		data.RebirthCount = 3
		data.RebirthTokens = 10
		local multiplier = Formulas.RebirthMultiplier(data.RebirthCount)
		t.truthy(Economy.BuyUpgrade(data, "TrainingPower"))
		t.equal(data.RebirthTokens, 9)
		t.equal(data.RebirthCount, 3)
		t.near(Formulas.RebirthMultiplier(data.RebirthCount), multiplier)
	end)

	t.test("upgrades check tokens, rebirths and max level", function()
		local data = DataTemplate.New()
		t.truthy(not Economy.BuyUpgrade(data, "TrainingPower"), "no tokens")
		data.RebirthTokens = 100
		t.truthy(not Economy.BuyUpgrade(data, "AutoTrain"), "needs 3 rebirths")
		data.RebirthCount = 3
		t.truthy(Economy.BuyUpgrade(data, "AutoTrain"))
		t.truthy(data.Settings.AutoTrain, "auto train switches on when bought")
		t.truthy(not Economy.BuyUpgrade(data, "AutoTrain"), "max level 1")
		local tokens = data.RebirthTokens
		t.truthy(Economy.BuyUpgrade(data, "PetEquipSlots"))
		t.equal(tokens - data.RebirthTokens, 3, "first level costs BaseCost")
		t.truthy(Economy.BuyUpgrade(data, "PetEquipSlots"))
		t.equal(tokens - data.RebirthTokens, 3 + 6, "second level costs BaseCost + CostStep")
		t.equal(Formulas.PetEquipSlots(data), PetsConfig.BaseEquipSlots + 2)
	end)

	t.test("bags unlock by rebirth count", function()
		local data = DataTemplate.New()
		t.truthy(not Economy.SelectBag(data, "Reinforced"))
		data.RebirthCount = 2
		t.truthy(Economy.SelectBag(data, "Reinforced"))
		t.equal(data.SelectedBag, "Reinforced")
	end)

	t.test("worlds unlock in order with Wins and rebirths", function()
		local data = DataTemplate.New()
		data.Wins = 1e12
		t.truthy(not Economy.UnlockWorld(data, "Desert"), "needs a rebirth")
		data.RebirthCount = 100
		t.truthy(not Economy.UnlockWorld(data, "Frostbite"), "must unlock Desert first")
		t.truthy(Economy.UnlockWorld(data, "Desert"))
		t.equal(data.Wins, 1e12 - 2000)
		t.truthy(not Economy.SetCurrentWorld(data, "Cosmic"), "can't travel to a locked world")
		t.truthy(Economy.SetCurrentWorld(data, "Desert"))
		t.equal(data.CurrentWorld, "Desert")
	end)

	t.test("launch rewards use the landing zone and track the personal best", function()
		local data = DataTemplate.New()
		local reward = Economy.AwardLaunch(data, "Greenfield", 120.7)
		t.equal(reward.Zone.Name, "Hay Bale Hill")
		t.equal(reward.Wins, 4)
		t.equal(reward.Distance, 120)
		t.truthy(reward.IsNewBest)
		t.equal(data.Wins, 4)

		local second = Economy.AwardLaunch(data, "Greenfield", 30)
		t.equal(second.Wins, 1)
		t.truthy(not second.IsNewBest)
		t.equal(second.Best, 120)
		t.equal(data.Wins, 5)
		t.equal(data.Stats.Launches, 2)

		data.Upgrades.WinBonus = 5 -- +50%
		local boosted = Economy.AwardLaunch(data, "Greenfield", 900)
		t.equal(boosted.Wins, math.floor(175 * 1.5))
	end)

	t.test("old or broken saves are repaired", function()
		local raw = {
			Version = 1,
			Power = 0 / 0,
			Wins = 50,
			EquippedGlove = "DoesNotExist",
			Pets = { ["7"] = { Id = "7", Species = "Greenfield_Rare", Tier = 1 } },
			EquippedPets = { "7", "7", "99" },
			NextPetId = 1,
			CurrentWorld = "Cosmic",
		}
		local data = DataTemplate.Prepare(raw)
		t.equal(data.Power, 0, "NaN Power reset")
		t.equal(data.Wins, 50, "Wins kept")
		t.equal(data.EquippedGlove, "Greenfield_1", "unknown glove replaced")
		t.equal(#data.EquippedPets, 1, "duplicates and missing pets unequipped")
		t.truthy(data.NextPetId > 7, "pet ids are never reused")
		t.equal(data.CurrentWorld, "Greenfield", "locked world replaced")
		t.truthy(data.Settings and data.Stats, "missing records filled in")
	end)
end
