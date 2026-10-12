-- Glove shop: tabs for each unlocked world, a card per glove with Buy / Equip.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GlovesConfig = require(Shared.Config.GlovesConfig)
local WorldsConfig = require(Shared.Config.WorldsConfig)
local Format = require(Shared.Utilities.Format)

local UI = script.Parent.Parent
local Components = require(UI.Components)
local Theme = require(UI.Theme)

local GlovesPanel = {}

function GlovesPanel.Create(ui)
	local panel = Components.Panel(ui.Root, "🥊 Glove Shop", Theme.Colors.Power, ui.Close, 210, 168)
	local selectedWorld: string? = nil

	local tabs = Components.Make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = panel.Info,
	})
	Components.Make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabs,
	})

	local self = { Name = "Gloves", Panel = panel }

	function self.Key(data)
		local owned = 0
		for _ in data.OwnedGloves do
			owned += 1
		end
		local unlocked = 0
		for _ in data.UnlockedWorlds do
			unlocked += 1
		end
		return `{data.Wins}|{data.EquippedGlove}|{owned}|{unlocked}|{selectedWorld or data.CurrentWorld}`
	end

	function self.Refresh(data)
		local worldId = selectedWorld or data.CurrentWorld

		Components.Clear(tabs)
		for _, world in WorldsConfig.List do
			if data.UnlockedWorlds[world.Id] then
				Components.Button({
					Text = `{world.Theme.Icon} {world.Name}`,
					Color = if world.Id == worldId then Theme.Colors.Power else Theme.Colors.Neutral,
					Size = UDim2.new(0.19, 0, 1, 0),
					LayoutOrder = world.Order,
					MaxTextSize = 16,
					OnClick = function()
						selectedWorld = world.Id
						self.Refresh(ui.GetData())
					end,
					Parent = tabs,
				})
			end
		end

		Components.Clear(panel.Content)
		for _, glove in GlovesConfig.ByWorld[worldId] do
			local owned = data.OwnedGloves[glove.Id] == true
			local equipped = data.EquippedGlove == glove.Id
			local card = Components.Card(panel.Content, glove.Index, if equipped then Theme.Colors.Good else nil)
			Components.CardLines(card, {
				{ Text = `{glove.Index}. {glove.Name}`, Color = glove.Color, Size = 22 },
				{ Text = `💪 +{Format.Number(glove.Power)} Power per train` },
				{ Text = `🚀 {Format.Multiplier(glove.LaunchBonus)} launch strength`, Color = Theme.Colors.SubText },
				{
					Text = if owned then "✅ Owned" else `🏆 {Format.Number(glove.Cost)} Wins`,
					Color = if owned then Theme.Colors.Good else Theme.Colors.Wins,
				},
			})

			if equipped then
				local button = Components.CardButton(card, "Equipped", Theme.Colors.Good, function() end)
				Components.SetEnabled(button, false)
			elseif owned then
				Components.CardButton(card, "Equip", Theme.Colors.Blue, function()
					ui.Request("EquipGlove", glove.Id)
				end)
			else
				local previous = GlovesConfig.ByWorld[worldId][glove.Index - 1]
				local inOrder = previous == nil or data.OwnedGloves[previous.Id] == true
				local canBuy = inOrder and data.Wins >= glove.Cost
				local button = Components.CardButton(card, if inOrder then "Buy" else "Buy previous first", Theme.Colors.Wins, function()
					ui.Request("BuyGlove", glove.Id)
				end)
				Components.SetEnabled(button, canBuy)
			end
		end
	end

	function self.OnOpen()
		selectedWorld = nil
	end

	return self
end

return GlovesPanel
