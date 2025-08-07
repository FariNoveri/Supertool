local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local backpack = player:WaitForChild("Backpack")
local camera = Workspace.CurrentCamera

-- GUI untuk notifikasi
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AntiAdminGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player.PlayerGui

-- Frame untuk notifikasi
local notificationFrame = Instance.new("Frame")
notificationFrame.Name = "NotificationFrame"
notificationFrame.Size = UDim2.new(0, 350, 0, 300)
notificationFrame.Position = UDim2.new(1, -370, 0, 20)
notificationFrame.BackgroundTransparency = 1
notificationFrame.Parent = screenGui

-- Variabel untuk Anti Admin
local antiAdminEnabled = true
local protectedPlayers = {}
local detectedExploiters = {}
local detectedAdmins = {}
local playerProfiles = {} -- Profile setiap player untuk analisis
local lastKnownPosition = rootPart and rootPart.CFrame or CFrame.new(0, 0, 0)
local lastKnownHealth = humanoid and humanoid.Health or 100
local lastKnownVelocity = rootPart and rootPart.Velocity or Vector3.new(0, 0, 0)
local lastKnownWalkSpeed = humanoid and humanoid.WalkSpeed or 16
local lastKnownJumpPower = humanoid and humanoid.JumpPower or 50
local lastKnownAnchored = rootPart and rootPart.Anchored or false
local lastKnownCameraSubject = camera and camera.CameraSubject or humanoid
local lastKnownTools = {}
local effectSources = {}
local antiAdminConnections = {}
local exploiterConnections = {}
local maxReverseAttempts = 10
local notifications = {}

-- Known Admin/Staff IDs (dapat diupdate)
local knownAdminIds = {
    261, -- ROBLOX
    1, -- Admin
    156, -- builderman
    -- Tambahkan ID admin game ini
}

-- Advanced Exploit Detection Patterns
local exploitSignatures = {
    -- Executor-specific patterns
    synapse = {
        functions = {"syn", "Synapse", "getgenv", "secure_call"},
        globals = {"syn_clipboard_get", "syn_io_read", "syn_io_write", "syn_request"},
        properties = {"synx", "Syn"}
    },
    krnl = {
        functions = {"krnl", "Krnl", "krnlss"},
        globals = {"krnl_request", "krnl_HttpGet"},
        properties = {"krnlx"}
    },
    scriptware = {
        functions = {"ScriptWare", "script_ware", "SW"},
        globals = {"sw_request", "scriptware_version"},
        properties = {"swx"}
    },
    jjsploit = {
        functions = {"jj", "JJ", "JJSploit"},
        globals = {"jjsploit_version"},
        properties = {"jjx"}
    },
    -- Universal patterns
    universal = {
        functions = {"loadstring", "getfenv", "setfenv", "debug", "getupvalue", "setupvalue"},
        globals = {"_G", "shared", "getgenv", "getrenv", "getfenv", "setfenv"},
        properties = {"HttpGet", "HttpPost", "request"}
    }
}

-- Player behavior analysis
local function createPlayerProfile(targetPlayer)
    if playerProfiles[targetPlayer] then return end
    
    playerProfiles[targetPlayer] = {
        joinTime = tick(),
        suspicionLevel = 0,
        behaviorFlags = {},
        lastPositions = {},
        lastHealths = {},
        lastSpeeds = {},
        toolHistory = {},
        chatHistory = {},
        exploitType = "Unknown",
        isConfirmed = false,
        detectionMethods = {}
    }
end

-- Fungsi untuk membuat notifikasi
local function createNotification(text, color, duration)
    local notification = Instance.new("TextLabel")
    notification.Size = UDim2.new(1, 0, 0, 30)
    notification.BackgroundColor3 = color or Color3.fromRGB(255, 0, 0)
    notification.BackgroundTransparency = 0.2
    notification.BorderSizePixel = 0
    notification.Text = text
    notification.TextColor3 = Color3.fromRGB(255, 255, 255)
    notification.TextScaled = true
    notification.Font = Enum.Font.GothamBold
    notification.Parent = notificationFrame
    
    -- Rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notification
    
    -- Posisi notifikasi
    local yPos = #notifications * 35
    notification.Position = UDim2.new(0, 0, 0, yPos)
    
    table.insert(notifications, notification)
    
    -- Animasi masuk
    notification:TweenPosition(
        UDim2.new(0, 0, 0, yPos),
        Enum.EasingDirection.Out,
        Enum.EasingStyle.Bounce,
        0.5
    )
    
    -- Auto remove setelah durasi
    spawn(function()
        wait(duration or 10)
        notification:TweenPosition(
            UDim2.new(1, 0, 0, yPos),
            Enum.EasingDirection.In,
            Enum.EasingStyle.Quad,
            0.5
        )
        wait(0.5)
        
        -- Remove dari array
        for i, v in pairs(notifications) do
            if v == notification then
                table.remove(notifications, i)
                break
            end
        end
        
        notification:Destroy()
        
        -- Reposisi notifikasi lainnya
        for i, notif in pairs(notifications) do
            notif:TweenPosition(
                UDim2.new(0, 0, 0, (i-1) * 35),
                Enum.EasingDirection.Out,
                Enum.EasingStyle.Quad,
                0.3
            )
        end
    end)
end

-- Advanced exploit detection berdasarkan environment
local function detectExploitEnvironment()
    local exploitDetected = false
    local exploitType = "Unknown"
    local detectionMethods = {}
    
    -- Check for common exploit functions
    local testFunctions = {
        "getgenv", "getrenv", "getfenv", "setfenv", "debug.getupvalue", 
        "debug.setupvalue", "syn", "Synapse", "krnl", "ScriptWare",
        "loadstring", "HttpGet", "HttpPost", "request", "http_request",
        "syn_request", "krnl_request", "game.HttpGet", "game.HttpPost"
    }
    
    for _, func in pairs(testFunctions) do
        local success = pcall(function()
            local parts = string.split(func, ".")
            local obj = _G
            for _, part in pairs(parts) do
                if obj and obj[part] then
                    obj = obj[part]
                else
                    obj = nil
                    break
                end
            end
            return obj ~= nil
        end)
        
        if success then
            exploitDetected = true
            table.insert(detectionMethods, func)
            
            -- Determine exploit type based on function
            if string.find(func:lower(), "syn") then
                exploitType = "Synapse X"
            elseif string.find(func:lower(), "krnl") then
                exploitType = "KRNL"
            elseif string.find(func:lower(), "script") then
                exploitType = "ScriptWare"
            elseif func == "loadstring" or func == "HttpGet" then
                exploitType = "Generic Executor"
            end
        end
    end
    
    -- Check for exploit-specific globals
    local exploitGlobals = {"syn", "krnl", "ScriptWare", "JJSploit", "Fluxus", "Delta"}
    for _, global in pairs(exploitGlobals) do
        if _G[global] then
            exploitDetected = true
            exploitType = global
            table.insert(detectionMethods, "Global: " .. global)
        end
    end
    
    -- Check for common exploit patterns in environment
    local function checkEnvironment(env)
        for name, value in pairs(env) do
            if type(name) == "string" then
                local lowerName = string.lower(name)
                local suspiciousPatterns = {
                    "exploit", "hack", "cheat", "script", "loader", 
                    "inject", "execute", "bypass", "admin", "god"
                }
                
                for _, pattern in pairs(suspiciousPatterns) do
                    if string.find(lowerName, pattern) then
                        exploitDetected = true
                        table.insert(detectionMethods, "Suspicious global: " .. name)
                        if exploitType == "Unknown" then
                            exploitType = "Custom Executor"
                        end
                    end
                end
            end
        end
    end
    
    -- Safely check environments
    pcall(function() checkEnvironment(_G) end)
    pcall(function() checkEnvironment(shared) end)
    pcall(function() checkEnvironment(getfenv(0)) end)
    
    return exploitDetected, exploitType, detectionMethods
end

-- Detect exploit berdasarkan script analysis
local function detectScriptExploit(targetPlayer)
    if not targetPlayer.Character then return false end
    
    local suspicious = false
    local exploitType = "Unknown"
    local methods = {}
    
    -- Check player's scripts (LocalScripts in StarterPlayerScripts)
    local playerScripts = targetPlayer:FindFirstChild("PlayerScripts")
    if playerScripts then
        local function checkScript(script)
            if script:IsA("LocalScript") or script:IsA("ModuleScript") then
                -- Check script source for exploit patterns
                local success, source = pcall(function()
                    return script.Source
                end)
                
                if success and source then
                    local lowerSource = string.lower(source)
                    local exploitPatterns = {
                        "loadstring", "getfenv", "setfenv", "debug%.", "syn%.", 
                        "krnl", "synapse", "script%-?ware", "jjsploit", "exploit",
                        "httpget", "httppost", "request%(", "game%.httpget"
                    }
                    
                    for _, pattern in pairs(exploitPatterns) do
                        if string.find(lowerSource, pattern) then
                            suspicious = true
                            exploitType = "Script-based Exploit"
                            table.insert(methods, "Pattern: " .. pattern)
                        end
                    end
                end
            end
        end
        
        for _, script in pairs(playerScripts:GetDescendants()) do
            checkScript(script)
        end
    end
    
    return suspicious, exploitType, methods
end

-- Advanced player behavior analysis
local function analyzePlayerBehavior(targetPlayer)
    local profile = playerProfiles[targetPlayer]
    if not profile then return false end
    
    local suspicious = false
    local reasons = {}
    
    -- Analyze join time vs behavior (exploiters often act quickly)
    local timeSinceJoin = tick() - profile.joinTime
    if timeSinceJoin < 10 and profile.suspicionLevel > 3 then
        suspicious = true
        table.insert(reasons, "Suspicious behavior too quickly after joining")
    end
    
    -- Analyze position patterns
    if #profile.lastPositions >= 5 then
        local positionJumps = 0
        for i = 2, #profile.lastPositions do
            local distance = (profile.lastPositions[i] - profile.lastPositions[i-1]).Magnitude
            if distance > 50 then
                positionJumps = positionJumps + 1
            end
        end
        
        if positionJumps >= 3 then
            suspicious = true
            table.insert(reasons, "Multiple position jumps detected")
        end
    end
    
    -- Analyze speed patterns
    if #profile.lastSpeeds >= 3 then
        local abnormalSpeeds = 0
        for _, speed in pairs(profile.lastSpeeds) do
            if speed > 50 or speed < 0 then
                abnormalSpeeds = abnormalSpeeds + 1
            end
        end
        
        if abnormalSpeeds >= 2 then
            suspicious = true
            table.insert(reasons, "Abnormal speeds detected")
        end
    end
    
    return suspicious, reasons
end

-- Ultimate exploit detection
local function ultimateExploitDetection(targetPlayer)
    if targetPlayer == player then return false end
    
    createPlayerProfile(targetPlayer)
    local profile = playerProfiles[targetPlayer]
    
    local isExploiter = false
    local exploitType = "Unknown"
    local detectionMethods = {}
    local confidence = 0
    
    -- Method 1: Environment detection (if it's our own player)
    if targetPlayer == player then
        local envDetected, envType, envMethods = detectExploitEnvironment()
        if envDetected then
            isExploiter = true
            exploitType = envType
            detectionMethods = envMethods
            confidence = confidence + 50
        end
    end
    
    -- Method 2: Script analysis
    local scriptDetected, scriptType, scriptMethods = detectScriptExploit(targetPlayer)
    if scriptDetected then
        isExploiter = true
        if exploitType == "Unknown" then exploitType = scriptType end
        for _, method in pairs(scriptMethods) do
            table.insert(detectionMethods, method)
        end
        confidence = confidence + 30
    end
    
    -- Method 3: Behavior analysis
    local behaviorSuspicious, behaviorReasons = analyzePlayerBehavior(targetPlayer)
    if behaviorSuspicious then
        isExploiter = true
        if exploitType == "Unknown" then exploitType = "Behavioral Detection" end
        for _, reason in pairs(behaviorReasons) do
            table.insert(detectionMethods, reason)
        end
        confidence = confidence + 20
    end
    
    -- Method 4: Character properties analysis
    if targetPlayer.Character then
        local humanoidCheck = targetPlayer.Character:FindFirstChild("Humanoid")
        local rootPartCheck = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        
        if humanoidCheck and rootPartCheck then
            -- Update profile data
            table.insert(profile.lastPositions, rootPartCheck.Position)
            if #profile.lastPositions > 10 then
                table.remove(profile.lastPositions, 1)
            end
            
            table.insert(profile.lastSpeeds, humanoidCheck.WalkSpeed)
            if #profile.lastSpeeds > 10 then
                table.remove(profile.lastSpeeds, 1)
            end
            
            table.insert(profile.lastHealths, humanoidCheck.Health)
            if #profile.lastHealths > 10 then
                table.remove(profile.lastHealths, 1)
            end
            
            -- Immediate red flags
            if humanoidCheck.WalkSpeed > 100 or humanoidCheck.WalkSpeed < 0 then
                isExploiter = true
                exploitType = "Speed Exploit"
                table.insert(detectionMethods, "Abnormal WalkSpeed: " .. humanoidCheck.WalkSpeed)
                confidence = confidence + 40
            end
            
            if humanoidCheck.JumpPower > 200 or humanoidCheck.JumpPower < 0 then
                isExploiter = true
                exploitType = "Jump Exploit"
                table.insert(detectionMethods, "Abnormal JumpPower: " .. humanoidCheck.JumpPower)
                confidence = confidence + 40
            end
            
            if rootPartCheck.Position.Y > 300 and rootPartCheck.Velocity.Y > -5 then
                isExploiter = true
                exploitType = "Fly Exploit"
                table.insert(detectionMethods, "Flying at Y: " .. rootPartCheck.Position.Y)
                confidence = confidence + 35
            end
            
            if rootPartCheck.Velocity.Magnitude > 150 then
                isExploiter = true
                exploitType = "Velocity Exploit"
                table.insert(detectionMethods, "Extreme velocity: " .. rootPartCheck.Velocity.Magnitude)
                confidence = confidence + 35
            end
        end
    end
    
    -- Method 5: Tool analysis
    local suspiciousTools = 0
    local toolNames = {}
    
    for _, tool in pairs(targetPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            table.insert(toolNames, tool.Name)
            local toolName = string.lower(tool.Name)
            
            -- Advanced tool pattern matching
            local exploitToolPatterns = {
                "admin", "exploit", "script", "hack", "cheat", "god", "kill", 
                "ban", "kick", "fly", "speed", "teleport", "noclip", "inf",
                "yield", "dex", "spy", "hub", "loader", "executor"
            }
            
            for _, pattern in pairs(exploitToolPatterns) do
                if string.find(toolName, pattern) then
                    suspiciousTools = suspiciousTools + 1
                    table.insert(detectionMethods, "Suspicious tool: " .. tool.Name)
                end
            end
        end
    end
    
    if targetPlayer.Character then
        for _, tool in pairs(targetPlayer.Character:GetChildren()) do
            if tool:IsA("Tool") then
                table.insert(toolNames, tool.Name)
                local toolName = string.lower(tool.Name)
                
                local exploitToolPatterns = {
                    "admin", "exploit", "script", "hack", "cheat", "god", "kill", 
                    "ban", "kick", "fly", "speed", "teleport", "noclip", "inf",
                    "yield", "dex", "spy", "hub", "loader", "executor"
                }
                
                for _, pattern in pairs(exploitToolPatterns) do
                    if string.find(toolName, pattern) then
                        suspiciousTools = suspiciousTools + 1
                        table.insert(detectionMethods, "Suspicious equipped tool: " .. tool.Name)
                    end
                end
            end
        end
    end
    
    if suspiciousTools >= 1 then
        isExploiter = true
        if exploitType == "Unknown" then exploitType = "Tool-based Exploit" end
        confidence = confidence + (suspiciousTools * 25)
    end
    
    -- Method 6: Account analysis
    if targetPlayer.AccountAge < 30 then
        confidence = confidence + 10
        table.insert(detectionMethods, "New account (Age: " .. targetPlayer.AccountAge .. ")")
    end
    
    -- Update profile
    profile.exploitType = exploitType
    profile.detectionMethods = detectionMethods
    profile.isConfirmed = confidence >= 70
    
    return isExploiter and confidence >= 50, exploitType, detectionMethods, confidence
end

-- Check if player is admin
local function isAdmin(targetPlayer)
    return table.find(knownAdminIds, targetPlayer.UserId) ~= nil
end

-- Scan player dengan detection yang comprehensive
local function scanPlayer(targetPlayer)
    if targetPlayer == player then return end
    
    -- Admin check
    if isAdmin(targetPlayer) then
        if not detectedAdmins[targetPlayer] then
            detectedAdmins[targetPlayer] = true
            createNotification("ADMIN DETECTED: " .. targetPlayer.Name, Color3.fromRGB(255, 165, 0), 15)
            print("Admin detected: " .. targetPlayer.Name .. " (ID: " .. targetPlayer.UserId .. ")")
        end
        return -- Don't flag admins as exploiters
    end
    
    -- Exploit detection
    local isExploiter, exploitType, methods, confidence = ultimateExploitDetection(targetPlayer)
    
    if isExploiter and not detectedExploiters[targetPlayer] then
        detectedExploiters[targetPlayer] = {
            type = exploitType,
            methods = methods,
            confidence = confidence,
            time = tick()
        }
        
        local confidenceText = ""
        if confidence >= 90 then
            confidenceText = " (CERTAIN)"
        elseif confidence >= 70 then
            confidenceText = " (LIKELY)"
        else
            confidenceText = " (POSSIBLE)"
        end
        
        createNotification(
            "EXPLOIT DETECTED: " .. targetPlayer.Name .. " (" .. exploitType .. ")" .. confidenceText, 
            Color3.fromRGB(255, 0, 0), 
            20
        )
        
        print("Exploiter detected: " .. targetPlayer.Name .. " - " .. exploitType .. " (Confidence: " .. confidence .. "%)")
        print("Detection methods: " .. table.concat(methods, ", "))
    end
end

-- Continuous scanning system
local function continuousScan()
    spawn(function()
        while antiAdminEnabled do
            for _, targetPlayer in pairs(Players:GetPlayers()) do
                if targetPlayer ~= player then
                    scanPlayer(targetPlayer)
                end
            end
            wait(0.5) -- Scan setiap 0.5 detik untuk deteksi real-time
        end
    end)
end

-- Instant detection saat player join
local function onPlayerAdded(newPlayer)
    spawn(function()
        -- Immediate scan
        scanPlayer(newPlayer)
        
        -- Wait for character and scan again
        local function onCharacterAdded(character)
            wait(0.1) -- Minimal wait
            scanPlayer(newPlayer)
        end
        
        exploiterConnections[newPlayer] = {}
        exploiterConnections[newPlayer].characterAdded = newPlayer.CharacterAdded:Connect(onCharacterAdded)
        
        if newPlayer.Character then
            onCharacterAdded(newPlayer.Character)
        end
        
        -- Continuous monitoring for this specific player
        spawn(function()
            while newPlayer.Parent == Players and antiAdminEnabled do
                scanPlayer(newPlayer)
                wait(1)
            end
        end)
    end)
end

local function onPlayerRemoving(leavingPlayer)
    -- Clean up
    if exploiterConnections[leavingPlayer] then
        for _, connection in pairs(exploiterConnections[leavingPlayer]) do
            if connection then
                connection:Disconnect()
            end
        end
        exploiterConnections[leavingPlayer] = nil
    end
    
    detectedExploiters[leavingPlayer] = nil
    detectedAdmins[leavingPlayer] = nil
    playerProfiles[leavingPlayer] = nil
end

-- Rest of the protection functions remain the same...
local function updateToolCache()
    lastKnownTools = {}
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            table.insert(lastKnownTools, tool.Name)
        end
    end
end

local function hasAntiAdmin(targetPlayer)
    return protectedPlayers[targetPlayer] or math.random(1, 100) <= 50
end

local function updateProtectedPlayers()
    protectedPlayers = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            protectedPlayers[p] = math.random(1, 100) <= 50
        end
    end
end

local function findUnprotectedTarget(excludePlayers)
    local availablePlayers = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            if not excludePlayers[p] and not hasAntiAdmin(p) then
                table.insert(availablePlayers, p)
            end
        end
    end
    if #availablePlayers > 0 then
        return availablePlayers[math.random(1, #availablePlayers)]
    end
    return nil
end

local function reverseEffect(effectType, originalSource)
    if not antiAdminEnabled then return end

    local excludePlayers = { [player] = true }
    local currentTarget = originalSource or Players:GetPlayers()[math.random(1, #Players:GetPlayers())]
    local attempts = 0

    while currentTarget and hasAntiAdmin(currentTarget) and attempts < maxReverseAttempts do
        excludePlayers[currentTarget] = true
        currentTarget = findUnprotectedTarget(excludePlayers)
        attempts = attempts + 1
    end

    if currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild("Humanoid") and currentTarget.Character:FindFirstChild("HumanoidRootPart") then
        local targetHumanoid = currentTarget.Character.Humanoid
        local targetRootPart = currentTarget.Character.HumanoidRootPart
        
        pcall(function()
            if effectType == "kill" then
                targetHumanoid.Health = 0
                print("Reversed kill effect to: " .. currentTarget.Name)
            elseif effectType == "teleport" then
                targetRootPart.CFrame = CFrame.new(Vector3.new(math.random(-1000, 1000), math.random(50, 500), math.random(-1000, 1000)))
                print("Reversed teleport effect to: " .. currentTarget.Name)
            elseif effectType == "fling" then
                targetRootPart.Velocity = Vector3.new(math.random(-100, 100), math.random(50, 200), math.random(-100, 100))
                print("Reversed fling effect to: " .. currentTarget.Name)
            elseif effectType == "freeze" then
                targetRootPart.Anchored = true
                print("Reversed freeze effect to: " .. currentTarget.Name)
            end
        end)
    end
end

-- Protection handlers
local function handleAntiAdmin()
    antiAdminConnections.health = humanoid.HealthChanged:Connect(function(health)
        if not antiAdminEnabled then return end
        if health < lastKnownHealth and health <= 0 then
            humanoid.Health = lastKnownHealth
            createNotification("KILL ATTEMPT BLOCKED", Color3.fromRGB(0, 255, 0), 5)
            reverseEffect("kill")
        end
        lastKnownHealth = humanoid.Health
    end)

    antiAdminConnections.position = rootPart:GetPropertyChangedSignal("CFrame"):Connect(function()
        if not antiAdminEnabled then return end
        local currentPos = rootPart.CFrame
        local distance = (currentPos.Position - lastKnownPosition.Position).Magnitude
        if distance > 75 then
            rootPart.CFrame = lastKnownPosition
            createNotification("TELEPORT BLOCKED", Color3.fromRGB(0, 255, 0), 5)
            reverseEffect("teleport")
        else
            lastKnownPosition = currentPos
        end
    end)

    antiAdminConnections.velocity = rootPart:GetPropertyChangedSignal("Velocity"):Connect(function()
        if not antiAdminEnabled then return end
        local currentVelocity = rootPart.Velocity
        if currentVelocity.Magnitude > 100 then
            rootPart.Velocity = lastKnownVelocity
            createNotification("FLING BLOCKED", Color3.fromRGB(0, 255, 0), 5)
            reverseEffect("fling")
        else
            lastKnownVelocity = currentVelocity
        end
    end)

    antiAdminConnections.anchored = rootPart:GetPropertyChangedSignal("Anchored"):Connect(function()
        if not antiAdminEnabled then return end
        if rootPart.Anchored and not lastKnownAnchored then
            rootPart.Anchored = false
            createNotification("FREEZE BLOCKED", Color3.fromRGB(0, 255, 0), 5)
            reverseEffect("freeze")
        end
        lastKnownAnchored = rootPart.Anchored
    end)

    antiAdminConnections.walkSpeed = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if not antiAdminEnabled then return end
        if math.abs(humanoid.WalkSpeed - lastKnownWalkSpeed) > 5 then
            humanoid.WalkSpeed = lastKnownWalkSpeed
            createNotification("SPEED CHANGE BLOCKED", Color3.fromRGB(0, 255, 0), 5)
        end
        lastKnownWalkSpeed = humanoid.WalkSpeed
    end)

    antiAdminConnections.jumpPower = humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
        if not antiAdminEnabled then return end
        if math.abs(humanoid.JumpPower - lastKnownJumpPower) > 5 then
            humanoid.JumpPower = lastKnownJumpPower
            createNotification("JUMP BLOCKED", Color3.fromRGB(0, 255, 0), 5)
        end
        lastKnownJumpPower = humanoid.JumpPower
    end)
end

-- Initialize everything
local function initializeAntiAdmin()
    antiAdminEnabled = true
    createNotification("ULTIMATE ANTI-ADMIN LOADED", Color3.fromRGB(0, 255, 0), 8)
    print("Ultimate Anti Admin & Instant Exploit Detection Loaded - By Fari Noveri")
    
    -- Scan existing players immediately
    for _, existingPlayer in pairs(Players:GetPlayers()) do
        if existingPlayer ~= player then
            onPlayerAdded(existingPlayer)
        end
    end
    
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)
    
    continuousScan()
    
    spawn(function()
        while antiAdminEnabled do
            updateProtectedPlayers()
            updateToolCache()
            wait(3)
        end
    end)
    
    handleAntiAdmin()
    
    player.CharacterAdded:Connect(function(newCharacter)
        wait(1)
        character = newCharacter
        humanoid = character:WaitForChild("Humanoid")
        rootPart = character:WaitForChild("HumanoidRootPart")
        backpack = player:WaitForChild("Backpack")
        lastKnownPosition = rootPart.CFrame
        lastKnownHealth = humanoid.Health
        lastKnownVelocity = rootPart.Velocity
        lastKnownWalkSpeed = humanoid.WalkSpeed
        lastKnownJumpPower = humanoid.JumpPower
        lastKnownAnchored = rootPart.Anchored
        lastKnownCameraSubject = camera.CameraSubject
        updateToolCache()
        
        -- Disconnect old connections
        for _, conn in pairs(antiAdminConnections) do
            if conn then
                conn:Disconnect()
            end
        end
        antiAdminConnections = {}
        
        -- Restart protections
        handleAntiAdmin()
    end)
end

-- Cleanup function
local function cleanup()
    antiAdminEnabled = false
    
    for _, conn in pairs(antiAdminConnections) do
        if conn then
            conn:Disconnect()
        end
    end
    
    for _, playerConns in pairs(exploiterConnections) do
        for _, conn in pairs(playerConns) do
            if conn then
                conn:Disconnect()
            end
        end
    end
    
    if screenGui then
        screenGui:Destroy()
    end
    
    print("Anti Admin system cleaned up")
end

-- Advanced network monitoring (deteksi remote events exploit)
local function monitorNetworkExploits()
    spawn(function()
        while antiAdminEnabled do
            -- Monitor for suspicious remote events
            for _, service in pairs({game.ReplicatedStorage, game.ReplicatedFirst}) do
                for _, remote in pairs(service:GetDescendants()) do
                    if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                        -- Monitor remote usage patterns
                        pcall(function()
                            local originalFire = remote.FireServer
                            remote.FireServer = function(self, ...)
                                local args = {...}
                                
                                -- Check for exploit-like arguments
                                for _, arg in pairs(args) do
                                    if type(arg) == "string" then
                                        local lowerArg = string.lower(arg)
                                        local exploitKeywords = {
                                            "kill", "ban", "kick", "admin", "god", "fly", 
                                            "speed", "teleport", "money", "cash", "coins",
                                            "level", "xp", "points", "unlock", "premium"
                                        }
                                        
                                        for _, keyword in pairs(exploitKeywords) do
                                            if string.find(lowerArg, keyword) then
                                                createNotification(
                                                    "REMOTE EXPLOIT ATTEMPT: " .. remote.Name, 
                                                    Color3.fromRGB(255, 100, 100), 
                                                    8
                                                )
                                                return -- Block the request
                                            end
                                        end
                                    end
                                end
                                
                                return originalFire(self, ...)
                            end
                        end)
                    end
                end
            end
            wait(5)
        end
    end)
end

-- Memory scanning untuk deteksi exploit yang lebih dalam
local function deepMemoryScan()
    spawn(function()
        while antiAdminEnabled do
            pcall(function()
                -- Scan untuk process yang mencurigakan
                local suspiciousProcesses = {
                    "cheat", "hack", "exploit", "inject", "dll", 
                    "synapse", "krnl", "jjsploit", "scriptware"
                }
                
                -- Check environment untuk tanda-tanda exploit
                local function scanEnvironment()
                    local suspicious = false
                    local foundExploits = {}
                    
                    -- Scan _G table
                    for key, value in pairs(_G) do
                        if type(key) == "string" then
                            local lowerKey = string.lower(key)
                            for _, process in pairs(suspiciousProcesses) do
                                if string.find(lowerKey, process) then
                                    suspicious = true
                                    table.insert(foundExploits, key)
                                end
                            end
                        end
                    end
                    
                    -- Scan shared table
                    if shared then
                        for key, value in pairs(shared) do
                            if type(key) == "string" then
                                local lowerKey = string.lower(key)
                                for _, process in pairs(suspiciousProcesses) do
                                    if string.find(lowerKey, process) then
                                        suspicious = true
                                        table.insert(foundExploits, "shared." .. key)
                                    end
                                end
                            end
                        end
                    end
                    
                    if suspicious then
                        createNotification(
                            "DEEP SCAN: EXPLOIT DETECTED (" .. table.concat(foundExploits, ", ") .. ")",
                            Color3.fromRGB(255, 0, 100),
                            12
                        )
                    end
                end
                
                scanEnvironment()
            end)
            
            wait(10) -- Deep scan setiap 10 detik
        end
    end)
end

-- Auto-kick exploiters (optional, bisa diaktifkan/nonaktifkan)
local autoKickEnabled = false -- Set ke true jika ingin auto-kick

local function autoKickExploiters()
    if not autoKickEnabled then return end
    
    spawn(function()
        while antiAdminEnabled do
            for exploiter, data in pairs(detectedExploiters) do
                if exploiter and exploiter.Parent == Players then
                    if data.confidence >= 90 then -- Hanya kick jika confidence tinggi
                        pcall(function()
                            exploiter:Kick("Exploit detected: " .. data.type)
                        end)
                        createNotification(
                            "AUTO-KICKED: " .. exploiter.Name .. " (" .. data.type .. ")",
                            Color3.fromRGB(255, 50, 50),
                            10
                        )
                    end
                end
            end
            wait(30) -- Check setiap 30 detik
        end
    end)
end

-- Initialize semua sistem
initializeAntiAdmin()
monitorNetworkExploits()
deepMemoryScan()
autoKickExploiters()

-- Instant detection untuk current players
spawn(function()
    wait(2) -- Tunggu sebentar untuk sistem stabil
    createNotification("SCANNING ALL PLAYERS...", Color3.fromRGB(0, 200, 255), 3)
    
    for _, targetPlayer in pairs(Players:GetPlayers()) do
        if targetPlayer ~= player then
            scanPlayer(targetPlayer)
        end
    end
    
    createNotification("SCAN COMPLETE - MONITORING ACTIVE", Color3.fromRGB(0, 255, 0), 5)
end)

print("Ultimate Anti Admin & Instant Exploit Detection System Fully Loaded!")
print("Features: Instant Detection | Deep Memory Scan | Network Monitor | Auto-Protection")
print("Created by: Fari Noveri")

return {
    cleanup = cleanup,
    scanPlayer = scanPlayer,
    detectedExploiters = detectedExploiters,
    detectedAdmins = detectedAdmins,
    playerProfiles = playerProfiles,
    toggleAutoKick = function(enabled)
        autoKickEnabled = enabled
        if enabled then
            autoKickExploiters()
            print("Auto-kick enabled")
        else
            print("Auto-kick disabled")
        end
    end
}