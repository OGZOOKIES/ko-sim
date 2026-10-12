-- Glove shop: buying and equipping gloves, and showing the equipped glove on the character.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GlovesConfig = require(Shared.Config.GlovesConfig)
local Economy = require(ServerScriptService.Logic.Economy)
local Net = require(ServerScriptService.Net)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local ShopService = {}

-- Hand part names for R15 and R6 characters, with where the glove sits on each.
local HANDS = {
	{ Name = "RightHand", Offset = CFrame.new(), Size = 1.25 },
	{ Name = "LeftHand", Offset = CFrame.new(), Size = 1.25 },
	{ Name = "Right Arm", Offset = CFrame.new(0, -0.9, 0), Size = 1.4 },
	{ Name = "Left Arm", Offset = CFrame.new(0, -0.9, 0), Size = 1.4 },
}

local function applyGloveVisual(player: Player)
	local character = player.Character
	local data = PlayerDataService.Get(player)
	if not character or not data then
		return
	end
	local glove = GlovesConfig.ById[data.EquippedGlove]
	if not glove then
		return
	end

	for _, child in character:GetChildren() do
		if child.Name == "GloveVisual" then
			child:Destroy()
		end
	end

	for _, hand in HANDS do
		local handPart = character:FindFirstChild(hand.Name)
		if handPart and handPart:IsA("BasePart") then
			local visual = Instance.new("Part")
			visual.Name = "GloveVisual"
			visual.Shape = Enum.PartType.Ball
			visual.Size = Vector3.new(hand.Size, hand.Size, hand.Size)
			visual.Color = glove.Color
			visual.Material = if glove.Index >= 8 then Enum.Material.Neon else Enum.Material.SmoothPlastic
			visual.CanCollide = false
			visual.CanQuery = false
			visual.CanTouch = false
			visual.Massless = true
			visual.CFrame = handPart.CFrame * hand.Offset
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handPart
			weld.Part1 = visual
			weld.Parent = visual
			visual.Parent = character
		end
	end
end

function ShopService.Init()
	Net.Handle("BuyGlove", function(player, gloveId)
		local data = PlayerDataService.Get(player)
		if not data then
			return Net.NotLoaded
		end
		local ok, message = Economy.BuyGlove(data, gloveId)
		if ok then
			PlayerDataService.MarkChanged(player)
			applyGloveVisual(player)
		end
		return { ok = ok, message = message }
	end)

	Net.Handle("EquipGlove", function(player, gloveId)
		local data = PlayerDataService.Get(player)
		if not data then
			return Net.NotLoaded
		end
		local ok, message = Economy.EquipGlove(data, gloveId)
		if ok then
			PlayerDataService.MarkChanged(player)
			applyGloveVisual(player)
		end
		return { ok = ok, message = message }
	end)
end

function ShopService.Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			-- Wait for the hands to exist before attaching gloves.
			character:WaitForChild("Humanoid", 10)
			task.wait(0.5)
			applyGloveVisual(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	PlayerDataService.ProfileLoaded:Connect(function(player)
		applyGloveVisual(player)
	end)
end

return ShopService
