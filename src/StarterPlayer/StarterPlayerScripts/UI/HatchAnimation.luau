-- Full-screen egg hatch: the egg wobbles, flashes, then reveals the pet.
-- Purely visual: the result was already decided by the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetsConfig = require(Shared.Config.PetsConfig)
local Formulas = require(Shared.Logic.Formulas)
local Format = require(Shared.Utilities.Format)

local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)

local make = Components.Make

local HatchAnimation = {}

function HatchAnimation.Play(root: Instance, eggColor: Color3, pet: { Species: string, Tier: number }, onDone: (() -> ())?)
	local species = PetsConfig.SpeciesById[pet.Species]
	local rarity = PetsConfig.RaritiesById[species.Rarity]

	local overlay = make("TextButton", {
		Name = "Hatch",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		ZIndex = 30,
		Parent = root,
	})

	local egg = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromScale(0.16, 0.36),
		BackgroundColor3 = eggColor,
		ZIndex = 31,
		Parent = overlay,
	})
	make("UIAspectRatioConstraint", { AspectRatio = 0.78, Parent = egg })
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = egg })
	Components.Stroke(egg, Theme.Darken(eggColor), 4)

	local flash = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 32,
		Parent = overlay,
	})

	local finished = false
	local function close()
		if finished then
			return
		end
		finished = true
		overlay:Destroy()
		if onDone then
			onDone()
		end
	end

	task.spawn(function()
		-- Wobble, faster and faster.
		for i = 1, 8 do
			local angle = if i % 2 == 0 then 14 else -14
			local tween = TweenService:Create(egg, TweenInfo.new(0.16 - i * 0.012), { Rotation = angle })
			tween:Play()
			tween.Completed:Wait()
			if finished then
				return
			end
		end

		flash.BackgroundTransparency = 0
		egg.Visible = false
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()

		local card = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.4, 0.42),
			BackgroundColor3 = Theme.Colors.Panel,
			ZIndex = 31,
			Parent = overlay,
		})
		make("UISizeConstraint", { MinSize = Vector2.new(260, 200), MaxSize = Vector2.new(460, 300), Parent = card })
		Components.Corner(card, 18)
		Components.Stroke(card, rarity.Color, 4)

		local lines = {
			{ Text = if pet.Tier > 1 then `{PetsConfig.Tiers[pet.Tier].Name} {species.Name}` else species.Name, Color = species.Color, Size = 0.3 },
			{ Text = rarity.Id:upper(), Color = rarity.Color, Size = 0.2 },
			{ Text = `{Format.Multiplier(Formulas.PetMultiplier(pet.Species, pet.Tier))} Power`, Color = Theme.Colors.Power, Size = 0.2 },
			{ Text = "Tap to continue", Color = Theme.Colors.SubText, Size = 0.14 },
		}
		local y = 0.06
		for _, line in lines do
			local label = Components.Label({
				Text = line.Text,
				TextColor3 = line.Color,
				TextStrokeTransparency = 0.2,
				Size = UDim2.fromScale(0.9, line.Size),
				Position = UDim2.fromScale(0.05, y),
				MaxTextSize = 48,
				ZIndex = 32,
				Parent = card,
			})
			label.ZIndex = 32
			y += line.Size + 0.02
		end

		local scale = make("UIScale", { Scale = 0.3, Parent = card })
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

		overlay.Activated:Connect(close)
		task.delay(4, close)
	end)
end

return HatchAnimation
