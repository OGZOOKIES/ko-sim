-- Builds one world from its config. Each part of the world has its own module:
--
--   Hub           stone plaza, avenue, lawns, walls, lamps, spawn monument, welcome arch
--   Stations      glove shop, eggs, rebirth altar, world portal, pet upgrader, upgrades
--   TrainingArea  the Training Grounds pavilion and plaza
--   LaunchArena   punch platform, stands, LAUNCH ZONE gate, display dummy
--   Runway        stone track, ten landing zones, signs, markings, finish
--   Landscape     terrain (hills, mountains, lakes or floating islands) and prop groves
--
-- Layout (studs, relative to the world origin; runway along +X):
--
--            z = -70:  Portal   Gloves   Eggs   Rebirth
--   spawn -- arch -- avenue (z = 0) ------------------ arena | dummy | runway ->
--            z = +70:  Fuse   Upgrades
--            z = +90..195: Training Grounds (x = -290..-140)
--
--   x = -290 .. 0   hub (top at y = 0, ground 20 studs below)
--   x = 0 .. end    runway, 80 studs wide

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EnvironmentConfig = require(Shared.Config.EnvironmentConfig)
local Formulas = require(Shared.Logic.Formulas)
local Hub = require(script.Parent.Hub)
local Landscape = require(script.Parent.Landscape)
local LaunchArena = require(script.Parent.LaunchArena)
local Runway = require(script.Parent.Runway)
local Stations = require(script.Parent.Stations)
local TrainingArea = require(script.Parent.TrainingArea)

export type Layout = {
	WorldId: string,
	Model: Model,
	Origin: Vector3, -- start of the runway, on the floor
	Forward: Vector3,
	Right: Vector3,
	RunwayLength: number,
	RunwayHalfWidth: number,
	SpawnLocation: SpawnLocation,
	DummyCFrame: CFrame,
	DummyOffset: number,
	StationPosition: Vector3,
	LaunchPrompt: ProximityPrompt,
}

local WorldBuilder = {}

function WorldBuilder.Build(world, origin: Vector3, parent: Instance): Layout
	local env = EnvironmentConfig[world.Id]
	assert(env, `EnvironmentConfig is missing world {world.Id}`)

	local model = Instance.new("Model")
	model.Name = world.Id
	model:SetAttribute("WorldId", world.Id)

	local runwayLength = Formulas.RunwayLength(world.Id)

	local spawnLocation = Hub.Build(model, origin, world, env)

	local stations = Instance.new("Model")
	stations.Name = "Stations"
	stations.Parent = model
	Stations.Build(stations, origin, world, env)
	TrainingArea.Build(stations, origin, world)

	local arena = LaunchArena.Build(model, origin, world, env)
	Runway.Build(model, origin, world, env, runwayLength, Hub.FloorThickness)
	Landscape.Build(model, origin, world, env, runwayLength)

	model.Parent = parent

	return {
		WorldId = world.Id,
		Model = model,
		Origin = origin,
		Forward = Vector3.xAxis,
		Right = Vector3.zAxis,
		RunwayLength = runwayLength,
		RunwayHalfWidth = Runway.HalfWidth,
		SpawnLocation = spawnLocation,
		DummyCFrame = arena.DummyCFrame,
		DummyOffset = LaunchArena.DummyOffset,
		StationPosition = arena.StationPosition,
		LaunchPrompt = arena.Prompt,
	}
end

return WorldBuilder
