-- Follow Player feature for MinimalHackGUI by Fari Noveri

local Follow = {}

-- Dependencies
local Players, RunService, humanoid, connections, player

-- State
Follow.enabled = false
Follow.target = nil
Follow.connections = {}
Follow.offset = Vector3.new(0, 0, 3) -- Follow from behind by 3 studs
Follow.lastTargetPosition = nil
Follow.speed = 1.2 -- Multiplier for follow speed to keep up
Follow.rootPart = nil

-- Get shared selectedPlayer from main Player module
local getSelectedPlayer

-- Stop Following Player
local function stopFollowing()
    Follow.enabled = false
    Follow.target = nil
    Follow.lastTargetPosition = nil
    
    -- Disconnect all follow connections
    for _, connection in pairs(Follow.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    Follow.connections = {}
    
    -- Reset humanoid properties to normal
    if humanoid then
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
        humanoid.PlatformStand = false
    end
    
    print("Stopped following player")
end

-- Follow Player function
local function followPlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then
        print("Cannot follow: Invalid target player")
        return
    end
    
    if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        print("Cannot follow: Target player has no character or HumanoidRootPart")
        return
    end
    
    if not Follow.rootPart or not humanoid then
        print("Cannot follow: Missing rootPart or humanoid")
        return
    end
    
    -- Stop any previous following
    stopFollowing()
    
    Follow.enabled = true
    Follow.target = targetPlayer
    
    local targetRootPart = targetPlayer.Character.HumanoidRootPart
    local targetHumanoid = targetPlayer.Character.Humanoid
    
    print("Started following: " .. targetPlayer.Name)
    
    -- Main follow loop using Heartbeat for smooth movement
    Follow.connections.heartbeat = RunService.Heartbeat:Connect(function()
        if not Follow.enabled or not Follow.target then
            stopFollowing()
            return
        end
        
        -- Check if target still exists and has character
        if not Follow.target.Character or not Follow.target.Character:FindFirstChild("HumanoidRootPart") or not Follow.target.Character:FindFirstChild("Humanoid") then
            return -- Wait for respawn
        end
        
        local currentTargetRootPart = Follow.target.Character.HumanoidRootPart
        local currentTargetHumanoid = Follow.target.Character.Humanoid
        
        if not Follow.rootPart or not humanoid then
            stopFollowing()
            return
        end
        
        -- Calculate follow position (behind the target)
        local targetPosition = currentTargetRootPart.Position
        local targetLookVector = currentTargetRootPart.CFrame.LookVector
        local followPosition = targetPosition - (targetLookVector * Follow.offset.Z)
        followPosition = followPosition + Vector3.new(0, Follow.offset.Y, 0)
        
        -- Calculate distance to target
        local distance = (Follow.rootPart.Position - followPosition).Magnitude
        
        -- Only move if distance is significant to avoid jittery movement
        if distance > 2 then
            -- Set humanoid to walk towards the follow position
            humanoid:MoveTo(followPosition)
            
            -- Match target's walk speed but slightly faster to keep up
            humanoid.WalkSpeed = math.max(currentTargetHumanoid.WalkSpeed * Follow.speed, 16)
        else
            -- Stop moving if we're close enough
            humanoid:MoveTo(Follow.rootPart.Position)
        end
        
        -- Copy jump behavior
        if currentTargetHumanoid.Jump and not humanoid.Jump then
            humanoid.Jump = true
        end
        
        -- Copy sit behavior
        if currentTargetHumanoid.Sit ~= humanoid.Sit then
            humanoid.Sit = currentTargetHumanoid.Sit
        end
        
        -- Store current position for next frame
        Follow.lastTargetPosition = targetPosition
    end)
    
    -- Handle target character respawn
    Follow.connections.characterAdded = Follow.target.CharacterAdded:Connect(function(newCharacter)
        if not Follow.enabled or Follow.target ~= targetPlayer then return end
        
        local newRootPart = newCharacter:WaitForChild("HumanoidRootPart", 10)
        local newHumanoid = newCharacter:WaitForChild("Humanoid", 10)
        
        if newRootPart and newHumanoid then
            print("Target respawned, continuing follow: " .. Follow.target.Name)
            -- The heartbeat connection will automatically handle the new character
        else
            print("Failed to get new character parts for follow target")
            stopFollowing()
        end
    end)
    
    -- Handle target leaving
    Follow.connections.playerRemoving = Players.PlayerRemoving:Connect(function(leavingPlayer)
        if leavingPlayer == Follow.target then
            print("Follow target left the game")
            stopFollowing()
        end
    end)
    
    -- Handle our own character respawn
    Follow.connections.ourCharacterAdded = player.CharacterAdded:Connect(function(newCharacter)
        if not Follow.enabled then return end
        
        local newRootPart = newCharacter:WaitForChild("HumanoidRootPart", 10)
        local newHumanoid = newCharacter:WaitForChild("Humanoid", 10)
        
        if newRootPart and newHumanoid then
            Follow.rootPart = newRootPart
            humanoid = newHumanoid
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
        local selectedPlayer = getSelectedPlayer and getSelectedPlayer() or nil
        if selectedPlayer then
            followPlayer(selectedPlayer)
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

-- Get Follow Target
function Follow.getFollowTarget()
    return Follow.target
end

-- Load buttons for this feature
function Follow.loadButtons(createButton, createToggleButton)
    createToggleButton("Follow Player", toggleFollowPlayer, "Player")
end

-- Reset states
function Follow.resetStates()
    Follow.enabled = false
    stopFollowing()
end

-- Initialize
function Follow.init(deps)
    Players = deps.Players
    RunService = deps.RunService
    humanoid = deps.humanoid
    connections = deps.connections
    player = deps.player
    Follow.rootPart = deps.rootPart
    
    -- Get reference to selectedPlayer function
    getSelectedPlayer = deps.getSelectedPlayer
    
    Follow.enabled = false
    Follow.target = nil
    Follow.connections = {}
    Follow.offset = Vector3.new(0, 0, 3)
    Follow.lastTargetPosition = nil
    Follow.speed = 1.2
    
    return true
end

return Follow