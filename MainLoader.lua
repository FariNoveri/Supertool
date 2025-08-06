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
    end
end

-- Memuat AntiAdmin.lua dari URL
local success, errorMsg = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/main/antiadmin.lua", true))()
end)
if not success then
    warn("Failed to load AntiAdmin.lua: " .. tostring(errorMsg))
else
    print("Anti Admin Loaded - By Fari Noveri")
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
local spectatePlayerList = {}
local currentSpectateIndex = 0
local spectateConnections = {}

-- Settings table
local settings = {
    FlySpeed = { value = 50, default = 50, min = 10, max = 200 },
    FreecamSpeed = { value = 80, default = 80, min = 20, max = 300 },
    JumpHeight = { value = 50, default = 50, min = 10, max = 150 },
    WalkSpeed = { value = 100, default = 100, min = 16, max = 300 },
    FlashlightBrightness = { value = 5, default = 5, min = 1, max = 10 },
    FlashlightRange = { value = 100, default = 100, min = 50, max = 200 },
    FullbrightBrightness = { value = 2, default = 2, min = 0, max = 5 }
}

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

-- Spectate Buttons
local NextSpectateButton = Instance.new("TextButton")
local PrevSpectateButton = Instance.new("TextButton")
local StopSpectateButton = Instance.new("TextButton")
local TeleportSpectateButton = Instance.new("TextButton")

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
Title.Text = "HACK - By Fari Noveri [UNKNOWN BLOCK]"
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
ScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
ScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

-- UIListLayout untuk content
UIListLayout.Parent = ScrollFrame
UIListLayout.Padding = UDim.new(0, 5)
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

-- Spectate Buttons
NextSpectateButton.Name = "NextSpectateButton"
NextSpectateButton.Parent = ScreenGui
NextSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
NextSpectateButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
NextSpectateButton.BorderSizePixel = 1
NextSpectateButton.Position = UDim2.new(0.5, 20, 0.5, 0)
NextSpectateButton.Size = UDim2.new(0, 60, 0, 30)
NextSpectateButton.Font = Enum.Font.Gotham
NextSpectateButton.Text = "NEXT >"
NextSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
NextSpectateButton.TextSize = 10
NextSpectateButton.Visible = false
NextSpectateButton.Active = true

-- Previous Spectate Button
PrevSpectateButton.Name = "PrevSpectateButton"
PrevSpectateButton.Parent = ScreenGui
PrevSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
PrevSpectateButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
PrevSpectateButton.BorderSizePixel = 1
PrevSpectateButton.Position = UDim2.new(0.5, -80, 0.5, 0)
PrevSpectateButton.Size = UDim2.new(0, 60, 0, 30)
PrevSpectateButton.Font = Enum.Font.Gotham
PrevSpectateButton.Text = "< PREV"
PrevSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
PrevSpectateButton.TextSize = 10
PrevSpectateButton.Visible = false
PrevSpectateButton.Active = true

-- Stop Spectate Button
StopSpectateButton.Name = "StopSpectateButton"
StopSpectateButton.Parent = ScreenGui
StopSpectateButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
StopSpectateButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
StopSpectateButton.BorderSizePixel = 1
StopSpectateButton.Position = UDim2.new(0.5, -30, 0.5, 40)
StopSpectateButton.Size = UDim2.new(0, 60, 0, 30)
StopSpectateButton.Font = Enum.Font.Gotham
StopSpectateButton.Text = "STOP"
StopSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
StopSpectateButton.TextSize = 10
StopSpectateButton.Visible = false
StopSpectateButton.Active = true

-- Teleport Spectate Button
TeleportSpectateButton.Name = "TeleportSpectateButton"
TeleportSpectateButton.Parent = ScreenGui
TeleportSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
TeleportSpectateButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
TeleportSpectateButton.BorderSizePixel = 1
TeleportSpectateButton.Position = UDim2.new(0.5, 40, 0.5, 40)
TeleportSpectateButton.Size = UDim2.new(0, 60, 0, 30)
TeleportSpectateButton.Font = Enum.Font.Gotham
TeleportSpectateButton.Text = "TP"
TeleportSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
TeleportSpectateButton.TextSize = 10
TeleportSpectateButton.Visible = false
TeleportSpectateButton.Active = true

-- Feature Functions

-- Flashlight
local flashlightPart = nil
local function toggleFlashlight(enabled)
    flashlightEnabled = enabled
    if enabled then
        if character and character:FindFirstChild("Head") then
            flashlightPart = Instance.new("PointLight")
            flashlightPart.Name = "Flashlight"
            flashlightPart.Brightness = settings.FlashlightBrightness.value
            flashlightPart.Range = settings.FlashlightRange.value
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
                
                local cameraCFrame = camera.CFrame
                local forwardVector = cameraCFrame.LookVector
                local rightVector = cameraCFrame.RightVector
                local upVector = Vector3.new(0, 1, 0)
                
                local velocity = Vector3.new(0, 0, 0)
                local speed = settings.FlySpeed.value
                
                if moveVector.Magnitude > 0 then
                    velocity = velocity + (forwardVector * -moveVector.Z * speed)
                    velocity = velocity + (rightVector * moveVector.X * speed)
                end
                
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
        humanoid.WalkSpeed = settings.WalkSpeed.value
    else
        humanoid.WalkSpeed = 16
    end
end

-- Jump High
local function toggleJumpHigh(enabled)
    jumpHighEnabled = enabled
    if enabled then
        humanoid.JumpHeight = settings.JumpHeight.value
        humanoid.JumpPower = settings.JumpHeight.value * 2.4
        connections.jumphigh = humanoid.Jumping:Connect(function()
            if jumpHighEnabled then
                rootPart.Velocity = Vector3.new(rootPart.Velocity.X, settings.JumpHeight.value * 2.4, rootPart.Velocity.Z)
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
        lighting.Brightness = settings.FullbrightBrightness.value
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

-- Freecam (Android Touch Controls)
local freecamPart = nil
local originalCameraSubject = nil
local freecamPosition = nil
local yaw = 0
local pitch = 0
local function toggleFreecam(enabled)
    freecamEnabled = enabled
    if enabled then
        originalCameraSubject = workspace.CurrentCamera.CameraSubject
        
        if character and rootPart then
            freecamPosition = rootPart.Position
        else
            freecamPosition = workspace.CurrentCamera.CFrame.Position
        end
        
        freecamPart = Instance.new("Part")
        freecamPart.Name = "FreecamPart"
        freecamPart.Anchored = true
        freecamPart.CanCollide = false
        freecamPart.Transparency = 1
        freecamPart.Size = Vector3.new(1, 1, 1)
        freecamPart.CFrame = CFrame.new(freecamPosition, freecamPosition + workspace.CurrentCamera.CFrame.LookVector)
        freecamPart.Parent = workspace
        
        workspace.CurrentCamera.CameraSubject = freecamPart
        
        local lookVector = workspace.CurrentCamera.CFrame.LookVector
        yaw = math.atan2(-lookVector.X, -lookVector.Z)
        pitch = math.asin(lookVector.Y)
        
        if rootPart then
            rootPart.Anchored = true
        end
        
        connections.freecam_input = UserInputService.InputChanged:Connect(function(input)
            if freecamEnabled and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                local delta = input.Delta
                local sensitivity = 0.005
                
                yaw = yaw - delta.X * sensitivity
                pitch = math.clamp(pitch - delta.Y * sensitivity, -math.pi/2 + 0.1, math.pi/2 - 0.1)
                
                local rotationCFrame = CFrame.new(Vector3.new(0, 0, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
                freecamPart.CFrame = CFrame.new(freecamPart.Position) * rotationCFrame
            end
        end)
        
        connections.freecam = RunService.RenderStepped:Connect(function(deltaTime)
            if freecamEnabled and freecamPart then
                local camera = workspace.CurrentCamera
                local moveVector = humanoid.MoveDirection
                
                local cameraCFrame = freecamPart.CFrame
                local forwardVector = cameraCFrame.LookVector
                local rightVector = cameraCFrame.RightVector
                local upVector = Vector3.new(0, 1, 0)
                
                local movement = Vector3.new(0, 0, 0)
                local speed = settings.FreecamSpeed.value
                
                if moveVector.Magnitude > 0 then
                    movement = movement + (forwardVector * -moveVector.Z * speed)
                    movement = movement + (rightVector * moveVector.X * speed)
                end
                
                if humanoid.Jump then
                    movement = movement + (upVector * speed)
                    humanoid.Jump = false
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                    movement = movement + (upVector * -speed)
                end
                
                local newPosition = freecamPart.Position + (movement * deltaTime)
                
                freecamPart.CFrame = CFrame.new(newPosition) * freecamPart.CFrame.Rotation
                freecamPosition = newPosition
                
                camera.CFrame = freecamPart.CFrame
            end
        end)
        
    else
        if connections.freecam then
            connections.freecam:Disconnect()
        end
        if connections.freecam_input then
            connections.freecam_input:Disconnect()
        end
        if freecamPart then
            freecamPart:Destroy()
            freecamPart = nil
        end
        
        if character and humanoid then
            workspace.CurrentCamera.CameraSubject = humanoid
            if rootPart then
                workspace.CurrentCamera.CFrame = CFrame.new(rootPart.Position + Vector3.new(0, 2, 0), rootPart.Position)
            end
        elseif originalCameraSubject then
            workspace.CurrentCamera.CameraSubject = originalCameraSubject
        end
        
        if rootPart then
            rootPart.Anchored = false
        end
        
        freecamPosition = nil
        yaw = 0
        pitch = 0
    end
end

-- Save Freecam Position to Position Manager
local function saveFreecamPosition()
    if freecamEnabled and freecamPosition then
        local positionName = PositionInput.Text
        if positionName == "" then
            positionName = "Freecam Position " .. (#savedPositions + 1)
        end
        savedPositions[positionName] = CFrame.new(freecamPosition)
        print("Freecam Position Saved: " .. positionName)
        PositionInput.Text = ""
        updatePositionList()
    else
        print("Freecam must be enabled to save position")
    end
end

-- Save Selected Player Position to Position Manager
local function savePlayerPosition()
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local positionName = PositionInput.Text
        if positionName == "" then
            positionName = selectedPlayer.Name .. " Position " .. (#savedPositions + 1)
        end
        savedPositions[positionName] = selectedPlayer.Character.HumanoidRootPart.CFrame
        print("Player Position Saved: " .. positionName)
        PositionInput.Text = ""
        updatePositionList()
    else
        print("Select a player first to save their position")
    end
end

-- Teleport to Freecam Position
local function teleportToFreecam()
    if freecamEnabled and freecamPosition and rootPart then
        toggleFreecam(false)
        buttonStates["Freecam"] = false
        rootPart.CFrame = CFrame.new(freecamPosition)
        print("Teleported to freecam position")
        switchCategory(currentCategory)
    elseif freecamPosition and rootPart then
        rootPart.CFrame = CFrame.new(freecamPosition)
        print("Teleported to last freecam position")
    else
        print("Use freecam first to set a position")
    end
end

-- Teleport to Spectated Player
local function teleportToSpectatedPlayer()
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and rootPart then
        rootPart.CFrame = selectedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
        print("Teleported to spectated player: " .. selectedPlayer.Name)
    else
        print("Cannot teleport: No valid spectated player")
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
        
        tpButton.MouseButton1Click:Connect(function()
            loadPosition(positionName)
        end)
        
        deleteButton.MouseButton1Click:Connect(function()
            deletePosition(positionName)
        end)
        
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

local function updateSpectateButtons()
    local isSpectating = selectedPlayer ~= nil
    NextSpectateButton.Visible = isSpectating
    PrevSpectateButton.Visible = isSpectating
    StopSpectateButton.Visible = isSpectating
    TeleportSpectateButton.Visible = isSpectating
end

local function stopSpectating()
    for _, connection in pairs(spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    spectateConnections = {}
    workspace.CurrentCamera.CameraSubject = humanoid
    selectedPlayer = nil
    currentSpectateIndex = 0
    SelectedPlayerLabel.Text = "SELECTED: NONE"
    print("Stopped spectating via Stop Spectate button")
    updateSpectateButtons()
    for _, item in pairs(PlayerListScrollFrame:GetChildren()) do
        if item:IsA("Frame") and item:FindFirstChild("SelectButton") then
            item.SelectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            item.SelectButton.Text = "SELECT PLAYER"
        end
    end
end

local function spectatePlayer(targetPlayer)
    for _, connection in pairs(spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    spectateConnections = {}
    
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
        workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
        selectedPlayer = targetPlayer
        currentSpectateIndex = table.find(spectatePlayerList, targetPlayer) or 0
        SelectedPlayerLabel.Text = "SELECTED: " .. targetPlayer.Name:upper()
        print("Spectating: " .. targetPlayer.Name)
        
        -- Connect to detect player death
        local targetHumanoid = targetPlayer.Character.Humanoid
        spectateConnections.died = targetHumanoid.Died:Connect(function()
            print("Spectated player died, waiting for respawn")
        end)
        
        -- Connect to detect respawn
        spectateConnections.characterAdded = targetPlayer.CharacterAdded:Connect(function(newCharacter)
            local newHumanoid = newCharacter:WaitForChild("Humanoid", 5)
            if newHumanoid then
                workspace.CurrentCamera.CameraSubject = newHumanoid
                print("Spectated player respawned, continuing spectate")
            end
        end)
        
        -- Update PlayerListFrame buttons to reflect selection
        for _, item in pairs(PlayerListScrollFrame:GetChildren()) do
            if item:IsA("Frame") and item:FindFirstChild("SelectButton") then
                if item.Name == targetPlayer.Name .. "Item" then
                    item.SelectButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                    item.SelectButton.Text = "SELECTED"
                else
                    item.SelectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    item.SelectButton.Text = "SELECT PLAYER"
                end
            end
        end
    else
        stopSpectating()
    end
    updateSpectateButtons()
end

local function spectateNextPlayer()
    if #spectatePlayerList == 0 then
        print("No players to spectate")
        stopSpectating()
        return
    end
    
    currentSpectateIndex = currentSpectateIndex + 1
    if currentSpectateIndex > #spectatePlayerList then
        currentSpectateIndex = 1
    end
    
    local targetPlayer = spectatePlayerList[currentSpectateIndex]
    if targetPlayer then
        spectatePlayer(targetPlayer)
    else
        stopSpectating()
    end
end

local function spectatePrevPlayer()
    if #spectatePlayerList == 0 then
        print("No players to spectate")
        stopSpectating()
        return
    end
    
    currentSpectateIndex = currentSpectateIndex - 1
    if currentSpectateIndex < 1 then
        currentSpectateIndex = #spectatePlayerList
    end
    
    local targetPlayer = spectatePlayerList[currentSpectateIndex]
    if targetPlayer then
        spectatePlayer(targetPlayer)
    else
        stopSpectating()
    end
end

local function updatePlayerList()
    for _, child in pairs(PlayerListScrollFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    local previousSelectedPlayer = selectedPlayer
    spectatePlayerList = {}
    local playerCount = 0
    local players = Players:GetPlayers()
    
    if #players <= 1 then
        local noPlayersLabel = Instance.new("TextLabel")
        noPlayersLabel.Name = "NoPlayersLabel"
        noPlayersLabel.Parent = PlayerListScrollFrame
        noPlayersLabel.BackgroundTransparency = 1
        noPlayersLabel.Size = UDim2.new(1, 0, 0, 30)
        noPlayersLabel.Font = Enum.Font.Gotham
        noPlayersLabel.Text = "No other players found"
        noPlayersLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        noPlayersLabel.TextSize = 11
        noPlayersLabel.TextXAlignment = Enum.TextXAlignment.Center
        print("Player List Updated: No other players found")
    else
        for _, p in pairs(players) do
            if p ~= player and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                playerCount = playerCount + 1
                table.insert(spectatePlayerList, p)
                
                local playerItem = Instance.new("Frame")
                playerItem.Name = p.Name .. "Item"
                playerItem.Parent = PlayerListScrollFrame
                playerItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                playerItem.BorderSizePixel = 0
                playerItem.Size = UDim2.new(1, -5, 0, 90)
                playerItem.LayoutOrder = playerCount
                
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
                selectButton.BackgroundColor3 = selectedPlayer == p and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(60, 60, 60)
                selectButton.BorderSizePixel = 0
                selectButton.Position = UDim2.new(0, 5, 0, 30)
                selectButton.Size = UDim2.new(1, -10, 0, 25)
                selectButton.Font = Enum.Font.Gotham
                selectButton.Text = selectedPlayer == p and "SELECTED" or "SELECT PLAYER"
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
                
                selectButton.MouseButton1Click:Connect(function()
                    selectedPlayer = p
                    currentSpectateIndex = table.find(spectatePlayerList, p) or 0
                    SelectedPlayerLabel.Text = "SELECTED: " .. p.Name:upper()
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
                    currentSpectateIndex = table.find(spectatePlayerList, p) or 0
                    spectatePlayer(p)
                end)
                
                stopSpectateButton.MouseButton1Click:Connect(function()
                    stopSpectating()
                end)
                
                teleportButton.MouseButton1Click:Connect(function()
                    if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and rootPart then
                        rootPart.CFrame = p.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                        print("Teleported to: " .. p.Name)
                    end
                end)
                
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
            end
        end
    end
    
    -- Preserve selectedPlayer and update currentSpectateIndex
    if previousSelectedPlayer then
        selectedPlayer = previousSelectedPlayer
        currentSpectateIndex = table.find(spectatePlayerList, selectedPlayer) or 0
        if currentSpectateIndex == 0 and selectedPlayer then
            -- If selectedPlayer is no longer valid, stop spectating
            if not (selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("Humanoid") and selectedPlayer.Character.Humanoid.Health > 0) then
                stopSpectating()
            end
        end
        SelectedPlayerLabel.Text = selectedPlayer and "SELECTED: " .. selectedPlayer.Name:upper() or "SELECTED: NONE"
    else
        currentSpectateIndex = 0
    end
    
    wait(0.1)
    local contentSize = PlayerListLayout.AbsoluteContentSize
    PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(contentSize.Y + 10, 30))
    print("Player List Updated: " .. playerCount .. " players listed")
    updateSpectateButtons()
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
    button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 30)
    button.Font = Enum.Font.Gotham
    button.Text = name:upper() .. (buttonStates[name] and " [ON]" or " [OFF]")
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 11
    
    button.MouseButton1Click:Connect(function()
        buttonStates[name] = not buttonStates[name]
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(25, 25, 25)
        button.Text = name:upper() .. (buttonStates[name] and " [ON]" or " [OFF]")
        callback(buttonStates[name])
    end)
    
    button.MouseEnter:Connect(function()
        if not buttonStates[name] then
            button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(25, 25, 25)
    end)
    
    return button
end

local function createCategoryButton(name)
    local button = Instance.new("TextButton")
    button.Name = name .. "Category"
    button.Parent = CategoryFrame
    button.BackgroundColor3 = currentCategory == name and Color3.fromRGB(35, 35, 35) or Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 35)
    button.Font = Enum.Font.Gotham
    button.Text = name:upper()
    button.TextColor3 = Color3.fromRGB(200, 200, 200)
    button.TextSize = 10
    button.AutoButtonColor = true
    
    button.MouseButton1Click:Connect(function()
        print("Category button clicked: " .. name) -- Debug log
        switchCategory(name)
    end)
    
    button.MouseEnter:Connect(function()
        if currentCategory ~= name then
            button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
    end)
    
    button.MouseLeave:Connect(function()
        if currentCategory ~= name then
            button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        end
    end)
    
    return button
end

local function clearButtons()
    for _, child in pairs(ScrollFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then
            child:Destroy()
        end
    end
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
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

-- Settings Category
local function createSettingInput(settingName, settingData)
    local settingFrame = Instance.new("Frame")
    settingFrame.Name = settingName .. "SettingFrame"
    settingFrame.Parent = ScrollFrame
    settingFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    settingFrame.BorderSizePixel = 0
    settingFrame.Size = UDim2.new(1, 0, 0, 60)
    
    local label = Instance.new("TextLabel")
    label.Name = "SettingLabel"
    label.Parent = settingFrame
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 5, 0, 5)
    label.Size = UDim2.new(1, -10, 0, 20)
    label.Font = Enum.Font.Gotham
    label.Text = string.format("%s (Default: %d, Min: %d, Max: %d)", settingName, settingData.default, settingData.min, settingData.max)
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    
    local input = Instance.new("TextBox")
    input.Name = settingName .. "Input"
    input.Parent = settingFrame
    input.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    input.BorderSizePixel = 0
    input.Position = UDim2.new(0, 5, 0, 30)
    input.Size = UDim2.new(1, -10, 0, 25)
    input.Font = Enum.Font.Gotham
    input.Text = tostring(settingData.value)
    input.TextColor3 = Color3.fromRGB(255, 255, 255)
    input.TextSize = 11
    input.PlaceholderText = "Enter value..."
    
    input.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local value = tonumber(input.Text)
            if value then
                value = math.clamp(value, settingData.min, settingData.max)
                settingData.value = value
                input.Text = tostring(value)
                print(string.format("%s set to %d", settingName, value))
                
                if settingName == "Fly Speed" and flyEnabled then
                    toggleFly(false)
                    toggleFly(true)
                elseif settingName == "Freecam Speed" and freecamEnabled then
                    toggleFreecam(false)
                    toggleFreecam(true)
                elseif settingName == "Jump Height" and jumpHighEnabled then
                    toggleJumpHigh(false)
                    toggleJumpHigh(true)
                elseif settingName == "Walk Speed" and speedEnabled then
                    toggleSpeed(false)
                    toggleSpeed(true)
                elseif settingName == "Flashlight Brightness" and flashlightEnabled then
                    toggleFlashlight(false)
                    toggleFlashlight(true)
                elseif settingName == "Flashlight Range" and flashlightEnabled then
                    toggleFlashlight(false)
                    toggleFlashlight(true)
                elseif settingName == "Fullbright Brightness" and fullbrightEnabled then
                    toggleFullbright(false)
                    toggleFullbright(true)
                end
            else
                input.Text = tostring(settingData.value)
                print(string.format("Invalid input for %s, reverting to %d", settingName, settingData.value))
            end
        end
    end)
    
    return settingFrame
end

-- Category switch function
local function switchCategory(category)
    if currentCategory == category then
        print("Category " .. category .. " already active, skipping switch")
        return
    end
    
    print("Switching to category: " .. category) -- Debug log
    currentCategory = category
    clearButtons()
    
    -- Update all category buttons' appearance
    for _, button in pairs(CategoryFrame:GetChildren()) do
        if button:IsA("TextButton") then
            button.BackgroundColor3 = button.Name == category .. "Category" and Color3.fromRGB(35, 35, 35) or Color3.fromRGB(25, 25, 25)
            button.TextColor3 = button.Name == category .. "Category" and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
        end
    end
    
    -- Populate content for the selected category
    if category == "Movement" then
        print("Loading Movement category content")
        createToggleButton("Fly", toggleFly)
        createToggleButton("Noclip", toggleNoclip)
        createToggleButton("Speed", toggleSpeed)
        createToggleButton("Jump High", toggleJumpHigh)
        createToggleButton("Spider", toggleSpider)
    elseif category == "Player" then
        print("Loading Player category content")
        createToggleButton("God Mode", toggleGodMode)
        createToggleButton("Anti AFK", toggleAntiAFK)
        createToggleButton("Player Phase", togglePlayerPhase)
    elseif category == "Visual" then
        print("Loading Visual category content")
        createToggleButton("Fullbright", toggleFullbright)
        createToggleButton("Flashlight", toggleFlashlight)
        createToggleButton("Freecam", toggleFreecam)
        createButton("Teleport to Freecam", teleportToFreecam)
        createButton("Save Freecam Position", saveFreecamPosition)
    elseif category == "Teleport" then
        print("Loading Teleport category content")
        createButton("Show Position Manager", showPositionManager)
        createButton("Save Current Position", savePosition)
        createButton("Select Player", showPlayerSelection)
        createButton("Save Player Position", savePlayerPosition)
        createButton("Teleport to Player", teleportToSpectatedPlayer)
    elseif category == "Settings" then
        print("Loading Settings category content")
        createSettingInput("Fly Speed", settings.FlySpeed)
        createSettingInput("Freecam Speed", settings.FreecamSpeed)
        createSettingInput("Jump Height", settings.JumpHeight)
        createSettingInput("Walk Speed", settings.WalkSpeed)
        createSettingInput("Flashlight Brightness", settings.FlashlightBrightness)
        createSettingInput("Flashlight Range", settings.FlashlightRange)
        createSettingInput("Fullbright Brightness", settings.FullbrightBrightness)
    elseif category == "Anti Admin" then
        print("Loading Anti Admin category content")
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Name = "AntiAdminInfo"
        infoLabel.Parent = ScrollFrame
        infoLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        infoLabel.BorderSizePixel = 0
        infoLabel.Size = UDim2.new(1, 0, 0, 300)
        infoLabel.Font = Enum.Font.Gotham
        infoLabel.Text = [[
ANTI ADMIN PROTECTION

This feature is included to protect you from other admin/exploit attempts (kill, teleport, etc.). Effects will be reversed to the attacker or redirected to unprotected players. It is always active and cannot be disabled for your safety.

Note: Admins can still kick, ban, or perform other server-side actions against you.

Created by Fari Noveri
]]
        infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        infoLabel.TextSize = 10
        infoLabel.TextWrapped = true
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoLabel.TextYAlignment = Enum.TextYAlignment.Top
    end
    
    -- Force layout update
    UIListLayout:ApplyLayout()
    ContentFrame:FindFirstChild("ScrollFrame").CanvasPosition = Vector2.new(0, 0) -- Reset scroll position
    
    -- Update ScrollFrame CanvasSize
    wait(0.1)
    local contentSize = UIListLayout.AbsoluteContentSize
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 20)
    print("Category " .. category .. " loaded with canvas size: " .. contentSize.Y)
end

-- Initialize Categories
local categories = {"Movement", "Player", "Visual", "Teleport", "Settings", "Anti Admin"}
for _, category in pairs(categories) do
    createCategoryButton(category)
end

-- Initialize GUI
switchCategory("Movement")

-- Connections
MinimizeButton.MouseButton1Click:Connect(function()
    guiMinimized = not guiMinimized
    MainFrame.Visible = not guiMinimized
    LogoButton.Visible = guiMinimized
    if guiMinimized then
        MinimizeButton.Text = "+"
    else
        MinimizeButton.Text = "_"
    end
end)

LogoButton.MouseButton1Click:Connect(function()
    guiMinimized = false
    MainFrame.Visible = true
    LogoButton.Visible = false
    MinimizeButton.Text = "_"
end)

ClosePlayerListButton.MouseButton1Click:Connect(function()
    PlayerListFrame.Visible = false
    playerListVisible = false
end)

ClosePositionButton.MouseButton1Click:Connect(function()
    PositionFrame.Visible = false
end)

SavePositionButton.MouseButton1Click:Connect(function()
    savePosition()
end)

NextSpectateButton.MouseButton1Click:Connect(spectateNextPlayer)
PrevSpectateButton.MouseButton1Click:Connect(spectatePrevPlayer)
StopSpectateButton.MouseButton1Click:Connect(stopSpectating)
TeleportSpectateButton.MouseButton1Click:Connect(teleportToSpectatedPlayer)

-- Handle character respawn
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    
    if flyEnabled then
        toggleFly(false)
        toggleFly(true)
    end
    if noclipEnabled then
        toggleNoclip(false)
        toggleNoclip(true)
    end
    if speedEnabled then
        toggleSpeed(false)
        toggleSpeed(true)
    end
    if jumpHighEnabled then
        toggleJumpHigh(false)
        toggleJumpHigh(true)
    end
    if godModeEnabled then
        toggleGodMode(false)
        toggleGodMode(true)
    end
    if spiderEnabled then
        toggleSpider(false)
        toggleSpider(true)
    end
    if playerPhaseEnabled then
        togglePlayerPhase(false)
        togglePlayerPhase(true)
    end
    if flashlightEnabled then
        toggleFlashlight(false)
        toggleFlashlight(true)
    end
end)

-- Handle player join/leave
Players.PlayerAdded:Connect(function()
    updatePlayerList()
end)
Players.PlayerRemoving:Connect(function(p)
    if selectedPlayer == p then
        stopSpectating()
    end
    updatePlayerList()
end)

-- Cleanup on script destruction
ScreenGui.AncestryChanged:Connect(function()
    if not ScreenGui:IsDescendantOf(game) then
        for _, connection in pairs(connections) do
            if connection then
                connection:Disconnect()
            end
        end
        for _, connection in pairs(spectateConnections) do
            if connection then
                connection:Disconnect()
            end
        end
    end
end)

print("MainLoader.lua Initialized - By Fari Noveri")