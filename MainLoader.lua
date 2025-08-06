-- Modern Minimal Roblox GUI Script untuk Android dengan Kategori (KRNL Compatible) - FIXED VERSION
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

-- AUTO-DISABLE PREVIOUS SCRIPTS
for _, gui in pairs(CoreGui:GetChildren()) do
    if gui.Name == "MinimalHackGUI" then
        gui:Destroy()
        print("Previous MinimalHackGUI removed")
    end
end

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
local flashlightEnabled = false

local savedPositions = {}
local selectedPlayer = nil
local currentCategory = "Movement"
local playerListVisible = false
local guiMinimized = false

-- Connections
local connections = {}
local buttonStates = {}

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

-- Position Save System
local PositionFrame = Instance.new("Frame")
local PositionScrollFrame = Instance.new("ScrollingFrame")
local PositionLayout = Instance.new("UIListLayout")
local PositionInput = Instance.new("TextBox")
local SavePositionButton = Instance.new("TextButton")

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

-- Position Save Frame
PositionFrame.Name = "PositionFrame"
PositionFrame.Parent = ScreenGui
PositionFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
PositionFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
PositionFrame.BorderSizePixel = 1
PositionFrame.Position = UDim2.new(0.3, 0, 0.2, 0)
PositionFrame.Size = UDim2.new(0, 350, 0, 400)
PositionFrame.Visible = false
PositionFrame.Active = true
PositionFrame.Draggable = true

-- Position Frame Title
local PositionTitle = Instance.new("TextLabel")
PositionTitle.Name = "Title"
PositionTitle.Parent = PositionFrame
PositionTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
PositionTitle.BorderSizePixel = 0
PositionTitle.Position = UDim2.new(0, 0, 0, 0)
PositionTitle.Size = UDim2.new(1, 0, 0, 35)
PositionTitle.Font = Enum.Font.Gotham
PositionTitle.Text = "SAVED POSITIONS"
PositionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
PositionTitle.TextSize = 12

-- Close Position Frame Button
local ClosePositionButton = Instance.new("TextButton")
ClosePositionButton.Name = "CloseButton"
ClosePositionButton.Parent = PositionFrame
ClosePositionButton.BackgroundTransparency = 1
ClosePositionButton.Position = UDim2.new(1, -30, 0, 5)
ClosePositionButton.Size = UDim2.new(0, 25, 0, 25)
ClosePositionButton.Font = Enum.Font.GothamBold
ClosePositionButton.Text = "X"
ClosePositionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ClosePositionButton.TextSize = 12

-- Position Input
PositionInput.Name = "PositionInput"
PositionInput.Parent = PositionFrame
PositionInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
PositionInput.BorderSizePixel = 0
PositionInput.Position = UDim2.new(0, 10, 0, 45)
PositionInput.Size = UDim2.new(1, -90, 0, 30)
PositionInput.Font = Enum.Font.Gotham
PositionInput.PlaceholderText = "Enter position name..."
PositionInput.Text = ""
PositionInput.TextColor3 = Color3.fromRGB(255, 255, 255)
PositionInput.TextSize = 11

-- Save Position Button
SavePositionButton.Name = "SavePositionButton"
SavePositionButton.Parent = PositionFrame
SavePositionButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
SavePositionButton.BorderSizePixel = 0
SavePositionButton.Position = UDim2.new(1, -70, 0, 45)
SavePositionButton.Size = UDim2.new(0, 60, 0, 30)
SavePositionButton.Font = Enum.Font.Gotham
SavePositionButton.Text = "SAVE"
SavePositionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SavePositionButton.TextSize = 10

-- Position ScrollFrame
PositionScrollFrame.Name = "PositionScrollFrame"
PositionScrollFrame.Parent = PositionFrame
PositionScrollFrame.BackgroundTransparency = 1
PositionScrollFrame.Position = UDim2.new(0, 10, 0, 85)
PositionScrollFrame.Size = UDim2.new(1, -20, 1, -95)
PositionScrollFrame.ScrollBarThickness = 4
PositionScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
PositionScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
PositionScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
PositionScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
PositionScrollFrame.BorderSizePixel = 0

-- Position Layout
PositionLayout.Parent = PositionScrollFrame
PositionLayout.Padding = UDim.new(0, 2)
PositionLayout.SortOrder = Enum.SortOrder.LayoutOrder
PositionLayout.FillDirection = Enum.FillDirection.Vertical

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

-- Flashlight
local flashlightPart = nil
local function toggleFlashlight(enabled)
    flashlightEnabled = enabled
    if enabled then
        if character and character:FindFirstChild("Head") then
            flashlightPart = Instance.new("PointLight")
            flashlightPart.Name = "Flashlight"
            flashlightPart.Brightness = 5
            flashlightPart.Range = 100
            flashlightPart.Color = Color3.fromRGB(255, 255, 255)
            flashlightPart.Parent = character.Head
        end
    else
        if flashlightPart then
            flashlightPart:Destroy()
            flashlightPart = nil
        elseif character and character:FindFirstChild("Head") and character.Head:FindFirstChild("Flashlight") then
            character.Head.Flashlight:Destroy()
        end
    end
end

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

-- Fly (Android Touch Controls)
local function toggleFly(enabled)
    flyEnabled = enabled
    if enabled then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = rootPart
        
        connections.fly = RunService.Heartbeat:Connect(function()
            if flyEnabled then
                local camera = workspace.CurrentCamera
                local moveVector = humanoid.MoveDirection
                
                -- Get camera direction
                local cameraCFrame = camera.CFrame
                local forwardVector = cameraCFrame.LookVector
                local rightVector = cameraCFrame.RightVector
                local upVector = Vector3.new(0, 1, 0)
                
                local velocity = Vector3.new(0, 0, 0)
                local speed = 50
                
                -- Movement berdasarkan virtual thumbstick Android
                if moveVector.Magnitude > 0 then
                    -- Forward/Backward (thumbstick up/down)
                    velocity = velocity + (forwardVector * -moveVector.Z * speed)
                    -- Left/Right (thumbstick left/right)  
                    velocity = velocity + (rightVector * moveVector.X * speed)
                end
                
                -- Jump button Android untuk naik
                if humanoid.Jump then
                    velocity = velocity + (upVector * speed)
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

-- Freecam (Android Touch Controls) - FIXED V2
local freecamPart = nil
local originalCameraSubject = nil
local freecamPosition = nil
local function toggleFreecam(enabled)
    freecamEnabled = enabled
    if enabled then
        originalCameraSubject = workspace.CurrentCamera.CameraSubject
        freecamPosition = workspace.CurrentCamera.CFrame.Position
        
        freecamPart = Instance.new("Part")
        freecamPart.Name = "FreecamPart"
        freecamPart.Anchored = true
        freecamPart.CanCollide = false
        freecamPart.Transparency = 1
        freecamPart.Size = Vector3.new(1, 1, 1)
        freecamPart.CFrame = workspace.CurrentCamera.CFrame
        freecamPart.Parent = workspace
        
        workspace.CurrentCamera.CameraSubject = freecamPart
        
        -- Freeze character
        if rootPart then
            rootPart.Anchored = true
        end
        
        connections.freecam = RunService.RenderStepped:Connect(function(deltaTime)
            if freecamEnabled and freecamPart then
                local camera = workspace.CurrentCamera
                local moveVector = humanoid.MoveDirection
                
                -- Get camera direction vectors
                local cameraCFrame = camera.CFrame
                local forwardVector = cameraCFrame.LookVector
                local rightVector = cameraCFrame.RightVector
                local upVector = Vector3.new(0, 1, 0) -- World up vector
                
                local movement = Vector3.new(0, 0, 0)
                local speed = 80
                
                -- WASD/Thumbstick movement (FIXED: proper directions)
                if moveVector.Magnitude > 0 then
                    -- Forward/Backward movement
                    movement = movement + (forwardVector * moveVector.Z * speed)
                    -- Left/Right movement
                    movement = movement + (rightVector * -moveVector.X * speed)
                end
                
                -- Jump button untuk naik
                if humanoid.Jump then
                    movement = movement + (upVector * speed)
                    humanoid.Jump = false
                end
                
                -- Apply movement with deltaTime for smooth motion
                local newPosition = freecamPart.Position + (movement * deltaTime)
                
                -- Update freecam part position while maintaining camera rotation
                freecamPart.CFrame = CFrame.new(newPosition, newPosition + camera.CFrame.LookVector)
                freecamPosition = newPosition
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
        
        -- Unfreeze character
        if rootPart then
            rootPart.Anchored = false
        end
    end
end

-- Teleport to Freecam Position
local function teleportToFreecam()
    if freecamEnabled and freecamPosition and rootPart then
        -- Disable freecam first
        toggleFreecam(false)
        buttonStates["Freecam"] = false
        
        -- Teleport to freecam position
        rootPart.CFrame = CFrame.new(freecamPosition)
        print("Teleported to freecam position")
        
        -- Refresh current category to update button display
        switchCategory(currentCategory)
    elseif freecamPosition and rootPart then
        -- If freecam was used before but not currently active
        rootPart.CFrame = CFrame.new(freecamPosition)
        print("Teleported to last freecam position")
    else
        print("Use freecam first to set a position")
    end
end

-- Position functions
local function savePosition()
    local positionName = PositionInput.Text
    if positionName == "" then
        positionName = "Position " .. (#savedPositions + 1)
    end
    
    if rootPart then
        savedPositions[positionName] = rootPart.CFrame
        print("Position Saved: " .. positionName)
        PositionInput.Text = ""
        updatePositionList()
    end
end

local function loadPosition(positionName)
    if savedPositions[positionName] and rootPart then
        rootPart.CFrame = savedPositions[positionName]
        print("Teleported to: " .. positionName)
    end
end

local function deletePosition(positionName)
    if savedPositions[positionName] then
        savedPositions[positionName] = nil
        print("Deleted position: " .. positionName)
        updatePositionList()
    end
end

local function showPositionManager()
    PositionFrame.Visible = true
    updatePositionList()
end

local function updatePositionList()
    for _, child in pairs(PositionScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local itemCount = 0
    
    for positionName, _ in pairs(savedPositions) do
        local positionItem = Instance.new("Frame")
        positionItem.Name = positionName .. "Item"
        positionItem.Parent = PositionScrollFrame
        positionItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        positionItem.BorderSizePixel = 0
        positionItem.Size = UDim2.new(1, -5, 0, 60)
        positionItem.LayoutOrder = itemCount
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Parent = positionItem
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.new(0, 5, 0, 5)
        nameLabel.Size = UDim2.new(1, -10, 0, 20)
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.Text = positionName
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize = 11
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local tpButton = Instance.new("TextButton")
        tpButton.Name = "TeleportButton"
        tpButton.Parent = positionItem
        tpButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        tpButton.BorderSizePixel = 0
        tpButton.Position = UDim2.new(0, 5, 0, 30)
        tpButton.Size = UDim2.new(0, 80, 0, 25)
        tpButton.Font = Enum.Font.Gotham
        tpButton.Text = "TELEPORT"
        tpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        tpButton.TextSize = 9
        
        local deleteButton = Instance.new("TextButton")
        deleteButton.Name = "DeleteButton"
        deleteButton.Parent = positionItem
        deleteButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
        deleteButton.BorderSizePixel = 0
        deleteButton.Position = UDim2.new(0, 90, 0, 30)
        deleteButton.Size = UDim2.new(0, 60, 0, 25)
        deleteButton.Font = Enum.Font.Gotham
        deleteButton.Text = "DELETE"
        deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        deleteButton.TextSize = 9
        
        -- Button events
        tpButton.MouseButton1Click:Connect(function()
            loadPosition(positionName)
        end)
        
        deleteButton.MouseButton1Click:Connect(function()
            deletePosition(positionName)
        end)
        
        -- Hover effects
        tpButton.MouseEnter:Connect(function()
            tpButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        end)
        
        tpButton.MouseLeave:Connect(function()
            tpButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end)
        
        deleteButton.MouseEnter:Connect(function()
            deleteButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        end)
        
        deleteButton.MouseLeave:Connect(function()
            deleteButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
        end)
        
        itemCount = itemCount + 1
    end
    
    wait(0.1)
    local contentSize = PositionLayout.AbsoluteContentSize
    PositionScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 10)
end

-- Player functions
local function showPlayerSelection()
    playerListVisible = true
    PlayerListFrame.Visible = true
    updatePlayerList()
end

local function updatePlayerList()
    for _, child in pairs(PlayerListScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local itemCount = 0
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            local playerItem = Instance.new("Frame")
            playerItem.Name = p.Name .. "Item"
            playerItem.Parent = PlayerListScrollFrame
            playerItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            playerItem.BorderSizePixel = 0
            playerItem.Size = UDim2.new(1, -5, 0, 90)
            playerItem.LayoutOrder = itemCount
            
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Name = "NameLabel"
            nameLabel.Parent = playerItem
            nameLabel.BackgroundTransparency = 1
            nameLabel.Position = UDim2.new(0, 5, 0, 5)
            nameLabel.Size = UDim2.new(1, -10, 0, 20)
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.Text = p.Name
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.TextSize = 12
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            local selectButton = Instance.new("TextButton")
            selectButton.Name = "SelectButton"
            selectButton.Parent = playerItem
            selectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            selectButton.BorderSizePixel = 0
            selectButton.Position = UDim2.new(0, 5, 0, 30)
            selectButton.Size = UDim2.new(1, -10, 0, 25)
            selectButton.Font = Enum.Font.Gotham
            selectButton.Text = "SELECT PLAYER"
            selectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            selectButton.TextSize = 10
            
            local spectateButton = Instance.new("TextButton")
            spectateButton.Name = "SpectateButton"
            spectateButton.Parent = playerItem
            spectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
            spectateButton.BorderSizePixel = 0
            spectateButton.Position = UDim2.new(0, 5, 0, 60)
            spectateButton.Size = UDim2.new(0, 70, 0, 25)
            spectateButton.Font = Enum.Font.Gotham
            spectateButton.Text = "SPECTATE"
            spectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            spectateButton.TextSize = 9
            
            local stopSpectateButton = Instance.new("TextButton")
            stopSpectateButton.Name = "StopSpectateButton"
            stopSpectateButton.Parent = playerItem
            stopSpectateButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
            stopSpectateButton.BorderSizePixel = 0
            stopSpectateButton.Position = UDim2.new(0, 80, 0, 60)
            stopSpectateButton.Size = UDim2.new(0, 70, 0, 25)
            stopSpectateButton.Font = Enum.Font.Gotham
            stopSpectateButton.Text = "STOP"
            stopSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            stopSpectateButton.TextSize = 9
            
            local teleportButton = Instance.new("TextButton")
            teleportButton.Name = "TeleportButton"
            teleportButton.Parent = playerItem
            teleportButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
            teleportButton.BorderSizePixel = 0
            teleportButton.Position = UDim2.new(0, 155, 0, 60)
            teleportButton.Size = UDim2.new(1, -160, 0, 25)
            teleportButton.Font = Enum.Font.Gotham
            teleportButton.Text = "TELEPORT"
            teleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            teleportButton.TextSize = 9
            
            -- Button events
            selectButton.MouseButton1Click:Connect(function()
                selectedPlayer = p
                SelectedPlayerLabel.Text = "SELECTED: " .. p.Name:upper()
                
                -- Update all select buttons
                for _, item in pairs(PlayerListScrollFrame:GetChildren()) do
                    if item:IsA("Frame") and item:FindFirstChild("SelectButton") then
                        if item.Name == p.Name .. "Item" then
                            item.SelectButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                            item.SelectButton.Text = "SELECTED"
                        else
                            item.SelectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                            item.SelectButton.Text = "SELECT PLAYER"
                        end
                    end
                end
            end)
            
            spectateButton.MouseButton1Click:Connect(function()
                if p and p.Character and p.Character:FindFirstChild("Humanoid") then
                    workspace.CurrentCamera.CameraSubject = p.Character.Humanoid
                    print("Spectating: " .. p.Name)
                end
            end)
            
            stopSpectateButton.MouseButton1Click:Connect(function()
                workspace.CurrentCamera.CameraSubject = humanoid
                print("Stopped spectating")
            end)
            
            teleportButton.MouseButton1Click:Connect(function()
                if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and rootPart then
                    rootPart.CFrame = p.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                    print("Teleported to: " .. p.Name)
                end
            end)
            
            -- Hover effects
            selectButton.MouseEnter:Connect(function()
                if selectedPlayer ~= p then
                    selectButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                end
            end)
            
            selectButton.MouseLeave:Connect(function()
                if selectedPlayer ~= p then
                    selectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                else
                    selectButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                end
            end)
            
            spectateButton.MouseEnter:Connect(function()
                spectateButton.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
            end)
            
            spectateButton.MouseLeave:Connect(function()
                spectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
            end)
            
            stopSpectateButton.MouseEnter:Connect(function()
                stopSpectateButton.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
            end)
            
            stopSpectateButton.MouseLeave:Connect(function()
                stopSpectateButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
            end)
            
            teleportButton.MouseEnter:Connect(function()
                teleportButton.BackgroundColor3 = Color3.fromRGB(50, 50, 100)
            end)
            
            teleportButton.MouseLeave:Connect(function()
                teleportButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
            end)
            
            itemCount = itemCount + 1
        end
    end
    
    wait(0.1)
    local contentSize = PlayerListLayout.AbsoluteContentSize
    PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 10)
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
    
    buttonStates[name] = false
    
    local function updateButton()
        if buttonStates[name] then
            button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            button.Text = name:upper() .. " [ON]"
        else
            button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            button.Text = name:upper() .. " [OFF]"
        end
    end
    
    button.MouseButton1Click:Connect(function()
        buttonStates[name] = not buttonStates[name]
        updateButton()
        callback(buttonStates[name])
    end)
    
    button.MouseEnter:Connect(function()
        if not buttonStates[name] then
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

-- Spider function (stick to walls)
local function toggleSpider(enabled)
    spiderEnabled = enabled
    if enabled then
        local bodyPosition = Instance.new("BodyPosition")
        bodyPosition.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyPosition.Position = rootPart.Position
        bodyPosition.Parent = rootPart
        
        local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
        bodyAngularVelocity.MaxTorque = Vector3.new(4000, 4000, 4000)
        bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
        bodyAngularVelocity.Parent = rootPart
        
        connections.spider = RunService.Heartbeat:Connect(function()
            if spiderEnabled and rootPart then
                local ray = workspace:Raycast(rootPart.Position, rootPart.CFrame.LookVector * 10)
                if ray then
                    bodyPosition.Position = ray.Position + ray.Normal * 3
                    local lookDirection = -ray.Normal
                    bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
                    rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + lookDirection)
                end
            end
        end)
    else
        if connections.spider then
            connections.spider:Disconnect()
        end
        if rootPart:FindFirstChild("BodyPosition") then
            rootPart:FindFirstChild("BodyPosition"):Destroy()
        end
        if rootPart:FindFirstChild("BodyAngularVelocity") then
            rootPart:FindFirstChild("BodyAngularVelocity"):Destroy()
        end
    end
end

-- Category button loaders
local function loadMovementButtons()
    createToggleButton("Fly", toggleFly)
    createToggleButton("Noclip", toggleNoclip)
    createToggleButton("Speed", toggleSpeed)
    createToggleButton("Jump High", toggleJumpHigh)
    createToggleButton("Spider", toggleSpider)
    createToggleButton("Player Phase", togglePlayerPhase)
end

local function loadPlayerButtons()
    createButton("Select Player", showPlayerSelection)
    createToggleButton("God Mode", toggleGodMode)
    createToggleButton("Anti AFK", toggleAntiAFK)
end

local function loadVisualButtons()
    createToggleButton("Fullbright", toggleFullbright)
    createToggleButton("Freecam", toggleFreecam)
    createToggleButton("Flashlight", toggleFlashlight)
end

local function loadTeleportButtons()
    createButton("Position Manager", showPositionManager)
    createButton("TP to Selected Player", function()
        if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and rootPart then
            rootPart.CFrame = selectedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
            print("Teleported to: " .. selectedPlayer.Name)
        else
            print("Select a player first")
        end
    end)
    createButton("TP to Freecam", teleportToFreecam)
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
    
    createButton("Reset Character", function()
        if humanoid then
            humanoid.Health = 0
        end
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

-- Minimize/Maximize functions dengan state preservation
local function minimizeGUI()
    guiMinimized = true
    MainFrame.Visible = false
    PlayerListFrame.Visible = false
    PositionFrame.Visible = false
    LogoButton.Visible = true
end

local function maximizeGUI()
    guiMinimized = false
    LogoButton.Visible = false
    MainFrame.Visible = true
    -- Don't automatically show other frames
end

-- Event connections
MinimizeButton.MouseButton1Click:Connect(minimizeGUI)
LogoButton.MouseButton1Click:Connect(maximizeGUI)

-- Player List Close Button
ClosePlayerListButton.MouseButton1Click:Connect(function()
    PlayerListFrame.Visible = false
    playerListVisible = false
end)

-- Position Manager Close Button
ClosePositionButton.MouseButton1Click:Connect(function()
    PositionFrame.Visible = false
end)

-- Save Position Button Event
SavePositionButton.MouseButton1Click:Connect(savePosition)

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
    
    -- Reset all feature states but preserve button states
    flyEnabled = false
    noclipEnabled = false
    speedEnabled = false
    jumpHighEnabled = false
    godModeEnabled = false
    antiAFKEnabled = false
    freecamEnabled = false
    playerPhaseEnabled = false
    spiderEnabled = false
    flashlightEnabled = false
    freecamPosition = nil -- Reset freecam position
    
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
    
    -- Reset button states to OFF
    for featureName, _ in pairs(buttonStates) do
        buttonStates[featureName] = false
    end
    
    -- Refresh current category to update button displays
    switchCategory(currentCategory)
    
    print("Character respawned - features reset")
end)

-- Player cleanup untuk Player Phase
Players.PlayerRemoving:Connect(function(removedPlayer)
    if removedPlayer == selectedPlayer then
        selectedPlayer = nil
        SelectedPlayerLabel.Text = "SELECTED: NONE"
    end
end)

-- Player joined/left events untuk update player list
Players.PlayerAdded:Connect(function()
    if playerListVisible then
        updatePlayerList()
    end
end)

Players.PlayerRemoving:Connect(function()
    if playerListVisible then
        wait(0.1) -- Small delay to ensure player is removed
        updatePlayerList()
    end
end)

print("=== MINIMAL HACK GUI LOADED (FIXED VERSION) ===")
print("✓ Auto-disable previous scripts")
print("✓ State preservation on minimize")
print("✓ Enhanced player list with individual buttons")
print("✓ Position manager with save/load/delete")
print("✓ Flashlight feature added")
print("✓ Fixed freecam movement directions")
print("✓ Added teleport to freecam feature")
print("GUI ready to use!")