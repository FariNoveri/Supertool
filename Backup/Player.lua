-- Player-related features for MinimalHackGUI by Fari Noveri, including spectate, player list, freeze players, bring player, fling, and magnet player
-- Enhanced with Physics Control and Improved Fling System

-- Dependencies: These must be passed from mainloader.lua
local Players, RunService, Workspace, humanoid, connections, buttonStates, ScrollFrame, ScreenGui, player

-- Initialize module
local Player = {}

-- Variables for player selection and spectate
Player.selectedPlayer = nil
Player.spectatePlayerList = {}
Player.currentSpectateIndex = 0
Player.spectateConnections = {}
Player.playerListVisible = false
Player.freezeEnabled = false
Player.frozenPlayerPositions = {}
Player.playerConnections = {}

-- Variables for new features
Player.fastRespawnEnabled = false
Player.noDeathAnimationEnabled = false
Player.deathAnimationConnections = {}
Player.magnetEnabled = false
Player.magnetOffset = Vector3.new(0, 0, -5)  -- Changed to directly in front
Player.magnetPlayerPositions = {}
Player.followEnabled = false
Player.followTarget = nil
Player.followConnections = {}
Player.followOffset = Vector3.new(0, 2, 5)
Player.followSpeed = 1.2
Player.followPathfinding = nil
Player.followPathHistory = {}

-- Variables for enhanced fling feature
Player.flingEnabled = false
Player.flingForce = 80 -- Increased from 50
Player.flingRange = 10
Player.flungPlayers = {}

-- Variables for physics control
Player.physicsEnabled = false
Player.physicsConnections = {}
Player.physicsPlayers = {}
Player.spinSpeed = 50 -- Increased from 20

-- Variables for teleport history
Player.teleportHistory = {}
Player.teleportFuture = {}

-- Variables for body size
Player.bodyScale = 1.0
Player.minScale = 0.5
Player.maxScale = 2.0
Player.scaleStep = 0.1

-- UI Elements
local PlayerListFrame, PlayerListScrollFrame, PlayerListLayout, SelectedPlayerLabel
local ClosePlayerListButton, NextSpectateButton, PrevSpectateButton, StopSpectateButton, TeleportSpectateButton
local EmoteGuiFrame
local SearchBox

local StarterGui = game:GetService("StarterGui")

-- Helper function to split string (Roblox Lua doesn't have string.split)
local function split(str, sep)
    local result = {}
    local regex = ("([^%s]+)"):format(sep)
    for Each in str:gmatch(regex) do
        table.insert(result, Each)
    end
    return result
end

-- Helper function to find player by partial name (enhanced matching)
local function findPlayer(name)
    if not name then return nil end
    name = name:lower()
    local candidates = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local pname = p.Name:lower()
        local dname = p.DisplayName:lower()
        if pname:find(name) or dname:find(name) then
            table.insert(candidates, p)
        end
    end
    if #candidates > 0 then
        table.sort(candidates, function(a, b)
            return a.Name:lower():find(name) < b.Name:lower():find(name)
        end)
        return candidates[1]
    end
    return nil
end

-- Force Field (God Mode replacement)
local function toggleForceField(enabled)
    Player.forceFieldEnabled = enabled
    if enabled then
        if player.Character then
            if not player.Character:FindFirstChild("ForceField") then
                local forceField = Instance.new("ForceField")
                forceField.Parent = player.Character
                forceField.Visible = false
                print("Force Field enabled")
            end
            
            connections.forcefield = player.CharacterAdded:Connect(function(character)
                if Player.forceFieldEnabled then
                    task.wait(0.1)
                    if not character:FindFirstChild("ForceField") then
                        local forceField = Instance.new("ForceField")
                        forceField.Parent = character
                        forceField.Visible = false
                        print("Force Field reapplied after respawn")
                    end
                end
            end)
            
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.MaxHealth = math.huge
                humanoid.Health = math.huge
                humanoid:GetPropertyChangedSignal("Health"):Connect(function()
                    if Player.forceFieldEnabled then
                        humanoid.Health = math.huge
                    end
                end)
            end
        else
            warn("Cannot enable Force Field: No character found")
        end
    else
        if player.Character then
            if player.Character:FindFirstChild("ForceField") then
                player.Character.ForceField:Destroy()
            end
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.MaxHealth = 100
                humanoid.Health = 100
            end
        end
        
        if connections.forcefield then
            connections.forcefield:Disconnect()
            connections.forcefield = nil
        end
        print("Force Field disabled")
    end
end

-- Anti AFK
local function toggleAntiAFK(enabled)
    Player.antiAFKEnabled = enabled
    if enabled then
        connections.antiafk = Players.LocalPlayer.Idled:Connect(function()
            if Player.antiAFKEnabled then
                local VirtualUser = game:GetService("VirtualUser")
                VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
                VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            end
        end)
        print("Anti AFK enabled")
    else
        if connections.antiafk then
            connections.antiafk:Disconnect()
            connections.antiafk = nil
        end
        print("Anti AFK disabled")
    end
end

-- Fast Respawn
local function toggleFastRespawn(enabled)
    Player.fastRespawnEnabled = enabled
    if enabled then
        connections.fastrespawn = player.CharacterRemoving:Connect(function()
            if Player.fastRespawnEnabled then
                print("Character removing, triggering fast respawn...")
                
                task.spawn(function()
                    local ReplicatedStorage = game:GetService("ReplicatedStorage")
                    local respawnRemote = ReplicatedStorage:FindFirstChild("RespawnRemote") or 
                                         ReplicatedStorage:FindFirstChild("Respawn") or
                                         ReplicatedStorage:FindFirstChild("LoadCharacter")
                    
                    if respawnRemote and respawnRemote:IsA("RemoteEvent") then
                        pcall(function()
                            respawnRemote:FireServer()
                            print("Fast respawn triggered via RemoteEvent")
                        end)
                    else
                        pcall(function()
                            player:LoadCharacter()
                            print("Fast respawn triggered via LoadCharacter")
                        end)
                    end
                    
                    local startTime = tick()
                    while not player.Character and Player.fastRespawnEnabled and (tick() - startTime) < 5 do
                        task.wait(0.05)
                    end
                    
                    if player.Character then
                        print("Fast respawn completed!")
                    end
                end)
            end
        end)
        
        connections.fastrespawncharadded = player.CharacterAdded:Connect(function(newCharacter)
            if Player.fastRespawnEnabled then
                print("Fast respawn: New character loaded")
                task.wait(0.2)
                if newCharacter:FindFirstChild("HumanoidRootPart") then
                    Player.rootPart = newCharacter.HumanoidRootPart
                end
            end
        end)
        
        print("Fast Respawn enabled")
    else
        if connections.fastrespawn then
            connections.fastrespawn:Disconnect()
            connections.fastrespawn = nil
        end
        if connections.fastrespawncharadded then
            connections.fastrespawncharadded:Disconnect()
            connections.fastrespawncharadded = nil
        end
        print("Fast Respawn disabled")
    end
end

-- No Death Animation
local function toggleNoDeathAnimation(enabled)
    Player.noDeathAnimationEnabled = enabled
    
    local function setupNoDeathForPlayer(targetPlayer)
        if Player.deathAnimationConnections[targetPlayer] then return end
        
        Player.deathAnimationConnections[targetPlayer] = {}
        
        local function setupCharacterNoDeathAnimation(character)
            if not Player.noDeathAnimationEnabled then return end
            
            local humanoidTarget = character:WaitForChild("Humanoid", 5)
            if humanoidTarget then
                Player.deathAnimationConnections[targetPlayer].died = humanoidTarget.Died:Connect(function()
                    if Player.noDeathAnimationEnabled then
                        for _, sound in pairs(character:GetDescendants()) do
                            if sound:IsA("Sound") then
                                sound:Stop()
                                sound.Volume = 0
                            end
                        end
                        
                        character.Archivable = false
                        for _, part in pairs(character:GetDescendants()) do
                            if part:IsA("BasePart") or part:IsA("Decal") then
                                part.Transparency = 1
                            elseif part:IsA("Accessory") then
                                local handle = part:FindFirstChild("Handle")
                                if handle then
                                    handle.Transparency = 1
                                end
                            end
                        end
                        
                        local animator = humanoidTarget:FindFirstChild("Animator")
                        if animator then
                            for _, track in pairs(animator:GetPlayingAnimationTracks()) do
                                track:Stop()
                            end
                        end
                        
                        print("Death animation and sound disabled for: " .. targetPlayer.Name)
                    end
                end)
            end
        end
        
        if targetPlayer.Character then
            setupCharacterNoDeathAnimation(targetPlayer.Character)
        end
        
        Player.deathAnimationConnections[targetPlayer].characterAdded = targetPlayer.CharacterAdded:Connect(function(character)
            setupCharacterNoDeathAnimation(character)
        end)
    end
    
    if enabled then
        for _, p in pairs(Players:GetPlayers()) do
            setupNoDeathForPlayer(p)
        end
        
        connections.nodeathanimation = Players.PlayerAdded:Connect(function(p)
            if Player.noDeathAnimationEnabled then
                setupNoDeathForPlayer(p)
            end
        end)
        
        print("No Death Animation enabled for all players")
    else
        for targetPlayer, playerConnections in pairs(Player.deathAnimationConnections) do
            for _, connection in pairs(playerConnections) do
                if connection then
                    connection:Disconnect()
                end
            end
        end
        Player.deathAnimationConnections = {}
        
        if connections.nodeathanimation then
            connections.nodeathanimation:Disconnect()
            connections.nodeathanimation = nil
        end
        
        print("No Death Animation disabled")
    end
end

-- Physics Control for Players - FIXED VERSION
local function enablePhysicsForPlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then
        print("Cannot enable physics: Invalid target player")
        return
    end
    
    if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        print("Cannot enable physics: Target player has no character")
        return
    end
    
    local success, result = pcall(function()
        local character = targetPlayer.Character
        local humanoid = character:FindFirstChild("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if not humanoid or not rootPart then
            print("Cannot enable physics: Missing parts")
            return
        end
        
        rootPart:SetNetworkOwner(player)
        
        -- IMPROVED PHYSICS: Make the character completely controllable by physics
        rootPart.Anchored = false
        rootPart.CanCollide = true
        rootPart.CanTouch = true
        rootPart.TopSurface = Enum.SurfaceType.Smooth
        rootPart.BottomSurface = Enum.SurfaceType.Smooth
        
        -- Disable humanoid states that interfere with physics
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
        humanoid.Sit = false
        
        -- Important: Set HipHeight to 0 to make physics work properly
        humanoid.HipHeight = 0
        
        -- Make all other body parts respond to physics properly
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part ~= rootPart then
                part.Anchored = false
                part.CanCollide = true
                part.CanTouch = true
                
                -- Remove any existing body movers
                for _, obj in pairs(part:GetChildren()) do
                    if obj:IsA("BodyVelocity") or obj:IsA("BodyPosition") or obj:IsA("BodyAngularVelocity") then
                        obj:Destroy()
                    end
                end
            end
        end
        
        -- Store physics data
        Player.physicsPlayers[targetPlayer] = {
            humanoid = humanoid,
            rootPart = rootPart,
            character = character,
            originalWalkSpeed = 16,
            originalJumpPower = 50
        }
        
        print("Enhanced Physics enabled for: " .. targetPlayer.Name)
    end)
    
    if not success then
        warn("Failed to enable physics: " .. tostring(result))
    end
end

-- Disable physics for a player
local function disablePhysicsForPlayer(targetPlayer)
    if not targetPlayer or not Player.physicsPlayers[targetPlayer] then
        return
    end
    
    local success, result = pcall(function()
        local physicsData = Player.physicsPlayers[targetPlayer]
        local humanoid = physicsData.humanoid
        local rootPart = physicsData.rootPart
        local character = physicsData.character
        
        if humanoid and humanoid.Parent then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            humanoid.WalkSpeed = physicsData.originalWalkSpeed
            humanoid.JumpPower = physicsData.originalJumpPower
            humanoid.HipHeight = 2  -- Standard HipHeight for R15
        end
        
        -- Clean up any remaining physics objects
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BodyVelocity") or part:IsA("BodyAngularVelocity") or part:IsA("BodyPosition") then
                    if part.Name:find("Physics") then
                        part:Destroy()
                    end
                end
            end
        end
        
        if rootPart then
            rootPart:SetNetworkOwner(nil)
        end
        
        Player.physicsPlayers[targetPlayer] = nil
        print("Physics disabled for: " .. targetPlayer.Name)
    end)
    
    if not success then
        warn("Failed to disable physics: " .. tostring(result))
    end
end

-- Toggle Physics Control
local function togglePhysicsControl(enabled)
    Player.physicsEnabled = enabled
    
    if enabled then
        print("Activating enhanced physics control...")
        
        -- Enable physics for all players
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player then
                enablePhysicsForPlayer(p)
            end
        end
        
        -- Monitor new players
        connections.physicsNewPlayers = Players.PlayerAdded:Connect(function(newPlayer)
            if Player.physicsEnabled and newPlayer ~= player then
                newPlayer.CharacterAdded:Connect(function(character)
                    task.wait(0.5)
                    enablePhysicsForPlayer(newPlayer)
                end)
                
                if newPlayer.Character then
                    task.wait(0.5)
                    enablePhysicsForPlayer(newPlayer)
                end
            end
        end)
        
        -- Monitor respawns
        connections.physicsRespawn = Players.PlayerRemoving:Connect(function(leavingPlayer)
            if Player.physicsPlayers[leavingPlayer] then
                Player.physicsPlayers[leavingPlayer] = nil
            end
        end)
        
        print("Enhanced physics control activated successfully")
    else
        print("Deactivating physics control...")
        
        if connections.physicsNewPlayers then
            connections.physicsNewPlayers:Disconnect()
            connections.physicsNewPlayers = nil
        end
        
        if connections.physicsRespawn then
            connections.physicsRespawn:Disconnect()
            connections.physicsRespawn = nil
        end
        
        -- Disable physics for all controlled players
        for targetPlayer, _ in pairs(Player.physicsPlayers) do
            disablePhysicsForPlayer(targetPlayer)
        end
        
        Player.physicsPlayers = {}
        print("Physics control deactivated successfully")
    end
end

-- Enhanced Fling Feature (like Infinite Yield)
local function enhancedFlingPlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then
        print("Cannot fling: Invalid target player")
        return
    end
    
    if not Player.rootPart then
        print("Cannot fling: Local player missing HumanoidRootPart")
        return
    end
    
    local success, result = pcall(function()
        local targetCharacter = targetPlayer.Character
        if not targetCharacter or not targetCharacter:FindFirstChild("HumanoidRootPart") then
            print("Cannot fling: Target player has no character or HumanoidRootPart")
            return
        end
        
        local targetRootPart = targetCharacter.HumanoidRootPart
        local targetHumanoid = targetCharacter:FindFirstChild("Humanoid")
        local distance = (Player.rootPart.Position - targetRootPart.Position).Magnitude
        
        if distance > Player.flingRange then
            print("Cannot fling: Target too far away (distance: " .. math.floor(distance) .. ")")
            return
        end
        
        -- Position local player at target for collision fling
        local oldCFrame = Player.rootPart.CFrame
        Player.rootPart.CFrame = targetRootPart.CFrame * CFrame.new(0, 0, -1)
        Player.rootPart.Anchored = false
        Player.rootPart.CanCollide = true
        
        -- High spin on local player
        local spin = Instance.new("BodyAngularVelocity")
        spin.AngularVelocity = Vector3.new(999999, 999999, 999999)
        spin.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        spin.Parent = Player.rootPart
        
        -- Apply velocity to target
        targetRootPart:SetNetworkOwner(player)
        targetRootPart.AssemblyLinearVelocity = Vector3.new(0, 10000, 0)
        
        task.delay(0.1, function()
            spin:Destroy()
            Player.rootPart.CFrame = oldCFrame
        end)
        
        task.delay(1, function()
            targetRootPart:SetNetworkOwner(nil)
        end)
        
        print("Fling applied to: " .. targetPlayer.Name)
    end)
    
    if not success then
        warn("Failed to fling player: " .. tostring(result))
    end
end

local function flingPlayer(targetPlayer)
    enhancedFlingPlayer(targetPlayer)
end

-- Toggle Enhanced Fling Mode - Continuously fling nearby players with FASTER spin
local function toggleFling(enabled)
    Player.flingEnabled = enabled
    
    if enabled then
        print("Enhanced FAST Fling mode enabled - will fling nearby players with faster spin")
        
        connections.fling = RunService.Heartbeat:Connect(function()
            if not Player.flingEnabled or not Player.rootPart then return end
            
            -- Make our character spin FASTER when fling mode is active
            local ourBodyAngularVel = Player.rootPart:FindFirstChild("FlingSpinVel")
            if not ourBodyAngularVel then
                ourBodyAngularVel = Instance.new("BodyAngularVelocity")
                ourBodyAngularVel.Name = "FlingSpinVel"
                ourBodyAngularVel.AngularVelocity = Vector3.new(0, Player.spinSpeed * 1.5, 0) -- 1.5x faster
                ourBodyAngularVel.MaxTorque = Vector3.new(0, math.huge, 0)
                ourBodyAngularVel.Parent = Player.rootPart
            end
            
            for _, targetPlayer in pairs(Players:GetPlayers()) do
                if targetPlayer ~= player and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local targetRootPart = targetPlayer.Character.HumanoidRootPart
                    local distance = (Player.rootPart.Position - targetRootPart.Position).Magnitude
                    
                    if distance <= Player.flingRange then
                        targetRootPart:SetNetworkOwner(player)
                        enablePhysicsForPlayer(targetPlayer)
                        
                        if not Player.flungPlayers[targetPlayer] then
                            Player.flungPlayers[targetPlayer] = true
                        end
                        
                        -- Apply continuous fling forces
                        local direction = (targetRootPart.Position - Player.rootPart.Position).Unit
                        local flingVelocity = direction * Player.flingForce * 1.2
                        flingVelocity = flingVelocity + Vector3.new(0, Player.flingForce * 0.6, 0)
                        
                        targetRootPart.Anchored = false
                        targetRootPart.AssemblyLinearVelocity = flingVelocity
                        
                        -- Add FASTER spinning effect to target
                        local targetBodyAngularVel = targetRootPart:FindFirstChild("TargetSpinVel")
                        if not targetBodyAngularVel then
                            targetBodyAngularVel = Instance.new("BodyAngularVelocity")
                            targetBodyAngularVel.Name = "TargetSpinVel"
                            targetBodyAngularVel.AngularVelocity = Vector3.new(
                                math.random(-Player.spinSpeed * 2, Player.spinSpeed * 2),
                                math.random(-Player.spinSpeed * 2, Player.spinSpeed * 2),
                                math.random(-Player.spinSpeed * 2, Player.spinSpeed * 2)
                            )
                            targetBodyAngularVel.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                            targetBodyAngularVel.Parent = targetRootPart
                        end
                    else
                        if Player.flungPlayers[targetPlayer] then
                            -- Clean up when player moves away
                            local targetBodyAngularVel = targetRootPart:FindFirstChild("TargetSpinVel")
                            if targetBodyAngularVel then
                                targetBodyAngularVel:Destroy()
                            end
                            
                            local targetHumanoid = targetPlayer.Character:FindFirstChild("Humanoid")
                            if targetHumanoid then
                                targetHumanoid.PlatformStand = false
                                targetHumanoid.WalkSpeed = 16
                                targetHumanoid.JumpPower = 50
                            end
                            if targetRootPart then
                                targetRootPart:SetNetworkOwner(nil)
                            end
                            disablePhysicsForPlayer(targetPlayer)
                            Player.flungPlayers[targetPlayer] = nil
                        end
                    end
                end
            end
        end)
        
        connections.flingRespawn = player.CharacterAdded:Connect(function(character)
            if Player.flingEnabled then
                task.wait(0.5)
                Player.rootPart = character:FindFirstChild("HumanoidRootPart")
            end
        end)
        
        print("Enhanced FAST Fling mode activated successfully")
    else
        -- Clean up our spinning
        if Player.rootPart then
            local ourSpinVel = Player.rootPart:FindFirstChild("FlingSpinVel")
            if ourSpinVel then
                ourSpinVel:Destroy()
            end
        end
        
        if connections.fling then
            connections.fling:Disconnect()
            connections.fling = nil
        end
        
        if connections.flingRespawn then
            connections.flingRespawn:Disconnect()
            connections.flingRespawn = nil
        end
        
        -- Clean up all flung players
        for targetPlayer, _ in pairs(Player.flungPlayers) do
            if targetPlayer.Character then
                local targetRootPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetRootPart then
                    local targetBodyAngularVel = targetRootPart:FindFirstChild("TargetSpinVel")
                    if targetBodyAngularVel then
                        targetBodyAngularVel:Destroy()
                    end
                    targetRootPart:SetNetworkOwner(nil)
                end
                
                local targetHumanoid = targetPlayer.Character:FindFirstChild("Humanoid")
                if targetHumanoid then
                    targetHumanoid.PlatformStand = false
                    targetHumanoid.WalkSpeed = 16
                    targetHumanoid.JumpPower = 50
                end
                
                disablePhysicsForPlayer(targetPlayer)
            end
        end
        Player.flungPlayers = {}
        
        print("Enhanced Fling mode disabled")
    end
end

-- Bring Player (Improved with direct CFrame set after taking ownership for server-side effect)
local function bringPlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then
        print("Cannot bring: Invalid target player")
        return
    end
    
    if not Player.rootPart then
        print("Cannot bring: Local player missing HumanoidRootPart")
        return
    end
    
    local success, result = pcall(function()
        local targetCharacter = targetPlayer.Character
        if not targetCharacter or not targetCharacter:FindFirstChild("HumanoidRootPart") then
            print("Cannot bring: Target player has no character or HumanoidRootPart")
            return
        end
        
        local targetRootPart = targetCharacter.HumanoidRootPart
        targetRootPart:SetNetworkOwner(player)
        
        -- Ensure the target player isn't anchored
        targetRootPart.Anchored = false
        
        -- Ensure humanoid is in a proper state
        local targetHumanoid = targetCharacter:FindFirstChild("Humanoid")
        if targetHumanoid then
            targetHumanoid.PlatformStand = false
            targetHumanoid.WalkSpeed = 16
            targetHumanoid.JumpPower = 50
        end
        
        local ourCFrame = Player.rootPart.CFrame
        local newCFrame = ourCFrame * CFrame.new(0, 0, -5)
        
        -- Direct set with anchor trick for better replication
        targetRootPart.Anchored = true
        targetRootPart.CFrame = newCFrame
        task.wait(0.1)
        targetRootPart.Anchored = false
        
        -- Hold ownership a bit longer
        task.delay(0.5, function()
            targetRootPart:SetNetworkOwner(nil)
            print("Brought player and released: " .. targetPlayer.Name)
        end)
    end)
    
    if not success then
        warn("Failed to bring player: " .. tostring(result))
    end
end

-- Magnet Players (client-side visual only using RenderStepped CFrame override)
local function toggleMagnetPlayers(enabled)
    Player.magnetEnabled = enabled
    
    if enabled then
        print("Activating magnet players (client-side visual)...")
        
        connections.magnet = RunService.RenderStepped:Connect(function()
            if not Player.magnetEnabled or not Player.rootPart then return end
            
            local ourCFrame = Player.rootPart.CFrame
            for _, targetPlayer in pairs(Players:GetPlayers()) do
                if targetPlayer ~= player and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = targetPlayer.Character.HumanoidRootPart
                    local targetPosition = (ourCFrame * CFrame.new(Player.magnetOffset)).Position
                    hrp.CFrame = CFrame.new(targetPosition) * ourCFrame.Rotation
                end
            end
        end)
        
        connections.magnetNewPlayers = Players.PlayerAdded:Connect(function(newPlayer)
            if Player.magnetEnabled and newPlayer ~= player then
                newPlayer.CharacterAdded:Connect(function(character)
                    task.wait(0.5)
                    print("Magnet (visual) applied to new player: " .. newPlayer.Name)
                end)
            end
        end)
        
        connections.magnetRespawn = player.CharacterAdded:Connect(function(character)
            if Player.magnetEnabled then
                task.wait(0.5)
                Player.rootPart = character:FindFirstChild("HumanoidRootPart")
            end
        end)
        
        print("Magnet players activated successfully (client-side visual)")
    else
        print("Deactivating magnet players...")
        if connections.magnet then
            connections.magnet:Disconnect()
            connections.magnet = nil
        end
        
        if connections.magnetNewPlayers then
            connections.magnetNewPlayers:Disconnect()
            connections.magnetNewPlayers = nil
        end
        
        if connections.magnetRespawn then
            connections.magnetRespawn:Disconnect()
            connections.magnetRespawn = nil
        end
        
        print("Magnet players deactivated successfully")
    end
end

-- Helper function to freeze a single player (client-side visual with stored CFrame)
local function freezePlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then return end
    
    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = targetPlayer.Character.HumanoidRootPart
        Player.frozenPlayerPositions[targetPlayer] = hrp.CFrame
        print("Froze player (visual): " .. targetPlayer.Name)
    end
end

-- Helper function to unfreeze a single player
local function unfreezePlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then return end
    
    Player.frozenPlayerPositions[targetPlayer] = nil
    print("Unfroze player: " .. targetPlayer.Name)
end

-- Setup monitoring for a specific player
local function setupPlayerMonitoring(targetPlayer)
    if targetPlayer == player or Player.playerConnections[targetPlayer] then return end
    
    Player.playerConnections[targetPlayer] = {}
    
    Player.playerConnections[targetPlayer].characterAdded = targetPlayer.CharacterAdded:Connect(function(character)
        task.wait(0.5)
        
        if Player.freezeEnabled then
            freezePlayer(targetPlayer)
            print("Auto-froze respawned player (visual): " .. targetPlayer.Name)
        end
        
        if Player.physicsEnabled then
            enablePhysicsForPlayer(targetPlayer)
            print("Physics applied to respawned player: " .. targetPlayer.Name)
        end
        
        if Player.selectedPlayer == targetPlayer then
            task.wait(0.5)
            spectatePlayer(targetPlayer)
            print("Resumed spectating respawned player: " .. targetPlayer.Name)
        end
        
        if Player.noDeathAnimationEnabled then
            local humanoidTarget = character:WaitForChild("Humanoid", 5)
            if humanoidTarget and not Player.deathAnimationConnections[targetPlayer] then
                toggleNoDeathAnimation(true)
            end
        end
    end)
    
    if Player.freezeEnabled and targetPlayer.Character then
        freezePlayer(targetPlayer)
    end
    
    if Player.physicsEnabled then
        enablePhysicsForPlayer(targetPlayer)
    end
    
    if Player.noDeathAnimationEnabled then
        toggleNoDeathAnimation(true)
    end
end

-- Clean up monitoring for a specific player
local function cleanupPlayerMonitoring(targetPlayer)
    if Player.playerConnections[targetPlayer] then
        for _, connection in pairs(Player.playerConnections[targetPlayer]) do
            if connection then
                connection:Disconnect()
            end
        end
        Player.playerConnections[targetPlayer] = nil
    end
    
    if Player.deathAnimationConnections[targetPlayer] then
        for _, connection in pairs(Player.deathAnimationConnections[targetPlayer]) do
            if connection then
                connection:Disconnect()
            end
        end
        Player.deathAnimationConnections[targetPlayer] = nil
    end
    
    Player.frozenPlayerPositions[targetPlayer] = nil
    disablePhysicsForPlayer(targetPlayer)
end

-- Freeze Players (client-side visual using RenderStepped CFrame override)
local function toggleFreezePlayers(enabled)
    Player.freezeEnabled = enabled
    
    if enabled then
        print("Activating freeze players (client-side visual)...")
        Player.frozenPlayerPositions = {}
        
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player then
                setupPlayerMonitoring(p)
                freezePlayer(p)
            end
        end
        
        if not connections.freezeNewPlayers then
            connections.freezeNewPlayers = Players.PlayerAdded:Connect(function(newPlayer)
                if Player.freezeEnabled and newPlayer ~= player then
                    print("New player joined, setting up freeze monitoring: " .. newPlayer.Name)
                    setupPlayerMonitoring(newPlayer)
                    
                    if newPlayer.Character then
                        task.wait(0.5)
                        freezePlayer(newPlayer)
                    else
                        newPlayer.CharacterAdded:Wait()
                        task.wait(0.5)
                        freezePlayer(newPlayer)
                    end
                end
            end)
        end
        
        connections.freeze = RunService.RenderStepped:Connect(function()
            if Player.freezeEnabled then
                for targetPlayer, frozenCFrame in pairs(Player.frozenPlayerPositions) do
                    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = targetPlayer.Character.HumanoidRootPart
                        hrp.CFrame = frozenCFrame
                    end
                end
            end
        end)
        print("Players frozen successfully (client-side visual)")
    else
        print("Deactivating freeze players...")
        if connections.freeze then
            connections.freeze:Disconnect()
            connections.freeze = nil
        end
        
        if connections.freezeNewPlayers then
            connections.freezeNewPlayers:Disconnect()
            connections.freezeNewPlayers = nil
        end
        
        for targetPlayer, _ in pairs(Player.frozenPlayerPositions) do
            unfreezePlayer(targetPlayer)
        end
        
        for targetPlayer, _ in pairs(Player.playerConnections) do
            cleanupPlayerMonitoring(targetPlayer)
        end
        
        Player.frozenPlayerPositions = {}
        Player.playerConnections = {}
        print("Players unfrozen successfully")
    end
end

-- Teleport to Player
local function teleportToPlayer(targetPlayer, direction)
    if not targetPlayer then
        print("Cannot teleport: No player selected")
        return
    end
    
    if targetPlayer.Name == "farinoveri_2" then
        print("Cannot teleport to this player: Access denied")
        StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] Cannot teleport to farinoveri_2"})
        return
    end
    
    local success, result = pcall(function()
        if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            if not Player.rootPart then
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    Player.rootPart = player.Character.HumanoidRootPart
                else
                    print("Cannot teleport: Local player missing HumanoidRootPart")
                    return
                end
            end
            
            table.insert(Player.teleportHistory, Player.rootPart.CFrame)
            Player.teleportFuture = {}
            
            local targetPosition = targetPlayer.Character.HumanoidRootPart.CFrame
            local offset = Vector3.new(0, 0, 5) -- default back
            if direction then
                direction = direction:lower()
                if direction == "front" then
                    offset = Vector3.new(0, 0, -5)
                elseif direction == "back" then
                    offset = Vector3.new(0, 0, 5)
                elseif direction == "left" then
                    offset = Vector3.new(-5, 0, 0)
                elseif direction == "right" then
                    offset = Vector3.new(5, 0, 0)
                end
            end
            local newPosition = targetPosition * CFrame.new(offset)
            Player.rootPart.CFrame = newPosition
            print("Teleported to: " .. targetPlayer.Name)
        else
            print("Cannot teleport: No valid player or missing HumanoidRootPart")
        end
    end)
    
    if not success then
        warn("Teleport failed: " .. tostring(result))
    end
end

-- Teleport to Spectated Player (Fixed)
local function teleportToSpectatedPlayer()
    teleportToPlayer(Player.selectedPlayer)
end

-- Back Teleport
local function backTeleport()
    if #Player.teleportHistory == 0 then
        StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] no previous position"})
        return
    end
    local prevCFrame = table.remove(Player.teleportHistory)
    if Player.rootPart then
        table.insert(Player.teleportFuture, Player.rootPart.CFrame)
        Player.rootPart.CFrame = prevCFrame
        StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] back to previous position"})
    end
end

-- Next Teleport
local function nextTeleport()
    if #Player.teleportFuture == 0 then
        StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] no next position"})
        return
    end
    local nextCFrame = table.remove(Player.teleportFuture)
    if Player.rootPart then
        table.insert(Player.teleportHistory, Player.rootPart.CFrame)
        Player.rootPart.CFrame = nextCFrame
        StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] next to forward position"})
    end
end

-- Show Emote GUI
local function showEmoteGui()
    if EmoteGuiFrame then
        EmoteGuiFrame.Visible = not EmoteGuiFrame.Visible
    else
        warn("EmoteGuiFrame not initialized")
    end
end

-- Stop Following Player
local function stopFollowing()
    Player.followEnabled = false
    Player.followTarget = nil
    Player.lastTargetPosition = nil
    Player.followPathHistory = {}
    
    for _, connection in pairs(Player.followConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    Player.followConnections = {}
    
    if Player.followPathfinding then
        Player.followPathfinding = nil
    end
    
    if humanoid then
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
        humanoid.PlatformStand = false
    end
    
    print("Stopped following player")
    Player.updatePlayerList()
end

-- Follow Player (client-side, follow exact path with history - improved recording)
local function followPlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then
        print("Cannot follow: Invalid target player")
        return
    end
    
    if targetPlayer.Name == "farinoveri_2" then
        print("Cannot follow this player: Access denied")
        StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] Cannot follow farinoveri_2"})
        return
    end
    
    if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        print("Cannot follow: Target player has no character or HumanoidRootPart")
        return
    end
    
    if not Player.rootPart or not humanoid then
        print("Cannot follow: Missing local player's rootPart or humanoid")
        return
    end
    
    stopFollowing()
    
    Player.followEnabled = true
    Player.followTarget = targetPlayer
    Player.followPathHistory = {}
    
    local targetRootPart = targetPlayer.Character.HumanoidRootPart
    local targetHumanoid = targetPlayer.Character.Humanoid
    
    print("Started following: " .. targetPlayer.Name)
    
    -- Record target path more frequently
    Player.followConnections.record = RunService.RenderStepped:Connect(function()
        if Player.followEnabled then
            table.insert(Player.followPathHistory, {Position = targetRootPart.Position, Time = tick()})
            if #Player.followPathHistory > 200 then  -- Increased buffer
                table.remove(Player.followPathHistory, 1)
            end
        end
    end)
    
    Player.followConnections.follow = RunService.Heartbeat:Connect(function()
        if not Player.followEnabled or not Player.followTarget then
            stopFollowing()
            return
        end
        
        if #Player.followPathHistory > 0 then
            local nextPos = Player.followPathHistory[1].Position
            humanoid:MoveTo(nextPos)
            if (Player.rootPart.Position - nextPos).Magnitude < 1 then  -- Tighter threshold
                table.remove(Player.followPathHistory, 1)
            end
        end
        
        humanoid.WalkSpeed = math.max(targetHumanoid.WalkSpeed * Player.followSpeed, 16)
        
        if targetHumanoid.Jump and not humanoid.Jump then
            humanoid.Jump = true
        end
        
        if targetHumanoid.Sit ~= humanoid.Sit then
            humanoid.Sit = targetHumanoid.Sit
        end
    end)
    
    Player.followConnections.characterAdded = Player.followTarget.CharacterAdded:Connect(function(newCharacter)
        if not Player.followEnabled or Player.followTarget ~= targetPlayer then return end
        
        local newRootPart = newCharacter:WaitForChild("HumanoidRootPart", 10)
        local newHumanoid = newCharacter:WaitForChild("Humanoid", 10)
        
        if newRootPart and newHumanoid then
            print("Target respawned, continuing follow: " .. Player.followTarget.Name)
            targetRootPart = newRootPart
            targetHumanoid = newHumanoid
            Player.followPathHistory = {}
        else
            print("Failed to get new character parts for follow target")
            stopFollowing()
        end
    end)
    
    Player.followConnections.playerRemoving = Players.PlayerRemoving:Connect(function(leavingPlayer)
        if leavingPlayer == Player.followTarget then
            print("Follow target left the game")
            stopFollowing()
        end
    end)
    
    Player.followConnections.ourCharacterAdded = player.CharacterAdded:Connect(function(newCharacter)
        if not Player.followEnabled then return end
        
        local newRootPart = newCharacter:WaitForChild("HumanoidRootPart", 10)
        local newHumanoid = newCharacter:WaitForChild("Humanoid", 10)
        
        if newRootPart and newHumanoid then
            Player.rootPart = newRootPart
            humanoid = newHumanoid
            print("Our character respawned, continuing follow")
        else
            print("Failed to get our new character parts")
            stopFollowing()
        end
    end)
    
    Player.updatePlayerList()
end

-- Toggle Follow Player
local function toggleFollowPlayer(targetPlayer)
    if not targetPlayer then
        print("No player selected to follow")
        return
    end
    if Player.followTarget == targetPlayer then
        stopFollowing()
    else
        followPlayer(targetPlayer)
    end
end

-- Set Body Scale
local function setBodyScale(scale)
    scale = math.clamp(scale, Player.minScale, Player.maxScale)
    Player.bodyScale = scale
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        local hum = player.Character.Humanoid
        hum.BodyDepthScale.Value = scale
        hum.BodyHeightScale.Value = scale
        hum.BodyWidthScale.Value = scale
        hum.HeadScale.Value = scale
        print("Set body scale to: " .. scale)
    end
end

-- Increase Body Scale
local function increaseScale()
    setBodyScale(Player.bodyScale + Player.scaleStep)
end

-- Decrease Body Scale
local function decreaseScale()
    setBodyScale(Player.bodyScale - Player.scaleStep)
end

-- Reset Body Scale
local function resetScale()
    setBodyScale(1.0)
end

-- Show Player Selection UI
local function showPlayerSelection()
    Player.playerListVisible = true
    if PlayerListFrame then
        PlayerListFrame.Visible = true
        Player.updatePlayerList()
    else
        warn("PlayerListFrame not initialized")
    end
end

-- Update Spectate Buttons Visibility
local function updateSpectateButtons()
    local isSelected = Player.selectedPlayer ~= nil
    if NextSpectateButton then NextSpectateButton.Visible = isSelected end
    if PrevSpectateButton then PrevSpectateButton.Visible = isSelected end
    if StopSpectateButton then StopSpectateButton.Visible = isSelected end
    if TeleportSpectateButton then TeleportSpectateButton.Visible = isSelected end
end

-- Stop Spectating
local function stopSpectating()
    for _, connection in pairs(Player.spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    Player.spectateConnections = {}
    
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        Workspace.CurrentCamera.CameraSubject = player.Character.Humanoid
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    elseif humanoid then
        Workspace.CurrentCamera.CameraSubject = humanoid
    end
    
    Player.selectedPlayer = nil
    Player.currentSpectateIndex = 0
    if SelectedPlayerLabel then
        SelectedPlayerLabel.Text = "SELECTED: NONE"
    end
    
    updateSpectateButtons()
    
    if PlayerListScrollFrame then
        for _, item in pairs(PlayerListScrollFrame:GetChildren()) do
            if item:IsA("Frame") and item:FindFirstChild("SelectButton") then
                item.SelectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                item.SelectButton.Text = "SELECT PLAYER"
            end
        end
    end
    print("Stopped spectating")
end

-- Spectate Player (Fixed)
local function spectatePlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then
        print("Cannot spectate: Invalid target player")
        stopSpectating()
        return
    end
    
    if targetPlayer.Name == "farinoveri_2" then
        print("Cannot spectate this player: Access denied")
        StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] Cannot spectate farinoveri_2"})
        return
    end
    
    -- Stop current spectating first
    for _, connection in pairs(Player.spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    Player.spectateConnections = {}
    
    local success, result = pcall(function()
        -- Check if target player has valid character
        if not targetPlayer.Character then
            print("Cannot spectate: Target player has no character")
            return false
        end
        
        local targetHumanoid = targetPlayer.Character:FindFirstChild("Humanoid")
        if not targetHumanoid then
            print("Cannot spectate: Target player has no humanoid")
            return false
        end
        
        -- Set camera to spectate target
        Workspace.CurrentCamera.CameraSubject = targetHumanoid
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        
        Player.selectedPlayer = targetPlayer
        
        -- Find the target in spectate list and set index
        for i, p in ipairs(Player.spectatePlayerList) do
            if p == targetPlayer then
                Player.currentSpectateIndex = i
                break
            end
        end
        
        if SelectedPlayerLabel then
            SelectedPlayerLabel.Text = "SELECTED: " .. targetPlayer.Name:upper()
        end
        print("Spectating: " .. targetPlayer.Name)
        
        -- Setup connections for spectating
        Player.spectateConnections.characterAdded = targetPlayer.CharacterAdded:Connect(function(newCharacter)
            if Player.selectedPlayer == targetPlayer then
                local newHumanoid = newCharacter:WaitForChild("Humanoid", 10)
                if newHumanoid then
                    task.wait(0.5)
                    Workspace.CurrentCamera.CameraSubject = newHumanoid
                    Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                    print("Spectated player respawned, continuing spectate: " .. targetPlayer.Name)
                else
                    print("Failed to get humanoid after respawn, stopping spectate")
                    stopSpectating()
                end
            end
        end)
        
        Player.spectateConnections.died = targetHumanoid.Died:Connect(function()
            if Player.selectedPlayer == targetPlayer then
                print("Spectated player died, waiting for respawn: " .. targetPlayer.Name)
            end
        end)
        
        Player.spectateConnections.playerRemoving = Players.PlayerRemoving:Connect(function(leavingPlayer)
            if leavingPlayer == targetPlayer and Player.selectedPlayer == targetPlayer then
                print("Spectated player left the game")
                stopSpectating()
            end
        end)
        
        -- Update UI
        if PlayerListScrollFrame then
            for _, item in pairs(PlayerListScrollFrame:GetChildren()) do
                if item:IsA("Frame") and item:FindFirstChild("SelectButton") then
                    if item.Name == targetPlayer.Name .. "Item" then
                        item.SelectButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                        item.SelectButton.Text = "SELECTED"
                    else
                        item.SelectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                        item.SelectButton.Text = "SELECT PLAYER"
                    end
                end
            end
        end
        
        return true
    end)
    
    if not success then
        warn("Failed to spectate player: " .. tostring(result))
        stopSpectating()
        return
    end
    
    updateSpectateButtons()
end

-- Spectate Next Player (Fixed)
local function spectateNextPlayer()
    if #Player.spectatePlayerList == 0 then
        print("No players to spectate")
        stopSpectating()
        return
    end
    
    local attempts = 0
    local maxAttempts = #Player.spectatePlayerList
    
    while attempts < maxAttempts do
        Player.currentSpectateIndex = (Player.currentSpectateIndex % #Player.spectatePlayerList) + 1
        local targetPlayer = Player.spectatePlayerList[Player.currentSpectateIndex]
        
        if targetPlayer and targetPlayer.Parent == Players and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
            spectatePlayer(targetPlayer)
            return
        end
        
        attempts = attempts + 1
    end
    
    print("No valid players to spectate")
    stopSpectating()
end

-- Spectate Previous Player (Fixed)
local function spectatePrevPlayer()
    if #Player.spectatePlayerList == 0 then
        print("No players to spectate")
        stopSpectating()
        return
    end
    
    local attempts = 0
    local maxAttempts = #Player.spectatePlayerList
    
    while attempts < maxAttempts do
        Player.currentSpectateIndex = Player.currentSpectateIndex - 1
        if Player.currentSpectateIndex < 1 then
            Player.currentSpectateIndex = #Player.spectatePlayerList
        end
        
        local targetPlayer = Player.spectatePlayerList[Player.currentSpectateIndex]
        
        if targetPlayer and targetPlayer.Parent == Players and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
            spectatePlayer(targetPlayer)
            return
        end
        
        attempts = attempts + 1
    end
    
    print("No valid players to spectate")
    stopSpectating()
end

-- Update Player List - FIXED VERSION with proper button connections
function Player.updatePlayerList()
    if not PlayerListScrollFrame then
        warn("PlayerListScrollFrame not initialized")
        return
    end
    
    -- Clear existing items
    for _, child in pairs(PlayerListScrollFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    local previousSelectedPlayer = Player.selectedPlayer
    Player.spectatePlayerList = {}
    local playerCount = 0
    
    -- Get search text
    local searchText = ""
    if SearchBox then
        searchText = string.lower(SearchBox.Text)
    end
    
    -- Get all players excluding local player
    local allPlayers = Players:GetPlayers()
    local validPlayers = {}
    
    for _, p in pairs(allPlayers) do
        if p ~= player and p.Parent == Players then -- Check if player is still in game
            local usernameLower = string.lower(p.Name)
            local displayNameLower = string.lower(p.DisplayName)
            if searchText == "" or string.find(usernameLower, searchText) or string.find(displayNameLower, searchText) then
                table.insert(validPlayers, p)
                table.insert(Player.spectatePlayerList, p)
            end
        end
    end
    
    if #validPlayers == 0 then
        local noPlayersLabel = Instance.new("TextLabel")
        noPlayersLabel.Name = "NoPlayersLabel"
        noPlayersLabel.Parent = PlayerListScrollFrame
        noPlayersLabel.BackgroundTransparency = 1
        noPlayersLabel.Size = UDim2.new(1, 0, 0, 30)
        noPlayersLabel.Font = Enum.Font.Gotham
        noPlayersLabel.Text = "No players found"
        noPlayersLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        noPlayersLabel.TextSize = 11
        noPlayersLabel.TextXAlignment = Enum.TextXAlignment.Center
        noPlayersLabel.ZIndex = 1
    else
        for _, p in pairs(validPlayers) do
            playerCount = playerCount + 1
            
            local playerItem = Instance.new("Frame")
            playerItem.Name = p.Name .. "Item"
            playerItem.Parent = PlayerListScrollFrame
            playerItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            playerItem.BorderSizePixel = 0
            playerItem.Size = UDim2.new(1, -5, 0, 130)
            playerItem.LayoutOrder = playerCount
            playerItem.ZIndex = 1
            
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Name = "NameLabel"
            nameLabel.Parent = playerItem
            nameLabel.BackgroundTransparency = 1
            nameLabel.Position = UDim2.new(0, 5, 0, 5)
            nameLabel.Size = UDim2.new(1, -10, 0, 20)
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.Text = p.DisplayName .. " (@" .. p.Name .. ")"
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.TextSize = 12
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.ZIndex = 2
            
            local selectButton = Instance.new("TextButton")
            selectButton.Name = "SelectButton"
            selectButton.Parent = playerItem
            selectButton.BackgroundColor3 = Player.selectedPlayer == p and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(60, 60, 60)
            selectButton.BorderSizePixel = 0
            selectButton.Position = UDim2.new(0, 5, 0, 30)
            selectButton.Size = UDim2.new(1, -10, 0, 25)
            selectButton.Font = Enum.Font.Gotham
            selectButton.Text = Player.selectedPlayer == p and "SELECTED" or "SELECT PLAYER"
            selectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            selectButton.TextSize = 10
            selectButton.ZIndex = 2
            selectButton.Active = true
            selectButton.Selectable = true
            
            local spectateButton = Instance.new("TextButton")
            spectateButton.Name = "SpectateButton"
            spectateButton.Parent = playerItem
            spectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
            spectateButton.BorderSizePixel = 0
            spectateButton.Position = UDim2.new(0, 5, 0, 60)
            spectateButton.Size = UDim2.new(0, 70, 0, 25)
            spectateButton.Font = Enum.Font.Gotham
            spectateButton.Text = "SPECTATE"
            spectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            spectateButton.TextSize = 9
            spectateButton.ZIndex = 2
            spectateButton.Active = true
            
            local stopSpectateButton = Instance.new("TextButton")
            stopSpectateButton.Name = "StopSpectateButton"
            stopSpectateButton.Parent = playerItem
            stopSpectateButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
            stopSpectateButton.BorderSizePixel = 0
            stopSpectateButton.Position = UDim2.new(0, 80, 0, 60)
            stopSpectateButton.Size = UDim2.new(0, 70, 0, 25)
            stopSpectateButton.Font = Enum.Font.Gotham
            stopSpectateButton.Text = "STOP"
            stopSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            stopSpectateButton.TextSize = 9
            stopSpectateButton.ZIndex = 2
            stopSpectateButton.Active = true
            
            local teleportButton = Instance.new("TextButton")
            teleportButton.Name = "TeleportButton"
            teleportButton.Parent = playerItem
            teleportButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
            teleportButton.BorderSizePixel = 0
            teleportButton.Position = UDim2.new(0, 155, 0, 60)
            teleportButton.Size = UDim2.new(1, -160, 0, 25)
            teleportButton.Font = Enum.Font.Gotham
            teleportButton.Text = "TELEPORT"
            teleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            teleportButton.TextSize = 9
            teleportButton.ZIndex = 2
            teleportButton.Active = true
            
            local followButton = Instance.new("TextButton")
            followButton.Name = "FollowButton"
            followButton.Parent = playerItem
            followButton.BackgroundColor3 = Player.followTarget == p and Color3.fromRGB(80, 60, 40) or Color3.fromRGB(60, 40, 80)
            followButton.BorderSizePixel = 0
            followButton.Position = UDim2.new(0, 5, 0, 90)
            followButton.Size = UDim2.new(0, 70, 0, 25)
            followButton.Font = Enum.Font.Gotham
            followButton.Text = Player.followTarget == p and "FOLLOWING" or "FOLLOW"
            followButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            followButton.TextSize = 9
            followButton.ZIndex = 2
            followButton.Active = true
            
            local stopFollowButton = Instance.new("TextButton")
            stopFollowButton.Name = "StopFollowButton"
            stopFollowButton.Parent = playerItem
            stopFollowButton.BackgroundColor3 = Color3.fromRGB(80, 40, 60)
            stopFollowButton.BorderSizePixel = 0
            stopFollowButton.Position = UDim2.new(0, 80, 0, 90)
            stopFollowButton.Size = UDim2.new(0, 70, 0, 25)
            stopFollowButton.Font = Enum.Font.Gotham
            stopFollowButton.Text = "STOP FOLLOW"
            stopFollowButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            stopFollowButton.TextSize = 8
            stopFollowButton.ZIndex = 2
            stopFollowButton.Active = true
            
            local bringButton = Instance.new("TextButton")
            bringButton.Name = "BringButton"
            bringButton.Parent = playerItem
            bringButton.BackgroundColor3 = Color3.fromRGB(40, 60, 80)
            bringButton.BorderSizePixel = 0
            bringButton.Position = UDim2.new(0, 155, 0, 90)
            bringButton.Size = UDim2.new(1, -160, 0, 25)
            bringButton.Font = Enum.Font.Gotham
            bringButton.Text = "BRING"
            bringButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            bringButton.TextSize = 9
            bringButton.ZIndex = 2
            bringButton.Active = true
            
            -- FIXED Button Events - Use closure to capture the current player properly
            local function createButtonConnections(currentPlayer)
                selectButton.MouseButton1Click:Connect(function()
                    print("SELECT clicked for: " .. currentPlayer.Name)
                    Player.selectedPlayer = currentPlayer
                    Player.currentSpectateIndex = table.find(Player.spectatePlayerList, currentPlayer) or 0
                    if SelectedPlayerLabel then
                        SelectedPlayerLabel.Text = "SELECTED: " .. currentPlayer.Name:upper()
                    end
                    -- Update all select buttons
                    for _, item in pairs(PlayerListScrollFrame:GetChildren()) do
                        if item:IsA("Frame") and item:FindFirstChild("SelectButton") then
                            local btn = item.SelectButton
                            btn.BackgroundColor3 = item.Name == currentPlayer.Name .. "Item" and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(60, 60, 60)
                            btn.Text = item.Name == currentPlayer.Name .. "Item" and "SELECTED" or "SELECT PLAYER"
                        end
                    end
                    updateSpectateButtons()
                end)
                
                spectateButton.MouseButton1Click:Connect(function()
                    print("SPECTATE clicked for: " .. currentPlayer.Name)
                    Player.currentSpectateIndex = table.find(Player.spectatePlayerList, currentPlayer) or 0
                    spectatePlayer(currentPlayer)
                end)
                
                stopSpectateButton.MouseButton1Click:Connect(function()
                    print("STOP SPECTATE clicked")
                    stopSpectating()
                end)
                
                teleportButton.MouseButton1Click:Connect(function()
                    print("TELEPORT clicked for: " .. currentPlayer.Name)
                    teleportToPlayer(currentPlayer)
                end)
                
                followButton.MouseButton1Click:Connect(function()
                    print("FOLLOW clicked for: " .. currentPlayer.Name)
                    toggleFollowPlayer(currentPlayer)
                    task.spawn(function()
                        task.wait(0.1)
                        Player.updatePlayerList()
                    end)
                end)
                
                stopFollowButton.MouseButton1Click:Connect(function()
                    print("STOP FOLLOW clicked for: " .. currentPlayer.Name)
                    if Player.followTarget == currentPlayer then
                        stopFollowing()
                        task.spawn(function()
                            task.wait(0.1)
                            Player.updatePlayerList()
                        end)
                    end
                end)
                
                bringButton.MouseButton1Click:Connect(function()
                    print("BRING clicked for: " .. currentPlayer.Name)
                    bringPlayer(currentPlayer)
                end)
                
                -- Add hover effects
                selectButton.MouseEnter:Connect(function()
                    if Player.selectedPlayer ~= currentPlayer then
                        selectButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                    end
                end)
                
                selectButton.MouseLeave:Connect(function()
                    if Player.selectedPlayer ~= currentPlayer then
                        selectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    else
                        selectButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                    end
                end)
                
                spectateButton.MouseEnter:Connect(function()
                    spectateButton.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
                end)
                
                spectateButton.MouseLeave:Connect(function()
                    spectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
                end)
                
                teleportButton.MouseEnter:Connect(function()
                    teleportButton.BackgroundColor3 = Color3.fromRGB(50, 50, 100)
                end)
                
                teleportButton.MouseLeave:Connect(function()
                    teleportButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
                end)
                
                followButton.MouseEnter:Connect(function()
                    if Player.followTarget ~= currentPlayer then
                        followButton.BackgroundColor3 = Color3.fromRGB(70, 50, 90)
                    end
                end)
                
                followButton.MouseLeave:Connect(function()
                    followButton.BackgroundColor3 = Player.followTarget == currentPlayer and Color3.fromRGB(80, 60, 40) or Color3.fromRGB(60, 40, 80)
                end)
                
                bringButton.MouseEnter:Connect(function()
                    bringButton.BackgroundColor3 = Color3.fromRGB(50, 70, 90)
                end)
                
                bringButton.MouseLeave:Connect(function()
                    bringButton.BackgroundColor3 = Color3.fromRGB(40, 60, 80)
                end)
                
            end
            
            -- Call the function to create connections with the current player
            createButtonConnections(p)
        end
    end
    
    -- Restore previous selected player if they still exist
    if previousSelectedPlayer and previousSelectedPlayer.Parent == Players then
        local stillExists = table.find(Player.spectatePlayerList, previousSelectedPlayer)
        if stillExists then
            Player.selectedPlayer = previousSelectedPlayer
            Player.currentSpectateIndex = stillExists
            if SelectedPlayerLabel then
                SelectedPlayerLabel.Text = "SELECTED: " .. previousSelectedPlayer.Name:upper()
            end
        else
            Player.selectedPlayer = nil
            Player.currentSpectateIndex = 0
            if SelectedPlayerLabel then
                SelectedPlayerLabel.Text = "SELECTED: NONE"
            end
            stopSpectating()
        end
    end
    
    task.spawn(function()
        task.wait(0.1)
        if PlayerListLayout then
            local contentSize = PlayerListLayout.AbsoluteContentSize
            PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(contentSize.Y + 10, 30))
        end
    end)
    updateSpectateButtons()
end

-- Get Selected Player
function Player.getSelectedPlayer()
    return Player.selectedPlayer
end

-- Load Player Buttons
function Player.loadPlayerButtons(createButton, createToggleButton, selectedPlayer)
    print("Loading Player buttons...")
    createButton("Select Player", showPlayerSelection, "Player")
    createButton("Emote Menu", showEmoteGui, "Player")
    createToggleButton("Force Field", toggleForceField, "Player")
    createToggleButton("Anti AFK", toggleAntiAFK, "Player")
    createToggleButton("Freeze Players", toggleFreezePlayers, "Player")
    createToggleButton("Fast Respawn", toggleFastRespawn, "Player")
    createToggleButton("No Death Animation", toggleNoDeathAnimation, "Player")
    createToggleButton("Physics Control", togglePhysicsControl, "Player")
    createToggleButton("Magnet Players", toggleMagnetPlayers, "Player")
    createToggleButton("Fling Mode", toggleFling, "Player")
    createButton("Increase Size", increaseScale, "Player")
    createButton("Decrease Size", decreaseScale, "Player")
    createButton("Reset Size", resetScale, "Player")
    print("Player buttons loaded successfully")
end

-- Reset Player States
function Player.resetStates()
    print("Resetting Player states...")
    Player.forceFieldEnabled = false
    Player.antiAFKEnabled = false
    Player.freezeEnabled = false
    Player.followEnabled = false
    Player.fastRespawnEnabled = false
    Player.noDeathAnimationEnabled = false
    Player.magnetEnabled = false
    Player.flingEnabled = false
    Player.physicsEnabled = false
    Player.teleportHistory = {}
    Player.teleportFuture = {}
    
    toggleForceField(false)
    toggleAntiAFK(false)
    toggleFreezePlayers(false)
    toggleFastRespawn(false)
    toggleNoDeathAnimation(false)
    toggleMagnetPlayers(false)
    toggleFling(false)
    togglePhysicsControl(false)
    stopFollowing()
    stopSpectating()
    print("Player states reset successfully")
end

-- Initialize UI Elements
local function initUI()
    if not ScreenGui then
        warn("ScreenGui not available for Player UI initialization")
        return
    end
    
    print("Initializing Player UI...")
    
    PlayerListFrame = Instance.new("Frame")
    PlayerListFrame.Name = "PlayerListFrame"
    PlayerListFrame.Parent = ScreenGui
    PlayerListFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    PlayerListFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    PlayerListFrame.BorderSizePixel = 1
    PlayerListFrame.Position = UDim2.new(0.5, -150, 0.2, 0)
    PlayerListFrame.Size = UDim2.new(0, 300, 0, 430) -- Increased height for search box
    PlayerListFrame.Visible = false
    PlayerListFrame.Active = true
    PlayerListFrame.Draggable = true

    local PlayerListTitle = Instance.new("TextLabel")
    PlayerListTitle.Name = "Title"
    PlayerListTitle.Parent = PlayerListFrame
    PlayerListTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    PlayerListTitle.BorderSizePixel = 0
    PlayerListTitle.Position = UDim2.new(0, 0, 0, 0)
    PlayerListTitle.Size = UDim2.new(1, 0, 0, 35)
    PlayerListTitle.Font = Enum.Font.Gotham
    PlayerListTitle.Text = "SELECT PLAYER"
    PlayerListTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    PlayerListTitle.TextSize = 12

    ClosePlayerListButton = Instance.new("TextButton")
    ClosePlayerListButton.Name = "CloseButton"
    ClosePlayerListButton.Parent = PlayerListFrame
    ClosePlayerListButton.BackgroundTransparency = 1
    ClosePlayerListButton.Position = UDim2.new(1, -30, 0, 5)
    ClosePlayerListButton.Size = UDim2.new(0, 25, 0, 25)
    ClosePlayerListButton.Font = Enum.Font.GothamBold
    ClosePlayerListButton.Text = "X"
    ClosePlayerListButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClosePlayerListButton.TextSize = 12

    SearchBox = Instance.new("TextBox")
    SearchBox.Name = "SearchBox"
    SearchBox.Parent = PlayerListFrame
    SearchBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    SearchBox.BorderSizePixel = 0
    SearchBox.Position = UDim2.new(0, 10, 0, 40)
    SearchBox.Size = UDim2.new(1, -20, 0, 25)
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.PlaceholderText = "Search by username or display name..."
    SearchBox.Text = ""
    SearchBox.TextColor3 = Color3.fromRGB(200, 200, 200)
    SearchBox.TextSize = 12
    SearchBox.ClearTextOnFocus = false

    SelectedPlayerLabel = Instance.new("TextLabel")
    SelectedPlayerLabel.Name = "SelectedPlayerLabel"
    SelectedPlayerLabel.Parent = PlayerListFrame
    SelectedPlayerLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    SelectedPlayerLabel.BorderSizePixel = 0
    SelectedPlayerLabel.Position = UDim2.new(0, 10, 0, 70)
    SelectedPlayerLabel.Size = UDim2.new(1, -20, 0, 25)
    SelectedPlayerLabel.Font = Enum.Font.Gotham
    SelectedPlayerLabel.Text = "SELECTED: NONE"
    SelectedPlayerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    SelectedPlayerLabel.TextSize = 10

    PlayerListScrollFrame = Instance.new("ScrollingFrame")
    PlayerListScrollFrame.Name = "PlayerListScrollFrame"
    PlayerListScrollFrame.Parent = PlayerListFrame
    PlayerListScrollFrame.BackgroundTransparency = 1
    PlayerListScrollFrame.Position = UDim2.new(0, 10, 0, 100)
    PlayerListScrollFrame.Size = UDim2.new(1, -20, 1, -110)
    PlayerListScrollFrame.ScrollBarThickness = 8
    PlayerListScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    PlayerListScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    PlayerListScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    PlayerListScrollFrame.BorderSizePixel = 0
    PlayerListScrollFrame.ScrollingEnabled = true
    PlayerListScrollFrame.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
    PlayerListScrollFrame.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
    PlayerListScrollFrame.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"

    PlayerListLayout = Instance.new("UIListLayout")
    PlayerListLayout.Parent = PlayerListScrollFrame
    PlayerListLayout.Padding = UDim.new(0, 5)
    PlayerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PlayerListLayout.FillDirection = Enum.FillDirection.Vertical

    NextSpectateButton = Instance.new("TextButton")
    NextSpectateButton.Name = "NextSpectateButton"
    NextSpectateButton.Parent = ScreenGui
    NextSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
    NextSpectateButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
    NextSpectateButton.BorderSizePixel = 1
    NextSpectateButton.Position = UDim2.new(0.5, 20, 0.5, 0)
    NextSpectateButton.Size = UDim2.new(0, 60, 0, 30)
    NextSpectateButton.Font = Enum.Font.Gotham
    NextSpectateButton.Text = "NEXT >"
    NextSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    NextSpectateButton.TextSize = 10
    NextSpectateButton.Visible = false
    NextSpectateButton.Active = true

    PrevSpectateButton = Instance.new("TextButton")
    PrevSpectateButton.Name = "PrevSpectateButton"
    PrevSpectateButton.Parent = ScreenGui
    PrevSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
    PrevSpectateButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
    PrevSpectateButton.BorderSizePixel = 1
    PrevSpectateButton.Position = UDim2.new(0.5, -80, 0.5, 0)
    PrevSpectateButton.Size = UDim2.new(0, 60, 0, 30)
    PrevSpectateButton.Font = Enum.Font.Gotham
    PrevSpectateButton.Text = "< PREV"
    PrevSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    PrevSpectateButton.TextSize = 10
    PrevSpectateButton.Visible = false
    PrevSpectateButton.Active = true

    StopSpectateButton = Instance.new("TextButton")
    StopSpectateButton.Name = "StopSpectateButton"
    StopSpectateButton.Parent = ScreenGui
    StopSpectateButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
    StopSpectateButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
    StopSpectateButton.BorderSizePixel = 1
    StopSpectateButton.Position = UDim2.new(0.5, -10, 0.5, 40)
    StopSpectateButton.Size = UDim2.new(0, 60, 0, 30)
    StopSpectateButton.Font = Enum.Font.Gotham
    StopSpectateButton.Text = "STOP"
    StopSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    StopSpectateButton.TextSize = 10
    StopSpectateButton.Visible = false
    StopSpectateButton.Active = true

    TeleportSpectateButton = Instance.new("TextButton")
    TeleportSpectateButton.Name = "TeleportSpectateButton"
    TeleportSpectateButton.Parent = ScreenGui
    TeleportSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
    TeleportSpectateButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
    TeleportSpectateButton.BorderSizePixel = 1
    TeleportSpectateButton.Position = UDim2.new(0.5, 60, 0.5, 40)
    TeleportSpectateButton.Size = UDim2.new(0, 60, 0, 30)
    TeleportSpectateButton.Font = Enum.Font.Gotham
    TeleportSpectateButton.Text = "TP"
    TeleportSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    TeleportSpectateButton.TextSize = 10
    TeleportSpectateButton.Visible = false
    TeleportSpectateButton.Active = true

    EmoteGuiFrame = Instance.new("Frame")
    EmoteGuiFrame.Name = "EmoteGuiFrame"
    EmoteGuiFrame.Parent = ScreenGui
    EmoteGuiFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    EmoteGuiFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    EmoteGuiFrame.BorderSizePixel = 1
    EmoteGuiFrame.Position = UDim2.new(0.5, -100, 0.3, 0)
    EmoteGuiFrame.Size = UDim2.new(0, 200, 0, 250)
    EmoteGuiFrame.Visible = false
    EmoteGuiFrame.Active = true
    EmoteGuiFrame.Draggable = true

    local EmoteTitle = Instance.new("TextLabel")
    EmoteTitle.Name = "Title"
    EmoteTitle.Parent = EmoteGuiFrame
    EmoteTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    EmoteTitle.BorderSizePixel = 0
    EmoteTitle.Position = UDim2.new(0, 0, 0, 0)
    EmoteTitle.Size = UDim2.new(1, 0, 0, 35)
    EmoteTitle.Font = Enum.Font.Gotham
    EmoteTitle.Text = "EMOTE MENU"
    EmoteTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    EmoteTitle.TextSize = 12

    local CloseEmoteButton = Instance.new("TextButton")
    CloseEmoteButton.Name = "CloseButton"
    CloseEmoteButton.Parent = EmoteGuiFrame
    CloseEmoteButton.BackgroundTransparency = 1
    CloseEmoteButton.Position = UDim2.new(1, -30, 0, 5)
    CloseEmoteButton.Size = UDim2.new(0, 25, 0, 25)
    CloseEmoteButton.Font = Enum.Font.GothamBold
    CloseEmoteButton.Text = "X"
    CloseEmoteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseEmoteButton.TextSize = 12

    local EmoteScrollFrame = Instance.new("ScrollingFrame")
    EmoteScrollFrame.Name = "EmoteScrollFrame"
    EmoteScrollFrame.Parent = EmoteGuiFrame
    EmoteScrollFrame.BackgroundTransparency = 1
    EmoteScrollFrame.Position = UDim2.new(0, 10, 0, 45)
    EmoteScrollFrame.Size = UDim2.new(1, -20, 1, -55)
    EmoteScrollFrame.ScrollBarThickness = 8
    EmoteScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    EmoteScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    EmoteScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    EmoteScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    EmoteScrollFrame.BorderSizePixel = 0
    EmoteScrollFrame.ScrollingEnabled = true
    EmoteScrollFrame.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
    EmoteScrollFrame.MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
    EmoteScrollFrame.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"

    local EmoteListLayout = Instance.new("UIListLayout")
    EmoteListLayout.Parent = EmoteScrollFrame
    EmoteListLayout.Padding = UDim.new(0, 5)
    EmoteListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    EmoteListLayout.FillDirection = Enum.FillDirection.Vertical

    -- Button Connections
    ClosePlayerListButton.MouseButton1Click:Connect(function()
        PlayerListFrame.Visible = false
        Player.playerListVisible = false
        print("Player list closed")
    end)

    CloseEmoteButton.MouseButton1Click:Connect(function()
        EmoteGuiFrame.Visible = false
        print("Emote menu closed")
    end)

    NextSpectateButton.MouseButton1Click:Connect(function()
        spectateNextPlayer()
    end)

    PrevSpectateButton.MouseButton1Click:Connect(function()
        spectatePrevPlayer()
    end)

    StopSpectateButton.MouseButton1Click:Connect(function()
        stopSpectating()
    end)

    TeleportSpectateButton.MouseButton1Click:Connect(function()
        teleportToSpectatedPlayer()
    end)

    if SearchBox then
        SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
            Player.updatePlayerList()
        end)
    end

    -- Initialize Player List
    Player.updatePlayerList()

    -- Populate Emote Menu
    local function updateEmoteMenu()
        for _, child in pairs(EmoteScrollFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        local emotes = {"wave", "point", "dance", "dance2", "dance3", "laugh", "cheer"}
        for i, emote in ipairs(emotes) do
            local emoteButton = Instance.new("TextButton")
            emoteButton.Name = emote .. "Button"
            emoteButton.Parent = EmoteScrollFrame
            emoteButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            emoteButton.BorderSizePixel = 0
            emoteButton.Size = UDim2.new(1, -10, 0, 30)
            emoteButton.Font = Enum.Font.Gotham
            emoteButton.Text = emote:upper()
            emoteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            emoteButton.TextSize = 10
            emoteButton.LayoutOrder = i
            
            emoteButton.MouseButton1Click:Connect(function()
                if player.Character and player.Character:FindFirstChild("Humanoid") then
                    local humanoid = player.Character.Humanoid
                    local success, result = pcall(function()
                        humanoid:PlayEmote(emote)
                        print("Played emote: " .. emote)
                    end)
                    if not success then
                        warn("Failed to play emote: " .. tostring(result))
                    end
                end
            end)
            
            emoteButton.MouseEnter:Connect(function()
                emoteButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            end)
            
            emoteButton.MouseLeave:Connect(function()
                emoteButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            end)
        end
        
        task.spawn(function()
            task.wait(0.1)
            local contentSize = EmoteListLayout.AbsoluteContentSize
            EmoteScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(contentSize.Y + 10, 30))
        end)
    end

    updateEmoteMenu()
    
    print("Player UI initialized successfully")
end

-- Initialize Connections
local function initConnections()
    connections.playerAdded = Players.PlayerAdded:Connect(function(newPlayer)
        print("Player added: " .. newPlayer.Name)
        task.wait(1) -- Wait for character to load
        Player.updatePlayerList()
        setupPlayerMonitoring(newPlayer)
    end)
    
    connections.playerRemoving = Players.PlayerRemoving:Connect(function(leavingPlayer)
        print("Player removing: " .. leavingPlayer.Name)
        cleanupPlayerMonitoring(leavingPlayer)
        if Player.selectedPlayer == leavingPlayer then
            stopSpectating()
        end
        if Player.followTarget == leavingPlayer then
            stopFollowing()
        end
        task.wait(0.5)
        Player.updatePlayerList()
    end)
    
    connections.characterAdded = player.CharacterAdded:Connect(function(character)
        print("Local player character added")
        Player.rootPart = character:WaitForChild("HumanoidRootPart", 5)
        humanoid = character:WaitForChild("Humanoid", 5)
        if not Player.rootPart or not humanoid then
            warn("Failed to initialize local player character parts")
        end
        if Player.forceFieldEnabled then
            task.wait(0.1)
            toggleForceField(true)
        end
        if Player.fastRespawnEnabled then
            toggleFastRespawn(true)
        end
        setBodyScale(Player.bodyScale)
        task.wait(1)
        Player.updatePlayerList()
    end)
    
    -- Remove the continuous heartbeat update as it causes performance issues
    -- Only update when player list is visible
    connections.updatePlayerListPeriodic = task.spawn(function()
        while true do
            if Player.playerListVisible and PlayerListFrame and PlayerListFrame.Visible then
                Player.updatePlayerList()
            end
            task.wait(2) -- Update every 2 seconds when visible
        end
    end)
    
    -- Add chat commands
    connections.chatted = player.Chatted:Connect(function(message)
        if message:sub(1,1) ~= "/" then return end
        
        local args = split(message:sub(2), " ")
        local cmd = args[1]:lower()
        
        if cmd == "tp" then
            local targetName = args[2]
            local direction = args[3]
            local target = findPlayer(targetName)
            if target then
                teleportToPlayer(target, direction)
                local dirText = direction and " " .. direction or ""
                StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] success tp to " .. target.Name .. dirText})
            else
                StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] failed tp: player not found"})
            end
        elseif cmd == "bring" then
            local target = findPlayer(args[2])
            if target then
                bringPlayer(target)
                StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] success bring " .. target.Name})
            else
                StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] failed bring: player not found"})
            end
        elseif cmd == "follow" then
            local target = findPlayer(args[2])
            if target then
                toggleFollowPlayer(target)
                StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] success follow " .. target.Name})
            else
                StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] failed follow: player not found"})
            end
        elseif cmd == "stopfollow" then
            stopFollowing()
            StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] success stop follow"})
        elseif cmd == "fling" then
            local target = findPlayer(args[2])
            if target then
                flingPlayer(target)
                StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] success fling " .. target.Name})
            else
                StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] failed fling: player not found"})
            end
        elseif cmd == "freeze" then
            local target = findPlayer(args[2])
            if target then
                freezePlayer(target)
                StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] success freeze " .. target.Name})
            else
                StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] failed freeze: player not found"})
            end
        elseif cmd == "unfreeze" then
            local target = findPlayer(args[2])
            if target then
                unfreezePlayer(target)
                StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] success unfreeze " .. target.Name})
            else
                StarterGui:SetCore("ChatMakeSystemMessage", {Text = "[SERVER] failed unfreeze: player not found"})
            end
        elseif cmd == "back" then
            backTeleport()
        elseif cmd == "next" then
            nextTeleport()
        end
    end)
end

-- Initialize the Player module
function Player.init(deps)
    print("Initializing Player module...")
    Players = deps.Players or game:GetService("Players")
    RunService = deps.RunService or game:GetService("RunService")
    Workspace = deps.Workspace or game:GetService("Workspace")
    player = deps.player or Players.LocalPlayer
    humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
    Player.rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    connections = deps.connections or {}
    buttonStates = deps.buttonStates or {}
    ScrollFrame = deps.ScrollFrame
    ScreenGui = deps.ScreenGui
    
    if not Players or not RunService or not Workspace or not player then
        warn("Missing critical dependencies for Player module")
        return
    end
    
    initUI()
    initConnections()
    
    -- Ensure initial state
    Player.resetStates()
    
    print("Player module initialized successfully")
end

-- Cleanup
function Player.cleanup()
    print("Cleaning up Player module...")
    Player.resetStates()
    
    for _, connection in pairs(connections) do
        if connection then
            if typeof(connection) == "RBXScriptConnection" then
                connection:Disconnect()
            elseif typeof(connection) == "thread" then
                task.cancel(connection)
            end
        end
    end
    connections = {}
    
    for _, connection in pairs(Player.spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    Player.spectateConnections = {}
    
    for _, connection in pairs(Player.followConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    Player.followConnections = {}
    
    for targetPlayer, playerConnections in pairs(Player.playerConnections) do
        for _, connection in pairs(playerConnections) do
            if connection then
                connection:Disconnect()
            end
        end
    end
    Player.playerConnections = {}
    
    for targetPlayer, playerConnections in pairs(Player.deathAnimationConnections) do
        for _, connection in pairs(playerConnections) do
            if connection then
                connection:Disconnect()
            end
        end
    end
    Player.deathAnimationConnections = {}
    
    for targetPlayer, _ in pairs(Player.physicsPlayers) do
        disablePhysicsForPlayer(targetPlayer)
    end
    Player.physicsPlayers = {}
    
    if PlayerListFrame then
        PlayerListFrame:Destroy()
    end
    if EmoteGuiFrame then
        EmoteGuiFrame:Destroy()
    end
    if NextSpectateButton then
        NextSpectateButton:Destroy()
    end
    if PrevSpectateButton then
        PrevSpectateButton:Destroy()
    end
    if StopSpectateButton then
        StopSpectateButton:Destroy()
    end
    if TeleportSpectateButton then
        TeleportSpectateButton:Destroy()
    end
    
    Player.selectedPlayer = nil
    Player.spectatePlayerList = {}
    Player.currentSpectateIndex = 0
    Player.playerListVisible = false
    Player.frozenPlayerPositions = {}
    Player.magnetPlayerPositions = {}
    
    print("Player module cleaned up successfully")
end

return Player