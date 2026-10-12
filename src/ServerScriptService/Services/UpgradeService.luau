-- Token upgrades: see UpgradesConfig for costs and effects.

local ServerScriptService = game:GetService("ServerScriptService")

local Economy = require(ServerScriptService.Logic.Economy)
local Net = require(ServerScriptService.Net)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local UpgradeService = {}

function UpgradeService.Init()
	Net.Handle("BuyUpgrade", function(player, upgradeId)
		local data = PlayerDataService.Get(player)
		if not data then
			return Net.NotLoaded
		end
		local ok, message = Economy.BuyUpgrade(data, upgradeId)
		if ok then
			PlayerDataService.MarkChanged(player)
		end
		return { ok = ok, message = message }
	end, { RateLimit = 4 })
end

return UpgradeService
