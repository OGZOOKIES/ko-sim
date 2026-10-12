--!strict
-- Rebirth: spend Power to reset it to 0 for a permanent multiplier and a Rebirth Token.
--
--   Cost(n)        = floor(BaseCost * CostGrowth ^ n)   where n = rebirths already done
--   Multiplier(n)  = 1 + n * MultiplierPerRebirth        (applies to Power gained from training)
--
-- Rebirth count, token balance and multiplier are separate: spending tokens never lowers the others.
-- Rebirthing keeps Wins, gloves, pets, upgrades, unlocked worlds and personal bests.

local RebirthConfig = {
	BaseCost = 2500,
	CostGrowth = 1.75,
	MultiplierPerRebirth = 0.2,
	TokensPerRebirth = 1,
}

return table.freeze(RebirthConfig)
