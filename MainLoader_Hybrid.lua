-- MainLoader Minimalist Version: UI Kiri + Fungsi Fixed
-- Desain minimalis dengan kategori di kiri dan fungsi yang diperbaiki

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Variables
local gui, logo, frame
local humanoid, hr, char
local selectedPlayer = nil
local spectatingPlayer = nil
local flying, freecam, noclip, godMode = false, false, false, false
local flySpeed = 40
local speedEnabled, jumpEnabled, waterWalk = false, false, false
local moveSpeed = 50
local jumpPower = 100
local savedPositions = {}
local positionCounter = 0
local connections = {}

-- Enhanced position saving system
local categories = {
    "General",
    "Spawn", 
    "Checkpoint",
    "Important"
}
local currentCategory = "General"

-- Notification function (improved)
local function notify(message, color)
    color = color or Color3.fromRGB(255, 255, 255)
    local notification = Instance.new("ScreenGui")
    notification.Name = "Notification"
    notification.Parent = game.CoreGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 45)
    frame.Position = UDim2.new(0.5, -140, 0.05, 0)
    frame.BackgroundColor3 = color
    frame.BorderSizePixel = 0
    frame.Parent = notification
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, -20, 1, 0)
    text.Position = UDim2.new(0, 10, 0, 0)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.Text = message
    text.TextSize = 14
    text.Font = Enum.Font.GothamMedium
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = frame
    
    -- Animation
    frame.Position = UDim2.new(0.5, -140, -0.1, 0)
    local tween = TweenService:Create(frame, TweenInfo.new(0.3), {Position = UDim2.new(0.5, -140, 0.05, 0)})
    tween:Play()
    
    task.wait(2.5)
    
    local tweenOut = TweenService:Create(frame, TweenInfo.new(0.3), {Position = UDim2.new(0.5, -140, -0.1, 0)})
    tweenOut:Play()
    tweenOut.Completed:Connect(function()
        notification:Destroy()
    end)
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
    
    dragHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- Character initialization (improved)
local function initChar()
    local success, errorMsg = pcall(function()
        if not player.Character then
            player.CharacterAdded:Wait()
        end
        
        char = player.Character
        humanoid = char:WaitForChild("Humanoid", 10)
        hr = char:WaitForChild("HumanoidRootPart", 10)
        
        if not humanoid or not hr then
            error("Failed to find Humanoid or HumanoidRootPart")
        end
        
        notify("✅ Character loaded", Color3.fromRGB(0, 255, 0))
    end)
    
    if not success then
        notify("⚠️ Character init failed: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
        task.wait(2)
        initChar()
    end
end

-- Movement functions (fixed)
local function toggleFly()
    flying = not flying
    local success, errorMsg = pcall(function()
        if flying then
            if not hr or not humanoid then
                flying = false
                error("Character not loaded")
            end
            
            -- Remove existing BodyVelocity
            local existingBV = hr:FindFirstChildOfClass("BodyVelocity")
            if existingBV then
                existingBV:Destroy()
            end
            
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(4000, 4000, 4000)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = hr
            
            connections.fly = RunService.Heartbeat:Connect(function()
                if not hr or not bv or not bv.Parent then
                    flying = false
                    if connections.fly then
                        connections.fly:Disconnect()
                        connections.fly = nil
                    end
                    return
                end
                
                local moveVector = humanoid.MoveDirection
                local cameraDirection = camera.CFrame.LookVector
                local rightVector = camera.CFrame.RightVector
                
                local flyDirection = Vector3.new(0, 0, 0)
                
                if moveVector.Magnitude > 0 then
                    flyDirection = (cameraDirection * moveVector.Z + rightVector * moveVector.X) * flySpeed
                end
                
                -- Add vertical movement
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    flyDirection = flyDirection + Vector3.new(0, flySpeed, 0)
                elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    flyDirection = flyDirection + Vector3.new(0, -flySpeed, 0)
                end
                
                bv.Velocity = flyDirection
            end)
            
            notify("🛫 Fly Enabled", Color3.fromRGB(0, 255, 0))
        else
            if connections.fly then
                connections.fly:Disconnect()
                connections.fly = nil
            end
            
            local bv = hr:FindFirstChildOfClass("BodyVelocity")
            if bv then
                bv:Destroy()
            end
            
            notify("🛬 Fly Disabled", Color3.fromRGB(255, 255, 0))
        end
    end)
    
    if not success then
        flying = false
        if connections.fly then
            connections.fly:Disconnect()
            connections.fly = nil
        end
        notify("⚠️ Fly error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleSpeed()
    speedEnabled = not speedEnabled
    local success, errorMsg = pcall(function()
        if not humanoid then
            error("Humanoid not found")
        end
        
        if speedEnabled then
            humanoid.WalkSpeed = moveSpeed
            notify("🏃 Speed Enabled (" .. moveSpeed .. ")", Color3.fromRGB(0, 255, 0))
        else
            humanoid.WalkSpeed = 16
            notify("🏃 Speed Disabled", Color3.fromRGB(255, 255, 0))
        end
    end)
    
    if not success then
        speedEnabled = false
        notify("⚠️ Speed error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleJump()
    jumpEnabled = not jumpEnabled
    local success, errorMsg = pcall(function()
        if not humanoid then
            error("Humanoid not found")
        end
        
        if jumpEnabled then
            humanoid.JumpPower = jumpPower
            notify("🦘 Jump Enabled (" .. jumpPower .. ")", Color3.fromRGB(0, 255, 0))
        else
            humanoid.JumpPower = 50
            notify("🦘 Jump Disabled", Color3.fromRGB(255, 255, 0))
        end
    end)
    
    if not success then
        jumpEnabled = false
        notify("⚠️ Jump error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleNoclip()
    noclip = not noclip
    local success, errorMsg = pcall(function()
        if noclip then
            connections.noclip = RunService.Stepped:Connect(function()
                if char then
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            part.CanCollide = false
                        end
                    end
                end
            end)
            notify("🚪 Noclip Enabled", Color3.fromRGB(0, 255, 0))
        else
            if connections.noclip then
                connections.noclip:Disconnect()
                connections.noclip = nil
            end
            
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
            notify("🚪 Noclip Disabled", Color3.fromRGB(255, 255, 0))
        end
    end)
    
    if not success then
        noclip = false
        if connections.noclip then
            connections.noclip:Disconnect()
            connections.noclip = nil
        end
        notify("⚠️ Noclip error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleWaterWalk()
    waterWalk = not waterWalk
    local success, errorMsg = pcall(function()
        if waterWalk then
            connections.waterWalk = RunService.Stepped:Connect(function()
                if humanoid and hr and humanoid.MoveDirection.Magnitude > 0 then
                    local raycast = workspace:Raycast(hr.Position, Vector3.new(0, -10, 0))
                    if raycast and raycast.Instance then
                        local hit = raycast.Instance
                        if hit.Name:lower():find("water") or hit.Material == Enum.Material.Water then
                            local waterSurface = raycast.Position.Y
                            hr.Position = Vector3.new(hr.Position.X, waterSurface + 3, hr.Position.Z)
                        end
                    end
                end
            end)
            notify("🌊 Water Walk Enabled", Color3.fromRGB(0, 255, 0))
        else
            if connections.waterWalk then
                connections.waterWalk:Disconnect()
                connections.waterWalk = nil
            end
            notify("🌊 Water Walk Disabled", Color3.fromRGB(255, 255, 0))
        end
    end)
    
    if not success then
        waterWalk = false
        if connections.waterWalk then
            connections.waterWalk:Disconnect()
            connections.waterWalk = nil
        end
        notify("⚠️ Water Walk error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleGodMode()
    godMode = not godMode
    local success, errorMsg = pcall(function()
        if not humanoid then
            error("Humanoid not found")
        end
        
        if godMode then
            humanoid.MaxHealth = math.huge
            humanoid.Health = math.huge
            
            connections.godMode = humanoid.HealthChanged:Connect(function(health)
                if health < math.huge then
                    humanoid.Health = math.huge
                end
            end)
            
            notify("🛡️ God Mode Enabled", Color3.fromRGB(0, 255, 0))
        else
            if connections.godMode then
                connections.godMode:Disconnect()
                connections.godMode = nil
            end
            
            humanoid.MaxHealth = 100
            humanoid.Health = 100
            notify("🛡️ God Mode Disabled", Color3.fromRGB(255, 255, 0))
        end
    end)
    
    if not success then
        godMode = false
        if connections.godMode then
            connections.godMode:Disconnect()
            connections.godMode = nil
        end
        notify("⚠️ God Mode error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Teleport functions
local function teleportToSpawn()
    local success, errorMsg = pcall(function()
        if not hr then
            error("Character not loaded")
        end
        
        local spawnLocation = workspace:FindFirstChild("SpawnLocation") or workspace:FindFirstChild("Spawn")
        if spawnLocation then
            hr.CFrame = CFrame.new(spawnLocation.Position + Vector3.new(0, 5, 0))
            notify("🚪 Teleported to spawn", Color3.fromRGB(0, 255, 0))
        else
            hr.CFrame = CFrame.new(0, 50, 0)
            notify("🚪 Teleported to default spawn", Color3.fromRGB(0, 255, 0))
        end
    end)
    
    if not success then
        notify("⚠️ Teleport error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function saveCurrentPosition()
    local success, errorMsg = pcall(function()
        if not hr then
            error("Character not loaded")
        end
        
        positionCounter = positionCounter + 1
        local positionName = "Position " .. positionCounter
        local positionData = {
            name = positionName,
            position = hr.Position,
            cframe = hr.CFrame,
            category = currentCategory,
            timestamp = os.time()
        }
        
        table.insert(savedPositions, positionData)
        notify("💾 Position saved: " .. positionName, Color3.fromRGB(0, 255, 0))
    end)
    
    if not success then
        notify("⚠️ Save position error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function showPositionList()
    -- Create simple position selector
    local posGui = Instance.new("ScreenGui")
    posGui.Name = "PositionList"
    posGui.Parent = game.CoreGui
    
    local posFrame = Instance.new("Frame")
    posFrame.Size = UDim2.new(0, 300, 0, 400)
    posFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
    posFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    posFrame.BorderSizePixel = 0
    posFrame.Parent = posGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = posFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.Text = "📍 Saved Positions"
    title.Parent = posFrame
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Text = "×"
    closeBtn.TextSize = 16
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = posFrame
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 5)
    closeCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        posGui:Destroy()
    end)
    
    -- Scroll frame
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -20, 1, -50)
    scrollFrame.Position = UDim2.new(0, 10, 0, 40)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 5
    scrollFrame.Parent = posFrame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.Padding = UDim.new(0, 5)
    listLayout.Parent = scrollFrame
    
    -- Add position buttons
    for i, posData in ipairs(savedPositions) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 35)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 12
        btn.Font = Enum.Font.Gotham
        btn.Text = posData.name .. " (" .. posData.category .. ")"
        btn.Parent = scrollFrame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 5)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            if hr and posData.cframe then
                hr.CFrame = posData.cframe
                notify("🚀 Teleported to " .. posData.name, Color3.fromRGB(0, 255, 0))
                posGui:Destroy()
            end
        end)
    end
    
    -- Update canvas size
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #savedPositions * 40)
    
    makeDraggable(posFrame, title)
    notify("📍 Position List Opened", Color3.fromRGB(0, 255, 255))
end

-- Player functions
local function showPlayerList()
    local playerGui = Instance.new("ScreenGui")
    playerGui.Name = "PlayerList"
    playerGui.Parent = game.CoreGui
    
    local playerFrame = Instance.new("Frame")
    playerFrame.Size = UDim2.new(0, 250, 0, 350)
    playerFrame.Position = UDim2.new(0.5, -125, 0.5, -175)
    playerFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    playerFrame.BorderSizePixel = 0
    playerFrame.Parent = playerGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = playerFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.Text = "👥 Players"
    title.Parent = playerFrame
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Text = "×"
    closeBtn.TextSize = 16
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = playerFrame
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 5)
    closeCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        playerGui:Destroy()
    end)
    
    -- Scroll frame
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -20, 1, -50)
    scrollFrame.Position = UDim2.new(0, 10, 0, 40)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 5
    scrollFrame.Parent = playerFrame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.Padding = UDim.new(0, 3)
    listLayout.Parent = scrollFrame
    
    -- Add player buttons
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 30)
            btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.TextSize = 12
            btn.Font = Enum.Font.Gotham
            btn.Text = plr.Name
            btn.Parent = scrollFrame
            
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 5)
            btnCorner.Parent = btn
            
            btn.MouseButton1Click:Connect(function()
                selectedPlayer = plr
                notify("👤 Selected: " .. plr.Name, Color3.fromRGB(0, 255, 255))
                playerGui:Destroy()
            end)
        end
    end
    
    -- Update canvas size
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #Players:GetPlayers() * 35)
    
    makeDraggable(playerFrame, title)
    notify("👥 Player List Opened", Color3.fromRGB(0, 255, 255))
end

local function teleportToPlayer()
    if not selectedPlayer then
        notify("⚠️ No player selected", Color3.fromRGB(255, 100, 100))
        return
    end
    
    local success, errorMsg = pcall(function()
        if not selectedPlayer.Character then
            error(selectedPlayer.Name .. " has no character")
        end
        
        local targetRootPart = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not targetRootPart then
            error(selectedPlayer.Name .. " has no root part")
        end
        
        if not hr then
            error("Your character not loaded")
        end
        
        hr.CFrame = CFrame.new(targetRootPart.Position + Vector3.new(0, 5, 0))
        notify("🚀 Teleported to " .. selectedPlayer.Name, Color3.fromRGB(0, 255, 0))
    end)
    
    if not success then
        notify("⚠️ Teleport error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Create minimalist GUI
local function createGUI()
    local success, errorMsg = pcall(function()
        -- Clean up old GUI
        local oldGui = game.CoreGui:FindFirstChild("MainLoaderMinimal")
        if oldGui then
            oldGui:Destroy()
        end
        
        -- Create ScreenGui
        gui = Instance.new("ScreenGui")
        gui.Name = "MainLoaderMinimal"
        gui.ResetOnSpawn = false
        gui.Parent = game.CoreGui
        
        -- Create logo button (smaller, bottom-right)
        logo = Instance.new("TextButton")
        logo.Size = UDim2.new(0, 50, 0, 50)
        logo.Position = UDim2.new(1, -60, 1, -60)
        logo.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        logo.TextColor3 = Color3.fromRGB(255, 255, 255)
        logo.Text = "⚡"
        logo.TextSize = 20
        logo.Font = Enum.Font.GothamBold
        logo.ZIndex = 1000
        logo.Parent = gui
        
        -- Logo styling
        local logoCorner = Instance.new("UICorner")
        logoCorner.CornerRadius = UDim.new(0, 25)
        logoCorner.Parent = logo
        
        local logoStroke = Instance.new("UIStroke")
        logoStroke.Color = Color3.fromRGB(100, 100, 100)
        logoStroke.Thickness = 1
        logoStroke.Parent = logo
        
        -- Main frame (smaller, minimalist)
        frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 500, 0, 350)
        frame.Position = UDim2.new(0.5, -250, 0.5, -175)
        frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        frame.BackgroundTransparency = 0.05
        frame.BorderSizePixel = 0
        frame.Visible = false
        frame.ZIndex = 100
        frame.Parent = gui
        
        local frameCorner = Instance.new("UICorner")
        frameCorner.CornerRadius = UDim.new(0, 8)
        frameCorner.Parent = frame
        
        local frameStroke = Instance.new("UIStroke")
        frameStroke.Color = Color3.fromRGB(50, 50, 50)
        frameStroke.Thickness = 1
        frameStroke.Parent = frame
        
        -- Header
        local header = Instance.new("Frame")
        header.Size = UDim2.new(1, 0, 0, 40)
        header.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        header.BorderSizePixel = 0
        header.ZIndex = 101
        header.Parent = frame
        
        local headerCorner = Instance.new("UICorner")
        headerCorner.CornerRadius = UDim.new(0, 8)
        headerCorner.Parent = header
        
        -- Title
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -50, 1, 0)
        title.Position = UDim2.new(0, 15, 0, 0)
        title.BackgroundTransparency = 1
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 14
        title.Font = Enum.Font.GothamBold
        title.Text = "MainLoader Minimal"
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.ZIndex = 102
        title.Parent = header
        
        -- Close button
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 30, 0, 30)
        closeBtn.Position = UDim2.new(1, -35, 0, 5)
        closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.Text = "×"
        closeBtn.TextSize = 16
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.ZIndex = 102
        closeBtn.Parent = header
        
        local closeBtnCorner = Instance.new("UICorner")
        closeBtnCorner.CornerRadius = UDim.new(0, 5)
        closeBtnCorner.Parent = closeBtn
        
        -- Left sidebar (categories) - smaller
        local sidebar = Instance.new("Frame")
        sidebar.Size = UDim2.new(0, 120, 1, -40)
        sidebar.Position = UDim2.new(0, 0, 0, 40)
        sidebar.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
        sidebar.BorderSizePixel = 0
        sidebar.ZIndex = 101
        sidebar.Parent = frame
        
        -- Right content area
        local contentArea = Instance.new("Frame")
        contentArea.Size = UDim2.new(1, -120, 1, -40)
        contentArea.Position = UDim2.new(0, 120, 0, 40)
        contentArea.BackgroundTransparency = 1
        contentArea.ZIndex = 101
        contentArea.Parent = frame
        
        -- Scroll frame for content
        local scrollFrame = Instance.new("ScrollingFrame")
        scrollFrame.Size = UDim2.new(1, -10, 1, -10)
        scrollFrame.Position = UDim2.new(0, 5, 0, 5)
        scrollFrame.BackgroundTransparency = 1
        scrollFrame.ScrollBarThickness = 4
        scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
        scrollFrame.ZIndex = 101
        scrollFrame.Parent = contentArea
        
        local scrollUIL = Instance.new("UIListLayout")
        scrollUIL.FillDirection = Enum.FillDirection.Vertical
        scrollUIL.Padding = UDim.new(0, 4)
        scrollUIL.Parent = scrollFrame
        
        -- Function to create feature buttons (smaller)
        local function createButton(text, callback, color, icon)
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, 0, 0, 32)
            button.BackgroundColor3 = color or Color3.fromRGB(25, 25, 25)
            button.BackgroundTransparency = 0.1
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
            button.TextSize = 12
            button.Font = Enum.Font.Gotham
            button.Text = "  " .. (icon or "•") .. " " .. text
            button.TextXAlignment = Enum.TextXAlignment.Left
            button.ZIndex = 102
            button.Parent = scrollFrame
            
            local buttonCorner = Instance.new("UICorner")
            buttonCorner.CornerRadius = UDim.new(0, 4)
            buttonCorner.Parent = button
            
            local buttonStroke = Instance.new("UIStroke")
            buttonStroke.Color = Color3.fromRGB(40, 40, 40)
            buttonStroke.Thickness = 1
            buttonStroke.Parent = button
            
            -- Hover effect
            button.MouseEnter:Connect(function()
                button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            end)
            
            button.MouseLeave:Connect(function()
                button.BackgroundColor3 = color or Color3.fromRGB(25, 25, 25)
            end)
            
            button.MouseButton1Click:Connect(function()
                local success, err = pcall(callback)
                if not success then
                    notify("⚠️ Error: " .. tostring(err), Color3.fromRGB(255, 100, 100))
                end
            end)
            
            return button
        end
        
        -- Function to create category buttons (smaller)
        local function createCategoryButton(text, categoryName, yPos)
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, -8, 0, 35)
            button.Position = UDim2.new(0, 4, 0, yPos)
            button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            button.BackgroundTransparency = 0.1
            button.TextColor3 = Color3.fromRGB(200, 200, 200)
            button.TextSize = 11
            button.Font = Enum.Font.GothamMedium
            button.Text = text
            button.ZIndex = 102
            button.Name = categoryName
            button.Parent = sidebar
            
            local buttonCorner = Instance.new("UICorner")
            buttonCorner.CornerRadius = UDim.new(0, 4)
            buttonCorner.Parent = button
            
            local buttonStroke = Instance.new("UIStroke")
            buttonStroke.Color = Color3.fromRGB(40, 40, 40)
            buttonStroke.Thickness = 1
            buttonStroke.Parent = button
            
            return button
        end
        
        -- Create category buttons
        local movementBtn = createCategoryButton("Movement", "Movement", 5)
        local teleportBtn = createCategoryButton("Teleport", "Teleport", 45)
        local playerBtn = createCategoryButton("Player", "Player", 85)
        local miscBtn = createCategoryButton("Misc", "Misc", 125)
        
        -- Function to show category content
        local function showCategory(categoryName)
            -- Clear existing content
            for _, child in pairs(scrollFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    child:Destroy()
                end
            end
            
            -- Reset all category button colors
            for _, child in pairs(sidebar:GetChildren()) do
                if child:IsA("TextButton") then
                    child.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
                    child.TextColor3 = Color3.fromRGB(200, 200, 200)
                end
            end
            
            -- Highlight selected category
            local selectedBtn = sidebar:FindFirstChild(categoryName)
            if selectedBtn then
                selectedBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                selectedBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
            
            -- Add category-specific buttons
            if categoryName == "Movement" then
                createButton("Toggle Fly", toggleFly, Color3.fromRGB(30, 30, 30), "🛫")
                createButton("Toggle Speed", toggleSpeed, Color3.fromRGB(30, 30, 30), "🏃")
                createButton("Toggle Jump Power", toggleJump, Color3.fromRGB(30, 30, 30), "🦘")
                createButton("Toggle Noclip", toggleNoclip, Color3.fromRGB(30, 30, 30), "🚪")
                createButton("Toggle Water Walk", toggleWaterWalk, Color3.fromRGB(30, 30, 30), "🌊")
                createButton("Toggle God Mode", toggleGodMode, Color3.fromRGB(30, 30, 30), "🛡️")
                
            elseif categoryName == "Teleport" then
                createButton("Teleport to Spawn", teleportToSpawn, Color3.fromRGB(30, 30, 30), "🚪")
                createButton("Save Current Position", saveCurrentPosition, Color3.fromRGB(30, 30, 30), "💾")
                createButton("Show Position List", showPositionList, Color3.fromRGB(30, 30, 30), "📍")
                
            elseif categoryName == "Player" then
                createButton("Show Player List", showPlayerList, Color3.fromRGB(30, 30, 30), "👥")
                createButton("Teleport to Player", teleportToPlayer, Color3.fromRGB(30, 30, 30), "🚀")
                if selectedPlayer then
                    createButton("Selected: " .. selectedPlayer.Name, function() end, Color3.fromRGB(40, 40, 40), "👤")
                else
                    createButton("No Player Selected", function() end, Color3.fromRGB(60, 30, 30), "👤")
                end
                
            elseif categoryName == "Misc" then
                createButton("Respawn Character", function()
                    player:LoadCharacter()
                    notify("🔄 Respawning...", Color3.fromRGB(0, 255, 255))
                end, Color3.fromRGB(30, 30, 30), "🔄")
                
                createButton("Reset All Features", function()
                    -- Reset all features
                    if flying then toggleFly() end
                    if speedEnabled then toggleSpeed() end
                    if jumpEnabled then toggleJump() end
                    if noclip then toggleNoclip() end
                    if waterWalk then toggleWaterWalk() end
                    if godMode then toggleGodMode() end
                    notify("🔄 All features reset", Color3.fromRGB(255, 255, 0))
                end, Color3.fromRGB(30, 30, 30), "🔄")
                
                createButton("Settings", function()
                    -- Create settings UI
                    local settingsGui = Instance.new("ScreenGui")
                    settingsGui.Name = "Settings"
                    settingsGui.Parent = game.CoreGui
                    
                    local settingsFrame = Instance.new("Frame")
                    settingsFrame.Size = UDim2.new(0, 300, 0, 200)
                    settingsFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
                    settingsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
                    settingsFrame.BorderSizePixel = 0
                    settingsFrame.Parent = settingsGui
                    
                    local settingsCorner = Instance.new("UICorner")
                    settingsCorner.CornerRadius = UDim.new(0, 8)
                    settingsCorner.Parent = settingsFrame
                    
                    -- Settings content
                    local settingsTitle = Instance.new("TextLabel")
                    settingsTitle.Size = UDim2.new(1, 0, 0, 40)
                    settingsTitle.BackgroundTransparency = 1
                    settingsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
                    settingsTitle.Text = "⚙️ Settings"
                    settingsTitle.TextSize = 16
                    settingsTitle.Font = Enum.Font.GothamBold
                    settingsTitle.Parent = settingsFrame
                    
                    -- Speed slider
                    local speedLabel = Instance.new("TextLabel")
                    speedLabel.Size = UDim2.new(1, -20, 0, 25)
                    speedLabel.Position = UDim2.new(0, 10, 0, 50)
                    speedLabel.BackgroundTransparency = 1
                    speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    speedLabel.Text = "Speed: " .. moveSpeed
                    speedLabel.TextSize = 12
                    speedLabel.Font = Enum.Font.Gotham
                    speedLabel.TextXAlignment = Enum.TextXAlignment.Left
                    speedLabel.Parent = settingsFrame
                    
                    -- Fly speed slider
                    local flyLabel = Instance.new("TextLabel")
                    flyLabel.Size = UDim2.new(1, -20, 0, 25)
                    flyLabel.Position = UDim2.new(0, 10, 0, 90)
                    flyLabel.BackgroundTransparency = 1
                    flyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    flyLabel.Text = "Fly Speed: " .. flySpeed
                    flyLabel.TextSize = 12
                    flyLabel.Font = Enum.Font.Gotham
                    flyLabel.TextXAlignment = Enum.TextXAlignment.Left
                    flyLabel.Parent = settingsFrame
                    
                    -- Jump power slider
                    local jumpLabel = Instance.new("TextLabel")
                    jumpLabel.Size = UDim2.new(1, -20, 0, 25)
                    jumpLabel.Position = UDim2.new(0, 10, 0, 130)
                    jumpLabel.BackgroundTransparency = 1
                    jumpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    jumpLabel.Text = "Jump Power: " .. jumpPower
                    jumpLabel.TextSize = 12
                    jumpLabel.Font = Enum.Font.Gotham
                    jumpLabel.TextXAlignment = Enum.TextXAlignment.Left
                    jumpLabel.Parent = settingsFrame
                    
                    -- Close settings
                    local closeSettings = Instance.new("TextButton")
                    closeSettings.Size = UDim2.new(0, 30, 0, 30)
                    closeSettings.Position = UDim2.new(1, -35, 0, 5)
                    closeSettings.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
                    closeSettings.TextColor3 = Color3.fromRGB(255, 255, 255)
                    closeSettings.Text = "×"
                    closeSettings.TextSize = 16
                    closeSettings.Font = Enum.Font.GothamBold
                    closeSettings.Parent = settingsFrame
                    
                    local closeSettingsCorner = Instance.new("UICorner")
                    closeSettingsCorner.CornerRadius = UDim.new(0, 5)
                    closeSettingsCorner.Parent = closeSettings
                    
                    closeSettings.MouseButton1Click:Connect(function()
                        settingsGui:Destroy()
                    end)
                    
                    makeDraggable(settingsFrame, settingsTitle)
                    notify("⚙️ Settings opened", Color3.fromRGB(0, 255, 255))
                end, Color3.fromRGB(30, 30, 30), "⚙️")
            end
        end
        
        -- Connect category buttons
        movementBtn.MouseButton1Click:Connect(function()
            showCategory("Movement")
        end)
        
        teleportBtn.MouseButton1Click:Connect(function()
            showCategory("Teleport")
        end)
        
        playerBtn.MouseButton1Click:Connect(function()
            showCategory("Player")
        end)
        
        miscBtn.MouseButton1Click:Connect(function()
            showCategory("Misc")
        end)
        
        -- Show default category
        showCategory("Movement")
        
        -- Logo functionality
        logo.MouseButton1Click:Connect(function()
            frame.Visible = not frame.Visible
            
            if frame.Visible then
                logo.Text = "×"
                logo.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            else
                logo.Text = "⚡"
                logo.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            end
        end)
        
        -- Close button functionality
        closeBtn.MouseButton1Click:Connect(function()
            frame.Visible = false
            logo.Text = "⚡"
            logo.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        end)
        
        -- Make draggable
        makeDraggable(frame, header)
        makeDraggable(logo, logo)
        
        notify("✅ MainLoader Minimal GUI Ready", Color3.fromRGB(0, 255, 0))
        
    end)
    
    if not success then
        notify("❌ GUI creation failed: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Main function
local function main()
    task.wait(2)
    
    -- Initialize character
    initChar()
    
    -- Create GUI
    createGUI()
    
    -- Connect character respawn
    player.CharacterAdded:Connect(function()
        task.wait(2)
        initChar()
    end)
    
    -- Connect player selection update
    task.spawn(function()
        while true do
            task.wait(5)
            -- Update player list periodically if GUI is open
            if frame and frame.Visible then
                local selectedBtn = sidebar:FindFirstChild("Player")
                if selectedBtn and selectedBtn.BackgroundColor3 == Color3.fromRGB(40, 40, 40) then
                    -- Refresh player category if it's currently selected
                    showCategory("Player")
                end
            end
        end
    end)
    
    notify("🚀 MainLoader Minimal Loaded!", Color3.fromRGB(0, 255, 255))
    notify("Click the ⚡ button to open GUI", Color3.fromRGB(255, 255, 0))
end

-- Cleanup function
local function cleanup()
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    connections = {}
    
    if gui then
        gui:Destroy()
    end
end

-- Run on game closing
game:BindToClose(cleanup)

-- Start the script
main()