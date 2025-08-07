-- mainloader.lua
-- Main loader for MinimalHackGUI by Fari Noveri

local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local screenGui = nil
local modules = {}
local tabs = {}
local currentTab = nil
local connections = {}

-- Module URLs
local moduleUrls = {
    Settings = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Settings.lua",
    Visual = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Visual.lua",
    Teleport = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Teleport.lua",
    Movement = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement.lua",
    Player = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Player.lua",
    Utility = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Utility.lua",
    Info = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Info.lua",
    AntiAdmin = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/AntiAdmin.lua",
    AntiAdminInfo = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/AntiAdminInfo.lua"
}

-- Utils
local utils = {
    notify = function(message)
        print("[Supertool] " .. message)
        if game.StarterGui and game.StarterGui.SetCore then
            pcall(function()
                game.StarterGui:SetCore("SendNotification", {
                    Title = "Supertool",
                    Text = message,
                    Duration = 3
                })
            end)
        end
    end,
    createToggle = function(name, state, callback, isButton)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -10, 0, 40)
        frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        frame.BorderSizePixel = 0
        
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -10, 0, 30)
        button.Position = UDim2.new(0, 5, 0, 5)
        button.BackgroundColor3 = isButton and Color3.fromRGB(40, 40, 80) or (state and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(60, 60, 60))
        button.Text = name:upper()
        button.Font = Enum.Font.Gotham
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 12
        button.Parent = frame
        
        button.MouseButton1Click:Connect(function()
            if not isButton then
                state = not state
                button.BackgroundColor3 = state and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(60, 60, 60)
            end
            callback(state)
        end)
        
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = isButton and Color3.fromRGB(50, 50, 100) or (state and Color3.fromRGB(120, 120, 120) or Color3.fromRGB(80, 80, 80))
        end)
        
        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = isButton and Color3.fromRGB(40, 40, 80) or (state and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(60, 60, 60))
        end)
        
        return frame
    end,
    createSlider = function(name, min, max, value, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -10, 0, 60)
        frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        frame.BorderSizePixel = 0
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -10, 0, 20)
        label.Position = UDim2.new(0, 5, 0, 5)
        label.BackgroundTransparency = 1
        label.Text = name .. ": " .. value
        label.Font = Enum.Font.Gotham
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame
        
        local slider = Instance.new("TextButton")
        slider.Size = UDim2.new(1, -10, 0, 30)
        slider.Position = UDim2.new(0, 5, 0, 25)
        slider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        slider.Text = ""
        slider.Parent = frame
        
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
        fill.BorderSizePixel = 0
        fill.Parent = slider
        
        slider.MouseButton1Down:Connect(function()
            local connection
            connection = UserInputService.InputChanged:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                    local mousePos = input.Position.X
                    local sliderPos = slider.AbsolutePosition.X
                    local sliderWidth = slider.AbsoluteSize.X
                    local newValue = math.clamp(min + (max - min) * (mousePos - sliderPos) / sliderWidth, min, max)
                    newValue = math.floor(newValue + 0.5)
                    fill.Size = UDim2.new((newValue - min) / (max - min), 0, 1, 0)
                    label.Text = name .. ": " .. newValue
                    callback(newValue)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    connection:Disconnect()
                end
            end)
        end)
        
        return frame
    end,
    createButton = function(name, callback)
        return utils.createToggle(name, false, callback, true)
    end,
    createKeybind = function(name, key, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -10, 0, 40)
        frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        frame.BorderSizePixel = 0
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -10, 0, 20)
        label.Position = UDim2.new(0, 5, 0, 5)
        label.BackgroundTransparency = 1
        label.Text = name .. ": " .. key.Name
        label.Font = Enum.Font.Gotham
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame
        
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0, 80, 0, 30)
        button.Position = UDim2.new(1, -85, 0, 5)
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        button.Text = "SET KEY"
        button.Font = Enum.Font.Gotham
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 12
        button.Parent = frame
        
        button.MouseButton1Click:Connect(function()
            button.Text = "Press a key..."
            local connection
            connection = UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    callback(input.KeyCode)
                    label.Text = name .. ": " .. input.KeyCode.Name
                    button.Text = "SET KEY"
                    connection:Disconnect()
                end
            end)
        end)
        
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        end)
        
        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end)
        
        return frame
    end
}

-- Create GUI
local function createGUI()
    screenGui = CoreGui:FindFirstChild("MinimalHackGUI")
    if screenGui then
        screenGui:Destroy()
        print("[Supertool] Existing MinimalHackGUI destroyed")
    end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MinimalHackGUI"
    screenGui.Parent = player.PlayerGui -- Changed to PlayerGui for testing
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    print("[Supertool] ScreenGui created and parented to PlayerGui")
    
    local uiScale = Instance.new("UIScale")
    uiScale.Name = "UIScale"
    uiScale.Parent = screenGui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 300, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    mainFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    mainFrame.BorderSizePixel = 1
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Visible = true
    mainFrame.Parent = screenGui
    print("[Supertool] MainFrame created and set to visible")
    
    local topBar = Instance.new("Frame")
    topBar.Name = "TopBar"
    topBar.Size = UDim2.new(1, 0, 0, 35)
    topBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    topBar.BorderSizePixel = 0
    topBar.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 40, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Supertool - Fari Noveri"
    title.Font = Enum.Font.GothamBold
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = topBar
    
    local logo = Instance.new("TextLabel")
    logo.Size = UDim2.new(0, 30, 0, 30)
    logo.Position = UDim2.new(0, 5, 0, 5)
    logo.BackgroundTransparency = 1
    logo.Text = "S"
    logo.Font = Enum.Font.GothamBold
    logo.TextColor3 = Color3.fromRGB(255, 255, 255)
    logo.TextScaled = true
    logo.Parent = topBar
    
    local minimizeButton = Instance.new("TextButton")
    minimizeButton.Name = "MinimizeButton"
    minimizeButton.Size = UDim2.new(0, 30, 0, 30)
    minimizeButton.Position = UDim2.new(1, -35, 0, 5)
    minimizeButton.BackgroundTransparency = 1
    minimizeButton.Text = "_"
    minimizeButton.Font = Enum.Font.GothamBold
    minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizeButton.TextSize = 16
    minimizeButton.Parent = topBar
    
    local logoButton = Instance.new("TextButton")
    logoButton.Name = "LogoButton"
    logoButton.Size = UDim2.new(0, 40, 0, 40)
    logoButton.Position = UDim2.new(0.5, -20, 0.5, -20)
    logoButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    logoButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
    logoButton.BorderSizePixel = 1
    logoButton.Text = "S"
    logoButton.Font = Enum.Font.GothamBold
    logoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    logoButton.TextSize = 16
    logoButton.Visible = false
    logoButton.Active = true
    logoButton.Draggable = true
    logoButton.Parent = screenGui
    
    local tabFrame = Instance.new("Frame")
    tabFrame.Name = "TabFrame"
    tabFrame.Size = UDim2.new(1, 0, 0, 40)
    tabFrame.Position = UDim2.new(0, 0, 0, 35)
    tabFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    tabFrame.BorderSizePixel = 0
    tabFrame.Parent = mainFrame
    
    local tabLayout = Instance.new("UIListLayout")
    tabLayout.FillDirection = Enum.FillDirection.Horizontal
    tabLayout.Padding = UDim.new(0, 5)
    tabLayout.Parent = tabFrame
    
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -10, 1, -80)
    contentFrame.Position = UDim2.new(0, 5, 0, 80)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame
    
    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(mainFrame, tweenInfo, {Size = UDim2.new(0, 300, 0, 400)})
    tween:Play()
    
    return minimizeButton, logoButton
end

-- Create tab
local function createTab(name)
    local tabButton = Instance.new("TextButton")
    tabButton.Name = name .. "Tab"
    tabButton.Size = UDim2.new(0, 80, 0, 40)
    tabButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    tabButton.Text = name:upper()
    tabButton.Font = Enum.Font.Gotham
    tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    tabButton.TextSize = 12
    tabButton.Parent = screenGui.MainFrame.TabFrame
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = name .. "Content"
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.Position = UDim2.new(0, 0, 0, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    scrollFrame.Visible = false
    scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    scrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Parent = screenGui.MainFrame.ContentFrame
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scrollFrame
    
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end)
    
    tabs[name] = { button = tabButton, scrollFrame = scrollFrame }
    
    tabButton.MouseButton1Click:Connect(function()
        switchCategory(name)
    end)
    
    tabButton.MouseEnter:Connect(function()
        if currentTab ~= name then
            tabButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        end
    end)
    
    tabButton.MouseLeave:Connect(function()
        if currentTab ~= name then
            tabButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
    end)
end

-- Switch category
local function switchCategory(category)
    if currentTab == category then return end
    
    if currentTab and tabs[currentTab] then
        tabs[currentTab].scrollFrame.Visible = false
        tabs[currentTab].button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end
    
    currentTab = category
    if tabs[category] then
        tabs[category].scrollFrame.Visible = true
        tabs[category].button.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        
        tabs[category].scrollFrame:ClearAllChildren()
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 5)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = tabs[category].scrollFrame
        
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            tabs[category].scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
        end)
        
        if modules[category] and modules[category].loadButtons then
            task.defer(function()
                pcall(function()
                    modules[category].loadButtons(tabs[category].scrollFrame, utils)
                end)
            end)
        else
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Name = "ErrorLabel"
            errorLabel.Parent = tabs[category].scrollFrame
            errorLabel.BackgroundTransparency = 1
            errorLabel.Size = UDim2.new(1, 0, 0, 30)
            errorLabel.Font = Enum.Font.Gotham
            errorLabel.Text = "Failed to load " .. category .. " module"
            errorLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            errorLabel.TextSize = 12
            errorLabel.TextXAlignment = Enum.TextXAlignment.Center
            utils.notify("Failed to load " .. category .. " module")
        end
    end
    
    for _, tab in pairs(tabs) do
        if tab.button.Name ~= category .. "Tab" then
            tab.button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
    end
end

-- Load modules
local function loadModules()
    for name, url in pairs(moduleUrls) do
        local success, result = pcall(function()
            local response = game:HttpGet(url)
            if not response or response == "" then
                error("Empty or no response from " .. url)
            end
            local module = loadstring(response)()
            if type(module) ~= "table" or not module.loadButtons then
                error("Invalid module structure for " .. name)
            end
            return module
        end)
        if success then
            modules[name] = result
            modules[name].utils = utils
            utils.notify("Loaded module: " .. name)
        else
            warn("[Supertool] Failed to load module " .. name .. ": " .. tostring(result))
            utils.notify("Failed to load module: " .. name .. " - Error: " .. tostring(result))
            modules[name] = {
                loadButtons = function(scrollFrame, _)
                    local errorLabel = Instance.new("TextLabel")
                    errorLabel.Name = "ErrorLabel"
                    errorLabel.Parent = scrollFrame
                    errorLabel.BackgroundTransparency = 1
                    errorLabel.Size = UDim2.new(1, 0, 0, 30)
                    errorLabel.Font = Enum.Font.Gotham
                    errorLabel.Text = "Failed to load " .. name .. " module: " .. tostring(result)
                    errorLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
                    errorLabel.TextSize = 12
                    errorLabel.TextXAlignment = Enum.TextXAlignment.Center
                end
            }
        end
    end
end

-- Minimize/Maximize
local function minimizeGUI()
    print("[Supertool] Minimizing GUI")
    screenGui.MainFrame.Visible = false
    screenGui.LogoButton.Visible = true
end

local function maximizeGUI()
    print("[Supertool] Maximizing GUI")
    screenGui.MainFrame.Visible = true
    screenGui.LogoButton.Visible = false
end

-- Initialize
local function initialize()
    local minimizeButton, logoButton = createGUI()
    for name, _ in pairs(moduleUrls) do
        createTab(name)
    end
    loadModules()
    switchCategory("Settings")
    
    if modules.Settings then
        screenGui.UIScale.Scale = modules.Settings.settings and modules.Settings.settings.uiScale or 1
        connections.input = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if not gameProcessed and input.KeyCode == (modules.Settings.settings and modules.Settings.settings.toggleKey or Enum.KeyCode.Insert) then
                if screenGui.MainFrame.Visible then
                    minimizeGUI()
                else
                    maximizeGUI()
                end
                utils.notify("GUI " .. (screenGui.MainFrame.Visible and "shown" or "hidden"))
            end
        end)
    end
    
    minimizeButton.MouseButton1Click:Connect(minimizeGUI)
    logoButton.MouseButton1Click:Connect(maximizeGUI)
    
    player.CharacterAdded:Connect(function(newCharacter)
        for name, module in pairs(modules) do
            if module.reset then
                pcall(function()
                    module.reset()
                end)
            end
        end
        switchCategory(currentTab)
    end)
    
    utils.notify("MinimalHackGUI Loaded - By Fari Noveri")
end

-- Cleanup
local function cleanup()
    for name, module in pairs(modules) do
        if module.cleanup then
            pcall(function()
                module.cleanup()
            end)
        end
    end
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    if screenGui then
        screenGui:Destroy()
        screenGui = nil
    end
    print("[Supertool] Cleanup completed")
end

-- Handle script destruction
game:BindToClose(cleanup)
screenGui = CoreGui:FindFirstChild("MinimalHackGUI")
if screenGui then
    screenGui.AncestryChanged:Connect(function(_, parent)
        if not parent then
            cleanup()
        end
    end)
end

-- Run
print("[Supertool] Initializing GUI")
initialize()

-- Return
return {
    cleanup = cleanup
}