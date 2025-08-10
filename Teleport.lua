-- Teleport-related features for MinimalHackGUI by Fari Noveri
-- ENHANCED VERSION: Fixed duplicates, added rename/delete, improved UI, better scrolling

-- Dependencies: Passed from mainloader.lua
local Players, Workspace, ScreenGui, player, rootPart, settings

local Teleport = {}

-- Variables
Teleport.savedPositions = {}
Teleport.positionNumbers = {} -- Store manual numbering for positions
Teleport.positionFrameVisible = false
Teleport.autoTeleportActive = false
Teleport.autoTeleportMode = "once" -- "once" or "repeat"
Teleport.autoTeleportDelay = 2 -- seconds between teleports
Teleport.currentAutoIndex = 1
Teleport.autoTeleportCoroutine = nil

-- UI Elements
local PositionFrame, PositionScrollFrame, PositionLayout, PositionInput, SavePositionButton
local AutoTeleportFrame, AutoTeleportButton, AutoModeToggle, DelayInput, StopAutoButton

-- Mock file system
local fileSystem = { ["DCIM/Supertool"] = {} }

-- Get root part
local function getRootPart()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        return player.Character.HumanoidRootPart
    end
    warn("Cannot get root part: Character or HumanoidRootPart not found")
    return nil
end

-- Save to mock filesystem
local function saveToFileSystem(positionName, cframe, number)
    if not positionName or not cframe then
        warn("Cannot save to file system: Invalid positionName or cframe")
        return false
    end
    fileSystem["DCIM/Supertool"][positionName] = {
        x = cframe.X,
        y = cframe.Y,
        z = cframe.Z,
        orientation = {cframe:ToEulerAnglesXYZ()},
        number = number or 0
    }
    print("Saved to file system: " .. positionName)
    return true
end

-- Load from mock filesystem
local function loadFromFileSystem(positionName)
    local data = fileSystem["DCIM/Supertool"][positionName]
    if data then
        local rx, ry, rz = unpack(data.orientation)
        Teleport.positionNumbers[positionName] = data.number or 0 -- Load number
        return CFrame.new(data.x, data.y, data.z) * CFrame.Angles(rx, ry, rz)
    end
    warn("Cannot load from file system: Position " .. tostring(positionName) .. " not found")
    return nil
end

-- Get ordered positions (now based on manual numbering)
local function getOrderedPositions()
    local orderedPositions = {}
    for name, cframe in pairs(Teleport.savedPositions) do
        local number = Teleport.positionNumbers[name] or 0
        table.insert(orderedPositions, {name = name, cframe = cframe, number = number})
    end
    
    -- Sort by number first, then by name for positions with same number or 0
    table.sort(orderedPositions, function(a, b)
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
    
    return orderedPositions
end

-- Check for duplicate numbers
local function getDuplicateNumbers()
    local numberCount = {}
    local duplicates = {}
    
    for name, number in pairs(Teleport.positionNumbers) do
        if number > 0 then -- Only check numbered positions
            if numberCount[number] then
                table.insert(numberCount[number], name)
                if not duplicates[number] then
                    duplicates[number] = true
                end
            else
                numberCount[number] = {name}
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
local function createRenameDialog(oldName, onRename)
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
    RenameTitle.Text = "Rename Position"
    RenameTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    RenameTitle.TextSize = 12
    RenameTitle.TextXAlignment = Enum.TextXAlignment.Left

    local RenameInput = Instance.new("TextBox")
    RenameInput.Parent = RenameFrame
    RenameInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    RenameInput.BorderSizePixel = 0
    RenameInput.Position = UDim2.new(0, 10, 0, 30)
    RenameInput.Size = UDim2.new(1, -20, 0, 25)
    RenameInput.Font = Enum.Font.Gotham
    RenameInput.Text = oldName
    RenameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    RenameInput.TextSize = 11

    local ConfirmButton = Instance.new("TextButton")
    ConfirmButton.Parent = RenameFrame
    ConfirmButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    ConfirmButton.BorderSizePixel = 0
    ConfirmButton.Position = UDim2.new(0, 10, 0, 65)
    ConfirmButton.Size = UDim2.new(0.5, -15, 0, 25)
    ConfirmButton.Font = Enum.Font.Gotham
    ConfirmButton.Text = "Confirm"
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
        local newName = RenameInput.Text:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
        if newName ~= "" and newName ~= oldName then
            if positionExists(newName) then
                warn("Position name '" .. newName .. "' already exists!")
                return
            end
            onRename(newName)
        end
        RenameFrame:Destroy()
    end)

    CancelButton.MouseButton1Click:Connect(function()
        RenameFrame:Destroy()
    end)

    RenameInput:CaptureFocus()
    RenameInput.SelectionStart = 1
    RenameInput.CursorPosition = #RenameInput.Text + 1
end

-- Delete position with confirmation
local function deletePositionWithConfirmation(positionName, button)
    -- Simple confirmation by requiring double-click
    if button.Text == "Delete?" then
        Teleport.savedPositions[positionName] = nil
        Teleport.positionNumbers[positionName] = nil -- Remove number too
        fileSystem["DCIM/Supertool"][positionName] = nil
        button.Parent:Destroy()
        print("Deleted position: " .. positionName)
        updateScrollCanvasSize()
        -- Refresh all buttons to update duplicate highlighting
        refreshPositionButtons()
    else
        button.Text = "Delete?"
        button.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        wait(2)
        if button.Parent then
            button.Text = "Del"
            button.BackgroundColor3 = Color3.fromRGB(100, 40, 40)
        end
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
            return
        end
        repeat
            for i = Teleport.currentAutoIndex, #positions do
                if not Teleport.autoTeleportActive then return end
                local position = positions[i]
                if safeTeleport(position.cframe) then
                    print("Auto teleported to: " .. position.name .. " (" .. i .. "/" .. #positions .. ")")
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
    spawn(function()
        local success, err = coroutine.resume(Teleport.autoTeleportCoroutine)
        if not success then
            warn("Auto teleport error: " .. tostring(err))
            Teleport.autoTeleportActive = false
        end
    end)
    print("Auto teleport started in " .. Teleport.autoTeleportMode .. " mode")
end

-- Stop auto teleport
function Teleport.stopAutoTeleport()
    if not Teleport.autoTeleportActive then return end
    Teleport.autoTeleportActive = false
    Teleport.currentAutoIndex = 1
    Teleport.autoTeleportCoroutine = nil
    print("Auto teleport stopped")
end

-- Toggle auto mode
function Teleport.toggleAutoMode()
    Teleport.autoTeleportMode = Teleport.autoTeleportMode == "once" and "repeat" or "once"
    if AutoModeToggle then
        AutoModeToggle.Text = "Mode: " .. Teleport.autoTeleportMode
    end
    print("Auto teleport mode set to: " .. Teleport.autoTeleportMode)
    return Teleport.autoTeleportMode
end

-- Create position button with rename, delete, and numbering functionality
local function createPositionButton(positionName, cframe)
    if not PositionScrollFrame then
        warn("Cannot create position button: PositionScrollFrame not initialized")
        return
    end

    local ButtonFrame = Instance.new("Frame")
    ButtonFrame.Size = UDim2.new(1, -10, 0, 22)
    ButtonFrame.BackgroundTransparency = 1
    ButtonFrame.Parent = PositionScrollFrame

    local number = Teleport.positionNumbers[positionName] or 0
    local duplicates = getDuplicateNumbers()
    local isDuplicate = duplicates[positionName] or false
    local displayText = positionName
    
    if number > 0 then
        displayText = "[" .. number .. "] " .. positionName
    end

    local NumberButton = Instance.new("TextButton")
    NumberButton.Size = UDim2.new(0, 25, 1, 0)
    NumberButton.Position = UDim2.new(0, 0, 0, 0)
    NumberButton.BackgroundColor3 = isDuplicate and Color3.fromRGB(120, 40, 40) or Color3.fromRGB(40, 80, 120)
    NumberButton.BorderSizePixel = 0
    NumberButton.Text = number > 0 and tostring(number) or "#"
    NumberButton.TextColor3 = isDuplicate and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(255, 255, 255)
    NumberButton.TextSize = 8
    NumberButton.Font = Enum.Font.GothamBold
    NumberButton.Parent = ButtonFrame

    local TeleportButton = Instance.new("TextButton")
    TeleportButton.Size = UDim2.new(1, -95, 1, 0)
    TeleportButton.Position = UDim2.new(0, 28, 0, 0)
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
            saveToFileSystem(positionName, cframe, newNumber)
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
            
            -- Update file system
            fileSystem["DCIM/Supertool"][newName] = fileSystem["DCIM/Supertool"][positionName]
            fileSystem["DCIM/Supertool"][positionName] = nil
            
            -- Save with number
            saveToFileSystem(newName, cframe, Teleport.positionNumbers[newName])
            
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
local function refreshPositionButtons()
    if not PositionScrollFrame then
        warn("Cannot refresh position buttons: PositionScrollFrame not initialized")
        return
    end
    for _, child in pairs(PositionScrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" then
            child:Destroy()
        end
    end
    for positionName, cframe in pairs(Teleport.savedPositions) do
        createPositionButton(positionName, cframe)
    end
    updateScrollCanvasSize()
end

-- On character respawn
local function onCharacterAdded(character)
    if Teleport.autoTeleportActive then
        Teleport.stopAutoTeleport()
        print("Auto teleport stopped due to character respawn")
    end
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
    if humanoidRootPart then
        wait(1)
        refreshPositionButtons()
        print("Character respawned, teleport system updated")
    else
        warn("HumanoidRootPart not found after respawn")
    end
end

-- Save current position (FIXED)
function Teleport.saveCurrentPosition()
    local root = getRootPart()
    if not root then
        warn("Cannot save position: Character not found")
        return false
    end
    
    local positionName = PositionInput and PositionInput.Text:gsub("^%s*(.-)%s*$", "%1") or ""
    if positionName == "" then
        positionName = "Position_" .. (os.time() % 10000) -- Use timestamp for uniqueness
    end
    
    -- Ensure unique name
    positionName = generateUniqueName(positionName)
    
    local currentCFrame = root.CFrame
    Teleport.savedPositions[positionName] = currentCFrame
    Teleport.positionNumbers[positionName] = 0 -- Default number
    saveToFileSystem(positionName, currentCFrame, 0)
    createPositionButton(positionName, currentCFrame)
    
    if PositionInput then
        PositionInput.Text = ""
    end
    
    updateScrollCanvasSize()
    print("Position saved: " .. positionName)
    return true
end

-- Save freecam position (fixed duplicate prevention)
function Teleport.saveFreecamPosition(freecamPosition)
    if not freecamPosition then
        warn("Cannot save: No freecam position available")
        return false
    end
    
    local positionName = PositionInput and PositionInput.Text:gsub("^%s*(.-)%s*$", "%1") or ""
    if positionName == "" then
        positionName = "Freecam_" .. (os.time() % 10000) -- Use timestamp for uniqueness
    end
    
    -- Ensure unique name
    positionName = generateUniqueName(positionName)
    
    local cframe = CFrame.new(freecamPosition)
    Teleport.savedPositions[positionName] = cframe
    Teleport.positionNumbers[positionName] = 0 -- Default number
    saveToFileSystem(positionName, cframe, 0)
    createPositionButton(positionName, cframe)
    
    if PositionInput then
        PositionInput.Text = ""
    end
    
    updateScrollCanvasSize()
    print("Saved freecam position: " .. positionName)
    return true
end

-- Load saved positions
function Teleport.loadSavedPositions()
    for positionName in pairs(fileSystem["DCIM/Supertool"]) do
        local cframe = loadFromFileSystem(positionName)
        if cframe then
            Teleport.savedPositions[positionName] = cframe
        end
    end
    refreshPositionButtons()
    print("Loaded " .. #getOrderedPositions() .. " saved positions")
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

-- Create position manager UI (optimized size and layout)
function Teleport.createPositionManagerUI()
    if not ScreenGui then
        warn("Cannot create Position Manager UI: ScreenGui not available")
        return
    end
    print("Creating Position Manager UI...")

    PositionFrame = Instance.new("Frame")
    PositionFrame.Name = "PositionFrame"
    PositionFrame.Parent = ScreenGui
    PositionFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    PositionFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    PositionFrame.BorderSizePixel = 1
    PositionFrame.Position = UDim2.new(0.3, 0, 0.25, 0)
    PositionFrame.Size = UDim2.new(0, 300, 0, 320) -- Reduced size
    PositionFrame.Visible = false
    PositionFrame.Active = true
    PositionFrame.Draggable = true

    local PositionTitle = Instance.new("TextLabel")
    PositionTitle.Name = "Title"
    PositionTitle.Parent = PositionFrame
    PositionTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    PositionTitle.BorderSizePixel = 0
    PositionTitle.Position = UDim2.new(0, 0, 0, 0)
    PositionTitle.Size = UDim2.new(1, 0, 0, 28) -- Reduced height
    PositionTitle.Font = Enum.Font.Gotham
    PositionTitle.Text = "POSITION MANAGER"
    PositionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    PositionTitle.TextSize = 11

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

    PositionInput = Instance.new("TextBox")
    PositionInput.Name = "PositionInput"
    PositionInput.Parent = PositionFrame
    PositionInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    PositionInput.BorderSizePixel = 0
    PositionInput.Position = UDim2.new(0, 8, 0, 35)
    PositionInput.Size = UDim2.new(1, -70, 0, 25) -- Reduced height
    PositionInput.Font = Enum.Font.Gotham
    PositionInput.PlaceholderText = "Position name..."
    PositionInput.Text = ""
    PositionInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    PositionInput.TextSize = 10

    SavePositionButton = Instance.new("TextButton")
    SavePositionButton.Name = "SavePositionButton"
    SavePositionButton.Parent = PositionFrame
    SavePositionButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    SavePositionButton.BorderSizePixel = 0
    SavePositionButton.Position = UDim2.new(1, -55, 0, 35)
    SavePositionButton.Size = UDim2.new(0, 50, 0, 25) -- Reduced size
    SavePositionButton.Font = Enum.Font.Gotham
    SavePositionButton.Text = "SAVE"
    SavePositionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SavePositionButton.TextSize = 9

    PositionScrollFrame = Instance.new("ScrollingFrame")
    PositionScrollFrame.Name = "PositionScrollFrame"
    PositionScrollFrame.Parent = PositionFrame
    PositionScrollFrame.BackgroundTransparency = 1
    PositionScrollFrame.Position = UDim2.new(0, 8, 0, 68)
    PositionScrollFrame.Size = UDim2.new(1, -16, 1, -135) -- Adjusted for smaller frame
    PositionScrollFrame.ScrollBarThickness = 3
    PositionScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    PositionScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    PositionScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    PositionScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    PositionScrollFrame.BorderSizePixel = 0

    PositionLayout = Instance.new("UIListLayout")
    PositionLayout.Parent = PositionScrollFrame
    PositionLayout.Padding = UDim.new(0, 1)
    PositionLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PositionLayout.FillDirection = Enum.FillDirection.Vertical

    AutoTeleportFrame = Instance.new("Frame")
    AutoTeleportFrame.Name = "AutoTeleportFrame"
    AutoTeleportFrame.Parent = PositionFrame
    AutoTeleportFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    AutoTeleportFrame.BorderSizePixel = 0
    AutoTeleportFrame.Position = UDim2.new(0, 8, 1, -62)
    AutoTeleportFrame.Size = UDim2.new(1, -16, 0, 58) -- Reduced height

    local AutoTeleportTitle = Instance.new("TextLabel")
    AutoTeleportTitle.Name = "AutoTeleportTitle"
    AutoTeleportTitle.Parent = AutoTeleportFrame
    AutoTeleportTitle.BackgroundTransparency = 1
    AutoTeleportTitle.Position = UDim2.new(0, 0, 0, 0)
    AutoTeleportTitle.Size = UDim2.new(1, 0, 0, 15) -- Reduced height
    AutoTeleportTitle.Font = Enum.Font.Gotham
    AutoTeleportTitle.Text = "AUTO TELEPORT"
    AutoTeleportTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    AutoTeleportTitle.TextSize = 9

    AutoModeToggle = Instance.new("TextButton")
    AutoModeToggle.Name = "AutoModeToggle"
    AutoModeToggle.Parent = AutoTeleportFrame
    AutoModeToggle.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
    AutoModeToggle.BorderSizePixel = 0
    AutoModeToggle.Position = UDim2.new(0, 3, 0, 18)
    AutoModeToggle.Size = UDim2.new(0.5, -5, 0, 18) -- Reduced height
    AutoModeToggle.Font = Enum.Font.Gotham
    AutoModeToggle.Text = "Mode: " .. Teleport.autoTeleportMode
    AutoModeToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    AutoModeToggle.TextSize = 8

    DelayInput = Instance.new("TextBox")
    DelayInput.Name = "DelayInput"
    DelayInput.Parent = AutoTeleportFrame
    DelayInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    DelayInput.BorderSizePixel = 0
    DelayInput.Position = UDim2.new(0.5, 2, 0, 18)
    DelayInput.Size = UDim2.new(0.5, -5, 0, 18) -- Reduced height
    DelayInput.Font = Enum.Font.Gotham
    DelayInput.Text = tostring(Teleport.autoTeleportDelay)
    DelayInput.PlaceholderText = "Delay (s)"
    DelayInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    DelayInput.TextSize = 8

    AutoTeleportButton = Instance.new("TextButton")
    AutoTeleportButton.Name = "AutoTeleportButton"
    AutoTeleportButton.Parent = AutoTeleportFrame
    AutoTeleportButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    AutoTeleportButton.BorderSizePixel = 0
    AutoTeleportButton.Position = UDim2.new(0, 3, 0, 40)
    AutoTeleportButton.Size = UDim2.new(0.5, -5, 0, 15) -- Reduced height
    AutoTeleportButton.Font = Enum.Font.Gotham
    AutoTeleportButton.Text = "Start Auto"
    AutoTeleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    AutoTeleportButton.TextSize = 8

    StopAutoButton = Instance.new("TextButton")
    StopAutoButton.Name = "StopAutoButton"
    StopAutoButton.Parent = AutoTeleportFrame
    StopAutoButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
    StopAutoButton.BorderSizePixel = 0
    StopAutoButton.Position = UDim2.new(0.5, 2, 0, 40)
    StopAutoButton.Size = UDim2.new(0.5, -5, 0, 15) -- Reduced height
    StopAutoButton.Font = Enum.Font.Gotham
    StopAutoButton.Text = "Stop Auto"
    StopAutoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    StopAutoButton.TextSize = 8

    -- Event connections
    SavePositionButton.MouseButton1Click:Connect(function()
        Teleport.saveCurrentPosition()
    end)

    ClosePositionButton.MouseButton1Click:Connect(function()
        Teleport.togglePositionManager()
    end)

    AutoTeleportButton.MouseButton1Click:Connect(function()
        Teleport.startAutoTeleport()
    end)

    StopAutoButton.MouseButton1Click:Connect(function()
        Teleport.stopAutoTeleport()
    end)

    AutoModeToggle.MouseButton1Click:Connect(function()
        Teleport.toggleAutoMode()
    end)

    DelayInput.FocusLost:Connect(function(enterPressed)
        local newDelay = tonumber(DelayInput.Text)
        if newDelay and newDelay > 0 then
            Teleport.autoTeleportDelay = newDelay
            print("Auto teleport delay set to: " .. newDelay .. "s")
        else
            DelayInput.Text = tostring(Teleport.autoTeleportDelay)
        end
    end)

    PositionLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        updateScrollCanvasSize()
    end)

    print("Position Manager UI created successfully")
end

-- Initialize module
function Teleport.init(deps)
    print("Initializing Teleport module...")
    Players = deps.Players
    Workspace = deps.Workspace
    ScreenGui = deps.ScreenGui
    player = deps.player
    rootPart = deps.rootPart
    settings = deps.settings

    if not Players or not Workspace or not ScreenGui or not player then
        warn("Critical dependencies missing for Teleport module!")
        return false
    end

    Teleport.savedPositions = {}
    Teleport.positionNumbers = {} -- Initialize position numbers
    Teleport.positionFrameVisible = false
    player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then
        onCharacterAdded(player.Character)
    end

    local success, err = pcall(Teleport.createPositionManagerUI)
    if not success then
        warn("Failed to create Position Manager UI: " .. tostring(err))
        return false
    end

    Teleport.loadSavedPositions()
    print("Teleport module initialized successfully")
    return true
end

-- Quick teleport functions
function Teleport.teleportToSpawn()
    local spawnLocation = Workspace:FindFirstChild("SpawnLocation")
    if spawnLocation then
        if safeTeleport(spawnLocation.CFrame + Vector3.new(0, 5, 0)) then
            print("Teleported to spawn")
        end
    else
        warn("Spawn location not found")
    end
end

function Teleport.teleportToPosition(x, y, z)
    if safeTeleport(CFrame.new(x, y, z)) then
        print("Teleported to coordinates: " .. x .. ", " .. y .. ", " .. z)
    end
end

-- Load teleport buttons (updated with fixed freecam save)
function Teleport.loadTeleportButtons(createButton, selectedPlayer, freecamEnabled, freecamPosition, toggleFreecam)
    print("Loading Teleport buttons...")
    
    createButton("Position Manager", function()
        Teleport.togglePositionManager()
    end, "Teleport")
    
    createButton("TP to Freecam", function()
        if freecamEnabled and freecamPosition and toggleFreecam then
            toggleFreecam(false)
            safeTeleport(CFrame.new(freecamPosition))
            print("Teleported to freecam position")
        elseif freecamPosition then
            safeTeleport(CFrame.new(freecamPosition))
            print("Teleported to last freecam position")
        else
            warn("Use freecam first to set a position")
        end
    end, "Teleport")
    
    createButton("Save Freecam Pos", function()
        if freecamPosition then
            Teleport.saveFreecamPosition(freecamPosition)
        else
            warn("Cannot save: Freecam must be enabled to save position")
        end
    end, "Teleport")
    
    createButton("Save Current Pos", function()
        Teleport.saveCurrentPosition()
    end, "Teleport")
    
    print("Teleport buttons loaded successfully")
end

-- Reset states
function Teleport.resetStates()
    print("Resetting Teleport states...")
    Teleport.savedPositions = {}
    Teleport.positionFrameVisible = false
    fileSystem["DCIM/Supertool"] = {}
    if PositionFrame then
        PositionFrame.Visible = false
    end
    Teleport.stopAutoTeleport()
    print("Teleport states reset successfully")
end

return Teleport