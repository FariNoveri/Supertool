-- Utility-old-related features for MinimalHackGUI by Fari Noveri

-- Dependencies: These must be passed from mainloader.lua
local Players, humanoid, rootPart, ScrollFrame, buttonStates, RunService, player, ScreenGui, settings

-- Initialize module
local Utility = {}

-- Variables for Macro
local macroRecording = false
local macroPlaying = false
local autoPlaying = false
local autoRespawning = false
local currentMacro = {}
local savedMacros = {}
local macroFrameVisible = false
local MacroFrame, MacroScrollFrame, MacroLayout, MacroInput, SaveMacroButton, MacroStatusLabel
local recordConnection = nil
local playbackConnection = nil
local currentMacroName = nil
local recordingPaused = false
local lastFrameTime = 0
local playbackPaused = false
local pausedIndex = nil
local pausedTime = nil
local pausedPosition = nil
local pausePart = nil
local pauseResumeTime = 5 -- Seconds to wait before resuming macro/path after death

-- Variables for Path Creator
local pathRecording = false
local pathPlaying = false
local pathAutoPlaying = false
local pathAutoRespawning = false
local currentPath = {}
local savedPaths = {}
local pathFrameVisible = false
local PathFrame, PathScrollFrame, PathLayout, PathInput, SavePathButton, PathStatusLabel
local pathRecordConnection = nil
local pathPlaybackConnection = nil
local currentPathName = nil
local pathRecordingPaused = false
local pathLastFrameTime = 0
local pathPlaybackPaused = false
local pathPausedIndex = nil
local pathPausedTime = nil
local pathPausedPosition = nil
local pathPausePart = nil
local pathVisuals = {}
local PathVisualsFolder
local UserInputService = game:GetService("UserInputService")

-- File System Integration
local HttpService = game:GetService("HttpService")
local MACRO_FOLDER_PATH = "Supertool/path/"
local PATH_FOLDER_PATH = "Supertool/paths/"

-- Helper functions (sanitizeFileName, validateAndConvertCFrame, etc.) remain unchanged
-- [Previous helper functions like sanitizeFileName, validateAndConvertCFrame, etc. are retained]

-- Generate waypoints for paths
local function generateWaypoints(frames)
    local wp = {}
    local accDist = 0
    local lastPos = nil
    for _, frame in ipairs(frames) do
        local pos = frame.cframe.Position
        if lastPos then
            local d = (pos - lastPos).Magnitude
            accDist = accDist + d
            if accDist >= 5 then
                table.insert(wp, {x = pos.X, y = pos.Y, z = pos.Z})
                accDist = accDist % 5
            end
        else
            table.insert(wp, {x = pos.X, y = pos.Y, z = pos.Z})
        end
        lastPos = pos
    end
    return wp
end

-- Save and load functions for macros (unchanged from original)
-- [Previous saveToJSONFile, loadFromJSONFile, etc. for macros remain unchanged]

-- Save and load functions for paths
local function savePathToJSONFile(pathName, pathData)
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(pathName)
        local fileName = sanitizedName .. ".json"
        local filePath = PATH_FOLDER_PATH .. fileName
        
        if not pathData or not pathData.frames or type(pathData.frames) ~= "table" then
            warn("[SUPERTOOL] Invalid path data for saving: " .. pathName)
            return false
        end
        
        local serializedFrames = {}
        for i, frame in pairs(pathData.frames) do
            if frame and frame.time then
                local serializedFrame = {
                    time = frame.time,
                    cframe = {frame.cframe:GetComponents()},
                    velocity = {frame.velocity.X, frame.velocity.Y, frame.velocity.Z},
                    walkSpeed = frame.walkSpeed,
                    jumpPower = frame.jumpPower,
                    hipHeight = frame.hipHeight,
                    state = frame.state.Name
                }
                table.insert(serializedFrames, serializedFrame)
            end
        end
        
        if #serializedFrames == 0 then
            warn("[SUPERTOOL] No valid frames to save for path: " .. pathName)
            return false
        end
        
        local jsonData = {
            name = pathName,
            created = pathData.created or os.time(),
            modified = os.time(),
            version = "1.1",
            frames = serializedFrames,
            startTime = pathData.startTime or 0,
            speed = pathData.speed or 1,
            frameCount = #serializedFrames,
            duration = serializedFrames[#serializedFrames].time
        }
        
        if pathData.waypointPositions then
            local swp = {}
            for _, p in ipairs(pathData.waypointPositions) do
                table.insert(swp, {x = p.X, y = p.Y, z = p.Z})
            end
            jsonData.waypoints = swp
        end
        
        local jsonString = HttpService:JSONEncode(jsonData)
        writefile(filePath, jsonString)
        
        print("[SUPERTOOL] Path saved: " .. filePath .. " (" .. #serializedFrames .. " frames)")
        return true
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to save path to JSON: " .. tostring(error))
        return false
    end
    return true
end

local function loadPathFromJSONFile(pathName)
    local success, result = pcall(function()
        local sanitizedName = sanitizeFileName(pathName)
        local fileName = sanitizedName .. ".json"
        local filePath = PATH_FOLDER_PATH .. fileName
        
        if not isfile(filePath) then
            return nil
        end
        
        local jsonString = readfile(filePath)
        if not jsonString or jsonString == "" then
            warn("[SUPERTOOL] Empty JSON file: " .. filePath)
            return nil
        end
        
        local jsonData = HttpService:JSONDecode(jsonString)
        if not jsonData or type(jsonData) ~= "table" then
            warn("[SUPERTOOL] Invalid JSON data in: " .. filePath)
            return nil
        end
        
        local rawFrames = jsonData.frames or {}
        local validFrames = {}
        local skippedFrames = 0
        
        for i, rawFrame in pairs(rawFrames) do
            local validFrame = validateFrame(rawFrame)
            if validFrame then
                table.insert(validFrames, validFrame)
            else
                skippedFrames = skippedFrames + 1
            end
        end
        
        if #validFrames == 0 then
            warn("[SUPERTOOL] No valid frames found in path: " .. pathName .. " (skipped: " .. skippedFrames .. ")")
            return nil
        end
        
        if skippedFrames > 0 then
            print("[SUPERTOOL] Loaded path with " .. skippedFrames .. " skipped invalid frames")
        end
        
        local pathData = {
            name = jsonData.name or pathName,
            created = jsonData.created or os.time(),
            modified = jsonData.modified or os.time(),
            version = jsonData.version or "1.0",
            frames = validFrames,
            startTime = tonumber(jsonData.startTime) or 0,
            speed = tonumber(jsonData.speed) or 1,
            frameCount = #validFrames,
            duration = validFrames[#validFrames].time
        }
        
        if jsonData.waypoints then
            local vwp = {}
            for _, w in ipairs(jsonData.waypoints) do
                table.insert(vwp, Vector3.new(w.x or 0, w.y or 0, w.z or 0))
            end
            pathData.waypointPositions = vwp
        end
        
        return pathData
    end)
    
    if success then
        if result then
            print("[SUPERTOOL] Successfully loaded path: " .. pathName .. " (" .. #(result.frames or {}) .. " frames)")
        end
        return result
    else
        warn("[SUPERTOOL] Failed to load path from JSON: " .. pathName .. " - " .. tostring(result))
        return nil
    end
end

local function deletePathFromJSONFile(pathName)
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(pathName)
        local fileName = sanitizedName .. ".json"
        local filePath = PATH_FOLDER_PATH .. fileName
        
        if isfile(filePath) then
            delfile(filePath)
            print("[SUPERTOOL] Path deleted: " .. filePath)
            return true
        else
            return false
        end
    end)
    
    if success then
        return error
    else
        warn("[SUPERTOOL] Failed to delete path JSON: " .. tostring(error))
        return false
    end
end

local function renamePathInJSONFile(oldName, newName)
    local success, error = pcall(function()
        local oldData = loadPathFromJSONFile(oldName)
        if not oldData then
            return false
        end
        
        oldData.name = newName
        oldData.modified = os.time()
        
        if savePathToJSONFile(newName, oldData) then
            deletePathFromJSONFile(oldName)
            print("[SUPERTOOL] Path renamed: " .. oldName .. " -> " .. newName)
            return true
        else
            return false
        end
    end)
    
    if success then
        return error
    else
        warn("[SUPERTOOL] Failed to rename path: " .. tostring(error))
        return false
    end
end

local function loadAllPathsFromFolder()
    local success, result = pcall(function()
        if not isfolder(PATH_FOLDER_PATH) then
            makefolder(PATH_FOLDER_PATH)
            print("[SUPERTOOL] Created paths folder: " .. PATH_FOLDER_PATH)
            return {}
        end
        
        local loadedPaths = {}
        local files = listfiles(PATH_FOLDER_PATH)
        local totalFiles = 0
        local loadedCount = 0
        local errorCount = 0
        
        for _, filePath in pairs(files) do
            if string.match(filePath, "%.json$") then
                totalFiles = totalFiles + 1
                local fileName = string.match(filePath, "([^/\\]+)%.json$")
                if fileName then
                    local pathData = loadPathFromJSONFile(fileName)
                    if pathData and pathData.frames and #pathData.frames > 0 then
                        loadedPaths[fileName] = pathData
                        loadedCount = loadedCount + 1
                        print("[SUPERTOOL] Loaded path: " .. fileName .. " (" .. #pathData.frames .. " frames)")
                    else
                        errorCount = errorCount + 1
                        warn("[SUPERTOOL] Failed to load path: " .. fileName)
                    end
                end
            end
        end
        
        print("[SUPERTOOL] Path loading complete: " .. loadedCount .. "/" .. totalFiles .. " files loaded" .. (errorCount > 0 and " (" .. errorCount .. " errors)" or ""))
        return loadedPaths
    end)
    
    if success then
        return result or {}
    else
        warn("[SUPERTOOL] Failed to load paths from folder: " .. tostring(result))
        return {}
    end
end

-- File System for Paths
local fileSystem = {
    ["Supertool/path"] = {},
    ["Supertool/paths"] = {}
}

local function ensureFileSystem()
    if not fileSystem["Supertool"] then
        fileSystem["Supertool"] = {}
    end
    if not fileSystem["Supertool/path"] then
        fileSystem["Supertool/path"] = {}
    end
    if not fileSystem["Supertool/paths"] then
        fileSystem["Supertool/paths"] = {}
    end
end

local function savePathToFileSystem(pathName, pathData)
    ensureFileSystem()
    fileSystem["Supertool/paths"][pathName] = pathData
    savePathToJSONFile(pathName, pathData)
end

local function loadPathFromFileSystem(pathName)
    local jsonData = loadPathFromJSONFile(pathName)
    if jsonData then
        return jsonData
    end
    
    ensureFileSystem()
    return fileSystem["Supertool/paths"][pathName]
end

local function deletePathFromFileSystem(pathName)
    ensureFileSystem()
    local memoryDeleted = false
    if fileSystem["Supertool/paths"][pathName] then
        fileSystem["Supertool/paths"][pathName] = nil
        memoryDeleted = true
    end
    
    local jsonDeleted = deletePathFromJSONFile(pathName)
    
    return memoryDeleted or jsonDeleted
end

local function renamePathInFileSystem(oldName, newName)
    ensureFileSystem()
    local memoryRenamed = false
    
    if fileSystem["Supertool/paths"][oldName] and newName ~= "" then
        fileSystem["Supertool/paths"][newName] = fileSystem["Supertool/paths"][oldName]
        fileSystem["Supertool/paths"][oldName] = nil
        memoryRenamed = true
    end
    
    local jsonRenamed = renamePathInJSONFile(oldName, newName)
    
    return memoryRenamed or jsonRenamed
end

local function syncPathsFromJSON()
    print("[SUPERTOOL] Starting path sync from JSON files...")
    local jsonPaths = loadAllPathsFromFolder()
    local syncedCount = 0
    
    for pathName, pathData in pairs(jsonPaths) do
        if pathData and pathData.frames and #pathData.frames > 0 then
            savedPaths[pathName] = pathData
            fileSystem["Supertool/paths"][pathName] = pathData
            syncedCount = syncedCount + 1
        else
            warn("[SUPERTOOL] Skipped invalid path during sync: " .. pathName)
        end
    end
    
    print("[SUPERTOOL] Path sync complete: " .. syncedCount .. " paths loaded from JSON files")
    return syncedCount
end

-- Path Visualization
local function drawPath(pathName)
    local path = savedPaths[pathName] or loadPathFromFileSystem(pathName)
    if not path or not path.frames or #path.frames == 0 then
        return nil
    end

    if not path.waypointPositions then
        path.waypointPositions = {}
        local wp = generateWaypoints(path.frames)
        for _, w in ipairs(wp) do
            table.insert(path.waypointPositions, Vector3.new(w.x, w.y, w.z))
        end
        savePathToFileSystem(pathName, path)
    end

    local pathFolder = Instance.new("Folder")
    pathFolder.Name = pathName
    pathFolder.Parent = PathVisualsFolder

    local lastPos = nil
    local waypointIndex = 1

    for i, frame in ipairs(path.frames) do
        local pos = frame.cframe.Position
        if lastPos then
            local dist = (pos - lastPos).Magnitude
            local line = Instance.new("Part")
            line.Anchored = true
            line.CanCollide = false
            line.Transparency = 0.5
            line.Size = Vector3.new(0.2, 0.2, dist)
            line.CFrame = CFrame.lookAt(lastPos, pos) * CFrame.new(0, 0, -dist / 2)
            local color
            if frame.state == Enum.HumanoidStateType.Running then
                color = Color3.new(0, 1, 0) -- green
            elseif frame.state == Enum.HumanoidStateType.Jumping then
                color = Color3.new(1, 0, 0) -- red
            elseif frame.state == Enum.HumanoidStateType.Freefall then
                color = Color3.new(1, 1, 0) -- yellow
            elseif frame.state == Enum.HumanoidStateType.Swimming then
                color = Color3.new(0.5, 0, 1) -- purple
            else
                color = Color3.new(1, 1, 1) -- white
            end
            line.Color = color
            line.Parent = pathFolder
        end

        if waypointIndex <= #path.waypointPositions and (pos - path.waypointPositions[waypointIndex]).Magnitude < 0.1 then
            local sphere = Instance.new("Part")
            sphere.Shape = Enum.PartType.Ball
            sphere.Size = Vector3.new(1, 1, 1)
            sphere.Anchored = true
            sphere.CanCollide = false
            sphere.Transparency = 0.3
            sphere.Color = Color3.new(0, 0, 1) -- blue
            sphere.Position = pos
            sphere.Parent = pathFolder
            waypointIndex = waypointIndex + 1
        end

        lastPos = pos
    end

    return pathFolder
end

local function togglePathVisual(pathName)
    if pathVisuals[pathName] then
        pathVisuals[pathName]:Destroy()
        pathVisuals[pathName] = nil
    else
        pathVisuals[pathName] = drawPath(pathName)
    end
end

-- Path Status Update
local function updatePathStatus()
    if not PathStatusLabel then return end
    if pathRecording then
        PathStatusLabel.Text = pathRecordingPaused and "Path Recording Paused" or "Recording Path"
        PathStatusLabel.Visible = true
    elseif pathPlaying and currentPathName then
        local path = savedPaths[currentPathName] or loadPathFromFileSystem(currentPathName)
        local speed = path and path.speed or 1
        local modeText = pathAutoRespawning and "Path Auto-Respawning" or (pathAutoPlaying and "Path Auto-Playing" or "Playing Path")
        PathStatusLabel.Text = (pathPlaybackPaused and "Paused: " or modeText .. ": ") .. currentPathName .. " (Speed: " .. speed .. "x)"
        PathStatusLabel.Visible = true
    else
        PathStatusLabel.Visible = false
    end
end

-- Macro-related functions (unchanged from original)
-- [Previous macro functions like startMacroRecording, stopMacroRecording, etc. remain unchanged]

-- Path Recording
local function startPathRecording()
    if pathRecording or pathPlaying then return end
    
    if not player.Character or not player.Character:FindFirstChild("Humanoid") or not player.Character:FindFirstChild("HumanoidRootPart") then
        warn("[SUPERTOOL] Cannot start path recording: Character not ready")
        return
    end
    
    pathRecording = true
    pathRecordingPaused = false
    currentPath = {frames = {}, startTime = tick(), speed = 1}
    pathLastFrameTime = 0
    
    updateCharacterReferences()
    updatePathStatus()
    
    local function setupDeathHandler()
        if humanoid then
            humanoid.Died:Connect(function()
                if pathRecording then
                    pathRecordingPaused = true
                    updatePathStatus()
                end
            end)
        end
    end
    
    setupDeathHandler()
    
    pathRecordConnection = RunService.Heartbeat:Connect(function()
        if not pathRecording or pathRecordingPaused then return end
        
        if not humanoid or not rootPart or not humanoid.Parent or not rootPart.Parent then
            updateCharacterReferences()
            if not humanoid or not rootPart then return end
            setupDeathHandler()
        end
        
        local success, frame = pcall(function()
            return {
                time = tick() - currentPath.startTime,
                cframe = rootPart.CFrame,
                velocity = rootPart.Velocity,
                walkSpeed = humanoid.WalkSpeed,
                jumpPower = humanoid.JumpPower,
                hipHeight = humanoid.HipHeight,
                state = humanoid:GetState()
            }
        end)
        
        if success and frame and frame.time and frame.cframe and frame.velocity then
            table.insert(currentPath.frames, frame)
            pathLastFrameTime = frame.time
        end
    end)
end

local function stopPathRecording()
    if not pathRecording then return end
    pathRecording = false
    pathRecordingPaused = false
    if pathRecordConnection then
        pathRecordConnection:Disconnect()
        pathRecordConnection = nil
    end
    
    local pathName = PathInput.Text
    if pathName == "" then
        pathName = "Path_" .. os.date("%H%M%S") .. "_" .. (#savedPaths + 1)
    end
    
    if #currentPath.frames == 0 then
        warn("[SUPERTOOL] Cannot save empty path")
        updatePathStatus()
        return
    end
    
    local validFrameCount = 0
    for i, frame in pairs(currentPath.frames) do
        if validateFrame(frame) then
            validFrameCount = validFrameCount + 1
        end
    end
    
    if validFrameCount == 0 then
        warn("[SUPERTOOL] Cannot save path: No valid frames found")
        updatePathStatus()
        return
    end
    
    currentPath.frameCount = #currentPath.frames
    currentPath.duration = currentPath.frames[#currentPath.frames].time
    currentPath.created = os.time()
    
    savedPaths[pathName] = currentPath
    local saveSuccess = savePathToFileSystem(pathName, currentPath)
    
    if saveSuccess then
        PathInput.Text = ""
        Utility.updatePathList()
        updatePathStatus()
        if PathFrame then
            PathFrame.Visible = true
        end
        
        print("[SUPERTOOL] Path recorded and saved: " .. pathName .. " (" .. #currentPath.frames .. " frames, " .. validFrameCount .. " valid)")
    else
        warn("[SUPERTOOL] Failed to save path: " .. pathName)
    end
end

local function stopPathPlayback()
    if not pathPlaying then return end
    pathPlaying = false
    pathAutoPlaying = false
    pathAutoRespawning = false
    pathPlaybackPaused = false
    pathPausedIndex = nil
    pathPausedTime = nil
    pathPausedPosition = nil
    if pathPausePart then
        pathPausePart:Destroy()
        pathPausePart = nil
    end
    if pathPlaybackConnection then
        pathPlaybackConnection:Disconnect()
        pathPlaybackConnection = nil
    end
    if humanoid then
        humanoid.WalkSpeed = settings.WalkSpeed.value or 16
    end
    currentPathName = nil
    Utility.updatePathList()
    updatePathStatus()
end

local function playPath(pathName, autoPlay, respawn)
    if pathRecording or pathPlaying then
        stopPathPlayback()
    end
    
    if not player.Character or not player.Character:FindFirstChild("Humanoid") or not player.Character:FindFirstChild("HumanoidRootPart") then
        warn("[SUPERTOOL] Cannot play path: Character not ready")
        return
    end
    
    updateCharacterReferences()
    if not humanoid or not rootPart then
        warn("[SUPERTOOL] Cannot play path: Failed to get character references")
        return
    end
    
    local path = savedPaths[pathName] or loadPathFromFileSystem(pathName)
    if not path or not path.frames or #path.frames == 0 then
        warn("[SUPERTOOL] Cannot play path: Invalid or empty path data for " .. pathName)
        return
    end
    
    local validFrames = {}
    for i, frame in pairs(path.frames) do
        local validFrame = validateFrame(frame)
        if validFrame then
            table.insert(validFrames, validFrame)
        end
    end
    
    if #validFrames == 0 then
        warn("[SUPERTOOL] Cannot play path: No valid frames in " .. pathName)
        return
    end
    
    if #validFrames < #path.frames then
        warn("[SUPERTOOL] Playing path with " .. (#path.frames - #validFrames) .. " invalid frames skipped")
        path.frames = validFrames
        path.frameCount = #validFrames
        path.duration = validFrames[#validFrames].time
        savedPaths[pathName] = path
        savePathToFileSystem(pathName, path)
    end
    
    pathPlaying = true
    pathAutoPlaying = autoPlay or false
    pathAutoRespawning = respawn or false
    pathPlaybackPaused = false
    currentPathName = pathName
    humanoid.WalkSpeed = 0
    updatePathStatus()
    
    print("[SUPERTOOL] Playing path: " .. pathName .. " (Auto: " .. tostring(pathAutoPlaying) .. ", Respawn: " .. tostring(pathAutoRespawning) .. ", Speed: " .. (path.speed or 1) .. "x, Frames: " .. #validFrames .. ")")
    
    local function playSinglePath()
        local startTime = tick()
        local index = 1
        local speed = path.speed or 1
        
        pathPlaybackConnection = RunService.Heartbeat:Connect(function()
            if not pathPlaying or pathPlaybackPaused or not player.Character then
                return
            end
            
            if not humanoid or not rootPart or not humanoid.Parent or not rootPart.Parent then
                updateCharacterReferences()
                if not humanoid or not rootPart then
                    pathPlaybackPaused = true
                    updatePathStatus()
                    return
                end
            end
            
            if index > #validFrames then
                if pathAutoPlaying then
                    if pathAutoRespawning then
                        resetCharacter()
                    else
                        index = 1
                        startTime = tick()
                    end
                else
                    stopPathPlayback()
                    return
                end
            end
            
            local frame = validFrames[index]
            local scaledTime = frame.time / speed
            while index <= #validFrames and scaledTime <= (tick() - startTime) do
                local success = pcall(function()
                    rootPart.CFrame = frame.cframe
                    rootPart.Velocity = frame.velocity
                    humanoid.WalkSpeed = frame.walkSpeed
                    humanoid.JumpPower = frame.jumpPower
                    humanoid.HipHeight = frame.hipHeight
                    humanoid:ChangeState(frame.state)
                end)
                
                if not success then
                    warn("[SUPERTOOL] Error applying frame " .. index .. " in path " .. pathName)
                end
                
                index = index + 1
                if index <= #validFrames then
                    frame = validFrames[index]
                    scaledTime = frame.time / speed
                end
            end
        end)
    end
    
    local function setupDeathHandler()
        if humanoid then
            humanoid.Died:Connect(function()
                if pathPlaying then
                    pathPlaybackPaused = true
                    updatePathStatus()
                    print("[SUPERTOOL] Path playback paused due to character death")
                    task.spawn(function()
                        task.wait(pauseResumeTime)
                        if pathPlaying and pathPlaybackPaused then
                            updateCharacterReferences()
                            if humanoid and rootPart then
                                pathPlaybackPaused = false
                                updatePathStatus()
                                print("[SUPERTOOL] Resuming path playback after " .. pauseResumeTime .. " seconds")
                                playSinglePath()
                            end
                        end
                    end)
                end
            end)
        end
    end
    
    setupDeathHandler()
    playSinglePath()
end

local function deletePath(pathName)
    if savedPaths[pathName] then
        if pathPlaying and currentPathName == pathName then
            stopPathPlayback()
        end
        if pathVisuals[pathName] then
            togglePathVisual(pathName)
        end
        savedPaths[pathName] = nil
        deletePathFromFileSystem(pathName)
        Utility.updatePathList()
        print("[SUPERTOOL] Path deleted: " .. pathName)
    end
end

local function renamePath(oldName, newName)
    if savedPaths[oldName] and newName ~= "" then
        if renamePathInFileSystem(oldName, newName) then
            if currentPathName == oldName then
                currentPathName = newName
                updatePathStatus()
            end
            savedPaths[newName] = savedPaths[oldName]
            savedPaths[oldName] = nil
            if pathVisuals[oldName] then
                togglePathVisual(oldName)
                togglePathVisual(newName)
            end
            Utility.updatePathList()
            print("[SUPERTOOL] Path renamed: " .. oldName .. " -> " .. newName)
        end
    end
end

local function showPathManager()
    pathFrameVisible = true
    if not PathFrame then
        initPathUI()
    end
    PathFrame.Visible = true
    Utility.updatePathList()
end

function Utility.updatePathList()
    if not PathScrollFrame then return end
    
    for _, child in pairs(PathScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local itemCount = 0
    
    local infoFrame = Instance.new("Frame")
    infoFrame.Name = "InfoFrame"
    infoFrame.Parent = PathScrollFrame
    infoFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    infoFrame.BorderSizePixel = 0
    infoFrame.Size = UDim2.new(1, -5, 0, 25)
    infoFrame.LayoutOrder = -1
    
    local pathCount = 0
    for _ in pairs(savedPaths) do
        pathCount = pathCount + 1
    end
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Parent = infoFrame
    infoLabel.BackgroundTransparency = 1
    infoLabel.Size = UDim2.new(1, 0, 1, 0)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Text = "JSON Sync: " .. PATH_FOLDER_PATH .. " (" .. pathCount .. " paths)"
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    infoLabel.TextSize = 7
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    for pathName, path in pairs(savedPaths) do
        if not path or not path.frames or type(path.frames) ~= "table" then
            warn("[SUPERTOOL] Skipping invalid path in UI: " .. pathName)
            continue
        end
        
        local pathItem = Instance.new("Frame")
        pathItem.Name = pathName .. "Item"
        pathItem.Parent = PathScrollFrame
        pathItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        pathItem.BorderSizePixel = 0
        pathItem.Size = UDim2.new(1, -5, 0, 110)
        pathItem.LayoutOrder = itemCount
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Parent = pathItem
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.new(0, 5, 0, 5)
        nameLabel.Size = UDim2.new(1, -10, 0, 15)
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.Text = pathName
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize = 7
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local frameCount = path.frameCount or (path.frames and #path.frames) or 0
        local duration = path.duration or (path.frames and #path.frames > 0 and path.frames[#path.frames] and path.frames[#path.frames].time) or 0
        local speed = path.speed or 1
        
        local validFrameCount = 0
        if path.frames then
            for _, frame in pairs(path.frames) do
                if validateFrame(frame) then
                    validFrameCount = validFrameCount + 1
                end
            end
        end
        
        local statusColor = Color3.fromRGB(150, 150, 150)
        local statusSuffix = ""
        
        if validFrameCount == 0 then
            statusColor = Color3.fromRGB(255, 100, 100)
            statusSuffix = " (INVALID)"
        elseif validFrameCount < frameCount then
            statusColor = Color3.fromRGB(255, 200, 100)
            statusSuffix = " (PARTIAL)"
        else
            statusColor = Color3.fromRGB(100, 255, 100)
            statusSuffix = " (VALID)"
        end
        
        local infoText = string.format("Frames: %d/%d | Duration: %.1fs | Speed: %.1fx%s", 
                                     validFrameCount, frameCount, duration, speed, statusSuffix)
        
        local pathInfoLabel = Instance.new("TextLabel")
        pathInfoLabel.Parent = pathItem
        pathInfoLabel.BackgroundTransparency = 1
        pathInfoLabel.Position = UDim2.new(0, 5, 0, 20)
        pathInfoLabel.Size = UDim2.new(1, -10, 0, 10)
        pathInfoLabel.Font = Enum.Font.Gotham
        pathInfoLabel.Text = infoText
        pathInfoLabel.TextColor3 = statusColor
        pathInfoLabel.TextSize = 6
        pathInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local renameInput = Instance.new("TextBox")
        renameInput.Name = "RenameInput"
        renameInput.Parent = pathItem
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
        speedLabel.Parent = pathItem
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
        speedInput.Parent = pathItem
        speedInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        speedInput.BorderSizePixel = 0
        speedInput.Position = UDim2.new(0, 60, 0, 55)
        speedInput.Size = UDim2.new(0, 40, 0, 15)
        speedInput.Font = Enum.Font.Gotham
        speedInput.Text = tostring(speed)
        speedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        speedInput.TextSize = 7
        speedInput.TextXAlignment = Enum.TextXAlignment.Center
        
        local buttonFrame = Instance.new("Frame")
        buttonFrame.Name = "ButtonFrame"
        buttonFrame.Parent = pathItem
        buttonFrame.BackgroundTransparency = 1
        buttonFrame.Position = UDim2.new(0, 5, 0, 75)
        buttonFrame.Size = UDim2.new(1, -10, 0, 15)
        
        local canPlay = validFrameCount > 0
        local playButtonColor = canPlay and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(40, 40, 40)
        local autoButtonColor = canPlay and Color3.fromRGB(60, 80, 60) or Color3.fromRGB(40, 50, 40)
        local autoRespColor = canPlay and Color3.fromRGB(60, 60, 80) or Color3.fromRGB(40, 40, 50)
        
        if pathPlaying and currentPathName == pathName then
            playButtonColor = Color3.fromRGB(100, 100, 100)
            autoButtonColor = Color3.fromRGB(100, 100, 100)
            autoRespColor = Color3.fromRGB(100, 100, 100)
        end
        
        local playButton = Instance.new("TextButton")
        playButton.Name = "PlayButton"
        playButton.Parent = buttonFrame
        playButton.BackgroundColor3 = playButtonColor
        playButton.BorderSizePixel = 0
        playButton.Position = UDim2.new(0, 0, 0, 0)
        playButton.Size = UDim2.new(0, 40, 0, 15)
        playButton.Font = Enum.Font.Gotham
        playButton.Text = (pathPlaying and currentPathName == pathName and not pathAutoPlaying) and "STOP" or (canPlay and "PLAY" or "INVALID")
        playButton.TextColor3 = canPlay and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
        playButton.TextSize = 7
        
        local autoPlayButton = Instance.new("TextButton")
        autoPlayButton.Name = "AutoPlayButton"
        autoPlayButton.Parent = buttonFrame
        autoPlayButton.BackgroundColor3 = autoButtonColor
        autoPlayButton.BorderSizePixel = 0
        autoPlayButton.Position = UDim2.new(0, 45, 0, 0)
        autoPlayButton.Size = UDim2.new(0, 40, 0, 15)
        autoPlayButton.Font = Enum.Font.Gotham
        autoPlayButton.Text = (pathPlaying and currentPathName == pathName and pathAutoPlaying and not pathAutoRespawning) and "STOP" or (canPlay and "AUTO" or "INVALID")
        autoPlayButton.TextColor3 = canPlay and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
        autoPlayButton.TextSize = 7
        
        local autoRespButton = Instance.new("TextButton")
        autoRespButton.Name = "AutoRespButton"
        autoRespButton.Parent = buttonFrame
        autoRespButton.BackgroundColor3 = autoRespColor
        autoRespButton.BorderSizePixel = 0
        autoRespButton.Position = UDim2.new(0, 90, 0, 0)
        autoRespButton.Size = UDim2.new(0, 40, 0, 15)
        autoRespButton.Font = Enum.Font.Gotham
        autoRespButton.Text = (pathPlaying and currentPathName == pathName and pathAutoPlaying and pathAutoRespawning) and "STOP" or (canPlay and "A-RESP" or "INVALID")
        autoRespButton.TextColor3 = canPlay and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
        autoRespButton.TextSize = 7
        
        local deleteButton = Instance.new("TextButton")
        deleteButton.Name = "DeleteButton"
        deleteButton.Parent = buttonFrame
        deleteButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
        deleteButton.BorderSizePixel = 0
        deleteButton.Position = UDim2.new(0, 135, 0, 0)
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
        renameButton.Position = UDim2.new(0, 180, 0, 0)
        renameButton.Size = UDim2.new(0, 40, 0, 15)
        renameButton.Font = Enum.Font.Gotham
        renameButton.Text = "RENAME"
        renameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        renameButton.TextSize = 7
        
        local buttonFrame2 = Instance.new("Frame")
        buttonFrame2.Name = "ButtonFrame2"
        buttonFrame2.Parent = pathItem
        buttonFrame2.BackgroundTransparency = 1
        buttonFrame2.Position = UDim2.new(0, 5, 0, 92)
        buttonFrame2.Size = UDim2.new(1, -10, 0, 15)
        
        local fixButton = Instance.new("TextButton")
        fixButton.Name = "FixButton"
        fixButton.Parent = buttonFrame2
        fixButton.BackgroundColor3 = canPlay and Color3.fromRGB(80, 60, 120) or Color3.fromRGB(120, 80, 60)
        fixButton.BorderSizePixel = 0
        fixButton.Position = UDim2.new(0, 0, 0, 0)
        fixButton.Size = UDim2.new(0, 45, 0, 15)
        fixButton.Font = Enum.Font.Gotham
        fixButton.Text = canPlay and "RESYNC" or "FIX"
        fixButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        fixButton.TextSize = 6
        
        local exportButton = Instance.new("TextButton")
        exportButton.Name = "ExportButton"
        exportButton.Parent = buttonFrame2
        exportButton.BackgroundColor3 = Color3.fromRGB(60, 120, 80)
        exportButton.BorderSizePixel = 0
        exportButton.Position = UDim2.new(0, 50, 0, 0)
        exportButton.Size = UDim2.new(0, 45, 0, 15)
        exportButton.Font = Enum.Font.Gotham
        exportButton.Text = "EXPORT"
        exportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        exportButton.TextSize = 6
        
        local showPathButton = Instance.new("TextButton")
        showPathButton.Name = "ShowPathButton"
        showPathButton.Parent = buttonFrame2
        showPathButton.BackgroundColor3 = Color3.fromRGB(80, 80, 40)
        showPathButton.BorderSizePixel = 0
        showPathButton.Position = UDim2.new(0, 100, 0, 0)
        showPathButton.Size = UDim2.new(0, 60, 0, 15)
        showPathButton.Font = Enum.Font.Gotham
        showPathButton.Text = pathVisuals[pathName] and "Hide Path" or "Show Path"
        showPathButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        showPathButton.TextSize = 6
        
        local fileStatusLabel = Instance.new("TextLabel")
        fileStatusLabel.Name = "FileStatusLabel"
        fileStatusLabel.Parent = buttonFrame2
        fileStatusLabel.BackgroundTransparency = 1
        fileStatusLabel.Position = UDim2.new(0, 165, 0, 0)
        fileStatusLabel.Size = UDim2.new(1, -165, 0, 15)
        fileStatusLabel.Font = Enum.Font.Gotham
        fileStatusLabel.Text = "📁 " .. sanitizeFileName(pathName) .. ".json"
        fileStatusLabel.TextColor3 = canPlay and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 150, 100)
        fileStatusLabel.TextSize = 6
        fileStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        speedInput.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local newSpeed = tonumber(speedInput.Text)
                if newSpeed and newSpeed > 0 and newSpeed <= 10 then
                    path.speed = newSpeed
                    savePathToFileSystem(pathName, path)
                    if pathPlaying and currentPathName == pathName then
                        savedPaths[pathName].speed = newSpeed
                        updatePathStatus()
                    end
                    print("[SUPERTOOL] Updated speed for path " .. pathName .. ": " .. newSpeed .. "x")
                else
                    speedInput.Text = tostring(path.speed or 1)
                    warn("[SUPERTOOL] Invalid speed value. Must be between 0.1 and 10")
                end
            end
        end)
        
        playButton.MouseButton1Click:Connect(function()
            if not canPlay then 
                warn("[SUPERTOOL] Cannot play invalid path: " .. pathName)
                return 
            end
            
            if pathPlaying and currentPathName == pathName and not pathAutoPlaying then
                stopPathPlayback()
            else
                playPath(pathName, false, false)
            end
            Utility.updatePathList()
        end)
        
        autoPlayButton.MouseButton1Click:Connect(function()
            if not canPlay then 
                warn("[SUPERTOOL] Cannot auto-play invalid path: " .. pathName)
                return 
            end
            
            if pathPlaying and currentPathName == pathName and pathAutoPlaying and not pathAutoRespawning then
                stopPathPlayback()
            else
                playPath(pathName, true, false)
            end
            Utility.updatePathList()
        end)
        
        autoRespButton.MouseButton1Click:Connect(function()
            if not canPlay then 
                warn("[SUPERTOOL] Cannot auto-respawn invalid path: " .. pathName)
                return 
            end
            
            if pathPlaying and currentPathName == pathName and pathAutoPlaying and pathAutoRespawning then
                stopPathPlayback()
            else
                playPath(pathName, true, true)
            end
            Utility.updatePathList()
        end)
        
        deleteButton.MouseButton1Click:Connect(function()
            deletePath(pathName)
        end)
        
        renameButton.MouseButton1Click:Connect(function()
            if renameInput.Text ~= "" then
                renamePath(pathName, renameInput.Text)
                renameInput.Text = ""
            end
        end)
        
        renameInput.FocusLost:Connect(function(enterPressed)
            if enterPressed and renameInput.Text ~= "" then
                renamePath(pathName, renameInput.Text)
                renameInput.Text = ""
            end
        end)
        
        fixButton.MouseButton1Click:Connect(function()
            if canPlay then
                savePathToJSONFile(pathName, path)
                fileStatusLabel.Text = "📁 ✓ " .. sanitizeFileName(pathName) .. ".json"
                fileStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            else
                local originalPath = loadPathFromJSONFile(pathName)
                if originalPath and originalPath.frames and #originalPath.frames > 0 then
                    savedPaths[pathName] = originalPath
                    Utility.updatePathList()
                    fileStatusLabel.Text = "🔧 Fixed from JSON!"
                    fileStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                else
                    fileStatusLabel.Text = "❌ Cannot fix - No valid data"
                    fileStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                end
            end
            
            task.wait(2)
            fileStatusLabel.Text = "📁 " .. sanitizeFileName(pathName) .. ".json"
            fileStatusLabel.TextColor3 = canPlay and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 150, 100)
        end)
        
        exportButton.MouseButton1Click:Connect(function()
            fileStatusLabel.Text = "📤 Exported to JSON!"
            fileStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
            savePathToJSONFile(pathName, path)
            task.wait(2)
            fileStatusLabel.Text = "📁 " .. sanitizeFileName(pathName) .. ".json"
            fileStatusLabel.TextColor3 = canPlay and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 150, 100)
        end)
        
        showPathButton.MouseButton1Click:Connect(function()
            togglePathVisual(pathName)
            showPathButton.Text = pathVisuals[pathName] and "Hide Path" or "Show Path"
        end)
        
        -- Hover effects (similar to macro buttons, omitted for brevity)
        
        itemCount = itemCount + 1
    end
    
    if itemCount > 0 then
        local utilityFrame = Instance.new("Frame")
        utilityFrame.Name = "UtilityFrame"
        utilityFrame.Parent = PathScrollFrame
        utilityFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 40)
        utilityFrame.BorderSizePixel = 0
        utilityFrame.Size = UDim2.new(1, -5, 0, 50)
        utilityFrame.LayoutOrder = itemCount + 1
        
        local refreshButton = Instance.new("TextButton")
        refreshButton.Parent = utilityFrame
        refreshButton.BackgroundColor3 = Color3.fromRGB(80, 80, 40)
        refreshButton.BorderSizePixel = 0
        refreshButton.Position = UDim2.new(0, 5, 0, 5)
        refreshButton.Size = UDim2.new(0, 80, 0, 18)
        refreshButton.Font = Enum.Font.Gotham
        refreshButton.Text = "🔄 REFRESH"
        refreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        refreshButton.TextSize = 7
        
        local syncAllButton = Instance.new("TextButton")
        syncAllButton.Parent = utilityFrame
        syncAllButton.BackgroundColor3 = Color3.fromRGB(40, 80, 80)
        syncAllButton.BorderSizePixel = 0
        syncAllButton.Position = UDim2.new(0, 90, 0, 5)
        syncAllButton.Size = UDim2.new(0, 80, 0, 18)
        syncAllButton.Font = Enum.Font.Gotham
        syncAllButton.Text = "💾 SYNC ALL"
        syncAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        syncAllButton.TextSize = 7
        
        local fixAllButton = Instance.new("TextButton")
        fixAllButton.Parent = utilityFrame
        fixAllButton.BackgroundColor3 = Color3.fromRGB(80, 40, 80)
        fixAllButton.BorderSizePixel = 0
        fixAllButton.Position = UDim2.new(0, 175, 0, 5)
        fixAllButton.Size = UDim2.new(0, 80, 0, 18)
        fixAllButton.Font = Enum.Font.Gotham
        fixAllButton.Text = "🔧 FIX ALL"
        fixAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        fixAllButton.TextSize = 7
        
        local statusLabel = Instance.new("TextLabel")
        statusLabel.Parent = utilityFrame
        statusLabel.BackgroundTransparency = 1
        statusLabel.Position = UDim2.new(0, 5, 0, 25)
        statusLabel.Size = UDim2.new(1, -10, 0, 20)
        statusLabel.Font = Enum.Font.Gotham
        statusLabel.Text = "Total: " .. itemCount .. " paths loaded"
        statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        statusLabel.TextSize = 7
        statusLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        refreshButton.MouseButton1Click:Connect(function()
            statusLabel.Text = "Refreshing..."
            local count = syncPathsFromJSON()
            Utility.updatePathList()
            statusLabel.Text = "Refreshed: " .. count .. " paths loaded"
            task.wait(2)
            statusLabel.Text = "Total: " .. itemCount .. " paths loaded"
        end)
        
        syncAllButton.MouseButton1Click:Connect(function()
            statusLabel.Text = "Syncing all..."
            local count = 0
            for name, data in pairs(savedPaths) do
                if savePathToJSONFile(name, data) then
                    count = count + 1
                end
            end
            statusLabel.Text = "Synced: " .. count .. " paths to JSON"
            task.wait(2)
            statusLabel.Text = "Total: " .. itemCount .. " paths loaded"
            print("[SUPERTOOL] Synced " .. count .. " paths to JSON files")
        end)
        
        fixAllButton.MouseButton1Click:Connect(function()
            statusLabel.Text = "Fixing all paths..."
            local fixedCount = 0
            local totalCount = 0
            
            for pathName, path in pairs(savedPaths) do
                totalCount = totalCount + 1
                
                if path and path.frames then
                    local validFrames = {}
                    for i, frame in pairs(path.frames) do
                        local validFrame = validateFrame(frame)
                        if validFrame then
                            table.insert(validFrames, validFrame)
                        end
                    end
                    
                    if #validFrames > 0 then
                        path.frames = validFrames
                        path.frameCount = #validFrames
                        path.duration = validFrames[#validFrames].time
                        path.modified = os.time()
                        savePathToJSONFile(pathName, path)
                        fixedCount = fixedCount + 1
                    end
                end
            end
            
            Utility.updatePathList()
            statusLabel.Text = "Fixed: " .. fixedCount .. "/" .. totalCount .. " paths"
            task.wait(3)
            statusLabel.Text = "Total: " .. itemCount .. " paths loaded"
            print("[SUPERTOOL] Fixed " .. fixedCount .. "/" .. totalCount .. " paths")
        end)
    end
    
    task.wait(0.1)
    if PathLayout then
        local contentSize = PathLayout.AbsoluteContentSize
        PathScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 5)
    end
end

local function initPathUI()
    if PathFrame then return end
    
    PathFrame = Instance.new("Frame")
    PathFrame.Name = "PathFrame"
    PathFrame.Parent = ScreenGui
    PathFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    PathFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    PathFrame.BorderSizePixel = 1
    PathFrame.Position = UDim2.new(0.5, 0, 0.2, 0)
    PathFrame.Size = UDim2.new(0, 300, 0, 400)
    PathFrame.Visible = pathFrameVisible
    PathFrame.Active = true
    PathFrame.Draggable = true

    local PathTitle = Instance.new("TextLabel")
    PathTitle.Name = "Title"
    PathTitle.Parent = PathFrame
    PathTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    PathTitle.BorderSizePixel = 0
    PathTitle.Size = UDim2.new(1, 0, 0, 20)
    PathTitle.Font = Enum.Font.Gotham
    PathTitle.Text = "PATH CREATOR - JSON SYNC v1.2"
    PathTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    PathTitle.TextSize = 8

    local ClosePathButton = Instance.new("TextButton")
    ClosePathButton.Name = "CloseButton"
    ClosePathButton.Parent = PathFrame
    ClosePathButton.BackgroundTransparency = 1
    ClosePathButton.Position = UDim2.new(1, -20, 0, 2)
    ClosePathButton.Size = UDim2.new(0, 15, 0, 15)
    ClosePathButton.Font = Enum.Font.GothamBold
    ClosePathButton.Text = "X"
    ClosePathButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClosePathButton.TextSize = 8

    PathInput = Instance.new("TextBox")
    PathInput.Name = "PathInput"
    PathInput.Parent = PathFrame
    PathInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    PathInput.BorderSizePixel = 0
    PathInput.Position = UDim2.new(0, 5, 0, 25)
    PathInput.Size = UDim2.new(1, -65, 0, 20)
    PathInput.Font = Enum.Font.Gotham
    PathInput.PlaceholderText = "Enter path name..."
    PathInput.Text = ""
    PathInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    PathInput.TextSize = 7

    SavePathButton = Instance.new("TextButton")
    SavePathButton.Name = "SavePathButton"
    SavePathButton.Parent = PathFrame
    SavePathButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    SavePathButton.BorderSizePixel = 0
    SavePathButton.Position = UDim2.new(1, -55, 0, 25)
    SavePathButton.Size = UDim2.new(0, 50, 0, 20)
    SavePathButton.Font = Enum.Font.Gotham
    SavePathButton.Text = "SAVE"
    SavePathButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SavePathButton.TextSize = 7

    PathScrollFrame = Instance.new("ScrollingFrame")
    PathScrollFrame.Name = "PathScrollFrame"
    PathScrollFrame.Parent = PathFrame
    PathScrollFrame.BackgroundTransparency = 1
    PathScrollFrame.Position = UDim2.new(0, 5, 0, 50)
    PathScrollFrame.Size = UDim2.new(1, -10, 1, -80)
    PathScrollFrame.ScrollBarThickness = 2
    PathScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    PathScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    PathScrollFrame.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
    PathScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    PathLayout = Instance.new("UIListLayout")
    PathLayout.Parent = PathScrollFrame
    PathLayout.Padding = UDim.new(0, 2)
    PathLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local PathPauseButton = Instance.new("TextButton")
    PathPauseButton.Name = "PathPauseButton"
    PathPauseButton.Parent = PathFrame
    PathPauseButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    PathPauseButton.BorderSizePixel = 0
    PathPauseButton.Position = UDim2.new(0, 5, 1, -30)
    PathPauseButton.Size = UDim2.new(0, 100, 0, 25)
    PathPauseButton.Font = Enum.Font.Gotham
    PathPauseButton.Text = "Pause"
    PathPauseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    PathPauseButton.TextSize = 8
    PathPauseButton.Visible = pathPlaying

    PathStatusLabel = Instance.new("TextLabel")
    PathStatusLabel.Name = "PathStatusLabel"
    PathStatusLabel.Parent = ScreenGui
    PathStatusLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    PathStatusLabel.BorderColor3 = Color3.fromRGB(45, 45, 45)
    PathStatusLabel.BorderSizePixel = 1
    PathStatusLabel.Position = UDim2.new(1, -200, 0, 35)
    PathStatusLabel.Size = UDim2.new(0, 190, 0, 20)
    PathStatusLabel.Font = Enum.Font.Gotham
    PathStatusLabel.Text = ""
    PathStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    PathStatusLabel.TextSize = 8
    PathStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    PathStatusLabel.Visible = false

    SavePathButton.MouseButton1Click:Connect(function()
        stopPathRecording()
        PathFrame.Visible = true
    end)
    
    ClosePathButton.MouseButton1Click:Connect(function()
        pathFrameVisible = false
        PathFrame.Visible = false
    end)
    
    PathPauseButton.MouseButton1Click:Connect(function()
        if not pathPlaying then return end
        local path = savedPaths[currentPathName]
        local validFrames = path.frames
        local speed = path.speed or 1
        if pathPlaybackPaused then
            -- resume
            if pathPausedIndex and validFrames[pathPausedIndex] then
                pcall(function()
                    rootPart.CFrame = validFrames[pathPausedIndex].cframe
                    rootPart.Velocity = validFrames[pathPausedIndex].velocity
                    humanoid.WalkSpeed = validFrames[pathPausedIndex].walkSpeed
                    humanoid.JumpPower = validFrames[pathPausedIndex].jumpPower
                    humanoid.HipHeight = validFrames[pathPausedIndex].hipHeight
                    humanoid:ChangeState(validFrames[pathPausedIndex].state)
                end)
            end
            pathPlaybackPaused = false
            PathPauseButton.Text = "Pause"
            if pathPausePart then
                pathPausePart:Destroy()
                pathPausePart = nil
            end
        else
            -- pause
            pathPlaybackPaused = true
            pathPausedIndex = pathPausedIndex or 1 -- fallback
            pathPausedPosition = validFrames[pathPausedIndex].cframe.Position
            createPauseIndicator(pathPausedPosition)
            PathPauseButton.Text = "Resume"
        end
        updatePathStatus()
    end)
end

function Utility.loadUtilityButtons(createButton)
    createButton("Kill Player", killPlayer)
    createButton("Reset Character", resetCharacter)
    createButton("Record Macro", startMacroRecording)
    createButton("Stop Macro", stopMacroRecording)
    createButton("Macro Manager", showMacroManager)
    createButton("Record Path", startPathRecording)
    createButton("Stop Path", stopPathRecording)
    createButton("Path Manager", showPathManager)
end

function Utility.resetStates()
    -- Macro states
    macroRecording = false
    macroPlaying = false
    autoPlaying = false
    autoRespawning = false
    recordingPaused = false
    playbackPaused = false
    
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
    
    updateMacroStatus()
    Utility.updateMacroList()
    
    -- Path states
    pathRecording = false
    pathPlaying = false
    pathAutoPlaying = false
    pathAutoRespawning = false
    pathRecordingPaused = false
    pathPlaybackPaused = false
    
    if pathRecordConnection then
        pathRecordConnection:Disconnect()
        pathRecordConnection = nil
    end
    if pathPlaybackConnection then
        pathPlaybackConnection:Disconnect()
        pathPlaybackConnection = nil
    end
    
    currentPath = {}
    currentPathName = nil
    pathLastFrameTime = 0
    pathFrameVisible = false
    
    if PathFrame then
        PathFrame.Visible = false
    end
    
    updatePathStatus()
    Utility.updatePathList()
    
    print("[SUPERTOOL] Utility states reset")
end

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
    
    -- Initialize macro states
    macroRecording = false
    macroPlaying = false
    autoPlaying = false
    autoRespawning = false
    recordingPaused = false
    playbackPaused = false
    currentMacro = {}
    macroFrameVisible = false
    currentMacroName = nil
    lastFrameTime = 0
    
    -- Initialize path states
    pathRecording = false
    pathPlaying = false
    pathAutoPlaying = false
    pathAutoRespawning = false
    pathRecordingPaused = false
    pathPlaybackPaused = false
    currentPath = {}
    pathFrameVisible = false
    currentPathName = nil
    pathLastFrameTime = 0
    
    PathVisualsFolder = Instance.new("Folder")
    PathVisualsFolder.Name = "SupertoolPaths"
    PathVisualsFolder.Parent = workspace
    
    local success, error = pcall(function()
        if not isfolder("Supertool") then
            makefolder("Supertool")
            print("[SUPERTOOL] Created Supertool folder")
        end
        if not isfolder(MACRO_FOLDER_PATH) then
            makefolder(MACRO_FOLDER_PATH)
            print("[SUPERTOOL] Created macro folder: " .. MACRO_FOLDER_PATH)
        end
        if not isfolder(PATH_FOLDER_PATH) then
            makefolder(PATH_FOLDER_PATH)
            print("[SUPERTOOL] Created paths folder: " .. PATH_FOLDER_PATH)
        end
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to create folder structure: " .. tostring(error))
    end
    
    ensureFileSystem()
    
    print("[SUPERTOOL] Loading macros from JSON files...")
    local macroCount = syncMacrosFromJSON()
    
    print("[SUPERTOOL] Loading paths from JSON files...")
    local pathCount = syncPathsFromJSON()
    
    local legacyCount = 0
    if fileSystem["Supertool/path"] then
        for macroName, macroData in pairs(fileSystem["Supertool/path"]) do
            if not savedMacros[macroName] and macroData and macroData.frames then
                local validFrames = {}
                for _, frame in pairs(macroData.frames) do
                    local validFrame = validateFrame(frame)
                    if validFrame then
                        table.insert(validFrames, validFrame)
                    end
                end
                
                if #validFrames > 0 then
                    macroData.frames = validFrames
                    macroData.frameCount = #validFrames
                    macroData.duration = validFrames[#validFrames].time
                    savedMacros[macroName] = macroData
                    saveToJSONFile(macroName, macroData)
                    legacyCount = legacyCount + 1
                    print("[SUPERTOOL] Converted legacy macro: " .. macroName)
                end
            end
        end
    end
    
    local legacyPathCount = 0
    if fileSystem["Supertool/paths"] then
        for pathName, pathData in pairs(fileSystem["Supertool/paths"]) do
            if not savedPaths[pathName] and pathData and pathData.frames then
                local validFrames = {}
                for _, frame in pairs(pathData.frames) do
                    local validFrame = validateFrame(frame)
                    if validFrame then
                        table.insert(validFrames, validFrame)
                    end
                end
                
                if #validFrames > 0 then
                    pathData.frames = validFrames
                    pathData.frameCount = #validFrames
                    pathData.duration = validFrames[#validFrames].time
                    savedPaths[pathName] = pathData
                    savePathToJSONFile(pathName, pathData)
                    legacyPathCount = legacyPathCount + 1
                    print("[SUPERTOOL] Converted legacy path: " .. pathName)
                end
            end
        end
    end
    
    print("[SUPERTOOL] Loading complete: " .. macroCount .. " macros, " .. pathCount .. " paths from JSON, " .. legacyCount .. " legacy macros, " .. legacyPathCount .. " legacy paths")
    
    task.spawn(function()
        initMacroUI()
        initPathUI()
        print("[SUPERTOOL] UI components initialized")
    end)
    
    if player then
        player.CharacterAdded:Connect(function(newCharacter)
            if newCharacter then
                task.spawn(function()
                    humanoid = newCharacter:WaitForChild("Humanoid", 30)
                    rootPart = newCharacter:WaitForChild("HumanoidRootPart", 30)
                    
                    if humanoid and rootPart then
                        print("[SUPERTOOL] Character loaded successfully")
                        
                        if macroRecording and recordingPaused then
                            recordingPaused = false
                            updateMacroStatus()
                            print("[SUPERTOOL] Macro recording resumed")
                        end
                        
                        if pathRecording and pathRecordingPaused then
                            pathRecordingPaused = false
                            updatePathStatus()
                            print("[SUPERTOOL] Path recording resumed")
                        end
                        
                        if macroPlaying and currentMacroName then
                            print("[SUPERTOOL] Resuming macro playback: " .. currentMacroName)
                            playMacro(currentMacroName, autoPlaying, autoRespawning)
                        end
                        
                        if pathPlaying and currentPathName then
                            print("[SUPERTOOL] Resuming path playback: " .. currentPathName)
                            playPath(currentPathName, pathAutoPlaying, pathAutoRespawning)
                        end
                        
                        updateMacroStatus()
                        updatePathStatus()
                    else
                        warn("[SUPERTOOL] Failed to get character references after spawn")
                    end
                end)
            end
        end)
        
        player.CharacterRemoving:Connect(function()
            if macroRecording then
                recordingPaused = true
                updateMacroStatus()
                print("[SUPERTOOL] Macro recording paused due to character removal")
            end
            if pathRecording then
                pathRecordingPaused = true
                updatePathStatus()
                print("[SUPERTOOL] Path recording paused due to character removal")
            end
            if macroPlaying then
                playbackPaused = true
                updateMacroStatus()
                print("[SUPERTOOL] Macro playback paused due to character removal")
            end
            if pathPlaying then
                pathPlaybackPaused = true
                updatePathStatus()
                print("[SUPERTOOL] Path playback paused due to character removal")
            end
        end)
    end
    
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Z and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            if pathPlaying and currentPathName then
                local path = savedPaths[currentPathName]
                if path and path.waypointPositions and #path.waypointPositions > 1 then
                    local prevWP = path.waypointPositions[#path.waypointPositions - 1]
                    if rootPart then
                        rootPart.CFrame = CFrame.new(prevWP)
                    end
                end
            end
        end
    end)
    
    print("[SUPERTOOL] Utility module fully initialized")
    print("  - Macro Path: " .. MACRO_FOLDER_PATH)
    print("  - Path Creator Path: " .. PATH_FOLDER_PATH)
    print("  - Total Macros: " .. (#savedMacros > 0 and tostring(#savedMacros) or "0"))
    print("  - Total Paths: " .. (#savedPaths > 0 and tostring(#savedPaths) or "0"))
    print("  - Version: 1.2 (Path Creator & Auto-Resume)")
end

return Utility