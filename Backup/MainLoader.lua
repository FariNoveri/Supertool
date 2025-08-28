-- Main entry point for MinimalHackGUI by Fari Noveri - IMPROVED MODULE LOADER

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")

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
Title.Text = "MinimalHackGUI by Fari Noveri [Improved Loader v2.0]"
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

-- Loading Status Label
local LoadingStatus = Instance.new("TextLabel")
LoadingStatus.Name = "LoadingStatus"
LoadingStatus.Parent = Frame
LoadingStatus.BackgroundTransparency = 1
LoadingStatus.Position = UDim2.new(0, 10, 1, -25)
LoadingStatus.Size = UDim2.new(1, -20, 0, 20)
LoadingStatus.Font = Enum.Font.Gotham
LoadingStatus.Text = "Initializing modules..."
LoadingStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
LoadingStatus.TextSize = 8
LoadingStatus.TextXAlignment = Enum.TextXAlignment.Left
LoadingStatus.Visible = true

-- Category Container with Scrolling
local CategoryContainer = Instance.new("ScrollingFrame")
CategoryContainer.Parent = Frame
CategoryContainer.BackgroundTransparency = 1
CategoryContainer.Position = UDim2.new(0, 5, 0, 30)
CategoryContainer.Size = UDim2.new(0, 80, 1, -60)
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
FeatureContainer.Size = UDim2.new(1, -95, 1, -60)
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

-- Module loading system - IMPROVED VERSION
local modules = {}
local modulesLoaded = {}
local moduleLoadingStatus = {}

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

-- Update loading status
local function updateLoadingStatus(message)
    if LoadingStatus then
        LoadingStatus.Text = message
        LoadingStatus.Visible = true
        print("[LOADER] " .. message)
    end
end

-- IMPROVED MODULE LOADING FUNCTION WITH RETRY LOGIC
local function loadModule(moduleName)
    local maxRetries = 3
    local retryDelay = 1
    
    updateLoadingStatus("Loading " .. moduleName .. " module...")
    
    if not moduleURLs[moduleName] then
        warn("[LOADER] No URL defined for module: " .. moduleName)
        moduleLoadingStatus[moduleName] = "No URL"
        return false
    end
    
    for attempt = 1, maxRetries do
        local success, result = pcall(function()
            print(string.format("[LOADER] Attempt %d/%d for %s", attempt, maxRetries, moduleName))
            
            -- Try to get the module content with timeout handling
            local response
            local httpSuccess, httpError = pcall(function()
                response = HttpService:GetAsync(moduleURLs[moduleName], false)
            end)
            
            if not httpSuccess then
                error("HTTP request failed: " .. tostring(httpError))
            end
            
            if not response then
                error("No response received")
            end
            
            if response == "" then
                error("Empty response received")
            end
            
            if response:find("404") or response:find("Not Found") then
                error("404 Not Found")
            end
            
            if response:find("<!DOCTYPE html>") or response:find("<html") then
                error("Received HTML instead of Lua code")
            end
            
            print(string.format("[LOADER] %s response received (length: %d)", moduleName, #response))
            
            -- Validate that it's Lua code by checking for common patterns
            if not (response:find("local") or response:find("function") or response:find("return")) then
                error("Response doesn't appear to be valid Lua code")
            end
            
            -- Try to compile the string as Lua code
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
            
            print(string.format("[LOADER] Successfully compiled and executed %s", moduleName))
            return moduleTable
        end)
        
        if success and result then
            modules[moduleName] = result
            modulesLoaded[moduleName] = true
            moduleLoadingStatus[moduleName] = "Success"
            updateLoadingStatus(moduleName .. " loaded successfully (" .. attempt .. "/" .. maxRetries .. ")")
            
            -- If this is the currently selected category, reload buttons
            if selectedCategory == moduleName then
                task.wait(0.1)
                loadButtons()
            end
            return true
        else
            local errorMsg = tostring(result or "Unknown error")
            warn(string.format("[LOADER] Attempt %d/%d failed for %s: %s", attempt, maxRetries, moduleName, errorMsg))
            moduleLoadingStatus[moduleName] = "Attempt " .. attempt .. " failed: " .. errorMsg
            
            if attempt < maxRetries then
                updateLoadingStatus(string.format("%s failed (attempt %d/%d), retrying...", moduleName, attempt, maxRetries))
                task.wait(retryDelay)
                retryDelay = retryDelay * 1.5 -- Exponential backoff
            else
                updateLoadingStatus(moduleName .. " failed to load after " .. maxRetries .. " attempts")
                moduleLoadingStatus[moduleName] = "Failed after " .. maxRetries .. " attempts"
            end
        end
    end
    
    return false
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
    updateLoadingStatus("Initializing loaded modules...")
    local initializedCount = 0
    
    for moduleName, module in pairs(modules) do
        if module and type(module.init) == "function" then
            local success, result = pcall(function()
                dependencies.character = character
                dependencies.humanoid = humanoid
                dependencies.rootPart = rootPart
                return module.init(dependencies)
            end)
            if not success then
                warn("[LOADER] Failed to initialize module " .. moduleName .. ": " .. tostring(result))
                moduleLoadingStatus[moduleName] = moduleLoadingStatus[moduleName] .. " | Init failed"
            else
                print("[LOADER] Initialized module: " .. moduleName)
                initializedCount = initializedCount + 1
            end
        else
            warn("[LOADER] Module " .. moduleName .. " has no init function or is invalid")
            moduleLoadingStatus[moduleName] = moduleLoadingStatus[moduleName] .. " | No init function"
        end
    end
    
    updateLoadingStatus(string.format("Initialized %d modules", initializedCount))
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

-- IMPROVED LOAD BUTTONS FUNCTION
local function loadButtons()
    print("[LOADER] Loading buttons for category: " .. selectedCategory)
    
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
        warn("[LOADER] No category selected!")
        return
    end
    
    -- Check if module is loaded
    if not modules[selectedCategory] then
        local statusLabel = Instance.new("TextLabel")
        statusLabel.Parent = FeatureContainer
        statusLabel.BackgroundTransparency = 1
        statusLabel.Size = UDim2.new(1, -2, 0, 40)
        statusLabel.Font = Enum.Font.Gotham
        statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        statusLabel.TextSize = 8
        statusLabel.TextXAlignment = Enum.TextXAlignment.Left
        statusLabel.TextYAlignment = Enum.TextYAlignment.Top
        statusLabel.TextWrapped = true
        
        local status = moduleLoadingStatus[selectedCategory] or "Not loaded"
        if modulesLoaded[selectedCategory] == nil then
            statusLabel.Text = "Loading " .. selectedCategory .. " module...\nStatus: " .. status
            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
            
            -- Try to load the module if not already attempted
            task.spawn(function()
                loadModule(selectedCategory)
            end)
        else
            statusLabel.Text = "Failed to load " .. selectedCategory .. " module.\nStatus: " .. status .. "\n\nTry selecting another category or restart the script."
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
        return
    end
    
    local module = modules[selectedCategory]
    local success = false
    local errorMessage = nil

    -- Load buttons based on selected category
    if selectedCategory == "Movement" and module.loadMovementButtons then
        success, errorMessage = pcall(function()
            print("[LOADER] Calling Movement.loadMovementButtons")
            module.loadMovementButtons(
                function(name, callback) return createButton(name, callback, "Movement") end,
                function(name, callback, disableCallback) return createToggleButton(name, callback, "Movement", disableCallback) end
            )
        end)
        
    elseif selectedCategory == "Player" and module.loadPlayerButtons then
        success, errorMessage = pcall(function()
            local selectedPlayer = module.getSelectedPlayer and module.getSelectedPlayer() or nil
            print("[LOADER] Calling Player.loadPlayerButtons with selectedPlayer: " .. tostring(selectedPlayer))
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
            print("[LOADER] Calling Teleport.loadTeleportButtons")
            module.loadTeleportButtons(
                function(name, callback) return createButton(name, callback, "Teleport") end,
                selectedPlayer, freecamEnabled, freecamPosition, toggleFreecam
            )
        end)
        
    elseif selectedCategory == "Visual" and module.loadVisualButtons then
        success, errorMessage = pcall(function()
            print("[LOADER] Calling Visual.loadVisualButtons")
            module.loadVisualButtons(function(name, callback, disableCallback)
                return createToggleButton(name, callback, "Visual", disableCallback)
            end)
        end)
        
    elseif selectedCategory == "Utility" and module.loadUtilityButtons then
        success, errorMessage = pcall(function()
            print("[LOADER] Calling Utility.loadUtilityButtons")
            module.loadUtilityButtons(function(name, callback)
                return createButton(name, callback, "Utility")
            end)
        end)
        
    elseif selectedCategory == "AntiAdmin" and module.loadAntiAdminButtons then
        success, errorMessage = pcall(function()
            print("[LOADER] Calling AntiAdmin.loadAntiAdminButtons")
            module.loadAntiAdminButtons(function(name, callback, disableCallback)
                return createToggleButton(name, callback, "AntiAdmin", disableCallback)
            end, FeatureContainer)
        end)
        
    elseif selectedCategory == "Settings" and module.loadSettingsButtons then
        success, errorMessage = pcall(function()
            print("[LOADER] Calling Settings.loadSettingsButtons")
            module.loadSettingsButtons(function(name, callback)
                return createButton(name, callback, "Settings")
            end)
        end)
        
    elseif selectedCategory == "Info" and module.createInfoDisplay then
        success, errorMessage = pcall(function()
            print("[LOADER] Calling Info.createInfoDisplay")
            module.createInfoDisplay(FeatureContainer)
        end)
        
    else
        errorMessage = "Module " .. selectedCategory .. " doesn't have the required function!"
        warn("[LOADER] " .. errorMessage)
    end

    -- Show error if loading failed
    if not success and errorMessage then
        local errorLabel = Instance.new("TextLabel")
        errorLabel.Parent = FeatureContainer
        errorLabel.BackgroundTransparency = 1
        errorLabel.Size = UDim2.new(1, -2, 0, 60)
        errorLabel.Font = Enum.Font.Gotham
        errorLabel.Text = "Error loading " .. selectedCategory .. " buttons:\n" .. tostring(errorMessage) .. "\n\nModule status: " .. (moduleLoadingStatus[selectedCategory] or "Unknown")
        errorLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        errorLabel.TextSize = 8
        errorLabel.TextXAlignment = Enum.TextXAlignment.Left
        errorLabel.TextYAlignment = Enum.TextYAlignment.Top
        errorLabel.TextWrapped = true
        print("[LOADER] Error: " .. tostring(errorMessage))
    elseif success then
        print("[LOADER] Successfully loaded buttons for " .. selectedCategory)
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
    print("[LOADER] Resetting all states")
    
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
        warn("[LOADER] Failed to set up character: " .. tostring(result))
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

-- IMPROVED MODULE LOADING WITH SEQUENTIAL PROCESSING AND BETTER ERROR HANDLING
local function startModuleLoading()
    updateLoadingStatus("Starting module loading process...")
    
    local totalModules = 0
    for _ in pairs(moduleURLs) do
        totalModules = totalModules + 1
    end
    
    local loadedCount = 0
    local failedCount = 0
    
    -- Load modules one by one to avoid overwhelming the HTTP service
    for moduleName, _ in pairs(moduleURLs) do
        updateLoadingStatus(string.format("Loading %s (%d/%d)...", moduleName, loadedCount + failedCount + 1, totalModules))
        
        local success = loadModule(moduleName)
        if success then
            loadedCount = loadedCount + 1
        else
            failedCount = failedCount + 1
        end
        
        -- Small delay between module loads to prevent rate limiting
        task.wait(0.5)
    end
    
    -- Summary of loading results
    if loadedCount > 0 then
        updateLoadingStatus(string.format("✓ Loaded %d/%d modules successfully", loadedCount, totalModules))
        print("[LOADER] Successfully loaded modules: " .. table.concat(getLoadedModuleNames(), ", "))
    end
    
    if failedCount > 0 then
        local failedModules = getFailedModuleNames()
        print("[LOADER] Failed to load modules: " .. table.concat(failedModules, ", "))
        
        if loadedCount == 0 then
            updateLoadingStatus("❌ All modules failed to load - check your internet connection")
        else
            updateLoadingStatus(string.format("⚠️ %d modules failed, %d loaded successfully", failedCount, loadedCount))
        end
    end
    
    if loadedCount > 0 then
        initializeModules()
        loadButtons()
        
        -- Hide loading status after successful initialization
        task.wait(2)
        if LoadingStatus then
            LoadingStatus.Visible = false
        end
    end
    
    print("[LOADER] Module loading process complete!")
    return loadedCount > 0
end

-- Helper functions for module status reporting
local function getLoadedModuleNames()
    local loaded = {}
    for moduleName, isLoaded in pairs(modulesLoaded) do
        if isLoaded then
            table.insert(loaded, moduleName)
        end
    end
    return loaded
end

local function getFailedModuleNames()
    local failed = {}
    for moduleName, _ in pairs(moduleURLs) do
        if not modulesLoaded[moduleName] then
            table.insert(failed, moduleName)
        end
    end
    return failed
end

-- Debug function to show detailed module status
local function showModuleStatus()
    print("\n[LOADER] === MODULE LOADING STATUS ===")
    for moduleName, url in pairs(moduleURLs) do
        local status = moduleLoadingStatus[moduleName] or "Not attempted"
        local loaded = modulesLoaded[moduleName] and "✓" or "✗"
        print(string.format("[LOADER] %s %s: %s", loaded, moduleName, status))
    end
    print("[LOADER] ==============================\n")
end

-- Add debug command for troubleshooting
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.F9 then
        showModuleStatus()
    end
end)

-- Alternative loading method using different HTTP approach
local function alternativeLoadModule(moduleName)
    local success, result = pcall(function()
        -- Try using game:HttpGet instead of HttpService:GetAsync
        local response = game:HttpGet(moduleURLs[moduleName])
        
        if not response or response == "" then
            error("Empty response from game:HttpGet")
        end
        
        if response:find("404") or response:find("Not Found") then
            error("404 Not Found")
        end
        
        -- Continue with normal processing
        local moduleFunc, loadError = loadstring(response)
        if not moduleFunc then
            error("Failed to compile: " .. tostring(loadError))
        end
        
        local moduleTable = moduleFunc()
        if not moduleTable or type(moduleTable) ~= "table" then
            error("Invalid module table")
        end
        
        return moduleTable
    end)
    
    if success and result then
        modules[moduleName] = result
        modulesLoaded[moduleName] = true
        moduleLoadingStatus[moduleName] = "Success (alternative method)"
        return true
    else
        moduleLoadingStatus[moduleName] = "Alternative method also failed: " .. tostring(result)
        return false
    end
end

-- Retry failed modules with alternative method
local function retryFailedModules()
    local retriedCount = 0
    updateLoadingStatus("Retrying failed modules with alternative method...")
    
    for moduleName, _ in pairs(moduleURLs) do
        if not modulesLoaded[moduleName] then
            print("[LOADER] Retrying " .. moduleName .. " with alternative method...")
            if alternativeLoadModule(moduleName) then
                retriedCount = retriedCount + 1
                print("[LOADER] ✓ Successfully loaded " .. moduleName .. " with alternative method")
            end
            task.wait(0.3)
        end
    end
    
    if retriedCount > 0 then
        updateLoadingStatus(string.format("✓ Recovered %d additional modules", retriedCount))
        initializeModules()
        loadButtons()
    end
    
    return retriedCount
end

-- Emergency fallback: Load from pastebin or other sources if GitHub fails
local fallbackURLs = {
    -- Add fallback URLs here if needed
    -- Utility = "https://pastebin.com/raw/XXXXXXXX",
}

local function loadFromFallback(moduleName)
    if not fallbackURLs[moduleName] then
        return false
    end
    
    updateLoadingStatus("Trying fallback source for " .. moduleName .. "...")
    
    local success, result = pcall(function()
        local response = game:HttpGet(fallbackURLs[moduleName])
        if not response or response == "" then
            error("Empty fallback response")
        end
        
        local moduleFunc, loadError = loadstring(response)
        if not moduleFunc then
            error("Failed to compile fallback: " .. tostring(loadError))
        end
        
        return moduleFunc()
    end)
    
    if success and result and type(result) == "table" then
        modules[moduleName] = result
        modulesLoaded[moduleName] = true
        moduleLoadingStatus[moduleName] = "Success (fallback source)"
        return true
    end
    
    return false
end

-- Start the improved loading process
task.spawn(function()
    local success = startModuleLoading()
    
    -- If initial loading had failures, try alternative methods
    if not success or #getFailedModuleNames() > 0 then
        task.wait(2)
        local recovered = retryFailedModules()
        
        -- If still have failures, try fallback sources
        if #getFailedModuleNames() > 0 then
            for _, moduleName in ipairs(getFailedModuleNames()) do
                loadFromFallback(moduleName)
            end
        end
        
        -- Final status update
        local finalLoaded = #getLoadedModuleNames()
        local finalFailed = #getFailedModuleNames()
        
        if finalLoaded > 0 then
            updateLoadingStatus(string.format("Ready! %d/%d modules loaded", finalLoaded, finalLoaded + finalFailed))
            if LoadingStatus then
                task.wait(3)
                LoadingStatus.Visible = false
            end
        else
            updateLoadingStatus("❌ No modules could be loaded - script may not function properly")
        end
    end
end)

print("[LOADER] MinimalHackGUI Improved Loader v2.0 initialized!")
print("[LOADER] Press F9 to show detailed module loading status")
print("[LOADER] Press HOME to toggle GUI visibility")