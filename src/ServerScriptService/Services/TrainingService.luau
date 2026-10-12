-- Training: each punch adds Power (see Formulas.TrainingGain).
-- The server decides how often a player may train; extra requests are ignored.
-- Auto Train runs here on the server once the upgrade is owned and switched on.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Logic.Formulas)
local Economy = require(ServerScriptService.Logic.Economy)
local Net = require(ServerScriptService.Net)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

-- Accept a punch slightly early to allow for network jitter.
local INTERVAL_TOLERANCE = 0.8

local TrainingService = {}

local lastTrain: { [Player]: number } = {}

function TrainingService.TryTrain(player: Player): boolean
	local data = PlayerDataService.Get(player)
	if not data then
		return false
	end
	local now = os.clock()
	if now - (lastTrain[player] or 0) < Formulas.TrainingInterval(data) * INTERVAL_TOLERANCE then
		return false
	end
	lastTrain[player] = now
	Economy.Train(data)
	PlayerDataService.MarkChanged(player)
	return true
end

function TrainingService.Init()
	Net.On("Train", function(player)
		TrainingService.TryTrain(player)
	end, { RateLimit = 15 })

	Net.Handle("SelectBag", function(player, bagId)
		local data = PlayerDataService.Get(player)
		if not data then
			return Net.NotLoaded
		end
		local ok, message = Economy.SelectBag(data, bagId)
		if ok then
			PlayerDataService.MarkChanged(player)
		end
		return { ok = ok, message = message }
	end)

	Net.Handle("SetAutoTrain", function(player, enabled)
		local data = PlayerDataService.Get(player)
		if not data then
			return Net.NotLoaded
		end
		if type(enabled) ~= "boolean" then
			return Net.Fail("Invalid request.")
		end
		if Formulas.UpgradeLevel(data, "AutoTrain") < 1 then
			return Net.Fail("Buy Auto Train in the Upgrades shop first.")
		end
		data.Settings.AutoTrain = enabled
		PlayerDataService.MarkChanged(player)
		return Net.Ok(if enabled then "Auto Train on." else "Auto Train off.")
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastTrain[player] = nil
	end)
end

function TrainingService.Start()
	task.spawn(function()
		while true do
			task.wait(0.1)
			for _, player in Players:GetPlayers() do
				local data = PlayerDataService.Get(player)
				if data and data.Settings.AutoTrain and Formulas.UpgradeLevel(data, "AutoTrain") >= 1 then
					TrainingService.TryTrain(player)
				end
			end
		end
	end)
end

return TrainingService
