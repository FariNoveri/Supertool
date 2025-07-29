-- MainLoader.lua (Single File Version)
-- Dibuat oleh Fari Noveri untuk SuperTool - Versi Loadstring Gabungan

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local humanoid, hrp, char
local up, down = false, false
local flying, noclip, autoHeal, noFall = false, false, false, false
local savedPos = nil

local gui = Instance.new("ScreenGui")
gui.Name = "SuperToolUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Logo
local logo = Instance.new("ImageButton")
logo.Size = UDim2.new(0, 50, 0, 50)
logo.Position = UDim2.new(0, 10, 0, 10)
logo.BackgroundTransparency = 1
logo.Image = "rbxassetid://3570695787"
logo.Parent = gui

-- Frame UI
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 260, 0, 400)
frame.Position = UDim2.new(0, 70, 0, 60)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 0
frame.ClipsDescendants = true
frame.Parent = gui

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, 0, 1, 0)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollBarThickness = 6
scroll.BackgroundTransparency = 1
scroll.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
end)

-- Drag
local dragging = false
local dragInput, dragStart, startPos
local function updateInput(input)
	local delta = input.Position - dragStart
	frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
		startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

logo.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
logo.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then updateInput(input) end
end)

-- Minimize
local minimized = false
logo.MouseButton1Click:Connect(function()
	minimized = not minimized
	frame.Visible = not minimized
end)

-- Button helpers
local function createButton(text, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -10, 0, 36)
	btn.Position = UDim2.new(0, 5, 0, 0)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamSemibold
	btn.Text = text
	btn.TextScaled = true
	btn.Parent = scroll
	btn.MouseButton1Click:Connect(callback)
	return btn
end

local function createStatusButton(text, defaultState, callback)
	local current = defaultState
	local btn = createButton(text .. " ❌", function()
		current = not current
		btn.Text = text .. (current and " ✅" or " ❌")
		callback(current)
	end)
	callback(current)
	return btn
end

-- Character init
local function refreshCharacter()
	char = player.Character or player.CharacterAdded:Wait()
	humanoid = char:WaitForChild("Humanoid")
	hr = char:WaitForChild("HumanoidRootPart")
end
refreshCharacter()
player.CharacterAdded:Connect(function()
	task.wait(1)
	refreshCharacter()
	if savedPos then hr.CFrame = CFrame.new(savedPos) end
end)

-- Fitur utama
createStatusButton("🕊️ Fly", false, function(state) flying = state end)
createStatusButton("👻 Noclip", false, function(state) noclip = state end)
createStatusButton("❤️ Auto Heal", false, function(state) autoHeal = state end)
createStatusButton("🛡️ No Fall Damage", false, function(state) noFall = state end)

createButton("📍 Simpan Lokasi", function()
	if hr then savedPos = hr.Position end
end)

createButton("🚀 Teleport ke Lokasi", function()
	if savedPos and hr then hr.CFrame = CFrame.new(savedPos) end
end)

createButton("❌ Tutup UI", function()
	gui:Destroy()
end)

-- Loop
RunService.RenderStepped:Connect(function()
	if flying and hr then
		local dir = humanoid.MoveDirection * 2
		if up then dir += Vector3.new(0, 2, 0) end
		if down then dir -= Vector3.new(0, 2, 0) end
		hr.Velocity = dir * 30
	end
	if noclip and char then
		for _,v in pairs(char:GetDescendants()) do
			if v:IsA("BasePart") then v.CanCollide = false end
		end
	end
	if autoHeal and humanoid and humanoid.Health < humanoid.MaxHealth then
		humanoid.Health += 1
	end
end)

print("✅ SuperTool Loaded (One-File Version)")
