-- Settings.lua
-- Settings features for MinimalHackGUI by Fari Noveri

local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

-- Settings variables
local settings = {
    uiScale = 1, -- Default UI scale (1 = 100%)
    toggleKey = Enum.KeyCode.Insert, -- Default key to toggle GUI
    notificationsEnabled = true -- Default notification setting
}
local filePath = "DCIM/Supertool/settings.json"

-- Load settings from file
local function loadSettings()
    if isfile and isfile(filePath) then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(filePath))
        end)
        if success and data then
            settings.uiScale = data.uiScale or settings.uiScale
            settings.toggleKey = Enum.KeyCode[data.toggleKey] or settings.toggleKey
            settings.notificationsEnabled = data.notificationsEnabled ~= nil and data.notificationsEnabled
            print("Loaded settings from " .. filePath)
        else
            print("Failed to load settings from " .. filePath)
        end
    else
        print("No settings file found at " .. filePath)
    end
end

-- Save settings to file
local function saveSettings()
    local success, error = pcall(function()
        local data = {
            uiScale = settings.uiScale,
            toggleKey = settings.toggleKey.Name,
            notificationsEnabled = settings.notificationsEnabled
        }
        writefile(filePath, HttpService:JSONEncode(data))
        print("Saved settings to " .. filePath)
    end)
    if not success then
        warn("Failed to save settings to " .. filePath .. ": " .. tostring(error))
    end
end

-- Notify function (aligned with mainloader.lua style)
local function notify(message)
    if settings.notificationsEnabled then
        print(message)
        if saymsg then
            pcall(function()
                saymsg(message)
            end)
        end
    end
end

-- Button creation function
local function createButton(name, callback)
    local button = Instance.new("TextButton")
    button.Name = name .. "Button"
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 30)
    button.Font = Enum.Font.Gotham
    button.Text = name:upper()
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 11
    
    button.MouseButton1Click:Connect(callback)
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    end)
    
    return button
end

-- Slider creation function
local function createSlider(name, min, max, default, callback)
    local frame = Instance.new("Frame")
    frame.Name = name .. "Slider"
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(1, 0, 0, 50)

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Parent = frame
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 5, 0, 5)
    label.Size = UDim2.new(0.5, -5, 0, 20)
    label.Font = Enum.Font.Gotham
    label.Text = name:upper()
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left

    local sliderBar = Instance.new("Frame")
    sliderBar.Name = "SliderBar"
    sliderBar.Parent = frame
    sliderBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    sliderBar.BorderSizePixel = 0
    sliderBar.Position = UDim2.new(0, 5, 0, 30)
    sliderBar.Size = UDim2.new(1, -10, 0, 10)

    local sliderKnob = Instance.new("TextButton")
    sliderKnob.Name = "SliderKnob"
    sliderKnob.Parent = sliderBar
    sliderKnob.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    sliderKnob.BorderSizePixel = 0
    sliderKnob.Size = UDim2.new(0, 10, 0, 10)
    sliderKnob.Position = UDim2.new((default - min) / (max - min), -5, 0, 0)
    sliderKnob.Text = ""

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "ValueLabel"
    valueLabel.Parent = frame
    valueLabel.BackgroundTransparency = 1
    valueLabel.Position = UDim2.new(0.5, 5, 0, 5)
    valueLabel.Size = UDim2.new(0.5, -10, 0, 20)
    valueLabel.Font = Enum.Font.Gotham
    valueLabel.Text = tostring(default)
    valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueLabel.TextSize = 11
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right

    local dragging = false
    sliderKnob.MouseButton1Down:Connect(function()
        dragging = true
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mouseX = input.Position.X
            local barX, barWidth = sliderBar.AbsolutePosition.X, sliderBar.AbsoluteSize.X
            local relativeX = math.clamp((mouseX - barX) / barWidth, 0, 1)
            sliderKnob.Position = UDim2.new(relativeX, -5, 0, 0)
            local value = min + (max - min) * relativeX
            value = math.round(value * 100) / 100 -- Round to 2 decimal places
            valueLabel.Text = tostring(value)
            callback(value)
        end
    end)

    return frame
end

-- Toggle creation function
local function createToggle(name, default, callback)
    local frame = Instance.new("Frame")
    frame.Name = name .. "Toggle"
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(1, 0, 0, 30)

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Parent = frame
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 5, 0, 5)
    label.Size = UDim2.new(0.5, -5, 0, 20)
    label.Font = Enum.Font.Gotham
    label.Text = name:upper()
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left

    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Parent = frame
    toggleButton.BackgroundColor3 = default and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(80, 40, 40)
    toggleButton.BorderSizePixel = 0
    toggleButton.Position = UDim2.new(0.5, 5, 0, 5)
    toggleButton.Size = UDim2.new(0.5, -10, 0, 20)
    toggleButton.Font = Enum.Font.Gotham
    toggleButton.Text = default and "ON" or "OFF"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.TextSize = 11

    toggleButton.MouseButton1Click:Connect(function()
        local newState = not default
        toggleButton.BackgroundColor3 = newState and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(80, 40, 40)
        toggleButton.Text = newState and "ON" or "OFF"
        callback(newState)
        default = newState
    end)

    toggleButton.MouseEnter:Connect(function()
        toggleButton.BackgroundColor3 = default and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(100, 50, 50)
    end)

    toggleButton.MouseLeave:Connect(function()
        toggleButton.BackgroundColor3 = default and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(80, 40, 40)
    end)

    return frame
end

-- Keybind creation function
local function createKeybind(name, defaultKey, callback)
    local frame = Instance.new("Frame")
    frame.Name = name .. "Keybind"
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.BorderSizePixel = 0
    frame.Size = UDim2.new(1, 0, 0, 30)

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Parent = frame
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 5, 0, 5)
    label.Size = UDim2.new(0.5, -5, 0, 20)
    label.Font = Enum.Font.Gotham
    label.Text = name:upper()
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left

    local keybindButton = Instance.new("TextButton")
    keybindButton.Name = "KeybindButton"
    keybindButton.Parent = frame
    keybindButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    keybindButton.BorderSizePixel = 0
    keybindButton.Position = UDim2.new(0.5, 5, 0, 5)
    keybindButton.Size = UDim2.new(0.5, -10, 0, 20)
    keybindButton.Font = Enum.Font.Gotham
    keybindButton.Text = defaultKey.Name
    keybindButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    keybindButton.TextSize = 11

    local waitingForKey = false
    keybindButton.MouseButton1Click:Connect(function()
        waitingForKey = true
        keybindButton.Text = "Press a key..."
    end)

    local inputConnection
    inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if waitingForKey and input.UserInputType == Enum.UserInputType.Keyboard and not gameProcessed then
            local newKey = input.KeyCode
            if newKey ~= Enum.KeyCode.Unknown then
                keybindButton.Text = newKey.Name
                waitingForKey = false
                callback(newKey)
                inputConnection:Disconnect()
            end
        end
    end)

    return frame
end

-- Load settings buttons into a provided ScrollFrame
local function loadSettingsButtons(scrollFrame, screenGui)
    -- UI Scale Slider
    createSlider("UI Scale", 0.5, 2, settings.uiScale, function(value)
        settings.uiScale = value
        screenGui.UIScale.Scale = value
        saveSettings()
        notify("UI Scale set to " .. value)
    end).Parent = scrollFrame

    -- Toggle Keybind
    createKeybind("Toggle GUI Key", settings.toggleKey, function(key)
        settings.toggleKey = key
        saveSettings()
        notify("Toggle GUI key set to " .. key.Name)
    end).Parent = scrollFrame

    -- Notifications Toggle
    createToggle("Notifications", settings.notificationsEnabled, function(state)
        settings.notificationsEnabled = state
        saveSettings()
        notify("Notifications " .. (state and "enabled" or "disabled"))
    end).Parent = scrollFrame
end

-- Initialize Settings
local function initializeSettings()
    loadSettings()
end

-- Cleanup function
local function cleanup()
    -- No specific cleanup needed for settings
end

-- Bind cleanup to game close
game:BindToClose(cleanup)

-- Initialize
initializeSettings()

-- Return functions for external use
return {
    loadSettingsButtons = loadSettingsButtons,
    cleanup = cleanup,
    settings = settings, -- Expose settings for external access
    notify = notify -- Expose notify function for other modules
}