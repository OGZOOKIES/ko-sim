-- Worlds: unlock with Wins + rebirths, then travel between unlocked worlds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldsConfig = require(Shared.Config.WorldsConfig)
local Format = require(Shared.Utilities.Format)

local UI = script.Parent.Parent
local Components = require(UI.Components)
local Theme = require(UI.Theme)

local WorldsPanel = {}

function WorldsPanel.Create(ui)
	local panel = Components.Panel(ui.Root, "🌍 Worlds", Theme.Colors.Blue, ui.Close, 250, 176)

	Components.Label({
		Text = "Each world has stronger gloves, pets and bigger rewards. Unlock them in order.",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.SubText,
		MaxTextSize = 18,
		Parent = panel.Info,
	})

	local self = { Name = "Worlds", Panel = panel }

	function self.Key(data)
		local unlocked = {}
		for _, world in WorldsConfig.List do
			if data.UnlockedWorlds[world.Id] then
				table.insert(unlocked, world.Id)
			end
		end
		return `{data.Wins}|{data.RebirthCount}|{data.CurrentWorld}|{table.concat(unlocked, ",")}`
	end

	function self.Refresh(data)
		Components.Clear(panel.Content)
		for _, world in WorldsConfig.List do
			local unlocked = data.UnlockedWorlds[world.Id] == true
			local current = data.CurrentWorld == world.Id
			local previous = WorldsConfig.List[world.Order - 1]
			local previousUnlocked = previous == nil or data.UnlockedWorlds[previous.Id] == true
			local enoughRebirths = data.RebirthCount >= world.RequiredRebirths
			local enoughWins = data.Wins >= world.UnlockCost

			local card = Components.Card(panel.Content, world.Order, if current then Theme.Colors.Good else world.Theme.Accent)
			local requirement = if unlocked
				then "✅ Unlocked"
				else `🏆 {Format.Number(world.UnlockCost)} Wins  •  ♻️ {world.RequiredRebirths} rebirths`
			Components.CardLines(card, {
				{ Text = `{world.Theme.Icon} {world.Name}`, Color = world.Theme.Accent, Size = 24 },
				{ Text = world.Description, Color = Theme.Colors.SubText, Size = 18 },
				{ Text = requirement, Color = if unlocked then Theme.Colors.Good else Theme.Colors.Wins, Size = 18 },
			})

			if current then
				Components.SetEnabled(Components.CardButton(card, "You are here", Theme.Colors.Good, function() end), false)
			elseif unlocked then
				Components.CardButton(card, "Travel", Theme.Colors.Blue, function()
					local result = ui.Request("TravelToWorld", world.Id)
					if result.ok then
						ui.Close()
					end
				end)
			else
				local text = if not previousUnlocked
					then `Unlock {previous.Name} first`
					elseif not enoughRebirths then `Needs {world.RequiredRebirths} rebirths`
					else "Unlock"
				local button = Components.CardButton(card, text, Theme.Colors.Wins, function()
					ui.Request("UnlockWorld", world.Id)
				end)
				Components.SetEnabled(button, previousUnlocked and enoughRebirths and enoughWins)
			end
		end
	end

	return self
end

return WorldsPanel
