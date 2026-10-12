-- Zone lookup, launch math, odds and number formatting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EggsConfig = require(Shared.Config.EggsConfig)
local LaunchConfig = require(Shared.Config.LaunchConfig)
local WorldsConfig = require(Shared.Config.WorldsConfig)
local Formulas = require(Shared.Logic.Formulas)
local PetOdds = require(Shared.Logic.PetOdds)
local Zones = require(Shared.Logic.Zones)
local Format = require(Shared.Utilities.Format)
local DataTemplate = require(ServerScriptService.Logic.DataTemplate)

return function(t)
	t.test("zone lookup at the boundaries", function()
		t.equal(Zones.Find("Greenfield", 0).Name, "Starter Field")
		t.equal(Zones.Find("Greenfield", 50).Name, "Starter Field")
		t.equal(Zones.Find("Greenfield", 50.99).Name, "Starter Field")
		t.equal(Zones.Find("Greenfield", 51).Name, "Wooden Fence")
		t.equal(Zones.Find("Greenfield", 850).Name, "Giant Oak")
		t.equal(Zones.Find("Greenfield", 851).Name, "Meadow Summit")
		t.equal(Zones.Find("Greenfield", 100000).Name, "Meadow Summit")
		t.equal(Zones.Find("Greenfield", -5).Name, "Starter Field", "negative distances count as 0")
		t.equal(Zones.Find("Greenfield", 0 / 0).Name, "Starter Field", "NaN counts as 0")
	end)

	t.test("every whole-stud distance maps to exactly one zone", function()
		for _, world in WorldsConfig.List do
			for d = 0, Formulas.RunwayLength(world.Id) do
				local matches = 0
				for _, zone in world.Zones do
					if d >= zone.Min and d <= zone.Max then
						matches += 1
					end
				end
				t.equal(matches, 1, `{world.Id} at {d} studs`)
				local found = Zones.Find(world.Id, d)
				t.truthy(d >= found.Min and d <= found.Max, `{world.Id} lookup at {d}`)
			end
		end
	end)

	t.test("rebirth cost rises and multiplier stacks", function()
		t.equal(Formulas.RebirthCost(0), 2500)
		for n = 1, 60 do
			t.truthy(Formulas.RebirthCost(n) > Formulas.RebirthCost(n - 1), `cost {n}`)
		end
		t.near(Formulas.RebirthMultiplier(0), 1)
		t.near(Formulas.RebirthMultiplier(1), 1.2)
		t.near(Formulas.RebirthMultiplier(10), 3)
	end)

	t.test("pet tier multipliers are 2x, 3x and 4x the base", function()
		t.near(Formulas.PetMultiplier("Greenfield_Legendary", 1), 5)
		t.near(Formulas.PetMultiplier("Greenfield_Legendary", 2), 10)
		t.near(Formulas.PetMultiplier("Greenfield_Legendary", 3), 15)
		t.near(Formulas.PetMultiplier("Greenfield_Legendary", 4), 20)
		t.near(Formulas.PetMultiplier("Unknown", 1), 1, nil, "unknown pets are harmless")
	end)

	t.test("training gain combines every multiplier", function()
		local data = DataTemplate.New()
		t.near(Formulas.TrainingGain(data), 1, nil, "starter")
		data.OwnedGloves.Greenfield_5 = true
		data.EquippedGlove = "Greenfield_5" -- 12 Power
		data.RebirthCount = 5 -- x2
		data.SelectedBag = "Heavy" -- x4
		data.Upgrades.TrainingPower = 3 -- x1.3
		data.Pets["1"] = { Id = "1", Species = "Greenfield_Rare", Tier = 1 } -- 2x -> +1
		data.Pets["2"] = { Id = "2", Species = "Greenfield_Common", Tier = 1 } -- 1.1x -> +0.1
		data.EquippedPets = { "1", "2" }
		t.near(Formulas.EquippedPetMultiplier(data), 2.1)
		t.near(Formulas.TrainingGain(data), 12 * 4 * 2 * 2.1 * 1.3, 1e-6)
	end)

	t.test("charge meter goes up and down", function()
		t.near(Formulas.ChargeAt(0, 1), 0)
		t.near(Formulas.ChargeAt(0.5, 1), 0.5)
		t.near(Formulas.ChargeAt(1, 1), 1)
		t.near(Formulas.ChargeAt(1.25, 1), 0.75)
		t.near(Formulas.ChargeAt(2, 1), 0)
		local cycle = LaunchConfig.ChargeCycle
		local sweet = Formulas.SweetSpotMin(cycle)
		t.truthy(Formulas.IsPerfect(sweet, cycle))
		t.truthy(not Formulas.IsPerfect(sweet - 0.01, cycle))
		t.truthy(Formulas.TimingFactor(1, true) > Formulas.TimingFactor(0.8, false), "perfect beats an early release")
		t.near(Formulas.TimingFactor(0, false), LaunchConfig.MinChargeFactor)
		t.near(Formulas.TimingFactor(1, true), LaunchConfig.TimingBonus)
		t.truthy(Formulas.TimingFactor(LaunchConfig.AutoCharge, false) < Formulas.TimingFactor(1, true), "quick punch is weaker than a perfect")
	end)

	t.test("faster charging never shrinks the perfect window", function()
		for _, cycle in { 1.3, 1.1, 0.975 } do
			-- Time spent above the sweet spot per peak = 2 * (1 - sweet) * cycle.
			local window = 2 * (1 - Formulas.SweetSpotMin(cycle)) * cycle
			t.near(window, LaunchConfig.PerfectWindow, 1e-6, `window at cycle {cycle}`)
		end
		local data = DataTemplate.New()
		local slow = Formulas.ChargeCycle(data)
		data.Upgrades.ChargeSpeed = 5
		t.truthy(Formulas.ChargeCycle(data) < slow, "Charge Speed makes the meter faster")
	end)

	t.test("stats breakdown matches the real formulas", function()
		local data = DataTemplate.New()
		data.Power = 12345
		data.RebirthCount = 3
		data.Upgrades.TrainingPower = 2
		local breakdown = Formulas.Breakdown(data, "Greenfield")
		local training = breakdown.Training
		t.near(training[#training].Value, Formulas.TrainingGain(data), 1e-9, "training total")
		local product = 1
		for i = 1, #training - 1 do
			product *= training[i].Value
		end
		t.near(product, Formulas.TrainingGain(data), 1e-6, "training factors multiply to the total")
		t.near(breakdown.Launch[3].Value, Formulas.LaunchStrength(data), 1e-9, "punch force")
		t.near(breakdown.Launch[1].Value * breakdown.Launch[2].Value, Formulas.LaunchStrength(data), 1e-6, "power x glove = punch force")
	end)

	t.test("launch distance grows with power and stays on the runway", function()
		local data = DataTemplate.New()
		local last = 0
		for _, power in { 0, 10, 1000, 1e5, 1e6, 1e9 } do
			data.Power = power
			local distance = Formulas.LaunchDistance(data, "Greenfield", 1)
			t.truthy(distance >= last, `distance doesn't shrink at {power} Power`)
			t.truthy(distance <= Formulas.MaxLaunchDistance("Greenfield"), "capped at the runway")
			t.truthy(distance >= LaunchConfig.MinDistance, "at least the minimum")
			last = distance
		end
		data.Power = 1e6
		local final = WorldsConfig.ById.Greenfield.Zones[10].Min
		t.truthy(Formulas.LaunchDistance(data, "Greenfield", 0.85) >= final * 0.85, "full strength reaches near the final zone")
	end)

	t.test("egg odds add up to 100% with and without luck", function()
		for _, egg in EggsConfig.List do
			for _, luck in { 0, 0.5, 1 } do
				local total = 0
				for _, entry in PetOdds.GetOdds(egg.Id, luck) do
					total += entry.Chance
				end
				t.near(total, 100, 1e-6, `{egg.Id} luck {luck}`)
			end
		end
		local base = PetOdds.GetOdds("GreenfieldEgg", 0)
		local lucky = PetOdds.GetOdds("GreenfieldEgg", 1)
		t.near(base[1].Chance, 45, 1e-9, "common is 45% without luck")
		t.truthy(lucky[8].Chance > base[8].Chance, "luck improves the secret pet")
		t.truthy(lucky[1].Chance < base[1].Chance, "luck lowers the common pet")
	end)

	t.test("egg rolls follow the odds", function()
		local rng = Random.new(12345)
		local counts = {}
		local rolls = 20000
		for _ = 1, rolls do
			local species = PetOdds.Roll("GreenfieldEgg", 0, rng)
			counts[species] = (counts[species] or 0) + 1
		end
		t.near((counts.Greenfield_Common or 0) / rolls, 0.45, 0.02, "common share")
		t.near((counts.Greenfield_Uncommon or 0) / rolls, 0.25, 0.02, "uncommon share")
	end)

	t.test("number formatting", function()
		t.equal(Format.Number(0), "0")
		t.equal(Format.Number(999), "999")
		t.equal(Format.Number(1000), "1K")
		t.equal(Format.Number(1234), "1.23K")
		t.equal(Format.Number(15500), "15.5K")
		t.equal(Format.Number(2.5e6), "2.5M")
		t.equal(Format.Number(1e9), "1B")
		t.equal(Format.Number(115e6), "115M")
		t.equal(Format.Multiplier(1.1), "x1.1")
		t.equal(Format.Multiplier(2), "x2")
	end)
end
