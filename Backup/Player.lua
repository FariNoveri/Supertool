-- Player-related features for MinimalHackGUI by Fari Noveri, including spectate, player list, freeze players, and follow player

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

-- Variables for follow player feature
Player.followEnabled = false
Player.followTarget = nil
Player.followConnections = {}
Player.followOffset = Vector3.new(0, 0, 3) -- Follow from behind by 3 studs
Player.lastTargetPosition = nil
Player.followSpeed = 1.2 -- Multiplier for follow speed to keep up
Player.followPathfinding = nil

-- Variables for new features
Player.fastRespawnEnabled = false
Player.noDeathAnimationEnabled = false
Player.deathAnimationConnections = {}

-- UI Elements
local PlayerListFrame, PlayerListScrollFrame, PlayerListLayout, SelectedPlayerLabel
local ClosePlayerListButton, NextSpectateButton, PrevSpectateButton, StopSpectateButton, TeleportSpectateButton

-- Force Field (God Mode replacement)
local function toggleForceField(enabled)
    Player.forceFieldEnabled = enabled
    if enabled then
        if player.Character then
            -- Create ForceField if it doesn't exist
            if not player.Character:FindFirstChild("ForceField") then
                local forceField = Instance.new("ForceField")
                forceField.Parent = player.Character
                forceField.Visible = false -- Make it invisible
                print("Force Field enabled")
            end
            
            -- Monitor character respawn to reapply ForceField
            connections.forcefield = player.CharacterAdded:Connect(function(character)
                if Player.forceFieldEnabled then
                    task.wait(0.1) -- Small delay to ensure character is fully loaded
                    if not character:FindFirstChild("ForceField") then
                        local forceField = Instance.new("ForceField")
                        forceField.Parent = character
                        forceField.Visible = false
                        print("Force Field reapplied after respawn")
                    end
                end
            end)
        else
            warn("Cannot enable Force Field: No character found")
        end
    else
        -- Remove ForceField
        if player.Character and player.Character:FindFirstChild("ForceField") then
            player.Character.ForceField:Destroy()
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

-- Fast Respawn - Client-safe version
local function toggleFastRespawn(enabled)
    Player.fastRespawnEnabled = enabled
    if enabled then
        -- Monitor for character removal and speed up the respawn waiting process
        connections.fastrespawn = player.CharacterRemoving:Connect(function(character)
            if Player.fastRespawnEnabled then
                print("Character removing, preparing for fast respawn...")
                
                -- Store respawn request
                task.spawn(function()
                    -- Wait for character to be fully removed
                    while player.Character == character do
                        task.wait(0.1)
                    end
                    
                    -- Try different client-side respawn methods
                    local success = false
                    
                    -- Method 1: Try using StarterGui reset
                    if not success then
                        local StarterGui = game:GetService("StarterGui")
                        local resetSuccess = pcall(function()
                            StarterGui:SetCore("ResetButtonCallback", true)
                        end)
                        if resetSuccess then
                            success = true
                            print("Fast respawn via StarterGui")
                        end
                    end
                    
                    -- Method 2: Check for game-specific respawn remotes
                    if not success then
                        local ReplicatedStorage = game:GetService("ReplicatedStorage")
                        local respawnRemote = ReplicatedStorage:FindFirstChild("RespawnRemote") or 
                                             ReplicatedStorage:FindFirstChild("Respawn") or
                                             ReplicatedStorage:FindFirstChild("LoadCharacter")
                        
                        if respawnRemote and respawnRemote:IsA("RemoteEvent") then
                            pcall(function()
                                respawnRemote:FireServer()
                                success = true
                                print("Fast respawn via RemoteEvent")
                            end)
                        end
                    end
                    
                    -- If no special method worked, just wait for natural respawn
                    if not success then
                        print("Fast respawn: Using natural respawn process")
                        local startTime = tick()
                        while not player.Character and Player.fastRespawnEnabled and (tick() - startTime) < 10 do
                            task.wait(0.1)
                        end
                    end
                    
                    if player.Character and Player.fastRespawnEnabled then
                        print("Fast respawn completed!")
                    end
                end)
            end
        end)
        
        -- Also monitor for when we actually get a new character
        connections.fastrespawncharadded = player.CharacterAdded:Connect(function(newCharacter)
            if Player.fastRespawnEnabled then
                print("Fast respawn: New character loaded")
                -- Ensure we update our rootPart reference
                task.wait(0.5)
                if newCharacter:FindFirstChild("HumanoidRootPart") then
                    Player.rootPart = newCharacter.HumanoidRootPart
                end
            end
        end)
        
        print("Fast Respawn enabled (Client-safe version)")
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

-- No Death Animation - Fixed version
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
                        -- Remove death sound
                        for _, sound in pairs(character:GetChildren()) do
                            if sound:IsA("Sound") and (sound.Name:lower():find("death") or sound.Name:lower():find("died")) then
                                sound:Stop()
                                sound.Volume = 0
                            end
                        end
                        
                        -- Prevent death animation by making character disappear
                        for _, part in pairs(character:GetChildren()) do
                            if part:IsA("BasePart") then
                                part.Transparency = 1
                            elseif part:IsA("Accessory") then
                                local handle = part:FindFirstChild("Handle")
                                if handle then
                                    handle.Transparency = 1
                                end
                            end
                        end
                        
                        -- Stop all animations
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
        
        -- Setup for current character
        if targetPlayer.Character then
            setupCharacterNoDeathAnimation(targetPlayer.Character)
        end
        
        -- Setup for future characters
        Player.deathAnimationConnections[targetPlayer].characterAdded = targetPlayer.CharacterAdded:Connect(function(character)
            setupCharacterNoDeathAnimation(character)
        end)
    end
    
    if enabled then
        -- Apply to all current players
        for _, p in pairs(Players:GetPlayers()) do
            setupNoDeathForPlayer(p)
        end
        
        -- Apply to future players
        connections.nodeathanimation = Players.PlayerAdded:Connect(function(p)
            if Player.noDeathAnimationEnabled then
                setupNoDeathForPlayer(p)
            end
        end)
        
        print("No Death Animation enabled for all players")
    else
        -- Clean up all connections
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
        task.wait(1) -- Wait for character to fully load
        
        if Player.freezeEnabled then
            freezePlayer(targetPlayer)
            print("Auto-froze respawned player: " .. targetPlayer.Name)
        end
        
        -- Reapply follow if this was our follow target
        if Player.followEnabled and Player.followTarget == targetPlayer then
            task.wait(0.5)
            followPlayer(targetPlayer)
            print("Resumed following respawned player: " .. targetPlayer.Name)
        end
        
        -- Reapply spectate if this was our spectate target
        if Player.selectedPlayer == targetPlayer then
            task.wait(0.5)
            spectatePlayer(targetPlayer)
            print("Resumed spectating respawned player: " .. targetPlayer.Name)
        end
        
        -- Apply no death animation if enabled
        if Player.noDeathAnimationEnabled then
            local humanoidTarget = character:WaitForChild("Humanoid", 5)
            if humanoidTarget and not Player.deathAnimationConnections[targetPlayer] then
                setupNoDeathForPlayer(targetPlayer)
            end
        end
    end)
    
    -- Initial freeze if freeze is enabled
    if Player.freezeEnabled and targetPlayer.Character then
        freezePlayer(targetPlayer)
    end
    
    -- Initial no death animation setup if enabled
    if Player.noDeathAnimationEnabled then
        setupNoDeathForPlayer(targetPlayer)
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
end

-- Stop Following Player
local function stopFollowing()
    Player.followEnabled = false
    Player.followTarget = nil
    Player.lastTargetPosition = nil
    
    -- Disconnect all follow connections
    for _, connection in pairs(Player.followConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    Player.followConnections = {}
    
    -- Destroy pathfinding if it exists
    if Player.followPathfinding then
        Player.followPathfinding = nil
    end
    
    -- Reset humanoid properties to normal
    if humanoid then
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
        humanoid.PlatformStand = false
    end
    
    print("Stopped following player")
end

-- Enhanced Follow Player function with pathfinding
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
    
    -- Stop any previous following
    stopFollowing()
    
    Player.followEnabled = true
    Player.followTarget = targetPlayer
    
    -- Create PathfindingService
    local PathfindingService = game:GetService("PathfindingService")
    
    local targetRootPart = targetPlayer.Character.HumanoidRootPart
    local targetHumanoid = targetPlayer.Character.Humanoid
    
    print("Started following: " .. targetPlayer.Name)
    
    -- Variables for pathfinding
    local currentPath = nil
    local currentWaypoint = 0
    local pathUpdateTime = 0
    local lastTargetPos = targetRootPart.Position
    
    -- Main follow loop using Heartbeat for smooth movement
    Player.followConnections.heartbeat = RunService.Heartbeat:Connect(function()
        if not Player.followEnabled or not Player.followTarget then
            stopFollowing()
            return
        end
        
        -- Check if target still exists and has character
        if not Player.followTarget.Character or not Player.followTarget.Character:FindFirstChild("HumanoidRootPart") or not Player.followTarget.Character:FindFirstChild("Humanoid") then
            return -- Wait for respawn
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
        
        -- Update path if target moved significantly or enough time passed
        local currentTime = tick()
        if not currentPath or (lastTargetPos - targetPosition).Magnitude > 4 or currentTime - pathUpdateTime > 2 then
            pathUpdateTime = currentTime
            lastTargetPos = targetPosition
            
            -- Create new path
            pcall(function()
                currentPath = PathfindingService:CreatePath({
                    AgentRadius = 2,
                    AgentHeight = 5,
                    AgentCanJump = true,
                    WaypointSpacing = 4
                })
                
                currentPath:ComputeAsync(ourPosition, targetPosition)
                
                if currentPath.Status == Enum.PathStatus.Success then
                    currentWaypoint = 1
                else
                    currentPath = nil
                end
            end)
        end
        
        -- Follow the path or move directly if no path available
        if currentPath and currentPath.Status == Enum.PathStatus.Success then
            local waypoints = currentPath:GetWaypoints()
            
            if currentWaypoint <= #waypoints then
                local waypoint = waypoints[currentWaypoint]
                local waypointPosition = waypoint.Position
                local waypointDistance = (ourPosition - waypointPosition).Magnitude
                
                -- Move to current waypoint
                humanoid:MoveTo(waypointPosition)
                
                -- Handle jumping
                if waypoint.Action == Enum.PathWaypointAction.Jump then
                    humanoid.Jump = true
                end
                
                -- Move to next waypoint if close enough
                if waypointDistance < 3 then
                    currentWaypoint = currentWaypoint + 1
                end
            end
        else
            -- Fallback: Direct movement if pathfinding fails
            if distance > 5 then
                local followPosition = targetPosition - (currentTargetRootPart.CFrame.LookVector * Player.followOffset.Z)
                followPosition = followPosition + Vector3.new(0, Player.followOffset.Y, 0)
                humanoid:MoveTo(followPosition)
            end
        end
        
        -- Match target's movement behaviors
        humanoid.WalkSpeed = math.max(currentTargetHumanoid.WalkSpeed * Player.followSpeed, 16)
        
        -- Copy jump behavior
        if currentTargetHumanoid.Jump and not humanoid.Jump then
            humanoid.Jump = true
        end
        
        -- Copy sit behavior
        if currentTargetHumanoid.Sit ~= humanoid.Sit then
            humanoid.Sit = currentTargetHumanoid.Sit
        end
        
        -- Store current position for next frame
        Player.lastTargetPosition = targetPosition
    end)
    
    -- Handle target character respawn
    Player.followConnections.characterAdded = Player.followTarget.CharacterAdded:Connect(function(newCharacter)
        if not Player.followEnabled or Player.followTarget ~= targetPlayer then return end
        
        local newRootPart = newCharacter:WaitForChild("HumanoidRootPart", 10)
        local newHumanoid = newCharacter:WaitForChild("Humanoid", 10)
        
        if newRootPart and newHumanoid then
            print("Target respawned, continuing follow: " .. Player.followTarget.Name)
            -- Reset pathfinding
            currentPath = nil
            currentWaypoint = 0
            pathUpdateTime = 0
        else
            print("Failed to get new character parts for follow target")
            stopFollowing()
        end
    end)
    
    -- Handle target leaving
    Player.followConnections.playerRemoving = Players.PlayerRemoving:Connect(function(leavingPlayer)
        if leavingPlayer == Player.followTarget then
            print("Follow target left the game")
            stopFollowing()
        end
    end)
    
    -- Handle our own character respawn
    Player.followConnections.ourCharacterAdded = player.CharacterAdded:Connect(function(newCharacter)
        if not Player.followEnabled then return end
        
        local newRootPart = newCharacter:WaitForChild("HumanoidRootPart", 10)
        local newHumanoid = newCharacter:WaitForChild("Humanoid", 10)
        
        if newRootPart and newHumanoid then
            Player.rootPart = newRootPart
            humanoid = newHumanoid
            currentPath = nil -- Reset path after our respawn
            print("Our character respawned, continuing follow")
        else
            print("Failed to get our new character parts")
            stopFollowing()
        end
    end)
end

-- Toggle Follow Player
local function toggleFollowPlayer(enabled)
    if enabled then
        if Player.selectedPlayer then
            followPlayer(Player.selectedPlayer)
        else
            print("No player selected to follow")
            -- Return false to prevent toggle button from staying enabled
            return false
        end
    else
        stopFollowing()
    end
    return true
end

-- Enhanced Freeze Players function with new player detection
local function toggleFreezePlayers(enabled)
    Player.freezeEnabled = enabled
    
    if enabled then
        print("Activating freeze players...")
        Player.frozenPlayerPositions = {}
        
        -- Freeze all current players
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player then
                setupPlayerMonitoring(p)
                freezePlayer(p)
            end
        end
        
        -- Monitor for new players joining
        if not connections.freezeNewPlayers then
            connections.freezeNewPlayers = Players.PlayerAdded:Connect(function(newPlayer)
                if Player.freezeEnabled and newPlayer ~= player then
                    print("New player joined, setting up freeze monitoring: " .. newPlayer.Name)
                    setupPlayerMonitoring(newPlayer)
                    
                    -- Wait for character to load then freeze
                    if newPlayer.Character then
                        task.wait(1)
                        freezePlayer(newPlayer)
                    else
                        newPlayer.CharacterAdded:Wait()
                        task.wait(1)
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

-- Update Spectate Buttons Visibility
local function updateSpectateButtons()
    local isSpectating = Player.selectedPlayer ~= nil
    if NextSpectateButton then NextSpectateButton.Visible = isSpectating end
    if PrevSpectateButton then PrevSpectateButton.Visible = isSpectating end
    if StopSpectateButton then StopSpectateButton.Visible = isSpectating end
    if TeleportSpectateButton then TeleportSpectateButton.Visible = isSpectating end
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

-- Enhanced Spectate Player with better respawn handling
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
        if SelectedPlayerLabel then
            SelectedPlayerLabel.Text = "SELECTED: " .. targetPlayer.Name:upper()
        end
        print("Spectating: " .. targetPlayer.Name)
        
        -- Enhanced character respawn handling
        Player.spectateConnections.characterAdded = targetPlayer.CharacterAdded:Connect(function(newCharacter)
            if Player.selectedPlayer == targetPlayer then
                local newHumanoid = newCharacter:WaitForChild("Humanoid", 10)
                if newHumanoid then
                    task.wait(0.5) -- Small delay to ensure proper loading
                    Workspace.CurrentCamera.CameraSubject = newHumanoid
                    Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                    print("Spectated player respawned, continuing spectate: " .. targetPlayer.Name)
                end
            end
        end)
        
        -- Handle character death
        local targetHumanoid = targetPlayer.Character.Humanoid
        Player.spectateConnections.died = targetHumanoid.Died:Connect(function()
            if Player.selectedPlayer == targetPlayer then
                print("Spectated player died, waiting for respawn: " .. targetPlayer.Name)
            end
        end)
        
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

-- Update Player List
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
    
    local previousSelectedPlayer = Player.selectedPlayer
    Player.spectatePlayerList = {}
    local playerCount = 0
    local players = Players:GetPlayers()
    
    if #players <= 1 then
        local noPlayersLabel = Instance.new("TextLabel")
        noPlayersLabel.Name = "NoPlayersLabel"
        noPlayersLabel.Parent = PlayerListScrollFrame
        noPlayersLabel.BackgroundTransparency = 1
        noPlayersLabel.Size = UDim2.new(1, 0, 0, 30)
        noPlayersLabel.Font = Enum.Font.Gotham
        noPlayersLabel.Text = "No other players found"
        noPlayersLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        noPlayersLabel.TextSize = 11
        noPlayersLabel.TextXAlignment = Enum.TextXAlignment.Center
    else
        for _, p in pairs(players) do
            if p ~= player and p.Character and p.Character:FindFirstChild("Humanoid") then
                playerCount = playerCount + 1
                table.insert(Player.spectatePlayerList, p)
                
                local playerItem = Instance.new("Frame")
                playerItem.Name = p.Name .. "Item"
                playerItem.Parent = PlayerListScrollFrame
                playerItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                playerItem.BorderSizePixel = 0
                playerItem.Size = UDim2.new(1, -5, 0, 120) -- Increased height for follow button
                playerItem.LayoutOrder = playerCount
                
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Name = "NameLabel"
                nameLabel.Parent = playerItem
                nameLabel.BackgroundTransparency = 1
                nameLabel.Position = UDim2.new(0, 5, 0, 5)
                nameLabel.Size = UDim2.new(1, -10, 0, 20)
                nameLabel.Font = Enum.Font.GothamBold
                nameLabel.Text = p.Name
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                nameLabel.TextSize = 12
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                
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
                
                -- New Follow Button
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
                
                -- New Stop Follow Button
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
                
                selectButton.MouseButton1Click:Connect(function()
                    Player.selectedPlayer = p
                    Player.currentSpectateIndex = table.find(Player.spectatePlayerList, p) or 0
                    if SelectedPlayerLabel then
                        SelectedPlayerLabel.Text = "SELECTED: " .. p.Name:upper()
                    end
                    for _, item in pairs(PlayerListScrollFrame:GetChildren()) do
                        if item:IsA("Frame") and item:FindFirstChild("SelectButton") then
                            if item.Name == p.Name .. "Item" then
                                item.SelectButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                                item.SelectButton.Text = "SELECTED"
                            else
                                item.SelectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                                item.SelectButton.Text = "SELECT PLAYER"
                            end
                        end
                    end
                    updateSpectateButtons()
                end)
                
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
                        Player.rootPart.CFrame = targetPosition * CFrame.new(0, 0, 3)
                        print("Teleported to: " .. p.Name)
                    else
                        print("Cannot teleport: No valid target player or missing rootPart")
                    end
                end)
                
                followButton.MouseButton1Click:Connect(function()
                    if Player.followTarget == p then
                        print("Already following this player")
                    else
                        followPlayer(p)
                        -- Update UI
                        Player.updatePlayerList()
                    end
                end)
                
                stopFollowButton.MouseButton1Click:Connect(function()
                    if Player.followTarget == p then
                        stopFollowing()
                        -- Update UI
                        Player.updatePlayerList()
                    end
                end)
                
                -- Mouse enter/leave effects for all buttons
                selectButton.MouseEnter:Connect(function()
                    if Player.selectedPlayer ~= p then
                        selectButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                    end
                end)
                
                selectButton.MouseLeave:Connect(function()
                    if Player.selectedPlayer ~= p then
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
                
                stopSpectateButton.MouseEnter:Connect(function()
                    stopSpectateButton.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
                end)
                
                stopSpectateButton.MouseLeave:Connect(function()
                    stopSpectateButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
                end)
                
                teleportButton.MouseEnter:Connect(function()
                    teleportButton.BackgroundColor3 = Color3.fromRGB(50, 50, 100)
                end)
                
                teleportButton.MouseLeave:Connect(function()
                    teleportButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
                end)
                
                followButton.MouseEnter:Connect(function()
                    if Player.followTarget == p then
                        followButton.BackgroundColor3 = Color3.fromRGB(100, 80, 60)
                    else
                        followButton.BackgroundColor3 = Color3.fromRGB(80, 60, 100)
                    end
                end)
                
                followButton.MouseLeave:Connect(function()
                    if Player.followTarget == p then
                        followButton.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
                    else
                        followButton.BackgroundColor3 = Color3.fromRGB(60, 40, 80)
                    end
                end)
                
                stopFollowButton.MouseEnter:Connect(function()
                    stopFollowButton.BackgroundColor3 = Color3.fromRGB(100, 60, 80)
                end)
                
                stopFollowButton.MouseLeave:Connect(function()
                    stopFollowButton.BackgroundColor3 = Color3.fromRGB(80, 40, 60)
                end)
            end
        end
    end
    
    if previousSelectedPlayer then
        Player.selectedPlayer = previousSelectedPlayer
        Player.currentSpectateIndex = table.find(Player.spectatePlayerList, Player.selectedPlayer) or 0
        if Player.currentSpectateIndex == 0 and Player.selectedPlayer then
            if not (Player.selectedPlayer.Character and Player.selectedPlayer.Character:FindFirstChild("Humanoid")) then
                stopSpectating()
            end
        end
        if SelectedPlayerLabel then
            SelectedPlayerLabel.Text = Player.selectedPlayer and "SELECTED: " .. Player.selectedPlayer.Name:upper() or "SELECTED: NONE"
        end
    else
        Player.currentSpectateIndex = 0
    end
    
    task.spawn(function()
        task.wait(0.1)
        local contentSize = PlayerListLayout.AbsoluteContentSize
        PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(contentSize.Y + 10, 30))
    end)
    updateSpectateButtons()
end

-- Teleport to Spectated Player
local function teleportToSpectatedPlayer()
    if Player.selectedPlayer and Player.selectedPlayer.Character and Player.selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and Player.rootPart then
        local targetPosition = Player.selectedPlayer.Character.HumanoidRootPart.CFrame
        Player.rootPart.CFrame = targetPosition * CFrame.new(0, 0, 3)
        print("Teleported to spectated player: " .. Player.selectedPlayer.Name)
    else
        print("Cannot teleport: No valid spectated player or missing rootPart")
    end
end

-- Get Selected Player
function Player.getSelectedPlayer()
    return Player.selectedPlayer
end

-- Get Follow Target
function Player.getFollowTarget()
    return Player.followTarget
end

-- Load Player Buttons
function Player.loadPlayerButtons(createButton, createToggleButton, selectedPlayer)
    print("Loading Player buttons...")
    createButton("Select Player", showPlayerSelection, "Player")
    createToggleButton("Force Field", toggleForceField, "Player")
    createToggleButton("Anti AFK", toggleAntiAFK, "Player")
    createToggleButton("Freeze Players", toggleFreezePlayers, "Player")
    createToggleButton("Follow Player", toggleFollowPlayer, "Player")
    createToggleButton("Fast Respawn", toggleFastRespawn, "Player")
    createToggleButton("No Death Animation", toggleNoDeathAnimation, "Player")
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
    
    toggleForceField(false)
    toggleAntiAFK(false)
    toggleFreezePlayers(false)
    toggleFastRespawn(false)
    toggleNoDeathAnimation(false)
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
    PlayerListFrame.Size = UDim2.new(0, 300, 0, 400) -- Increased height for follow buttons
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

    SelectedPlayerLabel = Instance.new("TextLabel")
    SelectedPlayerLabel.Name = "SelectedPlayerLabel"
    SelectedPlayerLabel.Parent = PlayerListFrame
    SelectedPlayerLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    SelectedPlayerLabel.BorderSizePixel = 0
    SelectedPlayerLabel.Position = UDim2.new(0, 10, 0, 45)
    SelectedPlayerLabel.Size = UDim2.new(1, -20, 0, 25)
    SelectedPlayerLabel.Font = Enum.Font.Gotham
    SelectedPlayerLabel.Text = "SELECTED: NONE"
    SelectedPlayerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    SelectedPlayerLabel.TextSize = 10

    PlayerListScrollFrame = Instance.new("ScrollingFrame")
    PlayerListScrollFrame.Name = "PlayerListScrollFrame"
    PlayerListScrollFrame.Parent = PlayerListFrame
    PlayerListScrollFrame.BackgroundTransparency = 1
    PlayerListScrollFrame.Position = UDim2.new(0, 10, 0, 80)
    PlayerListScrollFrame.Size = UDim2.new(1, -20, 1, -90)
    PlayerListScrollFrame.ScrollBarThickness = 4
    PlayerListScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    PlayerListScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    PlayerListScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    PlayerListScrollFrame.BorderSizePixel = 0

    PlayerListLayout = Instance.new("UIListLayout")
    PlayerListLayout.Parent = PlayerListScrollFrame
    PlayerListLayout.Padding = UDim.new(0, 2)
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
    StopSpectateButton.Position = UDim2.new(0.5, -30, 0.5, 40)
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
    TeleportSpectateButton.Position = UDim2.new(0.5, 40, 0.5, 40)
    TeleportSpectateButton.Size = UDim2.new(0, 60, 0, 30)
    TeleportSpectateButton.Font = Enum.Font.Gotham
    TeleportSpectateButton.Text = "TP"
    TeleportSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    TeleportSpectateButton.TextSize = 10
    TeleportSpectateButton.Visible = false
    TeleportSpectateButton.Active = true

    NextSpectateButton.MouseButton1Click:Connect(spectateNextPlayer)
    PrevSpectateButton.MouseButton1Click:Connect(spectatePrevPlayer)
    StopSpectateButton.MouseButton1Click:Connect(stopSpectating)
    TeleportSpectateButton.MouseButton1Click:Connect(teleportToSpectatedPlayer)

    NextSpectateButton.MouseEnter:Connect(function()
        NextSpectateButton.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
    end)
    NextSpectateButton.MouseLeave:Connect(function()
        NextSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
    end)

    PrevSpectateButton.MouseEnter:Connect(function()
        PrevSpectateButton.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
    end)
    PrevSpectateButton.MouseLeave:Connect(function()
        PrevSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
    end)

    StopSpectateButton.MouseEnter:Connect(function()
        StopSpectateButton.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
    end)
    StopSpectateButton.MouseLeave:Connect(function()
        StopSpectateButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
    end)

    TeleportSpectateButton.MouseEnter:Connect(function()
        TeleportSpectateButton.BackgroundColor3 = Color3.fromRGB(50, 50, 100)
    end)
    TeleportSpectateButton.MouseLeave:Connect(function()
        TeleportSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
    end)

    ClosePlayerListButton.MouseButton1Click:Connect(function()
        Player.playerListVisible = false
        PlayerListFrame.Visible = false
    end)
    
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
    
    Player.forceFieldEnabled = false
    Player.antiAFKEnabled = false
    Player.freezeEnabled = false
    Player.followEnabled = false
    Player.fastRespawnEnabled = false
    Player.noDeathAnimationEnabled = false
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
    
    pcall(initUI)
    pcall(Player.setupPlayerEvents)
    
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