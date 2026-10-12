--!strict
-- One egg per world, containing that world's eight species.
-- Hatch odds come from each species' rarity (PetsConfig.Rarities).

local PetsConfig = require(script.Parent.PetsConfig)
local WorldsConfig = require(script.Parent.WorldsConfig)

export type Egg = {
	Id: string,
	Name: string,
	World: string,
	Cost: number, -- Wins
	Pets: { string }, -- species ids
}

local eggs: { [string]: { Name: string, Cost: number } } = {
	Greenfield = { Name = "Meadow Egg", Cost = 25 },
	Desert = { Name = "Sandstone Egg", Cost = 1000 },
	Frostbite = { Name = "Frozen Egg", Cost = 30000 },
	Inferno = { Name = "Magma Egg", Cost = 800000 },
	Cosmic = { Name = "Galaxy Egg", Cost = 25000000 },
}

local EggsConfig = {
	List = {} :: { Egg },
	ById = {} :: { [string]: Egg },
	ByWorld = {} :: { [string]: Egg },
}

for _, world in WorldsConfig.List do
	local entry = eggs[world.Id]
	assert(entry, `EggsConfig is missing an egg for world {world.Id}`)
	local pets = {}
	for _, species in PetsConfig.SpeciesByWorld[world.Id] do
		table.insert(pets, species.Id)
	end
	local egg: Egg = {
		Id = `{world.Id}Egg`,
		Name = entry.Name,
		World = world.Id,
		Cost = entry.Cost,
		Pets = pets,
	}
	table.insert(EggsConfig.List, egg)
	EggsConfig.ById[egg.Id] = egg
	EggsConfig.ByWorld[world.Id] = egg
end

return EggsConfig
