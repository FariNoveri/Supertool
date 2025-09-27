--disable-run
-- Enhanced Path-only Utility for MinimalHackGUI by Fari Noveri
-- Updated version with fixed Ctrl+Z, JSON loading, status display, and enhanced path features
-- REMOVED: All macro functionality
-- ADDED: Top-right status display, pause/resume with markers, clickable path points
-- farinoveri30@gmail.com (claude ai)
-- Fixed bugs: UI textbox, outfit apply, reset character
-- MODIFIED: Removed Outfit Manager, Added Object Editor Feature (replaces Deleter with full manipulation)
-- NEW: Added Gear Loader Feature with input ID or predefined gears (exploit-safe)
-- FIXED: Gear loading HTTP 409 error by removing local scripts
-- REMOVED: Drawing Tool Feature (as per request)
-- REMOVED: Adonis Bypass and Kohl's Admin

-- NEW: Added Object Spawner Feature with input ID or predefined objects
-- FIXED: Object Editor nil calls and GUI size issues
-- NEW FIXES: Persistent GUI position, fixed drag reset, added freeze, copy list with delete, HEX color, remove effects
-- FIXED: Drag feature no longer resets on new object selection
-- FIXED: Restored scale feature, holdable move buttons, double right-click for paste confirmation, paste after respawn
-- FIXED: Scroll and close bugs, multi-select with limited options, reduced move sensitivity, simplified rotation, rename in copy list, confirmation toggle

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

-- Object Editor Variables (enhanced from Deleter)
local editorEnabled = false
local selectedObjects = {}  -- List for multi-select
local selectionBoxes = {}
local editorGui = nil
local deletedObjects = {}  -- Stack for undo: {object = clone, parent = originalParent, name = name}
local copiedObjects = {}  -- List for copied objects: {object = clone, originalCFrame = cframe, name = name}
local editedObjects = {}  -- Stack for undo edits: {object = obj, property = prop, oldValue = value}
local redoObjects = {} -- Stack for redo edits
local EditorScrollFrame, EditorLayout
local editorListVisible = false
local EditorListFrame
local lastGuiPosition = UDim2.new(0.5, -150, 0.3, 0)  -- Default position
local lastScrollPosition = 0  -- To preserve scroll position
local copyListFrame = nil
local copyListVisible = false
local isDragging = false
local dragConnection = nil
local rightClickConnection = nil
local lastRightClickTime = 0
local DOUBLE_CLICK_TIME = 0.5  -- seconds for double click
local pasteConfirmationEnabled = false  -- Toggle for confirmation, initial off
local allowMultiMoreThan2 = false  -- Toggle for selecting more than 2 objects, initial off
local dragStartPositions = {}
local dragStartHit = nil
local dragSteppedConn = nil
local confirmFrame = nil
local confirmVisual = nil  -- For showing paste location
local selectedStatusLabel = nil -- For displaying selected object names

-- Gear Loader Variables
local gearFrameVisible = false
local GearFrame, GearInput, GearScrollFrame, GearLayout
local predefinedGears = {
    {name = "Hyperlaser Gun", id = 130113146},
    {name = "Darkheart", id = 1689527},
    {name = "Vampire Vanquisher", id = 108149175},
    -- Tambah gear lain jika perlu
}

-- Object Spawner Variables
local objectFrameVisible = false
local ObjectFrame, ObjectInput, ObjectScrollFrame, ObjectLayout
local predefinedObjects = {
    {name = "Basic Part", id = 123456789},  -- Ganti dengan ID asset nyata
    {name = "Car Model", id = 987654321},   -- Contoh placeholder
    -- Tambah objek lain jika perlu
}

-- Chat Customizer Variables
local nameTag = ""
local tagPosition = "front"  -- front, middle, back
local rainbowChat = false
local customChatColor = nil  -- Color3 or nil
local customChatFont = nil  -- Enum.Font or nil
local chatFrameVisible = false
local ChatFrame, ChatInputTag, ChatPositionToggle, RainbowToggle, ColorInput, FontInput
local sayMessageRequest

-- File System Integration
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local PATH_FOLDER_PATH = "Supertool/Paths/"
local OBJECT_EDITOR_FOLDER = "Supertool/ObjectEditorMap/"
local currentPlaceId = game.PlaceId
local objectEdits = {}  -- To store edits {path = {prop = value}}

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

-- Helper to get full path of object
local function getFullPath(obj)
    local path = obj.Name
    local parent = obj.Parent
    while parent and parent ~= workspace do
        path = parent.Name .. "." .. path
        parent = parent.Parent
    end
    return "workspace." .. path
end

-- Save object edits to JSON
local function saveObjectEdits(update)
    local filePath = OBJECT_EDITOR_FOLDER .. tostring(currentPlaceId) .. ".json"
    if not isfolder(OBJECT_EDITOR_FOLDER) then
        makefolder(OBJECT_EDITOR_FOLDER)
    end
    local data = {}
    if update and isfile(filePath) then
        local jsonString = readfile(filePath)
        data = HttpService:JSONDecode(jsonString)
    end
    for path, props in pairs(objectEdits) do
        data[path] = props
    end
    local jsonString = HttpService:JSONEncode(data)
    writefile(filePath, jsonString)
    print("[SUPERTOOL] Object edits saved to " .. filePath)
end

-- Load object edits from JSON
local function loadObjectEdits()
    local filePath = OBJECT_EDITOR_FOLDER .. tostring(currentPlaceId) .. ".json"
    if isfile(filePath) then
        local jsonString = readfile(filePath)
        local data = HttpService:JSONDecode(jsonString)
        for path, props in pairs(data) do
            local obj = loadstring("return " .. path)()
            if obj then
                for prop, value in pairs(props) do
                    if prop == "Position" then
                        obj.Position = Vector3.new(unpack(value))
                    elseif prop == "Size" then
                        obj.Size = Vector3.new(unpack(value))
                    elseif prop == "Color" then
                        obj.Color = Color3.new(unpack(value))
                    elseif prop == "Orientation" then
                        obj.Orientation = Vector3.new(unpack(value))
                    elseif prop == "CustomPhysicalProperties" then
                        obj.CustomPhysicalProperties = PhysicalProperties.new(value.Density, value.Friction, value.Elasticity, value.FrictionWeight, value.ElasticityWeight)
                    elseif prop == "SurfaceLight" then
                        addSurfaceLight(obj)
                    elseif prop == "Transparency" then
                        obj.Transparency = value
                    else
                        obj[prop] = value
                    end
                end
            end
        end
        objectEdits = data
        print("[SUPERTOOL] Loaded object edits for place " .. currentPlaceId)
        return true
    else
        print("[SUPERTOOL] No object edits file found for place " .. currentPlaceId)
        return false
    end
end

-- Enhanced Object Editor Functions with more features, fixes, details, and user-friendly elements
local function clearSelection()
    for _, box in pairs(selectionBoxes) do
        if box and box.Parent then
            box:Destroy()
        end
    end
    selectionBoxes = {}
    selectedObjects = {}
    isDragging = false -- Reset drag on clear
    if editorGui and editorGui.Parent then
        lastGuiPosition = editorGui.Position  -- Save last position
        lastScrollPosition = editorGui:FindFirstChildOfClass("ScrollingFrame").CanvasPosition.Y  -- Save scroll position
        editorGui:Destroy()
        editorGui = nil
    end
    if selectedStatusLabel then
        selectedStatusLabel.Text = ""
        selectedStatusLabel.Visible = false
    end
end

local function duplicateObject()
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for duplicate")
        return 
    end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local clone = obj:Clone()
            clone.CFrame = obj.CFrame * CFrame.new(5, 0, 0)  -- Improved offset to avoid overlap
            clone.Parent = obj.Parent
            print("[SUPERTOOL] Duplicated: " .. obj.Name)
        end
    end)
    if not success then
        warn("[SUPERTOOL] Duplicate failed: " .. tostring(err))
    end
end

local function copyObject()
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for copy")
        return 
    end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local clone = obj:Clone()
            table.insert(copiedObjects, {object = clone, originalCFrame = obj.CFrame, name = obj.Name})
            print("[SUPERTOOL] Copied: " .. obj.Name .. " to list (#" .. #copiedObjects .. ")")
        end
    end)
    if not success then
        warn("[SUPERTOOL] Copy failed: " .. tostring(err))
    end
end

local function pasteObject(index, position)
    if #copiedObjects == 0 or not index or index < 1 or index > #copiedObjects then 
        warn("[SUPERTOOL] Invalid copy index to paste")
        return 
    end
    local success, err = pcall(function()
        local copied = copiedObjects[index]
        local newPaste = copied.object:Clone()
        newPaste.Name = copied.name  -- Preserve renamed name
        newPaste.CFrame = CFrame.new(position or copied.originalCFrame.Position)
        newPaste.Parent = workspace
        for _, script in pairs(newPaste:GetDescendants()) do
            if script:IsA("Script") or script:IsA("LocalScript") then
                script.Disabled = false
            end
        end
        print("[SUPERTOOL] Pasted from list #" .. index .. ": " .. copied.name)
    end)
    if not success then
        warn("[SUPERTOOL] Paste failed: " .. tostring(err))
    end
end

local function deleteCopy(index)
    if index and index >= 1 and index <= #copiedObjects then
        table.remove(copiedObjects, index)
        print("[SUPERTOOL] Deleted copy #" .. index .. " from list")
    end
end

local function renameCopy(index, newName)
    if index and index >= 1 and index <= #copiedObjects then
        copiedObjects[index].name = newName
        print("[SUPERTOOL] Renamed copy #" .. index .. " to " .. newName)
    end
end

local function resizeObject(scale)
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for resize")
        return 
    end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local oldSize = obj.Size
            table.insert(editedObjects, {object = obj, property = "Size", oldValue = oldSize})
            obj.Size = oldSize * Vector3.new(scale, scale, scale)  -- Uniform scale for simplicity
            print("[SUPERTOOL] Resized " .. obj.Name .. " by " .. scale)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].Size = {obj.Size.X, obj.Size.Y, obj.Size.Z}
        end
    end)
    if not success then
        warn("[SUPERTOOL] Resize failed: " .. tostring(err))
    end
end

local function deleteObject()
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for delete")
        return 
    end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local name = obj.Name
            local parent = obj.Parent
            local clone = obj:Clone()
            table.insert(deletedObjects, {object = clone, parent = parent, name = name})
            obj:Destroy()
            print("[SUPERTOOL] Deleted: " .. name)
        end
        clearSelection()
        updateEditorList()
    end)
    if not success then
        warn("[SUPERTOOL] Delete failed: " .. tostring(err))
    end
end

local function toggleAnchored()
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for anchor toggle")
        return 
    end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local oldValue = obj.Anchored
            table.insert(editedObjects, {object = obj, property = "Anchored", oldValue = oldValue})
            obj.Anchored = not oldValue
            print("[SUPERTOOL] Toggled Anchored to " .. tostring(not oldValue) .. " for " .. obj.Name)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].Anchored = obj.Anchored
        end
    end)
    if not success then
        warn("[SUPERTOOL] Anchor toggle failed: " .. tostring(err))
    end
end

local function toggleCanCollide()
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for collide toggle")
        return 
    end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local oldValue = obj.CanCollide
            table.insert(editedObjects, {object = obj, property = "CanCollide", oldValue = oldValue})
            obj.CanCollide = not oldValue
            print("[SUPERTOOL] Toggled CanCollide to " .. tostring(not oldValue) .. " for " .. obj.Name)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].CanCollide = obj.CanCollide
        end
    end)
    if not success then
        warn("[SUPERTOOL] Collide toggle failed: " .. tostring(err))
    end
end

local function changeColor(hex)
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for color change")
        return 
    end
    local success, err = pcall(function()
        local r, g, b = hex:match("#?(%x%x)(%x%x)(%x%x)")
        r = tonumber(r, 16)
        g = tonumber(g, 16)
        b = tonumber(b, 16)
        for _, obj in pairs(selectedObjects) do
            local oldColor = obj.Color
            table.insert(editedObjects, {object = obj, property = "Color", oldValue = oldColor})
            obj.Color = Color3.fromRGB(r, g, b)
            print("[SUPERTOOL] Changed color to HEX #" .. hex .. " for " .. obj.Name)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].Color = {obj.Color.R, obj.Color.G, obj.Color.B}
        end
    end)
    if not success then
        warn("[SUPERTOOL] Color change failed: " .. tostring(err))
    end
end

local function changeTransparency(trans)
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for transparency change")
        return 
    end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local oldTrans = obj.Transparency
            table.insert(editedObjects, {object = obj, property = "Transparency", oldValue = oldTrans})
            obj.Transparency = math.clamp(trans, 0, 1)
            print("[SUPERTOOL] Changed transparency to " .. trans .. " for " .. obj.Name)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].Transparency = obj.Transparency
        end
    end)
    if not success then
        warn("[SUPERTOOL] Transparency change failed: " .. tostring(err))
    end
end

-- New Feature: Change Position
local function changePosition(x, y, z)
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for position change")
        return 
    end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local oldPosition = obj.Position
            table.insert(editedObjects, {object = obj, property = "Position", oldValue = oldPosition})
            obj.Position = Vector3.new(x, y, z)
            print("[SUPERTOOL] Changed position to (" .. x .. "," .. y .. "," .. z .. ") for " .. obj.Name)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].Position = {x, y, z}
        end
    end)
    if not success then
        warn("[SUPERTOOL] Position change failed: " .. tostring(err))
    end
end

-- New Feature: Change Rotation
local function changeRotation(x, y, z)
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for rotation change")
        return 
    end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local oldCFrame = obj.CFrame
            table.insert(editedObjects, {object = obj, property = "CFrame", oldValue = oldCFrame})
            obj.CFrame = CFrame.new(obj.Position) * CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
            print("[SUPERTOOL] Changed rotation to (" .. x .. "," .. y .. "," .. z .. ") degrees for " .. obj.Name)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].Orientation = {x, y, z}
        end
    end)
    if not success then
        warn("[SUPERTOOL] Rotation change failed: " .. tostring(err))
    end
end

local function changeRotX(x)
    if #selectedObjects == 0 then return end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local rx, ry, rz = obj.CFrame:ToEulerAnglesXYZ()
            local oldCFrame = obj.CFrame
            table.insert(editedObjects, {object = obj, property = "CFrame", oldValue = oldCFrame})
            obj.CFrame = CFrame.new(obj.Position) * CFrame.Angles(math.rad(x), ry, rz)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].Orientation = {math.deg(rx), math.deg(ry), math.deg(rz)}
        end
    end)
    if not success then
        warn("[SUPERTOOL] Rot X change failed: " .. tostring(err))
    end
end

local function changeRotY(y)
    if #selectedObjects == 0 then return end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local rx, ry, rz = obj.CFrame:ToEulerAnglesXYZ()
            local oldCFrame = obj.CFrame
            table.insert(editedObjects, {object = obj, property = "CFrame", oldValue = oldCFrame})
            obj.CFrame = CFrame.new(obj.Position) * CFrame.Angles(rx, math.rad(y), rz)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].Orientation = {math.deg(rx), math.deg(ry), math.deg(rz)}
        end
    end)
    if not success then
        warn("[SUPERTOOL] Rot Y change failed: " .. tostring(err))
    end
end

local function changeRotZ(z)
    if #selectedObjects == 0 then return end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local rx, ry, rz = obj.CFrame:ToEulerAnglesXYZ()
            local oldCFrame = obj.CFrame
            table.insert(editedObjects, {object = obj, property = "CFrame", oldValue = oldCFrame})
            obj.CFrame = CFrame.new(obj.Position) * CFrame.Angles(rx, ry, math.rad(z))
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].Orientation = {math.deg(rx), math.deg(ry), math.deg(rz)}
        end
    end)
    if not success then
        warn("[SUPERTOOL] Rot Z change failed: " .. tostring(err))
    end
end

local function changeSizeX(x)
    if #selectedObjects == 0 then return end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local oldSize = obj.Size
            table.insert(editedObjects, {object = obj, property = "Size", oldValue = oldSize})
            obj.Size = Vector3.new(x, obj.Size.Y, obj.Size.Z)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].Size = {obj.Size.X, obj.Size.Y, obj.Size.Z}
        end
    end)
    if not success then
        warn("[SUPERTOOL] Size X change failed: " .. tostring(err))
    end
end

local function changeSizeY(y)
    if #selectedObjects == 0 then return end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local oldSize = obj.Size
            table.insert(editedObjects, {object = obj, property = "Size", oldValue = oldSize})
            obj.Size = Vector3.new(obj.Size.X, y, obj.Size.Z)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].Size = {obj.Size.X, obj.Size.Y, obj.Size.Z}
        end
    end)
    if not success then
        warn("[SUPERTOOL] Size Y change failed: " .. tostring(err))
    end
end

local function changeSizeZ(z)
    if #selectedObjects == 0 then return end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local oldSize = obj.Size
            table.insert(editedObjects, {object = obj, property = "Size", oldValue = oldSize})
            obj.Size = Vector3.new(obj.Size.X, obj.Size.Y, z)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].Size = {obj.Size.X, obj.Size.Y, obj.Size.Z}
        end
    end)
    if not success then
        warn("[SUPERTOOL] Size Z change failed: " .. tostring(err))
    end
end

local function resetSize()
    if #selectedObjects == 0 then return end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local oldSize = obj.Size
            table.insert(editedObjects, {object = obj, property = "Size", oldValue = oldSize})
            obj.Size = Vector3.new(4, 2, 4)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].Size = {4, 2, 4}
        end
    end)
    if not success then
        warn("[SUPERTOOL] Reset size failed: " .. tostring(err))
    end
end

-- New Feature: Change Material
local function changeMaterial(materialName)
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for material change")
        return 
    end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local oldMaterial = obj.Material
            table.insert(editedObjects, {object = obj, property = "Material", oldValue = oldMaterial})
            obj.Material = Enum.Material[materialName] or Enum.Material.SmoothPlastic
            print("[SUPERTOOL] Changed material to " .. materialName .. " for " .. obj.Name)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].Material = materialName
        end
    end)
    if not success then
        warn("[SUPERTOOL] Material change failed: " .. tostring(err))
    end
end

-- New Feature: Change Shape
local function changeShape(shapeName)
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for shape change")
        return 
    end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local oldShape = obj.Shape
            table.insert(editedObjects, {object = obj, property = "Shape", oldValue = oldShape})
            obj.Shape = Enum.PartType[shapeName] or Enum.PartType.Block
            print("[SUPERTOOL] Changed shape to " .. shapeName .. " for " .. obj.Name)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].Shape = shapeName
        end
    end)
    if not success then
        warn("[SUPERTOOL] Shape change failed: " .. tostring(err))
    end
end

-- New Feature: Add Surface Light
local function addSurfaceLight()
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for adding light")
        return 
    end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local light = Instance.new("SurfaceLight")
            light.Parent = obj
            light.Face = Enum.NormalId.Top
            light.Color = Color3.fromRGB(255, 255, 255)
            light.Brightness = 1
            print("[SUPERTOOL] Added SurfaceLight to " .. obj.Name)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].SurfaceLight = true
        end
    end)
    if not success then
        warn("[SUPERTOOL] Add light failed: " .. tostring(err))
    end
end

-- New Feature: Freeze Object
local function freezeObject()
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for freeze")
        return 
    end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local oldAnchored = obj.Anchored
            local oldVelocity = obj.Velocity
            table.insert(editedObjects, {object = obj, property = "Anchored", oldValue = oldAnchored})
            table.insert(editedObjects, {object = obj, property = "Velocity", oldValue = oldVelocity})
            obj.Anchored = true
            obj.Velocity = Vector3.new(0, 0, 0)
            print("[SUPERTOOL] Froze object: " .. obj.Name)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].Anchored = true
            objectEdits[path].Velocity = {0, 0, 0}
        end
    end)
    if not success then
        warn("[SUPERTOOL] Freeze failed: " .. tostring(err))
    end
end

-- New Feature: Unfreeze Object
local function unfreezeObject()
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for unfreeze")
        return 
    end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local oldAnchored = obj.Anchored
            table.insert(editedObjects, {object = obj, property = "Anchored", oldValue = oldAnchored})
            obj.Anchored = false
            print("[SUPERTOOL] Unfroze object: " .. obj.Name)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].Anchored = false
        end
    end)
    if not success then
        warn("[SUPERTOOL] Unfreeze failed: " .. tostring(err))
    end
end

-- New Feature: Remove Effects (e.g., slippery, custom physics)
local function removeEffects()
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for removing effects")
        return 
    end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local oldProperties = obj.CustomPhysicalProperties
            table.insert(editedObjects, {object = obj, property = "CustomPhysicalProperties", oldValue = oldProperties})
            obj.CustomPhysicalProperties = nil  -- Remove custom physics
            for _, surface in pairs(Enum.SurfaceType:GetEnumItems()) do
                if obj.TopSurface == surface or obj.BottomSurface == surface or obj.LeftSurface == surface or obj.RightSurface == surface or obj.FrontSurface == surface or obj.BackSurface == surface then
                    obj.TopSurface = Enum.SurfaceType.Smooth
                    obj.BottomSurface = Enum.SurfaceType.Smooth
                    obj.LeftSurface = Enum.SurfaceType.Smooth
                    obj.RightSurface = Enum.SurfaceType.Smooth
                    obj.FrontSurface = Enum.SurfaceType.Smooth
                    obj.BackSurface = Enum.SurfaceType.Smooth
                end
            end
            print("[SUPERTOOL] Removed effects from: " .. obj.Name)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].CustomPhysicalProperties = nil
            objectEdits[path].TopSurface = "Smooth"
            -- Repeat for other surfaces
        end
    end)
    if not success then
        warn("[SUPERTOOL] Remove effects failed: " .. tostring(err))
    end
end

-- New Feature: Set Slippery
local function setSlippery()
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for slippery effect")
        return 
    end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local oldProperties = obj.CustomPhysicalProperties
            table.insert(editedObjects, {object = obj, property = "CustomPhysicalProperties", oldValue = oldProperties})
            obj.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.01, 0.5, 100, 1)  -- Low friction for slippery
            print("[SUPERTOOL] Applied slippery effect to: " .. obj.Name)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].CustomPhysicalProperties = {Density = 0.7, Friction = 0.01, Elasticity = 0.5, FrictionWeight = 100, ElasticityWeight = 1}
        end
    end)
    if not success then
        warn("[SUPERTOOL] Set slippery failed: " .. tostring(err))
    end
end

-- New Feature: Set Custom Physical Properties
local function setCustomPhysics(density, friction, elasticity, frictionWeight, elasticityWeight)
    if #selectedObjects == 0 then 
        warn("[SUPERTOOL] No object selected for custom physics")
        return 
    end
    local success, err = pcall(function()
        for _, obj in pairs(selectedObjects) do
            local oldProperties = obj.CustomPhysicalProperties
            table.insert(editedObjects, {object = obj, property = "CustomPhysicalProperties", oldValue = oldProperties})
            obj.CustomPhysicalProperties = PhysicalProperties.new(density, friction, elasticity, frictionWeight, elasticityWeight)
            print("[SUPERTOOL] Set custom physics for: " .. obj.Name)
            local path = getFullPath(obj)
            objectEdits[path] = objectEdits[path] or {}
            objectEdits[path].CustomPhysicalProperties = {Density = density, Friction = friction, Elasticity = elasticity, FrictionWeight = frictionWeight, ElasticityWeight = elasticityWeight}
        end
    end)
    if not success then
        warn("[SUPERTOOL] Set custom physics failed: " .. tostring(err))
    end
end

local function undoObjectEdit()
    if #editedObjects > 0 then
        local lastEdit = table.remove(editedObjects)
        local success, err = pcall(function()
            if lastEdit.object and lastEdit.object.Parent then
                local current = lastEdit.object[lastEdit.property]
                lastEdit.newValue = current -- Store the value before undo for redo
                lastEdit.object[lastEdit.property] = lastEdit.oldValue
                table.insert(redoObjects, lastEdit) -- Push to redo
                print("[SUPERTOOL] Undid edit on " .. lastEdit.property)
            end
        end)
        if not success then
            warn("[SUPERTOOL] Undo edit failed: " .. tostring(err))
        end
    elseif #deletedObjects > 0 then
        local lastDelete = table.remove(deletedObjects)
        local success, err = pcall(function()
            if lastDelete.object then
                lastDelete.object.Parent = lastDelete.parent
                table.insert(redoObjects, {action = "delete", data = lastDelete}) -- For redo delete
                print("[SUPERTOOL] Undid deletion of: " .. lastDelete.name)
            end
        end)
        if not success then
            warn("[SUPERTOOL] Undo delete failed: " .. tostring(err))
        end
    end
    updateEditorList()
end

local function redoObjectEdit()
    if #redoObjects > 0 then
        local lastRedo = table.remove(redoObjects)
        local success, err = pcall(function()
            if lastRedo.action == "delete" then
                local delData = lastRedo.data
                if delData.object and delData.object.Parent then
                    delData.object:Destroy()
                    table.insert(deletedObjects, delData)
                    print("[SUPERTOOL] Redid deletion of: " .. delData.name)
                end
            else
                if lastRedo.object and lastRedo.object.Parent then
                    local current = lastRedo.object[lastRedo.property]
                    lastRedo.oldValue = current -- Update old for next undo
                    lastRedo.object[lastRedo.property] = lastRedo.newValue
                    table.insert(editedObjects, lastRedo) -- Push back to undo stack
                    print("[SUPERTOOL] Redid edit on " .. lastRedo.property)
                end
            end
        end)
        if not success then
            warn("[SUPERTOOL] Redo failed: " .. tostring(err))
        end
    end
    updateEditorList()
end

local function clearEditorHistory()
    editedObjects = {}
    deletedObjects = {}
    redoObjects = {}
    updateEditorList()
    print("[SUPERTOOL] Cleared editor history")
end

local function initCopyListUI()
    if copyListFrame then return end
    
    copyListFrame = Instance.new("Frame")
    copyListFrame.Name = "CopyListFrame"
    copyListFrame.Parent = ScreenGui
    copyListFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    copyListFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    copyListFrame.BorderSizePixel = 1
    copyListFrame.Position = UDim2.new(0.5, 200, 0.5, 0)
    copyListFrame.Size = UDim2.new(0, 250, 0, 300)
    copyListFrame.Visible = false
    copyListFrame.Active = true
    copyListFrame.Draggable = true

    local title = Instance.new("TextLabel")
    title.Parent = copyListFrame
    title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    title.BorderSizePixel = 0
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Font = Enum.Font.GothamBold
    title.Text = "Copy List"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 12

    local closeButton = Instance.new("TextButton")
    closeButton.Parent = copyListFrame
    closeButton.BackgroundTransparency = 1
    closeButton.Position = UDim2.new(1, -25, 0, 3)
    closeButton.Size = UDim2.new(0, 20, 0, 20)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeButton.TextSize = 14

    local copyScrollFrame = Instance.new("ScrollingFrame")
    copyScrollFrame.Parent = copyListFrame
    copyScrollFrame.BackgroundTransparency = 1
    copyScrollFrame.Position = UDim2.new(0, 5, 0, 30)
    copyScrollFrame.Size = UDim2.new(1, -10, 1, -35)
    copyScrollFrame.ScrollBarThickness = 4
    copyScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
    copyScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    local copyLayout = Instance.new("UIListLayout")
    copyLayout.Parent = copyScrollFrame
    copyLayout.Padding = UDim.new(0, 3)

    closeButton.MouseButton1Click:Connect(function()
        copyListFrame.Visible = false
        copyListVisible = false
    end)
end

local function updateCopyList()
    if not copyListFrame then initCopyListUI() end
    local scrollFrame = copyListFrame:FindFirstChildOfClass("ScrollingFrame")
    if not scrollFrame then return end
    
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    for i, copied in ipairs(copiedObjects) do
        local itemFrame = Instance.new("Frame")
        itemFrame.Parent = scrollFrame
        itemFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        itemFrame.Size = UDim2.new(1, 0, 0, 30)
        
        local nameInput = Instance.new("TextBox")
        nameInput.Parent = itemFrame
        nameInput.Position = UDim2.new(0, 5, 0, 5)
        nameInput.Size = UDim2.new(0.4, 0, 1, -10)
        nameInput.BackgroundTransparency = 1
        nameInput.Text = copied.name
        nameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameInput.TextSize = 10
        nameInput.Font = Enum.Font.Gotham
        nameInput.FocusLost:Connect(function()
            renameCopy(i, nameInput.Text)
        end)
        
        local pasteBtn = Instance.new("TextButton")
        pasteBtn.Parent = itemFrame
        pasteBtn.Position = UDim2.new(0.45, 0, 0, 5)
        pasteBtn.Size = UDim2.new(0.25, 0, 1, -10)
        pasteBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
        pasteBtn.Text = "Paste"
        pasteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        pasteBtn.TextSize = 10
        pasteBtn.Font = Enum.Font.Gotham
        pasteBtn.MouseButton1Click:Connect(function()
            local mouse = player:GetMouse()
            local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
            local params = RaycastParams.new()
            params.FilterDescendantsInstances = {player.Character}
            params.FilterType = Enum.RaycastFilterType.Exclude
            local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
            local pastePos = result and result.Position or copied.originalCFrame.Position
            pasteObject(i, pastePos)
        end)
        
        local deleteBtn = Instance.new("TextButton")
        deleteBtn.Parent = itemFrame
        deleteBtn.Position = UDim2.new(0.7, 0, 0, 5)
        deleteBtn.Size = UDim2.new(0.25, 0, 1, -10)
        deleteBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        deleteBtn.Text = "Delete"
        deleteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        deleteBtn.TextSize = 10
        deleteBtn.Font = Enum.Font.Gotham
        deleteBtn.MouseButton1Click:Connect(function()
            deleteCopy(i)
            updateCopyList()
        end)
    end
    
    local layout = scrollFrame:FindFirstChildOfClass("UIListLayout")
    if layout then
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end
end

local function toggleCopyList()
    if not copyListFrame then initCopyListUI() end
    copyListVisible = not copyListVisible
    copyListFrame.Visible = copyListVisible
    if copyListVisible then
        updateCopyList()
    end
end

local function createSlider(parent, labelText, min, max, initial, callback)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Parent = parent
    sliderFrame.Size = UDim2.new(1, 0, 0, 25)
    sliderFrame.BackgroundTransparency = 1

    local label = Instance.new("TextLabel")
    label.Parent = sliderFrame
    label.Size = UDim2.new(0.3, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 10
    label.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("Frame")
    track.Parent = sliderFrame
    track.Position = UDim2.new(0.3, 0, 0.25, 0)
    track.Size = UDim2.new(0.6, 0, 0.5, 0)
    track.BackgroundColor3 = Color3.fromRGB(25, 25, 25)

    local knob = Instance.new("TextButton")
    knob.Parent = track
    knob.Size = UDim2.new(0, 10, 2, 0)
    knob.Position = UDim2.new(0, 0, -0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    knob.Text = ""

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Parent = sliderFrame
    valueLabel.Position = UDim2.new(0.9, 0, 0, 0)
    valueLabel.Size = UDim2.new(0.1, 0, 1, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueLabel.TextSize = 10
    valueLabel.Font = Enum.Font.Gotham

    local function updateValue(noCallback)
        local frac = knob.Position.X.Scale
        local value = min + (max - min) * frac
        value = math.round(value)
        valueLabel.Text = tostring(value)
        if not noCallback then
            callback(value)
        end
    end

    local dragConn
    knob.MouseButton1Down:Connect(function()
        local mouseStart = UserInputService:GetMouseLocation().X
        local knobStart = knob.Position.X.Scale
        dragConn = RunService.RenderStepped:Connect(function()
            local mouseCurrent = UserInputService:GetMouseLocation().X
            local delta = (mouseCurrent - mouseStart) / track.AbsoluteSize.X
            local newFrac = math.clamp(knobStart + delta, 0, 1)
            knob.Position = UDim2.new(newFrac, 0, -0.5, 0)
            updateValue()
        end)
    end)

    local endConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and dragConn then
            dragConn:Disconnect()
            endConn:Disconnect()
        end
    end)

    -- Set initial
    local initFrac = (initial - min) / (max - min)
    knob.Position = UDim2.new(math.clamp(initFrac, 0, 1), 0, -0.5, 0)
    updateValue(true)  -- Initial update without callback

    return sliderFrame
end

local function selectAllSimilar()
    if #selectedObjects == 0 then return end
    local template = selectedObjects[1]
    local name = template.Name
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == name and obj ~= template then
            table.insert(selectedObjects, obj)
            local box = Instance.new("SelectionBox")
            box.Parent = obj
            box.Adornee = obj
            box.LineThickness = 0.1
            box.Color3 = Color3.fromRGB(0, 255, 0)
            table.insert(selectionBoxes, box)
        end
    end
    showEditorGUI()
    print("[SUPERTOOL] Selected all similar objects to " .. name)
end

local function viewScripts()
    if #selectedObjects == 0 then return end
    local obj = selectedObjects[1]
    local scripts = {}
    for _, desc in pairs(obj:GetDescendants()) do
        if desc:IsA("LocalScript") or desc:IsA("ModuleScript") or desc:IsA("Script") then
            table.insert(scripts, desc)
        end
    end
    if #scripts == 0 then
        print("[SUPERTOOL] No scripts found in " .. obj.Name)
        return
    end
    local scriptFrame = Instance.new("Frame")
    scriptFrame.Parent = ScreenGui
    scriptFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    scriptFrame.Size = UDim2.new(0, 400, 0, 300)
    scriptFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    scriptFrame.Draggable = true
    scriptFrame.Active = true

    local title = Instance.new("TextLabel")
    title.Parent = scriptFrame
    title.Size = UDim2.new(1, 0, 0, 25)
    title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    title.Text = "Scripts in " .. obj.Name
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12

    local closeBtn = Instance.new("TextButton")
    closeBtn.Parent = scriptFrame
    closeBtn.Position = UDim2.new(1, -25, 0, 0)
    closeBtn.Size = UDim2.new(0, 25, 0, 25)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.BackgroundTransparency = 1
    closeBtn.MouseButton1Click:Connect(function()
        scriptFrame:Destroy()
    end)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Parent = scriptFrame
    scroll.Position = UDim2.new(0, 0, 0, 25)
    scroll.Size = UDim2.new(1, 0, 1, -25)
    scroll.BackgroundTransparency = 1

    local layout = Instance.new("UIListLayout")
    layout.Parent = scroll
    layout.Padding = UDim.new(0, 5)

    for _, script in pairs(scripts) do
        local frame = Instance.new("Frame")
        frame.Parent = scroll
        frame.Size = UDim2.new(1, 0, 0, 50)
        frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Parent = frame
        nameLabel.Position = UDim2.new(0, 5, 0, 5)
        nameLabel.Size = UDim2.new(1, -10, 0, 20)
        nameLabel.Text = script.Name .. " (" .. script.ClassName .. ")"
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

        local sourceBtn = Instance.new("TextButton")
        sourceBtn.Parent = frame
        sourceBtn.Position = UDim2.new(0, 5, 0, 30)
        sourceBtn.Size = UDim2.new(1, -10, 0, 20)
        sourceBtn.Text = "View Source"
        sourceBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
        sourceBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        sourceBtn.MouseButton1Click:Connect(function()
            if script:IsA("LocalScript") or script:IsA("ModuleScript") then
                print("[SUPERTOOL] Script Source for " .. script.Name .. ":\n" .. script.Source)
            else
                print("[SUPERTOOL] server Script source cannot be viewed from client")
            end
        end)
    end
end

local function injectScript(code)
    if #selectedObjects == 0 then return end
    local obj = selectedObjects[1]
    local script = Instance.new("LocalScript")
    script.Parent = obj
    script.Source = code
    script.Disabled = false
    print("[SUPERTOOL] Injected LocalScript into " .. obj.Name)
end

local function showEditorGUI()
    if #selectedObjects == 0 then return end
    
    if editorGui then
        lastGuiPosition = editorGui.Position
        lastScrollPosition = editorGui:FindFirstChildOfClass("ScrollingFrame").CanvasPosition.Y
        editorGui:Destroy()
    end
    
    editorGui = Instance.new("Frame")
    editorGui.Parent = ScreenGui
    editorGui.Position = lastGuiPosition
    editorGui.Size = UDim2.new(0, 300, 0, 500)
    editorGui.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    editorGui.BorderColor3 = Color3.fromRGB(45, 45, 45)
    editorGui.BorderSizePixel = 1
    editorGui.Active = true
    editorGui.Draggable = true
    editorGui.ZIndex = 10
    
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 5)
    uiCorner.Parent = editorGui
    
    local title = Instance.new("TextLabel")
    title.Parent = editorGui
    title.Size = UDim2.new(1, 0, 0, 25)
    title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    title.Text = "Object Editor (" .. #selectedObjects .. " selected)"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12

    local closeButton = Instance.new("TextButton")
    closeButton.Parent = editorGui
    closeButton.BackgroundTransparency = 1
    closeButton.Position = UDim2.new(1, -25, 0, 3)
    closeButton.Size = UDim2.new(0, 20, 0, 20)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 14
    closeButton.ZIndex = 11
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Parent = editorGui
    scrollFrame.Position = UDim2.new(0, 5, 0, 30)
    scrollFrame.Size = UDim2.new(1, -10, 1, -35)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 5
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.None  -- Prevent auto scroll
    
    local layout = Instance.new("UIListLayout")
    layout.Parent = scrollFrame
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    
    -- Helper function to create section labels
    local function createSectionLabel(text)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 20)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = Color3.fromRGB(150, 150, 255)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        return label
    end
    
    -- Basic Actions Section
    local basicSection = createSectionLabel("Basic Actions (Copy, Paste, Duplicate, Delete)")
    basicSection.Parent = scrollFrame
    
    -- Duplicate Button
    local duplicateBtn = Instance.new("TextButton")
    duplicateBtn.Parent = scrollFrame
    duplicateBtn.Size = UDim2.new(1, 0, 0, 25)
    duplicateBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    duplicateBtn.Text = "Duplicate (Creates a copy nearby)"
    duplicateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    duplicateBtn.Font = Enum.Font.Gotham
    duplicateBtn.TextSize = 10
    duplicateBtn.MouseButton1Click:Connect(duplicateObject)
    
    -- Copy Button
    local copyBtn = Instance.new("TextButton")
    copyBtn.Parent = scrollFrame
    copyBtn.Size = UDim2.new(1, 0, 0, 25)
    copyBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 120)
    copyBtn.Text = "Copy to List (Saves to copy list)"
    copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copyBtn.Font = Enum.Font.Gotham
    copyBtn.TextSize = 10
    copyBtn.MouseButton1Click:Connect(copyObject)
    
    -- View Copy List Button
    local viewCopyListBtn = Instance.new("TextButton")
    viewCopyListBtn.Parent = scrollFrame
    viewCopyListBtn.Size = UDim2.new(1, 0, 0, 25)
    viewCopyListBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 100)
    viewCopyListBtn.Text = "View Copy List (Paste/Delete from list)"
    viewCopyListBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    viewCopyListBtn.Font = Enum.Font.Gotham
    viewCopyListBtn.TextSize = 10
    viewCopyListBtn.MouseButton1Click:Connect(toggleCopyList)
    
    -- Delete Button
    local deleteBtn = Instance.new("TextButton")
    deleteBtn.Parent = scrollFrame
    deleteBtn.Size = UDim2.new(1, 0, 0, 25)
    deleteBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    deleteBtn.Text = "Delete (Removes object, undo available)"
    deleteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    deleteBtn.Font = Enum.Font.Gotham
    deleteBtn.TextSize = 10
    deleteBtn.MouseButton1Click:Connect(deleteObject)
    
    -- Clear Selection Button
    local clearBtn = Instance.new("TextButton")
    clearBtn.Parent = scrollFrame
    clearBtn.Size = UDim2.new(1, 0, 0, 25)
    clearBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
    clearBtn.Text = "Clear All Selection"
    clearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    clearBtn.Font = Enum.Font.Gotham
    clearBtn.TextSize = 10
    clearBtn.MouseButton1Click:Connect(clearSelection)
    
    -- Paste Confirmation Toggle
    local confirmToggle = Instance.new("TextButton")
    confirmToggle.Parent = scrollFrame
    confirmToggle.Size = UDim2.new(1, 0, 0, 25)
    confirmToggle.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    confirmToggle.Text = "Paste Confirmation: " .. (pasteConfirmationEnabled and "ON" or "OFF")
    confirmToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    confirmToggle.Font = Enum.Font.Gotham
    confirmToggle.TextSize = 10
    confirmToggle.MouseButton1Click:Connect(function()
        pasteConfirmationEnabled = not pasteConfirmationEnabled
        confirmToggle.Text = "Paste Confirmation: " .. (pasteConfirmationEnabled and "ON" or "OFF")
    end)
    
    -- Multi-Select Toggle
    local multiToggle = Instance.new("TextButton")
    multiToggle.Parent = scrollFrame
    multiToggle.Size = UDim2.new(1, 0, 0, 25)
    multiToggle.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    multiToggle.Text = "Allow Select >2: " .. (allowMultiMoreThan2 and "ON" or "OFF")
    multiToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    multiToggle.Font = Enum.Font.Gotham
    multiToggle.TextSize = 10
    multiToggle.MouseButton1Click:Connect(function()
        allowMultiMoreThan2 = not allowMultiMoreThan2
        multiToggle.Text = "Allow Select >2: " .. (allowMultiMoreThan2 and "ON" or "OFF")
        if not allowMultiMoreThan2 and #selectedObjects > 2 then
            while #selectedObjects > 2 do
                local removed = table.remove(selectedObjects, 1)
                local box = table.remove(selectionBoxes, 1)
                if box then box:Destroy() end
            end
            showEditorGUI()
        end
    end)
    
    -- Select All Similar Button
    local selectAllBtn = Instance.new("TextButton")
    selectAllBtn.Parent = scrollFrame
    selectAllBtn.Size = UDim2.new(1, 0, 0, 25)
    selectAllBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 150)
    selectAllBtn.Text = "Select All Similar"
    selectAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectAllBtn.Font = Enum.Font.Gotham
    selectAllBtn.TextSize = 10
    selectAllBtn.MouseButton1Click:Connect(selectAllSimilar)
    
    -- Toggles Section (multi)
    local togglesSection = createSectionLabel("Toggles (Anchored, CanCollide)")
    togglesSection.Parent = scrollFrame
    
    -- Toggle Anchored
    local anchoredBtn = Instance.new("TextButton")
    anchoredBtn.Parent = scrollFrame
    anchoredBtn.Size = UDim2.new(1, 0, 0, 25)
    anchoredBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    anchoredBtn.Text = selectedObjects[1].Anchored and "Unanchor (Allow physics)" or "Anchor (Fix in place)"
    anchoredBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    anchoredBtn.Font = Enum.Font.Gotham
    anchoredBtn.TextSize = 10
    anchoredBtn.MouseButton1Click:Connect(function()
        toggleAnchored()
        anchoredBtn.Text = selectedObjects[1].Anchored and "Unanchor (Allow physics)" or "Anchor (Fix in place)"
    end)
    
    -- Toggle CanCollide
    local collideBtn = Instance.new("TextButton")
    collideBtn.Parent = scrollFrame
    collideBtn.Size = UDim2.new(1, 0, 0, 25)
    collideBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    collideBtn.Text = selectedObjects[1].CanCollide and "Disable Collision (Pass through)" or "Enable Collision (Solid)"
    collideBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    collideBtn.Font = Enum.Font.Gotham
    collideBtn.TextSize = 10
    collideBtn.MouseButton1Click:Connect(function()
        toggleCanCollide()
        collideBtn.Text = selectedObjects[1].CanCollide and "Disable Collision (Pass through)" or "Enable Collision (Solid)"
    end)
    
    -- Transform Section
    local transformSection = createSectionLabel("Transform (Position, Rotation, Size)")
    transformSection.Parent = scrollFrame
    
    -- Position Inputs
    local posFrame = Instance.new("Frame")
    posFrame.Parent = scrollFrame
    posFrame.Size = UDim2.new(1, 0, 0, 30)
    posFrame.BackgroundTransparency = 1
    
    local posLabel = Instance.new("TextLabel")
    posLabel.Parent = posFrame
    posLabel.Size = UDim2.new(1, 0, 0, 15)
    posLabel.BackgroundTransparency = 1
    posLabel.Text = "Position (X, Y, Z):"
    posLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    posLabel.Font = Enum.Font.Gotham
    posLabel.TextSize = 10
    
    local posX = Instance.new("TextBox")
    posX.Parent = posFrame
    posX.Position = UDim2.new(0, 0, 0.5, 0)
    posX.Size = UDim2.new(0.3, 0, 0.5, 0)
    posX.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    posX.Text = tostring(selectedObjects[1].Position.X)
    posX.TextColor3 = Color3.fromRGB(255, 255, 255)
    posX.Font = Enum.Font.Gotham
    posX.TextSize = 10
    
    local posY = Instance.new("TextBox")
    posY.Parent = posFrame
    posY.Position = UDim2.new(0.33, 0, 0.5, 0)
    posY.Size = UDim2.new(0.3, 0, 0.5, 0)
    posY.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    posY.Text = tostring(selectedObjects[1].Position.Y)
    posY.TextColor3 = Color3.fromRGB(255, 255, 255)
    posY.Font = Enum.Font.Gotham
    posY.TextSize = 10
    
    local posZ = Instance.new("TextBox")
    posZ.Parent = posFrame
    posZ.Position = UDim2.new(0.66, 0, 0.5, 0)
    posZ.Size = UDim2.new(0.3, 0, 0.5, 0)
    posZ.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    posZ.Text = tostring(selectedObjects[1].Position.Z)
    posZ.TextColor3 = Color3.fromRGB(255, 255, 255)
    posZ.Font = Enum.Font.Gotham
    posZ.TextSize = 10
    
    local posBtn = Instance.new("TextButton")
    posBtn.Parent = scrollFrame
    posBtn.Size = UDim2.new(1, 0, 0, 25)
    posBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
    posBtn.Text = "Apply Position (Sets absolute position)"
    posBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    posBtn.Font = Enum.Font.Gotham
    posBtn.TextSize = 10
    posBtn.MouseButton1Click:Connect(function()
        local x, y, z = tonumber(posX.Text), tonumber(posY.Text), tonumber(posZ.Text)
        if x and y and z then
            changePosition(x, y, z)
        end
    end)
    
    -- Move Buttons with reduced sensitivity (step = 0.2)
    local moveLabel = Instance.new("TextLabel")
    moveLabel.Parent = scrollFrame
    moveLabel.Size = UDim2.new(1, 0, 0, 15)
    moveLabel.BackgroundTransparency = 1
    moveLabel.Text = "Move Controls (Hold to continue):"
    moveLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    moveLabel.Font = Enum.Font.Gotham
    moveLabel.TextSize = 10
    
    local moveFrame = Instance.new("Frame")
    moveFrame.Parent = scrollFrame
    moveFrame.Size = UDim2.new(1, 0, 0, 60)
    moveFrame.BackgroundTransparency = 1
    
    local function createHoldButton(parent, pos, size, color, text, direction)
        local btn = Instance.new("TextButton")
        btn.Parent = parent
        btn.Position = pos
        btn.Size = size
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 10
        
        local connection
        btn.MouseButton1Down:Connect(function()
            connection = RunService.Heartbeat:Connect(function()
                for _, obj in pairs(selectedObjects) do
                    obj.Position = obj.Position + direction * 0.2  -- Reduced sensitivity
                end
            end)
        end)
        
        btn.MouseButton1Up:Connect(function()
            if connection then
                connection:Disconnect()
            end
        end)
        
        btn.MouseLeave:Connect(function()
            if connection then
                connection:Disconnect()
            end
        end)
        
        return btn
    end
    
    createHoldButton(moveFrame, UDim2.new(0.4, 0, 0, 0), UDim2.new(0.2, 0, 0.5, 0), Color3.fromRGB(80, 80, 120), "Up", Vector3.new(0, 0.2, 0))
    createHoldButton(moveFrame, UDim2.new(0.4, 0, 0.5, 0), UDim2.new(0.2, 0, 0.5, 0), Color3.fromRGB(80, 80, 120), "Down", Vector3.new(0, -0.2, 0))
    createHoldButton(moveFrame, UDim2.new(0, 0, 0.25, 0), UDim2.new(0.2, 0, 0.5, 0), Color3.fromRGB(80, 80, 120), "Left", Vector3.new(-0.2, 0, 0))
    createHoldButton(moveFrame, UDim2.new(0.8, 0, 0.25, 0), UDim2.new(0.2, 0, 0.5, 0), Color3.fromRGB(80, 80, 120), "Right", Vector3.new(0.2, 0, 0))
    createHoldButton(moveFrame, UDim2.new(0.2, 0, 0, 0), UDim2.new(0.2, 0, 0.5, 0), Color3.fromRGB(80, 80, 120), "Forward", Vector3.new(0, 0, -0.2))
    createHoldButton(moveFrame, UDim2.new(0.6, 0, 0, 0), UDim2.new(0.2, 0, 0.5, 0), Color3.fromRGB(80, 80, 120), "Backward", Vector3.new(0, 0, 0.2))
    
    -- Rotation Sliders
    local rx, ry, rz = selectedObjects[1].CFrame:ToEulerAnglesXYZ()
    createSlider(scrollFrame, "Rotation X:", -180, 180, math.deg(rx), changeRotX)
    createSlider(scrollFrame, "Rotation Y:", -180, 180, math.deg(ry), changeRotY)
    createSlider(scrollFrame, "Rotation Z:", -180, 180, math.deg(rz), changeRotZ)
    
    -- Reset Rotation Button
    local resetRotBtn = Instance.new("TextButton")
    resetRotBtn.Parent = scrollFrame
    resetRotBtn.Size = UDim2.new(1, 0, 0, 25)
    resetRotBtn.BackgroundColor3 = Color3.fromRGB(150, 100, 50)
    resetRotBtn.Text = "Reset Rotation"
    resetRotBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    resetRotBtn.Font = Enum.Font.Gotham
    resetRotBtn.TextSize = 10
    resetRotBtn.MouseButton1Click:Connect(function()
        changeRotation(0, 0, 0)
    end)
    
    -- Size Sliders
    local sx, sy, sz = selectedObjects[1].Size.X, selectedObjects[1].Size.Y, selectedObjects[1].Size.Z
    createSlider(scrollFrame, "Size X:", 0.1, 100, sx, changeSizeX)
    createSlider(scrollFrame, "Size Y:", 0.1, 100, sy, changeSizeY)
    createSlider(scrollFrame, "Size Z:", 0.1, 100, sz, changeSizeZ)
    
    -- Reset Size Button
    local resetSizeBtn = Instance.new("TextButton")
    resetSizeBtn.Parent = scrollFrame
    resetSizeBtn.Size = UDim2.new(1, 0, 0, 25)
    resetSizeBtn.BackgroundColor3 = Color3.fromRGB(150, 100, 50)
    resetSizeBtn.Text = "Reset Size"
    resetSizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    resetSizeBtn.Font = Enum.Font.Gotham
    resetSizeBtn.TextSize = 10
    resetSizeBtn.MouseButton1Click:Connect(resetSize)
    
    -- Effects Section
    local effectsSection = createSectionLabel("Effects (Add Light, Freeze, Remove Effects)")
    effectsSection.Parent = scrollFrame
    
    -- Add Light Button
    local lightBtn = Instance.new("TextButton")
    lightBtn.Parent = scrollFrame
    lightBtn.Size = UDim2.new(1, 0, 0, 25)
    lightBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 60)
    lightBtn.Text = "Add Surface Light (Adds light on top face)"
    lightBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    lightBtn.Font = Enum.Font.Gotham
    lightBtn.TextSize = 10
    lightBtn.MouseButton1Click:Connect(addSurfaceLight)
    
    -- Freeze Button
    local freezeBtn = Instance.new("TextButton")
    freezeBtn.Parent = scrollFrame
    freezeBtn.Size = UDim2.new(1, 0, 0, 25)
    freezeBtn.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
    freezeBtn.Text = "Freeze (Stops movement)"
    freezeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    freezeBtn.Font = Enum.Font.Gotham
    freezeBtn.TextSize = 10
    freezeBtn.MouseButton1Click:Connect(freezeObject)
    
    -- Unfreeze Button
    local unfreezeBtn = Instance.new("TextButton")
    unfreezeBtn.Parent = scrollFrame
    unfreezeBtn.Size = UDim2.new(1, 0, 0, 25)
    unfreezeBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 60)
    unfreezeBtn.Text = "Unfreeze (Allows movement)"
    unfreezeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    unfreezeBtn.Font = Enum.Font.Gotham
    unfreezeBtn.TextSize = 10
    unfreezeBtn.MouseButton1Click:Connect(unfreezeObject)
    
    -- Remove Effects Button
    local removeEffectsBtn = Instance.new("TextButton")
    removeEffectsBtn.Parent = scrollFrame
    removeEffectsBtn.Size = UDim2.new(1, 0, 0, 25)
    removeEffectsBtn.BackgroundColor3 = Color3.fromRGB(150, 100, 50)
    removeEffectsBtn.Text = "Remove Effects (e.g. Slippery surfaces)"
    removeEffectsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    removeEffectsBtn.Font = Enum.Font.Gotham
    removeEffectsBtn.TextSize = 10
    removeEffectsBtn.MouseButton1Click:Connect(removeEffects)
    
    -- Slippery Button
    local slipperyBtn = Instance.new("TextButton")
    slipperyBtn.Parent = scrollFrame
    slipperyBtn.Size = UDim2.new(1, 0, 0, 25)
    slipperyBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 150)
    slipperyBtn.Text = "Set Slippery"
    slipperyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    slipperyBtn.Font = Enum.Font.Gotham
    slipperyBtn.TextSize = 10
    slipperyBtn.MouseButton1Click:Connect(setSlippery)
    
    -- Custom Physics Section
    local physicsSection = createSectionLabel("Custom Physics (Density, Friction, etc)")
    physicsSection.Parent = scrollFrame
    
    createSlider(scrollFrame, "Density:", 0.01, 10, 1, function(value)
        for _, obj in pairs(selectedObjects) do
            local props = obj.CustomPhysicalProperties or PhysicalProperties.new(Enum.Material.Plastic)
            setCustomPhysics(value, props.Friction, props.Elasticity, props.FrictionWeight, props.ElasticityWeight)
        end
    end)
    
    createSlider(scrollFrame, "Friction:", 0, 2, 0.7, function(value)
        for _, obj in pairs(selectedObjects) do
            local props = obj.CustomPhysicalProperties or PhysicalProperties.new(Enum.Material.Plastic)
            setCustomPhysics(props.Density, value, props.Elasticity, props.FrictionWeight, props.ElasticityWeight)
        end
    end)
    
    createSlider(scrollFrame, "Elasticity:", 0, 1, 0.5, function(value)
        for _, obj in pairs(selectedObjects) do
            local props = obj.CustomPhysicalProperties or PhysicalProperties.new(Enum.Material.Plastic)
            setCustomPhysics(props.Density, props.Friction, value, props.FrictionWeight, props.ElasticityWeight)
        end
    end)
    
    -- Color Change
    local colorLabel = Instance.new("TextLabel")
    colorLabel.Parent = scrollFrame
    colorLabel.Size = UDim2.new(1, 0, 0, 15)
    colorLabel.BackgroundTransparency = 1
    colorLabel.Text = "Color (HEX):"
    colorLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    colorLabel.Font = Enum.Font.Gotham
    colorLabel.TextSize = 10
    
    local colorInput = Instance.new("TextBox")
    colorInput.Parent = scrollFrame
    colorInput.Size = UDim2.new(1, 0, 0, 25)
    colorInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    colorInput.PlaceholderText = "#RRGGBB"
    colorInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    colorInput.Font = Enum.Font.Gotham
    colorInput.TextSize = 10
    colorInput.FocusLost:Connect(function()
        changeColor(colorInput.Text)
    end)
    
    -- Transparency Change
    local transLabel = Instance.new("TextLabel")
    transLabel.Parent = scrollFrame
    transLabel.Size = UDim2.new(1, 0, 0, 15)
    transLabel.BackgroundTransparency = 1
    transLabel.Text = "Transparency (0-1):"
    transLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    transLabel.Font = Enum.Font.Gotham
    transLabel.TextSize = 10
    
    local transInput = Instance.new("TextBox")
    transInput.Parent = scrollFrame
    transInput.Size = UDim2.new(1, 0, 0, 25)
    transInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    transInput.Text = tostring(selectedObjects[1].Transparency)
    transInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    transInput.Font = Enum.Font.Gotham
    transInput.TextSize = 10
    transInput.FocusLost:Connect(function()
        local trans = tonumber(transInput.Text)
        if trans then
            changeTransparency(trans)
        end
    end)
    
    -- Drag Move Button (existing, with better label)
    local dragBtn = Instance.new("TextButton")
    dragBtn.Parent = scrollFrame
    dragBtn.Size = UDim2.new(1, 0, 0, 25)
    dragBtn.BackgroundColor3 = Color3.fromRGB(120, 80, 60)
    dragBtn.Text = isDragging and "Disable Drag Move" or "Toggle Drag Move (Click and drag to move)"
    dragBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dragBtn.Font = Enum.Font.Gotham
    dragBtn.TextSize = 10
    dragBtn.MouseButton1Click:Connect(function()
        isDragging = not isDragging
        dragBtn.Text = isDragging and "Disable Drag Move" or "Toggle Drag Move (Click and drag to move)"
        if not isDragging and dragSteppedConn then
            dragSteppedConn:Disconnect()
            dragSteppedConn = nil
        end
    end)
    
    -- View Scripts Button
    local viewScriptsBtn = Instance.new("TextButton")
    viewScriptsBtn.Parent = scrollFrame
    viewScriptsBtn.Size = UDim2.new(1, 0, 0, 25)
    viewScriptsBtn.BackgroundColor3 = Color3.fromRGB(100, 150, 100)
    viewScriptsBtn.Text = "View Scripts"
    viewScriptsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    viewScriptsBtn.Font = Enum.Font.Gotham
    viewScriptsBtn.TextSize = 10
    viewScriptsBtn.MouseButton1Click:Connect(viewScripts)
    
    -- Inject Script
    local injectLabel = Instance.new("TextLabel")
    injectLabel.Parent = scrollFrame
    injectLabel.Size = UDim2.new(1, 0, 0, 15)
    injectLabel.BackgroundTransparency = 1
    injectLabel.Text = "Inject LocalScript Code:"
    injectLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    injectLabel.Font = Enum.Font.Gotham
    injectLabel.TextSize = 10
    
    local injectInput = Instance.new("TextBox")
    injectInput.Parent = scrollFrame
    injectInput.Size = UDim2.new(1, 0, 0, 50)
    injectInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    injectInput.PlaceholderText = "Enter Lua code..."
    injectInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    injectInput.Font = Enum.Font.Gotham
    injectInput.TextSize = 10
    injectInput.MultiLine = true
    
    local injectBtn = Instance.new("TextButton")
    injectBtn.Parent = scrollFrame
    injectBtn.Size = UDim2.new(1, 0, 0, 25)
    injectBtn.BackgroundColor3 = Color3.fromRGB(150, 100, 50)
    injectBtn.Text = "Inject Script"
    injectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    injectBtn.Font = Enum.Font.Gotham
    injectBtn.TextSize = 10
    injectBtn.MouseButton1Click:Connect(function()
        if injectInput.Text ~= "" then
            injectScript(injectInput.Text)
            injectInput.Text = ""
        end
    end)
    
    -- Load Edits Button
    local loadBtn = Instance.new("TextButton")
    loadBtn.Parent = scrollFrame
    loadBtn.Size = UDim2.new(1, 0, 0, 25)
    loadBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
    loadBtn.Text = "Load Edits"
    loadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    loadBtn.Font = Enum.Font.Gotham
    loadBtn.TextSize = 10
    loadBtn.MouseButton1Click:Connect(function()
        local success = loadObjectEdits()
        print("[SUPERTOOL] Load edits: " .. (success and "success" or "failed"))
    end)
    
    -- Save and Update Buttons
    local saveBtn = Instance.new("TextButton")
    saveBtn.Parent = scrollFrame
    saveBtn.Size = UDim2.new(0.5, 0, 0, 25)
    saveBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    saveBtn.Text = "Save Edits"
    saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    saveBtn.Font = Enum.Font.Gotham
    saveBtn.TextSize = 10
    saveBtn.MouseButton1Click:Connect(function()
        saveObjectEdits(false)
    end)
    
    local updateBtn = Instance.new("TextButton")
    updateBtn.Parent = scrollFrame
    updateBtn.Position = UDim2.new(0.5, 0, 0, 0)
    updateBtn.Size = UDim2.new(0.5, 0, 0, 25)
    updateBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 100)
    updateBtn.Text = "Update Edits"
    updateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    updateBtn.Font = Enum.Font.Gotham
    updateBtn.TextSize = 10
    updateBtn.MouseButton1Click:Connect(function()
        saveObjectEdits(true)
    end)
    
    -- Clear History Button
    local clearHistoryBtn = Instance.new("TextButton")
    clearHistoryBtn.Parent = scrollFrame
    clearHistoryBtn.Size = UDim2.new(1, 0, 0, 25)
    clearHistoryBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    clearHistoryBtn.Text = "Clear Editor History"
    clearHistoryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    clearHistoryBtn.Font = Enum.Font.Gotham
    clearHistoryBtn.TextSize = 10
    clearHistoryBtn.MouseButton1Click:Connect(clearEditorHistory)
    
    -- Update canvas size
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end)
    
    task.wait(0.1)
    scrollFrame.CanvasPosition = Vector2.new(0, lastScrollPosition)
    
    closeButton.MouseButton1Click:Connect(function()
        if dragSteppedConn then
            dragSteppedConn:Disconnect()
            dragSteppedConn = nil
        end
        clearSelection()
    end)
    
    -- Update selected status
    if not selectedStatusLabel then
        selectedStatusLabel = Instance.new("TextLabel")
        selectedStatusLabel.Parent = ScreenGui
        selectedStatusLabel.Position = UDim2.new(0.5, 0, 0, 5)
        selectedStatusLabel.Size = UDim2.new(0, 200, 0, 30)
        selectedStatusLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        selectedStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        selectedStatusLabel.Visible = false
    end
    local names = {}
    for _, obj in pairs(selectedObjects) do
        table.insert(names, obj.Name)
    end
    selectedStatusLabel.Text = "Selected: " .. table.concat(names, ", ")
    selectedStatusLabel.Visible = true
end

local function startDrag()
    if #selectedObjects == 0 or not isDragging then return end
    local camera = workspace.CurrentCamera
    local mousePos = UserInputService:GetMouseLocation()
    local ray = camera:ScreenPointToRay(mousePos.X, mousePos.Y)
    local centerObj = selectedObjects[1]
    local normal = camera.CFrame.LookVector
    local denominator = ray.Direction:Dot(normal)
    if math.abs(denominator) < 1e-6 then return end
    local t = (centerObj.Position - ray.Origin):Dot(normal) / denominator
    dragStartHit = ray.Origin + ray.Direction * t
    dragStartPositions = {}
    for i, obj in ipairs(selectedObjects) do
        dragStartPositions[i] = obj.Position
    end
end

local function updateDrag()
    if not dragStartHit then return end
    local camera = workspace.CurrentCamera
    local mousePos = UserInputService:GetMouseLocation()
    local ray = camera:ScreenPointToRay(mousePos.X, mousePos.Y)
    local normal = camera.CFrame.LookVector
    local denominator = ray.Direction:Dot(normal)
    if math.abs(denominator) < 1e-6 then return end
    local t = (dragStartPositions[1] - ray.Origin):Dot(normal) / denominator
    local currentHit = ray.Origin + ray.Direction * t
    local delta = currentHit - dragStartHit
    for i, obj in ipairs(selectedObjects) do
        obj.Position = dragStartPositions[i] + delta
        local path = getFullPath(obj)
        objectEdits[path] = objectEdits[path] or {}
        objectEdits[path].Position = {obj.Position.X, obj.Position.Y, obj.Position.Z}
    end
end

local function setupEditorInput()
    local selectionConnection
    if selectionConnection then selectionConnection:Disconnect() end
    selectionConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if editorEnabled and input.UserInputType == Enum.UserInputType.MouseButton1 then
            if isDragging then return end  -- Don't select new when dragging
            local mouse = player:GetMouse()
            local target = mouse.Target
            if target and target:IsA("BasePart") and target ~= workspace.Terrain then
                if not allowMultiMoreThan2 and #selectedObjects >= 2 then return end
                table.insert(selectedObjects, target)
                local box = Instance.new("SelectionBox")
                box.Parent = target
                box.Adornee = target
                box.LineThickness = 0.1
                box.Color3 = Color3.fromRGB(0, 255, 0)
                table.insert(selectionBoxes, box)
                showEditorGUI()
            end
        end
    end)
    
    local multiSelectConnection = UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if editorEnabled and input.UserInputType == Enum.UserInputType.MouseButton1 then
            showEditorGUI()
        end
    end)
    
    -- Drag input
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if isDragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
            startDrag()
            if dragSteppedConn then dragSteppedConn:Disconnect() end
            dragSteppedConn = RunService.RenderStepped:Connect(updateDrag)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if isDragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
            if dragSteppedConn then
                dragSteppedConn:Disconnect()
                dragSteppedConn = nil
            end
            dragStartHit = nil
            dragStartPositions = {}
        end
    end)
end

local function toggleEditor()
    editorEnabled = not editorEnabled
    if editorEnabled then
        print("[SUPERTOOL] Object Editor enabled - Click on parts to edit")
        setupEditorInput()
        -- Setup right-click for paste
        if rightClickConnection then
            rightClickConnection:Disconnect()
        end
        rightClickConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                local currentTime = tick()
                if currentTime - lastRightClickTime < DOUBLE_CLICK_TIME then
                    if #copiedObjects > 0 then
                        local mouse = player:GetMouse()
                        local ray = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
                        local params = RaycastParams.new()
                        params.FilterDescendantsInstances = {player.Character}
                        params.FilterType = Enum.RaycastFilterType.Exclude
                        local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
                        local pastePos
                        if result then
                            pastePos = result.Position
                        end
                        if pasteConfirmationEnabled then
                            if confirmFrame then
                                confirmFrame:Destroy()
                            end
                            if confirmVisual then
                                confirmVisual:Destroy()
                            end
                            confirmVisual = copiedObjects[#copiedObjects].object:Clone()
                            confirmVisual.Parent = workspace
                            confirmVisual.CFrame = CFrame.new(pastePos)
                            confirmVisual.Transparency = 0.5
                            confirmFrame = Instance.new("Frame")
                            confirmFrame.Parent = ScreenGui
                            confirmFrame.Position = UDim2.fromOffset(mouse.X, mouse.Y)
                            confirmFrame.Size = UDim2.new(0, 150, 0, 50)
                            confirmFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
                            confirmFrame.BorderSizePixel = 1
                            confirmFrame.ZIndex = 100

                            local text = Instance.new("TextLabel")
                            text.Parent = confirmFrame
                            text.Size = UDim2.new(1, 0, 0.5, 0)
                            text.BackgroundTransparency = 1
                            text.Text = "Paste here?"
                            text.TextColor3 = Color3.fromRGB(255, 255, 255)
                            text.Font = Enum.Font.Gotham
                            text.TextSize = 12

                            local yesBtn = Instance.new("TextButton")
                            yesBtn.Parent = confirmFrame
                            yesBtn.Position = UDim2.new(0, 0, 0.5, 0)
                            yesBtn.Size = UDim2.new(0.5, 0, 0.5, 0)
                            yesBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
                            yesBtn.Text = "Yes"
                            yesBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                            yesBtn.Font = Enum.Font.Gotham
                            yesBtn.TextSize = 12
                            yesBtn.MouseButton1Click:Connect(function()
                                if pastePos then
                                    pasteObject(#copiedObjects, pastePos)
                                end
                                confirmFrame:Destroy()
                                confirmFrame = nil
                                confirmVisual:Destroy()
                                confirmVisual = nil
                            end)

                            local noBtn = Instance.new("TextButton")
                            noBtn.Parent = confirmFrame
                            noBtn.Position = UDim2.new(0.5, 0, 0.5, 0)
                            noBtn.Size = UDim2.new(0.5, 0, 0.5, 0)
                            noBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
                            noBtn.Text = "No"
                            noBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                            noBtn.Font = Enum.Font.Gotham
                            noBtn.TextSize = 12
                            noBtn.MouseButton1Click:Connect(function()
                                confirmFrame:Destroy()
                                confirmFrame = nil
                                confirmVisual:Destroy()
                                confirmVisual = nil
                            end)
                        else
                            if pastePos then
                                pasteObject(#copiedObjects, pastePos)
                            end
                        end
                    end
                end
                lastRightClickTime = currentTime
            end
        end)
    else
        print("[SUPERTOOL] Object Editor disabled")
        clearSelection()
        if rightClickConnection then
            rightClickConnection:Disconnect()
            rightClickConnection = nil
        end
    end
end

local function initEditorListUI()
    if EditorListFrame then return end
    
    EditorListFrame = Instance.new("Frame")
    EditorListFrame.Name = "EditorListFrame"
    EditorListFrame.Parent = ScreenGui
    EditorListFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    EditorListFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    EditorListFrame.BorderSizePixel = 1
    EditorListFrame.Position = UDim2.new(0.5, 200, 0.2, 0)
    EditorListFrame.Size = UDim2.new(0, 250, 0, 300)
    EditorListFrame.Visible = false
    EditorListFrame.Active = true
    EditorListFrame.Draggable = true

    local title = Instance.new("TextLabel")
    title.Parent = EditorListFrame
    title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    title.BorderSizePixel = 0
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Font = Enum.Font.GothamBold
    title.Text = "Edit History (Undo with Ctrl+Z)"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 12

    local closeButton = Instance.new("TextButton")
    closeButton.Parent = EditorListFrame
    closeButton.BackgroundTransparency = 1
    closeButton.Position = UDim2.new(1, -25, 0, 3)
    closeButton.Size = UDim2.new(0, 20, 0, 20)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeButton.TextSize = 14

    EditorScrollFrame = Instance.new("ScrollingFrame")
    EditorScrollFrame.Parent = EditorListFrame
    EditorScrollFrame.BackgroundTransparency = 1
    EditorScrollFrame.Position = UDim2.new(0, 5, 0, 30)
    EditorScrollFrame.Size = UDim2.new(1, -10, 1, -35)
    EditorScrollFrame.ScrollBarThickness = 4
    EditorScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
    EditorScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    EditorLayout = Instance.new("UIListLayout")
    EditorLayout.Parent = EditorScrollFrame
    EditorLayout.Padding = UDim.new(0, 3)

    closeButton.MouseButton1Click:Connect(function()
        EditorListFrame.Visible = false
        editorListVisible = false
    end)
end

local function updateEditorList()
    if not EditorScrollFrame or not EditorLayout then return end
    
    pcall(function()
        for _, child in pairs(EditorScrollFrame:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        -- Show recent edits and deletes (increased limit to 10 for more history)
        for i = #editedObjects, math.max(1, #editedObjects - 9), -1 do
            local edit = editedObjects[i]
            if edit then
                local label = Instance.new("TextLabel")
                label.Parent = EditorScrollFrame
                label.Size = UDim2.new(1, 0, 0, 20)
                label.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                label.Text = "Edit: " .. edit.property .. " on " .. (edit.object.Name or "Unknown")
                label.TextColor3 = Color3.fromRGB(255, 255, 255)
                label.TextSize = 10
                label.Font = Enum.Font.Gotham
            end
        end
        
        for i = #deletedObjects, math.max(1, #deletedObjects - 9), -1 do
            local del = deletedObjects[i]
            if del and del.name then
                local label = Instance.new("TextLabel")
                label.Parent = EditorScrollFrame
                label.Size = UDim2.new(1, 0, 0, 20)
                label.BackgroundColor3 = Color3.fromRGB(40, 25, 25)
                label.Text = "Delete: " .. del.name
                label.TextColor3 = Color3.fromRGB(255, 255, 255)
                label.TextSize = 10
                label.Font = Enum.Font.Gotham
            end
        end
        
        task.wait(0.1)
        if EditorLayout then
            EditorScrollFrame.CanvasSize = UDim2.new(0, 0, 0, EditorLayout.AbsoluteContentSize.Y)
        end
    end)
end

local function toggleEditorList()
    if not EditorListFrame then initEditorListUI() end
    editorListVisible = not editorListVisible
    EditorListFrame.Visible = editorListVisible
    if editorListVisible then
        updateEditorList()
    end
end

-- UI Components for Path
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
            autoPlayButton.TextSize = 7
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
        
        -- FIXED: Ctrl+Z for undo during path recording or object edit/delete
        if input.KeyCode == Enum.KeyCode.Z and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            if pathRecording then
                undoToLastMarker()
            elseif #editedObjects > 0 or #deletedObjects > 0 then
                undoObjectEdit()
            end
        end
        
        -- Ctrl+Y for redo
        if input.KeyCode == Enum.KeyCode.Y and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            redoObjectEdit()
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

-- Method 1: Direct Tool Creation (bypass FilteringEnabled)
local function createDirectTool(gearId)
    local success, err = pcall(function()
        -- Load asset
        local assets = game:GetObjects("rbxassetid://" .. gearId)
        local originalTool = assets[1]
        
        if not originalTool or not originalTool:IsA("Tool") then
            warn("Invalid tool asset")
            return
        end
        
        -- Create new tool with basic functionality
        local newTool = Instance.new("Tool")
        newTool.Name = originalTool.Name
        newTool.RequiresHandle = true
        newTool.CanBeDropped = true
        
        -- Clone handle and other essential parts, including textures for inventory icon
        for _, child in pairs(originalTool:GetChildren()) do
            if child.Name == "Handle" or child:IsA("BasePart") or child:IsA("Mesh") or child:IsA("Texture") or child:IsA("Decal") or child:IsA("SpecialMesh") or child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
                local clonedChild = child:Clone()
                clonedChild.Parent = newTool
                -- Clone scripts if they exist, but disable them to avoid conflicts (only for Script and LocalScript)
                if clonedChild:IsA("Script") or clonedChild:IsA("LocalScript") then
                    clonedChild.Disabled = true
                end
                -- ModuleScripts don't have Disabled property, so skip setting it
            end
        end
        
        -- Ensure Handle has proper texture for inventory icon if available
        local handle = newTool:FindFirstChild("Handle")
        if handle then
            local texture = handle:FindFirstChildOfClass("Texture") or handle:FindFirstChildOfClass("Decal")
            if texture then
                -- Texture/Decal on Handle will show as inventory icon
                print("[SUPERTOOL] Inventory icon preserved via Handle texture")
            end
        end
        
        newTool.Parent = player.Backpack
        print("[SUPERTOOL] Direct tool created: " .. newTool.Name)
        
        -- Auto equip
        task.wait(0.1)
        if player.Character and player.Character:FindFirstChild("Humanoid") then
            player.Character.Humanoid:EquipTool(newTool)
        end
    end)
    
    if not success then
        warn("[SUPERTOOL] Direct tool creation failed: " .. tostring(err))
    end
end

local function loadGear(id)
    createDirectTool(id)
end

local function initGearUI()
    if GearFrame then return end
    
    GearFrame = Instance.new("Frame")
    GearFrame.Name = "GearFrame"
    GearFrame.Parent = ScreenGui
    GearFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    GearFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    GearFrame.BorderSizePixel = 1
    GearFrame.Position = UDim2.new(0.5, 0, 0.2, 0)
    GearFrame.Size = UDim2.new(0, 250, 0, 300)
    GearFrame.Visible = false
    GearFrame.Active = true
    GearFrame.Draggable = true

    local GearTitle = Instance.new("TextLabel")
    GearTitle.Parent = GearFrame
    GearTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    GearTitle.BorderSizePixel = 0
    GearTitle.Size = UDim2.new(1, 0, 0, 25)
    GearTitle.Font = Enum.Font.GothamBold
    GearTitle.Text = "GEAR LOADER"
    GearTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    GearTitle.TextSize = 10

    local CloseGearButton = Instance.new("TextButton")
    CloseGearButton.Parent = GearFrame
    CloseGearButton.BackgroundTransparency = 1
    CloseGearButton.Position = UDim2.new(1, -25, 0, 2)
    CloseGearButton.Size = UDim2.new(0, 20, 0, 20)
    CloseGearButton.Font = Enum.Font.GothamBold
    CloseGearButton.Text = "X"
    CloseGearButton.TextColor3 = Color3.fromRGB(255, 100, 100)
    CloseGearButton.TextSize = 12

    GearInput = Instance.new("TextBox")
    GearInput.Parent = GearFrame
    GearInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    GearInput.BorderSizePixel = 0
    GearInput.Position = UDim2.new(0, 5, 0, 30)
    GearInput.Size = UDim2.new(0.7, -10, 0, 25)
    GearInput.Font = Enum.Font.Gotham
    GearInput.PlaceholderText = "Enter Gear ID..."
    GearInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    GearInput.TextSize = 8

    local LoadCustomButton = Instance.new("TextButton")
    LoadCustomButton.Parent = GearFrame
    LoadCustomButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    LoadCustomButton.BorderSizePixel = 0
    LoadCustomButton.Position = UDim2.new(0.7, 0, 0, 30)
    LoadCustomButton.Size = UDim2.new(0.3, -5, 0, 25)
    LoadCustomButton.Font = Enum.Font.GothamBold
    LoadCustomButton.Text = "LOAD"
    LoadCustomButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    LoadCustomButton.TextSize = 8

    GearScrollFrame = Instance.new("ScrollingFrame")
    GearScrollFrame.Parent = GearFrame
    GearScrollFrame.BackgroundTransparency = 1
    GearScrollFrame.Position = UDim2.new(0, 5, 0, 60)
    GearScrollFrame.Size = UDim2.new(1, -10, 1, -65)
    GearScrollFrame.ScrollBarThickness = 3
    GearScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
    GearScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    GearLayout = Instance.new("UIListLayout")
    GearLayout.Parent = GearScrollFrame
    GearLayout.Padding = UDim.new(0, 3)

    -- Event connections
    CloseGearButton.MouseButton1Click:Connect(function()
        GearFrame.Visible = false
        gearFrameVisible = false
    end)

    LoadCustomButton.MouseButton1Click:Connect(function()
        local id = tonumber(GearInput.Text)
        if id then
            loadGear(id)
            GearInput.Text = ""
        else
            warn("[SUPERTOOL] Invalid Gear ID")
        end
    end)

    -- Populate predefined gears
    for _, gear in ipairs(predefinedGears) do
        local gearItem = Instance.new("TextButton")
        gearItem.Parent = GearScrollFrame
        gearItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        gearItem.Size = UDim2.new(1, 0, 0, 25)
        gearItem.Text = gear.name .. " (ID: " .. gear.id .. ")"
        gearItem.TextColor3 = Color3.fromRGB(255, 255, 255)
        gearItem.TextSize = 8
        gearItem.Font = Enum.Font.Gotham

        gearItem.MouseButton1Click:Connect(function()
            loadGear(gear.id)
        end)
    end

    GearScrollFrame.CanvasSize = UDim2.new(0, 0, 0, GearLayout.AbsoluteContentSize.Y + 10)
end

local function toggleGearManager()
    if not GearFrame then initGearUI() end
    gearFrameVisible = not gearFrameVisible
    GearFrame.Visible = gearFrameVisible
end

-- New Object Spawner Functions
local function spawnObject(id)
    local success, err = pcall(function()
        local assets = game:GetObjects("rbxassetid://" .. id)
        local obj = assets[1]
        if obj then
            obj.Parent = workspace
            print("[SUPERTOOL] Spawned object: " .. obj.Name)
        end
    end)
    if not success then
        warn("[SUPERTOOL] Object spawn failed: " .. tostring(err))
    end
end

local function initObjectUI()
    if ObjectFrame then return end
    
    ObjectFrame = Instance.new("Frame")
    ObjectFrame.Name = "ObjectFrame"
    ObjectFrame.Parent = ScreenGui
    ObjectFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    ObjectFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    ObjectFrame.BorderSizePixel = 1
    ObjectFrame.Position = UDim2.new(0.5, 0, 0.2, 0)
    ObjectFrame.Size = UDim2.new(0, 250, 0, 300)
    ObjectFrame.Visible = false
    ObjectFrame.Active = true
    ObjectFrame.Draggable = true

    local ObjectTitle = Instance.new("TextLabel")
    ObjectTitle.Parent = ObjectFrame
    ObjectTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    ObjectTitle.BorderSizePixel = 0
    ObjectTitle.Size = UDim2.new(1, 0, 0, 25)
    ObjectTitle.Font = Enum.Font.GothamBold
    ObjectTitle.Text = "OBJECT SPAWNER"
    ObjectTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    ObjectTitle.TextSize = 10

    local CloseObjectButton = Instance.new("TextButton")
    CloseObjectButton.Parent = ObjectFrame
    CloseObjectButton.BackgroundTransparency = 1
    CloseObjectButton.Position = UDim2.new(1, -25, 0, 2)
    CloseObjectButton.Size = UDim2.new(0, 20, 0, 20)
    CloseObjectButton.Font = Enum.Font.GothamBold
    CloseObjectButton.Text = "X"
    CloseObjectButton.TextColor3 = Color3.fromRGB(255, 100, 100)
    CloseObjectButton.TextSize = 12

    ObjectInput = Instance.new("TextBox")
    ObjectInput.Parent = ObjectFrame
    ObjectInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    ObjectInput.BorderSizePixel = 0
    ObjectInput.Position = UDim2.new(0, 5, 0, 30)
    ObjectInput.Size = UDim2.new(0.7, -10, 0, 25)
    ObjectInput.Font = Enum.Font.Gotham
    ObjectInput.PlaceholderText = "Enter Object ID..."
    ObjectInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    ObjectInput.TextSize = 8

    local SpawnCustomButton = Instance.new("TextButton")
    SpawnCustomButton.Parent = ObjectFrame
    SpawnCustomButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    SpawnCustomButton.BorderSizePixel = 0
    SpawnCustomButton.Position = UDim2.new(0.7, 0, 0, 30)
    SpawnCustomButton.Size = UDim2.new(0.3, -5, 0, 25)
    SpawnCustomButton.Font = Enum.Font.GothamBold
    SpawnCustomButton.Text = "SPAWN"
    SpawnCustomButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SpawnCustomButton.TextSize = 8

    ObjectScrollFrame = Instance.new("ScrollingFrame")
    ObjectScrollFrame.Parent = ObjectFrame
    ObjectScrollFrame.BackgroundTransparency = 1
    ObjectScrollFrame.Position = UDim2.new(0, 5, 0, 60)
    ObjectScrollFrame.Size = UDim2.new(1, -10, 1, -65)
    ObjectScrollFrame.ScrollBarThickness = 3
    ObjectScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
    ObjectScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    ObjectLayout = Instance.new("UIListLayout")
    ObjectLayout.Parent = ObjectScrollFrame
    ObjectLayout.Padding = UDim.new(0, 3)

    -- Event connections
    CloseObjectButton.MouseButton1Click:Connect(function()
        ObjectFrame.Visible = false
        objectFrameVisible = false
    end)

    SpawnCustomButton.MouseButton1Click:Connect(function()
        local id = tonumber(ObjectInput.Text)
        if id then
            spawnObject(id)
            ObjectInput.Text = ""
        else
            warn("[SUPERTOOL] Invalid Object ID")
        end
    end)

    -- Populate predefined objects
    for _, obj in ipairs(predefinedObjects) do
        local objItem = Instance.new("TextButton")
        objItem.Parent = ObjectScrollFrame
        objItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        objItem.Size = UDim2.new(1, 0, 0, 25)
        objItem.Text = obj.name .. " (ID: " .. obj.id .. ")"
        objItem.TextColor3 = Color3.fromRGB(255, 255, 255)
        objItem.TextSize = 8
        objItem.Font = Enum.Font.Gotham

        objItem.MouseButton1Click:Connect(function()
            spawnObject(obj.id)
        end)
    end

    ObjectScrollFrame.CanvasSize = UDim2.new(0, 0, 0, ObjectLayout.AbsoluteContentSize.Y + 10)
end

local function toggleObjectSpawner()
    if not ObjectFrame then initObjectUI() end
    objectFrameVisible = not objectFrameVisible
    ObjectFrame.Visible = objectFrameVisible
end

local function applyMessageMods(message)
    if rainbowChat then
        local rainbowStr = ""
        local hue = 0
        local step = 1 / #message
        for i = 1, #message do
            local char = message:sub(i, i)
            local color = Color3.fromHSV(hue, 1, 1)
            rainbowStr = rainbowStr .. string.format('<font color="rgb(%d,%d,%d)">%s</font>', math.floor(color.R*255), math.floor(color.G*255), math.floor(color.B*255), char)
            hue = (hue + step) % 1
        end
        message = rainbowStr
    elseif customChatColor then
        message = string.format('<font color="rgb(%d,%d,%d)">%s</font>', math.floor(customChatColor.R*255), math.floor(customChatColor.G*255), math.floor(customChatColor.B*255), message)
    end
    if customChatFont then
        message = string.format('<font face="%s">%s</font>', customChatFont.Name, message)
    end
    return message
end

local function setupChatCustom()
    local success, err = pcall(function()
        local chatGui = player.PlayerGui:WaitForChild("Chat", 10)
        if not chatGui then return end
        -- Get chat bar
        local chatBar = chatGui.Frame.ChatBarParentFrame.Frame.BoxFrame.BackgroundFrame.TextBox
        -- Get say request
        local rs = game:GetService("ReplicatedStorage")
        local chatEventsFolder = rs:WaitForChild("DefaultChatSystemChatEvents")
        sayMessageRequest = chatEventsFolder:WaitForChild("SayMessageRequest")
        -- Hook focus lost
        chatBar.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local msg = chatBar.Text
                chatBar.Text = ""
                if #msg > 0 then
                    local modMsg = applyMessageMods(msg)
                    sayMessageRequest:FireServer(modMsg, "All")
                end
            end
        end)
        -- For name tag
        local messageLog = chatGui.Frame.ChatChannelParentFrame.Frame_MessageLogDisplay.Scroller
        local ourDisplayName = player.DisplayName
        local ourUsername = player.Name
        messageLog.ChildAdded:Connect(function(child)
            task.wait(0.1)
            for _, desc in pairs(child:GetDescendants()) do
                if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                    local text = desc.Text
                    local baseName
                    if text:find(ourDisplayName .. ": ") then
                        baseName = ourDisplayName
                    elseif text:find(ourUsername .. ": ") then
                        baseName = ourUsername
                    end
                    if baseName then
                        local tagged
                        if tagPosition == "front" then
                            tagged = nameTag .. baseName
                        elseif tagPosition == "back" then
                            tagged = baseName .. nameTag
                        else  -- middle
                            local half = math.floor(#baseName / 2)
                            tagged = baseName:sub(1, half) .. nameTag .. baseName:sub(half + 1)
                        end
                        desc.Text = text:gsub(baseName, tagged, 1)
                    end
                end
            end
        end)
    end)
    if not success then
        warn("[SUPERTOOL] Chat setup failed: " .. err)
    end
end

local function initChatUI()
    if ChatFrame then return end
    ChatFrame = Instance.new("Frame")
    ChatFrame.Name = "ChatFrame"
    ChatFrame.Parent = ScreenGui
    ChatFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    ChatFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    ChatFrame.BorderSizePixel = 1
    ChatFrame.Position = UDim2.new(0.5, 0, 0.2, 0)
    ChatFrame.Size = UDim2.new(0, 250, 0, 300)
    ChatFrame.Visible = false
    ChatFrame.Active = true
    ChatFrame.Draggable = true

    local title = Instance.new("TextLabel")
    title.Parent = ChatFrame
    title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    title.BorderSizePixel = 0
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Font = Enum.Font.GothamBold
    title.Text = "CHAT CUSTOMIZER"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 10

    local closeBtn = Instance.new("TextButton")
    closeBtn.Parent = ChatFrame
    closeBtn.BackgroundTransparency = 1
    closeBtn.Position = UDim2.new(1, -25, 0, 2)
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.TextSize = 12
    closeBtn.MouseButton1Click:Connect(function()
        ChatFrame.Visible = false
        chatFrameVisible = false
    end)

    -- Tag input
    local tagLabel = Instance.new("TextLabel")
    tagLabel.Parent = ChatFrame
    tagLabel.Position = UDim2.new(0, 5, 0, 30)
    tagLabel.Size = UDim2.new(0.4, 0, 0, 25)
    tagLabel.BackgroundTransparency = 1
    tagLabel.Text = "Name Tag:"
    tagLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    tagLabel.TextSize = 10
    tagLabel.Font = Enum.Font.Gotham

    ChatInputTag = Instance.new("TextBox")
    ChatInputTag.Parent = ChatFrame
    ChatInputTag.Position = UDim2.new(0.4, 0, 0, 30)
    ChatInputTag.Size = UDim2.new(0.6, -5, 0, 25)
    ChatInputTag.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    ChatInputTag.Text = nameTag
    ChatInputTag.TextColor3 = Color3.fromRGB(255, 255, 255)
    ChatInputTag.Font = Enum.Font.Gotham
    ChatInputTag.TextSize = 10
    ChatInputTag.FocusLost:Connect(function()
        nameTag = ChatInputTag.Text
    end)

    -- Position toggle
    local posLabel = Instance.new("TextLabel")
    posLabel.Parent = ChatFrame
    posLabel.Position = UDim2.new(0, 5, 0, 60)
    posLabel.Size = UDim2.new(0.4, 0, 0, 25)
    posLabel.BackgroundTransparency = 1
    posLabel.Text = "Tag Position:"
    posLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    posLabel.TextSize = 10
    posLabel.Font = Enum.Font.Gotham

    ChatPositionToggle = Instance.new("TextButton")
    ChatPositionToggle.Parent = ChatFrame
    ChatPositionToggle.Position = UDim2.new(0.4, 0, 0, 60)
    ChatPositionToggle.Size = UDim2.new(0.6, -5, 0, 25)
    ChatPositionToggle.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
    ChatPositionToggle.Text = tagPosition:upper()
    ChatPositionToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    ChatPositionToggle.Font = Enum.Font.Gotham
    ChatPositionToggle.TextSize = 10
    ChatPositionToggle.MouseButton1Click:Connect(function()
        if tagPosition == "front" then
            tagPosition = "middle"
        elseif tagPosition == "middle" then
            tagPosition = "back"
        else
            tagPosition = "front"
        end
        ChatPositionToggle.Text = tagPosition:upper()
    end)

    -- Rainbow toggle
    RainbowToggle = Instance.new("TextButton")
    RainbowToggle.Parent = ChatFrame
    RainbowToggle.Position = UDim2.new(0, 5, 0, 90)
    RainbowToggle.Size = UDim2.new(1, -10, 0, 25)
    RainbowToggle.BackgroundColor3 = rainbowChat and Color3.fromRGB(60, 120, 60) or Color3.fromRGB(150, 50, 50)
    RainbowToggle.Text = "Rainbow Chat: " .. (rainbowChat and "ON" or "OFF")
    RainbowToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    RainbowToggle.Font = Enum.Font.Gotham
    RainbowToggle.TextSize = 10
    RainbowToggle.MouseButton1Click:Connect(function()
        rainbowChat = not rainbowChat
        RainbowToggle.Text = "Rainbow Chat: " .. (rainbowChat and "ON" or "OFF")
        RainbowToggle.BackgroundColor3 = rainbowChat and Color3.fromRGB(60, 120, 60) or Color3.fromRGB(150, 50, 50)
    end)

    -- Custom color
    local colorLabel = Instance.new("TextLabel")
    colorLabel.Parent = ChatFrame
    colorLabel.Position = UDim2.new(0, 5, 0, 120)
    colorLabel.Size = UDim2.new(0.4, 0, 0, 25)
    colorLabel.BackgroundTransparency = 1
    colorLabel.Text = "Custom Color (HEX):"
    colorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    colorLabel.TextSize = 10
    colorLabel.Font = Enum.Font.Gotham

    ColorInput = Instance.new("TextBox")
    ColorInput.Parent = ChatFrame
    ColorInput.Position = UDim2.new(0.4, 0, 0, 120)
    ColorInput.Size = UDim2.new(0.6, -5, 0, 25)
    ColorInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    ColorInput.PlaceholderText = "#RRGGBB or empty to disable"
    ColorInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    ColorInput.Font = Enum.Font.Gotham
    ColorInput.TextSize = 10
    ColorInput.FocusLost:Connect(function()
        if ColorInput.Text == "" then
            customChatColor = nil
            return
        end
        local r, g, b = ColorInput.Text:match("#?(%x%x)(%x%x)(%x%x)")
        if r and g and b then
            customChatColor = Color3.fromRGB(tonumber(r,16), tonumber(g,16), tonumber(b,16))
        else
            customChatColor = nil
        end
    end)

    -- Custom font
    local fontLabel = Instance.new("TextLabel")
    fontLabel.Parent = ChatFrame
    fontLabel.Position = UDim2.new(0, 5, 0, 150)
    fontLabel.Size = UDim2.new(0.4, 0, 0, 25)
    fontLabel.BackgroundTransparency = 1
    fontLabel.Text = "Custom Font:"
    fontLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    fontLabel.TextSize = 10
    fontLabel.Font = Enum.Font.Gotham

    FontInput = Instance.new("TextBox")
    FontInput.Parent = ChatFrame
    FontInput.Position = UDim2.new(0.4, 0, 0, 150)
    FontInput.Size = UDim2.new(0.6, -5, 0, 25)
    FontInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    FontInput.PlaceholderText = "Gotham, Arial, etc or empty"
    FontInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    FontInput.Font = Enum.Font.Gotham
    FontInput.TextSize = 10
    FontInput.FocusLost:Connect(function()
        if FontInput.Text == "" then
            customChatFont = nil
        else
            if Enum.Font[FontInput.Text] then
                customChatFont = Enum.Font[FontInput.Text]
            else
                customChatFont = nil
            end
        end
    end)
end

local function toggleChatCustomizer()
    if not ChatFrame then initChatUI() end
    chatFrameVisible = not chatFrameVisible
    ChatFrame.Visible = chatFrameVisible
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
    createButton("Toggle Object Editor", toggleEditor)
    createButton("Editor History", toggleEditorList)
    createButton("Gear Manager", toggleGearManager)
    createButton("Object Spawner", toggleObjectSpawner)
    createButton("Chat Customizer", toggleChatCustomizer)
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
        if not isfolder(OBJECT_EDITOR_FOLDER) then
            makefolder(OBJECT_EDITOR_FOLDER)
        end
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to create folder structure")
    end
    
    -- FIXED: Load all existing files on initialization
    local pathCount = loadAllSavedPaths()
    print("[SUPERTOOL] Initialization complete - Paths loaded: " .. pathCount)
    
    setupKeyboardControls()
    setupEditorInput()
    setupChatCustom()
    
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
                    loadObjectEdits()
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
        initEditorListUI()
        initCopyListUI()
        initGearUI()
        initObjectUI()
        initChatUI()
        print("[SUPERTOOL] Enhanced Path Utility v2.0 initialized (Enhanced Object Editor with fixes)")
    end)
    
    -- Reapply edits every 5 seconds to persist against server changes
    RunService:BindToRenderStep("ReapplyEdits", Enum.RenderPriority.Last.Value, function()
        if tick() % 5 == 0 then
            loadObjectEdits()
        end
    end)
end

return Utility