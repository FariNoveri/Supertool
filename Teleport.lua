-- Teleport-related features for MinimalHackGUI by Fari Noveri, including enhanced position manager
-- FIXED VERSION - Handles respawn/character reset properly

-- Dependencies: These must be passed from mainloader.lua
local Players, Workspace, ScreenGui, player, rootPart, ScrollFrame, settings

-- Initialize module
local Teleport = {}

-- Variables
Teleport.savedPositions = {}
Teleport.positionFrameVisible = false

-- Auto teleport variables
Teleport.autoTeleportActive = false
Teleport.autoTeleportMode = "once" -- "once" or "repeat"
Teleport.autoTeleportDelay = 2 -- seconds between teleports
Teleport.currentAutoIndex = 1
Teleport.autoTeleportCoroutine = nil

-- UI Elements (to be initialized in init function)
local PositionFrame, PositionScrollFrame, PositionLayout, PositionInput, SavePositionButton
local AutoTeleportFrame, AutoTeleportButton, AutoModeToggle, DelayInput, StopAutoButton

-- Character tracking variables
local currentCharacter = nil
local currentRootPart = nil

-- Mock file system for DCIM/Supertool (simulated with proper persistence)
local fileSystem = {
    ["DCIM/Supertool"] = {}
}

-- Helper function to get current root part safely
local function getRootPart()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        currentCharacter = player.Character
        currentRootPart = player.Character.HumanoidRootPart
        return currentRootPart
    end
    return nil
end

-- Helper function to save to file system
local function saveToFileSystem(positionName, cframe)
    if not positionName or not cframe then return false end
    fileSystem["DCIM/Supertool"][positionName] = {
        x = cframe.X,
        y = cframe.Y,
        z = cframe.Z,
        orientation = {cframe:ToEulerAnglesXYZ()}
    }
    return true
end

-- Helper function to load from file system
local function loadFromFileSystem(positionName)
    local data = fileSystem["DCIM/Supertool"][positionName]
    if data then
        local x, y, z = unpack(data.orientation)
        return CFrame.new(data.x, data.y, data.z) * CFrame.Angles(x, y, z)
    end
    return nil
end

-- Function to get ordered list of saved positions
local function getOrderedPositions()
    local orderedPositions = {}
    for name, cframe in pairs(Teleport.savedPositions) do
        table.insert(orderedPositions, {name = name, cframe = cframe})
    end
    table.sort(orderedPositions, function(a, b) return a.name < b.name end)
    return orderedPositions
end

-- Auto teleport function
local function doAutoTeleport()
    return coroutine.create(function()
        local positions = getOrderedPositions()
        if #positions == 0 then
            warn("No saved positions for auto teleport")
            Teleport.autoTeleportActive = false
            return
        end
        
        repeat
            for i = Teleport.currentAutoIndex, #positions do
                if not Teleport.autoTeleportActive then
                    print("Auto teleport stopped")
                    return
                end
                
                local position = positions[i]
                if safeTeleport(position.cframe) then
                    print("Auto teleported to: " .. position.name .. " (" .. i .. "/" .. #positions .. ")")
                else
                    warn("Failed to auto teleport to: " .. position.name)
                end
                
                Teleport.currentAutoIndex = i + 1
                
                -- Don't wait after the last position in "once" mode
                if i < #positions or Teleport.autoTeleportMode == "repeat" then
                    wait(Teleport.autoTeleportDelay)
                end
            end
            
            -- Reset index for repeat mode
            if Teleport.autoTeleportMode == "repeat" and Teleport.autoTeleportActive then
                Teleport.currentAutoIndex = 1
                print("Auto teleport cycle completed, restarting...")
            end
        until Teleport.autoTeleportMode ~= "repeat" or not Teleport.autoTeleportActive
        
        print("Auto teleport finished")
        Teleport.autoTeleportActive = false
        Teleport.currentAutoIndex = 1
    end)
end

-- Function to start auto teleport
function Teleport.startAutoTeleport()
    if Teleport.autoTeleportActive then
        warn("Auto teleport already active")
        return
    end
    
    local positions = getOrderedPositions()
    if #positions == 0 then
        warn("No saved positions for auto teleport")
        return
    end
    
    Teleport.autoTeleportActive = true
    Teleport.currentAutoIndex = 1
    Teleport.autoTeleportCoroutine = doAutoTeleport()
    
    spawn(function()
        local success, err = coroutine.resume(Teleport.autoTeleportCoroutine)
        if not success then
            warn("Auto teleport error: " .. tostring(err))
            Teleport.autoTeleportActive = false
        end
    end)
    
    print("Auto teleport started in " .. Teleport.autoTeleportMode .. " mode with " .. Teleport.autoTeleportDelay .. "s delay")
end

-- Function to stop auto teleport
function Teleport.stopAutoTeleport()
    if not Teleport.autoTeleportActive then
        return
    end
    
    Teleport.autoTeleportActive = false
    Teleport.currentAutoIndex = 1
    
    if Teleport.autoTeleportCoroutine then
        Teleport.autoTeleportCoroutine = nil
    end
    
    print("Auto teleport stopped")
end

-- Function to toggle auto teleport mode
function Teleport.toggleAutoMode()
    if Teleport.autoTeleportMode == "once" then
        Teleport.autoTeleportMode = "repeat"
    else
        Teleport.autoTeleportMode = "once"
    end
    print("Auto teleport mode: " .. Teleport.autoTeleportMode)
    return Teleport.autoTeleportMode
end
local function safeTeleport(targetCFrame)
    local root = getRootPart()
    if not root then
        warn("Cannot teleport: Character or HumanoidRootPart not found")
        return false
    end
    
    -- Wait a bit to ensure character is fully loaded
    if not root.Parent then
        wait(0.1)
        root = getRootPart()
        if not root then return false end
    end
    
    -- Perform teleport
    root.CFrame = targetCFrame
    return true
end

-- Function to create position button in the UI
local function createPositionButton(positionName, cframe)
    if not PositionScrollFrame then return end
    
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -10, 0, 25)
    button.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    button.BorderSizePixel = 1
    button.BorderColor3 = Color3.new(0.5, 0.5, 0.5)
    button.Text = positionName
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextScaled = true
    button.Font = Enum.Font.SourceSans
    button.Parent = PositionScrollFrame
    
    -- Teleport on click
    button.MouseButton1Click:Connect(function()
        if safeTeleport(cframe) then
            print("Teleported to: " .. positionName)
        else
            warn("Failed to teleport to: " .. positionName)
        end
    end)
    
    -- Delete on right click
    button.MouseButton2Click:Connect(function()
        Teleport.savedPositions[positionName] = nil
        fileSystem["DCIM/Supertool"][positionName] = nil
        button:Destroy()
        print("Deleted position: " .. positionName)
    end)
end

-- Function to refresh all position buttons
local function refreshPositionButtons()
    if not PositionScrollFrame then return end
    
    -- Clear existing buttons
    for _, child in pairs(PositionScrollFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- Recreate buttons from saved positions
    for positionName, cframe in pairs(Teleport.savedPositions) do
        createPositionButton(positionName, cframe)
    end
end

-- Function to handle character respawn
local function onCharacterAdded(character)
    currentCharacter = character
    
    -- Stop auto teleport when character respawns
    if Teleport.autoTeleportActive then
        Teleport.stopAutoTeleport()
        print("Auto teleport stopped due to character respawn")
    end
    
    -- Wait for HumanoidRootPart to be added
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
    if humanoidRootPart then
        currentRootPart = humanoidRootPart
        print("Character respawned, teleport system ready")
        
        -- Wait a bit more to ensure character is fully loaded
        wait(1)
        
        -- Refresh position buttons to ensure they work with new character
        refreshPositionButtons()
    else
        warn("HumanoidRootPart not found after respawn")
    end
end

-- Function to save current position
function Teleport.saveCurrentPosition()
    local root = getRootPart()
    if not root then
        warn("Cannot save position: Character not found")
        return false
    end
    
    local positionName = PositionInput.Text
    if positionName == "" then
        positionName = "Position_" .. #Teleport.savedPositions + 1
    end
    
    local currentCFrame = root.CFrame
    Teleport.savedPositions[positionName] = currentCFrame
    saveToFileSystem(positionName, currentCFrame)
    
    createPositionButton(positionName, currentCFrame)
    PositionInput.Text = ""
    
    print("Saved position: " .. positionName)
    return true
end

-- Function to load all saved positions from file system
function Teleport.loadSavedPositions()
    for positionName, _ in pairs(fileSystem["DCIM/Supertool"]) do
        local cframe = loadFromFileSystem(positionName)
        if cframe then
            Teleport.savedPositions[positionName] = cframe
        end
    end
    refreshPositionButtons()
end

-- Function to toggle position manager visibility
function Teleport.togglePositionManager()
    if not PositionFrame then return end
    
    Teleport.positionFrameVisible = not Teleport.positionFrameVisible
    PositionFrame.Visible = Teleport.positionFrameVisible
end

-- Function to create position manager UI
function Teleport.createPositionManagerUI()
    if not ScreenGui then return end
    
    -- Main frame
    PositionFrame = Instance.new("Frame")
    PositionFrame.Size = UDim2.new(0, 280, 0, 400)
    PositionFrame.Position = UDim2.new(0, 10, 0, 50)
    PositionFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
    PositionFrame.BorderSizePixel = 2
    PositionFrame.BorderColor3 = Color3.new(0.3, 0.3, 0.3)
    PositionFrame.Visible = false
    PositionFrame.Active = true
    PositionFrame.Draggable = true
    PositionFrame.Parent = ScreenGui
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
    title.BorderSizePixel = 0
    title.Text = "Position Manager"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextScaled = true
    title.Font = Enum.Font.SourceSansBold
    title.Parent = PositionFrame
    
    -- Input field
    PositionInput = Instance.new("TextBox")
    PositionInput.Size = UDim2.new(0.7, -5, 0, 25)
    PositionInput.Position = UDim2.new(0, 5, 0, 30)
    PositionInput.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
    PositionInput.BorderSizePixel = 1
    PositionInput.BorderColor3 = Color3.new(0.5, 0.5, 0.5)
    PositionInput.Text = ""
    PositionInput.PlaceholderText = "Position name..."
    PositionInput.TextColor3 = Color3.new(1, 1, 1)
    PositionInput.TextScaled = true
    PositionInput.Font = Enum.Font.SourceSans
    PositionInput.Parent = PositionFrame
    
    -- Save button
    SavePositionButton = Instance.new("TextButton")
    SavePositionButton.Size = UDim2.new(0.3, -5, 0, 25)
    SavePositionButton.Position = UDim2.new(0.7, 0, 0, 30)
    SavePositionButton.BackgroundColor3 = Color3.new(0, 0.5, 0)
    SavePositionButton.BorderSizePixel = 1
    SavePositionButton.BorderColor3 = Color3.new(0.5, 0.5, 0.5)
    SavePositionButton.Text = "Save"
    SavePositionButton.TextColor3 = Color3.new(1, 1, 1)
    SavePositionButton.TextScaled = true
    SavePositionButton.Font = Enum.Font.SourceSansBold
    SavePositionButton.Parent = PositionFrame
    
    -- Auto Teleport Frame
    AutoTeleportFrame = Instance.new("Frame")
    AutoTeleportFrame.Size = UDim2.new(1, -10, 0, 80)
    AutoTeleportFrame.Position = UDim2.new(0, 5, 0, 60)
    AutoTeleportFrame.BackgroundColor3 = Color3.new(0.15, 0.15, 0.25)
    AutoTeleportFrame.BorderSizePixel = 1
    AutoTeleportFrame.BorderColor3 = Color3.new(0.4, 0.4, 0.6)
    AutoTeleportFrame.Parent = PositionFrame
    
    -- Auto teleport title
    local autoTitle = Instance.new("TextLabel")
    autoTitle.Size = UDim2.new(1, 0, 0, 20)
    autoTitle.Position = UDim2.new(0, 0, 0, 0)
    autoTitle.BackgroundTransparency = 1
    autoTitle.Text = "Auto Teleport"
    autoTitle.TextColor3 = Color3.new(1, 1, 1)
    autoTitle.TextScaled = true
    autoTitle.Font = Enum.Font.SourceSansBold
    autoTitle.Parent = AutoTeleportFrame
    
    -- Mode toggle button
    AutoModeToggle = Instance.new("TextButton")
    AutoModeToggle.Size = UDim2.new(0.3, -2, 0, 25)
    AutoModeToggle.Position = UDim2.new(0, 2, 0, 22)
    AutoModeToggle.BackgroundColor3 = Color3.new(0.2, 0.4, 0.8)
    AutoModeToggle.BorderSizePixel = 1
    AutoModeToggle.BorderColor3 = Color3.new(0.5, 0.5, 0.5)
    AutoModeToggle.Text = "Once"
    AutoModeToggle.TextColor3 = Color3.new(1, 1, 1)
    AutoModeToggle.TextScaled = true
    AutoModeToggle.Font = Enum.Font.SourceSans
    AutoModeToggle.Parent = AutoTeleportFrame
    
    -- Delay input
    DelayInput = Instance.new("TextBox")
    DelayInput.Size = UDim2.new(0.35, -2, 0, 25)
    DelayInput.Position = UDim2.new(0.3, 2, 0, 22)
    DelayInput.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
    DelayInput.BorderSizePixel = 1
    DelayInput.BorderColor3 = Color3.new(0.5, 0.5, 0.5)
    DelayInput.Text = "2"
    DelayInput.PlaceholderText = "Delay (s)"
    DelayInput.TextColor3 = Color3.new(1, 1, 1)
    DelayInput.TextScaled = true
    DelayInput.Font = Enum.Font.SourceSans
    DelayInput.Parent = AutoTeleportFrame
    
    -- Start auto teleport button
    AutoTeleportButton = Instance.new("TextButton")
    AutoTeleportButton.Size = UDim2.new(0.35, -2, 0, 25)
    AutoTeleportButton.Position = UDim2.new(0.65, 2, 0, 22)
    AutoTeleportButton.BackgroundColor3 = Color3.new(0, 0.6, 0)
    AutoTeleportButton.BorderSizePixel = 1
    AutoTeleportButton.BorderColor3 = Color3.new(0.5, 0.5, 0.5)
    AutoTeleportButton.Text = "Start"
    AutoTeleportButton.TextColor3 = Color3.new(1, 1, 1)
    AutoTeleportButton.TextScaled = true
    AutoTeleportButton.Font = Enum.Font.SourceSansBold
    AutoTeleportButton.Parent = AutoTeleportFrame
    
    -- Stop auto teleport button
    StopAutoButton = Instance.new("TextButton")
    StopAutoButton.Size = UDim2.new(1, -4, 0, 25)
    StopAutoButton.Position = UDim2.new(0, 2, 0, 50)
    StopAutoButton.BackgroundColor3 = Color3.new(0.6, 0, 0)
    StopAutoButton.BorderSizePixel = 1
    StopAutoButton.BorderColor3 = Color3.new(0.5, 0.5, 0.5)
    StopAutoButton.Text = "Stop Auto Teleport"
    StopAutoButton.TextColor3 = Color3.new(1, 1, 1)
    StopAutoButton.TextScaled = true
    StopAutoButton.Font = Enum.Font.SourceSansBold
    StopAutoButton.Parent = AutoTeleportFrame
    
    -- Scroll frame for positions
    PositionScrollFrame = Instance.new("ScrollingFrame")
    PositionScrollFrame.Size = UDim2.new(1, -10, 1, -155)
    PositionScrollFrame.Position = UDim2.new(0, 5, 0, 150)
    PositionScrollFrame.BackgroundColor3 = Color3.new(0.15, 0.15, 0.15)
    PositionScrollFrame.BorderSizePixel = 1
    PositionScrollFrame.BorderColor3 = Color3.new(0.5, 0.5, 0.5)
    PositionScrollFrame.ScrollBarThickness = 8
    PositionScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    PositionScrollFrame.Parent = PositionFrame
    
    -- Layout for scroll frame
    PositionLayout = Instance.new("UIListLayout")
    PositionLayout.Padding = UDim.new(0, 2)
    PositionLayout.SortOrder = Enum.SortOrder.Name
    PositionLayout.Parent = PositionScrollFrame
    
    -- Update canvas size when layout changes
    PositionLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        PositionScrollFrame.CanvasSize = UDim2.new(0, 0, 0, PositionLayout.AbsoluteContentSize.Y)
    end)
    
    -- Connect buttons
    SavePositionButton.MouseButton1Click:Connect(function()
        Teleport.saveCurrentPosition()
    end)
    
    -- Auto mode toggle
    AutoModeToggle.MouseButton1Click:Connect(function()
        local newMode = Teleport.toggleAutoMode()
        AutoModeToggle.Text = newMode == "once" and "Once" or "Repeat"
        AutoModeToggle.BackgroundColor3 = newMode == "once" and Color3.new(0.2, 0.4, 0.8) or Color3.new(0.8, 0.4, 0.2)
    end)
    
    -- Delay input
    DelayInput.FocusLost:Connect(function()
        local newDelay = tonumber(DelayInput.Text)
        if newDelay and newDelay > 0 then
            Teleport.autoTeleportDelay = newDelay
            print("Auto teleport delay set to: " .. newDelay .. "s")
        else
            DelayInput.Text = tostring(Teleport.autoTeleportDelay)
        end
    end)
    
    -- Start auto teleport
    AutoTeleportButton.MouseButton1Click:Connect(function()
        if not Teleport.autoTeleportActive then
            Teleport.startAutoTeleport()
        end
    end)
    
    -- Stop auto teleport
    StopAutoButton.MouseButton1Click:Connect(function()
        Teleport.stopAutoTeleport()
    end)
    
    -- Handle Enter key in input field
    PositionInput.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            Teleport.saveCurrentPosition()
        end
    end)
end

-- Initialization function
function Teleport.init(dependencies)
    -- Set dependencies
    Players = dependencies.Players
    Workspace = dependencies.Workspace
    ScreenGui = dependencies.ScreenGui
    player = dependencies.player
    rootPart = dependencies.rootPart
    ScrollFrame = dependencies.ScrollFrame
    settings = dependencies.settings
    
    -- Set up character tracking
    currentCharacter = player.Character
    currentRootPart = getRootPart()
    
    -- Connect character respawn handler
    player.CharacterAdded:Connect(onCharacterAdded)
    
    -- Handle initial character if already spawned
    if player.Character then
        onCharacterAdded(player.Character)
    end
    
    -- Create UI
    Teleport.createPositionManagerUI()
    
    -- Load saved positions
    Teleport.loadSavedPositions()
    
    print("Teleport module initialized with respawn safety")
end

-- Quick teleport functions (can be called safely anytime)
function Teleport.teleportToSpawn()
    local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
    if spawnLocation then
        safeTeleport(spawnLocation.CFrame + Vector3.new(0, 5, 0))
    end
end

function Teleport.teleportToPosition(x, y, z)
    safeTeleport(CFrame.new(x, y, z))
end

return Teleport        return CFrame.new(
            data.x, data.y, data.z,
            CFrame.fromEulerAnglesXYZ(table.unpack(data.orientation))
        )
    end
    return nil
end

-- Helper function to delete from file system
local function deleteFromFileSystem(positionName)
    if fileSystem["DCIM/Supertool"][positionName] then
        fileSystem["DCIM/Supertool"][positionName] = nil
        return true
    end
    return false
end

-- Helper function to rename in file system
local function renameInFileSystem(oldName, newName)
    if fileSystem["DCIM/Supertool"][oldName] and newName ~= "" then
        fileSystem["DCIM/Supertool"][newName] = fileSystem["DCIM/Supertool"][oldName]
        fileSystem["DCIM/Supertool"][oldName] = nil
        return true
    end
    return false
end

-- Save Position
local function savePosition()
    if not rootPart then
        warn("Cannot save position: No valid HumanoidRootPart")
        return
    end

    local positionName = PositionInput.Text
    if positionName == "" then
        positionName = "Position " .. (#Teleport.savedPositions + 1)
    end
    
    Teleport.savedPositions[positionName] = rootPart.CFrame
    if saveToFileSystem(positionName, rootPart.CFrame) then
        print("Position Saved: " .. positionName)
        PositionInput.Text = ""
        Teleport.updatePositionList()
    else
        warn("Failed to save position to file system")
    end
end

-- Load Position (Teleport to saved position)
local function loadPosition(positionName)
    if not rootPart then
        warn("Cannot teleport: No valid HumanoidRootPart")
        return
    end

    local cframe = Teleport.savedPositions[positionName] or loadFromFileSystem(positionName)
    if cframe then
        rootPart.CFrame = cframe
        print("Teleported to: " .. positionName)
    else
        warn("Cannot teleport: Invalid position")
    end
end

-- Delete Position
local function deletePosition(positionName)
    if Teleport.savedPositions[positionName] then
        Teleport.savedPositions[positionName] = nil
        if deleteFromFileSystem(positionName) then
            print("Deleted position: " .. positionName)
            Teleport.updatePositionList()
        else
            warn("Failed to delete position from file system")
        end
    end
end

-- Rename Position
local function renamePosition(oldName, newName)
    if Teleport.savedPositions[oldName] and newName ~= "" then
        if renameInFileSystem(oldName, newName) then
            Teleport.savedPositions[newName] = Teleport.savedPositions[oldName]
            Teleport.savedPositions[oldName] = nil
            print("Renamed position: " .. oldName .. " to " .. newName)
            Teleport.updatePositionList()
        else
            warn("Failed to rename position in file system")
        end
    else
        warn("Cannot rename: Invalid old name or empty new name")
    end
end

-- Save Freecam Position to Position Manager
local function saveFreecamPosition(freecamPosition)
    if not freecamPosition then
        warn("Cannot save: Freecam must be enabled to save position")
        return
    end

    local positionName = PositionInput.Text
    if positionName == "" then
        positionName = "Freecam Position " .. (#Teleport.savedPositions + 1)
    end
    
    local cframe = CFrame.new(freecamPosition)
    Teleport.savedPositions[positionName] = cframe
    if saveToFileSystem(positionName, cframe) then
        print("Freecam Position Saved: " .. positionName)
        PositionInput.Text = ""
        Teleport.updatePositionList()
    else
        warn("Failed to save freecam position")
    end
end

-- Teleport to Freecam Position
local function teleportToFreecam(freecamEnabled, freecamPosition, toggleFreecam)
    if not rootPart then
        warn("Cannot teleport: No valid HumanoidRootPart")
        return
    end

    if freecamEnabled and freecamPosition then
        toggleFreecam(false)
        rootPart.CFrame = CFrame.new(freecamPosition)
        print("Teleported to freecam position")
    elseif freecamPosition then
        rootPart.CFrame = CFrame.new(freecamPosition)
        print("Teleported to last freecam position")
    else
        warn("Use freecam first to set a position")
    end
end

-- Show Position Manager
local function showPositionManager()
    Teleport.positionFrameVisible = true
    if PositionFrame then
        PositionFrame.Visible = true
        Teleport.updatePositionList()
    else
        warn("PositionFrame not initialized")
    end
end

-- Update Position List UI
function Teleport.updatePositionList()
    if not PositionScrollFrame then return end
    
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
    
    task.wait(0.1)
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
    createButton("TP to Freecam", function() teleportToFreecam(freecamEnabled, freecamPosition, toggleFreecam) end)
    createButton("Save Freecam Position", function() saveFreecamPosition(freecamPosition) end)
    createButton("Save Current Position", savePosition)
end

-- Function to reset Teleport states
function Teleport.resetStates()
    Teleport.savedPositions = {}
    Teleport.positionFrameVisible = false
    fileSystem["DCIM/Supertool"] = {}
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
