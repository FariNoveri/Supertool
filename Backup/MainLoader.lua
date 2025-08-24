-- Main entry point for MinimalHackGUI by Fari Noveri - FIXED VERSION

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

-- Safety checks
if not Players or not UserInputService or not RunService or not Workspace or not Lighting then
    error("Required services not available")
end

-- Local Player
local player = Players.LocalPlayer
if not player then
    error("LocalPlayer not found")
end

local character, humanoid, rootPart

-- Connections and states
local connections = {}
local buttonStates = {}
local selectedCategory = "Movement"
local categoryStates = {} -- Store feature states per category
local activeFeature = nil -- Track currently active exclusive feature
local exclusiveFeatures = {} -- List of features that should be exclusive

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
ScreenGui.Enabled = true

-- Check for existing script instances
for _, gui in pairs(player.PlayerGui:GetChildren()) do
    if gui:IsA("ScreenGui") and gui.Name == "MinimalHackGUI" and gui ~= ScreenGui then
        gui:Destroy()
    end
end

-- Main Frame
local Frame = Instance.new("Frame")
Frame.Name = "MainFrame"
Frame.Parent = ScreenGui
Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Frame.BorderColor3 = Color3.fromRGB(45, 45, 45)
Frame.BorderSizePixel = 1
Frame.Position = UDim2.new(0.5, -250, 0.5, -150)
Frame.Size = UDim2.new(0, 500, 0, 300)
Frame.Active = true
Frame.Draggable = true

-- Title
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Parent = Frame
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.BorderSizePixel = 0
Title.Size = UDim2.new(1, 0, 0, 25)
Title.Font = Enum.Font.Gotham
Title.Text = "MinimalHackGUI by Fari Noveri [Backup] - FIXED"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 10

-- Minimized Logo
local MinimizedLogo = Instance.new("Frame")
MinimizedLogo.Name = "MinimizedLogo"
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
LogoText.Text = "H"
LogoText.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoText.TextSize = 12
LogoText.TextStrokeTransparency = 0.5
LogoText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

local LogoButton = Instance.new("TextButton")
LogoButton.Parent = MinimizedLogo
LogoButton.BackgroundTransparency = 1
LogoButton.Size = UDim2.new(1, 0, 1, 0)
LogoButton.Text = ""

-- Minimize Button
local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Parent = Frame
MinimizeButton.BackgroundTransparency = 1
MinimizeButton.Position = UDim2.new(1, -20, 0, 5)
MinimizeButton.Size = UDim2.new(0, 20, 0, 20)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "-"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextSize = 10

-- Category Container with Scrolling
local CategoryContainer = Instance.new("ScrollingFrame")
CategoryContainer.Parent = Frame
CategoryContainer.BackgroundTransparency = 1
CategoryContainer.Position = UDim2.new(0, 5, 0, 30)
CategoryContainer.Size = UDim2.new(0, 80, 1, -35)
CategoryContainer.ScrollBarThickness = 4
CategoryContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
CategoryContainer.ScrollingDirection = Enum.ScrollingDirection.Y
CategoryContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
CategoryContainer.CanvasSize = UDim2.new(0, 0, 0, 0)

local CategoryLayout = Instance.new("UIListLayout")
CategoryLayout.Parent = CategoryContainer
CategoryLayout.Padding = UDim.new(0, 3)
CategoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
CategoryLayout.FillDirection = Enum.FillDirection.Vertical

-- Update category canvas size when content changes
CategoryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    CategoryContainer.CanvasSize = UDim2.new(0, 0, 0, CategoryLayout.AbsoluteContentSize.Y + 10)
end)

-- Feature Container
local FeatureContainer = Instance.new("ScrollingFrame")
FeatureContainer.Parent = Frame
FeatureContainer.BackgroundTransparency = 1
FeatureContainer.Position = UDim2.new(0, 90, 0, 30)
FeatureContainer.Size = UDim2.new(1, -95, 1, -35)
FeatureContainer.ScrollBarThickness = 4
FeatureContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
FeatureContainer.ScrollingDirection = Enum.ScrollingDirection.Y
FeatureContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
FeatureContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
FeatureContainer.Visible = true

local FeatureLayout = Instance.new("UIListLayout")
FeatureLayout.Parent = FeatureContainer
FeatureLayout.Padding = UDim.new(0, 2)
FeatureLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Update feature canvas size when content changes
FeatureLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    FeatureContainer.CanvasSize = UDim2.new(0, 0, 0, FeatureLayout.AbsoluteContentSize.Y + 10)
end)

-- Categories
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

local categoryFrames = {}
local isMinimized = false

-- Load modules
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

-- Fallback AntiAdmin module (basic implementation)
local AntiAdminModule = {
    init = function(deps)
        print("AntiAdmin module initialized (fallback)")
        return true
    end,
    loadAntiAdminButtons = function(createToggleButton, container)
        createToggleButton("Anti-Kick", function(enabled)
            print("Anti-Kick toggled:", enabled)
        end)
        createToggleButton("Anti-Ban", function(enabled)
            print("Anti-Ban toggled:", enabled)
        end)
    end,
    resetStates = function()
        print("AntiAdmin states reset")
    end
}

-- Enhanced module loading with better error handling
local function loadModule(moduleName)
    if not moduleURLs[moduleName] then
        warn("No URL defined for module: " .. moduleName)
        return false
    end
    
    -- Check if game supports HttpGet
    if not game.HttpGet then
        warn("HttpGet not available - using fallback modules")
        if moduleName == "AntiAdmin" then
            modules[moduleName] = AntiAdminModule
            modulesLoaded[moduleName] = true
            print("Using fallback AntiAdmin module")
            if selectedCategory == moduleName then
                task.spawn(loadButtons)
            end
            return true
        end
        return false
    end
    
    local success, result = pcall(function()
        local response = game:HttpGet(moduleURLs[moduleName])
        if not response or response == "" then
            error("Empty or invalid response")
        end
        
        -- Add safety check for loadstring
        local func, err = loadstring(response)
        if not func then
            error("Failed to compile: " .. tostring(err))
        end
        
        local module = func()
        if not module or type(module) ~= "table" then
            error("Module returned invalid value: " .. tostring(module))
        end
        
        return module
    end)
    
    if success and result then
        modules[moduleName] = result
        modulesLoaded[moduleName] = true
        print("Loaded module: " .. moduleName)
        if selectedCategory == moduleName then
            task.spawn(loadButtons)
        end
        return true
    else
        warn("Failed to load module: " .. moduleName .. " Error: " .. tostring(result))
        
        -- Use fallback for AntiAdmin
        if moduleName == "AntiAdmin" then
            modules[moduleName] = AntiAdminModule
            modulesLoaded[moduleName] = true
            print("Using fallback AntiAdmin module")
            if selectedCategory == moduleName then
                task.spawn(loadButtons)
            end
            return true
        end
        return false
    end
end

-- Load all modules with error handling
for moduleName, _ in pairs(moduleURLs) do
    task.spawn(function() 
        local success = pcall(function()
            loadModule(moduleName)
        end)
        if not success then
            warn("Critical error loading " .. moduleName)
        end
    end)
end

-- Dependencies
local dependencies = {
    Players = Players,
    UserInputService = UserInputService,
    RunService = RunService,
    Workspace = Workspace,
    Lighting = Lighting,
    ScreenGui = ScreenGui,
    settings = settings,
    connections = connections,
    buttonStates = buttonStates,
    player = player
}

-- Initialize modules with error handling
local function initializeModules()
    for moduleName, module in pairs(modules) do
        if module and type(module.init) == "function" then
            local success, result = pcall(function()
                dependencies.character = character
                dependencies.humanoid = humanoid
                dependencies.rootPart = rootPart
                return module.init(dependencies)
            end)
            if not success then
                warn("Failed to initialize module " .. moduleName .. ": " .. tostring(result))
            else
                print("Initialized module: " .. moduleName)
            end
        end
    end
end

-- Helper functions for exclusive features
local function isExclusiveFeature(featureName)
    local exclusives = {"Fly", "Noclip", "Freecam", "Speed Hack", "Jump Hack"}
    for _, exclusive in ipairs(exclusives) do
        if featureName == exclusive then
            return true
        end
    end
    return false
end

local function disableActiveFeature()
    if activeFeature and activeFeature.disableCallback then
        pcall(activeFeature.disableCallback, false)
        if categoryStates[activeFeature.category] then
            categoryStates[activeFeature.category][activeFeature.name] = false
        end
    end
    activeFeature = nil
end

-- Create button
local function createButton(name, callback, categoryName)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Parent = FeatureContainer
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -2, 0, 20)
    button.Font = Enum.Font.Gotham
    button.Text = name
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 8
    button.LayoutOrder = #FeatureContainer:GetChildren()
    
    if type(callback) == "function" then
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
    print("Created button: " .. name .. " for category: " .. categoryName)
end

-- Create toggle button with exclusive feature support
local function createToggleButton(name, callback, categoryName, disableCallback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Parent = FeatureContainer
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -2, 0, 20)
    button.Font = Enum.Font.Gotham
    button.Text = name
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 8
    button.LayoutOrder = #FeatureContainer:GetChildren()
    
    if not categoryStates[categoryName] then
        categoryStates[categoryName] = {}
    end
    
    if categoryStates[categoryName][name] == nil then
        categoryStates[categoryName][name] = false
    end
    button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    
    button.MouseButton1Click:Connect(function()
        local newState = not categoryStates[categoryName][name]
        
        -- If enabling an exclusive feature
        if newState and isExclusiveFeature(name) then
            disableActiveFeature()
            activeFeature = {
                name = name,
                category = categoryName,
                disableCallback = disableCallback
            }
        elseif not newState and activeFeature and activeFeature.name == name then
            activeFeature = nil
        end
        
        categoryStates[categoryName][name] = newState
        button.BackgroundColor3 = newState and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
        
        if type(callback) == "function" then
            pcall(callback, newState)
        end
    end)
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(80, 80, 80)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    end)
end

-- Load buttons implementation with better error handling
local function loadButtons()
    -- Clear existing buttons
    for _, child in pairs(FeatureContainer:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    -- Update category button backgrounds
    for categoryName, categoryData in pairs(categoryFrames) do
        if categoryData and categoryData.button then
            categoryData.button.BackgroundColor3 = categoryName == selectedCategory and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25)
        end
    end

    if not selectedCategory then
        warn("No category selected!")
        return
    end
    
    -- Show loading label
    local loadingLabel = Instance.new("TextLabel")
    loadingLabel.Parent = FeatureContainer
    loadingLabel.BackgroundTransparency = 1
    loadingLabel.Size = UDim2.new(1, -2, 0, 20)
    loadingLabel.Font = Enum.Font.Gotham
    loadingLabel.Text = "Loading " .. selectedCategory .. "..."
    loadingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    loadingLabel.TextSize = 8
    loadingLabel.TextXAlignment = Enum.TextXAlignment.Left

    task.spawn(function()
        task.wait(0.2)
        
        local success = false
        local errorMessage = nil

        -- Load buttons based on selected category with fallbacks
        if selectedCategory == "Movement" then
            if modules.Movement and type(modules.Movement.loadMovementButtons) == "function" then
                success, errorMessage = pcall(function()
                    modules.Movement.loadMovementButtons(
                        function(name, callback) createButton(name, callback, "Movement") end,
                        function(name, callback, disableCallback) createToggleButton(name, callback, "Movement", disableCallback) end
                    )
                end)
            else
                -- Fallback buttons for Movement
                createButton("Basic Walk Speed", function() print("Basic walk speed activated") end, "Movement")
                createButton("Basic Jump Height", function() print("Basic jump height activated") end, "Movement")
                success = true
            end
        elseif selectedCategory == "AntiAdmin" then
            if modules.AntiAdmin and type(modules.AntiAdmin.loadAntiAdminButtons) == "function" then
                success, errorMessage = pcall(function()
                    modules.AntiAdmin.loadAntiAdminButtons(function(name, callback, disableCallback)
                        createToggleButton(name, callback, "AntiAdmin", disableCallback)
                    end, FeatureContainer)
                end)
            else
                -- This should not happen since we have a fallback, but just in case
                createButton("Module Loading...", function() print("AntiAdmin module not ready") end, "AntiAdmin")
                success = true
            end
        else
            -- Basic fallback for other categories
            createButton("Module Loading...", function() 
                print(selectedCategory .. " module not loaded yet") 
            end, selectedCategory)
            success = true
        end

        -- Update UI based on result
        if loadingLabel and loadingLabel.Parent then
            if not success and errorMessage then
                loadingLabel.Text = "Error: " .. tostring(errorMessage)
                loadingLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            elseif success then
                loadingLabel:Destroy()
            end
        end
    end)
end

-- Create category buttons
for _, category in ipairs(categories) do
    local categoryButton = Instance.new("TextButton")
    categoryButton.Name = category.name .. "Category"
    categoryButton.Parent = CategoryContainer
    categoryButton.BackgroundColor3 = selectedCategory == category.name and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25)
    categoryButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
    categoryButton.Size = UDim2.new(1, -5, 0, 25)
    categoryButton.LayoutOrder = category.order
    categoryButton.Font = Enum.Font.GothamBold
    categoryButton.Text = category.name
    categoryButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    categoryButton.TextSize = 8

    categoryButton.MouseButton1Click:Connect(function()
        selectedCategory = category.name
        task.spawn(loadButtons)
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

-- Minimize/Maximize
local function toggleMinimize()
    isMinimized = not isMinimized
    Frame.Visible = not isMinimized
    MinimizedLogo.Visible = isMinimized
    MinimizeButton.Text = isMinimized and "+" or "-"
end

-- Reset states
local function resetStates()
    print("Resetting all states")
    
    for _, connection in pairs(connections) do
        if connection and connection.Disconnect then
            pcall(function() connection:Disconnect() end)
        end
    end
    connections = {}
    
    for _, module in pairs(modules) do
        if module and type(module.resetStates) == "function" then
            pcall(function() module.resetStates() end)
        end
    end
    
    if selectedCategory then
        task.spawn(loadButtons)
    end
end

-- Character setup with error handling
local function onCharacterAdded(newCharacter)
    if not newCharacter then return end
    
    local success, result = pcall(function()
        character = newCharacter
        humanoid = character:WaitForChild("Humanoid", 30)
        rootPart = character:WaitForChild("HumanoidRootPart", 30)
        
        if not humanoid or not rootPart then
            error("Failed to find Humanoid or HumanoidRootPart")
        end
        
        dependencies.character = character
        dependencies.humanoid = humanoid
        dependencies.rootPart = rootPart
        
        initializeModules()
        
        if humanoid.Died then
            connections.humanoidDied = humanoid.Died:Connect(resetStates)
        end
    end)
    if not success then
        warn("Failed to set up character: " .. tostring(result))
    end
end

-- Initialize
if player.Character then
    onCharacterAdded(player.Character)
end
connections.characterAdded = player.CharacterAdded:Connect(onCharacterAdded)

-- Event connections
MinimizeButton.MouseButton1Click:Connect(toggleMinimize)
LogoButton.MouseButton1Click:Connect(toggleMinimize)

connections.toggleGui = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Home then
        toggleMinimize()
    end
end)

-- Start initialization with timeout and fallbacks
task.spawn(function()
    local timeout = 10
    local startTime = tick()
    
    -- Wait for some modules to load, but don't hang forever
    while tick() - startTime < timeout do
        local loadedCount = 0
        for _ in pairs(modulesLoaded) do
            loadedCount = loadedCount + 1
        end
        
        if loadedCount >= 2 then -- At least 2 modules loaded
            break
        end
        task.wait(0.5)
    end

    -- Check what loaded
    local loadedModules = {}
    for moduleName, loaded in pairs(modulesLoaded) do
        if loaded then
            table.insert(loadedModules, moduleName)
        end
    end
    
    if #loadedModules > 0 then
        print("Loaded modules: " .. table.concat(loadedModules, ", "))
    else
        warn("No modules loaded successfully - using basic fallbacks")
    end

    initializeModules()
    task.spawn(loadButtons)
end)

print("MinimalHackGUI loaded successfully!")