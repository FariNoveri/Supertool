-- Console Output: Script Start
print("MAINLOADER: Script Started")

local CoreGui = game:GetService("CoreGui")

-- Clean up existing GUIs
for _, gui in pairs(CoreGui:GetChildren()) do
    if gui.Name == "MinimalHackGUI" or gui.Name == "TestHttpGetGUI" or gui.Name == "ToggleGUI" or gui.Name:match("^Debug") then
        gui:Destroy()
    end
end

-- Console Output: Cleanup Done
print("MAINLOADER: Cleanup Done")

-- Info module variables
local InfoFrame, InfoScrollFrame, InfoLayout

-- Create ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MinimalHackGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Enabled = true

-- Console Output: ScreenGui Created
print("MAINLOADER: ScreenGui Created")

-- Create MainFrame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
MainFrame.BorderSizePixel = 1
MainFrame.Position = UDim2.new(0.05, 0, 0.1, 0)
MainFrame.Size = UDim2.new(0, 600, 0, 400)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = true

-- Console Output: MainFrame Created
print("MAINLOADER: MainFrame Created")

-- Create TopBar
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Parent = MainFrame
TopBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
TopBar.BorderSizePixel = 0
TopBar.Position = UDim2.new(0, 0, 0, 0)
TopBar.Size = UDim2.new(1, 0, 0, 35)

-- Create Logo
local Logo = Instance.new("TextLabel")
Logo.Name = "Logo"
Logo.Parent = TopBar
Logo.BackgroundTransparency = 1
Logo.Position = UDim2.new(0, 10, 0, 5)
Logo.Size = UDim2.new(0, 25, 0, 25)
Logo.Font = Enum.Font.GothamBold
Logo.Text = "H"
Logo.TextColor3 = Color3.fromRGB(255, 255, 255)
Logo.TextScaled = true

-- Create Title
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Parent = TopBar
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 45, 0, 0)
Title.Size = UDim2.new(1, -90, 1, 0)
Title.Font = Enum.Font.Gotham
Title.Text = "HACK - By Fari Noveri [UNKNOWN BLOCK]"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Create Toggle ScreenGui
local ToggleGui = Instance.new("ScreenGui")
ToggleGui.Name = "ToggleGUI"
ToggleGui.Parent = CoreGui
ToggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ToggleGui.Enabled = true

-- Create Minimize Button
local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Name = "MinimizeButton"
MinimizeButton.Parent = ToggleGui
MinimizeButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MinimizeButton.BorderSizePixel = 0
MinimizeButton.Position = UDim2.new(0.95, -30, 0.05, 0)
MinimizeButton.Size = UDim2.new(0, 25, 0, 25)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "-"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextSize = 14
MinimizeButton.Visible = true
MinimizeButton.ZIndex = 10

-- Console Output: Minimize Button Created
print("MAINLOADER: Minimize Button Created")

-- Create CategoryFrame
local CategoryFrame = Instance.new("Frame")
CategoryFrame.Name = "CategoryFrame"
CategoryFrame.Parent = MainFrame
CategoryFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
CategoryFrame.BorderSizePixel = 0
CategoryFrame.Position = UDim2.new(0, 0, 0, 35)
CategoryFrame.Size = UDim2.new(0, 140, 1, -35)

local CategoryList = Instance.new("UIListLayout")
CategoryList.Parent = CategoryFrame
CategoryList.Padding = UDim.new(0, 2)
CategoryList.SortOrder = Enum.SortOrder.LayoutOrder

-- Console Output: CategoryFrame Created
print("MAINLOADER: CategoryFrame Created")

-- Create ContentFrame
local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Parent = MainFrame
ContentFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
ContentFrame.BorderSizePixel = 0
ContentFrame.Position = UDim2.new(0, 140, 0, 35)
ContentFrame.Size = UDim2.new(1, -140, 1, -35)

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

-- Console Output: ContentFrame Created
print("MAINLOADER: ContentFrame Created")

-- Set Info module variables
local success, err = pcall(function()
    InfoFrame = ContentFrame
    InfoScrollFrame = ScrollFrame
    InfoLayout = UIListLayout
end)
if not success then
    print("MAINLOADER: Info Setup Error: " .. tostring(err))
end

-- Console Output: Info Setup
print("MAINLOADER: Info Setup Complete")

-- Create category button
local function createCategoryButton(name)
    local button = Instance.new("TextButton")
    button.Name = name .. "Category"
    button.Parent = CategoryFrame
    button.BackgroundColor3 = name == "Info" and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 35)
    button.Font = Enum.Font.Gotham
    button.Text = name:upper()
    button.TextColor3 = name == "Info" and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
    button.TextSize = 10
    
    button.MouseButton1Click:Connect(function()
        print("MAINLOADER: " .. name .. " Clicked")
        switchCategory(name)
    end)
    
    return button
end

-- Clear buttons
local function clearButtons()
    for _, child in pairs(ScrollFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then
            child:Destroy()
        end
    end
end

-- Placeholder for other categories
local function loadPlaceholder(category)
    local placeholderFrame = Instance.new("Frame")
    placeholderFrame.Name = category .. "Placeholder"
    placeholderFrame.Parent = ScrollFrame
    placeholderFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    placeholderFrame.BorderSizePixel = 0
    placeholderFrame.Size = UDim2.new(1, 0, 0, 100)
    
    local placeholderLabel = Instance.new("TextLabel")
    placeholderLabel.Name = "Label"
    placeholderLabel.Parent = placeholderFrame
    placeholderLabel.BackgroundTransparency = 1
    placeholderLabel.Size = UDim2.new(1, -10, 0, 30)
    placeholderLabel.Position = UDim2.new(0, 5, 0, 5)
    placeholderLabel.Font = Enum.Font.Gotham
    placeholderLabel.Text = category .. " category not yet implemented."
    placeholderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    placeholderLabel.TextSize = 10
    placeholderLabel.TextWrapped = true
    placeholderLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local exampleButton = Instance.new("TextButton")
    exampleButton.Name = "ExampleButton"
    exampleButton.Parent = placeholderFrame
    exampleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    exampleButton.BorderSizePixel = 0
    exampleButton.Position = UDim2.new(0, 5, 0, 40)
    exampleButton.Size = UDim2.new(1, -10, 0, 30)
    exampleButton.Font = Enum.Font.Gotham
    exampleButton.Text = "Example " .. category .. " Feature"
    exampleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    exampleButton.TextSize = 10
    
    exampleButton.MouseButton1Click:Connect(function()
        print("MAINLOADER: " .. category .. " Example Clicked")
    end)
    
    wait(0.1)
    local contentSize = UIListLayout.AbsoluteContentSize
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 20)
end

-- Info category function
local function loadInfo()
    if not InfoScrollFrame then
        print("MAINLOADER: InfoScrollFrame nil")
        return
    end
    local success, err = pcall(function()
        for _, child in pairs(InfoScrollFrame:GetChildren()) do
            if child:IsA("TextLabel") or child:IsA("Frame") then
                child:Destroy()
            end
        end
        local watermarkLabel = Instance.new("TextLabel")
        watermarkLabel.Name = "WatermarkLabel"
        watermarkLabel.Parent = InfoScrollFrame
        watermarkLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        watermarkLabel.BorderSizePixel = 0
        watermarkLabel.Size = UDim2.new(1, 0, 0, 300)
        watermarkLabel.Font = Enum.Font.SourceSans
        watermarkLabel.Text = "TEST INFO WATERMARK"
        watermarkLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        watermarkLabel.TextSize = 10
        watermarkLabel.TextWrapped = true
        watermarkLabel.TextXAlignment = Enum.TextXAlignment.Left
        watermarkLabel.TextYAlignment = Enum.TextYAlignment.Top
        
        wait(0.1)
        local contentSize = InfoLayout and InfoLayout.AbsoluteContentSize or Vector2.new(0, 0)
        InfoScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 20)
    end)
    if not success then
        print("MAINLOADER: Info Load Error: " .. tostring(err))
    else
        print("MAINLOADER: Info Watermark Created")
    end
end

-- Minimize button logic
MinimizeButton.Activated:Connect(function()
    print("MAINLOADER: Minimize Clicked")
    MainFrame.Visible = not MainFrame.Visible
    wait(0.5)
    MinimizeButton.Text = MainFrame.Visible and "-" or "+"
end)

-- Category switching
local currentCategory = "Info"
function switchCategory(categoryName)
    currentCategory = categoryName
    
    for _, child in pairs(CategoryFrame:GetChildren()) do
        if child:IsA("TextButton") then
            if child.Name == categoryName .. "Category" then
                child.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                child.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                child.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                child.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
    end
    
    clearButtons()
    
    if categoryName == "Info" then
        loadInfo()
    else
        loadPlaceholder(categoryName)
    end
end

-- Initialize categories
local success, err = pcall(function()
    for _, category in ipairs({"Movement", "Player", "Visual", "Teleport", "Utility", "Settings", "Info", "Anti Admin"}) do
        createCategoryButton(category)
    end
end)
if not success then
    print("MAINLOADER: Categories Error: " .. tostring(err))
end

-- Initialize GUI
local success, err = pcall(function()
    switchCategory("Info")
end)
if not success then
    print("MAINLOADER: Init Error: " .. tostring(err))
end

-- Update CategoryFrame size
wait(0.1)
local categoryContentSize = CategoryList.AbsoluteContentSize
CategoryFrame.Size = UDim2.new(0, 140, 0, categoryContentSize.Y + 10)

-- Console Output: GUI Complete
print("MAINLOADER: GUI Complete")