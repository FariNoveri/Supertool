-- Console Output: Script Start
print("TEST_HTTPGET: Script Started")

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
local success, CoreGui = pcall(function()
    return game:GetService("CoreGui")
end)

-- Console Output: CoreGui Result
print("TEST_HTTPGET: CoreGui " .. (success and "Success" or "Failed: " .. tostring(CoreGui)))

-- Debug Label: CoreGui Result
local DebugCoreGui = Instance.new("TextLabel")
DebugCoreGui.Name = "DebugCoreGui"
DebugCoreGui.BackgroundColor3 = success and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
DebugCoreGui.Size = UDim2.new(0, 200, 0, 30)
DebugCoreGui.Position = UDim2.new(0.5, -100, 0.35, -15)
DebugCoreGui.Font = Enum.Font.Gotham
DebugCoreGui.Text = success and "DEBUG: CoreGui Success" or "DEBUG: CoreGui Failed: " .. tostring(CoreGui)
DebugCoreGui.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugCoreGui.TextSize = 12
DebugCoreGui.Visible = true

if success then
    DebugStart.Parent = CoreGui
    DebugCoreGui.Parent = CoreGui
else
    return
end

-- Clean up existing GUIs
for _, gui in pairs(CoreGui:GetChildren()) do
    if gui.Name == "MinimalHackGUI" or gui.Name == "TestHttpGetGUI" or gui.Name == "ToggleGUI" or gui.Name:match("^Debug") then
        gui:Destroy()
    end
end

-- Debug Label: Cleanup Done
local DebugCleanup = Instance.new("TextLabel")
DebugCleanup.Name = "DebugCleanup"
DebugCleanup.Parent = CoreGui
DebugCleanup.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
DebugCleanup.Size = UDim2.new(0, 200, 0, 30)
DebugCleanup.Position = UDim2.new(0.5, -100, 0.4, -15)
DebugCleanup.Font = Enum.Font.Gotham
DebugCleanup.Text = "DEBUG: Cleanup Done"
DebugCleanup.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugCleanup.TextSize = 12
DebugCleanup.Visible = true

-- Console Output: Cleanup Done
print("TEST_HTTPGET: Cleanup Done")

-- Embedded Info module
local module = {
    setGuiElements = function(elements)
        print("TEST_HTTPGET: Setting GUI Elements")
        if not elements then
            print("TEST_HTTPGET: Elements nil")
            return
        end
        module.InfoFrame = elements.InfoFrame
        module.InfoScrollFrame = elements.InfoScrollFrame
        module.InfoLayout = elements.InfoLayout
    end,
    updateGui = function()
        print("TEST_HTTPGET: Updating GUI")
        if not module.InfoScrollFrame then
            print("TEST_HTTPGET: InfoScrollFrame nil")
            return
        end
        for _, child in pairs(module.InfoScrollFrame:GetChildren()) do
            if child:IsA("TextLabel") or child:IsA("Frame") then
                child:Destroy()
            end
        end
        local watermarkLabel = Instance.new("TextLabel")
        watermarkLabel.Name = "WatermarkLabel"
        watermarkLabel.Parent = module.InfoScrollFrame
        watermarkLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        watermarkLabel.BorderSizePixel = 0
        watermarkLabel.Size = UDim2.new(1, 0, 0, 300)
        watermarkLabel.Font = Enum.Font.Gotham
        watermarkLabel.Text = "TEST WATERMARK"
        watermarkLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        watermarkLabel.TextSize = 10
        watermarkLabel.TextWrapped = true
        watermarkLabel.TextXAlignment = Enum.TextXAlignment.Left
        watermarkLabel.TextYAlignment = Enum.TextYAlignment.Top
        
        wait(0.1)
        local contentSize = module.InfoLayout and module.InfoLayout.AbsoluteContentSize or Vector2.new(0, 0)
        module.InfoScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 20)
        print("TEST_HTTPGET: Watermark Created")
    end
}

-- Debug Label: Module Loaded
local DebugModule = Instance.new("TextLabel")
DebugModule.Name = "DebugModule"
DebugModule.Parent = CoreGui
DebugModule.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
DebugModule.Size = UDim2.new(0, 200, 0, 30)
DebugModule.Position = UDim2.new(0.5, -100, 0.45, -15)
DebugModule.Font = Enum.Font.Gotham
DebugModule.Text = "DEBUG: Module Loaded"
DebugModule.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugModule.TextSize = 12
DebugModule.Visible = true

-- Console Output: Module Loaded
print("TEST_HTTPGET: Module Loaded")

-- Create ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TestHttpGetGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Enabled = true

-- Debug Label: ScreenGui Created
local DebugScreenGui = Instance.new("TextLabel")
DebugScreenGui.Name = "DebugScreenGui"
DebugScreenGui.Parent = CoreGui
DebugScreenGui.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
DebugScreenGui.Size = UDim2.new(0, 200, 0, 30)
DebugScreenGui.Position = UDim2.new(0.5, -100, 0.5, -15)
DebugScreenGui.Font = Enum.Font.Gotham
DebugScreenGui.Text = "DEBUG: ScreenGui Created"
DebugScreenGui.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugScreenGui.TextSize = 12
DebugScreenGui.Visible = true

-- Console Output: ScreenGui Created
print("TEST_HTTPGET: ScreenGui Created")

-- Test module
local success, err = pcall(function()
    local ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "ContentFrame"
    ContentFrame.Parent = ScreenGui
    ContentFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    ContentFrame.BorderSizePixel = 0
    ContentFrame.Position = UDim2.new(0.05, 0, 0.1, 0)
    ContentFrame.Size = UDim2.new(0, 400, 0, 300)
    
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
    
    local UIListLayout = Instance.new("UIListLayout")
    UIListLayout.Parent = ScrollFrame
    UIListLayout.Padding = UDim.new(0, 5)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    module.setGuiElements({
        InfoFrame = ContentFrame,
        InfoScrollFrame = ScrollFrame,
        InfoLayout = UIListLayout
    })
    module.updateGui()
end)

-- Debug Label: GUI Complete
local DebugComplete = Instance.new("TextLabel")
DebugComplete.Name = "DebugComplete"
DebugComplete.Parent = CoreGui
DebugComplete.BackgroundColor3 = success and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
DebugComplete.Size = UDim2.new(0, 200, 0, 30)
DebugComplete.Position = UDim2.new(0.5, -100, 0.55, -15)
DebugComplete.Font = Enum.Font.Gotham
DebugComplete.Text = success and "DEBUG: GUI Complete" or "DEBUG: GUI Failed: " .. tostring(err)
DebugComplete.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugComplete.TextSize = 12
DebugComplete.Visible = true

-- Console Output: GUI Result
print("TEST_HTTPGET: GUI " .. (success and "Complete" or "Failed: " .. tostring(err)))