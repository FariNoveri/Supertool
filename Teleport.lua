-- Teleport.lua
-- Teleport features for MinimalHackGUI by Fari Noveri

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Teleport feature variables
local savedPositions = {}
local positionListVisible = false
local folderPath = "DCIM/Supertool"

-- Helper function to sanitize filenames
local function sanitizeFilename(name)
    return name:gsub("[^%w%s]", ""):gsub("%s+", " "):sub(1, 50)
end

-- Load saved positions from all JSON files in DCIM/Supertool
local function loadSavedPositions()
    savedPositions = {}
    if listfiles then
        local success, files = pcall(function()
            return listfiles(folderPath)
        end)
        if success and files then
            for _, file in pairs(files) do
                if file:match("%.json$") then
                    local success, data = pcall(function()
                        return HttpService:JSONDecode(readfile(file))
                    end)
                    if success and data then
                        local positionName = file:match("([^/\\]+)%.json$")
                        savedPositions[positionName] = CFrame.new(
                            data.Position.X, data.Position.Y, data.Position.Z,
                            data.Orientation.Xx, data.Orientation.Xy, data.Orientation.Xz,
                            data.Orientation.Yx, data.Orientation.Yy, data.Orientation.Yz,
                            data.Orientation.Zx, data.Orientation.Zy, data.Orientation.Zz
                        )
                        print("Loaded position: " .. positionName .. " from " .. file)
                    else
                        warn("Failed to load position from " .. file)
                    end
                end
            end
            print("Loaded " .. table.getn(savedPositions) .. " positions from " .. folderPath)
        else
            warn("Failed to list files in " .. folderPath)
        end
    else
        warn("listfiles not supported by executor")
    end
end

-- Save a position to a JSON file
local function savePositionToFile(positionName, cframe)
    local success, error = pcall(function()
        local data = {
            Position = { X = cframe.Position.X, Y = cframe.Position.Y, Z = cframe.Position.Z },
            Orientation = {
                Xx = cframe.XVector.X, Xy = cframe.XVector.Y, Xz = cframe.XVector.Z,
                Yx = cframe.YVector.X, Yy = cframe.YVector.Y, Yz = cframe.YVector.Z,
                Zx = cframe.ZVector.X, Zy = cframe.ZVector.Y, Zz = cframe.ZVector.Z
            }
        }
        local filePath = folderPath .. "/" .. sanitizeFilename(positionName) .. ".json"
        writefile(filePath, HttpService:JSONEncode(data))
        print("Saved position: " .. positionName .. " to " .. filePath)
    end)
    if not success then
        warn("Failed to save position " .. positionName .. ": " .. tostring(error))
    end
end

-- Delete a position file
local function deletePositionFile(positionName)
    local filePath = folderPath .. "/" .. sanitizeFilename(positionName) .. ".json"
    if isfile and isfile(filePath) then
        local success, error = pcall(function()
            delfile(filePath)
            print("Deleted position file: " .. filePath)
        end)
        if not success then
            warn("Failed to delete position file " .. filePath .. ": " .. tostring(error))
        end
    end
end

-- Rename a position file
local function renamePositionFile(oldName, newName)
    local oldFilePath = folderPath .. "/" .. sanitizeFilename(oldName) .. ".json"
    local newFilePath = folderPath .. "/" .. sanitizeFilename(newName) .. ".json"
    if isfile and isfile(oldFilePath) then
        local success, data = pcall(function()
            return readfile(oldFilePath)
        end)
        if success then
            local writeSuccess, error = pcall(function()
                writefile(newFilePath, data)
                delfile(oldFilePath)
                print("Renamed position file from " .. oldFilePath .. " to " .. newFilePath)
            end)
            if not writeSuccess then
                warn("Failed to rename position file " .. oldFilePath .. ": " .. tostring(error))
            end
        else
            warn("Failed to read position file " .. oldFilePath)
        end
    end
end

-- Position Manager UI Creation
local function createPositionManagerUI()
    local PositionFrame = Instance.new("Frame")
    local PositionTitle = Instance.new("TextLabel")
    local ClosePositionButton = Instance.new("TextButton")
    local PositionInput = Instance.new("TextBox")
    local SavePositionButton = Instance.new("TextButton")
    local PositionScrollFrame = Instance.new("ScrollingFrame")
    local PositionLayout = Instance.new("UIListLayout")

    PositionFrame.Name = "PositionFrame"
    PositionFrame.Parent = CoreGui
    PositionFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    PositionFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    PositionFrame.BorderSizePixel = 1
    PositionFrame.Position = UDim2.new(0.5, -150, 0.2, 0)
    PositionFrame.Size = UDim2.new(0, 300, 0, 350)
    PositionFrame.Visible = false
    PositionFrame.Active = true
    PositionFrame.Draggable = true

    PositionTitle.Name = "Title"
    PositionTitle.Parent = PositionFrame
    PositionTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    PositionTitle.BorderSizePixel = 0
    PositionTitle.Position = UDim2.new(0, 0, 0, 0)
    PositionTitle.Size = UDim2.new(1, 0, 0, 35)
    PositionTitle.Font = Enum.Font.Gotham
    PositionTitle.Text = "POSITION MANAGER"
    PositionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    PositionTitle.TextSize = 12

    ClosePositionButton.Name = "CloseButton"
    ClosePositionButton.Parent = PositionFrame
    ClosePositionButton.BackgroundTransparency = 1
    ClosePositionButton.Position = UDim2.new(1, -30, 0, 5)
    ClosePositionButton.Size = UDim2.new(0, 25, 0, 25)
    ClosePositionButton.Font = Enum.Font.GothamBold
    ClosePositionButton.Text = "X"
    ClosePositionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClosePositionButton.TextSize = 12

    PositionInput.Name = "PositionInput"
    PositionInput.Parent = PositionFrame
    PositionInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    PositionInput.BorderSizePixel = 0
    PositionInput.Position = UDim2.new(0, 10, 0, 45)
    PositionInput.Size = UDim2.new(0.65, -15, 0, 25)
    PositionInput.Font = Enum.Font.Gotham
    PositionInput.Text = ""
    PositionInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    PositionInput.TextSize = 10
    PositionInput.PlaceholderText = "Enter position name..."

    SavePositionButton.Name = "SavePositionButton"
    SavePositionButton.Parent = PositionFrame
    SavePositionButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
    SavePositionButton.BorderSizePixel = 0
    SavePositionButton.Position = UDim2.new(0.65, 5, 0, 45)
    SavePositionButton.Size = UDim2.new(0.35, -10, 0, 25)
    SavePositionButton.Font = Enum.Font.Gotham
    SavePositionButton.Text = "SAVE"
    SavePositionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SavePositionButton.TextSize = 10

    PositionScrollFrame.Name = "PositionScrollFrame"
    PositionScrollFrame.Parent = PositionFrame
    PositionScrollFrame.BackgroundTransparency = 1
    PositionScrollFrame.Position = UDim2.new(0, 10, 0, 80)
    PositionScrollFrame.Size = UDim2.new(1, -20, 1, -90)
    PositionScrollFrame.ScrollBarThickness = 4
    PositionScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    PositionScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    PositionScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    PositionScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    PositionScrollFrame.BorderSizePixel = 0

    PositionLayout.Parent = PositionScrollFrame
    PositionLayout.Padding = UDim.new(0, 2)
    PositionLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PositionLayout.FillDirection = Enum.FillDirection.Vertical

    return PositionFrame, PositionInput, PositionScrollFrame, PositionLayout
end

-- Update Position List
local function updatePositionList(utils)
    local PositionScrollFrame = CoreGui:FindFirstChild("PositionFrame") and CoreGui.PositionFrame:FindFirstChild("PositionScrollFrame")
    local PositionLayout = PositionScrollFrame and PositionScrollFrame:FindFirstChild("UIListLayout")
    if not PositionScrollFrame or not PositionLayout then return end

    for _, child in pairs(PositionScrollFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    if next(savedPositions) == nil then
        local noPositionsLabel = Instance.new("TextLabel")
        noPositionsLabel.Name = "NoPositionsLabel"
        noPositionsLabel.Parent = PositionScrollFrame
        noPositionsLabel.BackgroundTransparency = 1
        noPositionsLabel.Size = UDim2.new(1, 0, 0, 30)
        noPositionsLabel.Font = Enum.Font.Gotham
        noPositionsLabel.Text = "No positions saved"
        noPositionsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        noPositionsLabel.TextSize = 11
        noPositionsLabel.TextXAlignment = Enum.TextXAlignment.Center
        if utils.notify then
            utils.notify("Position List Updated: No positions saved")
        else
            print("Position List Updated: No positions saved")
        end
    else
        local positionCount = 0
        for positionName, cframe in pairs(savedPositions) do
            positionCount = positionCount + 1
            local positionItem = Instance.new("Frame")
            positionItem.Name = positionName .. "Item"
            positionItem.Parent = PositionScrollFrame
            positionItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            positionItem.BorderSizePixel = 0
            positionItem.Size = UDim2.new(1, -5, 0, 90)
            positionItem.LayoutOrder = positionCount

            local nameInput = Instance.new("TextBox")
            nameInput.Name = "NameInput"
            nameInput.Parent = positionItem
            nameInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            nameInput.BorderSizePixel = 0
            nameInput.Position = UDim2.new(0, 5, 0, 5)
            nameInput.Size = UDim2.new(1, -10, 0, 25)
            nameInput.Font = Enum.Font.GothamBold
            nameInput.Text = positionName
            nameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameInput.TextSize = 12
            nameInput.TextXAlignment = Enum.TextXAlignment.Left

            local teleportButton = Instance.new("TextButton")
            teleportButton.Name = "TeleportButton"
            teleportButton.Parent = positionItem
            teleportButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
            teleportButton.BorderSizePixel = 0
            teleportButton.Position = UDim2.new(0, 5, 0, 35)
            teleportButton.Size = UDim2.new(0, 70, 0, 25)
            teleportButton.Font = Enum.Font.Gotham
            teleportButton.Text = "TELEPORT"
            teleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            teleportButton.TextSize = 9

            local deleteButton = Instance.new("TextButton")
            deleteButton.Name = "DeleteButton"
            deleteButton.Parent = positionItem
            deleteButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
            deleteButton.BorderSizePixel = 0
            deleteButton.Position = UDim2.new(0, 80, 0, 35)
            deleteButton.Size = UDim2.new(0, 70, 0, 25)
            deleteButton.Font = Enum.Font.Gotham
            deleteButton.Text = "DELETE"
            deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            deleteButton.TextSize = 9

            local renameButton = Instance.new("TextButton")
            renameButton.Name = "RenameButton"
            renameButton.Parent = positionItem
            renameButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
            renameButton.BorderSizePixel = 0
            renameButton.Position = UDim2.new(0, 155, 0, 35)
            renameButton.Size = UDim2.new(1, -160, 0, 25)
            renameButton.Font = Enum.Font.Gotham
            renameButton.Text = "RENAME"
            renameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            renameButton.TextSize = 9

            nameInput.FocusLost:Connect(function(enterPressed)
                if enterPressed then
                    local newName = sanitizeFilename(nameInput.Text)
                    if newName ~= "" and newName ~= positionName then
                        savedPositions[newName] = savedPositions[positionName]
                        savedPositions[positionName] = nil
                        renamePositionFile(positionName, newName)
                        if utils.notify then
                            utils.notify("Renamed position from " .. positionName .. " to " .. newName)
                        else
                            print("Renamed position from " .. positionName .. " to " .. newName)
                        end
                        updatePositionList(utils)
                    else
                        nameInput.Text = positionName
                    end
                end
            end)

            teleportButton.MouseButton1Click:Connect(function()
                if rootPart then
                    rootPart.CFrame = cframe
                    if utils.notify then
                        utils.notify("Teleported to position: " .. positionName)
                    else
                        print("Teleported to position: " .. positionName)
                    end
                end
            end)

            deleteButton.MouseButton1Click:Connect(function()
                savedPositions[positionName] = nil
                deletePositionFile(positionName)
                if utils.notify then
                    utils.notify("Deleted position: " .. positionName)
                else
                    print("Deleted position: " .. positionName)
                end
                updatePositionList(utils)
            end)

            renameButton.MouseButton1Click:Connect(function()
                nameInput:CaptureFocus()
            end)

            teleportButton.MouseEnter:Connect(function()
                teleportButton.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
            end)

            teleportButton.MouseLeave:Connect(function()
                teleportButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
            end)

            deleteButton.MouseEnter:Connect(function()
                deleteButton.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
            end)

            deleteButton.MouseLeave:Connect(function()
                deleteButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
            end)

            renameButton.MouseEnter:Connect(function()
                renameButton.BackgroundColor3 = Color3.fromRGB(50, 50, 100)
            end)

            renameButton.MouseLeave:Connect(function()
                renameButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
            end)
        end
        if utils.notify then
            utils.notify("Position List Updated: " .. positionCount .. " positions listed")
        else
            print("Position List Updated: " .. positionCount .. " positions listed")
        end
    end

    task.wait(0.1)
    local contentSize = PositionLayout.AbsoluteContentSize
    PositionScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(contentSize.Y + 10, 30))
end

-- Show Position Manager
local function showPositionManager(utils)
    positionListVisible = true
    local PositionFrame = CoreGui:FindFirstChild("PositionFrame")
    if PositionFrame then
        PositionFrame.Visible = true
    end
    updatePositionList(utils)
end

-- Initialize Teleport UI
local function initializeTeleportUI()
    local PositionFrame, PositionInput, PositionScrollFrame, PositionLayout = createPositionManagerUI()
    
    ClosePositionButton = PositionFrame.CloseButton
    SavePositionButton = PositionFrame.SavePositionButton
    
    ClosePositionButton.MouseButton1Click:Connect(function()
        positionListVisible = false
        PositionFrame.Visible = false
    end)

    SavePositionButton.MouseButton1Click:Connect(function()
        if rootPart then
            local positionName = PositionInput.Text
            if positionName == "" then
                positionName = "Position " .. (#savedPositions + 1)
            end
            positionName = sanitizeFilename(positionName)
            savedPositions[positionName] = rootPart.CFrame
            savePositionToFile(positionName, rootPart.CFrame)
            PositionInput.Text = ""
            updatePositionList({ notify = print }) -- Fallback notify
            if utils and utils.notify then
                utils.notify("Position Saved: " .. positionName)
            else
                print("Position Saved: " .. positionName)
            end
        end
    end)

    SavePositionButton.MouseEnter:Connect(function()
        SavePositionButton.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
    end)

    SavePositionButton.MouseLeave:Connect(function()
        SavePositionButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
    end)
    
    loadSavedPositions()
    updatePositionList({ notify = print }) -- Fallback notify
end

-- Load buttons for mainloader.lua
local function loadButtons(scrollFrame, utils, playerModule, visualModule)
    initializeTeleportUI()

    utils.createButton("Position Manager", function()
        showPositionManager(utils)
    end).Parent = scrollFrame

    utils.createButton("TP to Selected Player", function()
        if playerModule and playerModule.getSelectedPlayer then
            local selectedPlayer = playerModule.getSelectedPlayer()
            if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and rootPart then
                rootPart.CFrame = selectedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                if utils.notify then
                    utils.notify("Teleported to: " .. selectedPlayer.Name)
                else
                    print("Teleported to: " .. selectedPlayer.Name)
                end
            else
                if utils.notify then
                    utils.notify("Select a player first")
                else
                    print("Select a player first")
                end
            end
        else
            if utils.notify then
                utils.notify("Player module not available")
            else
                print("Player module not available")
            end
        end
    end).Parent = scrollFrame

    utils.createButton("TP to Freecam", function()
        if visualModule and visualModule.getFreecamPosition then
            local freecamPosition = visualModule.getFreecamPosition()
            if freecamPosition and rootPart then
                rootPart.CFrame = CFrame.new(freecamPosition)
                if utils.notify then
                    utils.notify("Teleported to freecam position")
                else
                    print("Teleported to freecam position")
                end
            else
                if utils.notify then
                    utils.notify("Use freecam first to set a position")
                else
                    print("Use freecam first to set a position")
                end
            end
        else
            if utils.notify then
                utils.notify("Visual module not available")
            else
                print("Visual module not available")
            end
        end
    end).Parent = scrollFrame

    utils.createButton("Save Freecam Position", function()
        if visualModule and visualModule.getFreecamPosition then
            local freecamPosition = visualModule.getFreecamPosition()
            if freecamPosition then
                local positionName = CoreGui:FindFirstChild("PositionFrame") and CoreGui.PositionFrame:FindFirstChild("PositionInput") and CoreGui.PositionFrame.PositionInput.Text
                if positionName == "" then
                    positionName = "Freecam Position " .. (#savedPositions + 1)
                end
                positionName = sanitizeFilename(positionName)
                savedPositions[positionName] = CFrame.new(freecamPosition)
                savePositionToFile(positionName, CFrame.new(freecamPosition))
                if CoreGui:FindFirstChild("PositionFrame") and CoreGui.PositionFrame:FindFirstChild("PositionInput") then
                    CoreGui.PositionFrame.PositionInput.Text = ""
                end
                updatePositionList(utils)
                if utils.notify then
                    utils.notify("Freecam Position Saved: " .. positionName)
                else
                    print("Freecam Position Saved: " .. positionName)
                end
            else
                if utils.notify then
                    utils.notify("Freecam must be enabled to save position")
                else
                    print("Freecam must be enabled to save position")
                end
            end
        else
            if utils.notify then
                utils.notify("Visual module not available")
            else
                print("Visual module not available")
            end
        end
    end).Parent = scrollFrame

    utils.createButton("Save Player Position", function()
        if playerModule and playerModule.getSelectedPlayer then
            local selectedPlayer = playerModule.getSelectedPlayer()
            if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local positionName = CoreGui:FindFirstChild("PositionFrame") and CoreGui.PositionFrame:FindFirstChild("PositionInput") and CoreGui.PositionFrame.PositionInput.Text
                if positionName == "" then
                    positionName = selectedPlayer.Name .. " Position " .. (#savedPositions + 1)
                end
                positionName = sanitizeFilename(positionName)
                savedPositions[positionName] = selectedPlayer.Character.HumanoidRootPart.CFrame
                savePositionToFile(positionName, selectedPlayer.Character.HumanoidRootPart.CFrame)
                if CoreGui:FindFirstChild("PositionFrame") and CoreGui.PositionFrame:FindFirstChild("PositionInput") then
                    CoreGui.PositionFrame.PositionInput.Text = ""
                end
                updatePositionList(utils)
                if utils.notify then
                    utils.notify("Player Position Saved: " .. positionName)
                else
                    print("Player Position Saved: " .. positionName)
                end
            else
                if utils.notify then
                    utils.notify("Select a player first to save their position")
                else
                    print("Select a player first to save their position")
                end
            end
        else
            if utils.notify then
                utils.notify("Player module not available")
            else
                print("Player module not available")
            end
        end
    end).Parent = scrollFrame
end

-- Cleanup function
local function cleanup()
    local PositionFrame = CoreGui:FindFirstChild("PositionFrame")
    if PositionFrame then
        PositionFrame:Destroy()
    end
end

-- Handle character reset
local characterConnection
characterConnection = player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    rootPart = character:WaitForChild("HumanoidRootPart")
end)

-- Cleanup on script destruction
local function onScriptDestroy()
    cleanup()
    if characterConnection then
        characterConnection:Disconnect()
        characterConnection = nil
    end
end

-- Connect cleanup to GUI destruction
local screenGui = CoreGui:FindFirstChild("MinimalHackGUI")
if screenGui then
    screenGui.AncestryChanged:Connect(function(_, parent)
        if not parent then
            onScriptDestroy()
        end
    end)
end

-- Return module
return {
    loadButtons = loadButtons,
    cleanup = cleanup,
    reset = cleanup
}