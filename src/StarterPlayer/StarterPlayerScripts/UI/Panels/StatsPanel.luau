-- Stats: every multiplier that affects you, straight from Formulas.Breakdown, so what you see is
-- exactly what the server uses. Built once and updated in place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Logic.Formulas)
local Format = require(Shared.Utilities.Format)

local UI = script.Parent.Parent
local Components = require(UI.Components)
local Theme = require(UI.Theme)

local SECTIONS = {
	{ Key = "Training", Title = "💪 Training", Color = Theme.Colors.Power },
	{ Key = "Launch", Title = "🚀 Punch & distance", Color = Theme.Colors.Tokens },
	{ Key = "Rewards", Title = "🏆 Rewards & pets", Color = Theme.Colors.Wins },
}

local ROW_HEIGHT = 26

local StatsPanel = {}

local function formatValue(value: number, kind: string): string
	if kind == "Multiplier" then
		return Format.Multiplier(value)
	end
	return Format.Number(value)
end

function StatsPanel.Create(ui)
	local panel = Components.Panel(ui.Root, "📊 Stats", Theme.Colors.Blue, ui.Close, 260, 230)

	Components.Label({
		Text = "Each multiplier only boosts one thing. Rebirths and pets raise your Power, and Power drives your punch.",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.SubText,
		MaxTextSize = 17,
		Parent = panel.Info,
	})

	local rows: { [string]: { { Label: TextLabel, Value: TextLabel } } } = {}
	for order, section in SECTIONS do
		local card = Components.Card(panel.Content, order, section.Color)
		Components.Label({
			Text = section.Title,
			TextColor3 = section.Color,
			Size = UDim2.new(1, 0, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 24,
			Parent = card,
		})
		rows[section.Key] = {}
		for i = 1, 6 do
			local y = 30 + (i - 1) * ROW_HEIGHT
			local label = Components.Label({
				Text = "",
				Font = Theme.BodyFont,
				Position = UDim2.fromOffset(0, y),
				Size = UDim2.new(0.66, 0, 0, ROW_HEIGHT - 4),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Theme.Colors.SubText,
				MaxTextSize = 16,
				Parent = card,
			})
			local value = Components.Label({
				Text = "",
				Position = UDim2.new(0.66, 0, 0, y),
				Size = UDim2.new(0.34, 0, 0, ROW_HEIGHT - 4),
				TextXAlignment = Enum.TextXAlignment.Right,
				MaxTextSize = 19,
				Parent = card,
			})
			table.insert(rows[section.Key], { Label = label, Value = value })
		end
	end

	local self = { Name = "Stats", Panel = panel }

	-- No Key: values change constantly while training, and updating text is cheap.
	function self.Refresh(data)
		local breakdown = Formulas.Breakdown(data, data.CurrentWorld)
		for _, section in SECTIONS do
			local lines = breakdown[section.Key]
			for i, row in rows[section.Key] do
				local line = lines[i]
				row.Label.Visible = line ~= nil
				row.Value.Visible = line ~= nil
				if line then
					local total = line.Kind == "Total"
					row.Label.Text = if total then `= {line.Label}` else line.Label
					row.Label.TextColor3 = if total then section.Color else Theme.Colors.SubText
					local text = formatValue(line.Value, line.Kind)
					row.Value.Text = if line.Label == "Full-charge distance here" then `{text} studs` else text
					row.Value.TextColor3 = if total then section.Color else Theme.Colors.Text
				end
			end
		end
	end

	return self
end

return StatsPanel
