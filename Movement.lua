-- Movement features for MinimalHackGUI by Fari Noveri

-- Dependencies: These must be passed from mainloader.lua
local Players, UserInputService, RunService, Workspace, settings, character, humanoid, rootPart, connections, buttonStates, ScrollFrame

-- Initialize module
local Movement = {}

-- Fly (Improved for smoother control)
local function toggleFly(enabled)
    Movement.flyEnabled = enabled
    if enabled then
        if not rootPart or not humanoid or not settings.FlySpeed then return end
        
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge) -- Increased for better control
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = rootPart
        
        connections.fly = RunService.Heartbeat:Connect(function(deltaTime)
            if Movement.flyEnabled and rootPart and humanoid and settings.FlySpeed then
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
                
                -- Handle vertical movement with input
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    velocity = velocity + (upVector * speed)
                elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                    velocity = velocity - (upVector * speed)
                end
                
                bodyVelocity.Velocity = velocity
            end
        end)
    else
        if connections.fly then
            connections.fly:Disconnect()
            connections.fly = nil
        end
        if rootPart and rootPart:FindFirstChild("BodyVelocity") then
            rootPart:FindFirstChild("BodyVelocity"):Destroy()
        end
    end
end

-- Noclip (Improved with dynamic part handling)
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
        -- Handle new parts added to character
        if character then
            connections.noclipChildAdded = character.ChildAdded:Connect(function(child)
                if Movement.noclipEnabled and child:IsA("BasePart") and child.CanCollide then
                    child.CanCollide = false
                end
            end)
        end
    else
        if connections.noclip then
            connections.noclip:Disconnect()
            connections.noclip = nil
        end
        if connections.noclipChildAdded then
            connections.noclipChildAdded:Disconnect()
            connections.noclipChildAdded = nil
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

-- Speed (Fixed with proper checks)
local function toggleSpeed(enabled)
    Movement.speedEnabled = enabled
    if enabled then
        if humanoid and settings.WalkSpeed then
            humanoid.WalkSpeed = settings.WalkSpeed.value
        end
    else
        if humanoid then
            humanoid.WalkSpeed = 16
        end
    end
end

-- Jump High (Fixed with consistent physics)
local function toggleJumpHigh(enabled)
    Movement.jumpHighEnabled = enabled
    if enabled then
        if humanoid and settings.JumpHeight then
            humanoid.JumpPower = settings.JumpHeight.value * 7 -- Adjusted for Roblox physics
            connections.jumphigh = humanoid.Jumping:Connect(function()
                if Movement.jumpHighEnabled and rootPart then
                    rootPart.Velocity = Vector3.new(rootPart.Velocity.X, settings.JumpHeight.value * 7, rootPart.Velocity.Z)
                end
            end)
        end
    else
        if humanoid then
            humanoid.JumpPower = 50 -- Default Roblox value
        end
        if connections.jumphigh then
            connections.jumphigh:Disconnect()
            connections.jumphigh = nil
        end
    end
end

-- Spider (Improved raycasting and orientation)
local function toggleSpider(enabled)
    Movement.spiderEnabled = enabled
    if enabled then
        if not rootPart then return end
        
        local bodyPosition = Instance.new("BodyPosition")
        bodyPosition.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bodyPosition.Position = rootPart.Position
        bodyPosition.Parent = rootPart
        
        local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
        bodyAngularVelocity.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
        bodyAngularVelocity.Parent = rootPart
        
        connections.spider = RunService.Heartbeat:Connect(function()
            if Movement.spiderEnabled and rootPart then
                local rayParams = RaycastParams.new()
                rayParams.FilterDescendantsInstances = {character}
                rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                local rayResult = Workspace:Raycast(rootPart.Position, rootPart.CFrame.LookVector * 5, rayParams)
                
                if rayResult then
                    bodyPosition.Position = rayResult.Position + rayResult.Normal * 1.5
                    local lookDirection = -rayResult.Normal
                    local upVector = Vector3.new(0, 1, 0)
                    local rightVector = lookDirection:Cross(upVector).Unit
                    local newCFrame = CFrame.fromMatrix(rootPart.Position, rightVector, lookDirection, upVector)
                    bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
                    rootPart.CFrame = newCFrame
                end
            end
        end)
    else
        if connections.spider then
            connections.spider:Disconnect()
            connections.spider = nil
        end
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

-- Player Phase (Improved with dynamic player handling)
local function togglePlayerPhase(enabled)
    Movement.playerPhaseEnabled = enabled
    if enabled then
        connections.playerphase = RunService.Heartbeat:Connect(function()
            if Movement.playerPhaseEnabled then
                for _, otherPlayer in pairs(Players:GetPlayers()) do
                    if otherPlayer ~= Players.LocalPlayer and otherPlayer.Character then
                        for _, part in pairs(otherPlayer.Character:GetDescendants()) do
                            if part:IsA("BasePart") and part.CanCollide then
                                part.CanCollide = false
                            end
                        end
                    end
                end
            end
        end)
        -- Handle new players
        connections.playerPhasePlayerAdded = Players.PlayerAdded:Connect(function(player)
            if Movement.playerPhaseEnabled and player.Character then
                for _, part in pairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if connections.playerphase then
            connections.playerphase:Disconnect()
            connections.playerphase = nil
        end
        if connections.playerPhasePlayerAdded then
            connections.playerPhasePlayerAdded:Disconnect()
            connections.playerPhasePlayerAdded = nil
        end
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= Players.LocalPlayer and otherPlayer.Character then
                for _, part in pairs(otherPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end
    end
end

-- Freeze Blocks/Objects (New feature)
local function toggleFreezeObjects(enabled)
    Movement.freezeObjectsEnabled = enabled
    Movement.frozenObjectPositions = Movement.frozenObjectPositions or {}
    
    if enabled then
        -- Store initial positions of all non-player objects
        Movement.frozenObjectPositions = {}
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj ~= rootPart and not obj:IsDescendantOf(character) then
                local isPlayerPart = false
                for _, player in pairs(Players:GetPlayers()) do
                    if player.Character and obj:IsDescendantOf(player.Character) then
                        isPlayerPart = true
                        break
                    end
                end
                if not isPlayerPart then
                    Movement.frozenObjectPositions[obj] = obj.CFrame
                end
            end
        end
        connections.freezeObjects = RunService.RenderStepped:Connect(function()
            if Movement.freezeObjectsEnabled then
                for obj, frozenCFrame in pairs(Movement.frozenObjectPositions) do
                    if obj and obj.Parent and obj:IsA("BasePart") then
                        obj.CFrame = frozenCFrame
                    end
                end
            end
        end)
        -- Handle new objects added to Workspace
        connections.freezeObjectsAdded = Workspace.DescendantAdded:Connect(function(obj)
            if Movement.freezeObjectsEnabled and obj:IsA("BasePart") and obj ~= rootPart and not obj:IsDescendantOf(character) then
                local isPlayerPart = false
                for _, player in pairs(Players:GetPlayers()) do
                    if player.Character and obj:IsDescendantOf(player.Character) then
                        isPlayerPart = true
                        break
                    end
                end
                if not isPlayerPart then
                    Movement.frozenObjectPositions[obj] = obj.CFrame
                end
            end
        end)
    else
        if connections.freezeObjects then
            connections.freezeObjects:Disconnect()
            connections.freezeObjects = nil
        end
        if connections.freezeObjectsAdded then
            connections.freezeObjectsAdded:Disconnect()
            connections.freezeObjectsAdded = nil
        end
        Movement.frozenObjectPositions = {}
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
    createToggleButton("Freeze Objects", toggleFreezeObjects)
end

-- Function to reset Movement states (called when character respawns)
function Movement.resetStates()
    Movement.flyEnabled = false
    Movement.noclipEnabled = false
    Movement.speedEnabled = false
    Movement.jumpHighEnabled = false
    Movement.spiderEnabled = false
    Movement.playerPhaseEnabled = false
    Movement.freezeObjectsEnabled = false
    
    -- Disconnect all connections
    if connections.fly then
        connections.fly:Disconnect()
        connections.fly = nil
    end
    if connections.noclip then
        connections.noclip:Disconnect()
        connections.noclip = nil
    end
    if connections.noclipChildAdded then
        connections.noclipChildAdded:Disconnect()
        connections.noclipChildAdded = nil
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
    if connections.playerPhasePlayerAdded then
        connections.playerPhasePlayerAdded:Disconnect()
        connections.playerPhasePlayerAdded = nil
    end
    if connections.freezeObjects then
        connections.freezeObjects:Disconnect()
        connections.freezeObjects = nil
    end
    if connections.freezeObjectsAdded then
        connections.freezeObjectsAdded:Disconnect()
        connections.freezeObjectsAdded = nil
    end
    
    -- Clean up body objects
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
    
    -- Reset character properties
    if humanoid then
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
    end
    if character then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= Players.LocalPlayer and otherPlayer.Character then
            for _, part in pairs(otherPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
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
    Movement.freezeObjectsEnabled = false
    Movement.frozenObjectPositions = {}
end

return Movement