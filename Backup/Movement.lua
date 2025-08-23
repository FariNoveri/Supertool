-- Movement.lua - Enhanced version with bug fixes
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
Movement.undergroundEnabled = false
Movement.ghostEnabled = false
Movement.fakeLagEnabled = false
Movement.rewindEnabled = false
Movement.mirrorCloneEnabled = false
Movement.reverseWalkEnabled = false
Movement.fastLadderEnabled = false
Movement.stickyPlatformEnabled = false

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
local wallClimbButton
local flyUpButton, flyDownButton
local joystickDelta = Vector2.new(0, 0)
local isTouchingJoystick = false
local joystickTouchId = nil

-- New features variables
local positionHistory = {}
local maxHistorySize = 300 -- 10 seconds at 30 fps
local mirrorClone = nil
local originalPosition = nil -- Changed from originalCFrame
local fakeLagPositions = {}
local lastNetworkUpdate = 0
local ghostStartPosition = nil

-- Scroll frame for UI
local function setupScrollFrame()
    if ScrollFrame then
        ScrollFrame.ScrollingEnabled = true
        ScrollFrame.ScrollBarThickness = 8
        ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 600) -- Increased for new features
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

-- Create virtual controls with better positioning and WHITE STYLING
local function createMobileControls()
    print("Creating mobile controls")
    
    if flyJoystickFrame then flyJoystickFrame:Destroy() end
    if wallClimbButton then wallClimbButton:Destroy() end
    if flyUpButton then flyUpButton:Destroy() end
    if flyDownButton then flyDownButton:Destroy() end

    -- FLY UP BUTTON
    flyUpButton = Instance.new("TextButton")
    flyUpButton.Name = "FlyUpButton"
    flyUpButton.Size = UDim2.new(0, 60, 0, 60)
    flyUpButton.Position = UDim2.new(1, -80, 1, -260)
    flyUpButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- WHITE
    flyUpButton.BackgroundTransparency = 0.1
    flyUpButton.BorderSizePixel = 0
    flyUpButton.Text = "▲"
    flyUpButton.Font = Enum.Font.GothamBold
    flyUpButton.TextColor3 = Color3.fromRGB(0, 0, 0) -- BLACK TEXT
    flyUpButton.TextSize = 20
    flyUpButton.Visible = false
    flyUpButton.ZIndex = 10
    flyUpButton.Parent = ScreenGui or player.PlayerGui

    local upCorner = Instance.new("UICorner")
    upCorner.CornerRadius = UDim.new(0.2, 0)
    upCorner.Parent = flyUpButton

    -- FLY DOWN BUTTON
    flyDownButton = Instance.new("TextButton")
    flyDownButton.Name = "FlyDownButton"
    flyDownButton.Size = UDim2.new(0, 60, 0, 60)
    flyDownButton.Position = UDim2.new(1, -80, 1, -60)
    flyDownButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- WHITE
    flyDownButton.BackgroundTransparency = 0.1
    flyDownButton.BorderSizePixel = 0
    flyDownButton.Text = "▼"
    flyDownButton.Font = Enum.Font.GothamBold
    flyDownButton.TextColor3 = Color3.fromRGB(0, 0, 0) -- BLACK TEXT
    flyDownButton.TextSize = 20
    flyDownButton.Visible = false
    flyDownButton.ZIndex = 10
    flyDownButton.Parent = ScreenGui or player.PlayerGui

    local downCorner = Instance.new("UICorner")
    downCorner.CornerRadius = UDim.new(0.2, 0)
    downCorner.Parent = flyDownButton

    -- JOYSTICK
    flyJoystickFrame = Instance.new("Frame")
    flyJoystickFrame.Name = "FlyJoystick"
    flyJoystickFrame.Size = UDim2.new(0, 100, 0, 100)
    flyJoystickFrame.Position = UDim2.new(0, 20, 1, -130)
    flyJoystickFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- WHITE
    flyJoystickFrame.BackgroundTransparency = 0.1
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
    flyJoystickKnob.BackgroundColor3 = Color3.fromRGB(200, 200, 200) -- LIGHT GRAY
    flyJoystickKnob.BackgroundTransparency = 0.1
    flyJoystickKnob.BorderSizePixel = 0
    flyJoystickKnob.ZIndex = 11
    flyJoystickKnob.Parent = flyJoystickFrame

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0.5, 0)
    knobCorner.Parent = flyJoystickKnob

    -- WALL CLIMB BUTTON
    wallClimbButton = Instance.new("TextButton")
    wallClimbButton.Name = "WallClimbButton"
    wallClimbButton.Size = UDim2.new(0, 60, 0, 60)
    wallClimbButton.Position = UDim2.new(1, -80, 1, -130)
    wallClimbButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- WHITE
    wallClimbButton.BackgroundTransparency = 0.1
    wallClimbButton.BorderSizePixel = 0
    wallClimbButton.Text = "Climb"
    wallClimbButton.Font = Enum.Font.GothamBold
    wallClimbButton.TextColor3 = Color3.fromRGB(0, 0, 0) -- BLACK TEXT
    wallClimbButton.TextSize = 12
    wallClimbButton.Visible = false
    wallClimbButton.ZIndex = 10
    wallClimbButton.Parent = ScreenGui or player.PlayerGui

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0.2, 0)
    buttonCorner.Parent = wallClimbButton
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
            
            flyJoystickKnob.Position = UDim2.new(0.5, delta.X - 20, 0.5, 0 - 20) -- Only horizontal movement
            joystickDelta = Vector2.new(delta.X / maxRadius, 0) -- Only X axis
            
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
            flyBodyVelocity.MaxForce = Vector3.new(4000, 0, 4000) -- No Y force for floating
            flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            flyBodyVelocity.Parent = rootPart
            
            if flyJoystickFrame then flyJoystickFrame.Visible = true end
            
            connections.float = RunService.Heartbeat:Connect(function()
                if not Movement.floatEnabled then return end
                if not refreshReferences() or not rootPart or not humanoid then return end
                
                if not flyBodyVelocity or flyBodyVelocity.Parent ~= rootPart then
                    if flyBodyVelocity then flyBodyVelocity:Destroy() end
                    flyBodyVelocity = Instance.new("BodyVelocity")
                    flyBodyVelocity.MaxForce = Vector3.new(4000, 0, 4000) -- No Y force
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
                    
                    -- Only horizontal movement
                    forward = Vector3.new(forward.X, 0, forward.Z).Unit
                    right = Vector3.new(right.X, 0, right.Z).Unit
                    
                    floatDirection = right * joystickDelta.X -- Only horizontal
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

-- FIXED Underground walking - langsung ke bawah
local function toggleUnderground(enabled)
    Movement.undergroundEnabled = enabled
    
    if connections.underground then
        connections.underground:Disconnect()
        connections.underground = nil
    end
    
    if enabled then
        task.spawn(function()
            if not refreshReferences() or not rootPart or not player.Character then return end
            
            -- Enable noclip for underground movement
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
            
            -- LANGSUNG TURUN 20 STUD KE BAWAH
            rootPart.CFrame = rootPart.CFrame - Vector3.new(0, 20, 0)
        end)
        
        connections.underground = RunService.Heartbeat:Connect(function()
            if not Movement.undergroundEnabled then return end
            if not refreshReferences() or not rootPart or not player.Character then return end
            
            -- Keep parts non-collidable
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    else
        -- Teleport back to surface
        if refreshReferences() and rootPart and player.Character then
            -- Restore collision
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
            
            -- LANGSUNG NAIK 25 STUD KE ATAS
            rootPart.CFrame = rootPart.CFrame + Vector3.new(0, 25, 0)
        end
    end
end

-- FIXED Ghost Mode - Stay at start position for others
local function toggleGhost(enabled)
    Movement.ghostEnabled = enabled
    
    if connections.ghost then
        connections.ghost:Disconnect()
        connections.ghost = nil
    end
    
    if enabled then
        -- Store starting position when ghost is enabled
        if refreshReferences() and rootPart then
            ghostStartPosition = rootPart.Position
        end
        
        connections.ghost = RunService.Heartbeat:Connect(function()
            if not Movement.ghostEnabled then return end
            if not refreshReferences() or not rootPart then return end
            
            -- Make character non-collidable
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
            
            -- Occasionally "teleport" back to start position for network sync (others see player at start)
            if math.random() > 0.85 then -- More frequent updates
                local currentPos = rootPart.Position
                rootPart.CFrame = CFrame.new(ghostStartPosition) -- Go back to start for others
                task.wait(0.03)
                rootPart.CFrame = CFrame.new(currentPos) -- Return to real position
            end
        end)
    else
        -- Restore normal state
        if refreshReferences() and player.Character then
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
        ghostStartPosition = nil
    end
end

-- FIXED Fake Lag - Smooth walking for self, stuttering for others
local function toggleFakeLag(enabled)
    Movement.fakeLagEnabled = enabled
    
    if connections.fakeLag then
        connections.fakeLag:Disconnect()
        connections.fakeLag = nil
    end
    
    fakeLagPositions = {}
    lastNetworkUpdate = 0
    
    if enabled then
        connections.fakeLag = RunService.Heartbeat:Connect(function()
            if not Movement.fakeLagEnabled then return end
            if not refreshReferences() or not rootPart then return end
            
            local currentTime = tick()
            
            -- Store positions for lag simulation
            table.insert(fakeLagPositions, {
                position = rootPart.Position,
                time = currentTime
            })
            
            -- Remove old positions (keep 1.5 seconds worth)
            while #fakeLagPositions > 0 and currentTime - fakeLagPositions[1].time > 1.5 do
                table.remove(fakeLagPositions, 1)
            end
            
            -- Create stuttering effect for others by rapidly jumping between positions
            if currentTime - lastNetworkUpdate > 0.1 + math.random() * 0.2 then -- More frequent stutters
                if #fakeLagPositions > 10 then
                    -- Jump to an old position briefly
                    local oldPos = fakeLagPositions[math.max(1, #fakeLagPositions - math.random(5, 15))].position
                    rootPart.CFrame = CFrame.new(oldPos)
                    task.wait(0.05) -- Brief stutter
                    -- Jump back to current
                    rootPart.CFrame = CFrame.new(fakeLagPositions[#fakeLagPositions].position)
                end
                lastNetworkUpdate = currentTime
            end
        end)
    end
end

-- FIXED Rewind Movement - SMOOTH REWIND
local rewindButton

local function createRewindButton()
    if rewindButton then rewindButton:Destroy() end
    
    rewindButton = Instance.new("TextButton")
    rewindButton.Name = "RewindButton"
    rewindButton.Size = UDim2.new(0, 60, 0, 60)
    rewindButton.Position = UDim2.new(1, -80, 1, -200)
    rewindButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- WHITE
    rewindButton.BackgroundTransparency = 0.1
    rewindButton.BorderSizePixel = 0
    rewindButton.Text = "⏪"
    rewindButton.Font = Enum.Font.GothamBold
    rewindButton.TextColor3 = Color3.fromRGB(0, 0, 0) -- BLACK TEXT
    rewindButton.TextSize = 20
    rewindButton.Visible = false
    rewindButton.ZIndex = 10
    rewindButton.Parent = ScreenGui or player.PlayerGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.3, 0)
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
    
    if enabled then
        createRewindButton()
        if rewindButton then
            rewindButton.Visible = true
        end
        
        -- Store position history
        connections.rewind = RunService.Heartbeat:Connect(function()
            if not Movement.rewindEnabled then return end
            if not refreshReferences() or not rootPart then return end
            
            table.insert(positionHistory, {
                cframe = rootPart.CFrame,
                time = tick()
            })
            
            -- Keep only recent history
            while #positionHistory > maxHistorySize do
                table.remove(positionHistory, 1)
            end
        end)
        
        -- SMOOTH REWIND on button tap
        if rewindButton then
            connections.rewindInput = rewindButton.MouseButton1Click:Connect(function()
                if #positionHistory > 60 then
                    -- SMOOTH REWIND ANIMATION
                    rewindButton.BackgroundTransparency = 0.05
                    
                    local targetIndex = math.max(1, #positionHistory - 90) -- 3 seconds back
                    local currentIndex = #positionHistory
                    local smoothSteps = 30 -- Number of smooth steps
                    
                    task.spawn(function()
                        for i = 1, smoothSteps do
                            local progress = i / smoothSteps
                            local lerpIndex = math.floor(currentIndex - (currentIndex - targetIndex) * progress)
                            lerpIndex = math.max(1, math.min(lerpIndex, #positionHistory))
                            
                            if positionHistory[lerpIndex] then
                                rootPart.CFrame = positionHistory[lerpIndex].cframe
                                task.wait(0.02) -- Smooth animation
                            end
                        end
                        
                        rewindButton.BackgroundTransparency = 0.1
                    end)
                end
            end)
        end
    else
        if rewindButton then
            rewindButton.Visible = false
        end
        positionHistory = {}
    end
end

-- FIXED Mirror Clone - Error handling
local function toggleMirrorClone(enabled)
    Movement.mirrorCloneEnabled = enabled
    
    if mirrorClone then
        mirrorClone:Destroy()
        mirrorClone = nil
    end
    
    if enabled then
        if refreshReferences() and rootPart and player.Character and player then -- ADDED PLAYER CHECK
            -- Create clone at current position
            mirrorClone = player.Character:Clone()
            mirrorClone.Name = player.Name .. "_Clone" -- NOW SAFE TO USE player.Name
            mirrorClone.Parent = Workspace
            
            -- Make clone static
            for _, part in pairs(mirrorClone:GetChildren()) do
                if part:IsA("BasePart") then
                    part.Anchored = true
                    part.CanCollide = false
                end
            end
            
            -- Remove scripts from clone
            for _, obj in pairs(mirrorClone:GetDescendants()) do
                if obj:IsA("Script") or obj:IsA("LocalScript") then
                    obj:Destroy()
                end
            end
        end
    end
end

-- FIXED Reverse Walk - No flicker for self
local function toggleReverseWalk(enabled)
    Movement.reverseWalkEnabled = enabled
    
    if connections.reverseWalk then
        connections.reverseWalk:Disconnect()
        connections.reverseWalk = nil
    end
    
    if enabled then
        connections.reverseWalk = RunService.Heartbeat:Connect(function()
            if not Movement.reverseWalkEnabled then return end
            if not refreshReferences() or not rootPart then return end
            
            -- Only send reversed rotation to network occasionally (for other players to see)
            if math.random() > 0.9 then -- Less frequent to reduce flicker
                local currentCFrame = rootPart.CFrame
                -- Brief network update with reversed rotation
                rootPart.CFrame = currentCFrame * CFrame.Angles(0, math.pi, 0)
                RunService.Heartbeat:Wait() -- Wait one frame
                rootPart.CFrame = currentCFrame -- Restore immediately for self
            end
        end)
    end
end

-- FIXED Fast Ladder - Better detection
local function toggleFastLadder(enabled)
    Movement.fastLadderEnabled = enabled
    
    if connections.fastLadder then
        connections.fastLadder:Disconnect()
        connections.fastLadder = nil
    end
    
    if enabled then
        connections.fastLadder = RunService.Heartbeat:Connect(function()
            if not Movement.fastLadderEnabled then return end
            if not refreshReferences() or not rootPart or not humanoid then return end
            
            -- Only activate when player is trying to move up
            if humanoid.MoveDirection.Magnitude > 0 then
                -- Detect if near ladder (TrussPart or parts with "Ladder" in name)
                local raycastParams = RaycastParams.new()
                raycastParams.FilterDescendantsInstances = {player.Character}
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                
                local directions = {
                    rootPart.CFrame.RightVector,
                    -rootPart.CFrame.RightVector,
                    rootPart.CFrame.LookVector,
                    -rootPart.CFrame.LookVector
                }
                
                local isNearLadder = false
                for _, direction in ipairs(directions) do
                    local raycast = Workspace:Raycast(rootPart.Position, direction * 3, raycastParams)
                    if raycast and raycast.Instance then
                        local part = raycast.Instance
                        -- Better ladder detection
                        if part:IsA("TrussPart") or 
                           part.Name:lower():find("ladder") or 
                           part.Name:lower():find("climb") or
                           part.Name:lower():find("stair") then
                            isNearLadder = true
                            break
                        end
                    end
                end
                
                if isNearLadder then
                    -- Apply upward velocity for fast climbing
                    rootPart.Velocity = Vector3.new(rootPart.Velocity.X, 35, rootPart.Velocity.Z)
                end
            end
        end)
    end
end

-- FIXED Sticky Platform - Only stick when standing still
local function toggleStickyPlatform(enabled)
    Movement.stickyPlatformEnabled = enabled
    
    if connections.stickyPlatform then
        connections.stickyPlatform:Disconnect()
        connections.stickyPlatform = nil
    end
    
    if enabled then
        connections.stickyPlatform = RunService.Heartbeat:Connect(function()
            if not Movement.stickyPlatformEnabled then return end
            if not refreshReferences() or not rootPart or not humanoid then return end
            
            -- Only stick when player is NOT moving (standing still)
            if humanoid.MoveDirection.Magnitude < 0.1 then
                -- Detect moving platforms
                local raycastParams = RaycastParams.new()
                raycastParams.FilterDescendantsInstances = {player.Character}
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                
                local raycast = Workspace:Raycast(rootPart.Position, Vector3.new(0, -6, 0), raycastParams)
                if raycast and raycast.Instance then
                    local platform = raycast.Instance
                    
                    -- Check if platform is moving
                    if platform.AssemblyLinearVelocity.Magnitude > 2 then
                        -- Create temporary weld to stick to platform
                        local existingWeld = rootPart:FindFirstChild("PlatformWeld")
                        if not existingWeld then
                            local weld = Instance.new("WeldConstraint")
                            weld.Name = "PlatformWeld"
                            weld.Part0 = rootPart
                            weld.Part1 = platform
                            weld.Parent = rootPart
                            
                            -- Remove weld after short time or when player moves
                            game:GetService("Debris"):AddItem(weld, 1.0)
                        end
                    end
                end
            else
                -- Remove weld when player starts moving
                local existingWeld = rootPart:FindFirstChild("PlatformWeld")
                if existingWeld then
                    existingWeld:Destroy()
                end
            end
        end)
    else
        -- Clean up any existing welds
        if refreshReferences() and rootPart then
            local existingWeld = rootPart:FindFirstChild("PlatformWeld")
            if existingWeld then
                existingWeld:Destroy()
            end
        end
    end
end

-- Continue with existing functions (Moon Gravity, Double Jump, etc.)
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
    
    if enabled and wallClimbButton then
        wallClimbButton.Visible = true
        
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
            
            if isNearWall and wallClimbButton.Text == "Climbing" then
                rootPart.Velocity = Vector3.new(rootPart.Velocity.X, 30, rootPart.Velocity.Z)
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
        
        connections.wallClimbInput = wallClimbButton.MouseButton1Click:Connect(function()
            wallClimbButton.Text = wallClimbButton.Text == "Climb" and "Climbing" or "Climb"
        end)
    else
        if wallClimbButton then
            wallClimbButton.Visible = false
            wallClimbButton.Text = "Climb"
        end
    end
end

-- FIXED Fly Hack - Proper UP/DOWN movement
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
                
                if not flyBodyVelocity or flyBodyVelocity.Parent ~= rootPart then
                    if flyBodyVelocity then flyBodyVelocity:Destroy() end
                    flyBodyVelocity = Instance.new("BodyVelocity")
                    flyBodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                    flyBodyVelocity.Parent = rootPart
                end
                
                local camera = Workspace.CurrentCamera
                if not camera then return end
                
                local flyDirection = Vector3.new(0, 0, 0)
                local verticalInput = 0
                flySpeed = getSettingValue("FlySpeed", 50)
                
                -- Horizontal movement from joystick
                if joystickDelta.Magnitude > 0.05 then
                    local forward = camera.CFrame.LookVector
                    local right = camera.CFrame.RightVector
                    
                    forward = Vector3.new(forward.X, 0, forward.Z).Unit
                    right = Vector3.new(right.X, 0, right.Z).Unit
                    
                    flyDirection = flyDirection + (right * joystickDelta.X) + (forward * -joystickDelta.Y)
                end
                
                -- FIXED: Check fly up/down buttons properly
                if flyUpButton and flyUpButton.BackgroundTransparency < 0.2 then
                    verticalInput = 1
                elseif flyDownButton and flyDownButton.BackgroundTransparency < 0.2 then
                    verticalInput = -1
                end
                
                -- Add vertical movement
                flyDirection = flyDirection + Vector3.new(0, verticalInput, 0)
                
                if flyDirection.Magnitude > 0 then
                    flyBodyVelocity.Velocity = flyDirection.Unit * flySpeed
                else
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                end
            end)
            
            connections.flyInput = UserInputService.InputChanged:Connect(handleFlyJoystick)
            connections.flyBegan = UserInputService.InputBegan:Connect(handleFlyJoystick)
            connections.flyEnded = UserInputService.InputEnded:Connect(handleFlyJoystick)
            
            -- FIXED: Proper button handling
            if flyUpButton then
                connections.flyUp = flyUpButton.MouseButton1Down:Connect(function()
                    flyUpButton.BackgroundTransparency = 0.05
                end)
                connections.flyUpEnd = flyUpButton.MouseButton1Up:Connect(function()
                    flyUpButton.BackgroundTransparency = 0.1
                end)
            end
            
            if flyDownButton then
                connections.flyDown = flyDownButton.MouseButton1Down:Connect(function()
                    flyDownButton.BackgroundTransparency = 0.05
                end)
                connections.flyDownEnd = flyDownButton.MouseButton1Up:Connect(function()
                    flyDownButton.BackgroundTransparency = 0.1
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
            flyUpButton.BackgroundTransparency = 0.1
        end
        if flyDownButton then 
            flyDownButton.Visible = false
            flyDownButton.BackgroundTransparency = 0.1
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
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- FIXED Walk on Water - Better water detection
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
            
            -- Check multiple points around the player for water
            local waterDetected = false
            local checkPositions = {
                rootPart.Position,
                rootPart.Position + Vector3.new(2, 0, 0),
                rootPart.Position + Vector3.new(-2, 0, 0),
                rootPart.Position + Vector3.new(0, 0, 2),
                rootPart.Position + Vector3.new(0, 0, -2)
            }
            
            for _, pos in ipairs(checkPositions) do
                local raycast = Workspace:Raycast(pos, Vector3.new(0, -8, 0), raycastParams)
                if raycast and raycast.Instance then
                    local part = raycast.Instance
                    if part.Material == Enum.Material.Water or 
                       part.Name:lower():find("water") or
                       part.Name:lower():find("ocean") or
                       part.Name:lower():find("sea") or
                       part.BrickColor == BrickColor.new("Bright blue") then
                        waterDetected = true
                        
                        -- Create invisible platform above water
                        if not rootPart:FindFirstChild("WaterWalkPart") then
                            local waterWalkPart = Instance.new("Part")
                            waterWalkPart.Name = "WaterWalkPart"
                            waterWalkPart.Anchored = true
                            waterWalkPart.CanCollide = true
                            waterWalkPart.Transparency = 1
                            waterWalkPart.Size = Vector3.new(8, 0.2, 8)
                            waterWalkPart.Position = Vector3.new(rootPart.Position.X, raycast.Position.Y + 0.5, rootPart.Position.Z)
                            waterWalkPart.Parent = Workspace
                            game:GetService("Debris"):AddItem(waterWalkPart, 1.0)
                        end
                        break
                    end
                end
            end
            
            -- Also check if player is in Terrain water
            local region = Region3.new(
                rootPart.Position - Vector3.new(4, 4, 4),
                rootPart.Position + Vector3.new(4, 4, 4)
            )
            local materials, occupancies = Workspace.Terrain:ReadVoxels(region, 16)
            
            for x = 1, materials.Size.X do
                for y = 1, materials.Size.Y do
                    for z = 1, materials.Size.Z do
                        if materials[x][y][z] == Enum.Material.Water and occupancies[x][y][z] > 0 then
                            waterDetected = true
                            
                            if not rootPart:FindFirstChild("WaterWalkPart") then
                                local waterWalkPart = Instance.new("Part")
                                waterWalkPart.Name = "WaterWalkPart"
                                waterWalkPart.Anchored = true
                                waterWalkPart.CanCollide = true
                                waterWalkPart.Transparency = 1
                                waterWalkPart.Size = Vector3.new(8, 0.2, 8)
                                waterWalkPart.Position = Vector3.new(rootPart.Position.X, rootPart.Position.Y - 2, rootPart.Position.Z)
                                waterWalkPart.Parent = Workspace
                                game:GetService("Debris"):AddItem(waterWalkPart, 1.0)
                            end
                            break
                        end
                    end
                end
            end
        end)
    end
end

-- Enhanced Player NoClip with Anti-Fling Protection
local function togglePlayerNoclip(enabled)
    Movement.playerNoclipEnabled = enabled
    
    -- Disconnect existing connections
    if connections.playerNoclip then
        connections.playerNoclip:Disconnect()
        connections.playerNoclip = nil
    end
    if connections.antiFling then
        connections.antiFling:Disconnect()
        connections.antiFling = nil
    end
    
    if enabled then
        -- Main noclip function - makes other players non-solid
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
        
        -- Anti-fling protection
        connections.antiFling = RunService.Heartbeat:Connect(function()
            if not Movement.playerNoclipEnabled then return end
            if not refreshReferences() or not rootPart then return end
            
            -- Detect abnormal velocity (potential fling)
            local currentVelocity = rootPart.Velocity
            local maxNormalVelocity = 200 -- Adjust this value as needed
            
            -- Check if velocity is too high (indicates fling attempt)
            if currentVelocity.Magnitude > maxNormalVelocity then
                -- Reset velocity to prevent fling
                rootPart.Velocity = Vector3.new(0, 0, 0)
                
                -- Optional: Also reset angular velocity if rootPart has BodyAngularVelocity
                local bodyAngularVelocity = rootPart:FindFirstChild("BodyAngularVelocity")
                if bodyAngularVelocity then
                    bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
                end
            end
            
            -- Additional protection: Remove any suspicious BodyMovers from other players that might affect us
            for _, otherPlayer in pairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local otherRoot = otherPlayer.Character.HumanoidRootPart
                    
                    -- Remove any BodyVelocity, BodyPosition, or other BodyMovers that might be used for flinging
                    for _, obj in pairs(otherRoot:GetChildren()) do
                        if obj:IsA("BodyVelocity") or obj:IsA("BodyPosition") or obj:IsA("BodyAngularVelocity") then
                            -- Check if it's creating abnormal forces
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
        -- Restore collision for other players when disabled
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

-- FIXED Super Swim - Only when in water
local function toggleSwim(enabled)
    Movement.swimEnabled = enabled
    
    if connections.swim then
        connections.swim:Disconnect()
        connections.swim = nil
    end
    
    if enabled then
        connections.swim = RunService.Heartbeat:Connect(function()
            if not Movement.swimEnabled then return end
            if not refreshReferences() or not humanoid then return end
            
            -- Check if player is actually in water/swimming
            if humanoid:GetState() == Enum.HumanoidStateType.Swimming then
                humanoid.WalkSpeed = 75 -- Fast swim speed
            else
                -- Check for terrain water around player
                local inWater = false
                if rootPart then
                    local region = Region3.new(
                        rootPart.Position - Vector3.new(2, 2, 2),
                        rootPart.Position + Vector3.new(2, 2, 2)
                    )
                    local materials, occupancies = Workspace.Terrain:ReadVoxels(region, 16)
                    
                    for x = 1, materials.Size.X do
                        for y = 1, materials.Size.Y do
                            for z = 1, materials.Size.Z do
                                if materials[x][y][z] == Enum.Material.Water and occupancies[x][y][z] > 0 then
                                    inWater = true
                                    break
                                end
                            end
                        end
                    end
                end
                
                -- Apply fast speed only in water
                if inWater then
                    humanoid.WalkSpeed = 75
                else
                    humanoid.WalkSpeed = Movement.defaultWalkSpeed
                end
            end
        end)
    else
        if refreshReferences() and humanoid then
            humanoid.WalkSpeed = Movement.defaultWalkSpeed
        end
    end
end

-- Function to apply current settings to active features
function Movement.applySettings()
    print("Applying Movement settings")
    
    -- Apply speed setting if speed hack is enabled
    if Movement.speedEnabled then
        toggleSpeed(true)
    end
    
    -- Apply jump setting if jump hack is enabled
    if Movement.jumpEnabled then
        toggleJump(true)
    end
    
    -- Note: Fly speed is applied in real-time during fly/float loops
end

-- Function to create buttons for Movement features
function Movement.loadMovementButtons(createButton, createToggleButton)
    print("Loading movement buttons")
    if not createButton or not createToggleButton then
        warn("Error: createButton or createToggleButton not provided!")
        return
    end
    
    setupScrollFrame()
    
    -- Original features
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
    createToggleButton("Underground", toggleUnderground)
    
    -- New features
    createToggleButton("Ghost Mode", toggleGhost)
    createToggleButton("Fake Lag", toggleFakeLag)
    createToggleButton("Rewind (Tap ⏪)", toggleRewind)
    createToggleButton("Mirror Clone", toggleMirrorClone)
    createToggleButton("Reverse Walk", toggleReverseWalk)
    createToggleButton("Fast Ladder", toggleFastLadder)
    createToggleButton("Sticky Platform", toggleStickyPlatform)
end

-- Enhanced reset function
function Movement.resetStates()
    print("Resetting Movement states")
    
    -- Reset all states
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
    Movement.undergroundEnabled = false
    Movement.ghostEnabled = false
    Movement.fakeLagEnabled = false
    Movement.rewindEnabled = false
    Movement.mirrorCloneEnabled = false
    Movement.reverseWalkEnabled = false
    Movement.fastLadderEnabled = false
    Movement.stickyPlatformEnabled = false
    
    Movement.jumpCount = 0
    joystickDelta = Vector2.new(0, 0)
    isTouchingJoystick = false
    joystickTouchId = nil
    
    -- Clear history and clones
    positionHistory = {}
    fakeLagPositions = {}
    lastNetworkUpdate = 0
    if mirrorClone then
        mirrorClone:Destroy()
        mirrorClone = nil
    end
    originalPosition = nil
    ghostStartPosition = nil
    
    local allConnections = {
        "fly", "noclip", "playerNoclip", "infiniteJump", "walkOnWater", "doubleJump", 
        "wallClimb", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", 
        "flyDown", "flyDownEnd", "wallClimbInput", "float", "floatInput", 
        "floatBegan", "floatEnded", "underground", "antiFling", "ghost", "fakeLag",
        "rewind", "rewindInput", "reverseWalk", "fastLadder", "stickyPlatform", "swim"
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
            end)
        end
        
        if player.Character then
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
        
        -- Clean up any platform welds
        if rootPart then
            local existingWeld = rootPart:FindFirstChild("PlatformWeld")
            if existingWeld then
                existingWeld:Destroy()
            end
        end
    end
    
    Workspace.Gravity = Movement.defaultGravity
    
    -- Restore collision for other players
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
    if wallClimbButton then
        wallClimbButton.Visible = false
        wallClimbButton.Text = "Climb"
    end
    if flyUpButton then
        flyUpButton.Visible = false
        flyUpButton.BackgroundTransparency = 0.1
    end
    if flyDownButton then
        flyDownButton.Visible = false
        flyDownButton.BackgroundTransparency = 0.1
    end
    if rewindButton then
        rewindButton.Visible = false
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
            {Movement.undergroundEnabled, toggleUnderground, "Underground"},
            {Movement.flyEnabled, toggleFly, "Fly"},
            {Movement.ghostEnabled, toggleGhost, "Ghost Mode"},
            {Movement.fakeLagEnabled, toggleFakeLag, "Fake Lag"},
            {Movement.rewindEnabled, toggleRewind, "Rewind"},
            {Movement.mirrorCloneEnabled, toggleMirrorClone, "Mirror Clone"},
            {Movement.reverseWalkEnabled, toggleReverseWalk, "Reverse Walk"},
            {Movement.fastLadderEnabled, toggleFastLadder, "Fast Ladder"},
            {Movement.stickyPlatformEnabled, toggleStickyPlatform, "Sticky Platform"}
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
    
    -- Initialize all states to false
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
    Movement.undergroundEnabled = false
    Movement.ghostEnabled = false
    Movement.fakeLagEnabled = false
    Movement.rewindEnabled = false
    Movement.mirrorCloneEnabled = false
    Movement.reverseWalkEnabled = false
    Movement.fastLadderEnabled = false
    Movement.stickyPlatformEnabled = false
    
    Movement.jumpCount = 0
    joystickDelta = Vector2.new(0, 0)
    isTouchingJoystick = false
    joystickTouchId = nil
    
    -- Initialize new feature variables
    positionHistory = {}
    fakeLagPositions = {}
    lastNetworkUpdate = 0
    mirrorClone = nil
    originalPosition = nil
    ghostStartPosition = nil
    
    createMobileControls()
    setupScrollFrame()
    
    print("Movement module initialized successfully")
    return true
end

-- Enhanced debug function
function Movement.debug()
    print("=== Enhanced Movement Module Debug Info ===")
    print("Original Features:")
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
    print("  undergroundEnabled:", Movement.undergroundEnabled)
    
    print("New Features:")
    print("  ghostEnabled:", Movement.ghostEnabled)
    print("  fakeLagEnabled:", Movement.fakeLagEnabled)
    print("  rewindEnabled:", Movement.rewindEnabled)
    print("  mirrorCloneEnabled:", Movement.mirrorCloneEnabled)
    print("  reverseWalkEnabled:", Movement.reverseWalkEnabled)
    print("  fastLadderEnabled:", Movement.fastLadderEnabled)
    print("  stickyPlatformEnabled:", Movement.stickyPlatformEnabled)
    
    print("New Feature Data:")
    print("  positionHistory entries:", #positionHistory)
    print("  fakeLagPositions entries:", #fakeLagPositions)
    print("  mirrorClone exists:", mirrorClone ~= nil)
    print("  originalPosition stored:", originalPosition ~= nil)
    print("  ghostStartPosition stored:", ghostStartPosition ~= nil)
    
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
    else
        print("  settings: nil")
    end
    
    print("Fly/Float System:")
    print("  flyBodyVelocity:", flyBodyVelocity ~= nil)
    print("  joystickDelta:", joystickDelta)
    print("  isTouchingJoystick:", isTouchingJoystick)
    
    print("UI Elements:")
    print("  flyJoystickFrame:", flyJoystickFrame ~= nil)
    print("  wallClimbButton:", wallClimbButton ~= nil)
    print("  flyUpButton:", flyUpButton ~= nil)
    print("  flyDownButton:", flyDownButton ~= nil)
    print("  rewindButton:", rewindButton ~= nil)
    
    print("Active Connections:")
    local activeConnections = 0
    for name, conn in pairs(connections) do
        if conn and conn.Connected then
            activeConnections = activeConnections + 1
            print("  " .. name .. ": connected")
        end
    end
    print("  Total active:", activeConnections)
    
    print("Default Values:")
    print("  defaultWalkSpeed:", Movement.defaultWalkSpeed)
    print("  defaultJumpPower:", Movement.defaultJumpPower)
    print("  defaultJumpHeight:", Movement.defaultJumpHeight)
    print("  defaultGravity:", Movement.defaultGravity)
    print("===============================================")
end

-- Add cleanup function for when module is unloaded
function Movement.cleanup()
    print("Cleaning up Movement module")
    
    Movement.resetStates()
    
    if flyJoystickFrame then flyJoystickFrame:Destroy() end
    if wallClimbButton then wallClimbButton:Destroy() end
    if flyUpButton then flyUpButton:Destroy() end
    if flyDownButton then flyDownButton:Destroy() end
    if rewindButton then rewindButton:Destroy() end
    if mirrorClone then mirrorClone:Destroy() end
    
    flyJoystickFrame = nil
    flyJoystickKnob = nil
    wallClimbButton = nil
    flyUpButton = nil
    flyDownButton = nil
    flyBodyVelocity = nil
    mirrorClone = nil
    rewindButton = nil
    
    positionHistory = {}
    fakeLagPositions = {}
    originalPosition = nil
    ghostStartPosition = nil
    lastNetworkUpdate = 0
    
    print("Movement module cleaned up")
end

return Movement