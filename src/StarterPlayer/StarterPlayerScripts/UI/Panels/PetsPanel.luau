-- Pet inventory: equip, unequip, delete, and equip best.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetsConfig = require(Shared.Config.PetsConfig)
local Formulas = require(Shared.Logic.Formulas)
local Format = require(Shared.Utilities.Format)

local UI = script.Parent.Parent
local Components = require(UI.Components)
local Previews = require(UI.Previews)
local Theme = require(UI.Theme)

local PetsPanel = {}

-- "Gold Fox", "Fox"
function PetsPanel.PetName(speciesId: string, tier: number): string
	local species = PetsConfig.SpeciesById[speciesId]
	local name = if species then species.Name else "Unknown Pet"
	if tier > 1 then
		return `{PetsConfig.Tiers[tier].Name} {name}`
	end
	return name
end

function PetsPanel.Create(ui)
	local panel = Components.Panel(ui.Root, "🐾 Pets", Theme.Colors.Good, ui.Close, 190, 226)

	local summary = Components.Label({
		Size = UDim2.new(0.65, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 20,
		Parent = panel.Info,
	})
	Components.Button({
		Text = "⭐ Equip Best",
		Color = Theme.Colors.Good,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.33, 0, 1, 0),
		MaxTextSize = 20,
		OnClick = function()
			ui.Request("EquipBestPets")
		end,
		Parent = panel.Info,
	})

	local self = { Name = "Pets", Panel = panel }

	function self.Key(data)
		return `{data.NextPetId}|{Formulas.PetCount(data)}|{table.concat(data.EquippedPets, ",")}|{Formulas.PetEquipSlots(data)}`
	end

	function self.Refresh(data)
		local count = Formulas.PetCount(data)
		local bonus = Format.Multiplier(Formulas.EquippedPetMultiplier(data))
		local slots = Formulas.PetEquipSlots(data)
		summary.Text = `{count}/{PetsConfig.InventoryCapacity} pets  •  Equipped {#data.EquippedPets}/{slots}  •  Bonus {bonus}`
		summary.TextColor3 = if count >= PetsConfig.InventoryCapacity then Theme.Colors.Bad else Theme.Colors.Text

		local pets = {}
		for _, pet in data.Pets do
			table.insert(pets, pet)
		end
		local multipliers = {}
		for _, pet in pets do
			multipliers[pet.Id] = Formulas.PetMultiplier(pet.Species, pet.Tier)
		end
		table.sort(pets, function(a, b)
			local aEquipped = table.find(data.EquippedPets, a.Id) ~= nil
			local bEquipped = table.find(data.EquippedPets, b.Id) ~= nil
			if aEquipped ~= bEquipped then
				return aEquipped
			end
			if multipliers[a.Id] ~= multipliers[b.Id] then
				return multipliers[a.Id] > multipliers[b.Id]
			end
			return (tonumber(a.Id) or 0) < (tonumber(b.Id) or 0)
		end)

		Components.Clear(panel.Content)
		if #pets == 0 then
			local card = Components.Card(panel.Content, 1)
			Components.CardLines(card, {
				{ Text = "No pets yet!", Size = 24 },
				{ Text = "Hatch eggs at the 🥚 egg station.", Color = Theme.Colors.SubText },
			})
			return
		end

		for i, pet in pets do
			local species = PetsConfig.SpeciesById[pet.Species]
			local rarity = species and PetsConfig.RaritiesById[species.Rarity]
			local equipped = table.find(data.EquippedPets, pet.Id) ~= nil
			local card = Components.Card(panel.Content, i, if equipped then Theme.Colors.Good else nil)
			Previews.Pet(card, pet.Species, pet.Tier, UDim2.new(1, 0, 0, 84), nil, if rarity then rarity.Color else nil)
			Components.CardLines(Components.Below(card, 88), {
				{ Text = PetsPanel.PetName(pet.Species, pet.Tier), Color = if species then species.Color else nil, Size = 22 },
				{ Text = if rarity then rarity.Id else "?", Color = if rarity then rarity.Color else nil },
				{ Text = `{Format.Multiplier(multipliers[pet.Id])} Power`, Color = Theme.Colors.Power },
				{ Text = if equipped then "✅ Equipped" else "", Color = Theme.Colors.Good, Size = 18 },
			})

			Components.CardButton(card, if equipped then "Unequip" else "Equip", if equipped then Theme.Colors.Neutral else Theme.Colors.Blue, function()
				ui.Request(if equipped then "UnequipPet" else "EquipPet", pet.Id)
			end, 0.6)
			Components.CardButton(card, "🗑", Theme.Colors.Bad, function()
				ui.Confirm(
					"Delete pet?",
					`Delete your {PetsPanel.PetName(pet.Species, pet.Tier)} ({Format.Multiplier(multipliers[pet.Id])})? This can't be undone.`,
					"Delete",
					function()
						ui.Request("DeletePet", pet.Id)
					end
				)
			end, 0.4, 0.6)
		end
	end

	return self
end

return PetsPanel
