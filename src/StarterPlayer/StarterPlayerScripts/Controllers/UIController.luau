-- Owns the ScreenGui: HUD, panels, toasts and confirm dialogs.
--
-- API:
--   UIController.Open(name) / Close() / Toggle(name)
--   UIController.Toast(message, color?)
--   UIController.Confirm(title, body, yesText, onYes)
--   UIController.Request(remoteName, ...) -> result   (invokes the server and toasts its message)
--   UIController.GetHud() -> Hud elements
--   UIController.GetRoot() -> ScreenGui

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local StarterPlayerScripts = script.Parent.Parent
local ClientState = require(StarterPlayerScripts.ClientState)
local Net = require(StarterPlayerScripts.Net)
local Components = require(StarterPlayerScripts.UI.Components)
local Hud = require(StarterPlayerScripts.UI.Hud)
local Theme = require(StarterPlayerScripts.UI.Theme)

local make = Components.Make

local UIController = {}

local screen: ScreenGui
local hud
local toastList: Frame
local panels = {}
local openName: string? = nil
local toastCount = 0

local KIND_COLORS = {
	Info = Theme.Colors.Blue,
	Success = Theme.Colors.Good,
	Warning = Theme.Colors.Wins,
	Error = Theme.Colors.Bad,
}

local function refresh(panel, force: boolean?)
	local data = ClientState.Data
	if not data then
		return
	end
	local key = if panel.Key then panel.Key(data) else nil
	if force or key == nil or key ~= panel.LastKey then
		panel.LastKey = key
		panel.Refresh(data)
	end
end

function UIController.Open(name: string)
	local panel = panels[name]
	if not panel then
		return
	end
	if openName and openName ~= name then
		UIController.Close()
	end
	openName = name
	if panel.OnOpen then
		panel.OnOpen()
	end
	panel.Panel.Frame.Visible = true
	refresh(panel, true)
end

function UIController.Close()
	if openName and panels[openName] then
		panels[openName].Panel.Frame.Visible = false
	end
	openName = nil
end

function UIController.Toggle(name: string)
	if openName == name then
		UIController.Close()
	else
		UIController.Open(name)
	end
end

function UIController.IsOpen(): boolean
	return openName ~= nil
end

function UIController.Toast(message: string, color: Color3?)
	local accent = color or Theme.Colors.Blue
	toastCount += 1
	local toast = make("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0.1,
		LayoutOrder = toastCount,
		Parent = toastList,
	})
	Components.Corner(toast, 10)
	local stroke = Components.Stroke(toast, accent, 2)
	local label = Components.Label({
		Text = message,
		Size = UDim2.new(1, -16, 1, -6),
		Position = UDim2.fromOffset(8, 3),
		MaxTextSize = 20,
		Parent = toast,
	})

	-- Keep at most four toasts.
	local toasts = {}
	for _, child in toastList:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #toasts - 4 do
		toasts[i]:Destroy()
	end

	task.delay(2.6, function()
		if not toast.Parent then
			return
		end
		local info = TweenInfo.new(0.4)
		TweenService:Create(toast, info, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(stroke, info, { Transparency = 1 }):Play()
		task.wait(0.45)
		toast:Destroy()
	end)
end

function UIController.Confirm(title: string, body: string, yesText: string, onYes: () -> ())
	local overlay = make("TextButton", {
		Name = "Confirm",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		ZIndex = 20,
		Parent = screen,
	})
	local box = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.4),
		BackgroundColor3 = Theme.Colors.Panel,
		ZIndex = 21,
		Parent = overlay,
	})
	make("UISizeConstraint", { MinSize = Vector2.new(280, 200), MaxSize = Vector2.new(520, 260), Parent = box })
	Components.Corner(box, 16)
	Components.Stroke(box, Theme.Colors.Accent, 3)
	Components.Padding(box, 14)

	Components.Label({ Text = title, Size = UDim2.new(1, 0, 0, 34), MaxTextSize = 30, ZIndex = 22, Parent = box })
	Components.Label({
		Text = body,
		Font = Theme.BodyFont,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 1, -100),
		Position = UDim2.fromOffset(0, 40),
		TextColor3 = Theme.Colors.SubText,
		MaxTextSize = 20,
		ZIndex = 22,
		Parent = box,
	})

	local function close()
		overlay:Destroy()
	end
	Components.Button({
		Text = "Cancel",
		Color = Theme.Colors.Neutral,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.48, 0, 0, 48),
		ZIndex = 22,
		OnClick = close,
		Parent = box,
	})
	Components.Button({
		Text = yesText,
		Color = Theme.Colors.Good,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.48, 0, 0, 48),
		ZIndex = 22,
		OnClick = function()
			close()
			onYes()
		end,
		Parent = box,
	})
end

function UIController.Request(remoteName: string, ...: any): { [string]: any }
	local result = Net.Invoke(remoteName, ...)
	if result.message then
		UIController.Toast(result.message, if result.ok then Theme.Colors.Good else Theme.Colors.Bad)
	end
	return result
end

function UIController.GetHud()
	return hud
end

function UIController.GetRoot(): ScreenGui
	return screen
end

function UIController.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	screen = make("ScreenGui", {
		Name = "MainHUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	hud = Hud.Create(screen, UIController.Toggle)

	toastList = make("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.new(0.5, 0, 0, 180),
		BackgroundTransparency = 1,
		ZIndex = 25,
		Parent = screen,
	})
	make("UISizeConstraint", { MinSize = Vector2.new(280, 0), MaxSize = Vector2.new(560, 180), Parent = toastList })
	make("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = toastList,
	})

	local api = {
		Root = screen,
		Close = UIController.Close,
		Toast = UIController.Toast,
		Confirm = UIController.Confirm,
		Request = UIController.Request,
		GetData = function()
			return ClientState.Data
		end,
	}
	for _, module in StarterPlayerScripts.UI.Panels:GetChildren() do
		if module:IsA("ModuleScript") then
			local panel = require(module).Create(api)
			panels[panel.Name] = panel
		end
	end
end

function UIController.Start()
	local function onData(data)
		hud.Update(data)
		if openName and panels[openName] then
			refresh(panels[openName])
		end
	end
	ClientState.Changed:Connect(onData)
	if ClientState.Data then
		onData(ClientState.Data)
	end

	Net.On("Notify", function(message: string, kind: string?)
		UIController.Toast(message, KIND_COLORS[kind or "Info"])
	end)
end

return UIController
