-- Console Output: Script Start
print("TEST_SERVICES: Script Started")

-- Try CoreGui access
local success, CoreGui = pcall(function()
    return game:GetService("CoreGui")
end)

-- Console Output: CoreGui Result
print("TEST_SERVICES: CoreGui " .. (success and "Success" or "Failed: " .. tostring(CoreGui)))

if not success then return end

-- Test TextLabel
local DebugLabel = Instance.new("TextLabel")
DebugLabel.Name = "DebugLabel"
DebugLabel.Parent = CoreGui
DebugLabel.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
DebugLabel.Size = UDim2.new(0, 200, 0, 30)
DebugLabel.Position = UDim2.new(0.5, -100, 0.3, -15)
DebugLabel.Font = Enum.Font.SourceSans
DebugLabel.Text = "DEBUG: Test Label"
DebugLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugLabel.TextSize = 12
DebugLabel.Visible = true

-- Console Output: TextLabel Created
print("TEST_SERVICES: TextLabel Created")

-- Test Frame
local DebugFrame = Instance.new("Frame")
DebugFrame.Name = "DebugFrame"
DebugFrame.Parent = CoreGui
DebugFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
DebugFrame.Size = UDim2.new(0, 100, 0, 100)
DebugFrame.Position = UDim2.new(0.5, -50, 0.4, -50)
DebugFrame.Visible = true

-- Console Output: Frame Created
print("TEST_SERVICES: Frame Created")