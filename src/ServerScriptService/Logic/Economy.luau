--!strict
-- Every change to a player's progress goes through these functions.
--
-- They work on a plain data table and never yield, so each call finishes completely or not at all:
-- a failed check returns before anything is changed. Services call them after validating who is
-- asking; tests call them directly (see ServerScriptService.Tests).
--
-- Each function returns ok, message, and sometimes a result.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BagsConfig = require(Shared.Config.BagsConfig)
local EggsConfig = require(Shared.Config.EggsConfig)
local GameConfig = require(Shared.Config.GameConfig)
local GlovesConfig = require(Shared.Config.GlovesConfig)
local PetsConfig = require(Shared.Config.PetsConfig)
local RebirthConfig = require(Shared.Config.RebirthConfig)
local UpgradesConfig = require(Shared.Config.UpgradesConfig)
local WorldsConfig = require(Shared.Config.WorldsConfig)
local Formulas = require(Shared.Logic.Formulas)
local PetOdds = require(Shared.Logic.PetOdds)
local Zones = require(Shared.Logic.Zones)
local Format = require(Shared.Utilities.Format)
local Types = require(Shared.Types)

type PlayerData = Types.PlayerData
type PetData = Types.PetData

local Economy = {}

local function addCapped(current: number, amount: number): number
	return math.min(current + amount, GameConfig.MaxNumber)
end

-- Training

function Economy.Train(data: PlayerData): number
	local gain = Formulas.TrainingGain(data)
	data.Power = addCapped(data.Power, gain)
	return gain
end

function Economy.SelectBag(data: PlayerData, bagId: any): (boolean, string?)
	local bag = if type(bagId) == "string" then BagsConfig.ById[bagId] else nil
	if not bag then
		return false, "That bag doesn't exist."
	end
	if data.RebirthCount < bag.RequiredRebirths then
		return false, `{bag.Name} unlocks at {bag.RequiredRebirths} rebirths.`
	end
	data.SelectedBag = bag.Id
	return true, `Training with the {bag.Name} ({Format.Multiplier(bag.Multiplier)} Power).`
end

-- Gloves

function Economy.BuyGlove(data: PlayerData, gloveId: any): (boolean, string?)
	local glove = if type(gloveId) == "string" then GlovesConfig.ById[gloveId] else nil
	if not glove then
		return false, "That glove doesn't exist."
	end
	if data.OwnedGloves[glove.Id] then
		return false, "You already own that glove."
	end
	if not data.UnlockedWorlds[glove.World] then
		return false, `Unlock {WorldsConfig.ById[glove.World].Name} first.`
	end
	if glove.Index > 1 then
		local previous = GlovesConfig.ByWorld[glove.World][glove.Index - 1]
		if not data.OwnedGloves[previous.Id] then
			return false, `Buy {previous.Name} first.`
		end
	end
	if data.Wins < glove.Cost then
		return false, `You need {Format.Number(glove.Cost - data.Wins)} more Wins.`
	end

	data.Wins -= glove.Cost
	data.OwnedGloves[glove.Id] = true
	-- New gloves are always stronger than the last one in order, so equip them straight away.
	local equipped = GlovesConfig.ById[data.EquippedGlove]
	if not equipped or glove.Power > equipped.Power then
		data.EquippedGlove = glove.Id
	end
	return true, `Bought {glove.Name}!`
end

function Economy.EquipGlove(data: PlayerData, gloveId: any): (boolean, string?)
	local glove = if type(gloveId) == "string" then GlovesConfig.ById[gloveId] else nil
	if not glove then
		return false, "That glove doesn't exist."
	end
	if not data.OwnedGloves[glove.Id] then
		return false, "You don't own that glove yet."
	end
	data.EquippedGlove = glove.Id
	return true, `Equipped {glove.Name}.`
end

-- Pets

local function isEquipped(data: PlayerData, petId: string): number?
	return table.find(data.EquippedPets, petId)
end

function Economy.AddPet(data: PlayerData, speciesId: string, tier: number): PetData
	local id = tostring(data.NextPetId)
	data.NextPetId += 1
	local pet = { Id = id, Species = speciesId, Tier = tier }
	data.Pets[id] = pet
	return pet
end

function Economy.HatchEgg(data: PlayerData, eggId: any, rng: Random): (boolean, string?, PetData?)
	local egg = if type(eggId) == "string" then EggsConfig.ById[eggId] else nil
	if not egg then
		return false, "That egg doesn't exist."
	end
	if not data.UnlockedWorlds[egg.World] then
		return false, `Unlock {WorldsConfig.ById[egg.World].Name} first.`
	end
	local count = Formulas.PetCount(data)
	if count >= PetsConfig.InventoryCapacity then
		return false,
			`Your pet inventory is full ({count}/{PetsConfig.InventoryCapacity}). Delete or fuse pets to make room.`
	end
	if data.Wins < egg.Cost then
		return false, `You need {Format.Number(egg.Cost - data.Wins)} more Wins.`
	end

	data.Wins -= egg.Cost
	local speciesId = PetOdds.Roll(egg.Id, Formulas.UpgradeEffect(data, "EggLuck"), rng)
	local pet = Economy.AddPet(data, speciesId, 1)
	data.Stats.PetsHatched += 1
	if #data.EquippedPets < Formulas.PetEquipSlots(data) then
		table.insert(data.EquippedPets, pet.Id)
	end
	return true, nil, pet
end

function Economy.EquipPet(data: PlayerData, petId: any): (boolean, string?)
	if type(petId) ~= "string" or not data.Pets[petId] then
		return false, "That pet doesn't exist."
	end
	if isEquipped(data, petId) then
		return false, "That pet is already equipped."
	end
	if #data.EquippedPets >= Formulas.PetEquipSlots(data) then
		return false, "All your pet slots are full. Unequip a pet first."
	end
	table.insert(data.EquippedPets, petId)
	return true, nil
end

function Economy.UnequipPet(data: PlayerData, petId: any): (boolean, string?)
	local index = if type(petId) == "string" then isEquipped(data, petId) else nil
	if not index then
		return false, "That pet isn't equipped."
	end
	table.remove(data.EquippedPets, index)
	return true, nil
end

function Economy.EquipBestPets(data: PlayerData): (boolean, string?)
	local ids = {}
	for id in data.Pets do
		table.insert(ids, id)
	end
	local multipliers = {}
	for _, id in ids do
		local pet = data.Pets[id]
		multipliers[id] = Formulas.PetMultiplier(pet.Species, pet.Tier)
	end
	table.sort(ids, function(a, b)
		if multipliers[a] ~= multipliers[b] then
			return multipliers[a] > multipliers[b]
		end
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)
	local slots = Formulas.PetEquipSlots(data)
	local equipped = {}
	for i = 1, math.min(slots, #ids) do
		table.insert(equipped, ids[i])
	end
	data.EquippedPets = equipped
	return true, `Equipped your best {#equipped} pets.`
end

function Economy.DeletePet(data: PlayerData, petId: any): (boolean, string?)
	if type(petId) ~= "string" or not data.Pets[petId] then
		return false, "That pet doesn't exist."
	end
	local index = isEquipped(data, petId)
	if index then
		table.remove(data.EquippedPets, index)
	end
	data.Pets[petId] = nil
	return true, nil
end

-- Pet Upgrader: FuseCount identical pets (same species and tier) become one pet of the next tier.
function Economy.FusePets(data: PlayerData, speciesId: any, tier: any): (boolean, string?, PetData?)
	local species = if type(speciesId) == "string" then PetsConfig.SpeciesById[speciesId] else nil
	if not species then
		return false, "That pet doesn't exist."
	end
	if type(tier) ~= "number" or tier ~= math.floor(tier) or tier < 1 or tier >= #PetsConfig.Tiers then
		return false, "Those pets can't be upgraded any further."
	end

	local matching = {}
	for id, pet in data.Pets do
		if pet.Species == species.Id and pet.Tier == tier then
			table.insert(matching, id)
		end
	end
	local needed = PetsConfig.FuseCount
	if #matching < needed then
		return false, `You need {needed} of the same pet. You have {#matching}.`
	end

	-- Use unequipped pets first, oldest first.
	table.sort(matching, function(a, b)
		local aEquipped = isEquipped(data, a) ~= nil
		local bEquipped = isEquipped(data, b) ~= nil
		if aEquipped ~= bEquipped then
			return not aEquipped
		end
		return (tonumber(a) or 0) < (tonumber(b) or 0)
	end)

	local consumedEquipped = false
	for i = 1, needed do
		local id = matching[i]
		local index = isEquipped(data, id)
		if index then
			table.remove(data.EquippedPets, index)
			consumedEquipped = true
		end
		data.Pets[id] = nil
	end

	local pet = Economy.AddPet(data, species.Id, tier + 1)
	if consumedEquipped or #data.EquippedPets < Formulas.PetEquipSlots(data) then
		table.insert(data.EquippedPets, pet.Id)
	end
	local tierName = PetsConfig.Tiers[tier + 1].Name
	local multiplier = Format.Multiplier(Formulas.PetMultiplier(species.Id, tier + 1))
	return true, `Created a {tierName} {species.Name} ({multiplier})!`, pet
end

-- Rebirths

function Economy.Rebirth(data: PlayerData): (boolean, string?)
	local cost = Formulas.RebirthCost(data.RebirthCount)
	if data.Power < cost then
		return false, `You need {Format.Number(cost - data.Power)} more Power to rebirth.`
	end
	data.Power = 0
	data.RebirthCount += 1
	data.RebirthTokens += RebirthConfig.TokensPerRebirth
	local multiplier = Format.Multiplier(Formulas.RebirthMultiplier(data.RebirthCount))
	return true, `Rebirth {data.RebirthCount}! Training multiplier is now {multiplier}.`
end

-- Upgrades

function Economy.BuyUpgrade(data: PlayerData, upgradeId: any): (boolean, string?)
	local upgrade = if type(upgradeId) == "string" then UpgradesConfig.ById[upgradeId] else nil
	if not upgrade then
		return false, "That upgrade doesn't exist."
	end
	local level = Formulas.UpgradeLevel(data, upgrade.Id)
	if level >= upgrade.MaxLevel then
		return false, `{upgrade.Name} is already maxed.`
	end
	if data.RebirthCount < upgrade.RequiredRebirths then
		return false, `{upgrade.Name} unlocks at {upgrade.RequiredRebirths} rebirths.`
	end
	local cost = UpgradesConfig.CostForLevel(upgrade, level)
	if data.RebirthTokens < cost then
		return false, `You need {cost - data.RebirthTokens} more Rebirth Tokens.`
	end

	data.RebirthTokens -= cost
	data.Upgrades[upgrade.Id] = level + 1
	if upgrade.Id == "AutoTrain" then
		data.Settings.AutoTrain = true
	end
	return true, `{upgrade.Name} upgraded to level {level + 1}!`
end

-- Worlds

function Economy.UnlockWorld(data: PlayerData, worldId: any): (boolean, string?)
	local world = if type(worldId) == "string" then WorldsConfig.ById[worldId] else nil
	if not world then
		return false, "That world doesn't exist."
	end
	if data.UnlockedWorlds[world.Id] then
		return false, `{world.Name} is already unlocked.`
	end
	local previous = WorldsConfig.List[world.Order - 1]
	if previous and not data.UnlockedWorlds[previous.Id] then
		return false, `Unlock {previous.Name} first.`
	end
	if data.RebirthCount < world.RequiredRebirths then
		return false, `{world.Name} needs {world.RequiredRebirths} rebirths.`
	end
	if data.Wins < world.UnlockCost then
		return false, `You need {Format.Number(world.UnlockCost - data.Wins)} more Wins.`
	end
	data.Wins -= world.UnlockCost
	data.UnlockedWorlds[world.Id] = true
	return true, `Unlocked {world.Name}!`
end

function Economy.SetCurrentWorld(data: PlayerData, worldId: any): (boolean, string?)
	local world = if type(worldId) == "string" then WorldsConfig.ById[worldId] else nil
	if not world then
		return false, "That world doesn't exist."
	end
	if not data.UnlockedWorlds[world.Id] then
		return false, `{world.Name} is locked.`
	end
	data.CurrentWorld = world.Id
	return true, nil
end

-- Launch rewards

export type LaunchReward = {
	Zone: WorldsConfig.Zone,
	Wins: number,
	Distance: number,
	Best: number,
	IsNewBest: boolean,
}

function Economy.AwardLaunch(data: PlayerData, worldId: string, distance: number): LaunchReward
	local zone = Zones.Find(worldId, distance)
	local wins = Formulas.WinsForZone(data, zone)
	data.Wins = addCapped(data.Wins, wins)
	data.Stats.TotalWinsEarned = addCapped(data.Stats.TotalWinsEarned, wins)
	data.Stats.Launches += 1

	local studs = math.floor(math.max(distance, 0))
	local best = data.BestDistances[worldId] or 0
	local isNewBest = studs > best
	if isNewBest then
		data.BestDistances[worldId] = studs
	end
	return {
		Zone = zone,
		Wins = wins,
		Distance = studs,
		Best = math.max(best, studs),
		IsNewBest = isNewBest,
	}
end

return Economy
