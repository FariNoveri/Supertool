local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

-- Debug Label: Start
local DebugStart = Instance.new("TextLabel")
DebugStart.Name = "DebugStart"
DebugStart.Parent = CoreGui
DebugStart.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
DebugStart.Size = UDim2.new(0, 200, 0, 30)
DebugStart.Position = UDim2.new(0.5, -100, 0.3, -15)
DebugStart.Font = Enum.Font.Gotham
DebugStart.Text = "DEBUG: Script Started"
DebugStart.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugStart.TextSize = 12
DebugStart.Visible = true

-- Try HttpGet
local success, result = pcall(function()
    return game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/refs/heads/main/Info.lua", true)
end)

-- Debug Label: HttpGet Result
local DebugHttpGet = Instance.new("TextLabel")
DebugHttpGet.Name = "DebugHttpGet"
DebugHttpGet.Parent = CoreGui
DebugHttpGet.BackgroundColor3 = success and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
DebugHttpGet.Size = UDim2.new(0, 200, 0, 30)
DebugHttpGet.Position = UDim2.new(0.5, -100, 0.35, -15)
DebugHttpGet.Font = Enum.Font.Gotham
DebugHttpGet.Text = success and "DEBUG: HttpGet Success" or "DEBUG: HttpGet Failed"
DebugHttpGet.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugHttpGet.TextSize = 12
DebugHttpGet.Visible = true

-- Try loadstring if HttpGet succeeded
local module
if success then
    local loadSuccess, loadResult = pcall(function()
        return loadstring(result)()
    end)
    
    -- Debug Label: loadstring Result
    local DebugLoadstring = Instance.new("TextLabel")
    DebugLoadstring.Name = "DebugLoadstring"
    DebugLoadstring.Parent = CoreGui
    DebugLoadstring.BackgroundColor3 = loadSuccess and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    DebugLoadstring.Size = UDim2.new(0, 200, 0, 30)
    DebugLoadstring.Position = UDim2.new(0.5, -100, 0.4, -15)
    DebugLoadstring.Font = Enum.Font.Gotham
    DebugLoadstring.Text = loadSuccess and "DEBUG: loadstring Success" or "DEBUG: loadstring Failed"
    DebugLoadstring.TextColor3 = Color3.fromRGB(255, 255, 255)
    DebugLoadstring.TextSize = 12
    DebugLoadstring.Visible = true
    
    if loadSuccess then
        module = loadResult
    end
end

-- Create ScreenGui for testing module
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TestHttpGetGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Enabled = true

-- Test module if loaded
if module and module.updateGui then
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
end