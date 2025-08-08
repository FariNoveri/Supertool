-- movement.lua
-- Movement features for MinimalHackGUI by Fari Noveri

-- Dependencies: These must be passed from mainloader.lua
local Players, UserInputService, RunService, Workspace, settings, character, humanoid, rootPart, connections, buttonStates, ScrollFrame

-- Initialize module
local Movement = {}

-- Fly (Android Touch Controls)
local function toggleFly(enabled)
    Movement.flyEnabled = enabled
    if enabled then
        -- Check if rootPart exists before creating BodyVelocity
        if not rootPart then return end
        
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = rootPart
        
        connections.fly = RunService.Heartbeat:Connect(function()
            if Movement.flyEnabled and rootPart then
                local camera = Workspace.CurrentCamera
                local moveVector = humanoid.MoveDirection
                
                local cameraCFrame = camera.CFrame
                local forwardVector = cameraCFrame.LookVector
                local rightVector = cameraCFrame.RightVector
                local upVector = Vector3.new(0, 1, 0)
                
                local velocity = Vector3.new(0, 0, 0)
                local speed = settings.FlySpeed.value
                
                if moveVector.Magnitude > 0 then
                    velocity = velocity + (forwardVector * -moveVector.Z * speed)
                    velocity = velocity + (rightVector * moveVector.X * speed)
                end
                
                if humanoid.Jump then
                    velocity = velocity + (upVector * speed)
                    humanoid.Jump = false
                end
                
                bodyVelocity.Velocity = velocity
            end
        end)
    else
        if connections.fly then
            connections.fly:Disconnect()
            connections.fly = nil
        end
        -- Check if rootPart exists before trying to find BodyVelocity
        if rootPart and rootPart:FindFirstChild("BodyVelocity") then
            rootPart:FindFirstChild("BodyVelocity"):Destroy()
        end
    end
end

-- Noclip
local function toggleNoclip(enabled)
    Movement.noclipEnabled = enabled
    if enabled then
        connections.noclip = RunService.Stepped:Connect(function()
            if Movement.noclipEnabled and character then
                for _, part in pairs(character:GetDescendants()) do
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
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- Speed
local function toggleSpeed(enabled)
    Movement.speedEnabled = enabled
    if enabled then
        if humanoid then
            humanoid.WalkSpeed = settings.WalkSpeed.value
        end
    else
        if humanoid then
            humanoid.WalkSpeed = 16
        end
    end
end

-- Jump High
local function toggleJumpHigh(enabled)
    Movement.jumpHighEnabled = enabled
    if enabled then
        if humanoid then
            humanoid.JumpHeight = settings.JumpHeight.value
            humanoid.JumpPower = settings.JumpHeight.value * 2.4
            connections.jumphigh = humanoid.Jumping:Connect(function()
                if Movement.jumpHighEnabled and rootPart then
                    rootPart.Velocity = Vector3.new(rootPart.Velocity.X, settings.JumpHeight.value * 2.4, rootPart.Velocity.Z)
                end
            end)
        end
    else
        if humanoid then
            humanoid.JumpHeight = 7.2
            humanoid.JumpPower = 50
        end
        if connections.jumphigh then
            connections.jumphigh:Disconnect()
            connections.jumphigh = nil
        end
    end
end

-- Spider (stick to walls)
local function toggleSpider(enabled)
    Movement.spiderEnabled = enabled
    if enabled then
        -- Check if rootPart exists before creating body objects
        if not rootPart then return end
        
        local bodyPosition = Instance.new("BodyPosition")
        bodyPosition.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyPosition.Position = rootPart.Position
        bodyPosition.Parent = rootPart
        
        local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
        bodyAngularVelocity.MaxTorque = Vector3.new(4000, 4000, 4000)
        bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
        bodyAngularVelocity.Parent = rootPart
        
        connections.spider = RunService.Heartbeat:Connect(function()
            if Movement.spiderEnabled and rootPart then
                local ray = Workspace:Raycast(rootPart.Position, rootPart.CFrame.LookVector * 10)
                if ray then
                    bodyPosition.Position = ray.Position + ray.Normal * 3
                    local lookDirection = -ray.Normal
                    bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
                    rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + lookDirection)
                end
            end
        end)
    else
        if connections.spider then
            connections.spider:Disconnect()
            connections.spider = nil
        end
        -- Check if rootPart exists before trying to find body objects
        if rootPart then
            if rootPart:FindFirstChild("BodyPosition") then
                rootPart:FindFirstChild("BodyPosition"):Destroy()
            end
            if rootPart:FindFirstChild("BodyAngularVelocity") then
                rootPart:FindFirstChild("BodyAngularVelocity"):Destroy()
            end
        end
    end
end

-- Player Phase (nembus player lain)
local function togglePlayerPhase(enabled)
    Movement.playerPhaseEnabled = enabled
    if enabled then
        connections.playerphase = RunService.Heartbeat:Connect(function()
            if Movement.playerPhaseEnabled and character then
                for _, otherPlayer in pairs(Players:GetPlayers()) do
                    if otherPlayer ~= Players.LocalPlayer and otherPlayer.Character then
                        for _, part in pairs(otherPlayer.Character:GetChildren()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                            end
                        end
                    end
                end
            end
        end)
    else
        if connections.playerphase then
            connections.playerphase:Disconnect()
            connections.playerphase = nil
        end
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= Players.LocalPlayer and otherPlayer.Character then
                for _, part in pairs(otherPlayer.Character:GetChildren()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end
    end
end

-- Function to create toggle buttons for Movement features
function Movement.loadMovementButtons(createToggleButton)
    createToggleButton("Fly", toggleFly)
    createToggleButton("Noclip", toggleNoclip)
    createToggleButton("Speed", toggleSpeed)
    createToggleButton("Jump High", toggleJumpHigh)
    createToggleButton("Spider", toggleSpider)
    createToggleButton("Player Phase", togglePlayerPhase)
end

-- Function to reset Movement states (called when character respawns)
function Movement.resetStates()
    Movement.flyEnabled = false
    Movement.noclipEnabled = false
    Movement.speedEnabled = false
    Movement.jumpHighEnabled = false
    Movement.spiderEnabled = false
    Movement.playerPhaseEnabled = false
    
    -- Disconnect all connections first to prevent errors
    if connections.fly then
        connections.fly:Disconnect()
        connections.fly = nil
    end
    if connections.noclip then
        connections.noclip:Disconnect()
        connections.noclip = nil
    end
    if connections.jumphigh then
        connections.jumphigh:Disconnect()
        connections.jumphigh = nil
    end
    if connections.spider then
        connections.spider:Disconnect()
        connections.spider = nil
    end
    if connections.playerphase then
        connections.playerphase:Disconnect()
        connections.playerphase = nil
    end
    
    -- Only try to clean up body objects if rootPart exists
    if rootPart then
        if rootPart:FindFirstChild("BodyVelocity") then
            rootPart:FindFirstChild("BodyVelocity"):Destroy()
        end
        if rootPart:FindFirstChild("BodyPosition") then
            rootPart:FindFirstChild("BodyPosition"):Destroy()
        end
        if rootPart:FindFirstChild("BodyAngularVelocity") then
            rootPart:FindFirstChild("BodyAngularVelocity"):Destroy()
        end
    end
end

-- Function to set dependencies
function Movement.init(deps)
    Players = deps.Players
    UserInputService = deps.UserInputService
    RunService = deps.RunService
    Workspace = deps.Workspace
    settings = deps.settings
    character = deps.character
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    connections = deps.connections
    buttonStates = deps.buttonStates
    ScrollFrame = deps.ScrollFrame
    
    -- Initialize state variables
    Movement.flyEnabled = false
    Movement.noclipEnabled = false
    Movement.speedEnabled = false
    Movement.jumpHighEnabled = false
    Movement.spiderEnabled = false
    Movement.playerPhaseEnabled = false
end

return Movement