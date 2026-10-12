--!strict
-- Tuning for the punch-and-launch mechanic.

local LaunchConfig = {
	-- Charge meter: rises 0 -> 1 over ChargeCycle seconds, then falls back, and repeats.
	ChargeCycle = 1.3,
	-- Releasing at or above this charge is a "Perfect" punch.
	SweetSpotMin = 0.88,
	TimingBonus = 1.25,
	-- Releasing at 0 charge still gives this fraction of full distance.
	MinChargeFactor = 0.4,
	-- Server releases the punch automatically after this many seconds.
	MaxChargeTime = 8,

	-- Launch angle above the runway, plus random spread (Launch Control reduces spread).
	AngleDegrees = 32,
	AngleSpreadDegrees = 5,
	SideSpreadDegrees = 3,
	SpreadReductionPerLevel = 0.08,

	-- The ragdoll's flight covers this fraction of the target distance; tumbling covers the rest.
	FlightRangeFactor = 0.85,
	MinDistance = 3,

	-- When a launch is over
	MinFlightTime = 0.6, -- seconds before settling is checked
	SettleSpeed = 4, -- studs/second
	SettleTime = 0.8, -- seconds below SettleSpeed
	MaxFlightTime = 14, -- hard limit
	OutOfBoundsDrop = 25, -- studs below the runway
	OutOfBoundsSide = 12, -- studs past the runway's edge

	-- Station
	StationRange = 30, -- how close you must be to punch
	Cooldown = 1.5, -- seconds after a launch ends
	RagdollCleanupDelay = 1.5,
}

return table.freeze(LaunchConfig)
