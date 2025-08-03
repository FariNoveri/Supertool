local Roact = require(game:GetService("ReplicatedStorage"):WaitForChild("Roact"))
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid, hr, char
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
        notif.Parent = player:WaitForChild("PlayerGui")
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
    local joystickFrame = Instance.new("Frame")
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
    joystickFrame.Parent = player:WaitForChild("PlayerGui")

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

    local cameraControlFrame = Instance.new("Frame")
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
    cameraControlFrame.Parent = player:WaitForChild("PlayerGui")

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

    return joystickFrame, cameraControlFrame
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
            local joystickFrame, cameraControlFrame = createJoystick()
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
            local joystickFrame, cameraControlFrame = createJoystick()
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
        local joystickFrame, cameraControlFrame = createJoystick()
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
            local joystickFrame, cameraControlFrame = createJoystick()
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
            local joystickFrame, cameraControlFrame = createJoystick()
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
        local joystickFrame, cameraControlFrame = createJoystick()
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

-- Roact Components
local Button = Roact.Component:extend("Button")
function Button:init()
    self:setState({
        isPressed = false,
        holdStart = nil
    })
end

function Button:render()
    local props = self.props
    local isToggled = props.toggleState and props.toggleState() or false
    return Roact.createElement("TextButton", {
        Size = UDim2.new(0.95, 0, 0, 40),
        Position = UDim2.new(0.025, 0, 0, 0),
        BackgroundColor3 = isToggled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50),
        BackgroundTransparency = 0.3,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextScaled = true,
        Font = Enum.Font.Gotham,
        Text = props.text,
        ZIndex = 12,
        [Roact.Event.InputBegan] = function(rbx, input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                self:setState({ holdStart = tick() })
            end
        end,
        [Roact.Event.InputEnded] = function(rbx, input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if self.state.holdStart and tick() - self.state.holdStart >= 2 and props.slot then
                    props.onRename(props.slot, props.isSave)
                else
                    local success, err = pcall(props.onClick)
                    if not success then
                        notify("⚠️ Error in " .. props.text .. ": " .. tostring(err), Color3.fromRGB(255, 100, 100))
                    end
                end
                self:setState({ holdStart = nil })
            end
        end
    }, {
        Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 8) })
    })
end

local Dropdown = Roact.Component:extend("Dropdown")
function Dropdown:init()
    self:setState({
        isOpen = false
    })
end

function Dropdown:render()
    local props = self.props
    local items = props.items
    return Roact.createElement("Frame", {
        Size = UDim2.new(0.95, 0, 0, self.state.isOpen and (#items * 40 + 40) or 40),
        Position = UDim2.new(0.025, 0, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 12
    }, {
        Button = Roact.createElement("TextButton", {
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = Color3.fromRGB(50, 50, 50),
            BackgroundTransparency = 0.3,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextScaled = true,
            Font = Enum.Font.Gotham,
            Text = props.text,
            ZIndex = 12,
            [Roact.Event.MouseButton1Click] = function()
                self:setState({ isOpen = not self.state.isOpen })
                props.onToggle(self.state.isOpen)
            end
        }, {
            Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 8) })
        }),
        ItemFrame = self.state.isOpen and Roact.createElement("Frame", {
            Size = UDim2.new(0.95, 0, 0, #items * 40),
            Position = UDim2.new(0.025, 0, 0, 45),
            BackgroundColor3 = Color3.fromRGB(20, 20, 20),
            BackgroundTransparency = 0.1,
            BorderSizePixel = 0,
            ZIndex = 13,
            ClipsDescendants = true
        }, {
            UIL = Roact.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 5)
            }),
            Items = Roact.createFragment(table.map(items, function(item, index)
                return Roact.createElement("TextButton", {
                    Size = UDim2.new(1, 0, 0, 35),
                    BackgroundColor3 = Color3.fromRGB(50, 50, 50),
                    BackgroundTransparency = 0.3,
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextScaled = true,
                    Font = Enum.Font.Gotham,
                    Text = item,
                    ZIndex = 14,
                    [Roact.Event.MouseButton1Click] = function()
                        props.onSelect(item)
                        self:setState({ isOpen = false })
                        props.onToggle(false)
                    end
                }, {
                    Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 8) })
                })
            end))
        })
    })
end

local Category = Roact.Component:extend("Category")
function Category:init()
    self:setState({
        isOpen = true
    })
end

function Category:render()
    local props = self.props
    return Roact.createElement("Frame", {
        Size = UDim2.new(0.95, 0, 0, self.state.isOpen and (40 + #props.buttons * 48) or 40),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        ZIndex = 11
    }, {
        Title = Roact.createElement("TextButton", {
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextScaled = true,
            Font = Enum.Font.GothamBold,
            Text = props.title .. (self.state.isOpen and " ▼" or " ►"),
            ZIndex = 12,
            [Roact.Event.MouseButton1Click] = function()
                self:setState({ isOpen = not self.state.isOpen })
                props.onToggle(self.state.isOpen)
            end
        }, {
            Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 8) })
        }),
        ButtonFrame = self.state.isOpen and Roact.createElement("Frame", {
            Size = UDim2.new(0.95, 0, 0, #props.buttons * 48),
            Position = UDim2.new(0.025, 0, 0, 45),
            BackgroundTransparency = 1,
            ZIndex = 12,
            ClipsDescendants = true
        }, {
            UIL = Roact.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 8)
            }),
            Padding = Roact.createElement("UIPadding", {
                PaddingTop = UDim.new(0, 5),
                PaddingBottom = UDim.new(0, 5)
            }),
            Buttons = Roact.createFragment(props.buttons)
        })
    })
end

local MainUI = Roact.Component:extend("MainUI")
function MainUI:init()
    self:setState({
        isVisible = false,
        players = {},
        selectedSlot = nil,
        renameText = "",
        canvasSize = 0
    })
    self.scrollFrameRef = Roact.createRef()
end

function MainUI:didMount()
    local function updatePlayers()
        local playerNames = {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player then
                table.insert(playerNames, p.Name)
            end
        end
        self:setState({ players = playerNames })
    end
    updatePlayers()
    connections.playerAdded = Players.PlayerAdded:Connect(updatePlayers)
    connections.playerRemoving = Players.PlayerRemoving:Connect(updatePlayers)
end

function MainUI:willUnmount()
    if connections.playerAdded then
        connections.playerAdded:Disconnect()
        connections.playerAdded = nil
    end
    if connections.playerRemoving then
        connections.playerRemoving:Disconnect()
        connections.playerRemoving = nil
    end
end

function MainUI:render()
    local function updateCanvasSize(isOpen)
        local scrollFrame = self.scrollFrameRef.current
        if scrollFrame then
            local uil = scrollFrame:FindFirstChildOfClass("UIListLayout")
            if uil then
                self:setState({ canvasSize = uil.AbsoluteContentSize.Y + 30 })
            end
        end
    end

    local buttons = {
        Movement = {
            Roact.createElement(Button, { text = "Toggle Fly", onClick = toggleFly, toggleState = function() return flying end }),
            Roact.createElement(Button, { text = "Toggle Noclip", onClick = toggleNoclip, toggleState = function() return noclip end }),
            Roact.createElement(Button, { text = "Toggle Speed", onClick = toggleSpeed, toggleState = function() return speedEnabled end }),
            Roact.createElement(Button, { text = "Toggle Jump", onClick = toggleJump, toggleState = function() return jumpEnabled end }),
            Roact.createElement(Button, { text = "Toggle Water Walk", onClick = toggleWaterWalk, toggleState = function() return waterWalk end }),
            Roact.createElement(Button, { text = "Toggle Rocket", onClick = toggleRocket, toggleState = function() return rocket end }),
            Roact.createElement(Button, { text = "Toggle Spin", onClick = toggleSpin, toggleState = function() return spin end }),
            Roact.createElement(Button, { text = "Toggle God Mode", onClick = toggleGodMode, toggleState = function() return godMode end })
        },
        Visual = {
            Roact.createElement(Button, { text = "Toggle Freecam", onClick = toggleFreecam, toggleState = function() return freecam end }),
            Roact.createElement(Button, { text = "Return to Character", onClick = returnToCharacter, toggleState = function() return false end }),
            Roact.createElement(Button, { text = "Cancel Freecam", onClick = cancelFreecam, toggleState = function() return false end }),
            Roact.createElement(Button, { text = "Teleport Character to Camera", onClick = teleportCharacterToCamera, toggleState = function() return false end }),
            Roact.createElement(Button, { text = "Toggle Hide Nickname", onClick = toggleHideNick, toggleState = function() return nickHidden end }),
            Roact.createElement(Button, { text = "Toggle Random Nickname", onClick = toggleRandomNick, toggleState = function() return randomNick end }),
            Roact.createElement(Button, { text = "Set Custom Nickname", onClick = setCustomNick, toggleState = function() return false end })
        },
        Teleport = {
            Roact.createElement(Dropdown, {
                text = "Select Player",
                items = self.state.players,
                onSelect = function(name)
                    selectedPlayer = Players:FindFirstChild(name)
                    notify("👤 Selected Player: " .. name)
                end,
                onToggle = updateCanvasSize
            }),
            Roact.createElement(Button, { text = "Teleport to Player", onClick = teleportToPlayer, toggleState = function() return false end }),
            Roact.createElement(Button, { text = "Save Position", onClick = savePosition, toggleState = function() return false end }),
            Roact.createElement(Button, { text = "Teleport to Spawn", onClick = teleportToSpawn, toggleState = function() return false end })
        },
        Macro = {
            Roact.createElement(Button, { text = "Toggle Record Macro", onClick = toggleRecordMacro, toggleState = function() return macroRecording end }),
            Roact.createElement(Button, { text = "Mark Successful Run", onClick = markSuccessfulRun, toggleState = function() return false end }),
            Roact.createElement(Button, { text = "Toggle Play Macro", onClick = togglePlayMacro, toggleState = function() return macroPlaying end }),
            Roact.createElement(Button, { text = "Toggle Auto Play Macro on Respawn", onClick = toggleAutoPlayOnRespawn, toggleState = function() return autoPlayOnRespawn end }),
            Roact.createElement(Button, { text = "Toggle Record Macro on Respawn", onClick = toggleRecordOnRespawn, toggleState = function() return recordOnRespawn end })
        }
    }

    for slot = 1, maxSlots do
        if savedPositions[slot] then
            table.insert(buttons.Teleport, Roact.createElement(Button, {
                text = "Save " .. savedPositions[slot].name,
                onClick = savePosition,
                toggleState = function() return false end,
                slot = slot,
                isSave = true,
                onRename = function(slot, isSave)
                    self:setState({ selectedSlot = slot, renameText = savedPositions[slot].name })
                end
            }))
            table.insert(buttons.Teleport, Roact.createElement(Button, {
                text = "Load " .. savedPositions[slot].name,
                onClick = function() loadPosition(slot) end,
                toggleState = function() return false end,
                slot = slot,
                isSave = false,
                onRename = function(slot, isSave)
                    self:setState({ selectedSlot = slot, renameText = savedPositions[slot].name })
                end
            }))
        end
    end

    return Roact.createElement("ScreenGui", {
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    }, {
        Scale = Roact.createElement("UIScale", {
            Scale = math.min(1, math.min(camera.ViewportSize.X / 720, camera.ViewportSize.Y / 1280))
        }),
        Logo = Roact.createElement("ImageButton", {
            Size = UDim2.new(0, 50, 0, 50),
            Position = UDim2.new(0.95, -50, 0.05, 10),
            BackgroundColor3 = Color3.fromRGB(50, 150, 255),
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            Image = "rbxassetid://3570695787",
            ZIndex = 20,
            [Roact.Event.MouseButton1Click] = function()
                self:setState({ isVisible = not self.state.isVisible })
                notify(self.state.isVisible and "🖼️ GUI Closed" or "🖼️ GUI Opened")
            end
        }, {
            Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 8) })
        }),
        Frame = self.state.isVisible and Roact.createElement("Frame", {
            Size = UDim2.new(0, 350, 0, 500),
            Position = UDim2.new(0.5, -175, 0.5, -250),
            BackgroundColor3 = Color3.fromRGB(20, 20, 20),
            BackgroundTransparency = 0.1,
            BorderSizePixel = 0,
            ZIndex = 10,
            ClipsDescendants = true,
            [Roact.Event.InputBegan] = function(rbx, input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    self:setState({ dragging = true, dragStart = input.Position, startPos = rbx.Position })
                end
            end,
            [Roact.Event.InputEnded] = function(rbx, input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    self:setState({ dragging = false })
                end
            end,
            [Roact.Event.InputChanged] = function(rbx, input)
                if self.state.dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local delta = input.Position - self.state.dragStart
                    rbx.Position = UDim2.new(self.state.startPos.X.Scale, self.state.startPos.X.Offset + delta.X, self.state.startPos.Y.Scale, self.state.startPos.Y.Offset + delta.Y)
                end
            end
        }, {
            Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
            Title = Roact.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                BackgroundTransparency = 0.5,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                TextScaled = true,
                Font = Enum.Font.GothamBold,
                Text = "Krnl UI",
                ZIndex = 11
            }, {
                Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 8) })
            }),
            ScrollFrame = Roact.createElement("ScrollingFrame", {
                Size = UDim2.new(1, -10, 1, -50),
                Position = UDim2.new(0, 5, 0, 45),
                BackgroundTransparency = 1,
                ScrollBarThickness = 6,
                ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100),
                ZIndex = 11,
                ClipsDescendants = true,
                CanvasSize = UDim2.new(0, 0, 0, self.state.canvasSize),
                Ref = self.scrollFrameRef
            }, {
                UIL = Roact.createElement("UIListLayout", {
                    FillDirection = Enum.FillDirection.Vertical,
                    Padding = UDim.new(0, 8)
                }),
                Padding = Roact.createElement("UIPadding", {
                    PaddingTop = UDim.new(0, 5),
                    PaddingBottom = UDim.new(0, 20)
                }),
                Categories = Roact.createFragment({
                    Movement = Roact.createElement(Category, { title = "Movement", buttons = buttons.Movement, onToggle = updateCanvasSize }),
                    Visual = Roact.createElement(Category, { title = "Visual", buttons = buttons.Visual, onToggle = updateCanvasSize }),
                    Teleport = Roact.createElement(Category, { title = "Teleport", buttons = buttons.Teleport, onToggle = updateCanvasSize }),
                    Macro = Roact.createElement(Category, { title = "Macro", buttons = buttons.Macro, onToggle = updateCanvasSize })
                })
            }),
            RenameInput = self.state.selectedSlot and Roact.createElement("Frame", {
                Size = UDim2.new(0.95, 0, 0, 50),
                Position = UDim2.new(0.025, 0, 0, 0),
                BackgroundColor3 = Color3.fromRGB(30, 30, 30),
                BackgroundTransparency = 0.2,
                ZIndex = 15
            }, {
                Input = Roact.createElement("TextBox", {
                    Size = UDim2.new(0.8, -10, 0, 40),
                    Position = UDim2.new(0, 5, 0, 5),
                    BackgroundColor3 = Color3.fromRGB(50, 50, 50),
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextScaled = true,
                    Font = Enum.Font.Gotham,
                    Text = self.state.renameText,
                    ZIndex = 16,
                    [Roact.Change.Text] = function(rbx)
                        self:setState({ renameText = rbx.Text })
                    end,
                    [Roact.Event.FocusLost] = function(rbx, enterPressed)
                        if enterPressed and self.state.renameText ~= "" then
                            renamePosition(self.state.selectedSlot, self.state.renameText)
                            self:setState({ selectedSlot = nil, renameText = "" })
                        end
                    end
                }, {
                    Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 8) })
                }),
                Confirm = Roact.createElement("TextButton", {
                    Size = UDim2.new(0.2, -10, 0, 40),
                    Position = UDim2.new(0.8, 5, 0, 5),
                    BackgroundColor3 = Color3.fromRGB(0, 150, 0),
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextScaled = true,
                    Font = Enum.Font.Gotham,
                    Text = "OK",
                    ZIndex = 16,
                    [Roact.Event.MouseButton1Click] = function()
                        if self.state.renameText ~= "" then
                            renamePosition(self.state.selectedSlot, self.state.renameText)
                            self:setState({ selectedSlot = nil, renameText = "" })
                        end
                    end
                }, {
                    Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 8) })
                })
            })
        })
    })
end

-- Initialize
loadTeleportSlots()
initChar()
local handle = Roact.mount(Roact.createElement(MainUI), player:WaitForChild("PlayerGui"), "KrnlUI")
player.CharacterAdded:Connect(function()
    clearConnections()
    initChar()
end)

-- Cleanup
game:BindToClose(function()
    Roact.unmount(handle)
    clearConnections()
end)