-- Main entry point for MinimalHackGUI by Fari Noveri with Anti-Cheat Bypass

-- Anti-Detection Bypasses
local function createBypass()
    -- Spoof game services to avoid detection
    local spoofedServices = {}
    
    -- Safe HTTP function wrapper instead of direct hooking
    local function safeHttpGet(url)
        -- Add random delay to avoid pattern detection
        task.wait(math.random(50, 200) / 1000)
        local success, response = pcall(function()
            return game:GetService("HttpService"):GetAsync(url)
        end)
        return success and response or nil
    end
    
    -- Spoof getgc and getgenv functions if they exist (safer approach)
    pcall(function()
        if getgc then
            local originalGetGC = getgc
            getgc = function(...)
                local success, result = pcall(originalGetGC, ...)
                if not success then return {} end
                
                -- Filter out our GUI objects from garbage collection results
                local filtered = {}
                for i, v in pairs(result) do
                    if not (typeof(v) == "Instance" and string.find(tostring(v.Name), "MinimalHack")) then
                        table.insert(filtered, v)
                    end
                end
                return filtered
            end
        end
    end)
    
    -- Hide from common anti-cheat detection methods
    local function hideFromDetection()
        -- Randomize GUI names to avoid signature detection
        local randomSuffix = tostring(math.random(10000, 99999))
        return "PlayerGUI_" .. randomSuffix
    end
    
    -- Memory cleanup to avoid detection
    local function cleanupMemory()
        pcall(function()
            collectgarbage("count") -- Use count instead of collect
            task.wait(0.1)
        end)
    end
    
    return hideFromDetection, cleanupMemory, safeHttpGet
end

local hideFromDetection, cleanupMemory, safeHttpGet = createBypass()

-- Services (with anti-detection wrapping)
local function getService(serviceName)
    task.wait(math.random(1, 5) / 1000) -- Random micro-delay
    return game:GetService(serviceName)
end

local Players = getService("Players")
local UserInputService = getService("UserInputService")
local RunService = getService("RunService")
local Workspace = getService("Workspace")
local Lighting = getService("Lighting")

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

-- Anti-detection: Randomize update intervals
local updateInterval = math.random(100, 300) / 1000

-- Settings
local settings = {
    FlySpeed = {value = 50, min = 10, max = 200, default = 50},
    FreecamSpeed = {value = 50, min = 10, max = 200, default = 50},
    JumpHeight = {value = 7.2, min = 0, max = 50, default = 7.2},
    WalkSpeed = {value = 16, min = 10, max = 200, default = 16}
}

-- ScreenGui with bypass naming
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = hideFromDetection()
ScreenGui.Parent = player:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Enabled = true

-- Anti-detection: Hide from common detection methods
local function hideFromCommonDetection()
    -- Make GUI less visible to basic detection scripts
    ScreenGui.DisplayOrder = -1000
    
    -- Anti-detection heartbeat
    task.spawn(function()
        while ScreenGui.Parent do
            task.wait(updateInterval)
            -- Randomize some properties to avoid pattern detection
            ScreenGui.DisplayOrder = math.random(-1000, -500)
            cleanupMemory()
        end
    end)
end

hideFromCommonDetection()

-- Check for existing script instances (improved bypass)
for _, gui in pairs(player.PlayerGui:GetChildren()) do
    if gui:IsA("ScreenGui") and (gui.Name:find("PlayerGUI_") or gui.Name == "MinimalHackGUI") and gui ~= ScreenGui then
        task.spawn(function()
            task.wait(math.random(100, 500) / 1000)
            gui:Destroy()
        end)
    end
end

-- Main Frame with obfuscated properties
local Frame = Instance.new("Frame")
Frame.Name = "MainContainer_" .. tostring(math.random(1000, 9999))
Frame.Parent = ScreenGui
Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Frame.BorderColor3 = Color3.fromRGB(45, 45, 45)
Frame.BorderSizePixel = 1
Frame.Position = UDim2.new(0.5, -250, 0.5, -150)
Frame.Size = UDim2.new(0, 500, 0, 300)
Frame.Active = true
Frame.Draggable = true

-- Anti-detection: Make frame slightly transparent to avoid screenshot detection
Frame.BackgroundTransparency = 0.01

-- Title
local Title = Instance.new("TextLabel")
Title.Name = "HeaderText"
Title.Parent = Frame
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.BorderSizePixel = 0
Title.Size = UDim2.new(1, 0, 0, 25)
Title.Font = Enum.Font.Gotham
Title.Text = "MinimalHackGUI by Fari Noveri [Backup]"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 10

-- Minimized Logo
local MinimizedLogo = Instance.new("Frame")
MinimizedLogo.Name = "CompactView"
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
    {name = "Settings", order = 6},
    {name = "AntiAdmin", order = 7},
    {name = "Info", order = 8}
}

local categoryFrames = {}
local isMinimized = false

-- Define exclusive features (features that can't run together)
exclusiveFeatures = {
    "Fly", "Noclip", "Speed", "JumpHeight", "InfiniteJump", 
    "Freecam", "FullBright", "ESP", "Tracers", "AutoFarm"
}

-- Function to disable active feature
local function disableActiveFeature()
    if activeFeature then
        local categoryName = activeFeature.category
        local featureName = activeFeature.name
        
        -- Set state to false
        if categoryStates[categoryName] and categoryStates[categoryName][featureName] ~= nil then
            categoryStates[categoryName][featureName] = false
        end
        
        -- Find and update button appearance
        for _, child in pairs(FeatureContainer:GetChildren()) do
            if child:IsA("TextButton") and child.Name == featureName then
                child.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                break
            end
        end
        
        -- Call disable callback if available
        if activeFeature.disableCallback then
            pcall(activeFeature.disableCallback)
        end
        
        activeFeature = nil
    end
end

-- Function to check if feature is exclusive
local function isExclusiveFeature(featureName)
    for _, exclusive in pairs(exclusiveFeatures) do
        if string.find(featureName, exclusive) then
            return true
        end
    end
    return false
end

-- Load modules with bypass
local modules = {}
local modulesLoaded = {}

local moduleURLs = {
    Movement = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Movement.lua",
    Player = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Player.lua",
    Teleport = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Teleport.lua",
    Visual = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Visual.lua",
    Utility = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Utility.lua",
    Settings = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Settings.lua",
    AntiAdmin = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/AntiAdmin.lua",
    Info = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Info.lua"
}

-- Anti-detection module loading
local function loadModule(moduleName)
    if not moduleURLs[moduleName] then
        return false
    end
    
    -- Add random delay to avoid pattern detection
    task.wait(math.random(100, 500) / 1000)
    
    local success, result = pcall(function()
        local response = safeHttpGet(moduleURLs[moduleName])
        if not response or response == "" then
            return nil
        end
        
        -- Anti-detection: Obfuscate the loading process
        task.wait(math.random(50, 150) / 1000)
        
        local func, loadError = loadstring(response)
        if not func then
            warn("Failed to compile module " .. moduleName .. ": " .. tostring(loadError))
            return nil
        end
        
        local moduleResult = func()
        if not moduleResult then
            warn("Module " .. moduleName .. " returned nil")
            return nil
        end
        
        return moduleResult
    end)
    
    if success and result then
        modules[moduleName] = result
        modulesLoaded[moduleName] = true
        if selectedCategory == moduleName then
            task.spawn(loadButtons)
        end
        return true
    else
        warn("Failed to load module " .. moduleName .. ": " .. tostring(result))
        return false
    end
end

-- Load all modules with staggered timing
for moduleName, _ in pairs(moduleURLs) do
    task.spawn(function() 
        task.wait(math.random(100, 1000) / 1000) -- Random delay between module loads
        loadModule(moduleName) 
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
    player = player,
    disableActiveFeature = disableActiveFeature,
    isExclusiveFeature = isExclusiveFeature
}

-- Initialize modules
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
                -- Silent failure to avoid detection
            end
        end
    end
end

-- Create button with bypass
local function createButton(name, callback, categoryName)
    local button = Instance.new("TextButton")
    button.Name = name .. "_" .. tostring(math.random(100, 999)) -- Randomize name
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
            -- Anti-detection delay
            task.wait(math.random(10, 50) / 1000)
            
            -- Check if this is an exclusive feature
            if isExclusiveFeature(name) then
                disableActiveFeature()
                activeFeature = {
                    name = name,
                    category = categoryName,
                    disableCallback = nil
                }
            end
            
            callback()
        end)
    end
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end)
end

-- Create toggle button with exclusive feature support and bypass
local function createToggleButton(name, callback, categoryName, disableCallback)
    local button = Instance.new("TextButton")
    button.Name = name .. "_toggle_" .. tostring(math.random(100, 999))
    button.Parent = FeatureContainer
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -2, 0, 20)
    button.Font = Enum.Font.Gotham
    button.Text = name
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 8
    button.LayoutOrder = #FeatureContainer:GetChildren()
    
    if categoryStates[categoryName][name] == nil then
        categoryStates[categoryName][name] = false
    end
    button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    
    button.MouseButton1Click:Connect(function()
        -- Anti-detection delay
        task.wait(math.random(10, 50) / 1000)
        
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
            callback(newState)
        end
    end)
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(80, 80, 80)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    end)
end

-- Load buttons implementation with bypass
local function loadButtons()
    -- Clear existing buttons
    for _, child in pairs(FeatureContainer:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    -- Update category button backgrounds
    for categoryName, categoryData in pairs(categoryFrames) do
        categoryData.button.BackgroundColor3 = categoryName == selectedCategory and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25)
    end

    if not selectedCategory then
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
        -- Anti-detection delay
        task.wait(math.random(100, 300) / 1000)
        
        local success = false
        local errorMessage = nil

        -- Load buttons based on selected category
        if selectedCategory == "Movement" and modules.Movement and type(modules.Movement.loadMovementButtons) == "function" then
            success, errorMessage = pcall(function()
                modules.Movement.loadMovementButtons(
                    function(name, callback) createButton(name, callback, "Movement") end,
                    function(name, callback, disableCallback) createToggleButton(name, callback, "Movement", disableCallback) end
                )
            end)
        elseif selectedCategory == "Player" and modules.Player and type(modules.Player.loadPlayerButtons) == "function" then
            success, errorMessage = pcall(function()
                local selectedPlayer = modules.Player.getSelectedPlayer and modules.Player.getSelectedPlayer() or nil
                modules.Player.loadPlayerButtons(
                    function(name, callback) createButton(name, callback, "Player") end,
                    function(name, callback, disableCallback) createToggleButton(name, callback, "Player", disableCallback) end,
                    selectedPlayer
                )
            end)
        elseif selectedCategory == "Teleport" and modules.Teleport and type(modules.Teleport.loadTeleportButtons) == "function" then
            success, errorMessage = pcall(function()
                local selectedPlayer = modules.Player and modules.Player.getSelectedPlayer and modules.Player.getSelectedPlayer() or nil
                local freecamEnabled = modules.Visual and modules.Visual.getFreecamState and modules.Visual.getFreecamState() or false
                local freecamPosition = modules.Visual and modules.Visual.getFreecamState and select(2, modules.Visual.getFreecamState()) or nil
                local toggleFreecam = modules.Visual and modules.Visual.toggleFreecam or function() end
                modules.Teleport.loadTeleportButtons(
                    function(name, callback) createButton(name, callback, "Teleport") end,
                    selectedPlayer, freecamEnabled, freecamPosition, toggleFreecam
                )
            end)
        elseif selectedCategory == "Visual" and modules.Visual and type(modules.Visual.loadVisualButtons) == "function" then
            success, errorMessage = pcall(function()
                modules.Visual.loadVisualButtons(function(name, callback, disableCallback)
                    createToggleButton(name, callback, "Visual", disableCallback)
                end)
            end)
        elseif selectedCategory == "Utility" and modules.Utility and type(modules.Utility.loadUtilityButtons) == "function" then
            success, errorMessage = pcall(function()
                modules.Utility.loadUtilityButtons(function(name, callback)
                    createButton(name, callback, "Utility")
                end)
            end)
        elseif selectedCategory == "Settings" and modules.Settings and type(modules.Settings.loadSettingsButtons) == "function" then
            success, errorMessage = pcall(function()
                modules.Settings.loadSettingsButtons(function(name, callback)
                    createButton(name, callback, "Settings")
                end)
            end)
        elseif selectedCategory == "AntiAdmin" and modules.AntiAdmin and type(modules.AntiAdmin.loadAntiAdminButtons) == "function" then
            success, errorMessage = pcall(function()
                modules.AntiAdmin.loadAntiAdminButtons(function(name, callback, disableCallback)
                    createToggleButton(name, callback, "AntiAdmin", disableCallback)
                end, FeatureContainer)
            end)
        elseif selectedCategory == "Info" and modules.Info and type(modules.Info.createInfoDisplay) == "function" then
            success, errorMessage = pcall(function()
                modules.Info.createInfoDisplay(FeatureContainer)
            end)
        end

        -- Update UI based on result
        if loadingLabel and loadingLabel.Parent then
            if not success then
                loadingLabel.Text = "Failed to load " .. selectedCategory
                loadingLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            else
                loadingLabel:Destroy()
            end
        end
    end)
end

-- Create category buttons
for _, category in ipairs(categories) do
    local categoryButton = Instance.new("TextButton")
    categoryButton.Name = category.name .. "Cat_" .. tostring(math.random(100, 999))
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
        task.wait(math.random(10, 30) / 1000) -- Anti-detection delay
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

-- Minimize/Maximize with bypass
local function toggleMinimize()
    isMinimized = not isMinimized
    Frame.Visible = not isMinimized
    MinimizedLogo.Visible = isMinimized
    MinimizeButton.Text = isMinimized and "+" or "-"
    
    -- Anti-detection: Clean memory after UI changes
    cleanupMemory()
end

-- Reset states with bypass
local function resetStates()
    activeFeature = nil
    
    for _, connection in pairs(connections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
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
    
    cleanupMemory()
end

-- Character setup with bypass
local function onCharacterAdded(newCharacter)
    if not newCharacter then return end
    
    local success, result = pcall(function()
        character = newCharacter
        humanoid = character:WaitForChild("Humanoid", 30)
        rootPart = character:WaitForChild("HumanoidRootPart", 30)
        
        dependencies.character = character
        dependencies.humanoid = humanoid
        dependencies.rootPart = rootPart
        
        -- Anti-detection delay before initializing
        task.wait(math.random(200, 500) / 1000)
        initializeModules()
        
        if humanoid and humanoid.Died then
            connections.humanoidDied = humanoid.Died:Connect(resetStates)
        end
    end)
end

-- Initialize with bypass
if player.Character then
    onCharacterAdded(player.Character)
end
connections.characterAdded = player.CharacterAdded:Connect(onCharacterAdded)

-- Event connections with bypass
MinimizeButton.MouseButton1Click:Connect(toggleMinimize)
LogoButton.MouseButton1Click:Connect(toggleMinimize)

connections.toggleGui = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Home then
        toggleMinimize()
    end
end)

-- Anti-detection: Periodic cleanup and randomization
task.spawn(function()
    while ScreenGui.Parent do
        task.wait(math.random(30000, 60000) / 1000) -- 30-60 seconds
        cleanupMemory()
        
        -- Randomize some GUI properties to avoid detection
        if Frame.Visible then
            Frame.BackgroundTransparency = math.random(1, 5) / 100
        end
    end
end)

-- Start initialization with bypass
task.spawn(function()
    local timeout = 20 -- Increased timeout
    local startTime = tick()
    
    -- Wait for critical modules to load with random intervals
    while (not modules.Movement or not modules.Player or not modules.Teleport) and tick() - startTime < timeout do
        task.wait(math.random(100, 300) / 1000)
    end

    -- Anti-detection delay before final initialization
    task.wait(math.random(500, 1000) / 1000)
    
    initializeModules()
    task.spawn(loadButtons)
end)