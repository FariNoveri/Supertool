-- teleport.lua
-- Teleport-related features for MinimalHackGUI by Fari Noveri
-- ENHANCED VERSION: Added dropdown groups, fixed duplicates, added rename/delete, improved UI, better scrolling, persistent positions on respawn, auto-teleport status label, and pause on death with auto-resume

-- Dependencies: These must be passed from mainloader.lua
local Players, Workspace, ScreenGui, ScrollFrame, player, rootPart, settings

-- Initialize module
local Teleport = {}

-- Variables
Teleport.savedPositions = Teleport.savedPositions or {} -- Preserve existing positions
Teleport.positionNumbers = Teleport.positionNumbers or {} -- Preserve existing position numbers
Teleport.positionGroups = Teleport.positionGroups or {} -- Group assignments for positions
Teleport.groups = Teleport.groups or {} -- Group definitions {name, expanded, autoTeleportEnabled}
Teleport.positionFrameVisible = false
Teleport.autoTeleportActive = false
Teleport.autoTeleportPaused = false -- New flag for pausing auto-teleport
Teleport.autoTeleportMode = "once" -- "once" or "repeat"
Teleport.autoTeleportDelay = 2 -- seconds between teleports
Teleport.currentAutoIndex = 1
Teleport.autoTeleportCoroutine = nil

-- UI Elements (to be initialized in initUI function)
local PositionFrame, PositionScrollFrame, PositionLayout, PositionInput, SavePositionButton
local AutoTeleportFrame, AutoTeleportButton, AutoModeToggle, DelayInput, StopAutoButton
local AutoStatusLabel, GroupInput, CreateGroupButton -- New elements for groups

-- Mock file system - consistent with settings.lua structure
local fileSystem = fileSystem or { ["DCIM/Supertool"] = {} } -- Preserve existing filesystem

-- Get root part
local function getRootPart()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        return player.Character.HumanoidRootPart
    end
    warn("Cannot get root part: Character or HumanoidRootPart not found")
    return nil
end

-- Save group to filesystem
local function saveGroupToFileSystem(groupName, groupData)
    if not groupName or not groupData then
        warn("Cannot save group to file system: Invalid groupName or groupData")
        return false
    end
    fileSystem["DCIM/Supertool"]["group_" .. groupName] = {
        type = "teleport_group",
        name = groupName,
        expanded = groupData.expanded or false,
        autoTeleportEnabled = groupData.autoTeleportEnabled or false
    }
    print("Saved group to file system: " .. groupName)
    return true
end

-- Load group from filesystem
local function loadGroupFromFileSystem(groupName)
    local data = fileSystem["DCIM/Supertool"]["group_" .. groupName]
    if data and data.type == "teleport_group" then
        return {
            name = data.name,
            expanded = data.expanded or false,
            autoTeleportEnabled = data.autoTeleportEnabled or false
        }
    end
    return nil
end

-- Save to mock filesystem
local function saveToFileSystem(positionName, cframe, number, groupName)
    if not positionName or not cframe then
        warn("Cannot save to file system: Invalid positionName or cframe")
        return false
    end
    fileSystem["DCIM/Supertool"][positionName] = {
        type = "teleport_position", -- Add type identifier
        x = cframe.X,
        y = cframe.Y,
        z = cframe.Z,
        orientation = {cframe:ToEulerAnglesXYZ()},
        number = number or 0,
        group = groupName or "Default"
    }
    print("Saved to file system: " .. positionName)
    return true
end

-- Load from mock filesystem
local function loadFromFileSystem(positionName)
    local data = fileSystem["DCIM/Supertool"][positionName]
    if data and data.type == "teleport_position" then
        local rx, ry, rz = unpack(data.orientation)
        Teleport.positionNumbers[positionName] = data.number or 0 -- Load number
        Teleport.positionGroups[positionName] = data.group or "Default" -- Load group
        return CFrame.new(data.x, data.y, data.z) * CFrame.Angles(rx, ry, rz)
    end
    warn("Cannot load from file system: Position " .. tostring(positionName) .. " not found")
    return nil
end

-- Ensure default group exists
local function ensureDefaultGroup()
    if not Teleport.groups["Default"] then
        Teleport.groups["Default"] = {
            name = "Default",
            expanded = true,
            autoTeleportEnabled = true
        }
        saveGroupToFileSystem("Default", Teleport.groups["Default"])
    end
end

-- Get positions by group
local function getPositionsByGroup(groupName)
    local positions = {}
    for posName, cframe in pairs(Teleport.savedPositions) do
        local posGroup = Teleport.positionGroups[posName] or "Default"
        if posGroup == groupName then
            local number = Teleport.positionNumbers[posName] or 0
            table.insert(positions, {name = posName, cframe = cframe, number = number})
        end
    end
    
    -- Sort by number first, then by name for positions with same number or 0
    table.sort(positions, function(a, b)
        if a.number == 0 and b.number == 0 then
            return a.name < b.name -- Alphabetical for unnumbered
        elseif a.number == 0 then
            return false -- Unnumbered goes to end
        elseif b.number == 0 then
            return true -- Numbered comes first
        elseif a.number == b.number then
            return a.name < b.name -- Same number, sort by name
        else
            return a.number < b.number -- Sort by number
        end
    end)
    
    return positions
end

-- Get ordered positions for auto teleport (only from enabled groups)
local function getOrderedPositions()
    local orderedPositions = {}
    for groupName, groupData in pairs(Teleport.groups) do
        if groupData.autoTeleportEnabled then
            local groupPositions = getPositionsByGroup(groupName)
            for _, position in ipairs(groupPositions) do
                table.insert(orderedPositions, position)
            end
        end
    end
    return orderedPositions
end

-- Check for duplicate numbers within a group
local function getDuplicateNumbers(groupName)
    local numberCount = {}
    local duplicates = {}
    
    for posName, number in pairs(Teleport.positionNumbers) do
        local posGroup = Teleport.positionGroups[posName] or "Default"
        if posGroup == groupName and number > 0 then -- Only check numbered positions in this group
            if numberCount[number] then
                table.insert(numberCount[number], posName)
                if not duplicates[number] then
                    duplicates[number] = true
                end
            else
                numberCount[number] = {posName}
            end
        end
    end
    
    local duplicateList = {}
    for number, isDupe in pairs(duplicates) do
        for _, name in ipairs(numberCount[number]) do
            duplicateList[name] = true
        end
    end
    
    return duplicateList
end

-- Safe teleport
local function safeTeleport(targetCFrame)
    local root = getRootPart()
    if not root then
        return false
    end
    if not root.Parent then
        wait(0.1)
        root = getRootPart()
        if not root then return false end
    end
    root.CFrame = targetCFrame
    print("Teleported to CFrame: " .. tostring(targetCFrame))
    return true
end

-- Check if position name already exists
local function positionExists(positionName)
    return Teleport.savedPositions[positionName] ~= nil
end

-- Generate unique position name
local function generateUniqueName(baseName)
    if not positionExists(baseName) then
        return baseName
    end
    
    local counter = 1
    local newName = baseName .. "_" .. counter
    while positionExists(newName) do
        counter = counter + 1
        newName = baseName .. "_" .. counter
    end
    return newName
end

-- Create group rename dialog
local function createGroupRenameDialog(groupName, onRename)
    local RenameFrame = Instance.new("Frame")
    RenameFrame.Name = "GroupRenameDialog"
    RenameFrame.Parent = ScreenGui
    RenameFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    RenameFrame.BorderColor3 = Color3.fromRGB(60, 60, 60)
    RenameFrame.BorderSizePixel = 1
    RenameFrame.Position = UDim2.new(0.5, -125, 0.5, -50)
    RenameFrame.Size = UDim2.new(0, 250, 0, 100)
    RenameFrame.Active = true
    RenameFrame.Draggable = true

    local RenameTitle = Instance.new("TextLabel")
    RenameTitle.Parent = RenameFrame
    RenameTitle.BackgroundTransparency = 1
    RenameTitle.Position = UDim2.new(0, 10, 0, 5)
    RenameTitle.Size = UDim2.new(1, -20, 0, 20)
    RenameTitle.Font = Enum.Font.Gotham
    RenameTitle.Text = "Rename Group: " .. groupName
    RenameTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    RenameTitle.TextSize = 10
    RenameTitle.TextXAlignment = Enum.TextXAlignment.Left

    local RenameInput = Instance.new("TextBox")
    RenameInput.Parent = RenameFrame
    RenameInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    RenameInput.BorderSizePixel = 0
    RenameInput.Position = UDim2.new(0, 10, 0, 30)
    RenameInput.Size = UDim2.new(1, -20, 0, 25)
    RenameInput.Font = Enum.Font.Gotham
    RenameInput.Text = groupName
    RenameInput.PlaceholderText = "Enter new group name"
    RenameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    RenameInput.TextSize = 11

    local ConfirmButton = Instance.new("TextButton")
    ConfirmButton.Parent = RenameFrame
    ConfirmButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    ConfirmButton.BorderSizePixel = 0
    ConfirmButton.Position = UDim2.new(0, 10, 0, 65)
    ConfirmButton.Size = UDim2.new(0.5, -15, 0, 25)
    ConfirmButton.Font = Enum.Font.Gotham
    ConfirmButton.Text = "Rename"
    ConfirmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ConfirmButton.TextSize = 10

    local CancelButton = Instance.new("TextButton")
    CancelButton.Parent = RenameFrame
    CancelButton.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
    CancelButton.BorderSizePixel = 0
    CancelButton.Position = UDim2.new(0.5, 5, 0, 65)
    CancelButton.Size = UDim2.new(0.5, -15, 0, 25)
    CancelButton.Font = Enum.Font.Gotham
    CancelButton.Text = "Cancel"
    CancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CancelButton.TextSize = 10

    ConfirmButton.MouseButton1Click:Connect(function()
        local newName = RenameInput.Text:gsub("^%s*(.-)%s*$", "%1")
        if newName == "" then
            warn("New group name cannot be empty")
            return
        end
        if newName == groupName then
            warn("New name is the same as current name")
            RenameFrame:Destroy()
            return
        end
        if newName == "Default" then
            warn("Cannot rename to 'Default' - reserved name")
            return
        end
        if Teleport.groups[newName] then
            warn("Group name already exists: " .. newName)
            return
        end
        onRename(newName)
        RenameFrame:Destroy()
    end)

    CancelButton.MouseButton1Click:Connect(function()
        RenameFrame:Destroy()
    end)

    RenameInput:CaptureFocus()
end

-- Create number input dialog
local function createNumberInputDialog(positionName, currentNumber, onNumberSet)
    local NumberFrame = Instance.new("Frame")
    NumberFrame.Name = "NumberInputDialog"
    NumberFrame.Parent = ScreenGui
    NumberFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    NumberFrame.BorderColor3 = Color3.fromRGB(60, 60, 60)
    NumberFrame.BorderSizePixel = 1
    NumberFrame.Position = UDim2.new(0.5, -125, 0.5, -50)
    NumberFrame.Size = UDim2.new(0, 250, 0, 100)
    NumberFrame.Active = true
    NumberFrame.Draggable = true

    local NumberTitle = Instance.new("TextLabel")
    NumberTitle.Parent = NumberFrame
    NumberTitle.BackgroundTransparency = 1
    NumberTitle.Position = UDim2.new(0, 10, 0, 5)
    NumberTitle.Size = UDim2.new(1, -20, 0, 20)
    NumberTitle.Font = Enum.Font.Gotham
    NumberTitle.Text = "Set Position Number: " .. positionName
    NumberTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    NumberTitle.TextSize = 10
    NumberTitle.TextXAlignment = Enum.TextXAlignment.Left

    local NumberInput = Instance.new("TextBox")
    NumberInput.Parent = NumberFrame
    NumberInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    NumberInput.BorderSizePixel = 0
    NumberInput.Position = UDim2.new(0, 10, 0, 30)
    NumberInput.Size = UDim2.new(1, -20, 0, 25)
    NumberInput.Font = Enum.Font.Gotham
    NumberInput.Text = currentNumber > 0 and tostring(currentNumber) or ""
    NumberInput.PlaceholderText = "Enter number (0 = no number)"
    NumberInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    NumberInput.TextSize = 11

    local ConfirmButton = Instance.new("TextButton")
    ConfirmButton.Parent = NumberFrame
    ConfirmButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    ConfirmButton.BorderSizePixel = 0
    ConfirmButton.Position = UDim2.new(0, 10, 0, 65)
    ConfirmButton.Size = UDim2.new(0.5, -15, 0, 25)
    ConfirmButton.Font = Enum.Font.Gotham
    ConfirmButton.Text = "Set"
    ConfirmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ConfirmButton.TextSize = 10

    local CancelButton = Instance.new("TextButton")
    CancelButton.Parent = NumberFrame
    CancelButton.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
    CancelButton.BorderSizePixel = 0
    CancelButton.Position = UDim2.new(0.5, 5, 0, 65)
    CancelButton.Size = UDim2.new(0.5, -15, 0, 25)
    CancelButton.Font = Enum.Font.Gotham
    CancelButton.Text = "Cancel"
    CancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CancelButton.TextSize = 10

    ConfirmButton.MouseButton1Click:Connect(function()
        local numberText = NumberInput.Text:gsub("^%s*(.-)%s*$", "%1")
        local number = 0
        
        if numberText ~= "" then
            local parsedNumber = tonumber(numberText)
            if parsedNumber and parsedNumber >= 0 and parsedNumber == math.floor(parsedNumber) then
                number = parsedNumber
            else
                warn("Invalid number format! Use whole numbers >= 0")
                return
            end
        end
        
        onNumberSet(number)
        NumberFrame:Destroy()
    end)

    CancelButton.MouseButton1Click:Connect(function()
        NumberFrame:Destroy()
    end)

    NumberInput:CaptureFocus()
end

-- Create rename dialog
local function createRenameDialog(positionName, onRename)
    local RenameFrame = Instance.new("Frame")
    RenameFrame.Name = "RenameDialog"
    RenameFrame.Parent = ScreenGui
    RenameFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    RenameFrame.BorderColor3 = Color3.fromRGB(60, 60, 60)
    RenameFrame.BorderSizePixel = 1
    RenameFrame.Position = UDim2.new(0.5, -125, 0.5, -50)
    RenameFrame.Size = UDim2.new(0, 250, 0, 100)
    RenameFrame.Active = true
    RenameFrame.Draggable = true

    local RenameTitle = Instance.new("TextLabel")
    RenameTitle.Parent = RenameFrame
    RenameTitle.BackgroundTransparency = 1
    RenameTitle.Position = UDim2.new(0, 10, 0, 5)
    RenameTitle.Size = UDim2.new(1, -20, 0, 20)
    RenameTitle.Font = Enum.Font.Gotham
    RenameTitle.Text = "Rename Position: " .. positionName
    RenameTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    RenameTitle.TextSize = 10
    RenameTitle.TextXAlignment = Enum.TextXAlignment.Left

    local RenameInput = Instance.new("TextBox")
    RenameInput.Parent = RenameFrame
    RenameInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    RenameInput.BorderSizePixel = 0
    RenameInput.Position = UDim2.new(0, 10, 0, 30)
    RenameInput.Size = UDim2.new(1, -20, 0, 25)
    RenameInput.Font = Enum.Font.Gotham
    RenameInput.Text = positionName
    RenameInput.PlaceholderText = "Enter new name"
    RenameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    RenameInput.TextSize = 11

    local ConfirmButton = Instance.new("TextButton")
    ConfirmButton.Parent = RenameFrame
    ConfirmButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    ConfirmButton.BorderSizePixel = 0
    ConfirmButton.Position = UDim2.new(0, 10, 0, 65)
    ConfirmButton.Size = UDim2.new(0.5, -15, 0, 25)
    ConfirmButton.Font = Enum.Font.Gotham
    ConfirmButton.Text = "Rename"
    ConfirmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ConfirmButton.TextSize = 10

    local CancelButton = Instance.new("TextButton")
    CancelButton.Parent = RenameFrame
    CancelButton.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
    CancelButton.BorderSizePixel = 0
    CancelButton.Position = UDim2.new(0.5, 5, 0, 65)
    CancelButton.Size = UDim2.new(0.5, -15, 0, 25)
    CancelButton.Font = Enum.Font.Gotham
    CancelButton.Text = "Cancel"
    CancelButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CancelButton.TextSize = 10

    ConfirmButton.MouseButton1Click:Connect(function()
        local newName = RenameInput.Text:gsub("^%s*(.-)%s*$", "%1")
        if newName == "" then
            warn("New name cannot be empty")
            return
        end
        if newName == positionName then
            warn("New name is the same as current name")
            RenameFrame:Destroy()
            return
        end
        if positionExists(newName) then
            warn("Position name already exists: " .. newName)
            return
        end
        onRename(newName)
        RenameFrame:Destroy()
    end)

    CancelButton.MouseButton1Click:Connect(function()
        RenameFrame:Destroy()
    end)

    RenameInput:CaptureFocus()
end

-- Forward declarations for functions that reference each other
local refreshPositionButtons

-- Delete position with confirmation
local function deletePositionWithConfirmation(positionName, button)
    -- Simple confirmation by requiring double-click
    if button.Text == "Delete?" then
        Teleport.savedPositions[positionName] = nil
        Teleport.positionNumbers[positionName] = nil -- Remove number too
        Teleport.positionGroups[positionName] = nil -- Remove group assignment
        fileSystem["DCIM/Supertool"][positionName] = nil
        button.Parent:Destroy()
        print("Deleted position: " .. positionName)
        updateScrollCanvasSize()
        -- Refresh all buttons to update duplicate highlighting
        refreshPositionButtons()
    else
        button.Text = "Delete?"
        button.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        spawn(function()
            wait(2)
            if button.Parent then
                button.Text = "Del"
                button.BackgroundColor3 = Color3.fromRGB(100, 40, 40)
            end
        end)
    end
end

-- Delete group with confirmation
local function deleteGroupWithConfirmation(groupName, button)
    if groupName == "Default" then
        warn("Cannot delete Default group")
        return
    end
    
    if button.Text == "Delete Group?" then
        -- Move all positions in this group to Default
        for posName, group in pairs(Teleport.positionGroups) do
            if group == groupName then
                Teleport.positionGroups[posName] = "Default"
                -- Update filesystem
                if Teleport.savedPositions[posName] then
                    saveToFileSystem(posName, Teleport.savedPositions[posName], 
                                   Teleport.positionNumbers[posName] or 0, "Default")
                end
            end
        end
        
        -- Remove group
        Teleport.groups[groupName] = nil
        fileSystem["DCIM/Supertool"]["group_" .. groupName] = nil
        
        print("Deleted group: " .. groupName .. " (positions moved to Default)")
        refreshPositionButtons()
    else
        button.Text = "Delete Group?"
        button.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        spawn(function()
            wait(2)
            if button.Parent then
                button.Text = "Del"
                button.BackgroundColor3 = Color3.fromRGB(100, 40, 40)
            end
        end)
    end
end

-- Update scroll canvas size
local function updateScrollCanvasSize()
    if PositionScrollFrame and PositionLayout then
        PositionScrollFrame.CanvasSize = UDim2.new(0, 0, 0, PositionLayout.AbsoluteContentSize.Y + 10)
    end
end

-- Auto teleport loop
local function doAutoTeleport()
    return coroutine.create(function()
        local positions = getOrderedPositions()
        if #positions == 0 then
            warn("No saved positions for auto teleport")
            Teleport.autoTeleportActive = false
            if AutoStatusLabel then
                AutoStatusLabel.Visible = false
            end
            return
        end
        repeat
            for i = Teleport.currentAutoIndex, #positions do
                if not Teleport.autoTeleportActive then return end
                -- Check for pause
                while Teleport.autoTeleportPaused do
                    wait(0.1)
                end
                local position = positions[i]
                if safeTeleport(position.cframe) then
                    print("Auto teleported to: " .. position.name .. " (" .. i .. "/" .. #positions .. ")")
                    -- Update status label with current position
                    if AutoStatusLabel then
                        local number = Teleport.positionNumbers[position.name] or 0
                        local numberText = number > 0 and "#" .. number or ""
                        AutoStatusLabel.Text = "Auto: " .. Teleport.autoTeleportMode .. " - " .. position.name .. numberText
                    end
                else
                    warn("Failed to auto teleport to: " .. position.name)
                end
                Teleport.currentAutoIndex = i + 1
                if i < #positions or Teleport.autoTeleportMode == "repeat" then
                    wait(Teleport.autoTeleportDelay)
                end
            end
            if Teleport.autoTeleportMode == "repeat" and Teleport.autoTeleportActive then
                Teleport.currentAutoIndex = 1
                print("Auto teleport cycle completed, restarting...")
            end
        until Teleport.autoTeleportMode ~= "repeat" or not Teleport.autoTeleportActive
        Teleport.autoTeleportActive = false
        Teleport.currentAutoIndex = 1
        if AutoStatusLabel then
            AutoStatusLabel.Visible = false
        end
        print("Auto teleport finished")
    end)
end

-- Start auto teleport
function Teleport.startAutoTeleport()
    if Teleport.autoTeleportActive then
        warn("Auto teleport already active")
        return
    end
    if #getOrderedPositions() == 0 then
        warn("No saved positions for auto teleport")
        return
    end
    Teleport.autoTeleportActive = true
    Teleport.currentAutoIndex = 1
    Teleport.autoTeleportCoroutine = doAutoTeleport()
    -- Update status label
    if AutoStatusLabel then
        local positions = getOrderedPositions()
        local position = positions[1]
        local number = Teleport.positionNumbers[position.name] or 0
        local numberText = number > 0 and "#" .. number or ""
        AutoStatusLabel.Text = "Auto: " .. Teleport.autoTeleportMode .. " - " .. position.name .. numberText
        AutoStatusLabel.Visible = true
    end
    spawn(function()
        local success, err = coroutine.resume(Teleport.autoTeleportCoroutine)
        if not success then
            warn("Auto teleport error: " .. tostring(err))
            Teleport.autoTeleportActive = false
            if AutoStatusLabel then
                AutoStatusLabel.Visible = false
            end
        end
    end)
    print("Auto teleport started in " .. Teleport.autoTeleportMode .. " mode")
end

-- Stop auto teleport
function Teleport.stopAutoTeleport()
    if not Teleport.autoTeleportActive then return end
    Teleport.autoTeleportActive = false
    Teleport.autoTeleportPaused = false
    Teleport.currentAutoIndex = 1
    Teleport.autoTeleportCoroutine = nil
    if AutoStatusLabel then
        AutoStatusLabel.Visible = false
    end
    print("Auto teleport stopped")
end

-- Toggle auto mode
function Teleport.toggleAutoMode()
    Teleport.autoTeleportMode = Teleport.autoTeleportMode == "once" and "repeat" or "once"
    if AutoModeToggle then
        AutoModeToggle.Text = "Mode: " .. Teleport.autoTeleportMode
    end
    -- Update status label if auto-teleport is active
    if Teleport.autoTeleportActive and AutoStatusLabel then
        local positions = getOrderedPositions()
        if positions[Teleport.currentAutoIndex] then
            local position = positions[Teleport.currentAutoIndex]
            local number = Teleport.positionNumbers[position.name] or 0
            local numberText = number > 0 and "#" .. number or ""
            AutoStatusLabel.Text = "Auto: " .. Teleport.autoTeleportMode .. " - " .. position.name .. numberText
        end
    end
    print("Auto teleport mode set to: " .. Teleport.autoTeleportMode)
    return Teleport.autoTeleportMode
end

-- Create group header
local function createGroupHeader(groupName, groupData)
    if not PositionScrollFrame then
        warn("Cannot create group header: PositionScrollFrame not initialized")
        return
    end

    local GroupFrame = Instance.new("Frame")
    GroupFrame.Size = UDim2.new(1, -10, 0, 25)
    GroupFrame.BackgroundTransparency = 1
    GroupFrame.Parent = PositionScrollFrame

    -- Dropdown line (like --------v)
    local DropdownButton = Instance.new("TextButton")
    DropdownButton.Size = UDim2.new(0, 12, 1, 0)
    DropdownButton.Position = UDim2.new(0, 0, 0, 0)
    DropdownButton.BackgroundTransparency = 1
    DropdownButton.Text = groupData.expanded and "v" or ">"
    DropdownButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    DropdownButton.TextSize = 10
    DropdownButton.Font = Enum.Font.GothamBold
    DropdownButton.Parent = GroupFrame

    -- Dropdown line
    local DropdownLine = Instance.new("TextLabel")
    DropdownLine.Size = UDim2.new(0, 60, 1, 0)
    DropdownLine.Position = UDim2.new(0, 15, 0, 0)
    DropdownLine.BackgroundTransparency = 1
    DropdownLine.Text = "--------"
    DropdownLine.TextColor3 = Color3.fromRGB(150, 150, 150)
    DropdownLine.TextSize = 9
    DropdownLine.Font = Enum.Font.Gotham
    DropdownLine.TextXAlignment = Enum.TextXAlignment.Left
    DropdownLine.Parent = GroupFrame

    -- Group name label
    local GroupNameLabel = Instance.new("TextLabel")
    GroupNameLabel.Size = UDim2.new(1, -170, 1, 0)
    GroupNameLabel.Position = UDim2.new(0, 80, 0, 0)
    GroupNameLabel.BackgroundTransparency = 1
    GroupNameLabel.Text = groupName .. ".json"
    GroupNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    GroupNameLabel.TextSize = 9
    GroupNameLabel.Font = Enum.Font.Gotham
    GroupNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    GroupNameLabel.Parent = GroupFrame

    -- Auto teleport toggle for group
    local AutoToggleButton = Instance.new("TextButton")
    AutoToggleButton.Size = UDim2.new(0, 40, 0, 18)
    AutoToggleButton.Position = UDim2.new(1, -130, 0, 3)
    AutoToggleButton.BackgroundColor3 = groupData.autoTeleportEnabled and Color3.fromRGB(60, 120, 60) or Color3.fromRGB(120, 60, 60)
    AutoToggleButton.BorderSizePixel = 0
    AutoToggleButton.Text = groupData.autoTeleportEnabled and "ON" or "OFF"
    AutoToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    AutoToggleButton.TextSize = 8
    AutoToggleButton.Font = Enum.Font.Gotham
    AutoToggleButton.Parent = GroupFrame

    -- Rename group button
    local RenameGroupButton = Instance.new("TextButton")
    RenameGroupButton.Size = UDim2.new(0, 32, 0, 18)
    RenameGroupButton.Position = UDim2.new(1, -85, 0, 3)
    RenameGroupButton.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
    RenameGroupButton.BorderSizePixel = 0
    RenameGroupButton.Text = "Ren"
    RenameGroupButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    RenameGroupButton.TextSize = 8
    RenameGroupButton.Font = Enum.Font.Gotham
    RenameGroupButton.Parent = GroupFrame

    -- Delete group button (only for non-default groups)
    local DeleteGroupButton
    if groupName ~= "Default" then
        DeleteGroupButton = Instance.new("TextButton")
        DeleteGroupButton.Size = UDim2.new(0, 32, 0, 18)
        DeleteGroupButton.Position = UDim2.new(1, -50, 0, 3)
        DeleteGroupButton.BackgroundColor3 = Color3.fromRGB(100, 40, 40)
        DeleteGroupButton.BorderSizePixel = 0
        DeleteGroupButton.Text = "Del"
        DeleteGroupButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        DeleteGroupButton.TextSize = 8
        DeleteGroupButton.Font = Enum.Font.Gotham
        DeleteGroupButton.Parent = GroupFrame
    end

    -- Event connections
    DropdownButton.MouseButton1Click:Connect(function()
        groupData.expanded = not groupData.expanded
        DropdownButton.Text = groupData.expanded and "v" or ">"
        saveGroupToFileSystem(groupName, groupData)
        refreshPositionButtons()
    end)

    AutoToggleButton.MouseButton1Click:Connect(function()
        groupData.autoTeleportEnabled = not groupData.autoTeleportEnabled
        AutoToggleButton.BackgroundColor3 = groupData.autoTeleportEnabled and Color3.fromRGB(60, 120, 60) or Color3.fromRGB(120, 60, 60)
        AutoToggleButton.Text = groupData.autoTeleportEnabled and "ON" or "OFF"
        saveGroupToFileSystem(groupName, groupData)
        print("Group " .. groupName .. " auto teleport: " .. (groupData.autoTeleportEnabled and "enabled" or "disabled"))
    end)

    RenameGroupButton.MouseButton1Click:Connect(function()
        if groupName == "Default" then
            warn("Cannot rename Default group")
            return
        end
        createGroupRenameDialog(groupName, function(newName)
            -- Update group data
            Teleport.groups[newName] = Teleport.groups[groupName]
            Teleport.groups[newName].name = newName
            Teleport.groups[groupName] = nil
            
            -- Update all positions in this group
            for posName, group in pairs(Teleport.positionGroups) do
                if group == groupName then
                    Teleport.positionGroups[posName] = newName
                    -- Update filesystem
                    if Teleport.savedPositions[posName] then
                        saveToFileSystem(posName, Teleport.savedPositions[posName], 
                                       Teleport.positionNumbers[posName] or 0, newName)
                    end
                end
            end
            
            -- Update filesystem
            fileSystem["DCIM/Supertool"]["group_" .. newName] = fileSystem["DCIM/Supertool"]["group_" .. groupName]
            fileSystem["DCIM/Supertool"]["group_" .. groupName] = nil
            saveGroupToFileSystem(newName, Teleport.groups[newName])
            
            print("Renamed group to: " .. newName)
            refreshPositionButtons()
        end)
    end)

    if DeleteGroupButton then
        DeleteGroupButton.MouseButton1Click:Connect(function()
            deleteGroupWithConfirmation(groupName, DeleteGroupButton)
        end)

        -- Hover effects for delete button
        DeleteGroupButton.MouseEnter:Connect(function()
            if DeleteGroupButton.Text ~= "Delete Group?" then
                DeleteGroupButton.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
            end
        end)

        DeleteGroupButton.MouseLeave:Connect(function()
            if DeleteGroupButton.Text ~= "Delete Group?" then
                DeleteGroupButton.BackgroundColor3 = Color3.fromRGB(100, 40, 40)
            end
        end)
    end

    -- Hover effects
    AutoToggleButton.MouseEnter:Connect(function()
        if groupData.autoTeleportEnabled then
            AutoToggleButton.BackgroundColor3 = Color3.fromRGB(80, 140, 80)
        else
            AutoToggleButton.BackgroundColor3 = Color3.fromRGB(140, 80, 80)
        end
    end)

    AutoToggleButton.MouseLeave:Connect(function()
        AutoToggleButton.BackgroundColor3 = groupData.autoTeleportEnabled and Color3.fromRGB(60, 120, 60) or Color3.fromRGB(120, 60, 60)
    end)

    RenameGroupButton.MouseEnter:Connect(function()
        RenameGroupButton.BackgroundColor3 = Color3.fromRGB(80, 100, 140)
    end)

    RenameGroupButton.MouseLeave:Connect(function()
        RenameGroupButton.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
    end)
end

-- Create position button with rename, delete, and numbering functionality
createPositionButton = function(positionName, cframe, groupName)
    if not PositionScrollFrame then
        warn("Cannot create position button: PositionScrollFrame not initialized")
        return
    end

    local ButtonFrame = Instance.new("Frame")
    ButtonFrame.Size = UDim2.new(1, -10, 0, 22)
    ButtonFrame.BackgroundTransparency = 1
    ButtonFrame.Parent = PositionScrollFrame

    local number = Teleport.positionNumbers[positionName] or 0
    local duplicates = getDuplicateNumbers(groupName)
    local isDuplicate = duplicates[positionName] or false
    local displayText = positionName
    
    if number > 0 then
        displayText = "[" .. number .. "] " .. positionName
    end

    -- Indent for group items
    local indentOffset = 20

    local NumberButton = Instance.new("TextButton")
    NumberButton.Size = UDim2.new(0, 25, 1, 0)
    NumberButton.Position = UDim2.new(0, indentOffset, 0, 0)
    NumberButton.BackgroundColor3 = isDuplicate and Color3.fromRGB(120, 40, 40) or Color3.fromRGB(40, 80, 120)
    NumberButton.BorderSizePixel = 0
    NumberButton.Text = number > 0 and tostring(number) or "#"
    NumberButton.TextColor3 = isDuplicate and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(255, 255, 255)
    NumberButton.TextSize = 8
    NumberButton.Font = Enum.Font.GothamBold
    NumberButton.Parent = ButtonFrame

    local TeleportButton = Instance.new("TextButton")
    TeleportButton.Size = UDim2.new(1, -115 - indentOffset, 1, 0)
    TeleportButton.Position = UDim2.new(0, 28 + indentOffset, 0, 0)
    TeleportButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    TeleportButton.BorderSizePixel = 0
    TeleportButton.Text = displayText
    TeleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    TeleportButton.TextSize = 9
    TeleportButton.Font = Enum.Font.Gotham
    TeleportButton.TextXAlignment = Enum.TextXAlignment.Left
    TeleportButton.Parent = ButtonFrame

    local RenameButton = Instance.new("TextButton")
    RenameButton.Size = UDim2.new(0, 32, 1, 0)
    RenameButton.Position = UDim2.new(1, -67, 0, 0)
    RenameButton.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
    RenameButton.BorderSizePixel = 0
    RenameButton.Text = "Ren"
    RenameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    RenameButton.TextSize = 8
    RenameButton.Font = Enum.Font.Gotham
    RenameButton.Parent = ButtonFrame

    local DeleteButton = Instance.new("TextButton")
    DeleteButton.Size = UDim2.new(0, 32, 1, 0)
    DeleteButton.Position = UDim2.new(1, -32, 0, 0)
    DeleteButton.BackgroundColor3 = Color3.fromRGB(100, 40, 40)
    DeleteButton.BorderSizePixel = 0
    DeleteButton.Text = "Del"
    DeleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    DeleteButton.TextSize = 8
    DeleteButton.Font = Enum.Font.Gotham
    DeleteButton.Parent = ButtonFrame

    -- Event connections
    NumberButton.MouseButton1Click:Connect(function()
        createNumberInputDialog(positionName, number, function(newNumber)
            Teleport.positionNumbers[positionName] = newNumber
            saveToFileSystem(positionName, cframe, newNumber, groupName)
            print("Set number " .. newNumber .. " for position: " .. positionName)
            refreshPositionButtons() -- Refresh to update display and check duplicates
        end)
    end)

    TeleportButton.MouseButton1Click:Connect(function()
        if safeTeleport(cframe) then
            print("Teleported to: " .. positionName)
        end
    end)

    RenameButton.MouseButton1Click:Connect(function()
        createRenameDialog(positionName, function(newName)
            -- Update position data
            Teleport.savedPositions[newName] = Teleport.savedPositions[positionName]
            Teleport.savedPositions[positionName] = nil
            
            -- Update number data
            Teleport.positionNumbers[newName] = Teleport.positionNumbers[positionName]
            Teleport.positionNumbers[positionName] = nil
            
            -- Update group assignment
            Teleport.positionGroups[newName] = Teleport.positionGroups[positionName]
            Teleport.positionGroups[positionName] = nil
            
            -- Update file system
            fileSystem["DCIM/Supertool"][newName] = fileSystem["DCIM/Supertool"][positionName]
            fileSystem["DCIM/Supertool"][positionName] = nil
            
            -- Save with number and group
            saveToFileSystem(newName, cframe, Teleport.positionNumbers[newName], groupName)
            
            print("Renamed position to: " .. newName)
            refreshPositionButtons() -- Refresh all buttons
        end)
    end)

    DeleteButton.MouseButton1Click:Connect(function()
        deletePositionWithConfirmation(positionName, DeleteButton)
    end)

    -- Hover effects
    NumberButton.MouseEnter:Connect(function()
        if not isDuplicate then
            NumberButton.BackgroundColor3 = Color3.fromRGB(60, 100, 140)
        end
    end)

    NumberButton.MouseLeave:Connect(function()
        NumberButton.BackgroundColor3 = isDuplicate and Color3.fromRGB(120, 40, 40) or Color3.fromRGB(40, 80, 120)
    end)

    TeleportButton.MouseEnter:Connect(function()
        TeleportButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    end)

    TeleportButton.MouseLeave:Connect(function()
        TeleportButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    end)

    RenameButton.MouseEnter:Connect(function()
        RenameButton.BackgroundColor3 = Color3.fromRGB(80, 100, 140)
    end)

    RenameButton.MouseLeave:Connect(function()
        RenameButton.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
    end)

    DeleteButton.MouseEnter:Connect(function()
        if DeleteButton.Text ~= "Delete?" then
            DeleteButton.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
        end
    end)

    DeleteButton.MouseLeave:Connect(function()
        if DeleteButton.Text ~= "Delete?" then
            DeleteButton.BackgroundColor3 = Color3.fromRGB(100, 40, 40)
        end
    end)
end

-- Refresh position buttons
refreshPositionButtons = function()
    if not PositionScrollFrame then
        warn("Cannot refresh position buttons: PositionScrollFrame not initialized")
        return
    end
    
    -- Clear existing UI elements
    for _, child in pairs(PositionScrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" then
            child:Destroy()
        end
    end
    
    ensureDefaultGroup()
    
    -- Create groups in sorted order
    local sortedGroups = {}
    for groupName in pairs(Teleport.groups) do
        table.insert(sortedGroups, groupName)
    end
    table.sort(sortedGroups, function(a, b)
        if a == "Default" then return true end
        if b == "Default" then return false end
        return a < b
    end)
    
    for _, groupName in ipairs(sortedGroups) do
        local groupData = Teleport.groups[groupName]
        createGroupHeader(groupName, groupData)
        
        if groupData.expanded then
            local positions = getPositionsByGroup(groupName)
            for _, position in ipairs(positions) do
                createPositionButton(position.name, position.cframe, groupName)
            end
        end
    end
    
    updateScrollCanvasSize()
end

-- Create new group
function Teleport.createGroup(groupName)
    if not groupName or groupName == "" then
        warn("Group name cannot be empty")
        return false
    end
    if Teleport.groups[groupName] then
        warn("Group already exists: " .. groupName)
        return false
    end
    
    Teleport.groups[groupName] = {
        name = groupName,
        expanded = true,
        autoTeleportEnabled = true
    }
    saveGroupToFileSystem(groupName, Teleport.groups[groupName])
    refreshPositionButtons()
    print("Created group: " .. groupName)
    return true
end

-- On character respawn
local function onCharacterAdded(character)
    if Teleport.autoTeleportActive then
        Teleport.autoTeleportPaused = true
        print("Auto teleport paused due to character respawn")
        if AutoStatusLabel then
            AutoStatusLabel.Text = "Auto teleport paused"
        end
    end
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
    if humanoidRootPart then
        wait(1)
        -- Only refresh UI, do not reset savedPositions or fileSystem
        refreshPositionButtons()
        if Teleport.autoTeleportActive and Teleport.autoTeleportPaused then
            Teleport.autoTeleportPaused = false
            print("Auto teleport resumed after respawn")
            -- Update status label back to normal
            if AutoStatusLabel then
                local positions = getOrderedPositions()
                if positions[Teleport.currentAutoIndex] then
                    local position = positions[Teleport.currentAutoIndex]
                    local number = Teleport.positionNumbers[position.name] or 0
                    local numberText = number > 0 and "#" .. number or ""
                    AutoStatusLabel.Text = "Auto: " .. Teleport.autoTeleportMode .. " - " .. position.name .. numberText
                end
            end
        end
        print("Character respawned, teleport UI updated")
    else
        warn("HumanoidRootPart not found after respawn")
    end
end

-- Save current position
function Teleport.saveCurrentPosition(groupName)
    local root = getRootPart()
    if not root then
        warn("Cannot save position: Character not found")
        return false
    end
    
    groupName = groupName or "Default"
    ensureDefaultGroup()
    
    local positionName = PositionInput and PositionInput.Text:gsub("^%s*(.-)%s*$", "%1") or ""
    if positionName == "" then
        positionName = "Position_" .. (os.time() % 10000) -- Use timestamp for uniqueness
    end
    
    -- Ensure unique name
    positionName = generateUniqueName(positionName)
    
    local currentCFrame = root.CFrame
    Teleport.savedPositions[positionName] = currentCFrame
    Teleport.positionNumbers[positionName] = 0 -- Default number
    Teleport.positionGroups[positionName] = groupName
    saveToFileSystem(positionName, currentCFrame, 0, groupName)
    
    if PositionInput then
        PositionInput.Text = ""
    end
    
    refreshPositionButtons()
    print("Position saved: " .. positionName .. " in group: " .. groupName)
    return true
end

-- Save freecam position
function Teleport.saveFreecamPosition(freecamPosition, groupName)
    if not freecamPosition then
        warn("Cannot save: No freecam position available")
        return false
    end
    
    groupName = groupName or "Default"
    ensureDefaultGroup()
    
    local positionName = PositionInput and PositionInput.Text:gsub("^%s*(.-)%s*$", "%1") or ""
    if positionName == "" then
        positionName = "Freecam_" .. (os.time() % 10000) -- Use timestamp for uniqueness
    end
    
    -- Ensure unique name
    positionName = generateUniqueName(positionName)
    
    local cframe = CFrame.new(freecamPosition)
    Teleport.savedPositions[positionName] = cframe
    Teleport.positionNumbers[positionName] = 0 -- Default number
    Teleport.positionGroups[positionName] = groupName
    saveToFileSystem(positionName, cframe, 0, groupName)
    
    if PositionInput then
        PositionInput.Text = ""
    end
    
    refreshPositionButtons()
    print("Saved freecam position: " .. positionName .. " in group: " .. groupName)
    return true
end

-- Load saved positions from filesystem
function Teleport.loadSavedPositions()
    -- Load groups first
    for itemName, data in pairs(fileSystem["DCIM/Supertool"]) do
        if data.type == "teleport_group" then
            local groupName = itemName:gsub("^group_", "")
            Teleport.groups[groupName] = loadGroupFromFileSystem(groupName) or {
                name = groupName,
                expanded = true,
                autoTeleportEnabled = true
            }
        end
    end
    
    -- Load positions
    for positionName, data in pairs(fileSystem["DCIM/Supertool"]) do
        if data.type == "teleport_position" then
            local cframe = loadFromFileSystem(positionName)
            if cframe then
                Teleport.savedPositions[positionName] = cframe
            end
        end
    end
    
    ensureDefaultGroup()
    refreshPositionButtons()
    
    local groupCount = 0
    for _ in pairs(Teleport.groups) do groupCount = groupCount + 1 end
    
    print("Loaded " .. #getOrderedPositions() .. " saved positions in " .. groupCount .. " groups")
end

-- Toggle position manager UI
function Teleport.togglePositionManager()
    if not PositionFrame then
        warn("Position Manager UI not initialized")
        return
    end
    Teleport.positionFrameVisible = not Teleport.positionFrameVisible
    PositionFrame.Visible = Teleport.positionFrameVisible
    if Teleport.positionFrameVisible then
        refreshPositionButtons()
        print("Position Manager opened")
    else
        print("Position Manager closed")
    end
end

-- Initialize UI elements
local function initUI()
    if not ScreenGui then
        warn("Cannot create Position Manager UI: ScreenGui not available")
        return
    end
    print("Creating Position Manager UI...")

    -- Position Frame
    PositionFrame = Instance.new("Frame")
    PositionFrame.Name = "PositionFrame"
    PositionFrame.Parent = ScreenGui
    PositionFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    PositionFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    PositionFrame.BorderSizePixel = 1
    PositionFrame.Position = UDim2.new(0.3, 0, 0.25, 0)
    PositionFrame.Size = UDim2.new(0, 320, 0, 400)
    PositionFrame.Visible = false
    PositionFrame.Active = true
    PositionFrame.Draggable = true

    -- Position Title
    local PositionTitle = Instance.new("TextLabel")
    PositionTitle.Name = "Title"
    PositionTitle.Parent = PositionFrame
    PositionTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    PositionTitle.BorderSizePixel = 0
    PositionTitle.Position = UDim2.new(0, 0, 0, 0)
    PositionTitle.Size = UDim2.new(1, 0, 0, 28)
    PositionTitle.Font = Enum.Font.Gotham
    PositionTitle.Text = "POSITION MANAGER"
    PositionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    PositionTitle.TextSize = 11

    -- Close Position Button
    local ClosePositionButton = Instance.new("TextButton")
    ClosePositionButton.Name = "CloseButton"
    ClosePositionButton.Parent = PositionFrame
    ClosePositionButton.BackgroundTransparency = 1
    ClosePositionButton.Position = UDim2.new(1, -25, 0, 3)
    ClosePositionButton.Size = UDim2.new(0, 22, 0, 22)
    ClosePositionButton.Font = Enum.Font.GothamBold
    ClosePositionButton.Text = "X"
    ClosePositionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClosePositionButton.TextSize = 11

    -- Position Input
    PositionInput = Instance.new("TextBox")
    PositionInput.Name = "PositionInput"
    PositionInput.Parent = PositionFrame
    PositionInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    PositionInput.BorderSizePixel = 0
    PositionInput.Position = UDim2.new(0, 8, 0, 35)
    PositionInput.Size = UDim2.new(1, -70, 0, 25)
    PositionInput.Font = Enum.Font.Gotham
    PositionInput.PlaceholderText = "Position name..."
    PositionInput.Text = ""
    PositionInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    PositionInput.TextSize = 10

    -- Save Position Button
    SavePositionButton = Instance.new("TextButton")
    SavePositionButton.Name = "SavePositionButton"
    SavePositionButton.Parent = PositionFrame
    SavePositionButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    SavePositionButton.BorderSizePixel = 0
    SavePositionButton.Position = UDim2.new(1, -55, 0, 35)
    SavePositionButton.Size = UDim2.new(0, 50, 0, 25)
    SavePositionButton.Font = Enum.Font.Gotham
    SavePositionButton.Text = "SAVE"
    SavePositionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SavePositionButton.TextSize = 9

    -- Group Input
    GroupInput = Instance.new("TextBox")
    GroupInput.Name = "GroupInput"
    GroupInput.Parent = PositionFrame
    GroupInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    GroupInput.BorderSizePixel = 0
    GroupInput.Position = UDim2.new(0, 8, 0, 68)
    GroupInput.Size = UDim2.new(1, -100, 0, 25)
    GroupInput.Font = Enum.Font.Gotham
    GroupInput.PlaceholderText = "Group name..."
    GroupInput.Text = ""
    GroupInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    GroupInput.TextSize = 10

    -- Create Group Button
    CreateGroupButton = Instance.new("TextButton")
    CreateGroupButton.Name = "CreateGroupButton"
    CreateGroupButton.Parent = PositionFrame
    CreateGroupButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    CreateGroupButton.BorderSizePixel = 0
    CreateGroupButton.Position = UDim2.new(1, -85, 0, 68)
    CreateGroupButton.Size = UDim2.new(0, 80, 0, 25)
    CreateGroupButton.Font = Enum.Font.Gotham
    CreateGroupButton.Text = "CREATE GROUP"
    CreateGroupButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CreateGroupButton.TextSize = 8

    -- Position ScrollFrame
    PositionScrollFrame = Instance.new("ScrollingFrame")
    PositionScrollFrame.Name = "PositionScrollFrame"
    PositionScrollFrame.Parent = PositionFrame
    PositionScrollFrame.BackgroundTransparency = 1
    PositionScrollFrame.Position = UDim2.new(0, 8, 0, 101)
    PositionScrollFrame.Size = UDim2.new(1, -16, 1, -168)
    PositionScrollFrame.ScrollBarThickness = 3
    PositionScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    PositionScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    PositionScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    PositionScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)