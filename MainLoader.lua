-- mainloader.lua
-- Main entry point for MinimalHackGUI by Fari Noveri, integrating all modules

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RenderSettings = game:GetService("Settings")

-- Local Player
local player = Players.LocalPlayer
local humanoid, rootPart

-- Connections
local connections = {}
local buttonStates = {}

-- Settings
local settings = {
    FlySpeed = {value = 50, min = 10, max = 200, default = 50},
    FreecamSpeed = {value = 50, min = 10, max = 200, default = 50},
    JumpHeight = {value = 7.2, min = 0, max = 50, default = 7.2},
    WalkSpeed = {value = 16, min = 10, max = 200, default = 16}
}

-- ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MinimalHackGUI"
ScreenGui.Parent = player:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Main Frame (ukuran lebih kecil seperti gambar)
local Frame = Instance.new("Frame")
Frame.Name = "MainFrame"
Frame.Parent = ScreenGui
Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Frame.BorderSizePixel = 0
Frame.Position = UDim2.new(0.1, 0, 0.1, 0)
Frame.Size = UDim2.new(0, 650, 0, 320)
Frame.Active = true
Frame.Draggable = true

-- Corner radius kecil seperti di gambar
local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 6)
MainCorner.Parent = Frame

-- Title Bar (lebih tipis)
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Parent = Frame
TitleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
TitleBar.BorderSizePixel = 0
TitleBar.Position = UDim2.new(0, 0, 0, 0)
TitleBar.Size = UDim2.new(1, 0, 0, 30)

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 6)
TitleCorner.Parent = TitleBar

-- Fix rounded corner
local TitleFix = Instance.new("Frame")
TitleFix.Parent = TitleBar
TitleFix.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
TitleFix.BorderSizePixel = 0
TitleFix.Position = UDim2.new(0, 0, 0.6, 0)
TitleFix.Size = UDim2.new(1, 0, 0.4, 0)

-- Logo H seperti di gambar (kotak putih kecil)
local Logo = Instance.new("Frame")
Logo.Name = "Logo"
Logo.Parent = TitleBar
Logo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Logo.BorderSizePixel = 0
Logo.Position = UDim2.new(0, 8, 0.5, -6)
Logo.Size = UDim2.new(0, 12, 0, 12)

local LogoCorner = Instance.new("UICorner")
LogoCorner.CornerRadius = UDim.new(0, 2)
LogoCorner.Parent = Logo

local LogoH = Instance.new("TextLabel")
LogoH.Name = "LogoH"
LogoH.Parent = Logo
LogoH.BackgroundTransparency = 1
LogoH.Size = UDim2.new(1, 0, 1, 0)
LogoH.Font = Enum.Font.GothamBold
LogoH.Text = "H"
LogoH.TextColor3 = Color3.fromRGB(25, 25, 25)
LogoH.TextSize = 8

-- Title text persis seperti gambar
local TitleText = Instance.new("TextLabel")
TitleText.Name = "TitleText"
TitleText.Parent = TitleBar
TitleText.BackgroundTransparency = 1
TitleText.Position = UDim2.new(0, 28, 0, 0)
TitleText.Size = UDim2.new(1, -80, 1, 0)
TitleText.Font = Enum.Font.GothamBold
TitleText.Text = "HACK - By Fari Noveri [UNKNOWN BLOCK]"
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.TextSize = 10
TitleText.TextXAlignment = Enum.TextXAlignment.Left

-- Minimize & Close buttons (lebih kecil)
local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Name = "MinimizeButton"
MinimizeButton.Parent = TitleBar
MinimizeButton.BackgroundTransparency = 1
MinimizeButton.Position = UDim2.new(1, -45, 0, 3)
MinimizeButton.Size = UDim2.new(0, 20, 0, 20)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "–"
MinimizeButton.TextColor3 = Color3.fromRGB(200, 200, 200)
MinimizeButton.TextSize = 12

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Parent = TitleBar
CloseButton.BackgroundTransparency = 1
CloseButton.Position = UDim2.new(1, -22, 0, 3)
CloseButton.Size = UDim2.new(0, 20, 0, 20)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Text = "×"
CloseButton.TextColor3 = Color3.fromRGB(200, 200, 200)
CloseButton.TextSize = 14

-- Content container
local ContentContainer = Instance.new("Frame")
ContentContainer.Name = "ContentContainer"
ContentContainer.Parent = Frame
ContentContainer.BackgroundTransparency = 1
ContentContainer.Position = UDim2.new(0, 0, 0, 30)
ContentContainer.Size = UDim2.new(1, 0, 1, -30)

-- Sidebar (lebih sempit seperti gambar)
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Parent = ContentContainer
Sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Sidebar.BorderSizePixel = 0
Sidebar.Position = UDim2.new(0, 0, 0, 0)
Sidebar.Size = UDim2.new(0, 140, 1, 0)

-- Main content area
local MainContent = Instance.new("Frame")
MainContent.Name = "MainContent"
MainContent.Parent = ContentContainer
MainContent.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainContent.BorderSizePixel = 0
MainContent.Position = UDim2.new(0, 140, 0, 0)
MainContent.Size = UDim2.new(1, -140, 1, 0)

-- Content text area seperti di gambar
local ContentInfo = Instance.new("Frame")
ContentInfo.Name = "ContentInfo"
ContentInfo.Parent = MainContent
ContentInfo.BackgroundTransparency = 1
ContentInfo.Position = UDim2.new(0, 15, 0, 15)
ContentInfo.Size = UDim2.new(1, -30, 0, 80)

local InfoLine1 = Instance.new("TextLabel")
InfoLine1.Name = "InfoLine1"
InfoLine1.Parent = ContentInfo
InfoLine1.BackgroundTransparency = 1
InfoLine1.Position = UDim2.new(0, 0, 0, 0)
InfoLine1.Size = UDim2.new(1, 0, 0, 12)
InfoLine1.Font = Enum.Font.Gotham
InfoLine1.Text = "Created by Fari Noveri for Unknown Block members."
InfoLine1.TextColor3 = Color3.fromRGB(160, 160, 160)
InfoLine1.TextSize = 9
InfoLine1.TextXAlignment = Enum.TextXAlignment.Left

local InfoLine2 = Instance.new("TextLabel")
InfoLine2.Name = "InfoLine2"
InfoLine2.Parent = ContentInfo
InfoLine2.BackgroundTransparency = 1
InfoLine2.Position = UDim2.new(0, 0, 0, 12)
InfoLine2.Size = UDim2.new(1, 0, 0, 12)
InfoLine2.Font = Enum.Font.Gotham
InfoLine2.Text = "Do not sell or distribute."
InfoLine2.TextColor3 = Color3.fromRGB(140, 140, 140)
InfoLine2.TextSize = 9
InfoLine2.TextXAlignment = Enum.TextXAlignment.Left

local InfoParagraph = Instance.new("TextLabel")
InfoParagraph.Name = "InfoParagraph"
InfoParagraph.Parent = ContentInfo
InfoParagraph.BackgroundTransparency = 1
InfoParagraph.Position = UDim2.new(0, 0, 0, 30)
InfoParagraph.Size = UDim2.new(1, 0, 0, 45)
InfoParagraph.Font = Enum.Font.Gotham
InfoParagraph.Text = "This script is designed for exclusive use by the Unknown Block community to enhance gameplay experiences in Roblox. Please respect the community by using it responsibly and only within the intended group. Unauthorized sharing or commercial use is strictly prohibited."
InfoParagraph.TextColor3 = Color3.fromRGB(120, 120, 120)
InfoParagraph.TextSize = 8
InfoParagraph.TextXAlignment = Enum.TextXAlignment.Left
InfoParagraph.TextYAlignment = Enum.TextYAlignment.Top
InfoParagraph.TextWrapped = true

-- Content scroll untuk buttons
local ContentScroll = Instance.new("ScrollingFrame")
ContentScroll.Name = "ContentScroll"
ContentScroll.Parent = MainContent
ContentScroll.BackgroundTransparency = 1
ContentScroll.Position = UDim2.new(0, 15, 0, 100)
ContentScroll.Size = UDim2.new(1, -30, 1, -115)
ContentScroll.ScrollBarThickness = 3
ContentScroll.ScrollBarImageColor3 = Color3.fromRGB(50, 50, 50)
ContentScroll.ScrollingDirection = Enum.ScrollingDirection.Y
ContentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Parent = ContentScroll
ContentLayout.Padding = UDim.new(0, 3)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.FillDirection = Enum.FillDirection.Vertical

-- Categories (seperti gambar, text kecil)
local categories = {
    {name = "MOVEMENT", id = "Movement", pos = 0},
    {name = "PLAYER", id = "Player", pos = 1},
    {name = "VISUAL", id = "Visual", pos = 2},
    {name = "TELEPORT", id = "Teleport", pos = 3},
    {name = "UTILITY", id = "Utility", pos = 4},
    {name = "INFO", id = "Info", pos = 5}
}

local categoryButtons = {}
local selectedCategory = "Movement"

-- Create category buttons persis seperti gambar
for _, category in ipairs(categories) do
    local categoryButton = Instance.new("TextButton")
    categoryButton.Name = category.id .. "Button"
    categoryButton.Parent = Sidebar
    categoryButton.BackgroundColor3 = category.id == selectedCategory and Color3.fromRGB(45, 45, 45) or Color3.fromRGB(20, 20, 20)
    categoryButton.BorderSizePixel = 0
    categoryButton.Position = UDim2.new(0, 0, 0, category.pos * 35 + 10)
    categoryButton.Size = UDim2.new(1, 0, 0, 30)
    categoryButton.Font = Enum.Font.GothamBold
    categoryButton.Text = category.name
    categoryButton.TextColor3 = category.id == selectedCategory and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(140, 140, 140)
    categoryButton.TextSize = 9
    categoryButton.TextXAlignment = Enum.TextXAlignment.Left
    categoryButton.TextXOffset = 15
    
    categoryButtons[category.id] = categoryButton
end

-- Minimized logo
local MinimizedLogo = Instance.new("Frame")
MinimizedLogo.Name = "MinimizedLogo"
MinimizedLogo.Parent = ScreenGui
MinimizedLogo.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MinimizedLogo.BorderSizePixel = 0
MinimizedLogo.Position = UDim2.new(0, 10, 0, 10)
MinimizedLogo.Size = UDim2.new(0, 35, 0, 35)
MinimizedLogo.Visible = false
MinimizedLogo.Active = true
MinimizedLogo.Draggable = true

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 17)
MinCorner.Parent = MinimizedLogo

local MinLogoText = Instance.new("TextLabel")
MinLogoText.Name = "LogoText"
MinLogoText.Parent = MinimizedLogo
MinLogoText.BackgroundTransparency = 1
MinLogoText.Size = UDim2.new(1, 0, 1, 0)
MinLogoText.Font = Enum.Font.GothamBold
MinLogoText.Text = "H"
MinLogoText.TextColor3 = Color3.fromRGB(255, 255, 255)
MinLogoText.TextSize = 14

local MinLogoButton = Instance.new("TextButton")
MinLogoButton.Name = "LogoButton"
MinLogoButton.Parent = MinimizedLogo
MinLogoButton.BackgroundTransparency = 1
MinLogoButton.Size = UDim2.new(1, 0, 1, 0)
MinLogoButton.Text = ""

-- Module URLs
local moduleURLs = {
    Movement = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement.lua",
    Player = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Player.lua",
    Teleport = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Teleport.lua",
    Visual = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Visual.lua",
    Utility = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Utility.lua",
    Settings = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Settings.lua",
    Info = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Info.lua",
    AntiAdminInfo = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/AntiAdminInfo.lua",
    AntiAdmin = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/AntiAdmin.lua"
}

-- Load modules
local modules = {}
local function loadModule(moduleName)
    local success, result = pcall(function()
        local response = game:HttpGet(moduleURLs[moduleName])
        return loadstring(response)()
    end)
    if success and result then
        modules[moduleName] = result
        print("Successfully loaded module: " .. moduleName)
        return true
    else
        warn("Failed to load module " .. moduleName .. ": " .. tostring(result))
        return false
    end
end

for moduleName, _ in pairs(moduleURLs) do
    loadModule(moduleName)
end

-- Dependencies
local dependencies = {
    Players = Players,
    UserInputService = UserInputService,
    RunService = RunService,
    Workspace = Workspace,
    Lighting = Lighting,
    RenderSettings = RenderSettings,
    ScreenGui = ScreenGui,
    settings = settings,
    connections = connections,
    buttonStates = buttonStates,
    player = player,
    humanoid = humanoid,
    rootPart = rootPart
}

-- Initialize modules
for moduleName, module in pairs(modules) do
    if module and type(module.init) == "function" then
        local success, err = pcall(function()
            module.init(dependencies)
        end)
        if not success then
            warn("Failed to initialize module " .. moduleName .. ": " .. tostring(err))
        end
    end
end

-- Button helpers (ukuran kecil seperti gambar)
local function createButton(name, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Parent = ContentScroll
    button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -8, 0, 25)
    button.Font = Enum.Font.Gotham
    button.Text = name
    button.TextColor3 = Color3.fromRGB(220, 220, 220)
    button.TextSize = 8
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 3)
    buttonCorner.Parent = button
    
    button.MouseButton1Click:Connect(callback)
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    end)
    
    wait(0.01)
    ContentScroll.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y + 10)
end

local function createToggleButton(name, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Parent = ContentScroll
    button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -8, 0, 25)
    button.Font = Enum.Font.Gotham
    button.Text = name
    button.TextColor3 = Color3.fromRGB(220, 220, 220)
    button.TextSize = 8
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 3)
    buttonCorner.Parent = button
    
    buttonStates[name] = false
    
    button.MouseButton1Click:Connect(function()
        buttonStates[name] = not buttonStates[name]
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(60, 130, 60) or Color3.fromRGB(45, 45, 45)
        if type(callback) == "function" then
            callback(buttonStates[name])
        end
    end)
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(70, 150, 70) or Color3.fromRGB(55, 55, 55)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(60, 130, 60) or Color3.fromRGB(45, 45, 45)
    end)
    
    wait(0.01)
    ContentScroll.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y + 10)
end

-- Load category buttons
local function loadCategoryButtons(categoryId)
    for _, child in pairs(ContentScroll:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    if categoryId == "Movement" and modules.Movement and type(modules.Movement.loadMovementButtons) == "function" then
        local success, err = pcall(function()
            modules.Movement.loadMovementButtons(createToggleButton)
        end)
        if not success then
            warn("Error loading Movement buttons: " .. tostring(err))
        end
    elseif categoryId == "Player" and modules.Player and type(modules.Player.loadPlayerButtons) == "function" then
        local success, err = pcall(function()
            local selectedPlayer = nil
            if type(modules.Player.getSelectedPlayer) == "function" then
                selectedPlayer = modules.Player.getSelectedPlayer()
            end
            modules.Player.loadPlayerButtons(createButton, createToggleButton, selectedPlayer)
        end)
        if not success then
            warn("Error loading Player buttons: " .. tostring(err))
        end
    elseif categoryId == "Visual" and modules.Visual and type(modules.Visual.loadVisualButtons) == "function" then
        local success, err = pcall(function()
            modules.Visual.loadVisualButtons(createToggleButton)
        end)
        if not success then
            warn("Error loading Visual buttons: " .. tostring(err))
        end
    elseif categoryId == "Teleport" and modules.Teleport and type(modules.Teleport.loadTeleportButtons) == "function" then
        local success, err = pcall(function()
            local selectedPlayer = nil
            if modules.Player and type(modules.Player.getSelectedPlayer) == "function" then
                selectedPlayer = modules.Player.getSelectedPlayer()
            end
            
            local freecamEnabled, freecamPosition = false, nil
            if modules.Visual and type(modules.Visual.getFreecamState) == "function" then
                freecamEnabled, freecamPosition = modules.Visual.getFreecamState()
            end
            
            local toggleFreecam = function() end
            if modules.Visual and type(modules.Visual.toggleFreecam) == "function" then
                toggleFreecam = modules.Visual.toggleFreecam
            end
            
            modules.Teleport.loadTeleportButtons(createButton, selectedPlayer, freecamEnabled, freecamPosition, toggleFreecam)
        end)
        if not success then
            warn("Error loading Teleport buttons: " .. tostring(err))
        end
    elseif categoryId == "Utility" and modules.Utility and type(modules.Utility.loadUtilityButtons) == "function" then
        local success, err = pcall(function()
            modules.Utility.loadUtilityButtons(createButton)
        end)
        if not success then
            warn("Error loading Utility buttons: " .. tostring(err))
        end
    elseif categoryId == "Info" and modules.Info and type(modules.Info.loadInfoButtons) == "function" then
        local success, err = pcall(function()
            modules.Info.loadInfoButtons(createButton)
        end)
        if not success then
            warn("Error loading Info buttons: " .. tostring(err))
        end
    end
end

-- Category selection
local function selectCategory(categoryId)
    selectedCategory = categoryId
    
    for id, button in pairs(categoryButtons) do
        if id == categoryId then
            button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            button.TextColor3 = Color3.fromRGB(140, 140, 140)
        end
    end
    
    loadCategoryButtons(categoryId)
end

-- Connect category buttons
for id, button in pairs(categoryButtons) do
    button.MouseButton1Click:Connect(function()
        selectCategory(id)
    end)
    
    button.MouseEnter:Connect(function()
        if id ~= selectedCategory then
            button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            button.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
    end)
    
    button.MouseLeave:Connect(function()
        if id ~= selectedCategory then
            button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            button.TextColor3 = Color3.fromRGB(140, 140, 140)
        end
    end)
end

-- Minimize functionality
local isMinimized = false
local function toggleMinimize()
    isMinimized = not isMinimized
    if isMinimized then
        Frame.Visible = false
        MinimizedLogo.Visible = true
    else
        Frame.Visible = true
        MinimizedLogo.Visible = false
    end
end

-- Rest of functions (character setup, etc.)
local function resetStates()
    humanoid = nil
    rootPart = nil
    for _, connection in pairs(connections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
    connections = {}
    buttonStates = {}
    
    for _, module in pairs(modules) do
        if module and type(module.resetStates) == "function" then
            local success, err = pcall(function()
                module.resetStates()
            end)
            if not success then
                warn("Error resetting module state: " .. tostring(err))
            end
        end
    end
    
    loadCategoryButtons(selectedCategory)
end

local function onCharacterAdded(character)
    if not character then return end
    
    local success, err = pcall(function()
        humanoid = character:FindFirstChild("Humanoid")
        rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if not humanoid then
            humanoid = character:WaitForChild("Humanoid", 30)
        end
        
        if not rootPart then
            rootPart = character:WaitForChild("HumanoidRootPart", 30)
        end
        
        if not humanoid or not rootPart then
            return
        end
        
        dependencies.humanoid = humanoid
        dependencies.rootPart = rootPart
        
        if humanoid and typeof(humanoid) == "Instance" and humanoid.Died then
            connections.humanoidDied = humanoid.Died:Connect(function()
                resetStates()
            end)
        end
        
        resetStates()
    end)
    
    if not success then
        warn("Error in onCharacterAdded: " .. tostring(err))
    end
end

-- Initialize
if player.Character then
    onCharacterAdded(player.Character)
end
connections.characterAdded = player.CharacterAdded:Connect(onCharacterAdded)

loadCategoryButtons(selectedCategory)

-- Event connections
MinimizeButton.MouseButton1Click:Connect(toggleMinimize)
MinLogoButton.MouseButton1Click:Connect(toggleMinimize)
CloseButton.MouseButton1Click:Connect(function()
    Frame.Visible = false
    MinimizedLogo.Visible = false
end)

-- Hover effects untuk minimize/close
MinimizeButton.MouseEnter:Connect(function()
    MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
end)
MinimizeButton.MouseLeave:Connect(function()
    MinimizeButton.TextColor3 = Color3.fromRGB(200, 200, 200)
end)

CloseButton.MouseEnter:Connect(function()
    CloseButton.TextColor3 = Color3.fromRGB(255, 100, 100)
end)
CloseButton.MouseLeave:Connect(function()
    CloseButton.TextColor3 = Color3.fromRGB(200, 200, 200)
end)

-- Toggle GUI
connections.toggleGui = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Home then
        if Frame.Visible or MinimizedLogo.Visible then
            Frame.Visible = false
            MinimizedLogo.Visible = false
        else
            Frame.Visible = true
            MinimizedLogo.Visible = false
            isMinimized = false
        end
    end
end)