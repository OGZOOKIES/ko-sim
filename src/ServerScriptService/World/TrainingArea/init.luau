-- Builds the Training Grounds for one world: pavilion, bags, plaza and progression board.
--
-- Safe to call again: an existing TrainingArea under `parent` is removed first, so rebuilding
-- never leaves duplicates. Only this generated model is touched.
--
-- Visual settings live in Shared/Config/TrainingAreaConfig. Bag rules (multipliers, rebirth
-- requirements) stay in BagsConfig and are checked by the server in Economy.SelectBag.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrainingAreaConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.TrainingAreaConfig)
local Bags = require(script.Bags)
local Pavilion = require(script.Pavilion)
local Plaza = require(script.Plaza)
local ProgressBoard = require(script.ProgressBoard)

local TrainingArea = {}

function TrainingArea.Build(parent: Instance, origin: Vector3, world): Model
	local existing = parent:FindFirstChild("TrainingArea")
	if existing then
		existing:Destroy()
	end

	local center = origin + TrainingAreaConfig.Layout.Center
	local model = Instance.new("Model")
	model.Name = "TrainingArea"
	model:SetAttribute("WorldId", world.Id)
	model:SetAttribute("Center", center)

	Pavilion.Build(model, center)
	Bags.Build(model, center, world.Id)
	Plaza.Build(model, origin, world.Theme, world.Order * 77, world.Id)
	ProgressBoard.Build(model, origin + TrainingAreaConfig.Layout.BoardPosition, world.Id)

	model.Parent = parent
	return model
end

return TrainingArea
