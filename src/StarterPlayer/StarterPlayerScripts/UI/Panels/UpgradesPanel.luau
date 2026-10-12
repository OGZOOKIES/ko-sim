-- Token upgrades: level, effect now -> next, cost and requirement for each.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradesConfig = require(Shared.Config.UpgradesConfig)
local Formulas = require(Shared.Logic.Formulas)
local Format = require(Shared.Utilities.Format)

local UI = script.Parent.Parent
local Components = require(UI.Components)
local Theme = require(UI.Theme)

local UpgradesPanel = {}

local function effectText(upgrade, level: number): string
	local effect = level * upgrade.EffectPerLevel
	if upgrade.Display == "Toggle" then
		return if level > 0 then "Owned" else "Not owned"
	elseif upgrade.Display == "Flat" then
		return `+{Format.Number(effect)}`
	end
	return `+{Format.Number(math.floor(effect * 1000 + 0.5) / 10)}%`
end

function UpgradesPanel.Create(ui)
	local panel = Components.Panel(ui.Root, "⬆️ Upgrades", Theme.Colors.Tokens, ui.Close, 230, 176)

	local summary = Components.Label({
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.Tokens,
		MaxTextSize = 20,
		Parent = panel.Info,
	})

	local self = { Name = "Upgrades", Panel = panel }

	function self.Key(data)
		local parts = { tostring(data.RebirthTokens), tostring(data.RebirthCount) }
		for _, upgrade in UpgradesConfig.List do
			table.insert(parts, tostring(Formulas.UpgradeLevel(data, upgrade.Id)))
		end
		return table.concat(parts, "|")
	end

	function self.Refresh(data)
		summary.Text = `🪙 {Format.Number(data.RebirthTokens)} Rebirth Tokens  •  earn 1 per rebirth`

		Components.Clear(panel.Content)
		for _, upgrade in UpgradesConfig.List do
			local level = Formulas.UpgradeLevel(data, upgrade.Id)
			local maxed = level >= upgrade.MaxLevel
			local unlocked = data.RebirthCount >= upgrade.RequiredRebirths
			local cost = UpgradesConfig.CostForLevel(upgrade, level)

			local card = Components.Card(panel.Content, upgrade.Order, if maxed then Theme.Colors.Good else nil)
			Components.CardLines(card, {
				{ Text = `{upgrade.Icon} {upgrade.Name}`, Size = 22 },
				{ Text = upgrade.Description, Color = Theme.Colors.SubText, Size = 18 },
				{ Text = `Level {level}/{upgrade.MaxLevel}`, Color = Theme.Colors.Tokens },
				{
					Text = if maxed
						then effectText(upgrade, level)
						else `{effectText(upgrade, level)} → {effectText(upgrade, level + 1)}`,
					Color = Theme.Colors.Good,
				},
			})

			local text
			if maxed then
				text = "MAX"
			elseif not unlocked then
				text = `Needs {upgrade.RequiredRebirths} rebirths`
			else
				text = `Buy (🪙 {cost})`
			end
			local button = Components.CardButton(card, text, Theme.Colors.Tokens, function()
				ui.Request("BuyUpgrade", upgrade.Id)
			end)
			Components.SetEnabled(button, not maxed and unlocked and data.RebirthTokens >= cost)
		end
	end

	return self
end

return UpgradesPanel
