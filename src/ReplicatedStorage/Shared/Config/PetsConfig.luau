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
	Form: string,
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

-- One species per rarity, in rarity order: { Name, Color, Form }. Form picks the model built by Pets/PetBuilder.
local speciesByWorld: { [string]: { { any } } } = {
	Greenfield = {
		{ "Bunny", rgb(240, 230, 220), "Bunny" },
		{ "Duckling", rgb(255, 225, 80), "Bird" },
		{ "Fox", rgb(240, 130, 50), "Fox" },
		{ "Owl", rgb(150, 110, 80), "Owl" },
		{ "Deer", rgb(190, 140, 90), "Deer" },
		{ "Unicorn", rgb(255, 180, 230), "Unicorn" },
		{ "Meadow Sprite", rgb(150, 255, 150), "Spirit" },
		{ "Clover King", rgb(40, 200, 80), "King" },
	},
	Desert = {
		{ "Camel", rgb(210, 170, 110), "Camel" },
		{ "Lizard", rgb(150, 190, 80), "Lizard" },
		{ "Scorpion", rgb(170, 70, 40), "Scorpion" },
		{ "Vulture", rgb(100, 80, 70), "Bird" },
		{ "Fennec Fox", rgb(245, 200, 140), "Fox" },
		{ "Sand Serpent", rgb(230, 190, 90), "Serpent" },
		{ "Sphinx Cat", rgb(255, 215, 120), "Cat" },
		{ "Golden Scarab", rgb(255, 200, 0), "Beetle" },
	},
	Frostbite = {
		{ "Penguin", rgb(40, 40, 50), "Penguin" },
		{ "Snow Hare", rgb(250, 250, 255), "Bunny" },
		{ "Arctic Fox", rgb(220, 235, 255), "Fox" },
		{ "Polar Bear", rgb(240, 240, 235), "Bear" },
		{ "Snow Owl", rgb(230, 230, 250), "Owl" },
		{ "Yeti", rgb(190, 220, 255), "Yeti" },
		{ "Ice Dragon", rgb(100, 200, 255), "Dragon" },
		{ "Aurora Spirit", rgb(120, 255, 200), "Spirit" },
	},
	Inferno = {
		{ "Ember Slime", rgb(255, 120, 40), "Slime" },
		{ "Lava Pup", rgb(220, 70, 30), "Dog" },
		{ "Fire Salamander", rgb(255, 90, 60), "Lizard" },
		{ "Magma Golem", rgb(120, 50, 40), "Golem" },
		{ "Phoenix", rgb(255, 170, 30), "Phoenix" },
		{ "Hellhound", rgb(80, 20, 20), "Dog" },
		{ "Inferno Dragon", rgb(255, 50, 20), "Dragon" },
		{ "Molten King", rgb(255, 210, 60), "King" },
	},
	Cosmic = {
		{ "Space Puppy", rgb(200, 200, 255), "Dog" },
		{ "Moon Cat", rgb(220, 220, 230), "Cat" },
		{ "Alien", rgb(110, 255, 110), "Alien" },
		{ "Star Jelly", rgb(255, 150, 255), "Jelly" },
		{ "Comet Fox", rgb(120, 200, 255), "Fox" },
		{ "Nebula Whale", rgb(150, 90, 255), "Whale" },
		{ "Galaxy Dragon", rgb(90, 60, 200), "Dragon" },
		{ "Cosmic Overlord", rgb(255, 255, 255), "King" },
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
			Form = entry[3] :: string,
		}
		table.insert(worldSpecies, species)
		table.insert(PetsConfig.Species, species)
		PetsConfig.SpeciesById[species.Id] = species
	end
	PetsConfig.SpeciesByWorld[world.Id] = worldSpecies
end

return PetsConfig
