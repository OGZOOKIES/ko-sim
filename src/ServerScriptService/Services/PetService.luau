-- Eggs and the pet inventory. Hatch results are rolled on the server only.
-- Equipped pets are published as a player attribute so every client can draw them following.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EggsConfig = require(Shared.Config.EggsConfig)
local Log = require(Shared.Utilities.Log)
local Economy = require(ServerScriptService.Logic.Economy)
local Net = require(ServerScriptService.Net)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local log = Log.new("Pets")

-- Matches the client's hatch animation length so hatches can't be spammed.
local HATCH_COOLDOWN = 1.5

local PetService = {}

local rng = Random.new()
local lastHatch: { [Player]: number } = {}

-- "species:tier,species:tier" for the follow visuals.
local function updatePetAttribute(player: Player, data)
	local parts = {}
	for _, petId in data.EquippedPets do
		local pet = data.Pets[petId]
		if pet then
			table.insert(parts, `{pet.Species}:{pet.Tier}`)
		end
	end
	local value = table.concat(parts, ",")
	if player:GetAttribute("EquippedPets") ~= value then
		player:SetAttribute("EquippedPets", value)
	end
end

local function simpleHandler(action: (any, any) -> (boolean, string?))
	return function(player: Player, petId: any)
		local data = PlayerDataService.Get(player)
		if not data then
			return Net.NotLoaded
		end
		local ok, message = action(data, petId)
		if ok then
			PlayerDataService.MarkChanged(player)
		end
		return { ok = ok, message = message }
	end
end

function PetService.Init()
	Net.Handle("HatchEgg", function(player, eggId)
		local data = PlayerDataService.Get(player)
		if not data then
			return Net.NotLoaded
		end
		local egg = if type(eggId) == "string" then EggsConfig.ById[eggId] else nil
		if not egg then
			return Net.Fail("That egg doesn't exist.")
		end
		if data.CurrentWorld ~= egg.World then
			return Net.Fail("Travel to that world to hatch its egg.")
		end
		if os.clock() - (lastHatch[player] or 0) < HATCH_COOLDOWN then
			return Net.Fail("Still hatching...")
		end

		local ok, message, pet = Economy.HatchEgg(data, egg.Id, rng)
		if not ok or not pet then
			return Net.Fail(message)
		end
		lastHatch[player] = os.clock()
		PlayerDataService.MarkChanged(player)
		log.debug(`{player.Name} hatched {pet.Species}`)
		return Net.Ok(nil, { pet = { Id = pet.Id, Species = pet.Species, Tier = pet.Tier } })
	end, { RateLimit = 3 })

	Net.Handle("EquipPet", simpleHandler(Economy.EquipPet))
	Net.Handle("UnequipPet", simpleHandler(Economy.UnequipPet))
	Net.Handle("DeletePet", simpleHandler(Economy.DeletePet))
	Net.Handle("EquipBestPets", simpleHandler(function(data)
		return Economy.EquipBestPets(data)
	end))

	Players.PlayerRemoving:Connect(function(player)
		lastHatch[player] = nil
	end)
end

function PetService.Start()
	PlayerDataService.DataChanged:Connect(updatePetAttribute)
end

return PetService
