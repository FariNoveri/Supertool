-- MainLoader_Minimal.lua - Debug GUI untuk Android
-- Fokus: Pastikan GUI muncul dengan frame merah besar

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui, logo, frame

-- Mobile detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Notification system
local function notify(message, color)
    color = color or Color3.fromRGB(0, 255, 0)
    local success, errorMsg = pcall(function()
        if not gui then return end
        local notif = Instance.new("TextLabel")
        notif.Size = UDim2.new(0, 300, 0, 50)
        notif.Position = UDim2.new(0.5, -150, 0, 100)
        notif.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notif.BackgroundTransparency = 0.3
        notif.TextColor3 = color
        notif.TextScaled = true
        notif.Font = Enum.Font.GothamBold
        notif.Text = message
        notif.BorderSizePixel = 0
        notif.ZIndex = 10
        notif.Parent = gui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = notif
        
        TweenService:Create(notif, TweenInfo.new(0.3), {BackgroundTransparency = 0.1}):Play()
        task.wait(2)
        TweenService:Create(notif, TweenInfo.new(0.3), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
        task.wait(0.3)
        notif:Destroy()
    end)
    if not success then
        warn("Notify error: " .. errorMsg)
    end
end

-- Create minimal GUI
local function createGUI()
    local success, errorMsg = pcall(function()
        gui = Instance.new("ScreenGui")
        gui.Name = "DebugGUI"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Enabled = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Global -- Force render di atas UI lain
        local playerGui = player:WaitForChild("PlayerGui", 15)
        if not playerGui then
            warn("PlayerGui not found, trying CoreGui")
            gui.Parent = game:GetService("CoreGui")
        else
            gui.Parent = playerGui
        end

        -- Logo sederhana
        logo = Instance.new("ImageButton")
        logo.Size = UDim2.new(0, 80, 0, 80)
        logo.Position = UDim2.new(0, 10, 0, 10)
        logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        logo.BorderSizePixel = 0
        logo.Image = "rbxassetid://3570695787"
        logo.Visible = true
        logo.ZIndex = 10
        logo.Parent = gui
        
        local logoCorner = Instance.new("UICorner")
        logoCorner.CornerRadius = UDim.new(0, 40)
        logoCorner.Parent = logo

        -- Frame merah besar untuk debug
        frame = Instance.new("Frame")
        frame.Size = isMobile and UDim2.new(0.95, 0, 0.85, 0) or UDim2.new(0, 900, 0, 550)
        frame.Position = isMobile and UDim2.new(0.025, 0, 0.075, 0) or UDim2.new(0.5, -450, 0.5, -275)
        frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Merah mencolok
        frame.BorderSizePixel = 0
        frame.Visible = true
        frame.ZIndex = 5
        frame.Parent = gui
        
        local frameCorner = Instance.new("UICorner")
        frameCorner.CornerRadius = UDim.new(0, 12)
        frameCorner.Parent = frame

        -- Tes label di frame
        local testLabel = Instance.new("TextLabel")
        testLabel.Size = UDim2.new(1, 0, 0, 50)
        testLabel.Position = UDim2.new(0, 0, 0, 0)
        testLabel.BackgroundTransparency = 1
        testLabel.TextColor3 = Color3.new(1, 1, 1)
        testLabel.TextScaled = true
        testLabel.Font = Enum.Font.GothamBold
        testLabel.Text = "DEBUG GUI - SHOULD BE VISIBLE"
        testLabel.ZIndex = 6
        testLabel.Parent = frame
    end)
    if not success then
        warn("createGUI error: " .. errorMsg)
        notify("⚠️ Failed to create GUI: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
        task.wait(2)
        createGUI()
    end
end

-- Touch drag system
local function makeDraggable(element)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    if isMobile then
        element.TouchPan:Connect(function(totalTranslation, _, state)
            if state == Enum.UserInputState.Begin then
                dragging = true
                startPos = element.Position
            elseif state == Enum.UserInputState.Change and dragging then
                element.Position = UDim2.new(
                    startPos.X.Scale, 
                    startPos.X.Offset + totalTranslation.X,
                    startPos.Y.Scale, 
                    startPos.Y.Offset + totalTranslation.Y
                )
            elseif state == Enum.UserInputState.End then
                dragging = false
            end
        end)
    else
        element.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = element.Position
            end
        end)
        
        element.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
                local delta = input.Position - dragStart
                element.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
        
        element.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
    end
end

-- Initialize
local function init()
    local success, errorMsg = pcall(function()
        createGUI()
        makeDraggable(logo)
        
        logo.Activated:Connect(function()
            frame.Visible = not frame.Visible
            notify("🖼️ GUI Toggled " .. (frame.Visible and "ON" or "OFF"), Color3.fromRGB(frame.Visible and 0 or 255, frame.Visible and 255 or 100, frame.Visible and 0 or 100))
        end)
        
        -- Force visibilitas check
        if gui and frame and logo then
            gui.Enabled = true
            frame.Visible = true
            logo.Visible = true
            notify("🖼️ Debug GUI Initialized", Color3.fromRGB(0, 255, 0))
        else
            error("GUI, Frame, or Logo not initialized")
        end
    end)
    if not success then
        warn("init error: " .. errorMsg)
        notify("⚠️ Failed to initialize: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
        task.wait(2)
        init()
    end
end

init()
