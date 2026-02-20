local Players, RunService, Workspace, UserInputService, humanoid, rootPart, connections, buttonStates, ScrollFrame, ScreenGui, settings, player

local Movement = {}

Movement.speedEnabled = false
Movement.jumpEnabled = false
Movement.flyEnabled = false
Movement.noclipEnabled = false
Movement.infiniteJumpEnabled = false
Movement.walkOnWaterEnabled = false
Movement.swimEnabled = false
Movement.moonGravityEnabled = false
Movement.doubleJumpEnabled = false
Movement.wallClimbEnabled = false
Movement.playerNoclipEnabled = false
Movement.floatEnabled = false
Movement.rewindEnabled = false
Movement.boostEnabled = false
Movement.slowFallEnabled = false
Movement.fastFallEnabled = false
Movement.sprintEnabled = false
Movement.isSprinting = false
Movement.isRewinding = false
Movement.bunnyHopEnabled = false
Movement.persistFeatures = false

Movement.defaultWalkSpeed = 16
Movement.defaultJumpPower = 50
Movement.defaultJumpHeight = 7.2
Movement.defaultGravity = 196.2
Movement.jumpCount = 0
Movement.maxJumps = 1

local flySpeed = 50
local flyBodyVelocity = nil
local flyBodyGyro = nil
local flyJoystickFrame, flyJoystickKnob
local flyUpButton, flyDownButton
local boostButton
local rewindButton
local sprintButton
local wallClimbButton
local joystickDelta = Vector2.new(0, 0)
local isTouchingJoystick = false
local joystickTouchId = nil

local flyKeys = {forward = false, back = false, left = false, right = false, up = false, down = false}
local floatKeys = {forward = false, back = false, left = false, right = false, up = false, down = false}

local positionHistory = {}
local maxHistorySize = 300 
local isBoostActive = false
local isRespawning = false

local rewindText

local settingsFrame
local speedInput, jumpInput, sprintInput, flyInput, swimInput
local boostSpeedInput, boostDurationInput
local slowFallSpeedInput, fastFallSpeedInput, moonGravityMultiplierInput
local maxExtraJumpsInput, wallClimbSpeedInput, infiniteJumpMultiplierInput
local applyButton, closeButton
local persistToggle
local rewindSlowButton, rewindMediumButton, rewindFastButton
local currentRewindMode = "medium"

local defaultSettings = {
    WalkSpeed = 50,
    JumpHeight = 50,
    SprintSpeed = 300,
    FlySpeed = 50,
    SwimSpeed = 100,
    BoostSpeed = 100,
    BoostDuration = 0.5,
    SlowFallSpeed = -10,
    FastFallSpeed = -100,
    MoonGravityMultiplier = 1/6,
    MaxExtraJumps = 1,
    WallClimbSpeed = 30,
    InfiniteJumpMultiplier = 3
}

local function sendServerMessage(message)
    local StarterGui = game:GetService("StarterGui")
    if StarterGui then
        pcall(function()
            StarterGui:SetCore("ChatMakeSystemMessage", {
                Text = "[SERVER] " .. message;
                Color = Color3.fromRGB(0, 255, 0);
                Font = Enum.Font.GothamBold;
                FontSize = Enum.FontSize.Size18;
            })
        end)
    end

    local Chat = game:GetService("Chat")
    if Chat then
        pcall(function()
            local sss = game:GetService("ServerScriptService")
            local csr = sss:FindFirstChild("ChatServiceRunner")
            if csr then
                local cs = csr:FindFirstChild("ChatService")
                if cs then
                    local chatService = require(cs)
                    if chatService then
                        chatService:InternalSendSystemMessage("[SERVER] " .. message, "All")
                    end
                end
            end
        end)
    end
end

local function setupScrollFrame()
    if ScrollFrame then
        ScrollFrame.ScrollingEnabled = true
        ScrollFrame.ScrollBarThickness = 8
        ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 600)
    end
end

local function refreshReferences()
    if not player or not player.Character then 
        return false 
    end
    
    local newHumanoid = player.Character:FindFirstChildOfClass("Humanoid")
    local newRootPart = player.Character:FindFirstChild("HumanoidRootPart")
    
    if newHumanoid then
        humanoid = newHumanoid
    end
    if newRootPart then
        rootPart = newRootPart
    end
    
    return humanoid ~= nil and rootPart ~= nil
end

local function getSettingValue(settingName, defaultValue)
    if settings and settings[settingName] and settings[settingName].value then
        return settings[settingName].value
    end
    return defaultValue
end

local function updateButtonState(featureName, enabled)
    if buttonStates and buttonStates[featureName] then
        local button = buttonStates[featureName]
        if button and button.Parent then
            button.BackgroundColor3 = enabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(40, 40, 40)
            button.TextColor3 = enabled and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        end
    end
end

local function createSettingsGUI()
    if settingsFrame then settingsFrame:Destroy() end

    settingsFrame = Instance.new("Frame")
    settingsFrame.Name = "SettingsFrame"
    settingsFrame.Size = UDim2.new(0, 250, 0, 400)
    settingsFrame.Position = UDim2.new(0.5, -125, 0.5, -200)
    settingsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    settingsFrame.BorderSizePixel = 0
    settingsFrame.Visible = false
    settingsFrame.ZIndex = 15
    pcall(function() settingsFrame.Parent = ScreenGui or player.PlayerGui end)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.1, 0)
    corner.Parent = settingsFrame

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Text = "Movement Settings"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.Parent = settingsFrame

    local scrolling = Instance.new("ScrollingFrame")
    scrolling.Name = "SettingsScroll"
    scrolling.Size = UDim2.new(1, 0, 1, -70)
    scrolling.Position = UDim2.new(0, 0, 0, 30)
    scrolling.BackgroundTransparency = 1
    scrolling.ScrollBarThickness = 6
    scrolling.CanvasSize = UDim2.new(0, 0, 0, 1000)
    scrolling.Parent = settingsFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 5)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = scrolling

    local function createInputField(parent, name, settingName, defaultValue)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 50)
        frame.BackgroundTransparency = 1
        frame.Parent = parent

        local label = Instance.new("TextLabel")
        label.Name = name .. "Label"
        label.Size = UDim2.new(1, -10, 0, 20)
        label.Position = UDim2.new(0, 5, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name .. ":"
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local input = Instance.new("TextBox")
        input.Name = name .. "Input"
        input.Size = UDim2.new(1, -10, 0, 30)
        input.Position = UDim2.new(0, 5, 0, 20)
        input.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        input.TextColor3 = Color3.fromRGB(255, 255, 255)
        input.Text = tostring(getSettingValue(settingName, defaultValue))
        input.Font = Enum.Font.Gotham
        input.TextSize = 14
        input.Parent = frame

        return input
    end

    local function createToggleField(parent, name, toggleVar)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 50)
        frame.BackgroundTransparency = 1
        frame.Parent = parent

        local label = Instance.new("TextLabel")
        label.Name = name .. "Label"
        label.Size = UDim2.new(1, -10, 0, 20)
        label.Position = UDim2.new(0, 5, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = name .. ":"
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Font = Enum.Font.Gotham
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local toggle = Instance.new("TextButton")
        toggle.Name = name .. "Toggle"
        toggle.Size = UDim2.new(1, -10, 0, 30)
        toggle.Position = UDim2.new(0, 5, 0, 20)
        toggle.BackgroundColor3 = toggleVar and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(40, 40, 40)
        toggle.TextColor3 = toggleVar and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        toggle.Text = toggleVar and "ON" or "OFF"
        toggle.Font = Enum.Font.Gotham
        toggle.TextSize = 14
        toggle.Parent = frame

        return toggle
    end

    speedInput = createInputField(scrolling, "Speed", "WalkSpeed", defaultSettings.WalkSpeed)
    jumpInput = createInputField(scrolling, "Jump", "JumpHeight", defaultSettings.JumpHeight)
    sprintInput = createInputField(scrolling, "Sprint", "SprintSpeed", defaultSettings.SprintSpeed)
    flyInput = createInputField(scrolling, "Fly", "FlySpeed", defaultSettings.FlySpeed)
    swimInput = createInputField(scrolling, "Swim", "SwimSpeed", defaultSettings.SwimSpeed)
    boostSpeedInput = createInputField(scrolling, "Boost Speed", "BoostSpeed", defaultSettings.BoostSpeed)
    boostDurationInput = createInputField(scrolling, "Boost Duration", "BoostDuration", defaultSettings.BoostDuration)
    slowFallSpeedInput = createInputField(scrolling, "Slow Fall Speed", "SlowFallSpeed", defaultSettings.SlowFallSpeed)
    fastFallSpeedInput = createInputField(scrolling, "Fast Fall Speed", "FastFallSpeed", defaultSettings.FastFallSpeed)
    moonGravityMultiplierInput = createInputField(scrolling, "Moon Gravity Multiplier", "MoonGravityMultiplier", defaultSettings.MoonGravityMultiplier)
    maxExtraJumpsInput = createInputField(scrolling, "Max Extra Jumps", "MaxExtraJumps", defaultSettings.MaxExtraJumps)
    wallClimbSpeedInput = createInputField(scrolling, "Wall Climb Speed", "WallClimbSpeed", defaultSettings.WallClimbSpeed)
    infiniteJumpMultiplierInput = createInputField(scrolling, "Infinite Jump Multiplier", "InfiniteJumpMultiplier", defaultSettings.InfiniteJumpMultiplier)

    local rewindModeFrame = Instance.new("Frame")
    rewindModeFrame.Size = UDim2.new(1, 0, 0, 50)
    rewindModeFrame.BackgroundTransparency = 1
    rewindModeFrame.Parent = scrolling

    local rewindLabel = Instance.new("TextLabel")
    rewindLabel.Name = "RewindModeLabel"
    rewindLabel.Size = UDim2.new(1, -10, 0, 20)
    rewindLabel.Position = UDim2.new(0, 5, 0, 0)
    rewindLabel.BackgroundTransparency = 1
    rewindLabel.Text = "Rewind Speed:"
    rewindLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    rewindLabel.Font = Enum.Font.Gotham
    rewindLabel.TextSize = 12
    rewindLabel.TextXAlignment = Enum.TextXAlignment.Left
    rewindLabel.Parent = rewindModeFrame

    local buttonsFrame = Instance.new("Frame")
    buttonsFrame.Size = UDim2.new(1, -10, 0, 30)
    buttonsFrame.Position = UDim2.new(0, 5, 0, 20)
    buttonsFrame.BackgroundTransparency = 1
    buttonsFrame.Parent = rewindModeFrame

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(1/3, 0, 1, 0)
    gridLayout.Parent = buttonsFrame

    local function createModeButton(name, mode)
        local button = Instance.new("TextButton")
        button.Name = name .. "Button"
        button.BackgroundColor3 = (currentRewindMode == mode) and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(40, 40, 40)
        button.TextColor3 = (currentRewindMode == mode) and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        button.Text = name
        button.Font = Enum.Font.Gotham
        button.TextSize = 14
        button.Parent = buttonsFrame
        return button
    end

    rewindSlowButton = createModeButton("Slow", "slow")
    rewindMediumButton = createModeButton("Medium", "medium")
    rewindFastButton = createModeButton("Fast", "fast")

    local function updateRewindButtons()
        rewindSlowButton.BackgroundColor3 = (currentRewindMode == "slow") and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(40, 40, 40)
        rewindSlowButton.TextColor3 = (currentRewindMode == "slow") and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        rewindMediumButton.BackgroundColor3 = (currentRewindMode == "medium") and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(40, 40, 40)
        rewindMediumButton.TextColor3 = (currentRewindMode == "medium") and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        rewindFastButton.BackgroundColor3 = (currentRewindMode == "fast") and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(40, 40, 40)
        rewindFastButton.TextColor3 = (currentRewindMode == "fast") and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
    end

    rewindSlowButton.MouseButton1Click:Connect(function()
        currentRewindMode = "slow"
        settings.RewindMode = "slow"
        updateRewindButtons()
    end)
    rewindMediumButton.MouseButton1Click:Connect(function()
        currentRewindMode = "medium"
        settings.RewindMode = "medium"
        updateRewindButtons()
    end)
    rewindFastButton.MouseButton1Click:Connect(function()
        currentRewindMode = "fast"
        settings.RewindMode = "fast"
        updateRewindButtons()
    end)

    persistToggle = createToggleField(scrolling, "Keep Features After Death", Movement.persistFeatures)

    applyButton = Instance.new("TextButton")
    applyButton.Name = "ApplyButton"
    applyButton.Size = UDim2.new(0.45, -10, 0, 30)
    applyButton.Position = UDim2.new(0, 5, 1, -35)
    applyButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
    applyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    applyButton.Text = "Apply"
    applyButton.Font = Enum.Font.GothamBold
    applyButton.TextSize = 14
    applyButton.Parent = settingsFrame

    closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0.45, -10, 0, 30)
    closeButton.Position = UDim2.new(0.55, 5, 1, -35)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Text = "Close"
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 14
    closeButton.Parent = settingsFrame

    applyButton.MouseButton1Click:Connect(function()
        local speedVal = tonumber(speedInput.Text)
        local jumpVal = tonumber(jumpInput.Text)
        local sprintVal = tonumber(sprintInput.Text)
        local flyVal = tonumber(flyInput.Text)
        local swimVal = tonumber(swimInput.Text)
        local boostSpeedVal = tonumber(boostSpeedInput.Text)
        local boostDurationVal = tonumber(boostDurationInput.Text)
        local slowFallSpeedVal = tonumber(slowFallSpeedInput.Text)
        local fastFallSpeedVal = tonumber(fastFallSpeedInput.Text)
        local moonGravityMultiplierVal = tonumber(moonGravityMultiplierInput.Text)
        local maxExtraJumpsVal = tonumber(maxExtraJumpsInput.Text)
        local wallClimbSpeedVal = tonumber(wallClimbSpeedInput.Text)
        local infiniteJumpMultiplierVal = tonumber(infiniteJumpMultiplierInput.Text)

        if speedVal then settings.WalkSpeed = {value = math.clamp(speedVal, 1, 50)} end
        if jumpVal then settings.JumpHeight = {value = jumpVal} end
        if sprintVal then settings.SprintSpeed = {value = math.max(sprintVal, 50)} end
        if flyVal then settings.FlySpeed = {value = flyVal} end
        if swimVal then settings.SwimSpeed = {value = swimVal} end
        if boostSpeedVal then settings.BoostSpeed = {value = boostSpeedVal} end
        if boostDurationVal then settings.BoostDuration = {value = boostDurationVal} end
        if slowFallSpeedVal then settings.SlowFallSpeed = {value = slowFallSpeedVal} end
        if fastFallSpeedVal then settings.FastFallSpeed = {value = fastFallSpeedVal} end
        if moonGravityMultiplierVal then settings.MoonGravityMultiplier = {value = moonGravityMultiplierVal} end
        if maxExtraJumpsVal then settings.MaxExtraJumps = {value = maxExtraJumpsVal} end
        if wallClimbSpeedVal then settings.WallClimbSpeed = {value = wallClimbSpeedVal} end
        if infiniteJumpMultiplierVal then settings.InfiniteJumpMultiplier = {value = infiniteJumpMultiplierVal} end

        Movement.applySettings()
        settingsFrame.Visible = false
    end)

    persistToggle.MouseButton1Click:Connect(function()
        Movement.persistFeatures = not Movement.persistFeatures
        persistToggle.Text = Movement.persistFeatures and "ON" or "OFF"
        persistToggle.BackgroundColor3 = Movement.persistFeatures and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(40, 40, 40)
        persistToggle.TextColor3 = Movement.persistFeatures and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
    end)

    closeButton.MouseButton1Click:Connect(function()
        settingsFrame.Visible = false
    end)
end

local function createMobileControls()
    if flyJoystickFrame then flyJoystickFrame:Destroy() end
    if flyUpButton then flyUpButton:Destroy() end
    if flyDownButton then flyDownButton:Destroy() end
    if boostButton then boostButton:Destroy() end
    if rewindButton then rewindButton:Destroy() end
    if sprintButton then sprintButton:Destroy() end
    if wallClimbButton then wallClimbButton:Destroy() end

    flyJoystickFrame = Instance.new("Frame")
    flyJoystickFrame.Name = "FlyJoystick"
    flyJoystickFrame.Size = UDim2.new(0, 100, 0, 100)
    flyJoystickFrame.Position = UDim2.new(0, 20, 1, -130)
    flyJoystickFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flyJoystickFrame.BackgroundTransparency = 0.5
    flyJoystickFrame.BorderSizePixel = 0
    flyJoystickFrame.Visible = false
    flyJoystickFrame.ZIndex = 10
    pcall(function() flyJoystickFrame.Parent = ScreenGui or player.PlayerGui end)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = flyJoystickFrame

    flyJoystickKnob = Instance.new("Frame")
    flyJoystickKnob.Name = "Knob"
    flyJoystickKnob.Size = UDim2.new(0, 40, 0, 40)
    flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
    flyJoystickKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flyJoystickKnob.BackgroundTransparency = 0.1
    flyJoystickKnob.BorderSizePixel = 0
    flyJoystickKnob.ZIndex = 11
    flyJoystickKnob.Parent = flyJoystickFrame

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0.5, 0)
    knobCorner.Parent = flyJoystickKnob

    flyUpButton = Instance.new("TextButton")
    flyUpButton.Name = "FlyUpButton"
    flyUpButton.Size = UDim2.new(0, 50, 0, 50)
    flyUpButton.Position = UDim2.new(0, 130, 1, -180)
    flyUpButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flyUpButton.BackgroundTransparency = 0.5
    flyUpButton.BorderSizePixel = 0
    flyUpButton.Text = "↑"
    flyUpButton.Font = Enum.Font.GothamBold
    flyUpButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    flyUpButton.TextSize = 20
    flyUpButton.Visible = false
    flyUpButton.ZIndex = 10
    pcall(function() flyUpButton.Parent = ScreenGui or player.PlayerGui end)

    local upCorner = Instance.new("UICorner")
    upCorner.CornerRadius = UDim.new(0.2, 0)
    upCorner.Parent = flyUpButton

    flyDownButton = Instance.new("TextButton")
    flyDownButton.Name = "FlyDownButton"
    flyDownButton.Size = UDim2.new(0, 50, 0, 50)
    flyDownButton.Position = UDim2.new(0, 130, 1, -120)
    flyDownButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flyDownButton.BackgroundTransparency = 0.5
    flyDownButton.BorderSizePixel = 0
    flyDownButton.Text = "↓"
    flyDownButton.Font = Enum.Font.GothamBold
    flyDownButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    flyDownButton.TextSize = 20
    flyDownButton.Visible = false
    flyDownButton.ZIndex = 10
    pcall(function() flyDownButton.Parent = ScreenGui or player.PlayerGui end)

    local downCorner = Instance.new("UICorner")
    downCorner.CornerRadius = UDim.new(0.2, 0)
    downCorner.Parent = flyDownButton

    sprintButton = Instance.new("TextButton")
    sprintButton.Name = "SprintButton"
    sprintButton.Size = UDim2.new(0, 80, 0, 80)
    sprintButton.Position = UDim2.new(1, -100, 1, -370)
    sprintButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sprintButton.BackgroundTransparency = 0.5
    sprintButton.BorderSizePixel = 0
    sprintButton.Text = "SPRINT"
    sprintButton.Font = Enum.Font.GothamBold
    sprintButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    sprintButton.TextSize = 16
    sprintButton.Visible = false
    sprintButton.ZIndex = 10
    pcall(function() sprintButton.Parent = ScreenGui or player.PlayerGui end)

    local sprintCorner = Instance.new("UICorner")
    sprintCorner.CornerRadius = UDim.new(0.2, 0)
    sprintCorner.Parent = sprintButton

    wallClimbButton = Instance.new("TextButton")
    wallClimbButton.Name = "WallClimbButton"
    wallClimbButton.Size = UDim2.new(0, 80, 0, 80)
    wallClimbButton.Position = UDim2.new(1, -100, 1, -460)
    wallClimbButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    wallClimbButton.BackgroundTransparency = 0.5
    wallClimbButton.BorderSizePixel = 0
    wallClimbButton.Text = "CLIMB"
    wallClimbButton.Font = Enum.Font.GothamBold
    wallClimbButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    wallClimbButton.TextSize = 16
    wallClimbButton.Visible = false
    wallClimbButton.ZIndex = 10
    pcall(function() wallClimbButton.Parent = ScreenGui or player.PlayerGui end)

    local wallClimbCorner = Instance.new("UICorner")
    wallClimbCorner.CornerRadius = UDim.new(0.2, 0)
    wallClimbCorner.Parent = wallClimbButton
end

local function handleFloatJoystick(input, gameProcessed)
    if not Movement.floatEnabled or not flyJoystickFrame or not flyJoystickFrame.Visible then 
        return 
    end
    
    if input.UserInputType == Enum.UserInputType.Touch then
        local joystickCenter = flyJoystickFrame.AbsolutePosition + flyJoystickFrame.AbsoluteSize * 0.5
        local inputPos = Vector2.new(input.Position.X, input.Position.Y)
        local distanceFromCenter = (inputPos - joystickCenter).Magnitude
        
        if input.UserInputState == Enum.UserInputState.Begin then
            if distanceFromCenter <= 50 and not isTouchingJoystick then
                isTouchingJoystick = true
                joystickTouchId = input
            end
        elseif input.UserInputState == Enum.UserInputState.Change and isTouchingJoystick and input == joystickTouchId then
            local delta = inputPos - joystickCenter
            local magnitude = delta.Magnitude
            local maxRadius = 30
            
            if magnitude > maxRadius then
                delta = delta * (maxRadius / magnitude)
            end
            
            flyJoystickKnob.Position = UDim2.new(0.5, delta.X - 20, 0.5, delta.Y - 20)
            joystickDelta = delta / maxRadius
        elseif input.UserInputState == Enum.UserInputState.End and input == joystickTouchId then
            isTouchingJoystick = false
            joystickTouchId = nil
            flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
            joystickDelta = Vector2.new(0, 0)
        end
    end
end

local function handleFlyJoystick(input, gameProcessed)
    if not Movement.flyEnabled or not flyJoystickFrame or not flyJoystickFrame.Visible then 
        return 
    end
    
    if input.UserInputType == Enum.UserInputType.Touch then
        local joystickCenter = flyJoystickFrame.AbsolutePosition + flyJoystickFrame.AbsoluteSize * 0.5
        local inputPos = Vector2.new(input.Position.X, input.Position.Y)
        local distanceFromCenter = (inputPos - joystickCenter).Magnitude
        
        if input.UserInputState == Enum.UserInputState.Begin then
            if distanceFromCenter <= 50 and not isTouchingJoystick then
                isTouchingJoystick = true
                joystickTouchId = input
            end
        elseif input.UserInputState == Enum.UserInputState.Change and isTouchingJoystick and input == joystickTouchId then
            local delta = inputPos - joystickCenter
            local magnitude = delta.Magnitude
            local maxRadius = 30
            
            if magnitude > maxRadius then
                delta = delta * (maxRadius / magnitude)
            end
            
            flyJoystickKnob.Position = UDim2.new(0.5, delta.X - 20, 0.5, delta.Y - 20)
            joystickDelta = delta / maxRadius
        elseif input.UserInputState == Enum.UserInputState.End and input == joystickTouchId then
            isTouchingJoystick = false
            joystickTouchId = nil
            flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
            joystickDelta = Vector2.new(0, 0)
        end
    end
end

local function toggleSpeed(enabled)
    Movement.speedEnabled = enabled
    updateButtonState("Speed Hack", enabled)
    
    if enabled then
        local function applySpeed()
            if refreshReferences() and humanoid then
                local speedValue = getSettingValue("WalkSpeed", defaultSettings.WalkSpeed)
                humanoid.WalkSpeed = speedValue
                return true
            end
            return false
        end
        
        if not applySpeed() then
            task.spawn(function()
                task.wait(0.1)
                applySpeed()
            end)
        end
    else
        if refreshReferences() and humanoid then
            humanoid.WalkSpeed = Movement.defaultWalkSpeed
        end
    end
end

local function toggleJump(enabled)
    Movement.jumpEnabled = enabled
    updateButtonState("Jump Hack", enabled)
    
    if enabled then
        local function applyJump()
            if refreshReferences() and humanoid then
                local jumpValue = getSettingValue("JumpHeight", defaultSettings.JumpHeight)
                if humanoid:FindFirstChild("JumpHeight") then
                    humanoid.JumpHeight = jumpValue
                else
                    humanoid.JumpPower = jumpValue * 2.4
                end
                return true
            end
            return false
        end
        
        if not applyJump() then
            task.spawn(function()
                task.wait(0.1)
                applyJump()
            end)
        end
    else
        if refreshReferences() and humanoid then
            if humanoid:FindFirstChild("JumpHeight") then
                humanoid.JumpHeight = Movement.defaultJumpHeight
            else
                humanoid.JumpPower = Movement.defaultJumpPower
            end
        end
    end
end

local function toggleSlowFall(enabled)
    Movement.slowFallEnabled = enabled
    updateButtonState("Slow Fall", enabled)
    
    if connections.slowFall then
        connections.slowFall:Disconnect()
        connections.slowFall = nil
    end
    
    if enabled then
        connections.slowFall = RunService.Heartbeat:Connect(function()
            if not Movement.slowFallEnabled then return end
            if not refreshReferences() or not rootPart or not humanoid then return end
            
            if rootPart.Velocity.Y < 0 then
                local slowFallVelocity = Instance.new("BodyVelocity")
                slowFallVelocity.MaxForce = Vector3.new(0, 4000, 0)
                slowFallVelocity.Velocity = Vector3.new(0, getSettingValue("SlowFallSpeed", defaultSettings.SlowFallSpeed), 0)
                slowFallVelocity.Parent = rootPart
                game:GetService("Debris"):AddItem(slowFallVelocity, 0.1)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            end
        end)
    else
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        end
    end
end

local function toggleFastFall(enabled)
    Movement.fastFallEnabled = enabled
    updateButtonState("Fast Fall", enabled)
    
    if connections.fastFall then
        connections.fastFall:Disconnect()
        connections.fastFall = nil
    end
    
    if enabled then
        connections.fastFall = RunService.Heartbeat:Connect(function()
            if not Movement.fastFallEnabled then return end
            if not refreshReferences() or not rootPart or not humanoid then return end
            
            if rootPart.Velocity.Y < 0 then
                local fastFallVelocity = Instance.new("BodyVelocity")
                fastFallVelocity.MaxForce = Vector3.new(0, 4000, 0)
                fastFallVelocity.Velocity = Vector3.new(0, getSettingValue("FastFallSpeed", defaultSettings.FastFallSpeed), 0)
                fastFallVelocity.Parent = rootPart
                game:GetService("Debris"):AddItem(fastFallVelocity, 0.1)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            end
        end)
    else
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        end
    end
end

local function toggleSprint(enabled)
    Movement.sprintEnabled = enabled
    updateButtonState("Sprint", enabled)
    
    if connections.sprint then
        connections.sprint:Disconnect()
        connections.sprint = nil
    end
    if connections.sprintInput then
        connections.sprintInput:Disconnect()
        connections.sprintInput = nil
    end
    if connections.sprintToggle then
        connections.sprintToggle:Disconnect()
        connections.sprintToggle = nil
    end
    
    if enabled then
        if sprintButton then
            sprintButton.Visible = true
        end
        
        connections.sprintInput = sprintButton.MouseButton1Click:Connect(function()
            if refreshReferences() and humanoid then
                Movement.isSprinting = not Movement.isSprinting
                sprintButton.BackgroundColor3 = Movement.isSprinting and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
                sprintButton.BackgroundTransparency = Movement.isSprinting and 0.2 or 0.5
                sprintButton.Text = Movement.isSprinting and "SPRINTING!" or "SPRINT"
                
                humanoid.WalkSpeed = Movement.isSprinting and getSettingValue("SprintSpeed", defaultSettings.SprintSpeed) or (Movement.speedEnabled and getSettingValue("WalkSpeed", defaultSettings.WalkSpeed) or Movement.defaultWalkSpeed)
            end
        end)
        
        connections.sprintToggle = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or not Movement.sprintEnabled then return end
            if input.KeyCode == Enum.KeyCode.LeftShift then
                if refreshReferences() and humanoid then
                    Movement.isSprinting = not Movement.isSprinting
                    sprintButton.BackgroundColor3 = Movement.isSprinting and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
                    sprintButton.BackgroundTransparency = Movement.isSprinting and 0.2 or 0.5
                    sprintButton.Text = Movement.isSprinting and "SPRINTING!" or "SPRINT"
                    
                    humanoid.WalkSpeed = Movement.isSprinting and getSettingValue("SprintSpeed", defaultSettings.SprintSpeed) or (Movement.speedEnabled and getSettingValue("WalkSpeed", defaultSettings.WalkSpeed) or Movement.defaultWalkSpeed)
                end
            end
        end)
    else
        if sprintButton then
            sprintButton.Visible = false
            sprintButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            sprintButton.BackgroundTransparency = 0.5
            sprintButton.Text = "SPRINT"
        end
        if refreshReferences() and humanoid then
            humanoid.WalkSpeed = Movement.speedEnabled and getSettingValue("WalkSpeed", defaultSettings.WalkSpeed) or Movement.defaultWalkSpeed
        end
        Movement.isSprinting = false
    end
end

local function toggleFloat(enabled)
    Movement.floatEnabled = enabled
    updateButtonState("Float", enabled)
    
    local floatConnections = {"float", "floatInput", "floatBegan", "floatChanged", "floatEnded", "floatKeyBegan", "floatKeyEnded", "floatUp", "floatUpEnd", "floatDown", "floatDownEnd"}
    for _, connName in ipairs(floatConnections) do
        if connections[connName] then
            connections[connName]:Disconnect()
            connections[connName] = nil
        end
    end

    floatKeys = {forward = false, back = false, left = false, right = false, up = false, down = false}

    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    
    if enabled then
        task.spawn(function()
            task.wait(0.1)
            if not refreshReferences() or not rootPart or not humanoid then
                Movement.floatEnabled = false
                updateButtonState("Float", false)
                return
            end
            
            humanoid.PlatformStand = true
            flyBodyVelocity = Instance.new("BodyVelocity")
            flyBodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
            flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            flyBodyVelocity.Parent = rootPart
            
            if flyJoystickFrame then flyJoystickFrame.Visible = true end
            if flyUpButton then flyUpButton.Visible = true end
            if flyDownButton then flyDownButton.Visible = true end
            
            connections.float = RunService.Heartbeat:Connect(function()
                if not Movement.floatEnabled then return end
                if not refreshReferences() or not rootPart or not humanoid then return end
                
                if not flyBodyVelocity or flyBodyVelocity.Parent ~= rootPart then
                    if flyBodyVelocity then flyBodyVelocity:Destroy() end
                    flyBodyVelocity = Instance.new("BodyVelocity")
                    flyBodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                    flyBodyVelocity.Parent = rootPart
                end
                
                local camera = Workspace.CurrentCamera
                if not camera then return end
                
                local floatDirection = Vector3.new(0, 0, 0)
                flySpeed = getSettingValue("FlySpeed", defaultSettings.FlySpeed)
                
                if joystickDelta.Magnitude > 0.05 then
                    local forward = camera.CFrame.LookVector
                    local right = camera.CFrame.RightVector
                    
                    forward = Vector3.new(forward.X, 0, forward.Z).Unit
                    right = Vector3.new(right.X, 0, right.Z).Unit
                    
                    floatDirection = floatDirection + (right * joystickDelta.X) + (forward * -joystickDelta.Y)
                end
                
                local keyDirection = Vector3.new(0, 0, 0)
                local flatLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit
                local flatRight = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z).Unit
                
                if floatKeys.forward then keyDirection = keyDirection + flatLook end
                if floatKeys.back then keyDirection = keyDirection - flatLook end
                if floatKeys.left then keyDirection = keyDirection - flatRight end
                if floatKeys.right then keyDirection = keyDirection + flatRight end
                if floatKeys.up then keyDirection = keyDirection + Vector3.new(0, 1, 0) end
                if floatKeys.down then keyDirection = keyDirection - Vector3.new(0, 1, 0) end
                
                floatDirection = floatDirection + keyDirection
                
                if floatDirection.Magnitude > 0 then
                    flyBodyVelocity.Velocity = floatDirection.Unit * flySpeed
                else
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                end
            end)
            
            connections.floatBegan = UserInputService.InputBegan:Connect(handleFloatJoystick)
            connections.floatChanged = UserInputService.InputChanged:Connect(handleFloatJoystick)
            connections.floatEnded = UserInputService.InputEnded:Connect(handleFloatJoystick)
            
            connections.floatKeyBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed then return end
                local kc = input.KeyCode
                if kc == Enum.KeyCode.W then floatKeys.forward = true
                elseif kc == Enum.KeyCode.S then floatKeys.back = true
                elseif kc == Enum.KeyCode.A then floatKeys.left = true
                elseif kc == Enum.KeyCode.D then floatKeys.right = true
                elseif kc == Enum.KeyCode.Space then floatKeys.up = true
                elseif kc == Enum.KeyCode.LeftShift then floatKeys.down = true
                end
            end)
            
            connections.floatKeyEnded = UserInputService.InputEnded:Connect(function(input)
                local kc = input.KeyCode
                if kc == Enum.KeyCode.W then floatKeys.forward = false
                elseif kc == Enum.KeyCode.S then floatKeys.back = false
                elseif kc == Enum.KeyCode.A then floatKeys.left = false
                elseif kc == Enum.KeyCode.D then floatKeys.right = false
                elseif kc == Enum.KeyCode.Space then floatKeys.up = false
                elseif kc == Enum.KeyCode.LeftShift then floatKeys.down = false
                end
            end)
            
            connections.floatUp = flyUpButton.MouseButton1Down:Connect(function()
                floatKeys.up = true
            end)
            connections.floatUpEnd = flyUpButton.MouseButton1Up:Connect(function()
                floatKeys.up = false
            end)
            connections.floatDown = flyDownButton.MouseButton1Down:Connect(function()
                floatKeys.down = true
            end)
            connections.floatDownEnd = flyDownButton.MouseButton1Up:Connect(function()
                floatKeys.down = false
            end)
        end)
    else
        if humanoid then
            humanoid.PlatformStand = false
        end
        if flyJoystickFrame then 
            flyJoystickFrame.Visible = false
            flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
        end
        if flyUpButton then flyUpButton.Visible = false end
        if flyDownButton then flyDownButton.Visible = false end
        
        joystickDelta = Vector2.new(0, 0)
        isTouchingJoystick = false
        joystickTouchId = nil
    end
end

local function createBoostButton()
    if boostButton then boostButton:Destroy() end
    
    boostButton = Instance.new("TextButton")
    boostButton.Name = "BoostButton"
    boostButton.Size = UDim2.new(0, 80, 0, 80)
    boostButton.Position = UDim2.new(1, -100, 1, -280)
    boostButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    boostButton.BackgroundTransparency = 0.5
    boostButton.BorderSizePixel = 0
    boostButton.Text = "BOOST"
    boostButton.Font = Enum.Font.GothamBold
    boostButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    boostButton.TextSize = 16
    boostButton.Visible = false
    boostButton.ZIndex = 10
    pcall(function() boostButton.Parent = ScreenGui or player.PlayerGui end)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.2, 0)
    corner.Parent = boostButton
end

local function toggleBoost(enabled)
    Movement.boostEnabled = enabled
    updateButtonState("Boost (NOS)", enabled)
    
    if connections.boost then
        connections.boost:Disconnect()
        connections.boost = nil
    end
    if connections.boostInput then
        connections.boostInput:Disconnect()
        connections.boostInput = nil
    end
    if connections.boostToggle then
        connections.boostToggle:Disconnect()
        connections.boostToggle = nil
    end
    
    if enabled then
        createBoostButton()
        if boostButton then
            boostButton.Visible = true
        end
        
        connections.boostInput = boostButton.MouseButton1Click:Connect(function()
            if refreshReferences() and humanoid and rootPart then
                isBoostActive = true
                boostButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                boostButton.BackgroundTransparency = 0.2
                boostButton.Text = "BOOSTING!"
                
                local camera = Workspace.CurrentCamera
                if camera then
                    local boostDirection = camera.CFrame.LookVector
                    local boostForce = Instance.new("BodyVelocity")
                    boostForce.MaxForce = Vector3.new(4000, 0, 4000)
                    boostForce.Velocity = Vector3.new(boostDirection.X * getSettingValue("BoostSpeed", defaultSettings.BoostSpeed), 0, boostDirection.Z * getSettingValue("BoostSpeed", defaultSettings.BoostSpeed))
                    boostForce.Parent = rootPart
                    
                    game:GetService("Debris"):AddItem(boostForce, getSettingValue("BoostDuration", defaultSettings.BoostDuration))
                    
                    task.spawn(function()
                        task.wait(getSettingValue("BoostDuration", defaultSettings.BoostDuration))
                        isBoostActive = false
                        if boostButton then
                            boostButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                            boostButton.BackgroundTransparency = 0.5
                            boostButton.Text = "BOOST"
                        end
                    end)
                end
            end
        end)
        
        connections.boostToggle = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or not Movement.boostEnabled then return end
            if input.KeyCode == Enum.KeyCode.B then
                if refreshReferences() and humanoid and rootPart then
                    isBoostActive = true
                    boostButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
                    boostButton.BackgroundTransparency = 0.2
                    boostButton.Text = "BOOSTING!"
                    
                    local camera = Workspace.CurrentCamera
                    if camera then
                        local boostDirection = camera.CFrame.LookVector
                        local boostForce = Instance.new("BodyVelocity")
                        boostForce.MaxForce = Vector3.new(4000, 0, 4000)
                        boostForce.Velocity = Vector3.new(boostDirection.X * getSettingValue("BoostSpeed", defaultSettings.BoostSpeed), 0, boostDirection.Z * getSettingValue("BoostSpeed", defaultSettings.BoostSpeed))
                        boostForce.Parent = rootPart
                        
                        game:GetService("Debris"):AddItem(boostForce, getSettingValue("BoostDuration", defaultSettings.BoostDuration))
                        
                        task.spawn(function()
                            task.wait(getSettingValue("BoostDuration", defaultSettings.BoostDuration))
                            isBoostActive = false
                            if boostButton then
                                boostButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                                boostButton.BackgroundTransparency = 0.5
                                boostButton.Text = "BOOST"
                            end
                        end)
                    end
                end
            end
        end)
    else
        if boostButton then
            boostButton.Visible = false
            boostButton.Text = "BOOST"
        end
        isBoostActive = false
    end
end

local function createRewindButton()
    if rewindButton then rewindButton:Destroy() end
    
    rewindButton = Instance.new("TextButton")
    rewindButton.Name = "RewindButton"
    rewindButton.Size = UDim2.new(0, 80, 0, 80)
    rewindButton.Position = UDim2.new(1, -100, 1, -190)
    rewindButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    rewindButton.BackgroundTransparency = 0.5
    rewindButton.BorderSizePixel = 0
    rewindButton.Text = "⏪"
    rewindButton.Font = Enum.Font.GothamBold
    rewindButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    rewindButton.TextSize = 24
    rewindButton.Visible = false
    rewindButton.ZIndex = 10
    pcall(function() rewindButton.Parent = ScreenGui or player.PlayerGui end)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.2, 0)
    corner.Parent = rewindButton
end

local function createRewindText()
    if rewindText then rewindText:Destroy() end
    
    rewindText = Instance.new("TextLabel")
    rewindText.Name = "RewindText"
    rewindText.Size = UDim2.new(0, 200, 0, 50)
    rewindText.Position = UDim2.new(1, -210, 0, 10)
    rewindText.BackgroundTransparency = 1
    rewindText.TextColor3 = Color3.fromRGB(255, 255, 255)
    rewindText.Font = Enum.Font.GothamBold
    rewindText.TextSize = 20
    rewindText.TextXAlignment = Enum.TextXAlignment.Right
    rewindText.Visible = false
    rewindText.ZIndex = 10
    pcall(function() rewindText.Parent = ScreenGui or player.PlayerGui end)
end

local function toggleRewind(enabled)
    Movement.rewindEnabled = enabled
    updateButtonState("Smooth Rewind", enabled)
    
    if connections.rewind then
        connections.rewind:Disconnect()
        connections.rewind = nil
    end
    if connections.rewindInput then
        connections.rewindInput:Disconnect()
        connections.rewindInput = nil
    end
    if connections.rewindToggle then
        connections.rewindToggle:Disconnect()
        connections.rewindToggle = nil
    end
    
    if enabled then
        createRewindButton()
        createRewindText()
        if rewindButton then
            rewindButton.Visible = true
        end
        
        connections.rewind = RunService.Heartbeat:Connect(function()
            if not Movement.rewindEnabled then return end
            if not refreshReferences() or not rootPart then return end
            
            table.insert(positionHistory, {
                cframe = rootPart.CFrame,
                time = tick()
            })
            
            while #positionHistory > maxHistorySize do
                table.remove(positionHistory, 1)
            end
        end)
        
        local function performRewind()
            if #positionHistory < 30 then return end
            
            Movement.isRewinding = true
            rewindButton.BackgroundTransparency = 0.1
            rewindButton.Text = "STOP"
            rewindText.Visible = true
            
            local reversedHistory = {}
            for i = #positionHistory, 1, -1 do
                table.insert(reversedHistory, positionHistory[i])
            end
            
            local startTime = tick()
            local rewindDuration = (currentRewindMode == "slow" and 4) or (currentRewindMode == "medium" and 2) or 1
            local historyLength = #reversedHistory
            
            local rewindConnection
            rewindConnection = RunService.Heartbeat:Connect(function()
                if not Movement.isRewinding then
                    rewindConnection:Disconnect()
                    if rewindButton then
                        rewindButton.BackgroundTransparency = 0.5
                        rewindButton.Text = "⏪"
                    end
                    rewindText.Visible = false
                    positionHistory = {}
                    return
                end
                
                if not refreshReferences() or not rootPart then
                    rewindConnection:Disconnect()
                    rewindText.Visible = false
                    return
                end
                
                local elapsed = tick() - startTime
                local progress = math.min(elapsed / rewindDuration, 1)
                local remaining = math.ceil(rewindDuration - elapsed)
                rewindText.Text = "rewinding " .. remaining
                
                local index = progress * (historyLength - 1) + 1
                local floorIndex = math.floor(index)
                local ceilIndex = math.ceil(index)
                local frac = index - floorIndex
                
                local targetCFrame
                if ceilIndex <= historyLength then
                    local c1 = reversedHistory[floorIndex].cframe
                    local c2 = reversedHistory[ceilIndex].cframe
                    targetCFrame = c1:Lerp(c2, frac)
                else
                    targetCFrame = reversedHistory[historyLength].cframe
                end
                
                rootPart.CFrame = targetCFrame
                rootPart.Velocity = Vector3.new(0, 0, 0)
                
                if progress >= 1 then
                    rewindConnection:Disconnect()
                    if rewindButton then
                        rewindButton.BackgroundTransparency = 0.5
                        rewindButton.Text = "⏪"
                    end
                    rewindText.Visible = false
                    positionHistory = {}
                    Movement.isRewinding = false
                end
            end)
        end
        
        connections.rewindInput = rewindButton.MouseButton1Click:Connect(function()
            if refreshReferences() and rootPart then
                if Movement.isRewinding then
                    Movement.isRewinding = false
                else
                    performRewind()
                end
            end
        end)
        
        connections.rewindToggle = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or not Movement.rewindEnabled then return end
            if input.KeyCode == Enum.KeyCode.T then
                if refreshReferences() and rootPart then
                    if Movement.isRewinding then
                        Movement.isRewinding = false
                    else
                        performRewind()
                    end
                end
            end
        end)
    else
        if rewindButton then
            rewindButton.Visible = false
        end
        if rewindText then
            rewindText.Visible = false
        end
        positionHistory = {}
    end
end

local function toggleMoonGravity(enabled)
    Movement.moonGravityEnabled = enabled
    updateButtonState("Moon Gravity", enabled)
    
    if enabled then
        Workspace.Gravity = Movement.defaultGravity * getSettingValue("MoonGravityMultiplier", defaultSettings.MoonGravityMultiplier)
    else
        Workspace.Gravity = Movement.defaultGravity
    end
end

local function toggleDoubleJump(enabled)
    Movement.doubleJumpEnabled = enabled
    updateButtonState("Double Jump", enabled)
    
    if connections.doubleJump then
        connections.doubleJump:Disconnect()
        connections.doubleJump = nil
    end
    
    if enabled then
        Movement.maxJumps = getSettingValue("MaxExtraJumps", defaultSettings.MaxExtraJumps)
        connections.doubleJump = UserInputService.JumpRequest:Connect(function()
            if not Movement.doubleJumpEnabled then return end
            if not refreshReferences() or not humanoid then return end
            
            if humanoid:GetState() ~= Enum.HumanoidStateType.Jumping and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
                Movement.jumpCount = 0
            elseif Movement.jumpCount < Movement.maxJumps then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                Movement.jumpCount = Movement.jumpCount + 1
            end
        end)
    else
        Movement.jumpCount = 0
    end
end

local function toggleInfiniteJump(enabled)
    Movement.infiniteJumpEnabled = enabled
    updateButtonState("Infinite Jump", enabled)
    
    if connections.infiniteJump then
        connections.infiniteJump:Disconnect()
        connections.infiniteJump = nil
    end
    
    if enabled then
        connections.infiniteJump = UserInputService.JumpRequest:Connect(function()
            if not Movement.infiniteJumpEnabled then return end
            if not refreshReferences() or not humanoid or not rootPart then return end
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            rootPart.Velocity = Vector3.new(rootPart.Velocity.X, getSettingValue("JumpHeight", defaultSettings.JumpHeight) * getSettingValue("InfiniteJumpMultiplier", defaultSettings.InfiniteJumpMultiplier), rootPart.Velocity.Z)
        end)
    end
end

local function toggleWallClimb(enabled)
    Movement.wallClimbEnabled = enabled
    updateButtonState("Wall Climb", enabled)
    
    if connections.wallClimb then
        connections.wallClimb:Disconnect()
        connections.wallClimb = nil
    end
    if connections.wallClimbInput then
        connections.wallClimbInput:Disconnect()
        connections.wallClimbInput = nil
    end
    if connections.wallClimbButton then
        connections.wallClimbButton:Disconnect()
        connections.wallClimbButton = nil
    end
    
    if enabled then
        if wallClimbButton then
            wallClimbButton.Visible = true
        end
        
        connections.wallClimb = RunService.Heartbeat:Connect(function()
            if not Movement.wallClimbEnabled then return end
            if not refreshReferences() or not humanoid or not rootPart then return end
            
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {player.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            
            local directions = {
                rootPart.CFrame.RightVector,
                -rootPart.CFrame.RightVector,
                rootPart.CFrame.LookVector,
                -rootPart.CFrame.LookVector
            }
            
            local isNearWall = false
            for _, direction in ipairs(directions) do
                local raycast = Workspace:Raycast(rootPart.Position, direction * 3, raycastParams)
                if raycast and raycast.Instance and raycast.Normal.Y < 0.1 then
                    isNearWall = true
                    break
                end
            end
            
            if isNearWall then
                rootPart.Velocity = Vector3.new(rootPart.Velocity.X, getSettingValue("WallClimbSpeed", defaultSettings.WallClimbSpeed), rootPart.Velocity.Z)
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
        
        connections.wallClimbInput = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or not Movement.wallClimbEnabled then return end
            if input.KeyCode == Enum.KeyCode.C then
                Movement.wallClimbEnabled = not Movement.wallClimbEnabled
                updateButtonState("Wall Climb", Movement.wallClimbEnabled)
            end
        end)
        
        connections.wallClimbButton = wallClimbButton.MouseButton1Click:Connect(function()
            Movement.wallClimbEnabled = not Movement.wallClimbEnabled
            updateButtonState("Wall Climb", Movement.wallClimbEnabled)
            wallClimbButton.BackgroundColor3 = Movement.wallClimbEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 255, 255)
            wallClimbButton.Text = Movement.wallClimbEnabled and "CLIMBING" or "CLIMB"
        end)
    else
        if wallClimbButton then
            wallClimbButton.Visible = false
            wallClimbButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            wallClimbButton.Text = "CLIMB"
        end
    end
end

local function toggleBunnyHop(enabled)
    Movement.bunnyHopEnabled = enabled
    updateButtonState("Bunny Hop", enabled)

    if connections.bunnyHop then
        connections.bunnyHop:Disconnect()
        connections.bunnyHop = nil
    end

    if enabled then
        local airAccel = 100  
        connections.bunnyHop = RunService.Stepped:Connect(function(_, step)
            if not Movement.bunnyHopEnabled then return end
            if not refreshReferences() or not humanoid or not rootPart then return end
            if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then return end

            local moveDir = humanoid.MoveDirection
            if moveDir.Magnitude == 0 then return end

            local wishSpeed = humanoid.WalkSpeed
            local vel = rootPart.Velocity
            local horizVel = Vector3.new(vel.X, 0, vel.Z)
            local speed = horizVel:Dot(moveDir)

            if speed < wishSpeed then
                local addSpeed = wishSpeed - speed
                local accel = airAccel * wishSpeed * step
                if accel > addSpeed then accel = addSpeed end
                rootPart.Velocity = vel + moveDir * accel
            end
        end)
    end
end

local function toggleFly(enabled)
    Movement.flyEnabled = enabled
    updateButtonState("Fly", enabled)
    
    if enabled then
        sendServerMessage("FLY ACTIVATED")
    else
        sendServerMessage("FLY DEACTIVATED") 
    end
    
    local flyConnections = {"fly", "flyBegan", "flyChanged", "flyEnded", "flyUp", "flyUpEnd", "flyDown", "flyDownEnd", "flyKeyBegan", "flyKeyEnded"}
    for _, connName in ipairs(flyConnections) do
        if connections[connName] then
            connections[connName]:Disconnect()
            connections[connName] = nil
        end
    end
    
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if flyBodyGyro then
        flyBodyGyro:Destroy() 
        flyBodyGyro = nil
    end
    
    if enabled then
        if not refreshReferences() then
            Movement.flyEnabled = false
            updateButtonState("Fly", false)
            return
        end
        
        if not humanoid or not rootPart then
            Movement.flyEnabled = false
            updateButtonState("Fly", false)
            return
        end
        
        humanoid.PlatformStand = true
        
        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        flyBodyVelocity.Parent = rootPart
        
        flyBodyGyro = Instance.new("BodyGyro")
        flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        flyBodyGyro.P = 10000
        flyBodyGyro.CFrame = rootPart.CFrame
        flyBodyGyro.Parent = rootPart
        
        if flyJoystickFrame then flyJoystickFrame.Visible = true end
        if flyUpButton then flyUpButton.Visible = true end  
        if flyDownButton then flyDownButton.Visible = true end
        
        connections.fly = RunService.Heartbeat:Connect(function()
            if not Movement.flyEnabled then 
                return 
            end
            
            if not flyBodyVelocity or not flyBodyVelocity.Parent then
                flyBodyVelocity = Instance.new("BodyVelocity")
                flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                flyBodyVelocity.Parent = rootPart
            end
            
            if not flyBodyGyro or not flyBodyGyro.Parent then
                flyBodyGyro = Instance.new("BodyGyro")
                flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                flyBodyGyro.P = 10000
                flyBodyGyro.CFrame = rootPart.CFrame
                flyBodyGyro.Parent = rootPart
            end
            
            local camera = Workspace.CurrentCamera
            if not camera then return end
            
            flyBodyGyro.CFrame = camera.CFrame
            
            local speed = getSettingValue("FlySpeed", defaultSettings.FlySpeed)
            local moveVector = Vector3.new(0, 0, 0)
            
            if joystickDelta.Magnitude > 0.05 then
                moveVector = moveVector + (camera.CFrame.RightVector * joystickDelta.X) + (camera.CFrame.LookVector * -joystickDelta.Y)
            end
            
            if flyKeys.forward then 
                moveVector = moveVector + camera.CFrame.LookVector
            end
            if flyKeys.back then
                moveVector = moveVector - camera.CFrame.LookVector  
            end
            if flyKeys.left then
                moveVector = moveVector - camera.CFrame.RightVector
            end
            if flyKeys.right then
                moveVector = moveVector + camera.CFrame.RightVector
            end
            if flyKeys.up then
                moveVector = moveVector + Vector3.new(0, 1, 0)
            end
            if flyKeys.down then
                moveVector = moveVector - Vector3.new(0, 1, 0)
            end
            
            if moveVector.Magnitude > 0 then
                flyBodyVelocity.Velocity = moveVector.Unit * speed
            else
                flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end)
        
        connections.flyKeyBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            
            if input.KeyCode == Enum.KeyCode.W then
                flyKeys.forward = true
            elseif input.KeyCode == Enum.KeyCode.S then  
                flyKeys.back = true
            elseif input.KeyCode == Enum.KeyCode.A then
                flyKeys.left = true
            elseif input.KeyCode == Enum.KeyCode.D then
                flyKeys.right = true  
            elseif input.KeyCode == Enum.KeyCode.Space then
                flyKeys.up = true
            elseif input.KeyCode == Enum.KeyCode.LeftShift then
                flyKeys.down = true
            end
        end)
        
        connections.flyKeyEnded = UserInputService.InputEnded:Connect(function(input)
            if input.KeyCode == Enum.KeyCode.W then
                flyKeys.forward = false
            elseif input.KeyCode == Enum.KeyCode.S then
                flyKeys.back = false  
            elseif input.KeyCode == Enum.KeyCode.A then
                flyKeys.left = false
            elseif input.KeyCode == Enum.KeyCode.D then
                flyKeys.right = false
            elseif input.KeyCode == Enum.KeyCode.Space then
                flyKeys.up = false
            elseif input.KeyCode == Enum.KeyCode.LeftShift then
                flyKeys.down = false
            end
        end)
        
        connections.flyBegan = UserInputService.InputBegan:Connect(handleFlyJoystick)
        connections.flyChanged = UserInputService.InputChanged:Connect(handleFlyJoystick)
        connections.flyEnded = UserInputService.InputEnded:Connect(handleFlyJoystick)
        
        connections.flyUp = flyUpButton.MouseButton1Down:Connect(function()
            flyKeys.up = true
        end)
        connections.flyUpEnd = flyUpButton.MouseButton1Up:Connect(function()
            flyKeys.up = false
        end)
        connections.flyDown = flyDownButton.MouseButton1Down:Connect(function()
            flyKeys.down = true
        end)
        connections.flyDownEnd = flyDownButton.MouseButton1Up:Connect(function()
            flyKeys.down = false
        end)
        
    else
        if humanoid then
            humanoid.PlatformStand = false
        end
        
        if flyJoystickFrame then flyJoystickFrame.Visible = false end
        if flyUpButton then flyUpButton.Visible = false end
        if flyDownButton then flyDownButton.Visible = false end
        
        flyKeys = {forward = false, back = false, left = false, right = false, up = false, down = false}
        joystickDelta = Vector2.new(0, 0)
        isTouchingJoystick = false
        joystickTouchId = nil
    end
end

local function setupChatCommands()
    
    if connections.chatCommand then
        connections.chatCommand:Disconnect()
        connections.chatCommand = nil
    end
    
    if player and player.Chatted then
        connections.chatCommand = player.Chatted:Connect(function(message)
            
            local args = {}
            for word in message:gmatch("%S+") do
                table.insert(args, word)
            end
            local cmd = string.lower(args[1] or "")
            
            if cmd == "/fly" then
                toggleFly(true)
            elseif cmd == "/unfly" then
                toggleFly(false)
            elseif cmd == "/flyspeed" then
                local val = tonumber(args[2])
                if val then
                    settings.FlySpeed = {value = val}
                    sendServerMessage("Fly speed set to " .. val)
                    if Movement.flyEnabled then
                        toggleFly(false)
                        toggleFly(true)
                    end
                end
            elseif cmd == "/speed" then
                local val = tonumber(args[2])
                if val then
                    settings.WalkSpeed = {value = math.clamp(val, 1, 50)}
                    sendServerMessage("Speed set to " .. settings.WalkSpeed.value)
                    if Movement.speedEnabled then
                        toggleSpeed(true)
                    end
                end
            elseif cmd == "/jump" then
                local val = tonumber(args[2])
                if val then
                    settings.JumpHeight = {value = val}
                    sendServerMessage("Jump height set to " .. val)
                    if Movement.jumpEnabled then
                        toggleJump(true)
                    end
                end
            elseif cmd == "/sprint" then
                local val = tonumber(args[2])
                if val then
                    settings.SprintSpeed = {value = math.max(val, 50)}
                    sendServerMessage("Sprint speed set to " .. settings.SprintSpeed.value)
                    if Movement.sprintEnabled then
                    end
                end
            elseif cmd == "/swim" then
                local val = tonumber(args[2])
                if val then
                    settings.SwimSpeed = {value = val}
                    sendServerMessage("Swim speed set to " .. val)
                    if Movement.swimEnabled then
                        toggleSwim(true)
                    end
                end
            end
        end)
    end
end

local function toggleNoclip(enabled)
    Movement.noclipEnabled = enabled
    updateButtonState("NoClip", enabled)
    
    if connections.noclip then
        connections.noclip:Disconnect()
        connections.noclip = nil
    end
    
    if enabled then
        connections.noclip = RunService.Stepped:Connect(function()
            if not Movement.noclipEnabled then return end
            if not refreshReferences() or not player.Character then return end
            
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    else
        if refreshReferences() and player.Character then
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

local function toggleWalkOnWater(enabled)
    Movement.walkOnWaterEnabled = enabled
    updateButtonState("Walk on Water", enabled)
    
    if connections.walkOnWater then
        connections.walkOnWater:Disconnect()
        connections.walkOnWater = nil
    end
    
    if refreshReferences() and humanoid then
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, not enabled)
    end
    
    if enabled then
        connections.walkOnWater = RunService.Heartbeat:Connect(function()
            if not Movement.walkOnWaterEnabled then return end
            if not refreshReferences() or not rootPart or not player.Character then return end
            
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {player.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            
            local raycast = Workspace:Raycast(rootPart.Position, Vector3.new(0, -20, 0), raycastParams)
            if raycast and raycast.Instance and (raycast.Instance.Material == Enum.Material.Water or string.lower(raycast.Instance.Name):find("water")) then
                local waterWalkPart = rootPart:FindFirstChild("WaterWalkPart")
                if not waterWalkPart then
                    waterWalkPart = Instance.new("Part")
                    waterWalkPart.Name = "WaterWalkPart"
                    waterWalkPart.Anchored = true
                    waterWalkPart.CanCollide = true
                    waterWalkPart.Transparency = 1
                    waterWalkPart.Size = Vector3.new(15, 0.2, 15)
                    waterWalkPart.Parent = rootPart
                end
                waterWalkPart.Position = Vector3.new(rootPart.Position.X, raycast.Position.Y + 0.1, rootPart.Position.Z)
            end
        end)
    end
end

local function togglePlayerNoclip(enabled)
    Movement.playerNoclipEnabled = enabled
    updateButtonState("Player NoClip", enabled)
    
    if connections.playerNoclip then
        connections.playerNoclip:Disconnect()
        connections.playerNoclip = nil
    end
    if connections.antiFling then
        connections.antiFling:Disconnect()
        connections.antiFling = nil
    end
    
    if enabled then
        connections.playerNoclip = RunService.Heartbeat:Connect(function()
            if not Movement.playerNoclipEnabled then return end
            if not refreshReferences() or not player.Character then return end
            
            for _, otherPlayer in pairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character then
                    for _, part in pairs(otherPlayer.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end
        end)
        
        connections.antiFling = RunService.Heartbeat:Connect(function()
            if not Movement.playerNoclipEnabled then return end
            if not refreshReferences() or not rootPart then return end
            
            local currentVelocity = rootPart.Velocity
            local maxNormalVelocity = 200
            
            if currentVelocity.Magnitude > maxNormalVelocity then
                rootPart.Velocity = Vector3.new(0, 0, 0)
                
                local bodyAngularVelocity = rootPart:FindFirstChild("BodyAngularVelocity")
                if bodyAngularVelocity then
                    bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
                end
            end
            
            for _, otherPlayer in pairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local otherRoot = otherPlayer.Character.HumanoidRootPart
                    
                    for _, obj in pairs(otherRoot:GetChildren()) do
                        if obj:IsA("BodyVelocity") or obj:IsA("BodyPosition") or obj:IsA("BodyAngularVelocity") then
                            if obj:IsA("BodyVelocity") and obj.Velocity.Magnitude > maxNormalVelocity then
                                obj:Destroy()
                            elseif obj:IsA("BodyPosition") and (obj.Position - rootPart.Position).Magnitude > 1000 then
                                obj:Destroy()
                            elseif obj:IsA("BodyAngularVelocity") and obj.AngularVelocity.Magnitude > 50 then
                                obj:Destroy()
                            end
                        end
                    end
                end
            end
        end)
    else
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

local function toggleSwim(enabled)
    Movement.swimEnabled = enabled
    updateButtonState("Super Swim", enabled)
    
    if connections.swim then
        connections.swim:Disconnect()
        connections.swim = nil
    end
    
    if enabled then
        connections.swim = RunService.Heartbeat:Connect(function()
            if not Movement.swimEnabled then return end
            if not refreshReferences() or not humanoid then return end
            
            local baseSpeed = Movement.defaultWalkSpeed
            if Movement.speedEnabled then baseSpeed = getSettingValue("WalkSpeed", defaultSettings.WalkSpeed) end
            if Movement.isSprinting then baseSpeed = getSettingValue("SprintSpeed", defaultSettings.SprintSpeed) end
            
            if humanoid:GetState() == Enum.HumanoidStateType.Swimming then
                humanoid.WalkSpeed = getSettingValue("SwimSpeed", defaultSettings.SwimSpeed)
            else
                humanoid.WalkSpeed = baseSpeed
            end
        end)
    else
        if refreshReferences() and humanoid then
            humanoid.WalkSpeed = Movement.defaultWalkSpeed
        end
    end
end

function Movement.applySettings()
    if Movement.speedEnabled then
        toggleSpeed(true)
    end
    
    if Movement.jumpEnabled then
        toggleJump(true)
    end
    
    if Movement.sprintEnabled then
    end
end

function Movement.loadMovementButtons(createButton, createToggleButton)
    if not createButton or not createToggleButton then
        warn("Error: createButton or createToggleButton not provided!")
        return
    end
    
    setupScrollFrame()
    createSettingsGUI()
    
    createToggleButton("Speed Hack", toggleSpeed)
    createToggleButton("Jump Hack", toggleJump)
    createToggleButton("Moon Gravity", toggleMoonGravity)
    createToggleButton("Double Jump", toggleDoubleJump)
    createToggleButton("Infinite Jump", toggleInfiniteJump)
    createToggleButton("Wall Climb", toggleWallClimb)
    createToggleButton("Player NoClip", togglePlayerNoclip)
    createToggleButton("Fly", toggleFly)
    createToggleButton("NoClip", toggleNoclip)
    createToggleButton("Walk on Water", toggleWalkOnWater)
    createToggleButton("Super Swim", toggleSwim)
    createToggleButton("Float", toggleFloat)
    createToggleButton("Smooth Rewind", toggleRewind)
    createToggleButton("Boost (NOS)", toggleBoost)
    createToggleButton("Slow Fall", toggleSlowFall)
    createToggleButton("Fast Fall", toggleFastFall)
    createToggleButton("Sprint", toggleSprint)
    createToggleButton("Bunny Hop", toggleBunnyHop)
    
    local settingsButton = createButton("Settings", function()
        settingsFrame.Visible = not settingsFrame.Visible
    end)
    settingsButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    settingsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
end

function Movement.resetStates()
    isRespawning = true
    
    Movement.speedEnabled = false
    Movement.jumpEnabled = false
    Movement.flyEnabled = false
    Movement.noclipEnabled = false
    Movement.infiniteJumpEnabled = false
    Movement.walkOnWaterEnabled = false
    Movement.swimEnabled = false
    Movement.moonGravityEnabled = false
    Movement.doubleJumpEnabled = false
    Movement.wallClimbEnabled = false
    Movement.playerNoclipEnabled = false
    Movement.floatEnabled = false
    Movement.rewindEnabled = false
    Movement.boostEnabled = false
    Movement.slowFallEnabled = false
    Movement.fastFallEnabled = false
    Movement.sprintEnabled = false
    Movement.bunnyHopEnabled = false
    Movement.isSprinting = false
    Movement.isRewinding = false
    
    updateButtonState("Speed Hack", false)
    updateButtonState("Jump Hack", false)
    updateButtonState("Moon Gravity", false)
    updateButtonState("Double Jump", false)
    updateButtonState("Infinite Jump", false)
    updateButtonState("Wall Climb", false)
    updateButtonState("Player NoClip", false)
    updateButtonState("Fly", false)
    updateButtonState("NoClip", false)
    updateButtonState("Walk on Water", false)
    updateButtonState("Super Swim", false)
    updateButtonState("Float", false)
    updateButtonState("Smooth Rewind", false)
    updateButtonState("Boost (NOS)", false)
    updateButtonState("Slow Fall", false)
    updateButtonState("Fast Fall", false)
    updateButtonState("Sprint", false)
    updateButtonState("Bunny Hop", false)
    
    local allConnections = {
        "fly", "noclip", "playerNoclip", "infiniteJump", "walkOnWater", "doubleJump", 
        "wallClimb", "flyBegan", "flyChanged", "flyEnded", "flyUp", "flyUpEnd", "flyDown", "flyDownEnd", "wallClimbInput", "float", "floatBegan", "floatChanged", "floatEnded", "antiFling", 
        "rewind", "rewindInput", 
        "rewindToggle", "boost", "boostInput", "boostToggle", "slowFall", 
        "fastFall", "sprint", "sprintInput", "sprintToggle", "flyKeyBegan", 
        "flyKeyEnded", "floatKeyBegan", "floatKeyEnded", "wallClimbButton",
        "swim", "chat", "chatInput", "chatMonitor", "bunnyHop", "floatUp", "floatUpEnd", "floatDown", "floatDownEnd"
    }
    for _, connName in ipairs(allConnections) do
        if connections[connName] then
            connections[connName]:Disconnect()
            connections[connName] = nil
        end
    end
    
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if flyBodyGyro then
        flyBodyGyro:Destroy()
        flyBodyGyro = nil
    end
    
    if refreshReferences() then
        if humanoid then
            humanoid.WalkSpeed = Movement.defaultWalkSpeed
            humanoid.PlatformStand = false
            if humanoid:FindFirstChild("JumpHeight") then
                humanoid.JumpHeight = Movement.defaultJumpHeight
            else
                humanoid.JumpPower = Movement.defaultJumpPower
            end
            pcall(function()
                humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            end)
        end
        
        if player.Character then
            for _, part in pairs(player.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
    
    Workspace.Gravity = Movement.defaultGravity
    
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character then
            for _, part in pairs(otherPlayer.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
    
    if flyJoystickFrame then
        flyJoystickFrame.Visible = false
        flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
    end
    if flyUpButton then
        flyUpButton.Visible = false
        flyUpButton.BackgroundTransparency = 0.5
    end
    if flyDownButton then
        flyDownButton.Visible = false
        flyDownButton.BackgroundTransparency = 0.5
    end
    if rewindButton then
        rewindButton.Visible = false
        rewindButton.Text = "⏪"
    end
    if boostButton then
        boostButton.Visible = false
        boostButton.Text = "BOOST"
    end
    if sprintButton then
        sprintButton.Visible = false
        sprintButton.Text = "SPRINT"
    end
    if wallClimbButton then
        wallClimbButton.Visible = false
        wallClimbButton.Text = "CLIMB"
    end
    if rewindText then
        rewindText.Visible = false
    end
    
    Movement.jumpCount = 0
    joystickDelta = Vector2.new(0, 0)
    isTouchingJoystick = false
    joystickTouchId = nil
    positionHistory = {}
    isBoostActive = false
    isRespawning = false
end

function Movement.updateReferences(newHumanoid, newRootPart)
    humanoid = newHumanoid
    rootPart = newRootPart
    
    if humanoid then
        Movement.defaultWalkSpeed = humanoid.WalkSpeed or 16
        if humanoid:FindFirstChild("JumpHeight") then
            Movement.defaultJumpHeight = humanoid.JumpHeight or 7.2
        else
            Movement.defaultJumpPower = humanoid.JumpPower or 50
        end
    end
    Movement.defaultGravity = Workspace.Gravity or 196.2
    
    createMobileControls()
    createSettingsGUI()
    
    task.spawn(function()
        task.wait(0.3)
        
        for featureName, enabled in pairs({
            ["Speed Hack"] = Movement.speedEnabled,
            ["Jump Hack"] = Movement.jumpEnabled,
            ["Moon Gravity"] = Movement.moonGravityEnabled,
            ["Double Jump"] = Movement.doubleJumpEnabled,
            ["Infinite Jump"] = Movement.infiniteJumpEnabled,
            ["Wall Climb"] = Movement.wallClimbEnabled,
            ["Player NoClip"] = Movement.playerNoclipEnabled,
            ["Fly"] = Movement.flyEnabled,
            ["NoClip"] = Movement.noclipEnabled,
            ["Walk on Water"] = Movement.walkOnWaterEnabled,
            ["Super Swim"] = Movement.swimEnabled,
            ["Float"] = Movement.floatEnabled,
            ["Smooth Rewind"] = Movement.rewindEnabled,
            ["Boost (NOS)"] = Movement.boostEnabled,
            ["Slow Fall"] = Movement.slowFallEnabled,
            ["Fast Fall"] = Movement.fastFallEnabled,
            ["Sprint"] = Movement.sprintEnabled,
            ["Bunny Hop"] = Movement.bunnyHopEnabled
        }) do
            updateButtonState(featureName, enabled)
        end
        
        
        setupChatCommands()
    end)
end

function Movement.init(deps)
    if not deps then
        warn("Error: No dependencies provided!")
        return false
    end
    
    Players = deps.Players or game:GetService("Players")
    RunService = deps.RunService or game:GetService("RunService")
    Workspace = deps.Workspace or game:GetService("Workspace")
    UserInputService = deps.UserInputService or game:GetService("UserInputService")
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    connections = deps.connections or {}
    buttonStates = deps.buttonStates or {}
    ScrollFrame = deps.ScrollFrame
    ScreenGui = deps.ScreenGui
    settings = deps.settings or {}
    player = deps.player or Players.LocalPlayer
    
    if not Players or not RunService or not Workspace or not UserInputService then
        warn("Critical services missing!")
        return false
    end
    
    
    for k, v in pairs(defaultSettings) do
        if not settings[k] then
            settings[k] = {value = v}
        end
    end
    if not settings.RewindMode then
        settings.RewindMode = "medium"
    end
    currentRewindMode = settings.RewindMode
    
    Movement.speedEnabled = false
    Movement.jumpEnabled = false
    Movement.flyEnabled = false
    Movement.noclipEnabled = false
    Movement.infiniteJumpEnabled = false
    Movement.walkOnWaterEnabled = false
    Movement.swimEnabled = false
    Movement.moonGravityEnabled = false
    Movement.doubleJumpEnabled = false
    Movement.wallClimbEnabled = false
    Movement.playerNoclipEnabled = false
    Movement.floatEnabled = false
    Movement.rewindEnabled = false
    Movement.boostEnabled = false
    Movement.slowFallEnabled = false
    Movement.fastFallEnabled = false
    Movement.sprintEnabled = false
    Movement.bunnyHopEnabled = false
    Movement.isSprinting = false
    Movement.isRewinding = false
    
    Movement.jumpCount = 0
    joystickDelta = Vector2.new(0, 0)
    isTouchingJoystick = false
    joystickTouchId = nil
    positionHistory = {}
    isBoostActive = false
    isRespawning = false
    
    createMobileControls()
    createSettingsGUI()
    setupScrollFrame()
    setupChatCommands()
    
    connections.characterRemoving = player.CharacterRemoving:Connect(function()
        if not Movement.persistFeatures then
            Movement.resetStates()
        end
    end)

    connections.characterAdded = player.CharacterAdded:Connect(function(character)
        local newHumanoid = character:WaitForChild("Humanoid", 5)
        local newRootPart = character:WaitForChild("HumanoidRootPart", 5)
        Movement.updateReferences(newHumanoid, newRootPart)

        if Movement.persistFeatures then
            if Movement.speedEnabled then toggleSpeed(true) end
            if Movement.jumpEnabled then toggleJump(true) end
            if Movement.flyEnabled then toggleFly(true) end
            if Movement.noclipEnabled then toggleNoclip(true) end
            if Movement.infiniteJumpEnabled then toggleInfiniteJump(true) end
            if Movement.walkOnWaterEnabled then toggleWalkOnWater(true) end
            if Movement.swimEnabled then toggleSwim(true) end
            if Movement.moonGravityEnabled then toggleMoonGravity(true) end
            if Movement.doubleJumpEnabled then toggleDoubleJump(true) end
            if Movement.wallClimbEnabled then toggleWallClimb(true) end
            if Movement.playerNoclipEnabled then togglePlayerNoclip(true) end
            if Movement.floatEnabled then toggleFloat(true) end
            if Movement.rewindEnabled then toggleRewind(true) end
            if Movement.boostEnabled then toggleBoost(true) end
            if Movement.slowFallEnabled then toggleSlowFall(true) end
            if Movement.fastFallEnabled then toggleFastFall(true) end
            if Movement.bunnyHopEnabled then toggleBunnyHop(true) end
        end
    end)
    
    return true
end

function Movement.cleanup()
    Movement.resetStates()
    
    if flyJoystickFrame then flyJoystickFrame:Destroy() end
    if flyUpButton then flyUpButton:Destroy() end
    if flyDownButton then flyDownButton:Destroy() end
    if rewindButton then rewindButton:Destroy() end
    if boostButton then boostButton:Destroy() end
    if sprintButton then sprintButton:Destroy() end
    if wallClimbButton then wallClimbButton:Destroy() end
    if settingsFrame then settingsFrame:Destroy() end
    if rewindText then rewindText:Destroy() end
    
    flyJoystickFrame = nil
    flyJoystickKnob = nil
    flyUpButton = nil
    flyDownButton = nil
    flyBodyVelocity = nil
    flyBodyGyro = nil
    rewindButton = nil
    boostButton = nil
    sprintButton = nil
    wallClimbButton = nil
    settingsFrame = nil
    rewindText = nil
    
    positionHistory = {}
    isBoostActive = false
    isRespawning = false
end

return Movement