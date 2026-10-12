--!strict
-- Permanent upgrades bought with Rebirth Tokens.
--
--   Cost of the next level = BaseCost + CostStep * current level
--   Effect                 = level * EffectPerLevel
--
-- What each effect means is applied in Logic/Formulas.

export type Upgrade = {
	Id: string,
	Order: number,
	Name: string,
	Icon: string,
	Description: string,
	MaxLevel: number,
	BaseCost: number,
	CostStep: number,
	RequiredRebirths: number,
	EffectPerLevel: number,
	-- How to show the total effect: "Percent" (+30%), "Flat" (+3) or "Toggle" (On/Off).
	Display: string,
}

local list: { Upgrade } = {
	{
		Id = "TrainingPower",
		Order = 1,
		Name = "Training Power",
		Icon = "💪",
		Description = "More Power every time you train.",
		MaxLevel = 25,
		BaseCost = 1,
		CostStep = 1,
		RequiredRebirths = 0,
		EffectPerLevel = 0.1,
		Display = "Percent",
	},
	{
		Id = "ChargeSpeed",
		Order = 2,
		Name = "Charge Speed",
		Icon = "⚡",
		Description = "Your punch meter charges faster.",
		MaxLevel = 5,
		BaseCost = 1,
		CostStep = 1,
		RequiredRebirths = 1,
		EffectPerLevel = 0.05,
		Display = "Percent",
	},
	{
		Id = "PetEquipSlots",
		Order = 3,
		Name = "Pet Equip Slots",
		Icon = "🐾",
		Description = "Equip more pets at once.",
		MaxLevel = 5,
		BaseCost = 3,
		CostStep = 3,
		RequiredRebirths = 2,
		EffectPerLevel = 1,
		Display = "Flat",
	},
	{
		Id = "EggLuck",
		Order = 4,
		Name = "Egg Luck",
		Icon = "🍀",
		Description = "Better odds of Rare and rarer pets.",
		MaxLevel = 10,
		BaseCost = 2,
		CostStep = 2,
		RequiredRebirths = 3,
		EffectPerLevel = 0.1,
		Display = "Percent",
	},
	{
		Id = "TrainingSpeed",
		Order = 5,
		Name = "Training Speed",
		Icon = "⏱️",
		Description = "Train more often.",
		MaxLevel = 10,
		BaseCost = 2,
		CostStep = 1,
		RequiredRebirths = 1,
		EffectPerLevel = 0.05,
		Display = "Percent",
	},
	{
		Id = "LaunchControl",
		Order = 6,
		Name = "Launch Control",
		Icon = "🎯",
		Description = "Straighter, longer launches.",
		MaxLevel = 10,
		BaseCost = 2,
		CostStep = 2,
		RequiredRebirths = 2,
		EffectPerLevel = 0.02,
		Display = "Percent",
	},
	{
		Id = "AutoTrain",
		Order = 7,
		Name = "Auto Train",
		Icon = "🤖",
		Description = "Train automatically. Toggle it next to the Train button.",
		MaxLevel = 1,
		BaseCost = 5,
		CostStep = 0,
		RequiredRebirths = 3,
		EffectPerLevel = 1,
		Display = "Toggle",
	},
	{
		Id = "WinBonus",
		Order = 8,
		Name = "Win Bonus",
		Icon = "🏆",
		Description = "More Wins from every launch.",
		MaxLevel = 20,
		BaseCost = 2,
		CostStep = 2,
		RequiredRebirths = 1,
		EffectPerLevel = 0.1,
		Display = "Percent",
	},
}

local UpgradesConfig = {
	List = list,
	ById = {} :: { [string]: Upgrade },
}

for _, upgrade in list do
	UpgradesConfig.ById[upgrade.Id] = upgrade
end

function UpgradesConfig.CostForLevel(upgrade: Upgrade, currentLevel: number): number
	return upgrade.BaseCost + upgrade.CostStep * currentLevel
end

return UpgradesConfig
