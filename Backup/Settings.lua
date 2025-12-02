-- settings.lua - Fixed version with Logo controls and Custom Keybind
-- Settings-related features for MinimalHackGUI by Fari Noveri

-- Dependencies: These must be passed from mainloader.lua
local ScreenGui, ScrollFrame, settings, Movement
local UserInputService = game:GetService("UserInputService")

-- Initialize module
local Settings = {}

-- Store slider references for updates
local sliders = {}

-- Store toggle states
local toggleStates = {
    EnableDrag = true,
    HideGUI = false
}

-- Current keybind (default: Home)
local currentKeybind = Enum.KeyCode.Home
local keybindButton = nil
local isWaitingForKey = false

-- Helper function to create a slider UI
local function createSlider(name, setting, min, max, default, parent)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Name = name .. "Slider"
    sliderFrame.Parent = parent
    sliderFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    sliderFrame.BorderSizePixel = 0
    sliderFrame.Size = UDim2.new(1, -5, 0, 60)
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = sliderFrame
    
    local sliderLabel = Instance.new("TextLabel")
    sliderLabel.Name = "Label"
    sliderLabel.Parent = sliderFrame
    sliderLabel.BackgroundTransparency = 1
    sliderLabel.Position = UDim2.new(0, 8, 0, 5)
    sliderLabel.Size = UDim2.new(1, -60, 0, 20)
    sliderLabel.Font = Enum.Font.GothamBold
    sliderLabel.Text = name:upper()
    sliderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    sliderLabel.TextSize = 11
    sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local sliderBar = Instance.new("Frame")
    sliderBar.Name = "SliderBar"
    sliderBar.Parent = sliderFrame
    sliderBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    sliderBar.BorderSizePixel = 0
    sliderBar.Position = UDim2.new(0, 8, 0, 30)
    sliderBar.Size = UDim2.new(1, -70, 0, 12)
    
    -- Add rounded corners to slider bar
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 6)
    barCorner.Parent = sliderBar
    
    local fillBar = Instance.new("Frame")
    fillBar.Name = "Fill"
    fillBar.Parent = sliderBar
    fillBar.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
    fillBar.BorderSizePixel = 0
    fillBar.Size = UDim2.new((setting.value - min) / (max - min), 0, 1, 0)
    
    -- Add rounded corners to fill bar
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 6)
    fillCorner.Parent = fillBar
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "Value"
    valueLabel.Parent = sliderFrame
    valueLabel.BackgroundTransparency = 1
    valueLabel.Position = UDim2.new(1, -55, 0, 5)
    valueLabel.Size = UDim2.new(0, 50, 0, 20)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.Text = tostring(setting.value)
    valueLabel.TextColor3 = Color3.fromRGB(70, 130, 180)
    valueLabel.TextSize = 11
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    
    local sliderButton = Instance.new("TextButton")
    sliderButton.Name = "SliderButton"
    sliderButton.Parent = sliderBar
    sliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sliderButton.BorderSizePixel = 0
    sliderButton.Position = UDim2.new((setting.value - min) / (max - min), -6, 0, -3)
    sliderButton.Size = UDim2.new(0, 12, 0, 18)
    sliderButton.Text = ""
    
    -- Add rounded corners to slider button
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 6)
    buttonCorner.Parent = sliderButton
    
    -- Store references
    sliders[name] = {
        frame = sliderFrame,
        fillBar = fillBar,
        sliderButton = sliderButton,
        valueLabel = valueLabel,
        setting = setting,
        min = min,
        max = max
    }
    
    local dragging = false
    
    -- Mouse/Touch input handling
    local function updateSlider(inputPosition)
        local barPos = sliderBar.AbsolutePosition.X
        local barWidth = sliderBar.AbsoluteSize.X
        local relativeX = math.clamp((inputPosition - barPos) / barWidth, 0, 1)
        
        -- Calculate new value and round it based on slider type
        local newValue
        if name == "Logo Opacity" then
            -- For opacity, use decimal precision
            newValue = min + (max - min) * relativeX
            newValue = math.floor(newValue * 100 + 0.5) / 100
        else
            -- For other values, use integer precision
            newValue = min + (max - min) * relativeX
            newValue = math.floor(newValue + 0.5)
        end
        
        -- Update setting value
        setting.value = newValue
        
        -- Update UI elements
        fillBar.Size = UDim2.new(relativeX, 0, 1, 0)
        sliderButton.Position = UDim2.new(relativeX, -6, 0, -3)
        valueLabel.Text = tostring(newValue)
        
        -- Apply changes immediately for active features
        Settings.applySettings()
    end
    
    -- Unified input handling for mouse and touch
    sliderBar.InputBegan:Connect(function(input)
        if not dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = true
            updateSlider(input.Position.X)
        end
    end)
    
    sliderBar.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input.Position.X)
        end
    end)
    
    sliderBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    -- Also handle on slider button for better touch targeting
    sliderButton.InputBegan:Connect(function(input)
        if not dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            dragging = true
            updateSlider(input.Position.X)
        end
    end)
    
    sliderButton.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input.Position.X)
        end
    end)
    
    sliderButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- Helper function to create a toggle button UI
local function createToggleButton(name, callback, parent)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Parent = parent
    button.BackgroundColor3 = toggleStates[name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -2, 0, 20)
    button.Font = Enum.Font.Gotham
    button.Text = name
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 8
    
    button.MouseButton1Click:Connect(function()
        local newState = not toggleStates[name]
        toggleStates[name] = newState
        button.BackgroundColor3 = newState and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
        if type(callback) == "function" then
            callback(newState)
        end
    end)
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = toggleStates[name] and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(80, 80, 80)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = toggleStates[name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    end)
end

-- Helper function to get key name
local function getKeyName(keyCode)
    local keyName = tostring(keyCode):gsub("Enum.KeyCode.", "")
    return keyName
end

-- Helper function to create keybind button
local function createKeybindButton(parent)
    local keybindFrame = Instance.new("Frame")
    keybindFrame.Name = "KeybindFrame"
    keybindFrame.Parent = parent
    keybindFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    keybindFrame.BorderSizePixel = 0
    keybindFrame.Size = UDim2.new(1, -5, 0, 45)
    
    -- Add rounded corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = keybindFrame
    
    local keybindLabel = Instance.new("TextLabel")
    keybindLabel.Name = "Label"
    keybindLabel.Parent = keybindFrame
    keybindLabel.BackgroundTransparency = 1
    keybindLabel.Position = UDim2.new(0, 8, 0, 5)
    keybindLabel.Size = UDim2.new(1, -16, 0, 15)
    keybindLabel.Font = Enum.Font.GothamBold
    keybindLabel.Text = "TOGGLE GUI KEYBIND"
    keybindLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    keybindLabel.TextSize = 11
    keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    keybindButton = Instance.new("TextButton")
    keybindButton.Name = "KeybindButton"
    keybindButton.Parent = keybindFrame
    keybindButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    keybindButton.BorderColor3 = Color3.fromRGB(100, 100, 100)
    keybindButton.BorderSizePixel = 1
    keybindButton.Position = UDim2.new(0, 8, 0, 22)
    keybindButton.Size = UDim2.new(1, -16, 0, 18)
    keybindButton.Font = Enum.Font.GothamBold
    keybindButton.Text = "Current: " .. getKeyName(currentKeybind)
    keybindButton.TextColor3 = Color3.fromRGB(100, 200, 255)
    keybindButton.TextSize = 9
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 4)
    buttonCorner.Parent = keybindButton
    
    -- Keybind button click handler
    keybindButton.MouseButton1Click:Connect(function()
        if isWaitingForKey then return end
        
        isWaitingForKey = true
        keybindButton.Text = "Press any key..."
        keybindButton.BackgroundColor3 = Color3.fromRGB(80, 80, 30)
        
        local connection
        connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local keyCode = input.KeyCode
                
                -- Ignore certain keys
                if keyCode == Enum.KeyCode.Unknown or 
                   keyCode == Enum.KeyCode.LeftShift or 
                   keyCode == Enum.KeyCode.RightShift or
                   keyCode == Enum.KeyCode.LeftControl or
                   keyCode == Enum.KeyCode.RightControl or
                   keyCode == Enum.KeyCode.LeftAlt or
                   keyCode == Enum.KeyCode.RightAlt then
                    return
                end
                
                -- Update keybind
                currentKeybind = keyCode
                keybindButton.Text = "Current: " .. getKeyName(keyCode)
                keybindButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                isWaitingForKey = false
                
                -- Update the keybind connection
                Settings.updateKeybind(keyCode)
                
                connection:Disconnect()
                
                print("Keybind changed to: " .. getKeyName(keyCode))
            end
        end)
        
        -- Timeout after 5 seconds
        task.delay(5, function()
            if isWaitingForKey then
                isWaitingForKey = false
                keybindButton.Text = "Current: " .. getKeyName(currentKeybind)
                keybindButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                connection:Disconnect()
            end
        end)
    end)
    
    keybindButton.MouseEnter:Connect(function()
        if not isWaitingForKey then
            keybindButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        end
    end)
    
    keybindButton.MouseLeave:Connect(function()
        if not isWaitingForKey then
            keybindButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        end
    end)
end

-- Function to update slider UI when settings change externally
local function updateSliderUI(name, newValue)
    local slider = sliders[name]
    if not slider then return end
    
    local relativeX = (newValue - slider.min) / (slider.max - slider.min)
    slider.fillBar.Size = UDim2.new(relativeX, 0, 1, 0)
    slider.sliderButton.Position = UDim2.new(relativeX, -6, 0, -3)
    slider.valueLabel.Text = tostring(newValue)
end

-- Apply current settings to active features with immediate sync
function Settings.applySettings()
    local mainFrame = ScreenGui and ScreenGui:FindFirstChild("MainFrame")
    local minimizedLogo = ScreenGui and ScreenGui:FindFirstChild("MinimizedLogo")
    
    -- Apply GUI resize (Main Frame only)
    if mainFrame then
        if settings.GuiWidth then
            mainFrame.Size = UDim2.new(0, settings.GuiWidth.value, 0, mainFrame.Size.Y.Offset)
        end
        if settings.GuiHeight then
            mainFrame.Size = UDim2.new(0, mainFrame.Size.X.Offset, 0, settings.GuiHeight.value)
        end
    end
    
    -- Apply Logo Opacity (MinimizedLogo only)
    if minimizedLogo and settings.LogoOpacity then
        local opacity = settings.LogoOpacity.value
        minimizedLogo.BackgroundTransparency = 1 - opacity
        
        -- Apply opacity to logo's child elements
        for _, child in pairs(minimizedLogo:GetDescendants()) do
            if child:IsA("TextLabel") then
                if child:GetAttribute("OriginalTransparency") == nil then
                    child:SetAttribute("OriginalTransparency", child.TextTransparency or 0)
                end
                local originalTransparency = child:GetAttribute("OriginalTransparency")
                child.TextTransparency = originalTransparency + (1 - opacity) * (1 - originalTransparency)
            end
        end
    end
    
    -- Apply Enable/Disable Drag (Logo only, NOT MainFrame)
    if minimizedLogo then
        minimizedLogo.Draggable = toggleStates.EnableDrag
    end
    
    -- Apply Hide GUI (Logo only, NOT MainFrame)
    if minimizedLogo then
        minimizedLogo.Visible = not toggleStates.HideGUI
    end
    
    print("GUI Settings applied - Width:", settings.GuiWidth and settings.GuiWidth.value or "N/A", 
          "Height:", settings.GuiHeight and settings.GuiHeight.value or "N/A",
          "Logo Opacity:", settings.LogoOpacity and settings.LogoOpacity.value or "N/A",
          "Logo Drag:", toggleStates.EnableDrag,
          "Logo Hidden:", toggleStates.HideGUI,
          "Keybind:", getKeyName(currentKeybind))
end

-- Function to create buttons for Settings features
function Settings.loadSettingsButtons(createButton)
    -- Ignore createButton, directly add to ScrollFrame (which is FeatureContainer)
    if not ScrollFrame then
        warn("ScrollFrame not provided!")
        return
    end
    
    -- Create keybind button first
    createKeybindButton(ScrollFrame)
    
    -- Create toggle for Enable Drag (Logo)
    createToggleButton("Enable Drag", function(state)
        toggleStates.EnableDrag = state
        Settings.applySettings()
    end, ScrollFrame)
    
    -- Create toggle for Hide GUI (Logo)
    createToggleButton("Hide GUI", function(state)
        toggleStates.HideGUI = state
        Settings.applySettings()
    end, ScrollFrame)
    
    -- Create sliders for GUI controls
    if settings.GuiWidth then
        createSlider("GUI Width", settings.GuiWidth, settings.GuiWidth.min, settings.GuiWidth.max, settings.GuiWidth.default, ScrollFrame)
    end
    if settings.GuiHeight then
        createSlider("GUI Height", settings.GuiHeight, settings.GuiHeight.min, settings.GuiHeight.max, settings.GuiHeight.default, ScrollFrame)
    end
    if settings.LogoOpacity then
        createSlider("Logo Opacity", settings.LogoOpacity, settings.LogoOpacity.min, settings.LogoOpacity.max, settings.LogoOpacity.default, ScrollFrame)
    end
    
    -- Update all slider UIs to reflect current values
    for name, slider in pairs(sliders) do
        updateSliderUI(name, slider.setting.value)
    end
    
    print("Settings UI elements loaded (Logo controls + Custom Keybind)")
end

-- Function to update keybind connection
function Settings.updateKeybind(newKeyCode)
    currentKeybind = newKeyCode
    -- The mainloader will handle reconnecting with the new keybind
    return currentKeybind
end

-- Function to get current keybind
function Settings.getCurrentKeybind()
    return currentKeybind
end

-- Function to set keybind (for external use)
function Settings.setKeybind(keyCode)
    currentKeybind = keyCode
    if keybindButton then
        keybindButton.Text = "Current: " .. getKeyName(keyCode)
    end
    print("Keybind set to: " .. getKeyName(keyCode))
end

-- Function to reset Settings states
function Settings.resetStates()
    print("Resetting Settings to defaults")
    
    if not settings then
        warn("Settings not initialized!")
        return
    end
    
    -- Reset all settings to defaults
    if settings.GuiWidth then settings.GuiWidth.value = settings.GuiWidth.default end
    if settings.GuiHeight then settings.GuiHeight.value = settings.GuiHeight.default end
    if settings.LogoOpacity then settings.LogoOpacity.value = settings.LogoOpacity.default end
    
    -- Reset toggles
    toggleStates.EnableDrag = true
    toggleStates.HideGUI = false
    
    -- Reset keybind to default (Home)
    currentKeybind = Enum.KeyCode.Home
    if keybindButton then
        keybindButton.Text = "Current: " .. getKeyName(currentKeybind)
    end
    
    -- Update slider UIs
    for name, slider in pairs(sliders) do
        updateSliderUI(name, slider.setting.value)
    end
    
    -- Apply the reset settings
    Settings.applySettings()
    
    print("Settings reset complete")
end

-- Function to get current setting value
function Settings.getSetting(settingName)
    if settings and settings[settingName] then
        return settings[settingName].value
    end
    return nil
end

-- Function to set setting value
function Settings.setSetting(settingName, value)
    if settings and settings[settingName] then
        local setting = settings[settingName]
        local clampedValue = math.clamp(value, setting.min, setting.max)
        setting.value = clampedValue
        
        -- Update slider UI if it exists
        updateSliderUI(settingName, clampedValue)
        
        -- Apply settings immediately
        Settings.applySettings()
        
        return true
    end
    return false
end

-- Function to refresh all sliders
function Settings.refreshSliders()
    for name, slider in pairs(sliders) do
        updateSliderUI(name, slider.setting.value)
    end
end

-- Function to set dependencies and initialize UI
function Settings.init(deps)
    print("Initializing Settings module")
    
    if not deps then
        warn("No dependencies provided to Settings module!")
        return false
    end
    
    ScreenGui = deps.ScreenGui
    ScrollFrame = deps.ScrollFrame
    settings = deps.settings
    Movement = deps.Movement
    
    if not ScreenGui then
        warn("ScreenGui not provided!")
        return false
    end
    
    if not settings then
        warn("Settings not provided!")
        return false
    end
    
    -- Ensure all required settings exist with proper defaults
    if not settings.GuiWidth then
        settings.GuiWidth = {value = 500, min = 300, max = 800, default = 500}
        print("Created default GuiWidth setting")
    end
    
    if not settings.GuiHeight then
        settings.GuiHeight = {value = 300, min = 200, max = 600, default = 300}
        print("Created default GuiHeight setting")
    end
    
    if not settings.LogoOpacity then
        settings.LogoOpacity = {value = 1.0, min = 0.1, max = 1.0, default = 1.0}
        print("Created default LogoOpacity setting")
    end
    
    print("Settings module initialized successfully (with Custom Keybind)")
    return true
end

-- Debug function
function Settings.debug()
    print("=== Settings Module Debug ===")
    print("ScreenGui:", ScreenGui ~= nil)
    print("Settings object:", settings ~= nil)
    print("Movement reference:", Movement ~= nil)
    print("Current Keybind:", getKeyName(currentKeybind))
    
    if settings then
        print("Current Settings Values:")
        local settingsList = {"GuiWidth", "GuiHeight", "LogoOpacity"}
        for _, name in ipairs(settingsList) do
            if settings[name] then
                print("  " .. name .. ":", settings[name].value, 
                      "(min:", settings[name].min, 
                      "max:", settings[name].max, 
                      "default:", settings[name].default, ")")
            else
                print("  " .. name .. ": NOT FOUND")
            end
        end
    end
    
    print("Toggle States:")
    for name, state in pairs(toggleStates) do
        print("  " .. name .. ":", state)
    end
    
    print("Active Sliders:")
    local sliderCount = 0
    for name, slider in pairs(sliders) do
        sliderCount = sliderCount + 1
        local isVisible = slider.frame and slider.frame.Parent and slider.frame.Visible
        print("  " .. name .. ":", isVisible and "VISIBLE" or "HIDDEN")
    end
    print("  Total sliders:", sliderCount)
    
    print("=============================")
end

-- Cleanup function
function Settings.cleanup()
    print("Cleaning up Settings module")
    
    sliders = {}
    isWaitingForKey = false
    keybindButton = nil
    
    print("Settings module cleaned up")
end

-- Function to handle settings changes from external sources
function Settings.onSettingChanged(settingName, newValue)
    if settings and settings[settingName] then
        settings[settingName].value = newValue
        updateSliderUI(settingName, newValue)
        Settings.applySettings()
        print("Setting changed externally:", settingName, "=", newValue)
    end
end

-- Function to get all current setting values as a table
function Settings.getAllSettings()
    local currentSettings = {}
    if settings then
        for name, setting in pairs(settings) do
            currentSettings[name] = setting.value
        end
    end
    currentSettings.Keybind = getKeyName(currentKeybind)
    return currentSettings
end

-- Function to force refresh of all UI elements
function Settings.refreshUI()
    -- Refresh all sliders
    Settings.refreshSliders()
    
    -- Refresh keybind button
    if keybindButton then
        keybindButton.Text = "Current: " .. getKeyName(currentKeybind)
    end
    
    print("Settings UI refreshed")
end

return Settings