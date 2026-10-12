--!strict
-- Egg hatch odds. Only the server rolls; the UI uses GetOdds to show chances.

local Config = script.Parent.Parent.Config
local EggsConfig = require(Config.EggsConfig)
local PetsConfig = require(Config.PetsConfig)

export type Odds = { SpeciesId: string, Chance: number } -- Chance in percent

local PetOdds = {}

-- luckBonus 0.3 = Rare and rarer pets are 30% more likely (before re-normalising to 100%).
function PetOdds.GetOdds(eggId: string, luckBonus: number): { Odds }
	local egg = EggsConfig.ById[eggId]
	assert(egg, `Unknown egg {eggId}`)

	local weights = {}
	local total = 0
	for _, speciesId in egg.Pets do
		local species = PetsConfig.SpeciesById[speciesId]
		local rarity = PetsConfig.RaritiesById[species.Rarity]
		local weight = rarity.Probability
		if rarity.Order >= PetsConfig.LuckAffectsFromOrder then
			weight *= 1 + luckBonus
		end
		table.insert(weights, { SpeciesId = speciesId, Weight = weight })
		total += weight
	end

	local odds = {}
	for _, entry in weights do
		table.insert(odds, { SpeciesId = entry.SpeciesId, Chance = entry.Weight / total * 100 })
	end
	return odds
end

function PetOdds.Roll(eggId: string, luckBonus: number, rng: Random): string
	local odds = PetOdds.GetOdds(eggId, luckBonus)
	local roll = rng:NextNumber() * 100
	local cumulative = 0
	for _, entry in odds do
		cumulative += entry.Chance
		if roll < cumulative then
			return entry.SpeciesId
		end
	end
	return odds[#odds].SpeciesId
end

return PetOdds
