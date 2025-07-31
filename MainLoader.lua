local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid, hr, char
local gui, frame, logo

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

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function notify(message, color)
    local success, errorMsg = pcall(function()
        if not gui then
            print("Notify failed: GUI not initialized")
            return
        end
        local notif = Instance.new("TextLabel")
        notif.Size = UDim2.new(0, 200, 0, 30) -- Increased size for better visibility
        notif.Position = UDim2.new(0.5, -100, 0, 10)
        notif.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notif.BackgroundTransparency = 0.5
        notif.TextColor3 = color or Color3.fromRGB(0, 255, 0)
        notif.TextScaled = true
        notif.Font = Enum.Font.Gotham
        notif.Text = message
        notif.BorderSizePixel = 0
        notif.ZIndex = 10 -- Higher ZIndex to ensure visibility
        notif.Parent = gui
        task.spawn(function()
            task.wait(3)
            notif:Destroy()
        end)
    end)
    if not success then
        print("Notify error: " .. tostring(errorMsg))
    end
end

local function initChar()
    local success, errorMsg = pcall(function()
        char = player.Character or player.CharacterAdded:Wait()
        humanoid = char:WaitForChild("Humanoid", 10)
        hr = char:WaitForChild("HumanoidRootPart", 10)
        if not humanoid or not hr then
            error("Failed to find Humanoid or HumanoidRootPart")
        end
        print("Character initialized")
    end)
    if not success then
        print("initChar error: " .. tostring(errorMsg))
        notify("⚠️ Character init failed, retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(5) -- Reduced retry delay
        initChar()
    end
end

local function createGUI()
    local success, errorMsg = pcall(function()
        if gui then
            gui:Destroy()
            gui = nil
        end

        gui = Instance.new("ScreenGui")
        gui.Name = "SimpleUILibrary_Krnl"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Enabled = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

        -- Parent directly to PlayerGui to avoid CoreGui restrictions
        local playerGui = player:WaitForChild("PlayerGui", 10)
        if not playerGui then
            error("PlayerGui not found")
        end
        gui.Parent = playerGui
        print("GUI parented to PlayerGui")

        logo = Instance.new("ImageButton")
        logo.Size = UDim2.new(0, 40, 0, 40) -- Slightly larger for visibility
        logo.Position = UDim2.new(0, 10, 0, 10)
        logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        logo.BorderSizePixel = 0
        logo.Image = "rbxassetid://3570695787"
        logo.ZIndex = 10
        logo.Parent = gui
        print("Logo created")

        frame = Instance.new("Frame")
        frame.Size = isMobile and UDim2.new(0.9, 0, 0.6, 0) or UDim2.new(0, 300, 0, 200)
        frame.Position = UDim2.new(0.5, -150, 0.5, -100)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        frame.BackgroundTransparency = 0.1
        frame.BorderSizePixel = 0
        frame.Visible = false
        frame.ZIndex = 10
        frame.Parent = gui
        print("Frame created")

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 30)
        title.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        title.TextColor3 = Color3.new(1, 1, 1)
        title.Text = "Krnl UI"
        title.TextScaled = true
        title.Font = Enum.Font.Gotham
        title.ZIndex = 10
        title.Parent = frame
        print("Title created")

        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 20, 0, 20)
        closeBtn.Position = UDim2.new(1, -25, 0, 5)
        closeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        closeBtn.Text = "✕"
        closeBtn.TextColor3 = Color3.new(1, 1, 1)
        closeBtn.TextScaled = true
        closeBtn.Font = Enum.Font.Gotham
        closeBtn.BorderSizePixel = 0
        closeBtn.ZIndex = 10
        closeBtn.Parent = frame
        closeBtn.Activated:Connect(function()
            frame.Visible = false
            notify("🖼️ UI Closed")
        end)
        print("Close button created")

        local testBtn = Instance.new("TextButton")
        testBtn.Size = UDim2.new(1, -10, 0, 30)
        testBtn.Position = UDim2.new(0, 5, 0, 40)
        testBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        testBtn.TextColor3 = Color3.new(1, 1, 1)
        testBtn.Text = "Test UI"
        testBtn.TextScaled = true
        testBtn.Font = Enum.Font.Gotham
        testBtn.BorderSizePixel = 0
        testBtn.ZIndex = 10
        testBtn.Parent = frame
        testBtn.Activated:Connect(function()
            notify("✅ UI Works!")
        end)
        print("Test button created")
    end)
    if not success then
        print("createGUI error: " .. tostring(errorMsg))
        notify("⚠️ UI creation failed, retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(5) -- Reduced retry delay
        createGUI()
    end
end

local function makeDraggable(element)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    if isMobile then
        element.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = element.Position
            end
        end)
        element.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch and dragging then
                local delta = input.Position - dragStart
                element.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
        element.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
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

local function setupUI()
    local success, errorMsg = pcall(function()
        createGUI()
        makeDraggable(logo)
        makeDraggable(frame) -- Make the main frame draggable too
        
        logo.Activated:Connect(function()
            frame.Visible = not frame.Visible
            notify("🖼️ UI " .. (frame.Visible and "ON" or "OFF"))
        end)
        
        initChar()
    end)
    if not success then
        print("setupUI error: " .. tostring(errorMsg))
        notify("⚠️ UI setup failed, retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(5) -- Reduced retry delay
        setupUI()
    end
end

-- Start the UI setup
setupUI()