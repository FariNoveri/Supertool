-- Mobile-Only Roblox Executor GUI Script
-- Fixes minimize to circular logo, Utility/Spectate category switching, Delta compatibility

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
local PhysicsService = game:GetService("PhysicsService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui", 10)
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid", 10)
local RootPart = Character:WaitForChild("HumanoidRootPart", 10)

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
    AntiAFK = false,
    Fullbright = false,
    PlayerNoclip = false
}

local Settings = {
    FlySpeed = 50,
    WalkSpeed = 50,
    JumpPower = 120,
    SpectateIndex = 1,
    SavedPosition = nil
}

-- Categories and features
local Categories = {
    Movement = {
        {name = "Toggle Fly", func = "ToggleFly"},
        {name = "Toggle Noclip", func = "ToggleNoclip"},
        {name = "Toggle Speed", func = "ToggleSpeedHack"},
        {name = "Toggle Jump Power", func = "ToggleJumpPower"}
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
        {name = "Toggle Player Noclip", func = "TogglePlayerNoclip"},
        {name = "Save Position", func = "SavePosition"},
        {name = "TP to Saved Pos", func = "TeleportToSavedPosition"}
    }
}

-- Feature Functions
local FeatureFunctions = {}

FeatureFunctions.ToggleFly = function()
    States.Flying = not States.Flying
    if States.Flying then
        local BodyVelocity = Instance.new("BodyVelocity")
        BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        BodyVelocity.Velocity = Vector3.new(0, 0, 0)
        BodyVelocity.Parent = RootPart
        
        Connections.Fly = RunService.Heartbeat:Connect(function()
            if States.Flying and RootPart and RootPart:FindFirstChild("BodyVelocity") then
                local MoveVector = Humanoid.MoveDirection
                local Camera = Workspace.CurrentCamera
                if Camera then
                    local velocity = (Camera.CFrame.LookVector * MoveVector.Z + Camera.CFrame.RightVector * MoveVector.X) * Settings.FlySpeed
                    if UserInputService.Jump then
                        velocity = velocity + Vector3.new(0, Settings.FlySpeed, 0)
                    end
                    BodyVelocity.Velocity = velocity
                end
            end
        end)
        print("Fly: ON")
    else
        if Connections.Fly then
            Connections.Fly:Disconnect()
            Connections.Fly = nil
        end
        if RootPart and RootPart:FindFirstChild("BodyVelocity") then
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
        Humanoid.JumpPower = Settings.JumpPower
        Humanoid.UseJumpPower = true
        print("Jump Power: ON (" .. Settings.JumpPower .. ")")
    else
        Humanoid.JumpPower = 50
        Humanoid.UseJumpPower = true
        print("Jump Power: OFF")
    end
end

FeatureFunctions.ToggleSpectate = function()
    States.Spectating = not States.Spectating
    local alivePlayers = GetAlivePlayers()
    if States.Spectating and #alivePlayers > 0 then
        Settings.SpectateIndex = math.clamp(Settings.SpectateIndex, 1, #alivePlayers)
        local targetPlayer = alivePlayers[Settings.SpectateIndex]
        if targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
            Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
            print("Spectating: " .. targetPlayer.Name)
        end
    else
        Workspace.CurrentCamera.CameraSubject = Humanoid
        print("Spectate: OFF")
    end
end

FeatureFunctions.NextSpectate = function()
    if not States.Spectating then return end
    local alivePlayers = GetAlivePlayers()
    if #alivePlayers > 0 then
        Settings.SpectateIndex = (Settings.SpectateIndex % #alivePlayers) + 1
        local targetPlayer = alivePlayers[Settings.SpectateIndex]
        if targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
            Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
            print("Spectating: " .. targetPlayer.Name)
        end
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
        if targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
            Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
            print("Spectating: " .. targetPlayer.Name)
        end
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

FeatureFunctions.TogglePlayerNoclip = function()
    States.PlayerNoclip = not States.PlayerNoclip
    if States.PlayerNoclip then
        pcall(function()
            PhysicsService:CreateCollisionGroup("NoPlayerCollision")
            PhysicsService:CreateCollisionGroup("DefaultPlayer")
            PhysicsService:CollisionGroupSetCollidable("NoPlayerCollision", "DefaultPlayer", false)
            
            if Character then
                for _, part in pairs(Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        PhysicsService:SetPartCollisionGroup(part, "NoPlayerCollision")
                    end
                end
            end
            
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= Player and player.Character then
                    for _, part in pairs(player.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            PhysicsService:SetPartCollisionGroup(part, "DefaultPlayer")
                        end
                    end
                end
            end
            
            Connections.PlayerNoclip = Players.PlayerAdded:Connect(function(newPlayer)
                if newPlayer ~= Player and newPlayer.Character then
                    for _, part in pairs(newPlayer.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            PhysicsService:SetPartCollisionGroup(part, "DefaultPlayer")
                        end
                    end
                end
            end)
            
            print("Player Noclip: ON")
        end)
    else
        if Connections.PlayerNoclip then
            Connections.PlayerNoclip:Disconnect()
            Connections.PlayerNoclip = nil
        end
        pcall(function()
            if Character then
                for _, part in pairs(Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        PhysicsService:SetPartCollisionGroup(part, "Default")
                    end
                end
            end
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= Player and player.Character then
                    for _, part in pairs(player.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            PhysicsService:SetPartCollisionGroup(part, "Default")
                        end
                    end
                end
            end
            print("Player Noclip: OFF")
        end)
    end
end

FeatureFunctions.SavePosition = function()
    if RootPart then
        Settings.SavedPosition = RootPart.CFrame
        print("Position Saved!")
    end
end

FeatureFunctions.TeleportToSavedPosition = function()
    if Settings.SavedPosition and RootPart then
        RootPart.CFrame = Settings.SavedPosition
        print("Teleported to saved position!")
    else
        print("No saved position found!")
    end
end

local function GetAlivePlayers()
    local alivePlayers = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= Player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(alivePlayers, player)
        end
    end
    return alivePlayers
end

-- Create Main GUI
local function CreateGUI()
    local success, result = pcall(function()
        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "MobileExecutorGUI"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.Enabled = true
        ScreenGui.Parent = PlayerGui
        
        _G.MobileExecutorGUI = ScreenGui
        
        local MainFrame = Instance.new("Frame")
        MainFrame.Name = "MainFrame"
        MainFrame.Size = UDim2.new(0, 300, 0, 400)
        MainFrame.Position = UDim2.new(1, -310, 0, 20)
        MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        MainFrame.BorderSizePixel = 0
        MainFrame.Visible = true
        MainFrame.ZIndex = 10
        MainFrame.Parent = ScreenGui
        
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(0, 12)
        Corner.Parent = MainFrame
        
        local Stroke = Instance.new("UIStroke")
        Stroke.Name = "MainStroke"
        Stroke.Color = Color3.fromRGB(0, 150, 255)
        Stroke.Thickness = 2
        Stroke.Transparency = 0
        Stroke.Parent = MainFrame
        
        local Logo = Instance.new("TextButton")
        Logo.Name = "Logo"
        Logo.Size = UDim2.new(0, 50, 0, 50)
        Logo.Position = UDim2.new(0, 5, 0, 5)
        Logo.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        Logo.BorderSizePixel = 0
        Logo.Text = "⚡"
        Logo.TextScaled = true
        Logo.Font = Enum.Font.GothamBold
        Logo.TextColor3 = Color3.fromRGB(255, 255, 255)
        Logo.ZIndex = 20
        Logo.Active = true
        Logo.Selectable = true
        Logo.AutoButtonColor = true
        Logo.Parent = ScreenGui -- Initially parented to ScreenGui for minimize
        
        local LogoCorner = Instance.new("UICorner")
        LogoCorner.CornerRadius = UDim.new(0.5, 0) -- Circular logo
        LogoCorner.Parent = Logo
        
        local Header = Instance.new("Frame")
        Header.Name = "Header"
        Header.Size = UDim2.new(1, 0, 0, 50)
        Header.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        Header.BorderSizePixel = 0
        Header.ZIndex = 12
        Header.Parent = MainFrame
        
        local HeaderCorner = Instance.new("UICorner")
        HeaderCorner.CornerRadius = UDim.new(0, 12)
        HeaderCorner.Parent = Header
        
        local Title = Instance.new("TextButton")
        Title.Name = "Title"
        Title.Size = UDim2.new(1, -90, 1, 0)
        Title.Position = UDim2.new(0, 50, 0, 0)
        Title.BackgroundTransparency = 1
        Title.Text = "Mobile Executor"
        Title.TextColor3 = Color3.fromRGB(255, 255, 255)
        Title.TextScaled = true
        Title.Font = Enum.Font.GothamBold
        Title.ZIndex = 12
        Title.Active = true
        Title.Selectable = true
        Title.AutoButtonColor = true
        Title.Parent = Header
        
        local MinimizeButton = Instance.new("TextButton")
        MinimizeButton.Name = "MinimizeButton"
        MinimizeButton.Size = UDim2.new(0, 30, 0, 30)
        MinimizeButton.Position = UDim2.new(1, -35, 0, 10)
        MinimizeButton.BackgroundColor3 = Color3.fromRGB(255, 193, 7)
        MinimizeButton.BorderSizePixel = 0
        MinimizeButton.Text = "−"
        MinimizeButton.TextScaled = true
        MinimizeButton.Font = Enum.Font.GothamBold
        MinimizeButton.TextColor3 = Color3.fromRGB(0, 0, 0)
        MinimizeButton.ZIndex = 12
        MinimizeButton.Active = true
        MinimizeButton.Selectable = true
        MinimizeButton.AutoButtonColor = true
        MinimizeButton.Parent = Header
        
        local MinimizeCorner = Instance.new("UICorner")
        MinimizeCorner.CornerRadius = UDim.new(0, 6)
        MinimizeCorner.Parent = MinimizeButton
        
        local ContentFrame = Instance.new("Frame")
        ContentFrame.Name = "ContentFrame"
        ContentFrame.Size = UDim2.new(1, -10, 1, -60)
        ContentFrame.Position = UDim2.new(0, 5, 0, 55)
        ContentFrame.BackgroundTransparency = 1
        ContentFrame.BorderSizePixel = 0
        ContentFrame.Visible = true
        ContentFrame.ZIndex = 10
        ContentFrame.Parent = MainFrame
        
        local CategoryFrame = Instance.new("Frame")
        CategoryFrame.Name = "CategoryFrame"
        CategoryFrame.Size = UDim2.new(0, 90, 1, 0)
        CategoryFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        CategoryFrame.BorderSizePixel = 0
        CategoryFrame.ZIndex = 15
        CategoryFrame.ClipsDescendants = false
        CategoryFrame.Parent = ContentFrame
        
        local CategoryCorner = Instance.new("UICorner")
        CategoryCorner.CornerRadius = UDim.new(0, 8)
        CategoryCorner.Parent = CategoryFrame
        
        local CategoryStroke = Instance.new("UIStroke")
        CategoryStroke.Color = Color3.fromRGB(50, 50, 50)
        CategoryStroke.Thickness = 1
        CategoryStroke.Parent = CategoryFrame
        
        local CategoryList = Instance.new("UIListLayout")
        CategoryList.SortOrder = Enum.SortOrder.LayoutOrder
        CategoryList.Padding = UDim.new(0, 5)
        CategoryList.Parent = CategoryFrame
        
        local CategoryPadding = Instance.new("UIPadding")
        CategoryPadding.PaddingTop = UDim.new(0, 8)
        CategoryPadding.PaddingBottom = UDim.new(0, 8)
        CategoryPadding.PaddingLeft = UDim.new(0, 8)
        CategoryPadding.PaddingRight = UDim.new(0, 8)
        CategoryPadding.Parent = CategoryFrame
        
        local FeaturesFrame = Instance.new("ScrollingFrame")
        FeaturesFrame.Name = "FeaturesFrame"
        FeaturesFrame.Size = UDim2.new(1, -100, 1, 0)
        FeaturesFrame.Position = UDim2.new(0, 100, 0, 0)
        FeaturesFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        FeaturesFrame.BorderSizePixel = 0
        FeaturesFrame.ScrollBarThickness = 4
        FeaturesFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
        FeaturesFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        FeaturesFrame.ZIndex = 10
        FeaturesFrame.Parent = ContentFrame
        
        local FeaturesCorner = Instance.new("UICorner")
        FeaturesCorner.CornerRadius = UDim.new(0, 8)
        FeaturesCorner.Parent = FeaturesFrame
        
        local FeaturesStroke = Instance.new("UIStroke")
        FeaturesStroke.Color = Color3.fromRGB(50, 50, 50)
        FeaturesStroke.Thickness = 1
        FeaturesStroke.Parent = FeaturesFrame
        
        local FeaturesList = Instance.new("UIListLayout")
        FeaturesList.SortOrder = Enum.SortOrder.LayoutOrder
        FeaturesList.Padding = UDim.new(0, 8)
        FeaturesList.Parent = FeaturesFrame
        
        local FeaturesPadding = Instance.new("UIPadding")
        FeaturesPadding.PaddingTop = UDim.new(0, 10)
        FeaturesPadding.PaddingBottom = UDim.new(0, 10)
        FeaturesPadding.PaddingLeft = UDim.new(0, 10)
        FeaturesPadding.PaddingRight = UDim.new(0, 10)
        FeaturesPadding.Parent = FeaturesFrame
        
        GUI.ScreenGui = ScreenGui
        GUI.MainFrame = MainFrame
        GUI.CategoryFrame = CategoryFrame
        GUI.FeaturesFrame = FeaturesFrame
        GUI.Logo = Logo
        GUI.Title = Title
        GUI.MinimizeButton = MinimizeButton
        GUI.MainStroke = Stroke
        
        return GUI
    end)
    
    if not success then
        warn("Error creating GUI: " .. tostring(result))
        return nil
    end
    return result
end

-- Create Category Button
local function CreateCategoryButton(name, parent)
    local success, result = pcall(function()
        print("Creating category button: " .. name)
        local Button = Instance.new("TextButton")
        Button.Name = name .. "Category"
        Button.Size = UDim2.new(1, 0, 0, 35)
        Button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        Button.BorderSizePixel = 0
        Button.Text = name
        Button.TextColor3 = Color3.fromRGB(200, 200, 200)
        Button.TextScaled = true
        Button.Font = Enum.Font.GothamSemibold
        Button.ZIndex = 20
        Button.Active = true
        Button.Selectable = true
        Button.AutoButtonColor = true
        Button.Parent = parent
        
        local ButtonCorner = Instance.new("UICorner")
        ButtonCorner.CornerRadius = UDim.new(0, 6)
        ButtonCorner.Parent = Button
        
        local function UpdateCategoryAppearance()
            Button.BackgroundColor3 = CurrentCategory == name and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(40, 40, 40)
            Button.TextColor3 = CurrentCategory == name and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
        end
        
        Button.TouchTap:Connect(function()
            print("Tapped category (TouchTap): " .. name)
            CurrentCategory = name
            UpdateAllCategories()
            task.defer(function()
                LoadCategoryFeatures(name)
            end)
        end)
        
        -- Fallback for Delta: Use InputBegan for touch detection
        Button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                print("Tapped category (InputBegan): " .. name)
                CurrentCategory = name
                UpdateAllCategories()
                task.defer(function()
                    LoadCategoryFeatures(name)
                end)
            end
        end)
        
        UpdateCategoryAppearance()
        print("Category button created: " .. name)
        return Button, UpdateCategoryAppearance
    end)
    
    if not success then
        warn("Error creating category button: " .. tostring(result))
        return nil, nil
    end
    return result
end

-- Create Feature Button
local function CreateFeatureButton(name, funcName, parent)
    local success, result = pcall(function()
        print("Creating feature button: " .. name)
        local Button = Instance.new("TextButton")
        Button.Name = name
        Button.Size = UDim2.new(1, 0, 0, 40)
        Button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        Button.BorderSizePixel = 0
        Button.Text = name
        Button.TextColor3 = Color3.fromRGB(255, 255, 255)
        Button.TextScaled = true
        Button.Font = Enum.Font.Gotham
        Button.ZIndex = 20
        Button.Active = true
        Button.Selectable = true
        Button.AutoButtonColor = true
        Button.Parent = parent
        
        local ButtonCorner = Instance.new("UICorner")
        ButtonCorner.CornerRadius = UDim.new(0, 8)
        ButtonCorner.Parent = Button
        
        local ButtonStroke = Instance.new("UIStroke")
        ButtonStroke.Color = Color3.fromRGB(70, 70, 70)
        ButtonStroke.Thickness = 1
        ButtonStroke.Parent = Button
        
        Button.TouchTap:Connect(function()
            print("Tapped feature (TouchTap): " .. name)
            if FeatureFunctions[funcName] then
                FeatureFunctions[funcName]()
            else
                print("Function not found: " .. tostring(funcName))
            end
        end)
        
        -- Fallback for Delta: Use InputBegan for touch detection
        Button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                print("Tapped feature (InputBegan): " .. name)
                if FeatureFunctions[funcName] then
                    FeatureFunctions[funcName]()
                else
                    print("Function not found: " .. tostring(funcName))
                end
            end
        end)
        
        print("Feature button created: " .. name)
        return Button
    end)
    
    if not success then
        warn("Error creating feature button: " .. tostring(result))
        return nil
    end
    return result
end

-- Update all category appearances
function UpdateAllCategories()
    local success, result = pcall(function()
        for categoryName, updateFunc in pairs(CategoryUpdateFunctions) do
            if updateFunc then
                updateFunc()
            else
                warn("No update function for category: " .. categoryName)
            end
        end
    end)
    if not success then
        warn("Error updating categories: " .. tostring(result))
    end
end

-- Load features for selected category
local function LoadCategoryFeatures(categoryName)
    local success, result = pcall(function()
        print("Loading features for category: " .. categoryName)
        -- Clear existing feature buttons
        for _, child in pairs(GUI.FeaturesFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        -- Verify category exists
        local categoryFeatures = Categories[categoryName]
        if not categoryFeatures then
            warn("Category not found: " .. tostring(categoryName))
            return
        end
        
        -- Load feature buttons
        for i, feature in ipairs(categoryFeatures) do
            print("Loading feature " .. i .. ": " .. feature.name)
            local button = CreateFeatureButton(feature.name, feature.func, GUI.FeaturesFrame)
            if not button then
                warn("Failed to create feature button: " .. feature.name)
            end
        end
        
        -- Update canvas size
        GUI.FeaturesFrame.CanvasSize = UDim2.new(0, 0, 0, GUI.FeaturesFrame.UIListLayout.AbsoluteContentSize.Y + 20)
        print("Features loaded for category: " .. categoryName)
    end)
    
    if not success then
        warn("Error loading category features: " .. tostring(result))
    end
end

-- Minimize/Maximize functionality
local function ToggleMinimize()
    local success, result = pcall(function()
        IsMinimized = not IsMinimized
        
        if IsMinimized then
            -- Hide MainFrame and its children
            GUI.MainFrame.Visible = false
            GUI.Logo.Parent = GUI.ScreenGui
            GUI.Logo.Size = UDim2.new(0, 50, 0, 50)
            GUI.Logo.Position = UDim2.new(1, -60, 0, 20)
        else
            -- Show MainFrame and reparent Logo
            GUI.MainFrame.Visible = true
            GUI.Logo.Parent = GUI.MainFrame
            GUI.Logo.Size = UDim2.new(0, 50, 0, 50)
            GUI.Logo.Position = UDim2.new(0, 5, 0, 5)
            task.defer(function()
                LoadCategoryFeatures(CurrentCategory)
            end)
        end
        
        local tween = TweenService:Create(
            GUI.Logo,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 50, 0, 50), Position = IsMinimized and UDim2.new(1, -60, 0, 20) or UDim2.new(0, 5, 0, 5)}
        )
        tween:Play()
        
        print("Minimize state: " .. (IsMinimized and "Minimized" or "Maximized"))
    end)
    
    if not success then
        warn("Error in minimize function: " .. tostring(result))
    end
end

-- Make Logo draggable
local function MakeDraggable(button)
    local success, result = pcall(function()
        local dragToggle = false
        local dragStart = nil
        local startPos = nil
        
        button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                dragToggle = true
                dragStart = input.Position
                startPos = button.Position
            end
        end)
        
        button.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch and dragToggle then
                local delta = input.Position - dragStart
                local position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                button.Position = position
            end
        end)
        
        button.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                dragToggle = false
            end
        end)
        
        button.TouchTap:Connect(function()
            if IsMinimized then
                print("Logo tapped, maximizing GUI")
                ToggleMinimize()
            end
        end)
        
        -- Fallback for Delta: Use InputBegan for tap detection
        button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch and IsMinimized then
                print("Logo tapped (InputBegan), maximizing GUI")
                ToggleMinimize()
            end
        end)
    end)
    
    if not success then
        warn("Error setting up draggable: " .. tostring(result))
    end
end

-- Initialize GUI
local function InitializeGUI()
    local success, result = pcall(function()
        GUI = CreateGUI()
        if not GUI then
            error("Failed to create GUI")
        end
        
        for categoryName, _ in pairs(Categories) do
            local button, updateFunc = CreateCategoryButton(categoryName, GUI.CategoryFrame)
            if button and updateFunc then
                CategoryUpdateFunctions[categoryName] = updateFunc
            else
                warn("Failed to create category button for: " .. categoryName)
            end
        end
        
        MakeDraggable(GUI.Logo)
        
        GUI.MinimizeButton.TouchTap:Connect(function()
            print("Minimize button tapped (TouchTap)")
            ToggleMinimize()
        end)
        
        -- Fallback for Delta: Use InputBegan for minimize button
        GUI.MinimizeButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                print("Minimize button tapped (InputBegan)")
                ToggleMinimize()
            end
        end)
        
        task.defer(function()
            LoadCategoryFeatures(CurrentCategory)
        end)
        UpdateAllCategories()
        
        GUI.FeaturesFrame.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            GUI.FeaturesFrame.CanvasSize = UDim2.new(0, 0, 0, GUI.FeaturesFrame.UIListLayout.AbsoluteContentSize.Y + 20)
        end)
    end)
    
    if not success then
        warn("Error initializing GUI: " .. tostring(result))
    end
end

-- Character respawn handling
Player.CharacterAdded:Connect(function(newCharacter)
    local success, result = pcall(function()
        Character = newCharacter
        Humanoid = Character:WaitForChild("Humanoid", 10)
        RootPart = Character:WaitForChild("HumanoidRootPart", 10)
        
        for state, _ in pairs(States) do
            States[state] = false
        end
        
        Humanoid.WalkSpeed = 16
        Humanoid.JumpPower = 50
        Humanoid.UseJumpPower = true
        Humanoid.MaxHealth = 100
        Humanoid.Health = 100
        
        for _, connection in pairs(Connections) do
            if connection then
                connection:Disconnect()
            end
        end
        Connections = {}
        
        if States.PlayerNoclip then
            FeatureFunctions.TogglePlayerNoclip()
            FeatureFunctions.TogglePlayerNoclip()
        end
        
        print("Character respawned - GUI states reset")
    end)
    
    if not success then
        warn("Error in character respawn handling: " .. tostring(result))
    end
end)

-- Cleanup function
local function Cleanup()
    local success, result = pcall(function()
        for _, connection in pairs(Connections) do
            if connection then
                connection:Disconnect()
            end
        end
        
        if Humanoid then
            Humanoid.WalkSpeed = 16
            Humanoid.JumpPower = 50
            Humanoid.UseJumpPower = true
            Humanoid.MaxHealth = 100
            Humanoid.Health = 100
        end
        
        game.Lighting.Brightness = 1
        game.Lighting.ClockTime = 8
        game.Lighting.FogEnd = 100000
        game.Lighting.GlobalShadows = true
        game.Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
        
        if Workspace.CurrentCamera then
            Workspace.CurrentCamera.CameraSubject = Humanoid
        end
        
        if RootPart and RootPart:FindFirstChild("BodyVelocity") then
            RootPart.BodyVelocity:Destroy()
        end
        
        pcall(function()
            if Character then
                for _, part in pairs(Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        PhysicsService:SetPartCollisionGroup(part, "Default")
                    end
                end
            end
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= Player and player.Character then
                    for _, part in pairs(player.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            PhysicsService:SetPartCollisionGroup(part, "Default")
                        end
                    end
                end
            end
        end)
        
        print("Mobile Executor GUI cleaned up")
    end)
    
    if not success then
        warn("Error in cleanup: " .. tostring(result))
    end
end

-- Handle script removal
if GUI.ScreenGui then
    GUI.ScreenGui.AncestryChanged:Connect(function()
        if not GUI.ScreenGui.Parent then
            Cleanup()
        end
    end)
end

Players.PlayerRemoving:Connect(function(player)
    if player == Player then
        Cleanup()
    end
end)

-- Initialize
local success, result = pcall(InitializeGUI)
if not success then
    warn("Error during initialization: " .. tostring(result))
else
    print("✅ Mobile Executor GUI Loaded Successfully!")
    print("📱 Optimized for Mobile (Delta Executor)")
    print("🎯 Drag logo to move GUI")
    print("📦 Tap minimize button to hide GUI, tap logo to show")
    print("⚡ All features are mobile-ready!")
end