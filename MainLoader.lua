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
local followTarget = nil

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
frame.Size = UDim2.new(0, 280, 0, 420)
frame.Position = UDim2.new(0, 70, 0, 60)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
frame.BackgroundTransparency = 0.1
frame.BorderSizePixel = 0
frame.ClipsDescendants = true
frame.Parent = gui

-- Tab Buttons
local tabsFrame = Instance.new("Frame")
tabsFrame.Size = UDim2.new(1, 0, 0, 30)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Parent = frame

local tabList = Instance.new("UIListLayout")
tabList.FillDirection = Enum.FillDirection.Horizontal
tabList.SortOrder = Enum.SortOrder.LayoutOrder
tabList.Parent = tabsFrame

local tabPages = {}
local currentTab = nil

local function createTab(name)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 90, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	btn.TextColor3 = Color3.new(1,1,1)
	btn.Font = Enum.Font.Gotham
	btn.Text = name
	btn.TextScaled = true
	btn.Parent = tabsFrame

	local page = Instance.new("ScrollingFrame")
	page.Size = UDim2.new(1, 0, 1, -30)
	page.Position = UDim2.new(0, 0, 0, 30)
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.ScrollBarThickness = 6
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = page

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end)

	tabPages[name] = page

	btn.MouseButton1Click:Connect(function()
		if currentTab then tabPages[currentTab].Visible = false end
		currentTab = name
		tabPages[name].Visible = true
	end)

	if not currentTab then
		currentTab = name
		page.Visible = true
	end

	return page
end

local movementTab = createTab("Movement")
local playerTab = createTab("Player")
local funTab = createTab("Fun")

-- Button helpers
local function createButton(text, callback, parent)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -10, 0, 36)
	btn.Position = UDim2.new(0, 5, 0, 0)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamSemibold
	btn.Text = text
	btn.TextScaled = true
	btn.Parent = parent
	btn.MouseButton1Click:Connect(callback)
	return btn
end

local function createStatusButton(text, defaultState, callback, parent)
	local current = defaultState
	local btn = createButton(text .. " ❌", function()
		current = not current
		btn.Text = text .. (current and " ✅" or " ❌")
		callback(current)
	end, parent)
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

-- Movement Features
createStatusButton("🕊️ Fly", false, function(state) flying = state end, movementTab)
createStatusButton("👻 Noclip", false, function(state) noclip = state end, movementTab)
createStatusButton("🛡️ No Fall Damage", false, function(state) noFall = state end, movementTab)
createButton("📍 Simpan Lokasi", function()
	if hr then savedPos = hr.Position end
end, movementTab)
createButton("🚀 Teleport ke Lokasi", function()
	if savedPos and hr then hr.CFrame = CFrame.new(savedPos) end
end, movementTab)

-- Player Features
createStatusButton("❤️ Auto Heal", false, function(state) autoHeal = state end, playerTab)
createButton("🧲 Tarik Semua Pemain", function()
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			p.Character.HumanoidRootPart.CFrame = hr.CFrame + Vector3.new(0, 5, 0)
		end
	end
end, playerTab)

-- Dropdown: Teleport ke pemain
local dropdown = Instance.new("TextButton")
dropdown.Size = UDim2.new(1, -10, 0, 36)
dropdown.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
dropdown.TextColor3 = Color3.new(1, 1, 1)
dropdown.Font = Enum.Font.Gotham

dropdown.Text = "🌍 Teleport ke Pemain"
dropdown.TextScaled = true
dropdown.Parent = playerTab

dropdown.MouseButton1Click:Connect(function()
	local menu = Instance.new("Frame")
	menu.Size = UDim2.new(1, -10, 0, 120)
	menu.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	menu.Parent = playerTab

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.Parent = menu

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local opt = Instance.new("TextButton")
			opt.Size = UDim2.new(1, 0, 0, 28)
			opt.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
			opt.TextColor3 = Color3.new(1, 1, 1)
			opt.Font = Enum.Font.Gotham
			opt.Text = p.Name
			opt.TextScaled = true
			opt.Parent = menu
			opt.MouseButton1Click:Connect(function()
				menu:Destroy()
				if hr and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
					hr.CFrame = p.Character.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
				end
			end)
		end
	end
end)

-- Fun Features
createStatusButton("🎯 Follow Pemain", false, function(state)
	followTarget = state and Players:GetPlayers()[2] or nil
end, funTab)

-- Drag + Minimize
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

logo.MouseButton1Click:Connect(function()
	frame.Visible = not frame.Visible
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
	if followTarget and followTarget.Character and followTarget.Character:FindFirstChild("HumanoidRootPart") and hr then
		hr.CFrame = followTarget.Character.HumanoidRootPart.CFrame + Vector3.new(0, 0, -3)
	end
end)

print("✅ SuperTool Loaded with Tabs and Dropdown")
