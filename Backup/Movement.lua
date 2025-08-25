-- Movement.lua - Enhanced version with updated Rewind, removed Instant Jump, and fixed syntax errors
-- Movement-related features for MinimalHackGUI by Fari Noveri, mobile-friendly with robust respawn handling

-- Dependencies: These must be passed from mainloader.lua
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
Movement.ladderClimbEnabled = false

-- Default values
Movement.defaultWalkSpeed = 16
Movement.defaultJumpPower = 50
Movement.defaultJumpHeight = 7.2
Movement.defaultGravity = 196.2
Movement.jumpCount = 0
Movement.maxJumps = 2

-- Fly controls
local flySpeed = 50
local flyBodyVelocity = nil
local flyJoystickFrame, flyJoystickKnob
local flyUpButton, flyDownButton
local boostButton
local rewindButton
local joystickDelta = Vector2.new(0, 0)
local isTouchingJoystick = false
local joystickTouchId = nil

-- New features variables
local positionHistory = {}
local maxHistorySize = 180 -- 6 seconds at 30 fps
local isBoostActive = false
local boostEndTime = 0

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

-- Create virtual controls with better positioning and white style
local function createMobileControls()
    print("Creating mobile controls")
    
    if flyJoystickFrame then flyJoystickFrame:Destroy() end
    if flyUpButton then flyUpButton:Destroy() end
    if flyDownButton then flyDownButton:Destroy() end
    if boostButton then boostButton:Destroy() end
    if rewindButton then rewindButton:Destroy() end

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
            
            flyJoystickKnob.Position = UDim2.new(0.5, delta.X - 20, 0.5, 0 - 20)
            joystickDelta = Vector2.new(delta.X / maxRadius, 0)
            
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

-- Speed Hack with settings integration
local function toggleSpeed(enabled)
    Movement.speedEnabled = enabled
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

-- Jump Hack with settings integration
local function toggleJump(enabled)
    Movement.jumpEnabled = enabled
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

-- Ladder Climb (automatic faster upward movement on ladders)
local function toggleLadderClimb(enabled)
    Movement.ladderClimbEnabled = enabled
    print("Ladder Climb:", enabled)
    
    if connections.ladderClimb then
        connections.ladderClimb:Disconnect()
        connections.ladderClimb = nil
    end
    
    if enabled then
        connections.ladderClimb = RunService.Heartbeat:Connect(function()
            if not Movement.ladderClimbEnabled then return end
            if not refreshReferences() or not rootPart or not humanoid then return end
            
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {player.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            
            local directions = {
                rootPart.CFrame.LookVector,
                -rootPart.CFrame.LookVector,
                rootPart.CFrame.RightVector,
                -rootPart.CFrame.RightVector
            }
            
            local nearLadder = false
            for _, direction in ipairs(directions) do
                local raycast = Workspace:Raycast(rootPart.Position, direction * 2, raycastParams)
                if raycast and raycast.Instance and raycast.Instance.Name:lower():find("ladder") then
                    nearLadder = true
                    break
                end
            end
            
            if nearLadder then
                rootPart.Velocity = Vector3.new(rootPart.Velocity.X, 50, rootPart.Velocity.Z)
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end

-- Fixed Float Hack (horizontal movement only)
local function toggleFloat(enabled)
    Movement.floatEnabled = enabled
    print("Float toggle:", enabled)
    
    local floatConnections = {"float", "floatInput", "floatBegan", "floatEnded"}
    for _, connName in ipairs(floatConnections) do
        if connections[connName] then
            connections[connName]:Disconnect()
            connections[connName] = nil
        end
    end
    
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
                    
                    floatDirection = right * joystickDelta.X
                end
                
                if floatDirection.Magnitude > 0 then
                    flyBodyVelocity.Velocity = Vector3.new(floatDirection.X * flySpeed, 0, floatDirection.Z * flySpeed)
                else
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                end
            end)
            
            connections.floatInput = UserInputService.InputChanged:Connect(handleFloatJoystick)
            connections.floatBegan = UserInputService.InputBegan:Connect(handleFloatJoystick)
            connections.floatEnded = UserInputService.InputEnded:Connect(handleFloatJoystick)
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

-- Boost (NOS-like effect)
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
            if not isBoostActive and refreshReferences() and humanoid and rootPart then
                isBoostActive = true
                boostEndTime = tick() + 2
                
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
                end
            end
        end)
        
        connections.boostToggle = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or not Movement.boostEnabled then return end
            if input.KeyCode == Enum.KeyCode.B then
                if not isBoostActive and refreshReferences() and humanoid and rootPart then
                    isBoostActive = true
                    boostEndTime = tick() + 2
                    
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
                    end
                end
            end
        end)
        
        connections.boost = RunService.Heartbeat:Connect(function()
            if not Movement.boostEnabled then return end
            
            if isBoostActive and tick() >= boostEndTime then
                isBoostActive = false
                if boostButton then
                    boostButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    boostButton.BackgroundTransparency = 0.5
                    boostButton.Text = "BOOST"
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

-- Improved Rewind Movement (follows exact path with rotations)
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

-- Moon Gravity
local function toggleMoonGravity(enabled)
    Movement.moonGravityEnabled = enabled
    if enabled then
        Workspace.Gravity = Movement.defaultGravity / 6
    else
        Workspace.Gravity = Movement.defaultGravity
    end
end

-- Double Jump with improved respawn handling
local function toggleDoubleJump(enabled)
    Movement.doubleJumpEnabled = enabled
    
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

-- Infinite Jump with improved respawn handling
local function toggleInfiniteJump(enabled)
    Movement.infiniteJumpEnabled = enabled
    
    if connections.infiniteJump then
        connections.infiniteJump:Disconnect()
        connections.infiniteJump = nil
    end
    
    if enabled then
        connections.infiniteJump = UserInputService.JumpRequest:Connect(function()
            if not Movement.infiniteJumpEnabled then return end
            if not refreshReferences() or not humanoid then return end
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end

-- Wall Climbing with improved respawn handling
local function toggleWallClimb(enabled)
    Movement.wallClimbEnabled = enabled
    
    if connections.wallClimb then
        connections.wallClimb:Disconnect()
        connections.wallClimb = nil
    end
    if connections.wallClimbInput then
        connections.wallClimbInput:Disconnect()
        connections.wallClimbInput = nil
    end
    
    if enabled then
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
                print("Wall Climb:", Movement.wallClimbEnabled)
            end
        end)
    end
end

-- Fly Hack with settings integration
local function toggleFly(enabled)
    Movement.flyEnabled = enabled
    print("Fly toggle:", enabled)
    
    local flyConnections = {"fly", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", "flyDown", "flyDownEnd"}
    for _, connName in ipairs(flyConnections) do
        if connections[connName] then
            connections[connName]:Disconnect()
            connections[connName] = nil
        end
    end
    
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    
    if enabled then
        task.spawn(function()
            task.wait(0.1)
            if not refreshReferences() or not rootPart or not humanoid then
                print("Failed to get rootPart for fly")
                Movement.flyEnabled = false
                return
            end
            
            humanoid.PlatformStand = true
            flyBodyVelocity = Instance.new("BodyVelocity")
            flyBodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
            flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            flyBodyVelocity.Parent = rootPart
            
            if flyJoystickFrame then flyJoystickFrame.Visible = true end
            if flyUpButton then flyUpButton.Visible = true end
            if flyDownButton then flyDownButton.Visible = true end
            
            connections.fly = RunService.Heartbeat:Connect(function()
                if not Movement.flyEnabled then return end
                if not refreshReferences() or not rootPart then return end
                
                if not flyBodyVelocity or flyBodyVelocity.Parent != rootPart then
                    if flyBodyVelocity then flyBodyVelocity:Destroy() end
                    flyBodyVelocity = Instance.new("BodyVelocity")
                    flyBodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                    flyBodyVelocity.Parent = rootPart
                end
                
                local camera = Workspace.CurrentCamera
                if not camera then return end
                
                local flyDirection = Vector3.new(0, 0, 0)
                local floatVerticalInput = 0
                flySpeed = getSettingValue("FlySpeed", 50)
                
                if joystickDelta.Magnitude > 0.05 then
                    local forward = camera.CFrame.LookVector
                    local right = camera.CFrame.RightVector
                    
                    forward = Vector3.new(forward.X, 0, forward.Z).Unit
                    right = Vector3.new(right.X, 0, right.Z).Unit
                    
                    flyDirection = flyDirection + (right * joystickDelta.X) + (forward * -joystickDelta.Y)
                end
                
                if flyUpButton and flyUpButton.BackgroundTransparency == 0.1 then
                    floatVerticalInput = 1
                elseif flyDownButton and flyDownButton.BackgroundTransparency == 0.1 then
                    floatVerticalInput = -1
                end
                
                if floatVerticalInput != 0 then
                    flyDirection = flyDirection + Vector3.new(0, floatVerticalInput, 0)
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

-- NoClip with better respawn handling
local function toggleNoclip(enabled)
    Movement.noclipEnabled = enabled
    
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
                if part:IsA("BasePart") and part.Name != "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- Walk on Water with better respawn handling
local function toggleWalkOnWater(enabled)
    Movement.walkOnWaterEnabled = enabled
    
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
            
            local raycast = Workspace:Raycast(rootPart.Position, Vector3.new(0, -10, 0), raycastParams)
            if raycast and raycast.Instance and (raycast.Instance.Material == Enum.Material.Water or raycast.Instance.Name:lower():find("water")) then
                if not rootPart:FindFirstChild("WaterWalkPart") then
                    local waterWalkPart = Instance.new("Part")
                    waterWalkPart.Name = "WaterWalkPart"
                    waterWalkPart.Anchored = true
                    waterWalkPart.CanCollide = true
                    waterWalkPart.Transparency = 1
                    waterWalkPart.Size = Vector3.new(10, 0.2, 10)
                    waterWalkPart.Position = Vector3.new(rootPart.Position.X, raycast.Position.Y + 0.1, rootPart.Position.Z)
                    waterWalkPart.Parent = Workspace
                    game:GetService("Debris"):AddItem(waterWalkPart, 0.5)
                end
            end
        end)
    end
end

-- Enhanced Player NoClip with Anti-Fling Protection
local function togglePlayerNoclip(enabled)
    Movement.playerNoclipEnabled = enabled
    
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
                if otherPlayer != player and otherPlayer.Character then
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
                if otherPlayer != player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
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
            if otherPlayer != player and otherPlayer.Character then
                for _, part in pairs(otherPlayer.Character:GetChildren()) do
                    if part:IsA("BasePart") and part.Name != "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end
    end
end

-- Super Swim with better reference handling
local function toggleSwim(enabled)
    Movement.swimEnabled = enabled
    
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
                    humanoid.WalkSpeed = Movement.defaultWalkSpeed
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
    createToggleButton("Ladder Climb", toggleLadderClimb)
end

-- Enhanced reset function
function Movement.resetStates()
    print("Resetting Movement states")
    
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
    Movement.ladderClimbEnabled = false
    
    Movement.jumpCount = 0
    joystickDelta = Vector2.new(0, 0)
    isTouchingJoystick = false
    joystickTouchId = nil
    
    positionHistory = {}
    isBoostActive = false
    boostEndTime = 0
    
    local allConnections = {
        "fly", "noclip", "playerNoclip", "infiniteJump", "walkOnWater", "doubleJump", 
        "wallClimb", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", 
        "flyDown", "flyDownEnd", "wallClimbInput", "float", "floatInput", 
        "floatBegan", "floatEnded", "antiFling", "rewind", "rewindInput", 
        "rewindToggle", "boost", "boostInput", "boostToggle", "slowFall", 
        "fastFall", "ladderClimb"
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
                if part:IsA("BasePart") and part.Name != "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
    
    Workspace.Gravity = Movement.defaultGravity
    
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer != player and otherPlayer.Character then
            for _, part in pairs(otherPlayer.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name != "HumanoidRootPart" then
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
end

-- Enhanced reference update function
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
    
    task.spawn(function()
        task.wait(0.2)
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
            {Movement.ladderClimbEnabled, toggleLadderClimb, "Ladder Climb"}
        }
        
        for _, state in ipairs(statesToReapply) do
            if state[1] then
                print("Reapplying", state[3])
                state[2](true)
            end
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
    Movement.ladderClimbEnabled = false
    
    Movement.jumpCount = 0
    joystickDelta = Vector2.new(0, 0)
    isTouchingJoystick = false
    joystickTouchId = nil
    
    positionHistory = {}
    isBoostActive = false
    boostEndTime = 0
    
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
    print("  ladderClimbEnabled:", Movement.ladderClimbEnabled)
    
    print("New Feature Data:")
    print("  positionHistory entries:", #positionHistory)
    print("  isBoostActive:", isBoostActive)
    print("  boostEndTime:", boostEndTime)
    
    print("References:")
    print("  player:", player != nil)
    print("  humanoid:", humanoid != nil)
    print("  rootPart:", rootPart != nil)
    print("  player.Character:", player and player.Character != nil)
    
    print("Settings Integration:")
    if settings then
        print("  WalkSpeed setting:", getSettingValue("WalkSpeed", "not found"))
        print("  JumpHeight setting:", getSettingValue("JumpHeight", "not found"))
        print("  FlySpeed setting:", getSettingValue("FlySpeed", "not found"))
    else
        print("  settings: nil")
    end
    
    print("UI Elements:")
    print("  flyJoystickFrame:", flyJoystickFrame != nil)
    print("  flyUpButton:", flyUpButton != nil)
    print("  flyDownButton:", flyDownButton != nil)
    print("  rewindButton:", rewindButton != nil)
    print("  boostButton:", boostButton != nil)
    
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
    
    flyJoystickFrame = nil
    flyJoystickKnob = nil
    flyUpButton = nil
    flyDownButton = nil
    flyBodyVelocity = nil
    rewindButton = nil
    boostButton = nil
    
    positionHistory = {}
    isBoostActive = false
    boostEndTime = 0
    
    print("Movement module cleaned up")
end

return Movement