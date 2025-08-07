-- Debug Label: Script Start
local DebugStart = Instance.new("TextLabel")
DebugStart.Name = "DebugStart"
DebugStart.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
DebugStart.Size = UDim2.new(0, 200, 0, 30)
DebugStart.Position = UDim2.new(0.5, -100, 0.3, -15)
DebugStart.Font = Enum.Font.Gotham
DebugStart.Text = "DEBUG: Script Started"
DebugStart.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugStart.TextSize = 12
DebugStart.Visible = true

-- Try CoreGui access
local success, result = pcall(function()
    local CoreGui = game:GetService("CoreGui")
    DebugStart.Parent = CoreGui
    return CoreGui
end)

-- Debug Label: CoreGui Result
local DebugCoreGui = Instance.new("TextLabel")
DebugCoreGui.Name = "DebugCoreGui"
DebugCoreGui.BackgroundColor3 = success and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
DebugCoreGui.Size = UDim2.new(0, 200, 0, 30)
DebugCoreGui.Position = UDim2.new(0.5, -100, 0.35, -15)
DebugCoreGui.Font = Enum.Font.Gotham
DebugCoreGui.Text = success and "DEBUG: CoreGui Success" or "DEBUG: CoreGui Failed"
DebugCoreGui.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugCoreGui.TextSize = 12
DebugCoreGui.Visible = true

if success then
    DebugCoreGui.Parent = result
end