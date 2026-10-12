--!strict
-- Ten gloves per world, bought with Wins. Listed as { Name, Power, Cost in Wins }.
--
-- Power: added to your Power stat each time you train (before multipliers).
-- LaunchBonus: multiplies launch strength. It rises by 0.08 for every glove in the game,
--   from x1.00 (Starter Mitts) to x4.92 (the last Cosmic glove).
-- Gloves must be bought in order inside each world.

local WorldsConfig = require(script.Parent.WorldsConfig)

export type Glove = {
	Id: string,
	World: string,
	Index: number,
	Name: string,
	Power: number,
	Cost: number,
	LaunchBonus: number,
	Color: Color3,
}

local LAUNCH_BONUS_PER_GLOVE = 0.08

local byWorld: { [string]: { { any } } } = {
	Greenfield = {
		{ "Starter Mitts", 1, 0 },
		{ "Wooden Knuckles", 2, 10 },
		{ "Leather Gloves", 4, 30 },
		{ "Iron Fists", 7, 75 },
		{ "Heavy Hitters", 12, 180 },
		{ "Power Punchers", 20, 400 },
		{ "Shockwave Gloves", 35, 900 },
		{ "Thunder Fists", 60, 2000 },
		{ "Titan Smashers", 100, 4500 },
		{ "Meadow Destroyers", 175, 9000 },
	},
	Desert = {
		{ "Sand Wraps", 250, 1500 },
		{ "Cactus Punchers", 400, 4000 },
		{ "Scorpion Stingers", 650, 9000 },
		{ "Dune Breakers", 1000, 18000 },
		{ "Sandstorm Fists", 1600, 35000 },
		{ "Mummy Mitts", 2500, 65000 },
		{ "Scarab Smashers", 4000, 120000 },
		{ "Pharaoh Gauntlets", 6500, 220000 },
		{ "Sphinx Crushers", 10000, 400000 },
		{ "Desert Destroyers", 16000, 700000 },
	},
	Frostbite = {
		{ "Frost Mittens", 22000, 60000 },
		{ "Snowball Fists", 35000, 150000 },
		{ "Icicle Knuckles", 55000, 320000 },
		{ "Penguin Pounders", 85000, 650000 },
		{ "Glacier Gloves", 130000, 1200000 },
		{ "Yeti Paws", 200000, 2200000 },
		{ "Blizzard Bashers", 320000, 4000000 },
		{ "Crystal Crushers", 500000, 7000000 },
		{ "Avalanche Fists", 800000, 12000000 },
		{ "Frostbite Annihilators", 1250000, 20000000 },
	},
	Inferno = {
		{ "Ember Wraps", 1.8e6, 1.5e6 },
		{ "Cinder Fists", 2.8e6, 4e6 },
		{ "Magma Mitts", 4.5e6, 9e6 },
		{ "Obsidian Knuckles", 7e6, 18e6 },
		{ "Lava Lashers", 11e6, 35e6 },
		{ "Phoenix Talons", 17e6, 65e6 },
		{ "Volcano Punchers", 27e6, 120e6 },
		{ "Dragon Claws", 42e6, 220e6 },
		{ "Hellfire Gauntlets", 65e6, 400e6 },
		{ "Inferno Obliterators", 100e6, 700e6 },
	},
	Cosmic = {
		{ "Stardust Wraps", 150e6, 50e6 },
		{ "Meteor Mitts", 240e6, 120e6 },
		{ "Comet Crushers", 380e6, 260e6 },
		{ "Nebula Knuckles", 600e6, 520e6 },
		{ "Plasma Punchers", 950e6, 1e9 },
		{ "Supernova Fists", 1.5e9, 2e9 },
		{ "Quasar Gauntlets", 2.4e9, 3.6e9 },
		{ "Galaxy Smashers", 3.8e9, 6.5e9 },
		{ "Black Hole Bashers", 6e9, 11e9 },
		{ "Cosmic Annihilators", 10e9, 20e9 },
	},
}

local GlovesConfig = {
	List = {} :: { Glove },
	ById = {} :: { [string]: Glove },
	ByWorld = {} :: { [string]: { Glove } },
	StarterGloveId = "Greenfield_1",
}

local globalIndex = 0
for _, world in WorldsConfig.List do
	local entries = byWorld[world.Id]
	assert(entries, `GlovesConfig is missing gloves for world {world.Id}`)
	local worldGloves = {}
	for i, entry in entries do
		globalIndex += 1
		local glove: Glove = {
			Id = `{world.Id}_{i}`,
			World = world.Id,
			Index = i,
			Name = entry[1] :: string,
			Power = entry[2] :: number,
			Cost = entry[3] :: number,
			LaunchBonus = 1 + (globalIndex - 1) * LAUNCH_BONUS_PER_GLOVE,
			-- Gloves fade from white to the world's accent colour as they get stronger.
			Color = Color3.new(1, 1, 1):Lerp(world.Theme.Accent, 0.35 + 0.65 * (i - 1) / 9),
		}
		table.insert(worldGloves, glove)
		table.insert(GlovesConfig.List, glove)
		GlovesConfig.ById[glove.Id] = glove
	end
	GlovesConfig.ByWorld[world.Id] = worldGloves
end

return GlovesConfig
