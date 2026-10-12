-- Full-screen egg hatch: the egg wobbles, flashes, then reveals the pet.
-- Purely visual: the result was already decided by the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetsConfig = require(Shared.Config.PetsConfig)
local Formulas = require(Shared.Logic.Formulas)
local Format = require(Shared.Utilities.Format)

local RunService = game:GetService("RunService")

local Components = require(script.Parent.Components)
local Previews = require(script.Parent.Previews)
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
	Components.Shade(egg, Theme.Shading)
	-- A band and a few spots so the egg reads as an object, not a blob.
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.new(0.95, 0, 0.07, 0),
		BackgroundColor3 = Theme.Colors.Accent,
		BorderSizePixel = 0,
		ZIndex = 32,
		Parent = egg,
	})
	for _, spot in { { 0.3, 0.3, 0.16 }, { 0.68, 0.24, 0.12 }, { 0.6, 0.75, 0.15 }, { 0.26, 0.72, 0.1 } } do
		local dot = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(spot[1], spot[2]),
			Size = UDim2.fromScale(spot[3], spot[3] * 0.78),
			BackgroundColor3 = Theme.Darken(eggColor, 0.25),
			ZIndex = 32,
			Parent = egg,
		})
		make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = dot })
	end

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
			Size = UDim2.fromScale(0.4, 0.62),
			BackgroundColor3 = Theme.Colors.Panel,
			ZIndex = 31,
			Parent = overlay,
		})
		make("UISizeConstraint", { MinSize = Vector2.new(280, 340), MaxSize = Vector2.new(460, 470), Parent = card })
		Components.Corner(card, 18)
		Components.Stroke(card, rarity.Color, 4)
		Components.Shade(card, Theme.SoftShading)

		-- The pet itself, turning slowly on a glowing stage.
		local viewport, model = Previews.Pet(card, pet.Species, pet.Tier, UDim2.fromScale(0.9, 0.5), UDim2.fromScale(0.05, 0.04), rarity.Color)
		viewport.ZIndex = 32
		local spinStart = os.clock()
		local spin = RunService.RenderStepped:Connect(function()
			model:PivotTo(CFrame.Angles(0, math.rad(-20) + (os.clock() - spinStart) * 1.6, 0))
		end)
		card.Destroying:Connect(function()
			spin:Disconnect()
		end)

		local lines = {
			{ Text = if pet.Tier > 1 then `{PetsConfig.Tiers[pet.Tier].Name} {species.Name}` else species.Name, Color = species.Color:Lerp(Color3.new(1, 1, 1), 0.3), Size = 0.13 },
			{ Text = rarity.Id:upper(), Color = rarity.Color, Size = 0.1 },
			{ Text = `{Format.Multiplier(Formulas.PetMultiplier(pet.Species, pet.Tier))} Power`, Color = Theme.Colors.Power, Size = 0.1 },
			{ Text = "Tap to continue", Color = Theme.Colors.SubText, Size = 0.07 },
		}
		local y = 0.555
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
