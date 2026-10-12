-- Server entry point. Creates the remotes, then initialises and starts every service in order.
--
-- Init: create remotes handlers, build things, connect to other services' events.
-- Start: begin doing work (loops, player handling).
-- PlayerDataService starts last so every service is listening before any profile loads.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Log = require(Shared.Utilities.Log)
local Net = require(script.Parent.Net)

local log = Log.new("Bootstrap")

local Services = script.Parent.Services

local ORDER = {
	"PlayerDataService",
	"WorldService",
	"ZoneRewardService",
	"TrainingService",
	"ShopService",
	"PetService",
	"PetUpgradeService",
	"RebirthService",
	"UpgradeService",
	"LaunchService",
}

log.info(`Starting {GameConfig.GameName} v{GameConfig.Version}`)

Net.Init()

local services = {}
for _, name in ORDER do
	services[name] = require(Services:WaitForChild(name))
end

for _, name in ORDER do
	local service = services[name]
	if service.Init then
		service.Init()
	end
end

for _, name in ORDER do
	local service = services[name]
	if name ~= "PlayerDataService" and service.Start then
		service.Start()
	end
end
services.PlayerDataService.Start()

log.info("Server ready")

if RunService:IsStudio() and GameConfig.RunTestsInStudio then
	task.spawn(function()
		require(script.Parent.Tests.TestRunner).Run()
	end)
end
