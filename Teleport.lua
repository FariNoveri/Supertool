-- teleport.lua
-- Teleport-related features for MinimalHackGUI by Fari Noveri, including enhanced position manager

-- Dependencies: These must be passed from mainloader.lua
local Players, Workspace, ScreenGui, player, rootPart, ScrollFrame, settings

-- Initialize module
local Teleport = {}

-- Variables
Teleport.savedPositions = {}
Teleport.positionFrameVisible = false

-- UI Elements (to be initialized in init function)
local PositionFrame, PositionScrollFrame, PositionLayout, PositionInput, SavePositionButton

-- Mock file system for DCIM/Supertool (simulated, as Roblox Lua doesn't have file I/O)
local fileSystem = {
    ["DCIM/Supertool"] = {}
}

-- Helper function to simulate saving to file system
local function saveToFileSystem(positionName, cframe)
    fileSystem["DCIM/Supertool"][positionName] = {
        x = cframe.X,
        y = cframe.Y,
        z = cframe.Z,
        orientation = {cframe:ToEulerAnglesXYZ()}
    }
    print("Saved to file system: DCIM/Supertool/" .. positionName)
end

-- Helper function to delete from file system
local function deleteFromFileSystem(positionName)
    if fileSystem["DCIM/Supertool"][positionName] then
        fileSystem["DCIM/Supertool"][positionName] = nil
        print("Deleted from file system: DCIM/Supertool/" .. positionName)
    end
end

-- Helper function to rename in file system
local function renameInFileSystem(oldName, newName)
    if fileSystem["DCIM/Supertool"][oldName] then
        fileSystem["DCIM/Supertool"][newName] = fileSystem["DCIM/Supertool"][oldName]
        fileSystem["DCIM/Supertool"][oldName] = nil
        print("Renamed in file system: DCIM/Supertool/" .. oldName .. " to " .. newName)
    end
end

-- Save Position
local function savePosition()
    local positionName = PositionInput.Text
    if positionName == "" then
        positionName = "Position " .. (#Teleport.savedPositions + 1)
    end
    
    if rootPart then
        Teleport.savedPositions[positionName] = rootPart.CFrame
        saveToFileSystem(positionName, rootPart.CFrame)
        print("Position Saved: " .. positionName)
        PositionInput.Text = ""
        Teleport.updatePositionList()
    else
        print("Cannot save position: No valid HumanoidRootPart")
    end
end

-- Load Position (Teleport to saved position)
local function loadPosition(positionName)
    if Teleport.savedPositions[positionName] and rootPart then
        rootPart.CFrame = Teleport.savedPositions[positionName]
        print("Teleported to: " .. positionName)
    else
        print("Cannot teleport: Invalid position or no HumanoidRootPart")
    end
end

-- Delete Position
local function deletePosition(positionName)
    if Teleport.savedPositions[positionName] then
        Teleport.savedPositions[positionName] = nil
        deleteFromFileSystem(positionName)
        print("Deleted position: " .. positionName)
        Teleport.updatePositionList()
    end
end

-- Rename Position
local function renamePosition(oldName, newName)
    if Teleport.savedPositions[oldName] and newName ~= "" then
        Teleport.savedPositions[newName] = Teleport.savedPositions[oldName]
        Teleport.savedPositions[oldName] = nil
        renameInFileSystem(oldName, newName)
        print("Renamed position: " .. oldName .. " to " .. newName)
        Teleport.updatePositionList()
    else
        print("Cannot rename: Invalid old name or empty new name")
    end
end

-- Save Freecam Position to Position Manager
local function saveFreecamPosition(freecamPosition)
    if freecamPosition then
        local positionName = PositionInput.Text
        if positionName == "" then
            positionName = "Freecam Position " .. (#Teleport.savedPositions + 1)
        end
        Teleport.savedPositions[positionName] = CFrame.new(freecamPosition)
        saveToFileSystem(positionName, CFrame.new(freecamPosition))
        print("Freecam Position Saved: " .. positionName)
        PositionInput.Text = ""
        Teleport.updatePositionList()
    else
        print("Cannot save: Freecam must be enabled to save position")
    end
end

-- Save Selected Player Position to Position Manager
local function savePlayerPosition(selectedPlayer)
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local positionName = PositionInput.Text
        if positionName == "" then
            positionName = selectedPlayer.Name .. " Position " .. (#Teleport.savedPositions + 1)
        end
        Teleport.savedPositions[positionName] = selectedPlayer.Character.HumanoidRootPart.CFrame
        saveToFileSystem(positionName, selectedPlayer.Character.HumanoidRootPart.CFrame)
        print("Player Position Saved: " .. positionName)
        PositionInput.Text = ""
        Teleport.updatePositionList()
    else
        print("Select a player first to save their position")
    end
end

-- Teleport to Freecam Position
local function teleportToFreecam(freecamEnabled, freecamPosition, toggleFreecam)
    if freecamEnabled and freecamPosition and rootPart then
        toggleFreecam(false)
        rootPart.CFrame = CFrame.new(freecamPosition)
        print("Teleported to freecam position")
    elseif freecamPosition and rootPart then
        rootPart.CFrame = CFrame.new(freecamPosition)
        print("Teleported to last freecam position")
    else
        print("Use freecam first to set a position")
    end
end

-- Teleport to Selected Player
local function teleportToSelectedPlayer(selectedPlayer)
    if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and rootPart then
        rootPart.CFrame = selectedPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
        print("Teleported to: " .. selectedPlayer.Name)
    else
        print("Select a player first")
    end
end

-- Show Position Manager
local function showPositionManager()
    Teleport.positionFrameVisible = true
    PositionFrame.Visible = true
    Teleport.updatePositionList()
end

-- Update Position List UI
function Teleport.updatePositionList()
    for _, child in pairs(PositionScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local itemCount = 0
    
    for positionName, _ in pairs(Teleport.savedPositions) do
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
        
        local renameInput = Instance.new("TextBox")
        renameInput.Name = "RenameInput"
        renameInput.Parent = positionItem
        renameInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        renameInput.BorderSizePixel = 0
        renameInput.Position = UDim2.new(0, 5, 0, 30)
        renameInput.Size = UDim2.new(1, -10, 0, 25)
        renameInput.Font = Enum.Font.Gotham
        renameInput.Text = ""
        renameInput.PlaceholderText = "Enter new name..."
        renameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        renameInput.TextSize = 11
        
        local buttonFrame = Instance.new("Frame")
        buttonFrame.Name = "ButtonFrame"
        buttonFrame.Parent = positionItem
        buttonFrame.BackgroundTransparency = 1
        buttonFrame.Position = UDim2.new(0, 5, 0, 60)
        buttonFrame.Size = UDim2.new(1, -10, 0, 25)
        
        local tpButton = Instance.new("TextButton")
        tpButton.Name = "TeleportButton"
        tpButton.Parent = buttonFrame
        tpButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        tpButton.BorderSizePixel = 0
        tpButton.Position = UDim2.new(0, 0, 0, 0)
        tpButton.Size = UDim2.new(0, 80, 0, 25)
        tpButton.Font = Enum.Font.Gotham
        tpButton.Text = "TELEPORT"
        tpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        tpButton.TextSize = 9
        
        local deleteButton = Instance.new("TextButton")
        deleteButton.Name = "DeleteButton"
        deleteButton.Parent = buttonFrame
        deleteButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
        deleteButton.BorderSizePixel = 0
        deleteButton.Position = UDim2.new(0, 85, 0, 0)
        deleteButton.Size = UDim2.new(0, 60, 0, 25)
        deleteButton.Font = Enum.Font.Gotham
        deleteButton.Text = "DELETE"
        deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        deleteButton.TextSize = 9
        
        local renameButton = Instance.new("TextButton")
        renameButton.Name = "RenameButton"
        renameButton.Parent = buttonFrame
        renameButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
        renameButton.BorderSizePixel = 0
        renameButton.Position = UDim2.new(0, 150, 0, 0)
        renameButton.Size = UDim2.new(0, 60, 0, 25)
        renameButton.Font = Enum.Font.Gotham
        renameButton.Text = "RENAME"
        renameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        renameButton.TextSize = 9
        
        tpButton.MouseButton1Click:Connect(function()
            loadPosition(positionName)
        end)
        
        deleteButton.MouseButton1Click:Connect(function()
            deletePosition(positionName)
        end)
        
        renameButton.MouseButton1Click:Connect(function()
            renamePosition(positionName, renameInput.Text)
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
            renameButton.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
        end)
        
        renameButton.MouseLeave:Connect(function()
            renameButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
        end)
        
        itemCount = itemCount + 1
    end
    
    wait(0.1)
    local contentSize = PositionLayout.AbsoluteContentSize
    PositionScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 10)
end

-- Initialize UI elements
local function initUI()
    -- Position Save Frame
    PositionFrame = Instance.new("Frame")
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
    local PositionTitle = Instance.new("TextLabel")
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
    local ClosePositionButton = Instance.new("TextButton")
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
    PositionInput = Instance.new("TextBox")
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
    SavePositionButton = Instance.new("TextButton")
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
    PositionScrollFrame = Instance.new("ScrollingFrame")
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
    PositionLayout = Instance.new("UIListLayout")
    PositionLayout.Parent = PositionScrollFrame
    PositionLayout.Padding = UDim.new(0, 2)
    PositionLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PositionLayout.FillDirection = Enum.FillDirection.Vertical

    -- Connect Save Position Button
    SavePositionButton.MouseButton1Click:Connect(savePosition)

    -- Connect Close Position Button
    ClosePositionButton.MouseButton1Click:Connect(function()
        Teleport.positionFrameVisible = false
        PositionFrame.Visible = false
    end)
end

-- Function to create buttons for Teleport features
function Teleport.loadTeleportButtons(createButton, selectedPlayer, freecamEnabled, freecamPosition, toggleFreecam)
    createButton("Position Manager", showPositionManager)
    createButton("TP to Selected Player", function() teleportToSelectedPlayer(selectedPlayer) end)
    createButton("TP to Freecam", function() teleportToFreecam(freecamEnabled, freecamPosition, toggleFreecam) end)
    createButton("Save Freecam Position", function() saveFreecamPosition(freecamPosition) end)
    createButton("Save Player Position", function() savePlayerPosition(selectedPlayer) end)
end

-- Function to reset Teleport states
function Teleport.resetStates()
    Teleport.savedPositions = {}
    Teleport.positionFrameVisible = false
    if PositionFrame then
        PositionFrame.Visible = false
    end
end

-- Function to set dependencies and initialize UI
function Teleport.init(deps)
    Players = deps.Players
    Workspace = deps.Workspace
    ScreenGui = deps.ScreenGui
    player = deps.player
    rootPart = deps.rootPart
    ScrollFrame = deps.ScrollFrame
    settings = deps.settings
    
    -- Initialize state variables
    Teleport.savedPositions = {}
    Teleport.positionFrameVisible = false
    
    -- Initialize UI elements
    initUI()
end

return Teleport