-- Enhanced Utility-related features for MinimalHackGUI by Fari Noveri
-- New Features: Path Recording, Enhanced Macro Controls, Auto-Respawn

-- Dependencies: These must be passed from mainloader.lua
local Players, humanoid, rootPart, ScrollFrame, buttonStates, RunService, player, ScreenGui, settings

-- Initialize module
local Utility = {}

-- Existing variables (macro system)
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
local playbackPaused = false
local pauseResumeTime = 5 -- Seconds to wait before resuming macro after death

-- NEW: Path Recording System Variables
local pathRecording = false
local pathPlaying = false
local pathShowOnly = false
local currentPath = {}
local savedPaths = {}
local pathFrameVisible = false
local PathFrame, PathScrollFrame, PathLayout, PathInput, SavePathButton
local pathConnection = nil
local pathPlayConnection = nil
local currentPathName = nil
local pathPaused = false
local pathPauseIndex = 1
local lastPathTime = 0
local pathUndoHistory = {}
local pathVisualParts = {}
local pathMarkerParts = {}

-- NEW: Enhanced Macro Variables
local macroPaused = false
local macroPauseIndex = 1
local macroPauseTime = 0
local autoRespawnEnabled = false

-- File System Integration
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MACRO_FOLDER_PATH = "Supertool/Macro/"
local PATH_FOLDER_PATH = "Supertool/Path/"

-- Path movement detection constants
local WALK_THRESHOLD = 5 -- studs per second
local JUMP_THRESHOLD = 20 -- studs per second Y velocity
local FALL_THRESHOLD = -10 -- studs per second Y velocity
local SWIM_THRESHOLD = 2 -- when in water
local MARKER_DISTANCE = 5 -- meters between path markers

-- Helper function untuk sanitize filename
local function sanitizeFileName(name)
    local sanitized = string.gsub(name, "[<>:\"/\\|?*]", "_")
    sanitized = string.gsub(sanitized, "^%s*(.-)%s*$", "%1")
    if sanitized == "" then
        sanitized = "unnamed_" .. os.time()
    end
    return sanitized
end

-- NEW: Path Movement Detection
local function detectMovementType(velocity, position)
    local speed = velocity.Magnitude
    local yVelocity = velocity.Y
    
    -- Check if swimming (simplified - you might want to add water detection)
    local isInWater = false
    local region = workspace:ReadVoxels(
        Region3.new(position - Vector3.new(2, 2, 2), position + Vector3.new(2, 2, 2)),
        4
    )
    -- Basic water detection logic would go here
    
    if isInWater then
        return "swimming", Color3.fromRGB(128, 0, 128) -- Purple
    elseif yVelocity > JUMP_THRESHOLD then
        return "jumping", Color3.fromRGB(255, 0, 0) -- Red
    elseif yVelocity < FALL_THRESHOLD then
        return "falling", Color3.fromRGB(255, 255, 0) -- Yellow
    elseif speed > WALK_THRESHOLD then
        return "walking", Color3.fromRGB(0, 255, 0) -- Green
    else
        return "idle", Color3.fromRGB(200, 200, 200) -- Gray
    end
end

-- NEW: Path Visualization
local function createPathVisual(position, movementType, color, isMarker)
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
        -- Add glowing effect for markers
        local pointLight = Instance.new("PointLight")
        pointLight.Parent = part
        pointLight.Color = color
        pointLight.Brightness = 2
        pointLight.Range = 10
        
        -- Add text label for undo points
        local gui = Instance.new("BillboardGui")
        gui.Parent = part
        gui.Size = UDim2.new(0, 100, 0, 50)
        gui.StudsOffset = Vector3.new(0, 2, 0)
        
        local label = Instance.new("TextLabel")
        label.Parent = gui
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0
        label.Text = "UNDO POINT"
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

-- NEW: Path Recording Functions
local function startPathRecording()
    if pathRecording or pathPlaying or macroRecording or macroPlaying then 
        warn("[SUPERTOOL] Cannot start path recording: Another recording/playback is active")
        return 
    end
    
    if not player.Character or not player.Character:FindFirstChild("Humanoid") or not player.Character:FindFirstChild("HumanoidRootPart") then
        warn("[SUPERTOOL] Cannot start path recording: Character not ready")
        return
    end
    
    pathRecording = true
    currentPath = {points = {}, startTime = tick(), markers = {}}
    pathUndoHistory = {}
    lastPathTime = 0
    clearPathVisuals()
    
    print("[SUPERTOOL] Path recording started")
    
    pathConnection = RunService.Heartbeat:Connect(function()
        if not pathRecording or not humanoid or not rootPart then return end
        
        local currentTime = tick() - currentPath.startTime
        local position = rootPart.Position
        local velocity = rootPart.Velocity
        local movementType, color = detectMovementType(velocity, position)
        
        -- Create path point
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
        
        -- Create visual
        local visualPart = createPathVisual(position, movementType, color, false)
        table.insert(pathVisualParts, visualPart)
        
        -- Check if we need to create a marker (every MARKER_DISTANCE studs)
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
        
        if shouldCreateMarker then
            local marker = {
                time = currentTime,
                position = position,
                cframe = rootPart.CFrame,
                pathIndex = #currentPath.points
            }
            table.insert(currentPath.markers, marker)
            
            -- Create marker visual
            local markerPart = createPathVisual(position, movementType, color, true)
            table.insert(pathMarkerParts, markerPart)
            
            print("[SUPERTOOL] Path marker created at " .. tostring(position))
        end
    end)
end

local function stopPathRecording()
    if not pathRecording then return end
    pathRecording = false
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

-- NEW: Path Playback Functions
local function playPath(pathName, showOnly)
    if pathRecording or pathPlaying or macroRecording or macroPlaying then return end
    
    if not player.Character or not player.Character:FindFirstChild("Humanoid") or not player.Character:FindFirstChild("HumanoidRootPart") then
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
    currentPathName = pathName
    pathPaused = false
    pathPauseIndex = 1
    
    -- Show path visualization
    clearPathVisuals()
    for i, point in pairs(path.points) do
        local _, color = detectMovementType(point.velocity, point.position)
        local visualPart = createPathVisual(point.position, point.movementType, color, false)
        table.insert(pathVisualParts, visualPart)
    end
    
    for i, marker in pairs(path.markers or {}) do
        local _, color = detectMovementType(Vector3.new(0, 0, 0), marker.position)
        local markerPart = createPathVisual(marker.position, "marker", color, true)
        table.insert(pathMarkerParts, markerPart)
    end
    
    if pathShowOnly then
        print("[SUPERTOOL] Showing path: " .. pathName)
        return
    end
    
    print("[SUPERTOOL] Playing path: " .. pathName)
    
    local startTime = tick()
    local index = 1
    
    pathPlayConnection = RunService.Heartbeat:Connect(function()
        if not pathPlaying or pathPaused then return end
        
        if index > #path.points then
            pathPlaying = false
            currentPathName = nil
            if pathPlayConnection then
                pathPlayConnection:Disconnect()
                pathPlayConnection = nil
            end
            return
        end
        
        local point = path.points[index]
        if point and tick() - startTime >= point.time then
            if humanoid and rootPart then
                rootPart.CFrame = point.cframe
                rootPart.Velocity = point.velocity
                humanoid.WalkSpeed = point.walkSpeed
                humanoid.JumpPower = point.jumpPower
            end
            index = index + 1
        end
    end)
end

-- NEW: Path Undo System
local function undoToLastMarker()
    if not currentPathName then return end
    
    local path = savedPaths[currentPathName]
    if not path or not path.markers or #path.markers == 0 then return end
    
    -- Find the last marker before current position
    local lastMarker = path.markers[#path.markers]
    if lastMarker and humanoid and rootPart then
        rootPart.CFrame = lastMarker.cframe
        print("[SUPERTOOL] Undid to last marker at " .. tostring(lastMarker.position))
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
        
        local jsonData = {
            name = pathName,
            created = pathData.created or os.time(),
            points = pathData.points,
            markers = pathData.markers or {},
            pointCount = #pathData.points,
            markerCount = #(pathData.markers or {}),
            duration = pathData.duration
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
        
        return jsonData
    end)
    
    return success and result or nil
end

-- ENHANCED: Macro pause/resume functionality
local function pauseResumeMacro()
    if not macroPlaying or not currentMacroName then return end
    
    if macroPaused then
        -- Resume
        macroPaused = false
        playbackPaused = false
        updateMacroStatus()
        print("[SUPERTOOL] Macro resumed from pause point")
    else
        -- Pause
        macroPaused = true
        playbackPaused = true
        macroPauseTime = tick()
        updateMacroStatus()
        print("[SUPERTOOL] Macro paused")
    end
end

-- ENHANCED: Auto-respawn functionality
local function enableAutoRespawn()
    autoRespawnEnabled = true
    print("[SUPERTOOL] Auto-respawn enabled for macro completion")
end

local function disableAutoRespawn()
    autoRespawnEnabled = false
    print("[SUPERTOOL] Auto-respawn disabled")
end

-- Enhanced macro playback with pause support
local function playMacroEnhanced(macroName, autoPlay, withRespawn)
    if macroRecording or macroPlaying then return end
    
    if not player.Character or not player.Character:FindFirstChild("Humanoid") or not player.Character:FindFirstChild("HumanoidRootPart") then
        warn("[SUPERTOOL] Cannot play macro: Character not ready")
        return
    end
    
    local macro = savedMacros[macroName] or loadFromFileSystem(macroName)
    if not macro or not macro.frames or #macro.frames == 0 then
        warn("[SUPERTOOL] Cannot play macro: Invalid macro data")
        return
    end
    
    macroPlaying = true
    autoPlaying = autoPlay or false
    autoRespawnEnabled = withRespawn or false
    currentMacroName = macroName
    macroPaused = false
    macroPauseIndex = 1
    
    updateMacroStatus()
    
    local function playSingleMacro()
        local startTime = tick()
        local index = macroPauseIndex
        local speed = macro.speed or 1
        
        playbackConnection = RunService.Heartbeat:Connect(function()
            if not macroPlaying then return end
            
            if macroPaused then
                -- Show pause indicator
                if humanoid and rootPart then
                    -- Create pause visual indicator
                    -- You could add a GUI element here
                end
                return
            end
            
            if not humanoid or not rootPart then return end
            
            if index > #macro.frames then
                if autoRespawnEnabled then
                    -- Respawn and restart
                    player:LoadCharacter()
                    task.wait(3) -- Wait for respawn
                    index = 1
                    startTime = tick()
                    macroPauseIndex = 1
                    print("[SUPERTOOL] Auto-respawned and restarting macro: " .. macroName)
                elseif autoPlaying then
                    index = 1
                    startTime = tick()
                    macroPauseIndex = 1
                else
                    macroPlaying = false
                    currentMacroName = nil
                    macroPaused = false
                    updateMacroStatus()
                    if playbackConnection then
                        playbackConnection:Disconnect()
                        playbackConnection = nil
                    end
                    return
                end
            end
            
            local frame = macro.frames[index]
            local scaledTime = frame.time / speed
            
            if scaledTime <= (tick() - startTime) then
                local success = pcall(function()
                    rootPart.CFrame = frame.cframe
                    rootPart.Velocity = frame.velocity
                    humanoid.WalkSpeed = frame.walkSpeed
                    humanoid.JumpPower = frame.jumpPower
                    humanoid.HipHeight = frame.hipHeight
                    humanoid:ChangeState(frame.state)
                end)
                
                if success then
                    macroPauseIndex = index
                end
                
                index = index + 1
            end
        end)
    end
    
    playSingleMacro()
end

-- Update existing functions with new features
local function updateMacroStatus()
    if not MacroStatusLabel then return end
    
    if macroRecording then
        MacroStatusLabel.Text = recordingPaused and "Recording Paused" or "Recording Macro"
        MacroStatusLabel.Visible = true
    elseif macroPlaying and currentMacroName then
        local macro = savedMacros[currentMacroName] or loadFromFileSystem(currentMacroName)
        local speed = macro and macro.speed or 1
        local statusText = ""
        
        if macroPaused then
            statusText = "⏸️ PAUSED: " .. currentMacroName
        elseif autoPlaying then
            statusText = "🔄 Auto-Playing: " .. currentMacroName
        else
            statusText = "▶️ Playing: " .. currentMacroName
        end
        
        if autoRespawnEnabled then
            statusText = statusText .. " (Auto-Respawn)"
        end
        
        statusText = statusText .. " (Speed: " .. speed .. "x)"
        MacroStatusLabel.Text = statusText
        MacroStatusLabel.Visible = true
    elseif pathRecording then
        MacroStatusLabel.Text = "🛤️ Recording Path"
        MacroStatusLabel.Visible = true
    elseif pathPlaying and currentPathName then
        local statusText = pathShowOnly and "👁️ Showing Path: " or "🛤️ Playing Path: "
        MacroStatusLabel.Text = statusText .. currentPathName
        MacroStatusLabel.Visible = true
    else
        MacroStatusLabel.Visible = false
    end
end

-- Initialize UI components for paths
local function initPathUI()
    PathFrame = Instance.new("Frame")
    PathFrame.Name = "PathFrame"
    PathFrame.Parent = ScreenGui
    PathFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    PathFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    PathFrame.BorderSizePixel = 1
    PathFrame.Position = UDim2.new(0.65, 0, 0.2, 0)
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
    PathTitle.Text = "PATH MANAGER - Visual Navigation"
    PathTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    PathTitle.TextSize = 8

    PathInput = Instance.new("TextBox")
    PathInput.Parent = PathFrame
    PathInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    PathInput.BorderSizePixel = 0
    PathInput.Position = UDim2.new(0, 5, 0, 25)
    PathInput.Size = UDim2.new(1, -65, 0, 20)
    PathInput.Font = Enum.Font.Gotham
    PathInput.PlaceholderText = "Enter path name..."
    PathInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    PathInput.TextSize = 7

    SavePathButton = Instance.new("TextButton")
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
    PathScrollFrame.Parent = PathFrame
    PathScrollFrame.BackgroundTransparency = 1
    PathScrollFrame.Position = UDim2.new(0, 5, 0, 50)
    PathScrollFrame.Size = UDim2.new(1, -10, 1, -55)
    PathScrollFrame.ScrollBarThickness = 2
    
    PathLayout = Instance.new("UIListLayout")
    PathLayout.Parent = PathScrollFrame
    PathLayout.Padding = UDim.new(0, 2)
    
    SavePathButton.MouseButton1Click:Connect(stopPathRecording)
end

function updatePathList()
    if not PathScrollFrame then return end
    
    for _, child in pairs(PathScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    for pathName, pathData in pairs(savedPaths) do
        local pathItem = Instance.new("Frame")
        pathItem.Parent = PathScrollFrame
        pathItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        pathItem.Size = UDim2.new(1, -5, 0, 80)
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Parent = pathItem
        nameLabel.Text = pathName
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.Size = UDim2.new(1, 0, 0, 20)
        nameLabel.BackgroundTransparency = 1
        
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Parent = pathItem
        infoLabel.Position = UDim2.new(0, 0, 0, 20)
        infoLabel.Size = UDim2.new(1, 0, 0, 15)
        infoLabel.BackgroundTransparency = 1
        infoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        infoLabel.TextSize = 6
        infoLabel.Text = string.format("Points: %d | Markers: %d | Duration: %.1fs", 
                                     pathData.pointCount or 0, 
                                     pathData.markerCount or 0, 
                                     pathData.duration or 0)
        
        -- Buttons
        local playButton = Instance.new("TextButton")
        playButton.Parent = pathItem
        playButton.Position = UDim2.new(0, 0, 0, 40)
        playButton.Size = UDim2.new(0, 60, 0, 15)
        playButton.Text = "PLAY"
        playButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        playButton.TextSize = 7
        
        local showButton = Instance.new("TextButton")
        showButton.Parent = pathItem
        showButton.Position = UDim2.new(0, 65, 0, 40)
        showButton.Size = UDim2.new(0, 60, 0, 15)
        showButton.Text = "SHOW"
        showButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
        showButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        showButton.TextSize = 7
        
        local undoButton = Instance.new("TextButton")
        undoButton.Parent = pathItem
        undoButton.Position = UDim2.new(0, 130, 0, 40)
        undoButton.Size = UDim2.new(0, 60, 0, 15)
        undoButton.Text = "UNDO"
        undoButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
        undoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        undoButton.TextSize = 7
        
        local deleteButton = Instance.new("TextButton")
        deleteButton.Parent = pathItem
        deleteButton.Position = UDim2.new(0, 195, 0, 40)
        deleteButton.Size = UDim2.new(0, 60, 0, 15)
        deleteButton.Text = "DELETE"
        deleteButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
        deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        deleteButton.TextSize = 7
        
        playButton.MouseButton1Click:Connect(function()
            playPath(pathName, false)
        end)
        
        showButton.MouseButton1Click:Connect(function()
            playPath(pathName, true)
        end)
        
        undoButton.MouseButton1Click:Connect(function()
            currentPathName = pathName
            undoToLastMarker()
        end)
        
        deleteButton.MouseButton1Click:Connect(function()
            savedPaths[pathName] = nil
            -- Also delete JSON file
            local sanitizedName = sanitizeFileName(pathName)
            local filePath = PATH_FOLDER_PATH .. sanitizedName .. ".json"
            if isfile(filePath) then
                delfile(filePath)
            end
            updatePathList()
            clearPathVisuals()
        end)
    end
end

-- Enhanced macro UI updates
function Utility.updateMacroList()
    if not MacroScrollFrame then return end
    
    -- Clear existing items
    for _, child in pairs(MacroScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local itemCount = 0
    
    for macroName, macro in pairs(savedMacros) do
        local macroItem = Instance.new("Frame")
        macroItem.Parent = MacroScrollFrame
        macroItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        macroItem.Size = UDim2.new(1, -5, 0, 130) -- Increased height for new buttons
        
        -- Name label
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Parent = macroItem
        nameLabel.Position = UDim2.new(0, 5, 0, 5)
        nameLabel.Size = UDim2.new(1, -10, 0, 15)
        nameLabel.Text = macroName
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextSize = 7
        nameLabel.Font = Enum.Font.Gotham
        
        -- Info label
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
        
        -- ENHANCED: Single Play/Pause button
        local isCurrentlyPlaying = (macroPlaying and currentMacroName == macroName)
        local playPauseButton = Instance.new("TextButton")
        playPauseButton.Parent = macroItem
        playPauseButton.Position = UDim2.new(0, 5, 0, 40)
        playPauseButton.Size = UDim2.new(0, 60, 0, 18)
        playPauseButton.BackgroundColor3 = isCurrentlyPlaying and (macroPaused and Color3.fromRGB(40, 100, 40) or Color3.fromRGB(100, 40, 40)) or Color3.fromRGB(60, 60, 60)
        playPauseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        playPauseButton.TextSize = 7
        playPauseButton.Font = Enum.Font.Gotham
        
        if isCurrentlyPlaying then
            playPauseButton.Text = macroPaused and "RESUME" or "PAUSE"
        else
            playPauseButton.Text = "PLAY"
        end
        
        -- Auto Play button
        local autoPlayButton = Instance.new("TextButton")
        autoPlayButton.Parent = macroItem
        autoPlayButton.Position = UDim2.new(0, 70, 0, 40)
        autoPlayButton.Size = UDim2.new(0, 50, 0, 18)
        autoPlayButton.BackgroundColor3 = (isCurrentlyPlaying and autoPlaying) and Color3.fromRGB(100, 100, 40) or Color3.fromRGB(60, 80, 60)
        autoPlayButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        autoPlayButton.TextSize = 7
        autoPlayButton.Font = Enum.Font.Gotham
        autoPlayButton.Text = (isCurrentlyPlaying and autoPlaying) and "STOP" or "AUTO"
        
        -- ENHANCED: Auto-Respawn button
        local autoRespawnButton = Instance.new("TextButton")
        autoRespawnButton.Parent = macroItem
        autoRespawnButton.Position = UDim2.new(0, 125, 0, 40)
        autoRespawnButton.Size = UDim2.new(0, 60, 0, 18)
        autoRespawnButton.BackgroundColor3 = (isCurrentlyPlaying and autoRespawnEnabled) and Color3.fromRGB(100, 60, 100) or Color3.fromRGB(80, 40, 80)
        autoRespawnButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        autoRespawnButton.TextSize = 6
        autoRespawnButton.Font = Enum.Font.Gotham
        autoRespawnButton.Text = "RESPAWN"
        
        -- Delete button
        local deleteButton = Instance.new("TextButton")
        deleteButton.Parent = macroItem
        deleteButton.Position = UDim2.new(0, 190, 0, 40)
        deleteButton.Size = UDim2.new(0, 50, 0, 18)
        deleteButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
        deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        deleteButton.TextSize = 7
        deleteButton.Font = Enum.Font.Gotham
        deleteButton.Text = "DELETE"
        
        -- Speed control
        local speedLabel = Instance.new("TextLabel")
        speedLabel.Parent = macroItem
        speedLabel.Position = UDim2.new(0, 5, 0, 65)
        speedLabel.Size = UDim2.new(0, 40, 0, 15)
        speedLabel.BackgroundTransparency = 1
        speedLabel.Text = "Speed:"
        speedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        speedLabel.TextSize = 6
        speedLabel.Font = Enum.Font.Gotham
        
        local speedInput = Instance.new("TextBox")
        speedInput.Parent = macroItem
        speedInput.Position = UDim2.new(0, 50, 0, 65)
        speedInput.Size = UDim2.new(0, 35, 0, 15)
        speedInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        speedInput.BorderSizePixel = 0
        speedInput.Text = tostring(macro.speed or 1)
        speedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        speedInput.TextSize = 6
        speedInput.Font = Enum.Font.Gotham
        
        -- Rename input
        local renameInput = Instance.new("TextBox")
        renameInput.Parent = macroItem
        renameInput.Position = UDim2.new(0, 90, 0, 65)
        renameInput.Size = UDim2.new(0, 80, 0, 15)
        renameInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        renameInput.BorderSizePixel = 0
        renameInput.PlaceholderText = "New name..."
        renameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        renameInput.TextSize = 6
        renameInput.Font = Enum.Font.Gotham
        
        -- Rename button
        local renameButton = Instance.new("TextButton")
        renameButton.Parent = macroItem
        renameButton.Position = UDim2.new(0, 175, 0, 65)
        renameButton.Size = UDim2.new(0, 50, 0, 15)
        renameButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
        renameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        renameButton.TextSize = 6
        renameButton.Font = Enum.Font.Gotham
        renameButton.Text = "RENAME"
        
        -- Status indicator for enhanced features
        local statusLabel = Instance.new("TextLabel")
        statusLabel.Parent = macroItem
        statusLabel.Position = UDim2.new(0, 5, 0, 85)
        statusLabel.Size = UDim2.new(1, -10, 0, 15)
        statusLabel.BackgroundTransparency = 1
        statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        statusLabel.TextSize = 6
        statusLabel.Font = Enum.Font.Gotham
        
        local statusText = ""
        if isCurrentlyPlaying then
            if macroPaused then
                statusText = "Status: PAUSED (Frame " .. macroPauseIndex .. "/" .. frameCount .. ")"
            elseif autoPlaying and autoRespawnEnabled then
                statusText = "Status: AUTO + RESPAWN"
            elseif autoPlaying then
                statusText = "Status: AUTO PLAYING"
            elseif autoRespawnEnabled then
                statusText = "Status: PLAYING + RESPAWN"
            else
                statusText = "Status: PLAYING"
            end
        else
            statusText = "Status: Ready"
        end
        statusLabel.Text = statusText
        
        -- Event handlers
        playPauseButton.MouseButton1Click:Connect(function()
            if isCurrentlyPlaying then
                -- Currently playing, so pause/resume
                pauseResumeMacro()
            else
                -- Not playing, so start
                playMacroEnhanced(macroName, false, false)
            end
            Utility.updateMacroList()
        end)
        
        autoPlayButton.MouseButton1Click:Connect(function()
            if isCurrentlyPlaying and autoPlaying then
                -- Stop auto play
                stopMacroPlayback()
            else
                -- Start auto play
                playMacroEnhanced(macroName, true, autoRespawnEnabled)
            end
            Utility.updateMacroList()
        end)
        
        autoRespawnButton.MouseButton1Click:Connect(function()
            if isCurrentlyPlaying then
                -- Toggle respawn for current playback
                autoRespawnEnabled = not autoRespawnEnabled
                updateMacroStatus()
            else
                -- Start with respawn enabled
                playMacroEnhanced(macroName, true, true)
            end
            Utility.updateMacroList()
        end)
        
        deleteButton.MouseButton1Click:Connect(function()
            if isCurrentlyPlaying then
                stopMacroPlayback()
            end
            savedMacros[macroName] = nil
            deleteFromFileSystem(macroName)
            Utility.updateMacroList()
        end)
        
        speedInput.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local newSpeed = tonumber(speedInput.Text)
                if newSpeed and newSpeed > 0 and newSpeed <= 10 then
                    macro.speed = newSpeed
                    saveToFileSystem(macroName, macro)
                    if isCurrentlyPlaying then
                        savedMacros[macroName].speed = newSpeed
                    end
                else
                    speedInput.Text = tostring(macro.speed or 1)
                end
            end
        end)
        
        renameButton.MouseButton1Click:Connect(function()
            if renameInput.Text ~= "" then
                local newName = renameInput.Text
                if savedMacros[macroName] then
                    savedMacros[newName] = savedMacros[macroName]
                    savedMacros[macroName] = nil
                    
                    if isCurrentlyPlaying then
                        currentMacroName = newName
                    end
                    
                    renameInFileSystem(macroName, newName)
                    renameInput.Text = ""
                    Utility.updateMacroList()
                end
            end
        end)
        
        itemCount = itemCount + 1
    end
    
    -- Update canvas size
    task.wait(0.1)
    if MacroLayout then
        MacroScrollFrame.CanvasSize = UDim2.new(0, 0, 0, MacroLayout.AbsoluteContentSize.Y + 5)
    end
end

-- User Input Service for Ctrl+Z undo
local function setupKeyboardControls()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        -- Ctrl+Z for undo to last marker
        if input.KeyCode == Enum.KeyCode.Z and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            undoToLastMarker()
        end
        
        -- Space for pause/resume macro
        if input.KeyCode == Enum.KeyCode.Space and macroPlaying then
            pauseResumeMacro()
        end
    end)
end

-- Enhanced existing functions
local function stopMacroPlayback()
    if not macroPlaying then return end
    macroPlaying = false
    autoPlaying = false
    autoRespawnEnabled = false
    macroPaused = false
    playbackPaused = false
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
    if humanoid then
        humanoid.WalkSpeed = settings.WalkSpeed.value or 16
    end
    currentMacroName = nil
    macroPauseIndex = 1
    Utility.updateMacroList()
    updateMacroStatus()
end

-- Add existing utility functions (keeping original macro recording/loading functions)
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

-- File system functions (keeping existing ones for macros)
local fileSystem = {
    ["Supertool/Macro"] = {}
}

local function ensureFileSystem()
    if not fileSystem["Supertool"] then
        fileSystem["Supertool"] = {}
    end
    if not fileSystem["Supertool/Macro"] then
        fileSystem["Supertool/Macro"] = {}
    end
end

local function saveToFileSystem(macroName, macroData)
    ensureFileSystem()
    fileSystem["Supertool/Macro"][macroName] = macroData
    -- Also save to JSON for persistence
    saveToJSONFile(macroName, macroData)
end

local function loadFromFileSystem(macroName)
    ensureFileSystem()
    return fileSystem["Supertool/Macro"][macroName]
end

local function deleteFromFileSystem(macroName)
    ensureFileSystem()
    if fileSystem["Supertool/Macro"][macroName] then
        fileSystem["Supertool/Macro"][macroName] = nil
    end
    -- Also delete JSON file
    local sanitizedName = sanitizeFileName(macroName)
    local filePath = MACRO_FOLDER_PATH .. sanitizedName .. ".json"
    if isfile(filePath) then
        delfile(filePath)
    end
end

local function renameInFileSystem(oldName, newName)
    ensureFileSystem()
    if fileSystem["Supertool/Macro"][oldName] then
        fileSystem["Supertool/Macro"][newName] = fileSystem["Supertool/Macro"][oldName]
        fileSystem["Supertool/Macro"][oldName] = nil
    end
    -- Handle JSON files
    local oldPath = MACRO_FOLDER_PATH .. sanitizeFileName(oldName) .. ".json"
    local newPath = MACRO_FOLDER_PATH .. sanitizeFileName(newName) .. ".json"
    if isfile(oldPath) then
        local data = readfile(oldPath)
        writefile(newPath, data)
        delfile(oldPath)
    end
end

-- JSON save/load functions for macros (keeping existing implementation)
local function saveToJSONFile(macroName, macroData)
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
        return true
    end)
    
    return success
end

-- Initialize UI functions (keeping existing macro UI)
local function initMacroUI()
    if MacroFrame then return end
    
    MacroFrame = Instance.new("Frame")
    MacroFrame.Name = "MacroFrame"
    MacroFrame.Parent = ScreenGui
    MacroFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    MacroFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    MacroFrame.BorderSizePixel = 1
    MacroFrame.Position = UDim2.new(0.3, 0, 0.2, 0)
    MacroFrame.Size = UDim2.new(0, 300, 0, 450) -- Increased height for new features
    MacroFrame.Visible = false
    MacroFrame.Active = true
    MacroFrame.Draggable = true

    local MacroTitle = Instance.new("TextLabel")
    MacroTitle.Parent = MacroFrame
    MacroTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    MacroTitle.BorderSizePixel = 0
    MacroTitle.Size = UDim2.new(1, 0, 0, 20)
    MacroTitle.Font = Enum.Font.Gotham
    MacroTitle.Text = "ENHANCED MACRO MANAGER v2.0"
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
    MacroInput.Size = UDim2.new(1, -65, 0, 20)
    MacroInput.Font = Enum.Font.Gotham
    MacroInput.PlaceholderText = "Enter macro name..."
    MacroInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    MacroInput.TextSize = 7

    SaveMacroButton = Instance.new("TextButton")
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
    MacroScrollFrame.Parent = MacroFrame
    MacroScrollFrame.BackgroundTransparency = 1
    MacroScrollFrame.Position = UDim2.new(0, 5, 0, 50)
    MacroScrollFrame.Size = UDim2.new(1, -10, 1, -55)
    MacroScrollFrame.ScrollBarThickness = 2
    MacroScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    MacroScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    MacroLayout = Instance.new("UIListLayout")
    MacroLayout.Parent = MacroScrollFrame
    MacroLayout.Padding = UDim.new(0, 2)

    MacroStatusLabel = Instance.new("TextLabel")
    MacroStatusLabel.Parent = ScreenGui
    MacroStatusLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    MacroStatusLabel.BorderColor3 = Color3.fromRGB(45, 45, 45)
    MacroStatusLabel.BorderSizePixel = 1
    MacroStatusLabel.Position = UDim2.new(1, -250, 0, 10)
    MacroStatusLabel.Size = UDim2.new(0, 240, 0, 25)
    MacroStatusLabel.Font = Enum.Font.Gotham
    MacroStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    MacroStatusLabel.TextSize = 8
    MacroStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    MacroStatusLabel.Visible = false

    SaveMacroButton.MouseButton1Click:Connect(stopMacroRecording)
    CloseMacroButton.MouseButton1Click:Connect(function()
        MacroFrame.Visible = false
        macroFrameVisible = false
    end)
end

-- Existing utility functions
local function startMacroRecording()
    if macroRecording or macroPlaying or pathRecording or pathPlaying then return end
    
    if not player.Character or not player.Character:FindFirstChild("Humanoid") or not player.Character:FindFirstChild("HumanoidRootPart") then
        warn("[SUPERTOOL] Cannot start recording: Character not ready")
        return
    end
    
    macroRecording = true
    recordingPaused = false
    currentMacro = {frames = {}, startTime = tick(), speed = 1}
    lastFrameTime = 0
    updateMacroStatus()
    
    recordConnection = RunService.Heartbeat:Connect(function()
        if not macroRecording or recordingPaused then return end
        
        if not humanoid or not rootPart then return end
        
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
    saveToFileSystem(macroName, currentMacro)
    
    MacroInput.Text = ""
    Utility.updateMacroList()
    updateMacroStatus()
    MacroFrame.Visible = true
    
    print("[SUPERTOOL] Macro saved: " .. macroName)
end

-- Load utility buttons
function Utility.loadUtilityButtons(createButton)
    createButton("Record Macro", startMacroRecording)
    createButton("Stop Recording", stopMacroRecording)
    createButton("Macro Manager", function()
        if not MacroFrame then initMacroUI() end
        MacroFrame.Visible = not MacroFrame.Visible
        macroFrameVisible = MacroFrame.Visible
        if macroFrameVisible then
            Utility.updateMacroList()
        end
    end)
    
    -- NEW: Path recording buttons
    createButton("Record Path", startPathRecording)
    createButton("Stop Path Recording", stopPathRecording)
    createButton("Path Manager", function()
        if not PathFrame then initPathUI() end
        PathFrame.Visible = not PathFrame.Visible
        pathFrameVisible = PathFrame.Visible
        if pathFrameVisible then
            updatePathList()
        end
    end)
    
    createButton("Clear Visuals", clearPathVisuals)
    createButton("Kill Player", function()
        if humanoid then humanoid.Health = 0 end
    end)
    createButton("Reset Character", function()
        if player then player:LoadCharacter() end
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
    
    -- Reset all states
    macroRecording = false
    macroPlaying = false
    autoPlaying = false
    macroPaused = false
    autoRespawnEnabled = false
    pathRecording = false
    pathPlaying = false
    pathShowOnly = false
    pathPaused = false
    
    -- Initialize file system
    ensureFileSystem()
    
    -- Create folders
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
    
    -- Setup keyboard controls
    setupKeyboardControls()
    
    -- Character event handlers
    if player then
        player.CharacterAdded:Connect(function(newCharacter)
            task.spawn(function()
                humanoid = newCharacter:WaitForChild("Humanoid", 30)
                rootPart = newCharacter:WaitForChild("HumanoidRootPart", 30)
                print("[SUPERTOOL] Character loaded - Enhanced features ready")
            end)
        end)
    end
    
    -- Initialize UI components
    task.spawn(function()
        initMacroUI()
        initPathUI()
        print("[SUPERTOOL] Enhanced Utility Module v2.0 initialized")
        print("  - Path Recording: Visual navigation with undo markers")
        print("  - Enhanced Macros: Pause/Resume, Auto-Respawn")
        print("  - Keyboard Controls: Ctrl+Z (undo), Space (pause/resume)")
    end)
end

return Utility