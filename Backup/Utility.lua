-- FIXED Utility-related features for MinimalHackGUI by Fari Noveri
-- Version 1.4 - Fixed character reference issues and improved stability

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
local characterLoadedOnce = false

-- File System Integration for KRNL
local HttpService = game:GetService("HttpService")
local MACRO_FOLDER_PATH = "Supertool/Macro/"

-- FIXED: Initialize required services immediately
local function initializeServices()
    if not RunService then
        RunService = game:GetService("RunService")
    end
    if not Players then
        Players = game:GetService("Players")
    end
    if not player then
        player = Players.LocalPlayer
    end
end

-- FIXED: Enhanced character reference update with retry mechanism
local function updateCharacterReferences()
    local maxRetries = 5
    local retryDelay = 0.5
    
    for attempt = 1, maxRetries do
        local success = pcall(function()
            if not player then
                player = Players.LocalPlayer
            end
            
            if player and player.Character then
                local character = player.Character
                local newHumanoid = character:FindFirstChild("Humanoid")
                local newRootPart = character:FindFirstChild("HumanoidRootPart")
                
                -- Verify both components exist and are valid
                if newHumanoid and newRootPart and newHumanoid.Health > 0 then
                    humanoid = newHumanoid
                    rootPart = newRootPart
                    
                    -- Setup death handler for auto-pause (only once per character)
                    if not humanoid:GetAttribute("SupertoolDeathHandlerSet") then
                        humanoid:SetAttribute("SupertoolDeathHandlerSet", true)
                        
                        humanoid.Died:Connect(function()
                            print("[SUPERTOOL] Character died - Health: " .. humanoid.Health)
                            
                            if macroRecording then
                                recordingPaused = true
                                print("[SUPERTOOL] Recording paused - character died")
                                updateMacroStatus()
                            elseif macroPlaying then
                                macroPlaybackPaused = true
                                print("[SUPERTOOL] Playback paused - character died")
                                updateMacroStatus()
                            end
                        end)
                        
                        print("[SUPERTOOL] Death handler set for new character")
                    end
                    
                    characterLoadedOnce = true
                    print("[SUPERTOOL] Character references updated successfully (attempt " .. attempt .. ")")
                    print("- Humanoid Health: " .. humanoid.Health)
                    print("- RootPart Position: " .. tostring(rootPart.Position))
                    return true
                else
                    print("[SUPERTOOL] Character components not ready (attempt " .. attempt .. ")")
                    print("- Character exists: " .. tostring(character ~= nil))
                    print("- Humanoid exists: " .. tostring(newHumanoid ~= nil))
                    print("- RootPart exists: " .. tostring(newRootPart ~= nil))
                    print("- Health: " .. (newHumanoid and newHumanoid.Health or "N/A"))
                end
            else
                print("[SUPERTOOL] Player or character not available (attempt " .. attempt .. ")")
            end
            
            -- Character not ready, wait and retry
            if attempt < maxRetries then
                wait(retryDelay)
            end
            return false
        end)
        
        if success then
            return true
        end
    end
    
    warn("[SUPERTOOL] Failed to update character references after " .. maxRetries .. " attempts")
    return false
end

-- FIXED: Enhanced character loading with proper wait
local function waitForCharacter()
    local maxWait = 15 -- Maximum wait time in seconds
    local waitTime = 0
    local checkInterval = 0.1
    
    print("[SUPERTOOL] Waiting for character to be ready...")
    
    while waitTime < maxWait do
        if player and player.Character then
            local character = player.Character
            local testHumanoid = character:FindFirstChild("Humanoid")
            local testRootPart = character:FindFirstChild("HumanoidRootPart")
            
            if testHumanoid and testRootPart and testHumanoid.Health > 0 then
                print("[SUPERTOOL] Character found, updating references...")
                return updateCharacterReferences()
            else
                print("[SUPERTOOL] Character exists but components not ready - Health: " .. 
                      (testHumanoid and testHumanoid.Health or "N/A"))
            end
        else
            print("[SUPERTOOL] No character found, waiting...")
        end
        
        wait(checkInterval)
        waitTime = waitTime + checkInterval
    end
    
    warn("[SUPERTOOL] Timeout waiting for character to load after " .. maxWait .. " seconds")
    return false
end

-- FIXED: Improved character respawn handling
local function setupCharacterHandling()
    if not player then
        player = Players.LocalPlayer
    end
    
    if player then
        -- Handle character spawning
        local characterAddedConnection = player.CharacterAdded:Connect(function(character)
            print("[SUPERTOOL] Character added: " .. character.Name)
            
            spawn(function()
                -- Wait for character to be fully loaded
                local humanoidLoaded = character:WaitForChild("Humanoid", 10)
                local rootPartLoaded = character:WaitForChild("HumanoidRootPart", 10)
                
                if humanoidLoaded and rootPartLoaded then
                    print("[SUPERTOOL] Character components loaded, waiting for stability...")
                    wait(2) -- Additional wait for full stability
                    
                    if updateCharacterReferences() then
                        print("[SUPERTOOL] Character references updated after spawn")
                        
                        -- Resume paused activities after a delay
                        if recordingPaused and macroRecording then
                            wait(1) -- Extra delay before resuming recording
                            recordingPaused = false
                            print("[SUPERTOOL] Recording resumed after respawn")
                            updateMacroStatus()
                        end
                        
                        if macroPlaybackPaused and macroPlaying then
                            wait(1) -- Extra delay before resuming playback
                            macroPlaybackPaused = false
                            print("[SUPERTOOL] Playback resumed after respawn")
                            updateMacroStatus()
                        end
                    else
                        warn("[SUPERTOOL] Failed to update character references after spawn")
                    end
                else
                    warn("[SUPERTOOL] Character components failed to load within timeout")
                end
            end)
        end)
        
        -- Handle character removal
        local characterRemovingConnection = player.CharacterRemoving:Connect(function(character)
            print("[SUPERTOOL] Character removing: " .. character.Name)
            humanoid = nil
            rootPart = nil
            characterLoadedOnce = false
        end)
        
        -- Store connections for cleanup
        if connections then
            table.insert(connections, characterAddedConnection)
            table.insert(connections, characterRemovingConnection)
        end
        
        -- Initial setup if character already exists
        if player.Character then
            spawn(function()
                print("[SUPERTOOL] Initial character setup...")
                wait(1) -- Delay to ensure character is stable
                updateCharacterReferences()
            end)
        end
    end
end

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

-- Helper function untuk save macro ke JSON file
local function saveToJSONFile(macroName, macroData)
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(macroName)
        local fileName = sanitizedName .. ".json"
        local filePath = MACRO_FOLDER_PATH .. fileName
        
        -- Ensure folder exists
        if not isfolder(MACRO_FOLDER_PATH) then
            makefolder(MACRO_FOLDER_PATH)
        end
        
        -- Create valid macro data structure
        if not macroData or not macroData.frames then
            macroData = macroData or {}
            macroData.frames = {}
        end
        
        -- Process frames
        local validFrames = {}
        for i, frame in pairs(macroData.frames or {}) do
            if frame then
                local validFrame = {
                    time = tonumber(frame.time) or (i * 0.1),
                    walkSpeed = tonumber(frame.walkSpeed) or 16,
                    jumpPower = tonumber(frame.jumpPower) or 50,
                    hipHeight = tonumber(frame.hipHeight) or 0,
                    state = frame.state or "Running"
                }
                
                -- Handle CFrame
                if frame.cframe then
                    if typeof(frame.cframe) == "CFrame" then
                        validFrame.cframe = {frame.cframe:GetComponents()}
                    elseif typeof(frame.cframe) == "table" and #frame.cframe >= 12 then
                        validFrame.cframe = frame.cframe
                    else
                        validFrame.cframe = {0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1}
                    end
                else
                    validFrame.cframe = {0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1}
                end
                
                -- Handle Velocity
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
                
                table.insert(validFrames, validFrame)
            end
        end
        
        local jsonData = {
            name = macroName,
            created = macroData.created or os.time(),
            modified = os.time(),
            version = "1.4",
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
        warn("[SUPERTOOL] Failed to save macro: " .. tostring(error))
        return false
    end
    return true
end

-- Helper function untuk load macro dari JSON file
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
            return nil
        end
        
        local jsonData = HttpService:JSONDecode(jsonString)
        if not jsonData then
            return nil
        end
        
        -- Process frames
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
                
                -- Process CFrame
                if frame.cframe and typeof(frame.cframe) == "table" and #frame.cframe >= 12 then
                    local components = {}
                    for j = 1, 12 do
                        components[j] = tonumber(frame.cframe[j]) or 0
                    end
                    validFrame.cframe = CFrame.new(unpack(components))
                else
                    validFrame.cframe = CFrame.new(0, 0, 0)
                end
                
                -- Process Velocity
                if frame.velocity and typeof(frame.velocity) == "table" and #frame.velocity >= 3 then
                    validFrame.velocity = Vector3.new(
                        tonumber(frame.velocity[1]) or 0,
                        tonumber(frame.velocity[2]) or 0,
                        tonumber(frame.velocity[3]) or 0
                    )
                else
                    validFrame.velocity = Vector3.new(0, 0, 0)
                end
                
                -- Process State
                if frame.state and typeof(frame.state) == "string" then
                    local stateEnum = Enum.HumanoidStateType[frame.state]
                    validFrame.state = stateEnum or Enum.HumanoidStateType.Running
                else
                    validFrame.state = Enum.HumanoidStateType.Running
                end
                
                table.insert(validFrames, validFrame)
            end
        end
        
        -- Sort frames by time
        if #validFrames > 1 then
            table.sort(validFrames, function(a, b) return a.time < b.time end)
        end
        
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
    
    if success and result then
        print("[SUPERTOOL] Loaded macro: " .. macroName .. " (" .. #(result.frames or {}) .. " frames)")
        return result
    else
        if not success then
            warn("[SUPERTOOL] Error loading macro: " .. tostring(result))
        end
        return nil
    end
end

-- FIXED: Update macro status display
local function updateMacroStatus()
    if not MacroStatusLabel then return end
    
    local success = pcall(function()
        if macroRecording then
            local frameCount = currentMacro and #(currentMacro.frames or {}) or 0
            local statusText = (recordingPaused and "📹 Recording Paused" or "📹 Recording") .. 
                             " (" .. frameCount .. " frames)"
            MacroStatusLabel.Text = statusText
            MacroStatusLabel.TextColor3 = recordingPaused and Color3.fromRGB(255, 200, 100) or Color3.fromRGB(255, 100, 100)
            MacroStatusLabel.Visible = true
        elseif macroPlaying and currentMacroName then
            local macro = savedMacros[currentMacroName]
            local speed = currentPlaybackSpeed or (macro and macro.speed) or 1
            local statusText = (autoPlaying and "🔄 Auto-Playing" or "▶️ Playing") .. 
                             ": " .. currentMacroName .. " (" .. speed .. "x)"
            if macroPlaybackPaused then
                statusText = "⏸️ " .. statusText .. " [PAUSED]"
            end
            MacroStatusLabel.Text = statusText
            MacroStatusLabel.TextColor3 = macroPlaybackPaused and Color3.fromRGB(255, 200, 100) or Color3.fromRGB(100, 255, 100)
            MacroStatusLabel.Visible = true
        else
            MacroStatusLabel.Visible = false
        end
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to update macro status")
    end
end

-- FIXED: Initialize Macro UI with proper error handling
local function initMacroUI()
    if MacroFrame or not ScreenGui then 
        print("[SUPERTOOL] MacroFrame already exists or ScreenGui not available")
        return 
    end
    
    local success = pcall(function()
        print("[SUPERTOOL] Creating Macro UI...")
        
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
        MacroTitle.Name = "Title"
        MacroTitle.Parent = MacroFrame
        MacroTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        MacroTitle.BorderSizePixel = 0
        MacroTitle.Size = UDim2.new(1, 0, 0, 20)
        MacroTitle.Font = Enum.Font.Gotham
        MacroTitle.Text = "MACRO MANAGER - FIXED v1.4"
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
        CloseMacroButton.TextColor3 = Color3.fromRGB(255, 100, 100)
        CloseMacroButton.TextSize = 10

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
        SaveMacroButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
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

        -- Status label
        MacroStatusLabel = Instance.new("TextLabel")
        MacroStatusLabel.Name = "MacroStatusLabel"
        MacroStatusLabel.Parent = ScreenGui
        MacroStatusLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        MacroStatusLabel.BorderColor3 = Color3.fromRGB(45, 45, 45)
        MacroStatusLabel.BorderSizePixel = 1
        MacroStatusLabel.Position = UDim2.new(1, -280, 0, 10)
        MacroStatusLabel.Size = UDim2.new(0, 270, 0, 25)
        MacroStatusLabel.Font = Enum.Font.Gotham
        MacroStatusLabel.Text = ""
        MacroStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        MacroStatusLabel.TextSize = 8
        MacroStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
        MacroStatusLabel.Visible = false

        -- Connect events
        SaveMacroButton.MouseButton1Click:Connect(function()
            print("[SUPERTOOL] Save button clicked")
            stopMacroRecording()
        end)
        
        CloseMacroButton.MouseButton1Click:Connect(function()
            print("[SUPERTOOL] Close button clicked")
            macroFrameVisible = false
            MacroFrame.Visible = false
        end)
        
        print("[SUPERTOOL] Macro UI created successfully")
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to create Macro UI")
        MacroFrame = nil
    end
end

-- FIXED: Show Macro Manager
local function showMacroManager()
    print("[SUPERTOOL] Show Macro Manager called")
    
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
        print("[SUPERTOOL] Macro Manager shown")
        -- Update list after showing
        task.spawn(function()
            wait(0.1)
            Utility.updateMacroList()
        end)
    else
        warn("[SUPERTOOL] Failed to show MacroFrame")
    end
end

-- FIXED: Start Macro Recording with enhanced character validation
local function startMacroRecording()
    print("[SUPERTOOL] Start Macro Recording called")
    
    if macroRecording then
        print("[SUPERTOOL] Already recording")
        return
    end
    
    if macroPlaying then
        print("[SUPERTOOL] Cannot record while playing")
        return
    end
    
    -- Initialize services first
    initializeServices()
    
    print("[SUPERTOOL] Checking character status before recording...")
    print("- Player exists: " .. tostring(player ~= nil))
    print("- Character exists: " .. tostring(player and player.Character ~= nil))
    print("- Humanoid exists: " .. tostring(humanoid ~= nil))
    print("- RootPart exists: " .. tostring(rootPart ~= nil))
    print("- Health: " .. (humanoid and humanoid.Health or "N/A"))
    
    -- Wait for character if needed
    if not humanoid or not rootPart or (humanoid and humanoid.Health <= 0) then
        print("[SUPERTOOL] Character not ready, waiting...")
        if not waitForCharacter() then
            warn("[SUPERTOOL] Cannot start recording - character not available after waiting")
            return
        end
    end
    
    if not humanoid or not rootPart or humanoid.Health <= 0 then
        warn("[SUPERTOOL] Cannot start recording - character components invalid")
        return
    end
    
    local success = pcall(function()
        macroRecording = true
        recordingPaused = false
        currentMacro = {
            frames = {}, 
            startTime = tick(), 
            speed = 1,
            created = os.time()
        }
        lastFrameTime = 0
        
        updateMacroStatus()
        print("[SUPERTOOL] Macro recording started successfully")
        print("- Start time: " .. currentMacro.startTime)
        print("- Character health: " .. humanoid.Health)
        print("- Character position: " .. tostring(rootPart.Position))
        
        local frameCount = 0
        local maxFrames = 3000
        local lastRecordTime = 0
        local recordInterval = 0.05 -- Reduced interval for smoother recording
        
        recordConnection = RunService.Heartbeat:Connect(function()
            if not macroRecording or recordingPaused then return end
            
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
            
            -- Check character validity each frame
            if not humanoid or not rootPart or humanoid.Health <= 0 then
                print("[SUPERTOOL] Character became invalid during recording")
                if not updateCharacterReferences() then
                    recordingPaused = true
                    print("[SUPERTOOL] Recording paused - character unavailable")
                    updateMacroStatus()
                    return
                end
            end
            
            -- Record frame with error handling
            local frameSuccess = pcall(function()
                local frame = {
                    time = currentTime - currentMacro.startTime,
                    cframe = rootPart.CFrame,
                    velocity = rootPart.Velocity,
                    walkSpeed = humanoid.WalkSpeed,
                    jumpPower = humanoid.JumpPower,
                    hipHeight = humanoid.HipHeight,
                    state = humanoid:GetState()
                }
                
                table.insert(currentMacro.frames, frame)
                frameCount = frameCount + 1
                lastFrameTime = frame.time
                
                -- Update status every 100 frames
                if frameCount % 100 == 0 then
                    updateMacroStatus()
                end
            end)
            
            if not frameSuccess then
                warn("[SUPERTOOL] Failed to record frame " .. frameCount)
            end
        end)
        
        print("[SUPERTOOL] Recording connection established")
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to start macro recording")
        macroRecording = false
        recordingPaused = false
    end
end

-- FIXED: Stop Macro Recording
local function stopMacroRecording()
    print("[SUPERTOOL] Stop Macro Recording called")
    
    if not macroRecording then
        print("[SUPERTOOL] Not currently recording")
        return
    end
    
    local success = pcall(function()
        macroRecording = false
        recordingPaused = false
        
        if recordConnection then
            recordConnection:Disconnect()
            recordConnection = nil
        end
        
        local macroName = ""
        if MacroInput and MacroInput.Text and MacroInput.Text ~= "" then
            macroName = MacroInput.Text
        else
            macroName = "Macro_" .. os.date("%H%M%S")
        end
        
        -- Process and save macro
        currentMacro.frameCount = #currentMacro.frames
        currentMacro.duration = #currentMacro.frames > 0 and currentMacro.frames[#currentMacro.frames].time or 0
        currentMacro.name = macroName
        currentMacro.modified = os.time()
        
        savedMacros[macroName] = currentMacro
        saveToJSONFile(macroName, currentMacro)
        
        if MacroInput then
            MacroInput.Text = ""
        end
        
        updateMacroStatus()
        showMacroManager()
        
        print("[SUPERTOOL] Macro saved successfully: " .. macroName)
        print("- Total frames: " .. #currentMacro.frames)
        print("- Duration: " .. string.format("%.2f", currentMacro.duration) .. " seconds")
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to stop macro recording")
    end
end

-- FIXED: Play Macro with enhanced character validation
local function playMacro(macroName, autoPlay)
    print("[SUPERTOOL] Play Macro called: " .. macroName .. " (Auto: " .. tostring(autoPlay) .. ")")
    
    if macroRecording then
        warn("[SUPERTOOL] Cannot play while recording")
        return
    end
    
    if macroPlaying then
        print("[SUPERTOOL] Already playing a macro")
        return
    end
    
    -- Initialize services
    initializeServices()
    
    print("[SUPERTOOL] Checking character status before playback...")
    print("- Player exists: " .. tostring(player ~= nil))
    print("- Character exists: " .. tostring(player and player.Character ~= nil))
    print("- Humanoid exists: " .. tostring(humanoid ~= nil))
    print("- RootPart exists: " .. tostring(rootPart ~= nil))
    print("- Health: " .. (humanoid and humanoid.Health or "N/A"))
    
    -- Wait for character if needed
    if not humanoid or not rootPart or (humanoid and humanoid.Health <= 0) then
        print("[SUPERTOOL] Character not ready for playback, waiting...")
        if not waitForCharacter() then
            warn("[SUPERTOOL] Cannot play macro - character not available after waiting")
            return
        end
    end
    
    if not humanoid or not rootPart or humanoid.Health <= 0 then
        warn("[SUPERTOOL] Cannot play macro - character components invalid")
        return
    end
    
    local macro = savedMacros[macroName] or loadFromJSONFile(macroName)
    if not macro then
        warn("[SUPERTOOL] Macro not found: " .. macroName)
        return
    end
    
    if not macro.frames or #macro.frames == 0 then
        warn("[SUPERTOOL] Macro has no frames: " .. macroName)
        return
    end
    
    local success = pcall(function()
        macroPlaying = true
        autoPlaying = autoPlay or false
        macroPlaybackPaused = false
        currentMacroName = macroName
        currentPlaybackSpeed = macro.speed or 1
        
        -- Store original walk speed
        local originalWalkSpeed = humanoid.WalkSpeed
        humanoid.WalkSpeed = 0
        
        updateMacroStatus()
        print("[SUPERTOOL] Playing macro: " .. macroName)
        print("- Total frames: " .. #macro.frames)
        print("- Duration: " .. string.format("%.2f", macro.duration or 0) .. " seconds")
        print("- Speed: " .. currentPlaybackSpeed .. "x")
        print("- Auto-play: " .. tostring(autoPlaying))
        
        local function playSingleMacro()
            local startTime = tick()
            local index = 1
            local lastUpdateTime = 0
            local updateInterval = 0.03 -- Smoother playback
            local framesApplied = 0
            
            playbackConnection = RunService.Heartbeat:Connect(function()
                if not macroPlaying then
                    if playbackConnection then
                        playbackConnection:Disconnect()
                        playbackConnection = nil
                    end
                    return
                end
                
                local currentTime = tick()
                if currentTime - lastUpdateTime < updateInterval then
                    return
                end
                lastUpdateTime = currentTime
                
                if macroPlaybackPaused then
                    return
                end
                
                -- Validate character each frame
                if not humanoid or not rootPart or humanoid.Health <= 0 then
                    print("[SUPERTOOL] Character became invalid during playback")
                    if not updateCharacterReferences() then
                        macroPlaybackPaused = true
                        print("[SUPERTOOL] Playback paused - character unavailable")
                        updateMacroStatus()
                        return
                    end
                end
                
                if index > #macro.frames then
                    if autoPlaying then
                        index = 1
                        startTime = tick()
                        framesApplied = 0
                        print("[SUPERTOOL] Auto-play: Restarting macro")
                    else
                        macroPlaying = false
                        if playbackConnection then
                            playbackConnection:Disconnect()
                            playbackConnection = nil
                        end
                        if humanoid then
                            humanoid.WalkSpeed = originalWalkSpeed
                        end
                        currentMacroName = nil
                        updateMacroStatus()
                        print("[SUPERTOOL] Macro playback completed - " .. framesApplied .. " frames applied")
                        return
                    end
                end
                
                if index <= #macro.frames then
                    local frame = macro.frames[index]
                    local scaledTime = frame.time / currentPlaybackSpeed
                    
                    if scaledTime <= (currentTime - startTime) then
                        -- Apply frame data safely
                        local frameSuccess = pcall(function()
                            rootPart.CFrame = frame.cframe
                            rootPart.Velocity = frame.velocity
                            humanoid.WalkSpeed = frame.walkSpeed
                            humanoid.JumpPower = frame.jumpPower
                            humanoid.HipHeight = frame.hipHeight
                            if frame.state then
                                humanoid:ChangeState(frame.state)
                            end
                        end)
                        
                        if frameSuccess then
                            framesApplied = framesApplied + 1
                        else
                            warn("[SUPERTOOL] Failed to apply frame " .. index)
                        end
                        
                        index = index + 1
                        
                        -- Update status every 100 frames
                        if framesApplied % 100 == 0 then
                            print("[SUPERTOOL] Applied " .. framesApplied .. " frames")
                        end
                    end
                end
            end)
            
            print("[SUPERTOOL] Playback connection established")
        end
        
        playSingleMacro()
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to play macro")
        macroPlaying = false
        autoPlaying = false
        currentMacroName = nil
        updateMacroStatus()
    end
end

-- FIXED: Stop Macro Playback
local function stopMacroPlayback()
    print("[SUPERTOOL] Stop Macro Playback called")
    
    local success = pcall(function()
        macroPlaying = false
        autoPlaying = false
        macroPlaybackPaused = false
        
        if playbackConnection then
            playbackConnection:Disconnect()
            playbackConnection = nil
        end
        
        if humanoid then
            humanoid.WalkSpeed = 16
        end
        
        currentMacroName = nil
        currentPlaybackSpeed = 1
        updateMacroStatus()
        
        print("[SUPERTOOL] Macro playback stopped successfully")
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to stop macro playback")
    end
end

-- Update macro list UI (enhanced with better error handling)
function Utility.updateMacroList()
    if not MacroScrollFrame then 
        warn("[SUPERTOOL] MacroScrollFrame not available")
        return 
    end
    
    print("[SUPERTOOL] Updating macro list...")
    
    local success = pcall(function()
        -- Clear existing items
        for _, child in pairs(MacroScrollFrame:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        local itemCount = 0
        
        -- Create macro items
        for macroName, macro in pairs(savedMacros) do
            local macroItem = Instance.new("Frame")
            macroItem.Name = macroName .. "Item"
            macroItem.Parent = MacroScrollFrame
            macroItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            macroItem.BorderSizePixel = 0
            macroItem.Size = UDim2.new(1, -5, 0, 60)
            macroItem.LayoutOrder = itemCount
            
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Parent = macroItem
            nameLabel.BackgroundTransparency = 1
            nameLabel.Position = UDim2.new(0, 5, 0, 5)
            nameLabel.Size = UDim2.new(1, -10, 0, 15)
            nameLabel.Font = Enum.Font.Gotham
            nameLabel.Text = macroName
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.TextSize = 8
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            local infoLabel = Instance.new("TextLabel")
            infoLabel.Parent = macroItem
            infoLabel.BackgroundTransparency = 1
            infoLabel.Position = UDim2.new(0, 5, 0, 20)
            infoLabel.Size = UDim2.new(1, -10, 0, 10)
            infoLabel.Font = Enum.Font.Gotham
            local frameCount = (macro.frames and #macro.frames) or 0
            local duration = macro.duration or 0
            infoLabel.Text = "Frames: " .. frameCount .. " | Duration: " .. string.format("%.1f", duration) .. "s | Speed: " .. (macro.speed or 1) .. "x"
            infoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            infoLabel.TextSize = 6
            infoLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            local playButton = Instance.new("TextButton")
            playButton.Parent = macroItem
            playButton.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
            playButton.BorderSizePixel = 0
            playButton.Position = UDim2.new(0, 5, 0, 35)
            playButton.Size = UDim2.new(0, 50, 0, 20)
            playButton.Font = Enum.Font.Gotham
            playButton.Text = "PLAY"
            playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            playButton.TextSize = 7
            
            local autoButton = Instance.new("TextButton")
            autoButton.Parent = macroItem
            autoButton.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
            autoButton.BorderSizePixel = 0
            autoButton.Position = UDim2.new(0, 60, 0, 35)
            autoButton.Size = UDim2.new(0, 50, 0, 20)
            autoButton.Font = Enum.Font.Gotham
            autoButton.Text = "AUTO"
            autoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            autoButton.TextSize = 7
            
            local deleteButton = Instance.new("TextButton")
            deleteButton.Parent = macroItem
            deleteButton.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
            deleteButton.BorderSizePixel = 0
            deleteButton.Position = UDim2.new(0, 115, 0, 35)
            deleteButton.Size = UDim2.new(0, 50, 0, 20)
            deleteButton.Font = Enum.Font.Gotham
            deleteButton.Text = "DELETE"
            deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            deleteButton.TextSize = 7
            
            local stopButton = Instance.new("TextButton")
            stopButton.Parent = macroItem
            stopButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            stopButton.BorderSizePixel = 0
            stopButton.Position = UDim2.new(0, 170, 0, 35)
            stopButton.Size = UDim2.new(0, 50, 0, 20)
            stopButton.Font = Enum.Font.Gotham
            stopButton.Text = "STOP"
            stopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            stopButton.TextSize = 7
            
            -- Connect button events with enhanced logging
            playButton.MouseButton1Click:Connect(function()
                print("[SUPERTOOL] Play button clicked for: " .. macroName)
                playMacro(macroName, false)
            end)
            
            autoButton.MouseButton1Click:Connect(function()
                print("[SUPERTOOL] Auto button clicked for: " .. macroName)
                playMacro(macroName, true)
            end)
            
            deleteButton.MouseButton1Click:Connect(function()
                print("[SUPERTOOL] Delete button clicked for: " .. macroName)
                local deleteSuccess = pcall(function()
                    savedMacros[macroName] = nil
                    local sanitizedName = sanitizeFileName(macroName)
                    local filePath = MACRO_FOLDER_PATH .. sanitizedName .. ".json"
                    if isfile(filePath) then
                        delfile(filePath)
                    end
                    Utility.updateMacroList()
                    print("[SUPERTOOL] Macro deleted: " .. macroName)
                end)
                if not deleteSuccess then
                    warn("[SUPERTOOL] Failed to delete macro: " .. macroName)
                end
            end)
            
            stopButton.MouseButton1Click:Connect(function()
                print("[SUPERTOOL] Stop button clicked")
                stopMacroPlayback()
            end)
            
            itemCount = itemCount + 1
        end
        
        -- Add info if no macros
        if itemCount == 0 then
            local noMacrosLabel = Instance.new("TextLabel")
            noMacrosLabel.Parent = MacroScrollFrame
            noMacrosLabel.BackgroundTransparency = 1
            noMacrosLabel.Size = UDim2.new(1, 0, 0, 30)
            noMacrosLabel.Font = Enum.Font.Gotham
            noMacrosLabel.Text = "No macros saved yet. Record one first!"
            noMacrosLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            noMacrosLabel.TextSize = 8
        end
        
        -- Update canvas size
        task.wait(0.1)
        if MacroLayout then
            MacroScrollFrame.CanvasSize = UDim2.new(0, 0, 0, MacroLayout.AbsoluteContentSize.Y + 10)
        end
    end)
    
    if success then
        print("[SUPERTOOL] Macro list updated successfully (" .. table.getn(savedMacros) .. " macros)")
    else
        warn("[SUPERTOOL] Failed to update macro list")
    end
end

-- Load all macros from JSON folder (enhanced)
local function loadAllMacrosFromJSON()
    local success = pcall(function()
        if not isfolder(MACRO_FOLDER_PATH) then
            makefolder(MACRO_FOLDER_PATH)
            print("[SUPERTOOL] Created macro folder: " .. MACRO_FOLDER_PATH)
            return
        end
        
        local files = listfiles(MACRO_FOLDER_PATH)
        local count = 0
        local errors = 0
        
        for _, filePath in pairs(files) do
            if string.match(filePath, "%.json$") then
                local fileName = string.match(filePath, "([^/\\]+)%.json$")
                if fileName then
                    local macroName = string.gsub(fileName, "%.json$", "")
                    local macroData = loadFromJSONFile(macroName)
                    if macroData then
                        savedMacros[macroName] = macroData
                        count = count + 1
                    else
                        errors = errors + 1
                    end
                end
            end
        end
        
        print("[SUPERTOOL] Loaded " .. count .. " macros from JSON files")
        if errors > 0 then
            warn("[SUPERTOOL] Failed to load " .. errors .. " macro files")
        end
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to load macros from JSON folder")
    end
end

-- FIXED: Kill Player function
local function killPlayer()
    print("[SUPERTOOL] Kill Player called")
    
    local success = pcall(function()
        initializeServices()
        updateCharacterReferences()
        
        if humanoid then
            humanoid.Health = 0
            print("[SUPERTOOL] Player killed successfully")
        else
            warn("[SUPERTOOL] Humanoid not found")
        end
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to kill player")
    end
end

-- FIXED: Reset Character function
local function resetCharacter()
    print("[SUPERTOOL] Reset Character called")
    
    local success = pcall(function()
        initializeServices()
        updateCharacterReferences()
        
        if player and player.Character and humanoid then
            humanoid.Health = 0
            print("[SUPERTOOL] Character reset (killed to respawn)")
        else
            warn("[SUPERTOOL] Cannot reset - Character or Humanoid not found")
        end
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to reset character")
    end
end

-- FIXED: Initialize function with enhanced character handling
function Utility.init(deps)
    print("[SUPERTOOL] Initializing Utility module v1.4...")
    
    local success = pcall(function()
        -- Set dependencies
        Players = deps.Players or game:GetService("Players")
        RunService = deps.RunService or game:GetService("RunService")
        player = deps.player or Players.LocalPlayer
        ScreenGui = deps.ScreenGui
        settings = deps.settings or {}
        connections = deps.connections or {}
        disableActiveFeature = deps.disableActiveFeature
        isExclusiveFeature = deps.isExclusiveFeature
        
        -- Initialize services
        initializeServices()
        
        -- Setup enhanced character handling
        setupCharacterHandling()
        
        -- Load existing macros
        loadAllMacrosFromJSON()
        
        print("[SUPERTOOL] Dependencies verification:")
        print("- Players: " .. (Players and "✓" or "✗"))
        print("- RunService: " .. (RunService and "✓" or "✗"))
        print("- player: " .. (player and "✓" or "✗"))
        print("- ScreenGui: " .. (ScreenGui and "✓" or "✗"))
        print("- humanoid: " .. (humanoid and "✓" or "✗"))
        print("- rootPart: " .. (rootPart and "✓" or "✗"))
        print("- Saved macros: " .. table.getn(savedMacros))
        
        if player then
            print("- Player name: " .. player.Name)
            if player.Character then
                print("- Character: " .. player.Character.Name)
            end
        end
    end)
    
    if success then
        print("[SUPERTOOL] Utility module initialized successfully!")
        return true
    else
        warn("[SUPERTOOL] Failed to initialize Utility module")
        return false
    end
end

-- Load buttons function (enhanced with better error handling)
function Utility.loadUtilityButtons(createButton)
    if not createButton or type(createButton) ~= "function" then
        error("createButton function is required")
        return
    end
    
    print("[SUPERTOOL] Loading utility buttons...")
    
    local success = pcall(function()
        -- Create buttons with enhanced logging
        createButton("Kill Player", function()
            print("[SUPERTOOL] Kill Player button pressed")
            killPlayer()
        end)
        
        createButton("Reset Character", function()
            print("[SUPERTOOL] Reset Character button pressed")
            resetCharacter()
        end)
        
        createButton("Record Macro", function()
            print("[SUPERTOOL] Record Macro button pressed")
            startMacroRecording()
        end)
        
        createButton("Stop Recording", function()
            print("[SUPERTOOL] Stop Recording button pressed")
            stopMacroRecording()
        end)
        
        createButton("Macro Manager", function()
            print("[SUPERTOOL] Macro Manager button pressed")
            showMacroManager()
        end)
        
        createButton("Stop Playback", function()
            print("[SUPERTOOL] Stop Playback button pressed")
            stopMacroPlayback()
        end)
        
        -- Debug button for troubleshooting
        createButton("Debug Status", function()
            print("[SUPERTOOL] Debug Status button pressed")
            Utility.debugStatus()
        end)
        
        -- Force refresh button
        createButton("Force Refresh", function()
            print("[SUPERTOOL] Force Refresh button pressed")
            Utility.forceRefresh()
        end)
    end)
    
    if success then
        print("[SUPERTOOL] Utility buttons loaded successfully")
    else
        warn("[SUPERTOOL] Failed to load some utility buttons")
    end
end

-- Reset states function (enhanced)
function Utility.resetStates()
    print("[SUPERTOOL] Resetting utility states...")
    
    local success = pcall(function()
        -- Stop all activities
        macroRecording = false
        macroPlaying = false
        autoPlaying = false
        macroPlaybackPaused = false
        recordingPaused = false
        
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
        
        -- Reset variables
        currentMacroName = nil
        currentPlaybackSpeed = 1
        currentMacro = {}
        lastFrameTime = 0
        characterLoadedOnce = false
        
        -- Restore humanoid speed
        if humanoid then
            pcall(function()
                humanoid.WalkSpeed = 16
            end)
        end
        
        updateMacroStatus()
        
        print("[SUPERTOOL] Utility states reset successfully")
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to reset some utility states")
    end
end

-- Enhanced cleanup function
function Utility.cleanup()
    print("[SUPERTOOL] Cleaning up Utility module...")
    
    local success = pcall(function()
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
        
        -- Clear UI references
        MacroScrollFrame = nil
        MacroLayout = nil
        MacroInput = nil
        SaveMacroButton = nil
        
        -- Clear variables
        macroFrameVisible = false
        
        print("[SUPERTOOL] Utility module cleaned up successfully")
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to cleanup some utility components")
    end
end

-- Enhanced utility functions
function Utility.getMacroList()
    local macroList = {}
    for name, macro in pairs(savedMacros) do
        macroList[name] = {
            name = name,
            frameCount = (macro.frames and #macro.frames) or 0,
            duration = macro.duration or 0,
            speed = macro.speed or 1,
            created = macro.created,
            modified = macro.modified,
            version = macro.version or "1.0"
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
        playbackSpeed = currentPlaybackSpeed,
        recordingPaused = recordingPaused,
        characterReady = (humanoid ~= nil and rootPart ~= nil and (humanoid.Health or 0) > 0),
        characterLoadedOnce = characterLoadedOnce,
        totalMacros = table.getn(savedMacros)
    }
end

function Utility.isReady()
    return ScreenGui ~= nil and player ~= nil and RunService ~= nil
end

function Utility.forceRefresh()
    print("[SUPERTOOL] Force refresh called")
    pcall(function()
        initializeServices()
        local updated = updateCharacterReferences()
        print("- Character update: " .. (updated and "✓" or "✗"))
        
        loadAllMacrosFromJSON()
        print("- Macros loaded: " .. table.getn(savedMacros))
        
        if MacroFrame and MacroFrame.Visible then
            Utility.updateMacroList()
            print("- UI updated: ✓")
        end
        
        updateMacroStatus()
        print("- Status updated: ✓")
    end)
end

-- Enhanced debug function
function Utility.debugStatus()
    print("=== UTILITY DEBUG STATUS v1.4 ===")
    print("RECORDING STATUS:")
    print("- Recording: " .. tostring(macroRecording))
    print("- Recording Paused: " .. tostring(recordingPaused))
    print("- Record Connection: " .. (recordConnection and "Active" or "Inactive"))
    
    print("\nPLAYBACK STATUS:")
    print("- Playing: " .. tostring(macroPlaying))
    print("- Auto Playing: " .. tostring(autoPlaying))
    print("- Playback Paused: " .. tostring(macroPlaybackPaused))
    print("- Current Macro: " .. (currentMacroName or "None"))
    print("- Playback Speed: " .. currentPlaybackSpeed)
    print("- Playback Connection: " .. (playbackConnection and "Active" or "Inactive"))
    
    print("\nCHARACTER STATUS:")
    print("- Player: " .. (player and player.Name or "Missing"))
    print("- Character: " .. (player and player.Character and player.Character.Name or "Missing"))
    print("- Humanoid: " .. (humanoid and "Available" or "Missing"))
    print("- Health: " .. (humanoid and humanoid.Health or "N/A"))
    print("- RootPart: " .. (rootPart and "Available" or "Missing"))
    print("- Position: " .. (rootPart and tostring(rootPart.Position) or "N/A"))
    print("- Character Loaded Once: " .. tostring(characterLoadedOnce))
    
    print("\nMACRO DATA:")
    local macroNames = {}
    for name, _ in pairs(savedMacros) do
        table.insert(macroNames, name)
    end
    print("- Saved Macros (" .. #macroNames .. "): " .. table.concat(macroNames, ", "))
    
    print("\nUI STATUS:")
    print("- ScreenGui: " .. (ScreenGui and "Available" or "Missing"))
    print("- MacroFrame: " .. (MacroFrame and "Created" or "Not Created"))
    print("- MacroFrame Visible: " .. (MacroFrame and tostring(MacroFrame.Visible) or "N/A"))
    print("- Status Label: " .. (MacroStatusLabel and "Available" or "Missing"))
    
    print("\nSYSTEM STATUS:")
    print("- Players Service: " .. (Players and "✓" or "✗"))
    print("- RunService: " .. (RunService and "✓" or "✗"))
    print("- HttpService: " .. (HttpService and "✓" or "✗"))
    
    if currentMacro and currentMacro.frames then
        print("\nCURRENT RECORDING:")
        print("- Frames: " .. #currentMacro.frames)
        print("- Duration: " .. string.format("%.2f", lastFrameTime) .. "s")
        print("- Start Time: " .. (currentMacro.startTime or "N/A"))
    end
    
    print("=== END DEBUG STATUS ===")
end

-- Return the module
return Utility