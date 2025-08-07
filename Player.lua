local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local PlayerModule = {}
PlayerModule.godModeEnabled = false
PlayerModule.antiAFKEnabled = false
PlayerModule.selectedPlayer = nil
PlayerModule.spectatePlayerList = {}
PlayerModule.currentSpectateIndex = 0
PlayerModule.spectateConnections = {}
PlayerModule.playerListVisible = false
local connections = {}

-- God Mode
function PlayerModule.toggleGodMode(enabled)
    PlayerModule.godModeEnabled = enabled
    if enabled then
        connections.godmode = humanoid.HealthChanged:Connect(function()
            if PlayerModule.godModeEnabled then
                humanoid.Health = humanoid.MaxHealth
            end
        end)
    else
        if connections.godmode then
            connections.godmode:Disconnect()
        end
    end
end

-- Anti AFK
function PlayerModule.toggleAntiAFK(enabled)
    PlayerModule.antiAFKEnabled = enabled
    if enabled then
        connections.antiafk = Players.LocalPlayer.Idled:Connect(function()
            if PlayerModule.antiAFKEnabled then
                VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
                VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            end
        end)
    else
        if connections.antiafk then
            connections.antiafk:Disconnect()
        end
    end
end

-- Player Selection
function PlayerModule.showPlayerSelection()
    PlayerModule.playerListVisible = true
    if PlayerModule.PlayerListFrame then
        PlayerModule.PlayerListFrame.Visible = true
        PlayerModule.updatePlayerList()
    end
end

-- Update Spectate Buttons (requires external GUI elements)
function PlayerModule.updateSpectateButtons()
    local isSpectating = PlayerModule.selectedPlayer ~= nil
    if PlayerModule.NextSpectateButton then
        PlayerModule.NextSpectateButton.Visible = isSpectating
    end
    if PlayerModule.PrevSpectateButton then
        PlayerModule.PrevSpectateButton.Visible = isSpectating
    end
    if PlayerModule.StopSpectateButton then
        PlayerModule.StopSpectateButton.Visible = isSpectating
    end
    if PlayerModule.TeleportSpectateButton then
        PlayerModule.TeleportSpectateButton.Visible = isSpectating
    end
end

-- Stop Spectating
function PlayerModule.stopSpectating()
    for _, connection in pairs(PlayerModule.spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    PlayerModule.spectateConnections = {}
    Workspace.CurrentCamera.CameraSubject = humanoid
    PlayerModule.selectedPlayer = nil
    PlayerModule.currentSpectateIndex = 0
    if PlayerModule.SelectedPlayerLabel then
        PlayerModule.SelectedPlayerLabel.Text = "SELECTED: NONE"
    end
    print("Stopped spectating via Stop Spectate button")
    for _, item in pairs(PlayerModule.PlayerListScrollFrame:GetChildren()) do
        if item:IsA("Frame") and item:FindFirstChild("SelectButton") then
            item.SelectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            item.SelectButton.Text = "SELECT PLAYER"
        end
    end
    PlayerModule.updateSpectateButtons()
end

-- Spectate Player
function PlayerModule.spectatePlayer(targetPlayer)
    for _, connection in pairs(PlayerModule.spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    PlayerModule.spectateConnections = {}
    
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
        Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
        PlayerModule.selectedPlayer = targetPlayer
        PlayerModule.currentSpectateIndex = table.find(PlayerModule.spectatePlayerList, targetPlayer) or 0
        if PlayerModule.SelectedPlayerLabel then
            PlayerModule.SelectedPlayerLabel.Text = "SELECTED: " .. targetPlayer.Name:upper()
        end
        print("Spectating: " .. targetPlayer.Name)
        
        -- Connect to detect player death
        local targetHumanoid = targetPlayer.Character.Humanoid
        PlayerModule.spectateConnections.died = targetHumanoid.Died:Connect(function()
            print("Spectated player died, waiting for respawn")
        end)
        
        -- Connect to detect respawn
        PlayerModule.spectateConnections.characterAdded = targetPlayer.CharacterAdded:Connect(function(newCharacter)
            local newHumanoid = newCharacter:WaitForChild("Humanoid", 5)
            if newHumanoid then
                Workspace.CurrentCamera.CameraSubject = newHumanoid
                print("Spectated player respawned, continuing spectate")
            end
        end)
        
        -- Update PlayerListFrame buttons to reflect selection
        for _, item in pairs(PlayerModule.PlayerListScrollFrame:GetChildren()) do
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
        PlayerModule.stopSpectating()
    end
    PlayerModule.updateSpectateButtons()
end

-- Spectate Next Player
function PlayerModule.spectateNextPlayer()
    if #PlayerModule.spectatePlayerList == 0 then
        print("No players to spectate")
        PlayerModule.stopSpectating()
        return
    end
    
    PlayerModule.currentSpectateIndex = PlayerModule.currentSpectateIndex + 1
    if PlayerModule.currentSpectateIndex > #PlayerModule.spectatePlayerList then
        PlayerModule.currentSpectateIndex = 1
    end
    
    local targetPlayer = PlayerModule.spectatePlayerList[PlayerModule.currentSpectateIndex]
    if targetPlayer then
        PlayerModule.spectatePlayer(targetPlayer)
    else
        PlayerModule.stopSpectating()
    end
end

-- Spectate Previous Player
function PlayerModule.spectatePrevPlayer()
    if #PlayerModule.spectatePlayerList == 0 then
        print("No players to spectate")
        PlayerModule.stopSpectating()
        return
    end
    
    PlayerModule.currentSpectateIndex = PlayerModule.currentSpectateIndex - 1
    if PlayerModule.currentSpectateIndex < 1 then
        PlayerModule.currentSpectateIndex = #PlayerModule.spectatePlayerList
    end
    
    local targetPlayer = PlayerModule.spectatePlayerList[PlayerModule.currentSpectateIndex]
    if targetPlayer then
        PlayerModule.spectatePlayer(targetPlayer)
    else
        PlayerModule.stopSpectating()
    end
end

-- Teleport to Spectated Player
function PlayerModule.teleportToSpectatedPlayer()
    if PlayerModule.selectedPlayer and PlayerModule.selectedPlayer.Character and PlayerModule.selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and rootPart then
        rootPart.CFrame = PlayerModule.selectedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
        print("Teleported to spectated player: " .. PlayerModule.selectedPlayer.Name)
    else
        print("Cannot teleport: No valid spectated player")
    end
end

-- Update Player List
function PlayerModule.updatePlayerList()
    local PlayerListScrollFrame = PlayerModule.PlayerListScrollFrame
    local PlayerListLayout = PlayerModule.PlayerListLayout
    local SelectedPlayerLabel = PlayerModule.SelectedPlayerLabel

    if not (PlayerListScrollFrame and PlayerListLayout and SelectedPlayerLabel) then
        return
    end

    for _, child in pairs(PlayerListScrollFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    local previousSelectedPlayer = PlayerModule.selectedPlayer
    PlayerModule.spectatePlayerList = {}
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
            if p ~= player and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                playerCount = playerCount + 1
                table.insert(PlayerModule.spectatePlayerList, p)
                
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
                selectButton.BackgroundColor3 = PlayerModule.selectedPlayer == p and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(60, 60, 60)
                selectButton.BorderSizePixel = 0
                selectButton.Position = UDim2.new(0, 5, 0, 30)
                selectButton.Size = UDim2.new(1, -10, 0, 25)
                selectButton.Font = Enum.Font.Gotham
                selectButton.Text = PlayerModule.selectedPlayer == p and "SELECTED" or "SELECT PLAYER"
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
                    PlayerModule.selectedPlayer = p
                    PlayerModule.currentSpectateIndex = table.find(PlayerModule.spectatePlayerList, p) or 0
                    if PlayerModule.SelectedPlayerLabel then
                        PlayerModule.SelectedPlayerLabel.Text = "SELECTED: " .. p.Name:upper()
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
                end)
                
                spectateButton.MouseButton1Click:Connect(function()
                    PlayerModule.currentSpectateIndex = table.find(PlayerModule.spectatePlayerList, p) or 0
                    PlayerModule.spectatePlayer(p)
                end)
                
                stopSpectateButton.MouseButton1Click:Connect(function()
                    PlayerModule.stopSpectating()
                end)
                
                teleportButton.MouseButton1Click:Connect(function()
                    if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and rootPart then
                        rootPart.CFrame = p.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                        print("Teleported to: " .. p.Name)
                    end
                end)
                
                selectButton.MouseEnter:Connect(function()
                    if PlayerModule.selectedPlayer ~= p then
                        selectButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                    end
                end)
                
                selectButton.MouseLeave:Connect(function()
                    if PlayerModule.selectedPlayer ~= p then
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
        PlayerModule.selectedPlayer = previousSelectedPlayer
        PlayerModule.currentSpectateIndex = table.find(PlayerModule.spectatePlayerList, PlayerModule.selectedPlayer) or 0
        if PlayerModule.currentSpectateIndex == 0 and PlayerModule.selectedPlayer then
            -- If selectedPlayer is no longer valid, stop spectating
            if not (PlayerModule.selectedPlayer.Character and PlayerModule.selectedPlayer.Character:FindFirstChild("Humanoid") and PlayerModule.selectedPlayer.Character.Humanoid.Health > 0) then
                PlayerModule.stopSpectating()
            end
        end
        if PlayerModule.SelectedPlayerLabel then
            PlayerModule.SelectedPlayerLabel.Text = PlayerModule.selectedPlayer and "SELECTED: " .. PlayerModule.selectedPlayer.Name:upper() or "SELECTED: NONE"
        end
    else
        PlayerModule.currentSpectateIndex = 0
    end
    
    wait(0.1)
    local contentSize = PlayerListLayout.AbsoluteContentSize
    PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(contentSize.Y + 10, 30))
    print("Player List Updated: " .. playerCount .. " players listed")
    PlayerModule.updateSpectateButtons()
end

-- Cleanup function
function PlayerModule.cleanup()
    PlayerModule.toggleGodMode(false)
    PlayerModule.toggleAntiAFK(false)
    PlayerModule.stopSpectating()
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    for _, connection in pairs(PlayerModule.spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
end

-- Set GUI elements (to be called from mainloader.lua)
function PlayerModule.setGuiElements(elements)
    PlayerModule.PlayerListFrame = elements.PlayerListFrame
    PlayerModule.PlayerListScrollFrame = elements.PlayerListScrollFrame
    PlayerModule.PlayerListLayout = elements.PlayerListLayout
    PlayerModule.SelectedPlayerLabel = elements.SelectedPlayerLabel
    PlayerModule.NextSpectateButton = elements.NextSpectateButton
    PlayerModule.PrevSpectateButton = elements.PrevSpectateButton
    PlayerModule.StopSpectateButton = elements.StopSpectateButton
    PlayerModule.TeleportSpectateButton = elements.TeleportSpectateButton
end

return PlayerModule