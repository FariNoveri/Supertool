-- settings.lua
-- Settings-related features for MinimalHackGUI by Fari Noveri

-- Dependencies: These must be passed from mainloader.lua
local ScreenGui, ScrollFrame, settings, Movement

-- Initialize module
local Settings = {}

-- UI Elements (to be initialized in initUI function)
local SettingsFrame, SettingsScrollFrame, SettingsLayout

-- Store slider references for updates
local sliders = {}

-- Helper function to create a slider UI
local function createSlider(name, setting, min, max, default)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Name = name .. "Slider"
    sliderFrame.Parent = SettingsScrollFrame
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
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    
    -- Mouse/Touch input handling
    local function updateSlider(inputPosition)
        local barPos = sliderBar.AbsolutePosition.X
        local barWidth = sliderBar.AbsoluteSize.X
        local relativeX = math.clamp((inputPosition - barPos) / barWidth, 0, 1)
        
        -- Calculate new value and round it
        local newValue = min + (max - min) * relativeX
        newValue = math.floor(newValue + 0.5)
        
        -- Update setting value
        setting.value = newValue
        
        -- Update UI elements
        fillBar.Size = UDim2.new(relativeX, 0, 1, 0)
        sliderButton.Position = UDim2.new(relativeX, -6, 0, -3)
        valueLabel.Text = tostring(newValue)
        
        -- Apply changes immediately for active features
        Settings.applySettings()
    end
    
    sliderButton.MouseButton1Down:Connect(function()
        dragging = true
    end)
    
    sliderBar.MouseButton1Down:Connect(function()
        local mousePos = UserInputService:GetMouseLocation()
        updateSlider(mousePos.X)
        dragging = true
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement) then
            local mousePos = UserInputService:GetMouseLocation()
            updateSlider(mousePos.X)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    -- Touch support for mobile
    sliderButton.TouchTap:Connect(function()
        dragging = true
    end)
    
    UserInputService.TouchMoved:Connect(function(touch, gameProcessed)
        if dragging and not gameProcessed then
            updateSlider(touch.Position.X)
        end
    end)
    
    UserInputService.TouchEnded:Connect(function(touch, gameProcessed)
        dragging = false
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

-- Apply current settings to active features
function Settings.applySettings()
    if not Movement then return end
    
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    if not player or not player.Character then return end
    
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    -- Apply Walk Speed if Speed Hack is enabled
    if Movement.speedEnabled and settings.WalkSpeed then
        humanoid.WalkSpeed = settings.WalkSpeed.value
    end
    
    -- Apply Jump Height if Jump Hack is enabled
    if Movement.jumpEnabled and settings.JumpHeight then
        if humanoid:FindFirstChild("JumpHeight") then
            humanoid.JumpHeight = settings.JumpHeight.value
        else
            humanoid.JumpPower = settings.JumpHeight.value * 2.4
        end
    end
    
    -- Note: Fly Speed and Freecam Speed are applied directly in their respective modules
    print("Settings applied - WalkSpeed:", settings.WalkSpeed.value, "JumpHeight:", settings.JumpHeight.value)
end

-- Show Settings UI
local function showSettings()
    if not SettingsFrame then
        warn("Settings UI not initialized!")
        return
    end
    
    SettingsFrame.Visible = true
    SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, SettingsLayout.AbsoluteContentSize.Y + 20)
    
    -- Update all slider UIs to reflect current values
    for name, slider in pairs(sliders) do
        updateSliderUI(name, slider.setting.value)
    end
end

-- Hide Settings UI
local function hideSettings()
    if SettingsFrame then
        SettingsFrame.Visible = false
    end
end

-- Initialize UI elements
local function initUI()
    if not ScreenGui then
        warn("ScreenGui not provided to Settings module!")
        return
    end
    
    -- Settings Frame
    SettingsFrame = Instance.new("Frame")
    SettingsFrame.Name = "SettingsFrame"
    SettingsFrame.Parent = ScreenGui
    SettingsFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    SettingsFrame.BorderColor3 = Color3.fromRGB(60, 60, 60)
    SettingsFrame.BorderSizePixel = 2
    SettingsFrame.Position = UDim2.new(0.5, -175, 0.2, 0)
    SettingsFrame.Size = UDim2.new(0, 350, 0, 400)
    SettingsFrame.Visible = false
    SettingsFrame.Active = true
    SettingsFrame.Draggable = true
    SettingsFrame.ZIndex = 10

    -- Add rounded corners to settings frame
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 8)
    frameCorner.Parent = SettingsFrame

    -- Settings Title
    local SettingsTitle = Instance.new("TextLabel")
    SettingsTitle.Name = "Title"
    SettingsTitle.Parent = SettingsFrame
    SettingsTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    SettingsTitle.BorderSizePixel = 0
    SettingsTitle.Position = UDim2.new(0, 0, 0, 0)
    SettingsTitle.Size = UDim2.new(1, 0, 0, 40)
    SettingsTitle.Font = Enum.Font.GothamBold
    SettingsTitle.Text = "⚙️ SETTINGS"
    SettingsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    SettingsTitle.TextSize = 14
    SettingsTitle.ZIndex = 11
    
    -- Add rounded corners to title
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = SettingsTitle

    -- Close Settings Button
    local CloseSettingsButton = Instance.new("TextButton")
    CloseSettingsButton.Name = "CloseButton"
    CloseSettingsButton.Parent = SettingsFrame
    CloseSettingsButton.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
    CloseSettingsButton.Position = UDim2.new(1, -35, 0, 8)
    CloseSettingsButton.Size = UDim2.new(0, 25, 0, 25)
    CloseSettingsButton.Font = Enum.Font.GothamBold
    CloseSettingsButton.Text = "✕"
    CloseSettingsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseSettingsButton.TextSize = 12
    CloseSettingsButton.ZIndex = 12
    
    -- Add rounded corners to close button
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = CloseSettingsButton

    -- Settings ScrollFrame
    SettingsScrollFrame = Instance.new("ScrollingFrame")
    SettingsScrollFrame.Name = "SettingsScrollFrame"
    SettingsScrollFrame.Parent = SettingsFrame
    SettingsScrollFrame.BackgroundTransparency = 1
    SettingsScrollFrame.Position = UDim2.new(0, 15, 0, 50)
    SettingsScrollFrame.Size = UDim2.new(1, -30, 1, -65)
    SettingsScrollFrame.ScrollBarThickness = 6
    SettingsScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(70, 130, 180)
    SettingsScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    SettingsScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    SettingsScrollFrame.BorderSizePixel = 0
    SettingsScrollFrame.ZIndex = 11

    -- Settings Layout
    SettingsLayout = Instance.new("UIListLayout")
    SettingsLayout.Parent = SettingsScrollFrame
    SettingsLayout.Padding = UDim.new(0, 8)
    SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SettingsLayout.FillDirection = Enum.FillDirection.Vertical

    -- Create sliders for settings
    createSlider("Walk Speed", settings.WalkSpeed, settings.WalkSpeed.min, settings.WalkSpeed.max, settings.WalkSpeed.default)
    createSlider("Jump Height", settings.JumpHeight, settings.JumpHeight.min, settings.JumpHeight.max, settings.JumpHeight.default)
    createSlider("Fly Speed", settings.FlySpeed, settings.FlySpeed.min, settings.FlySpeed.max, settings.FlySpeed.default)
    createSlider("Freecam Speed", settings.FreecamSpeed, settings.FreecamSpeed.min, settings.FreecamSpeed.max, settings.FreecamSpeed.default)

    -- Connect Close Settings Button
    CloseSettingsButton.MouseButton1Click:Connect(hideSettings)
    
    -- Update canvas size after layout change
    SettingsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, SettingsLayout.AbsoluteContentSize.Y + 20)
    end)
    
    print("Settings UI initialized successfully")
end

-- Function to create buttons for Settings features
function Settings.loadSettingsButtons(createButton)
    if not createButton then
        warn("createButton function not provided!")
        return
    end
    createButton("Settings", showSettings)
end

-- Function to reset Settings states
function Settings.resetStates()
    print("Resetting Settings to defaults")
    
    if not settings then
        warn("Settings not initialized!")
        return
    end
    
    -- Reset all settings to defaults
    settings.FlySpeed.value = settings.FlySpeed.default
    settings.FreecamSpeed.value = settings.FreecamSpeed.default
    settings.JumpHeight.value = settings.JumpHeight.default
    settings.WalkSpeed.value = settings.WalkSpeed.default
    
    -- Update slider UIs
    for name, slider in pairs(sliders) do
        updateSliderUI(name, slider.setting.value)
    end
    
    -- Apply the reset settings
    Settings.applySettings()
    
    if SettingsFrame then
        SettingsFrame.Visible = false
    end
    
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
    Movement = deps.Movement -- Add Movement reference for applying settings
    
    if not ScreenGui then
        warn("ScreenGui not provided!")
        return false
    end
    
    if not settings then
        warn("Settings not provided!")
        return false
    end
    
    -- Initialize UI elements
    initUI()
    
    print("Settings module initialized successfully")
    return true
end

-- Debug function
function Settings.debug()
    print("=== Settings Module Debug ===")
    print("ScreenGui:", ScreenGui ~= nil)
    print("SettingsFrame:", SettingsFrame ~= nil)
    print("Settings object:", settings ~= nil)
    
    if settings then
        print("Current Settings Values:")
        for name, setting in pairs(settings) do
            print("  " .. name .. ":", setting.value, "(min:", setting.min, "max:", setting.max, "default:", setting.default, ")")
        end
    end
    
    print("Active Sliders:", #sliders)
    for name, _ in pairs(sliders) do
        print("  " .. name)
    end
    print("=============================")
end

-- Cleanup function
function Settings.cleanup()
    print("Cleaning up Settings module")
    
    if SettingsFrame then
        SettingsFrame:Destroy()
        SettingsFrame = nil
    end
    
    SettingsScrollFrame = nil
    SettingsLayout = nil
    sliders = {}
    
    print("Settings module cleaned up")
end

return Settings