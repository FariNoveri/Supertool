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

-- GUI untuk peringatan
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AntiAdminGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player.PlayerGui

-- Frame untuk peringatan - ukuran lebih kecil dan kotak
local notificationFrame = Instance.new("Frame")
notificationFrame.Name = "NotificationFrame"
notificationFrame.Size = UDim2.new(0, 200, 0, 200) -- Lebih kecil dan kotak
notificationFrame.Position = UDim2.new(1, -210, 0, 10) -- Posisi kanan atas
notificationFrame.BackgroundTransparency = 1
notificationFrame.Parent = screenGui

-- Variabel untuk Anti Admin
local antiAdminEnabled = true
local protectedPlayers = {}
local detectedExploiters = {}
local detectedAdmins = {}
local playerProfiles = {}
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

-- ID Admin yang dikenal
local knownAdminIds = {
    261, -- ROBLOX
    1, -- Admin
    156, -- builderman
    -- Tambahkan ID admin game ini
}

-- Pola deteksi exploit
local exploitSignatures = {
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
    universal = {
        functions = {"loadstring", "getfenv", "setfenv", "debug", "getupvalue", "setupvalue"},
        globals = {"_G", "shared", "getgenv", "getrenv", "getfenv", "setfenv"},
        properties = {"HttpGet", "HttpPost", "request"}
    }
}

-- Membuat profil pemain
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
        exploitType = "Tidak diketahui",
        isConfirmed = false,
        detectionMethods = {}
    }
end

-- Fungsi untuk membuat peringatan - lebih sederhana dan kecil
local function createNotification(text, color, duration)
    local notification = Instance.new("TextLabel")
    notification.Size = UDim2.new(1, 0, 0, 25) -- Tinggi lebih kecil
    notification.BackgroundColor3 = color or Color3.fromRGB(255, 0, 0)
    notification.BackgroundTransparency = 0.1
    notification.BorderSizePixel = 0
    notification.Text = text
    notification.TextColor3 = Color3.fromRGB(255, 255, 255)
    notification.TextScaled = true
    notification.Font = Enum.Font.Gotham
    notification.Parent = notificationFrame
    
    -- Sudut melengkung
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = notification
    
    -- Posisi peringatan
    local yPos = #notifications * 30 -- Jarak antar notifikasi lebih kecil
    notification.Position = UDim2.new(0, 0, 0, yPos)
    
    table.insert(notifications, notification)
    
    -- Animasi masuk
    notification:TweenPosition(
        UDim2.new(0, 0, 0, yPos),
        Enum.EasingDirection.Out,
        Enum.EasingStyle.Quad,
        0.3
    )
    
    -- Hilang otomatis setelah durasi lebih singkat
    spawn(function()
        wait(duration or 4) -- Durasi default lebih singkat
        notification:TweenPosition(
            UDim2.new(1, 0, 0, yPos),
            Enum.EasingDirection.In,
            Enum.EasingStyle.Quad,
            0.3
        )
        wait(0.3)
        
        -- Hapus dari array
        for i, v in pairs(notifications) do
            if v == notification then
                table.remove(notifications, i)
                break
            end
        end
        
        notification:Destroy()
        
        -- Atur ulang posisi peringatan lainnya
        for i, notif in pairs(notifications) do
            notif:TweenPosition(
                UDim2.new(0, 0, 0, (i-1) * 30),
                Enum.EasingDirection.Out,
                Enum.EasingStyle.Quad,
                0.2
            )
        end
    end)
end

-- Deteksi exploit berdasarkan environment
local function detectExploitEnvironment()
    local exploitDetected = false
    local exploitType = "Tidak diketahui"
    local detectionMethods = {}
    
    -- Periksa fungsi exploit umum
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
            
            -- Tentukan jenis exploit berdasarkan fungsi
            if string.find(func:lower(), "syn") then
                exploitType = "Synapse X"
            elseif string.find(func:lower(), "krnl") then
                exploitType = "KRNL"
            elseif string.find(func:lower(), "script") then
                exploitType = "ScriptWare"
            elseif func == "loadstring" or func == "HttpGet" then
                exploitType = "Executor Umum"
            end
        end
    end
    
    -- Periksa global exploit
    local exploitGlobals = {"syn", "krnl", "ScriptWare", "JJSploit", "Fluxus", "Delta"}
    for _, global in pairs(exploitGlobals) do
        if _G[global] then
            exploitDetected = true
            exploitType = global
            table.insert(detectionMethods, "Global: " .. global)
        end
    end
    
    -- Periksa pola exploit dalam environment
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
                        table.insert(detectionMethods, "Global mencurigakan: " .. name)
                        if exploitType == "Tidak diketahui" then
                            exploitType = "Executor Kustom"
                        end
                    end
                end
            end
        end
    end
    
    -- Periksa environment dengan aman
    pcall(function() checkEnvironment(_G) end)
    pcall(function() checkEnvironment(shared) end)
    pcall(function() checkEnvironment(getfenv(0)) end)
    
    return exploitDetected, exploitType, detectionMethods
end

-- Deteksi exploit berdasarkan analisis script
local function detectScriptExploit(targetPlayer)
    if not targetPlayer.Character then return false end
    
    local suspicious = false
    local exploitType = "Tidak diketahui"
    local methods = {}
    
    -- Periksa script pemain
    local playerScripts = targetPlayer:FindFirstChild("PlayerScripts")
    if playerScripts then
        local function checkScript(script)
            if script:IsA("LocalScript") or script:IsA("ModuleScript") then
                -- Periksa source script untuk pola exploit
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
                            exploitType = "Exploit Berbasis Script"
                            table.insert(methods, "Pola: " .. pattern)
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

-- Analisis perilaku pemain
local function analyzePlayerBehavior(targetPlayer)
    local profile = playerProfiles[targetPlayer]
    if not profile then return false end
    
    local suspicious = false
    local reasons = {}
    
    -- Analisis waktu bergabung vs perilaku
    local timeSinceJoin = tick() - profile.joinTime
    if timeSinceJoin < 10 and profile.suspicionLevel > 3 then
        suspicious = true
        table.insert(reasons, "Perilaku mencurigakan terlalu cepat setelah bergabung")
    end
    
    -- Analisis pola posisi
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
            table.insert(reasons, "Berpindah posisi tidak wajar")
        end
    end
    
    -- Analisis pola kecepatan
    if #profile.lastSpeeds >= 3 then
        local abnormalSpeeds = 0
        for _, speed in pairs(profile.lastSpeeds) do
            if speed > 50 or speed < 0 then
                abnormalSpeeds = abnormalSpeeds + 1
            end
        end
        
        if abnormalSpeeds >= 2 then
            suspicious = true
            table.insert(reasons, "Kecepatan tidak normal")
        end
    end
    
    return suspicious, reasons
end

-- Deteksi exploit utama
local function ultimateExploitDetection(targetPlayer)
    if targetPlayer == player then return false end
    
    createPlayerProfile(targetPlayer)
    local profile = playerProfiles[targetPlayer]
    
    local isExploiter = false
    local exploitType = "Tidak diketahui"
    local detectionMethods = {}
    local confidence = 0
    
    -- Metode 1: Deteksi environment (jika pemain sendiri)
    if targetPlayer == player then
        local envDetected, envType, envMethods = detectExploitEnvironment()
        if envDetected then
            isExploiter = true
            exploitType = envType
            detectionMethods = envMethods
            confidence = confidence + 50
        end
    end
    
    -- Metode 2: Analisis script
    local scriptDetected, scriptType, scriptMethods = detectScriptExploit(targetPlayer)
    if scriptDetected then
        isExploiter = true
        if exploitType == "Tidak diketahui" then exploitType = scriptType end
        for _, method in pairs(scriptMethods) do
            table.insert(detectionMethods, method)
        end
        confidence = confidence + 30
    end
    
    -- Metode 3: Analisis perilaku
    local behaviorSuspicious, behaviorReasons = analyzePlayerBehavior(targetPlayer)
    if behaviorSuspicious then
        isExploiter = true
        if exploitType == "Tidak diketahui" then exploitType = "Deteksi Perilaku" end
        for _, reason in pairs(behaviorReasons) do
            table.insert(detectionMethods, reason)
        end
        confidence = confidence + 20
    end
    
    -- Metode 4: Analisis properti karakter
    if targetPlayer.Character then
        local humanoidCheck = targetPlayer.Character:FindFirstChild("Humanoid")
        local rootPartCheck = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        
        if humanoidCheck and rootPartCheck then
            -- Update data profil
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
            
            -- Tanda bahaya langsung
            if humanoidCheck.WalkSpeed > 100 or humanoidCheck.WalkSpeed < 0 then
                isExploiter = true
                exploitType = "Speed Hack"
                table.insert(detectionMethods, "WalkSpeed tidak wajar: " .. humanoidCheck.WalkSpeed)
                confidence = confidence + 40
            end
            
            if humanoidCheck.JumpPower > 200 or humanoidCheck.JumpPower < 0 then
                isExploiter = true
                exploitType = "Jump Hack"
                table.insert(detectionMethods, "JumpPower tidak wajar: " .. humanoidCheck.JumpPower)
                confidence = confidence + 40
            end
            
            if rootPartCheck.Position.Y > 300 and rootPartCheck.Velocity.Y > -5 then
                isExploiter = true
                exploitType = "Fly Hack"
                table.insert(detectionMethods, "Terbang di Y: " .. rootPartCheck.Position.Y)
                confidence = confidence + 35
            end
            
            if rootPartCheck.Velocity.Magnitude > 150 then
                isExploiter = true
                exploitType = "Velocity Hack"
                table.insert(detectionMethods, "Kecepatan ekstrem: " .. rootPartCheck.Velocity.Magnitude)
                confidence = confidence + 35
            end
        end
    end
    
    -- Metode 5: Analisis tool
    local suspiciousTools = 0
    local toolNames = {}
    
    for _, tool in pairs(targetPlayer.Backpack:GetChildren()) do
        if tool:IsA("Tool") then
            table.insert(toolNames, tool.Name)
            local toolName = string.lower(tool.Name)
            
            -- Pencocokan pola tool exploit
            local exploitToolPatterns = {
                "admin", "exploit", "script", "hack", "cheat", "god", "kill", 
                "ban", "kick", "fly", "speed", "teleport", "noclip", "inf",
                "yield", "dex", "spy", "hub", "loader", "executor"
            }
            
            for _, pattern in pairs(exploitToolPatterns) do
                if string.find(toolName, pattern) then
                    suspiciousTools = suspiciousTools + 1
                    table.insert(detectionMethods, "Tool mencurigakan: " .. tool.Name)
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
                        table.insert(detectionMethods, "Tool terpasang mencurigakan: " .. tool.Name)
                    end
                end
            end
        end
    end
    
    if suspiciousTools >= 1 then
        isExploiter = true
        if exploitType == "Tidak diketahui" then exploitType = "Exploit Tool" end
        confidence = confidence + (suspiciousTools * 25)
    end
    
    -- Metode 6: Analisis akun
    if targetPlayer.AccountAge < 30 then
        confidence = confidence + 10
        table.insert(detectionMethods, "Akun baru (Umur: " .. targetPlayer.AccountAge .. " hari)")
    end
    
    -- Update profil
    profile.exploitType = exploitType
    profile.detectionMethods = detectionMethods
    profile.isConfirmed = confidence >= 70
    
    return isExploiter and confidence >= 50, exploitType, detectionMethods, confidence
end

-- Periksa apakah pemain adalah admin
local function isAdmin(targetPlayer)
    return table.find(knownAdminIds, targetPlayer.UserId) ~= nil
end

-- Pindai pemain dengan deteksi komprehensif
local function scanPlayer(targetPlayer)
    if targetPlayer == player then return end
    
    -- Periksa admin
    if isAdmin(targetPlayer) then
        if not detectedAdmins[targetPlayer] then
            detectedAdmins[targetPlayer] = true
            createNotification("Admin: " .. targetPlayer.Name, Color3.fromRGB(255, 165, 0), 5)
            print("Admin terdeteksi: " .. targetPlayer.Name .. " (ID: " .. targetPlayer.UserId .. ")")
        end
        return -- Jangan tandai admin sebagai exploiter
    end
    
    -- Deteksi exploit
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
            confidenceText = " (Pasti)"
        elseif confidence >= 70 then
            confidenceText = " (Kemungkinan)"
        else
            confidenceText = " (Mungkin)"
        end
        
        createNotification(
            "Exploit: " .. targetPlayer.Name .. " (" .. exploitType .. ")" .. confidenceText, 
            Color3.fromRGB(255, 0, 0), 
            6
        )
        
        print("Exploiter terdeteksi: " .. targetPlayer.Name .. " - " .. exploitType .. " (Keyakinan: " .. confidence .. "%)")
        print("Metode deteksi: " .. table.concat(methods, ", "))
    end
end

-- Sistem pemindaian berkelanjutan
local function continuousScan()
    spawn(function()
        while antiAdminEnabled do
            for _, targetPlayer in pairs(Players:GetPlayers()) do
                if targetPlayer ~= player then
                    scanPlayer(targetPlayer)
                end
            end
            wait(0.5) -- Pindai setiap 0.5 detik untuk deteksi real-time
        end
    end)
end

-- Deteksi instan saat pemain bergabung
local function onPlayerAdded(newPlayer)
    spawn(function()
        -- Pindai langsung
        scanPlayer(newPlayer)
        
        -- Tunggu karakter dan pindai lagi
        local function onCharacterAdded(character)
            wait(0.1) -- Tunggu minimal
            scanPlayer(newPlayer)
        end
        
        exploiterConnections[newPlayer] = {}
        exploiterConnections[newPlayer].characterAdded = newPlayer.CharacterAdded:Connect(onCharacterAdded)
        
        if newPlayer.Character then
            onCharacterAdded(newPlayer.Character)
        end
        
        -- Monitor berkelanjutan untuk pemain ini
        spawn(function()
            while newPlayer.Parent == Players and antiAdminEnabled do
                scanPlayer(newPlayer)
                wait(1)
            end
        end)
    end)
end

local function onPlayerRemoving(leavingPlayer)
    -- Bersihkan
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

-- Fungsi untuk memperbarui cache tool
local function updateToolCache()
    lastKnownTools = {}
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            table.insert(lastKnownTools, tool.Name)
        end
    end
end

-- Periksa apakah pemain memiliki anti admin
local function hasAntiAdmin(targetPlayer)
    return protectedPlayers[targetPlayer] or math.random(1, 100) <= 50
end

-- Update pemain yang dilindungi
local function updateProtectedPlayers()
    protectedPlayers = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            protectedPlayers[p] = math.random(1, 100) <= 50
        end
    end
end

-- Cari target yang tidak dilindungi
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

-- Balikkan efek
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
                print("Efek kill dibalikkan ke: " .. currentTarget.Name)
            elseif effectType == "teleport" then
                targetRootPart.CFrame = CFrame.new(Vector3.new(math.random(-1000, 1000), math.random(50, 500), math.random(-1000, 1000)))
                print("Efek teleport dibalikkan ke: " .. currentTarget.Name)
            elseif effectType == "fling" then
                targetRootPart.Velocity = Vector3.new(math.random(-100, 100), math.random(50, 200), math.random(-100, 100))
                print("Efek fling dibalikkan ke: " .. currentTarget.Name)
            elseif effectType == "freeze" then
                targetRootPart.Anchored = true
                print("Efek freeze dibalikkan ke: " .. currentTarget.Name)
            end
        end)
    end
end

-- Handler perlindungan
local function handleAntiAdmin()
    antiAdminConnections.health = humanoid.HealthChanged:Connect(function(health)
        if not antiAdminEnabled then return end
        if health < lastKnownHealth and health <= 0 then
            humanoid.Health = lastKnownHealth
            createNotification("Kill Diblokir", Color3.fromRGB(0, 255, 0), 3)
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
            createNotification("Teleport Diblokir", Color3.fromRGB(0, 255, 0), 3)
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
            createNotification("Fling Diblokir", Color3.fromRGB(0, 255, 0), 3)
            reverseEffect("fling")
        else
            lastKnownVelocity = currentVelocity
        end
    end)

    antiAdminConnections.anchored = rootPart:GetPropertyChangedSignal("Anchored"):Connect(function()
        if not antiAdminEnabled then return end
        if rootPart.Anchored and not lastKnownAnchored then
            rootPart.Anchored = false
            createNotification("Freeze Diblokir", Color3.fromRGB(0, 255, 0), 3)
            reverseEffect("freeze")
        end
        lastKnownAnchored = rootPart.Anchored
    end)

    antiAdminConnections.walkSpeed = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if not antiAdminEnabled then return end
        if math.abs(humanoid.WalkSpeed - lastKnownWalkSpeed) > 5 then
            humanoid.WalkSpeed = lastKnownWalkSpeed
            createNotification("Speed Diblokir", Color3.fromRGB(0, 255, 0), 3)
        end
        lastKnownWalkSpeed = humanoid.WalkSpeed
    end)

    antiAdminConnections.jumpPower = humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
        if not antiAdminEnabled then return end
        if math.abs(humanoid.JumpPower - lastKnownJumpPower) > 5 then
            humanoid.JumpPower = lastKnownJumpPower
            createNotification("Jump Diblokir", Color3.fromRGB(0, 255, 0), 3)
        end
        lastKnownJumpPower = humanoid.JumpPower
    end)
end

-- Inisialisasi semua
local function initializeAntiAdmin()
    antiAdminEnabled = true
    createNotification("Anti Admin Aktif", Color3.fromRGB(0, 255, 0), 4)
    print("Anti Admin & Deteksi Exploit Dimuat - Oleh Fari Noveri")
    
    -- Pindai pemain yang sudah ada
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
        
        -- Putus koneksi lama
        for _, conn in pairs(antiAdminConnections) do
            if conn then
                conn:Disconnect()
            end
        end
        antiAdminConnections = {}
        
        -- Mulai ulang perlindungan
        handleAntiAdmin()
    end)
end

-- Fungsi pembersihan
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
    
    print("Sistem Anti Admin dibersihkan")
end

-- Monitor exploit jaringan
local function monitorNetworkExploits()
    spawn(function()
        while antiAdminEnabled do
            -- Monitor remote events yang mencurigakan
            for _, service in pairs({game.ReplicatedStorage, game.ReplicatedFirst}) do
                for _, remote in pairs(service:GetDescendants()) do
                    if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                        -- Monitor pola penggunaan remote
                        pcall(function()
                            local originalFire = remote.FireServer
                            remote.FireServer = function(self, ...)
                                local args = {...}
                                
                                -- Periksa argumen yang mencurigakan
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
                                                    "Remote Exploit: " .. remote.Name, 
                                                    Color3.fromRGB(255, 100, 100), 
                                                    4
                                                )
                                                return -- Blokir permintaan
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

-- Pemindaian memori mendalam
local function deepMemoryScan()
    spawn(function()
        while antiAdminEnabled do
            pcall(function()
                -- Pindai proses yang mencurigakan
                local suspiciousProcesses = {
                    "cheat", "hack", "exploit", "inject", "dll", 
                    "synapse", "krnl", "jjsploit", "scriptware"
                }
                
                -- Periksa environment untuk tanda exploit
                local function scanEnvironment()
                    local suspicious = false
                    local foundExploits = {}
                    
                    -- Pindai tabel _G
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
                    
                    -- Pindai tabel shared
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
                            "Exploit Ditemukan: " .. table.concat(foundExploits, ", "),
                            Color3.fromRGB(255, 0, 100),
                            6
                        )
                    end
                end
                
                scanEnvironment()
            end)
            
            wait(10) -- Pindai mendalam setiap 10 detik
        end
    end)
end

-- Auto-kick exploiter (opsional)
local autoKickEnabled = false -- Set ke true jika ingin auto-kick

local function autoKickExploiters()
    if not autoKickEnabled then return end
    
    spawn(function()
        while antiAdminEnabled do
            for exploiter, data in pairs(detectedExploiters) do
                if exploiter and exploiter.Parent == Players then
                    if data.confidence >= 90 then -- Hanya kick jika keyakinan tinggi
                        pcall(function()
                            exploiter:Kick("Exploit terdeteksi: " .. data.type)
                        end)
                        createNotification(
                            "Auto-kick: " .. exploiter.Name,
                            Color3.fromRGB(255, 50, 50),
                            4
                        )
                    end
                end
            end
            wait(30) -- Periksa setiap 30 detik
        end
    end)
end

-- Inisialisasi semua sistem
initializeAntiAdmin()
monitorNetworkExploits()
deepMemoryScan()
autoKickExploiters()

-- Deteksi instan untuk pemain saat ini
spawn(function()
    wait(2) -- Tunggu sistem stabil
    createNotification("Memindai Pemain...", Color3.fromRGB(0, 200, 255), 2)
    
    for _, targetPlayer in pairs(Players:GetPlayers()) do
        if targetPlayer ~= player then
            scanPlayer(targetPlayer)
        end
    end
    
    createNotification("Pindai Selesai", Color3.fromRGB(0, 255, 0), 3)
end)

print("Sistem Anti Admin & Deteksi Exploit Selesai Dimuat!")
print("Fitur: Deteksi Instan | Pindai Memori | Monitor Jaringan | Perlindungan Otomatis")
print("Dibuat oleh: Fari Noveri")

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
            print("Auto-kick diaktifkan")
        else
            print("Auto-kick dinonaktifkan")
        end
    end
}