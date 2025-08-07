local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Variabel untuk fitur Teleport
local savedPositions = {}
local selectedPlayer = nil
local freecamPosition = nil
local freecamEnabled = false -- Dibutuhkan untuk saveFreecamPosition dan teleportToFreecam

-- GUI Creation untuk Position Manager
local ScreenGui = Instance.new("ScreenGui")
local PositionFrame = Instance.new("Frame")
local PositionTitle = Instance.new("TextLabel")
local ClosePositionButton = Instance.new("TextButton")
local PositionInput = Instance.new("TextBox")
local SavePositionButton = Instance.new("TextButton")
local PositionScrollFrame = Instance.new("ScrollingFrame")
local PositionLayout = Instance.new("UIListLayout")

-- GUI Properties
ScreenGui.Name = "TeleportHackGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Position Save Frame
PositionFrame.Name = "PositionFrame"
PositionFrame.Parent = ScreenGui
PositionFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
PositionFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
PositionFrame.BorderSizePixel = 1
PositionFrame.Position = UDim2.new(0.3, 0, 0.2, 0)
PositionFrame.Size = UDim2.new(0, 350, 0, 400)
PositionFrame.Visible = false
PositionFrame.Active = true
PositionFrame.Draggable = true

-- Position Frame Title
PositionTitle.Name = "Title"
PositionTitle.Parent = PositionFrame
PositionTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
PositionTitle.BorderSizePixel = 0
PositionTitle.Position = UDim2.new(0, 0, 0, 0)
PositionTitle.Size = UDim2.new(1, 0, 0, 35)
PositionTitle.Font = Enum.Font.Gotham
PositionTitle.Text = "SAVED POSITIONS"
PositionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
PositionTitle.TextSize = 12

-- Close Position Frame Button
ClosePositionButton.Name = "CloseButton"
ClosePositionButton.Parent = PositionFrame
ClosePositionButton.BackgroundTransparency = 1
ClosePositionButton.Position = UDim2.new(1, -30, 0, 5)
ClosePositionButton.Size = UDim2.new(0, 25, 0, 25)
ClosePositionButton.Font = Enum.Font.GothamBold
ClosePositionButton.Text = "X"
ClosePositionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ClosePositionButton.TextSize = 12

-- Position Input
PositionInput.Name = "PositionInput"
PositionInput.Parent = PositionFrame
PositionInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
PositionInput.BorderSizePixel = 0
PositionInput.Position = UDim2.new(0, 10, 0, 45)
PositionInput.Size = UDim2.new(1, -90, 0, 30)
PositionInput.Font = Enum.Font.Gotham
PositionInput.PlaceholderText = "Enter position name..."
PositionInput.Text = ""
PositionInput.TextColor3 = Color3.fromRGB(255, 255, 255)
PositionInput.TextSize = 11

-- Save Position Button
SavePositionButton.Name = "SavePositionButton"
SavePositionButton.Parent = PositionFrame
SavePositionButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
SavePositionButton.BorderSizePixel = 0
SavePositionButton.Position = UDim2.new(1, -70, 0, 45)
SavePositionButton.Size = UDim2.new(0, 60, 0, 30)
SavePositionButton.Font = Enum.Font.Gotham
SavePositionButton.Text = "SAVE"
SavePositionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SavePositionButton.TextSize = 10

-- Position ScrollFrame
PositionScrollFrame.Name = "PositionScrollFrame"
PositionScrollFrame.Parent = PositionFrame
PositionScrollFrame.BackgroundTransparency = 1
PositionScrollFrame.Position = UDim2.new(0, 10, 0, 85)
PositionScrollFrame.Size = UDim2.new(1, -20, 1, -95)
PositionScrollFrame.ScrollBarThickness = 4
PositionScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
PositionScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
PositionScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
PositionScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
PositionScrollFrame.BorderSizePixel = 0

-- Position Layout
PositionLayout.Parent = PositionScrollFrame
PositionLayout.Padding = UDim.new(0, 2)
PositionLayout.SortOrder = Enum.SortOrder.LayoutOrder
PositionLayout.FillDirection = Enum.FillDirection.Vertical

-- Fungsi untuk menyimpan posisi ke file
local function savePositionsToFile()
    if not pcall(function() return writefile end) then
        warn("writefile not supported in this environment")
        return
    end
    
    local success, errorMsg = pcall(function()
        makefolder("DCIM/Supertool")
        local positionData = {}
        for name, cframe in pairs(savedPositions) do
            positionData[name] = {
                Position = {cframe.Position.X, cframe.Position.Y, cframe.Position.Z},
                Orientation = {cframe:ToEulerAnglesXYZ()}
            }
        end
        writefile("DCIM/Supertool/saved_positions.json", HttpService:JSONEncode(positionData))
        print("Positions saved to DCIM/Supertool/saved_positions.json")
    end)
    if not success then
        warn("Failed to save positions: " .. tostring(errorMsg))
    end
end

-- Fungsi untuk memuat posisi dari file
local function loadPositionsFromFile()
    if not pcall(function() return readfile end) then
        warn("readfile not supported in this environment")
        return
    end
    
    local success, result = pcall(function()
        local fileContent = readfile("DCIM/Supertool/saved_positions.json")
        return HttpService:JSONDecode(fileContent)
    end)
    
    if success then
        savedPositions = {}
        for name, data in pairs(result) do
            local pos = Vector3.new(data.Position[1], data.Position[2], data.Position[3])
            local rot = CFrame.Angles(data.Orientation[1], data.Orientation[2], data.Orientation[3])
            savedPositions[name] = CFrame.new(pos) * rot
        end
        print("Positions loaded from DCIM/Supertool/saved_positions.json")
        updatePositionList()
    else
        warn("No saved positions found or error loading: " .. tostring(result))
    end
end

-- Save Freecam Position
local function saveFreecamPosition()
    if freecamEnabled and freecamPosition then
        local positionName = PositionInput.Text
        if positionName == "" then
            positionName = "Freecam Position " .. (#savedPositions + 1)
        end
        savedPositions[positionName] = CFrame.new(freecamPosition)
        print("Freecam Position Saved: " .. positionName)
        PositionInput.Text = ""
        savePositionsToFile()
        updatePositionList()
    else
        print("Freecam must be enabled to save position")
    end
end

-- Save Selected Player Position
local function savePlayerPosition()
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local positionName = PositionInput.Text
        if positionName == "" then
            positionName = selectedPlayer.Name .. " Position " .. (#savedPositions + 1)
        end
        savedPositions[positionName] = selectedPlayer.Character.HumanoidRootPart.CFrame
        print("Player Position Saved: " .. positionName)
        PositionInput.Text = ""
        savePositionsToFile()
        updatePositionList()
    else
        print("Select a player first to save their position")
    end
end

-- Teleport to Freecam
local function teleportToFreecam()
    if freecamPosition and rootPart then
        if freecamEnabled then
            freecamEnabled = false -- Nonaktifkan freecam
            if game:GetService("Workspace").CurrentCamera then
                game:GetService("Workspace").CurrentCamera.CameraSubject = humanoid
            end
        end
        rootPart.CFrame = CFrame.new(freecamPosition)
        print("Teleported to freecam position")
    else
        print("No freecam position available")
    end
end

-- Teleport to Selected Player
local function teleportToPlayer()
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and rootPart then
        rootPart.CFrame = selectedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
        print("Teleported to: " .. selectedPlayer.Name)
    else
        print("Select a player first")
    end
end

-- Position Manager
local function showPositionManager()
    PositionFrame.Visible = true
    updatePositionList()
end

local function updatePositionList()
    for _, child in pairs(PositionScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local itemCount = 0
    
    for positionName, _ in pairs(savedPositions) do
        local positionItem = Instance.new("Frame")
        positionItem.Name = positionName .. "Item"
        positionItem.Parent = PositionScrollFrame
        positionItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        positionItem.BorderSizePixel = 0
        positionItem.Size = UDim2.new(1, -5, 0, 90)
        positionItem.LayoutOrder = itemCount
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Parent = positionItem
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.new(0, 5, 0, 5)
        nameLabel.Size = UDim2.new(1, -10, 0, 20)
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.Text = positionName
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize = 11
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local tpButton = Instance.new("TextButton")
        tpButton.Name = "TeleportButton"
        tpButton.Parent = positionItem
        tpButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        tpButton.BorderSizePixel = 0
        tpButton.Position = UDim2.new(0, 5, 0, 30)
        tpButton.Size = UDim2.new(0, 80, 0, 25)
        tpButton.Font = Enum.Font.Gotham
        tpButton.Text = "TELEPORT"
        tpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        tpButton.TextSize = 9
        
        local deleteButton = Instance.new("TextButton")
        deleteButton.Name = "DeleteButton"
        deleteButton.Parent = positionItem
        deleteButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
        deleteButton.BorderSizePixel = 0
        deleteButton.Position = UDim2.new(0, 90, 0, 30)
        deleteButton.Size = UDim2.new(0, 60, 0, 25)
        deleteButton.Font = Enum.Font.Gotham
        deleteButton.Text = "DELETE"
        deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        deleteButton.TextSize = 9
        
        local renameButton = Instance.new("TextButton")
        renameButton.Name = "RenameButton"
        renameButton.Parent = positionItem
        renameButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
        renameButton.BorderSizePixel = 0
        renameButton.Position = UDim2.new(0, 155, 0, 30)
        renameButton.Size = UDim2.new(0, 60, 0, 25)
        renameButton.Font = Enum.Font.Gotham
        renameButton.Text = "RENAME"
        renameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        renameButton.TextSize = 9
        
        local renameInput = Instance.new("TextBox")
        renameInput.Name = "RenameInput"
        renameInput.Parent = positionItem
        renameInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        renameInput.BorderSizePixel = 0
        renameInput.Position = UDim2.new(0, 5, 0, 60)
        renameInput.Size = UDim2.new(1, -10, 0, 25)
        renameInput.Font = Enum.Font.Gotham
        renameInput.PlaceholderText = "Enter new name..."
        renameInput.Text = ""
        renameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        renameInput.TextSize = 11
        renameInput.Visible = false
        
        tpButton.MouseButton1Click:Connect(function()
            if savedPositions[positionName] and rootPart then
                rootPart.CFrame = savedPositions[positionName]
                print("Teleported to: " .. positionName)
            end
        end)
        
        deleteButton.MouseButton1Click:Connect(function()
            savedPositions[positionName] = nil
            print("Deleted position: " .. positionName)
            savePositionsToFile()
            updatePositionList()
        end)
        
        renameButton.MouseButton1Click:Connect(function()
            renameInput.Visible = true
            renameInput:CaptureFocus()
        end)
        
        renameInput.FocusLost:Connect(function(enterPressed)
            if enterPressed and renameInput.Text ~= "" then
                local newName = renameInput.Text
                if savedPositions[newName] then
                    print("Position name already exists: " .. newName)
                else
                    savedPositions[newName] = savedPositions[positionName]
                    savedPositions[positionName] = nil
                    print("Renamed position from " .. positionName .. " to " .. newName)
                    savePositionsToFile()
                    updatePositionList()
                end
            end
            renameInput.Text = ""
            renameInput.Visible = false
        end)
        
        tpButton.MouseEnter:Connect(function()
            tpButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        end)
        
        tpButton.MouseLeave:Connect(function()
            tpButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end)
        
        deleteButton.MouseEnter:Connect(function()
            deleteButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        end)
        
        deleteButton.MouseLeave:Connect(function()
            deleteButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
        end)
        
        renameButton.MouseEnter:Connect(function()
            renameButton.BackgroundColor3 = Color3.fromRGB(50, 50, 100)
        end)
        
        renameButton.MouseLeave:Connect(function()
            renameButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
        end)
        
        itemCount = itemCount + 1
    end
    
    wait(0.1)
    local contentSize = PositionLayout.AbsoluteContentSize
    PositionScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 10)
end

-- Save Current Position
local function savePosition()
    local positionName = PositionInput.Text
    if positionName == "" then
        positionName = "Position " .. (#savedPositions + 1)
    end
    
    if rootPart then
        savedPositions[positionName] = rootPart.CFrame
        print("Position Saved: " .. positionName)
        PositionInput.Text = ""
        savePositionsToFile()
        updatePositionList()
    end
end

-- Event Connections
ClosePositionButton.MouseButton1Click:Connect(function()
    PositionFrame.Visible = false
end)

SavePositionButton.MouseButton1Click:Connect(savePosition)

-- Handle character reset untuk Teleport
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
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
loadPositionsFromFile()
showPositionManager()
print("Teleport Features Loaded")