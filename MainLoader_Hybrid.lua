-- MainLoader Hybrid Version: Fitur Lengkap + GUI Pasti Muncul
-- Gabungan MainLoader.lua (fitur) + MainLoader_Fixed.lua (GUI & error handling)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Debug GUI untuk memastikan script berjalan
local function createDebugGUI()
    local debugGui = Instance.new("ScreenGui")
    debugGui.Name = "DebugGUI"
    debugGui.Parent = game.CoreGui
    local debugFrame = Instance.new("Frame")
    debugFrame.Size = UDim2.new(0, 200, 0, 100)
    debugFrame.Position = UDim2.new(0.5, -100, 0.1, 0)
    debugFrame.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    debugFrame.Parent = debugGui
    local debugText = Instance.new("TextLabel")
    debugText.Size = UDim2.new(1, 0, 1, 0)
    debugText.BackgroundTransparency = 1
    debugText.TextColor3 = Color3.fromRGB(255, 255, 255)
    debugText.Text = "DEBUG: Script Loaded"
    debugText.TextSize = 16
    debugText.Font = Enum.Font.GothamBold
    debugText.Parent = debugFrame
    task.wait(5)
    debugGui:Destroy()
end

-- Notification function
local function notify(message, color)
    color = color or Color3.fromRGB(255, 255, 255)
    local notification = Instance.new("ScreenGui")
    notification.Name = "Notification"
    notification.Parent = game.CoreGui
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 50)
    frame.Position = UDim2.new(0.5, -150, 0.1, 0)
    frame.BackgroundColor3 = color
    frame.BorderSizePixel = 0
    frame.Parent = notification
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.Text = message
    text.TextSize = 16
    text.Font = Enum.Font.GothamBold
    text.Parent = frame
    task.wait(3)
    notification:Destroy()
end

-- Semua variabel dan fitur dari MainLoader.lua
local humanoid, hr, char
local joystickFrame, cameraControlFrame, playerListFrame, positionListFrame
local selectedPlayer = nil
local spectatingPlayer = nil
local spectateUI = nil
local spectateNextBtn = nil
local spectatePrevBtn = nil
local spectateStopBtn = nil
local flying, freecam, noclip, godMode = false, false, false, false
local flySpeed = 40
local freecamSpeed = 20
local cameraRotationSensitivity = 0.01
local speedEnabled, jumpEnabled, waterWalk, rocket, spin = false, false, false, false, false
local moveSpeed = 50
local jumpPower = 100

-- Enhanced position saving system
local savedPositions = {}
local positionCounter = 0
local maxSavedPositions = 50
local autoSaveEnabled = false
local autoSaveInterval = 30

-- Category system for positions
local categories = {
    "General",
    "Spawn",
    "Checkpoint", 
    "Important",
    "Custom"
}
local currentCategory = "General"

-- Android DCIM folder path
local dcimPath = "DCIM/Supertool"
local gameName = game.Name or "UnknownGame"

-- Save data function
local function saveData()
    if writefile then
        local data = {
            positions = savedPositions,
            positionCounter = positionCounter,
            categories = categories,
            currentCategory = currentCategory
        }
        
        local success, result = pcall(function()
            writefile(dcimPath .. "/" .. gameName .. "_checkpoints.json", HttpService:JSONEncode(data))
        end)
        
        if success then
            print("💾 Data saved successfully")
        else
            print("❌ Failed to save data: " .. tostring(result))
        end
    end
end

-- Function to add new category
local function addNewCategory(categoryName)
    if not categoryName or categoryName == "" then return false end
    
    -- Check if category already exists
    for _, cat in ipairs(categories) do
        if cat == categoryName then
            return false
        end
    end
    
    table.insert(categories, categoryName)
    saveData()
    notify("📁 Added new category: " .. categoryName, Color3.fromRGB(0, 255, 255))
    return true
end

-- Simple macro system (like Geometry Dash)
local macroRecording = false
local macroPlaying = false
local macroActions = {}
local macroPerfectActions = {}
local currentAttempt = 1
local totalAttempts = 0
local practiceMode = false
local macroStartTime = 0

-- Mobile specific variables
local freecamCFrame = nil
local hrCFrame = nil
local joystickTouch = nil
local cameraTouch = nil
local joystickRadius = 50
local joystickDeadzone = 0.15
local moveDirection = Vector3.new(0, 0, 0)
local cameraDelta = Vector2.new(0, 0)
local cameraRotationSensitivity = 0.02 -- Increased from 0.01
local nickHidden, randomNick = false, false
local customNick = "PemainKeren"
local defaultLogoPos = UDim2.new(0.95, -50, 0.05, 10)
local defaultFramePos = UDim2.new(0.5, -400, 0.5, -250)
local freezeMovingParts = false
local originalCFrames = {}

-- Admin detection system
local adminDetectionEnabled = true
local adminList = {}
local detectedAdmins = {}
local adminWarningShown = false

-- Fake stats system
local fakeStatsEnabled = false
local fakeStatsData = {}
local fakeStatsBillboard = nil
local fakeStatsText = nil
local currentFakeStat = ""
local fakeStatsRotation = {}
local fakeStatsRotationIndex = 1
local fakeStatsRotationSpeed = 3 -- seconds per stat
local autoDetectGameStats = true

local connections = {}

-- Load saved data with local persistence
local function loadSavedData()
    local success, result = pcall(function()
        -- Try to load from DCIM/Supertool folder if available
        if writefile and readfile then
            local filePath = dcimPath .. "/" .. gameName .. "_checkpoints.json"
            if isfile and isfile(filePath) then
                local fileContent = readfile(filePath)
                local savedData = HttpService:JSONDecode(fileContent)
                savedPositions = savedData.positions or {}
                positionCounter = savedData.positionCounter or #savedPositions
                categories = savedData.categories or categories
                currentCategory = savedData.currentCategory or "General"
                notify("📁 Loaded " .. #savedPositions .. " checkpoints from DCIM/Supertool", Color3.fromRGB(0, 255, 255))
                return true
            else
                notify("📁 No saved checkpoints found, starting fresh", Color3.fromRGB(255, 255, 0))
            end
        end
        
        return false
    end)
    
    if not success then
        print("❌ Failed to load saved data: " .. tostring(result))
    end
end

-- Drag function for any GUI element
local function makeDraggable(guiElement, dragHandle)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
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

-- Real feature functions
local function toggleFly()
    flying = not flying
    local success, errorMsg = pcall(function()
        if flying then
            if not hr or not humanoid or not camera then
                flying = false
                error("Character or camera not loaded")
            end
            
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = hr
            
            connections.fly = RunService.RenderStepped:Connect(function()
                if not hr or not humanoid or not camera then
                    flying = false
                    if connections.fly then
                        connections.fly:Disconnect()
                        connections.fly = nil
                    end
                    notify("⚠️ Fly failed: Character or camera lost", Color3.fromRGB(255, 100, 100))
                    return
                end
                
                local forward = camera.CFrame.LookVector
                local right = camera.CFrame.RightVector
                local up = Vector3.new(0, 1, 0)
                local moveDir = Vector3.new(0, 0, 0)
                
                if moveDir.Magnitude > 0 then
                    moveDir = moveDir.Unit * flySpeed
                else
                    moveDir = Vector3.new(0, 0, 0)
                end
                
                bv.Velocity = moveDir
                hr.CFrame = CFrame.new(hr.Position) * camera.CFrame.Rotation
            end)
            notify("🛫 Fly Enabled")
        else
            if connections.fly then
                connections.fly:Disconnect()
                connections.fly = nil
            end
            if hr and hr:FindFirstChildOfClass("BodyVelocity") then
                hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
            end
            notify("🛬 Fly Disabled")
        end
    end)
    if not success then
        flying = false
        if connections.fly then
            connections.fly:Disconnect()
            connections.fly = nil
        end
        if hr and hr:FindFirstChildOfClass("BodyVelocity") then
            hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
        end
        notify("⚠️ Fly error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleSpeed()
    speedEnabled = not speedEnabled
    local success, errorMsg = pcall(function()
        if speedEnabled then
            if humanoid then
                humanoid.WalkSpeed = moveSpeed
            end
            notify("🏃 Speed Enabled")
        else
            if humanoid then
                humanoid.WalkSpeed = 16
            end
            notify("🏃 Speed Disabled")
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
        if jumpEnabled then
            if humanoid then
                humanoid.JumpPower = jumpPower
            end
            notify("🦘 Jump Enabled")
        else
            if humanoid then
                humanoid.JumpPower = 50
            end
            notify("🦘 Jump Disabled")
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
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
            notify("🚪 Noclip Enabled")
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
            notify("🚪 Noclip Disabled")
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
                if humanoid and hr then
                    local ray = Ray.new(hr.Position, Vector3.new(0, -5, 0))
                    local hit, pos = workspace:FindPartOnRayWithIgnoreList(ray, {char})
                    if hit and hit.Name:lower():find("water") then
                        hr.Position = Vector3.new(hr.Position.X, pos.Y + 1, hr.Position.Z)
                    end
                end
            end)
            notify("🌊 Water Walk Enabled")
        else
            if connections.waterWalk then
                connections.waterWalk:Disconnect()
                connections.waterWalk = nil
            end
            notify("🌊 Water Walk Disabled")
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
        if godMode then
            if humanoid then
                humanoid.MaxHealth = math.huge
                humanoid.Health = math.huge
            end
            connections.godMode = humanoid.HealthChanged:Connect(function(health)
                if health < math.huge then
                    humanoid.Health = math.huge
                end
            end)
            notify("🛡️ God Mode Enabled")
        else
            if connections.godMode then
                connections.godMode:Disconnect()
                connections.godMode = nil
            end
            if humanoid then
                humanoid.MaxHealth = 100
                humanoid.Health = 100
            end
            notify("🛡️ God Mode Disabled")
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

local function teleportToSpawn()
    local success, errorMsg = pcall(function()
        if not hr then
            notify("⚠️ Character not loaded", Color3.fromRGB(255, 100, 100))
            return
        end
        
        local spawnLocation = workspace:FindFirstChild("SpawnLocation") or workspace:FindFirstChild("Spawn")
        if spawnLocation then
            hr.CFrame = CFrame.new(spawnLocation.Position + Vector3.new(0, 3, 0))
            notify("🚪 Teleported to spawn")
        else
            hr.CFrame = CFrame.new(0, 100, 0)
            notify("🚪 Teleported to default spawn")
        end
    end)
    if not success then
        notify("⚠️ Teleport error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function saveCurrentPosition()
    local success, errorMsg = pcall(function()
        if not hr then
            notify("⚠️ Character not loaded", Color3.fromRGB(255, 100, 100))
            return
        end
        
        positionCounter = positionCounter + 1
        local positionName = "Position " .. positionCounter
        local positionData = {
            name = positionName,
            position = hr.Position,
            category = currentCategory,
            timestamp = os.time()
        }
        
        table.insert(savedPositions, positionData)
        saveData()
        notify("💾 Position saved: " .. positionName, Color3.fromRGB(0, 255, 0))
    end)
    if not success then
        notify("⚠️ Save position error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Position List UI
local function createPositionListUI()
    if positionListFrame then
        positionListFrame:Destroy()
    end
    
    positionListFrame = Instance.new("Frame")
    positionListFrame.Size = UDim2.new(0, 400, 0, 500)
    positionListFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
    positionListFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    positionListFrame.BackgroundTransparency = 0.1
    positionListFrame.BorderSizePixel = 0
    positionListFrame.Visible = false
    positionListFrame.ZIndex = 30
    positionListFrame.Parent = gui
    
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 10)
    frameCorner.Parent = positionListFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 50)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 20
    title.Font = Enum.Font.GothamBold
    title.Text = "Saved Positions"
    title.ZIndex = 31
    title.Parent = positionListFrame
    
    -- Scroll frame
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -20, 1, -60)
    scrollFrame.Position = UDim2.new(0, 10, 0, 50)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ZIndex = 31
    scrollFrame.Parent = positionListFrame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.Padding = UDim.new(0, 5)
    listLayout.Parent = scrollFrame
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Text = "×"
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.ZIndex = 31
    closeBtn.Parent = positionListFrame
    
    closeBtn.MouseButton1Click:Connect(function()
        positionListFrame.Visible = false
    end)
    
    -- Make draggable
    makeDraggable(positionListFrame, title)
end

-- Update position list
local function updatePositionList()
    if not positionListFrame then return end
    
    local scrollFrame = positionListFrame:FindFirstChild("ScrollingFrame")
    if not scrollFrame then return end
    
    -- Clear existing buttons
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- Add position buttons
    for i, posData in ipairs(savedPositions) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 40)
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 14
        btn.Font = Enum.Font.Gotham
        btn.Text = posData.name .. " (" .. posData.category .. ")"
        btn.ZIndex = 32
        btn.Parent = scrollFrame
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            if hr then
                hr.CFrame = CFrame.new(posData.position)
                notify("🚀 Teleported to " .. posData.name)
            end
        end)
    end
end

local function showPositionList()
    if positionListFrame then
        positionListFrame.Visible = not positionListFrame.Visible
        if positionListFrame.Visible then
            updatePositionList()
        end
        notify(positionListFrame.Visible and "📍 Position List Opened" or "📍 Position List Closed")
    end
end

-- Player List UI
local function createPlayerListUI()
    if playerListFrame then
        playerListFrame:Destroy()
    end
    
    playerListFrame = Instance.new("Frame")
    playerListFrame.Size = UDim2.new(0, 300, 0, 400)
    playerListFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
    playerListFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    playerListFrame.BackgroundTransparency = 0.1
    playerListFrame.BorderSizePixel = 0
    playerListFrame.Visible = false
    playerListFrame.ZIndex = 30
    playerListFrame.Parent = gui
    
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 10)
    frameCorner.Parent = playerListFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 50)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 20
    title.Font = Enum.Font.GothamBold
    title.Text = "Players"
    title.ZIndex = 31
    title.Parent = playerListFrame
    
    -- Scroll frame
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -20, 1, -60)
    scrollFrame.Position = UDim2.new(0, 10, 0, 50)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ZIndex = 31
    scrollFrame.Parent = playerListFrame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.Padding = UDim.new(0, 5)
    listLayout.Parent = scrollFrame
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -40, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Text = "×"
    closeBtn.TextSize = 18
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.ZIndex = 31
    closeBtn.Parent = playerListFrame
    
    closeBtn.MouseButton1Click:Connect(function()
        playerListFrame.Visible = false
    end)
    
    -- Make draggable
    makeDraggable(playerListFrame, title)
end

-- Update player list
local function updatePlayerList()
    if not playerListFrame then return end
    
    local scrollFrame = playerListFrame:FindFirstChild("ScrollingFrame")
    if not scrollFrame then return end
    
    -- Clear existing buttons
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- Add player buttons
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 40)
            btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.TextSize = 14
            btn.Font = Enum.Font.Gotham
            btn.Text = plr.Name
            btn.ZIndex = 32
            btn.Parent = scrollFrame
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 5)
            corner.Parent = btn
            
            btn.MouseButton1Click:Connect(function()
                selectedPlayer = plr
                notify("👤 Selected: " .. plr.Name)
            end)
        end
    end
end

local function showPlayerList()
    if playerListFrame then
        playerListFrame.Visible = not playerListFrame.Visible
        if playerListFrame.Visible then
            updatePlayerList()
        end
        notify(playerListFrame.Visible and "👥 Player List Opened" or "👥 Player List Closed")
    end
end

local function teleportToPlayer()
    if not selectedPlayer then
        notify("⚠️ No player selected", Color3.fromRGB(255, 100, 100))
        return
    end
    
    if not selectedPlayer.Character then
        notify("⚠️ " .. selectedPlayer.Name .. " has no character", Color3.fromRGB(255, 100, 100))
        return
    end
    
    local targetRootPart = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRootPart then
        notify("⚠️ " .. selectedPlayer.Name .. " has no root part", Color3.fromRGB(255, 100, 100))
        return
    end
    
    if not hr then
        notify("⚠️ Your character not loaded", Color3.fromRGB(255, 100, 100))
        return
    end
    
    hr.CFrame = CFrame.new(targetRootPart.Position + Vector3.new(0, 3, 0))
    notify("🚀 Teleported to " .. selectedPlayer.Name)
end

-- Admin detection system
local function loadAdminList()
    -- Load admin list from file or use default
    if readfile and isfile then
        local adminFile = "admin_list.txt"
        if isfile(adminFile) then
            local content = readfile(adminFile)
            for line in content:gmatch("[^\r\n]+") do
                table.insert(adminList, line)
            end
        end
    end
    
    -- Default admin names (common admin names)
    local defaultAdmins = {"Admin", "Moderator", "Owner", "Manager", "Staff"}
    for _, name in ipairs(defaultAdmins) do
        if not table.find(adminList, name) then
            table.insert(adminList, name)
        end
    end
end

local function startAdminMonitoring()
    if not adminDetectionEnabled then return end
    
    connections.adminMonitor = RunService.Heartbeat:Connect(function()
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= player then
                local isAdmin = false
                for _, adminName in ipairs(adminList) do
                    if plr.Name:lower():find(adminName:lower()) or 
                       plr.DisplayName:lower():find(adminName:lower()) then
                        isAdmin = true
                        break
                    end
                end
                
                if isAdmin and not table.find(detectedAdmins, plr) then
                    table.insert(detectedAdmins, plr)
                    notify("⚠️ Admin detected: " .. plr.Name, Color3.fromRGB(255, 100, 100))
                end
            end
        end
    end)
end

local function toggleAdminDetection()
    adminDetectionEnabled = not adminDetectionEnabled
    if adminDetectionEnabled then
        startAdminMonitoring()
        notify("🛡️ Admin Detection Enabled", Color3.fromRGB(0, 255, 0))
    else
        if connections.adminMonitor then
            connections.adminMonitor:Disconnect()
            connections.adminMonitor = nil
        end
        notify("🛡️ Admin Detection Disabled", Color3.fromRGB(255, 100, 100))
    end
end

-- Fake stats system
local function createFakeStatsBillboard()
    if fakeStatsBillboard then
        fakeStatsBillboard:Destroy()
    end
    
    fakeStatsBillboard = Instance.new("BillboardGui")
    fakeStatsBillboard.Size = UDim2.new(0, 200, 0, 50)
    fakeStatsBillboard.StudsOffset = Vector3.new(0, 3, 0)
    fakeStatsBillboard.AlwaysOnTop = true
    fakeStatsBillboard.Enabled = false
    fakeStatsBillboard.Parent = hr
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0.5
    frame.Parent = fakeStatsBillboard
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 5)
    corner.Parent = frame
    
    fakeStatsText = Instance.new("TextLabel")
    fakeStatsText.Size = UDim2.new(1, 0, 1, 0)
    fakeStatsText.BackgroundTransparency = 1
    fakeStatsText.TextColor3 = Color3.fromRGB(255, 255, 255)
    fakeStatsText.TextSize = 16
    fakeStatsText.Font = Enum.Font.GothamBold
    fakeStatsText.Text = "Loading stats..."
    fakeStatsText.Parent = frame
end

local function updateFakeStatsDisplay()
    if not fakeStatsText then return end
    
    local stats = {
        "Kills: 999",
        "Wins: 50",
        "Level: 100",
        "Coins: 999999",
        "Experience: 999999"
    }
    
    fakeStatsText.Text = stats[fakeStatsRotationIndex] or "Stats: 999"
end

local function startFakeStatsRotation()
    if not fakeStatsEnabled then return end
    
    connections.fakeStatsRotation = RunService.Heartbeat:Connect(function()
        if fakeStatsEnabled and fakeStatsText then
            fakeStatsRotationIndex = fakeStatsRotationIndex + 1
            if fakeStatsRotationIndex > 5 then
                fakeStatsRotationIndex = 1
            end
            updateFakeStatsDisplay()
        end
    end)
end

local function toggleFakeStats()
    fakeStatsEnabled = not fakeStatsEnabled
    
    if fakeStatsEnabled then
        if not fakeStatsBillboard then
            createFakeStatsBillboard()
        end
        fakeStatsBillboard.Enabled = true
        startFakeStatsRotation()
        notify("📊 Fake Stats Enabled", Color3.fromRGB(0, 255, 0))
    else
        if fakeStatsBillboard then
            fakeStatsBillboard.Enabled = false
        end
        if connections.fakeStatsRotation then
            connections.fakeStatsRotation:Disconnect()
            connections.fakeStatsRotation = nil
        end
        notify("📊 Fake Stats Disabled", Color3.fromRGB(255, 100, 100))
    end
end

local function detectGameAndCreateStats()
    local gameName = game.Name:lower()
    local stats = {}
    
    if gameName:find("adopt") then
        stats = {"Pets: 999", "Money: 999999", "Level: 100"}
    elseif gameName:find("murder") then
        stats = {"Wins: 50", "Kills: 999", "Sheriff Wins: 25"}
    elseif gameName:find("tycoon") then
        stats = {"Money: 999999", "Level: 100", "Rebirths: 10"}
    else
        stats = {"Level: 100", "Coins: 999999", "Experience: 999999"}
    end
    
    fakeStatsRotation = stats
    notify("🎮 Game detected: " .. game.Name, Color3.fromRGB(0, 255, 255))
end

-- Character initialization
local function initChar()
    local success, errorMsg = pcall(function()
        local retryCount = 0
        while not player.Character and retryCount < 5 do
            notify("⏳ Waiting for character to spawn... Attempt " .. (retryCount + 1), Color3.fromRGB(255, 255, 0))
            player.CharacterAdded:Wait()
            task.wait(2)
            retryCount = retryCount + 1
        end
        
        if not player.Character then
            error("Character failed to load after retries")
        end
        
        char = player.Character
        humanoid = char:WaitForChild("Humanoid", 20)
        hr = char:WaitForChild("HumanoidRootPart", 20)
        
        if not humanoid or not hr then
            error("Failed to find Humanoid or HumanoidRootPart after 20s")
        end
        
        notify("✅ Character loaded successfully", Color3.fromRGB(0, 255, 0))
    end)
    
    if not success then
        print("initChar error: " .. tostring(errorMsg))
        notify("⚠️ Character init failed: " .. tostring(errorMsg) .. ", retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(5)
        initChar()
    end
end

-- Joystick for mobile controls
local function createJoystick()
    if joystickFrame then
        joystickFrame:Destroy()
    end
    
    joystickFrame = Instance.new("Frame")
    joystickFrame.Size = UDim2.new(0, 150, 0, 150)
    joystickFrame.Position = UDim2.new(0, 50, 1, -200)
    joystickFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    joystickFrame.BackgroundTransparency = 0.5
    joystickFrame.BorderSizePixel = 0
    joystickFrame.Visible = false
    joystickFrame.ZIndex = 40
    joystickFrame.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 75)
    corner.Parent = joystickFrame
    
    -- Joystick handle
    local handle = Instance.new("Frame")
    handle.Size = UDim2.new(0, 30, 0, 30)
    handle.Position = UDim2.new(0.5, -15, 0.5, -15)
    handle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    handle.BorderSizePixel = 0
    handle.ZIndex = 41
    handle.Parent = joystickFrame
    
    local handleCorner = Instance.new("UICorner")
    handleCorner.CornerRadius = UDim.new(0, 15)
    handleCorner.Parent = handle
    
    -- Touch handling
    joystickFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            joystickTouch = input
        end
    end)
    
    joystickFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch and joystickTouch then
            local center = joystickFrame.AbsolutePosition + joystickFrame.AbsoluteSize / 2
            local touchPos = input.Position
            local direction = (touchPos - center)
            local distance = direction.Magnitude
            
            if distance > joystickRadius then
                direction = direction.Unit * joystickRadius
            end
            
            if distance > joystickDeadzone * joystickRadius then
                moveDirection = Vector3.new(direction.X / joystickRadius, 0, direction.Y / joystickRadius)
            else
                moveDirection = Vector3.new(0, 0, 0)
            end
            
            handle.Position = UDim2.new(0.5, -15 + direction.X, 0.5, -15 + direction.Y)
        end
    end)
    
    joystickFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            joystickTouch = nil
            moveDirection = Vector3.new(0, 0, 0)
            handle.Position = UDim2.new(0.5, -15, 0.5, -15)
        end
    end)
end

-- Camera control for mobile
local function createCameraControl()
    if cameraControlFrame then
        cameraControlFrame:Destroy()
    end
    
    cameraControlFrame = Instance.new("Frame")
    cameraControlFrame.Size = UDim2.new(0, 200, 0, 200)
    cameraControlFrame.Position = UDim2.new(1, -250, 1, -250)
    cameraControlFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    cameraControlFrame.BackgroundTransparency = 0.5
    cameraControlFrame.BorderSizePixel = 0
    cameraControlFrame.Visible = false
    cameraControlFrame.ZIndex = 40
    cameraControlFrame.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 100)
    corner.Parent = cameraControlFrame
    
    -- Camera handle
    local cameraHandle = Instance.new("Frame")
    cameraHandle.Size = UDim2.new(0, 40, 0, 40)
    cameraHandle.Position = UDim2.new(0.5, -20, 0.5, -20)
    cameraHandle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    cameraHandle.BorderSizePixel = 0
    cameraHandle.ZIndex = 41
    cameraHandle.Parent = cameraControlFrame
    
    local handleCorner = Instance.new("UICorner")
    handleCorner.CornerRadius = UDim.new(0, 20)
    handleCorner.Parent = cameraHandle
    
    -- Touch handling
    cameraControlFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            cameraTouch = input
        end
    end)
    
    cameraControlFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch and cameraTouch then
            local center = cameraControlFrame.AbsolutePosition + cameraControlFrame.AbsoluteSize / 2
            local touchPos = input.Position
            local direction = (touchPos - center)
            
            cameraDelta = Vector2.new(direction.X / 100, direction.Y / 100)
            cameraHandle.Position = UDim2.new(0.5, -20 + direction.X, 0.5, -20 + direction.Y)
        end
    end)
    
    cameraControlFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            cameraTouch = nil
            cameraDelta = Vector2.new(0, 0)
            cameraHandle.Position = UDim2.new(0.5, -20, 0.5, -20)
        end
    end)
end

-- Spectate UI
local function createSpectateUI()
    if spectateUI then
        spectateUI:Destroy()
    end
    
    spectateUI = Instance.new("Frame")
    spectateUI.Size = UDim2.new(0, 350, 0, 120)
    spectateUI.Position = UDim2.new(0.5, -175, 0.1, 0)
    spectateUI.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    spectateUI.BackgroundTransparency = 0.2
    spectateUI.BorderSizePixel = 0
    spectateUI.ZIndex = 50
    spectateUI.Visible = false
    spectateUI.Parent = gui
    
    local spectateCorner = Instance.new("UICorner")
    spectateCorner.CornerRadius = UDim.new(0, 10)
    spectateCorner.Parent = spectateUI
    
    -- Make spectate UI draggable
    makeDraggable(spectateUI, spectateUI)
    
    -- Spectate info
    local spectateInfo = Instance.new("TextLabel")
    spectateInfo.Size = UDim2.new(1, 0, 0, 40)
    spectateInfo.Position = UDim2.new(0, 10, 0, 5)
    spectateInfo.BackgroundTransparency = 1
    spectateInfo.TextColor3 = Color3.fromRGB(255, 255, 255)
    spectateInfo.TextSize = 18
    spectateInfo.Font = Enum.Font.GothamBold
    spectateInfo.Text = "👁️ Spectating: None"
    spectateInfo.ZIndex = 51
    spectateInfo.Parent = spectateUI
    
    -- Previous button
    spectatePrevBtn = Instance.new("TextButton")
    spectatePrevBtn.Size = UDim2.new(0, 100, 0, 40)
    spectatePrevBtn.Position = UDim2.new(0, 10, 0, 50)
    spectatePrevBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
    spectatePrevBtn.BackgroundTransparency = 0.2
    spectatePrevBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    spectatePrevBtn.TextSize = 16
    spectatePrevBtn.Font = Enum.Font.GothamBold
    spectatePrevBtn.Text = "◀ Previous"
    spectatePrevBtn.ZIndex = 51
    spectatePrevBtn.Parent = spectateUI
    
    local prevCorner = Instance.new("UICorner")
    prevCorner.CornerRadius = UDim.new(0, 8)
    prevCorner.Parent = spectatePrevBtn
    
    -- Next button
    spectateNextBtn = Instance.new("TextButton")
    spectateNextBtn.Size = UDim2.new(0, 100, 0, 40)
    spectateNextBtn.Position = UDim2.new(0, 125, 0, 50)
    spectateNextBtn.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
    spectateNextBtn.BackgroundTransparency = 0.2
    spectateNextBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    spectateNextBtn.TextSize = 16
    spectateNextBtn.Font = Enum.Font.GothamBold
    spectateNextBtn.Text = "Next ▶"
    spectateNextBtn.ZIndex = 51
    spectateNextBtn.Parent = spectateUI
    
    local nextCorner = Instance.new("UICorner")
    nextCorner.CornerRadius = UDim.new(0, 8)
    nextCorner.Parent = spectateNextBtn
    
    -- Stop button
    spectateStopBtn = Instance.new("TextButton")
    spectateStopBtn.Size = UDim2.new(0, 100, 0, 40)
    spectateStopBtn.Position = UDim2.new(0, 240, 0, 50)
    spectateStopBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    spectateStopBtn.BackgroundTransparency = 0.2
    spectateStopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    spectateStopBtn.TextSize = 16
    spectateStopBtn.Font = Enum.Font.GothamBold
    spectateStopBtn.Text = "Stop"
    spectateStopBtn.ZIndex = 51
    spectateStopBtn.Parent = spectateUI
    
    local stopCorner = Instance.new("UICorner")
    stopCorner.CornerRadius = UDim.new(0, 8)
    stopCorner.Parent = spectateStopBtn
    
    notify("👁️ Spectate UI created", Color3.fromRGB(0, 255, 255))
end

-- Overlay protection
local function startOverlayProtection()
    -- Ensure GUI stays on top
    connections.overlayProtection = RunService.Heartbeat:Connect(function()
        if gui then
            gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        end
    end)
end

-- Create GUI function dengan error handling yang aman
local function createGUI()
    print("🔧 Starting GUI creation...")
    local success, errorMsg = pcall(function()
        -- Clean up old GUI
        local oldGui = player.PlayerGui:FindFirstChild("MainLoaderGUI")
        if oldGui then
            oldGui:Destroy()
            print("🗑️ Cleaned up old GUI")
        end
        
        print("📱 Creating ScreenGui...")
        -- Create new GUI - Try CoreGui first, then PlayerGui
        gui = Instance.new("ScreenGui")
        gui.Name = "MainLoaderGUI"
        gui.ResetOnSpawn = false
        
        -- Try CoreGui first (better for executors)
        local success1 = pcall(function()
            gui.Parent = game.CoreGui
        end)
        
        if not success1 then
            -- Fallback to PlayerGui
            gui.Parent = player:WaitForChild("PlayerGui", 10)
        end
        
        if not gui then
            error("Failed to create ScreenGui")
        end
        
        print("✅ ScreenGui created successfully")
        
        print("🎯 Creating logo button...")
        -- Create main logo button (draggable)
        logo = Instance.new("TextButton")
        logo.Size = UDim2.new(0, 80, 0, 80)
        logo.Position = UDim2.new(0.85, 0, 0.8, 0)
        logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        logo.TextColor3 = Color3.fromRGB(255, 255, 255)
        logo.Text = "⚡"
        logo.TextSize = 30
        logo.Font = Enum.Font.GothamBold
        logo.ZIndex = 1000
        logo.Visible = true
        logo.Parent = gui
        
        if not logo then
            error("Failed to create logo button")
        end
        
        print("✅ Logo button created successfully")
        
        -- Make logo circular
        local logoCorner = Instance.new("UICorner")
        logoCorner.CornerRadius = UDim.new(0, 40)
        logoCorner.Parent = logo
        
        -- Make logo draggable
        makeDraggable(logo, logo)
        
        print("📋 Creating main frame...")
        -- Create main frame (hidden by default, draggable)
        frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 800, 0, 500)
        frame.Position = UDim2.new(0.5, -400, 0.5, -250)
        frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        frame.BackgroundTransparency = 0.1
        frame.BorderSizePixel = 0
        frame.Visible = false
        frame.ZIndex = 50
        frame.Parent = gui
        
        local frameCorner = Instance.new("UICorner")
        frameCorner.CornerRadius = UDim.new(0, 15)
        frameCorner.Parent = frame
        
        -- Header (draggable handle)
        local header = Instance.new("Frame")
        header.Size = UDim2.new(1, 0, 0, 60)
        header.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        header.BorderSizePixel = 0
        header.ZIndex = 51
        header.Parent = frame
        
        local headerCorner = Instance.new("UICorner")
        headerCorner.CornerRadius = UDim.new(0, 15)
        headerCorner.Parent = header
        
        -- Make frame draggable by header
        makeDraggable(frame, header)
        
        -- Title
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -60, 1, 0)
        title.Position = UDim2.new(0, 20, 0, 0)
        title.BackgroundTransparency = 1
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 24
        title.Font = Enum.Font.GothamBold
        title.Text = "MainLoader Enhanced"
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.ZIndex = 52
        title.Parent = header
        
        -- Close button
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 40, 0, 40)
        closeBtn.Position = UDim2.new(1, -50, 0, 10)
        closeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.Text = "×"
        closeBtn.TextSize = 24
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.ZIndex = 52
        closeBtn.Parent = header
        
        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, 20)
        closeCorner.Parent = closeBtn
        
        -- Left sidebar for categories
        local sidebar = Instance.new("Frame")
        sidebar.Size = UDim2.new(0, 200, 1, -60)
        sidebar.Position = UDim2.new(0, 0, 0, 60)
        sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        sidebar.BorderSizePixel = 0
        sidebar.ZIndex = 51
        sidebar.Parent = frame
        
        local sidebarCorner = Instance.new("UICorner")
        sidebarCorner.CornerRadius = UDim.new(0, 15)
        sidebarCorner.Parent = sidebar
        
        -- Right content area
        local contentArea = Instance.new("Frame")
        contentArea.Size = UDim2.new(1, -200, 1, -60)
        contentArea.Position = UDim2.new(0, 200, 0, 60)
        contentArea.BackgroundTransparency = 1
        contentArea.ZIndex = 51
        contentArea.Parent = frame
        
        -- Scroll frame for content
        local scrollFrame = Instance.new("ScrollingFrame")
        scrollFrame.Size = UDim2.new(1, -20, 1, -20)
        scrollFrame.Position = UDim2.new(0, 10, 0, 10)
        scrollFrame.BackgroundTransparency = 1
        scrollFrame.ScrollBarThickness = 8
        scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
        scrollFrame.ZIndex = 51
        scrollFrame.ClipsDescendants = true
        scrollFrame.ScrollingEnabled = true
        scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        scrollFrame.Parent = contentArea
        
        local scrollUIL = Instance.new("UIListLayout")
        scrollUIL.FillDirection = Enum.FillDirection.Vertical
        scrollUIL.Padding = UDim.new(0, 8)
        scrollUIL.Parent = scrollFrame
        
        -- Function to create buttons
        local function createButton(text, callback, color, icon)
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, 0, 0, 50)
            button.BackgroundColor3 = color or Color3.fromRGB(30, 30, 30)
            button.BackgroundTransparency = 0.1
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
            button.TextSize = 16
            button.Font = Enum.Font.GothamBold
            button.Text = icon .. " " .. text
            button.TextXAlignment = Enum.TextXAlignment.Left
            button.ZIndex = 52
            button.Parent = scrollFrame
            
            local buttonCorner = Instance.new("UICorner")
            buttonCorner.CornerRadius = UDim.new(0, 8)
            buttonCorner.Parent = button
            
            button.MouseButton1Click:Connect(function()
                local success, err = pcall(callback)
                if not success then
                    notify("⚠️ Error: " .. tostring(err), Color3.fromRGB(255, 100, 100))
                end
            end)
            
            return button
        end
        
        -- Category buttons for sidebar
        local function createCategoryButton(text, categoryName)
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, -20, 0, 45)
            button.Position = UDim2.new(0, 10, 0, 10 + (45 * #sidebar:GetChildren()))
            button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            button.BackgroundTransparency = 0.2
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
            button.TextSize = 16
            button.Font = Enum.Font.GothamBold
            button.Text = text
            button.ZIndex = 52
            button.Name = categoryName
            local buttonCorner = Instance.new("UICorner")
            buttonCorner.CornerRadius = UDim.new(0, 8)
            buttonCorner.Parent = button
            button.Parent = sidebar
            
            return button
        end
        
        -- Create category buttons
        local movementBtn = createCategoryButton("Movement", "Movement")
        local teleportBtn = createCategoryButton("Teleport", "Teleport")
        local playerBtn = createCategoryButton("Player", "Player")
        local miscBtn = createCategoryButton("Misc", "Misc")
        
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
                    child.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                end
            end
            
            -- Highlight selected category
            local selectedBtn = sidebar:FindFirstChild(categoryName)
            if selectedBtn then
                selectedBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
            end
            
            -- Add category-specific buttons
            if categoryName == "Movement" then
                createButton("Toggle Fly", toggleFly, Color3.fromRGB(0, 150, 255), "🛫")
                createButton("Toggle Speed", toggleSpeed, Color3.fromRGB(0, 150, 255), "🏃")
                createButton("Toggle Jump Power", toggleJump, Color3.fromRGB(0, 150, 255), "🦘")
                createButton("Toggle Noclip", toggleNoclip, Color3.fromRGB(0, 150, 255), "🚪")
                createButton("Toggle Water Walk", toggleWaterWalk, Color3.fromRGB(0, 150, 255), "🌊")
            elseif categoryName == "Teleport" then
                createButton("Teleport to Spawn", teleportToSpawn, Color3.fromRGB(0, 150, 0), "🚪")
                createButton("Save Current Position", saveCurrentPosition, Color3.fromRGB(150, 150, 0), "💾")
                createButton("Show Position List", showPositionList, Color3.fromRGB(150, 150, 0), "📍")
            elseif categoryName == "Player" then
                createButton("Show Player List", showPlayerList, Color3.fromRGB(150, 0, 150), "👥")
                createButton("Teleport to Player", teleportToPlayer, Color3.fromRGB(150, 0, 150), "🚀")
                createButton("Toggle Admin Detection", toggleAdminDetection, Color3.fromRGB(255, 100, 100), "🛡️")
            elseif categoryName == "Misc" then
                createButton("Toggle God Mode", toggleGodMode, Color3.fromRGB(0, 150, 255), "🛡️")
                createButton("Toggle Fake Stats", toggleFakeStats, Color3.fromRGB(255, 150, 0), "📊")
                createButton("Auto-Detect Game Stats", detectGameAndCreateStats, Color3.fromRGB(0, 255, 255), "🎮")
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
        
        print("🔘 Creating feature buttons...")
        
        print("🔗 Setting up logo functionality...")
        -- Logo functionality
        logo.MouseButton1Click:Connect(function()
            frame.Visible = not frame.Visible
            
            -- Animate logo
            if frame.Visible then
                logo.Text = "✕"
                logo.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
            else
                logo.Text = "⚡"
                logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
            end
        end)
        
        -- Close button functionality
        closeBtn.MouseButton1Click:Connect(function()
            frame.Visible = false
            logo.Text = "⚡"
            logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
            notify("📱 GUI Closed")
        end)
        
        print("✅ GUI created successfully")
        notify("✅ MainLoader GUI created successfully")
        
        -- Ensure logo is visible
        if logo then
            logo.Visible = true
            logo.ZIndex = 1000 -- Ensure it's on top
            print("✅ Logo is visible and ready")
        end
        
    end)
    
    if not success then
        print("❌ GUI creation failed: " .. tostring(errorMsg))
        notify("❌ GUI creation failed", Color3.fromRGB(255, 100, 100))
        -- Create fallback GUI
        local fallbackGui = Instance.new("ScreenGui")
        fallbackGui.Name = "MainLoaderFallback"
        
        -- Try CoreGui first
        local success1 = pcall(function()
            fallbackGui.Parent = game.CoreGui
        end)
        
        if not success1 then
            fallbackGui.Parent = player:WaitForChild("PlayerGui", 10)
        end
        
        local fallbackBtn = Instance.new("TextButton")
        fallbackBtn.Size = UDim2.new(0, 100, 0, 50)
        fallbackBtn.Position = UDim2.new(0.9, -100, 0.1, 0)
        fallbackBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        fallbackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        fallbackBtn.Text = "⚡"
        fallbackBtn.TextSize = 18
        fallbackBtn.Font = Enum.Font.GothamBold
        fallbackBtn.ZIndex = 1000
        fallbackBtn.Visible = true
        fallbackBtn.Parent = fallbackGui
        
        fallbackBtn.MouseButton1Click:Connect(function()
            notify("⚠️ Main GUI failed to create", Color3.fromRGB(255, 100, 100))
        end)
        
        print("⚠️ Using fallback GUI - Main GUI failed to create")
    end
end

-- Main function
local function main()
    print("🚀 Starting MainLoader Hybrid...")
    
    local success, errorMsg = pcall(function()
        -- Wait a bit for game to load
        task.wait(2)
        
        -- Load basic data
        loadSavedData()
        task.wait(1)
        
        -- Create GUI with retry mechanism
        local retryCount = 0
        local guiCreated = false
        
        while retryCount < 3 and not guiCreated do
            createGUI()
            
            -- Check if GUI was created successfully
            if gui and gui.Parent then
                print("✅ GUI created successfully on attempt " .. (retryCount + 1))
                guiCreated = true
                break
            else
                retryCount = retryCount + 1
                print("⚠️ GUI creation failed, retrying... (" .. retryCount .. "/3)")
                task.wait(3) -- Wait longer between retries
            end
        end
        
        if not guiCreated then
            print("❌ Failed to create GUI after 3 attempts")
            notify("❌ GUI creation failed - Check console", Color3.fromRGB(255, 100, 100))
            return
        end
        
        -- Create other UI elements (with error handling)
        local function safeCreate(func, name)
            local success, err = pcall(func)
            if not success then
                print("⚠️ Failed to create " .. name .. ": " .. tostring(err))
            else
                print("✅ " .. name .. " created successfully")
            end
        end
        
        -- Only create essential UI elements
        safeCreate(createJoystick, "Joystick")
        safeCreate(createCameraControl, "Camera Control")
        safeCreate(createPlayerListUI, "Player List UI")
        safeCreate(createPositionListUI, "Position List UI")
        safeCreate(createSpectateUI, "Spectate UI")
        
        -- Start systems (with error handling)
        local function safeStart(func, name)
            local success, err = pcall(func)
            if not success then
                print("⚠️ Failed to start " .. name .. ": " .. tostring(err))
            else
                print("✅ " .. name .. " started successfully")
            end
        end
        
        safeStart(startOverlayProtection, "Overlay Protection")
        safeStart(loadAdminList, "Admin List")
        safeStart(startAdminMonitoring, "Admin Monitoring")
        safeStart(detectGameAndCreateStats, "Game Detection")
        safeStart(initChar, "Character Init")
        
        -- Connect character respawn
        player.CharacterAdded:Connect(function()
            task.wait(2)
            safeStart(initChar, "Character Init (Respawn)")
        end)
        
        print("🎉 MainLoader Hybrid fully loaded!")
        print("📱 Look for the ⚡ button in the bottom-right corner")
        print("🎮 Features: Movement, Teleport, Player, Misc categories")
        
        -- Test notification
        task.wait(1)
        notify("✅ MainLoader Hybrid Ready! Tap ⚡ button", Color3.fromRGB(0, 255, 0))
        
        -- Additional test to ensure GUI is visible
        task.wait(2)
        if logo and logo.Visible then
            print("✅ Logo is visible and ready!")
            notify("🎯 Logo button is visible - Click it to open GUI!", Color3.fromRGB(0, 255, 255))
        else
            print("⚠️ Logo might not be visible")
            notify("⚠️ Logo button may not be visible - Check console for errors", Color3.fromRGB(255, 255, 0))
        end
        
    end)
    
    if not success then
        print("❌ Main function error: " .. tostring(errorMsg))
        print("🔄 Retrying in 3 seconds...")
        task.wait(3)
        main()
    end
end

main()