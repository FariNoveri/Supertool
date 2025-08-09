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

-- Create virtual controls
local function createMobileControls()
    print("Creating mobile controls")
    
    -- Clean up existing controls
    if flyJoystickFrame then flyJoystickFrame:Destroy() end
    if wallClimbButton then wallClimbButton:Destroy() end
    if flyUpButton then flyUpButton:Destroy() end
    if flyDownButton then flyDownButton:Destroy() end

    -- Fly Joystick
    flyJoystickFrame = Instance.new("Frame")
    flyJoystickFrame.Name = "FlyJoystick"
    flyJoystickFrame.Size = UDim2.new(0, 120, 0, 120)
    flyJoystickFrame.Position = UDim2.new(0.05, 0, 0.65, 0)
    flyJoystickFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    flyJoystickFrame.BackgroundTransparency = 0.6
    flyJoystickFrame.BorderSizePixel = 0
    flyJoystickFrame.Visible = false
    flyJoystickFrame.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = flyJoystickFrame

    flyJoystickKnob = Instance.new("Frame")
    flyJoystickKnob.Name = "Knob"
    flyJoystickKnob.Size = UDim2.new(0, 50, 0, 50)
    flyJoystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
    flyJoystickKnob.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    flyJoystickKnob.BackgroundTransparency = 0.2
    flyJoystickKnob.BorderSizePixel = 0
    flyJoystickKnob.Parent = flyJoystickFrame

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0.5, 0)
    knobCorner.Parent = flyJoystickKnob

    -- Wall Climb Button
    wallClimbButton = Instance.new("TextButton")
    wallClimbButton.Name = "WallClimbButton"
    wallClimbButton.Size = UDim2.new(0, 70, 0, 70)
    wallClimbButton.Position = UDim2.new(0.82, -35, 0.65, 0)
    wallClimbButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    wallClimbButton.BackgroundTransparency = 0.5
    wallClimbButton.BorderSizePixel = 0
    wallClimbButton.Text = "Climb"
    wallClimbButton.Font = Enum.Font.GothamBold
    wallClimbButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    wallClimbButton.TextSize = 14
    wallClimbButton.Visible = false
    wallClimbButton.Parent = ScreenGui

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0.2, 0)
    buttonCorner.Parent = wallClimbButton

    -- Fly Up Button
    flyUpButton = Instance.new("TextButton")
    flyUpButton.Name = "FlyUpButton"
    flyUpButton.Size = UDim2.new(0, 60, 0, 60)
    flyUpButton.Position = UDim2.new(0.82, -30, 0.45, 0)
    flyUpButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    flyUpButton.BackgroundTransparency = 0.5
    flyUpButton.BorderSizePixel = 0
    flyUpButton.Text = "▲"
    flyUpButton.Font = Enum.Font.GothamBold
    flyUpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    flyUpButton.TextSize = 20
    flyUpButton.Visible = false
    flyUpButton.Parent = ScreenGui

    local upCorner = Instance.new("UICorner")
    upCorner.CornerRadius = UDim.new(0.3, 0)
    upCorner.Parent = flyUpButton

    -- Fly Down Button
    flyDownButton = Instance.new("TextButton")
    flyDownButton.Name = "FlyDownButton"
    flyDownButton.Size = UDim2.new(0, 60, 0, 60)
    flyDownButton.Position = UDim2.new(0.82, -30, 0.55, 0)
    flyDownButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    flyDownButton.BackgroundTransparency = 0.5
    flyDownButton.BorderSizePixel = 0
    flyDownButton.Text = "▼"
    flyDownButton.Font = Enum.Font.GothamBold
    flyDownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    flyDownButton.TextSize = 20
    flyDownButton.Visible = false
    flyDownButton.Parent = ScreenGui

    local downCorner = Instance.new("UICorner")
    downCorner.CornerRadius = UDim.new(0.3, 0)
    downCorner.Parent = flyDownButton

    print("Mobile controls created successfully")
end

-- Handle fly joystick input with better touch tracking
local function handleFlyJoystick(input, gameProcessed)
    if not Movement.flyEnabled or not flyJoystickFrame or not flyJoystickFrame.Visible then 
        return 
    end
    
    if input.UserInputType == Enum.UserInputType.Touch then
        local joystickCenter = flyJoystickFrame.AbsolutePosition + flyJoystickFrame.AbsoluteSize * 0.5
        local inputPos = Vector2.new(input.Position.X, input.Position.Y)
        local distanceFromCenter = (inputPos - joystickCenter).Magnitude
        
        if input.UserInputState == Enum.UserInputState.Begin then
            -- Check if touch is within joystick area
            if distanceFromCenter <= 60 and not isTouchingJoystick then
                isTouchingJoystick = true
                joystickTouchId = input
                print("Started touching joystick")
            end
        elseif input.UserInputState == Enum.UserInputState.Change and isTouchingJoystick and input == joystickTouchId then
            local delta = inputPos - joystickCenter
            local magnitude = delta.Magnitude
            local maxRadius = 35
            
            if magnitude > maxRadius then
                delta = delta * (maxRadius / magnitude)
            end
            
            flyJoystickKnob.Position = UDim2.new(0.5, delta.X - 25, 0.5, delta.Y - 25)
            joystickDelta = delta / maxRadius
            print("Joystick delta:", joystickDelta)
            
        elseif input.UserInputState == Enum.UserInputState.End and input == joystickTouchId then
            isTouchingJoystick = false
            joystickTouchId = nil
            flyJoystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
            joystickDelta = Vector2.new(0, 0)
            print("Stopped touching joystick")
        end
    end
end

-- Speed Hack with respawn fix
local function toggleSpeed(enabled)
    Movement.speedEnabled = enabled
    print("Speed:", enabled, "Humanoid:", humanoid ~= nil)
    
    -- Get fresh references if needed
    if not humanoid and player.Character then
        humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    end
    
    if humanoid then
        if enabled then
            humanoid.WalkSpeed = settings.WalkSpeed and settings.WalkSpeed.value or 50
        else
            humanoid.WalkSpeed = Movement.defaultWalkSpeed
        end
    else
        warn("No humanoid found for speed hack")
    end
end

-- Jump Hack with respawn fix
local function toggleJump(enabled)
    Movement.jumpEnabled = enabled
    print("Jump:", enabled, "Humanoid:", humanoid ~= nil)
    
    -- Get fresh references if needed
    if not humanoid and player.Character then
        humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    end
    
    if humanoid then
        if enabled then
            if humanoid:FindFirstChild("JumpHeight") then
                humanoid.JumpHeight = settings.JumpHeight and settings.JumpHeight.value or 50
            else
                humanoid.JumpPower = (settings.JumpHeight and settings.JumpHeight.value * 2.4) or 150
            end
        else
            if humanoid:FindFirstChild("JumpHeight") then
                humanoid.JumpHeight = Movement.defaultJumpHeight
            else
                humanoid.JumpPower = Movement.defaultJumpPower
            end
        end
    else
        warn("No humanoid found for jump hack")
    end
end

-- Moon Gravity
local function toggleMoonGravity(enabled)
    Movement.moonGravityEnabled = enabled
    print("Moon Gravity:", enabled)
    if enabled then
        Workspace.Gravity = Movement.defaultGravity / 6
    else
        Workspace.Gravity = Movement.defaultGravity
    end
end

-- Double Jump with better respawn handling
local function toggleDoubleJump(enabled)
    Movement.doubleJumpEnabled = enabled
    print("Double Jump:", enabled)
    
    -- Disconnect old connection
    if connections.doubleJump then
        connections.doubleJump:Disconnect()
        connections.doubleJump = nil
    end
    
    if enabled then
        connections.doubleJump = UserInputService.JumpRequest:Connect(function()
            -- Get fresh humanoid reference
            if not humanoid and player.Character then
                humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            end
            
            if not humanoid or not Movement.doubleJumpEnabled then return end
            
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

-- Infinite Jump with better respawn handling
local function toggleInfiniteJump(enabled)
    Movement.infiniteJumpEnabled = enabled
    print("Infinite Jump:", enabled)
    
    -- Disconnect old connection
    if connections.infiniteJump then
        connections.infiniteJump:Disconnect()
        connections.infiniteJump = nil
    end
    
    if enabled then
        connections.infiniteJump = UserInputService.JumpRequest:Connect(function()
            -- Get fresh humanoid reference
            if not humanoid and player.Character then
                humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            end
            
            if not humanoid or not Movement.infiniteJumpEnabled then return end
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end

-- Wall Climbing with better respawn handling
local function toggleWallClimb(enabled)
    Movement.wallClimbEnabled = enabled
    print("Wall Climb:", enabled, "RootPart:", rootPart ~= nil)
    
    -- Disconnect old connections
    if connections.wallClimb then
        connections.wallClimb:Disconnect()
        connections.wallClimb = nil
    end
    if connections.wallClimbInput then
        connections.wallClimbInput:Disconnect()
        connections.wallClimbInput = nil
    end
    
    -- Get fresh references if needed
    if not rootPart and player.Character then
        rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    end
    if not humanoid and player.Character then
        humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    end
    
    if enabled and rootPart and wallClimbButton then
        wallClimbButton.Visible = true
        
        connections.wallClimb = RunService.Heartbeat:Connect(function()
            -- Refresh references if character changed
            if not humanoid and player.Character then
                humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            end
            if not rootPart and player.Character then
                rootPart = player.Character:FindFirstChild("HumanoidRootPart")
            end
            
            if not humanoid or not rootPart or not Movement.wallClimbEnabled then return end
            
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

-- Improved Fly Hack with 3D movement
local function toggleFly(enabled)
    Movement.flyEnabled = enabled
    print("Fly:", enabled, "RootPart:", rootPart ~= nil)
    
    -- Disconnect old connections
    local flyConnections = {"fly", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", "flyDown", "flyDownEnd"}
    for _, connName in ipairs(flyConnections) do
        if connections[connName] then
            connections[connName]:Disconnect()
            connections[connName] = nil
        end
    end
    
    -- Get fresh references if needed
    if not rootPart and player.Character then
        rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    end
    
    if enabled and rootPart then
        -- Clean up old BodyVelocity
        if flyBodyVelocity then
            flyBodyVelocity:Destroy()
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
        
        -- Main fly loop with improved 3D movement
        connections.fly = RunService.Heartbeat:Connect(function()
            -- Refresh references if character changed
            if not rootPart and player.Character then
                rootPart = player.Character:FindFirstChild("HumanoidRootPart")
                if rootPart and flyBodyVelocity then
                    flyBodyVelocity.Parent = rootPart
                end
            end
            
            if not rootPart or not Movement.flyEnabled or not flyBodyVelocity or flyBodyVelocity.Parent ~= rootPart then 
                return 
            end
            
            local camera = Workspace.CurrentCamera
            if not camera then return end
            
            local flyDirection = Vector3.new(0, 0, 0)
            flySpeed = settings.FlySpeed and settings.FlySpeed.value or 50
            
            -- Horizontal movement from joystick
            if joystickDelta.Magnitude > 0.1 then
                local forward = camera.CFrame.LookVector
                local right = camera.CFrame.RightVector
                
                flyDirection = flyDirection + (right * joystickDelta.X) + (forward * -joystickDelta.Y)
            end
            
            -- Vertical movement from buttons
            if flyVerticalInput ~= 0 then
                flyDirection = flyDirection + Vector3.new(0, flyVerticalInput, 0)
            end
            
            -- Apply movement
            flyBodyVelocity.Velocity = flyDirection.Unit * flySpeed * math.min(flyDirection.Magnitude, 1)
        end)
        
        -- Touch input handling
        connections.flyInput = UserInputService.InputChanged:Connect(function(input, processed)
            if not processed then
                handleFlyJoystick(input, processed)
            end
        end)
        
        connections.flyBegan = UserInputService.InputBegan:Connect(function(input, processed)
            if not processed then
                handleFlyJoystick(input, processed)
            end
        end)
        
        connections.flyEnded = UserInputService.InputEnded:Connect(function(input, processed)
            if not processed then
                handleFlyJoystick(input, processed)
            end
        end)
        
        -- Up/Down button connections
        if flyUpButton then
            connections.flyUp = flyUpButton.MouseButton1Down:Connect(function()
                flyVerticalInput = 1
                flyUpButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            end)
            connections.flyUpEnd = flyUpButton.MouseButton1Up:Connect(function()
                flyVerticalInput = 0
                flyUpButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            end)
        end
        
        if flyDownButton then
            connections.flyDown = flyDownButton.MouseButton1Down:Connect(function()
                flyVerticalInput = -1
                flyDownButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            end)
            connections.flyDownEnd = flyDownButton.MouseButton1Up:Connect(function()
                flyVerticalInput = 0
                flyDownButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            end)
        end
        
        print("Fly enabled with 3D movement")
    else
        -- Disable fly
        if flyBodyVelocity then
            flyBodyVelocity:Destroy()
            flyBodyVelocity = nil
        end
        
        -- Hide fly controls
        if flyJoystickFrame then 
            flyJoystickFrame.Visible = false
            flyJoystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
        end
        if flyUpButton then 
            flyUpButton.Visible = false
            flyUpButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
        if flyDownButton then 
            flyDownButton.Visible = false
            flyDownButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
        
        -- Reset fly variables
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
    print("NoClip:", enabled)
    
    -- Disconnect old connection
    if connections.noclip then
        connections.noclip:Disconnect()
        connections.noclip = nil
    end
    
    if enabled then
        connections.noclip = RunService.Stepped:Connect(function()
            -- Refresh character reference
            if not player.Character then
                player.Character = Players.LocalPlayer.Character
            end
            
            if not player.Character or not Movement.noclipEnabled then return end
            
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    else
        -- Re-enable collision
        if player.Character then
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
    print("Walk on Water:", enabled, "RootPart:", rootPart ~= nil)
    
    -- Disconnect old connection
    if connections.walkOnWater then
        connections.walkOnWater:Disconnect()
        connections.walkOnWater = nil
    end
    
    if enabled then
        connections.walkOnWater = RunService.Heartbeat:Connect(function()
            -- Refresh rootPart reference
            if not rootPart and player.Character then
                rootPart = player.Character:FindFirstChild("HumanoidRootPart")
            end
            
            if not rootPart or not Movement.walkOnWaterEnabled then return end
            
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
    else
        -- Clean up water walk parts
        if rootPart and rootPart:FindFirstChild("WaterWalkPart") then
            rootPart.WaterWalkPart:Destroy()
        end
    end
end

-- Player NoClip - Pass through other players without physics
local function togglePlayerNoclip(enabled)
    Movement.playerNoclipEnabled = enabled
    print("Player NoClip:", enabled)
    
    -- Disconnect old connection
    if connections.playerNoclip then
        connections.playerNoclip:Disconnect()
        connections.playerNoclip = nil
    end
    
    if enabled then
        connections.playerNoclip = RunService.Heartbeat:Connect(function()
            -- Refresh character reference
            if not player.Character then
                player.Character = Players.LocalPlayer.Character
            end
            
            if not player.Character or not Movement.playerNoclipEnabled then return end
            
            -- Make all player parts non-collidable with other players
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
        -- Re-enable collision for all other players
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
local function toggleSwim(enabled)
    Movement.swimEnabled = enabled
    print("Super Swim:", enabled, "Humanoid:", humanoid ~= nil)
    
    -- Get fresh humanoid reference
    if not humanoid and player.Character then
        humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    end
    
    if humanoid then
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
    else
        warn("No humanoid found for super swim")
    end
end

-- Function to create buttons for Movement features
function Movement.loadMovementButtons(createButton, createToggleButton)
    print("Loading movement buttons")
    if not createButton or not createToggleButton then
        warn("Error: createButton or createToggleButton not provided! Buttons will not be created.")
        print("Debug: createButton =", createButton, "createToggleButton =", createToggleButton)
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

-- Function to reset Movement states
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
    Movement.jumpCount = 0
    flyVerticalInput = 0
    joystickDelta = Vector2.new(0, 0)
    isTouchingJoystick = false
    joystickTouchId = nil
    
    local movementConnections = {"fly", "noclip", "playerNoclip", "infiniteJump", "walkOnWater", "doubleJump", "wallClimb", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", "flyDown", "flyDownEnd", "wallClimbInput"}
    for _, connName in ipairs(movementConnections) do
        if connections[connName] then
            print("Disconnecting:", connName)
            connections[connName]:Disconnect()
            connections[connName] = nil
        end
    end
    
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    
    if humanoid then
        humanoid.WalkSpeed = Movement.defaultWalkSpeed
        if humanoid:FindFirstChild("JumpHeight") then
            humanoid.JumpHeight = Movement.defaultJumpHeight
        else
            humanoid.JumpPower = Movement.defaultJumpPower
        end
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
            humanoid.WalkSpeed = Movement.defaultWalkSpeed
        end)
    end
    
    Workspace.Gravity = Movement.defaultGravity
    
    if rootPart then
        if rootPart:FindFirstChild("WaterWalkPart") then
            rootPart.WaterWalkPart:Destroy()
        end
    end
    
    if flyJoystickFrame then
        flyJoystickFrame.Visible = false
        flyJoystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
    end
    if wallClimbButton then
        wallClimbButton.Visible = false
        wallClimbButton.Text = "Climb"
    end
    if flyUpButton then
        flyUpButton.Visible = false
        flyUpButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end
    if flyDownButton then
        flyDownButton.Visible = false
        flyDownButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end
end

-- Function to update references when character respawns
function Movement.updateReferences(newHumanoid, newRootPart)
    print("Updating Movement references: Humanoid =", newHumanoid ~= nil, "RootPart =", newRootPart ~= nil)
    humanoid = newHumanoid
    rootPart = newRootPart
    
    if humanoid then
        Movement.defaultWalkSpeed = humanoid.WalkSpeed or 16
        if humanoid:FindFirstChild("JumpHeight") then
            Movement.defaultJumpHeight = humanoid.JumpHeight or 7.2
        else
            Movement.defaultJumpPower = humanoid.JumpPower or 50
        end
        Movementlocal isTouchingJoystick = false
local joystickTouchId = nil

-- Create virtual controls
local function createMobileControls()
    print("Creating mobile controls")
    
    -- Clean up existing controls
    if flyJoystickFrame then flyJoystickFrame:Destroy() end
    if wallClimbButton then wallClimbButton:Destroy() end
    if flyUpButton then flyUpButton:Destroy() end
    if flyDownButton then flyDownButton:Destroy() end

    -- Fly Joystick
    flyJoystickFrame = Instance.new("Frame")
    flyJoystickFrame.Name = "FlyJoystick"
    flyJoystickFrame.Size = UDim2.new(0, 120, 0, 120)
    flyJoystickFrame.Position = UDim2.new(0.05, 0, 0.65, 0)
    flyJoystickFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    flyJoystickFrame.BackgroundTransparency = 0.6
    flyJoystickFrame.BorderSizePixel = 0
    flyJoystickFrame.Visible = false
    flyJoystickFrame.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = flyJoystickFrame

    flyJoystickKnob = Instance.new("Frame")
    flyJoystickKnob.Name = "Knob"
    flyJoystickKnob.Size = UDim2.new(0, 50, 0, 50)
    flyJoystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
    flyJoystickKnob.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    flyJoystickKnob.BackgroundTransparency = 0.2
    flyJoystickKnob.BorderSizePixel = 0
    flyJoystickKnob.Parent = flyJoystickFrame

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0.5, 0)
    knobCorner.Parent = flyJoystickKnob

    -- Wall Climb Button
    wallClimbButton = Instance.new("TextButton")
    wallClimbButton.Name = "WallClimbButton"
    wallClimbButton.Size = UDim2.new(0, 70, 0, 70)
    wallClimbButton.Position = UDim2.new(0.82, -35, 0.65, 0)
    wallClimbButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    wallClimbButton.BackgroundTransparency = 0.5
    wallClimbButton.BorderSizePixel = 0
    wallClimbButton.Text = "Climb"
    wallClimbButton.Font = Enum.Font.GothamBold
    wallClimbButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    wallClimbButton.TextSize = 14
    wallClimbButton.Visible = false
    wallClimbButton.Parent = ScreenGui

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0.2, 0)
    buttonCorner.Parent = wallClimbButton

    -- Fly Up Button
    flyUpButton = Instance.new("TextButton")
    flyUpButton.Name = "FlyUpButton"
    flyUpButton.Size = UDim2.new(0, 60, 0, 60)
    flyUpButton.Position = UDim2.new(0.82, -30, 0.45, 0)
    flyUpButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    flyUpButton.BackgroundTransparency = 0.5
    flyUpButton.BorderSizePixel = 0
    flyUpButton.Text = "▲"
    flyUpButton.Font = Enum.Font.GothamBold
    flyUpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    flyUpButton.TextSize = 20
    flyUpButton.Visible = false
    flyUpButton.Parent = ScreenGui

    local upCorner = Instance.new("UICorner")
    upCorner.CornerRadius = UDim.new(0.3, 0)
    upCorner.Parent = flyUpButton

    -- Fly Down Button
    flyDownButton = Instance.new("TextButton")
    flyDownButton.Name = "FlyDownButton"
    flyDownButton.Size = UDim2.new(0, 60, 0, 60)
    flyDownButton.Position = UDim2.new(0.82, -30, 0.55, 0)
    flyDownButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    flyDownButton.BackgroundTransparency = 0.5
    flyDownButton.BorderSizePixel = 0
    flyDownButton.Text = "▼"
    flyDownButton.Font = Enum.Font.GothamBold
    flyDownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    flyDownButton.TextSize = 20
    flyDownButton.Visible = false
    flyDownButton.Parent = ScreenGui

    local downCorner = Instance.new("UICorner")
    downCorner.CornerRadius = UDim.new(0.3, 0)
    downCorner.Parent = flyDownButton

    print("Mobile controls created successfully")
end

-- Handle fly joystick input with better touch tracking
local function handleFlyJoystick(input, gameProcessed)
    if not Movement.flyEnabled or not flyJoystickFrame or not flyJoystickFrame.Visible then 
        return 
    end
    
    if input.UserInputType == Enum.UserInputType.Touch then
        local joystickCenter = flyJoystickFrame.AbsolutePosition + flyJoystickFrame.AbsoluteSize * 0.5
        local inputPos = Vector2.new(input.Position.X, input.Position.Y)
        local distanceFromCenter = (inputPos - joystickCenter).Magnitude
        
        if input.UserInputState == Enum.UserInputState.Begin then
            -- Check if touch is within joystick area
            if distanceFromCenter <= 60 and not isTouchingJoystick then
                isTouchingJoystick = true
                joystickTouchId = input
                print("Started touching joystick")
            end
        elseif input.UserInputState == Enum.UserInputState.Change and isTouchingJoystick and input == joystickTouchId then
            local delta = inputPos - joystickCenter
            local magnitude = delta.Magnitude
            local maxRadius = 35
            
            if magnitude > maxRadius then
                delta = delta * (maxRadius / magnitude)
            end
            
            flyJoystickKnob.Position = UDim2.new(0.5, delta.X - 25, 0.5, delta.Y - 25)
            joystickDelta = delta / maxRadius
            print("Joystick delta:", joystickDelta)
            
        elseif input.UserInputState == Enum.UserInputState.End and input == joystickTouchId then
            isTouchingJoystick = false
            joystickTouchId = nil
            flyJoystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
            joystickDelta = Vector2.new(0, 0)
            print("Stopped touching joystick")
        end
    end
end

-- Speed Hack with respawn fix
local function toggleSpeed(enabled)
    Movement.speedEnabled = enabled
    print("Speed:", enabled, "Humanoid:", humanoid ~= nil)
    
    -- Get fresh references if needed
    if not humanoid and player.Character then
        humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    end
    
    if humanoid then
        if enabled then
            humanoid.WalkSpeed = settings.WalkSpeed and settings.WalkSpeed.value or 50
        else
            humanoid.WalkSpeed = Movement.defaultWalkSpeed
        end
    else
        warn("No humanoid found for speed hack")
    end
end

-- Jump Hack with respawn fix
local function toggleJump(enabled)
    Movement.jumpEnabled = enabled
    print("Jump:", enabled, "Humanoid:", humanoid ~= nil)
    
    -- Get fresh references if needed
    if not humanoid and player.Character then
        humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    end
    
    if humanoid then
        if enabled then
            if humanoid:FindFirstChild("JumpHeight") then
                humanoid.JumpHeight = settings.JumpHeight and settings.JumpHeight.value or 50
            else
                humanoid.JumpPower = (settings.JumpHeight and settings.JumpHeight.value * 2.4) or 150
            end
        else
            if humanoid:FindFirstChild("JumpHeight") then
                humanoid.JumpHeight = Movement.defaultJumpHeight
            else
                humanoid.JumpPower = Movement.defaultJumpPower
            end
        end
    else
        warn("No humanoid found for jump hack")
    end
end

-- Moon Gravity
local function toggleMoonGravity(enabled)
    Movement.moonGravityEnabled = enabled
    print("Moon Gravity:", enabled)
    if enabled then
        Workspace.Gravity = Movement.defaultGravity / 6
    else
        Workspace.Gravity = Movement.defaultGravity
    end
end

-- Double Jump with better respawn handling
local function toggleDoubleJump(enabled)
    Movement.doubleJumpEnabled = enabled
    print("Double Jump:", enabled)
    
    -- Disconnect old connection
    if connections.doubleJump then
        connections.doubleJump:Disconnect()
        connections.doubleJump = nil
    end
    
    if enabled then
        connections.doubleJump = UserInputService.JumpRequest:Connect(function()
            -- Get fresh humanoid reference
            if not humanoid and player.Character then
                humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            end
            
            if not humanoid or not Movement.doubleJumpEnabled then return end
            
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

-- Infinite Jump with better respawn handling
local function toggleInfiniteJump(enabled)
    Movement.infiniteJumpEnabled = enabled
    print("Infinite Jump:", enabled)
    
    -- Disconnect old connection
    if connections.infiniteJump then
        connections.infiniteJump:Disconnect()
        connections.infiniteJump = nil
    end
    
    if enabled then
        connections.infiniteJump = UserInputService.JumpRequest:Connect(function()
            -- Get fresh humanoid reference
            if not humanoid and player.Character then
                humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            end
            
            if not humanoid or not Movement.infiniteJumpEnabled then return end
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end

-- Wall Climbing with better respawn handling
local function toggleWallClimb(enabled)
    Movement.wallClimbEnabled = enabled
    print("Wall Climb:", enabled, "RootPart:", rootPart ~= nil)
    
    -- Disconnect old connections
    if connections.wallClimb then
        connections.wallClimb:Disconnect()
        connections.wallClimb = nil
    end
    if connections.wallClimbInput then
        connections.wallClimbInput:Disconnect()
        connections.wallClimbInput = nil
    end
    
    -- Get fresh references if needed
    if not rootPart and player.Character then
        rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    end
    if not humanoid and player.Character then
        humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    end
    
    if enabled and rootPart and wallClimbButton then
        wallClimbButton.Visible = true
        
        connections.wallClimb = RunService.Heartbeat:Connect(function()
            -- Refresh references if character changed
            if not humanoid and player.Character then
                humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            end
            if not rootPart and player.Character then
                rootPart = player.Character:FindFirstChild("HumanoidRootPart")
            end
            
            if not humanoid or not rootPart or not Movement.wallClimbEnabled then return end
            
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

-- Improved Fly Hack with 3D movement
local function toggleFly(enabled)
    Movement.flyEnabled = enabled
    print("Fly:", enabled, "RootPart:", rootPart ~= nil)
    
    -- Disconnect old connections
    local flyConnections = {"fly", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", "flyDown", "flyDownEnd"}
    for _, connName in ipairs(flyConnections) do
        if connections[connName] then
            connections[connName]:Disconnect()
            connections[connName] = nil
        end
    end
    
    -- Get fresh references if needed
    if not rootPart and player.Character then
        rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    end
    
    if enabled and rootPart then
        -- Clean up old BodyVelocity
        if flyBodyVelocity then
            flyBodyVelocity:Destroy()
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
        
        -- Main fly loop with improved 3D movement
        connections.fly = RunService.Heartbeat:Connect(function()
            -- Refresh references if character changed
            if not rootPart and player.Character then
                rootPart = player.Character:FindFirstChild("HumanoidRootPart")
                if rootPart and flyBodyVelocity then
                    flyBodyVelocity.Parent = rootPart
                end
            end
            
            if not rootPart or not Movement.flyEnabled or not flyBodyVelocity or flyBodyVelocity.Parent ~= rootPart then 
                return 
            end
            
            local camera = Workspace.CurrentCamera
            if not camera then return end
            
            local flyDirection = Vector3.new(0, 0, 0)
            flySpeed = settings.FlySpeed and settings.FlySpeed.value or 50
            
            -- Horizontal movement from joystick
            if joystickDelta.Magnitude > 0.1 then
                local forward = camera.CFrame.LookVector
                local right = camera.CFrame.RightVector
                
                flyDirection = flyDirection + (right * joystickDelta.X) + (forward * -joystickDelta.Y)
            end
            
            -- Vertical movement from buttons
            if flyVerticalInput ~= 0 then
                flyDirection = flyDirection + Vector3.new(0, flyVerticalInput, 0)
            end
            
            -- Apply movement
            flyBodyVelocity.Velocity = flyDirection.Unit * flySpeed * math.min(flyDirection.Magnitude, 1)
        end)
        
        -- Touch input handling
        connections.flyInput = UserInputService.InputChanged:Connect(function(input, processed)
            if not processed then
                handleFlyJoystick(input, processed)
            end
        end)
        
        connections.flyBegan = UserInputService.InputBegan:Connect(function(input, processed)
            if not processed then
                handleFlyJoystick(input, processed)
            end
        end)
        
        connections.flyEnded = UserInputService.InputEnded:Connect(function(input, processed)
            if not processed then
                handleFlyJoystick(input, processed)
            end
        end)
        
        -- Up/Down button connections
        if flyUpButton then
            connections.flyUp = flyUpButton.MouseButton1Down:Connect(function()
                flyVerticalInput = 1
                flyUpButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            end)
            connections.flyUpEnd = flyUpButton.MouseButton1Up:Connect(function()
                flyVerticalInput = 0
                flyUpButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            end)
        end
        
        if flyDownButton then
            connections.flyDown = flyDownButton.MouseButton1Down:Connect(function()
                flyVerticalInput = -1
                flyDownButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            end)
            connections.flyDownEnd = flyDownButton.MouseButton1Up:Connect(function()
                flyVerticalInput = 0
                flyDownButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            end)
        end
        
        print("Fly enabled with 3D movement")
    else
        -- Disable fly
        if flyBodyVelocity then
            flyBodyVelocity:Destroy()
            flyBodyVelocity = nil
        end
        
        -- Hide fly controls
        if flyJoystickFrame then 
            flyJoystickFrame.Visible = false
            flyJoystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
        end
        if flyUpButton then 
            flyUpButton.Visible = false
            flyUpButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
        if flyDownButton then 
            flyDownButton.Visible = false
            flyDownButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
        
        -- Reset fly variables
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
    print("NoClip:", enabled)
    
    -- Disconnect old connection
    if connections.noclip then
        connections.noclip:Disconnect()
        connections.noclip = nil
    end
    
    if enabled then
        connections.noclip = RunService.Stepped:Connect(function()
            -- Refresh character reference
            if not player.Character then
                player.Character = Players.LocalPlayer.Character
            end
            
            if not player.Character or not Movement.noclipEnabled then return end
            
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    else
        -- Re-enable collision
        if player.Character then
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
    print("Walk on Water:", enabled, "RootPart:", rootPart ~= nil)
    
    -- Disconnect old connection
    if connections.walkOnWater then
        connections.walkOnWater:Disconnect()
        connections.walkOnWater = nil
    end
    
    if enabled then
        connections.walkOnWater = RunService.Heartbeat:Connect(function()
            -- Refresh rootPart reference
            if not rootPart and player.Character then
                rootPart = player.Character:FindFirstChild("HumanoidRootPart")
            end
            
            if not rootPart or not Movement.walkOnWaterEnabled then return end
            
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
    else
        -- Clean up water walk parts
        if rootPart and rootPart:FindFirstChild("WaterWalkPart") then
            rootPart.WaterWalkPart:Destroy()
        end
    end
end

-- Super Swim with better respawn handling
local function toggleSwim(enabled)
    Movement.swimEnabled = enabled
    print("Super Swim:", enabled, "Humanoid:", humanoid ~= nil)
    
    -- Get fresh humanoid reference
    if not humanoid and player.Character then
        humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    end
    
    if humanoid then
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
    else
        warn("No humanoid found for super swim")
    end
end

-- Function to create buttons for Movement features
function Movement.loadMovementButtons(createButton, createToggleButton)
    print("Loading movement buttons")
    if not createButton or not createToggleButton then
        warn("Error: createButton or createToggleButton not provided! Buttons will not be created.")
        print("Debug: createButton =", createButton, "createToggleButton =", createToggleButton)
        return
    end
    
    createToggleButton("Speed Hack", toggleSpeed)
    createToggleButton("Jump Hack", toggleJump)
    createToggleButton("Moon Gravity", toggleMoonGravity)
    createToggleButton("Double Jump", toggleDoubleJump)
    createToggleButton("Infinite Jump", toggleInfiniteJump)
    createToggleButton("Wall Climb", toggleWallClimb)
    createToggleButton("Fly", toggleFly)
    createToggleButton("NoClip", toggleNoclip)
    createToggleButton("Walk on Water", toggleWalkOnWater)
    createToggleButton("Super Swim", toggleSwim)
end

-- Function to reset Movement states
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
    Movement.jumpCount = 0
    flyVerticalInput = 0
    joystickDelta = Vector2.new(0, 0)
    isTouchingJoystick = false
    joystickTouchId = nil
    
    local movementConnections = {"fly", "noclip", "infiniteJump", "walkOnWater", "doubleJump", "wallClimb", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", "flyDown", "flyDownEnd", "wallClimbInput"}
    for _, connName in ipairs(movementConnections) do
        if connections[connName] then
            print("Disconnecting:", connName)
            connections[connName]:Disconnect()
            connections[connName] = nil
        end
    end
    
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    
    if humanoid then
        humanoid.WalkSpeed = Movement.defaultWalkSpeed
        if humanoid:FindFirstChild("JumpHeight") then
            humanoid.JumpHeight = Movement.defaultJumpHeight
        else
            humanoid.JumpPower = Movement.defaultJumpPower
        end
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
            humanoid.WalkSpeed = Movement.defaultWalkSpeed
        end)
    end
    
    Workspace.Gravity = Movement.defaultGravity
    
    if rootPart then
        if rootPart:FindFirstChild("WaterWalkPart") then
            rootPart.WaterWalkPart:Destroy()
        end
    end
    
    if flyJoystickFrame then
        flyJoystickFrame.Visible = false
        flyJoystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
    end
    if wallClimbButton then
        wallClimbButton.Visible = false
        wallClimbButton.Text = "Climb"
    end
    if flyUpButton then
        flyUpButton.Visible = false
        flyUpButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end
    if flyDownButton then
        flyDownButton.Visible = false
        flyDownButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end
end

-- Function to update references when character respawns
function Movement.updateReferences(newHumanoid, newRootPart)
    print("Updating Movement references: Humanoid =", newHumanoid ~= nil, "RootPart =", newRootPart ~= nil)
    humanoid = newHumanoid
    rootPart = newRootPart
    
    if humanoid then
        Movement.defaultWalkSpeed = humanoid.WalkSpeed or 16
        if humanoid:FindFirstChild("JumpHeight") then
            Movement.defaultJumpHeight = humanoid.JumpHeight or 7.2
        else
            Movement.defaultJumpPower = humanoid.JumpPower or 50
        end
        Movement    if wallClimbButton then wallClimbButton:Destroy() end

    flyJoystickFrame = Instance.new("Frame")
    flyJoystickFrame.Name = "FlyJoystick"
    flyJoystickFrame.Size = UDim2.new(0, 100, 0, 100)
    flyJoystickFrame.Position = UDim2.new(0.1, 0, 0.7, 0)
    flyJoystickFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    flyJoystickFrame.BackgroundTransparency = 0.5
    flyJoystickFrame.BorderSizePixel = 0
    flyJoystickFrame.Visible = false
    flyJoystickFrame.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = flyJoystickFrame

    flyJoystickKnob = Instance.new("Frame")
    flyJoystickKnob.Name = "Knob"
    flyJoystickKnob.Size = UDim2.new(0, 40, 0, 40)
    flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
    flyJoystickKnob.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    flyJoystickKnob.BackgroundTransparency = 0.3
    flyJoystickKnob.BorderSizePixel = 0
    flyJoystickKnob.Parent = flyJoystickFrame

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0.5, 0)
    knobCorner.Parent = flyJoystickKnob

    wallClimbButton = Instance.new("TextButton")
    wallClimbButton.Name = "WallClimbButton"
    wallClimbButton.Size = UDim2.new(0, 60, 0, 60)
    wallClimbButton.Position = UDim2.new(0.85, -30, 0.7, 0)
    wallClimbButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    wallClimbButton.BackgroundTransparency = 0.5
    wallClimbButton.BorderSizePixel = 0
    wallClimbButton.Text = "Climb"
    wallClimbButton.Font = Enum.Font.Gotham
    wallClimbButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    wallClimbButton.TextSize = 7
    wallClimbButton.Visible = false
    wallClimbButton.Parent = ScreenGui

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0.2, 0)
    buttonCorner.Parent = wallClimbButton
end

-- Handle fly joystick input
local function handleFlyJoystick(input)
    if not Movement.flyEnabled or not flyJoystickFrame or not flyJoystickFrame.Visible then return Vector2.new(0, 0) end
    if input.UserInputType == Enum.UserInputType.Touch then
        if input.UserInputState == Enum.UserInputState.Begin then
            flyJoystickFrame.Visible = true
            flyJoystickFrame.Position = UDim2.new(0, input.Position.X - 50, 0, input.Position.Y - 50)
        elseif input.UserInputState == Enum.UserInputState.Change then
            local center = flyJoystickFrame.AbsolutePosition + flyJoystickFrame.AbsoluteSize * 0.5
            local delta = Vector2.new(input.Position.X - center.X, input.Position.Y - center.Y)
            local magnitude = delta.Magnitude
            local maxRadius = 30
            if magnitude > maxRadius then
                delta = delta * (maxRadius / magnitude)
            end
            flyJoystickKnob.Position = UDim2.new(0.5, delta.X - 20, 0.5, delta.Y - 20)
            return delta / maxRadius
        elseif input.UserInputState == Enum.UserInputState.End then
            flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
            flyJoystickFrame.Visible = false
            return Vector2.new(0, 0)
        end
    end
    return Vector2.new(0, 0)
end

-- Speed Hack
local function toggleSpeed(enabled)
    Movement.speedEnabled = enabled
    print("Speed:", enabled, "Humanoid:", humanoid ~= nil)
    if not humanoid then
        humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    end
    if humanoid and enabled then
        humanoid.WalkSpeed = settings.WalkSpeed and settings.WalkSpeed.value or 50
    elseif humanoid then
        humanoid.WalkSpeed = Movement.defaultWalkSpeed
    end
end

-- Jump Hack
local function toggleJump(enabled)
    Movement.jumpEnabled = enabled
    print("Jump:", enabled, "Humanoid:", humanoid ~= nil)
    if not humanoid then
        humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    end
    if humanoid and enabled then
        if humanoid:FindFirstChild("JumpHeight") then
            humanoid.JumpHeight = settings.JumpHeight and settings.JumpHeight.value or 50
        else
            humanoid.JumpPower = (settings.JumpHeight and settings.JumpHeight.value * 2.4) or 150
        end
    elseif humanoid then
        if humanoid:FindFirstChild("JumpHeight") then
            humanoid.JumpHeight = Movement.defaultJumpHeight
        else
            humanoid.JumpPower = Movement.defaultJumpPower
        end
    end
end

-- Moon Gravity
local function toggleMoonGravity(enabled)
    Movement.moonGravityEnabled = enabled
    print("Moon Gravity:", enabled)
    if enabled then
        Workspace.Gravity = Movement.defaultGravity / 6
    else
        Workspace.Gravity = Movement.defaultGravity
    end
end

-- Double Jump
local function toggleDoubleJump(enabled)
    Movement.doubleJumpEnabled = enabled
    print("Double Jump:", enabled)
    if enabled then
        connections.doubleJump = UserInputService.JumpRequest:Connect(function()
            if not humanoid or not Movement.doubleJumpEnabled then return end
            if humanoid:GetState() ~= Enum.HumanoidStateType.Jumping and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
                Movement.jumpCount = 0
            elseif Movement.jumpCount < Movement.maxJumps then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                Movement.jumpCount = Movement.jumpCount + 1
            end
        end)
    else
        if connections.doubleJump then
            connections.doubleJump:Disconnect()
            connections.doubleJump = nil
        end
        Movement.jumpCount = 0
    end
end

-- Infinite Jump
local function toggleInfiniteJump(enabled)
    Movement.infiniteJumpEnabled = enabled
    print("Infinite Jump:", enabled)
    if enabled then
        connections.infiniteJump = UserInputService.JumpRequest:Connect(function()
            if not humanoid or not Movement.infiniteJumpEnabled then return end
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    else
        if connections.infiniteJump then
            connections.infiniteJump:Disconnect()
            connections.infiniteJump = nil
        end
    end
end

-- Wall Climbing
local function toggleWallClimb(enabled)
    Movement.wallClimbEnabled = enabled
    print("Wall Climb:", enabled, "RootPart:", rootPart ~= nil)
    if not rootPart then
        rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    end
    if enabled and rootPart then
        wallClimbButton.Visible = true
        connections.wallClimb = RunService.Heartbeat:Connect(function()
            if not humanoid or not rootPart or not Movement.wallClimbEnabled then return end
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
        if connections.wallClimb then
            connections.wallClimb:Disconnect()
            connections.wallClimb = nil
        end
        if connections.wallClimbInput then
            connections.wallClimbInput:Disconnect()
            connections.wallClimbInput = nil
        end
        if wallClimbButton then
            wallClimbButton.Visible = false
            wallClimbButton.Text = "Climb"
        end
    end
end

-- Fly Hack
local function toggleFly(enabled)
    Movement.flyEnabled = enabled
    print("Fly:", enabled, "RootPart:", rootPart ~= nil)
    if not rootPart then
        rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    end
    if enabled and rootPart then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = rootPart
        flyJoystickFrame.Visible = true
        
        connections.fly = RunService.Heartbeat:Connect(function()
            if not rootPart or not Movement.flyEnabled or not rootPart:FindFirstChild("BodyVelocity") then return end
            local bodyVel = rootPart.BodyVelocity
            local camera = Workspace.CurrentCamera
            local flyDirection = Vector3.new(0, 0, 0)
            if joystickDelta.Magnitude > 0 then
                flyDirection = camera.CFrame:VectorToWorldSpace(Vector3.new(joystickDelta.X, 0, -joystickDelta.Y))
            end
            
            flyDirection = flyDirection + Vector3.new(0, flyVerticalInput, 0)
            bodyVel.Velocity = flyDirection * (settings.FlySpeed and settings.FlySpeed.value or 50)
        end)
        
        connections.flyInput = UserInputService.TouchMoved:Connect(function(input, processed)
            if not processed then
                joystickDelta = handleFlyJoystick(input)
            end
        end)
        connections.flyBegan = UserInputService.TouchStarted:Connect(function(input, processed)
            if not processed then
                handleFlyJoystick(input)
            end
        end)
        connections.flyEnded = UserInputService.TouchEnded:Connect(function(input, processed)
            if not processed then
                joystickDelta = handleFlyJoystick(input)
            end
        end)
        
        local flyUpButton = Instance.new("TextButton")
        flyUpButton.Name = "FlyUpButton"
        flyUpButton.Size = UDim2.new(0, 50, 0, 50)
        flyUpButton.Position = UDim2.new(0.85, -25, 0.6, 0)
        flyUpButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        flyUpButton.BackgroundTransparency = 0.5
        flyUpButton.Text = "Up"
        flyUpButton.Font = Enum.Font.Gotham
        flyUpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        flyUpButton.TextSize = 7
        flyUpButton.Visible = true
        flyUpButton.Parent = ScreenGui
        
        local upCorner = Instance.new("UICorner")
        upCorner.CornerRadius = UDim.new(0.2, 0)
        upCorner.Parent = flyUpButton
        
        local flyDownButton = Instance.new("TextButton")
        flyDownButton.Name = "FlyDownButton"
        flyDownButton.Size = UDim2.new(0, 50, 0, 50)
        flyDownButton.Position = UDim2.new(0.85, -25, 0.75, 0)
        flyDownButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        flyDownButton.BackgroundTransparency = 0.5
        flyDownButton.Text = "Down"
        flyDownButton.Font = Enum.Font.Gotham
        flyDownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        flyDownButton.TextSize = 7
        flyDownButton.Visible = true
        flyDownButton.Parent = ScreenGui
        
        local downCorner = Instance.new("UICorner")
        downCorner.CornerRadius = UDim.new(0.2, 0)
        downCorner.Parent = flyDownButton
        
        connections.flyUp = flyUpButton.MouseButton1Click:Connect(function()
            flyVerticalInput = 1
        end)
        connections.flyUpEnd = flyUpButton.MouseButton1Up:Connect(function()
            flyVerticalInput = flyVerticalInput == 1 and 0 or flyVerticalInput
        end)
        connections.flyDown = flyDownButton.MouseButton1Click:Connect(function()
            flyVerticalInput = -1
        end)
        connections.flyDownEnd = flyDownButton.MouseButton1Up:Connect(function()
            flyVerticalInput = flyVerticalInput == -1 and 0 or flyVerticalInput
        end)
    else
        if connections.fly then
            connections.fly:Disconnect()
            connections.fly = nil
        end
        if connections.flyInput then
            connections.flyInput:Disconnect()
            connections.flyInput = nil
        end
        if connections.flyBegan then
            connections.flyBegan:Disconnect()
            connections.flyBegan = nil
        end
        if connections.flyEnded then
            connections.flyEnded:Disconnect()
            connections.flyEnded = nil
        end
        if connections.flyUp then
            connections.flyUp:Disconnect()
            connections.flyUp = nil
        end
        if connections.flyUpEnd then
            connections.flyUpEnd:Disconnect()
            connections.flyUpEnd = nil
        end
        if connections.flyDown then
            connections.flyDown:Disconnect()
            connections.flyDown = nil
        end
        if connections.flyDownEnd then
            connections.flyDownEnd:Disconnect()
            connections.flyDownEnd = nil
        end
        if rootPart and rootPart:FindFirstChild("BodyVelocity") then
            rootPart.BodyVelocity:Destroy()
        end
        if flyJoystickFrame then
            flyJoystickFrame.Visible = false
            flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
        end
        if ScreenGui:FindFirstChild("FlyUpButton") then
            ScreenGui:FindFirstChild("FlyUpButton"):Destroy()
        end
        if ScreenGui:FindFirstChild("FlyDownButton") then
            ScreenGui:FindFirstChild("FlyDownButton"):Destroy()
        end
        flyVerticalInput = 0
        joystickDelta = Vector2.new(0, 0)
    end
end

-- NoClip
local function toggleNoclip(enabled)
    Movement.noclipEnabled = enabled
    print("NoClip:", enabled)
    if not player.Character then
        player.Character = Players.LocalPlayer.Character
    end
    if enabled and player.Character then
        connections.noclip = RunService.Stepped:Connect(function()
            if not player.Character or not Movement.noclipEnabled then return end
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    else
        if connections.noclip then
            connections.noclip:Disconnect()
            connections.noclip = nil
        end
        if player.Character then
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
    print("Walk on Water:", enabled, "RootPart:", rootPart ~= nil)
    if not rootPart then
        rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    end
    if enabled and rootPart then
        connections.walkOnWater = RunService.Heartbeat:Connect(function()
            if not rootPart or not Movement.walkOnWaterEnabled then return end
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
    else
        if connections.walkOnWater then
            connections.walkOnWater:Disconnect()
            connections.walkOnWater = nil
        end
        if rootPart and rootPart:FindFirstChild("WaterWalkPart") then
            rootPart.WaterWalkPart:Destroy()
        end
    end
end

-- Super Swim
local function toggleSwim(enabled)
    Movement.swimEnabled = enabled
    print("Super Swim:", enabled, "Humanoid:", humanoid ~= nil)
    if not humanoid then
        humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    end
    if humanoid and enabled then
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
            humanoid.WalkSpeed = 50
        end)
    elseif humanoid then
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
            humanoid.WalkSpeed = Movement.defaultWalkSpeed
        end)
    end
end

-- Function to create buttons for Movement features
function Movement.loadMovementButtons(createButton, createToggleButton)
    print("Loading movement buttons")
    if not createButton or not createToggleButton then
        warn("Error: createButton or createToggleButton not provided! Buttons will not be created.")
        print("Debug: createButton =", createButton, "createToggleButton =", createToggleButton)
        return
    end
    
    createToggleButton("Speed Hack", toggleSpeed)
    createToggleButton("Jump Hack", toggleJump)
    createToggleButton("Moon Gravity", toggleMoonGravity)
    createToggleButton("Double Jump", toggleDoubleJump)
    createToggleButton("Infinite Jump", toggleInfiniteJump)
    createToggleButton("Wall Climb", toggleWallClimb)
    createToggleButton("Fly", toggleFly)
    createToggleButton("NoClip", toggleNoclip)
    createToggleButton("Walk on Water", toggleWalkOnWater)
    createToggleButton("Super Swim", toggleSwim)
end

-- Function to reset Movement states
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
    Movement.jumpCount = 0
    flyVerticalInput = 0
    joystickDelta = Vector2.new(0, 0)
    
    local movementConnections = {"fly", "noclip", "infiniteJump", "walkOnWater", "doubleJump", "wallClimb", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", "flyDown", "flyDownEnd", "wallClimbInput"}
    for _, connName in ipairs(movementConnections) do
        if connections[connName] then
            print("Disconnecting:", connName)
            connections[connName]:Disconnect()
            connections[connName] = nil
        end
    end
    
    if humanoid then
        humanoid.WalkSpeed = Movement.defaultWalkSpeed
        if humanoid:FindFirstChild("JumpHeight") then
            humanoid.JumpHeight = Movement.defaultJumpHeight
        else
            humanoid.JumpPower = Movement.defaultJumpPower
        end
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
            humanoid.WalkSpeed = Movement.defaultWalkSpeed
        end)
    end
    Workspace.Gravity = Movement.defaultGravity
    if rootPart then
        if rootPart:FindFirstChild("BodyVelocity") then
            rootPart.BodyVelocity:Destroy()
        end
        if rootPart:FindFirstChild("WaterWalkPart") then
            rootPart.WaterWalkPart:Destroy()
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
    if ScreenGui then
        if ScreenGui:FindFirstChild("FlyUpButton") then
            ScreenGui:FindFirstChild("FlyUpButton"):Destroy()
        end
        if ScreenGui:FindFirstChild("FlyDownButton") then
            ScreenGui:FindFirstChild("FlyDownButton"):Destroy()
        end
    end
end

-- Function to update references when character respawns
function Movement.updateReferences(newHumanoid, newRootPart)
    print("Updating Movement references: Humanoid =", newHumanoid ~= nil, "RootPart =", newRootPart ~= nil)
    humanoid = newHumanoid
    rootPart = newRootPart
    
    if humanoid then
        Movement.defaultWalkSpeed = humanoid.WalkSpeed or 16
        if humanoid:FindFirstChild("JumpHeight") then
            Movement.defaultJumpHeight = humanoid.JumpHeight or 7.2
        else
            Movement.defaultJumpPower = humanoid.JumpPower or 50
        end
        Movement.defaultGravity = Workspace.Gravity or 196.2
    else
        warn("No humanoid provided in updateReferences!")
    end
    
    -- Reset and recreate mobile controls
    createMobileControls()
    
    -- Reapply active states
    if Movement.speedEnabled then
        print("Reapplying Speed")
        toggleSpeed(true)
    end
    if Movement.jumpEnabled then
        print("Reapplying Jump")
        toggleJump(true)
    end
    if Movement.moonGravityEnabled then
        print("Reapplying Moon Gravity")
        toggleMoonGravity(true)
    end
    if Movement.doubleJumpEnabled then
        print("Reapplying Double Jump")
        toggleDoubleJump(true)
    end
    if Movement.infiniteJumpEnabled then
        print("Reapplying Infinite Jump")
        toggleInfiniteJump(true)
    end
    if Movement.wallClimbEnabled then
        print("Reapplying Wall Climb")
        toggleWallClimb(true)
    end
    if Movement.flyEnabled then
        print("Reapplying Fly")
        toggleFly(true)
    end
    if Movement.noclipEnabled then
        print("Reapplying NoClip")
        toggleNoclip(true)
    end
    if Movement.walkOnWaterEnabled then
        print("Reapplying Walk on Water")
        toggleWalkOnWater(true)
    end
    if Movement.swimEnabled then
        print("Reapplying Super Swim")
        toggleSwim(true)
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
    Movement.jumpCount = 0
    flyVerticalInput = 0
    joystickDelta = Vector2.new(0, 0)
    
    if humanoid then
        Movement.defaultWalkSpeed = humanoid.WalkSpeed or 16
        if humanoid:FindFirstChild("JumpHeight") then
            Movement.defaultJumpHeight = humanoid.JumpHeight or 7.2
        else
            Movement.defaultJumpPower = humanoid.JumpPower or 50
        end
        Movement.defaultGravity = Workspace.Gravity or 196.2
    end
    
    createMobileControls()
    
    print("Movement module initialized successfully")
    return true
end

-- Debug function
function Movement.debug()
    print("=== Movement Module Debug Info ===")
    print("speedEnabled:", Movement.speedEnabled)
    print("jumpEnabled:", Movement.jumpEnabled)
    print("flyEnabled:", Movement.flyEnabled)
    print("noclipEnabled:", Movement.noclipEnabled)
    print("infiniteJumpEnabled:", Movement.infiniteJumpEnabled)
    print("walkOnWaterEnabled:", Movement.walkOnWaterEnabled)
    print("swimEnabled:", Movement.swimEnabled)
    print("moonGravityEnabled:", Movement.moonGravityEnabled)
    print("doubleJumpEnabled:", Movement.doubleJumpEnabled)
    print("wallClimbEnabled:", Movement.wallClimbEnabled)
    print("humanoid:", humanoid ~= nil)
    print("rootPart:", rootPart ~= nil)
    print("jumpCount:", Movement.jumpCount)
    print("flyVerticalInput:", flyVerticalInput)
    print("joystickDelta:", joystickDelta)
    print("flyJoystickFrame:", flyJoystickFrame ~= nil)
    print("wallClimbButton:", wallClimbButton ~= nil)
    print("===================================")
end

return Movement
