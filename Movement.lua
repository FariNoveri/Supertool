-- Movement.lua
-- Movement features for MinimalHackGUI by Fari Noveri

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Movement feature variables
local flyEnabled = false
local noclipEnabled = false
local speedEnabled = false
local jumpHighEnabled = false
local spiderEnabled = false
local playerPhaseEnabled = false

-- Settings for movement features
local settings = {
    FlySpeed = { value = 50, default = 50, min = 10, max = 200 },
    JumpHeight = { value = 50, default = 50, min = 10, max = 150 },
    WalkSpeed = { value = 100, default = 100, min = 16, max = 300 }
}

-- Connections table for movement features
local connections = {}

-- Button states for toggles
local buttonStates = {
    Fly = false,
    Noclip = false,
    Speed = false,
    ["Jump High"] = false,
    Spider = false,
    ["Player Phase"] = false
}

-- Movement Functions

-- Fly (Android Touch Controls)
local function toggleFly(enabled)
    flyEnabled = enabled
    if enabled then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = rootPart
        
        connections.fly = RunService.Heartbeat:Connect(function()
            if flyEnabled then
                local camera = Workspace.CurrentCamera
                local moveVector = humanoid.MoveDirection
                
                local cameraCFrame = camera.CFrame
                local forwardVector = cameraCFrame.LookVector
                local rightVector = cameraCFrame.RightVector
                local upVector = Vector3.new(0, 1, 0)
                
                local velocity = Vector3.new(0, 0, 0)
                local speed = settings.FlySpeed.value
                
                if moveVector.Magnitude > 0 then
                    velocity = velocity + (forwardVector * -moveVector.Z * speed)
                    velocity = velocity + (rightVector * moveVector.X * speed)
                end
                
                if humanoid.Jump then
                    velocity = velocity + (upVector * speed)
                    humanoid.Jump = false
                end
                
                bodyVelocity.Velocity = velocity
            end
        end)
    else
        if connections.fly then
            connections.fly:Disconnect()
        end
        if rootPart:FindFirstChild("BodyVelocity") then
            rootPart:FindFirstChild("BodyVelocity"):Destroy()
        end
    end
end

-- Noclip
local function toggleNoclip(enabled)
    noclipEnabled = enabled
    if enabled then
        connections.noclip = RunService.Stepped:Connect(function()
            if noclipEnabled and character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if connections.noclip then
            connections.noclip:Disconnect()
        end
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- Speed
local function toggleSpeed(enabled)
    speedEnabled = enabled
    if enabled then
        humanoid.WalkSpeed = settings.WalkSpeed.value
    else
        humanoid.WalkSpeed = 16
    end
end

-- Jump High
local function toggleJumpHigh(enabled)
    jumpHighEnabled = enabled
    if enabled then
        humanoid.JumpHeight = settings.JumpHeight.value
        humanoid.JumpPower = settings.JumpHeight.value * 2.4
        connections.jumphigh = humanoid.Jumping:Connect(function()
            if jumpHighEnabled then
                rootPart.Velocity = Vector3.new(rootPart.Velocity.X, settings.JumpHeight.value * 2.4, rootPart.Velocity.Z)
            end
        end)
    else
        humanoid.JumpHeight = 7.2
        humanoid.JumpPower = 50
        if connections.jumphigh then
            connections.jumphigh:Disconnect()
        end
    end
end

-- Spider (stick to walls)
local function toggleSpider(enabled)
    spiderEnabled = enabled
    if enabled then
        local bodyPosition = Instance.new("BodyPosition")
        bodyPosition.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyPosition.Position = rootPart.Position
        bodyPosition.Parent = rootPart
        
        local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
        bodyAngularVelocity.MaxTorque = Vector3.new(4000, 4000, 4000)
        bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
        bodyAngularVelocity.Parent = rootPart
        
        connections.spider = RunService.Heartbeat:Connect(function()
            if spiderEnabled and rootPart then
                local ray = Workspace:Raycast(rootPart.Position, rootPart.CFrame.LookVector * 10)
                if ray then
                    bodyPosition.Position = ray.Position + ray.Normal * 3
                    local lookDirection = -ray.Normal
                    bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
                    rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + lookDirection)
                end
            end
        end)
    else
        if connections.spider then
            connections.spider:Disconnect()
        end
        if rootPart:FindFirstChild("BodyPosition") then
            rootPart:FindFirstChild("BodyPosition"):Destroy()
        end
        if rootPart:FindFirstChild("BodyAngularVelocity") then
            rootPart:FindFirstChild("BodyAngularVelocity"):Destroy()
        end
    end
end

-- Player Phase (pass through other players)
local function togglePlayerPhase(enabled)
    playerPhaseEnabled = enabled
    if enabled then
        connections.playerphase = RunService.Heartbeat:Connect(function()
            if playerPhaseEnabled and character then
                for _, otherPlayer in pairs(Players:GetPlayers()) do
                    if otherPlayer ~= player and otherPlayer.Character then
                        for _, part in pairs(otherPlayer.Character:GetChildren()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                            end
                        end
                    end
                end
            end
        end)
    else
        if connections.playerphase then
            connections.playerphase:Disconnect()
        end
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= player and otherPlayer.Character then
                for _, part in pairs(otherPlayer.Character:GetChildren()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end
    end
end

-- Function to create toggle buttons for movement features
local function createToggleButton(name, callback)
    local button = Instance.new("TextButton")
    button.Name = name .. "Button"
    button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 30)
    button.Font = Enum.Font.Gotham
    button.Text = name:upper() .. (buttonStates[name] and " [ON]" or " [OFF]")
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 11
    
    button.MouseButton1Click:Connect(function()
        buttonStates[name] = not buttonStates[name]
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(25, 25, 25)
        button.Text = name:upper() .. (buttonStates[name] and " [ON]" or " [OFF]")
        callback(buttonStates[name])
    end)
    
    button.MouseEnter:Connect(function()
        if not buttonStates[name] then
            button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = buttonStates[name] and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(25, 25, 25)
    end)
    
    return button
end

-- Function to create setting inputs for movement-related settings
local function createSettingInput(settingName, settingData)
    local settingFrame = Instance.new("Frame")
    settingFrame.Name = settingName .. "SettingFrame"
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
                print(string.format("%s set to %d", settingName, value))
                
                if settingName == "Fly Speed" and flyEnabled then
                    toggleFly(false)
                    toggleFly(true)
                elseif settingName == "Jump Height" and jumpHighEnabled then
                    toggleJumpHigh(false)
                    toggleJumpHigh(true)
                elseif settingName == "Walk Speed" and speedEnabled then
                    toggleSpeed(false)
                    toggleSpeed(true)
                end
            else
                input.Text = tostring(settingData.value)
                print(string.format("Invalid input for %s, reverting to %d", settingName, settingData.value))
            end
        end
    end)
    
    return settingFrame
end

-- Function to load movement buttons into a provided ScrollFrame
local function loadMovementButtons(scrollFrame)
    createToggleButton("Fly", toggleFly).Parent = scrollFrame
    createToggleButton("Noclip", toggleNoclip).Parent = scrollFrame
    createToggleButton("Speed", toggleSpeed).Parent = scrollFrame
    createToggleButton("Jump High", toggleJumpHigh).Parent = scrollFrame
    createToggleButton("Spider", toggleSpider).Parent = scrollFrame
    createToggleButton("Player Phase", togglePlayerPhase).Parent = scrollFrame
end

-- Function to load movement settings into a provided ScrollFrame
local function loadMovementSettings(scrollFrame)
    createSettingInput("Fly Speed", settings.FlySpeed).Parent = scrollFrame
    createSettingInput("Jump Height", settings.JumpHeight).Parent = scrollFrame
    createSettingInput("Walk Speed", settings.WalkSpeed).Parent = scrollFrame
end

-- Handle character reset
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Reset movement features
    flyEnabled = false
    noclipEnabled = false
    speedEnabled = false
    jumpHighEnabled = false
    spiderEnabled = false
    playerPhaseEnabled = false
    
    toggleFly(false)
    toggleNoclip(false)
    toggleSpeed(false)
    toggleJumpHigh(false)
    toggleSpider(false)
    togglePlayerPhase(false)
    
    buttonStates["Fly"] = false
    buttonStates["Noclip"] = false
    buttonStates["Speed"] = false
    buttonStates["Jump High"] = false
    buttonStates["Spider"] = false
    buttonStates["Player Phase"] = false
end)

-- Cleanup function
local function cleanup()
    toggleFly(false)
    toggleNoclip(false)
    toggleSpeed(false)
    toggleJumpHigh(false)
    toggleSpider(false)
    togglePlayerPhase(false)
    
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
end

-- Bind cleanup to game close
game:BindToClose(cleanup)

-- Return functions for external use
return {
    loadMovementButtons = loadMovementButtons,
    loadMovementSettings = loadMovementSettings,
    cleanup = cleanup
}