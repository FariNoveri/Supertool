-- settings.lua
-- Settings-related features for MinimalHackGUI by Fari Noveri

-- Dependencies: These must be passed from mainloader.lua
local ScreenGui, ScrollFrame, settings, modules

-- Initialize module
local Settings = {}

-- UI Elements (to be initialized in initUI function)
local SettingsFrame, SettingsScrollFrame, SettingsLayout

-- Helper function to create a slider UI
local function createSlider(name, setting, min, max, default)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Name = name .. "Slider"
    sliderFrame.Parent = SettingsScrollFrame
    sliderFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    sliderFrame.BorderSizePixel = 0
    sliderFrame.Size = UDim2.new(1, -5, 0, 60)
    
    local sliderLabel = Instance.new("TextLabel")
    sliderLabel.Name = "Label"
    sliderLabel.Parent = sliderFrame
    sliderLabel.BackgroundTransparency = 1
    sliderLabel.Position = UDim2.new(0, 5, 0, 5)
    sliderLabel.Size = UDim2.new(1, -10, 0, 20)
    sliderLabel.Font = Enum.Font.Gotham
    sliderLabel.Text = name:upper()
    sliderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    sliderLabel.TextSize = 11
    sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local sliderBar = Instance.new("Frame")
    sliderBar.Name = "SliderBar"
    sliderBar.Parent = sliderFrame
    sliderBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    sliderBar.BorderSizePixel = 0
    sliderBar.Position = UDim2.new(0, 5, 0, 30)
    sliderBar.Size = UDim2.new(1, -10, 0, 10)
    
    local fillBar = Instance.new("Frame")
    fillBar.Name = "Fill"
    fillBar.Parent = sliderBar
    fillBar.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    fillBar.BorderSizePixel = 0
    fillBar.Size = UDim2.new((setting.value - min) / (max - min), 0, 1, 0)
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "Value"
    valueLabel.Parent = sliderFrame
    valueLabel.BackgroundTransparency = 1
    valueLabel.Position = UDim2.new(1, -50, 0, 5)
    valueLabel.Size = UDim2.new(0, 45, 0, 20)
    valueLabel.Font = Enum.Font.Gotham
    valueLabel.Text = tostring(setting.value)
    valueLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    valueLabel.TextSize = 11
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    
    local sliderButton = Instance.new("TextButton")
    sliderButton.Name = "SliderButton"
    sliderButton.Parent = sliderBar
    sliderButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
    sliderButton.BorderSizePixel = 0
    sliderButton.Position = UDim2.new((setting.value - min) / (max - min), -5, 0, -2)
    sliderButton.Size = UDim2.new(0, 10, 0, 14)
    sliderButton.Text = ""
    
    local dragging = false
    
    sliderButton.MouseButton1Down:Connect(function()
        dragging = true
    end)
    
    game:GetService("UserInputService").InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    game:GetService("RunService").RenderStepped:Connect(function()
        if dragging then
            local mouseX = game:GetService("UserInputService"):GetMouseLocation().X
            local barPos = sliderBar.AbsolutePosition.X
            local barWidth = sliderBar.AbsoluteSize.X
            local relativeX = math.clamp((mouseX - barPos) / barWidth, 0, 1)
            
            setting.value = min + (max - min) * relativeX
            setting.value = math.floor(setting.value + 0.5)
            
            fillBar.Size = UDim2.new(relativeX, 0, 1, 0)
            sliderButton.Position = UDim2.new(relativeX, -5, 0, -2)
            valueLabel.Text = tostring(setting.value)
        end
    end)
end

-- Helper function to create toggle buttons
local function createToggleButton(name, description, callback, initialState)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = name .. "Toggle"
    toggleFrame.Parent = SettingsScrollFrame
    toggleFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    toggleFrame.BorderSizePixel = 0
    toggleFrame.Size = UDim2.new(1, -5, 0, 50)
    
    local toggleLabel = Instance.new("TextLabel")
    toggleLabel.Name = "Label"
    toggleLabel.Parent = toggleFrame
    toggleLabel.BackgroundTransparency = 1
    toggleLabel.Position = UDim2.new(0, 5, 0, 5)
    toggleLabel.Size = UDim2.new(1, -60, 0, 20)
    toggleLabel.Font = Enum.Font.Gotham
    toggleLabel.Text = name:upper()
    toggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleLabel.TextSize = 11
    toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local descLabel = Instance.new("TextLabel")
    descLabel.Name = "Description"
    descLabel.Parent = toggleFrame
    descLabel.BackgroundTransparency = 1
    descLabel.Position = UDim2.new(0, 5, 0, 25)
    descLabel.Size = UDim2.new(1, -60, 0, 20)
    descLabel.Font = Enum.Font.Gotham
    descLabel.Text = description
    descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    descLabel.TextSize = 9
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Parent = toggleFrame
    toggleButton.BackgroundColor3 = initialState and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    toggleButton.BorderSizePixel = 0
    toggleButton.Position = UDim2.new(1, -50, 0, 10)
    toggleButton.Size = UDim2.new(0, 40, 0, 30)
    toggleButton.Font = Enum.Font.Gotham
    toggleButton.Text = initialState and "ON" or "OFF"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.TextSize = 10
    
    local currentState = initialState or false
    
    toggleButton.MouseButton1Click:Connect(function()
        currentState = not currentState
        toggleButton.BackgroundColor3 = currentState and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
        toggleButton.Text = currentState and "ON" or "OFF"
        
        if callback then
            callback(currentState)
        end
    end)
    
    toggleButton.MouseEnter:Connect(function()
        toggleButton.BackgroundColor3 = currentState and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(80, 80, 80)
    end)
    
    toggleButton.MouseLeave:Connect(function()
        toggleButton.BackgroundColor3 = currentState and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    end)
    
    return toggleButton
end

-- Helper function to create action buttons
local function createActionButton(name, description, callback)
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Name = name .. "Button"
    buttonFrame.Parent = SettingsScrollFrame
    buttonFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    buttonFrame.BorderSizePixel = 0
    buttonFrame.Size = UDim2.new(1, -5, 0, 50)
    
    local buttonLabel = Instance.new("TextLabel")
    buttonLabel.Name = "Label"
    buttonLabel.Parent = buttonFrame
    buttonLabel.BackgroundTransparency = 1
    buttonLabel.Position = UDim2.new(0, 5, 0, 5)
    buttonLabel.Size = UDim2.new(1, -60, 0, 20)
    buttonLabel.Font = Enum.Font.Gotham
    buttonLabel.Text = name:upper()
    buttonLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    buttonLabel.TextSize = 11
    buttonLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local descLabel = Instance.new("TextLabel")
    descLabel.Name = "Description"
    descLabel.Parent = buttonFrame
    descLabel.BackgroundTransparency = 1
    descLabel.Position = UDim2.new(0, 5, 0, 25)
    descLabel.Size = UDim2.new(1, -60, 0, 20)
    descLabel.Font = Enum.Font.Gotham
    descLabel.Text = description
    descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    descLabel.TextSize = 9
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local actionButton = Instance.new("TextButton")
    actionButton.Name = "ActionButton"
    actionButton.Parent = buttonFrame
    actionButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    actionButton.BorderSizePixel = 0
    actionButton.Position = UDim2.new(1, -50, 0, 10)
    actionButton.Size = UDim2.new(0, 40, 0, 30)
    actionButton.Font = Enum.Font.Gotham
    actionButton.Text = "GO"
    actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    actionButton.TextSize = 10
    
    actionButton.MouseButton1Click:Connect(function()
        if callback then
            callback()
        end
    end)
    
    actionButton.MouseEnter:Connect(function()
        actionButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end)
    
    actionButton.MouseLeave:Connect(function()
        actionButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end)
end

-- Helper function to create separator
local function createSeparator(title)
    local separatorFrame = Instance.new("Frame")
    separatorFrame.Name = title .. "Separator"
    separatorFrame.Parent = SettingsScrollFrame
    separatorFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    separatorFrame.BorderSizePixel = 0
    separatorFrame.Size = UDim2.new(1, -5, 0, 25)
    
    local separatorLabel = Instance.new("TextLabel")
    separatorLabel.Name = "Label"
    separatorLabel.Parent = separatorFrame
    separatorLabel.BackgroundTransparency = 1
    separatorLabel.Size = UDim2.new(1, 0, 1, 0)
    separatorLabel.Font = Enum.Font.GothamBold
    separatorLabel.Text = title:upper()
    separatorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    separatorLabel.TextSize = 12
end

-- Show Settings UI
local function showSettings()
    SettingsFrame.Visible = true
    SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, SettingsLayout.AbsoluteContentSize.Y + 10)
end

-- Initialize UI elements
local function initUI()
    -- Settings Frame
    SettingsFrame = Instance.new("Frame")
    SettingsFrame.Name = "SettingsFrame"
    SettingsFrame.Parent = ScreenGui
    SettingsFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    SettingsFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    SettingsFrame.BorderSizePixel = 1
    SettingsFrame.Position = UDim2.new(0.5, -200, 0.1, 0)
    SettingsFrame.Size = UDim2.new(0, 400, 0, 450)
    SettingsFrame.Visible = false
    SettingsFrame.Active = true
    SettingsFrame.Draggable = true

    -- Settings Title
    local SettingsTitle = Instance.new("TextLabel")
    SettingsTitle.Name = "Title"
    SettingsTitle.Parent = SettingsFrame
    SettingsTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    SettingsTitle.BorderSizePixel = 0
    SettingsTitle.Position = UDim2.new(0, 0, 0, 0)
    SettingsTitle.Size = UDim2.new(1, 0, 0, 35)
    SettingsTitle.Font = Enum.Font.Gotham
    SettingsTitle.Text = "MINIMALHACKGUI SETTINGS"
    SettingsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    SettingsTitle.TextSize = 12

    -- Close Settings Button
    local CloseSettingsButton = Instance.new("TextButton")
    CloseSettingsButton.Name = "CloseButton"
    CloseSettingsButton.Parent = SettingsFrame
    CloseSettingsButton.BackgroundTransparency = 1
    CloseSettingsButton.Position = UDim2.new(1, -30, 0, 5)
    CloseSettingsButton.Size = UDim2.new(0, 25, 0, 25)
    CloseSettingsButton.Font = Enum.Font.GothamBold
    CloseSettingsButton.Text = "X"
    CloseSettingsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseSettingsButton.TextSize = 12

    -- Settings ScrollFrame
    SettingsScrollFrame = Instance.new("ScrollingFrame")
    SettingsScrollFrame.Name = "SettingsScrollFrame"
    SettingsScrollFrame.Parent = SettingsFrame
    SettingsScrollFrame.BackgroundTransparency = 1
    SettingsScrollFrame.Position = UDim2.new(0, 10, 0, 45)
    SettingsScrollFrame.Size = UDim2.new(1, -20, 1, -55)
    SettingsScrollFrame.ScrollBarThickness = 4
    SettingsScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    SettingsScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    SettingsScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    SettingsScrollFrame.BorderSizePixel = 0

    -- Settings Layout
    SettingsLayout = Instance.new("UIListLayout")
    SettingsLayout.Parent = SettingsScrollFrame
    SettingsLayout.Padding = UDim.new(0, 2)
    SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SettingsLayout.FillDirection = Enum.FillDirection.Vertical

    -- Update canvas size when content changes
    SettingsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, SettingsLayout.AbsoluteContentSize.Y + 10)
    end)

    -- GENERAL SETTINGS SECTION
    createSeparator("General Settings")
    
    -- Create sliders for general settings
    createSlider("Fly Speed", settings.FlySpeed, settings.FlySpeed.min, settings.FlySpeed.max, settings.FlySpeed.default)
    createSlider("Freecam Speed", settings.FreecamSpeed, settings.FreecamSpeed.min, settings.FreecamSpeed.max, settings.FreecamSpeed.default)
    createSlider("Jump Height", settings.JumpHeight, settings.JumpHeight.min, settings.JumpHeight.max, settings.JumpHeight.default)
    createSlider("Walk Speed", settings.WalkSpeed, settings.WalkSpeed.min, settings.WalkSpeed.max, settings.WalkSpeed.default)

    -- ANTI-RECORD SETTINGS SECTION
    createSeparator("Anti-Record Settings")
    
    -- AntiRecord Settings
    createSlider("Hide Sensitivity", settings.AntiRecordIntensity, settings.AntiRecordIntensity.min, settings.AntiRecordIntensity.max, settings.AntiRecordIntensity.default)
    
    -- AntiRecord Toggle
    createToggleButton(
        "Anti Record",
        "Hides GUI when recording/FPS drops detected",
        function(enabled)
            if modules.AntiRecord and modules.AntiRecord.toggleAntiRecord then
                modules.AntiRecord.toggleAntiRecord(enabled)
            end
        end,
        false
    )
    
    -- AntiScreenshot Toggle
    createToggleButton(
        "Anti Screenshot",
        "Hides GUI randomly to avoid screenshots",
        function(enabled)
            if modules.AntiRecord and modules.AntiRecord.toggleAntiScreenshot then
                modules.AntiRecord.toggleAntiScreenshot(enabled)
            end
        end,
        false
    )
    
    -- Manual Hide Button
    createActionButton(
        "Hide GUI (3s)",
        "Hide GUI for 3 seconds",
        function()
            if modules.AntiRecord and modules.AntiRecord.manualHide then
                modules.AntiRecord.manualHide()
            end
        end
    )
    
    -- Manual Show Button
    createActionButton(
        "Force Show GUI", 
        "Emergency restore GUI visibility",
        function()
            if modules.AntiRecord and modules.AntiRecord.manualShow then
                modules.AntiRecord.manualShow()
            end
        end
    )

    -- Connect Close Settings Button
    CloseSettingsButton.MouseButton1Click:Connect(function()
        SettingsFrame.Visible = false
    end)
end

-- Function to recreate all settings elements (for reset)
local function recreateSettings()
    -- Clear existing elements
    for _, child in pairs(SettingsScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- GENERAL SETTINGS SECTION
    createSeparator("General Settings")
    
    -- Create sliders for general settings
    createSlider("Fly Speed", settings.FlySpeed, settings.FlySpeed.min, settings.FlySpeed.max, settings.FlySpeed.default)
    createSlider("Freecam Speed", settings.FreecamSpeed, settings.FreecamSpeed.min, settings.FreecamSpeed.max, settings.FreecamSpeed.default)
    createSlider("Jump Height", settings.JumpHeight, settings.JumpHeight.min, settings.JumpHeight.max, settings.JumpHeight.default)
    createSlider("Walk Speed", settings.WalkSpeed, settings.WalkSpeed.min, settings.WalkSpeed.max, settings.WalkSpeed.default)

    -- ANTI-RECORD SETTINGS SECTION
    createSeparator("Anti-Record Settings")
    
    -- AntiRecord Intensity Slider
    createSlider("Detection Sensitivity", settings.AntiRecordIntensity, settings.AntiRecordIntensity.min, settings.AntiRecordIntensity.max, settings.AntiRecordIntensity.default)
    createSlider("Flicker Speed", settings.AntiRecordFlickerSpeed, settings.AntiRecordFlickerSpeed.min, settings.AntiRecordFlickerSpeed.max, settings.AntiRecordFlickerSpeed.default)
    
    -- AntiRecord Toggle
    createToggleButton(
        "Anti Record",
        "Hides GUI when recording is detected",
        function(enabled)
            if modules.AntiRecord and modules.AntiRecord.toggleAntiRecord then
                modules.AntiRecord.toggleAntiRecord(enabled)
            end
        end,
        false
    )
    
    -- AntiScreenshot Toggle
    createToggleButton(
        "Anti Screenshot",
        "Hides GUI more aggressively to prevent screenshots",
        function(enabled)
            if modules.AntiRecord and modules.AntiRecord.toggleAntiScreenshot then
                modules.AntiRecord.toggleAntiScreenshot(enabled)
            end
        end,
        false
    )
    
    -- Manual Hide Button
    createActionButton(
        "Manual Hide",
        "Instantly hide all GUI elements",
        function()
            if modules.AntiRecord and modules.AntiRecord.manualHide then
                modules.AntiRecord.manualHide()
            end
        end
    )
    
    -- Manual Show Button
    createActionButton(
        "Manual Show", 
        "Show all hidden GUI elements",
        function()
            if modules.AntiRecord and modules.AntiRecord.manualShow then
                modules.AntiRecord.manualShow()
            end
        end
    )
end

-- Function to create buttons for Settings features
function Settings.loadSettingsButtons(createButton)
    createButton("Open Settings", showSettings)
    
    -- Quick access buttons for AntiRecord
    createButton("Quick Hide GUI", function()
        if modules.AntiRecord and modules.AntiRecord.manualHide then
            modules.AntiRecord.manualHide()
        end
    end)
    
    createButton("Quick Show GUI", function()
        if modules.AntiRecord and modules.AntiRecord.manualShow then
            modules.AntiRecord.manualShow()
        end
    end)
    
    createButton("Reset All Settings", function()
        -- Reset all settings to default values
        settings.FlySpeed.value = settings.FlySpeed.default
        settings.FreecamSpeed.value = settings.FreecamSpeed.default
        settings.JumpHeight.value = settings.JumpHeight.default
        settings.WalkSpeed.value = settings.WalkSpeed.default
        settings.AntiRecordIntensity.value = settings.AntiRecordIntensity.default
        
        -- Reset AntiRecord states
        if modules.AntiRecord and modules.AntiRecord.resetStates then
            modules.AntiRecord.resetStates()
        end
        
        -- Recreate settings UI to reflect changes
        if SettingsFrame and SettingsFrame.Visible then
            recreateSettings()
        end
        
        print("All settings reset to default values")
    end)
end

-- Function to reset Settings states
function Settings.resetStates()
    settings.FlySpeed.value = settings.FlySpeed.default
    settings.FreecamSpeed.value = settings.FreecamSpeed.default
    settings.JumpHeight.value = settings.JumpHeight.default
    settings.WalkSpeed.value = settings.WalkSpeed.default
    settings.AntiRecordIntensity.value = settings.AntiRecordIntensity.default
    
    if SettingsFrame then
        SettingsFrame.Visible = false
        recreateSettings()
    end
end

-- Function to set dependencies and initialize UI
function Settings.init(deps)
    ScreenGui = deps.ScreenGui
    ScrollFrame = deps.ScrollFrame
    settings = deps.settings
    modules = deps.modules -- Add modules to access AntiRecord
    
    -- Initialize UI elements
    initUI()
    
    print("Settings module initialized with AntiRecord support")
end

return Settings