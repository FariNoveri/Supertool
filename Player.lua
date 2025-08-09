-- Player-related features for MinimalHackGUI by Fari Noveri, including spectate, player list, and freeze players

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
Player.playerConnections = {} -- New: Store player-specific connections

-- UI Elements (to be initialized in init function)
local PlayerListFrame, PlayerListScrollFrame, PlayerListLayout, SelectedPlayerLabel
local ClosePlayerListButton, NextSpectateButton, PrevSpectateButton, StopSpectateButton, TeleportSpectateButton

-- God Mode
local function toggleGodMode(enabled)
    Player.godModeEnabled = enabled
    if enabled then
        connections.godmode = humanoid.HealthChanged:Connect(function()
            if Player.godModeEnabled then
                humanoid.Health = humanoid.MaxHealth
            end
        end)
        print("God Mode enabled")
    else
        if connections.godmode then
            connections.godmode:Disconnect()
            connections.godmode = nil
        end
        print("God Mode disabled")
    end
end

-- Anti AFK
local function toggleAntiAFK(enabled)
    Player.antiAFKEnabled = enabled
    if enabled then
        connections.antiafk = Players.LocalPlayer.Idled:Connect(function()
            if Player.antiAFKEnabled then
                game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
                game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
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

-- Helper function to freeze a single player
local function freezePlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then return end
    
    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = targetPlayer.Character.HumanoidRootPart
        
        -- Store original state if not already stored
        if not Player.frozenPlayerPositions[targetPlayer] then
            Player.frozenPlayerPositions[targetPlayer] = {
                cframe = hrp.CFrame,
                anchored = hrp.Anchored,
                velocity = hrp.AssemblyLinearVelocity
            }
        end
        
        -- Apply freeze
        hrp.Anchored = true
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        
        -- Disable humanoid movement
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
        
        -- Restore original state
        hrp.Anchored = frozenData and frozenData.anchored or false
        
        -- Restore humanoid movement
        if targetPlayer.Character:FindFirstChild("Humanoid") then
            local hum = targetPlayer.Character.Humanoid
            hum.PlatformStand = false
            hum.WalkSpeed = 16 -- Default Roblox walkspeed
            hum.JumpPower = 50 -- Default Roblox jump power
        end
        
        print("Unfroze player: " .. targetPlayer.Name)
    end
    
    -- Remove from frozen positions
    Player.frozenPlayerPositions[targetPlayer] = nil
end

-- Setup monitoring for a specific player
local function setupPlayerMonitoring(targetPlayer)
    if targetPlayer == player or Player.playerConnections[targetPlayer] then return end
    
    Player.playerConnections[targetPlayer] = {}
    
    -- Monitor character spawning
    Player.playerConnections[targetPlayer].characterAdded = targetPlayer.CharacterAdded:Connect(function(character)
        if not Player.freezeEnabled then return end
        
        -- Wait for HumanoidRootPart to load
        local hrp = character:WaitForChild("HumanoidRootPart", 5)
        if hrp then
            -- Small delay to ensure character is fully loaded
            wait(0.5)
            freezePlayer(targetPlayer)
            print("Auto-froze respawned player: " .. targetPlayer.Name)
        end
    end)
    
    -- If player already has character, freeze immediately if freeze is enabled
    if Player.freezeEnabled and targetPlayer.Character then
        freezePlayer(targetPlayer)
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
    
    -- Remove from frozen positions
    Player.frozenPlayerPositions[targetPlayer] = nil
end

-- Improved Freeze Players function with auto-freeze for new players
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
        
        -- Use Heartbeat for consistent position enforcement
        connections.freeze = RunService.Heartbeat:Connect(function()
            if Player.freezeEnabled then
                for targetPlayer, frozenData in pairs(Player.frozenPlayerPositions) do
                    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = targetPlayer.Character.HumanoidRootPart
                        
                        -- Force position and stop all movement
                        hrp.CFrame = frozenData.cframe
                        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        hrp.Anchored = true
                        
                        -- Keep humanoid disabled
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
        
        print("Players frozen successfully - Auto-freeze enabled for new players")
    else
        print("Deactivating freeze players...")
        
        -- Stop the freeze loop
        if connections.freeze then
            connections.freeze:Disconnect()
            connections.freeze = nil
        end
        
        -- Unfreeze all players
        for targetPlayer, _ in pairs(Player.frozenPlayerPositions) do
            unfreezePlayer(targetPlayer)
        end
        
        -- Clean up all player monitoring
        for targetPlayer, _ in pairs(Player.playerConnections) do
            cleanupPlayerMonitoring(targetPlayer)
        end
        
        Player.frozenPlayerPositions = {}
        Player.playerConnections = {}
        
        print("Players unfrozen successfully - Auto-freeze disabled")
    end
end

-- Show Player Selection UI
local function showPlayerSelection()
    Player.playerListVisible = true
    PlayerListFrame.Visible = true
    Player.updatePlayerList()
end

-- Update Spectate Buttons Visibility
local function updateSpectateButtons()
    local isSpectating = Player.selectedPlayer ~= nil
    if NextSpectateButton then NextSpectateButton.Visible = isSpectating end
    if PrevSpectateButton then PrevSpectateButton.Visible = isSpectating end
    if StopSpectateButton then StopSpectateButton.Visible = isSpectating end
    if TeleportSpectateButton then TeleportSpectateButton.Visible = isSpectating end
end

-- Improved Stop Spectating function
local function stopSpectating()
    -- Disconnect all spectate connections
    for _, connection in pairs(Player.spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    Player.spectateConnections = {}
    
    -- Reset camera to local player immediately
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        Workspace.CurrentCamera.CameraSubject = player.Character.Humanoid
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    else
        Workspace.CurrentCamera.CameraSubject = humanoid
    end
    
    -- Clear selected player
    Player.selectedPlayer = nil
    Player.currentSpectateIndex = 0
    if SelectedPlayerLabel then
        SelectedPlayerLabel.Text = "SELECTED: NONE"
    end
    
    -- Update UI
    updateSpectateButtons()
    
    -- Reset all player selection buttons
    if PlayerListScrollFrame then
        for _, item in pairs(PlayerListScrollFrame:GetChildren()) do
            if item:IsA("Frame") and item:FindFirstChild("SelectButton") then
                item.SelectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                item.SelectButton.Text = "SELECT PLAYER"
            end
        end
    end
    
    print("Stopped spectating - Camera reset to local player")
end

-- Improved Spectate Player function
local function spectatePlayer(targetPlayer)
    -- Clean up existing connections
    for _, connection in pairs(Player.spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    Player.spectateConnections = {}
    
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
        -- Set camera immediately
        Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        
        Player.selectedPlayer = targetPlayer
        Player.currentSpectateIndex = table.find(Player.spectatePlayerList, targetPlayer) or 0
        if SelectedPlayerLabel then
            SelectedPlayerLabel.Text = "SELECTED: " .. targetPlayer.Name:upper()
        end
        print("Spectating: " .. targetPlayer.Name)
        
        -- Connect to detect player death
        local targetHumanoid = targetPlayer.Character.Humanoid
        Player.spectateConnections.died = targetHumanoid.Died:Connect(function()
            print("Spectated player died, waiting for respawn")
            -- Wait for respawn and continue spectating
            local newCharacter = targetPlayer.CharacterAdded:Wait()
            local newHumanoid = newCharacter:WaitForChild("Humanoid", 5)
            if newHumanoid and Player.selectedPlayer == targetPlayer then
                Workspace.CurrentCamera.CameraSubject = newHumanoid
                Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                print("Spectated player respawned, continuing spectate")
            end
        end)
        
        -- Connect to detect character added (for initial or subsequent respawns)
        Player.spectateConnections.characterAdded = targetPlayer.CharacterAdded:Connect(function(newCharacter)
            local newHumanoid = newCharacter:WaitForChild("Humanoid", 5)
            if newHumanoid and Player.selectedPlayer == targetPlayer then
                Workspace.CurrentCamera.CameraSubject = newHumanoid
                Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                print("Spectated player character added, continuing spectate")
            end
        end)
        
        -- Update PlayerListFrame buttons to reflect selection
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
    if not PlayerListScrollFrame then return end
    
    -- Clear existing items
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
        print("Player List Updated: No other players found")
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
                playerItem.Size = UDim2.new(1, -5, 0, 90)
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
                
                -- Connect button events
                selectButton.MouseButton1Click:Connect(function()
                    Player.selectedPlayer = p
                    Player.currentSpectateIndex = table.find(Player.spectatePlayerList, p) or 0
                    if SelectedPlayerLabel then
                        SelectedPlayerLabel.Text = "SELECTED: " .. p.Name:upper()
                    end
                    
                    -- Update UI
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
                
                -- Add hover effects
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
            end
        end
    end
    
    -- Preserve selectedPlayer and update currentSpectateIndex
    if previousSelectedPlayer then
        Player.selectedPlayer = previousSelectedPlayer
        Player.currentSpectateIndex = table.find(Player.spectatePlayerList, Player.selectedPlayer) or 0
        if Player.currentSpectateIndex == 0 and Player.selectedPlayer then
            -- If selectedPlayer is no longer valid, stop spectating
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
    
    -- Update canvas size
    if PlayerListLayout then
        spawn(function()
            wait(0.1)
            local contentSize = PlayerListLayout.AbsoluteContentSize
            PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(contentSize.Y + 10, 30))
        end)
    end
    
    print("Player List Updated: " .. playerCount .. " players listed")
    updateSpectateButtons()
end

-- Improved Teleport to Spectated Player
local function teleportToSpectatedPlayer()
    if Player.selectedPlayer and Player.selectedPlayer.Character and Player.selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and Player.rootPart then
        local targetPosition = Player.selectedPlayer.Character.HumanoidRootPart.CFrame
        Player.rootPart.CFrame = targetPosition * CFrame.new(0, 0, 3)
        print("Teleported to spectated player: " .. Player.selectedPlayer.Name)
    else
        print("Cannot teleport: No valid spectated player or missing rootPart")
        if not Player.selectedPlayer then
            print("Debug: No player selected")
        elseif not Player.selectedPlayer.Character then
            print("Debug: Selected player has no character")
        elseif not Player.selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
            print("Debug: Selected player has no HumanoidRootPart")
        elseif not Player.rootPart then
            print("Debug: Local player rootPart is nil")
        end
    end
end

-- Function to create buttons for Player features
function Player.loadPlayerButtons(createButton, createToggleButton)
    print("Loading Player buttons...")
    createButton("Select Player", showPlayerSelection)
    createToggleButton("God Mode", toggleGodMode)
    createToggleButton("Anti AFK", toggleAntiAFK)
    createToggleButton("Freeze Players", toggleFreezePlayers)
    print("Player buttons loaded successfully")
end

-- Function to reset Player states (called when character respawns)
function Player.resetStates()
    print("Resetting Player states...")
    Player.godModeEnabled = false
    Player.antiAFKEnabled = false
    Player.freezeEnabled = false
    
    toggleGodMode(false)
    toggleAntiAFK(false)
    toggleFreezePlayers(false)
    stopSpectating()
    print("Player states reset successfully")
end

-- Function to initialize UI elements
local function initUI()
    if not ScreenGui then
        warn("ScreenGui not available for Player UI initialization")
        return
    end
    
    print("Initializing Player UI...")
    
    -- Player Selection Frame
    PlayerListFrame = Instance.new("Frame")
    PlayerListFrame.Name = "PlayerListFrame"
    PlayerListFrame.Parent = ScreenGui
    PlayerListFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    PlayerListFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    PlayerListFrame.BorderSizePixel = 1
    PlayerListFrame.Position = UDim2.new(0.5, -150, 0.2, 0)
    PlayerListFrame.Size = UDim2.new(0, 300, 0, 350)
    PlayerListFrame.Visible = false
    PlayerListFrame.Active = true
    PlayerListFrame.Draggable = true

    -- Player List Title
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

    -- Close Button for Player List
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

    -- Selected Player Display
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

    -- Player List ScrollFrame
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

    -- Player List Layout
    PlayerListLayout = Instance.new("UIListLayout")
    PlayerListLayout.Parent = PlayerListScrollFrame
    PlayerListLayout.Padding = UDim.new(0, 2)
    PlayerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PlayerListLayout.FillDirection = Enum.FillDirection.Vertical

    -- Spectate Buttons
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

    -- Connect Spectate Button Events
    NextSpectateButton.MouseButton1Click:Connect(spectateNextPlayer)
    PrevSpectateButton.MouseButton1Click:Connect(spectatePrevPlayer)
    StopSpectateButton.MouseButton1Click:Connect(stopSpectating)
    TeleportSpectateButton.MouseButton1Click:Connect(teleportToSpectatedPlayer)

    -- Hover effects for spectate buttons
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

    -- Connect Close Button
    ClosePlayerListButton.MouseButton1Click:Connect(function()
        Player.playerListVisible = false
        PlayerListFrame.Visible = false
    end)
    
    print("Player UI initialized successfully")
end

-- Function to set dependencies and initialize UI
function Player.init(deps)
    print("Initializing Player module...")
    
    -- Set dependencies
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
    
    -- Validate critical dependencies
    if not Players or not RunService or not Workspace or not ScreenGui or not player then
        warn("Critical dependencies missing for Player module!")
        return false
    end
    
    -- Initialize state variables
    Player.godModeEnabled = false
    Player.antiAFKEnabled = false
    Player.freezeEnabled = false
    Player.selectedPlayer = nil
    Player.spectatePlayerList = {}
    Player.currentSpectateIndex = 0
    Player.spectateConnections = {}
    Player.playerListVisible = false
    Player.frozenPlayerPositions = {}
    Player.playerConnections = {}
    
    -- Initialize UI elements
    pcall(initUI)
    
    print("Player module initialized successfully")
    return true
end

-- Function to handle player added/removed events
function Player.setupPlayerEvents()
    if not Players then
        warn("Players service not available for setupPlayerEvents")
        return
    end
    
    print("Setting up Player events...")
    
    -- Handle when a new player joins
    Players.PlayerAdded:Connect(function(p)
        if p ~= player then
            print("New player joined: " .. p.Name)
            -- Setup monitoring for new player immediately
            setupPlayerMonitoring(p)
        end
        Player.updatePlayerList()
    end)

    -- Handle when a player leaves
    Players.PlayerRemoving:Connect(function(p)
        if p == Player.selectedPlayer then
            stopSpectating()
        end
        
        -- Clean up monitoring for leaving player
        cleanupPlayerMonitoring(p)
        Player.updatePlayerList()
        
        print("Player left: " .. p.Name)
    end)

    -- Setup monitoring for all current players
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            setupPlayerMonitoring(p)
        end
    end

    -- Periodic player list update
    spawn(function()
        while true do
            Player.updatePlayerList()
            wait(5)
        end
    end)
    
    print("Player events set up successfully")
end

-- Function to cleanup all Player resources
function Player.cleanup()
    print("Cleaning up Player module...")
    
    -- Stop all features
    Player.resetStates()
    
    -- Clean up all player monitoring
    for targetPlayer, _ in pairs(Player.playerConnections) do
        cleanupPlayerMonitoring(targetPlayer)
    end
    
    -- Clean up UI elements
    if PlayerListFrame then
        PlayerListFrame:Destroy()
        PlayerListFrame = nil
    end
    
    if NextSpectateButton then NextSpectateButton:Destroy() NextSpectateButton = nil end
    if PrevSpectateButton then PrevSpectateButton:Destroy() PrevSpectateButton = nil end
    if StopSpectateButton then StopSpectateButton:Destroy() StopSpectateButton = nil end
    if TeleportSpectateButton then TeleportSpectateButton:Destroy() TeleportSpectateButton = nil end
    
    print("Player module cleaned up successfully")
end

return Player    end
end

-- Anti AFK
local function toggleAntiAFK(enabled)
    Player.antiAFKEnabled = enabled
    if enabled then
        connections.antiafk = Players.LocalPlayer.Idled:Connect(function()
            if Player.antiAFKEnabled then
                game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
                game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            end
        end)
    else
        if connections.antiafk then
            connections.antiafk:Disconnect()
            connections.antiafk = nil
        end
    end
end

-- Helper function to freeze a single player
local function freezePlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then return end
    
    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = targetPlayer.Character.HumanoidRootPart
        
        -- Store original state if not already stored
        if not Player.frozenPlayerPositions[targetPlayer] then
            Player.frozenPlayerPositions[targetPlayer] = {
                cframe = hrp.CFrame,
                anchored = hrp.Anchored,
                velocity = hrp.AssemblyLinearVelocity
            }
        end
        
        -- Apply freeze
        hrp.Anchored = true
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        
        -- Disable humanoid movement
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
        
        -- Restore original state
        hrp.Anchored = frozenData and frozenData.anchored or false
        
        -- Restore humanoid movement
        if targetPlayer.Character:FindFirstChild("Humanoid") then
            local hum = targetPlayer.Character.Humanoid
            hum.PlatformStand = false
            hum.WalkSpeed = 16 -- Default Roblox walkspeed
            hum.JumpPower = 50 -- Default Roblox jump power
        end
        
        print("Unfroze player: " .. targetPlayer.Name)
    end
    
    -- Remove from frozen positions
    Player.frozenPlayerPositions[targetPlayer] = nil
end

-- Setup monitoring for a specific player
local function setupPlayerMonitoring(targetPlayer)
    if targetPlayer == player or Player.playerConnections[targetPlayer] then return end
    
    Player.playerConnections[targetPlayer] = {}
    
    -- Monitor character spawning
    Player.playerConnections[targetPlayer].characterAdded = targetPlayer.CharacterAdded:Connect(function(character)
        if not Player.freezeEnabled then return end
        
        -- Wait for HumanoidRootPart to load
        local hrp = character:WaitForChild("HumanoidRootPart", 5)
        if hrp then
            -- Small delay to ensure character is fully loaded
            wait(0.5)
            freezePlayer(targetPlayer)
            print("Auto-froze respawned player: " .. targetPlayer.Name)
        end
    end)
    
    -- If player already has character, freeze immediately if freeze is enabled
    if Player.freezeEnabled and targetPlayer.Character then
        freezePlayer(targetPlayer)
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
    
    -- Remove from frozen positions
    Player.frozenPlayerPositions[targetPlayer] = nil
end

-- Improved Freeze Players function with auto-freeze for new players
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
        
        -- Use Heartbeat for consistent position enforcement
        connections.freeze = RunService.Heartbeat:Connect(function()
            if Player.freezeEnabled then
                for targetPlayer, frozenData in pairs(Player.frozenPlayerPositions) do
                    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = targetPlayer.Character.HumanoidRootPart
                        
                        -- Force position and stop all movement
                        hrp.CFrame = frozenData.cframe
                        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        hrp.Anchored = true
                        
                        -- Keep humanoid disabled
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
        
        print("Players frozen successfully - Auto-freeze enabled for new players")
    else
        print("Deactivating freeze players...")
        
        -- Stop the freeze loop
        if connections.freeze then
            connections.freeze:Disconnect()
            connections.freeze = nil
        end
        
        -- Unfreeze all players
        for targetPlayer, _ in pairs(Player.frozenPlayerPositions) do
            unfreezePlayer(targetPlayer)
        end
        
        -- Clean up all player monitoring
        for targetPlayer, _ in pairs(Player.playerConnections) do
            cleanupPlayerMonitoring(targetPlayer)
        end
        
        Player.frozenPlayerPositions = {}
        Player.playerConnections = {}
        
        print("Players unfrozen successfully - Auto-freeze disabled")
    end
end

-- Show Player Selection UI
local function showPlayerSelection()
    Player.playerListVisible = true
    PlayerListFrame.Visible = true
    Player.updatePlayerList()
end

-- Update Spectate Buttons Visibility
local function updateSpectateButtons()
    local isSpectating = Player.selectedPlayer ~= nil
    NextSpectateButton.Visible = isSpectating
    PrevSpectateButton.Visible = isSpectating
    StopSpectateButton.Visible = isSpectating
    TeleportSpectateButton.Visible = isSpectating
end

-- Improved Stop Spectating function
local function stopSpectating()
    -- Disconnect all spectate connections
    for _, connection in pairs(Player.spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    Player.spectateConnections = {}
    
    -- Reset camera to local player immediately
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        Workspace.CurrentCamera.CameraSubject = player.Character.Humanoid
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    else
        Workspace.CurrentCamera.CameraSubject = humanoid
    end
    
    -- Clear selected player
    Player.selectedPlayer = nil
    Player.currentSpectateIndex = 0
    SelectedPlayerLabel.Text = "SELECTED: NONE"
    
    -- Update UI
    updateSpectateButtons()
    
    -- Reset all player selection buttons
    for _, item in pairs(PlayerListScrollFrame:GetChildren()) do
        if item:IsA("Frame") and item:FindFirstChild("SelectButton") then
            item.SelectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            item.SelectButton.Text = "SELECT PLAYER"
        end
    end
    
    print("Stopped spectating - Camera reset to local player")
end

-- Improved Spectate Player function
local function spectatePlayer(targetPlayer)
    -- Clean up existing connections
    for _, connection in pairs(Player.spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    Player.spectateConnections = {}
    
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
        -- Set camera immediately
        Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        
        Player.selectedPlayer = targetPlayer
        Player.currentSpectateIndex = table.find(Player.spectatePlayerList, targetPlayer) or 0
        SelectedPlayerLabel.Text = "SELECTED: " .. targetPlayer.Name:upper()
        print("Spectating: " .. targetPlayer.Name)
        
        -- Connect to detect player death
        local targetHumanoid = targetPlayer.Character.Humanoid
        Player.spectateConnections.died = targetHumanoid.Died:Connect(function()
            print("Spectated player died, waiting for respawn")
            -- Wait for respawn and continue spectating
            local newCharacter = targetPlayer.CharacterAdded:Wait()
            local newHumanoid = newCharacter:WaitForChild("Humanoid", 5)
            if newHumanoid and Player.selectedPlayer == targetPlayer then
                Workspace.CurrentCamera.CameraSubject = newHumanoid
                Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                print("Spectated player respawned, continuing spectate")
            end
        end)
        
        -- Connect to detect character added (for initial or subsequent respawns)
        Player.spectateConnections.characterAdded = targetPlayer.CharacterAdded:Connect(function(newCharacter)
            local newHumanoid = newCharacter:WaitForChild("Humanoid", 5)
            if newHumanoid and Player.selectedPlayer == targetPlayer then
                Workspace.CurrentCamera.CameraSubject = newHumanoid
                Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                print("Spectated player character added, continuing spectate")
            end
        end)
        
        -- Update PlayerListFrame buttons to reflect selection
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
        print("Player List Updated: No other players found")
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
                playerItem.Size = UDim2.new(1, -5, 0, 90)
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
                
                selectButton.MouseButton1Click:Connect(function()
                    Player.selectedPlayer = p
                    Player.currentSpectateIndex = table.find(Player.spectatePlayerList, p) or 0
                    SelectedPlayerLabel.Text = "SELECTED: " .. p.Name:upper()
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
            end
        end
    end
    
    -- Preserve selectedPlayer and update currentSpectateIndex
    if previousSelectedPlayer then
        Player.selectedPlayer = previousSelectedPlayer
        Player.currentSpectateIndex = table.find(Player.spectatePlayerList, Player.selectedPlayer) or 0
        if Player.currentSpectateIndex == 0 and Player.selectedPlayer then
            -- If selectedPlayer is no longer valid, stop spectating
            if not (Player.selectedPlayer.Character and Player.selectedPlayer.Character:FindFirstChild("Humanoid")) then
                stopSpectating()
            end
        end
        SelectedPlayerLabel.Text = Player.selectedPlayer and "SELECTED: " .. Player.selectedPlayer.Name:upper() or "SELECTED: NONE"
    else
        Player.currentSpectateIndex = 0
    end
    
    wait(0.1)
    local contentSize = PlayerListLayout.AbsoluteContentSize
    PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(contentSize.Y + 10, 30))
    print("Player List Updated: " .. playerCount .. " players listed")
    updateSpectateButtons()
end

-- Improved Teleport to Spectated Player
local function teleportToSpectatedPlayer()
    if Player.selectedPlayer and Player.selectedPlayer.Character and Player.selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and Player.rootPart then
        local targetPosition = Player.selectedPlayer.Character.HumanoidRootPart.CFrame
        Player.rootPart.CFrame = targetPosition * CFrame.new(0, 0, 3)
        print("Teleported to spectated player: " .. Player.selectedPlayer.Name)
    else
        print("Cannot teleport: No valid spectated player or missing rootPart")
        if not Player.selectedPlayer then
            print("Debug: No player selected")
        elseif not Player.selectedPlayer.Character then
            print("Debug: Selected player has no character")
        elseif not Player.selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
            print("Debug: Selected player has no HumanoidRootPart")
        elseif not Player.rootPart then
            print("Debug: Local player rootPart is nil")
        end
    end
end

-- Function to create buttons for Player features
function Player.loadPlayerButtons(createButton, createToggleButton)
    createButton("Select Player", showPlayerSelection)
    createToggleButton("God Mode", toggleGodMode)
    createToggleButton("Anti AFK", toggleAntiAFK)
    createToggleButton("Freeze Players", toggleFreezePlayers)
end

-- Function to reset Player states (called when character respawns)
function Player.resetStates()
    Player.godModeEnabled = false
    Player.antiAFKEnabled = false
    Player.freezeEnabled = false
    
    toggleGodMode(false)
    toggleAntiAFK(false)
    toggleFreezePlayers(false)
    stopSpectating()
end

-- Function to initialize UI elements
local function initUI()
    -- Player Selection Frame
    PlayerListFrame = Instance.new("Frame")
    PlayerListFrame.Name = "PlayerListFrame"
    PlayerListFrame.Parent = ScreenGui
    PlayerListFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    PlayerListFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    PlayerListFrame.BorderSizePixel = 1
    PlayerListFrame.Position = UDim2.new(0.5, -150, 0.2, 0)
    PlayerListFrame.Size = UDim2.new(0, 300, 0, 350)
    PlayerListFrame.Visible = false
    PlayerListFrame.Active = true
    PlayerListFrame.Draggable = true

    -- Player List Title
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

    -- Close Button for Player List
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

    -- Selected Player Display
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

    -- Player List ScrollFrame
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

    -- Player List Layout
    PlayerListLayout = Instance.new("UIListLayout")
    PlayerListLayout.Parent = PlayerListScrollFrame
    PlayerListLayout.Padding = UDim.new(0, 2)
    PlayerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PlayerListLayout.FillDirection = Enum.FillDirection.Vertical

    -- Spectate Buttons
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

    -- Connect Spectate Button Events
    NextSpectateButton.MouseButton1Click:Connect(spectateNextPlayer)
    PrevSpectateButton.MouseButton1Click:Connect(spectatePrevPlayer)
    StopSpectateButton.MouseButton1Click:Connect(stopSpectating)
    TeleportSpectateButton.MouseButton1Click:Connect(teleportToSpectatedPlayer)

    -- Hover effects for spectate buttons
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

    -- Connect Close Button
    ClosePlayerListButton.MouseButton1Click:Connect(function()
        Player.playerListVisible = false
        PlayerListFrame.Visible = false
    end)
end

-- Function to set dependencies and initialize UI
function Player.init(deps)
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
    
    -- Initialize state variables
    Player.godModeEnabled = false
    Player.antiAFKEnabled = false
    Player.freezeEnabled = false
    Player.selectedPlayer = nil
    Player.spectatePlayerList = {}
    Player.currentSpectateIndex = 0
    Player.spectateConnections = {}
    Player.playerListVisible = false
    Player.frozenPlayerPositions = {}
    Player.playerConnections = {}
    
    -- Initialize UI elements
    initUI()
end

-- Function to handle player added/removed events
function Player.setupPlayerEvents()
    -- Handle when a new player joins
    Players.PlayerAdded:Connect(function(p)
        if p ~= player then
            print("New player joined: " .. p.Name)
            -- Setup monitoring for new player immediately
            setupPlayerMonitoring(p)
        end
        Player.updatePlayerList()
    end)

    -- Handle when a player leaves
    Players.PlayerRemoving:Connect(function(p)
        if p == Player.selectedPlayer then
            stopSpectating()
        end
        
        -- Clean up monitoring for leaving player
        cleanupPlayerMonitoring(p)
        Player.updatePlayerList()
        
        print("Player left: " .. p.Name)
    end)

    -- Setup monitoring for all current players
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            setupPlayerMonitoring(p)
        end
    end

    -- Periodic player list update
    spawn(function()
        while true do
            Player.updatePlayerList()
            wait(5)
        end
    end)
end

return Playerend

-- Anti AFK
local function toggleAntiAFK(enabled)
    Player.antiAFKEnabled = enabled
    if enabled then
        connections.antiafk = Players.LocalPlayer.Idled:Connect(function()
            if Player.antiAFKEnabled then
                game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
                game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            end
        end)
    else
        if connections.antiafk then
            connections.antiafk:Disconnect()
            connections.antiafk = nil
        end
    end
end

-- Improved Freeze Players function
local function toggleFreezePlayers(enabled)
    Player.freezeEnabled = enabled
    if enabled then
        Player.frozenPlayerPositions = {}
        
        -- Store initial positions for all players
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = p.Character.HumanoidRootPart
                Player.frozenPlayerPositions[p] = {
                    cframe = hrp.CFrame,
                    anchored = hrp.Anchored,
                    velocity = hrp.AssemblyLinearVelocity
                }
                
                -- Anchor the part and stop all movement
                hrp.Anchored = true
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                
                -- Disable humanoid movement
                if p.Character:FindFirstChild("Humanoid") then
                    p.Character.Humanoid.PlatformStand = true
                    p.Character.Humanoid.Sit = false
                    p.Character.Humanoid.WalkSpeed = 0
                    p.Character.Humanoid.JumpPower = 0
                end
            end
        end
        
        -- Use Heartbeat for more consistent updates
        connections.freeze = RunService.Heartbeat:Connect(function()
            if Player.freezeEnabled then
                for targetPlayer, frozenData in pairs(Player.frozenPlayerPositions) do
                    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = targetPlayer.Character.HumanoidRootPart
                        
                        -- Force position and stop all movement
                        hrp.CFrame = frozenData.cframe
                        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        hrp.Anchored = true
                        
                        -- Keep humanoid disabled
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
        -- Restore all players to normal state
        if connections.freeze then
            connections.freeze:Disconnect()
            connections.freeze = nil
        end
        
        for targetPlayer, frozenData in pairs(Player.frozenPlayerPositions) do
            if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = targetPlayer.Character.HumanoidRootPart
                hrp.Anchored = frozenData.anchored or false
                
                -- Restore humanoid movement
                if targetPlayer.Character:FindFirstChild("Humanoid") then
                    local hum = targetPlayer.Character.Humanoid
                    hum.PlatformStand = false
                    hum.WalkSpeed = 16 -- Default Roblox walkspeed
                    hum.JumpPower = 50 -- Default Roblox jump power
                end
            end
        end
        
        Player.frozenPlayerPositions = {}
        print("Players unfrozen successfully")
    end
end

-- Show Player Selection UI
local function showPlayerSelection()
    Player.playerListVisible = true
    PlayerListFrame.Visible = true
    Player.updatePlayerList()
end

-- Update Spectate Buttons Visibility
local function updateSpectateButtons()
    local isSpectating = Player.selectedPlayer ~= nil
    NextSpectateButton.Visible = isSpectating
    PrevSpectateButton.Visible = isSpectating
    StopSpectateButton.Visible = isSpectating
    TeleportSpectateButton.Visible = isSpectating
end

-- Improved Stop Spectating function
local function stopSpectating()
    -- Disconnect all spectate connections
    for _, connection in pairs(Player.spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    Player.spectateConnections = {}
    
    -- Reset camera to local player immediately
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        Workspace.CurrentCamera.CameraSubject = player.Character.Humanoid
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    else
        Workspace.CurrentCamera.CameraSubject = humanoid
    end
    
    -- Clear selected player
    Player.selectedPlayer = nil
    Player.currentSpectateIndex = 0
    SelectedPlayerLabel.Text = "SELECTED: NONE"
    
    -- Update UI
    updateSpectateButtons()
    
    -- Reset all player selection buttons
    for _, item in pairs(PlayerListScrollFrame:GetChildren()) do
        if item:IsA("Frame") and item:FindFirstChild("SelectButton") then
            item.SelectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            item.SelectButton.Text = "SELECT PLAYER"
        end
    end
    
    print("Stopped spectating - Camera reset to local player")
end

-- Improved Spectate Player function
local function spectatePlayer(targetPlayer)
    -- Clean up existing connections
    for _, connection in pairs(Player.spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    Player.spectateConnections = {}
    
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
        -- Set camera immediately
        Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        
        Player.selectedPlayer = targetPlayer
        Player.currentSpectateIndex = table.find(Player.spectatePlayerList, targetPlayer) or 0
        SelectedPlayerLabel.Text = "SELECTED: " .. targetPlayer.Name:upper()
        print("Spectating: " .. targetPlayer.Name)
        
        -- Connect to detect player death
        local targetHumanoid = targetPlayer.Character.Humanoid
        Player.spectateConnections.died = targetHumanoid.Died:Connect(function()
            print("Spectated player died, waiting for respawn")
            -- Wait for respawn and continue spectating
            local newCharacter = targetPlayer.CharacterAdded:Wait()
            local newHumanoid = newCharacter:WaitForChild("Humanoid", 5)
            if newHumanoid and Player.selectedPlayer == targetPlayer then
                Workspace.CurrentCamera.CameraSubject = newHumanoid
                Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                print("Spectated player respawned, continuing spectate")
            end
        end)
        
        -- Connect to detect character added (for initial or subsequent respawns)
        Player.spectateConnections.characterAdded = targetPlayer.CharacterAdded:Connect(function(newCharacter)
            local newHumanoid = newCharacter:WaitForChild("Humanoid", 5)
            if newHumanoid and Player.selectedPlayer == targetPlayer then
                Workspace.CurrentCamera.CameraSubject = newHumanoid
                Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                print("Spectated player character added, continuing spectate")
            end
        end)
        
        -- Update PlayerListFrame buttons to reflect selection
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
        print("Player List Updated: No other players found")
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
                playerItem.Size = UDim2.new(1, -5, 0, 90)
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
                
                selectButton.MouseButton1Click:Connect(function()
                    Player.selectedPlayer = p
                    Player.currentSpectateIndex = table.find(Player.spectatePlayerList, p) or 0
                    SelectedPlayerLabel.Text = "SELECTED: " .. p.Name:upper()
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
            end
        end
    end
    
    -- Update frozen positions when player list updates (untuk freeze yang sudah aktif)
    if Player.freezeEnabled then
        local newFrozenPositions = {}
        for _, p in pairs(players) do
            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                if Player.frozenPlayerPositions[p] then
                    -- Gunakan posisi yang sudah tersimpan
                    newFrozenPositions[p] = Player.frozenPlayerPositions[p]
                else
                    -- Player baru, freeze di posisi saat ini
                    local hrp = p.Character.HumanoidRootPart
                    newFrozenPositions[p] = {
                        cframe = hrp.CFrame,
                        anchored = hrp.Anchored,
                        velocity = hrp.AssemblyLinearVelocity
                    }
                    
                    -- Apply freeze immediately for new players
                    hrp.Anchored = true
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    
                    if p.Character:FindFirstChild("Humanoid") then
                        p.Character.Humanoid.PlatformStand = true
                        p.Character.Humanoid.WalkSpeed = 0
                        p.Character.Humanoid.JumpPower = 0
                    end
                end
            end
        end
        Player.frozenPlayerPositions = newFrozenPositions
    end
    
    -- Preserve selectedPlayer and update currentSpectateIndex
    if previousSelectedPlayer then
        Player.selectedPlayer = previousSelectedPlayer
        Player.currentSpectateIndex = table.find(Player.spectatePlayerList, Player.selectedPlayer) or 0
        if Player.currentSpectateIndex == 0 and Player.selectedPlayer then
            -- If selectedPlayer is no longer valid, stop spectating
            if not (Player.selectedPlayer.Character and Player.selectedPlayer.Character:FindFirstChild("Humanoid")) then
                stopSpectating()
            end
        end
        SelectedPlayerLabel.Text = Player.selectedPlayer and "SELECTED: " .. Player.selectedPlayer.Name:upper() or "SELECTED: NONE"
    else
        Player.currentSpectateIndex = 0
    end
    
    wait(0.1)
    local contentSize = PlayerListLayout.AbsoluteContentSize
    PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(contentSize.Y + 10, 30))
    print("Player List Updated: " .. playerCount .. " players listed")
    updateSpectateButtons()
end

-- Improved Teleport to Spectated Player
local function teleportToSpectatedPlayer()
    if Player.selectedPlayer and Player.selectedPlayer.Character and Player.selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and Player.rootPart then
        local targetPosition = Player.selectedPlayer.Character.HumanoidRootPart.CFrame
        Player.rootPart.CFrame = targetPosition * CFrame.new(0, 0, 3)
        print("Teleported to spectated player: " .. Player.selectedPlayer.Name)
    else
        print("Cannot teleport: No valid spectated player or missing rootPart")
        if not Player.selectedPlayer then
            print("Debug: No player selected")
        elseif not Player.selectedPlayer.Character then
            print("Debug: Selected player has no character")
        elseif not Player.selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
            print("Debug: Selected player has no HumanoidRootPart")
        elseif not Player.rootPart then
            print("Debug: Local player rootPart is nil")
        end
    end
end

-- Function to create buttons for Player features
function Player.loadPlayerButtons(createButton, createToggleButton)
    createButton("Select Player", showPlayerSelection)
    createToggleButton("God Mode", toggleGodMode)
    createToggleButton("Anti AFK", toggleAntiAFK)
    createToggleButton("Freeze Players", toggleFreezePlayers)
end

-- Function to reset Player states (called when character respawns)
function Player.resetStates()
    Player.godModeEnabled = false
    Player.antiAFKEnabled = false
    Player.freezeEnabled = false
    
    toggleGodMode(false)
    toggleAntiAFK(false)
    toggleFreezePlayers(false)
    stopSpectating()
end

-- Function to initialize UI elements
local function initUI()
    -- Player Selection Frame
    PlayerListFrame = Instance.new("Frame")
    PlayerListFrame.Name = "PlayerListFrame"
    PlayerListFrame.Parent = ScreenGui
    PlayerListFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    PlayerListFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    PlayerListFrame.BorderSizePixel = 1
    PlayerListFrame.Position = UDim2.new(0.5, -150, 0.2, 0)
    PlayerListFrame.Size = UDim2.new(0, 300, 0, 350)
    PlayerListFrame.Visible = false
    PlayerListFrame.Active = true
    PlayerListFrame.Draggable = true

    -- Player List Title
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

    -- Close Button for Player List
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

    -- Selected Player Display
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

    -- Player List ScrollFrame
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

    -- Player List Layout
    PlayerListLayout = Instance.new("UIListLayout")
    PlayerListLayout.Parent = PlayerListScrollFrame
    PlayerListLayout.Padding = UDim.new(0, 2)
    PlayerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PlayerListLayout.FillDirection = Enum.FillDirection.Vertical

    -- Spectate Buttons
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

    -- Connect Spectate Button Events
    NextSpectateButton.MouseButton1Click:Connect(spectateNextPlayer)
    PrevSpectateButton.MouseButton1Click:Connect(spectatePrevPlayer)
    StopSpectateButton.MouseButton1Click:Connect(stopSpectating)
    TeleportSpectateButton.MouseButton1Click:Connect(teleportToSpectatedPlayer)

    -- Hover effects for spectate buttons
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

    -- Connect Close Button
    ClosePlayerListButton.MouseButton1Click:Connect(function()
        Player.playerListVisible = false
        PlayerListFrame.Visible = false
    end)
end

-- Function to set dependencies and initialize UI
function Player.init(deps)
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
    
    -- Initialize state variables
    Player.godModeEnabled = false
    Player.antiAFKEnabled = false
    Player.freezeEnabled = false
    Player.selectedPlayer = nil
    Player.spectatePlayerList = {}
    Player.currentSpectateIndex = 0
    Player.spectateConnections = {}
    Player.playerListVisible = false
    Player.frozenPlayerPositions = {}
    
    -- Initialize UI elements
    initUI()
end

-- Function to handle player added/removed events
function Player.setupPlayerEvents()
    Players.PlayerAdded:Connect(function(p)
        Player.updatePlayerList()
        if Player.freezeEnabled and p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = p.Character.HumanoidRootPart
            Player.frozenPlayerPositions[p] = {
                cframe = hrp.CFrame,
                anchored = hrp.Anchored,
                velocity = hrp.AssemblyLinearVelocity
            }
            
            -- Apply freeze immediately for new players
            hrp.Anchored = true
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            
            if p.Character:FindFirstChild("Humanoid") then
                p.Character.Humanoid.PlatformStand = true
                p.Character.Humanoid.WalkSpeed = 0
                p.Character.Humanoid.JumpPower = 0
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(p)
        if p == Player.selectedPlayer then
            stopSpectating()
        end
        Player.frozenPlayerPositions[p] = nil
        Player.updatePlayerList()
    end)

    -- Periodic player list update
    spawn(function()
        while true do
            Player.updatePlayerList()
            wait(5)
        end
    end)
end

return Player
