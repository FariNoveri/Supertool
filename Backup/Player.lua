-- Player-related features for MinimalHackGUI by Fari Noveri, including spectate, player list, freeze players, bring player, and magnet player

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
Player.magnetOffset = Vector3.new(2, 0, -5) -- Adjusted: 5 studs in front, 2 studs left
Player.magnetPlayerPositions = {}

-- Variables for hide features
Player.hideCharacterEnabled = false
Player.hideMyCharacterEnabled = false
Player.hiddenPlayers = {}
Player.originalMyCharacterTransparency = {}

-- Variables for spectate UI control
Player.spectateUIVisible = true
Player.spectateUIHidden = false

-- UI Elements
local PlayerListFrame, PlayerListScrollFrame, PlayerListLayout, PlayerSearchBox
local ClosePlayerListButton, NextSpectateButton, PrevSpectateButton, StopSpectateButton, TeleportSpectateButton
local FollowSpectateButton, HideSpectateUIButton, HidePlayerButton
local SpectateUIFrame
local EmoteGuiFrame

-- Hide Character (all players except me)
local function hidePlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player or not targetPlayer.Character then return end
    
    if not Player.hiddenPlayers[targetPlayer] then
        Player.hiddenPlayers[targetPlayer] = {}
    end
    
    for _, part in pairs(targetPlayer.Character:GetDescendants()) do
        if part:IsA("BasePart") then
            if not Player.hiddenPlayers[targetPlayer][part] then
                Player.hiddenPlayers[targetPlayer][part] = part.Transparency
            end
            part.Transparency = 1
        elseif part:IsA("Decal") or part:IsA("Texture") then
            if not Player.hiddenPlayers[targetPlayer][part] then
                Player.hiddenPlayers[targetPlayer][part] = part.Transparency
            end
            part.Transparency = 1
        elseif part:IsA("Accessory") then
            local handle = part:FindFirstChild("Handle")
            if handle then
                if not Player.hiddenPlayers[targetPlayer][handle] then
                    Player.hiddenPlayers[targetPlayer][handle] = handle.Transparency
                end
                handle.Transparency = 1
                for _, mesh in pairs(handle:GetDescendants()) do
                    if mesh:IsA("SpecialMesh") or mesh:IsA("MeshPart") then
                        if not Player.hiddenPlayers[targetPlayer][mesh] then
                            Player.hiddenPlayers[targetPlayer][mesh] = mesh.Transparency or 0
                        end
                        if mesh:IsA("MeshPart") then
                            mesh.Transparency = 1
                        end
                    end
                end
            end
        end
    end
    print("Hidden player: " .. targetPlayer.Name)
end

local function showPlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player or not targetPlayer.Character then return end
    
    if Player.hiddenPlayers[targetPlayer] then
        for part, originalTransparency in pairs(Player.hiddenPlayers[targetPlayer]) do
            if part and part.Parent then
                part.Transparency = originalTransparency
            end
        end
        Player.hiddenPlayers[targetPlayer] = nil
    end
    print("Shown player: " .. targetPlayer.Name)
end

local function toggleHideCharacter(enabled)
    Player.hideCharacterEnabled = enabled
    
    if enabled then
        print("Hiding all other players...")
        Player.hiddenPlayers = {}
        
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player then
                hidePlayer(p)
            end
        end
        
        connections.hidecharacter = Players.PlayerAdded:Connect(function(newPlayer)
            if Player.hideCharacterEnabled and newPlayer ~= player then
                newPlayer.CharacterAdded:Connect(function(character)
                    if Player.hideCharacterEnabled then
                        task.wait(0.5)
                        hidePlayer(newPlayer)
                    end
                end)
                if newPlayer.Character then
                    task.wait(0.5)
                    hidePlayer(newPlayer)
                end
            end
        end)
        
        connections.hidecharacterrespawn = RunService.Heartbeat:Connect(function()
            if Player.hideCharacterEnabled then
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= player and p.Character and not Player.hiddenPlayers[p] then
                        hidePlayer(p)
                    end
                end
            end
        end)
        
        print("All other players hidden successfully")
    else
        print("Showing all other players...")
        
        if connections.hidecharacter then
            connections.hidecharacter:Disconnect()
            connections.hidecharacter = nil
        end
        
        if connections.hidecharacterrespawn then
            connections.hidecharacterrespawn:Disconnect()
            connections.hidecharacterrespawn = nil
        end
        
        for targetPlayer, _ in pairs(Player.hiddenPlayers) do
            showPlayer(targetPlayer)
        end
        
        Player.hiddenPlayers = {}
        print("All other players shown successfully")
    end
end

-- Hide My Character (only local player)
local function hideMyCharacter()
    if not player.Character then return end
    
    Player.originalMyCharacterTransparency = {}
    
    for _, part in pairs(player.Character:GetDescendants()) do
        if part:IsA("BasePart") then
            Player.originalMyCharacterTransparency[part] = part.Transparency
            part.Transparency = 1
        elseif part:IsA("Decal") or part:IsA("Texture") then
            Player.originalMyCharacterTransparency[part] = part.Transparency
            part.Transparency = 1
        elseif part:IsA("Accessory") then
            local handle = part:FindFirstChild("Handle")
            if handle then
                Player.originalMyCharacterTransparency[handle] = handle.Transparency
                handle.Transparency = 1
                for _, mesh in pairs(handle:GetDescendants()) do
                    if mesh:IsA("SpecialMesh") or mesh:IsA("MeshPart") then
                        Player.originalMyCharacterTransparency[mesh] = mesh.Transparency or 0
                        if mesh:IsA("MeshPart") then
                            mesh.Transparency = 1
                        end
                    end
                end
            end
        end
    end
    print("Hidden my character")
end

local function showMyCharacter()
    if not player.Character then return end
    
    for part, originalTransparency in pairs(Player.originalMyCharacterTransparency) do
        if part and part.Parent then
            part.Transparency = originalTransparency
        end
    end
    Player.originalMyCharacterTransparency = {}
    print("Shown my character")
end

local function toggleHideMyCharacter(enabled)
    Player.hideMyCharacterEnabled = enabled
    
    if enabled then
        print("Hiding my character...")
        hideMyCharacter()
        
        connections.hidemycharacter = player.CharacterAdded:Connect(function(character)
            if Player.hideMyCharacterEnabled then
                task.wait(0.5)
                hideMyCharacter()
            end
        end)
        
        print("My character hidden successfully")
    else
        print("Showing my character...")
        
        if connections.hidemycharacter then
            connections.hidemycharacter:Disconnect()
            connections.hidemycharacter = nil
        end
        
        showMyCharacter()
        print("My character shown successfully")
    end
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

-- Fixed Bring Player function
local function bringPlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then
        print("Cannot bring: Invalid target player")
        return
    end
    
    if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        print("Cannot bring: Target player has no character or HumanoidRootPart")
        return
    end
    
    if not Player.rootPart then
        print("Cannot bring: Missing rootPart")
        return
    end
    
    local targetRootPart = targetPlayer.Character.HumanoidRootPart
    local ourPosition = Player.rootPart.CFrame
    
    -- Fixed bring player positioning
    local bringPosition = ourPosition * CFrame.new(0, 0, -5) -- 5 studs behind us
    targetRootPart.CFrame = bringPosition
    
    -- Force the position to stick
    if targetRootPart then
        targetRootPart.Anchored = true
        task.wait(0.1)
        targetRootPart.Anchored = false
    end
    
    print("Brought player: " .. targetPlayer.Name)
end

-- Magnet Players
local function toggleMagnetPlayers(enabled)
    Player.magnetEnabled = enabled
    
    if enabled then
        print("Activating magnet players...")
        Player.magnetPlayerPositions = {}
        
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                Player.magnetPlayerPositions[p] = p.Character.HumanoidRootPart
            end
        end
        
        connections.magnet = RunService.Heartbeat:Connect(function()
            if not Player.magnetEnabled or not Player.rootPart then return end
            
            local ourCFrame = Player.rootPart.CFrame
            for targetPlayer, _ in pairs(Player.magnetPlayerPositions) do
                if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = targetPlayer.Character.HumanoidRootPart
                    local targetCFrame = ourCFrame * CFrame.new(Player.magnetOffset)
                    hrp.CFrame = CFrame.new(targetCFrame.Position, ourCFrame.Position)
                    hrp.Anchored = true
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    
                    if targetPlayer.Character:FindFirstChild("Humanoid") then
                        local hum = targetPlayer.Character.Humanoid
                        hum.PlatformStand = true
                        hum.WalkSpeed = 0
                        hum.JumpPower = 0
                    end
                else
                    Player.magnetPlayerPositions[targetPlayer] = nil -- Remove invalid players
                end
            end
        end)
        
        connections.magnetNewPlayers = Players.PlayerAdded:Connect(function(newPlayer)
            if Player.magnetEnabled and newPlayer ~= player then
                newPlayer.CharacterAdded:Connect(function(character)
                    task.wait(0.5)
                    if character:FindFirstChild("HumanoidRootPart") then
                        Player.magnetPlayerPositions[newPlayer] = character.HumanoidRootPart
                        print("Magnet applied to new player: " .. newPlayer.Name)
                    end
                end)
                if newPlayer.Character and newPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    task.wait(0.5)
                    Player.magnetPlayerPositions[newPlayer] = newPlayer.Character.HumanoidRootPart
                    print("Magnet applied to existing player: " .. newPlayer.Name)
                end
            end
        end)
        
        connections.magnetRespawn = player.CharacterAdded:Connect(function(character)
            if Player.magnetEnabled then
                task.wait(0.5)
                Player.rootPart = character:FindFirstChild("HumanoidRootPart")
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        Player.magnetPlayerPositions[p] = p.Character.HumanoidRootPart
                        print("Magnet reapplied to player: " .. p.Name)
                    end
                end
            end
        end)
        
        print("Magnet players activated successfully")
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
        
        for targetPlayer, _ in pairs(Player.magnetPlayerPositions) do
            if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = targetPlayer.Character.HumanoidRootPart
                hrp.Anchored = false
                if targetPlayer.Character:FindFirstChild("Humanoid") then
                    local hum = targetPlayer.Character.Humanoid
                    hum.PlatformStand = false
                    hum.WalkSpeed = 16
                    hum.JumpPower = 50
                end
            end
        end
        
        Player.magnetPlayerPositions = {}
        print("Magnet players deactivated successfully")
    end
end

-- Helper function to freeze a single player
local function freezePlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then return end
    
    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = targetPlayer.Character.HumanoidRootPart
        
        if not Player.frozenPlayerPositions[targetPlayer] then
            Player.frozenPlayerPositions[targetPlayer] = {
                cframe = hrp.CFrame,
                anchored = hrp.Anchored,
                velocity = hrp.AssemblyLinearVelocity
            }
        end
        
        hrp.Anchored = true
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        
        if targetPlayer.Character:FindFirstChild("Humanoid") then
            local hum = targetPlayer.Character.Humanoid
            hum.PlatformStand = true
            hum.Sit = false
            hum.WalkSpeed = 0
            hum.JumpPower = 0
        end
        
        print("Froze player: " .. targetPlayer.Name)
    end
end

-- Helper function to unfreeze a single player
local function unfreezePlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then return end
    
    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = targetPlayer.Character.HumanoidRootPart
        local frozenData = Player.frozenPlayerPositions[targetPlayer]
        
        hrp.Anchored = frozenData and frozenData.anchored or false
        
        if targetPlayer.Character:FindFirstChild("Humanoid") then
            local hum = targetPlayer.Character.Humanoid
            hum.PlatformStand = false
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
        
        print("Unfroze player: " .. targetPlayer.Name)
    end
    
    Player.frozenPlayerPositions[targetPlayer] = nil
end

-- Setup monitoring for a specific player
local function setupPlayerMonitoring(targetPlayer)
    if targetPlayer == player or Player.playerConnections[targetPlayer] then return end
    
    Player.playerConnections[targetPlayer] = {}
    
    Player.playerConnections[targetPlayer].characterAdded = targetPlayer.CharacterAdded:Connect(function(character)
        task.wait(0.5)
        
        if Player.freezeEnabled then
            freezePlayer(targetPlayer)
            print("Auto-froze respawned player: " .. targetPlayer.Name)
        end
        
        if Player.magnetEnabled then
            if character:FindFirstChild("HumanoidRootPart") then
                Player.magnetPlayerPositions[targetPlayer] = character.HumanoidRootPart
                print("Magnet applied to respawned player: " .. targetPlayer.Name)
            end
        end
        
        if Player.hideCharacterEnabled then
            hidePlayer(targetPlayer)
            print("Re-hidden respawned player: " .. targetPlayer.Name)
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
    
    if Player.magnetEnabled and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        Player.magnetPlayerPositions[targetPlayer] = targetPlayer.Character.HumanoidRootPart
        print("Magnet applied to player: " .. targetPlayer.Name)
    end
    
    if Player.hideCharacterEnabled then
        hidePlayer(targetPlayer)
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
    Player.magnetPlayerPositions[targetPlayer] = nil
    Player.hiddenPlayers[targetPlayer] = nil
end

-- Freeze Players
local function toggleFreezePlayers(enabled)
    Player.freezeEnabled = enabled
    
    if enabled then
        print("Activating freeze players...")
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
        
        connections.freeze = RunService.Heartbeat:Connect(function()
            if Player.freezeEnabled then
                for targetPlayer, frozenData in pairs(Player.frozenPlayerPositions) do
                    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = targetPlayer.Character.HumanoidRootPart
                        hrp.CFrame = frozenData.cframe
                        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        hrp.Anchored = true
                        
                        if targetPlayer.Character:FindFirstChild("Humanoid") then
                            local hum = targetPlayer.Character.Humanoid
                            hum.PlatformStand = true
                            hum.WalkSpeed = 0
                            hum.JumpPower = 0
                        end
                    end
                end
            end
        end)
        print("Players frozen successfully")
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

-- Update Spectate Buttons Visibility and Position
local function updateSpectateButtons()
    local isSpectating = Player.selectedPlayer ~= nil
    
    if SpectateUIFrame then
        SpectateUIFrame.Visible = isSpectating and Player.spectateUIVisible
        
        -- Update Follow button text based on follow state
        if FollowSpectateButton and Player.selectedPlayer then
            if Player.followTarget == Player.selectedPlayer then
                FollowSpectateButton.Text = "UNFOLLOW"
                FollowSpectateButton.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
            else
                FollowSpectateButton.Text = "FOLLOW"
                FollowSpectateButton.BackgroundColor3 = Color3.fromRGB(60, 40, 80)
            end
        end
        
        -- Update Hide Player button text
        if HidePlayerButton and Player.selectedPlayer then
            if Player.hiddenPlayers[Player.selectedPlayer] then
                HidePlayerButton.Text = "SHOW " .. (Player.selectedPlayer.DisplayName or Player.selectedPlayer.Name)
                HidePlayerButton.BackgroundColor3 = Color3.fromRGB(40, 80, 60)
            else
                HidePlayerButton.Text = "HIDE " .. (Player.selectedPlayer.DisplayName or Player.selectedPlayer.Name)
                HidePlayerButton.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
            end
        end
    end
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
    
    updateSpectateButtons()
    print("Stopped spectating")
end

-- Spectate Player
local function spectatePlayer(targetPlayer)
    for _, connection in pairs(Player.spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    Player.spectateConnections = {}
    
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
        Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        
        Player.selectedPlayer = targetPlayer
        Player.currentSpectateIndex = table.find(Player.spectatePlayerList, targetPlayer) or 0
        print("Spectating: " .. targetPlayer.Name)
        
        Player.spectateConnections.characterAdded = targetPlayer.CharacterAdded:Connect(function(newCharacter)
            if Player.selectedPlayer == targetPlayer then
                local newHumanoid = newCharacter:WaitForChild("Humanoid", 10)
                if newHumanoid then
                    task.wait(0.5)
                    Workspace.CurrentCamera.CameraSubject = newHumanoid
                    Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                    print("Spectated player respawned, continuing spectate: " .. targetPlayer.Name)
                end
            end
        end)
        
        local targetHumanoid = targetPlayer.Character.Humanoid
        Player.spectateConnections.died = targetHumanoid.Died:Connect(function()
            if Player.selectedPlayer == targetPlayer then
                print("Spectated player died, waiting for respawn: " .. targetPlayer.Name)
            end
        end)
    else
        stopSpectating()
    end
    updateSpectateButtons()
end

-- Spectate Next Player
local function spectateNextPlayer()
    if #Player.spectatePlayerList == 0 then
        print("No players to spectate")
        stopSpectating()
        return
    end
    
    Player.currentSpectateIndex = Player.currentSpectateIndex + 1
    if Player.currentSpectateIndex > #Player.spectatePlayerList then
        Player.currentSpectateIndex = 1
    end
    
    local targetPlayer = Player.spectatePlayerList[Player.currentSpectateIndex]
    if targetPlayer then
        spectatePlayer(targetPlayer)
    else
        stopSpectating()
    end
end

-- Spectate Previous Player
local function spectatePrevPlayer()
    if #Player.spectatePlayerList == 0 then
        print("No players to spectate")
        stopSpectating()
        return
    end
    
    Player.currentSpectateIndex = Player.currentSpectateIndex - 1
    if Player.currentSpectateIndex < 1 then
        Player.currentSpectateIndex = #Player.spectatePlayerList
    end
    
    local targetPlayer = Player.spectatePlayerList[Player.currentSpectateIndex]
    if targetPlayer then
        spectatePlayer(targetPlayer)
    else
        stopSpectating()
    end
end

-- Search filter function
local function matchesSearch(targetPlayer, searchText)
    if not searchText or searchText == "" then
        return true
    end
    
    searchText = searchText:lower()
    local username = targetPlayer.Name:lower()
    local displayName = (targetPlayer.DisplayName or ""):lower()
    
    return username:find(searchText) or displayName:find(searchText)
end

-- Update Player List with search functionality
function Player.updatePlayerList()
    if not PlayerListScrollFrame then
        warn("PlayerListScrollFrame not initialized")
        return
    end
    
    for _, child in pairs(PlayerListScrollFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    local searchText = PlayerSearchBox and PlayerSearchBox.Text or ""
    Player.spectatePlayerList = {}
    local playerCount = 0
    local players = Players:GetPlayers()
    local validPlayers = {}
    
    -- Filter players based on search and validity
    for _, p in pairs(players) do
        if p ~= player and p.Character and p.Character:FindFirstChild("Humanoid") then
            if matchesSearch(p, searchText) then
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
        noPlayersLabel.Text = searchText ~= "" and "No players match search" or "No other players found"
        noPlayersLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        noPlayersLabel.TextSize = 11
        noPlayersLabel.TextXAlignment = Enum.TextXAlignment.Center
    else
        for _, p in pairs(validPlayers) do
            playerCount = playerCount + 1
            
            local playerItem = Instance.new("Frame")
            playerItem.Name = p.Name .. "Item"
            playerItem.Parent = PlayerListScrollFrame
            playerItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            playerItem.BorderSizePixel = 0
            playerItem.Size = UDim2.new(1, -5, 0, 180) -- Adjusted height
            playerItem.LayoutOrder = playerCount
            
            -- Display name with username and display name format
            local displayText = p.Name
            if p.DisplayName and p.DisplayName ~= p.Name then
                displayText = p.Name .. " (" .. p.DisplayName .. ")"
            end
            
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Name = "NameLabel"
            nameLabel.Parent = playerItem
            nameLabel.BackgroundTransparency = 1
            nameLabel.Position = UDim2.new(0, 5, 0, 5)
            nameLabel.Size = UDim2.new(1, -10, 0, 20)
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.Text = displayText
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.TextSize = 12
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.TextScaled = true
            
            -- Row 1: Spectate, Stop, Teleport
            local spectateButton = Instance.new("TextButton")
            spectateButton.Name = "SpectateButton"
            spectateButton.Parent = playerItem
            spectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
            spectateButton.BorderSizePixel = 0
            spectateButton.Position = UDim2.new(0, 5, 0, 30)
            spectateButton.Size = UDim2.new(0, 60, 0, 25)
            spectateButton.Font = Enum.Font.Gotham
            spectateButton.Text = "SPECTATE"
            spectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            spectateButton.TextSize = 8
            
            local stopSpectateButton = Instance.new("TextButton")
            stopSpectateButton.Name = "StopSpectateButton"
            stopSpectateButton.Parent = playerItem
            stopSpectateButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
            stopSpectateButton.BorderSizePixel = 0
            stopSpectateButton.Position = UDim2.new(0, 70, 0, 30)
            stopSpectateButton.Size = UDim2.new(0, 60, 0, 25)
            stopSpectateButton.Font = Enum.Font.Gotham
            stopSpectateButton.Text = "STOP"
            stopSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            stopSpectateButton.TextSize = 8
            
            local teleportButton = Instance.new("TextButton")
            teleportButton.Name = "TeleportButton"
            teleportButton.Parent = playerItem
            teleportButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
            teleportButton.BorderSizePixel = 0
            teleportButton.Position = UDim2.new(0, 135, 0, 30)
            teleportButton.Size = UDim2.new(1, -140, 0, 25)
            teleportButton.Font = Enum.Font.Gotham
            teleportButton.Text = "TELEPORT"
            teleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            teleportButton.TextSize = 8
            
            -- Row 2: Follow, Stop Follow, Bring
            local followButton = Instance.new("TextButton")
            followButton.Name = "FollowButton"
            followButton.Parent = playerItem
            followButton.BackgroundColor3 = Player.followTarget == p and Color3.fromRGB(80, 60, 40) or Color3.fromRGB(60, 40, 80)
            followButton.BorderSizePixel = 0
            followButton.Position = UDim2.new(0, 5, 0, 60)
            followButton.Size = UDim2.new(0, 60, 0, 25)
            followButton.Font = Enum.Font.Gotham
            followButton.Text = Player.followTarget == p and "FOLLOWING" or "FOLLOW"
            followButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            followButton.TextSize = 8
            
            local stopFollowButton = Instance.new("TextButton")
            stopFollowButton.Name = "StopFollowButton"
            stopFollowButton.Parent = playerItem
            stopFollowButton.BackgroundColor3 = Color3.fromRGB(80, 40, 60)
            stopFollowButton.BorderSizePixel = 0
            stopFollowButton.Position = UDim2.new(0, 70, 0, 60)
            stopFollowButton.Size = UDim2.new(0, 60, 0, 25)
            stopFollowButton.Font = Enum.Font.Gotham
            stopFollowButton.Text = "STOP FOLLOW"
            stopFollowButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            stopFollowButton.TextSize = 7
            
            local bringButton = Instance.new("TextButton")
            bringButton.Name = "BringButton"
            bringButton.Parent = playerItem
            bringButton.BackgroundColor3 = Color3.fromRGB(40, 60, 80)
            bringButton.BorderSizePixel = 0
            bringButton.Position = UDim2.new(0, 135, 0, 60)
            bringButton.Size = UDim2.new(1, -140, 0, 25)
            bringButton.Font = Enum.Font.Gotham
            bringButton.Text = "BRING"
            bringButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            bringButton.TextSize = 8
            
            -- Row 3: Magnet, Hide/Show
            local magnetButton = Instance.new("TextButton")
            magnetButton.Name = "MagnetButton"
            magnetButton.Parent = playerItem
            magnetButton.BackgroundColor3 = Color3.fromRGB(60, 80, 40)
            magnetButton.BorderSizePixel = 0
            magnetButton.Position = UDim2.new(0, 5, 0, 90)
            magnetButton.Size = UDim2.new(0, 60, 0, 25)
            magnetButton.Font = Enum.Font.Gotham
            magnetButton.Text = "MAGNET"
            magnetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            magnetButton.TextSize = 8
            
            local hideButton = Instance.new("TextButton")
            hideButton.Name = "HideButton"
            hideButton.Parent = playerItem
            hideButton.BackgroundColor3 = Player.hiddenPlayers[p] and Color3.fromRGB(80, 40, 80) or Color3.fromRGB(80, 60, 40)
            hideButton.BorderSizePixel = 0
            hideButton.Position = UDim2.new(0, 70, 0, 90)
            hideButton.Size = UDim2.new(0, 60, 0, 25)
            hideButton.Font = Enum.Font.Gotham
            hideButton.Text = Player.hiddenPlayers[p] and "SHOW" or "HIDE"
            hideButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            hideButton.TextSize = 8
            
            -- Row 4: Freeze Individual
            local freezeIndividualButton = Instance.new("TextButton")
            freezeIndividualButton.Name = "FreezeIndividualButton"
            freezeIndividualButton.Parent = playerItem
            freezeIndividualButton.BackgroundColor3 = Player.frozenPlayerPositions[p] and Color3.fromRGB(80, 80, 40) or Color3.fromRGB(40, 40, 100)
            freezeIndividualButton.BorderSizePixel = 0
            freezeIndividualButton.Position = UDim2.new(0, 5, 0, 120)
            freezeIndividualButton.Size = UDim2.new(1, -10, 0, 25)
            freezeIndividualButton.Font = Enum.Font.Gotham
            freezeIndividualButton.Text = Player.frozenPlayerPositions[p] and "UNFREEZE" or "FREEZE"
            freezeIndividualButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            freezeIndividualButton.TextSize = 8
            
            -- Button Events
            spectateButton.MouseButton1Click:Connect(function()
                Player.currentSpectateIndex = table.find(Player.spectatePlayerList, p) or 0
                spectatePlayer(p)
            end)
            
            stopSpectateButton.MouseButton1Click:Connect(function()
                stopSpectating()
            end)
            
            teleportButton.MouseButton1Click:Connect(function()
                if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and Player.rootPart then
                    local targetPosition = p.Character.HumanoidRootPart.CFrame
                    local newPosition = targetPosition * CFrame.new(0, 0, 5)
                    Player.rootPart.CFrame = newPosition
                    print("Teleported to: " .. p.Name)
                else
                    print("Cannot teleport: No valid target player or missing rootPart")
                end
            end)
            
            followButton.MouseButton1Click:Connect(function()
                toggleFollowPlayer(p)
                Player.updatePlayerList()
            end)
            
            stopFollowButton.MouseButton1Click:Connect(function()
                if Player.followTarget == p then
                    stopFollowing()
                    Player.updatePlayerList()
                end
            end)
            
            bringButton.MouseButton1Click:Connect(function()
                bringPlayer(p)
            end)
            
            magnetButton.MouseButton1Click:Connect(function()
                if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and Player.rootPart then
                    Player.magnetPlayerPositions[p] = p.Character.HumanoidRootPart
                    toggleMagnetPlayers(true)
                else
                    print("Cannot magnet: No valid target player or missing rootPart")
                end
            end)
            
            hideButton.MouseButton1Click:Connect(function()
                if Player.hiddenPlayers[p] then
                    showPlayer(p)
                    hideButton.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
                    hideButton.Text = "HIDE"
                else
                    hidePlayer(p)
                    hideButton.BackgroundColor3 = Color3.fromRGB(80, 40, 80)
                    hideButton.Text = "SHOW"
                end
                updateSpectateButtons()
            end)
            
            freezeIndividualButton.MouseButton1Click:Connect(function()
                if Player.frozenPlayerPositions[p] then
                    unfreezePlayer(p)
                    freezeIndividualButton.BackgroundColor3 = Color3.fromRGB(40, 40, 100)
                    freezeIndividualButton.Text = "FREEZE"
                else
                    freezePlayer(p)
                    freezeIndividualButton.BackgroundColor3 = Color3.fromRGB(80, 80, 40)
                    freezeIndividualButton.Text = "UNFREEZE"
                end
            end)
            
            -- Hover effects
            local buttons = {spectateButton, stopSpectateButton, teleportButton, followButton, stopFollowButton, bringButton, magnetButton, hideButton, freezeIndividualButton}
            local hoverColors = {
                Color3.fromRGB(50, 100, 50), Color3.fromRGB(100, 50, 50), Color3.fromRGB(50, 50, 100),
                Color3.fromRGB(80, 60, 100), Color3.fromRGB(100, 60, 80), Color3.fromRGB(50, 80, 100),
                Color3.fromRGB(80, 100, 50), Color3.fromRGB(100, 80, 60), Color3.fromRGB(60, 60, 120)
            }
            local originalColors = {
                Color3.fromRGB(40, 80, 40), Color3.fromRGB(80, 40, 40), Color3.fromRGB(40, 40, 80),
                followButton.BackgroundColor3, Color3.fromRGB(80, 40, 60), Color3.fromRGB(40, 60, 80),
                Color3.fromRGB(60, 80, 40), hideButton.BackgroundColor3, freezeIndividualButton.BackgroundColor3
            }
            
            for i, button in ipairs(buttons) do
                button.MouseEnter:Connect(function()
                    button.BackgroundColor3 = hoverColors[i]
                end)
                button.MouseLeave:Connect(function()
                    button.BackgroundColor3 = originalColors[i]
                end)
            end
        end
    end
    
    task.spawn(function()
        task.wait(0.1)
        local contentSize = PlayerListLayout.AbsoluteContentSize
        PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(contentSize.Y + 10, 30))
    end)
    updateSpectateButtons()
end

-- Teleport to Spectated Player - Fixed
local function teleportToSpectatedPlayer()
    if Player.selectedPlayer and Player.selectedPlayer.Character and Player.selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and Player.rootPart then
        local targetPosition = Player.selectedPlayer.Character.HumanoidRootPart.CFrame
        local newPosition = targetPosition * CFrame.new(0, 0, 5)
        Player.rootPart.CFrame = newPosition
        print("Teleported to spectated player: " .. Player.selectedPlayer.Name)
    else
        print("Cannot teleport: No valid spectated player or missing rootPart")
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
    updateSpectateButtons()
end

-- Improved Follow Player with better pathfinding
local function followPlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then
        print("Cannot follow: Invalid target player")
        return
    end
    
    if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        print("Cannot follow: Target player has no character or HumanoidRootPart")
        return
    end
    
    if not Player.rootPart or not humanoid then
        print("Cannot follow: Missing rootPart or humanoid")
        return
    end
    
    stopFollowing()
    
    Player.followEnabled = true
    Player.followTarget = targetPlayer
    
    local PathfindingService = game:GetService("PathfindingService")
    
    print("Started following: " .. targetPlayer.Name)
    
    local currentPath = nil
    local currentWaypoint = 1
    local pathUpdateTime = 0
    local lastTargetPos = Vector3.new(0, 0, 0)
    local followDistance = 5
    
    Player.followConnections.heartbeat = RunService.Heartbeat:Connect(function()
        if not Player.followEnabled or not Player.followTarget then
            stopFollowing()
            return
        end
        
        if not Player.followTarget.Character or not Player.followTarget.Character:FindFirstChild("HumanoidRootPart") or not Player.followTarget.Character:FindFirstChild("Humanoid") then
            return
        end
        
        local currentTargetRootPart = Player.followTarget.Character.HumanoidRootPart
        local currentTargetHumanoid = Player.followTarget.Character.Humanoid
        
        if not Player.rootPart or not humanoid then
            stopFollowing()
            return
        end
        
        local targetPosition = currentTargetRootPart.Position
        local ourPosition = Player.rootPart.Position
        local distance = (ourPosition - targetPosition).Magnitude
        
        -- Update path if target moved significantly or path is old
        local currentTime = tick()
        if not currentPath or (lastTargetPos - targetPosition).Magnitude > 6 or currentTime - pathUpdateTime > 3 then
            pathUpdateTime = currentTime
            lastTargetPos = targetPosition
            
            -- Calculate follow position (behind target)
            local followOffset = currentTargetRootPart.CFrame.LookVector * -followDistance
            local followPosition = targetPosition + followOffset
            
            pcall(function()
                currentPath = PathfindingService:CreatePath({
                    AgentRadius = 2,
                    AgentHeight = 5,
                    AgentCanJump = true,
                    WaypointSpacing = 4,
                    AgentMaxSlope = 45
                })
                
                currentPath:ComputeAsync(ourPosition, followPosition)
                
                if currentPath.Status == Enum.PathStatus.Success then
                    currentWaypoint = 1
                else
                    currentPath = nil
                end
            end)
        end
        
        -- Follow the path or move directly
        if currentPath and currentPath.Status == Enum.PathStatus.Success then
            local waypoints = currentPath:GetWaypoints()
            
            if currentWaypoint <= #waypoints then
                local waypoint = waypoints[currentWaypoint]
                local waypointDistance = (ourPosition - waypoint.Position).Magnitude
                
                humanoid:MoveTo(waypoint.Position)
                
                if waypoint.Action == Enum.PathWaypointAction.Jump then
                    humanoid.Jump = true
                end
                
                if waypointDistance < 4 then
                    currentWaypoint = currentWaypoint + 1
                end
            end
        else
            -- Direct movement if pathfinding fails or we're close
            if distance > followDistance then
                local followOffset = currentTargetRootPart.CFrame.LookVector * -followDistance
                local followPosition = targetPosition + followOffset
                humanoid:MoveTo(followPosition)
            end
        end
        
        -- Match target's movement properties
        humanoid.WalkSpeed = math.max(currentTargetHumanoid.WalkSpeed * 1.1, 16)
        
        if currentTargetHumanoid.Jump then
            humanoid.Jump = true
        end
        
        Player.lastTargetPosition = targetPosition
    end)
    
    Player.followConnections.characterAdded = Player.followTarget.CharacterAdded:Connect(function(newCharacter)
        if not Player.followEnabled or Player.followTarget ~= targetPlayer then return end
        
        local newRootPart = newCharacter:WaitForChild("HumanoidRootPart", 10)
        local newHumanoid = newCharacter:WaitForChild("Humanoid", 10)
        
        if newRootPart and newHumanoid then
            print("Target respawned, continuing follow: " .. Player.followTarget.Name)
            currentPath = nil
            currentWaypoint = 1
            pathUpdateTime = 0
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
            currentPath = nil
            print("Our character respawned, continuing follow")
        else
            print("Failed to get our new character parts")
            stopFollowing()
        end
    end)
    
    Player.updatePlayerList()
    updateSpectateButtons()
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

-- Toggle Spectate UI Visibility
local function toggleSpectateUIVisibility()
    Player.spectateUIVisible = not Player.spectateUIVisible
    Player.spectateUIHidden = not Player.spectateUIVisible
    
    if SpectateUIFrame then
        SpectateUIFrame.Visible = Player.spectateUIVisible and (Player.selectedPlayer ~= nil)
        
        if HideSpectateUIButton then
            HideSpectateUIButton.Text = Player.spectateUIVisible and "HIDE UI" or "SHOW UI"
            HideSpectateUIButton.BackgroundColor3 = Player.spectateUIVisible and Color3.fromRGB(80, 40, 40) or Color3.fromRGB(40, 80, 40)
        end
    end
    
    print(Player.spectateUIVisible and "Spectate UI shown" or "Spectate UI hidden")
end

-- Toggle Hide Selected Player
local function toggleHideSelectedPlayer()
    if not Player.selectedPlayer then
        print("No player selected to hide")
        return
    end
    
    if Player.hiddenPlayers[Player.selectedPlayer] then
        showPlayer(Player.selectedPlayer)
    else
        hidePlayer(Player.selectedPlayer)
    end
    
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
    createToggleButton("Magnet Players", toggleMagnetPlayers, "Player")
    createToggleButton("Hide Character", toggleHideCharacter, "Player")
    createToggleButton("Hide My Character", toggleHideMyCharacter, "Player")
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
    Player.hideCharacterEnabled = false
    Player.hideMyCharacterEnabled = false
    
    toggleForceField(false)
    toggleAntiAFK(false)
    toggleFreezePlayers(false)
    toggleFastRespawn(false)
    toggleNoDeathAnimation(false)
    toggleMagnetPlayers(false)
    toggleHideCharacter(false)
    toggleHideMyCharacter(false)
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
    
    -- Player List Frame
    PlayerListFrame = Instance.new("Frame")
    PlayerListFrame.Name = "PlayerListFrame"
    PlayerListFrame.Parent = ScreenGui
    PlayerListFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    PlayerListFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    PlayerListFrame.BorderSizePixel = 1
    PlayerListFrame.Position = UDim2.new(0.5, -150, 0.2, 0)
    PlayerListFrame.Size = UDim2.new(0, 300, 0, 450)
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

    -- Search Box
    PlayerSearchBox = Instance.new("TextBox")
    PlayerSearchBox.Name = "SearchBox"
    PlayerSearchBox.Parent = PlayerListFrame
    PlayerSearchBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    PlayerSearchBox.BorderColor3 = Color3.fromRGB(60, 60, 60)
    PlayerSearchBox.BorderSizePixel = 1
    PlayerSearchBox.Position = UDim2.new(0, 10, 0, 45)
    PlayerSearchBox.Size = UDim2.new(1, -20, 0, 25)
    PlayerSearchBox.Font = Enum.Font.Gotham
    PlayerSearchBox.PlaceholderText = "Search player (username/display name)..."
    PlayerSearchBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    PlayerSearchBox.Text = ""
    PlayerSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    PlayerSearchBox.TextSize = 10
    PlayerSearchBox.ClearTextOnFocus = false

    PlayerListScrollFrame = Instance.new("ScrollingFrame")
    PlayerListScrollFrame.Name = "PlayerListScrollFrame"
    PlayerListScrollFrame.Parent = PlayerListFrame
    PlayerListScrollFrame.BackgroundTransparency = 1
    PlayerListScrollFrame.Position = UDim2.new(0, 10, 0, 80)
    PlayerListScrollFrame.Size = UDim2.new(1, -20, 1, -90)
    PlayerListScrollFrame.ScrollBarThickness = 8
    PlayerListScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    PlayerListScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    PlayerListScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    PlayerListScrollFrame.BorderSizePixel = 0
    PlayerListScrollFrame.ScrollingEnabled = true

    PlayerListLayout = Instance.new("UIListLayout")
    PlayerListLayout.Parent = PlayerListScrollFrame
    PlayerListLayout.Padding = UDim.new(0, 5)
    PlayerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PlayerListLayout.FillDirection = Enum.FillDirection.Vertical

    -- Spectate UI Frame (replaces individual buttons)
    SpectateUIFrame = Instance.new("Frame")
    SpectateUIFrame.Name = "SpectateUIFrame"
    SpectateUIFrame.Parent = ScreenGui
    SpectateUIFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    SpectateUIFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    SpectateUIFrame.BorderSizePixel = 1
    SpectateUIFrame.Position = UDim2.new(0.5, -150, 0.4, 0)
    SpectateUIFrame.Size = UDim2.new(0, 300, 0, 120)
    SpectateUIFrame.Visible = false
    SpectateUIFrame.Active = true
    SpectateUIFrame.Draggable = false -- Initially not draggable

    -- Row 1: Previous, Next, Stop, Teleport
    PrevSpectateButton = Instance.new("TextButton")
    PrevSpectateButton.Name = "PrevSpectateButton"
    PrevSpectateButton.Parent = SpectateUIFrame
    PrevSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
    PrevSpectateButton.BorderSizePixel = 0
    PrevSpectateButton.Position = UDim2.new(0, 5, 0, 5)
    PrevSpectateButton.Size = UDim2.new(0, 70, 0, 25)
    PrevSpectateButton.Font = Enum.Font.Gotham
    PrevSpectateButton.Text = "< PREV"
    PrevSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    PrevSpectateButton.TextSize = 9

    NextSpectateButton = Instance.new("TextButton")
    NextSpectateButton.Name = "NextSpectateButton"
    NextSpectateButton.Parent = SpectateUIFrame
    NextSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
    NextSpectateButton.BorderSizePixel = 0
    NextSpectateButton.Position = UDim2.new(0, 80, 0, 5)
    NextSpectateButton.Size = UDim2.new(0, 70, 0, 25)
    NextSpectateButton.Font = Enum.Font.Gotham
    NextSpectateButton.Text = "NEXT >"
    NextSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    NextSpectateButton.TextSize = 9

    StopSpectateButton = Instance.new("TextButton")
    StopSpectateButton.Name = "StopSpectateButton"
    StopSpectateButton.Parent = SpectateUIFrame
    StopSpectateButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
    StopSpectateButton.BorderSizePixel = 0
    StopSpectateButton.Position = UDim2.new(0, 155, 0, 5)
    StopSpectateButton.Size = UDim2.new(0, 70, 0, 25)
    StopSpectateButton.Font = Enum.Font.Gotham
    StopSpectateButton.Text = "STOP"
    StopSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    StopSpectateButton.TextSize = 9

    TeleportSpectateButton = Instance.new("TextButton")
    TeleportSpectateButton.Name = "TeleportSpectateButton"
    TeleportSpectateButton.Parent = SpectateUIFrame
    TeleportSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
    TeleportSpectateButton.BorderSizePixel = 0
    TeleportSpectateButton.Position = UDim2.new(0, 230, 0, 5)
    TeleportSpectateButton.Size = UDim2.new(0, 65, 0, 25)
    TeleportSpectateButton.Font = Enum.Font.Gotham
    TeleportSpectateButton.Text = "TP"
    TeleportSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    TeleportSpectateButton.TextSize = 9

    -- Row 2: Follow, Hide Player, Hide UI
    FollowSpectateButton = Instance.new("TextButton")
    FollowSpectateButton.Name = "FollowSpectateButton"
    FollowSpectateButton.Parent = SpectateUIFrame
    FollowSpectateButton.BackgroundColor3 = Color3.fromRGB(60, 40, 80)
    FollowSpectateButton.BorderSizePixel = 0
    FollowSpectateButton.Position = UDim2.new(0, 5, 0, 35)
    FollowSpectateButton.Size = UDim2.new(0, 70, 0, 25)
    FollowSpectateButton.Font = Enum.Font.Gotham
    FollowSpectateButton.Text = "FOLLOW"
    FollowSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    FollowSpectateButton.TextSize = 9

    HidePlayerButton = Instance.new("TextButton")
    HidePlayerButton.Name = "HidePlayerButton"
    HidePlayerButton.Parent = SpectateUIFrame
    HidePlayerButton.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
    HidePlayerButton.BorderSizePixel = 0
    HidePlayerButton.Position = UDim2.new(0, 80, 0, 35)
    HidePlayerButton.Size = UDim2.new(0, 145, 0, 25)
    HidePlayerButton.Font = Enum.Font.Gotham
    HidePlayerButton.Text = "HIDE PLAYER"
    HidePlayerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    HidePlayerButton.TextSize = 8

    HideSpectateUIButton = Instance.new("TextButton")
    HideSpectateUIButton.Name = "HideSpectateUIButton"
    HideSpectateUIButton.Parent = SpectateUIFrame
    HideSpectateUIButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
    HideSpectateUIButton.BorderSizePixel = 0
    HideSpectateUIButton.Position = UDim2.new(0, 230, 0, 35)
    HideSpectateUIButton.Size = UDim2.new(0, 65, 0, 25)
    HideSpectateUIButton.Font = Enum.Font.Gotham
    HideSpectateUIButton.Text = "HIDE UI"
    HideSpectateUIButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    HideSpectateUIButton.TextSize = 8

    -- Show UI button (appears when UI is hidden)
    local ShowSpectateUIButton = Instance.new("TextButton")
    ShowSpectateUIButton.Name = "ShowSpectateUIButton"
    ShowSpectateUIButton.Parent = ScreenGui
    ShowSpectateUIButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
    ShowSpectateUIButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
    ShowSpectateUIButton.BorderSizePixel = 1
    ShowSpectateUIButton.Position = UDim2.new(0.5, -35, 0.4, 0)
    ShowSpectateUIButton.Size = UDim2.new(0, 70, 0, 30)
    ShowSpectateUIButton.Font = Enum.Font.Gotham
    ShowSpectateUIButton.Text = "SHOW UI"
    ShowSpectateUIButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ShowSpectateUIButton.TextSize = 9
    ShowSpectateUIButton.Visible = false
    ShowSpectateUIButton.Active = true
    ShowSpectateUIButton.Draggable = true

    -- Emote GUI Frame
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
    EmoteScrollFrame.Position = UDim2.new(0, 10, 0, 40)
    EmoteScrollFrame.Size = UDim2.new(1, -20, 1, -50)
    EmoteScrollFrame.ScrollBarThickness = 6
    EmoteScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    EmoteScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    EmoteScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    EmoteScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    EmoteScrollFrame.ScrollingEnabled = true

    local EmoteListLayout = Instance.new("UIListLayout")
    EmoteListLayout.Parent = EmoteScrollFrame
    EmoteListLayout.Padding = UDim.new(0, 5)
    EmoteListLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local emotes = {
        {name = "Cuco - Levitate", id = "507765000", catalogId = "15698511500"},
        {name = "Victory Royale Jump", id = "507771019", catalogId = "107425576246359"},
        {name = "SODA POP | SAJABOYS", id = "5092650060", catalogId = "131337151013044"},
        {name = "Orange Justice", id = "507771019", catalogId = "107425576246359"},
        {name = "Default Dance", id = "507771019", catalogId = "107425576246359"},
        {name = "Floss", id = "507771019", catalogId = "107425576246359"}
    }

    for i, emote in ipairs(emotes) do
        local emoteButton = Instance.new("TextButton")
        emoteButton.Name = "EmoteButton" .. i
        emoteButton.Parent = EmoteScrollFrame
        emoteButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        emoteButton.BorderSizePixel = 0
        emoteButton.Size = UDim2.new(1, -10, 0, 30)
        emoteButton.Font = Enum.Font.Gotham
        emoteButton.Text = emote.name
        emoteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        emoteButton.TextSize = 10
        emoteButton.LayoutOrder = i

        emoteButton.MouseButton1Click:Connect(function()
            local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
            if not humanoid then
                warn("Cannot play emote: No humanoid found")
                return
            end

            if not emote.id or emote.id == "" then
                warn("Invalid or empty emote ID for: " .. emote.name)
                return
            end

            local success, result = pcall(function()
                local animation = Instance.new("Animation")
                animation.AnimationId = "rbxassetid://" .. emote.id
                local emoteTrack = humanoid:LoadAnimation(animation)
                if emoteTrack:IsA("AnimationTrack") then
                    emoteTrack:Play()
                else
                    error("Loaded animation is not valid for: " .. emote.name)
                end
                return emoteTrack
            end)

            if success then
                print("Playing emote: " .. emote.name)
            else
                warn("Failed to play emote " .. emote.name .. " via LoadAnimation: " .. tostring(result))
                local ReplicatedStorage = game:GetService("ReplicatedStorage")
                local emoteRemote = ReplicatedStorage:FindFirstChild("EmoteRemote") or
                                    ReplicatedStorage:FindFirstChild("PlayEmote") or
                                    ReplicatedStorage:FindFirstChild("Emote")
                if emoteRemote and emoteRemote:IsA("RemoteEvent") then
                    pcall(function()
                        emoteRemote:FireServer(emote.name)
                        print("Triggered emote " .. emote.name .. " via RemoteEvent")
                    end)
                else
                    warn("No valid RemoteEvent found for emote: " .. emote.name)
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

    -- Event Connections
    NextSpectateButton.MouseButton1Click:Connect(spectateNextPlayer)
    PrevSpectateButton.MouseButton1Click:Connect(spectatePrevPlayer)
    StopSpectateButton.MouseButton1Click:Connect(stopSpectating)
    TeleportSpectateButton.MouseButton1Click:Connect(teleportToSpectatedPlayer)
    FollowSpectateButton.MouseButton1Click:Connect(function()
        if Player.selectedPlayer then
            toggleFollowPlayer(Player.selectedPlayer)
        end
    end)
    HidePlayerButton.MouseButton1Click:Connect(toggleHideSelectedPlayer)
    HideSpectateUIButton.MouseButton1Click:Connect(function()
        Player.spectateUIVisible = false
        Player.spectateUIHidden = true
        SpectateUIFrame.Visible = false
        SpectateUIFrame.Draggable = false
        ShowSpectateUIButton.Visible = true
        ShowSpectateUIButton.Draggable = true
        HideSpectateUIButton.Text = "SHOW UI"
    end)
    
    ShowSpectateUIButton.MouseButton1Click:Connect(function()
        Player.spectateUIVisible = true
        Player.spectateUIHidden = false
        SpectateUIFrame.Visible = Player.selectedPlayer ~= nil
        SpectateUIFrame.Draggable = true
        ShowSpectateUIButton.Visible = false
        ShowSpectateUIButton.Draggable = false
        HideSpectateUIButton.Text = "HIDE UI"
        updateSpectateButtons()
    end)

    ClosePlayerListButton.MouseButton1Click:Connect(function()
        Player.playerListVisible = false
        PlayerListFrame.Visible = false
    end)

    CloseEmoteButton.MouseButton1Click:Connect(function()
        EmoteGuiFrame.Visible = false
    end)

    -- Search functionality
    PlayerSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        Player.updatePlayerList()
    end)

    -- Hover effects for spectate buttons
    local spectateButtons = {NextSpectateButton, PrevSpectateButton, StopSpectateButton, TeleportSpectateButton, FollowSpectateButton, HidePlayerButton, HideSpectateUIButton, ShowSpectateUIButton}
    local spectateHoverColors = {
        Color3.fromRGB(50, 100, 50), Color3.fromRGB(50, 100, 50), Color3.fromRGB(100, 50, 50), 
        Color3.fromRGB(50, 50, 100), Color3.fromRGB(80, 60, 100), Color3.fromRGB(100, 80, 60), 
        Color3.fromRGB(100, 60, 60), Color3.fromRGB(50, 100, 50)
    }
    local spectateOriginalColors = {
        Color3.fromRGB(40, 80, 40), Color3.fromRGB(40, 80, 40), Color3.fromRGB(80, 40, 40), 
        Color3.fromRGB(40, 40, 80), Color3.fromRGB(60, 40, 80), Color3.fromRGB(80, 60, 40), 
        Color3.fromRGB(80, 40, 40), Color3.fromRGB(40, 80, 40)
    }

    for i, button in ipairs(spectateButtons) do
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = spectateHoverColors[i]
        end)
        button.MouseLeave:Connect(function()
            if button == FollowSpectateButton and Player.selectedPlayer and Player.followTarget == Player.selectedPlayer then
                button.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
            elseif button == HidePlayerButton and Player.selectedPlayer and Player.hiddenPlayers[Player.selectedPlayer] then
                button.BackgroundColor3 = Color3.fromRGB(40, 80, 60)
            else
                button.BackgroundColor3 = spectateOriginalColors[i]
            end
        end)
    end
    
    print("Player UI initialized successfully")
end

-- Initialize Module
function Player.init(deps)
    print("Initializing Player module...")
    
    Players = deps.Players
    RunService = deps.RunService
    Workspace = deps.Workspace
    humanoid = deps.humanoid
    connections = deps.connections
    buttonStates = deps.buttonStates
    ScrollFrame = deps.ScrollFrame
    ScreenGui = deps.ScreenGui
    player = deps.player
    Player.rootPart = deps.rootPart
    
    if not Players or not RunService or not Workspace or not ScreenGui or not player then
        warn("Critical dependencies missing for Player module!")
        return false
    end
    
    -- Initialize variables
    Player.forceFieldEnabled = false
    Player.antiAFKEnabled = false
    Player.freezeEnabled = false
    Player.followEnabled = false
    Player.fastRespawnEnabled = false
    Player.noDeathAnimationEnabled = false
    Player.magnetEnabled = false
    Player.hideCharacterEnabled = false
    Player.hideMyCharacterEnabled = false
    Player.selectedPlayer = nil
    Player.spectatePlayerList = {}
    Player.currentSpectateIndex = 0
    Player.spectateConnections = {}
    Player.playerListVisible = false
    Player.frozenPlayerPositions = {}
    Player.playerConnections = {}
    Player.followTarget = nil
    Player.followConnections = {}
    Player.followOffset = Vector3.new(0, 0, 3)
    Player.lastTargetPosition = nil
    Player.followSpeed = 1.2
    Player.followPathfinding = nil
    Player.deathAnimationConnections = {}
    Player.magnetPlayerPositions = {}
    Player.hiddenPlayers = {}
    Player.originalMyCharacterTransparency = {}
    Player.spectateUIVisible = true
    Player.spectateUIHidden = false
    
    pcall(initUI)
    pcall(Player.setupPlayerEvents)
    
    -- Handle local player respawn for magnet and hide
    connections.localPlayerRespawn = player.CharacterAdded:Connect(function(newCharacter)
        task.wait(0.5)
        if newCharacter:FindFirstChild("HumanoidRootPart") then
            Player.rootPart = newCharacter.HumanoidRootPart
            humanoid = newCharacter:FindFirstChild("Humanoid")
            if Player.magnetEnabled then
                print("Local player respawned, reapplying magnet...")
                toggleMagnetPlayers(true)
            end
            if Player.hideMyCharacterEnabled then
                print("Local player respawned, reapplying hide my character...")
                task.wait(0.5)
                hideMyCharacter()
            end
        end
    end)
    
    print("Player module initialized successfully")
    return true
end

-- Setup Player Events
function Player.setupPlayerEvents()
    if not Players then
        warn("Players service not available for setupPlayerEvents")
        return
    end
    
    print("Setting up Player events...")
    
    Players.PlayerAdded:Connect(function(p)
        if p ~= player then
            print("New player joined: " .. p.Name)
            setupPlayerMonitoring(p)
            Player.updatePlayerList()
        end
    end)

    Players.PlayerRemoving:Connect(function(p)
        if p == Player.selectedPlayer then
            stopSpectating()
        end
        if p == Player.followTarget then
            stopFollowing()
        end
        cleanupPlayerMonitoring(p)
        Player.updatePlayerList()
        print("Player left: " .. p.Name)
    end)

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            setupPlayerMonitoring(p)
        end
    end
    
    task.spawn(function()
        while true do
            Player.updatePlayerList()
            task.wait(5)
        end
    end)
    
    print("Player events set up successfully")
end

return Player