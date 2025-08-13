-- Dependencies: These must be passed from mainloader.lua
local Players, humanoid, rootPart, ScrollFrame, buttonStates, RunService, player, ScreenGui, settings

-- Initialize module
local Utility = {}

-- Variables
local macroRecording = false
local macroPlaying = false
local autoPlaying = false
local currentMacro = {}
local savedMacros = {}
local macroFrameVisible = false
local MacroFrame, MacroScrollFrame, MacroLayout, MacroInput, SaveMacroButton, MacroStatusLabel
local recordConnection = nil
local playbackConnection = nil
local currentMacroName = nil
local recordingPaused = false
local lastFrameTime = 0

-- Memory Scanner Variables
local memoryFrameVisible = false
local MemoryFrame, MemoryScrollFrame, MemoryLayout, SearchInput, SearchButton, MemoryStatusLabel
local foundAddresses = {}
local isScanning = false
local currentSearchValue = nil
local searchHistory = {}

-- File System Integration for KRNL
local HttpService = game:GetService("HttpService")
local MACRO_FOLDER_PATH = "Supertool/Macro/"

-- Helper function untuk sanitize filename
local function sanitizeFileName(name)
    -- Replace invalid characters with underscore
    local sanitized = string.gsub(name, "[<>:\"/\\|?*]", "_")
    -- Remove leading/trailing spaces
    sanitized = string.gsub(sanitized, "^%s*(.-)%s*$", "%1")
    -- Ensure filename is not empty
    if sanitized == "" then
        sanitized = "unnamed_macro"
    end
    return sanitized
end

-- Helper function untuk save macro ke JSON file (FIXED)
local function saveToJSONFile(macroName, macroData)
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(macroName)
        local fileName = sanitizedName .. ".json"
        local filePath = MACRO_FOLDER_PATH .. fileName
        
        -- PERBAIKAN: Convert CFrame ke format yang bisa di-serialize
        local serializedFrames = {}
        for i, frame in pairs(macroData.frames or {}) do
            local serializedFrame = {
                time = frame.time,
                velocity = frame.velocity and {
                    X = frame.velocity.X,
                    Y = frame.velocity.Y,
                    Z = frame.velocity.Z
                } or {X = 0, Y = 0, Z = 0},
                walkSpeed = frame.walkSpeed or 16,
                jumpPower = frame.jumpPower or 50,
                hipHeight = frame.hipHeight or 0,
                state = frame.state and tostring(frame.state) or "Running"
            }
            
            -- Convert CFrame ke table format yang proper
            if frame.cframe then
                local cf = frame.cframe
                local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
                serializedFrame.cframe = {
                    x = x, y = y, z = z,
                    r00 = r00, r01 = r01, r02 = r02,
                    r10 = r10, r11 = r11, r12 = r12,
                    r20 = r20, r21 = r21, r22 = r22
                }
            else
                -- Default CFrame jika tidak ada
                serializedFrame.cframe = {
                    x = 0, y = 0, z = 0,
                    r00 = 1, r01 = 0, r02 = 0,
                    r10 = 0, r11 = 1, r12 = 0,
                    r20 = 0, r21 = 0, r22 = 1
                }
            end
            
            table.insert(serializedFrames, serializedFrame)
        end
        
        -- Create JSON data with metadata
        local jsonData = {
            name = macroName,
            created = os.time(),
            modified = os.time(),
            version = "1.1", -- Updated version
            frames = serializedFrames,
            startTime = macroData.startTime or 0,
            speed = macroData.speed or 1,
            frameCount = #serializedFrames,
            duration = #serializedFrames > 0 and serializedFrames[#serializedFrames].time or 0
        }
        
        local jsonString = HttpService:JSONEncode(jsonData)
        writefile(filePath, jsonString)
        
        print("[SUPERTOOL] Macro saved: " .. filePath .. " (" .. #serializedFrames .. " frames)")
        return true
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to save macro to JSON: " .. tostring(error))
        return false
    end
    return true
end

-- Helper function untuk load macro dari JSON file (FIXED)
local function loadFromJSONFile(macroName)
    local success, result = pcall(function()
        local sanitizedName = sanitizeFileName(macroName)
        local fileName = sanitizedName .. ".json"
        local filePath = MACRO_FOLDER_PATH .. fileName
        
        if not isfile(filePath) then
            return nil
        end
        
        local jsonString = readfile(filePath)
        local jsonData = HttpService:JSONDecode(jsonString)
        
        -- PERBAIKAN: Convert frames kembali ke format yang benar
        local validFrames = {}
        local frames = jsonData.frames or {}
        
        for i, frame in pairs(frames) do
            if frame and frame.time and frame.cframe then
                local validFrame = {
                    time = frame.time,
                    walkSpeed = frame.walkSpeed or 16,
                    jumpPower = frame.jumpPower or 50,
                    hipHeight = frame.hipHeight or 0
                }
                
                -- PERBAIKAN: Convert CFrame dari table format
                if frame.cframe.x and frame.cframe.y and frame.cframe.z then
                    -- Method 1: Dari components lengkap
                    if frame.cframe.r00 then
                        validFrame.cframe = CFrame.new(
                            frame.cframe.x, frame.cframe.y, frame.cframe.z,
                            frame.cframe.r00, frame.cframe.r01, frame.cframe.r02,
                            frame.cframe.r10, frame.cframe.r11, frame.cframe.r12,
                            frame.cframe.r20, frame.cframe.r21, frame.cframe.r22
                        )
                    else
                        -- Method 2: Basic position only
                        validFrame.cframe = CFrame.new(frame.cframe.x, frame.cframe.y, frame.cframe.z)
                    end
                else
                    -- Fallback: Default CFrame
                    validFrame.cframe = CFrame.new(0, 0, 0)
                end
                
                -- Convert velocity
                if frame.velocity and frame.velocity.X then
                    validFrame.velocity = Vector3.new(frame.velocity.X, frame.velocity.Y, frame.velocity.Z)
                else
                    validFrame.velocity = Vector3.new(0, 0, 0)
                end
                
                -- Convert state
                if frame.state then
                    local stateStr = tostring(frame.state)
                    -- Convert string state back to enum
                    if stateStr == "Running" then
                        validFrame.state = Enum.HumanoidStateType.Running
                    elseif stateStr == "Jumping" then
                        validFrame.state = Enum.HumanoidStateType.Jumping
                    elseif stateStr == "Freefall" then
                        validFrame.state = Enum.HumanoidStateType.Freefall
                    elseif stateStr == "Flying" then
                        validFrame.state = Enum.HumanoidStateType.Flying
                    else
                        validFrame.state = Enum.HumanoidStateType.Running
                    end
                else
                    validFrame.state = Enum.HumanoidStateType.Running
                end
                
                table.insert(validFrames, validFrame)
            end
        end
        
        if #validFrames == 0 then
            warn("[SUPERTOOL] No valid frames found in macro: " .. macroName .. " (Raw frames: " .. #frames .. ")")
            return nil
        end
        
        -- Return macro data in expected format
        return {
            frames = validFrames,
            startTime = jsonData.startTime or 0,
            speed = jsonData.speed or 1,
            name = jsonData.name or macroName,
            created = jsonData.created,
            modified = jsonData.modified,
            version = jsonData.version or "1.0",
            frameCount = #validFrames,
            duration = validFrames[#validFrames].time or 0
        }
    end)
    
    if success then
        if result then
            print("[SUPERTOOL] Successfully loaded macro from JSON: " .. macroName .. " (" .. #(result.frames or {}) .. " frames)")
        else
            print("[SUPERTOOL] Macro file not found: " .. macroName)
        end
        return result
    else
        warn("[SUPERTOOL] Failed to load macro from JSON: " .. tostring(result))
        return nil
    end
end

-- Helper function untuk delete macro dari JSON file
local function deleteFromJSONFile(macroName)
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(macroName)
        local fileName = sanitizedName .. ".json"
        local filePath = MACRO_FOLDER_PATH .. fileName
        
        if isfile(filePath) then
            delfile(filePath)
            print("[SUPERTOOL] Macro deleted: " .. filePath)
            return true
        else
            return false
        end
    end)
    
    if success then
        return error
    else
        warn("[SUPERTOOL] Failed to delete macro JSON: " .. tostring(error))
        return false
    end
end

-- Helper function untuk rename macro di JSON file
local function renameInJSONFile(oldName, newName)
    local success, error = pcall(function()
        -- Load old file
        local oldData = loadFromJSONFile(oldName)
        if not oldData then
            return false
        end
        
        -- Update name in data
        oldData.name = newName
        oldData.modified = os.time()
        
        -- Save with new name
        if saveToJSONFile(newName, oldData) then
            -- Delete old file
            deleteFromJSONFile(oldName)
            print("[SUPERTOOL] Macro renamed: " .. oldName .. " -> " .. newName)
            return true
        else
            return false
        end
    end)
    
    if success then
        return error
    else
        warn("[SUPERTOOL] Failed to rename macro: " .. tostring(error))
        return false
    end
end

-- Helper function untuk load semua macros dari folder
local function loadAllMacrosFromFolder()
    local success, error = pcall(function()
        if not isfolder(MACRO_FOLDER_PATH) then
            makefolder(MACRO_FOLDER_PATH)
            print("[SUPERTOOL] Created macro folder: " .. MACRO_FOLDER_PATH)
        end
        
        local loadedMacros = {}
        local files = listfiles(MACRO_FOLDER_PATH)
        
        for _, filePath in pairs(files) do
            if string.match(filePath, "%.json$") then
                local fileName = string.match(filePath, "([^/\\]+)%.json$")
                if fileName then
                    local macroData = loadFromJSONFile(fileName)
                    if macroData then
                        local originalName = macroData.name or fileName
                        loadedMacros[originalName] = macroData
                        print("[SUPERTOOL] Loaded macro: " .. originalName)
                    end
                end
            end
        end
        
        return loadedMacros
    end)
    
    if success then
        return error or {}
    else
        warn("[SUPERTOOL] Failed to load macros from folder: " .. tostring(error))
        return {}
    end
end

-- Mock file system for backward compatibility (now syncs with JSON)
local fileSystem = {
    ["Supertool/Macro"] = {}
}

-- Helper function to ensure DCIM/Supertool exists (backward compatibility)
local function ensureFileSystem()
    if not fileSystem["Supertool"] then
        fileSystem["Supertool"] = {}
    end
    if not fileSystem["Supertool/Macro"] then
        fileSystem["Supertool/Macro"] = {}
    end
end

-- Helper function to save macro to file system (now syncs with JSON)
local function saveToFileSystem(macroName, macroData)
    ensureFileSystem()
    fileSystem["Supertool/Macro"][macroName] = macroData
    
    -- Auto-sync to JSON file
    saveToJSONFile(macroName, macroData)
end

-- Helper function to load macro from file system (prioritizes JSON)
local function loadFromFileSystem(macroName)
    -- Try to load from JSON first
    local jsonData = loadFromJSONFile(macroName)
    if jsonData then
        return jsonData
    end
    
    -- Fallback to memory
    ensureFileSystem()
    return fileSystem["Supertool/Macro"][macroName]
end

-- Helper function to delete macro from file system (syncs with JSON)
local function deleteFromFileSystem(macroName)
    ensureFileSystem()
    local memoryDeleted = false
    if fileSystem["Supertool/Macro"][macroName] then
        fileSystem["Supertool/Macro"][macroName] = nil
        memoryDeleted = true
    end
    
    -- Delete from JSON
    local jsonDeleted = deleteFromJSONFile(macroName)
    
    return memoryDeleted or jsonDeleted
end

-- Helper function to rename macro in file system (syncs with JSON)
local function renameInFileSystem(oldName, newName)
    ensureFileSystem()
    local memoryRenamed = false
    
    if fileSystem["Supertool/Macro"][oldName] and newName ~= "" then
        fileSystem["Supertool/Macro"][newName] = fileSystem["Supertool/Macro"][oldName]
        fileSystem["Supertool/Macro"][oldName] = nil
        memoryRenamed = true
    end
    
    -- Rename in JSON
    local jsonRenamed = renameInJSONFile(oldName, newName)
    
    return memoryRenamed or jsonRenamed
end

-- Function untuk sync macros dari JSON ke memory pada startup
local function syncMacrosFromJSON()
    local jsonMacros = loadAllMacrosFromFolder()
    for macroName, macroData in pairs(jsonMacros) do
        savedMacros[macroName] = macroData
        fileSystem["Supertool/Macro"][macroName] = macroData
    end
    print("[SUPERTOOL] Synced " .. table.maxn(jsonMacros) .. " macros from JSON files")
end

-- FIXED Memory Scanner Functions - Optimized to prevent freezing
local function getAllProperties(obj)
    local properties = {}
    
    -- Only scan common Roblox properties to avoid excessive scanning
    local commonProps = {
        -- Humanoid properties
        "Health", "MaxHealth", "WalkSpeed", "JumpPower", "JumpHeight", "HipHeight", 
        -- Part properties
        "Size", "Transparency", "Reflectance", "Material",
        -- Sound properties
        "Volume", "Pitch", "PlaybackSpeed",
        -- Value objects
        "Value",
        -- GUI properties
        "StudsOffset", "BackgroundTransparency", "TextTransparency",
        -- Lighting
        "Brightness", "Ambient", "ColorShift_Top", "ColorShift_Bottom",
        -- Other common numeric properties
        "FieldOfView", "MaxDistance", "MinDistance", "RollOffMode"
    }
    
    for _, prop in pairs(commonProps) do
        local success, value = pcall(function()
            return obj[prop]
        end)
        
        if success and value ~= nil then
            local valueType = typeof(value)
            if valueType == "number" or valueType == "string" or valueType == "boolean" then
                properties[prop] = value
            elseif valueType == "Vector3" then
                -- Include Vector3 components
                properties[prop .. ".X"] = value.X
                properties[prop .. ".Y"] = value.Y
                properties[prop .. ".Z"] = value.Z
            elseif valueType == "Color3" then
                -- Include Color3 components
                properties[prop .. ".R"] = value.R
                properties[prop .. ".G"] = value.G
                properties[prop .. ".B"] = value.B
            end
        end
    end
    
    return properties
end

local function scanMemory(searchValue)
    if isScanning then 
        MemoryStatusLabel.Text = "Already scanning, please wait..."
        return 
    end
    
    isScanning = true
    foundAddresses = {}
    
    MemoryStatusLabel.Text = "Scanning memory for: " .. tostring(searchValue)
    MemoryStatusLabel.Visible = true
    
    -- Convert search value to number if possible for better matching
    local numSearchValue = tonumber(searchValue)
    local strSearchValue = tostring(searchValue)
    
    local scannedCount = 0
    local maxScanPerFrame = 50 -- Limit objects scanned per frame
    local objectsToScan = {}
    
    -- Collect objects to scan
    local function collectObjects(container, path, maxDepth)
        if maxDepth <= 0 then return end
        
        table.insert(objectsToScan, {obj = container, path = path})
        
        -- Limit children scanning to prevent excessive recursion
        local children = container:GetChildren()
        local childLimit = math.min(#children, 20) -- Max 20 children per object
        
        for i = 1, childLimit do
            local child = children[i]
            if child and typeof(child) == "Instance" then
                collectObjects(child, path .. "/" .. child.Name, maxDepth - 1)
            end
        end
    end
    
    task.spawn(function()
        -- Collect objects with limited depth
        collectObjects(workspace, "Workspace", 3) -- Limited depth
        
        if player then
            collectObjects(player, "LocalPlayer", 2)
            if player.Character then
                collectObjects(player.Character, "Character", 2)
            end
            if player.PlayerGui then
                collectObjects(player.PlayerGui, "PlayerGui", 2)
            end
        end
        
        -- Scan other players (limited)
        local playerCount = 0
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if playerCount >= 5 then break end -- Limit to 5 other players
            if otherPlayer ~= player and otherPlayer.Character then
                collectObjects(otherPlayer.Character, otherPlayer.Name, 1)
                playerCount = playerCount + 1
            end
        end
        
        MemoryStatusLabel.Text = "Scanning " .. #objectsToScan .. " objects..."
        
        -- Process objects in batches with yields
        local processedCount = 0
        local batchSize = 25 -- Process 25 objects per batch
        
        for i = 1, #objectsToScan, batchSize do
            if not isScanning then break end -- Allow cancellation
            
            local endIndex = math.min(i + batchSize - 1, #objectsToScan)
            
            for j = i, endIndex do
                if not isScanning then break end
                
                local objData = objectsToScan[j]
                local obj = objData.obj
                local path = objData.path
                
                if obj and obj.Parent then -- Check if object still exists
                    local properties = getAllProperties(obj)
                    
                    for propName, propValue in pairs(properties) do
                        local numValue = tonumber(propValue)
                        local match = false
                        
                        -- Check for numeric match
                        if numSearchValue and numValue and math.abs(numValue - numSearchValue) < 0.001 then
                            match = true
                        -- Check for string match
                        elseif propValue == strSearchValue then
                            match = true
                        -- Check for partial string match (case insensitive)
                        elseif typeof(propValue) == "string" and string.find(string.lower(tostring(propValue)), string.lower(strSearchValue), 1, true) then
                            match = true
                        end
                        
                        if match then
                            table.insert(foundAddresses, {
                                object = obj,
                                property = propName,
                                value = propValue,
                                path = path .. "." .. propName,
                                address = tostring(obj) .. ":" .. propName,
                                objectName = obj.Name,
                                className = obj.ClassName
                            })
                        end
                    end
                end
                
                processedCount = processedCount + 1
            end
            
            -- Update progress
            local progress = math.floor((processedCount / #objectsToScan) * 100)
            MemoryStatusLabel.Text = "Scanning... " .. progress .. "% (" .. #foundAddresses .. " found)"
            
            -- Yield every batch to prevent freezing
            task.wait(0.03) -- Small delay to prevent lag
        end
        
        isScanning = false
        currentSearchValue = searchValue
        table.insert(searchHistory, {
            value = searchValue, 
            count = #foundAddresses, 
            time = tick()
        })
        
        -- Limit history to last 10 searches
        if #searchHistory > 10 then
            table.remove(searchHistory, 1)
        end
        
        MemoryStatusLabel.Text = "Found " .. #foundAddresses .. " addresses with value: " .. tostring(searchValue)
        Utility.updateMemoryList()
    end)
end

local function refineSearch(newValue)
    if isScanning then 
        MemoryStatusLabel.Text = "Please wait for current scan to finish"
        return 
    end
    
    if #foundAddresses == 0 then 
        MemoryStatusLabel.Text = "No addresses to refine. Run initial scan first."
        return 
    end
    
    local refinedAddresses = {}
    MemoryStatusLabel.Text = "Refining search..."
    
    local numNewValue = tonumber(newValue)
    local strNewValue = tostring(newValue)
    
    task.spawn(function()
        local processed = 0
        local batchSize = 20
        
        for i = 1, #foundAddresses, batchSize do
            local endIndex = math.min(i + batchSize - 1, #foundAddresses)
            
            for j = i, endIndex do
                local addr = foundAddresses[j]
                
                if addr.object and addr.object.Parent then -- Check if object still exists
                    local success, currentValue = pcall(function()
                        return addr.object[addr.property]
                    end)
                    
                    if success and currentValue ~= nil then
                        local numCurrentValue = tonumber(currentValue)
                        local match = false
                        
                        -- Check for numeric match
                        if numNewValue and numCurrentValue and math.abs(numCurrentValue - numNewValue) < 0.001 then
                            match = true
                        -- Check for exact string match
                        elseif currentValue == strNewValue then
                            match = true
                        end
                        
                        if match then
                            addr.value = currentValue
                            table.insert(refinedAddresses, addr)
                        end
                    end
                end
                
                processed = processed + 1
            end
            
            -- Update progress
            local progress = math.floor((processed / #foundAddresses) * 100)
            MemoryStatusLabel.Text = "Refining... " .. progress .. "% (" .. #refinedAddresses .. " match)"
            
            task.wait(0.02) -- Yield to prevent lag
        end
        
        foundAddresses = refinedAddresses
        currentSearchValue = newValue
        table.insert(searchHistory, {
            value = newValue, 
            count = #foundAddresses, 
            time = tick()
        })
        
        -- Limit history
        if #searchHistory > 10 then
            table.remove(searchHistory, 1)
        end
        
        MemoryStatusLabel.Text = "Refined to " .. #foundAddresses .. " addresses"
        Utility.updateMemoryList()
    end)
end

local function modifyValue(addr, newValue)
    if not addr.object or not addr.object.Parent then
        MemoryStatusLabel.Text = "Object no longer exists"
        return
    end
    
    local success, err = pcall(function()
        local convertedValue = newValue
        local currentValue = addr.object[addr.property]
        
        -- Auto type conversion
        if typeof(currentValue) == "number" then
            convertedValue = tonumber(newValue)
            if not convertedValue then
                error("Invalid number: " .. tostring(newValue))
            end
        elseif typeof(currentValue) == "boolean" then
            if typeof(newValue) == "boolean" then
                convertedValue = newValue
            elseif typeof(newValue) == "string" then
                convertedValue = string.lower(newValue) == "true"
            else
                convertedValue = (tonumber(newValue) or 0) ~= 0
            end
        else
            convertedValue = tostring(newValue)
        end
        
        addr.object[addr.property] = convertedValue
        addr.value = convertedValue
        
        return true
    end)
    
    if success then
        MemoryStatusLabel.Text = "✓ Modified " .. addr.property .. " = " .. tostring(newValue)
    else
        MemoryStatusLabel.Text = "✗ Failed to modify: " .. (err or "Unknown error")
    end
    
    task.wait(0.1)
    Utility.updateMemoryList()
end

-- Batch modify with safety limits and progress
local function batchModify(newValue)
    if #foundAddresses == 0 then
        MemoryStatusLabel.Text = "No addresses to modify"
        return
    end
    
    MemoryStatusLabel.Text = "Batch modifying..."
    
    task.spawn(function()
        local count = 0
        local maxModify = math.min(#foundAddresses, 50) -- Safety limit
        local successCount = 0
        
        for i = 1, maxModify do
            local addr = foundAddresses[i]
            
            if addr.object and addr.object.Parent then
                local success = pcall(function()
                    local convertedValue = newValue
                    local currentValue = addr.object[addr.property]
                    
                    if typeof(currentValue) == "number" then
                        convertedValue = tonumber(newValue) or 0
                    elseif typeof(currentValue) == "boolean" then
                        if typeof(newValue) == "string" then
                            convertedValue = string.lower(newValue) == "true"
                        else
                            convertedValue = (tonumber(newValue) or 0) ~= 0
                        end
                    else
                        convertedValue = tostring(newValue)
                    end
                    
                    addr.object[addr.property] = convertedValue
                    addr.value = convertedValue
                    successCount = successCount + 1
                end)
            end
            
            count = count + 1
            
            -- Update progress every 10 modifications
            if count % 10 == 0 then
                MemoryStatusLabel.Text = "Modifying... " .. count .. "/" .. maxModify
                task.wait(0.05) -- Small delay to prevent lag
            end
        end
        
        MemoryStatusLabel.Text = "✓ Modified " .. successCount .. "/" .. count .. " values to " .. tostring(newValue)
        
        if successCount > 0 then
            Utility.updateMemoryList()
        end
    end)
end

-- Update Memory List UI
function Utility.updateMemoryList()
    if not MemoryScrollFrame then return end
    
    for _, child in pairs(MemoryScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Show search history first
    if #searchHistory > 0 then
        local historyFrame = Instance.new("Frame")
        historyFrame.Name = "HistoryFrame"
        historyFrame.Parent = MemoryScrollFrame
        historyFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        historyFrame.BorderSizePixel = 0
        historyFrame.Size = UDim2.new(1, -5, 0, 25)
        historyFrame.LayoutOrder = -1
        
        local historyLabel = Instance.new("TextLabel")
        historyLabel.Parent = historyFrame
        historyLabel.BackgroundTransparency = 1
        historyLabel.Size = UDim2.new(1, 0, 1, 0)
        historyLabel.Font = Enum.Font.Gotham
        historyLabel.Text = "Search History: " .. table.concat((function()
            local vals = {}
            for i = math.max(1, #searchHistory-2), #searchHistory do
                table.insert(vals, searchHistory[i].value .. "(" .. searchHistory[i].count .. ")")
            end
            return vals
        end)(), " → ")
        historyLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
        historyLabel.TextSize = 7
        historyLabel.TextXAlignment = Enum.TextXAlignment.Left
    end
    
    -- Limit display to prevent lag
    local maxDisplay = math.min(#foundAddresses, 20)
    
    for i = 1, maxDisplay do
        local addr = foundAddresses[i]
        
        local addrFrame = Instance.new("Frame")
        addrFrame.Name = "Address" .. i
        addrFrame.Parent = MemoryScrollFrame
        addrFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        addrFrame.BorderSizePixel = 0
        addrFrame.Size = UDim2.new(1, -5, 0, 70)
        addrFrame.LayoutOrder = i
        
        local addressLabel = Instance.new("TextLabel")
        addressLabel.Parent = addrFrame
        addressLabel.BackgroundTransparency = 1
        addressLabel.Position = UDim2.new(0, 5, 0, 2)
        addressLabel.Size = UDim2.new(1, -10, 0, 12)
        addressLabel.Font = Enum.Font.Gotham
        addressLabel.Text = addr.address
        addressLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        addressLabel.TextSize = 6
        addressLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local pathLabel = Instance.new("TextLabel")
        pathLabel.Parent = addrFrame
        pathLabel.BackgroundTransparency = 1
        pathLabel.Position = UDim2.new(0, 5, 0, 14)
        pathLabel.Size = UDim2.new(0.6, 0, 0, 12)
        pathLabel.Font = Enum.Font.Gotham
        pathLabel.Text = addr.path
        pathLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
        pathLabel.TextSize = 7
        pathLabel.TextXAlignment = Enum.TextXAlignment.Left
        pathLabel.TextTruncate = Enum.TextTruncate.AtEnd
        
        local valueLabel = Instance.new("TextLabel")
        valueLabel.Parent = addrFrame
        valueLabel.BackgroundTransparency = 1
        valueLabel.Position = UDim2.new(0.6, 0, 0, 14)
        valueLabel.Size = UDim2.new(0.4, -5, 0, 12)
        valueLabel.Font = Enum.Font.Gotham
        valueLabel.Text = "Value: " .. tostring(addr.value)
        valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        valueLabel.TextSize = 7
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        
        local inputBox = Instance.new("TextBox")
        inputBox.Parent = addrFrame
        inputBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        inputBox.BorderSizePixel = 0
        inputBox.Position = UDim2.new(0, 5, 0, 28)
        inputBox.Size = UDim2.new(0.6, -5, 0, 18)
        inputBox.Font = Enum.Font.Gotham
        inputBox.PlaceholderText = "New value..."
        inputBox.Text = ""
        inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        inputBox.TextSize = 7
        
        local modifyBtn = Instance.new("TextButton")
        modifyBtn.Parent = addrFrame
        modifyBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
        modifyBtn.BorderSizePixel = 0
        modifyBtn.Position = UDim2.new(0.6, 5, 0, 28)
        modifyBtn.Size = UDim2.new(0.4, -10, 0, 18)
        modifyBtn.Font = Enum.Font.Gotham
        modifyBtn.Text = "MODIFY"
        modifyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        modifyBtn.TextSize = 7
        
        local freezeBtn = Instance.new("TextButton")
        freezeBtn.Parent = addrFrame
        freezeBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 60)
        freezeBtn.BorderSizePixel = 0
        freezeBtn.Position = UDim2.new(0, 5, 0, 48)
        freezeBtn.Size = UDim2.new(0.5, -5, 0, 16)
        freezeBtn.Font = Enum.Font.Gotham
        freezeBtn.Text = "FREEZE"
        freezeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        freezeBtn.TextSize = 6
        
        local copyBtn = Instance.new("TextButton")
        copyBtn.Parent = addrFrame
        copyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 100)
        copyBtn.BorderSizePixel = 0
        copyBtn.Position = UDim2.new(0.5, 5, 0, 48)
        copyBtn.Size = UDim2.new(0.5, -10, 0, 16)
        copyBtn.Font = Enum.Font.Gotham
        copyBtn.Text = "COPY ADDR"
        copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        copyBtn.TextSize = 6
        
        -- Event handlers
        modifyBtn.MouseButton1Click:Connect(function()
            local newVal = tonumber(inputBox.Text) or inputBox.Text
            if newVal ~= "" then
                modifyValue(addr, newVal)
                inputBox.Text = ""
            end
        end)
        
        inputBox.FocusLost:Connect(function(enterPressed)
            if enterPressed and inputBox.Text ~= "" then
                local newVal = tonumber(inputBox.Text) or inputBox.Text
                modifyValue(addr, newVal)
                inputBox.Text = ""
            end
        end)
        
        freezeBtn.MouseButton1Click:Connect(function()
            -- TODO: Implement freeze functionality
            MemoryStatusLabel.Text = "Freeze feature coming soon!"
        end)
        
        copyBtn.MouseButton1Click:Connect(function()
            -- Copy address to "clipboard" (show in status)
            MemoryStatusLabel.Text = "Copied: " .. addr.address
        end)
    end
    
    if #foundAddresses > maxDisplay then
        local moreLabel = Instance.new("TextLabel")
        moreLabel.Parent = MemoryScrollFrame
        moreLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 40)
        moreLabel.BorderSizePixel = 0
        moreLabel.Size = UDim2.new(1, -5, 0, 25)
        moreLabel.LayoutOrder = maxDisplay + 1
        moreLabel.Font = Enum.Font.Gotham
        moreLabel.Text = "+" .. (#foundAddresses - maxDisplay) .. " more addresses (refine search to see them)"
        moreLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
        moreLabel.TextSize = 7
    end
    
    task.wait(0.1)
    if MemoryLayout then
        local contentSize = MemoryLayout.AbsoluteContentSize
        MemoryScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 10)
    end
end

-- Show Memory Scanner
local function showMemoryScanner()
    memoryFrameVisible = true
    if not MemoryFrame then
        initMemoryUI()
    end
    MemoryFrame.Visible = true
    Utility.updateMemoryList()
end

-- Initialize Memory Scanner UI
local function initMemoryUI()
    if MemoryFrame then return end
    
    MemoryFrame = Instance.new("Frame")
    MemoryFrame.Name = "MemoryFrame"
    MemoryFrame.Parent = ScreenGui
    MemoryFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    MemoryFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    MemoryFrame.BorderSizePixel = 1
    MemoryFrame.Position = UDim2.new(0.35, 0, 0.1, 0)
    MemoryFrame.Size = UDim2.new(0, 450, 0, 500)
    MemoryFrame.Visible = memoryFrameVisible
    MemoryFrame.Active = true
    MemoryFrame.Draggable = true

    local title = Instance.new("TextLabel")
    title.Parent = MemoryFrame
    title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    title.BorderSizePixel = 0
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Font = Enum.Font.GothamBold
    title.Text = "MEMORY SCANNER - GameGuardian Style"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 9

    local closeBtn = Instance.new("TextButton")
    closeBtn.Parent = MemoryFrame
    closeBtn.BackgroundTransparency = 1
    closeBtn.Position = UDim2.new(1, -25, 0, 2)
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.TextSize = 10

    SearchInput = Instance.new("TextBox")
    SearchInput.Parent = MemoryFrame
    SearchInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    SearchInput.BorderSizePixel = 0
    SearchInput.Position = UDim2.new(0, 10, 0, 35)
    SearchInput.Size = UDim2.new(1, -120, 0, 30)
    SearchInput.Font = Enum.Font.Gotham
    SearchInput.PlaceholderText = "Enter value (auto-detect type)"
    SearchInput.Text = ""
    SearchInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    SearchInput.TextSize = 8

    SearchButton = Instance.new("TextButton")
    SearchButton.Parent = MemoryFrame
    SearchButton.BackgroundColor3 = Color3.fromRGB(80, 120, 80)
    SearchButton.BorderSizePixel = 0
    SearchButton.Position = UDim2.new(1, -100, 0, 35)
    SearchButton.Size = UDim2.new(0, 90, 0, 30)
    SearchButton.Font = Enum.Font.GothamBold
    SearchButton.Text = "SCAN"
    SearchButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SearchButton.TextSize = 9
    
    local refineBtn = Instance.new("TextButton")
    refineBtn.Parent = MemoryFrame
    refineBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 80)
    refineBtn.BorderSizePixel = 0
    refineBtn.Position = UDim2.new(0, 10, 0, 75)
    refineBtn.Size = UDim2.new(0, 80, 0, 25)
    refineBtn.Font = Enum.Font.Gotham
    refineBtn.Text = "REFINE"
    refineBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    refineBtn.TextSize = 8
    
    local batchBtn = Instance.new("TextButton")
    batchBtn.Parent = MemoryFrame
    batchBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
    batchBtn.BorderSizePixel = 0
    batchBtn.Position = UDim2.new(0, 100, 0, 75)
    batchBtn.Size = UDim2.new(0, 80, 0, 25)
    batchBtn.Font = Enum.Font.Gotham
    batchBtn.Text = "BATCH"
    batchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    batchBtn.TextSize = 8
    
    local clearBtn = Instance.new("TextButton")
    clearBtn.Parent = MemoryFrame
    clearBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
    clearBtn.BorderSizePixel = 0
    clearBtn.Position = UDim2.new(1, -100, 0, 75)
    clearBtn.Size = UDim2.new(0, 90, 0, 25)
    clearBtn.Font = Enum.Font.Gotham
    clearBtn.Text = "CLEAR"
    clearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    clearBtn.TextSize = 8

    MemoryStatusLabel = Instance.new("TextLabel")
    MemoryStatusLabel.Parent = MemoryFrame
    MemoryStatusLabel.BackgroundTransparency = 1
    MemoryStatusLabel.Position = UDim2.new(0, 10, 0, 105)
    MemoryStatusLabel.Size = UDim2.new(1, -20, 0, 15)
    MemoryStatusLabel.Font = Enum.Font.Gotham
    MemoryStatusLabel.Text = "Ready to scan memory"
    MemoryStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    MemoryStatusLabel.TextSize = 7
    MemoryStatusLabel.TextXAlignment = Enum.TextXAlignment.Left

    MemoryScrollFrame = Instance.new("ScrollingFrame")
    MemoryScrollFrame.Parent = MemoryFrame
    MemoryScrollFrame.BackgroundTransparency = 1
    MemoryScrollFrame.Position = UDim2.new(0, 10, 0, 125)
    MemoryScrollFrame.Size = UDim2.new(1, -20, 1, -135)
    MemoryScrollFrame.ScrollBarThickness = 4
    MemoryScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    MemoryScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    MemoryScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    MemoryLayout = Instance.new("UIListLayout")
    MemoryLayout.Parent = MemoryScrollFrame
    MemoryLayout.Padding = UDim.new(0, 3)
    MemoryLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- Event handlers
    SearchButton.MouseButton1Click:Connect(function()
        local val = tonumber(SearchInput.Text) or SearchInput.Text
        if val ~= "" then
            scanMemory(val)
        end
    end)
    
    refineBtn.MouseButton1Click:Connect(function()
        local val = tonumber(SearchInput.Text) or SearchInput.Text
        if val ~= "" and #foundAddresses > 0 then
            refineSearch(val)
        end
    end)
    
    batchBtn.MouseButton1Click:Connect(function()
        local val = tonumber(SearchInput.Text) or SearchInput.Text
        if val ~= "" and #foundAddresses > 0 then
            batchModify(val)
        end
    end)
    
    clearBtn.MouseButton1Click:Connect(function()
        foundAddresses = {}
        searchHistory = {}
        currentSearchValue = nil
        SearchInput.Text = ""
        MemoryStatusLabel.Text = "Memory cleared"
        Utility.updateMemoryList()
    end)
    
    SearchInput.FocusLost:Connect(function(enterPressed)
        if enterPressed and SearchInput.Text ~= "" then
            local val = tonumber(SearchInput.Text) or SearchInput.Text
            if #foundAddresses > 0 then
                refineSearch(val)
            else
                scanMemory(val)
            end
        end
    end)
    
    closeBtn.MouseButton1Click:Connect(function()
        memoryFrameVisible = false
        MemoryFrame.Visible = false
    end)
end

-- Update macro status display
local function updateMacroStatus()
    if not MacroStatusLabel then return end
    if macroRecording then
        MacroStatusLabel.Text = recordingPaused and "Recording Paused" or "Recording Macro"
        MacroStatusLabel.Visible = true
    elseif macroPlaying and currentMacroName then
        local macro = savedMacros[currentMacroName] or loadFromFileSystem(currentMacroName)
        local speed = macro and macro.speed or 1
        MacroStatusLabel.Text = (autoPlaying and "Auto-Playing Macro: " or "Playing Macro: ") .. currentMacroName .. " (Speed: " .. speed .. "x)"
        MacroStatusLabel.Visible = true
    else
        MacroStatusLabel.Visible = false
    end
end

-- Update Character References (IMPROVED)
local function updateCharacterReferences()
    if player and player.Character then
        local newHumanoid = player.Character:FindFirstChild("Humanoid")
        local newRootPart = player.Character:FindFirstChild("HumanoidRootPart")
        
        if newHumanoid and newRootPart then
            humanoid = newHumanoid
            rootPart = newRootPart
            print("[SUPERTOOL] Character references updated successfully")
            
            if macroRecording and recordingPaused then
                recordingPaused = false
                updateMacroStatus()
                print("[SUPERTOOL] Recording resumed after respawn")
            end
            
            return true
        else
            print("[SUPERTOOL] Failed to find Humanoid or HumanoidRootPart in new character")
            return false
        end
    else
        print("[SUPERTOOL] No character found for reference update")
        return false
    end
end

-- Record Macro (FIXED)
local function startMacroRecording()
    if macroRecording or macroPlaying then 
        print("[SUPERTOOL] Cannot start recording: already recording=" .. tostring(macroRecording) .. " or playing=" .. tostring(macroPlaying))
        return 
    end
    
    if not updateCharacterReferences() then
        warn("[SUPERTOOL] Cannot start recording: character references not available")
        return
    end
    
    macroRecording = true
    recordingPaused = false
    currentMacro = {frames = {}, startTime = tick(), speed = 1}
    lastFrameTime = 0
    
    updateMacroStatus()
    print("[SUPERTOOL] Started macro recording")
    
    local function setupDeathHandler()
        if humanoid then
            humanoid.Died:Connect(function()
                if macroRecording then
                    recordingPaused = true
                    updateMacroStatus()
                    print("[SUPERTOOL] Recording paused due to character death")
                end
            end)
        end
    end
    
    setupDeathHandler()
    
    recordConnection = RunService.Heartbeat:Connect(function()
        if not macroRecording or recordingPaused then return end
        
        if not humanoid or not rootPart or not humanoid.Parent or not rootPart.Parent then
            if updateCharacterReferences() then
                setupDeathHandler()
            else
                return
            end
        end
        
        local frame = {
            time = tick() - currentMacro.startTime,
            cframe = rootPart.CFrame,
            velocity = rootPart.Velocity,
            walkSpeed = humanoid.WalkSpeed,
            jumpPower = humanoid.JumpPower,
            hipHeight = humanoid.HipHeight,
            state = humanoid:GetState()
        }
        table.insert(currentMacro.frames, frame)
        lastFrameTime = frame.time
    end)
end

-- Stop Macro Recording (FIXED)
local function stopMacroRecording()
    if not macroRecording then 
        print("[SUPERTOOL] Not recording any macro")
        return 
    end
    
    macroRecording = false
    recordingPaused = false
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    
    local macroName = MacroInput and MacroInput.Text or ""
    if macroName == "" then
        macroName = "Macro_" .. tostring(table.maxn(savedMacros) + 1)
    end
    
    if #currentMacro.frames == 0 then
        warn("[SUPERTOOL] No frames recorded, macro not saved")
        updateMacroStatus()
        return
    end
    
    -- Save to both memory and JSON file
    savedMacros[macroName] = currentMacro
    saveToFileSystem(macroName, currentMacro)
    
    if MacroInput then
        MacroInput.Text = ""
    end
    Utility.updateMacroList()
    updateMacroStatus()
    if MacroFrame then
        MacroFrame.Visible = true
    end
    
    print("[SUPERTOOL] Macro recorded and saved: " .. macroName .. " (" .. #currentMacro.frames .. " frames)")
end

-- Stop Macro Playback
local function stopMacroPlayback()
    if not macroPlaying then return end
    macroPlaying = false
    autoPlaying = false
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    if humanoid then
        humanoid.WalkSpeed = settings.WalkSpeed and settings.WalkSpeed.value or 16
        humanoid.JumpPower = settings.JumpPower and settings.JumpPower.value or 50
    end
    currentMacroName = nil
    Utility.updateMacroList()
    updateMacroStatus()
    print("[SUPERTOOL] Stopped macro playback")
end

-- Play Macro with Adjustable Speed (FIXED)
local function playMacro(macroName, autoPlay)
    if macroRecording or macroPlaying then 
        print("[SUPERTOOL] Cannot play macro: recording=" .. tostring(macroRecording) .. ", playing=" .. tostring(macroPlaying))
        return 
    end
    
    if not updateCharacterReferences() then
        warn("[SUPERTOOL] Cannot play macro: character references not available")
        return
    end
    
    local macro = savedMacros[macroName] or loadFromFileSystem(macroName)
    if not macro then
        warn("[SUPERTOOL] Macro not found: " .. macroName)
        return
    end
    
    if not macro.frames or #macro.frames == 0 then
        warn("[SUPERTOOL] Macro has no frames: " .. macroName)
        return
    end
    
    macroPlaying = true
    autoPlaying = autoPlay or false
    currentMacroName = macroName
    updateMacroStatus()
    
    print("[SUPERTOOL] Playing macro: " .. macroName .. " (Auto: " .. tostring(autoPlaying) .. ", Speed: " .. (macro.speed or 1) .. "x, Frames: " .. #macro.frames .. ")")
    
    local function playSingleMacro()
        local startTime = tick()
        local frameIndex = 1
        local speed = macro.speed or 1
        local totalFrames = #macro.frames
        
        -- Set initial humanoid state
        if humanoid then
            humanoid.WalkSpeed = 0  -- Prevent normal movement
            humanoid.JumpPower = 0  -- Prevent jumping during playback
        end
        
        playbackConnection = RunService.Heartbeat:Connect(function()
            -- Check if we should stop
            if not macroPlaying then
                if playbackConnection then 
                    playbackConnection:Disconnect() 
                    playbackConnection = nil
                end
                if humanoid then
                    humanoid.WalkSpeed = settings.WalkSpeed and settings.WalkSpeed.value or 16
                    humanoid.JumpPower = settings.JumpPower and settings.JumpPower.value or 50
                end
                currentMacroName = nil
                Utility.updateMacroList()
                updateMacroStatus()
                return
            end
            
            -- Check if character still exists
            if not player.Character or not humanoid or not rootPart or not humanoid.Parent or not rootPart.Parent then
                print("[SUPERTOOL] Character lost during playback, attempting to update references...")
                if not updateCharacterReferences() then
                    print("[SUPERTOOL] Could not restore character references, stopping playback")
                    macroPlaying = false
                    return
                end
            end
            
            -- Check if we've finished all frames
            if frameIndex > totalFrames then
                if autoPlaying then
                    -- Restart from beginning
                    frameIndex = 1
                    startTime = tick()
                    print("[SUPERTOOL] Auto-restarting macro: " .. macroName)
                else
                    -- Stop playback
                    macroPlaying = false
                    if humanoid then
                        humanoid.WalkSpeed = settings.WalkSpeed and settings.WalkSpeed.value or 16
                        humanoid.JumpPower = settings.JumpPower and settings.JumpPower.value or 50
                    end
                    currentMacroName = nil
                    Utility.updateMacroList()
                    updateMacroStatus()
                    print("[SUPERTOOL] Finished playing macro: " .. macroName)
                    return
                end
            end
            
            local currentTime = (tick() - startTime) * speed
            local frame = macro.frames[frameIndex]
            
            if not frame then
                frameIndex = frameIndex + 1
                return
            end
            
            -- Apply frame if time matches
            if currentTime >= frame.time then
                -- Apply frame with error handling
                local success = pcall(function()
                    if frame.cframe and rootPart then
                        rootPart.CFrame = frame.cframe
                    end
                    
                    if frame.velocity and rootPart then
                        rootPart.Velocity = frame.velocity
                    end
                    
                    if humanoid then
                        if frame.walkSpeed then
                            humanoid.WalkSpeed = frame.walkSpeed
                        end
                        if frame.jumpPower then
                            humanoid.JumpPower = frame.jumpPower
                        end
                        if frame.hipHeight then
                            humanoid.HipHeight = frame.hipHeight
                        end
                        if frame.state then
                            humanoid:ChangeState(frame.state)
                        end
                    end
                end)
                
                if not success then
                    warn("[SUPERTOOL] Error applying frame " .. frameIndex .. " for macro " .. macroName)
                end
                
                frameIndex = frameIndex + 1
                
                -- Debug info every 30 frames
                if frameIndex % 30 == 0 then
                    print("[SUPERTOOL] Macro progress: " .. frameIndex .. "/" .. totalFrames .. " frames")
                end
            end
        end)
    end
    
    playSingleMacro()
end


-- Delete Macro
local function deleteMacro(macroName)
    if savedMacros[macroName] then
        if macroPlaying and currentMacroName == macroName then
            stopMacroPlayback()
        end
        savedMacros[macroName] = nil
        deleteFromFileSystem(macroName)
        Utility.updateMacroList()
        print("[SUPERTOOL] Macro deleted: " .. macroName)
    end
end

-- Rename Macro
local function renameMacro(oldName, newName)
    if savedMacros[oldName] and newName ~= "" then
        if renameInFileSystem(oldName, newName) then
            if currentMacroName == oldName then
                currentMacroName = newName
                updateMacroStatus()
            end
            savedMacros[newName] = savedMacros[oldName]
            savedMacros[oldName] = nil
            Utility.updateMacroList()
            print("[SUPERTOOL] Macro renamed: " .. oldName .. " -> " .. newName)
        end
    end
end

-- Show Macro Manager
local function showMacroManager()
    macroFrameVisible = true
    if not MacroFrame then
        initMacroUI()
    end
    MacroFrame.Visible = true
    Utility.updateMacroList()
end

-- Update Macro List UI
function Utility.updateMacroList()
    if not MacroScrollFrame then return end
    
    for _, child in pairs(MacroScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local itemCount = 0
    
    -- Show macro folder info
    local infoFrame = Instance.new("Frame")
    infoFrame.Name = "InfoFrame"
    infoFrame.Parent = MacroScrollFrame
    infoFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    infoFrame.BorderSizePixel = 0
    infoFrame.Size = UDim2.new(1, -5, 0, 25)
    infoFrame.LayoutOrder = -1
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Parent = infoFrame
    infoLabel.BackgroundTransparency = 1
    infoLabel.Size = UDim2.new(1, 0, 1, 0)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Text = "JSON Sync: " .. MACRO_FOLDER_PATH .. " (" .. table.maxn(savedMacros) .. " macros)"
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    infoLabel.TextSize = 7
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    for macroName, macro in pairs(savedMacros) do
        local macroItem = Instance.new("Frame")
        macroItem.Name = macroName .. "Item"
        macroItem.Parent = MacroScrollFrame
        macroItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        macroItem.BorderSizePixel = 0
        macroItem.Size = UDim2.new(1, -5, 0, 110)
        macroItem.LayoutOrder = itemCount
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Parent = macroItem
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.new(0, 5, 0, 5)
        nameLabel.Size = UDim2.new(1, -10, 0, 15)
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.Text = macroName
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize = 7
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        -- Show macro info
        local infoText = string.format("Frames: %d | Duration: %.1fs | Speed: %.1fx", 
                                     macro.frameCount or #(macro.frames or {}),
                                     macro.duration or (macro.frames and #macro.frames > 0 and macro.frames[#macro.frames].time or 0),
                                     macro.speed or 1)
        
        local macroInfoLabel = Instance.new("TextLabel")
        macroInfoLabel.Parent = macroItem
        macroInfoLabel.BackgroundTransparency = 1
        macroInfoLabel.Position = UDim2.new(0, 5, 0, 20)
        macroInfoLabel.Size = UDim2.new(1, -10, 0, 10)
        macroInfoLabel.Font = Enum.Font.Gotham
        macroInfoLabel.Text = infoText
        macroInfoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        macroInfoLabel.TextSize = 6
        macroInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local renameInput = Instance.new("TextBox")
        renameInput.Name = "RenameInput"
        renameInput.Parent = macroItem
        renameInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        renameInput.BorderSizePixel = 0
        renameInput.Position = UDim2.new(0, 5, 0, 35)
        renameInput.Size = UDim2.new(1, -10, 0, 15)
        renameInput.Font = Enum.Font.Gotham
        renameInput.Text = ""
        renameInput.PlaceholderText = "Enter new name..."
        renameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        renameInput.TextSize = 7
        
        local speedLabel = Instance.new("TextLabel")
        speedLabel.Name = "SpeedLabel"
        speedLabel.Parent = macroItem
        speedLabel.BackgroundTransparency = 1
        speedLabel.Position = UDim2.new(0, 5, 0, 55)
        speedLabel.Size = UDim2.new(0, 50, 0, 15)
        speedLabel.Font = Enum.Font.Gotham
        speedLabel.Text = "Speed:"
        speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        speedLabel.TextSize = 7
        speedLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local speedInput = Instance.new("TextBox")
        speedInput.Name = "SpeedInput"
        speedInput.Parent = macroItem
        speedInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        speedInput.BorderSizePixel = 0
        speedInput.Position = UDim2.new(0, 60, 0, 55)
        speedInput.Size = UDim2.new(0, 40, 0, 15)
        speedInput.Font = Enum.Font.Gotham
        speedInput.Text = tostring(macro.speed or 1)
        speedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        speedInput.TextSize = 7
        speedInput.TextXAlignment = Enum.TextXAlignment.Center
        
        local buttonFrame = Instance.new("Frame")
        buttonFrame.Name = "ButtonFrame"
        buttonFrame.Parent = macroItem
        buttonFrame.BackgroundTransparency = 1
        buttonFrame.Position = UDim2.new(0, 5, 0, 75)
        buttonFrame.Size = UDim2.new(1, -10, 0, 15)
        
        local playButton = Instance.new("TextButton")
        playButton.Name = "PlayButton"
        playButton.Parent = buttonFrame
        playButton.BackgroundColor3 = (macroPlaying and currentMacroName == macroName and not autoPlaying) and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(60, 60, 60)
        playButton.BorderSizePixel = 0
        playButton.Position = UDim2.new(0, 0, 0, 0)
        playButton.Size = UDim2.new(0, 40, 0, 15)
        playButton.Font = Enum.Font.Gotham
        playButton.Text = (macroPlaying and currentMacroName == macroName and not autoPlaying) and "PLAYING" or "PLAY"
        playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        playButton.TextSize = 7
        
        local autoPlayButton = Instance.new("TextButton")
        autoPlayButton.Name = "AutoPlayButton"
        autoPlayButton.Parent = buttonFrame
        autoPlayButton.BackgroundColor3 = (macroPlaying and currentMacroName == macroName and autoPlaying) and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(60, 80, 60)
        autoPlayButton.BorderSizePixel = 0
        autoPlayButton.Position = UDim2.new(0, 45, 0, 0)
        autoPlayButton.Size = UDim2.new(0, 40, 0, 15)
        autoPlayButton.Font = Enum.Font.Gotham
        autoPlayButton.Text = (macroPlaying and currentMacroName == macroName and autoPlaying) and "STOP" or "AUTO"
        autoPlayButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        autoPlayButton.TextSize = 7
        
        local deleteButton = Instance.new("TextButton")
        deleteButton.Name = "DeleteButton"
        deleteButton.Parent = buttonFrame
        deleteButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
        deleteButton.BorderSizePixel = 0
        deleteButton.Position = UDim2.new(0, 90, 0, 0)
        deleteButton.Size = UDim2.new(0, 40, 0, 15)
        deleteButton.Font = Enum.Font.Gotham
        deleteButton.Text = "DELETE"
        deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        deleteButton.TextSize = 7
        
        local renameButton = Instance.new("TextButton")
        renameButton.Name = "RenameButton"
        renameButton.Parent = buttonFrame
        renameButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
        renameButton.BorderSizePixel = 0
        renameButton.Position = UDim2.new(0, 135, 0, 0)
        renameButton.Size = UDim2.new(0, 40, 0, 15)
        renameButton.Font = Enum.Font.Gotham
        renameButton.Text = "RENAME"
        renameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        renameButton.TextSize = 7
        
        -- Additional button row
        local buttonFrame2 = Instance.new("Frame")
        buttonFrame2.Name = "ButtonFrame2"
        buttonFrame2.Parent = macroItem
        buttonFrame2.BackgroundTransparency = 1
        buttonFrame2.Position = UDim2.new(0, 5, 0, 92)
        buttonFrame2.Size = UDim2.new(1, -10, 0, 15)
        
        local syncButton = Instance.new("TextButton")
        syncButton.Name = "SyncButton"
        syncButton.Parent = buttonFrame2
        syncButton.BackgroundColor3 = Color3.fromRGB(80, 60, 120)
        syncButton.BorderSizePixel = 0
        syncButton.Position = UDim2.new(0, 0, 0, 0)
        syncButton.Size = UDim2.new(0, 60, 0, 15)
        syncButton.Font = Enum.Font.Gotham
        syncButton.Text = "RESYNC"
        syncButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        syncButton.TextSize = 6
        
        local exportButton = Instance.new("TextButton")
        exportButton.Name = "ExportButton"
        exportButton.Parent = buttonFrame2
        exportButton.BackgroundColor3 = Color3.fromRGB(60, 120, 80)
        exportButton.BorderSizePixel = 0
        exportButton.Position = UDim2.new(0, 65, 0, 0)
        exportButton.Size = UDim2.new(0, 55, 0, 15)
        exportButton.Font = Enum.Font.Gotham
        exportButton.Text = "EXPORT"
        exportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        exportButton.TextSize = 6
        
        local fileStatusLabel = Instance.new("TextLabel")
        fileStatusLabel.Name = "FileStatusLabel"
        fileStatusLabel.Parent = buttonFrame2
        fileStatusLabel.BackgroundTransparency = 1
        fileStatusLabel.Position = UDim2.new(0, 125, 0, 0)
        fileStatusLabel.Size = UDim2.new(1, -125, 0, 15)
        fileStatusLabel.Font = Enum.Font.Gotham
        fileStatusLabel.Text = "📁 " .. sanitizeFileName(macroName) .. ".json"
        fileStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        fileStatusLabel.TextSize = 6
        fileStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        -- Event handlers
        speedInput.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local newSpeed = tonumber(speedInput.Text)
                if newSpeed and newSpeed > 0 then
                    macro.speed = newSpeed
                    saveToFileSystem(macroName, macro)
                    updateMacroStatus()
                    print("[SUPERTOOL] Updated speed for " .. macroName .. ": " .. newSpeed .. "x")
                else
                    speedInput.Text = tostring(macro.speed or 1)
                end
            end
        end)
        
        playButton.MouseButton1Click:Connect(function()
            if macroPlaying and currentMacroName == macroName and not autoPlaying then
                stopMacroPlayback()
            else
                playMacro(macroName, false)
                Utility.updateMacroList()
            end
        end)
        
        autoPlayButton.MouseButton1Click:Connect(function()
            if macroPlaying and currentMacroName == macroName and autoPlaying then
                stopMacroPlayback()
            else
                playMacro(macroName, true)
                Utility.updateMacroList()
            end
        end)
        
        deleteButton.MouseButton1Click:Connect(function()
            deleteMacro(macroName)
        end)
        
        renameButton.MouseButton1Click:Connect(function()
            if renameInput.Text ~= "" then
                renameMacro(macroName, renameInput.Text)
                renameInput.Text = ""
            end
        end)
        
        renameInput.FocusLost:Connect(function(enterPressed)
            if enterPressed and renameInput.Text ~= "" then
                renameMacro(macroName, renameInput.Text)
                renameInput.Text = ""
            end
        end)
        
        syncButton.MouseButton1Click:Connect(function()
            -- Force resync this macro to JSON
            saveToJSONFile(macroName, macro)
            fileStatusLabel.Text = "📁 ✓ " .. sanitizeFileName(macroName) .. ".json"
            fileStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            wait(2)
            fileStatusLabel.Text = "📁 " .. sanitizeFileName(macroName) .. ".json"
        end)
        
        exportButton.MouseButton1Click:Connect(function()
            -- Show export info
            fileStatusLabel.Text = "📤 Exported to JSON!"
            fileStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
            saveToJSONFile(macroName, macro)
            wait(2)
            fileStatusLabel.Text = "📁 " .. sanitizeFileName(macroName) .. ".json"
            fileStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        end)
        
        -- Hover effects
        playButton.MouseEnter:Connect(function()
            if not (macroPlaying and currentMacroName == macroName and not autoPlaying) then
                playButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            end
        end)
        
        playButton.MouseLeave:Connect(function()
            if macroPlaying and currentMacroName == macroName and not autoPlaying then
                playButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            else
                playButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            end
        end)
        
        autoPlayButton.MouseEnter:Connect(function()
            if not (macroPlaying and currentMacroName == macroName and autoPlaying) then
                autoPlayButton.BackgroundColor3 = Color3.fromRGB(80, 100, 80)
            end
        end)
        
        autoPlayButton.MouseLeave:Connect(function()
            if macroPlaying and currentMacroName == macroName and autoPlaying then
                autoPlayButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            else
                autoPlayButton.BackgroundColor3 = Color3.fromRGB(60, 80, 60)
            end
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
        
        syncButton.MouseEnter:Connect(function()
            syncButton.BackgroundColor3 = Color3.fromRGB(100, 80, 150)
        end)
        
        syncButton.MouseLeave:Connect(function()
            syncButton.BackgroundColor3 = Color3.fromRGB(80, 60, 120)
        end)
        
        exportButton.MouseEnter:Connect(function()
            exportButton.BackgroundColor3 = Color3.fromRGB(80, 150, 100)
        end)
        
        exportButton.MouseLeave:Connect(function()
            exportButton.BackgroundColor3 = Color3.fromRGB(60, 120, 80)
        end)
        
        itemCount = itemCount + 1
    end
    
    -- Add refresh button at bottom
    if itemCount > 0 then
        local refreshFrame = Instance.new("Frame")
        refreshFrame.Name = "RefreshFrame"
        refreshFrame.Parent = MacroScrollFrame
        refreshFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 40)
        refreshFrame.BorderSizePixel = 0
        refreshFrame.Size = UDim2.new(1, -5, 0, 30)
        refreshFrame.LayoutOrder = itemCount + 1
        
        local refreshButton = Instance.new("TextButton")
        refreshButton.Parent = refreshFrame
        refreshButton.BackgroundColor3 = Color3.fromRGB(80, 80, 40)
        refreshButton.BorderSizePixel = 0
        refreshButton.Position = UDim2.new(0, 5, 0, 5)
        refreshButton.Size = UDim2.new(0, 100, 0, 20)
        refreshButton.Font = Enum.Font.Gotham
        refreshButton.Text = "🔄 REFRESH"
        refreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        refreshButton.TextSize = 8
        
        local syncAllButton = Instance.new("TextButton")
        syncAllButton.Parent = refreshFrame
        syncAllButton.BackgroundColor3 = Color3.fromRGB(40, 80, 80)
        syncAllButton.BorderSizePixel = 0
        syncAllButton.Position = UDim2.new(0, 110, 0, 5)
        syncAllButton.Size = UDim2.new(0, 100, 0, 20)
        syncAllButton.Font = Enum.Font.Gotham
        syncAllButton.Text = "💾 SYNC ALL"
        syncAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        syncAllButton.TextSize = 8
        
        refreshButton.MouseButton1Click:Connect(function()
            syncMacrosFromJSON()
            Utility.updateMacroList()
        end)
        
        syncAllButton.MouseButton1Click:Connect(function()
            local count = 0
            for name, data in pairs(savedMacros) do
                saveToJSONFile(name, data)
                count = count + 1
            end
            print("[SUPERTOOL] Synced " .. count .. " macros to JSON files")
        end)
    end
    
    task.wait(0.1)
    if MacroLayout then
        local contentSize = MacroLayout.AbsoluteContentSize
        MacroScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 5)
    end
end

-- Initialize Macro UI elements
local function initMacroUI()
    if MacroFrame then return end
    
    MacroFrame = Instance.new("Frame")
    MacroFrame.Name = "MacroFrame"
    MacroFrame.Parent = ScreenGui
    MacroFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    MacroFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    MacroFrame.BorderSizePixel = 1
    MacroFrame.Position = UDim2.new(0.3, 0, 0.2, 0)
    MacroFrame.Size = UDim2.new(0, 300, 0, 400)
    MacroFrame.Visible = macroFrameVisible
    MacroFrame.Active = true
    MacroFrame.Draggable = true

    local MacroTitle = Instance.new("TextLabel")
    MacroTitle.Name = "Title"
    MacroTitle.Parent = MacroFrame
    MacroTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    MacroTitle.BorderSizePixel = 0
    MacroTitle.Size = UDim2.new(1, 0, 0, 20)
    MacroTitle.Font = Enum.Font.Gotham
    MacroTitle.Text = "MACRO MANAGER - JSON SYNC"
    MacroTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    MacroTitle.TextSize = 8

    local CloseMacroButton = Instance.new("TextButton")
    CloseMacroButton.Name = "CloseButton"
    CloseMacroButton.Parent = MacroFrame
    CloseMacroButton.BackgroundTransparency = 1
    CloseMacroButton.Position = UDim2.new(1, -20, 0, 2)
    CloseMacroButton.Size = UDim2.new(0, 15, 0, 15)
    CloseMacroButton.Font = Enum.Font.GothamBold
    CloseMacroButton.Text = "X"
    CloseMacroButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseMacroButton.TextSize = 8

    MacroInput = Instance.new("TextBox")
    MacroInput.Name = "MacroInput"
    MacroInput.Parent = MacroFrame
    MacroInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    MacroInput.BorderSizePixel = 0
    MacroInput.Position = UDim2.new(0, 5, 0, 25)
    MacroInput.Size = UDim2.new(1, -65, 0, 20)
    MacroInput.Font = Enum.Font.Gotham
    MacroInput.PlaceholderText = "Enter macro name..."
    MacroInput.Text = ""
    MacroInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    MacroInput.TextSize = 7

    SaveMacroButton = Instance.new("TextButton")
    SaveMacroButton.Name = "SaveMacroButton"
    SaveMacroButton.Parent = MacroFrame
    SaveMacroButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    SaveMacroButton.BorderSizePixel = 0
    SaveMacroButton.Position = UDim2.new(1, -55, 0, 25)
    SaveMacroButton.Size = UDim2.new(0, 50, 0, 20)
    SaveMacroButton.Font = Enum.Font.Gotham
    SaveMacroButton.Text = "SAVE"
    SaveMacroButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SaveMacroButton.TextSize = 7

    MacroScrollFrame = Instance.new("ScrollingFrame")
    MacroScrollFrame.Name = "MacroScrollFrame"
    MacroScrollFrame.Parent = MacroFrame
    MacroScrollFrame.BackgroundTransparency = 1
    MacroScrollFrame.Position = UDim2.new(0, 5, 0, 50)
    MacroScrollFrame.Size = UDim2.new(1, -10, 1, -55)
    MacroScrollFrame.ScrollBarThickness = 2
    MacroScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    MacroScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    MacroScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    MacroScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    MacroLayout = Instance.new("UIListLayout")
    MacroLayout.Parent = MacroScrollFrame
    MacroLayout.Padding = UDim.new(0, 2)
    MacroLayout.SortOrder = Enum.SortOrder.LayoutOrder

    MacroStatusLabel = Instance.new("TextLabel")
    MacroStatusLabel.Name = "MacroStatusLabel"
    MacroStatusLabel.Parent = ScreenGui
    MacroStatusLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    MacroStatusLabel.BorderColor3 = Color3.fromRGB(45, 45, 45)
    MacroStatusLabel.BorderSizePixel = 1
    MacroStatusLabel.Position = UDim2.new(1, -200, 0, 10)
    MacroStatusLabel.Size = UDim2.new(0, 190, 0, 20)
    MacroStatusLabel.Font = Enum.Font.Gotham
    MacroStatusLabel.Text = ""
    MacroStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    MacroStatusLabel.TextSize = 8
    MacroStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    MacroStatusLabel.Visible = false

    SaveMacroButton.MouseButton1Click:Connect(function()
        stopMacroRecording()
        MacroFrame.Visible = true
    end)
    
    CloseMacroButton.MouseButton1Click:Connect(function()
        macroFrameVisible = false
        MacroFrame.Visible = false
    end)
end

-- Kill Player
local function killPlayer()
    if humanoid then
        humanoid.Health = 0
    end
end

-- Reset Character
local function resetCharacter()
    if player and player.Character then
        player:LoadCharacter()
    end
end

-- Function to create buttons for Utility features
function Utility.loadUtilityButtons(createButton)
    createButton("Kill Player", killPlayer)
    createButton("Reset Character", resetCharacter)
    createButton("Record Macro", startMacroRecording)
    createButton("Stop Macro", stopMacroRecording)
    createButton("Macro Manager", showMacroManager)
    createButton("Memory Scanner", showMemoryScanner)
end

-- Function to reset Utility states
function Utility.resetStates()
    macroRecording = false
    macroPlaying = false
    autoPlaying = false
    recordingPaused = false
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    currentMacro = {}
    currentMacroName = nil
    lastFrameTime = 0
    macroFrameVisible = false
    if MacroFrame then
        MacroFrame.Visible = false
    end
    
    -- Reset memory scanner
    memoryFrameVisible = false
    foundAddresses = {}
    isScanning = false
    currentSearchValue = nil
    searchHistory = {}
    if MemoryFrame then
        MemoryFrame.Visible = false
    end
    
    updateMacroStatus()
    Utility.updateMacroList()
end

-- Function to set dependencies and handle character respawn
function Utility.init(deps)
    Players = deps.Players
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    ScrollFrame = deps.ScrollFrame
    buttonStates = deps.buttonStates
    player = deps.player
    RunService = deps.RunService
    settings = deps.settings
    ScreenGui = deps.ScreenGui
    
    macroRecording = false
    macroPlaying = false
    autoPlaying = false
    recordingPaused = false
    currentMacro = {}
    savedMacros = {}
    macroFrameVisible = false
    currentMacroName = nil
    lastFrameTime = 0
    
    -- Initialize memory scanner variables
    memoryFrameVisible = false
    foundAddresses = {}
    isScanning = false
    currentSearchValue = nil
    searchHistory = {}
    
    -- Create folder if doesn't exist
    if not isfolder(MACRO_FOLDER_PATH) then
        makefolder(MACRO_FOLDER_PATH)
        print("[SUPERTOOL] Created macro folder: " .. MACRO_FOLDER_PATH)
    end
    
    -- Load macros from JSON files first, then backward compatibility
    ensureFileSystem()
    syncMacrosFromJSON()
    
    -- Load any remaining from old file system
    for macroName, macroData in pairs(fileSystem["Supertool/Macro"]) do
        if not savedMacros[macroName] then
            savedMacros[macroName] = macroData
            -- Auto-sync old macros to JSON
            saveToJSONFile(macroName, macroData)
        end
    end
    
    initMacroUI()
    initMemoryUI()
    
    player.CharacterAdded:Connect(function(newCharacter)
        if newCharacter then
            task.wait(1) -- Wait for character to fully load
            if updateCharacterReferences() then
                if macroRecording and recordingPaused then
                    recordingPaused = false
                    updateMacroStatus()
                    print("[SUPERTOOL] Recording resumed after character respawn")
                end
                if macroPlaying and currentMacroName then
                    task.wait(0.5) -- Small delay to ensure character is stable
                    if autoPlaying then
                        playMacro(currentMacroName, true)
                    else
                        playMacro(currentMacroName, false)
                    end
                end
                updateMacroStatus()
            end
        end
    end)
    
    print("[SUPERTOOL] Utility module initialized with JSON sync to: " .. MACRO_FOLDER_PATH)
end

return Utility-- Utility-related features for MinimalHackGUI by Fari Noveri