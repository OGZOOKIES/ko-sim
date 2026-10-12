--!strict
-- Game-wide settings. Everything in ReplicatedStorage is visible to players: never put secrets here.

local GameConfig = {
	GameName = "Ragdoll Punch Simulator",
	Version = "0.1.0",

	-- Prints Log.debug messages. Debug logs only appear in Studio, even when this is true.
	DebugLogging = true,

	-- Runs ServerScriptService.Tests when you press Play in Studio. Results go to the Output window.
	RunTestsInStudio = true,

	StartingWorld = "Greenfield",

	-- World layout: each world is built at (0, WorldBaseHeight, (order - 1) * WorldSpacing).
	WorldSpacing = 2000,
	WorldBaseHeight = 100,

	-- Seconds between training punches before Training Speed upgrades.
	TrainingInterval = 0.4,

	-- DataStore
	DataStoreName = "PlayerData_v1",
	AutosaveInterval = 60,

	-- Largest value a currency can reach. Keeps numbers far away from infinity.
	MaxNumber = 1e300,
}

return table.freeze(GameConfig)
