-- Glove shop: buying and equipping gloves, and showing the equipped glove on the character.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GlovesConfig = require(Shared.Config.GlovesConfig)
local GloveBuilder = require(Shared.Gloves.GloveBuilder)
local Economy = require(ServerScriptService.Logic.Economy)
local Net = require(ServerScriptService.Net)
local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)

local ShopService = {}

-- Puts the equipped glove pair on the character (built by the same GloveBuilder as the shop preview).
local function applyGloveVisual(player: Player)
	local character = player.Character
	local data = PlayerDataService.Get(player)
	if not character or not character.Parent or not data then
		return
	end
	if not GlovesConfig.ById[data.EquippedGlove] then
		return
	end
	-- Skip rebuilding when the right gloves are already on.
	local current = character:FindFirstChild("GloveRight")
	if current and current:GetAttribute("GloveId") == data.EquippedGlove then
		return
	end
	GloveBuilder.Attach(character, data.EquippedGlove)
	character:SetAttribute("GloveId", data.EquippedGlove)
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
			-- Wait for both hands (R15) or arms (R6) before attaching gloves.
			local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
			if not humanoid then
				return
			end
			local r15 = humanoid.RigType == Enum.HumanoidRigType.R15
			character:WaitForChild(if r15 then "RightHand" else "Right Arm", 10)
			character:WaitForChild(if r15 then "LeftHand" else "Left Arm", 10)
			task.wait(0.2) -- let the avatar finish scaling
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
