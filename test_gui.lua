-- Simple GUI Test Script
-- This script will help you test if the GUI appears properly

local Players = game:GetService("Players")
local player = Players.LocalPlayer

print("🧪 Starting GUI Test...")

-- Test 1: Check if PlayerGui exists
if not player.PlayerGui then
    print("❌ PlayerGui not found!")
    return
else
    print("✅ PlayerGui found")
end

-- Test 2: Create a simple test GUI
local testGui = Instance.new("ScreenGui")
testGui.Name = "TestGUI"
testGui.ResetOnSpawn = false
testGui.Parent = player.PlayerGui

local testButton = Instance.new("TextButton")
testButton.Size = UDim2.new(0, 100, 0, 50)
testButton.Position = UDim2.new(0.5, -50, 0.5, -25)
testButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
testButton.TextColor3 = Color3.fromRGB(255, 255, 255)
testButton.Text = "TEST"
testButton.TextSize = 18
testButton.Font = Enum.Font.GothamBold
testButton.ZIndex = 100
testButton.Parent = testGui

testButton.MouseButton1Click:Connect(function()
    print("✅ Test button clicked - GUI is working!")
    testGui:Destroy()
end)

print("✅ Test GUI created - Look for red TEST button in center")
print("📱 If you see the red TEST button, the GUI system is working")
print("🎯 Click the TEST button to remove it and run the main script")

-- Wait 10 seconds then auto-remove test GUI
task.wait(10)
if testGui and testGui.Parent then
    testGui:Destroy()
    print("⏰ Test GUI auto-removed after 10 seconds")
end 