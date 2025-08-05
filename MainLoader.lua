-- Roblox Mobile GUI Script with Categories
-- Compatible with all games, mobile-optimized

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
        {name = "Toggle Fly", func = nil},
        {name = "Toggle Noclip", func = nil},
        {name = "Toggle Speed", func = nil},
        {name = "Toggle Jump Power", func = nil},
        {name = "Toggle SpiderMan", func = nil}
    },
    Spectate = {
        {name = "Toggle Spectate", func = nil},
        {name = "Next Spectate", func = nil},
        {name = "Prev Spectate", func = nil},
        {name = "TP to Spectate", func = nil}
    },
    Utility = {
        {name = "Toggle God Mode", func = nil},
        {name = "Toggle Fullbright", func = nil},
        {name = "Toggle Anti AFK", func = nil},
        {name = "Save Position", func = nil},
        {name = "TP to Saved Pos", func = nil}
    }
}

-- Create Main GUI
local function CreateGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "MobileExecutorGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = PlayerGui
    
    -- Main Frame (Rectangle, positioned right)
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 380, 0, 480)
    MainFrame.Position = UDim2.new(1, -390, 0, 20)
    MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    
    -- Frame styling
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = MainFrame
    
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(40, 40, 40)
    Stroke.Thickness = 1
    Stroke.Parent = MainFrame
    
    -- Header with Logo
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 50)
    Header.Position = UDim2.new(0, 0, 0, 0)
    Header.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    Header.BorderSizePixel = 0
    Header.Parent = MainFrame
    
    local HeaderCorner = Instance.new("UICorner")
    HeaderCorner.CornerRadius = UDim.new(0, 8)
    HeaderCorner.Parent = Header
    
    -- Logo (Draggable)
    local Logo = Instance.new("TextButton")
    Logo.Name = "Logo"
    Logo.Size = UDim2.new(0, 30, 0, 30)
    Logo.Position = UDim2.new(0, 10, 0, 10)
    Logo.BackgroundColor3 = Color3.fromRGB(255, 0, 128)
    Logo.BorderSizePixel = 0
    Logo.Text = "🎯"
    Logo.TextScaled = true
    Logo.Font = Enum.Font.GothamBold
    Logo.TextColor3 = Color3.fromRGB(0, 0, 0)
    Logo.Parent = Header
    
    local LogoCorner = Instance.new("UICorner")
    LogoCorner.CornerRadius = UDim.new(0, 4)
    LogoCorner.Parent = Logo
    
    -- Title (also draggable area)
    local Title = Instance.new("TextButton")
    Title.Name = "Title"
    Title.Size = UDim2.new(1, -50, 1, 0)
    Title.Position = UDim2.new(0, 50, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "Mobile Executor"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextScaled = true
    Title.Font = Enum.Font.GothamBold
    Title.Parent = Header
    
    -- Content Area
    local ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "ContentFrame"
    ContentFrame.Size = UDim2.new(1, -10, 1, -60)
    ContentFrame.Position = UDim2.new(0, 5, 0, 55)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.BorderSizePixel = 0
    ContentFrame.Parent = MainFrame
    
    -- Category Frame (Left side)
    local CategoryFrame = Instance.new("Frame")
    CategoryFrame.Name = "CategoryFrame"
    CategoryFrame.Size = UDim2.new(0, 100, 1, 0)
    CategoryFrame.Position = UDim2.new(0, 0, 0, 0)
    CategoryFrame.BackgroundColor3 = Color3.fromRGB(5, 5, 5)
    CategoryFrame.BorderSizePixel = 0
    CategoryFrame.Parent = ContentFrame
    
    local CategoryCorner = Instance.new("UICorner")
    CategoryCorner.CornerRadius = UDim.new(0, 4)
    CategoryCorner.Parent = CategoryFrame
    
    local CategoryStroke = Instance.new("UIStroke")
    CategoryStroke.Color = Color3.fromRGB(30, 30, 30)
    CategoryStroke.Thickness = 1
    CategoryStroke.Parent = CategoryFrame
    
    -- Category List Layout
    local CategoryList = Instance.new("UIListLayout")
    CategoryList.SortOrder = Enum.SortOrder.LayoutOrder
    CategoryList.Padding = UDim.new(0, 2)
    CategoryList.Parent = CategoryFrame
    
    local CategoryPadding = Instance.new("UIPadding")
    CategoryPadding.PaddingAll = UDim.new(0, 5)
    CategoryPadding.Parent = CategoryFrame
    
    -- Features Frame (Right side)
    local FeaturesFrame = Instance.new("ScrollingFrame")
    FeaturesFrame.Name = "FeaturesFrame"
    FeaturesFrame.Size = UDim2.new(1, -110, 1, 0)
    FeaturesFrame.Position = UDim2.new(0, 110, 0, 0)
    FeaturesFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
    FeaturesFrame.BorderSizePixel = 0
    FeaturesFrame.ScrollBarThickness = 4
    FeaturesFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
    FeaturesFrame.Parent = ContentFrame
    
    local FeaturesCorner = Instance.new("UICorner")
    FeaturesCorner.CornerRadius = UDim.new(0, 4)
    FeaturesCorner.Parent = FeaturesFrame
    
    local FeaturesStroke = Instance.new("UIStroke")
    FeaturesStroke.Color = Color3.fromRGB(30, 30, 30)
    FeaturesStroke.Thickness = 1
    FeaturesStroke.Parent = FeaturesFrame
    
    -- Features List Layout
    local FeaturesList = Instance.new("UIListLayout")
    FeaturesList.SortOrder = Enum.SortOrder.LayoutOrder
    FeaturesList.Padding = UDim.new(0, 5)
    FeaturesList.Parent = FeaturesFrame
    
    local FeaturesPadding = Instance.new("UIPadding")
    FeaturesPadding.PaddingAll = UDim.new(0, 8)
    FeaturesPadding.Parent = FeaturesFrame
    
    GUI.ScreenGui = ScreenGui
    GUI.MainFrame = MainFrame
    GUI.CategoryFrame = CategoryFrame
    GUI.FeaturesFrame = FeaturesFrame
    GUI.Logo = Logo
    GUI.Title = Title
    
    return GUI
end

-- Create Category Button
local function CreateCategoryButton(name, parent)
    local Button = Instance.new("TextButton")
    Button.Name = name .. "Category"
    Button.Size = UDim2.new(1, 0, 0, 35)
    Button.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    Button.BorderSizePixel = 0
    Button.Text = name
    Button.TextColor3 = Color3.fromRGB(200, 200, 200)
    Button.TextScaled = true
    Button.Font = Enum.Font.GothamSemibold
    Button.Parent = parent
    
    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 3)
    ButtonCorner.Parent = Button
    
    -- Highlight current category
    local function UpdateCategoryAppearance()
        if CurrentCategory == name then
            Button.BackgroundColor3 = Color3.fromRGB(255, 0, 128)
            Button.TextColor3 = Color3.fromRGB(0, 0, 0)
        else
            Button.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
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
local function CreateFeatureButton(name, callback, parent)
    local Button = Instance.new("TextButton")
    Button.Name = name
    Button.Size = UDim2.new(1, 0, 0, 40)
    Button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Button.BorderSizePixel = 0
    Button.Text = name
    Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    Button.TextScaled = true
    Button.Font = Enum.Font.Gotham
    Button.Parent = parent
    
    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 4)
    ButtonCorner.Parent = Button
    
    local ButtonStroke = Instance.new("UIStroke")
    ButtonStroke.Color = Color3.fromRGB(40, 40, 40)
    ButtonStroke.Thickness = 1
    ButtonStroke.Parent = Button
    
    Button.MouseButton1Click:Connect(callback)
    Button.TouchTap:Connect(callback)
    
    return Button
end

-- Update all category appearances
local CategoryUpdateFunctions = {}
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
    GUI.FeaturesFrame.CanvasSize = UDim2.new(0, 0, 0, GUI.FeaturesFrame.UIListLayout.AbsoluteContentSize.Y + 16)
end

-- Movement Features
local function ToggleFly()
    States.Flying = not States.Flying
    
    if States.Flying then
        local BodyVelocity = Instance.new("BodyVelocity")
        BodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        BodyVelocity.Velocity = Vector3.new(0, 0, 0)
        BodyVelocity.Parent = RootPart
        
        Connections.Fly = RunService.Heartbeat:Connect(function()
            if States.Flying then
                local MoveVector = Humanoid.MoveDirection
                BodyVelocity.Velocity = (Workspace.CurrentCamera.CFrame.LookVector * MoveVector.Z + Workspace.CurrentCamera.CFrame.RightVector * MoveVector.X) * Settings.FlySpeed
            end
        end)
    else
        if Connections.Fly then
            Connections.Fly:Disconnect()
        end
        if RootPart:FindFirstChild("BodyVelocity") then
            RootPart.BodyVelocity:Destroy()
        end
    end
end

local function ToggleNoclip()
    States.Noclip = not States.Noclip
    
    if States.Noclip then
        Connections.Noclip = RunService.Stepped:Connect(function()
            for _, part in pairs(Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)
    else
        if Connections.Noclip then
            Connections.Noclip:Disconnect()
        end
        for _, part in pairs(Character:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end
end

local function ToggleSpeedHack()
    States.SpeedHack = not States.SpeedHack
    
    if States.SpeedHack then
        Humanoid.WalkSpeed = Settings.WalkSpeed
    else
        Humanoid.WalkSpeed = 16
    end
end

local function ToggleJumpPower()
    States.JumpPower = not States.JumpPower
    
    if States.JumpPower then
        if Humanoid:FindFirstChild("JumpHeight") then
            Humanoid.JumpHeight = Settings.JumpPower
        else
            Humanoid.JumpPower = Settings.JumpPower
        end
    else
        if Humanoid:FindFirstChild("JumpHeight") then
            Humanoid.JumpHeight = 7.2
        else
            Humanoid.JumpPower = 50
        end
    end
end

local function ToggleSpiderMan()
    States.SpiderMan = not States.SpiderMan
    
    if States.SpiderMan then
        Connections.SpiderMan = RunService.Heartbeat:Connect(function()
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
        end)
    else
        if Connections.SpiderMan then
            Connections.SpiderMan:Disconnect()
        end
        if RootPart:FindFirstChild("SpiderVelocity") then
            RootPart.SpiderVelocity:Destroy()
        end
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

local function ToggleSpectate()
    States.Spectating = not States.Spectating
    local alivePlayers = GetAlivePlayers()
    
    if States.Spectating and #alivePlayers > 0 then
        Settings.SpectateIndex = math.min(Settings.SpectateIndex, #alivePlayers)
        local targetPlayer = alivePlayers[Settings.SpectateIndex]
        Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
    else
        Workspace.CurrentCamera.CameraSubject = Humanoid
    end
end

local function NextSpectate()
    if not States.Spectating then return end
    local alivePlayers = GetAlivePlayers()
    if #alivePlayers > 0 then
        Settings.SpectateIndex = Settings.SpectateIndex % #alivePlayers + 1
        local targetPlayer = alivePlayers[Settings.SpectateIndex]
        Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
    end
end

local function PrevSpectate()
    if not States.Spectating then return end
    local alivePlayers = GetAlivePlayers()
    if #alivePlayers > 0 then
        Settings.SpectateIndex = Settings.SpectateIndex - 1
        if Settings.SpectateIndex < 1 then
            Settings.SpectateIndex = #alivePlayers
        end
        local targetPlayer = alivePlayers[Settings.SpectateIndex]
        Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
    end
end

local function TeleportToSpectate()
    if not States.Spectating then return end
    local alivePlayers = GetAlivePlayers()
    if #alivePlayers > 0 then
        local targetPlayer = alivePlayers[Settings.SpectateIndex]
        if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            RootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame
        end
    end
end

-- Utility Features
local function ToggleGodMode()
    States.GodMode = not States.GodMode
    
    if States.GodMode then
        Humanoid.MaxHealth = math.huge
        Humanoid.Health = math.huge
    else
        Humanoid.MaxHealth = 100
        Humanoid.Health = 100
    end
end

local function ToggleFullbright()
    States.Fullbright = not States.Fullbright
    
    if States.Fullbright then
        game.Lighting.Brightness = 2
        game.Lighting.ClockTime = 14
        game.Lighting.FogEnd = 100000
        game.Lighting.GlobalShadows = false
        game.Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    else
        game.Lighting.Brightness = 1
        game.Lighting.ClockTime = 8
        game.Lighting.FogEnd = 100000
        game.Lighting.GlobalShadows = true
        game.Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
    end
end

local function ToggleAntiAFK()
    States.AntiAFK = not States.AntiAFK
    
    if States.AntiAFK then
        Connections.AntiAFK = RunService.Heartbeat:Connect(function()
            game:GetService("VirtualUser"):CaptureController()
            game:GetService("VirtualUser"):ClickButton2(Vector2.new())
        end)
    else
        if Connections.AntiAFK then
            Connections.AntiAFK:Disconnect()
        end
    end
end

local function SavePosition()
    Settings.SavedPosition = RootPart.CFrame
end

local function TeleportToSavedPosition()
    if Settings.SavedPosition then
        RootPart.CFrame = Settings.SavedPosition
    end
end

-- Assign functions to categories
Categories.Movement[1].func = ToggleFly
Categories.Movement[2].func = ToggleNoclip
Categories.Movement[3].func = ToggleSpeedHack
Categories.Movement[4].func = ToggleJumpPower
Categories.Movement[5].func = ToggleSpiderMan

Categories.Spectate[1].func = ToggleSpectate
Categories.Spectate[2].func = NextSpectate
Categories.Spectate[3].func = PrevSpectate
Categories.Spectate[4].func = TeleportToSpectate

Categories.Utility[1].func = ToggleGodMode
Categories.Utility[2].func = ToggleFullbright
Categories.Utility[3].func = ToggleAntiAFK
Categories.Utility[4].func = SavePosition
Categories.Utility[5].func = TeleportToSavedPosition

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
    
    -- Load default category
    LoadCategoryFeatures(CurrentCategory)
    UpdateAllCategories()
    
    -- Auto-update canvas size when content changes
    GUI.FeaturesFrame.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        GUI.FeaturesFrame.CanvasSize = UDim2.new(0, 0, 0, GUI.FeaturesFrame.UIListLayout.AbsoluteContentSize.Y + 16)
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
end)

-- Initialize
InitializeGUI()

print("Mobile Executor GUI with Categories Loaded!")