-- MainLoader.lua - Android Optimized Complete Version with Fixed Player, Trajectory, and Macro
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
local connections = {}
local antiRagdoll = false
local improvedFlying = false

-- UI Variables
local gui, frame, logo
local tabPages = {}
local currentTab = nil

-- Mobile detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Initialize character
local function initChar()
    local success, errorMsg = pcall(function()
        char = player.Character or player.CharacterAdded:Wait()
        humanoid = char:WaitForChild("Humanoid", 5)
        hr = char:WaitForChild("HumanoidRootPart", 5)
        if not humanoid or not hr then
            error("Failed to find Humanoid or HumanoidRootPart")
        end
    end)
    if not success then
        warn("initChar error: " .. errorMsg)
        notify("⚠️ Failed to initialize character, retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(1)
        initChar() -- Retry if failed
    else
        notify("👤 Character initialized", Color3.fromRGB(0, 255, 0))
    end
end

-- Notification system
local function notify(message, color)
    color = color or Color3.fromRGB(0, 255, 0)
    local success, errorMsg = pcall(function()
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
    end)
    if not success then
        warn("Notify error: " .. errorMsg)
    end
end

-- Create main GUI
local function createGUI()
    local success, errorMsg = pcall(function()
        gui = Instance.new("ScreenGui")
        gui.Name = "SuperToolUI_Mobile"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Enabled = true
        gui.Parent = player:WaitForChild("PlayerGui", 5)

        logo = Instance.new("ImageButton")
        logo.Size = UDim2.new(0, 70, 0, 70)
        logo.Position = UDim2.new(0, 20, 0, 20)
        logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        logo.BorderSizePixel = 0
        logo.Image = "rbxassetid://3570695787"
        logo.ImageTransparency = 0.2
        logo.Visible = true
        logo.Parent = gui
        
        local logoCorner = Instance.new("UICorner")
        logoCorner.CornerRadius = UDim.new(0, 35)
        logoCorner.Parent = logo

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
    end)
    if not success then
        warn("createGUI error: " .. errorMsg)
        notify("⚠️ Failed to create GUI, retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(1)
        createGUI()
    else
        notify("🖼️ GUI Initialized", Color3.fromRGB(0, 255, 0))
    end
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
        notify("🖼️ GUI Closed", Color3.fromRGB(255, 100, 100))
    end)

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

    local contentArea = Instance.new("Frame")
    contentArea.Size = UDim2.new(1, 0, 1, -110)
    contentArea.Position = UDim2.new(0, 0, 0, 110)
    contentArea.BackgroundTransparency = 1
    contentArea.BorderSizePixel = 0
    contentArea.Parent = frame

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

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.Position = UDim2.new(0, 0, 0, 0)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.ScrollBarThickness = 8
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Visible = false
    page.Parent = contentArea

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page
    
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)

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
        notify("📑 Switched to " .. name .. " tab", Color3.fromRGB(0, 255, 0))
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
    
    btn.Activated:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        task.wait(0.1)
        btn.BackgroundColor3 = color
        if callback then
            local success, errorMsg = pcall(callback)
            if not success then
                warn("Button callback error: " .. errorMsg)
                notify("⚠️ Error in button action: " .. text, Color3.fromRGB(255, 100, 100))
            end
        end
    end)
    
    return btn
end

-- Improved Flying system (Analog + Freecam-like)
local function setupFlying()
    local bodyVel, bodyGyro
    
    local function startFly()
        if not hr or not humanoid then
            notify("⚠️ Cannot start flying: Character not ready", Color3.fromRGB(255, 100, 100))
            return
        end
        
        bodyVel = Instance.new("BodyVelocity")
        bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bodyVel.Velocity = Vector3.new(0, 0, 0)
        bodyVel.Parent = hr
        
        bodyGyro = Instance.new("BodyAngularVelocity")
        bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        bodyGyro.AngularVelocity = Vector3.new(0, 0, 0)
        bodyGyro.Parent = hr
        
        flying = true
        notify("🚁 Flying Mode ON - Use joystick/camera to fly!", Color3.fromRGB(0, 255, 0))
        
        connections.flyLoop = RunService.Heartbeat:Connect(function()
            if not flying or not hr or not bodyVel or not humanoid or not camera then return end
            
            local moveVector = Vector3.new(0, 0, 0)
            local cam = camera.CFrame
            local forward = cam.LookVector
            local right = cam.RightVector
            
            if improvedFlying then
                local moveDir = humanoid.MoveDirection
                if moveDir.Magnitude > 0 then
                    moveVector = forward * moveDir.Z * flySpeed + right * moveDir.X * flySpeed
                end
            else
                if isMobile then
                    local moveVec = humanoid.MoveDirection
                    if moveVec.Magnitude > 0 then
                        moveVector = (forward * moveVec.Z + right * moveVec.X).Unit * flySpeed
                        moveVector = moveVector + Vector3.new(0, flySpeed * 0.3, 0)
                    else
                        moveVector = Vector3.new(0, flySpeed * 0.2, 0)
                    end
                else
                    local up = cam.UpVector
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
                    moveVector = moveVector * flySpeed
                end
            end
            
            bodyVel.Velocity = moveVector
            bodyGyro.CFrame = cam
        end)
    end
    
    local function stopFly()
        flying = false
        if bodyVel then bodyVel:Destroy() end
        if bodyGyro then bodyGyro:Destroy() end
        if connections.flyLoop then connections.flyLoop:Disconnect() end
        notify("🚁 Flying Mode OFF", Color3.fromRGB(255, 100, 100))
    end
    
    local function toggleImprovedFlying()
        improvedFlying = not improvedFlying
        notify("🛩️ Improved Flying: " .. (improvedFlying and "ON" or "OFF"), Color3.fromRGB(0, 255, improvedFlying and 0 or 100))
    end
    
    return startFly, stopFly, toggleImprovedFlying
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

-- No Fall Damage system
local function setupNoFallDamage()
    local function toggleNoFallDamage()
        noFall = not noFall
        if noFall then
            notify("🛡️ No Fall Damage ON", Color3.fromRGB(0, 255, 0))
            connections.fallDamageLoop = humanoid.StateChanged:Connect(function(oldState, newState)
                if newState == Enum.HumanoidStateType.Freefall and noFall then
                    humanoid.FallDamage = 0
                end
            end)
        else
            notify("🛡️ No Fall Damage OFF", Color3.fromRGB(255, 100, 100))
            if connections.fallDamageLoop then connections.fallDamageLoop:Disconnect() end
        end
    end
    
    return toggleNoFallDamage
end

-- Anti Ragdoll system
local function setupAntiRagdoll()
    local function toggleAntiRagdoll()
        antiRagdoll = not antiRagdoll
        if antiRagdoll then
            notify("🛡️ Anti Ragdoll ON", Color3.fromRGB(0, 255, 0))
            if humanoid then
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            end
            connections.ragdollLoop = humanoid.StateChanged:Connect(function(oldState, newState)
                if newState == Enum.HumanoidStateType.Ragdoll and antiRagdoll then
                    humanoid:ChangeState(Enum.HumanoidStateType.Running)
                end
            end)
        else
            notify("🛡️ Anti Ragdoll OFF", Color3.fromRGB(255, 100, 100))
            if humanoid then
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
            end
            if connections.ragdollLoop then connections.ragdollLoop:Disconnect() end
        end
    end
    
    return toggleAntiRagdoll
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

-- Player interaction system (with teleport enhancements)
local function setupPlayerSystem()
    local playerListFrame
    local selectedPlayer = nil
    
    local function createPlayerList(parent)
        playerListFrame = Instance.new("ScrollingFrame")
        playerListFrame.Size = UDim2.new(1, -20, 0, 300)
        playerListFrame.Position = UDim2.new(0, 10, 0, 50)
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
        
        notify("🎮 Player list frame created", Color3.fromRGB(0, 255, 0))
        return playerListFrame
    end
    
    local function refreshPlayerList()
        if not playerListFrame then
            notify("⚠️ Player list frame not initialized", Color3.fromRGB(255, 100, 100))
            return
        end
        
        for _, child in ipairs(playerListFrame:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        
        local players = Players:GetPlayers()
        if #players <= 1 then
            createButton("⚠️ No other players found", function() end, playerListFrame, Color3.fromRGB(255, 100, 100))
            notify("⚠️ No other players found", Color3.fromRGB(255, 100, 100))
        else
            for _, p in ipairs(players) do
                if p ~= player then
                    createButton("🎮 " .. p.Name, function()
                        selectedPlayer = p
                        for _, child in ipairs(playerListFrame:GetChildren()) do
                            if child:IsA("TextButton") and (child.Text:find("🔄") or child.Text:find("🧲") or child.Text:find("🎯") or child.Text:find("🚫")) then
                                child:Destroy()
                            end
                        end
                        
                        createButton("🔄 Teleport to " .. p.Name, function()
                            if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and hr then
                                hr.CFrame = p.Character.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
                                notify("Teleported to " .. p.Name, Color3.fromRGB(0, 255, 255))
                            else
                                notify("⚠️ Cannot teleport: Target not ready", Color3.fromRGB(255, 100, 100))
                            end
                        end, playerListFrame, Color3.fromRGB(0, 150, 255))
                        
                        createButton("🧲 Teleport " .. p.Name .. " to Me", function()
                            if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and hr then
                                p.Character.HumanoidRootPart.CFrame = hr.CFrame + Vector3.new(0, 0, -5)
                                notify("Teleported " .. p.Name .. " to you", Color3.fromRGB(255, 0, 255))
                            else
                                notify("⚠️ Cannot teleport: Target not ready", Color3.fromRGB(255, 100, 100))
                            end
                        end, playerListFrame, Color3.fromRGB(255, 0, 255))
                        
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
                        
                        createButton("🚫 Stop Follow", function()
                            followTarget = nil
                            if connections.followLoop then connections.followLoop:Disconnect() end
                            notify("Stopped following", Color3.fromRGB(255, 100, 100))
                        end, pesan dariRGB(255, 100, 100))
                    end, playerListFrame)
                end
            end
            notify("🎮 Player list refreshed (" .. (#players - 1) .. " players)", Color3.fromRGB(0, 255, 0))
        end
    end
    
    return createPlayerList, refreshPlayerList
end

-- Sistem Visualisasi Lintasan dengan Pewarnaan dan Autoplay (Macro)
local function setupTrajectoryAndMacro()
    local trajectoryEnabled = false
    local macroRecording = false
    local macroPlaying = false
    local macroActions = {}
    local trajectoryParts = {}
    local initialVelocity = 50
    local gravity = 196.2
    local maxPoints = 50
    local timeStep = 0.1
    local autoPlayOnRespawn = false
    local groundLevel = 0

    local function clearTrajectory()
        for _, part in ipairs(trajectoryParts) do
            part:Destroy()
        end
        trajectoryParts = {}
    end

    local function drawTrajectory()
        clearTrajectory()
        if not trajectoryEnabled or not hr or not camera then
            notify("⚠️ Cannot draw trajectory: Character or camera not ready", Color3.fromRGB(255, 100, 100))
            return
        end

        local startPos = hr.Position + Vector3.new(0, 2, 0)
        local direction = camera.CFrame.LookVector * initialVelocity
        local velocity = direction
        local position = startPos
        local prevHeight = startPos.Y

        for i = 1, maxPoints do
            local t = i * timeStep
            local newPos = position + velocity * timeStep + Vector3.new(0, -0.5 * gravity * timeStep^2, 0)
            velocity = velocity + Vector3.new(0, -gravity * timeStep, 0)

            local height = newPos.Y - groundLevel
            local color
            if height < 50 then
                color = BrickColor.new("Lime green")
            elseif height < 100 then
                color = BrickColor.new("Really red")
            else
                color = BrickColor.new("Cyan")
            end

            local point = Instance.new("Part")
            point.Size = Vector3.new(0.5, 0.5, 0.5) -- Ukuran lebih besar
            point.Position = newPos
            point.Anchored = true
            point.CanCollide = false
            point.BrickColor = color
            point.Material = Enum.Material.Neon
            point.Parent = workspace
            table.insert(trajectoryParts, point)

            local ray = Ray.new(position, (newPos - position).Unit * (newPos - position).Magnitude)
            local hit, hitPos = workspace:FindPartOnRay(ray, char)
            if hit then
                local hitPoint = Instance.new("Part")
                hitPoint.Size = Vector3.new(0.7, 0.7, 0.7)
                hitPoint.Position = hitPos
                hitPoint.Anchored = true
                hitPoint.CanCollide = false
                hitPoint.BrickColor = BrickColor.new("Bright yellow")
                hitPoint.Material = Enum.Material.Neon
                hitPoint.Parent = workspace
                table.insert(trajectoryParts, hitPoint)
                break
            end

            position = newPos
            prevHeight = height
        end
    end

    local function toggleTrajectory()
        trajectoryEnabled = not trajectoryEnabled
        if trajectoryEnabled then
            notify("📏 Trajectory Mode ON", Color3.fromRGB(255, 0, 0))
            connections.trajectoryLoop = RunService.RenderStepped:Connect(function()
                if hr and camera then
                    drawTrajectory()
                else
                    notify("⚠️ Trajectory paused: Character or camera not ready", Color3.fromRGB(255, 100, 100))
                end
            end)
        else
            notify("📏 Trajectory Mode OFF", Color3.fromRGB(255, 100, 100))
            clearTrajectory()
            if connections.trajectoryLoop then connections.trajectoryLoop:Disconnect() end
        end
    end

    local function startRecordingMacro()
        macroRecording = true
        macroActions = {}
        notify("🎥 Recording Macro...", Color3.fromRGB(0, 255, 0))
        
        connections.macroRecordLoop = RunService.Heartbeat:Connect(function(deltaTime)
            if not macroRecording or not humanoid or not hr then return end
            table.insert(macroActions, {
                time = tick(),
                position = hr.Position,
                moveDirection = humanoid.MoveDirection,
                jump = humanoid.Jump
            })
        end)
    end

    local function stopRecordingMacro()
        macroRecording = false
        if connections.macroRecordLoop then connections.macroRecordLoop:Disconnect() end
        notify("🎥 Macro Recorded (" .. #macroActions .. " actions)", Color3.fromRGB(0, 255, 0))
    end

    local function playMacro()
        if #macroActions == 0 then
            notify("⚠️ No Macro Recorded!", Color3.fromRGB(255, 100, 100))
            return
        end
        macroPlaying = true
        notify("▶️ Playing Macro...", Color3.fromRGB(0, 255, 255))

        -- Reset ke posisi awal
        if hr and macroActions[1] and macroActions[1].position then
            hr.CFrame = CFrame.new(macroActions[1].position)
            notify("📍 Reset to macro start position", Color3.fromRGB(0, 255, 255))
        end

        local startTime = tick()
        connections.macroPlayLoop = RunService.Heartbeat:Connect(function()
            if not macroPlaying or not humanoid or not hr then return end
            local currentTime = tick() - startTime

            for _, action in ipairs(macroActions) do
                if math.abs(action.time - startTime - currentTime) < 0.05 then
                    hr.Position = action.position
                    humanoid.MoveDirection = action.moveDirection
                    humanoid.Jump = action.jump
                end
            end

            if currentTime >= (macroActions[#macroActions].time - macroActions[1].time) then
                macroPlaying = false
                connections.macroPlayLoop:Disconnect()
                notify("⏹️ Macro Finished", Color3.fromRGB(255, 100, 100))
            end
        end)
    end

    local function stopPlayingMacro()
        macroPlaying = false
        if connections.macroPlayLoop then connections.macroPlayLoop:Disconnect() end
        notify("⏹️ Macro Stopped", Color3.fromRGB(255, 100, 100))
    end

    local function toggleAutoPlay()
        autoPlayOnRespawn = not autoPlayOnRespawn
        notify("🔄 AutoPlay on Respawn: " .. (autoPlayOnRespawn and "ON" or "OFF"), Color3.fromRGB(0, 255, autoPlayOnRespawn and 0 or 100))
    end

    player.CharacterAdded:Connect(function()
        task.wait(1)
        initChar()
        notify("👤 Character loaded", Color3.fromRGB(0, 255, 0))
        if autoPlayOnRespawn and #macroActions > 0 then
            playMacro()
        end
    end)

    return toggleTrajectory, startRecordingMacro, stopRecordingMacro, playMacro, stopPlayingMacro, toggleAutoPlay
end

-- Main setup function
local function setupUI()
    local success, errorMsg = pcall(function()
        createGUI()
        makeDraggable(logo)
        
        logo.Activated:Connect(function()
            frame.Visible = not frame.Visible
            if frame.Visible then
                TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Size = frame.Size}):Play()
            end
            notify("🖼️ GUI Toggled: " .. (frame.Visible and "ON" or "OFF"), Color3.fromRGB(0, 255, 0))
        end)
        
        local tabContainer, contentArea = createTabSystem()
        
        -- Movement Tab  
        local movementTab = createTab("Movement", "🚀", tabContainer, contentArea)
        local startFly, stopFly, toggleImprovedFlying = setupFlying()
        local toggleNoclip = setupNoclip()
        
        createButton("🚁 Toggle Flying (Use Joystick!)", function()
            if flying then stopFly() else startFly() end
        end, movementTab)
        
        createButton("🛩️ Toggle Improved Flying", toggleImprovedFlying, movementTab, Color3.fromRGB(0, 150, 255))
        
        createButton("👻 Toggle Noclip", toggleNoclip, movementTab)
        
        createButton("⚡ Fly Speed + (Current: " .. flySpeed .. ")", function()
            flySpeed = flySpeed + 5
            notify("Fly Speed: " .. flySpeed, Color3.fromRGB(255, 255, 0))
        end, movementTab)
        
        createButton("⚡ Fly Speed - (Current: " .. flySpeed .. ")", function()
            flySpeed = math.max(1, flySpeed - 5)
            notify("Fly Speed: " .. flySpeed, Color3.fromRGB(255, 255, 0))
        end, movementTab)
        
        createButton("🏃 Super Speed", function()
            if humanoid then
                humanoid.WalkSpeed = humanoid.WalkSpeed == 16 and 50 or 16
                notify("Speed: " .. humanoid.WalkSpeed, Color3.fromRGB(255, 255, 0))
            else
                notify("⚠️ Cannot set speed: Character not ready", Color3.fromRGB(255, 100, 100))
            end
        end, movementTab)
        
        createButton("🦘 Super Jump", function()
            if humanoid then
                humanoid.JumpPower = humanoid.JumpPower == 50 and 120 or 50
                notify("Jump Power: " .. humanoid.JumpPower, Color3.fromRGB(255, 255, 0))
            else
                notify("⚠️ Cannot set jump: Character not ready", Color3.fromRGB(255, 100, 100))
            end
        end, movementTab)
        
        createButton("🌊 Walk on Water", function()
            local walkOnWater = not workspace.Terrain.ReadVoxels
            for _, part in pairs(workspace:GetPartsByMaterial(Enum.Material.Water)) do
                part.CanCollide = walkOnWater
            end
            notify("Walk on water: " .. (walkOnWater and "ON" or "OFF"), Color3.fromRGB(0, 150, 255))
        end, movementTab)
        
        createButton("🚀 Rocket Jump", function()
            if hr then
                local rocket = Instance.new("BodyVelocity")
                rocket.MaxForce = Vector3.new(4000, 4000, 4000)
                rocket.Velocity = Vector3.new(0, 100, 0)
                rocket.Parent = hr
                task.wait(0.5)
                rocket:Destroy()
                notify("🚀 ROCKET JUMP!", Color3.fromRGB(255, 100, 0))
            else
                notify("⚠️ Cannot rocket jump: Character not ready", Color3.fromRGB(255, 100, 100))
            end
        end, movementTab)
        
        createButton("🌪️ Spin Attack", function()
            if hr then
                local spin = Instance.new("BodyAngularVelocity")
                spin.MaxTorque = Vector3.new(0, 4000, 0)
                spin.AngularVelocity = Vector3.new(0, 50, 0)
                spin.Parent = hr
                task.wait(2)
                spin:Destroy()
                notify("🌪️ Spin complete!", Color3.fromRGB(255, 255, 0))
            else
                notify("⚠️ Cannot spin: Character not ready", Color3.fromRGB(255, 100, 100))
            end
        end, movementTab)
        
        -- Player Tab
        local playerTab = createTab("Player", "🎮", tabContainer, contentArea)
        local createPlayerList, refreshPlayerList = setupPlayerSystem()
        
        createButton("🔄 Refresh Player List", refreshPlayerList, playerTab, Color3.fromRGB(0, 150, 255))
        
        local playerListFrame = createPlayerList(playerTab)
        
        -- Utility Tab
        local utilityTab = createTab("Utility", "🛠️", tabContainer, contentArea)
        local toggleAutoHeal = setupAutoHeal()
        local toggleGodMode = setupGodMode()
        local toggleNoFallDamage = setupNoFallDamage()
        local toggleAntiRagdoll = setupAntiRagdoll()
        local savePosition, loadPosition = setupPositions()
        local toggleTrajectory, startRecordingMacro, stopRecordingMacro, playMacro, stopPlayingMacro, toggleAutoPlay = setupTrajectoryAndMacro()

        createButton("💚 Toggle Auto Heal", toggleAutoHeal, utilityTab)
        createButton("⚡ Toggle God Mode", toggleGodMode, utilityTab)
        createButton("🛡️ Toggle No Fall Damage", toggleNoFallDamage, utilityTab, Color3.fromRGB(0, 255, 0))
        createButton("🛡️ Toggle Anti Ragdoll", toggleAntiRagdoll, utilityTab, Color3.fromRGB(0, 255, 0))
        
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
            else
                notify("⚠️ Cannot teleport: Character not ready", Color3.fromRGB(255, 100, 100))
            end
        end, utilityTab)
        
        createButton("📏 Toggle Trajectory", toggleTrajectory, utilityTab, Color3.fromRGB(255, 0, 0))
        createButton("🎥 Start Recording Macro", startRecordingMacro, utilityTab, Color3.fromRGB(0, 255, 0))
        createButton("⏹️ Stop Recording Macro", stopRecordingMacro, utilityTab, Color3.fromRGB(255, 100, 100))
        createButton("▶️ Play Macro", playMacro, utilityTab, Color3.fromRGB(0, 255, 255))
        createButton("🚫 Stop Macro", stopPlayingMacro, utilityTab, Color3.fromRGB(255, 100, 100))
        createButton("🔄 Toggle AutoPlay on Respawn", toggleAutoPlay, utilityTab, Color3.fromRGB(0, 150, 255))
        
        -- Settings Tab
        local settingsTab = createTab("Settings", "⚙️", tabContainer, contentArea)
        
        createButton("🔄 Reset Character", function()
            if humanoid then
                humanoid.Health = 0
                notify("Character reset", Color3.fromRGB(255, 100, 100))
            else
                notify("⚠️ Cannot reset: Character not ready", Color3.fromRGB(255, 100, 100))
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
            settings().Rendering.QualityLevel = 1
            notify("Optimized for mobile", Color3.fromRGB(0, 255, 0))
        end, settingsTab)
        
        -- Initialize
        initChar()
        refreshPlayerList()
        
        -- Auto-refresh player list
        Players.PlayerAdded:Connect(function()
            task.wait(0.5)
            refreshPlayerList()
        end)
        Players.PlayerRemoving:Connect(function()
            task.wait(0.5)
            refreshPlayerList()
        end)
        
        notify("🚀 Super Tool Mobile Loaded!", Color3.fromRGB(0, 255, 0))
    end)
    if not success then
        warn("setupUI error: " .. errorMsg)
        notify("⚠️ Failed to setup UI, retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(1)
        setupUI()
    end
end

-- Cleanup function
local function cleanup()
    for _, connection in pairs(connections) do
        if connection then connection:Disconnect() end
    end
    if gui then gui:Destroy() end
end

-- Initialize with error handling
local function init()
    local success, errorMsg = pcall(function()
        setupUI()
    end)
    if not success then
        warn("Initialization error: " .. errorMsg)
        notify("⚠️ Script initialization failed, retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(2)
        init()
    end
end

-- Run initialization
init()

-- Cleanup on leave
game:BindToClose(cleanup)
player.AncestryChanged:Connect(function()
    if not player.Parent then cleanup() end
end)
