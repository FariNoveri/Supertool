-- =====================================================
-- MinimalHackGUI by Fari Noveri [Firebase Edition]
-- Firebase: user tracking, blacklist, kick, owner highlight
-- =====================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

-- =====================================================
-- PROXY CONFIG (Google Apps Script)
-- =====================================================
local PROXY_URL = "https://script.google.com/macros/s/AKfycbwWgh9cUPEqkAx8Z-yXOvkJW2tSfMi_wuMF0zh87k-5FiBgxPpD7jT-ty6Nv4SlTvw9/exec"
local OWNER_NAME = "FariNoveri_2"

-- =====================================================
-- FIRESTORE via PROXY
-- =====================================================

local function encodeParams(params)
    local parts = {}
    for k, v in pairs(params) do
        table.insert(parts, k .. "=" .. tostring(v):gsub(" ", "%%20"))
    end
    return table.concat(parts, "&")
end

local function firestoreGet(collection, docId)
    local url = PROXY_URL .. "?action=get&username=" .. docId
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)
    if not success or not response then
        warn("[Proxy GET failed]: " .. tostring(response))
        return nil
    end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, response)
    if not ok then warn("[Proxy GET decode failed]: " .. tostring(data)) return nil end
    if data and data.error then return nil end
    if not data.fields then return nil end
    local result = {}
    for k, v in pairs(data.fields) do
        if v.booleanValue ~= nil then result[k] = v.booleanValue
        elseif v.integerValue ~= nil then result[k] = tonumber(v.integerValue)
        elseif v.doubleValue ~= nil then result[k] = v.doubleValue
        elseif v.stringValue ~= nil then result[k] = v.stringValue
        end
    end
    return result
end

local function firestoreSet(collection, docId, data)
    local params = {
        action = "set",
        username = docId,
        last_online = tostring(data.last_online or os.time()),
        map_id = tostring(data.map_id or game.PlaceId),
        job_id = tostring(data.job_id or game.JobId),
        blacklisted = tostring(data.blacklisted or false)
    }
    if data.kick_message ~= nil then
        params.kick_message = tostring(data.kick_message)
    end
    -- Support clearing command field
    if data.command ~= nil then
        params.command = tostring(data.command)
    end
    local url = PROXY_URL .. "?" .. encodeParams(params)
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)
    if not success then
        warn("[Proxy SET failed]: " .. tostring(response))
    end
    return success
end

local function firestoreUpdate(collection, docId, data)
    return firestoreSet(collection, docId, data)
end

-- =====================================================
-- BLACKLIST CHECK + KICK CHECK — jalankan PERTAMA
-- =====================================================

local isBlacklisted = false

task.spawn(function()
    local userData = firestoreGet("users", player.Name)

    -- Cek blacklist saat pertama load (dengan expiry check)
    if userData and (userData.blacklisted == true or userData.blacklisted == "true") then
        local expiry = userData.blacklist_expiry or 0
        -- Cek apakah ban sudah expired
        if expiry ~= 0 and os.time() > expiry then
            -- Auto unban via Firestore
            pcall(function()
                game:HttpGet(PROXY_URL .. "?action=blacklist&username=" .. player.Name .. "&value=false&expiry=0")
            end)
            -- Lanjut load normal
        else
            isBlacklisted = true
            for _, gui in pairs(player.PlayerGui:GetChildren()) do
                if gui.Name == "MinimalHackGUI" then gui:Destroy() end
            end
            local kickMsg = "blacklisted! more info why dm on discord FariNoveri#2817"
            if expiry ~= 0 then
                local remaining = expiry - os.time()
                local timeStr = remaining < 3600 and (math.floor(remaining/60) .. " menit")
                    or remaining < 86400 and (math.floor(remaining/3600) .. " jam")
                    or (math.floor(remaining/86400) .. " hari")
                kickMsg = "Kamu di-ban selama " .. timeStr .. " lagi."
            end
            warn("[SuperTool] Akses ditolak untuk: " .. player.Name)
            player:Kick(kickMsg)
            return
        end
    end

    -- Register / update user di Firestore
    if userData then
        -- User lama: kirim event_type=online supaya GAS trigger Discord
        firestoreUpdate("users", player.Name, {
            last_online = os.time(),
            map_id = tostring(game.PlaceId),
            job_id = tostring(game.JobId),
            event_type = "online"
        })
    else
        -- User baru
        firestoreSet("users", player.Name, {
            username = player.Name,
            last_online = os.time(),
            map_id = tostring(game.PlaceId),
            job_id = tostring(game.JobId),
            blacklisted = false,
            event_type = "online"
        })
    end

    -- Kirim offline saat player leave
    game:GetService("Players").LocalPlayer.AncestryChanged:Connect(function()
        pcall(function()
            firestoreOffline(player.Name)
        end)
    end)

    -- Update last_online setiap 60 detik
    task.spawn(function()
        while task.wait(60) do
            if not isBlacklisted then
                pcall(function()
                    firestoreUpdate("users", player.Name, {
                        last_online = os.time(),
                        map_id = tostring(game.PlaceId),
                        job_id = tostring(game.JobId)
                    })
                end)
            end
        end
    end)

    -- Cek blacklist + kick_message realtime setiap 10 detik
    task.spawn(function()
        while task.wait(3) do
            if not isBlacklisted then
                pcall(function()
                    local check = firestoreGet("users", player.Name)
                    if check then
                        -- Cek blacklist
                        if check.blacklisted == true or check.blacklisted == "true" then
                            local expiry = check.blacklist_expiry or 0
                            if expiry ~= 0 and os.time() > expiry then
                                -- Auto unban
                                pcall(function()
                                    game:HttpGet(PROXY_URL .. "?action=blacklist&username=" .. player.Name .. "&value=false&expiry=0")
                                end)
                            else
                                isBlacklisted = true
                                for _, gui in pairs(player.PlayerGui:GetChildren()) do
                                    if gui.Name == "MinimalHackGUI" then gui:Destroy() end
                                end
                                local kickMsg = "blacklisted! more info why dm on discord FariNoveri#2817"
                                if expiry ~= 0 then
                                    local remaining = expiry - os.time()
                                    local timeStr = remaining < 3600 and (math.floor(remaining/60) .. " menit")
                                        or remaining < 86400 and (math.floor(remaining/3600) .. " jam")
                                        or (math.floor(remaining/86400) .. " hari")
                                    kickMsg = "Kamu di-ban selama " .. timeStr .. " lagi."
                                end
                                warn("[SuperTool] Akses dicabut untuk: " .. player.Name)
                                player:Kick(kickMsg)
                                return
                            end
                        end

                        -- Cek kick_message
                        if check.kick_message and check.kick_message ~= "" and check.kick_message ~= "nil" then
                            local msg = check.kick_message
                            local cleared = false
                            pcall(function()
                                firestoreUpdate("users", player.Name, {
                                    kick_message = "",
                                    last_online = os.time(),
                                    map_id = tostring(game.PlaceId),
                                    job_id = tostring(game.JobId)
                                })
                                cleared = true
                            end)
                            if cleared then
                                warn("[SuperTool] Player di-kick: " .. player.Name .. " | Pesan: " .. msg)
                                task.wait(1)
                                player:Kick(msg)
                            end
                        end

                        -- Cek command
                        if check.command and check.command ~= "" and check.command ~= "nil" and check.command ~= "cleared" then
                            local cmd = check.command
                            -- Clear di background (fire and forget), langsung eksekusi
                            -- Pakai local flag supaya tidak loop di polling berikutnya
                            check.command = "cleared"
                            task.spawn(function()
                                for attempt = 1, 5 do
                                    local ok = pcall(function()
                                        game:HttpGet(PROXY_URL
                                            .. "?action=clearcommand&username=" .. player.Name)
                                    end)
                                    if ok then break end
                                    task.wait(2)
                                end
                            end)

                            warn("[SuperTool] Executing command: " .. cmd)
                            print("[SuperTool] CMD START: " .. cmd)

                            -- Execute command
                            if cmd == "removegui" then
                                for _, gui in pairs(player.PlayerGui:GetChildren()) do
                                    if gui:IsA("ScreenGui") and gui.Name == "MinimalHackGUI" then
                                        gui:Destroy()
                                        print("[SuperTool] GUI removed")
                                    end
                                end

                            elseif cmd == "respawn" then
                                print("[SuperTool] Respawning...")
                                player:LoadCharacter()

                            elseif cmd == "rejoin" then
                                print("[SuperTool] Rejoining...")
                                game:GetService("TeleportService"):Teleport(game.PlaceId, player)

                            elseif cmd == "explode" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        local root = char:FindFirstChild("HumanoidRootPart")
                                        if root then
                                            local explosion = Instance.new("Explosion")
                                            explosion.Position = root.Position
                                            explosion.BlastRadius = 10
                                            explosion.BlastPressure = 500000
                                            explosion.DestroyJointRadiusPercent = 0
                                            explosion.Parent = game.Workspace
                                        end
                                    end
                                end)

                            elseif cmd == "nuke" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        local root = char:FindFirstChild("HumanoidRootPart")
                                        if root then
                                            for i = 1, 5 do
                                                local explosion = Instance.new("Explosion")
                                                explosion.Position = root.Position + Vector3.new(
                                                    math.random(-20, 20),
                                                    math.random(0, 15),
                                                    math.random(-20, 20)
                                                )
                                                explosion.BlastRadius = 30
                                                explosion.BlastPressure = 9999999
                                                explosion.Parent = game.Workspace
                                                task.wait(0.1)
                                            end
                                        end
                                    end
                                end)

                            elseif cmd == "fire" then
                                -- Pasang api di semua limb
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        for _, part in pairs(char:GetChildren()) do
                                            if part:IsA("BasePart") then
                                                local fire = Instance.new("Fire")
                                                fire.Size = 5
                                                fire.Heat = 25
                                                fire.Color = Color3.fromRGB(255, 80, 0)
                                                fire.SecondaryColor = Color3.fromRGB(255, 200, 0)
                                                fire.Parent = part
                                            end
                                        end
                                    end
                                end)

                            elseif cmd == "fling" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        local root = char:FindFirstChild("HumanoidRootPart")
                                        if root then
                                            local bv = Instance.new("BodyVelocity")
                                            bv.Velocity = Vector3.new(
                                                math.random(-200, 200),
                                                math.random(500, 1000),
                                                math.random(-200, 200)
                                            )
                                            bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                                            bv.Parent = root
                                            game:GetService("Debris"):AddItem(bv, 0.2)
                                        end
                                    end
                                end)

                            elseif cmd == "freeze" then
                                -- Freeze: anchor + WalkSpeed 0 + selimut es biru di badan
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        local root = char:FindFirstChild("HumanoidRootPart")
                                        local hum = char:FindFirstChild("Humanoid")
                                        if root then root.Anchored = true end
                                        if hum then
                                            hum.WalkSpeed = 0
                                            hum.JumpPower = 0
                                        end
                                        -- Visual: bungkus semua part dengan box biru transparan
                                        for _, part in pairs(char:GetChildren()) do
                                            if part:IsA("BasePart") then
                                                -- Tint biru pada part
                                                local iceHighlight = Instance.new("SelectionBox")
                                                iceHighlight.Name = "IceBox"
                                                iceHighlight.Adornee = part
                                                iceHighlight.Color3 = Color3.fromRGB(0, 180, 255)
                                                iceHighlight.SurfaceColor3 = Color3.fromRGB(100, 220, 255)
                                                iceHighlight.SurfaceTransparency = 0.4
                                                iceHighlight.LineThickness = 0.05
                                                iceHighlight.Parent = char
                                                -- Partikel es
                                                local attachment = Instance.new("Attachment")
                                                attachment.Parent = part
                                                local particles = Instance.new("ParticleEmitter")
                                                particles.Name = "IceParticle"
                                                particles.Color = ColorSequence.new(Color3.fromRGB(180, 230, 255))
                                                particles.LightEmission = 0.5
                                                particles.Size = NumberSequence.new(0.3)
                                                particles.Lifetime = NumberRange.new(0.5, 1.5)
                                                particles.Rate = 8
                                                particles.Speed = NumberRange.new(1, 3)
                                                particles.Parent = attachment
                                            end
                                        end
                                    end
                                end)

                            elseif cmd == "unfreeze" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        local root = char:FindFirstChild("HumanoidRootPart")
                                        local hum = char:FindFirstChild("Humanoid")
                                        if root then root.Anchored = false end
                                        if hum then hum.WalkSpeed = 16 hum.JumpPower = 50 end
                                        -- Hapus visual es
                                        for _, obj in pairs(char:GetDescendants()) do
                                            if obj.Name == "IceBox" or obj.Name == "IceParticle" then
                                                obj:Destroy()
                                            end
                                        end
                                    end
                                end)

                            elseif cmd == "jail" then
                                -- Jail: kurung player dalam kotak besi
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        local root = char:FindFirstChild("HumanoidRootPart")
                                        local hum = char:FindFirstChild("Humanoid")
                                        if root then
                                            -- Anchor player
                                            root.Anchored = true
                                            if hum then hum.WalkSpeed = 0 hum.JumpPower = 0 end

                                            -- Buat jail cage dari 6 sisi
                                            local jailModel = Instance.new("Model")
                                            jailModel.Name = "AdminJail"
                                            jailModel.Parent = game.Workspace

                                            local pos = root.Position
                                            local size = 6 -- ukuran sel

                                            local panels = {
                                                -- {offset, size, name}
                                                {Vector3.new(0, size/2, 0),    Vector3.new(size, 0.3, size),  "Top"},
                                                {Vector3.new(0, -size/2, 0),   Vector3.new(size, 0.3, size),  "Bottom"},
                                                {Vector3.new(size/2, 0, 0),    Vector3.new(0.3, size, size),  "Right"},
                                                {Vector3.new(-size/2, 0, 0),   Vector3.new(0.3, size, size),  "Left"},
                                                {Vector3.new(0, 0, size/2),    Vector3.new(size, size, 0.3),  "Front"},
                                                {Vector3.new(0, 0, -size/2),   Vector3.new(size, size, 0.3),  "Back"},
                                            }

                                            for _, panel in pairs(panels) do
                                                local wall = Instance.new("Part")
                                                wall.Name = panel[3]
                                                wall.Size = panel[2]
                                                wall.Position = pos + panel[1]
                                                wall.Anchored = true
                                                wall.CanCollide = true
                                                wall.Material = Enum.Material.Metal
                                                wall.BrickColor = BrickColor.new("Dark stone grey")
                                                wall.Transparency = 0.4
                                                -- Bar pattern via SelectionBox outline
                                                local sb = Instance.new("SelectionBox")
                                                sb.Adornee = wall
                                                sb.Color3 = Color3.fromRGB(80, 80, 80)
                                                sb.LineThickness = 0.04
                                                sb.SurfaceTransparency = 1
                                                sb.Parent = jailModel
                                                wall.Parent = jailModel
                                            end

                                            -- Label "JAILED" di atas
                                            local billboard = Instance.new("BillboardGui")
                                            billboard.Size = UDim2.new(0, 120, 0, 30)
                                            billboard.StudsOffset = Vector3.new(0, size/2 + 2, 0)
                                            billboard.Adornee = root
                                            billboard.AlwaysOnTop = true
                                            billboard.Parent = game.Workspace
                                            local lbl = Instance.new("TextLabel")
                                            lbl.Size = UDim2.new(1,0,1,0)
                                            lbl.BackgroundTransparency = 0.5
                                            lbl.BackgroundColor3 = Color3.fromRGB(20,20,20)
                                            lbl.TextColor3 = Color3.fromRGB(255,80,80)
                                            lbl.Font = Enum.Font.GothamBold
                                            lbl.TextSize = 14
                                            lbl.Text = "⛓ JAILED"
                                            lbl.Parent = billboard

                                            -- Simpan referensi jail di player
                                            player:SetAttribute("JailModel", jailModel.Name)
                                        end
                                    end
                                end)

                            elseif cmd == "unjail" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        local root = char:FindFirstChild("HumanoidRootPart")
                                        local hum = char:FindFirstChild("Humanoid")
                                        if root then root.Anchored = false end
                                        if hum then hum.WalkSpeed = 16 hum.JumpPower = 50 end
                                        -- Hapus jail model
                                        for _, obj in pairs(game.Workspace:GetChildren()) do
                                            if obj.Name == "AdminJail" then obj:Destroy() end
                                        end
                                        -- Hapus billboard
                                        for _, obj in pairs(game.Workspace:GetChildren()) do
                                            if obj:IsA("BillboardGui") then obj:Destroy() end
                                        end
                                    end
                                end)

                            elseif cmd == "invisible" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        for _, part in pairs(char:GetDescendants()) do
                                            if part:IsA("BasePart") or part:IsA("Decal") then
                                                part.Transparency = 1
                                            end
                                        end
                                    end
                                end)

                            elseif cmd == "visible" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        for _, part in pairs(char:GetDescendants()) do
                                            if part:IsA("BasePart") then
                                                part.Transparency = 0
                                            elseif part:IsA("Decal") then
                                                part.Transparency = 0
                                            end
                                        end
                                    end
                                end)

                            elseif cmd == "loopkill" then
                                pcall(function()
                                    player:SetAttribute("StopLoopKill", false)
                                    task.spawn(function()
                                        for i = 1, 10 do
                                            if player:GetAttribute("StopLoopKill") == true then
                                                break
                                            end
                                            local char = player.Character
                                            if char then
                                                local hum = char:FindFirstChild("Humanoid")
                                                if hum then hum.Health = 0 end
                                            end
                                            task.wait(1)
                                        end
                                    end)
                                end)

                            elseif cmd == "seizure" then
                                pcall(function()
                                    task.spawn(function()
                                        for i = 1, 20 do
                                            local char = player.Character
                                            if char then
                                                local root = char:FindFirstChild("HumanoidRootPart")
                                                if root then
                                                    local bv = Instance.new("BodyVelocity")
                                                    bv.Velocity = Vector3.new(
                                                        math.random(-50, 50),
                                                        math.random(20, 80),
                                                        math.random(-50, 50)
                                                    )
                                                    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                                                    bv.Parent = root
                                                    game:GetService("Debris"):AddItem(bv, 0.1)
                                                end
                                            end
                                            task.wait(0.15)
                                        end
                                    end)
                                end)

                            -- ===== MOVEMENT =====
                            elseif cmd == "speed100" then
                                pcall(function()
                                    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
                                    if hum then hum.WalkSpeed = 100 end
                                end)

                            elseif cmd == "speed0" then
                                pcall(function()
                                    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
                                    if hum then hum.WalkSpeed = 0 end
                                end)

                            elseif cmd == "jumppower100" then
                                pcall(function()
                                    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
                                    if hum then hum.JumpPower = 100 end
                                end)

                            elseif cmd == "jumppower0" then
                                pcall(function()
                                    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
                                    if hum then hum.JumpPower = 0 end
                                end)

                            elseif cmd == "gravity0" then
                                pcall(function()
                                    game.Workspace.Gravity = 0
                                end)

                            elseif cmd == "gravityreset" then
                                pcall(function()
                                    game.Workspace.Gravity = 196.2
                                end)

                            elseif cmd == "noclip" then
                                pcall(function()
                                    player:SetAttribute("Noclip", true)
                                    task.spawn(function()
                                        while player:GetAttribute("Noclip") do
                                            local char = player.Character
                                            if char then
                                                for _, p in pairs(char:GetDescendants()) do
                                                    if p:IsA("BasePart") then
                                                        p.CanCollide = false
                                                    end
                                                end
                                            end
                                            task.wait(0.1)
                                        end
                                    end)
                                end)

                            elseif cmd == "clip" then
                                pcall(function()
                                    player:SetAttribute("Noclip", false)
                                    local char = player.Character
                                    if char then
                                        for _, p in pairs(char:GetDescendants()) do
                                            if p:IsA("BasePart") then p.CanCollide = true end
                                        end
                                    end
                                end)

                            -- ===== GENERAL =====
                            elseif cmd == "godmode" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        local hum = char:FindFirstChild("Humanoid")
                                        if hum then
                                            hum.MaxHealth = math.huge
                                            hum.Health = math.huge
                                        end
                                        -- Forcefield
                                        local ff = Instance.new("ForceField")
                                        ff.Visible = false
                                        ff.Parent = char
                                    end
                                end)

                            elseif cmd == "ungodmode" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        local hum = char:FindFirstChild("Humanoid")
                                        if hum then
                                            hum.MaxHealth = 100
                                            hum.Health = 100
                                        end
                                        for _, obj in pairs(char:GetChildren()) do
                                            if obj:IsA("ForceField") then obj:Destroy() end
                                        end
                                    end
                                end)

                            elseif cmd == "maxhealth" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        local hum = char:FindFirstChild("Humanoid")
                                        if hum then hum.Health = hum.MaxHealth end
                                    end
                                end)

                            -- ===== TROLL - PARTICLES =====
                            elseif cmd == "smoke" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        for _, part in pairs(char:GetChildren()) do
                                            if part:IsA("BasePart") then
                                                local smoke = Instance.new("Smoke")
                                                smoke.Name = "AdminSmoke"
                                                smoke.RiseVelocity = 3
                                                smoke.Size = 2
                                                smoke.Parent = part
                                            end
                                        end
                                    end
                                end)

                            elseif cmd == "unsmoke" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        for _, obj in pairs(char:GetDescendants()) do
                                            if obj.Name == "AdminSmoke" then obj:Destroy() end
                                        end
                                    end
                                end)

                            elseif cmd == "sparkles" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        for _, part in pairs(char:GetChildren()) do
                                            if part:IsA("BasePart") then
                                                local sp = Instance.new("Sparkles")
                                                sp.Name = "AdminSparkles"
                                                sp.SparkleColor = Color3.fromRGB(255, 220, 0)
                                                sp.Parent = part
                                            end
                                        end
                                    end
                                end)

                            elseif cmd == "unsparkles" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        for _, obj in pairs(char:GetDescendants()) do
                                            if obj.Name == "AdminSparkles" then obj:Destroy() end
                                        end
                                    end
                                end)

                            -- ===== TROLL - MOVEMENT FX =====
                            elseif cmd == "spin" then
                                pcall(function()
                                    player:SetAttribute("AdminSpin", true)
                                    task.spawn(function()
                                        while player:GetAttribute("AdminSpin") do
                                            local char = player.Character
                                            local root = char and char:FindFirstChild("HumanoidRootPart")
                                            if root then
                                                root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(15), 0)
                                            end
                                            task.wait(0.03)
                                        end
                                    end)
                                end)

                            elseif cmd == "unspin" then
                                pcall(function()
                                    player:SetAttribute("AdminSpin", false)
                                end)

                            elseif cmd == "drunk" then
                                pcall(function()
                                    player:SetAttribute("AdminDrunk", true)
                                    task.spawn(function()
                                        local t = 0
                                        while player:GetAttribute("AdminDrunk") do
                                            t = t + 0.05
                                            local char = player.Character
                                            local root = char and char:FindFirstChild("HumanoidRootPart")
                                            if root then
                                                local offset = Vector3.new(math.sin(t)*3, 0, math.cos(t*0.7)*2)
                                                root.CFrame = root.CFrame + offset * 0.15
                                            end
                                            task.wait(0.05)
                                        end
                                    end)
                                end)

                            elseif cmd == "undrunk" then
                                pcall(function()
                                    player:SetAttribute("AdminDrunk", false)
                                end)

                            elseif cmd == "flingloop" then
                                pcall(function()
                                    player:SetAttribute("StopLoopKill", false)
                                    task.spawn(function()
                                        for i = 1, 15 do
                                            if player:GetAttribute("StopLoopKill") then break end
                                            local char = player.Character
                                            local root = char and char:FindFirstChild("HumanoidRootPart")
                                            if root then
                                                local bv = Instance.new("BodyVelocity")
                                                bv.Velocity = Vector3.new(math.random(-300,300), math.random(300,800), math.random(-300,300))
                                                bv.MaxForce = Vector3.new(1e9,1e9,1e9)
                                                bv.Parent = root
                                                game:GetService("Debris"):AddItem(bv, 0.15)
                                            end
                                            task.wait(0.8)
                                        end
                                    end)
                                end)

                            elseif cmd == "rainbow" then
                                pcall(function()
                                    player:SetAttribute("AdminRainbow", true)
                                    task.spawn(function()
                                        local hue = 0
                                        while player:GetAttribute("AdminRainbow") do
                                            hue = (hue + 0.02) % 1
                                            local col = Color3.fromHSV(hue, 1, 1)
                                            local char = player.Character
                                            if char then
                                                for _, part in pairs(char:GetDescendants()) do
                                                    if part:IsA("BasePart") then
                                                        part.Color = col
                                                    end
                                                end
                                            end
                                            task.wait(0.05)
                                        end
                                    end)
                                end)

                            elseif cmd == "unrainbow" then
                                pcall(function()
                                    player:SetAttribute("AdminRainbow", false)
                                end)

                            elseif cmd == "dance" then
                                pcall(function()
                                    player:SetAttribute("AdminDance", true)
                                    task.spawn(function()
                                        local t = 0
                                        while player:GetAttribute("AdminDance") do
                                            t = t + 0.1
                                            local char = player.Character
                                            local root = char and char:FindFirstChild("HumanoidRootPart")
                                            if root then
                                                root.CFrame = root.CFrame
                                                    * CFrame.Angles(math.sin(t)*0.2, math.sin(t*1.3)*0.3, math.sin(t*0.7)*0.1)
                                            end
                                            task.wait(0.05)
                                        end
                                    end)
                                end)

                            elseif cmd == "undance" then
                                pcall(function()
                                    player:SetAttribute("AdminDance", false)
                                end)

                            -- ===== APPEARANCE =====
                            elseif cmd == "bighead" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        local head = char:FindFirstChild("Head")
                                        if head then head.Size = Vector3.new(3, 3, 3) end
                                    end
                                end)

                            elseif cmd == "smallhead" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        local head = char:FindFirstChild("Head")
                                        if head then head.Size = Vector3.new(0.3, 0.3, 0.3) end
                                    end
                                end)

                            elseif cmd == "normalhead" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        local head = char:FindFirstChild("Head")
                                        if head then head.Size = Vector3.new(2, 1, 1) end
                                    end
                                end)

                            elseif cmd == "giant" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        for _, part in pairs(char:GetChildren()) do
                                            if part:IsA("BasePart") then
                                                part.Size = part.Size * 3
                                            end
                                        end
                                    end
                                end)

                            elseif cmd == "tiny" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        for _, part in pairs(char:GetChildren()) do
                                            if part:IsA("BasePart") then
                                                part.Size = part.Size * 0.3
                                            end
                                        end
                                    end
                                end)

                            elseif cmd == "normalsize" then
                                pcall(function()
                                    player:LoadCharacter()
                                end)

                            elseif cmd == "chicken" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        -- Kepala besar, badan kecil, kaki panjang
                                        local head = char:FindFirstChild("Head")
                                        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
                                        if head then head.Size = Vector3.new(2.5, 2.5, 2.5) end
                                        if torso then torso.Size = torso.Size * 0.6 end
                                    end
                                end)

                            elseif cmd == "flat" then
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        for _, part in pairs(char:GetChildren()) do
                                            if part:IsA("BasePart") then
                                                part.Size = Vector3.new(part.Size.X, 0.1, part.Size.Z)
                                            end
                                        end
                                    end
                                end)

                            elseif cmd == "normalshape" then
                                pcall(function()
                                    player:LoadCharacter()
                                end)

                            -- ===== RESTRAIN - BLIND =====
                            elseif cmd == "blind" then
                                pcall(function()
                                    local existingBlind = player.PlayerGui:FindFirstChild("AdminBlind")
                                    if existingBlind then existingBlind:Destroy() end
                                    local blindGui = Instance.new("ScreenGui")
                                    blindGui.Name = "AdminBlind"
                                    blindGui.ResetOnSpawn = false
                                    blindGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                                    blindGui.Parent = player.PlayerGui
                                    local blackFrame = Instance.new("Frame")
                                    blackFrame.Size = UDim2.new(1, 0, 1, 0)
                                    blackFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                                    blackFrame.BorderSizePixel = 0
                                    blackFrame.ZIndex = 999
                                    blackFrame.Parent = blindGui
                                    -- Teks kecil di tengah
                                    local lbl = Instance.new("TextLabel")
                                    lbl.Size = UDim2.new(1, 0, 0, 20)
                                    lbl.Position = UDim2.new(0, 0, 0.5, -10)
                                    lbl.BackgroundTransparency = 1
                                    lbl.Text = "🙈"
                                    lbl.TextSize = 20
                                    lbl.TextColor3 = Color3.fromRGB(50, 50, 50)
                                    lbl.Font = Enum.Font.Gotham
                                    lbl.ZIndex = 1000
                                    lbl.Parent = blindGui
                                end)

                            elseif cmd == "unblind" then
                                pcall(function()
                                    local blindGui = player.PlayerGui:FindFirstChild("AdminBlind")
                                    if blindGui then blindGui:Destroy() end
                                end)

                            -- ===== SCREEN FX =====
                            elseif cmd == "screenblind" then
                                pcall(function()
                                    local g = player.PlayerGui:FindFirstChild("AdminScreenBlind")
                                    if g then g:Destroy() end
                                    local gui = Instance.new("ScreenGui")
                                    gui.Name = "AdminScreenBlind"
                                    gui.ResetOnSpawn = false
                                    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                                    gui.Parent = player.PlayerGui
                                    local f = Instance.new("Frame")
                                    f.Size = UDim2.new(1,0,1,0)
                                    f.BackgroundColor3 = Color3.fromRGB(0,0,0)
                                    f.BorderSizePixel = 0
                                    f.ZIndex = 999
                                    f.Parent = gui
                                end)

                            elseif cmd == "unscreenblind" then
                                pcall(function()
                                    local g = player.PlayerGui:FindFirstChild("AdminScreenBlind")
                                    if g then g:Destroy() end
                                end)

                            elseif cmd == "screenblur" then
                                pcall(function()
                                    local existing = game:GetService("Lighting"):FindFirstChild("AdminBlur")
                                    if existing then existing:Destroy() end
                                    local blur = Instance.new("BlurEffect")
                                    blur.Name = "AdminBlur"
                                    blur.Size = 40
                                    blur.Parent = game:GetService("Lighting")
                                end)

                            elseif cmd == "unscreenblur" then
                                pcall(function()
                                    local b = game:GetService("Lighting"):FindFirstChild("AdminBlur")
                                    if b then b:Destroy() end
                                end)

                            elseif cmd == "screenspin" then
                                pcall(function()
                                    local g = player.PlayerGui:FindFirstChild("AdminScreenSpin")
                                    if g then g:Destroy() end
                                    local gui = Instance.new("ScreenGui")
                                    gui.Name = "AdminScreenSpin"
                                    gui.ResetOnSpawn = false
                                    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                                    gui.Parent = player.PlayerGui
                                    player:SetAttribute("AdminScreenSpin", true)
                                    task.spawn(function()
                                        local rot = 0
                                        while player:GetAttribute("AdminScreenSpin") do
                                            rot = rot + 3
                                            local cam = game.Workspace.CurrentCamera
                                            if cam then
                                                cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, math.rad(3))
                                            end
                                            task.wait(0.03)
                                        end
                                    end)
                                end)

                            elseif cmd == "unscreenspin" then
                                pcall(function()
                                    player:SetAttribute("AdminScreenSpin", false)
                                    local g = player.PlayerGui:FindFirstChild("AdminScreenSpin")
                                    if g then g:Destroy() end
                                end)

                            elseif cmd == "screenshake" then
                                pcall(function()
                                    player:SetAttribute("AdminScreenShake", true)
                                    task.spawn(function()
                                        while player:GetAttribute("AdminScreenShake") do
                                            local cam = game.Workspace.CurrentCamera
                                            if cam then
                                                local offset = Vector3.new(
                                                    math.random(-10,10)*0.05,
                                                    math.random(-10,10)*0.05,
                                                    0
                                                )
                                                cam.CFrame = cam.CFrame + offset
                                            end
                                            task.wait(0.04)
                                        end
                                    end)
                                end)

                            elseif cmd == "unscreenshake" then
                                pcall(function()
                                    player:SetAttribute("AdminScreenShake", false)
                                end)

                            elseif cmd == "screenflip" then
                                pcall(function()
                                    local g = player.PlayerGui:FindFirstChild("AdminScreenFlip")
                                    if g then g:Destroy() end
                                    local gui = Instance.new("ScreenGui")
                                    gui.Name = "AdminScreenFlip"
                                    gui.ResetOnSpawn = false
                                    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                                    gui.Parent = player.PlayerGui
                                    -- Frame transparan yang merotasi seluruh content
                                    local f = Instance.new("Frame")
                                    f.Size = UDim2.new(1,0,1,0)
                                    f.BackgroundTransparency = 1
                                    f.Rotation = 180
                                    f.ZIndex = 998
                                    f.Parent = gui
                                    -- Overlay hitam semi-transparan biar keliatan efeknya
                                    local overlay = Instance.new("Frame")
                                    overlay.Size = UDim2.new(1,0,1,0)
                                    overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
                                    overlay.BackgroundTransparency = 0.7
                                    overlay.ZIndex = 997
                                    overlay.Parent = gui
                                    -- Rotate camera
                                    player:SetAttribute("AdminFlipped", true)
                                    task.spawn(function()
                                        while player:GetAttribute("AdminFlipped") do
                                            local cam = game.Workspace.CurrentCamera
                                            if cam then
                                                cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, math.rad(180))
                                            end
                                            task.wait(5)
                                        end
                                    end)
                                end)

                            elseif cmd == "unscreenflip" then
                                pcall(function()
                                    player:SetAttribute("AdminFlipped", false)
                                    local g = player.PlayerGui:FindFirstChild("AdminScreenFlip")
                                    if g then g:Destroy() end
                                end)

                            elseif cmd == "screennoise" then
                                pcall(function()
                                    local g = player.PlayerGui:FindFirstChild("AdminNoise")
                                    if g then g:Destroy() end
                                    local gui = Instance.new("ScreenGui")
                                    gui.Name = "AdminNoise"
                                    gui.ResetOnSpawn = false
                                    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                                    gui.Parent = player.PlayerGui
                                    player:SetAttribute("AdminNoise", true)
                                    task.spawn(function()
                                        while player:GetAttribute("AdminNoise") do
                                            -- Buat banyak kotak kecil random
                                            for i = 1, 80 do
                                                local px = Instance.new("Frame")
                                                px.Size = UDim2.new(0, math.random(2,8), 0, math.random(2,8))
                                                px.Position = UDim2.new(math.random(), 0, math.random(), 0)
                                                local c = math.random(0, 255)
                                                px.BackgroundColor3 = Color3.fromRGB(c, c, c)
                                                px.BackgroundTransparency = math.random() * 0.5
                                                px.BorderSizePixel = 0
                                                px.ZIndex = 998
                                                px.Parent = gui
                                            end
                                            task.wait(0.05)
                                            -- Clear
                                            for _, ch in pairs(gui:GetChildren()) do
                                                if ch:IsA("Frame") then ch:Destroy() end
                                            end
                                        end
                                    end)
                                end)

                            elseif cmd == "unscreennoise" then
                                pcall(function()
                                    player:SetAttribute("AdminNoise", false)
                                    local g = player.PlayerGui:FindFirstChild("AdminNoise")
                                    if g then g:Destroy() end
                                end)

                            elseif cmd == "screenred" then
                                pcall(function()
                                    local g = player.PlayerGui:FindFirstChild("AdminScreenRed")
                                    if g then g:Destroy() end
                                    local gui = Instance.new("ScreenGui")
                                    gui.Name = "AdminScreenRed"
                                    gui.ResetOnSpawn = false
                                    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                                    gui.Parent = player.PlayerGui
                                    local f = Instance.new("Frame")
                                    f.Size = UDim2.new(1,0,1,0)
                                    f.BackgroundColor3 = Color3.fromRGB(255,0,0)
                                    f.BackgroundTransparency = 0.6
                                    f.BorderSizePixel = 0
                                    f.ZIndex = 997
                                    f.Parent = gui
                                end)

                            elseif cmd == "screenzoom" then
                                pcall(function()
                                    local cam = game.Workspace.CurrentCamera
                                    if cam then
                                        cam.FieldOfView = 20
                                    end
                                end)

                            elseif cmd == "unscreenzoom" then
                                pcall(function()
                                    local cam = game.Workspace.CurrentCamera
                                    if cam then
                                        cam.FieldOfView = 70
                                    end
                                end)

                            elseif cmd == "screenclear" then
                                -- Hapus semua screen FX sekaligus
                                pcall(function()
                                    local fxNames = {
                                        "AdminScreenBlind","AdminScreenSpin","AdminNoise",
                                        "AdminScreenFlip","AdminScreenRed","AdminBlind"
                                    }
                                    for _, name in pairs(fxNames) do
                                        local g = player.PlayerGui:FindFirstChild(name)
                                        if g then g:Destroy() end
                                    end
                                    -- Clear lighting effects
                                    local blur = game:GetService("Lighting"):FindFirstChild("AdminBlur")
                                    if blur then blur:Destroy() end
                                    -- Reset attributes
                                    local attrs = {"AdminScreenSpin","AdminScreenShake","AdminFlipped","AdminNoise"}
                                    for _, attr in pairs(attrs) do
                                        player:SetAttribute(attr, false)
                                    end
                                    -- Reset camera FOV
                                    local cam = game.Workspace.CurrentCamera
                                    if cam then cam.FieldOfView = 70 end
                                end)

                            elseif cmd == "unfire" then
                                -- Hapus semua Fire dari karakter
                                pcall(function()
                                    local char = player.Character
                                    if char then
                                        for _, obj in pairs(char:GetDescendants()) do
                                            if obj:IsA("Fire") or obj:IsA("Smoke") then
                                                obj:Destroy()
                                            end
                                        end
                                    end
                                end)

                            elseif cmd == "unloopkill" then
                                -- Stop loopkill dengan membuat flag via attribute
                                pcall(function()
                                    player:SetAttribute("StopLoopKill", true)
                                end)

                            elseif cmd:sub(1, 9) == "announce:" then
                                -- Announce pakai Roblox native SendNotification (seperti screenshot)
                                pcall(function()
                                    local announceText = cmd:sub(10)
                                    game:GetService("StarterGui"):SetCore("SendNotification", {
                                        Title = player.Name,
                                        Text = announceText,
                                        Duration = 8,
                                        Icon = "https://www.roblox.com/headshot-thumbnail/image?userId=7740869755&width=150&height=150&format=png",
                                        Button1 = "OK",
                                    })
                                end)

                            end -- end cmd check
                        end -- end command check
                    end
                end)
            end
        end
    end)
end)

-- =====================================================
-- RAINBOW OWNER HIGHLIGHT SYSTEM
-- =====================================================

if player.Name == OWNER_NAME then
    local activeHighlights = {}
    local rainbowConnections = {}
    local colorIndex = 0
    local colorAlpha = 0

    local RAINBOW = {
        Color3.fromRGB(255, 0, 0),
        Color3.fromRGB(255, 127, 0),
        Color3.fromRGB(255, 255, 0),
        Color3.fromRGB(0, 255, 0),
        Color3.fromRGB(0, 150, 255),
        Color3.fromRGB(100, 0, 255),
        Color3.fromRGB(220, 0, 220),
    }

    local function getRainbow()
        colorAlpha = colorAlpha + 0.015
        if colorAlpha >= 1 then
            colorAlpha = 0
            colorIndex = (colorIndex + 1) % #RAINBOW
        end
        local c1 = RAINBOW[colorIndex + 1]
        local c2 = RAINBOW[((colorIndex + 1) % #RAINBOW) + 1]
        return c1:Lerp(c2, colorAlpha)
    end

    local function addHighlight(targetPlayer)
        if not targetPlayer or activeHighlights[targetPlayer.Name] then return end
        local char = targetPlayer.Character
        if not char then return end

        local selBox = Instance.new("SelectionBox")
        selBox.Name = "OwnerRainbow"
        selBox.Adornee = char
        selBox.LineThickness = 0.07
        selBox.SurfaceTransparency = 0.8
        selBox.SurfaceColor3 = Color3.fromRGB(255, 255, 255)
        selBox.Color3 = Color3.fromRGB(255, 0, 0)
        selBox.Parent = game:GetService("CoreGui")

        local bb = Instance.new("BillboardGui")
        bb.Name = "OwnerTag_" .. targetPlayer.Name
        bb.Size = UDim2.new(0, 140, 0, 28)
        bb.StudsOffset = Vector3.new(0, 3.2, 0)
        bb.AlwaysOnTop = true
        bb.Adornee = char:FindFirstChild("Head") or char:FindFirstChildWhichIsA("BasePart")
        bb.Parent = game:GetService("CoreGui")

        local bg = Instance.new("Frame")
        bg.Parent = bb
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bg.BackgroundTransparency = 0.5
        bg.BorderSizePixel = 0
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)

        local lbl = Instance.new("TextLabel")
        lbl.Parent = bg
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextStrokeTransparency = 0.3
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.Text = "⚙ " .. targetPlayer.Name

        activeHighlights[targetPlayer.Name] = {
            box = selBox,
            bb = bb,
            label = lbl
        }

        local conn = targetPlayer.CharacterAdded:Connect(function(newChar)
            task.wait(1)
            if activeHighlights[targetPlayer.Name] then
                activeHighlights[targetPlayer.Name].box.Adornee = newChar
                local h = newChar:FindFirstChild("Head")
                if h then activeHighlights[targetPlayer.Name].bb.Adornee = h end
            end
        end)
        rainbowConnections[targetPlayer.Name] = conn
    end

    local function removeHighlight(pName)
        if activeHighlights[pName] then
            pcall(function() activeHighlights[pName].box:Destroy() end)
            pcall(function() activeHighlights[pName].bb:Destroy() end)
            activeHighlights[pName] = nil
        end
        if rainbowConnections[pName] then
            pcall(function() rainbowConnections[pName]:Disconnect() end)
            rainbowConnections[pName] = nil
        end
    end

    local function checkAndHighlight(p)
        if p == player then return end
        task.spawn(function()
            local userData = firestoreGet("users", p.Name)
            if userData and type(userData) == "table" then
                local lastOn = userData.last_online or 0
                if os.time() - lastOn < 180 then
                    addHighlight(p)
                end
            end
        end)
    end

    for _, p in ipairs(Players:GetPlayers()) do
        checkAndHighlight(p)
    end

    Players.PlayerAdded:Connect(function(p)
        task.wait(8)
        checkAndHighlight(p)
    end)

    Players.PlayerRemoving:Connect(function(p)
        removeHighlight(p.Name)
    end)

    RunService.Heartbeat:Connect(function()
        local col = getRainbow()
        for _, data in pairs(activeHighlights) do
            if data.box and data.box.Parent then
                data.box.Color3 = col
                data.box.SurfaceColor3 = col
            end
            if data.label and data.label.Parent then
                data.label.TextColor3 = col
            end
        end
    end)

    task.spawn(function()
        while task.wait(45) do
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and not activeHighlights[p.Name] then
                    checkAndHighlight(p)
                end
            end
        end
    end)
end

-- =====================================================
-- GUI SETUP
-- =====================================================

local character, humanoid, rootPart

local connections = {}
local buttonStates = {}
local selectedCategory = "Movement"
local categoryStates = {}
local activeFeature = nil
local exclusiveFeatures = {}

local settings = {
    GuiWidth = {value = 500, min = 300, max = 800, default = 500},
    GuiHeight = {value = 300, min = 200, max = 600, default = 300},
    GuiOpacity = {value = 1.0, min = 0.1, max = 1.0, default = 1.0}
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MinimalHackGUI"
ScreenGui.Parent = player:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Enabled = true

for _, gui in pairs(player.PlayerGui:GetChildren()) do
    if gui:IsA("ScreenGui") and gui.Name == "MinimalHackGUI" and gui ~= ScreenGui then
        gui:Destroy()
    end
end

local Frame = Instance.new("Frame")
Frame.Name = "MainFrame"
Frame.Parent = ScreenGui
Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Frame.BorderColor3 = Color3.fromRGB(45, 45, 45)
Frame.BorderSizePixel = 1
Frame.Position = UDim2.new(0.5, -250, 0.5, -150)
Frame.Size = UDim2.new(0, settings.GuiWidth.value, 0, settings.GuiHeight.value)
Frame.Active = true
Frame.Draggable = true

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Parent = Frame
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.BorderSizePixel = 0
Title.Size = UDim2.new(1, 0, 0, 25)
Title.Font = Enum.Font.Gotham
Title.Text = "MinimalHackGUI by Fari Noveri [Fixed Loader]"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 10

local MinimizedLogo = Instance.new("Frame")
MinimizedLogo.Name = "MinimizedLogo"
MinimizedLogo.Parent = ScreenGui
MinimizedLogo.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MinimizedLogo.BorderColor3 = Color3.fromRGB(45, 45, 45)
MinimizedLogo.Position = UDim2.new(0, 5, 0, 5)
MinimizedLogo.Size = UDim2.new(0, 30, 0, 30)
MinimizedLogo.Visible = false
MinimizedLogo.Active = true
MinimizedLogo.Draggable = true

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 12)
Corner.Parent = MinimizedLogo

local LogoText = Instance.new("TextLabel")
LogoText.Parent = MinimizedLogo
LogoText.BackgroundTransparency = 1
LogoText.Size = UDim2.new(1, 0, 1, 0)
LogoText.Font = Enum.Font.GothamBold
LogoText.Text = "H"
LogoText.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoText.TextSize = 12
LogoText.TextStrokeTransparency = 0.5
LogoText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

local LogoButton = Instance.new("TextButton")
LogoButton.Parent = MinimizedLogo
LogoButton.BackgroundTransparency = 1
LogoButton.Size = UDim2.new(1, 0, 1, 0)
LogoButton.Text = ""

local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Parent = Frame
MinimizeButton.BackgroundTransparency = 1
MinimizeButton.Position = UDim2.new(1, -20, 0, 5)
MinimizeButton.Size = UDim2.new(0, 20, 0, 20)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "-"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextSize = 10

local function createSlideNotification()
    local NotificationFrame = Instance.new("Frame")
    NotificationFrame.Name = "SlideNotification"
    NotificationFrame.Parent = ScreenGui
    NotificationFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    NotificationFrame.BorderSizePixel = 0
    NotificationFrame.Size = UDim2.new(0, 200, 0, 70)
    NotificationFrame.Position = UDim2.new(1, 0, 1, -80)
    NotificationFrame.ZIndex = 1000
    NotificationFrame.Active = true

    local NotificationCorner = Instance.new("UICorner")
    NotificationCorner.CornerRadius = UDim.new(0, 8)
    NotificationCorner.Parent = NotificationFrame

    local Shadow = Instance.new("Frame")
    Shadow.Name = "Shadow"
    Shadow.Parent = ScreenGui
    Shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Shadow.BackgroundTransparency = 0.8
    Shadow.BorderSizePixel = 0
    Shadow.Size = UDim2.new(0, 204, 0, 74)
    Shadow.Position = UDim2.new(1, 2, 1, -78)
    Shadow.ZIndex = 999

    local ShadowCorner = Instance.new("UICorner")
    ShadowCorner.CornerRadius = UDim.new(0, 8)
    ShadowCorner.Parent = Shadow

    local LogoImage = Instance.new("ImageLabel")
    LogoImage.Name = "Logo"
    LogoImage.Parent = NotificationFrame
    LogoImage.BackgroundTransparency = 1
    LogoImage.Position = UDim2.new(0, 8, 0, 8)
    LogoImage.Size = UDim2.new(0, 35, 0, 35)
    LogoImage.Image = "https://cdn.rafled.com/anime-icons/images/cADJDgHDli9YzzGB5AhH0Aa2dR8Bfu8w.jpg"
    LogoImage.ScaleType = Enum.ScaleType.Fit

    local LogoCorner2 = Instance.new("UICorner")
    LogoCorner2.CornerRadius = UDim.new(0, 6)
    LogoCorner2.Parent = LogoImage

    local MainText = Instance.new("TextLabel")
    MainText.Parent = NotificationFrame
    MainText.BackgroundTransparency = 1
    MainText.Position = UDim2.new(0, 50, 0, 8)
    MainText.Size = UDim2.new(1, -58, 0, 20)
    MainText.Font = Enum.Font.GothamBold
    MainText.Text = "Made by fari noveri"
    MainText.TextColor3 = Color3.fromRGB(30, 30, 30)
    MainText.TextSize = 10
    MainText.TextXAlignment = Enum.TextXAlignment.Left
    MainText.TextYAlignment = Enum.TextYAlignment.Center

    local SubText = Instance.new("TextLabel")
    SubText.Parent = NotificationFrame
    SubText.BackgroundTransparency = 1
    SubText.Position = UDim2.new(0, 50, 0, 28)
    SubText.Size = UDim2.new(1, -58, 0, 15)
    SubText.Font = Enum.Font.Gotham
    SubText.Text = "SuperTool"
    SubText.TextColor3 = Color3.fromRGB(100, 100, 100)
    SubText.TextSize = 9
    SubText.TextXAlignment = Enum.TextXAlignment.Left
    SubText.TextYAlignment = Enum.TextYAlignment.Center

    local StatusText = Instance.new("TextLabel")
    StatusText.Parent = NotificationFrame
    StatusText.BackgroundTransparency = 1
    StatusText.Position = UDim2.new(0, 50, 0, 43)
    StatusText.Size = UDim2.new(1, -58, 0, 15)
    StatusText.Font = Enum.Font.Gotham
    StatusText.Text = "Successfully loaded!"
    StatusText.TextColor3 = Color3.fromRGB(0, 150, 0)
    StatusText.TextSize = 8
    StatusText.TextXAlignment = Enum.TextXAlignment.Left
    StatusText.TextYAlignment = Enum.TextYAlignment.Center

    local DismissButton = Instance.new("TextButton")
    DismissButton.Name = "DismissButton"
    DismissButton.Parent = NotificationFrame
    DismissButton.BackgroundTransparency = 1
    DismissButton.Size = UDim2.new(1, 0, 1, 0)
    DismissButton.Text = ""
    DismissButton.ZIndex = 1001

    local slideInTime = 0.4
    local stayTime = 4.5
    local slideOutTime = 0.3
    local slideInPosition = UDim2.new(1, -210, 1, -80)
    local slideOutPosition = UDim2.new(1, 0, 1, -80)
    local shadowSlideInPosition = UDim2.new(1, -208, 1, -78)
    local shadowSlideOutPosition = UDim2.new(1, 2, 1, -78)

    local slideInInfo = TweenInfo.new(slideInTime, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local slideOutInfo = TweenInfo.new(slideOutTime, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

    local slideInTween = TweenService:Create(NotificationFrame, slideInInfo, {Position = slideInPosition})
    local shadowSlideInTween = TweenService:Create(Shadow, slideInInfo, {Position = shadowSlideInPosition})

    local function slideOut()
        local slideOutTween = TweenService:Create(NotificationFrame, slideOutInfo, {Position = slideOutPosition})
        local shadowSlideOutTween = TweenService:Create(Shadow, slideOutInfo, {Position = shadowSlideOutPosition})
        slideOutTween:Play()
        shadowSlideOutTween:Play()
        slideOutTween.Completed:Connect(function()
            NotificationFrame:Destroy()
            Shadow:Destroy()
        end)
    end

    DismissButton.MouseButton1Click:Connect(slideOut)
    slideInTween:Play()
    shadowSlideInTween:Play()
    slideInTween.Completed:Connect(function()
        task.spawn(function()
            task.wait(stayTime)
            slideOut()
        end)
    end)
end

local CategoryContainer = Instance.new("ScrollingFrame")
CategoryContainer.Parent = Frame
CategoryContainer.BackgroundTransparency = 1
CategoryContainer.Position = UDim2.new(0, 5, 0, 30)
CategoryContainer.Size = UDim2.new(0, 80, 1, -35)
CategoryContainer.ScrollBarThickness = 4
CategoryContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
CategoryContainer.ScrollingDirection = Enum.ScrollingDirection.Y
CategoryContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
CategoryContainer.CanvasSize = UDim2.new(0, 0, 0, 0)

local CategoryLayout = Instance.new("UIListLayout")
CategoryLayout.Parent = CategoryContainer
CategoryLayout.Padding = UDim.new(0, 3)
CategoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
CategoryLayout.FillDirection = Enum.FillDirection.Vertical

CategoryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    CategoryContainer.CanvasSize = UDim2.new(0, 0, 0, CategoryLayout.AbsoluteContentSize.Y + 10)
end)

local FeatureContainer = Instance.new("ScrollingFrame")
FeatureContainer.Parent = Frame
FeatureContainer.BackgroundTransparency = 1
FeatureContainer.Position = UDim2.new(0, 90, 0, 30)
FeatureContainer.Size = UDim2.new(1, -95, 1, -35)
FeatureContainer.ScrollBarThickness = 4
FeatureContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
FeatureContainer.ScrollingDirection = Enum.ScrollingDirection.Y
FeatureContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
FeatureContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
FeatureContainer.Visible = true

local FeatureLayout = Instance.new("UIListLayout")
FeatureLayout.Parent = FeatureContainer
FeatureLayout.Padding = UDim.new(0, 2)
FeatureLayout.SortOrder = Enum.SortOrder.LayoutOrder

FeatureLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    FeatureContainer.CanvasSize = UDim2.new(0, 0, 0, FeatureLayout.AbsoluteContentSize.Y + 10)
end)

local categories = {
    {name = "Movement", order = 1},
    {name = "Player", order = 2},
    {name = "Teleport", order = 3},
    {name = "Visual", order = 4},
    {name = "Utility", order = 5},
    {name = "AntiAdmin", order = 6},
    {name = "Settings", order = 7},
    {name = "Info", order = 8},
    {name = "Credit", order = 9}
}

local categoryFrames = {}
local isMinimized = false
local previousMouseBehavior

local modules = {}
local modulesLoaded = {}

local moduleURLs = {
    Movement = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Movement.lua",
    Player = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Player.lua",
    Teleport = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Teleport.lua",
    Visual = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Visual.lua",
    Utility = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Utility.lua",
    AntiAdmin = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/AntiAdmin.lua",
    Settings = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Settings.lua",
    Info = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Info.lua",
    Credit = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Credit.lua"
}

local function loadModule(moduleName)
    if not moduleURLs[moduleName] then
        warn("No URL defined for module: " .. moduleName)
        return false
    end
    local success, result = pcall(function()
        local response = game:HttpGet(moduleURLs[moduleName])
        if not response or response == "" or response:find("404") then
            error("Failed to fetch module or got 404")
        end
        local moduleFunc, loadError = loadstring(response)
        if not moduleFunc then
            error("Failed to compile module: " .. tostring(loadError))
        end
        local moduleTable = moduleFunc()
        if not moduleTable then error("Module function returned nil") end
        if type(moduleTable) ~= "table" then
            error("Module must return a table, got: " .. type(moduleTable))
        end
        return moduleTable
    end)
    if success and result then
        modules[moduleName] = result
        modulesLoaded[moduleName] = true
        if selectedCategory == moduleName then
            task.wait(0.1)
            loadButtons()
        end
        return true
    else
        warn("Failed to load module " .. moduleName .. ": " .. tostring(result))
        return false
    end
end

for moduleName, _ in pairs(moduleURLs) do
    task.spawn(function()
        loadModule(moduleName)
    end)
end

local dependencies = {
    Players = Players,
    UserInputService = UserInputService,
    RunService = RunService,
    Workspace = Workspace,
    Lighting = Lighting,
    ScreenGui = ScreenGui,
    ScrollFrame = FeatureContainer,
    settings = settings,
    connections = connections,
    buttonStates = buttonStates,
    player = player
}

local function initializeModules()
    for moduleName, module in pairs(modules) do
        if module and type(module.init) == "function" then
            local success, errorMsg = pcall(function()
                dependencies.character = character
                dependencies.humanoid = humanoid
                dependencies.rootPart = rootPart
                dependencies.ScrollFrame = FeatureContainer
                module.init(dependencies)
            end)
            if not success then
                warn("Failed to initialize module " .. moduleName .. ": " .. tostring(errorMsg))
            end
        end
    end
end

local function isExclusiveFeature(featureName)
    local exclusives = {"Fly", "Noclip", "Freecam", "Speed Hack", "Jump Hack"}
    for _, exclusive in ipairs(exclusives) do
        if featureName:find(exclusive) then return true end
    end
    return false
end

local function disableActiveFeature()
    if activeFeature and activeFeature.disableCallback and type(activeFeature.disableCallback) == "function" then
        pcall(activeFeature.disableCallback, false)
        if categoryStates[activeFeature.category] then
            categoryStates[activeFeature.category][activeFeature.name] = false
        end
    end
    activeFeature = nil
end

local function createButton(name, callback, categoryName)
    local success, result = pcall(function()
        local button = Instance.new("TextButton")
        button.Name = name
        button.Parent = FeatureContainer
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        button.BorderSizePixel = 0
        button.Size = UDim2.new(1, -2, 0, 20)
        button.Font = Enum.Font.Gotham
        button.Text = name
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 8
        button.LayoutOrder = #FeatureContainer:GetChildren()
        if type(callback) == "function" then
            button.MouseButton1Click:Connect(function()
                pcall(callback)
            end)
        end
        button.MouseEnter:Connect(function() button.BackgroundColor3 = Color3.fromRGB(80, 80, 80) end)
        button.MouseLeave:Connect(function() button.BackgroundColor3 = Color3.fromRGB(60, 60, 60) end)
        return button
    end)
    if not success then
        warn("Failed to create button " .. name .. ": " .. tostring(result))
        return nil
    end
    return result
end

local function createToggleButton(name, callback, categoryName, disableCallback)
    local success, result = pcall(function()
        local button = Instance.new("TextButton")
        button.Name = name
        button.Parent = FeatureContainer
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        button.BorderSizePixel = 0
        button.Size = UDim2.new(1, -2, 0, 20)
        button.Font = Enum.Font.Gotham
        button.Text = name
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 8
        button.LayoutOrder = #FeatureContainer:GetChildren()
        if not categoryStates[categoryName] then categoryStates[categoryName] = {} end
        if categoryStates[categoryName][name] == nil then categoryStates[categoryName][name] = false end
        button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
        button.MouseButton1Click:Connect(function()
            local newState = not categoryStates[categoryName][name]
            if newState and isExclusiveFeature(name) then
                disableActiveFeature()
                activeFeature = {name = name, category = categoryName, disableCallback = disableCallback}
            elseif not newState and activeFeature and activeFeature.name == name then
                activeFeature = nil
            end
            categoryStates[categoryName][name] = newState
            button.BackgroundColor3 = newState and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
            if type(callback) == "function" then
                pcall(callback, newState)
            end
        end)
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(80, 80, 80)
        end)
        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
        end)
        return button
    end)
    if not success then
        warn("Failed to create toggle button " .. name .. ": " .. tostring(result))
        return nil
    end
    return result
end

local function getModuleFunctions(module)
    local functions = {}
    if type(module) == "table" then
        for key, value in pairs(module) do
            if type(value) == "function" then table.insert(functions, key) end
        end
    end
    return functions
end

function loadButtons()
    pcall(function()
        for _, child in pairs(FeatureContainer:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then
                child:Destroy()
            end
        end
    end)
    pcall(function()
        for categoryName, categoryData in pairs(categoryFrames) do
            if categoryData and categoryData.button then
                categoryData.button.BackgroundColor3 = categoryName == selectedCategory and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25)
            end
        end
    end)
    if not selectedCategory then return end
    if not modules[selectedCategory] then
        local loadingLabel = Instance.new("TextLabel")
        loadingLabel.Parent = FeatureContainer
        loadingLabel.BackgroundTransparency = 1
        loadingLabel.Size = UDim2.new(1, -2, 0, 20)
        loadingLabel.Font = Enum.Font.Gotham
        loadingLabel.Text = "Loading " .. selectedCategory .. " module..."
        loadingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        loadingLabel.TextSize = 8
        loadingLabel.TextXAlignment = Enum.TextXAlignment.Left
        if not modulesLoaded[selectedCategory] then
            task.spawn(function() loadModule(selectedCategory) end)
        end
        return
    end
    local module = modules[selectedCategory]
    local success, errorMessage = false, nil

    if selectedCategory == "Credit" and module.createCreditDisplay then
        success, errorMessage = pcall(function() module.createCreditDisplay(FeatureContainer) end)
    elseif selectedCategory == "Visual" and module.loadVisualButtons then
        success, errorMessage = pcall(function()
            if not module.isInitialized or not module.isInitialized() then
                error("Visual module is not properly initialized")
            end
            module.loadVisualButtons(function(name, callback, disableCallback)
                return createToggleButton(name, callback, "Visual", disableCallback)
            end)
        end)
    elseif selectedCategory == "Movement" and module.loadMovementButtons then
        success, errorMessage = pcall(function()
            module.loadMovementButtons(
                function(name, callback) return createButton(name, callback, "Movement") end,
                function(name, callback, disableCallback) return createToggleButton(name, callback, "Movement", disableCallback) end
            )
        end)
    elseif selectedCategory == "Player" and module.loadPlayerButtons then
        success, errorMessage = pcall(function()
            local selectedPlayer = module.getSelectedPlayer and module.getSelectedPlayer() or nil
            module.loadPlayerButtons(
                function(name, callback) return createButton(name, callback, "Player") end,
                function(name, callback, disableCallback) return createToggleButton(name, callback, "Player", disableCallback) end,
                selectedPlayer
            )
        end)
    elseif selectedCategory == "Teleport" and module.loadTeleportButtons then
        success, errorMessage = pcall(function()
            local selectedPlayer = modules.Player and modules.Player.getSelectedPlayer and modules.Player.getSelectedPlayer() or nil
            local freecamEnabled = modules.Visual and modules.Visual.getFreecamState and modules.Visual.getFreecamState() or false
            local freecamPosition = freecamEnabled and select(2, modules.Visual.getFreecamState()) or nil
            local toggleFreecam = modules.Visual and modules.Visual.toggleFreecam or function() end
            module.loadTeleportButtons(
                function(name, callback) return createButton(name, callback, "Teleport") end,
                selectedPlayer, freecamEnabled, freecamPosition, toggleFreecam
            )
        end)
    elseif selectedCategory == "Utility" and module.loadUtilityButtons then
        success, errorMessage = pcall(function()
            module.loadUtilityButtons(function(name, callback)
                return createButton(name, callback, "Utility")
            end)
        end)
    elseif selectedCategory == "AntiAdmin" and module.loadAntiAdminButtons then
        success, errorMessage = pcall(function()
            module.loadAntiAdminButtons(function(name, callback, disableCallback)
                return createToggleButton(name, callback, "AntiAdmin", disableCallback)
            end, FeatureContainer)
        end)
    elseif selectedCategory == "Settings" and module.loadSettingsButtons then
        success, errorMessage = pcall(function()
            module.loadSettingsButtons(function(name, callback)
                return createButton(name, callback, "Settings")
            end)
        end)
    elseif selectedCategory == "Info" and module.createInfoDisplay then
        success, errorMessage = pcall(function() module.createInfoDisplay(FeatureContainer) end)
    else
        local fallbackLabel = Instance.new("TextLabel")
        fallbackLabel.Parent = FeatureContainer
        fallbackLabel.BackgroundTransparency = 1
        fallbackLabel.Size = UDim2.new(1, -2, 0, 40)
        fallbackLabel.Font = Enum.Font.Gotham
        fallbackLabel.Text = selectedCategory .. " module loaded but missing required function.\nFunctions: " .. table.concat(getModuleFunctions(module), ", ")
        fallbackLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        fallbackLabel.TextSize = 8
        fallbackLabel.TextXAlignment = Enum.TextXAlignment.Left
        fallbackLabel.TextYAlignment = Enum.TextYAlignment.Top
        fallbackLabel.TextWrapped = true
        return
    end

    if not success and errorMessage then
        local errorLabel = Instance.new("TextLabel")
        errorLabel.Parent = FeatureContainer
        errorLabel.BackgroundTransparency = 1
        errorLabel.Size = UDim2.new(1, -2, 0, 60)
        errorLabel.Font = Enum.Font.Gotham
        errorLabel.Text = "Error loading " .. selectedCategory .. ":\n" .. tostring(errorMessage)
        errorLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        errorLabel.TextSize = 8
        errorLabel.TextXAlignment = Enum.TextXAlignment.Left
        errorLabel.TextYAlignment = Enum.TextYAlignment.Top
        errorLabel.TextWrapped = true
    end
end

for _, category in ipairs(categories) do
    local categoryButton = Instance.new("TextButton")
    categoryButton.Name = category.name .. "Category"
    categoryButton.Parent = CategoryContainer
    categoryButton.BackgroundColor3 = selectedCategory == category.name and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25)
    categoryButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
    categoryButton.Size = UDim2.new(1, -5, 0, 25)
    categoryButton.LayoutOrder = category.order
    categoryButton.Font = Enum.Font.GothamBold
    categoryButton.Text = category.name
    categoryButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    categoryButton.TextSize = 8
    categoryButton.MouseButton1Click:Connect(function()
        selectedCategory = category.name
        loadButtons()
    end)
    categoryButton.MouseEnter:Connect(function()
        if selectedCategory ~= category.name then
            categoryButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
    end)
    categoryButton.MouseLeave:Connect(function()
        if selectedCategory ~= category.name then
            categoryButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        end
    end)
    categoryFrames[category.name] = {button = categoryButton}
    categoryStates[category.name] = {}
end

local function toggleMinimize()
    isMinimized = not isMinimized
    Frame.Visible = not isMinimized
    MinimizedLogo.Visible = isMinimized
    MinimizeButton.Text = isMinimized and "+" or "-"
    if isMinimized then
        if previousMouseBehavior then
            UserInputService.MouseBehavior = previousMouseBehavior
        end
    else
        previousMouseBehavior = UserInputService.MouseBehavior
        if previousMouseBehavior == Enum.MouseBehavior.LockCenter or previousMouseBehavior == Enum.MouseBehavior.LockCurrent then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end
end

local function resetStates()
    for key, connection in pairs(connections) do
        pcall(function()
            if connection and connection.Disconnect then connection:Disconnect() end
        end)
        connections[key] = nil
    end
    for moduleName, module in pairs(modules) do
        if module and type(module.resetStates) == "function" then
            pcall(function() module.resetStates() end)
        end
    end
    if selectedCategory then
        task.spawn(function()
            task.wait(0.5)
            loadButtons()
        end)
    end
end

local function onCharacterAdded(newCharacter)
    if not newCharacter then return end
    local success, result = pcall(function()
        character = newCharacter
        humanoid = character:WaitForChild("Humanoid", 30)
        rootPart = character:WaitForChild("HumanoidRootPart", 30)
        if not humanoid or not rootPart then error("Failed to find Humanoid or HumanoidRootPart") end
        dependencies.character = character
        dependencies.humanoid = humanoid
        dependencies.rootPart = rootPart
        dependencies.ScrollFrame = FeatureContainer
        for moduleName, module in pairs(modules) do
            if module and type(module.updateReferences) == "function" then
                pcall(function() module.updateReferences() end)
            end
        end
        initializeModules()
        if humanoid and humanoid.Died then
            connections.humanoidDied = humanoid.Died:Connect(function()
                pcall(resetStates)
            end)
        end
        if selectedCategory and modules[selectedCategory] then
            task.spawn(function()
                task.wait(1)
                loadButtons()
            end)
        end
    end)
    if not success then
        warn("Failed to set up character: " .. tostring(result))
        character = newCharacter
        dependencies.character = character
        dependencies.ScrollFrame = FeatureContainer
    end
end

if player.Character then onCharacterAdded(player.Character) end
connections.characterAdded = player.CharacterAdded:Connect(onCharacterAdded)

MinimizeButton.MouseButton1Click:Connect(function() pcall(toggleMinimize) end)
LogoButton.MouseButton1Click:Connect(function() pcall(toggleMinimize) end)

connections.toggleGui = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Home then
        pcall(toggleMinimize)
    end
end)

task.spawn(function()
    local timeout = 45
    local startTime = tick()
    while tick() - startTime < timeout do
        local loadedCount = 0
        local criticalModulesLoaded = 0
        local criticalModules = {"Movement", "Visual", "Player"}
        for moduleName, _ in pairs(moduleURLs) do
            if modulesLoaded[moduleName] then
                loadedCount = loadedCount + 1
                for _, critical in ipairs(criticalModules) do
                    if moduleName == critical then
                        criticalModulesLoaded = criticalModulesLoaded + 1
                        break
                    end
                end
            end
        end
        if criticalModulesLoaded >= 2 or loadedCount >= 4 then break end
        task.wait(1)
    end

    local loadedModules, failedModules = {}, {}
    for moduleName, _ in pairs(moduleURLs) do
        if modulesLoaded[moduleName] then
            table.insert(loadedModules, moduleName)
        else
            table.insert(failedModules, moduleName)
        end
    end

    if #loadedModules > 0 then initializeModules() end

    task.wait(0.5)
    local buttonLoadSuccess, buttonLoadError = pcall(loadButtons)
    if not buttonLoadSuccess then
        warn("Failed to load initial buttons: " .. tostring(buttonLoadError))
        local fallbackLabel = Instance.new("TextLabel")
        fallbackLabel.Parent = FeatureContainer
        fallbackLabel.BackgroundTransparency = 1
        fallbackLabel.Size = UDim2.new(1, -2, 0, 60)
        fallbackLabel.Font = Enum.Font.Gotham
        fallbackLabel.Text = "GUI Initialized but some modules failed to load.\nLoaded: " .. (#loadedModules > 0 and table.concat(loadedModules, ", ") or "None")
        fallbackLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        fallbackLabel.TextSize = 8
        fallbackLabel.TextXAlignment = Enum.TextXAlignment.Left
        fallbackLabel.TextYAlignment = Enum.TextYAlignment.Top
        fallbackLabel.TextWrapped = true
    end

    task.wait(1)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "SuperTool",
            Text = "Successfully loaded! Made by FariNoveri_2",
            Duration = 5,
            Icon = "https://www.roblox.com/headshot-thumbnail/image?userId=7740869755&width=150&height=150&format=png",
        })
    end)

    if #failedModules > 0 then
        task.spawn(function()
            task.wait(5)
            for _, failedModule in ipairs(failedModules) do
                if not modulesLoaded[failedModule] then
                    task.spawn(function() loadModule(failedModule) end)
                end
                task.wait(2)
            end
        end)
    end
end)

RunService.Heartbeat:Connect(function()
    if ScreenGui and ScreenGui.Parent ~= player.PlayerGui then
        pcall(function() ScreenGui.Parent = player.PlayerGui end)
    end
end)

task.spawn(function()
    task.wait(10)
    if not ScreenGui or not ScreenGui.Parent then
        pcall(function()
            if ScreenGui then ScreenGui.Parent = player.PlayerGui end
        end)
    end
end)