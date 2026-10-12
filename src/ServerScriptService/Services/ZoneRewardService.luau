-- Turns a finished launch into Wins. LaunchService calls Award exactly once per launch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Utilities.Log)
local Economy = require(ServerScriptService.Logic.Economy)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local log = Log.new("ZoneReward")

local ZoneRewardService = {}

function ZoneRewardService.Award(player: Player, worldId: string, distance: number): Economy.LaunchReward?
	local data = PlayerDataService.Get(player)
	if not data then
		return nil
	end
	local reward = Economy.AwardLaunch(data, worldId, distance)
	PlayerDataService.MarkChanged(player)
	log.debug(`{player.Name}: {reward.Distance} studs, {reward.Zone.Name}, +{reward.Wins} Wins`)
	return reward
end

return ZoneRewardService
