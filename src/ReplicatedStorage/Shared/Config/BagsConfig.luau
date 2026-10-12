--!strict
-- Punching bags multiply Power gained from training. They unlock by rebirth count and are free to use.

export type Bag = {
	Id: string,
	Order: number,
	Name: string,
	RequiredRebirths: number,
	Multiplier: number,
	Color: Color3,
}

local rgb = Color3.fromRGB

local list: { Bag } = {
	{ Id = "Basic", Order = 1, Name = "Basic Bag", RequiredRebirths = 0, Multiplier = 1, Color = rgb(200, 60, 60) },
	{ Id = "Reinforced", Order = 2, Name = "Reinforced Bag", RequiredRebirths = 2, Multiplier = 2, Color = rgb(70, 120, 220) },
	{ Id = "Heavy", Order = 3, Name = "Heavy Bag", RequiredRebirths = 5, Multiplier = 4, Color = rgb(60, 60, 70) },
	{ Id = "Titan", Order = 4, Name = "Titan Bag", RequiredRebirths = 10, Multiplier = 8, Color = rgb(240, 180, 40) },
	{ Id = "Elemental", Order = 5, Name = "Elemental Bag", RequiredRebirths = 20, Multiplier = 15, Color = rgb(60, 220, 160) },
	{ Id = "Cosmic", Order = 6, Name = "Cosmic Bag", RequiredRebirths = 50, Multiplier = 30, Color = rgb(170, 90, 255) },
}

local BagsConfig = {
	List = list,
	ById = {} :: { [string]: Bag },
	DefaultBagId = "Basic",
}

for _, bag in list do
	BagsConfig.ById[bag.Id] = bag
end

return BagsConfig
