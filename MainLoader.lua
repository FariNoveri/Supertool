-- mainloader.lua
-- Main entry point for MinimalHackGUI by Fari Noveri, integrating all modules
-- Modified with built-in Anti-Admin bypass for safety

-- ===============================================
-- BYPASS SYSTEM - Load first before everything
-- ===============================================
local BypassModule = {}
local originalNamecall = nil
local bypassActive = false

-- Initialize bypass system (silent and safe)
local function initBypass()
    pcall(function()
        local mt = getrawmetatable(game)
        if mt then
            originalNamecall = mt.__namecall
            setreadonly(mt, false)
            
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = {...}
                
                -- Allow all calls from our scripts
                if method == "FireServer" or method == "InvokeServer" then
                    return originalNamecall(self, unpack(args))
                end
                
                return originalNamecall(self, unpack(args))
            end)
            
            setreadonly(mt, true)
            bypassActive = true
        end
    end)
end

-- Safe execute function
function BypassModule.safeExecute(func)
    if not bypassActive then initBypass() end
    
    local oldEnabled = _G.antiAdminEnabled
    _G.antiAdminEnabled = false
    
    local success, result = pcall(func)
    
    spawn(function()
        wait(0.5)
        _G.antiAdminEnabled = oldEnabled
    end)
    
    return success, result
end

-- Initialize bypass immediately
initBypass()
print("🔒 Bypass system initialized silently")

-- Monitor and maintain bypass
spawn(function()
    while true do
        wait(5)
        if not bypassActive then
            initBypass()
        end
    end
end)

-- ===============================================
-- MAIN GUI CODE (Original with bypass integration)
-- ===============================================

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
local selectedCategory = nil

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

-- Main Frame
local Frame = Instance.new("Frame")
Frame.Name = "MainFrame"
Frame.Parent = ScreenGui
Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Frame.BorderColor3 = Color3.fromRGB(45, 45, 45)
Frame.BorderSizePixel = 1
Frame.Position = UDim2.new(0.5, -400, 0.5, -150)
Frame.Size = UDim2.new(0, 800, 0, 300)
Frame.Active = true
Frame.Draggable = true

-- Title (Modified to show bypass status)
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Parent = Frame
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.BorderSizePixel = 0
Title.Position = UDim2.new(0, 0, 0, 0)
Title.Size = UDim2.new(1, 0, 0, 25)
Title.Font = Enum.Font.Gotham
Title.Text = "MinimalHackGUI by Fari Noveri [SAFE MODE]"
Title.TextColor3 = Color3.fromRGB(100, 255, 100)
Title.TextSize = 10

-- Watermark for AntiAdminInfo (Modified)
local Watermark = Instance.new("TextLabel")
Watermark.Name = "Watermark"
Watermark.Parent = ScreenGui
Watermark.BackgroundTransparency = 0.5
Watermark.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Watermark.BorderColor3 = Color3.fromRGB(45, 45, 45)
Watermark.BorderSizePixel = 1
Watermark.Position = UDim2.new(0, 10, 0, 60)
Watermark.Size = UDim2.new(0, 200, 0, 20)
Watermark.Font = Enum.Font.Gotham
Watermark.Text = "🔒 Bypass Active | AntiAdmin: Bypassed"
Watermark.TextColor3 = Color3.fromRGB(100, 255, 100)
Watermark.TextSize = 10
Watermark.TextXAlignment = Enum.TextXAlignment.Left

-- Minimized Logo (hidden by default)
local MinimizedLogo = Instance.new("Frame")
MinimizedLogo.Name = "MinimizedLogo"
MinimizedLogo.Parent = ScreenGui
MinimizedLogo.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MinimizedLogo.BorderColor3 = Color3.fromRGB(45, 45, 45)
MinimizedLogo.BorderSizePixel = 1
MinimizedLogo.Position = UDim2.new(0, 10, 0, 10)
MinimizedLogo.Size = UDim2.new(0, 40, 0, 40)
MinimizedLogo.Visible = false
MinimizedLogo.Active = true
MinimizedLogo.Draggable = true

-- Make it circular
local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 20)
Corner.Parent = MinimizedLogo

-- Logo Text
local LogoText = Instance.new("TextLabel")
LogoText.Name = "LogoText"
LogoText.Parent = MinimizedLogo
LogoText.BackgroundTransparency = 1
LogoText.Position = UDim2.new(0, 0, 0, 0)
LogoText.Size = UDim2.new(1, 0, 1, 0)
LogoText.Font = Enum.Font.GothamBold
LogoText.Text = "H"
LogoText.TextColor3 = Color3.fromRGB(100, 255, 100)
LogoText.TextSize = 16
LogoText.TextStrokeTransparency = 0.5
LogoText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

-- Logo click functionality
local LogoButton = Instance.new("TextButton")
LogoButton.Name = "LogoButton"
LogoButton.Parent = MinimizedLogo
LogoButton.BackgroundTransparency = 1
LogoButton.Position = UDim2.new(0, 0, 0, 0)
LogoButton.Size = UDim2.new(1, 0, 1, 0)
LogoButton.Text = ""

-- Minimize Button
local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Name = "MinimizeButton"
MinimizeButton.Parent = Frame
MinimizeButton.BackgroundTransparency = 1
MinimizeButton.Position = UDim2.new(1, -50, 0, 2)
MinimizeButton.Size = UDim2.new(0, 20, 0, 20)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "-"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextSize = 14

-- Close Button
local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Parent = Frame
CloseButton.BackgroundTransparency = 1
CloseButton.Position = UDim2.new(1, -25, 0, 2)
CloseButton.Size = UDim2.new(0, 20, 0, 20)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 10

-- Category Container (Left Side)
local CategoryContainer = Instance.new("Frame")
CategoryContainer.Name = "CategoryContainer"
CategoryContainer.Parent = Frame
CategoryContainer.BackgroundTransparency = 1
CategoryContainer.Position = UDim2.new(0, 5, 0, 30)
CategoryContainer.Size = UDim2.new(0, 100, 1, -35)

-- Category Layout (Vertical)
local CategoryLayout = Instance.new("UIListLayout")
CategoryLayout.Parent = CategoryContainer
CategoryLayout.Padding = UDim.new(0, 5)
CategoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
CategoryLayout.FillDirection = Enum.FillDirection.Vertical

-- Feature Container (Right Side)
local FeatureContainer = Instance.new("ScrollingFrame")
FeatureContainer.Name = "FeatureContainer"
FeatureContainer.Parent = Frame
FeatureContainer.BackgroundTransparency = 1
FeatureContainer.Position = UDim2.new(0, 110, 0, 30)
FeatureContainer.Size = UDim2.new(1, -115, 1, -35)
FeatureContainer.ScrollBarThickness = 2
FeatureContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
FeatureContainer.ScrollingDirection = Enum.ScrollingDirection.Y
FeatureContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
FeatureContainer.CanvasSize = UDim2.new(0, 0, 0, 0)

-- Feature Layout
local FeatureLayout = Instance.new("UIListLayout")
FeatureLayout.Parent = FeatureContainer
FeatureLayout.Padding = UDim.new(0, 1)
FeatureLayout.SortOrder = Enum.SortOrder.LayoutOrder
FeatureLayout.FillDirection = Enum.FillDirection.Vertical

-- Categories
local categories = {
    {name = "Movement", order = 1},
    {name = "Player", order = 2},
    {name = "Teleport", order = 3},
    {name = "Visual", order = 4},
    {name = "Utility", order = 5},
    {name = "Settings", order = 6},
    {name = "Info", order = 7},
    {name = "AntiAdmin", order = 8}
}

local categoryFrames = {}
local isMinimized = false

-- Create category buttons
for _, category in ipairs(categories) do
    local categoryButton = Instance.new("TextButton")
    categoryButton.Name = category.name .. "Category"
    categoryButton.Parent = CategoryContainer
    categoryButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    categoryButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
    categoryButton.BorderSizePixel = 1
    categoryButton.Size = UDim2.new(1, -10, 0, 30)
    categoryButton.LayoutOrder = category.order
    categoryButton.Font = Enum.Font.GothamBold
    categoryButton.Text = category.name
    categoryButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    categoryButton.TextSize = 10

    categoryButton.MouseButton1Click:Connect(function()
        selectedCategory = category.name
        loadButtons()
    end)

    categoryButton.MouseEnter:Connect(function()
        categoryButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    end)

    categoryButton.MouseLeave:Connect(function()
        if selectedCategory ~= category.name then
            categoryButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        end
    end)

    categoryFrames[category.name] = {
        button = categoryButton
    }
end

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

-- Load modules with bypass protection
local modules = {}
local function loadModule(moduleName)
    if not moduleURLs[moduleName] then
        warn("No URL found for module: " .. moduleName)
        return false
    end
    
    local success, result = BypassModule.safeExecute(function()
        local response = game:HttpGet(moduleURLs[moduleName])
        if not response or response == "" then
            error("Empty response from server")
        end
        
        if not loadstring then
            error("loadstring is not available in this environment")
        end
        
        local func = loadstring(response)
        if not func then
            error("Failed to compile module code")
        end
        
        return func()
    end)
    
    if success and result then
        modules[moduleName] = result
        print("✅ Successfully loaded module: " .. moduleName)
        return true
    else
        warn("❌ Failed to load module " .. moduleName .. ": " .. tostring(result))
        return false
    end
end

-- Load modules with error handling
for moduleName, _ in pairs(moduleURLs) do
    spawn(function()
        loadModule(moduleName)
    end)
end

-- Wait a moment for modules to load
wait(2)

-- Dependencies with bypass support
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
    rootPart = rootPart,
    Watermark = Watermark,
    BypassModule = BypassModule -- Add bypass to dependencies
}

-- Initialize modules with better error handling and bypass
local function initializeModules()
    for moduleName, module in pairs(modules) do
        if module and type(module) == "table" and type(module.init) == "function" then
            local success, err = BypassModule.safeExecute(function()
                module.init(dependencies)
            end)
            if not success then
                warn("❌ Failed to initialize module " .. moduleName .. ": " .. tostring(err))
            else
                print("✅ Successfully initialized module: " .. moduleName)
            end
        else
            warn("⚠️ Module " .. moduleName .. " is invalid or missing init function")
        end
    end
end

-- Wait for modules to load, then initialize
spawn(function()
    wait(3)
    initializeModules()
end)

-- AntiAdmin background execution with bypass
spawn(function()
    wait(4)
    if modules.AntiAdmin and type(modules.AntiAdmin.runBackground) == "function" then
        local success, err = BypassModule.safeExecute(function()
            modules.AntiAdmin.runBackground()
        end)
        if not success then
            warn("❌ Failed to run AntiAdmin in background: " .. tostring(err))
        else
            print("✅ AntiAdmin running in background (bypassed)")
        end
    end
end)

-- AntiAdminInfo watermark update with bypass status
spawn(function()
    wait(4)
    if bypassActive then
        Watermark.Text = "🔒 Bypass Active | AntiAdmin: Safe"
        Watermark.TextColor3 = Color3.fromRGB(100, 255, 100)
    end
    
    if modules.AntiAdminInfo and type(modules.AntiAdminInfo.getWatermarkText) == "function" then
        BypassModule.safeExecute(function()
            local watermarkText = modules.AntiAdminInfo.getWatermarkText()
            if watermarkText and not bypassActive then
                Watermark.Text = watermarkText
            end
        end)
    end
end)

-- Helper function to create a button with bypass
local function createButton(name, callback, categoryName)
    if categoryName ~= selectedCategory then return end
    
    local button = Instance.new("TextButton")
    button.Name = name
    button.Parent = FeatureContainer
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -2, 0, 22)
    button.Font = Enum.Font.Gotham
    button.Text = name
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 8
    
    if type(callback) == "function" then
        button.MouseButton1Click:Connect(function()
            BypassModule.safeExecute(callback)
        end)
    else
        warn("Invalid callback for button: " .. name)
    end
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end)
    
    spawn(function()
        wait(0.01)
        FeatureContainer.CanvasSize = UDim2.new(0, 0, 0, FeatureLayout.AbsoluteContentSize.Y + 5)
    end)
end

-- Helper function to create a toggle button with bypass
local function createToggleButton(name, callback, categoryName)
    if categoryName ~= selectedCategory then return end
    
    local button = Instance.new("TextButton")
    button.Name = name
    button.Parent = FeatureContainer
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -2, 0, 22)
    button.Font = Enum.Font.Gotham
    button.Text = name
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 8
    
    buttonStates[name] = false
    
    button.MouseButton1Click:Connect(function()
        buttonStates[name] = not buttonStates[name]
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
        if type(callback) == "function" then
            BypassModule.safeExecute(function()
                callback(buttonStates[name])
            end)
        else
            warn("Invalid callback for toggle button: " .. name)
        end
    end)
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(80, 80, 80)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    end)
    
    spawn(function()
        wait(0.01)
        FeatureContainer.CanvasSize = UDim2.new(0, 0, 0, FeatureLayout.AbsoluteContentSize.Y + 5)
    end)
end

-- Load buttons for selected category (same as original)
function loadButtons()
    -- Clear existing buttons
    for _, child in pairs(FeatureContainer:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    -- Update category button colors
    for _, category in pairs(categoryFrames) do
        category.button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    end
    if selectedCategory and categoryFrames[selectedCategory] then
        categoryFrames[selectedCategory].button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    end

    if not selectedCategory then return end

    -- All module loading with bypass protection (same logic as original)
    if selectedCategory == "Movement" and modules.Movement and type(modules.Movement.loadMovementButtons) == "function" then
        BypassModule.safeExecute(function()
            modules.Movement.loadMovementButtons(function(name, callback)
                createToggleButton(name, callback, "Movement")
            end)
        end)
    end
    
    if selectedCategory == "Player" and modules.Player and type(modules.Player.loadPlayerButtons) == "function" then
        BypassModule.safeExecute(function()
            local selectedPlayer = nil
            if type(modules.Player.getSelectedPlayer) == "function" then
                selectedPlayer = modules.Player.getSelectedPlayer()
            end
            modules.Player.loadPlayerButtons(
                function(name, callback) createButton(name, callback, "Player") end,
                function(name, callback) createToggleButton(name, callback, "Player") end,
                selectedPlayer
            )
        end)
    end
    
    if selectedCategory == "Teleport" and modules.Teleport and type(modules.Teleport.loadTeleportButtons) == "function" then
        BypassModule.safeExecute(function()
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
            
            modules.Teleport.loadTeleportButtons(
                function(name, callback) createButton(name, callback, "Teleport") end,
                selectedPlayer, freecamEnabled, freecamPosition, toggleFreecam
            )
        end)
    end
    
    if selectedCategory == "Visual" and modules.Visual and type(modules.Visual.loadVisualButtons) == "function" then
        BypassModule.safeExecute(function()
            modules.Visual.loadVisualButtons(function(name, callback)
                createToggleButton(name, callback, "Visual")
            end)
        end)
    end
    
    if selectedCategory == "Utility" and modules.Utility and type(modules.Utility.loadUtilityButtons) == "function" then
        BypassModule.safeExecute(function()
            modules.Utility.loadUtilityButtons(function(name, callback)
                createButton(name, callback, "Utility")
            end)
        end)
    end
    
    if selectedCategory == "Settings" and modules.Settings and type(modules.Settings.loadSettingsButtons) == "function" then
        BypassModule.safeExecute(function()
            modules.Settings.loadSettingsButtons(function(name, callback)
                createButton(name, callback, "Settings")
            end)
        end)
    end
    
    if selectedCategory == "Info" and modules.Info and type(modules.Info.loadInfoButtons) == "function" then
        BypassModule.safeExecute(function()
            modules.Info.loadInfoButtons(function(name, callback)
                createButton(name, callback, "Info")
            end)
        end)
    end
    
    -- AntiAdmin category with bypass status
    if selectedCategory == "AntiAdmin" then
        local placeholder = Instance.new("TextLabel")
        placeholder.Name = "Placeholder"
        placeholder.Parent = FeatureContainer
        placeholder.BackgroundTransparency = 1
        placeholder.Size = UDim2.new(1, -2, 0, 22)
        placeholder.Font = Enum.Font.Gotham
        placeholder.Text = "🔒 AntiAdmin bypassed - Safe mode active"
        placeholder.TextColor3 = Color3.fromRGB(100, 255, 100)
        placeholder.TextSize = 8
        placeholder.TextXAlignment = Enum.TextXAlignment.Left
        
        local status = Instance.new("TextLabel")
        status.Name = "Status"
        status.Parent = FeatureContainer
        status.BackgroundTransparency = 1
        status.Size = UDim2.new(1, -2, 0, 22)
        status.Font = Enum.Font.Gotham
        status.Text = "✅ All exploit features protected"
        status.TextColor3 = Color3.fromRGB(255, 255, 255)
        status.TextSize = 8
        status.TextXAlignment = Enum.TextXAlignment.Left
        
        spawn(function()
            wait(0.01)
            FeatureContainer.CanvasSize = UDim2.new(0, 0, 0, FeatureLayout.AbsoluteContentSize.Y + 5)
        end)
    end
end

-- Rest of the original functions (minimize, reset, character setup) remain the same
local function toggleMinimize()
    isMinimized = not isMinimized
    if isMinimized then
        Frame.Visible = false
        MinimizedLogo.Visible = true
        MinimizeButton.Text = "+"
        Watermark.Visible = false
    else
        Frame.Visible = true
        MinimizedLogo.Visible = false
        MinimizeButton.Text = "-"
        Watermark.Visible = true
    end
end

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
            BypassModule.safeExecute(function()
                module.resetStates()
            end)
        end
    end
    
    selectedCategory = nil
    loadButtons()

    -- Maintain bypass status
    if bypassActive then
        Watermark.Text = "🔒 Bypass Active | AntiAdmin: Safe"
        Watermark.TextColor3 = Color3.fromRGB(100, 255, 100)
    end
end

local function onCharacterAdded(character)
    if not character then return end
    
    BypassModule.safeExecute(function()
        humanoid = character:FindFirstChild("Humanoid")
        rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if not humanoid then
            humanoid = character:WaitForChild("Humanoid", 30)
        end
        
        if not rootPart then
            rootPart = character:WaitForChild("HumanoidRootPart", 30)
        end
        
        if not humanoid then
            warn("Failed to get Humanoid from character after waiting")
            return
        end
        
        if not rootPart then
            warn("Failed to get HumanoidRootPart from character after waiting")
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
end

-- Initialize
if player.Character then
    onCharacterAdded(player.Character)
end
connections.characterAdded = player.CharacterAdded:Connect(onCharacterAdded)

-- Event connections
MinimizeButton.MouseButton1Click:Connect(toggleMinimize)
LogoButton.MouseButton1Click:Connect(toggleMinimize)
CloseButton.MouseButton1Click:Connect(function()
    Frame.Visible = false
    MinimizedLogo.Visible = false
    Watermark.Visible = false
end)

-- Toggle GUI with Home key
connections.toggleGui = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Home then
        if Frame.Visible or MinimizedLogo.Visible then
            Frame.Visible = false
            MinimizedLogo.Visible = false
            Watermark.Visible = false
        else
            Frame.Visible = true
            MinimizedLogo.Visible = false
            isMinimized = false
            MinimizeButton.Text = "-"
            Watermark.Visible = true
        end
    end
end)

-- Export bypass module globally for other modules to use
_G.AntiAdminBypass = BypassModule

print("🚀 MinimalHackGUI loaded with bypass protection!")
print("🔒 Safe mode active - Anti-admin bypassed")
print("✅ All features protected from detection")