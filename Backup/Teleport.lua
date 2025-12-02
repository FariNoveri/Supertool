-- Teleport-related features for MinimalHackGUI by Fari Noveri
-- ENHANCED VERSION: Added JSON file persistence, directional teleport buttons, scrollable UI

if _G.Teleport then
    return _G.Teleport
end

-- Dependencies: These must be passed from mainloader.lua
local Players, Workspace, ScreenGui, ScrollFrame, player, rootPart, settings

-- Initialize module
local Teleport = {}

-- Variables
Teleport.positions = Teleport.positions or {} -- {name: {cframe, number, created}}
Teleport.positionLabels = Teleport.positionLabels or {} -- New: Table for position labels in the world
Teleport.labelsVisible = true -- New: Toggle for showing/hiding labels
Teleport.positionFrameVisible = false
Teleport.autoTeleportActive = false
Teleport.autoTeleportPaused = false -- New flag for pausing auto-teleport
Teleport.autoTeleportMode = "once" -- "once" or "repeat"
Teleport.autoTeleportDelay = 2 -- seconds between teleports
Teleport.currentAutoIndex = 1
Teleport.autoTeleportCoroutine = nil
Teleport.smoothTeleportEnabled = true
Teleport.smoothTeleportSpeed = 100 -- studs per second
Teleport.doubleClickTeleportEnabled = false -- New: Toggle for double-click TP to mouse
Teleport.lastClickTime = 0
Teleport.doubleClickThreshold = 0.5 -- seconds for double click
Teleport.undoStack = {} -- New: Undo stack for directional and double-click teleports
Teleport.initialized = false
Teleport.sortMode = "order" -- "alpha", "order", "time"
Teleport.newestPosition = nil

-- UI Elements (to be initialized in initUI function)
local PositionFrame, PositionScrollFrame, PositionLayout, PositionInput, SavePositionButton
local AutoTeleportFrame, AutoTeleportButton, AutoModeToggle, DelayInput, StopAutoButton
local AutoStatusLabel -- New label for auto-teleport status
local SmoothToggle, SpeedInput
local CoordInputX, CoordInputY, CoordInputZ, TeleportToCoordButton, SaveCoordButton
local LabelToggle -- New: Toggle for labels visibility
local SortModeButton, DeleteAllButton, PrefixInput, AddPrefixButton

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
local function saveToJSONFile(positionName, cframe, number, created)
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(positionName)
        local fileName = sanitizedName .. ".json"
        local filePath = TELEPORT_FOLDER_PATH .. fileName
        
        local jsonData = {
            name = positionName,
            type = "teleport_position",
            created = created or os.time(),
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
                created = jsonData.created or os.time(),
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
        
        if saveToJSONFile(newName, oldData.cframe, oldData.number, oldData.created) then
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
        local files = listfiles(TELEPORT_FOLDER_PATH)
        
        for _, filePath in pairs(files) do
            if string.match(filePath, "%.json$") then
                local fileName = string.match(filePath, "([^/\\]+)%.json$")
                if fileName then
                    local positionData = loadFromJSONFile(fileName)
                    if positionData then
                        local originalName = positionData.name or fileName
                        loadedPositions[originalName] = positionData
                        print("[SUPERTOOL] Loaded position: " .. originalName)
                    end
                end
            end
        end
        
        return loadedPositions
    end)
    
    if success then
        return error or {}
    else
        warn("[SUPERTOOL] Failed to load positions from folder: " .. tostring(error))
        return {}
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
local function saveToFileSystem(positionName, cframe, number, created)
    ensureFileSystem()
    fileSystem["Supertool/Teleport"][positionName] = {
        type = "teleport_position",
        x = cframe.X,
        y = cframe.Y,
        z = cframe.Z,
        orientation = {cframe:ToEulerAnglesXYZ()},
        number = number or 0,
        created = created or os.time()
    }
    
    saveToJSONFile(positionName, cframe, number, created)
    return true
end

-- Helper function to load position from file system (prioritizes JSON)
local function loadFromFileSystem(positionName)
    local jsonData = loadFromJSONFile(positionName)
    if jsonData then
        return jsonData.cframe, jsonData.number, jsonData.created
    end
    
    ensureFileSystem()
    local data = fileSystem["Supertool/Teleport"][positionName]
    if data and data.type == "teleport_position" then
        local rx, ry, rz = unpack(data.orientation)
        return CFrame.new(data.x, data.y, data.z) * CFrame.Angles(rx, ry, rz), data.number or 0, data.created or os.time()
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
    local jsonPositions = loadAllPositionsFromFolder()
    for positionName, data in pairs(jsonPositions) do
        Teleport.positions[positionName] = {cframe = data.cframe, number = data.number or 0, created = data.created}
        fileSystem["Supertool/Teleport"][positionName] = {
            type = "teleport_position",
            x = data.cframe.X,
            y = data.cframe.Y,
            z = data.cframe.Z,
            orientation = {data.cframe:ToEulerAnglesXYZ()},
            number = data.number or 0,
            created = data.created
        }
        Teleport.createPositionLabel(positionName, data.cframe.Position)
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

-- Get ordered positions based on sort mode
local function getOrderedPositions()
    local orderedPositions = {}
    for name, data in pairs(Teleport.positions) do
        table.insert(orderedPositions, {name = name, cframe = data.cframe, number = data.number, created = data.created})
    end
    
    if Teleport.sortMode == "alpha" then
        table.sort(orderedPositions, function(a, b) return a.name < b.name end)
    elseif Teleport.sortMode == "time" then
        table.sort(orderedPositions, function(a, b) return a.created < b.created end)
    else -- "order"
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
    end
    
    return orderedPositions
end

-- Check for duplicate numbers
local function getDuplicateNumbers()
    local numberCount = {}
    local duplicates = {}
    
    for name, data in pairs(Teleport.positions) do
        local number = data.number
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
        local startPos = root.CFrame.Position
        local targetPos = targetCFrame.Position
        local distance = (targetPos - startPos).Magnitude
        local duration = distance / Teleport.smoothTeleportSpeed
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
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
    return Teleport.positions[positionName] ~= nil
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
        Teleport.positions[positionName] = nil
        if Teleport.positionLabels[positionName] then
            Teleport.positionLabels[positionName]:Destroy()
            Teleport.positionLabels[positionName] = nil
        end
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

-- Delete all positions
local function deleteAllPositions()
    for name in pairs(Teleport.positions) do
        if Teleport.positionLabels[name] then
            Teleport.positionLabels[name]:Destroy()
            Teleport.positionLabels[name] = nil
        end
        deleteFromFileSystem(name)
    end
    Teleport.positions = {}
    Teleport.newestPosition = nil
    print("Deleted all positions")
    refreshPositionButtons()
end

-- Add prefix to all positions
local function addPrefixToAll(prefix)
    if prefix == "" then return end
    local newPositions = {}
    for oldName, data in pairs(Teleport.positions) do
        local newName = prefix .. oldName
        newName = generateUniqueName(newName)
        newPositions[newName] = data
        if Teleport.positionLabels[oldName] then
            local label = Teleport.positionLabels[oldName]
            Teleport.positionLabels[newName] = label
            Teleport.positionLabels[oldName] = nil
            local number = data.number
            local labelText = newName
            if number > 0 then
                labelText = "[" .. number .. "] " .. newName
            end
            label.TextLabel.Text = labelText
        end
        renameInFileSystem(oldName, newName)
        print("Renamed " .. oldName .. " to " .. newName)
    end
    Teleport.positions = newPositions
    refreshPositionButtons()
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
                        local number = position.number
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
        local number = position.number
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
            local number = position.number
            local numberText = number > 0 and "#" .. number or ""
            AutoStatusLabel.Text = "Auto teleport: " .. position.name .. numberText .. " (" .. Teleport.autoTeleportMode .. ")"
        end
    end
    print("Auto teleport mode set to: " .. Teleport.autoTeleportMode)
    return Teleport.autoTeleportMode
end

-- Create position button with rename, delete, and numbering functionality
createPositionButton = function(positionName, cframe, number, created)
    if not PositionScrollFrame then
        warn("Cannot create position button: PositionScrollFrame not initialized")
        return
    end

    local ButtonFrame = Instance.new("Frame")
    ButtonFrame.Size = UDim2.new(1, -10, 0, 22)
    ButtonFrame.BackgroundTransparency = 1
    ButtonFrame.Parent = PositionScrollFrame

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
    TeleportButton.BackgroundColor3 = positionName == Teleport.newestPosition and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(50, 50, 50)
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
            Teleport.positions[positionName].number = newNumber
            saveToFileSystem(positionName, cframe, newNumber, created)
            if Teleport.positionLabels[positionName] then
                local labelText = positionName
                if newNumber > 0 then
                    labelText = "[" .. newNumber .. "] " .. positionName
                end
                Teleport.positionLabels[positionName].TextLabel.Text = labelText
            end
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
            local data = Teleport.positions[positionName]
            Teleport.positions[newName] = data
            Teleport.positions[positionName] = nil
            if Teleport.positionLabels[positionName] then
                local label = Teleport.positionLabels[positionName]
                Teleport.positionLabels[newName] = label
                Teleport.positionLabels[positionName] = nil
                local num = data.number
                local labelText = newName
                if num > 0 then
                    labelText = "[" .. num .. "] " .. newName
                end
                label.TextLabel.Text = labelText
            end
            renameInFileSystem(positionName, newName)
            if Teleport.newestPosition == positionName then
                Teleport.newestPosition = newName
            end
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
        TeleportButton.BackgroundColor3 = positionName == Teleport.newestPosition and Color3.fromRGB(70, 120, 70) or Color3.fromRGB(70, 70, 70)
    end)

    TeleportButton.MouseLeave:Connect(function()
        TeleportButton.BackgroundColor3 = positionName == Teleport.newestPosition and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(50, 50, 50)
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
    infoLabel.Text = "JSON Sync: " .. TELEPORT_FOLDER_PATH .. " (" .. table.maxn(Teleport.positions) .. " positions)"
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    infoLabel.TextSize = 7
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    for _, pos in ipairs(getOrderedPositions()) do
        createPositionButton(pos.name, pos.cframe, pos.number, pos.created)
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
            for name, data in pairs(Teleport.positions) do
                saveToJSONFile(name, data.cframe, data.number, data.created)
                count = count + 1
            end
            print("[SUPERTOOL] Synced " .. count .. " positions to JSON files")
        end)
    end
    
    updateScrollCanvasSize()
end

-- On character respawn
local function onCharacterAdded(character)
    Teleport.lastClickTime = 0
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
                    local number = position.number
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
    local created = os.time()
    Teleport.positions[positionName] = {cframe = currentCFrame, number = 0, created = created}
    saveToFileSystem(positionName, currentCFrame, 0, created)
    Teleport.createPositionLabel(positionName, currentCFrame.Position)
    Teleport.newestPosition = positionName
    createPositionButton(positionName, currentCFrame, 0, created)
    
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
    local created = os.time()
    Teleport.positions[positionName] = {cframe = cframe, number = 0, created = created}
    saveToFileSystem(positionName, cframe, 0, created)
    Teleport.createPositionLabel(positionName, cframe.Position)
    Teleport.newestPosition = positionName
    createPositionButton(positionName, cframe, 0, created)
    
    if PositionInput then
        PositionInput.Text = ""
    end
    
    updateScrollCanvasSize()
    print("Saved freecam position: " .. positionName)
    return true
end

-- Save custom coordinate position
function Teleport.saveCoordPosition()
    local x = tonumber(CoordInputX.Text) or 0
    local y = tonumber(CoordInputY.Text) or 0
    local z = tonumber(CoordInputZ.Text) or 0
    local cframe = CFrame.new(x, y, z)
    
    local positionName = PositionInput and PositionInput.Text:gsub("^%s*(.-)%s*$", "%1") or ""
    if positionName == "" then
        positionName = "Coord_" .. (os.time() % 10000)
    end
    
    positionName = generateUniqueName(positionName)
    
    local created = os.time()
    Teleport.positions[positionName] = {cframe = cframe, number = 0, created = created}
    saveToFileSystem(positionName, cframe, 0, created)
    Teleport.createPositionLabel(positionName, cframe.Position)
    Teleport.newestPosition = positionName
    createPositionButton(positionName, cframe, 0, created)
    
    updateScrollCanvasSize()
    print("Saved coordinate position: " .. positionName)
    return true
end

-- Teleport to custom coordinates
function Teleport.teleportToCoords()
    local x = tonumber(CoordInputX.Text) or 0
    local y = tonumber(CoordInputY.Text) or 0
    local z = tonumber(CoordInputZ.Text) or 0
    local cframe = CFrame.new(x, y, z)
    if safeTeleport(cframe) then
        print("Teleported to coordinates: " .. x .. ", " .. y .. ", " .. z)
    end
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
    if #Teleport.undoStack >= 50 then
        table.remove(Teleport.undoStack, 1)
    end
    table.insert(Teleport.undoStack, currentCFrame)
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
    if #Teleport.undoStack >= 50 then
        table.remove(Teleport.undoStack, 1)
    end
    table.insert(Teleport.undoStack, currentCFrame)
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
    if #Teleport.undoStack >= 50 then
        table.remove(Teleport.undoStack, 1)
    end
    table.insert(Teleport.undoStack, currentCFrame)
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
    if #Teleport.undoStack >= 50 then
        table.remove(Teleport.undoStack, 1)
    end
    table.insert(Teleport.undoStack, currentCFrame)
    local leftVector = -currentCFrame.RightVector * (distance or 10)
    safeTeleport(currentCFrame + leftVector)
    print("Teleported left by " .. (distance or 10) .. " units")
end

function Teleport.teleportUp(distance)
    local root = getRootPart()
    if not root then
        warn("Cannot teleport: Character not found")
        return
    end
    local currentCFrame = root.CFrame
    if #Teleport.undoStack >= 50 then
        table.remove(Teleport.undoStack, 1)
    end
    table.insert(Teleport.undoStack, currentCFrame)
    local upVector = currentCFrame.UpVector * (distance or 10)
    safeTeleport(currentCFrame + upVector)
    print("Teleported up by " .. (distance or 10) .. " units")
end

function Teleport.teleportDown(distance)
    local root = getRootPart()
    if not root then
        warn("Cannot teleport: Character not found")
        return
    end
    local currentCFrame = root.CFrame
    if #Teleport.undoStack >= 50 then
        table.remove(Teleport.undoStack, 1)
    end
    table.insert(Teleport.undoStack, currentCFrame)
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
    
    createButton("TP Up", function()
        Teleport.teleportUp()
    end)
    
    createButton("TP Down", function()
        Teleport.teleportDown()
    end)
    
    createButton("Double Click TP", function()
        Teleport.doubleClickTeleportEnabled = not Teleport.doubleClickTeleportEnabled
        print("Double click teleport " .. (Teleport.doubleClickTeleportEnabled and "enabled" or "disabled"))
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

-- New: Create position label in the world
function Teleport.createPositionLabel(positionName, positionVector)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Position = positionVector + Vector3.new(0, 5, 0) -- Slightly above the position
    part.Parent = Workspace

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PositionLabel"
    billboard.Parent = part
    billboard.Adornee = part
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = Teleport.labelsVisible

    local textLabel = Instance.new("TextLabel")
    textLabel.Parent = billboard
    textLabel.BackgroundTransparency = 1
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    local number = Teleport.positions[positionName].number
    local labelText = positionName
    if number > 0 then
        labelText = "[" .. number .. "] " .. positionName
    end
    textLabel.Text = labelText
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextSize = 14
    textLabel.Font = Enum.Font.GothamBold

    Teleport.positionLabels[positionName] = billboard
end

-- New: Toggle labels visibility
function Teleport.toggleLabels()
    Teleport.labelsVisible = not Teleport.labelsVisible
    for _, label in pairs(Teleport.positionLabels) do
        label.Enabled = Teleport.labelsVisible
    end
    if LabelToggle then
        LabelToggle.Text = "Position Labels: " .. (Teleport.labelsVisible and "ON" or "OFF")
    end
    print("Position labels " .. (Teleport.labelsVisible and "shown" or "hidden"))
end

-- Clean old labels
local function cleanOldLabels()
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Part") and child:FindFirstChild("PositionLabel") then
            child:Destroy()
        end
    end
end

-- Function to set dependencies and initialize UI
function Teleport.init(deps)
    if Teleport.initialized then
        return true
    end
    Teleport.initialized = true

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

    ScreenGui.ResetOnSpawn = false  -- Prevent GUI reset on respawn

    Teleport.positions = Teleport.positions or {}
    Teleport.positionLabels = Teleport.positionLabels or {}
    Teleport.positionFrameVisible = false
    
    if not isfolder(TELEPORT_FOLDER_PATH) then
        makefolder(TELEPORT_FOLDER_PATH)
        print("[SUPERTOOL] Created teleport folder: " .. TELEPORT_FOLDER_PATH)
    end
    
    ensureFileSystem()
    
    cleanOldLabels()
    syncPositionsFromJSON()
    
    for positionName, data in pairs(fileSystem["Supertool/Teleport"]) do
        if data.type == "teleport_position" and not Teleport.positions[positionName] then
            local cframe, number, created = loadFromFileSystem(positionName)
            if cframe then
                Teleport.positions[positionName] = {cframe = cframe, number = number, created = created}
                saveToJSONFile(positionName, cframe, number, created)
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

        PositionFrame = ScreenGui:FindFirstChild("PositionFrame")
        if not PositionFrame then
            PositionFrame = Instance.new("Frame")
            PositionFrame.Name = "PositionFrame"
            PositionFrame.Parent = ScreenGui
            PositionFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
            PositionFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
            PositionFrame.BorderSizePixel = 1
            PositionFrame.Position = UDim2.new(0.3, 0, 0.25, 0)
            PositionFrame.Size = UDim2.new(0, 300, 0, 420) -- Increased size for new elements
            PositionFrame.Visible = false
            PositionFrame.Active = true
            PositionFrame.Draggable = true
        end

        local PositionTitle = PositionFrame:FindFirstChild("Title")
        if not PositionTitle then
            PositionTitle = Instance.new("TextLabel")
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
        end

        local ClosePositionButton = PositionFrame:FindFirstChild("CloseButton")
        if not ClosePositionButton then
            ClosePositionButton = Instance.new("TextButton")
            ClosePositionButton.Name = "CloseButton"
            ClosePositionButton.Parent = PositionFrame
            ClosePositionButton.BackgroundTransparency = 1
            ClosePositionButton.Position = UDim2.new(1, -25, 0, 3)
            ClosePositionButton.Size = UDim2.new(0, 22, 0, 22)
            ClosePositionButton.Font = Enum.Font.GothamBold
            ClosePositionButton.Text = "X"
            ClosePositionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            ClosePositionButton.TextSize = 11
        end

        PositionInput = PositionFrame:FindFirstChild("PositionInput")
        if not PositionInput then
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
        end

        SavePositionButton = PositionFrame:FindFirstChild("SavePositionButton")
        if not SavePositionButton then
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
        end

        CoordInputX = PositionFrame:FindFirstChild("CoordInputX")
        if not CoordInputX then
            CoordInputX = Instance.new("TextBox")
            CoordInputX.Name = "CoordInputX"
            CoordInputX.Parent = PositionFrame
            CoordInputX.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            CoordInputX.BorderSizePixel = 0
            CoordInputX.Position = UDim2.new(0, 8, 0, 65)
            CoordInputX.Size = UDim2.new(0.3, -5, 0, 25)
            CoordInputX.Font = Enum.Font.Gotham
            CoordInputX.PlaceholderText = "X"
            CoordInputX.Text = ""
            CoordInputX.TextColor3 = Color3.fromRGB(255, 255, 255)
            CoordInputX.TextSize = 10
        end

        CoordInputY = PositionFrame:FindFirstChild("CoordInputY")
        if not CoordInputY then
            CoordInputY = Instance.new("TextBox")
            CoordInputY.Name = "CoordInputY"
            CoordInputY.Parent = PositionFrame
            CoordInputY.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            CoordInputY.BorderSizePixel = 0
            CoordInputY.Position = UDim2.new(0.3, 0, 0, 65)
            CoordInputY.Size = UDim2.new(0.3, -5, 0, 25)
            CoordInputY.Font = Enum.Font.Gotham
            CoordInputY.PlaceholderText = "Y"
            CoordInputY.Text = ""
            CoordInputY.TextColor3 = Color3.fromRGB(255, 255, 255)
            CoordInputY.TextSize = 10
        end

        CoordInputZ = PositionFrame:FindFirstChild("CoordInputZ")
        if not CoordInputZ then
            CoordInputZ = Instance.new("TextBox")
            CoordInputZ.Name = "CoordInputZ"
            CoordInputZ.Parent = PositionFrame
            CoordInputZ.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            CoordInputZ.BorderSizePixel = 0
            CoordInputZ.Position = UDim2.new(0.6, 0, 0, 65)
            CoordInputZ.Size = UDim2.new(0.3, -5, 0, 25)
            CoordInputZ.Font = Enum.Font.Gotham
            CoordInputZ.PlaceholderText = "Z"
            CoordInputZ.Text = ""
            CoordInputZ.TextColor3 = Color3.fromRGB(255, 255, 255)
            CoordInputZ.TextSize = 10
        end

        TeleportToCoordButton = PositionFrame:FindFirstChild("TeleportToCoordButton")
        if not TeleportToCoordButton then
            TeleportToCoordButton = Instance.new("TextButton")
            TeleportToCoordButton.Name = "TeleportToCoordButton"
            TeleportToCoordButton.Parent = PositionFrame
            TeleportToCoordButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            TeleportToCoordButton.BorderSizePixel = 0
            TeleportToCoordButton.Position = UDim2.new(0, 8, 0, 95)
            TeleportToCoordButton.Size = UDim2.new(0.5, -10, 0, 25)
            TeleportToCoordButton.Font = Enum.Font.Gotham
            TeleportToCoordButton.Text = "TP to Coord"
            TeleportToCoordButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            TeleportToCoordButton.TextSize = 9
        end

        SaveCoordButton = PositionFrame:FindFirstChild("SaveCoordButton")
        if not SaveCoordButton then
            SaveCoordButton = Instance.new("TextButton")
            SaveCoordButton.Name = "SaveCoordButton"
            SaveCoordButton.Parent = PositionFrame
            SaveCoordButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            SaveCoordButton.BorderSizePixel = 0
            SaveCoordButton.Position = UDim2.new(0.5, 2, 0, 95)
            SaveCoordButton.Size = UDim2.new(0.5, -10, 0, 25)
            SaveCoordButton.Font = Enum.Font.Gotham
            SaveCoordButton.Text = "Save Coord"
            SaveCoordButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            SaveCoordButton.TextSize = 9
        end

        SmoothToggle = PositionFrame:FindFirstChild("SmoothToggle")
        if not SmoothToggle then
            SmoothToggle = Instance.new("TextButton")
            SmoothToggle.Name = "SmoothToggle"
            SmoothToggle.Parent = PositionFrame
            SmoothToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            SmoothToggle.BorderSizePixel = 0
            SmoothToggle.Position = UDim2.new(0, 8, 0, 125)
            SmoothToggle.Size = UDim2.new(0.5, -10, 0, 25)
            SmoothToggle.Font = Enum.Font.Gotham
            SmoothToggle.Text = "Smooth TP: " .. (Teleport.smoothTeleportEnabled and "ON" or "OFF")
            SmoothToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
            SmoothToggle.TextSize = 9
        end

        SpeedInput = PositionFrame:FindFirstChild("SpeedInput")
        if not SpeedInput then
            SpeedInput = Instance.new("TextBox")
            SpeedInput.Name = "SpeedInput"
            SpeedInput.Parent = PositionFrame
            SpeedInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            SpeedInput.BorderSizePixel = 0
            SpeedInput.Position = UDim2.new(0.5, 2, 0, 125)
            SpeedInput.Size = UDim2.new(0.5, -10, 0, 25)
            SpeedInput.Font = Enum.Font.Gotham
            SpeedInput.Text = tostring(Teleport.smoothTeleportSpeed)
            SpeedInput.PlaceholderText = "Speed (studs/s)"
            SpeedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
            SpeedInput.TextSize = 9
        end

        LabelToggle = PositionFrame:FindFirstChild("LabelToggle")
        if not LabelToggle then
            LabelToggle = Instance.new("TextButton")
            LabelToggle.Name = "LabelToggle"
            LabelToggle.Parent = PositionFrame
            LabelToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            LabelToggle.BorderSizePixel = 0
            LabelToggle.Position = UDim2.new(0, 8, 0, 155)
            LabelToggle.Size = UDim2.new(1, -16, 0, 25)
            LabelToggle.Font = Enum.Font.Gotham
            LabelToggle.Text = "Position Labels: " .. (Teleport.labelsVisible and "ON" or "OFF")
            LabelToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
            LabelToggle.TextSize = 9
        end

        SortModeButton = PositionFrame:FindFirstChild("SortModeButton")
        if not SortModeButton then
            SortModeButton = Instance.new("TextButton")
            SortModeButton.Name = "SortModeButton"
            SortModeButton.Parent = PositionFrame
            SortModeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            SortModeButton.BorderSizePixel = 0
            SortModeButton.Position = UDim2.new(0, 8, 0, 185)
            SortModeButton.Size = UDim2.new(0.5, -10, 0, 25)
            SortModeButton.Font = Enum.Font.Gotham
            SortModeButton.Text = "Sort: Order"
            SortModeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            SortModeButton.TextSize = 9
        end

        DeleteAllButton = PositionFrame:FindFirstChild("DeleteAllButton")
        if not DeleteAllButton then
            DeleteAllButton = Instance.new("TextButton")
            DeleteAllButton.Name = "DeleteAllButton"
            DeleteAllButton.Parent = PositionFrame
            DeleteAllButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
            DeleteAllButton.BorderSizePixel = 0
            DeleteAllButton.Position = UDim2.new(0.5, 2, 0, 185)
            DeleteAllButton.Size = UDim2.new(0.5, -10, 0, 25)
            DeleteAllButton.Font = Enum.Font.Gotham
            DeleteAllButton.Text = "Delete All"
            DeleteAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            DeleteAllButton.TextSize = 9
        end

        PrefixInput = PositionFrame:FindFirstChild("PrefixInput")
        if not PrefixInput then
            PrefixInput = Instance.new("TextBox")
            PrefixInput.Name = "PrefixInput"
            PrefixInput.Parent = PositionFrame
            PrefixInput.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            PrefixInput.BorderSizePixel = 0
            PrefixInput.Position = UDim2.new(0, 8, 0, 215)
            PrefixInput.Size = UDim2.new(0.5, -10, 0, 25)
            PrefixInput.Font = Enum.Font.Gotham
            PrefixInput.PlaceholderText = "Prefix for all"
            PrefixInput.Text = ""
            PrefixInput.TextColor3 = Color3.fromRGB(255, 255, 255)
            PrefixInput.TextSize = 9
        end

        AddPrefixButton = PositionFrame:FindFirstChild("AddPrefixButton")
        if not AddPrefixButton then
            AddPrefixButton = Instance.new("TextButton")
            AddPrefixButton.Name = "AddPrefixButton"
            AddPrefixButton.Parent = PositionFrame
            AddPrefixButton.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
            AddPrefixButton.BorderSizePixel = 0
            AddPrefixButton.Position = UDim2.new(0.5, 2, 0, 215)
            AddPrefixButton.Size = UDim2.new(0.5, -10, 0, 25)
            AddPrefixButton.Font = Enum.Font.Gotham
            AddPrefixButton.Text = "Add Prefix"
            AddPrefixButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            AddPrefixButton.TextSize = 9
        end

        PositionScrollFrame = PositionFrame:FindFirstChild("PositionScrollFrame")
        if not PositionScrollFrame then
            PositionScrollFrame = Instance.new("ScrollingFrame")
            PositionScrollFrame.Name = "PositionScrollFrame"
            PositionScrollFrame.Parent = PositionFrame
            PositionScrollFrame.BackgroundTransparency = 1
            PositionScrollFrame.Position = UDim2.new(0, 8, 0, 245)
            PositionScrollFrame.Size = UDim2.new(1, -16, 1, -315)
            PositionScrollFrame.ScrollBarThickness = 3
            PositionScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
            PositionScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
            PositionScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
            PositionScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
            PositionScrollFrame.BorderSizePixel = 0
        end

        PositionLayout = PositionScrollFrame:FindFirstChild("PositionLayout")
        if not PositionLayout then
            PositionLayout = Instance.new("UIListLayout")
            PositionLayout.Name = "PositionLayout"
            PositionLayout.Parent = PositionScrollFrame
            PositionLayout.Padding = UDim.new(0, 1)
            PositionLayout.SortOrder = Enum.SortOrder.LayoutOrder
            PositionLayout.FillDirection = Enum.FillDirection.Vertical
        end

        AutoTeleportFrame = PositionFrame:FindFirstChild("AutoTeleportFrame")
        if not AutoTeleportFrame then
            AutoTeleportFrame = Instance.new("Frame")
            AutoTeleportFrame.Name = "AutoTeleportFrame"
            AutoTeleportFrame.Parent = PositionFrame
            AutoTeleportFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            AutoTeleportFrame.BorderSizePixel = 0
            AutoTeleportFrame.Position = UDim2.new(0, 8, 1, -62)
            AutoTeleportFrame.Size = UDim2.new(1, -16, 0, 58)
        end

        local AutoTeleportTitle = AutoTeleportFrame:FindFirstChild("AutoTeleportTitle")
        if not AutoTeleportTitle then
            AutoTeleportTitle = Instance.new("TextLabel")
            AutoTeleportTitle.Name = "AutoTeleportTitle"
            AutoTeleportTitle.Parent = AutoTeleportFrame
            AutoTeleportTitle.BackgroundTransparency = 1
            AutoTeleportTitle.Position = UDim2.new(0, 0, 0, 0)
            AutoTeleportTitle.Size = UDim2.new(1, 0, 0, 15)
            AutoTeleportTitle.Font = Enum.Font.Gotham
            AutoTeleportTitle.Text = "AUTO TELEPORT"
            AutoTeleportTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
            AutoTeleportTitle.TextSize = 9
        end

        AutoModeToggle = AutoTeleportFrame:FindFirstChild("AutoModeToggle")
        if not AutoModeToggle then
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
        end

        DelayInput = AutoTeleportFrame:FindFirstChild("DelayInput")
        if not DelayInput then
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
        end

        AutoTeleportButton = AutoTeleportFrame:FindFirstChild("AutoTeleportButton")
        if not AutoTeleportButton then
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
        end

        StopAutoButton = AutoTeleportFrame:FindFirstChild("StopAutoButton")
        if not StopAutoButton then
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
        end

        AutoStatusLabel = ScreenGui:FindFirstChild("AutoStatusLabel")
        if not AutoStatusLabel then
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
        end

        -- Connect events (these will be connected each time if re-init, but since guarded by initialized, only once)
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

        SpeedInput.FocusLost:Connect(function(enterPressed)
            local newSpeed = tonumber(SpeedInput.Text)
            if newSpeed and newSpeed > 0 then
                Teleport.smoothTeleportSpeed = newSpeed
                print("Smooth teleport speed set to: " .. newSpeed .. " studs/s")
            else
                SpeedInput.Text = tostring(Teleport.smoothTeleportSpeed)
            end
        end)

        TeleportToCoordButton.MouseButton1Click:Connect(function()
            Teleport.teleportToCoords()
        end)

        SaveCoordButton.MouseButton1Click:Connect(function()
            Teleport.saveCoordPosition()
        end)

        LabelToggle.MouseButton1Click:Connect(function()
            Teleport.toggleLabels()
        end)

        SortModeButton.MouseButton1Click:Connect(function()
            if Teleport.sortMode == "order" then
                Teleport.sortMode = "alpha"
                SortModeButton.Text = "Sort: Alpha"
            elseif Teleport.sortMode == "alpha" then
                Teleport.sortMode = "time"
                SortModeButton.Text = "Sort: Time"
            else
                Teleport.sortMode = "order"
                SortModeButton.Text = "Sort: Order"
            end
            refreshPositionButtons()
        end)

        DeleteAllButton.MouseButton1Click:Connect(function()
            if DeleteAllButton.Text == "Confirm Delete All?" then
                deleteAllPositions()
                DeleteAllButton.Text = "Delete All"
            else
                DeleteAllButton.Text = "Confirm Delete All?"
                spawn(function()
                    wait(3)
                    if DeleteAllButton then
                        DeleteAllButton.Text = "Delete All"
                    end
                end)
            end
        end)

        AddPrefixButton.MouseButton1Click:Connect(function()
            local prefix = PrefixInput.Text:gsub("^%s*(.-)%s*$", "%1")
            addPrefixToAll(prefix)
            PrefixInput.Text = ""
        end)

        PositionLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            updateScrollCanvasSize()
        end)

        print("Position Manager UI created successfully")
    end
    
    initUI()
    
    Teleport.loadSavedPositions()
    print("[SUPERTOOL] Teleport module initialized with JSON sync to: " .. TELEPORT_FOLDER_PATH)

    -- Setup double click teleport and undo
    local UserInputService = game:GetService("UserInputService")
    local Mouse = player:GetMouse()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if not Teleport.doubleClickTeleportEnabled then return end
            local root = getRootPart()
            if not root then return end
            local currentTime = tick()
            if currentTime - Teleport.lastClickTime < Teleport.doubleClickThreshold then
                local hit = Mouse.Hit
                if hit then
                    local currentCFrame = root.CFrame
                    if #Teleport.undoStack >= 50 then
                        table.remove(Teleport.undoStack, 1)
                    end
                    table.insert(Teleport.undoStack, currentCFrame)
                    safeTeleport(hit)
                    print("Double click teleported to mouse position")
                end
            end
            Teleport.lastClickTime = currentTime
        elseif input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Z then
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
                if #Teleport.undoStack > 0 then
                    local prevCFrame = table.remove(Teleport.undoStack)
                    safeTeleport(prevCFrame)
                    print("Undid last teleport")
                end
            end
        end
    end)
    
    return true
end

_G.Teleport = Teleport
return Teleport