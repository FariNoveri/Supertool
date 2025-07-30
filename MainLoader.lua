-- TabbedGUI_Krnl.lua - GUI dengan Tab Menu untuk Krnl Android
-- Fix "computation failed: Illegal instruction" dan GUI nggak muncul

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid, hr, char
local gui, frame, logo
local tabs = {}
local currentTab = nil

-- Feature states
local flying, noclip, autoHeal, noFall, godMode = false, false, false, false, false
local flySpeed = 16
local savedPositions = {}
local followTarget = nil
local connections = {}
local antiRagdoll = false
local aimbotEnabled = false
local aimbulletEnabled = false
local targetPart = "Head"
local aimbotSpeed = 0.5
local aimbulletSpeed = 100
local useFOV = false
local fovRadius = 100
local espEnabled = false
local ignoreTeam = false
local bulletSpeed = 100
local antiSpectate = false
local antiReport = false
local nickHidden = false
local customNick = ""
local randomNick = false
local trajectoryEnabled = false
local macroRecording = false
local macroPlaying = false
local macroActions = {}
local macroNoclip = false
local autoPlayOnRespawn = false

-- Mobile detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Notification system
local function notify(message, color)
    local success, errorMsg = pcall(function()
        if not gui then
            warn("Notify failed: GUI not initialized")
            return
        end
        local notif = Instance.new("TextLabel")
        notif.Size = UDim2.new(0, 150, 0, 30)
        notif.Position = UDim2.new(0.5, -75, 0, 10)
        notif.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notif.BackgroundTransparency = 0.6
        notif.TextColor3 = color or Color3.fromRGB(0, 255, 0)
        notif.TextScaled = true
        notif.Font = Enum.Font.Gotham
        notif.Text = message
        notif.BorderSizePixel = 0
        notif.ZIndex = 5
        notif.Parent = gui
        task.wait(2)
        notif:Destroy()
    end)
    if not success then
        warn("Notify error: " .. tostring(errorMsg))
    end
end

-- Initialize character
local function initChar()
    local success, errorMsg = pcall(function()
        task.wait(5) -- Delay panjang
        char = player.Character or player.CharacterAdded:Wait()
        humanoid = char:WaitForChild("Humanoid", 20)
        hr = char:WaitForChild("HumanoidRootPart", 20)
        if not humanoid or not hr then
            error("Failed to find Humanoid or HumanoidRootPart")
        end
        warn("Character initialized")
    end)
    if not success then
        warn("initChar error: " .. tostring(errorMsg))
        notify("⚠️ Init character failed, retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(5)
        initChar()
    end
end

-- Create button
local function createButton(text, callback, parent, color)
    local success, errorMsg = pcall(function()
        color = color or Color3.fromRGB(60, 60, 60)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 35)
        btn.BackgroundColor3 = color
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.Gotham
        btn.Text = text
        btn.TextScaled = true
        btn.BorderSizePixel = 0
        btn.ZIndex = 6
        btn.Parent = parent
        btn.Activated:Connect(function()
            if callback then
                local success, errorMsg = pcall(callback)
                if not success then
                    warn("Button callback error: " .. tostring(errorMsg))
                    notify("⚠️ Error in " .. text, Color3.fromRGB(255, 100, 100))
                end
            end
        end)
        warn("Button " .. text .. " created")
        return btn
    end)
    if not success then
        warn("createButton error: " .. tostring(errorMsg))
        notify("⚠️ Failed to create button " .. text, Color3.fromRGB(255, 100, 100))
    end
end

-- Create text input
local function createTextInput(placeholder, parent, callback)
    local success, errorMsg = pcall(function()
        local inputFrame = Instance.new("Frame")
        inputFrame.Size = UDim2.new(1, -10, 0, 35)
        inputFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        inputFrame.BorderSizePixel = 0
        inputFrame.ZIndex = 6
        inputFrame.Parent = parent
        
        local textBox = Instance.new("TextBox")
        textBox.Size = UDim2.new(1, -10, 1, -10)
        textBox.Position = UDim2.new(0, 5, 0, 5)
        textBox.BackgroundTransparency = 1
        textBox.TextColor3 = Color3.new(1, 1, 1)
        textBox.Font = Enum.Font.Gotham
        textBox.TextScaled = true
        textBox.PlaceholderText = placeholder
        textBox.Text = ""
        textBox.ZIndex = 7
        textBox.Parent = inputFrame
        
        textBox.FocusLost:Connect(function(enterPressed)
            if enterPressed and callback then
                callback(textBox.Text)
            end
        end)
        warn("TextInput " .. placeholder .. " created")
        return inputFrame
    end)
    if not success then
        warn("createTextInput error: " .. tostring(errorMsg))
        notify("⚠️ Failed to create input", Color3.fromRGB(255, 100, 100))
    end
end

-- Create tab
local function createTab(name, parent)
    local tabFrame = Instance.new("ScrollingFrame")
    tabFrame.Size = UDim2.new(1, -10, 1, -40)
    tabFrame.Position = UDim2.new(0, 5, 0, 35)
    tabFrame.BackgroundTransparency = 1
    tabFrame.BorderSizePixel = 0
    tabFrame.CanvasSize = UDim2.new(0, 0, 2, 0)
    tabFrame.ScrollBarThickness = 4
    tabFrame.ZIndex = 6
    tabFrame.Parent = parent
    tabFrame.Visible = false
    
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    layout.Parent = tabFrame
    
    tabs[name] = tabFrame
    return tabFrame
end

-- Switch tab
local function switchTab(tabName)
    for name, tab in pairs(tabs) do
        tab.Visible = (name == tabName)
    end
    currentTab = tabName
    notify("Tab: " .. tabName)
end

-- Create GUI
local function createGUI()
    local success, errorMsg = pcall(function()
        if gui then
            gui:Destroy()
            gui = nil
        end

        gui = Instance.new("ScreenGui")
        gui.Name = "TabbedGUI_Krnl"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Enabled = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        local coreGui = game:GetService("CoreGui")
        local playerGui = player:WaitForChild("PlayerGui", 20)
        gui.Parent = playerGui or coreGui
        warn("GUI parented to " .. (playerGui and "PlayerGui" or "CoreGui"))

        logo = Instance.new("ImageButton")
        logo.Size = UDim2.new(0, 50, 0, 50)
        logo.Position = UDim2.new(0, 5, 0, 5)
        logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        logo.BorderSizePixel = 0
        logo.Image = "rbxassetid://3570695787"
        logo.ZIndex = 5
        logo.Parent = gui

        frame = Instance.new("Frame")
        frame.Size = isMobile and UDim2.new(0.85, 0, 0.7, 0) or UDim2.new(0, 300, 0, 250)
        frame.Position = isMobile and UDim2.new(0.075, 0, 0.15, 0) or UDim2.new(0.5, -150, 0.5, -125)
        frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        frame.BorderSizePixel = 0
        frame.Visible = false
        frame.ZIndex = 5
        frame.Parent = gui

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 30)
        title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        title.TextColor3 = Color3.new(1, 1, 1)
        title.Text = "🚀 Krnl Tool"
        title.TextScaled = true
        title.Font = Enum.Font.Gotham
        title.ZIndex = 6
        title.Parent = frame

        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 25, 0, 25)
        closeBtn.Position = UDim2.new(1, -30, 0, 5)
        closeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        closeBtn.Text = "✕"
        closeBtn.TextColor3 = Color3.new(1, 1, 1)
        closeBtn.TextScaled = true
        closeBtn.Font = Enum.Font.Gotham
        closeBtn.BorderSizePixel = 0
        closeBtn.ZIndex = 6
        closeBtn.Parent = frame
        closeBtn.Activated:Connect(function()
            frame.Visible = false
            notify("🖼️ GUI Closed")
        end)

        local tabBar = Instance.new("Frame")
        tabBar.Size = UDim2.new(1, 0, 0, 30)
        tabBar.Position = UDim2.new(0, 0, 0, 30)
        tabBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        tabBar.BorderSizePixel = 0
        tabBar.ZIndex = 6
        tabBar.Parent = frame

        local tabLayout = Instance.new("UIListLayout")
        tabLayout.FillDirection = Enum.FillDirection.Horizontal
        tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
        tabLayout.Padding = UDim.new(0, 5)
        tabLayout.Parent = tabBar

        local function createTabButton(name, order)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0.25, -5, 1, 0)
            btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            btn.TextColor3 = Color3.new(1, 1, 1)
            btn.Text = name
            btn.TextScaled = true
            btn.Font = Enum.Font.Gotham
            btn.BorderSizePixel = 0
            btn.ZIndex = 6
            btn.LayoutOrder = order
            btn.Parent = tabBar
            btn.Activated:Connect(function()
                switchTab(name)
            end)
        end

        createTabButton("Movement", 1)
        createTabButton("Combat", 2)
        createTabButton("Utility", 3)
        createTabButton("Misc", 4)

        warn("GUI created")
    end)
    if not success then
        warn("createGUI error: " .. tostring(errorMsg))
        notify("⚠️ GUI creation failed, retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(5)
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
                    startPos.X.Scale, startPos.X.Offset + totalTranslation.X,
                    startPos.Y.Scale, startPos.Y.Offset + totalTranslation.Y
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

-- Flying system
local function setupFlying()
    local bodyVel, bodyGyro
    
    local function startFly()
        if not hr or not humanoid then
            notify("⚠️ Cannot fly", Color3.fromRGB(255, 100, 100))
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
        notify("🚁 Flying ON")
        
        connections.flyLoop = RunService.Stepped:Connect(function()
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
                    moveVector = forward * -moveDir.Z * flySpeed + right * moveDir.X * flySpeed
                    if moveDir.Y > 0.5 then
                        moveVector = moveVector + up * flySpeed
                    elseif moveDir.Y < -0.5 then
                        moveVector = moveVector - up * flySpeed
                    end
                end
            else
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveVector = moveVector + forward * flySpeed
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveVector = moveVector - forward * flySpeed
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveVector = moveVector - right * flySpeed
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveVector = moveVector + right * flySpeed
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveVector = moveVector + up * flySpeed
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveVector = moveVector - up * flySpeed
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
    local function toggleNoclip()
        noclip = not noclip
        if noclip then
            notify("👻 Noclip ON")
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
    local function toggleAutoHeal()
        autoHeal = not autoHeal
        if autoHeal then
            notify("💚 Auto Heal ON")
            connections.healLoop = RunService.Stepped:Connect(function()
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

-- God mode
local function setupGodMode()
    local function toggleGodMode()
        godMode = not godMode
        if godMode then
            notify("⚡ God Mode ON")
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

-- No fall damage
local function setupNoFallDamage()
    local function toggleNoFallDamage()
        noFall = not noFall
        if noFall then
            notify("🛡️ No Fall ON")
            connections.fallDamageLoop = humanoid.StateChanged:Connect(function(oldState, newState)
                if newState == Enum.HumanoidStateType.Freefall and noFall then
                    humanoid.FallDamage = 0
                end
            end)
        else
            notify("🛡️ No Fall OFF", Color3.fromRGB(255, 100, 100))
            if connections.fallDamageLoop then connections.fallDamageLoop:Disconnect() end
        end
    end
    return toggleNoFallDamage
end

-- Anti ragdoll
local function setupAntiRagdoll()
    local function toggleAntiRagdoll()
        antiRagdoll = not antiRagdoll
        if antiRagdoll then
            notify("🛡️ Anti Ragdoll ON")
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

-- Position save/load
local function setupPositions()
    local function savePosition(name)
        if not hr then return end
        savedPositions[name] = hr.CFrame
        notify("📍 Saved " .. name)
    end
    local function loadPosition(name)
        if not hr or not savedPositions[name] then return end
        hr.CFrame = savedPositions[name]
        notify("📍 Loaded " .. name)
    end
    return savePosition, loadPosition
end

-- Player interaction
local function setupPlayerSystem()
    local function teleportToPlayer(targetPlayer)
        if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and hr then
            hr.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
            notify("Teleported to " .. targetPlayer.Name)
        end
    end
    local function followPlayer(targetPlayer)
        followTarget = targetPlayer
        notify("Following " .. targetPlayer.Name)
        if connections.followLoop then connections.followLoop:Disconnect() end
        connections.followLoop = RunService.Stepped:Connect(function()
            if followTarget and followTarget.Character and followTarget.Character:FindFirstChild("HumanoidRootPart") and hr then
                hr.CFrame = followTarget.Character.HumanoidRootPart.CFrame + Vector3.new(0, 5, 5)
            end
        end)
    end
    local function stopFollow()
        followTarget = nil
        if connections.followLoop then connections.followLoop:Disconnect() end
        notify("Stopped following", Color3.fromRGB(255, 100, 100))
    end
    return teleportToPlayer, followPlayer, stopFollow
end

-- Combat system
local function setupCombat()
    local espGuis = {}
    local fovCircle = nil
    
    local function getTargetPart(character)
        if targetPart == "Random" then
            local parts = {"Head", "Torso", "LeftLeg", "RightLeg"}
            targetPart = parts[math.random(1, #parts)]
        end
        return character:FindFirstChild(targetPart) or character:FindFirstChild("HumanoidRootPart")
    end
    
    local function getClosestPlayer()
        local closestPlayer = nil
        local closestDistance = useFOV and fovRadius or math.huge
        local mousePos = UserInputService:GetMouseLocation()
        
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                if ignoreTeam and p.Team == player.Team then continue end
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
            notify("🎯 Aimbot ON")
            connections.aimbotLoop = RunService.Stepped:Connect(function()
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
                task.wait(0.05)
            end)
        else
            notify("🎯 Aimbot OFF", Color3.fromRGB(255, 100, 100))
            if connections.aimbotLoop then connections.aimbotLoop:Disconnect() end
        end
    end
    
    local function toggleAimbullet()
        aimbulletEnabled = not aimbulletEnabled
        if aimbulletEnabled then
            notify("🔫 Aimbullet ON")
            connections.aimbulletLoop = RunService.Stepped:Connect(function()
                if not aimbulletEnabled or not hr or not camera then return end
                local target = getClosestPlayer()
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local targetPart = getTargetPart(target.Character)
                    if targetPart then
                        for _, obj in pairs(workspace:GetChildren()) do
                            if obj:IsA("BasePart") and obj.Name:lower():find("bullet") then
                                local bodyVel = obj:FindFirstChildOfClass("BodyVelocity") or Instance.new("BodyVelocity", obj)
                                bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                                bodyVel.Velocity = (targetPart.Position - obj.Position).Unit * aimbulletSpeed
                            end
                        end
                    end
                end
                task.wait(0.05)
            end)
        else
            notify("🔫 Aimbullet OFF", Color3.fromRGB(255, 100, 100))
            if connections.aimbulletLoop then connections.aimbulletLoop:Disconnect() end
        end
    end
    
    local function toggleESP()
        espEnabled = not espEnabled
        if espEnabled then
            notify("👁️ ESP ON")
            connections.espLoop = RunService.Stepped:Connect(function()
                for _, gui in pairs(espGuis) do gui:Destroy() end
                espGuis = {}
                local count = 0
                for _, p in ipairs(Players:GetPlayers()) do
                    if count >= 5 then break end
                    if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        if ignoreTeam and p.Team == player.Team then continue end
                        local head = p.Character:FindFirstChild("Head")
                        if head then
                            local billboard = Instance.new("BillboardGui")
                            billboard.Size = UDim2.new(0, 30, 0, 30)
                            billboard.Adornee = head
                            billboard.AlwaysOnTop = true
                            billboard.Parent = head
                            local skull = Instance.new("ImageLabel")
                            skull.Size = UDim2.new(1, 0, 1, 0)
                            skull.BackgroundTransparency = 1
                            skull.Image = "rbxassetid://2790389767"
                            skull.Parent = billboard
                            table.insert(espGuis, billboard)
                            count = count + 1
                        end
                    end
                end
                task.wait(0.1)
            end)
        else
            notify("👁️ ESP OFF", Color3.fromRGB(255, 100, 100))
            if connections.espLoop then connections.espLoop:Disconnect() end
            for _, gui in pairs(espGuis) do gui:Destroy() end
            espGuis = {}
        end
    end
    
    local function toggleFOV()
        useFOV = not useFOV
        if useFOV then
            notify("🔲 FOV ON")
            fovCircle = Instance.new("Frame")
            fovCircle.Size = UDim2.new(0, fovRadius * 2, 0, fovRadius * 2)
            fovCircle.Position = UDim2.new(0.5, -fovRadius, 0.5, -fovRadius)
            fovCircle.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
            fovCircle.BackgroundTransparency = 0.9
            fovCircle.BorderSizePixel = 0
            fovCircle.ZIndex = 6
            fovCircle.Parent = gui
        else
            notify("🔲 FOV OFF", Color3.fromRGB(255, 100, 100))
            if fovCircle then fovCircle:Destroy() end
            fovCircle = nil
        end
    end
    
    local function setTargetPart(part)
        targetPart = part
        notify("🎯 Target: " .. part)
    end
    
    local function adjustAimbotSpeed(delta)
        aimbotSpeed = math.clamp(aimbotSpeed + delta, 0.1, 1)
        notify("🎯 Aim Speed: " .. aimbotSpeed)
    end
    
    local function adjustAimbulletSpeed(delta)
        aimbulletSpeed = math.clamp(aimbulletSpeed + delta, 50, 200)
        notify("🔫 Bullet Speed: " .. aimbulletSpeed)
    end
    
    local function adjustBulletSpeed(delta)
        bulletSpeed = math.clamp(bulletSpeed + delta, 50, 200)
        notify("💨 Speed: " .. bulletSpeed)
        for _, obj in pairs(workspace:GetChildren()) do
            if obj:IsA("BasePart") and obj.Name:lower():find("bullet") then
                local bodyVel = obj:FindFirstChildOfClass("BodyVelocity")
                if bodyVel then
                    bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                    bodyVel.Velocity = bodyVel.Velocity.Unit * bulletSpeed
                end
            end
        end
    end
    
    local function toggleIgnoreTeam()
        ignoreTeam = not ignoreTeam
        notify("👥 Ignore Team: " .. (ignoreTeam and "ON" or "OFF"))
    end
    
    return toggleAimbot, toggleAimbullet, toggleESP, toggleFOV, setTargetPart, adjustAimbotSpeed, adjustAimbulletSpeed, adjustBulletSpeed, toggleIgnoreTeam
end

-- Nickname system
local function setupNickname()
    local function toggleHideNick()
        nickHidden = not nickHidden
        if nickHidden then
            player.DisplayName = ""
            notify("🕵️ Nick Hidden")
        else
            player.DisplayName = player.Name
            notify("🕵️ Nick Visible", Color3.fromRGB(255, 100, 100))
        end
    end
    
    local function setCustomNick(name)
        if name == "" then
            notify("⚠️ Nickname empty", Color3.fromRGB(255, 100, 100))
            return
        end
        customNick = name
        player.DisplayName = name
        randomNick = false
        notify("🕵️ Nick: " .. name)
    end
    
    local function toggleRandomNick()
        randomNick = not randomNick
        if randomNick then
            local randomNames = {"Shadow", "Blaze", "Phantom", "Ghost"}
            player.DisplayName = randomNames[math.random(1, #randomNames)] .. math.random(100, 999)
            notify("🕵️ Random Nick: " .. player.DisplayName)
        else
            player.DisplayName = player.Name
            notify("🕵️ Nick Restored", Color3.fromRGB(255, 100, 100))
        end
    end
    return toggleHideNick, setCustomNick, toggleRandomNick
end

-- Anti Spectate and Anti Report
local function setupAntiFeatures()
    local function toggleAntiSpectate()
        antiSpectate = not antiSpectate
        if antiSpectate then
            notify("🕵️ Anti Spectate ON")
            camera.CameraType = Enum.CameraType.Fixed
        else
            notify("🕵️ Anti Spectate OFF", Color3.fromRGB(255, 100, 100))
            camera.CameraType = Enum.CameraType.Custom
        end
    end
    
    local function toggleAntiReport()
        antiReport = not antiReport
        notify("🚫 Anti Report " .. (antiReport and "ON" or "OFF"))
    end
    return toggleAntiSpectate, toggleAntiReport
end

-- Trajectory and Macro
local function setupTrajectoryAndMacro()
    local trajectoryBeams = {}
    local maxDistance = 50

    local function clearTrajectory()
        for _, beam in ipairs(trajectoryBeams) do
            beam:Destroy()
        end
        trajectoryBeams = {}
    end

    local function drawTrajectory()
        clearTrajectory()
        if not trajectoryEnabled or not hr or not camera then
            notify("⚠️ Cannot draw trajectory", Color3.fromRGB(255, 100, 100))
            return
        end
        local startPos = hr.Position + camera.CFrame.LookVector * 2 + Vector3.new(0, 1, 0)
        local direction = camera.CFrame.LookVector
        local endPos = startPos + direction * maxDistance
        local ray = Ray.new(startPos, direction * maxDistance)
        local hit, hitPos = workspace:FindPartOnRayWithIgnoreList(ray, {char})
        if hit then
            endPos = hitPos
        end
        local attachment0 = Instance.new("Attachment")
        attachment0.Position = startPos
        attachment0.Parent = workspace.Terrain
        local attachment1 = Instance.new("Attachment")
        attachment1.Position = endPos
        attachment1.Parent = workspace.Terrain
        local beam = Instance.new("Beam")
        beam.Attachment0 = attachment0
        beam.Attachment1 = attachment1
        beam.Width0 = 0.1
        beam.Width1 = 0.1
        beam.LightEmission = 1
        beam.LightInfluence = 0
        beam.Color = ColorSequence.new((endPos - startPos).Magnitude < 20 and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0))
        beam.Parent = workspace
        table.insert(trajectoryBeams, beam)
        table.insert(trajectoryBeams, attachment0)
        table.insert(trajectoryBeams, attachment1)
        task.wait(0.1)
    end

    local function toggleTrajectory()
        trajectoryEnabled = not trajectoryEnabled
        if trajectoryEnabled then
            notify("📏 Trajectory ON")
            connections.trajectoryLoop = RunService.Stepped:Connect(drawTrajectory)
        else
            notify("📏 Trajectory OFF", Color3.fromRGB(255, 100, 100))
            clearTrajectory()
            if connections.trajectoryLoop then connections.trajectoryLoop:Disconnect() end
        end
    end

    local function startRecordingMacro()
        macroRecording = true
        macroActions = {}
        notify("🎥 Recording Macro")
        connections.macroRecordLoop = RunService.Stepped:Connect(function()
            if not macroRecording or not humanoid or not hr then return end
            table.insert(macroActions, {
                position = hr.CFrame,
                moveDirection = humanoid.MoveDirection,
                jump = humanoid.Jump
            })
            if #macroActions > 100 then
                stopRecordingMacro()
            end
        end)
    end

    local function stopRecordingMacro()
        macroRecording = false
        if connections.macroRecordLoop then connections.macroRecordLoop:Disconnect() end
        notify("🎥 Macro Recorded (" .. #macroActions .. ")")
    end

    local function playMacro()
        if #macroActions == 0 then
            notify("⚠️ No Macro", Color3.fromRGB(255, 100, 100))
            return
        end
        if not humanoid or not hr then
            notify("⚠️ Cannot play macro", Color3.fromRGB(255, 100, 100))
            return
        end
        if not noclip then
            local toggleNoclip = setupNoclip()
            toggleNoclip()
            macroNoclip = true
        end
        macroPlaying = true
        notify("▶️ Playing Macro")
        if macroActions[1] then
            hr.CFrame = macroActions[1].position
        end
        local bodyVel = Instance.new("BodyVelocity")
        bodyVel.MaxForce = Vector3.new(math.huge, 0, math.huge)
        bodyVel.Parent = hr
        local actionIndex = 1
        connections.macroPlayLoop = RunService.Stepped:Connect(function()
            if not macroPlaying or not humanoid or not hr then
                macroPlaying = false
                if bodyVel then bodyVel:Destroy() end
                if connections.macroPlayLoop then connections.macroPlayLoop:Disconnect() end
                notify("⚠️ Macro stopped", Color3.fromRGB(255, 100, 100))
                return
            end
            if actionIndex <= #macroActions then
                local action = macroActions[actionIndex]
                hr.CFrame = action.position
                bodyVel.Velocity = action.moveDirection.Magnitude > 0 and action.moveDirection * 16 or Vector3.new(0, 0, 0)
                if action.jump then
                    humanoid.Jump = true
                end
                actionIndex = actionIndex + 1
                task.wait(0.05)
            else
                macroPlaying = false
                if bodyVel then bodyVel:Destroy() end
                if connections.macroPlayLoop then connections.macroPlayLoop:Disconnect() end
                if macroNoclip then
                    local toggleNoclip = setupNoclip()
                    toggleNoclip()
                    macroNoclip = false
                end
                notify("⏹️ Macro Finished", Color3.fromRGB(255, 100, 100))
            end
        end)
    end

    local function stopPlayingMacro()
        macroPlaying = false
        if connections.macroPlayLoop then connections.macroPlayLoop:Disconnect() end
        if hr then
            for _, obj in pairs(hr:GetChildren()) do
                if obj:IsA("BodyVelocity") then obj:Destroy() end
            end
        end
        if macroNoclip then
            local toggleNoclip = setupNoclip()
            toggleNoclip()
            macroNoclip = false
        end
        notify("⏹️ Macro Stopped", Color3.fromRGB(255, 100, 100))
    end

    local function toggleAutoPlay()
        autoPlayOnRespawn = not autoPlayOnRespawn
        notify("🔄 AutoPlay: " .. (autoPlayOnRespawn and "ON" or "OFF"))
    end

    return toggleTrajectory, startRecordingMacro, stopRecordingMacro, playMacro, stopPlayingMacro, toggleAutoPlay
end

-- Setup UI
local function setupUI()
    local success, errorMsg = pcall(function()
        task.wait(5) -- Delay panjang
        createGUI()
        makeDraggable(logo)
        
        logo.Activated:Connect(function()
            frame.Visible = not frame.Visible
            notify("🖼️ GUI " .. (frame.Visible and "ON" or "OFF"))
            if frame.Visible and not currentTab then
                switchTab("Movement")
            end
        end)
        
        -- Create tabs
        local movementTab = createTab("Movement", frame)
        local combatTab = createTab("Combat", frame)
        local utilityTab = createTab("Utility", frame)
        local miscTab = createTab("Misc", frame)

        -- Movement Tab
        local startFly, stopFly = setupFlying()
        local toggleNoclip = setupNoclip()
        createButton("🚁 Fly", function()
            if flying then stopFly() else startFly() end
        end, movementTab, Color3.fromRGB(0, 150, 255))
        createButton("👻 Noclip", toggleNoclip, movementTab, Color3.fromRGB(0, 150, 255))
        createButton("🏃 Speed", function()
            if humanoid then
                humanoid.WalkSpeed = humanoid.WalkSpeed == 16 and 50 or 16
                notify("Speed: " .. humanoid.WalkSpeed)
            end
        end, movementTab, Color3.fromRGB(255, 255, 0))
        createButton("🦘 Jump", function()
            if humanoid then
                humanoid.JumpPower = humanoid.JumpPower == 50 and 120 or 50
                notify("Jump: " .. humanoid.JumpPower)
            end
        end, movementTab, Color3.fromRGB(255, 255, 0))
        createButton("🌊 Water Walk", function()
            local walkOnWater = not workspace.Terrain.ReadVoxels
            for _, part in pairs(workspace:GetDescendants()) do
                if part:IsA("BasePart") and part.Material == Enum.Material.Water then
                    part.CanCollide = walkOnWater
                end
            end
            notify("Water Walk: " .. (walkOnWater and "ON" or "OFF"))
        end, movementTab, Color3.fromRGB(0, 150, 255))
        createButton("🚀 Rocket", function()
            if hr then
                local rocket = Instance.new("BodyVelocity")
                rocket.MaxForce = Vector3.new(4000, 4000, 4000)
                rocket.Velocity = Vector3.new(0, 100, 0)
                rocket.Parent = hr
                task.wait(0.5)
                rocket:Destroy()
                notify("🚀 Rocket Jump")
            end
        end, movementTab, Color3.fromRGB(255, 100, 0))
        createButton("🌪️ Spin", function()
            if hr then
                local spin = Instance.new("BodyAngularVelocity")
                spin.MaxTorque = Vector3.new(0, 4000, 0)
                spin.AngularVelocity = Vector3.new(0, 50, 0)
                spin.Parent = hr
                task.wait(1)
                spin:Destroy()
                notify("🌪️ Spin Done")
            end
        end, movementTab, Color3.fromRGB(255, 255, 0))

        -- Combat Tab
        local toggleAimbot, toggleAimbullet, toggleESP, toggleFOV, setTargetPart, adjustAimbotSpeed, adjustAimbulletSpeed, adjustBulletSpeed, toggleIgnoreTeam = setupCombat()
        createButton("🎯 Aimbot", toggleAimbot, combatTab, Color3.fromRGB(255, 0, 0))
        createButton("🔫 Aimbullet", toggleAimbullet, combatTab, Color3.fromRGB(255, 0, 0))
        createButton("👁️ ESP", toggleESP, combatTab, Color3.fromRGB(255, 0, 255))
        createButton("🔲 FOV", toggleFOV, combatTab, Color3.fromRGB(0, 255, 255))
        createButton("👥 Ignore Team", toggleIgnoreTeam, combatTab, Color3.fromRGB(0, 255, 0))
        createButton("🎯 Head", function() setTargetPart("Head") end, combatTab, Color3.fromRGB(255, 0, 0))
        createButton("🎯 Body", function() setTargetPart("Torso") end, combatTab, Color3.fromRGB(255, 0, 0))
        createButton("🎯 Legs", function() setTargetPart("LeftLeg") end, combatTab, Color3.fromRGB(255, 0, 0))
        createButton("🎯 Random", function() setTargetPart("Random") end, combatTab, Color3.fromRGB(255, 0, 0))
        createButton("⚡ Aim +", function() adjustAimbotSpeed(0.1) end, combatTab, Color3.fromRGB(255, 0, 0))
        createButton("⚡ Aim -", function() adjustAimbotSpeed(-0.1) end, combatTab, Color3.fromRGB(255, 0, 0))
        createButton("🔫 Bullet +", function() adjustAimbulletSpeed(10) end, combatTab, Color3.fromRGB(255, 0, 0))
        createButton("🔫 Bullet -", function() adjustAimbulletSpeed(-10) end, combatTab, Color3.fromRGB(255, 0, 0))
        createButton("💨 Speed +", function() adjustBulletSpeed(10) end, combatTab, Color3.fromRGB(255, 0, 0))
        createButton("💨 Speed -", function() adjustBulletSpeed(-10) end, combatTab, Color3.fromRGB(255, 0, 0))

        -- Utility Tab
        local toggleAutoHeal = setupAutoHeal()
        local toggleGodMode = setupGodMode()
        local toggleNoFallDamage = setupNoFallDamage()
        local toggleAntiRagdoll = setupAntiRagdoll()
        local savePosition, loadPosition = setupPositions()
        local teleportToPlayer, followPlayer, stopFollow = setupPlayerSystem()
        createButton("💚 Heal", toggleAutoHeal, utilityTab, Color3.fromRGB(0, 255, 0))
        createButton("⚡ God", toggleGodMode, utilityTab, Color3.fromRGB(255, 215, 0))
        createButton("🛡️ No Fall", toggleNoFallDamage, utilityTab, Color3.fromRGB(0, 255, 0))
        createButton("🛡️ Anti Ragdoll", toggleAntiRagdoll, utilityTab, Color3.fromRGB(0, 255, 0))
        createButton("📍 Save Pos 1", function() savePosition("pos1") end, utilityTab, Color3.fromRGB(0, 255, 0))
        createButton("📍 Load Pos 1", function() loadPosition("pos1") end, utilityTab, Color3.fromRGB(0, 255, 255))
        createButton("📍 Save Pos 2", function() savePosition("pos2") end, utilityTab, Color3.fromRGB(0, 255, 0))
        createButton("📍 Load Pos 2", function() loadPosition("pos2") end, utilityTab, Color3.fromRGB(0, 255, 255))
        createButton("🏠 Spawn", function()
            if hr then
                hr.CFrame = CFrame.new(0, 50, 0)
                notify("Teleported to spawn")
            end
        end, utilityTab, Color3.fromRGB(0, 255, 255))
        createButton("🔄 TP to Player", function()
            local target = Players:GetPlayers()[2]
            if target then teleportToPlayer(target) end
        end, utilityTab, Color3.fromRGB(0, 255, 255))
        createButton("🎯 Follow", function()
            local target = Players:GetPlayers()[2]
            if target then followPlayer(target) end
        end, utilityTab, Color3.fromRGB(255, 165, 0))
        createButton("🚫 Stop Follow", stopFollow, utilityTab, Color3.fromRGB(255, 100, 100))

        -- Misc Tab
        local toggleHideNick, setCustomNick, toggleRandomNick = setupNickname()
        local toggleAntiSpectate, toggleAntiReport = setupAntiFeatures()
        local toggleTrajectory, startRecordingMacro, stopRecordingMacro, playMacro, stopPlayingMacro, toggleAutoPlay = setupTrajectoryAndMacro()
        createButton("🕵️ Hide Nick", toggleHideNick, miscTab, Color3.fromRGB(0, 255, 0))
        createButton("🕵️ Random Nick", toggleRandomNick, miscTab, Color3.fromRGB(0, 255, 0))
        createTextInput("Enter Nick", miscTab, setCustomNick)
        createButton("🕵️ Anti Spectate", toggleAntiSpectate, miscTab, Color3.fromRGB(0, 255, 0))
        createButton("🚫 Anti Report", toggleAntiReport, miscTab, Color3.fromRGB(0, 255, 0))
        createButton("📏 Trajectory", toggleTrajectory, miscTab, Color3.fromRGB(255, 0, 0))
        createButton("🎥 Record Macro", startRecordingMacro, miscTab, Color3.fromRGB(0, 255, 0))
        createButton("⏹️ Stop Record", stopRecordingMacro, miscTab, Color3.fromRGB(255, 100, 100))
        createButton("▶️ Play Macro", playMacro, miscTab, Color3.fromRGB(0, 255, 255))
        createButton("🚫 Stop Macro", stopPlayingMacro, miscTab, Color3.fromRGB(255, 100, 100))
        createButton("🔄 AutoPlay", toggleAutoPlay, miscTab, Color3.fromRGB(0, 150, 255))
        createButton("🔄 Reset", function()
            if humanoid then
                humanoid.Health = 0
                notify("Reset")
            end
        end, miscTab, Color3.fromRGB(255, 100, 100))
        createButton("🧹 Clean", function()
            for _, obj in pairs(workspace:GetChildren()) do
                if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) and obj.Name ~= "Terrain" then
                    obj:Destroy()
                end
            end
            notify("Workspace cleaned")
        end, miscTab, Color3.fromRGB(0, 255, 0))
        createButton("📱 Optimize", function()
            settings().Rendering.QualityLevel = 1
            notify("Optimized")
        end, miscTab, Color3.fromRGB(0, 255, 0))

        initChar()
        
        player.CharacterAdded:Connect(function()
            task.wait(5)
            initChar()
            if autoPlayOnRespawn and #macroActions > 0 then
                playMacro()
            end
        end)

        switchTab("Movement")
    end)
    if not success then
        warn("setupUI error: " .. tostring(errorMsg))
        notify("⚠️ UI setup failed, retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(5)
        setupUI()
    end
end
