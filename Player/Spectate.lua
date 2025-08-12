-- Spectate Player feature for MinimalHackGUI by Fari Noveri

local Spectate = {}

-- Dependencies
local Players, Workspace, ScreenGui, player

-- State
Spectate.selectedPlayer = nil
Spectate.spectatePlayerList = {}
Spectate.currentSpectateIndex = 0
Spectate.connections = {}

-- UI Elements
local NextSpectateButton, PrevSpectateButton, StopSpectateButton, TeleportSpectateButton
local rootPart

-- Get shared data from main Player module
local getSelectedPlayer, updatePlayerList

-- Update Spectate Buttons Visibility
local function updateSpectateButtons()
    local isSpectating = Spectate.selectedPlayer ~= nil
    if NextSpectateButton then NextSpectateButton.Visible = isSpectating end
    if PrevSpectateButton then PrevSpectateButton.Visible = isSpectating end
    if StopSpectateButton then StopSpectateButton.Visible = isSpectating end
    if TeleportSpectateButton then TeleportSpectateButton.Visible = isSpectating end
end

-- Stop Spectating
local function stopSpectating()
    for _, connection in pairs(Spectate.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    Spectate.connections = {}
    
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        Workspace.CurrentCamera.CameraSubject = player.Character.Humanoid
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    end
    
    Spectate.selectedPlayer = nil
    Spectate.currentSpectateIndex = 0
    
    updateSpectateButtons()
    print("Stopped spectating")
end

-- Spectate Player
local function spectatePlayer(targetPlayer)
    for _, connection in pairs(Spectate.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    Spectate.connections = {}
    
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
        Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        
        Spectate.selectedPlayer = targetPlayer
        Spectate.currentSpectateIndex = table.find(Spectate.spectatePlayerList, targetPlayer) or 0
        print("Spectating: " .. targetPlayer.Name)
        
        local targetHumanoid = targetPlayer.Character.Humanoid
        Spectate.connections.died = targetHumanoid.Died:Connect(function()
            print("Spectated player died, waiting for respawn")
            local newCharacter = targetPlayer.CharacterAdded:Wait()
            local newHumanoid = newCharacter:WaitForChild("Humanoid", 5)
            if newHumanoid and Spectate.selectedPlayer == targetPlayer then
                Workspace.CurrentCamera.CameraSubject = newHumanoid
                Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                print("Spectated player respawned, continuing spectate")
            end
        end)
        
        Spectate.connections.characterAdded = targetPlayer.CharacterAdded:Connect(function(newCharacter)
            local newHumanoid = newCharacter:WaitForChild("Humanoid", 5)
            if newHumanoid and Spectate.selectedPlayer == targetPlayer then
                Workspace.CurrentCamera.CameraSubject = newHumanoid
                Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                print("Spectated player character added, continuing spectate")
            end
        end)
    else
        stopSpectating()
    end
    updateSpectateButtons()
end

-- Spectate Next Player
local function spectateNextPlayer()
    if #Spectate.spectatePlayerList == 0 then
        print("No players to spectate")
        stopSpectating()
        return
    end
    
    Spectate.currentSpectateIndex = Spectate.currentSpectateIndex + 1
    if Spectate.currentSpectateIndex > #Spectate.spectatePlayerList then
        Spectate.currentSpectateIndex = 1
    end
    
    local targetPlayer = Spectate.spectatePlayerList[Spectate.currentSpectateIndex]
    if targetPlayer then
        spectatePlayer(targetPlayer)
    else
        stopSpectating()
    end
end

-- Spectate Previous Player
local function spectatePrevPlayer()
    if #Spectate.spectatePlayerList == 0 then
        print("No players to spectate")
        stopSpectating()
        return
    end
    
    Spectate.currentSpectateIndex = Spectate.currentSpectateIndex - 1
    if Spectate.currentSpectateIndex < 1 then
        Spectate.currentSpectateIndex = #Spectate.spectatePlayerList
    end
    
    local targetPlayer = Spectate.spectatePlayerList[Spectate.currentSpectateIndex]
    if targetPlayer then
        spectatePlayer(targetPlayer)
    else
        stopSpectating()
    end
end

-- Teleport to Spectated Player
local function teleportToSpectatedPlayer()
    if Spectate.selectedPlayer and Spectate.selectedPlayer.Character and 
       Spectate.selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and rootPart then
        local targetPosition = Spectate.selectedPlayer.Character.HumanoidRootPart.CFrame
        rootPart.CFrame = targetPosition * CFrame.new(0, 0, 3)
        print("Teleported to spectated player: " .. Spectate.selectedPlayer.Name)
    else
        print("Cannot teleport: No valid spectated player or missing rootPart")
    end
end

-- Initialize UI Elements
local function initUI()
    if not ScreenGui then
        warn("ScreenGui not available for Spectate UI initialization")
        return
    end
    
    print("Initializing Spectate UI...")
    
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

    -- Connect button events
    NextSpectateButton.MouseButton1Click:Connect(spectateNextPlayer)
    PrevSpectateButton.MouseButton1Click:Connect(spectatePrevPlayer)
    StopSpectateButton.MouseButton1Click:Connect(stopSpectating)
    TeleportSpectateButton.MouseButton1Click:Connect(teleportToSpectatedPlayer)

    -- Mouse hover effects
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
    
    print("Spectate UI initialized successfully")
end

-- Setup events
function Spectate.setupEvents()
    -- Update spectate player list
    Spectate.spectatePlayerList = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("Humanoid") then
            table.insert(Spectate.spectatePlayerList, p)
        end
    end
end

-- Get selected player
function Spectate.getSelectedPlayer()
    return Spectate.selectedPlayer
end

-- Reset states
function Spectate.resetStates()
    stopSpectating()
    Spectate.spectatePlayerList = {}
    Spectate.currentSpectateIndex = 0
end

-- Initialize
function Spectate.init(deps)
    Players = deps.Players
    Workspace = deps.Workspace
    ScreenGui = deps.ScreenGui
    player = deps.player
    rootPart = deps.rootPart
    
    -- Get reference to shared functions
    getSelectedPlayer = deps.getSelectedPlayer
    updatePlayerList = deps.updatePlayerList
    
    Spectate.selectedPlayer = nil
    Spectate.spectatePlayerList = {}
    Spectate.currentSpectateIndex = 0
    Spectate.connections = {}
    
    pcall(initUI)
    
    return true
end

return Spectate