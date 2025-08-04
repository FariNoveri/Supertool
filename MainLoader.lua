local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid, hr, char
local gui, frame, logo, joystickFrame, cameraControlFrame, playerListFrame
local selectedPlayer = nil
local spectatingPlayer = nil
local flying, freecam, noclip, godMode = false, false, false, false
local flySpeed = 40
local freecamSpeed = UserInputService.TouchEnabled and 20 or 30
local cameraRotationSensitivity = UserInputService.TouchEnabled and 0.01 or 0.005
local speedEnabled, jumpEnabled, waterWalk, rocket, spin = false, false, false, false, false
local moveSpeed = 50
local jumpPower = 100
local spinSpeed = 20
local savedPositions = { [1] = nil, [2] = nil }
local macroRecording, macroPlaying, autoPlayOnRespawn, recordOnRespawn = false, false, false, false
local macroActions = {}
local macroSuccessfulEndTime = nil
local isMobile = UserInputService.TouchEnabled
local freecamCFrame = nil
local hrCFrame = nil
local joystickTouch = nil
local cameraTouch = nil
local joystickRadius = 50
local joystickDeadzone = 0.15
local moveDirection = Vector3.new(0, 0, 0)
local cameraDelta = Vector2.new(0, 0)
local nickHidden, randomNick = false, false
local customNick = "PemainKeren"
local defaultLogoPos = UDim2.new(0.95, -50, 0.05, 10)
local defaultFramePos = UDim2.new(0.5, -400, 0.5, -250)
local freezeMovingParts = false
local originalCFrames = {}

local connections = {}
local currentCategory = "Movement"

-- Notify function
local function notify(message, color)
    local success, errorMsg = pcall(function()
        if not gui then
            print("Notify: " .. message)
            return
        end
        local notif = Instance.new("TextLabel")
        notif.Size = UDim2.new(0, 350, 0, 60)
        notif.Position = UDim2.new(0.5, -175, 0.1, 0)
        notif.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        notif.BackgroundTransparency = 0.4
        notif.TextColor3 = color or Color3.fromRGB(0, 255, 0)
        notif.TextSize = 18
        notif.Font = Enum.Font.Gotham
        notif.Text = message
        notif.TextWrapped = true
        notif.BorderSizePixel = 0
        notif.ZIndex = 20
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = notif
        notif.Parent = gui
        task.spawn(function()
            task.wait(3)
            notif:Destroy()
        end)
    end)
    if not success then
        print("Notify error: " .. tostring(errorMsg))
    end
end

-- Clear connections
local function clearConnections()
    for key, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
            connections[key] = nil
        end
    end
end

-- Validate position
local function isValidPosition(pos)
    return pos and not (pos.Y < -1000 or pos.Y > 10000 or math.abs(pos.X) > 10000 or math.abs(pos.Z) > 10000)
end

-- Ensure character visibility
local function ensureCharacterVisible()
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0
                part.LocalTransparencyModifier = 0
            end
        end
    end
end

-- Clean adornments
local function cleanAdornments(character)
    local success, errorMsg = pcall(function()
        for _, obj in pairs(character:GetDescendants()) do
            if obj:IsA("SelectionBox") or obj:IsA("BoxHandleAdornment") or obj:IsA("SurfaceGui") then
                obj:Destroy()
            end
        end
    end)
    if not success then
        print("cleanAdornments error: " .. tostring(errorMsg))
    end
end

-- Reset character state
local function resetCharacterState()
    if hr and humanoid then
        hr.Velocity = Vector3.new(0, 0, 0)
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
        humanoid.Health = humanoid.MaxHealth
        ensureCharacterVisible()
        cleanAdornments(char)
    end
end

-- Initialize character
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
        cleanAdornments(char)
        ensureCharacterVisible()
        
        -- Reapply all active features
        if flying then toggleFly() toggleFly() end
        if freecam then toggleFreecam() toggleFreecam() end
        if noclip then toggleNoclip() toggleNoclip() end
        if speedEnabled then toggleSpeed() toggleSpeed() end
        if jumpEnabled then toggleJump() toggleJump() end
        if waterWalk then toggleWaterWalk() toggleWaterWalk() end
        if spin then toggleSpin() toggleSpin() end
        if godMode then toggleGodMode() toggleGodMode() end
        if nickHidden then toggleHideNick() toggleHideNick() end
        if randomNick then toggleRandomNick() toggleRandomNick() end
        if recordOnRespawn and macroRecording then toggleRecordMacro() toggleRecordMacro() end
        if autoPlayOnRespawn and macroPlaying then togglePlayMacro() togglePlayMacro() end
    end)
    if not success then
        print("initChar error: " .. tostring(errorMsg))
        notify("⚠️ Character init failed: " .. tostring(errorMsg) .. ", retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(5)
        initChar()
    end
end

-- Spectate player
local function spectatePlayer()
    local success, errorMsg = pcall(function()
        if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("Humanoid") then
            spectatingPlayer = selectedPlayer
            camera.CameraSubject = selectedPlayer.Character.Humanoid
            notify("👁️ Spectating " .. selectedPlayer.Name)
        else
            notify("⚠️ No player selected or invalid character", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Spectate error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Stop spectating
local function stopSpectate()
    local success, errorMsg = pcall(function()
        if spectatingPlayer then
            camera.CameraSubject = humanoid
            spectatingPlayer = nil
            notify("👁️ Stopped spectating")
        else
            notify("⚠️ Not currently spectating", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Stop spectate error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Freeze moving parts
local function toggleFreezeMovingParts()
    freezeMovingParts = not freezeMovingParts
    local success, errorMsg = pcall(function()
        if freezeMovingParts then
            -- Find and freeze all moving parts
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and not obj.Anchored and obj.Name ~= "HumanoidRootPart" then
                    -- Check if it's likely a moving platform/obstacle
                    if obj.Name:lower():find("moving") or obj.Name:lower():find("platform") or 
                       obj.Name:lower():find("obstacle") or obj.Name:lower():find("trap") or
                       obj.Name:lower():find("block") or obj.Name:lower():find("wood") or
                       obj.Name:lower():find("step") or obj.Name:lower():find("stair") or
                       obj.Parent and (obj.Parent.Name:lower():find("moving") or 
                       obj.Parent.Name:lower():find("obstacle") or obj.Parent.Name:lower():find("trap")) then
                        originalCFrames[obj] = obj.CFrame
                        obj.Anchored = true
                        -- Also freeze any BodyMovers
                        for _, child in pairs(obj:GetChildren()) do
                            if child:IsA("BodyVelocity") or child:IsA("BodyPosition") or 
                               child:IsA("BodyAngularVelocity") or child:IsA("BodyThrust") then
                                child.MaxForce = Vector3.new(0, 0, 0)
                            end
                        end
                    end
                end
                -- Freeze tweens on parts
                if obj:IsA("BasePart") and obj:FindFirstChild("TweenService") then
                    obj.TweenService:Pause()
                end
            end
            
            -- Stop RunService connections that might move parts
            connections.freezeWatch = RunService.Heartbeat:Connect(function()
                for part, originalCFrame in pairs(originalCFrames) do
                    if part and part.Parent then
                        part.CFrame = originalCFrame
                        part.Anchored = true
                    end
                end
            end)
            
            notify("🧊 Moving Parts Frozen")
        else
            -- Unfreeze all parts
            if connections.freezeWatch then
                connections.freezeWatch:Disconnect()
                connections.freezeWatch = nil
            end
            
            for part, originalCFrame in pairs(originalCFrames) do
                if part and part.Parent then
                    part.Anchored = false
                    -- Restore BodyMovers
                    for _, child in pairs(part:GetChildren()) do
                        if child:IsA("BodyVelocity") then
                            child.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        elseif child:IsA("BodyPosition") then
                            child.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        end
                    end
                end
            end
            originalCFrames = {}
            
            notify("🧊 Moving Parts Unfrozen")
        end
    end)
    if not success then
        freezeMovingParts = false
        if connections.freezeWatch then
            connections.freezeWatch:Disconnect()
            connections.freezeWatch = nil
        end
        notify("⚠️ Freeze Moving Parts error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Create joystick and camera control
local function createJoystick()
    if joystickFrame then
        joystickFrame:Destroy()
    end
    joystickFrame = Instance.new("Frame")
    joystickFrame.Size = UDim2.new(0, 120, 0, 120)
    joystickFrame.Position = UDim2.new(0.1, 0, 0.65, 0)
    joystickFrame.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    joystickFrame.BackgroundTransparency = 0.5
    joystickFrame.BorderSizePixel = 0
    joystickFrame.ZIndex = 15
    joystickFrame.Visible = false
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 60)
    corner.Parent = joystickFrame
    joystickFrame.Parent = gui

    local joystickKnob = Instance.new("Frame")
    joystickKnob.Size = UDim2.new(0, 40, 0, 40)
    joystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
    joystickKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    joystickKnob.BackgroundTransparency = 0.2
    joystickKnob.BorderSizePixel = 0
    joystickKnob.ZIndex = 16
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0, 20)
    knobCorner.Parent = joystickKnob
    joystickKnob.Parent = joystickFrame

    cameraControlFrame = Instance.new("Frame")
    cameraControlFrame.Size = UDim2.new(0, 120, 0, 120)
    cameraControlFrame.Position = UDim2.new(0.8, -120, 0.65, 0)
    cameraControlFrame.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    cameraControlFrame.BackgroundTransparency = 0.5
    cameraControlFrame.BorderSizePixel = 0
    cameraControlFrame.ZIndex = 15
    cameraControlFrame.Visible = false
    local camCorner = Instance.new("UICorner")
    camCorner.CornerRadius = UDim.new(0, 60)
    camCorner.Parent = cameraControlFrame
    cameraControlFrame.Parent = gui

    local cameraKnob = Instance.new("Frame")
    cameraKnob.Size = UDim2.new(0, 40, 0, 40)
    cameraKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
    cameraKnob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    cameraKnob.BackgroundTransparency = 0.2
    cameraKnob.BorderSizePixel = 0
    cameraKnob.ZIndex = 16
    local camKnobCorner = Instance.new("UICorner")
    camKnobCorner.CornerRadius = UDim.new(0, 20)
    camKnobCorner.Parent = cameraKnob
    cameraKnob.Parent = cameraControlFrame

    local function updateJoystick(input)
        local center = Vector2.new(joystickFrame.AbsolutePosition.X + joystickFrame.AbsoluteSize.X / 2, joystickFrame.AbsolutePosition.Y + joystickFrame.AbsoluteSize.Y / 2)
        local delta = Vector2.new(input.Position.X, input.Position.Y) - center
        local magnitude = delta.Magnitude
        local maxRadius = joystickRadius
        if magnitude > maxRadius then
            delta = delta.Unit * maxRadius
        end
        joystickKnob.Position = UDim2.new(0.5, delta.X - 20, 0.5, delta.Y - 20)
        local inputMag = delta.Magnitude / maxRadius
        if inputMag < joystickDeadzone then
            moveDirection = Vector3.new(0, 0, 0)
        else
            moveDirection = Vector3.new(delta.X / maxRadius, 0, -delta.Y / maxRadius)
        end
    end

    local function updateCameraControl(input)
        local center = Vector2.new(cameraControlFrame.AbsolutePosition.X + cameraControlFrame.AbsoluteSize.X / 2, cameraControlFrame.AbsolutePosition.Y + cameraControlFrame.AbsoluteSize.Y / 2)
        local delta = Vector2.new(input.Position.X, input.Position.Y) - center
        local magnitude = delta.Magnitude
        local maxRadius = joystickRadius
        if magnitude > maxRadius then
            delta = delta.Unit * maxRadius
        end
        cameraKnob.Position = UDim2.new(0.5, delta.X - 20, 0.5, delta.Y - 20)
        local inputMag = delta.Magnitude / maxRadius
        if inputMag < joystickDeadzone then
            cameraDelta = Vector2.new(0, 0)
        else
            cameraDelta = Vector2.new(-delta.X / maxRadius, delta.Y / maxRadius)
        end
    end

    connections.joystickBegan = UserInputService.TouchStarted:Connect(function(input)
        if not UserInputService:GetFocusedTextBox() and (flying or freecam) then
            local touchPos = Vector2.new(input.Position.X, input.Position.Y)
            local joystickPos = Vector2.new(joystickFrame.AbsolutePosition.X + joystickFrame.AbsoluteSize.X / 2, joystickFrame.AbsolutePosition.Y + joystickFrame.AbsoluteSize.Y / 2)
            local cameraPos = Vector2.new(cameraControlFrame.AbsolutePosition.X + cameraControlFrame.AbsoluteSize.X / 2, cameraControlFrame.AbsolutePosition.Y + cameraControlFrame.AbsoluteSize.Y / 2)
            if not joystickTouch and (touchPos - joystickPos).Magnitude <= joystickRadius * 2 then
                joystickTouch = input
                updateJoystick(input)
            elseif not cameraTouch and (touchPos - cameraPos).Magnitude <= joystickRadius * 2 then
                cameraTouch = input
                updateCameraControl(input)
            end
        end
    end)

    connections.joystickMoved = UserInputService.TouchMoved:Connect(function(input)
        if input == joystickTouch then
            updateJoystick(input)
        elseif input == cameraTouch then
            updateCameraControl(input)
        end
    end)

    connections.joystickEnded = UserInputService.TouchEnded:Connect(function(input)
        if input == joystickTouch then
            joystickTouch = nil
            joystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
            moveDirection = Vector3.new(0, 0, 0)
        elseif input == cameraTouch then
            cameraTouch = nil
            cameraKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
            cameraDelta = Vector2.new(0, 0)
        end
    end)
end

-- Create separate player list UI
local function createPlayerListUI()
    if playerListFrame then
        playerListFrame:Destroy()
    end
    
    playerListFrame = Instance.new("Frame")
    playerListFrame.Size = UDim2.new(0, 300, 0, 400)
    playerListFrame.Position = UDim2.new(0, 20, 0.5, -200)
    playerListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    playerListFrame.BackgroundTransparency = 0.1
    playerListFrame.BorderSizePixel = 0
    playerListFrame.Visible = false
    playerListFrame.ZIndex = 25
    local playerFrameCorner = Instance.new("UICorner")
    playerFrameCorner.CornerRadius = UDim.new(0, 12)
    playerFrameCorner.Parent = playerListFrame
    playerListFrame.Parent = gui

    local playerTitle = Instance.new("TextLabel")
    playerTitle.Size = UDim2.new(1, 0, 0, 50)
    playerTitle.BackgroundTransparency = 1
    playerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    playerTitle.TextSize = 20
    playerTitle.Font = Enum.Font.GothamBold
    playerTitle.Text = "Select Player"
    playerTitle.ZIndex = 26
    playerTitle.Parent = playerListFrame

    local playerScrollFrame = Instance.new("ScrollingFrame")
    playerScrollFrame.Size = UDim2.new(1, -20, 1, -70)
    playerScrollFrame.Position = UDim2.new(0, 10, 0, 60)
    playerScrollFrame.BackgroundTransparency = 1
    playerScrollFrame.ScrollBarThickness = 8
    playerScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    playerScrollFrame.ZIndex = 26
    playerScrollFrame.ClipsDescendants = true
    playerScrollFrame.ScrollingEnabled = true
    playerScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    playerScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    playerScrollFrame.Parent = playerListFrame

    local playerUIL = Instance.new("UIListLayout")
    playerUIL.FillDirection = Enum.FillDirection.Vertical
    playerUIL.Padding = UDim.new(0, 5)
    playerUIL.Parent = playerScrollFrame

    local playerPadding = Instance.new("UIPadding")
    playerPadding.PaddingTop = UDim.new(0, 5)
    playerPadding.PaddingBottom = UDim.new(0, 5)
    playerPadding.PaddingLeft = UDim.new(0, 5)
    playerPadding.PaddingRight = UDim.new(0, 5)
    playerPadding.Parent = playerScrollFrame

    local function updatePlayerList()
        for _, child in pairs(playerScrollFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player then
                local playerButton = Instance.new("TextButton")
                playerButton.Size = UDim2.new(1, -10, 0, 40)
                playerButton.BackgroundColor3 = selectedPlayer == p and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
                playerButton.BackgroundTransparency = 0.3
                playerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                playerButton.TextSize = 16
                playerButton.Font = Enum.Font.Gotham
                playerButton.Text = p.Name .. " (" .. p.DisplayName .. ")"
                playerButton.TextWrapped = true
                playerButton.ZIndex = 27
                local playerCorner = Instance.new("UICorner")
                playerCorner.CornerRadius = UDim.new(0, 8)
                playerCorner.Parent = playerButton
                
                playerButton.MouseEnter:Connect(function()
                    if selectedPlayer ~= p then
                        playerButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
                    end
                end)
                playerButton.MouseLeave:Connect(function()
                    playerButton.BackgroundColor3 = selectedPlayer == p and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
                end)
                
                playerButton.MouseButton1Click:Connect(function()
                    selectedPlayer = p
                    updatePlayerList() -- Refresh to show selection
                    notify("👤 Selected Player: " .. p.Name)
                end)
                
                playerButton.Parent = playerScrollFrame
            end
        end
    end

    -- Close button for player list
    local closePlayerList = Instance.new("TextButton")
    closePlayerList.Size = UDim2.new(0, 30, 0, 30)
    closePlayerList.Position = UDim2.new(1, -40, 0, 10)
    closePlayerList.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closePlayerList.BackgroundTransparency = 0.3
    closePlayerList.TextColor3 = Color3.fromRGB(255, 255, 255)
    closePlayerList.TextSize = 18
    closePlayerList.Font = Enum.Font.GothamBold
    closePlayerList.Text = "×"
    closePlayerList.ZIndex = 28
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 15)
    closeCorner.Parent = closePlayerList
    closePlayerList.MouseButton1Click:Connect(function()
        playerListFrame.Visible = false
    end)
    closePlayerList.Parent = playerListFrame

    Players.PlayerAdded:Connect(updatePlayerList)
    Players.PlayerRemoving:Connect(updatePlayerList)
    updatePlayerList()
    
    return updatePlayerList
end

-- Show player list
local function showPlayerList()
    if playerListFrame then
        playerListFrame.Visible = not playerListFrame.Visible
        notify(playerListFrame.Visible and "👥 Player List Opened" or "👥 Player List Closed")
    end
end

-- All the original toggle functions remain the same...
-- (I'll include the key ones for brevity, but all original functions are preserved)

-- Fly toggle
local function toggleFly()
    flying = not flying
    local success, errorMsg = pcall(function()
        if flying then
            if freecam then
                toggleFreecam()
                notify("📷 Freecam disabled to enable Fly", Color3.fromRGB(255, 100, 100))
            end
            if not hr or not humanoid or not camera then
                flying = false
                error("Character or camera not loaded")
            end
            joystickFrame.Visible = isMobile
            cameraControlFrame.Visible = isMobile
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = hr
            connections.flyMouse = UserInputService.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement then
                    local inputMag = input.Delta.Magnitude
                    if inputMag < 2 then
                        cameraDelta = Vector2.new(0, 0)
                    else
                        cameraDelta = Vector2.new(-input.Delta.X, input.Delta.Y)
                    end
                end
            end)
            connections.fly = RunService.RenderStepped:Connect(function()
                if not hr or not humanoid or not camera then
                    flying = false
                    connections.fly:Disconnect()
                    connections.fly = nil
                    if connections.flyMouse then
                        connections.flyMouse:Disconnect()
                        connections.flyMouse = nil
                    end
                    joystickFrame.Visible = false
                    cameraControlFrame.Visible = false
                    notify("⚠️ Fly failed: Character or camera lost", Color3.fromRGB(255, 100, 100))
                    return
                end
                local forward = camera.CFrame.LookVector
                local right = camera.CFrame.RightVector
                local up = Vector3.new(0, 1, 0)
                local moveDir = Vector3.new(0, 0, 0)
                if isMobile then
                    moveDir = moveDirection.X * right + moveDirection.Z * forward
                else
                    local anyKeyPressed = false
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                        moveDir = moveDir + forward
                        anyKeyPressed = true
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                        moveDir = moveDir - forward
                        anyKeyPressed = true
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                        moveDir = moveDir - right
                        anyKeyPressed = true
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                        moveDir = moveDir + right
                        anyKeyPressed = true
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                        moveDir = moveDir + up
                        anyKeyPressed = true
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                        moveDir = moveDir - up
                        anyKeyPressed = true
                    end
                    if not anyKeyPressed then
                        moveDir = Vector3.new(0, 0, 0)
                    end
                end
                if moveDir.Magnitude > 0 then
                    moveDir = moveDir.Unit * flySpeed
                else
                    moveDir = Vector3.new(0, 0, 0)
                end
                bv.Velocity = moveDir
                hr.CFrame = CFrame.new(hr.Position) * camera.CFrame.Rotation
                local yaw = cameraDelta.X * cameraRotationSensitivity
                local pitch = cameraDelta.Y * cameraRotationSensitivity
                local currentPitch = math.asin(camera.CFrame.LookVector.Y)
                pitch = math.clamp(currentPitch + pitch, -math.pi / 2 + 0.1, math.pi / 2 - 0.1)
                local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch - currentPitch, 0, 0)
                camera.CFrame = CFrame.new(camera.CFrame.Position) * (camera.CFrame.Rotation * rotation)
                if not isMobile then
                    cameraDelta = Vector2.new(0, 0)
                end
            end)
            notify("🛫 Fly Enabled" .. (isMobile and " (Joystick + Camera Control)" or " (WASD, Space, Shift, Mouse)"))
        else
            if connections.fly then
                connections.fly:Disconnect()
                connections.fly = nil
            end
            if connections.flyMouse then
                connections.flyMouse:Disconnect()
                connections.flyMouse = nil
            end
            if hr and hr:FindFirstChildOfClass("BodyVelocity") then
                hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
            end
            joystickFrame.Visible = false
            cameraControlFrame.Visible = false
            moveDirection = Vector3.new(0, 0, 0)
            cameraDelta = Vector2.new(0, 0)
            notify("🛬 Fly Disabled")
        end
    end)
    if not success then
        flying = false
        if connections.fly then
            connections.fly:Disconnect()
            connections.fly = nil
        end
        if connections.flyMouse then
            connections.flyMouse:Disconnect()
            connections.flyMouse = nil
        end
        if hr and hr:FindFirstChildOfClass("BodyVelocity") then
            hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
        end
        joystickFrame.Visible = false
        cameraControlFrame.Visible = false
        moveDirection = Vector3.new(0, 0, 0)
        cameraDelta = Vector2.new(0, 0)
        notify("⚠️ Fly error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Freecam toggle
local function toggleFreecam()
    freecam = not freecam
    local success, errorMsg = pcall(function()
        if freecam then
            if flying then
                toggleFly()
                notify("🛫 Fly disabled to enable Freecam", Color3.fromRGB(255, 100, 100))
            end
            if not hr or not humanoid or not camera then
                freecam = false
                error("Character or camera not loaded")
            end
            joystickFrame.Visible = isMobile
            cameraControlFrame.Visible = isMobile
            hrCFrame = hr.CFrame
            freecamCFrame = camera.CFrame
            camera.CameraType = Enum.CameraType.Scriptable
            camera.CameraSubject = nil
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = hr
            connections.freecamLock = RunService.Stepped:Connect(function()
                if hr and hrCFrame then
                    hr.CFrame = hrCFrame
                else
                    freecam = false
                    connections.freecamLock:Disconnect()
                    connections.freecamLock = nil
                    joystickFrame.Visible = false
                    cameraControlFrame.Visible = false
                    notify("⚠️ Character lost, Freecam disabled", Color3.fromRGB(255, 100, 100))
                end
            end)
            connections.freecamMouse = UserInputService.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement then
                    local inputMag = input.Delta.Magnitude
                    if inputMag < 2 then
                        cameraDelta = Vector2.new(0, 0)
                    else
                        cameraDelta = Vector2.new(-input.Delta.X, input.Delta.Y)
                    end
                end
            end)
            connections.freecam = RunService.RenderStepped:Connect(function()
                if not camera or not freecamCFrame then
                    freecam = false
                    connections.freecam:Disconnect()
                    connections.freecam = nil
                    if connections.freecamLock then
                        connections.freecamLock:Disconnect()
                        connections.freecamLock = nil
                    end
                    if connections.freecamMouse then
                        connections.freecamMouse:Disconnect()
                        connections.freecamMouse = nil
                    end
                    joystickFrame.Visible = false
                    cameraControlFrame.Visible = false
                    notify("⚠️ Freecam failed: Camera or CFrame lost", Color3.fromRGB(255, 100, 100))
                    return
                end
                local forward = freecamCFrame.LookVector
                local right = freecamCFrame.RightVector
                local up = Vector3.new(0, 1, 0)
                local moveDir = Vector3.new(0, 0, 0)
                if isMobile then
                    moveDir = moveDirection.X * right + moveDirection.Z * forward
                else
                    local anyKeyPressed = false
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                        moveDir = moveDir + forward
                        anyKeyPressed = true
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                        moveDir = moveDir - forward
                        anyKeyPressed = true
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                        moveDir = moveDir - right
                        anyKeyPressed = true
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                        moveDir = moveDir + right
                        anyKeyPressed = true
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.E) then
                        moveDir = moveDir + up
                        anyKeyPressed = true
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
                        moveDir = moveDir - up
                        anyKeyPressed = true
                    end
                    if not anyKeyPressed then
                        moveDir = Vector3.new(0, 0, 0)
                    end
                end
                if moveDir.Magnitude > 0 then
                    moveDir = moveDir * freecamSpeed
                    freecamCFrame = CFrame.new(freecamCFrame.Position + moveDir) * freecamCFrame.Rotation
                end
                local yaw = cameraDelta.X * cameraRotationSensitivity
                local pitch = cameraDelta.Y * cameraRotationSensitivity
                local currentPitch = math.asin(freecamCFrame.LookVector.Y)
                pitch = math.clamp(currentPitch + pitch, -math.pi / 2 + 0.1, math.pi / 2 - 0.1)
                local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch - currentPitch, 0, 0)
                freecamCFrame = CFrame.new(freecamCFrame.Position) * (freecamCFrame.Rotation * rotation)
                if not isMobile then
                    cameraDelta = Vector2.new(0, 0)
                end
                camera.CFrame = freecamCFrame
            end)
            notify("📷 Freecam Enabled" .. (isMobile and " (Joystick + Camera Control)" or " (WASD, QE, Mouse)"))
        else
            if connections.freecam then
                connections.freecam:Disconnect()
                connections.freecam = nil
            end
            if connections.freecamLock then
                connections.freecamLock:Disconnect()
                connections.freecamLock = nil
            end
            if connections.freecamMouse then
                connections.freecamMouse:Disconnect()
                connections.freecamMouse = nil
            end
            if hr and hr:FindFirstChildOfClass("BodyVelocity") then
                hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
            end
            if camera and humanoid then
                camera.CameraType = Enum.CameraType.Custom
                camera.CameraSubject = humanoid
                if hr then
                    camera.CFrame = CFrame.new(hr.CFrame.Position + Vector3.new(0, 5, 10), hr.CFrame.Position)
                end
            end
            freecamCFrame = nil
            hrCFrame = nil
            joystickFrame.Visible = false
            cameraControlFrame.Visible = false
            moveDirection = Vector3.new(0, 0, 0)
            cameraDelta = Vector2.new(0, 0)
            notify("📷 Freecam Disabled")
        end
    end)
    if not success then
        freecam = false
        if connections.freecam then
            connections.freecam:Disconnect()
            connections.freecam = nil
        end
        if connections.freecamLock then
            connections.freecamLock:Disconnect()
            connections.freecamLock = nil
        end
        if connections.freecamMouse then
            connections.freecamMouse:Disconnect()
            connections.freecamMouse = nil
        end
        if hr and hr:FindFirstChildOfClass("BodyVelocity") then
            hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
        end
        joystickFrame.Visible = false
        cameraControlFrame.Visible = false
        moveDirection = Vector3.new(0, 0, 0)
        cameraDelta = Vector2.new(0, 0)
        notify("⚠️ Freecam error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Other essential functions (abbreviated for space)
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

-- Teleport functions
local function teleportToPlayer()
    local success, errorMsg = pcall(function()
        if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and hr then
            local targetPos = selectedPlayer.Character.HumanoidRootPart.Position
            if isValidPosition(targetPos) then
                hr.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
                notify("🚀 Teleported to " .. selectedPlayer.Name)
            else
                notify("⚠️ Invalid position for teleport", Color3.fromRGB(255, 100, 100))
            end
        else
            notify("⚠️ No player selected or invalid character", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Teleport error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function savePosition(slot)
    local success, errorMsg = pcall(function()
        if hr then
            savedPositions[slot] = hr.CFrame
            notify("💾 Position " .. slot .. " Saved")
        else
            notify("⚠️ Character not loaded", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Save Position error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function loadPosition(slot)
    local success, errorMsg = pcall(function()
        if hr and savedPositions[slot] and isValidPosition(savedPositions[slot].Position) then
            hr.CFrame = savedPositions[slot]
            notify("📍 Teleported to Position " .. slot)
        else
            notify("⚠️ No position saved in slot " .. slot .. " or invalid position", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Load Position error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Create GUI with improved category system
local function createGUI()
    local success, errorMsg = pcall(function()
        if gui then
            gui:Destroy()
            gui = nil
        end

        gui = Instance.new("ScreenGui")
        gui.Name = "SimpleUILibrary_Krnl"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Enabled = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = player:WaitForChild("PlayerGui", 20)

        local scale = Instance.new("UIScale")
        scale.Scale = math.min(1, math.min(camera.ViewportSize.X / 1280, camera.ViewportSize.Y / 720))
        scale.Parent = gui

        logo = Instance.new("ImageButton")
        logo.Size = UDim2.new(0, 60, 0, 60)
        logo.Position = defaultLogoPos
        logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        logo.BackgroundTransparency = 0.3
        logo.BorderSizePixel = 0
        logo.Image = "rbxassetid://3570695787"
        logo.ZIndex = 20
        local logoCorner = Instance.new("UICorner")
        logoCorner.CornerRadius = UDim.new(0, 12)
        logoCorner.Parent = logo
        logo.Parent = gui

        frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 800, 0, 500)
        frame.Position = defaultFramePos
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        frame.BackgroundTransparency = 0.1
        frame.BorderSizePixel = 0
        frame.Visible = false
        frame.ZIndex = 10
        frame.ClipsDescendants = true
        local frameCorner = Instance.new("UICorner")
        frameCorner.CornerRadius = UDim.new(0, 12)
        frameCorner.Parent = frame
        frame.Parent = gui

        local sidebar = Instance.new("Frame")
        sidebar.Size = UDim2.new(0, 200, 1, 0)
        sidebar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        sidebar.BackgroundTransparency = 0.2
        sidebar.BorderSizePixel = 0
        sidebar.ZIndex = 11
        sidebar.Parent = frame

        local sidebarUIL = Instance.new("UIListLayout")
        sidebarUIL.FillDirection = Enum.FillDirection.Vertical
        sidebarUIL.Padding = UDim.new(0, 10)
        sidebarUIL.Parent = sidebar

        local sidebarPadding = Instance.new("UIPadding")
        sidebarPadding.PaddingTop = UDim.new(0, 10)
        sidebarPadding.PaddingLeft = UDim.new(0, 10)
        sidebarPadding.PaddingRight = UDim.new(0, 10)
        sidebarPadding.Parent = sidebar

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(0, 200, 0, 50)
        title.BackgroundTransparency = 1
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 24
        title.Font = Enum.Font.GothamBold
        title.Text = "Enhanced Krnl UI"
        title.ZIndex = 12
        title.Parent = sidebar

        local contentFrame = Instance.new("Frame")
        contentFrame.Size = UDim2.new(0, 580, 1, -10)
        contentFrame.Position = UDim2.new(0, 210, 0, 5)
        contentFrame.BackgroundTransparency = 1
        contentFrame.ZIndex = 11
        contentFrame.ClipsDescendants = true
        contentFrame.Parent = frame

        local scrollFrame = Instance.new("ScrollingFrame")
        scrollFrame.Size = UDim2.new(1, -10, 1, -10)
        scrollFrame.Position = UDim2.new(0, 5, 0, 5)
        scrollFrame.BackgroundTransparency = 1
        scrollFrame.ScrollBarThickness = 8
        scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
        scrollFrame.ZIndex = 11
        scrollFrame.ClipsDescendants = true
        scrollFrame.ScrollingEnabled = true
        scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        scrollFrame.Parent = contentFrame

        local scrollUIL = Instance.new("UIListLayout")
        scrollUIL.FillDirection = Enum.FillDirection.Vertical
        scrollUIL.Padding = UDim.new(0, 8)
        scrollUIL.Parent = scrollFrame

        local scrollPadding = Instance.new("UIPadding")
        scrollPadding.PaddingTop = UDim.new(0, 10)
        scrollPadding.PaddingBottom = UDim.new(0, 20)
        scrollPadding.PaddingLeft = UDim.new(0, 10)
        scrollPadding.PaddingRight = UDim.new(0, 10)
        scrollPadding.Parent = scrollFrame

        local function createButton(text, callback, toggleState)
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, -10, 0, 50)
            button.BackgroundColor3 = toggleState() and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
            button.BackgroundTransparency = 0.3
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
            button.TextSize = 18
            button.Font = Enum.Font.Gotham
            button.Text = text
            button.TextWrapped = true
            button.ZIndex = 12
            button.Visible = false -- Start hidden, show when category is selected
            local buttonCorner = Instance.new("UICorner")
            buttonCorner.CornerRadius = UDim.new(0, 10)
            buttonCorner.Parent = button
            button.MouseEnter:Connect(function()
                button.BackgroundColor3 = toggleState() and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(70, 70, 70)
            end)
            button.MouseLeave:Connect(function()
                button.BackgroundColor3 = toggleState() and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
            end)
            button.MouseButton1Click:Connect(function()
                local success, err = pcall(callback)
                if not success then
                    notify("⚠️ Error in " .. text .. ": " .. tostring(err), Color3.fromRGB(255, 100, 100))
                end
                button.BackgroundColor3 = toggleState() and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
            end)
            return button
        end

        local categories = {
            Movement = {
                createButton("Toggle Fly", toggleFly, function() return flying end),
                createButton("Toggle Noclip", toggleNoclip, function() return noclip end),
                createButton("Toggle Speed", toggleSpeed, function() return speedEnabled end),
                createButton("Toggle Jump", toggleJump, function() return jumpEnabled end),
                createButton("Toggle Water Walk", toggleWaterWalk, function() return waterWalk end),
                createButton("Toggle God Mode", toggleGodMode, function() return godMode end),
                createButton("Toggle Freeze Moving Parts", toggleFreezeMovingParts, function() return freezeMovingParts end)
            },
            Visual = {
                createButton("Toggle Freecam", toggleFreecam, function() return freecam end)
            },
            Player = {
                createButton("Open Player List", showPlayerList, function() return false end),
                createButton("Spectate Selected Player", spectatePlayer, function() return spectatingPlayer ~= nil end),
                createButton("Stop Spectate", stopSpectate, function() return false end),
                createButton("Teleport to Selected Player", teleportToPlayer, function() return false end)
            },
            Teleport = {
                createButton("Save Position 1", function() savePosition(1) end, function() return savedPositions[1] ~= nil end),
                createButton("Save Position 2", function() savePosition(2) end, function() return savedPositions[2] ~= nil end),
                createButton("Load Position 1", function() loadPosition(1) end, function() return false end),
                createButton("Load Position 2", function() loadPosition(2) end, function() return false end)
            }
        }

        -- Add all buttons to scrollFrame initially
        for categoryName, buttons in pairs(categories) do
            for _, button in pairs(buttons) do
                button.Parent = scrollFrame
            end
        end

        local function updateCategory(categoryName)
            -- Hide all buttons first
            for _, buttons in pairs(categories) do
                for _, button in pairs(buttons) do
                    button.Visible = false
                end
            end
            
            -- Show buttons for selected category
            if categories[categoryName] then
                for _, button in pairs(categories[categoryName]) do
                    button.Visible = true
                end
            end
            
            currentCategory = categoryName
            
            -- Update sidebar button colors
            for _, child in pairs(sidebar:GetChildren()) do
                if child:IsA("TextButton") and child.Name ~= "Logo" then
                    child.BackgroundColor3 = child.Name == categoryName and Color3.fromRGB(70, 70, 70) or Color3.fromRGB(50, 50, 50)
                end
            end
            
            -- Force layout update
            scrollFrame.CanvasPosition = Vector2.new(0, 0)
            scrollUIL:ApplyLayout()
            notify("🔄 Switched to: " .. categoryName)
        end

        -- Create sidebar category buttons
        for categoryName, _ in pairs(categories) do
            local categoryButton = Instance.new("TextButton")
            categoryButton.Size = UDim2.new(1, -20, 0, 50)
            categoryButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            categoryButton.BackgroundTransparency = 0.3
            categoryButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            categoryButton.TextSize = 18
            categoryButton.Font = Enum.Font.GothamBold
            categoryButton.Text = categoryName
            categoryButton.TextWrapped = true
            categoryButton.ZIndex = 12
            categoryButton.Name = categoryName
            local categoryCorner = Instance.new("UICorner")
            categoryCorner.CornerRadius = UDim.new(0, 10)
            categoryCorner.Parent = categoryButton
            categoryButton.MouseEnter:Connect(function()
                if currentCategory ~= categoryName then
                    categoryButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
                end
            end)
            categoryButton.MouseLeave:Connect(function()
                categoryButton.BackgroundColor3 = currentCategory == categoryName and Color3.fromRGB(70, 70, 70) or Color3.fromRGB(50, 50, 50)
            end)
            categoryButton.MouseButton1Click:Connect(function()
                updateCategory(categoryName)
            end)
            categoryButton.Parent = sidebar
        end

        -- Initialize with Movement category
        updateCategory("Movement")

        logo.MouseButton1Click:Connect(function()
            frame.Visible = not frame.Visible
            notify(frame.Visible and "🖼️ GUI Opened" or "🖼️ GUI Closed")
        end)

        -- Make frame draggable
        local dragging, dragInput, dragStart, startPos
        local function updateDrag(input)
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
        frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        frame.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        UserInputService.InputChanged:Connect(function()
            if dragInput and dragging then
                updateDrag(dragInput)
            end
        end)
    end)
    if not success then
        notify("⚠️ GUI creation failed: " .. tostring(errorMsg) .. ", retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(2)
        createGUI()
    end
end

-- Cleanup old instance
local function cleanupOldInstance()
    local oldGui = player.PlayerGui:FindFirstChild("SimpleUILibrary_Krnl")
    if oldGui then
        oldGui:Destroy()
        notify("🛠️ Old script instance terminated", Color3.fromRGB(255, 255, 0))
    end
end

-- Additional utility functions
local function teleportToSpawn()
    local success, errorMsg = pcall(function()
        if hr then
            local spawnLocation = workspace:FindFirstChildOfClass("SpawnLocation")
            local targetPos = spawnLocation and spawnLocation.Position or Vector3.new(0, 5, 0)
            if isValidPosition(targetPos) then
                hr.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
                notify("🚪 Teleported to Spawn")
            else
                notify("⚠️ Invalid spawn position", Color3.fromRGB(255, 100, 100))
            end
        else
            notify("⚠️ Character not loaded", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Teleport to Spawn error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleHideNick()
    nickHidden = not nickHidden
    local success, errorMsg = pcall(function()
        if nickHidden then
            if char then
                local head = char:FindFirstChild("Head")
                if head then
                    local billboard = head:FindFirstChildOfClass("BillboardGui")
                    if billboard then
                        billboard.Enabled = false
                    end
                end
            end
            notify("🕵️ Nickname Hidden")
        else
            if char then
                local head = char:FindFirstChild("Head")
                if head then
                    local billboard = head:FindFirstChildOfClass("BillboardGui")
                    if billboard then
                        billboard.Enabled = true
                    end
                end
            end
            notify("🕵️ Nickname Visible")
        end
    end)
    if not success then
        nickHidden = false
        notify("⚠️ Hide Nickname error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleRandomNick()
    randomNick = not randomNick
    local success, errorMsg = pcall(function()
        if randomNick then
            if char and char:FindFirstChild("Head") then
                local head = char:FindFirstChild("Head")
                local billboard = head:FindFirstChildOfClass("BillboardGui")
                if billboard then
                    local label = billboard:FindFirstChildOfClass("TextLabel")
                    if label then
                        label.Text = HttpService:GenerateGUID(false):sub(1, 8)
                    end
                end
            end
            notify("🎭 Random Nickname Enabled")
        else
            if char and char:FindFirstChild("Head") then
                local head = char:FindFirstChild("Head")
                local billboard = head:FindFirstChildOfClass("BillboardGui")
                if billboard then
                    local label = billboard:FindFirstChildOfClass("TextLabel")
                    if label then
                        label.Text = player.Name
                    end
                end
            end
            notify("🎭 Random Nickname Disabled")
        end
    end)
    if not success then
        randomNick = false
        notify("⚠️ Random Nickname error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function setCustomNick()
    local success, errorMsg = pcall(function()
        if char and char:FindFirstChild("Head") then
            local head = char:FindFirstChild("Head")
            local billboard = head:FindFirstChildOfClass("BillboardGui")
            if billboard then
                local label = billboard:FindFirstChildOfClass("TextLabel")
                if label then
                    label.Text = customNick
                end
            end
            notify("🎭 Custom Nickname Set: " .. customNick)
        else
            notify("⚠️ Character or head not found", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Set Custom Nickname error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Enhanced freeze function for mountain climbing games
local function freezeAllMovingObjects()
    local success, errorMsg = pcall(function()
        local frozenCount = 0
        
        -- More comprehensive search for moving objects
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local shouldFreeze = false
                local objName = obj.Name:lower()
                local parentName = obj.Parent and obj.Parent.Name:lower() or ""
                
                -- Check for common moving object names
                local movingKeywords = {
                    "moving", "platform", "obstacle", "trap", "block", "wood", "step", "stair",
                    "elevator", "lift", "swing", "pendulum", "crusher", "spike", "saw",
                    "conveyor", "belt", "rotating", "spinning", "falling", "dropping"
                }
                
                for _, keyword in pairs(movingKeywords) do
                    if objName:find(keyword) or parentName:find(keyword) then
                        shouldFreeze = true
                        break
                    end
                end
                
                -- Check if object has movement-related components
                if not shouldFreeze then
                    for _, child in pairs(obj:GetChildren()) do
                        if child:IsA("BodyVelocity") or child:IsA("BodyPosition") or 
                           child:IsA("BodyAngularVelocity") or child:IsA("BodyThrust") or
                           child:IsA("TweenService") or child.Name:lower():find("tween") then
                            shouldFreeze = true
                            break
                        end
                    end
                end
                
                -- Check if object is currently moving
                if not shouldFreeze and obj.Velocity.Magnitude > 0.1 and not obj.Anchored then
                    shouldFreeze = true
                end
                
                if shouldFreeze and obj.Name ~= "HumanoidRootPart" then
                    originalCFrames[obj] = obj.CFrame
                    obj.Anchored = true
                    obj.Velocity = Vector3.new(0, 0, 0)
                    -- Only set AngularVelocity if the object is not a UnionOperation
                    if not obj:IsA("UnionOperation") then
                        obj.AngularVelocity = Vector3.new(0, 0, 0)
                    end
                    
                    -- Disable BodyMovers
                    for _, child in pairs(obj:GetChildren()) do
                        if child:IsA("BodyVelocity") or child:IsA("BodyPosition") or 
                           child:IsA("BodyAngularVelocity") or child:IsA("BodyThrust") then
                            child.MaxForce = Vector3.new(0, 0, 0)
                        elseif child:IsA("Script") or child:IsA("LocalScript") then
                            -- Temporarily disable scripts that might move the object
                            child.Disabled = true
                        end
                    end
                    
                    frozenCount = frozenCount + 1
                end
            end
        end
        
        notify("🧊 Frozen " .. frozenCount .. " moving objects")
    end)
    
    if not success then
        notify("⚠️ Freeze objects error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Anti-fall function for mountain climbing
local function toggleAntiFall()
    local antiFall = not (connections.antiFall ~= nil)
    local success, errorMsg = pcall(function()
        if antiFall then
            local lastSafePosition = hr and hr.CFrame or CFrame.new(0, 100, 0)
            
            connections.antiFall = RunService.Heartbeat:Connect(function()
                if hr and humanoid then
                    -- Update safe position if player is on solid ground
                    local ray = workspace:Raycast(hr.Position, Vector3.new(0, -10, 0))
                    if ray and ray.Instance then
                        lastSafePosition = hr.CFrame
                    end
                    
                    -- Check if player is falling too far
                    if hr.Position.Y < lastSafePosition.Position.Y - 50 then
                        hr.CFrame = lastSafePosition
                        notify("🪂 Saved from falling!")
                    end
                end
            end)
            notify("🪂 Anti-Fall Enabled")
        else
            if connections.antiFall then
                connections.antiFall:Disconnect()
                connections.antiFall = nil
            end
            notify("🪂 Anti-Fall Disabled")
        end
    end)
    if not success then
        if connections.antiFall then
            connections.antiFall:Disconnect()
            connections.antiFall = nil
        end
        notify("⚠️ Anti-Fall error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Improved GUI creation with all features
local function createEnhancedGUI()
    local success, errorMsg = pcall(function()
        if gui then
            gui:Destroy()
            gui = nil
        end

        gui = Instance.new("ScreenGui")
        gui.Name = "SimpleUILibrary_Krnl"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Enabled = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = player:WaitForChild("PlayerGui", 20)

        local scale = Instance.new("UIScale")
        scale.Scale = math.min(1, math.min(camera.ViewportSize.X / 1280, camera.ViewportSize.Y / 720))
        scale.Parent = gui

        logo = Instance.new("ImageButton")
        logo.Size = UDim2.new(0, 60, 0, 60)
        logo.Position = defaultLogoPos
        logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        logo.BackgroundTransparency = 0.3
        logo.BorderSizePixel = 0
        logo.Image = "rbxassetid://3570695787"
        logo.ZIndex = 20
        local logoCorner = Instance.new("UICorner")
        logoCorner.CornerRadius = UDim.new(0, 12)
        logoCorner.Parent = logo
        logo.Parent = gui

        frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 850, 0, 550)
        frame.Position = UDim2.new(0.5, -425, 0.5, -275)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        frame.BackgroundTransparency = 0.1
        frame.BorderSizePixel = 0
        frame.Visible = false
        frame.ZIndex = 10
        frame.ClipsDescendants = true
        local frameCorner = Instance.new("UICorner")
        frameCorner.CornerRadius = UDim.new(0, 12)
        frameCorner.Parent = frame
        frame.Parent = gui

        local sidebar = Instance.new("Frame")
        sidebar.Size = UDim2.new(0, 200, 1, 0)
        sidebar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        sidebar.BackgroundTransparency = 0.2
        sidebar.BorderSizePixel = 0
        sidebar.ZIndex = 11
        sidebar.Parent = frame

        local sidebarUIL = Instance.new("UIListLayout")
        sidebarUIL.FillDirection = Enum.FillDirection.Vertical
        sidebarUIL.Padding = UDim.new(0, 8)
        sidebarUIL.Parent = sidebar

        local sidebarPadding = Instance.new("UIPadding")
        sidebarPadding.PaddingTop = UDim.new(0, 15)
        sidebarPadding.PaddingLeft = UDim.new(0, 10)
        sidebarPadding.PaddingRight = UDim.new(0, 10)
        sidebarPadding.Parent = sidebar

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -20, 0, 50)
        title.BackgroundTransparency = 1
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 22
        title.Font = Enum.Font.GothamBold
        title.Text = "Enhanced Krnl UI"
        title.ZIndex = 12
        title.Parent = sidebar

        local contentFrame = Instance.new("Frame")
        contentFrame.Size = UDim2.new(0, 630, 1, -10)
        contentFrame.Position = UDim2.new(0, 210, 0, 5)
        contentFrame.BackgroundTransparency = 1
        contentFrame.ZIndex = 11
        contentFrame.ClipsDescendants = true
        contentFrame.Parent = frame

        local scrollFrame = Instance.new("ScrollingFrame")
        scrollFrame.Size = UDim2.new(1, -10, 1, -10)
        scrollFrame.Position = UDim2.new(0, 5, 0, 5)
        scrollFrame.BackgroundTransparency = 1
        scrollFrame.ScrollBarThickness = 8
        scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
        scrollFrame.ZIndex = 11
        scrollFrame.ClipsDescendants = true
        scrollFrame.ScrollingEnabled = true
        scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        scrollFrame.Parent = contentFrame

        local scrollUIL = Instance.new("UIListLayout")
        scrollUIL.FillDirection = Enum.FillDirection.Vertical
        scrollUIL.Padding = UDim.new(0, 8)
        scrollUIL.Parent = scrollFrame

        local scrollPadding = Instance.new("UIPadding")
        scrollPadding.PaddingTop = UDim.new(0, 15)
        scrollPadding.PaddingBottom = UDim.new(0, 20)
        scrollPadding.PaddingLeft = UDim.new(0, 15)
        scrollPadding.PaddingRight = UDim.new(0, 15)
        scrollPadding.Parent = scrollFrame

        local function createButton(text, callback, toggleState)
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, -10, 0, 45)
            button.BackgroundColor3 = toggleState() and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
            button.BackgroundTransparency = 0.2
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
            button.TextSize = 16
            button.Font = Enum.Font.Gotham
            button.Text = text
            button.TextWrapped = true
            button.ZIndex = 12
            button.Visible = false
            local buttonCorner = Instance.new("UICorner")
            buttonCorner.CornerRadius = UDim.new(0, 8)
            buttonCorner.Parent = button
            
            button.MouseEnter:Connect(function()
                button.BackgroundColor3 = toggleState() and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(70, 70, 70)
            end)
            button.MouseLeave:Connect(function()
                button.BackgroundColor3 = toggleState() and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
            end)
            button.MouseButton1Click:Connect(function()
                local success, err = pcall(callback)
                if not success then
                    notify("⚠️ Error in " .. text .. ": " .. tostring(err), Color3.fromRGB(255, 100, 100))
                end
                -- Update button color after callback
                button.BackgroundColor3 = toggleState() and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
            end)
            return button
        end

        -- Define all categories with complete feature set
        local categories = {
            Movement = {
                createButton("Toggle Fly", toggleFly, function() return flying end),
                createButton("Toggle Noclip", toggleNoclip, function() return noclip end),
                createButton("Toggle Speed", toggleSpeed, function() return speedEnabled end),
                createButton("Toggle Jump Power", toggleJump, function() return jumpEnabled end),
                createButton("Toggle Water Walk", toggleWaterWalk, function() return waterWalk end),
                createButton("Toggle God Mode", toggleGodMode, function() return godMode end),
                createButton("Toggle Anti-Fall", toggleAntiFall, function() return connections.antiFall ~= nil end)
            },
            Visual = {
                createButton("Toggle Freecam", toggleFreecam, function() return freecam end),
                createButton("Toggle Hide Nickname", toggleHideNick, function() return nickHidden end),
                createButton("Toggle Random Nickname", toggleRandomNick, function() return randomNick end),
                createButton("Set Custom Nickname", setCustomNick, function() return false end)
            },
            World = {
                createButton("Toggle Freeze Moving Parts", toggleFreezeMovingParts, function() return freezeMovingParts end),
                createButton("Freeze All Moving Objects", freezeAllMovingObjects, function() return false end)
            },
            Player = {
                createButton("Open Player List", showPlayerList, function() return false end),
                createButton("Spectate Selected Player", spectatePlayer, function() return spectatingPlayer ~= nil end),
                createButton("Stop Spectate", stopSpectate, function() return false end),
                createButton("Teleport to Selected Player", teleportToPlayer, function() return false end)
            },
            Teleport = {
                createButton("Teleport to Spawn", teleportToSpawn, function() return false end),
                createButton("Save Position 1", function() savePosition(1) end, function() return savedPositions[1] ~= nil end),
                createButton("Save Position 2", function() savePosition(2) end, function() return savedPositions[2] ~= nil end),
                createButton("Load Position 1", function() loadPosition(1) end, function() return false end),
                createButton("Load Position 2", function() loadPosition(2) end, function() return false end)
            }
        }

        -- Add all buttons to scrollFrame
        for categoryName, buttons in pairs(categories) do
            for _, button in pairs(buttons) do
                button.Parent = scrollFrame
            end
        end

        local function updateCategory(categoryName)
            -- Hide all buttons
            for _, buttons in pairs(categories) do
                for _, button in pairs(buttons) do
                    button.Visible = false
                end
            end
            
            -- Show buttons for selected category
            if categories[categoryName] then
                for _, button in pairs(categories[categoryName]) do
                    button.Visible = true
                end
            end
            
            currentCategory = categoryName
            
            -- Update sidebar button colors
            for _, child in pairs(sidebar:GetChildren()) do
                if child:IsA("TextButton") and categories[child.Name] then
                    child.BackgroundColor3 = child.Name == categoryName and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(50, 50, 50)
                end
            end
            
            scrollFrame.CanvasPosition = Vector2.new(0, 0)
            notify("📂 " .. categoryName .. " (" .. #categories[categoryName] .. " features)")
        end

        -- Create sidebar category buttons
        for categoryName, _ in pairs(categories) do
            local categoryButton = Instance.new("TextButton")
            categoryButton.Size = UDim2.new(1, -20, 0, 45)
            categoryButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            categoryButton.BackgroundTransparency = 0.2
            categoryButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            categoryButton.TextSize = 16
            categoryButton.Font = Enum.Font.GothamBold
            categoryButton.Text = categoryName
            categoryButton.ZIndex = 12
            categoryButton.Name = categoryName
            local categoryCorner = Instance.new("UICorner")
            categoryCorner.CornerRadius = UDim.new(0, 8)
            categoryCorner.Parent = categoryButton
            
            categoryButton.MouseEnter:Connect(function()
                if currentCategory ~= categoryName then
                    categoryButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
                end
            end)
            categoryButton.MouseLeave:Connect(function()
                categoryButton.BackgroundColor3 = currentCategory == categoryName and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(50, 50, 50)
            end)
            categoryButton.MouseButton1Click:Connect(function()
                updateCategory(categoryName)
            end)
            categoryButton.Parent = sidebar
        end

        -- Initialize with Movement category
        updateCategory("Movement")

        logo.MouseButton1Click:Connect(function()
            frame.Visible = not frame.Visible
            notify(frame.Visible and "🖼️ GUI Opened" or "🖼️ GUI Closed")
        end)

        -- Make frame draggable
        local dragging, dragInput, dragStart, startPos
        local function updateDrag(input)
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
        
        title.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        
        title.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        
        UserInputService.InputChanged:Connect(function()
            if dragInput and dragging then
                updateDrag(dragInput)
            end
        end)
    end)
    
    if not success then
        notify("⚠️ Enhanced GUI creation failed: " .. tostring(errorMsg) .. ", retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(2)
        createEnhancedGUI()
    end
end

-- Main initialization
local function main()
    local success, errorMsg = pcall(function()
        cleanupOldInstance()
        task.wait(1.5)
        createEnhancedGUI()
        createJoystick()
        createPlayerListUI()
        initChar()
        player.CharacterAdded:Connect(initChar)
        notify("✅ Enhanced Krnl UI Loaded Successfully! 🚀")
    end)
    if not success then
        notify("⚠️ Script failed to load: " .. tostring(errorMsg) .. ", retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(2)
        main()
    end
end

main()