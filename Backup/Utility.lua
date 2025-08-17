-- Utility-related features for MinimalHackGUI by Fari Noveri
-- Optimized version with memory scanner removed and lag fixes
-- FIXED VERSION - Addresses all critical issues

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

-- FIXED: Add safety checks for all file operations
local function safeFileOperation(operation, ...)
    local success, result = pcall(operation, ...)
    if not success then
        warn("[SUPERTOOL] File operation failed: " .. tostring(result))
        return false, result
    end
    return true, result
end

-- Helper function untuk sanitize filename
local function sanitizeFileName(name)
    if not name or type(name) ~= "string" then
        return "unnamed_macro"
    end
    
    local sanitized = string.gsub(name, "[<>:\"/\\|?*]", "_")
    sanitized = string.gsub(sanitized, "^%s*(.-)%s*$", "%1")
    if sanitized == "" then
        sanitized = "unnamed_macro"
    end
    return sanitized
end

-- FIXED: Helper function untuk save macro ke JSON file dengan validation yang lebih baik
local function saveToJSONFile(macroName, macroData)
    if not macroName or not macroData then
        warn("[SUPERTOOL] Cannot save: invalid macro name or data")
        return false
    end
    
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(macroName)
        local fileName = sanitizedName .. ".json"
        local filePath = MACRO_FOLDER_PATH .. fileName
        
        -- FIXED: Better validation for macro data
        if not macroData.frames or type(macroData.frames) ~= "table" or #macroData.frames == 0 then
            warn("[SUPERTOOL] Cannot save empty macro: " .. macroName)
            return false
        end
        
        local validFrames = {}
        for i, frame in pairs(macroData.frames) do
            -- FIXED: More robust frame validation
            if type(frame) == "table" and frame.time and frame.cframe and frame.velocity then
                local validFrame = {}
                
                -- Validate and convert time
                validFrame.time = tonumber(frame.time) or 0
                if validFrame.time < 0 then validFrame.time = 0 end
                
                -- Validate and convert CFrame
                local cframeArray
                if typeof(frame.cframe) == "CFrame" then
                    cframeArray = {frame.cframe:GetComponents()}
                elseif type(frame.cframe) == "table" and #frame.cframe >= 12 then
                    cframeArray = {}
                    for j = 1, 12 do
                        cframeArray[j] = tonumber(frame.cframe[j]) or 0
                    end
                else
                    warn("[SUPERTOOL] Invalid CFrame in frame " .. i .. ", using default")
                    cframeArray = {0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1}
                end
                validFrame.cframe = cframeArray
                
                -- Validate and convert Velocity
                local velocityArray
                if typeof(frame.velocity) == "Vector3" then
                    velocityArray = {frame.velocity.X, frame.velocity.Y, frame.velocity.Z}
                elseif type(frame.velocity) == "table" and #frame.velocity >= 3 then
                    velocityArray = {
                        tonumber(frame.velocity[1]) or 0,
                        tonumber(frame.velocity[2]) or 0,
                        tonumber(frame.velocity[3]) or 0
                    }
                else
                    velocityArray = {0, 0, 0}
                end
                validFrame.velocity = velocityArray
                
                -- Validate other properties with defaults
                validFrame.walkSpeed = tonumber(frame.walkSpeed) or 16
                validFrame.jumpPower = tonumber(frame.jumpPower) or 50
                validFrame.hipHeight = tonumber(frame.hipHeight) or 0
                
                -- Validate state
                local stateString = "Running"
                if typeof(frame.state) == "EnumItem" then
                    stateString = frame.state.Name
                elseif type(frame.state) == "string" and frame.state ~= "" then
                    stateString = frame.state
                end
                validFrame.state = stateString
                
                table.insert(validFrames, validFrame)
            else
                -- FIXED: Still count frame even if some fields are missing, use defaults
                warn("[SUPERTOOL] Frame " .. i .. " missing required fields, using defaults")
                local defaultFrame = {
                    time = tonumber(frame and frame.time) or (i * 0.1), -- Use index-based time if missing
                    cframe = {0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1},
                    velocity = {0, 0, 0},
                    walkSpeed = 16,
                    jumpPower = 50,
                    hipHeight = 0,
                    state = "Running"
                }
                table.insert(validFrames, defaultFrame)
            end
        end
        
        -- FIXED: Allow saving even if some frames were invalid
        if #validFrames == 0 then
            warn("[SUPERTOOL] No valid frames to save for macro: " .. macroName)
            return false
        end
        
        local jsonData = {
            name = macroName,
            created = macroData.created or os.time(),
            modified = os.time(),
            version = "1.2",
            frames = validFrames,
            startTime = tonumber(macroData.startTime) or 0,
            speed = tonumber(macroData.speed) or 1,
            frameCount = #validFrames,
            duration = validFrames[#validFrames].time or 0
        }
        
        -- FIXED: Safe file creation with folder check
        local folderSuccess = safeFileOperation(function()
            if not isfolder(MACRO_FOLDER_PATH) then
                makefolder(MACRO_FOLDER_PATH)
            end
        end)
        
        if not folderSuccess then
            warn("[SUPERTOOL] Failed to create macro folder")
            return false
        end
        
        local jsonString = HttpService:JSONEncode(jsonData)
        local writeSuccess = safeFileOperation(writefile, filePath, jsonString)
        
        if writeSuccess then
            print("[SUPERTOOL] Macro saved: " .. filePath .. " (" .. #validFrames .. " frames)")
            return true
        else
            return false
        end
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to save macro to JSON: " .. tostring(error))
        return false
    end
    return true
end

-- FIXED: Helper function untuk load macro dari JSON file dengan validation yang lebih robust
local function loadFromJSONFile(macroName)
    if not macroName or type(macroName) ~= "string" then
        warn("[SUPERTOOL] Invalid macro name for loading")
        return nil
    end
    
    local success, result = pcall(function()
        local sanitizedName = sanitizeFileName(macroName)
        local fileName = sanitizedName .. ".json"
        local filePath = MACRO_FOLDER_PATH .. fileName
        
        -- FIXED: Safe file existence check
        local fileExists = safeFileOperation(isfile, filePath)
        if not fileExists then
            return nil
        end
        
        local jsonString
        local readSuccess
        readSuccess, jsonString = safeFileOperation(readfile, filePath)
        
        if not readSuccess or not jsonString or jsonString == "" then
            warn("[SUPERTOOL] Empty or unreadable JSON file: " .. filePath)
            return nil
        end
        
        local jsonData = HttpService:JSONDecode(jsonString)
        if not jsonData or type(jsonData) ~= "table" then
            warn("[SUPERTOOL] Failed to decode JSON: " .. filePath)
            return nil
        end
        
        local frames = jsonData.frames or {}
        if type(frames) ~= "table" then
            warn("[SUPERTOOL] Invalid frames data in macro: " .. macroName)
            return nil
        end
        
        -- FIXED: Allow loading even if some frames are invalid
        local validFrames = {}
        local invalidFrameCount = 0
        
        for i, frame in pairs(frames) do
            if type(frame) == "table" then
                local validFrame = {}
                
                -- More lenient frame validation
                validFrame.time = tonumber(frame.time) or (i * 0.1)
                validFrame.walkSpeed = tonumber(frame.walkSpeed) or 16
                validFrame.jumpPower = tonumber(frame.jumpPower) or 50
                validFrame.hipHeight = tonumber(frame.hipHeight) or 0
                
                -- Handle CFrame with fallback
                if type(frame.cframe) == "table" and #frame.cframe >= 12 then
                    local components = {}
                    local validComponents = true
                    
                    for j = 1, 12 do
                        local component = tonumber(frame.cframe[j])
                        if component then
                            components[j] = component
                        else
                            validComponents = false
                            break
                        end
                    end
                    
                    if validComponents then
                        validFrame.cframe = CFrame.new(unpack(components))
                    else
                        validFrame.cframe = CFrame.new(0, 0, 0)
                        invalidFrameCount = invalidFrameCount + 1
                    end
                else
                    validFrame.cframe = CFrame.new(0, 0, 0)
                    invalidFrameCount = invalidFrameCount + 1
                end
                
                -- Handle Velocity with fallback
                if type(frame.velocity) == "table" and #frame.velocity >= 3 then
                    local vx, vy, vz = tonumber(frame.velocity[1]), tonumber(frame.velocity[2]), tonumber(frame.velocity[3])
                    if vx and vy and vz then
                        validFrame.velocity = Vector3.new(vx, vy, vz)
                    else
                        validFrame.velocity = Vector3.new(0, 0, 0)
                        invalidFrameCount = invalidFrameCount + 1
                    end
                else
                    validFrame.velocity = Vector3.new(0, 0, 0)
                    invalidFrameCount = invalidFrameCount + 1
                end
                
                -- Handle State with fallback
                if type(frame.state) == "string" and frame.state ~= "" then
                    local stateEnum = Enum.HumanoidStateType[frame.state]
                    validFrame.state = stateEnum or Enum.HumanoidStateType.Running
                else
                    validFrame.state = Enum.HumanoidStateType.Running
                end
                
                table.insert(validFrames, validFrame)
            else
                invalidFrameCount = invalidFrameCount + 1
            end
        end
        
        -- FIXED: Allow loading even if no perfectly valid frames, but warn user
        if #validFrames == 0 then
            warn("[SUPERTOOL] No valid frames found in macro: " .. macroName .. ", but file exists")
            -- Return minimal valid macro instead of nil
            return {
                frames = {{
                    time = 0,
                    cframe = CFrame.new(0, 0, 0),
                    velocity = Vector3.new(0, 0, 0),
                    walkSpeed = 16,
                    jumpPower = 50,
                    hipHeight = 0,
                    state = Enum.HumanoidStateType.Running
                }},
                startTime = 0,
                speed = 1,
                name = macroName,
                created = os.time(),
                modified = os.time(),
                version = "1.2",
                frameCount = 1,
                duration = 0
            }
        end
        
        if invalidFrameCount > 0 then
            warn("[SUPERTOOL] " .. invalidFrameCount .. " invalid frames corrected in macro: " .. macroName)
        end
        
        table.sort(validFrames, function(a, b) return a.time < b.time end)
        
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
    if not macroName then return false end
    
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(macroName)
        local fileName = sanitizedName .. ".json"
        local filePath = MACRO_FOLDER_PATH .. fileName
        
        local fileExists = safeFileOperation(isfile, filePath)
        if fileExists then
            local deleteSuccess = safeFileOperation(delfile, filePath)
            if deleteSuccess then
                print("[SUPERTOOL] Macro deleted: " .. filePath)
                return true
            end
        end
        return false
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
    if not oldName or not newName then return false end
    
    local success, error = pcall(function()
        local oldData = loadFromJSONFile(oldName)
        if not oldData then
            return false
        end
        
        oldData.name = newName
        oldData.modified = os.time()
        
        if saveToJSONFile(newName, oldData) then
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

-- FIXED: Helper function untuk load semua macros dari folder dengan timeout protection
local function loadAllMacrosFromFolder()
    local success, result = pcall(function()
        local startTime = tick()
        local timeoutLimit = 25 -- 25 seconds to prevent 30+ second timeout
        
        local folderSuccess = safeFileOperation(function()
            if not isfolder(MACRO_FOLDER_PATH) then
                makefolder(MACRO_FOLDER_PATH)
                print("[SUPERTOOL] Created macro folder: " .. MACRO_FOLDER_PATH)
            end
        end)
        
        if not folderSuccess then
            warn("[SUPERTOOL] Cannot access macro folder")
            return {}
        end
        
        local loadedMacros = {}
        local filesSuccess, files = safeFileOperation(listfiles, MACRO_FOLDER_PATH)
        
        if not filesSuccess or not files then
            warn("[SUPERTOOL] Cannot list macro files")
            return {}
        end
        
        local processedCount = 0
        local maxFiles = 50 -- Limit to prevent timeout
        
        for i, filePath in pairs(files) do
            -- FIXED: Check timeout to prevent script running over 30 seconds
            if tick() - startTime > timeoutLimit then
                warn("[SUPERTOOL] Loading timeout reached, processed " .. processedCount .. " files")
                break
            end
            
            if processedCount >= maxFiles then
                warn("[SUPERTOOL] Maximum file limit reached (" .. maxFiles .. "), skipping remaining files")
                break
            end
            
            if string.match(filePath, "%.json$") then
                local fileName = string.match(filePath, "([^/\\]+)%.json$")
                if fileName then
                    local macroData = loadFromJSONFile(fileName)
                    if macroData and macroData.frames and #macroData.frames > 0 then
                        local originalName = macroData.name or fileName
                        loadedMacros[originalName] = macroData
                        processedCount = processedCount + 1
                        print("[SUPERTOOL] Loaded macro: " .. originalName .. " (" .. #macroData.frames .. " frames)")
                    else
                        warn("[SUPERTOOL] Skipped invalid macro file: " .. fileName)
                    end
                end
            end
            
            -- Small yield to prevent lag
            if processedCount % 5 == 0 then
                task.wait(0.01)
            end
        end
        
        print("[SUPERTOOL] Total macros loaded: " .. processedCount)
        return loadedMacros
    end)
    
    if success then
        return result or {}
    else
        warn("[SUPERTOOL] Failed to load macros from folder: " .. tostring(result))
        return {}
    end
end

-- Mock file system for backward compatibility
local fileSystem = {
    ["Supertool/Macro"] = {}
}

-- Helper function to ensure DCIM/Supertool exists
local function ensureFileSystem()
    if not fileSystem["Supertool"] then
        fileSystem["Supertool"] = {}
    end
    if not fileSystem["Supertool/Macro"] then
        fileSystem["Supertool/Macro"] = {}
    end
end

-- Helper function to save macro to file system
local function saveToFileSystem(macroName, macroData)
    if not macroName or not macroData then return end
    ensureFileSystem()
    fileSystem["Supertool/Macro"][macroName] = macroData
    saveToJSONFile(macroName, macroData)
end

-- Helper function to load macro from file system
local function loadFromFileSystem(macroName)
    if not macroName then return nil end
    
    local jsonData = loadFromJSONFile(macroName)
    if jsonData then
        return jsonData
    end
    
    ensureFileSystem()
    return fileSystem["Supertool/Macro"][macroName]
end

-- Helper function to delete macro from file system
local function deleteFromFileSystem(macroName)
    if not macroName then return false end
    
    ensureFileSystem()
    local memoryDeleted = false
    if fileSystem["Supertool/Macro"][macroName] then
        fileSystem["Supertool/Macro"][macroName] = nil
        memoryDeleted = true
    end
    
    local jsonDeleted = deleteFromJSONFile(macroName)
    
    return memoryDeleted or jsonDeleted
end

-- Helper function to rename macro in file system
local function renameInFileSystem(oldName, newName)
    if not oldName or not newName or newName == "" then return false end
    
    ensureFileSystem()
    local memoryRenamed = false
    
    if fileSystem["Supertool/Macro"][oldName] then
        fileSystem["Supertool/Macro"][newName] = fileSystem["Supertool/Macro"][oldName]
        fileSystem["Supertool/Macro"][oldName] = nil
        memoryRenamed = true
    end
    
    local jsonRenamed = renameInJSONFile(oldName, newName)
    
    return memoryRenamed or jsonRenamed
end

-- FIXED: Function untuk sync macros dari JSON ke memory pada startup
local function syncMacrosFromJSON()
    local startTime = tick()
    print("[SUPERTOOL] Starting macro sync from JSON files...")
    
    local jsonMacros = loadAllMacrosFromFolder()
    local count = 0
    
    for macroName, macroData in pairs(jsonMacros) do
        if macroData and macroData.frames and #macroData.frames > 0 then
            savedMacros[macroName] = macroData
            fileSystem["Supertool/Macro"][macroName] = macroData
            count = count + 1
        end
        
        -- Prevent timeout
        if tick() - startTime > 20 then
            warn("[SUPERTOOL] Sync timeout reached after " .. count .. " macros")
            break
        end
    end
    
    local elapsed = tick() - startTime
    print("[SUPERTOOL] Synced " .. count .. " valid macros from JSON files in " .. string.format("%.2f", elapsed) .. " seconds")
end

-- Delete Macro
local function deleteMacro(macroName)
    if not macroName then return end
    
    if savedMacros[macroName] then
        savedMacros[macroName] = nil
        deleteFromFileSystem(macroName)
        if Utility.updateMacroList then
            Utility.updateMacroList()
        end
        print("[SUPERTOOL] Macro deleted: " .. macroName)
    end
end

-- Rename Macro
local function renameMacro(oldName, newName)
    if not oldName or not newName or newName == "" then return end
    
    if savedMacros[oldName] then
        if renameInFileSystem(oldName, newName) then
            if currentMacroName == oldName then
                currentMacroName = newName
                if updateMacroStatus then
                    updateMacroStatus()
                end
            end
            savedMacros[newName] = savedMacros[oldName]
            savedMacros[oldName] = nil
            if Utility.updateMacroList then
                Utility.updateMacroList()
            end
            print("[SUPERTOOL] Macro renamed: " .. oldName .. " -> " .. newName)
        end
    end
end

-- FIXED: Show Macro Manager - check if initMacroUI exists
local function showMacroManager()
    macroFrameVisible = true
    if not MacroFrame then
        if initMacroUI then
            initMacroUI()
        else
            warn("[SUPERTOOL] initMacroUI function not found - creating basic UI")
            -- Create basic UI fallback
            createBasicMacroUI()
        end
    end
    if MacroFrame then
        MacroFrame.Visible = true
        if Utility.updateMacroList then
            Utility.updateMacroList()
        end
    end
end

-- FIXED: Create basic macro UI fallback function
local function createBasicMacroUI()
    if not ScreenGui then
        warn("[SUPERTOOL] ScreenGui not available, cannot create macro UI")
        return
    end
    
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

    -- Connect events
    SaveMacroButton.MouseButton1Click:Connect(function()
        stopMacroRecording()
        if MacroFrame then
            MacroFrame.Visible = true
        end
    end)
    
    CloseMacroButton.MouseButton1Click:Connect(function()
        macroFrameVisible = false
        if MacroFrame then
            MacroFrame.Visible = false
        end
    end)
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
        
        -- Event handlers with safety checks
        speedInput.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local newSpeed = tonumber(speedInput.Text)
                if newSpeed and newSpeed > 0 then
                    macro.speed = newSpeed
                    saveToFileSystem(macroName, macro)
                    if macroPlaying and currentMacroName == macroName then
                        updatePlaybackSpeed(macroName, newSpeed)
                        if Utility.updateMacroList then
                            Utility.updateMacroList()
                        end
                    end
                    if updateMacroStatus then
                        updateMacroStatus()
                    end
                    print("[SUPERTOOL] Updated speed for " .. macroName .. ": " .. newSpeed .. "x")
                else
                    speedInput.Text = tostring(macro.speed or 1)
                end
            end
        end)
        
        updateSpeedBtn.MouseButton1Click:Connect(function()
            local newSpeed = tonumber(speedInput.Text)
            if newSpeed and newSpeed > 0 then
                macro.speed = newSpeed
                saveToFileSystem(macroName, macro)
                if macroPlaying and currentMacroName == macroName then
                    updatePlaybackSpeed(macroName, newSpeed)
                    if Utility.updateMacroList then
                        Utility.updateMacroList()
                    end
                end
                if updateMacroStatus then
                    updateMacroStatus()
                end
                print("[SUPERTOOL] Real-time speed update for " .. macroName .. ": " .. newSpeed .. "x")
                
                updateSpeedBtn.BackgroundColor3 = Color3.fromRGB(120, 200, 120)
                updateSpeedBtn.Text = "✓"
                task.wait(1)
                updateSpeedBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
                updateSpeedBtn.Text = "UPDATE"
            else
                speedInput.Text = tostring(macro.speed or 1)
                updateSpeedBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
                updateSpeedBtn.Text = "✗"
                task.wait(1)
                updateSpeedBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
                updateSpeedBtn.Text = "UPDATE"
            end
        end)
        
        playButton.MouseButton1Click:Connect(function()
            if macroPlaying and currentMacroName == macroName and not autoPlaying then
                stopMacroPlayback()
            else
                playMacro(macroName, false)
                if Utility.updateMacroList then
                    Utility.updateMacroList()
                end
            end
        end)
        
        autoPlayButton.MouseButton1Click:Connect(function()
            if macroPlaying and currentMacroName == macroName and autoPlaying then
                stopMacroPlayback()
            else
                playMacro(macroName, true)
                if Utility.updateMacroList then
                    Utility.updateMacroList()
                end
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
            saveToJSONFile(macroName, macro)
            fileStatusLabel.Text = "📁 ✓ " .. sanitizeFileName(macroName) .. ".json"
            fileStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            task.wait(2)
            fileStatusLabel.Text = "📁 " .. sanitizeFileName(macroName) .. ".json"
        end)
        
        exportButton.MouseButton1Click:Connect(function()
            fileStatusLabel.Text = "📤 Exported to JSON!"
            fileStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
            saveToJSONFile(macroName, macro)
            task.wait(2)
            fileStatusLabel.Text = "📁 " .. sanitizeFileName(macroName) .. ".json"
            fileStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        end)
        
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
            if Utility.updateMacroList then
                Utility.updateMacroList()
            end
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
    createBasicMacroUI()
end

-- NEW: Function to handle death and respawn with auto-pause/resume
local function handleCharacterDeath()
    if macroPlaying then
        macroPlaybackPaused = true
        print("[SUPERTOOL] Macro paused due to character death")
        if updateMacroStatus then
            updateMacroStatus()
        end
        
        if deathPauseTimeout then
            deathPauseTimeout:Disconnect()
            deathPauseTimeout = nil
        end
        
        local connection
        connection = player.CharacterAdded:Connect(function(newCharacter)
            connection:Disconnect()
            if macroPlaybackPaused then
                task.wait(respawnWaitTime)
                if macroPlaybackPaused and macroPlaying then
                    macroPlaybackPaused = false
                    print("[SUPERTOOL] Macro resumed after respawn")
                    if updateMacroStatus then
                        updateMacroStatus()
                    end
                end
            end
        end)
    end
end

-- Update macro status display
function updateMacroStatus()
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
        humanoid = player.Character:FindFirstChild("Humanoid")
        rootPart = player.Character:FindFirstChild("HumanoidRootPart")
        
        if humanoid then
            local connection
            connection = humanoid.Died:Connect(function()
                connection:Disconnect()
                handleCharacterDeath()
            end)
        end
        
        if macroRecording and recordingPaused then
            recordingPaused = false
            if updateMacroStatus then
                updateMacroStatus()
            end
        end
    end
end

-- Record Macro
local function startMacroRecording()
    if macroRecording or macroPlaying then return end
    macroRecording = true
    recordingPaused = false
    currentMacro = {frames = {}, startTime = tick(), speed = 1}
    lastFrameTime = 0
    
    updateCharacterReferences()
    if updateMacroStatus then
        updateMacroStatus()
    end
    
    local function setupDeathHandler()
        if humanoid then
            local connection
            connection = humanoid.Died:Connect(function()
                connection:Disconnect()
                if macroRecording then
                    recordingPaused = true
                    if updateMacroStatus then
                        updateMacroStatus()
                    end
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
            cframe = {rootPart.CFrame:GetComponents()},
            velocity = {rootPart.Velocity.X, rootPart.Velocity.Y, rootPart.Velocity.Z},
            walkSpeed = humanoid.WalkSpeed,
            jumpPower = humanoid.JumpPower,
            hipHeight = humanoid.HipHeight,
            state = humanoid:GetState().Name
        }
        table.insert(currentMacro.frames, frame)
        lastFrameTime = frame.time
    end)
end

-- FIXED: Stop Macro Recording with nil checks
local function stopMacroRecording()
    if not macroRecording then return end
    macroRecording = false
    recordingPaused = false
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    
    -- FIXED: Check if MacroInput exists before accessing Text property
    local macroName = "Macro_" .. (os.time() % 10000) -- Default name
    if MacroInput and MacroInput.Text then
        if MacroInput.Text ~= "" then
            macroName = MacroInput.Text
        end
    end
    
    if #currentMacro.frames == 0 then
        warn("Cannot save empty macro")
        return
    end
    
    currentMacro.frameCount = #currentMacro.frames
    currentMacro.duration = currentMacro.frames[#currentMacro.frames].time
    currentMacro.created = os.time()
    
    savedMacros[macroName] = currentMacro
    saveToFileSystem(macroName, currentMacro)
    
    -- FIXED: Safe clearing of MacroInput
    if MacroInput then
        MacroInput.Text = ""
    end
    
    if Utility.updateMacroList then
        Utility.updateMacroList()
    end
    if updateMacroStatus then
        updateMacroStatus()
    end
    if MacroFrame then
        MacroFrame.Visible = true
    end
    
    print("[SUPERTOOL] Macro recorded and saved: " .. macroName .. " (" .. #currentMacro.frames .. " frames)")
end

-- Stop Macro Playback
function stopMacroPlayback()
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
        humanoid.WalkSpeed = (settings and settings.WalkSpeed and settings.WalkSpeed.value) or 16
    end
    currentMacroName = nil
    if Utility.updateMacroList then
        Utility.updateMacroList()
    end
    if updateMacroStatus then
        updateMacroStatus()
    end
end

-- NEW: Function to update playback speed dynamically
function updatePlaybackSpeed(macroName, newSpeed)
    if macroPlaying and currentMacroName == macroName then
        currentPlaybackSpeed = newSpeed
        local macro = savedMacros[macroName]
        if macro then
            macro.speed = newSpeed
            saveToFileSystem(macroName, macro)
        end
        if updateMacroStatus then
            updateMacroStatus()
        end
        print("[SUPERTOOL] Updated playback speed to " .. newSpeed .. "x")
    end
end

-- OPTIMIZED: Play Macro with lag fixes
function playMacro(macroName, autoPlay)
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
    if updateMacroStatus then
        updateMacroStatus()
    end
    
    if humanoid then
        local connection
        connection = humanoid.Died:Connect(function()
            connection:Disconnect()
            handleCharacterDeath()
        end)
    end
    
    print("[SUPERTOOL] Playing macro: " .. macroName .. " (Auto: " .. tostring(autoPlaying) .. ", Speed: " .. currentPlaybackSpeed .. "x)")
    
    local function playSingleMacro()
        local startTime = tick()
        local index = 1
        local lastProcessedTime = -1
        local maxFramesPerTick = 10
        
        playbackConnection = RunService.Heartbeat:Connect(function()
            if not macroPlaying or not player.Character or macroPlaybackPaused then
                if not macroPlaying or not player.Character then
                    if playbackConnection then playbackConnection:Disconnect() end
                    macroPlaying = false
                    autoPlaying = false
                    macroPlaybackPaused = false
                    if humanoid then humanoid.WalkSpeed = (settings and settings.WalkSpeed and settings.WalkSpeed.value) or 16 end
                    currentMacroName = nil
                    currentPlaybackSpeed = 1
                    if Utility.updateMacroList then
                        Utility.updateMacroList()
                    end
                    if updateMacroStatus then
                        updateMacroStatus()
                    end
                end
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
                    if Utility.updateMacroList then
                        Utility.updateMacroList()
                    end
                    if updateMacroStatus then
                        updateMacroStatus()
                    end
                    return
                end
            end
            
            if index > #macro.frames then
                if autoPlaying then
                    index = 1
                    startTime = tick()
                    lastProcessedTime = -1
                else
                    stopMacroPlayback()
                    return
                end
            end
            
            local framesProcessed = 0
            local currentTime = tick() - startTime
            
            while index <= #macro.frames and framesProcessed < maxFramesPerTick do
                local frame = macro.frames[index]
                local scaledTime = frame.time / currentPlaybackSpeed
                
                if scaledTime > currentTime then
                    break
                end
                
                if scaledTime <= lastProcessedTime then
                    index = index + 1
                    continue
                end
                
                if frame.cframe and frame.velocity and frame.walkSpeed and frame.jumpPower and frame.hipHeight and frame.state then
                    local success, err = pcall(function()
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
                    end)
                    
                    if not success then
                        warn("[SUPERTOOL] Error applying frame " .. index .. ": " .. tostring(err))
                    end
                end
                
                lastProcessedTime = scaledTime
                index = index + 1
                framesProcessed = framesProcessed + 1
            end
            
            if framesProcessed > 0 then
                task.wait(0.01)
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

-- FIXED: Reset Character - use alternative method
local function resetCharacter()
    if player and player.Character then
        -- FIXED: Use Humanoid:TakeDamage instead of LoadCharacter (which can only be called by backend)
        if humanoid then
            humanoid:TakeDamage(humanoid.MaxHealth)
            print("[SUPERTOOL] Character reset via damage")
        else
            -- Alternative: Teleport to void
            if rootPart then
                rootPart.CFrame = CFrame.new(0, -1000, 0)
                print("[SUPERTOOL] Character teleported to void for reset")
            end
        end
    end
end

-- Initialize function
function Utility.init(deps)
    if not deps then
        warn("[SUPERTOOL] No dependencies provided to Utility.init")
        return false
    end
    
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
    
    -- FIXED: Only sync macros if we have necessary services
    if RunService and player then
        syncMacrosFromJSON()
    else
        warn("[SUPERTOOL] Missing required services for macro sync")
    end
    
    print("[SUPERTOOL] Utility module initialized successfully")
    return true
end

-- Load buttons function
function Utility.loadUtilityButtons(createButton)
    if not createButton or type(createButton) ~= "function" then
        error("createButton function is required")
        return
    end
    
    print("[SUPERTOOL] Loading utility buttons...")
    
    -- FIXED: Add error handling for button creation
    local success, err = pcall(function()
        createButton("Kill Player", killPlayer)
        createButton("Reset Character", resetCharacter)
        createButton("Record Macro", startMacroRecording)
        createButton("Stop Macro", stopMacroRecording)
        createButton("Macro Manager", showMacroManager)
    end)
    
    if success then
        print("[SUPERTOOL] Utility buttons loaded successfully")
    else
        warn("[SUPERTOOL] Failed to load utility buttons: " .. tostring(err))
    end
end

-- Reset states function
function Utility.resetStates()
    macroRecording = false
    macroPlaying = false
    autoPlaying = false
    macroPlaybackPaused = false
    
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    if deathPauseTimeout then
        deathPauseTimeout:Disconnect()
        deathPauseTimeout = nil
    end
    
    print("[SUPERTOOL] Utility states reset")
end

-- FIXED: Add cleanup function for safe shutdown
function Utility.cleanup()
    Utility.resetStates()
    
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
end

-- FIXED: Add error recovery function
function Utility.recoverFromError()
    warn("[SUPERTOOL] Attempting error recovery...")
    
    -- Stop any active operations
    Utility.resetStates()
    
    -- Try to restore character references
    if player and player.Character then
        updateCharacterReferences()
    end
    
    -- Clear corrupted macros
    local corruptedCount = 0
    for name, macro in pairs(savedMacros) do
        if not macro or not macro.frames or type(macro.frames) ~= "table" or #macro.frames == 0 then
            savedMacros[name] = nil
            corruptedCount = corruptedCount + 1
        end
    end
    
    if corruptedCount > 0 then
        warn("[SUPERTOOL] Removed " .. corruptedCount .. " corrupted macros from memory")
    end
    
    print("[SUPERTOOL] Error recovery completed")
end

-- FIXED: Add validation function for macro data integrity
function Utility.validateMacros()
    local totalMacros = 0
    local validMacros = 0
    local repairedMacros = 0
    
    for name, macro in pairs(savedMacros) do
        totalMacros = totalMacros + 1
        
        if macro and type(macro) == "table" and macro.frames and type(macro.frames) == "table" then
            local frameCount = #macro.frames
            if frameCount > 0 then
                validMacros = validMacros + 1
                
                -- Check if repair is needed
                local needsRepair = false
                for i, frame in ipairs(macro.frames) do
                    if not frame.time or not frame.cframe or not frame.velocity then
                        needsRepair = true
                        break
                    end
                end
                
                if needsRepair then
                    -- Attempt repair
                    local repairedFrames = {}
                    for i, frame in ipairs(macro.frames) do
                        local repairedFrame = {
                            time = tonumber(frame.time) or (i * 0.1),
                            cframe = frame.cframe or {0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1},
                            velocity = frame.velocity or {0, 0, 0},
                            walkSpeed = tonumber(frame.walkSpeed) or 16,
                            jumpPower = tonumber(frame.jumpPower) or 50,
                            hipHeight = tonumber(frame.hipHeight) or 0,
                            state = frame.state or "Running"
                        }
                        table.insert(repairedFrames, repairedFrame)
                    end
                    
                    macro.frames = repairedFrames
                    macro.frameCount = #repairedFrames
                    macro.duration = repairedFrames[#repairedFrames].time or 0
                    saveToFileSystem(name, macro)
                    repairedMacros = repairedMacros + 1
                end
            end
        end
    end
    
    print("[SUPERTOOL] Macro validation complete:")
    print("  Total: " .. totalMacros .. " | Valid: " .. validMacros .. " | Repaired: " .. repairedMacros)
    
    return {
        total = totalMacros,
        valid = validMacros,
        repaired = repairedMacros
    }
end

-- FIXED: Add safe macro loading with retry mechanism
function Utility.safeSyncMacros(maxRetries)
    maxRetries = maxRetries or 3
    local attempt = 1
    
    while attempt <= maxRetries do
        print("[SUPERTOOL] Macro sync attempt " .. attempt .. "/" .. maxRetries)
        
        local success = pcall(function()
            syncMacrosFromJSON()
        end)
        
        if success then
            print("[SUPERTOOL] Macro sync successful on attempt " .. attempt)
            return true
        else
            warn("[SUPERTOOL] Macro sync failed on attempt " .. attempt)
            attempt = attempt + 1
            if attempt <= maxRetries then
                task.wait(1) -- Wait before retry
            end
        end
    end
    
    warn("[SUPERTOOL] All macro sync attempts failed")
    return false
end

-- Export main utility functions for external access
Utility.stopMacroPlayback = stopMacroPlayback
Utility.updatePlaybackSpeed = updatePlaybackSpeed
Utility.playMacro = playMacro
Utility.updateMacroStatus = updateMacroStatus
Utility.startMacroRecording = startMacroRecording
Utility.stopMacroRecording = stopMacroRecording

return Utility