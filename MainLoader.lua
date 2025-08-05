-- Enhanced Roblox Mobile GUI Script with Categories
-- Compatible with all games, mobile-optimized with minimize feature and script management

-- Prevent multiple instances
if _G.MobileExecutorGUI then
    _G.MobileExecutorGUI:Destroy()
    print("Previous Mobile Executor GUI instance destroyed")
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- Variables
local GUI = {}
local Connections = {}
local CurrentCategory = "Movement"
local IsMinimized = false
local CategoryUpdateFunctions = {}

local States = {
    Flying = false,
    Noclip = false,
    SpeedHack = false,
    JumpPower = false,
    GodMode = false,
    Spectating = false,
    SpiderMan = false,
    FreeCam = false,
    AntiAFK = false,
    Fullbright = false
}

local Settings = {
    FlySpeed = 50,
    WalkSpeed = 50,
    JumpPower = 120,
    SpectateIndex = 1,
    SavedPosition = nil,
    FreeCamPosition = nil
}

-- Categories and their features
local Categories = {
    Movement = {
        {name = "Toggle Fly", func = "ToggleFly"},
        {name = "Toggle Noclip", func = "ToggleNoclip"},
        {name = "Toggle Speed", func = "ToggleSpeedHack"},
        {name = "Toggle Jump Power", func = "ToggleJumpPower"},
        {name = "Toggle SpiderMan", func = "ToggleSpiderMan"}
    },
    Spectate = {
        {name = "Toggle Spectate", func = "ToggleSpectate"},
        {name = "Next Spectate", func = "NextSpectate"},
        {name = "Prev Spectate", func = "PrevSpectate"},
        {name = "TP to Spectate", func = "TeleportToSpectate"}
    },
    Utility = {
        {name = "Toggle God Mode", func = "ToggleGodMode"},
        {name = "Toggle Fullbright", func = "ToggleFullbright"},
        {name = "Toggle Anti AFK", func = "ToggleAntiAFK"},
        {name = "Save Position", func = "SavePosition"},
        {name = "TP to Saved Pos", func = "TeleportToSavedPosition"}
    }
}

-- Feature Functions
local FeatureFunctions = {}

-- Movement Features
FeatureFunctions.ToggleFly = function()
    States.Flying = not States.Flying
    
    if States.Flying then
        local BodyVelocity = Instance.new("BodyVelocity")
        BodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        BodyVelocity.Velocity = Vector3.new(0, 0, 0)
        BodyVelocity.Parent = RootPart
        
        Connections.Fly = RunService.Heartbeat:Connect(function()
            if States.Flying and RootPart:FindFirstChild("BodyVelocity") then
                local MoveVector = Humanoid.MoveDirection
                local Camera = Workspace.CurrentCamera
                if Camera then
                    BodyVelocity.Velocity = (Camera.CFrame.LookVector * MoveVector.Z + Camera.CFrame.RightVector * MoveVector.X) * Settings.FlySpeed
                end
            end
        end)
        print("Fly: ON")
    else
        if Connections.Fly then
            Connections.Fly:Disconnect()
            Connections.Fly = nil
        end
        if RootPart:FindFirstChild("BodyVelocity") then
            RootPart.BodyVelocity:Destroy()
        end
        print("Fly: OFF")
    end
end

FeatureFunctions.ToggleNoclip = function()
    States.Noclip = not States.Noclip
    
    if States.Noclip then
        Connections.Noclip = RunService.Stepped:Connect(function()
            if Character then
                for _, part in pairs(Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
        print("Noclip: ON")
    else
        if Connections.Noclip then
            Connections.Noclip:Disconnect()
            Connections.Noclip = nil
        end
        if Character then
            for _, part in pairs(Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
        print("Noclip: OFF")
    end
end

FeatureFunctions.ToggleSpeedHack = function()
    States.SpeedHack = not States.SpeedHack
    
    if States.SpeedHack then
        Humanoid.WalkSpeed = Settings.WalkSpeed
        print("Speed Hack: ON (" .. Settings.WalkSpeed .. ")")
    else
        Humanoid.WalkSpeed = 16
        print("Speed Hack: OFF")
    end
end

FeatureFunctions.ToggleJumpPower = function()
    States.JumpPower = not States.JumpPower
    
    if States.JumpPower then
        if Humanoid:FindFirstChild("JumpHeight") then
            Humanoid.JumpHeight = Settings.JumpPower
        else
            Humanoid.JumpPower = Settings.JumpPower
        end
        print("Jump Power: ON (" .. Settings.JumpPower .. ")")
    else
        if Humanoid:FindFirstChild("JumpHeight") then
            Humanoid.JumpHeight = 7.2
        else
            Humanoid.JumpPower = 50
        end
        print("Jump Power: OFF")
    end
end

FeatureFunctions.ToggleSpiderMan = function()
    States.SpiderMan = not States.SpiderMan
    
    if States.SpiderMan then
        Connections.SpiderMan = RunService.Heartbeat:Connect(function()
            if RootPart then
                local ray = Workspace:Raycast(RootPart.Position, RootPart.CFrame.LookVector * 3)
                if ray and ray.Instance then
                    local BodyVelocity = RootPart:FindFirstChild("SpiderVelocity") or Instance.new("BodyVelocity")
                    BodyVelocity.Name = "SpiderVelocity"
                    BodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
                    BodyVelocity.Velocity = RootPart.CFrame.LookVector * 20
                    BodyVelocity.Parent = RootPart
                else
                    if RootPart:FindFirstChild("SpiderVelocity") then
                        RootPart.SpiderVelocity:Destroy()
                    end
                end
            end
        end)
        print("SpiderMan: ON")
    else
        if Connections.SpiderMan then
            Connections.SpiderMan:Disconnect()
            Connections.SpiderMan = nil
        end
        if RootPart:FindFirstChild("SpiderVelocity") then
            RootPart.SpiderVelocity:Destroy()
        end
        print("SpiderMan: OFF")
    end
end

-- Spectate Features
local function GetAlivePlayers()
    local alivePlayers = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= Player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(alivePlayers, player)
        end
    end
    return alivePlayers
end

FeatureFunctions.ToggleSpectate = function()
    States.Spectating = not States.Spectating
    local alivePlayers = GetAlivePlayers()
    
    if States.Spectating and #alivePlayers > 0 then
        Settings.SpectateIndex = math.min(Settings.SpectateIndex, #alivePlayers)
        local targetPlayer = alivePlayers[Settings.SpectateIndex]
        Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
        print("Spectating: " .. targetPlayer.Name)
    else
        Workspace.CurrentCamera.CameraSubject = Humanoid
        print("Spectate: OFF")
    end
end

FeatureFunctions.NextSpectate = function()
    if not States.Spectating then return end
    local alivePlayers = GetAlivePlayers()
    if #alivePlayers > 0 then
        Settings.SpectateIndex = Settings.SpectateIndex % #alivePlayers + 1
        local targetPlayer = alivePlayers[Settings.SpectateIndex]
        Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
        print("Spectating: " .. targetPlayer.Name)
    end
end

FeatureFunctions.PrevSpectate = function()
    if not States.Spectating then return end
    local alivePlayers = GetAlivePlayers()
    if #alivePlayers > 0 then
        Settings.SpectateIndex = Settings.SpectateIndex - 1
        if Settings.SpectateIndex < 1 then
            Settings.SpectateIndex = #alivePlayers
        end
        local targetPlayer = alivePlayers[Settings.SpectateIndex]
        Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
        print("Spectating: " .. targetPlayer.Name)
    end
end

FeatureFunctions.TeleportToSpectate = function()
    if not States.Spectating then return end
    local alivePlayers = GetAlivePlayers()
    if #alivePlayers > 0 then
        local targetPlayer = alivePlayers[Settings.SpectateIndex]
        if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            RootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame
            print("Teleported to: " .. targetPlayer.Name)
        end
    end
end

-- Utility Features
FeatureFunctions.ToggleGodMode = function()
    States.GodMode = not States.GodMode
    
    if States.GodMode then
        Humanoid.MaxHealth = math.huge
        Humanoid.Health = math.huge
        print("God Mode: ON")
    else
        Humanoid.MaxHealth = 100
        Humanoid.Health = 100
        print("God Mode: OFF")
    end
end

FeatureFunctions.ToggleFullbright = function()
    States.Fullbright = not States.Fullbright
    
    if States.Fullbright then
        game.Lighting.Brightness = 2
        game.Lighting.ClockTime = 14
        game.Lighting.FogEnd = 100000
        game.Lighting.GlobalShadows = false
        game.Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        print("Fullbright: ON")
    else
        game.Lighting.Brightness = 1
        game.Lighting.ClockTime = 8
        game.Lighting.FogEnd = 100000
        game.Lighting.GlobalShadows = true
        game.Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
        print("Fullbright: OFF")
    end
end

FeatureFunctions.ToggleAntiAFK = function()
    States.AntiAFK = not States.AntiAFK
    
    if States.AntiAFK then
        Connections.AntiAFK = RunService.Heartbeat:Connect(function()
            game:GetService("VirtualUser"):CaptureController()
            game:GetService("VirtualUser"):ClickButton2(Vector2.new())
        end)
        print("Anti AFK: ON")
    else
        if Connections.AntiAFK then
            Connections.AntiAFK:Disconnect()
            Connections.AntiAFK = nil
        end
        print("Anti AFK: OFF")
    end
end

FeatureFunctions.SavePosition = function()
    Settings.SavedPosition = RootPart.CFrame
    print("Position Saved!")
end

FeatureFunctions.TeleportToSavedPosition = function()
    if Settings.SavedPosition then
        RootPart.CFrame = Settings.SavedPosition
        print("Teleported to saved position!")
    else
        print("No saved position found!")
    end
end

-- Create Main GUI
local function CreateGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "MobileExecutorGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = PlayerGui
    
    -- Store reference globally to prevent multiple instances
    _G.MobileExecutorGUI = ScreenGui
    
    -- Main Frame (Rectangle, positioned right)
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 380, 0, 480)
    MainFrame.Position = UDim2.new(1, -390, 0, 20)
    MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    -- Frame styling
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 12)
    Corner.Parent = MainFrame
    
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(0, 150, 255)
    Stroke.Thickness = 2
    Stroke.Parent = MainFrame
    
    -- Header with Logo
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 60)
    Header.Position = UDim2.new(0, 0, 0, 0)
    Header.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    Header.BorderSizePixel = 0
    Header.Parent = MainFrame
    
    local HeaderCorner = Instance.new("UICorner")
    HeaderCorner.CornerRadius = UDim.new(0, 12)
    HeaderCorner.Parent = Header
    
    -- Logo (Draggable)
    local Logo = Instance.new("TextButton")
    Logo.Name = "Logo"
    Logo.Size = UDim2.new(0, 40, 0, 40)
    Logo.Position = UDim2.new(0, 10, 0, 10)
    Logo.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    Logo.BorderSizePixel = 0
    Logo.Text = "⚡"
    Logo.TextScaled = true
    Logo.Font = Enum.Font.GothamBold
    Logo.TextColor3 = Color3.fromRGB(255, 255, 255)
    Logo.Parent = Header
    
    local LogoCorner = Instance.new("UICorner")
    LogoCorner.CornerRadius = UDim.new(0, 8)
    LogoCorner.Parent = Logo
    
    -- Title (also draggable area)
    local Title = Instance.new("TextButton")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, -110, 1, 0)
    Title.Position = UDim2.new(0, 60, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "Mobile Executor Pro"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextScaled = true
    Title.Font = Enum.Font.GothamBold
    Title.Parent = Header
    
    -- Minimize Button
    local MinimizeButton = Instance.new("TextButton")
    MinimizeButton.Name = "MinimizeButton"
    MinimizeButton.Size = UDim2.new(0, 30, 0, 30)
    MinimizeButton.Position = UDim2.new(1, -40, 0, 15)
    MinimizeButton.BackgroundColor3 = Color3.fromRGB(255, 193, 7)
    MinimizeButton.BorderSizePixel = 0
    MinimizeButton.Text = "−"
    MinimizeButton.TextScaled = true
    MinimizeButton.Font = Enum.Font.GothamBold
    MinimizeButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    MinimizeButton.Parent = Header
    
    local MinimizeCorner = Instance.new("UICorner")
    MinimizeCorner.CornerRadius = UDim.new(0, 6)
    MinimizeCorner.Parent = MinimizeButton
    
    -- Content Area
    local ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "ContentFrame"
    ContentFrame.Size = UDim2.new(1, -10, 1, -70)
    ContentFrame.Position = UDim2.new(0, 5, 0, 65)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.BorderSizePixel = 0
    ContentFrame.Parent = MainFrame
    
    -- Category Frame (Left side)
    local CategoryFrame = Instance.new("Frame")
    CategoryFrame.Name = "CategoryFrame"
    CategoryFrame.Size = UDim2.new(0, 110, 1, 0)
    CategoryFrame.Position = UDim2.new(0, 0, 0, 0)
    CategoryFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    CategoryFrame.BorderSizePixel = 0
    CategoryFrame.Parent = ContentFrame
    
    local CategoryCorner = Instance.new("UICorner")
    CategoryCorner.CornerRadius = UDim.new(0, 8)
    CategoryCorner.Parent = CategoryFrame
    
    local CategoryStroke = Instance.new("UIStroke")
    CategoryStroke.Color = Color3.fromRGB(50, 50, 50)
    CategoryStroke.Thickness = 1
    CategoryStroke.Parent = CategoryFrame
    
    -- Category List Layout
    local CategoryList = Instance.new("UIListLayout")
    CategoryList.SortOrder = Enum.SortOrder.LayoutOrder
    CategoryList.Padding = UDim.new(0, 5)
    CategoryList.Parent = CategoryFrame
    
    local CategoryPadding = Instance.new("UIPadding")
    CategoryPadding.PaddingAll = UDim.new(0, 8)
    CategoryPadding.Parent = CategoryFrame
    
    -- Features Frame (Right side)
    local FeaturesFrame = Instance.new("ScrollingFrame")
    FeaturesFrame.Name = "FeaturesFrame"
    FeaturesFrame.Size = UDim2.new(1, -120, 1, 0)
    FeaturesFrame.Position = UDim2.new(0, 120, 0, 0)
    FeaturesFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    FeaturesFrame.BorderSizePixel = 0
    FeaturesFrame.ScrollBarThickness = 6
    FeaturesFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
    FeaturesFrame.Parent = ContentFrame
    
    local FeaturesCorner = Instance.new("UICorner")
    FeaturesCorner.CornerRadius = UDim.new(0, 8)
    FeaturesCorner.Parent = FeaturesFrame
    
    local FeaturesStroke = Instance.new("UIStroke")
    FeaturesStroke.Color = Color3.fromRGB(50, 50, 50)
    FeaturesStroke.Thickness = 1
    FeaturesStroke.Parent = FeaturesFrame
    
    -- Features List Layout
    local FeaturesList = Instance.new("UIListLayout")
    FeaturesList.SortOrder = Enum.SortOrder.LayoutOrder
    FeaturesList.Padding = UDim.new(0, 8)
    FeaturesList.Parent = FeaturesFrame
    
    local FeaturesPadding = Instance.new("UIPadding")
    FeaturesPadding.PaddingAll = UDim.new(0, 10)
    FeaturesPadding.Parent = FeaturesFrame
    
    GUI.ScreenGui = ScreenGui
    GUI.MainFrame = MainFrame
    GUI.CategoryFrame = CategoryFrame
    GUI.FeaturesFrame = FeaturesFrame
    GUI.Logo = Logo
    GUI.Title = Title
    GUI.MinimizeButton = MinimizeButton
    GUI.ContentFrame = ContentFrame
    
    return GUI
end

-- Create Category Button
local function CreateCategoryButton(name, parent)
    local Button = Instance.new("TextButton")
    Button.Name = name .. "Category"
    Button.Size = UDim2.new(1, 0, 0, 40)
    Button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Button.BorderSizePixel = 0
    Button.Text = name
    Button.TextColor3 = Color3.fromRGB(200, 200, 200)
    Button.TextScaled = true
    Button.Font = Enum.Font.GothamSemibold
    Button.Parent = parent
    
    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 6)
    ButtonCorner.Parent = Button
    
    -- Highlight current category
    local function UpdateCategoryAppearance()
        if CurrentCategory == name then
            Button.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
            Button.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            Button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            Button.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end
    
    Button.MouseButton1Click:Connect(function()
        CurrentCategory = name
        UpdateAllCategories()
        LoadCategoryFeatures(name)
    end)
    
    Button.TouchTap:Connect(function()
        CurrentCategory = name
        UpdateAllCategories()
        LoadCategoryFeatures(name)
    end)
    
    UpdateCategoryAppearance()
    return Button, UpdateCategoryAppearance
end

-- Create Feature Button
local function CreateFeatureButton(name, funcName, parent)
    local Button = Instance.new("TextButton")
    Button.Name = name
    Button.Size = UDim2.new(1, 0, 0, 45)
    Button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    Button.BorderSizePixel = 0
    Button.Text = name
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.TextScaled = true
    Button.Font = Enum.Font.Gotham
    Button.Parent = parent
    
    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 8)
    ButtonCorner.Parent = Button
    
    local ButtonStroke = Instance.new("UIStroke")
    ButtonStroke.Color = Color3.fromRGB(70, 70, 70)
    ButtonStroke.Thickness = 1
    ButtonStroke.Parent = Button
    
    -- Hover effect
    Button.MouseEnter:Connect(function()
        Button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end)
    
    Button.MouseLeave:Connect(function()
        Button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    end)
    
    -- Click handler
    local function handleClick()
        if FeatureFunctions[funcName] then
            FeatureFunctions[funcName]()
        else
            print("Function not found: " .. tostring(funcName))
        end
    end
    
    Button.MouseButton1Click:Connect(handleClick)
    Button.TouchTap:Connect(handleClick)
    
    return Button
end

-- Update all category appearances
function UpdateAllCategories()
    for _, updateFunc in pairs(CategoryUpdateFunctions) do
        updateFunc()
    end
end

-- Load features for selected category
local function LoadCategoryFeatures(categoryName)
    -- Clear current features
    for _, child in pairs(GUI.FeaturesFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- Load new features
    local categoryFeatures = Categories[categoryName]
    if categoryFeatures then
        for _, feature in pairs(categoryFeatures) do
            CreateFeatureButton(feature.name, feature.func, GUI.FeaturesFrame)
        end
    end
    
    -- Update canvas size
    wait() -- Wait for UI to update
    GUI.FeaturesFrame.CanvasSize = UDim2.new(0, 0, 0, GUI.FeaturesFrame.UIListLayout.AbsoluteContentSize.Y + 20)
end

-- Minimize/Maximize functionality
local function ToggleMinimize()
    IsMinimized = not IsMinimized
    
    local targetSize, targetText
    if IsMinimized then
        targetSize = UDim2.new(0, 380, 0, 60)
        targetText = "+"
        GUI.ContentFrame.Visible = false
    else
        targetSize = UDim2.new(0, 380, 0, 480)
        targetText = "−"
        GUI.ContentFrame.Visible = true
    end
    
    GUI.MinimizeButton.Text = targetText
    
    local tween = TweenService:Create(
        GUI.MainFrame,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Size = targetSize}
    )
    tween:Play()
end

-- Make GUI draggable
local function MakeDraggable(frame, dragButton)
    local dragToggle = nil
    local dragStart = nil
    local startPos = nil
    
    local function updateInput(input)
        local delta = input.Position - dragStart
        local position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        frame.Position = position
    end
    
    dragButton.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragToggle = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragToggle = false
                end
            end)
        end
    end)
    
    dragButton.InputChanged:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            if dragToggle then
                updateInput(input)
            end
        end
    end)
end

-- Initialize GUI
local function InitializeGUI()
    CreateGUI()
    
    -- Create category buttons
    for categoryName, _ in pairs(Categories) do
        local button, updateFunc = CreateCategoryButton(categoryName, GUI.CategoryFrame)
        CategoryUpdateFunctions[categoryName] = updateFunc
    end
    
    -- Enable dragging
    MakeDraggable(GUI.MainFrame, GUI.Logo)
    MakeDraggable(GUI.MainFrame, GUI.Title)
    
    -- Minimize button functionality
    GUI.MinimizeButton.MouseButton1Click:Connect(ToggleMinimize)
    GUI.MinimizeButton.TouchTap:Connect(ToggleMinimize)
    
    -- Load default category
    LoadCategoryFeatures(CurrentCategory)
    UpdateAllCategories()
    
    -- Auto-update canvas size when content changes
    GUI.FeaturesFrame.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        GUI.FeaturesFrame.CanvasSize = UDim2.new(0, 0, 0, GUI.FeaturesFrame.UIListLayout.AbsoluteContentSize.Y + 20)
    end)
end

-- Character respawn handling
Player.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter
    Humanoid = Character:WaitForChild("Humanoid")
    RootPart = Character:WaitForChild("HumanoidRootPart")
    
    -- Reset states
    for state, _ in pairs(States) do
        States[state] = false
    end
    
    -- Reset humanoid values
    Humanoid.WalkSpeed = 16
    if Humanoid:FindFirstChild("JumpHeight") then
        Humanoid.JumpHeight = 7.2
    else
        Humanoid.JumpPower = 50
    end
    
    -- Disconnect old connections
    for _, connection in pairs(Connections) do
        if connection then
            connection:Disconnect()
        end
    end
    Connections = {}
    
    print("Character respawned - GUI states reset")
end)

-- Cleanup function
local function Cleanup()
    -- Disconnect all connections
    for _, connection in pairs(Connections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    -- Reset character properties
    if Humanoid then
        Humanoid.WalkSpeed = 16
        if Humanoid:FindFirstChild("JumpHeight") then
            Humanoid.JumpHeight = 7.2
        else
            Humanoid.JumpPower = 50
        end
        Humanoid.MaxHealth = 100
        Humanoid.Health = 100
    end
    
    -- Reset lighting
    game.Lighting.Brightness = 1
    game.Lighting.ClockTime = 8
    game.Lighting.FogEnd = 100000
    game.Lighting.GlobalShadows = true
    game.Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
    
    -- Reset camera
    if Workspace.CurrentCamera then
        Workspace.CurrentCamera.CameraSubject = Humanoid
    end
    
    -- Remove body velocities
    if RootPart then
        if RootPart:FindFirstChild("BodyVelocity") then
            RootPart.BodyVelocity:Destroy()
        end
        if RootPart:FindFirstChild("SpiderVelocity") then
            RootPart.SpiderVelocity:Destroy()
        end
    end
    
    print("Mobile Executor GUI cleaned up")
end

-- Handle script removal
if GUI.ScreenGui then
    GUI.ScreenGui.AncestryChanged:Connect(function()
        if not GUI.ScreenGui.Parent then
            Cleanup()
        end
    end)
end

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
    if player == Player then
        Cleanup()
    end
end)

-- Initialize
InitializeGUI()

print("✅ Mobile Executor GUI with Categories Loaded Successfully!")
print("📱 Features: Movement, Spectate, Utility")
print("🎯 Click logo or title to drag GUI")
print("📦 Click minimize button to hide/show")
print("⚡ All features are working and ready to use!")