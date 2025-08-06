-- Modern Roblox GUI Script untuk Android dengan Kategori
-- Dibuat dengan desain modern hitam dan fitur lengkap

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

-- Variabel untuk fitur
local flyEnabled = false
local noclipEnabled = false
local speedEnabled = false
local jumpHighEnabled = false
local godModeEnabled = false
local fullbrightEnabled = false
local antiAFKEnabled = false
local playerNoclipEnabled = false
local spiderEnabled = false
local freecamEnabled = false

local savedPosition = nil
local savedPositionName = "Default"
local spectateIndex = 1
local selectedPlayer = nil
local currentCategory = "Movement"
local playerListVisible = false

-- Connections
local connections = {}

-- GUI Creation
local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local TopBar = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local Logo = Instance.new("TextLabel")
local MinimizeButton = Instance.new("TextButton")

-- Category System
local CategoryFrame = Instance.new("Frame")
local CategoryList = Instance.new("UIListLayout")
local ContentFrame = Instance.new("Frame")
local ScrollFrame = Instance.new("ScrollingFrame")
local UIListLayout = Instance.new("UIListLayout")

-- Player Selection System
local PlayerListFrame = Instance.new("Frame")
local PlayerListScrollFrame = Instance.new("ScrollingFrame")
local PlayerListLayout = Instance.new("UIListLayout")
local SelectedPlayerLabel = Instance.new("TextLabel")

local LogoButton = Instance.new("TextButton")

-- GUI Properties
ScreenGui.Name = "ModernHackGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Main Frame (lebih lebar untuk kategori)
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderColor3 = Color3.fromRGB(0, 162, 255)
MainFrame.BorderSizePixel = 2
MainFrame.Position = UDim2.new(0.05, 0, 0.1, 0)
MainFrame.Size = UDim2.new(0, 450, 0, 500)
MainFrame.Active = true
MainFrame.Draggable = true

-- Corner untuk Main Frame
local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

-- Top Bar
TopBar.Name = "TopBar"
TopBar.Parent = MainFrame
TopBar.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
TopBar.Position = UDim2.new(0, 0, 0, 0)
TopBar.Size = UDim2.new(1, 0, 0, 40)

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 12)
TopCorner.Parent = TopBar

-- Fix corner untuk bottom
local TopFix = Instance.new("Frame")
TopFix.Parent = TopBar
TopFix.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
TopFix.BorderSizePixel = 0
TopFix.Position = UDim2.new(0, 0, 0.5, 0)
TopFix.Size = UDim2.new(1, 0, 0.5, 0)

-- Logo di TopBar
Logo.Name = "Logo"
Logo.Parent = TopBar
Logo.BackgroundTransparency = 1
Logo.Position = UDim2.new(0, 10, 0, 5)
Logo.Size = UDim2.new(0, 30, 0, 30)
Logo.Font = Enum.Font.GothamBold
Logo.Text = "🔥"
Logo.TextColor3 = Color3.fromRGB(255, 255, 255)
Logo.TextScaled = true

-- Title
Title.Name = "Title"
Title.Parent = TopBar
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 50, 0, 0)
Title.Size = UDim2.new(1, -90, 1, 0)
Title.Font = Enum.Font.GothamBold
Title.Text = "Modern Hack GUI"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextScaled = true
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Minimize Button
MinimizeButton.Name = "MinimizeButton"
MinimizeButton.Parent = TopBar
MinimizeButton.BackgroundTransparency = 1
MinimizeButton.Position = UDim2.new(1, -35, 0, 5)
MinimizeButton.Size = UDim2.new(0, 30, 0, 30)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "−"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextScaled = true

-- Category Frame (Panel Kiri)
CategoryFrame.Name = "CategoryFrame"
CategoryFrame.Parent = MainFrame
CategoryFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
CategoryFrame.BorderColor3 = Color3.fromRGB(0, 162, 255)
CategoryFrame.BorderSizePixel = 1
CategoryFrame.Position = UDim2.new(0, 10, 0, 50)
CategoryFrame.Size = UDim2.new(0, 120, 1, -60)

local CategoryCorner = Instance.new("UICorner")
CategoryCorner.CornerRadius = UDim.new(0, 8)
CategoryCorner.Parent = CategoryFrame

-- Category List Layout
CategoryList.Parent = CategoryFrame
CategoryList.Padding = UDim.new(0, 5)
CategoryList.SortOrder = Enum.SortOrder.LayoutOrder

-- Content Frame (Panel Kanan)
ContentFrame.Name = "ContentFrame"
ContentFrame.Parent = MainFrame
ContentFrame.BackgroundTransparency = 1
ContentFrame.Position = UDim2.new(0, 140, 0, 50)
ContentFrame.Size = UDim2.new(1, -150, 1, -60)

-- ScrollFrame di Content
ScrollFrame.Name = "ScrollFrame"
ScrollFrame.Parent = ContentFrame
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.Position = UDim2.new(0, 0, 0, 0)
ScrollFrame.Size = UDim2.new(1, 0, 1, 0)
ScrollFrame.ScrollBarThickness = 6
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 162, 255)

-- UIListLayout untuk content
UIListLayout.Parent = ScrollFrame
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Player Selection Frame
PlayerListFrame.Name = "PlayerListFrame"
PlayerListFrame.Parent = ScreenGui
PlayerListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
PlayerListFrame.BorderColor3 = Color3.fromRGB(0, 162, 255)
PlayerListFrame.BorderSizePixel = 2
PlayerListFrame.Position = UDim2.new(0.5, 0, 0.2, 0)
PlayerListFrame.Size = UDim2.new(0, 300, 0, 400)
PlayerListFrame.Visible = false
PlayerListFrame.Active = true
PlayerListFrame.Draggable = true

local PlayerListCorner = Instance.new("UICorner")
PlayerListCorner.CornerRadius = UDim.new(0, 12)
PlayerListCorner.Parent = PlayerListFrame

-- Player List Title
local PlayerListTitle = Instance.new("TextLabel")
PlayerListTitle.Name = "Title"
PlayerListTitle.Parent = PlayerListFrame
PlayerListTitle.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
PlayerListTitle.Position = UDim2.new(0, 0, 0, 0)
PlayerListTitle.Size = UDim2.new(1, 0, 0, 40)
PlayerListTitle.Font = Enum.Font.GothamBold
PlayerListTitle.Text = "Select Player"
PlayerListTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
PlayerListTitle.TextScaled = true

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 12)
TitleCorner.Parent = PlayerListTitle

local TitleFix = Instance.new("Frame")
TitleFix.Parent = PlayerListTitle
TitleFix.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
TitleFix.BorderSizePixel = 0
TitleFix.Position = UDim2.new(0, 0, 0.5, 0)
TitleFix.Size = UDim2.new(1, 0, 0.5, 0)

-- Close Button untuk Player List
local ClosePlayerListButton = Instance.new("TextButton")
ClosePlayerListButton.Name = "CloseButton"
ClosePlayerListButton.Parent = PlayerListFrame
ClosePlayerListButton.BackgroundTransparency = 1
ClosePlayerListButton.Position = UDim2.new(1, -35, 0, 5)
ClosePlayerListButton.Size = UDim2.new(0, 30, 0, 30)
ClosePlayerListButton.Font = Enum.Font.GothamBold
ClosePlayerListButton.Text = "×"
ClosePlayerListButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ClosePlayerListButton.TextScaled = true

-- Selected Player Display
SelectedPlayerLabel.Name = "SelectedPlayerLabel"
SelectedPlayerLabel.Parent = PlayerListFrame
SelectedPlayerLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
SelectedPlayerLabel.BorderColor3 = Color3.fromRGB(0, 162, 255)
SelectedPlayerLabel.BorderSizePixel = 1
SelectedPlayerLabel.Position = UDim2.new(0, 10, 0, 50)
SelectedPlayerLabel.Size = UDim2.new(1, -20, 0, 30)
SelectedPlayerLabel.Font = Enum.Font.Gotham
SelectedPlayerLabel.Text = "Selected: None"
SelectedPlayerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SelectedPlayerLabel.TextSize = 14

local SelectedCorner = Instance.new("UICorner")
SelectedCorner.CornerRadius = UDim.new(0, 6)
SelectedCorner.Parent = SelectedPlayerLabel

-- Player List ScrollFrame
PlayerListScrollFrame.Name = "PlayerListScrollFrame"
PlayerListScrollFrame.Parent = PlayerListFrame
PlayerListScrollFrame.BackgroundTransparency = 1
PlayerListScrollFrame.Position = UDim2.new(0, 10, 0, 90)
PlayerListScrollFrame.Size = UDim2.new(1, -20, 1, -100)
PlayerListScrollFrame.ScrollBarThickness = 6
PlayerListScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 162, 255)

-- Player List Layout
PlayerListLayout.Parent = PlayerListScrollFrame
PlayerListLayout.Padding = UDim.new(0, 5)
PlayerListLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Logo Button (minimized state)
LogoButton.Name = "LogoButton"
LogoButton.Parent = ScreenGui
LogoButton.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
LogoButton.Position = UDim2.new(0.05, 0, 0.1, 0)
LogoButton.Size = UDim2.new(0, 50, 0, 50)
LogoButton.Font = Enum.Font.GothamBold
LogoButton.Text = "🔥"
LogoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoButton.TextScaled = true
LogoButton.Visible = false
LogoButton.Active = true
LogoButton.Draggable = true

local LogoCorner = Instance.new("UICorner")
LogoCorner.CornerRadius = UDim.new(1, 0)
LogoCorner.Parent = LogoButton

-- Categories dan Buttons
local categories = {
    ["Movement"] = {
        icon = "🏃",
        buttons = {}
    },
    ["Player"] = {
        icon = "👤", 
        buttons = {}
    },
    ["Visual"] = {
        icon = "👁️",
        buttons = {}
    },
    ["Teleport"] = {
        icon = "📍",
        buttons = {}
    },
    ["Utility"] = {
        icon = "🔧",
        buttons = {}
    }
}

-- Function to create category buttons
local function createCategoryButton(name, icon)
    local button = Instance.new("TextButton")
    button.Name = name .. "Category"
    button.Parent = CategoryFrame
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -10, 0, 40)
    button.Font = Enum.Font.Gotham
    button.Text = icon .. " " .. name
    button.TextColor3 = Color3.fromRGB(200, 200, 200)
    button.TextSize = 12
    button.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Padding untuk text
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 8)
    padding.Parent = button
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    button.MouseButton1Click:Connect(function()
        switchCategory(name)
    end)
    
    return button
end

-- Function to switch categories
function switchCategory(categoryName)
    currentCategory = categoryName
    
    -- Update category button colors
    for _, child in pairs(CategoryFrame:GetChildren()) do
        if child:IsA("TextButton") then
            if child.Name == categoryName .. "Category" then
                child.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
                child.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                child.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                child.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
    end
    
    -- Clear current buttons
    for _, child in pairs(ScrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- Show buttons for selected category
    if categories[categoryName] and categories[categoryName].buttons then
        for _, buttonData in pairs(categories[categoryName].buttons) do
            if buttonData.type == "toggle" then
                createToggleButton(buttonData.name, buttonData.callback)
            else
                createButton(buttonData.name, buttonData.callback)
            end
        end
    end
    
    -- Force update canvas size
    wait(0.1)
    updateCanvasSize()
end

-- Function to create buttons
local function createButton(name, callback)
    local button = Instance.new("TextButton")
    button.Name = name .. "Button"
    button.Parent = ScrollFrame
    button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    button.BorderColor3 = Color3.fromRGB(0, 162, 255)
    button.BorderSizePixel = 1
    button.Size = UDim2.new(1, 0, 0, 35)
    button.Font = Enum.Font.Gotham
    button.Text = name
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 14
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    button.MouseButton1Click:Connect(callback)
    
    -- Hover effect
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0, 162, 255)}):Play()
    end)
    
    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35, 35, 35)}):Play()
    end)
    
    return button
end

-- Function to create toggle buttons
local function createToggleButton(name, callback)
    local button = Instance.new("TextButton")
    button.Name = name .. "Button"
    button.Parent = ScrollFrame
    button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    button.BorderColor3 = Color3.fromRGB(0, 162, 255)
    button.BorderSizePixel = 1
    button.Size = UDim2.new(1, 0, 0, 35)
    button.Font = Enum.Font.Gotham
    button.Text = name .. " [OFF]"
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 14
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    local isToggled = false
    
    local function updateButton()
        if isToggled then
            button.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
            button.Text = name .. " [ON]"
        else
            button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            button.Text = name .. " [OFF]"
        end
    end
    
    button.MouseButton1Click:Connect(function()
        isToggled = not isToggled
        updateButton()
        callback(isToggled)
    end)
    
    -- Hover effect (hanya saat OFF)
    button.MouseEnter:Connect(function()
        if not isToggled then
            TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 50, 50)}):Play()
        end
    end)
    
    button.MouseLeave:Connect(function()
        if not isToggled then
            TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35, 35, 35)}):Play()
        end
    end)
    
    updateButton()
    return button
end

-- Minimize/Maximize functions
local function minimizeGUI()
    MainFrame.Visible = false
    LogoButton.Visible = true
end

local function maximizeGUI()
    LogoButton.Visible = false
    MainFrame.Visible = true
end

-- Event connections
MinimizeButton.MouseButton1Click:Connect(minimizeGUI)
LogoButton.MouseButton1Click:Connect(maximizeGUI)

-- Player List Close Button
ClosePlayerListButton.MouseButton1Click:Connect(function()
    PlayerListFrame.Visible = false
    playerListVisible = false
end)

-- Function to update player list
local function updatePlayerList()
    -- Clear existing player buttons
    for _, child in pairs(PlayerListScrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- Add players to list
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            local playerButton = Instance.new("TextButton")
            playerButton.Name = p.Name .. "Button"
            playerButton.Parent = PlayerListScrollFrame
            playerButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            playerButton.BorderColor3 = Color3.fromRGB(0, 162, 255)
            playerButton.BorderSizePixel = 1
            playerButton.Size = UDim2.new(1, 0, 0, 35)
            playerButton.Font = Enum.Font.Gotham
            playerButton.Text = p.Name
            playerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            playerButton.TextSize = 14
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = playerButton
            
            -- Player selection
            playerButton.MouseButton1Click:Connect(function()
                selectedPlayer = p
                SelectedPlayerLabel.Text = "Selected: " .. p.Name
                PlayerListFrame.Visible = false
                playerListVisible = false
                
                -- Update button color to show selection
                for _, btn in pairs(PlayerListScrollFrame:GetChildren()) do
                    if btn:IsA("TextButton") then
                        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
                    end
                end
                playerButton.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
            end)
            
            -- Hover effects
            playerButton.MouseEnter:Connect(function()
                if playerButton.BackgroundColor3 ~= Color3.fromRGB(0, 162, 255) then
                    TweenService:Create(playerButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 50, 50)}):Play()
                end
            end)
            
            playerButton.MouseLeave:Connect(function()
                if playerButton.BackgroundColor3 ~= Color3.fromRGB(0, 162, 255) then
                    TweenService:Create(playerButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35, 35, 35)}):Play()
                end
            end)
        end
    end
    
    -- Update canvas size
    local contentSize = PlayerListLayout.AbsoluteContentSize
    PlayerListScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 10)
end

-- Function to show player selection
local function showPlayerSelection()
    playerListVisible = true
    PlayerListFrame.Visible = true
    updatePlayerList()
end

-- Feature Functions (sama seperti sebelumnya)

-- Fly
local function toggleFly(enabled)
    flyEnabled = enabled
    if enabled then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = rootPart
        
        connections.fly = RunService.Heartbeat:Connect(function()
            if flyEnabled then
                local moveVector = humanoid.MoveDirection
                bodyVelocity.Velocity = moveVector * 50
            end
        end)
    else
        if connections.fly then
            connections.fly:Disconnect()
        end
        if rootPart:FindFirstChild("BodyVelocity") then
            rootPart:FindFirstChild("BodyVelocity"):Destroy()
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
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
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
                end
            end
        end
    end
end

-- Speed
local function toggleSpeed(enabled)
    speedEnabled = enabled
    if enabled then
        humanoid.WalkSpeed = 100
    else
        humanoid.WalkSpeed = 16
    end
end

-- Jump High
local function toggleJumpHigh(enabled)
    jumpHighEnabled = enabled
    if enabled then
        humanoid.JumpPower = 120
    else
        humanoid.JumpPower = 50
    end
end

-- Spider
local function toggleSpider(enabled)
    spiderEnabled = enabled
    if enabled then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = rootPart
        
        connections.spider = RunService.Heartbeat:Connect(function()
            if spiderEnabled then
                local raycast = workspace:Raycast(rootPart.Position, rootPart.CFrame.LookVector * 3)
                if raycast then
                    bodyVelocity.Velocity = rootPart.CFrame.LookVector * 16
                else
                    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                end
            end
        end)
    else
        if connections.spider then
            connections.spider:Disconnect()
        end
        if rootPart:FindFirstChild("BodyVelocity") then
            rootPart:FindFirstChild("BodyVelocity"):Destroy()
        end
    end
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
        connections.antiafk = game:GetService("Players").LocalPlayer.Idled:Connect(function()
            if antiAFKEnabled then
                game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
                game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
            end
        end)
    else
        if connections.antiafk then
            connections.antiafk:Disconnect()
        end
    end
end

-- Fullbright
local function toggleFullbright(enabled)
    fullbrightEnabled = enabled
    local lighting = game:GetService("Lighting")
    if enabled then
        lighting.Brightness = 2
        lighting.ClockTime = 14
        lighting.FogEnd = 100000
        lighting.GlobalShadows = false
        lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    else
        lighting.Brightness = 1
        lighting.ClockTime = 14
        lighting.FogEnd = 100000
        lighting.GlobalShadows = true
        lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
    end
end

-- Freecam
local freecamPart = nil
local function toggleFreecam(enabled)
    freecamEnabled = enabled
    if enabled then
        freecamPart = Instance.new("Part")
        freecamPart.Name = "FreecamPart"
        freecamPart.Anchored = true
        freecamPart.CanCollide = false
        freecamPart.Transparency = 1
        freecamPart.CFrame = rootPart.CFrame
        freecamPart.Parent = workspace
        
        workspace.CurrentCamera.CameraSubject = freecamPart
    else
        if freecamPart then
            freecamPart:Destroy()
            freecamPart = nil
        end
        workspace.CurrentCamera.CameraSubject = humanoid
    end
end

-- Spectate functions
local function spectateSelectedPlayer()
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("Humanoid") then
        workspace.CurrentCamera.CameraSubject = selectedPlayer.Character.Humanoid
    else
        -- Show notification if no player selected
        local notification = Instance.new("TextLabel")
        notification.Parent = ScreenGui
        notification.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        notification.Size = UDim2.new(0, 250, 0, 50)
        notification.Position = UDim2.new(0.5, -125, 0, 50)
        notification.Text = "Please select a player first!"
        notification.TextColor3 = Color3.fromRGB(255, 255, 255)
        notification.Font = Enum.Font.GothamBold
        notification.TextScaled = true
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = notification
        
        spawn(function()
            wait(2)
            notification:Destroy()
        end)
    end
end

local function spectatePlayer()
    local players = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(players, p)
        end
    end
    
    if #players > 0 then
        spectateIndex = ((spectateIndex - 1) % #players) + 1
        local targetPlayer = players[spectateIndex]
        if targetPlayer and targetPlayer.Character then
            workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
            selectedPlayer = targetPlayer
            SelectedPlayerLabel.Text = "Selected: " .. targetPlayer.Name
        end
    end
end

local function nextSpectate()
    spectateIndex = spectateIndex + 1
    spectatePlayer()
end

local function prevSpectate()
    spectateIndex = spectateIndex - 1
    spectatePlayer()
end

local function stopSpectate()
    workspace.CurrentCamera.CameraSubject = humanoid
end

-- Teleport to selected player
local function tpToSelectedPlayer()
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and rootPart then
        rootPart.CFrame = selectedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
    else
        -- Show notification if no player selected
        local notification = Instance.new("TextLabel")
        notification.Parent = ScreenGui
        notification.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        notification.Size = UDim2.new(0, 250, 0, 50)
        notification.Position = UDim2.new(0.5, -125, 0, 50)
        notification.Text = "Please select a player first!"
        notification.TextColor3 = Color3.fromRGB(255, 255, 255)
        notification.Font = Enum.Font.GothamBold
        notification.TextScaled = true
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = notification
        
        spawn(function()
            wait(2)
            notification:Destroy()
        end)
    end
end

-- Save/Load Position
local function savePosition()
    if rootPart then
        savedPosition = rootPart.CFrame
        -- Notification
        local notification = Instance.new("TextLabel")
        notification.Parent = ScreenGui
        notification.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
        notification.Size = UDim2.new(0, 200, 0, 50)
        notification.Position = UDim2.new(0.5, -100, 0, 50)
        notification.Text = "Position Saved!"
        notification.TextColor3 = Color3.fromRGB(255, 255, 255)
        notification.Font = Enum.Font.GothamBold
        notification.TextScaled = true
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = notification
        
        spawn(function()
            wait(2)
            notification:Destroy()
        end)
    end
end

local function loadPosition()
    if savedPosition and rootPart then
        rootPart.CFrame = savedPosition
    end
end

local function tpToFreecam()
    if freecamPart and rootPart then
        rootPart.CFrame = freecamPart.CFrame
    end
end

-- Setup Categories dan Buttons
-- Movement Category
table.insert(categories["Movement"].buttons, {name = "Fly", type = "toggle", callback = toggleFly})
table.insert(categories["Movement"].buttons, {name = "Noclip", type = "toggle", callback = toggleNoclip})
table.insert(categories["Movement"].buttons, {name = "Speed", type = "toggle", callback = toggleSpeed})
table.insert(categories["Movement"].buttons, {name = "Jump High", type = "toggle", callback = toggleJumpHigh})
table.insert(categories["Movement"].buttons, {name = "Spider", type = "toggle", callback = toggleSpider})

-- Player Category
table.insert(categories["Player"].buttons, {name = "Select Player", type = "normal", callback = showPlayerSelection})
table.insert(categories["Player"].buttons, {name = "God Mode", type = "toggle", callback = toggleGodMode})
table.insert(categories["Player"].buttons, {name = "Anti AFK", type = "toggle", callback = toggleAntiAFK})
table.insert(categories["Player"].buttons, {name = "Spectate Selected", type = "normal", callback = spectateSelectedPlayer})
table.insert(categories["Player"].buttons, {name = "Auto Spectate", type = "normal", callback = spectatePlayer})
table.insert(categories["Player"].buttons, {name = "Next Spectate", type = "normal", callback = nextSpectate})
table.insert(categories["Player"].buttons, {name = "Prev Spectate", type = "normal", callback = prevSpectate})
table.insert(categories["Player"].buttons, {name = "Stop Spectate", type = "normal", callback = stopSpectate})

-- Visual Category
table.insert(categories["Visual"].buttons, {name = "Fullbright", type = "toggle", callback = toggleFullbright})
table.insert(categories["Visual"].buttons, {name = "Freecam", type = "toggle", callback = toggleFreecam})

-- Teleport Category
table.insert(categories["Teleport"].buttons, {name = "Save Position", type = "normal", callback = savePosition})
table.insert(categories["Teleport"].buttons, {name = "TP to Saved Position", type = "normal", callback = loadPosition})
table.insert(categories["Teleport"].buttons, {name = "TP to Selected Player", type = "normal", callback = tpToSelectedPlayer})
table.insert(categories["Teleport"].buttons, {name = "TP to Freecam", type = "normal", callback = tpToFreecam})

-- Utility Category
table.insert(categories["Utility"].buttons, {name = "Disable Previous Script", type = "normal", callback = function()
    for _, gui in pairs(CoreGui:GetChildren()) do
        if gui.Name == "ModernHackGUI" and gui ~= ScreenGui then
            gui:Destroy()
        end
    end
end})

-- Create category buttons
for name, data in pairs(categories) do
    createCategoryButton(name, data.icon)
end

-- Initialize with Movement category
spawn(function()
    wait(0.5) -- Wait for everything to load
    switchCategory("Movement")
end)

-- Update canvas size
local function updateCanvasSize()
    spawn(function()
        wait(0.1)
        local contentSize = UIListLayout.AbsoluteContentSize
        ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 10)
    end)
end

UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvasSize)

-- Character respawn handling
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Reset all toggles
    flyEnabled = false
    noclipEnabled = false
    speedEnabled = false
    jumpHighEnabled = false
    godModeEnabled = false
    antiAFKEnabled = false
    spiderEnabled = false
    freecamEnabled = false
    
    -- Disconnect all connections
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    connections = {}
end)

print("Modern Hack GUI dengan Kategori & Player Selection Loaded!")
print("🏃 Movement | 👤 Player | 👁️ Visual | 📍 Teleport | 🔧 Utility")
print("Klik 'Select Player' untuk memilih target")
print("Klik kategori di kiri untuk beralih fitur")

-- Debug: Print categories to check if they're loaded
print("Categories loaded:")
for name, data in pairs(categories) do
    print("- " .. name .. " (" .. #data.buttons .. " buttons)")
end