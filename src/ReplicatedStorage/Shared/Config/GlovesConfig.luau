--!strict
-- Ten gloves per world, bought with Wins. Listed as { Name, Power, Cost in Wins }.
-- How each glove looks is in GloveDesigns (same order); ids are "<World>_<1-10>" and never change,
-- so renaming a glove here is safe for saved data.
--
-- Gloves give two separate stats (see Logic/Formulas):
--   Power        added to your Power each time you train, before multipliers
--   LaunchForce  multiplies your punch force when launching. +0.08 per glove across the game:
--                x1.00 (Starter Mitts) up to x4.92 (Cosmic Annihilators)
-- Gloves must be bought in order inside each world.

local WorldsConfig = require(script.Parent.WorldsConfig)

export type Glove = {
	Id: string,
	World: string,
	Index: number, -- 1-10 inside its world
	Tier: number, -- 1-50 across the game
	Name: string,
	Power: number,
	Cost: number,
	LaunchForce: number,
}

local LAUNCH_FORCE_PER_GLOVE = 0.08

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
		{ "Dune Brawlers", 250, 1500 },
		{ "Scorpion Grips", 400, 4000 },
		{ "Sandstorm Crushers", 650, 9000 },
		{ "Mirage Strikers", 1000, 18000 },
		{ "Canyon Breakers", 1600, 35000 },
		{ "Sunforge Gauntlets", 2500, 65000 },
		{ "Pharaoh's Wrath", 4000, 120000 },
		{ "Dune Devastators", 6500, 220000 },
		{ "Scorch Titans", 10000, 400000 },
		{ "Desert Sovereigns", 16000, 700000 },
	},
	Frostbite = {
		{ "Frostbite Mitts", 22000, 60000 },
		{ "Glacier Grips", 35000, 150000 },
		{ "Avalanche Fists", 55000, 320000 },
		{ "Crystal Breakers", 85000, 650000 },
		{ "Permafrost Gauntlets", 130000, 1200000 },
		{ "Blizzard Strikers", 200000, 2200000 },
		{ "Arctic Warlords", 320000, 4000000 },
		{ "Frozen Colossus", 500000, 7000000 },
		{ "Glacial Monarchs", 800000, 12000000 },
		{ "Absolute Zero", 1250000, 20000000 },
	},
	Inferno = {
		{ "Cinder Fists", 1.8e6, 1.5e6 },
		{ "Ashen Knuckles", 2.8e6, 4e6 },
		{ "Magma Crushers", 4.5e6, 9e6 },
		{ "Hellforge Gauntlets", 7e6, 18e6 },
		{ "Infernal Strikers", 11e6, 35e6 },
		{ "Lava Titans", 17e6, 65e6 },
		{ "Demon King's Grips", 27e6, 120e6 },
		{ "Cataclysm Fists", 42e6, 220e6 },
		{ "Worldender Gauntlets", 65e6, 400e6 },
		{ "Inferno Sovereigns", 100e6, 700e6 },
	},
	Cosmic = {
		{ "Stardust Gloves", 150e6, 50e6 },
		{ "Nebula Grips", 240e6, 120e6 },
		{ "Orbit Breakers", 380e6, 260e6 },
		{ "Quantum Fists", 600e6, 520e6 },
		{ "Pulsar Gauntlets", 950e6, 1e9 },
		{ "Black Hole Crushers", 1.5e9, 2e9 },
		{ "Supernova Strikers", 2.4e9, 3.6e9 },
		{ "Celestial Titans", 3.8e9, 6.5e9 },
		{ "Dimension Breakers", 6e9, 11e9 },
		{ "Cosmic Annihilators", 10e9, 20e9 },
	},
}

local GlovesConfig = {
	List = {} :: { Glove },
	ById = {} :: { [string]: Glove },
	ByWorld = {} :: { [string]: { Glove } },
	StarterGloveId = "Greenfield_1",
}

local tier = 0
for _, world in WorldsConfig.List do
	local entries = byWorld[world.Id]
	assert(entries, `GlovesConfig is missing gloves for world {world.Id}`)
	local worldGloves = {}
	for i, entry in entries do
		tier += 1
		local glove: Glove = {
			Id = `{world.Id}_{i}`,
			World = world.Id,
			Index = i,
			Tier = tier,
			Name = entry[1] :: string,
			Power = entry[2] :: number,
			Cost = entry[3] :: number,
			LaunchForce = 1 + (tier - 1) * LAUNCH_FORCE_PER_GLOVE,
		}
		table.insert(worldGloves, glove)
		table.insert(GlovesConfig.List, glove)
		GlovesConfig.ById[glove.Id] = glove
	end
	GlovesConfig.ByWorld[world.Id] = worldGloves
end

return GlovesConfig
