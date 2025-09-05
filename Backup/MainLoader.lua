-- MinimalHackGUI by Fari Noveri - ANTI-DETECTION VERSION

-- ========== ANTI-DETECTION SYSTEM ==========
local function generateRandomName()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local name = ""
    for i = 1, math.random(8, 12) do
        name = name .. chars:sub(math.random(1, #chars), math.random(1, #chars))
    end
    return name
end

local legitimateNames = {
    "PlayerInterface", "GameSettings", "NotificationCenter", 
    "PlayerStats", "GameHelper", "UIManager", "PlayerTools"
}

-- Admin detection
local adminKeywords = {"admin", "mod", "moderator", "owner", "dev", "staff"}
local stealthMode = false
local emergencyHidden = false

local function isLikelyAdmin(playerName)
    local lower = playerName:lower()
    for _, keyword in pairs(adminKeywords) do
        if lower:find(keyword) then return true end
    end
    return false
end

-- ========== SERVICES ==========
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

-- ========== VARIABLES ==========
local player = Players.LocalPlayer
local character, humanoid, rootPart
local connections = {}
local buttonStates = {}
local selectedCategory = "Movement"
local categoryStates = {}
local activeFeature = nil

-- Settings
local settings = {
    FlySpeed = {value = 50, min = 10, max = 200, default = 50},
    FreecamSpeed = {value = 50, min = 10, max = 200, default = 50},
    JumpHeight = {value = 7.2, min = 0, max = 50, default = 7.2},
    WalkSpeed = {value = 16, min = 10, max = 200, default = 16}
}

-- ========== STEALTH SCREENGUI SETUP ==========
-- Clean up existing instances
pcall(function()
    for _, gui in pairs(player.PlayerGui:GetChildren()) do
        if gui.Name:find("MinimalHackGUI") or gui.Name:find("Hack") then
            gui:Destroy()
        end
    end
    for _, gui in pairs(CoreGui:GetChildren()) do
        if gui.Name:find("MinimalHackGUI") or gui.Name:find("Hack") then
            gui:Destroy()
        end
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = legitimateNames[math.random(1, #legitimateNames)] .. "_" .. generateRandomName()
ScreenGui.Parent = CoreGui  -- Use CoreGui instead of PlayerGui for stealth
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = math.random(-50, -10)
ScreenGui.Enabled = true

-- ========== GUI ELEMENTS ==========
local Frame = Instance.new("Frame")
Frame.Name = generateRandomName()
Frame.Parent = ScreenGui
Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Frame.BorderColor3 = Color3.fromRGB(45, 45, 45)
Frame.BorderSizePixel = 1
Frame.Position = UDim2.new(0.5, -250, 0.5, -150)
Frame.Size = UDim2.new(0, 500, 0, 300)
Frame.Active = true
Frame.Draggable = true

local Title = Instance.new("TextLabel")
Title.Parent = Frame
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.BorderSizePixel = 0
Title.Size = UDim2.new(1, 0, 0, 25)
Title.Font = Enum.Font.Gotham
Title.Text = "Game Interface v2.1" -- Innocent looking title
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 10

-- Minimized state
local MinimizedLogo = Instance.new("Frame")
MinimizedLogo.Name = generateRandomName()
MinimizedLogo.Parent = ScreenGui
MinimizedLogo.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MinimizedLogo.BorderColor3 = Color3.fromRGB(45, 45, 45)
MinimizedLogo.Position = UDim2.new(0, 5, 0, 5)
MinimizedLogo.Size = UDim2.new(0, 30, 0, 30)
MinimizedLogo.Visible = false
MinimizedLogo.Active = true
MinimizedLogo.Draggable = true

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 12)
Corner.Parent = MinimizedLogo

local LogoText = Instance.new("TextLabel")
LogoText.Parent = MinimizedLogo
LogoText.BackgroundTransparency = 1
LogoText.Size = UDim2.new(1, 0, 1, 0)
LogoText.Font = Enum.Font.GothamBold
LogoText.Text = "G" -- Change from "H" to look less suspicious
LogoText.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoText.TextSize = 12

local LogoButton = Instance.new("TextButton")
LogoButton.Parent = MinimizedLogo
LogoButton.BackgroundTransparency = 1
LogoButton.Size = UDim2.new(1, 0, 1, 0)
LogoButton.Text = ""

-- Minimize button
local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Parent = Frame
MinimizeButton.BackgroundTransparency = 1
MinimizeButton.Position = UDim2.new(1, -20, 0, 5)
MinimizeButton.Size = UDim2.new(0, 20, 0, 20)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "-"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextSize = 10

-- Category container
local CategoryContainer = Instance.new("ScrollingFrame")
CategoryContainer.Parent = Frame
CategoryContainer.BackgroundTransparency = 1
CategoryContainer.Position = UDim2.new(0, 5, 0, 30)
CategoryContainer.Size = UDim2.new(0, 80, 1, -35)
CategoryContainer.ScrollBarThickness = 4
CategoryContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
CategoryContainer.ScrollingDirection = Enum.ScrollingDirection.Y
CategoryContainer.CanvasSize = UDim2.new(0, 0, 0, 0)

local CategoryLayout = Instance.new("UIListLayout")
CategoryLayout.Parent = CategoryContainer
CategoryLayout.Padding = UDim.new(0, 3)
CategoryLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Feature container
local FeatureContainer = Instance.new("ScrollingFrame")
FeatureContainer.Parent = Frame
FeatureContainer.BackgroundTransparency = 1
FeatureContainer.Position = UDim2.new(0, 90, 0, 30)
FeatureContainer.Size = UDim2.new(1, -95, 1, -35)
FeatureContainer.ScrollBarThickness = 4
FeatureContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
FeatureContainer.ScrollingDirection = Enum.ScrollingDirection.Y
FeatureContainer.CanvasSize = UDim2.new(0, 0, 0, 0)

local FeatureLayout = Instance.new("UIListLayout")
FeatureLayout.Parent = FeatureContainer
FeatureLayout.Padding = UDim.new(0, 2)
FeatureLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- ========== ANTI-DETECTION HTTP SYSTEM ==========
local function safeHttpGet(url, maxRetries)
    maxRetries = maxRetries or 2
    local baseDelay = math.random(1, 3)
    
    for attempt = 1, maxRetries do
        local success, result = pcall(function()
            wait(baseDelay * attempt) -- Progressive delay
            return game:HttpGet(url)
        end)
        
        if success and result and #result > 100 and not result:find("404") then
            return result
        end
        
        if attempt < maxRetries then
            wait(math.random(2, 5)) -- Random delay between retries
        end
    end
    
    return nil
end

-- ========== STEALTH FUNCTIONS ==========
local function enableEmergencyMode()
    if emergencyHidden then return end
    emergencyHidden = true
    
    -- Completely hide the GUI
    ScreenGui.Enabled = false
    
    -- Clear any global references
    pcall(function()
        _G.MinimalHackGUI = nil
        getgenv().MinimalHackGUI = nil
    end)
    
    print("Emergency mode activated - GUI hidden")
end

local function disableEmergencyMode()
    if not emergencyHidden then return end
    emergencyHidden = false
    ScreenGui.Enabled = true
    print("Emergency mode deactivated - GUI restored")
end

local function toggleStealthMode()
    stealthMode = not stealthMode
    
    if stealthMode then
        Frame.BackgroundTransparency = 0.8
        Title.Text = "System Monitor"
        for _, child in pairs(Frame:GetDescendants()) do
            if child:IsA("TextButton") or child:IsA("TextLabel") then
                child.TextTransparency = 0.7
            end
        end
    else
        Frame.BackgroundTransparency = 0
        Title.Text = "Game Interface v2.1"
        for _, child in pairs(Frame:GetDescendants()) do
            if child:IsA("TextButton") or child:IsA("TextLabel") then
                child.TextTransparency = 0
            end
        end
    end
end

-- ========== ADMIN DETECTION ==========
local function checkForAdmins()
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and isLikelyAdmin(p.Name) then
            enableEmergencyMode()
            return
        end
    end
end

-- Monitor for admin joins
Players.PlayerAdded:Connect(function(newPlayer)
    if isLikelyAdmin(newPlayer.Name) then
        enableEmergencyMode()
    end
end)

-- ========== IMPROVED MODULE LOADING ==========
local modules = {}
local modulesLoaded = {}

local moduleURLs = {
    Movement = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Movement.lua",
    Player = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Player.lua",
    Teleport = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Teleport.lua",
    Visual = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Visual.lua",
    Utility = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Utility.lua",
    AntiAdmin = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/AntiAdmin.lua",
    Settings = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Settings.lua",
    Info = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Info.lua"
}

local function loadModule(moduleName)
    if modulesLoaded[moduleName] then return true end
    
    local success, result = pcall(function()
        local response = safeHttpGet(moduleURLs[moduleName], 3)
        if not response then
            error("Failed to fetch module")
        end
        
        local moduleFunc, loadError = loadstring(response)
        if not moduleFunc then
            error("Compilation failed: " .. tostring(loadError))
        end
        
        local moduleTable = moduleFunc()
        if type(moduleTable) ~= "table" then
            error("Invalid module format")
        end
        
        return moduleTable
    end)
    
    if success then
        modules[moduleName] = result
        modulesLoaded[moduleName] = true
        return true
    end
    
    return false
end

-- ========== DEPENDENCIES ==========
local dependencies = {
    Players = Players,
    UserInputService = UserInputService,
    RunService = RunService,
    Workspace = Workspace,
    Lighting = Lighting,
    ScreenGui = ScreenGui,
    ScrollFrame = FeatureContainer,
    settings = settings,
    connections = connections,
    buttonStates = buttonStates,
    player = player
}

-- ========== GUI FUNCTIONS ==========
local categoryFrames = {}
local isMinimized = false

local categories = {
    {name = "Movement", order = 1},
    {name = "Player", order = 2},
    {name = "Teleport", order = 3},
    {name = "Visual", order = 4},
    {name = "Utility", order = 5},
    {name = "AntiAdmin", order = 6},
    {name = "Settings", order = 7},
    {name = "Info", order = 8}
}

local function createButton(name, callback, categoryName)
    local button = Instance.new("TextButton")
    button.Name = generateRandomName()
    button.Parent = FeatureContainer
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -2, 0, 20)
    button.Font = Enum.Font.Gotham
    button.Text = name
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 8
    button.LayoutOrder = #FeatureContainer:GetChildren()
    
    if callback then
        button.MouseButton1Click:Connect(function()
            pcall(callback)
        end)
    end
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end)
    
    return button
end

local function createToggleButton(name, callback, categoryName, disableCallback)
    local button = createButton(name, nil, categoryName)
    
    if not categoryStates[categoryName] then
        categoryStates[categoryName] = {}
    end
    
    if categoryStates[categoryName][name] == nil then
        categoryStates[categoryName][name] = false
    end
    
    local function updateButton()
        local isActive = categoryStates[categoryName][name]
        button.BackgroundColor3 = isActive and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    end
    
    button.MouseButton1Click:Connect(function()
        local newState = not categoryStates[categoryName][name]
        categoryStates[categoryName][name] = newState
        updateButton()
        
        if callback then
            pcall(callback, newState)
        end
    end)
    
    updateButton()
    return button
end

local function loadButtons()
    -- Clear existing buttons
    for _, child in pairs(FeatureContainer:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    -- Update category highlights
    for categoryName, categoryData in pairs(categoryFrames) do
        if categoryData and categoryData.button then
            categoryData.button.BackgroundColor3 = categoryName == selectedCategory and 
                Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25)
        end
    end
    
    if not modules[selectedCategory] then
        local loadingLabel = Instance.new("TextLabel")
        loadingLabel.Parent = FeatureContainer
        loadingLabel.BackgroundTransparency = 1
        loadingLabel.Size = UDim2.new(1, -2, 0, 20)
        loadingLabel.Font = Enum.Font.Gotham
        loadingLabel.Text = "Loading " .. selectedCategory .. "..."
        loadingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        loadingLabel.TextSize = 8
        
        -- Try loading the module
        task.spawn(function()
            if loadModule(selectedCategory) then
                wait(1)
                loadButtons()
            end
        end)
        return
    end
    
    -- Load module buttons
    local module = modules[selectedCategory]
    local success = pcall(function()
        if selectedCategory == "Movement" and module.loadMovementButtons then
            module.loadMovementButtons(createButton, createToggleButton)
        elseif selectedCategory == "Visual" and module.loadVisualButtons then
            module.loadVisualButtons(createToggleButton)
        -- Add other modules similarly...
        end
    end)
    
    if not success then
        local errorLabel = Instance.new("TextLabel")
        errorLabel.Parent = FeatureContainer
        errorLabel.BackgroundTransparency = 1
        errorLabel.Size = UDim2.new(1, -2, 0, 40)
        errorLabel.Font = Enum.Font.Gotham
        errorLabel.Text = "Error loading " .. selectedCategory
        errorLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        errorLabel.TextSize = 8
        errorLabel.TextWrapped = true
    end
end

-- ========== CREATE CATEGORIES ==========
for _, category in ipairs(categories) do
    local categoryButton = Instance.new("TextButton")
    categoryButton.Name = generateRandomName()
    categoryButton.Parent = CategoryContainer
    categoryButton.BackgroundColor3 = selectedCategory == category.name and 
        Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25)
    categoryButton.BorderSizePixel = 0
    categoryButton.Size = UDim2.new(1, -5, 0, 25)
    categoryButton.LayoutOrder = category.order
    categoryButton.Font = Enum.Font.GothamBold
    categoryButton.Text = category.name
    categoryButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    categoryButton.TextSize = 8

    categoryButton.MouseButton1Click:Connect(function()
        selectedCategory = category.name
        loadButtons()
    end)

    categoryButton.MouseEnter:Connect(function()
        if selectedCategory ~= category.name then
            categoryButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
    end)

    categoryButton.MouseLeave:Connect(function()
        if selectedCategory ~= category.name then
            categoryButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        end
    end)

    categoryFrames[category.name] = {button = categoryButton}
    categoryStates[category.name] = {}
end

-- ========== ANTI-DETECTION KEYBINDS ==========
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    -- Emergency hide: Alt + H
    if input.KeyCode == Enum.KeyCode.H and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
        enableEmergencyMode()
    
    -- Emergency restore: Alt + J  
    elseif input.KeyCode == Enum.KeyCode.J and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
        disableEmergencyMode()
    
    -- Stealth mode: Alt + S
    elseif input.KeyCode == Enum.KeyCode.S and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
        toggleStealthMode()
    
    -- Normal toggle: Home
    elseif input.KeyCode == Enum.KeyCode.Home then
        if not emergencyHidden then
            isMinimized = not isMinimized
            Frame.Visible = not isMinimized
            MinimizedLogo.Visible = isMinimized
        end
    end
end)

-- ========== CHARACTER SETUP ==========
local function onCharacterAdded(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid", 30)
    rootPart = character:WaitForChild("HumanoidRootPart", 30)
    
    dependencies.character = character
    dependencies.humanoid = humanoid
    dependencies.rootPart = rootPart
    
    -- Update modules
    for _, module in pairs(modules) do
        if module and module.updateReferences then
            pcall(module.updateReferences)
        end
    end
end

if player.Character then
    onCharacterAdded(player.Character)
end
connections.characterAdded = player.CharacterAdded:Connect(onCharacterAdded)

-- ========== MINIMIZE FUNCTIONS ==========
local function toggleMinimize()
    if emergencyHidden then return end
    isMinimized = not isMinimized
    Frame.Visible = not isMinimized
    MinimizedLogo.Visible = isMinimized
end

MinimizeButton.MouseButton1Click:Connect(toggleMinimize)
LogoButton.MouseButton1Click:Connect(toggleMinimize)

-- ========== STARTUP ==========
task.spawn(function()
    -- Check for admins immediately
    checkForAdmins()
    
    -- Load modules with staggered delays
    local moduleNames = {}
    for name, _ in pairs(moduleURLs) do
        table.insert(moduleNames, name)
    end
    
    for i, moduleName in ipairs(moduleNames) do
        task.spawn(function()
            wait(i * 0.5) -- Stagger loading
            loadModule(moduleName)
            if selectedCategory == moduleName then
                wait(1)
                loadButtons()
            end
        end)
    end
    
    -- Initialize dependencies for loaded modules
    wait(3)
    for _, module in pairs(modules) do
        if module and module.init then
            pcall(module.init, dependencies)
        end
    end
    
    -- Load initial category
    wait(1)
    loadButtons()
    
    -- Periodic admin check
    task.spawn(function()
        while ScreenGui.Parent do
            checkForAdmins()
            wait(30) -- Check every 30 seconds
        end
    end)
end)

-- ========== CANVAS SIZE UPDATES ==========
CategoryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    CategoryContainer.CanvasSize = UDim2.new(0, 0, 0, CategoryLayout.AbsoluteContentSize.Y + 10)
end)

FeatureLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    FeatureContainer.CanvasSize = UDim2.new(0, 0, 0, FeatureLayout.AbsoluteContentSize.Y + 10)
end)

print("Enhanced Anti-Detection GUI Loaded")
print("Keybinds:")
print("- Alt + H: Emergency Hide")
print("- Alt + J: Emergency Restore") 
print("- Alt + S: Toggle Stealth Mode")
print("- Home: Toggle Minimize")