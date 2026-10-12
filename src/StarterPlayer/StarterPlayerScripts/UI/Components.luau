-- Reusable UI building blocks. Everything is built in code so it can live in Git and be reviewed.
--
-- Sizes use scale + size constraints so the same UI works on phones and monitors.
-- Buttons use .Activated, which fires for mouse clicks, touch taps and gamepad presses.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Components = {}

function Components.Make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local make = Components.Make

function Components.Corner(parent: Instance, radius: number?): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function Components.Stroke(parent: Instance, color: Color3, thickness: number?): UIStroke
	return make("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

-- Vertical shading (lighter at the top) for depth.
function Components.Shade(parent: Instance, sequence: ColorSequence?): UIGradient
	return make("UIGradient", {
		Color = sequence or Theme.SoftShading,
		Rotation = 90,
		Parent = parent,
	})
end

function Components.Padding(parent: Instance, pixels: number)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, pixels),
		PaddingRight = UDim.new(0, pixels),
		PaddingTop = UDim.new(0, pixels),
		PaddingBottom = UDim.new(0, pixels),
		Parent = parent,
	})
end

-- Scaled text that never gets bigger than maxSize.
function Components.Label(props: { [string]: any }): TextLabel
	local maxSize = props.MaxTextSize or 22
	props.MaxTextSize = nil
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
		TextStrokeTransparency = 0.6,
		TextStrokeColor3 = Theme.Colors.Dark,
		Size = UDim2.new(1, 0, 0, 24),
	})
	for key, value in props do
		if key == "Parent" then
			continue
		end
		(label :: any)[key] = value
	end
	make("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 8, Parent = label })
	label.Parent = props.Parent
	return label
end

-- A chunky button. props: Text, Color, Size, Position, AnchorPoint, LayoutOrder, MaxTextSize, OnClick, Parent
function Components.Button(props: { [string]: any }): TextButton
	local color = props.Color or Theme.Colors.Accent
	local button = make("TextButton", {
		Name = props.Name or "Button",
		Text = props.Text or "",
		Font = Theme.Font,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
		TextStrokeTransparency = 0.4,
		TextStrokeColor3 = Theme.Colors.Dark,
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Size = props.Size or UDim2.fromOffset(160, 44),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = if props.Visible == nil then true else props.Visible,
		ZIndex = props.ZIndex or 1,
	})
	button:SetAttribute("BaseColor", color)
	Components.Corner(button, props.CornerRadius or 10)
	Components.Stroke(button, Theme.Darken(color, 0.45), 2.5)
	Components.Shade(button, Theme.Shading)
	make("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize or 24, MinTextSize = 8, Parent = button })
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		Parent = button,
	})

	local scale = make("UIScale", { Parent = button })
	local pressInfo = TweenInfo.new(0.08)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, pressInfo, { Scale = 0.93 }):Play()
	end)
	local function release()
		TweenService:Create(scale, pressInfo, { Scale = 1 }):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)

	if props.OnClick then
		button.Activated:Connect(function()
			if button:GetAttribute("Disabled") then
				return
			end
			props.OnClick()
		end)
	end

	button.Parent = props.Parent
	return button
end

-- Greys a button out (it stays visible so players can see what they're missing).
function Components.SetEnabled(button: TextButton, enabled: boolean)
	button:SetAttribute("Disabled", not enabled)
	local base = button:GetAttribute("BaseColor") or button.BackgroundColor3
	button.BackgroundColor3 = if enabled then base else Theme.Colors.Neutral
	button.TextTransparency = if enabled then 0 else 0.35
end

function Components.SetColor(button: TextButton, color: Color3)
	button:SetAttribute("BaseColor", color)
	if not button:GetAttribute("Disabled") then
		button.BackgroundColor3 = color
	end
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Theme.Darken(color)
	end
end

-- Removes every GuiObject child (keeps layouts and padding).
function Components.Clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

export type Panel = {
	Frame: Frame,
	Title: TextLabel,
	Info: Frame,
	Content: ScrollingFrame,
	Grid: UIGridLayout,
}

-- A centered window with a title bar, a close button, an info strip and a scrolling card grid.
-- Cards are at least `minCardWidth` pixels wide; the column count adapts to the screen.
function Components.Panel(root: Instance, title: string, color: Color3, onClose: () -> (), minCardWidth: number?, cardHeight: number?): Panel
	local frame = make("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromScale(0.82, 0.78),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		ZIndex = 5,
		Parent = root,
	})
	make("UISizeConstraint", { MaxSize = Vector2.new(900, 640), Parent = frame })
	Components.Corner(frame, 18)
	local frameStroke = Components.Stroke(frame, Theme.Colors.Accent, 2.5)
	frameStroke.Transparency = 0.35
	Components.Shade(frame, Theme.SoftShading)

	-- Header: the panel's colour fading into navy, with a thin gold rule underneath.
	local header = make("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = frame,
	})
	Components.Corner(header, 18)
	make("UIGradient", {
		Color = ColorSequence.new(color, Theme.Darken(color, 0.55)),
		Rotation = 0,
		Parent = header,
	})
	make("Frame", {
		Name = "Rule",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, 0),
		Size = UDim2.new(1, -28, 0, 2),
		BackgroundColor3 = Theme.Colors.Accent,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Parent = header,
	})
	local titleLabel = Components.Label({
		Text = title,
		Size = UDim2.new(1, -76, 1, -10),
		Position = UDim2.fromOffset(18, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.3,
		MaxTextSize = 30,
		Parent = header,
	})
	Components.Button({
		Name = "Close",
		Text = "✕",
		Color = Theme.Colors.Bad,
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -48, 0, 6),
		MaxTextSize = 22,
		CornerRadius = 20,
		OnClick = onClose,
		Parent = header,
	})

	local info = make("Frame", {
		Name = "Info",
		Size = UDim2.new(1, -24, 0, 44),
		Position = UDim2.fromOffset(12, 58),
		BackgroundTransparency = 1,
		Parent = frame,
	})

	local content = make("ScrollingFrame", {
		Name = "Content",
		Position = UDim2.fromOffset(12, 108),
		Size = UDim2.new(1, -24, 1, -120),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = frame,
	})
	make("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8), Parent = content })
	local grid = make("UIGridLayout", {
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = content,
	})

	local minWidth = minCardWidth or 220
	local height = cardHeight or 150
	local function resize()
		local width = content.AbsoluteSize.X - 12
		local columns = math.max(1, math.floor((width + 10) / (minWidth + 10)))
		grid.CellSize = UDim2.new(1 / columns, -10, 0, height)
	end
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()

	return {
		Frame = frame,
		Title = titleLabel,
		Info = info,
		Content = content,
		Grid = grid,
	}
end

-- A card for a panel grid.
function Components.Card(parent: Instance, order: number, highlight: Color3?): Frame
	local card = make("Frame", {
		BackgroundColor3 = Theme.Colors.Card,
		LayoutOrder = order,
		Parent = parent,
	})
	Components.Corner(card, 14)
	local stroke = Components.Stroke(card, highlight or Theme.Colors.CardHighlight, if highlight then 3 else 1.5)
	stroke.Transparency = if highlight then 0 else 0.2
	Components.Shade(card, Theme.SoftShading)
	Components.Padding(card, 8)
	return card
end

-- A transparent area filling a card below `offset` pixels (e.g. under a preview image).
function Components.Below(card: Frame, offset: number): Frame
	return make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, offset),
		Size = UDim2.new(1, 0, 1, -offset),
		BackgroundTransparency = 1,
		Parent = card,
	})
end

-- Stacks text lines from the top of a card. Returns the y offset below the last line.
function Components.CardLines(card: Frame, lines: { { Text: string, Color: Color3?, Size: number? } }): number
	local y = 0
	for _, line in lines do
		local height = line.Size or 20
		Components.Label({
			Text = line.Text,
			TextColor3 = line.Color or Theme.Colors.Text,
			Size = UDim2.new(1, 0, 0, height),
			Position = UDim2.fromOffset(0, y),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = height,
			Parent = card,
		})
		y += height + 2
	end
	return y
end

-- A button pinned to the bottom of a card.
function Components.CardButton(card: Frame, text: string, color: Color3, onClick: () -> (), widthScale: number?, xScale: number?): TextButton
	return Components.Button({
		Text = text,
		Color = color,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(xScale or 0, if (xScale or 0) > 0 then 3 else 0, 1, 0),
		Size = UDim2.new(widthScale or 1, if (widthScale or 1) < 1 then -3 else 0, 0, 34),
		MaxTextSize = 20,
		OnClick = onClick,
		Parent = card,
	})
end

return Components
