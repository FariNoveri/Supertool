local CoreGui = game:GetService("CoreGui")

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
DebugCleanup.Position = UDim2.new(0.5, -100, 0.35, -15)
DebugCleanup.Font = Enum.Font.Gotham
DebugCleanup.Text = "DEBUG: Cleanup Done"
DebugCleanup.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugCleanup.TextSize = 12
DebugCleanup.Visible = true

-- Embedded Info module
local modules = {
    Info = {
        setGuiElements = function(elements)
            modules.Info.InfoFrame = elements.InfoFrame
            modules.Info.InfoScrollFrame = elements.InfoScrollFrame
            modules.Info.InfoLayout = elements.InfoLayout
        end,
        updateGui = function()
            if not modules.Info.InfoScrollFrame then return end
            for _, child in pairs(modules.Info.InfoScrollFrame:GetChildren()) do
                if child:IsA("TextLabel") or child:IsA("Frame") then
                    child:Destroy()
                end
            end
            local watermarkLabel = Instance.new("TextLabel")
            watermarkLabel.Name = "WatermarkLabel"
            watermarkLabel.Parent = modules.Info.InfoScrollFrame
            watermarkLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            watermarkLabel.BorderSizePixel = 0
            watermarkLabel.Size = UDim2.new(1, 0, 0, 300)
            watermarkLabel.Font = Enum.Font.Gotham
            watermarkLabel.Text = [[
--[ NOTICE BEFORE USING ]--

Created by Fari Noveri for Unknown Block members.
Not for sale, not for showing off, not for tampering.

- Rules of Use:
- Do not sell this script. It's not for profit.
- Keep the creator's name as "by Fari Noveri".
- Do not re-upload to public platforms without permission.
- Do not combine with other scripts and claim as your own.
- Only get updates from the original source to avoid errors.

- If you find this script outside the group:
It may have been leaked. Please don't share it further.

- Purpose:
This script is made to help fellow members, not for profit.
Please use it responsibly and respect its purpose.

- For suggestions, questions, or feedback:
Contact:
- Instagram: @fariinoveri
- TikTok: @fari_noveri

Thank you for reading. Use it wisely.

- Fari Noveri
]]
            watermarkLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            watermarkLabel.TextSize = 10
            watermarkLabel.TextWrapped = true
            watermarkLabel.TextXAlignment = Enum.TextXAlignment.Left
            watermarkLabel.TextYAlignment = Enum.TextYAlignment.Top
            
            wait(0.1)
            local contentSize = modules.Info.InfoLayout.AbsoluteContentSize
            modules.Info.InfoScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 20)
        end
    }
}

-- Debug Label: Modules Loaded
local DebugModules = Instance.new("TextLabel")
DebugModules.Name = "DebugModules"
DebugModules.Parent = CoreGui
DebugModules.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
DebugModules.Size = UDim2.new(0, 200, 0, 30)
DebugModules.Position = UDim2.new(0.5, -100, 0.4, -15)
DebugModules.Font = Enum.Font.Gotham
DebugModules.Text = "DEBUG: Info Loaded (Embedded)"
DebugModules.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugModules.TextSize = 12
DebugModules.Visible = true

-- Create ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MinimalHackGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Enabled = true

-- Debug Label: ScreenGui Created
local DebugScreenGui = Instance.new("TextLabel")
DebugScreenGui.Name = "DebugScreenGui"
DebugScreenGui.Parent = CoreGui
DebugScreenGui.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
DebugScreenGui.Size = UDim2.new(0, 200, 0, 30)
DebugScreenGui.Position = UDim2.new(0.5, -100, 0.45, -15)
DebugScreenGui.Font = Enum.Font.Gotham
DebugScreenGui.Text = "DEBUG: ScreenGui Created"
DebugScreenGui.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugScreenGui.TextSize = 12
DebugScreenGui.Visible = true

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

-- Debug Label: MainFrame Created
local DebugMainFrame = Instance.new("TextLabel")
DebugMainFrame.Name = "DebugMainFrame"
DebugMainFrame.Parent = CoreGui
DebugMainFrame.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
DebugMainFrame.Size = UDim2.new(0, 200, 0, 30)
DebugMainFrame.Position = UDim2.new(0.5, -100, 0.5, -15)
DebugMainFrame.Font = Enum.Font.Gotham
DebugMainFrame.Text = "DEBUG: MainFrame Created"
DebugMainFrame.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugMainFrame.TextSize = 12
DebugMainFrame.Visible = true

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
Title.Text = "HACK - By Fari Noveri [UNKNOWN BLOCK] e321321"
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

-- Debug Label: Minimize Click
local DebugMinimize = Instance.new("TextLabel")
DebugMinimize.Name = "DebugMinimize"
DebugMinimize.Parent = CoreGui
DebugMinimize.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
DebugMinimize.Size = UDim2.new(0, 200, 0, 30)
DebugMinimize.Position = UDim2.new(0.5, -100, 0.55, -15)
DebugMinimize.Font = Enum.Font.Gotham
DebugMinimize.Text = "DEBUG: Minimize Not Clicked"
DebugMinimize.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugMinimize.TextSize = 12
DebugMinimize.Visible = false

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

-- Pass GUI elements to Info module
modules.Info.setGuiElements({
    InfoFrame = ContentFrame,
    InfoScrollFrame = ScrollFrame,
    InfoLayout = UIListLayout
})

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
        DebugMinimize.Visible = true
        DebugMinimize.Text = "DEBUG: " .. name .. " Clicked"
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
        DebugMinimize.Visible = true
        DebugMinimize.Text = "DEBUG: " .. category .. " Example Clicked"
    end)
    
    wait(0.1)
    local contentSize = UIListLayout.AbsoluteContentSize
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 20)
end

-- Minimize button logic
MinimizeButton.Activated:Connect(function()
    DebugMinimize.Visible = true
    DebugMinimize.Text = "DEBUG: Minimize Clicked"
    local newVisible = not MainFrame.Visible
    MainFrame.Visible = newVisible
    wait(0.2)
    if MainFrame.Parent then
        MinimizeButton.Text = newVisible and "-" or "+"
    end
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
        modules.Info.updateGui()
    else
        loadPlaceholder(categoryName)
    end
    
    wait(0.1)
    local contentSize = UIListLayout.AbsoluteContentSize
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 20)
end

-- Initialize categories
for _, category in ipairs({"Movement", "Player", "Visual", "Teleport", "Utility", "Settings", "Info", "Anti Admin"}) do
    createCategoryButton(category)
end

-- Initialize GUI
switchCategory("Info")

-- Update CategoryFrame size
wait(0.1)
local categoryContentSize = CategoryList.AbsoluteContentSize
CategoryFrame.Size = UDim2.new(0, 140, 0, categoryContentSize.Y + 10)

-- Debug Label: GUI Complete
local DebugComplete = Instance.new("TextLabel")
DebugComplete.Name = "DebugComplete"
DebugComplete.Parent = CoreGui
DebugComplete.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
DebugComplete.Size = UDim2.new(0, 200, 0, 30)
DebugComplete.Position = UDim2.new(0.5, -100, 0.6, -15)
DebugComplete.Font = Enum.Font.Gotham
DebugComplete.Text = "DEBUG: GUI Complete"
DebugComplete.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugComplete.TextSize = 12
DebugComplete.Visible = true