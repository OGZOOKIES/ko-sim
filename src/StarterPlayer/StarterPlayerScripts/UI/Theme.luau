-- Colours and fonts shared by every piece of UI. Matches the game's art direction:
-- deep midnight navy surfaces, warm gold for prestige, restrained cyan for energy.

local rgb = Color3.fromRGB

local Theme = {
	Font = Enum.Font.FredokaOne,
	BodyFont = Enum.Font.GothamBold,

	Colors = {
		Background = rgb(14, 18, 40),
		Panel = rgb(24, 30, 62),
		Card = rgb(36, 44, 86),
		CardHighlight = rgb(52, 62, 116),
		Text = rgb(255, 255, 255),
		SubText = rgb(178, 190, 226),
		Dark = rgb(8, 10, 24),

		Accent = rgb(255, 196, 64),
		Power = rgb(255, 112, 64),
		Wins = rgb(255, 200, 56),
		Rebirth = rgb(176, 106, 255),
		Tokens = rgb(72, 212, 255),

		Good = rgb(76, 206, 108),
		Bad = rgb(232, 72, 82),
		Neutral = rgb(92, 104, 148),
		Blue = rgb(64, 132, 255),
	},

	Icons = {
		Power = "💪",
		Wins = "🏆",
		Rebirth = "♻️",
		Tokens = "🪙",
	},

	-- Vertical shading applied to buttons, cards and panels for depth.
	Shading = ColorSequence.new(Color3.new(1, 1, 1), rgb(186, 186, 196)),
	SoftShading = ColorSequence.new(Color3.new(1, 1, 1), rgb(214, 214, 224)),
}

-- A darker version of a colour, for borders and pressed states.
function Theme.Darken(color: Color3, amount: number?): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount or 0.35)
end

return Theme
