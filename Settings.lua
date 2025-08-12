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
            
            -- Update AntiRecord settings if applicable
            if name == "Anti-Record Intensity" and modules.AntiRecord then
                local antiRecordSettings = modules.AntiRecord.getSettings()
                if antiRecordSettings then
                    antiRecordSettings.Intensity = setting.value
                end
            elseif name == "Anti-Record Flicker Speed" and modules.AntiRecord then
                local antiRecordSettings = modules.AntiRecord.getSettings()
                if antiRecordSettings then
                    antiRecordSettings.FlickerSpeed = setting.value
                end
            end
        end
    end)
end

-- Helper function to create toggle button for settings
local function createSettingsToggle(name, initialState, callback)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = name .. "Toggle"
    toggleFrame.Parent = SettingsScrollFrame
    toggleFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    toggleFrame.BorderSizePixel = 0
    toggleFrame.Size = UDim2.new(1, -5, 0, 40)
    
    local toggleLabel = Instance.new("TextLabel")
    toggleLabel.Name = "Label"
    toggleLabel.Parent = toggleFrame
    toggleLabel.BackgroundTransparency = 1
    toggleLabel.Position = UDim2.new(0, 5, 0, 5)
    toggleLabel.Size = UDim2.new(1, -60, 0, 30)
    toggleLabel.Font = Enum.Font.Gotham
    toggleLabel.Text = name:upper()
    toggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleLabel.TextSize = 11
    toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
    toggleLabel.TextYAlignment = Enum.TextYAlignment.Center
    
    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Parent = toggleFrame
    toggleButton.BackgroundColor3 = initialState and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    toggleButton.BorderSizePixel = 0
    toggleButton.Position = UDim2.new(1, -50, 0, 8)
    toggleButton.Size = UDim2.new(0, 45, 0, 24)
    toggleButton.Font = Enum.Font.Gotham
    toggleButton.Text = initialState and "ON" or "OFF"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.TextSize = 9
    
    local currentState = initialState
    
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

-- Helper function to create method selector for Anti-Record
local function createMethodSelector()
    local methodFrame = Instance.new("Frame")
    methodFrame.Name = "AntiRecordMethodSelector"
    methodFrame.Parent = SettingsScrollFrame
    methodFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    methodFrame.BorderSizePixel = 0
    methodFrame.Size = UDim2.new(1, -5, 0, 80)
    
    local methodLabel = Instance.new("TextLabel")
    methodLabel.Name = "Label"
    methodLabel.Parent = methodFrame
    methodLabel.BackgroundTransparency = 1
    methodLabel.Position = UDim2.new(0, 5, 0, 5)
    methodLabel.Size = UDim2.new(1, -10, 0, 20)
    methodLabel.Font = Enum.Font.Gotham
    methodLabel.Text = "ANTI-RECORD METHOD"
    methodLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    methodLabel.TextSize = 11
    methodLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local methods = {"Overlay", "Flicker", "BlackScreen"}
    local selectedMethod = "Overlay"
    local methodButtons = {}
    
    for i, method in ipairs(methods) do
        local methodButton = Instance.new("TextButton")
        methodButton.Name = method .. "Button"
        methodButton.Parent = methodFrame
        methodButton.BackgroundColor3 = method == selectedMethod and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
        methodButton.BorderSizePixel = 0
        methodButton.Position = UDim2.new((i-1) * 0.33, 5, 0, 30)
        methodButton.Size = UDim2.new(0.3, -5, 0, 25)
        methodButton.Font = Enum.Font.Gotham
        methodButton.Text = method
        methodButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        methodButton.TextSize = 8
        
        methodButton.MouseButton1Click:Connect(function()
            -- Update visual state
            for _, btn in pairs(methodButtons) do
                btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            end
            methodButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
            selectedMethod = method
            
            -- Update AntiRecord method
            if modules.AntiRecord then
                local antiRecordSettings = modules.AntiRecord.getSettings()
                if antiRecordSettings then
                    antiRecordSettings.Method = method
                end
            end
            
            print("Anti-Record method changed to: " .. method)
        end)
        
        methodButton.MouseEnter:Connect(function()
            if method ~= selectedMethod then
                methodButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            end
        end)
        
        methodButton.MouseLeave:Connect(function()
            if method ~= selectedMethod then
                methodButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            end
        end)
        
        methodButtons[method] = methodButton
    end
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
    SettingsFrame.Position = UDim2.new(0.5, -150, 0.2, 0)
    SettingsFrame.Size = UDim2.new(0, 300, 0, 450) -- Increased height for anti-record settings
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
    SettingsTitle.Text = "SETTINGS"
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
    SettingsLayout.Padding = UDim.new(0, 5)
    SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SettingsLayout.FillDirection = Enum.FillDirection.Vertical

    -- Update canvas size when content changes
    SettingsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, SettingsLayout.AbsoluteContentSize.Y + 20)
    end)

    -- Create separator
    local function createSeparator(text)
        local separatorFrame = Instance.new("Frame")
        separatorFrame.Name = text .. "Separator"
        separatorFrame.Parent = SettingsScrollFrame
        separatorFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        separatorFrame.BorderSizePixel = 0
        separatorFrame.Size = UDim2.new(1, -5, 0, 30)
        
        local separatorLabel = Instance.new("TextLabel")
        separatorLabel.Name = "Label"
        separatorLabel.Parent = separatorFrame
        separatorLabel.BackgroundTransparency = 1
        separatorLabel.Size = UDim2.new(1, 0, 1, 0)
        separatorLabel.Font = Enum.Font.GothamBold
        separatorLabel.Text = text:upper()
        separatorLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        separatorLabel.TextSize = 12
        separatorLabel.TextYAlignment = Enum.TextYAlignment.Center
        
        return separatorFrame
    end

    -- Movement Settings Section
    createSeparator("Movement Settings")
    createSlider("Fly Speed", settings.FlySpeed, settings.FlySpeed.min, settings.FlySpeed.max, settings.FlySpeed.default)
    createSlider("Freecam Speed", settings.FreecamSpeed, settings.FreecamSpeed.min, settings.FreecamSpeed.max, settings.FreecamSpeed.default)
    createSlider("Jump Height", settings.JumpHeight, settings.JumpHeight.min, settings.JumpHeight.max, settings.JumpHeight.default)
    createSlider("Walk Speed", settings.WalkSpeed, settings.WalkSpeed.min, settings.WalkSpeed.max, settings.WalkSpeed.default)

    -- Anti-Record Settings Section
    createSeparator("Anti-Record Settings")
    
    -- Anti-Record Enable Toggle
    createSettingsToggle("Enable Anti-Record", false, function(enabled)
        if modules.AntiRecord then
            local antiRecordSettings = modules.AntiRecord.getSettings()
            if antiRecordSettings then
                antiRecordSettings.Enabled = enabled
                -- Toggle anti-record through the module
                if modules.AntiRecord.toggleAntiRecord then
                    modules.AntiRecord.toggleAntiRecord(enabled)
                end
            end
        end
        print("Anti-Record toggled: " .. tostring(enabled))
    end)
    
    -- Anti-Record Method Selector
    createMethodSelector()
    
    -- Anti-Record Sliders
    createSlider("Anti-Record Intensity", settings.AntiRecordIntensity, settings.AntiRecordIntensity.min, settings.AntiRecordIntensity.max, settings.AntiRecordIntensity.default)
    createSlider("Anti-Record Flicker Speed", settings.AntiRecordFlickerSpeed, settings.AntiRecordFlickerSpeed.min, settings.AntiRecordFlickerSpeed.max, settings.AntiRecordFlickerSpeed.default)

    -- Connect Close Settings Button
    CloseSettingsButton.MouseButton1Click:Connect(function()
        SettingsFrame.Visible = false
    end)
    
    -- Update canvas size
    task.wait(0.1)
    SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, SettingsLayout.AbsoluteContentSize.Y + 20)
end

-- Function to create buttons for Settings features
function Settings.loadSettingsButtons(createButton)
    createButton("Open Settings", showSettings)
end

-- Function to reset Settings states
function Settings.resetStates()
    settings.FlySpeed.value = settings.FlySpeed.default
    settings.FreecamSpeed.value = settings.FreecamSpeed.default
    settings.JumpHeight.value = settings.JumpHeight.default
    settings.WalkSpeed.value = settings.WalkSpeed.default
    settings.AntiRecordIntensity.value = settings.AntiRecordIntensity.default
    settings.AntiRecordFlickerSpeed.value = settings.AntiRecordFlickerSpeed.default
    
    if SettingsFrame then
        SettingsFrame.Visible = false
        -- Clear and recreate all settings
        for _, child in pairs(SettingsScrollFrame:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        -- Reinitialize UI
        task.wait(0.1)
        initUI()
    end
    
    -- Reset AntiRecord module
    if modules.AntiRecord and modules.AntiRecord.resetStates then
        modules.AntiRecord.resetStates()
    end
end

-- Function to set dependencies and initialize UI
function Settings.init(deps)
    ScreenGui = deps.ScreenGui
    ScrollFrame = deps.ScrollFrame
    settings = deps.settings
    modules = deps.modules -- Get access to other modules including AntiRecord
    
    -- Initialize UI elements
    initUI()
end

return Settings