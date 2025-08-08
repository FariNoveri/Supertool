-- Console Output: Script Start
print("TEST_HTTPGET: Script Started")

-- Try CoreGui access
local success, CoreGui = pcall(function()
    return game:GetService("CoreGui")
end)

-- Console Output: CoreGui Result
print("TEST_HTTPGET: CoreGui " .. (success and "Success" or "Failed: " .. tostring(CoreGui)))

if not success then return end

-- Clean up existing GUIs
for _, gui in pairs(CoreGui:GetChildren()) do
    if gui.Name == "MinimalHackGUI" or gui.Name == "TestHttpGetGUI" or gui.Name == "ToggleGUI" or gui.Name:match("^Debug") then
        gui:Destroy()
    end
end

-- Console Output: Cleanup Done
print("TEST_HTTPGET: Cleanup Done")

-- Create ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TestHttpGetGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Enabled = true

-- Console Output: ScreenGui Created
print("TEST_HTTPGET: ScreenGui Created")

-- Create ContentFrame
local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Parent = ScreenGui
ContentFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
ContentFrame.BorderSizePixel = 0
ContentFrame.Position = UDim2.new(0.05, 0, 0.1, 0)
ContentFrame.Size = UDim2.new(0, 400, 0, 300)

-- Create ScrollFrame
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Name = "ScrollFrame"
ScrollFrame.Parent = ContentFrame
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.Position = UDim2.new(0, 10, 0, 10)
ScrollFrame.Size = UDim2.new(1, -20, 1, -20)
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
ScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

-- Create UIListLayout
local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = ScrollFrame
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Console Output: GUI Elements Created
print("TEST_HTTPGET: GUI Elements Created")

-- Create Watermark
local success, err = pcall(function()
    local watermarkLabel = Instance.new("TextLabel")
    watermarkLabel.Name = "WatermarkLabel"
    watermarkLabel.Parent = ScrollFrame
    watermarkLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    watermarkLabel.BorderSizePixel = 0
    watermarkLabel.Size = UDim2.new(1, 0, 0, 300)
    watermarkLabel.Font = Enum.Font.SourceSans
    watermarkLabel.Text = "TEST WATERMARK"
    watermarkLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    watermarkLabel.TextSize = 10
    watermarkLabel.TextWrapped = true
    watermarkLabel.TextXAlignment = Enum.TextXAlignment.Left
    watermarkLabel.TextYAlignment = Enum.TextYAlignment.Top
    
    wait(0.1)
    local contentSize = UIListLayout.AbsoluteContentSize
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 20)
end)

-- Console Output: Watermark Result
print("TEST_HTTPGET: Watermark " .. (success and "Created" or "Failed: " .. tostring(err)))

-- Console Output: GUI Result
print("TEST_HTTPGET: GUI " .. (success and "Complete" or "Failed: " .. tostring(err)))