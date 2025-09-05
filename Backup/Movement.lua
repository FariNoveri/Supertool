-- Movement.lua - Updated version with enhanced GUI and chat commands /fly and /unfly for SpeedHack, JumpHack, and Fly

-- Dependencies
local Players, RunService, Workspace, UserInputService, humanoid, rootPart, connections, buttonStates, ScrollFrame, ScreenGui, settings, player

-- Initialize module
local Movement = {}

-- Movement states
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
Movement.isSprinting = false

-- Default values
Movement.defaultWalkSpeed = 16
Movement.defaultJumpPower = 50
Movement.defaultJumpHeight = 7.2
Movement.defaultGravity = 196.2
Movement.jumpCount = 0
Movement.maxJumps = 1

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
local maxHistorySize = 180
local isBoostActive = false
local isRespawning = false

-- New settings GUI
local settingsFrame
local speedInput, jumpInput, sprintInput, flyInput, swimInput
local applyButton, closeButton

-- Chat system
local function sendServerMessage(message)
    local StarterGui = game:GetService("StarterGui")
    if StarterGui then
        pcall(function()
            StarterGui:SetCore("ChatMakeSystemMessage", {
                Text = "[SERVER] " .. message;
                Color = Color3.fromRGB(0, 255, 0);
                Font = Enum.Font.GothamBold;
                FontSize = Enum.FontSize.Size18;
            })
        end)
    end
    
    -- Alternative method - print to console
    print("[SERVER] " .. message)
    
    -- Try to add to chat directly if possible
    local Chat = game:GetService("Chat")
    if Chat then
        pcall(function()
            local chatService = require(game:GetService("ServerScriptService"):WaitForChild("ChatServiceRunner"):WaitForChild("ChatService"))
            if chatService then
                chatService:InternalSendSystemMessage("[SERVER] " .. message, "All")
            end
        end)
    end
end

-- Scroll frame for UI
local function setupScrollFrame()
    if ScrollFrame then
        ScrollFrame.ScrollingEnabled = true
        ScrollFrame.ScrollBarThickness = 8
        ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 600)
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

-- Update button visual state
local function updateButtonState(featureName, enabled)
    if buttonStates and buttonStates[featureName] then
        local button = buttonStates[featureName]
        if button and button.Parent then
            button.BackgroundColor3 = enabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(40, 40, 40)
            button.TextColor3 = enabled and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        end
    end
end

-- Create settings GUI for SpeedHack, JumpHack, and Fly
local function createSettingsGUI()
    if settingsFrame then settingsFrame:Destroy() end

    settingsFrame = Instance.new("Frame")
    settingsFrame.Name = "SettingsFrame"
    settingsFrame.Size = UDim2.new(0, 200, 0, 300)
    settingsFrame.Position = UDim2.new(0.5, -100, 0.5, -150)
    settingsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    settingsFrame.BorderSizePixel = 0
    settingsFrame.Visible = false
    settingsFrame.ZIndex = 15
    settingsFrame.Parent = ScreenGui or player.PlayerGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.1, 0)
    corner.Parent = settingsFrame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "Movement Settings"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.Parent = settingsFrame

    local function createInputField(name, settingName, defaultValue, yOffset)
        local label = Instance.new("TextLabel")
        label.Name = name .. "Label"
        label.Size = UDim2.new(1, -10, 0, 20)
        label.Position = UDim2.new(0, 5, 0, yOffset)
        label.BackgroundTransparency = 1
        label.Text = name .. ":"
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = settingsFrame

        local input = Instance.new("TextBox")
        input.Name = name .. "Input"
        input.Size = UDim2.new(1, -10, 0, 30)
        input.Position = UDim2.new(0, 5, 0, yOffset + 20)
        input.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        input.TextColor3 = Color3.fromRGB(255, 255, 255)
        input.Text = tostring(getSettingValue(settingName, defaultValue))
        input.Font = Enum.Font.Gotham
        input.TextSize = 14
        input.Parent = settingsFrame

        return input
    end

    speedInput = createInputField("Speed", "WalkSpeed", 50, 40)
    jumpInput = createInputField("Jump", "JumpHeight", 50, 90)
    sprintInput = createInputField("Sprint", "SprintSpeed", 300, 140)
    flyInput = createInputField("Fly", "FlySpeed", 50, 190)
    swimInput = createInputField("Swim", "SwimSpeed", 100, 240)

    applyButton = Instance.new("TextButton")
    applyButton.Name = "ApplyButton"
    applyButton.Size = UDim2.new(0.45, -10, 0, 30)
    applyButton.Position = UDim2.new(0, 5, 1, -35)
    applyButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
    applyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    applyButton.Text = "Apply"
    applyButton.Font = Enum.Font.GothamBold
    applyButton.TextSize = 14
    applyButton.Parent = settingsFrame

    closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0.45, -10, 0, 30)
    closeButton.Position = UDim2.new(0.55, 5, 1, -35)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Text = "Close"
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 14
    closeButton.Parent = settingsFrame

    applyButton.MouseButton1Click:Connect(function()
        local speedVal = tonumber(speedInput.Text)
        local jumpVal = tonumber(jumpInput.Text)
        local sprintVal = tonumber(sprintInput.Text)
        local flyVal = tonumber(flyInput.Text)
        local swimVal = tonumber(swimInput.Text)

        if speedVal then settings.WalkSpeed = {value = speedVal} end
        if jumpVal then settings.JumpHeight = {value = jumpVal} end
        if sprintVal then settings.SprintSpeed = {value = sprintVal} end
        if flyVal then settings.FlySpeed = {value = flyVal} end
        if swimVal then settings.SwimSpeed = {value = swimVal} end

        Movement.applySettings()
        settingsFrame.Visible = false
    end)

    closeButton.MouseButton1Click:Connect(function()
        settingsFrame.Visible = false
    end)
end

-- Create mobile controls
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

-- Joystick handling for float
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

-- Joystick handling for fly
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

-- Speed Hack with settings integration
local function toggleSpeed(enabled)
    Movement.speedEnabled = enabled
    updateButtonState("Speed Hack", enabled)
    
    if enabled then
        local function applySpeed()
            if refreshReferences() and humanoid then
                local speedValue = getSettingValue("WalkSpeed", 50)
                humanoid.WalkSpeed = speedValue
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

-- Jump Hack with settings integration
local function toggleJump(enabled)
    Movement.jumpEnabled = enabled
    updateButtonState("Jump Hack", enabled)
    
    if enabled then
        local function applyJump()
            if refreshReferences() and humanoid then
                local jumpValue = getSettingValue("JumpHeight", 50)
                if humanoid:FindFirstChild("JumpHeight") then
                    humanoid.JumpHeight = jumpValue
                else
                    humanoid.JumpPower = jumpValue * 2.4
                end
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

-- Slow Fall
local function toggleSlowFall(enabled)
    Movement.slowFallEnabled = enabled
    updateButtonState("Slow Fall", enabled)
    
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

-- Fast Fall
local function toggleFastFall(enabled)
    Movement.fastFallEnabled = enabled
    updateButtonState("Fast Fall", enabled)
    
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

-- Sprint feature
local function toggleSprint(enabled)
    Movement.sprintEnabled = enabled
    updateButtonState("Sprint", enabled)
    
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
        
        connections.sprintInput = sprintButton.MouseButton1Click:Connect(function()
            if refreshReferences() and humanoid then
                Movement.isSprinting = not Movement.isSprinting
                sprintButton.BackgroundColor3 = Movement.isSprinting and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
                sprintButton.BackgroundTransparency = Movement.isSprinting and 0.2 or 0.5
                sprintButton.Text = Movement.isSprinting and "SPRINTING!" or "SPRINT"
                
                humanoid.WalkSpeed = Movement.isSprinting and getSettingValue("SprintSpeed", 300) or (Movement.speedEnabled and getSettingValue("WalkSpeed", 50) or Movement.defaultWalkSpeed)
            end
        end)
        
        connections.sprintToggle = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or not Movement.sprintEnabled then return end
            if input.KeyCode == Enum.KeyCode.LeftShift then
                if refreshReferences() and humanoid then
                    Movement.isSprinting = not Movement.isSprinting
                    sprintButton.BackgroundColor3 = Movement.isSprinting and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
                    sprintButton.BackgroundTransparency = Movement.isSprinting and 0.2 or 0.5
                    sprintButton.Text = Movement.isSprinting and "SPRINTING!" or "SPRINT"
                    
                    humanoid.WalkSpeed = Movement.isSprinting and getSettingValue("SprintSpeed", 300) or (Movement.speedEnabled and getSettingValue("WalkSpeed", 50) or Movement.defaultWalkSpeed)
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
        Movement.isSprinting = false
    end
end

-- Float Hack
local function toggleFloat(enabled)
    Movement.floatEnabled = enabled
    updateButtonState("Float", enabled)
    
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
                
                if joystickDelta.Magnitude > 0.05 then
                    local forward = camera.CFrame.LookVector
                    local right = camera.CFrame.RightVector
                    
                    forward = Vector3.new(forward.X, 0, forward.Z).Unit
                    right = Vector3.new(right.X, 0, right.Z).Unit
                    
                    floatDirection = floatDirection + (right * joystickDelta.X) + (forward * -joystickDelta.Y)
                end
                
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

-- Boost
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

-- Rewind Movement
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
            if #positionHistory < 30 then return end
            
            rewindButton.BackgroundTransparency = 0.1
            rewindButton.Text = "REWINDING"
            
            local reversedHistory = {}
            for i = #positionHistory, 1, -1 do
                table.insert(reversedHistory, positionHistory[i])
            end
            
            local startTime = tick()
            local rewindDuration = 2
            local historyLength = #reversedHistory
            local frameInterval = 6 / historyLength
            
            local rewindConnection
            rewindConnection = RunService.Heartbeat:Connect(function()
                if not refreshReferences() or not rootPart then
                    rewindConnection:Disconnect()
                    return
                end
                
                local elapsed = tick() - startTime
                local progress = math.min(elapsed / rewindDuration, 1)
                
                local frameIndex = math.floor(progress * (historyLength - 1)) + 1
                if frameIndex > historyLength then
                    frameIndex = historyLength
                end
                
                local targetCFrame = reversedHistory[frameIndex].cframe
                rootPart.CFrame = targetCFrame
                rootPart.Velocity = Vector3.new(0, 0, 0)
                
                if progress >= 1 then
                    rewindConnection:Disconnect()
                    if rewindButton then
                        rewindButton.BackgroundTransparency = 0.5
                        rewindButton.Text = "⏪"
                    end
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

-- Moon Gravity
local function toggleMoonGravity(enabled)
    Movement.moonGravityEnabled = enabled
    updateButtonState("Moon Gravity", enabled)
    
    if enabled then
        Workspace.Gravity = Movement.defaultGravity / 6
    else
        Workspace.Gravity = Movement.defaultGravity
    end
end

-- Double Jump
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

-- Infinite Jump
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
            rootPart.Velocity = Vector3.new(rootPart.Velocity.X, getSettingValue("JumpHeight", 50) * 3, rootPart.Velocity.Z)
        end)
    end
end

-- Wall Climbing
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
            end
        end)
        
        connections.wallClimbButton = wallClimbButton.MouseButton1Click:Connect(function()
            Movement.wallClimbEnabled = not Movement.wallClimbEnabled
            updateButtonState("Wall Climb", Movement.wallClimbEnabled)
            wallClimbButton.BackgroundColor3 = Movement.wallClimbEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
            wallClimbButton.Text = Movement.wallClimbEnabled and "CLIMBING" or "CLIMB"
        end)
    else
        if wallClimbButton then
            wallClimbButton.Visible = false
            wallClimbButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            wallClimbButton.Text = "CLIMB"
        end
    end
end

-- Fly Hack with enhanced chat commands
-- Simple and reliable fly implementation
local function toggleFly(enabled)
    Movement.flyEnabled = enabled
    updateButtonState("Fly", enabled)
    
    -- Send message
    if enabled then
        sendServerMessage("FLY ACTIVATED")
        print("=== ACTIVATING FLY ===")
    else
        sendServerMessage("FLY DEACTIVATED") 
        print("=== DEACTIVATING FLY ===")
    end
    
    -- Clean up ALL fly connections first
    local flyConnections = {"fly", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", "flyDown", "flyDownEnd", "flyKeyBegan", "flyKeyEnded"}
    for _, connName in ipairs(flyConnections) do
        if connections[connName] then
            connections[connName]:Disconnect()
            connections[connName] = nil
            print("Disconnected:", connName)
        end
    end
    
    -- Destroy existing fly objects
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
        print("Destroyed flyBodyVelocity")
    end
    if flyBodyGyro then
        flyBodyGyro:Destroy() 
        flyBodyGyro = nil
        print("Destroyed flyBodyGyro")
    end
    
    if enabled then
        -- Force refresh references
        if not refreshReferences() then
            print("ERROR: Cannot refresh references!")
            Movement.flyEnabled = false
            updateButtonState("Fly", false)
            return
        end
        
        print("Player:", player.Name)
        print("Character:", player.Character and player.Character.Name or "nil")
        print("Humanoid:", humanoid and "found" or "nil")
        print("RootPart:", rootPart and "found" or "nil")
        
        if not humanoid or not rootPart then
            print("ERROR: Missing humanoid or rootPart!")
            Movement.flyEnabled = false
            updateButtonState("Fly", false)
            return
        end
        
        -- SIMPLE FLY SETUP - no delays, direct approach
        print("Setting PlatformStand...")
        humanoid.PlatformStand = true
        
        print("Creating BodyVelocity...")
        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        flyBodyVelocity.Parent = rootPart
        
        print("Creating BodyGyro...")  
        flyBodyGyro = Instance.new("BodyGyro")
        flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        flyBodyGyro.P = 10000
        flyBodyGyro.CFrame = rootPart.CFrame
        flyBodyGyro.Parent = rootPart
        
        -- Show controls
        if flyJoystickFrame then flyJoystickFrame.Visible = true end
        if flyUpButton then flyUpButton.Visible = true end  
        if flyDownButton then flyDownButton.Visible = true end
        
        print("Starting fly heartbeat...")
        
        -- SIMPLE FLY LOOP
        connections.fly = RunService.Heartbeat:Connect(function()
            if not Movement.flyEnabled then 
                print("Fly disabled, stopping loop")
                return 
            end
            
            -- Check if objects still exist
            if not flyBodyVelocity or not flyBodyVelocity.Parent then
                print("BodyVelocity missing, recreating...")
                flyBodyVelocity = Instance.new("BodyVelocity")
                flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                flyBodyVelocity.Parent = rootPart
            end
            
            if not flyBodyGyro or not flyBodyGyro.Parent then
                print("BodyGyro missing, recreating...")
                flyBodyGyro = Instance.new("BodyGyro")
                flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                flyBodyGyro.P = 10000
                flyBodyGyro.CFrame = rootPart.CFrame
                flyBodyGyro.Parent = rootPart
            end
            
            local camera = Workspace.CurrentCamera
            if not camera then return end
            
            -- Set rotation to camera
            flyBodyGyro.CFrame = camera.CFrame
            
            -- Get fly speed
            local speed = getSettingValue("FlySpeed", 50)
            local moveVector = Vector3.new(0, 0, 0)
            
            -- Keyboard controls - SIMPLE
            if flyKeys.forward then 
                moveVector = moveVector + camera.CFrame.LookVector
            end
            if flyKeys.back then
                moveVector = moveVector - camera.CFrame.LookVector  
            end
            if flyKeys.left then
                moveVector = moveVector - camera.CFrame.RightVector
            end
            if flyKeys.right then
                moveVector = moveVector + camera.CFrame.RightVector
            end
            if flyKeys.up then
                moveVector = moveVector + Vector3.new(0, 1, 0)
            end
            if flyKeys.down then
                moveVector = moveVector - Vector3.new(0, 1, 0)
            end
            
            -- Apply movement
            flyBodyVelocity.Velocity = moveVector * speed
        end)
        
        -- SIMPLE KEYBOARD INPUT
        connections.flyKeyBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            
            if input.KeyCode == Enum.KeyCode.W then
                flyKeys.forward = true
                print("W pressed")
            elseif input.KeyCode == Enum.KeyCode.S then  
                flyKeys.back = true
                print("S pressed")
            elseif input.KeyCode == Enum.KeyCode.A then
                flyKeys.left = true
                print("A pressed")
            elseif input.KeyCode == Enum.KeyCode.D then
                flyKeys.right = true  
                print("D pressed")
            elseif input.KeyCode == Enum.KeyCode.Space then
                flyKeys.up = true
                print("Space pressed")
            elseif input.KeyCode == Enum.KeyCode.LeftShift then
                flyKeys.down = true
                print("Shift pressed") 
            end
        end)
        
        connections.flyKeyEnded = UserInputService.InputEnded:Connect(function(input)
            if input.KeyCode == Enum.KeyCode.W then
                flyKeys.forward = false
            elseif input.KeyCode == Enum.KeyCode.S then
                flyKeys.back = false  
            elseif input.KeyCode == Enum.KeyCode.A then
                flyKeys.left = false
            elseif input.KeyCode == Enum.KeyCode.D then
                flyKeys.right = false
            elseif input.KeyCode == Enum.KeyCode.Space then
                flyKeys.up = false
            elseif input.KeyCode == Enum.KeyCode.LeftShift then
                flyKeys.down = false
            end
        end)
        
        print("FLY SETUP COMPLETE!")
        
    else
        -- DISABLE FLY
        print("Disabling fly...")
        
        if humanoid then
            humanoid.PlatformStand = false
            print("PlatformStand disabled")
        end
        
        -- Hide controls
        if flyJoystickFrame then flyJoystickFrame.Visible = false end
        if flyUpButton then flyUpButton.Visible = false end
        if flyDownButton then flyDownButton.Visible = false end
        
        -- Reset keys
        flyKeys = {forward = false, back = false, left = false, right = false, up = false, down = false}
        
        print("FLY DISABLED!")
    end
end

-- SIMPLE CHAT COMMANDS - Fixed
local function setupChatCommands()
    print("=== SETTING UP CHAT COMMANDS ===")
    
    -- Clean existing
    if connections.chatCommand then
        connections.chatCommand:Disconnect()
        connections.chatCommand = nil
    end
    
    -- Simple player chat connection
    if player and player.Chatted then
        connections.chatCommand = player.Chatted:Connect(function(message)
            print("CHAT MESSAGE:", message)
            
            local cmd = string.lower(string.gsub(message, "%s+", ""))
            print("PROCESSED COMMAND:", cmd)
            
            if cmd == "/fly" then
                print("CHAT: Activating fly!")
                toggleFly(true)
            elseif cmd == "/unfly" then
                print("CHAT: Deactivating fly!")  
                toggleFly(false)
            end
        end)
        print("Chat commands connected successfully!")
    else
        print("ERROR: Could not connect to player.Chatted")
    end
end

-- Test function to manually trigger fly
function Movement.testFly()
    print("=== MANUAL FLY TEST ===")
    toggleFly(not Movement.flyEnabled)
end

-- Debug function specifically for fly
function Movement.debugFly()
    print("=== FLY DEBUG ===")
    print("flyEnabled:", Movement.flyEnabled)
    print("flyBodyVelocity:", flyBodyVelocity ~= nil)
    print("flyBodyGyro:", flyBodyGyro ~= nil) 
    print("player:", player ~= nil)
    print("humanoid:", humanoid ~= nil)
    print("rootPart:", rootPart ~= nil)
    print("fly connection:", connections.fly ~= nil)
    print("chat connection:", connections.chatCommand ~= nil)
    
    if flyBodyVelocity then
        print("BodyVelocity parent:", flyBodyVelocity.Parent and flyBodyVelocity.Parent.Name or "nil")
        print("BodyVelocity velocity:", flyBodyVelocity.Velocity)
    end
    
    if flyBodyGyro then  
        print("BodyGyro parent:", flyBodyGyro.Parent and flyBodyGyro.Parent.Name or "nil")
    end
    
    print("flyKeys:", flyKeys)
end

-- NoClip
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

-- Walk on Water
local function toggleWalkOnWater(enabled)
    Movement.walkOnWaterEnabled = enabled
    updateButtonState("Walk on Water", enabled)
    
    if connections.walkOnWater then
        connections.walkOnWater:Disconnect()
        connections.walkOnWater = nil
    end
    
    if refreshReferences() and humanoid then
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, not enabled)
    end
    
    if enabled then
        connections.walkOnWater = RunService.Heartbeat:Connect(function()
            if not Movement.walkOnWaterEnabled then return end
            if not refreshReferences() or not rootPart or not player.Character then return end
            
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {player.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            
            local raycast = Workspace:Raycast(rootPart.Position, Vector3.new(0, -20, 0), raycastParams)
            if raycast and raycast.Instance and (raycast.Instance.Material == Enum.Material.Water or string.lower(raycast.Instance.Name):find("water")) then
                local waterWalkPart = rootPart:FindFirstChild("WaterWalkPart")
                if not waterWalkPart then
                    waterWalkPart = Instance.new("Part")
                    waterWalkPart.Name = "WaterWalkPart"
                    waterWalkPart.Anchored = true
                    waterWalkPart.CanCollide = true
                    waterWalkPart.Transparency = 1
                    waterWalkPart.Size = Vector3.new(15, 0.2, 15)
                    waterWalkPart.Parent = rootPart
                end
                waterWalkPart.Position = Vector3.new(rootPart.Position.X, raycast.Position.Y + 0.1, rootPart.Position.Z)
            end
        end)
    end
end

-- Player NoClip
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

-- Super Swim
local function toggleSwim(enabled)
    Movement.swimEnabled = enabled
    updateButtonState("Super Swim", enabled)
    
    if connections.swim then
        connections.swim:Disconnect()
        connections.swim = nil
    end
    
    if enabled then
        connections.swim = RunService.Heartbeat:Connect(function()
            if not Movement.swimEnabled then return end
            if not refreshReferences() or not humanoid then return end
            
            local baseSpeed = Movement.defaultWalkSpeed
            if Movement.speedEnabled then baseSpeed = getSettingValue("WalkSpeed", 50) end
            if Movement.isSprinting then baseSpeed = getSettingValue("SprintSpeed", 300) end
            
            if humanoid:GetState() == Enum.HumanoidStateType.Swimming then
                humanoid.WalkSpeed = getSettingValue("SwimSpeed", 100)
            else
                humanoid.WalkSpeed = baseSpeed
            end
        end)
    else
        if refreshReferences() and humanoid then
            humanoid.WalkSpeed = Movement.defaultWalkSpeed
        end
    end
end

-- Apply settings
function Movement.applySettings()
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

-- Load movement buttons with new settings button
function Movement.loadMovementButtons(createButton, createToggleButton)
    if not createButton or not createToggleButton then
        warn("Error: createButton or createToggleButton not provided!")
        return
    end
    
    setupScrollFrame()
    createSettingsGUI()
    
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
    
    local settingsButton = createButton("Settings", function()
        settingsFrame.Visible = not settingsFrame.Visible
    end)
    settingsButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    settingsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
end

-- Reset states
function Movement.resetStates()
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
    
    if currentStates.moonGravityEnabled then
        Movement.moonGravityEnabled = false
        updateButtonState("Moon Gravity", false)
    end
    
    isRespawning = true
    
    local allConnections = {
        "fly", "noclip", "playerNoclip", "infiniteJump", "walkOnWater", "doubleJump", 
        "wallClimb", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", 
        "flyDown", "flyDownEnd", "wallClimbInput", "float", "floatInput", 
        "floatBegan", "floatEnded", "antiFling", "rewind", "rewindInput", 
        "rewindToggle", "boost", "boostInput", "boostToggle", "slowFall", 
        "fastFall", "sprint", "sprintInput", "sprintToggle", "flyKeyBegan", 
        "flyKeyEnded", "floatKeyBegan", "floatKeyEnded", "wallClimbButton",
        "swim", "chat", "chatInput", "chatMonitor"
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
    
    Workspace.Gravity = Movement.defaultGravity
    
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            for _, part in pairs(otherPlayer.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
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
    
    Movement.jumpCount = 0
    joystickDelta = Vector2.new(0, 0)
    isTouchingJoystick = false
    joystickTouchId = nil
    positionHistory = {}
    isBoostActive = false
    isRespawning = false
end

-- Update references
function Movement.updateReferences(newHumanoid, newRootPart)
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
    createSettingsGUI()
    
    task.spawn(function()
        task.wait(0.3)
        
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
                state[2](true)
            end
        end
        
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
        
        -- Setup chat commands again after respawn
        setupChatCommands()
    end)
end

-- Enhanced chat command setup
local function setupChatCommands()
    -- Clean up existing chat connections
    if connections.chat then
        connections.chat:Disconnect()
        connections.chat = nil
    end
    if connections.chatInput then
        connections.chatInput:Disconnect()
        connections.chatInput = nil
    end
    if connections.chatMonitor then
        connections.chatMonitor:Disconnect()
        connections.chatMonitor = nil
    end
    
    -- Primary method: Direct chat connection
    if player and player.Chatted then
        connections.chat = player.Chatted:Connect(function(message)
            local lowerMessage = string.lower(message)
            if lowerMessage == "/fly" then
                print("Chat command detected: /fly")
                toggleFly(true)
            elseif lowerMessage == "/unfly" then
                print("Chat command detected: /unfly") 
                toggleFly(false)
            end
        end)
    end
    
    -- Alternative method: Monitor chat service
    local success, chatService = pcall(function()
        return game:GetService("Chat")
    end)
    
    if success and chatService then
        connections.chatMonitor = chatService.Chatted:Connect(function(part, message, color)
            if part and part.Parent == player.Character and part.Parent:FindFirstChild("Head") then
                local lowerMessage = string.lower(message)
                if lowerMessage == "/fly" then
                    print("Chat monitor detected: /fly")
                    toggleFly(true)
                elseif lowerMessage == "/unfly" then
                    print("Chat monitor detected: /unfly")
                    toggleFly(false)
                end
            end
        end)
    end
    
    -- Backup method: Text service monitoring
    local TextService = game:GetService("TextService")
    if TextService then
        local lastMessage = ""
        local lastTime = 0
        
        connections.chatInput = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if input.KeyCode == Enum.KeyCode.Return and not gameProcessed then
                task.wait(0.1) -- Small delay to catch the message
                local currentTime = tick()
                
                -- Try to detect if /fly or /unfly was typed
                task.spawn(function()
                    task.wait(0.2)
                    local gui = player.PlayerGui:FindFirstChild("Chat")
                    if gui then
                        local chatFrame = gui:FindFirstChild("Frame")
                        if chatFrame then
                            local chatChannelParentFrame = chatFrame:FindFirstChild("ChatChannelParentFrame")
                            if chatChannelParentFrame then
                                local frame = chatChannelParentFrame:FindFirstChild("Frame_MessageLogDisplay")
                                if frame then
                                    local scrollingFrame = frame:FindFirstChild("Scroller")
                                    if scrollingFrame then
                                        local lastChild = scrollingFrame:GetChildren()
                                        if #lastChild > 0 then
                                            local lastMsg = lastChild[#lastChild]
                                            if lastMsg and lastMsg:FindFirstChild("TextLabel") then
                                                local msgText = lastMsg.TextLabel.Text
                                                if string.find(string.lower(msgText), "/fly") then
                                                    toggleFly(true)
                                                elseif string.find(string.lower(msgText), "/unfly") then
                                                    toggleFly(false)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end)
    end
end

-- Initialize module
function Movement.init(deps)
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
    Movement.isSprinting = false
    
    Movement.jumpCount = 0
    joystickDelta = Vector2.new(0, 0)
    isTouchingJoystick = false
    joystickTouchId = nil
    positionHistory = {}
    isBoostActive = false
    isRespawning = false
    
    createMobileControls()
    createSettingsGUI()
    setupScrollFrame()
    setupChatCommands()
    
    return true
end

-- Debug function
function Movement.debug()
    print("=== Movement Module Debug Info ===")
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
    
    print("Settings GUI:")
    print("  settingsFrame:", settingsFrame ~= nil)
    print("  speedInput:", speedInput ~= nil)
    print("  jumpInput:", jumpInput ~= nil)
    print("  sprintInput:", sprintInput ~= nil)
    print("  flyInput:", flyInput ~= nil)
    print("  swimInput:", swimInput ~= nil)
    
    print("References:")
    print("  player:", player ~= nil)
    print("  humanoid:", humanoid ~= nil)
    print("  rootPart:", rootPart ~= nil)
    
    print("Settings Values:")
    print("  WalkSpeed:", getSettingValue("WalkSpeed", "not found"))
    print("  JumpHeight:", getSettingValue("JumpHeight", "not found"))
    print("  SprintSpeed:", getSettingValue("SprintSpeed", "not found"))
    print("  FlySpeed:", getSettingValue("FlySpeed", "not found"))
    print("  SwimSpeed:", getSettingValue("SwimSpeed", "not found"))
    
    print("Chat Commands:")
    print("  chat connection:", connections.chat ~= nil)
    print("  chatInput connection:", connections.chatInput ~= nil)
    print("  chatMonitor connection:", connections.chatMonitor ~= nil)
end

-- Cleanup function
function Movement.cleanup()
    Movement.resetStates()
    
    if flyJoystickFrame then flyJoystickFrame:Destroy() end
    if flyUpButton then flyUpButton:Destroy() end
    if flyDownButton then flyDownButton:Destroy() end
    if rewindButton then rewindButton:Destroy() end
    if boostButton then boostButton:Destroy() end
    if sprintButton then sprintButton:Destroy() end
    if wallClimbButton then wallClimbButton:Destroy() end
    if settingsFrame then settingsFrame:Destroy() end
    
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
    settingsFrame = nil
    
    positionHistory = {}
    isBoostActive = false
    isRespawning = false
end

return Movement