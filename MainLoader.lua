-- Enhanced Minimalist Roblox Script for Android (Fluxus Optimized)
-- Black theme, compact right-aligned rectangular GUI, draggable, watermark with HWID
-- Auto-disable previous instances, minimize feature, scrollable content, persistent features

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

-- Disable any existing instances of this script
for _, gui in pairs(LocalPlayer.PlayerGui:GetChildren()) do
    if gui.Name == "MinimalistGUI" then
        gui:Destroy()
    end
end

-- Global cleanup for previous instances
if getgenv and getgenv().MinimalistGUICleanup then
    getgenv().MinimalistGUICleanup()
end

-- Cleanup function for current instance
local cleanup = {}
local function addToCleanup(connection)
    table.insert(cleanup, connection)
end

local function cleanupAll()
    for _, connection in pairs(cleanup) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
    cleanup = {}
end

if getgenv then
    getgenv().MinimalistGUICleanup = cleanupAll
end

-- Use ScreenGui for Fluxus compatibility
local gui = Instance.new("ScreenGui")
gui.Name = "MinimalistGUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Main Frame (Compact, Right-Aligned, Rectangular)
local mainFrame = Instance.new("Frame", gui)
mainFrame.Size = UDim2.new(0, 350, 0, 250)
mainFrame.Position = UDim2.new(1, -360, 0.5, -125)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.ZIndex = 10

-- Add corner rounding
local mainCorner = Instance.new("UICorner", mainFrame)
mainCorner.CornerRadius = UDim.new(0, 8)

-- Add stroke
local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Color = Color3.fromRGB(40, 40, 40)
mainStroke.Thickness = 1

-- Title Bar - Make it draggable
local titleBar = Instance.new("Frame", mainFrame)
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 11
titleBar.Active = true

-- Make titleBar draggable
local dragging = false
local dragStart = nil
local startPos = nil

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)

titleBar.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

titleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

local titleCorner = Instance.new("UICorner", titleBar)
titleCorner.CornerRadius = UDim.new(0, 8)

-- Logo (Top-right, draggable)
local logo = Instance.new("TextButton", gui)
logo.Size = UDim2.new(0, 35, 0, 35)
logo.Position = UDim2.new(1, -45, 0, 10)
logo.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
logo.Text = "⚡"
logo.TextColor3 = Color3.fromRGB(100, 150, 255)
logo.TextSize = 18
logo.Font = Enum.Font.SourceSansBold
logo.ZIndex = 15
logo.Active = true
logo.Draggable = true

local logoCorner = Instance.new("UICorner", logo)
logoCorner.CornerRadius = UDim.new(0, 17)

local logoStroke = Instance.new("UIStroke", logo)
logoStroke.Color = Color3.fromRGB(40, 40, 40)
logoStroke.Thickness = 2

-- Logo click to toggle GUI
logo.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

-- Title (adjusted position)
local title = Instance.new("TextLabel", titleBar)
title.Size = UDim2.new(0, 120, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Unknown Block"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 14
title.Font = Enum.Font.SourceSansBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 12

-- Minimize Button
local minimizeButton = Instance.new("TextButton", titleBar)
minimizeButton.Size = UDim2.new(0, 25, 0, 20)
minimizeButton.Position = UDim2.new(1, -55, 0, 5)
minimizeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
minimizeButton.Text = "—"
minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeButton.TextSize = 12
minimizeButton.ZIndex = 12

local minimizeCorner = Instance.new("UICorner", minimizeButton)
minimizeCorner.CornerRadius = UDim.new(0, 4)

-- Close Button
local closeButton = Instance.new("TextButton", titleBar)
closeButton.Size = UDim2.new(0, 25, 0, 20)
closeButton.Position = UDim2.new(1, -25, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 12
closeButton.ZIndex = 12

local closeCorner = Instance.new("UICorner", closeButton)
closeCorner.CornerRadius = UDim.new(0, 4)

-- Watermark with HWID
local hwid = "Unknown"
pcall(function()
    hwid = gethwid and gethwid() or "No HWID"
end)
local watermark = Instance.new("TextLabel", titleBar)
watermark.Size = UDim2.new(0, 180, 1, 0)
watermark.Position = UDim2.new(1, -240, 0, 0)
watermark.BackgroundTransparency = 1
watermark.Text = "farinoveri | " .. hwid
watermark.TextColor3 = Color3.fromRGB(150, 150, 150)
watermark.TextSize = 10
watermark.Font = Enum.Font.SourceSans
watermark.TextXAlignment = Enum.TextXAlignment.Right
watermark.ZIndex = 12

-- Content Container
local contentContainer = Instance.new("Frame", mainFrame)
contentContainer.Size = UDim2.new(1, 0, 1, -30)
contentContainer.Position = UDim2.new(0, 0, 0, 30)
contentContainer.BackgroundTransparency = 1
contentContainer.ZIndex = 11

-- Sidebar (Left within Frame)
local sidebar = Instance.new("Frame", contentContainer)
sidebar.Size = UDim2.new(0, 90, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
sidebar.BorderSizePixel = 0
sidebar.ZIndex = 11

local sidebarCorner = Instance.new("UICorner", sidebar)
sidebarCorner.CornerRadius = UDim.new(0, 6)

-- Content Frame (Right within Frame)
local contentFrame = Instance.new("ScrollingFrame", contentContainer)
contentFrame.Size = UDim2.new(0, 250, 1, 0)
contentFrame.Position = UDim2.new(0, 95, 0, 0)
contentFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
contentFrame.BorderSizePixel = 0
contentFrame.ZIndex = 11
contentFrame.ScrollBarThickness = 4
contentFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

local contentCorner = Instance.new("UICorner", contentFrame)
contentCorner.CornerRadius = UDim.new(0, 6)

-- Main Button (⚡ Bottom Right) - Only shows when minimized
local mainButton = Instance.new("TextButton")
mainButton.Size = UDim2.new(0, 45, 0, 45)
mainButton.Position = UDim2.new(1, -55, 1, -55)
mainButton.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
mainButton.Text = "⚡"
mainButton.TextColor3 = Color3.fromRGB(100, 150, 255)
mainButton.TextSize = 20
mainButton.Font = Enum.Font.SourceSansBold
mainButton.Parent = gui
mainButton.ZIndex = 10
mainButton.Visible = false

local buttonCorner = Instance.new("UICorner", mainButton)
buttonCorner.CornerRadius = UDim.new(0, 22)

local buttonStroke = Instance.new("UIStroke", mainButton)
buttonStroke.Color = Color3.fromRGB(40, 40, 40)
buttonStroke.Thickness = 2

-- Minimize/Maximize functionality
local isMinimized = false
minimizeButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        mainFrame.Visible = false
        mainButton.Visible = true
        minimizeButton.Text = "□"
    else
        mainFrame.Visible = true
        mainButton.Visible = false
        minimizeButton.Text = "—"
    end
end)

mainButton.MouseButton1Click:Connect(function()
    isMinimized = false
    mainFrame.Visible = true
    mainButton.Visible = false
    minimizeButton.Text = "—"
end)

closeButton.MouseButton1Click:Connect(function()
    cleanupAll()
    gui:Destroy()
end)

-- Notification System
local function notify(message)
    local notif = Instance.new("Frame", gui)
    notif.Size = UDim2.new(0, 200, 0, 40)
    notif.Position = UDim2.new(0.5, -100, 0, 20)
    notif.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    notif.ZIndex = 20
    
    local notifCorner = Instance.new("UICorner", notif)
    notifCorner.CornerRadius = UDim.new(0, 6)
    
    local notifStroke = Instance.new("UIStroke", notif)
    notifStroke.Color = Color3.fromRGB(60, 60, 60)
    notifStroke.Thickness = 1
    
    local notifText = Instance.new("TextLabel", notif)
    notifText.Size = UDim2.new(1, -10, 1, 0)
    notifText.Position = UDim2.new(0, 5, 0, 0)
    notifText.BackgroundTransparency = 1
    notifText.Text = message
    notifText.TextColor3 = Color3.fromRGB(255, 255, 255)
    notifText.TextSize = 12
    notifText.Font = Enum.Font.SourceSans
    notifText.TextWrapped = true
    notifText.ZIndex = 21
    
    -- Fade in
    notif.BackgroundTransparency = 1
    notifText.TextTransparency = 1
    TweenService:Create(notif, TweenInfo.new(0.3), {BackgroundTransparency = 0}):Play()
    TweenService:Create(notifText, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
    
    -- Fade out and destroy
    wait(2.5)
    TweenService:Create(notif, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    TweenService:Create(notifText, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
    wait(0.3)
    notif:Destroy()
end

-- Initialize GUI and handle respawn
local function initializeGui()
    if not gui.Parent then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        notify("GUI Initialized")
    end
end

initializeGui()
addToCleanup(LocalPlayer.CharacterAdded:Connect(initializeGui))
addToCleanup(Players.PlayerAdded:Connect(function(player)
    if player == LocalPlayer then
        initializeGui()
    end
end))

-- Category System
local categories = {"Movement", "Teleport", "Player", "Misc"}
local currentCategory = "Movement"
local categoryButtons = {}

-- Feature States (Persistent across category switches)
local featureStates = {
    freecamEnabled = false,
    speedEnabled = false,
    jumpEnabled = false,
    noclipEnabled = false,
    wallClimbEnabled = false,
    noPlayerCollisionEnabled = false,
    godModeEnabled = false,
    fakeStatsEnabled = false,
    freezeBlocksEnabled = false,
    adminDetectionEnabled = false,
    spectating = false
}

-- Feature Variables
local lastFreecamPos = nil
local camera = Workspace.CurrentCamera
local adminList = {}
local fakeStats = {"Kills: 1000", "Level: 99", "Coins: 99999"}
local currentStatIndex = 1
local spectateTarget = nil
local spectateIndex = 0
local frozenBlocks = {}
local collisionGroupName = "NoPlayerCollision"

-- Saved Positions with Categories
local savedPositions = {
    General = {},
    Spawn = {},
    Checkpoint = {},
    Important = {},
    Custom = {}
}
local positionCategory = "General"

-- Setup Collision Group
pcall(function()
    PhysicsService:CreateCollisionGroup(collisionGroupName)
    PhysicsService:CollisionGroupSetCollidable(collisionGroupName, "Default", false)
end)

-- Category Button Creation
local function createCategoryButtons()
    -- Clear existing buttons first
    for _, child in pairs(sidebar:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    for i, category in ipairs(categories) do
        local button = Instance.new("TextButton", sidebar)
        button.Size = UDim2.new(1, -10, 0, 35)
        button.Position = UDim2.new(0, 5, 0, 5 + (i-1)*40)
        button.BackgroundColor3 = category == currentCategory and Color3.fromRGB(60, 100, 60) or Color3.fromRGB(30, 30, 30)
        button.Text = category
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 11
        button.Font = Enum.Font.SourceSansBold
        button.ZIndex = 12
        
        local buttonCorner = Instance.new("UICorner", button)
        buttonCorner.CornerRadius = UDim.new(0, 4)
        
        local buttonStroke = Instance.new("UIStroke", button)
        buttonStroke.Color = category == currentCategory and Color3.fromRGB(80, 120, 80) or Color3.fromRGB(50, 50, 50)
        buttonStroke.Thickness = 1
        
        categoryButtons[category] = button
        
        button.MouseButton1Click:Connect(function()
            currentCategory = category
            -- Recreate all buttons with updated colors
            createCategoryButtons()
            loadCategoryContent(category)
        end)
    end
end

-- Button Creation Helper
local function createButton(parent, text, callback, enabled)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 230, 0, 30)
    button.Position = UDim2.new(0, 10, 0, #parent:GetChildren() * 35 + 10)
    button.BackgroundColor3 = enabled and Color3.fromRGB(60, 100, 60) or Color3.fromRGB(40, 40, 40)
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 11
    button.Font = Enum.Font.SourceSans
    button.ZIndex = 12
    button.Parent = parent
    
    local buttonCorner = Instance.new("UICorner", button)
    buttonCorner.CornerRadius = UDim.new(0, 4)
    
    local buttonStroke = Instance.new("UIStroke", button)
    buttonStroke.Color = enabled and Color3.fromRGB(80, 120, 80) or Color3.fromRGB(60, 60, 60)
    buttonStroke.Thickness = 1
    
    button.MouseButton1Click:Connect(callback)
    
    -- Update canvas size for scrolling
    parent.CanvasSize = UDim2.new(0, 0, 0, #parent:GetChildren() * 35 + 20)
    
    return button
end

-- Spectate Functions
local function updateSpectate(target)
    if featureStates.spectating and target and target.Character and target.Character:FindFirstChild("Humanoid") then
        camera.CameraType = Enum.CameraType.Follow
        camera.CameraSubject = target.Character.Humanoid
        spectateTarget = target
        notify("Spectating " .. target.Name)
    else
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        featureStates.spectating = false
        spectateTarget = nil
        notify("Spectate Stopped")
    end
end

-- Feature Functions
local function toggleSpeed()
    featureStates.speedEnabled = not featureStates.speedEnabled
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        local humanoid = LocalPlayer.Character.Humanoid
        humanoid.WalkSpeed = featureStates.speedEnabled and 100 or 16
        notify(featureStates.speedEnabled and "Speed Enabled" or "Speed Disabled")
    end
end

local function toggleJump()
    featureStates.jumpEnabled = not featureStates.jumpEnabled
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        local humanoid = LocalPlayer.Character.Humanoid
        humanoid.JumpPower = featureStates.jumpEnabled and 100 or 50
        notify(featureStates.jumpEnabled and "Jump Power Enabled" or "Jump Power Disabled")
    end
end

local function toggleNoclip()
    featureStates.noclipEnabled = not featureStates.noclipEnabled
    featureStates.wallClimbEnabled = false
    featureStates.noPlayerCollisionEnabled = false
    notify(featureStates.noclipEnabled and "Noclip Enabled" or "Noclip Disabled")
    
    if featureStates.noclipEnabled then
        local connection
        connection = RunService.Stepped:Connect(function()
            if featureStates.noclipEnabled and LocalPlayer.Character then
                for _, part in pairs(LocalPlayer.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            else
                connection:Disconnect()
            end
        end)
        addToCleanup(connection)
    end
end

-- Content Loader
local function loadCategoryContent(category)
    -- Clear content frame
    for _, child in pairs(contentFrame:GetChildren()) do
        if not child:IsA("UICorner") then
            child:Destroy()
        end
    end
    
    -- Reset canvas position and size
    contentFrame.CanvasPosition = Vector2.new(0, 0)
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    
    if category == "Movement" then
        createButton(contentFrame, "🛫 Toggle Fly/Freecam", function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                featureStates.freecamEnabled = not featureStates.freecamEnabled
                featureStates.wallClimbEnabled = false
                featureStates.noPlayerCollisionEnabled = false
                if featureStates.freecamEnabled then
                    lastFreecamPos = LocalPlayer.Character.HumanoidRootPart.Position
                    camera.CameraType = Enum.CameraType.Scriptable
                    notify("Fly/Freecam Enabled")
                    local connection = RunService.RenderStepped:Connect(function()
                        if featureStates.freecamEnabled then
                            local moveVector = Vector3.new()
                            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                                moveVector = moveVector + camera.CFrame.LookVector * 50
                            end
                            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                                moveVector = moveVector - camera.CFrame.LookVector * 50
                            end
                            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                                moveVector = moveVector - camera.CFrame.RightVector * 50
                            end
                            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                                moveVector = moveVector + camera.CFrame.RightVector * 50
                            end
                            camera.CFrame = camera.CFrame + moveVector * RunService.Heartbeat:Wait()
                        else
                            connection:Disconnect()
                        end
                    end)
                    addToCleanup(connection)
                else
                    camera.CameraType = Enum.CameraType.Custom
                    notify("Fly/Freecam Disabled")
                end
                loadCategoryContent(category) -- Refresh to update button color
            end
        end, featureStates.freecamEnabled)
        
        createButton(contentFrame, "🏃 Toggle Speed", toggleSpeed, featureStates.speedEnabled)
        createButton(contentFrame, "🦘 Toggle Jump Power", toggleJump, featureStates.jumpEnabled)
        createButton(contentFrame, "🚪 Toggle Noclip", toggleNoclip, featureStates.noclipEnabled)
        
        createButton(contentFrame, "🕸️ Toggle Wall Climb", function()
            featureStates.wallClimbEnabled = not featureStates.wallClimbEnabled
            featureStates.noPlayerCollisionEnabled = false
            notify(featureStates.wallClimbEnabled and "Wall Climb Enabled" or "Wall Climb Disabled")
            if featureStates.wallClimbEnabled then
                local connection = RunService.Stepped:Connect(function()
                    if featureStates.wallClimbEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = LocalPlayer.Character.HumanoidRootPart
                        local ray = Ray.new(hrp.Position, hrp.CFrame.LookVector * 2)
                        local hit, pos = Workspace:FindPartOnRay(ray, LocalPlayer.Character)
                        if hit and UserInputService:IsKeyDown(Enum.KeyCode.W) then
                            hrp.Velocity = Vector3.new(0, 50, 0)
                        end
                    else
                        connection:Disconnect()
                    end
                end)
                addToCleanup(connection)
            end
            loadCategoryContent(category)
        end, featureStates.wallClimbEnabled)
        
        createButton(contentFrame, "👻 Toggle No Player Collision", function()
            featureStates.noPlayerCollisionEnabled = not featureStates.noPlayerCollisionEnabled
            featureStates.wallClimbEnabled = false
            if featureStates.noPlayerCollisionEnabled then
                if LocalPlayer.Character then
                    for _, part in pairs(LocalPlayer.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            pcall(function()
                                PhysicsService:SetPartCollisionGroup(part, collisionGroupName)
                            end)
                        end
                    end
                end
                notify("No Player Collision Enabled")
            else
                if LocalPlayer.Character then
                    for _, part in pairs(LocalPlayer.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            pcall(function()
                                PhysicsService:SetPartCollisionGroup(part, "Default")
                            end)
                        end
                    end
                end
                notify("No Player Collision Disabled")
            end
            loadCategoryContent(category)
        end, featureStates.noPlayerCollisionEnabled)
        
    elseif category == "Teleport" then
        createButton(contentFrame, "🚪 Teleport to Spawn", function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, 10, 0)
                notify("Teleported to Spawn")
            end
        end)
        
        createButton(contentFrame, "💾 Save Current Position", function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local pos = LocalPlayer.Character.HumanoidRootPart.Position
                table.insert(savedPositions[positionCategory], {pos = pos, name = "Pos " .. #savedPositions[positionCategory] + 1})
                notify("Saved to " .. positionCategory)
            end
        end)
        
        createButton(contentFrame, "📍 Show Position List", function()
            -- Clear content frame
            for _, child in pairs(contentFrame:GetChildren()) do
                if not child:IsA("UICorner") then
                    child:Destroy()
                end
            end
            contentFrame.CanvasPosition = Vector2.new(0, 0)
            contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
            
            for cat, positions in pairs(savedPositions) do
                if #positions > 0 then
                    createButton(contentFrame, cat .. " (" .. #positions .. ")", function()
                        -- Clear content frame
                        for _, child in pairs(contentFrame:GetChildren()) do
                            if not child:IsA("UICorner") then
                                child:Destroy()
                            end
                        end
                        contentFrame.CanvasPosition = Vector2.new(0, 0)
                        contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
                        
                        for i, posData in ipairs(positions) do
                            createButton(contentFrame, "📍 " .. posData.name, function()
                                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(posData.pos)
                                    notify("Teleported to " .. posData.name)
                                end
                            end)
                        end
                        createButton(contentFrame, "🔙 Back", function()
                            loadCategoryContent("Teleport")
                        end)
                    end)
                end
            end
        end)
        
        createButton(contentFrame, "📍 Teleport to Last Freecam", function()
            if lastFreecamPos and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(lastFreecamPos)
                notify("Teleported to Last Freecam Position")
            else
                notify("No Freecam Position Saved")
            end
        end)
        
    elseif category == "Player" then
        createButton(contentFrame, "👥 Show Player List", function()
            -- Clear content frame
            for _, child in pairs(contentFrame:GetChildren()) do
                if not child:IsA("UICorner") then
                    child:Destroy()
                end
            end
            contentFrame.CanvasPosition = Vector2.new(0, 0)
            contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
            
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    createButton(contentFrame, "👤 " .. player.Name, function()
                        if LocalPlayer.Character and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                            LocalPlayer.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame
                            notify("Teleported to " .. player.Name)
                        end
                    end)
                end
            end
            createButton(contentFrame, "🔙 Back", function()
                loadCategoryContent("Player")
            end)
        end)
        
        createButton(contentFrame, "👁️ Toggle Spectate", function()
            featureStates.spectating = not featureStates.spectating
            if featureStates.spectating then
                local playerList = Players:GetPlayers()
                if #playerList > 1 then
                    spectateIndex = (spectateIndex % #playerList) + 1
                    if playerList[spectateIndex] == LocalPlayer then
                        spectateIndex = (spectateIndex % #playerList) + 1
                    end
                    updateSpectate(playerList[spectateIndex])
                end
            else
                updateSpectate(nil)
            end
            loadCategoryContent(category)
        end, featureStates.spectating)
        
        createButton(contentFrame, "⏮️ Previous Player", function()
            if featureStates.spectating then
                local playerList = Players:GetPlayers()
                spectateIndex = spectateIndex - 1
                if spectateIndex < 1 then spectateIndex = #playerList end
                if playerList[spectateIndex] == LocalPlayer then
                    spectateIndex = spectateIndex - 1
                    if spectateIndex < 1 then spectateIndex = #playerList end
                end
                updateSpectate(playerList[spectateIndex])
            else
                notify("Spectate not active")
            end
        end)
        
        createButton(contentFrame, "⏭️ Next Player", function()
            if featureStates.spectating then
                local playerList = Players:GetPlayers()
                spectateIndex = (spectateIndex % #playerList) + 1
                if playerList[spectateIndex] == LocalPlayer then
                    spectateIndex = (spectateIndex % #playerList) + 1
                end
                updateSpectate(playerList[spectateIndex])
            else
                notify("Spectate not active")
            end
        end)
        
    elseif category == "Misc" then
        createButton(contentFrame, "🛡️ Toggle God Mode", function()
            featureStates.godModeEnabled = not featureStates.godModeEnabled
            if featureStates.godModeEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                local humanoid = LocalPlayer.Character.Humanoid
                humanoid.MaxHealth = math.huge
                humanoid.Health = math.huge
                notify("God Mode Enabled")
            else
                notify("God Mode Disabled")
            end
            loadCategoryContent(category)
        end, featureStates.godModeEnabled)
        
        createButton(contentFrame, "📊 Toggle Fake Stats", function()
            featureStates.fakeStatsEnabled = not featureStates.fakeStatsEnabled
            if featureStates.fakeStatsEnabled then
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") then
                    local billboard = Instance.new("BillboardGui", LocalPlayer.Character.Head)
                    billboard.Size = UDim2.new(0, 100, 0, 50)
                    billboard.StudsOffset = Vector3.new(0, 3, 0)
                    billboard.ZIndex = 10
                    local statLabel = Instance.new("TextLabel", billboard)
                    statLabel.Size = UDim2.new(1, 0, 1, 0)
                    statLabel.BackgroundTransparency = 1
                    statLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    statLabel.TextSize = 14
                    statLabel.Text = fakeStats[currentStatIndex]
                    statLabel.ZIndex = 10
                    spawn(function()
                        while featureStates.fakeStatsEnabled do
                            currentStatIndex = (currentStatIndex % #fakeStats) + 1
                            if statLabel and statLabel.Parent then
                                statLabel.Text = fakeStats[currentStatIndex]
                            end
                            wait(3)
                        end
                    end)
                end
                notify("Fake Stats Enabled")
            else
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") then
                    local billboard = LocalPlayer.Character.Head:FindFirstChild("BillboardGui")
                    if billboard then billboard:Destroy() end
                end
                notify("Fake Stats Disabled")
            end
            loadCategoryContent(category)
        end, featureStates.fakeStatsEnabled)
        
        createButton(contentFrame, "🧊 Toggle Freeze Blocks", function()
            featureStates.freezeBlocksEnabled = not featureStates.freezeBlocksEnabled
            if featureStates.freezeBlocksEnabled then
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and not obj.Anchored and obj.Velocity.Magnitude > 0 then
                        table.insert(frozenBlocks, {part = obj, originalVelocity = obj.Velocity})
                        obj.Velocity = Vector3.new(0, 0, 0)
                        obj.Anchored = true
                    end
                end
                notify("Moving Blocks Frozen")
            else
                for _, block in pairs(frozenBlocks) do
                    if block.part and block.part.Parent then
                        block.part.Anchored = false
                        block.part.Velocity = block.originalVelocity
                    end
                end
                frozenBlocks = {}
                notify("Moving Blocks Unfrozen")
            end
            loadCategoryContent(category)
        end, featureStates.freezeBlocksEnabled)
        
        createButton(contentFrame, "🛡️ Toggle Admin Detection", function()
            featureStates.adminDetectionEnabled = not featureStates.adminDetectionEnabled
            notify(featureStates.adminDetectionEnabled and "Admin Detection Enabled" or "Admin Detection Disabled")
            if featureStates.adminDetectionEnabled then
                local connection = Players.PlayerAdded:Connect(function(player)
                    pcall(function()
                        local role = player:GetRoleInGroup(game.GroupId or 0)
                        if role == "Admin" or role == "Moderator" or role == "Owner" then
                            if not table.find(adminList, player.Name) then
                                table.insert(adminList, player.Name)
                                notify("⚠️ Admin Detected: " .. player.Name)
                            end
                        end
                    end)
                end)
                addToCleanup(connection)
            end
            loadCategoryContent(category)
        end, featureStates.adminDetectionEnabled)
        
        createButton(contentFrame, "📜 Show Admin List", function()
            -- Clear content frame
            for _, child in pairs(contentFrame:GetChildren()) do
                if not child:IsA("UICorner") then
                    child:Destroy()
                end
            end
            contentFrame.CanvasPosition = Vector2.new(0, 0)
            contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
            
            if #adminList > 0 then
                for i, admin in ipairs(adminList) do
                    createButton(contentFrame, "⚠️ Admin: " .. admin, function() end)
                end
            else
                createButton(contentFrame, "No Admins Detected", function() end)
            end
            createButton(contentFrame, "🔙 Back", function()
                loadCategoryContent("Misc")
            end)
        end)
        
        createButton(contentFrame, "🔄 Reset All Features", function()
            -- Reset all features
            featureStates = {
                freecamEnabled = false,
                speedEnabled = false,
                jumpEnabled = false,
                noclipEnabled = false,
                wallClimbEnabled = false,
                noPlayerCollisionEnabled = false,
                godModeEnabled = false,
                fakeStatsEnabled = false,
                freezeBlocksEnabled = false,
                adminDetectionEnabled = false,
                spectating = false
            }
            
            -- Reset character properties
            if LocalPlayer.Character then
                local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid.WalkSpeed = 16
                    humanoid.JumpPower = 50
                    humanoid.MaxHealth = 100
                    humanoid.Health = 100
                end
                
                -- Reset collision
                for _, part in pairs(LocalPlayer.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                        pcall(function()
                            PhysicsService:SetPartCollisionGroup(part, "Default")
                        end)
                    end
                end
                
                -- Remove fake stats
                local head = LocalPlayer.Character:FindFirstChild("Head")
                if head then
                    local billboard = head:FindFirstChild("BillboardGui")
                    if billboard then billboard:Destroy() end
                end
            end
            
            -- Reset camera
            camera.CameraType = Enum.CameraType.Custom
            camera.CameraSubject = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
            
            -- Unfreeze blocks
            for _, block in pairs(frozenBlocks) do
                if block.part and block.part.Parent then
                    block.part.Anchored = false
                    block.part.Velocity = block.originalVelocity
                end
            end
            frozenBlocks = {}
            
            -- Clean up connections
            cleanupAll()
            
            notify("All Features Reset")
            loadCategoryContent(category)
        end)
    end
end

-- Auto-apply persistent features on character spawn
local function applyPersistentFeatures()
    wait(1) -- Wait for character to fully load
    
    if featureStates.speedEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = 100
    end
    
    if featureStates.jumpEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.JumpPower = 100
    end
    
    if featureStates.godModeEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        local humanoid = LocalPlayer.Character.Humanoid
        humanoid.MaxHealth = math.huge
        humanoid.Health = math.huge
    end
    
    if featureStates.noPlayerCollisionEnabled and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetChildren()) do
            if part:IsA("BasePart") then
                pcall(function()
                    PhysicsService:SetPartCollisionGroup(part, collisionGroupName)
                end)
            end
        end
    end
    
    if featureStates.fakeStatsEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") then
        local billboard = Instance.new("BillboardGui", LocalPlayer.Character.Head)
        billboard.Size = UDim2.new(0, 100, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.ZIndex = 10
        local statLabel = Instance.new("TextLabel", billboard)
        statLabel.Size = UDim2.new(1, 0, 1, 0)
        statLabel.BackgroundTransparency = 1
        statLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        statLabel.TextSize = 14
        statLabel.Text = fakeStats[currentStatIndex]
        statLabel.ZIndex = 10
        spawn(function()
            while featureStates.fakeStatsEnabled and statLabel and statLabel.Parent do
                currentStatIndex = (currentStatIndex % #fakeStats) + 1
                statLabel.Text = fakeStats[currentStatIndex]
                wait(3)
            end
        end)
    end
end

-- Connect character spawn events
addToCleanup(LocalPlayer.CharacterAdded:Connect(function()
    applyPersistentFeatures()
end))

-- Initialize
createCategoryButtons()
loadCategoryContent("Movement")

-- Auto-save positions (if supported)
pcall(function()
    if readfile and isfile("positions.txt") then
        local saveData = game:GetService("HttpService"):JSONDecode(readfile("positions.txt"))
        for cat, positions in pairs(saveData) do
            if savedPositions[cat] then
                savedPositions[cat] = positions
            end
        end
    end
end)

-- Save positions on shutdown
game:BindToClose(function()
    pcall(function()
        if writefile then
            local saveData = {}
            for cat, positions in pairs(savedPositions) do
                saveData[cat] = positions
            end
            writefile("positions.txt", game:GetService("HttpService"):JSONEncode(saveData))
        end
    end)
end)

-- Hotkeys
addToCleanup(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.Insert then
        isMinimized = not isMinimized
        if isMinimized then
            mainFrame.Visible = false
            mainButton.Visible = true
        else
            mainFrame.Visible = true
            mainButton.Visible = false
        end
    elseif input.KeyCode == Enum.KeyCode.Delete then
        cleanupAll()
        gui:Destroy()
    end
end))

notify("Enhanced GUI Loaded - Insert: Toggle | Delete: Close")