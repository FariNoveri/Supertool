local CoreGui = game:GetService("CoreGui")

-- Clean up existing MinimalHackGUI
for _, gui in pairs(CoreGui:GetChildren()) do
    if gui.Name == "MinimalHackGUI" then
        gui:Destroy()
    end
end

-- Create ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MinimalHackGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Enabled = true

-- Create TestLabel
local TestLabel = Instance.new("TextLabel")
TestLabel.Name = "TestLabel"
TestLabel.Parent = ScreenGui
TestLabel.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
TestLabel.Size = UDim2.new(0, 200, 0, 50)
TestLabel.Position = UDim2.new(0.5, -100, 0.5, -25)
TestLabel.Font = Enum.Font.Gotham
TestLabel.Text = "TEST GUI - Fari Noveri"
TestLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TestLabel.TextSize = 14
TestLabel.Visible = true