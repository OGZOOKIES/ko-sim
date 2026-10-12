-- Pet Upgrader: lists every species + tier you own, how many of the 5 you have,
-- and what you'd get. Upgrading asks for confirmation first.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetsConfig = require(Shared.Config.PetsConfig)
local Formulas = require(Shared.Logic.Formulas)
local Format = require(Shared.Utilities.Format)

local UI = script.Parent.Parent
local Components = require(UI.Components)
local Previews = require(UI.Previews)
local Theme = require(UI.Theme)
local PetsPanel = require(script.Parent.PetsPanel)

local PURPLE = Color3.fromRGB(255, 120, 200)

local FusePanel = {}

function FusePanel.Create(ui)
	local panel = Components.Panel(ui.Root, "✨ Pet Upgrader", PURPLE, ui.Close, 220, 236)

	Components.Label({
		Text = `{PetsConfig.FuseCount} identical pets → 1 upgraded pet.  Gold x2  •  Diamond x3  •  Rainbow x4 (of the base)`,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.SubText,
		MaxTextSize = 18,
		Parent = panel.Info,
	})

	local self = { Name = "Fuse", Panel = panel }

	function self.Key(data)
		return `{data.NextPetId}|{Formulas.PetCount(data)}`
	end

	function self.Refresh(data)
		-- Group by species and tier.
		local groups = {}
		local byKey = {}
		for _, pet in data.Pets do
			if pet.Tier < #PetsConfig.Tiers and PetsConfig.SpeciesById[pet.Species] then
				local key = `{pet.Species}:{pet.Tier}`
				local group = byKey[key]
				if not group then
					group = { Species = pet.Species, Tier = pet.Tier, Count = 0 }
					byKey[key] = group
					table.insert(groups, group)
				end
				group.Count += 1
			end
		end
		table.sort(groups, function(a, b)
			local aReady = a.Count >= PetsConfig.FuseCount
			local bReady = b.Count >= PetsConfig.FuseCount
			if aReady ~= bReady then
				return aReady
			end
			return Formulas.PetMultiplier(a.Species, a.Tier) > Formulas.PetMultiplier(b.Species, b.Tier)
		end)

		Components.Clear(panel.Content)
		if #groups == 0 then
			local card = Components.Card(panel.Content, 1)
			Components.CardLines(card, {
				{ Text = "Nothing to upgrade yet", Size = 22 },
				{ Text = "Hatch duplicate pets, then come back.", Color = Theme.Colors.SubText },
			})
			return
		end

		for i, group in groups do
			local ready = group.Count >= PetsConfig.FuseCount
			local fromName = PetsPanel.PetName(group.Species, group.Tier)
			local toName = PetsPanel.PetName(group.Species, group.Tier + 1)
			local fromMultiplier = Format.Multiplier(Formulas.PetMultiplier(group.Species, group.Tier))
			local toMultiplier = Format.Multiplier(Formulas.PetMultiplier(group.Species, group.Tier + 1))

			local card = Components.Card(panel.Content, i, if ready then PURPLE else nil)
			Previews.Pet(card, group.Species, math.min(group.Tier + 1, #PetsConfig.Tiers), UDim2.new(1, 0, 0, 74))
			Components.CardLines(Components.Below(card, 78), {
				{ Text = `{fromName} ({fromMultiplier})`, Color = PetsConfig.SpeciesById[group.Species].Color, Size = 20 },
				{
					Text = `Owned: {group.Count}/{PetsConfig.FuseCount}`,
					Color = if ready then Theme.Colors.Good else Theme.Colors.SubText,
				},
				{ Text = `→ {toName}`, Color = PURPLE },
				{ Text = `→ {toMultiplier} Power`, Color = Theme.Colors.Power },
			})
			local button = Components.CardButton(card, "Upgrade", PURPLE, function()
				ui.Confirm(
					"Upgrade pets?",
					`Combine {PetsConfig.FuseCount} {fromName} ({fromMultiplier}) into 1 {toName} ({toMultiplier})?`,
					"Upgrade",
					function()
						ui.Request("UpgradePet", group.Species, group.Tier)
					end
				)
			end)
			Components.SetEnabled(button, ready)
		end
	end

	return self
end

return FusePanel
