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
local flyVerticalInput = 0
local isTouchingJoystick = false
local joystickTouchId = nil

-- Reference refresh function
local function refreshReferences()
    if not player or not player.Character then 
        return false 
    end
    
    local newHumanoid = player.Character:FindFirstChildOfClass("Humanoid")
    local newRootPart = player.Character:FindFirstChild("HumanoidRootPart")
    
    if newHumanoid ~= humanoid then
        humanoid = newHumanoid
    end
    if newRootPart ~= rootPart then
        rootPart = newRootPart
    end
    
    return humanoid ~= nil and rootPart ~= nil
end

-- Create virtual controls with better positioning
local function createMobileControls()
    print("Creating mobile controls")
    
    -- Clean up existing controls
    if flyJoystickFrame then flyJoystickFrame:Destroy() end
    if wallClimbButton then wallClimbButton:Destroy() end
    if flyUpButton then flyUpButton:Destroy() end
    if flyDownButton then flyDownButton:Destroy() end

    -- Fly Joystick - Better positioning and size
    flyJoystickFrame = Instance.new("Frame")
    flyJoystickFrame.Name = "FlyJoystick"
    flyJoystickFrame.Size = UDim2.new(0, 100, 0, 100)
    flyJoystickFrame.Position = UDim2.new(0, 20, 1, -130)
    flyJoystickFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    flyJoystickFrame.BackgroundTransparency = 0.3
    flyJoystickFrame.BorderSizePixel = 0
    flyJoystickFrame.Visible = false
    flyJoystickFrame.ZIndex = 10
    flyJoystickFrame.Parent = ScreenGui

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

    -- Wall Climb Button
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
    wallClimbButton.Parent = ScreenGui

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0.2, 0)
    buttonCorner.Parent = wallClimbButton

    -- Fly Up Button
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
    flyUpButton.Parent = ScreenGui

    local upCorner = Instance.new("UICorner")
    upCorner.CornerRadius = UDim.new(0.3, 0)
    upCorner.Parent = flyUpButton

    -- Fly Down Button
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
    flyDownButton.Parent = ScreenGui

    local downCorner = Instance.new("UICorner")
    downCorner.CornerRadius = UDim.new(0.3, 0)
    downCorner.Parent = flyDownButton

    print("Mobile controls created successfully")
end

-- Improved joystick handling
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
            -- Retry after a short delay
            task.wait(0.1)
            applySpeed()
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
            task.wait(0.1)
            applyJump()
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
    
    -- Clean up connections
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

-- Improved Fly Hack - Fixed the main issue
local function toggleFly(enabled)
    Movement.flyEnabled = enabled
    print("Fly toggle:", enabled)
    
    -- Clean up all fly connections
    local flyConnections = {"fly", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", "flyDown", "flyDownEnd"}
    for _, connName in ipairs(flyConnections) do
        if connections[connName] then
            connections[connName]:Disconnect()
            connections[connName] = nil
        end
    end
    
    -- Clean up BodyVelocity
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    
    if enabled then
        -- Wait a moment for character to be ready
        task.wait(0.1)
        
        if not refreshReferences() or not rootPart then
            print("Failed to get rootPart for fly")
            Movement.flyEnabled = false
            return
        end
        
        -- Create new BodyVelocity
        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        flyBodyVelocity.Parent = rootPart
        
        -- Show fly controls
        if flyJoystickFrame then flyJoystickFrame.Visible = true end
        if flyUpButton then flyUpButton.Visible = true end
        if flyDownButton then flyDownButton.Visible = true end
        
        -- Main fly loop - simplified and more reliable
        connections.fly = RunService.Heartbeat:Connect(function()
            if not Movement.flyEnabled then return end
            if not refreshReferences() or not rootPart then return end
            
            -- Recreate BodyVelocity if it's missing
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
            
            -- Horizontal movement
            if joystickDelta.Magnitude > 0.05 then
                local forward = camera.CFrame.LookVector
                local right = camera.CFrame.RightVector
                
                -- Remove Y component for cleaner horizontal movement
                forward = Vector3.new(forward.X, 0, forward.Z).Unit
                right = Vector3.new(right.X, 0, right.Z).Unit
                
                flyDirection = flyDirection + (right * joystickDelta.X) + (forward * -joystickDelta.Y)
            end
            
            -- Vertical movement
            if flyVerticalInput ~= 0 then
                flyDirection = flyDirection + Vector3.new(0, flyVerticalInput, 0)
            end
            
            -- Apply movement with proper magnitude
            if flyDirection.Magnitude > 0 then
                flyBodyVelocity.Velocity = flyDirection.Unit * flySpeed
            else
                flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end)
        
        -- Input handling
        connections.flyInput = UserInputService.InputChanged:Connect(handleFlyJoystick)
        connections.flyBegan = UserInputService.InputBegan:Connect(handleFlyJoystick)
        connections.flyEnded = UserInputService.InputEnded:Connect(handleFlyJoystick)
        
        -- Up/Down button handling
        if flyUpButton then
            connections.flyUp = flyUpButton.MouseButton1Down:Connect(function()
                flyVerticalInput = 1
                flyUpButton.BackgroundTransparency = 0.1
            end)
            connections.flyUpEnd = flyUpButton.MouseButton1Up:Connect(function()
                flyVerticalInput = 0
                flyUpButton.BackgroundTransparency = 0.3
            end)
        end
        
        if flyDownButton then
            connections.flyDown = flyDownButton.MouseButton1Down:Connect(function()
                flyVerticalInput = -1
                flyDownButton.BackgroundTransparency = 0.1
            end)
            connections.flyDownEnd = flyDownButton.MouseButton1Up:Connect(function()
                flyVerticalInput = 0
                flyDownButton.BackgroundTransparency = 0.3
            end)
        end
        
        print("Fly enabled successfully")
    else
        -- Disable fly
        -- Hide controls
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
        
        -- Reset variables
        flyVerticalInput = 0
        joystickDelta = Vector2.new(0, 0)
        isTouchingJoystick = false
        joystickTouchId = nil
        
        print("Fly disabled")
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
local function togglePlayerNoclip(enabled)
    Movement.playerNoclipEnabled = enabled
    
    if connections.playerNoclip then
        connections.playerNoclip:Disconnect()
        connections.playerNoclip = nil
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
        task.wait(0.1)
        applySwim()
    end
end

-- Function to create buttons for Movement features
function Movement.loadMovementButtons(createButton, createToggleButton)
    print("Loading movement buttons")
    if not createButton or not createToggleButton then
        warn("Error: createButton or createToggleButton not provided!")
        return
    end
    
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
end

-- Improved reset function
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
    Movement.jumpCount = 0
    flyVerticalInput = 0
    joystickDelta = Vector2.new(0, 0)
    isTouchingJoystick = false
    joystickTouchId = nil
    
    -- Disconnect all connections
    local movementConnections = {"fly", "noclip", "playerNoclip", "infiniteJump", "walkOnWater", "doubleJump", "wallClimb", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", "flyDown", "flyDownEnd", "wallClimbInput"}
    for _, connName in ipairs(movementConnections) do
        if connections[connName] then
            connections[connName]:Disconnect()
            connections[connName] = nil
        end
    end
    
    -- Clean up fly objects
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    
    -- Reset character properties
    if refreshReferences() then
        if humanoid then
            humanoid.WalkSpeed = Movement.defaultWalkSpeed
            if humanoid:FindFirstChild("JumpHeight") then
                humanoid.JumpHeight = Movement.defaultJumpHeight
            else
                humanoid.JumpPower = Movement.defaultJumpPower
            end
            pcall(function()
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
            end)
        end
        
        -- Re-enable collision
        if player.Character then
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
    
    -- Reset workspace properties
    Workspace.Gravity = Movement.defaultGravity
    
    -- Hide UI elements
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
    
    -- Recreate mobile controls
    createMobileControls()
    
    -- Reapply active states with delay to ensure character is ready
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
        {Movement.flyEnabled, toggleFly, "Fly"} -- Fly last to ensure other states are ready
    }
    
    for _, state in ipairs(statesToReapply) do
        if state[1] then -- if enabled
            print("Reapplying", state[3])
            state[2](true) -- call toggle function
        end
    end
end

-- Function to set dependencies
function Movement.init(deps)
    print("Initializing Movement module")
    if not deps then
        warn("Error: No dependencies provided!")
        return false
    end
    
    Players = deps.Players
    RunService = deps.RunService
    Workspace = deps.Workspace
    UserInputService = deps.UserInputService
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    connections = deps.connections
    buttonStates = deps.buttonStates
    ScrollFrame = deps.ScrollFrame
    ScreenGui = deps.ScreenGui
    settings = deps.settings
    player = deps.player
    
    -- Validate critical dependencies
    if not Players or not RunService or not Workspace or not UserInputService then
        warn("Critical services missing!")
        return false
    end
    
    if not player then
        player = Players.LocalPlayer
    end
    
    -- Initialize default values
    if humanoid then
        Movement.defaultWalkSpeed = humanoid.WalkSpeed or 16
        if humanoid:FindFirstChild("JumpHeight") then
            Movement.defaultJumpHeight = humanoid.JumpHeight or 7.2
        else
            Movement.defaultJumpPower = humanoid.JumpPower or 50
        end
    end
    Movement.defaultGravity = Workspace.Gravity or 196.2
    
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
    Movement.jumpCount = 0
    flyVerticalInput = 0
    joystickDelta = Vector2.new(0, 0)
    isTouchingJoystick = false
    joystickTouchId = nil
    
    createMobileControls()
    
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
    
    print("References:")
    print("  player:", player ~= nil)
    print("  humanoid:", humanoid ~= nil)
    print("  rootPart:", rootPart ~= nil)
    print("  player.Character:", player and player.Character ~= nil)
    
    print("Fly System:")
    print("  flyBodyVelocity:", flyBodyVelocity ~= nil)
    print("  joystickDelta:", joystickDelta)
    print("  flyVerticalInput:", flyVerticalInput)
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
    print("  defaultGravity:", Movement.defaultGravity)
    print("===================================")
end

-- Add cleanup function for when module is unloaded
function Movement.cleanup()
    print("Cleaning up Movement module")
    
    -- Reset all states first
    Movement.resetStates()
    
    -- Destroy UI elements
    if flyJoystickFrame then flyJoystickFrame:Destroy() end
    if wallClimbButton then wallClimbButton:Destroy() end
    if flyUpButton then flyUpButton:Destroy() end
    if flyDownButton then flyDownButton:Destroy() end
    
    -- Clear references
    flyJoystickFrame = nil
    flyJoystickKnob = nil
    wallClimbButton = nil
    flyUpButton = nil
    flyDownButton = nil
    flyBodyVelocity = nil
    
    print("Movement module cleaned up")
end

return Movement