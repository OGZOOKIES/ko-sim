--!strict
-- THE progression calculations. Every number in the game comes from here, so the server, the HUD,
-- the shop and the Stats panel always agree. Only the server applies them to saved data.
--
-- Each multiplier feeds exactly one quantity, so nothing is applied twice:
--
-- 1. Training Power gained per punch
--      glove Power x bag x rebirth multiplier x pet multiplier x (1 + Training Power upgrade)
--    (Rebirths and pets only boost training. They reach launches through your Power.)
--
-- 2. Punch force (launch strength)
--      max(Power, 1) x glove LaunchForce
--
-- 3. Distance
--      finalZoneStart x (punch force / world.FullStrength) ^ DistanceExponent
--      x timing factor x (1 + Launch Control upgrade), capped at the end of the runway
--    timing factor = MinChargeFactor + (1 - MinChargeFactor) x charge, x TimingBonus on a Perfect.
--    Quick Punch uses AutoCharge and is never Perfect.
--
-- 4. Wins per launch
--      landing zone's Wins x (1 + Win Bonus upgrade)
--
-- 5. Pets: each equipped pet adds (its multiplier - 1); tiers multiply the base by 2/3/4.
--    Egg Luck boosts Rare-and-better weights; Pet Equip Slots adds slots.

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

-- Lowest charge that counts as Perfect for a meter with this cycle. The meter spends
-- LaunchConfig.PerfectWindow seconds above it at each peak, however fast it charges.
function Formulas.SweetSpotMin(cycle: number): number
	return math.clamp(1 - LaunchConfig.PerfectWindow / (2 * cycle), 0.5, 0.97)
end

function Formulas.IsPerfect(charge: number, cycle: number): boolean
	return charge >= Formulas.SweetSpotMin(cycle)
end

-- How much of the full distance a release gives (x TimingBonus when Perfect).
function Formulas.TimingFactor(charge: number, perfect: boolean): number
	charge = math.clamp(charge, 0, 1)
	local factor = LaunchConfig.MinChargeFactor + (1 - LaunchConfig.MinChargeFactor) * charge
	return if perfect then factor * LaunchConfig.TimingBonus else factor
end

-- Launching

function Formulas.GloveLaunchForce(data: PlayerData): number
	local glove = GlovesConfig.ById[data.EquippedGlove]
	return if glove then glove.LaunchForce else 1
end

-- Punch force: what the launch distance is calculated from.
function Formulas.LaunchStrength(data: PlayerData): number
	return math.max(data.Power, 1) * Formulas.GloveLaunchForce(data)
end

function Formulas.RunwayLength(worldId: string): number
	local world = WorldsConfig.ById[worldId]
	return world.Zones[#world.Zones].Min + WorldsConfig.RunwayExtension
end

function Formulas.MaxLaunchDistance(worldId: string): number
	return Formulas.RunwayLength(worldId) - 40
end

-- timingFactor comes from Formulas.TimingFactor (1 = a full, non-Perfect charge).
function Formulas.LaunchDistance(data: PlayerData, worldId: string, timingFactor: number): number
	local world = WorldsConfig.ById[worldId]
	local finalZoneStart = world.Zones[#world.Zones].Min
	local ratio = Formulas.LaunchStrength(data) / world.FullStrength
	local distance = finalZoneStart
		* ratio ^ WorldsConfig.DistanceExponent
		* timingFactor
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

-- Breakdowns for the Stats panel: every factor exactly as the server applies it.
-- Kind: "Number" for a base value, "Multiplier" for a factor, "Total" for the result.
export type Line = { Label: string, Value: number, Kind: string }

function Formulas.Breakdown(data: PlayerData, worldId: string): { [string]: { Line } }
	local trainingUpgrade = 1 + Formulas.UpgradeEffect(data, "TrainingPower")
	local launchControl = 1 + Formulas.UpgradeEffect(data, "LaunchControl")
	local fullDistance = Formulas.LaunchDistance(data, worldId, 1)
	return {
		Training = {
			{ Label = "Glove Power", Value = Formulas.GlovePower(data), Kind = "Number" },
			{ Label = "Punching bag", Value = Formulas.BagMultiplier(data), Kind = "Multiplier" },
			{ Label = "Rebirths", Value = Formulas.RebirthMultiplier(data.RebirthCount), Kind = "Multiplier" },
			{ Label = "Pets", Value = Formulas.EquippedPetMultiplier(data), Kind = "Multiplier" },
			{ Label = "Training Power upgrade", Value = trainingUpgrade, Kind = "Multiplier" },
			{ Label = "Power per train", Value = Formulas.TrainingGain(data), Kind = "Total" },
		},
		Launch = {
			{ Label = "Your Power", Value = math.max(data.Power, 1), Kind = "Number" },
			{ Label = "Glove punch force", Value = Formulas.GloveLaunchForce(data), Kind = "Multiplier" },
			{ Label = "Punch force", Value = Formulas.LaunchStrength(data), Kind = "Total" },
			{ Label = "Launch Control upgrade (distance)", Value = launchControl, Kind = "Multiplier" },
			{ Label = "Perfect timing (distance)", Value = LaunchConfig.TimingBonus, Kind = "Multiplier" },
			{ Label = "Full-charge distance here", Value = math.floor(fullDistance), Kind = "Total" },
		},
		Rewards = {
			{ Label = "Win Bonus upgrade", Value = 1 + Formulas.UpgradeEffect(data, "WinBonus"), Kind = "Multiplier" },
			{ Label = "Egg Luck (Rare and better)", Value = 1 + Formulas.UpgradeEffect(data, "EggLuck"), Kind = "Multiplier" },
			{ Label = "Pet slots", Value = Formulas.PetEquipSlots(data), Kind = "Number" },
		},
	}
end

return Formulas
