-- mainloader.lua
-- Main entry point for MinimalHackGUI by Fari Noveri, integrating all modules

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local RenderSettings = game:GetService("StarterGui")

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

-- Load modules
local modules = {}
local function loadModule(moduleName)
    local success, result = pcall(function()
        local response = game:HttpGet(moduleURLs[moduleName])
        return loadstring(response)()
    end)
    if success then
        modules[moduleName] = result
        print("Loaded module: " .. moduleName)
    else
        warn("Failed to load module " .. moduleName .. ": " .. tostring(result))
    end
end

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

-- Initialize modules
for moduleName, module in pairs(modules) do
    if module and module.init then
        module.init(dependencies)
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
        callback(buttonStates[name])
    end)
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(80, 80, 80)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    end)
end

-- Load buttons for each module
local function loadButtons()
    if modules.Movement and modules.Movement.loadMovementButtons then
        modules.Movement.loadMovementButtons(createToggleButton)
    end
    if modules.Player and modules.Player.loadPlayerButtons then
        local selectedPlayer = modules.Player.getSelectedPlayer()
        modules.Player.loadPlayerButtons(createButton, createToggleButton, selectedPlayer)
    end
    if modules.Teleport and modules.Teleport.loadTeleportButtons then
        local selectedPlayer = modules.Player and modules.Player.getSelectedPlayer() or nil
        local freecamEnabled, freecamPosition = modules.Visual and modules.Visual.getFreecamState() or false, nil
        local toggleFreecam = modules.Visual and modules.Visual.toggleFreecam or function() end
        modules.Teleport.loadTeleportButtons(createButton, selectedPlayer, freecamEnabled, freecamPosition, toggleFreecam)
    end
    if modules.Visual and modules.Visual.loadVisualButtons then
        modules.Visual.loadVisualButtons(createToggleButton)
    end
    if modules.Utility and modules.Utility.loadUtilityButtons then
        modules.Utility.loadUtilityButtons(createButton)
    end
    if modules.Settings and modules.Settings.loadSettingsButtons then
        modules.Settings.loadSettingsButtons(createButton)
    end
    if modules.Info and modules.Info.loadInfoButtons then
        modules.Info.loadInfoButtons(createButton)
    end
    if modules.AntiAdminInfo and modules.AntiAdminInfo.loadInfoButtons then
        modules.AntiAdminInfo.loadInfoButtons(createButton)
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
        connection:Disconnect()
    end
    connections = {}
    buttonStates = {}
    
    for _, module in pairs(modules) do
        if module and module.resetStates then
            module.resetStates()
        end
    end
    
    for _, child in pairs(ScrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    loadButtons()
    updateCanvasSize()
end

-- Character setup
local function onCharacterAdded(character)
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    dependencies.humanoid = humanoid
    dependencies.rootPart = rootPart
    
    resetStates()
    
    connections.humanoidDied = humanoid.Died:Connect(function()
        resetStates()
    end)
end

-- Initialize
if player.Character then
    onCharacterAdded(player.Character)
end
connections.characterAdded = player.CharacterAdded:Connect(onCharacterAdded)

-- Load buttons
loadButtons()
updateCanvasSize()

-- Close Button
CloseButton.MouseButton1Click:Connect(function()
    Frame.Visible = false
end)

-- Toggle GUI with Home key
connections.toggleGui = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Home then
        Frame.Visible = not Frame.Visible
    end
end)