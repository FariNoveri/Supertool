-- Utility-related features for MinimalHackGUI by Fari Noveri
-- Fixed version with improved error handling and removed memory scanner

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
        
        -- PERBAIKAN: More lenient frame validation - always try to save something
        if not macroData or not macroData.frames then
            macroData = macroData or {}
            macroData.frames = {}
            warn("[SUPERTOOL] Saving macro with empty frames: " .. macroName)
        end
        
        -- PERBAIKAN: More flexible frame validation - don't skip frames too easily
        local validFrames = {}
        for i, frame in pairs(macroData.frames or {}) do
            if frame then
                -- Create a valid frame even with missing data
                local validFrame = {
                    time = tonumber(frame.time) or (i * 0.1), -- Default time if missing
                    walkSpeed = tonumber(frame.walkSpeed) or 16,
                    jumpPower = tonumber(frame.jumpPower) or 50,
                    hipHeight = tonumber(frame.hipHeight) or 0,
                    state = "Running" -- Default state
                }
                
                -- Handle CFrame - more flexible approach
                if frame.cframe then
                    if typeof(frame.cframe) == "CFrame" then
                        validFrame.cframe = {frame.cframe:GetComponents()}
                    elseif typeof(frame.cframe) == "table" and #frame.cframe >= 12 then
                        validFrame.cframe = frame.cframe
                    else
                        -- Create default CFrame if invalid
                        validFrame.cframe = {0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1}
                        warn("[SUPERTOOL] Using default CFrame for frame " .. i)
                    end
                else
                    -- Default CFrame at origin
                    validFrame.cframe = {0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1}
                end
                
                -- Handle Velocity - more flexible approach
                if frame.velocity then
                    if typeof(frame.velocity) == "Vector3" then
                        validFrame.velocity = {frame.velocity.X, frame.velocity.Y, frame.velocity.Z}
                    elseif typeof(frame.velocity) == "table" and #frame.velocity >= 3 then
                        validFrame.velocity = frame.velocity
                    else
                        validFrame.velocity = {0, 0, 0}
                    end
                else
                    validFrame.velocity = {0, 0, 0}
                end
                
                -- Handle State
                if frame.state then
                    if typeof(frame.state) == "EnumItem" then
                        validFrame.state = frame.state.Name
                    elseif typeof(frame.state) == "string" then
                        validFrame.state = frame.state
                    end
                end
                
                table.insert(validFrames, validFrame)
            end
        end
        
        -- PERBAIKAN: Save even if no valid frames (for debugging)
        local jsonData = {
            name = macroName,
            created = macroData.created or os.time(),
            modified = os.time(),
            version = "1.2", -- Updated version
            frames = validFrames,
            startTime = tonumber(macroData.startTime) or 0,
            speed = tonumber(macroData.speed) or 1,
            frameCount = #validFrames,
            duration = #validFrames > 0 and (validFrames[#validFrames].time or 0) or 0
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
        
        -- PERBAIKAN: More robust frame validation - don't reject completely
        local frames = jsonData.frames or {}
        local validFrames = {}
        
        for i, frame in pairs(frames) do
            if frame then
                local validFrame = {
                    time = tonumber(frame.time) or (i * 0.1),
                    walkSpeed = tonumber(frame.walkSpeed) or 16,
                    jumpPower = tonumber(frame.jumpPower) or 50,
                    hipHeight = tonumber(frame.hipHeight) or 0
                }
                
                -- PERBAIKAN: Better CFrame conversion with fallback
                if frame.cframe and typeof(frame.cframe) == "table" and #frame.cframe >= 12 then
                    local components = {}
                    for j = 1, 12 do
                        components[j] = tonumber(frame.cframe[j]) or (j <= 3 and 0 or (j == 4 or j == 8 or j == 12) and 1 or 0)
                    end
                    validFrame.cframe = CFrame.new(unpack(components))
                else
                    validFrame.cframe = CFrame.new(0, 0, 0)
                end
                
                -- PERBAIKAN: Better Velocity conversion with fallback
                if frame.velocity and typeof(frame.velocity) == "table" and #frame.velocity >= 3 then
                    local vx, vy, vz = tonumber(frame.velocity[1]) or 0, tonumber(frame.velocity[2]) or 0, tonumber(frame.velocity[3]) or 0
                    validFrame.velocity = Vector3.new(vx, vy, vz)
                else
                    validFrame.velocity = Vector3.new(0, 0, 0)
                end
                
                -- PERBAIKAN: Better State conversion
                if frame.state and typeof(frame.state) == "string" and frame.state ~= "" then
                    local stateEnum = Enum.HumanoidStateType[frame.state]
                    validFrame.state = stateEnum or Enum.HumanoidStateType.Running
                else
                    validFrame.state = Enum.HumanoidStateType.Running
                end
                
                table.insert(validFrames, validFrame)
            end
        end
        
        -- PERBAIKAN: Don't reject completely if no valid frames, return with empty frames
        if #validFrames == 0 then
            warn("[SUPERTOOL] No valid frames found in macro: " .. macroName .. ", creating empty macro")
            validFrames = {} -- Keep empty but don't return nil
        end
        
        -- Sort frames by time to ensure correct order
        if #validFrames > 1 then
            table.sort(validFrames, function(a, b) return a.time < b.time end)
        end
        
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
            duration = #validFrames > 0 and (validFrames[#validFrames].time or 0) or 0
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
                    if macroData then -- Don't require frames to be non-empty
                        local originalName = macroData.name or fileName
                        loadedMacros[originalName] = macroData
                        print("[SUPERTOOL] Loaded macro: " .. originalName .. " (" .. #(macroData.frames or {}) .. " frames)")
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
        if macroData then -- Don't require frames to exist
            savedMacros[macroName] = macroData
            fileSystem["Supertool/Macro"][macroName] = macroData
            count = count + 1
        end
    end
    print("[SUPERTOOL] Synced " .. count .. " macros from JSON files")
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

-- FIXED: Show Macro Manager dengan proper error handling
local function showMacroManager()
    if not ScreenGui then
        warn("[SUPERTOOL] ScreenGui not available")
        return
    end
    
    macroFrameVisible = true
    if not MacroFrame then
        initMacroUI()
    end
    if MacroFrame then
        MacroFrame.Visible = true
        Utility.updateMacroList()
    else
        warn("[SUPERTOOL] Failed to create MacroFrame")
    end
end

-- IMPROVED: Update Macro List UI with better error handling
function Utility.updateMacroList()
    if not MacroScrollFrame then 
        warn("[SUPERTOOL] MacroScrollFrame not available")
        return 
    end
    
    -- Clear existing items safely
    for _, child in pairs(MacroScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            pcall(function() child:Destroy() end)
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
        local success = pcall(function()
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
            
            -- Real-time speed update button
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
            
            -- Event handlers with better error handling
            speedInput.FocusLost:Connect(function(enterPressed)
                pcall(function()
                    if enterPressed then
                        local newSpeed = tonumber(speedInput.Text)
                        if newSpeed and newSpeed > 0 then
                            macro.speed = newSpeed
                            saveToFileSystem(macroName, macro)
                            if macroPlaying and currentMacroName == macroName then
                                updatePlaybackSpeed(macroName, newSpeed)
                                Utility.updateMacroList()
                            end
                            updateMacroStatus()
                            print("[SUPERTOOL] Updated speed for " .. macroName .. ": " .. newSpeed .. "x")
                        else
                            speedInput.Text = tostring(macro.speed or 1)
                        end
                    end
                end)
            end)
            
            updateSpeedBtn.MouseButton1Click:Connect(function()
                pcall(function()
                    local newSpeed = tonumber(speedInput.Text)
                    if newSpeed and newSpeed > 0 then
                        macro.speed = newSpeed
                        saveToFileSystem(macroName, macro)
                        if macroPlaying and currentMacroName == macroName then
                            updatePlaybackSpeed(macroName, newSpeed)
                            Utility.updateMacroList()
                        end
                        updateMacroStatus()
                        print("[SUPERTOOL] Real-time speed update for " .. macroName .. ": " .. newSpeed .. "x")
                        
                        updateSpeedBtn.BackgroundColor3 = Color3.fromRGB(120, 200, 120)
                        updateSpeedBtn.Text = "✓"
                        task.spawn(function()
                            wait(1)
                            if updateSpeedBtn and updateSpeedBtn.Parent then
                                updateSpeedBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
                                updateSpeedBtn.Text = "UPDATE"
                            end
                        end)
                    else
                        speedInput.Text = tostring(macro.speed or 1)
                        updateSpeedBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
                        updateSpeedBtn.Text = "✗"
                        task.spawn(function()
                            wait(1)
                            if updateSpeedBtn and updateSpeedBtn.Parent then
                                updateSpeedBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
                                updateSpeedBtn.Text = "UPDATE"
                            end
                        end)
                    end
                end)
            end)
            
            playButton.MouseButton1Click:Connect(function()
                pcall(function()
                    if macroPlaying and currentMacroName == macroName and not autoPlaying then
                        stopMacroPlayback()
                    else
                        playMacro(macroName, false)
                        Utility.updateMacroList()
                    end
                end)
            end)
            
            autoPlayButton.MouseButton1Click:Connect(function()
                pcall(function()
                    if macroPlaying and currentMacroName == macroName and autoPlaying then
                        stopMacroPlayback()
                    else
                        playMacro(macroName, true)
                        Utility.updateMacroList()
                    end
                end)
            end)
            
            deleteButton.MouseButton1Click:Connect(function()
                pcall(function()
                    deleteMacro(macroName)
                end)
            end)
            
            renameButton.MouseButton1Click:Connect(function()
                pcall(function()
                    if renameInput.Text ~= "" then
                        renameMacro(macroName, renameInput.Text)
                        renameInput.Text = ""
                    end
                end)
            end)
            
            renameInput.FocusLost:Connect(function(enterPressed)
                pcall(function()
                    if enterPressed and renameInput.Text ~= "" then
                        renameMacro(macroName, renameInput.Text)
                        renameInput.Text = ""
                    end
                end)
            end)
            
            syncButton.MouseButton1Click:Connect(function()
                pcall(function()
                    saveToJSONFile(macroName, macro)
                    fileStatusLabel.Text = "📁 ✓ " .. sanitizeFileName(macroName) .. ".json"
                    fileStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                    task.spawn(function()
                        wait(2)
                        if fileStatusLabel and fileStatusLabel.Parent then
                            fileStatusLabel.Text = "📁 " .. sanitizeFileName(macroName) .. ".json"
                        end
                    end)
                end)
            end)
            
            exportButton.MouseButton1Click:Connect(function()
                pcall(function()
                    fileStatusLabel.Text = "📤 Exported to JSON!"
                    fileStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
                    saveToJSONFile(macroName, macro)
                    task.spawn(function()
                        wait(2)
                        if fileStatusLabel and fileStatusLabel.Parent then
                            fileStatusLabel.Text = "📁 " .. sanitizeFileName(macroName) .. ".json"
                            fileStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                        end
                    end)
                end)
            end)
            
            itemCount = itemCount + 1
        end)
        
        if not success then
            warn("[SUPERTOOL] Failed to create UI for macro: " .. macroName)
        end
    end
    
    -- Add refresh button at bottom with error handling
    if itemCount > 0 then
        pcall(function()
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
                pcall(function()
                    syncMacrosFromJSON()
                    Utility.updateMacroList()
                end)
            end)
            
            syncAllButton.MouseButton1Click:Connect(function()
                pcall(function()
                    local count = 0
                    for name, data in pairs(savedMacros) do
                        saveToJSONFile(name, data)
                        count = count + 1
                    end
                    print("[SUPERTOOL] Synced " .. count .. " macros to JSON files")
                end)
            end)
        end)
    end
    
    -- Update scroll size safely
    pcall(function()
        task.wait(0.1)
        if MacroLayout then
            local contentSize = MacroLayout.AbsoluteContentSize
            MacroScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 5)
        end
    end)
end

-- Initialize Macro UI elements with better error handling
local function initMacroUI()
    if MacroFrame or not ScreenGui then return end
    
    local success = pcall(function()
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
        MacroTitle.Text = "MACRO MANAGER - FIXED v1.2"
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
        MacroStatusLabel.Position = UDim2.new(1, -250, 0, 10)
        MacroStatusLabel.Size = UDim2.new(0, 240, 0, 25)
        MacroStatusLabel.Font = Enum.Font.Gotham
        MacroStatusLabel.Text = ""
        MacroStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        MacroStatusLabel.TextSize = 8
        MacroStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
        MacroStatusLabel.Visible = false

        SaveMacroButton.MouseButton1Click:Connect(function()
            pcall(function()
                stopMacroRecording()
                if MacroFrame then
                    MacroFrame.Visible = true
                end
            end)
        end)
        
        CloseMacroButton.MouseButton1Click:Connect(function()
            pcall(function()
                macroFrameVisible = false
                if MacroFrame then
                    MacroFrame.Visible = false
                end
            end)
        end)
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to create Macro UI")
        MacroFrame = nil
    end
end

-- NEW: Function to handle death and respawn with auto-pause/resume
local function handleCharacterDeath()
    if macroPlaying then
        macroPlaybackPaused = true
        print("[SUPERTOOL] Macro paused due to character death")
        updateMacroStatus()
        
        -- Clear any existing timeout
        if deathPauseTimeout then
            pcall(function() deathPauseTimeout:Disconnect() end)
            deathPauseTimeout = nil
        end
        
        -- Wait for respawn and then resume after delay
        local connection
        connection = player.CharacterAdded:Connect(function(newCharacter)
            if macroPlaybackPaused then
                task.spawn(function()
                    wait(respawnWaitTime)
                    if macroPlaybackPaused and macroPlaying then
                        macroPlaybackPaused = false
                        print("[SUPERTOOL] Macro resumed after respawn")
                        updateMacroStatus()
                    end
                end)
            end
            if connection then
                connection:Disconnect()
            end
        end)
    end
end

-- Update macro status display with pause information
local function updateMacroStatus()
    pcall(function()
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
    end)
end

-- Update character references after respawn
local function updateCharacterReferences()
    pcall(function()
        if player and player.Character then
            humanoid = player.Character:FindFirstChild("Humanoid")
            rootPart = player.Character:FindFirstChild("HumanoidRootPart")
            
            -- Setup death handler for auto-pause
            if humanoid then
                humanoid.Died:Connect(handleCharacterDeath)
            end
            
            if macroRecording and recordingPaused then
                recordingPaused = false
                updateMacroStatus()
            end
        end
    end)
end

-- FIXED: Record Macro with better error handling and timeout prevention
local function startMacroRecording()
    if macroRecording or macroPlaying then return end
    
    pcall(function()
        macroRecording = true
        recordingPaused = false
        currentMacro = {frames = {}, startTime = tick(), speed = 1}
        lastFrameTime = 0
        
        updateCharacterReferences()
        updateMacroStatus()
        
        local frameCount = 0
        local maxFrames = 3000 -- Prevent excessive memory usage
        local lastRecordTime = 0
        local recordInterval = 0.1 -- Record every 0.1 seconds to prevent lag
        
        local function setupDeathHandler()
            pcall(function()
                if humanoid then
                    humanoid.Died:Connect(function()
                        if macroRecording then
                            recordingPaused = true
                            updateMacroStatus()
                        end
                    end)
                end
            end)
        end
        
        setupDeathHandler()
        
        recordConnection = RunService.Heartbeat:Connect(function()
            pcall(function()
                if not macroRecording or recordingPaused then return end
                
                -- Prevent timeout by limiting recording rate
                local currentTime = tick()
                if currentTime - lastRecordTime < recordInterval then
                    return
                end
                lastRecordTime = currentTime
                
                if frameCount >= maxFrames then
                    print("[SUPERTOOL] Max frames reached, stopping recording")
                    stopMacroRecording()
                    return
                end
                
                if not humanoid or not rootPart then
                    updateCharacterReferences()
                    if not humanoid or not rootPart then return end
                    setupDeathHandler()
                end
                
                local frame = {
                    time = currentTime - currentMacro.startTime,
                    cframe = {rootPart.CFrame:GetComponents()},
                    velocity = {rootPart.Velocity.X, rootPart.Velocity.Y, rootPart.Velocity.Z},
                    walkSpeed = humanoid.WalkSpeed or 16,
                    jumpPower = humanoid.JumpPower or 50,
                    hipHeight = humanoid.HipHeight or 0,
                    state = humanoid:GetState().Name or "Running"
                }
                table.insert(currentMacro.frames, frame)
                frameCount = frameCount + 1
                lastFrameTime = frame.time
            end)
        end)
    end)
end

-- FIXED: Stop Macro Recording with better error handling
local function stopMacroRecording()
    if not macroRecording then return end
    
    pcall(function()
        macroRecording = false
        recordingPaused = false
        if recordConnection then
            recordConnection:Disconnect()
            recordConnection = nil
        end
        
        local macroName = ""
        if MacroInput and MacroInput.Text then
            macroName = MacroInput.Text
        end
        
        if macroName == "" then
            macroName = "Macro_" .. (os.time() % 10000)
        end
        
        -- Always save, even with empty frames for debugging
        currentMacro.frameCount = #currentMacro.frames
        currentMacro.duration = #currentMacro.frames > 0 and currentMacro.frames[#currentMacro.frames].time or 0
        currentMacro.created = os.time()
        
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
    end)
end

-- Stop Macro Playback with better error handling
local function stopMacroPlayback()
    pcall(function()
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
            pcall(function() deathPauseTimeout:Disconnect() end)
            deathPauseTimeout = nil
        end
        if humanoid then
            humanoid.WalkSpeed = settings.WalkSpeed and settings.WalkSpeed.value or 16
        end
        currentMacroName = nil
        Utility.updateMacroList()
        updateMacroStatus()
    end)
end

-- Update playback speed dynamically
local function updatePlaybackSpeed(macroName, newSpeed)
    pcall(function()
        if macroPlaying and currentMacroName == macroName then
            currentPlaybackSpeed = newSpeed
            local macro = savedMacros[macroName]
            if macro then
                macro.speed = newSpeed
                saveToFileSystem(macroName, macro)
            end
            updateMacroStatus()
            print("[SUPERTOOL] Updated playback speed to " .. newSpeed .. "x")
        end
    end)
end

-- IMPROVED: Play Macro with timeout prevention and better error handling
local function playMacro(macroName, autoPlay)
    pcall(function()
        if macroRecording or macroPlaying or not humanoid or not rootPart then return end
        local macro = savedMacros[macroName] or loadFromFileSystem(macroName)
        if not macro or not macro.frames then 
            warn("[SUPERTOOL] Invalid macro: " .. macroName)
            return 
        end
        
        -- Allow playing even with empty frames for debugging
        if #macro.frames == 0 then
            warn("[SUPERTOOL] Playing empty macro: " .. macroName)
        end
        
        macroPlaying = true
        autoPlaying = autoPlay or false
        macroPlaybackPaused = false
        currentMacroName = macroName
        currentPlaybackSpeed = macro.speed or 1
        if humanoid then
            humanoid.WalkSpeed = 0
        end
        updateMacroStatus()
        
        -- Setup death handler
        if humanoid then
            humanoid.Died:Connect(handleCharacterDeath)
        end
        
        print("[SUPERTOOL] Playing macro: " .. macroName .. " (Auto: " .. tostring(autoPlaying) .. ", Speed: " .. currentPlaybackSpeed .. "x)")
        
        local function playSingleMacro()
            local startTime = tick()
            local index = 1
            local lastUpdateTime = 0
            local updateInterval = 0.05 -- Limit update rate to prevent timeout
            
            playbackConnection = RunService.Heartbeat:Connect(function()
                pcall(function()
                    -- Prevent timeout by limiting update rate
                    local currentTime = tick()
                    if currentTime - lastUpdateTime < updateInterval then
                        return
                    end
                    lastUpdateTime = currentTime
                    
                    if not macroPlaying or not player.Character then
                        if playbackConnection then playbackConnection:Disconnect() end
                        macroPlaying = false
                        autoPlaying = false
                        macroPlaybackPaused = false
                        if humanoid then humanoid.WalkSpeed = settings.WalkSpeed and settings.WalkSpeed.value or 16 end
                        currentMacroName = nil
                        currentPlaybackSpeed = 1
                        Utility.updateMacroList()
                        updateMacroStatus()
                        return
                    end
                    
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
                    
                    if #macro.frames == 0 then
                        -- Handle empty macro
                        if autoPlaying then
                            -- Keep running for auto-play
                            return
                        else
                            -- Stop for single play
                            if playbackConnection then playbackConnection:Disconnect() end
                            macroPlaying = false
                            macroPlaybackPaused = false
                            if humanoid then humanoid.WalkSpeed = settings.WalkSpeed and settings.WalkSpeed.value or 16 end
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
                            if humanoid then humanoid.WalkSpeed = settings.WalkSpeed and settings.WalkSpeed.value or 16 end
                            currentMacroName = nil
                            currentPlaybackSpeed = 1
                            Utility.updateMacroList()
                            updateMacroStatus()
                            return
                        end
                    end
                    
                    if index <= #macro.frames then
                        local frame = macro.frames[index]
                        local scaledTime = frame.time / currentPlaybackSpeed
                        
                        if scaledTime <= (currentTime - startTime) then
                            if frame.cframe and frame.velocity and frame.walkSpeed and frame.jumpPower and frame.hipHeight and frame.state then
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
                        end
                    end
                end)
            end)
        end
        
        playSingleMacro()
    end)
end

-- FIXED: Kill Player with better error handling
local function killPlayer()
    pcall(function()
        if humanoid then
            humanoid.Health = 0
            print("[SUPERTOOL] Player killed")
        else
            warn("[SUPERTOOL] Humanoid not found")
        end
    end)
end

-- FIXED: Reset Character - Use alternative method since LoadCharacter requires server
local function resetCharacter()
    pcall(function()
        if player and player.Character and humanoid then
            -- Alternative method: Kill player to trigger respawn
            humanoid.Health = 0
            print("[SUPERTOOL] Character reset (killed to respawn)")
        else
            warn("[SUPERTOOL] Cannot reset - Character or Humanoid not found")
        end
    end)
end

-- Initialize function (REQUIRED for module system)
function Utility.init(deps)
    local success = pcall(function()
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
    end)
    
    if success then
        print("[SUPERTOOL] Utility module initialized successfully")
        return true
    else
        warn("[SUPERTOOL] Failed to initialize Utility module")
        return false
    end
end

-- Load buttons function (REQUIRED for module system)
function Utility.loadUtilityButtons(createButton)
    if not createButton or type(createButton) ~= "function" then
        error("createButton function is required")
        return
    end
    
    print("[SUPERTOOL] Loading utility buttons...")
    
    local success = pcall(function()
        -- Create buttons with error handling
        createButton("Kill Player", function()
            pcall(killPlayer)
        end)
        
        createButton("Reset Character", function()
            pcall(resetCharacter)
        end)
        
        createButton("Record Macro", function()
            pcall(startMacroRecording)
        end)
        
        createButton("Stop Recording", function()
            pcall(stopMacroRecording)
        end)
        
        createButton("Macro Manager", function()
            pcall(showMacroManager)
        end)
    end)
    
    if success then
        print("[SUPERTOOL] Utility buttons loaded successfully")
    else
        warn("[SUPERTOOL] Failed to load some utility buttons")
    end
end

-- Reset states function (REQUIRED for module system)
function Utility.resetStates()
    pcall(function()
        -- Reset all utility states
        macroRecording = false
        macroPlaying = false
        autoPlaying = false
        macroPlaybackPaused = false
        
        -- Disconnect connections safely
        if recordConnection then
            pcall(function() recordConnection:Disconnect() end)
            recordConnection = nil
        end
        if playbackConnection then
            pcall(function() playbackConnection:Disconnect() end)
            playbackConnection = nil
        end
        if deathPauseTimeout then
            pcall(function() deathPauseTimeout:Disconnect() end)
            deathPauseTimeout = nil
        end
        
        -- Reset current states
        currentMacroName = nil
        currentPlaybackSpeed = 1
        recordingPaused = false
        
        print("[SUPERTOOL] Utility states reset")
    end)
end

-- Cleanup function for proper module management
function Utility.cleanup()
    pcall(function()
        Utility.resetStates()
        
        -- Destroy UI elements
        if MacroFrame then
            MacroFrame:Destroy()
            MacroFrame = nil
        end
        if MacroStatusLabel then
            MacroStatusLabel:Destroy()
            MacroStatusLabel = nil
        end
        
        -- Clear references
        MacroScrollFrame = nil
        MacroLayout = nil
        MacroInput = nil
        SaveMacroButton = nil
        
        print("[SUPERTOOL] Utility module cleaned up")
    end)
end

-- Additional utility functions for external access
function Utility.getMacroList()
    local macroList = {}
    for name, macro in pairs(savedMacros) do
        macroList[name] = {
            name = name,
            frameCount = macro.frameCount or (macro.frames and #macro.frames) or 0,
            duration = macro.duration or 0,
            speed = macro.speed or 1,
            created = macro.created,
            modified = macro.modified
        }
    end
    return macroList
end

function Utility.getMacroStatus()
    return {
        recording = macroRecording,
        playing = macroPlaying,
        autoPlaying = autoPlaying,
        paused = macroPlaybackPaused,
        currentMacro = currentMacroName,
        playbackSpeed = currentPlaybackSpeed
    }
end

function Utility.forceSyncMacros()
    pcall(function()
        syncMacrosFromJSON()
        if Utility.updateMacroList then
            Utility.updateMacroList()
        end
        print("[SUPERTOOL] Force sync completed")
    end)
end

-- Export specific macro data for external use
function Utility.exportMacroData(macroName)
    local macro = savedMacros[macroName] or loadFromFileSystem(macroName)
    if macro then
        return {
            name = macroName,
            frames = macro.frames,
            frameCount = #(macro.frames or {}),
            duration = macro.duration or 0,
            speed = macro.speed or 1,
            created = macro.created,
            modified = macro.modified,
            version = macro.version or "1.0"
        }
    end
    return nil
end

-- Import macro data from external source
function Utility.importMacroData(macroName, macroData)
    if not macroName or not macroData then return false end
    
    local success = pcall(function()
        local processedData = {
            frames = macroData.frames or {},
            startTime = macroData.startTime or 0,
            speed = macroData.speed or 1,
            name = macroName,
            created = macroData.created or os.time(),
            modified = os.time(),
            version = "1.2",
            frameCount = #(macroData.frames or {}),
            duration = macroData.duration or 0
        }
        
        savedMacros[macroName] = processedData
        saveToFileSystem(macroName, processedData)
        
        if Utility.updateMacroList then
            Utility.updateMacroList()
        end
        
        print("[SUPERTOOL] Imported macro: " .. macroName)
    end)
    
    return success
end

-- Utility function to check if macro system is ready
function Utility.isReady()
    return ScreenGui ~= nil and player ~= nil and RunService ~= nil
end

-- Return the module
return Utility