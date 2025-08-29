-- Enhanced Path-only Utility for MinimalHackGUI by Fari Noveri
-- PERFORMANCE OPTIMIZED VERSION
-- FIXED: Major lag issues during path visualization
-- OPTIMIZED: Reduced visual part creation by 80%
-- OPTIMIZED: Smart visual culling and batching
-- OPTIMIZED: Efficient path rendering system

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
local currentPlayingPath = nil
local pathPauseIndex = 1
local lastPathTime = 0
local pathVisualParts = {}
local pathMarkerParts = {}
local pathEffectParts = {}
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

-- PERFORMANCE OPTIMIZATION CONSTANTS
local MAX_VISUAL_PARTS = 50 -- Limit visual parts to prevent lag
local VISUAL_DISTANCE_THRESHOLD = 100 -- Only show visuals within 100 studs
local PATH_SIMPLIFICATION_FACTOR = 5 -- Show every 5th point only
local UPDATE_FREQUENCY = 0.1 -- Update visuals every 0.1 seconds instead of every frame

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
local MARKER_DISTANCE = 10 -- Increased from 5 to reduce markers
local CLICKABLE_RADIUS = 8 -- Increased radius but fewer points

-- Movement colors
local movementColors = {
    swimming = Color3.fromRGB(128, 0, 128),
    jumping = Color3.fromRGB(255, 0, 0),
    falling = Color3.fromRGB(255, 255, 0),
    walking = Color3.fromRGB(0, 255, 0),
    idle = Color3.fromRGB(200, 200, 200),
    paused = Color3.fromRGB(255, 255, 255)
}

-- PERFORMANCE: Visual parts pooling system
local visualPartsPool = {}
local function getPooledPart()
    if #visualPartsPool > 0 then
        return table.remove(visualPartsPool)
    else
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Material = Enum.Material.SmoothPlastic
        return part
    end
end

local function returnToPool(part)
    if part and part.Parent then
        part.Parent = nil
        -- Clear any children
        for _, child in pairs(part:GetChildren()) do
            if child:IsA("BillboardGui") or child:IsA("ClickDetector") then
                child:Destroy()
            end
        end
        table.insert(visualPartsPool, part)
    end
end

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

-- OPTIMIZED: Simplified visual effects (no more lag-causing animations)
local function createPathEffect(position, movementType)
    -- Skip effects during path showing to reduce lag
    if pathShowOnly then return end
    
    local color = getColorFromType(movementType)
    
    -- Simple static glow part without animations
    local glowPart = getPooledPart()
    glowPart.Name = "PathGlow"
    glowPart.Parent = workspace
    glowPart.Material = Enum.Material.Neon
    glowPart.Color = color
    glowPart.Transparency = 0.7
    glowPart.Size = Vector3.new(0.8, 0.8, 0.8)
    glowPart.Shape = Enum.PartType.Ball
    glowPart.CFrame = CFrame.new(position)
    
    table.insert(pathEffectParts, glowPart)
    return glowPart
end

-- OPTIMIZED: Distance-based and simplified path visualization
local function createPathVisual(position, movementType, isMarker, idleDuration, isClickable)
    -- PERFORMANCE: Check distance from player to reduce visual load
    if rootPart and (position - rootPart.Position).Magnitude > VISUAL_DISTANCE_THRESHOLD then
        return nil -- Don't create distant visuals
    end
    
    local color = getColorFromType(movementType)
    local part = getPooledPart()
    part.Name = isMarker and "PathMarker" or (isClickable and "ClickablePathPoint" or "PathPoint")
    part.Parent = workspace
    part.Color = color
    part.Transparency = isMarker and 0.4 or (isClickable and 0.5 or 0.7) -- More transparent to reduce visual noise
    part.Size = isMarker and Vector3.new(1.2, 1.2, 1.2) or (isClickable and Vector3.new(1, 1, 1) or Vector3.new(0.6, 0.6, 0.6))
    part.Shape = isMarker and Enum.PartType.Ball or Enum.PartType.Block
    part.CFrame = CFrame.new(position)
    
    -- OPTIMIZED: Only add effects to markers and clickable points
    if not isMarker and not isClickable then
        -- Skip effects for regular path points
    elseif isClickable then
        createPathEffect(position, movementType)
    end
    
    if isClickable then
        local detector = Instance.new("ClickDetector")
        detector.Parent = part
        detector.MaxActivationDistance = 30 -- Reduced from 50
        
        detector.MouseClick:Connect(function(clickingPlayer)
            if not currentPlayingPath or not currentPlayingPath.points then return end
            
            -- Find the closest point in the currently playing path
            local closestIndex = 1
            local closestDistance = math.huge
            
            for i, point in pairs(currentPlayingPath.points) do
                local distance = (position - point.position).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closestIndex = i
                end
            end
            
            -- Clear any existing billboard from this part
            for _, child in pairs(part:GetChildren()) do
                if child:IsA("BillboardGui") then
                    child:Destroy()
                end
            end
            
            -- Create "Start From Here" label
            local billboard = Instance.new("BillboardGui")
            billboard.Parent = part
            billboard.Size = UDim2.new(0, 100, 0, 30)
            billboard.StudsOffset = Vector3.new(0, 2, 0)
            billboard.AlwaysOnTop = true
            
            local textLabel = Instance.new("TextLabel")
            textLabel.Parent = billboard
            textLabel.Size = UDim2.new(1, 0, 1, 0)
            textLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            textLabel.BackgroundTransparency = 0.3
            textLabel.BorderSizePixel = 0
            textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            textLabel.TextStrokeTransparency = 0.5
            textLabel.TextSize = 10
            textLabel.Font = Enum.Font.GothamBold
            textLabel.Text = "START HERE"
            
            -- Auto-fade after 3 seconds (reduced from 5)
            task.spawn(function()
                task.wait(3)
                if billboard and billboard.Parent then
                    billboard:Destroy()
                end
            end)
            
            pathPauseIndex = closestIndex
            print("[SUPERTOOL] Path playback will start from index " .. closestIndex)
            
            if pathPlaying and currentPathName then
                stopPathPlayback()
                task.wait(0.1)
                playPath(currentPathName, false, pathAutoPlaying, pathAutoRespawning)
            end
        end)
    end
    
    -- OPTIMIZED: Simplified idle duration labels
    if isMarker and movementType == "idle" and idleDuration and idleDuration > 2 then
        local billboard = Instance.new("BillboardGui")
        billboard.Parent = part
        billboard.Size = UDim2.new(0, 80, 0, 25)
        billboard.StudsOffset = Vector3.new(0, 1.5, 0)
        billboard.AlwaysOnTop = false
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Parent = billboard
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.TextStrokeTransparency = 0.7
        textLabel.TextSize = 10
        textLabel.Font = Enum.Font.Gotham
        textLabel.Text = idleDuration >= 60 and 
            string.format("%.0fm", idleDuration/60) or 
            string.format("%.0fs", idleDuration)
    end
    
    return part
end

-- OPTIMIZED: Efficient visual clearing with pooling
local function clearPathVisuals()
    -- Return all parts to pool instead of destroying them
    for _, part in pairs(pathVisualParts) do
        returnToPool(part)
    end
    for _, part in pairs(pathMarkerParts) do
        returnToPool(part)
    end
    for _, part in pairs(pathEffectParts) do
        returnToPool(part)
    end
    pathVisualParts = {}
    pathMarkerParts = {}
    pathEffectParts = {}
    
    -- Clear paused here label
    if pausedHereLabel and pausedHereLabel.Parent then
        returnToPool(pausedHereLabel)
        pausedHereLabel = nil
    end
end

local function createPausedHereMarker(position)
    if pausedHereLabel and pausedHereLabel.Parent then
        returnToPool(pausedHereLabel)
    end
    
    pausedHereLabel = getPooledPart()
    pausedHereLabel.Name = "PausedHereMarker"
    pausedHereLabel.Parent = workspace
    pausedHereLabel.Color = movementColors.paused
    pausedHereLabel.Transparency = 0.3
    pausedHereLabel.Size = Vector3.new(1.2, 1.2, 1.2)
    pausedHereLabel.Shape = Enum.PartType.Ball
    pausedHereLabel.CFrame = CFrame.new(position)
    
    local billboard = Instance.new("BillboardGui")
    billboard.Parent = pausedHereLabel
    billboard.Size = UDim2.new(0, 100, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.AlwaysOnTop = false
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Parent = billboard
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.BackgroundTransparency = 0.4
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextStrokeTransparency = 0.7
    textLabel.TextSize = 10
    textLabel.Font = Enum.Font.GothamBold
    textLabel.Text = "PAUSED"
end

-- OPTIMIZED: Efficient visibility toggle
local function togglePathVisibility()
    pathVisualsVisible = not pathVisualsVisible
    
    local transparency = pathVisualsVisible and 0.5 or 1
    
    -- Batch update all visuals
    local allParts = {}
    for _, part in pairs(pathVisualParts) do table.insert(allParts, part) end
    for _, part in pairs(pathMarkerParts) do table.insert(allParts, part) end
    for _, part in pairs(pathEffectParts) do table.insert(allParts, part) end
    
    for _, part in pairs(allParts) do
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

-- OPTIMIZED: Path Recording with reduced visual creation
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
    
    print("[SUPERTOOL] Path recording started (optimized mode)")
    updatePathStatus()
    
    local previousMovementType = nil
    local lastVisualTime = 0
    
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
        
        -- OPTIMIZED: Only create visuals every UPDATE_FREQUENCY seconds and limit count
        if currentTime - lastVisualTime >= UPDATE_FREQUENCY and #pathVisualParts < MAX_VISUAL_PARTS then
            local visualPart = createPathVisual(position, movementType, false)
            if visualPart then
                table.insert(pathVisualParts, visualPart)
            end
            lastVisualTime = currentTime
        end
        
        -- Handle idle detection (unchanged but optimized)
        if movementType == "idle" then
            if previousMovementType ~= "idle" then
                idleStartTime = currentTime
                idleStartPosition = position
                currentIdleLabel = createPathVisual(position, movementType, true, 0)
                if currentIdleLabel then
                    table.insert(pathMarkerParts, currentIdleLabel)
                end
            end
            if currentIdleLabel and currentTime - idleStartTime > 1 then -- Only update if idle for more than 1 second
                local duration = currentTime - idleStartTime
                local label = currentIdleLabel:FindFirstChildOfClass("BillboardGui")
                if label then
                    local textLabel = label:FindFirstChild("TextLabel")
                    if textLabel then
                        textLabel.Text = duration >= 60 and 
                            string.format("%.0fm", duration/60) or 
                            string.format("%.0fs", duration)
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
        
        -- OPTIMIZED: Create fewer markers (increased distance threshold)
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
            if markerPart then
                table.insert(pathMarkerParts, markerPart)
            end
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

-- OPTIMIZED: Efficient path playback with smart visual loading
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
    
    currentPlayingPath = {
        name = path.name,
        points = {},
        markers = path.markers or {},
        created = path.created,
        pointCount = path.pointCount,
        markerCount = path.markerCount,
        duration = path.duration,
        speed = path.speed or 1
    }
    
    -- Deep copy the points
    for i, point in pairs(path.points) do
        table.insert(currentPlayingPath.points, {
            time = point.time,
            position = point.position,
            cframe = point.cframe,
            velocity = point.velocity,
            movementType = point.movementType,
            walkSpeed = point.walkSpeed,
            jumpPower = point.jumpPower
        })
    end
    
    pathPlaying = true
    pathShowOnly = showOnly or false
    pathAutoPlaying = autoPlay or false
    pathAutoRespawning = respawn or false
    currentPathName = pathName
    pathPaused = false
    playbackStartTime = tick()
    playbackPauseTime = 0
    playbackOffsetTime = currentPlayingPath.points[pathPauseIndex] and currentPlayingPath.points[pathPauseIndex].time or 0
    
    clearPathVisuals()
    
    -- OPTIMIZED: Smart visual creation with distance culling and simplification
    print("[SUPERTOOL] Creating optimized path visuals...")
    
    -- Create simplified path visuals (every Nth point based on PATH_SIMPLIFICATION_FACTOR)
    local visualCount = 0
    local playerPos = rootPart and rootPart.Position or Vector3.new(0, 0, 0)
    
    for i = 1, #currentPlayingPath.points, PATH_SIMPLIFICATION_FACTOR do
        if visualCount >= MAX_VISUAL_PARTS then break end
        
        local point = currentPlayingPath.points[i]
        local distance = (point.position - playerPos).Magnitude
        
        -- Only create visuals for nearby points
        if distance <= VISUAL_DISTANCE_THRESHOLD then
            local visualPart = createPathVisual(point.position, point.movementType, false)
            if visualPart then
                table.insert(pathVisualParts, visualPart)
                visualCount = visualCount + 1
            end
        end
    end
    
    -- Add clickable points every CLICKABLE_RADIUS meters (but limit total)
    local clickableCount = 0
    local lastClickablePosition = nil
    for i, point in pairs(currentPlayingPath.points) do
        if clickableCount >= 20 then break end -- Limit clickable points
        
        local distance = playerPos and (point.position - playerPos).Magnitude or 0
        if distance <= VISUAL_DISTANCE_THRESHOLD then
            if not lastClickablePosition or (point.position - lastClickablePosition).Magnitude >= CLICKABLE_RADIUS then
                local clickablePart = createPathVisual(point.position, point.movementType, false, nil, true)
                if clickablePart then
                    table.insert(pathMarkerParts, clickablePart)
                    lastClickablePosition = point.position
                    clickableCount = clickableCount + 1
                end
            end
        end
    end
    
    -- Add important markers only
    for i, marker in pairs(currentPlayingPath.markers or {}) do
        local distance = playerPos and (marker.position - playerPos).Magnitude or 0
        if distance <= VISUAL_DISTANCE_THRESHOLD then
            local markerPart = createPathVisual(marker.position, marker.movementType or "marker", true, marker.idleDuration)
            if markerPart then
                table.insert(pathMarkerParts, markerPart)
            end
        end
    end
    
    updatePathStatus()
    
    print("[SUPERTOOL] Path visuals created: " .. #pathVisualParts .. " path points, " .. #pathMarkerParts .. " markers/clickables")
    
    if pathShowOnly then
        print("[SUPERTOOL] Showing optimized path: " .. pathName)
        return
    end
    
    print("[SUPERTOOL] Playing path: " .. pathName)
    
    local index = pathPauseIndex
    
    pathPlayConnection = RunService.Heartbeat:Connect(function()
        if not pathPlaying or pathPaused then return end
        
        if not updateCharacterReferences() then return end
        
        if index > #currentPlayingPath.points then
            if pathAutoPlaying then
                if pathAutoRespawning then
                    resetCharacter()
                    task.spawn(function()
                        task.wait(5)
                        if pathPlaying and pathAutoPlaying and pathAutoRespawning then
                            index = 1
                            pathPauseIndex = 1
                            playbackOffsetTime = currentPlayingPath.points[1].time or 0
                            playbackStartTime = tick()
                            playbackPauseTime = 0
                        end
                    end)
                    return
                else
                    index = 1
                    pathPauseIndex = 1
                    playbackOffsetTime = currentPlayingPath.points[1].time or 0
                    playbackStartTime = tick()
                    playbackPauseTime = 0
                end
            else
                print("[SUPERTOOL] Path playback completed")
                stopPathPlayback()
                return
            end
        end
        
        local point = currentPlayingPath.points[index]
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
        currentPlayingPath = nil
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
    currentPlayingPath = nil
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
        returnToPool(pausedHereLabel)
        pausedHereLabel = nil
    end
    
    updatePathList()
    updatePathStatus()
    print("[SUPERTOOL] Path playback stopped")
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
            returnToPool(pausedHereLabel)
            pausedHereLabel = nil
        end
        playbackStartTime = tick()
    end
    
    updatePathStatus()
end

-- OPTIMIZED: Undo system with efficient visual updates
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
        
        -- OPTIMIZED: Clear and recreate visuals efficiently
        clearPathVisuals()
        
        -- Recreate simplified visuals
        local visualCount = 0
        for i = 1, #currentPath.points, PATH_SIMPLIFICATION_FACTOR do
            if visualCount >= MAX_VISUAL_PARTS then break end
            local point = currentPath.points[i]
            local visualPart = createPathVisual(point.position, point.movementType, false)
            if visualPart then
                table.insert(pathVisualParts, visualPart)
                visualCount = visualCount + 1
            end
        end
        
        for i, marker in pairs(currentPath.markers) do
            local markerPart = createPathVisual(marker.position, marker.movementType or "marker", true, marker.idleDuration)
            if markerPart then
                table.insert(pathMarkerParts, markerPart)
            end
        end
        
        -- Create undo marker
        local undoMarker = createPathVisual(lastMarker.position, "paused", true)
        if undoMarker then
            table.insert(pathMarkerParts, undoMarker)
        end
    end
end

-- OPTIMIZED: Load paths function with progress feedback
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

-- Status Update Functions
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

-- File system functions (unchanged but optimized)
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

-- OPTIMIZED: UI Components with performance improvements
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
    PathTitle.Text = "PATH CREATOR v3.0 - OPTIMIZED EDITION"
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
    PathPauseButton.Size = UDim2.new(0, 60, 0, 25)
    PathPauseButton.Font = Enum.Font.GothamBold
    PathPauseButton.Text = "PAUSE"
    PathPauseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    PathPauseButton.TextSize = 8

    local ClearVisualsButton = Instance.new("TextButton")
    ClearVisualsButton.Parent = PathControlsFrame
    ClearVisualsButton.BackgroundColor3 = Color3.fromRGB(80, 60, 60)
    ClearVisualsButton.BorderSizePixel = 0
    ClearVisualsButton.Position = UDim2.new(0, 70, 0, 2.5)
    ClearVisualsButton.Size = UDim2.new(0, 60, 0, 25)
    ClearVisualsButton.Font = Enum.Font.GothamBold
    ClearVisualsButton.Text = "CLEAR"
    ClearVisualsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClearVisualsButton.TextSize = 8

    local UndoButton = Instance.new("TextButton")
    UndoButton.Parent = PathControlsFrame
    UndoButton.BackgroundColor3 = Color3.fromRGB(60, 80, 80)
    UndoButton.BorderSizePixel = 0
    UndoButton.Position = UDim2.new(0, 135, 0, 2.5)
    UndoButton.Size = UDim2.new(0, 60, 0, 25)
    UndoButton.Font = Enum.Font.GothamBold
    UndoButton.Text = "UNDO"
    UndoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    UndoButton.TextSize = 8

    local ToggleVisualsButton = Instance.new("TextButton")
    ToggleVisualsButton.Parent = PathControlsFrame
    ToggleVisualsButton.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    ToggleVisualsButton.BorderSizePixel = 0
    ToggleVisualsButton.Position = UDim2.new(0, 200, 0, 2.5)
    ToggleVisualsButton.Size = UDim2.new(0, 60, 0, 25)
    ToggleVisualsButton.Font = Enum.Font.GothamBold
    ToggleVisualsButton.Text = "HIDE"
    ToggleVisualsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleVisualsButton.TextSize = 8

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
    ToggleVisualsButton.MouseButton1Click:Connect(togglePathVisibility)
    
    -- OPTIMIZED: Debounced search functionality
    local lastSearchTime = 0
    PathInput.Changed:Connect(function(property)
        if property == "Text" then
            lastSearchTime = tick()
            task.spawn(function()
                task.wait(0.3) -- Debounce search
                if tick() - lastSearchTime >= 0.25 then
                    updatePathList()
                end
            end)
        end
    end)
end

-- OPTIMIZED: Efficient path list updates with reduced GUI creation
function updatePathList()
    if not PathScrollFrame then return end
    
    -- Clear existing items efficiently
    for _, child in pairs(PathScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local searchText = PathInput.Text:lower()
    local itemCount = 0
    
    for pathName, path in pairs(savedPaths) do
        if searchText == "" or string.find(pathName:lower(), searchText) then
            itemCount = itemCount + 1
            if itemCount > 20 then -- Limit displayed items to prevent lag
                local moreLabel = Instance.new("TextLabel")
                moreLabel.Parent = PathScrollFrame
                moreLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                moreLabel.BorderSizePixel = 0
                moreLabel.Size = UDim2.new(1, -5, 0, 30)
                moreLabel.Font = Enum.Font.GothamBold
                moreLabel.Text = "... and " .. (table.getn(savedPaths) - 20) .. " more (refine search)"
                moreLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
                moreLabel.TextSize = 10
                break
            end
            
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
            
            -- Create buttons with proper event handling
            local function createPathButton(text, color, position, callback)
                local button = Instance.new("TextButton")
                button.Parent = pathItem
                button.Position = position
                button.Size = UDim2.new(0, 45, 0, 20)
                button.BackgroundColor3 = color
                button.TextColor3 = Color3.fromRGB(255, 255, 255)
                button.TextSize = 7
                button.Font = Enum.Font.GothamBold
                button.Text = text
                button.MouseButton1Click:Connect(callback)
                return button
            end
            
            -- Button row 1
            local playButton = createPathButton(
                (pathPlaying and currentPathName == pathName and not pathAutoPlaying) and "STOP" or "PLAY",
                Color3.fromRGB(60, 120, 60),
                UDim2.new(0, 5, 0, 38),
                function()
                    if pathPlaying and currentPathName == pathName and not pathAutoPlaying then
                        stopPathPlayback()
                    else
                        playPath(pathName, false, false, false)
                    end
                    task.wait(0.1)
                    updatePathList()
                end
            )
            
            local autoPlayButton = createPathButton(
                (pathPlaying and currentPathName == pathName and pathAutoPlaying and not pathAutoRespawning) and "STOP" or "LOOP",
                Color3.fromRGB(60, 100, 120),
                UDim2.new(0, 55, 0, 38),
                function()
                    if pathPlaying and currentPathName == pathName and pathAutoPlaying and not pathAutoRespawning then
                        stopPathPlayback()
                    else
                        playPath(pathName, false, true, false)
                    end
                    task.wait(0.1)
                    updatePathList()
                end
            )
            
            local autoRespButton = createPathButton(
                (pathPlaying and currentPathName == pathName and pathAutoPlaying and pathAutoRespawning) and "STOP" or "A-RESP",
                Color3.fromRGB(120, 60, 100),
                UDim2.new(0, 105, 0, 38),
                function()
                    if pathPlaying and currentPathName == pathName and pathAutoPlaying and pathAutoRespawning then
                        stopPathPlayback()
                    else
                        playPath(pathName, false, true, true)
                    end
                    task.wait(0.1)
                    updatePathList()
                end
            )
            
            local toggleShowButton = createPathButton(
                (pathShowOnly and currentPathName == pathName) and "HIDE" or "SHOW",
                Color3.fromRGB(100, 100, 60),
                UDim2.new(0, 155, 0, 38),
                function()
                    togglePathVisuals(pathName)
                end
            )
            
            local deleteButton = createPathButton(
                "DELETE",
                Color3.fromRGB(150, 50, 50),
                UDim2.new(0, 205, 0, 38),
                function()
                    -- Cleanup and delete
                    if pathPlaying and currentPathName == pathName then
                        stopPathPlayback()
                    end
                    if pathShowOnly and currentPathName == pathName then
                        clearPathVisuals()
                        pathShowOnly = false
                        currentPathName = nil
                    end
                    
                    savedPaths[pathName] = nil
                    deletePathFromJSON(pathName)
                    updatePathList()
                    print("[SUPERTOOL] Path deleted: " .. pathName)
                end
            )
            
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
            
            local renameButton = createPathButton(
                "RENAME",
                Color3.fromRGB(50, 120, 50),
                UDim2.new(0, 160, 0, 65),
                function()
                    if renameInput.Text ~= "" then
                        local newName = renameInput.Text
                        if savedPaths[pathName] then
                            savedPaths[newName] = savedPaths[pathName]
                            savedPaths[pathName] = nil
                            
                            if pathPlaying and currentPathName == pathName then
                                currentPathName = newName
                            elseif pathShowOnly and currentPathName == pathName then
                                currentPathName = newName
                            end
                            
                            renamePathInJSON(pathName, newName)
                            renameInput.Text = ""
                            updatePathList()
                            print("[SUPERTOOL] Path renamed: " .. pathName .. " -> " .. newName)
                        end
                    end
                end
            )
            
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
            
            speedInput.FocusLost:Connect(function(enterPressed)
                if enterPressed then
                    local newSpeed = tonumber(speedInput.Text)
                    if newSpeed and newSpeed > 0 and newSpeed <= 10 then
                        path.speed = newSpeed
                        savePathToJSON(pathName, path)
                        print("[SUPERTOOL] Speed updated for " .. pathName .. ": " .. newSpeed)
                    else
                        speedInput.Text = tostring(path.speed or 1)
                    end
                end
            end)
        end
    end
    
    -- Update canvas size after a short delay
    task.spawn(function()
        task.wait(0.1)
        if PathLayout then
            PathScrollFrame.CanvasSize = UDim2.new(0, 0, 0, PathLayout.AbsoluteContentSize.Y + 10)
        end
    end)
end

-- OPTIMIZED: Keyboard Controls with reduced frequency
local function setupKeyboardControls()
    local lastKeyTime = {}
    
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        local currentTime = tick()
        local keyCode = input.KeyCode
        
        -- Debounce key presses
        if lastKeyTime[keyCode] and currentTime - lastKeyTime[keyCode] < DEBOUNCE_TIME then
            return
        end
        lastKeyTime[keyCode] = currentTime
        
        -- Ctrl+Z for undo during path recording
        if keyCode == Enum.KeyCode.Z and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            undoToLastMarker()
        end
        
        -- Ctrl+P for pause/resume
        if keyCode == Enum.KeyCode.P and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            pausePath()
        end
        
        -- Ctrl+L for hide/show path visuals
        if keyCode == Enum.KeyCode.L and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            togglePathVisibility()
        end
    end)
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
end

-- OPTIMIZED: Initialize function with performance monitoring
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
    
    -- Reset all states
    pathRecording = false
    pathPlaying = false
    pathShowOnly = false
    pathPaused = false
    pathAutoPlaying = false
    pathAutoRespawning = false
    currentPlayingPath = nil
    
    -- Initialize visual parts pool
    visualPartsPool = {}
    pathVisualParts = {}
    pathMarkerParts = {}
    pathEffectParts = {}
    
    -- Create folder structure
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
    
    -- Load existing paths
    local pathCount = loadAllSavedPaths()
    print("[SUPERTOOL] Initialization complete - Paths loaded: " .. pathCount)
    
    setupKeyboardControls()
    
    -- Character event handling
    if player then
        player.CharacterAdded:Connect(function(newCharacter)
            task.spawn(function()
                humanoid = newCharacter:WaitForChild("Humanoid", 30)
                rootPart = newCharacter:WaitForChild("HumanoidRootPart", 30)
                if humanoid and rootPart then
                    if pathRecording and pathPaused then
                        task.wait(3)
                        pathPaused = false
                        updatePathStatus()
                    end
                    if pathPlaying and currentPathName then
                        task.wait(3)
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
        print("[SUPERTOOL] Enhanced Path Utility v3.0 - PERFORMANCE OPTIMIZED")
        print("  ✅ FIXED: Major lag issues during path visualization")
        print("  ✅ OPTIMIZED: Reduced visual parts by up to 80%")
        print("  ✅ OPTIMIZED: Smart distance culling (100 studs max)")
        print("  ✅ OPTIMIZED: Visual parts pooling system")
        print("  ✅ OPTIMIZED: Path simplification (every 5th point)")
        print("  ✅ OPTIMIZED: Limited max visual parts to " .. MAX_VISUAL_PARTS)
        print("  ✅ OPTIMIZED: Efficient UI updates with debouncing")
        print("  ✅ OPTIMIZED: Reduced animation complexity")
        print("  - Performance Settings:")
        print("    • Max Visual Parts: " .. MAX_VISUAL_PARTS)
        print("    • Visual Distance: " .. VISUAL_DISTANCE_THRESHOLD .. " studs")
        print("    • Simplification Factor: " .. PATH_SIMPLIFICATION_FACTOR)
        print("    • Update Frequency: " .. UPDATE_FREQUENCY .. "s")
        print("  - Keyboard Controls:")
        print("    • Ctrl+Z: Undo during recording")
        print("    • Ctrl+P: Pause/Resume playback") 
        print("    • Ctrl+L: Hide/Show path visuals")
        print("  - JSON Storage: Supertool/Paths/")
        print("  - Features: Optimized rendering, smart culling, object pooling")
    end)
end

return Utility