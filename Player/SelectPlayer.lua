-- selectplayer.lua
-- Module for handling player selection and spectate functionality in MinimalHackGUI by Fari Noveri

-- Dependencies: These must be passed from player.lua
local Players, RunService, Workspace, humanoid, connections, buttonStates, ScreenGui, player

-- Initialize module
local SelectPlayer = {}

-- Variables for player selection and spectate
SelectPlayer.selectedPlayer = nil
SelectPlayer.spectatePlayerList = {}
SelectPlayer.currentSpectateIndex = 0
SelectPlayer.spectateConnections = {}
SelectPlayer.playerListVisible = false

-- UI Elements
local PlayerListFrame, PlayerListScrollFrame, PlayerListLayout, SelectedPlayerLabel
local ClosePlayerListButton, NextSpectateButton, PrevSpectateButton, StopSpectateButton, TeleportSpectateButton

-- Show Player Selection UI
local function showPlayerSelection()
    SelectPlayer.playerListVisible = true
    if PlayerListFrame then
        PlayerListFrame.Visible = true
        SelectPlayer.updatePlayerList()
    else
        warn("PlayerListFrame not initialized")
    end
end

-- Update Spectate Buttons Visibility
local function updateSpectateButtons()
    local isSpectating = SelectPlayer.selectedPlayer ~= nil
    if NextSpectateButton then NextSpectateButton.Visible = isSpectating end
    if PrevSpectateButton then PrevSpectateButton.Visible = isSpectating end
    if StopSpectateButton then StopSpectateButton.Visible = isSpectating end
    if TeleportSpectateButton then TeleportSpectateButton.Visible = isSpectating end
end

-- Stop Spectating
local function stopSpectating()
    for _, connection in pairs(SelectPlayer.spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    SelectPlayer.spectateConnections = {}
    
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        Workspace.CurrentCamera.CameraSubject = player.Character.Humanoid
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    elseif humanoid then
        Workspace.CurrentCamera.CameraSubject = humanoid
    end
    
    SelectPlayer.selectedPlayer = nil
    SelectPlayer.currentSpectateIndex = 0
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

-- Spectate Player
local function spectatePlayer(targetPlayer)
    for _, connection in pairs(SelectPlayer.spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    SelectPlayer.spectateConnections = {}
    
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
        Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        
        SelectPlayer.selectedPlayer = targetPlayer
        SelectPlayer.currentSpectateIndex = table.find(SelectPlayer.spectatePlayerList, targetPlayer) or 0
        if SelectedPlayerLabel then
            SelectedPlayerLabel.Text = "SELECTED: " .. targetPlayer.Name:upper()
        end
        print("Spectating: " .. targetPlayer.Name)
        
        SelectPlayer.spectateConnections.characterAdded = targetPlayer.CharacterAdded:Connect(function(newCharacter)
            if SelectPlayer.selectedPlayer == targetPlayer then
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
        SelectPlayer.spectateConnections.died = targetHumanoid.Died:Connect(function()
            if SelectPlayer.selectedPlayer == targetPlayer then
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
    if #SelectPlayer.spectatePlayerList == 0 then
        print("No players to spectate")
        stopSpectating()
        return
    end
    
    SelectPlayer.currentSpectateIndex = SelectPlayer.currentSpectateIndex + 1
    if SelectPlayer.currentSpectateIndex > #SelectPlayer.spectatePlayerList then
        SelectPlayer.currentSpectateIndex = 1
    end
    
    local targetPlayer = SelectPlayer.spectatePlayerList[SelectPlayer.currentSpectateIndex]
    if targetPlayer then
        spectatePlayer(targetPlayer)
    else
        stopSpectating()
    end
end

-- Spectate Previous Player
local function spectatePrevPlayer()
    if #SelectPlayer.spectatePlayerList == 0 then
        print("No players to spectate")
        stopSpectating()
        return
    end
    
    SelectPlayer.currentSpectateIndex = SelectPlayer.currentSpectateIndex - 1
    if SelectPlayer.currentSpectateIndex < 1 then
        SelectPlayer.currentSpectateIndex = #SelectPlayer.spectatePlayerList
    end
    
    local targetPlayer = SelectPlayer.spectatePlayerList[SelectPlayer.currentSpectateIndex]
    if targetPlayer then
        spectatePlayer(targetPlayer)
    else
        stopSpectating()
    end
end

-- Teleport to Spectated Player
local function teleportToSpectatedPlayer()
    if SelectPlayer.selectedPlayer and SelectPlayer.selectedPlayer.Character and SelectPlayer.selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and SelectPlayer.rootPart then
        local targetPosition = SelectPlayer.selectedPlayer.Character.HumanoidRootPart.CFrame
        local newPosition = targetPosition * CFrame.new(0, 0, 5)
        SelectPlayer.rootPart.CFrame = newPosition
        print("Teleported to spectated player: " .. SelectPlayer.selectedPlayer.Name)
    else
        print("Cannot teleport: No valid spectated player or missing rootPart")
    end
end

-- Update Player List
function SelectPlayer.updatePlayerList()
    if not PlayerListScrollFrame then
        warn("PlayerListScrollFrame not initialized")
        return
    end
    
    for _, child in pairs(PlayerListScrollFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    local previousSelectedPlayer = SelectPlayer.selectedPlayer
    SelectPlayer.spectatePlayerList = {}
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
                table.insert(SelectPlayer.spectatePlayerList, p)
                
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
                selectButton.BackgroundColor3 = SelectPlayer.selectedPlayer == p and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(60, 60, 60)
                selectButton.BorderSizePixel = 0
                selectButton.Position = UDim2.new(0, 5, 0, 30)
                selectButton.Size = UDim2.new(1, -10, 0, 25)
                selectButton.Font = Enum.Font.Gotham
                selectButton.Text = SelectPlayer.selectedPlayer == p and "SELECTED" or "SELECT PLAYER"
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
                
                -- Button Events
                selectButton.MouseButton1Click:Connect(function()
                    SelectPlayer.selectedPlayer = p
                    SelectPlayer.currentSpectateIndex = table.find(SelectPlayer.spectatePlayerList, p) or 0
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
                    SelectPlayer.currentSpectateIndex = table.find(SelectPlayer.spectatePlayerList, p) or 0
                    spectatePlayer(p)
                end)
                
                stopSpectateButton.MouseButton1Click:Connect(function()
                    stopSpectating()
                end)
                
                teleportButton.MouseButton1Click:Connect(function()
                    if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and SelectPlayer.rootPart then
                        local targetPosition = p.Character.HumanoidRootPart.CFrame
                        local newPosition = targetPosition * CFrame.new(0, 0, 5)
                        SelectPlayer.rootPart.CFrame = newPosition
                        print("Teleported to: " .. p.Name)
                    else
                        print("Cannot teleport: No valid target player or missing rootPart")
                    end
                end)
                
                -- Hover effects for buttons
                selectButton.MouseEnter:Connect(function()
                    if SelectPlayer.selectedPlayer ~= p then
                        selectButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                    end
                end)
                
                selectButton.MouseLeave:Connect(function()
                    if SelectPlayer.selectedPlayer ~= p then
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
    
    if previousSelectedPlayer then
        SelectPlayer.selectedPlayer = previousSelectedPlayer
        SelectPlayer.currentSpectateIndex = table.find(SelectPlayer.spectatePlayerList, SelectPlayer.selectedPlayer) or 0
        if SelectPlayer.currentSpectateIndex == 0 and SelectPlayer.selectedPlayer then
            if not (SelectPlayer.selectedPlayer.Character and SelectPlayer.selectedPlayer.Character:FindFirstChild("Humanoid")) then
                stopSpectating()
            end
        end
        if SelectedPlayerLabel then
            SelectedPlayerLabel.Text = SelectPlayer.selectedPlayer and "SELECTED: " .. SelectPlayer.selectedPlayer.Name:upper() or "SELECTED: NONE"
        end
    else
        SelectPlayer.currentSpectateIndex = 0
    end
    
    task.spawn(function()
        task.wait(0.1)
        local contentSize = PlayerListLayout.AbsoluteContentSize
        PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(contentSize.Y + 10, 30))
    end)
    updateSpectateButtons()
end

-- Initialize UI Elements
local function initUI()
    if not ScreenGui then
        warn("ScreenGui not available for SelectPlayer UI initialization")
        return
    end
    
    print("Initializing SelectPlayer UI...")
    
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
        SelectPlayer.playerListVisible = false
        PlayerListFrame.Visible = false
    end)
    
    print("SelectPlayer UI initialized successfully")
end

-- Initialize Module
function SelectPlayer.init(deps)
    print("Initializing SelectPlayer module...")
    
    Players = deps.Players
    RunService = deps.RunService
    Workspace = deps.Workspace
    humanoid = deps.humanoid
    connections = deps.connections
    buttonStates = deps.buttonStates
    ScreenGui = deps.ScreenGui
    player = deps.player
    SelectPlayer.rootPart = deps.rootPart
    
    if not Players or not RunService or not Workspace or not ScreenGui or not player then
        warn("Critical dependencies missing for SelectPlayer module!")
        return false
    end
    
    SelectPlayer.selectedPlayer = nil
    SelectPlayer.spectatePlayerList = {}
    SelectPlayer.currentSpectateIndex = 0
    SelectPlayer.spectateConnections = {}
    SelectPlayer.playerListVisible = false
    
    pcall(initUI)
    pcall(SelectPlayer.setupPlayerEvents)
    
    print("SelectPlayer module initialized successfully")
    return true
end

-- Setup Player Events
function SelectPlayer.setupPlayerEvents()
    if not Players then
        warn("Players service not available for setupPlayerEvents")
        return
    end
    
    print("Setting up SelectPlayer events...")
    
    Players.PlayerAdded:Connect(function(p)
        if p ~= player then
            print("New player joined: " .. p.Name)
            SelectPlayer.updatePlayerList()
        end
    end)

    Players.PlayerRemoving:Connect(function(p)
        if p == SelectPlayer.selectedPlayer then
            stopSpectating()
        end
        SelectPlayer.updatePlayerList()
        print("Player left: " .. p.Name)
    end)
    
    task.spawn(function()
        while true do
            SelectPlayer.updatePlayerList()
            task.wait(5)
        end
    end)
    
    print("SelectPlayer events set up successfully")
end

-- Load Select Player Button
function SelectPlayer.loadPlayerButtons(createButton)
    print("Loading SelectPlayer button...")
    createButton("Select Player", showPlayerSelection, "Player")
    print("SelectPlayer button loaded successfully")
end

-- Reset SelectPlayer States
function SelectPlayer.resetStates()
    print("Resetting SelectPlayer states...")
    stopSpectating()
    print("SelectPlayer states reset successfully")
end

-- Get Selected Player
function SelectPlayer.getSelectedPlayer()
    return SelectPlayer.selectedPlayer
end

return SelectPlayer
