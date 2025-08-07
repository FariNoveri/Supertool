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
end

-- Cleanup function
local function cleanup()
    if inputConnection then
        inputConnection:Disconnect()
        inputConnection = nil
    end
    saveSettings() -- Save settings before cleanup
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