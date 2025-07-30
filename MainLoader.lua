-- NoCombatGUI_Krnl.lua - GUI Minimal tanpa Combat untuk Krnl Android
-- Fokus logo dan frame muncul, fitur lain ditunda

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid, hr, char
local gui, frame, logo

-- Feature states (ditunda sampai GUI muncul)
local flying, noclip, autoHeal, noFall, godMode = false, false, false, false, false
local flySpeed = 16
local savedPositions = {}
local followTarget = nil
local connections = {}
local antiRagdoll = false
local antiSpectate = false
local antiReport = false
local nickHidden = false
local customNick = ""
local randomNick = false
local trajectoryEnabled = false
local macroRecording = false
local macroPlaying = false
local macroActions = {}
local macroNoclip = false
local autoPlayOnRespawn = false

-- Mobile detection
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Notification system
local function notify(message, color)
    local success, errorMsg = pcall(function()
        if not gui then
            warn("Notify failed: GUI not initialized")
            return
        end
        local notif = Instance.new("TextLabel")
        notif.Size = UDim2.new(0, 120, 0, 25)
        notif.Position = UDim2.new(0.5, -60, 0, 5)
        notif.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notif.BackgroundTransparency = 0.7
        notif.TextColor3 = color or Color3.fromRGB(0, 255, 0)
        notif.TextScaled = true
        notif.Font = Enum.Font.Gotham
        notif.Text = message
        notif.BorderSizePixel = 0
        notif.ZIndex = 3
        notif.Parent = gui
        task.wait(2)
        notif:Destroy()
    end)
    if not success then
        warn("Notify error: " .. tostring(errorMsg))
    end
end

-- Initialize character
local function initChar()
    local success, errorMsg = pcall(function()
        task.wait(15) -- Delay ekstra panjang
        char = player.Character or player.CharacterAdded:Wait()
        humanoid = char:WaitForChild("Humanoid", 40)
        hr = char:WaitForChild("HumanoidRootPart", 40)
        if not humanoid or not hr then
            error("Failed to find Humanoid or HumanoidRootPart")
        end
        warn("Character initialized")
    end)
    if not success then
        warn("initChar error: " .. tostring(errorMsg))
        notify("⚠️ Init character failed, retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(15)
        initChar()
    end
end

-- Create minimal GUI
local function createGUI()
    local success, errorMsg = pcall(function()
        if gui then
            gui:Destroy()
            gui = nil
        end

        gui = Instance.new("ScreenGui")
        gui.Name = "NoCombatGUI_Krnl"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Enabled = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

        local coreGui = game:GetService("CoreGui")
        local playerGui = player:WaitForChild("PlayerGui", 40)
        gui.Parent = coreGui
        task.wait(3)
        if playerGui then
            gui.Parent = playerGui
        end
        warn("GUI parented to " .. (gui.Parent == playerGui and "PlayerGui" or "CoreGui"))

        logo = Instance.new("ImageButton")
        logo.Size = UDim2.new(0, 40, 0, 40)
        logo.Position = UDim2.new(0, 5, 0, 5)
        logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        logo.BorderSizePixel = 0
        logo.Image = "rbxassetid://3570695787"
        logo.ZIndex = 3
        logo.Parent = gui
        warn("Logo created")

        frame = Instance.new("Frame")
        frame.Size = isMobile and UDim2.new(0.8, 0, 0.6, 0) or UDim2.new(0, 200, 0, 150)
        frame.Position = isMobile and UDim2.new(0.1, 0, 0.2, 0) or UDim2.new(0.5, -100, 0.5, -75)
        frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        frame.BorderSizePixel = 0
        frame.Visible = false
        frame.ZIndex = 3
        frame.Parent = gui
        warn("Frame created")

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 25)
        title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        title.TextColor3 = Color3.new(1, 1, 1)
        title.Text = "🚀 Krnl Tool"
        title.TextScaled = true
        title.Font = Enum.Font.Gotham
        title.ZIndex = 3
        title.Parent = frame
        warn("Title created")

        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 20, 0, 20)
        closeBtn.Position = UDim2.new(1, -25, 0, 5)
        closeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        closeBtn.Text = "✕"
        closeBtn.TextColor3 = Color3.new(1, 1, 1)
        closeBtn.TextScaled = true
        closeBtn.Font = Enum.Font.Gotham
        closeBtn.BorderSizePixel = 0
        closeBtn.ZIndex = 3
        closeBtn.Parent = frame
        closeBtn.Activated:Connect(function()
            frame.Visible = false
            notify("🖼️ GUI Closed")
        end)
        warn("Close button created")

        local testBtn = Instance.new("TextButton")
        testBtn.Size = UDim2.new(1, -10, 0, 30)
        testBtn.Position = UDim2.new(0, 5, 0, 30)
        testBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        testBtn.TextColor3 = Color3.new(1, 1, 1)
        testBtn.Text = "Test GUI"
        testBtn.TextScaled = true
        testBtn.Font = Enum.Font.Gotham
        testBtn.BorderSizePixel = 0
        testBtn.ZIndex = 3
        testBtn.Parent = frame
        testBtn.Activated:Connect(function()
            notify("✅ GUI Works!")
        end)
        warn("Test button created")
    end)
    if not success then
        warn("createGUI error: " .. tostring(errorMsg))
        notify("⚠️ GUI creation failed, retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(15)
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
                    startPos.X.Scale, startPos.X.Offset + totalTranslation.X,
                    startPos.Y.Scale, startPos.Y.Offset + totalTranslation.Y
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

-- Setup UI
local function setupUI()
    local success, errorMsg = pcall(function()
        task.wait(15) -- Delay super panjang
        createGUI()
        makeDraggable(logo)
        
        logo.Activated:Connect(function()
            frame.Visible = not frame.Visible
            notify("🖼️ GUI " .. (frame.Visible and "ON" or "OFF"))
        end)
        
        initChar()
    end)
    if not success then
        warn("setupUI error: " .. tostring(errorMsg))
        notify("⚠️ UI setup failed, retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(15)
        setupUI()
    end
end

-- Start UI
setupUI()
notify("🚀 GUI Loaded")
```

