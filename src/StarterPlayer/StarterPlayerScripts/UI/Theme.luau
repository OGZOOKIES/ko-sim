-- Colours and fonts shared by every piece of UI.

local rgb = Color3.fromRGB

local Theme = {
	Font = Enum.Font.FredokaOne,
	BodyFont = Enum.Font.GothamBold,

	Colors = {
		Background = rgb(28, 30, 48),
		Panel = rgb(40, 44, 70),
		Card = rgb(56, 61, 96),
		CardHighlight = rgb(72, 80, 130),
		Text = rgb(255, 255, 255),
		SubText = rgb(190, 200, 230),
		Dark = rgb(15, 15, 25),

		Accent = rgb(255, 190, 40),
		Power = rgb(255, 110, 60),
		Wins = rgb(255, 205, 50),
		Rebirth = rgb(180, 100, 255),
		Tokens = rgb(70, 210, 255),

		Good = rgb(80, 210, 100),
		Bad = rgb(235, 75, 75),
		Neutral = rgb(110, 120, 160),
		Blue = rgb(60, 140, 255),
	},

	Icons = {
		Power = "💪",
		Wins = "🏆",
		Rebirth = "♻️",
		Tokens = "🪙",
	},
}

-- A darker version of a colour, for borders and pressed states.
function Theme.Darken(color: Color3, amount: number?): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount or 0.35)
end

return Theme
