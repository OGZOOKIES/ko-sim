--!strict
-- Pet rarities, upgrade tiers and the eight species of each world.
--
-- A species' multiplier = its rarity's BaseMultiplier * its world's WorldScale.
-- Upgrade tiers multiply that base: Gold x2, Diamond x3, Rainbow x4.
-- Equipped pets combine additively: total = 1 + sum of (pet multiplier - 1).

local WorldsConfig = require(script.Parent.WorldsConfig)

export type Rarity = {
	Id: string,
	Order: number,
	Probability: number, -- percent; all rarities must add up to 100
	BaseMultiplier: number,
	Color: Color3,
}

export type Tier = {
	Id: number,
	Name: string,
	Multiplier: number,
}

export type Species = {
	Id: string,
	Name: string,
	World: string,
	Rarity: string,
	Multiplier: number,
	Color: Color3,
}

local rgb = Color3.fromRGB

local rarities: { Rarity } = {
	{ Id = "Common", Order = 1, Probability = 45, BaseMultiplier = 1.1, Color = rgb(200, 200, 200) },
	{ Id = "Uncommon", Order = 2, Probability = 25, BaseMultiplier = 1.5, Color = rgb(100, 220, 100) },
	{ Id = "Rare", Order = 3, Probability = 15, BaseMultiplier = 2, Color = rgb(70, 150, 255) },
	{ Id = "Epic", Order = 4, Probability = 8, BaseMultiplier = 3, Color = rgb(180, 90, 255) },
	{ Id = "Legendary", Order = 5, Probability = 4.5, BaseMultiplier = 5, Color = rgb(255, 180, 40) },
	{ Id = "Mythic", Order = 6, Probability = 2, BaseMultiplier = 8, Color = rgb(255, 70, 110) },
	{ Id = "Divine", Order = 7, Probability = 0.49, BaseMultiplier = 12, Color = rgb(120, 255, 240) },
	{ Id = "Secret", Order = 8, Probability = 0.01, BaseMultiplier = 25, Color = rgb(255, 40, 220) },
}

local tiers: { Tier } = {
	{ Id = 1, Name = "Normal", Multiplier = 1 },
	{ Id = 2, Name = "Gold", Multiplier = 2 },
	{ Id = 3, Name = "Diamond", Multiplier = 3 },
	{ Id = 4, Name = "Rainbow", Multiplier = 4 },
}

-- Later worlds' pets are stronger.
local worldScale: { [string]: number } = {
	Greenfield = 1,
	Desert = 1.6,
	Frostbite = 2.5,
	Inferno = 4,
	Cosmic = 6.5,
}

-- One species per rarity, in rarity order: { Name, Color }.
local speciesByWorld: { [string]: { { any } } } = {
	Greenfield = {
		{ "Bunny", rgb(240, 230, 220) },
		{ "Duckling", rgb(255, 225, 80) },
		{ "Fox", rgb(240, 130, 50) },
		{ "Owl", rgb(150, 110, 80) },
		{ "Deer", rgb(190, 140, 90) },
		{ "Unicorn", rgb(255, 180, 230) },
		{ "Meadow Sprite", rgb(150, 255, 150) },
		{ "Clover King", rgb(40, 200, 80) },
	},
	Desert = {
		{ "Camel", rgb(210, 170, 110) },
		{ "Lizard", rgb(150, 190, 80) },
		{ "Scorpion", rgb(170, 70, 40) },
		{ "Vulture", rgb(100, 80, 70) },
		{ "Fennec Fox", rgb(245, 200, 140) },
		{ "Sand Serpent", rgb(230, 190, 90) },
		{ "Sphinx Cat", rgb(255, 215, 120) },
		{ "Golden Scarab", rgb(255, 200, 0) },
	},
	Frostbite = {
		{ "Penguin", rgb(40, 40, 50) },
		{ "Snow Hare", rgb(250, 250, 255) },
		{ "Arctic Fox", rgb(220, 235, 255) },
		{ "Polar Bear", rgb(240, 240, 235) },
		{ "Snow Owl", rgb(230, 230, 250) },
		{ "Yeti", rgb(190, 220, 255) },
		{ "Ice Dragon", rgb(100, 200, 255) },
		{ "Aurora Spirit", rgb(120, 255, 200) },
	},
	Inferno = {
		{ "Ember Slime", rgb(255, 120, 40) },
		{ "Lava Pup", rgb(220, 70, 30) },
		{ "Fire Salamander", rgb(255, 90, 60) },
		{ "Magma Golem", rgb(120, 50, 40) },
		{ "Phoenix", rgb(255, 170, 30) },
		{ "Hellhound", rgb(80, 20, 20) },
		{ "Inferno Dragon", rgb(255, 50, 20) },
		{ "Molten King", rgb(255, 210, 60) },
	},
	Cosmic = {
		{ "Space Puppy", rgb(200, 200, 255) },
		{ "Moon Cat", rgb(220, 220, 230) },
		{ "Alien", rgb(110, 255, 110) },
		{ "Star Jelly", rgb(255, 150, 255) },
		{ "Comet Fox", rgb(120, 200, 255) },
		{ "Nebula Whale", rgb(150, 90, 255) },
		{ "Galaxy Dragon", rgb(90, 60, 200) },
		{ "Cosmic Overlord", rgb(255, 255, 255) },
	},
}

local PetsConfig = {
	Rarities = rarities,
	RaritiesById = {} :: { [string]: Rarity },
	Tiers = tiers,
	WorldScale = worldScale,
	Species = {} :: { Species },
	SpeciesById = {} :: { [string]: Species },
	SpeciesByWorld = {} :: { [string]: { Species } },

	-- Pets needed to upgrade to the next tier.
	FuseCount = 5,

	BaseEquipSlots = 3,
	InventoryCapacity = 60,

	-- Egg Luck boosts the weight of every rarity at or above this order (Rare and better).
	LuckAffectsFromOrder = 3,
}

for _, rarity in rarities do
	PetsConfig.RaritiesById[rarity.Id] = rarity
end

local function round2(n: number): number
	return math.floor(n * 100 + 0.5) / 100
end

for _, world in WorldsConfig.List do
	local entries = speciesByWorld[world.Id]
	assert(entries, `PetsConfig is missing species for world {world.Id}`)
	local scale = worldScale[world.Id] or 1
	local worldSpecies = {}
	for i, entry in entries do
		local rarity = rarities[i]
		assert(rarity, `World {world.Id} lists more species than there are rarities`)
		local species: Species = {
			Id = `{world.Id}_{rarity.Id}`,
			Name = entry[1] :: string,
			World = world.Id,
			Rarity = rarity.Id,
			Multiplier = round2(rarity.BaseMultiplier * scale),
			Color = entry[2] :: Color3,
		}
		table.insert(worldSpecies, species)
		table.insert(PetsConfig.Species, species)
		PetsConfig.SpeciesById[species.Id] = species
	end
	PetsConfig.SpeciesByWorld[world.Id] = worldSpecies
end

return PetsConfig
