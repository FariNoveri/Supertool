-- Settings.lua
-- Settings features for MinimalHackGUI by Fari Noveri

local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

-- Settings variables
local settings = {
    uiScale = 1, -- Default UI scale (1 = 100%)
    toggleKey = Enum.KeyCode.Insert, -- Default key to toggle GUI
    notificationsEnabled = true, -- Default notification setting
    FlashlightBrightness = { value = 5, default = 5, min = 1, max = 10 },
    FlashlightRange = { value = 100, default = 100, min = 50, max = 200 },
    FullbrightBrightness = { value = 2, default = 2, min = 0, max = 5 },
    FreecamSpeed = { value = 80, default = 80, min = 20, max = 300 }
}
local filePath = "DCIM/Supertool/settings.json"
local inputConnection

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
            settings.FlashlightBrightness.value = data.FlashlightBrightness or settings.FlashlightBrightness.default
            settings.FlashlightRange.value = data.FlashlightRange or settings.FlashlightRange.default
            settings.FullbrightBrightness.value = data.FullbrightBrightness or settings.FullbrightBrightness.default
            settings.FreecamSpeed.value = data.FreecamSpeed or settings.FreecamSpeed.default
            if utils and utils.notify then
                utils.notify("Loaded settings from " .. filePath)
            else
                print("Loaded settings from " .. filePath)
            end
        else
            if utils and utils.notify then
                utils.notify("Failed to load settings from " .. filePath)
            else
                print("Failed to load settings from " .. filePath)
            end
        end
    else
        if utils and utils.notify then
            utils.notify("No settings file found at " .. filePath)
        else
            print("No settings file found at " .. filePath)
        end
    end
end

-- Save settings to file
local function saveSettings()
    local success, error = pcall(function()
        local data = {
            uiScale = settings.uiScale,
            toggleKey = settings.toggleKey.Name,
            notificationsEnabled = settings.notificationsEnabled,
            FlashlightBrightness = settings.FlashlightBrightness.value,
            FlashlightRange = settings.FlashlightRange.value,
            FullbrightBrightness = settings.FullbrightBrightness.value,
            FreecamSpeed = settings.FreecamSpeed.value
        }
        writefile(filePath, HttpService:JSONEncode(data))
        if utils and utils.notify then
            utils.notify("Saved settings to " .. filePath)
        else
            print("Saved settings to " .. filePath)
        end
    end)
    if not success then
        if utils and utils.notify then
            utils.notify("Failed to save settings to " .. filePath .. ": " .. tostring(error))
        else
            warn("Failed to save settings to " .. filePath .. ": " .. tostring(error))
        end
    end
end

-- Initialize Settings
local function initializeSettings()
    loadSettings()
    local screenGui = CoreGui:FindFirstChild("MinimalHackGUI")
    if screenGui and screenGui:FindFirstChild("UIScale") then
        screenGui.UIScale.Scale = settings.uiScale
    end
end

-- Load buttons for mainloader.lua
local function loadButtons(scrollFrame, utils)
    initializeSettings()

    -- UI Scale Slider
    utils.createSlider("UI Scale", 0.5, 2, settings.uiScale, function(value)
        settings.uiScale = value
        local screenGui = CoreGui:FindFirstChild("MinimalHackGUI")
        if screenGui and screenGui:FindFirstChild("UIScale") then
            screenGui.UIScale.Scale = value
        end
        saveSettings()
        if utils.notify then
            utils.notify("UI Scale set to " .. value)
        else
            print("UI Scale set to " .. value)
        end
    end).Parent = scrollFrame

    -- Toggle Keybind
    utils.createKeybind("Toggle GUI Key", settings.toggleKey, function(key)
        settings.toggleKey = key
        saveSettings()
        if utils.notify then
            utils.notify("Toggle GUI key set to " .. key.Name)
        else
            print("Toggle GUI key set to " .. key.Name)
        end
    end).Parent = scrollFrame

    -- Notifications Toggle
    utils.createToggle("Notifications", settings.notificationsEnabled, function(state)
        settings.notificationsEnabled = state
        saveSettings()
        if utils.notify then
            utils.notify("Notifications " .. (state and "enabled" or "disabled"))
        else
            print("Notifications " .. (state and "enabled" or "disabled"))
        end
    end).Parent = scrollFrame

    -- Flashlight Brightness Slider
    utils.createSlider("Flashlight Brightness", settings.FlashlightBrightness.min, settings.FlashlightBrightness.max, settings.FlashlightBrightness.value, function(value)
        settings.FlashlightBrightness.value = value
        saveSettings()
        if utils.notify then
            utils.notify("Flashlight Brightness set to " .. value)
        else
            print("Flashlight Brightness set to " .. value)
        end
    end).Parent = scrollFrame

    -- Flashlight Range Slider
    utils.createSlider("Flashlight Range", settings.FlashlightRange.min, settings.FlashlightRange.max, settings.FlashlightRange.value, function(value)
        settings.FlashlightRange.value = value
        saveSettings()
        if utils.notify then
            utils.notify("Flashlight Range set to " .. value)
        else
            print("Flashlight Range set to " .. value)
        end
    end).Parent = scrollFrame

    -- Fullbright Brightness Slider
    utils.createSlider("Fullbright Brightness", settings.FullbrightBrightness.min, settings.FullbrightBrightness.max, settings.FullbrightBrightness.value, function(value)
        settings.FullbrightBrightness.value = value
        saveSettings()
        if utils.notify then
            utils.notify("Fullbright Brightness set to " .. value)
        else
            print("Fullbright Brightness set to " .. value)
        end
    end).Parent = scrollFrame

    -- Freecam Speed Slider
    utils.createSlider("Freecam Speed", settings.FreecamSpeed.min, settings.FreecamSpeed.max, settings.FreecamSpeed.value, function(value)
        settings.FreecamSpeed.value = value
        saveSettings()
        if utils.notify then
            utils.notify("Freecam Speed set to " .. value)
        else
            print("Freecam Speed set to " .. value)
        end
    end).Parent = scrollFrame
end

-- Cleanup function
local function cleanup()
    if inputConnection then
        inputConnection:Disconnect()
        inputConnection = nil
    end
    saveSettings()
end

-- Cleanup on script destruction
local function onScriptDestroy()
    cleanup()
end

-- Connect cleanup to GUI destruction
local screenGui = CoreGui:FindFirstChild("MinimalHackGUI")
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
    reset = cleanup,
    settings = settings,
    notify = function(message)
        if settings.notificationsEnabled then
            if utils and utils.notify then
                utils.notify(message)
            else
                print(message)
            end
        end
    end
}