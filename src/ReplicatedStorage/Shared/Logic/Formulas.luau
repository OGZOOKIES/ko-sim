--!strict
-- Every gameplay number is calculated here, so the server and the UI always agree.
-- The server is the only one that applies these to saved data; clients use them for previews.
--
-- Training gain per punch:
--   glove Power * bag multiplier * rebirth multiplier * pet multiplier * (1 + Training Power upgrade)
--
-- Launch:
--   strength = max(Power, 1) * glove LaunchBonus
--   distance = finalZoneStart * (strength / world.FullStrength) ^ DistanceExponent
--              * charge factor * (1 + Launch Control upgrade), capped at the end of the runway
--   charge factor = MinChargeFactor + (1 - MinChargeFactor) * charge, x TimingBonus on a Perfect

local Config = script.Parent.Parent.Config
local BagsConfig = require(Config.BagsConfig)
local GameConfig = require(Config.GameConfig)
local GlovesConfig = require(Config.GlovesConfig)
local LaunchConfig = require(Config.LaunchConfig)
local PetsConfig = require(Config.PetsConfig)
local RebirthConfig = require(Config.RebirthConfig)
local UpgradesConfig = require(Config.UpgradesConfig)
local WorldsConfig = require(Config.WorldsConfig)
local Types = require(script.Parent.Parent.Types)

type PlayerData = Types.PlayerData

local Formulas = {}

-- Upgrades

function Formulas.UpgradeLevel(data: PlayerData, upgradeId: string): number
	return data.Upgrades[upgradeId] or 0
end

function Formulas.UpgradeEffect(data: PlayerData, upgradeId: string): number
	local upgrade = UpgradesConfig.ById[upgradeId]
	if not upgrade then
		return 0
	end
	return math.min(Formulas.UpgradeLevel(data, upgradeId), upgrade.MaxLevel) * upgrade.EffectPerLevel
end

-- Rebirths

function Formulas.RebirthMultiplier(rebirthCount: number): number
	return 1 + rebirthCount * RebirthConfig.MultiplierPerRebirth
end

function Formulas.RebirthCost(rebirthCount: number): number
	return math.floor(RebirthConfig.BaseCost * RebirthConfig.CostGrowth ^ rebirthCount)
end

-- Pets

function Formulas.PetMultiplier(speciesId: string, tier: number): number
	local species = PetsConfig.SpeciesById[speciesId]
	local tierInfo = PetsConfig.Tiers[tier]
	if not species or not tierInfo then
		return 1
	end
	return species.Multiplier * tierInfo.Multiplier
end

function Formulas.EquippedPetMultiplier(data: PlayerData): number
	local bonus = 0
	for _, petId in data.EquippedPets do
		local pet = data.Pets[petId]
		if pet then
			bonus += Formulas.PetMultiplier(pet.Species, pet.Tier) - 1
		end
	end
	return 1 + bonus
end

function Formulas.PetEquipSlots(data: PlayerData): number
	return PetsConfig.BaseEquipSlots + Formulas.UpgradeEffect(data, "PetEquipSlots")
end

function Formulas.PetCount(data: PlayerData): number
	local count = 0
	for _ in data.Pets do
		count += 1
	end
	return count
end

-- Training

function Formulas.GlovePower(data: PlayerData): number
	local glove = GlovesConfig.ById[data.EquippedGlove]
	return if glove then glove.Power else 1
end

function Formulas.BagMultiplier(data: PlayerData): number
	local bag = BagsConfig.ById[data.SelectedBag] or BagsConfig.List[1]
	return bag.Multiplier
end

function Formulas.TrainingGain(data: PlayerData): number
	return Formulas.GlovePower(data)
		* Formulas.BagMultiplier(data)
		* Formulas.RebirthMultiplier(data.RebirthCount)
		* Formulas.EquippedPetMultiplier(data)
		* (1 + Formulas.UpgradeEffect(data, "TrainingPower"))
end

function Formulas.TrainingInterval(data: PlayerData): number
	return GameConfig.TrainingInterval * (1 - Formulas.UpgradeEffect(data, "TrainingSpeed"))
end

-- Charging

function Formulas.ChargeCycle(data: PlayerData): number
	return LaunchConfig.ChargeCycle * (1 - Formulas.UpgradeEffect(data, "ChargeSpeed"))
end

-- Charge after `elapsed` seconds: rises 0 -> 1 over one cycle, falls back over the next, repeats.
function Formulas.ChargeAt(elapsed: number, cycle: number): number
	local t = (math.max(elapsed, 0) / cycle) % 2
	return if t <= 1 then t else 2 - t
end

function Formulas.IsPerfect(charge: number): boolean
	return charge >= LaunchConfig.SweetSpotMin
end

function Formulas.ChargeFactor(charge: number): number
	charge = math.clamp(charge, 0, 1)
	local factor = LaunchConfig.MinChargeFactor + (1 - LaunchConfig.MinChargeFactor) * charge
	if Formulas.IsPerfect(charge) then
		factor *= LaunchConfig.TimingBonus
	end
	return factor
end

-- Launching

function Formulas.LaunchStrength(data: PlayerData): number
	local glove = GlovesConfig.ById[data.EquippedGlove]
	local bonus = if glove then glove.LaunchBonus else 1
	return math.max(data.Power, 1) * bonus
end

function Formulas.RunwayLength(worldId: string): number
	local world = WorldsConfig.ById[worldId]
	return world.Zones[#world.Zones].Min + WorldsConfig.RunwayExtension
end

function Formulas.MaxLaunchDistance(worldId: string): number
	return Formulas.RunwayLength(worldId) - 40
end

function Formulas.LaunchDistance(data: PlayerData, worldId: string, charge: number): number
	local world = WorldsConfig.ById[worldId]
	local finalZoneStart = world.Zones[#world.Zones].Min
	local ratio = Formulas.LaunchStrength(data) / world.FullStrength
	local distance = finalZoneStart
		* ratio ^ WorldsConfig.DistanceExponent
		* Formulas.ChargeFactor(charge)
		* (1 + Formulas.UpgradeEffect(data, "LaunchControl"))
	return math.clamp(distance, LaunchConfig.MinDistance, Formulas.MaxLaunchDistance(worldId))
end

-- 1 = full random spread, 0 = perfectly straight.
function Formulas.LaunchSpread(data: PlayerData): number
	return math.max(0, 1 - Formulas.UpgradeLevel(data, "LaunchControl") * LaunchConfig.SpreadReductionPerLevel)
end

-- Rewards

function Formulas.WinsForZone(data: PlayerData, zone: WorldsConfig.Zone): number
	return math.floor(zone.Wins * (1 + Formulas.UpgradeEffect(data, "WinBonus")))
end

return Formulas
