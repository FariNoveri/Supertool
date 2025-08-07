local Players = game:GetService("Players")
local player = Players.LocalPlayer
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TestGUI"
screenGui.Parent = player.PlayerGui
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 200)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
mainFrame.Parent = screenGui
print("[TestGUI] MainFrame created")

local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 0, 50)
label.BackgroundTransparency = 1
label.Text = "Supertool Test GUI"
label.TextColor3 = Color3.fromRGB(255, 255, 255)
label.TextSize = 20
label.Parent = mainFrame
print("[TestGUI] Label created")