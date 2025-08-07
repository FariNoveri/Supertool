local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- AUTO-DISABLE PREVIOUS SCRIPTS
for _, gui in pairs(CoreGui:GetChildren()) do
    if gui.Name == "MinimalHackGUI" or gui.Name == "TeleportHackGUI" then
        gui:Destroy()
    end
end

-- URLs for script loading
local scriptURLs = {
    AntiAdmin = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/AntiAdmin.lua",
    Movement = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement.lua",
    Player = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Player.lua",
    Visual = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Visual.lua",
    Teleport = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Teleport.lua",
    Utility = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Utility.lua",
    Settings = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Settings.lua",
    Info = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Info.lua"
}

-- Load AntiAdmin.lua
local success, errorMsg = pcall(function()
    loadstring(game:HttpGet(scriptURLs.AntiAdmin, true))()
end)
if not success then
    local errorLabel = Instance.new("TextLabel")
    errorLabel.Name = "AntiAdminError"
    errorLabel.Parent = CoreGui
    errorLabel.BackgroundTransparency = 1
    errorLabel.Position = UDim2.new(0.5, 0, 0.05, 0)
    errorLabel.Size = UDim2.new(0, 300, 0, 20)
    errorLabel.Font = Enum.Font.Gotham
    errorLabel.Text = "Failed to load AntiAdmin: " .. tostring(errorMsg)
    errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
    errorLabel.TextSize = 10
    errorLabel.TextWrapped = true
end

-- Variables for GUI
local selectedPlayer = nil
local currentCategory = "Movement"
local playerListVisible = false
local guiMinimized = false
local spectatePlayerList = {}
local currentSpectateIndex = 0
local spectateConnections = {}
local buttonStates = {}

-- GUI Creation
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MinimalHackGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
MainFrame.BorderSizePixel = 1
MainFrame.Position = UDim2.new(0.05, 0, 0.1, 0)
MainFrame.Size = UDim2.new(0, 600, 0, 400)
MainFrame.Active = true
MainFrame.Draggable = true

local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Parent = MainFrame
TopBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
TopBar.BorderSizePixel = 0
TopBar.Position = UDim2.new(0, 0, 0, 0)
TopBar.Size = UDim2.new(1, 0, 0, 35)

local Logo = Instance.new("TextLabel")
Logo.Name = "Logo"
Logo.Parent = TopBar
Logo.BackgroundTransparency = 1
Logo.Position = UDim2.new(0, 10, 0, 5)
Logo.Size = UDim2.new(0, 25, 0, 25)
Logo.Font = Enum.Font.GothamBold
Logo.Text = "H"
Logo.TextColor3 = Color3.fromRGB(255, 255, 255)
Logo.TextScaled = true

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Parent = TopBar
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 45, 0, 0)
Title.Size = UDim2.new(1, -90, 1, 0)
Title.Font = Enum.Font.Gotham
Title.Text = "HACK - By Fari Noveri [UNKNOWN BLOCK] 32131"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left

local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Name = "MinimizeButton"
MinimizeButton.Parent = TopBar
MinimizeButton.BackgroundTransparency = 1
MinimizeButton.Position = UDim2.new(1, -30, 0, 5)
MinimizeButton.Size = UDim2.new(0, 25, 0, 25)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "_"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextSize = 16
MinimizeButton.AutoButtonColor = true

local CategoryFrame = Instance.new("Frame")
CategoryFrame.Name = "CategoryFrame"
CategoryFrame.Parent = MainFrame
CategoryFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
CategoryFrame.BorderSizePixel = 0
CategoryFrame.Position = UDim2.new(0, 0, 0, 35)
CategoryFrame.Size = UDim2.new(0, 140, 1, -35)

local CategoryList = Instance.new("UIListLayout")
CategoryList.Parent = CategoryFrame
CategoryList.Padding = UDim.new(0, 2)
CategoryList.SortOrder = Enum.SortOrder.LayoutOrder

local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Parent = MainFrame
ContentFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
ContentFrame.BorderSizePixel = 0
ContentFrame.Position = UDim2.new(0, 140, 0, 35)
ContentFrame.Size = UDim2.new(1, -140, 1, -35)

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Name = "ScrollFrame"
ScrollFrame.Parent = ContentFrame
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.Position = UDim2.new(0, 10, 0, 10)
ScrollFrame.Size = UDim2.new(1, -20, 1, -20)
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
ScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = ScrollFrame
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local PlayerListFrame = Instance.new("Frame")
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

local ClosePlayerListButton = Instance.new("TextButton")
ClosePlayerListButton.Name = "CloseButton"
ClosePlayerListButton.Parent = PlayerListFrame
ClosePlayerListButton.BackgroundTransparency = 1
ClosePlayerListButton.Position = UDim2.new(1, -30, 0, 5)
ClosePlayerListButton.Size = UDim2.new(0, 25, 0, 25)
ClosePlayerListButton.Font = Enum.Font.GothamBold
ClosePlayerListButton.Text = "X"
ClosePlayerListButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ClosePlayerListButton.TextSize = 12
ClosePlayerListButton.AutoButtonColor = true

local SelectedPlayerLabel = Instance.new("TextLabel")
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

local PlayerListScrollFrame = Instance.new("ScrollingFrame")
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

local PlayerListLayout = Instance.new("UIListLayout")
PlayerListLayout.Parent = PlayerListScrollFrame
PlayerListLayout.Padding = UDim.new(0, 2)
PlayerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
PlayerListLayout.FillDirection = Enum.FillDirection.Vertical

local LogoButton = Instance.new("TextButton")
LogoButton.Name = "LogoButton"
LogoButton.Parent = ScreenGui
LogoButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
LogoButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
LogoButton.BorderSizePixel = 1
LogoButton.Position = UDim2.new(0.05, 0, 0.1, 0)
LogoButton.Size = UDim2.new(0, 40, 0, 40)
LogoButton.Font = Enum.Font.GothamBold
LogoButton.Text = "H"
LogoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoButton.TextSize = 16
LogoButton.Visible = false
LogoButton.Active = true
LogoButton.Draggable = true
LogoButton.AutoButtonColor = true

local NextSpectateButton = Instance.new("TextButton")
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
NextSpectateButton.AutoButtonColor = true

local PrevSpectateButton = Instance.new("TextButton")
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
PrevSpectateButton.AutoButtonColor = true

local StopSpectateButton = Instance.new("TextButton")
StopSpectateButton.Name = "StopSpectateButton"
StopSpectateButton.Parent = ScreenGui
StopSpectateButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
StopSpectateButton.BorderSizePixel = 1
StopSpectateButton.Position = UDim2.new(0.5, -30, 0.5, 40)
StopSpectateButton.Size = UDim2.new(0, 60, 0, 30)
StopSpectateButton.Font = Enum.Font.Gotham
StopSpectateButton.Text = "STOP"
StopSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
StopSpectateButton.TextSize = 10
StopSpectateButton.Visible = false
StopSpectateButton.Active = true
StopSpectateButton.AutoButtonColor = true

local TeleportSpectateButton = Instance.new("TextButton")
TeleportSpectateButton.Name = "TeleportSpectateButton"
TeleportSpectateButton.Parent = ScreenGui
TeleportSpectateButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
TeleportSpectateButton.BorderSizePixel = 1
TeleportSpectateButton.Position = UDim2.new(0.5, 40, 0.5, 40)
TeleportSpectateButton.Size = UDim2.new(0, 60, 0, 30)
TeleportSpectateButton.Font = Enum.Font.Gotham
TeleportSpectateButton.Text = "TP"
TeleportSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
TeleportSpectateButton.TextSize = 10
TeleportSpectateButton.Visible = false
TeleportSpectateButton.Active = true
TeleportSpectateButton.AutoButtonColor = true

-- Load feature scripts
local function loadFeatureScript(category)
    local success, result = pcall(function()
        local scriptContent = game:HttpGet(scriptURLs[category], true)
        return loadstring(scriptContent)()
    end)
    if success and type(result) == "table" then
        return result
    else
        local errorLabel = Instance.new("TextLabel")
        errorLabel.Name = category .. "Error"
        errorLabel.Parent = ScrollFrame
        errorLabel.BackgroundTransparency = 1
        errorLabel.Size = UDim2.new(1, 0, 0, 30)
        errorLabel.Font = Enum.Font.Gotham
        errorLabel.Text = "Failed to load " .. category .. ": " .. tostring(result or "Unknown error")
        errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        errorLabel.TextSize = 11
        return nil
    end
end

-- Button creation functions
local function createButton(name, callback)
    local button = Instance.new("TextButton")
    button.Name = name .. "Button"
    button.Parent = ScrollFrame
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 30)
    button.Font = Enum.Font.Gotham
    button.Text = name:upper()
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 11
    button.AutoButtonColor = true

    button.MouseButton1Click:Connect(function()
        local success, err = pcall(callback)
        if not success then
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = name .. "Error"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Error in " .. name .. ": " .. tostring(err)
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end
    end)

    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    end)

    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    end)

    return button
end

local function createToggleButton(name, callback)
    local button = Instance.new("TextButton")
    button.Name = name .. "Button"
    button.Parent = ScrollFrame
    button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 30)
    button.Font = Enum.Font.Gotham
    button.Text = name:upper() .. (buttonStates[name] and " [ON]" or " [OFF]")
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 11
    button.AutoButtonColor = true

    button.MouseButton1Click:Connect(function()
        buttonStates[name] = not buttonStates[name]
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(25, 25, 25)
        button.Text = name:upper() .. (buttonStates[name] and " [ON]" or " [OFF]")
        local success, err = pcall(function() callback(buttonStates[name]) end)
        if not success then
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = name .. "Error"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Error in " .. name .. ": " .. tostring(err)
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end
    end)

    button.MouseEnter:Connect(function()
        if not buttonStates[name] then
            button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
    end)

    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(25, 25, 25)
    end)

    return button
end

local function createCategoryButton(name)
    local button = Instance.new("TextButton")
    button.Name = name .. "Category"
    button.Parent = CategoryFrame
    button.BackgroundColor3 = name == currentCategory and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 35)
    button.Font = Enum.Font.Gotham
    button.Text = name:upper()
    button.TextColor3 = name == currentCategory and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
    button.TextSize = 10
    button.AutoButtonColor = true

    button.MouseButton1Click:Connect(function()
        switchCategory(name)
    end)

    return button
end

local function clearButtons()
    for _, child in pairs(ScrollFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then
            child:Destroy()
        end
    end
end

-- Player functions
local function updateSpectateButtons()
    local isSpectating = selectedPlayer ~= nil
    NextSpectateButton.Visible = isSpectating
    PrevSpectateButton.Visible = isSpectating
    StopSpectateButton.Visible = isSpectating
    TeleportSpectateButton.Visible = isSpectating
end

local function stopSpectating()
    for _, connection in pairs(spectateConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    spectateConnections = {}
    workspace.CurrentCamera.CameraSubject = humanoid
    selectedPlayer = nil
    currentSpectateIndex = 0
    SelectedPlayerLabel.Text = "SELECTED: NONE"
    updateSpectateButtons()
    for _, item in pairs(PlayerListScrollFrame:GetChildren()) do
        if item:IsA("Frame") and item:FindFirstChild("SelectButton") then
            item.SelectButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            item.SelectButton.Text = "SELECT PLAYER"
        end
    end
end

local function spectatePlayer(targetPlayer)
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
        SelectedPlayerLabel.Text = "SELECTED: " .. targetPlayer.Name:upper()

        local targetHumanoid = targetPlayer.Character.Humanoid
        spectateConnections.died = targetHumanoid.Died:Connect(function()
            -- Handle player death
        end)

        spectateConnections.characterAdded = targetPlayer.CharacterAdded:Connect(function(newCharacter)
            local newHumanoid = newCharacter:WaitForChild("Humanoid", 5)
            if newHumanoid then
                workspace.CurrentCamera.CameraSubject = newHumanoid
            end
        end)

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

local function spectateNextPlayer()
    if #spectatePlayerList == 0 then
        stopSpectating()
        return
    end

    currentSpectateIndex = currentSpectateIndex + 1
    if currentSpectateIndex > #spectatePlayerList then
        currentSpectateIndex = 1
    end

    local targetPlayer = spectatePlayerList[currentSpectateIndex]
    if targetPlayer then
        spectatePlayer(targetPlayer)
    else
        stopSpectating()
    end
end

local function spectatePrevPlayer()
    if #spectatePlayerList == 0 then
        stopSpectating()
        return
    end

    currentSpectateIndex = currentSpectateIndex - 1
    if currentSpectateIndex < 1 then
        currentSpectateIndex = #spectatePlayerList
    end

    local targetPlayer = spectatePlayerList[currentSpectateIndex]
    if targetPlayer then
        spectatePlayer(targetPlayer)
    else
        stopSpectating()
    end
end

local function updatePlayerList()
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
                selectButton.BackgroundColor3 = selectedPlayer == p and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(60, 60, 60)
                selectButton.BorderSizePixel = 0
                selectButton.Position = UDim2.new(0, 5, 0, 30)
                selectButton.Size = UDim2.new(1, -10, 0, 25)
                selectButton.Font = Enum.Font.Gotham
                selectButton.Text = selectedPlayer == p and "SELECTED" or "SELECT PLAYER"
                selectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                selectButton.TextSize = 10
                selectButton.AutoButtonColor = true

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
                spectateButton.AutoButtonColor = true

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
                stopSpectateButton.AutoButtonColor = true

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
                teleportButton.AutoButtonColor = true

                selectButton.MouseButton1Click:Connect(function()
                    selectedPlayer = p
                    currentSpectateIndex = table.find(spectatePlayerList, p) or 0
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
                    currentSpectateIndex = table.find(spectatePlayerList, p) or 0
                    spectatePlayer(p)
                end)

                stopSpectateButton.MouseButton1Click:Connect(function()
                    stopSpectating()
                end)

                teleportButton.MouseButton1Click:Connect(function()
                    local teleport = loadFeatureScript("Teleport")
                    if teleport and teleport.teleportToPlayer then
                        local success, err = pcall(teleport.teleportToPlayer)
                        if not success then
                            local errorLabel = Instance.new("TextLabel")
                            errorLabel.Name = "TeleportError"
                            errorLabel.Parent = ScrollFrame
                            errorLabel.BackgroundTransparency = 1
                            errorLabel.Size = UDim2.new(1, 0, 0, 20)
                            errorLabel.Font = Enum.Font.Gotham
                            errorLabel.Text = "Error in Teleport: " .. tostring(err)
                            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
                            errorLabel.TextSize = 10
                        end
                    else
                        local errorLabel = Instance.new("TextLabel")
                        errorLabel.Name = "TeleportError"
                        errorLabel.Parent = ScrollFrame
                        errorLabel.BackgroundTransparency = 1
                        errorLabel.Size = UDim2.new(1, 0, 0, 20)
                        errorLabel.Font = Enum.Font.Gotham
                        errorLabel.Text = "Teleport function not available"
                        errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
                        errorLabel.TextSize = 10
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
        selectedPlayer = previousSelectedPlayer
        currentSpectateIndex = table.find(spectatePlayerList, selectedPlayer) or 0
        if currentSpectateIndex == 0 and selectedPlayer then
            if not (selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("Humanoid") and selectedPlayer.Character.Humanoid.Health > 0) then
                stopSpectating()
            end
        end
        SelectedPlayerLabel.Text = selectedPlayer and "SELECTED: " .. selectedPlayer.Name:upper() or "SELECTED: NONE"
    else
        currentSpectateIndex = 0
    end

    wait(0.1)
    local contentSize = PlayerListLayout.AbsoluteContentSize
    PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(contentSize.Y + 10, 30))
    updateSpectateButtons()
end

-- Category button loaders
local function loadMovementButtons()
    local movement = loadFeatureScript("Movement")
    if movement then
        createToggleButton("Fly", movement.toggleFly or function() 
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "FlyError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Fly function not available"
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end)
        createToggleButton("Noclip", movement.toggleNoclip or function() 
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "NoclipError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Noclip function not available"
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end)
        createToggleButton("Speed", movement.toggleSpeed or function() 
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "SpeedError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Speed function not available"
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end)
        createToggleButton("Jump High", movement.toggleJumpHigh or function() 
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "JumpHighError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Jump High function not available"
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end)
        createToggleButton("Spider", movement.toggleSpider or function() 
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "SpiderError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Spider function not available"
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end)
        createToggleButton("Player Phase", movement.togglePlayerPhase or function() 
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "PlayerPhaseError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Player Phase function not available"
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end)
    end
end

local function loadPlayerButtons()
    local playerFuncs = loadFeatureScript("Player")
    if playerFuncs then
        createButton("Select Player", playerFuncs.showPlayerSelection or function()
            updatePlayerList()
            PlayerListFrame.Visible = true
        end)
        createToggleButton("God Mode", playerFuncs.toggleGodMode or function() 
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "GodModeError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "God Mode function not available"
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end)
        createToggleButton("Anti AFK", playerFuncs.toggleAntiAFK or function() 
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "AntiAFKError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Anti AFK function not available"
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end)
    end
end

local function loadVisualButtons()
    local visual = loadFeatureScript("Visual")
    if visual then
        createToggleButton("Fullbright", visual.toggleFullbright or function() 
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "FullbrightError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Fullbright function not available"
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end)
        createToggleButton("Freecam", visual.toggleFreecam or function() 
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "FreecamError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Freecam function not available"
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end)
        createToggleButton("Flashlight", visual.toggleFlashlight or function() 
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "FlashlightError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Flashlight function not available"
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end)
    end
end

local function loadTeleportButtons()
    local teleport = loadFeatureScript("Teleport")
    if teleport then
        createButton("Position Manager", teleport.showPositionManager or function() 
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "PositionManagerError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Position Manager not available"
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end)
        createButton("TP to Selected Player", teleport.teleportToPlayer or function() 
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "TeleportToPlayerError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Teleport to Player not available"
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end)
        createButton("TP to Freecam", teleport.teleportToFreecam or function() 
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "TeleportToFreecamError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Teleport to Freecam not available"
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end)
        createButton("Save Freecam Position", teleport.saveFreecamPosition or function() 
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "SaveFreecamPositionError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Save Freecam Position not available"
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end)
        createButton("Save Player Position", teleport.savePlayerPosition or function() 
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "SavePlayerPositionError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Save Player Position not available"
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end)
    end
end

local function loadUtilityButtons()
    local utility = loadFeatureScript("Utility")
    if utility then
        createButton("Disable Previous Script", utility.disablePreviousScript or function()
            for _, gui in pairs(CoreGui:GetChildren()) do
                if gui.Name == "MinimalHackGUI" and gui ~= ScreenGui then
                    gui:Destroy()
                end
            end
        end)
        createButton("Reset Character", utility.resetCharacter or function()
            if humanoid then
                humanoid.Health = 0
            end
        end)
    end
end

local function loadSettingsButtons()
    local settingsFuncs = loadFeatureScript("Settings")
    if settingsFuncs and settingsFuncs.loadSettingsButtons then
        local success, err = pcall(settingsFuncs.loadSettingsButtons)
        if not success then
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "SettingsError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Error in Settings: " .. tostring(err)
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end
    end
end

local function loadInfoButtons()
    local info = loadFeatureScript("Info")
    if info and info.loadInfoButtons then
        local success, err = pcall(info.loadInfoButtons)
        if not success then
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "InfoError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Error in Info (Language Switch): " .. tostring(err)
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end
    end
end

local function loadAntiAdminButtons()
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "AntiAdminInfo"
    infoLabel.Parent = ScrollFrame
    infoLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    infoLabel.BorderSizePixel = 0
    infoLabel.Size = UDim2.new(1, 0, 0, 300)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Text = [[
ANTI ADMIN PROTECTION

This feature is included to protect you from other admin/exploit attempts (kill, teleport, etc.). Effects will be reversed to the attacker or redirected to unprotected players. It is always active and cannot be disabled for your safety.

Note: Admins can still kick, ban, or perform other server-side actions against you.

Created by Fari Noveri
]]
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoLabel.TextSize = 10
    infoLabel.TextWrapped = true
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top
end

-- Category switching function
function switchCategory(categoryName)
    currentCategory = categoryName

    for _, child in pairs(CategoryFrame:GetChildren()) do
        if child:IsA("TextButton") then
            if child.Name == categoryName .. "Category" then
                child.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                child.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                child.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                child.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
    end

    clearButtons()

    if categoryName == "Movement" then
        loadMovementButtons()
    elseif categoryName == "Player" then
        loadPlayerButtons()
    elseif categoryName == "Visual" then
        loadVisualButtons()
    elseif categoryName == "Teleport" then
        loadTeleportButtons()
    elseif categoryName == "Utility" then
        loadUtilityButtons()
    elseif categoryName == "Settings" then
        loadSettingsButtons()
    elseif categoryName == "Info" then
        loadInfoButtons()
    elseif categoryName == "AntiAdmin" then
        loadAntiAdminButtons()
    end

    wait(0.1)
    local contentSize = UIListLayout.AbsoluteContentSize
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(contentSize.Y + 10, 30))
end

-- GUI interactions
MinimizeButton.MouseButton1Click:Connect(function()
    guiMinimized = not guiMinimized
    MainFrame.Visible = not guiMinimized
    LogoButton.Visible = guiMinimized
end)

LogoButton.MouseButton1Click:Connect(function()
    guiMinimized = false
    MainFrame.Visible = true
    LogoButton.Visible = false
end)

ClosePlayerListButton.MouseButton1Click:Connect(function()
    PlayerListFrame.Visible = false
    playerListVisible = false
end)

NextSpectateButton.MouseButton1Click:Connect(spectateNextPlayer)
PrevSpectateButton.MouseButton1Click:Connect(spectatePrevPlayer)
StopSpectateButton.MouseButton1Click:Connect(stopSpectating)

TeleportSpectateButton.MouseButton1Click:Connect(function()
    local teleport = loadFeatureScript("Teleport")
    if teleport and teleport.teleportToPlayer then
        local success, err = pcall(teleport.teleportToPlayer)
        if not success then
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "TeleportSpectateError"
            errorLabel.Parent = ScrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 20)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Error in Teleport Spectate: " .. tostring(err)
            errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            errorLabel.TextSize = 10
        end
    else
        local errorLabel = Instance.new("TextLabel")
        errorLabel.Name = "TeleportSpectateError"
        errorLabel.Parent = ScrollFrame
        errorLabel.BackgroundTransparency = 1
        errorLabel.Size = UDim2.new(1, 0, 0, 20)
        errorLabel.Font = Enum.Font.Gotham
        errorLabel.Text = "Teleport Spectate function not available"
        errorLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
        errorLabel.TextSize = 10
    end
end)

-- Initialize categories
local categories = {"Movement", "Player", "Visual", "Teleport", "Utility", "Settings", "Info", "AntiAdmin"}
for _, category in pairs(categories) do
    createCategoryButton(category)
end

-- Initial category load
switchCategory("Movement")

-- Update player list when players join/leave
Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(updatePlayerList)

-- Handle character reset
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
end)

-- Cleanup
local function cleanup()
    if ScreenGui then
        ScreenGui:Destroy()
    end
    stopSpectating()
end

game:BindToClose(cleanup)