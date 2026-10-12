--!strict
-- The saved-data schema: defaults for new players, migrations for old saves, and cleanup.
--
-- Changing the schema:
--   1. Add the field to New() (and to Shared/Types).
--   2. If old saves need converting, bump VERSION and add Migrations[oldVersion].
--      Fields that only need a default are filled in by Reconcile, no migration needed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BagsConfig = require(Shared.Config.BagsConfig)
local GameConfig = require(Shared.Config.GameConfig)
local GlovesConfig = require(Shared.Config.GlovesConfig)
local WorldsConfig = require(Shared.Config.WorldsConfig)
local Formulas = require(Shared.Logic.Formulas)
local Types = require(Shared.Types)

type PlayerData = Types.PlayerData

local VERSION = 1

local DataTemplate = {
	Version = VERSION,
}

function DataTemplate.New(): PlayerData
	return {
		Version = VERSION,
		Power = 0,
		Wins = 0,
		RebirthCount = 0,
		RebirthTokens = 0,
		OwnedGloves = { [GlovesConfig.StarterGloveId] = true },
		EquippedGlove = GlovesConfig.StarterGloveId,
		Pets = {},
		EquippedPets = {},
		NextPetId = 1,
		Upgrades = {},
		UnlockedWorlds = { [GameConfig.StartingWorld] = true },
		CurrentWorld = GameConfig.StartingWorld,
		SelectedBag = BagsConfig.DefaultBagId,
		BestDistances = {},
		Settings = { AutoTrain = false },
		Stats = { Launches = 0, TotalWinsEarned = 0, PetsHatched = 0 },
	}
end

-- Migrations[n] converts version n data to version n + 1, in place.
local Migrations: { [number]: (any) -> () } = {
	-- [1] = function(data) data.NewField = data.OldField; data.OldField = nil end,
}

local function migrate(data: any)
	local version = tonumber(data.Version) or 1
	while version < VERSION do
		local migration = Migrations[version]
		if migration then
			migration(data)
		end
		version += 1
	end
	data.Version = VERSION
end

-- Fills in any missing fields with defaults. Nested record tables (Settings, Stats) are filled
-- key by key; collections (Pets, Upgrades, ...) are only created if missing.
local RECORD_FIELDS = { Settings = true, Stats = true }

local function reconcile(data: any)
	local defaults = DataTemplate.New() :: any
	for key, default in defaults do
		local value = data[key]
		if value == nil or typeof(value) ~= typeof(default) then
			data[key] = default
		elseif RECORD_FIELDS[key] then
			for subKey, subDefault in default do
				if typeof(value[subKey]) ~= typeof(subDefault) then
					value[subKey] = subDefault
				end
			end
		end
	end
end

local function finiteOrZero(n: number): number
	if n ~= n or n == math.huge or n == -math.huge then
		return 0
	end
	return math.clamp(n, 0, GameConfig.MaxNumber)
end

-- Repairs anything that no longer matches the config (removed gloves, too many equipped pets...).
function DataTemplate.Sanitize(data: PlayerData)
	data.Power = finiteOrZero(data.Power)
	data.Wins = finiteOrZero(data.Wins)
	data.RebirthCount = math.floor(finiteOrZero(data.RebirthCount))
	data.RebirthTokens = math.floor(finiteOrZero(data.RebirthTokens))

	data.OwnedGloves[GlovesConfig.StarterGloveId] = true
	if not data.OwnedGloves[data.EquippedGlove] or not GlovesConfig.ById[data.EquippedGlove] then
		data.EquippedGlove = GlovesConfig.StarterGloveId
	end

	data.UnlockedWorlds[GameConfig.StartingWorld] = true
	if not data.UnlockedWorlds[data.CurrentWorld] or not WorldsConfig.ById[data.CurrentWorld] then
		data.CurrentWorld = GameConfig.StartingWorld
	end

	local bag = BagsConfig.ById[data.SelectedBag]
	if not bag or bag.RequiredRebirths > data.RebirthCount then
		data.SelectedBag = BagsConfig.DefaultBagId
	end

	-- NextPetId must stay above every existing pet id so ids are never reused.
	for petId in data.Pets do
		local n = tonumber(petId)
		if n and n >= data.NextPetId then
			data.NextPetId = n + 1
		end
	end

	-- Equipped pets: must exist, no duplicates, no more than the slot count.
	local slots = Formulas.PetEquipSlots(data)
	local seen = {}
	local equipped = {}
	for _, petId in data.EquippedPets do
		if data.Pets[petId] and not seen[petId] and #equipped < slots then
			seen[petId] = true
			table.insert(equipped, petId)
		end
	end
	data.EquippedPets = equipped
end

-- Turns whatever was loaded from the DataStore into valid current-version data.
function DataTemplate.Prepare(raw: any): PlayerData
	migrate(raw)
	reconcile(raw)
	local data = raw :: PlayerData
	DataTemplate.Sanitize(data)
	return data
end

return DataTemplate
