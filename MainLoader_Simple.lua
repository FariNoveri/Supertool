-- Simplified MainLoader - Core GUI Only
-- This version focuses on getting the basic GUI working first

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid, hr, char
local gui, frame, logo

-- Basic feature states
local flying, noclip, speedEnabled, jumpEnabled, godMode = false, false, false, false, false
local flySpeed = 40
local moveSpeed = 50
local jumpPower = 100

-- Drag function for any GUI element
local function makeDraggable(guiElement, dragHandle)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    local function updateDrag(input)
        local delta = input.Position - dragStart
        guiElement.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
    
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiElement.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                updateDrag(input)
            end
        end
    end)
    
    dragHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- Notify function
local function notify(message, color)
    local success, errorMsg = pcall(function()
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
    end)
    if not success then
        print("Notify error: " .. tostring(errorMsg))
    end
end

-- Get character function
local function getChar()
    if player.Character then
        char = player.Character
        humanoid = char:FindFirstChild("Humanoid")
        hr = char:FindFirstChild("HumanoidRootPart")
        return char, humanoid, hr
    end
    return nil, nil, nil
end

-- Basic feature functions
local function toggleFly()
    flying = not flying
    local success, errorMsg = pcall(function()
        if flying then
            if not hr or not humanoid then
                flying = false
                error("Character not loaded")
            end
            
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = hr
            
            local connection
            connection = RunService.RenderStepped:Connect(function()
                if not hr or not humanoid then
                    flying = false
                    if connection then
                        connection:Disconnect()
                    end
                    if hr and hr:FindFirstChildOfClass("BodyVelocity") then
                        hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
                    end
                    notify("⚠️ Fly failed: Character lost", Color3.fromRGB(255, 100, 100))
                    return
                end
                
                local forward = camera.CFrame.LookVector
                local right = camera.CFrame.RightVector
                local moveDir = Vector3.new(0, 0, 0)
                
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveDir = moveDir + forward
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveDir = moveDir - forward
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveDir = moveDir - right
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveDir = moveDir + right
                end
                
                if moveDir.Magnitude > 0 then
                    moveDir = moveDir.Unit * flySpeed
                end
                
                bv.Velocity = moveDir
            end)
            notify("🛫 Fly Enabled")
        else
            if hr and hr:FindFirstChildOfClass("BodyVelocity") then
                hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
            end
            notify("🛬 Fly Disabled")
        end
    end)
    if not success then
        flying = false
        notify("⚠️ Fly error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleSpeed()
    speedEnabled = not speedEnabled
    local success, errorMsg = pcall(function()
        if speedEnabled then
            if humanoid then
                humanoid.WalkSpeed = moveSpeed
            end
            notify("🏃 Speed Enabled")
        else
            if humanoid then
                humanoid.WalkSpeed = 16
            end
            notify("🏃 Speed Disabled")
        end
    end)
    if not success then
        speedEnabled = false
        notify("⚠️ Speed error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleJump()
    jumpEnabled = not jumpEnabled
    local success, errorMsg = pcall(function()
        if jumpEnabled then
            if humanoid then
                humanoid.JumpPower = jumpPower
            end
            notify("🦘 Jump Enabled")
        else
            if humanoid then
                humanoid.JumpPower = 50
            end
            notify("🦘 Jump Disabled")
        end
    end)
    if not success then
        jumpEnabled = false
        notify("⚠️ Jump error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleNoclip()
    noclip = not noclip
    local success, errorMsg = pcall(function()
        if noclip then
            local connection
            connection = RunService.Stepped:Connect(function()
                if char then
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                else
                    if connection then
                        connection:Disconnect()
                    end
                    noclip = false
                end
            end)
            notify("🚪 Noclip Enabled")
        else
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
            notify("🚪 Noclip Disabled")
        end
    end)
    if not success then
        noclip = false
        notify("⚠️ Noclip error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleGodMode()
    godMode = not godMode
    local success, errorMsg = pcall(function()
        if godMode then
            if humanoid then
                humanoid.MaxHealth = math.huge
                humanoid.Health = math.huge
            end
            local connection
            connection = humanoid.HealthChanged:Connect(function(health)
                if health < math.huge then
                    humanoid.Health = math.huge
                end
            end)
            notify("🛡️ God Mode Enabled")
        else
            if humanoid then
                humanoid.MaxHealth = 100
                humanoid.Health = 100
            end
            notify("🛡️ God Mode Disabled")
        end
    end)
    if not success then
        godMode = false
        notify("⚠️ God Mode error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function teleportToSpawn()
    local success, errorMsg = pcall(function()
        if hr then
            local spawnLocation = workspace:FindFirstChildOfClass("SpawnLocation")
            local targetPos = spawnLocation and spawnLocation.Position or Vector3.new(0, 5, 0)
            hr.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
            notify("🚪 Teleported to Spawn")
        else
            notify("⚠️ Character not loaded", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Teleport error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Create GUI function
local function createGUI()
    print("🔧 Starting GUI creation...")
    local success, errorMsg = pcall(function()
        -- Clean up old GUI
        local oldGui = player.PlayerGui:FindFirstChild("MainLoaderGUI")
        if oldGui then
            oldGui:Destroy()
            print("🗑️ Cleaned up old GUI")
        end
        
        print("📱 Creating ScreenGui...")
        -- Create new GUI
        gui = Instance.new("ScreenGui")
        gui.Name = "MainLoaderGUI"
        gui.ResetOnSpawn = false
        gui.Parent = player:WaitForChild("PlayerGui", 10)
        
        if not gui then
            error("Failed to create ScreenGui")
        end
        
        print("✅ ScreenGui created successfully")
        
        print("🎯 Creating logo button...")
        -- Create main logo button (draggable)
        logo = Instance.new("TextButton")
        logo.Size = UDim2.new(0, 80, 0, 80)
        logo.Position = UDim2.new(0.85, 0, 0.8, 0)
        logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        logo.TextColor3 = Color3.fromRGB(255, 255, 255)
        logo.Text = "⚡"
        logo.TextSize = 30
        logo.Font = Enum.Font.GothamBold
        logo.ZIndex = 100
        logo.Visible = true
        logo.Parent = gui
        
        if not logo then
            error("Failed to create logo button")
        end
        
        print("✅ Logo button created successfully")
        
        -- Make logo circular
        local logoCorner = Instance.new("UICorner")
        logoCorner.CornerRadius = UDim.new(0, 40)
        logoCorner.Parent = logo
        
        -- Make logo draggable
        makeDraggable(logo, logo)
        
        print("📋 Creating main frame...")
        -- Create main frame (hidden by default, draggable)
        frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 320, 0, 500)
        frame.Position = UDim2.new(0.5, -160, 0.5, -250)
        frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        frame.BackgroundTransparency = 0.1
        frame.BorderSizePixel = 0
        frame.Visible = false
        frame.ZIndex = 50
        frame.Parent = gui
        
        local frameCorner = Instance.new("UICorner")
        frameCorner.CornerRadius = UDim.new(0, 15)
        frameCorner.Parent = frame
        
        -- Header (draggable handle)
        local header = Instance.new("Frame")
        header.Size = UDim2.new(1, 0, 0, 60)
        header.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        header.BorderSizePixel = 0
        header.ZIndex = 51
        header.Parent = frame
        
        local headerCorner = Instance.new("UICorner")
        headerCorner.CornerRadius = UDim.new(0, 15)
        headerCorner.Parent = header
        
        -- Make frame draggable by header
        makeDraggable(frame, header)
        
        -- Title
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -60, 1, 0)
        title.Position = UDim2.new(0, 20, 0, 0)
        title.BackgroundTransparency = 1
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 24
        title.Font = Enum.Font.GothamBold
        title.Text = "MainLoader"
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
        
        -- Function to create buttons
        local function createButton(text, callback, color, icon)
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
        
        print("🔘 Creating feature buttons...")
        -- Add feature buttons
        createButton("Toggle Fly", toggleFly, Color3.fromRGB(0, 150, 255), "🛫")
        createButton("Toggle Speed", toggleSpeed, Color3.fromRGB(0, 150, 255), "🏃")
        createButton("Toggle Jump Power", toggleJump, Color3.fromRGB(0, 150, 255), "🦘")
        createButton("Toggle Noclip", toggleNoclip, Color3.fromRGB(0, 150, 255), "🚪")
        createButton("Toggle God Mode", toggleGodMode, Color3.fromRGB(0, 150, 255), "🛡️")
        createButton("Teleport to Spawn", teleportToSpawn, Color3.fromRGB(0, 150, 0), "🚪")
        
        print("🔗 Setting up logo functionality...")
        -- Logo functionality
        logo.MouseButton1Click:Connect(function()
            frame.Visible = not frame.Visible
            notify(frame.Visible and "📱 GUI Opened" or "📱 GUI Closed")
            
            -- Animate logo
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
        
        print("✅ GUI created successfully")
        notify("✅ MainLoader GUI created successfully")
        
    end)
    
    if not success then
        print("❌ GUI creation failed: " .. tostring(errorMsg))
        notify("❌ GUI creation failed: " .. tostring(errorMsg), Color3.fromRGB(255, 0, 0))
    end
end

-- Initialize character
local function initChar()
    local success, errorMsg = pcall(function()
        if player.Character then
            char = player.Character
            humanoid = char:WaitForChild("Humanoid", 10)
            hr = char:WaitForChild("HumanoidRootPart", 10)
            
            if humanoid and hr then
                notify("✅ Character loaded - All features ready", Color3.fromRGB(0, 255, 0))
            else
                notify("⚠️ Character parts not found", Color3.fromRGB(255, 255, 0))
            end
        else
            notify("⚠️ Character not loaded", Color3.fromRGB(255, 255, 0))
        end
    end)
    if not success then
        print("initChar error: " .. tostring(errorMsg))
    end
end

-- Main function
local function main()
    print("🚀 Starting Simplified MainLoader...")
    
    -- Create GUI
    createGUI()
    
    -- Initialize character if exists
    if player.Character then
        task.wait(1)
        initChar()
    end
    
    -- Connect character respawn
    player.CharacterAdded:Connect(function()
        task.wait(2)
        initChar()
    end)
    
    print("🎉 Simplified MainLoader loaded!")
    print("📱 Look for the ⚡ button in the bottom-right corner")
    print("🎮 Basic Features: Fly, Speed, Jump, Noclip, God Mode, Teleport")
    
    -- Test notification
    task.wait(1)
    notify("✅ Simplified MainLoader Ready! Tap ⚡ button", Color3.fromRGB(0, 255, 0))
    
    -- Additional test to ensure GUI is visible
    task.wait(2)
    if logo and logo.Visible then
        print("✅ Logo is visible and ready!")
        notify("🎯 Logo button is visible - Click it to open GUI!", Color3.fromRGB(0, 255, 255))
    else
        print("⚠️ Logo might not be visible")
        notify("⚠️ Logo button may not be visible - Check console for errors", Color3.fromRGB(255, 255, 0))
    end
end

main() 