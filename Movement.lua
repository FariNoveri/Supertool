-- Movement-related features for MinimalHackGUI by Fari Noveri, including speed, jump, fly, noclip, etc.

-- Dependencies: These must be passed from mainloader.lua
local Players, RunService, Workspace, humanoid, connections, buttonStates, ScrollFrame, ScreenGui, player

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
Movement.defaultGravity = 196.2 -- Default Roblox gravity
Movement.jumpCount = 0
Movement.maxJumps = 2 -- For double jump

-- Speed Hack
local function toggleSpeed(enabled)
    Movement.speedEnabled = enabled
    print("Speed:", enabled)
    
    if enabled and humanoid then
        humanoid.WalkSpeed = 50
    elseif humanoid then
        humanoid.WalkSpeed = Movement.defaultWalkSpeed
    end
end

-- Jump Hack
local function toggleJump(enabled)
    Movement.jumpEnabled = enabled
    print("Jump:", enabled)
    
    if enabled and humanoid then
        if humanoid:FindFirstChild("JumpHeight") then
            humanoid.JumpHeight = 50
        else
            humanoid.JumpPower = 150
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
        Workspace.Gravity = 196.2 / 6 -- Moon gravity (~1/6 of Earth's)
    else
        Workspace.Gravity = Movement.defaultGravity
    end
end

-- Double Jump
local function toggleDoubleJump(enabled)
    Movement.doubleJumpEnabled = enabled
    print("Double Jump:", enabled)
    
    if enabled then
        connections.doubleJump = game:GetService("UserInputService").JumpRequest:Connect(function()
            if Movement.doubleJumpEnabled and humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
                Movement.jumpCount = 0
            elseif Movement.doubleJumpEnabled and humanoid and Movement.jumpCount < Movement.maxJumps then
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
        connections.infiniteJump = game:GetService("UserInputService").JumpRequest:Connect(function()
            if Movement.infiniteJumpEnabled and humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
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
    print("Wall Climb:", enabled)
    
    if enabled then
        connections.wallClimb = RunService.Heartbeat:Connect(function()
            if Movement.wallClimbEnabled and humanoid and Movement.rootPart then
                local raycastParams = RaycastParams.new()
                raycastParams.FilterDescendantsInstances = {player.Character}
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                
                local directions = {
                    Movement.rootPart.CFrame.RightVector,
                    -Movement.rootPart.CFrame.RightVector,
                    Movement.rootPart.CFrame.LookVector,
                    -Movement.rootPart.CFrame.LookVector
                }
                
                local isNearWall = false
                for _, direction in ipairs(directions) do
                    local raycast = Workspace:Raycast(Movement.rootPart.Position, direction * 3, raycastParams)
                    if raycast and raycast.Instance and raycast.Normal.Y < 0.1 then -- Vertical surface check
                        isNearWall = true
                        break
                    end
                end
                
                if isNearWall and game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.Space) then
                    Movement.rootPart.Velocity = Vector3.new(Movement.rootPart.Velocity.X, 30, Movement.rootPart.Velocity.Z)
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end)
    else
        if connections.wallClimb then
            connections.wallClimb:Disconnect()
            connections.wallClimb = nil
        end
    end
end

-- Fly Hack
local function toggleFly(enabled)
    Movement.flyEnabled = enabled
    print("Fly:", enabled)
    
    if enabled then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = Movement.rootPart
        
        connections.fly = RunService.Heartbeat:Connect(function()
            if Movement.flyEnabled and Movement.rootPart and Movement.rootPart:FindFirstChild("BodyVelocity") then
                local bodyVel = Movement.rootPart.BodyVelocity
                local camera = Workspace.CurrentCamera
                local moveVector = humanoid.MoveDirection
                
                local flyDirection = Vector3.new(0, 0, 0)
                if moveVector.Magnitude > 0 then
                    flyDirection = camera.CFrame:VectorToWorldSpace(Vector3.new(moveVector.X, 0, moveVector.Z))
                end
                
                local verticalInput = 0
                if game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.Space) then
                    verticalInput = 1
                elseif game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.LeftShift) then
                    verticalInput = -1
                end
                
                flyDirection = flyDirection + Vector3.new(0, verticalInput, 0)
                bodyVel.Velocity = flyDirection * 50
            end
        end)
    else
        if connections.fly then
            connections.fly:Disconnect()
            connections.fly = nil
        end
        
        if Movement.rootPart and Movement.rootPart:FindFirstChild("BodyVelocity") then
            Movement.rootPart.BodyVelocity:Destroy()
        end
    end
end

-- NoClip
local function toggleNoclip(enabled)
    Movement.noclipEnabled = enabled
    print("NoClip:", enabled)
    
    if enabled then
        connections.noclip = RunService.Stepped:Connect(function()
            if Movement.noclipEnabled and player.Character then
                for _, part in pairs(player.Character:GetChildren()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
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
            if Movement.walkOnWaterEnabled and Movement.rootPart then
                local raycast = Workspace:Raycast(Movement.rootPart.Position, Vector3.new(0, -10, 0))
                if raycast and raycast.Instance then
                    if raycast.Instance.Material == Enum.Material.Water or raycast.Instance.Name:lower():find("water") then
                        if not Movement.rootPart:FindFirstChild("WaterWalkPart") then
                            local waterWalkPart = Instance.new("Part")
                            waterWalkPart.Name = "WaterWalkPart"
                            waterWalkPart.Anchored = true
                            waterWalkPart.CanCollide = true
                            waterWalkPart.Transparency = 1
                            waterWalkPart.Size = Vector3.new(10, 0.2, 10)
                            waterWalkPart.Position = Vector3.new(Movement.rootPart.Position.X, raycast.Position.Y + 0.1, Movement.rootPart.Position.Z)
                            waterWalkPart.Parent = Workspace
                            
                            game:GetService("Debris"):AddItem(waterWalkPart, 2)
                        end
                    end
                end
            end
        end)
    else
        if connections.walkOnWater then
            connections.walkOnWater:Disconnect()
            connections.walkOnWater = nil
        end
    end
end

-- Super Swim
local function toggleSwim(enabled)
    Movement.swimEnabled = enabled
    print("Super Swim:", enabled)
    
    if enabled and humanoid then
        humanoid.SwimSpeed = 50
    elseif humanoid then
        humanoid.SwimSpeed = 16
    end
end

-- Function to create buttons for Movement features
function Movement.loadMovementButtons(createButton, createToggleButton)
    print("Loading movement buttons")
    
    if not createButton or not createToggleButton then
        print("createButton or createToggleButton not provided!")
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
    
    local movementConnections = {"fly", "noclip", "infiniteJump", "walkOnWater", "doubleJump", "wallClimb"}
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
        humanoid.SwimSpeed = 16
    end
    Workspace.Gravity = Movement.defaultGravity
end

-- Function to update references when character respawns
function Movement.updateReferences(newHumanoid, newRootPart)
    humanoid = newHumanoid
    Movement.rootPart = newRootPart
    
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
        print("Error: No dependencies provided!")
        return false
    end
    
    Players = deps.Players
    RunService = deps.RunService
    Workspace = deps.Workspace
    humanoid = deps.humanoid
    connections = deps.connections
    buttonStates = deps.buttonStates
    ScrollFrame = deps.ScrollFrame
    ScreenGui = deps.ScreenGui
    player = deps.player
    Movement.rootPart = deps.rootPart
    
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
    
    if humanoid then
        Movement.defaultWalkSpeed = humanoid.WalkSpeed
        if humanoid:FindFirstChild("JumpHeight") then
            Movement.defaultJumpHeight = humanoid.JumpHeight
        else
            Movement.defaultJumpPower = humanoid.JumpPower
        end
        Movement.defaultGravity = Workspace.Gravity
    end
    
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
    print("rootPart:", Movement.rootPart ~= nil)
    print("jumpCount:", Movement.jumpCount)
    print("===================================")
end

return Movement