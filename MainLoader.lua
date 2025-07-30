-- MainLoader_Fixed.lua - Optimized for Krnl Android, Fixed GUI
-- Dibuat oleh Fari Noveri - Full Android Touch Support + Combat Tab

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

-- UI Variables
local gui, frame, logo
local tabPages = {}
local currentTab = nil

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

-- Create main GUI
local function createGUI()
    local success, errorMsg = pcall(function()
        if gui then
            gui:Destroy()
            gui = nil
        end

        gui = Instance.new("ScreenGui")
        gui.Name = "SuperToolUI_Krnl"
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
        frame.Size = isMobile and UDim2.new(0.95, 0, 0.85, 0) or UDim2.new(0, 900, 0, 550)
        frame.Position = isMobile and UDim2.new(0.025, 0, 0.075, 0) or UDim2.new(0.5, -450, 0.5, -275)
        frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        frame.BorderSizePixel = 0
        frame.Visible = true
        frame.ZIndex = 50
        frame.Parent = gui
        
        local frameCorner = Instance.new("UICorner")
        frameCorner.CornerRadius = UDim.new(0, 12)
        frameCorner.Parent = frame

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

-- Tab system
local function createTabSystem()
    local success, errorMsg = pcall(function()
        local titleBar = Instance.new("Frame")
        titleBar.Size = UDim2.new(1, 0, 0, 40)
        titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        titleBar.BorderSizePixel = 0
        titleBar.ZIndex = 60
        titleBar.Parent = frame
        
        local titleCorner = Instance.new("UICorner")
        titleCorner.CornerRadius = UDim.new(0, 12)
        titleCorner.Parent = titleBar
        
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(0.7, 0, 1, 0)
        title.BackgroundTransparency = 1
        title.Text = "🚀 Super Tool Krnl"
        title.TextColor3 = Color3.new(1, 1, 1)
        title.TextScaled = true
        title.Font = Enum.Font.GothamBold
        title.ZIndex = 61
        title.Parent = titleBar
        
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 30, 0, 30)
        closeBtn.Position = UDim2.new(1, -35, 0, 5)
        closeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        closeBtn.Text = "✕"
        closeBtn.TextColor3 = Color3.new(1, 1, 1)
        closeBtn.TextScaled = true
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.BorderSizePixel = 0
        closeBtn.ZIndex = 61
        closeBtn.Parent = titleBar
        
        local closeBtnCorner = Instance.new("UICorner")
        closeBtnCorner.CornerRadius = UDim.new(0, 15)
        closeBtnCorner.Parent = closeBtn
        
        closeBtn.Activated:Connect(function()
            frame.Visible = false
            notify("🖼️ GUI Closed", Color3.fromRGB(255, 100, 100))
        end)

        local tabContainer = Instance.new("Frame")
        tabContainer.Size = UDim2.new(0, 150, 1, -40)
        tabContainer.Position = UDim2.new(0, 0, 0, 40)
        tabContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        tabContainer.BorderSizePixel = 0
        tabContainer.ZIndex = 60
        tabContainer.Parent = frame

        local tabLayout = Instance.new("UIListLayout")
        tabLayout.FillDirection = Enum.FillDirection.Vertical
        tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
        tabLayout.Padding = UDim.new(0, 5)
        tabLayout.Parent = tabContainer

        local contentArea = Instance.new("Frame")
        contentArea.Size = UDim2.new(1, -150, 1, -40)
        contentArea.Position = UDim2.new(0, 150, 0, 40)
        contentArea.BackgroundTransparency = 1
        contentArea.BorderSizePixel = 0
        contentArea.ZIndex = 60
        contentArea.Parent = frame

        warn("Tab system created")
        return tabContainer, contentArea
    end)
    if not success then
        warn("createTabSystem error: " .. errorMsg)
        notify("⚠️ Failed to create tab system: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
        return nil, nil
    end
end

-- Create tab
local function createTab(name, icon, tabContainer, contentArea)
    local success, errorMsg = pcall(function()
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 60)
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.Gotham
        btn.Text = icon .. " " .. name
        btn.TextScaled = true
        btn.BorderSizePixel = 0
        btn.ZIndex = 61
        btn.Parent = tabContainer
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.ScrollBarThickness = 8
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.Visible = false
        page.ZIndex = 61
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
                data.button.BackgroundColor3 = (tabName == name) and Color3.fromRGB(50, 150, 255) or Color3.fromRGB(60, 60, 60)
            end
            currentTab = name
            notify("📑 Switched to " .. name, Color3.fromRGB(0, 255, 0))
        end)

        if not currentTab then
            btn.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
            page.Visible = true
            currentTab = name
        end

        warn("Tab " .. name .. " created")
        return page
    end)
    if not success then
        warn("createTab error: " .. errorMsg)
        notify("⚠️ Failed to create tab " .. name .. ": " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
        return nil
    end
end

-- Create button
local function createButton(text, callback, parent, color)
    local success, errorMsg = pcall(function()
        color = color or Color3.fromRGB(60, 60, 60)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 60, 0, 60)
        btn.BackgroundColor3 = color
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.Font = Enum.Font.GothamSemibold
        btn.Text = text
        btn.TextScaled = true
        btn.BorderSizePixel = 0
        btn.ZIndex = 61
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

-- Create text input
local function createTextInput(placeholder, parent, callback)
    local success, errorMsg = pcall(function()
        local inputFrame = Instance.new("Frame")
        inputFrame.Size = UDim2.new(1, -20, 0, 60)
        inputFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        inputFrame.BorderSizePixel = 0
        inputFrame.ZIndex = 61
        inputFrame.Parent = parent
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = inputFrame
        
        local textBox = Instance.new("TextBox")
        textBox.Size = UDim2.new(1, -10, 1, -10)
        textBox.Position = UDim2.new(0, 5, 0, 5)
        textBox.BackgroundTransparency = 1
        textBox.TextColor3 = Color3.new(1, 1, 1)
        textBox.Font = Enum.Font.Gotham
        textBox.TextScaled = true
        textBox.PlaceholderText = placeholder
        textBox.Text = ""
        textBox.ZIndex = 62
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
        warn("createTextInput error: " .. errorMsg)
        notify("⚠️ Failed to create text input: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Flying system
local function setupFlying()
    local bodyVel, bodyGyro
    
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
            
            if improvedFlying then
                local moveDir = humanoid.MoveDirection
                if moveDir.Magnitude > 0 then
                    moveVector = forward * -moveDir.Z * flySpeed + right * moveDir.X * flySpeed
                end
            else
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

-- Auto heal
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

-- God mode
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

-- No fall damage
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

-- Anti ragdoll
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

-- Position save/load
local function setupPositions()
    local function savePosition(name)
        if not hr then return end
        savedPositions[name] = hr.CFrame
        notify("📍 Position '" .. name .. "' saved", Color3.fromRGB(0, 255, 0))
    end
    
    local function loadPosition(name)
        if not hr or not savedPositions[name] then return end
        hr.CFrame = savedPositions[name]
        notify("📍 Teleported to '" .. name .. "'", Color3.fromRGB(0, 255, 255))
    end
    
    return savePosition, loadPosition
end

-- Player interaction
local function setupPlayerSystem()
    local playerListFrame
    local currentSubMenu = nil
    
    local function createPlayerList(parent)
        playerListFrame = Instance.new("ScrollingFrame")
        playerListFrame.Size = UDim2.new(1, -20, 0, 300)
        playerListFrame.Position = UDim2.new(0, 10, 0, 50)
        playerListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        playerListFrame.ScrollBarThickness = 8
        playerListFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        playerListFrame.BorderSizePixel = 0
        playerListFrame.ZIndex = 61
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
        
        warn("Player list created")
        return playerListFrame
    end
    
    local function closeSubMenu()
        if currentSubMenu then
            currentSubMenu:Destroy()
            currentSubMenu = nil
        end
    end
    
    local function createSubMenu(parentButton, targetPlayer)
        closeSubMenu()
        
        local subMenu = Instance.new("Frame")
        subMenu.Size = UDim2.new(1, -10, 0, 120)
        subMenu.Position = UDim2.new(0, 5, 1, 5)
        subMenu.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        subMenu.BorderSizePixel = 0
        subMenu.ZIndex = 61
        subMenu.Parent = parentButton
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = subMenu
        
        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Padding = UDim.new(0, 4)
        layout.Parent = subMenu
        
        currentSubMenu = subMenu
        
        createButton("🔄 Teleport", function()
            if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") and hr then
                hr.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
                notify("Teleported to " .. targetPlayer.Name, Color3.fromRGB(0, 255, 255))
            end
            closeSubMenu()
        end, subMenu, Color3.fromRGB(0, 150, 255))
        
        createButton("🎯 Follow", function()
            followTarget = targetPlayer
            notify("Following " .. targetPlayer.Name, Color3.fromRGB(255, 165, 0))
            if connections.followLoop then connections.followLoop:Disconnect() end
            connections.followLoop = RunService.Heartbeat:Connect(function()
                if followTarget and followTarget.Character and followTarget.Character:FindFirstChild("HumanoidRootPart") and hr then
                    hr.CFrame = followTarget.Character.HumanoidRootPart.CFrame + Vector3.new(0, 5, 5)
                end
            end)
            closeSubMenu()
        end, subMenu, Color3.fromRGB(255, 165, 0))
        
        createButton("🚫 Stop Follow", function()
            followTarget = nil
            if connections.followLoop then connections.followLoop:Disconnect() end
            notify("Stopped following", Color3.fromRGB(255, 100, 100))
            closeSubMenu()
        end, subMenu, Color3.fromRGB(255, 100, 100))
        
        createButton("📸 Copy Avatar", function()
            if targetPlayer then
                local success, appearance = pcall(function()
                    return Players:GetCharacterAppearanceAsync(targetPlayer.UserId)
                end)
                if success and appearance then
                    for _, obj in pairs(char:GetChildren()) do
                        if obj:IsA("Accessory") or obj:IsA("CharacterMesh") then
                            obj:Destroy()
                        end
                    end
                    for _, obj in pairs(appearance:GetChildren()) do
                        if obj:IsA("Accessory") or obj:IsA("CharacterMesh") then
                            local clone = obj:Clone()
                            clone.Parent = char
                        end
                    end
                    notify("Copied avatar of " .. targetPlayer.Name, Color3.fromRGB(0, 255, 255))
                else
                    notify("⚠️ Failed to copy avatar", Color3.fromRGB(255, 100, 100))
                end
            end
            closeSubMenu()
        end, subMenu, Color3.fromRGB(0, 200, 200))
        
        createButton("❌ Cancel", closeSubMenu, subMenu, Color3.fromRGB(100, 100, 100))
    end
    
    local function refreshPlayerList()
        if not playerListFrame then return end
        for _, child in ipairs(playerListFrame:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("Frame") then child:Destroy() end
        end
        closeSubMenu()
        
        local players = Players:GetPlayers()
        if #players <= 1 then
            createButton("⚠️ No players", function() end, playerListFrame, Color3.fromRGB(255, 100, 100))
        else
            for _, p in ipairs(players) do
                if p ~= player then
                    createButton("🎮 " .. p.Name, function()
                        createSubMenu(playerListFrame, p)
                    end, playerListFrame)
                end
            end
        end
        warn("Player list refreshed")
    end
    
    return createPlayerList, refreshPlayerList
end

-- Combat system
local function setupCombat()
    local espGuis = {}
    local fovCircle = nil
    
    local function getTargetPart(character, partName)
        if partName == "Random" then
            local parts = {"Head", "Torso", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot"}
            partName = parts[math.random(1, #parts)]
        end
        return character:FindFirstChild(partName) or character:FindFirstChild("HumanoidRootPart")
    end
    
    local function getClosestPlayer()
        local closestPlayer = nil
        local closestDistance = useFOV and fovRadius or math.huge
        local mousePos = UserInputService:GetMouseLocation()
        
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                if ignoreTeam and p.Team == player.Team then continue end
                local targetPart = getTargetPart(p.Character, targetPart)
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
                    local targetPart = getTargetPart(target.Character, targetPart)
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
    
    local function toggleAimbullet()
        aimbulletEnabled = not aimbulletEnabled
        if aimbulletEnabled then
            notify("🔫 Aimbullet ON", Color3.fromRGB(255, 0, 0))
            connections.aimbulletLoop = RunService.Stepped:Connect(function()
                if not aimbulletEnabled or not hr or not camera then return end
                local target = getClosestPlayer()
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    local targetPart = getTargetPart(target.Character, targetPart)
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
            end)
        else
            notify("🔫 Aimbullet OFF", Color3.fromRGB(255, 100, 100))
            if connections.aimbulletLoop then connections.aimbulletLoop:Disconnect() end
        end
    end
    
    local function toggleESP()
        espEnabled = not espEnabled
        if espEnabled then
            notify("👁️ ESP ON", Color3.fromRGB(255, 0, 255))
            connections.espLoop = RunService.RenderStepped:Connect(function()
                for _, gui in pairs(espGuis) do gui:Destroy() end
                espGuis = {}
                
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        if ignoreTeam and p.Team == player.Team then continue end
                        local head = p.Character:FindFirstChild("Head")
                        if head then
                            local billboard = Instance.new("BillboardGui")
                            billboard.Size = UDim2.new(0, 50, 0, 50)
                            billboard.Adornee = head
                            billboard.AlwaysOnTop = true
                            billboard.Parent = head
                            
                            local skull = Instance.new("ImageLabel")
                            skull.Size = UDim2.new(1, 0, 1, 0)
                            skull.BackgroundTransparency = 1
                            skull.Image = "rbxassetid://2790389767"
                            skull.Parent = billboard
                            
                            table.insert(espGuis, billboard)
                        end
                    end
                end
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
            notify("🔲 FOV Circle ON", Color3.fromRGB(0, 255, 255))
            fovCircle = Instance.new("Frame")
            fovCircle.Size = UDim2.new(0, fovRadius * 2, 0, fovRadius * 2)
            fovCircle.Position = UDim2.new(0.5, -fovRadius, 0.5, -fovRadius)
            fovCircle.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
            fovCircle.BackgroundTransparency = 0.8
            fovCircle.BorderSizePixel = 0
            fovCircle.ZIndex = 61
            fovCircle.Parent = gui
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = fovCircle
        else
            notify("🔲 FOV Circle OFF", Color3.fromRGB(255, 100, 100))
            if fovCircle then fovCircle:Destroy() end
            fovCircle = nil
        end
    end
    
    local function setTargetPart(part)
        targetPart = part
        notify("🎯 Target Part: " .. part, Color3.fromRGB(255, 0, 0))
    end
    
    local function adjustAimbotSpeed(delta)
        aimbotSpeed = math.clamp(aimbotSpeed + delta, 0.1, 1)
        notify("🎯 Aimbot Speed: " .. aimbotSpeed, Color3.fromRGB(255, 0, 0))
    end
    
    local function adjustAimbulletSpeed(delta)
        aimbulletSpeed = math.clamp(aimbulletSpeed + delta, 50, 200)
        notify("🔫 Aimbullet Speed: " .. aimbulletSpeed, Color3.fromRGB(255, 0, 0))
    end
    
    local function adjustBulletSpeed(delta)
        bulletSpeed = math.clamp(bulletSpeed + delta, 50, 200)
        notify("💨 Bullet Speed: " .. bulletSpeed, Color3.fromRGB(255, 0, 0))
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
        notify("👥 Ignore Team: " .. (ignoreTeam and "ON" or "OFF"), Color3.fromRGB(0, 255, 0))
    end
    
    return toggleAimbot, toggleAimbullet, toggleESP, toggleFOV, setTargetPart, adjustAimbotSpeed, adjustAimbulletSpeed, adjustBulletSpeed, toggleIgnoreTeam
end

-- Nickname system
local function setupNickname()
    local function toggleHideNick()
        nickHidden = not nickHidden
        if nickHidden then
            player.DisplayName = ""
            notify("🕵️ Nickname Hidden", Color3.fromRGB(0, 255, 0))
        else
            player.DisplayName = player.Name
            notify("🕵️ Nickname Visible", Color3.fromRGB(255, 100, 100))
        end
    end
    
    local function setCustomNick(name)
        if name == "" then
            notify("⚠️ Nickname cannot be empty", Color3.fromRGB(255, 100, 100))
            return
        end
        customNick = name
        player.DisplayName = name
        randomNick = false
        notify("🕵️ Nickname Set: " .. name, Color3.fromRGB(0, 255, 0))
    end
    
    local function toggleRandomNick()
        randomNick = not randomNick
        if randomNick then
            local randomNames = {"Shadow", "Blaze", "Phantom", "Ghost", "Ninja", "Storm"}
            player.DisplayName = randomNames[math.random(1, #randomNames)] .. math.random(100, 999)
            notify("🕵️ Random Nickname: " .. player.DisplayName, Color3.fromRGB(0, 255, 0))
        else
            player.DisplayName = player.Name
            notify("🕵️ Nickname Restored", Color3.fromRGB(255, 100, 100))
        end
    end
    
    return toggleHideNick, setCustomNick, toggleRandomNick
end

-- Anti Spectate and Anti Report
local function setupAntiFeatures()
    local function toggleAntiSpectate()
        antiSpectate = not antiSpectate
        if antiSpectate then
            notify("🕵️ Anti Spectate ON", Color3.fromRGB(0, 255, 0))
            camera.CameraType = Enum.CameraType.Fixed
        else
            notify("🕵️ Anti Spectate OFF", Color3.fromRGB(255, 100, 100))
            camera.CameraType = Enum.CameraType.Custom
        end
    end
    
    local function toggleAntiReport()
        antiReport = not antiReport
        notify("🚫 Anti Report " .. (antiReport and "ON" or "OFF"), Color3.fromRGB(0, 255, antiReport and 0 or 100))
    end
    
    return toggleAntiSpectate, toggleAntiReport
end

-- Trajectory and Macro
local function setupTrajectoryAndMacro()
    local trajectoryEnabled = false
    local macroRecording = false
    local macroPlaying = false
    local macroActions = {}
    local trajectoryBeams = {}
    local maxDistance = 50
    local autoPlayOnRespawn = false
    local macroNoclip = false

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
        beam.Width0 = 0.2
        beam.Width1 = 0.2
        beam.LightEmission = 1
        beam.LightInfluence = 0
        beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        beam.TextureMode = Enum.TextureMode.Stretch
        beam.TextureSpeed = 0
        beam.Color = ColorSequence.new((endPos - startPos).Magnitude < 20 and Color3.fromRGB(0, 255, 0) or
                                       (endPos - startPos).Magnitude < 40 and Color3.fromRGB(255, 255, 0) or
                                       Color3.fromRGB(255, 0, 0))
        beam.Parent = workspace
        table.insert(trajectoryBeams, beam)
        table.insert(trajectoryBeams, attachment0)
        table.insert(trajectoryBeams, attachment1)

        local endPoint = Instance.new("Part")
        endPoint.Size = Vector3.new(0.5, 0.5, 0.5)
        endPoint.Position = endPos
        endPoint.Anchored = true
        endPoint.CanCollide = false
        endPoint.BrickColor = BrickColor.new("Bright yellow")
        endPoint.Material = Enum.Material.Neon
        endPoint.Parent = workspace
        table.insert(trajectoryBeams, endPoint)
    end

    local function toggleTrajectory()
        trajectoryEnabled = not trajectoryEnabled
        if trajectoryEnabled then
            notify("📏 Trajectory ON", Color3.fromRGB(255, 0, 0))
            connections.trajectoryLoop = RunService.RenderStepped:Connect(drawTrajectory)
        else
            notify("📏 Trajectory OFF", Color3.fromRGB(255, 100, 100))
            clearTrajectory()
            if connections.trajectoryLoop then connections.trajectoryLoop:Disconnect() end
        end
    end

    local function startRecordingMacro()
        macroRecording = true
        macroActions = {}
        notify("🎥 Recording Macro", Color3.fromRGB(0, 255, 0))
        connections.macroRecordLoop = RunService.Heartbeat:Connect(function()
            if not macroRecording or not humanoid or not hr then return end
            table.insert(macroActions, {
                position = hr.CFrame,
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
            notify("⚠️ No Macro Recorded", Color3.fromRGB(255, 100, 100))
            return
        end
        if not humanoid or not hr then
            notify("⚠️ Cannot play macro", Color3.fromRGB(255, 100, 100))
            return
        end

        if humanoid:GetState() != Enum.HumanoidStateType.Running then
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end

        if not noclip then
            local toggleNoclip = setupNoclip()
            toggleNoclip()
            macroNoclip = true
        end

        macroPlaying = true
        notify("▶️ Playing Macro", Color3.fromRGB(0, 255, 255))
        if macroActions[1] then
            hr.CFrame = macroActions[1].position
        end

        local bodyVel = Instance.new("BodyVelocity")
        bodyVel.MaxForce = Vector3.new(math.huge, 0, math.huge)
        bodyVel.Parent = hr

        local actionIndex = 1
        connections.macroPlayLoop = RunService.Heartbeat:Connect(function()
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
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
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
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
        notify("⏹️ Macro Stopped", Color3.fromRGB(255, 100, 100))
    end

    local function toggleAutoPlay()
        autoPlayOnRespawn = not autoPlayOnRespawn
        notify("🔄 AutoPlay on Respawn: " .. (autoPlayOnRespawn and "ON" or "OFF"), Color3.fromRGB(0, 255, autoPlayOnRespawn and 0 or 100))
    end

    player.CharacterAdded:Connect(function()
        task.wait(1)
        initChar()
        if autoPlayOnRespawn and #macroActions > 0 then
            playMacro()
        end
    end)

    return toggleTrajectory, startRecordingMacro, stopRecordingMacro, playMacro, stopPlayingMacro, toggleAutoPlay
end

-- Main setup
local function setupUI()
    local success, errorMsg = pcall(function()
        task.wait(0.5) -- Delay kecil untuk pastikan PlayerGui ready
        createGUI()
        makeDraggable(logo)
        
        logo.Activated:Connect(function()
            frame.Visible = not frame.Visible
            notify("🖼️ GUI Toggled " .. (frame.Visible and "ON" or "OFF"), Color3.fromRGB(frame.Visible and 0 or 255, frame.Visible and 255 or 100, frame.Visible and 0 or 100))
        end)
        
        local tabContainer, contentArea = createTabSystem()
        if not tabContainer or not contentArea then
            error("Failed to create tab system")
        end
        
        -- Movement Tab
        local movementTab = createTab("Movement", "🚀", tabContainer, contentArea)
        if movementTab then
            local startFly, stopFly, toggleImprovedFlying = setupFlying()
            local toggleNoclip = setupNoclip()
            
            createButton("🚁 Fly", function()
                if flying then stopFly() else startFly() end
            end, movementTab, Color3.fromRGB(0, 150, 255))
            
            createButton("🛩️ Improve Fly", toggleImprovedFlying, movementTab, Color3.fromRGB(0, 150, 255))
            
            createButton("👻 Noclip", toggleNoclip, movementTab, Color3.fromRGB(0, 150, 255))
            
            createButton("⚡ Speed +", function()
                flySpeed = flySpeed + 5
                notify("Fly Speed: " .. flySpeed, Color3.fromRGB(255, 255, 0))
            end, movementTab, Color3.fromRGB(255, 255, 0))
            
            createButton("⚡ Speed -", function()
                flySpeed = math.max(1, flySpeed - 5)
                notify("Fly Speed: " .. flySpeed, Color3.fromRGB(255, 255, 0))
            end, movementTab, Color3.fromRGB(255, 255, 0))
            
            createButton("🏃 Sprint", function()
                if humanoid then
                    humanoid.WalkSpeed = humanoid.WalkSpeed == 16 and 50 or 16
                    notify("Speed: " .. humanoid.WalkSpeed, Color3.fromRGB(255, 255, 0))
                end
            end, movementTab, Color3.fromRGB(255, 255, 0))
            
            createButton("🦘 Jump", function()
                if humanoid then
                    humanoid.JumpPower = humanoid.JumpPower == 50 and 120 or 50
                    notify("Jump Power: " .. humanoid.JumpPower, Color3.fromRGB(255, 255, 0))
                end
            end, movementTab, Color3.fromRGB(255, 255, 0))
            
            createButton("🌊 Water Walk", function()
                local walkOnWater = not workspace.Terrain.ReadVoxels
                for _, part in pairs(workspace:GetPartsByMaterial(Enum.Material.Water)) do
                    part.CanCollide = walkOnWater
                end
                notify("Walk on water: " .. (walkOnWater and "ON" or "OFF"), Color3.fromRGB(0, 150, 255))
            end, movementTab, Color3.fromRGB(0, 150, 255))
            
            createButton("🚀 Rocket", function()
                if hr then
                    local rocket = Instance.new("BodyVelocity")
                    rocket.MaxForce = Vector3.new(4000, 4000, 4000)
                    rocket.Velocity = Vector3.new(0, 100, 0)
                    rocket.Parent = hr
                    task.wait(0.5)
                    rocket:Destroy()
                    notify("🚀 ROCKET JUMP!", Color3.fromRGB(255, 100, 0))
                end
            end, movementTab, Color3.fromRGB(255, 100, 0))
            
            createButton("🌪️ Spin", function()
                if hr then
                    local spin = Instance.new("BodyAngularVelocity")
                    spin.MaxTorque = Vector3.new(0, 4000, 0)
                    spin.AngularVelocity = Vector3.new(0, 50, 0)
                    spin.Parent = hr
                    task.wait(2)
                    spin:Destroy()
                    notify("🌪️ Spin complete!", Color3.fromRGB(255, 255, 0))
                end
            end, movementTab, Color3.fromRGB(255, 255, 0))
        end
        
        -- Combat Tab
        local combatTab = createTab("Combat", "🎯", tabContainer, contentArea)
        if combatTab then
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
        end
        
        -- Player Tab
        local playerTab = createTab("Player", "🎮", tabContainer, contentArea)
        if playerTab then
            local createPlayerList, refreshPlayerList = setupPlayerSystem()
            
            createButton("🔄 Refresh", refreshPlayerList, playerTab, Color3.fromRGB(0, 150, 255))
            
            local playerListFrame = createPlayerList(playerTab)
            refreshPlayerList()
        end
        
        -- Utility Tab
        local utilityTab = createTab("Utility", "🛠️", tabContainer, contentArea)
        if utilityTab then
            local toggleAutoHeal = setupAutoHeal()
            local toggleGodMode = setupGodMode()
            local toggleNoFallDamage = setupNoFallDamage()
            local toggleAntiRagdoll = setupAntiRagdoll()
            local savePosition, loadPosition = setupPositions()
            local toggleTrajectory, startRecordingMacro, stopRecordingMacro, playMacro, stopPlayingMacro, toggleAutoPlay = setupTrajectoryAndMacro()

            createButton("💚 Heal", toggleAutoHeal, utilityTab, Color3.fromRGB(0, 255, 0))
            createButton("⚡ God", toggleGodMode, utilityTab, Color3.fromRGB(255, 215, 0))
            createButton("🛡️ No Fall", toggleNoFallDamage, utilityTab, Color3.fromRGB(0, 255, 0))
            createButton("🛡️ Anti Ragdoll", toggleAntiRagdoll, utilityTab, Color3.fromRGB(0, 255, 0))
            
            createButton("📍 Save 1", function() savePosition("pos1") end, utilityTab, Color3.fromRGB(0, 255, 0))
            createButton("📍 Load 1", function() loadPosition("pos1") end, utilityTab, Color3.fromRGB(0, 255, 255))
            createButton("📍 Save 2", function() savePosition("pos2") end, utilityTab, Color3.fromRGB(0, 255, 0))
            createButton("📍 Load 2", function() loadPosition("pos2") end, utilityTab, Color3.fromRGB(0, 255, 255))
            createButton("🏠 Spawn", function()
                if hr then
                    hr.CFrame = CFrame.new(0, 50, 0)
                    notify("Teleported to spawn", Color3.fromRGB(0, 255, 255))
                end
            end, utilityTab, Color3.fromRGB(0, 255, 255))
            
            createButton("📏 Trajectory", toggleTrajectory, utilityTab, Color3.fromRGB(255, 0, 0))
            createButton("🎥 Record", startRecordingMacro, utilityTab, Color3.fromRGB(0, 255, 0))
            createButton("⏹️ Stop Rec", stopRecordingMacro, utilityTab, Color3.fromRGB(255, 100, 100))
            createButton("▶️ Play", playMacro, utilityTab, Color3.fromRGB(0, 255, 255))
            createButton("🚫 Stop Macro", stopPlayingMacro, utilityTab, Color3.fromRGB(255, 100, 100))
            createButton("🔄 AutoPlay", toggleAutoPlay, utilityTab, Color3.fromRGB(0, 150, 255))
        end
        
        -- Settings Tab
        local settingsTab = createTab("Settings", "⚙️", tabContainer, contentArea)
        if settingsTab then
            local toggleHideNick, setCustomNick, toggleRandomNick = setupNickname()
            local toggleAntiSpectate, toggleAntiReport = setupAntiFeatures()
            
            createButton("🔄 Reset", function()
                if humanoid then
                    humanoid.Health = 0
                    notify("Character reset", Color3.fromRGB(255, 100, 100))
                end
            end, settingsTab, Color3.fromRGB(255, 100, 100))
            
            createButton("🧹 Clean", function()
                for _, obj in pairs(workspace:GetChildren()) do
                    if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) and obj.Name ~= "Terrain" then
                        obj:Destroy()
                    end
                end
                notify("Workspace cleaned", Color3.fromRGB(0, 255, 0))
            end, settingsTab, Color3.fromRGB(0, 255, 0))
            
            createButton("📱 Optimize", function()
                settings().Rendering.QualityLevel = 1
                notify("Optimized for mobile", Color3.fromRGB(0, 255, 0))
            end, settingsTab, Color3.fromRGB(0, 255, 0))
            
            createButton("🕵️ Hide Nick", toggleHideNick, settingsTab, Color3.fromRGB(0, 255, 0))
            createButton("🕵️ Random Nick", toggleRandomNick, settingsTab, Color3.fromRGB(0, 255, 0))
            
            createTextInput("Enter Custom Nick", settingsTab, setCustomNick)
            
            createButton("🕵️ Anti Spectate", toggleAntiSpectate, settingsTab, Color3.fromRGB(0, 255, 0))
            createButton("🚫 Anti Report", toggleAntiReport, settingsTab, Color3.fromRGB(0, 255, 0))
        end
        
        -- Initialize
        initChar()
        
        Players.PlayerAdded:Connect(function()
            task.wait(0.5)
            refreshPlayerList()
        end)
        Players.PlayerRemoving:Connect(function()
            task.wait(0.5)
            refreshPlayerList()
        end)
        
        notify("🚀 Super Tool Loaded", Color3.fromRGB(0, 255, 0))
    end)
    if not success then
        warn("setupUI error: " .. errorMsg)
        notify("⚠️ Failed to setup UI: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
        task.wait(1)
        setupUI()
    end
end

-- Cleanup
local function cleanup()
    for _, connection in pairs(connections) do
        if connection then connection:Disconnect() end
    end
    if gui then gui:Destroy() end
end

-- Initialize
local function init()
    local success, errorMsg = pcall(function()
        task.wait(0.5) -- Delay untuk pastikan Krnl inject
        setupUI()
        player.CharacterAdded:Connect(function()
            task.wait(1)
            initChar()
        end)
        if player.Character then
            initChar()
        end
        if gui and frame then
            gui.Enabled = true
            frame.Visible = true
            warn("GUI and Frame initialized, should be visible")
            notify("🖼️ Super Tool GUI Loaded", Color3.fromRGB(0, 255, 0))
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
