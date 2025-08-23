-- settings.lua
-- Settings-related features for MinimalHackGUI by Fari Noveri

-- Dependencies: These must be passed from mainloader.lua
local ScreenGui, ScrollFrame, settings, UserInputService, RunService

-- Initialize module
local Settings = {}

-- UI Elements (to be initialized in initUI function)
local SettingsFrame, SettingsScrollFrame, SettingsLayout

-- Helper function to create a slider UI with mobile touch support
local function createSlider(name, setting, min, max, default)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Name = name .. "Slider"
    sliderFrame.Parent = SettingsScrollFrame
    sliderFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    sliderFrame.BorderSizePixel = 0
    sliderFrame.Size = UDim2.new(1, -5, 0, 70)
    
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(0, 4)
    sliderCorner.Parent = sliderFrame
    
    local sliderLabel = Instance.new("TextLabel")
    sliderLabel.Name = "Label"
    sliderLabel.Parent = sliderFrame
    sliderLabel.BackgroundTransparency = 1
    sliderLabel.Position = UDim2.new(0, 10, 0, 5)
    sliderLabel.Size = UDim2.new(1, -60, 0, 20)
    sliderLabel.Font = Enum.Font.GothamBold
    sliderLabel.Text = name:upper()
    sliderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    sliderLabel.TextSize = 12
    sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "Value"
    valueLabel.Parent = sliderFrame
    valueLabel.BackgroundTransparency = 1
    valueLabel.Position = UDim2.new(1, -55, 0, 5)
    valueLabel.Size = UDim2.new(0, 50, 0, 20)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.Text = tostring(setting.value)
    valueLabel.TextColor3 = Color3.fromRGB(100, 150, 255)
    valueLabel.TextSize = 12
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    
    local sliderBar = Instance.new("Frame")
    sliderBar.Name = "SliderBar"
    sliderBar.Parent = sliderFrame
    sliderBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    sliderBar.BorderSizePixel = 0
    sliderBar.Position = UDim2.new(0, 10, 0, 35)
    sliderBar.Size = UDim2.new(1, -20, 0, 20)
    
    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 10)
    barCorner.Parent = sliderBar
    
    local fillBar = Instance.new("Frame")
    fillBar.Name = "Fill"
    fillBar.Parent = sliderBar
    fillBar.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
    fillBar.BorderSizePixel = 0
    fillBar.Size = UDim2.new((setting.value - min) / (max - min), 0, 1, 0)
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 10)
    fillCorner.Parent = fillBar
    
    local sliderButton = Instance.new("Frame")
    sliderButton.Name = "SliderButton"
    sliderButton.Parent = sliderBar
    sliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sliderButton.BorderSizePixel = 0
    sliderButton.Position = UDim2.new((setting.value - min) / (max - min), -8, 0.5, -8)
    sliderButton.Size = UDim2.new(0, 16, 0, 16)
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = sliderButton
    
    -- Make the slider bar clickable for better mobile support
    local sliderInput = Instance.new("TextButton")
    sliderInput.Name = "SliderInput"
    sliderInput.Parent = sliderBar
    sliderInput.BackgroundTransparency = 1
    sliderInput.Size = UDim2.new(1, 0, 1, 0)
    sliderInput.Text = ""
    
    local dragging = false
    local dragConnection
    
    local function updateSlider(inputPosition)
        local barPos = sliderBar.AbsolutePosition.X
        local barWidth = sliderBar.AbsoluteSize.X
        local relativeX = math.clamp((inputPosition - barPos) / barWidth, 0, 1)
        
        setting.value = min + (max - min) * relativeX
        setting.value = math.floor(setting.value + 0.5) -- Round to nearest integer
        
        fillBar.Size = UDim2.new(relativeX, 0, 1, 0)
        sliderButton.Position = UDim2.new(relativeX, -8, 0.5, -8)
        valueLabel.Text = tostring(setting.value)
    end
    
    -- Handle both mouse and touch input
    sliderInput.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateSlider(input.Position.X)
            
            dragConnection = UserInputService.InputChanged:Connect(function(dragInput)
                if dragging and (dragInput.UserInputType == Enum.UserInputType.MouseMovement or dragInput.UserInputType == Enum.UserInputType.Touch) then
                    updateSlider(dragInput.Position.X)
                end
            end)
        end
    end)
    
    sliderInput.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if dragConnection then
                dragConnection:Disconnect()
                dragConnection = nil
            end
        end
    end)
    
    -- Global input ended to ensure dragging stops
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if dragConnection then
                dragConnection:Disconnect()
                dragConnection = nil
            end
        end
    end)
end

-- Show Settings UI
local function showSettings()
    if SettingsFrame then
        SettingsFrame.Visible = true
        -- Update canvas size to fit all content
        task.wait(0.1) -- Wait for layout to update
        SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, SettingsLayout.AbsoluteContentSize.Y + 20)
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
        warn("ScreenGui not found, cannot create Settings UI")
        return
    end
    
    -- Settings Frame
    SettingsFrame = Instance.new("Frame")
    SettingsFrame.Name = "SettingsFrame"
    SettingsFrame.Parent = ScreenGui
    SettingsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    SettingsFrame.BorderColor3 = Color3.fromRGB(60, 60, 60)
    SettingsFrame.BorderSizePixel = 2
    SettingsFrame.Position = UDim2.new(0.5, -175, 0.1, 0)
    SettingsFrame.Size = UDim2.new(0, 350, 0, 400)
    SettingsFrame.Visible = false
    SettingsFrame.Active = true
    SettingsFrame.Draggable = true
    SettingsFrame.ZIndex = 100

    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 8)
    frameCorner.Parent = SettingsFrame

    -- Settings Title
    local SettingsTitle = Instance.new("TextLabel")
    SettingsTitle.Name = "Title"
    SettingsTitle.Parent = SettingsFrame
    SettingsTitle.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    SettingsTitle.BorderSizePixel = 0
    SettingsTitle.Position = UDim2.new(0, 0, 0, 0)
    SettingsTitle.Size = UDim2.new(1, 0, 0, 45)
    SettingsTitle.Font = Enum.Font.GothamBold
    SettingsTitle.Text = "⚙️ SETTINGS"
    SettingsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    SettingsTitle.TextSize = 16
    SettingsTitle.ZIndex = 101

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = SettingsTitle

    -- Close Settings Button
    local CloseSettingsButton = Instance.new("TextButton")
    CloseSettingsButton.Name = "CloseButton"
    CloseSettingsButton.Parent = SettingsFrame
    CloseSettingsButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    CloseSettingsButton.BorderSizePixel = 0
    CloseSettingsButton.Position = UDim2.new(1, -40, 0, 8)
    CloseSettingsButton.Size = UDim2.new(0, 30, 0, 30)
    CloseSettingsButton.Font = Enum.Font.GothamBold
    CloseSettingsButton.Text = "✕"
    CloseSettingsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseSettingsButton.TextSize = 14
    CloseSettingsButton.ZIndex = 102

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = CloseSettingsButton

    -- Settings ScrollFrame
    SettingsScrollFrame = Instance.new("ScrollingFrame")
    SettingsScrollFrame.Name = "SettingsScrollFrame"
    SettingsScrollFrame.Parent = SettingsFrame
    SettingsScrollFrame.BackgroundTransparency = 1
    SettingsScrollFrame.Position = UDim2.new(0, 15, 0, 60)
    SettingsScrollFrame.Size = UDim2.new(1, -30, 1, -75)
    SettingsScrollFrame.ScrollBarThickness = 6
    SettingsScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    SettingsScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    SettingsScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    SettingsScrollFrame.BorderSizePixel = 0
    SettingsScrollFrame.ZIndex = 101
    SettingsScrollFrame.ScrollingEnabled = true

    -- Settings Layout
    SettingsLayout = Instance.new("UIListLayout")
    SettingsLayout.Parent = SettingsScrollFrame
    SettingsLayout.Padding = UDim.new(0, 10)
    SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SettingsLayout.FillDirection = Enum.FillDirection.Vertical
    SettingsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    -- Create sliders for settings only if settings exist
    if settings then
        if settings.FlySpeed then
            createSlider("Fly Speed", settings.FlySpeed, settings.FlySpeed.min, settings.FlySpeed.max, settings.FlySpeed.default)
        end
        if settings.FreecamSpeed then
            createSlider("Freecam Speed", settings.FreecamSpeed, settings.FreecamSpeed.min, settings.FreecamSpeed.max, settings.FreecamSpeed.default)
        end
        if settings.JumpHeight then
            createSlider("Jump Height", settings.JumpHeight, settings.JumpHeight.min, settings.JumpHeight.max, settings.JumpHeight.default)
        end
        if settings.WalkSpeed then
            createSlider("Walk Speed", settings.WalkSpeed, settings.WalkSpeed.min, settings.WalkSpeed.max, settings.WalkSpeed.default)
        end
        
        -- Add new settings for Rewind and Boost if needed
        if settings.RewindTime then
            createSlider("Rewind Time", settings.RewindTime, settings.RewindTime.min, settings.RewindTime.max, settings.RewindTime.default)
        end
        if settings.BoostMultiplier then
            createSlider("Boost Multiplier", settings.BoostMultiplier, settings.BoostMultiplier.min, settings.BoostMultiplier.max, settings.BoostMultiplier.default)
        end
    end

    -- Connect Close Settings Button
    CloseSettingsButton.MouseButton1Click:Connect(function()
        hideSettings()
    end)
    
    -- Update canvas size after creating all sliders
    task.spawn(function()
        task.wait(0.1)
        SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, SettingsLayout.AbsoluteContentSize.Y + 20)
    end)
end

-- Function to recreate all sliders (used when resetting)
local function recreateSliders()
    if not SettingsScrollFrame or not settings then return end
    
    -- Clear existing sliders
    for _, child in pairs(SettingsScrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name:find("Slider") then
            child:Destroy()
        end
    end
    
    -- Recreate sliders
    if settings.FlySpeed then
        createSlider("Fly Speed", settings.FlySpeed, settings.FlySpeed.min, settings.FlySpeed.max, settings.FlySpeed.default)
    end
    if settings.FreecamSpeed then
        createSlider("Freecam Speed", settings.FreecamSpeed, settings.FreecamSpeed.min, settings.FreecamSpeed.max, settings.FreecamSpeed.default)
    end
    if settings.JumpHeight then
        createSlider("Jump Height", settings.JumpHeight, settings.JumpHeight.min, settings.JumpHeight.max, settings.JumpHeight.default)
    end
    if settings.WalkSpeed then
        createSlider("Walk Speed", settings.WalkSpeed, settings.WalkSpeed.min, settings.WalkSpeed.max, settings.WalkSpeed.default)
    end
    if settings.RewindTime then
        createSlider("Rewind Time", settings.RewindTime, settings.RewindTime.min, settings.RewindTime.max, settings.RewindTime.default)
    end
    if settings.BoostMultiplier then
        createSlider("Boost Multiplier", settings.BoostMultiplier, settings.BoostMultiplier.min, settings.BoostMultiplier.max, settings.BoostMultiplier.default)
    end
    
    -- Update canvas size
    task.spawn(function()
        task.wait(0.1)
        if SettingsScrollFrame and SettingsLayout then
            SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, SettingsLayout.AbsoluteContentSize.Y + 20)
        end
    end)
end

-- Function to create buttons for Settings features
function Settings.loadSettingsButtons(createButton)
    if createButton then
        createButton("Settings", showSettings)
    else
        warn("createButton function not provided to Settings.loadSettingsButtons")
    end
end

-- Function to reset Settings states
function Settings.resetStates()
    if not settings then
        warn("Settings table not available for reset")
        return
    end
    
    -- Reset all setting values to defaults
    if settings.FlySpeed then
        settings.FlySpeed.value = settings.FlySpeed.default
    end
    if settings.FreecamSpeed then
        settings.FreecamSpeed.value = settings.FreecamSpeed.default
    end
    if settings.JumpHeight then
        settings.JumpHeight.value = settings.JumpHeight.default
    end
    if settings.WalkSpeed then
        settings.WalkSpeed.value = settings.WalkSpeed.default
    end
    if settings.RewindTime then
        settings.RewindTime.value = settings.RewindTime.default
    end
    if settings.BoostMultiplier then
        settings.BoostMultiplier.value = settings.BoostMultiplier.default
    end
    
    -- Hide settings frame
    hideSettings()
    
    -- Recreate sliders to reflect reset values
    recreateSliders()
    
    print("Settings reset to default values")
end

-- Function to update a specific setting
function Settings.updateSetting(settingName, value)
    if settings and settings[settingName] then
        settings[settingName].value = value
        print("Updated " .. settingName .. " to " .. tostring(value))
    else
        warn("Setting " .. settingName .. " not found")
    end
end

-- Function to get a setting value
function Settings.getSetting(settingName)
    if settings and settings[settingName] then
        return settings[settingName].value
    end
    return nil
end

-- Function to set dependencies and initialize UI
function Settings.init(deps)
    if not deps then
        warn("No dependencies provided to Settings.init")
        return false
    end
    
    ScreenGui = deps.ScreenGui
    ScrollFrame = deps.ScrollFrame
    settings = deps.settings
    UserInputService = deps.UserInputService or game:GetService("UserInputService")
    RunService = deps.RunService or game:GetService("RunService")
    
    if not ScreenGui then
        warn("ScreenGui not provided to Settings")
        return false
    end
    
    if not settings then
        warn("Settings table not provided to Settings")
        return false
    end
    
    -- Initialize UI elements
    initUI()
    
    print("Settings module initialized successfully")
    return true
end

-- Function to show/hide settings (can be called externally)
function Settings.toggle()
    if SettingsFrame then
        SettingsFrame.Visible = not SettingsFrame.Visible
        if SettingsFrame.Visible then
            SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, SettingsLayout.AbsoluteContentSize.Y + 20)
        end
    end
end

-- Function to check if settings is open
function Settings.isOpen()
    return SettingsFrame and SettingsFrame.Visible
end

-- Debug function
function Settings.debug()
    print("=== Settings Module Debug Info ===")
    print("SettingsFrame exists:", SettingsFrame ~= nil)
    print("SettingsFrame visible:", SettingsFrame and SettingsFrame.Visible)
    print("Settings table exists:", settings ~= nil)
    if settings then
        print("Available settings:")
        for name, setting in pairs(settings) do
            if type(setting) == "table" and setting.value then
                print("  " .. name .. ":", setting.value, "(min:" .. (setting.min or "?") .. ", max:" .. (setting.max or "?") .. ", default:" .. (setting.default or "?") .. ")")
            end
        end
    end
    print("UserInputService:", UserInputService ~= nil)
    print("RunService:", RunService ~= nil)
    print("ScreenGui:", ScreenGui ~= nil)
    print("=====================================")
end

-- Cleanup function
function Settings.cleanup()
    if SettingsFrame then
        SettingsFrame:Destroy()
        SettingsFrame = nil
    end
    SettingsScrollFrame = nil
    SettingsLayout = nil
    print("Settings module cleaned up")
end

return Settings