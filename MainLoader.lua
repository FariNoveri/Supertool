-- Modern Minimal Roblox GUI Script untuk Android dengan Kategori (KRNL Compatible)
-- Redesigned dengan desain hitam minimalis dan fitur Player Phase

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Variabel untuk fitur
local flyEnabled = false
local noclipEnabled = false
local speedEnabled = false
local jumpHighEnabled = false
local godModeEnabled = false
local fullbrightEnabled = false
local antiAFKEnabled = false
local spiderEnabled = false
local freecamEnabled = false
local playerPhaseEnabled = false

local savedPosition = nil
local spectateIndex = 1
local selectedPlayer = nil
local currentCategory = "Movement"
local playerListVisible = false

-- Connections
local connections = {}

-- GUI Creation
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local TopBar = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local Logo = Instance.new("TextLabel")
local MinimizeButton = Instance.new("TextButton")

-- Category System
local CategoryFrame = Instance.new("Frame")
local CategoryList = Instance.new("UIListLayout")
local ContentFrame = Instance.new("Frame")
local ScrollFrame = Instance.new("ScrollingFrame")
local UIListLayout = Instance.new("UIListLayout")

-- Player Selection System
local PlayerListFrame = Instance.new("Frame")
local PlayerListScrollFrame = Instance.new("ScrollingFrame")
local PlayerListLayout = Instance.new("UIListLayout")
local SelectedPlayerLabel = Instance.new("TextLabel")

local LogoButton = Instance.new("TextButton")

-- GUI Properties
ScreenGui.Name = "MinimalHackGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Main Frame (horizontal layout)
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
MainFrame.BorderSizePixel = 1
MainFrame.Position = UDim2.new(0.05, 0, 0.1, 0)
MainFrame.Size = UDim2.new(0, 600, 0, 400)
MainFrame.Active = true
MainFrame.Draggable = true

-- Top Bar
TopBar.Name = "TopBar"
TopBar.Parent = MainFrame
TopBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
TopBar.BorderSizePixel = 0
TopBar.Position = UDim2.new(0, 0, 0, 0)
TopBar.Size = UDim2.new(1, 0, 0, 35)

-- Logo di TopBar (minimalis)
Logo.Name = "Logo"
Logo.Parent = TopBar
Logo.BackgroundTransparency = 1
Logo.Position = UDim2.new(0, 10, 0, 5)
Logo.Size = UDim2.new(0, 25, 0, 25)
Logo.Font = Enum.Font.GothamBold
Logo.Text = "H"
Logo.TextColor3 = Color3.fromRGB(255, 255, 255)
Logo.TextScaled = true

-- Title
Title.Name = "Title"
Title.Parent = TopBar
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 45, 0, 0)
Title.Size = UDim2.new(1, -90, 1, 0)
Title.Font = Enum.Font.Gotham
Title.Text = "HACK"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Minimize Button
MinimizeButton.Name = "MinimizeButton"
MinimizeButton.Parent = TopBar
MinimizeButton.BackgroundTransparency = 1
MinimizeButton.Position = UDim2.new(1, -30, 0, 5)
MinimizeButton.Size = UDim2.new(0, 25, 0, 25)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "_"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextSize = 16

-- Category Frame (Panel Kiri - lebih kecil)
CategoryFrame.Name = "CategoryFrame"
CategoryFrame.Parent = MainFrame
CategoryFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
CategoryFrame.BorderSizePixel = 0
CategoryFrame.Position = UDim2.new(0, 0, 0, 35)
CategoryFrame.Size = UDim2.new(0, 140, 1, -35)

-- Category List Layout
CategoryList.Parent = CategoryFrame
CategoryList.Padding = UDim.new(0, 2)
CategoryList.SortOrder = Enum.SortOrder.LayoutOrder

-- Content Frame (Panel Kanan)
ContentFrame.Name = "ContentFrame"
ContentFrame.Parent = MainFrame
ContentFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
ContentFrame.BorderSizePixel = 0
ContentFrame.Position = UDim2.new(0, 140, 0, 35)
ContentFrame.Size = UDim2.new(1, -140, 1, -35)

-- ScrollFrame di Content
ScrollFrame.Name = "ScrollFrame"
ScrollFrame.Parent = ContentFrame
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.Position = UDim2.new(0, 10, 0, 10)
ScrollFrame.Size = UDim2.new(1, -20, 1, -20)
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
ScrollFrame.BorderSizePixel = 0

-- UIListLayout untuk content
UIListLayout.Parent = ScrollFrame
UIListLayout.Padding = UDim.new(0, 3)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Player Selection Frame
PlayerListFrame.Name = "PlayerListFrame"
PlayerListFrame.Parent = ScreenGui
PlayerListFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
PlayerListFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
PlayerListFrame.BorderSizePixel = 1
PlayerListFrame.Position = UDim2.new(0.5, -150, 0.2, 0)
PlayerListFrame.Size = UDim2.new(0, 300, 0, 350)
PlayerListFrame.Visible = false
PlayerListFrame.Active = true
PlayerListFrame.Draggable = true

-- Player List Title
local PlayerListTitle = Instance.new("TextLabel")
PlayerListTitle.Name = "Title"
PlayerListTitle.Parent = PlayerListFrame
PlayerListTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
PlayerListTitle.BorderSizePixel = 0
PlayerListTitle.Position = UDim2.new(0, 0, 0, 0)
PlayerListTitle.Size = UDim2.new(1, 0, 0, 35)
PlayerListTitle.Font = Enum.Font.Gotham
PlayerListTitle.Text = "SELECT PLAYER"
PlayerListTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
PlayerListTitle.TextSize = 12

-- Close Button untuk Player List
local ClosePlayerListButton = Instance.new("TextButton")
ClosePlayerListButton.Name = "CloseButton"
ClosePlayerListButton.Parent = PlayerListFrame
ClosePlayerListButton.BackgroundTransparency = 1
ClosePlayerListButton.Position = UDim2.new(1, -30, 0, 5)
ClosePlayerListButton.Size = UDim2.new(0, 25, 0, 25)
ClosePlayerListButton.Font = Enum.Font.GothamBold
ClosePlayerListButton.Text = "X"
ClosePlayerListButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ClosePlayerListButton.TextSize = 12

-- Selected Player Display
SelectedPlayerLabel.Name = "SelectedPlayerLabel"
SelectedPlayerLabel.Parent = PlayerListFrame
SelectedPlayerLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
SelectedPlayerLabel.BorderSizePixel = 0
SelectedPlayerLabel.Position = UDim2.new(0, 10, 0, 45)
SelectedPlayerLabel.Size = UDim2.new(1, -20, 0, 25)
SelectedPlayerLabel.Font = Enum.Font.Gotham
SelectedPlayerLabel.Text = "SELECTED: NONE"
SelectedPlayerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SelectedPlayerLabel.TextSize = 10

-- Player List ScrollFrame
PlayerListScrollFrame.Name = "PlayerListScrollFrame"
PlayerListScrollFrame.Parent = PlayerListFrame
PlayerListScrollFrame.BackgroundTransparency = 1
PlayerListScrollFrame.Position = UDim2.new(0, 10, 0, 80)
PlayerListScrollFrame.Size = UDim2.new(1, -20, 1, -90)
PlayerListScrollFrame.ScrollBarThickness = 4
PlayerListScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
PlayerListScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
PlayerListScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
PlayerListScrollFrame.BorderSizePixel = 0

-- Player List Layout
PlayerListLayout.Parent = PlayerListScrollFrame
PlayerListLayout.Padding = UDim.new(0, 2)
PlayerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
PlayerListLayout.FillDirection = Enum.FillDirection.Vertical

-- Logo Button (minimized state)
LogoButton.Name = "LogoButton"
LogoButton.Parent = ScreenGui
LogoButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
LogoButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
LogoButton.BorderSizePixel = 1
LogoButton.Position = UDim2.new(0.05, 0, 0.1, 0)
LogoButton.Size = UDim2.new(0, 40, 0, 40)
LogoButton.Font = Enum.Font.GothamBold
LogoButton.Text = "H"
LogoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoButton.TextSize = 16
LogoButton.Visible = false
LogoButton.Active = true
LogoButton.Draggable = true

-- Feature Functions

-- Player Phase (nembus player lain)
local function togglePlayerPhase(enabled)
    playerPhaseEnabled = enabled
    if enabled then
        connections.playerphase = RunService.Heartbeat:Connect(function()
            if playerPhaseEnabled and character then
                for _, otherPlayer in pairs(Players:GetPlayers()) do
                    if otherPlayer ~= player and otherPlayer.Character then
                        for _, part in pairs(otherPlayer.Character:GetChildren()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                            end
                        end
                    end
                end
            end
        end)
    else
        if connections.playerphase then
            connections.playerphase:Disconnect()
        end
        -- Reset collision untuk semua player
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= player and otherPlayer.Character then
                for _, part in pairs(otherPlayer.Character:GetChildren()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end
    end
end

-- Fly (3D Movement dengan kamera)
local function toggleFly(enabled)
    flyEnabled = enabled
    if enabled then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = rootPart
        
        local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
        bodyAngularVelocity.MaxTorque = Vector3.new(0, math.huge, 0)
        bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
        bodyAngularVelocity.Parent = rootPart
        
        connections.fly = RunService.Heartbeat:Connect(function()
            if flyEnabled then
                local camera = workspace.CurrentCamera
                local moveVector = humanoid.MoveDirection
                
                local cameraCFrame = camera.CFrame
                local forwardVector = cameraCFrame.LookVector
                local rightVector = cameraCFrame.RightVector
                local upVector = cameraCFrame.UpVector
                
                local velocity = Vector3.new(0, 0, 0)
                
                if moveVector.Magnitude > 0 then
                    velocity = velocity + (forwardVector * moveVector.Z * -50)
                    velocity = velocity + (rightVector * moveVector.X * 50)
                end
                
                if humanoid.Jump then
                    velocity = velocity + (upVector * 50)
                    humanoid.Jump = false
                end
                
                bodyVelocity.Velocity = velocity
            end
        end)
    else
        if connections.fly then
            connections.fly:Disconnect()
        end
        if rootPart:FindFirstChild("BodyVelocity") then
            rootPart:FindFirstChild("BodyVelocity"):Destroy()
        end
        if rootPart:FindFirstChild("BodyAngularVelocity") then
            rootPart:FindFirstChild("BodyAngularVelocity"):Destroy()
        end
    end
end

-- Noclip
local function toggleNoclip(enabled)
    noclipEnabled = enabled
    if enabled then
        connections.noclip = RunService.Stepped:Connect(function()
            if noclipEnabled and character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if connections.noclip then
            connections.noclip:Disconnect()
        end
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- Speed
local function toggleSpeed(enabled)
    speedEnabled = enabled
    if enabled then
        humanoid.WalkSpeed = 100
    else
        humanoid.WalkSpeed = 16
    end
end

-- Jump High
local function toggleJumpHigh(enabled)
    jumpHighEnabled = enabled
    if enabled then
        humanoid.JumpHeight = 50
        humanoid.JumpPower = 120
        connections.jumphigh = humanoid.Jumping:Connect(function()
            if jumpHighEnabled then
                rootPart.Velocity = Vector3.new(rootPart.Velocity.X, 120, rootPart.Velocity.Z)
            end
        end)
    else
        humanoid.JumpHeight = 7.2
        humanoid.JumpPower = 50
        if connections.jumphigh then
            connections.jumphigh:Disconnect()
        end
    end
end

-- God Mode
local function toggleGodMode(enabled)
    godModeEnabled = enabled
    if enabled then
        connections.godmode = humanoid.HealthChanged:Connect(function()
            if godModeEnabled then
                humanoid.Health = humanoid.MaxHealth
            end
        end)
    else
        if connections.godmode then
            connections.godmode:Disconnect()
        end
    end
end

-- Anti AFK
local function toggleAntiAFK(enabled)
    antiAFKEnabled = enabled
    if enabled then
        connections.antiafk = game:GetService("Players").LocalPlayer.Idled:Connect(function()
            if antiAFKEnabled then
                game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
                game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
            end
        end)
    else
        if connections.antiafk then
            connections.antiafk:Disconnect()
        end
    end
end

-- Fullbright
local function toggleFullbright(enabled)
    fullbrightEnabled = enabled
    local lighting = game:GetService("Lighting")
    if enabled then
        lighting.Brightness = 2
        lighting.ClockTime = 14
        lighting.FogEnd = 100000
        lighting.GlobalShadows = false
        lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    else
        lighting.Brightness = 1
        lighting.ClockTime = 14
        lighting.FogEnd = 100000
        lighting.GlobalShadows = true
        lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
    end
end

-- Freecam
local freecamPart = nil
local originalCameraSubject = nil
local function toggleFreecam(enabled)
    freecamEnabled = enabled
    if enabled then
        originalCameraSubject = workspace.CurrentCamera.CameraSubject
        
        freecamPart = Instance.new("Part")
        freecamPart.Name = "FreecamPart"
        freecamPart.Anchored = true
        freecamPart.CanCollide = false
        freecamPart.Transparency = 1
        freecamPart.Size = Vector3.new(1, 1, 1)
        freecamPart.CFrame = workspace.CurrentCamera.CFrame
        freecamPart.Parent = workspace
        
        workspace.CurrentCamera.CameraSubject = freecamPart
        
        if rootPart then
            rootPart.Anchored = true
        end
        
        connections.freecam = RunService.Heartbeat:Connect(function()
            if freecamEnabled and freecamPart then
                local camera = workspace.CurrentCamera
                local moveVector = humanoid.MoveDirection
                
                local velocity = Vector3.new(0, 0, 0)
                local speed = 50
                
                if moveVector.Magnitude > 0 then
                    local forwardVector = camera.CFrame.LookVector
                    local rightVector = camera.CFrame.RightVector
                    local upVector = camera.CFrame.UpVector
                    
                    velocity = velocity + (forwardVector * moveVector.Z * -speed)
                    velocity = velocity + (rightVector * moveVector.X * speed)
                end
                
                if humanoid.Jump then
                    velocity = velocity + Vector3.new(0, speed, 0)
                    humanoid.Jump = false
                end
                
                freecamPart.CFrame = freecamPart.CFrame + (velocity * RunService.Heartbeat:Wait())
            end
        end)
    else
        if connections.freecam then
            connections.freecam:Disconnect()
        end
        if freecamPart then
            freecamPart:Destroy()
            freecamPart = nil
        end
        if originalCameraSubject then
            workspace.CurrentCamera.CameraSubject = originalCameraSubject
        else
            workspace.CurrentCamera.CameraSubject = humanoid
        end
        
        if rootPart then
            rootPart.Anchored = false
        end
    end
end

-- Position functions
local function savePosition()
    if rootPart then
        savedPosition = rootPart.CFrame
        print("Position Saved")
    end
end

local function loadPosition()
    if savedPosition and rootPart then
        rootPart.CFrame = savedPosition
        print("Teleported to saved position")
    else
        print("No saved position")
    end
end

-- Player functions
local function showPlayerSelection()
    playerListVisible = true
    PlayerListFrame.Visible = true
    updatePlayerList()
end

local function updatePlayerList()
    for _, child in pairs(PlayerListScrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    local buttonCount = 0
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            local playerButton = Instance.new("TextButton")
            playerButton.Name = p.Name .. "Button"
            playerButton.Parent = PlayerListScrollFrame
            playerButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            playerButton.BorderSizePixel = 0
            playerButton.Size = UDim2.new(1, -5, 0, 30)
            playerButton.Font = Enum.Font.Gotham
            playerButton.Text = p.Name
            playerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            playerButton.TextSize = 12
            playerButton.LayoutOrder = buttonCount
            
            playerButton.MouseButton1Click:Connect(function()
                selectedPlayer = p
                SelectedPlayerLabel.Text = "SELECTED: " .. p.Name:upper()
                PlayerListFrame.Visible = false
                playerListVisible = false
                
                for _, btn in pairs(PlayerListScrollFrame:GetChildren()) do
                    if btn:IsA("TextButton") then
                        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                    end
                end
                playerButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            end)
            
            playerButton.MouseEnter:Connect(function()
                if playerButton.BackgroundColor3 ~= Color3.fromRGB(60, 60, 60) then
                    playerButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                end
            end)
            
            playerButton.MouseLeave:Connect(function()
                if selectedPlayer ~= p then
                    playerButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                end
            end)
            
            buttonCount = buttonCount + 1
        end
    end
    
    wait(0.1)
    local contentSize = PlayerListLayout.AbsoluteContentSize
    PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 10)
end

local function spectateSelectedPlayer()
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("Humanoid") then
        workspace.CurrentCamera.CameraSubject = selectedPlayer.Character.Humanoid
        print("Spectating: " .. selectedPlayer.Name)
    else
        print("Select a player first")
    end
end

local function tpToSelectedPlayer()
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and rootPart then
        rootPart.CFrame = selectedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
        print("Teleported to: " .. selectedPlayer.Name)
    else
        print("Select a player first")
    end
end

local function stopSpectate()
    workspace.CurrentCamera.CameraSubject = humanoid
    print("Stopped spectating")
end

-- Button creation functions
local function createButton(name, callback)
    local button = Instance.new("TextButton")
    button.Name = name .. "Button"
    button.Parent = ScrollFrame
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 30)
    button.Font = Enum.Font.Gotham
    button.Text = name:upper()
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 11
    
    button.MouseButton1Click:Connect(callback)
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    end)
    
    return button
end

local function createToggleButton(name, callback)
    local button = Instance.new("TextButton")
    button.Name = name .. "Button"
    button.Parent = ScrollFrame
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 30)
    button.Font = Enum.Font.Gotham
    button.Text = name:upper() .. " [OFF]"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 11
    
    local isToggled = false
    
    local function updateButton()
        if isToggled then
            button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            button.Text = name:upper() .. " [ON]"
        else
            button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            button.Text = name:upper() .. " [OFF]"
        end
    end
    
    button.MouseButton1Click:Connect(function()
        isToggled = not isToggled
        updateButton()
        callback(isToggled)
    end)
    
    button.MouseEnter:Connect(function()
        if not isToggled then
            button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
    end)
    
    button.MouseLeave:Connect(function()
        updateButton()
    end)
    
    updateButton()
    return button
end

local function createCategoryButton(name)
    local button = Instance.new("TextButton")
    button.Name = name .. "Category"
    button.Parent = CategoryFrame
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 35)
    button.Font = Enum.Font.Gotham
    button.Text = name:upper()
    button.TextColor3 = Color3.fromRGB(200, 200, 200)
    button.TextSize = 10
    
    button.MouseButton1Click:Connect(function()
        switchCategory(name)
    end)
    
    return button
end

local function clearButtons()
    for _, child in pairs(ScrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

-- Category button loaders
local function loadMovementButtons()
    createToggleButton("Fly", toggleFly)
    createToggleButton("Noclip", toggleNoclip)
    createToggleButton("Speed", toggleSpeed)
    createToggleButton("Jump High", toggleJumpHigh)
    createToggleButton("Player Phase", togglePlayerPhase)
end

local function loadPlayerButtons()
    createButton("Select Player", showPlayerSelection)
    createToggleButton("God Mode", toggleGodMode)
    createToggleButton("Anti AFK", toggleAntiAFK)
    createButton("Spectate Selected", spectateSelectedPlayer)
    createButton("Stop Spectate", stopSpectate)
end

local function loadVisualButtons()
    createToggleButton("Fullbright", toggleFullbright)
    createToggleButton("Freecam", toggleFreecam)
end

local function loadTeleportButtons()
    createButton("Save Position", savePosition)
    createButton("Load Position", loadPosition)
    createButton("TP to Selected Player", tpToSelectedPlayer)
end

local function loadUtilityButtons()
    createButton("Disable Previous Script", function()
        for _, gui in pairs(CoreGui:GetChildren()) do
            if gui.Name == "MinimalHackGUI" and gui ~= ScreenGui then
                gui:Destroy()
            end
        end
        print("Previous scripts disabled")
    end)
end

-- Category switching function
function switchCategory(categoryName)
    currentCategory = categoryName
    
    for _, child in pairs(CategoryFrame:GetChildren()) do
        if child:IsA("TextButton") then
            if child.Name == categoryName .. "Category" then
                child.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                child.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                child.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                child.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
    end
    
    clearButtons()
    
    if categoryName == "Movement" then
        loadMovementButtons()
    elseif categoryName == "Player" then
        loadPlayerButtons()
    elseif categoryName == "Visual" then
        loadVisualButtons()
    elseif categoryName == "Teleport" then
        loadTeleportButtons()
    elseif categoryName == "Utility" then
        loadUtilityButtons()
    end
    
    wait(0.1)
    local contentSize = UIListLayout.AbsoluteContentSize
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 10)
end

-- Minimize/Maximize functions
local function minimizeGUI()
    MainFrame.Visible = false
    LogoButton.Visible = true
end

local function maximizeGUI()
    LogoButton.Visible = false
    MainFrame.Visible = true
end

-- Event connections
MinimizeButton.MouseButton1Click:Connect(minimizeGUI)
LogoButton.MouseButton1Click:Connect(maximizeGUI)

-- Player List Close Button
ClosePlayerListButton.MouseButton1Click:Connect(function()
    PlayerListFrame.Visible = false
    playerListVisible = false
end)

-- Create category buttons
createCategoryButton("Movement")
createCategoryButton("Player")
createCategoryButton("Visual")
createCategoryButton("Teleport")
createCategoryButton("Utility")

-- Initialize with Movement category
wait(0.5)
switchCategory("Movement")

-- Character respawn handling
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Reset all toggles
    flyEnabled = false
    noclipEnabled = false
    speedEnabled = false
    jumpHighEnabled = false
    godModeEnabled = false
    antiAFKEnabled = false
    freecamEnabled = false
    playerPhaseEnabled = false
    
    -- Disconnect all connections
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    connections = {}
    
    -- Reset character properties
    if rootPart then
        rootPart.Anchored = false
    end
    
    print("Character respawned - features reset")
end)

-- Player cleanup untuk Player Phase
Players.PlayerRemoving:Connect(function(removedPlayer)
    if removedPlayer == selectedPlayer then
        selectedPlayer = nil
        SelectedPlayerLabel.Text = "SELECTED: NONE"
    end
end)

print("=== MINIMAL HACK GUI LOADED ===")
print("Movement | Player | Visual | Teleport | Utility")
print("Player Phase: Nembus semua player lain")
print("GUI siap digunakan!")