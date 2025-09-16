-- Teleport-related features for MinimalHackGUI by Fari Noveri
-- ENHANCED VERSION: Added JSON file persistence, directional teleport buttons, scrollable UI

-- Dependencies: These must be passed from mainloader.lua
local Players, Workspace, ScreenGui, ScrollFrame, player, rootPart, settings

-- Initialize module
local Teleport = {}

-- Variables
Teleport.savedPositions = Teleport.savedPositions or {} -- Preserve existing positions
Teleport.positionNumbers = Teleport.positionNumbers or {} -- Preserve existing position numbers
Teleport.positionFrameVisible = false
Teleport.autoTeleportActive = false
Teleport.autoTeleportPaused = false -- New flag for pausing auto-teleport
Teleport.autoTeleportMode = "once" -- "once" or "repeat"
Teleport.autoTeleportDelay = 2 -- seconds between teleports
Teleport.currentAutoIndex = 1
Teleport.autoTeleportCoroutine = nil
Teleport.smoothTeleportEnabled = false
Teleport.smoothTeleportDuration = 0.5 -- seconds

-- UI Elements (to be initialized in initUI function)
local PositionFrame, PositionScrollFrame, PositionLayout, PositionInput, SavePositionButton
local AutoTeleportFrame, AutoTeleportButton, AutoModeToggle, DelayInput, StopAutoButton
local AutoStatusLabel -- New label for auto-teleport status
local SmoothToggle, DurationInput

-- File System Integration for KRNL (like utility.lua)
local HttpService = game:GetService("HttpService")
local TELEPORT_FOLDER_PATH = "Supertool/Teleport/"

-- Helper function untuk sanitize filename
local function sanitizeFileName(name)
    local sanitized = string.gsub(name, "[<>:\"/\\|?*]", "_")
    sanitized = string.gsub(sanitized, "^%s*(.-)%s*$", "%1")
    if sanitized == "" then
        sanitized = "unnamed_position"
    end
    return sanitized
end

-- Helper function untuk save position ke JSON file
local function saveToJSONFile(positionName, cframe, number)
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(positionName)
        local fileName = sanitizedName .. ".json"
        local filePath = TELEPORT_FOLDER_PATH .. fileName
        
        local jsonData = {
            name = positionName,
            type = "teleport_position",
            created = os.time(),
            modified = os.time(),
            version = "1.0",
            x = cframe.X,
            y = cframe.Y,
            z = cframe.Z,
            orientation = {cframe:ToEulerAnglesXYZ()},
            number = number or 0
        }
        
        local jsonString = HttpService:JSONEncode(jsonData)
        writefile(filePath, jsonString)
        
        print("[SUPERTOOL] Position saved: " .. filePath)
        return true
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to save position to JSON: " .. tostring(error))
        return false
    end
    return true
end

-- Helper function untuk load position dari JSON file
local function loadFromJSONFile(positionName)
    local success, result = pcall(function()
        local sanitizedName = sanitizeFileName(positionName)
        local fileName = sanitizedName .. ".json"
        local filePath = TELEPORT_FOLDER_PATH .. fileName
        
        if isfile(filePath) then
            local jsonString = readfile(filePath)
            local jsonData = HttpService:JSONDecode(jsonString)
            
            local rx, ry, rz = unpack(jsonData.orientation or {0, 0, 0})
            local cframe = CFrame.new(jsonData.x, jsonData.y, jsonData.z) * CFrame.Angles(rx, ry, rz)
            
            return {
                cframe = cframe,
                number = jsonData.number or 0,
                name = jsonData.name or positionName,
                created = jsonData.created,
                modified = jsonData.modified,
                version = jsonData.version or "1.0"
            }
        else
            return nil
        end
    end)
    
    if success then
        return result
    else
        warn("[SUPERTOOL] Failed to load position from JSON: " .. tostring(result))
        return nil
    end
end

-- Helper function untuk delete position dari JSON file
local function deleteFromJSONFile(positionName)
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(positionName)
        local fileName = sanitizedName .. ".json"
        local filePath = TELEPORT_FOLDER_PATH .. fileName
        
        if isfile(filePath) then
            delfile(filePath)
            print("[SUPERTOOL] Position deleted: " .. filePath)
            return true
        else
            return false
        end
    end)
    
    if success then
        return error
    else
        warn("[SUPERTOOL] Failed to delete position JSON: " .. tostring(error))
        return false
    end
end

-- Helper function untuk rename position di JSON file
local function renameInJSONFile(oldName, newName)
    local success, error = pcall(function()
        local oldData = loadFromJSONFile(oldName)
        if not oldData then
            return false
        end
        
        oldData.name = newName
        oldData.modified = os.time()
        
        if saveToJSONFile(newName, oldData.cframe, oldData.number) then
            deleteFromJSONFile(oldName)
            print("[SUPERTOOL] Position renamed: " .. oldName .. " -> " .. newName)
            return true
        else
            return false
        end
    end)
    
    if success then
        return error
    else
        warn("[SUPERTOOL] Failed to rename position: " .. tostring(error))
        return false
    end
end

-- Helper function untuk load semua positions dari folder
local function loadAllPositionsFromFolder()
    local success, error = pcall(function()
        if not isfolder(TELEPORT_FOLDER_PATH) then
            makefolder(TELEPORT_FOLDER_PATH)
            print("[SUPERTOOL] Created teleport folder: " .. TELEPORT_FOLDER_PATH)
        end
        
        local loadedPositions = {}
        local loadedNumbers = {}
        local files = listfiles(TELEPORT_FOLDER_PATH)
        
        for _, filePath in pairs(files) do
            if string.match(filePath, "%.json$") then
                local fileName = string.match(filePath, "([^/\\]+)%.json$")
                if fileName then
                    local positionData = loadFromJSONFile(fileName)
                    if positionData then
                        local originalName = positionData.name or fileName
                        loadedPositions[originalName] = positionData.cframe
                        loadedNumbers[originalName] = positionData.number or 0
                        print("[SUPERTOOL] Loaded position: " .. originalName)
                    end
                end
            end
        end
        
        return loadedPositions, loadedNumbers
    end)
    
    if success then
        return error or {}, {}
    else
        warn("[SUPERTOOL] Failed to load positions from folder: " .. tostring(error))
        return {}, {}
    end
end

-- Mock file system for backward compatibility (now syncs with JSON)
local fileSystem = {
    ["Supertool/Teleport"] = {}
}

-- Helper function to ensure Supertool/Teleport exists (backward compatibility)
local function ensureFileSystem()
    if not fileSystem["Supertool"] then
        fileSystem["Supertool"] = {}
    end
    if not fileSystem["Supertool/Teleport"] then
        fileSystem["Supertool/Teleport"] = {}
    end
end

-- Helper function to save position to file system (now syncs with JSON)
local function saveToFileSystem(positionName, cframe, number)
    ensureFileSystem()
    fileSystem["Supertool/Teleport"][positionName] = {
        type = "teleport_position",
        x = cframe.X,
        y = cframe.Y,
        z = cframe.Z,
        orientation = {cframe:ToEulerAnglesXYZ()},
        number = number or 0
    }
    
    saveToJSONFile(positionName, cframe, number)
    return true
end

-- Helper function to load position from file system (prioritizes JSON)
local function loadFromFileSystem(positionName)
    local jsonData = loadFromJSONFile(positionName)
    if jsonData then
        Teleport.positionNumbers[positionName] = jsonData.number
        return jsonData.cframe
    end
    
    ensureFileSystem()
    local data = fileSystem["Supertool/Teleport"][positionName]
    if data and data.type == "teleport_position" then
        local rx, ry, rz = unpack(data.orientation)
        Teleport.positionNumbers[positionName] = data.number or 0
        return CFrame.new(data.x, data.y, data.z) * CFrame.Angles(rx, ry, rz)
    end
    
    return nil
end

-- Helper function to delete position from file system (syncs with JSON)
local function deleteFromFileSystem(positionName)
    ensureFileSystem()
    local memoryDeleted = false
    if fileSystem["Supertool/Teleport"][positionName] then
        fileSystem["Supertool/Teleport"][positionName] = nil
        memoryDeleted = true
    end
    
    local jsonDeleted = deleteFromJSONFile(positionName)
    
    return memoryDeleted or jsonDeleted
end

-- Helper function to rename position in file system (syncs with JSON)
local function renameInFileSystem(oldName, newName)
    ensureFileSystem()
    local memoryRenamed = false
    
    if fileSystem["Supertool/Teleport"][oldName] and newName ~= "" then
        fileSystem["Supertool/Teleport"][newName] = fileSystem["Supertool/Teleport"][oldName]
        fileSystem["Supertool/Teleport"][oldName] = nil
        memoryRenamed = true
    end
    
    local jsonRenamed = renameInJSONFile(oldName, newName)
    
    return memoryRenamed or jsonRenamed
end

-- Function untuk sync positions dari JSON ke memory pada startup
local function syncPositionsFromJSON()
    local jsonPositions, jsonNumbers = loadAllPositionsFromFolder()
    for positionName, cframe in pairs(jsonPositions) do
        Teleport.savedPositions[positionName] = cframe
        Teleport.positionNumbers[positionName] = jsonNumbers[positionName] or 0
        fileSystem["Supertool/Teleport"][positionName] = {
            type = "teleport_position",
            x = cframe.X,
            y = cframe.Y,
            z = cframe.Z,
            orientation = {cframe:ToEulerAnglesXYZ()},
            number = jsonNumbers[positionName] or 0
        }
    end
    print("[SUPERTOOL] Synced " .. table.maxn(jsonPositions) .. " positions from JSON files")
end

-- Get root part
local function getRootPart()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        return player.Character.HumanoidRootPart
    end
    warn("Cannot get root part: Character or HumanoidRootPart not found")
    return nil
end

-- Get ordered positions (now based on manual numbering)
local function getOrderedPositions()
    local orderedPositions = {}
    for name, cframe in pairs(Teleport.savedPositions) do
        local number = Teleport.positionNumbers[name] or 0
        table.insert(orderedPositions, {name = name, cframe = cframe, number = number})
    end
    
    table.sort(orderedPositions, function(a, b)
        if a.number == 0 and b.number == 0 then
            return a.name < b.name
        elseif a.number == 0 then
            return false
        elseif b.number == 0 then
            return true
        elseif a.number == b.number then
            return a.name < b.name
        else
            return a.number < b.number
        end
    end)
    
    return orderedPositions
end

-- Check for duplicate numbers
local function getDuplicateNumbers()
    local numberCount = {}
    local duplicates = {}
    
    for name, number in pairs(Teleport.positionNumbers) do
        if number > 0 then
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
    if Teleport.smoothTeleportEnabled then
        local TweenService = game:GetService("TweenService")
        local tweenInfo = TweenInfo.new(Teleport.smoothTeleportDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
        local tween = TweenService:Create(root, tweenInfo, {CFrame = targetCFrame})
        tween:Play()
        tween.Completed:Wait()
        print("Smooth teleported to CFrame: " .. tostring(targetCFrame))
    else
        root.CFrame = targetCFrame
        print("Teleported to CFrame: " .. tostring(targetCFrame))
    end
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
    if button.Text == "Delete?" then
        Teleport.savedPositions[positionName] = nil
        Teleport.positionNumbers[positionName] = nil
        deleteFromFileSystem(positionName)
        button.Parent:Destroy()
        print("Deleted position: " .. positionName)
        updateScrollCanvasSize()
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
                while Teleport.autoTeleportPaused do
                    wait(0.1)
                end
                local position = positions[i]
                if safeTeleport(position.cframe) then
                    print("Auto teleported to: " .. position.name .. " (" .. i .. "/" .. #positions .. ")")
                    if AutoStatusLabel then
                        local number = Teleport.positionNumbers[position.name] or 0
                        local numberText = number > 0 and "#" .. number or ""
                        AutoStatusLabel.Text = "Auto teleport: " .. position.name .. numberText .. " (" .. Teleport.autoTeleportMode .. ")"
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
    if AutoStatusLabel then
        local positions = getOrderedPositions()
        local position = positions[1]
        local number = Teleport.positionNumbers[position.name] or 0
        local numberText = number > 0 and "#" .. number or ""
        AutoStatusLabel.Text = "Auto teleport: " .. position.name .. numberText .. " (" .. Teleport.autoTeleportMode .. ")"
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
    if Teleport.autoTeleportActive and AutoStatusLabel then
        local positions = getOrderedPositions()
        if positions[Teleport.currentAutoIndex] then
            local position = positions[Teleport.currentAutoIndex]
            local number = Teleport.positionNumbers[position.name] or 0
            local numberText = number > 0 and "#" .. number or ""
            AutoStatusLabel.Text = "Auto teleport: " .. position.name .. numberText .. " (" .. Teleport.autoTeleportMode .. ")"
        end
    end
    print("Auto teleport mode set to: " .. Teleport.autoTeleportMode)
    return Teleport.autoTeleportMode
end

-- Create position button with rename, delete, and numbering functionality
createPositionButton = function(positionName, cframe)
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

    NumberButton.MouseButton1Click:Connect(function()
        createNumberInputDialog(positionName, number, function(newNumber)
            Teleport.positionNumbers[positionName] = newNumber
            saveToFileSystem(positionName, cframe, newNumber)
            print("Set number " .. newNumber .. " for position: " .. positionName)
            refreshPositionButtons()
        end)
    end)

    TeleportButton.MouseButton1Click:Connect(function()
        if safeTeleport(cframe) then
            print("Teleported to: " .. positionName)
        end
    end)

    RenameButton.MouseButton1Click:Connect(function()
        createRenameDialog(positionName, function(newName)
            Teleport.savedPositions[newName] = Teleport.savedPositions[positionName]
            Teleport.savedPositions[positionName] = nil
            Teleport.positionNumbers[newName] = Teleport.positionNumbers[positionName]
            Teleport.positionNumbers[positionName] = nil
            renameInFileSystem(positionName, newName)
            print("Renamed position to: " .. newName)
            refreshPositionButtons()
        end)
    end)

    DeleteButton.MouseButton1Click:Connect(function()
        deletePositionWithConfirmation(positionName, DeleteButton)
    end)

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
    for _, child in pairs(PositionScrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" then
            child:Destroy()
        end
    end
    
    local itemCount = 0
    
    local infoFrame = Instance.new("Frame")
    infoFrame.Name = "InfoFrame"
    infoFrame.Parent = PositionScrollFrame
    infoFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    infoFrame.BorderSizePixel = 0
    infoFrame.Size = UDim2.new(1, -5, 0, 20)
    infoFrame.LayoutOrder = -1
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Parent = infoFrame
    infoLabel.BackgroundTransparency = 1
    infoLabel.Size = UDim2.new(1, 0, 1, 0)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Text = "JSON Sync: " .. TELEPORT_FOLDER_PATH .. " (" .. table.maxn(Teleport.savedPositions) .. " positions)"
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    infoLabel.TextSize = 7
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    for positionName, cframe in pairs(Teleport.savedPositions) do
        createPositionButton(positionName, cframe)
        itemCount = itemCount + 1
    end
    
    if itemCount > 0 then
        local refreshFrame = Instance.new("Frame")
        refreshFrame.Name = "RefreshFrame"
        refreshFrame.Parent = PositionScrollFrame
        refreshFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 40)
        refreshFrame.BorderSizePixel = 0
        refreshFrame.Size = UDim2.new(1, -5, 0, 25)
        refreshFrame.LayoutOrder = itemCount + 1
        
        local refreshButton = Instance.new("TextButton")
        refreshButton.Parent = refreshFrame
        refreshButton.BackgroundColor3 = Color3.fromRGB(80, 80, 40)
        refreshButton.BorderSizePixel = 0
        refreshButton.Position = UDim2.new(0, 5, 0, 2)
        refreshButton.Size = UDim2.new(0, 80, 0, 20)
        refreshButton.Font = Enum.Font.Gotham
        refreshButton.Text = "🔄 REFRESH"
        refreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        refreshButton.TextSize = 7
        
        local syncAllButton = Instance.new("TextButton")
        syncAllButton.Parent = refreshFrame
        syncAllButton.BackgroundColor3 = Color3.fromRGB(40, 80, 80)
        syncAllButton.BorderSizePixel = 0
        syncAllButton.Position = UDim2.new(0, 90, 0, 2)
        syncAllButton.Size = UDim2.new(0, 80, 0, 20)
        syncAllButton.Font = Enum.Font.Gotham
        syncAllButton.Text = "💾 SYNC ALL"
        syncAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        syncAllButton.TextSize = 7
        
        refreshButton.MouseButton1Click:Connect(function()
            syncPositionsFromJSON()
            refreshPositionButtons()
        end)
        
        syncAllButton.MouseButton1Click:Connect(function()
            local count = 0
            for name, cframe in pairs(Teleport.savedPositions) do
                local number = Teleport.positionNumbers[name] or 0
                saveToJSONFile(name, cframe, number)
                count = count + 1
            end
            print("[SUPERTOOL] Synced " .. count .. " positions to JSON files")
        end)
    end
    
    updateScrollCanvasSize()
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
        refreshPositionButtons()
        if Teleport.autoTeleportActive and Teleport.autoTeleportPaused then
            Teleport.autoTeleportPaused = false
            print("Auto teleport resumed after respawn")
            if AutoStatusLabel then
                local positions = getOrderedPositions()
                if positions[Teleport.currentAutoIndex] then
                    local position = positions[Teleport.currentAutoIndex]
                    local number = Teleport.positionNumbers[position.name] or 0
                    local numberText = number > 0 and "#" .. number or ""
                    AutoStatusLabel.Text = "Auto teleport: " .. position.name .. numberText .. " (" .. Teleport.autoTeleportMode .. ")"
                end
            end
        end
        print("Character respawned, teleport UI updated")
    else
        warn("HumanoidRootPart not found after respawn")
    end
end

-- Save current position
function Teleport.saveCurrentPosition()
    local root = getRootPart()
    if not root then
        warn("Cannot save position: Character not found")
        return false
    end
    
    local positionName = PositionInput and PositionInput.Text:gsub("^%s*(.-)%s*$", "%1") or ""
    if positionName == "" then
        positionName = "Position_" .. (os.time() % 10000)
    end
    
    positionName = generateUniqueName(positionName)
    
    local currentCFrame = root.CFrame
    Teleport.savedPositions[positionName] = currentCFrame
    Teleport.positionNumbers[positionName] = 0
    saveToFileSystem(positionName, currentCFrame, 0)
    createPositionButton(positionName, currentCFrame)
    
    if PositionInput then
        PositionInput.Text = ""
    end
    
    updateScrollCanvasSize()
    print("Position saved: " .. positionName)
    return true
end

-- Save freecam position
function Teleport.saveFreecamPosition(freecamPosition)
    if not freecamPosition then
        warn("Cannot save: No freecam position available")
        return false
    end
    
    local positionName = PositionInput and PositionInput.Text:gsub("^%s*(.-)%s*$", "%1") or ""
    if positionName == "" then
        positionName = "Freecam_" .. (os.time() % 10000)
    end
    
    positionName = generateUniqueName(positionName)
    
    local cframe = CFrame.new(freecamPosition)
    Teleport.savedPositions[positionName] = cframe
    Teleport.positionNumbers[positionName] = 0
    saveToFileSystem(positionName, cframe, 0)
    createPositionButton(positionName, cframe)
    
    if PositionInput then
        PositionInput.Text = ""
    end
    
    updateScrollCanvasSize()
    print("Saved freecam position: " .. positionName)
    return true
end

-- Load saved positions from filesystem
function Teleport.loadSavedPositions()
    syncPositionsFromJSON()
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

-- Directional teleport functions
function Teleport.teleportForward(distance)
    local root = getRootPart()
    if not root then
        warn("Cannot teleport: Character not found")
        return
    end
    local currentCFrame = root.CFrame
    local forwardVector = currentCFrame.LookVector * (distance or 10)
    safeTeleport(currentCFrame + forwardVector)
    print("Teleported forward by " .. (distance or 10) .. " units")
end

function Teleport.teleportBackward(distance)
    local root = getRootPart()
    if not root then
        warn("Cannot teleport: Character not found")
        return
    end
    local currentCFrame = root.CFrame
    local backwardVector = -currentCFrame.LookVector * (distance or 10)
    safeTeleport(currentCFrame + backwardVector)
    print("Teleported backward by " .. (distance or 10) .. " units")
end

function Teleport.teleportRight(distance)
    local root = getRootPart()
    if not root then
        warn("Cannot teleport: Character not found")
        return
    end
    local currentCFrame = root.CFrame
    local rightVector = currentCFrame.RightVector * (distance or 10)
    safeTeleport(currentCFrame + rightVector)
    print("Teleported right by " .. (distance or 10) .. " units")
end

function Teleport.teleportLeft(distance)
    local root = getRootPart()
    if not root then
        warn("Cannot teleport: Character not found")
        return
    end
    local currentCFrame = root.CFrame
    local leftVector = -currentCFrame.RightVector * (distance or 10)
    safeTeleport(currentCFrame + leftVector)
    print("Teleported left by " .. (distance or 10) .. " units")
end

function Teleport.teleportDown(distance)
    local root = getRootPart()
    if not root then
        warn("Cannot teleport: Character not found")
        return
    end
    local currentCFrame = root.CFrame
    local downVector = -currentCFrame.UpVector * (distance or 10)
    safeTeleport(currentCFrame + downVector)
    print("Teleported down by " .. (distance or 10) .. " units")
end

-- Function to create buttons for Teleport features
function Teleport.loadTeleportButtons(createButton, selectedPlayer, freecamEnabled, freecamPosition, toggleFreecam)
    createButton("Position Manager", function()
        Teleport.togglePositionManager()
    end)
    
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
    end)
    
    createButton("Save Freecam Pos", function()
        if freecamPosition then
            Teleport.saveFreecamPosition(freecamPosition)
        else
            warn("Cannot save: Freecam must be enabled to save position")
        end
    end)
    
    createButton("Save Current Pos", function()
        Teleport.saveCurrentPosition()
    end)
    
    createButton("TP to Spawn", function()
        Teleport.teleportToSpawn()
    end)
    
    createButton("TP Forward", function()
        Teleport.teleportForward()
    end)
    
    createButton("TP Backward", function()
        Teleport.teleportBackward()
    end)
    
    createButton("TP Right", function()
        Teleport.teleportRight()
    end)
    
    createButton("TP Left", function()
        Teleport.teleportLeft()
    end)
    
    createButton("TP Down", function()
        Teleport.teleportDown()
    end)
end

-- Function to reset Teleport states
function Teleport.resetStates()
    Teleport.positionFrameVisible = false
    if PositionFrame then
        PositionFrame.Visible = false
    end
    Teleport.stopAutoTeleport()
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

-- Function to set dependencies and initialize UI
function Teleport.init(deps)
    ScreenGui = deps.ScreenGui
    ScrollFrame = deps.ScrollFrame
    Players = deps.Players
    Workspace = deps.Workspace
    player = deps.player
    rootPart = deps.rootPart
    settings = deps.settings

    if not Players or not Workspace or not ScreenGui or not player then
        warn("Critical dependencies missing for Teleport module!")
        return false
    end

    Teleport.savedPositions = Teleport.savedPositions or {}
    Teleport.positionNumbers = Teleport.positionNumbers or {}
    Teleport.positionFrameVisible = false
    
    if not isfolder(TELEPORT_FOLDER_PATH) then
        makefolder(TELEPORT_FOLDER_PATH)
        print("[SUPERTOOL] Created teleport folder: " .. TELEPORT_FOLDER_PATH)
    end
    
    ensureFileSystem()
    
    syncPositionsFromJSON()
    
    for positionName, data in pairs(fileSystem["Supertool/Teleport"]) do
        if data.type == "teleport_position" and not Teleport.savedPositions[positionName] then
            local cframe = loadFromFileSystem(positionName)
            if cframe then
                Teleport.savedPositions[positionName] = cframe
                saveToJSONFile(positionName, cframe, Teleport.positionNumbers[positionName] or 0)
            end
        end
    end
    
    player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then
        onCharacterAdded(player.Character)
    end

    -- Initialize UI elements
    local function initUI()
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
        PositionFrame.Size = UDim2.new(0, 300, 0, 350)
        PositionFrame.Visible = false
        PositionFrame.Active = true
        PositionFrame.Draggable = true

        local PositionTitle = Instance.new("TextLabel")
        PositionTitle.Name = "Title"
        PositionTitle.Parent = PositionFrame
        PositionTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        PositionTitle.BorderSizePixel = 0
        PositionTitle.Position = UDim2.new(0, 0, 0, 0)
        PositionTitle.Size = UDim2.new(1, 0, 0, 28)
        PositionTitle.Font = Enum.Font.Gotham
        PositionTitle.Text = "POSITION MANAGER - JSON SYNC"
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
        PositionInput.Size = UDim2.new(1, -70, 0, 25)
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
        SavePositionButton.Size = UDim2.new(0, 50, 0, 25)
        SavePositionButton.Font = Enum.Font.Gotham
        SavePositionButton.Text = "SAVE"
        SavePositionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        SavePositionButton.TextSize = 9

        SmoothToggle = Instance.new("TextButton")
        SmoothToggle.Name = "SmoothToggle"
        SmoothToggle.Parent = PositionFrame
        SmoothToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        SmoothToggle.BorderSizePixel = 0
        SmoothToggle.Position = UDim2.new(0, 8, 0, 65)
        SmoothToggle.Size = UDim2.new(0.5, -10, 0, 25)
        SmoothToggle.Font = Enum.Font.Gotham
        SmoothToggle.Text = "Smooth TP: " .. (Teleport.smoothTeleportEnabled and "ON" or "OFF")
        SmoothToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
        SmoothToggle.TextSize = 9

        DurationInput = Instance.new("TextBox")
        DurationInput.Name = "DurationInput"
        DurationInput.Parent = PositionFrame
        DurationInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        DurationInput.BorderSizePixel = 0
        DurationInput.Position = UDim2.new(0.5, 2, 0, 65)
        DurationInput.Size = UDim2.new(0.5, -10, 0, 25)
        DurationInput.Font = Enum.Font.Gotham
        DurationInput.Text = tostring(Teleport.smoothTeleportDuration)
        DurationInput.PlaceholderText = "Duration (s)"
        DurationInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        DurationInput.TextSize = 9

        PositionScrollFrame = Instance.new("ScrollingFrame")
        PositionScrollFrame.Name = "PositionScrollFrame"
        PositionScrollFrame.Parent = PositionFrame
        PositionScrollFrame.BackgroundTransparency = 1
        PositionScrollFrame.Position = UDim2.new(0, 8, 0, 95)
        PositionScrollFrame.Size = UDim2.new(1, -16, 1, -165)
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
        AutoTeleportFrame.Size = UDim2.new(1, -16, 0, 58)

        local AutoTeleportTitle = Instance.new("TextLabel")
        AutoTeleportTitle.Name = "AutoTeleportTitle"
        AutoTeleportTitle.Parent = AutoTeleportFrame
        AutoTeleportTitle.BackgroundTransparency = 1
        AutoTeleportTitle.Position = UDim2.new(0, 0, 0, 0)
        AutoTeleportTitle.Size = UDim2.new(1, 0, 0, 15)
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
        AutoModeToggle.Size = UDim2.new(0.5, -5, 0, 18)
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
        DelayInput.Size = UDim2.new(0.5, -5, 0, 18)
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
        AutoTeleportButton.Size = UDim2.new(0.5, -5, 0, 15)
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
        StopAutoButton.Size = UDim2.new(0.5, -5, 0, 15)
        StopAutoButton.Font = Enum.Font.Gotham
        StopAutoButton.Text = "Stop Auto"
        StopAutoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        StopAutoButton.TextSize = 8

        AutoStatusLabel = Instance.new("TextLabel")
        AutoStatusLabel.Name = "AutoStatusLabel"
        AutoStatusLabel.Parent = ScreenGui
        AutoStatusLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        AutoStatusLabel.BorderColor3 = Color3.fromRGB(60, 60, 60)
        AutoStatusLabel.BorderSizePixel = 1
        AutoStatusLabel.Position = UDim2.new(1, -250, 0, 35)
        AutoStatusLabel.Size = UDim2.new(0, 240, 0, 20)
        AutoStatusLabel.Font = Enum.Font.Gotham
        AutoStatusLabel.Text = ""
        AutoStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        AutoStatusLabel.TextSize = 8
        AutoStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
        AutoStatusLabel.Visible = false

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

        SmoothToggle.MouseButton1Click:Connect(function()
            Teleport.smoothTeleportEnabled = not Teleport.smoothTeleportEnabled
            SmoothToggle.Text = "Smooth TP: " .. (Teleport.smoothTeleportEnabled and "ON" or "OFF")
            SmoothToggle.BackgroundColor3 = Teleport.smoothTeleportEnabled and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
            print("Smooth teleport " .. (Teleport.smoothTeleportEnabled and "enabled" or "disabled"))
        end)

        DurationInput.FocusLost:Connect(function(enterPressed)
            local newDuration = tonumber(DurationInput.Text)
            if newDuration and newDuration > 0 then
                Teleport.smoothTeleportDuration = newDuration
                print("Smooth teleport duration set to: " .. newDuration .. "s")
            else
                DurationInput.Text = tostring(Teleport.smoothTeleportDuration)
            end
        end)

        PositionLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            updateScrollCanvasSize()
        end)

        print("Position Manager UI created successfully")
    end
    
    initUI()
    
    Teleport.loadSavedPositions()
    print("[SUPERTOOL] Teleport module initialized with JSON sync to: " .. TELEPORT_FOLDER_PATH)
    return true
end

return Teleport