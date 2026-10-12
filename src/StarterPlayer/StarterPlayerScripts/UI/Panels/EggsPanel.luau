-- Egg station for the current world: odds (including Egg Luck), cost and the Hatch button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EggsConfig = require(Shared.Config.EggsConfig)
local PetsConfig = require(Shared.Config.PetsConfig)
local WorldsConfig = require(Shared.Config.WorldsConfig)
local Formulas = require(Shared.Logic.Formulas)
local PetOdds = require(Shared.Logic.PetOdds)
local Format = require(Shared.Utilities.Format)

local UI = script.Parent.Parent
local Components = require(UI.Components)
local HatchAnimation = require(UI.HatchAnimation)
local Previews = require(UI.Previews)
local Theme = require(UI.Theme)

local EggsPanel = {}

function EggsPanel.Create(ui)
	local panel = Components.Panel(ui.Root, "🥚 Eggs", Theme.Colors.Wins, ui.Close, 170, 196)
	local hatching = false

	local summary = Components.Label({
		Size = UDim2.new(0.6, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 20,
		Parent = panel.Info,
	})

	local self = { Name = "Eggs", Panel = panel }

	local hatchButton
	hatchButton = Components.Button({
		Text = "Hatch",
		Color = Theme.Colors.Wins,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.38, 0, 1, 0),
		MaxTextSize = 22,
		OnClick = function()
			local data = ui.GetData()
			if hatching or not data then
				return
			end
			local egg = EggsConfig.ByWorld[data.CurrentWorld]
			hatching = true
			Components.SetEnabled(hatchButton, false)
			local result = ui.Request("HatchEgg", egg.Id)
			if result.ok and result.pet then
				local accent = WorldsConfig.ById[egg.World].Theme.Accent
				HatchAnimation.Play(ui.Root, accent:Lerp(Color3.new(1, 1, 1), 0.4), result.pet, function()
					hatching = false
					self.Refresh(ui.GetData())
				end)
			else
				hatching = false
				self.Refresh(ui.GetData())
			end
		end,
		Parent = panel.Info,
	})

	function self.Key(data)
		return `{data.Wins}|{data.CurrentWorld}|{Formulas.UpgradeLevel(data, "EggLuck")}|{Formulas.PetCount(data)}|{hatching}`
	end

	function self.Refresh(data)
		local egg = EggsConfig.ByWorld[data.CurrentWorld]
		local count = Formulas.PetCount(data)
		local full = count >= PetsConfig.InventoryCapacity
		summary.Text = `{egg.Name}  •  🏆 {Format.Number(egg.Cost)} Wins  •  🐾 {count}/{PetsConfig.InventoryCapacity}`
		hatchButton.Text = if full then "Inventory full" else `Hatch (🏆 {Format.Number(egg.Cost)})`
		Components.SetEnabled(hatchButton, not hatching and not full and data.Wins >= egg.Cost)

		Components.Clear(panel.Content)
		local luck = Formulas.UpgradeEffect(data, "EggLuck")
		for i, entry in PetOdds.GetOdds(egg.Id, luck) do
			local species = PetsConfig.SpeciesById[entry.SpeciesId]
			local rarity = PetsConfig.RaritiesById[species.Rarity]
			local card = Components.Card(panel.Content, i, rarity.Color)
			Previews.Pet(card, species.Id, 1, UDim2.new(1, 0, 0, 80), nil, rarity.Color)
			Components.CardLines(Components.Below(card, 84), {
				{ Text = species.Name, Color = species.Color, Size = 22 },
				{ Text = rarity.Id, Color = rarity.Color },
				{ Text = `🎲 {Format.Percent(entry.Chance)}` },
				{ Text = `{Format.Multiplier(species.Multiplier)} Power`, Color = Theme.Colors.Power },
			})
		end
	end

	return self
end

return EggsPanel
