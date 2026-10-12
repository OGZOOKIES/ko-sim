-- Pet Upgrader Machine: 5 identical pets -> 1 pet of the next tier (Gold, Diamond, Rainbow).
-- Economy.FusePets checks and changes everything in one step that can't be interrupted, and
-- Net's per-player lock rejects a second request while one is running.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Utilities.Log)
local Economy = require(ServerScriptService.Logic.Economy)
local Net = require(ServerScriptService.Net)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local log = Log.new("PetUpgrade")

local PetUpgradeService = {}

function PetUpgradeService.Init()
	Net.Handle("UpgradePet", function(player, speciesId, tier)
		local data = PlayerDataService.Get(player)
		if not data then
			return Net.NotLoaded
		end
		local ok, message, pet = Economy.FusePets(data, speciesId, tier)
		if not ok or not pet then
			return Net.Fail(message)
		end
		PlayerDataService.MarkChanged(player)
		log.debug(`{player.Name} upgraded {pet.Species} to tier {pet.Tier}`)
		return Net.Ok(message, { pet = { Id = pet.Id, Species = pet.Species, Tier = pet.Tier } })
	end, { RateLimit = 3 })
end

return PetUpgradeService
