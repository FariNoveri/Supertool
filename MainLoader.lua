-- Main entry point for MinimalHackGUI by Fari Noveri

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

-- Check for existing script instances (simplified)
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
Title.Text = "MinimalHackGUI by Fari Noveri eqweq"
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

-- Minimize/Close Buttons
local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Parent = Frame
MinimizeButton.BackgroundTransparency = 1
MinimizeButton.Position = UDim2.new(1, -40, 0, 5)
MinimizeButton.Size = UDim2.new(0, 20, 0, 20)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "-"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextSize = 10

local CloseButton = Instance.new("TextButton")
CloseButton.Parent = Frame
CloseButton.BackgroundTransparency = 1
CloseButton.Position = UDim2.new(1, -20, 0, 5)
CloseButton.Size = UDim2.new(0, 20, 0, 20)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 10

-- Category Container
local CategoryContainer = Instance.new("Frame")
CategoryContainer.Parent = Frame
CategoryContainer.BackgroundTransparency = 1
CategoryContainer.Position = UDim2.new(0, 5, 0, 30)
CategoryContainer.Size = UDim2.new(0, 80, 1, -35)

local CategoryLayout = Instance.new("UIListLayout")
CategoryLayout.Parent = CategoryContainer
CategoryLayout.Padding = UDim.new(0, 3)
CategoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
CategoryLayout.FillDirection = Enum.FillDirection.Vertical

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

-- Categories (removed AntiAdmin)
local categories = {
    {name = "Movement", order = 1},
    {name = "Player", order = 2},
    {name = "Teleport", order = 3},
    {name = "Visual", order = 4},
    {name = "Utility", order = 5},
    {name = "Settings", order = 6},
    {name = "Info", order = 7}
}

local categoryFrames = {}
local isMinimized = false

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
        -- loadButtons() will be defined later
        task.spawn(function()
            if loadButtons then
                loadButtons()
            end
        end)
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

-- Module URLs (removed AntiAdmin)
local moduleURLs = {
    Movement = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement.lua",
    Player = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Player.lua",
    Teleport = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Teleport.lua",
    Visual = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Visual.lua",
    Utility = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Utility.lua",
    Settings = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Settings.lua",
    Info = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Info.lua"
}

-- Load modules
local modules = {}
local modulesLoaded = {}

local function loadModule(moduleName)
    if not moduleURLs[moduleName] then
        warn("No URL defined for module: " .. moduleName)
        return false
    end
    
    local success, result = pcall(function()
        local response = game:HttpGet(moduleURLs[moduleName])
        if not response or response == "" then
            warn("Empty or invalid response for module: " .. moduleName)
            return nil
        end
        local func = loadstring(response)
        if not func then
            warn("Failed to compile module: " .. moduleName)
            return nil
        end
        local module = func()
        if not module then
            warn("Module " .. moduleName .. " returned nil")
            return nil
        end
        return module
    end)
    
    if success and result then
        modules[moduleName] = result
        modulesLoaded[moduleName] = true
        print("Loaded module: " .. moduleName)
        return true
    else
        warn("Failed to load module: " .. moduleName .. " Error: " .. tostring(result))
        return false
    end
end

-- Load all modules
for moduleName, _ in pairs(moduleURLs) do
    task.spawn(function() loadModule(moduleName) end)
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
                warn("Failed to initialize module " .. moduleName .. ": " .. tostring(result))
            else
                print("Initialized module: " .. moduleName)
            end
        end
    end
end

-- Create button
local function createButton(name, callback, categoryName)
    if categoryName ~= selectedCategory then return end
    
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
        button.MouseButton1Click:Connect(callback)
    end
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end)
    print("Created button: " .. name .. " for category: " .. categoryName)
end

-- Create toggle button
local function createToggleButton(name, callback, categoryName)
    if categoryName ~= selectedCategory then return end
    
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
    
    if categoryStates[categoryName][name] == nil then
        categoryStates[categoryName][name] = false
    end
    button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    
    button.MouseButton1Click:Connect(function()
        categoryStates[categoryName][name] = not categoryStates[categoryName][name]
        button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
        if type(callback) == "function" then
            callback(categoryStates[categoryName][name])
        end
    end)
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(80, 80, 80)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    end)
    print("Created toggle button: " .. name .. " for category: " .. categoryName)
end

-- Forward declaration of loadButtons function
local loadButtons

-- Load buttons implementation
loadButtons = function()
    for _, child in pairs(FeatureContainer:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    for categoryName, categoryData in pairs(categoryFrames) do
        categoryData.button.BackgroundColor3 = categoryName == selectedCategory and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25)
    end

    if not selectedCategory then return end
    
    local loadingLabel = Instance.new("TextLabel")
    loadingLabel.Parent = FeatureContainer
    loadingLabel.BackgroundTransparency = 1
    loadingLabel.Size = UDim2.new(1, -2, 0, 20)
    loadingLabel.Font = Enum.Font.Gotham
    loadingLabel.Text = "Loading..."
    loadingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    loadingLabel.TextSize = 8
    loadingLabel.TextXAlignment = Enum.TextXAlignment.Left

    task.spawn(function()
        task.wait(0.1)
        
        if selectedCategory == "Movement" and modules.Movement and type(modules.Movement.loadMovementButtons) == "function" then
            local success, result = pcall(function()
                print("Calling Movement.loadMovementButtons")
                modules.Movement.loadMovementButtons(
                    function(name, callback) createButton(name, callback, "Movement") end,
                    function(name, callback) createToggleButton(name, callback, "Movement") end
                )
            end)
            if not success then
                warn("Failed to load Movement buttons: " .. tostring(result))
                loadingLabel.Text = "Failed to load Movement buttons!"
                loadingLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
        elseif selectedCategory == "Player" and modules.Player and type(modules.Player.loadPlayerButtons) == "function" then
            local success, result = pcall(function()
                local selectedPlayer = modules.Player.getSelectedPlayer and modules.Player.getSelectedPlayer() or nil
                print("Calling Player.loadPlayerButtons with selectedPlayer: " .. tostring(selectedPlayer))
                modules.Player.loadPlayerButtons(
                    function(name, callback) createButton(name, callback, "Player") end,
                    function(name, callback) createToggleButton(name, callback, "Player") end,
                    selectedPlayer
                )
            end)
            if not success then
                warn("Failed to load Player buttons: " .. tostring(result))
                loadingLabel.Text = "Failed to load Player buttons!"
                loadingLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
        elseif selectedCategory == "Teleport" and modules.Teleport and type(modules.Teleport.loadTeleportButtons) == "function" then
            local success, result = pcall(function()
                local selectedPlayer = modules.Player and modules.Player.getSelectedPlayer and modules.Player.getSelectedPlayer() or nil
                local freecamEnabled = modules.Visual and modules.Visual.getFreecamState and modules.Visual.getFreecamState() or false
                local freecamPosition = modules.Visual and modules.Visual.getFreecamState and select(2, modules.Visual.getFreecamState()) or nil
                local toggleFreecam = modules.Visual and modules.Visual.toggleFreecam or function() end
                print("Calling Teleport.loadTeleportButtons with selectedPlayer: " .. tostring(selectedPlayer))
                modules.Teleport.loadTeleportButtons(
                    function(name, callback) createButton(name, callback, "Teleport") end,
                    selectedPlayer, freecamEnabled, freecamPosition, toggleFreecam
                )
            end)
            if not success then
                warn("Failed to load Teleport buttons: " .. tostring(result))
                loadingLabel.Text = "Failed to load Teleport buttons!"
                loadingLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
        elseif selectedCategory == "Visual" and modules.Visual and type(modules.Visual.loadVisualButtons) == "function" then
            local success, result = pcall(function()
                modules.Visual.loadVisualButtons(function(name, callback)
                    createToggleButton(name, callback, "Visual")
                end)
            end)
            if not success then
                warn("Failed to load Visual buttons: " .. tostring(result))
                loadingLabel.Text = "Failed to load Visual buttons!"
                loadingLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
        elseif selectedCategory == "Utility" and modules.Utility and type(modules.Utility.loadUtilityButtons) == "function" then
            local success, result = pcall(function()
                modules.Utility.loadUtilityButtons(function(name, callback)
                    createButton(name, callback, "Utility")
                end)
            end)
            if not success then
                warn("Failed to load Utility buttons: " .. tostring(result))
                loadingLabel.Text = "Failed to load Utility buttons!"
                loadingLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
        elseif selectedCategory == "Settings" and modules.Settings and type(modules.Settings.loadSettingsButtons) == "function" then
            local success, result = pcall(function()
                modules.Settings.loadSettingsButtons(function(name, callback)
                    createButton(name, callback, "Settings")
                end)
            end)
            if not success then
                warn("Failed to load Settings buttons: " .. tostring(result))
                loadingLabel.Text = "Failed to load Settings buttons!"
                loadingLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
        elseif selectedCategory == "Info" and modules.Info and type(modules.Info.loadInfoButtons) == "function" then
            local success, result = pcall(function()
                modules.Info.loadInfoButtons(function(name, callback)
                    createButton(name, callback, "Info")
                end)
            end)
            if not success then
                warn("Failed to load Info buttons: " .. tostring(result))
                loadingLabel.Text = "Failed to load Info buttons!"
                loadingLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            end
        end
        
        if loadingLabel and loadingLabel.Parent then
            loadingLabel:Destroy()
        end
        
        FeatureContainer.CanvasSize = UDim2.new(0, 0, 0, math.max(FeatureLayout.AbsoluteContentSize.Y + 5, 1))
    end)
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
        loadButtons()
    end
end

-- Character setup
local function onCharacterAdded(newCharacter)
    if not newCharacter then return end
    
    local success, result = pcall(function()
        character = newCharacter
        humanoid = character:WaitForChild("Humanoid", 30)
        rootPart = character:WaitForChild("HumanoidRootPart", 30)
        
        dependencies.character = character
        dependencies.humanoid = humanoid
        dependencies.rootPart = rootPart
        
        initializeModules()
        
        if humanoid and humanoid.Died then
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
CloseButton.MouseButton1Click:Connect(function()
    Frame.Visible = false
    MinimizedLogo.Visible = false
end)

connections.toggleGui = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Home then
        if Frame.Visible or MinimizedLogo.Visible then
            Frame.Visible = false
            MinimizedLogo.Visible = false
        else
            Frame.Visible = true
            MinimizedLogo.Visible = false
            isMinimized = false
            MinimizeButton.Text = "-"
        end
    end
end)

-- Start initialization
task.spawn(function()
    local timeout = 15
    local startTime = tick()
    
    -- Wait for critical modules to load
    while (not modules.Movement or not modules.Player or not modules.Teleport) and tick() - startTime < timeout do
        task.wait(0.1)
    end

    -- Check if modules loaded successfully
    for _, moduleName in ipairs({"Movement", "Player", "Teleport"}) do
        if not modules[moduleName] then
            warn("Failed to load " .. moduleName .. " module after timeout!")
        else
            print(moduleName .. " module loaded successfully")
        end
    end

    initializeModules()
    loadButtons()
end)