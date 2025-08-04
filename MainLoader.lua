local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid, hr, char
local gui, frame, logo, joystickFrame, cameraControlFrame, playerListFrame, positionListFrame
local selectedPlayer = nil
local spectatingPlayer = nil
local flying, freecam, noclip, godMode = false, false, false, false
local flySpeed = 40
local freecamSpeed = 20
local cameraRotationSensitivity = 0.01
local speedEnabled, jumpEnabled, waterWalk, rocket, spin = false, false, false, false, false
local moveSpeed = 50
local jumpPower = 100

-- Enhanced position saving system
local savedPositions = {}
local positionCounter = 0
local maxSavedPositions = 50
local autoSaveEnabled = false
local autoSaveInterval = 30
local isPositionListMinimized = false -- NEW: Tracks minimized state of position list
local isAutoTeleportActive = false -- NEW: Tracks auto-teleport state

-- Enhanced macro system
local macroRecording, macroPlaying, autoPlayOnRespawn, recordOnRespawn = false, false, false, false
local macroActions = {}
local macroSuccessfulActions = {}
local macroSuccessfulEndTime = nil
local currentAttempt = 1
local totalAttempts = 0
local practiceMode = false

-- Mobile specific variables
local freecamCFrame = nil
local hrCFrame = nil
local joystickTouch = nil
local cameraTouch = nil
local joystickRadius = 50
local joystickDeadzone = 0.15
local moveDirection = Vector3.new(0, 0, 0)
local cameraDelta = Vector2.new(0, 0)
local nickHidden, randomNick = false, false
local customNick = "PemainKeren"
local defaultLogoPos = UDim2.new(0.95, -50, 0.05, 10)
local defaultFramePos = UDim2.new(0.5, -400, 0.5, -250)
local freezeMovingParts = false
local originalCFrames = {}
local localStorage = {}
local connections = {}
local currentCategory = "Movement"

-- Data persistence key
local dataKey = "EnhancedKrnlUI_" .. tostring(player.UserId) .. "_" .. game.PlaceId

-- Load saved data
local function loadSavedData()
    savedPositions = savedPositions or {}
    positionCounter = #savedPositions
end

-- Save data
local function saveData()
    -- In a real environment, you'd save to DataStore here
    -- For now, data persists in memory during the session
end

-- Notify function
local function notify(message, color)
    local success, errorMsg = pcall(function()
        if not gui then
            print("Notify: " .. message)
            return
        end
        local notif = Instance.new("TextLabel")
        notif.Size = UDim2.new(0, 350, 0, 60)
        notif.Position = UDim2.new(0.5, -175, 0.1, 0)
        notif.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        notif.BackgroundTransparency = 0.4
        notif.TextColor3 = color or Color3.fromRGB(0, 255, 0)
        notif.TextSize = 18
        notif.Font = Enum.Font.Gotham
        notif.Text = message
        notif.TextWrapped = true
        notif.BorderSizePixel = 0
        notif.ZIndex = 20
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = notif
        notif.Parent = gui
        task.spawn(function()
            task.wait(3)
            notif:Destroy()
        end)
    end)
    if not success then
        print("Notify error: " .. tostring(errorMsg))
    end
end

-- Clear connections
local function clearConnections()
    for key, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
            connections[key] = nil
        end
    end
end

-- Validate position
local function isValidPosition(pos)
    return pos and not (pos.Y < -1000 or pos.Y > 10000 or math.abs(pos.X) > 10000 or math.abs(pos.Z) > 10000)
end

-- Ensure character visibility
local function ensureCharacterVisible()
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0
                part.LocalTransparencyModifier = 0
            end
        end
    end
end

-- Clean adornments
local function cleanAdornments(character)
    local success, errorMsg = pcall(function()
        for _, obj in pairs(character:GetDescendants()) do
            if obj:IsA("SelectionBox") or obj:IsA("BoxHandleAdornment") or obj:IsA("SurfaceGui") then
                obj:Destroy()
            end
        end
    end)
    if not success then
        print("cleanAdornments error: " .. tostring(errorMsg))
    end
end

-- Reset character state
local function resetCharacterState()
    if hr and humanoid then
        hr.Velocity = Vector3.new(0, 0, 0)
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
        humanoid.Health = humanoid.MaxHealth
        ensureCharacterVisible()
        cleanAdornments(char)
    end
end

-- Enhanced macro system functions
local function recordMacroAction(actionType, data)
    if macroRecording then
        local action = {
            time = tick(),
            type = actionType,
            data = data
        }
        table.insert(macroActions, action)
    end
end

local function onCharacterDied()
    if macroRecording and practiceMode then
        totalAttempts = totalAttempts + 1
        currentAttempt = currentAttempt + 1
        notify("💀 Death recorded - Attempt " .. currentAttempt .. " (Total: " .. totalAttempts .. ")", Color3.fromRGB(255, 100, 100))
    end
end

local function finishMacroSuccessfully()
    if macroRecording then
        macroSuccessfulActions = {}
        local lastDeathTime = 0
        
        for _, action in ipairs(macroActions) do
            if action.type ~= "death" and action.time > lastDeathTime then
                table.insert(macroSuccessfulActions, action)
            elseif action.type == "death" then
                lastDeathTime = action.time
                macroSuccessfulActions = {}
            end
        end
        
        macroSuccessfulEndTime = tick()
        notify("✅ Macro completed successfully! (" .. #macroSuccessfulActions .. " actions, " .. totalAttempts .. " attempts)", Color3.fromRGB(0, 255, 0))
    end
end

local function toggleRecordMacro()
    macroRecording = not macroRecording
    if macroRecording then
        macroActions = {}
        macroSuccessfulActions = {}
        currentAttempt = 1
        totalAttempts = 1
        practiceMode = true
        macroSuccessfulEndTime = nil
        
        if humanoid then
            connections.macroDeath = humanoid.Died:Connect(onCharacterDied)
        end
        
        notify("🔴 Macro Recording Started (Practice Mode)", Color3.fromRGB(255, 0, 0))
    else
        if connections.macroDeath then
            connections.macroDeath:Disconnect()
            connections.macroDeath = nil
        end
        
        finishMacroSuccessfully()
        practiceMode = false
        notify("⏹️ Macro Recording Stopped", Color3.fromRGB(255, 255, 0))
    end
end

local function togglePlayMacro()
    macroPlaying = not macroPlaying
    if macroPlaying then
        if #macroSuccessfulActions == 0 then
            macroPlaying = false
            notify("⚠️ No successful macro recorded!", Color3.fromRGB(255, 100, 100))
            return
        end
        
        notify("▶️ Playing Successful Macro (" .. #macroSuccessfulActions .. " actions)", Color3.fromRGB(0, 255, 0))
        
        task.spawn(function()
            local startTime = tick()
            local actionIndex = 1
            
            while macroPlaying and actionIndex <= #macroSuccessfulActions do
                local action = macroSuccessfulActions[actionIndex]
                local targetTime = startTime + (action.time - macroSuccessfulActions[1].time)
                
                while tick() < targetTime and macroPlaying do
                    task.wait(0.01)
                end
                
                if not macroPlaying then break end
                
                if action.type == "move" and hr then
                    hr.CFrame = action.data
                elseif action.type == "jump" and humanoid then
                    humanoid.Jump = true
                end
                
                actionIndex = actionIndex + 1
            end
            
            if macroPlaying then
                notify("✅ Macro playback completed!", Color3.fromRGB(0, 255, 0))
                macroPlaying = false
            end
        end)
    else
        notify("⏹️ Macro Playback Stopped", Color3.fromRGB(255, 255, 0))
    end
end

local function saveToLocalStorage()
    localStorage[dataKey] = {
        savedPositions = savedPositions,
        positionCounter = positionCounter
    }
end

local function loadFromLocalStorage()
    if localStorage[dataKey] then
        savedPositions = localStorage[dataKey].savedPositions or {}
        positionCounter = localStorage[dataKey].positionCounter or #savedPositions
    else
        savedPositions = {}
        positionCounter = 0
    end
end

-- Enhanced position saving system
local function saveCurrentPosition(customName)
    local success, errorMsg = pcall(function()
        if hr then
            positionCounter = positionCounter + 1
            local positionName = customName or ("Position " .. positionCounter)
            local positionData = {
                name = positionName,
                cframe = hr.CFrame,
                timestamp = os.time(),
                id = positionCounter
            }
            
            table.insert(savedPositions, positionData)
            
            if #savedPositions > maxSavedPositions then
                table.remove(savedPositions, 1)
            end
            
            saveToLocalStorage() -- CHANGED: Use new storage function
            notify("💾 Saved: " .. positionName)
            
            if positionListFrame and positionListFrame.Visible then
                updatePositionList()
            end
        else
            notify("⚠️ Character not loaded", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Save Position error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleAutoSave()
    autoSaveEnabled = not autoSaveEnabled
    if autoSaveEnabled then
        notify("🔄 Auto Save Enabled (every " .. autoSaveInterval .. "s)", Color3.fromRGB(0, 255, 0))
        task.spawn(function()
            local lastPosition = nil
            while autoSaveEnabled do
                task.wait(autoSaveInterval)
                if hr and hr.Position and autoSaveEnabled then
                    if not lastPosition or (hr.Position - lastPosition).Magnitude > 10 then
                        saveCurrentPosition("Auto " .. os.date("%H:%M:%S"))
                        lastPosition = hr.Position
                    end
                end
            end
        end)
    else
        notify("🔄 Auto Save Disabled", Color3.fromRGB(255, 100, 100))
    end
end

local function deletePosition(positionId)
    for i, pos in ipairs(savedPositions) do
        if pos.id == positionId then
            table.remove(savedPositions, i)
            saveToLocalStorage() -- CHANGED: Use new storage function
            notify("🗑️ Deleted: " .. pos.name, Color3.fromRGB(255, 100, 100))
            if positionListFrame and positionListFrame.Visible then
                updatePositionList()
            end
            break
        end
    end
end

local function toggleAutoTeleport()
    isAutoTeleportActive = not isAutoTeleportActive
    if isAutoTeleportActive then
        if #savedPositions == 0 then
            isAutoTeleportActive = false
            notify("⚠️ No saved positions to auto-teleport!", Color3.fromRGB(255, 100, 100))
            return
        end
        
        notify("🚀 Auto-Teleport Started (" .. #savedPositions .. " positions)", Color3.fromRGB(0, 255, 0))
        
        task.spawn(function()
            local index = 1
            while isAutoTeleportActive and #savedPositions > 0 do
                local pos = savedPositions[index]
                if pos and hr and isValidPosition(pos.cframe.Position) then
                    hr.CFrame = pos.cframe
                    notify("📍 Auto-Teleported to: " .. pos.name)
                else
                    notify("⚠️ Invalid position or character not loaded at index " .. index, Color3.fromRGB(255, 100, 100))
                end
                
                index = index + 1
                if index > #savedPositions then
                    index = 1 -- Loop back to the first position
                end
                
                task.wait(2) -- Delay between teleports (adjustable)
            end
            
            if not isAutoTeleportActive then
                notify("⏹️ Auto-Teleport Stopped", Color3.fromRGB(255, 255, 0))
            end
        end)
    else
        notify("⏹️ Auto-Teleport Stopped", Color3.fromRGB(255, 255, 0))
    end
end

local function showRenameDialog(positionId)
    local pos = nil
    for _, p in ipairs(savedPositions) do
        if p.id == positionId then
            pos = p
            break
        end
    end
    
    if not pos then return end
    
    -- Create rename dialog
    local renameDialog = Instance.new("Frame")
    renameDialog.Size = UDim2.new(0, 300, 0, 150)
    renameDialog.Position = UDim2.new(0.5, -150, 0.5, -75)
    renameDialog.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    renameDialog.BorderSizePixel = 0
    renameDialog.ZIndex = 35
    local renameCorner = Instance.new("UICorner")
    renameCorner.CornerRadius = UDim.new(0, 10)
    renameCorner.Parent = renameDialog
    renameDialog.Parent = gui
    
    local renameTitle = Instance.new("TextLabel")
    renameTitle.Size = UDim2.new(1, 0, 0, 40)
    renameTitle.BackgroundTransparency = 1
    renameTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    renameTitle.TextSize = 16
    renameTitle.Font = Enum.Font.GothamBold
    renameTitle.Text = "Rename Position"
    renameTitle.ZIndex = 36
    renameTitle.Parent = renameDialog
    
    local renameBox = Instance.new("TextBox")
    renameBox.Size = UDim2.new(1, -20, 0, 30)
    renameBox.Position = UDim2.new(0, 10, 0, 50)
    renameBox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    renameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    renameBox.TextSize = 14
    renameBox.Font = Enum.Font.Gotham
    renameBox.Text = pos.name
    renameBox.PlaceholderText = "Enter new name..."
    renameBox.ZIndex = 36
    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 5)
    boxCorner.Parent = renameBox
    renameBox.Parent = renameDialog
    
    local confirmBtn = Instance.new("TextButton")
    confirmBtn.Size = UDim2.new(0, 80, 0, 30)
    confirmBtn.Position = UDim2.new(0, 50, 0, 100)
    confirmBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    confirmBtn.TextSize = 14
    confirmBtn.Font = Enum.Font.Gotham
    confirmBtn.Text = "Confirm"
    confirmBtn.ZIndex = 36
    local confirmCorner = Instance.new("UICorner")
    confirmCorner.CornerRadius = UDim.new(0, 5)
    confirmCorner.Parent = confirmBtn
    confirmBtn.MouseButton1Click:Connect(function()
        if renameBox.Text ~= "" then
            pos.name = renameBox.Text
            saveData()
            notify("✏️ Renamed to: " .. renameBox.Text)
            if positionListFrame and positionListFrame.Visible then
                updatePositionList()
            end
        end
        renameDialog:Destroy()
    end)
    confirmBtn.Parent = renameDialog
    
    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0, 80, 0, 30)
    cancelBtn.Position = UDim2.new(0, 170, 0, 100)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    cancelBtn.TextSize = 14
    cancelBtn.Font = Enum.Font.Gotham
    cancelBtn.Text = "Cancel"
    cancelBtn.ZIndex = 36
    local cancelCorner = Instance.new("UICorner")
    cancelCorner.CornerRadius = UDim.new(0, 5)
    cancelCorner.Parent = cancelBtn
    cancelBtn.MouseButton1Click:Connect(function()
        renameDialog:Destroy()
    end)
    cancelBtn.Parent = renameDialog
end

local function loadPosition(positionId)
    local success, errorMsg = pcall(function()
        for _, pos in ipairs(savedPositions) do
            if pos.id == positionId then
                if hr and isValidPosition(pos.cframe.Position) then
                    hr.CFrame = pos.cframe
                    notify("📍 Teleported to: " .. pos.name)
                else
                    notify("⚠️ Invalid position or character not loaded", Color3.fromRGB(255, 100, 100))
                end
                return
            end
        end
        notify("⚠️ Position not found", Color3.fromRGB(255, 100, 100))
    end)
    if not success then
        notify("⚠️ Load Position error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Teleport to freecam function
local function teleportToFreecam()
    local success, errorMsg = pcall(function()
        if freecam and freecamCFrame and hr then
            hr.CFrame = freecamCFrame
            notify("📷➡️ Teleported to Freecam Position")
        elseif not freecam then
            notify("⚠️ Freecam is not active", Color3.fromRGB(255, 100, 100))
        elseif not freecamCFrame then
            notify("⚠️ No freecam position available", Color3.fromRGB(255, 100, 100))
        else
            notify("⚠️ Character not loaded", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Teleport to Freecam error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Create position list UI
function updatePositionList()
    if not positionListFrame then return end
    
    local scrollFrame = positionListFrame:FindFirstChild("ScrollFrame")
    if not scrollFrame then return end
    
    -- Clear existing buttons
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name == "PositionItem" then
            child:Destroy()
        end
    end
    
    -- Add position items
    for i, pos in ipairs(savedPositions) do
        local itemFrame = Instance.new("Frame")
        itemFrame.Name = "PositionItem"
        itemFrame.Size = UDim2.new(1, -10, 0, 100)
        itemFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        itemFrame.BackgroundTransparency = 0.3
        itemFrame.BorderSizePixel = 0
        itemFrame.ZIndex = 27
        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 8)
        itemCorner.Parent = itemFrame
        itemFrame.Parent = scrollFrame
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, -10, 0, 25)
        nameLabel.Position = UDim2.new(0, 10, 0, 5)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize = 16
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Text = pos.name
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.ZIndex = 28
        nameLabel.Parent = itemFrame
        
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Size = UDim2.new(1, -10, 0, 20)
        infoLabel.Position = UDim2.new(0, 10, 0, 30)
        infoLabel.BackgroundTransparency = 1
        infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        infoLabel.TextSize = 12
        infoLabel.Font = Enum.Font.Gotham
        infoLabel.Text = "ID: " .. pos.id .. " | " .. os.date("%H:%M:%S", pos.timestamp)
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoLabel.ZIndex = 28
        infoLabel.Parent = itemFrame
        
        -- Button container
        local buttonFrame = Instance.new("Frame")
        buttonFrame.Size = UDim2.new(1, -10, 0, 35)
        buttonFrame.Position = UDim2.new(0, 10, 0, 55)
        buttonFrame.BackgroundTransparency = 1
        buttonFrame.ZIndex = 28
        buttonFrame.Parent = itemFrame
        
        local buttonUIL = Instance.new("UIListLayout")
        buttonUIL.FillDirection = Enum.FillDirection.Horizontal
        buttonUIL.Padding = UDim.new(0, 5)
        buttonUIL.Parent = buttonFrame
        
        -- Teleport button
        local teleportBtn = Instance.new("TextButton")
        teleportBtn.Size = UDim2.new(0, 70, 0, 30)
        teleportBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
        teleportBtn.BackgroundTransparency = 0.2
        teleportBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        teleportBtn.TextSize = 12
        teleportBtn.Font = Enum.Font.Gotham
        teleportBtn.Text = "Go"
        teleportBtn.ZIndex = 29
        local teleportCorner = Instance.new("UICorner")
        teleportCorner.CornerRadius = UDim.new(0, 4)
        teleportCorner.Parent = teleportBtn
        teleportBtn.MouseButton1Click:Connect(function()
            loadPosition(pos.id)
        end)
        teleportBtn.Parent = buttonFrame
        
        -- Rename button
        local renameBtn = Instance.new("TextButton")
        renameBtn.Size = UDim2.new(0, 70, 0, 30)
        renameBtn.BackgroundColor3 = Color3.fromRGB(200, 120, 0)
        renameBtn.BackgroundTransparency = 0.2
        renameBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        renameBtn.TextSize = 12
        renameBtn.Font = Enum.Font.Gotham
        renameBtn.Text = "Rename"
        renameBtn.ZIndex = 29
        local renameCorner = Instance.new("UICorner")
        renameCorner.CornerRadius = UDim.new(0, 4)
        renameCorner.Parent = renameBtn
        renameBtn.MouseButton1Click:Connect(function()
            showRenameDialog(pos.id)
        end)
        renameBtn.Parent = buttonFrame
        
        -- Delete button
        local deleteBtn = Instance.new("TextButton")
        deleteBtn.Size = UDim2.new(0, 70, 0, 30)
        deleteBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        deleteBtn.BackgroundTransparency = 0.2
        deleteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        deleteBtn.TextSize = 12
        deleteBtn.Font = Enum.Font.Gotham
        deleteBtn.Text = "Delete"
        deleteBtn.ZIndex = 29
        local deleteCorner = Instance.new("UICorner")
        deleteCorner.CornerRadius = UDim.new(0, 4)
        deleteCorner.Parent = deleteBtn
        deleteBtn.MouseButton1Click:Connect(function()
            deletePosition(pos.id)
        end)
        deleteBtn.Parent = buttonFrame
    end
end

local function createPositionListUI()
    if positionListFrame then
        positionListFrame:Destroy()
    end
    
    positionListFrame = Instance.new("Frame")
    positionListFrame.Size = UDim2.new(0, 400, 0, isPositionListMinimized and 50 or 500) -- CHANGED: Dynamic size based on minimized state
    positionListFrame.Position = UDim2.new(0, 20, 0.5, -250)
    positionListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    positionListFrame.BackgroundTransparency = 0.1
    positionListFrame.BorderSizePixel = 0
    positionListFrame.Visible = false
    positionListFrame.ZIndex = 25
    local posFrameCorner = Instance.new("UICorner")
    posFrameCorner.CornerRadius = UDim.new(0, 12)
    posFrameCorner.Parent = positionListFrame
    positionListFrame.Parent = gui

    local posTitle = Instance.new("TextLabel")
    posTitle.Size = UDim2.new(1, 0, 0, 50)
    posTitle.BackgroundTransparency = 1
    posTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    posTitle.TextSize = 20
    posTitle.Font = Enum.Font.GothamBold
    posTitle.Text = "Saved Positions (" .. #savedPositions .. ")"
    posTitle.ZIndex = 26
    posTitle.Parent = positionListFrame

    local posScrollFrame = Instance.new("ScrollingFrame")
    posScrollFrame.Name = "ScrollFrame"
    posScrollFrame.Size = UDim2.new(1, -20, 1, -70)
    posScrollFrame.Position = UDim2.new(0, 10, 0, 60)
    posScrollFrame.BackgroundTransparency = 1
    posScrollFrame.ScrollBarThickness = 8
    posScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    posScrollFrame.ZIndex = 26
    posScrollFrame.ClipsDescendants = true
    posScrollFrame.ScrollingEnabled = true
    posScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    posScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    posScrollFrame.Visible = not isPositionListMinimized -- CHANGED: Hide scroll frame when minimized
    posScrollFrame.Parent = positionListFrame

    local posUIL = Instance.new("UIListLayout")
    posUIL.FillDirection = Enum.FillDirection.Vertical
    posUIL.Padding = UDim.new(0, 5)
    posUIL.Parent = posScrollFrame

    local posPadding = Instance.new("UIPadding")
    posPadding.PaddingTop = UDim.new(0, 5)
    posPadding.PaddingBottom = UDim.new(0, 5)
    posPadding.PaddingLeft = UDim.new(0, 5)
    posPadding.PaddingRight = UDim.new(0, 5)
    posPadding.Parent = posScrollFrame

    -- NEW: Minimize/Maximize button
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
    minimizeBtn.Position = UDim2.new(1, -80, 0, 10)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    minimizeBtn.BackgroundTransparency = 0.3
    minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizeBtn.TextSize = 18
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.Text = isPositionListMinimized and "+" or "-"
    minimizeBtn.ZIndex = 28
    local minimizeCorner = Instance.new("UICorner")
    minimizeCorner.CornerRadius = UDim.new(0, 15)
    minimizeCorner.Parent = minimizeBtn
    minimizeBtn.MouseButton1Click:Connect(function()
        isPositionListMinimized = not isPositionListMinimized
        positionListFrame.Size = UDim2.new(0, 400, 0, isPositionListMinimized and 50 or 500)
        posScrollFrame.Visible = not isPositionListMinimized
        minimizeBtn.Text = isPositionListMinimized and "+" or "-"
        notify(isPositionListMinimized and "📍 Position List Minimized" or "📍 Position List Maximized")
        if not isPositionListMinimized then
            updatePositionList()
        end
    end)
    minimizeBtn.Parent = positionListFrame

    -- Close button (unchanged but included for context)
    local closePosListBtn = Instance.new("TextButton")
    closePosListBtn.Size = UDim2.new(0, 30, 0, 30)
    closePosListBtn.Position = UDim2.new(1, -40, 0, 10)
    closePosListBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closePosListBtn.BackgroundTransparency = 0.3
    closePosListBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closePosListBtn.TextSize = 18
    closePosListBtn.Font = Enum.Font.GothamBold
    closePosListBtn.Text = "×"
    closePosListBtn.ZIndex = 28
    local closePosCorner = Instance.new("UICorner")
    closePosCorner.CornerRadius = UDim.new(0, 15)
    closePosCorner.Parent = closePosListBtn
    closePosListBtn.MouseButton1Click:Connect(function()
        positionListFrame.Visible = false
    end)
    closePosListBtn.Parent = positionListFrame

    updatePositionList()
end


local function showPositionList()
    if positionListFrame then
        positionListFrame.Visible = not positionListFrame.Visible
        if positionListFrame.Visible then
            updatePositionList()
            local posTitle = positionListFrame:FindFirstChild("TextLabel")
            if posTitle then
                posTitle.Text = "Saved Positions (" .. #savedPositions .. ")"
            end
        end
        notify(positionListFrame.Visible and "📍 Position List Opened" or "📍 Position List Closed")
    end
end

-- Initialize character
local function initChar()
    local success, errorMsg = pcall(function()
        local retryCount = 0
        while not player.Character and retryCount < 5 do
            notify("⏳ Waiting for character to spawn... Attempt " .. (retryCount + 1), Color3.fromRGB(255, 255, 0))
            player.CharacterAdded:Wait()
            task.wait(2)
            retryCount = retryCount + 1
        end
        if not player.Character then
            error("Character failed to load after retries")
        end
        char = player.Character
        humanoid = char:WaitForChild("Humanoid", 20)
        hr = char:WaitForChild("HumanoidRootPart", 20)
        if not humanoid or not hr then
            error("Failed to find Humanoid or HumanoidRootPart after 20s")
        end
        cleanAdornments(char)
        ensureCharacterVisible()
        
        -- Removed auto-save spawn position
        -- saveCurrentPosition("Spawn " .. positionCounter) -- Commented out to disable auto-save on respawn
        
        -- Connect macro recording to new character
        if macroRecording and humanoid then
            if connections.macroDeath then
                connections.macroDeath:Disconnect()
            end
            connections.macroDeath = humanoid.Died:Connect(onCharacterDied)
        end
        
        -- Reapply all active features
        if flying then toggleFly() toggleFly() end
        if freecam then toggleFreecam() toggleFreecam() end
        if noclip then toggleNoclip() toggleNoclip() end
        if speedEnabled then toggleSpeed() toggleSpeed() end
        if jumpEnabled then toggleJump() toggleJump() end
        if waterWalk then toggleWaterWalk() toggleWaterWalk() end
        if godMode then toggleGodMode() toggleGodMode() end
        if recordOnRespawn and macroRecording then toggleRecordMacro() toggleRecordMacro() end
        if autoPlayOnRespawn and macroPlaying then togglePlayMacro() togglePlayMacro() end
    end)
    if not success then
        print("initChar error: " .. tostring(errorMsg))
        notify("⚠️ Character init failed: " .. tostring(errorMsg) .. ", retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(5)
        initChar()
    end
end

-- Fixed Fly toggle
local function toggleFly()
    flying = not flying
    local success, errorMsg = pcall(function()
        if flying then
            if freecam then
                toggleFreecam()
                notify("📷 Freecam disabled to enable Fly", Color3.fromRGB(255, 100, 100))
            end
            if not hr or not humanoid or not camera then
                flying = false
                error("Character or camera not loaded")
            end
            
            joystickFrame.Visible = true
            cameraControlFrame.Visible = true
            
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = hr
            
            connections.fly = RunService.RenderStepped:Connect(function()
                if not hr or not humanoid or not camera then
                    flying = false
                    if connections.fly then
                        connections.fly:Disconnect()
                        connections.fly = nil
                    end
                    joystickFrame.Visible = false
                    cameraControlFrame.Visible = false
                    notify("⚠️ Fly failed: Character or camera lost", Color3.fromRGB(255, 100, 100))
                    return
                end
                
                -- Record movement for macro
                if macroRecording then
                    recordMacroAction("move", hr.CFrame)
                end
                
                local forward = camera.CFrame.LookVector
                local right = camera.CFrame.RightVector
                local up = Vector3.new(0, 1, 0)
                local moveDir = moveDirection.X * right + moveDirection.Z * forward
                
                if moveDir.Magnitude > 0 then
                    moveDir = moveDir.Unit * flySpeed
                else
                    moveDir = Vector3.new(0, 0, 0)
                end
                
                bv.Velocity = moveDir
                hr.CFrame = CFrame.new(hr.Position) * camera.CFrame.Rotation
                
                local yaw = cameraDelta.X * cameraRotationSensitivity
                local pitch = cameraDelta.Y * cameraRotationSensitivity
                local currentPitch = math.asin(camera.CFrame.LookVector.Y)
                pitch = math.clamp(currentPitch + pitch, -math.pi / 2 + 0.1, math.pi / 2 - 0.1)
                local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch - currentPitch, 0, 0)
                camera.CFrame = CFrame.new(camera.CFrame.Position) * (camera.CFrame.Rotation * rotation)
            end)
            notify("🛫 Fly Enabled (Mobile Controls)")
        else
            if connections.fly then
                connections.fly:Disconnect()
                connections.fly = nil
            end
            if hr and hr:FindFirstChildOfClass("BodyVelocity") then
                hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
            end
            joystickFrame.Visible = false
            cameraControlFrame.Visible = false
            moveDirection = Vector3.new(0, 0, 0)
            cameraDelta = Vector2.new(0, 0)
            notify("🛬 Fly Disabled")
        end
    end)
    if not success then
        flying = false
        if connections.fly then
            connections.fly:Disconnect()
            connections.fly = nil
        end
        if hr and hr:FindFirstChildOfClass("BodyVelocity") then
            hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
        end
        joystickFrame.Visible = false
        cameraControlFrame.Visible = false
        moveDirection = Vector3.new(0, 0, 0)
        cameraDelta = Vector2.new(0, 0)
        notify("⚠️ Fly error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end



-- Fixed Freecam toggle
local function toggleFreecam()
    freecam = not freecam
    local success, errorMsg = pcall(function()
        if freecam then
            if flying then
                toggleFly()
                notify("🛫 Fly disabled to enable Freecam", Color3.fromRGB(255, 100, 100))
            end
            if not hr or not humanoid or not camera then
                freecam = false
                error("Character or camera not loaded")
            end
            
            joystickFrame.Visible = true
            cameraControlFrame.Visible = true
            hrCFrame = hr.CFrame
            freecamCFrame = camera.CFrame
            camera.CameraType = Enum.CameraType.Scriptable
            camera.CameraSubject = nil
            
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = hr
            
            connections.freecamLock = RunService.Stepped:Connect(function()
                if hr and hrCFrame then
                    hr.CFrame = hrCFrame
                else
                    freecam = false
                    if connections.freecamLock then
                        connections.freecamLock:Disconnect()
                        connections.freecamLock = nil
                    end
                    joystickFrame.Visible = false
                    cameraControlFrame.Visible = false
                    notify("⚠️ Character lost, Freecam disabled", Color3.fromRGB(255, 100, 100))
                end
            end)
            
            connections.freecam = RunService.RenderStepped:Connect(function()
                if not camera or not freecamCFrame then
                    freecam = false
                    if connections.freecam then
                        connections.freecam:Disconnect()
                        connections.freecam = nil
                    end
                    if connections.freecamLock then
                        connections.freecamLock:Disconnect()
                        connections.freecamLock = nil
                    end
                    joystickFrame.Visible = false
                    cameraControlFrame.Visible = false
                    notify("⚠️ Freecam failed: Camera or CFrame lost", Color3.fromRGB(255, 100, 100))
                    return
                end
                
                local forward = freecamCFrame.LookVector
                local right = freecamCFrame.RightVector
                local moveDir = moveDirection.X * right + moveDirection.Z * forward
                
                if moveDir.Magnitude > 0 then
                    moveDir = moveDir * freecamSpeed
                    freecamCFrame = CFrame.new(freecamCFrame.Position + moveDir) * freecamCFrame.Rotation
                end
                
                local yaw = cameraDelta.X * cameraRotationSensitivity
                local pitch = cameraDelta.Y * cameraRotationSensitivity
                local currentPitch = math.asin(freecamCFrame.LookVector.Y)
                pitch = math.clamp(currentPitch + pitch, -math.pi / 2 + 0.1, math.pi / 2 - 0.1)
                local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch - currentPitch, 0, 0)
                freecamCFrame = CFrame.new(freecamCFrame.Position) * (freecamCFrame.Rotation * rotation)
                
                camera.CFrame = freecamCFrame
            end)
            notify("📷 Freecam Enabled (Mobile Controls)")
        else
            if connections.freecam then
                connections.freecam:Disconnect()
                connections.freecam = nil
            end
            if connections.freecamLock then
                connections.freecamLock:Disconnect()
                connections.freecamLock = nil
            end
            if hr and hr:FindFirstChildOfClass("BodyVelocity") then
                hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
            end
            if camera and humanoid then
                camera.CameraType = Enum.CameraType.Custom
                camera.CameraSubject = humanoid
                if hr then
                    camera.CFrame = CFrame.new(hr.CFrame.Position + Vector3.new(0, 5, 10), hr.CFrame.Position)
                end
            end
            freecamCFrame = nil
            hrCFrame = nil
            joystickFrame.Visible = false
            cameraControlFrame.Visible = false
            moveDirection = Vector3.new(0, 0, 0)
            cameraDelta = Vector2.new(0, 0)
            notify("📷 Freecam Disabled")
        end
    end)
    if not success then
        freecam = false
        if connections.freecam then
            connections.freecam:Disconnect()
            connections.freecam = nil
        end
        if connections.freecamLock then
            connections.freecamLock:Disconnect()
            connections.freecamLock = nil
        end
        if hr and hr:FindFirstChildOfClass("BodyVelocity") then
            hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
        end
        joystickFrame.Visible = false
        cameraControlFrame.Visible = false
        moveDirection = Vector3.new(0, 0, 0)
        cameraDelta = Vector2.new(0, 0)
        notify("⚠️ Freecam error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Other essential functions
local function toggleNoclip()
    noclip = not noclip
    local success, errorMsg = pcall(function()
        if noclip then
            connections.noclip = RunService.Stepped:Connect(function()
                if char then
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
            notify("🚪 Noclip Enabled")
        else
            if connections.noclip then
                connections.noclip:Disconnect()
                connections.noclip = nil
            end
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = true
                    end
                end
            end
            notify("🚪 Noclip Disabled")
        end
    end)
    if not success then
        noclip = false
        if connections.noclip then
            connections.noclip:Disconnect()
            connections.noclip = nil
        end
        notify("⚠️ Noclip error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleSpeed()
    speedEnabled = not speedEnabled
    local success, errorMsg = pcall(function()
        if speedEnabled then
            if humanoid then
                humanoid.WalkSpeed = moveSpeed
            end
            notify("🏃 Speed Enabled")
        else
            if humanoid then
                humanoid.WalkSpeed = 16
            end
            notify("🏃 Speed Disabled")
        end
    end)
    if not success then
        speedEnabled = false
        notify("⚠️ Speed error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleJump()
    jumpEnabled = not jumpEnabled
    local success, errorMsg = pcall(function()
        if jumpEnabled then
            if humanoid then
                humanoid.JumpPower = jumpPower
            end
            notify("🦘 Jump Enabled")
        else
            if humanoid then
                humanoid.JumpPower = 50
            end
            notify("🦘 Jump Disabled")
        end
    end)
    if not success then
        jumpEnabled = false
        notify("⚠️ Jump error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleWaterWalk()
    waterWalk = not waterWalk
    local success, errorMsg = pcall(function()
        if waterWalk then
            connections.waterWalk = RunService.Stepped:Connect(function()
                if humanoid and hr then
                    local ray = Ray.new(hr.Position, Vector3.new(0, -5, 0))
                    local hit, pos = workspace:FindPartOnRayWithIgnoreList(ray, {char})
                    if hit and hit.Name:lower():find("water") then
                        hr.Position = Vector3.new(hr.Position.X, pos.Y + 1, hr.Position.Z)
                    end
                end
            end)
            notify("🌊 Water Walk Enabled")
        else
            if connections.waterWalk then
                connections.waterWalk:Disconnect()
                connections.waterWalk = nil
            end
            notify("🌊 Water Walk Disabled")
        end
    end)
    if not success then
        waterWalk = false
        if connections.waterWalk then
            connections.waterWalk:Disconnect()
            connections.waterWalk = nil
        end
        notify("⚠️ Water Walk error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleGodMode()
    godMode = not godMode
    local success, errorMsg = pcall(function()
        if godMode then
            if humanoid then
                humanoid.MaxHealth = math.huge
                humanoid.Health = math.huge
            end
            connections.godMode = humanoid.HealthChanged:Connect(function(health)
                if health < math.huge then
                    humanoid.Health = math.huge
                end
            end)
            notify("🛡️ God Mode Enabled")
        else
            if connections.godMode then
                connections.godMode:Disconnect()
                connections.godMode = nil
            end
            if humanoid then
                humanoid.MaxHealth = 100
                humanoid.Health = 100
            end
            notify("🛡️ God Mode Disabled")
        end
    end)
    if not success then
        godMode = false
        if connections.godMode then
            connections.godMode:Disconnect()
            connections.godMode = nil
        end
        notify("⚠️ God Mode error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Player functions
local function spectatePlayer()
    local success, errorMsg = pcall(function()
        if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("Humanoid") then
            spectatingPlayer = selectedPlayer
            camera.CameraSubject = selectedPlayer.Character.Humanoid
            notify("👁️ Spectating " .. selectedPlayer.Name)
        else
            notify("⚠️ No player selected or invalid character", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Spectate error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function stopSpectate()
    local success, errorMsg = pcall(function()
        if spectatingPlayer then
            camera.CameraSubject = humanoid
            spectatingPlayer = nil
            notify("👁️ Stopped spectating")
        else
            notify("⚠️ Not currently spectating", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Stop spectate error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function teleportToPlayer()
    local success, errorMsg = pcall(function()
        if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") and hr then
            local targetPos = selectedPlayer.Character.HumanoidRootPart.Position
            if isValidPosition(targetPos) then
                hr.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
                notify("🚀 Teleported to " .. selectedPlayer.Name)
            else
                notify("⚠️ Invalid position for teleport", Color3.fromRGB(255, 100, 100))
            end
        else
            notify("⚠️ No player selected or invalid character", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Teleport error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function teleportToSpawn()
    local success, errorMsg = pcall(function()
        if hr then
            local spawnLocation = workspace:FindFirstChildOfClass("SpawnLocation")
            local targetPos = spawnLocation and spawnLocation.Position or Vector3.new(0, 5, 0)
            if isValidPosition(targetPos) then
                hr.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
                notify("🚪 Teleported to Spawn")
            else
                notify("⚠️ Invalid spawn position", Color3.fromRGB(255, 100, 100))
            end
        else
            notify("⚠️ Character not loaded", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Teleport to Spawn error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function toggleFreezeMovingParts()
    freezeMovingParts = not freezeMovingParts
    local success, errorMsg = pcall(function()
        if freezeMovingParts then
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and not obj.Anchored and obj.Name ~= "HumanoidRootPart" then
                    if obj.Name:lower():find("moving") or obj.Name:lower():find("platform") or 
                       obj.Name:lower():find("obstacle") or obj.Name:lower():find("trap") or
                       obj.Name:lower():find("block") or obj.Name:lower():find("wood") or
                       obj.Name:lower():find("step") or obj.Name:lower():find("stair") or
                       obj.Parent and (obj.Parent.Name:lower():find("moving") or 
                       obj.Parent.Name:lower():find("obstacle") or obj.Parent.Name:lower():find("trap")) then
                        originalCFrames[obj] = obj.CFrame
                        obj.Anchored = true
                        for _, child in pairs(obj:GetChildren()) do
                            if child:IsA("BodyVelocity") or child:IsA("BodyPosition") or 
                               child:IsA("BodyAngularVelocity") or child:IsA("BodyThrust") then
                                child.MaxForce = Vector3.new(0, 0, 0)
                            end
                        end
                    end
                end
            end
            
            connections.freezeWatch = RunService.Heartbeat:Connect(function()
                for part, originalCFrame in pairs(originalCFrames) do
                    if part and part.Parent then
                        part.CFrame = originalCFrame
                        part.Anchored = true
                    end
                end
            end)
            
            notify("🧊 Moving Parts Frozen")
        else
            if connections.freezeWatch then
                connections.freezeWatch:Disconnect()
                connections.freezeWatch = nil
            end
            
            for part, originalCFrame in pairs(originalCFrames) do
                if part and part.Parent then
                    part.Anchored = false
                    for _, child in pairs(part:GetChildren()) do
                        if child:IsA("BodyVelocity") then
                            child.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        elseif child:IsA("BodyPosition") then
                            child.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        end
                    end
                end
            end
            originalCFrames = {}
            
            notify("🧊 Moving Parts Unfrozen")
        end
    end)
    if not success then
        freezeMovingParts = false
        if connections.freezeWatch then
            connections.freezeWatch:Disconnect()
            connections.freezeWatch = nil
        end
        notify("⚠️ Freeze Moving Parts error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Practice mode toggle
local function togglePracticeMode()
    practiceMode = not practiceMode
    notify(practiceMode and "🎯 Practice Mode Enabled" or "🎯 Practice Mode Disabled")
end

-- Create mobile joystick
local function createJoystick()
    if joystickFrame then
        joystickFrame:Destroy()
    end
    
    joystickFrame = Instance.new("Frame")
    joystickFrame.Size = UDim2.new(0, 120, 0, 120)
    joystickFrame.Position = UDim2.new(0.1, 0, 0.65, 0)
    joystickFrame.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    joystickFrame.BackgroundTransparency = 0.5
    joystickFrame.BorderSizePixel = 0
    joystickFrame.ZIndex = 15
    joystickFrame.Visible = false
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 60)
    corner.Parent = joystickFrame
    joystickFrame.Parent = gui

    local joystickKnob = Instance.new("Frame")
    joystickKnob.Size = UDim2.new(0, 40, 0, 40)
    joystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
    joystickKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    joystickKnob.BackgroundTransparency = 0.2
    joystickKnob.BorderSizePixel = 0
    joystickKnob.ZIndex = 16
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0, 20)
    knobCorner.Parent = joystickKnob
    joystickKnob.Parent = joystickFrame

    local function updateJoystick(touchPosition)
        local center = joystickFrame.AbsolutePosition + joystickFrame.AbsoluteSize / 2
        local offset = touchPosition - center
        local distance = math.min(offset.Magnitude, joystickRadius)
        local direction = offset.Magnitude > 0 and offset.Unit or Vector2.new(0, 0)
        
        joystickKnob.Position = UDim2.new(0.5, direction.X * distance - 20, 0.5, direction.Y * distance - 20)
        
        if distance > joystickDeadzone * joystickRadius then
            local normalizedDistance = (distance - joystickDeadzone * joystickRadius) / (joystickRadius - joystickDeadzone * joystickRadius)
            moveDirection = Vector3.new(direction.X * normalizedDistance, 0, -direction.Y * normalizedDistance)
        else
            moveDirection = Vector3.new(0, 0, 0)
        end
    end

    joystickFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            joystickTouch = input
            updateJoystick(input.Position)
        end
    end)

    joystickFrame.InputChanged:Connect(function(input)
        if input == joystickTouch then
            updateJoystick(input.Position)
        end
    end)

    joystickFrame.InputEnded:Connect(function(input)
        if input == joystickTouch then
            joystickTouch = nil
            joystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
            moveDirection = Vector3.new(0, 0, 0)
        end
    end)
end

-- Create camera control
local function createCameraControl()
    if cameraControlFrame then
        cameraControlFrame:Destroy()
    end
    
    cameraControlFrame = Instance.new("Frame")
    cameraControlFrame.Size = UDim2.new(0, 200, 0, 120)
    cameraControlFrame.Position = UDim2.new(0.9, -200, 0.65, 0)
    cameraControlFrame.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    cameraControlFrame.BackgroundTransparency = 0.7
    cameraControlFrame.BorderSizePixel = 0
    cameraControlFrame.ZIndex = 15
    cameraControlFrame.Visible = false
    local camCorner = Instance.new("UICorner")
    camCorner.CornerRadius = UDim.new(0, 10)
    camCorner.Parent = cameraControlFrame
    cameraControlFrame.Parent = gui

    local camLabel = Instance.new("TextLabel")
    camLabel.Size = UDim2.new(1, 0, 0, 30)
    camLabel.BackgroundTransparency = 1
    camLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    camLabel.TextSize = 14
    camLabel.Font = Enum.Font.Gotham
    camLabel.Text = "Camera Control"
    camLabel.ZIndex = 16
    camLabel.Parent = cameraControlFrame

    cameraControlFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            cameraTouch = input
        end
    end)

    cameraControlFrame.InputChanged:Connect(function(input)
        if input == cameraTouch then
            cameraDelta = Vector2.new(input.Delta.X, input.Delta.Y) * 0.5
        end
    end)

    cameraControlFrame.InputEnded:Connect(function(input)
        if input == cameraTouch then
            cameraTouch = nil
            cameraDelta = Vector2.new(0, 0)
        end
    end)
end

-- Fixed player list UI
local function updatePlayerList()
    if not playerListFrame then return end
    
    local scrollFrame = playerListFrame:FindFirstChild("ScrollFrame")
    if not scrollFrame then return end
    
    -- Clear existing buttons
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name == "PlayerItem" then
            child:Destroy()
        end
    end
    
    -- Add player items
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player then
            local itemFrame = Instance.new("Frame")
            itemFrame.Name = "PlayerItem"
            itemFrame.Size = UDim2.new(1, -10, 0, 80)
            itemFrame.BackgroundColor3 = selectedPlayer == plr and Color3.fromRGB(60, 120, 60) or Color3.fromRGB(40, 40, 40)
            itemFrame.BackgroundTransparency = 0.3
            itemFrame.BorderSizePixel = 0
            itemFrame.ZIndex = 27
            local itemCorner = Instance.new("UICorner")
            itemCorner.CornerRadius = UDim.new(0, 8)
            itemCorner.Parent = itemFrame
            itemFrame.Parent = scrollFrame
            
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(0.6, 0, 0.5, 0)
            nameLabel.Position = UDim2.new(0, 10, 0, 5)
            nameLabel.BackgroundTransparency = 1
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLabel.TextSize = 16
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.Text = plr.Name
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.ZIndex = 28
            nameLabel.Parent = itemFrame
            
            local infoLabel = Instance.new("TextLabel")
            infoLabel.Size = UDim2.new(0.6, 0, 0.5, 0)
            infoLabel.Position = UDim2.new(0, 10, 0.5, 0)
            infoLabel.BackgroundTransparency = 1
            infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            infoLabel.TextSize = 12
            infoLabel.Font = Enum.Font.Gotham
            infoLabel.Text = "ID: " .. plr.UserId .. " | " .. (plr.Character and "Alive" or "Dead")
            infoLabel.TextXAlignment = Enum.TextXAlignment.Left
            infoLabel.ZIndex = 28
            infoLabel.Parent = itemFrame
            
            -- Select button
            local selectBtn = Instance.new("TextButton")
            selectBtn.Size = UDim2.new(0, 60, 0, 25)
            selectBtn.Position = UDim2.new(1, -130, 0, 5)
            selectBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
            selectBtn.BackgroundTransparency = 0.2
            selectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            selectBtn.TextSize = 12
            selectBtn.Font = Enum.Font.Gotham
            selectBtn.Text = selectedPlayer == plr and "Selected" or "Select"
            selectBtn.ZIndex = 29
            local selectCorner = Instance.new("UICorner")
            selectCorner.CornerRadius = UDim.new(0, 4)
            selectCorner.Parent = selectBtn
            selectBtn.MouseButton1Click:Connect(function()
                selectedPlayer = plr
                notify("👤 Selected: " .. plr.Name)
                updatePlayerList()
            end)
            selectBtn.Parent = itemFrame
            
            -- TP button
            local tpBtn = Instance.new("TextButton")
            tpBtn.Size = UDim2.new(0, 60, 0, 25)
            tpBtn.Position = UDim2.new(1, -65, 0, 5)
            tpBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
            tpBtn.BackgroundTransparency = 0.2
            tpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            tpBtn.TextSize = 12
            tpBtn.Font = Enum.Font.Gotham
            tpBtn.Text = "TP"
            tpBtn.ZIndex = 29
            local tpCorner = Instance.new("UICorner")
            tpCorner.CornerRadius = UDim.new(0, 4)
            tpCorner.Parent = tpBtn
            tpBtn.MouseButton1Click:Connect(function()
                selectedPlayer = plr
                teleportToPlayer()
            end)
            tpBtn.Parent = itemFrame
            
            -- Spectate button
            local spectateBtn = Instance.new("TextButton")
            spectateBtn.Size = UDim2.new(0, 80, 0, 25)
            spectateBtn.Position = UDim2.new(1, -130, 0, 35)
            spectateBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 150)
            spectateBtn.BackgroundTransparency = 0.2
            spectateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            spectateBtn.TextSize = 12
            spectateBtn.Font = Enum.Font.Gotham
            spectateBtn.Text = spectatingPlayer == plr and "Stop" or "Spectate"
            spectateBtn.ZIndex = 29
            local spectateCorner = Instance.new("UICorner")
            spectateCorner.CornerRadius = UDim.new(0, 4)
            spectateCorner.Parent = spectateBtn
            spectateBtn.MouseButton1Click:Connect(function()
                if spectatingPlayer == plr then
                    stopSpectate()
                else
                    selectedPlayer = plr
                    spectatePlayer()
                end
                updatePlayerList()
            end)
            spectateBtn.Parent = itemFrame
        end
    end
end

local function createPlayerListUI()
    if playerListFrame then
        playerListFrame:Destroy()
    end
    
    playerListFrame = Instance.new("Frame")
    playerListFrame.Size = UDim2.new(0, 350, 0, 450)
    playerListFrame.Position = UDim2.new(0, 20, 0.5, -225)
    playerListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    playerListFrame.BackgroundTransparency = 0.1
    playerListFrame.BorderSizePixel = 0
    playerListFrame.Visible = false
    playerListFrame.ZIndex = 25
    local playerFrameCorner = Instance.new("UICorner")
    playerFrameCorner.CornerRadius = UDim.new(0, 12)
    playerFrameCorner.Parent = playerListFrame
    playerListFrame.Parent = gui

    local playerTitle = Instance.new("TextLabel")
    playerTitle.Size = UDim2.new(1, 0, 0, 50)
    playerTitle.BackgroundTransparency = 1
    playerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    playerTitle.TextSize = 20
    playerTitle.Font = Enum.Font.GothamBold
    playerTitle.Text = "Player List (" .. (#Players:GetPlayers() - 1) .. " players)"
    playerTitle.ZIndex = 26
    playerTitle.Parent = playerListFrame

    local playerScrollFrame = Instance.new("ScrollingFrame")
    playerScrollFrame.Name = "ScrollFrame"
    playerScrollFrame.Size = UDim2.new(1, -20, 1, -70)
    playerScrollFrame.Position = UDim2.new(0, 10, 0, 60)
    playerScrollFrame.BackgroundTransparency = 1
    playerScrollFrame.ScrollBarThickness = 8
    playerScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    playerScrollFrame.ZIndex = 26
    playerScrollFrame.ClipsDescendants = true
    playerScrollFrame.ScrollingEnabled = true
    playerScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    playerScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    playerScrollFrame.Parent = playerListFrame

    local playerUIL = Instance.new("UIListLayout")
    playerUIL.FillDirection = Enum.FillDirection.Vertical
    playerUIL.Padding = UDim.new(0, 5)
    playerUIL.Parent = playerScrollFrame

    local playerPadding = Instance.new("UIPadding")
    playerPadding.PaddingTop = UDim.new(0, 5)
    playerPadding.PaddingBottom = UDim.new(0, 5)
    playerPadding.PaddingLeft = UDim.new(0, 5)
    playerPadding.PaddingRight = UDim.new(0, 5)
    playerPadding.Parent = playerScrollFrame

    -- Close button
    local closePlayerListBtn = Instance.new("TextButton")
    closePlayerListBtn.Size = UDim2.new(0, 30, 0, 30)
    closePlayerListBtn.Position = UDim2.new(1, -40, 0, 10)
    closePlayerListBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closePlayerListBtn.BackgroundTransparency = 0.3
    closePlayerListBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closePlayerListBtn.TextSize = 18
    closePlayerListBtn.Font = Enum.Font.GothamBold
    closePlayerListBtn.Text = "×"
    closePlayerListBtn.ZIndex = 28
    local closePlayerCorner = Instance.new("UICorner")
    closePlayerCorner.CornerRadius = UDim.new(0, 15)
    closePlayerCorner.Parent = closePlayerListBtn
    closePlayerListBtn.MouseButton1Click:Connect(function()
        playerListFrame.Visible = false
    end)
    closePlayerListBtn.Parent = playerListFrame

    updatePlayerList()
    
    -- Update player list when players join/leave
    Players.PlayerAdded:Connect(function()
        if playerListFrame and playerListFrame.Visible then
            updatePlayerList()
            playerTitle.Text = "Player List (" .. (#Players:GetPlayers() - 1) .. " players)"
        end
    end)
    
    Players.PlayerRemoving:Connect(function()
        task.wait(0.1)
        if playerListFrame and playerListFrame.Visible then
            updatePlayerList()
            playerTitle.Text = "Player List (" .. (#Players:GetPlayers() - 1) .. " players)"
        end
    end)
end

local function showPlayerList()
    if playerListFrame then
        playerListFrame.Visible = not playerListFrame.Visible
        if playerListFrame.Visible then
            updatePlayerList()
            local playerTitle = playerListFrame:FindFirstChild("TextLabel")
            if playerTitle then
                playerTitle.Text = "Player List (" .. (#Players:GetPlayers() - 1) .. " players)"
            end
        end
    end
end

-- Enhanced GUI creation with all new features
local function createEnhancedGUI()
    local success, errorMsg = pcall(function()
        if gui then
            gui:Destroy()
            gui = nil
        end

        gui = Instance.new("ScreenGui")
        gui.Name = "SimpleUILibrary_Krnl"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Enabled = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = player:WaitForChild("PlayerGui", 20)

        local scale = Instance.new("UIScale")
        scale.Scale = math.min(1, math.min(camera.ViewportSize.X / 1280, camera.ViewportSize.Y / 720))
        scale.Parent = gui

        logo = Instance.new("ImageButton")
        logo.Size = UDim2.new(0, 60, 0, 60)
        logo.Position = defaultLogoPos
        logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        logo.BackgroundTransparency = 0.3
        logo.BorderSizePixel = 0
        logo.Image = "rbxassetid://3570695787"
        logo.ZIndex = 20
        local logoCorner = Instance.new("UICorner")
        logoCorner.CornerRadius = UDim.new(0, 12)
        logoCorner.Parent = logo
        logo.Parent = gui

        frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 900, 0, 600)
        frame.Position = UDim2.new(0.5, -450, 0.5, -300)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        frame.BackgroundTransparency = 0.1
        frame.BorderSizePixel = 0
        frame.Visible = false
        frame.ZIndex = 10
        frame.ClipsDescendants = true
        local frameCorner = Instance.new("UICorner")
        frameCorner.CornerRadius = UDim.new(0, 12)
        frameCorner.Parent = frame
        frame.Parent = gui

        local sidebar = Instance.new("Frame")
        sidebar.Size = UDim2.new(0, 220, 1, 0)
        sidebar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        sidebar.BackgroundTransparency = 0.2
        sidebar.BorderSizePixel = 0
        sidebar.ZIndex = 11
        sidebar.Parent = frame

        local sidebarUIL = Instance.new("UIListLayout")
        sidebarUIL.FillDirection = Enum.FillDirection.Vertical
        sidebarUIL.Padding = UDim.new(0, 8)
        sidebarUIL.Parent = sidebar

        local sidebarPadding = Instance.new("UIPadding")
        sidebarPadding.PaddingTop = UDim.new(0, 15)
        sidebarPadding.PaddingLeft = UDim.new(0, 10)
        sidebarPadding.PaddingRight = UDim.new(0, 10)
        sidebarPadding.Parent = sidebar

        local function createCategoryButton(categoryName)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -20, 0, 45)
    button.BackgroundColor3 = categoryName == currentCategory and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(50, 50, 50)
    button.BackgroundTransparency = 0.2
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 16
    button.Font = Enum.Font.Gotham
    button.Text = categoryName
    button.Name = categoryName
    button.ZIndex = 12
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = button
    
    button.MouseEnter:Connect(function()
        if categoryName ~= currentCategory then
            button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        end
    end)
    
    button.MouseLeave:Connect(function()
        if categoryName ~= currentCategory then
            button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        end
    end)
    
    button.MouseButton1Click:Connect(function()
        updateCategory(categoryName)
    end)
    
    button.Parent = sidebar
    return button
end

for categoryName, _ in pairs(categories) do
    createCategoryButton(categoryName)
end

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -20, 0, 50)
        title.BackgroundTransparency = 1
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextSize = 22
        title.Font = Enum.Font.GothamBold
        title.Text = "Enhanced Krnl Mobile"
        title.ZIndex = 12
        title.Parent = sidebar

        local contentFrame = Instance.new("Frame")
        contentFrame.Size = UDim2.new(0, 660, 1, -10)
        contentFrame.Position = UDim2.new(0, 230, 0, 5)
        contentFrame.BackgroundTransparency = 1
        contentFrame.ZIndex = 11
        contentFrame.ClipsDescendants = true
        contentFrame.Parent = frame

        local scrollFrame = Instance.new("ScrollingFrame")
        scrollFrame.Size = UDim2.new(1, -10, 1, -10)
        scrollFrame.Position = UDim2.new(0, 5, 0, 5)
        scrollFrame.BackgroundTransparency = 1
        scrollFrame.ScrollBarThickness = 8
        scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
        scrollFrame.ZIndex = 11
        scrollFrame.ClipsDescendants = true
        scrollFrame.ScrollingEnabled = true
        scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        scrollFrame.Parent = contentFrame

        local scrollUIL = Instance.new("UIListLayout")
        scrollUIL.FillDirection = Enum.FillDirection.Vertical
        scrollUIL.Padding = UDim.new(0, 8)
        scrollUIL.Parent = scrollFrame

        local scrollPadding = Instance.new("UIPadding")
        scrollPadding.PaddingTop = UDim.new(0, 15)
        scrollPadding.PaddingBottom = UDim.new(0, 20)
        scrollPadding.PaddingLeft = UDim.new(0, 15)
        scrollPadding.PaddingRight = UDim.new(0, 15)
        scrollPadding.Parent = scrollFrame

        local function createButton(text, callback, toggleState)
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, -10, 0, 45)
            button.BackgroundColor3 = toggleState() and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
            button.BackgroundTransparency = 0.2
            button.TextColor3 = Color3.fromRGB(255, 255, 255)
            button.TextSize = 16
            button.Font = Enum.Font.Gotham
            button.Text = text
            button.TextWrapped = true
            button.ZIndex = 12
            button.Visible = false
            local buttonCorner = Instance.new("UICorner")
            buttonCorner.CornerRadius = UDim.new(0, 8)
            buttonCorner.Parent = button
            
            button.MouseEnter:Connect(function()
                button.BackgroundColor3 = toggleState() and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(70, 70, 70)
            end)
            button.MouseLeave:Connect(function()
                button.BackgroundColor3 = toggleState() and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
            end)
            button.MouseButton1Click:Connect(function()
                local success, err = pcall(callback)
                if not success then
                    notify("⚠️ Error in " .. text .. ": " .. tostring(err), Color3.fromRGB(255, 100, 100))
                end
                button.BackgroundColor3 = toggleState() and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
            end)
            return button
        end

        -- CHANGED: Added Toggle Auto Teleport button to Teleport category
        local categories = {
            Movement = {
                createButton("Toggle Fly", toggleFly, function() return flying end),
                createButton("Toggle Noclip", toggleNoclip, function() return noclip end),
                createButton("Toggle Speed", toggleSpeed, function() return speedEnabled end),
                createButton("Toggle Jump Power", toggleJump, function() return jumpEnabled end),
                createButton("Toggle Water Walk", toggleWaterWalk, function() return waterWalk end),
                createButton("Toggle God Mode", toggleGodMode, function() return godMode end)
            },
            Visual = {
                createButton("Toggle Freecam", toggleFreecam, function() return freecam end),
                createButton("Teleport to Freecam", teleportToFreecam, function() return false end)
            },
            World = {
                createButton("Toggle Freeze Moving Parts", toggleFreezeMovingParts, function() return freezeMovingParts end)
            },
            Player = {
                createButton("Open Player List", showPlayerList, function() return false end),
                createButton("Spectate Selected Player", spectatePlayer, function() return spectatingPlayer ~= nil end),
                createButton("Stop Spectate", stopSpectate, function() return false end),
                createButton("Teleport to Selected Player", teleportToPlayer, function() return false end)
            },
            Teleport = {
                createButton("Teleport to Spawn", teleportToSpawn, function() return false end),
                createButton("Save Current Position", function() saveCurrentPosition() end, function() return false end),
                createButton("Open Position List", showPositionList, function() return false end),
                createButton("Toggle Auto Teleport", toggleAutoTeleport, function() return isAutoTeleportActive end) -- NEW: Auto-Teleport button
            },
            Macro = {
                createButton("Toggle Practice Mode", togglePracticeMode, function() return practiceMode end),
                createButton("Toggle Record Macro", toggleRecordMacro, function() return macroRecording end),
                createButton("Toggle Play Macro", togglePlayMacro, function() return macroPlaying end),
                createButton("Finish Macro Successfully", finishMacroSuccessfully, function() return false end)
            }
        }

        -- Rest of createEnhancedGUI remains unchanged, included for context
        for categoryName, buttons in pairs(categories) do
            for _, button in pairs(buttons) do
                button.Parent = scrollFrame
            end
        end

        local function updateCategory(categoryName)
            for _, buttons in pairs(categories) do
                for _, button in pairs(buttons) do
                    button.Visible = false
                end
            end
            
            if categories[categoryName] then
                for _, button in pairs(categories[categoryName]) do
                    button.Visible = true
                end
            end
            
            currentCategory = categoryName
            
            for _, child in pairs(sidebar:GetChildren()) do
                if child:IsA("TextButton") and categories[child.Name] then
                    child.BackgroundColor3 = child.Name == categoryName and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(50, 50, 50)
                end
            end
            
            scrollFrame.CanvasPosition = Vector2.new(0, 0)
            notify("📂 " .. categoryName .. " (" .. #categories[categoryName] .. " features)")
        end

        -- Initialize with Movement category
        updateCategory("Movement")

        logo.MouseButton1Click:Connect(function()
            frame.Visible = not frame.Visible
        end)

        -- Make frame draggable
        local dragging, dragInput, dragStart, startPos
        local function updateDrag(input)
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
        
        title.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = frame.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        
        title.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        
        UserInputService.InputChanged:Connect(function()
            if dragInput and dragging then
                updateDrag(dragInput)
            end
        end)
        
        -- Status display
        local statusFrame = Instance.new("Frame")
        statusFrame.Size = UDim2.new(1, 0, 0, 60)
        statusFrame.Position = UDim2.new(0, 0, 1, -60)
        statusFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        statusFrame.BackgroundTransparency = 0.3
        statusFrame.BorderSizePixel = 0
        statusFrame.ZIndex = 11
        statusFrame.Parent = frame
        
        local statusLabel = Instance.new("TextLabel")
        statusLabel.Size = UDim2.new(1, -20, 1, 0)
        statusLabel.Position = UDim2.new(0, 10, 0, 0)
        statusLabel.BackgroundTransparency = 1
        statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        statusLabel.TextSize = 14
        statusLabel.Font = Enum.Font.Gotham
        statusLabel.Text = "✅ Enhanced Krnl Mobile v2.0 | Positions: " .. #savedPositions .. " | Attempts: " .. totalAttempts
        statusLabel.TextXAlignment = Enum.TextXAlignment.Left
        statusLabel.ZIndex = 12
        statusLabel.Parent = statusFrame
        
        -- Update status periodically
        task.spawn(function()
            while gui and gui.Parent do
                if statusLabel then
                    local macroStatus = ""
                    if macroRecording then
                        macroStatus = "🔴 Recording"
                    elseif macroPlaying then
                        macroStatus = "▶️ Playing"
                    elseif practiceMode then
                        macroStatus = "🎯 Practice"
                    end
                    
                    statusLabel.Text = "✅ Enhanced Krnl Mobile v2.0 | Positions: " .. #savedPositions .. 
                                     " | Attempts: " .. totalAttempts .. 
                                     (macroStatus ~= "" and " | " .. macroStatus or "") ..
                                     (autoSaveEnabled and " | Auto Save ON" or "")
                end
                task.wait(1)
            end
        end)
    end)
    
    if not success then
        notify("⚠️ Enhanced GUI creation failed: " .. tostring(errorMsg) .. ", retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(2)
        createEnhancedGUI()
    end
end

-- Cleanup old instance
local function cleanupOldInstance()
    local oldGui = player.PlayerGui:FindFirstChild("SimpleUILibrary_Krnl")
    if oldGui then
        oldGui:Destroy()
        notify("🛠️ Old script instance terminated", Color3.fromRGB(255, 255, 0))
    end
end

-- Main initialization
local function main()
    local success, errorMsg = pcall(function()
        cleanupOldInstance()
        loadFromLocalStorage() -- CHANGED: Use new storage function
        task.wait(1.5)
        createEnhancedGUI()
        createJoystick()
        createCameraControl()
        createPlayerListUI()
        createPositionListUI()
        initChar()
        
        -- Connect character respawn
        player.CharacterAdded:Connect(function()
            task.wait(2)
            initChar()
        end)
        
        notify("🚀 Enhanced Krnl Mobile v2.0 Loaded Successfully!")
        notify("📱 100% Mobile GUI - All features accessible via touch interface")
    end)
    if not success then
        notify("⚠️ Script failed to load: " .. tostring(errorMsg) .. ", retrying...", Color3.fromRGB(255, 100, 100))
        task.wait(2)
        main()
    end
end

main()