-- Enhanced Utility-related features for MinimalHackGUI by Fari Noveri
-- Updated version with path recording, visualization, undo functionality, and new Spawn Gear feature
-- Removed macro-related features
-- FIXED: Auto-load files after relog and undo during recording
-- NEW: Added Spawn Gear GUI with reset functionality and no duplication

-- Dependencies: These must be passed from mainloader.lua
local Players, humanoid, rootPart, ScrollFrame, buttonStates, RunService, player, ScreenGui, settings

-- Initialize module
local Utility = {}

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

-- Gear Spawning System Variables
local gearFrameVisible = false
local GearFrame, GearScrollFrame, GearLayout
local spawnedGears = {} -- Tracks spawned gear instances to prevent duplication
local InsertService = game:GetService("InsertService")

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

-- Movement colors
local movementColors = {
    swimming = Color3.fromRGB(128, 0, 128),
    jumping = Color3.fromRGB(255, 0, 0),
    falling = Color3.fromRGB(255, 255, 0),
    walking = Color3.fromRGB(0, 255, 0),
    idle = Color3.fromRGB(200, 200, 200)
}

-- Gear list with names and IDs
local gearList = {
    {name = "Rainbow Magic Carpet", id = 225921000},
    {name = "The 6th Annual Bloxy Award", id = 2758794374},
    {name = "Speed Coil", id = 99119158},
    {name = "Icy Arctic Fowl", id = 101078559},
    {name = "Dragon's Flame Sword", id = 168140949},
    {name = "Frost Guard General's Sword", id = 139574344},
    {name = "Phoenix", id = 92142799},
    {name = "Deluxe Rainbow Magic Carpet", id = 477910063},
    {name = "Airstrike", id = 88885539},
    {name = "Dual Gravity Coil", id = 150366274},
    {name = "Regeneration Coil", id = 119101539},
    {name = "Foul Poison Fowl", id = 170896941},
    {name = "Neon Rainbow Phoenix", id = 261827192},
    {name = "Golden Magic Carpet", id = 1016183873},
    {name = "8-Bit Phoenix", id = 163355404},
    {name = "Water Dragon Claws", id = 2548989639},
    {name = "Flying Dragon", id = 610133821},
    {name = "Paint Grenade", id = 172246820},
    {name = "Mega Annoying Megaphone", id = 65545971},
    {name = "Breath of Ice", id = 2605966484}
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
    if player then
        player:LoadCharacter()
    end
end

-- Gear Spawning Functions
local function spawnGear(gearId, gearName)
    if not updateCharacterReferences() then
        warn("[SUPERTOOL] Cannot spawn gear: Character not ready")
        return
    end

    -- Check for duplication
    if spawnedGears[gearId] then
        warn("[SUPERTOOL] Gear already spawned: " .. gearName)
        return
    end

    local success, result = pcall(function()
        local gear = InsertService:LoadAsset(gearId)
        local gearItem = gear:GetChildren()[1]
        if gearItem and gearItem:IsA("Tool") then
            gearItem.Parent = player.Backpack
            spawnedGears[gearId] = gearItem
            print("[SUPERTOOL] Spawned gear: " .. gearName)
        else
            warn("[SUPERTOOL] Failed to spawn gear: Invalid asset for " .. gearName)
        end
        gear:Destroy()
    end)

    if not success then
        warn("[SUPERTOOL] Failed to spawn gear: " .. tostring(result))
    end
end

local function resetAllGears()
    for gearId, gearItem in pairs(spawnedGears) do
        if gearItem and gearItem.Parent then
            gearItem:Destroy()
        end
    end
    spawnedGears = {}
    print("[SUPERTOOL] All spawned gears removed")
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
    if pathRecording or pathPlaying then return end
    
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

local function pausePath()
    if not pathPlaying then return end
    pathPaused = not pathPaused
    updatePathStatus()
end

-- Path Undo System
local function undoToLastMarker()
    if not pathRecording or not currentPath or not currentPath.markers or #currentPath.markers == 0 then
        warn("[SUPERTOOL] Undo only available during path recording with existing markers")
        return
    end
    
    local lastMarkerIndex = #currentPath.markers
    local lastMarker = currentPath.markers[lastMarkerIndex]
    
    if lastMarker and updateCharacterReferences() then
        rootPart.CFrame = lastMarker.cframe
        print("[SUPERTOOL] Undid to last marker at " .. tostring(lastMarker.position))
        
        currentPath.points = {table.unpack(currentPath.points, 1, lastMarker.pathIndex)}
        currentPath.markers = {table.unpack(currentPath.markers, 1, lastMarkerIndex - 1)}
        
        clearPathVisuals()
        for i, point in pairs(currentPath.points) do
            local visualPart = createPathVisual(point.position, point.movementType, false)
            table.insert(pathVisualParts, visualPart)
        end
        
        for i, marker in pairs(currentPath.markers) do
            local markerPart = createPathVisual(marker.position, marker.movementType or "marker", true, marker.idleDuration)
            table.insert(pathMarkerParts, markerPart)
        end
        
        local undoMarker = createPathVisual(lastMarker.position, "idle", true)
        undoMarker.Color = Color3.fromRGB(255, 255, 255)
        table.insert(pathMarkerParts, undoMarker)
    end
end

-- File System Functions for Paths
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

-- Load all saved paths
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
                    savedPaths[fileName] = pathData
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

-- Gear UI
local function initGearUI()
    if GearFrame then return end
    
    GearFrame = Instance.new("Frame")
    GearFrame.Name = "GearFrame"
    GearFrame.Parent = ScreenGui
    GearFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    GearFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    GearFrame.BorderSizePixel = 1
    GearFrame.Position = UDim2.new(0.7, 0, 0.2, 0)
    GearFrame.Size = UDim2.new(0, 300, 0, 400)
    GearFrame.Visible = false
    GearFrame.Active = true
    GearFrame.Draggable = true

    local GearTitle = Instance.new("TextLabel")
    GearTitle.Parent = GearFrame
    GearTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    GearTitle.BorderSizePixel = 0
    GearTitle.Size = UDim2.new(1, 0, 0, 20)
    GearTitle.Font = Enum.Font.Gotham
    GearTitle.Text = "GEAR SPAWNER v1.0"
    GearTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    GearTitle.TextSize = 8

    local CloseGearButton = Instance.new("TextButton")
    CloseGearButton.Parent = GearFrame
    CloseGearButton.BackgroundTransparency = 1
    CloseGearButton.Position = UDim2.new(1, -20, 0, 2)
    CloseGearButton.Size = UDim2.new(0, 15, 0, 15)
    CloseGearButton.Font = Enum.Font.GothamBold
    CloseGearButton.Text = "X"
    CloseGearButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseGearButton.TextSize = 8

    GearScrollFrame = Instance.new("ScrollingFrame")
    GearScrollFrame.Parent = GearFrame
    GearScrollFrame.BackgroundTransparency = 1
    GearScrollFrame.Position = UDim2.new(0, 5, 0, 50)
    GearScrollFrame.Size = UDim2.new(1, -10, 1, -80)
    GearScrollFrame.ScrollBarThickness = 2
    GearScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    GearScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    GearLayout = Instance.new("UIListLayout")
    GearLayout.Parent = GearScrollFrame
    GearLayout.Padding = UDim.new(0, 2)

    local ResetAllButton = Instance.new("TextButton")
    ResetAllButton.Parent = GearFrame
    ResetAllButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
    ResetAllButton.BorderSizePixel = 0
    ResetAllButton.Position = UDim2.new(0, 5, 1, -30)
    ResetAllButton.Size = UDim2.new(0, 100, 0, 25)
    ResetAllButton.Font = Enum.Font.Gotham
    ResetAllButton.Text = "Reset All Gears"
    ResetAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ResetAllButton.TextSize = 8

    CloseGearButton.MouseButton1Click:Connect(function()
        GearFrame.Visible = false
        gearFrameVisible = false
    end)

    ResetAllButton.MouseButton1Click:Connect(function()
        resetAllGears()
        updateGearList()
    end)

    updateGearList()
end

function updateGearList()
    if not GearScrollFrame then return end
    
    for _, child in pairs(GearScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    for _, gear in ipairs(gearList) do
        local gearItem = Instance.new("Frame")
        gearItem.Parent = GearScrollFrame
        gearItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        gearItem.Size = UDim2.new(1, -5, 0, 50)
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Parent = gearItem
        nameLabel.Position = UDim2.new(0, 5, 0, 5)
        nameLabel.Size = UDim2.new(1, -10, 0, 15)
        nameLabel.Text = gear.name
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextSize = 7
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local idLabel = Instance.new("TextLabel")
        idLabel.Parent = gearItem
        idLabel.Position = UDim2.new(0, 5, 0, 20)
        idLabel.Size = UDim2.new(1, -10, 0, 10)
        idLabel.BackgroundTransparency = 1
        idLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        idLabel.TextSize = 6
        idLabel.Font = Enum.Font.Gotham
        idLabel.Text = "ID: " .. gear.id
        idLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local spawnButton = Instance.new("TextButton")
        spawnButton.Parent = gearItem
        spawnButton.Position = UDim2.new(0, 5, 0, 30)
        spawnButton.Size = UDim2.new(0, 60, 0, 15)
        spawnButton.BackgroundColor3 = spawnedGears[gear.id] and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(40, 80, 40)
        spawnButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        spawnButton.TextSize = 7
        spawnButton.Font = Enum.Font.Gotham
        spawnButton.Text = spawnedGears[gear.id] and "Spawned" or "Spawn"
        
        spawnButton.MouseButton1Click:Connect(function()
            if not spawnedGears[gear.id] then
                spawnGear(gear.id, gear.name)
                updateGearList()
            end
        end)
    end
    
    task.wait(0.1)
    if GearLayout then
        GearScrollFrame.CanvasSize = UDim2.new(0, 0, 0, GearLayout.AbsoluteContentSize.Y + 5)
    end
end

-- Path UI
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
    PathTitle.Text = "PATH CREATOR - JSON SYNC v1.4"
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
    PathStatusLabel.ZIndex = 10

    ClosePathButton.MouseButton1Click:Connect(function()
        PathFrame.Visible = false
        pathFrameVisible = false
    end)

    PathPauseButton.MouseButton1Click:Connect(pausePath)
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
            
            local toggleShowButton = Instance.new("TextButton")
            toggleShowButton.Parent = pathItem
            toggleShowButton.Position = UDim2.new(0, 140, 0, 40)
            toggleShowButton.Size = UDim2.new(0, 40, 0, 18)
            toggleShowButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
            toggleShowButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            toggleShowButton.TextSize = 7
            toggleShowButton.Font = Enum.Font.Gotham
            toggleShowButton.Text = (pathShowOnly and currentPathName == pathName) and "HIDE" or "SHOW"
            
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
        PathScrollFrame.CanvasSize = UDim2.new(0, 0, 0, PathLayout.AbsoluteContentSize.Y + 5)
    end
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
    createButton("Gear Spawner", function()
        if not GearFrame then initGearUI() end
        GearFrame.Visible = not GearFrame.Visible
        gearFrameVisible = GearFrame.Visible
        if gearFrameVisible then
            updateGearList()
        end
    end)
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
    
    pathRecording = false
    pathPlaying = false
    pathShowOnly = false
    pathPaused = false
    gearFrameVisible = false
    spawnedGears = {}
    
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
    
    task.spawn(function()
        local pathCount = loadAllSavedPaths()
        print("[SUPERTOOL] Initialization complete - Paths: " .. pathCount)
    end)
    
    setupKeyboardControls()
    
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
                    -- Clear spawned gears on character reset
                    resetAllGears()
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
            -- Clear spawned gears on character removal
            resetAllGears()
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
                -- Clear spawned gears on death
                resetAllGears()
            end)
        end
    end
    
    task.spawn(function()
        initPathUI()
        initGearUI()
        print("[SUPERTOOL] Path and Gear Utility Module v2.6 initialized")
        print("  - Path Recording: Visual navigation with undo markers and idle duration")
        print("  - Gear Spawner: Spawn and manage gears with reset functionality")
        print("  - Keyboard Controls: Ctrl+Z (undo)")
        print("  - JSON Storage: Supertool/Paths")
    end)
end

return Utility
