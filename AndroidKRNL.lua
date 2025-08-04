-- AndroidKRNL.lua - Complete Android Script for Fluxus
-- Copy and paste this entire file into Fluxus

print("🚀 Loading Android KRNL...")

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Variables
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid, hr, char
local gui, frame, logo
local flying, noclip, godMode = false, false, false
local speedEnabled, jumpEnabled = false, false
local moveSpeed = 50
local jumpPower = 100
local flySpeed = 40

-- Connections
local connections = {}

-- Notify function
local function notify(message, color)
    if not gui then
        print("Notify: " .. message)
        return
    end
    local notif = Instance.new("TextLabel")
    notif.Size = UDim2.new(0, 350, 0, 60)
    notif.Position = UDim2.new(0.5, -175, 0.1, 0)
    notif.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    notif.BackgroundTransparency = 0.4
    notif.TextColor3 = color or Color3.fromRGB(0, 255, 0)
    notif.TextSize = 18
    notif.Font = Enum.Font.Gotham
    notif.Text = message
    notif.TextWrapped = true
    notif.BorderSizePixel = 0
    notif.ZIndex = 20
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = notif
    notif.Parent = gui
    task.spawn(function()
        task.wait(3)
        notif:Destroy()
    end)
end

-- Get character
local function getChar()
    if not player.Character then
        notify("⚠️ Character not loaded", Color3.fromRGB(255, 100, 100))
        return nil, nil, nil
    end
    local char = player.Character
    local humanoid = char:FindFirstChild("Humanoid")
    local hr = char:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not hr then
        notify("⚠️ Humanoid or HumanoidRootPart not found", Color3.fromRGB(255, 100, 100))
        return nil, nil, nil
    end
    
    return char, humanoid, hr
end

-- Toggle Fly
local function toggleFly()
    local char, humanoid, hr = getChar()
    if not char then return end
    
    flying = not flying
    
    if flying then
        -- Create BodyVelocity for flying
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent = hr
        
        -- Fly connection
        connections.fly = RunService.RenderStepped:Connect(function()
            if not hr or not humanoid then
                flying = false
                if connections.fly then
                    connections.fly:Disconnect()
                    connections.fly = nil
                end
                if hr and hr:FindFirstChildOfClass("BodyVelocity") then
                    hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
                end
                return
            end
            
            -- Simple WASD movement
            local moveVector = Vector3.new(0, 0, 0)
            
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveVector = moveVector + camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveVector = moveVector - camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveVector = moveVector - camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveVector = moveVector + camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveVector = moveVector + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                moveVector = moveVector + Vector3.new(0, -1, 0)
            end
            
            if moveVector.Magnitude > 0 then
                moveVector = moveVector.Unit * flySpeed
            end
            
            bv.Velocity = moveVector
        end)
        
        notify("🛫 Fly Enabled (WASD + Space/Shift)", Color3.fromRGB(0, 255, 0))
    else
        if connections.fly then
            connections.fly:Disconnect()
            connections.fly = nil
        end
        if hr and hr:FindFirstChildOfClass("BodyVelocity") then
            hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
        end
        notify("🛬 Fly Disabled", Color3.fromRGB(255, 100, 100))
    end
end

-- Toggle Speed
local function toggleSpeed()
    local char, humanoid, hr = getChar()
    if not char then return end
    
    speedEnabled = not speedEnabled
    
    if speedEnabled then
        humanoid.WalkSpeed = moveSpeed
        notify("🏃 Speed Enabled (" .. moveSpeed .. ")", Color3.fromRGB(0, 255, 0))
    else
        humanoid.WalkSpeed = 16
        notify("🏃 Speed Disabled", Color3.fromRGB(255, 100, 100))
    end
end

-- Toggle Jump Power
local function toggleJump()
    local char, humanoid, hr = getChar()
    if not char then return end
    
    jumpEnabled = not jumpEnabled
    
    if jumpEnabled then
        humanoid.JumpPower = jumpPower
        notify("🦘 Jump Power Enabled (" .. jumpPower .. ")", Color3.fromRGB(0, 255, 0))
    else
        humanoid.JumpPower = 50
        notify("🦘 Jump Power Disabled", Color3.fromRGB(255, 100, 100))
    end
end

-- Toggle Noclip
local function toggleNoclip()
    local char, humanoid, hr = getChar()
    if not char then return end
    
    noclip = not noclip
    
    if noclip then
        connections.noclip = RunService.Stepped:Connect(function()
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
        notify("🚪 Noclip Enabled", Color3.fromRGB(0, 255, 0))
    else
        if connections.noclip then
            connections.noclip:Disconnect()
            connections.noclip = nil
        end
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
        notify("🚪 Noclip Disabled", Color3.fromRGB(255, 100, 100))
    end
end

-- Toggle God Mode
local function toggleGodMode()
    local char, humanoid, hr = getChar()
    if not char then return end
    
    godMode = not godMode
    
    if godMode then
        humanoid.MaxHealth = math.huge
        humanoid.Health = math.huge
        connections.godMode = humanoid.HealthChanged:Connect(function(health)
            if health < math.huge then
                humanoid.Health = math.huge
            end
        end)
        notify("🛡️ God Mode Enabled", Color3.fromRGB(0, 255, 0))
    else
        if connections.godMode then
            connections.godMode:Disconnect()
            connections.godMode = nil
        end
        humanoid.MaxHealth = 100
        humanoid.Health = 100
        notify("🛡️ God Mode Disabled", Color3.fromRGB(255, 100, 100))
    end
end

-- Teleport to spawn
local function teleportToSpawn()
    local char, humanoid, hr = getChar()
    if not char then return end
    
    local spawnLocation = workspace:FindFirstChildOfClass("SpawnLocation")
    local targetPos = spawnLocation and spawnLocation.Position or Vector3.new(0, 5, 0)
    hr.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
    notify("🚪 Teleported to Spawn", Color3.fromRGB(0, 255, 255))
end

-- Teleport to player
local function teleportToPlayer()
    local char, humanoid, hr = getChar()
    if not char then return end
    
    -- Get first player that's not you
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local targetPos = plr.Character.HumanoidRootPart.Position
            hr.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
            notify("🚀 Teleported to " .. plr.Name, Color3.fromRGB(0, 255, 255))
            return
        end
    end
    notify("⚠️ No other players found", Color3.fromRGB(255, 100, 100))
end

-- Create Mobile GUI
local function createMobileGUI()
    -- Clean up old GUI
    local oldGui = player.PlayerGui:FindFirstChild("AndroidKRNL")
    if oldGui then
        oldGui:Destroy()
    end
    
    -- Create new GUI
    gui = Instance.new("ScreenGui")
    gui.Name = "AndroidKRNL"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui", 10)
    
    -- Create floating action button (FAB)
    logo = Instance.new("TextButton")
    logo.Size = UDim2.new(0, 80, 0, 80)
    logo.Position = UDim2.new(0.85, 0, 0.8, 0)
    logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
    logo.TextColor3 = Color3.fromRGB(255, 255, 255)
    logo.Text = "⚡"
    logo.TextSize = 30
    logo.Font = Enum.Font.GothamBold
    logo.ZIndex = 100
    logo.Parent = gui
    
    -- Make FAB circular
    local fabCorner = Instance.new("UICorner")
    fabCorner.CornerRadius = UDim2.new(0, 40)
    fabCorner.Parent = logo
    
    -- Create main panel (hidden by default)
    frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 320, 0, 500)
    frame.Position = UDim2.new(0.5, -160, 0.5, -250)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.ZIndex = 50
    frame.Parent = gui
    
    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 15)
    panelCorner.Parent = frame
    
    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 60)
    header.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
    header.BorderSizePixel = 0
    header.ZIndex = 51
    header.Parent = frame
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 15)
    headerCorner.Parent = header
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.Text = "Android KRNL"
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 52
    title.Parent = header
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.Position = UDim2.new(1, -50, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Text = "×"
    closeBtn.TextSize = 24
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.ZIndex = 52
    closeBtn.Parent = header
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 20)
    closeCorner.Parent = closeBtn
    
    -- Content area
    local contentArea = Instance.new("Frame")
    contentArea.Size = UDim2.new(1, -20, 1, -80)
    contentArea.Position = UDim2.new(0, 10, 0, 70)
    contentArea.BackgroundTransparency = 1
    contentArea.ZIndex = 51
    contentArea.Parent = frame
    
    -- Scroll frame
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    scrollFrame.ZIndex = 51
    scrollFrame.ClipsDescendants = true
    scrollFrame.ScrollingEnabled = true
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Parent = contentArea
    
    local scrollUIL = Instance.new("UIListLayout")
    scrollUIL.FillDirection = Enum.FillDirection.Vertical
    scrollUIL.Padding = UDim.new(0, 8)
    scrollUIL.Parent = scrollFrame
    
    -- Function to create mobile-friendly buttons
    local function createMobileButton(text, callback, color, icon)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 0, 60)
        button.BackgroundColor3 = color or Color3.fromRGB(40, 40, 40)
        button.BackgroundTransparency = 0.1
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 18
        button.Font = Enum.Font.GothamBold
        button.Text = icon .. " " .. text
        button.TextXAlignment = Enum.TextXAlignment.Left
        button.ZIndex = 52
        button.Parent = scrollFrame
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 10)
        buttonCorner.Parent = button
        
        button.MouseButton1Click:Connect(function()
            local success, err = pcall(callback)
            if not success then
                notify("⚠️ Error: " .. tostring(err), Color3.fromRGB(255, 100, 100))
            end
        end)
        
        return button
    end
    
    -- Add all feature buttons
    createMobileButton("Toggle Fly", toggleFly, Color3.fromRGB(0, 150, 255), "🛫")
    createMobileButton("Toggle Speed", toggleSpeed, Color3.fromRGB(0, 150, 255), "🏃")
    createMobileButton("Toggle Jump Power", toggleJump, Color3.fromRGB(0, 150, 255), "🦘")
    createMobileButton("Toggle Noclip", toggleNoclip, Color3.fromRGB(0, 150, 255), "🚪")
    createMobileButton("Toggle God Mode", toggleGodMode, Color3.fromRGB(0, 150, 255), "🛡️")
    createMobileButton("Teleport to Spawn", teleportToSpawn, Color3.fromRGB(0, 150, 0), "🚪")
    createMobileButton("Teleport to Player", teleportToPlayer, Color3.fromRGB(150, 0, 150), "👥")
    
    -- FAB functionality
    logo.MouseButton1Click:Connect(function()
        frame.Visible = not frame.Visible
        notify(frame.Visible and "📱 GUI Opened" or "📱 GUI Closed")
        
        -- Animate FAB
        if frame.Visible then
            logo.Text = "✕"
            logo.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        else
            logo.Text = "⚡"
            logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        end
    end)
    
    -- Close button functionality
    closeBtn.MouseButton1Click:Connect(function()
        frame.Visible = false
        logo.Text = "⚡"
        logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        notify("📱 GUI Closed")
    end)
    
    notify("📱 Android KRNL GUI created successfully")
    print("✅ Android KRNL loaded! Tap the ⚡ button to open menu")
end

-- Initialize character when loaded
player.CharacterAdded:Connect(function()
    task.wait(2)
    local char, humanoid, hr = getChar()
    if char then
        notify("✅ Character loaded - All features ready", Color3.fromRGB(0, 255, 0))
    end
end)

-- Create GUI
createMobileGUI()

-- Initialize character if already exists
if player.Character then
    task.wait(1)
    local char, humanoid, hr = getChar()
    if char then
        notify("✅ Character loaded - All features ready", Color3.fromRGB(0, 255, 0))
    end
end

print("🎉 Android KRNL fully loaded!")
print("📱 Look for the ⚡ button in the bottom-right corner")
print("🎮 Features: Fly, Speed, Jump, Noclip, God Mode, Teleport") 