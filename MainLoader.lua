```lua
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
local flySpeed = 40
local freecamSpeed = UserInputService.TouchEnabled and 20 or 30
local cameraRotationSensitivity = UserInputService.TouchEnabled and 0.01 or 0.005
local speedEnabled, jumpEnabled, waterWalk, rocket, spin = false, false, false, false, false
local moveSpeed = 50
local jumpPower = 100
local spinSpeed = 20
local savedPositions = {} -- {slot = {name = "string", cframe = CFrame}}
local maxSlots = 10
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
local defaultFramePos = UDim2.new(0.5, -175, 0.5, -250)

local connections = {}

-- File I/O for persistent storage
local function saveTeleportSlots()
    local success, errorMsg = pcall(function()
        local data = {}
        for slot, info in pairs(savedPositions) do
            data[tostring(slot)] = {name = info.name, cframe = {info.cframe:GetComponents()}}
        end
        writefile("krnl/teleport_slots.json", HttpService:JSONEncode(data))
    end)
    if not success then
        notify("⚠️ Failed to save teleport slots: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function loadTeleportSlots()
    local success, result = pcall(function()
        if isfile("krnl/teleport_slots.json") then
            local data = HttpService:JSONDecode(readfile("krnl/teleport_slots.json"))
            savedPositions = {}
            for slot, info in pairs(data) do
                slot = tonumber(slot)
                if slot and info.name and info.cframe and #info.cframe == 12 then
                    savedPositions[slot] = {
                        name = info.name,
                        cframe = CFrame.new(table.unpack(info.cframe))
                    }
                end
            end
        end
    end)
    if not success then
        notify("⚠️ Failed to load teleport slots: " .. tostring(result), Color3.fromRGB(255, 100, 100))
    end
end

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
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
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

local function savePosition()
    local success, errorMsg = pcall(function()
        if hr then
            local slot = 1
            while savedPositions[slot] and slot <= maxSlots do
                slot = slot + 1
            end
            if slot > maxSlots then
                notify("⚠️ Maximum " .. maxSlots .. " slots reached", Color3.fromRGB(255, 100, 100))
                return
            end
            savedPositions[slot] = {name = "Slot " .. slot, cframe = hr.CFrame}
            saveTeleportSlots()
            notify("💾 Position Saved to Slot " .. slot)
            createGUI() -- Refresh GUI to show new slot
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
        if hr and savedPositions[slot] and isValidPosition(savedPositions[slot].cframe.Position) then
            hr.CFrame = savedPositions[slot].cframe
            notify("📍 Teleported to " .. savedPositions[slot].name)
        else
            notify("⚠️ No position saved in slot " .. slot .. " or invalid position", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Load Position error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function renamePosition(slot, newName)
    local success, errorMsg = pcall(function()
        if savedPositions[slot] then
            newName = newName:sub(1, 20) -- Limit name length
            savedPositions[slot].name = newName
            saveTeleportSlots()
            notify("✏️ Renamed Slot " .. slot .. " to " .. newName)
            createGUI() -- Refresh GUI to show new name
        else
            notify("⚠️ No position saved in slot " .. slot, Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Rename Position error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Macro functions
local function toggleRecordMacro()
    macroRecording = not macroRecording
    local success, errorMsg = pcall(function()
        if macroRecording then
            macroActions = {}
            macroSuccessfulEndTime = nil
            local startTime = tick()
            connections.macroRecord = RunService.RenderStepped:Connect(function()
                if hr and humanoid then
                    local action = {
                        time = tick() - startTime,
                        position = hr.CFrame,
                        velocity = hr.Velocity,
                        state = humanoid:GetState(),
                        health = humanoid.Health
                    }
                    table.insert(macroActions, action)
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

local function markSuccessfulRun()
    local success, errorMsg = pcall(function()
        if macroRecording then
            macroSuccessfulEndTime = tick() - (macroActions[1] and macroActions[1].time or tick())
            notify("✅ Marked Successful Run at " .. string.format("%.2f", macroSuccessfulEndTime) .. "s")
        else
            notify("⚠️ Not recording macro", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Mark Successful Run error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
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
                    if action.health > 0 and action.state ~= Enum.HumanoidStateType.Dead and (not macroSuccessfulEndTime or action.time <= macroSuccessfulEndTime) then
                        hr.CFrame = action.position
                        hr.Velocity = action.velocity
                        humanoid:ChangeState(action.state)
                    end
                    index = index + 1
                end
                if index > #macroActions or (macroSuccessfulEndTime and currentTime >= macroSuccessfulEndTime) then
                    togglePlayMacro()
                    notify("▶️ Macro Playback Completed")
                end
            end)
            notify("▶️ Macro Playback Started")
        else
            if connections.macroPlay then
                connections.macroPlay:Disconnect()
                connections.macroPlay = nil
            end
            notify("▶️ Macro Playback Stopped")
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

-- Create GUI with categories
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
        scale.Scale = math.min(1, math.min(camera.ViewportSize.X / 720, camera.ViewportSize.Y / 1280))
        scale.Parent = gui

        logo = Instance.new("ImageButton")
        logo.Size = UDim2.new(0, 50, 0, 50)
        logo.Position = defaultLogoPos
        logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        logo.BackgroundTransparency = 0.3
        logo.BorderSizePixel = 0
        logo.Image = "rbxassetid://3570695787"
        logo.ZIndex = 20
        local logoCorner = Instance.new("UICorner")
        logoCorner.CornerRadius = UDim.new(0, 8)
        logoCorner.Parent = logo
        logo.Parent = gui

        frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 350, 0, 500)
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

        local uil = Instance.new("UIListLayout")
        uil.FillDirection = Enum.FillDirection.Vertical
        uil.Padding = UDim.new(0, 10)
        uil.Parent = frame

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 40)
        title.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        title.BackgroundTransparency = 0.5
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextScaled = true
        title.Font = Enum.Font.GothamBold
        title.Text = "Krnl UI"
        title.ZIndex = 11
        local titleCorner = Instance.new("UICorner")
        titleCorner.CornerRadius = UDim.new(0, 8)
        titleCorner.Parent = title
        title.Parent = frame

        local scrollFrame = Instance.new("ScrollingFrame")
        scrollFrame.Size = UDim2.new(1, -10, 1, -50)
        scrollFrame.Position = UDim2.new(0, 5, 0, 45)
        scrollFrame.BackgroundTransparency = 1
        scrollFrame.ScrollBarThickness = 6
        scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
        scrollFrame.ZIndex = 11
        scrollFrame.ClipsDescendants = true
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        scrollFrame.Parent = frame

        local scrollUIL = Instance.new("UIListLayout")
        scrollUIL.FillDirection = Enum.FillDirection.Vertical
        scrollUIL.Padding = UDim.new(0, 8)
        scrollUIL.Parent = scrollFrame

        local scrollPadding = Instance.new("UIPadding")
        scrollPadding.PaddingTop = UDim.new(0, 5)
        scrollPadding.PaddingBottom = UDim.new(0, 20)
        scrollPadding.Parent = scrollFrame

        local renameInput
        local function createRenameInput(slot, isSave)
            if renameInput then
                renameInput:Destroy()
            end
            renameInput = Instance.new("Frame")
            renameInput.Size = UDim2.new(0.95, 0, 0, 50)
            renameInput.Position = UDim2.new(0.025, 0, 0, 0)
            renameInput.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            renameInput.BackgroundTransparency = 0.2
            renameInput.ZIndex = 15
            renameInput.Parent = scrollFrame

            local inputBox = Instance.new("TextBox")
            inputBox.Size = UDim2.new(0.8, -10, 0, 40)
            inputBox.Position = UDim2.new(0, 5, 0, 5)
            inputBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            inputBox.TextScaled = true
            inputBox.Font = Enum.Font.Gotham
            inputBox.Text = savedPositions[slot] and savedPositions[slot].name or "Slot " .. slot
            inputBox.ZIndex = 16
            local inputCorner = Instance.new("UICorner")
            inputCorner.CornerRadius = UDim.new(0, 8)
            inputCorner.Parent = inputBox
            inputBox.Parent = renameInput

            local confirmButton = Instance.new("TextButton")
            confirmButton.Size = UDim2.new(0.2, -10, 0, 40)
            confirmButton.Position = UDim2.new(0.8, 5, 0, 5)
            confirmButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
            confirmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            confirmButton.TextScaled = true
            confirmButton.Font = Enum.Font.Gotham
            confirmButton.Text = "OK"
            confirmButton.ZIndex = 16
            local confirmCorner = Instance.new("UICorner")
            confirmCorner.CornerRadius = UDim.new(0, 8)
            confirmCorner.Parent = confirmButton
            confirmButton.Parent = renameInput

            confirmButton.MouseButton1Click:Connect(function()
                local newName = inputBox.Text
                if newName ~= "" then
                    renamePosition(slot, newName)
                end
                renameInput:Destroy()
                renameInput = nil
                scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollUIL.AbsoluteContentSize.Y + 30)
            end)

            inputBox.FocusLost:Connect(function(enterPressed)
                if enterPressed then
                    local newName = inputBox.Text
                    if newName ~= "" then
                        renamePosition(slot, newName)
                    end
                    renameInput:Destroy()
                    renameInput = nil
                    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollUIL.AbsoluteContentSize.Y + 30)
                end
            end)
        end

        local function createButton(text, callback, toggleState, slot, isSave)
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(0.95, 0, 0, 40)
            button.Position = UDim2.new(0.025, 0, 0, 0)
            button.BackgroundColor3 = toggleState() and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
            button.BackgroundTransparency = 0.3
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
            button.TextScaled = true
            button.Font = Enum.Font.Gotham
            button.Text = text
            button.ZIndex = 12
            local buttonCorner = Instance.new("UICorner")
            buttonCorner.CornerRadius = UDim.new(0, 8)
            buttonCorner.Parent = button

            local holdStart = nil
            button.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    holdStart = tick()
                end
            end)
            button.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    if holdStart and tick() - holdStart >= 2 then
                        if slot then
                            createRenameInput(slot, isSave)
                            scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollUIL.AbsoluteContentSize.Y + 30)
                        end
                    else
                        local success, err = pcall(callback)
                        if not success then
                            notify("⚠️ Error in " .. text .. ": " .. tostring(err), Color3.fromRGB(255, 100, 100))
                        end
                        button.BackgroundColor3 = toggleState() and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
                        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollUIL.AbsoluteContentSize.Y + 30)
                    end
                    holdStart = nil
                end
            end)

            return button
        end

        local function createDropdown(text, items, callback)
            local dropdown = Instance.new("TextButton")
            dropdown.Size = UDim2.new(0.95, 0, 0, 40)
            dropdown.Position = UDim2.new(0.025, 0, 0, 0)
            dropdown.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            dropdown.BackgroundTransparency = 0.3
            dropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
            dropdown.TextScaled = true
            dropdown.Font = Enum.Font.Gotham
            dropdown.Text = text
            dropdown.ZIndex = 12
            local dropdownCorner = Instance.new("UICorner")
            dropdownCorner.CornerRadius = UDim.new(0, 8)
            dropdownCorner.Parent = dropdown

            local dropdownFrame = Instance.new("Frame")
            dropdownFrame.Size = UDim2.new(0.95, 0, 0, 0)
            dropdownFrame.Position = UDim2.new(0.025, 0, 0, 45)
            dropdownFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            dropdownFrame.BackgroundTransparency = 0.1
            dropdownFrame.BorderSizePixel = 0
            dropdownFrame.Visible = false
            dropdownFrame.ZIndex = 13
            dropdownFrame.ClipsDescendants = true
            local dropdownFrameCorner = Instance.new("UICorner")
            dropdownFrameCorner.CornerRadius = UDim.new(0, 8)
            dropdownFrameCorner.Parent = dropdownFrame

            local dropdownUIL = Instance.new("UIListLayout")
            dropdownUIL.FillDirection = Enum.FillDirection.Vertical
            dropdownUIL.Padding = UDim.new(0, 5)
            dropdownUIL.Parent = dropdownFrame

            for _, item in pairs(items) do
                local itemButton = Instance.new("TextButton")
                itemButton.Size = UDim2.new(1, 0, 0, 35)
                itemButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                itemButton.BackgroundTransparency = 0.3
                itemButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                itemButton.TextScaled = true
                itemButton.Font = Enum.Font.Gotham
                itemButton.Text = item
                itemButton.ZIndex = 14
                local itemCorner = Instance.new("UICorner")
                itemCorner.CornerRadius = UDim.new(0, 8)
                itemCorner.Parent = itemButton
                itemButton.Parent = dropdownFrame
                itemButton.MouseButton1Click:Connect(function()
                    callback(item)
                    dropdownFrame.Visible = false
                    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollUIL.AbsoluteContentSize.Y + 30)
                end)
            end

            dropdown.MouseButton1Click:Connect(function()
                dropdownFrame.Visible = not dropdownFrame.Visible
                dropdownFrame.Size = dropdownFrame.Visible and UDim2.new(0.95, 0, 0, #items * 40) or UDim2.new(0.95, 0, 0, 0)
                scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollUIL.AbsoluteContentSize.Y + 30)
            end)

            return dropdown, dropdownFrame
        end

        local function createCategory(titleText, buttons, parent)
            local categoryFrame = Instance.new("Frame")
            categoryFrame.Size = UDim2.new(0.95, 0, 0, 40)
            categoryFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            categoryFrame.BackgroundTransparency = 0.2
            categoryFrame.BorderSizePixel = 0
            categoryFrame.ZIndex = 11
            local categoryCorner = Instance.new("UICorner")
            categoryCorner.CornerRadius = UDim.new(0, 8)
            categoryCorner.Parent = categoryFrame
            categoryFrame.Parent = parent

            local categoryTitle = Instance.new("TextButton")
            categoryTitle.Size = UDim2.new(1, 0, 0, 40)
            categoryTitle.BackgroundTransparency = 1
            categoryTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
            categoryTitle.TextScaled = true
            categoryTitle.Font = Enum.Font.GothamBold
            categoryTitle.Text = titleText .. " ▼"
            categoryTitle.ZIndex = 12
            categoryTitle.Parent = categoryFrame

            local buttonFrame = Instance.new("Frame")
            buttonFrame.Size = UDim2.new(0.95, 0, 0, 0)
            buttonFrame.Position = UDim2.new(0.025, 0, 0, 45)
            buttonFrame.BackgroundTransparency = 1
            buttonFrame.ZIndex = 12
            buttonFrame.ClipsDescendants = true
            buttonFrame.Visible = true
            buttonFrame.Parent = categoryFrame

            local buttonUIL = Instance.new("UIListLayout")
            buttonUIL.FillDirection = Enum.FillDirection.Vertical
            buttonUIL.Padding = UDim.new(0, 8)
            buttonUIL.Parent = buttonFrame

            local buttonPadding = Instance.new("UIPadding")
            buttonPadding.PaddingTop = UDim.new(0, 5)
            buttonPadding.PaddingBottom = UDim.new(0, 5)
            buttonPadding.Parent = buttonFrame

            for _, button in pairs(buttons) do
                button.Parent = buttonFrame
            end

            local function updateCategory()
                buttonFrame.Size = buttonFrame.Visible and UDim2.new(0.95, 0, 0, buttonUIL.AbsoluteContentSize.Y + 10) or UDim2.new(0.95, 0, 0, 0)
                categoryTitle.Text = titleText .. (buttonFrame.Visible and " ▼" or " ►")
                scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollUIL.AbsoluteContentSize.Y + 30)
            end

            categoryTitle.MouseButton1Click:Connect(function()
                buttonFrame.Visible = not buttonFrame.Visible
                updateCategory()
            end)

            buttonUIL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCategory)
            updateCategory()

            return categoryFrame
        end

        local categories = {
            {
                name = "Movement",
                buttons = {
                    createButton("Toggle Fly", toggleFly, function() return flying end),
                    createButton("Toggle Noclip", toggleNoclip, function() return noclip end),
                    createButton("Toggle Speed", toggleSpeed, function() return speedEnabled end),
                    createButton("Toggle Jump", toggleJump, function() return jumpEnabled end),
                    createButton("Toggle Water Walk", toggleWaterWalk, function() return waterWalk end),
                    createButton("Toggle Rocket", toggleRocket, function() return rocket end),
                    createButton("Toggle Spin", toggleSpin, function() return spin end),
                    createButton("Toggle God Mode", toggleGodMode, function() return godMode end)
                }
            },
            {
                name = "Visual",
                buttons = {
                    createButton("Toggle Freecam", toggleFreecam, function() return freecam end),
                    createButton("Return to Character", returnToCharacter, function() return false end),
                    createButton("Cancel Freecam", cancelFreecam, function() return false end),
                    createButton("Teleport Character to Camera", teleportCharacterToCamera, function() return false end),
                    createButton("Toggle Hide Nickname", toggleHideNick, function() return nickHidden end),
                    createButton("Toggle Random Nickname", toggleRandomNick, function() return randomNick end),
                    createButton("Set Custom Nickname", setCustomNick, function() return false end)
                }
            },
            {
                name = "Teleport",
                buttons = {
                    createButton("Save Position", savePosition, function() return false end),
                    createButton("Teleport to Spawn", teleportToSpawn, function() return false end)
                }
            },
            {
                name = "Macro",
                buttons = {
                    createButton("Toggle Record Macro", toggleRecordMacro, function() return macroRecording end),
                    createButton("Mark Successful Run", markSuccessfulRun, function() return false end),
                    createButton("Toggle Play Macro", togglePlayMacro, function() return macroPlaying end),
                    createButton("Toggle Auto Play Macro on Respawn", toggleAutoPlayOnRespawn, function() return autoPlayOnRespawn end),
                    createButton("Toggle Record Macro on Respawn", toggleRecordOnRespawn, function() return recordOnRespawn end)
                }
            }
        }

        -- Add saved position buttons dynamically
        for slot = 1, maxSlots do
            if savedPositions[slot] then
                table.insert(categories[3].buttons, createButton("Save " .. savedPositions[slot].name, function() savePosition(slot) end, function() return false end, slot, true))
                table.insert(categories[3].buttons, createButton("Load " .. savedPositions[slot].name, function() loadPosition(slot) end, function() return false end, slot, false))
            end
        end

        local playerDropdown, playerDropdownFrame = createDropdown("Select Player", {}, function(name)
            selectedPlayer = Players:FindFirstChild(name)
            notify("👤 Selected Player: " .. name)
        end)
        table.insert(categories[3].buttons, 1, playerDropdown)
        table.insert(categories[3].buttons, 2, createButton("Teleport to Player", teleportToPlayer, function() return false end))
        table.insert(categories[3].buttons, 3, playerDropdownFrame)

        for _, category in pairs(categories) do
            createCategory(category.name, category.buttons, scrollFrame)
        end

        scrollUIL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollUIL.AbsoluteContentSize.Y + 30)
        end)
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollUIL.AbsoluteContentSize.Y + 30)

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
        UserInputService.InputChanged:Connect(function()
            if dragInput and dragging then
                updateDrag(dragInput)
            end
        end)

        local function updatePlayerDropdown()
            local playerNames = {}
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= player then
                    table.insert(playerNames, p.Name)
                end
            end
            playerDropdownFrame:ClearAllChildren()
            local dropdownUIL = Instance.new("UIListLayout")
            dropdownUIL.FillDirection = Enum.FillDirection.Vertical
            dropdownUIL.Padding = UDim.new(0, 5)
            dropdownUIL.Parent = playerDropdownFrame
            for _, item in pairs(playerNames) do
                local itemButton = Instance.new("TextButton")
                itemButton.Size = UDim2.new(1, 0, 0, 35)
                itemButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                itemButton.BackgroundTransparency = 0.3
                itemButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                itemButton.TextScaled = true
                itemButton.Font = Enum.Font.Gotham
                itemButton.Text = item
                itemButton.ZIndex = 14
                local itemCorner = Instance.new("UICorner")
                itemCorner.CornerRadius = UDim.new(0, 8)
                itemCorner.Parent = itemButton
                itemButton.Parent = playerDropdownFrame
                itemButton.MouseButton1Click:Connect(function()
                    selectedPlayer = Players:FindFirstChild(item)
                    notify("👤 Selected Player: " .. item)
                    playerDropdownFrame.Visible = false
                    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollUIL.AbsoluteContentSize.Y + 30)
                end)
            end
            playerDropdown.MouseButton1Click:Connect(function()
                playerDropdownFrame.Visible = not playerDropdownFrame.Visible
                playerDropdownFrame.Size = playerDropdownFrame.Visible and UDim2.new(0.95, 0, 0, #playerNames * 40) or UDim2.new(0.95, 0, 0, 0)
                scrollFrame.CanvasSize = UDim2.new(0, 0, 0, scrollUIL.AbsoluteContentSize.Y + 30)
            end)
        end

        Players.PlayerAdded:Connect(updatePlayerDropdown)
        Players.PlayerRemoving:Connect(updatePlayerDropdown)
        updatePlayerDropdown()
    end)
    if not success then
        notify("⚠️ GUI creation failed: " .. tostring(errorMsg) .. ", retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(2)
        createGUI()
    end

    main()