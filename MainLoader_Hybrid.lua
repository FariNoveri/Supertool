-- MainLoader Minimalis - Android Optimized
-- UI minimalis dengan kategori di kiri, tanpa emoji, warna hitam

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Variabel utama
local gui, logo, frame
local humanoid, hr, char
local selectedPlayer = nil
local flying, freecam, noclip, godMode = false, false, false, false
local speedEnabled, jumpEnabled, waterWalk = false, false, false
local flySpeed = 40
local moveSpeed = 50
local jumpPower = 100
local connections = {}

-- Position system
local savedPositions = {}
local positionCounter = 0
local currentCategory = "General"

-- Notification function
local function notify(message, color)
    color = color or Color3.fromRGB(200, 200, 200)
    local notification = Instance.new("ScreenGui")
    notification.Name = "Notification"
    notification.Parent = game.CoreGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 250, 0, 40)
    frame.Position = UDim2.new(0.5, -125, 0.1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BorderSizePixel = 0
    frame.Parent = notification
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, -20, 1, 0)
    text.Position = UDim2.new(0, 10, 0, 0)
    text.BackgroundTransparency = 1
    text.TextColor3 = color
    text.Text = message
    text.TextSize = 14
    text.Font = Enum.Font.Gotham
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = frame
    
    -- Auto destroy
    game:GetService("Debris"):AddItem(notification, 3)
end

-- Drag function
local function makeDraggable(guiElement, dragHandle)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    dragHandle = dragHandle or guiElement
    
    local function updateDrag(input)
        local delta = input.Position - dragStart
        guiElement.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
    
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiElement.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                updateDrag(input)
            end
        end
    end)
end

-- Character initialization
local function initChar()
    local success, errorMsg = pcall(function()
        char = player.Character or player.CharacterAdded:Wait()
        humanoid = char:WaitForChild("Humanoid", 10)
        hr = char:WaitForChild("HumanoidRootPart", 10)
        
        if humanoid and hr then
            notify("Character loaded", Color3.fromRGB(100, 255, 100))
        end
    end)
    
    if not success then
        notify("Character init failed", Color3.fromRGB(255, 100, 100))
        task.wait(2)
        initChar()
    end
end

-- Movement functions
local function toggleFly()
    flying = not flying
    
    if flying then
        if not hr then
            flying = false
            notify("No character", Color3.fromRGB(255, 100, 100))
            return
        end
        
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(4000, 4000, 4000)
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent = hr
        
        connections.fly = RunService.Heartbeat:Connect(function()
            if not hr or not hr.Parent then
                flying = false
                if connections.fly then
                    connections.fly:Disconnect()
                end
                return
            end
            
            local moveVector = Vector3.new(0, 0, 0)
            
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveVector = moveVector + camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveVector = moveVector - camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveVector = moveVector - camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveVector = moveVector + camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveVector = moveVector + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                moveVector = moveVector - Vector3.new(0, 1, 0)
            end
            
            if moveVector.Magnitude > 0 then
                bv.Velocity = moveVector.Unit * flySpeed
            else
                bv.Velocity = Vector3.new(0, 0, 0)
            end
        end)
        
        notify("Fly enabled", Color3.fromRGB(100, 255, 100))
    else
        if connections.fly then
            connections.fly:Disconnect()
            connections.fly = nil
        end
        if hr and hr:FindFirstChild("BodyVelocity") then
            hr.BodyVelocity:Destroy()
        end
        notify("Fly disabled", Color3.fromRGB(255, 100, 100))
    end
end

local function toggleSpeed()
    speedEnabled = not speedEnabled
    
    if speedEnabled then
        if humanoid then
            humanoid.WalkSpeed = moveSpeed
            notify("Speed enabled", Color3.fromRGB(100, 255, 100))
        end
    else
        if humanoid then
            humanoid.WalkSpeed = 16
            notify("Speed disabled", Color3.fromRGB(255, 100, 100))
        end
    end
end

local function toggleJump()
    jumpEnabled = not jumpEnabled
    
    if jumpEnabled then
        if humanoid then
            humanoid.JumpPower = jumpPower
            notify("Jump boost enabled", Color3.fromRGB(100, 255, 100))
        end
    else
        if humanoid then
            humanoid.JumpPower = 50
            notify("Jump boost disabled", Color3.fromRGB(255, 100, 100))
        end
    end
end

local function toggleNoclip()
    noclip = not noclip
    
    if noclip then
        connections.noclip = RunService.Stepped:Connect(function()
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
        notify("Noclip enabled", Color3.fromRGB(100, 255, 100))
    else
        if connections.noclip then
            connections.noclip:Disconnect()
            connections.noclip = nil
        end
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
        notify("Noclip disabled", Color3.fromRGB(255, 100, 100))
    end
end

local function toggleWaterWalk()
    waterWalk = not waterWalk
    
    if waterWalk then
        connections.waterWalk = RunService.Stepped:Connect(function()
            if hr then
                local raycast = workspace:Raycast(hr.Position, Vector3.new(0, -10, 0))
                if raycast and raycast.Instance.Name:lower():find("water") then
                    hr.Position = Vector3.new(hr.Position.X, raycast.Position.Y + 3, hr.Position.Z)
                end
            end
        end)
        notify("Water walk enabled", Color3.fromRGB(100, 255, 100))
    else
        if connections.waterWalk then
            connections.waterWalk:Disconnect()
            connections.waterWalk = nil
        end
        notify("Water walk disabled", Color3.fromRGB(255, 100, 100))
    end
end

local function toggleGodMode()
    godMode = not godMode
    
    if godMode then
        if humanoid then
            humanoid.MaxHealth = math.huge
            humanoid.Health = math.huge
            
            connections.godMode = humanoid.HealthChanged:Connect(function()
                if humanoid.Health < humanoid.MaxHealth then
                    humanoid.Health = humanoid.MaxHealth
                end
            end)
        end
        notify("God mode enabled", Color3.fromRGB(100, 255, 100))
    else
        if connections.godMode then
            connections.godMode:Disconnect()
            connections.godMode = nil
        end
        if humanoid then
            humanoid.MaxHealth = 100
            humanoid.Health = 100
        end
        notify("God mode disabled", Color3.fromRGB(255, 100, 100))
    end
end

-- Teleport functions
local function teleportToSpawn()
    if not hr then
        notify("No character", Color3.fromRGB(255, 100, 100))
        return
    end
    
    local spawn = workspace:FindFirstChild("SpawnLocation") or workspace:FindFirstChild("Spawn")
    if spawn then
        hr.CFrame = CFrame.new(spawn.Position + Vector3.new(0, 5, 0))
    else
        hr.CFrame = CFrame.new(0, 50, 0)
    end
    notify("Teleported to spawn", Color3.fromRGB(100, 255, 100))
end

local function savePosition()
    if not hr then
        notify("No character", Color3.fromRGB(255, 100, 100))
        return
    end
    
    positionCounter = positionCounter + 1
    local posData = {
        name = "Position " .. positionCounter,
        position = hr.Position,
        cframe = hr.CFrame
    }
    
    table.insert(savedPositions, posData)
    notify("Position saved: " .. posData.name, Color3.fromRGB(100, 255, 100))
end

-- Player functions
local function showPlayerList()
    local playerFrame = Instance.new("Frame")
    playerFrame.Size = UDim2.new(0, 200, 0, 300)
    playerFrame.Position = UDim2.new(0.5, -100, 0.5, -150)
    playerFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    playerFrame.BorderSizePixel = 0
    playerFrame.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = playerFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(200, 200, 200)
    title.Text = "Players"
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.Parent = playerFrame
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -25, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 12
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = playerFrame
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -10, 1, -40)
    scrollFrame.Position = UDim2.new(0, 5, 0, 35)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.Parent = playerFrame
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.Parent = scrollFrame
    
    -- Add players
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 25)
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            btn.TextColor3 = Color3.fromRGB(200, 200, 200)
            btn.Text = plr.Name
            btn.TextSize = 12
            btn.Font = Enum.Font.Gotham
            btn.Parent = scrollFrame
            
            btn.MouseButton1Click:Connect(function()
                selectedPlayer = plr
                notify("Selected: " .. plr.Name, Color3.fromRGB(100, 255, 100))
                playerFrame:Destroy()
            end)
        end
    end
    
    closeBtn.MouseButton1Click:Connect(function()
        playerFrame:Destroy()
    end)
    
    makeDraggable(playerFrame, title)
end

local function teleportToPlayer()
    if not selectedPlayer then
        notify("No player selected", Color3.fromRGB(255, 100, 100))
        return
    end
    
    if not selectedPlayer.Character or not selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
        notify("Player not available", Color3.fromRGB(255, 100, 100))
        return
    end
    
    if not hr then
        notify("No character", Color3.fromRGB(255, 100, 100))
        return
    end
    
    hr.CFrame = selectedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 5)
    notify("Teleported to " .. selectedPlayer.Name, Color3.fromRGB(100, 255, 100))
end

-- Create minimalist GUI
local function createGUI()
    -- Clean up old GUI
    if gui then gui:Destroy() end
    
    -- Main ScreenGui
    gui = Instance.new("ScreenGui")
    gui.Name = "MainLoaderMinimal"
    gui.ResetOnSpawn = false
    gui.Parent = game.CoreGui
    
    -- Logo button (minimalist)
    logo = Instance.new("TextButton")
    logo.Size = UDim2.new(0, 50, 0, 50)
    logo.Position = UDim2.new(1, -70, 1, -70)
    logo.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    logo.BorderSizePixel = 0
    logo.TextColor3 = Color3.fromRGB(200, 200, 200)
    logo.Text = "ML"
    logo.TextSize = 18
    logo.Font = Enum.Font.GothamBold
    logo.Parent = gui
    
    local logoCorner = Instance.new("UICorner")
    logoCorner.CornerRadius = UDim.new(0, 8)
    logoCorner.Parent = logo
    
    -- Main frame (smaller and minimalist)
    frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 600, 0, 350)
    frame.Position = UDim2.new(0.5, -300, 0.5, -175)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = gui
    
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 8)
    frameCorner.Parent = frame
    
    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    header.BorderSizePixel = 0
    header.Parent = frame
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 8)
    headerCorner.Parent = header
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 15, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(200, 200, 200)
    title.Text = "MainLoader"
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Text = "X"
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = header
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 4)
    closeBtnCorner.Parent = closeBtn
    
    -- Left sidebar (categories)
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 120, 1, -40)
    sidebar.Position = UDim2.new(0, 0, 0, 40)
    sidebar.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    sidebar.BorderSizePixel = 0
    sidebar.Parent = frame
    
    -- Content area
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -120, 1, -40)
    content.Position = UDim2.new(0, 120, 0, 40)
    content.BackgroundTransparency = 1
    content.Parent = frame
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -10, 1, -10)
    scrollFrame.Position = UDim2.new(0, 5, 0, 5)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.Parent = content
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.Parent = scrollFrame
    
    -- Function to create category button
    local function createCategoryBtn(text, category)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 35)
        btn.Position = UDim2.new(0, 5, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        btn.BorderSizePixel = 0
        btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        btn.Text = text
        btn.TextSize = 12
        btn.Font = Enum.Font.Gotham
        btn.Parent = sidebar
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = btn
        
        return btn
    end
    
    -- Function to create feature button
    local function createFeatureBtn(text, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        btn.BorderSizePixel = 0
        btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        btn.Text = text
        btn.TextSize = 12
        btn.Font = Enum.Font.Gotham
        btn.Parent = scrollFrame
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            local success, err = pcall(callback)
            if not success then
                notify("Error: " .. tostring(err), Color3.fromRGB(255, 100, 100))
            end
        end)
        
        return btn
    end
    
    -- Function to show category content
    local function showCategory(categoryName)
        -- Clear existing buttons
        for _, child in pairs(scrollFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        -- Reset sidebar buttons
        for _, child in pairs(sidebar:GetChildren()) do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            end
        end
        
        -- Highlight active category
        for _, child in pairs(sidebar:GetChildren()) do
            if child:IsA("TextButton") and child.Text == categoryName then
                child.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            end
        end
        
        -- Add category content
        if categoryName == "Movement" then
            createFeatureBtn("Toggle Fly", toggleFly)
            createFeatureBtn("Toggle Speed", toggleSpeed)
            createFeatureBtn("Toggle Jump", toggleJump)
            createFeatureBtn("Toggle Noclip", toggleNoclip)
            createFeatureBtn("Toggle Water Walk", toggleWaterWalk)
        elseif categoryName == "Teleport" then
            createFeatureBtn("Teleport to Spawn", teleportToSpawn)
            createFeatureBtn("Save Position", savePosition)
        elseif categoryName == "Player" then
            createFeatureBtn("Show Players", showPlayerList)
            createFeatureBtn("Teleport to Player", teleportToPlayer)
        elseif categoryName == "Misc" then
            createFeatureBtn("Toggle God Mode", toggleGodMode)
        end
    end
    
    -- Create category buttons
    local movementBtn = createCategoryBtn("Movement", "Movement")
    local teleportBtn = createCategoryBtn("Teleport", "Teleport")
    local playerBtn = createCategoryBtn("Player", "Player")
    local miscBtn = createCategoryBtn("Misc", "Misc")
    
    -- Position category buttons
    movementBtn.Position = UDim2.new(0, 5, 0, 10)
    teleportBtn.Position = UDim2.new(0, 5, 0, 50)
    playerBtn.Position = UDim2.new(0, 5, 0, 90)
    miscBtn.Position = UDim2.new(0, 5, 0, 130)
    
    -- Connect category buttons
    movementBtn.MouseButton1Click:Connect(function() showCategory("Movement") end)
    teleportBtn.MouseButton1Click:Connect(function() showCategory("Teleport") end)
    playerBtn.MouseButton1Click:Connect(function() showCategory("Player") end)
    miscBtn.MouseButton1Click:Connect(function() showCategory("Misc") end)
    
    -- Logo functionality
    logo.MouseButton1Click:Connect(function()
        frame.Visible = not frame.Visible
        if frame.Visible then
            logo.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            showCategory("Movement") -- Show default category
        else
            logo.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        end
    end)
    
    -- Close button functionality
    closeBtn.MouseButton1Click:Connect(function()
        frame.Visible = false
        logo.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    end)
    
    -- Make draggable
    makeDraggable(frame, header)
    makeDraggable(logo)
    
    notify("MainLoader ready", Color3.fromRGB(100, 255, 100))
end

-- Main function
local function main()
    -- Wait for game to load
    task.wait(1)
    
    -- Initialize character
    initChar()
    
    -- Create GUI
    createGUI()
    
    -- Handle character respawning
    player.CharacterAdded:Connect(function()
        task.wait(1)
        initChar()
    end)
    
    notify("MainLoader loaded - Tap ML button", Color3.fromRGB(100, 255, 100))
end

-- Start the script
main()