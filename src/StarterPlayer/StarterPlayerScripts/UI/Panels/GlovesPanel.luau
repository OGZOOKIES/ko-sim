-- Glove shop: a tab per unlocked world and a card per glove with a live 3D preview of the pair,
-- built by the same GloveBuilder that puts gloves on characters.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GlovesConfig = require(Shared.Config.GlovesConfig)
local WorldsConfig = require(Shared.Config.WorldsConfig)
local GloveBuilder = require(Shared.Gloves.GloveBuilder)
local Format = require(Shared.Utilities.Format)

local UI = script.Parent.Parent
local Components = require(UI.Components)
local Theme = require(UI.Theme)

local make = Components.Make

local GlovesPanel = {}

local CAMERA_CFRAME = CFrame.lookAt(Vector3.new(0.4, 0.35, -4.6), Vector3.new(0, -0.25, 0))

-- A small 3D stage with the glove pair. Returns the model so it can be turned slowly.
local function preview(card: Frame, gloveId: string, owned: boolean): Model
	local viewport = make("ViewportFrame", {
		Size = UDim2.new(1, 0, 0, 104),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.2,
		Ambient = Color3.fromRGB(150, 150, 165),
		LightColor = Color3.fromRGB(255, 245, 230),
		LightDirection = Vector3.new(-0.6, -1, 0.8),
		ImageTransparency = if owned then 0 else 0.05,
		Parent = card,
	})
	Components.Corner(viewport, 10)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 38
	camera.CFrame = CAMERA_CFRAME
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local pair = GloveBuilder.BuildPair(gloveId)
	pair.Parent = viewport
	return pair
end

function GlovesPanel.Create(ui)
	local panel = Components.Panel(ui.Root, "🥊 Glove Shop", Theme.Colors.Power, ui.Close, 210, 262)
	local selectedWorld: string? = nil
	local spinning: { Model } = {}
	local spinConnection: RBXScriptConnection? = nil

	local tabs = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = panel.Info,
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabs,
	})

	local self = { Name = "Gloves", Panel = panel }

	-- Gently turn the previews while the shop is open.
	local function startSpinning()
		if spinConnection then
			return
		end
		spinConnection = RunService.RenderStepped:Connect(function()
			if not panel.Frame.Visible then
				return
			end
			local angle = math.sin(os.clock() * 0.8) * 0.35
			for _, pair in spinning do
				if pair.Parent then
					pair:PivotTo(CFrame.Angles(0, angle, 0))
				end
			end
		end)
	end

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
		table.clear(spinning)
		for _, glove in GlovesConfig.ByWorld[worldId] do
			local owned = data.OwnedGloves[glove.Id] == true
			local equipped = data.EquippedGlove == glove.Id
			local design = GloveBuilder.GetDesign(glove.Id)
			local card = Components.Card(panel.Content, glove.Index, if equipped then Theme.Colors.Good else nil)

			table.insert(spinning, preview(card, glove.Id, owned))

			local lines = make("Frame", {
				Position = UDim2.fromOffset(0, 108),
				Size = UDim2.new(1, 0, 1, -144),
				BackgroundTransparency = 1,
				Parent = card,
			})
			Components.CardLines(lines, {
				{ Text = `{glove.Index}. {glove.Name}`, Color = design.Colors.Trim:Lerp(Color3.new(1, 1, 1), 0.45), Size = 22 },
				{ Text = design.Feature, Color = Theme.Colors.SubText, Size = 16 },
				{ Text = `💪 +{Format.Number(glove.Power)} Power per train`, Size = 18 },
				{ Text = `🚀 {Format.Multiplier(glove.LaunchForce)} punch force`, Color = Theme.Colors.Tokens, Size = 18 },
				{
					Text = if owned then "✅ Owned" else `🏆 {Format.Number(glove.Cost)} Wins`,
					Color = if owned then Theme.Colors.Good else Theme.Colors.Wins,
					Size = 18,
				},
			})

			if equipped then
				Components.SetEnabled(Components.CardButton(card, "Equipped", Theme.Colors.Good, function() end), false)
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
		startSpinning()
	end

	function self.OnOpen()
		selectedWorld = nil
	end

	return self
end

return GlovesPanel
