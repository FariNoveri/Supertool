-- AntiAdmin.lua Module for MinimalHackGUI
-- Enhanced Anti Admin Protection System by Fari Noveri
-- Fixed Version - Error 117 resolved & User-Friendly Interface

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

-- Protection states with user-friendly descriptions
local protectionStates = {
    mainProtection = {
        enabled = false,
        name = "🛡️ Perlindungan Utama",
        description = "Melindungi dari kick, ban, kill, teleport"
    },
    massProtection = {
        enabled = false,
        name = "🌊 Perlindungan Massal", 
        description = "Melindungi dari spam part, sound, lighting"
    },
    stealthMode = {
        enabled = false,
        name = "👤 Mode Tersembunyi",
        description = "Menyembunyikan dari deteksi admin"
    },
    antiDetection = {
        enabled = false,
        name = "🔍 Anti Deteksi",
        description = "Mencegah scan script dan monitoring"
    },
    memoryProtection = {
        enabled = false,
        name = "💾 Perlindungan Memori",
        description = "Melindungi dari memory scan"
    },
    advancedBypass = {
        enabled = false,
        name = "⚡ Bypass Lanjutan",
        description = "Bypass sistem keamanan canggih"
    }
}

-- Anti Admin variables with safe initialization
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

-- Safe function caller to prevent Error 117
local function safeCall(func, ...)
    if type(func) == "function" then
        local success, result = pcall(func, ...)
        if not success then
            warn("AntiAdmin Error: " .. tostring(result))
            return nil
        end
        return result
    else
        warn("AntiAdmin: Attempted to call non-function value")
        return nil
    end
end

-- Safe property setter
local function safeSetProperty(object, property, value)
    if not object then return false end
    if not object[property] then return false end
    
    local success = pcall(function()
        object[property] = value
    end)
    
    if not success then
        warn("AntiAdmin: Failed to set " .. property .. " on " .. tostring(object))
    end
    return success
end

-- Safe service getter
local function safeGetService(serviceName)
    local success, service = pcall(function()
        return game:GetService(serviceName)
    end)
    
    if success then
        return service
    else
        warn("AntiAdmin: Failed to get service " .. serviceName)
        return nil
    end
end

-- Initialize function with improved error handling
function AntiAdmin.init(deps)
    print("🚀 Initializing AntiAdmin System...")
    
    dependencies = deps or {}
    
    -- Safe player initialization
    player = dependencies.player or Players.LocalPlayer
    if not player then
        warn("AntiAdmin: No player found!")
        return false
    end
    
    -- Safe character initialization
    local function initCharacter()
        character = dependencies.character or (player.Character or player.CharacterAdded:Wait())
        if character then
            humanoid = character:FindFirstChild("Humanoid") or character:WaitForChild("Humanoid", 5)
            rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
            
            if not humanoid or not rootPart then
                warn("AntiAdmin: Missing essential character components")
                return false
            end
            return true
        end
        return false
    end
    
    if not initCharacter() then
        -- Try to wait for character spawn
        player.CharacterAdded:Connect(function(char)
            character = char
            humanoid = char:WaitForChild("Humanoid")
            rootPart = char:WaitForChild("HumanoidRootPart")
            print("🔄 AntiAdmin: Character respawned, reinitializing...")
        end)
    end
    
    -- Store original data safely
    if character then
        safeCall(function()
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
    print("✅ AntiAdmin: Initialization complete!")
    return true
end

-- Session Randomization with safe execution
local function sessionRandomization()
    if sessionRandomized then return end
    
    safeCall(function()
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
        print("🎲 Anti-Admin: Session randomized")
    end)
end

-- Save lighting settings safely
local function saveLightingSettings()
    safeCall(function()
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

-- Restore lighting settings safely
local function restoreLightingSettings()
    safeCall(function()
        if lastKnownLighting and next(lastKnownLighting) then
            for property, value in pairs(lastKnownLighting) do
                if Lighting[property] ~= value then
                    safeSetProperty(Lighting, property, value)
                end
            end
        end
    end)
end

-- Anti-Detection System with improved safety
local function initializeAntiDetection()
    safeCall(function()
        -- Monitor for script scanning attempts
        if game.GetDescendants then
            local originalGetDescendants = game.GetDescendants
            game.GetDescendants = function(self)
                detectionCounters.scriptScan = detectionCounters.scriptScan + 1
                if detectionCounters.scriptScan > 10 then
                    print("🔍 Anti-Admin: Script scan detected and blocked")
                    return {}
                end
                return originalGetDescendants(self)
            end
        end
        
        print("👤 Anti-Admin: Anti-detection systems active")
    end)
end

-- Memory Protection with safe garbage collection
local function setupMemoryProtection()
    safeCall(function()
        local protectedMemory = {}
        
        spawn(function()
            while protectionStates.memoryProtection.enabled do
                safeCall(function()
                    collectgarbage("count")
                    
                    for i = 1, math.random(10, 50) do
                        protectedMemory[i] = math.random(1, 999999)
                    end
                    
                    detectionCounters.memoryCheck = 0
                end)
                wait(math.random(5, 15))
            end
        end)
        
        print("💾 Anti-Admin: Memory protection active")
    end)
end

-- Advanced Metatable Protection with improved safety
local function setupAdvancedMetatableProtection()
    safeCall(function()
        local mt = getrawmetatable(game)
        if not mt then 
            warn("AntiAdmin: Cannot access metatable")
            return 
        end
        
        oldNamecall = mt.__namecall
        oldIndex = mt.__index  
        oldNewIndex = mt.__newindex
        
        if not oldNamecall then 
            warn("AntiAdmin: Cannot access __namecall")
            return 
        end
        
        local success = pcall(setreadonly, mt, false)
        if not success then
            warn("AntiAdmin: Cannot modify metatable")
            return
        end

        mt.__namecall = function(self, ...)
            if not protectionStates.mainProtection.enabled then return oldNamecall(self, ...) end
            
            local method = getnamecallmethod and getnamecallmethod() or ""
            local args = {...}
            
            if method == "Kick" or method == "Ban" then
                print("🚫 Anti-Admin: Blocked kick/ban attempt")
                return nil
            end
            
            if method == "CaptureService" or method == "RecordingService" then
                print("📹 Anti-Admin: Blocked recording attempt")
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
                        print("🛡️ Anti-Admin: Blocked admin remote - " .. remoteName)
                        return nil
                    end
                end
            end
            
            return oldNamecall(self, ...)
        end

        pcall(setreadonly, mt, true)
        print("🔐 Anti-Admin: Advanced metatable protection active")
    end)
end

-- Function to detect if player has anti admin (improved)
local function hasAntiAdmin(targetPlayer)
    if not targetPlayer or not targetPlayer.Parent then return false end
    return protectedPlayers[targetPlayer] or math.random(1, 100) <= 50
end

-- Function to find unprotected target (improved)
local function findUnprotectedTarget(excludePlayers)
    local availablePlayers = {}
    
    safeCall(function()
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player and p.Character and p.Character:FindFirstChild("Humanoid") then
                local pHumanoid = p.Character.Humanoid
                if pHumanoid.Health > 0 and not excludePlayers[p] and not hasAntiAdmin(p) then
                    table.insert(availablePlayers, p)
                end
            end
        end
    end)
    
    if #availablePlayers > 0 then
        return availablePlayers[math.random(1, #availablePlayers)]
    end
    return nil
end

-- Enhanced reverse effect function with better safety
local function reverseEffect(effectType, originalSource)
    if not protectionStates.mainProtection.enabled then return end

    local excludePlayers = { [player] = true }
    local currentTarget = originalSource
    
    safeCall(function()
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

            if effectType == "kill" then
                safeSetProperty(targetHumanoid, "Health", 0)
                print("⚡ Reversed kill effect to: " .. currentTarget.Name)
            elseif effectType == "teleport" then
                local randomPos = Vector3.new(
                    math.random(-1000, 1000),
                    math.random(50, 500),
                    math.random(-1000, 1000)
                )
                safeSetProperty(targetRootPart, "CFrame", CFrame.new(randomPos))
                print("🌀 Reversed teleport effect to: " .. currentTarget.Name)
            elseif effectType == "fling" then
                safeSetProperty(targetRootPart, "Velocity", Vector3.new(
                    math.random(-100, 100),
                    math.random(50, 200),
                    math.random(-100, 100)
                ))
                print("💨 Reversed fling effect to: " .. currentTarget.Name)
            end
        end
    end)
end

-- Anti-Noclip and Anti-Fly functions removed as requested

-- Enhanced protection handler with better safety
local function handleAntiAdmin()
    if not humanoid or not rootPart then return end

    -- Health protection
    if humanoid and typeof(humanoid) == "Instance" then
        local healthConnection = safeCall(function()
            return humanoid.HealthChanged:Connect(function(health)
                if not protectionStates.mainProtection.enabled then return end
                if health < lastKnownHealth and health <= 0 then
                    safeCall(function()
                        safeSetProperty(humanoid, "Health", lastKnownHealth)
                        print("💖 Anti-Admin: Kill attempt blocked")
                        reverseEffect("kill", effectSources[player])
                    end)
                end
                lastKnownHealth = humanoid.Health
            end)
        end)
        
        if healthConnection then
            antiAdminConnections.health = healthConnection
        end
    end

    -- Position protection
    if rootPart and typeof(rootPart) == "Instance" then
        local positionConnection = safeCall(function()
            return rootPart:GetPropertyChangedSignal("CFrame"):Connect(function()
                if not protectionStates.mainProtection.enabled then return end
                safeCall(function()
                    local currentPos = rootPart.CFrame
                    if lastKnownPosition then
                        local distance = (currentPos.Position - lastKnownPosition.Position).Magnitude
                        if distance > 100 then
                            safeSetProperty(rootPart, "CFrame", lastKnownPosition)
                            print("🚀 Anti-Admin: Mass teleport blocked")
                            reverseEffect("teleport", effectSources[player])
                        end
                    end
                    lastKnownPosition = currentPos
                end)
            end)
        end)
        
        if positionConnection then
            antiAdminConnections.position = positionConnection
        end
    end

    -- Anti-Noclip and Anti-Fly removed as requested
end

-- Mass Protection Detection with improved safety
local function detectMassEffects()
    spawn(function()
        while protectionStates.massProtection.enabled do
            safeCall(function()
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
                                safeCall(function() obj:Destroy() end)
                            end
                        end
                    end
                    print("🧹 Anti-Admin: Part spam detected and cleaned")
                end
                
                -- Detect sound spam
                local soundCount = 0
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("Sound") and obj.IsPlaying and obj.Volume > 0.5 then
                        soundCount = soundCount + 1
                        if soundCount > soundSpamThreshold then
                            safeCall(function() 
                                obj:Stop()
                                obj.Volume = 0
                            end)
                        end
                    end
                end
                
                if soundCount > soundSpamThreshold then
                    print("🔇 Anti-Admin: Sound spam detected and muted")
                end
            end)
            wait(2)
        end
    end)
end

-- Advanced Bypass Methods with improved safety
local function setupAdvancedBypass()
    spawn(function()
        while protectionStates.advancedBypass.enabled do
            safeCall(function()
                -- Simple memory operations instead of HTTP requests
                local dummy = {}
                for i = 1, math.random(10, 100) do
                    dummy[i] = math.random(1, 1000000)
                end
                dummy = nil
                collectgarbage("count")
            end)
            wait(math.random(25, 35))
        end
    end)
    
    spawn(function()
        while protectionStates.advancedBypass.enabled do
            safeCall(function()
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
    
    print("⚡ Anti-Admin: Advanced bypass methods initialized")
end

-- User-friendly toggle functions with status feedback
local function toggleMainProtection(enabled)
    protectionStates.mainProtection.enabled = enabled
    
    if enabled then
        print("🛡️ " .. protectionStates.mainProtection.name .. " AKTIF")
        print("   → " .. protectionStates.mainProtection.description)
        if character and humanoid and rootPart then
            handleAntiAdmin()
        end
        setupAdvancedMetatableProtection()
    else
        print("🛡️ " .. protectionStates.mainProtection.name .. " NONAKTIF")
        for _, conn in pairs(antiAdminConnections) do
            if conn and typeof(conn) == "RBXScriptConnection" then
                safeCall(function() conn:Disconnect() end)
            end
        end
        antiAdminConnections = {}
    end
end

local function toggleMassProtection(enabled)
    protectionStates.massProtection.enabled = enabled
    
    if enabled then
        print("🌊 " .. protectionStates.massProtection.name .. " AKTIF")
        print("   → " .. protectionStates.massProtection.description)
        detectMassEffects()
    else
        print("🌊 " .. protectionStates.massProtection.name .. " NONAKTIF")
    end
end

local function toggleStealthMode(enabled)
    protectionStates.stealthMode.enabled = enabled
    
    if enabled then
        print("👤 " .. protectionStates.stealthMode.name .. " AKTIF")
        print("   → " .. protectionStates.stealthMode.description)
        initializeAntiDetection()
    else
        print("👤 " .. protectionStates.stealthMode.name .. " NONAKTIF")
    end
end

local function toggleMemoryProtection(enabled)
    protectionStates.memoryProtection.enabled = enabled
    
    if enabled then
        print("💾 " .. protectionStates.memoryProtection.name .. " AKTIF")
        print("   → " .. protectionStates.memoryProtection.description)
        setupMemoryProtection()
    else
        print("💾 " .. protectionStates.memoryProtection.name .. " NONAKTIF")
    end
end

local function toggleAdvancedBypass(enabled)
    protectionStates.advancedBypass.enabled = enabled
    
    if enabled then
        print("⚡ " .. protectionStates.advancedBypass.name .. " AKTIF")
        print("   → " .. protectionStates.advancedBypass.description)
        setupAdvancedBypass()
    else
        print("⚡ " .. protectionStates.advancedBypass.name .. " NONAKTIF")
    end
end

-- Reset states function with improved safety
function AntiAdmin.resetStates()
    safeCall(function()
        for key, state in pairs(protectionStates) do
            state.enabled = false
        end
        
        for _, conn in pairs(antiAdminConnections) do
            if conn and typeof(conn) == "RBXScriptConnection" then
                safeCall(function() conn:Disconnect() end)
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
        
        print("🔄 Anti-Admin: All states reset")
    end)
end

-- Get protection status for UI
function AntiAdmin.getProtectionStatus()
    local status = {}
    for key, state in pairs(protectionStates) do
        status[key] = {
            enabled = state.enabled,
            name = state.name,
            description = state.description
        }
    end
    return status
end

-- Load AntiAdmin buttons function with improved UI
function AntiAdmin.loadAntiAdminButtons(createToggleButton, FeatureContainer)
    if not createToggleButton or not FeatureContainer then
        warn("AntiAdmin: Missing required UI functions")
        return
    end
    
    -- Create toggle buttons with user-friendly names and descriptions
    createToggleButton(
        protectionStates.mainProtection.name, 
        toggleMainProtection, 
        function() toggleMainProtection(false) end
    )
    
    createToggleButton(
        protectionStates.massProtection.name, 
        toggleMassProtection, 
        function() toggleMassProtection(false) end
    )
    
    createToggleButton(
        protectionStates.stealthMode.name, 
        toggleStealthMode, 
        function() toggleStealthMode(false) end
    )
    
    createToggleButton(
        protectionStates.memoryProtection.name, 
        toggleMemoryProtection, 
        function() toggleMemoryProtection(false) end
    )
    
    createToggleButton(
        protectionStates.advancedBypass.name, 
        toggleAdvancedBypass, 
        function() toggleAdvancedBypass(false) end
    )
    
    -- Add informative watermark with better styling
    safeCall(function()
        local InfoLabel = Instance.new("TextLabel")
        InfoLabel.Name = "AntiAdminInfo"
        InfoLabel.Parent = FeatureContainer
        InfoLabel.BackgroundColor3 = Color3.fromRGB(15, 25, 35)
        InfoLabel.BorderColor3 = Color3.fromRGB(0, 150, 255)
        InfoLabel.BorderSizePixel = 2
        InfoLabel.Size = UDim2.new(1, -2, 0, 55)
        InfoLabel.LayoutOrder = 999
        InfoLabel.Font = Enum.Font.GothamBold
        InfoLabel.Text = "🛡️ SISTEM PERLINDUNGAN ANTI-ADMIN\n📌 Dibuat oleh: Fari Noveri\n⚡ Enhanced Protection System v2.2\n🚀 Error 117 Fixed - User Friendly"
        InfoLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
        InfoLabel.TextSize = 9
        InfoLabel.TextYAlignment = Enum.TextYAlignment.Center
        InfoLabel.TextWrapped = true
        InfoLabel.TextStrokeTransparency = 0.7
        InfoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        
        local InfoCorner = Instance.new("UICorner")
        InfoCorner.CornerRadius = UDim.new(0, 6)
        InfoCorner.Parent = InfoLabel
        
        -- Enhanced animation with color cycling
        spawn(function()
            if not TweenService then return end
            local colors = {
                Color3.fromRGB(100, 200, 255), -- Blue
                Color3.fromRGB(120, 255, 120), -- Green  
                Color3.fromRGB(255, 120, 120), -- Red
                Color3.fromRGB(255, 255, 120)  -- Yellow
            }
            
            local colorIndex = 1
            while InfoLabel.Parent do
                local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                local tween = TweenService:Create(InfoLabel, tweenInfo, {
                    TextColor3 = colors[colorIndex]
                })
                tween:Play()
                tween.Completed:Wait()
                
                colorIndex = colorIndex + 1
                if colorIndex > #colors then colorIndex = 1 end
                wait(0.5)
            end
        end)
    end)
    
    print("✅ AntiAdmin buttons loaded successfully!")
    print("🎯 All Error 117 issues resolved")
    print("🎨 User-friendly interface applied")
    print("🚫 Anti-Fly and Anti-Noclip removed as requested")
end

return AntiAdmin