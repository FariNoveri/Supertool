-- info.lua
-- Info-related features for MinimalHackGUI by Fari Noveri, including watermark notice

-- Dependencies: These must be passed from mainloader.lua
local ScreenGui

-- Initialize module
local Info = {}

-- UI Elements (to be initialized in initUI function)
local WatermarkLabel

-- Initialize UI elements
local function initUI()
    -- Watermark Notice
    WatermarkLabel = Instance.new("TextLabel")
    WatermarkLabel.Name = "WatermarkLabel"
    WatermarkLabel.Parent = ScreenGui
    WatermarkLabel.BackgroundTransparency = 1
    WatermarkLabel.Position = UDim2.new(0, 10, 0, 10)
    WatermarkLabel.Size = UDim2.new(0, 200, 0, 20)
    WatermarkLabel.Font = Enum.Font.GothamBold
    -- WatermarkLabel.Text = "MinimalHackGUI by Fari Noveri"
    WatermarkLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    WatermarkLabel.TextSize = 14
    WatermarkLabel.TextXAlignment = Enum.TextXAlignment.Left
end

-- Function to create buttons for Info features (none needed, as Info is display-only)
function Info.loadInfoButtons(createButton)
    -- No buttons required for Info category
end

-- Function to reset Info states
function Info.resetStates()
    -- No persistent states in Info, but included for consistency
    if WatermarkLabel then
        WatermarkLabel.Visible = true
    end
end

-- Function to set dependencies and initialize UI
function Info.init(deps)
    ScreenGui = deps.ScreenGui
    
    -- Initialize UI elements
    initUI()
end

return Info