-- Punching bags: pick which one you train with. Better bags unlock with rebirths.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BagsConfig = require(Shared.Config.BagsConfig)
local Format = require(Shared.Utilities.Format)

local UI = script.Parent.Parent
local Components = require(UI.Components)
local Theme = require(UI.Theme)

local RED = Color3.fromRGB(230, 90, 90)

local BagsPanel = {}

function BagsPanel.Create(ui)
	local panel = Components.Panel(ui.Root, "🏋️ Punching Bags", RED, ui.Close, 200, 140)

	Components.Label({
		Text = "Bags multiply the Power you get from training. Rebirth to unlock better ones.",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.SubText,
		MaxTextSize = 18,
		Parent = panel.Info,
	})

	local self = { Name = "Bags", Panel = panel }

	function self.Key(data)
		return `{data.RebirthCount}|{data.SelectedBag}`
	end

	function self.Refresh(data)
		Components.Clear(panel.Content)
		for _, bag in BagsConfig.List do
			local selected = data.SelectedBag == bag.Id
			local unlocked = data.RebirthCount >= bag.RequiredRebirths
			local card = Components.Card(panel.Content, bag.Order, if selected then Theme.Colors.Good else nil)
			Components.CardLines(card, {
				{ Text = bag.Name, Color = bag.Color:Lerp(Color3.new(1, 1, 1), 0.3), Size = 22 },
				{ Text = `💪 {Format.Multiplier(bag.Multiplier)} training Power`, Color = Theme.Colors.Power },
				{
					Text = if bag.RequiredRebirths > 0 then `♻️ {bag.RequiredRebirths} rebirths` else "Free",
					Color = if unlocked then Theme.Colors.SubText else Theme.Colors.Bad,
				},
			})
			if selected then
				Components.SetEnabled(Components.CardButton(card, "In use", Theme.Colors.Good, function() end), false)
			else
				local button = Components.CardButton(card, if unlocked then "Use" else "Locked", Theme.Colors.Blue, function()
					ui.Request("SelectBag", bag.Id)
				end)
				Components.SetEnabled(button, unlocked)
			end
		end
	end

	return self
end

return BagsPanel
