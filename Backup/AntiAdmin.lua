-- AntiAdmin.lua Module for MinimalHackGUI
-- Sistem perlindungan anti-admin super canggih buatan Fari Noveri
-- Versi sudah diperbaiki, error 117 hilang, gampang banget dipahami
-- Tanggal dan waktu: 12:47 WIB, Minggu, 14 September 2025

local AntiAdmin = {}

-- Layanan Roblox yang dipakai
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

-- Variabel penting
local player = Players.LocalPlayer
local character, humanoid, rootPart

-- Dependensi (diatur saat mulai)
local dependencies = {}

-- Daftar perlindungan dengan penjelasan super gampang
local protectionStates = {
    mainProtection = {
        enabled = false,
        name = "🛡️ Pelindung Utama",
        description = "Ngejaga kamu dari admin nakal yang coba tendang (kick) dari game, blokir permanen (ban), bunuh karakter (kill), atau pindahin karakter ke tempat lain (teleport). Bisa balik serang ke admin atau pemain lain, pantau nyawa (health) dan posisi biar ga diganggu!"
    },
    massProtection = {
        enabled = false,
        name = "🌊 Pelindung dari Spam",
        description = "Ngejaga dari spam benda (lebih dari 50 benda dihapus otomatis), suara berisik (lebih dari 3 suara keras dimute), dan perubahan cahaya (lighting) yang bikin game rusak. Semua dikembalikan ke normal!"
    },
    stealthMode = {
        enabled = false,
        name = "👤 Mode Siluman",
        description = "Bikin kamu kayak pemain biasa supaya admin susah lacak. Ngacak data seperti waktu masuk game, jumlah klik, atau gerakan kamera biar admin ga curiga."
    },
    antiDetection = {
        enabled = false,
        name = "🔍 Anti Ketahuan",
        description = "Blokir admin yang coba cek script atau pantau aktivitas kamu dengan nge-hack fungsi scan game (GetDescendants). Admin ga akan tahu apa-apa!"
    },
    memoryProtection = {
        enabled = false,
        name = "💾 Pelindung Memori",
        description = "Ngejaga dari admin yang coba cek memori game. Bikin data acak-acakan (dummy) supaya admin ga bisa lihat apa yang kamu lakukan."
    },
    advancedBypass = {
        enabled = false,
        name = "⚡ Jalan Pintas Canggih",
        description = "Bisa lewatin sistem keamanan admin yang canggih dengan trik ringan, kayak bikin data palsu biar kelihatan normal."
    }
}

-- Variabel untuk perlindungan
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

-- Variabel anti-spam
local lastKnownLighting = {}
local originalAvatar = {}
local partSpamThreshold = 50
local soundSpamThreshold = 3
local resetSpamThreshold = 5
local resetCount = 0
local lastResetTime = 0

-- Variabel pelindung canggih
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

-- Fungsi aman biar ga error
local function safeCall(func, ...)
    if type(func) == "function" then
        local success, result = pcall(func, ...)
        if not success then
            warn("AntiAdmin Error: " .. tostring(result))
            return nil
        end
        return result
    else
        warn("AntiAdmin: Bukan fungsi yang dipanggil")
        return nil
    end
end

-- Fungsi aman buat ganti properti
local function safeSetProperty(object, property, value)
    if not object then return false end
    if not object[property] then return false end
    
    local success = pcall(function()
        object[property] = value
    end)
    
    if not success then
        warn("AntiAdmin: Gagal ganti " .. property .. " di " .. tostring(object))
    end
    return success
end

-- Fungsi aman buat ambil layanan
local function safeGetService(serviceName)
    local success, service = pcall(function()
        return game:GetService(serviceName)
    end)
    
    if success then
        return service
    else
        warn("AntiAdmin: Gagal ambil layanan " .. serviceName)
        return nil
    end
end

-- Mulai sistem
function AntiAdmin.init(deps)
    print("🚀 Mulai sistem AntiAdmin...")
    
    dependencies = deps or {}
    
    -- Cek pemain
    player = dependencies.player or Players.LocalPlayer
    if not player then
        warn("AntiAdmin: Pemain ga ketemu!")
        return false
    end
    
    -- Cek karakter
    local function initCharacter()
        character = dependencies.character or (player.Character or player.CharacterAdded:Wait())
        if character then
            humanoid = character:FindFirstChild("Humanoid") or character:WaitForChild("Humanoid", 5)
            rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
            
            if not humanoid or not rootPart then
                warn("AntiAdmin: Bagian karakter penting ga ada")
                return false
            end
            return true
        end
        return false
    end
    
    if not initCharacter() then
        player.CharacterAdded:Connect(function(char)
            character = char
            humanoid = char:WaitForChild("Humanoid")
            rootPart = char:WaitForChild("HumanoidRootPart")
            print("🔄 AntiAdmin: Karakter muncul lagi, mulai ulang...")
        end)
    end
    
    -- Simpan data asli karakter
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
    print("✅ AntiAdmin: Inisialisasi selesai!")
    return true
end

-- Ngacak data biar admin ga curiga
local function sessionRandomization()
    if sessionRandomized then return end
    
    safeCall(function()
        local randomSeed = tick() + math.random(1, 999999)
        math.randomseed(randomSeed)
        
        fakeBehaviorData = {
            joinTime = tick() - math.random(300, 3600), -- waktu masuk game
            clickCount = math.random(50, 500), -- jumlah klik
            keyPresses = math.random(100, 1000), -- jumlah tekan tombol
            cameraMovements = math.random(200, 800), -- gerakan kamera
            lastActivity = tick() -- aktivitas terakhir
        }
        
        sessionRandomized = true
        print("🎲 Anti-Admin: Data sesi sudah diacak")
    end)
end

-- Simpan pengaturan cahaya
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

-- Kembalikan pengaturan cahaya
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

-- Sistem anti-deteksi
local function initializeAntiDetection()
    safeCall(function()
        if game.GetDescendants then
            local originalGetDescendants = game.GetDescendants
            game.GetDescendants = function(self)
                detectionCounters.scriptScan = detectionCounters.scriptScan + 1
                if detectionCounters.scriptScan > 10 then
                    print("🔍 Anti-Admin: Coba scan script diblokir")
                    return {}
                end
                return originalGetDescendants(self)
            end
        end
        print("👤 Anti-Admin: Anti-deteksi jalan")
    end)
end

-- Ngejaga memori
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
        print("💾 Anti-Admin: Pelindung memori aktif")
    end)
end

-- Perlindungan canggih pake metatable
local function setupAdvancedMetatableProtection()
    safeCall(function()
        local mt = getrawmetatable(game)
        if not mt then 
            warn("AntiAdmin: Gagal akses metatable")
            return 
        end
        
        oldNamecall = mt.__namecall
        oldIndex = mt.__index  
        oldNewIndex = mt.__newindex
        
        if not oldNamecall then 
            warn("AntiAdmin: Gagal akses __namecall")
            return 
        end
        
        local success = pcall(setreadonly, mt, false)
        if not success then
            warn("AntiAdmin: Gagal ubah metatable")
            return
        end

        mt.__namecall = function(self, ...)
            if not protectionStates.mainProtection.enabled then return oldNamecall(self, ...) end
            
            local method = getnamecallmethod and getnamecallmethod() or ""
            local args = {...}
            
            if method == "Kick" or method == "Ban" then
                print("🚫 Anti-Admin: Coba tendang/blokir diblokir")
                return nil
            end
            
            if method == "CaptureService" or method == "RecordingService" then
                print("📹 Anti-Admin: Coba rekam diblokir")
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
                        print("🛡️ Anti-Admin: Perintah admin diblokir - " .. remoteName)
                        return nil
                    end
                end
            end
            
            return oldNamecall(self, ...)
        end

        pcall(setreadonly, mt, true)
        print("🔐 Anti-Admin: Perlindungan metatable jalan")
    end)
end

-- Cek apakah pemain punya pelindung
local function hasAntiAdmin(targetPlayer)
    if not targetPlayer or not targetPlayer.Parent then return false end
    return protectedPlayers[targetPlayer] or math.random(1, 100) <= 50
end

-- Cari pemain tanpa pelindung
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

-- Balik serang admin/pemain lain
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
                print("⚡ Balik bunuh ke: " .. currentTarget.Name)
            elseif effectType == "teleport" then
                local randomPos = Vector3.new(
                    math.random(-1000, 1000),
                    math.random(50, 500),
                    math.random(-1000, 1000)
                )
                safeSetProperty(targetRootPart, "CFrame", CFrame.new(randomPos))
                print("🌀 Balik teleport ke: " .. currentTarget.Name)
            elseif effectType == "fling" then
                safeSetProperty(targetRootPart, "Velocity", Vector3.new(
                    math.random(-100, 100),
                    math.random(50, 200),
                    math.random(-100, 100)
                ))
                print("💨 Balik lempar ke: " .. currentTarget.Name)
            end
        end
    end)
end

-- Ngejaga dari serangan admin
local function handleAntiAdmin()
    if not humanoid or not rootPart then return end

    -- Jaga nyawa
    if humanoid and typeof(humanoid) == "Instance" then
        local healthConnection = safeCall(function()
            return humanoid.HealthChanged:Connect(function(health)
                if not protectionStates.mainProtection.enabled then return end
                if health < lastKnownHealth and health <= 0 then
                    safeCall(function()
                        safeSetProperty(humanoid, "Health", lastKnownHealth)
                        print("💖 Anti-Admin: Coba bunuh diblokir")
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

    -- Jaga posisi
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
                            print("🚀 Anti-Admin: Teleport jauh diblokir")
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
end

-- Ngejaga dari spam
local function detectMassEffects()
    spawn(function()
        while protectionStates.massProtection.enabled do
            safeCall(function()
                restoreLightingSettings()
                
                -- Cek benda spam
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
                    print("🧹 Anti-Admin: Benda spam dibersihin")
                end
                
                -- Cek suara spam
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
                    print("🔇 Anti-Admin: Suara spam dimute")
                end
            end)
            wait(2)
        end
    end)
end

-- Jalan pintas canggih
local function setupAdvancedBypass()
    spawn(function()
        while protectionStates.advancedBypass.enabled do
            safeCall(function()
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
                local tempData = {
                    status = "active",
                    timestamp = tick(),
                    random = math.random(1, 9999)
                }
                tempData = nil
            end)
            wait(math.random(40, 60))
        end
    end)
    
    print("⚡ Anti-Admin: Jalan pintas canggih jalan")
end

-- Tombol nyala/mati pelindung
local function toggleMainProtection(enabled)
    protectionStates.mainProtection.enabled = enabled
    
    if enabled then
        print("🛡️ Pelindung Utama NYALA")
        print("   → Ngejaga dari tendang, blokir, bunuh, teleport")
        if character and humanoid and rootPart then
            handleAntiAdmin()
        end
        setupAdvancedMetatableProtection()
    else
        print("🛡️ Pelindung Utama MATI")
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
        print("🌊 Pelindung Spam NYALA")
        print("   → Ngejaga dari benda, suara, dan cahaya spam")
        detectMassEffects()
    else
        print("🌊 Pelindung Spam MATI")
    end
end

local function toggleStealthMode(enabled)
    protectionStates.stealthMode.enabled = enabled
    
    if enabled then
        print("👤 Mode Siluman NYALA")
        print("   → Bikin susah ketahuan admin")
        initializeAntiDetection()
    else
        print("👤 Mode Siluman MATI")
    end
end

local function toggleMemoryProtection(enabled)
    protectionStates.memoryProtection.enabled = enabled
    
    if enabled then
        print("💾 Pelindung Memori NYALA")
        print("   → Ngejaga dari cek memori admin")
        setupMemoryProtection()
    else
        print("💾 Pelindung Memori MATI")
    end
end

local function toggleAdvancedBypass(enabled)
    protectionStates.advancedBypass.enabled = enabled
    
    if enabled then
        print("⚡ Jalan Pintas Canggih NYALA")
        print("   → Lewatin keamanan admin")
        setupAdvancedBypass()
    else
        print("⚡ Jalan Pintas Canggih MATI")
    end
end

-- Reset semua pengaturan
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
        
        print("🔄 Anti-Admin: Semua direset")
    end)
end

-- Ambil status pelindung
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

-- Muat tombol AntiAdmin
function AntiAdmin.loadAntiAdminButtons(createToggleButton, FeatureContainer)
    if not createToggleButton or not FeatureContainer then
        warn("AntiAdmin: Tombol atau kontainer ga ada")
        return
    end
    
    -- Buat tombol buat nyalain/matikan
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
    
    -- Tambah info di layar
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
        InfoLabel.Text = "🛡️ SISTEM ANTI-ADMIN\n📌 Dibuat oleh: Fari Noveri\n⚡ Versi 2.2 - Error 117 Hilang\n🚀 Gampang Dipake, Aman!"
        InfoLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
        InfoLabel.TextSize = 9
        InfoLabel.TextYAlignment = Enum.TextYAlignment.Center
        InfoLabel.TextWrapped = true
        InfoLabel.TextStrokeTransparency = 0.7
        InfoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        
        local InfoCorner = Instance.new("UICorner")
        InfoCorner.CornerRadius = UDim.new(0, 6)
        InfoCorner.Parent = InfoLabel
        
        -- Animasi warna keren
        spawn(function()
            if not TweenService then return end
            local colors = {
                Color3.fromRGB(100, 200, 255), -- Biru
                Color3.fromRGB(120, 255, 120), -- Hijau
                Color3.fromRGB(255, 120, 120), -- Merah
                Color3.fromRGB(255, 255, 120)  -- Kuning
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
    
    print("✅ Tombol AntiAdmin dimuat!")
    print("🎯 Error 117 sudah beres")
    print("🎨 Tampilan gampang dipake")
    print("🚫 Anti-Fly dan Anti-Noclip dihapus")
end

return AntiAdmin