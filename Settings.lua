local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

-- Tabel pengaturan untuk semua fitur
local settings = {
    FlySpeed = { value = 50, default = 50, min = 10, max = 200 },
    JumpHeight = { value = 50, default = 50, min = 10, max = 150 },
    WalkSpeed = { value = 100, default = 100, min = 16, max = 300 },
    FlashlightBrightness = { value = 5, default = 5, min = 1, max = 10 },
    FlashlightRange = { value = 100, default = 100, min = 50, max = 200 },
    FullbrightBrightness = { value = 2, default = 2, min = 0, max = 5 }
}

-- GUI Creation untuk Settings
local ScreenGui = Instance.new("ScreenGui")
local SettingsFrame = Instance.new("Frame")
local SettingsTitle = Instance.new("TextLabel")
local CloseSettingsButton = Instance.new("TextButton")
local SettingsScrollFrame = Instance.new("ScrollingFrame")
local SettingsLayout = Instance.new("UIListLayout")

-- GUI Properties
ScreenGui.Name = "SettingsHackGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Settings Frame
SettingsFrame.Name = "SettingsFrame"
SettingsFrame.Parent = ScreenGui
SettingsFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
SettingsFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
SettingsFrame.BorderSizePixel = 1
SettingsFrame.Position = UDim2.new(0.5, -175, 0.2, 0)
SettingsFrame.Size = UDim2.new(0, 350, 0, 400)
SettingsFrame.Visible = false
SettingsFrame.Active = true
SettingsFrame.Draggable = true

-- Settings Frame Title
SettingsTitle.Name = "Title"
SettingsTitle.Parent = SettingsFrame
SettingsTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
SettingsTitle.BorderSizePixel = 0
SettingsTitle.Position = UDim2.new(0, 0, 0, 0)
SettingsTitle.Size = UDim2.new(1, 0, 0, 35)
SettingsTitle.Font = Enum.Font.Gotham
SettingsTitle.Text = "SETTINGS"
SettingsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
SettingsTitle.TextSize = 12

-- Close Settings Frame Button
CloseSettingsButton.Name = "CloseButton"
CloseSettingsButton.Parent = SettingsFrame
CloseSettingsButton.BackgroundTransparency = 1
CloseSettingsButton.Position = UDim2.new(1, -30, 0, 5)
CloseSettingsButton.Size = UDim2.new(0, 25, 0, 25)
CloseSettingsButton.Font = Enum.Font.GothamBold
CloseSettingsButton.Text = "X"
CloseSettingsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseSettingsButton.TextSize = 12

-- Settings ScrollFrame
SettingsScrollFrame.Name = "SettingsScrollFrame"
SettingsScrollFrame.Parent = SettingsFrame
SettingsScrollFrame.BackgroundTransparency = 1
SettingsScrollFrame.Position = UDim2.new(0, 10, 0, 45)
SettingsScrollFrame.Size = UDim2.new(1, -20, 1, -55)
SettingsScrollFrame.ScrollBarThickness = 4
SettingsScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
SettingsScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
SettingsScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
SettingsScrollFrame.BorderSizePixel = 0

-- Settings Layout
SettingsLayout.Parent = SettingsScrollFrame
SettingsLayout.Padding = UDim.new(0, 5)
SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
SettingsLayout.FillDirection = Enum.FillDirection.Vertical

-- Fungsi untuk menyimpan pengaturan ke file
local function saveSettingsToFile()
    if not pcall(function() return writefile end) then
        warn("writefile not supported in this environment")
        return
    end
    
    local success, errorMsg = pcall(function()
        makefolder("DCIM/Supertool")
        local settingsData = {}
        for key, data in pairs(settings) do
            settingsData[key] = data.value
        end
        writefile("DCIM/Supertool/settings.json", HttpService:JSONEncode(settingsData))
        print("Settings saved to DCIM/Supertool/settings.json")
    end)
    if not success then
        warn("Failed to save settings: " .. tostring(errorMsg))
    end
end

-- Fungsi untuk memuat pengaturan dari file
local function loadSettingsFromFile()
    if not pcall(function() return readfile end) then
        warn("readfile not supported in this environment")
        return
    end
    
    local success, result = pcall(function()
        local fileContent = readfile("DCIM/Supertool/settings.json")
        return HttpService:JSONDecode(fileContent)
    end)
    
    if success then
        for key, value in pairs(result) do
            if settings[key] then
                settings[key].value = math.clamp(value, settings[key].min, settings[key].max)
            end
        end
        print("Settings loaded from DCIM/Supertool/settings.json")
        updateSettingsGUI()
    else
        warn("No saved settings found or error loading: " .. tostring(result))
    end
end

-- Fungsi untuk memperbarui GUI Settings
local function updateSettingsGUI()
    for _, child in pairs(SettingsScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local itemCount = 0
    for settingName, settingData in pairs(settings) do
        local settingItem = Instance.new("Frame")
        settingItem.Name = settingName .. "Item"
        settingItem.Parent = SettingsScrollFrame
        settingItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        settingItem.BorderSizePixel = 0
        settingItem.Size = UDim2.new(1, -5, 0, 60)
        settingItem.LayoutOrder = itemCount
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Parent = settingItem
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.new(0, 5, 0, 5)
        nameLabel.Size = UDim2.new(1, -10, 0, 20)
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.Text = settingName
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize = 11
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local valueInput = Instance.new("TextBox")
        valueInput.Name = "ValueInput"
        valueInput.Parent = settingItem
        valueInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        valueInput.BorderSizePixel = 0
        valueInput.Position = UDim2.new(0, 5, 0, 30)
        valueInput.Size = UDim2.new(0, 80, 0, 25)
        valueInput.Font = Enum.Font.Gotham
        valueInput.Text = tostring(settingData.value)
        valueInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        valueInput.TextSize = 11
        
        local rangeLabel = Instance.new("TextLabel")
        rangeLabel.Name = "RangeLabel"
        rangeLabel.Parent = settingItem
        rangeLabel.BackgroundTransparency = 1
        rangeLabel.Position = UDim2.new(0, 90, 0, 30)
        rangeLabel.Size = UDim2.new(1, -95, 0, 25)
        rangeLabel.Font = Enum.Font.Gotham
        rangeLabel.Text = string.format("(Min: %s, Max: %s)", settingData.min, settingData.max)
        rangeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        rangeLabel.TextSize = 10
        rangeLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        valueInput.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local newValue = tonumber(valueInput.Text)
                if newValue then
                    newValue = math.clamp(newValue, settingData.min, settingData.max)
                    settingData.value = newValue
                    valueInput.Text = tostring(newValue)
                    saveSettingsToFile()
                    print("Updated " .. settingName .. " to " .. newValue)
                else
                    valueInput.Text = tostring(settingData.value)
                    print("Invalid input for " .. settingName)
                end
            end
        end)
        
        itemCount = itemCount + 1
    end
    
    wait(0.1)
    local contentSize = SettingsLayout.AbsoluteContentSize
    SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 10)
end

-- Fungsi untuk menampilkan Settings
local function showSettings()
    SettingsFrame.Visible = true
    updateSettingsGUI()
end

-- Event Connections
CloseSettingsButton.MouseButton1Click:Connect(function()
    SettingsFrame.Visible = false
end)

-- Cleanup saat script dihancurkan
local function cleanup()
    -- Hapus GUI
    if ScreenGui then
        ScreenGui:Destroy()
    end
end

-- Tangani penutupan game atau script
game:BindToClose(cleanup)

-- Inisialisasi
loadSettingsFromFile()
showSettings()
print("Settings Features Loaded")