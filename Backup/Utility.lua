-- Enhanced Utility-related features for MinimalHackGUI by Fari Noveri
-- Updated version with fixed swimming color, status sync, live idle duration, auto pause/resume, and undo functionality

-- Dependencies: These must be passed from mainloader.lua
local Players, humanoid, rootPart, ScrollFrame, buttonStates, RunService, player, ScreenGui, settings

-- Initialize module
local Utility = {}

-- Macro System Variables
local macroRecording = false
local macroPlaying = false
local autoPlaying = false
local autoRespawning = false
local macroPaused = false
local currentMacro = {}
local savedMacros = {}
local macroFrameVisible = false
local MacroFrame, MacroScrollFrame, MacroLayout, MacroInput, MacroStatusLabel
local recordConnection = nil
local playbackConnection = nil
local currentMacroName = nil
local recordingPaused = false
local lastFrameTime = 0
local macroPauseIndex = 1
local macroPauseTime = 0
local pauseResumeTime = 5 -- Seconds to wait before resuming macro after death

-- Path Recording System Variables
local pathRecording = false
local pathPlaying = false
local pathShowOnly = false
local pathPaused = false
local currentPath = {}
local savedPaths = {}
local pathFrameVisible = false
local PathFrame, PathScrollFrame, PathLayout, PathInput, PathStatusLabel
local pathConnection = nil
local pathPlayConnection = nil
local currentPathName = nil
local pathPauseIndex = 1
local lastPathTime = 0
local pathVisualParts = {}
local pathMarkerParts = {}
local idleStartTime = nil
local currentIdleLabel = nil
local idleStartPosition = nil

-- File System Integration
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MACRO_FOLDER_PATH = "Supertool/Macro/"
local PATH_FOLDER_PATH = "Supertool/Paths/"

-- Path movement detection constants
local WALK_THRESHOLD = 5 -- studs per second
local JUMP_THRESHOLD = 20 -- studs per second Y velocity
local FALL_THRESHOLD = -10 -- studs per second Y velocity
local SWIM_THRESHOLD = 2 -- when in water
local MARKER_DISTANCE = 5 -- meters between path markers

-- Movement colors
local movementColors = {
    swimming = Color3.fromRGB(128, 0, 128),
    jumping = Color3.fromRGB(255, 0, 0),
    falling = Color3.fromRGB(255, 255, 0),
    walking = Color3.fromRGB(0, 255, 0),
    idle = Color3.fromRGB(200, 200, 200)
}

-- Helper function for sanitize filename
local function sanitizeFileName(name)
    local sanitized = string.gsub(name, "[<>:\"/\\|?*]", "_")
    sanitized = string.gsub(sanitized, "^%s*(.-)%s*$", "%1")
    if sanitized == "" then
        sanitized = "unnamed_" .. os.time()
    end
    return sanitized
end

-- Helper functions for CFrame and Vector3 validation
local function validateAndConvertCFrame(cframeData)
    if not cframeData then 
        return CFrame.new(0, 0, 0) 
    end
    
    if typeof(cframeData) == "CFrame" then
        return cframeData
    end
    
    if type(cframeData) == "table" and #cframeData == 12 then
        local success, result = pcall(function()
            return CFrame.new(unpack(cframeData))
        end)
        if success and typeof(result) == "CFrame" then
            return result
        end
    end
    
    if type(cframeData) == "table" and cframeData.x and cframeData.y and cframeData.z then
        local success, result = pcall(function()
            return CFrame.new(cframeData.x, cframeData.y, cframeData.z)
        end)
        if success and typeof(result) == "CFrame" then
            return result
        end
    end
    
    warn("[SUPERTOOL] Invalid CFrame data, using origin: " .. tostring(cframeData))
    return CFrame.new(0, 0, 0)
end

local function validateAndConvertVector3(vectorData)
    if not vectorData then 
        return Vector3.new(0, 0, 0) 
    end
    
    if typeof(vectorData) == "Vector3" then
        return vectorData
    end
    
    if type(vectorData) == "table" and #vectorData == 3 then
        local success, result = pcall(function()
            return Vector3.new(vectorData[1] or 0, vectorData[2] or 0, vectorData[3] or 0)
        end)
        if success and typeof(result) == "Vector3" then
            return result
        end
    end
    
    if type(vectorData) == "table" and type(vectorData.x) == "number" and type(vectorData.y) == "number" and type(vectorData.z) == "number" then
        return Vector3.new(vectorData.x, vectorData.y, vectorData.z)
    end
    
    warn("[SUPERTOOL] Invalid Vector3 data, using zero: " .. tostring(vectorData))
    return Vector3.new(0, 0, 0)
end

local function validateFrame(rawFrame)
    if not rawFrame or type(rawFrame) ~= "table" then
        return nil
    end
    
    if not rawFrame.time or type(rawFrame.time) ~= "number" then
        return nil
    end
    
    local validatedFrame = {
        time = rawFrame.time,
        cframe = validateAndConvertCFrame(rawFrame.cframe),
        velocity = validateAndConvertVector3(rawFrame.velocity),
        walkSpeed = tonumber(rawFrame.walkSpeed) or 16,
        jumpPower = tonumber(rawFrame.jumpPower) or 50,
        hipHeight = tonumber(rawFrame.hipHeight) or 0,
        state = rawFrame.state or Enum.HumanoidStateType.Running
    }
    
    if typeof(validatedFrame.state) == "string" then
        validatedFrame.state = Enum.HumanoidStateType[rawFrame.state] or Enum.HumanoidStateType.Running
    end
    
    return validatedFrame
end

local function updateCharacterReferences()
    if player and player.Character then
        humanoid = player.Character:FindFirstChild("Humanoid")
        rootPart = player.Character:FindFirstChild("HumanoidRootPart")
        return humanoid and rootPart
    end
    return false
end

local function killPlayer()
    if humanoid then
        humanoid.Health = 0
    end
end

local function resetCharacter()
    if player then
        player:LoadCharacter()
    end
end

-- Path Movement Detection
local function detectMovementType(velocity, position)
    local speed = velocity.Magnitude
    local yVelocity = velocity.Y
    
    local isInWater = false
    if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Swimming then
        isInWater = true
    end
    
    if isInWater then
        return "swimming"
    elseif yVelocity > JUMP_THRESHOLD then
        return "jumping"
    elseif yVelocity < FALL_THRESHOLD then
        return "falling"
    elseif speed > WALK_THRESHOLD then
        return "walking"
    else
        return "idle"
    end
end

-- Get color from movement type
local function getColorFromType(movementType)
    return movementColors[movementType] or Color3.fromRGB(200, 200, 200)
end

-- Path Visualization
local function createPathVisual(position, movementType, isMarker, idleDuration)
    local color = getColorFromType(movementType)
    local part = Instance.new("Part")
    part.Name = isMarker and "PathMarker" or "PathPoint"
    part.Parent = workspace
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Transparency = isMarker and 0.3 or 0.7
    part.Size = isMarker and Vector3.new(1, 1, 1) or Vector3.new(0.5, 0.5, 0.5)
    part.Shape = isMarker and Enum.PartType.Ball or Enum.PartType.Block
    part.CFrame = CFrame.new(position)
    
    if isMarker then
        local pointLight = Instance.new("PointLight")
        pointLight.Parent = part
        pointLight.Color = color
        pointLight.Brightness = 2
        pointLight.Range = 10
        
        if movementType == "idle" and idleDuration then
            local billboard = Instance.new("BillboardGui")
            billboard.Parent = part
            billboard.Size = UDim2.new(0, 100, 0, 30)
            billboard.StudsOffset = Vector3.new(0, 2, 0)
            billboard.AlwaysOnTop = true
            
            local textLabel = Instance.new("TextLabel")
            textLabel.Parent = billboard
            textLabel.Size = UDim2.new(1, 0, 1, 0)
            textLabel.BackgroundTransparency = 1
            textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            textLabel.TextStrokeTransparency = 0.5
            textLabel.TextSize = 8
            textLabel.Font = Enum.Font.Gotham
            textLabel.Text = idleDuration >= 60 and 
                string.format("%.1fm", idleDuration/60) or 
                string.format("%.1fs", idleDuration)
            textLabel.Name = "IdleLabel"
        end
    end
    
    return part
end

local function clearPathVisuals()
    for _, part in pairs(pathVisualParts) do
        if part and part.Parent then
            part:Destroy()
        end
    end
    for _, part in pairs(pathMarkerParts) do
        if part and part.Parent then
            part:Destroy()
        end
    end
    pathVisualParts = {}
    pathMarkerParts = {}
end

-- Path Recording Functions
local function startPathRecording()
    if pathRecording or pathPlaying or macroRecording or macroPlaying then 
        warn("[SUPERTOOL] Cannot start path recording: Another recording/playback is active")
        return 
    end
    
    if not updateCharacterReferences() then
        warn("[SUPERTOOL] Cannot start path recording: Character not ready")
        return
    end
    
    pathRecording = true
    currentPath = {points = {}, startTime = tick(), markers = {}}
    lastPathTime = 0
    idleStartTime = nil
    currentIdleLabel = nil
    idleStartPosition = nil
    clearPathVisuals()
    
    print("[SUPERTOOL] Path recording started")
    
    local previousMovementType = nil
    
    pathConnection = RunService.Heartbeat:Connect(function()
        if not pathRecording or pathPaused then return end
        
        if not updateCharacterReferences() then return end
        
        local currentTime = tick() - currentPath.startTime
        local position = rootPart.Position
        local velocity = rootPart.Velocity
        local movementType = detectMovementType(velocity, position)
        
        local pathPoint = {
            time = currentTime,
            position = position,
            cframe = rootPart.CFrame,
            velocity = velocity,
            movementType = movementType,
            walkSpeed = humanoid.WalkSpeed,
            jumpPower = humanoid.JumpPower
        }
        
        table.insert(currentPath.points, pathPoint)
        
        local visualPart = createPathVisual(position, movementType, false)
        table.insert(pathVisualParts, visualPart)
        
        if movementType == "idle" then
            if previousMovementType ~= "idle" then
                idleStartTime = currentTime
                idleStartPosition = position
                currentIdleLabel = createPathVisual(position, movementType, true, 0)
                table.insert(pathMarkerParts, currentIdleLabel)
            end
            if currentIdleLabel then
                local duration = currentTime - idleStartTime
                local label = currentIdleLabel:FindFirstChildOfClass("BillboardGui"):FindFirstChild("IdleLabel")
                if label then
                    label.Text = duration >= 60 and 
                        string.format("%.1fm", duration/60) or 
                        string.format("%.1fs", duration)
                end
            end
        else
            if previousMovementType == "idle" and idleStartTime then
                local duration = currentTime - idleStartTime
                table.insert(currentPath.markers, {
                    time = idleStartTime,
                    position = idleStartPosition,
                    cframe = CFrame.new(idleStartPosition),
                    pathIndex = #currentPath.points - 1,
                    idleDuration = duration,
                    movementType = "idle"
                })
                idleStartTime = nil
                currentIdleLabel = nil
                idleStartPosition = nil
            end
        end
        
        local shouldCreateMarker = false
        if #currentPath.markers == 0 then
            shouldCreateMarker = true
        else
            local lastMarker = currentPath.markers[#currentPath.markers]
            local distance = (position - lastMarker.position).Magnitude
            if distance >= MARKER_DISTANCE then
                shouldCreateMarker = true
            end
        end
        
        if shouldCreateMarker and movementType ~= "idle" then
            local marker = {
                time = currentTime,
                position = position,
                cframe = rootPart.CFrame,
                pathIndex = #currentPath.points,
                movementType = movementType
            }
            table.insert(currentPath.markers, marker)
            
            local markerPart = createPathVisual(position, movementType, true)
            table.insert(pathMarkerParts, markerPart)
            
            print("[SUPERTOOL] Path marker created at " .. tostring(position))
        end
        
        previousMovementType = movementType
    end)
end

local function stopPathRecording()
    if not pathRecording then return end
    
    if idleStartTime then
        local duration = (tick() - currentPath.startTime) - idleStartTime
        table.insert(currentPath.markers, {
            time = idleStartTime,
            position = idleStartPosition,
            cframe = CFrame.new(idleStartPosition),
            pathIndex = #currentPath.points,
            idleDuration = duration,
            movementType = "idle"
        })
        idleStartTime = nil
        currentIdleLabel = nil
        idleStartPosition = nil
    end
    
    pathRecording = false
    pathPaused = false
    if pathConnection then
        pathConnection:Disconnect()
        pathConnection = nil
    end
    
    local pathName = PathInput.Text
    if pathName == "" then
        pathName = "Path_" .. os.date("%H%M%S")
    end
    
    if #currentPath.points == 0 then
        warn("[SUPERTOOL] Cannot save empty path")
        clearPathVisuals()
        return
    end
    
    currentPath.name = pathName
    currentPath.created = os.time()
    currentPath.pointCount = #currentPath.points
    currentPath.markerCount = #currentPath.markers
    currentPath.duration = currentPath.points[#currentPath.points].time
    
    savedPaths[pathName] = currentPath
    savePathToJSON(pathName, currentPath)
    
    PathInput.Text = ""
    updatePathList()
    
    print("[SUPERTOOL] Path recorded: " .. pathName .. " (" .. #currentPath.points .. " points, " .. #currentPath.markers .. " markers)")
end

-- Path Playback Functions
local function playPath(pathName, showOnly, autoPlay, respawn)
    if pathRecording or pathPlaying or macroRecording or macroPlaying then return end
    
    if not updateCharacterReferences() then
        warn("[SUPERTOOL] Cannot play path: Character not ready")
        return
    end
    
    local path = savedPaths[pathName] or loadPathFromJSON(pathName)
    if not path or not path.points or #path.points == 0 then
        warn("[SUPERTOOL] Cannot play path: Invalid path data")
        return
    end
    
    pathPlaying = true
    pathShowOnly = showOnly or false
    pathAutoPlaying = autoPlay or false
    pathAutoRespawning = respawn or false
    currentPathName = pathName
    pathPaused = false
    pathPauseIndex = 1
    
    clearPathVisuals()
    for i, point in pairs(path.points) do
        local visualPart = createPathVisual(point.position, point.movementType, false)
        table.insert(pathVisualParts, visualPart)
    end
    
    for i, marker in pairs(path.markers or {}) do
        local markerPart = createPathVisual(marker.position, marker.movementType or "marker", true, marker.idleDuration)
        table.insert(pathMarkerParts, markerPart)
    end
    
    if pathShowOnly then
        print("[SUPERTOOL] Showing path: " .. pathName)
        updatePathStatus()
        return
    end
    
    print("[SUPERTOOL] Playing path: " .. pathName)
    
    local startTime = tick()
    local index = 1
    
    pathPlayConnection = RunService.Heartbeat:Connect(function()
        if not pathPlaying or pathPaused then return end
        
        if not updateCharacterReferences() then return end
        
        if index > #path.points then
            if pathAutoPlaying then
                if pathAutoRespawning then
                    resetCharacter()
                else
                    index = 1
                    startTime = tick()
                end
            else
                pathPlaying = false
                currentPathName = nil
                if pathPlayConnection then
                    pathPlayConnection:Disconnect()
                    pathPlayConnection = nil
                end
                humanoid.WalkSpeed = settings.WalkSpeed.value or 16
                updatePathStatus()
                return
            end
        end
        
        local point = path.points[index]
        if point and tick() - startTime >= point.time then
            pcall(function()
                rootPart.CFrame = point.cframe
                rootPart.Velocity = point.velocity
                humanoid.WalkSpeed = point.walkSpeed
                humanoid.JumpPower = point.jumpPower
            end)
            index = index + 1
        end
    end)
end

local function stopPathPlayback()
    if not pathPlaying then return end
    pathPlaying = false
    pathAutoPlaying = false
    pathAutoRespawning = false
    pathPaused = false
    pathPauseIndex = 1
    if pathPlayConnection then
        pathPlayConnection:Disconnect()
        pathPlayConnection = nil
    end
    if humanoid then
        humanoid.WalkSpeed = settings.WalkSpeed.value or 16
    end
    currentPathName = nil
    updatePathList()
    updatePathStatus()
end

-- Path Undo System
local function undoToLastMarker()
    if not currentPathName then return end
    
    local path = savedPaths[currentPathName]
    if not path or not path.markers or #path.markers == 0 then return end
    
    local lastMarkerIndex = #path.markers
    local lastMarker = path.markers[lastMarkerIndex]
    if lastMarker and updateCharacterReferences() then
        rootPart.CFrame = lastMarker.cframe
        print("[SUPERTOOL] Undid to last marker at " .. tostring(lastMarker.position))
        
        -- Remove points and markers after the last marker
        path.points = {table.unpack(path.points, 1, lastMarker.pathIndex)}
        path.markers = {table.unpack(path.markers, 1, lastMarkerIndex - 1)}
        path.pointCount = #path.points
        path.markerCount = #path.markers
        path.duration = path.points[#path.points].time
        
        -- Save updated path
        savePathToJSON(currentPathName, path)
        
        -- Update visuals
        clearPathVisuals()
        for i, point in pairs(path.points) do
            local visualPart = createPathVisual(point.position, point.movementType, false)
            table.insert(pathVisualParts, visualPart)
        end
        
        for i, marker in pairs(path.markers) do
            local markerPart = createPathVisual(marker.position, marker.movementType or "marker", true, marker.idleDuration)
            table.insert(pathMarkerParts, markerPart)
        end
        
        -- Create white sphere at undo position
        local undoMarker = createPathVisual(lastMarker.position, "idle", true)
        table.insert(pathMarkerParts, undoMarker)
    end
end

-- File system functions for paths
function savePathToJSON(pathName, pathData)
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(pathName)
        local fileName = sanitizedName .. ".json"
        local filePath = PATH_FOLDER_PATH .. fileName
        
        if not isfolder(PATH_FOLDER_PATH) then
            makefolder(PATH_FOLDER_PATH)
        end
        
        local serializedPoints = {}
        for _, point in ipairs(pathData.points or {}) do
            table.insert(serializedPoints, {
                time = point.time,
                position = {point.position.X, point.position.Y, point.position.Z},
                cframe = {point.cframe:GetComponents()},
                velocity = {point.velocity.X, point.velocity.Y, point.velocity.Z},
                movementType = point.movementType,
                walkSpeed = point.walkSpeed,
                jumpPower = point.jumpPower
            })
        end
        
        local serializedMarkers = {}
        for _, marker in ipairs(pathData.markers or {}) do
            table.insert(serializedMarkers, {
                time = marker.time,
                position = {marker.position.X, marker.position.Y, marker.position.Z},
                cframe = {marker.cframe:GetComponents()},
                pathIndex = marker.pathIndex,
                idleDuration = marker.idleDuration,
                movementType = marker.movementType
            })
        end
        
        local jsonData = {
            name = pathName,
            created = pathData.created or os.time(),
            points = serializedPoints,
            markers = serializedMarkers,
            pointCount = #serializedPoints,
            markerCount = #serializedMarkers,
            duration = pathData.duration,
            speed = pathData.speed or 1
        }
        
        local jsonString = HttpService:JSONEncode(jsonData)
        writefile(filePath, jsonString)
        
        print("[SUPERTOOL] Path saved: " .. filePath)
        return true
    end)
    
    return success
end

function loadPathFromJSON(pathName)
    local success, result = pcall(function()
        local sanitizedName = sanitizeFileName(pathName)
        local fileName = sanitizedName .. ".json"
        local filePath = PATH_FOLDER_PATH .. fileName
        
        if not isfile(filePath) then return nil end
        
        local jsonString = readfile(filePath)
        local jsonData = HttpService:JSONDecode(jsonString)
        
        local validPoints = {}
        for _, pointData in ipairs(jsonData.points or {}) do
            local point = {
                time = pointData.time,
                position = validateAndConvertVector3(pointData.position),
                cframe = validateAndConvertCFrame(pointData.cframe),
                velocity = validateAndConvertVector3(pointData.velocity),
                movementType = pointData.movementType or "walking",
                walkSpeed = pointData.walkSpeed or 16,
                jumpPower = pointData.jumpPower or 50
            }
            table.insert(validPoints, point)
        end
        
        local validMarkers = {}
        for _, markerData in ipairs(jsonData.markers or {}) do
            local marker = {
                time = markerData.time,
                position = validateAndConvertVector3(markerData.position),
                cframe = validateAndConvertCFrame(markerData.cframe),
                pathIndex = markerData.pathIndex,
                idleDuration = markerData.idleDuration,
                movementType = markerData.movementType
            }
            table.insert(validMarkers, marker)
        end
        
        return {
            name = jsonData.name or pathName,
            created = jsonData.created or os.time(),
            points = validPoints,
            markers = validMarkers,
            pointCount = #validPoints,
            markerCount = #validMarkers,
            duration = jsonData.duration or 0,
            speed = jsonData.speed or 1
        }
    end)
    
    return success and result or nil
end

function deletePathFromJSON(pathName)
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(pathName)
        local fileName = sanitizedName .. ".json"
        local filePath = PATH_FOLDER_PATH .. fileName
        
        if isfile(filePath) then
            delfile(filePath)
            print("[SUPERTOOL] Path deleted: " .. filePath)
            return true
        end
        return false
    end)
    
    return success and error or false
end

function renamePathInJSON(oldName, newName)
    local success, error = pcall(function()
        local oldData = loadPathFromJSON(oldName)
        if not oldData then return false end
        
        oldData.name = newName
        oldData.modified = os.time()
        
        if savePathToJSON(newName, oldData) then
            deletePathFromJSON(oldName)
            return true
        end
        return false
    end)
    
    return success and error or false
end

-- Macro Functions
local function startMacroRecording()
    if macroRecording or macroPlaying or pathRecording or pathPlaying then 
        warn("[SUPERTOOL] Cannot start macro recording: Another recording/playback is active")
        return 
    end
    
    if not updateCharacterReferences() then
        warn("[SUPERTOOL] Cannot start recording: Character not ready")
        return
    end
    
    macroRecording = true
    recordingPaused = false
    macroPaused = false
    currentMacro = {frames = {}, startTime = tick(), speed = 1}
    lastFrameTime = 0
    updateMacroStatus()
    
    recordConnection = RunService.Heartbeat:Connect(function()
        if not macroRecording or macroPaused then return end
        
        if not updateCharacterReferences() then return end
        
        local success, frame = pcall(function()
            return {
                time = tick() - currentMacro.startTime,
                cframe = rootPart.CFrame,
                velocity = rootPart.Velocity,
                walkSpeed = humanoid.WalkSpeed,
                jumpPower = humanoid.JumpPower,
                hipHeight = humanoid.HipHeight,
                state = humanoid:GetState()
            }
        end)
        
        if success and frame then
            table.insert(currentMacro.frames, frame)
        end
    end)
end

local function stopMacroRecording()
    if not macroRecording then return end
    macroRecording = false
    macroPaused = false
    recordingPaused = false
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    
    local macroName = MacroInput.Text
    if macroName == "" then
        macroName = "Macro_" .. os.date("%H%M%S")
    end
    
    if #currentMacro.frames == 0 then
        warn("[SUPERTOOL] Cannot save empty macro")
        updateMacroStatus()
        return
    end
    
    currentMacro.frameCount = #currentMacro.frames
    currentMacro.duration = currentMacro.frames[#currentMacro.frames].time
    currentMacro.created = os.time()
    
    savedMacros[macroName] = currentMacro
    saveMacroToJSON(macroName, currentMacro)
    
    MacroInput.Text = ""
    Utility.updateMacroList()
    updateMacroStatus()
    if MacroFrame then
        MacroFrame.Visible = true
    end
    
    print("[SUPERTOOL] Macro saved: " .. macroName)
end

local function stopMacroPlayback()
    if not macroPlaying then return end
    macroPlaying = false
    autoPlaying = false
    autoRespawning = false
    macroPaused = false
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    if humanoid then
        humanoid.WalkSpeed = settings.WalkSpeed.value or 16
    end
    currentMacroName = nil
    Utility.updateMacroList()
    updateMacroStatus()
end

local function playMacro(macroName, autoPlay, respawn)
    if macroRecording or macroPlaying or pathRecording or pathPlaying then
        stopMacroPlayback()
    end
    
    if not updateCharacterReferences() then
        warn("[SUPERTOOL] Cannot play macro: Character not ready")
        return
    end
    
    local macro = savedMacros[macroName] or loadMacroFromJSON(macroName)
    if not macro or not macro.frames or #macro.frames == 0 then
        warn("[SUPERTOOL] Cannot play macro: Invalid macro data for " .. macroName)
        return
    end
    
    macroPlaying = true
    autoPlaying = autoPlay or false
    autoRespawning = respawn or false
    macroPaused = false
    currentMacroName = macroName
    humanoid.WalkSpeed = 0
    updateMacroStatus()
    
    print("[SUPERTOOL] Playing macro: " .. macroName)
    
    local startTime = tick()
    local index = 1
    local speed = macro.speed or 1
    
    playbackConnection = RunService.Heartbeat:Connect(function()
        if not macroPlaying or macroPaused then return end
        
        if not updateCharacterReferences() then return end
        
        if index > #macro.frames then
            if autoPlaying then
                if autoRespawning then
                    resetCharacter()
                else
                    index = 1
                    startTime = tick()
                end
            else
                stopMacroPlayback()
                return
            end
        end
        
        local frame = macro.frames[index]
        local scaledTime = frame.time / speed
        
        if scaledTime <= (tick() - startTime) then
            pcall(function()
                rootPart.CFrame = frame.cframe
                rootPart.Velocity = frame.velocity
                humanoid.WalkSpeed = frame.walkSpeed
                humanoid.JumpPower = frame.jumpPower
                humanoid.HipHeight = frame.hipHeight
                humanoid:ChangeState(frame.state)
            end)
            index = index + 1
        end
    end)
end

local function pauseMacro()
    if not macroPlaying then return end
    macroPaused = not macroPaused
    updateMacroStatus()
end

local function pausePath()
    if not pathPlaying then return end
    pathPaused = not pathPaused
    updatePathStatus()
end

-- Status Update Functions
local function updateMacroStatus()
    if not MacroStatusLabel then return end
    
    local statusText = ""
    if macroRecording then
        statusText = recordingPaused and "Recording Paused" or "Recording Macro..."
    elseif macroPlaying and currentMacroName then
        local macro = savedMacros[currentMacroName] or loadMacroFromJSON(currentMacroName)
        local speed = macro and macro.speed or 1
        local modeText = autoRespawning and "Auto-Respawning Macro" or (autoPlaying and "Auto-Playing Macro" or "Playing Macro")
        statusText = (macroPaused and "Paused: " or modeText .. ": ") .. currentMacroName .. " (Speed: " .. speed .. "x)"
    end
    
    MacroStatusLabel.Text = statusText
    MacroStatusLabel.Visible = statusText ~= ""
end

local function updatePathStatus()
    if not PathStatusLabel then return end
    
    local statusText = ""
    if pathRecording then
        statusText = pathPaused and "Recording Paused" or "Recording Path..."
    elseif pathPlaying and currentPathName then
        local statusPrefix = pathShowOnly and "👁️ Showing Path: " or "🛤️ Playing Path: "
        local modeText = pathAutoRespawning and "Auto-Respawning Path" or (pathAutoPlaying and "Auto-Playing Path" or "Playing Path")
        statusText = (pathPaused and "Paused: " or (pathShowOnly and statusPrefix or modeText .. ": ")) .. currentPathName
    end
    
    PathStatusLabel.Text = statusText
    PathStatusLabel.Visible = statusText ~= ""
end

-- File System Integration
function saveMacroToJSON(macroName, macroData)
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(macroName)
        local fileName = sanitizedName .. ".json"
        local filePath = MACRO_FOLDER_PATH .. fileName
        
        if not isfolder(MACRO_FOLDER_PATH) then
            makefolder(MACRO_FOLDER_PATH)
        end
        
        if not macroData or not macroData.frames then
            return false
        end
        
        local serializedFrames = {}
        for i, frame in pairs(macroData.frames) do
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
        
        local jsonData = {
            name = macroName,
            created = macroData.created or os.time(),
            frames = serializedFrames,
            speed = macroData.speed or 1,
            frameCount = #serializedFrames,
            duration = serializedFrames[#serializedFrames] and serializedFrames[#serializedFrames].time or 0
        }
        
        local jsonString = HttpService:JSONEncode(jsonData)
        writefile(filePath, jsonString)
        print("[SUPERTOOL] Macro saved: " .. filePath)
        return true
    end)
    
    return success
end

function loadMacroFromJSON(macroName)
    local success, result = pcall(function()
        local sanitizedName = sanitizeFileName(macroName)
        local fileName = sanitizedName .. ".json"
        local filePath = MACRO_FOLDER_PATH .. fileName
        
        if not isfile(filePath) then return nil end
        
        local jsonString = readfile(filePath)
        local jsonData = HttpService:JSONDecode(jsonString)
        
        local validFrames = {}
        for i, rawFrame in pairs(jsonData.frames or {}) do
            local validFrame = validateFrame(rawFrame)
            if validFrame then
                table.insert(validFrames, validFrame)
            end
        end
        
        if #validFrames == 0 then return nil end
        
        return {
            name = jsonData.name or macroName,
            created = jsonData.created or os.time(),
            frames = validFrames,
            speed = jsonData.speed or 1,
            frameCount = #validFrames,
            duration = validFrames[#validFrames].time
        }
    end)
    
    return success and result or nil
end

function deleteMacroFromJSON(macroName)
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(macroName)
        local fileName = sanitizedName .. ".json"
        local filePath = MACRO_FOLDER_PATH .. fileName
        
        if isfile(filePath) then
            delfile(filePath)
            print("[SUPERTOOL] Macro deleted: " .. filePath)
            return true
        end
        return false
    end)
    
    return success and error or false
end

function renameMacroInJSON(oldName, newName)
    local success, error = pcall(function()
        local oldData = loadMacroFromJSON(oldName)
        if not oldData then return false end
        
        oldData.name = newName
        oldData.modified = os.time()
        
        if saveMacroToJSON(newName, oldData) then
            deleteMacroFromJSON(oldName)
            return true
        end
        return false
    end)
    
    return success and error or false
end

-- UI Components
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
    MacroFrame.Visible = false
    MacroFrame.Active = true
    MacroFrame.Draggable = true

    local MacroTitle = Instance.new("TextLabel")
    MacroTitle.Parent = MacroFrame
    MacroTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    MacroTitle.BorderSizePixel = 0
    MacroTitle.Size = UDim2.new(1, 0, 0, 20)
    MacroTitle.Font = Enum.Font.Gotham
    MacroTitle.Text = "MACRO MANAGER - JSON SYNC v1.3"
    MacroTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    MacroTitle.TextSize = 8

    local CloseMacroButton = Instance.new("TextButton")
    CloseMacroButton.Parent = MacroFrame
    CloseMacroButton.BackgroundTransparency = 1
    CloseMacroButton.Position = UDim2.new(1, -20, 0, 2)
    CloseMacroButton.Size = UDim2.new(0, 15, 0, 15)
    CloseMacroButton.Font = Enum.Font.GothamBold
    CloseMacroButton.Text = "X"
    CloseMacroButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseMacroButton.TextSize = 8

    MacroInput = Instance.new("TextBox")
    MacroInput.Parent = MacroFrame
    MacroInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    MacroInput.BorderSizePixel = 0
    MacroInput.Position = UDim2.new(0, 5, 0, 25)
    MacroInput.Size = UDim2.new(1, -10, 0, 20)
    MacroInput.Font = Enum.Font.Gotham
    MacroInput.PlaceholderText = "Search macros..."
    MacroInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    MacroInput.TextSize = 7

    MacroScrollFrame = Instance.new("ScrollingFrame")
    MacroScrollFrame.Parent = MacroFrame
    MacroScrollFrame.BackgroundTransparency = 1
    MacroScrollFrame.Position = UDim2.new(0, 5, 0, 50)
    MacroScrollFrame.Size = UDim2.new(1, -10, 1, -80)
    MacroScrollFrame.ScrollBarThickness = 2
    MacroScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    MacroScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    MacroLayout = Instance.new("UIListLayout")
    MacroLayout.Parent = MacroScrollFrame
    MacroLayout.Padding = UDim.new(0, 2)

    local MacroPauseButton = Instance.new("TextButton")
    MacroPauseButton.Parent = MacroFrame
    MacroPauseButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    MacroPauseButton.BorderSizePixel = 0
    MacroPauseButton.Position = UDim2.new(0, 5, 1, -30)
    MacroPauseButton.Size = UDim2.new(0, 100, 0, 25)
    MacroPauseButton.Font = Enum.Font.Gotham
    MacroPauseButton.Text = "Pause"
    MacroPauseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    MacroPauseButton.TextSize = 8
    MacroPauseButton.Visible = macroPlaying

    MacroStatusLabel = Instance.new("TextLabel")
    MacroStatusLabel.Parent = ScreenGui
    MacroStatusLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    MacroStatusLabel.BorderColor3 = Color3.fromRGB(45, 45, 45)
    MacroStatusLabel.BorderSizePixel = 1
    MacroStatusLabel.Position = UDim2.new(1, -250, 0, 5)
    MacroStatusLabel.Size = UDim2.new(0, 240, 0, 25)
    MacroStatusLabel.Font = Enum.Font.Gotham
    MacroStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    MacroStatusLabel.TextSize = 8
    MacroStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    MacroStatusLabel.Visible = false

    CloseMacroButton.MouseButton1Click:Connect(function()
        MacroFrame.Visible = false
        macroFrameVisible = false
    end)

    MacroPauseButton.MouseButton1Click:Connect(pauseMacro)
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
    PathFrame.Visible = false
    PathFrame.Active = true
    PathFrame.Draggable = true

    local PathTitle = Instance.new("TextLabel")
    PathTitle.Parent = PathFrame
    PathTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    PathTitle.BorderSizePixel = 0
    PathTitle.Size = UDim2.new(1, 0, 0, 20)
    PathTitle.Font = Enum.Font.Gotham
    PathTitle.Text = "PATH CREATOR - JSON SYNC v1.3"
    PathTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    PathTitle.TextSize = 8

    local ClosePathButton = Instance.new("TextButton")
    ClosePathButton.Parent = PathFrame
    ClosePathButton.BackgroundTransparency = 1
    ClosePathButton.Position = UDim2.new(1, -20, 0, 2)
    ClosePathButton.Size = UDim2.new(0, 15, 0, 15)
    ClosePathButton.Font = Enum.Font.GothamBold
    ClosePathButton.Text = "X"
    ClosePathButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClosePathButton.TextSize = 8

    PathInput = Instance.new("TextBox")
    PathInput.Parent = PathFrame
    PathInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    PathInput.BorderSizePixel = 0
    PathInput.Position = UDim2.new(0, 5, 0, 25)
    PathInput.Size = UDim2.new(1, -10, 0, 20)
    PathInput.Font = Enum.Font.Gotham
    PathInput.PlaceholderText = "Search paths..."
    PathInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    PathInput.TextSize = 7

    PathScrollFrame = Instance.new("ScrollingFrame")
    PathScrollFrame.Parent = PathFrame
    PathScrollFrame.BackgroundTransparency = 1
    PathScrollFrame.Position = UDim2.new(0, 5, 0, 50)
    PathScrollFrame.Size = UDim2.new(1, -10, 1, -80)
    PathScrollFrame.ScrollBarThickness = 2
    PathScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    PathScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    PathLayout = Instance.new("UIListLayout")
    PathLayout.Parent = PathScrollFrame
    PathLayout.Padding = UDim.new(0, 2)

    local PathPauseButton = Instance.new("TextButton")
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
    PathStatusLabel.Parent = ScreenGui
    PathStatusLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    PathStatusLabel.BorderColor3 = Color3.fromRGB(45, 45, 45)
    PathStatusLabel.BorderSizePixel = 1
    PathStatusLabel.Position = UDim2.new(1, -250, 0, 30)
    PathStatusLabel.Size = UDim2.new(0, 240, 0, 25)
    PathStatusLabel.Font = Enum.Font.Gotham
    PathStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    PathStatusLabel.TextSize = 8
    PathStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    PathStatusLabel.Visible = false

    ClosePathButton.MouseButton1Click:Connect(function()
        PathFrame.Visible = false
        pathFrameVisible = false
    end)

    PathPauseButton.MouseButton1Click:Connect(pausePath)
end

function Utility.updateMacroList()
    if not MacroScrollFrame then return end
    
    for _, child in pairs(MacroScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local searchText = MacroInput.Text:lower()
    for macroName, macro in pairs(savedMacros) do
        if searchText == "" or string.find(macroName:lower(), searchText) then
            local macroItem = Instance.new("Frame")
            macroItem.Parent = MacroScrollFrame
            macroItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            macroItem.Size = UDim2.new(1, -5, 0, 110)
            
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Parent = macroItem
            nameLabel.Position = UDim2.new(0, 5, 0, 5)
            nameLabel.Size = UDim2.new(1, -10, 0, 15)
            nameLabel.Text = macroName
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.BackgroundTransparency = 1
            nameLabel.TextSize = 7
            nameLabel.Font = Enum.Font.Gotham
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            local frameCount = macro.frameCount or #(macro.frames or {})
            local duration = macro.duration or 0
            local infoLabel = Instance.new("TextLabel")
            infoLabel.Parent = macroItem
            infoLabel.Position = UDim2.new(0, 5, 0, 20)
            infoLabel.Size = UDim2.new(1, -10, 0, 10)
            infoLabel.BackgroundTransparency = 1
            infoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            infoLabel.TextSize = 6
            infoLabel.Font = Enum.Font.Gotham
            infoLabel.Text = string.format("Frames: %d | Duration: %.1fs", frameCount, duration)
            infoLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            local playButton = Instance.new("TextButton")
            playButton.Parent = macroItem
            playButton.Position = UDim2.new(0, 5, 0, 40)
            playButton.Size = UDim2.new(0, 40, 0, 18)
            playButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            playButton.TextSize = 7
            playButton.Font = Enum.Font.Gotham
            playButton.Text = (macroPlaying and currentMacroName == macroName and not autoPlaying) and "STOP" or "PLAY"
            
            local autoPlayButton = Instance.new("TextButton")
            autoPlayButton.Parent = macroItem
            autoPlayButton.Position = UDim2.new(0, 50, 0, 40)
            autoPlayButton.Size = UDim2.new(0, 40, 0, 18)
            autoPlayButton.BackgroundColor3 = Color3.fromRGB(60, 80, 60)
            autoPlayButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            autoPlayButton.TextSize = 7
            autoPlayButton.Font = Enum.Font.Gotham
            autoPlayButton.Text = (macroPlaying and currentMacroName == macroName and autoPlaying and not autoRespawning) and "STOP" or "AUTO"
            
            local autoRespawnButton = Instance.new("TextButton")
            autoRespawnButton.Parent = macroItem
            autoRespawnButton.Position = UDim2.new(0, 95, 0, 40)
            autoRespawnButton.Size = UDim2.new(0, 40, 0, 18)
            autoRespawnButton.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
            autoRespawnButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            autoRespawnButton.TextSize = 7
            autoRespawnButton.Font = Enum.Font.Gotham
            autoRespawnButton.Text = (macroPlaying and currentMacroName == macroName and autoPlaying and autoRespawning) and "STOP" or "A-RESP"
            
            local deleteButton = Instance.new("TextButton")
            deleteButton.Parent = macroItem
            deleteButton.Position = UDim2.new(0, 140, 0, 40)
            deleteButton.Size = UDim2.new(0, 40, 0, 18)
            deleteButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
            deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            deleteButton.TextSize = 7
            deleteButton.Font = Enum.Font.Gotham
            deleteButton.Text = "DELETE"
            
            local renameInput = Instance.new("TextBox")
            renameInput.Parent = macroItem
            renameInput.Position = UDim2.new(0, 5, 0, 65)
            renameInput.Size = UDim2.new(0, 130, 0, 15)
            renameInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            renameInput.BorderSizePixel = 0
            renameInput.PlaceholderText = "Rename..."
            renameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
            renameInput.TextSize = 6
            renameInput.Font = Enum.Font.Gotham
            
            local renameButton = Instance.new("TextButton")
            renameButton.Parent = macroItem
            renameButton.Position = UDim2.new(0, 140, 0, 65)
            renameButton.Size = UDim2.new(0, 40, 0, 15)
            renameButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
            renameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            renameButton.TextSize = 6
            renameButton.Font = Enum.Font.Gotham
            renameButton.Text = "RENAME"
            
            local speedLabel = Instance.new("TextLabel")
            speedLabel.Parent = macroItem
            speedLabel.Position = UDim2.new(0, 5, 0, 85)
            speedLabel.Size = UDim2.new(0, 40, 0, 15)
            speedLabel.BackgroundTransparency = 1
            speedLabel.Text = "Speed:"
            speedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            speedLabel.TextSize = 6
            speedLabel.Font = Enum.Font.Gotham
            speedLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            local speedInput = Instance.new("TextBox")
            speedInput.Parent = macroItem
            speedInput.Position = UDim2.new(0, 50, 0, 85)
            speedInput.Size = UDim2.new(0, 40, 0, 15)
            speedInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            speedInput.BorderSizePixel = 0
            speedInput.Text = tostring(macro.speed or 1)
            speedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
            speedInput.TextSize = 6
            speedInput.Font = Enum.Font.Gotham
            
            playButton.MouseButton1Click:Connect(function()
                if macroPlaying and currentMacroName == macroName and not autoPlaying then
                    stopMacroPlayback()
                else
                    playMacro(macroName, false, false)
                end
                Utility.updateMacroList()
            end)
            
            autoPlayButton.MouseButton1Click:Connect(function()
                if macroPlaying and currentMacroName == macroName and autoPlaying and not autoRespawning then
                    stopMacroPlayback()
                else
                    playMacro(macroName, true, false)
                end
                Utility.updateMacroList()
            end)
            
            autoRespawnButton.MouseButton1Click:Connect(function()
                if macroPlaying and currentMacroName == macroName and autoPlaying and autoRespawning then
                    stopMacroPlayback()
                else
                    playMacro(macroName, true, true)
                end
                Utility.updateMacroList()
            end)
            
            deleteButton.MouseButton1Click:Connect(function()
                if macroPlaying and currentMacroName == macroName then
                    stopMacroPlayback()
                end
                savedMacros[macroName] = nil
                deleteMacroFromJSON(macroName)
                Utility.updateMacroList()
            end)
            
            renameButton.MouseButton1Click:Connect(function()
                if renameInput.Text ~= "" then
                    local newName = renameInput.Text
                    if savedMacros[macroName] then
                        savedMacros[newName] = savedMacros[macroName]
                        savedMacros[macroName] = nil
                        
                        if macroPlaying and currentMacroName == macroName then
                            currentMacroName = newName
                        end
                        
                        renameMacroInJSON(macroName, newName)
                        renameInput.Text = ""
                        Utility.updateMacroList()
                    end
                end
            end)
            
            speedInput.FocusLost:Connect(function(enterPressed)
                if enterPressed then
                    local newSpeed = tonumber(speedInput.Text)
                    if newSpeed and newSpeed > 0 and newSpeed <= 10 then
                        macro.speed = newSpeed
                        saveMacroToJSON(macroName, macro)
                    else
                        speedInput.Text = tostring(macro.speed or 1)
                    end
                end
            end)
        end
    end
    
    task.wait(0.1)
    if MacroLayout then
        MacroScrollFrame.CanvasSize = UDim2.new(0, 0, 0, MacroLayout.AbsoluteContentSize.Y + 5)
    end
end

function updatePathList()
    if not PathScrollFrame then return end
    
    for _, child in pairs(PathScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local searchText = PathInput.Text:lower()
    for pathName, path in pairs(savedPaths) do
        if searchText == "" or string.find(pathName:lower(), searchText) then
            local pathItem = Instance.new("Frame")
            pathItem.Parent = PathScrollFrame
            pathItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            pathItem.Size = UDim2.new(1, -5, 0, 110)
            
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Parent = pathItem
            nameLabel.Position = UDim2.new(0, 5, 0, 5)
            nameLabel.Size = UDim2.new(1, -10, 0, 15)
            nameLabel.Text = pathName
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.BackgroundTransparency = 1
            nameLabel.TextSize = 7
            nameLabel.Font = Enum.Font.Gotham
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            local infoLabel = Instance.new("TextLabel")
            infoLabel.Parent = pathItem
            infoLabel.Position = UDim2.new(0, 5, 0, 20)
            infoLabel.Size = UDim2.new(1, -10, 0, 10)
            infoLabel.BackgroundTransparency = 1
            infoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            infoLabel.TextSize = 6
            infoLabel.Font = Enum.Font.Gotham
            infoLabel.Text = string.format("Points: %d | Markers: %d | Duration: %.1fs", 
                                         path.pointCount or 0, 
                                         path.markerCount or 0, 
                                         path.duration or 0)
            infoLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            local playButton = Instance.new("TextButton")
            playButton.Parent = pathItem
            playButton.Position = UDim2.new(0, 5, 0, 40)
            playButton.Size = UDim2.new(0, 40, 0, 18)
            playButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            playButton.TextSize = 7
            playButton.Font = Enum.Font.Gotham
            playButton.Text = (pathPlaying and currentPathName == pathName and not pathAutoPlaying) and "STOP" or "PLAY"
            
            local autoPlayButton = Instance.new("TextButton")
            autoPlayButton.Parent = pathItem
            autoPlayButton.Position = UDim2.new(0, 50, 0, 40)
            autoPlayButton.Size = UDim2.new(0, 40, 0, 18)
            autoPlayButton.BackgroundColor3 = Color3.fromRGB(60, 80, 60)
            autoPlayButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            autoPlayButton.TextSize = 7
            autoPlayButton.Font = Enum.Font.Gotham
            autoPlayButton.Text = (pathPlaying and currentPathName == pathName and pathAutoPlaying and not pathAutoRespawning) and "STOP" or "AUTO"
            
            local autoRespButton = Instance.new("TextButton")
            autoRespButton.Parent = pathItem
            autoRespButton.Position = UDim2.new(0, 95, 0, 40)
            autoRespButton.Size = UDim2.new(0, 40, 0, 18)
            autoRespButton.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
            autoRespButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            autoRespButton.TextSize = 7
            autoRespButton.Font = Enum.Font.Gotham
            autoRespButton.Text = (pathPlaying and currentPathName == pathName and pathAutoPlaying and pathAutoRespawning) and "STOP" or "A-RESP"
            
            local showButton = Instance.new("TextButton")
            showButton.Parent = pathItem
            showButton.Position = UDim2.new(0, 140, 0, 40)
            showButton.Size = UDim2.new(0, 40, 0, 18)
            showButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
            showButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            showButton.TextSize = 7
            showButton.Font = Enum.Font.Gotham
            showButton.Text = "SHOW"
            
            local deleteButton = Instance.new("TextButton")
            deleteButton.Parent = pathItem
            deleteButton.Position = UDim2.new(0, 185, 0, 40)
            deleteButton.Size = UDim2.new(0, 40, 0, 18)
            deleteButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
            deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            deleteButton.TextSize = 7
            deleteButton.Font = Enum.Font.Gotham
            deleteButton.Text = "DELETE"
            
            local renameInput = Instance.new("TextBox")
            renameInput.Parent = pathItem
            renameInput.Position = UDim2.new(0, 5, 0, 65)
            renameInput.Size = UDim2.new(0, 130, 0, 15)
            renameInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            renameInput.BorderSizePixel = 0
            renameInput.PlaceholderText = "Rename..."
            renameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
            renameInput.TextSize = 6
            renameInput.Font = Enum.Font.Gotham
            
            local renameButton = Instance.new("TextButton")
            renameButton.Parent = pathItem
            renameButton.Position = UDim2.new(0, 140, 0, 65)
            renameButton.Size = UDim2.new(0, 40, 0, 15)
            renameButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
            renameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            renameButton.TextSize = 6
            renameButton.Font = Enum.Font.Gotham
            renameButton.Text = "RENAME"
            
            local speedLabel = Instance.new("TextLabel")
            speedLabel.Parent = pathItem
            speedLabel.Position = UDim2.new(0, 5, 0, 85)
            speedLabel.Size = UDim2.new(0, 40, 0, 15)
            speedLabel.BackgroundTransparency = 1
            speedLabel.Text = "Speed:"
            speedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            speedLabel.TextSize = 6
            speedLabel.Font = Enum.Font.Gotham
            speedLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            local speedInput = Instance.new("TextBox")
            speedInput.Parent = pathItem
            speedInput.Position = UDim2.new(0, 50, 0, 85)
            speedInput.Size = UDim2.new(0, 40, 0, 15)
            speedInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            speedInput.BorderSizePixel = 0
            speedInput.Text = tostring(path.speed or 1)
            speedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
            speedInput.TextSize = 6
            speedInput.Font = Enum.Font.Gotham
            
            playButton.MouseButton1Click:Connect(function()
                if pathPlaying and currentPathName == pathName and not pathAutoPlaying then
                    stopPathPlayback()
                else
                    playPath(pathName, false, false, false)
                end
                updatePathList()
            end)
            
            autoPlayButton.MouseButton1Click:Connect(function()
                if pathPlaying and currentPathName == pathName and pathAutoPlaying and not pathAutoRespawning then
                    stopPathPlayback()
                else
                    playPath(pathName, false, true, false)
                end
                updatePathList()
            end)
            
            autoRespButton.MouseButton1Click:Connect(function()
                if pathPlaying and currentPathName == pathName and pathAutoPlaying and pathAutoRespawning then
                    stopPathPlayback()
                else
                    playPath(pathName, false, true, true)
                end
                updatePathList()
            end)
            
            showButton.MouseButton1Click:Connect(function()
                playPath(pathName, true, false, false)
            end)
            
            deleteButton.MouseButton1Click:Connect(function()
                if pathPlaying and currentPathName == pathName then
                    stopPathPlayback()
                end
                savedPaths[pathName] = nil
                deletePathFromJSON(pathName)
                updatePathList()
                clearPathVisuals()
            end)
            
            renameButton.MouseButton1Click:Connect(function()
                if renameInput.Text ~= "" then
                    local newName = renameInput.Text
                    if savedPaths[pathName] then
                        savedPaths[newName] = savedPaths[pathName]
                        savedPaths[pathName] = nil
                        
                        if pathPlaying and currentPathName == pathName then
                            currentPathName = newName
                        end
                        
                        renamePathInJSON(pathName, newName)
                        renameInput.Text = ""
                        updatePathList()
                    end
                end
            end)
            
            speedInput.FocusLost:Connect(function(enterPressed)
                if enterPressed then
                    local newSpeed = tonumber(speedInput.Text)
                    if newSpeed and newSpeed > 0 and newSpeed <= 10 then
                        path.speed = newSpeed
                        savePathToJSON(pathName, path)
                    else
                        speedInput.Text = tostring(path.speed or 1)
                    end
                end
            end)
        end
    end
    
    task.wait(0.1)
    if PathLayout then
        PathScrollFrame.CanvasSize = UDim2.new(0, 0, 0, PathLayout.AbsoluteContentSize.Y + 5)
    end
end

-- Keyboard Controls
local function setupKeyboardControls()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.Z and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            undoToLastMarker()
        end
    end)
end

-- Load utility buttons
function Utility.loadUtilityButtons(createButton)
    createButton("Record Macro", startMacroRecording)
    createButton("Stop Macro", stopMacroRecording)
    createButton("Macro Manager", function()
        if not MacroFrame then initMacroUI() end
        MacroFrame.Visible = not MacroFrame.Visible
        macroFrameVisible = MacroFrame.Visible
        if macroFrameVisible then
            Utility.updateMacroList()
        end
    end)
    
    createButton("Record Path", startPathRecording)
    createButton("Stop Path", stopPathRecording)
    createButton("Path Manager", function()
        if not PathFrame then initPathUI() end
        PathFrame.Visible = not PathFrame.Visible
        pathFrameVisible = PathFrame.Visible
        if pathFrameVisible then
            updatePathList()
        end
    end)
    
    createButton("Clear Visuals", clearPathVisuals)
    createButton("Kill Player", killPlayer)
    createButton("Reset Character", resetCharacter)
    createButton("Undo Path", undoToLastMarker)
end

-- Initialize function
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
    autoRespawning = false
    macroPaused = false
    pathRecording = false
    pathPlaying = false
    pathShowOnly = false
    pathPaused = false
    
    local success = pcall(function()
        if not isfolder("Supertool") then
            makefolder("Supertool")
        end
        if not isfolder(MACRO_FOLDER_PATH) then
            makefolder(MACRO_FOLDER_PATH)
        end
        if not isfolder(PATH_FOLDER_PATH) then
            makefolder(PATH_FOLDER_PATH)
        end
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to create folder structure")
    end
    
    setupKeyboardControls()
    
    if player then
        player.CharacterAdded:Connect(function(newCharacter)
            task.spawn(function()
                humanoid = newCharacter:WaitForChild("Humanoid", 30)
                rootPart = newCharacter:WaitForChild("HumanoidRootPart", 30)
                if humanoid and rootPart then
                    if macroRecording and recordingPaused then
                        task.wait(pauseResumeTime)
                        recordingPaused = false
                        updateMacroStatus()
                    end
                    if pathRecording and pathPaused then
                        task.wait(pauseResumeTime)
                        pathPaused = false
                        updatePathStatus()
                    end
                    if macroPlaying and currentMacroName then
                        task.wait(pauseResumeTime)
                        macroPaused = false
                        playMacro(currentMacroName, autoPlaying, autoRespawning)
                    end
                    if pathPlaying and currentPathName then
                        task.wait(pauseResumeTime)
                        pathPaused = false
                        playPath(currentPathName, pathShowOnly, pathAutoPlaying, pathAutoRespawning)
                    end
                end
            end)
        end)
        
        player.CharacterRemoving:Connect(function()
            if macroRecording then
                recordingPaused = true
                updateMacroStatus()
            end
            if pathRecording then
                pathPaused = true
                updatePathStatus()
            end
            if macroPlaying then
                macroPaused = true
                updateMacroStatus()
            end
            if pathPlaying then
                pathPaused = true
                updatePathStatus()
            end
        end)
        
        if humanoid then
            humanoid.Died:Connect(function()
                if macroRecording then
                    recordingPaused = true
                    updateMacroStatus()
                end
                if pathRecording then
                    pathPaused = true
                    updatePathStatus()
                end
                if macroPlaying then
                    macroPaused = true
                    updateMacroStatus()
                end
                if pathPlaying then
                    pathPaused = true
                    updatePathStatus()
                end
            end)
        end
    end
    
    task.spawn(function()
        initMacroUI()
        initPathUI()
        print("[SUPERTOOL] Enhanced Utility Module v2.3 initialized")
        print("  - Path Recording: Visual navigation with undo markers and idle duration")
        print("  - Enhanced Macros: Full macro system with pause/resume")
        print("  - Keyboard Controls: Ctrl+Z (undo)")
        print("  - JSON Storage: Supertool/Macro and Supertool/Paths")
    end)
end

return Utility