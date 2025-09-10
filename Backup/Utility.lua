-- Enhanced Path-only Utility for MinimalHackGUI by Fari Noveri
-- Updated version with fixed Ctrl+Z, JSON loading, status display, and enhanced path features
-- REMOVED: All macro functionality
-- ADDED: Top-right status display, pause/resume with markers, clickable path points
-- farinoveri30@gmail.com (claude ai)
-- Fixed bugs: UI textbox, outfit apply, reset character
-- MODIFIED: Removed Outfit Manager, Added Object Deleter Feature

-- Dependencies: These must be passed from mainloader.lua
local Players, humanoid, rootPart, ScrollFrame, buttonStates, RunService, player, ScreenGui, settings

-- Initialize module
local Utility = {}

-- Path Recording System Variables
local pathRecording = false
local pathPlaying = false
local pathShowOnly = false
local pathPaused = false
local pathAutoPlaying = false
local pathAutoRespawning = false
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
local pausedHereLabel = nil
local playbackStartTime = 0
local playbackPauseTime = 0
local playbackOffsetTime = 0
local pathVisualsVisible = true
local lastPauseToggleTime = 0
local lastVisibilityToggleTime = 0
local DEBOUNCE_TIME = 0.5 -- seconds

-- Object Deleter Variables
local deleterEnabled = false
local selectedObject = nil
local selectionBox = nil
local confirmationGui = nil
local successGui = nil
local deletedObjects = {}  -- Stack for undo: {object = clone, parent = originalParent, name = name}
local deletedListFrame = nil
local deletedListVisible = false
local DeletedScrollFrame, DeletedLayout

-- File System Integration
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local PATH_FOLDER_PATH = "Supertool/Paths/"

-- Path movement detection constants
local WALK_THRESHOLD = 5 -- studs per second
local JUMP_THRESHOLD = 20 -- studs per second Y velocity
local FALL_THRESHOLD = -10 -- studs per second Y velocity
local SWIM_THRESHOLD = 2 -- when in water
local MARKER_DISTANCE = 5 -- meters between path markers
local CLICKABLE_RADIUS = 5 -- meters radius for clickable path points

-- Movement colors
local movementColors = {
    swimming = Color3.fromRGB(128, 0, 128),
    jumping = Color3.fromRGB(255, 0, 0),
    falling = Color3.fromRGB(255, 255, 0),
    walking = Color3.fromRGB(0, 255, 0),
    idle = Color3.fromRGB(200, 200, 200),
    paused = Color3.fromRGB(255, 255, 255)
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
    killPlayer()  -- Changed to kill for client-side respawn
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
local function createPathVisual(position, movementType, isMarker, idleDuration, isClickable)
    local color = getColorFromType(movementType)
    local part = Instance.new("Part")
    part.Name = isMarker and "PathMarker" or (isClickable and "ClickablePathPoint" or "PathPoint")
    part.Parent = workspace
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.SmoothPlastic
    part.Color = color
    part.Transparency = isMarker and 0.3 or (isClickable and 0.5 or 0.7)
    part.Size = isMarker and Vector3.new(1, 1, 1) or (isClickable and Vector3.new(0.8, 0.8, 0.8) or Vector3.new(0.5, 0.5, 0.5))
    part.Shape = isMarker and Enum.PartType.Ball or Enum.PartType.Block
    part.CFrame = CFrame.new(position)
    
    if isClickable then
        -- Add click detection
        local detector = Instance.new("ClickDetector")
        detector.Parent = part
        detector.MaxActivationDistance = 50
        
        detector.MouseClick:Connect(function(player)
            -- Find the closest point in the path
            local closestIndex = 1
            local closestDistance = math.huge
            
            for i, point in pairs(currentPath.points or savedPaths[currentPathName].points or {}) do
                local distance = (position - point.position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closestIndex = i
                end
            end
            
            -- Create "Start From Here" label
            local billboard = Instance.new("BillboardGui")
            billboard.Parent = part
            billboard.Size = UDim2.new(0, 120, 0, 40)
            billboard.StudsOffset = Vector3.new(0, 3, 0)
            billboard.AlwaysOnTop = false
            
            local textLabel = Instance.new("TextLabel")
            textLabel.Parent = billboard
            textLabel.Size = UDim2.new(1, 0, 1, 0)
            textLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            textLabel.BackgroundTransparency = 0.3
            textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            textLabel.TextStrokeTransparency = 0.5
            textLabel.TextSize = 14
            textLabel.Font = Enum.Font.GothamBold
            textLabel.Text = "START FROM HERE"
            
            -- Auto-remove after 3 seconds
            game:GetService("Debris"):AddItem(billboard, 3)
            
            -- Set playback start index
            pathPauseIndex = closestIndex
            print("[SUPERTOOL] Path playback will start from index " .. closestIndex)
            
            if pathPlaying then
                stopPathPlayback()
                playPath(currentPathName, false, pathAutoPlaying, pathAutoRespawning)
            end
        end)
    end
    
    if isMarker then        
        if movementType == "idle" and idleDuration then
            local billboard = Instance.new("BillboardGui")
            billboard.Parent = part
            billboard.Size = UDim2.new(0, 100, 0, 30)
            billboard.StudsOffset = Vector3.new(0, 2, 0)
            billboard.AlwaysOnTop = false
            
            local textLabel = Instance.new("TextLabel")
            textLabel.Parent = billboard
            textLabel.Size = UDim2.new(1, 0, 1, 0)
            textLabel.BackgroundTransparency = 1
            textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            textLabel.TextStrokeTransparency = 0.5
            textLabel.TextSize = 12
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
    
    -- Clear paused here label
    if pausedHereLabel and pausedHereLabel.Parent then
        pausedHereLabel:Destroy()
        pausedHereLabel = nil
    end
end

local function createPausedHereMarker(position)
    if pausedHereLabel and pausedHereLabel.Parent then
        pausedHereLabel:Destroy()
    end
    
    pausedHereLabel = Instance.new("Part")
    pausedHereLabel.Name = "PausedHereMarker"
    pausedHereLabel.Parent = workspace
    pausedHereLabel.Anchored = true
    pausedHereLabel.CanCollide = false
    pausedHereLabel.Material = Enum.Material.SmoothPlastic
    pausedHereLabel.Color = movementColors.paused
    pausedHereLabel.Transparency = 0.2
    pausedHereLabel.Size = Vector3.new(1.5, 1.5, 1.5)
    pausedHereLabel.Shape = Enum.PartType.Ball
    pausedHereLabel.CFrame = CFrame.new(position)
    
    local billboard = Instance.new("BillboardGui")
    billboard.Parent = pausedHereLabel
    billboard.Size = UDim2.new(0, 120, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = false
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Parent = billboard
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.BackgroundTransparency = 0.3
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.TextStrokeTransparency = 0.5
    textLabel.TextSize = 12
    textLabel.Font = Enum.Font.GothamBold
    textLabel.Text = "PAUSED HERE"
end

local function togglePathVisibility()
    pathVisualsVisible = not pathVisualsVisible
    
    local transparency = pathVisualsVisible and 0 or 1
    
    for _, part in pairs(pathVisualParts) do
        if part and part.Parent then
            part.Transparency = transparency
            local billboard = part:FindFirstChildOfClass("BillboardGui")
            if billboard then
                billboard.Enabled = pathVisualsVisible
            end
        end
    end
    
    for _, part in pairs(pathMarkerParts) do
        if part and part.Parent then
            part.Transparency = transparency
            local billboard = part:FindFirstChildOfClass("BillboardGui")
            if billboard then
                billboard.Enabled = pathVisualsVisible
            end
        end
    end
    
    if pausedHereLabel and pausedHereLabel.Parent then
        pausedHereLabel.Transparency = transparency
        local billboard = pausedHereLabel:FindFirstChildOfClass("BillboardGui")
        if billboard then
            billboard.Enabled = pathVisualsVisible
        end
    end
    
    print("[SUPERTOOL] Path visuals " .. (pathVisualsVisible and "shown" or "hidden"))
end

-- Path Recording Functions
local function startPathRecording()
    if pathRecording or pathPlaying then 
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
    updatePathStatus()
    
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
                local label = currentIdleLabel:FindFirstChildOfClass("BillboardGui")
                if label then
                    local textLabel = label:FindFirstChild("IdleLabel")
                    if textLabel then
                        textLabel.Text = duration >= 60 and 
                            string.format("%.1fm", duration/60) or 
                            string.format("%.1fs", duration)
                    end
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
        updatePathStatus()
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
    updatePathStatus()
    
    print("[SUPERTOOL] Path recorded: " .. pathName .. " (" .. #currentPath.points .. " points, " .. #currentPath.markers .. " markers)")
end

-- Path Playback Functions
local function playPath(pathName, showOnly, autoPlay, respawn)
    if pathRecording or pathPlaying then 
        stopPathPlayback()
    end
    
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
    playbackStartTime = tick()
    playbackPauseTime = 0
    playbackOffsetTime = path.points[pathPauseIndex].time or 0
    
    clearPathVisuals()
    
    -- Create path visuals with clickable points every 5 meters
    local lastClickablePosition = nil
    for i, point in pairs(path.points) do
        local visualPart = createPathVisual(point.position, point.movementType, false)
        table.insert(pathVisualParts, visualPart)
        
        -- Add clickable points every 5 meters
        if not lastClickablePosition or (point.position - lastClickablePosition).Magnitude >= CLICKABLE_RADIUS then
            local clickablePart = createPathVisual(point.position, point.movementType, false, nil, true)
            table.insert(pathMarkerParts, clickablePart)
            lastClickablePosition = point.position
        end
    end
    
    for i, marker in pairs(path.markers or {}) do
        local markerPart = createPathVisual(marker.position, marker.movementType or "marker", true, marker.idleDuration)
        table.insert(pathMarkerParts, markerPart)
    end
    
    updatePathStatus()
    
    if pathShowOnly then
        print("[SUPERTOOL] Showing path: " .. pathName)
        return
    end
    
    print("[SUPERTOOL] Playing path: " .. pathName)
    
    local index = pathPauseIndex
    
    pathPlayConnection = RunService.Heartbeat:Connect(function()
        if not pathPlaying or pathPaused then return end
        
        if not updateCharacterReferences() then return end
        
        if index > #path.points then
            if pathAutoPlaying then
                if pathAutoRespawning then
                    resetCharacter()
                else
                    index = 1
                    playbackOffsetTime = path.points[1].time or 0
                    playbackStartTime = tick()
                    playbackPauseTime = 0
                end
            else
                stopPathPlayback()
                return
            end
        end
        
        local point = path.points[index]
        if point then
            local adjustedTime = point.time - playbackOffsetTime - playbackPauseTime
            if tick() - playbackStartTime >= adjustedTime then
                pcall(function()
                    rootPart.CFrame = point.cframe
                    rootPart.Velocity = point.movementType == "idle" and Vector3.new(0, 0, 0) or point.velocity
                    humanoid.WalkSpeed = point.walkSpeed
                    humanoid.JumpPower = point.jumpPower
                end)
                index = index + 1
            end
        end
    end)
end

local function togglePathVisuals(pathName)
    if pathShowOnly and currentPathName == pathName then
        clearPathVisuals()
        pathShowOnly = false
        currentPathName = nil
        updatePathStatus()
    else
        playPath(pathName, true, false, false)
    end
    updatePathList()
end

local function stopPathPlayback()
    if not pathPlaying then return end
    pathPlaying = false
    pathAutoPlaying = false
    pathAutoRespawning = false
    pathPaused = false
    pathShowOnly = false
    pathPauseIndex = 1
    playbackOffsetTime = 0
    if pathPlayConnection then
        pathPlayConnection:Disconnect()
        pathPlayConnection = nil
    end
    if humanoid then
        humanoid.WalkSpeed = settings.WalkSpeed.value or 16
    end
    currentPathName = nil
    
    -- Clear paused here marker
    if pausedHereLabel and pausedHereLabel.Parent then
        pausedHereLabel:Destroy()
        pausedHereLabel = nil
    end
    
    updatePathList()
    updatePathStatus()
end

local function pausePath()
    if not pathPlaying or pathShowOnly then return end
    
    pathPaused = not pathPaused
    
    if pathPaused then
        -- Create paused marker at current position
        if updateCharacterReferences() then
            createPausedHereMarker(rootPart.Position)
            playbackPauseTime = playbackPauseTime + (tick() - playbackStartTime)
        end
    else
        -- Remove paused marker and resume
        if pausedHereLabel and pausedHereLabel.Parent then
            pausedHereLabel:Destroy()
            pausedHereLabel = nil
        end
        playbackStartTime = tick()
    end
    
    updatePathStatus()
end

-- FIXED: Path Undo System
local function undoToLastMarker()
    if not pathRecording or not currentPath or not currentPath.markers or #currentPath.markers == 0 then
        warn("[SUPERTOOL] Undo only available during path recording with existing markers")
        return
    end
    
    local lastMarkerIndex = #currentPath.markers
    local lastMarker = currentPath.markers[lastMarkerIndex]
    
    if lastMarker and updateCharacterReferences() then
        -- Teleport to last marker
        rootPart.CFrame = lastMarker.cframe
        print("[SUPERTOOL] Undid to last marker at " .. tostring(lastMarker.position))
        
        -- Remove points and markers after the last marker
        currentPath.points = {table.unpack(currentPath.points, 1, lastMarker.pathIndex)}
        currentPath.markers = {table.unpack(currentPath.markers, 1, lastMarkerIndex - 1)}
        
        -- Update visuals - clear and recreate
        clearPathVisuals()
        for i, point in pairs(currentPath.points) do
            local visualPart = createPathVisual(point.position, point.movementType, false)
            table.insert(pathVisualParts, visualPart)
        end
        
        for i, marker in pairs(currentPath.markers) do
            local markerPart = createPathVisual(marker.position, marker.movementType or "marker", true, marker.idleDuration)
            table.insert(pathMarkerParts, markerPart)
        end
        
        -- Create white sphere at undo position
        local undoMarker = createPathVisual(lastMarker.position, "paused", true)
        table.insert(pathMarkerParts, undoMarker)
    end
end

-- FIXED: Load all existing files function
local function loadAllSavedPaths()
    local success, result = pcall(function()
        if not isfolder(PATH_FOLDER_PATH) then return 0 end
        
        local files = listfiles(PATH_FOLDER_PATH)
        local loadedCount = 0
        
        for _, filePath in pairs(files) do
            local fileName = filePath:match("([^/\\]+)%.json$")
            if fileName then
                local pathData = loadPathFromJSON(fileName)
                if pathData then
                    savedPaths[pathData.name] = pathData
                    loadedCount = loadedCount + 1
                end
            end
        end
        
        return loadedCount
    end)
    
    if success then
        print("[SUPERTOOL] Loaded " .. result .. " paths from disk")
        return result
    else
        warn("[SUPERTOOL] Failed to load paths: " .. tostring(result))
        return 0
    end
end

-- Status Update Functions - FIXED
function updatePathStatus()
    if not PathStatusLabel then return end
    
    local statusText = ""
    if pathRecording then
        statusText = pathPaused and "🔴 Recording Paused" or "🔴 Recording Path..."
    elseif pathPlaying and currentPathName then
        local statusPrefix = pathShowOnly and "👁️ Showing: " or "🛤️ Playing: "
        local modeText = pathAutoRespawning and "Auto-Respawn" or (pathAutoPlaying and "Auto-Loop" or "Single Play")
        statusText = (pathPaused and "⏸️ Paused: " or statusPrefix) .. currentPathName .. 
                    (pathShowOnly and "" or " (" .. modeText .. ")")
    end
    
    PathStatusLabel.Text = statusText
    PathStatusLabel.Visible = statusText ~= ""
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

-- UI Components
local function initPathUI()
    if PathFrame then return end
    
    PathFrame = Instance.new("Frame")
    PathFrame.Name = "PathFrame"
    PathFrame.Parent = ScreenGui
    PathFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    PathFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    PathFrame.BorderSizePixel = 1
    PathFrame.Position = UDim2.new(0.5, 0, 0.2, 0)
    PathFrame.Size = UDim2.new(0, 320, 0, 450)
    PathFrame.Visible = false
    PathFrame.Active = true
    PathFrame.Draggable = true

    local PathTitle = Instance.new("TextLabel")
    PathTitle.Parent = PathFrame
    PathTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    PathTitle.BorderSizePixel = 0
    PathTitle.Size = UDim2.new(1, 0, 0, 25)
    PathTitle.Font = Enum.Font.GothamBold
    PathTitle.Text = "PATH CREATOR v2.0 - Enhanced"
    PathTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    PathTitle.TextSize = 10

    local ClosePathButton = Instance.new("TextButton")
    ClosePathButton.Parent = PathFrame
    ClosePathButton.BackgroundTransparency = 1
    ClosePathButton.Position = UDim2.new(1, -25, 0, 2)
    ClosePathButton.Size = UDim2.new(0, 20, 0, 20)
    ClosePathButton.Font = Enum.Font.GothamBold
    ClosePathButton.Text = "X"
    ClosePathButton.TextColor3 = Color3.fromRGB(255, 100, 100)
    ClosePathButton.TextSize = 12

    PathInput = Instance.new("TextBox")
    PathInput.Parent = PathFrame
    PathInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    PathInput.BorderSizePixel = 0
    PathInput.Position = UDim2.new(0, 5, 0, 30)
    PathInput.Size = UDim2.new(1, -10, 0, 25)
    PathInput.Font = Enum.Font.Gotham
    PathInput.PlaceholderText = "Search paths or enter new path name..."
    PathInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    PathInput.TextSize = 8

    PathScrollFrame = Instance.new("ScrollingFrame")
    PathScrollFrame.Parent = PathFrame
    PathScrollFrame.BackgroundTransparency = 1
    PathScrollFrame.Position = UDim2.new(0, 5, 0, 60)
    PathScrollFrame.Size = UDim2.new(1, -10, 1, -100)
    PathScrollFrame.ScrollBarThickness = 3
    PathScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
    PathScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    PathLayout = Instance.new("UIListLayout")
    PathLayout.Parent = PathScrollFrame
    PathLayout.Padding = UDim.new(0, 3)

    local PathControlsFrame = Instance.new("Frame")
    PathControlsFrame.Parent = PathFrame
    PathControlsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    PathControlsFrame.BorderSizePixel = 0
    PathControlsFrame.Position = UDim2.new(0, 5, 1, -35)
    PathControlsFrame.Size = UDim2.new(1, -10, 0, 30)

    local PathPauseButton = Instance.new("TextButton")
    PathPauseButton.Parent = PathControlsFrame
    PathPauseButton.BackgroundColor3 = Color3.fromRGB(80, 80, 60)
    PathPauseButton.BorderSizePixel = 0
    PathPauseButton.Position = UDim2.new(0, 5, 0, 2.5)
    PathPauseButton.Size = UDim2.new(0, 80, 0, 25)
    PathPauseButton.Font = Enum.Font.GothamBold
    PathPauseButton.Text = "PAUSE/RESUME"
    PathPauseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    PathPauseButton.TextSize = 8

    local ClearVisualsButton = Instance.new("TextButton")
    ClearVisualsButton.Parent = PathControlsFrame
    ClearVisualsButton.BackgroundColor3 = Color3.fromRGB(80, 60, 60)
    ClearVisualsButton.BorderSizePixel = 0
    ClearVisualsButton.Position = UDim2.new(0, 90, 0, 2.5)
    ClearVisualsButton.Size = UDim2.new(0, 80, 0, 25)
    ClearVisualsButton.Font = Enum.Font.GothamBold
    ClearVisualsButton.Text = "CLEAR"
    ClearVisualsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClearVisualsButton.TextSize = 8

    local UndoButton = Instance.new("TextButton")
    UndoButton.Parent = PathControlsFrame
    UndoButton.BackgroundColor3 = Color3.fromRGB(60, 80, 80)
    UndoButton.BorderSizePixel = 0
    UndoButton.Position = UDim2.new(0, 175, 0, 2.5)
    UndoButton.Size = UDim2.new(0, 80, 0, 25)
    UndoButton.Font = Enum.Font.GothamBold
    UndoButton.Text = "UNDO (Ctrl+Z)"
    UndoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    UndoButton.TextSize = 7

    -- Status Label positioned at top right
    PathStatusLabel = Instance.new("TextLabel")
    PathStatusLabel.Parent = ScreenGui
    PathStatusLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    PathStatusLabel.BorderColor3 = Color3.fromRGB(45, 45, 45)
    PathStatusLabel.BorderSizePixel = 1
    PathStatusLabel.Position = UDim2.new(1, -300, 0, 5)
    PathStatusLabel.Size = UDim2.new(0, 290, 0, 30)
    PathStatusLabel.Font = Enum.Font.GothamBold
    PathStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    PathStatusLabel.TextSize = 9
    PathStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    PathStatusLabel.Visible = false
    PathStatusLabel.ZIndex = 100

    -- Event connections
    ClosePathButton.MouseButton1Click:Connect(function()
        PathFrame.Visible = false
        pathFrameVisible = false
    end)

    PathPauseButton.MouseButton1Click:Connect(pausePath)
    ClearVisualsButton.MouseButton1Click:Connect(clearPathVisuals)
    UndoButton.MouseButton1Click:Connect(undoToLastMarker)
    
    -- Search functionality
    PathInput.Changed:Connect(function(property)
        if property == "Text" then
            updatePathList()
        end
    end)
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
            pathItem.BorderColor3 = Color3.fromRGB(40, 40, 40)
            pathItem.BorderSizePixel = 1
            pathItem.Size = UDim2.new(1, -5, 0, 120)
            
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Parent = pathItem
            nameLabel.Position = UDim2.new(0, 5, 0, 3)
            nameLabel.Size = UDim2.new(1, -10, 0, 18)
            nameLabel.Text = pathName
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
            nameLabel.BackgroundTransparency = 1
            nameLabel.TextSize = 9
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            local infoLabel = Instance.new("TextLabel")
            infoLabel.Parent = pathItem
            infoLabel.Position = UDim2.new(0, 5, 0, 20)
            infoLabel.Size = UDim2.new(1, -10, 0, 12)
            infoLabel.BackgroundTransparency = 1
            infoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
            infoLabel.TextSize = 7
            infoLabel.Font = Enum.Font.Gotham
            infoLabel.Text = string.format("Points: %d | Markers: %d | Duration: %.1fs", 
                                         path.pointCount or 0, 
                                         path.markerCount or 0, 
                                         path.duration or 0)
            infoLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            -- Button row 1
            local playButton = Instance.new("TextButton")
            playButton.Parent = pathItem
            playButton.Position = UDim2.new(0, 5, 0, 38)
            playButton.Size = UDim2.new(0, 45, 0, 20)
            playButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
            playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            playButton.TextSize = 7
            playButton.Font = Enum.Font.GothamBold
            playButton.Text = (pathPlaying and currentPathName == pathName and not pathAutoPlaying) and "STOP" or "PLAY"
            
            local autoPlayButton = Instance.new("TextButton")
            autoPlayButton.Parent = pathItem
            autoPlayButton.Position = UDim2.new(0, 55, 0, 38)
            autoPlayButton.Size = UDim2.new(0, 45, 0, 20)
            autoPlayButton.BackgroundColor3 = Color3.fromRGB(60, 100, 120)
            autoPlayButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            autoPlayButton.TextSize = 7
            autoPlayButton.Font = Enum.Font.GothamBold
            autoPlayButton.Text = (pathPlaying and currentPathName == pathName and pathAutoPlaying and not pathAutoRespawning) and "STOP" or "LOOP"
            
            local autoRespButton = Instance.new("TextButton")
            autoRespButton.Parent = pathItem
            autoRespButton.Position = UDim2.new(0, 105, 0, 38)
            autoRespButton.Size = UDim2.new(0, 45, 0, 20)
            autoRespButton.BackgroundColor3 = Color3.fromRGB(120, 60, 100)
            autoRespButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            autoRespButton.TextSize = 7
            autoRespButton.Font = Enum.Font.GothamBold
            autoRespButton.Text = (pathPlaying and currentPathName == pathName and pathAutoPlaying and pathAutoRespawning) and "STOP" or "A-RESP"
            
            local toggleShowButton = Instance.new("TextButton")
            toggleShowButton.Parent = pathItem
            toggleShowButton.Position = UDim2.new(0, 155, 0, 38)
            toggleShowButton.Size = UDim2.new(0, 45, 0, 20)
            toggleShowButton.BackgroundColor3 = Color3.fromRGB(100, 100, 60)
            toggleShowButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            toggleShowButton.TextSize = 7
            toggleShowButton.Font = Enum.Font.GothamBold
            toggleShowButton.Text = (pathShowOnly and currentPathName == pathName) and "HIDE" or "SHOW"
            
            local deleteButton = Instance.new("TextButton")
            deleteButton.Parent = pathItem
            deleteButton.Position = UDim2.new(0, 205, 0, 38)
            deleteButton.Size = UDim2.new(0, 45, 0, 20)
            deleteButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
            deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            deleteButton.TextSize = 7
            deleteButton.Font = Enum.Font.GothamBold
            deleteButton.Text = "DELETE"
            
            -- Rename section
            local renameInput = Instance.new("TextBox")
            renameInput.Parent = pathItem
            renameInput.Position = UDim2.new(0, 5, 0, 65)
            renameInput.Size = UDim2.new(0, 150, 0, 18)
            renameInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            renameInput.BorderSizePixel = 0
            renameInput.PlaceholderText = "Enter new name..."
            renameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
            renameInput.TextSize = 7
            renameInput.Font = Enum.Font.Gotham
            
            local renameButton = Instance.new("TextButton")
            renameButton.Parent = pathItem
            renameButton.Position = UDim2.new(0, 160, 0, 65)
            renameButton.Size = UDim2.new(0, 50, 0, 18)
            renameButton.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
            renameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            renameButton.TextSize = 7
            renameButton.Font = Enum.Font.GothamBold
            renameButton.Text = "RENAME"
            
            -- Speed control
            local speedLabel = Instance.new("TextLabel")
            speedLabel.Parent = pathItem
            speedLabel.Position = UDim2.new(0, 5, 0, 90)
            speedLabel.Size = UDim2.new(0, 50, 0, 18)
            speedLabel.BackgroundTransparency = 1
            speedLabel.Text = "Speed:"
            speedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            speedLabel.TextSize = 7
            speedLabel.Font = Enum.Font.Gotham
            speedLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            local speedInput = Instance.new("TextBox")
            speedInput.Parent = pathItem
            speedInput.Position = UDim2.new(0, 55, 0, 90)
            speedInput.Size = UDim2.new(0, 50, 0, 18)
            speedInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            speedInput.BorderSizePixel = 0
            speedInput.Text = tostring(path.speed or 1)
            speedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
            speedInput.TextSize = 7
            speedInput.Font = Enum.Font.Gotham
            
            -- Event connections
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
            
            toggleShowButton.MouseButton1Click:Connect(function()
                togglePathVisuals(pathName)
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
        PathScrollFrame.CanvasSize = UDim2.new(0, 0, 0, PathLayout.AbsoluteContentSize.Y + 10)
    end
end

-- FIXED: Keyboard Controls
local function setupKeyboardControls()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        local currentTime = tick()
        
        -- FIXED: Ctrl+Z for undo during path recording or object delete
        if input.KeyCode == Enum.KeyCode.Z and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            if pathRecording then
                undoToLastMarker()
            elseif #deletedObjects > 0 then
                undoDeleteObject()
            end
        end
        
        -- Ctrl+P for pause/resume
        if input.KeyCode == Enum.KeyCode.P and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            if currentTime - lastPauseToggleTime >= DEBOUNCE_TIME then
                lastPauseToggleTime = currentTime
                pausePath()
            end
        end
        
        -- Ctrl+L for hide/show path visuals
        if input.KeyCode == Enum.KeyCode.L and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            if currentTime - lastVisibilityToggleTime >= DEBOUNCE_TIME then
                lastVisibilityToggleTime = currentTime
                togglePathVisibility()
            end
        end
    end)
end

-- Object Deleter Functions
local function clearSelection()
    if selectionBox and selectionBox.Parent then
        selectionBox:Destroy()
        selectionBox = nil
    end
    selectedObject = nil
    if confirmationGui and confirmationGui.Parent then
        confirmationGui:Destroy()
        confirmationGui = nil
    end
end

local function showSuccess(name)
    if not name then name = "Unknown" end
    if not ScreenGui then 
        print("[SUPERTOOL] Success: Deleted " .. name)
        return 
    end
    
    -- Clean up existing success GUI first
    if successGui and successGui.Parent then
        pcall(function()
            successGui:Destroy()
        end)
        successGui = nil
    end
    
    local success = pcall(function()
        successGui = Instance.new("Frame")
        successGui.Parent = ScreenGui
        successGui.Position = UDim2.new(0.5, -100, 0.1, 0)
        successGui.Size = UDim2.new(0, 200, 0, 50)
        successGui.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        successGui.BackgroundTransparency = 0.5
        successGui.ZIndex = 10
        
        local text = Instance.new("TextLabel")
        text.Parent = successGui
        text.Size = UDim2.new(1, 0, 1, 0)
        text.BackgroundTransparency = 1
        text.Text = "Sukses menghapus " .. name
        text.TextColor3 = Color3.fromRGB(255, 255, 255)
        text.TextSize = 14
        text.ZIndex = 11
        
        -- Use spawn to avoid blocking
        task.spawn(function()
            task.wait(3)
            if successGui and successGui.Parent then
                successGui:Destroy()
                successGui = nil
            end
        end)
    end)
    
    if not success then
        print("[SUPERTOOL] Success: Deleted " .. name)
    end
end


-- Fixed deleteSelectedObject function
-- Fixed deleteSelectedObject function with better error handling
local function deleteSelectedObject()
    if not selectedObject then 
        warn("[SUPERTOOL] No object selected for deletion")
        return 
    end
    
    local name = selectedObject.Name or "Unknown"
    local parent = selectedObject.Parent
    
    -- Create clone before deletion
    local clone = nil
    local success1 = pcall(function()
        clone = selectedObject:Clone()
    end)
    
    if not success1 or not clone then
        warn("[SUPERTOOL] Failed to clone object before deletion")
        clearSelection()
        return
    end
    
    -- Add to deleted objects stack
    table.insert(deletedObjects, {object = clone, parent = parent, name = name})
    
    -- Delete the object
    local success2 = pcall(function()
        selectedObject:Destroy()
    end)
    
    if not success2 then
        warn("[SUPERTOOL] Failed to destroy object")
        -- Remove from stack if destruction failed
        table.remove(deletedObjects)
        clearSelection()
        return
    end
    
    -- Clear selection
    clearSelection()
    
    -- Show success message (with safety check)
    if showSuccess then
        pcall(function()
            showSuccess(name)
        end)
    end
    
    -- Update deleted list (with safety check)
    if updateDeletedList then
        pcall(function()
            updateDeletedList()
        end)
    end
    
    print("[SUPERTOOL] Successfully deleted object: " .. name)
end


local function showConfirmation(obj)
    clearSelection()
    selectedObject = obj
    
    selectionBox = Instance.new("SelectionBox")
    selectionBox.Parent = obj
    selectionBox.Adornee = obj
    selectionBox.LineThickness = 0.1
    selectionBox.Color3 = Color3.fromRGB(255, 0, 0)
    
    confirmationGui = Instance.new("Frame")
    confirmationGui.Parent = ScreenGui
    confirmationGui.Position = UDim2.new(0.5, -100, 0.5, -50)
    confirmationGui.Size = UDim2.new(0, 200, 0, 100)
    confirmationGui.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    confirmationGui.BackgroundTransparency = 0.5
    confirmationGui.ZIndex = 10
    
    local text = Instance.new("TextLabel")
    text.Parent = confirmationGui
    text.Position = UDim2.new(0, 0, 0, 0)
    text.Size = UDim2.new(1, 0, 0.5, 0)
    text.BackgroundTransparency = 1
    text.Text = "Apakah anda ingin hapus ini?"
    text.TextColor3 = Color3.fromRGB(255, 255, 255)
    text.TextSize = 14
    text.TextWrapped = true
    text.ZIndex = 11
    
    local yesButton = Instance.new("TextButton")
    yesButton.Parent = confirmationGui
    yesButton.Position = UDim2.new(0, 10, 0.6, 0)
    yesButton.Size = UDim2.new(0.4, 0, 0.3, 0)
    yesButton.Text = "Ya"
    yesButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    yesButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    yesButton.ZIndex = 11
    
    local noButton = Instance.new("TextButton")
    noButton.Parent = confirmationGui
    noButton.Position = UDim2.new(0.55, 0, 0.6, 0)
    noButton.Size = UDim2.new(0.4, 0, 0.3, 0)
    noButton.Text = "Tidak"
    noButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    noButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    noButton.ZIndex = 11
    
    local yesConnection, noConnection
    yesConnection = yesButton.MouseButton1Click:Connect(function()
        if selectedObject then
            deleteSelectedObject()
        end
        if yesConnection then yesConnection:Disconnect() end
        if noConnection then noConnection:Disconnect() end
    end)
    
    noConnection = noButton.MouseButton1Click:Connect(function()
        clearSelection()
        if yesConnection then yesConnection:Disconnect() end
        if noConnection then noConnection:Disconnect() end
    end)
    
    game:GetService("Debris"):AddItem(confirmationGui, 5)
end

local function setupDeleterInput()
    local connection
    if connection then connection:Disconnect() end -- Prevent duplicate connections
    connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if deleterEnabled and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            local mouse = player:GetMouse()
            local target = mouse.Target
            if target and target:IsA("BasePart") and target ~= workspace.Terrain then
                showConfirmation(target)
            end
        end
    end)
end

local function toggleDeleter()
    deleterEnabled = not deleterEnabled
    if deleterEnabled then
        print("[SUPERTOOL] Object Deleter enabled")
        setupDeleterInput()
    else
        print("[SUPERTOOL] Object Deleter disabled")
        clearSelection()
    end
end

local function undoDeleteObject()
    if #deletedObjects == 0 then return end
    
    local last = table.remove(deletedObjects)
    last.object.Parent = last.parent
    
    print("[SUPERTOOL] Undid deletion of: " .. last.name)
    updateDeletedList()
end

local function initDeletedListUI()
    if deletedListFrame then return end
    
    deletedListFrame = Instance.new("Frame")
    deletedListFrame.Name = "DeletedListFrame"
    deletedListFrame.Parent = ScreenGui
    deletedListFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    deletedListFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    deletedListFrame.BorderSizePixel = 1
    deletedListFrame.Position = UDim2.new(0.5, 0, 0.2, 0)
    deletedListFrame.Size = UDim2.new(0, 200, 0, 300)
    deletedListFrame.Visible = false
    deletedListFrame.Active = true
    deletedListFrame.Draggable = true

    local title = Instance.new("TextLabel")
    title.Parent = deletedListFrame
    title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    title.BorderSizePixel = 0
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Font = Enum.Font.GothamBold
    title.Text = "Deleted Objects"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 10

    local closeButton = Instance.new("TextButton")
    closeButton.Parent = deletedListFrame
    closeButton.BackgroundTransparency = 1
    closeButton.Position = UDim2.new(1, -25, 0, 2)
    closeButton.Size = UDim2.new(0, 20, 0, 20)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeButton.TextSize = 12

    DeletedScrollFrame = Instance.new("ScrollingFrame")
    DeletedScrollFrame.Parent = deletedListFrame
    DeletedScrollFrame.BackgroundTransparency = 1
    DeletedScrollFrame.Position = UDim2.new(0, 5, 0, 30)
    DeletedScrollFrame.Size = UDim2.new(1, -10, 1, -35)
    DeletedScrollFrame.ScrollBarThickness = 3
    DeletedScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
    DeletedScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    DeletedLayout = Instance.new("UIListLayout")
    DeletedLayout.Parent = DeletedScrollFrame
    DeletedLayout.Padding = UDim.new(0, 3)

    closeButton.MouseButton1Click:Connect(function()
        deletedListFrame.Visible = false
        deletedListVisible = false
    end)
end

-- Fix updateDeletedList function
local function updateDeletedList()
    if not DeletedScrollFrame or not DeletedLayout then 
        return 
    end
    
    pcall(function()
        -- Clear existing items
        for _, child in pairs(DeletedScrollFrame:GetChildren()) do
            if child:IsA("TextLabel") then
                child:Destroy()
            end
        end
        
        -- Add items from deleted objects stack
        for i = #deletedObjects, 1, -1 do
            local item = deletedObjects[i]
            if item and item.name then
                local label = Instance.new("TextLabel")
                label.Parent = DeletedScrollFrame
                label.Size = UDim2.new(1, 0, 0, 20)
                label.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                label.Text = item.name
                label.TextColor3 = Color3.fromRGB(255, 255, 255)
                label.TextSize = 10
            end
        end
        
        -- Update canvas size
        task.wait(0.1)
        if DeletedLayout then
            DeletedScrollFrame.CanvasSize = UDim2.new(0, 0, 0, DeletedLayout.AbsoluteContentSize.Y)
        end
    end)
end

local function toggleDeletedList()
    if not deletedListFrame then initDeletedListUI() end
    deletedListVisible = not deletedListVisible
    deletedListFrame.Visible = deletedListVisible
    if deletedListVisible then
        updateDeletedList()
    end
end

-- Load utility buttons
function Utility.loadUtilityButtons(createButton)
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
    createButton("Undo Path (Ctrl+Z)", undoToLastMarker)
    createButton("Toggle Deleter", toggleDeleter)
    createButton("Deleted List", toggleDeletedList)
end

-- Initialize function
function Utility.init(deps)
    if not deps then return end
    if not deps.Players then return end
    if not deps.RunService then return end
    if not deps.player then return end
    if not deps.ScreenGui then return end
    if not deps.settings then return end

    Players = deps.Players
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    ScrollFrame = deps.ScrollFrame
    buttonStates = deps.buttonStates
    player = deps.player
    RunService = deps.RunService
    settings = deps.settings
    ScreenGui = deps.ScreenGui
    
    -- Reset all states
    pathRecording = false
    pathPlaying = false
    pathShowOnly = false
    pathPaused = false
    pathAutoPlaying = false
    pathAutoRespawning = false
    
    -- FIXED: Create folder structure first
    local success = pcall(function()
        if not isfolder("Supertool") then
            makefolder("Supertool")
        end
        if not isfolder(PATH_FOLDER_PATH) then
            makefolder(PATH_FOLDER_PATH)
        end
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to create folder structure")
    end
    
    -- FIXED: Load all existing files on initialization
    local pathCount = loadAllSavedPaths()
    print("[SUPERTOOL] Initialization complete - Paths loaded: " .. pathCount)
    
    setupKeyboardControls()
    setupDeleterInput()
    
    if player then
        player.CharacterAdded:Connect(function(newCharacter)
            task.spawn(function()
                humanoid = newCharacter:WaitForChild("Humanoid", 30)
                rootPart = newCharacter:WaitForChild("HumanoidRootPart", 30)
                if humanoid and rootPart then
                    if pathRecording and pathPaused then
                        task.wait(5)
                        pathPaused = false
                        updatePathStatus()
                    end
                    if pathPlaying and currentPathName then
                        task.wait(5)
                        pathPaused = false
                        playPath(currentPathName, pathShowOnly, pathAutoPlaying, pathAutoRespawning)
                    end
                end
            end)
        end)
        
        player.CharacterRemoving:Connect(function()
            if pathRecording then
                pathPaused = true
                updatePathStatus()
            end
            if pathPlaying then
                pathPaused = true
                updatePathStatus()
            end
        end)
        
        if humanoid then
            humanoid.Died:Connect(function()
                if pathRecording then
                    pathPaused = true
                    updatePathStatus()
                end
                if pathPlaying then
                    pathPaused = true
                    updatePathStatus()
                end
            end)
        end
    end
    
    task.spawn(function()
        initPathUI()
        initDeletedListUI()
        print("[SUPERTOOL] Enhanced Path Utility v2.0 initialized with Object Deleter")
        print("  - REMOVED: All macro functionality and Outfit Manager")
        print("  - FIXED: Ctrl+Z undo function")
        print("  - FIXED: JSON path loading after relog")
        print("  - ADDED: Top-right status display")
        print("  - ADDED: Clickable path points every 5 meters")
        print("  - ADDED: Pause/Resume with 'PAUSED HERE' markers")
        print("  - ADDED: Object Deleter with confirmation, success message, list, and undo")
        print("  - ENHANCED: Better UI with improved controls")
        print("  - Keyboard Controls: Ctrl+Z (undo during recording or delete)")
        print("  - JSON Storage: Supertool/Paths/")
    end)
end

return Utility