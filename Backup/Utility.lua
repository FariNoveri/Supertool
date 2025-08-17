-- FIXED Utility-related features for MinimalHackGUI by Fari Noveri
-- Version 1.3 - Fixed button responsiveness and dependency issues

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

-- FIXED: Better character reference update
local function updateCharacterReferences()
    local success = pcall(function()
        if player and player.Character then
            humanoid = player.Character:FindFirstChild("Humanoid")
            rootPart = player.Character:FindFirstChild("HumanoidRootPart")
            
            -- Setup death handler for auto-pause
            if humanoid and not humanoid:GetPropertyChangedSignal("Health"):IsConnected() then
                humanoid.Died:Connect(function()
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
            end
            
            return true
        end
        return false
    end)
    
    if success then
        print("[SUPERTOOL] Character references updated successfully")
    else
        warn("[SUPERTOOL] Failed to update character references")
    end
    
    return success
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
            version = "1.3",
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
            MacroStatusLabel.Text = recordingPaused and "📹 Recording Paused" or "📹 Recording Macro..."
            MacroStatusLabel.TextColor3 = recordingPaused and Color3.fromRGB(255, 200, 100) or Color3.fromRGB(255, 100, 100)
            MacroStatusLabel.Visible = true
        elseif macroPlaying and currentMacroName then
            local macro = savedMacros[currentMacroName]
            local speed = currentPlaybackSpeed or (macro and macro.speed) or 1
            local statusText = (autoPlaying and "🔄 Auto-Playing" or "▶️ Playing") .. ": " .. currentMacroName .. " (" .. speed .. "x)"
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
        MacroTitle.Text = "MACRO MANAGER - FIXED v1.3"
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

-- FIXED: Start Macro Recording with better initialization
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
    
    -- Update character references
    if not updateCharacterReferences() then
        warn("[SUPERTOOL] Cannot start recording - character not available")
        return
    end
    
    if not humanoid or not rootPart then
        warn("[SUPERTOOL] Cannot start recording - missing humanoid or rootPart")
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
        print("[SUPERTOOL] Macro recording started")
        
        local frameCount = 0
        local maxFrames = 3000
        local lastRecordTime = 0
        local recordInterval = 0.1
        
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
            
            if not humanoid or not rootPart then
                if not updateCharacterReferences() then
                    return
                end
            end
            
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
        end)
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to start macro recording")
        macroRecording = false
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
        
        print("[SUPERTOOL] Macro saved: " .. macroName .. " (" .. #currentMacro.frames .. " frames)")
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to stop macro recording")
    end
end

-- FIXED: Play Macro function
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
    
    -- Update character references
    if not updateCharacterReferences() then
        warn("[SUPERTOOL] Cannot play macro - character not available")
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
        
        if humanoid then
            humanoid.WalkSpeed = 0
        end
        
        updateMacroStatus()
        print("[SUPERTOOL] Playing macro: " .. macroName .. " (Frames: " .. #macro.frames .. ")")
        
        local function playSingleMacro()
            local startTime = tick()
            local index = 1
            local lastUpdateTime = 0
            local updateInterval = 0.05
            
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
                
                if not humanoid or not rootPart then
                    if not updateCharacterReferences() then
                        return
                    end
                end
                
                if index > #macro.frames then
                    if autoPlaying then
                        index = 1
                        startTime = tick()
                    else
                        macroPlaying = false
                        if playbackConnection then
                            playbackConnection:Disconnect()
                            playbackConnection = nil
                        end
                        if humanoid then
                            humanoid.WalkSpeed = 16
                        end
                        currentMacroName = nil
                        updateMacroStatus()
                        return
                    end
                end
                
                if index <= #macro.frames then
                    local frame = macro.frames[index]
                    local scaledTime = frame.time / currentPlaybackSpeed
                    
                    if scaledTime <= (currentTime - startTime) then
                        rootPart.CFrame = frame.cframe
                        rootPart.Velocity = frame.velocity
                        humanoid.WalkSpeed = frame.walkSpeed
                        humanoid.JumpPower = frame.jumpPower
                        humanoid.HipHeight = frame.hipHeight
                        if frame.state then
                            humanoid:ChangeState(frame.state)
                        end
                        
                        index = index + 1
                    end
                end
            end)
        end
        
        playSingleMacro()
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to play macro")
        macroPlaying = false
        autoPlaying = false
        currentMacroName = nil
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
        
        print("[SUPERTOOL] Macro playback stopped")
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to stop macro playback")
    end
end

-- Update macro list UI (simplified for debugging)
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
            infoLabel.Text = "Frames: " .. frameCount .. " | Duration: " .. string.format("%.1f", duration) .. "s"
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
            
            -- Connect button events
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
                savedMacros[macroName] = nil
                local sanitizedName = sanitizeFileName(macroName)
                local filePath = MACRO_FOLDER_PATH .. sanitizedName .. ".json"
                if isfile(filePath) then
                    delfile(filePath)
                end
                Utility.updateMacroList()
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
        print("[SUPERTOOL] Macro list updated successfully")
    else
        warn("[SUPERTOOL] Failed to update macro list")
    end
end

-- Load all macros from JSON folder
local function loadAllMacrosFromJSON()
    local success = pcall(function()
        if not isfolder(MACRO_FOLDER_PATH) then
            makefolder(MACRO_FOLDER_PATH)
            print("[SUPERTOOL] Created macro folder: " .. MACRO_FOLDER_PATH)
            return
        end
        
        local files = listfiles(MACRO_FOLDER_PATH)
        local count = 0
        
        for _, filePath in pairs(files) do
            if string.match(filePath, "%.json$") then
                local fileName = string.match(filePath, "([^/\\]+)%.json$")
                if fileName then
                    local macroName = string.gsub(fileName, "%.json$", "")
                    local macroData = loadFromJSONFile(macroName)
                    if macroData then
                        savedMacros[macroName] = macroData
                        count = count + 1
                    end
                end
            end
        end
        
        print("[SUPERTOOL] Loaded " .. count .. " macros from JSON files")
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
            print("[SUPERTOOL] Player killed")
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

-- Initialize function (REQUIRED for module system)
function Utility.init(deps)
    print("[SUPERTOOL] Initializing Utility module...")
    
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
        
        -- Update character references
        updateCharacterReferences()
        
        -- Setup character respawn handling
        if player then
            player.CharacterAdded:Connect(function()
                task.wait(1) -- Wait for character to fully load
                updateCharacterReferences()
            end)
        end
        
        -- Load existing macros
        loadAllMacrosFromJSON()
        
        print("[SUPERTOOL] Dependencies set:")
        print("- Players:", Players and "✓" or "✗")
        print("- RunService:", RunService and "✓" or "✗") 
        print("- player:", player and "✓" or "✗")
        print("- ScreenGui:", ScreenGui and "✓" or "✗")
        print("- humanoid:", humanoid and "✓" or "✗")
        print("- rootPart:", rootPart and "✓" or "✗")
    end)
    
    if success then
        print("[SUPERTOOL] Utility module initialized successfully")
        return true
    else
        warn("[SUPERTOOL] Failed to initialize Utility module")
        return false
    end
end

-- Load buttons function (REQUIRED for module system)
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
    end)
    
    if success then
        print("[SUPERTOOL] Utility buttons loaded successfully")
    else
        warn("[SUPERTOOL] Failed to load some utility buttons")
    end
end

-- Reset states function (REQUIRED for module system)
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

-- Cleanup function
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

-- Additional utility functions
function Utility.getMacroList()
    local macroList = {}
    for name, macro in pairs(savedMacros) do
        macroList[name] = {
            name = name,
            frameCount = (macro.frames and #macro.frames) or 0,
            duration = macro.duration or 0,
            speed = macro.speed or 1,
            created = macro.created,
            modified = macro.modified
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
        recordingPaused = recordingPaused
    }
end

function Utility.isReady()
    return ScreenGui ~= nil and player ~= nil and RunService ~= nil
end

function Utility.forceRefresh()
    print("[SUPERTOOL] Force refresh called")
    pcall(function()
        initializeServices()
        updateCharacterReferences()
        loadAllMacrosFromJSON()
        if MacroFrame and MacroFrame.Visible then
            Utility.updateMacroList()
        end
        updateMacroStatus()
    end)
end

-- Debug function to check status
function Utility.debugStatus()
    print("=== UTILITY DEBUG STATUS ===")
    print("Recording:", macroRecording)
    print("Playing:", macroPlaying)
    print("Auto Playing:", autoPlaying)
    print("Current Macro:", currentMacroName or "None")
    print("Saved Macros:", table.concat(table.keys(savedMacros) or {}, ", "))
    print("ScreenGui:", ScreenGui and "Available" or "Missing")
    print("Player:", player and player.Name or "Missing")
    print("Humanoid:", humanoid and "Available" or "Missing")
    print("RootPart:", rootPart and "Available" or "Missing")
    print("MacroFrame:", MacroFrame and "Created" or "Not Created")
    print("Record Connection:", recordConnection and "Active" or "Inactive")
    print("Playback Connection:", playbackConnection and "Active" or "Inactive")
    print("=== END DEBUG STATUS ===")
end

-- Return the module
return Utility