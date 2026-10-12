-- Draws every player's equipped pets following them, using the same PetBuilder models as the
-- inventory. Purely local and anchored, so it costs the server nothing. The server publishes
-- equipped pets as the "EquippedPets" player attribute ("species:tier,species:tier").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PetBuilder = require(ReplicatedStorage:WaitForChild("Shared").Pets.PetBuilder)

local PetController = {}

type Follower = { Model: Model, RainbowParts: { BasePart } }

local folder: Folder
local followers: { [Player]: { Follower } } = {}

local function makePet(speciesId: string, tier: number): Follower
	local model = PetBuilder.Build(speciesId, tier, 0.9)
	local rainbow = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Rainbow") then
			table.insert(rainbow, part)
		end
	end
	model.Parent = folder
	return { Model = model, RainbowParts = rainbow }
end

local function clear(player: Player)
	local list = followers[player]
	if list then
		for _, follower in list do
			follower.Model:Destroy()
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
			table.insert(list, makePet(speciesId, tonumber(tierText) or 1))
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
					-- An arc behind the player, bobbing gently, each pet slightly out of step.
					local x = (i - (count + 1) / 2) * 3.4
					local bob = math.sin(t * 3 + i) * 0.35
					local target = root.CFrame * CFrame.new(x, -0.6 + bob, 5.2 + math.abs(x) * 0.3)
					local current = follower.Model:GetPivot()
					follower.Model:PivotTo(current:Lerp(target, alpha))
					for j, part in follower.RainbowParts do
						part.Color = Color3.fromHSV((t * 0.25 + i * 0.1 + j * 0.03) % 1, 0.7, 1)
					end
				end
			end
		end
	end)
end

return PetController
