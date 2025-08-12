-- Freeze Players feature for MinimalHackGUI by Fari Noveri

local Freeze = {}

-- Dependencies
local Players, RunService, connections, player

-- State
Freeze.enabled = false
Freeze.frozenPlayerPositions = {}
Freeze.playerConnections = {}

-- Helper function to freeze a single player
local function freezePlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then return end
    
    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = targetPlayer.Character.HumanoidRootPart
        
        if not Freeze.frozenPlayerPositions[targetPlayer] then
            Freeze.frozenPlayerPositions[targetPlayer] = {
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
        local frozenData = Freeze.frozenPlayerPositions[targetPlayer]
        
        hrp.Anchored = frozenData and frozenData.anchored or false
        
        if targetPlayer.Character:FindFirstChild("Humanoid") then
            local hum = targetPlayer.Character.Humanoid
            hum.PlatformStand = false
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
        
        print("Unfroze player: " .. targetPlayer.Name)
    end
    
    Freeze.frozenPlayerPositions[targetPlayer] = nil
end

-- Setup monitoring for a specific player
local function setupPlayerMonitoring(targetPlayer)
    if targetPlayer == player or Freeze.playerConnections[targetPlayer] then return end
    
    Freeze.playerConnections[targetPlayer] = {}
    
    Freeze.playerConnections[targetPlayer].characterAdded = targetPlayer.CharacterAdded:Connect(function(character)
        if not Freeze.enabled then return end
        
        local hrp = character:WaitForChild("HumanoidRootPart", 5)
        if hrp then
            wait(0.5)
            freezePlayer(targetPlayer)
            print("Auto-froze respawned player: " .. targetPlayer.Name)
        end
    end)
    
    if Freeze.enabled and targetPlayer.Character then
        freezePlayer(targetPlayer)
    end
end

-- Clean up monitoring for a specific player
local function cleanupPlayerMonitoring(targetPlayer)
    if Freeze.playerConnections[targetPlayer] then
        for _, connection in pairs(Freeze.playerConnections[targetPlayer]) do
            if connection then
                connection:Disconnect()
            end
        end
        Freeze.playerConnections[targetPlayer] = nil
    end
    
    Freeze.frozenPlayerPositions[targetPlayer] = nil
end

-- Toggle Freeze Players
local function toggleFreezePlayers(enabled)
    Freeze.enabled = enabled
    
    if enabled then
        print("Activating freeze players...")
        Freeze.frozenPlayerPositions = {}
        
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player then
                setupPlayerMonitoring(p)
                freezePlayer(p)
            end
        end
        
        connections.freeze = RunService.Heartbeat:Connect(function()
            if Freeze.enabled then
                for targetPlayer, frozenData in pairs(Freeze.frozenPlayerPositions) do
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
        
        for targetPlayer, _ in pairs(Freeze.frozenPlayerPositions) do
            unfreezePlayer(targetPlayer)
        end
        
        for targetPlayer, _ in pairs(Freeze.playerConnections) do
            cleanupPlayerMonitoring(targetPlayer)
        end
        
        Freeze.frozenPlayerPositions = {}
        Freeze.playerConnections = {}
        print("Players unfrozen successfully")
    end
end

-- Setup events for player join/leave
function Freeze.setupEvents()
    Players.PlayerAdded:Connect(function(p)
        if p ~= player then
            setupPlayerMonitoring(p)
        end
    end)

    Players.PlayerRemoving:Connect(function(p)
        cleanupPlayerMonitoring(p)
    end)
end

-- Load buttons for this feature
function Freeze.loadButtons(createButton, createToggleButton)
    createToggleButton("Freeze Players", toggleFreezePlayers, "Player")
end

-- Reset states
function Freeze.resetStates()
    Freeze.enabled = false
    toggleFreezePlayers(false)
end

-- Initialize
function Freeze.init(deps)
    Players = deps.Players
    RunService = deps.RunService
    connections = deps.connections
    player = deps.player
    
    Freeze.enabled = false
    Freeze.frozenPlayerPositions = {}
    Freeze.playerConnections = {}
    
    return true
end

return Freeze