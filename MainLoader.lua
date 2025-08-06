-- Modern Roblox GUI Script untuk Android dengan Kategori (KRNL Compatible)
-- Dibuat dengan desain modern hitam dan fitur lengkap

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
ScreenGui.Name = "ModernHackGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Main Frame (lebih lebar untuk kategori)
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderColor3 = Color3.fromRGB(0, 162, 255)
MainFrame.BorderSizePixel = 2
MainFrame.Position = UDim2.new(0.05, 0, 0.1, 0)
MainFrame.Size = UDim2.new(0, 450, 0, 500)
MainFrame.Active = true
MainFrame.Draggable = true

-- Corner untuk Main Frame
local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

-- Top Bar
TopBar.Name = "TopBar"
TopBar.Parent = MainFrame
TopBar.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
TopBar.Position = UDim2.new(0, 0, 0, 0)
TopBar.Size = UDim2.new(1, 0, 0, 40)

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 12)
TopCorner.Parent = TopBar

-- Fix corner untuk bottom
local TopFix = Instance.new("Frame")
TopFix.Parent = TopBar
TopFix.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
TopFix.BorderSizePixel = 0
TopFix.Position = UDim2.new(0, 0, 0.5, 0)
TopFix.Size = UDim2.new(1, 0, 0.5, 0)

-- Logo di TopBar
Logo.Name = "Logo"
Logo.Parent = TopBar
Logo.BackgroundTransparency = 1
Logo.Position = UDim2.new(0, 10, 0, 5)
Logo.Size = UDim2.new(0, 30, 0, 30)
Logo.Font = Enum.Font.GothamBold
Logo.Text = "🔥"
Logo.TextColor3 = Color3.fromRGB(255, 255, 255)
Logo.TextScaled = true

-- Title
Title.Name = "Title"
Title.Parent = TopBar
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 50, 0, 0)
Title.Size = UDim2.new(1, -90, 1, 0)
Title.Font = Enum.Font.GothamBold
Title.Text = "Modern Hack GUI"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextScaled = true
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Minimize Button
MinimizeButton.Name = "MinimizeButton"
MinimizeButton.Parent = TopBar
MinimizeButton.BackgroundTransparency = 1
MinimizeButton.Position = UDim2.new(1, -35, 0, 5)
MinimizeButton.Size = UDim2.new(0, 30, 0, 30)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "−"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextScaled = true

-- Category Frame (Panel Kiri)
CategoryFrame.Name = "CategoryFrame"
CategoryFrame.Parent = MainFrame
CategoryFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
CategoryFrame.BorderColor3 = Color3.fromRGB(0, 162, 255)
CategoryFrame.BorderSizePixel = 1
CategoryFrame.Position = UDim2.new(0, 10, 0, 50)
CategoryFrame.Size = UDim2.new(0, 120, 1, -60)

local CategoryCorner = Instance.new("UICorner")
CategoryCorner.CornerRadius = UDim.new(0, 8)
CategoryCorner.Parent = CategoryFrame

-- Category List Layout
CategoryList.Parent = CategoryFrame
CategoryList.Padding = UDim.new(0, 5)
CategoryList.SortOrder = Enum.SortOrder.LayoutOrder

-- Content Frame (Panel Kanan)
ContentFrame.Name = "ContentFrame"
ContentFrame.Parent = MainFrame
ContentFrame.BackgroundTransparency = 1
ContentFrame.Position = UDim2.new(0, 140, 0, 50)
ContentFrame.Size = UDim2.new(1, -150, 1, -60)

-- ScrollFrame di Content
ScrollFrame.Name = "ScrollFrame"
ScrollFrame.Parent = ContentFrame
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.Position = UDim2.new(0, 0, 0, 0)
ScrollFrame.Size = UDim2.new(1, 0, 1, 0)
ScrollFrame.ScrollBarThickness = 6
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 162, 255)

-- UIListLayout untuk content
UIListLayout.Parent = ScrollFrame
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Player Selection Frame
PlayerListFrame.Name = "PlayerListFrame"
PlayerListFrame.Parent = ScreenGui
PlayerListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
PlayerListFrame.BorderColor3 = Color3.fromRGB(0, 162, 255)
PlayerListFrame.BorderSizePixel = 2
PlayerListFrame.Position = UDim2.new(0.5, -150, 0.2, 0)
PlayerListFrame.Size = UDim2.new(0, 300, 0, 400)
PlayerListFrame.Visible = false
PlayerListFrame.Active = true
PlayerListFrame.Draggable = true

local PlayerListCorner = Instance.new("UICorner")
PlayerListCorner.CornerRadius = UDim.new(0, 12)
PlayerListCorner.Parent = PlayerListFrame

-- Player List Title
local PlayerListTitle = Instance.new("TextLabel")
PlayerListTitle.Name = "Title"
PlayerListTitle.Parent = PlayerListFrame
PlayerListTitle.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
PlayerListTitle.Position = UDim2.new(0, 0, 0, 0)
PlayerListTitle.Size = UDim2.new(1, 0, 0, 40)
PlayerListTitle.Font = Enum.Font.GothamBold
PlayerListTitle.Text = "Select Player"
PlayerListTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
PlayerListTitle.TextScaled = true

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 12)
TitleCorner.Parent = PlayerListTitle

local TitleFix = Instance.new("Frame")
TitleFix.Parent = PlayerListTitle
TitleFix.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
TitleFix.BorderSizePixel = 0
TitleFix.Position = UDim2.new(0, 0, 0.5, 0)
TitleFix.Size = UDim2.new(1, 0, 0.5, 0)

-- Close Button untuk Player List
local ClosePlayerListButton = Instance.new("TextButton")
ClosePlayerListButton.Name = "CloseButton"
ClosePlayerListButton.Parent = PlayerListFrame
ClosePlayerListButton.BackgroundTransparency = 1
ClosePlayerListButton.Position = UDim2.new(1, -35, 0, 5)
ClosePlayerListButton.Size = UDim2.new(0, 30, 0, 30)
ClosePlayerListButton.Font = Enum.Font.GothamBold
ClosePlayerListButton.Text = "×"
ClosePlayerListButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ClosePlayerListButton.TextScaled = true

-- Selected Player Display
SelectedPlayerLabel.Name = "SelectedPlayerLabel"
SelectedPlayerLabel.Parent = PlayerListFrame
SelectedPlayerLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
SelectedPlayerLabel.BorderColor3 = Color3.fromRGB(0, 162, 255)
SelectedPlayerLabel.BorderSizePixel = 1
SelectedPlayerLabel.Position = UDim2.new(0, 10, 0, 50)
SelectedPlayerLabel.Size = UDim2.new(1, -20, 0, 30)
SelectedPlayerLabel.Font = Enum.Font.Gotham
SelectedPlayerLabel.Text = "Selected: None"
SelectedPlayerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SelectedPlayerLabel.TextSize = 14

local SelectedCorner = Instance.new("UICorner")
SelectedCorner.CornerRadius = UDim.new(0, 6)
SelectedCorner.Parent = SelectedPlayerLabel

-- Player List ScrollFrame (Fixed scrolling)
PlayerListScrollFrame.Name = "PlayerListScrollFrame"
PlayerListScrollFrame.Parent = PlayerListFrame
PlayerListScrollFrame.BackgroundTransparency = 1
PlayerListScrollFrame.Position = UDim2.new(0, 10, 0, 90)
PlayerListScrollFrame.Size = UDim2.new(1, -20, 1, -100)
PlayerListScrollFrame.ScrollBarThickness = 8
PlayerListScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 162, 255)
PlayerListScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
PlayerListScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

-- Player List Layout
PlayerListLayout.Parent = PlayerListScrollFrame
PlayerListLayout.Padding = UDim.new(0, 5)
PlayerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
PlayerListLayout.FillDirection = Enum.FillDirection.Vertical

-- Logo Button (minimized state)
LogoButton.Name = "LogoButton"
LogoButton.Parent = ScreenGui
LogoButton.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
LogoButton.Position = UDim2.new(0.05, 0, 0.1, 0)
LogoButton.Size = UDim2.new(0, 50, 0, 50)
LogoButton.Font = Enum.Font.GothamBold
LogoButton.Text = "🔥"
LogoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoButton.TextScaled = true
LogoButton.Visible = false
LogoButton.Active = true
LogoButton.Draggable = true

local LogoCorner = Instance.new("UICorner")
LogoCorner.CornerRadius = UDim.new(1, 0)
LogoCorner.Parent = LogoButton

-- Feature Functions

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
                
                -- Get camera direction
                local cameraCFrame = camera.CFrame
                local forwardVector = cameraCFrame.LookVector
                local rightVector = cameraCFrame.RightVector
                local upVector = cameraCFrame.UpVector
                
                -- Calculate movement based on camera direction and player input
                local velocity = Vector3.new(0, 0, 0)
                
                -- Forward/Backward movement
                if moveVector.Magnitude > 0 then
                    velocity = velocity + (forwardVector * moveVector.Z * -50)
                    velocity = velocity + (rightVector * moveVector.X * 50)
                end
                
                -- Up/Down movement (touch controls for mobile)
                -- Check for jump button (space on PC, jump button on mobile)
                if humanoid.Jump then
                    velocity = velocity + (upVector * 50)
                    humanoid.Jump = false
                end
                
                -- Apply velocity
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

-- Jump High (Fixed untuk mobile)
local function toggleJumpHigh(enabled)
    jumpHighEnabled = enabled
    if enabled then
        humanoid.JumpHeight = 50 -- Untuk R15
        humanoid.JumpPower = 120  -- Untuk R6
        -- Backup method
        connections.jumphigh = humanoid.Jumping:Connect(function()
            if jumpHighEnabled then
                rootPart.Velocity = Vector3.new(rootPart.Velocity.X, 120, rootPart.Velocity.Z)
            end
        end)
    else
        humanoid.JumpHeight = 7.2 -- Default R15
        humanoid.JumpPower = 50   -- Default R6
        if connections.jumphigh then
            connections.jumphigh:Disconnect()
        end
    end
end

-- Spider (Wall climbing)
local function toggleSpider(enabled)
    spiderEnabled = enabled
    if enabled then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = rootPart
        
        local bodyPosition = Instance.new("BodyPosition")
        bodyPosition.MaxForce = Vector3.new(0, 4000, 0)
        bodyPosition.Parent = rootPart
        
        connections.spider = RunService.Heartbeat:Connect(function()
            if spiderEnabled then
                local camera = workspace.CurrentCamera
                local moveVector = humanoid.MoveDirection
                
                -- Raycast untuk detect wall
                local rayDirection = camera.CFrame.LookVector * 4
                local raycastParams = RaycastParams.new()
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                raycastParams.FilterDescendantsInstances = {character}
                
                local rayResult = workspace:Raycast(rootPart.Position, rayDirection, raycastParams)
                
                if rayResult and moveVector.Magnitude > 0 then
                    -- Ada wall dan player bergerak
                    local wallNormal = rayResult.Normal
                    local wallPosition = rayResult.Position
                    
                    -- Stick to wall
                    bodyPosition.Position = wallPosition + (wallNormal * 3)
                    bodyPosition.MaxForce = Vector3.new(4000, 4000, 4000)
                    
                    -- Movement along wall
                    local rightVector = camera.CFrame.RightVector
                    local upVector = Vector3.new(0, 1, 0)
                    
                    local velocity = Vector3.new(0, 0, 0)
                    velocity = velocity + (rightVector * moveVector.X * 16)
                    velocity = velocity + (upVector * moveVector.Z * -16)
                    
                    bodyVelocity.Velocity = velocity
                else
                    -- No wall, normal movement
                    bodyPosition.MaxForce = Vector3.new(0, 0, 0)
                    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                end
            end
        end)
    else
        if connections.spider then
            connections.spider:Disconnect()
        end
        if rootPart:FindFirstChild("BodyVelocity") then
            rootPart:FindFirstChild("BodyVelocity"):Destroy()
        end
        if rootPart:FindFirstChild("BodyPosition") then
            rootPart:FindFirstChild("BodyPosition"):Destroy()
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

-- Freecam (Camera only movement)
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
        
        -- Freeze character
        if rootPart then
            rootPart.Anchored = true
        end
        
        connections.freecam = RunService.Heartbeat:Connect(function()
            if freecamEnabled and freecamPart then
                local camera = workspace.CurrentCamera
                local moveVector = humanoid.MoveDirection
                
                -- Get input for movement
                local velocity = Vector3.new(0, 0, 0)
                local speed = 50
                
                if moveVector.Magnitude > 0 then
                    local forwardVector = camera.CFrame.LookVector
                    local rightVector = camera.CFrame.RightVector
                    local upVector = camera.CFrame.UpVector
                    
                    velocity = velocity + (forwardVector * moveVector.Z * -speed)
                    velocity = velocity + (rightVector * moveVector.X * speed)
                end
                
                -- Up/Down movement
                if humanoid.Jump then
                    velocity = velocity + Vector3.new(0, speed, 0)
                    humanoid.Jump = false
                end
                
                -- Apply movement to freecam part
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
        
        -- Unfreeze character
        if rootPart then
            rootPart.Anchored = false
        end
    end
end

-- Save/Load Position
local function savePosition()
    if rootPart then
        savedPosition = rootPart.CFrame
        -- Simple notification
        print("Position Saved!")
    end
end

local function loadPosition()
    if savedPosition and rootPart then
        rootPart.CFrame = savedPosition
        print("Teleported to saved position!")
    else
        print("No saved position found!")
    end
end

local function tpToFreecam()
    if freecamPart and rootPart then
        rootPart.CFrame = freecamPart.CFrame
        print("Teleported to freecam position!")
    else
        print("Freecam not active!")
    end
end

-- Player functions
local function showPlayerSelection()
    playerListVisible = true
    PlayerListFrame.Visible = true
    updatePlayerList()
end

local function updatePlayerList()
    -- Clear existing player buttons
    for _, child in pairs(PlayerListScrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    local buttonCount = 0
    
    -- Add players to list
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            local playerButton = Instance.new("TextButton")
            playerButton.Name = p.Name .. "Button"
            playerButton.Parent = PlayerListScrollFrame
            playerButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            playerButton.BorderColor3 = Color3.fromRGB(0, 162, 255)
            playerButton.BorderSizePixel = 1
            playerButton.Size = UDim2.new(1, -10, 0, 35)
            playerButton.Font = Enum.Font.Gotham
            playerButton.Text = p.Name
            playerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            playerButton.TextSize = 14
            playerButton.LayoutOrder = buttonCount
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = playerButton
            
            -- Player selection
            playerButton.MouseButton1Click:Connect(function()
                selectedPlayer = p
                SelectedPlayerLabel.Text = "Selected: " .. p.Name
                PlayerListFrame.Visible = false
                playerListVisible = false
                print("Selected player: " .. p.Name)
                
                -- Visual feedback
                for _, btn in pairs(PlayerListScrollFrame:GetChildren()) do
                    if btn:IsA("TextButton") then
                        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                    end
                end
                playerButton.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
            end)
            
            -- Hover effects
            playerButton.MouseEnter:Connect(function()
                if playerButton.BackgroundColor3 ~= Color3.fromRGB(0, 162, 255) then
                    playerButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                end
            end)
            
            playerButton.MouseLeave:Connect(function()
                if selectedPlayer ~= p then
                    playerButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                end
            end)
            
            buttonCount = buttonCount + 1
        end
    end
    
    -- Update canvas size for scrolling
    wait(0.1)
    local contentSize = PlayerListLayout.AbsoluteContentSize
    PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 20)
    
    print("Updated player list: " .. buttonCount .. " players")
end

local function spectateSelectedPlayer()
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("Humanoid") then
        workspace.CurrentCamera.CameraSubject = selectedPlayer.Character.Humanoid
        print("Spectating: " .. selectedPlayer.Name)
    else
        print("Please select a player first!")
    end
end

local function tpToSelectedPlayer()
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and rootPart then
        rootPart.CFrame = selectedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
        print("Teleported to: " .. selectedPlayer.Name)
    else
        print("Please select a player first!")
    end
end

local function spectatePlayer()
    local players = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(players, p)
        end
    end
    
    if #players > 0 then
        spectateIndex = ((spectateIndex - 1) % #players) + 1
        local targetPlayer = players[spectateIndex]
        if targetPlayer and targetPlayer.Character then
            workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
            selectedPlayer = targetPlayer
            SelectedPlayerLabel.Text = "Selected: " .. targetPlayer.Name
            print("Auto spectating: " .. targetPlayer.Name)
        end
    end
end

local function nextSpectate()
    spectateIndex = spectateIndex + 1
    spectatePlayer()
end

local function prevSpectate()
    spectateIndex = spectateIndex - 1
    spectatePlayer()
end

local function stopSpectate()
    workspace.CurrentCamera.CameraSubject = humanoid
    print("Stopped spectating")
end

-- Function to create buttons
local function createButton(name, callback)
    local button = Instance.new("TextButton")
    button.Name = name .. "Button"
    button.Parent = ScrollFrame
    button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    button.BorderColor3 = Color3.fromRGB(0, 162, 255)
    button.BorderSizePixel = 1
    button.Size = UDim2.new(1, 0, 0, 35)
    button.Font = Enum.Font.Gotham
    button.Text = name
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 14
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    button.MouseButton1Click:Connect(callback)
    
    return button
end

-- Function to create toggle buttons
local function createToggleButton(name, callback)
    local button = Instance.new("TextButton")
    button.Name = name .. "Button"
    button.Parent = ScrollFrame
    button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    button.BorderColor3 = Color3.fromRGB(0, 162, 255)
    button.BorderSizePixel = 1
    button.Size = UDim2.new(1, 0, 0, 35)
    button.Font = Enum.Font.Gotham
    button.Text = name .. " [OFF]"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 14
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    local isToggled = false
    
    local function updateButton()
        if isToggled then
            button.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
            button.Text = name .. " [ON]"
        else
            button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            button.Text = name .. " [OFF]"
        end
    end
    
    button.MouseButton1Click:Connect(function()
        isToggled = not isToggled
        updateButton()
        callback(isToggled)
    end)
    
    updateButton()
    return button
end

-- Function to create category buttons
local function createCategoryButton(name, icon)
    local button = Instance.new("TextButton")
    button.Name = name .. "Category"
    button.Parent = CategoryFrame
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -10, 0, 40)
    button.Font = Enum.Font.Gotham
    button.Text = icon .. " " .. name
    button.TextColor3 = Color3.fromRGB(200, 200, 200)
    button.TextSize = 12
    button.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Padding untuk text
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 8)
    padding.Parent = button
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    button.MouseButton1Click:Connect(function()
        switchCategory(name)
    end)
    
    return button
end

-- Function to clear buttons
local function clearButtons()
    for _, child in pairs(ScrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

-- Function to load category buttons
local function loadMovementButtons()
    createToggleButton("Fly", toggleFly)
    createToggleButton("Noclip", toggleNoclip)
    createToggleButton("Speed", toggleSpeed)
    createToggleButton("Jump High", toggleJumpHigh)
    createToggleButton("Spider", toggleSpider)
end

local function loadPlayerButtons()
    createButton("Select Player", showPlayerSelection)
    createToggleButton("God Mode", toggleGodMode)
    createToggleButton("Anti AFK", toggleAntiAFK)
    createButton("Spectate Selected", spectateSelectedPlayer)
    createButton("Auto Spectate", spectatePlayer)
    createButton("Next Spectate", nextSpectate)
    createButton("Prev Spectate", prevSpectate)
    createButton("Stop Spectate", stopSpectate)
end

local function loadVisualButtons()
    createToggleButton("Fullbright", toggleFullbright)
    createToggleButton("Freecam", toggleFreecam)
end

local function loadTeleportButtons()
    createButton("Save Position", savePosition)
    createButton("TP to Saved Position", loadPosition)
    createButton("TP to Selected Player", tpToSelectedPlayer)
    createButton("TP to Freecam", tpToFreecam)
end

local function loadUtilityButtons()
    createButton("Disable Previous Script", function()
        for _, gui in pairs(CoreGui:GetChildren()) do
            if gui.Name == "ModernHackGUI" and gui ~= ScreenGui then
                gui:Destroy()
            end
        end
        print("Disabled previous scripts")
    end)
end

-- Function to switch categories (KRNL Compatible)
function switchCategory(categoryName)
    currentCategory = categoryName
    print("Switching to category: " .. categoryName)
    
    -- Update category button colors
    for _, child in pairs(CategoryFrame:GetChildren()) do
        if child:IsA("TextButton") then
            if child.Name == categoryName .. "Category" then
                child.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
                child.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                child.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                child.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
    end
    
    -- Clear current buttons
    clearButtons()
    
    -- Load category-specific buttons
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
    
    -- Update canvas size
    wait(0.1)
    local contentSize = UIListLayout.AbsoluteContentSize
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 10)
    
    print("Loaded " .. categoryName .. " buttons")
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
createCategoryButton("Movement", "🏃")
createCategoryButton("Player", "👤")
createCategoryButton("Visual", "👁️")
createCategoryButton("Teleport", "📍")
createCategoryButton("Utility", "🔧")

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
    spiderEnabled = false
    freecamEnabled = false
    
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

print("=== Modern Hack GUI Loaded (KRNL Compatible) ===")
print("🏃 Movement | 👤 Player | 👁️ Visual | 📍 Teleport | 🔧 Utility")
print("Click categories on the left to switch features")
print("Click 'Select Player' in Player category to choose targets")
print("GUI is ready to use!")