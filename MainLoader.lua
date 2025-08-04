-- MOBILE-ONLY KRNL UI SCRIPT v2.0
-- Optimized 100% for Android devices
-- No PC/Desktop support - Pure Mobile Experience

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid, hr, char
local gui, frame, logo, joystickFrame, cameraControlFrame, playerListFrame, positionListFrame
local selectedPlayer = nil
local spectatingPlayer = nil
local flying, freecam, noclip, godMode = false, false, false, false
local flySpeed = 25 -- Mobile optimized speed
local freecamSpeed = 20 -- Mobile optimized speed
local cameraRotationSensitivity = 0.015 -- Mobile optimized sensitivity
local speedEnabled, jumpEnabled, waterWalk, rocket, spin = false, false, false, false, false
local moveSpeed = 40 -- Mobile optimized
local jumpPower = 80 -- Mobile optimized
local spinSpeed = 15 -- Mobile optimized

-- Enhanced position saving system
local savedPositions = {}
local positionCounter = 0
local maxSavedPositions = 30 -- Reduced for mobile

-- Enhanced macro system
local macroRecording, macroPlaying, autoPlayOnRespawn, recordOnRespawn = false, false, false, false
local macroActions = {}
local macroSuccessfulActions = {}
local macroSuccessfulEndTime = nil
local currentAttempt = 1
local totalAttempts = 0
local practiceMode = false

-- MOBILE ONLY - Force mobile detection
local isMobile = true -- Always true for this mobile version
local freecamCFrame = nil
local hrCFrame = nil
local joystickTouch = nil
local cameraTouch = nil
local joystickRadius = 60 -- Larger for mobile
local joystickDeadzone = 0.2 -- Larger deadzone for touch
local moveDirection = Vector3.new(0, 0, 0)
local cameraDelta = Vector2.new(0, 0)
local nickHidden, randomNick = false, false
local customNick = "MobileUser"
local freezeMovingParts = false
local originalCFrames = {}

local connections = {}
local currentCategory = "Movement"

-- Mobile-specific UI scaling
local mobileScale = math.min(camera.ViewportSize.X / 800, camera.ViewportSize.Y / 600)

-- Enhanced mobile notification system
local function notify(message, color)
    local success, errorMsg = pcall(function()
        if not gui then
            print("Mobile Notify: " .. message)
            return
        end
        
        local notif = Instance.new("TextLabel")
        notif.Size = UDim2.new(0, 320, 0, 70) -- Larger for mobile
        notif.Position = UDim2.new(0.5, -160, 0.15, 0) -- Higher position for mobile
        notif.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        notif.BackgroundTransparency = 0.2
        notif.TextColor3 = color or Color3.fromRGB(0, 255, 100)
        notif.TextSize = 16 -- Larger text for mobile
        notif.Font = Enum.Font.GothamBold
        notif.Text = message
        notif.TextWrapped = true
        notif.BorderSizePixel = 0
        notif.ZIndex = 50
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = notif
        
        local shadow = Instance.new("Frame")
        shadow.Size = UDim2.new(1, 4, 1, 4)
        shadow.Position = UDim2.new(0, -2, 0, -2)
        shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        shadow.BackgroundTransparency = 0.8
        shadow.ZIndex = 49
        local shadowCorner = Instance.new("UICorner")
        shadowCorner.CornerRadius = UDim.new(0, 12)
        shadowCorner.Parent = shadow
        shadow.Parent = notif
        
        notif.Parent = gui
        
        -- Animate in
        notif.BackgroundTransparency = 1
        notif.TextTransparency = 1
        local tween = TweenService:Create(notif, TweenInfo.new(0.3), {BackgroundTransparency = 0.2, TextTransparency = 0})
        tween:Play()
        
        task.spawn(function()
            task.wait(4) -- Longer display time for mobile
            local fadeOut = TweenService:Create(notif, TweenInfo.new(0.5), {BackgroundTransparency = 1, TextTransparency = 1})
            fadeOut:Play()
            fadeOut.Completed:Connect(function()
                notif:Destroy()
            end)
        end)
    end)
    if not success then
        print("Mobile Notify error: " .. tostring(errorMsg))
    end
end

-- Clear connections
local function clearConnections()
    for key, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
            connections[key] = nil
        end
    end
end

-- Mobile-optimized position validation
local function isValidPosition(pos)
    return pos and not (pos.Y < -500 or pos.Y > 5000 or math.abs(pos.X) > 5000 or math.abs(pos.Z) > 5000)
end

-- Mobile character initialization
local function initChar()
    local success, errorMsg = pcall(function()
        local retryCount = 0
        while not player.Character and retryCount < 3 do
            notify("📱 Loading character... (" .. (retryCount + 1) .. "/3)", Color3.fromRGB(255, 255, 100))
            player.CharacterAdded:Wait()
            task.wait(1.5)
            retryCount = retryCount + 1
        end
        
        if not player.Character then
            error("Character failed to load")
        end
        
        char = player.Character
        humanoid = char:WaitForChild("Humanoid", 15)
        hr = char:WaitForChild("HumanoidRootPart", 15)
        
        if not humanoid or not hr then
            error("Failed to find Humanoid or HumanoidRootPart")
        end
        
        -- Mobile-specific character setup
        humanoid.PlatformStand = false
        if hr then
            hr.Anchored = false
        end
        
        task.wait(0.5)
        notify("📱 Character loaded successfully!", Color3.fromRGB(0, 255, 0))
    end)
    
    if not success then
        notify("⚠️ Character load failed: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
        task.wait(3)
        initChar()
    end
end

-- Mobile-optimized fly function
local function toggleFly()
    flying = not flying
    local success, errorMsg = pcall(function()
        if flying then
            if freecam then
                toggleFreecam()
                notify("📷 Freecam disabled for Fly", Color3.fromRGB(255, 150, 0))
            end
            
            if not hr or not humanoid or not camera then
                flying = false
                error("Character not ready")
            end
            
            joystickFrame.Visible = true
            cameraControlFrame.Visible = true
            
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(4000, 4000, 4000) -- Mobile optimized
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = hr
            
            connections.fly = RunService.Heartbeat:Connect(function() -- Changed to Heartbeat for mobile
                if not hr or not humanoid or not camera then
                    flying = false
                    if connections.fly then
                        connections.fly:Disconnect()
                        connections.fly = nil
                    end
                    joystickFrame.Visible = false
                    cameraControlFrame.Visible = false
                    notify("⚠️ Fly stopped - character lost", Color3.fromRGB(255, 100, 100))
                    return
                end
                
                local forward = camera.CFrame.LookVector
                local right = camera.CFrame.RightVector
                local up = Vector3.new(0, 1, 0)
                local moveDir = moveDirection.X * right + moveDirection.Z * forward
                
                if moveDir.Magnitude > 0 then
                    moveDir = moveDir.Unit * flySpeed
                else
                    moveDir = Vector3.new(0, 0, 0)
                end
                
                bv.Velocity = moveDir
                hr.CFrame = CFrame.new(hr.Position) * camera.CFrame.Rotation
                
                -- Mobile camera rotation
                if cameraDelta.Magnitude > 0 then
                    local yaw = cameraDelta.X * cameraRotationSensitivity
                    local pitch = cameraDelta.Y * cameraRotationSensitivity
                    local currentPitch = math.asin(camera.CFrame.LookVector.Y)
                    pitch = math.clamp(currentPitch + pitch, -math.pi / 2 + 0.1, math.pi / 2 - 0.1)
                    local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch - currentPitch, 0, 0)
                    camera.CFrame = CFrame.new(camera.CFrame.Position) * (camera.CFrame.Rotation * rotation)
                end
            end)
            
            notify("🛫 Mobile Fly Enabled", Color3.fromRGB(0, 255, 100))
        else
            if connections.fly then
                connections.fly:Disconnect()
                connections.fly = nil
            end
            if hr and hr:FindFirstChildOfClass("BodyVelocity") then
                hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
            end
            joystickFrame.Visible = false
            cameraControlFrame.Visible = false
            moveDirection = Vector3.new(0, 0, 0)
            cameraDelta = Vector2.new(0, 0)
            notify("🛬 Mobile Fly Disabled", Color3.fromRGB(255, 150, 0))
        end
    end)
    
    if not success then
        flying = false
        notify("⚠️ Fly error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Mobile-optimized freecam
local function toggleFreecam()
    freecam = not freecam
    local success, errorMsg = pcall(function()
        if freecam then
            if flying then
                toggleFly()
                notify("🛫 Fly disabled for Freecam", Color3.fromRGB(255, 150, 0))
            end
            
            if not hr or not humanoid or not camera then
                freecam = false
                error("Character not ready")
            end
            
            joystickFrame.Visible = true
            cameraControlFrame.Visible = true
            hrCFrame = hr.CFrame
            freecamCFrame = camera.CFrame
            camera.CameraType = Enum.CameraType.Scriptable
            camera.CameraSubject = nil
            
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(4000, 4000, 4000)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = hr
            
            connections.freecamLock = RunService.Heartbeat:Connect(function()
                if hr and hrCFrame then
                    hr.CFrame = hrCFrame
                end
            end)
            
            connections.freecam = RunService.Heartbeat:Connect(function()
                if not camera or not freecamCFrame then
                    freecam = false
                    if connections.freecam then connections.freecam:Disconnect() end
                    if connections.freecamLock then connections.freecamLock:Disconnect() end
                    joystickFrame.Visible = false
                    cameraControlFrame.Visible = false
                    return
                end
                
                local forward = freecamCFrame.LookVector
                local right = freecamCFrame.RightVector
                local up = Vector3.new(0, 1, 0)
                local moveDir = moveDirection.X * right + moveDirection.Z * forward
                
                if moveDir.Magnitude > 0 then
                    moveDir = moveDir * freecamSpeed
                    freecamCFrame = CFrame.new(freecamCFrame.Position + moveDir * 0.016) * freecamCFrame.Rotation -- Mobile frame timing
                end
                
                -- Mobile camera rotation for freecam
                if cameraDelta.Magnitude > 0 then
                    local yaw = cameraDelta.X * cameraRotationSensitivity
                    local pitch = cameraDelta.Y * cameraRotationSensitivity
                    local currentPitch = math.asin(freecamCFrame.LookVector.Y)
                    pitch = math.clamp(currentPitch + pitch, -math.pi / 2 + 0.1, math.pi / 2 - 0.1)
                    local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch - currentPitch, 0, 0)
                    freecamCFrame = CFrame.new(freecamCFrame.Position) * (freecamCFrame.Rotation * rotation)
                end
                
                camera.CFrame = freecamCFrame
            end)
            
            notify("📷 Mobile Freecam Enabled", Color3.fromRGB(100, 200, 255))
        else
            if connections.freecam then
                connections.freecam:Disconnect()
                connections.freecam = nil
            end
            if connections.freecamLock then
                connections.freecamLock:Disconnect()
                connections.freecamLock = nil
            end
            if hr and hr:FindFirstChildOfClass("BodyVelocity") then
                hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
            end
            if camera and humanoid then
                camera.CameraType = Enum.CameraType.Custom
                camera.CameraSubject = humanoid
            end
            freecamCFrame = nil
            hrCFrame = nil
            joystickFrame.Visible = false
            cameraControlFrame.Visible = false
            moveDirection = Vector3.new(0, 0, 0)
            cameraDelta = Vector2.new(0, 0)
            notify("📷 Mobile Freecam Disabled", Color3.fromRGB(255, 150, 0))
        end
    end)
    
    if not success then
        freecam = false
        notify("⚠️ Freecam error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Other mobile-optimized functions
local function toggleNoclip()
    noclip = not noclip
    if noclip then
        connections.noclip = RunService.Heartbeat:Connect(function()
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
        notify("🚪 Mobile Noclip ON", Color3.fromRGB(150, 0, 255))
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
        notify("🚪 Mobile Noclip OFF", Color3.fromRGB(255, 150, 0))
    end
end

local function toggleSpeed()
    speedEnabled = not speedEnabled
    if speedEnabled then
        if humanoid then
            humanoid.WalkSpeed = moveSpeed
        end
        notify("🏃 Mobile Speed ON", Color3.fromRGB(255, 200, 0))
    else
        if humanoid then
            humanoid.WalkSpeed = 16
        end
        notify("🏃 Mobile Speed OFF", Color3.fromRGB(255, 150, 0))
    end
end

local function toggleJump()
    jumpEnabled = not jumpEnabled
    if jumpEnabled then
        if humanoid then
            humanoid.JumpPower = jumpPower
        end
        notify("🦘 Mobile Jump ON", Color3.fromRGB(0, 255, 150))
    else
        if humanoid then
            humanoid.JumpPower = 50
        end
        notify("🦘 Mobile Jump OFF", Color3.fromRGB(255, 150, 0))
    end
end

local function toggleGodMode()
    godMode = not godMode
    if godMode then
        if humanoid then
            humanoid.MaxHealth = math.huge
            humanoid.Health = math.huge
        end
        connections.godMode = humanoid.HealthChanged:Connect(function(health)
            if health < math.huge then
                humanoid.Health = math.huge
            end
        end)
        notify("🛡️ Mobile God Mode ON", Color3.fromRGB(255, 215, 0))
    else
        if connections.godMode then
            connections.godMode:Disconnect()
            connections.godMode = nil
        end
        if humanoid then
            humanoid.MaxHealth = 100
            humanoid.Health = 100
        end
        notify("🛡️ Mobile God Mode OFF", Color3.fromRGB(255, 150, 0))
    end
end

-- Mobile position system
local function autoSavePosition(customName)
    if hr then
        positionCounter = positionCounter + 1
        local positionName = customName or ("Mobile Pos " .. positionCounter)
        local positionData = {
            name = positionName,
            cframe = hr.CFrame,
            timestamp = os.time(),
            id = positionCounter
        }
        
        table.insert(savedPositions, positionData)
        
        if #savedPositions > maxSavedPositions then
            table.remove(savedPositions, 1)
        end
        
        notify("📍 Saved: " .. positionName, Color3.fromRGB(0, 255, 150))
    else
        notify("⚠️ Character not loaded", Color3.fromRGB(255, 100, 100))
    end
end

local function loadPosition(positionId)
    for _, pos in ipairs(savedPositions) do
        if pos.id == positionId then
            if hr and isValidPosition(pos.cframe.Position) then
                hr.CFrame = pos.cframe
                notify("📍 Teleported: " .. pos.name, Color3.fromRGB(0, 255, 100))
            else
                notify("⚠️ Invalid position", Color3.fromRGB(255, 100, 100))
            end
            return
        end
    end
end

-- Mobile-optimized joystick
local function createMobileJoystick()
    if joystickFrame then joystickFrame:Destroy() end
    
    joystickFrame = Instance.new("Frame")
    joystickFrame.Size = UDim2.new(0, 140, 0, 140) -- Larger for mobile
    joystickFrame.Position = UDim2.new(0.05, 0, 0.65, 0)
    joystickFrame.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    joystickFrame.BackgroundTransparency = 0.4
    joystickFrame.BorderSizePixel = 0
    joystickFrame.ZIndex = 40
    joystickFrame.Visible = false
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 70)
    corner.Parent = joystickFrame
    joystickFrame.Parent = gui

    local joystickKnob = Instance.new("Frame")
    joystickKnob.Size = UDim2.new(0, 50, 0, 50) -- Larger knob
    joystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
    joystickKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    joystickKnob.BackgroundTransparency = 0.1
    joystickKnob.BorderSizePixel = 0
    joystickKnob.ZIndex = 41
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0, 25)
    knobCorner.Parent = joystickKnob
    joystickKnob.Parent = joystickFrame

    -- Mobile joystick controls
    joystickFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            joystickTouch = input
        end
    end)

    joystickFrame.InputChanged:Connect(function(input)
        if input == joystickTouch and input.UserInputState ~= Enum.UserInputState.End then
            local center = joystickFrame.AbsolutePosition + joystickFrame.AbsoluteSize / 2
            local inputPos = Vector2.new(input.Position.X, input.Position.Y)
            local delta = inputPos - center
            local distance = math.min(delta.Magnitude, joystickRadius)
            local direction = delta.Unit
            
            if delta.Magnitude > joystickDeadzone * joystickRadius then
                moveDirection = Vector3.new(direction.X, 0, -direction.Y) * (distance / joystickRadius)
            else
                moveDirection = Vector3.new(0, 0, 0)
            end
            
            local knobPos = direction * distance
            joystickKnob.Position = UDim2.new(0.5, knobPos.X - 25, 0.5, knobPos.Y - 25)
        end
    end)

    joystickFrame.InputEnded:Connect(function(input)
        if input == joystickTouch then
            joystickTouch = nil
            moveDirection = Vector3.new(0, 0, 0)
            joystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
        end
    end)
end

-- Mobile camera controls
local function createMobileCameraControl()
    if cameraControlFrame then cameraControlFrame:Destroy() end
    
    cameraControlFrame = Instance.new("Frame")
    cameraControlFrame.Size = UDim2.new(0, 140, 0, 140)
    cameraControlFrame.Position = UDim2.new(0.95, -140, 0.65, 0)
    cameraControlFrame.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    cameraControlFrame.BackgroundTransparency = 0.4
    cameraControlFrame.BorderSizePixel = 0
    cameraControlFrame.ZIndex = 40
    cameraControlFrame.Visible = false
    local camCorner = Instance.new("UICorner")
    camCorner.CornerRadius = UDim.new(0, 70)
    camCorner.Parent = cameraControlFrame
    cameraControlFrame.Parent = gui

    local cameraLabel = Instance.new("TextLabel")
    cameraLabel.Size = UDim2.new(1, 0, 1, 0)
    cameraLabel.BackgroundTransparency = 1
    cameraLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    cameraLabel.TextSize = 16
    cameraLabel.Font = Enum.Font.GothamBold
    cameraLabel.Text = "📷\nCAM"
    cameraLabel.ZIndex = 41
    cameraLabel.Parent = cameraControlFrame

    cameraControlFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            cameraTouch = input
        end
    end)

    cameraControlFrame.InputChanged:Connect(function(input)
        if input == cameraTouch and input.UserInputState ~= Enum.UserInputState.End then
            cameraDelta = Vector2.new(input.Delta.X, input.Delta.Y) * 0.5 -- Mobile sensitivity
        end
    end)

    cameraControlFrame.InputEnded:Connect(function(input)
        if input == cameraTouch then
            cameraTouch = nil
            cameraDelta = Vector2.new(0, 0)
        end
    end)
end

-- Mobile floating hotkey buttons
local function createMobileHotkeys()
    local hotkeyFrame = Instance.new("Frame")
    hotkeyFrame.Size = UDim2.new(0, 180, 0, 400)
    hotkeyFrame.Position = UDim2.new(1, -200, 0.25, 0)
    hotkeyFrame.BackgroundTransparency = 1
    hotkeyFrame.ZIndex = 35
    hotkeyFrame.Parent = gui
    
    local function createHotkeyButton(text, emoji, color, callback, yPos)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 60, 0, 60) -- Larger for mobile
        btn.Position = UDim2.new(0, 0, 0, yPos)
        btn.BackgroundColor3 = color
        btn.BackgroundTransparency = 0.2
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 12
        btn.Font = Enum.Font.GothamBold
        btn.Text = emoji .. "\n" .. text
        btn.ZIndex = 36
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 30)
        corner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            callback()
            -- Visual feedback
            btn.BackgroundTransparency = 0.5
            task.wait(0.1)
            btn.BackgroundTransparency = 0.2
        end)
        btn.Parent = hotkeyFrame
        return btn
    end
    
    -- Create mobile hotkey buttons
    createHotkeyButton("FLY", "🛫", Color3.fromRGB(0, 150, 255), toggleFly, 0)
    createHotkeyButton("CAM", "📷", Color3.fromRGB(255, 150, 0), toggleFreecam, 70)
    createHotkeyButton("CLIP", "🚪", Color3.fromRGB(150, 0, 255), toggleNoclip, 140)
    createHotkeyButton("SPEED", "🏃", Color3.fromRGB(255, 200, 0), toggleSpeed, 210)
    createHotkeyButton("JUMP", "🦘", Color3.fromRGB(0, 255, 150), toggleJump, 280)
    createHotkeyButton("GOD", "🛡️", Color3.fromRGB(255, 215, 0), toggleGodMode, 350)
    
    -- Toggle hotkeys visibility
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 50, 0, 50)
    toggleBtn.Position = UDim2.new(1, -70, 0.2, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    toggleBtn.BackgroundTransparency = 0.3
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.TextSize = 20
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.Text = "⚡"
    toggleBtn.ZIndex = 36
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 25)
    toggleCorner.Parent = toggleBtn
    
    toggleBtn.MouseButton1Click:Connect(function()
        hotkeyFrame.Visible = not hotkeyFrame.Visible
        notify(hotkeyFrame.Visible and "⚡ Mobile Hotkeys ON" or "⚡ Mobile Hotkeys OFF")
    end)
    toggleBtn.Parent = gui
    
    notify("⚡ Mobile Hotkeys Ready! Tap ⚡ to toggle")
end

-- Mobile-optimized GUI
local function createMobileGUI()
    local success, errorMsg = pcall(function()
        if gui then gui:Destroy() end

        gui = Instance.new("ScreenGui")
        gui.Name = "MobileKrnlUI"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Enabled = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = player:WaitForChild("PlayerGui", 15)

        -- Mobile-optimized scaling
        local scale = Instance.new("UIScale")
        scale.Scale = mobileScale
        scale.Parent = gui

        -- Mobile logo (larger)
        logo = Instance.new("ImageButton")
        logo.Size = UDim2.new(0, 80, 0, 80) -- Larger for mobile
        logo.Position = UDim2.new(0.9, -80, 0.05, 0)
        logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        logo.BackgroundTransparency = 0.2
        logo.BorderSizePixel = 0
        logo.Image = "rbxassetid://3570695787"
        logo.ZIndex = 20
        local logoCorner = Instance.new("UICorner")
        logoCorner.CornerRadius = UDim.new(0, 15)
        logoCorner.Parent = logo
        logo.Parent = gui

        -- Mobile main frame (optimized size)
        frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 700, 0, 500) -- Mobile optimized size
        frame.Position = UDim2.new(0.5, -350, 0.5, -250)
        frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        frame.BackgroundTransparency = 0.05
        frame.BorderSizePixel = 0
        frame.Visible = false
        frame.ZIndex = 10
        frame.ClipsDescendants = true
        local frameCorner = Instance.new("UICorner")
        frameCorner.CornerRadius = UDim.new(0, 15)
        frameCorner.Parent = frame
        frame.Parent = gui

        -- Mobile sidebar
        local sidebar = Instance.new("Frame")
        sidebar.Size = UDim2.new(0, 180, 1, 0) -- Narrower for mobile
        sidebar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        sidebar.BackgroundTransparency = 0.1
        sidebar.BorderSizePixel = 0
        sidebar.ZIndex = 11
        sidebar.Parent = frame

        local sidebarUIL = Instance.new("UIListLayout")
        sidebarUIL.FillDirection = Enum.FillDirection.Vertical
        sidebarUIL.Padding = UDim.new(0, 10) -- More padding for mobile
        sidebarUIL.Parent = sidebar

        local sidebarPadding = Instance.new("UIPadding")
        sidebarPadding.PaddingTop = UDim.new(0, 20)
        sidebarPadding.PaddingLeft = UDim.new(0, 15)
        sidebarPadding.PaddingRight = UDim.new(0, 15)
        sidebarPadding.Parent = sidebar

        -- Mobile title
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -10, 0, 60) -- Larger for mobile
        title.BackgroundTransparency = 1
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 18 -- Mobile optimized
        title.Font = Enum.Font.GothamBold
        title.Text = "📱 Mobile Krnl UI\nv2.0"
        title.TextWrapped = true
        title.ZIndex = 12
        title.Parent = sidebar

        -- Mobile content frame
        local contentFrame = Instance.new("Frame")
        contentFrame.Size = UDim2.new(0, 510, 1, -10) -- Adjusted for mobile
        contentFrame.Position = UDim2.new(0, 185, 0, 5)
        contentFrame.BackgroundTransparency = 1
        contentFrame.ZIndex = 11
        contentFrame.ClipsDescendants = true
        contentFrame.Parent = frame

        -- Mobile scroll frame
        local scrollFrame = Instance.new("ScrollingFrame")
        scrollFrame.Size = UDim2.new(1, -10, 1, -10)
        scrollFrame.Position = UDim2.new(0, 5, 0, 5)
        scrollFrame.BackgroundTransparency = 1
        scrollFrame.ScrollBarThickness = 12 -- Thicker for mobile
        scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150)
        scrollFrame.ZIndex = 11
        scrollFrame.ClipsDescendants = true
        scrollFrame.ScrollingEnabled = true
        scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        scrollFrame.Parent = contentFrame

        local scrollUIL = Instance.new("UIListLayout")
        scrollUIL.FillDirection = Enum.FillDirection.Vertical
        scrollUIL.Padding = UDim.new(0, 12) -- More padding for mobile
        scrollUIL.Parent = scrollFrame

        local scrollPadding = Instance.new("UIPadding")
        scrollPadding.PaddingTop = UDim.new(0, 20)
        scrollPadding.PaddingBottom = UDim.new(0, 25)
        scrollPadding.PaddingLeft = UDim.new(0, 20)
        scrollPadding.PaddingRight = UDim.new(0, 20)
        scrollPadding.Parent = scrollFrame

        -- Mobile button creator
        local function createMobileButton(text, callback, toggleState)
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, -20, 0, 55) -- Larger for mobile touch
            button.BackgroundColor3 = toggleState() and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(40, 40, 40)
            button.BackgroundTransparency = 0.1
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
            button.TextSize = 18 -- Larger text for mobile
            button.Font = Enum.Font.GothamBold
            button.Text = text
            button.TextWrapped = true
            button.ZIndex = 12
            button.Visible = false
            
            local buttonCorner = Instance.new("UICorner")
            buttonCorner.CornerRadius = UDim.new(0, 10)
            buttonCorner.Parent = button
            
            -- Mobile touch feedback
            button.MouseButton1Down:Connect(function()
                button.BackgroundColor3 = toggleState() and Color3.fromRGB(70, 220, 70) or Color3.fromRGB(60, 60, 60)
                button.Size = UDim2.new(1, -20, 0, 52) -- Slight shrink effect
            end)
            
            button.MouseButton1Up:Connect(function()
                local success, err = pcall(callback)
                if not success then
                    notify("⚠️ Error: " .. text .. " - " .. tostring(err), Color3.fromRGB(255, 100, 100))
                end
                button.BackgroundColor3 = toggleState() and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(40, 40, 40)
                button.Size = UDim2.new(1, -20, 0, 55) -- Back to normal
            end)
            
            return button
        end

        -- Mobile categories with emojis
        local categories = {
            ["🛫 Movement"] = {
                createMobileButton("🛫 Toggle Mobile Fly", toggleFly, function() return flying end),
                createMobileButton("🚪 Toggle Mobile Noclip", toggleNoclip, function() return noclip end),
                createMobileButton("🏃 Toggle Mobile Speed", toggleSpeed, function() return speedEnabled end),
                createMobileButton("🦘 Toggle Mobile Jump", toggleJump, function() return jumpEnabled end),
                createMobileButton("🛡️ Toggle Mobile God Mode", toggleGodMode, function() return godMode end)
            },
            ["📷 Camera"] = {
                createMobileButton("📷 Toggle Mobile Freecam", toggleFreecam, function() return freecam end),
                createMobileButton("📍 Teleport to Freecam", function()
                    if freecam and freecamCFrame and hr then
                        hr.CFrame = freecamCFrame
                        notify("📍 Teleported to Mobile Freecam")
                    else
                        notify("⚠️ Freecam not active", Color3.fromRGB(255, 100, 100))
                    end
                end, function() return false end)
            },
            ["📍 Positions"] = {
                createMobileButton("💾 Save Current Position", function() 
                    autoSavePosition("Mobile " .. os.date("%H:%M"))
                end, function() return false end),
                createMobileButton("📋 View Saved Positions", function()
                    local posText = "📱 Mobile Positions:\n"
                    for i, pos in ipairs(savedPositions) do
                        posText = posText .. i .. ". " .. pos.name .. "\n"
                    end
                    notify(#savedPositions > 0 and posText or "📍 No positions saved yet")
                end, function() return false end),
                createMobileButton("🚀 Teleport to Last Position", function()
                    if #savedPositions > 0 then
                        loadPosition(savedPositions[#savedPositions].id)
                    else
                        notify("⚠️ No positions saved", Color3.fromRGB(255, 100, 100))
                    end
                end, function() return false end)
            },
            ["🎮 Mobile Tools"] = {
                createMobileButton("📱 Show Mobile Hotkeys", function()
                    local hotkeyFrame = gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("Frame")
                    if hotkeyFrame then
                        hotkeyFrame.Visible = not hotkeyFrame.Visible
                        notify(hotkeyFrame.Visible and "⚡ Mobile Hotkeys Shown" or "⚡ Mobile Hotkeys Hidden")
                    end
                end, function() return false end),
                createMobileButton("🔄 Reset Character", function()
                    if humanoid then
                        humanoid.Health = 0
                        notify("🔄 Character Reset")
                    end
                end, function() return false end),
                createMobileButton("🏠 Teleport to Spawn", function()
                    if hr then
                        local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
                        local pos = spawn and spawn.Position or Vector3.new(0, 10, 0)
                        hr.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
                        notify("🏠 Teleported to Mobile Spawn")
                    end
                end, function() return false end)
            }
        }

        -- Add all buttons to scroll frame
        for categoryName, buttons in pairs(categories) do
            for _, button in pairs(buttons) do
                button.Parent = scrollFrame
            end
        end

        -- Mobile category switcher
        local function updateMobileCategory(categoryName)
            for _, buttons in pairs(categories) do
                for _, button in pairs(buttons) do
                    button.Visible = false
                end
            end
            
            if categories[categoryName] then
                for _, button in pairs(categories[categoryName]) do
                    button.Visible = true
                end
            end
            
            currentCategory = categoryName
            
            -- Update sidebar buttons
            for _, child in pairs(sidebar:GetChildren()) do
                if child:IsA("TextButton") and categories[child.Name] then
                    child.BackgroundColor3 = child.Name == categoryName and Color3.fromRGB(50, 150, 255) or Color3.fromRGB(40, 40, 40)
                end
            end
            
            scrollFrame.CanvasPosition = Vector2.new(0, 0)
            notify("📂 " .. categoryName .. " (" .. #categories[categoryName] .. " tools)")
        end

        -- Create mobile sidebar category buttons
        for categoryName, _ in pairs(categories) do
            local categoryButton = Instance.new("TextButton")
            categoryButton.Size = UDim2.new(1, -10, 0, 50) -- Larger for mobile
            categoryButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            categoryButton.BackgroundTransparency = 0.1
            categoryButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            categoryButton.TextSize = 14 -- Mobile optimized
            categoryButton.Font = Enum.Font.GothamBold
            categoryButton.Text = categoryName
            categoryButton.TextWrapped = true
            categoryButton.ZIndex = 12
            categoryButton.Name = categoryName
            
            local categoryCorner = Instance.new("UICorner")
            categoryCorner.CornerRadius = UDim.new(0, 10)
            categoryCorner.Parent = categoryButton
            
            -- Mobile touch feedback for categories
            categoryButton.MouseButton1Down:Connect(function()
                categoryButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            end)
            
            categoryButton.MouseButton1Up:Connect(function()
                updateMobileCategory(categoryName)
            end)
            
            categoryButton.Parent = sidebar
        end

        -- Initialize with first category
        updateMobileCategory("🛫 Movement")

        -- Mobile logo click handler
        logo.MouseButton1Click:Connect(function()
            frame.Visible = not frame.Visible
            notify(frame.Visible and "📱 Mobile GUI Opened" or "📱 Mobile GUI Closed")
        end)

        -- Mobile drag functionality (simplified)
        local dragging = false
        local dragStart = nil
        local startPos = nil

        title.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position
            end
        end)

        title.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(
                    startPos.X.Scale, 
                    startPos.X.Offset + delta.X, 
                    startPos.Y.Scale, 
                    startPos.Y.Offset + delta.Y
                )
            end
        end)

        title.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        -- Mobile status bar
        local statusFrame = Instance.new("Frame")
        statusFrame.Size = UDim2.new(1, 0, 0, 50)
        statusFrame.Position = UDim2.new(0, 0, 1, -50)
        statusFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        statusFrame.BackgroundTransparency = 0.2
        statusFrame.BorderSizePixel = 0
        statusFrame.ZIndex = 11
        statusFrame.Parent = frame
        
        local statusLabel = Instance.new("TextLabel")
        statusLabel.Size = UDim2.new(1, -20, 1, 0)
        statusLabel.Position = UDim2.new(0, 10, 0, 0)
        statusLabel.BackgroundTransparency = 1
        statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        statusLabel.TextSize = 14
        statusLabel.Font = Enum.Font.Gotham
        statusLabel.Text = "📱 Mobile Krnl UI Active | Positions: " .. #savedPositions
        statusLabel.TextXAlignment = Enum.TextXAlignment.Left
        statusLabel.ZIndex = 12
        statusLabel.Parent = statusFrame
        
        -- Mobile close button
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 40, 0, 40)
        closeBtn.Position = UDim2.new(1, -50, 0, 10)
        closeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        closeBtn.BackgroundTransparency = 0.2
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.TextSize = 20
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.Text = "×"
        closeBtn.ZIndex = 13
        
        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, 20)
        closeCorner.Parent = closeBtn
        
        closeBtn.MouseButton1Click:Connect(function()
            frame.Visible = false
            notify("📱 Mobile GUI Closed")
        end)
        closeBtn.Parent = frame

        -- Update status periodically
        task.spawn(function()
            while gui and gui.Parent do
                if statusLabel then
                    local activeFeatures = {}
                    if flying then table.insert(activeFeatures, "🛫Fly") end
                    if freecam then table.insert(activeFeatures, "📷Cam") end
                    if noclip then table.insert(activeFeatures, "🚪Clip") end
                    if speedEnabled then table.insert(activeFeatures, "🏃Speed") end
                    if godMode then table.insert(activeFeatures, "🛡️God") end
                    
                    local featuresText = #activeFeatures > 0 and " | Active: " .. table.concat(activeFeatures, " ") or ""
                    statusLabel.Text = "📱 Mobile Krnl UI | Pos: " .. #savedPositions .. featuresText
                end
                task.wait(2)
            end
        end)
    end)
    
    if not success then
        notify("⚠️ Mobile GUI failed: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
        task.wait(3)
        createMobileGUI()
    end
end

-- Main mobile initialization
local function mobileMain()
    local success, errorMsg = pcall(function()
        -- Clean old instances
        local oldGui = player.PlayerGui:FindFirstChild("MobileKrnlUI")
        if oldGui then
            oldGui:Destroy()
            notify("🛠️ Old mobile instance removed", Color3.fromRGB(255, 200, 0))
        end
        
        task.wait(1)
        
        -- Initialize mobile components
        createMobileGUI()
        createMobileJoystick()
        createMobileCameraControl()
        createMobileHotkeys()
        initChar()
        
        -- Connect character respawn
        player.CharacterAdded:Connect(function()
            task.wait(1.5) -- Mobile loading time
            initChar()
        end)
        
        -- Mobile auto-save (less frequent for performance)
        task.spawn(function()
            local lastPosition = nil
            while true do
                task.wait(45) -- Longer interval for mobile
                if hr and hr.Position then
                    if not lastPosition or (hr.Position - lastPosition).Magnitude > 15 then
                        autoSavePosition("Auto " .. os.date("%H:%M"))
                        lastPosition = hr.Position
                    end
                end
            end
        end)
        
        -- Mobile gesture controls (simplified)
        local gestureFrame = Instance.new("Frame")
        gestureFrame.Size = UDim2.new(1, 0, 1, 0)
        gestureFrame.BackgroundTransparency = 1
        gestureFrame.ZIndex = 1
        gestureFrame.Parent = gui
        
        local lastTap = 0
        local tapCount = 0
        
        gestureFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                local now = tick()
                if now - lastTap < 0.5 then
                    tapCount = tapCount + 1
                    if tapCount == 1 then -- Double tap
                        toggleFly()
                    elseif tapCount == 2 then -- Triple tap
                        toggleNoclip()
                    end
                else
                    tapCount = 0
                end
                lastTap = now
            end
        end)
        
        notify("🚀 Mobile Krnl UI v2.0 Loaded!", Color3.fromRGB(0, 255, 0))
        notify("📱 100% Mobile Optimized - Tap logo to open!", Color3.fromRGB(100, 200, 255))
        notify("👆 Gestures: Double tap = Fly, Triple tap = Noclip", Color3.fromRGB(255, 200, 0))
    end)
    
    if not success then
        notify("⚠️ Mobile script failed: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
        task.wait(3)
        mobileMain()
    end
end

-- Start mobile script
mobileMain()