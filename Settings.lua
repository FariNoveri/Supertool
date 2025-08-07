local HttpService = game:GetService("HttpService")

local Settings = {}
local connections = {}
local directory = "dcim/supertool"
local settingsFile = directory .. "/settings.json"

-- Settings table
Settings.values = {
    FlySpeed = { value = 50, default = 50, min = 10, max = 200 },
    FreecamSpeed = { value = 80, default = 80, min = 20, max = 300 },
    JumpHeight = { value = 50, default = 50, min = 10, max = 150 },
    WalkSpeed = { value = 100, default = 100, min = 16, max = 300 },
    FlashlightBrightness = { value = 5, default = 5, min = 1, max = 10 },
    FlashlightRange = { value = 100, default = 100, min = 50, max = 200 },
    FullbrightBrightness = { value = 2, default = 2, min = 0, max = 5 }
}

-- Ensure directory exists
if not isfolder(directory) then
    makefolder(directory)
end

-- Load settings from file
function Settings.loadSettings()
    local success, content = pcall(readfile, settingsFile)
    if success then
        local success, data = pcall(function() return HttpService:JSONDecode(content) end)
        if success then
            for key, setting in pairs(Settings.values) do
                if data[key] and type(data[key]) == "number" then
                    setting.value = math.clamp(data[key], setting.min, setting.max)
                end
            end
            Settings.updateGui()
        end
    end
end

-- Save settings to file
function Settings.saveSettings()
    local data = {}
    for key, setting in pairs(Settings.values) do
        data[key] = setting.value
    end
    local json = HttpService:JSONEncode(data)
    local success, errorMsg = pcall(writefile, settingsFile, json)
    if not success then
        warn("Failed to save settings: " .. tostring(errorMsg))
    else
        print("Settings saved to " .. settingsFile)
    end
end

-- Get setting value
function Settings.getSetting(key)
    if Settings.values[key] then
        return Settings.values[key].value
    end
    return nil
end

-- Set setting value
function Settings.setSetting(key, value)
    if Settings.values[key] then
        local clampedValue = math.clamp(tonumber(value) or Settings.values[key].default, Settings.values[key].min, Settings.values[key].max)
        Settings.values[key].value = clampedValue
        Settings.saveSettings()
        Settings.updateGui()
        print("Set " .. key .. " to " .. clampedValue)
        return true
    end
    return false
end

-- Reset all settings to defaults
function Settings.resetSettings()
    for key, setting in pairs(Settings.values) do
        setting.value = setting.default
    end
    Settings.saveSettings()
    Settings.updateGui()
    print("Settings reset to defaults")
end

-- Update GUI elements
function Settings.updateGui()
    if not Settings.SettingsFrame or not Settings.SettingsScrollFrame or not Settings.SettingsLayout then
        return
    end
    for _, child in pairs(Settings.SettingsScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    local index = 0
    for key, setting in pairs(Settings.values) do
        index = index + 1
        local settingFrame = Instance.new("Frame")
        settingFrame.Name = key
        settingFrame.Parent = Settings.SettingsScrollFrame
        settingFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        settingFrame.BorderSizePixel = 0
        settingFrame.Size = UDim2.new(1, -5, 0, 50)
        settingFrame.LayoutOrder = index

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Parent = settingFrame
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.new(0, 5, 0, 5)
        nameLabel.Size = UDim2.new(0, 150, 0, 20)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Text = key
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left

        local valueInput = Instance.new("TextBox")
        valueInput.Name = "ValueInput"
        valueInput.Parent = settingFrame
        valueInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        valueInput.BorderSizePixel = 0
        valueInput.Position = UDim2.new(0, 160, 0, 10)
        valueInput.Size = UDim2.new(0, 80, 0, 25)
        valueInput.Font = Enum.Font.Gotham
        valueInput.Text = tostring(setting.value)
        valueInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        valueInput.TextSize = 12

        valueInput.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                Settings.setSetting(key, valueInput.Text)
            end
        end)

        valueInput.MouseEnter:Connect(function()
            valueInput.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        end)
        valueInput.MouseLeave:Connect(function()
            valueInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end)
    end
    wait(0.1)
    Settings.SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(Settings.SettingsLayout.AbsoluteContentSize.Y + 10, 30))
end

-- Set GUI elements
function Settings.setGuiElements(elements)
    Settings.SettingsFrame = elements.SettingsFrame
    Settings.SettingsScrollFrame = elements.SettingsScrollFrame
    Settings.SettingsLayout = elements.SettingsLayout
end

-- Cleanup
function Settings.cleanup()
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
end

-- Initialize settings
Settings.loadSettings()

return Settings