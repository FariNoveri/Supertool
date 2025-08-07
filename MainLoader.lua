-- mainloader.lua
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local screenGui = nil

local function createGUI()
    print("[Supertool] Creating GUI")
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MinimalHackGUI"
    screenGui.Parent = player.PlayerGui
    screenGui.ResetOnSpawn = false
    print("[Supertool] ScreenGui created")

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 300, 0, 200)
    mainFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    mainFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    mainFrame.BorderSizePixel = 1
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Visible = true
    mainFrame.Parent = screenGui
    print("[Supertool] MainFrame created")

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 50)
    label.BackgroundTransparency = 1
    label.Text = "Supertool - Fari Noveri"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 20
    label.Parent = mainFrame
    print("[Supertool] Label created")

    local minimizeButton = Instance.new("TextButton")
    minimizeButton.Size = UDim2.new(0, 30, 0, 30)
    minimizeButton.Position = UDim2.new(1, -35, 0, 5)
    minimizeButton.BackgroundTransparency = 1
    minimizeButton.Text = "_"
    minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizeButton.TextSize = 16
    minimizeButton.Parent = mainFrame
    print("[Supertool] Minimize button created")

    minimizeButton.MouseButton1Click:Connect(function()
        print("[Supertool] Minimize clicked")
        mainFrame.Visible = false
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.Insert then
            print("[Supertool] Toggle GUI with Insert")
            mainFrame.Visible = not mainFrame.Visible
        end
    end)
end

local function cleanup()
    if screenGui then
        screenGui:Destroy()
        screenGui = nil
        print("[Supertool] Cleanup completed")
    end
end

game:BindToClose(cleanup)
print("[Supertool] Initializing GUI")
createGUI()