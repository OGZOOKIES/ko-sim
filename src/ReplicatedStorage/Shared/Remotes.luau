--!strict
-- Names of every remote. The server creates them in ReplicatedStorage.Remotes when it starts;
-- clients wait for them there. Add a name here before using a new remote.
--
-- Functions (client -> server, returns { ok: boolean, message: string?, ... }):
--   GetState()                         -> { ok, data }
--   BuyGlove(gloveId) / EquipGlove(gloveId)
--   HatchEgg(eggId)                    -> { ok, pet }
--   EquipPet(petId) / UnequipPet(petId) / EquipBestPets() / DeletePet(petId)
--   UpgradePet(speciesId, tier)        -> { ok, pet }
--   Rebirth()
--   BuyUpgrade(upgradeId)
--   SelectBag(bagId) / SetAutoTrain(enabled)
--   UnlockWorld(worldId) / TravelToWorld(worldId)
--   StartLaunch()                      -- start charging at the launch station you're standing at
--   ReleasePunch(sessionId, charge)    -- release the charging punch
--
-- Events:
--   Train            client -> server, no arguments
--   StateUpdated     server -> client (data snapshot)
--   Notify           server -> client (message, kind)
--   ChargeStarted    server -> client (info)
--   LaunchStarted    server -> client (info)
--   LaunchEnded      server -> client (result)

local Remotes = {
	Functions = {
		"GetState",
		"BuyGlove",
		"EquipGlove",
		"HatchEgg",
		"EquipPet",
		"UnequipPet",
		"EquipBestPets",
		"DeletePet",
		"UpgradePet",
		"Rebirth",
		"BuyUpgrade",
		"SelectBag",
		"SetAutoTrain",
		"UnlockWorld",
		"TravelToWorld",
		"StartLaunch",
		"ReleasePunch",
	},
	Events = {
		"Train",
		"StateUpdated",
		"Notify",
		"ChargeStarted",
		"LaunchStarted",
		"LaunchEnded",
	},
}

return table.freeze(Remotes)
