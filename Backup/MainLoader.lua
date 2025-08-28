-- Main entry point for MinimalHackGUI by Fari Noveri - IMPROVED MODULE LOADER v2.1

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Suppress Roblox chat system warnings
pcall(function()
    if ReplicatedStorage:FindFirstChild("SendLikelySpeakingUser") then
        ReplicatedStorage.SendLikelySpeakingUser.OnClientEvent:Connect(function() end)
    end
end)

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

-- Clean up existing instances
for _, gui in pairs(player.PlayerGui:GetChildren()) do
    if gui:IsA("ScreenGui") and gui.Name == "MinimalHackGUI" then
        gui:Destroy()
    end
end

-- ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MinimalHackGUI"
ScreenGui.Parent = player:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Enabled = true

-- Main Frame with improved styling
local Frame = Instance.new("Frame")
Frame.Name = "MainFrame"
Frame.Parent = ScreenGui
Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Frame.BorderColor3 = Color3.fromRGB(60, 60, 60)
Frame.BorderSizePixel = 2
Frame.Position = UDim2.new(0.5, -275, 0.5, -175)
Frame.Size = UDim2.new(0, 550, 0, 350)
Frame.Active = true
Frame.Draggable = true

-- Add corner radius for modern look
local FrameCorner = Instance.new("UICorner")
FrameCorner.CornerRadius = UDim.new(0, 8)
FrameCorner.Parent = Frame

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Parent = Frame
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TitleBar.BorderSizePixel = 0
TitleBar.Size = UDim2.new(1, 0, 0, 30)

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = TitleBar

-- Title
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Parent = TitleBar
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 10, 0, 0)
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Font = Enum.Font.GothamBold
Title.Text = "MinimalHackGUI v2.1 - Enhanced by Fari Noveri"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 12
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Status Indicator
local StatusIndicator = Instance.new("Frame")
StatusIndicator.Name = "StatusIndicator"
StatusIndicator.Parent = TitleBar
StatusIndicator.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
StatusIndicator.BorderSizePixel = 0
StatusIndicator.Position = UDim2.new(1, -45, 0.5, -3)
StatusIndicator.Size = UDim2.new(0, 6, 0, 6)

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(1, 0)
StatusCorner.Parent = StatusIndicator

-- Minimize Button
local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Parent = TitleBar
MinimizeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
MinimizeButton.BorderSizePixel = 0
MinimizeButton.Position = UDim2.new(1, -25, 0.5, -8)
MinimizeButton.Size = UDim2.new(0, 16, 0, 16)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "−"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextSize = 10

local MinButtonCorner = Instance.new("UICorner")
MinButtonCorner.CornerRadius = UDim.new(0, 3)
MinButtonCorner.Parent = MinimizeButton

-- Minimized Logo (Enhanced)
local MinimizedLogo = Instance.new("Frame")
MinimizedLogo.Name = "MinimizedLogo"
MinimizedLogo.Parent = ScreenGui
MinimizedLogo.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MinimizedLogo.BorderColor3 = Color3.fromRGB(60, 60, 60)
MinimizedLogo.BorderSizePixel = 2
MinimizedLogo.Position = UDim2.new(0, 10, 0, 10)
MinimizedLogo.Size = UDim2.new(0, 40, 0, 40)
MinimizedLogo.Visible = false
MinimizedLogo.Active = true
MinimizedLogo.Draggable = true

local LogoCorner = Instance.new("UICorner")
LogoCorner.CornerRadius = UDim.new(0, 8)
LogoCorner.Parent = MinimizedLogo

local LogoText = Instance.new("TextLabel")
LogoText.Parent = MinimizedLogo
LogoText.BackgroundTransparency = 1
LogoText.Size = UDim2.new(1, 0, 1, 0)
LogoText.Font = Enum.Font.GothamBold
LogoText.Text = "MH"
LogoText.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoText.TextSize = 14
LogoText.TextStrokeTransparency = 0.3
LogoText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

local LogoButton = Instance.new("TextButton")
LogoButton.Parent = MinimizedLogo
LogoButton.BackgroundTransparency = 1
LogoButton.Size = UDim2.new(1, 0, 1, 0)
LogoButton.Text = ""

-- Enhanced Loading Status with Progress Bar
local LoadingFrame = Instance.new("Frame")
LoadingFrame.Name = "LoadingFrame"
LoadingFrame.Parent = Frame
LoadingFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
LoadingFrame.BorderSizePixel = 0
LoadingFrame.Position = UDim2.new(0, 5, 1, -35)
LoadingFrame.Size = UDim2.new(1, -10, 0, 30)

local LoadingCorner = Instance.new("UICorner")
LoadingCorner.CornerRadius = UDim.new(0, 5)
LoadingCorner.Parent = LoadingFrame

local LoadingStatus = Instance.new("TextLabel")
LoadingStatus.Name = "LoadingStatus"
LoadingStatus.Parent = LoadingFrame
LoadingStatus.BackgroundTransparency = 1
LoadingStatus.Position = UDim2.new(0, 8, 0, 0)
LoadingStatus.Size = UDim2.new(1, -16, 0, 15)
LoadingStatus.Font = Enum.Font.Gotham
LoadingStatus.Text = "Initializing enhanced modules..."
LoadingStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
LoadingStatus.TextSize = 9
LoadingStatus.TextXAlignment = Enum.TextXAlignment.Left

-- Progress Bar
local ProgressBar = Instance.new("Frame")
ProgressBar.Name = "ProgressBar"
ProgressBar.Parent = LoadingFrame
ProgressBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ProgressBar.BorderSizePixel = 0
ProgressBar.Position = UDim2.new(0, 8, 0, 18)
ProgressBar.Size = UDim2.new(1, -16, 0, 4)

local ProgressCorner = Instance.new("UICorner")
ProgressCorner.CornerRadius = UDim.new(0, 2)
ProgressCorner.Parent = ProgressBar

local ProgressFill = Instance.new("Frame")
ProgressFill.Name = "ProgressFill"
ProgressFill.Parent = ProgressBar
ProgressFill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
ProgressFill.BorderSizePixel = 0
ProgressFill.Size = UDim2.new(0, 0, 1, 0)

local FillCorner = Instance.new("UICorner")
FillCorner.CornerRadius = UDim.new(0, 2)
FillCorner.Parent = ProgressFill

-- Category Container with Enhanced Scrolling
local CategoryContainer = Instance.new("ScrollingFrame")
CategoryContainer.Parent = Frame
CategoryContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
CategoryContainer.BorderSizePixel = 0
CategoryContainer.Position = UDim2.new(0, 8, 0, 38)
CategoryContainer.Size = UDim2.new(0, 120, 1, -80)
CategoryContainer.ScrollBarThickness = 6
CategoryContainer.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
CategoryContainer.ScrollingDirection = Enum.ScrollingDirection.Y
CategoryContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
CategoryContainer.CanvasSize = UDim2.new(0, 0, 0, 0)

local CatCorner = Instance.new("UICorner")
CatCorner.CornerRadius = UDim.new(0, 6)
CatCorner.Parent = CategoryContainer

local CategoryLayout = Instance.new("UIListLayout")
CategoryLayout.Parent = CategoryContainer
CategoryLayout.Padding = UDim.new(0, 4)
CategoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
CategoryLayout.FillDirection = Enum.FillDirection.Vertical

-- Update category canvas size
CategoryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    CategoryContainer.CanvasSize = UDim2.new(0, 0, 0, CategoryLayout.AbsoluteContentSize.Y + 15)
end)

-- Enhanced Feature Container
local FeatureContainer = Instance.new("ScrollingFrame")
FeatureContainer.Parent = Frame
FeatureContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
FeatureContainer.BorderSizePixel = 0
FeatureContainer.Position = UDim2.new(0, 136, 0, 38)
FeatureContainer.Size = UDim2.new(1, -144, 1, -80)
FeatureContainer.ScrollBarThickness = 6
FeatureContainer.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
FeatureContainer.ScrollingDirection = Enum.ScrollingDirection.Y
FeatureContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
FeatureContainer.CanvasSize = UDim2.new(0, 0, 0, 0)

local FeatCorner = Instance.new("UICorner")
FeatCorner.CornerRadius = UDim.new(0, 6)
FeatCorner.Parent = FeatureContainer

local FeatureLayout = Instance.new("UIListLayout")
FeatureLayout.Parent = FeatureContainer
FeatureLayout.Padding = UDim.new(0, 3)
FeatureLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Update feature canvas size
FeatureLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    FeatureContainer.CanvasSize = UDim2.new(0, 0, 0, FeatureLayout.AbsoluteContentSize.Y + 15)
end)

-- Enhanced Categories with Icons
local categories = {
    {name = "Movement", order = 1, icon = "🏃"},
    {name = "Player", order = 2, icon = "👤"},
    {name = "Teleport", order = 3, icon = "📍"},
    {name = "Visual", order = 4, icon = "👁"},
    {name = "Utility", order = 5, icon = "🔧"},
    {name = "AntiAdmin", order = 6, icon = "🛡"},
    {name = "Settings", order = 7, icon = "⚙"},
    {name = "Info", order = 8, icon = "ℹ"}
}

local categoryFrames = {}
local isMinimized = false

-- Enhanced Module Loading System
local modules = {}
local modulesLoaded = {}
local moduleLoadingStatus = {}
local loadingProgress = 0

-- Updated URLs with fallbacks
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

-- Fallback URLs
local fallbackURLs = {
    -- Add alternative sources if needed
}

-- Enhanced progress update function
local function updateProgress(current, total, message)
    loadingProgress = math.floor((current / total) * 100)
    ProgressFill:TweenSize(
        UDim2.new(current / total, 0, 1, 0),
        Enum.EasingDirection.Out,
        Enum.EasingStyle.Quad,
        0.3,
        true
    )
    
    if LoadingStatus then
        LoadingStatus.Text = string.format("%s (%d%%)", message, loadingProgress)
        StatusIndicator.BackgroundColor3 = current == total and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 165, 0)
        print("[ENHANCED LOADER] " .. message .. " (" .. loadingProgress .. "%)")
    end
end

-- Enhanced module loading with better error handling
local function loadModule(moduleName)
    local maxRetries = 4
    local retryDelay = 0.5
    
    if not moduleURLs[moduleName] then
        warn("[ENHANCED LOADER] No URL defined for module: " .. moduleName)
        moduleLoadingStatus[moduleName] = "❌ No URL defined"
        return false
    end
    
    for attempt = 1, maxRetries do
        local success, result = pcall(function()
            print(string.format("[ENHANCED LOADER] 📥 Attempt %d/%d for %s", attempt, maxRetries, moduleName))
            
            -- Try multiple HTTP methods
            local response
            local methods = {
                function() return HttpService:GetAsync(moduleURLs[moduleName], false) end,
                function() return game:HttpGet(moduleURLs[moduleName]) end
            }
            
            local httpSuccess = false
            local httpError = "All HTTP methods failed"
            
            for i, method in ipairs(methods) do
                local methodSuccess, methodResult = pcall(method)
                if methodSuccess and methodResult then
                    response = methodResult
                    httpSuccess = true
                    print(string.format("[ENHANCED LOADER] ✅ HTTP method %d succeeded for %s", i, moduleName))
                    break
                else
                    print(string.format("[ENHANCED LOADER] ❌ HTTP method %d failed for %s: %s", i, moduleName, tostring(methodResult)))
                end
            end
            
            if not httpSuccess then
                error("All HTTP methods failed: " .. httpError)
            end
            
            -- Enhanced response validation
            if not response or response == "" then
                error("Empty response received")
            end
            
            if #response < 50 then
                error("Response too short (likely error page)")
            end
            
            if response:find("404") or response:find("Not Found") or response:find("<!DOCTYPE") then
                error("Received error page instead of Lua code")
            end
            
            -- Validate Lua syntax
            if not (response:find("local") or response:find("function") or response:find("return") or response:find("--")) then
                error("Response doesn't appear to be valid Lua code")
            end
            
            print(string.format("[ENHANCED LOADER] ✅ %s response validated (length: %d)", moduleName, #response))
            
            -- Compile and execute
            local moduleFunc, loadError = loadstring(response, moduleName .. "_module")
            if not moduleFunc then
                error("Compilation failed: " .. tostring(loadError))
            end
            
            local moduleTable = moduleFunc()
            
            if not moduleTable then
                error("Module function returned nil")
            end
            
            if type(moduleTable) ~= "table" then
                error("Module must return a table, got: " .. type(moduleTable))
            end
            
            -- Validate required functions
            local requiredFunctions = {
                Movement = {"loadMovementButtons", "init"},
                Player = {"loadPlayerButtons", "init"},
                Teleport = {"loadTeleportButtons", "init"},
                Visual = {"loadVisualButtons", "init"},
                Utility = {"loadUtilityButtons", "init"},
                AntiAdmin = {"loadAntiAdminButtons", "init"},
                Settings = {"loadSettingsButtons", "init"},
                Info = {"createInfoDisplay", "init"}
            }
            
            if requiredFunctions[moduleName] then
                for _, funcName in ipairs(requiredFunctions[moduleName]) do
                    if type(moduleTable[funcName]) ~= "function" then
                        warn(string.format("[ENHANCED LOADER] ⚠️ Missing function %s in module %s", funcName, moduleName))
                    end
                end
            end
            
            print(string.format("[ENHANCED LOADER] ✅ Successfully loaded and validated %s", moduleName))
            return moduleTable
            
        end)
        
        if success and result then
            modules[moduleName] = result
            modulesLoaded[moduleName] = true
            moduleLoadingStatus[moduleName] = string.format("✅ Success (attempt %d)", attempt)
            return true
        else
            local errorMsg = tostring(result or "Unknown error")
            warn(string.format("[ENHANCED LOADER] ❌ Attempt %d/%d failed for %s: %s", attempt, maxRetries, moduleName, errorMsg))
            moduleLoadingStatus[moduleName] = string.format("❌ Attempt %d failed: %s", attempt, errorMsg:sub(1, 50))
            
            if attempt < maxRetries then
                task.wait(retryDelay)
                retryDelay = retryDelay * 1.2 -- Exponential backoff
            end
        end
    end
    
    -- Try fallback if available
    if fallbackURLs[moduleName] then
        print("[ENHANCED LOADER] 🔄 Trying fallback source for " .. moduleName)
        local fallbackSuccess = loadFromFallback(moduleName)
        if fallbackSuccess then
            return true
        end
    end
    
    moduleLoadingStatus[moduleName] = "❌ All attempts failed"
    return false
end

-- Fallback loading function
local function loadFromFallback(moduleName)
    if not fallbackURLs[moduleName] then
        return false
    end
    
    local success, result = pcall(function()
        local response = game:HttpGet(fallbackURLs[moduleName])
        if not response or response == "" then
            error("Empty fallback response")
        end
        
        local moduleFunc, loadError = loadstring(response, moduleName .. "_fallback")
        if not moduleFunc then
            error("Fallback compilation failed: " .. tostring(loadError))
        end
        
        return moduleFunc()
    end)
    
    if success and result and type(result) == "table" then
        modules[moduleName] = result
        modulesLoaded[moduleName] = true
        moduleLoadingStatus[moduleName] = "✅ Success (fallback source)"
        return true
    end
    
    return false
end

-- Enhanced dependencies
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

-- Enhanced module initialization
local function initializeModules()
    updateProgress(0, 1, "Initializing modules...")
    local initializedCount = 0
    local totalModules = 0
    
    for _ in pairs(modules) do
        totalModules = totalModules + 1
    end
    
    local current = 0
    for moduleName, module in pairs(modules) do
        current = current + 1
        updateProgress(current, totalModules, "Initializing " .. moduleName)
        
        if module and type(module.init) == "function" then
            local success, result = pcall(function()
                dependencies.character = character
                dependencies.humanoid = humanoid
                dependencies.rootPart = rootPart
                return module.init(dependencies)
            end)
            if not success then
                warn("[ENHANCED LOADER] ❌ Failed to initialize " .. moduleName .. ": " .. tostring(result))
                moduleLoadingStatus[moduleName] = moduleLoadingStatus[moduleName] .. " | Init failed"
            else
                print("[ENHANCED LOADER] ✅ Initialized " .. moduleName)
                initializedCount = initializedCount + 1
            end
        else
            warn("[ENHANCED LOADER] ⚠️ Module " .. moduleName .. " has no init function")
        end
        
        task.wait(0.05) -- Small delay for smooth progress
    end
    
    updateProgress(totalModules, totalModules, string.format("✅ Initialized %d/%d modules", initializedCount, totalModules))
end

-- Enhanced exclusive feature handling
local function isExclusiveFeature(featureName)
    local exclusives = {"Fly", "Noclip", "Freecam", "Speed Hack", "Jump Hack", "Infinite Jump"}
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
        print("[ENHANCED LOADER] 🔄 Disabled exclusive feature: " .. activeFeature.name)
    end
    activeFeature = nil
end

-- Enhanced button creation with modern styling
local function createButton(name, callback, categoryName)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Parent = FeatureContainer
    button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -6, 0, 28)
    button.Font = Enum.Font.Gotham
    button.Text = name
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 10
    button.LayoutOrder = #FeatureContainer:GetChildren()
    
    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 4)
    ButtonCorner.Parent = button
    
    -- Enhanced hover effects
    button.MouseEnter:Connect(function()
        button:TweenSize(UDim2.new(1, -4, 0, 28), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
        button.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
    end)
    
    button.MouseLeave:Connect(function()
        button:TweenSize(UDim2.new(1, -6, 0, 28), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
        button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    end)
    
    if type(callback) == "function" then
        button.MouseButton1Click:Connect(function()
            button.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
            task.wait(0.1)
            button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            
            local success, errorMsg = pcall(callback)
            if not success then
                warn("❌ Error executing callback for " .. name .. ": " .. tostring(errorMsg))
                button.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
                task.wait(0.5)
                button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            end
        end)
    end
    
    return button
end

-- Enhanced toggle button with visual feedback
local function createToggleButton(name, callback, categoryName, disableCallback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Parent = FeatureContainer
    button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -6, 0, 28)
    button.Font = Enum.Font.Gotham
    button.Text = name
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 10
    button.LayoutOrder = #FeatureContainer:GetChildren()
    
    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 4)
    ButtonCorner.Parent = button
    
    -- Toggle indicator
    local ToggleIndicator = Instance.new("Frame")
    ToggleIndicator.Name = "ToggleIndicator"
    ToggleIndicator.Parent = button
    ToggleIndicator.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    ToggleIndicator.BorderSizePixel = 0
    ToggleIndicator.Position = UDim2.new(1, -8, 0.5, -2)
    ToggleIndicator.Size = UDim2.new(0, 4, 0, 4)
    
    local IndicatorCorner = Instance.new("UICorner")
    IndicatorCorner.CornerRadius = UDim.new(1, 0)
    IndicatorCorner.Parent = ToggleIndicator
    
    -- Ensure category state exists
    if not categoryStates[categoryName] then
        categoryStates[categoryName] = {}
    end
    
    if categoryStates[categoryName][name] == nil then
        categoryStates[categoryName][name] = false
    end
    
    -- Update visual state
    local function updateVisualState()
        local isEnabled = categoryStates[categoryName][name]
        button.BackgroundColor3 = isEnabled and Color3.fromRGB(40, 120, 40) or Color3.fromRGB(45, 45, 45)
        ToggleIndicator.BackgroundColor3 = isEnabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
    end
    
    updateVisualState()
    
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
        updateVisualState()
        
        if type(callback) == "function" then
            local success, errorMsg = pcall(callback, newState)
            if not success then
                warn("❌ Error executing toggle callback for " .. name .. ": " .. tostring(errorMsg))
                -- Revert state on error
                categoryStates[categoryName][name] = not newState
                updateVisualState()
            end
        end
    end)
    
    -- Enhanced hover effects
    button.MouseEnter:Connect(function()
        button:TweenSize(UDim2.new(1, -4, 0, 28), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
        local isEnabled = categoryStates[categoryName][name]
        button.BackgroundColor3 = isEnabled and Color3.fromRGB(50, 140, 50) or Color3.fromRGB(65, 65, 65)
    end)
    
    button.MouseLeave:Connect(function()
        button:TweenSize(UDim2.new(1, -6, 0, 28), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
        updateVisualState()
    end)
    
    return button
end

-- Enhanced load buttons function with better error handling
local function loadButtons()
    print("[ENHANCED LOADER] 🔄 Loading buttons for category: " .. selectedCategory)
    
    -- Clear existing buttons with animation
    for _, child in pairs(FeatureContainer:GetChildren()) do
        if child:IsA("TextButton") or (child:IsA("TextLabel") and child.Name ~= "FeatureLayout") then
            child:TweenSize(UDim2.new(1, -6, 0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.2, true)
            task.wait(0.05)
            child:Destroy()
        end
    end
    
    -- Update category button states
    for categoryName, categoryData in pairs(categoryFrames) do
        if categoryData and categoryData.button then
            local isSelected = categoryName == selectedCategory
            categoryData.button.BackgroundColor3 = isSelected and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(35, 35, 35)
            categoryData.button.TextColor3 = isSelected and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
        end
    end

    if not selectedCategory then
        warn("[ENHANCED LOADER] ❌ No category selected!")
        return
    end
    
    -- Check if module is loaded
    if not modules[selectedCategory] then
        local statusFrame = Instance.new("Frame")
        statusFrame.Name = "StatusFrame"
        statusFrame.Parent = FeatureContainer
        statusFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        statusFrame.BorderSizePixel = 0
        statusFrame.Size = UDim2.new(1, -6, 0, 80)
        
        local StatusCorner = Instance.new("UICorner")
        StatusCorner.CornerRadius = UDim.new(0, 6)
        StatusCorner.Parent = statusFrame
        
        local statusLabel = Instance.new("TextLabel")
        statusLabel.Parent = statusFrame
        statusLabel.BackgroundTransparency = 1
        statusLabel.Position = UDim2.new(0, 10, 0, 10)
        statusLabel.Size = UDim2.new(1, -20, 1, -20)
        statusLabel.Font = Enum.Font.Gotham
        statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        statusLabel.TextSize = 9
        statusLabel.TextXAlignment = Enum.TextXAlignment.Left
        statusLabel.TextYAlignment = Enum.TextYAlignment.Top
        statusLabel.TextWrapped = true
        
        local status = moduleLoadingStatus[selectedCategory] or "❓ Not loaded"
        if modulesLoaded[selectedCategory] == nil then
            statusLabel.Text = "🔄 Loading " .. selectedCategory .. " module...\n\nStatus: " .. status .. "\n\nPlease wait..."
            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
            
            -- Try to load the module if not already attempted
            task.spawn(function()
                if loadModule(selectedCategory) then
                    task.wait(0.5)
                    loadButtons() -- Reload buttons after successful load
                end
            end)
        else
            statusLabel.Text = "❌ Failed to load " .. selectedCategory .. " module\n\nStatus: " .. status .. "\n\nTry selecting another category or restart the script."
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            
            -- Add retry button
            local retryButton = createButton("🔄 Retry " .. selectedCategory, function()
                moduleLoadingStatus[selectedCategory] = nil
                modulesLoaded[selectedCategory] = nil
                loadButtons()
            end, selectedCategory)
            retryButton.Position = UDim2.new(0, 0, 1, -35)
            retryButton.Size = UDim2.new(1, -6, 0, 25)
            retryButton.BackgroundColor3 = Color3.fromRGB(200, 100, 50)
        end
        return
    end
    
    local module = modules[selectedCategory]
    local success = false
    local errorMessage = nil

    -- Enhanced module loading with specific handlers
    if selectedCategory == "Movement" and module.loadMovementButtons then
        success, errorMessage = pcall(function()
            print("[ENHANCED LOADER] 🏃 Loading Movement buttons...")
            module.loadMovementButtons(
                function(name, callback) return createButton(name, callback, "Movement") end,
                function(name, callback, disableCallback) return createToggleButton(name, callback, "Movement", disableCallback) end
            )
        end)
        
    elseif selectedCategory == "Player" and module.loadPlayerButtons then
        success, errorMessage = pcall(function()
            local selectedPlayer = module.getSelectedPlayer and module.getSelectedPlayer() or nil
            print("[ENHANCED LOADER] 👤 Loading Player buttons with selectedPlayer: " .. tostring(selectedPlayer))
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
            print("[ENHANCED LOADER] 📍 Loading Teleport buttons...")
            module.loadTeleportButtons(
                function(name, callback) return createButton(name, callback, "Teleport") end,
                selectedPlayer, freecamEnabled, freecamPosition, toggleFreecam
            )
        end)
        
    elseif selectedCategory == "Visual" and module.loadVisualButtons then
        success, errorMessage = pcall(function()
            print("[ENHANCED LOADER] 👁 Loading Visual buttons...")
            module.loadVisualButtons(function(name, callback, disableCallback)
                return createToggleButton(name, callback, "Visual", disableCallback)
            end)
        end)
        
    elseif selectedCategory == "Utility" and module.loadUtilityButtons then
        success, errorMessage = pcall(function()
            print("[ENHANCED LOADER] 🔧 Loading Utility buttons...")
            module.loadUtilityButtons(function(name, callback)
                return createButton(name, callback, "Utility")
            end)
        end)
        
    elseif selectedCategory == "AntiAdmin" and module.loadAntiAdminButtons then
        success, errorMessage = pcall(function()
            print("[ENHANCED LOADER] 🛡 Loading AntiAdmin buttons...")
            module.loadAntiAdminButtons(function(name, callback, disableCallback)
                return createToggleButton(name, callback, "AntiAdmin", disableCallback)
            end, FeatureContainer)
        end)
        
    elseif selectedCategory == "Settings" and module.loadSettingsButtons then
        success, errorMessage = pcall(function()
            print("[ENHANCED LOADER] ⚙ Loading Settings buttons...")
            module.loadSettingsButtons(function(name, callback)
                return createButton(name, callback, "Settings")
            end)
        end)
        
    elseif selectedCategory == "Info" and module.createInfoDisplay then
        success, errorMessage = pcall(function()
            print("[ENHANCED LOADER] ℹ Loading Info display...")
            module.createInfoDisplay(FeatureContainer)
        end)
        
    else
        errorMessage = "Module " .. selectedCategory .. " is missing required functions!"
        warn("[ENHANCED LOADER] ❌ " .. errorMessage)
    end

    -- Enhanced error display
    if not success and errorMessage then
        local errorFrame = Instance.new("Frame")
        errorFrame.Name = "ErrorFrame"
        errorFrame.Parent = FeatureContainer
        errorFrame.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
        errorFrame.BorderSizePixel = 0
        errorFrame.Size = UDim2.new(1, -6, 0, 100)
        
        local ErrorCorner = Instance.new("UICorner")
        ErrorCorner.CornerRadius = UDim.new(0, 6)
        ErrorCorner.Parent = errorFrame
        
        local errorLabel = Instance.new("TextLabel")
        errorLabel.Parent = errorFrame
        errorLabel.BackgroundTransparency = 1
        errorLabel.Position = UDim2.new(0, 10, 0, 10)
        errorLabel.Size = UDim2.new(1, -20, 1, -20)
        errorLabel.Font = Enum.Font.Gotham
        errorLabel.Text = "❌ Error loading " .. selectedCategory .. " buttons:\n\n" .. tostring(errorMessage) .. "\n\nModule status: " .. (moduleLoadingStatus[selectedCategory] or "Unknown")
        errorLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
        errorLabel.TextSize = 9
        errorLabel.TextXAlignment = Enum.TextXAlignment.Left
        errorLabel.TextYAlignment = Enum.TextYAlignment.Top
        errorLabel.TextWrapped = true
        print("[ENHANCED LOADER] ❌ Error: " .. tostring(errorMessage))
    elseif success then
        print("[ENHANCED LOADER] ✅ Successfully loaded buttons for " .. selectedCategory)
    end
end

-- Enhanced category button creation with icons and animations
for _, category in ipairs(categories) do
    local categoryButton = Instance.new("TextButton")
    categoryButton.Name = category.name .. "Category"
    categoryButton.Parent = CategoryContainer
    categoryButton.BackgroundColor3 = selectedCategory == category.name and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(35, 35, 35)
    categoryButton.BorderSizePixel = 0
    categoryButton.Size = UDim2.new(1, -8, 0, 32)
    categoryButton.LayoutOrder = category.order
    categoryButton.Font = Enum.Font.GothamBold
    categoryButton.Text = (category.icon or "") .. " " .. category.name
    categoryButton.TextColor3 = selectedCategory == category.name and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
    categoryButton.TextSize = 9

    local CategoryCorner = Instance.new("UICorner")
    CategoryCorner.CornerRadius = UDim.new(0, 5)
    CategoryCorner.Parent = categoryButton

    categoryButton.MouseButton1Click:Connect(function()
        if selectedCategory ~= category.name then
            selectedCategory = category.name
            loadButtons()
            
            -- Animate button press
            categoryButton:TweenSize(UDim2.new(1, -6, 0, 32), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
            task.wait(0.1)
            categoryButton:TweenSize(UDim2.new(1, -8, 0, 32), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
        end
    end)

    categoryButton.MouseEnter:Connect(function()
        if selectedCategory ~= category.name then
            categoryButton:TweenSize(UDim2.new(1, -6, 0, 32), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
            categoryButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            categoryButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end)

    categoryButton.MouseLeave:Connect(function()
        if selectedCategory ~= category.name then
            categoryButton:TweenSize(UDim2.new(1, -8, 0, 32), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
            categoryButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            categoryButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end)

    categoryFrames[category.name] = {button = categoryButton}
    categoryStates[category.name] = {}
end

-- Enhanced minimize/maximize with animations
local function toggleMinimize()
    isMinimized = not isMinimized
    
    if isMinimized then
        -- Animate minimize
        Frame:TweenSize(UDim2.new(0, 0, 0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Back, 0.3, true)
        Frame:TweenPosition(UDim2.new(0.5, 0, 0.5, 0), Enum.EasingDirection.In, Enum.EasingStyle.Back, 0.3, true)
        task.wait(0.3)
        Frame.Visible = false
        MinimizedLogo.Visible = true
        MinimizedLogo:TweenSize(UDim2.new(0, 40, 0, 40), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.3, true)
    else
        -- Animate maximize
        MinimizedLogo:TweenSize(UDim2.new(0, 0, 0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Back, 0.3, true)
        task.wait(0.3)
        MinimizedLogo.Visible = false
        Frame.Visible = true
        Frame:TweenSize(UDim2.new(0, 550, 0, 350), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.3, true)
        Frame:TweenPosition(UDim2.new(0.5, -275, 0.5, -175), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.3, true)
    end
    
    MinimizeButton.Text = isMinimized and "+" or "−"
end

-- Enhanced reset states function
local function resetStates()
    print("[ENHANCED LOADER] 🔄 Resetting all states...")
    
    -- Disconnect all connections safely
    for name, connection in pairs(connections) do
        if connection and connection.Disconnect then
            pcall(function() connection:Disconnect() end)
        end
    end
    connections = {}
    
    -- Reset module states
    for moduleName, module in pairs(modules) do
        if module and type(module.resetStates) == "function" then
            pcall(function() 
                print("[ENHANCED LOADER] 🔄 Resetting " .. moduleName .. " states")
                module.resetStates() 
            end)
        end
    end
    
    -- Clear active exclusive feature
    disableActiveFeature()
    
    -- Reload current category
    if selectedCategory then
        task.spawn(loadButtons)
    end
    
    print("[ENHANCED LOADER] ✅ All states reset successfully")
end

-- Enhanced character setup
local function onCharacterAdded(newCharacter)
    if not newCharacter then return end
    
    print("[ENHANCED LOADER] 👤 Setting up new character...")
    
    local success, result = pcall(function()
        character = newCharacter
        humanoid = character:WaitForChild("Humanoid", 30)
        rootPart = character:WaitForChild("HumanoidRootPart", 30)
        
        if not humanoid or not rootPart then
            error("Failed to find required character components")
        end
        
        -- Update dependencies
        dependencies.character = character
        dependencies.humanoid = humanoid
        dependencies.rootPart = rootPart
        
        print("[ENHANCED LOADER] ✅ Character setup complete")
        
        -- Reinitialize modules with new character
        initializeModules()
        
        -- Set up death connection
        if humanoid.Died then
            connections.humanoidDied = humanoid.Died:Connect(function()
                print("[ENHANCED LOADER] 💀 Character died, resetting states...")
                resetStates()
            end)
        end
        
        StatusIndicator.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        
    end)
    
    if not success then
        warn("[ENHANCED LOADER] ❌ Failed to set up character: " .. tostring(result))
        StatusIndicator.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    end
end

-- Initialize character
if player.Character then
    onCharacterAdded(player.Character)
end
connections.characterAdded = player.CharacterAdded:Connect(onCharacterAdded)

-- Enhanced event connections
MinimizeButton.MouseButton1Click:Connect(function()
    -- Add click animation
    MinimizeButton:TweenSize(UDim2.new(0, 14, 0, 14), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.1, true)
    task.wait(0.1)
    MinimizeButton:TweenSize(UDim2.new(0, 16, 0, 16), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
    toggleMinimize()
end)

LogoButton.MouseButton1Click:Connect(function()
    -- Add click animation
    MinimizedLogo:TweenSize(UDim2.new(0, 35, 0, 35), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.1, true)
    task.wait(0.1)
    MinimizedLogo:TweenSize(UDim2.new(0, 40, 0, 40), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true)
    toggleMinimize()
end)

-- Enhanced hotkeys
connections.toggleGui = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.Home then
        toggleMinimize()
    elseif input.KeyCode == Enum.KeyCode.F9 then
        showModuleStatus()
    elseif input.KeyCode == Enum.KeyCode.F10 then
        resetStates()
    end
end)

-- Enhanced module loading process
local function startEnhancedModuleLoading()
    updateProgress(0, 1, "🚀 Starting enhanced module loading...")
    
    local totalModules = 0
    for _ in pairs(moduleURLs) do
        totalModules = totalModules + 1
    end
    
    local loadedCount = 0
    local failedCount = 0
    local currentModule = 0
    
    print("[ENHANCED LOADER] 📊 Loading " .. totalModules .. " modules...")
    
    -- Load modules with progress tracking
    for moduleName, _ in pairs(moduleURLs) do
        currentModule = currentModule + 1
        updateProgress(currentModule - 1, totalModules, string.format("📥 Loading %s (%d/%d)", moduleName, currentModule, totalModules))
        
        local startTime = tick()
        local success = loadModule(moduleName)
        local loadTime = tick() - startTime
        
        if success then
            loadedCount = loadedCount + 1
            print(string.format("[ENHANCED LOADER] ✅ %s loaded successfully (%.2fs)", moduleName, loadTime))
        else
            failedCount = failedCount + 1
            print(string.format("[ENHANCED LOADER] ❌ %s failed to load (%.2fs)", moduleName, loadTime))
        end
        
        -- Update progress
        updateProgress(currentModule, totalModules, string.format("📦 Processed %s", moduleName))
        
        -- Prevent overwhelming HTTP service
        if currentModule < totalModules then
            task.wait(0.3)
        end
    end
    
    -- Final summary
    local summaryMessage = ""
    if loadedCount > 0 then
        summaryMessage = string.format("✅ Loaded %d/%d modules successfully", loadedCount, totalModules)
        StatusIndicator.BackgroundColor3 = failedCount == 0 and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 165, 0)
    else
        summaryMessage = "❌ No modules loaded - check internet connection"
        StatusIndicator.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    end
    
    updateProgress(totalModules, totalModules, summaryMessage)
    print("[ENHANCED LOADER] 📈 Loading summary: " .. summaryMessage)
    
    if failedCount > 0 then
        local failedModules = getFailedModuleNames()
        print("[ENHANCED LOADER] ❌ Failed modules: " .. table.concat(failedModules, ", "))
        
        -- Attempt recovery
        task.spawn(function()
            task.wait(2)
            local recovered = retryFailedModules()
            if recovered > 0 then
                updateProgress(totalModules, totalModules, string.format("🔄 Recovered %d additional modules", recovered))
            end
        end)
    end
    
    if loadedCount > 0 then
        initializeModules()
        loadButtons()
        
        -- Auto-hide loading status after success
        task.spawn(function()
            task.wait(3)
            if LoadingFrame then
                LoadingFrame:TweenSize(UDim2.new(1, -10, 0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.5, true)
                task.wait(0.5)
                LoadingFrame.Visible = false
            end
        end)
    end
    
    print("[ENHANCED LOADER] 🎉 Enhanced loading process complete!")
    return loadedCount > 0
end

-- Helper functions
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

-- Enhanced retry system
local function retryFailedModules()
    local retriedCount = 0
    local failedModules = getFailedModuleNames()
    
    if #failedModules == 0 then
        return 0
    end
    
    updateProgress(0, #failedModules, "🔄 Retrying failed modules...")
    
    for i, moduleName in ipairs(failedModules) do
        updateProgress(i - 1, #failedModules, "🔄 Retrying " .. moduleName)
        
        print("[ENHANCED LOADER] 🔄 Retrying " .. moduleName .. " with alternative methods...")
        
        -- Try fallback first, then alternative HTTP method
        local success = loadFromFallback(moduleName) or alternativeLoadModule(moduleName)
        
        if success then
            retriedCount = retriedCount + 1
            print("[ENHANCED LOADER] ✅ Successfully recovered " .. moduleName)
        else
            print("[ENHANCED LOADER] ❌ Still failed to load " .. moduleName)
        end
        
        updateProgress(i, #failedModules, string.format("🔄 Processed %s", moduleName))
        task.wait(0.3)
    end
    
    if retriedCount > 0 then
        updateProgress(#failedModules, #failedModules, string.format("✅ Recovered %d/%d modules", retriedCount, #failedModules))
        initializeModules()
        loadButtons()
    else
        updateProgress(#failedModules, #failedModules, "❌ No additional modules recovered")
    end
    
    return retriedCount
end

-- Alternative loading method
local function alternativeLoadModule(moduleName)
    local success, result = pcall(function()
        print("[ENHANCED LOADER] 🔄 Trying alternative HTTP method for " .. moduleName)
        
        local response = game:HttpGet(moduleURLs[moduleName])
        
        if not response or response == "" or #response < 50 then
            error("Invalid response from alternative method")
        end
        
        if response:find("404") or response:find("<!DOCTYPE") then
            error("Error page received")
        end
        
        local moduleFunc, loadError = loadstring(response, moduleName .. "_alt")
        if not moduleFunc then
            error("Compilation failed: " .. tostring(loadError))
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
        moduleLoadingStatus[moduleName] = "✅ Success (alternative HTTP)"
        return true
    else
        moduleLoadingStatus[moduleName] = "❌ Alternative method failed: " .. tostring(result or "Unknown")
        return false
    end
end

-- Enhanced debug function
local function showModuleStatus()
    print("\n[ENHANCED LOADER] ═══ DETAILED MODULE STATUS ═══")
    print(string.format("[ENHANCED LOADER] 📊 Total modules: %d", #categories))
    print(string.format("[ENHANCED LOADER] ✅ Loaded: %d", #getLoadedModuleNames()))
    print(string.format("[ENHANCED LOADER] ❌ Failed: %d", #getFailedModuleNames()))
    print(string.format("[ENHANCED LOADER] 📈 Success rate: %.1f%%", (#getLoadedModuleNames() / #categories) * 100))
    print("[ENHANCED LOADER] ──────────────────────────────")
    
    for i, category in ipairs(categories) do
        local moduleName = category.name
        local status = moduleLoadingStatus[moduleName] or "❓ Not attempted"
        local loaded = modulesLoaded[moduleName] and "✅" or "❌"
        local icon = category.icon or "📦"
        print(string.format("[ENHANCED LOADER] %s %s %s: %s", loaded, icon, moduleName, status))
    end
    
    print("[ENHANCED LOADER] ══════════════════════════════")
    print("[ENHANCED LOADER] 💡 Press F10 to reset all states")
    print("[ENHANCED LOADER] 💡 Press HOME to toggle GUI visibility\n")
end

-- Start the enhanced loading process
task.spawn(function()
    local success = startEnhancedModuleLoading()
    
    if not success then
        StatusIndicator.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        updateProgress(1, 1, "❌ Critical failure - no modules loaded")
    end
end)

-- Final initialization
print("[ENHANCED LOADER] 🚀 MinimalHackGUI Enhanced v2.1 initialized!")
print("[ENHANCED LOADER] ⌨️  Hotkeys:")
print("[ENHANCED LOADER]    🏠 HOME - Toggle GUI visibility")
print("[ENHANCED LOADER]    🔍 F9   - Show module status")
print("[ENHANCED LOADER]    🔄 F10  - Reset all states")
print("[ENHANCED LOADER] 📋 Categories: " .. table.concat({unpack(categories, 1, math.min(4, #categories))}, ", ") .. (#categories > 4 and "..." or ""))