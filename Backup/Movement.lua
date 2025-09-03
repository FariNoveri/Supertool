-- Movement.lua - Fixed version with proper state synchronization and settings integration
-- Movement-related features for MinimalHackGUI by Fari Noveri, mobile-friendly with robust respawn handling

-- Dependencies: These must be passed from mainloader.lua
local Players, RunService, Workspace, UserInputService, humanoid, rootPart, connections, buttonStates, ScrollFrame, ScreenGui, settings, player

-- Initialize module
local Movement = {}

-- Movement states (these need to persist across respawns)
Movement.speedEnabled = false
Movement.jumpEnabled = false
Movement.flyEnabled = false
Movement.noclipEnabled = false
Movement.infiniteJumpEnabled = false
Movement.walkOnWaterEnabled = false
Movement.swimEnabled = false
Movement.moonGravityEnabled = false
Movement.doubleJumpEnabled = false
Movement.wallClimbEnabled = false
Movement.playerNoclipEnabled = false
Movement.floatEnabled = false
Movement.rewindEnabled = false
Movement.boostEnabled = false
Movement.slowFallEnabled = false
Movement.fastFallEnabled = false
Movement.sprintEnabled = false

-- Default values
Movement.defaultWalkSpeed = 16
Movement.defaultJumpPower = 50
Movement.defaultJumpHeight = 7.2
Movement.defaultGravity = 196.2
Movement.jumpCount = 0
Movement.maxJumps = 1  -- Fixed for proper double jump (1 air jump)

-- Fly controls
local flySpeed = 50
local flyBodyVelocity = nil
local flyBodyGyro = nil
local flyJoystickFrame, flyJoystickKnob
local flyUpButton, flyDownButton
local boostButton
local rewindButton
local sprintButton
local wallClimbButton
local joystickDelta = Vector2.new(0, 0)
local isTouchingJoystick = false
local joystickTouchId = nil

-- Key states for PC controls
local flyKeys = {forward = false, back = false, left = false, right = false, up = false, down = false}
local floatKeys = {forward = false, back = false, left = false, right = false}

-- New features variables
local positionHistory = {}
local maxHistorySize = 180 -- 6 seconds at 30 fps
local isBoostActive = false

-- State synchronization flag
local isRespawning = false

-- Scroll frame for UI
local function setupScrollFrame()
    if ScrollFrame then
        ScrollFrame.ScrollingEnabled = true
        ScrollFrame.ScrollBarThickness = 8
        ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 500)
    end
end

-- Reference refresh function
local function refreshReferences()
    if not player or not player.Character then 
        return false 
    end
    
    local newHumanoid = player.Character:FindFirstChildOfClass("Humanoid")
    local newRootPart = player.Character:FindFirstChild("HumanoidRootPart")
    
    if newHumanoid then
        humanoid = newHumanoid
    end
    if newRootPart then
        rootPart = newRootPart
    end
    
    return humanoid ~= nil and rootPart ~= nil
end

-- Helper function to get setting value safely
local function getSettingValue(settingName, defaultValue)
    if settings and settings[settingName] and settings[settingName].value then
        return settings[settingName].value
    end
    return defaultValue
end

-- Function to update button visual state
local function updateButtonState(featureName, enabled)
    if buttonStates and buttonStates[featureName] then
        local button = buttonStates[featureName]
        if button and button.Parent then
            button.BackgroundColor3 = enabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(40, 40, 40)
            button.TextColor3 = enabled and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        end
    end
end

-- Create virtual controls with better positioning and white style
local function createMobileControls()
    print("Creating mobile controls")
    
    if flyJoystickFrame then flyJoystickFrame:Destroy() end
    if flyUpButton then flyUpButton:Destroy() end
    if flyDownButton then flyDownButton:Destroy() end
    if boostButton then boostButton:Destroy() end
    if rewindButton then rewindButton:Destroy() end
    if sprintButton then sprintButton:Destroy() end
    if wallClimbButton then wallClimbButton:Destroy() end

    flyJoystickFrame = Instance.new("Frame")
    flyJoystickFrame.Name = "FlyJoystick"
    flyJoystickFrame.Size = UDim2.new(0, 100, 0, 100)
    flyJoystickFrame.Position = UDim2.new(0, 20, 1, -130)
    flyJoystickFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flyJoystickFrame.BackgroundTransparency = 0.5
    flyJoystickFrame.BorderSizePixel = 0
    flyJoystickFrame.Visible = false
    flyJoystickFrame.ZIndex = 10
    flyJoystickFrame.Parent = ScreenGui or player.PlayerGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = flyJoystickFrame

    flyJoystickKnob = Instance.new("Frame")
    flyJoystickKnob.Name = "Knob"
    flyJoystickKnob.Size = UDim2.new(0, 40, 0, 40)
    flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
    flyJoystickKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flyJoystickKnob.BackgroundTransparency = 0.1
    flyJoystickKnob.BorderSizePixel = 0
    flyJoystickKnob.ZIndex = 11
    flyJoystickKnob.Parent = flyJoystickFrame

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0.5, 0)
    knobCorner.Parent = flyJoystickKnob

    flyUpButton = Instance.new("TextButton")
    flyUpButton.Name = "FlyUpButton"
    flyUpButton.Size = UDim2.new(0, 50, 0, 50)
    flyUpButton.Position = UDim2.new(0, 130, 1, -180)
    flyUpButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flyUpButton.BackgroundTransparency = 0.5
    flyUpButton.BorderSizePixel = 0
    flyUpButton.Text = "↑"
    flyUpButton.Font = Enum.Font.GothamBold
    flyUpButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    flyUpButton.TextSize = 20
    flyUpButton.Visible = false
    flyUpButton.ZIndex = 10
    flyUpButton.Parent = ScreenGui or player.PlayerGui

    local upCorner = Instance.new("UICorner")
    upCorner.CornerRadius = UDim.new(0.2, 0)
    upCorner.Parent = flyUpButton

    flyDownButton = Instance.new("TextButton")
    flyDownButton.Name = "FlyDownButton"
    flyDownButton.Size = UDim2.new(0, 50, 0, 50)
    flyDownButton.Position = UDim2.new(0, 130, 1, -120)
    flyDownButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flyDownButton.BackgroundTransparency = 0.5
    flyDownButton.BorderSizePixel = 0
    flyDownButton.Text = "↓"
    flyDownButton.Font = Enum.Font.GothamBold
    flyDownButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    flyDownButton.TextSize = 20
    flyDownButton.Visible = false
    flyDownButton.ZIndex = 10
    flyDownButton.Parent = ScreenGui or player.PlayerGui

    local downCorner = Instance.new("UICorner")
    downCorner.CornerRadius = UDim.new(0.2, 0)
    downCorner.Parent = flyDownButton

    sprintButton = Instance.new("TextButton")
    sprintButton.Name = "SprintButton"
    sprintButton.Size = UDim2.new(0, 80, 0, 80)
    sprintButton.Position = UDim2.new(1, -100, 1, -370)
    sprintButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sprintButton.BackgroundTransparency = 0.5
    sprintButton.BorderSizePixel = 0
    sprintButton.Text = "SPRINT"
    sprintButton.Font = Enum.Font.GothamBold
    sprintButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    sprintButton.TextSize = 16
    sprintButton.Visible = false
    sprintButton.ZIndex = 10
    sprintButton.Parent = ScreenGui or player.PlayerGui

    local sprintCorner = Instance.new("UICorner")
    sprintCorner.CornerRadius = UDim.new(0.2, 0)
    sprintCorner.Parent = sprintButton

    wallClimbButton = Instance.new("TextButton")
    wallClimbButton.Name = "WallClimbButton"
    wallClimbButton.Size = UDim2.new(0, 80, 0, 80)
    wallClimbButton.Position = UDim2.new(1, -100, 1, -460)
    wallClimbButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    wallClimbButton.BackgroundTransparency = 0.5
    wallClimbButton.BorderSizePixel = 0
    wallClimbButton.Text = "CLIMB"
    wallClimbButton.Font = Enum.Font.GothamBold
    wallClimbButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    wallClimbButton.TextSize = 16
    wallClimbButton.Visible = false
    wallClimbButton.ZIndex = 10
    wallClimbButton.Parent = ScreenGui or player.PlayerGui

    local wallClimbCorner = Instance.new("UICorner")
    wallClimbCorner.CornerRadius = UDim.new(0.2, 0)
    wallClimbCorner.Parent = wallClimbButton
end

-- Improved joystick handling for float (horizontal only)
local function handleFloatJoystick(input, gameProcessed)
    if not Movement.floatEnabled or not flyJoystickFrame or not flyJoystickFrame.Visible then 
        return 
    end
    
    if input.UserInputType == Enum.UserInputType.Touch then
        local joystickCenter = flyJoystickFrame.AbsolutePosition + flyJoystickFrame.AbsoluteSize * 0.5
        local inputPos = Vector2.new(input.Position.X, input.Position.Y)
        local distanceFromCenter = (inputPos - joystickCenter).Magnitude
        
        if input.UserInputState == Enum.UserInputState.Begin then
            if distanceFromCenter <= 50 and not isTouchingJoystick then
                isTouchingJoystick = true
                joystickTouchId = input
            end
        elseif input.UserInputState == Enum.UserInputState.Change and isTouchingJoystick and input == joystickTouchId then
            local delta = inputPos - joystickCenter
            local magnitude = delta.Magnitude
            local maxRadius = 30
            
            if magnitude > maxRadius then
                delta = delta * (maxRadius / magnitude)
            end
            
            flyJoystickKnob.Position = UDim2.new(0.5, delta.X - 20, 0.5, delta.Y - 20)
            joystickDelta = delta / maxRadius
            
        elseif input.UserInputState == Enum.UserInputState.End and input == joystickTouchId then
            isTouchingJoystick = false
            joystickTouchId = nil
            flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
            joystickDelta = Vector2.new(0, 0)
        end
    end
end

-- Regular joystick handling for fly (with vertical movement)
local function handleFlyJoystick(input, gameProcessed)
    if not Movement.flyEnabled or not flyJoystickFrame or not flyJoystickFrame.Visible then 
        return 
    end
    
    if input.UserInputType == Enum.UserInputType.Touch then
        local joystickCenter = flyJoystickFrame.AbsolutePosition + flyJoystickFrame.AbsoluteSize * 0.5
        local inputPos = Vector2.new(input.Position.X, input.Position.Y)
        local distanceFromCenter = (inputPos - joystickCenter).Magnitude
        
        if input.UserInputState == Enum.UserInputState.Begin then
            if distanceFromCenter <= 50 and not isTouchingJoystick then
                isTouchingJoystick = true
                joystickTouchId = input
            end
        elseif input.UserInputState == Enum.UserInputState.Change and isTouchingJoystick and input == joystickTouchId then
            local delta = inputPos - joystickCenter
            local magnitude = delta.Magnitude
            local maxRadius = 30
            
            if magnitude > maxRadius then
                delta = delta * (maxRadius / magnitude)
            end
            
            flyJoystickKnob.Position = UDim2.new(0.5, delta.X - 20, 0.5, delta.Y - 20)
            joystickDelta = delta / maxRadius
            
        elseif input.UserInputState == Enum.UserInputState.End and input == joystickTouchId then
            isTouchingJoystick = false
            joystickTouchId = nil
            flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
            joystickDelta = Vector2.new(0, 0)
        end
    end
end

-- Speed Hack with settings integration and proper sync
local function toggleSpeed(enabled)
    Movement.speedEnabled = enabled
    updateButtonState("Speed Hack", enabled)
    print("Speed Hack:", enabled)
    
    if enabled then
        local function applySpeed()
            if refreshReferences() and humanoid then
                local speedValue = getSettingValue("WalkSpeed", 50)
                humanoid.WalkSpeed = speedValue
                print("Applied speed:", speedValue)
                return true
            end
            return false
        end
        
        if not applySpeed() then
            task.spawn(function()
                task.wait(0.1)
                applySpeed()
            end)
        end
    else
        if refreshReferences() and humanoid then
            humanoid.WalkSpeed = Movement.defaultWalkSpeed
        end
    end
end

-- Jump Hack with settings integration and proper sync
local function toggleJump(enabled)
    Movement.jumpEnabled = enabled
    updateButtonState("Jump Hack", enabled)
    print("Jump Hack:", enabled)
    
    if enabled then
        local function applyJump()
            if refreshReferences() and humanoid then
                local jumpValue = getSettingValue("JumpHeight", 50)
                if humanoid:FindFirstChild("JumpHeight") then
                    humanoid.JumpHeight = jumpValue
                else
                    humanoid.JumpPower = jumpValue * 2.4
                end
                print("Applied jump:", jumpValue)
                return true
            end
            return false
        end
        
        if not applyJump() then
            task.spawn(function()
                task.wait(0.1)
                applyJump()
            end)
        end
    else
        if refreshReferences() and humanoid then
            if humanoid:FindFirstChild("JumpHeight") then
                humanoid.JumpHeight = Movement.defaultJumpHeight
            else
                humanoid.JumpPower = Movement.defaultJumpPower
            end
        end
    end
end

-- Slow Fall with no fall damage (automatic)
local function toggleSlowFall(enabled)
    Movement.slowFallEnabled = enabled
    updateButtonState("Slow Fall", enabled)
    print("Slow Fall:", enabled)
    
    if connections.slowFall then
        connections.slowFall:Disconnect()
        connections.slowFall = nil
    end
    
    if enabled then
        connections.slowFall = RunService.Heartbeat:Connect(function()
            if not Movement.slowFallEnabled then return end
            if not refreshReferences() or not rootPart or not humanoid then return end
            
            if rootPart.Velocity.Y < 0 then
                local slowFallVelocity = Instance.new("BodyVelocity")
                slowFallVelocity.MaxForce = Vector3.new(0, 4000, 0)
                slowFallVelocity.Velocity = Vector3.new(0, -10, 0)
                slowFallVelocity.Parent = rootPart
                game:GetService("Debris"):AddItem(slowFallVelocity, 0.1)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            end
        end)
    else
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        end
    end
end

-- Fast Fall with no fall damage (automatic)
local function toggleFastFall(enabled)
    Movement.fastFallEnabled = enabled
    updateButtonState("Fast Fall", enabled)
    print("Fast Fall:", enabled)
    
    if connections.fastFall then
        connections.fastFall:Disconnect()
        connections.fastFall = nil
    end
    
    if enabled then
        connections.fastFall = RunService.Heartbeat:Connect(function()
            if not Movement.fastFallEnabled then return end
            if not refreshReferences() or not rootPart or not humanoid then return end
            
            if rootPart.Velocity.Y < 0 then
                local fastFallVelocity = Instance.new("BodyVelocity")
                fastFallVelocity.MaxForce = Vector3.new(0, 4000, 0)
                fastFallVelocity.Velocity = Vector3.new(0, -100, 0)
                fastFallVelocity.Parent = rootPart
                game:GetService("Debris"):AddItem(fastFallVelocity, 0.1)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            end
        end)
    else
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        end
    end
end

-- Sprint feature with toggle and proper sync
local function toggleSprint(enabled)
    Movement.sprintEnabled = enabled
    updateButtonState("Sprint", enabled)
    print("Sprint:", enabled)
    
    if connections.sprint then
        connections.sprint:Disconnect()
        connections.sprint = nil
    end
    if connections.sprintInput then
        connections.sprintInput:Disconnect()
        connections.sprintInput = nil
    end
    if connections.sprintToggle then
        connections.sprintToggle:Disconnect()
        connections.sprintToggle = nil
    end
    
    if enabled then
        if sprintButton then
            sprintButton.Visible = true
        end
        
        local isSprinting = false
        
        connections.sprintInput = sprintButton.MouseButton1Click:Connect(function()
            if refreshReferences() and humanoid then
                isSprinting = not isSprinting
                sprintButton.BackgroundColor3 = isSprinting and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
                sprintButton.BackgroundTransparency = isSprinting and 0.2 or 0.5
                sprintButton.Text = isSprinting and "SPRINTING!" or "SPRINT"
                
                humanoid.WalkSpeed = isSprinting and getSettingValue("SprintSpeed", 80) or (Movement.speedEnabled and getSettingValue("WalkSpeed", 50) or Movement.defaultWalkSpeed)
            end
        end)
        
        connections.sprintToggle = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or not Movement.sprintEnabled then return end
            if input.KeyCode == Enum.KeyCode.LeftShift then
                if refreshReferences() and humanoid then
                    isSprinting = not isSprinting
                    sprintButton.BackgroundColor3 = isSprinting and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
                    sprintButton.BackgroundTransparency = isSprinting and 0.2 or 0.5
                    sprintButton.Text = isSprinting and "SPRINTING!" or "SPRINT"
                    
                    humanoid.WalkSpeed = isSprinting and getSettingValue("SprintSpeed", 80) or (Movement.speedEnabled and getSettingValue("WalkSpeed", 50) or Movement.defaultWalkSpeed)
                end
            end
        end)
    else
        if sprintButton then
            sprintButton.Visible = false
            sprintButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            sprintButton.BackgroundTransparency = 0.5
            sprintButton.Text = "SPRINT"
        end
        if refreshReferences() and humanoid then
            humanoid.WalkSpeed = Movement.speedEnabled and getSettingValue("WalkSpeed", 50) or Movement.defaultWalkSpeed
        end
    end
end

-- Fixed Float Hack (full horizontal movement) with proper sync and PC controls
local function toggleFloat(enabled)
    Movement.floatEnabled = enabled
    updateButtonState("Float", enabled)
    print("Float toggle:", enabled)
    
    local floatConnections = {"float", "floatInput", "floatBegan", "floatEnded", "floatKeyBegan", "floatKeyEnded"}
    for _, connName in ipairs(floatConnections) do
        if connections[connName] then
            connections[connName]:Disconnect()
            connections[connName] = nil
        end
    end
    
    floatKeys = {forward = false, back = false, left = false, right = false}
    
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    
    if enabled then
        task.spawn(function()
            task.wait(0.1)
            if not refreshReferences() or not rootPart or not humanoid then
                print("Failed to get references for float")
                Movement.floatEnabled = false
                updateButtonState("Float", false)
                return
            end
            
            humanoid.PlatformStand = true
            flyBodyVelocity = Instance.new("BodyVelocity")
            flyBodyVelocity.MaxForce = Vector3.new(4000, 0, 4000)
            flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            flyBodyVelocity.Parent = rootPart
            
            if flyJoystickFrame then flyJoystickFrame.Visible = true end
            
            connections.float = RunService.Heartbeat:Connect(function()
                if not Movement.floatEnabled then return end
                if not refreshReferences() or not rootPart or not humanoid then return end
                
                if not flyBodyVelocity or flyBodyVelocity.Parent ~= rootPart then
                    if flyBodyVelocity then flyBodyVelocity:Destroy() end
                    flyBodyVelocity = Instance.new("BodyVelocity")
                    flyBodyVelocity.MaxForce = Vector3.new(4000, 0, 4000)
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                    flyBodyVelocity.Parent = rootPart
                end
                
                local camera = Workspace.CurrentCamera
                if not camera then return end
                
                local floatDirection = Vector3.new(0, 0, 0)
                flySpeed = getSettingValue("FlySpeed", 50)
                
                -- Joystick input
                if joystickDelta.Magnitude > 0.05 then
                    local forward = camera.CFrame.LookVector
                    local right = camera.CFrame.RightVector
                    
                    forward = Vector3.new(forward.X, 0, forward.Z).Unit
                    right = Vector3.new(right.X, 0, right.Z).Unit
                    
                    floatDirection = floatDirection + (right * joystickDelta.X) + (forward * -joystickDelta.Y)
                end
                
                -- Keyboard input
                local keyDirection = Vector3.new(0, 0, 0)
                local flatLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit
                local flatRight = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z).Unit
                
                if floatKeys.forward then keyDirection = keyDirection + flatLook end
                if floatKeys.back then keyDirection = keyDirection - flatLook end
                if floatKeys.left then keyDirection = keyDirection - flatRight end
                if floatKeys.right then keyDirection = keyDirection + flatRight end
                
                floatDirection = floatDirection + keyDirection
                
                if floatDirection.Magnitude > 0 then
                    flyBodyVelocity.Velocity = floatDirection.Unit * flySpeed
                else
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                end
            end)
            
            connections.floatInput = UserInputService.InputChanged:Connect(handleFloatJoystick)
            connections.floatBegan = UserInputService.InputBegan:Connect(handleFloatJoystick)
            connections.floatEnded = UserInputService.InputEnded:Connect(handleFloatJoystick)
            
            connections.floatKeyBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed or not Movement.floatEnabled then return end
                local kc = input.KeyCode
                if kc == Enum.KeyCode.W then floatKeys.forward = true
                elseif kc == Enum.KeyCode.S then floatKeys.back = true
                elseif kc == Enum.KeyCode.A then floatKeys.left = true
                elseif kc == Enum.KeyCode.D then floatKeys.right = true
                end
            end)
            
            connections.floatKeyEnded = UserInputService.InputEnded:Connect(function(input)
                local kc = input.KeyCode
                if kc == Enum.KeyCode.W then floatKeys.forward = false
                elseif kc == Enum.KeyCode.S then floatKeys.back = false
                elseif kc == Enum.KeyCode.A then floatKeys.left = false
                elseif kc == Enum.KeyCode.D then floatKeys.right = false
                end
            end)
        end)
    else
        if humanoid then
            humanoid.PlatformStand = false
        end
        if flyJoystickFrame then 
            flyJoystickFrame.Visible = false
            flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
        end
        
        joystickDelta = Vector2.new(0, 0)
        isTouchingJoystick = false
        joystickTouchId = nil
    end
end

-- Boost (NOS-like effect, no cooldown) with proper sync
local function createBoostButton()
    if boostButton then boostButton:Destroy() end
    
    boostButton = Instance.new("TextButton")
    boostButton.Name = "BoostButton"
    boostButton.Size = UDim2.new(0, 80, 0, 80)
    boostButton.Position = UDim2.new(1, -100, 1, -280)
    boostButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    boostButton.BackgroundTransparency = 0.5
    boostButton.BorderSizePixel = 0
    boostButton.Text = "BOOST"
    boostButton.Font = Enum.Font.GothamBold
    boostButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    boostButton.TextSize = 16
    boostButton.Visible = false
    boostButton.ZIndex = 10
    boostButton.Parent = ScreenGui or player.PlayerGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.2, 0)
    corner.Parent = boostButton
end

local function toggleBoost(enabled)
    Movement.boostEnabled = enabled
    updateButtonState("Boost (NOS)", enabled)
    
    if connections.boost then
        connections.boost:Disconnect()
        connections.boost = nil
    end
    if connections.boostInput then
        connections.boostInput:Disconnect()
        connections.boostInput = nil
    end
    if connections.boostToggle then
        connections.boostToggle:Disconnect()
        connections.boostToggle = nil
    end
    
    if enabled then
        createBoostButton()
        if boostButton then
            boostButton.Visible = true
        end
        
        connections.boostInput = boostButton.MouseButton1Click:Connect(function()
            if refreshReferences() and humanoid and rootPart then
                isBoostActive = true
                boostButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                boostButton.BackgroundTransparency = 0.2
                boostButton.Text = "BOOSTING!"
                
                local camera = Workspace.CurrentCamera
                if camera then
                    local boostDirection = camera.CFrame.LookVector
                    local boostForce = Instance.new("BodyVelocity")
                    boostForce.MaxForce = Vector3.new(4000, 0, 4000)
                    boostForce.Velocity = Vector3.new(boostDirection.X * 100, 0, boostDirection.Z * 100)
                    boostForce.Parent = rootPart
                    
                    game:GetService("Debris"):AddItem(boostForce, 0.5)
                    
                    task.spawn(function()
                        task.wait(0.5)
                        isBoostActive = false
                        if boostButton then
                            boostButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                            boostButton.BackgroundTransparency = 0.5
                            boostButton.Text = "BOOST"
                        end
                    end)
                end
            end
        end)
        
        connections.boostToggle = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or not Movement.boostEnabled then return end
            if input.KeyCode == Enum.KeyCode.B then
                if refreshReferences() and humanoid and rootPart then
                    isBoostActive = true
                    boostButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                    boostButton.BackgroundTransparency = 0.2
                    boostButton.Text = "BOOSTING!"
                    
                    local camera = Workspace.CurrentCamera
                    if camera then
                        local boostDirection = camera.CFrame.LookVector
                        local boostForce = Instance.new("BodyVelocity")
                        boostForce.MaxForce = Vector3.new(4000, 0, 4000)
                        boostForce.Velocity = Vector3.new(boostDirection.X * 100, 0, boostDirection.Z * 100)
                        boostForce.Parent = rootPart
                        
                        game:GetService("Debris"):AddItem(boostForce, 0.5)
                        
                        task.spawn(function()
                            task.wait(0.5)
                            isBoostActive = false
                            if boostButton then
                                boostButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                                boostButton.BackgroundTransparency = 0.5
                                boostButton.Text = "BOOST"
                            end
                        end)
                    end
                end
            end
        end)
    else
        if boostButton then
            boostButton.Visible = false
        end
        isBoostActive = false
    end
end

-- Improved Rewind Movement (follows exact path with rotations) with proper sync
local function createRewindButton()
    if rewindButton then rewindButton:Destroy() end
    
    rewindButton = Instance.new("TextButton")
    rewindButton.Name = "RewindButton"
    rewindButton.Size = UDim2.new(0, 80, 0, 80)
    rewindButton.Position = UDim2.new(1, -100, 1, -190)
    rewindButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    rewindButton.BackgroundTransparency = 0.5
    rewindButton.BorderSizePixel = 0
    rewindButton.Text = "⏪"
    rewindButton.Font = Enum.Font.GothamBold
    rewindButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    rewindButton.TextSize = 24
    rewindButton.Visible = false
    rewindButton.ZIndex = 10
    rewindButton.Parent = ScreenGui or player.PlayerGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.2, 0)
    corner.Parent = rewindButton
end

local function toggleRewind(enabled)
    Movement.rewindEnabled = enabled
    updateButtonState("Smooth Rewind", enabled)
    
    if connections.rewind then
        connections.rewind:Disconnect()
        connections.rewind = nil
    end
    if connections.rewindInput then
        connections.rewindInput:Disconnect()
        connections.rewindInput = nil
    end
    if connections.rewindToggle then
        connections.rewindToggle:Disconnect()
        connections.rewindToggle = nil
    end
    
    if enabled then
        createRewindButton()
        if rewindButton then
            rewindButton.Visible = true
        end
        
        connections.rewind = RunService.Heartbeat:Connect(function()
            if not Movement.rewindEnabled then return end
            if not refreshReferences() or not rootPart then return end
            
            table.insert(positionHistory, {
                cframe = rootPart.CFrame,
                time = tick()
            })
            
            while #positionHistory > maxHistorySize do
                table.remove(positionHistory, 1)
            end
        end)
        
        local function performRewind()
            if #positionHistory < 30 then return end -- Minimum 1 second of history
            
            rewindButton.BackgroundTransparency = 0.1
            rewindButton.Text = "REWINDING"
            
            -- Reverse the history to play it backwards
            local reversedHistory = {}
            for i = #positionHistory, 1, -1 do
                table.insert(reversedHistory, positionHistory[i])
            end
            
            local startTime = tick()
            local rewindDuration = 2 -- Rewind takes 2 seconds to play back 6 seconds
            local historyLength = #reversedHistory
            local frameInterval = 6 / historyLength -- Time per frame in history
            
            local rewindConnection
            rewindConnection = RunService.Heartbeat:Connect(function()
                if not refreshReferences() or not rootPart then
                    rewindConnection:Disconnect()
                    return
                end
                
                local elapsed = tick() - startTime
                local progress = math.min(elapsed / rewindDuration, 1)
                
                -- Calculate which frame to display
                local frameIndex = math.floor(progress * (historyLength - 1)) + 1
                if frameIndex > historyLength then
                    frameIndex = historyLength
                end
                
                -- Get the target CFrame
                local targetCFrame = reversedHistory[frameIndex].cframe
                
                -- Apply the exact CFrame (position and rotation)
                rootPart.CFrame = targetCFrame
                rootPart.Velocity = Vector3.new(0, 0, 0) -- Prevent momentum
                
                if progress >= 1 then
                    rewindConnection:Disconnect()
                    if rewindButton then
                        rewindButton.BackgroundTransparency = 0.5
                        rewindButton.Text = "⏪"
                    end
                    -- Clear history after rewind to start fresh
                    positionHistory = {}
                end
            end)
        end
        
        connections.rewindInput = rewindButton.MouseButton1Click:Connect(function()
            if refreshReferences() and rootPart then
                performRewind()
            end
        end)
        
        connections.rewindToggle = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or not Movement.rewindEnabled then return end
            if input.KeyCode == Enum.KeyCode.T then
                if refreshReferences() and rootPart then
                    performRewind()
                end
            end
        end)
    else
        if rewindButton then
            rewindButton.Visible = false
        end
        positionHistory = {}
    end
end

-- Moon Gravity with proper sync and respawn handling
local function toggleMoonGravity(enabled)
    Movement.moonGravityEnabled = enabled
    updateButtonState("Moon Gravity", enabled)
    print("Moon Gravity:", enabled)
    
    if enabled then
        Workspace.Gravity = Movement.defaultGravity / 6
    else
        Workspace.Gravity = Movement.defaultGravity
    end
end

-- Double Jump with improved respawn handling and sync
local function toggleDoubleJump(enabled)
    Movement.doubleJumpEnabled = enabled
    updateButtonState("Double Jump", enabled)
    
    if connections.doubleJump then
        connections.doubleJump:Disconnect()
        connections.doubleJump = nil
    end
    
    if enabled then
        connections.doubleJump = UserInputService.JumpRequest:Connect(function()
            if not Movement.doubleJumpEnabled then return end
            if not refreshReferences() or not humanoid then return end
            
            if humanoid:GetState() ~= Enum.HumanoidStateType.Jumping and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
                Movement.jumpCount = 0
            elseif Movement.jumpCount < Movement.maxJumps then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                Movement.jumpCount = Movement.jumpCount + 1
            end
        end)
    else
        Movement.jumpCount = 0
    end
end

-- Infinite Jump with improved speed and sync
local function toggleInfiniteJump(enabled)
    Movement.infiniteJumpEnabled = enabled
    updateButtonState("Infinite Jump", enabled)
    
    if connections.infiniteJump then
        connections.infiniteJump:Disconnect()
        connections.infiniteJump = nil
    end
    
    if enabled then
        connections.infiniteJump = UserInputService.JumpRequest:Connect(function()
            if not Movement.infiniteJumpEnabled then return end
            if not refreshReferences() or not humanoid or not rootPart then return end
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            rootPart.Velocity = Vector3.new(rootPart.Velocity.X, getSettingValue("JumpHeight", 50) * 2, rootPart.Velocity.Z)
        end)
    end
end

-- Wall Climbing with improved respawn handling and sync, added mobile button
local function toggleWallClimb(enabled)
    Movement.wallClimbEnabled = enabled
    updateButtonState("Wall Climb", enabled)
    
    if connections.wallClimb then
        connections.wallClimb:Disconnect()
        connections.wallClimb = nil
    end
    if connections.wallClimbInput then
        connections.wallClimbInput:Disconnect()
        connections.wallClimbInput = nil
    end
    if connections.wallClimbButton then
        connections.wallClimbButton:Disconnect()
        connections.wallClimbButton = nil
    end
    
    if enabled then
        if wallClimbButton then
            wallClimbButton.Visible = true
        end
        
        connections.wallClimb = RunService.Heartbeat:Connect(function()
            if not Movement.wallClimbEnabled then return end
            if not refreshReferences() or not humanoid or not rootPart then return end
            
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {player.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            
            local directions = {
                rootPart.CFrame.RightVector,
                -rootPart.CFrame.RightVector,
                rootPart.CFrame.LookVector,
                -rootPart.CFrame.LookVector
            }
            
            local isNearWall = false
            for _, direction in ipairs(directions) do
                local raycast = Workspace:Raycast(rootPart.Position, direction * 3, raycastParams)
                if raycast and raycast.Instance and raycast.Normal.Y < 0.1 then
                    isNearWall = true
                    break
                end
            end
            
            if isNearWall then
                rootPart.Velocity = Vector3.new(rootPart.Velocity.X, 30, rootPart.Velocity.Z)
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
        
        connections.wallClimbInput = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == Enum.KeyCode.C then
                Movement.wallClimbEnabled = not Movement.wallClimbEnabled
                updateButtonState("Wall Climb", Movement.wallClimbEnabled)
                print("Wall Climb:", Movement.wallClimbEnabled)
            end
        end)
        
        connections.wallClimbButton = wallClimbButton.MouseButton1Click:Connect(function()
            Movement.wallClimbEnabled = not Movement.wallClimbEnabled
            updateButtonState("Wall Climb", Movement.wallClimbEnabled)
            wallClimbButton.BackgroundColor3 = Movement.wallClimbEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
            wallClimbButton.Text = Movement.wallClimbEnabled and "CLIMBING" or "CLIMB"
            print("Wall Climb (mobile):", Movement.wallClimbEnabled)
        end)
    else
        if wallClimbButton then
            wallClimbButton.Visible = false
            wallClimbButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            wallClimbButton.Text = "CLIMB"
        end
    end
end

-- Fly Hack with settings integration, proper sync, and PC controls (modified to Infinite Yield style with BodyGyro)
local function toggleFly(enabled)
    Movement.flyEnabled = enabled
    updateButtonState("Fly", enabled)
    print("Fly toggle:", enabled)
    
    local flyConnections = {"fly", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", "flyDown", "flyDownEnd", "flyKeyBegan", "flyKeyEnded"}
    for _, connName in ipairs(flyConnections) do
        if connections[connName] then
            connections[connName]:Disconnect()
            connections[connName] = nil
        end
    end
    
    flyKeys = {forward = false, back = false, left = false, right = false, up = false, down = false}
    
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if flyBodyGyro then
        flyBodyGyro:Destroy()
        flyBodyGyro = nil
    end
    
    if enabled then
        task.spawn(function()
            task.wait(0.1)
            if not refreshReferences() or not rootPart or not humanoid then
                print("Failed to get rootPart for fly")
                Movement.flyEnabled = false
                updateButtonState("Fly", false)
                return
            end
            
            humanoid.PlatformStand = true
            flyBodyVelocity = Instance.new("BodyVelocity")
            flyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            flyBodyVelocity.Parent = rootPart
            
            flyBodyGyro = Instance.new("BodyGyro")
            flyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            flyBodyGyro.P = 9e4
            flyBodyGyro.Parent = rootPart
            
            if flyJoystickFrame then flyJoystickFrame.Visible = true end
            if flyUpButton then flyUpButton.Visible = true end
            if flyDownButton then flyDownButton.Visible = true end
            
            connections.fly = RunService.Heartbeat:Connect(function()
                if not Movement.flyEnabled then return end
                if not refreshReferences() or not rootPart then return end
                
                if not flyBodyVelocity or flyBodyVelocity.Parent ~= rootPart then
                    if flyBodyVelocity then flyBodyVelocity:Destroy() end
                    flyBodyVelocity = Instance.new("BodyVelocity")
                    flyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                    flyBodyVelocity.Parent = rootPart
                end
                
                if not flyBodyGyro or flyBodyGyro.Parent ~= rootPart then
                    if flyBodyGyro then flyBodyGyro:Destroy() end
                    flyBodyGyro = Instance.new("BodyGyro")
                    flyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                    flyBodyGyro.P = 9e4
                    flyBodyGyro.Parent = rootPart
                end
                
                local camera = Workspace.CurrentCamera
                if not camera then return end
                
                flyBodyGyro.CFrame = camera.CFrame
                
                local flyDirection = Vector3.new(0, 0, 0)
                local verticalInput = 0
                flySpeed = getSettingValue("FlySpeed", 50)
                
                -- Joystick input
                if joystickDelta.Magnitude > 0.05 then
                    local forward = camera.CFrame.LookVector
                    local right = camera.CFrame.RightVector
                    
                    forward = Vector3.new(forward.X, 0, forward.Z).Unit
                    right = Vector3.new(right.X, 0, right.Z).Unit
                    
                    flyDirection = flyDirection + (right * joystickDelta.X) + (forward * -joystickDelta.Y)
                end
                
                -- Keyboard input
                local keyDirection = Vector3.new(0, 0, 0)
                local flatLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit
                local flatRight = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z).Unit
                
                if flyKeys.forward then keyDirection = keyDirection + flatLook end
                if flyKeys.back then keyDirection = keyDirection - flatLook end
                if flyKeys.left then keyDirection = keyDirection - flatRight end
                if flyKeys.right then keyDirection = keyDirection + flatRight end
                if flyKeys.up then keyDirection = keyDirection + Vector3.new(0, 1, 0) end
                if flyKeys.down then keyDirection = keyDirection + Vector3.new(0, -1, 0) end
                
                flyDirection = flyDirection + keyDirection
                
                -- Button input for vertical (mobile)
                if flyUpButton and flyUpButton.BackgroundTransparency == 0.1 then
                    verticalInput = 1
                elseif flyDownButton and flyDownButton.BackgroundTransparency == 0.1 then
                    verticalInput = -1
                end
                
                if verticalInput ~= 0 then
                    flyDirection = flyDirection + Vector3.new(0, verticalInput, 0)
                end
                
                if flyDirection.Magnitude > 0 then
                    flyBodyVelocity.Velocity = flyDirection.Unit * flySpeed
                else
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                end
            end)
            
            connections.flyInput = UserInputService.InputChanged:Connect(handleFlyJoystick)
            connections.flyBegan = UserInputService.InputBegan:Connect(handleFlyJoystick)
            connections.flyEnded = UserInputService.InputEnded:Connect(handleFlyJoystick)
            
            if flyUpButton then
                connections.flyUp = flyUpButton.MouseButton1Down:Connect(function()
                    flyUpButton.BackgroundTransparency = 0.1
                end)
                connections.flyUpEnd = flyUpButton.MouseButton1Up:Connect(function()
                    flyUpButton.BackgroundTransparency = 0.5
                end)
            end
            
            if flyDownButton then
                connections.flyDown = flyDownButton.MouseButton1Down:Connect(function()
                    flyDownButton.BackgroundTransparency = 0.1
                end)
                connections.flyDownEnd = flyDownButton.MouseButton1Up:Connect(function()
                    flyDownButton.BackgroundTransparency = 0.5
                end)
            end
            
            connections.flyKeyBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed or not Movement.flyEnabled then return end
                local kc = input.KeyCode
                if kc == Enum.KeyCode.W then flyKeys.forward = true
                elseif kc == Enum.KeyCode.S then flyKeys.back = true
                elseif kc == Enum.KeyCode.A then flyKeys.left = true
                elseif kc == Enum.KeyCode.D then flyKeys.right = true
                elseif kc == Enum.KeyCode.Space then flyKeys.up = true
                elseif kc == Enum.KeyCode.LeftShift then flyKeys.down = true
                end
            end)
            
            connections.flyKeyEnded = UserInputService.InputEnded:Connect(function(input)
                local kc = input.KeyCode
                if kc == Enum.KeyCode.W then flyKeys.forward = false
                elseif kc == Enum.KeyCode.S then flyKeys.back = false
                elseif kc == Enum.KeyCode.A then flyKeys.left = false
                elseif kc == Enum.KeyCode.D then flyKeys.right = false
                elseif kc == Enum.KeyCode.Space then flyKeys.up = false
                elseif kc == Enum.KeyCode.LeftShift then flyKeys.down = false
                end
            end)
        end)
    else
        if humanoid then
            humanoid.PlatformStand = false
        end
        if flyJoystickFrame then 
            flyJoystickFrame.Visible = false
            flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
        end
        if flyUpButton then 
            flyUpButton.Visible = false
            flyUpButton.BackgroundTransparency = 0.5
        end
        if flyDownButton then 
            flyDownButton.Visible = false
            flyDownButton.BackgroundTransparency = 0.5
        end
        
        joystickDelta = Vector2.new(0, 0)
        isTouchingJoystick = false
        joystickTouchId = nil
    end
end

-- NoClip with better respawn handling and sync
local function toggleNoclip(enabled)
    Movement.noclipEnabled = enabled
    updateButtonState("NoClip", enabled)
    
    if connections.noclip then
        connections.noclip:Disconnect()
        connections.noclip = nil
    end
    
    if enabled then
        connections.noclip = RunService.Stepped:Connect(function()
            if not Movement.noclipEnabled then return end
            if not refreshReferences() or not player.Character then return end
            
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    else
        if refreshReferences() and player.Character then
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- Walk on Water with better respawn handling and sync, increased reliability
local function toggleWalkOnWater(enabled)
    Movement.walkOnWaterEnabled = enabled
    updateButtonState("Walk on Water", enabled)
    
    if connections.walkOnWater then
        connections.walkOnWater:Disconnect()
        connections.walkOnWater = nil
    end
    
    if enabled then
        connections.walkOnWater = RunService.Heartbeat:Connect(function()
            if not Movement.walkOnWaterEnabled then return end
            if not refreshReferences() or not rootPart or not player.Character then return end
            
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {player.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            
            local raycast = Workspace:Raycast(rootPart.Position, Vector3.new(0, -20, 0), raycastParams)  -- Increased ray length
            if raycast and raycast.Instance and (raycast.Instance.Material == Enum.Material.Water or string.lower(raycast.Instance.Name):find("water")) then
                local waterWalkPart = rootPart:FindFirstChild("WaterWalkPart")
                if not waterWalkPart then
                    waterWalkPart = Instance.new("Part")
                    waterWalkPart.Name = "WaterWalkPart"
                    waterWalkPart.Anchored = true
                    waterWalkPart.CanCollide = true
                    waterWalkPart.Transparency = 1
                    waterWalkPart.Size = Vector3.new(15, 0.2, 15)  -- Larger size
                    waterWalkPart.Parent = rootPart  -- Parent to rootPart to follow player
                end
                waterWalkPart.Position = Vector3.new(rootPart.Position.X, raycast.Position.Y + 0.1, rootPart.Position.Z)
            end
        end)
    end
end

-- Enhanced Player NoClip with Anti-Fling Protection and sync
local function togglePlayerNoclip(enabled)
    Movement.playerNoclipEnabled = enabled
    updateButtonState("Player NoClip", enabled)
    
    if connections.playerNoclip then
        connections.playerNoclip:Disconnect()
        connections.playerNoclip = nil
    end
    if connections.antiFling then
        connections.antiFling:Disconnect()
        connections.antiFling = nil
    end
    
    if enabled then
        connections.playerNoclip = RunService.Heartbeat:Connect(function()
            if not Movement.playerNoclipEnabled then return end
            if not refreshReferences() or not player.Character then return end
            
            for _, otherPlayer in pairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character then
                    for _, part in pairs(otherPlayer.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end
        end)
        
        connections.antiFling = RunService.Heartbeat:Connect(function()
            if not Movement.playerNoclipEnabled then return end
            if not refreshReferences() or not rootPart then return end
            
            local currentVelocity = rootPart.Velocity
            local maxNormalVelocity = 200
            
            if currentVelocity.Magnitude > maxNormalVelocity then
                rootPart.Velocity = Vector3.new(0, 0, 0)
                
                local bodyAngularVelocity = rootPart:FindFirstChild("BodyAngularVelocity")
                if bodyAngularVelocity then
                    bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
                end
            end
            
            for _, otherPlayer in pairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local otherRoot = otherPlayer.Character.HumanoidRootPart
                    
                    for _, obj in pairs(otherRoot:GetChildren()) do
                        if obj:IsA("BodyVelocity") or obj:IsA("BodyPosition") or obj:IsA("BodyAngularVelocity") then
                            if obj:IsA("BodyVelocity") and obj.Velocity.Magnitude > maxNormalVelocity then
                                obj:Destroy()
                            elseif obj:IsA("BodyPosition") and (obj.Position - rootPart.Position).Magnitude > 1000 then
                                obj:Destroy()
                            elseif obj:IsA("BodyAngularVelocity") and obj.AngularVelocity.Magnitude > 50 then
                                obj:Destroy()
                            end
                        end
                    end
                end
            end
        end)
    else
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

-- Super Swim with better reference handling and sync
local function toggleSwim(enabled)
    Movement.swimEnabled = enabled
    updateButtonState("Super Swim", enabled)
    
    local function applySwim()
        if refreshReferences() and humanoid then
            if enabled then
                pcall(function()
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
                    humanoid.WalkSpeed = 50
                end)
            else
                pcall(function()
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
                    humanoid.WalkSpeed = Movement.speedEnabled and getSettingValue("WalkSpeed", 50) or Movement.defaultWalkSpeed
                end)
            end
            return true
        end
        return false
    end
    
    if not applySwim() then
        task.spawn(function()
            task.wait(0.1)
            applySwim()
        end)
    end
end

-- Function to apply current settings to active features
function Movement.applySettings()
    print("Applying Movement settings")
    
    if Movement.speedEnabled then
        toggleSpeed(true)
    end
    
    if Movement.jumpEnabled then
        toggleJump(true)
    end
    
    if Movement.sprintEnabled then
        toggleSprint(true)
    end
end

-- Function to create buttons for Movement features
function Movement.loadMovementButtons(createButton, createToggleButton)
    print("Loading movement buttons")
    if not createButton or not createToggleButton then
        warn("Error: createButton or createToggleButton not provided!")
        return
    end
    
    setupScrollFrame()
    
    createToggleButton("Speed Hack", toggleSpeed)
    createToggleButton("Jump Hack", toggleJump)
    createToggleButton("Moon Gravity", toggleMoonGravity)
    createToggleButton("Double Jump", toggleDoubleJump)
    createToggleButton("Infinite Jump", toggleInfiniteJump)
    createToggleButton("Wall Climb", toggleWallClimb)
    createToggleButton("Player NoClip", togglePlayerNoclip)
    createToggleButton("Fly", toggleFly)
    createToggleButton("NoClip", toggleNoclip)
    createToggleButton("Walk on Water", toggleWalkOnWater)
    createToggleButton("Super Swim", toggleSwim)
    createToggleButton("Float", toggleFloat)
    createToggleButton("Smooth Rewind", toggleRewind)
    createToggleButton("Boost (NOS)", toggleBoost)
    createToggleButton("Slow Fall", toggleSlowFall)
    createToggleButton("Fast Fall", toggleFastFall)
    createToggleButton("Sprint", toggleSprint)
end

-- Enhanced reset function with proper state sync
function Movement.resetStates()
    print("Resetting Movement states")
    
    -- Store current states before reset
    local currentStates = {
        speedEnabled = Movement.speedEnabled,
        jumpEnabled = Movement.jumpEnabled,
        flyEnabled = Movement.flyEnabled,
        noclipEnabled = Movement.noclipEnabled,
        infiniteJumpEnabled = Movement.infiniteJumpEnabled,
        walkOnWaterEnabled = Movement.walkOnWaterEnabled,
        swimEnabled = Movement.swimEnabled,
        moonGravityEnabled = Movement.moonGravityEnabled,
        doubleJumpEnabled = Movement.doubleJumpEnabled,
        wallClimbEnabled = Movement.wallClimbEnabled,
        playerNoclipEnabled = Movement.playerNoclipEnabled,
        floatEnabled = Movement.floatEnabled,
        rewindEnabled = Movement.rewindEnabled,
        boostEnabled = Movement.boostEnabled,
        slowFallEnabled = Movement.slowFallEnabled,
        fastFallEnabled = Movement.fastFallEnabled,
        sprintEnabled = Movement.sprintEnabled
    }
    
    -- Deactivate moon gravity on death as per request
    if currentStates.moonGravityEnabled then
        Movement.moonGravityEnabled = false
        updateButtonState("Moon Gravity", false)
    end
    
    -- Set flag to indicate we're resetting (not actually disabling)
    isRespawning = true
    
    -- Disconnect all connections
    local allConnections = {
        "fly", "noclip", "playerNoclip", "infiniteJump", "walkOnWater", "doubleJump", 
        "wallClimb", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", 
        "flyDown", "flyDownEnd", "wallClimbInput", "float", "floatInput", 
        "floatBegan", "floatEnded", "antiFling", "rewind", "rewindInput", 
        "rewindToggle", "boost", "boostInput", "boostToggle", "slowFall", 
        "fastFall", "sprint", "sprintInput", "sprintToggle", "flyKeyBegan", 
        "flyKeyEnded", "floatKeyBegan", "floatKeyEnded", "wallClimbButton"
    }
    for _, connName in ipairs(allConnections) do
        if connections[connName] then
            connections[connName]:Disconnect()
            connections[connName] = nil
        end
    end
    
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if flyBodyGyro then
        flyBodyGyro:Destroy()
        flyBodyGyro = nil
    end
    
    -- Reset temporary variables but keep feature states
    Movement.jumpCount = 0
    joystickDelta = Vector2.new(0, 0)
    isTouchingJoystick = false
    joystickTouchId = nil
    positionHistory = {}
    isBoostActive = false
    
    -- Reset physics if character exists
    if refreshReferences() then
        if humanoid then
            humanoid.WalkSpeed = Movement.defaultWalkSpeed
            humanoid.PlatformStand = false
            if humanoid:FindFirstChild("JumpHeight") then
                humanoid.JumpHeight = Movement.defaultJumpHeight
            else
                humanoid.JumpPower = Movement.defaultJumpPower
            end
            pcall(function()
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            end)
        end
        
        if player.Character then
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
    
    -- Always reset workspace gravity on reset
    Workspace.Gravity = Movement.defaultGravity
    
    -- Reset player collisions
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            for _, part in pairs(otherPlayer.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
    
    -- Hide mobile controls temporarily
    if flyJoystickFrame then
        flyJoystickFrame.Visible = false
        flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
    end
    if flyUpButton then
        flyUpButton.Visible = false
        flyUpButton.BackgroundTransparency = 0.5
    end
    if flyDownButton then
        flyDownButton.Visible = false
        flyDownButton.BackgroundTransparency = 0.5
    end
    if rewindButton then
        rewindButton.Visible = false
        rewindButton.Text = "⏪"
    end
    if boostButton then
        boostButton.Visible = false
        boostButton.Text = "BOOST"
    end
    if sprintButton then
        sprintButton.Visible = false
        sprintButton.Text = "SPRINT"
    end
    if wallClimbButton then
        wallClimbButton.Visible = false
        wallClimbButton.Text = "CLIMB"
    end
    
    -- Clear respawn flag
    isRespawning = false
    
    print("Movement reset complete, states preserved for reapplication")
end

-- Enhanced reference update function with proper state restoration
function Movement.updateReferences(newHumanoid, newRootPart)
    print("Updating Movement references")
    humanoid = newHumanoid
    rootPart = newRootPart
    
    if humanoid then
        Movement.defaultWalkSpeed = humanoid.WalkSpeed or 16
        if humanoid:FindFirstChild("JumpHeight") then
            Movement.defaultJumpHeight = humanoid.JumpHeight or 7.2
        else
            Movement.defaultJumpPower = humanoid.JumpPower or 50
        end
    end
    
    Movement.defaultGravity = Workspace.Gravity or 196.2
    
    createMobileControls()
    
    -- Reapply all active states after a short delay
    task.spawn(function()
        task.wait(0.3) -- Give time for character to fully load
        
        local statesToReapply = {
            {Movement.speedEnabled, toggleSpeed, "Speed"},
            {Movement.jumpEnabled, toggleJump, "Jump"},
            {Movement.moonGravityEnabled, toggleMoonGravity, "Moon Gravity"},
            {Movement.doubleJumpEnabled, toggleDoubleJump, "Double Jump"},
            {Movement.infiniteJumpEnabled, toggleInfiniteJump, "Infinite Jump"},
            {Movement.wallClimbEnabled, toggleWallClimb, "Wall Climb"},
            {Movement.playerNoclipEnabled, togglePlayerNoclip, "Player NoClip"},
            {Movement.noclipEnabled, toggleNoclip, "NoClip"},
            {Movement.walkOnWaterEnabled, toggleWalkOnWater, "Walk on Water"},
            {Movement.swimEnabled, toggleSwim, "Super Swim"},
            {Movement.floatEnabled, toggleFloat, "Float"},
            {Movement.flyEnabled, toggleFly, "Fly"},
            {Movement.rewindEnabled, toggleRewind, "Smooth Rewind"},
            {Movement.boostEnabled, toggleBoost, "Boost"},
            {Movement.slowFallEnabled, toggleSlowFall, "Slow Fall"},
            {Movement.fastFallEnabled, toggleFastFall, "Fast Fall"},
            {Movement.sprintEnabled, toggleSprint, "Sprint"}
        }
        
        for _, state in ipairs(statesToReapply) do
            if state[1] then
                print("Reapplying", state[3])
                state[2](true)
            end
        end
        
        -- Update all button states to reflect current status
        for featureName, enabled in pairs({
            ["Speed Hack"] = Movement.speedEnabled,
            ["Jump Hack"] = Movement.jumpEnabled,
            ["Moon Gravity"] = Movement.moonGravityEnabled,
            ["Double Jump"] = Movement.doubleJumpEnabled,
            ["Infinite Jump"] = Movement.infiniteJumpEnabled,
            ["Wall Climb"] = Movement.wallClimbEnabled,
            ["Player NoClip"] = Movement.playerNoclipEnabled,
            ["Fly"] = Movement.flyEnabled,
            ["NoClip"] = Movement.noclipEnabled,
            ["Walk on Water"] = Movement.walkOnWaterEnabled,
            ["Super Swim"] = Movement.swimEnabled,
            ["Float"] = Movement.floatEnabled,
            ["Smooth Rewind"] = Movement.rewindEnabled,
            ["Boost (NOS)"] = Movement.boostEnabled,
            ["Slow Fall"] = Movement.slowFallEnabled,
            ["Fast Fall"] = Movement.fastFallEnabled,
            ["Sprint"] = Movement.sprintEnabled
        }) do
            updateButtonState(featureName, enabled)
        end
    end)
end

-- Function to set dependencies
function Movement.init(deps)
    print("Initializing Movement module")
    if not deps then
        warn("Error: No dependencies provided!")
        return false
    end
    
    Players = deps.Players or game:GetService("Players")
    RunService = deps.RunService or game:GetService("RunService")
    Workspace = deps.Workspace or game:GetService("Workspace")
    UserInputService = deps.UserInputService or game:GetService("UserInputService")
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    connections = deps.connections or {}
    buttonStates = deps.buttonStates or {}
    ScrollFrame = deps.ScrollFrame
    ScreenGui = deps.ScreenGui
    settings = deps.settings or {}
    player = deps.player or Players.LocalPlayer
    
    if not Players or not RunService or not Workspace or not UserInputService then
        warn("Critical services missing!")
        return false
    end
    
    if humanoid then
        Movement.defaultWalkSpeed = humanoid.WalkSpeed or 16
        if humanoid:FindFirstChild("JumpHeight") then
            Movement.defaultJumpHeight = humanoid.JumpHeight or 7.2
        else
            Movement.defaultJumpPower = humanoid.JumpPower or 50
        end
    end
    Movement.defaultGravity = Workspace.Gravity or 196.2
    
    -- Initialize all states as false (they will be set by button toggles)
    Movement.speedEnabled = false
    Movement.jumpEnabled = false
    Movement.flyEnabled = false
    Movement.noclipEnabled = false
    Movement.infiniteJumpEnabled = false
    Movement.walkOnWaterEnabled = false
    Movement.swimEnabled = false
    Movement.moonGravityEnabled = false
    Movement.doubleJumpEnabled = false
    Movement.wallClimbEnabled = false
    Movement.playerNoclipEnabled = false
    Movement.floatEnabled = false
    Movement.rewindEnabled = false
    Movement.boostEnabled = false
    Movement.slowFallEnabled = false
    Movement.fastFallEnabled = false
    Movement.sprintEnabled = false
    
    Movement.jumpCount = 0
    joystickDelta = Vector2.new(0, 0)
    isTouchingJoystick = false
    joystickTouchId = nil
    
    positionHistory = {}
    isBoostActive = false
    isRespawning = false
    
    createMobileControls()
    setupScrollFrame()
    
    print("Movement module initialized successfully")
    return true
end

-- Enhanced debug function
function Movement.debug()
    print("=== Enhanced Movement Module Debug Info ===")
    print("Movement Features:")
    print("  speedEnabled:", Movement.speedEnabled)
    print("  jumpEnabled:", Movement.jumpEnabled)
    print("  flyEnabled:", Movement.flyEnabled)
    print("  noclipEnabled:", Movement.noclipEnabled)
    print("  infiniteJumpEnabled:", Movement.infiniteJumpEnabled)
    print("  walkOnWaterEnabled:", Movement.walkOnWaterEnabled)
    print("  swimEnabled:", Movement.swimEnabled)
    print("  moonGravityEnabled:", Movement.moonGravityEnabled)
    print("  doubleJumpEnabled:", Movement.doubleJumpEnabled)
    print("  wallClimbEnabled:", Movement.wallClimbEnabled)
    print("  playerNoclipEnabled:", Movement.playerNoclipEnabled)
    print("  floatEnabled:", Movement.floatEnabled)
    print("  rewindEnabled:", Movement.rewindEnabled)
    print("  boostEnabled:", Movement.boostEnabled)
    print("  slowFallEnabled:", Movement.slowFallEnabled)
    print("  fastFallEnabled:", Movement.fastFallEnabled)
    print("  sprintEnabled:", Movement.sprintEnabled)
    
    print("New Feature Data:")
    print("  positionHistory entries:", #positionHistory)
    print("  isBoostActive:", isBoostActive)
    print("  isRespawning:", isRespawning)
    
    print("References:")
    print("  player:", player ~= nil)
    print("  humanoid:", humanoid ~= nil)
    print("  rootPart:", rootPart ~= nil)
    print("  player.Character:", player and player.Character ~= nil)
    
    print("Settings Integration:")
    if settings then
        print("  WalkSpeed setting:", getSettingValue("WalkSpeed", "not found"))
        print("  JumpHeight setting:", getSettingValue("JumpHeight", "not found"))
        print("  FlySpeed setting:", getSettingValue("FlySpeed", "not found"))
        print("  SprintSpeed setting:", getSettingValue("SprintSpeed", "not found"))
    else
        print("  settings: nil")
    end
    
    print("UI Elements:")
    print("  flyJoystickFrame:", flyJoystickFrame ~= nil)
    print("  flyUpButton:", flyUpButton ~= nil)
    print("  flyDownButton:", flyDownButton ~= nil)
    print("  rewindButton:", rewindButton ~= nil)
    print("  boostButton:", boostButton ~= nil)
    print("  sprintButton:", sprintButton ~= nil)
    
    print("Button States:")
    if buttonStates then
        for name, button in pairs(buttonStates) do
            if button and button.Parent then
                local isGreen = button.BackgroundColor3 == Color3.fromRGB(0, 255, 0)
                print("  " .. name .. ": " .. (isGreen and "ACTIVE" or "INACTIVE"))
            end
        end
    end
    
    print("Active Connections:")
    local activeConnections = 0
    for name, conn in pairs(connections) do
        if conn and conn.Connected then
            activeConnections = activeConnections + 1
            print("  " .. name .. ": connected")
        end
    end
    print("  Total active:", activeConnections)
    print("===============================================")
end

-- Add cleanup function for when module is unloaded
function Movement.cleanup()
    print("Cleaning up Movement module")
    
    Movement.resetStates()
    
    if flyJoystickFrame then flyJoystickFrame:Destroy() end
    if flyUpButton then flyUpButton:Destroy() end
    if flyDownButton then flyDownButton:Destroy() end
    if rewindButton then rewindButton:Destroy() end
    if boostButton then boostButton:Destroy() end
    if sprintButton then sprintButton:Destroy() end
    if wallClimbButton then wallClimbButton:Destroy() end
    
    flyJoystickFrame = nil
    flyJoystickKnob = nil
    flyUpButton = nil
    flyDownButton = nil
    flyBodyVelocity = nil
    flyBodyGyro = nil
    rewindButton = nil
    boostButton = nil
    sprintButton = nil
    wallClimbButton = nil
    
    positionHistory = {}
    isBoostActive = false
    isRespawning = false
    
    print("Movement module cleaned up")
end

return Movement