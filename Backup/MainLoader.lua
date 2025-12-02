-- Main entry point for MinimalHackGUI by Fari Noveri - UPDATED VERSION WITH NEW SETTINGS

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService") -- Added for slide animation

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

-- Settings - UPDATED: Removed WalkSpeed, Added GUI Controls
local settings = {
    GuiWidth = {value = 500, min = 300, max = 800, default = 500},
    GuiHeight = {value = 300, min = 200, max = 600, default = 300},
    LogoOpacity = {value = 1.0, min = 0.1, max = 1.0, default = 1.0}
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
Frame.Size = UDim2.new(0, settings.GuiWidth.value, 0, settings.GuiHeight.value)
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

-- ===== SLIDE NOTIFICATION SYSTEM =====
local function createSlideNotification()
    -- Notification Frame
    local NotificationFrame = Instance.new("Frame")
    NotificationFrame.Name = "SlideNotification"
    NotificationFrame.Parent = ScreenGui
    NotificationFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- White background
    NotificationFrame.BorderSizePixel = 0
    NotificationFrame.Size = UDim2.new(0, 200, 0, 70)
    NotificationFrame.Position = UDim2.new(1, 0, 1, -80) -- Start off-screen (right)
    NotificationFrame.ZIndex = 1000 -- High z-index to appear on top
    NotificationFrame.Active = true -- Make it clickable
    
    -- Rounded corners
    local NotificationCorner = Instance.new("UICorner")
    NotificationCorner.CornerRadius = UDim.new(0, 8)
    NotificationCorner.Parent = NotificationFrame
    
    -- Drop shadow effect
    local Shadow = Instance.new("Frame")
    Shadow.Name = "Shadow"
    Shadow.Parent = ScreenGui
    Shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Shadow.BackgroundTransparency = 0.8
    Shadow.BorderSizePixel = 0
    Shadow.Size = UDim2.new(0, 204, 0, 74)
    Shadow.Position = UDim2.new(1, 2, 1, -78)
    Shadow.ZIndex = 999
    
    local ShadowCorner = Instance.new("UICorner")
    ShadowCorner.CornerRadius = UDim.new(0, 8)
    ShadowCorner.Parent = Shadow
    
    -- Logo ImageLabel
    local LogoImage = Instance.new("ImageLabel")
    LogoImage.Name = "Logo"
    LogoImage.Parent = NotificationFrame
    LogoImage.BackgroundTransparency = 1
    LogoImage.Position = UDim2.new(0, 8, 0, 8)
    LogoImage.Size = UDim2.new(0, 35, 0, 35)
    LogoImage.Image = "https://cdn.rafled.com/anime-icons/images/cADJDgHDli9YzzGB5AhH0Aa2dR8Bfu8w.jpg"
    LogoImage.ScaleType = Enum.ScaleType.Fit
    
    -- Logo rounded corners
    local LogoCorner = Instance.new("UICorner")
    LogoCorner.CornerRadius = UDim.new(0, 6)
    LogoCorner.Parent = LogoImage
    
    -- Main Text (Made by fari noveri)
    local MainText = Instance.new("TextLabel")
    MainText.Name = "MainText"
    MainText.Parent = NotificationFrame
    MainText.BackgroundTransparency = 1
    MainText.Position = UDim2.new(0, 50, 0, 8)
    MainText.Size = UDim2.new(1, -58, 0, 20)
    MainText.Font = Enum.Font.GothamBold
    MainText.Text = "Made by fari noveri"
    MainText.TextColor3 = Color3.fromRGB(30, 30, 30)
    MainText.TextSize = 10
    MainText.TextXAlignment = Enum.TextXAlignment.Left
    MainText.TextYAlignment = Enum.TextYAlignment.Center
    
    -- Sub Text (SuperTool)
    local SubText = Instance.new("TextLabel")
    SubText.Name = "SubText"
    SubText.Parent = NotificationFrame
    SubText.BackgroundTransparency = 1
    SubText.Position = UDim2.new(0, 50, 0, 28)
    SubText.Size = UDim2.new(1, -58, 0, 15)
    SubText.Font = Enum.Font.Gotham
    SubText.Text = "SuperTool"
    SubText.TextColor3 = Color3.fromRGB(100, 100, 100)
    SubText.TextSize = 9
    SubText.TextXAlignment = Enum.TextXAlignment.Left
    SubText.TextYAlignment = Enum.TextYAlignment.Center
    
    -- Version/Status Text
    local StatusText = Instance.new("TextLabel")
    StatusText.Name = "StatusText"
    StatusText.Parent = NotificationFrame
    StatusText.BackgroundTransparency = 1
    StatusText.Position = UDim2.new(0, 50, 0, 43)
    StatusText.Size = UDim2.new(1, -58, 0, 15)
    StatusText.Font = Enum.Font.Gotham
    StatusText.Text = "Successfully loaded!"
    StatusText.TextColor3 = Color3.fromRGB(0, 150, 0)
    StatusText.TextSize = 8
    StatusText.TextXAlignment = Enum.TextXAlignment.Left
    StatusText.TextYAlignment = Enum.TextYAlignment.Center
    
    -- Click to dismiss button (invisible overlay)
    local DismissButton = Instance.new("TextButton")
    DismissButton.Name = "DismissButton"
    DismissButton.Parent = NotificationFrame
    DismissButton.BackgroundTransparency = 1
    DismissButton.Size = UDim2.new(1, 0, 1, 0)
    DismissButton.Text = ""
    DismissButton.ZIndex = 1001
    
    -- Animation variables
    local slideInTime = 0.4
    local stayTime = 4.5
    local slideOutTime = 0.3
    
    local slideInPosition = UDim2.new(1, -210, 1, -80) -- Final position (visible)
    local slideOutPosition = UDim2.new(1, 0, 1, -80) -- Off-screen right
    
    local shadowSlideInPosition = UDim2.new(1, -208, 1, -78)
    local shadowSlideOutPosition = UDim2.new(1, 2, 1, -78)
    
    -- Tween info
    local slideInInfo = TweenInfo.new(
        slideInTime,
        Enum.EasingStyle.Quart,
        Enum.EasingDirection.Out,
        0,
        false,
        0
    )
    
    local slideOutInfo = TweenInfo.new(
        slideOutTime,
        Enum.EasingStyle.Quart,
        Enum.EasingDirection.In,
        0,
        false,
        0
    )
    
    -- Slide in animation
    local slideInTween = TweenService:Create(NotificationFrame, slideInInfo, {Position = slideInPosition})
    local shadowSlideInTween = TweenService:Create(Shadow, slideInInfo, {Position = shadowSlideInPosition})
    
    -- Slide out function
    local function slideOut()
        local slideOutTween = TweenService:Create(NotificationFrame, slideOutInfo, {Position = slideOutPosition})
        local shadowSlideOutTween = TweenService:Create(Shadow, slideOutInfo, {Position = shadowSlideOutPosition})
        
        slideOutTween:Play()
        shadowSlideOutTween:Play()
        
        slideOutTween.Completed:Connect(function()
            NotificationFrame:Destroy()
            Shadow:Destroy()
        end)
    end
    
    -- Click to dismiss
    DismissButton.MouseButton1Click:Connect(function()
        slideOut()
    end)
    
    -- Auto dismiss after stay time
    local autoDismissConnection
    
    -- Start animation sequence
    slideInTween:Play()
    shadowSlideInTween:Play()
    
    slideInTween.Completed:Connect(function()
        -- Start auto-dismiss timer after slide in completes
        autoDismissConnection = task.spawn(function()
            task.wait(stayTime)
            slideOut()
        end)
    end)
    
    print("✨ Slide notification created and animated!")
end
-- ===== END SLIDE NOTIFICATION SYSTEM =====

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
    {name = "Info", order = 8},
    {name = "Credit", order = 9}
}

local categoryFrames = {}
local isMinimized = false
local previousMouseBehavior

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
    Info = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Info.lua",
    Credit = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Credit.lua"
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

-- Dependencies for modules - UPDATED with new settings
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

-- Initialize modules function
local function initializeModules()
    print("Initializing loaded modules...")
    local initResults = {}
    
    for moduleName, module in pairs(modules) do
        local success = false
        local errorMsg = nil
        
        if module and type(module.init) == "function" then
            success, errorMsg = pcall(function()
                -- Always update dependencies with current info
                dependencies.character = character
                dependencies.humanoid = humanoid
                dependencies.rootPart = rootPart
                dependencies.ScrollFrame = FeatureContainer
                
                -- Validate critical dependencies before init
                if not dependencies.ScrollFrame then
                    error("ScrollFrame (FeatureContainer) is nil - cannot initialize " .. moduleName)
                end
                
                print("Initializing " .. moduleName .. " with dependencies:", {
                    character = dependencies.character and "OK" or "NIL",
                    humanoid = dependencies.humanoid and "OK" or "NIL",
                    rootPart = dependencies.rootPart and "OK" or "NIL",
                    ScrollFrame = dependencies.ScrollFrame and "OK" or "NIL",
                    ScreenGui = dependencies.ScreenGui and "OK" or "NIL"
                })
                
                local result = module.init(dependencies)
                if result == false then
                    error("Module init returned false")
                end
                return result
            end)
            
            if success then
                print("✓ Initialized module: " .. moduleName)
                initResults[moduleName] = "SUCCESS"
            else
                warn("✗ Failed to initialize module " .. moduleName .. ": " .. tostring(errorMsg))
                initResults[moduleName] = "FAILED: " .. tostring(errorMsg)
            end
        else
            warn("✗ Module " .. moduleName .. " has no init function or is invalid")
            initResults[moduleName] = "NO_INIT_FUNCTION"
        end
    end
    
    -- Report initialization results
    local successCount = 0
    local failCount = 0
    
    for moduleName, result in pairs(initResults) do
        if result == "SUCCESS" then
            successCount = successCount + 1
        else
            failCount = failCount + 1
        end
    end
    
    print(string.format("Module initialization complete: %d success, %d failed", successCount, failCount))
    
    if successCount == 0 then
        warn("WARNING: No modules initialized successfully!")
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

-- Create button with error handling
local function createButton(name, callback, categoryName)
    local success, result = pcall(function()
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
                local callbackSuccess, errorMsg = pcall(callback)
                if not callbackSuccess then
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
    end)
    
    if not success then
        warn("Failed to create button " .. name .. ": " .. tostring(result))
        return nil
    end
    
    return result
end

-- Create toggle button with exclusive feature support and error handling
local function createToggleButton(name, callback, categoryName, disableCallback)
    local success, result = pcall(function()
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
                local callbackSuccess, errorMsg = pcall(callback, newState)
                if not callbackSuccess then
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
    end)
    
    if not success then
        warn("Failed to create toggle button " .. name .. ": " .. tostring(result))
        return nil
    end
    
    return result
end

-- LOAD BUTTONS FUNCTION
local function loadButtons()
    print("Loading buttons for category: " .. selectedCategory)
    
    -- Clear existing buttons first - with error handling
    pcall(function()
        for _, child in pairs(FeatureContainer:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then
                child:Destroy()
            end
        end
    end)
    
    -- Update category button backgrounds - with error handling
    pcall(function()
        for categoryName, categoryData in pairs(categoryFrames) do
            if categoryData and categoryData.button then
                categoryData.button.BackgroundColor3 = categoryName == selectedCategory and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25)
            end
        end
    end)

    if not selectedCategory then
        warn("No category selected!")
        return
    end
    
    -- Check if module exists and is loaded
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

    -- INDIVIDUAL ERROR HANDLING FOR EACH MODULE TYPE INCLUDING CREDIT
    if selectedCategory == "Credit" and module.createCreditDisplay then
        success, errorMessage = pcall(function()
            print("Calling Credit.createCreditDisplay")
            module.createCreditDisplay(FeatureContainer)
        end)
        
    elseif selectedCategory == "Visual" and module.loadVisualButtons then
        success, errorMessage = pcall(function()
            print("Calling Visual.loadVisualButtons")
            
            -- Extra validation for Visual module
            if not module.isInitialized or not module.isInitialized() then
                error("Visual module is not properly initialized")
            end
            
            module.loadVisualButtons(function(name, callback, disableCallback)
                return createToggleButton(name, callback, "Visual", disableCallback)
            end)
        end)
        
    elseif selectedCategory == "Movement" and module.loadMovementButtons then
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
        -- Fallback for modules without proper functions
        local fallbackLabel = Instance.new("TextLabel")
        fallbackLabel.Parent = FeatureContainer
        fallbackLabel.BackgroundTransparency = 1
        fallbackLabel.Size = UDim2.new(1, -2, 0, 40)
        fallbackLabel.Font = Enum.Font.Gotham
        fallbackLabel.Text = selectedCategory .. " module loaded but missing required function.\nModule functions available: " .. table.concat(getModuleFunctions(module), ", ")
        fallbackLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        fallbackLabel.TextSize = 8
        fallbackLabel.TextXAlignment = Enum.TextXAlignment.Left
        fallbackLabel.TextYAlignment = Enum.TextYAlignment.Top
        fallbackLabel.TextWrapped = true
        return
    end

    -- Show result with better messaging
    if not success and errorMessage then
        local errorLabel = Instance.new("TextLabel")
        errorLabel.Parent = FeatureContainer
        errorLabel.BackgroundTransparency = 1
        errorLabel.Size = UDim2.new(1, -2, 0, 60)
        errorLabel.Font = Enum.Font.Gotham
        errorLabel.Text = "Error loading " .. selectedCategory .. ":\n" .. tostring(errorMessage) .. "\n\nTry switching to another category and back."
        errorLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        errorLabel.TextSize = 8
        errorLabel.TextXAlignment = Enum.TextXAlignment.Left
        errorLabel.TextYAlignment = Enum.TextYAlignment.Top
        errorLabel.TextWrapped = true
        print("Error loading " .. selectedCategory .. ": " .. tostring(errorMessage))
    elseif success then
        print("✓ Successfully loaded buttons for " .. selectedCategory)
    end
end

-- Helper function to get available functions in a module
local function getModuleFunctions(module)
    local functions = {}
    if type(module) == "table" then
        for key, value in pairs(module) do
            if type(value) == "function" then
                table.insert(functions, key)
            end
        end
    end
    return functions
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
    if isMinimized then
        if previousMouseBehavior then
            UserInputService.MouseBehavior = previousMouseBehavior
        end
    else
        previousMouseBehavior = UserInputService.MouseBehavior
        if previousMouseBehavior == Enum.MouseBehavior.LockCenter or previousMouseBehavior == Enum.MouseBehavior.LockCurrent then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end
end

-- Enhanced reset states with better error handling
local function resetStates()
    print("Resetting all states")
    
    -- Disconnect all connections safely
    for key, connection in pairs(connections) do
        pcall(function()
            if connection and connection.Disconnect then
                connection:Disconnect()
            end
        end)
        connections[key] = nil
    end
    
    -- Reset module states safely
    for moduleName, module in pairs(modules) do
        if module and type(module.resetStates) == "function" then
            local success, error = pcall(function() 
                module.resetStates() 
            end)
            if not success then
                warn("Failed to reset states for " .. moduleName .. ": " .. tostring(error))
            else
                print("✓ Reset states for " .. moduleName)
            end
        end
    end
    
    -- Reload current category buttons
    if selectedCategory then
        task.spawn(function()
            task.wait(0.5) -- Give modules time to reset
            loadButtons()
        end)
    end
end

-- Enhanced character setup with better error handling and module updates
local function onCharacterAdded(newCharacter)
    if not newCharacter then return end
    
    local success, result = pcall(function()
        character = newCharacter
        humanoid = character:WaitForChild("Humanoid", 30)
        rootPart = character:WaitForChild("HumanoidRootPart", 30)
        
        if not humanoid or not rootPart then
            error("Failed to find Humanoid or HumanoidRootPart")
        end
        
        -- Update dependencies for all modules
        dependencies.character = character
        dependencies.humanoid = humanoid
        dependencies.rootPart = rootPart
        dependencies.ScrollFrame = FeatureContainer
        
        print("Character setup complete, updating module references...")
        
        -- Update references for modules that support it
        for moduleName, module in pairs(modules) do
            if module and type(module.updateReferences) == "function" then
                local updateSuccess, updateError = pcall(function()
                    module.updateReferences()
                end)
                if not updateSuccess then
                    warn("Failed to update references for " .. moduleName .. ": " .. tostring(updateError))
                else
                    print("✓ Updated references for " .. moduleName)
                end
            end
        end
        
        -- Re-initialize modules that need character data
        initializeModules()
        
        -- Set up death connection with error handling
        if humanoid and humanoid.Died then
            connections.humanoidDied = humanoid.Died:Connect(function()
                pcall(resetStates)
            end)
        end
        
        -- Reload current buttons if needed
        if selectedCategory and modules[selectedCategory] then
            task.spawn(function()
                task.wait(1) -- Give modules time to fully update
                loadButtons()
            end)
        end
    end)
    
    if not success then
        warn("Failed to set up character: " .. tostring(result))
        -- Don't completely fail - try to continue with basic setup
        character = newCharacter
        dependencies.character = character
        dependencies.ScrollFrame = FeatureContainer
    else
        print("✓ Character setup successful")
    end
end

-- Initialize character with error handling
if player.Character then
    onCharacterAdded(player.Character)
end
connections.characterAdded = player.CharacterAdded:Connect(onCharacterAdded)

-- Event connections with error handling
MinimizeButton.MouseButton1Click:Connect(function()
    pcall(toggleMinimize)
end)

LogoButton.MouseButton1Click:Connect(function()
    pcall(toggleMinimize)
end)

connections.toggleGui = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Home then
        pcall(toggleMinimize)
    end
end)

-- Enhanced startup sequence with better error handling and reporting
task.spawn(function()
    local timeout = 45 -- Increased timeout for better reliability
    local startTime = tick()
    
    print("=== MinimalHackGUI Initialization Started ===")
    print("Settings updated: Removed WalkSpeed, Added GuiOpacity")
    
    -- Wait for at least one critical module to load
    while tick() - startTime < timeout do
        local loadedCount = 0
        local criticalModulesLoaded = 0
        local criticalModules = {"Movement", "Visual", "Player"} -- Essential modules
        
        for moduleName, _ in pairs(moduleURLs) do
            if modulesLoaded[moduleName] then
                loadedCount = loadedCount + 1
                for _, critical in ipairs(criticalModules) do
                    if moduleName == critical then
                        criticalModulesLoaded = criticalModulesLoaded + 1
                        break
                    end
                end
            end
        end
        
        print(string.format("Loading progress: %d/%d total, %d/%d critical", 
              loadedCount, #categories, criticalModulesLoaded, #criticalModules))
        
        if criticalModulesLoaded >= 2 or loadedCount >= 4 then
            print("Sufficient modules loaded, proceeding with initialization...")
            break
        end
        
        task.wait(1)
    end

    -- Report final loading results
    local loadedModules = {}
    local failedModules = {}
    
    for moduleName, _ in pairs(moduleURLs) do
        if modulesLoaded[moduleName] then
            table.insert(loadedModules, moduleName)
        else
            table.insert(failedModules, moduleName)
        end
    end
    
    print("=== Module Loading Results ===")
    if #loadedModules > 0 then
        print("✓ Successfully loaded: " .. table.concat(loadedModules, ", "))
    end
    
    if #failedModules > 0 then
        print("✗ Failed to load: " .. table.concat(failedModules, ", "))
        print("Note: Failed modules will be retried when accessed")
    end

    -- Initialize loaded modules
    if #loadedModules > 0 then
        print("=== Starting Module Initialization ===")
        initializeModules()
    else
        warn("WARNING: No modules loaded successfully! GUI will have limited functionality.")
    end
    
    -- Load initial category buttons
    print("=== Loading Initial Interface ===")
    task.wait(0.5) -- Give modules time to fully initialize
    
    local buttonLoadSuccess, buttonLoadError = pcall(loadButtons)
    if not buttonLoadSuccess then
        warn("Failed to load initial buttons: " .. tostring(buttonLoadError))
        -- Create fallback message
        local fallbackLabel = Instance.new("TextLabel")
        fallbackLabel.Parent = FeatureContainer
        fallbackLabel.BackgroundTransparency = 1
        fallbackLabel.Size = UDim2.new(1, -2, 0, 60)
        fallbackLabel.Font = Enum.Font.Gotham
        fallbackLabel.Text = "GUI Initialized but some modules failed to load.\nTry switching between categories or restarting the script.\n\nLoaded: " .. (#loadedModules > 0 and table.concat(loadedModules, ", ") or "None")
        fallbackLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        fallbackLabel.TextSize = 8
        fallbackLabel.TextXAlignment = Enum.TextXAlignment.Left
        fallbackLabel.TextYAlignment = Enum.TextYAlignment.Top
        fallbackLabel.TextWrapped = true
    else
        print("✓ Initial interface loaded successfully")
    end
    
    -- ===== SHOW SLIDE NOTIFICATION AFTER SUCCESSFUL INITIALIZATION =====
    task.wait(1) -- Wait a bit more to ensure everything is stable
    pcall(function()
        createSlideNotification()
        print("✓ Slide notification triggered!")
    end)
    -- ===== END NOTIFICATION TRIGGER =====
    
    print("=== MinimalHackGUI Initialization Complete ===")
    print("Press HOME key to toggle GUI visibility")
    print("New Settings: GUI Width, GUI Height, GUI Opacity controls added")
    print("Removed: WalkSpeed setting (now handled in Movement module)")
    print("Loaded modules will continue loading in background")
    
    -- Continue trying to load failed modules in background
    if #failedModules > 0 then
        task.spawn(function()
            task.wait(5) -- Wait before retry
            print("=== Retrying Failed Modules ===")
            for _, failedModule in ipairs(failedModules) do
                if not modulesLoaded[failedModule] then
                    print("Retrying: " .. failedModule)
                    task.spawn(function()
                        loadModule(failedModule)
                    end)
                end
                task.wait(2) -- Stagger retries
            end
        end)
    end
end)

-- Add cleanup on script termination
game:GetService("RunService").Heartbeat:Connect(function()
    if ScreenGui.Parent ~= player.PlayerGui then
        ScreenGui.Parent = player.PlayerGui
    end
end)

-- Final safety check
task.spawn(function()
    task.wait(10)
    if not ScreenGui or not ScreenGui.Parent then
        warn("GUI lost parent, attempting recovery...")
        if ScreenGui then
            ScreenGui.Parent = player.PlayerGui
        end
    end
    
    local workingModules = 0
    for _, module in pairs(modules) do
        if module and type(module) == "table" then
            workingModules = workingModules + 1
        end
    end
    
    print(string.format("Health check: %d working modules, GUI %s", 
          workingModules, (ScreenGui and ScreenGui.Parent) and "OK" or "ERROR"))
    
    -- Display current settings info
    print("Current Settings Configuration:")
    for settingName, setting in pairs(settings) do
        print(string.format("  %s: %s (range: %s-%s)", 
              settingName, setting.value, setting.min, setting.max))
    end
end)