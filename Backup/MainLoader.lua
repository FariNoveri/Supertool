-- Main entry point for MinimalHackGUI by Fari Noveri - FIXED MODULE LOADER

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

-- Local Player
local player = Players.LocalPlayer
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
Title.Text = "MinimalHackGUI by Fari Noveri [Fixed Loader]"
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

-- Load modules - FIXED VERSION
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

-- PROPER MODULE LOADING FUNCTION
local function loadModule(moduleName)
    print("Attempting to load module: " .. moduleName)
    
    if not moduleURLs[moduleName] then
        warn("No URL defined for module: " .. moduleName)
        return false
    end
    
    local success, result = pcall(function()
        -- Try to get the module content
        local response = game:HttpGet(moduleURLs[moduleName])
        
        if not response or response == "" or response:find("404") then
            error("Failed to fetch module or got 404")
        end
        
        print("Got response for " .. moduleName .. " (length: " .. #response .. ")")
        
        -- Try to load the string as Lua code
        local moduleFunc, loadError = loadstring(response)
        if not moduleFunc then
            error("Failed to compile module: " .. tostring(loadError))
        end
        
        -- Execute the module code to get the module table
        local moduleTable = moduleFunc()
        
        if not moduleTable then
            error("Module function returned nil")
        end
        
        if type(moduleTable) ~= "table" then
            error("Module must return a table, got: " .. type(moduleTable))
        end
        
        print("Successfully compiled and executed module: " .. moduleName)
        return moduleTable
    end)
    
    if success and result then
        modules[moduleName] = result
        modulesLoaded[moduleName] = true
        print("✓ Module loaded successfully: " .. moduleName)
        
        -- If this is the currently selected category, reload buttons
        if selectedCategory == moduleName then
            task.wait(0.1) -- Small delay to ensure everything is ready
            loadButtons()
        end
        return true
    else
        warn("✗ Failed to load module " .. moduleName .. ": " .. tostring(result))
        return false
    end
end

-- Load all modules asynchronously
print("Starting module loading...")
for moduleName, _ in pairs(moduleURLs) do
    task.spawn(function()
        local startTime = tick()
        local success = loadModule(moduleName)
        local loadTime = tick() - startTime
        print(string.format("Module %s: %s (%.2fs)", moduleName, success and "SUCCESS" or "FAILED", loadTime))
    end)
end

-- Dependencies for modules
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

-- Initialize modules
local function initializeModules()
    print("Initializing loaded modules...")
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
                print("✓ Initialized module: " .. moduleName)
            end
        else
            print("Module " .. moduleName .. " has no init function or is invalid")
        end
    end
end

-- Helper functions for exclusive features
local function isExclusiveFeature(featureName)
    local exclusives = {"Fly", "Noclip", "Freecam", "Speed Hack", "Jump Hack"}
    for _, exclusive in ipairs(exclusives) do
        if featureName:find(exclusive) then
            return true
        end
    end
    return false
end

local function disableActiveFeature()
    if activeFeature and activeFeature.disableCallback and type(activeFeature.disableCallback) == "function" then
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
            local success, errorMsg = pcall(callback)
            if not success then
                warn("Error executing callback for " .. name .. ": " .. tostring(errorMsg))
            end
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
    
    -- Ensure category state exists
    if not categoryStates[categoryName] then
        categoryStates[categoryName] = {}
    end
    
    if categoryStates[categoryName][name] == nil then
        categoryStates[categoryName][name] = false
    end
    
    button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    
    button.MouseButton1Click:Connect(function()
        local newState = not categoryStates[categoryName][name]
        
        -- Handle exclusive features
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
            local success, errorMsg = pcall(callback, newState)
            if not success then
                warn("Error executing toggle callback for " .. name .. ": " .. tostring(errorMsg))
            end
        end
    end)
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(80, 80, 80)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    end)
    
    return button
end

-- PROPER LOAD BUTTONS FUNCTION
local function loadButtons()
    print("Loading buttons for category: " .. selectedCategory)
    
    -- Clear existing buttons
    for _, child in pairs(FeatureContainer:GetChildren()) do
        if child:IsA("TextButton") or (child:IsA("TextLabel") and child.Name ~= "FeatureLayout") then
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
    
    -- Check if module is loaded
    if not modules[selectedCategory] then
        local loadingLabel = Instance.new("TextLabel")
        loadingLabel.Parent = FeatureContainer
        loadingLabel.BackgroundTransparency = 1
        loadingLabel.Size = UDim2.new(1, -2, 0, 20)
        loadingLabel.Font = Enum.Font.Gotham
        loadingLabel.Text = "Loading " .. selectedCategory .. " module..."
        loadingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        loadingLabel.TextSize = 8
        loadingLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        -- Try to load the module if not already loading
        if not modulesLoaded[selectedCategory] then
            task.spawn(function()
                loadModule(selectedCategory)
            end)
        end
        return
    end
    
    local module = modules[selectedCategory]
    local success = false
    local errorMessage = nil

    -- Load buttons based on selected category
    if selectedCategory == "Movement" and module.loadMovementButtons then
        success, errorMessage = pcall(function()
            print("Calling Movement.loadMovementButtons")
            module.loadMovementButtons(
                function(name, callback) return createButton(name, callback, "Movement") end,
                function(name, callback, disableCallback) return createToggleButton(name, callback, "Movement", disableCallback) end
            )
        end)
        
    elseif selectedCategory == "Player" and module.loadPlayerButtons then
        success, errorMessage = pcall(function()
            local selectedPlayer = module.getSelectedPlayer and module.getSelectedPlayer() or nil
            print("Calling Player.loadPlayerButtons with selectedPlayer: " .. tostring(selectedPlayer))
            module.loadPlayerButtons(
                function(name, callback) return createButton(name, callback, "Player") end,
                function(name, callback, disableCallback) return createToggleButton(name, callback, "Player", disableCallback) end,
                selectedPlayer
            )
        end)
        
    elseif selectedCategory == "Teleport" and module.loadTeleportButtons then
        success, errorMessage = pcall(function()
            local selectedPlayer = modules.Player and modules.Player.getSelectedPlayer and modules.Player.getSelectedPlayer() or nil
            local freecamEnabled = modules.Visual and modules.Visual.getFreecamState and modules.Visual.getFreecamState() or false
            local freecamPosition = freecamEnabled and select(2, modules.Visual.getFreecamState()) or nil
            local toggleFreecam = modules.Visual and modules.Visual.toggleFreecam or function() end
            print("Calling Teleport.loadTeleportButtons")
            module.loadTeleportButtons(
                function(name, callback) return createButton(name, callback, "Teleport") end,
                selectedPlayer, freecamEnabled, freecamPosition, toggleFreecam
            )
        end)
        
    elseif selectedCategory == "Visual" and module.loadVisualButtons then
        success, errorMessage = pcall(function()
            print("Calling Visual.loadVisualButtons")
            module.loadVisualButtons(function(name, callback, disableCallback)
                return createToggleButton(name, callback, "Visual", disableCallback)
            end)
        end)
        
    elseif selectedCategory == "Utility" and module.loadUtilityButtons then
        success, errorMessage = pcall(function()
            print("Calling Utility.loadUtilityButtons")
            module.loadUtilityButtons(function(name, callback)
                return createButton(name, callback, "Utility")
            end)
        end)
        
    elseif selectedCategory == "AntiAdmin" and module.loadAntiAdminButtons then
        success, errorMessage = pcall(function()
            print("Calling AntiAdmin.loadAntiAdminButtons")
            module.loadAntiAdminButtons(function(name, callback, disableCallback)
                return createToggleButton(name, callback, "AntiAdmin", disableCallback)
            end, FeatureContainer)
        end)
        
    elseif selectedCategory == "Settings" and module.loadSettingsButtons then
        success, errorMessage = pcall(function()
            print("Calling Settings.loadSettingsButtons")
            module.loadSettingsButtons(function(name, callback)
                return createButton(name, callback, "Settings")
            end)
        end)
        
    elseif selectedCategory == "Info" and module.createInfoDisplay then
        success, errorMessage = pcall(function()
            print("Calling Info.createInfoDisplay")
            module.createInfoDisplay(FeatureContainer)
        end)
        
    else
        errorMessage = "Module " .. selectedCategory .. " doesn't have the required function!"
        warn(errorMessage)
    end

    -- Show error if loading failed
    if not success and errorMessage then
        local errorLabel = Instance.new("TextLabel")
        errorLabel.Parent = FeatureContainer
        errorLabel.BackgroundTransparency = 1
        errorLabel.Size = UDim2.new(1, -2, 0, 40)
        errorLabel.Font = Enum.Font.Gotham
        errorLabel.Text = "Error loading " .. selectedCategory .. ":\n" .. tostring(errorMessage)
        errorLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        errorLabel.TextSize = 8
        errorLabel.TextXAlignment = Enum.TextXAlignment.Left
        errorLabel.TextYAlignment = Enum.TextYAlignment.Top
        errorLabel.TextWrapped = true
        print("Error: " .. tostring(errorMessage))
    elseif success then
        print("✓ Successfully loaded buttons for " .. selectedCategory)
    end
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

-- Character setup
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

-- Initialize character
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

-- Start initialization
task.spawn(function()
    local timeout = 30 -- Increased timeout
    local startTime = tick()
    
    -- Wait for at least one module to load
    while tick() - startTime < timeout do
        local loadedCount = 0
        for _ in pairs(modulesLoaded) do
            loadedCount = loadedCount + 1
        end
        
        if loadedCount > 0 then
            print("At least one module loaded, proceeding...")
            break
        end
        
        task.wait(0.5)
    end

    -- Report loading results
    local loadedModules = {}
    local failedModules = {}
    
    for moduleName, _ in pairs(moduleURLs) do
        if modulesLoaded[moduleName] then
            table.insert(loadedModules, moduleName)
        else
            table.insert(failedModules, moduleName)
        end
    end
    
    if #loadedModules > 0 then
        print("✓ Successfully loaded modules: " .. table.concat(loadedModules, ", "))
    end
    
    if #failedModules > 0 then
        print("✗ Failed to load modules: " .. table.concat(failedModules, ", "))
    end

    initializeModules()
    loadButtons()
    
    print("MinimalHackGUI initialization complete!")
end)