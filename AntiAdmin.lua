local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local backpack = player:WaitForChild("Backpack")
local camera = Workspace.CurrentCamera

-- Variabel untuk Anti Admin dan Anti Exploit
local antiAdminEnabled = true -- Selalu aktif, tidak bisa dinonaktifkan
local protectedPlayers = {} -- Daftar pemain yang memiliki Anti Admin aktif (simulasi)
local lastKnownPosition = rootPart and rootPart.CFrame or CFrame.new(0, 0, 0) -- Cache posisi terakhir
local lastKnownHealth = humanoid and humanoid.Health or 100 -- Cache kesehatan terakhir
local lastKnownVelocity = rootPart and rootPart.Velocity or Vector3.new(0, 0, 0) -- Cache kecepatan
local lastKnownWalkSpeed = humanoid and humanoid.WalkSpeed or 16 -- Cache kecepatan jalan
local lastKnownJumpPower = humanoid and humanoid.JumpPower or 50 -- Cache lompatan
local lastKnownAnchored = rootPart and rootPart.Anchored or false -- Cache status anchored
local lastKnownCameraSubject = camera and camera.CameraSubject or humanoid -- Cache subjek kamera
local lastKnownTools = {} -- Cache tool di backpack
local lastKnownCanCollide = rootPart and rootPart.CanCollide or true -- Cache CanCollide
local lastKnownTransparency = humanoid and humanoid:GetPropertyChangedSignal("Transparency") or 0 -- Cache Transparency
local effectSources = {} -- Cache sumber efek (untuk pelacakan pelaku)
local antiAdminConnections = {} -- Koneksi untuk fitur Anti Admin
local maxReverseAttempts = 10 -- Batas iterasi untuk mencegah loop tak terbatas
local allowedAnimations = {} -- Daftar animasi yang diizinkan
local allowedRemotes = {} -- Daftar RemoteEvent/RemoteFunction yang diizinkan

-- Fungsi untuk memperbarui cache tool
local function updateToolCache()
    lastKnownTools = {}
    for _, tool in pairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            table.insert(lastKnownTools, tool.Name)
        end
    end
end

-- Fungsi untuk mendeteksi apakah pemain memiliki Anti Admin aktif (simulasi)
local function hasAntiAdmin(targetPlayer)
    return protectedPlayers[targetPlayer] or math.random(1, 100) <= 50 -- 50% peluang untuk simulasi
end

-- Fungsi untuk memperbarui daftar pemain yang terlindungi
local function updateProtectedPlayers()
    protectedPlayers = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            protectedPlayers[p] = math.random(1, 100) <= 50 -- 50% peluang untuk simulasi
        end
    end
end

-- Fungsi untuk menemukan target yang tidak terlindungi
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

-- Fungsi untuk membalikkan efek dengan logika "hot potato"
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
        if effectType == "kill" then
            targetHumanoid.Health = 0
            print("Reversed kill effect to: " .. currentTarget.Name .. " after " .. attempts .. " attempts")
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
            targetHumanoid.JumpPower = 0
            print("Reversed jump change to: " .. currentTarget.Name .. " after " .. attempts .. " attempts")
        elseif effectType == "tool" then
            for _, tool in pairs(currentTarget.Backpack:GetChildren()) do
                if tool:IsA("Tool") then
                    tool:Destroy()
                end
            end
            print("Reversed tool removal to: " .. currentTarget.Name .. " after " .. attempts .. " attempts")
        elseif effectType == "camera" then
            Workspace.CurrentCamera.CameraSubject = targetHumanoid
            print("Reversed camera change to: " .. currentTarget.Name .. " after " .. attempts .. " attempts")
        elseif effectType == "effect" then
            for _, effect in pairs(targetRootPart:GetChildren()) do
                if effect:IsA("ParticleEmitter") or effect:IsA("Beam") or effect:IsA("Trail") then
                    effect:Destroy()
                end
            end
            print("Reversed visual effect to: " .. currentTarget.Name .. " after " .. attempts .. " attempts")
        elseif effectType == "animation" then
            for _, anim in pairs(targetHumanoid:GetPlayingAnimationTracks()) do
                anim:Stop()
            end
            print("Reversed animation to: " .. currentTarget.Name .. " after " .. attempts .. " attempts")
        elseif effectType == "collision" then
            targetRootPart.CanCollide = false
            print("Reversed collision change to: " .. currentTarget.Name .. " after " .. attempts .. " attempts")
        elseif effectType == "godmode" then
            targetHumanoid.MaxHealth = 100
            targetHumanoid.Health = 100
            print("Reversed god mode to: " .. currentTarget.Name .. " after " .. attempts .. " attempts")
        end
    else
        print("No unprotected target found for " .. effectType .. " reversal after " .. attempts .. " attempts")
    end
end

-- Fungsi untuk mendeteksi dan menangani efek
local function handleAntiAdmin()
    -- Kill Protection
    antiAdminConnections.health = humanoid.HealthChanged:Connect(function(health)
        if not antiAdminEnabled then return end
        if health < lastKnownHealth and health <= 0 then
            humanoid.Health = lastKnownHealth
            print("Detected kill attempt, health restored")
            reverseEffect("kill", effectSources[player] or nil)
        end
        lastKnownHealth = humanoid.Health
    end)

    -- Teleport Protection
    antiAdminConnections.position = rootPart:GetPropertyChangedSignal("CFrame"):Connect(function()
        if not antiAdminEnabled then return end
        local currentPos = rootPart.CFrame
        local distance = (currentPos.Position - lastKnownPosition.Position).Magnitude
        if distance > 10 then
            rootPart.CFrame = lastKnownPosition
            print("Detected teleport attempt, position restored")
            reverseEffect("teleport", effectSources[player] or nil)
        end
        lastKnownPosition = currentPos
    end)

    -- Fling Protection
    antiAdminConnections.velocity = rootPart:GetPropertyChangedSignal("Velocity"):Connect(function()
        if not antiAdminEnabled then return end
        local currentVelocity = rootPart.Velocity
        local velocityDiff = (currentVelocity - lastKnownVelocity).Magnitude
        if velocityDiff > 50 then
            rootPart.Velocity = lastKnownVelocity
            print("Detected fling attempt, velocity restored")
            reverseEffect("fling", effectSources[player] or nil)
        end
        lastKnownVelocity = currentVelocity
    end)

    -- Freeze Protection
    antiAdminConnections.anchored = rootPart:GetPropertyChangedSignal("Anchored"):Connect(function()
        if not antiAdminEnabled then return end
        if rootPart.Anchored and not lastKnownAnchored then
            rootPart.Anchored = false
            print("Detected freeze attempt, unanchored")
            reverseEffect("freeze", effectSources[player] or nil)
        end
        lastKnownAnchored = rootPart.Anchored
    end)

    -- Speed Protection
    antiAdminConnections.walkSpeed = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if not antiAdminEnabled then return end
        if humanoid.WalkSpeed ~= lastKnownWalkSpeed then
            humanoid.WalkSpeed = lastKnownWalkSpeed
            print("Detected speed change attempt, speed restored")
            reverseEffect("speed", effectSources[player] or nil)
        end
        lastKnownWalkSpeed = humanoid.WalkSpeed
    end)

    -- Jump Protection
    antiAdminConnections.jumpPower = humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
        if not antiAdminEnabled then return end
        if humanoid.JumpPower ~= lastKnownJumpPower then
            humanoid.JumpPower = lastKnownJumpPower
            print("Detected jump power change attempt, jump power restored")
            reverseEffect("jump", effectSources[player] or nil)
        end
        lastKnownJumpPower = humanoid.JumpPower
    end)

    -- Tool Protection
    antiAdminConnections.backpack = backpack.ChildAdded:Connect(function(child)
        if not antiAdminEnabled then return end
        if child:IsA("Tool") and not table.find(lastKnownTools, child.Name) then
            child:Destroy()
            print("Detected unauthorized tool addition, tool removed")
            reverseEffect("tool", effectSources[player] or nil)
        end
        updateToolCache()
    end)
    antiAdminConnections.backpackRemoved = backpack.ChildRemoved:Connect(function(child)
        if not antiAdminEnabled then return end
        if child:IsA("Tool") and table.find(lastKnownTools, child.Name) then
            local newTool = child:Clone()
            newTool.Parent = backpack
            print("Detected tool removal attempt, tool restored")
            reverseEffect("tool", effectSources[player] or nil)
        end
        updateToolCache()
    end)

    -- Camera Protection
    antiAdminConnections.camera = camera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
        if not antiAdminEnabled then return end
        if camera.CameraSubject ~= lastKnownCameraSubject then
            camera.CameraSubject = lastKnownCameraSubject
            print("Detected camera manipulation attempt, camera restored")
            reverseEffect("camera", effectSources[player] or nil)
        end
        lastKnownCameraSubject = camera.CameraSubject
    end)

    -- **NEW: Anti-Instance Manipulation Protection**
    antiAdminConnections.instanceRemoval = character.ChildRemoved:Connect(function(child)
        if not antiAdminEnabled then return end
        if child:IsA("Humanoid") or child:IsA("BasePart") then
            print("Detected attempt to remove critical instance: " .. child.Name)
            -- Mengembalikan instance dengan respawn karakter jika perlu
            player:LoadCharacter()
            reverseEffect("kill", effectSources[player] or nil) -- Anggap sebagai upaya kill
        end
    end)

    -- **NEW: Anti-Effect Protection**
    antiAdminConnections.effectProtection = character.DescendantAdded:Connect(function(descendant)
        if not antiAdminEnabled then return end
        if descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") or descendant:IsA("Trail") then
            descendant:Destroy()
            print("Detected unauthorized visual effect, removed: " .. descendant.Name)
            reverseEffect("effect", effectSources[player] or nil)
        end
    end)

    -- **NEW: Anti-Animation Protection**
    antiAdminConnections.animationProtection = humanoid.AnimationPlayed:Connect(function(animationTrack)
        if not antiAdminEnabled then return end
        if not allowedAnimations[animationTrack.Animation.AnimationId] then
            animationTrack:Stop()
            print("Detected unauthorized animation, stopped: " .. animationTrack.Animation.Name)
            reverseEffect("animation", effectSources[player] or nil)
        end
    end)

    -- **NEW: Anti-Collision Protection**
    antiAdminConnections.canCollide = rootPart:GetPropertyChangedSignal("CanCollide"):Connect(function()
        if not antiAdminEnabled then return end
        if rootPart.CanCollide ~= lastKnownCanCollide then
            rootPart.CanCollide = lastKnownCanCollide
            print("Detected CanCollide change attempt, restored")
            reverseEffect("collision", effectSources[player] or nil)
        end
        lastKnownCanCollide = rootPart.CanCollide
    end)

    -- **NEW: Anti-Transparency Protection**
    antiAdminConnections.transparency = humanoid:GetPropertyChangedSignal("Transparency"):Connect(function()
        if not antiAdminEnabled then return end
        if humanoid.Transparency ~= lastKnownTransparency then
            humanoid.Transparency = lastKnownTransparency
            print("Detected transparency change attempt, restored")
            reverseEffect("collision", effectSources[player] or nil)
        end
        lastKnownTransparency = humanoid.Transparency
    end)

    -- **NEW: Anti-God Mode Protection**
    antiAdminConnections.godMode = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
        if not antiAdminEnabled then return end
        if humanoid.MaxHealth > 1000 or humanoid.MaxHealth < 100 then
            humanoid.MaxHealth = 100
            humanoid.Health = math.min(humanoid.Health, 100)
            print("Detected god mode attempt, health capped")
            reverseEffect("godmode", effectSources[player] or nil)
        end
    end)

    -- **NEW: Anti-Network Ownership Protection**
    antiAdminConnections.networkOwnership = RunService.Heartbeat:Connect(function()
        if not antiAdminEnabled then return end
        if rootPart:GetNetworkOwner() ~= player then
            rootPart:SetNetworkOwner(player)
            print("Detected network ownership change, restored to player")
            reverseEffect("fling", effectSources[player] or nil) -- Anggap sebagai upaya fling
        end
    end)
end

-- **NEW: Anti-Remote Exploit Protection**
local function setupAntiRemoteExploit()
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = function(self, ...)
        if not antiAdminEnabled then return oldNamecall(self, ...) end
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "InvokeServer") and not allowedRemotes[self] then
            print("Blocked unauthorized Remote call: " .. self.Name)
            return nil -- Blokir panggilan remote yang tidak diizinkan
        end
        return oldNamecall(self, ...)
    end

    setreadonly(mt, true)
end

-- Inisialisasi Anti Admin
local function initializeAntiAdmin()
    antiAdminEnabled = true
    print("Anti Admin Protection initialized - Always Active")

    -- Inisialisasi daftar animasi yang diizinkan (tambahkan ID animasi default Roblox)
    allowedAnimations["rbxassetid://0"] = true -- Contoh: Animasi default Roblox

    -- Inisialisasi daftar RemoteEvent/RemoteFunction yang diizinkan (tambahkan sesuai kebutuhan game)
    -- allowedRemotes[game:GetService("ReplicatedStorage").SomeRemote] = true

    spawn(function()
        while true do
            updateProtectedPlayers()
            updateToolCache()
            wait(10)
        end
    end)

    handleAntiAdmin()
    setupAntiRemoteExploit()

    player.CharacterAdded:Connect(function(newCharacter)
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
        lastKnownCanCollide = rootPart.CanCollide
        lastKnownTransparency = humanoid.Transparency
        updateToolCache()

        for _, conn in pairs(antiAdminConnections) do
            if conn then
                conn:Disconnect()
            end
        end
        antiAdminConnections = {}
        handleAntiAdmin()
    end)
end

-- Cleanup
local function cleanup()
    for _, conn in pairs(antiAdminConnections) do
        if conn then
            conn:Disconnect()
        end
    end
    -- Reset metatable untuk anti-remote exploit
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    mt.__namecall = oldNamecall
    setreadonly(mt, true)
end

-- Jalankan inisialisasi
initializeAntiAdmin()
print("Anti Admin and Anti Exploit Loaded - By Fari Noveri")

return {
    cleanup = cleanup
}