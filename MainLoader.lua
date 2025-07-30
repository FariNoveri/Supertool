-- SimpleGUI_Krnl.lua - UI Lama Simpel untuk Krnl Android
-- Fokus: Logo + Frame dengan tombol dasar, ringan dan stabil

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid, hr, char
local gui, frame, logo

-- Feature states
local flying = false
local noclip = false
local aimbotEnabled = false
local targetPart = "Head"
local aimbotSpeed = 0.5
local autoHeal = false

-- Mobile detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Notification system
local function notify(message, color)
    color = color or Color3.fromRGB(0, 255, 0)
    local success, errorMsg = pcall(function()
        if not gui then
            warn("Notify failed: GUI not initialized")
            return
        end
        local notif = Instance.new("TextLabel")
        notif.Size = UDim2.new(0, 300, 0, 50)
        notif.Position = UDim2.new(0.5, -150, 0, 50)
        notif.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notif.BackgroundTransparency = 0.3
        notif.TextColor3 = color
        notif.TextScaled = true
        notif.Font = Enum.Font.GothamBold
        notif.Text = message
        notif.BorderSizePixel = 0
        notif.ZIndex = 100
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

-- Initialize character
local function initChar()
    local success, errorMsg = pcall(function()
        char = player.Character or player.CharacterAdded:Wait()
        humanoid = char:WaitForChild("Humanoid", 10)
        hr = char:WaitForChild("HumanoidRootPart", 10)
        if not humanoid or not hr then
            error("Failed to find Humanoid or HumanoidRootPart")
        end
    end)
    if not success then
        warn("initChar error: " .. errorMsg)
        notify("⚠️ Failed to initialize character", Color3.fromRGB(255, 100, 100))
        task.wait(2)
        initChar()
    end
end

-- Create simple GUI
local function createGUI()
    local success, errorMsg = pcall(function()
        if gui then
            gui:Destroy()
            gui = nil
        end

        gui = Instance.new("ScreenGui")
        gui.Name = "SimpleGUI_Krnl"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Enabled = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
        local playerGui = player:WaitForChild("PlayerGui", 20)
        if not playerGui then
            warn("PlayerGui not found, trying CoreGui")
            gui.Parent = game:GetService("CoreGui")
        else
            gui.Parent = playerGui
        end
        warn("GUI parented to " .. (playerGui and "PlayerGui" or "CoreGui"))

        logo = Instance.new("ImageButton")
        logo.Size = UDim2.new(0, 80, 0, 80)
        logo.Position = UDim2.new(0, 10, 0, 10)
        logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        logo.BorderSizePixel = 0
        logo.Image = "rbxassetid://3570695787"
        logo.Visible = true
        logo.ZIndex = 100
        logo.Parent = gui
        
        local logoCorner = Instance.new("UICorner")
        logoCorner.CornerRadius = UDim.new(0, 40)
        logoCorner.Parent = logo

        frame = Instance.new("Frame")
        frame.Size = isMobile and UDim2.new(0.95, 0, 0.85, 0) or UDim2.new(0, 600, 0, 400)
        frame.Position = isMobile and UDim2.new(0.025, 0, 0.075, 0) or UDim2.new(0.5, -300, 0.5, -200)
        frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        frame.BorderSizePixel = 0
        frame.Visible = true
        frame.ZIndex = 50
        frame.Parent = gui
        
        local frameCorner = Instance.new("UICorner")
        frameCorner.CornerRadius = UDim.new(0, 12)
        frameCorner.Parent = frame

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 40)
        title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        title.TextColor3 = Color3.new(1, 1, 1)
        title.Text = "🚀 Simple Tool Krnl"
        title.TextScaled = true
        title.Font = Enum.Font.GothamBold
        title.ZIndex = 51
        title.Parent = frame

        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 30, 0, 30)
        closeBtn.Position = UDim2.new(1, -35, 0, 5)
        closeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        closeBtn.Text = "✕"
        closeBtn.TextColor3 = Color3.new(1, 1, 1)
        closeBtn.TextScaled = true
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.BorderSizePixel = 0
        closeBtn.ZIndex = 51
        closeBtn.Parent = frame
        
        local closeBtnCorner = Instance.new("UICorner")
        closeBtnCorner.CornerRadius = UDim.new(0, 15)
        closeBtnCorner.Parent = closeBtn
        
        closeBtn.Activated:Connect(function()
            frame.Visible = false
            notify("🖼️ GUI Closed", Color3.fromRGB(255, 100, 100))
        end)

        warn("GUI and Frame created")
    end)
    if not success then
        warn("createGUI error: " .. errorMsg)
        notify("⚠️ Failed to create GUI: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
        task.wait(1)
        createGUI()
    end
end

-- Touch drag system
local function makeDraggable(element)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    if isMobile then
        element.TouchPan:Connect(function(totalTranslation, _, state)
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

-- Create button
local function createButton(text, callback, parent, color)
    local success, errorMsg = pcall(function()
        color = color or Color3.fromRGB(60, 60, 60)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 100, 0, 50)
        btn.BackgroundColor3 = color
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamSemibold
        btn.Text = text
        btn.TextScaled = true
        btn.BorderSizePixel = 0
        btn.ZIndex = 51
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
                    notify("⚠️ Error in button: " .. text, Color3.fromRGB(255, 100, 100))
                end
            end
        end)
        
        warn("Button " .. text .. " created")
        return btn
    end)
    if not success then
        warn("createButton error: " .. errorMsg)
        notify("⚠️ Failed to create button " .. text .. ": " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Flying system
local function setupFlying()
    local bodyVel, bodyGyro
    local connections = {}
    
    local function startFly()
        if not hr or not humanoid then
            notify("⚠️ Cannot fly: Character not ready", Color3.fromRGB(255, 100, 100))
            return
        end
        
        bodyVel = Instance.new("BodyVelocity")
        bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bodyVel.Velocity = Vector3.new(0, 0, 0)
        bodyVel.Parent = hr
        
        bodyGyro = Instance.new("BodyAngularVelocity")
        bodyGyro.MaxTorque = Vector3.new(0, math.huge, 0)
        bodyGyro.AngularVelocity = Vector3.new(0, 0, 0)
        bodyGyro.Parent = hr
        
        flying = true
        notify("🚁 Flying ON", Color3.fromRGB(0, 255, 0))
        
        connections.flyLoop = RunService.Heartbeat:Connect(function()
            if not flying or not hr or not bodyVel or not humanoid or not camera then 
                return 
            end
            
            local moveVector = Vector3.new(0, 0, 0)
            local cam = camera.CFrame
            local forward = cam.LookVector.Unit
            local right = cam.RightVector.Unit
            local up = Vector3.new(0, 1, 0)
            
            if isMobile then
                local moveDir = humanoid.MoveDirection
                if moveDir.Magnitude > 0 then
                    moveVector = forward * -moveDir.Z * 16 + right * moveDir.X * 16
                    if moveDir.Y > 0.5 then
                        moveVector = moveVector + up * 16
                    elseif moveDir.Y < -0.5 then
                        moveVector = moveVector - up * 16
                    end
                end
            else
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveVector = moveVector + forward * 16
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveVector = moveVector - forward * 16
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveVector = moveVector - right * 16
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveVector = moveVector + right * 16
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveVector = moveVector + up * 16
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveVector = moveVector - up * 16
                end
            end
            
            bodyVel.Velocity = moveVector
            bodyGyro.CFrame = CFrame.new(Vector3.new(0, 0, 0)) * CFrame.Angles(0, -math.atan2(cam.LookVector.X, cam.LookVector.Z), 0)
        end)
    end
    
    local function stopFly()
        flying = false
        if bodyVel then bodyVel:Destroy() end
        if bodyGyro then bodyGyro:Destroy() end
        if connections.flyLoop then connections.flyLoop:Disconnect() end
        notify("🚁 Flying OFF", Color3.fromRGB(255, 100, 100))
    end
    
    return startFly, stopFly
end

-- Noclip system
local function setupNoclip()
    local connections = {}
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

-- Auto heal
local function setupAutoHeal()
    local connections = {}
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

-- Aimbot system
local function setupAimbot()
    local connections = {}
    
    local function getTargetPart(character)
        if targetPart == "Random" then
            local parts = {"Head", "Torso", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot"}
            targetPart = parts[math.random(1, #parts)]
        end
        return character:FindFirstChild(targetPart) or character:FindFirstChild("HumanoidRootPart")
    end
    
    local function getClosestPlayer()
        local closestPlayer = nil
        local closestDistance = math.huge
        local mousePos = UserInputService:GetMouseLocation()
        
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local targetPart = getTargetPart(p.Character)
                if targetPart then
                    local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        local distance = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(mousePos.X, mousePos.Y)).Magnitude
                        if distance < closestDistance then
                            closestDistance = distance
                            closestPlayer = p
                        end
                    end
                end
            end
        end
        return closestPlayer
    end
    
    local function toggleAimbot()
        aimbotEnabled = not aimbotEnabled
        if aimbotEnabled then
            notify("🎯 Aimbot ON", Color3.fromRGB(255, 0, 0))
            connections.aimbotLoop = RunService.RenderStepped:Connect(function()
                if not aimbotEnabled or not hr or not camera then return end
                local target = getClosestPlayer()
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local targetPart = getTargetPart(target.Character)
                    if targetPart then
                        local targetPos = targetPart.Position
                        local currentPos = camera.CFrame.Position
                        camera.CFrame = camera.CFrame:Lerp(CFrame.new(currentPos, targetPos), aimbotSpeed)
                    end
                end
            end)
        else
            notify("🎯 Aimbot OFF", Color3.fromRGB(255, 100, 100))
            if connections.aimbotLoop then connections.aimbotLoop:Disconnect() end
        end
    end
    
    return toggleAimbot
end

-- Setup UI
local function setupUI()
    local success, errorMsg = pcall(function()
        task.wait(0.5) -- Delay untuk pastikan PlayerGui ready
        createGUI()
        makeDraggable(logo)
        
        logo.Activated:Connect(function()
            frame.Visible = not frame.Visible
            notify("🖼️ GUI Toggled " .. (frame.Visible and "ON" or "OFF"), Color3.fromRGB(frame.Visible and 0 or 255, frame.Visible and 255 or 100, frame.Visible and 0 or 100))
        end)
        
        local buttonLayout = Instance.new("UIGridLayout")
        buttonLayout.CellSize = UDim2.new(0, 100, 0, 50)
        buttonLayout.CellPadding = UDim2.new(0, 10, 0, 10)
        buttonLayout.StartCorner = Enum.StartCorner.TopLeft
        buttonLayout.Parent = frame
        buttonLayout.Position = UDim2.new(0, 10, 0, 50)
        buttonLayout.Size = UDim2.new(1, -20, 1, -60)
        
        local startFly, stopFly = setupFlying()
        local toggleNoclip = setupNoclip()
        local toggleAimbot = setupAimbot()
        local toggleAutoHeal = setupAutoHeal()
        
        createButton("🚁 Fly", function()
            if flying then stopFly() else startFly() end
        end, frame, Color3.fromRGB(0, 150, 255))
        
        createButton("👻 Noclip", toggleNoclip, frame, Color3.fromRGB(0, 150, 255))
        
        createButton("🎯 Aimbot", toggleAimbot, frame, Color3.fromRGB(255, 0, 0))
        
        createButton("💚 Heal", toggleAutoHeal, frame, Color3.fromRGB(0, 255, 0))
        
        createButton("🏃 Speed", function()
            if humanoid then
                humanoid.WalkSpeed = humanoid.WalkSpeed == 16 and 50 or 16
                notify("Speed: " .. humanoid.WalkSpeed, Color3.fromRGB(255, 255, 0))
            end
        end, frame, Color3.fromRGB(255, 255, 0))
        
        createButton("🦘 Jump", function()
            if humanoid then
                humanoid.JumpPower = humanoid.JumpPower == 50 and 120 or 50
                notify("Jump Power: " .. humanoid.JumpPower, Color3.fromRGB(255, 255, 0))
            end
        end, frame, Color3.fromRGB(255, 255, 0))
        
        createButton("🔄 Reset", function()
            if humanoid then
                humanoid.Health = 0
                notify("Character reset", Color3.fromRGB(255, 100, 100))
            end
        end, frame, Color3.fromRGB(255, 100, 100))
        
        initChar()
        
        player.CharacterAdded:Connect(function()
            task.wait(1)
            initChar()
        end)
        
        notify("🚀 Simple Tool Loaded", Color3.fromRGB(0, 255, 0))
    end)
    if not success then
        warn("setupUI error: " .. errorMsg)
        notify("⚠️ Failed to setup UI: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
        task.wait(1)
        setupUI()
    end
end

-- Initialize
local function init()
    local success, errorMsg = pcall(function()
        task.wait(0.5) -- Delay untuk pastikan Krnl inject
        setupUI()
        if gui and frame then
            gui.Enabled = true
            frame.Visible = true
            warn("GUI and Frame initialized, should be visible")
            notify("🖼️ Simple GUI Loaded", Color3.fromRGB(0, 255, 0))
        else
            error("GUI or Frame not initialized")
        end
    end)
    if not success then
        warn("init error: " .. errorMsg)
        notify("⚠️ Failed to initialize: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
        task.wait(1)
        init()
    end
end

init()
