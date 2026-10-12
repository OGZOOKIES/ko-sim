-- An in-world board showing the six bags from Basic to Cosmic. The server draws the fixed text;
-- each client fills in "Your rebirths" and the per-bag status (In use / Unlocked / Next / Locked).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BagsConfig = require(Shared.Config.BagsConfig)
local TrainingAreaConfig = require(Shared.Config.TrainingAreaConfig)
local Format = require(Shared.Utilities.Format)
local Parts = require(script.Parent.Parent.Parts)

local P = TrainingAreaConfig.Palette

local ProgressBoard = {}

local function text(parent: Instance, name: string, value: string, color: Color3, y: number, height: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.05, y)
	label.Size = UDim2.fromScale(0.9, height)
	label.Font = Enum.Font.FredokaOne
	label.Text = value
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Parent = parent
	return label
end

-- `position` is the point on the ground under the middle of the board. Faces -Z.
function ProgressBoard.Build(parent: Instance, position: Vector3, worldId: string)
	local model = Instance.new("Model")
	model.Name = "ProgressBoard"
	model.Parent = parent

	for _, x in { -11.5, 11.5 } do
		Parts.Part(model, { Name = "Post", Size = Vector3.new(1, 11, 1), Position = position + Vector3.new(x, 5.5, 0.3), Color = P.Navy, Material = Enum.Material.SmoothPlastic })
		Parts.Decor(model, { Name = "PostCap", Size = Vector3.new(1.4, 0.4, 1.4), Position = position + Vector3.new(x, 11.2, 0.3), Color = P.Gold, Material = Enum.Material.Foil })
	end
	Parts.Decor(model, { Name = "Frame", Size = Vector3.new(25, 10.4, 0.4), Position = position + Vector3.new(0, 6.2, 0.1), Color = P.Gold, Material = Enum.Material.Foil })
	Parts.Decor(model, { Name = "Header", Size = Vector3.new(26, 0.6, 1.8), Position = position + Vector3.new(0, 11.6, 0.1), Color = P.Navy, Material = Enum.Material.SmoothPlastic })
	Parts.Decor(model, { Name = "HeaderTrim", Size = Vector3.new(26.2, 0.15, 1.9), Position = position + Vector3.new(0, 11.3, 0.1), Color = P.Cyan, Material = Enum.Material.Neon })
	local board = Parts.Decor(model, { Name = "Board", Size = Vector3.new(24, 9.6, 0.3), Position = position + Vector3.new(0, 6.2, -0.2), Color = P.DeepNavy })

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui:SetAttribute("WorldId", worldId)
	gui.Parent = board

	text(gui, "Title", "🏋️ BAG PROGRESSION", P.Gold, 0.03, 0.15)
	text(gui, "Rebirths", "Rebirth to unlock stronger bags", Color3.new(1, 1, 1), 0.18, 0.09)

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromScale(0.03, 0.31)
	row.Size = UDim2.fromScale(0.94, 0.65)
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0.012, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	for _, bag in BagsConfig.List do
		local visual = TrainingAreaConfig.Bags[bag.Id]
		local cell = Instance.new("Frame")
		cell.Name = bag.Id
		cell.LayoutOrder = bag.Order
		cell.Size = UDim2.fromScale(0.156, 1)
		cell.BackgroundColor3 = visual.Mat:Lerp(P.DeepNavy, 0.55)
		cell.Parent = row
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.1, 0)
		corner.Parent = cell
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Stroke"
		stroke.Color = visual.Mat
		stroke.Thickness = 3
		stroke.Parent = cell

		text(cell, "Name", (string.gsub(bag.Name, " Bag", "")),visual.Mat:Lerp(Color3.new(1, 1, 1), 0.4), 0.05, 0.22)
		text(cell, "Multiplier", Format.Multiplier(bag.Multiplier), P.Gold, 0.3, 0.2)
		text(cell, "Requirement", if bag.RequiredRebirths > 0 then `{bag.RequiredRebirths} Rebirths` else "Free", Color3.fromRGB(200, 210, 235), 0.53, 0.15)
		text(cell, "Status", if bag.RequiredRebirths > 0 then "🔒" else "✅", Color3.new(1, 1, 1), 0.72, 0.2)
	end

	CollectionService:AddTag(gui, TrainingAreaConfig.Tags.Board)
end

return ProgressBoard
