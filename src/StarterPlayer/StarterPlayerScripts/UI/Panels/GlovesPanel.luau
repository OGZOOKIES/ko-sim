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

local PREVIEW_HEIGHT = 132
local PREVIEW_FOV = 30
local PREVIEW_ASPECT = 1.5 -- typical card width / preview height

-- A small photo stage for the glove pair: light neutral backdrop, soft key light from the
-- upper left, a contact shadow, and a camera fitted to the pair's real bounding box so no glove
-- is ever clipped. Returns the pair so it can turn gently.
local function preview(card: Frame, gloveId: string): Model
	local viewport = make("ViewportFrame", {
		Size = UDim2.new(1, 0, 0, PREVIEW_HEIGHT),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Ambient = Color3.fromRGB(150, 152, 166),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-0.5, -0.8, 0.6),
		Parent = card,
	})
	Components.Corner(viewport, 10)
	make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(226, 230, 240), Color3.fromRGB(150, 158, 182)),
		Rotation = 90,
		Parent = viewport,
	})

	local pair = GloveBuilder.BuildPair(gloveId)
	pair.Parent = viewport
	local boxCFrame, size = pair:GetBoundingBox()
	local center = boxCFrame.Position

	local shadow = Instance.new("Part")
	shadow.Anchored = true
	shadow.Color = Color3.new(0, 0, 0)
	shadow.Transparency = 0.7
	shadow.Size = Vector3.new(size.X * 0.95, 0.04, size.Z * 1.3)
	shadow.Position = Vector3.new(center.X, center.Y - size.Y / 2 - 0.03, center.Z)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = shadow
	shadow.Parent = viewport

	-- Fit both the height and the width, with a little margin.
	local tanHalf = math.tan(math.rad(PREVIEW_FOV / 2))
	local distance = math.max(size.Y / 2 / tanHalf, size.X / 2 / (tanHalf * PREVIEW_ASPECT)) * 1.18 + size.Z / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = PREVIEW_FOV
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0, size.Y * 0.18, -distance), center)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return pair
end

function GlovesPanel.Create(ui)
	local panel = Components.Panel(ui.Root, "🥊 Glove Shop", Theme.Colors.Power, ui.Close, 210, 290)
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
			local angle = math.sin(os.clock() * 0.7) * 0.3
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

			table.insert(spinning, preview(card, glove.Id))

			local lines = make("Frame", {
				Position = UDim2.fromOffset(0, PREVIEW_HEIGHT + 4),
				Size = UDim2.new(1, 0, 1, -(PREVIEW_HEIGHT + 40)),
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
