-- Utility-related features for MinimalHackGUI by Fari Noveri

-- Dependencies: These must be passed from mainloader.lua
local Players, humanoid, rootPart, ScrollFrame, buttonStates, RunService, player, ScreenGui, settings

-- Initialize module
local Utility = {}

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

-- Admin Command Variables
local adminFrameVisible = false
local AdminFrame, AdminScrollFrame, AdminLayout, AdminStatusLabel
local adminCommands = {}
local adminList = {}

-- File System Integration for KRNL
local HttpService = game:GetService("HttpService")
local MACRO_FOLDER_PATH = "Supertool/Macro/"

-- Helper function untuk sanitize filename
local function sanitizeFileName(name)
    local sanitized = string.gsub(name, "[<>:\"/\\|?*]", "_")
    sanitized = string.gsub(sanitized, "^%s*(.-)%s*$", "%1")
    if sanitized == "" then
        sanitized = "unnamed_macro"
    end
    return sanitized
end

-- FIXED: Robust validation and conversion functions
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

local function validateAndConvertState(stateData)
    if not stateData then 
        return Enum.HumanoidStateType.Running 
    end
    
    if typeof(stateData) == "EnumItem" and stateData.EnumType == Enum.HumanoidStateType then
        return stateData
    end
    
    if type(stateData) == "string" then
        local success, result = pcall(function()
            return Enum.HumanoidStateType[stateData]
        end)
        if success and result then
            return result
        end
    end
    
    if type(stateData) == "number" then
        for _, state in pairs(Enum.HumanoidStateType:GetEnumItems()) do
            if state.Value == stateData then
                return state
            end
        end
    end
    
    return Enum.HumanoidStateType.Running
end

local function validateFrame(frame)
    if not frame or type(frame) ~= "table" then
        return nil
    end
    
    if not frame.time or type(frame.time) ~= "number" or frame.time < 0 then
        return nil
    end
    
    local validFrame = {
        time = frame.time,
        cframe = validateAndConvertCFrame(frame.cframe),
        velocity = validateAndConvertVector3(frame.velocity),
        walkSpeed = tonumber(frame.walkSpeed) or 16,
        jumpPower = tonumber(frame.jumpPower) or 50,
        hipHeight = tonumber(frame.hipHeight) or 0,
        state = validateAndConvertState(frame.state)
    }
    
    return validFrame
end

-- FIXED: More robust macro saving
local function saveToJSONFile(macroName, macroData)
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(macroName)
        local fileName = sanitizedName .. ".json"
        local filePath = MACRO_FOLDER_PATH .. fileName
        
        if not macroData or not macroData.frames or type(macroData.frames) ~= "table" then
            warn("[SUPERTOOL] Invalid macro data for saving: " .. macroName)
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
        
        if #serializedFrames == 0 then
            warn("[SUPERTOOL] No valid frames to save for macro: " .. macroName)
            return false
        end
        
        local jsonData = {
            name = macroName,
            created = macroData.created or os.time(),
            modified = os.time(),
            version = "1.1",
            frames = serializedFrames,
            startTime = macroData.startTime or 0,
            speed = macroData.speed or 1,
            frameCount = #serializedFrames,
            duration = serializedFrames[#serializedFrames].time
        }
        
        local jsonString = HttpService:JSONEncode(jsonData)
        writefile(filePath, jsonString)
        
        print("[SUPERTOOL] Macro saved: " .. filePath .. " (" .. #serializedFrames .. " frames)")
        return true
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to save macro to JSON: " .. tostring(error))
        return false
    end
    return true
end

-- FIXED: More robust macro loading
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
            warn("[SUPERTOOL] No valid frames found in macro: " .. macroName .. " (skipped: " .. skippedFrames .. ")")
            return nil
        end
        
        if skippedFrames > 0 then
            print("[SUPERTOOL] Loaded macro with " .. skippedFrames .. " skipped invalid frames")
        end
        
        local macroData = {
            name = jsonData.name or macroName,
            created = jsonData.created or os.time(),
            modified = jsonData.modified or os.time(),
            version = jsonData.version or "1.0",
            frames = validFrames,
            startTime = tonumber(jsonData.startTime) or 0,
            speed = tonumber(jsonData.speed) or 1,
            frameCount = #validFrames,
            duration = validFrames[#validFrames].time
        }
        
        return macroData
    end)
    
    if success then
        if result then
            print("[SUPERTOOL] Successfully loaded macro: " .. macroName .. " (" .. #(result.frames or {}) .. " frames)")
        end
        return result
    else
        warn("[SUPERTOOL] Failed to load macro from JSON: " .. macroName .. " - " .. tostring(result))
        return nil
    end
end

local function deleteFromJSONFile(macroName)
    local success, error = pcall(function()
        local sanitizedName = sanitizeFileName(macroName)
        local fileName = sanitizedName .. ".json"
        local filePath = MACRO_FOLDER_PATH .. fileName
        
        if isfile(filePath) then
            delfile(filePath)
            print("[SUPERTOOL] Macro deleted: " .. filePath)
            return true
        else
            return false
        end
    end)
    
    if success then
        return error
    else
        warn("[SUPERTOOL] Failed to delete macro JSON: " .. tostring(error))
        return false
    end
end

local function renameInJSONFile(oldName, newName)
    local success, error = pcall(function()
        local oldData = loadFromJSONFile(oldName)
        if not oldData then
            return false
        end
        
        oldData.name = newName
        oldData.modified = os.time()
        
        if saveToJSONFile(newName, oldData) then
            deleteFromJSONFile(oldName)
            print("[SUPERTOOL] Macro renamed: " .. oldName .. " -> " .. newName)
            return true
        else
            return false
        end
    end)
    
    if success then
        return error
    else
        warn("[SUPERTOOL] Failed to rename macro: " .. tostring(error))
        return false
    end
end

local function loadAllMacrosFromFolder()
    local success, result = pcall(function()
        if not isfolder(MACRO_FOLDER_PATH) then
            makefolder(MACRO_FOLDER_PATH)
            print("[SUPERTOOL] Created macro folder: " .. MACRO_FOLDER_PATH)
            return {}
        end
        
        local loadedMacros = {}
        local files = listfiles(MACRO_FOLDER_PATH)
        local totalFiles = 0
        local loadedCount = 0
        local errorCount = 0
        
        for _, filePath in pairs(files) do
            if string.match(filePath, "%.json$") then
                totalFiles = totalFiles + 1
                local fileName = string.match(filePath, "([^/\\]+)%.json$")
                if fileName then
                    local macroData = loadFromJSONFile(fileName)
                    if macroData and macroData.frames and #macroData.frames > 0 then
                        local originalName = macroData.name or fileName
                        loadedMacros[originalName] = macroData
                        loadedCount = loadedCount + 1
                        print("[SUPERTOOL] Loaded macro: " .. originalName .. " (" .. #macroData.frames .. " frames)")
                    else
                        errorCount = errorCount + 1
                        warn("[SUPERTOOL] Failed to load macro: " .. fileName)
                    end
                end
            end
        end
        
        print("[SUPERTOOL] Macro loading complete: " .. loadedCount .. "/" .. totalFiles .. " files loaded" .. (errorCount > 0 and " (" .. errorCount .. " errors)" or ""))
        return loadedMacros
    end)
    
    if success then
        return result or {}
    else
        warn("[SUPERTOOL] Failed to load macros from folder: " .. tostring(result))
        return {}
    end
end

-- Mock file system for backward compatibility
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
    saveToJSONFile(macroName, macroData)
end

local function loadFromFileSystem(macroName)
    local jsonData = loadFromJSONFile(macroName)
    if jsonData then
        return jsonData
    end
    
    ensureFileSystem()
    return fileSystem["Supertool/Macro"][macroName]
end

local function deleteFromFileSystem(macroName)
    ensureFileSystem()
    local memoryDeleted = false
    if fileSystem["Supertool/Macro"][macroName] then
        fileSystem["Supertool/Macro"][macroName] = nil
        memoryDeleted = true
    end
    
    local jsonDeleted = deleteFromJSONFile(macroName)
    
    return memoryDeleted or jsonDeleted
end

local function renameInFileSystem(oldName, newName)
    ensureFileSystem()
    local memoryRenamed = false
    
    if fileSystem["Supertool/Macro"][oldName] and newName ~= "" then
        fileSystem["Supertool/Macro"][newName] = fileSystem["Supertool/Macro"][oldName]
        fileSystem["Supertool/Macro"][oldName] = nil
        memoryRenamed = true
    end
    
    local jsonRenamed = renameInJSONFile(oldName, newName)
    
    return memoryRenamed or jsonRenamed
end

local function syncMacrosFromJSON()
    print("[SUPERTOOL] Starting macro sync from JSON files...")
    local jsonMacros = loadAllMacrosFromFolder()
    local syncedCount = 0
    
    for macroName, macroData in pairs(jsonMacros) do
        if macroData and macroData.frames and #macroData.frames > 0 then
            savedMacros[macroName] = macroData
            fileSystem["Supertool/Macro"][macroName] = macroData
            syncedCount = syncedCount + 1
        else
            warn("[SUPERTOOL] Skipped invalid macro during sync: " .. macroName)
        end
    end
    
    print("[SUPERTOOL] Sync complete: " .. syncedCount .. " macros loaded from JSON files")
    return syncedCount
end

-- Admin Command Functions
local function detectAdminCommands()
    adminCommands = {}
    adminList = {}
    
    local success, result = pcall(function()
        -- Mock detection of admin commands (simulating Infinite Yield style)
        local possibleCommands = {
            {cmd = "fly", desc = "Enables flying"},
            {cmd = "noclip", desc = "Disables collision"},
            {cmd = "god", desc = "Grants invincibility"},
            {cmd = "speed", desc = "Sets walk speed"},
            {cmd = "tp", desc = "Teleports player"},
            {cmd = "kill", desc = "Kills target player"},
            {cmd = "ban", desc = "Bans target player"},
            {cmd = "kick", desc = "Kicks target player"}
        }
        
        for _, cmdData in pairs(possibleCommands) do
            table.insert(adminCommands, {
                command = cmdData.cmd,
                description = cmdData.desc
            })
        end
        
        -- Detect admins (mock implementation)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player then
                table.insert(adminList, p.Name)
            end
        end
        
        return true
    end)
    
    if success then
        print("[SUPERTOOL] Detected " .. #adminCommands .. " admin commands and " .. #adminList .. " admins")
    else
        warn("[SUPERTOOL] Failed to detect admin commands: " .. tostring(result))
    end
end

local function executeAdminCommand(command, args)
    local success, error = pcall(function()
        -- Simulate command execution with bypass
        print("[SUPERTOOL] Executing command: " .. command .. " " .. (args or ""))
        -- Mock implementation (replace with actual command execution logic)
        if command == "fly" then
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Flying)
            end
        elseif command == "speed" and args then
            if humanoid then
                humanoid.WalkSpeed = tonumber(args) or 16
            end
        end
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to execute command " .. command .. ": " .. tostring(error))
    end
end

local function showAdminPanel()
    adminFrameVisible = true
    if not AdminFrame then
        initAdminUI()
    end
    AdminFrame.Visible = true
    detectAdminCommands()
    Utility.updateAdminList()
end

local function initAdminUI()
    if AdminFrame then return end
    
    AdminFrame = Instance.new("Frame")
    AdminFrame.Name = "AdminFrame"
    AdminFrame.Parent = ScreenGui
    AdminFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    AdminFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    AdminFrame.BorderSizePixel = 1
    AdminFrame.Position = UDim2.new(0.35, 0, 0.1, 0)
    AdminFrame.Size = UDim2.new(0, 450, 0, 500)
    AdminFrame.Visible = adminFrameVisible
    AdminFrame.Active = true
    AdminFrame.Draggable = true

    local title = Instance.new("TextLabel")
    title.Parent = AdminFrame
    title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    title.BorderSizePixel = 0
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Font = Enum.Font.GothamBold
    title.Text = "ADMIN COMMAND PANEL"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 9

    local closeBtn = Instance.new("TextButton")
    closeBtn.Parent = AdminFrame
    closeBtn.BackgroundTransparency = 1
    closeBtn.Position = UDim2.new(1, -25, 0, 2)
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeBtn.TextSize = 10

    local commandInput = Instance.new("TextBox")
    commandInput.Parent = AdminFrame
    commandInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    commandInput.BorderSizePixel = 0
    commandInput.Position = UDim2.new(0, 10, 0, 35)
    commandInput.Size = UDim2.new(1, -120, 0, 30)
    commandInput.Font = Enum.Font.Gotham
    commandInput.PlaceholderText = "Enter command..."
    commandInput.Text = ""
    commandInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    commandInput.TextSize = 8

    local executeButton = Instance.new("TextButton")
    executeButton.Parent = AdminFrame
    executeButton.BackgroundColor3 = Color3.fromRGB(80, 120, 80)
    executeButton.BorderSizePixel = 0
    executeButton.Position = UDim2.new(1, -100, 0, 35)
    executeButton.Size = UDim2.new(0, 90, 0, 30)
    executeButton.Font = Enum.Font.GothamBold
    executeButton.Text = "EXECUTE"
    executeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    executeButton.TextSize = 9

    AdminStatusLabel = Instance.new("TextLabel")
    AdminStatusLabel.Parent = AdminFrame
    AdminStatusLabel.BackgroundTransparency = 1
    AdminStatusLabel.Position = UDim2.new(0, 10, 0, 75)
    AdminStatusLabel.Size = UDim2.new(1, -20, 0, 15)
    AdminStatusLabel.Font = Enum.Font.Gotham
    AdminStatusLabel.Text = "Ready to execute commands"
    AdminStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    AdminStatusLabel.TextSize = 7
    AdminStatusLabel.TextXAlignment = Enum.TextXAlignment.Left

    local adminListLabel = Instance.new("TextLabel")
    adminListLabel.Parent = AdminFrame
    adminListLabel.BackgroundTransparency = 1
    adminListLabel.Position = UDim2.new(0, 10, 0, 95)
    adminListLabel.Size = UDim2.new(1, -20, 0, 15)
    adminListLabel.Font = Enum.Font.Gotham
    adminListLabel.Text = "Admins: " .. (#adminList > 0 and table.concat(adminList, ", ") or "None detected")
    adminListLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
    adminListLabel.TextSize = 7
    adminListLabel.TextXAlignment = Enum.TextXAlignment.Left

    AdminScrollFrame = Instance.new("ScrollingFrame")
    AdminScrollFrame.Parent = AdminFrame
    AdminScrollFrame.BackgroundTransparency = 1
    AdminScrollFrame.Position = UDim2.new(0, 10, 0, 115)
    AdminScrollFrame.Size = UDim2.new(1, -20, 1, -125)
    AdminScrollFrame.ScrollBarThickness = 4
    AdminScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
    AdminScrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    AdminScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)

    AdminLayout = Instance.new("UIListLayout")
    AdminLayout.Parent = AdminScrollFrame
    AdminLayout.Padding = UDim.new(0, 3)
    AdminLayout.SortOrder = Enum.SortOrder.LayoutOrder

    executeButton.MouseButton1Click:Connect(function()
        local input = commandInput.Text
        if input ~= "" then
            local parts = string.split(input, " ")
            local cmd = parts[1]
            local args = table.concat(parts, " ", 2)
            executeAdminCommand(cmd, args)
            commandInput.Text = ""
        end
    end)

    commandInput.FocusLost:Connect(function(enterPressed)
        if enterPressed and commandInput.Text ~= "" then
            local parts = string.split(commandInput.Text, " ")
            local cmd = parts[1]
            local args = table.concat(parts, " ", 2)
            executeAdminCommand(cmd, args)
            commandInput.Text = ""
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        adminFrameVisible = false
        AdminFrame.Visible = false
    end)
end

function Utility.updateAdminList()
    if not AdminScrollFrame then return end
    
    for _, child in pairs(AdminScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    for i, cmdData in ipairs(adminCommands) do
        local cmdFrame = Instance.new("Frame")
        cmdFrame.Name = "Command" .. i
        cmdFrame.Parent = AdminScrollFrame
        cmdFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        cmdFrame.BorderSizePixel = 0
        cmdFrame.Size = UDim2.new(1, -5, 0, 50)
        cmdFrame.LayoutOrder = i
        
        local cmdLabel = Instance.new("TextLabel")
        cmdLabel.Parent = cmdFrame
        cmdLabel.BackgroundTransparency = 1
        cmdLabel.Position = UDim2.new(0, 5, 0, 5)
        cmdLabel.Size = UDim2.new(1, -10, 0, 15)
        cmdLabel.Font = Enum.Font.Gotham
        cmdLabel.Text = cmdData.command
        cmdLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        cmdLabel.TextSize = 7
        cmdLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local descLabel = Instance.new("TextLabel")
        descLabel.Parent = cmdFrame
        descLabel.BackgroundTransparency = 1
        descLabel.Position = UDim2.new(0, 5, 0, 20)
        descLabel.Size = UDim2.new(1, -10, 0, 15)
        descLabel.Font = Enum.Font.Gotham
        descLabel.Text = cmdData.description
        descLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        descLabel.TextSize = 6
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local executeBtn = Instance.new("TextButton")
        executeBtn.Parent = cmdFrame
        executeBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
        executeBtn.BorderSizePixel = 0
        executeBtn.Position = UDim2.new(0.7, 5, 0, 5)
        executeBtn.Size = UDim2.new(0.3, -10, 0, 25)
        executeBtn.Font = Enum.Font.Gotham
        executeBtn.Text = "EXECUTE"
        executeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        executeBtn.TextSize = 7
        
        executeBtn.MouseButton1Click:Connect(function()
            executeAdminCommand(cmdData.command)
        end)
    end
    
    task.wait(0.1)
    if AdminLayout then
        local contentSize = AdminLayout.AbsoluteContentSize
        AdminScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 10)
    end
    
    if AdminStatusLabel then
        AdminStatusLabel.Text = "Detected " .. #adminCommands .. " commands"
    end
end

-- Update macro status display
local function updateMacroStatus()
    if not MacroStatusLabel then return end
    if macroRecording then
        MacroStatusLabel.Text = recordingPaused and "Recording Paused" or "Recording Macro"
        MacroStatusLabel.Visible = true
    elseif macroPlaying and currentMacroName then
        local macro = savedMacros[currentMacroName] or loadFromFileSystem(currentMacroName)
        local speed = macro and macro.speed or 1
        MacroStatusLabel.Text = (autoPlaying and "Auto-Playing Macro: " or "Playing Macro: ") .. currentMacroName .. " (Speed: " .. speed .. "x)"
        MacroStatusLabel.Visible = true
    else
        MacroStatusLabel.Visible = false
    end
end

-- Update character references
local function updateCharacterReferences()
    if player.Character then
        humanoid = player.Character:WaitForChild("Humanoid", 30)
        rootPart = player.Character:WaitForChild("HumanoidRootPart", 30)
        if macroRecording and recordingPaused then
            recordingPaused = false
            updateMacroStatus()
        end
    end
end

local function startMacroRecording()
    if macroRecording or macroPlaying then return end
    
    if not player.Character or not player.Character:FindFirstChild("Humanoid") or not player.Character:FindFirstChild("HumanoidRootPart") then
        warn("[SUPERTOOL] Cannot start recording: Character not ready")
        return
    end
    
    macroRecording = true
    recordingPaused = false
    currentMacro = {frames = {}, startTime = tick(), speed = 1}
    lastFrameTime = 0
    
    updateCharacterReferences()
    updateMacroStatus()
    
    local function setupDeathHandler()
        if humanoid then
            humanoid.Died:Connect(function()
                if macroRecording then
                    recordingPaused = true
                    updateMacroStatus()
                end
            end)
        end
    end
    
    setupDeathHandler()
    
    recordConnection = RunService.Heartbeat:Connect(function()
        if not macroRecording or recordingPaused then return end
        
        if not humanoid or not rootPart or not humanoid.Parent or not rootPart.Parent then
            updateCharacterReferences()
            if not humanoid or not rootPart then return end
            setupDeathHandler()
        end
        
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
        
        if success and frame and frame.time and frame.cframe and frame.velocity then
            table.insert(currentMacro.frames, frame)
            lastFrameTime = frame.time
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
        macroName = "Macro_" .. os.date("%H%M%S") .. "_" .. (#savedMacros + 1)
    end
    
    if #currentMacro.frames == 0 then
        warn("[SUPERTOOL] Cannot save empty macro")
        updateMacroStatus()
        return
    end
    
    local validFrameCount = 0
    for i, frame in pairs(currentMacro.frames) do
        if validateFrame(frame) then
            validFrameCount = validFrameCount + 1
        end
    end
    
    if validFrameCount == 0 then
        warn("[SUPERTOOL] Cannot save macro: No valid frames found")
        updateMacroStatus()
        return
    end
    
    currentMacro.frameCount = #currentMacro.frames
    currentMacro.duration = currentMacro.frames[#currentMacro.frames].time
    currentMacro.created = os.time()
    
    savedMacros[macroName] = currentMacro
    local saveSuccess = saveToFileSystem(macroName, currentMacro)
    
    if saveSuccess then
        MacroInput.Text = ""
        Utility.updateMacroList()
        updateMacroStatus()
        if MacroFrame then
            MacroFrame.Visible = true
        end
        
        print("[SUPERTOOL] Macro recorded and saved: " .. macroName .. " (" .. #currentMacro.frames .. " frames, " .. validFrameCount .. " valid)")
    else
        warn("[SUPERTOOL] Failed to save macro: " .. macroName)
    end
end

local function stopMacroPlayback()
    if not macroPlaying then return end
    macroPlaying = false
    autoPlaying = false
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

local function playMacro(macroName, autoPlay)
    if macroRecording or macroPlaying then return end
    
    if not player.Character or not player.Character:FindFirstChild("Humanoid") or not player.Character:FindFirstChild("HumanoidRootPart") then
        warn("[SUPERTOOL] Cannot play macro: Character not ready")
        return
    end
    
    updateCharacterReferences()
    if not humanoid or not rootPart then
        warn("[SUPERTOOL] Cannot play macro: Failed to get character references")
        return
    end
    
    local macro = savedMacros[macroName] or loadFromFileSystem(macroName)
    if not macro or not macro.frames or #macro.frames == 0 then
        warn("[SUPERTOOL] Cannot play macro: Invalid or empty macro data for " .. macroName)
        return
    end
    
    local validFrames = {}
    for i, frame in pairs(macro.frames) do
        local validFrame = validateFrame(frame)
        if validFrame then
            table.insert(validFrames, validFrame)
        end
    end
    
    if #validFrames == 0 then
        warn("[SUPERTOOL] Cannot play macro: No valid frames in " .. macroName)
        return
    end
    
    if #validFrames < #macro.frames then
        warn("[SUPERTOOL] Playing macro with " .. (#macro.frames - #validFrames) .. " invalid frames skipped")
        macro.frames = validFrames
        macro.frameCount = #validFrames
        macro.duration = validFrames[#validFrames].time
        savedMacros[macroName] = macro
        saveToFileSystem(macroName, macro)
    end
    
    macroPlaying = true
    autoPlaying = autoPlay or false
    currentMacroName = macroName
    humanoid.WalkSpeed = 0
    updateMacroStatus()
    
    print("[SUPERTOOL] Playing macro: " .. macroName .. " (Auto: " .. tostring(autoPlaying) .. ", Speed: " .. (macro.speed or 1) .. "x, Frames: " .. #validFrames .. ")")
    
    local function playSingleMacro()
        local startTime = tick()
        local index = 1
        local speed = macro.speed or 1
        
        playbackConnection = RunService.Heartbeat:Connect(function()
            if not macroPlaying or not player.Character then
                if playbackConnection then playbackConnection:Disconnect() end
                macroPlaying = false
                autoPlaying = false
                if humanoid then humanoid.WalkSpeed = settings.WalkSpeed.value or 16 end
                currentMacroName = nil
                Utility.updateMacroList()
                updateMacroStatus()
                return
            end
            
            if not humanoid or not rootPart or not humanoid.Parent or not rootPart.Parent then
                updateCharacterReferences()
                if not humanoid or not rootPart then
                    if playbackConnection then playbackConnection:Disconnect() end
                    macroPlaying = false
                    autoPlaying = false
                    currentMacroName = nil
                    Utility.updateMacroList()
                    updateMacroStatus()
                    return
                end
            end
            
            if index > #validFrames then
                if autoPlaying then
                    index = 1
                    startTime = tick()
                else
                    if playbackConnection then playbackConnection:Disconnect() end
                    macroPlaying = false
                    humanoid.WalkSpeed = settings.WalkSpeed.value or 16
                    currentMacroName = nil
                    Utility.updateMacroList()
                    updateMacroStatus()
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
                    warn("[SUPERTOOL] Error applying frame " .. index .. " in macro " .. macroName)
                end
                
                index = index + 1
                if index <= #validFrames then
                    frame = validFrames[index]
                    scaledTime = frame.time / speed
                end
            end
        end)
    end
    
    playSingleMacro()
end

local function deleteMacro(macroName)
    if savedMacros[macroName] then
        if macroPlaying and currentMacroName == macroName then
            stopMacroPlayback()
        end
        savedMacros[macroName] = nil
        deleteFromFileSystem(macroName)
        Utility.updateMacroList()
        print("[SUPERTOOL] Macro deleted: " .. macroName)
    end
end

local function renameMacro(oldName, newName)
    if savedMacros[oldName] and newName ~= "" then
        if renameInFileSystem(oldName, newName) then
            if currentMacroName == oldName then
                currentMacroName = newName
                updateMacroStatus()
            end
            savedMacros[newName] = savedMacros[oldName]
            savedMacros[oldName] = nil
            Utility.updateMacroList()
            print("[SUPERTOOL] Macro renamed: " .. oldName .. " -> " .. newName)
        end
    end
end

local function showMacroManager()
    macroFrameVisible = true
    if not MacroFrame then
        initMacroUI()
    end
    MacroFrame.Visible = true
    Utility.updateMacroList()
end

function Utility.updateMacroList()
    if not MacroScrollFrame then return end
    
    for _, child in pairs(MacroScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local itemCount = 0
    
    local infoFrame = Instance.new("Frame")
    infoFrame.Name = "InfoFrame"
    infoFrame.Parent = MacroScrollFrame
    infoFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    infoFrame.BorderSizePixel = 0
    infoFrame.Size = UDim2.new(1, -5, 0, 25)
    infoFrame.LayoutOrder = -1
    
    local macroCount = 0
    for _ in pairs(savedMacros) do
        macroCount = macroCount + 1
    end
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Parent = infoFrame
    infoLabel.BackgroundTransparency = 1
    infoLabel.Size = UDim2.new(1, 0, 1, 0)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Text = "JSON Sync: " .. MACRO_FOLDER_PATH .. " (" .. macroCount .. " macros)"
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    infoLabel.TextSize = 7
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    for macroName, macro in pairs(savedMacros) do
        if not macro or not macro.frames or type(macro.frames) ~= "table" then
            warn("[SUPERTOOL] Skipping invalid macro in UI: " .. macroName)
            continue
        end
        
        local macroItem = Instance.new("Frame")
        macroItem.Name = macroName .. "Item"
        macroItem.Parent = MacroScrollFrame
        macroItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        macroItem.BorderSizePixel = 0
        macroItem.Size = UDim2.new(1, -5, 0, 110)
        macroItem.LayoutOrder = itemCount
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Parent = macroItem
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.new(0, 5, 0, 5)
        nameLabel.Size = UDim2.new(1, -10, 0, 15)
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.Text = macroName
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize = 7
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local frameCount = macro.frameCount or (macro.frames and #macro.frames) or 0
        local duration = macro.duration or (macro.frames and #macro.frames > 0 and macro.frames[#macro.frames] and macro.frames[#macro.frames].time) or 0
        local speed = macro.speed or 1
        
        local validFrameCount = 0
        if macro.frames then
            for _, frame in pairs(macro.frames) do
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
        
        local macroInfoLabel = Instance.new("TextLabel")
        macroInfoLabel.Parent = macroItem
        macroInfoLabel.BackgroundTransparency = 1
        macroInfoLabel.Position = UDim2.new(0, 5, 0, 20)
        macroInfoLabel.Size = UDim2.new(1, -10, 0, 10)
        macroInfoLabel.Font = Enum.Font.Gotham
        macroInfoLabel.Text = infoText
        macroInfoLabel.TextColor3 = statusColor
        macroInfoLabel.TextSize = 6
        macroInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local renameInput = Instance.new("TextBox")
        renameInput.Name = "RenameInput"
        renameInput.Parent = macroItem
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
        speedLabel.Parent = macroItem
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
        speedInput.Parent = macroItem
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
        buttonFrame.Parent = macroItem
        buttonFrame.BackgroundTransparency = 1
        buttonFrame.Position = UDim2.new(0, 5, 0, 75)
        buttonFrame.Size = UDim2.new(1, -10, 0, 15)
        
        local canPlay = validFrameCount > 0
        local playButtonColor = canPlay and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(40, 40, 40)
        local autoButtonColor = canPlay and Color3.fromRGB(60, 80, 60) or Color3.fromRGB(40, 50, 40)
        
        if macroPlaying and currentMacroName == macroName then
            playButtonColor = Color3.fromRGB(100, 100, 100)
            autoButtonColor = Color3.fromRGB(100, 100, 100)
        end
        
        local playButton = Instance.new("TextButton")
        playButton.Name = "PlayButton"
        playButton.Parent = buttonFrame
        playButton.BackgroundColor3 = playButtonColor
        playButton.BorderSizePixel = 0
        playButton.Position = UDim2.new(0, 0, 0, 0)
        playButton.Size = UDim2.new(0, 40, 0, 15)
        playButton.Font = Enum.Font.Gotham
        playButton.Text = (macroPlaying and currentMacroName == macroName and not autoPlaying) and "PLAYING" or (canPlay and "PLAY" or "INVALID")
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
        autoPlayButton.Text = (macroPlaying and currentMacroName == macroName and autoPlaying) and "STOP" or (canPlay and "AUTO" or "INVALID")
        autoPlayButton.TextColor3 = canPlay and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
        autoPlayButton.TextSize = 7
        
        local deleteButton = Instance.new("TextButton")
        deleteButton.Name = "DeleteButton"
        deleteButton.Parent = buttonFrame
        deleteButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
        deleteButton.BorderSizePixel = 0
        deleteButton.Position = UDim2.new(0, 90, 0, 0)
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
        renameButton.Position = UDim2.new(0, 135, 0, 0)
        renameButton.Size = UDim2.new(0, 40, 0, 15)
        renameButton.Font = Enum.Font.Gotham
        renameButton.Text = "RENAME"
        renameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        renameButton.TextSize = 7
        
        local buttonFrame2 = Instance.new("Frame")
        buttonFrame2.Name = "ButtonFrame2"
        buttonFrame2.Parent = macroItem
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
        
        local fileStatusLabel = Instance.new("TextLabel")
        fileStatusLabel.Name = "FileStatusLabel"
        fileStatusLabel.Parent = buttonFrame2
        fileStatusLabel.BackgroundTransparency = 1
        fileStatusLabel.Position = UDim2.new(0, 100, 0, 0)
        fileStatusLabel.Size = UDim2.new(1, -100, 0, 15)
        fileStatusLabel.Font = Enum.Font.Gotham
        fileStatusLabel.Text = "📁 " .. sanitizeFileName(macroName) .. ".json"
        fileStatusLabel.TextColor3 = canPlay and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 150, 100)
        fileStatusLabel.TextSize = 6
        fileStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        speedInput.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local newSpeed = tonumber(speedInput.Text)
                if newSpeed and newSpeed > 0 and newSpeed <= 10 then
                    macro.speed = newSpeed
                    saveToFileSystem(macroName, macro)
                    updateMacroStatus()
                    print("[SUPERTOOL] Updated speed for " .. macroName .. ": " .. newSpeed .. "x")
                else
                    speedInput.Text = tostring(macro.speed or 1)
                    warn("[SUPERTOOL] Invalid speed value. Must be between 0.1 and 10")
                end
            end
        end)
        
        playButton.MouseButton1Click:Connect(function()
            if not canPlay then 
                warn("[SUPERTOOL] Cannot play invalid macro: " .. macroName)
                return 
            end
            
            if macroPlaying and currentMacroName == macroName and not autoPlaying then
                stopMacroPlayback()
            else
                playMacro(macroName, false)
                Utility.updateMacroList()
            end
        end)
        
        autoPlayButton.MouseButton1Click:Connect(function()
            if not canPlay then 
                warn("[SUPERTOOL] Cannot auto-play invalid macro: " .. macroName)
                return 
            end
            
            if macroPlaying and currentMacroName == macroName and autoPlaying then
                stopMacroPlayback()
            else
                playMacro(macroName, true)
                Utility.updateMacroList()
            end
        end)
        
        deleteButton.MouseButton1Click:Connect(function()
            deleteMacro(macroName)
        end)
        
        renameButton.MouseButton1Click:Connect(function()
            if renameInput.Text ~= "" then
                renameMacro(macroName, renameInput.Text)
                renameInput.Text = ""
            end
        end)
        
        renameInput.FocusLost:Connect(function(enterPressed)
            if enterPressed and renameInput.Text ~= "" then
                renameMacro(macroName, renameInput.Text)
                renameInput.Text = ""
            end
        end)
        
        fixButton.MouseButton1Click:Connect(function()
            if canPlay then
                saveToJSONFile(macroName, macro)
                fileStatusLabel.Text = "📁 ✓ " .. sanitizeFileName(macroName) .. ".json"
                fileStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            else
                local originalMacro = loadFromJSONFile(macroName)
                if originalMacro and originalMacro.frames and #originalMacro.frames > 0 then
                    savedMacros[macroName] = originalMacro
                    Utility.updateMacroList()
                    fileStatusLabel.Text = "🔧 Fixed from JSON!"
                    fileStatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                else
                    fileStatusLabel.Text = "❌ Cannot fix - No valid data"
                    fileStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                end
            end
            
            task.wait(2)
            fileStatusLabel.Text = "📁 " .. sanitizeFileName(macroName) .. ".json"
            fileStatusLabel.TextColor3 = canPlay and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 150, 100)
        end)
        
        exportButton.MouseButton1Click:Connect(function()
            fileStatusLabel.Text = "📤 Exported to JSON!"
            fileStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
            saveToJSONFile(macroName, macro)
            task.wait(2)
            fileStatusLabel.Text = "📁 " .. sanitizeFileName(macroName) .. ".json"
            fileStatusLabel.TextColor3 = canPlay and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 150, 100)
        end)
        
        if canPlay then
            playButton.MouseEnter:Connect(function()
                if not (macroPlaying and currentMacroName == macroName and not autoPlaying) then
                    playButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                end
            end)
            
            playButton.MouseLeave:Connect(function()
                if macroPlaying and currentMacroName == macroName and not autoPlaying then
                    playButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                else
                    playButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                end
            end)
            
            autoPlayButton.MouseEnter:Connect(function()
                if not (macroPlaying and currentMacroName == macroName and autoPlaying) then
                    autoPlayButton.BackgroundColor3 = Color3.fromRGB(80, 100, 80)
                end
            end)
            
            autoPlayButton.MouseLeave:Connect(function()
                if macroPlaying and currentMacroName == macroName and autoPlaying then
                    autoPlayButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                else
                    autoPlayButton.BackgroundColor3 = Color3.fromRGB(60, 80, 60)
                end
            end)
        end
        
        deleteButton.MouseEnter:Connect(function()
            deleteButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        end)
        
        deleteButton.MouseLeave:Connect(function()
            deleteButton.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
        end)
        
        renameButton.MouseEnter:Connect(function()
            renameButton.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
        end)
        
        renameButton.MouseLeave:Connect(function()
            renameButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
        end)
        
        fixButton.MouseEnter:Connect(function()
            if canPlay then
                fixButton.BackgroundColor3 = Color3.fromRGB(100, 80, 150)
            else
                fixButton.BackgroundColor3 = Color3.fromRGB(150, 100, 80)
            end
        end)
        
        fixButton.MouseLeave:Connect(function()
            if canPlay then
                fixButton.BackgroundColor3 = Color3.fromRGB(80, 60, 120)
            else
                fixButton.BackgroundColor3 = Color3.fromRGB(120, 80, 60)
            end
        end)
        
        exportButton.MouseEnter:Connect(function()
            exportButton.BackgroundColor3 = Color3.fromRGB(80, 150, 100)
        end)
        
        exportButton.MouseLeave:Connect(function()
            exportButton.BackgroundColor3 = Color3.fromRGB(60, 120, 80)
        end)
        
        itemCount = itemCount + 1
    end
    
    if itemCount > 0 then
        local utilityFrame = Instance.new("Frame")
        utilityFrame.Name = "UtilityFrame"
        utilityFrame.Parent = MacroScrollFrame
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
        statusLabel.Text = "Total: " .. itemCount .. " macros loaded"
        statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        statusLabel.TextSize = 7
        statusLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        refreshButton.MouseButton1Click:Connect(function()
            statusLabel.Text = "Refreshing..."
            local count = syncMacrosFromJSON()
            Utility.updateMacroList()
            statusLabel.Text = "Refreshed: " .. count .. " macros loaded"
            task.wait(2)
            statusLabel.Text = "Total: " .. itemCount .. " macros loaded"
        end)
        
        syncAllButton.MouseButton1Click:Connect(function()
            statusLabel.Text = "Syncing all..."
            local count = 0
            for name, data in pairs(savedMacros) do
                if saveToJSONFile(name, data) then
                    count = count + 1
                end
            end
            statusLabel.Text = "Synced: " .. count .. " macros to JSON"
            task.wait(2)
            statusLabel.Text = "Total: " .. itemCount .. " macros loaded"
            print("[SUPERTOOL] Synced " .. count .. " macros to JSON files")
        end)
        
        fixAllButton.MouseButton1Click:Connect(function()
            statusLabel.Text = "Fixing all macros..."
            local fixedCount = 0
            local totalCount = 0
            
            for macroName, macro in pairs(savedMacros) do
                totalCount = totalCount + 1
                
                if macro and macro.frames then
                    local validFrames = {}
                    for i, frame in pairs(macro.frames) do
                        local validFrame = validateFrame(frame)
                        if validFrame then
                            table.insert(validFrames, validFrame)
                        end
                    end
                    
                    if #validFrames > 0 then
                        macro.frames = validFrames
                        macro.frameCount = #validFrames
                        macro.duration = validFrames[#validFrames].time
                        macro.modified = os.time()
                        saveToJSONFile(macroName, macro)
                        fixedCount = fixedCount + 1
                    end
                end
            end
            
            Utility.updateMacroList()
            statusLabel.Text = "Fixed: " .. fixedCount .. "/" .. totalCount .. " macros"
            task.wait(3)
            statusLabel.Text = "Total: " .. itemCount .. " macros loaded"
            print("[SUPERTOOL] Fixed " .. fixedCount .. "/" .. totalCount .. " macros")
        end)
    end
    
    task.wait(0.1)
    if MacroLayout then
        local contentSize = MacroLayout.AbsoluteContentSize
        MacroScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 5)
    end
end

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
    MacroFrame.Visible = macroFrameVisible
    MacroFrame.Active = true
    MacroFrame.Draggable = true

    local MacroTitle = Instance.new("TextLabel")
    MacroTitle.Name = "Title"
    MacroTitle.Parent = MacroFrame
    MacroTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    MacroTitle.BorderSizePixel = 0
    MacroTitle.Size = UDim2.new(1, 0, 0, 20)
    MacroTitle.Font = Enum.Font.Gotham
    MacroTitle.Text = "MACRO MANAGER - JSON SYNC v1.1"
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
    CloseMacroButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseMacroButton.TextSize = 8

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
    SaveMacroButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
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

    MacroStatusLabel = Instance.new("TextLabel")
    MacroStatusLabel.Name = "MacroStatusLabel"
    MacroStatusLabel.Parent = ScreenGui
    MacroStatusLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    MacroStatusLabel.BorderColor3 = Color3.fromRGB(45, 45, 45)
    MacroStatusLabel.BorderSizePixel = 1
    MacroStatusLabel.Position = UDim2.new(1, -200, 0, 10)
    MacroStatusLabel.Size = UDim2.new(0, 190, 0, 20)
    MacroStatusLabel.Font = Enum.Font.Gotham
    MacroStatusLabel.Text = ""
    MacroStatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    MacroStatusLabel.TextSize = 8
    MacroStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    MacroStatusLabel.Visible = false

    SaveMacroButton.MouseButton1Click:Connect(function()
        stopMacroRecording()
        MacroFrame.Visible = true
    end)
    
    CloseMacroButton.MouseButton1Click:Connect(function()
        macroFrameVisible = false
        MacroFrame.Visible = false
    end)
end

local function killPlayer()
    if humanoid then
        humanoid.Health = 0
    end
end

local function resetCharacter()
    if player and player.Character then
        player:LoadCharacter()
    end
end

function Utility.loadUtilityButtons(createButton)
    createButton("Kill Player", killPlayer)
    createButton("Reset Character", resetCharacter)
    createButton("Record Macro", startMacroRecording)
    createButton("Stop Macro", stopMacroRecording)
    createButton("Macro Manager", showMacroManager)
    createButton("Admin Commands", showAdminPanel)
end

function Utility.resetStates()
    macroRecording = false
    macroPlaying = false
    autoPlaying = false
    recordingPaused = false
    
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
    
    adminFrameVisible = false
    adminCommands = {}
    adminList = {}
    
    if AdminFrame then
        AdminFrame.Visible = false
    end
    
    updateMacroStatus()
    Utility.updateMacroList()
    
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
    
    macroRecording = false
    macroPlaying = false
    autoPlaying = false
    recordingPaused = false
    currentMacro = {}
    macroFrameVisible = false
    currentMacroName = nil
    lastFrameTime = 0
    
    adminFrameVisible = false
    adminCommands = {}
    adminList = {}
    
    local success, error = pcall(function()
        if not isfolder("Supertool") then
            makefolder("Supertool")
            print("[SUPERTOOL] Created Supertool folder")
        end
        if not isfolder(MACRO_FOLDER_PATH) then
            makefolder(MACRO_FOLDER_PATH)
            print("[SUPERTOOL] Created macro folder: " .. MACRO_FOLDER_PATH)
        end
    end)
    
    if not success then
        warn("[SUPERTOOL] Failed to create folder structure: " .. tostring(error))
    end
    
    ensureFileSystem()
    
    print("[SUPERTOOL] Loading macros from JSON files...")
    local loadedCount = syncMacrosFromJSON()
    
    local legacyCount = 0
    if fileSystem["Supertool/Macro"] then
        for macroName, macroData in pairs(fileSystem["Supertool/Macro"]) do
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
    
    print("[SUPERTOOL] Macro loading complete: " .. loadedCount .. " from JSON, " .. legacyCount .. " from legacy")
    
    task.spawn(function()
        initMacroUI()
        initAdminUI()
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
                        
                        if macroPlaying and currentMacroName then
                            print("[SUPERTOOL] Resuming macro playback: " .. currentMacroName)
                            if autoPlaying then
                                playMacro(currentMacroName, true)
                            else
                                playMacro(currentMacroName, false)
                            end
                        end
                        
                        updateMacroStatus()
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
            if macroPlaying then
                print("[SUPERTOOL] Macro playback paused due to character removal")
            end
        end)
    end
    
    detectAdminCommands()
    
    print("[SUPERTOOL] Utility module fully initialized")
    print("  - JSON Path: " .. MACRO_FOLDER_PATH)
    print("  - Total Macros: " .. (#savedMacros > 0 and tostring(#savedMacros) or "0"))
    print("  - Version: 1.1 (Enhanced Validation)")
end

return Utility