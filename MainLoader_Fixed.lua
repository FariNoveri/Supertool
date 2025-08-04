-- MainLoader Fixed Version - Focus on GUI Visibility
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Debug GUI to confirm script is running
local function createDebugGUI()
    local debugGui = Instance.new("ScreenGui")
    debugGui.Name = "DebugGUI"
    debugGui.Parent = game.CoreGui
    
    local debugFrame = Instance.new("Frame")
    debugFrame.Size = UDim2.new(0, 200, 0, 100)
    debugFrame.Position = UDim2.new(0.5, -100, 0.1, 0)
    debugFrame.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    debugFrame.Parent = debugGui
    
    local debugText = Instance.new("TextLabel")
    debugText.Size = UDim2.new(1, 0, 1, 0)
    debugText.BackgroundTransparency = 1
    debugText.TextColor3 = Color3.fromRGB(255, 255, 255)
    debugText.Text = "DEBUG: Script Loaded"
    debugText.TextSize = 16
    debugText.Font = Enum.Font.GothamBold
    debugText.Parent = debugFrame
    
    -- Auto destroy after 5 seconds
    task.wait(5)
    debugGui:Destroy()
end

-- Notification function
local function notify(message, color)
    color = color or Color3.fromRGB(255, 255, 255)
    
    local notification = Instance.new("ScreenGui")
    notification.Name = "Notification"
    notification.Parent = game.CoreGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 50)
    frame.Position = UDim2.new(0.5, -150, 0.1, 0)
    frame.BackgroundColor3 = color
    frame.BorderSizePixel = 0
    frame.Parent = notification
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame
    
    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.Text = message
    text.TextSize = 16
    text.Font = Enum.Font.GothamBold
    text.Parent = frame
    
    -- Auto destroy after 3 seconds
    task.wait(3)
    notification:Destroy()
end

-- Create main GUI
local function createMainGUI()
    print("🔧 Creating main GUI...")
    
    -- Clean up old GUI
    local oldGui = player.PlayerGui:FindFirstChild("MainLoaderGUI")
    if oldGui then
        oldGui:Destroy()
    end
    
    -- Create new GUI
    local gui = Instance.new("ScreenGui")
    gui.Name = "MainLoaderGUI"
    gui.ResetOnSpawn = false
    
    -- Try CoreGui first, then PlayerGui
    local success1 = pcall(function()
        gui.Parent = game.CoreGui
    end)
    
    if not success1 then
        gui.Parent = player:WaitForChild("PlayerGui", 10)
    end
    
    -- Create logo button
    local logo = Instance.new("TextButton")
    logo.Size = UDim2.new(0, 80, 0, 80)
    logo.Position = UDim2.new(0.85, 0, 0.8, 0)
    logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
    logo.TextColor3 = Color3.fromRGB(255, 255, 255)
    logo.Text = "⚡"
    logo.TextSize = 30
    logo.Font = Enum.Font.GothamBold
    logo.ZIndex = 1000
    logo.Visible = true
    logo.Parent = gui
    
    -- Make logo circular
    local logoCorner = Instance.new("UICorner")
    logoCorner.CornerRadius = UDim.new(0, 40)
    logoCorner.Parent = logo
    
    -- Create main frame
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 400, 0, 300)
    frame.Position = UDim2.new(0.5, -200, 0.5, -150)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.ZIndex = 50
    frame.Parent = gui
    
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 15)
    frameCorner.Parent = frame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 50)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.Text = "MainLoader Enhanced"
    title.ZIndex = 51
    title.Parent = frame
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 40, 0, 40)
    closeBtn.Position = UDim2.new(1, -50, 0, 10)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Text = "×"
    closeBtn.TextSize = 24
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.ZIndex = 52
    closeBtn.Parent = frame
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 20)
    closeCorner.Parent = closeBtn
    
    -- Simple buttons
    local function createButton(text, callback, yPos)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0.8, 0, 0, 40)
        button.Position = UDim2.new(0.1, 0, 0, yPos)
        button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 16
        button.Font = Enum.Font.GothamBold
        button.Text = text
        button.ZIndex = 52
        button.Parent = frame
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 8)
        buttonCorner.Parent = button
        
        button.MouseButton1Click:Connect(callback)
        return button
    end
    
    -- Create buttons
    createButton("Fly", function() notify("🛫 Fly toggled", Color3.fromRGB(0, 150, 255)) end, 70)
    createButton("Speed", function() notify("🏃 Speed toggled", Color3.fromRGB(0, 150, 255)) end, 120)
    createButton("Noclip", function() notify("🚪 Noclip toggled", Color3.fromRGB(0, 150, 255)) end, 170)
    createButton("God Mode", function() notify("🛡️ God mode toggled", Color3.fromRGB(0, 150, 255)) end, 220)
    
    -- Logo functionality
    logo.MouseButton1Click:Connect(function()
        frame.Visible = not frame.Visible
        notify(frame.Visible and "📱 GUI Opened" or "📱 GUI Closed")
        
        if frame.Visible then
            logo.Text = "✕"
            logo.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        else
            logo.Text = "⚡"
            logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        end
    end)
    
    -- Close button functionality
    closeBtn.MouseButton1Click:Connect(function()
        frame.Visible = false
        logo.Text = "⚡"
        logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        notify("📱 GUI Closed")
    end)
    
    print("✅ Main GUI created successfully")
    notify("✅ MainLoader GUI created successfully", Color3.fromRGB(0, 255, 0))
    
    return gui
end

-- Main function
local function main()
    print("🚀 Starting MainLoader Fixed...")
    
    -- Create debug GUI first
    createDebugGUI()
    
    -- Wait a bit
    task.wait(2)
    
    -- Create main GUI
    local success, errorMsg = pcall(function()
        createMainGUI()
    end)
    
    if not success then
        print("❌ GUI creation failed: " .. tostring(errorMsg))
        notify("❌ GUI creation failed", Color3.fromRGB(255, 100, 100))
        
        -- Create fallback GUI
        local fallbackGui = Instance.new("ScreenGui")
        fallbackGui.Name = "MainLoaderFallback"
        fallbackGui.Parent = game.CoreGui
        
        local fallbackBtn = Instance.new("TextButton")
        fallbackBtn.Size = UDim2.new(0, 100, 0, 50)
        fallbackBtn.Position = UDim2.new(0.9, -100, 0.1, 0)
        fallbackBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        fallbackBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        fallbackBtn.Text = "⚡"
        fallbackBtn.TextSize = 18
        fallbackBtn.Font = Enum.Font.GothamBold
        fallbackBtn.ZIndex = 1000
        fallbackBtn.Visible = true
        fallbackBtn.Parent = fallbackGui
        
        fallbackBtn.MouseButton1Click:Connect(function()
            notify("⚠️ Main GUI failed to create", Color3.fromRGB(255, 100, 100))
        end)
    else
        print("🎉 MainLoader Fixed loaded successfully!")
        notify("🎉 MainLoader Fixed Ready! Look for ⚡ button", Color3.fromRGB(0, 255, 0))
    end
end

-- Start the script
main() 