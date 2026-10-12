-- Rebirths: see RebirthConfig for the rules and Economy.Rebirth for the transaction.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Utilities.Log)
local Economy = require(ServerScriptService.Logic.Economy)
local Net = require(ServerScriptService.Net)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local log = Log.new("Rebirth")

local RebirthService = {}

function RebirthService.Init()
	Net.Handle("Rebirth", function(player)
		local data = PlayerDataService.Get(player)
		if not data then
			return Net.NotLoaded
		end
		local ok, message = Economy.Rebirth(data)
		if ok then
			PlayerDataService.MarkChanged(player)
			log.info(`{player.Name} rebirthed ({data.RebirthCount})`)
		end
		return { ok = ok, message = message }
	end, { RateLimit = 2 })
end

return RebirthService
