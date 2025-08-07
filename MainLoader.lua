local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- AUTO-DISABLE PREVIOUS SCRIPTS
for _, gui in pairs(CoreGui:GetChildren()) do
    if gui.Name == "MinimalHackGUI" then
        gui:Destroy()
    end
end

-- Load AntiAdmin.lua in the background
local success, errorMsg = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/refs/heads/main/AntiAdmin.lua", true))()
end)
if not success then
    warn("Failed to load AntiAdmin.lua: " .. tostring(errorMsg))
else
    print("Anti Admin Loaded - By Fari Noveri")
end

-- Load other modules
local modules = {
    AntiAdmin = loadstring(game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/refs/heads/main/AntiAdmin.lua", true))(),
    Movement = loadstring(game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/refs/heads/main/Movement.lua", true))(),
    Player = loadstring(game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/refs/heads/main/Player.lua", true))(),
    Visual = loadstring(game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/refs/heads/main/Visual.lua", true))(),
    Teleport = loadstring(game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/refs/heads/main/Teleport.lua", true))(),
    Utility = loadstring(game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/refs/heads/main/Utility.lua", true))(),
    Settings = loadstring(game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/refs/heads/main/Settings.lua", true))(),
    Info = loadstring(game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/refs/heads/main/Info.lua", true))(),
    AntiAdminInfo = loadstring(game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/refs/heads/main/antiadmininfo.lua", true))()
}

-- Variables
local currentCategory = "Movement"
local playerListVisible = false
local guiMinimized = false
local selectedPlayer = nil
local currentSpectateIndex = 0
local spectatePlayerList = {}
local spectateConnections = {}
local connections = {}
local buttonStates = {}

-- GUI Creation
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MinimalHackGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
MainFrame.BorderSizePixel = 1
MainFrame.Position = UDim2.new(0.05, 0, 0.1, 0)
MainFrame.Size = UDim2.new(0, 600, 0, 400)
MainFrame.Active = true
MainFrame.Draggable = true

local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Parent = MainFrame
TopBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
TopBar.BorderSizePixel = 0
TopBar.Position = UDim2.new(0, 0, 0, 0)
TopBar.Size = UDim2.new(1, 0, 0, 35)

local Logo = Instance.new("TextLabel")
Logo.Name = "Logo"
Logo.Parent = TopBar
Logo.BackgroundTransparency = 1
Logo.Position = UDim2.new(0, 10, 0, 5)
Logo.Size = UDim2.new(0, 25, 0, 25)
Logo.Font = Enum.Font.GothamBold
Logo.Text = "H"
Logo.TextColor3 = Color3.fromRGB(255, 255, 255)
Logo.TextScaled = true

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Parent = TopBar
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 45, 0, 0)
Title.Size = UDim2.new(1, -90, 1, 0)
Title.Font = Enum.Font.Gotham
Title.Text = "HACK - By Fari Noveri [UNKNOWN BLOCK]"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left

local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Name = "MinimizeButton"
MinimizeButton.Parent = TopBar
MinimizeButton.BackgroundTransparency = 1
MinimizeButton.Position = UDim2.new(1, -30, 0, 5)
MinimizeButton.Size = UDim2.new(0, 25, 0, 25)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "_"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextSize = 16

local CategoryFrame = Instance.new("Frame")
CategoryFrame.Name = "CategoryFrame"
CategoryFrame.Parent = MainFrame
CategoryFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
CategoryFrame.BorderSizePixel = 0
CategoryFrame.Position = UDim2.new(0, 0, 0, 35)
CategoryFrame.Size = UDim2.new(0, 140, 1, -35)

local CategoryList = Instance.new("UIListLayout")
CategoryList.Parent = CategoryFrame
CategoryList.Padding = UDim.new(0, 2)
CategoryList.SortOrder = Enum.SortOrder.LayoutOrder

local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Parent = MainFrame
ContentFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
ContentFrame.BorderSizePixel = 0
ContentFrame.Position = UDim2.new(0, 140, 0, 35)
ContentFrame.Size = UDim2.new(1, -140, 1, -35)

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Name = "ScrollFrame"
ScrollFrame.Parent = ContentFrame
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.Position = UDim2.new(0, 10, 0, 10)
ScrollFrame.Size = UDim2.new(1, -20, 1, -20)
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
ScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = ScrollFrame
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local PlayerListFrame = Instance.new("Frame")
PlayerListFrame.Name = "PlayerListFrame"
PlayerListFrame.Parent = ScreenGui
PlayerListFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
PlayerListFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
PlayerListFrame.BorderSizePixel = 1
PlayerListFrame.Position = UDim2.new(0.5, -150, 0.2, 0)
PlayerListFrame.Size = UDim2.new(0, 300, 0, 350)
PlayerListFrame.Visible = false
PlayerListFrame.Active = true
PlayerListFrame.Draggable = true

local PlayerListTitle = Instance.new("TextLabel")
PlayerListTitle.Name = "Title"
PlayerListTitle.Parent = PlayerListFrame
PlayerListTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
PlayerListTitle.BorderSizePixel = 0
PlayerListTitle.Position = UDim2.new(0, 0, 0, 0)
PlayerListTitle.Size = UDim2.new(1, 0, 0, 35)
PlayerListTitle.Font = Enum.Font.Gotham
PlayerListTitle.Text = "SELECT PLAYER"
PlayerListTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
PlayerListTitle.TextSize = 12

local ClosePlayerListButton = Instance.new("TextButton")
ClosePlayerListButton.Name = "CloseButton"
ClosePlayerListButton.Parent = PlayerListFrame
ClosePlayerListButton.BackgroundTransparency = 1
ClosePlayerListButton.Position = UDim2.new(1, -30, 0, 5)
ClosePlayerListButton.Size = UDim2.new(0, 25, 0, 25)
ClosePlayerListButton.Font = Enum.Font.GothamBold
ClosePlayerListButton.Text = "X"
ClosePlayerListButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ClosePlayerListButton.TextSize = 12

local SelectedPlayerLabel = Instance.new("TextLabel")
SelectedPlayerLabel.Name = "SelectedPlayerLabel"
SelectedPlayerLabel.Parent = PlayerListFrame
SelectedPlayerLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
SelectedPlayerLabel.BorderSizePixel = 0
SelectedPlayerLabel.Position = UDim2.new(0, 10, 0, 45)
SelectedPlayerLabel.Size = UDim2.new(1, -20, 0, 25)
SelectedPlayerLabel.Font = Enum.Font.Gotham
SelectedPlayerLabel.Text = "SELECTED: NONE"
SelectedPlayerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SelectedPlayerLabel.TextSize = 10

local PlayerListScrollFrame = Instance.new("ScrollingFrame")
PlayerListScrollFrame.Name = "PlayerListScrollFrame"
PlayerListScrollFrame.Parent = PlayerListFrame
PlayerListScrollFrame.BackgroundTransparency = 1
PlayerListScrollFrame.Position = UDim2.new(0, 10, 0, 80)
PlayerListScrollFrame.Size = UDim2.new(1, -20, 1, -90)
PlayerListScrollFrame.ScrollBarThickness = 4
PlayerListScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
PlayerListScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
PlayerListScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
PlayerListScrollFrame.BorderSizePixel = 0

local PlayerListLayout = Instance.new("UIListLayout")
PlayerListLayout.Parent = PlayerListScrollFrame
PlayerListLayout.Padding = UDim.new(0, 2)
PlayerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
PlayerListLayout.FillDirection = Enum.FillDirection.Vertical

local PositionFrame = Instance.new("Frame")
PositionFrame.Name = "PositionFrame"
PositionFrame.Parent = ScreenGui
PositionFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
PositionFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
PositionFrame.BorderSizePixel = 1
PositionFrame.Position = UDim2.new(0.3, 0, 0.2, 0)
PositionFrame.Size = UDim2.new(0, 350, 0, 400)
PositionFrame.Visible = false
PositionFrame.Active = true
PositionFrame.Draggable = true

local PositionTitle = Instance.new("TextLabel")
PositionTitle.Name = "Title"
PositionTitle.Parent = PositionFrame
PositionTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
PositionTitle.BorderSizePixel = 0
PositionTitle.Position = UDim2.new(0, 0, 0, 0)
PositionTitle.Size = UDim2.new(1, 0, 0, 35)
PositionTitle.Font = Enum.Font.Gotham
PositionTitle.Text = "SAVED POSITIONS"
PositionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
PositionTitle.TextSize = 12

local ClosePositionButton = Instance.new("TextButton")
ClosePositionButton.Name = "CloseButton"
ClosePositionButton.Parent = PositionFrame
ClosePositionButton.BackgroundTransparency = 1
ClosePositionButton.Position = UDim2.new(1, -30, 0, 5)
ClosePositionButton.Size = UDim2.new(0, 25, 0, 25)
ClosePositionButton.Font = Enum.Font.GothamBold
ClosePositionButton.Text = "X"
ClosePositionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ClosePositionButton.TextSize = 12

local PositionInput = Instance.new("TextBox")
PositionInput.Name = "PositionInput"
PositionInput.Parent = PositionFrame
PositionInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
PositionInput.BorderSizePixel = 0
PositionInput.Position = UDim2.new(0, 10, 0, 45)
PositionInput.Size = UDim2.new(1, -90, 0, 30)
PositionInput.Font = Enum.Font.Gotham
PositionInput.PlaceholderText = "Enter position name..."
PositionInput.Text = ""
PositionInput.TextColor3 = Color3.fromRGB(255, 255, 255)
PositionInput.TextSize = 11

local SavePositionButton = Instance.new("TextButton")
SavePositionButton.Name = "SavePositionButton"
SavePositionButton.Parent = PositionFrame
SavePositionButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
SavePositionButton.BorderSizePixel = 0
SavePositionButton.Position = UDim2.new(1, -70, 0, 45)
SavePositionButton.Size = UDim2.new(0, 60, 0, 30)
SavePositionButton.Font = Enum.Font.Gotham
SavePositionButton.Text = "SAVE"
SavePositionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SavePositionButton.TextSize = 10

local PositionScrollFrame = Instance.new("ScrollingFrame")
PositionScrollFrame.Name = "PositionScrollFrame"
PositionScrollFrame.Parent = PositionFrame
PositionScrollFrame.BackgroundTransparency = 1
PositionScrollFrame.Position = UDim2.new(0, 10, 0, 85)
PositionScrollFrame.Size = UDim2.new(1, -20, 1, -95)
PositionScrollFrame.ScrollBarThickness = 4
PositionScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
PositionScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
PositionScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
PositionScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
PositionScrollFrame.BorderSizePixel = 0

local PositionLayout = Instance.new("UIListLayout")
PositionLayout.Parent = PositionScrollFrame
PositionLayout.Padding = UDim.new(0, 2)
PositionLayout.SortOrder = Enum.SortOrder.LayoutOrder
PositionLayout.FillDirection = Enum.FillDirection.Vertical

local LogoButton = Instance.new("TextButton")
LogoButton.Name = "LogoButton"
LogoButton.Parent = ScreenGui
LogoButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
LogoButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
LogoButton.BorderSizePixel = 1
LogoButton.Position = UDim2.new(0.05, 0, 0.1, 0)
LogoButton.Size = UDim2.new(0, 40, 0, 40)
LogoButton.Font = Enum.Font.GothamBold
LogoButton.Text = "H"
LogoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoButton.TextSize = 16
LogoButton.Visible = false
LogoButton.Active = true
LogoButton.Draggable = true

local NextSpectateButton = Instance.new("TextButton")
NextSpectateButton.Name = "NextSpectateButton"
NextSpectateButton.Parent = ScreenGui
NextSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
NextSpectateButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
NextSpectateButton.BorderSizePixel = 1
NextSpectateButton.Position = UDim2.new(0.5, 20, 0.5, 0)
NextSpectateButton.Size = UDim2.new(0, 60, 0, 30)
NextSpectateButton.Font = Enum.Font.Gotham
NextSpectateButton.Text = "NEXT >"
NextSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
NextSpectateButton.TextSize = 10
NextSpectateButton.Visible = false
NextSpectateButton.Active = true

local PrevSpectateButton = Instance.new("TextButton")
PrevSpectateButton.Name = "PrevSpectateButton"
PrevSpectateButton.Parent = ScreenGui
PrevSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
PrevSpectateButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
PrevSpectateButton.BorderSizePixel = 1
PrevSpectateButton.Position = UDim2.new(0.5, -80, 0.5, 0)
PrevSpectateButton.Size = UDim2.new(0, 60, 0, 30)
PrevSpectateButton.Font = Enum.Font.Gotham
PrevSpectateButton.Text = "< PREV"
PrevSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
PrevSpectateButton.TextSize = 10
PrevSpectateButton.Visible = false
PrevSpectateButton.Active = true

local StopSpectateButton = Instance.new("TextButton")
StopSpectateButton.Name = "StopSpectateButton"
StopSpectateButton.Parent = ScreenGui
StopSpectateButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
StopSpectateButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
StopSpectateButton.BorderSizePixel = 1
StopSpectateButton.Position = UDim2.new(0.5, -30, 0.5, 40)
StopSpectateButton.Size = UDim2.new(0, 60, 0, 30)
StopSpectateButton.Font = Enum.Font.Gotham
StopSpectateButton.Text = "STOP"
StopSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
StopSpectateButton.TextSize = 10
StopSpectateButton.Visible = false
StopSpectateButton.Active = true

local TeleportSpectateButton = Instance.new("TextButton")
TeleportSpectateButton.Name = "TeleportSpectateButton"
TeleportSpectateButton.Parent = ScreenGui
TeleportSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
TeleportSpectateButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
TeleportSpectateButton.BorderSizePixel = 1
TeleportSpectateButton.Position = UDim2.new(0.5, 40, 0.5, 40)
TeleportSpectateButton.Size = UDim2.new(0, 60, 0, 30)
TeleportSpectateButton.Font = Enum.Font.Gotham
TeleportSpectateButton.Text = "TP"
TeleportSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
TeleportSpectateButton.TextSize = 10
TeleportSpectateButton.Visible = false
TeleportSpectateButton.Active = true

-- Pass GUI elements to modules
modules.Teleport.setGuiElements({
    PositionFrame = PositionFrame,
    PositionScrollFrame = PositionScrollFrame,
    PositionLayout = PositionLayout,
    PositionInput = PositionInput
})
modules.Settings.setGuiElements({
    SettingsFrame = ContentFrame,
    SettingsScrollFrame = ScrollFrame,
    SettingsLayout = UIListLayout
})
modules.Info.setGuiElements({
    InfoFrame = ContentFrame,
    InfoScrollFrame = ScrollFrame,
    InfoLayout = UIListLayout
})
modules.AntiAdminInfo.setGuiElements({
    InfoFrame = ContentFrame,
    InfoScrollFrame = ScrollFrame,
    InfoLayout = UIListLayout
})

-- Button creation functions
local function createButton(name, callback)
    local button = Instance.new("TextButton")
    button.Name = name .. "Button"
    button.Parent = ScrollFrame
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 30)
    button.Font = Enum.Font.Gotham
    button.Text = name:upper()
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 11
    
    button.MouseButton1Click:Connect(callback)
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    end)
    
    return button
end

local function createToggleButton(name, callback)
    local button = Instance.new("TextButton")
    button.Name = name .. "Button"
    button.Parent = ScrollFrame
    button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 30)
    button.Font = Enum.Font.Gotham
    button.Text = name:upper() .. (buttonStates[name] and " [ON]" or " [OFF]")
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 11
    
    button.MouseButton1Click:Connect(function()
        buttonStates[name] = not buttonStates[name]
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(25, 25, 25)
        button.Text = name:upper() .. (buttonStates[name] and " [ON]" or " [OFF]")
        callback(buttonStates[name])
    end)
    
    button.MouseEnter:Connect(function()
        if not buttonStates[name] then
            button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(25, 25, 25)
    end)
    
    return button
end

local function createCategoryButton(name)
    local button = Instance.new("TextButton")
    button.Name = name .. "Category"
    button.Parent = CategoryFrame
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 35)
    button.Font = Enum.Font.Gotham
    button.Text = name:upper()
    button.TextColor3 = Color3.fromRGB(200, 200, 200)
    button.TextSize = 10
    
    button.MouseButton1Click:Connect(function()
        switchCategory(name)
    end)
    
    return button
end

local function clearButtons()
    for _, child in pairs(ScrollFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then
            child:Destroy()
        end
    end
end

-- Category button loaders
local function loadMovementButtons()
    createToggleButton("Fly", function(enabled)
        modules.Movement.toggleFly(enabled)
        buttonStates["Fly"] = enabled
    end)
    createToggleButton("Noclip", function(enabled)
        modules.Movement.toggleNoclip(enabled)
        buttonStates["Noclip"] = enabled
    end)
    createToggleButton("Speed", function(enabled)
        modules.Movement.toggleSpeed(enabled)
        buttonStates["Speed"] = enabled
    end)
    createToggleButton("Jump High", function(enabled)
        modules.Movement.toggleJumpHigh(enabled)
        buttonStates["Jump High"] = enabled
    end)
    createToggleButton("Spider", function(enabled)
        modules.Movement.toggleSpider(enabled)
        buttonStates["Spider"] = enabled
    end)
    createToggleButton("Player Phase", function(enabled)
        modules.Movement.togglePlayerPhase(enabled)
        buttonStates["Player Phase"] = enabled
    end)
end

local function loadPlayerButtons()
    createButton("Select Player", showPlayerSelection)
    createToggleButton("God Mode", function(enabled)
        modules.Player.toggleGodMode(enabled)
        buttonStates["God Mode"] = enabled
    end)
    createToggleButton("Anti AFK", function(enabled)
        modules.Player.toggleAntiAFK(enabled)
        buttonStates["Anti AFK"] = enabled
    end)
end

local function loadVisualButtons()
    createToggleButton("Fullbright", function(enabled)
        modules.Visual.toggleFullbright(enabled)
        buttonStates["Fullbright"] = enabled
    end)
    createToggleButton("Freecam", function(enabled)
        modules.Teleport.toggleFreecam(enabled)
        buttonStates["Freecam"] = enabled
    end)
    createToggleButton("Flashlight", function(enabled)
        modules.Visual.toggleFlashlight(enabled)
        buttonStates["Flashlight"] = enabled
    end)
    createToggleButton("Low Detail Mode", function(enabled)
        modules.Visual.toggleLowDetailMode(enabled)
        buttonStates["Low Detail Mode"] = enabled
    end)
end

local function loadTeleportButtons()
    createButton("Position Manager", function()
        PositionFrame.Visible = true
        modules.Teleport.updatePositionList()
    end)
    createButton("TP to Selected Player", function()
        if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and rootPart then
            modules.Teleport.teleportToPosition(selectedPlayer.Character.HumanoidRootPart.Position)
            print("Teleported to: " .. selectedPlayer.Name)
        else
            print("Select a player first")
        end
    end)
    createButton("TP to Freecam", function()
        modules.Teleport.teleportToFreecam()
        if modules.Teleport.freecamEnabled then
            modules.Teleport.toggleFreecam(false)
            buttonStates["Freecam"] = false
        end
        switchCategory(currentCategory)
    end)
    createButton("Save Freecam Position", function()
        local positionName = PositionInput.Text
        if positionName == "" then
            positionName = "Freecam Position " .. tostring(os.time())
        end
        modules.Teleport.saveFreecamPosition(positionName)
        PositionInput.Text = ""
    end)
    createButton("Save Player Position", function()
        local positionName = PositionInput.Text
        if positionName == "" then
            positionName = (selectedPlayer and selectedPlayer.Name or "Player") .. " Position " .. tostring(os.time())
        end
        modules.Teleport.savePlayerPosition(positionName)
        PositionInput.Text = ""
    end)
end

local function loadUtilityButtons()
    createButton("Reset Character", function()
        if humanoid then
            humanoid.Health = 0
        end
    end)
    createToggleButton("Admin Access", function(enabled)
        modules.Utility.toggleAdminAccess(enabled)
        buttonStates["Admin Access"] = enabled
    end)
    createButton("Destroy Script", cleanup)
end

local function loadSettingsButtons()
    modules.Settings.updateGui()
end

local function loadInfoButtons()
    modules.Info.updateGui()
end

local function loadAntiAdminButtons()
    modules.AntiAdminInfo.updateGui()
end

-- Category switching function
function switchCategory(categoryName)
    currentCategory = categoryName
    
    for _, child in pairs(CategoryFrame:GetChildren()) do
        if child:IsA("TextButton") then
            if child.Name == categoryName .. "Category" then
                child.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                child.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                child.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                child.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
    end
    
    clearButtons()
    
    if categoryName == "Movement" then
        loadMovementButtons()
    elseif categoryName == "Player" then
        loadPlayerButtons()
    elseif categoryName == "Visual" then
        loadVisualButtons()
    elseif categoryName == "Teleport" then
        loadTeleportButtons()
    elseif categoryName == "Utility" then
        loadUtilityButtons()
    elseif categoryName == "Settings" then
        loadSettingsButtons()
    elseif categoryName == "Info" then
        loadInfoButtons()
    elseif categoryName == "Anti Admin" then
        loadAntiAdminButtons()
    end
    
    wait(0.1)
    local contentSize = UIListLayout.AbsoluteContentSize
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 20)
end

-- Player selection and spectate functions
local function showPlayerSelection()
    playerListVisible = true
    PlayerListFrame.Visible = true
    updatePlayerList()
end

local function updateSpectateButtons()
    local isSpectating = selectedPlayer ~= nil
    NextSpectateButton.Visible = isSpectating
    PrevSpectateButton.Visible = isSpectating
    StopSpectateButton.Visible = isSpectating
    TeleportSpectateButton.Visible = isSpectating
end

local function stopSpectating()
    for _, connection in pairs(spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    spectateConnections = {}
    Workspace.CurrentCamera.CameraSubject = humanoid
    selectedPlayer = nil
    currentSpectateIndex = 0
    SelectedPlayerLabel.Text = "SELECTED: NONE"
    print("Stopped spectating")
    updateSpectateButtons()
    for _, item in pairs(PlayerListScrollFrame:GetChildren()) do
        if item:IsA("Frame") and item:FindFirstChild("SelectButton") then
            item.SelectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            item.SelectButton.Text = "SELECT PLAYER"
        end
    end
end

local function spectatePlayer(targetPlayer)
    for _, connection in pairs(spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    spectateConnections = {}
    
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
        Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
        selectedPlayer = targetPlayer
        currentSpectateIndex = table.find(spectatePlayerList, targetPlayer) or 0
        SelectedPlayerLabel.Text = "SELECTED: " .. targetPlayer.Name:upper()
        print("Spectating: " .. targetPlayer.Name)
        
        spectateConnections.died = targetPlayer.Character.Humanoid.Died:Connect(function()
            print("Spectated player died, waiting for respawn")
        end)
        
        spectateConnections.characterAdded = targetPlayer.CharacterAdded:Connect(function(newCharacter)
            local newHumanoid = newCharacter:WaitForChild("Humanoid", 5)
            if newHumanoid then
                Workspace.CurrentCamera.CameraSubject = newHumanoid
                print("Spectated player respawned, continuing spectate")
            end
        end)
        
        for _, item in pairs(PlayerListScrollFrame:GetChildren()) do
            if item:IsA("Frame") and item:FindFirstChild("SelectButton") then
                if item.Name == targetPlayer.Name .. "Item" then
                    item.SelectButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                    item.SelectButton.Text = "SELECTED"
                else
                    item.SelectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    item.SelectButton.Text = "SELECT PLAYER"
                end
            end
        end
    else
        stopSpectating()
    end
    updateSpectateButtons()
end

local function spectateNextPlayer()
    if #spectatePlayerList == 0 then
        print("No players to spectate")
        stopSpectating()
        return
    end
    
    currentSpectateIndex = currentSpectateIndex + 1
    if currentSpectateIndex > #spectatePlayerList then
        currentSpectateIndex = 1
    end
    
    local targetPlayer = spectatePlayerList[currentSpectateIndex]
    if targetPlayer then
        spectatePlayer(targetPlayer)
    else
        stopSpectating()
    end
end

local function spectatePrevPlayer()
    if #spectatePlayerList == 0 then
        print("No players to spectate")
        stopSpectating()
        return
    end
    
    currentSpectateIndex = currentSpectateIndex - 1
    if currentSpectateIndex < 1 then
        currentSpectateIndex = #spectatePlayerList
    end
    
    local targetPlayer = spectatePlayerList[currentSpectateIndex]
    if targetPlayer then
        spectatePlayer(targetPlayer)
    else
        stopSpectating()
    end
end

local function updatePlayerList()
    for _, child in pairs(PlayerListScrollFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    local previousSelectedPlayer = selectedPlayer
    spectatePlayerList = {}
    local playerCount = 0
    local players = Players:GetPlayers()
    
    if #players <= 1 then
        local noPlayersLabel = Instance.new("TextLabel")
        noPlayersLabel.Name = "NoPlayersLabel"
        noPlayersLabel.Parent = PlayerListScrollFrame
        noPlayersLabel.BackgroundTransparency = 1
        noPlayersLabel.Size = UDim2.new(1, 0, 0, 30)
        noPlayersLabel.Font = Enum.Font.Gotham
        noPlayersLabel.Text = "No other players found"
        noPlayersLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        noPlayersLabel.TextSize = 11
        noPlayersLabel.TextXAlignment = Enum.TextXAlignment.Center
        print("Player List Updated: No other players found")
    else
        for _, p in pairs(players) do
            if p ~= player and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                playerCount = playerCount + 1
                table.insert(spectatePlayerList, p)
                
                local playerItem = Instance.new("Frame")
                playerItem.Name = p.Name .. "Item"
                playerItem.Parent = PlayerListScrollFrame
                playerItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                playerItem.BorderSizePixel = 0
                playerItem.Size = UDim2.new(1, -5, 0, 90)
                playerItem.LayoutOrder = playerCount
                
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Name = "NameLabel"
                nameLabel.Parent = playerItem
                nameLabel.BackgroundTransparency = 1
                nameLabel.Position = UDim2.new(0, 5, 0, 5)
                nameLabel.Size = UDim2.new(1, -10, 0, 20)
                nameLabel.Font = Enum.Font.GothamBold
                nameLabel.Text = p.Name
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                nameLabel.TextSize = 12
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                
                local selectButton = Instance.new("TextButton")
                selectButton.Name = "SelectButton"
                selectButton.Parent = playerItem
                selectButton.BackgroundColor3 = selectedPlayer == p and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(60, 60, 60)
                selectButton.BorderSizePixel = 0
                selectButton.Position = UDim2.new(0, 5, 0, 30)
                selectButton.Size = UDim2.new(1, -10, 0, 25)
                selectButton.Font = Enum.Font.Gotham
                selectButton.Text = selectedPlayer == p and "SELECTED" or "SELECT PLAYER"
                selectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                selectButton.TextSize = 10
                
                local spectateButton = Instance.new("TextButton")
                spectateButton.Name = "SpectateButton"
                spectateButton.Parent = playerItem
                spectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
                spectateButton.BorderSizePixel = 0
                spectateButton.Position = UDim2.new(0, 5, 0, 60)
                spectateButton.Size = UDim2.new(0, 70, 0, 25)
                spectateButton.Font = Enum.Font.Gotham
                spectateButton.Text = "SPECTATE"
                spectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                spectateButton.TextSize = 9
                
                local stopSpectateButton = Instance.new("TextButton")
                stopSpectateButton.Name = "StopSpectateButton"
                stopSpectateButton.Parent = playerItem
                stopSpectateButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
                stopSpectateButton.BorderSizePixel = 0
                stopSpectateButton.Position = UDim2.new(0, 80, 0, 60)
                stopSpectateButton.Size = UDim2.new(0, 70, 0, 25)
                stopSpectateButton.Font = Enum.Font.Gotham
                stopSpectateButton.Text = "STOP"
                stopSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                stopSpectateButton.TextSize = 9
                
                local teleportButton = Instance.new("TextButton")
                teleportButton.Name = "TeleportButton"
                teleportButton.Parent = playerItem
                teleportButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
                teleportButton.BorderSizePixel = 0
                teleportButton.Position = UDim2.new(0, 155, 0, 60)
                teleportButton.Size = UDim2.new(1, -160, 0, 25)
                teleportButton.Font = Enum.Font.Gotham
                teleportButton.Text = "TELEPORT"
                teleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                teleportButton.TextSize = 9
                
                selectButton.MouseButton1Click:Connect(function()
                    selectedPlayer = p
                    currentSpectateIndex = table.find(spectatePlayerList, p) or 0
                    SelectedPlayerLabel.Text = "SELECTED: " .. p.Name:upper()
                    for _, item in pairs(PlayerListScrollFrame:GetChildren()) do
                        if item:IsA("Frame") and item:FindFirstChild("SelectButton") then
                            if item.Name == p.Name .. "Item" then
                                item.SelectButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                                item.SelectButton.Text = "SELECTED"
                            else
                                item.SelectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                                item.SelectButton.Text = "SELECT PLAYER"
                            end
                        end
                    end
                end)
                
                spectateButton.MouseButton1Click:Connect(function()
                    currentSpectateIndex = table.find(spectatePlayerList, p) or 0
                    spectatePlayer(p)
                end)
                
                stopSpectateButton.MouseButton1Click:Connect(stopSpectating)
                
                teleportButton.MouseButton1Click:Connect(function()
                    if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and rootPart then
                        modules.Teleport.teleportToPosition(p.Character.HumanoidRootPart.Position)
                        print("Teleported to: " .. p.Name)
                    end
                end)
                
                selectButton.MouseEnter:Connect(function()
                    if selectedPlayer != p then
                        selectButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                    end
                end)
                
                selectButton.MouseLeave:Connect(function()
                    if selectedPlayer != p then
                        selectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    else
                        selectButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                    end
                end)
                
                spectateButton.MouseEnter:Connect(function()
                    spectateButton.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
                end)
                
                spectateButton.MouseLeave:Connect(function()
                    spectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
                end)
                
                stopSpectateButton.MouseEnter:Connect(function()
                    stopSpectateButton.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
                end)
                
                stopSpectateButton.MouseLeave:Connect(function()
                    stopSpectateButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
                end)
                
                teleportButton.MouseEnter:Connect(function()
                    teleportButton.BackgroundColor3 = Color3.fromRGB(50, 50, 100)
                end)
                
                teleportButton.MouseLeave:Connect(function()
                    teleportButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
                end)
            end
        end
    end
    
    if previousSelectedPlayer then
        selectedPlayer = previousSelectedPlayer
        currentSpectateIndex = table.find(spectatePlayerList, selectedPlayer) or 0
        if currentSpectateIndex == 0 and selectedPlayer then
            if not (selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("Humanoid") and selectedPlayer.Character.Humanoid.Health > 0) then
                stopSpectating()
            end
        end
        SelectedPlayerLabel.Text = selectedPlayer and "SELECTED: " .. selectedPlayer.Name:upper() or "SELECTED: NONE"
    else
        currentSpectateIndex = 0
    end
    
    wait(0.1)
    local contentSize = PlayerListLayout.AbsoluteContentSize
    PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(contentSize.Y + 10, 30))
    print("Player List Updated: " .. playerCount .. " players listed")
    updateSpectateButtons()
end

-- Minimize/Maximize functions
local function minimizeGUI()
    guiMinimized = true
    MainFrame.Visible = false
    PlayerListFrame.Visible = false
    PositionFrame.Visible = false
    LogoButton.Visible = true
    updateSpectateButtons()
end

local function maximizeGUI()
    guiMinimized = false
    MainFrame.Visible = true
    LogoButton.Visible = false
    if playerListVisible then
        PlayerListFrame.Visible = true
    end
    updateSpectateButtons()
end

-- Cleanup function
function cleanup()
    for _, module in pairs(modules) do
        if module.cleanup then
            module.cleanup()
        end
    end
    for _, connection in pairs(spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    if ScreenGui then
        ScreenGui:Destroy()
    end
    print("Script cleaned up")
end

-- Initialize categories
createCategoryButton("Movement")
createCategoryButton("Player")
createCategoryButton("Visual")
createCategoryButton("Teleport")
createCategoryButton("Utility")
createCategoryButton("Settings")
createCategoryButton("Info")
createCategoryButton("Anti Admin")

-- Event Connections
MinimizeButton.MouseButton1Click:Connect(minimizeGUI)
LogoButton.MouseButton1Click:Connect(maximizeGUI)
ClosePlayerListButton.MouseButton1Click:Connect(function()
    playerListVisible = false
    PlayerListFrame.Visible = false
end)
ClosePositionButton.MouseButton1Click:Connect(function()
    PositionFrame.Visible = false
end)
SavePositionButton.MouseButton1Click:Connect(function()
    local positionName = PositionInput.Text
    if positionName == "" then
        positionName = "Position " .. tostring(os.time())
    end
    modules.Teleport.savePlayerPosition(positionName)
    PositionInput.Text = ""
end)
NextSpectateButton.MouseButton1Click:Connect(spectateNextPlayer)
PrevSpectateButton.MouseButton1Click:Connect(spectatePrevPlayer)
StopSpectateButton.MouseButton1Click:Connect(stopSpectating)
TeleportSpectateButton.MouseButton1Click:Connect(function()
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and rootPart then
        modules.Teleport.teleportToPosition(selectedPlayer.Character.HumanoidRootPart.Position)
        print("Teleported to spectated player: " .. selectedPlayer.Name)
    else
        print("Cannot teleport: No valid spectated player")
    end
end)

NextSpectateButton.MouseEnter:Connect(function()
    NextSpectateButton.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
end)
NextSpectateButton.MouseLeave:Connect(function()
    NextSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
end)
PrevSpectateButton.MouseEnter:Connect(function()
    PrevSpectateButton.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
end)
PrevSpectateButton.MouseLeave:Connect(function()
    PrevSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
end)
StopSpectateButton.MouseEnter:Connect(function()
    StopSpectateButton.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
end)
StopSpectateButton.MouseLeave:Connect(function()
    StopSpectateButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
end)
TeleportSpectateButton.MouseEnter:Connect(function()
    TeleportSpectateButton.BackgroundColor3 = Color3.fromRGB(50, 50, 100)
end)
TeleportSpectateButton.MouseLeave:Connect(function()
    TeleportSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
end)

-- Handle character reset
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    for name, _ in pairs(buttonStates) do
        buttonStates[name] = false
    end
    switchCategory(currentCategory)
end)

-- Update player list periodically
Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(function(p)
    if p == selectedPlayer then
        stopSpectating()
    end
    updatePlayerList()
end)

spawn(function()
    while true do
        updatePlayerList()
        wait(5)
    end
end)

-- Toggle GUI with LeftControl
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if input.KeyCode == Enum.KeyCode.LeftControl and not gameProcessedEvent then
        if guiMinimized then
            maximizeGUI()
        end
    end
end)

-- Initialize GUI
switchCategory("Movement")
updatePlayerList()
print("MinimalHackGUI Loaded - By Fari Noveri")

-- Opening animation
local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tween = TweenService:Create(MainFrame, tweenInfo, {Size = UDim2.new(0, 600, 0, 400)})
tween:Play()

-- Update CategoryFrame size
wait(0.1)
local categoryContentSize = CategoryList.AbsoluteContentSize
CategoryFrame.Size = UDim2.new(0, 140, 0, categoryContentSize.Y + 10)