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

-- Clean up existing GUIs
for _, gui in pairs(CoreGui:GetChildren()) do
    if gui.Name == "MinimalHackGUI" or gui.Name == "TestHttpGetGUI" or gui.Name == "DebugStart" or gui.Name == "DebugCleanup" or gui.Name == "DebugModules" or gui.Name == "DebugScreenGui" or gui.Name == "DebugMainFrame" or gui.Name == "DebugComplete" then
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

-- Load modules
local modules = {}
local moduleNames = {"Info", "Movement", "Player", "Visual", "Teleport", "Utility", "Settings", "AntiAdmin", "AntiAdminInfo"}
for _, moduleName in ipairs(moduleNames) do
    local success, result = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/refs/heads/main/" .. moduleName .. ".lua", true))()
    end)
    if success and result then
        modules[moduleName] = result
    end
end

-- Debug Label: Modules Loaded
local DebugModules = Instance.new("TextLabel")
DebugModules.Name = "DebugModules"
DebugModules.Parent = CoreGui
DebugModules.BackgroundColor3 = modules.Info and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
DebugModules.Size = UDim2.new(0, 200, 0, 30)
DebugModules.Position = UDim2.new(0.5, -100, 0.4, -15)
DebugModules.Font = Enum.Font.Gotham
DebugModules.Text = modules.Info and "DEBUG: Info Loaded" or "DEBUG: Info Load Failed"
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
Title.Text = "HACK - By Fari Noveri [UNKNOWN BLOCK] dasda"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left

-- Create Minimize Button
local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Name = "MinimizeButton"
MinimizeButton.Parent = TopBar
MinimizeButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MinimizeButton.BorderSizePixel = 0
MinimizeButton.Position = UDim2.new(1, -30, 0, 5)
MinimizeButton.Size = UDim2.new(0, 25, 0, 25)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "-"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextSize = 14

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
if modules.Info then
    modules.Info.setGuiElements({
        InfoFrame = ContentFrame,
        InfoScrollFrame = ScrollFrame,
        InfoLayout = UIListLayout
    })
end

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

-- Fallback watermark
local function loadFallbackInfo()
    local watermarkLabel = Instance.new("TextLabel")
    watermarkLabel.Name = "WatermarkLabel"
    watermarkLabel.Parent = ScrollFrame
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
    local contentSize = UIListLayout.AbsoluteContentSize
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 20)
end

-- Placeholder for other categories
local function loadPlaceholder(category)
    local placeholderLabel = Instance.new("TextLabel")
    placeholderLabel.Name = category .. "Placeholder"
    placeholderLabel.Parent = ScrollFrame
    placeholderLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    placeholderLabel.BorderSizePixel = 0
    placeholderLabel.Size = UDim2.new(1, 0, 0, 50)
    placeholderLabel.Font = Enum.Font.Gotham
    placeholderLabel.Text = category .. " category not yet implemented."
    placeholderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    placeholderLabel.TextSize = 10
    placeholderLabel.TextWrapped = true
    placeholderLabel.TextXAlignment = Enum.TextXAlignment.Left
    placeholderLabel.TextYAlignment = Enum.TextYAlignment.Top
    
    wait(0.1)
    local contentSize = UIListLayout.AbsoluteContentSize
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 20)
end

-- Minimize button logic
MinimizeButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
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
        if modules.Info then
            modules.Info.updateGui()
        else
            loadFallbackInfo()
        end
    elseif categoryName == "Movement" then
        if modules.Movement then
            modules.Movement.updateGui()
        else
            loadPlaceholder("Movement")
        end
    elseif categoryName == "Player" then
        if modules.Player then
            modules.Player.updateGui()
        else
            loadPlaceholder("Player")
        end
    elseif categoryName == "Visual" then
        if modules.Visual then
            modules.Visual.updateGui()
        else
            loadPlaceholder("Visual")
        end
    elseif categoryName == "Teleport" then
        if modules.Teleport then
            modules.Teleport.updateGui()
        else
            loadPlaceholder("Teleport")
        end
    elseif categoryName == "Utility" then
        if modules.Utility then
            modules.Utility.updateGui()
        else
            loadPlaceholder("Utility")
        end
    elseif categoryName == "Settings" then
        if modules.Settings then
            modules.Settings.updateGui()
        else
            loadPlaceholder("Settings")
        end
    elseif categoryName == "Anti Admin" then
        if modules.AntiAdminInfo then
            modules.AntiAdminInfo.updateGui()
        else
            loadPlaceholder("Anti Admin")
        end
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
DebugComplete.Position = UDim2.new(0.5, -100, 0.55, -15)
DebugComplete.Font = Enum.Font.Gotham
DebugComplete.Text = "DEBUG: GUI Complete"
DebugComplete.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugComplete.TextSize = 12
DebugComplete.Visible = true