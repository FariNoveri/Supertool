-- Enhanced Unified Macro-Path System for MinimalHackGUI by Fari Noveri
-- Version 3.0 - Unified GUI with advanced features and JSON sync

-- Dependencies: These must be passed from mainloader.lua
local Players, humanoid, rootPart, ScrollFrame, buttonStates, RunService, player, ScreenGui, settings

-- Initialize module
local Utility = {}

-- Unified System Variables
local isRecording = false
local isPlaying = false
local autoPlaying = false
local autoRespawning = false
local isPaused = false
local currentData = {}
local savedItems = {}
local frameVisible = false
local MainFrame, MainScrollFrame, MainLayout, MainInput, StatusLabel
local recordConnection = nil
local playbackConnection = nil
local currentItemName = nil
local recordingPaused = false
local lastFrameTime = 0
local pauseIndex = 1
local pauseTime = 0
local pauseResumeTime = 5 -- Seconds to wait before resuming after death
local currentRecordingType = "macro" -- "macro" or "path"

-- Path-specific variables
local pathVisualParts = {}
local pathMarkerParts = {}
local idleStartTime = nil
local currentIdleLabel = nil
local idleStartPosition = nil
local pauseMarker = nil

-- File System Integration
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SAVE_FOLDER_PATH = "Supertool/Macro/"

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
    idle = Color3.fromRGB(200, 200, 200),
    paused = Color3.fromRGB(255, 165, 0) -- Orange for pause marker
}

-- Helper function for sanitize filename
local function sanitizeFileName(name)
    local sanitized = string.gsub(name, "[<>:\"/\\|?*]", "_")
    sanitized = string.gsub(sanitized, "^%s*(.-)%s*$", "%1")
    if sanitized == "" then
        sanitized = "item_" .. os.time()
    end
    return sanitized
end

-- Generate random filename
local function generateRandomName(type)
    local prefixes = {
        macro = {"Swift", "Quick", "Auto", "Smooth", "Fast", "Pro"},
        path = {"Route", "Trail", "Journey", "Track", "Way", "Path"}
    }
    local suffixes = {"Alpha", "Beta", "Gamma", "Delta", "Prime", "Max", "Ultra", "Plus"}
    
    local prefix = prefixes[type][math.random(1, #prefixes[type])]
    local suffix = suffixes[math.random(1, #suffixes)]
    local number = math.random(100, 999)
    
    return prefix .. suffix .. number
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
local function createPathVisual(position, movementType, isMarker, idleDuration, isPauseMarker)
    local color = getColorFromType(movementType)
    if isPauseMarker then
        color = movementColors.paused
    end
    
    local part = Instance.new("Part")
    part.Name = isPauseMarker and "PauseMarker" or (isMarker and "PathMarker" or "PathPoint")
    part.Parent = workspace
    part.Anchored = true
    part.CanCollide = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Transparency = isMarker and 0.3 or 0.7
    part.Size = isPauseMarker and Vector3.new(2, 2, 2) or (isMarker and Vector3.new(1, 1, 1) or Vector3.new(0.5, 0.5, 0.5))
    part.Shape = isMarker and Enum.PartType.Ball or Enum.PartType.Block
    part.CFrame = CFrame.new(position)
    
    if isMarker or isPauseMarker then
        local pointLight = Instance.new("PointLight")
        pointLight.Parent = part
        pointLight.Color = color
        pointLight.Brightness = isPauseMarker and 3 or 2
        pointLight.Range = isPauseMarker and 15 or 10
        
        if (movementType == "idle" and idleDuration) or isPauseMarker then
            local billboard = Instance.new("BillboardGui")
            billboard.Parent = part
            billboard.Size = UDim2.new(0, 120, 0, 30)
            billboard.StudsOffset = Vector3.new(0, 3, 0)
            billboard.AlwaysOnTop = true
            
            local textLabel = Instance.new("TextLabel")
            textLabel.Parent = billboard
            textLabel.Size = UDim2.new(1, 0, 1, 0)
            textLabel.BackgroundTransparency = 1
            textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            textLabel.TextStrokeTransparency = 0.5
            textLabel.TextSize = 14
            textLabel.Font = Enum.Font.GothamBold
            textLabel.Name = isPauseMarker and "PauseLabel" or "IdleLabel"
            
            if isPauseMarker then
                textLabel.Text = "⏸️ PAUSED HERE"
                textLabel.TextColor3 = Color3.fromRGB(255, 165, 0)
            else
                textLabel.Text = idleDuration >= 60 and 
                    string.format("%.1fm", idleDuration/60) or 
                    string.format("%.1fs", idleDuration)
            end
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
    if pauseMarker and pauseMarker.Parent then
        pauseMarker:Destroy()
    end
    pathVisualParts = {}
    pathMarkerParts = {}
    pauseMarker = nil
end

-- Unified Recording Functions
local function startRecording(recordType)
    if isRecording or isPlaying then 
        warn("[SUPERTOOL] Cannot start recording: Another recording/playback is active")
        return 
    end
    
    if not updateCharacterReferences() then
        warn("[SUPERTOOL] Cannot start recording: Character not ready")
        return
    end
    
    isRecording = true
    currentRecordingType = recordType
    recordingPaused = false
    isPaused = false
    clearPathVisuals()
    
    if recordType == "macro" then
        currentData = {frames = {}, startTime = tick(), speed = 1, type = "macro"}
    else -- path
        currentData = {points = {}, markers = {}, startTime = tick(), speed = 1, type = "path"}
        idleStartTime = nil
        currentIdleLabel = nil
        idleStartPosition = nil
    end
    
    lastFrameTime = 0
    updateStatus()
    
    print("[SUPERTOOL] " .. recordType:gsub("^%l", string.upper) .. " recording started")
    
    local previousMovementType = nil
    
    recordConnection = RunService.Heartbeat:Connect(function()
        if not isRecording or isPaused then return end
        
        if not updateCharacterReferences() then return end
        
        local currentTime = tick() - currentData.startTime
        
        if recordType == "macro" then
            local success, frame = pcall(function()
                return {
                    time = currentTime,
                    cframe = rootPart.CFrame,
                    velocity = rootPart.Velocity,
                    walkSpeed = humanoid.WalkSpeed,
                    jumpPower = humanoid.JumpPower,
                    hipHeight = humanoid.HipHeight,
                    state = humanoid:GetState()
                }
            end)
            
            if success and frame then
                table.insert(currentData.frames, frame)
            end
        else -- path
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
            
            table.insert(currentData.points, pathPoint)
            
            local visualPart = createPathVisual(position, movementType, false)
            table.insert(pathVisualParts, visualPart)
            
            -- Handle idle detection and markers
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
                    table.insert(currentData.markers, {
                        time = idleStartTime,
                        position = idleStartPosition,
                        cframe = CFrame.new(idleStartPosition),
                        pathIndex = #currentData.points - 1,
                        idleDuration = duration,
                        movementType = "idle"
                    })
                    idleStartTime = nil
                    currentIdleLabel = nil
                    idleStartPosition = nil
                end
            end
            
            -- Create distance markers
            local shouldCreateMarker = false
            if #currentData.markers == 0 then
                shouldCreateMarker = true
            else
                local lastMarker = currentData.markers[#currentData.markers]
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
                    pathIndex = #currentData.points,
                    movementType = movementType
                }
                table.insert(currentData.markers, marker)
                
                local markerPart = createPathVisual(position, movementType, true)
                table.insert(pathMarkerParts, markerPart)
            end
            
            previousMovementType = movementType
        end
    end)
end

local function stopRecording()
    if not isRecording then return end
    
    -- Handle final idle duration for paths
    if currentRecordingType == "path" and idleStartTime then
        local duration = (tick() - currentData.startTime) - idleStartTime
        table.insert(currentData.markers, {
            time = idleStartTime,
            position = idleStartPosition,
            cframe = CFrame.new(idleStartPosition),
            pathIndex = #currentData.points,
            idleDuration = duration,
            movementType = "idle"
        })
        idleStartTime = nil
        currentIdleLabel = nil
        idleStartPosition = nil
    end
    
    isRecording = false
    isPaused = false
    recordingPaused = false
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    
    -- Generate random name
    local itemName = generateRandomName(currentRecordingType)
    
    -- Validate data
    local dataCount = 0
    if currentRecordingType == "macro" then
        dataCount = #(currentData.frames or {})
    else
        dataCount = #(currentData.points or {})
    end
    
    if dataCount == 0 then
        warn("[SUPERTOOL] Cannot save empty " .. currentRecordingType)
        clearPathVisuals()
        updateStatus()
        return
    end
    
    -- Set metadata
    currentData.name = itemName
    currentData.created = os.time()
    
    if currentRecordingType == "macro" then
        currentData.frameCount = #currentData.frames
        currentData.duration = currentData.frames[#currentData.frames].time
    else
        currentData.pointCount = #currentData.points
        currentData.markerCount = #(currentData.markers or {})
        currentData.duration = currentData.points[#currentData.points].time
    end
    
    -- Save data
    savedItems[itemName] = currentData
    saveToJSON(itemName, currentData)
    
    updateList()
    updateStatus()
    
    print("[SUPERTOOL] " .. currentRecordingType:gsub("^%l", string.upper) .. " saved: " .. itemName .. " (" .. dataCount .. " " .. (currentRecordingType == "macro" and "frames" or "points") .. ")")
end

-- Unified Playback Functions
local function playItem(itemName, showOnly, autoPlay, respawn)
    if isRecording or isPlaying then 
        stopPlayback()
    end
    
    if not updateCharacterReferences() then
        warn("[SUPERTOOL] Cannot play item: Character not ready")
        return
    end
    
    local item = savedItems[itemName] or loadFromJSON(itemName)
    if not item then
        warn("[SUPERTOOL] Cannot play item: Invalid data for " .. itemName)
        return
    end
    
    isPlaying = true
    autoPlaying = autoPlay or false
    autoRespawning = respawn or false
    currentItemName = itemName
    isPaused = false
    pauseIndex = 1
    
    -- Clear previous visuals
    clearPathVisuals()
    
    if item.type == "path" then
        -- Show path visuals
        for i, point in pairs(item.points or {}) do
            local visualPart = createPathVisual(point.position, point.movementType, false)
            table.insert(pathVisualParts, visualPart)
        end
        
        for i, marker in pairs(item.markers or {}) do
            local markerPart = createPathVisual(marker.position, marker.movementType or "marker", true, marker.idleDuration)
            table.insert(pathMarkerParts, markerPart)
        end
        
        if showOnly then
            print("[SUPERTOOL] Showing path: " .. itemName)
            updateStatus()
            return
        end
    end
    
    print("[SUPERTOOL] Playing " .. item.type .. ": " .. itemName)
    
    local startTime = tick()
    local index = 1
    local speed = item.speed or 1
    local dataArray = item.type == "macro" and item.frames or item.points
    
    if item.type == "macro" and humanoid then
        humanoid.WalkSpeed = 0
    end
    
    playbackConnection = RunService.Heartbeat:Connect(function()
        if not isPlaying or isPaused then return end
        
        if not updateCharacterReferences() then return end
        
        if index > #dataArray then
            if autoPlaying then
                if autoRespawning then
                    resetCharacter()
                else
                    index = 1
                    startTime = tick()
                end
            else
                stopPlayback()
                return
            end
        end
        
        local frameData = dataArray[index]
        local scaledTime = frameData.time / speed
        
        if scaledTime <= (tick() - startTime) then
            pcall(function()
                rootPart.CFrame = frameData.cframe
                rootPart.Velocity = frameData.velocity
                humanoid.WalkSpeed = frameData.walkSpeed
                humanoid.JumpPower = frameData.jumpPower
                
                if item.type == "macro" then
                    humanoid.HipHeight = frameData.hipHeight
                    humanoid:ChangeState(frameData.state)
                end
            end)
            index = index + 1
        end
    end)
    
    updateStatus()
end

local function stopPlayback()
    if not isPlaying then return end
    isPlaying = false
    autoPlaying = false
    autoRespawning = false
    isPaused = false
    pauseIndex = 1
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    if humanoid then
        humanoid.WalkSpeed = settings.WalkSpeed.value or 16
    end
    
    -- Remove pause marker
    if pauseMarker then
        pauseMarker:Destroy()
        pauseMarker = nil
    end
    
    currentItemName = nil
    updateList()
    updateStatus()
end

local function pausePlayback()
    if not isPlaying then return end
    isPaused = not isPaused
    
    -- Handle pause marker for paths
    if currentItemName then
        local item = savedItems[currentItemName] or loadFromJSON(currentItemName)
        if item and item.type == "path" and rootPart then
            if isPaused then
                -- Create pause marker
                pauseMarker = createPathVisual(rootPart.Position, "paused", true, nil, true)
            else
                -- Remove pause marker
                if pauseMarker then
                    pauseMarker:Destroy()
                    pauseMarker = nil
                end
            end
        end
    end
    
    updateStatus()
end

-- Undo System (for paths only)
local function undoToLastMarker()
    if not isRecording or currentRecordingType ~= "path" or not currentData.markers then
        warn("[SUPERTOOL] Undo only available during path recording")
        return
    end
    
    if #currentData.markers == 0 then
        warn("[SUPERTOOL] No markers to undo")
        return
    end
    
    local lastMarkerIndex = #currentData.markers
    local lastMarker = currentData.markers[lastMarkerIndex]
    if lastMarker and updateCharacterReferences() then
        rootPart.CFrame = lastMarker.cframe
        print("[SUPERTOOL] Undid to last marker at " .. tostring(lastMarker.position))
        
        -- Remove points and markers after the last marker
        currentData.points = {table.unpack(currentData.points, 1, lastMarker.pathIndex)}
        currentData.markers = {table.unpack(currentData.markers, 1, lastMarkerIndex - 1)}
        
        -- Save updated data
        if currentItemName then
            saveToJSON(currentItemName, currentData)
        end
        
        -- Update visuals
        clearPathVisuals()
        for i, point in pairs(currentData.points) do
            local visualPart = createPathVisual(point.position, point.movementType, false)
            table.insert(pathVisualParts, visualPart)
        end
        
        for i, marker in pairs(currentData.markers) do
            local markerPart = createPathVisual(marker.position, marker.movementType or "marker", true, marker.idleDuration)
            table.insert(pathMarkerParts, markerPart)
        end
        
        -- Create white sphere at undo position
        local undoMarker = createPathVisual(lastMarker.position, "idle", true)
        table.insert(pathMarkerParts, undoMarker)
    end
end

-- Status Update Function
local function updateStatus()
    if not StatusLabel then return end
    
    local statusText = ""
    if isRecording then
        local typeText = currentRecordingType:gsub("^%l", string.upper)
        statusText = recordingPaused and "Recording Paused" or ("Recording " .. typeText .. "...")
    elseif isPlaying and currentItemName then
        local item = savedItems[currentItemName] or loadFromJSON(currentItemName)
        local typeText = (item and item.type or "item"):gsub("^%l", string.upper)
        local speed = item and item.speed or 1
        local modeText = autoRespawning and "Auto-Respawning" or (autoPlaying and "Auto-Playing" or "Playing")
        statusText = (isPaused and "⏸️ Paused: " or (modeText .. " " .. typeText .. ": ")) .. currentItemName .. " (Speed: " .. speed .. "x)"
    end
    
    StatusLabel.Text = statusText
    StatusLabel.Visible = statusText ~= ""
end

-- File System Functions
function saveToJSON(itemName, itemData)
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(itemName)
        local fileName = sanitizedName .. ".json"
        local filePath = SAVE_FOLDER_PATH .. fileName
        
        if not isfolder(SAVE_FOLDER_PATH) then
            makefolder(SAVE_FOLDER_PATH)
        end
        
        local jsonData = {
            name = itemName,
            type = itemData.type,
            created = itemData.created or os.time(),
            speed = itemData.speed or 1
        }
        
        if itemData.type == "macro" then
            local serializedFrames = {}
            for i, frame in pairs(itemData.frames or {}) do
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
            
            jsonData.frames = serializedFrames
            jsonData.frameCount = #serializedFrames
            jsonData.duration = serializedFrames[#serializedFrames] and serializedFrames[#serializedFrames].time or 0
        else -- path
            local serializedPoints = {}
            for _, point in ipairs(itemData.points or {}) do
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
            for _, marker in ipairs(itemData.markers or {}) do
                table.insert(serializedMarkers, {
                    time = marker.time,
                    position = {marker.position.X, marker.position.Y, marker.position.Z},
                    cframe = {marker.cframe:GetComponents()},
                    pathIndex = marker.pathIndex,
                    idleDuration = marker.idleDuration,
                    movementType = marker.movementType
                })
            end
            
            jsonData.points = serializedPoints
            jsonData.markers = serializedMarkers
            jsonData.pointCount = #serializedPoints
            jsonData.markerCount = #serializedMarkers
            jsonData.duration = itemData.duration
        end
        
        local jsonString = HttpService:JSONEncode(jsonData)
        writefile(filePath, jsonString)
        
        print("[SUPERTOOL] Item saved: " .. filePath)
        return true
    end)
    
    return success
end

function loadFromJSON(itemName)
    local success, result = pcall(function()
        local sanitizedName = sanitizeFileName(itemName)
        local fileName = sanitizedName .. ".json"
        local filePath = SAVE_FOLDER_PATH .. fileName
        
        if not isfile(filePath) then return nil end
        
        local jsonString = readfile(filePath)
        local jsonData = HttpService:JSONDecode(jsonString)
        
        local loadedData = {
            name = jsonData.name or itemName,
            type = jsonData.type or "macro",
            created = jsonData.created or os.time(),
            speed = jsonData.speed or 1
        }
        
        if jsonData.type == "macro" then
            local validFrames = {}
            for i, rawFrame in pairs(jsonData.frames or {}) do
                local validFrame = validateFrame(rawFrame)
                if validFrame then
                    table.insert(validFrames, validFrame)
                end
            end
            
            loadedData.frames = validFrames
            loadedData.frameCount = #validFrames
            loadedData.duration = validFrames[#validFrames] and validFrames[#validFrames].time or 0
        else -- path
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
            
            loadedData.points = validPoints
            loadedData.markers = validMarkers
            loadedData.pointCount = #validPoints
            loadedData.markerCount = #validMarkers
            loadedData.duration = jsonData.duration or 0
        end
        
        return loadedData
    end)
    
    return success and result or nil
end

function deleteFromJSON(itemName)
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(itemName)
        local fileName = sanitizedName .. ".json"
        local filePath = SAVE_FOLDER_PATH .. fileName
        
        if isfile(filePath) then
            delfile(filePath)
            print("[SUPERTOOL] Item deleted: " .. filePath)
            return true
        end
        return false
    end)
    
    return success and error or false
end

function renameInJSON(oldName, newName)
    local success, error = pcall(function()
        local oldData = loadFromJSON(oldName)
        if not oldData then return false end
        
        oldData.name = newName
        oldData.modified = os.time()
        
        if saveToJSON(newName, oldData) then
            deleteFromJSON(oldName)
            return true
        end
        return false
    end)
    
    return success and error or false
end

-- UI Components
local function initUnifiedUI()
    if MainFrame then return end
    
    MainFrame = Instance.new("Frame")
    MainFrame.Name = "UnifiedFrame"
    MainFrame.Parent = ScreenGui
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    MainFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    MainFrame.BorderSizePixel = 1
    MainFrame.Position = UDim2.new(0.3, 0, 0.15, 0)
    MainFrame.Size = UDim2.new(0, 400, 0, 500)
    MainFrame.Visible = false
    MainFrame.Active = true
    MainFrame.Draggable = true

    local MainTitle = Instance.new("TextLabel")
    MainTitle.Parent = MainFrame
    MainTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    MainTitle.BorderSizePixel = 0
    MainTitle.Size = UDim2.new(1, 0, 0, 25)
    MainTitle.Font = Enum.Font.GothamBold
    MainTitle.Text = "🎯 SUPERTOOL UNIFIED SYSTEM v3.0"
    MainTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    MainTitle.TextSize = 10

    local CloseButton = Instance.new("TextButton")
    CloseButton.Parent = MainFrame
    CloseButton.BackgroundTransparency = 1
    CloseButton.Position = UDim2.new(1, -25, 0, 2)
    CloseButton.Size = UDim2.new(0, 20, 0, 20)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Text = "✕"
    CloseButton.TextColor3 = Color3.fromRGB(255, 100, 100)
    CloseButton.TextSize = 12

    MainInput = Instance.new("TextBox")
    MainInput.Parent = MainFrame
    MainInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    MainInput.BorderSizePixel = 0
    MainInput.Position = UDim2.new(0, 10, 0, 35)
    MainInput.Size = UDim2.new(1, -20, 0, 25)
    MainInput.Font = Enum.Font.Gotham
    MainInput.PlaceholderText = "🔍 Search macros and paths..."
    MainInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    MainInput.TextSize = 9
    MainInput.ClearTextOnFocus = false

    MainScrollFrame = Instance.new("ScrollingFrame")
    MainScrollFrame.Parent = MainFrame
    MainScrollFrame.BackgroundTransparency = 1
    MainScrollFrame.Position = UDim2.new(0, 10, 0, 70)
    MainScrollFrame.Size = UDim2.new(1, -20, 1, -110)
    MainScrollFrame.ScrollBarThickness = 3
    MainScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
    MainScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    MainLayout = Instance.new("UIListLayout")
    MainLayout.Parent = MainScrollFrame
    MainLayout.Padding = UDim.new(0, 5)
    MainLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- Control buttons
    local ControlFrame = Instance.new("Frame")
    ControlFrame.Parent = MainFrame
    ControlFrame.BackgroundTransparency = 1
    ControlFrame.Position = UDim2.new(0, 10, 1, -35)
    ControlFrame.Size = UDim2.new(1, -20, 0, 30)

    local PauseButton = Instance.new("TextButton")
    PauseButton.Parent = ControlFrame
    PauseButton.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
    PauseButton.BorderSizePixel = 0
    PauseButton.Position = UDim2.new(0, 0, 0, 0)
    PauseButton.Size = UDim2.new(0, 80, 0, 30)
    PauseButton.Font = Enum.Font.GothamBold
    PauseButton.Text = "⏸️ PAUSE"
    PauseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    PauseButton.TextSize = 9

    local StopButton = Instance.new("TextButton")
    StopButton.Parent = ControlFrame
    StopButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
    StopButton.BorderSizePixel = 0
    StopButton.Position = UDim2.new(0, 90, 0, 0)
    StopButton.Size = UDim2.new(0, 80, 0, 30)
    StopButton.Font = Enum.Font.GothamBold
    StopButton.Text = "⏹️ STOP"
    StopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    StopButton.TextSize = 9

    local ClearVisualsButton = Instance.new("TextButton")
    ClearVisualsButton.Parent = ControlFrame
    ClearVisualsButton.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    ClearVisualsButton.BorderSizePixel = 0
    ClearVisualsButton.Position = UDim2.new(0, 180, 0, 0)
    ClearVisualsButton.Size = UDim2.new(0, 100, 0, 30)
    ClearVisualsButton.Font = Enum.Font.GothamBold
    ClearVisualsButton.Text = "🧹 CLEAR"
    ClearVisualsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClearVisualsButton.TextSize = 9

    StatusLabel = Instance.new("TextLabel")
    StatusLabel.Parent = ScreenGui
    StatusLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    StatusLabel.BorderColor3 = Color3.fromRGB(45, 45, 45)
    StatusLabel.BorderSizePixel = 1
    StatusLabel.Position = UDim2.new(1, -300, 0, 10)
    StatusLabel.Size = UDim2.new(0, 290, 0, 30)
    StatusLabel.Font = Enum.Font.GothamBold
    StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    StatusLabel.TextSize = 10
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Visible = false
    StatusLabel.ZIndex = 10

    -- Button connections
    CloseButton.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        frameVisible = false
    end)

    PauseButton.MouseButton1Click:Connect(pausePlayback)
    StopButton.MouseButton1Click:Connect(stopPlayback)
    ClearVisualsButton.MouseButton1Click:Connect(clearPathVisuals)
    
    -- Search functionality
    MainInput.Changed:Connect(function(property)
        if property == "Text" then
            updateList()
        end
    end)
end

function updateList()
    if not MainScrollFrame then return end
    
    -- Clear existing items
    for _, child in pairs(MainScrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name == "ItemFrame" then
            child:Destroy()
        end
    end
    
    local searchText = MainInput.Text:lower()
    local layoutOrder = 0
    
    for itemName, item in pairs(savedItems) do
        if searchText == "" or string.find(itemName:lower(), searchText) then
            layoutOrder = layoutOrder + 1
            
            local itemFrame = Instance.new("Frame")
            itemFrame.Name = "ItemFrame"
            itemFrame.Parent = MainScrollFrame
            itemFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            itemFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
            itemFrame.BorderSizePixel = 1
            itemFrame.Size = UDim2.new(1, -10, 0, 140)
            itemFrame.LayoutOrder = layoutOrder
            
            -- Type indicator
            local typeIcon = item.type == "macro" and "🎮" or "🛤️"
            local typeColor = item.type == "macro" and Color3.fromRGB(100, 150, 255) or Color3.fromRGB(100, 255, 150)
            
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Parent = itemFrame
            nameLabel.Position = UDim2.new(0, 8, 0, 5)
            nameLabel.Size = UDim2.new(1, -16, 0, 20)
            nameLabel.Text = typeIcon .. " " .. itemName
            nameLabel.TextColor3 = typeColor
            nameLabel.BackgroundTransparency = 1
            nameLabel.TextSize = 10
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            -- Info label
            local infoText = ""
            if item.type == "macro" then
                infoText = string.format("Frames: %d | Duration: %.1fs", 
                                       item.frameCount or 0, 
                                       item.duration or 0)
            else
                infoText = string.format("Points: %d | Markers: %d | Duration: %.1fs", 
                                       item.pointCount or 0, 
                                       item.markerCount or 0, 
                                       item.duration or 0)
            end
            
            local infoLabel = Instance.new("TextLabel")
            infoLabel.Parent = itemFrame
            infoLabel.Position = UDim2.new(0, 8, 0, 25)
            infoLabel.Size = UDim2.new(1, -16, 0, 15)
            infoLabel.BackgroundTransparency = 1
            infoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
            infoLabel.TextSize = 8
            infoLabel.Font = Enum.Font.Gotham
            infoLabel.Text = infoText
            infoLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            -- Action buttons row 1
            local playButton = Instance.new("TextButton")
            playButton.Parent = itemFrame
            playButton.Position = UDim2.new(0, 8, 0, 45)
            playButton.Size = UDim2.new(0, 50, 0, 20)
            playButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
            playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            playButton.TextSize = 8
            playButton.Font = Enum.Font.GothamBold
            local isCurrentlyPlaying = (isPlaying and currentItemName == itemName and not autoPlaying)
            playButton.Text = isCurrentlyPlaying and "STOP" or "▶️ PLAY"
            
            local autoPlayButton = Instance.new("TextButton")
            autoPlayButton.Parent = itemFrame
            autoPlayButton.Position = UDim2.new(0, 63, 0, 45)
            autoPlayButton.Size = UDim2.new(0, 50, 0, 20)
            autoPlayButton.BackgroundColor3 = Color3.fromRGB(80, 140, 80)
            autoPlayButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            autoPlayButton.TextSize = 8
            autoPlayButton.Font = Enum.Font.GothamBold
            local isAutoPlaying = (isPlaying and currentItemName == itemName and autoPlaying and not autoRespawning)
            autoPlayButton.Text = isAutoPlaying and "STOP" or "🔄 AUTO"
            
            local autoRespawnButton = Instance.new("TextButton")
            autoRespawnButton.Parent = itemFrame
            autoRespawnButton.Position = UDim2.new(0, 118, 0, 45)
            autoRespawnButton.Size = UDim2.new(0, 60, 0, 20)
            autoRespawnButton.BackgroundColor3 = Color3.fromRGB(100, 160, 100)
            autoRespawnButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            autoRespawnButton.TextSize = 8
            autoRespawnButton.Font = Enum.Font.GothamBold
            local isAutoRespawning = (isPlaying and currentItemName == itemName and autoPlaying and autoRespawning)
            autoRespawnButton.Text = isAutoRespawning and "STOP" or "♻️ A-RESP"
            
            -- Show/Hide button (only for paths)
            if item.type == "path" then
                local showButton = Instance.new("TextButton")
                showButton.Parent = itemFrame
                showButton.Position = UDim2.new(0, 183, 0, 45)
                showButton.Size = UDim2.new(0, 50, 0, 20)
                showButton.BackgroundColor3 = Color3.fromRGB(40, 100, 140)
                showButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                showButton.TextSize = 8
                showButton.Font = Enum.Font.GothamBold
                showButton.Text = "👁️ SHOW"
                
                showButton.MouseButton1Click:Connect(function()
                    playItem(itemName, true, false, false)
                    updateList()
                end)
            end
            
            local deleteButton = Instance.new("TextButton")
            deleteButton.Parent = itemFrame
            deleteButton.Position = UDim2.new(1, -60, 0, 45)
            deleteButton.Size = UDim2.new(0, 50, 0, 20)
            deleteButton.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
            deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            deleteButton.TextSize = 8
            deleteButton.Font = Enum.Font.GothamBold
            deleteButton.Text = "🗑️ DEL"
            
            -- Action buttons row 2
            local renameInput = Instance.new("TextBox")
            renameInput.Parent = itemFrame
            renameInput.Position = UDim2.new(0, 8, 0, 70)
            renameInput.Size = UDim2.new(0, 120, 0, 18)
            renameInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            renameInput.BorderSizePixel = 0
            renameInput.PlaceholderText = "✏️ Rename..."
            renameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
            renameInput.TextSize = 7
            renameInput.Font = Enum.Font.Gotham
            
            local renameButton = Instance.new("TextButton")
            renameButton.Parent = itemFrame
            renameButton.Position = UDim2.new(0, 133, 0, 70)
            renameButton.Size = UDim2.new(0, 45, 0, 18)
            renameButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
            renameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            renameButton.TextSize = 7
            renameButton.Font = Enum.Font.GothamBold
            renameButton.Text = "RENAME"
            
            local exportButton = Instance.new("TextButton")
            exportButton.Parent = itemFrame
            exportButton.Position = UDim2.new(0, 183, 0, 70)
            exportButton.Size = UDim2.new(0, 50, 0, 18)
            exportButton.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
            exportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            exportButton.TextSize = 7
            exportButton.Font = Enum.Font.GothamBold
            exportButton.Text = "📤 EXPORT"
            
            -- Speed control
            local speedLabel = Instance.new("TextLabel")
            speedLabel.Parent = itemFrame
            speedLabel.Position = UDim2.new(0, 8, 0, 95)
            speedLabel.Size = UDim2.new(0, 45, 0, 15)
            speedLabel.BackgroundTransparency = 1
            speedLabel.Text = "⚡ Speed:"
            speedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            speedLabel.TextSize = 7
            speedLabel.Font = Enum.Font.Gotham
            speedLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            local speedInput = Instance.new("TextBox")
            speedInput.Parent = itemFrame
            speedInput.Position = UDim2.new(0, 58, 0, 95)
            speedInput.Size = UDim2.new(0, 40, 0, 15)
            speedInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            speedInput.BorderSizePixel = 0
            speedInput.Text = tostring(item.speed or 1)
            speedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
            speedInput.TextSize = 7
            speedInput.Font = Enum.Font.Gotham
            
            -- Date info
            local dateLabel = Instance.new("TextLabel")
            dateLabel.Parent = itemFrame
            dateLabel.Position = UDim2.new(0, 8, 0, 115)
            dateLabel.Size = UDim2.new(1, -16, 0, 15)
            dateLabel.BackgroundTransparency = 1
            dateLabel.Text = "📅 Created: " .. os.date("%Y-%m-%d %H:%M:%S", item.created or os.time())
            dateLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            dateLabel.TextSize = 6
            dateLabel.Font = Enum.Font.Gotham
            dateLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            -- Button connections
            playButton.MouseButton1Click:Connect(function()
                if isCurrentlyPlaying then
                    stopPlayback()
                else
                    playItem(itemName, false, false, false)
                end
                updateList()
            end)
            
            autoPlayButton.MouseButton1Click:Connect(function()
                if isAutoPlaying then
                    stopPlayback()
                else
                    playItem(itemName, false, true, false)
                end
                updateList()
            end)
            
            autoRespawnButton.MouseButton1Click:Connect(function()
                if isAutoRespawning then
                    stopPlayback()
                else
                    playItem(itemName, false, true, true)
                end
                updateList()
            end)
            
            deleteButton.MouseButton1Click:Connect(function()
                -- Confirm delete (simple implementation)
                if isPlaying and currentItemName == itemName then
                    stopPlayback()
                end
                savedItems[itemName] = nil
                deleteFromJSON(itemName)
                clearPathVisuals()
                updateList()
                print("[SUPERTOOL] Deleted: " .. itemName)
            end)
            
            renameButton.MouseButton1Click:Connect(function()
                if renameInput.Text ~= "" then
                    local newName = renameInput.Text
                    if savedItems[itemName] then
                        savedItems[newName] = savedItems[itemName]
                        savedItems[itemName] = nil
                        
                        if isPlaying and currentItemName == itemName then
                            currentItemName = newName
                        end
                        
                        renameInJSON(itemName, newName)
                        renameInput.Text = ""
                        updateList()
                        print("[SUPERTOOL] Renamed: " .. itemName .. " → " .. newName)
                    end
                end
            end)
            
            exportButton.MouseButton1Click:Connect(function()
                -- Simple export - copy filename to clipboard if possible
                print("[SUPERTOOL] Export: " .. itemName .. " (saved in " .. SAVE_FOLDER_PATH .. ")")
                if setclipboard then
                    setclipboard(SAVE_FOLDER_PATH .. sanitizeFileName(itemName) .. ".json")
                end
            end)
            
            speedInput.FocusLost:Connect(function(enterPressed)
                if enterPressed then
                    local newSpeed = tonumber(speedInput.Text)
                    if newSpeed and newSpeed > 0 and newSpeed <= 10 then
                        item.speed = newSpeed
                        saveToJSON(itemName, item)
                        print("[SUPERTOOL] Speed updated: " .. itemName .. " → " .. newSpeed .. "x")
                    else
                        speedInput.Text = tostring(item.speed or 1)
                    end
                end
            end)
        end
    end
    
    -- Update canvas size
    task.wait(0.1)
    if MainLayout then
        MainScrollFrame.CanvasSize = UDim2.new(0, 0, 0, MainLayout.AbsoluteContentSize.Y + 10)
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
    if not createButton then
        error("[SUPERTOOL] createButton function is nil in loadUtilityButtons")
    end
    
    print("[SUPERTOOL] Loading unified utility buttons")
    
    createButton("🎮 Record Macro", function() startRecording("macro") end)
    createButton("🛤️ Record Path", function() startRecording("path") end)
    createButton("⏹️ Stop Recording", stopRecording)
    createButton("📋 Manager", function()
        if not MainFrame then initUnifiedUI() end
        MainFrame.Visible = not MainFrame.Visible
        frameVisible = MainFrame.Visible
        if frameVisible then
            updateList()
        end
    end)
    
    createButton("🧹 Clear Visuals", clearPathVisuals)
    createButton("💀 Kill Player", killPlayer)
    createButton("♻️ Reset Character", resetCharacter)
    createButton("↶ Undo Path", undoToLastMarker)
end

-- Initialize function
function Utility.init(deps)
    if not deps or type(deps) ~= "table" then
        error("[SUPERTOOL] Invalid dependencies table provided to Utility.init")
    end
    
    Players = deps.Players
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    ScrollFrame = deps.ScrollFrame
    buttonStates = deps.buttonStates
    player = deps.player
    RunService = deps.RunService
    settings = deps.settings
    ScreenGui = deps.ScreenGui
    
    -- Validate critical dependencies
    if not Players then warn("[SUPERTOOL] Players service not provided") end
    if not player then warn("[SUPERTOOL] player not provided") end
    if not RunService then warn("[SUPERTOOL] RunService not provided") end
    if not ScreenGui then warn("[SUPERTOOL] ScreenGui not provided") end
    
    -- Reset all states
    isRecording = false
    isPlaying = false
    autoPlaying = false
    autoRespawning = false
    isPaused = false
    
    -- Create folder structure
    local success = pcall(function()
        if not isfolder("Supertool") then
            makefolder("Supertool")
        end
        if not isfolder(SAVE_FOLDER_PATH) then
            makefolder(SAVE_FOLDER_PATH)
        end
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to create folder structure")
    end
    
    setupKeyboardControls()
    
    -- Character management
    if player then
        player.CharacterAdded:Connect(function(newCharacter)
            task.spawn(function()
                humanoid = newCharacter:WaitForChild("Humanoid", 30)
                rootPart = newCharacter:WaitForChild("HumanoidRootPart", 30)
                if humanoid and rootPart then
                    if isRecording and recordingPaused then
                        task.wait(pauseResumeTime)
                        recordingPaused = false
                        updateStatus()
                    end
                    if isPlaying and currentItemName then
                        task.wait(pauseResumeTime)
                        isPaused = false
                        local item = savedItems[currentItemName] or loadFromJSON(currentItemName)
                        if item then
                            playItem(currentItemName, false, autoPlaying, autoRespawning)
                        end
                    end
                end
            end)
        end)
        
        player.CharacterRemoving:Connect(function()
            if isRecording then
                recordingPaused = true
                updateStatus()
            end
            if isPlaying then
                isPaused = true
                updateStatus()
            end
        end)
        
        if humanoid then
            humanoid.Died:Connect(function()
                if isRecording then
                    recordingPaused = true
                    updateStatus()
                end
                if isPlaying then
                    isPaused = true
                    updateStatus()
                end
            end)
        end
    end
    
    task.spawn(function()
        initUnifiedUI()
        print("[SUPERTOOL] ✅ Enhanced Unified System v3.0 initialized")
        print("  🎯 Features: Unified GUI with macros & paths")
        print("  📁 Storage: " .. SAVE_FOLDER_PATH)
        print("  ⌨️ Controls: Ctrl+Z (undo), Pause markers")
        print("  🎮 Actions: Export, Rename, Delete with sync")
    end)
end

return Utility