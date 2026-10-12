-- Draws every player's equipped pets following them. Purely local and anchored, so it costs the
-- server nothing. The server publishes equipped pets as the "EquippedPets" player attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetsConfig = require(Shared.Config.PetsConfig)

local PetController = {}

type Follower = { Part: BasePart, Rainbow: boolean }

local folder: Folder
local followers: { [Player]: { Follower } } = {}

local GOLD = Color3.fromRGB(255, 200, 40)
local DIAMOND = Color3.fromRGB(150, 230, 255)

local function makePet(speciesId: string, tier: number): Follower?
	local species = PetsConfig.SpeciesById[speciesId]
	if not species then
		return nil
	end
	local rarity = PetsConfig.RaritiesById[species.Rarity]
	local size = 1.4 + rarity.Order * 0.15

	local part = Instance.new("Part")
	part.Name = species.Name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Color = species.Color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false

	if tier == 2 then
		part.Color = species.Color:Lerp(GOLD, 0.7)
		part.Material = Enum.Material.Foil
	elseif tier == 3 then
		part.Color = species.Color:Lerp(DIAMOND, 0.7)
		part.Material = Enum.Material.Glass
		part.Transparency = 0.15
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = DIAMOND
		sparkles.Parent = part
	end

	local face = Instance.new("Decal")
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = part

	if rarity.Order >= 5 then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = 8
		light.Brightness = 1
		light.Parent = part
	end

	part.Parent = folder
	return { Part = part, Rainbow = tier == 4 }
end

local function clear(player: Player)
	local list = followers[player]
	if list then
		for _, follower in list do
			follower.Part:Destroy()
		end
	end
	followers[player] = nil
end

local function rebuild(player: Player)
	clear(player)
	local value = player:GetAttribute("EquippedPets")
	if type(value) ~= "string" or value == "" then
		return
	end
	local list = {}
	for _, entry in string.split(value, ",") do
		local speciesId, tierText = string.match(entry, "^(.-):(%d+)$")
		if speciesId then
			local follower = makePet(speciesId, tonumber(tierText) or 1)
			if follower then
				table.insert(list, follower)
			end
		end
	end
	followers[player] = list
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuild(player)
	end)
	rebuild(player)
end

function PetController.Init()
	folder = Instance.new("Folder")
	folder.Name = "ClientPets"
	folder.Parent = workspace
end

function PetController.Start()
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	for _, player in Players:GetPlayers() do
		watch(player)
	end

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		local alpha = 1 - math.exp(-dt * 8)
		for player, list in followers do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local count = #list
				for i, follower in list do
					local x = (i - (count + 1) / 2) * 3.2
					local bob = math.sin(t * 3 + i) * 0.4
					local target = root.CFrame * CFrame.new(x, -1 + bob, 5 + math.abs(x) * 0.3)
					follower.Part.CFrame = follower.Part.CFrame:Lerp(target, alpha)
					if follower.Rainbow then
						follower.Part.Color = Color3.fromHSV((t * 0.25 + i * 0.1) % 1, 0.75, 1)
					end
				end
			end
		end
	end)
end

return PetController
