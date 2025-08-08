-- mainloader.lua
-- Main entry point for MinimalHackGUI by Fari Noveri, integrating all modules

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RenderSettings = game:GetService("Settings") -- Fixed: Changed from StarterGui to Settings

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

-- Main Frame
local Frame = Instance.new("Frame")
Frame.Name = "MainFrame"
Frame.Parent = ScreenGui
Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Frame.BorderColor3 = Color3.fromRGB(45, 45, 45)
Frame.BorderSizePixel = 1
Frame.Position = UDim2.new(0.5, -150, 0.5, -200)
Frame.Size = UDim2.new(0, 300, 0, 400)
Frame.Active = true
Frame.Draggable = true

-- Title
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Parent = Frame
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.BorderSizePixel = 0
Title.Position = UDim2.new(0, 0, 0, 0)
Title.Size = UDim2.new(1, 0, 0, 35)
Title.Font = Enum.Font.Gotham
Title.Text = "MinimalHackGUI by Fari Noveri"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 12

-- Close Button
local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Parent = Frame
CloseButton.BackgroundTransparency = 1
CloseButton.Position = UDim2.new(1, -30, 0, 5)
CloseButton.Size = UDim2.new(0, 25, 0, 25)
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 12

-- ScrollFrame
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Name = "ScrollFrame"
ScrollFrame.Parent = Frame
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.Position = UDim2.new(0, 10, 0, 45)
ScrollFrame.Size = UDim2.new(1, -20, 1, -55)
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
ScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
ScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

-- Layout
local Layout = Instance.new("UIListLayout")
Layout.Parent = ScrollFrame
Layout.Padding = UDim.new(0, 2)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.FillDirection = Enum.FillDirection.Vertical

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

-- Load modules with better error handling
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

-- Load all modules
for moduleName, _ in pairs(moduleURLs) do
    loadModule(moduleName)
end

-- Dependencies for modules
local dependencies = {
    Players = Players,
    UserInputService = UserInputService,
    RunService = RunService,
    Workspace = Workspace,
    Lighting = Lighting,
    RenderSettings = RenderSettings,
    ScreenGui = ScreenGui,
    ScrollFrame = ScrollFrame,
    settings = settings,
    connections = connections,
    buttonStates = buttonStates,
    player = player,
    humanoid = humanoid,
    rootPart = rootPart
}

-- Initialize modules with error handling
for moduleName, module in pairs(modules) do
    if module and type(module.init) == "function" then
        local success, err = pcall(function()
            module.init(dependencies)
        end)
        if not success then
            warn("Failed to initialize module " .. moduleName .. ": " .. tostring(err))
        else
            print("Initialized module: " .. moduleName)
        end
    end
end

-- Helper function to create a button
local function createButton(name, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Parent = ScrollFrame
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -5, 0, 30)
    button.Font = Enum.Font.Gotham
    button.Text = name:upper()
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 10
    
    button.MouseButton1Click:Connect(callback)
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end)
end

-- Helper function to create a toggle button
local function createToggleButton(name, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Parent = ScrollFrame
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -5, 0, 30)
    button.Font = Enum.Font.Gotham
    button.Text = name:upper()
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 10
    
    buttonStates[name] = false
    
    button.MouseButton1Click:Connect(function()
        buttonStates[name] = not buttonStates[name]
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
        if type(callback) == "function" then
            callback(buttonStates[name])
        end
    end)
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(80, 80, 80)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    end)
end

-- Load buttons for each module with better error handling
local function loadButtons()
    -- Movement module
    if modules.Movement and type(modules.Movement.loadMovementButtons) == "function" then
        local success, err = pcall(function()
            modules.Movement.loadMovementButtons(createToggleButton)
        end)
        if not success then
            warn("Error loading Movement buttons: " .. tostring(err))
        end
    end
    
    -- Player module
    if modules.Player and type(modules.Player.loadPlayerButtons) == "function" then
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
    end
    
    -- Teleport module
    if modules.Teleport and type(modules.Teleport.loadTeleportButtons) == "function" then
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
    end
    
    -- Visual module
    if modules.Visual and type(modules.Visual.loadVisualButtons) == "function" then
        local success, err = pcall(function()
            modules.Visual.loadVisualButtons(createToggleButton)
        end)
        if not success then
            warn("Error loading Visual buttons: " .. tostring(err))
        end
    end
    
    -- Utility module
    if modules.Utility and type(modules.Utility.loadUtilityButtons) == "function" then
        local success, err = pcall(function()
            modules.Utility.loadUtilityButtons(createButton)
        end)
        if not success then
            warn("Error loading Utility buttons: " .. tostring(err))
        end
    end
    
    -- Settings module
    if modules.Settings and type(modules.Settings.loadSettingsButtons) == "function" then
        local success, err = pcall(function()
            modules.Settings.loadSettingsButtons(createButton)
        end)
        if not success then
            warn("Error loading Settings buttons: " .. tostring(err))
        end
    end
    
    -- Info module
    if modules.Info and type(modules.Info.loadInfoButtons) == "function" then
        local success, err = pcall(function()
            modules.Info.loadInfoButtons(createButton)
        end)
        if not success then
            warn("Error loading Info buttons: " .. tostring(err))
        end
    end
    
    -- AntiAdminInfo module
    if modules.AntiAdminInfo and type(modules.AntiAdminInfo.loadInfoButtons) == "function" then
        local success, err = pcall(function()
            modules.AntiAdminInfo.loadInfoButtons(createButton)
        end)
        if not success then
            warn("Error loading AntiAdminInfo buttons: " .. tostring(err))
        end
    end
end

-- Update CanvasSize
local function updateCanvasSize()
    wait(0.1)
    local contentSize = Layout.AbsoluteContentSize
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 10)
end

-- Reset states on character death
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
    
    -- Reset module states
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
    
    -- Clear existing buttons
    for _, child in pairs(ScrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- Reload buttons
    loadButtons()
    updateCanvasSize()
end

-- Character setup (alternative approach)
local function onCharacterAdded(character)
    if not character then return end
    
    local success, err = pcall(function()
        -- Try immediate access first
        humanoid = character:FindFirstChild("Humanoid")
        rootPart = character:FindFirstChild("HumanoidRootPart")
        
        -- If not found immediately, wait for them
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
        
        -- Connect to humanoid death with additional safety check
        if humanoid and typeof(humanoid) == "Instance" and humanoid.Died then
            connections.humanoidDied = humanoid.Died:Connect(function()
                resetStates()
            end)
        else
            warn("Humanoid or Died event not available")
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

-- Load buttons initially
loadButtons()
updateCanvasSize()

-- Close Button
CloseButton.MouseButton1Click:Connect(function()
    Frame.Visible = false
end)

-- Toggle GUI with Home key (fixed typo)
connections.toggleGui = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Home then
        Frame.Visible = not Frame.Visible  -- Fixed: was Frame.visible (lowercase)
    end
end)