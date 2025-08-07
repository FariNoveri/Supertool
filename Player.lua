-- Player.lua
-- Player features for MinimalHackGUI by Fari Noveri

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Player feature variables
local godModeEnabled = false
local antiAFKEnabled = false
local noclipEnabled = false
local selectedPlayer = nil
local playerListVisible = false
local spectatePlayerList = {}
local currentSpectateIndex = 0
local spectateConnections = {}
local connections = {}

-- Button states for toggles
local buttonStates = {
    ["God Mode"] = false,
    ["Anti AFK"] = false,
    ["Noclip"] = false
}

-- Setup collision group for Noclip
local function setupCollisionGroup()
    pcall(function()
        PhysicsService:CreateCollisionGroup("Players")
        PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
    end)
end

-- God Mode
local function toggleGodMode(enabled)
    godModeEnabled = enabled
    if enabled then
        connections.godmode = humanoid.HealthChanged:Connect(function()
            if godModeEnabled then
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
local function toggleAntiAFK(enabled)
    antiAFKEnabled = enabled
    if enabled then
        connections.antiafk = Players.LocalPlayer.Idled:Connect(function()
            if antiAFKEnabled then
                game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
                game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            end
        end)
    else
        if connections.antiafk then
            connections.antiafk:Disconnect()
        end
    end
end

-- Noclip
local function toggleNoclip(enabled)
    noclipEnabled = enabled
    if enabled then
        connections.noclip = RunService.Stepped:Connect(function()
            if noclipEnabled and character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                        pcall(function()
                            part.CollisionGroup = "Players"
                        end)
                    end
                end
            end
        end)
    else
        if connections.noclip then
            connections.noclip:Disconnect()
        end
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                    pcall(function()
                        part.CollisionGroup = "Default"
                    end)
                end
            end
        end
    end
end

-- Player Selection UI Creation
local function createPlayerListUI()
    local PlayerListFrame = Instance.new("Frame")
    local PlayerListTitle = Instance.new("TextLabel")
    local ClosePlayerListButton = Instance.new("TextButton")
    local SelectedPlayerLabel = Instance.new("TextLabel")
    local PlayerListScrollFrame = Instance.new("ScrollingFrame")
    local PlayerListLayout = Instance.new("UIListLayout")

    PlayerListFrame.Name = "PlayerListFrame"
    PlayerListFrame.Parent = CoreGui
    PlayerListFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    PlayerListFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    PlayerListFrame.BorderSizePixel = 1
    PlayerListFrame.Position = UDim2.new(0.5, -150, 0.2, 0)
    PlayerListFrame.Size = UDim2.new(0, 300, 0, 350)
    PlayerListFrame.Visible = false
    PlayerListFrame.Active = true
    PlayerListFrame.Draggable = true

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

    ClosePlayerListButton.Name = "CloseButton"
    ClosePlayerListButton.Parent = PlayerListFrame
    ClosePlayerListButton.BackgroundTransparency = 1
    ClosePlayerListButton.Position = UDim2.new(1, -30, 0, 5)
    ClosePlayerListButton.Size = UDim2.new(0, 25, 0, 25)
    ClosePlayerListButton.Font = Enum.Font.GothamBold
    ClosePlayerListButton.Text = "X"
    ClosePlayerListButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClosePlayerListButton.TextSize = 12

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

    PlayerListLayout.Parent = PlayerListScrollFrame
    PlayerListLayout.Padding = UDim.new(0, 2)
    PlayerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PlayerListLayout.FillDirection = Enum.FillDirection.Vertical

    ClosePlayerListButton.MouseButton1Click:Connect(function()
        playerListVisible = false
        PlayerListFrame.Visible = false
    end)

    return PlayerListFrame, SelectedPlayerLabel, PlayerListScrollFrame, PlayerListLayout
end

-- Spectate Buttons Creation
local function createSpectateButtons()
    local NextSpectateButton = Instance.new("TextButton")
    local PrevSpectateButton = Instance.new("TextButton")
    local StopSpectateButton = Instance.new("TextButton")
    local TeleportSpectateButton = Instance.new("TextButton")

    NextSpectateButton.Name = "NextSpectateButton"
    NextSpectateButton.Parent = CoreGui
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

    PrevSpectateButton.Name = "PrevSpectateButton"
    PrevSpectateButton.Parent = CoreGui
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

    StopSpectateButton.Name = "StopSpectateButton"
    StopSpectateButton.Parent = CoreGui
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

    TeleportSpectateButton.Name = "TeleportSpectateButton"
    TeleportSpectateButton.Parent = CoreGui
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

    return NextSpectateButton, PrevSpectateButton, StopSpectateButton, TeleportSpectateButton
end

-- Player Selection and Spectate Functions
local function showPlayerSelection(utils)
    playerListVisible = true
    local PlayerListFrame = CoreGui:FindFirstChild("PlayerListFrame")
    if PlayerListFrame then
        PlayerListFrame.Visible = true
    end
    updatePlayerList(utils)
end

local function updateSpectateButtons()
    local isSpectating = selectedPlayer ~= nil
    local NextSpectateButton = CoreGui:FindFirstChild("NextSpectateButton")
    local PrevSpectateButton = CoreGui:FindFirstChild("PrevSpectateButton")
    local StopSpectateButton = CoreGui:FindFirstChild("StopSpectateButton")
    local TeleportSpectateButton = CoreGui:FindFirstChild("TeleportSpectateButton")
    if NextSpectateButton then NextSpectateButton.Visible = isSpectating end
    if PrevSpectateButton then PrevSpectateButton.Visible = isSpectating end
    if StopSpectateButton then StopSpectateButton.Visible = isSpectating end
    if TeleportSpectateButton then TeleportSpectateButton.Visible = isSpectating end
end

local function stopSpectating(utils)
    for _, connection in pairs(spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    spectateConnections = {}
    workspace.CurrentCamera.CameraSubject = humanoid
    selectedPlayer = nil
    currentSpectateIndex = 0
    local SelectedPlayerLabel = CoreGui:FindFirstChild("PlayerListFrame") and CoreGui.PlayerListFrame:FindFirstChild("SelectedPlayerLabel")
    if SelectedPlayerLabel then
        SelectedPlayerLabel.Text = "SELECTED: NONE"
    end
    if utils.notify then
        utils.notify("Stopped spectating")
    else
        print("Stopped spectating")
    end
    updateSpectateButtons()
    local PlayerListScrollFrame = CoreGui:FindFirstChild("PlayerListFrame") and CoreGui.PlayerListFrame:FindFirstChild("PlayerListScrollFrame")
    if PlayerListScrollFrame then
        for _, item in pairs(PlayerListScrollFrame:GetChildren()) do
            if item:IsA("Frame") and item:FindFirstChild("SelectButton") then
                item.SelectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                item.SelectButton.Text = "SELECT PLAYER"
            end
        end
    end
end

local function spectatePlayer(targetPlayer, utils)
    for _, connection in pairs(spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    spectateConnections = {}
    
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
        workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
        selectedPlayer = targetPlayer
        currentSpectateIndex = table.find(spectatePlayerList, targetPlayer) or 0
        local SelectedPlayerLabel = CoreGui:FindFirstChild("PlayerListFrame") and CoreGui.PlayerListFrame:FindFirstChild("SelectedPlayerLabel")
        if SelectedPlayerLabel then
            SelectedPlayerLabel.Text = "SELECTED: " .. targetPlayer.Name:upper()
        end
        if utils.notify then
            utils.notify("Spectating: " .. targetPlayer.Name)
        else
            print("Spectating: " .. targetPlayer.Name)
        end
        
        local targetHumanoid = targetPlayer.Character.Humanoid
        spectateConnections.died = targetHumanoid.Died:Connect(function()
            if utils.notify then
                utils.notify("Spectated player died, waiting for respawn")
            else
                print("Spectated player died, waiting for respawn")
            end
        end)
        
        spectateConnections.characterAdded = targetPlayer.CharacterAdded:Connect(function(newCharacter)
            local newHumanoid = newCharacter:WaitForChild("Humanoid", 5)
            if newHumanoid then
                workspace.CurrentCamera.CameraSubject = newHumanoid
                if utils.notify then
                    utils.notify("Spectated player respawned, continuing spectate")
                else
                    print("Spectated player respawned, continuing spectate")
                end
            end
        end)
        
        local PlayerListScrollFrame = CoreGui:FindFirstChild("PlayerListFrame") and CoreGui.PlayerListFrame:FindFirstChild("PlayerListScrollFrame")
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
        stopSpectating(utils)
    end
    updateSpectateButtons()
end

local function spectateNextPlayer(utils)
    if #spectatePlayerList == 0 then
        if utils.notify then
            utils.notify("No players to spectate")
        else
            print("No players to spectate")
        end
        stopSpectating(utils)
        return
    end
    
    currentSpectateIndex = currentSpectateIndex + 1
    if currentSpectateIndex > #spectatePlayerList then
        currentSpectateIndex = 1
    end
    
    local targetPlayer = spectatePlayerList[currentSpectateIndex]
    if targetPlayer then
        spectatePlayer(targetPlayer, utils)
    else
        stopSpectating(utils)
    end
end

local function spectatePrevPlayer(utils)
    if #spectatePlayerList == 0 then
        if utils.notify then
            utils.notify("No players to spectate")
        else
            print("No players to spectate")
        end
        stopSpectating(utils)
        return
    end
    
    currentSpectateIndex = currentSpectateIndex - 1
    if currentSpectateIndex < 1 then
        currentSpectateIndex = #spectatePlayerList
    end
    
    local targetPlayer = spectatePlayerList[currentSpectateIndex]
    if targetPlayer then
        spectatePlayer(targetPlayer, utils)
    else
        stopSpectating(utils)
    end
end

local function teleportToSpectatedPlayer(utils)
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and rootPart then
        rootPart.CFrame = selectedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
        if utils.notify then
            utils.notify("Teleported to spectated player: " .. selectedPlayer.Name)
        else
            print("Teleported to spectated player: " .. selectedPlayer.Name)
        end
    else
        if utils.notify then
            utils.notify("Cannot teleport: No valid spectated player")
        else
            print("Cannot teleport: No valid spectated player")
        end
    end
end

local function updatePlayerList(utils)
    local PlayerListScrollFrame = CoreGui:FindFirstChild("PlayerListFrame") and CoreGui.PlayerListFrame:FindFirstChild("PlayerListScrollFrame")
    local PlayerListLayout = PlayerListScrollFrame and PlayerListScrollFrame:FindFirstChild("PlayerListLayout")
    if not PlayerListScrollFrame or not PlayerListLayout then return end

    for _, child in pairs(PlayerListScrollFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    local previousSelectedPlayer = selectedPlayer
    spectatePlayerList = {}
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
        if utils.notify then
            utils.notify("Player List Updated: No other players found")
        else
            print("Player List Updated: No other players found")
        end
    else
        for _, p in pairs(players) do
            if p ~= player and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                playerCount = playerCount + 1
                table.insert(spectatePlayerList, p)
                
                local playerItem = Instance.new("Frame")
                playerItem.Name = p.Name .. "Item"
                playerItem.Parent = PlayerListScrollFrame
                playerItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                playerItem.BorderSizePixel = 0
                playerItem.Size = UDim2.new(1, -5, 0, 60)
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
                selectButton.BackgroundColor3 = selectedPlayer == p and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(60, 60, 60)
                selectButton.BorderSizePixel = 0
                selectButton.Position = UDim2.new(0, 5, 0, 30)
                selectButton.Size = UDim2.new(0, 80, 0, 25)
                selectButton.Font = Enum.Font.Gotham
                selectButton.Text = selectedPlayer == p and "SELECTED" or "SELECT"
                selectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                selectButton.TextSize = 9
                
                local spectateButton = Instance.new("TextButton")
                spectateButton.Name = "SpectateButton"
                spectateButton.Parent = playerItem
                spectateButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
                spectateButton.BorderSizePixel = 0
                spectateButton.Position = UDim2.new(0, 90, 0, 30)
                spectateButton.Size = UDim2.new(0, 80, 0, 25)
                spectateButton.Font = Enum.Font.Gotham
                spectateButton.Text = "SPECTATE"
                spectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                spectateButton.TextSize = 9
                
                local teleportButton = Instance.new("TextButton")
                teleportButton.Name = "TeleportButton"
                teleportButton.Parent = playerItem
                teleportButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
                teleportButton.BorderSizePixel = 0
                teleportButton.Position = UDim2.new(0, 175, 0, 30)
                teleportButton.Size = UDim2.new(1, -180, 0, 25)
                teleportButton.Font = Enum.Font.Gotham
                teleportButton.Text = "TELEPORT"
                teleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                teleportButton.TextSize = 9
                
                selectButton.MouseButton1Click:Connect(function()
                    selectedPlayer = p
                    currentSpectateIndex = table.find(spectatePlayerList, p) or 0
                    local SelectedPlayerLabel = CoreGui:FindFirstChild("PlayerListFrame") and CoreGui.PlayerListFrame:FindFirstChild("SelectedPlayerLabel")
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
                                item.SelectButton.Text = "SELECT"
                            end
                        end
                    end
                    if utils.notify then
                        utils.notify("Selected player: " .. p.Name)
                    else
                        print("Selected player: " .. p.Name)
                    end
                end)
                
                spectateButton.MouseButton1Click:Connect(function()
                    currentSpectateIndex = table.find(spectatePlayerList, p) or 0
                    spectatePlayer(p, utils)
                end)
                
                teleportButton.MouseButton1Click:Connect(function()
                    if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and rootPart then
                        rootPart.CFrame = p.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                        if utils.notify then
                            utils.notify("Teleported to: " .. p.Name)
                        else
                            print("Teleported to: " .. p.Name)
                        end
                    end
                end)
                
                selectButton.MouseEnter:Connect(function()
                    if selectedPlayer ~= p then
                        selectButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                    end
                end)
                
                selectButton.MouseLeave:Connect(function()
                    if selectedPlayer ~= p then
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
            end
        end
    end
    
    if previousSelectedPlayer then
        selectedPlayer = previousSelectedPlayer
        currentSpectateIndex = table.find(spectatePlayerList, selectedPlayer) or 0
        if currentSpectateIndex == 0 and selectedPlayer then
            if not (selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("Humanoid") and selectedPlayer.Character.Humanoid.Health > 0) then
                stopSpectating(utils)
            end
        end
        local SelectedPlayerLabel = CoreGui:FindFirstChild("PlayerListFrame") and CoreGui.PlayerListFrame:FindFirstChild("SelectedPlayerLabel")
        if SelectedPlayerLabel then
            SelectedPlayerLabel.Text = selectedPlayer and "SELECTED: " .. selectedPlayer.Name:upper() or "SELECTED: NONE"
        end
    else
        currentSpectateIndex = 0
    end
    
    task.wait(0.1)
    local contentSize = PlayerListLayout.AbsoluteContentSize
    PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(contentSize.Y + 10, 30))
    if utils.notify then
        utils.notify("Player List Updated: " .. playerCount .. " players listed")
    else
        print("Player List Updated: " .. playerCount .. " players listed")
    end
end

-- Initialize Player UI
local function initializePlayerUI()
    local PlayerListFrame, SelectedPlayerLabel, PlayerListScrollFrame, PlayerListLayout = createPlayerListUI()
    local NextSpectateButton, PrevSpectateButton, StopSpectateButton, TeleportSpectateButton = createSpectateButtons()
    
    NextSpectateButton.MouseButton1Click:Connect(function()
        spectateNextPlayer(utils)
    end)
    PrevSpectateButton.MouseButton1Click:Connect(function()
        spectatePrevPlayer(utils)
    end)
    StopSpectateButton.MouseButton1Click:Connect(function()
        stopSpectating(utils)
    end)
    TeleportSpectateButton.MouseButton1Click:Connect(function()
        teleportToSpectatedPlayer(utils)
    end)
    
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
    
    updatePlayerList({ notify = print }) -- Fallback notify
end

-- Load buttons for mainloader.lua
local function loadButtons(scrollFrame, utils)
    initializePlayerUI()

    utils.createButton("Select Player", function()
        showPlayerSelection(utils)
    end).Parent = scrollFrame

    utils.createToggle("God Mode", buttonStates["God Mode"], function(state)
        buttonStates["God Mode"] = state
        toggleGodMode(state)
        if utils.notify then
            utils.notify("God Mode " .. (state and "enabled" or "disabled"))
        else
            print("God Mode " .. (state and "enabled" or "disabled"))
        end
    end).Parent = scrollFrame

    utils.createToggle("Anti AFK", buttonStates["Anti AFK"], function(state)
        buttonStates["Anti AFK"] = state
        toggleAntiAFK(state)
        if utils.notify then
            utils.notify("Anti AFK " .. (state and "enabled" or "disabled"))
        else
            print("Anti AFK " .. (state and "enabled" or "disabled"))
        end
    end).Parent = scrollFrame

    utils.createToggle("Noclip", buttonStates["Noclip"], function(state)
        buttonStates["Noclip"] = state
        toggleNoclip(state)
        if utils.notify then
            utils.notify("Noclip " .. (state and "enabled" or "disabled"))
        else
            print("Noclip " .. (state and "enabled" or "disabled"))
        end
    end).Parent = scrollFrame
end

-- Handle character reset
local characterConnection
characterConnection = player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    
    godModeEnabled = false
    antiAFKEnabled = false
    noclipEnabled = false
    buttonStates["God Mode"] = false
    buttonStates["Anti AFK"] = false
    buttonStates["Noclip"] = false
    
    toggleGodMode(false)
    toggleAntiAFK(false)
    toggleNoclip(false)
end)

-- Update player list periodically
local updateConnection
updateConnection = RunService.Heartbeat:Connect(function()
    updatePlayerList({ notify = print }) -- Fallback notify
end)

-- Cleanup function
local function cleanup()
    toggleGodMode(false)
    toggleAntiAFK(false)
    toggleNoclip(false)
    stopSpectating({ notify = print }) -- Fallback notify
    
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    for _, connection in pairs(spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    if updateConnection then
        updateConnection:Disconnect()
    end
    if characterConnection then
        characterConnection:Disconnect()
    end
    
    local PlayerListFrame = CoreGui:FindFirstChild("PlayerListFrame")
    if PlayerListFrame then
        PlayerListFrame:Destroy()
    end
    local NextSpectateButton = CoreGui:FindFirstChild("NextSpectateButton")
    local PrevSpectateButton = CoreGui:FindFirstChild("PrevSpectateButton")
    local StopSpectateButton = CoreGui:FindFirstChild("StopSpectateButton")
    local TeleportSpectateButton = CoreGui:FindFirstChild("TeleportSpectateButton")
    if NextSpectateButton then NextSpectateButton:Destroy() end
    if PrevSpectateButton then PrevSpectateButton:Destroy() end
    if StopSpectateButton then StopSpectateButton:Destroy() end
    if TeleportSpectateButton then TeleportSpectateButton:Destroy() end
end

-- Cleanup on script destruction
local function onScriptDestroy()
    cleanup()
end

-- Connect cleanup to GUI destruction
local screenGui = CoreGui:FindFirstChild("MinimalHackGUI")
if screenGui then
    screenGui.AncestryChanged:Connect(function(_, parent)
        if not parent then
            onScriptDestroy()
        end
    end)
end

-- Initialize collision group
setupCollisionGroup()

-- Return module
return {
    loadButtons = loadButtons,
    cleanup = cleanup,
    reset = cleanup,
    getSelectedPlayer = function() return selectedPlayer end
}