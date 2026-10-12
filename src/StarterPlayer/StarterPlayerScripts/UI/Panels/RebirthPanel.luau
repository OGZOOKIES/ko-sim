-- Rebirth: shows the cost, progress, current and next multiplier, and asks before rebirthing.
-- Built once and updated in place, because Power changes many times a second while training.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RebirthConfig = require(Shared.Config.RebirthConfig)
local Formulas = require(Shared.Logic.Formulas)
local Format = require(Shared.Utilities.Format)

local UI = script.Parent.Parent
local Components = require(UI.Components)
local Theme = require(UI.Theme)

local make = Components.Make

local RebirthPanel = {}

function RebirthPanel.Create(ui)
	local panel = Components.Panel(ui.Root, "♻️ Rebirth", Theme.Colors.Rebirth, ui.Close, 2000, 300)

	Components.Label({
		Text = "Rebirthing resets Power to 0. You keep Wins, gloves, pets, upgrades and worlds.",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.SubText,
		MaxTextSize = 18,
		Parent = panel.Info,
	})

	local card = Components.Card(panel.Content, 1, Theme.Colors.Rebirth)

	local function row(y: number, color: Color3?): TextLabel
		return Components.Label({
			Size = UDim2.new(1, 0, 0, 28),
			Position = UDim2.fromOffset(0, y),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color or Theme.Colors.Text,
			MaxTextSize = 24,
			Parent = card,
		})
	end

	local countLabel = row(0)
	local multiplierLabel = row(32, Theme.Colors.Rebirth)
	local tokenLabel = row(64, Theme.Colors.Tokens)
	local costLabel = row(96, Theme.Colors.Power)

	local bar = make("Frame", {
		Position = UDim2.fromOffset(0, 134),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Theme.Colors.Dark,
		Parent = card,
	})
	Components.Corner(bar, 13)
	local fill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Colors.Rebirth,
		Parent = bar,
	})
	Components.Corner(fill, 13)
	local percent = Components.Label({
		Size = UDim2.fromScale(1, 1),
		MaxTextSize = 18,
		ZIndex = 2,
		Parent = bar,
	})

	local rebirthButton = Components.Button({
		Text = "REBIRTH",
		Color = Theme.Colors.Rebirth,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0.6, 0, 0, 56),
		MaxTextSize = 30,
		OnClick = function()
			local data = ui.GetData()
			if not data then
				return
			end
			local current = Format.Multiplier(Formulas.RebirthMultiplier(data.RebirthCount))
			local nextMultiplier = Format.Multiplier(Formulas.RebirthMultiplier(data.RebirthCount + 1))
			ui.Confirm(
				"Rebirth?",
				`Your Power resets to 0. Training multiplier goes from {current} to {nextMultiplier} and you get {RebirthConfig.TokensPerRebirth} Rebirth Token.`,
				"Rebirth!",
				function()
					ui.Request("Rebirth")
				end
			)
		end,
		Parent = card,
	})

	local self = { Name = "Rebirth", Panel = panel }

	-- No Key: refresh on every update (it only changes text).
	function self.Refresh(data)
		local cost = Formulas.RebirthCost(data.RebirthCount)
		local progress = math.clamp(data.Power / cost, 0, 1)
		countLabel.Text = `♻️ Rebirths: {Format.Number(data.RebirthCount)}`
		local current = Format.Multiplier(Formulas.RebirthMultiplier(data.RebirthCount))
		local nextMultiplier = Format.Multiplier(Formulas.RebirthMultiplier(data.RebirthCount + 1))
		multiplierLabel.Text = `💪 Training multiplier: {current} → {nextMultiplier}`
		tokenLabel.Text = `🪙 Tokens: {Format.Number(data.RebirthTokens)}  (+{RebirthConfig.TokensPerRebirth} per rebirth)`
		costLabel.Text = `Cost: {Format.Number(cost)} Power  (you have {Format.Number(data.Power)})`
		fill.Size = UDim2.fromScale(progress, 1)
		percent.Text = `{math.floor(progress * 100)}%`
		Components.SetEnabled(rebirthButton, data.Power >= cost)
	end

	return self
end

return RebirthPanel
