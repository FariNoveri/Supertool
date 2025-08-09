-- Anti Admin Protection System by Fari Noveri

local AntiAdmin = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Variables
local player = Players.LocalPlayer
local character
local humanoid
local rootPart
local backpack
local camera = Workspace.CurrentCamera
local ScreenGui -- Will be set via dependencies

-- Anti Admin variables
local antiAdminEnabled = true
local protectedPlayers = {} -- Players marked as admins
local lastKnownPosition
local lastKnownHealth = 100
local lastKnownVelocity = Vector3.new(0, 0, 0)
local lastKnownWalkSpeed = 16
local lastKnownJumpPower = 50
local lastKnownAnchored = false
local lastKnownCameraSubject
local lastKnownTools = {}
local lastKnownCanCollide = true
local lastKnownTransparency = 0
local effectSources = {} -- Tracks source of effects (e.g., admin causing kill)
local antiAdminConnections = {}
local maxReverseAttempts = 10
local allowedAnimations = {}
local allowedRemotes = {}
local oldNamecall
local adminNotificationLabel -- For admin detection notification

-- Initialize function
function AntiAdmin.init(dependencies)
    if dependencies then
        if dependencies.player then player = dependencies.player end
        if dependencies.humanoid then humanoid = dependencies.humanoid end
        if dependencies.rootPart then rootPart = dependencies.rootPart end
        if dependencies.ScreenGui then ScreenGui = dependencies.ScreenGui end
    end
    
    character = player.Character
    if character then
        humanoid = character:FindFirstChild("Humanoid")
        rootPart = character:FindFirstChild("HumanoidRootPart")
        backpack = player:FindFirstChild("Backpack")
        
        if humanoid then
            lastKnownHealth = humanoid.Health
            lastKnownWalkSpeed = humanoid.WalkSpeed
            lastKnownJumpPower = humanoid.JumpPower or humanoid.JumpHeight or 50
            lastKnownTransparency = 0
        end
        
        if rootPart then
            lastKnownPosition = rootPart.CFrame
            lastKnownVelocity = rootPart.Velocity
            lastKnownAnchored = rootPart.Anchored
            lastKnownCanCollide = rootPart.CanCollide
        end
        
        if camera then
            lastKnownCameraSubject = camera.CameraSubject
        end
    end

    -- Create admin notification UI
    if ScreenGui then
        adminNotificationLabel = Instance.new("TextLabel")
        adminNotificationLabel.Name = "AdminNotification"
        adminNotificationLabel.Parent = ScreenGui
        adminNotificationLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        adminNotificationLabel.BackgroundTransparency = 0.5
        adminNotificationLabel.BorderColor3 = Color3.fromRGB(45, 45, 45)
        adminNotificationLabel.Position = UDim2.new(1, -205, 0, 5)
        adminNotificationLabel.Size = UDim2.new(0, 200, 0, 30)
        adminNotificationLabel.Font = Enum.Font.Gotham
        adminNotificationLabel.Text = ""
        adminNotificationLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        adminNotificationLabel.TextSize = 12
        adminNotificationLabel.TextXAlignment = Enum.TextXAlignment.Left
        adminNotificationLabel.Visible = false
        print("Admin notification UI created")
    else
        warn("Cannot create admin notification UI: ScreenGui not available")
    end
end

-- Function to show admin notification
local function showAdminNotification(message)
    if not adminNotificationLabel then
        warn("Cannot show admin notification: UI not initialized")
        return
    end
    adminNotificationLabel.Text = message
    adminNotificationLabel.Visible = true
    print("Showing notification: " .. message)
    spawn(function()
        wait(3)
        if adminNotificationLabel then
            adminNotificationLabel.Visible = false
            adminNotificationLabel.Text = ""
            print("Admin notification hidden")
        end
    end)
end

-- Function to update tool cache
local function updateToolCache()
    if not backpack then return end
    lastKnownTools = {}
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            table.insert(lastKnownTools, tool.Name)
        end
    end
end

-- Function to detect if player is an admin (simulation)
local function hasAntiAdmin(targetPlayer)
    if not targetPlayer then return false end
    return protectedPlayers[targetPlayer] or false -- Use protectedPlayers to check admin status
end

-- Function to update protected players and detect admins
local function updateProtectedPlayers()
    protectedPlayers = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            local isAdmin = math.random(1, 100) <= 50 -- Simulated admin check
            protectedPlayers[p] = isAdmin
            if isAdmin then
                showAdminNotification("Detected Admin: " .. p.Name)
            end
        end
    end
end

-- Function to find unprotected target
local function findUnprotectedTarget(excludePlayers)
    local availablePlayers = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("Humanoid") then
            local pHumanoid = p.Character.Humanoid
            if pHumanoid.Health > 0 and not excludePlayers[p] and not hasAntiAdmin(p) then
                table.insert(availablePlayers, p)
            end
        end
    end
    if #availablePlayers > 0 then
        return availablePlayers[math.random(1, #availablePlayers)]
    end
    return nil
end

-- Function to reverse effect with "hot potato" logic
local function reverseEffect(effectType, originalSource)
    if not antiAdminEnabled then return end

    local excludePlayers = { [player] = true }
    local currentTarget = originalSource
    if not currentTarget then
        local allPlayers = Players:GetPlayers()
        if #allPlayers > 1 then
            currentTarget = allPlayers[math.random(1, #allPlayers)]
        else
            return
        end
    end
    
    local attempts = 0
    while currentTarget and hasAntiAdmin(currentTarget) and attempts < maxReverseAttempts do
        excludePlayers[currentTarget] = true
        currentTarget = findUnprotectedTarget(excludePlayers)
        attempts = attempts + 1
    end

    if currentTarget and currentTarget.Character then
        local targetHumanoid = currentTarget.Character:FindFirstChild("Humanoid")
        local targetRootPart = currentTarget.Character:FindFirstChild("HumanoidRootPart")
        
        if not targetHumanoid or not targetRootPart then return end

        pcall(function()
            if effectType == "kill" then
                targetHumanoid.Health = 0
                print("Reversed kill effect to: " .. currentTarget.Name .. " after " .. attempts .. " attempts")
                showAdminNotification("Kill attempt by " .. (originalSource and originalSource.Name or "unknown") .. " reversed to " .. currentTarget.Name)
            elseif effectType == "teleport" then
                local randomPos = Vector3.new(
                    math.random(-1000, 1000),
                    math.random(50, 500),
                    math.random(-1000, 1000)
                )
                targetRootPart.CFrame = CFrame.new(randomPos)
                print("Reversed teleport effect to: " .. currentTarget.Name .. " after " .. attempts .. " attempts")
            elseif effectType == "fling" then
                targetRootPart.Velocity = Vector3.new(
                    math.random(-100, 100),
                    math.random(50, 200),
                    math.random(-100, 100)
                )
                print("Reversed fling effect to: " .. currentTarget.Name .. " after " .. attempts .. " attempts")
            elseif effectType == "freeze" then
                targetRootPart.Anchored = true
                print("Reversed freeze effect to: " .. currentTarget.Name .. " after " .. attempts .. " attempts")
            elseif effectType == "speed" then
                targetHumanoid.WalkSpeed = math.random(0, 5)
                print("Reversed speed change to: " .. currentTarget.Name .. " after " .. attempts .. " attempts")
            elseif effectType == "jump" then
                if targetHumanoid.JumpPower then
                    targetHumanoid.JumpPower = 0
                elseif targetHumanoid.JumpHeight then
                    targetHumanoid.JumpHeight = 0
                end
                print("Reversed jump change to: " .. currentTarget.Name .. " after " .. attempts .. " attempts")
            elseif effectType == "tool" then
                local targetBackpack = currentTarget:FindFirstChild("Backpack")
                if targetBackpack then
                    for _, tool in pairs(targetBackpack:GetChildren()) do
                        if tool:IsA("Tool") then
                            tool:Destroy()
                        end
                    end
                end
                print("Reversed tool removal to: " .. currentTarget.Name .. " after " .. attempts .. " attempts")
            elseif effectType == "camera" then
                if camera then
                    camera.CameraSubject = targetHumanoid
                end
                print("Reversed camera change to: " .. currentTarget.Name .. " after " .. attempts .. " attempts")
            elseif effectType == "effect" then
                for _, effect in pairs(targetRootPart:GetChildren()) do
                    if effect:IsA("ParticleEmitter") or effect:IsA("Beam") or effect:IsA("Trail") then
                        effect:Destroy()
                    end
                end
                print("Reversed visual effect to: " .. currentTarget.Name .. " after " .. attempts .. " attempts")
            end
        end)
    else
        print("No unprotected target found for " .. effectType .. " reversal after " .. attempts .. " attempts")
    end
end

-- Function to check if death was likely from falling
local function isFallDeath()
    if not humanoid or not rootPart then return false end
    -- Check if player is in the air (no floor) or has high downward velocity
    local isInAir = humanoid.FloorMaterial == Enum.Material.Air
    local downwardVelocity = rootPart.Velocity.Y < -50 -- Typical fall velocity threshold
    return isInAir or downwardVelocity
end

-- Function to handle anti admin protection
local function handleAntiAdmin()
    if not humanoid or not rootPart then return end

    -- Kill Protection
    if humanoid and typeof(humanoid) == "Instance" then
        antiAdminConnections.health = humanoid.HealthChanged:Connect(function(health)
            if not antiAdminEnabled then return end
            if health < lastKnownHealth and health <= 0 then
                pcall(function()
                    -- Check if death is likely from falling
                    if isFallDeath() then
                        print("Detected accidental death (likely fall), not reversing")
                        return
                    end
                    -- Check for admin involvement
                    local adminDetected = false
                    local sourcePlayer = effectSources[player]
                    if sourcePlayer and hasAntiAdmin(sourcePlayer) then
                        adminDetected = true
                    else
                        -- Check if any admin is present (as a fallback)
                        for _, p in pairs(Players:GetPlayers()) do
                            if p ~= player and hasAntiAdmin(p) then
                                adminDetected = true
                                sourcePlayer = p
                                break
                            end
                        end
                    end
                    if adminDetected then
                        humanoid.Health = lastKnownHealth
                        print("Detected admin/exploit kill attempt, health restored")
                        reverseEffect("kill", sourcePlayer)
                    else
                        print("No admin detected for kill attempt, not reversing")
                    end
                end)
            end
            lastKnownHealth = humanoid.Health
        end)
    end

    -- Teleport Protection
    if rootPart and typeof(rootPart) == "Instance" then
        antiAdminConnections.position = rootPart:GetPropertyChangedSignal("CFrame"):Connect(function()
            if not antiAdminEnabled then return end
            pcall(function()
                local currentPos = rootPart.CFrame
                if lastKnownPosition then
                    local distance = (currentPos.Position - lastKnownPosition.Position).Magnitude
                    if distance > 50 then
                        rootPart.CFrame = lastKnownPosition
                        print("Detected teleport attempt, position restored")
                        reverseEffect("teleport", effectSources[player])
                    end
                end
                lastKnownPosition = currentPos
            end)
        end)
    end

    -- Speed Protection
    if humanoid and typeof(humanoid) == "Instance" then
        antiAdminConnections.walkSpeed = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if not antiAdminEnabled then return end
            pcall(function()
                local currentSpeed = humanoid.WalkSpeed
                if math.abs(currentSpeed - lastKnownWalkSpeed) > 50 then
                    humanoid.WalkSpeed = lastKnownWalkSpeed
                    print("Detected speed change attempt, speed restored")
                    reverseEffect("speed", effectSources[player])
                else
                    lastKnownWalkSpeed = currentSpeed
                end
            end)
        end)
    end

    -- Freeze Protection
    if rootPart and typeof(rootPart) == "Instance" then
        antiAdminConnections.anchored = rootPart:GetPropertyChangedSignal("Anchored"):Connect(function()
            if not antiAdminEnabled then return end
            pcall(function()
                if rootPart.Anchored and not lastKnownAnchored then
                    rootPart.Anchored = false
                    print("Detected freeze attempt, unanchored")
                    reverseEffect("freeze", effectSources[player])
                end
                lastKnownAnchored = rootPart.Anchored
            end)
        end)
    end
end

-- Function to setup anti-remote exploit protection
local function setupAntiRemoteExploit()
    pcall(function()
        local mt = getrawmetatable(game)
        if not mt then return end
        
        oldNamecall = mt.__namecall
        if not oldNamecall then return end
        
        setreadonly(mt, false)

        mt.__namecall = function(self, ...)
            if not antiAdminEnabled then return oldNamecall(self, ...) end
            
            local method = getnamecallmethod()
            if (method == "FireServer" or method == "InvokeServer") and not allowedRemotes[self] then
                print("Blocked unauthorized Remote call: " .. tostring(self.Name))
                -- Attempt to identify the source player (simulated)
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= player and hasAntiAdmin(p) then
                        effectSources[player] = p
                        print("Suspected admin remote from: " .. p.Name)
                        break
                    end
                end
                return nil
            end
            return oldNamecall(self, ...)
        end

        setreadonly(mt, true)
    end)
end

-- Run background function
function AntiAdmin.runBackground()
    antiAdminEnabled = true
    print("Anti Admin Protection running in background")

    -- Initialize allowed animations
    allowedAnimations["rbxassetid://0"] = true

    -- Start background tasks
    spawn(function()
        while antiAdminEnabled do
            pcall(function()
                updateProtectedPlayers()
                updateToolCache()
            end)
            wait(10)
        end
    end)

    -- Setup protection if character exists
    if character and humanoid and rootPart then
        handleAntiAdmin()
    end
    
    setupAntiRemoteExploit()

    -- Handle character respawning
    player.CharacterAdded:Connect(function(newCharacter)
        wait(0.5)
        character = newCharacter
        humanoid = character:WaitForChild("Humanoid", 10)
        rootPart = character:WaitForChild("HumanoidRootPart", 10)
        backpack = player:WaitForChild("Backpack", 10)
        
        if humanoid and rootPart then
            lastKnownPosition = rootPart.CFrame
            lastKnownHealth = humanoid.Health
            lastKnownVelocity = rootPart.Velocity
            lastKnownWalkSpeed = humanoid.WalkSpeed
            lastKnownJumpPower = humanoid.JumpPower or humanoid.JumpHeight or 50
            lastKnownAnchored = rootPart.Anchored
            lastKnownCanCollide = rootPart.CanCollide
            lastKnownTransparency = 0
            if camera then
                lastKnownCameraSubject = camera.CameraSubject
            end
            updateToolCache()

            -- Clean up old connections
            for _, conn in pairs(antiAdminConnections) do
                if conn and typeof(conn) == "RBXScriptConnection" then
                    conn:Disconnect()
                end
            end
            antiAdminConnections = {}
            
            -- Setup new protection
            handleAntiAdmin()
        end
    end)
end

-- Reset states function
function AntiAdmin.resetStates()
    print("Resetting AntiAdmin states...")
    for _, conn in pairs(antiAdminConnections) do
        if conn and typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    antiAdminConnections = {}
    
    lastKnownHealth = 100
    lastKnownVelocity = Vector3.new(0, 0, 0)
    lastKnownWalkSpeed = 16
    lastKnownJumpPower = 50
    lastKnownAnchored = false
    lastKnownCanCollide = true
    lastKnownTransparency = 0
    lastKnownTools = {}
    effectSources = {}
    
    if adminNotificationLabel then
        adminNotificationLabel:Destroy()
        adminNotificationLabel = nil
        print("Admin notification UI destroyed")
    end
end

-- Cleanup function
function AntiAdmin.cleanup()
    antiAdminEnabled = false
    
    for _, conn in pairs(antiAdminConnections) do
        if conn and typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    antiAdminConnections = {}
    
    pcall(function()
        if oldNamecall then
            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            mt.__namecall = oldNamecall
            setreadonly(mt, true)
        end
    end)
    
    if adminNotificationLabel then
        adminNotificationLabel:Destroy()
        adminNotificationLabel = nil
        print("Admin notification UI destroyed during cleanup")
    end
end

return AntiAdmin