-- MainLoader.lua - Android Optimized Complete Version
-- Dibuat oleh Fari Noveri - Full Android Touch Support + All Features

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid, hr, char

-- Feature states
local flying, noclip, autoHeal, noFall, godMode = false, false, false, false, false
local flySpeed = 16
local savedPositions = {}
local followTarget = nil
local gendongWeld = nil
local connections = {}

-- UI Variables
local gui, frame, logo
local tabPages = {}
local currentTab = nil
local isMinimized = false

-- Mobile detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Initialize character
local function initChar()
    char = player.Character or player.CharacterAdded:Wait()
    humanoid = char:WaitForChild("Humanoid")
    hr = char:WaitForChild("HumanoidRootPart")
end

-- Notification system
local function notify(message, color)
    color = color or Color3.fromRGB(0, 255, 0)
    local notif = Instance.new("TextLabel")
    notif.Size = UDim2.new(0, 300, 0, 50)
    notif.Position = UDim2.new(0.5, -150, 0, 100)
    notif.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    notif.BackgroundTransparency = 0.3
    notif.TextColor3 = color
    notif.TextScaled = true
    notif.Font = Enum.Font.GothamBold
    notif.Text = message
    notif.BorderSizePixel = 0
    notif.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notif
    
    TweenService:Create(notif, TweenInfo.new(0.3), {BackgroundTransparency = 0.1}):Play()
    task.wait(2)
    TweenService:Create(notif, TweenInfo.new(0.3), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
    task.wait(0.3)
    notif:Destroy()
end

-- Create main GUI
local function createGUI()
    gui = Instance.new("ScreenGui")
    gui.Name = "SuperToolUI_Mobile"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = player:WaitForChild("PlayerGui")

    -- Logo (bigger for mobile)
    logo = Instance.new("ImageButton")
    logo.Size = UDim2.new(0, 70, 0, 70)
    logo.Position = UDim2.new(0, 20, 0, 100)
    logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
    logo.BorderSizePixel = 0
    logo.Image = "rbxassetid://3570695787"
    logo.ImageTransparency = 0.2
    logo.Parent = gui
    
    local logoCorner = Instance.new("UICorner")
    logoCorner.CornerRadius = UDim.new(0, 35)
    logoCorner.Parent = logo

    -- Main frame (responsive)
    frame = Instance.new("Frame")
    if isMobile then
        frame.Size = UDim2.new(0.95, 0, 0.8, 0)
        frame.Position = UDim2.new(0.025, 0, 0.1, 0)
    else
        frame.Size = UDim2.new(0, 800, 0, 500)
        frame.Position = UDim2.new(0.5, -400, 0.5, -250)
    end
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = gui
    
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 12)
    frameCorner.Parent = frame
end

-- Touch drag system for mobile
local function makeDraggable(element)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    if isMobile then
        element.TouchPan:Connect(function(totalTranslation, velocity, state)
            if state == Enum.UserInputState.Begin then
                dragging = true
                startPos = element.Position
            elseif state == Enum.UserInputState.Change and dragging then
                element.Position = UDim2.new(
                    startPos.X.Scale, 
                    startPos.X.Offset + totalTranslation.X,
                    startPos.Y.Scale, 
                    startPos.Y.Offset + totalTranslation.Y
                )
            elseif state == Enum.UserInputState.End then
                dragging = false
            end
        end)
    else
        -- Desktop drag
        element.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = element.Position
            end
        end)
        
        element.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
                local delta = input.Position - dragStart
                element.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
        
        element.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
    end
end

-- Tab system
local function createTabSystem()
    -- Title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = frame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.7, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "🚀 Super Tool Mobile"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = titleBar
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.Position = UDim2.new(1, -45, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.TextScaled = true
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = titleBar
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 20)
    closeBtnCorner.Parent = closeBtn
    
    closeBtn.Activated:Connect(function()
        frame.Visible = false
    end)

    -- Tab buttons container
    local tabContainer = Instance.new("Frame")
    tabContainer.Size = UDim2.new(1, 0, 0, 60)
    tabContainer.Position = UDim2.new(0, 0, 0, 50)
    tabContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    tabContainer.BorderSizePixel = 0
    tabContainer.Parent = frame

    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tabLayout.Padding = UDim.new(0, 5)
    tabLayout.Parent = tabContainer

    -- Content area
    local contentArea = Instance.new("ScrollingFrame")
    contentArea.Size = UDim2.new(1, 0, 1, -110)
    contentArea.Position = UDim2.new(0, 0, 0, 110)
    contentArea.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentArea.ScrollBarThickness = 8
    contentArea.BackgroundTransparency = 1
    contentArea.BorderSizePixel = 0
    contentArea.Parent = frame

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 8)
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Parent = contentArea

    contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        contentArea.CanvasSize = UDim2.new(0, 0, 0, contentLayout.AbsoluteContentSize.Y + 20)
    end)

    return tabContainer, contentArea
end

-- Create tab function
local function createTab(name, icon, tabContainer, contentArea)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 120, 1, -10)
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.Gotham
    btn.Text = icon .. " " .. name
    btn.TextScaled = true
    btn.BorderSizePixel = 0
    btn.Parent = tabContainer
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    local page = Instance.new("Frame")
    page.Size = UDim2.new(1, 0, 0, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = contentArea

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    tabPages[name] = {page = page, button = btn}

    btn.Activated:Connect(function()
        for tabName, data in pairs(tabPages) do
            data.page.Visible = (tabName == name)
            if tabName == name then
                data.button.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
            else
                data.button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            end
        end
        currentTab = name
    end)

    if not currentTab then
        btn.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        page.Visible = true
        currentTab = name
    end

    return page
end

-- Create button with better mobile touch
local function createButton(text, callback, parent, color)
    color = color or Color3.fromRGB(70, 70, 70)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, isMobile and 50 or 40)
    btn.Position = UDim2.new(0, 10, 0, 0)
    btn.BackgroundColor3 = color
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamSemibold
    btn.Text = text
    btn.TextScaled = true
    btn.BorderSizePixel = 0
    btn.Parent = parent
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn
    
    -- Touch feedback
    btn.Activated:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        task.wait(0.1)
        btn.BackgroundColor3 = color
        if callback then callback() end
    end)
    
    return btn
end

-- Flying system
local function setupFlying()
    local bodyVel, bodyGyro
    
    local function startFly()
        if not hr then return end
        
        bodyVel = Instance.new("BodyVelocity")
        bodyVel.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVel.Velocity = Vector3.new(0, 0, 0)
        bodyVel.Parent = hr
        
        bodyGyro = Instance.new("BodyAngularVelocity")
        bodyGyro.MaxTorque = Vector3.new(4000, 4000, 4000)
        bodyGyro.AngularVelocity = Vector3.new(0, 0, 0)
        bodyGyro.Parent = hr
        
        flying = true
        notify("🚁 Flying Mode ON", Color3.fromRGB(0, 255, 0))
        
        connections.flyLoop = RunService.Heartbeat:Connect(function()
            if not flying or not hr or not bodyVel then return end
            
            local moveVector = Vector3.new(0, 0, 0)
            local rotVector = Vector3.new(0, 0, 0)
            
            if isMobile then
                -- Mobile flying controls (touch to move)
                local cam = camera
                local cf = cam.CFrame
                local forward = cf.LookVector
                local right = cf.RightVector
                local up = cf.UpVector
                
                -- Simple auto-hover
                moveVector = up * (flySpeed * 0.1)
            else
                -- Desktop flying controls
                local cam = camera
                local cf = cam.CFrame
                local forward = cf.LookVector
                local right = cf.RightVector
                local up = cf.UpVector
                
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveVector = moveVector + forward
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveVector = moveVector - forward
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveVector = moveVector - right
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveVector = moveVector + right
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveVector = moveVector + up
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveVector = moveVector - up
                end
            end
            
            bodyVel.Velocity = moveVector * flySpeed
            bodyGyro.AngularVelocity = rotVector
        end)
    end
    
    local function stopFly()
        flying = false
        if bodyVel then bodyVel:Destroy() end
        if bodyGyro then bodyGyro:Destroy() end
        if connections.flyLoop then connections.flyLoop:Disconnect() end
        notify("🚁 Flying Mode OFF", Color3.fromRGB(255, 100, 100))
    end
    
    return startFly, stopFly
end

-- Noclip system
local function setupNoclip()
    local function toggleNoclip()
        noclip = not noclip
        if noclip then
            notify("👻 Noclip ON", Color3.fromRGB(0, 255, 255))
            connections.noclipLoop = RunService.Stepped:Connect(function()
                if not noclip or not char then return end
                for _, part in pairs(char:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end)
        else
            notify("👻 Noclip OFF", Color3.fromRGB(255, 100, 100))
            if connections.noclipLoop then connections.noclipLoop:Disconnect() end
            if char then
                for _, part in pairs(char:GetChildren()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end
    end
    
    return toggleNoclip
end

-- Auto heal system
local function setupAutoHeal()
    local function toggleAutoHeal()
        autoHeal = not autoHeal
        if autoHeal then
            notify("💚 Auto Heal ON", Color3.fromRGB(0, 255, 0))
            connections.healLoop = RunService.Heartbeat:Connect(function()
                if not autoHeal or not humanoid then return end
                if humanoid.Health < humanoid.MaxHealth then
                    humanoid.Health = humanoid.MaxHealth
                end
            end)
        else
            notify("💚 Auto Heal OFF", Color3.fromRGB(255, 100, 100))
            if connections.healLoop then connections.healLoop:Disconnect() end
        end
    end
    
    return toggleAutoHeal
end

-- God mode system
local function setupGodMode()
    local function toggleGodMode()
        godMode = not godMode
        if godMode then
            notify("⚡ God Mode ON", Color3.fromRGB(255, 215, 0))
            if humanoid then
                humanoid.MaxHealth = math.huge
                humanoid.Health = math.huge
            end
        else
            notify("⚡ God Mode OFF", Color3.fromRGB(255, 100, 100))
            if humanoid then
                humanoid.MaxHealth = 100
                humanoid.Health = 100
            end
        end
    end
    
    return toggleGodMode
end

-- Position save/load system
local function setupPositions()
    local function savePosition(name)
        if not hr then return end
        savedPositions[name] = hr.CFrame
        notify("📍 Position '" .. name .. "' saved!", Color3.fromRGB(0, 255, 0))
    end
    
    local function loadPosition(name)
        if not hr or not savedPositions[name] then return end
        hr.CFrame = savedPositions[name]
        notify("📍 Teleported to '" .. name .. "'!", Color3.fromRGB(0, 255, 255))
    end
    
    return savePosition, loadPosition
end

-- Player interaction system
local function setupPlayerSystem()
    local playerListFrame
    local selectedPlayer = nil
    
    local function createPlayerList(parent)
        playerListFrame = Instance.new("ScrollingFrame")
        playerListFrame.Size = UDim2.new(1, -20, 0, 300)
        playerListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        playerListFrame.ScrollBarThickness = 8
        playerListFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        playerListFrame.BorderSizePixel = 0
        playerListFrame.Parent = parent
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = playerListFrame

        local listLayout = Instance.new("UIListLayout")
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Padding = UDim.new(0, 4)
        listLayout.Parent = playerListFrame

        listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            playerListFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
        end)
        
        return playerListFrame
    end
    
    local function refreshPlayerList()
        if not playerListFrame then return end
        
        for _, child in ipairs(playerListFrame:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then
                createButton("🎮 " .. p.Name, function()
                    selectedPlayer = p
                    -- Clear previous action buttons
                    for _, child in ipairs(playerListFrame:GetChildren()) do
                        if child:IsA("TextButton") and child.Text:find("🔄") then
                            child:Destroy()
                        end
                    end
                    
                    -- Create action buttons
                    createButton("🔄 Teleport to " .. p.Name, function()
                        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and hr then
                            hr.CFrame = p.Character.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
                            notify("Teleported to " .. p.Name, Color3.fromRGB(0, 255, 255))
                        end
                    end, playerListFrame, Color3.fromRGB(0, 150, 255))
                    
                    createButton("🎯 Follow " .. p.Name, function()
                        followTarget = p
                        notify("Following " .. p.Name, Color3.fromRGB(255, 165, 0))
                        if connections.followLoop then connections.followLoop:Disconnect() end
                        connections.followLoop = RunService.Heartbeat:Connect(function()
                            if followTarget and followTarget.Character and followTarget.Character:FindFirstChild("HumanoidRootPart") and hr then
                                hr.CFrame = followTarget.Character.HumanoidRootPart.CFrame + Vector3.new(0, 5, 5)
                            end
                        end)
                    end, playerListFrame, Color3.fromRGB(255, 165, 0))
                    
                    createButton("🧲 Bring " .. p.Name, function()
                        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and hr then
                            p.Character.HumanoidRootPart.CFrame = hr.CFrame + Vector3.new(0, 0, -5)
                            notify("Brought " .. p.Name, Color3.fromRGB(255, 0, 255))
                        end
                    end, playerListFrame, Color3.fromRGB(255, 0, 255))
                    
                    createButton("🚫 Stop Follow", function()
                        followTarget = nil
                        if connections.followLoop then connections.followLoop:Disconnect() end
                        notify("Stopped following", Color3.fromRGB(255, 100, 100))
                    end, playerListFrame, Color3.fromRGB(255, 100, 100))
                    
                end, playerListFrame)
            end
        end
    end
    
    return createPlayerList, refreshPlayerList
end

-- Main setup function
local function setupUI()
    createGUI()
    makeDraggable(logo)
    
    logo.Activated:Connect(function()
        frame.Visible = not frame.Visible
        if frame.Visible then
            TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Size = frame.Size}):Play()
        end
    end)
    
    local tabContainer, contentArea = createTabSystem()
    
    -- Movement Tab
    local movementTab = createTab("Movement", "🚀", tabContainer, contentArea)
    local startFly, stopFly = setupFlying()
    
    createButton("🚁 Toggle Flying", function()
        if flying then stopFly() else startFly() end
    end, movementTab)
    
    local toggleNoclip = setupNoclip()
    createButton("👻 Toggle Noclip", toggleNoclip, movementTab)
    
    createButton("⚡ Fly Speed +", function()
        flySpeed = flySpeed + 5
        notify("Fly Speed: " .. flySpeed, Color3.fromRGB(255, 255, 0))
    end, movementTab)
    
    createButton("⚡ Fly Speed -", function()
        flySpeed = math.max(1, flySpeed - 5)
        notify("Fly Speed: " .. flySpeed, Color3.fromRGB(255, 255, 0))
    end, movementTab)
    
    -- Player Tab
    local playerTab = createTab("Player", "🎮", tabContainer, contentArea)
    local createPlayerList, refreshPlayerList = setupPlayerSystem()
    local playerList = createPlayerList(playerTab)
    
    createButton("🔄 Refresh Player List", refreshPlayerList, playerTab, Color3.fromRGB(0, 150, 255))
    
    -- Utility Tab
    local utilityTab = createTab("Utility", "🛠️", tabContainer, contentArea)
    local toggleAutoHeal = setupAutoHeal()
    local toggleGodMode = setupGodMode()
    local savePosition, loadPosition = setupPositions()
    
    createButton("💚 Toggle Auto Heal", toggleAutoHeal, utilityTab)
    createButton("⚡ Toggle God Mode", toggleGodMode, utilityTab)
    
    createButton("📍 Save Position 1", function()
        savePosition("pos1")
    end, utilityTab, Color3.fromRGB(0, 255, 0))
    
    createButton("📍 Load Position 1", function()
        loadPosition("pos1")
    end, utilityTab, Color3.fromRGB(0, 255, 255))
    
    createButton("📍 Save Position 2", function()
        savePosition("pos2") 
    end, utilityTab, Color3.fromRGB(0, 255, 0))
    
    createButton("📍 Load Position 2", function()
        loadPosition("pos2")
    end, utilityTab, Color3.fromRGB(0, 255, 255))
    
    createButton("🏠 Go to Spawn", function()
        if hr then
            hr.CFrame = CFrame.new(0, 50, 0)
            notify("Teleported to spawn", Color3.fromRGB(0, 255, 255))
        end
    end, utilityTab)
    
    -- Settings Tab
    local settingsTab = createTab("Settings", "⚙️", tabContainer, contentArea)
    
    createButton("🔄 Reset Character", function()
        if humanoid then
            humanoid.Health = 0
            notify("Character reset", Color3.fromRGB(255, 100, 100))
        end
    end, settingsTab, Color3.fromRGB(255, 100, 100))
    
    createButton("🧹 Clean Workspace", function()
        for _, obj in pairs(workspace:GetChildren()) do
            if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) and obj.Name ~= "Terrain" then
                obj:Destroy()
            end
        end
        notify("Workspace cleaned", Color3.fromRGB(0, 255, 0))
    end, settingsTab)
    
    createButton("📱 Mobile Optimize", function()
        -- Reduce graphics for better performance
        settings().Rendering.QualityLevel = 1
        notify("Optimized for mobile", Color3.fromRGB(0, 255, 0))
    end, settingsTab)
    
    -- Initialize
    initChar()
    refreshPlayerList()
    
    -- Auto-refresh player list
    Players.PlayerAdded:Connect(refreshPlayerList)
    Players.PlayerRemoving:Connect(refreshPlayerList)
    
    -- Character respawn handling
    player.CharacterAdded:Connect(function()
        task.wait(1)
        initChar()
        notify("Character loaded", Color3.fromRGB(0, 255, 0))
    end)
    
    notify("🚀 Super Tool Mobile Loaded!", Color3.fromRGB(0, 255, 0))
end

-- Cleanup function
local function cleanup()
    for _, connection in pairs(connections) do
        if connection then connection:Disconnect() end
    end
    if gui then gui:Destroy() end
end

-- Initialize
setupUI()

-- Cleanup on leave
game:BindToClose(cleanup)
player.AncestryChanged:Connect(function()
    if not player.Parent then cleanup() end
end)