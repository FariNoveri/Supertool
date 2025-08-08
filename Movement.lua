-- Movement-related features for MinimalHackGUI by Fari Noveri, mobile-friendly

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

-- Default values
Movement.defaultWalkSpeed = 16
Movement.defaultJumpPower = 50
Movement.defaultJumpHeight = 7.2
Movement.defaultGravity = 196.2
Movement.jumpCount = 0
Movement.maxJumps = 2
local flyVerticalInput = 0 -- For mobile fly controls
local wallClimbButton -- Virtual button for wall climb
local flyJoystickFrame, flyJoystickKnob -- Virtual joystick for fly

-- Create virtual controls for mobile
local function createMobileControls()
    -- Fly joystick
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

    -- Wall climb button
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
    if not Movement.flyEnabled or not flyJoystickFrame.Visible then return Vector2.new(0, 0) end
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
    print("Speed:", enabled)
    
    if humanoid and enabled then
        humanoid.WalkSpeed = settings.WalkSpeed and settings.WalkSpeed.value or 50
    elseif humanoid then
        humanoid.WalkSpeed = Movement.defaultWalkSpeed
    end
end

-- Jump Hack
local function toggleJump(enabled)
    Movement.jumpEnabled = enabled
    print("Jump:", enabled)
    
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

-- Wall Climbing (Mobile)
local function toggleWallClimb(enabled)
    Movement.wallClimbEnabled = enabled
    print("Wall Climb:", enabled)
    
    if enabled then
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
        wallClimbButton.Visible = false
        wallClimbButton.Text = "Climb"
    end
end

-- Fly Hack (Mobile)
local function toggleFly(enabled)
    Movement.flyEnabled = enabled
    print("Fly:", enabled)
    
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
            local joystickDelta = Vector2.new(0, 0) -- Updated via touch input
            
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
        
        -- Vertical control buttons
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
        flyJoystickFrame.Visible = false
        flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
        if ScreenGui:FindFirstChild("FlyUpButton") then
            ScreenGui:FindFirstChild("FlyUpButton"):Destroy()
        end
        if ScreenGui:FindFirstChild("FlyDownButton") then
            ScreenGui:FindFirstChild("FlyDownButton"):Destroy()
        end
        flyVerticalInput = 0
    end
end

-- NoClip
local function toggleNoclip(enabled)
    Movement.noclipEnabled = enabled
    print("NoClip:", enabled)
    
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
    print("Walk on Water:", enabled)
    
    if enabled then
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
    print("Super Swim:", enabled)
    
    if humanoid and enabled then
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
            humanoid.WalkSpeed = 50 -- Fallback to WalkSpeed for swimming
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
    
    local movementConnections = {"fly", "noclip", "infiniteJump", "walkOnWater", "doubleJump", "wallClimb", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", "flyDown", "flyDownEnd", "wallClimbInput"}
    for _, connName in ipairs(movementConnections) do
        if connections[connName] then
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
    if rootPart and rootPart:FindFirstChild("BodyVelocity") then
        rootPart.BodyVelocity:Destroy()
    end
    if rootPart and rootPart:FindFirstChild("WaterWalkPart") then
        rootPart.WaterWalkPart:Destroy()
    end
    if ScreenGui:FindFirstChild("FlyJoystick") then
        flyJoystickFrame.Visible = false
        flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
    end
    if ScreenGui:FindFirstChild("WallClimbButton") then
        wallClimbButton.Visible = false
        wallClimbButton.Text = "Climb"
    end
    if ScreenGui:FindFirstChild("FlyUpButton") then
        ScreenGui:FindFirstChild("FlyUpButton"):Destroy()
    end
    if ScreenGui:FindFirstChild("FlyDownButton") then
        ScreenGui:FindFirstChild("FlyDownButton"):Destroy()
    end
end

-- Function to update references when character respawns
function Movement.updateReferences(newHumanoid, newRootPart)
    print("Updating Movement references")
    humanoid = newHumanoid
    rootPart = newRootPart
    
    if humanoid then
        Movement.defaultWalkSpeed = humanoid.WalkSpeed
        if humanoid:FindFirstChild("JumpHeight") then
            Movement.defaultJumpHeight = humanoid.JumpHeight
        else
            Movement.defaultJumpPower = humanoid.JumpPower
        end
        Movement.defaultGravity = Workspace.Gravity
    end
    
    -- Reapply active states
    if Movement.speedEnabled then toggleSpeed(true) end
    if Movement.jumpEnabled then toggleJump(true) end
    if Movement.moonGravityEnabled then toggleMoonGravity(true) end
    if Movement.doubleJumpEnabled then toggleDoubleJump(true) end
    if Movement.infiniteJumpEnabled then toggleInfiniteJump(true) end
    if Movement.wallClimbEnabled then toggleWallClimb(true) end
    if Movement.flyEnabled then toggleFly(true) end
    if Movement.noclipEnabled then toggleNoclip(true) end
    if Movement.walkOnWaterEnabled then toggleWalkOnWater(true) end
    if Movement.swimEnabled then toggleSwim(true) end
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
    
    if humanoid then
        Movement.defaultWalkSpeed = humanoid.WalkSpeed
        if humanoid:FindFirstChild("JumpHeight") then
            Movement.defaultJumpHeight = humanoid.JumpHeight
        else
            Movement.defaultJumpPower = humanoid.JumpPower
        end
        Movement.defaultGravity = Workspace.Gravity
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
    print("===================================")
end

return Movement