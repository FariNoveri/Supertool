-- Visual.lua
-- Visual features for MinimalHackGUI by Fari Noveri

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Visual feature variables
local fullbrightEnabled = false
local freecamEnabled = false
local flashlightEnabled = false
local lowDetailEnabled = false

-- Settings for visual features
local settings = {
    FlashlightBrightness = { value = 5, default = 5, min = 1, max = 10 },
    FlashlightRange = { value = 100, default = 100, min = 50, max = 200 },
    FullbrightBrightness = { value = 2, default = 2, min = 0, max = 5 },
    FreecamSpeed = { value = 80, default = 80, min = 20, max = 300 }
}

-- Connections table for visual features
local connections = {}

-- Button states for toggles
local buttonStates = {
    Fullbright = false,
    Freecam = false,
    Flashlight = false,
    ["Low Detail"] = false
}

-- Visual Functions

-- Flashlight
local flashlightPart = nil
local function toggleFlashlight(enabled)
    flashlightEnabled = enabled
    if enabled then
        if character and character:FindFirstChild("Head") then
            flashlightPart = Instance.new("PointLight")
            flashlightPart.Name = "Flashlight"
            flashlightPart.Brightness = settings.FlashlightBrightness.value
            flashlightPart.Range = settings.FlashlightRange.value
            flashlightPart.Color = Color3.fromRGB(255, 255, 255)
            flashlightPart.Parent = character.Head
        end
    else
        if flashlightPart then
            flashlightPart:Destroy()
            flashlightPart = nil
        elseif character and character:FindFirstChild("Head") and character.Head:FindFirstChild("Flashlight") then
            character.Head.Flashlight:Destroy()
        end
    end
end

-- Fullbright
local function toggleFullbright(enabled)
    fullbrightEnabled = enabled
    if enabled then
        Lighting.Brightness = settings.FullbrightBrightness.value
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    else
        Lighting.Brightness = 1
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = true
        Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 70)
    end
end

-- Freecam
local freecamPart = nil
local originalCameraSubject = nil
local freecamPosition = nil
local yaw = 0
local pitch = 0
local function toggleFreecam(enabled)
    freecamEnabled = enabled
    if enabled then
        originalCameraSubject = Workspace.CurrentCamera.CameraSubject
        
        if character and rootPart then
            freecamPosition = rootPart.Position
        else
            freecamPosition = Workspace.CurrentCamera.CFrame.Position
        end
        
        freecamPart = Instance.new("Part")
        freecamPart.Name = "FreecamPart"
        freecamPart.Anchored = true
        freecamPart.CanCollide = false
        freecamPart.Transparency = 1
        freecamPart.Size = Vector3.new(1, 1, 1)
        freecamPart.CFrame = CFrame.new(freecamPosition, freecamPosition + Workspace.CurrentCamera.CFrame.LookVector)
        freecamPart.Parent = Workspace
        
        Workspace.CurrentCamera.CameraSubject = freecamPart
        
        local lookVector = Workspace.CurrentCamera.CFrame.LookVector
        yaw = math.atan2(-lookVector.X, -lookVector.Z)
        pitch = math.asin(lookVector.Y)
        
        if rootPart then
            rootPart.Anchored = true
        end
        
        connections.freecam_input = UserInputService.InputChanged:Connect(function(input)
            if freecamEnabled and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
                local delta = input.Delta
                local sensitivity = 0.005
                
                yaw = yaw - delta.X * sensitivity
                pitch = math.clamp(pitch - delta.Y * sensitivity, -math.pi/2 + 0.1, math.pi/2 - 0.1)
                
                local rotationCFrame = CFrame.new(Vector3.new(0, 0, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
                freecamPart.CFrame = CFrame.new(freecamPart.Position) * rotationCFrame
            end
        end)
        
        connections.freecam = RunService.RenderStepped:Connect(function(deltaTime)
            if freecamEnabled and freecamPart then
                local camera = Workspace.CurrentCamera
                local moveVector = humanoid.MoveDirection
                
                local cameraCFrame = freecamPart.CFrame
                local forwardVector = cameraCFrame.LookVector
                local rightVector = cameraCFrame.RightVector
                local upVector = Vector3.new(0, 1, 0)
                
                local movement = Vector3.new(0, 0, 0)
                local speed = settings.FreecamSpeed.value
                
                if moveVector.Magnitude > 0 then
                    movement = movement + (forwardVector * -moveVector.Z * speed)
                    movement = movement + (rightVector * moveVector.X * speed)
                end
                
                if humanoid.Jump then
                    movement = movement + (upVector * speed)
                    humanoid.Jump = false
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                    movement = movement + (upVector * -speed)
                end
                
                local newPosition = freecamPart.Position + (movement * deltaTime)
                
                freecamPart.CFrame = CFrame.new(newPosition) * freecamPart.CFrame.Rotation
                freecamPosition = newPosition
                
                camera.CFrame = freecamPart.CFrame
            end
        end)
        
    else
        if connections.freecam then
            connections.freecam:Disconnect()
            connections.freecam = nil
        end
        if connections.freecam_input then
            connections.freecam_input:Disconnect()
            connections.freecam_input = nil
        end
        if freecamPart then
            freecamPart:Destroy()
            freecamPart = nil
        end
        
        if character and humanoid then
            Workspace.CurrentCamera.CameraSubject = humanoid
            if rootPart then
                Workspace.CurrentCamera.CFrame = CFrame.new(rootPart.Position + Vector3.new(0, 2, 0), rootPart.Position)
            end
        elseif originalCameraSubject then
            Workspace.CurrentCamera.CameraSubject = originalCameraSubject
        end
        
        if rootPart then
            rootPart.Anchored = false
        end
        
        freecamPosition = nil
        yaw = 0
        pitch = 0
    end
end

-- Low Detail Mode
local lowDetailSettings = {}
local function toggleLowDetail(enabled)
    lowDetailEnabled = enabled
    if enabled then
        lowDetailSettings = {
            GlobalShadows = Lighting.GlobalShadows,
            ShadowSoftness = Lighting.ShadowSoftness,
            FogEnd = Lighting.FogEnd,
            EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
            EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
        }
        
        Lighting.GlobalShadows = false
        Lighting.ShadowSoftness = 0
        Lighting.FogEnd = 100000
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
        
        for _, descendant in pairs(Workspace:GetDescendants()) do
            if descendant:IsA("BasePart") then
                descendant.Material = Enum.Material.SmoothPlastic
                if descendant:IsA("MeshPart") then
                    descendant.TextureID = ""
                end
            elseif descendant:IsA("Decal") then
                descendant.Transparency = 1
            elseif descendant:IsA("ParticleEmitter") then
                descendant.Enabled = false
            end
        end
    else
        if lowDetailSettings.GlobalShadows ~= nil then
            Lighting.GlobalShadows = lowDetailSettings.GlobalShadows
            Lighting.ShadowSoftness = lowDetailSettings.ShadowSoftness
            Lighting.FogEnd = lowDetailSettings.FogEnd
            Lighting.EnvironmentDiffuseScale = lowDetailSettings.EnvironmentDiffuseScale
            Lighting.EnvironmentSpecularScale = lowDetailSettings.EnvironmentSpecularScale
        end
        
        for _, descendant in pairs(Workspace:GetDescendants()) do
            if descendant:IsA("BasePart") then
                descendant.Material = Enum.Material.Plastic
            elseif descendant:IsA("Decal") then
                descendant.Transparency = 0
            elseif descendant:IsA("ParticleEmitter") then
                descendant.Enabled = true
            end
        end
    end
end

-- Cleanup function
local function cleanup()
    toggleFullbright(false)
    toggleFreecam(false)
    toggleFlashlight(false)
    toggleLowDetail(false)
    
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    connections = {}
end

-- Handle character reset
local characterConnection
characterConnection = player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    
    fullbrightEnabled = false
    freecamEnabled = false
    flashlightEnabled = false
    lowDetailEnabled = false
    
    toggleFullbright(false)
    toggleFreecam(false)
    toggleFlashlight(false)
    toggleLowDetail(false)
    
    buttonStates["Fullbright"] = false
    buttonStates["Freecam"] = false
    buttonStates["Flashlight"] = false
    buttonStates["Low Detail"] = false
end)

-- Load buttons for mainloader.lua
local function loadButtons(scrollFrame, utils)
    utils.createToggleButton("Fullbright", function(state)
        buttonStates["Fullbright"] = state
        toggleFullbright(state)
        if utils.notify then
            utils.notify("Fullbright: " .. (state and "ON" or "OFF"))
        end
    end).Parent = scrollFrame

    utils.createToggleButton("Freecam", function(state)
        buttonStates["Freecam"] = state
        toggleFreecam(state)
        if utils.notify then
            utils.notify("Freecam: " .. (state and "ON" or "OFF"))
        end
    end).Parent = scrollFrame

    utils.createToggleButton("Flashlight", function(state)
        buttonStates["Flashlight"] = state
        toggleFlashlight(state)
        if utils.notify then
            utils.notify("Flashlight: " .. (state and "ON" or "OFF"))
        end
    end).Parent = scrollFrame

    utils.createToggleButton("Low Detail", function(state)
        buttonStates["Low Detail"] = state
        toggleLowDetail(state)
        if utils.notify then
            utils.notify("Low Detail: " .. (state and "ON" or "OFF"))
        end
    end).Parent = scrollFrame

    -- Setting inputs
    for settingName, settingData in pairs(settings) do
        local settingFrame = Instance.new("Frame")
        settingFrame.Name = settingName .. "SettingFrame"
        settingFrame.Parent = scrollFrame
        settingFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        settingFrame.BorderSizePixel = 0
        settingFrame.Size = UDim2.new(1, 0, 0, 60)
        
        local label = Instance.new("TextLabel")
        label.Name = "SettingLabel"
        label.Parent = settingFrame
        label.BackgroundTransparency = 1
        label.Position = UDim2.new(0, 5, 0, 5)
        label.Size = UDim2.new(1, -10, 0, 20)
        label.Font = Enum.Font.Gotham
        label.Text = string.format("%s (Default: %d, Min: %d, Max: %d)", settingName, settingData.default, settingData.min, settingData.max)
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        
        local input = Instance.new("TextBox")
        input.Name = settingName .. "Input"
        input.Parent = settingFrame
        input.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        input.BorderSizePixel = 0
        input.Position = UDim2.new(0, 5, 0, 30)
        input.Size = UDim2.new(1, -10, 0, 25)
        input.Font = Enum.Font.Gotham
        input.Text = tostring(settingData.value)
        input.TextColor3 = Color3.fromRGB(255, 255, 255)
        input.TextSize = 11
        input.PlaceholderText = "Enter value..."
        
        input.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local value = tonumber(input.Text)
                if value then
                    value = math.clamp(value, settingData.min, settingData.max)
                    settingData.value = value
                    input.Text = tostring(value)
                    if utils.notify then
                        utils.notify(string.format("%s set to %d", settingName, value))
                    end
                    
                    if settingName == "Freecam Speed" and freecamEnabled then
                        toggleFreecam(false)
                        toggleFreecam(true)
                    elseif settingName == "Flashlight Brightness" and flashlightEnabled then
                        toggleFlashlight(false)
                        toggleFlashlight(true)
                    elseif settingName == "Flashlight Range" and flashlightEnabled then
                        toggleFlashlight(false)
                        toggleFlashlight(true)
                    elseif settingName == "Fullbright Brightness" and fullbrightEnabled then
                        toggleFullbright(false)
                        toggleFullbright(true)
                    end
                else
                    input.Text = tostring(settingData.value)
                    if utils.notify then
                        utils.notify(string.format("Invalid input for %s, reverting to %d", settingName, settingData.value))
                    end
                end
            end
        end)
    end
end

-- Cleanup on script destruction
local function onScriptDestroy()
    cleanup()
    if characterConnection then
        characterConnection:Disconnect()
        characterConnection = nil
    end
end

-- Connect cleanup to GUI destruction
local screenGui = game:GetService("CoreGui"):FindFirstChild("MinimalHackGUI")
if screenGui then
    screenGui.AncestryChanged:Connect(function(_, parent)
        if not parent then
            onScriptDestroy()
        end
    end)
end

-- Return module
return {
    loadButtons = loadButtons,
    cleanup = cleanup,
    reset = cleanup -- For character reset in mainloader.lua
}