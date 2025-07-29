-- MainLoader.lua (Versi Android Final dengan UI Persegi Panjang + Filter Tabs + Scroll)
-- Dibuat oleh Fari Noveri - UI & kontrol Android lengkap

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local humanoid, hr, char
local flying, noclip, autoHeal, noFall, godMode = false, false, false, false, false
local savedPos = nil
local followTarget = nil
local up, down = false, false

local gui = Instance.new("ScreenGui")
gui.Name = "SuperToolUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- Logo toggle
local logo = Instance.new("ImageButton")
logo.Size = UDim2.new(0, 50, 0, 50)
logo.Position = UDim2.new(0, 10, 0, 10)
logo.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
logo.BorderSizePixel = 0
logo.Image = "rbxassetid://3570695787"
logo.Parent = gui

-- Main frame (persegi panjang horizontal)
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 700, 0, 400)
frame.Position = UDim2.new(0, 70, 0, 70)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Visible = true
frame.Parent = gui

-- Tabs panel
local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(0, 130, 1, 0)
tabFrame.Position = UDim2.new(0, 0, 0, 0)
tabFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
tabFrame.BorderSizePixel = 0
tabFrame.Parent = frame

local tabLayout = Instance.new("UIListLayout")
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = tabFrame

-- Scrollable content panel
local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Size = UDim2.new(1, -140, 1, 0)
contentFrame.Position = UDim2.new(0, 140, 0, 0)
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
contentFrame.ScrollBarThickness = 6
contentFrame.BackgroundTransparency = 1
contentFrame.BorderSizePixel = 0
contentFrame.Parent = frame

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 4)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = contentFrame

contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 10)
end)

-- Tab system
local tabPages = {}
local currentTab = nil

local function switchTab(name)
	for tabName, page in pairs(tabPages) do
		page.Visible = (tabName == name)
	end
	currentTab = name
end

local function createTab(name)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -10, 0, 32)
	btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.Gotham
	btn.Text = name
	btn.TextScaled = true
	btn.Parent = tabFrame
	btn.MouseButton1Click:Connect(function() switchTab(name) end)

	local page = Instance.new("Frame")
	page.Size = UDim2.new(1, 0, 0, 0)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.Name = name
	page.Parent = contentFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = page

	tabPages[name] = page

	if not currentTab then
		switchTab(name)
	end

	return page
end

-- Buttons inside a page
local function createButton(text, callback, parent)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -20, 0, 36)
	btn.Position = UDim2.new(0, 10, 0, 0)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamSemibold
	btn.Text = text
	btn.TextScaled = true
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = true
	btn.Parent = parent
	btn.MouseButton1Click:Connect(callback)
	return btn
end

local function createToggle(text, stateRef, callback, parent)
	local btn = createButton(text .. " ❌", function()
		stateRef[1] = not stateRef[1]
		btn.Text = text .. (stateRef[1] and " ✅" or " ❌")
		callback(stateRef[1])
	end, parent)
	callback(stateRef[1])
end

-- Init player state
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

-- Tabs & Features
local movementTab = createTab("Movement")
local playerTab = createTab("Player")
local otherTab = createTab("Other")

createToggle("🕊️ Fly", {flying}, function(val) flying = val end, movementTab)
createButton("⬆️ Naik", function() up = true task.delay(0.3, function() up = false end) end, movementTab)
createButton("⬇️ Turun", function() down = true task.delay(0.3, function() down = false end) end, movementTab)
createToggle("👻 Noclip", {noclip}, function(val) noclip = val end, movementTab)
createToggle("🛡️ No Fall", {noFall}, function(val) noFall = val end, movementTab)
createButton("📍 Simpan Lokasi", function() if hr then savedPos = hr.Position end end, movementTab)
createButton("🚀 Teleport ke Lokasi", function() if savedPos and hr then hr.CFrame = CFrame.new(savedPos) end end, movementTab)

createToggle("❤️ Auto Heal", {autoHeal}, function(val) autoHeal = val end, playerTab)
createToggle("💀 God Mode", {godMode}, function(val) godMode = val end, playerTab)
createButton("🧲 Tarik Pemain", function()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			p.Character.HumanoidRootPart.CFrame = hr.CFrame + Vector3.new(0, 5, 0)
		end
	end
end, playerTab)
createButton("🌍 Teleport ke Pemain", function()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			hr.CFrame = p.Character.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
			break
		end
	end
end, playerTab)
createButton("🎯 Follow Pemain", function()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			followTarget = p
			break
		end
	end
end, playerTab)

logo.MouseButton1Click:Connect(function()
	frame.Visible = not frame.Visible
end)

RunService.RenderStepped:Connect(function()
	if flying and hr then
		local dir = humanoid.MoveDirection * 2
		if up then dir += Vector3.new(0, 2, 0) end
		if down then dir -= Vector3.new(0, 2, 0) end
		hr.Velocity = dir * 30
	end
	if noclip and char then
		for _,v in ipairs(char:GetDescendants()) do
			if v:IsA("BasePart") then v.CanCollide = false end
		end
	end
	if autoHeal and humanoid and humanoid.Health < humanoid.MaxHealth then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 0.5)
	end
	if godMode and humanoid then
		humanoid.Health = humanoid.MaxHealth
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	end
	if noFall and humanoid then
		if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
	if followTarget and followTarget.Character and followTarget.Character:FindFirstChild("HumanoidRootPart") and hr then
		hr.CFrame = followTarget.Character.HumanoidRootPart.CFrame + Vector3.new(0, 0, -3)
	end
end)

print("✅ SuperTool Android UI Final: Persegi Panjang dengan Tab & Scroll")
