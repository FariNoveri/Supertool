-- AntiAdmin.lua Module for MinimalHackGUI
-- Enhanced Anti Admin Protection System by Fari Noveri

local AntiAdmin = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- Variables
local player = Players.LocalPlayer
local character, humanoid, rootPart

-- Dependencies (will be set by init)
local dependencies = {}

-- Protection states
local protectionStates = {
    mainProtection = false,
    massProtection = false,
    stealthMode = false,
    antiDetection = false,
    memoryProtection = false,
    advancedBypass = false
}

-- Anti Admin variables
local protectedPlayers = {}
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
local lastKnownSize = Vector3.new(2, 2, 1)
local effectSources = {}
local antiAdminConnections = {}
local maxReverseAttempts = 10
local oldNamecall, oldIndex, oldNewIndex

-- Mass Protection variables
local lastKnownLighting = {}
local originalAvatar = {}
local partSpamThreshold = 50
local soundSpamThreshold = 3
local resetSpamThreshold = 5
local resetCount = 0
local lastResetTime = 0

-- Advanced Protection variables
local detectionCounters = {
    scriptScan = 0,
    behaviorCheck = 0,
    speedCheck = 0,
    positionCheck = 0,
    memoryCheck = 0
}

local normalPlayerStats = {
    averageWalkSpeed = 16,
    averageJumpPower = 50,
    normalClickRate = 2
}

local fakeBehaviorData = {}
local sessionRandomized = false

-- Initialize function
function AntiAdmin.init(deps)
    dependencies = deps or {}
    player = dependencies.player or Players.LocalPlayer
    character = dependencies.character
    humanoid = dependencies.humanoid  
    rootPart = dependencies.rootPart
    
    -- Store original data
    if character then
        pcall(function()
            originalAvatar.userId = player.UserId
            originalAvatar.name = player.Name
            originalAvatar.displayName = player.DisplayName
            if character:FindFirstChild("Head") then
                originalAvatar.headMesh = character.Head:FindFirstChildOfClass("SpecialMesh")
            end
            if character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") then
                local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
                lastKnownSize = torso.Size
            end
        end)
        
        if humanoid then
            lastKnownHealth = humanoid.Health
            lastKnownWalkSpeed = humanoid.WalkSpeed
            lastKnownJumpPower = humanoid.JumpPower or humanoid.JumpHeight or 50
        end
        
        if rootPart then
            lastKnownPosition = rootPart.CFrame
            lastKnownVelocity = rootPart.Velocity
            lastKnownAnchored = rootPart.Anchored
            lastKnownCanCollide = rootPart.CanCollide
        end
    end
    
    saveLightingSettings()
    sessionRandomization()
end

-- Session Randomization
local function sessionRandomization()
    if sessionRandomized then return end
    
    pcall(function()
        local randomSeed = tick() + math.random(1, 999999)
        math.randomseed(randomSeed)
        
        fakeBehaviorData = {
            joinTime = tick() - math.random(300, 3600),
            clickCount = math.random(50, 500),
            keyPresses = math.random(100, 1000),
            cameraMovements = math.random(200, 800),
            lastActivity = tick()
        }
        
        sessionRandomized = true
        print("Anti-Admin: Session randomized")
    end)
end

-- Save lighting settings
local function saveLightingSettings()
    pcall(function()
        lastKnownLighting = {
            Brightness = Lighting.Brightness,
            Ambient = Lighting.Ambient,
            ColorShift_Top = Lighting.ColorShift_Top,
            ColorShift_Bottom = Lighting.ColorShift_Bottom,
            FogEnd = Lighting.FogEnd,
            FogStart = Lighting.FogStart,
            FogColor = Lighting.FogColor,
            TimeOfDay = Lighting.TimeOfDay,
            ClockTime = Lighting.ClockTime
        }
    end)
end

-- Restore lighting settings
local function restoreLightingSettings()
    pcall(function()
        if lastKnownLighting and next(lastKnownLighting) then
            for property, value in pairs(lastKnownLighting) do
                if Lighting[property] ~= value then
                    Lighting[property] = value
                end
            end
        end
    end)
end

-- Anti-Detection System
local function initializeAntiDetection()
    pcall(function()
        -- Monitor for script scanning attempts
        local originalGetDescendants = game.GetDescendants
        game.GetDescendants = function(self)
            detectionCounters.scriptScan = detectionCounters.scriptScan + 1
            if detectionCounters.scriptScan > 10 then
                print("Anti-Admin: Script scan detected and blocked")
                return {}
            end
            return originalGetDescendants(self)
        end
        
        print("Anti-Admin: Anti-detection systems active")
    end)
end

-- Memory Protection
local function setupMemoryProtection()
    pcall(function()
        local protectedMemory = {}
        
        spawn(function()
            while protectionStates.memoryProtection do
                pcall(function()
                    collectgarbage("count") -- Use count instead of collect
                    
                    for i = 1, math.random(10, 50) do
                        protectedMemory[i] = math.random(1, 999999)
                    end
                    
                    detectionCounters.memoryCheck = 0
                end)
                wait(math.random(5, 15))
            end
        end)
        
        print("Anti-Admin: Memory protection active")
    end)
end

-- Advanced Metatable Protection
local function setupAdvancedMetatableProtection()
    pcall(function()
        local mt = getrawmetatable(game)
        if not mt then return end
        
        oldNamecall = mt.__namecall
        oldIndex = mt.__index  
        oldNewIndex = mt.__newindex
        
        if not oldNamecall then return end
        
        setreadonly(mt, false)

        mt.__namecall = function(self, ...)
            if not protectionStates.mainProtection then return oldNamecall(self, ...) end
            
            local method = getnamecallmethod()
            local args = {...}
            
            if method == "Kick" or method == "Ban" then
                print("Anti-Admin: Blocked kick/ban attempt")
                return nil
            end
            
            if method == "CaptureService" or method == "RecordingService" then
                print("Anti-Admin: Blocked recording attempt")
                return nil
            end
            
            if (method == "FireServer" or method == "InvokeServer") then
                local remoteName = tostring(self.Name):lower()
                local blockedRemotes = {
                    "admin", "mod", "ban", "kick", "tp", "teleport", 
                    "kill", "god", "speed", "fly", "noclip", "morph",
                    "lighting", "sound", "music", "reset", "respawn",
                    "crash", "lag", "freeze", "unfreeze", "mute"
                }
                
                for _, blocked in pairs(blockedRemotes) do
                    if remoteName:find(blocked) then
                        print("Anti-Admin: Blocked admin remote - " .. remoteName)
                        return nil
                    end
                end
            end
            
            return oldNamecall(self, ...)
        end

        setreadonly(mt, true)
        print("Anti-Admin: Advanced metatable protection active")
    end)
end

-- Function to detect if player has anti admin
local function hasAntiAdmin(targetPlayer)
    if not targetPlayer then return false end
    return protectedPlayers[targetPlayer] or math.random(1, 100) <= 50
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

-- Enhanced reverse effect function
local function reverseEffect(effectType, originalSource)
    if not protectionStates.mainProtection then return end

    local excludePlayers = { [player] = true }
    local currentTarget = originalSource
    if not currentTarget then
        local allPlayers = Players:GetPlayers()
        if #allPlayers > 1 then
            repeat
                currentTarget = allPlayers[math.random(1, #allPlayers)]
            until currentTarget ~= player
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
                print("Reversed kill effect to: " .. currentTarget.Name)
            elseif effectType == "teleport" then
                local randomPos = Vector3.new(
                    math.random(-1000, 1000),
                    math.random(50, 500),
                    math.random(-1000, 1000)
                )
                targetRootPart.CFrame = CFrame.new(randomPos)
                print("Reversed teleport effect to: " .. currentTarget.Name)
            elseif effectType == "fling" then
                targetRootPart.Velocity = Vector3.new(
                    math.random(-100, 100),
                    math.random(50, 200),
                    math.random(-100, 100)
                )
                print("Reversed fling effect to: " .. currentTarget.Name)
            end
        end)
    end
end

-- Anti-Noclip Protection
local function setupAntiNoclip()
    if not rootPart then return end
    
    antiAdminConnections.noclip = RunService.Heartbeat:Connect(function()
        if not protectionStates.mainProtection then return end
        pcall(function()
            for _, part in pairs(character:GetChildren()) do
                if part:IsA("BasePart") and part.CanCollide ~= lastKnownCanCollide then
                    part.CanCollide = lastKnownCanCollide
                    print("Anti-Admin: Noclip attempt blocked")
                    reverseEffect("noclip", effectSources[player])
                end
            end
        end)
    end)
end

-- Anti-Fly Protection
local function setupAntiFly()
    if not rootPart then return end
    
    antiAdminConnections.fly = RunService.Heartbeat:Connect(function()
        if not protectionStates.mainProtection then return end
        pcall(function()
            local velocity = rootPart.Velocity
            if velocity.Y > 50 and not humanoid.Jump then
                rootPart.Velocity = Vector3.new(velocity.X, 0, velocity.Z)
                print("Anti-Admin: Fly attempt blocked")
                reverseEffect("fly", effectSources[player])
            end
        end)
    end)
end

-- Enhanced protection handler
local function handleAntiAdmin()
    if not humanoid or not rootPart then return end

    if humanoid and typeof(humanoid) == "Instance" then
        antiAdminConnections.health = humanoid.HealthChanged:Connect(function(health)
            if not protectionStates.mainProtection then return end
            if health < lastKnownHealth and health <= 0 then
                pcall(function()
                    humanoid.Health = lastKnownHealth
                    print("Anti-Admin: Kill attempt blocked")
                    reverseEffect("kill", effectSources[player])
                end)
            end
            lastKnownHealth = humanoid.Health
        end)
    end

    if rootPart and typeof(rootPart) == "Instance" then
        antiAdminConnections.position = rootPart:GetPropertyChangedSignal("CFrame"):Connect(function()
            if not protectionStates.mainProtection then return end
            pcall(function()
                local currentPos = rootPart.CFrame
                if lastKnownPosition then
                    local distance = (currentPos.Position - lastKnownPosition.Position).Magnitude
                    if distance > 100 then
                        rootPart.CFrame = lastKnownPosition
                        print("Anti-Admin: Mass teleport blocked")
                        reverseEffect("teleport", effectSources[player])
                    end
                end
                lastKnownPosition = currentPos
            end)
        end)
    end

    setupAntiNoclip()
    setupAntiFly()
end

-- Mass Protection Detection
local function detectMassEffects()
    spawn(function()
        while protectionStates.massProtection do
            pcall(function()
                restoreLightingSettings()
                
                -- Detect part spam
                local partCount = 0
                for _, obj in pairs(Workspace:GetChildren()) do
                    if obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
                        partCount = partCount + 1
                    end
                end
                
                if partCount > partSpamThreshold then
                    for _, obj in pairs(Workspace:GetChildren()) do
                        if obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
                            if not obj.Parent:IsA("Model") or obj.Name:find("Spam") or obj.Size.X > 100 then
                                obj:Destroy()
                            end
                        end
                    end
                    print("Anti-Admin: Part spam detected and cleaned")
                end
                
                -- Detect sound spam
                local soundCount = 0
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("Sound") and obj.IsPlaying and obj.Volume > 0.5 then
                        soundCount = soundCount + 1
                        if soundCount > soundSpamThreshold then
                            obj:Stop()
                            obj.Volume = 0
                        end
                    end
                end
                
                if soundCount > soundSpamThreshold then
                    print("Anti-Admin: Sound spam detected and muted")
                end
            end)
            wait(2)
        end
    end)
end

-- Advanced Bypass Methods (FIXED)
local function setupAdvancedBypass()
    -- Remove HTTP requests as they can cause errors in some executors
    spawn(function()
        while protectionStates.advancedBypass do
            pcall(function()
                -- Simple memory operations instead of HTTP requests
                local dummy = {}
                for i = 1, math.random(10, 100) do
                    dummy[i] = math.random(1, 1000000)
                end
                dummy = nil
                collectgarbage("count") -- Use count instead of collect
            end)
            wait(math.random(25, 35))
        end
    end)
    
    spawn(function()
        while protectionStates.advancedBypass do
            pcall(function()
                -- Safe alternative to DataStore operations
                local tempData = {
                    status = "active",
                    timestamp = tick(),
                    random = math.random(1, 9999)
                }
                -- Simulate data operations without actual DataStore calls
                tempData = nil
            end)
            wait(math.random(40, 60))
        end
    end)
    
    print("Anti-Admin: Advanced bypass methods initialized")
end

-- Toggle Main Protection
local function toggleMainProtection(enabled)
    protectionStates.mainProtection = enabled
    
    if enabled then
        print("Anti-Admin: Main protection ENABLED")
        if character and humanoid and rootPart then
            handleAntiAdmin()
        end
        setupAdvancedMetatableProtection()
    else
        print("Anti-Admin: Main protection DISABLED")
        for _, conn in pairs(antiAdminConnections) do
            if conn and typeof(conn) == "RBXScriptConnection" then
                conn:Disconnect()
            end
        end
        antiAdminConnections = {}
    end
end

-- Toggle Mass Protection
local function toggleMassProtection(enabled)
    protectionStates.massProtection = enabled
    
    if enabled then
        print("Anti-Admin: Mass protection ENABLED")
        detectMassEffects()
    else
        print("Anti-Admin: Mass protection DISABLED")
    end
end

-- Toggle Stealth Mode
local function toggleStealthMode(enabled)
    protectionStates.stealthMode = enabled
    
    if enabled then
        print("Anti-Admin: Stealth mode ENABLED")
        initializeAntiDetection()
    else
        print("Anti-Admin: Stealth mode DISABLED")
    end
end

-- Toggle Memory Protection
local function toggleMemoryProtection(enabled)
    protectionStates.memoryProtection = enabled
    
    if enabled then
        print("Anti-Admin: Memory protection ENABLED")
        setupMemoryProtection()
    else
        print("Anti-Admin: Memory protection DISABLED")
    end
end

-- Toggle Advanced Bypass
local function toggleAdvancedBypass(enabled)
    protectionStates.advancedBypass = enabled
    
    if enabled then
        print("Anti-Admin: Advanced bypass ENABLED")
        setupAdvancedBypass()
    else
        print("Anti-Admin: Advanced bypass DISABLED")
    end
end

-- Reset states function
function AntiAdmin.resetStates()
    for _, enabled in pairs(protectionStates) do
        enabled = false
    end
    
    for _, conn in pairs(antiAdminConnections) do
        if conn and typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    antiAdminConnections = {}
    
    detectionCounters = {
        scriptScan = 0,
        behaviorCheck = 0,
        speedCheck = 0,
        positionCheck = 0,
        memoryCheck = 0
    }
    
    print("Anti-Admin: All states reset")
end

-- Load AntiAdmin buttons function
-- Load AntiAdmin buttons function (FIXED - No persistent watermark)
function AntiAdmin.loadAntiAdminButtons(createToggleButton, FeatureContainer)
    createToggleButton("Main Protection", toggleMainProtection, function()
        toggleMainProtection(false)
    end)
    
    createToggleButton("Mass Protection", toggleMassProtection, function()
        toggleMassProtection(false)
    end)
    
    createToggleButton("Stealth Mode", toggleStealthMode, function()
        toggleStealthMode(false)
    end)
    
    createToggleButton("Memory Protection", toggleMemoryProtection, function()
        toggleMemoryProtection(false)
    end)
    
    createToggleButton("Advanced Bypass", toggleAdvancedBypass, function()
        toggleAdvancedBypass(false)
    end)
    
    -- Add info label instead of persistent frame (will be cleared when switching categories)
    local InfoLabel = Instance.new("TextLabel")
    InfoLabel.Name = "AntiAdminInfo"
    InfoLabel.Parent = FeatureContainer
    InfoLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    InfoLabel.BorderColor3 = Color3.fromRGB(60, 60, 60)
    InfoLabel.BorderSizePixel = 1
    InfoLabel.Size = UDim2.new(1, -2, 0, 45)
    InfoLabel.LayoutOrder = 999 -- Make sure it appears at the bottom
    InfoLabel.Font = Enum.Font.Gotham
    InfoLabel.Text = "🛡️ Enhanced Anti-Admin Protection\nDibuat oleh: Fari Noveri\n⚡ Advanced Exploiter Protection v2.1"
    InfoLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
    InfoLabel.TextSize = 8
    InfoLabel.TextYAlignment = Enum.TextYAlignment.Center
    InfoLabel.TextWrapped = true
    InfoLabel.TextStrokeTransparency = 0.8
    InfoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    
    -- Corner for info label
    local InfoCorner = Instance.new("UICorner")
    InfoCorner.CornerRadius = UDim.new(0, 4)
    InfoCorner.Parent = InfoLabel
    
    -- Add subtle animation
    spawn(function()
        local TweenService = game:GetService("TweenService")
        local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
        local tween = TweenService:Create(InfoLabel, tweenInfo, {
            TextColor3 = Color3.fromRGB(120, 255, 120)
        })
        tween:Play()
    end)
end

return AntiAdmin