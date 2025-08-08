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

-- Mock file system for DCIM/Supertool
local fileSystem = {
    ["DCIM/Supertool"] = {}
}

-- Helper function to ensure DCIM/Supertool exists
local function ensureFileSystem()
    if not fileSystem["DCIM"] then
        fileSystem["DCIM"] = {}
    end
    if not fileSystem["DCIM/Supertool"] then
        fileSystem["DCIM/Supertool"] = {}
    end
end

-- Helper function to save macro to file system
local function saveToFileSystem(macroName, macroData)
    ensureFileSystem()
    fileSystem["DCIM/Supertool"][macroName] = macroData
end

-- Helper function to load macro from file system
local function loadFromFileSystem(macroName)
    ensureFileSystem()
    return fileSystem["DCIM/Supertool"][macroName]
end

-- Helper function to delete macro from file system
local function deleteFromFileSystem(macroName)
    ensureFileSystem()
    if fileSystem["DCIM/Supertool"][macroName] then
        fileSystem["DCIM/Supertool"][macroName] = nil
        return true
    end
    return false
end

-- Helper function to rename macro in file system
local function renameInFileSystem(oldName, newName)
    ensureFileSystem()
    if fileSystem["DCIM/Supertool"][oldName] and newName ~= "" then
        fileSystem["DCIM/Supertool"][newName] = fileSystem["DCIM/Supertool"][oldName]
        fileSystem["DCIM/Supertool"][oldName] = nil
        return true
    end
    return false
end

-- Update macro status display
local function updateMacroStatus()
    if not MacroStatusLabel then return end
    if macroRecording then
        MacroStatusLabel.Text = recordingPaused and "Recording Paused" or "Recording Macro"
        MacroStatusLabel.Visible = true
    elseif macroPlaying and currentMacroName then
        MacroStatusLabel.Text = (autoPlaying and "Auto-Playing Macro: " or "Playing Macro: ") .. currentMacroName
        MacroStatusLabel.Visible = true
    else
        MacroStatusLabel.Visible = false
    end
end

-- Update character references after respawn
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

-- Record Macro
local function startMacroRecording()
    if macroRecording or macroPlaying then return end
    macroRecording = true
    recordingPaused = false
    currentMacro = {frames = {}, startTime = tick()}
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
        
        if not humanoid or not rootPart then
            updateCharacterReferences()
            if not humanoid or not rootPart then return end
            setupDeathHandler()
        end
        
        local frame = {
            time = tick() - currentMacro.startTime,
            cframe = rootPart.CFrame,
            velocity = rootPart.Velocity,
            walkSpeed = humanoid.WalkSpeed,
            jumpPower = humanoid.JumpPower,
            hipHeight = humanoid.HipHeight,
            state = humanoid:GetState()
        }
        table.insert(currentMacro.frames, frame)
        lastFrameTime = frame.time
    end)
end

-- Stop Macro Recording
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
        macroName = "Macro " .. (#savedMacros + 1)
    end
    
    savedMacros[macroName] = currentMacro
    saveToFileSystem(macroName, currentMacro)
    MacroInput.Text = ""
    Utility.updateMacroList()
    updateMacroStatus()
    if MacroFrame then
        MacroFrame.Visible = true
    end
end

-- Stop Macro Playback
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

-- Play Macro
local function playMacro(macroName, autoPlay)
    if macroRecording or macroPlaying or not humanoid or not rootPart then return end
    local macro = savedMacros[macroName] or loadFromFileSystem(macroName)
    if not macro or not macro.frames then return end
    
    macroPlaying = true
    autoPlaying = autoPlay or false
    currentMacroName = macroName
    humanoid.WalkSpeed = 0
    updateMacroStatus()
    
    local function playSingleMacro()
        local startTime = tick()
        local index = 1
        
        playbackConnection = RunService.Heartbeat:Connect(function()
            if not macroPlaying or not player.Character then
                if playbackConnection then playbackConnection:Disconnect() end
                macroPlaying = false
                autoPlaying = false
                humanoid.WalkSpeed = settings.WalkSpeed.value or 16
                currentMacroName = nil
                Utility.updateMacroList()
                updateMacroStatus()
                return
            end
            
            if not humanoid or not rootPart then
                updateCharacterReferences()
                if not humanoid or not rootPart then
                    if playbackConnection then playbackConnection:Disconnect() end
                    macroPlaying = false
                    autoPlaying = false
                    humanoid.WalkSpeed = settings.WalkSpeed.value or 16
                    currentMacroName = nil
                    Utility.updateMacroList()
                    updateMacroStatus()
                    return
                end
            end
            
            if index > #macro.frames then
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
            
            local frame = macro.frames[index]
            while index <= #macro.frames and frame.time <= (tick() - startTime) do
                if frame.cframe and frame.velocity and frame.walkSpeed and frame.jumpPower and frame.hipHeight and frame.state then
                    rootPart.CFrame = frame.cframe
                    rootPart.Velocity = frame.velocity
                    humanoid.WalkSpeed = frame.walkSpeed
                    humanoid.JumpPower = frame.jumpPower
                    humanoid.HipHeight = frame.hipHeight
                    humanoid:ChangeState(frame.state)
                end
                index = index + 1
                frame = macro.frames[index] or frame
            end
        end)
    end
    
    playSingleMacro()
end

-- Delete Macro
local function deleteMacro(macroName)
    if savedMacros[macroName] then
        if macroPlaying and currentMacroName == macroName then
            stopMacroPlayback()
        end
        savedMacros[macroName] = nil
        deleteFromFileSystem(macroName)
        Utility.updateMacroList()
    end
end

-- Rename Macro
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
        end
    end
end

-- Show Macro Manager
local function showMacroManager()
    macroFrameVisible = true
    if not MacroFrame then
        initUI()
    end
    MacroFrame.Visible = true
    Utility.updateMacroList()
end

-- Update Macro List UI
function Utility.updateMacroList()
    if not MacroScrollFrame then return end
    
    for _, child in pairs(MacroScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    local itemCount = 0
    
    for macroName, _ in pairs(savedMacros) do
        local macroItem = Instance.new("Frame")
        macroItem.Name = macroName .. "Item"
        macroItem.Parent = MacroScrollFrame
        macroItem.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        macroItem.BorderSizePixel = 0
        macroItem.Size = UDim2.new(1, -5, 0, 70)
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
        
        local renameInput = Instance.new("TextBox")
        renameInput.Name = "RenameInput"
        renameInput.Parent = macroItem
        renameInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        renameInput.BorderSizePixel = 0
        renameInput.Position = UDim2.new(0, 5, 0, 25)
        renameInput.Size = UDim2.new(1, -10, 0, 15)
        renameInput.Font = Enum.Font.Gotham
        renameInput.Text = ""
        renameInput.PlaceholderText = "Enter new name..."
        renameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        renameInput.TextSize = 7
        
        local buttonFrame = Instance.new("Frame")
        buttonFrame.Name = "ButtonFrame"
        buttonFrame.Parent = macroItem
        buttonFrame.BackgroundTransparency = 1
        buttonFrame.Position = UDim2.new(0, 5, 0, 45)
        buttonFrame.Size = UDim2.new(1, -10, 0, 15)
        
        local playButton = Instance.new("TextButton")
        playButton.Name = "PlayButton"
        playButton.Parent = buttonFrame
        playButton.BackgroundColor3 = (macroPlaying and currentMacroName == macroName and not autoPlaying) and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(60, 60, 60)
        playButton.BorderSizePixel = 0
        playButton.Position = UDim2.new(0, 0, 0, 0)
        playButton.Size = UDim2.new(0, 40, 0, 15)
        playButton.Font = Enum.Font.Gotham
        playButton.Text = (macroPlaying and currentMacroName == macroName and not autoPlaying) and "PLAYING" or "PLAY"
        playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        playButton.TextSize = 7
        
        local autoPlayButton = Instance.new("TextButton")
        autoPlayButton.Name = "AutoPlayButton"
        autoPlayButton.Parent = buttonFrame
        autoPlayButton.BackgroundColor3 = (macroPlaying and currentMacroName == macroName and autoPlaying) and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(60, 80, 60)
        autoPlayButton.BorderSizePixel = 0
        autoPlayButton.Position = UDim2.new(0, 45, 0, 0)
        autoPlayButton.Size = UDim2.new(0, 40, 0, 15)
        autoPlayButton.Font = Enum.Font.Gotham
        autoPlayButton.Text = (macroPlaying and currentMacroName == macroName and autoPlaying) and "STOP" or "AUTO"
        autoPlayButton.TextColor3 = Color3.fromRGB(255, 255, 255)
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
        
        playButton.MouseButton1Click:Connect(function()
            if macroPlaying and currentMacroName == macroName and not autoPlaying then
                stopMacroPlayback()
            else
                playMacro(macroName, false)
                Utility.updateMacroList()
            end
        end)
        
        autoPlayButton.MouseButton1Click:Connect(function()
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
            renameMacro(macroName, renameInput.Text)
        end)
        
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
        
        itemCount = itemCount + 1
    end
    
    task.wait(0.1)
    local contentSize = MacroLayout.AbsoluteContentSize
    MacroScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 5)
end

-- Initialize UI elements
local function initUI()
    if MacroFrame then return end
    
    MacroFrame = Instance.new("Frame")
    MacroFrame.Name = "MacroFrame"
    MacroFrame.Parent = ScreenGui
    MacroFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    MacroFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
    MacroFrame.BorderSizePixel = 1
    MacroFrame.Position = UDim2.new(0.3, 0, 0.2, 0)
    MacroFrame.Size = UDim2.new(0, 300, 0, 300)
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
    MacroTitle.Text = "MACRO MANAGER"
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

-- Kill Player
local function killPlayer()
    if humanoid then
        humanoid.Health = 0
    end
end

-- Reset Character
local function resetCharacter()
    if player and player.Character then
        player:LoadCharacter()
    end
end

-- Function to create buttons for Utility features
function Utility.loadUtilityButtons(createButton)
    createButton("Kill Player", killPlayer)
    createButton("Reset Character", resetCharacter)
    createButton("Record Macro", startMacroRecording)
    createButton("Stop Macro", stopMacroRecording)
    createButton("Macro Manager", showMacroManager)
end

-- Function to reset Utility states
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
    updateMacroStatus()
    Utility.updateMacroList()
end

-- Function to set dependencies and handle character respawn
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
    savedMacros = {}
    macroFrameVisible = false
    currentMacroName = nil
    lastFrameTime = 0
    
    ensureFileSystem()
    for macroName, macroData in pairs(fileSystem["DCIM/Supertool"]) do
        savedMacros[macroName] = macroData
    end
    
    initUI()
    
    player.CharacterAdded:Connect(function(newCharacter)
        if newCharacter then
            humanoid = newCharacter:WaitForChild("Humanoid", 30)
            rootPart = newCharacter:WaitForChild("HumanoidRootPart", 30)
            if macroRecording and recordingPaused then
                recordingPaused = false
                updateMacroStatus()
            end
            if macroPlaying and currentMacroName then
                if autoPlaying then
                    playMacro(currentMacroName, true)
                else
                    playMacro(currentMacroName, false)
                end
            end
            updateMacroStatus()
        end
    end)
end

return Utility