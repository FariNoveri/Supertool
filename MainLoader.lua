local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid, hr, char
local gui, frame, logo, joystickFrame, cameraControlFrame
local selectedPlayer = nil
local flying, freecam, noclip, godMode = false, false, false, false
local flySpeed = 50
local freecamSpeed = 30
local cameraRotationSensitivity = 0.005 -- Dikurangi untuk rotasi lebih halus
local speedEnabled, jumpEnabled, waterWalk, rocket, spin = false, false, false, false, false
local moveSpeed = 50
local jumpPower = 100
local spinSpeed = 20
local savedPositions = { [1] = nil, [2] = nil }
local macroRecording, macroPlaying, autoPlayOnRespawn, recordOnRespawn = false, false, false, false
local macroActions = {}
local macroSuccessfulRun = nil
local isMobile = UserInputService.TouchEnabled
local freecamCFrame = nil
local hrCFrame = nil
local joystickTouch = nil
local cameraTouch = nil
local joystickRadius = 50
local moveDirection = Vector3.new(0, 0, 0)
local cameraDelta = Vector2.new(0, 0)
local nickHidden, randomNick = false, false
local customNick = "PemainKeren"
local defaultLogoPos = UDim2.new(0.95, -60, 0.05, 10)
local defaultFramePos = UDim2.new(0.5, -200, 0.5, -300)

local connections = {}

-- Notify function
local function notify(message, color)
    local success, errorMsg = pcall(function()
        if not gui then
            print("Notify: " .. message)
            return
        end
        local notif = Instance.new("TextLabel")
        notif.Size = UDim2.new(0, 300, 0, 50)
        notif.Position = UDim2.new(0.5, -150, 0.1, 0)
        notif.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notif.BackgroundTransparency = 0.5
        notif.TextColor3 = color or Color3.fromRGB(0, 255, 0)
        notif.TextScaled = true
        notif.Font = Enum.Font.Gotham
        notif.Text = message
        notif.BorderSizePixel = 0
        notif.ZIndex = 20
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
    joystickFrame.Parent = gui

    local joystickKnob = Instance.new("Frame")
    joystickKnob.Size = UDim2.new(0, 40, 0, 40)
    joystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
    joystickKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    joystickKnob.BackgroundTransparency = 0.2
    joystickKnob.BorderSizePixel = 0
    joystickKnob.ZIndex = 16
    joystickKnob.Parent = joystickFrame

    cameraControlFrame = Instance.new("Frame")
    cameraControlFrame.Size = UDim2.new(0, 120, 0, 120)
    cameraControlFrame.Position = UDim2.new(0.8, -120, 0.65, 0)
    cameraControlFrame.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    cameraControlFrame.BackgroundTransparency = 0.5
    cameraControlFrame.BorderSizePixel = 0
    cameraControlFrame.ZIndex = 15
    cameraControlFrame.Visible = false
    cameraControlFrame.Parent = gui

    local cameraKnob = Instance.new("Frame")
    cameraKnob.Size = UDim2.new(0, 40, 0, 40)
    cameraKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
    cameraKnob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    cameraKnob.BackgroundTransparency = 0.2
    cameraKnob.BorderSizePixel = 0
    cameraKnob.ZIndex = 16
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
        moveDirection = Vector3.new(delta.X / maxRadius, 0, -delta.Y / maxRadius)
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
        cameraDelta = Vector2.new(-delta.X / maxRadius, delta.Y / maxRadius) -- Dibalik untuk rotasi tangan kanan
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
                    cameraDelta = Vector2.new(-input.Delta.X, input.Delta.Y) -- Dibalik untuk rotasi tangan kanan
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
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + forward end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - forward end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - right end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + right end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + up end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - up end
                end
                if moveDir.Magnitude > 0 then
                    moveDir = moveDir.Unit * flySpeed
                end
                bv.Velocity = moveDir
                hr.CFrame = CFrame.new(hr.Position) * camera.CFrame.Rotation
                local rotation = CFrame.Angles(0, cameraDelta.X * cameraRotationSensitivity, 0) * CFrame.Angles(cameraDelta.Y * cameraRotationSensitivity, 0, 0)
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
                    cameraDelta = Vector2.new(-input.Delta.X, input.Delta.Y) -- Dibalik untuk rotasi tangan kanan
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
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + forward end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - forward end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - right end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + right end
                    if UserInputService:IsKeyDown(Enum.KeyCode.E) then moveDir = moveDir + up end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveDir = moveDir - up end
                end
                if moveDir.Magnitude > 0 then
                    moveDir = moveDir * freecamSpeed
                    freecamCFrame = CFrame.new(freecamCFrame.Position + moveDir) * freecamCFrame.Rotation
                end
                local yaw = cameraDelta.X * cameraRotationSensitivity
                local pitch = cameraDelta.Y * cameraRotationSensitivity
                -- Clamp pitch untuk mencegah muter-muter berlebihan
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
        notify("⚠️ Freecam error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Freecam utilities
local function returnToCharacter()
    if freecam and hr and humanoid then
        freecamCFrame = CFrame.new(hr.CFrame.Position + Vector3.new(0, 5, 10), hr.CFrame.Position)
        camera.CFrame = freecamCFrame
        notify("📷 Returned to Character")
    else
        notify("⚠️ Freecam not enabled or character not loaded", Color3.fromRGB(255, 100, 100))
    end
end

local function cancelFreecam()
    if freecam then
        toggleFreecam()
        notify("📷 Freecam Canceled")
    else
        notify("⚠️ Freecam not enabled", Color3.fromRGB(255, 100, 100))
    end
end

local function teleportCharacterToCamera()
    if freecam and hr and isValidPosition(freecamCFrame.Position) then
        hrCFrame = CFrame.new(freecamCFrame.Position + Vector3.new(0, 3, 0))
        local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(hr, tweenInfo, {CFrame = hrCFrame})
        tween:Play()
        tween.Completed:Connect(function()
            notify("👤 Character Teleported to Camera")
        end)
    else
        notify("⚠️ Freecam not enabled or invalid position", Color3.fromRGB(255, 100, 100))
    end
end

-- Noclip toggle
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

-- Speed toggle
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

-- Jump toggle
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

-- Water walk toggle
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

-- Rocket toggle
local function toggleRocket()
    rocket = not rocket
    local success, errorMsg = pcall(function()
        if rocket then
            if not hr or not humanoid then
                rocket = false
                error("Character not loaded")
            end
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(0, math.huge, 0)
            bv.Velocity = Vector3.new(0, 100, 0)
            bv.Parent = hr
            notify("🚀 Rocket Enabled")
        else
            if hr and hr:FindFirstChildOfClass("BodyVelocity") then
                hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
            end
            notify("🚀 Rocket Disabled")
        end
    end)
    if not success then
        rocket = false
        if hr and hr:FindFirstChildOfClass("BodyVelocity") then
            hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
        end
        notify("⚠️ Rocket error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Spin toggle
local function toggleSpin()
    spin = not spin
    local success, errorMsg = pcall(function()
        if spin then
            if not hr or not humanoid then
                spin = false
                error("Character not loaded")
            end
            connections.spin = RunService.RenderStepped:Connect(function()
                if hr then
                    hr.CFrame = hr.CFrame * CFrame.Angles(0, math.rad(spinSpeed), 0)
                end
            end)
            notify("🌀 Spin Enabled")
        else
            if connections.spin then
                connections.spin:Disconnect()
                connections.spin = nil
            end
            notify("🌀 Spin Disabled")
        end
    end)
    if not success then
        spin = false
        if connections.spin then
            connections.spin:Disconnect()
            connections.spin = nil
        end
        notify("⚠️ Spin error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- God mode toggle
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

-- Hide nickname toggle
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

-- Random nickname toggle
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
                        label.Text = HttpService:GenerateGUID(false)
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

-- Set custom nickname
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

-- Macro functions
local function toggleRecordMacro()
    macroRecording = not macroRecording
    local success, errorMsg = pcall(function()
        if macroRecording then
            macroActions = {}
            local startTime = tick()
            connections.macroRecord = RunService.RenderStepped:Connect(function()
                if hr and humanoid then
                    table.insert(macroActions, {
                        time = tick() - startTime,
                        position = hr.CFrame,
                        velocity = hr.Velocity,
                        state = humanoid:GetState()
                    })
                end
            end)
            notify("🎥 Macro Recording Started")
        else
            if connections.macroRecord then
                connections.macroRecord:Disconnect()
                connections.macroRecord = nil
            end
            notify("🎥 Macro Recording Stopped (" .. #macroActions .. " actions recorded)")
        end
    end)
    if not success then
        macroRecording = false
        if connections.macroRecord then
            connections.macroRecord:Disconnect()
            connections.macroRecord = nil
        end
        notify("⚠️ Macro Record error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function togglePlayMacro()
    macroPlaying = not macroPlaying
    local success, errorMsg = pcall(function()
        if macroPlaying then
            if #macroActions == 0 then
                macroPlaying = false
                error("No macro actions recorded")
            end
            if not hr or not humanoid then
                macroPlaying = false
                error("Character not loaded")
            end
            local startTime = tick()
            local index = 1
            connections.macroPlay = RunService.RenderStepped:Connect(function()
                if not hr or not humanoid then
                    macroPlaying = false
                    if connections.macroPlay then
                        connections.macroPlay:Disconnect()
                        connections.macroPlay = nil
                    end
                    notify("⚠️ Macro playback failed: Character lost", Color3.fromRGB(255, 100, 100))
                    return
                end
                local currentTime = tick() - startTime
                while index <= #macroActions and macroActions[index].time <= currentTime do
                    local action = macroActions[index]
                    hr.CFrame = action.position
                    hr.Velocity = action.velocity
                    humanoid:ChangeState(action.state)
                    index = index + 1
                end
                if index > #macroActions then
                    macroSuccessfulRun = true
                    togglePlayMacro()
                end
            end)
            notify("▶️ Macro Playback Started")
        else
            if connections.macroPlay then
                connections.macroPlay:Disconnect()
                connections.macroPlay = nil
            end
            notify(macroSuccessfulRun and "▶️ Macro Playback Completed" or "▶️ Macro Playback Stopped")
            macroSuccessfulRun = nil
        end
    end)
    if not success then
        macroPlaying = false
        if connections.macroPlay then
            connections.macroPlay:Disconnect()
            connections.macroPlay = nil
        end
        notify("⚠️ Macro Play error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleAutoPlayOnRespawn()
    autoPlayOnRespawn = not autoPlayOnRespawn
    notify(autoPlayOnRespawn and "🔄 Auto Play Macro on Respawn Enabled" or "🔄 Auto Play Macro on Respawn Disabled")
end

local function toggleRecordOnRespawn()
    recordOnRespawn = not recordOnRespawn
    notify(recordOnRespawn and "🔄 Record Macro on Respawn Enabled" or "🔄 Record Macro on Respawn Disabled")
end

-- Create GUI
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
        scale.Parent = gui
        local screenSize = camera.ViewportSize
        scale.Scale = math.min(1, math.min(screenSize.X / 1280, screenSize.Y / 720)) -- Skala lebih besar untuk Android

        logo = Instance.new("ImageButton")
        logo.Size = UDim2.new(0, 70, 0, 70)
        logo.Position = defaultLogoPos
        logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        logo.BorderSizePixel = 0
        logo.Image = "rbxassetid://3570695787"
        logo.ZIndex = 20
        logo.Parent = gui

        frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 400, 0, 600) -- Diperbesar agar nggak kecel
        frame.Position = defaultFramePos
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        frame.BackgroundTransparency = 0.1
        frame.BorderSizePixel = 0
        frame.Visible = false
        frame.ZIndex = 10
        frame.ClipsDescendants = true
        frame.Parent = gui

        local uil = Instance.new("UIListLayout")
        uil.FillDirection = Enum.FillDirection.Vertical
        uil.Padding = UDim.new(0, 10)
        uil.Parent = frame

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 50)
        title.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        title.BackgroundTransparency = 0.5
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextScaled = true
        title.Font = Enum.Font.GothamBold
        title.Text = "Krnl UI"
        title.ZIndex = 11
        title.Parent = frame

        local scrollFrame = Instance.new("ScrollingFrame")
        scrollFrame.Size = UDim2.new(1, 0, 1, -60)
        scrollFrame.Position = UDim2.new(0, 0, 0, 60)
        scrollFrame.BackgroundTransparency = 1
        scrollFrame.ScrollBarThickness = 8
        scrollFrame.ZIndex = 11
        scrollFrame.ClipsDescendants = true
        scrollFrame.Parent = frame

        local scrollUIL = Instance.new("UIListLayout")
        scrollUIL.FillDirection = Enum.FillDirection.Vertical
        scrollUIL.Padding = UDim.new(0, 8)
        scrollUIL.Parent = scrollFrame

        local function createButton(text, callback, toggleState)
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(0.9, 0, 0, 50) -- Tombol lebih besar
            button.Position = UDim2.new(0.05, 0, 0, 0)
            button.BackgroundColor3 = toggleState() and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
            button.BackgroundTransparency = 0.3
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
            button.TextScaled = true
            button.Font = Enum.Font.Gotham
            button.Text = text
            button.ZIndex = 12
            button.Parent = scrollFrame
            local function updateButton()
                button.BackgroundColor3 = toggleState() and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
                scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollUIL.AbsoluteContentSize.Y + 20) -- Tambah padding
            end
            button.MouseButton1Click:Connect(function()
                local success, err = pcall(callback)
                if not success then
                    notify("⚠️ Error in " .. text .. ": " .. tostring(err), Color3.fromRGB(255, 100, 100))
                end
                updateButton()
            end)
            updateButton()
            return button
        end

        local function createDropdown(text, items, callback)
            local dropdown = Instance.new("TextButton")
            dropdown.Size = UDim2.new(0.9, 0, 0, 50)
            dropdown.Position = UDim2.new(0.05, 0, 0, 0)
            dropdown.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            dropdown.BackgroundTransparency = 0.3
            dropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
            dropdown.TextScaled = true
            dropdown.Font = Enum.Font.Gotham
            dropdown.Text = text
            dropdown.ZIndex = 12
            dropdown.Parent = scrollFrame

            local dropdownFrame = Instance.new("Frame")
            dropdownFrame.Size = UDim2.new(0.9, 0, 0, 0)
            dropdownFrame.Position = UDim2.new(0.05, 0, 0, 55)
            dropdownFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            dropdownFrame.BackgroundTransparency = 0.1
            dropdownFrame.BorderSizePixel = 0
            dropdownFrame.Visible = false
            dropdownFrame.ZIndex = 13
            dropdownFrame.ClipsDescendants = true
            dropdownFrame.Parent = scrollFrame

            local dropdownUIL = Instance.new("UIListLayout")
            dropdownUIL.FillDirection = Enum.FillDirection.Vertical
            dropdownUIL.Padding = UDim.new(0, 5)
            dropdownUIL.Parent = dropdownFrame

            for _, item in pairs(items) do
                local itemButton = Instance.new("TextButton")
                itemButton.Size = UDim2.new(1, 0, 0, 40)
                itemButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                itemButton.BackgroundTransparency = 0.3
                itemButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                itemButton.TextScaled = true
                itemButton.Font = Enum.Font.Gotham
                itemButton.Text = item
                itemButton.ZIndex = 14
                itemButton.Parent = dropdownFrame
                itemButton.MouseButton1Click:Connect(function()
                    callback(item)
                    dropdownFrame.Visible = false
                    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollUIL.AbsoluteContentSize.Y + 20)
                end)
            end

            dropdown.MouseButton1Click:Connect(function()
                dropdownFrame.Visible = not dropdownFrame.Visible
                dropdownFrame.Size = dropdownFrame.Visible and UDim2.new(0.9, 0, 0, #items * 45) or UDim2.new(0.9, 0, 0, 0)
                scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollUIL.AbsoluteContentSize.Y + 20)
            end)

            scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollUIL.AbsoluteContentSize.Y + 20)
        end

        -- Update CanvasSize saat konten berubah
        scrollUIL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollUIL.AbsoluteContentSize.Y + 20)
        end)

        logo.MouseButton1Click:Connect(function()
            frame.Visible = not frame.Visible
            notify(frame.Visible and "🖼️ GUI Opened" or "🖼️ GUI Closed")
        end)

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
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                updateDrag(input)
            end
        end)

        createButton("Toggle Fly", toggleFly, function() return flying end)
        createButton("Toggle Freecam", toggleFreecam, function() return freecam end)
        createButton("Return to Character", returnToCharacter, function() return false end)
        createButton("Cancel Freecam", cancelFreecam, function() return false end)
        createButton("Teleport Character to Camera", teleportCharacterToCamera, function() return false end)
        createButton("Toggle Noclip", toggleNoclip, function() return noclip end)
        createButton("Toggle Speed", toggleSpeed, function() return speedEnabled end)
        createButton("Toggle Jump", toggleJump, function() return jumpEnabled end)
        createButton("Toggle Water Walk", toggleWaterWalk, function() return waterWalk end)
        createButton("Toggle Rocket", toggleRocket, function() return rocket end)
        createButton("Toggle Spin", toggleSpin, function() return spin end)
        createButton("Toggle God Mode", toggleGodMode, function() return godMode end)
        createButton("Toggle Hide Nickname", toggleHideNick, function() return nickHidden end)
        createButton("Toggle Random Nickname", toggleRandomNick, function() return randomNick end)
        createButton("Set Custom Nickname", setCustomNick, function() return false end)
        createButton("Teleport to Player", teleportToPlayer, function() return false end)
        createButton("Teleport to Spawn", teleportToSpawn, function() return false end)
        createButton("Save Position 1", function() savePosition(1) end, function() return false end)
        createButton("Save Position 2", function() savePosition(2) end, function() return false end)
        createButton("Load Position 1", function() loadPosition(1) end, function() return false end)
        createButton("Load Position 2", function() loadPosition(2) end, function() return false end)
        createButton("Toggle Record Macro", toggleRecordMacro, function() return macroRecording end)
        createButton("Toggle Play Macro", togglePlayMacro, function() return macroPlaying end)
        createButton("Toggle Auto Play Macro on Respawn", toggleAutoPlayOnRespawn, function() return autoPlayOnRespawn end)
        createButton("Toggle Record Macro on Respawn", toggleRecordOnRespawn, function() return recordOnRespawn end)

        local playerNames = {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player then
                table.insert(playerNames, p.Name)
            end
        end
        createDropdown("Select Player", playerNames, function(name)
            selectedPlayer = Players:FindFirstChild(name)
            notify("👤 Selected Player: " .. name)
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

-- Main initialization
local function main()
    local success, errorMsg = pcall(function()
        cleanupOldInstance()
        task.wait(1.5) -- Delay lebih panjang untuk Android
        createGUI()
        createJoystick()
        initChar()
        player.CharacterAdded:Connect(initChar)
        notify("✅ Script Loaded Successfully")
    end)
    if not success then
        notify("⚠️ Script failed to load: " .. tostring(errorMsg) .. ", retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(2)
        main()
    end
end

main()
