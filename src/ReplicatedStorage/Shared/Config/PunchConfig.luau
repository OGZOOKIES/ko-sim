-- How the punch looks and sounds. Gameplay timing lives in LaunchConfig.
--
-- Animations: leave these empty to use the built-in procedural punch, which works on R15 and R6
-- with no uploads. To use your own animations, upload them (Avatar > Animation Editor > Publish)
-- and paste the ids here, e.g. "rbxassetid://1234567890".
--   WindUp  looped pose while charging
--   Punch   the strike. Add a KeyframeMarker named "Impact" where the fist connects.
--
-- Sounds: Roblox's built-in sounds so nothing needs uploading. Swap in your own ids any time.

local PunchConfig = {
	Animations = {
		WindUp = "",
		Punch = "",
	},

	Sounds = {
		Whoosh = "rbxasset://sounds/swordlunge.wav",
		Impact = "rbxasset://sounds/swordhit.wav",
		Ragdoll = "rbxasset://sounds/uuhhh.mp3",
	},

	-- Procedural punch timing (seconds)
	PunchDuration = 0.42, -- whole strike including recovery
	ExtendTime = 0.12, -- fist reaches the target (matches LaunchConfig.ImpactDelay)

	-- Effects are scaled by glove tier between these (1 = Starter Mitts, 50 = Cosmic Annihilators).
	MinIntensity = 0.7,
	MaxIntensity = 1.4,
}

return table.freeze(PunchConfig)
