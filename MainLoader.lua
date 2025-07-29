-- MainLoader.lua (Versi Android Final dengan UI Persegi Panjang + Filter Tabs + Scroll + Nama Target + List Pemain)
-- Dibuat oleh Fari Noveri - UI & kontrol Android lengkap

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local humanoid, hr, char
local flying, noclip, autoHeal, noFall, godMode = false, false, false, false, false
local savedPos = nil
local followTarget = nil
local gendongWeld = nil
local up, down = false, false

local gui = Instance.new("ScreenGui")
gui.Name = "SuperToolUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- Logo toggle + drag
local logo = Instance.new("ImageButton")
logo.Size = UDim2.new(0, 50, 0, 50)
logo.Position = UDim2.new(0.5, -25, 0, 10)
logo.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
logo.BorderSizePixel = 0
logo.Image = "rbxassetid://3570695787"
logo.Parent = gui

local dragging = false
local dragInput, dragStart, startPos
logo.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = logo.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)
logo.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		dragInput = input
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		local delta = input.Position - dragStart
		logo.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

logo.MouseButton1Click:Connect(function()
	frame.Visible = not frame.Visible
end)

-- Main frame (UI persegi panjang horizontal)
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 700, 0, 400)
frame.Position = UDim2.new(0.5, -350, 0.5, -200)
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

-- Tambahkan list pemain di tab Player
local playerTab = createTab("Player")
local playerListFrame = Instance.new("ScrollingFrame")
playerListFrame.Size = UDim2.new(1, -20, 0, 250)
playerListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
playerListFrame.ScrollBarThickness = 6
playerListFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
playerListFrame.BorderSizePixel = 0
playerListFrame.Parent = playerTab

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 2)
listLayout.Parent = playerListFrame

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	playerListFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
end)

local function refreshPlayerList()
	for _, child in ipairs(playerListFrame:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			createButton("🎮 " .. p.Name, function()
				createButton("🔄 Teleport ke " .. p.Name, function()
					if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
						player.Character.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
					end
				end, playerListFrame)
				createButton("🎯 Follow " .. p.Name, function()
					followTarget = p
				end, playerListFrame)
				createButton("🧲 Tarik " .. p.Name, function()
					if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
						p.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
					end
				end, playerListFrame)
				createButton("🤝 Gendong " .. p.Name, function()
					if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
						if gendongWeld then gendongWeld:Destroy() end
						gendongWeld = Instance.new("WeldConstraint")
						gendongWeld.Part0 = player.Character.HumanoidRootPart
						gendongWeld.Part1 = p.Character.HumanoidRootPart
						gendongWeld.Parent = player.Character.HumanoidRootPart
					end
				end, playerListFrame)
				createButton("🚫 Batal Gendong", function()
					if gendongWeld then gendongWeld:Destroy() gendongWeld = nil end
				end, playerListFrame)
			end, playerListFrame)
		end
	end
end

Players.PlayerAdded:Connect(refreshPlayerList)
Players.PlayerRemoving:Connect(refreshPlayerList)
task.defer(refreshPlayerList)
