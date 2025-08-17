-- Utility-related features for MinimalHackGUI by Fari Noveri
-- Complete version with proper module structure

local Utility = {}

-- Module dependencies (will be set by init function)
local Players, humanoid, rootPart, ScrollFrame, buttonStates, RunService, player, ScreenGui, settings
local connections, disableActiveFeature, isExclusiveFeature

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

-- NEW: Variables for dynamic speed control and auto-pause
local currentPlaybackSpeed = 1
local macroPlaybackPaused = false
local deathPauseTimeout = nil
local respawnWaitTime = 3 -- seconds to wait after respawn before resuming

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

-- FIXED: Helper function untuk save macro ke JSON file dengan validation yang lebih baik
local function saveToJSONFile(macroName, macroData)
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(macroName)
        local fileName = sanitizedName .. ".json"
        local filePath = MACRO_FOLDER_PATH .. fileName
        
        -- PERBAIKAN: Ensure frames exist and are valid before saving
        if not macroData or not macroData.frames or #macroData.frames == 0 then
            warn("[SUPERTOOL] Cannot save empty macro: " .. macroName)
            return false
        end
        
        -- PERBAIKAN: Validate each frame before saving
        local validFrames = {}
        for i, frame in pairs(macroData.frames) do
            if frame and frame.time and frame.cframe and frame.velocity then
                -- Ensure cframe is properly serialized
                local cframeArray
                if typeof(frame.cframe) == "CFrame" then
                    cframeArray = {frame.cframe:GetComponents()}
                elseif typeof(frame.cframe) == "table" and #frame.cframe == 12 then
                    cframeArray = frame.cframe
                else
                    warn("[SUPERTOOL] Invalid CFrame in frame " .. i .. ", skipping")
                    continue
                end
                
                -- Ensure velocity is properly serialized
                local velocityArray
                if typeof(frame.velocity) == "Vector3" then
                    velocityArray = {frame.velocity.X, frame.velocity.Y, frame.velocity.Z}
                elseif typeof(frame.velocity) == "table" and #frame.velocity == 3 then
                    velocityArray = frame.velocity
                else
                    warn("[SUPERTOOL] Invalid Velocity in frame " .. i .. ", using default")
                    velocityArray = {0, 0, 0}
                end
                
                -- Ensure state is properly serialized
                local stateString
                if typeof(frame.state) == "EnumItem" then
                    stateString = frame.state.Name
                elseif typeof(frame.state) == "string" then
                    stateString = frame.state
                else
                    stateString = "Running"
                end
                
                table.insert(validFrames, {
                    time = tonumber(frame.time) or 0,
                    cframe = cframeArray,
                    velocity = velocityArray,
                    walkSpeed = tonumber(frame.walkSpeed) or 16,
                    jumpPower = tonumber(frame.jumpPower) or 50,
                    hipHeight = tonumber(frame.hipHeight) or 0,
                    state = stateString
                })
            else
                warn("[SUPERTOOL] Invalid frame " .. i .. " in macro " .. macroName .. ", skipping")
            end
        end
        
        if #validFrames == 0 then
            warn("[SUPERTOOL] No valid frames to save for macro: " .. macroName)
            return false
        end
        
        -- Create JSON data with metadata
        local jsonData = {
            name = macroName,
            created = macroData.created or os.time(),
            modified = os.time(),
            version = "1.1", -- Updated version for better compatibility
            frames = validFrames,
            startTime = tonumber(macroData.startTime) or 0,
            speed = tonumber(macroData.speed) or 1,
            frameCount = #validFrames,
            duration = validFrames[#validFrames].time or 0
        }
        
        local jsonString = HttpService:JSONEncode(jsonData)
        writefile(filePath, jsonString)
        
        print("[SUPERTOOL] Macro saved: " .. filePath .. " (" .. #validFrames .. " frames)")
        return true
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to save macro to JSON: " .. tostring(error))
        return false
    end
    return true
end

-- FIXED: Helper function untuk load macro dari JSON file dengan validation yang lebih robust
local function loadFromJSONFile(macroName)
    local success, result = pcall(function()
        local sanitizedName = sanitizeFileName(macroName)
        local fileName = sanitizedName .. ".json"
        local filePath = MACRO_FOLDER_PATH .. fileName
        
        if not isfile(filePath) then
            return nil
        end
        
        local jsonString = readfile(filePath)
        if not jsonString or jsonString == "" then
            warn("[SUPERTOOL] Empty JSON file: " .. filePath)
            return nil
        end
        
        local jsonData = HttpService:JSONDecode(jsonString)
        if not jsonData then
            warn("[SUPERTOOL] Failed to decode JSON: " .. filePath)
            return nil
        end
        
        -- PERBAIKAN: More robust frame validation
        local frames = jsonData.frames or {}
        if #frames == 0 then
            warn("[SUPERTOOL] No frames in macro: " .. macroName)
            return nil
        end
        
        -- PERBAIKAN: Better frame validation and conversion
        local validFrames = {}
        for i, frame in pairs(frames) do
            if frame and frame.time and frame.cframe and frame.velocity then
                local validFrame = {
                    time = tonumber(frame.time),
                    walkSpeed = tonumber(frame.walkSpeed) or 16,
                    jumpPower = tonumber(frame.jumpPower) or 50,
                    hipHeight = tonumber(frame.hipHeight) or 0
                }
                
                -- PERBAIKAN: Better CFrame conversion with error handling
                if typeof(frame.cframe) == "table" and #frame.cframe == 12 then
                    local components = frame.cframe
                    -- Validate all components are numbers
                    local allValid = true
                    for j = 1, 12 do
                        if not tonumber(components[j]) then
                            allValid = false
                            break
                        end
                    end
                    
                    if allValid then
                        validFrame.cframe = CFrame.new(unpack(components))
                    else
                        warn("[SUPERTOOL] Invalid CFrame components in frame " .. i)
                        continue
                    end
                else
                    warn("[SUPERTOOL] Invalid CFrame format in frame " .. i)
                    continue
                end
                
                -- PERBAIKAN: Better Velocity conversion with error handling
                if typeof(frame.velocity) == "table" and #frame.velocity == 3 then
                    local vx, vy, vz = tonumber(frame.velocity[1]), tonumber(frame.velocity[2]), tonumber(frame.velocity[3])
                    if vx and vy and vz then
                        validFrame.velocity = Vector3.new(vx, vy, vz)
                    else
                        warn("[SUPERTOOL] Invalid velocity components in frame " .. i)
                        validFrame.velocity = Vector3.new(0, 0, 0)
                    end
                else
                    validFrame.velocity = Vector3.new(0, 0, 0)
                end
                
                -- PERBAIKAN: Better State conversion
                if typeof(frame.state) == "string" and frame.state ~= "" then
                    local stateEnum = Enum.HumanoidStateType[frame.state]
                    validFrame.state = stateEnum or Enum.HumanoidStateType.Running
                else
                    validFrame.state = Enum.HumanoidStateType.Running
                end
                
                -- Only add if time is valid
                if validFrame.time and validFrame.time >= 0 then
                    table.insert(validFrames, validFrame)
                end
            else
                warn("[SUPERTOOL] Missing required fields in frame " .. i)
            end
        end
        
        if #validFrames == 0 then
            warn("[SUPERTOOL] No valid frames found in macro: " .. macroName)
            return nil
        end
        
        -- Sort frames by time to ensure correct order
        table.sort(validFrames, function(a, b) return a.time < b.time end)
        
        -- Return macro data in expected format
        return {
            frames = validFrames,
            startTime = tonumber(jsonData.startTime) or 0,
            speed = tonumber(jsonData.speed) or 1,
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

-- FIXED: Helper function untuk load semua macros dari folder dengan better error handling
local function loadAllMacrosFromFolder()
    local success, result = pcall(function()
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
                    if macroData and macroData.frames and #macroData.frames > 0 then
                        local originalName = macroData.name or fileName
                        loadedMacros[originalName] = macroData
                        print("[SUPERTOOL] Loaded macro: " .. originalName .. " (" .. #macroData.frames .. " frames)")
                    else
                        warn("[SUPERTOOL] Skipped invalid macro file: " .. fileName)
                    end
                end
            end
        end
        
        return loadedMacros
    end)
    
    if success then
        return result or {}
    else
        warn("[SUPERTOOL] Failed to load macros from folder: " .. tostring(result))
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

-- FIXED: Function untuk sync macros dari JSON ke memory pada startup
local function syncMacrosFromJSON()
    local jsonMacros = loadAllMacrosFromFolder()
    local count = 0
    for macroName, macroData in pairs(jsonMacros) do
        if macroData and macroData.frames and #macroData.frames > 0 then
            savedMacros[macroName] = macroData
            fileSystem["Supertool/Macro"][macroName] = macroData
            count = count + 1
        end
    end
    print("[SUPERTOOL] Synced " .. count .. " valid macros from JSON files")
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

-- Delete Macro
local function deleteMacro(macroName)
    if savedMacros[macroName] then
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

-- IMPROVED: Update Macro List UI with dynamic speed control and better status display
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
    local macroCount = 0
    for _ in pairs(savedMacros) do macroCount = macroCount + 1 end
    infoLabel.Text = "JSON Sync: " .. MACRO_FOLDER_PATH .. " (" .. macroCount .. " macros)"
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
        
        -- Show macro info with better data handling
        local frameCount = macro.frameCount or (macro.frames and #macro.frames) or 0
        local duration = macro.duration or (macro.frames and #macro.frames > 0 and macro.frames[#macro.frames].time) or 0
        local speed = currentPlaybackSpeed or macro.speed or 1
        local infoText = string.format("Frames: %d | Duration: %.1fs | Speed: %.1fx", frameCount, duration, speed)
        
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
        speedInput.Text = tostring(speed)
        speedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        speedInput.TextSize = 7
        speedInput.TextXAlignment = Enum.TextXAlignment.Center
        
        -- NEW: Real-time speed update button
        local updateSpeedBtn = Instance.new("TextButton")
        updateSpeedBtn.Name = "UpdateSpeedBtn"
        updateSpeedBtn.Parent = macroItem
        updateSpeedBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
        updateSpeedBtn.BorderSizePixel = 0
        updateSpeedBtn.Position = UDim2.new(0, 105, 0, 55)
        updateSpeedBtn.Size = UDim2.new(0, 35, 0, 15)
        updateSpeedBtn.Font = Enum.Font.Gotham
        updateSpeedBtn.Text = "UPDATE"
        updateSpeedBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        updateSpeedBtn.TextSize = 6
        
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
        local playText = "PLAY"
        if macroPlaying and currentMacroName == macroName and not autoPlaying then
            playText = macroPlaybackPaused and "PAUSED" or "PLAYING"
        end
        playButton.Text = playText
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
        local autoText = "AUTO"
        if macroPlaying and currentMacroName == macroName and autoPlaying then
            autoText = macroPlaybackPaused and "PAUSED" or "STOP"
        end
        autoPlayButton.Text = autoText
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
        
        -- IMPROVED: Event handlers with real-time speed update and better status handling
        speedInput.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local newSpeed = tonumber(speedInput.Text)
                if newSpeed and newSpeed > 0 then
                    macro.speed = newSpeed
                    saveToFileSystem(macroName, macro)
                    -- If this macro is currently playing, update the playback speed immediately
                    if macroPlaying and currentMacroName == macroName then
                        updatePlaybackSpeed(macroName, newSpeed)
                        Utility.updateMacroList() -- Refresh to show updated speed
                    end
                    updateMacroStatus()
                    print("[SUPERTOOL] Updated speed for " .. macroName .. ": " .. newSpeed .. "x")
                else
                    speedInput.Text = tostring(macro.speed or 1)
                end
            end
        end)
        
        -- NEW: Real-time speed update button handler
        updateSpeedBtn.MouseButton1Click:Connect(function()
            local newSpeed = tonumber(speedInput.Text)
            if newSpeed and newSpeed > 0 then
                macro.speed = newSpeed
                saveToFileSystem(macroName, macro)
                -- If this macro is currently playing, update the playback speed immediately
                if macroPlaying and currentMacroName == macroName then
                    updatePlaybackSpeed(macroName, newSpeed)
                    Utility.updateMacroList() -- Refresh to show updated speed
                end
                updateMacroStatus()
                print("[SUPERTOOL] Real-time speed update for " .. macroName .. ": " .. newSpeed .. "x")
                
                -- Visual feedback
                updateSpeedBtn.BackgroundColor3 = Color3.fromRGB(120, 200, 120)
                updateSpeedBtn.Text = "✓"
                wait(1)
                updateSpeedBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
                updateSpeedBtn.Text = "UPDATE"
            else
                speedInput.Text = tostring(macro.speed or 1)
                -- Error feedback
                updateSpeedBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
                updateSpeedBtn.Text = "✗"
                wait(1)
                updateSpeedBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
                updateSpeedBtn.Text = "UPDATE"
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
        
        -- Hover effects for better UX
        local function setupHoverEffect(button, normalColor, hoverColor)
            button.MouseEnter:Connect(function()
                button.BackgroundColor3 = hoverColor
            end)
            button.MouseLeave:Connect(function()
                button.BackgroundColor3 = normalColor
            end)
        end
        
        setupHoverEffect(playButton, playButton.BackgroundColor3, Color3.fromRGB(80, 80, 80))
        setupHoverEffect(autoPlayButton, autoPlayButton.BackgroundColor3, Color3.fromRGB(80, 100, 80))
        setupHoverEffect(deleteButton, Color3.fromRGB(120, 40, 40), Color3.fromRGB(150, 50, 50))
        setupHoverEffect(renameButton, Color3.fromRGB(40, 80, 40), Color3.fromRGB(50, 100, 50))
        setupHoverEffect(syncButton, Color3.fromRGB(80, 60, 120), Color3.fromRGB(100, 80, 150))
        setupHoverEffect(exportButton, Color3.fromRGB(60, 120, 80), Color3.fromRGB(80, 150, 100))
        setupHoverEffect(updateSpeedBtn, Color3.fromRGB(80, 60, 40), Color3.fromRGB(100, 80, 60))
        
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
    MacroTitle.Text = "MACRO MANAGER - IMPROVED v1.1"
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

    -- IMPROVED: Status label with better positioning and styling
    MacroStatusLabel = Instance.new("TextLabel")
    MacroStatusLabel.Name = "MacroStatusLabel"
    MacroStatusLabel.Parent = ScreenGui
    MacroStatusLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    MacroStatusLabel.BorderColor3 = Color3.fromRGB(45, 45, 45)
    MacroStatusLabel.BorderSizePixel = 1
    MacroStatusLabel.Position = UDim2.new(1, -250, 0, 10)
    MacroStatusLabel.Size = UDim2.new(0, 240, 0, 25)
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

-- NEW: Function to handle death and respawn with auto-pause/resume
local function handleCharacterDeath()
    if macroPlaying then
        macroPlaybackPaused = true
        print("[SUPERTOOL] Macro paused due to character death")
        updateMacroStatus()
        
        -- Clear any existing timeout
        if deathPauseTimeout then
            deathPauseTimeout:Disconnect()
            deathPauseTimeout = nil
        end
        
        -- Wait for respawn and then resume after delay
        player.CharacterAdded:Connect(function(newCharacter)
            if macroPlaybackPaused then
                deathPauseTimeout = task.wait(respawnWaitTime)
                if macroPlaybackPaused and macroPlaying then
                    macroPlaybackPaused = false
                    print("[SUPERTOOL] Macro resumed after respawn")
                    updateMacroStatus()
                end
            end
        end)
    end
end

-- NEW: Update macro status display with pause information
local function updateMacroStatus()
    if not MacroStatusLabel then return end
    if macroRecording then
        MacroStatusLabel.Text = recordingPaused and "Recording Paused" or "Recording Macro"
        MacroStatusLabel.Visible = true
    elseif macroPlaying and currentMacroName then
        local macro = savedMacros[currentMacroName] or loadFromFileSystem(currentMacroName)
        local speed = currentPlaybackSpeed or (macro and macro.speed) or 1
        local statusText = (autoPlaying and "Auto-Playing" or "Playing") .. " Macro: " .. currentMacroName .. " (Speed: " .. speed .. "x)"
        if macroPlaybackPaused then
            statusText = statusText .. " [PAUSED]"
        end
        MacroStatusLabel.Text = statusText
        MacroStatusLabel.Visible = true
    else
        MacroStatusLabel.Visible = false
    end
end

-- Update character references after respawn
local function updateCharacterReferences()
    if player.Character then
        humanoid = player.Character:WaitForChild("Humanoid", 30)
        rootPart = player.Character:WaitForChild("HumanoidRootPart", 30)
        
        -- Setup death handler for auto-pause
        if humanoid then
            humanoid.Died:Connect(handleCharacterDeath)
        end
        
        if macroRecording and recordingPaused then
            recordingPaused = false
            updateMacroStatus()
        end
    end
end

-- Record Macro dengan perbaikan untuk menyimpan state dengan benar
local function startMacroRecording()
    if macroRecording or macroPlaying then return end
    macroRecording = true
    recordingPaused = false
    currentMacro = {frames = {}, startTime = tick(), speed = 1}
    lastFrameTime = 0
    
    updateCharacterReferences()
    updateMacroStatus()
    
    local function setupDeathHandler()
        if humanoid then
            humanoid.Died:Connect(function()
                if macroRecording then
                    recordingPaused = true
                    updateMacroStatus()
                end
            end)
        end
    end
    
    setupDeathHandler()
    
    recordConnection = RunService.Heartbeat:Connect(function()
        if not macroRecording or recordingPaused then return end
        
        if not humanoid or not rootPart then
            updateCharacterReferences()
            if not humanoid or not rootPart then return end
            setupDeathHandler()
        end
        
        local frame = {
            time = tick() - currentMacro.startTime,
            cframe = {rootPart.CFrame:GetComponents()}, -- Store as table array for JSON encoding
            velocity = {rootPart.Velocity.X, rootPart.Velocity.Y, rootPart.Velocity.Z}, -- Store as table array
            walkSpeed = humanoid.WalkSpeed,
            jumpPower = humanoid.JumpPower,
            hipHeight = humanoid.HipHeight,
            state = humanoid:GetState().Name -- Store as string
        }
        table.insert(currentMacro.frames, frame)
        lastFrameTime = frame.time
    end)
end

-- Stop Macro Recording dengan perbaikan untuk save yang benar
local function stopMacroRecording()
    if not macroRecording then return end
    macroRecording = false
    recordingPaused = false
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    
    local macroName = MacroInput.Text
    if macroName == "" then
        macroName = "Macro_" .. (os.time() % 10000) -- Use timestamp for uniqueness
    end
    
    -- Ensure macro has valid frames before saving
    if #currentMacro.frames == 0 then
        warn("Cannot save empty macro")
        return
    end
    
    -- Set metadata
    currentMacro.frameCount = #currentMacro.frames
    currentMacro.duration = currentMacro.frames[#currentMacro.frames].time
    currentMacro.created = os.time()
    
    -- Save to both memory and JSON file
    savedMacros[macroName] = currentMacro
    saveToFileSystem(macroName, currentMacro)
    
    MacroInput.Text = ""
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
    macroPlaybackPaused = false
    currentPlaybackSpeed = 1
    
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    if deathPauseTimeout then
        deathPauseTimeout:Disconnect()
        deathPauseTimeout = nil
    end
    if humanoid then
        humanoid.WalkSpeed = settings.WalkSpeed.value or 16
    end
    currentMacroName = nil
    Utility.updateMacroList()
    updateMacroStatus()
end

-- NEW: Function to update playback speed dynamically
local function updatePlaybackSpeed(macroName, newSpeed)
    if macroPlaying and currentMacroName == macroName then
        currentPlaybackSpeed = newSpeed
        -- Also update the macro data for future use
        local macro = savedMacros[macroName]
        if macro then
            macro.speed = newSpeed
            saveToFileSystem(macroName, macro)
        end
        updateMacroStatus()
        print("[SUPERTOOL] Updated playback speed to " .. newSpeed .. "x")
    end
end

-- IMPROVED: Play Macro with dynamic speed control and auto-pause/resume
local function playMacro(macroName, autoPlay)
    if macroRecording or macroPlaying or not humanoid or not rootPart then return end
    local macro = savedMacros[macroName] or loadFromFileSystem(macroName)
    if not macro or not macro.frames or #macro.frames == 0 then 
        warn("[SUPERTOOL] Invalid or empty macro: " .. macroName)
        return 
    end
    
    macroPlaying = true
    autoPlaying = autoPlay or false
    macroPlaybackPaused = false
    currentMacroName = macroName
    currentPlaybackSpeed = macro.speed or 1
    humanoid.WalkSpeed = 0
    updateMacroStatus()
    
    -- Setup death handler for auto-pause
    if humanoid then
        humanoid.Died:Connect(handleCharacterDeath)
    end
    
    print("[SUPERTOOL] Playing macro: " .. macroName .. " (Auto: " .. tostring(autoPlaying) .. ", Speed: " .. currentPlaybackSpeed .. "x)")
    
    local function playSingleMacro()
        local startTime = tick()
        local index = 1
        
        playbackConnection = RunService.Heartbeat:Connect(function()
            -- Check if macro should stop
            if not macroPlaying or not player.Character then
                if playbackConnection then playbackConnection:Disconnect() end
                macroPlaying = false
                autoPlaying = false
                macroPlaybackPaused = false
                if humanoid then humanoid.WalkSpeed = settings.WalkSpeed.value or 16 end
                currentMacroName = nil
                currentPlaybackSpeed = 1
                Utility.updateMacroList()
                updateMacroStatus()
                return
            end
            
            -- Pause if character died
            if macroPlaybackPaused then
                return
            end
            
            if not humanoid or not rootPart then
                updateCharacterReferences()
                if not humanoid or not rootPart then
                    if playbackConnection then playbackConnection:Disconnect() end
                    macroPlaying = false
                    autoPlaying = false
                    macroPlaybackPaused = false
                    currentMacroName = nil
                    currentPlaybackSpeed = 1
                    Utility.updateMacroList()
                    updateMacroStatus()
                    return
                end
            end
            
            if index > #macro.frames then
                if autoPlaying then
                    index = 1
                    startTime = tick()
                else
                    if playbackConnection then playbackConnection:Disconnect() end
                    macroPlaying = false
                    macroPlaybackPaused = false
                    if humanoid then humanoid.WalkSpeed = settings.WalkSpeed.value or 16 end
                    currentMacroName = nil
                    currentPlaybackSpeed = 1
                    Utility.updateMacroList()
                    updateMacroStatus()
                    return
                end
            end
            
            local frame = macro.frames[index]
            local scaledTime = frame.time / currentPlaybackSpeed -- Use current dynamic speed
            while index <= #macro.frames and scaledTime <= (tick() - startTime) do
                if frame.cframe and frame.velocity and frame.walkSpeed and frame.jumpPower and frame.hipHeight and frame.state then
                    -- Ensure proper data types when loading
                    local cframe = frame.cframe
                    if typeof(cframe) == "table" then
                        cframe = CFrame.new(unpack(cframe))
                    end
                    
                    local velocity = frame.velocity
                    if typeof(velocity) == "table" then
                        velocity = Vector3.new(unpack(velocity))
                    end
                    
                    local state = frame.state
                    if typeof(state) == "string" then
                        state = Enum.HumanoidStateType[state] or Enum.HumanoidStateType.Running
                    end
                    
                    rootPart.CFrame = cframe
                    rootPart.Velocity = velocity
                    humanoid.WalkSpeed = frame.walkSpeed
                    humanoid.JumpPower = frame.jumpPower
                    humanoid.HipHeight = frame.hipHeight
                    humanoid:ChangeState(state)
                end
                index = index + 1
                frame = macro.frames[index] or frame
                scaledTime = frame.time / currentPlaybackSpeed -- Use current dynamic speed
            end
        end)
    end
    
    playSingleMacro()
end

-- Kill Player
local function killPlayer()
    if humanoid then
        humanoid.Health = 0
        print("[SUPERTOOL] Player killed")
    end
end

-- Reset Character
local function resetCharacter()
    if player and player.Character then
        player:LoadCharacter()
        print("[SUPERTOOL] Character reset")
    end
end

-- Initialize function (REQUIRED for module system)
function Utility.init(deps)
    -- Set dependencies
    Players = deps.Players
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    RunService = deps.RunService
    player = deps.player
    ScreenGui = deps.ScreenGui
    settings = deps.settings
    connections = deps.connections
    disableActiveFeature = deps.disableActiveFeature
    isExclusiveFeature = deps.isExclusiveFeature
    
    -- Sync macros on startup
    syncMacrosFromJSON()
    
    print("[SUPERTOOL] Utility module initialized successfully")
    return true
end

-- Load buttons function (REQUIRED for module system)
function Utility.loadUtilityButtons(createButton)
    if not createButton or type(createButton) ~= "function" then
        error("createButton function is required")
        return
    end
    
    print("[SUPERTOOL] Loading utility buttons...")
    
    -- Create buttons
    createButton("Kill Player", killPlayer)
    createButton("Reset Character", resetCharacter)
    createButton("Record Macro", startMacroRecording)
    createButton("Stop Macro", stopMacroRecording)
    createButton("Macro Manager", showMacroManager)
    createButton("Memory Scanner", showMemoryScanner)
    
    print("[SUPERTOOL] Utility buttons loaded successfully")
end

-- Reset states function (REQUIRED for module system)
function Utility.resetStates()
    -- Reset all utility states
    macroRecording = false
    macroPlaying = false
    autoPlaying = false
    macroPlaybackPaused = false
    
    -- Disconnect connections
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    
    print("[SUPERTOOL] Utility states reset")
end

-- Return the module
return Utility