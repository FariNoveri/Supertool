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
local floatVerticalInput = 0
local isTouchingJoystick = false
local joystickTouchId = nil

-- Scroll frame for UI
local function setupScrollFrame()
    if ScrollFrame then
        ScrollFrame.ScrollingEnabled = true
        ScrollFrame.ScrollBarThickness = 8
        ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 400)
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

-- Create virtual controls with better positioning
local function createMobileControls()
    print("Creating mobile controls")
    
    if flyJoystickFrame then flyJoystickFrame:Destroy() end
    if wallClimbButton then wallClimbButton:Destroy() end
    if flyUpButton then flyUpButton:Destroy() end
    if flyDownButton then flyDownButton:Destroy() end

    flyJoystickFrame = Instance.new("Frame")
    flyJoystickFrame.Name = "FlyJoystick"
    flyJoystickFrame.Size = UDim2.new(0, 100, 0, 100)
    flyJoystickFrame.Position = UDim2.new(0, 20, 1, -130)
    flyJoystickFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    flyJoystickFrame.BackgroundTransparency = 0.3
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
    flyJoystickKnob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    flyJoystickKnob.BackgroundTransparency = 0.1
    flyJoystickKnob.BorderSizePixel = 0
    flyJoystickKnob.ZIndex = 11
    flyJoystickKnob.Parent = flyJoystickFrame

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0.5, 0)
    knobCorner.Parent = flyJoystickKnob

    wallClimbButton = Instance.new("TextButton")
    wallClimbButton.Name = "WallClimbButton"
    wallClimbButton.Size = UDim2.new(0, 60, 0, 60)
    wallClimbButton.Position = UDim2.new(1, -80, 1, -130)
    wallClimbButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    wallClimbButton.BackgroundTransparency = 0.3
    wallClimbButton.BorderSizePixel = 0
    wallClimbButton.Text = "Climb"
    wallClimbButton.Font = Enum.Font.GothamBold
    wallClimbButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    wallClimbButton.TextSize = 12
    wallClimbButton.Visible = false
    wallClimbButton.ZIndex = 10
    wallClimbButton.Parent = ScreenGui or player.PlayerGui

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0.2, 0)
    buttonCorner.Parent = wallClimbButton

    flyUpButton = Instance.new("TextButton")
    flyUpButton.Name = "FlyUpButton"
    flyUpButton.Size = UDim2.new(0, 50, 0, 50)
    flyUpButton.Position = UDim2.new(1, -70, 1, -200)
    flyUpButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    flyUpButton.BackgroundTransparency = 0.3
    flyUpButton.BorderSizePixel = 0
    flyUpButton.Text = "▲"
    flyUpButton.Font = Enum.Font.GothamBold
    flyUpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    flyUpButton.TextSize = 16
    flyUpButton.Visible = false
    flyUpButton.ZIndex = 10
    flyUpButton.Parent = ScreenGui or player.PlayerGui

    local upCorner = Instance.new("UICorner")
    upCorner.CornerRadius = UDim.new(0.3, 0)
    upCorner.Parent = flyUpButton

    flyDownButton = Instance.new("TextButton")
    flyDownButton.Name = "FlyDownButton"
    flyDownButton.Size = UDim2.new(0, 50, 0, 50)
    flyDownButton.Position = UDim2.new(1, -70, 1, -140)
    flyDownButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    flyDownButton.BackgroundTransparency = 0.3
    flyDownButton.BorderSizePixel = 0
    flyDownButton.Text = "▼"
    flyDownButton.Font = Enum.Font.GothamBold
    flyDownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    flyDownButton.TextSize = 16
    flyDownButton.Visible = false
    flyDownButton.ZIndex = 10
    flyDownButton.Parent = ScreenGui or player.PlayerGui

    local downCorner = Instance.new("UICorner")
    downCorner.CornerRadius = UDim.new(0.3, 0)
    downCorner.Parent = flyDownButton

    print("Mobile controls created successfully")
end

-- Improved joystick handling
local function handleFlyJoystick(input, gameProcessed)
    if not (Movement.flyEnabled or Movement.floatEnabled) or not flyJoystickFrame or not flyJoystickFrame.Visible then 
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

-- Speed Hack with better reference handling
local function toggleSpeed(enabled)
    Movement.speedEnabled = enabled
    
    if enabled then
        local function applySpeed()
            if refreshReferences() and humanoid then
                humanoid.WalkSpeed = settings.WalkSpeed and settings.WalkSpeed.value or 50
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

-- Jump Hack with better reference handling
local function toggleJump(enabled)
    Movement.jumpEnabled = enabled
    
    if enabled then
        local function applyJump()
            if refreshReferences() and humanoid then
                if humanoid:FindFirstChild("JumpHeight") then
                    humanoid.JumpHeight = settings.JumpHeight and settings.JumpHeight.value or 50
                else
                    humanoid.JumpPower = (settings.JumpHeight and settings.JumpHeight.value * 2.4) or 150
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

-- Float Hack
local function toggleFloat(enabled)
    Movement.floatEnabled = enabled
    print("Float toggle:", enabled)
    
    local floatConnections = {"float", "floatInput", "floatBegan", "floatEnded", "floatUp", "floatUpEnd", "floatDown", "floatDownEnd"}
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
            flyBodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
            flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            flyBodyVelocity.Parent = rootPart
            
            if flyJoystickFrame then flyJoystickFrame.Visible = true end
            if flyUpButton then flyUpButton.Visible = true end
            if flyDownButton then flyDownButton.Visible = true end
            
            connections.float = RunService.Heartbeat:Connect(function()
                if not Movement.floatEnabled then return end
                if not refreshReferences() or not rootPart or not humanoid then return end
                
                if not flyBodyVelocity or flyBodyVelocity.Parent ~= rootPart then
                    if flyBodyVelocity then flyBodyVelocity:Destroy() end
                    flyBodyVelocity = Instance.new("BodyVelocity")
                    flyBodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                    flyBodyVelocity.Parent = rootPart
                end
                
                local camera = Workspace.CurrentCamera
                if not camera then return end
                
                local floatDirection = Vector3.new(0, 0, 0)
                flySpeed = settings.FlySpeed and settings.FlySpeed.value or 50
                
                if joystickDelta.Magnitude > 0.05 then
                    local forward = camera.CFrame.LookVector
                    local right = camera.CFrame.RightVector
                    
                    forward = Vector3.new(forward.X, 0, forward.Z).Unit
                    right = Vector3.new(right.X, 0, right.Z).Unit
                    
                    floatDirection = floatDirection + (right * joystickDelta.X) + (forward * -joystickDelta.Y)
                end
                
                if floatVerticalInput ~= 0 then
                    floatDirection = floatDirection + Vector3.new(0, floatVerticalInput, 0)
                end
                
                if floatDirection.Magnitude > 0 then
                    flyBodyVelocity.Velocity = floatDirection.Unit * flySpeed
                else
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                end
            end)
            
            connections.floatInput = UserInputService.InputChanged:Connect(handleFlyJoystick)
            connections.floatBegan = UserInputService.InputBegan:Connect(handleFlyJoystick)
            connections.floatEnded = UserInputService.InputEnded:Connect(handleFlyJoystick)
            
            if flyUpButton then
                connections.floatUp = flyUpButton.MouseButton1Down:Connect(function()
                    floatVerticalInput = 1
                    flyUpButton.BackgroundTransparency = 0.1
                end)
                connections.floatUpEnd = flyUpButton.MouseButton1Up:Connect(function()
                    floatVerticalInput = 0
                    flyUpButton.BackgroundTransparency = 0.3
                end)
            end
            
            if flyDownButton then
                connections.floatDown = flyDownButton.MouseButton1Down:Connect(function()
                    floatVerticalInput = -1
                    flyDownButton.BackgroundTransparency = 0.1
                end)
                connections.floatDownEnd = flyDownButton.MouseButton1Up:Connect(function()
                    floatVerticalInput = 0
                    flyDownButton.BackgroundTransparency = 0.3
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
            flyUpButton.BackgroundTransparency = 0.3
        end
        if flyDownButton then 
            flyDownButton.Visible = false
            flyDownButton.BackgroundTransparency = 0.3
        end
        
        floatVerticalInput = 0
        joystickDelta = Vector2.new(0, 0)
        isTouchingJoystick = false
        joystickTouchId = nil
    end
end

-- Underground walking
-- Underground walking - Fixed version
local function toggleUnderground(enabled)
    Movement.undergroundEnabled = enabled
    
    if connections.underground then
        connections.underground:Disconnect()
        connections.underground = nil
    end
    
    if enabled then
        -- Move player underground when enabled
        task.spawn(function()
            if not refreshReferences() or not rootPart or not player.Character then return end
            
            -- Disable collision for all character parts
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
            
            -- Move player down underground (5-10 studs below ground)
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {player.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            
            local raycast = Workspace:Raycast(rootPart.Position, Vector3.new(0, -1000, 0), raycastParams)
            if raycast and raycast.Instance then
                -- Position player 7 studs below the ground surface
                local undergroundPosition = Vector3.new(
                    rootPart.Position.X, 
                    raycast.Position.Y - 7, 
                    rootPart.Position.Z
                )
                rootPart.CFrame = CFrame.new(undergroundPosition)
            else
                -- If no ground found, just move down
                rootPart.CFrame = rootPart.CFrame - Vector3.new(0, 10, 0)
            end
        end)
        
        -- Keep player underground and maintain collision state
        connections.underground = RunService.Heartbeat:Connect(function()
            if not Movement.undergroundEnabled then return end
            if not refreshReferences() or not rootPart or not player.Character then return end
            
            -- Ensure all parts remain non-collidable
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
            
            -- Prevent player from floating up by checking if they're above ground
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {player.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            
            local upwardRaycast = Workspace:Raycast(rootPart.Position, Vector3.new(0, 100, 0), raycastParams)
            if upwardRaycast and upwardRaycast.Instance then
                local groundLevel = upwardRaycast.Position.Y
                local playerLevel = rootPart.Position.Y
                
                -- If player is too close to surface (less than 3 studs below), push them down
                if playerLevel > groundLevel - 3 then
                    rootPart.CFrame = CFrame.new(
                        rootPart.Position.X,
                        groundLevel - 7,
                        rootPart.Position.Z
                    )
                end
            end
        end)
    else
        -- When disabled, teleport player back to surface
        if refreshReferences() and rootPart and player.Character then
            -- First, restore collision for body parts (except HumanoidRootPart)
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
            
            -- Find ground surface above player
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {player.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            
            -- Cast ray upward to find surface
            local upwardRaycast = Workspace:Raycast(rootPart.Position, Vector3.new(0, 1000, 0), raycastParams)
            if upwardRaycast and upwardRaycast.Instance then
                -- Teleport player to surface + 3 studs above ground
                local surfacePosition = Vector3.new(
                    rootPart.Position.X,
                    upwardRaycast.Position.Y + 3,
                    rootPart.Position.Z
                )
                rootPart.CFrame = CFrame.new(surfacePosition)
            else
                -- If no surface found above, just move player up significantly
                rootPart.CFrame = rootPart.CFrame + Vector3.new(0, 50, 0)
            end
            
            -- Wait a bit then ensure collision is restored
            task.wait(0.1)
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
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

-- Improved Fly Hack
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
                flySpeed = settings.FlySpeed and settings.FlySpeed.value or 50
                
                if joystickDelta.Magnitude > 0.05 then
                    local forward = camera.CFrame.LookVector
                    local right = camera.CFrame.RightVector
                    
                    forward = Vector3.new(forward.X, 0, forward.Z).Unit
                    right = Vector3.new(right.X, 0, right.Z).Unit
                    
                    flyDirection = flyDirection + (right * joystickDelta.X) + (forward * -joystickDelta.Y)
                end
                
                if floatVerticalInput ~= 0 then
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
                    floatVerticalInput = 1
                    flyUpButton.BackgroundTransparency = 0.1
                end)
                connections.flyUpEnd = flyUpButton.MouseButton1Up:Connect(function()
                    floatVerticalInput = 0
                    flyUpButton.BackgroundTransparency = 0.3
                end)
            end
            
            if flyDownButton then
                connections.flyDown = flyDownButton.MouseButton1Down:Connect(function()
                    floatVerticalInput = -1
                    flyDownButton.BackgroundTransparency = 0.1
                end)
                connections.flyDownEnd = flyDownButton.MouseButton1Up:Connect(function()
                    floatVerticalInput = 0
                    flyDownButton.BackgroundTransparency = 0.3
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
            flyUpButton.BackgroundTransparency = 0.3
        end
        if flyDownButton then 
            flyDownButton.Visible = false
            flyDownButton.BackgroundTransparency = 0.3
        end
        
        floatVerticalInput = 0
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

-- Player NoClip with better handling
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
    createToggleButton("Underground", toggleUnderground)
end

-- Improved reset function
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
    Movement.undergroundEnabled = false
    Movement.jumpCount = 0
    floatVerticalInput = 0
    joystickDelta = Vector2.new(0, 0)
    isTouchingJoystick = false
    joystickTouchId = nil
    
    local movementConnections = {
        "fly", "noclip", "playerNoclip", "infiniteJump", "walkOnWater", "doubleJump", 
        "wallClimb", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", 
        "flyDown", "flyDownEnd", "wallClimbInput", "float", "floatInput", 
        "floatBegan", "floatEnded", "floatUp", "floatUpEnd", "floatDown", 
        "floatDownEnd", "underground"
    }
    for _, connName in ipairs(movementConnections) do
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
    end
    
    Workspace.Gravity = Movement.defaultGravity
    
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
        flyUpButton.BackgroundTransparency = 0.3
    end
    if flyDownButton then
        flyDownButton.Visible = false
        flyDownButton.BackgroundTransparency = 0.3
    end
end

-- Improved reference update function
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
            {Movement.flyEnabled, toggleFly, "Fly"}
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
    Movement.undergroundEnabled = false
    Movement.jumpCount = 0
    floatVerticalInput = 0
    joystickDelta = Vector2.new(0, 0)
    isTouchingJoystick = false
    joystickTouchId = nil
    
    createMobileControls()
    setupScrollFrame()
    
    print("Movement module initialized successfully")
    return true
end

-- Enhanced debug function
function Movement.debug()
    print("=== Movement Module Debug Info ===")
    print("Module States:")
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
    
    print("References:")
    print("  player:", player ~= nil)
    print("  humanoid:", humanoid ~= nil)
    print("  rootPart:", rootPart ~= nil)
    print("  player.Character:", player and player.Character ~= nil)
    
    print("Fly/Float System:")
    print("  flyBodyVelocity:", flyBodyVelocity ~= nil)
    print("  joystickDelta:", joystickDelta)
    print("  floatVerticalInput:", floatVerticalInput)
    print("  isTouchingJoystick:", isTouchingJoystick)
    
    print("UI Elements:")
    print("  flyJoystickFrame:", flyJoystickFrame ~= nil)
    print("  wallClimbButton:", wallClimbButton ~= nil)
    print("  flyUpButton:", flyUpButton ~= nil)
    print("  flyDownButton:", flyDownButton ~= nil)
    
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
    print("  classified")
    print("===================================")
end

-- Add cleanup function for when module is unloaded
function Movement.cleanup()
    print("Cleaning up Movement module")
    
    Movement.resetStates()
    
    if flyJoystickFrame then flyJoystickFrame:Destroy() end
    if wallClimbButton then wallClimbButton:Destroy() end
    if flyUpButton then flyUpButton:Destroy() end
    if flyDownButton then flyDownButton:Destroy() end
    
    flyJoystickFrame = nil
    flyJoystickKnob = nil
    wallClimbButton = nil
    flyUpButton = nil
    flyDownButton = nil
    flyBodyVelocity = nil
    
    print("Movement module cleaned up")
end

return Movement