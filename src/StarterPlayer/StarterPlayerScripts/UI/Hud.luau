-- The always-visible HUD: currency pills, world name, menu buttons, train button and status line.
-- Hud.Create returns the elements so controllers can hook into them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BagsConfig = require(Shared.Config.BagsConfig)
local GlovesConfig = require(Shared.Config.GlovesConfig)
local WorldsConfig = require(Shared.Config.WorldsConfig)
local Formulas = require(Shared.Logic.Formulas)
local Format = require(Shared.Utilities.Format)

local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)

local make = Components.Make

local Hud = {}

export type HudElements = {
	Root: Frame,
	Values: { [string]: TextLabel },
	WorldLabel: TextLabel,
	StatusLabel: TextLabel,
	TrainButton: TextButton,
	AutoButton: TextButton,
	LaunchLabel: TextLabel,
	BottomArea: Frame,
	Update: (data: { [string]: any }) -> (),
}

local MENU = {
	{ Panel = "Gloves", Text = "🥊 Gloves", Color = Theme.Colors.Power },
	{ Panel = "Pets", Text = "🐾 Pets", Color = Theme.Colors.Good },
	{ Panel = "Eggs", Text = "🥚 Eggs", Color = Theme.Colors.Wins },
	{ Panel = "Fuse", Text = "✨ Fuse", Color = Color3.fromRGB(255, 120, 200) },
	{ Panel = "Bags", Text = "🏋️ Bags", Color = Color3.fromRGB(230, 90, 90) },
	{ Panel = "Rebirth", Text = "♻️ Rebirth", Color = Theme.Colors.Rebirth },
	{ Panel = "Upgrades", Text = "⬆️ Upgrades", Color = Theme.Colors.Tokens },
	{ Panel = "Worlds", Text = "🌍 Worlds", Color = Theme.Colors.Blue },
	{ Panel = "Stats", Text = "📊 Stats", Color = Color3.fromRGB(90, 110, 170) },
}

local function pill(parent: Instance, order: number, icon: string, color: Color3): TextLabel
	local frame = make("Frame", {
		Size = UDim2.fromScale(0.24, 1),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.15,
		LayoutOrder = order,
		Parent = parent,
	})
	make("UISizeConstraint", { MinSize = Vector2.new(84, 30), MaxSize = Vector2.new(190, 46), Parent = frame })
	Components.Corner(frame, 20)
	Components.Stroke(frame, color, 2)
	Components.Label({
		Text = icon,
		Size = UDim2.new(0, 30, 1, -6),
		Position = UDim2.fromOffset(6, 3),
		MaxTextSize = 24,
		Parent = frame,
	})
	return Components.Label({
		Text = "0",
		TextColor3 = color,
		Size = UDim2.new(1, -44, 1, -8),
		Position = UDim2.fromOffset(38, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 26,
		Parent = frame,
	})
end

function Hud.Create(root: Instance, openPanel: (string) -> ()): HudElements
	local hud = make("Frame", {
		Name = "Hud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = root,
	})

	-- Currency pills, top center.
	local top = make("Frame", {
		Name = "Stats",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.new(0.62, 0, 0, 42),
		BackgroundTransparency = 1,
		Parent = hud,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = top,
	})
	local values = {
		Power = pill(top, 1, Theme.Icons.Power, Theme.Colors.Power),
		Wins = pill(top, 2, Theme.Icons.Wins, Theme.Colors.Wins),
		Rebirths = pill(top, 3, Theme.Icons.Rebirth, Theme.Colors.Rebirth),
		Tokens = pill(top, 4, Theme.Icons.Tokens, Theme.Colors.Tokens),
	}

	-- Launch readout, below the pills (LaunchController fills it in during a launch).
	local launchLabel = Components.Label({
		Name = "LaunchReadout",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.new(0.7, 0, 0, 44),
		TextColor3 = Theme.Colors.Wins,
		TextStrokeTransparency = 0,
		MaxTextSize = 36,
		Visible = false,
		Parent = hud,
	})

	-- World name, top left under Roblox's buttons.
	local worldLabel = Components.Label({
		Text = "",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(0.18, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = hud,
	})

	-- Menu, left side: two columns of square buttons.
	local menu = make("Frame", {
		Name = "Menu",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.45, 0),
		Size = UDim2.fromScale(0.3, 0.58),
		BackgroundTransparency = 1,
		Parent = hud,
	})
	make("UIAspectRatioConstraint", { AspectRatio = 0.4, DominantAxis = Enum.DominantAxis.Height, Parent = menu })
	make("UISizeConstraint", { MaxSize = Vector2.new(190, 475), Parent = menu })
	make("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0.2, -6),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	for i, item in MENU do
		Components.Button({
			Name = item.Panel,
			Text = item.Text,
			Color = item.Color,
			LayoutOrder = i,
			MaxTextSize = 18,
			OnClick = function()
				openPanel(item.Panel)
			end,
			Parent = menu,
		})
	end

	-- Bottom center: status line, train button, auto toggle.
	local bottom = make("Frame", {
		Name = "Bottom",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(0.5, 0, 0, 118),
		BackgroundTransparency = 1,
		Parent = hud,
	})
	make("UISizeConstraint", { MinSize = Vector2.new(260, 118), MaxSize = Vector2.new(560, 118), Parent = bottom })

	local status = Components.Label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 22),
		TextColor3 = Theme.Colors.SubText,
		MaxTextSize = 18,
		Parent = bottom,
	})

	local trainButton = Components.Button({
		Name = "Train",
		Text = "💪 TRAIN",
		Color = Theme.Colors.Power,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(0.55, 0, 0, 80),
		MaxTextSize = 34,
		CornerRadius = 18,
		Parent = bottom,
	})

	local autoButton = Components.Button({
		Name = "AutoTrain",
		Text = "AUTO: OFF",
		Color = Theme.Colors.Neutral,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0.79, 0, 1, -18),
		Size = UDim2.new(0.21, 0, 0, 44),
		MaxTextSize = 18,
		Visible = false,
		Parent = bottom,
	})

	local function update(data)
		values.Power.Text = Format.Number(data.Power)
		values.Wins.Text = Format.Number(data.Wins)
		values.Rebirths.Text = Format.Number(data.RebirthCount)
		values.Tokens.Text = Format.Number(data.RebirthTokens)

		local world = WorldsConfig.ById[data.CurrentWorld]
		worldLabel.Text = if world then `{world.Theme.Icon} {world.Name}` else ""

		local glove = GlovesConfig.ById[data.EquippedGlove]
		local bag = BagsConfig.ById[data.SelectedBag]
		status.Text = string.format(
			"🥊 %s  •  🐾 %d/%d %s  •  🏋️ %s",
			if glove then glove.Name else "?",
			#data.EquippedPets,
			Formulas.PetEquipSlots(data),
			Format.Multiplier(Formulas.EquippedPetMultiplier(data)),
			if bag then bag.Name else "?"
		)
		trainButton.Text = `💪 TRAIN  +{Format.Number(Formulas.TrainingGain(data))}`

		local hasAuto = Formulas.UpgradeLevel(data, "AutoTrain") >= 1
		autoButton.Visible = hasAuto
		autoButton.Text = if data.Settings.AutoTrain then "AUTO: ON" else "AUTO: OFF"
		Components.SetColor(autoButton, if data.Settings.AutoTrain then Theme.Colors.Good else Theme.Colors.Neutral)
	end

	return {
		Root = hud,
		Values = values,
		WorldLabel = worldLabel,
		StatusLabel = status,
		TrainButton = trainButton,
		AutoButton = autoButton,
		LaunchLabel = launchLabel,
		BottomArea = bottom,
		Update = update,
	}
end

return Hud
