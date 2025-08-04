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
local spectateUI = nil
local spectateNextBtn = nil
local spectatePrevBtn = nil
local spectateStopBtn = nil
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

-- Category system for positions
local categories = {
    "General",
    "Spawn",
    "Checkpoint", 
    "Important",
    "Custom"
}
local currentCategory = "General"

-- Function to add new category
local function addNewCategory(categoryName)
    if not categoryName or categoryName == "" then return false end
    
    -- Check if category already exists
    for _, cat in ipairs(categories) do
        if cat == categoryName then
            return false
        end
    end
    
    table.insert(categories, categoryName)
    saveData()
    notify("📁 Added new category: " .. categoryName, Color3.fromRGB(0, 255, 255))
    return true
end

-- Simple macro system (like Geometry Dash)
local macroRecording = false
local macroPlaying = false
local macroActions = {}
local macroPerfectActions = {}
local currentAttempt = 1
local totalAttempts = 0
local practiceMode = false
local macroStartTime = 0

-- Mobile specific variables
local freecamCFrame = nil
local hrCFrame = nil
local joystickTouch = nil
local cameraTouch = nil
local joystickRadius = 50
local joystickDeadzone = 0.15
local moveDirection = Vector3.new(0, 0, 0)
local cameraDelta = Vector2.new(0, 0)
local cameraRotationSensitivity = 0.02 -- Increased from 0.01
local nickHidden, randomNick = false, false
local customNick = "PemainKeren"
local defaultLogoPos = UDim2.new(0.95, -50, 0.05, 10)
local defaultFramePos = UDim2.new(0.5, -400, 0.5, -250)
local freezeMovingParts = false
local originalCFrames = {}

-- Admin detection system
local adminDetectionEnabled = true
local adminList = {}
local detectedAdmins = {}
local adminWarningShown = false

-- Fake stats system
local fakeStatsEnabled = false
local fakeStatsData = {}
local fakeStatsBillboard = nil
local fakeStatsText = nil
local currentFakeStat = ""
local fakeStatsRotation = {}
local fakeStatsRotationIndex = 1
local fakeStatsRotationSpeed = 3 -- seconds per stat
local autoDetectGameStats = true

local connections = {}

-- Android DCIM folder path
local dcimPath = "DCIM/Supertool"
local gameName = game.Name or "UnknownGame"

-- Load saved data with local persistence
local function loadSavedData()
    local success, result = pcall(function()
        -- Try to load from DCIM/Supertool folder if available
        if writefile and readfile then
            local filePath = dcimPath .. "/" .. gameName .. "_checkpoints.json"
            if isfile and isfile(filePath) then
                local fileContent = readfile(filePath)
                local savedData = HttpService:JSONDecode(fileContent)
                savedPositions = savedData.positions or {}
                positionCounter = savedData.positionCounter or #savedPositions
                categories = savedData.categories or categories
                currentCategory = savedData.currentCategory or "General"
                notify("📁 Loaded " .. #savedPositions .. " checkpoints from DCIM/Supertool", Color3.fromRGB(0, 255, 255))
                return true
            else
                notify("📁 No saved checkpoints found, starting fresh", Color3.fromRGB(255, 255, 0))
            end
        end
        
        -- Fallback to memory-only storage
        savedPositions = savedPositions or {}
        positionCounter = #savedPositions
        return true
    end)
    
    if not success then
        print("Failed to load saved data: " .. tostring(result))
        savedPositions = savedPositions or {}
        positionCounter = #savedPositions
        notify("⚠️ Failed to load checkpoints: " .. tostring(result), Color3.fromRGB(255, 100, 100))
    end
end

-- Save data with local persistence
local function saveData()
    local success, errorMsg = pcall(function()
        local dataToSave = {
            positions = savedPositions,
            positionCounter = positionCounter,
            categories = categories,
            currentCategory = currentCategory,
            lastSaved = os.time(),
            gameName = gameName
        }
        local jsonData = HttpService:JSONEncode(dataToSave)
        
        -- Try to save to DCIM/Supertool folder if available
        if writefile then
            local filePath = dcimPath .. "/" .. gameName .. "_checkpoints.json"
            writefile(filePath, jsonData)
            notify("💾 Saved " .. #savedPositions .. " checkpoints to DCIM/Supertool", Color3.fromRGB(0, 255, 0))
        end
        
        -- Data is also kept in memory for the session
    end)
    
    if not success then
        print("Failed to save data: " .. tostring(errorMsg))
        notify("⚠️ Failed to save checkpoints: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Save individual checkpoint with custom name
local function saveCheckpoint(checkpointName, category)
    local success, errorMsg = pcall(function()
        if hr then
            positionCounter = positionCounter + 1
            local positionName = checkpointName or ("Checkpoint " .. positionCounter)
            local positionCategory = category or currentCategory
            local positionData = {
                name = positionName,
                cframe = hr.CFrame,
                timestamp = os.time(),
                id = positionCounter,
                category = positionCategory
            }
            
            table.insert(savedPositions, positionData)
            
            if #savedPositions > maxSavedPositions then
                table.remove(savedPositions, 1)
            end
            
            saveData()
            notify("💾 Saved: " .. positionName .. " (" .. positionCategory .. ")")
            
            if positionListFrame and positionListFrame.Visible then
                updatePositionList()
            end
        else
            notify("⚠️ Character not loaded", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Save Checkpoint error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
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

-- Simple macro system functions (like Geometry Dash)
local function recordMacroAction(actionType, data)
    if macroRecording then
        local action = {
            time = tick() - macroStartTime,
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
        
        -- Reset actions for next attempt
        macroActions = {}
        macroStartTime = tick()
    end
end

local function onCharacterFinished()
    if macroRecording and practiceMode then
        -- Save the perfect run (no deaths)
        macroPerfectActions = {}
        for _, action in ipairs(macroActions) do
            table.insert(macroPerfectActions, action)
        end
        
        notify("✅ Perfect run recorded! (" .. #macroPerfectActions .. " actions, " .. totalAttempts .. " attempts)", Color3.fromRGB(0, 255, 0))
        notify("🎯 Now you can play the perfect run!", Color3.fromRGB(0, 255, 255))
    end
end

local function toggleRecordMacro()
    macroRecording = not macroRecording
    if macroRecording then
        macroActions = {}
        macroPerfectActions = {}
        currentAttempt = 1
        totalAttempts = 1
        practiceMode = true
        macroStartTime = tick()
        
        if humanoid then
            connections.macroDeath = humanoid.Died:Connect(onCharacterDied)
        end
        
        notify("🔴 Macro Recording Started (Practice Mode)", Color3.fromRGB(255, 0, 0))
        notify("💀 Practice until you complete without dying", Color3.fromRGB(255, 255, 0))
    else
        if connections.macroDeath then
            connections.macroDeath:Disconnect()
            connections.macroDeath = nil
        end
        
        practiceMode = false
        notify("⏹️ Macro Recording Stopped", Color3.fromRGB(255, 255, 0))
        
        if #macroPerfectActions > 0 then
            notify("🎯 Perfect run saved! (" .. #macroPerfectActions .. " actions)", Color3.fromRGB(0, 255, 0))
        else
            notify("⚠️ No perfect run recorded", Color3.fromRGB(255, 100, 100))
        end
    end
end

local function togglePlayMacro()
    macroPlaying = not macroPlaying
    if macroPlaying then
        if #macroPerfectActions == 0 then
            macroPlaying = false
            notify("⚠️ No perfect macro recorded! Practice first!", Color3.fromRGB(255, 100, 100))
            return
        end
        
        notify("▶️ Playing Perfect Macro (" .. #macroPerfectActions .. " actions)", Color3.fromRGB(0, 255, 0))
        
        task.spawn(function()
            local startTime = tick()
            local actionIndex = 1
            
            while macroPlaying and actionIndex <= #macroPerfectActions do
                local action = macroPerfectActions[actionIndex]
                local targetTime = startTime + action.time
                
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
                notify("✅ Perfect macro completed!", Color3.fromRGB(0, 255, 0))
                macroPlaying = false
            end
        end)
    else
        notify("⏹️ Macro Playback Stopped", Color3.fromRGB(255, 255, 0))
    end
end

-- Enhanced position saving system
local function saveCurrentPosition(customName, category)
    saveCheckpoint(customName, category)
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
                        saveCheckpoint("Auto Checkpoint " .. os.date("%H:%M:%S"), currentCategory)
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
            saveData()
            notify("🗑️ Deleted: " .. pos.name, Color3.fromRGB(255, 100, 100))
            if positionListFrame and positionListFrame.Visible then
                updatePositionList()
            end
            break
        end
    end
end

-- Auto teleport through all saved positions
local function autoTeleportAllPositions()
    local success, errorMsg = pcall(function()
        if #savedPositions == 0 then
            notify("⚠️ No saved checkpoints to teleport to", Color3.fromRGB(255, 100, 100))
            return
        end
        
        if not hr then
            notify("⚠️ Character not loaded", Color3.fromRGB(255, 100, 100))
            return
        end
        
        notify("🚀 Starting auto teleport through " .. #savedPositions .. " checkpoints", Color3.fromRGB(0, 255, 0))
        
        task.spawn(function()
            for i, pos in ipairs(savedPositions) do
                if hr then
                    hr.CFrame = pos.cframe
                    notify("📍 Teleported to: " .. pos.name .. " (" .. (pos.category or "General") .. ") - " .. i .. "/" .. #savedPositions, Color3.fromRGB(0, 255, 255))
                    task.wait(2) -- Wait 2 seconds between teleports
                else
                    notify("⚠️ Character lost during teleport", Color3.fromRGB(255, 100, 100))
                    break
                end
            end
            notify("✅ Auto teleport completed!", Color3.fromRGB(0, 255, 0))
        end)
    end)
    
    if not success then
        notify("⚠️ Auto teleport error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
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
    renameDialog.Size = UDim2.new(0, 350, 0, 200)
    renameDialog.Position = UDim2.new(0.5, -175, 0.5, -100)
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
    renameTitle.Text = "Edit Position"
    renameTitle.ZIndex = 36
    renameTitle.Parent = renameDialog
    
    -- Name label and input
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(0, 80, 0, 25)
    nameLabel.Position = UDim2.new(0, 10, 0, 50)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 14
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.Text = "Name:"
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.ZIndex = 36
    nameLabel.Parent = renameDialog
    
    local renameBox = Instance.new("TextBox")
    renameBox.Size = UDim2.new(1, -100, 0, 25)
    renameBox.Position = UDim2.new(0, 100, 0, 50)
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
    
    -- Category label and dropdown
    local categoryLabel = Instance.new("TextLabel")
    categoryLabel.Size = UDim2.new(0, 80, 0, 25)
    categoryLabel.Position = UDim2.new(0, 10, 0, 85)
    categoryLabel.BackgroundTransparency = 1
    categoryLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    categoryLabel.TextSize = 14
    categoryLabel.Font = Enum.Font.Gotham
    categoryLabel.Text = "Category:"
    categoryLabel.TextXAlignment = Enum.TextXAlignment.Left
    categoryLabel.ZIndex = 36
    categoryLabel.Parent = renameDialog
    
    local categoryDropdown = Instance.new("TextButton")
    categoryDropdown.Size = UDim2.new(1, -100, 0, 25)
    categoryDropdown.Position = UDim2.new(0, 100, 0, 85)
    categoryDropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    categoryDropdown.BackgroundTransparency = 0.3
    categoryDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
    categoryDropdown.TextSize = 14
    categoryDropdown.Font = Enum.Font.Gotham
    categoryDropdown.Text = pos.category or "General"
    categoryDropdown.ZIndex = 36
    local categoryDropdownCorner = Instance.new("UICorner")
    categoryDropdownCorner.CornerRadius = UDim.new(0, 5)
    categoryDropdownCorner.Parent = categoryDropdown
    categoryDropdown.Parent = renameDialog
    
    -- Category dropdown functionality
    local dropdownOpen = false
    local dropdownFrame = nil
    local selectedCategory = pos.category or "General"
    
    categoryDropdown.MouseButton1Click:Connect(function()
        if dropdownOpen then
            if dropdownFrame then
                dropdownFrame:Destroy()
                dropdownFrame = nil
            end
            dropdownOpen = false
        else
            if dropdownFrame then
                dropdownFrame:Destroy()
            end
            
            dropdownFrame = Instance.new("Frame")
            dropdownFrame.Size = UDim2.new(1, -100, 0, 25 * #categories)
            dropdownFrame.Position = UDim2.new(0, 100, 0, 110)
            dropdownFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            dropdownFrame.BorderSizePixel = 0
            dropdownFrame.ZIndex = 38
            local dropdownFrameCorner = Instance.new("UICorner")
            dropdownFrameCorner.CornerRadius = UDim.new(0, 5)
            dropdownFrameCorner.Parent = dropdownFrame
            dropdownFrame.Parent = renameDialog
            
            local dropdownUIL = Instance.new("UIListLayout")
            dropdownUIL.FillDirection = Enum.FillDirection.Vertical
            dropdownUIL.Parent = dropdownFrame
            
            for _, category in ipairs(categories) do
                local categoryBtn = Instance.new("TextButton")
                categoryBtn.Size = UDim2.new(1, 0, 0, 25)
                categoryBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                categoryBtn.BackgroundTransparency = 0.3
                categoryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                categoryBtn.TextSize = 14
                categoryBtn.Font = Enum.Font.Gotham
                categoryBtn.Text = category
                categoryBtn.ZIndex = 39
                categoryBtn.MouseButton1Click:Connect(function()
                    selectedCategory = category
                    categoryDropdown.Text = category
                    dropdownFrame:Destroy()
                    dropdownFrame = nil
                    dropdownOpen = false
                end)
                categoryBtn.Parent = dropdownFrame
            end
            
            dropdownOpen = true
        end
    end)
    
    local confirmBtn = Instance.new("TextButton")
    confirmBtn.Size = UDim2.new(0, 80, 0, 30)
    confirmBtn.Position = UDim2.new(0, 50, 0, 150)
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
            pos.category = selectedCategory
            saveData()
            notify("✏️ Updated: " .. renameBox.Text .. " (" .. selectedCategory .. ")")
            if positionListFrame and positionListFrame.Visible then
                updatePositionList()
            end
        end
        renameDialog:Destroy()
    end)
    confirmBtn.Parent = renameDialog
    
    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0, 80, 0, 30)
    cancelBtn.Position = UDim2.new(0, 220, 0, 150)
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

-- Create position list UI with categories
function updatePositionList()
    if not positionListFrame then return end
    
    local scrollFrame = positionListFrame:FindFirstChild("ScrollFrame")
    if not scrollFrame then return end
    
    -- Clear existing items
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Group positions by category
    local positionsByCategory = {}
    for _, pos in ipairs(savedPositions) do
        local category = pos.category or "General"
        if not positionsByCategory[category] then
            positionsByCategory[category] = {}
        end
        table.insert(positionsByCategory[category], pos)
    end
    
    -- Create category sections
    for categoryName, categoryPositions in pairs(positionsByCategory) do
        -- Category header
        local categoryFrame = Instance.new("Frame")
        categoryFrame.Name = "Category_" .. categoryName
        categoryFrame.Size = UDim2.new(1, -10, 0, 40)
        categoryFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        categoryFrame.BackgroundTransparency = 0.2
        categoryFrame.BorderSizePixel = 0
        categoryFrame.ZIndex = 27
        local categoryCorner = Instance.new("UICorner")
        categoryCorner.CornerRadius = UDim.new(0, 8)
        categoryCorner.Parent = categoryFrame
        categoryFrame.Parent = scrollFrame
        
        -- Category name and count
        local categoryLabel = Instance.new("TextLabel")
        categoryLabel.Size = UDim2.new(1, -80, 1, 0)
        categoryLabel.Position = UDim2.new(0, 10, 0, 0)
        categoryLabel.BackgroundTransparency = 1
        categoryLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        categoryLabel.TextSize = 16
        categoryLabel.Font = Enum.Font.GothamBold
        categoryLabel.Text = categoryName .. " (" .. #categoryPositions .. ")"
        categoryLabel.TextXAlignment = Enum.TextXAlignment.Left
        categoryLabel.ZIndex = 28
        categoryLabel.Parent = categoryFrame
        
        -- Collapse/Expand button
        local collapseBtn = Instance.new("TextButton")
        collapseBtn.Size = UDim2.new(0, 30, 0, 30)
        collapseBtn.Position = UDim2.new(1, -40, 0, 5)
        collapseBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        collapseBtn.BackgroundTransparency = 0.3
        collapseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        collapseBtn.TextSize = 18
        collapseBtn.Font = Enum.Font.GothamBold
        collapseBtn.Text = "▼"
        collapseBtn.ZIndex = 29
        local collapseCorner = Instance.new("UICorner")
        collapseCorner.CornerRadius = UDim.new(0, 4)
        collapseCorner.Parent = collapseBtn
        collapseBtn.Parent = categoryFrame
        
        -- Category content container
        local contentFrame = Instance.new("Frame")
        contentFrame.Name = "Content"
        contentFrame.Size = UDim2.new(1, 0, 0, 0)
        contentFrame.Position = UDim2.new(0, 0, 1, 0)
        contentFrame.BackgroundTransparency = 1
        contentFrame.ZIndex = 26
        contentFrame.Parent = categoryFrame
        
        local contentUIL = Instance.new("UIListLayout")
        contentUIL.FillDirection = Enum.FillDirection.Vertical
        contentUIL.Padding = UDim.new(0, 5)
        contentUIL.Parent = contentFrame
        
        -- Add position items to this category
        for i, pos in ipairs(categoryPositions) do
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
            itemFrame.Parent = contentFrame
            
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
        
        -- Collapse/Expand functionality
        local isCollapsed = false
        collapseBtn.MouseButton1Click:Connect(function()
            isCollapsed = not isCollapsed
            if isCollapsed then
                collapseBtn.Text = "▶"
                contentFrame.Size = UDim2.new(1, 0, 0, 0)
                contentFrame.Visible = false
            else
                collapseBtn.Text = "▼"
                contentFrame.Size = UDim2.new(1, 0, 0, contentUIL.AbsoluteContentSize.Y)
                contentFrame.Visible = true
            end
        end)
    end
end

local function createPositionListUI()
    if positionListFrame then
        positionListFrame:Destroy()
    end
    
    positionListFrame = Instance.new("Frame")
    positionListFrame.Size = UDim2.new(0, 450, 0, 600)
    positionListFrame.Position = UDim2.new(0, 20, 0.5, -300)
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
    posTitle.Text = "Saved Checkpoints (" .. #savedPositions .. ")"
    posTitle.ZIndex = 26
    posTitle.Parent = positionListFrame

    -- Auto teleport button
    local autoTeleportBtn = Instance.new("TextButton")
    autoTeleportBtn.Size = UDim2.new(0, 120, 0, 35)
    autoTeleportBtn.Position = UDim2.new(0, 10, 0, 55)
    autoTeleportBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
    autoTeleportBtn.BackgroundTransparency = 0.2
    autoTeleportBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoTeleportBtn.TextSize = 14
    autoTeleportBtn.Font = Enum.Font.GothamBold
    autoTeleportBtn.Text = "🚀 Auto Teleport"
    autoTeleportBtn.ZIndex = 28
    local autoTeleportCorner = Instance.new("UICorner")
    autoTeleportCorner.CornerRadius = UDim.new(0, 6)
    autoTeleportCorner.Parent = autoTeleportBtn
    autoTeleportBtn.MouseButton1Click:Connect(function()
        autoTeleportAllPositions()
    end)
    autoTeleportBtn.Parent = positionListFrame

    -- Category selector
    local categoryLabel = Instance.new("TextLabel")
    categoryLabel.Size = UDim2.new(0, 80, 0, 35)
    categoryLabel.Position = UDim2.new(0, 140, 0, 55)
    categoryLabel.BackgroundTransparency = 1
    categoryLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    categoryLabel.TextSize = 14
    categoryLabel.Font = Enum.Font.Gotham
    categoryLabel.Text = "Category:"
    categoryLabel.TextXAlignment = Enum.TextXAlignment.Left
    categoryLabel.ZIndex = 26
    categoryLabel.Parent = positionListFrame

    local categoryDropdown = Instance.new("TextButton")
    categoryDropdown.Size = UDim2.new(0, 100, 0, 35)
    categoryDropdown.Position = UDim2.new(0, 230, 0, 55)
    categoryDropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    categoryDropdown.BackgroundTransparency = 0.3
    categoryDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
    categoryDropdown.TextSize = 14
    categoryDropdown.Font = Enum.Font.Gotham
    categoryDropdown.Text = currentCategory
    categoryDropdown.ZIndex = 28
    local categoryDropdownCorner = Instance.new("UICorner")
    categoryDropdownCorner.CornerRadius = UDim.new(0, 6)
    categoryDropdownCorner.Parent = categoryDropdown
    categoryDropdown.Parent = positionListFrame

    -- Add category button
    local addCategoryBtn = Instance.new("TextButton")
    addCategoryBtn.Size = UDim2.new(0, 30, 0, 35)
    addCategoryBtn.Position = UDim2.new(0, 340, 0, 55)
    addCategoryBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
    addCategoryBtn.BackgroundTransparency = 0.2
    addCategoryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    addCategoryBtn.TextSize = 16
    addCategoryBtn.Font = Enum.Font.GothamBold
    addCategoryBtn.Text = "+"
    addCategoryBtn.ZIndex = 28
    local addCategoryCorner = Instance.new("UICorner")
    addCategoryCorner.CornerRadius = UDim.new(0, 6)
    addCategoryCorner.Parent = addCategoryBtn
    addCategoryBtn.MouseButton1Click:Connect(function()
        -- Create add category dialog
        local addDialog = Instance.new("Frame")
        addDialog.Size = UDim2.new(0, 300, 0, 150)
        addDialog.Position = UDim2.new(0.5, -150, 0.5, -75)
        addDialog.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        addDialog.BorderSizePixel = 0
        addDialog.ZIndex = 35
        local addDialogCorner = Instance.new("UICorner")
        addDialogCorner.CornerRadius = UDim.new(0, 10)
        addDialogCorner.Parent = addDialog
        addDialog.Parent = gui
        
        local addTitle = Instance.new("TextLabel")
        addTitle.Size = UDim2.new(1, 0, 0, 40)
        addTitle.BackgroundTransparency = 1
        addTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        addTitle.TextSize = 16
        addTitle.Font = Enum.Font.GothamBold
        addTitle.Text = "Add New Category"
        addTitle.ZIndex = 36
        addTitle.Parent = addDialog
        
        local categoryBox = Instance.new("TextBox")
        categoryBox.Size = UDim2.new(1, -20, 0, 30)
        categoryBox.Position = UDim2.new(0, 10, 0, 50)
        categoryBox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        categoryBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        categoryBox.TextSize = 14
        categoryBox.Font = Enum.Font.Gotham
        categoryBox.PlaceholderText = "Enter category name..."
        categoryBox.ZIndex = 36
        local boxCorner = Instance.new("UICorner")
        boxCorner.CornerRadius = UDim.new(0, 5)
        boxCorner.Parent = categoryBox
        categoryBox.Parent = addDialog
        
        local confirmBtn = Instance.new("TextButton")
        confirmBtn.Size = UDim2.new(0, 80, 0, 30)
        confirmBtn.Position = UDim2.new(0, 50, 0, 100)
        confirmBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        confirmBtn.TextSize = 14
        confirmBtn.Font = Enum.Font.Gotham
        confirmBtn.Text = "Add"
        confirmBtn.ZIndex = 36
        local confirmCorner = Instance.new("UICorner")
        confirmCorner.CornerRadius = UDim.new(0, 5)
        confirmCorner.Parent = confirmBtn
        confirmBtn.MouseButton1Click:Connect(function()
            if categoryBox.Text ~= "" then
                if addNewCategory(categoryBox.Text) then
                    -- Update dropdown if it exists
                    if dropdownFrame then
                        dropdownFrame:Destroy()
                        dropdownFrame = nil
                    end
                end
            end
            addDialog:Destroy()
        end)
        confirmBtn.Parent = addDialog
        
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
            addDialog:Destroy()
        end)
        cancelBtn.Parent = addDialog
    end)
    addCategoryBtn.Parent = positionListFrame

    -- Category dropdown functionality
    local dropdownOpen = false
    local dropdownFrame = nil
    
    categoryDropdown.MouseButton1Click:Connect(function()
        if dropdownOpen then
            if dropdownFrame then
                dropdownFrame:Destroy()
                dropdownFrame = nil
            end
            dropdownOpen = false
        else
            if dropdownFrame then
                dropdownFrame:Destroy()
            end
            
            dropdownFrame = Instance.new("Frame")
            dropdownFrame.Size = UDim2.new(0, 100, 0, 35 * #categories)
            dropdownFrame.Position = UDim2.new(0, 230, 0, 90)
            dropdownFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            dropdownFrame.BorderSizePixel = 0
            dropdownFrame.ZIndex = 30
            local dropdownFrameCorner = Instance.new("UICorner")
            dropdownFrameCorner.CornerRadius = UDim.new(0, 6)
            dropdownFrameCorner.Parent = dropdownFrame
            dropdownFrame.Parent = positionListFrame
            
            local dropdownUIL = Instance.new("UIListLayout")
            dropdownUIL.FillDirection = Enum.FillDirection.Vertical
            dropdownUIL.Parent = dropdownFrame
            
            for _, category in ipairs(categories) do
                local categoryBtn = Instance.new("TextButton")
                categoryBtn.Size = UDim2.new(1, 0, 0, 35)
                categoryBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                categoryBtn.BackgroundTransparency = 0.3
                categoryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                categoryBtn.TextSize = 14
                categoryBtn.Font = Enum.Font.Gotham
                categoryBtn.Text = category
                categoryBtn.ZIndex = 31
                categoryBtn.MouseButton1Click:Connect(function()
                    currentCategory = category
                    categoryDropdown.Text = category
                    dropdownFrame:Destroy()
                    dropdownFrame = nil
                    dropdownOpen = false
                    saveData()
                end)
                categoryBtn.Parent = dropdownFrame
            end
            
            dropdownOpen = true
        end
    end)

    local posScrollFrame = Instance.new("ScrollingFrame")
    posScrollFrame.Name = "ScrollFrame"
    posScrollFrame.Size = UDim2.new(1, -20, 1, -110)
    posScrollFrame.Position = UDim2.new(0, 10, 0, 100)
    posScrollFrame.BackgroundTransparency = 1
    posScrollFrame.ScrollBarThickness = 8
    posScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    posScrollFrame.ZIndex = 26
    posScrollFrame.ClipsDescendants = true
    posScrollFrame.ScrollingEnabled = true
    posScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    posScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
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

    -- Close button
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
        if dropdownFrame then
            dropdownFrame:Destroy()
            dropdownFrame = nil
            dropdownOpen = false
        end
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
                posTitle.Text = "Saved Checkpoints (" .. #savedPositions .. ")"
            end
        end
        notify(positionListFrame.Visible and "📍 Checkpoint List Opened" or "📍 Checkpoint List Closed")
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
        
        -- Connect macro recording to new character
        if macroRecording and humanoid then
            if connections.macroDeath then
                connections.macroDeath:Disconnect()
            end
            connections.macroDeath = humanoid.Died:Connect(onCharacterDied)
        end
        
        -- Recreate fake stats billboard if enabled
        if fakeStatsEnabled then
            task.wait(1) -- Wait for character to fully load
            createFakeStatsBillboard()
            if fakeStatsBillboard then
                fakeStatsBillboard.Enabled = true
                updateFakeStatsDisplay()
            end
        end
        
        -- Reapply all active features
        if flying then toggleFly() toggleFly() end
        if freecam then toggleFreecam() toggleFreecam() end
        if noclip then toggleNoclip() toggleNoclip() end
        if speedEnabled then toggleSpeed() toggleSpeed() end
        if jumpEnabled then toggleJump() toggleJump() end
        if waterWalk then toggleWaterWalk() toggleWaterWalk() end
        if godMode then toggleGodMode() toggleGodMode() end
        -- Macro will be handled separately
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
            ensureOverlayOnTop()
            
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
            ensureOverlayOnTop()
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

-- Enhanced player functions
local function spectatePlayer()
    local success, errorMsg = pcall(function()
        if not selectedPlayer then
            notify("⚠️ No player selected", Color3.fromRGB(255, 100, 100))
            return
        end
        
        if not selectedPlayer.Character then
            notify("⚠️ " .. selectedPlayer.Name .. " has no character", Color3.fromRGB(255, 100, 100))
            return
        end
        
        local targetHumanoid = selectedPlayer.Character:FindFirstChild("Humanoid")
        if not targetHumanoid then
            notify("⚠️ " .. selectedPlayer.Name .. " has no humanoid", Color3.fromRGB(255, 100, 100))
            return
        end
        
        if targetHumanoid.Health <= 0 then
            notify("⚠️ Cannot spectate dead player", Color3.fromRGB(255, 100, 100))
            return
        end
        
        spectatingPlayer = selectedPlayer
        camera.CameraSubject = targetHumanoid
        notify("👁️ Spectating " .. selectedPlayer.Name)
        
        -- Show spectate UI
        updateSpectateUI()
        
        -- Setup auto-switch when player dies
        setupSpectateAutoSwitch()
        
        -- Update player list to reflect spectate status
        if playerListFrame and playerListFrame.Visible then
            updatePlayerList()
        end
    end)
    if not success then
        notify("⚠️ Spectate error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Create spectate UI
local function createSpectateUI()
    if spectateUI then
        spectateUI:Destroy()
    end
    
    spectateUI = Instance.new("Frame")
    spectateUI.Size = UDim2.new(0, 350, 0, 120) -- Bigger for mobile
    spectateUI.Position = UDim2.new(0.5, -175, 0.1, 0)
    spectateUI.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    spectateUI.BackgroundTransparency = 0.2
    spectateUI.BorderSizePixel = 0
    spectateUI.ZIndex = 50
    spectateUI.Visible = false
    local spectateCorner = Instance.new("UICorner")
    spectateCorner.CornerRadius = UDim.new(0, 10)
    spectateCorner.Parent = spectateUI
    spectateUI.Parent = gui
    
    -- Spectate info
    local spectateInfo = Instance.new("TextLabel")
    spectateInfo.Size = UDim2.new(1, 0, 0, 40)
    spectateInfo.Position = UDim2.new(0, 10, 0, 5)
    spectateInfo.BackgroundTransparency = 1
    spectateInfo.TextColor3 = Color3.fromRGB(255, 255, 255)
    spectateInfo.TextSize = 18
    spectateInfo.Font = Enum.Font.GothamBold
    spectateInfo.Text = "👁️ Spectating: None"
    spectateInfo.ZIndex = 51
    spectateInfo.Parent = spectateUI
    
    -- Previous button (bigger for mobile)
    spectatePrevBtn = Instance.new("TextButton")
    spectatePrevBtn.Size = UDim2.new(0, 100, 0, 40)
    spectatePrevBtn.Position = UDim2.new(0, 10, 0, 50)
    spectatePrevBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
    spectatePrevBtn.BackgroundTransparency = 0.2
    spectatePrevBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    spectatePrevBtn.TextSize = 16
    spectatePrevBtn.Font = Enum.Font.GothamBold
    spectatePrevBtn.Text = "◀ Previous"
    spectatePrevBtn.ZIndex = 51
    local prevCorner = Instance.new("UICorner")
    prevCorner.CornerRadius = UDim.new(0, 8)
    prevCorner.Parent = spectatePrevBtn
    spectatePrevBtn.Parent = spectateUI
    
    -- Next button (bigger for mobile)
    spectateNextBtn = Instance.new("TextButton")
    spectateNextBtn.Size = UDim2.new(0, 100, 0, 40)
    spectateNextBtn.Position = UDim2.new(0, 125, 0, 50)
    spectateNextBtn.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
    spectateNextBtn.BackgroundTransparency = 0.2
    spectateNextBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    spectateNextBtn.TextSize = 16
    spectateNextBtn.Font = Enum.Font.GothamBold
    spectateNextBtn.Text = "Next ▶"
    spectateNextBtn.ZIndex = 51
    local nextCorner = Instance.new("UICorner")
    nextCorner.CornerRadius = UDim.new(0, 8)
    nextCorner.Parent = spectateNextBtn
    spectateNextBtn.Parent = spectateUI
    
    -- Stop button (bigger for mobile)
    spectateStopBtn = Instance.new("TextButton")
    spectateStopBtn.Size = UDim2.new(0, 100, 0, 40)
    spectateStopBtn.Position = UDim2.new(0, 240, 0, 50)
    spectateStopBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    spectateStopBtn.BackgroundTransparency = 0.2
    spectateStopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    spectateStopBtn.TextSize = 16
    spectateStopBtn.Font = Enum.Font.GothamBold
    spectateStopBtn.Text = "Stop"
    spectateStopBtn.ZIndex = 51
    local stopCorner = Instance.new("UICorner")
    stopCorner.CornerRadius = UDim.new(0, 8)
    stopCorner.Parent = spectateStopBtn
    spectateStopBtn.Parent = spectateUI
    
    -- Button functionality with touch feedback
    spectatePrevBtn.MouseButton1Click:Connect(function()
        spectatePreviousPlayer()
    end)
    
    spectatePrevBtn.MouseEnter:Connect(function()
        spectatePrevBtn.BackgroundColor3 = Color3.fromRGB(120, 120, 255)
    end)
    
    spectatePrevBtn.MouseLeave:Connect(function()
        spectatePrevBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
    end)
    
    spectateNextBtn.MouseButton1Click:Connect(function()
        spectateNextPlayer()
    end)
    
    spectateNextBtn.MouseEnter:Connect(function()
        spectateNextBtn.BackgroundColor3 = Color3.fromRGB(120, 255, 120)
    end)
    
    spectateNextBtn.MouseLeave:Connect(function()
        spectateNextBtn.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
    end)
    
    spectateStopBtn.MouseButton1Click:Connect(function()
        stopSpectate()
    end)
    
    spectateStopBtn.MouseEnter:Connect(function()
        spectateStopBtn.BackgroundColor3 = Color3.fromRGB(255, 120, 120)
    end)
    
    spectateStopBtn.MouseLeave:Connect(function()
        spectateStopBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    end)
    
    notify("👁️ Spectate UI created (Mobile Optimized)", Color3.fromRGB(0, 255, 255))
    
    -- Add swipe gestures for mobile
    local touchStart = nil
    local touchEnd = nil
    
    spectateUI.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            touchStart = input.Position
        end
    end)
    
    spectateUI.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch and touchStart then
            touchEnd = input.Position
            local swipeDistance = (touchEnd - touchStart).Magnitude
            
            if swipeDistance > 50 then -- Minimum swipe distance
                local swipeDirection = (touchEnd - touchStart).Unit
                
                if math.abs(swipeDirection.X) > math.abs(swipeDirection.Y) then
                    -- Horizontal swipe
                    if swipeDirection.X > 0 then
                        -- Swipe right = Next
                        spectateNextPlayer()
                    else
                        -- Swipe left = Previous
                        spectatePreviousPlayer()
                    end
                end
            end
            
            touchStart = nil
            touchEnd = nil
        end
    end)
end

-- Get all alive players
local function getAlivePlayers()
    local alivePlayers = {}
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
            table.insert(alivePlayers, plr)
        end
    end
    return alivePlayers
end

-- Spectate next player
local function spectateNextPlayer()
    local alivePlayers = getAlivePlayers()
    if #alivePlayers == 0 then
        notify("⚠️ No alive players to spectate", Color3.fromRGB(255, 100, 100))
        return
    end
    
    local currentIndex = 1
    if spectatingPlayer then
        for i, plr in ipairs(alivePlayers) do
            if plr == spectatingPlayer then
                currentIndex = i
                break
            end
        end
    end
    
    local nextIndex = currentIndex + 1
    if nextIndex > #alivePlayers then
        nextIndex = 1 -- Loop back to first
    end
    
    local nextPlayer = alivePlayers[nextIndex]
    spectatingPlayer = nextPlayer
    selectedPlayer = nextPlayer
    
    if nextPlayer.Character and nextPlayer.Character:FindFirstChild("Humanoid") then
        camera.CameraSubject = nextPlayer.Character.Humanoid
        notify("👁️ Spectating: " .. nextPlayer.Name, Color3.fromRGB(0, 255, 255))
        updateSpectateUI()
        setupSpectateAutoSwitch()
    end
end

-- Spectate previous player
local function spectatePreviousPlayer()
    local alivePlayers = getAlivePlayers()
    if #alivePlayers == 0 then
        notify("⚠️ No alive players to spectate", Color3.fromRGB(255, 100, 100))
        return
    end
    
    local currentIndex = 1
    if spectatingPlayer then
        for i, plr in ipairs(alivePlayers) do
            if plr == spectatingPlayer then
                currentIndex = i
                break
            end
        end
    end
    
    local prevIndex = currentIndex - 1
    if prevIndex < 1 then
        prevIndex = #alivePlayers -- Loop to last
    end
    
    local prevPlayer = alivePlayers[prevIndex]
    spectatingPlayer = prevPlayer
    selectedPlayer = prevPlayer
    
    if prevPlayer.Character and prevPlayer.Character:FindFirstChild("Humanoid") then
        camera.CameraSubject = prevPlayer.Character.Humanoid
        notify("👁️ Spectating: " .. prevPlayer.Name, Color3.fromRGB(0, 255, 255))
        updateSpectateUI()
        setupSpectateAutoSwitch()
    end
end

-- Update spectate UI
local function updateSpectateUI()
    if not spectateUI then return end
    
    if spectatingPlayer then
        spectateUI.Visible = true
        local infoLabel = spectateUI:FindFirstChild("TextLabel")
        if infoLabel then
            infoLabel.Text = "👁️ Spectating: " .. spectatingPlayer.Name
        end
    else
        spectateUI.Visible = false
    end
end

-- Auto switch spectate when current player dies
local function setupSpectateAutoSwitch()
    if spectatingPlayer and spectatingPlayer.Character then
        local humanoid = spectatingPlayer.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.Died:Connect(function()
                task.wait(1) -- Wait a bit
                if spectatingPlayer then -- Still spectating the same player
                    notify("💀 " .. spectatingPlayer.Name .. " died, switching to next player", Color3.fromRGB(255, 100, 100))
                    spectateNextPlayer()
                end
            end)
        end
    end
end

local function stopSpectate()
    local success, errorMsg = pcall(function()
        if spectatingPlayer then
            if humanoid then
                camera.CameraSubject = humanoid
            else
                camera.CameraSubject = nil
            end
            spectatingPlayer = nil
            notify("👁️ Stopped spectating")
            
            -- Hide spectate UI
            updateSpectateUI()
            
            -- Update player list to reflect spectate status
            if playerListFrame and playerListFrame.Visible then
                updatePlayerList()
            end
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
        if not selectedPlayer then
            notify("⚠️ No player selected", Color3.fromRGB(255, 100, 100))
            return
        end
        
        if not selectedPlayer.Character then
            notify("⚠️ " .. selectedPlayer.Name .. " has no character", Color3.fromRGB(255, 100, 100))
            return
        end
        
        local targetRootPart = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not targetRootPart then
            notify("⚠️ " .. selectedPlayer.Name .. " has no root part", Color3.fromRGB(255, 100, 100))
            return
        end
        
        if not hr then
            notify("⚠️ Your character not loaded", Color3.fromRGB(255, 100, 100))
            return
        end
        
        local targetPos = targetRootPart.Position
        if isValidPosition(targetPos) then
            hr.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
            notify("🚀 Teleported to " .. selectedPlayer.Name)
        else
            notify("⚠️ Invalid position for teleport", Color3.fromRGB(255, 100, 100))
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

-- Auto-detect when character finishes (for macro)
local function detectCharacterFinished()
    -- This can be customized based on the game
    -- For now, we'll use a simple timer-based approach
    if macroRecording and practiceMode then
        task.wait(5) -- Wait 5 seconds after recording starts
        if macroRecording and not humanoid.Health == 0 then
            onCharacterFinished()
        end
    end
end

-- Function to ensure overlay is always on top
local function ensureOverlayOnTop()
    if joystickFrame then
        joystickFrame.ZIndex = 100
        for _, child in pairs(joystickFrame:GetDescendants()) do
            if child:IsA("GuiObject") then
                child.ZIndex = 101
            end
        end
    end
    if cameraControlFrame then
        cameraControlFrame.ZIndex = 100
        for _, child in pairs(cameraControlFrame:GetDescendants()) do
            if child:IsA("GuiObject") then
                child.ZIndex = 101
            end
        end
    end
end

-- Admin detection functions
local function loadAdminList()
    -- Common admin usernames and patterns
    adminList = {
        -- Roblox staff
        "ROBLOX",
        "ROBLOX_ADMIN",
        "ROBLOX_MODERATOR",
        "ROBLOX_DEVELOPER",
        "ROBLOX_BUILDER",
        "ROBLOX_ENGINEER",
        "ROBLOX_DESIGNER",
        "ROBLOX_ARTIST",
        "ROBLOX_ANIMATOR",
        "ROBLOX_SCRIPTWRITER",
        "ROBLOX_QA",
        "ROBLOX_TESTER",
        "ROBLOX_SUPPORT",
        "ROBLOX_HELP",
        "ROBLOX_INFO",
        "ROBLOX_NEWS",
        "ROBLOX_BLOG",
        "ROBLOX_DEV",
        "ROBLOX_TEAM",
        "ROBLOX_OFFICIAL",
        
        -- Common admin patterns
        "ADMIN",
        "MODERATOR", 
        "MOD",
        "OWNER",
        "CREATOR",
        "DEVELOPER",
        "DEV",
        "BUILDER",
        "MANAGER",
        "SUPERVISOR",
        "CONTROLLER",
        "OPERATOR",
        "STAFF",
        "TEAM",
        "HELPER",
        "SUPPORT",
        "GUIDE",
        "MENTOR",
        "TUTOR",
        "ASSISTANT",
        
        -- Game-specific admin patterns
        "GAME_ADMIN",
        "GAME_MOD",
        "GAME_OWNER",
        "GAME_DEV",
        "GAME_BUILDER",
        "GAME_MANAGER",
        "GAME_STAFF",
        "GAME_TEAM",
        "GAME_HELPER",
        "GAME_SUPPORT",
        
        -- Security patterns
        "SECURITY",
        "ANTI_EXPLOIT",
        "EXPLOIT_DETECTOR",
        "HACK_DETECTOR",
        "CHEAT_DETECTOR",
        "BAN_HAMMER",
        "MODERATION_BOT",
        "AUTO_MOD",
        "AUTO_BAN",
        "AUTO_KICK",
        
        -- Common admin suffixes
        "_ADMIN",
        "_MOD",
        "_OWNER", 
        "_DEV",
        "_STAFF",
        "_TEAM",
        "_HELPER",
        "_SUPPORT",
        "_MANAGER",
        "_SUPERVISOR"
    }
end

local function isAdminPlayer(playerName)
    if not adminDetectionEnabled then return false end
    
    local playerNameUpper = string.upper(playerName)
    
    -- Check exact matches
    for _, adminName in ipairs(adminList) do
        if playerNameUpper == string.upper(adminName) then
            return true, adminName
        end
    end
    
    -- Check pattern matches
    for _, adminPattern in ipairs(adminList) do
        if string.find(playerNameUpper, string.upper(adminPattern)) then
            return true, adminPattern
        end
    end
    
    -- Check for admin indicators in display name
    local adminIndicators = {"ADMIN", "MOD", "OWNER", "DEV", "STAFF", "TEAM", "HELPER"}
    for _, indicator in ipairs(adminIndicators) do
        if string.find(playerNameUpper, indicator) then
            return true, indicator
        end
    end
    
    return false
end

local function checkForAdmins()
    if not adminDetectionEnabled then return end
    
    local currentAdmins = {}
    local newAdmins = {}
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player then
            local isAdmin, adminType = isAdminPlayer(plr.Name)
            if isAdmin then
                table.insert(currentAdmins, {player = plr, type = adminType})
                
                -- Check if this is a newly detected admin
                local alreadyDetected = false
                for _, detected in ipairs(detectedAdmins) do
                    if detected.player == plr then
                        alreadyDetected = true
                        break
                    end
                end
                
                if not alreadyDetected then
                    table.insert(newAdmins, {player = plr, type = adminType})
                    table.insert(detectedAdmins, {player = plr, type = adminType})
                end
            end
        end
    end
    
    -- Show warning for new admins
    for _, adminData in ipairs(newAdmins) do
        local adminName = adminData.player.Name
        local adminType = adminData.type
        local adminDisplayName = adminData.player.DisplayName
        
        notify("⚠️ ADMIN DETECTED: " .. adminName .. " (" .. adminType .. ")", Color3.fromRGB(255, 0, 0))
        notify("🛡️ Display Name: " .. adminDisplayName, Color3.fromRGB(255, 100, 100))
        notify("🚨 Consider disabling exploits!", Color3.fromRGB(255, 200, 0))
        
        -- Show admin warning dialog
        showAdminWarning(adminData)
    end
    
    -- Update detected admins list (remove disconnected players)
    detectedAdmins = currentAdmins
end

local function showAdminWarning(adminData)
    if adminWarningShown then return end
    
    local adminName = adminData.player.Name
    local adminType = adminData.type
    local adminDisplayName = adminData.player.DisplayName
    
    -- Create admin warning dialog
    local warningDialog = Instance.new("Frame")
    warningDialog.Size = UDim2.new(0, 400, 0, 250)
    warningDialog.Position = UDim2.new(0.5, -200, 0.5, -125)
    warningDialog.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    warningDialog.BackgroundTransparency = 0.1
    warningDialog.BorderSizePixel = 0
    warningDialog.ZIndex = 100
    local warningCorner = Instance.new("UICorner")
    warningCorner.CornerRadius = UDim.new(0, 10)
    warningCorner.Parent = warningDialog
    warningDialog.Parent = gui
    
    local warningTitle = Instance.new("TextLabel")
    warningTitle.Size = UDim2.new(1, 0, 0, 50)
    warningTitle.BackgroundTransparency = 1
    warningTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    warningTitle.TextSize = 20
    warningTitle.Font = Enum.Font.GothamBold
    warningTitle.Text = "🚨 ADMIN DETECTED!"
    warningTitle.ZIndex = 101
    warningTitle.Parent = warningDialog
    
    local adminInfo = Instance.new("TextLabel")
    adminInfo.Size = UDim2.new(1, -20, 0, 60)
    adminInfo.Position = UDim2.new(0, 10, 0, 60)
    adminInfo.BackgroundTransparency = 1
    adminInfo.TextColor3 = Color3.fromRGB(255, 255, 255)
    adminInfo.TextSize = 16
    adminInfo.Font = Enum.Font.Gotham
    adminInfo.Text = "Name: " .. adminName .. "\nDisplay: " .. adminDisplayName .. "\nType: " .. adminType
    adminInfo.TextXAlignment = Enum.TextXAlignment.Left
    adminInfo.ZIndex = 101
    adminInfo.Parent = warningDialog
    
    local warningText = Instance.new("TextLabel")
    warningText.Size = UDim2.new(1, -20, 0, 60)
    warningText.Position = UDim2.new(0, 10, 0, 130)
    warningText.BackgroundTransparency = 1
    warningText.TextColor3 = Color3.fromRGB(255, 255, 255)
    warningText.TextSize = 14
    warningText.Font = Enum.Font.Gotham
    warningText.Text = "⚠️ An admin has been detected in this server!\nConsider disabling exploits to avoid detection.\nStay cautious and avoid suspicious activities."
    warningText.TextWrapped = true
    warningText.TextXAlignment = Enum.TextXAlignment.Left
    warningText.ZIndex = 101
    warningText.Parent = warningDialog
    
    local disableBtn = Instance.new("TextButton")
    disableBtn.Size = UDim2.new(0, 120, 0, 35)
    disableBtn.Position = UDim2.new(0, 20, 0, 200)
    disableBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    disableBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    disableBtn.TextSize = 14
    disableBtn.Font = Enum.Font.GothamBold
    disableBtn.Text = "Disable Exploits"
    disableBtn.ZIndex = 101
    local disableCorner = Instance.new("UICorner")
    disableCorner.CornerRadius = UDim.new(0, 5)
    disableCorner.Parent = disableBtn
    disableBtn.MouseButton1Click:Connect(function()
        -- Disable all active exploits
        if flying then toggleFly() end
        if freecam then toggleFreecam() end
        if noclip then toggleNoclip() end
        if speedEnabled then toggleSpeed() end
        if jumpEnabled then toggleJump() end
        if waterWalk then toggleWaterWalk() end
        if godMode then toggleGodMode() end
        if macroRecording then toggleRecordMacro() end
        if macroPlaying then togglePlayMacro() end
        if autoSaveEnabled then toggleAutoSave() end
        if freezeMovingParts then toggleFreezeMovingParts() end
        
        notify("🛡️ All exploits disabled for safety", Color3.fromRGB(0, 255, 0))
        warningDialog:Destroy()
        adminWarningShown = true
    end)
    disableBtn.Parent = warningDialog
    
    local ignoreBtn = Instance.new("TextButton")
    ignoreBtn.Size = UDim2.new(0, 120, 0, 35)
    ignoreBtn.Position = UDim2.new(0, 160, 0, 200)
    ignoreBtn.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
    ignoreBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ignoreBtn.TextSize = 14
    ignoreBtn.Font = Enum.Font.GothamBold
    ignoreBtn.Text = "Ignore"
    ignoreBtn.ZIndex = 101
    local ignoreCorner = Instance.new("UICorner")
    ignoreCorner.CornerRadius = UDim.new(0, 5)
    ignoreCorner.Parent = ignoreBtn
    ignoreBtn.MouseButton1Click:Connect(function()
        warningDialog:Destroy()
        adminWarningShown = true
    end)
    ignoreBtn.Parent = warningDialog
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 120, 0, 35)
    closeBtn.Position = UDim2.new(0, 300, 0, 200)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "Close"
    closeBtn.ZIndex = 101
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 5)
    closeCorner.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function()
        warningDialog:Destroy()
    end)
    closeBtn.Parent = warningDialog
    
    -- Auto close after 30 seconds
    task.spawn(function()
        task.wait(30)
        if warningDialog and warningDialog.Parent then
            warningDialog:Destroy()
        end
    end)
end

local function toggleAdminDetection()
    adminDetectionEnabled = not adminDetectionEnabled
    if adminDetectionEnabled then
        notify("🛡️ Admin Detection Enabled", Color3.fromRGB(0, 255, 0))
        checkForAdmins() -- Check immediately
    else
        notify("🛡️ Admin Detection Disabled", Color3.fromRGB(255, 100, 100))
    end
end

-- Auto-detect game and create appropriate fake stats
local function detectGameAndCreateStats()
    local gameName = game.Name:lower()
    local placeId = game.PlaceId
    
    -- Reset fake stats data
    fakeStatsData = {}
    fakeStatsRotation = {}
    
    -- Common game detections
    if string.find(gameName, "blox fruits") or placeId == 2753915549 or placeId == 4442272183 or placeId == 7449423635 then
        -- Blox Fruits
        fakeStatsData = {
            level = 2550,
            bounty = 999999999,
            fruits = "DRAGON V2",
            race = "GHOUL",
            fighting_style = "ELECTRIC",
            sword = "TRUE TRIAL KATANA",
            gun = "TRUE TRIAL FLINTLOCK",
            accessory = "TRUE TRIAL CAPE",
            title = "GOD OF WAR",
            kills = 999999,
            deaths = 0,
            wins = 999999,
            losses = 0
        }
        fakeStatsRotation = {"level", "bounty", "fruits", "race", "fighting_style", "sword", "gun", "accessory", "title", "kills", "wins"}
        
    elseif string.find(gameName, "king legacy") or placeId == 4520749081 or placeId == 6381829480 or placeId == 5931540094 then
        -- King Legacy
        fakeStatsData = {
            level = 2550,
            bounty = 999999999,
            fruits = "DRAGON V2",
            race = "GHOUL",
            fighting_style = "ELECTRIC",
            sword = "TRUE TRIAL KATANA",
            gun = "TRUE TRIAL FLINTLOCK",
            accessory = "TRUE TRIAL CAPE",
            title = "GOD OF WAR",
            kills = 999999,
            deaths = 0,
            wins = 999999,
            losses = 0
        }
        fakeStatsRotation = {"level", "bounty", "fruits", "race", "fighting_style", "sword", "gun", "accessory", "title", "kills", "wins"}
        
    elseif string.find(gameName, "grand piece online") or placeId == 1730877806 or placeId == 189707 or placeId == 132766327 then
        -- Grand Piece Online
        fakeStatsData = {
            level = 2550,
            bounty = 999999999,
            fruits = "DRAGON V2",
            race = "GHOUL",
            fighting_style = "ELECTRIC",
            sword = "TRUE TRIAL KATANA",
            gun = "TRUE TRIAL FLINTLOCK",
            accessory = "TRUE TRIAL CAPE",
            title = "GOD OF WAR",
            kills = 999999,
            deaths = 0,
            wins = 999999,
            losses = 0
        }
        fakeStatsRotation = {"level", "bounty", "fruits", "race", "fighting_style", "sword", "gun", "accessory", "title", "kills", "wins"}
        
    elseif string.find(gameName, "anime fighting simulator") or placeId == 734159876 then
        -- Anime Fighting Simulator
        fakeStatsData = {
            power = 999999999,
            chakra = 999999999,
            strength = 999999999,
            speed = 999999999,
            defense = 999999999,
            rank = "GOD",
            prestige = 999,
            mastery = 999999,
            skill = "MAX",
            wins = 999999,
            losses = 0
        }
        fakeStatsRotation = {"power", "chakra", "strength", "speed", "defense", "rank", "prestige", "mastery", "skill", "wins"}
        
    elseif string.find(gameName, "tower of hell") or placeId == 1962086868 then
        -- Tower of Hell
        fakeStatsData = {
            stage = 999,
            summit = 999,
            wins = 999999,
            losses = 0,
            time = "00:00:01",
            rank = "GOD",
            title = "SPEEDRUNNER",
            achievement = "PERFECT",
            skill = "MAX"
        }
        fakeStatsRotation = {"stage", "summit", "wins", "time", "rank", "title", "achievement", "skill"}
        
    elseif string.find(gameName, "doomspire brickbattle") or placeId == 186884708 then
        -- Doomspire Brickbattle
        fakeStatsData = {
            wins = 999999,
            losses = 0,
            kills = 999999,
            deaths = 0,
            rank = "GOD",
            title = "CHAMPION",
            skill = "MAX",
            achievement = "UNSTOPPABLE"
        }
        fakeStatsRotation = {"wins", "kills", "rank", "title", "skill", "achievement"}
        
    elseif string.find(gameName, "adopt me") or placeId == 920587237 then
        -- Adopt Me
        fakeStatsData = {
            money = 999999999,
            bucks = 999999999,
            pets = 999999,
            houses = 999999,
            vehicles = 999999,
            rank = "GOD",
            title = "BILLIONAIRE",
            achievement = "RICHEST",
            skill = "MAX"
        }
        fakeStatsRotation = {"money", "bucks", "pets", "houses", "vehicles", "rank", "title", "achievement", "skill"}
        
    elseif string.find(gameName, "brookhaven") or placeId == 3956818381 then
        -- Brookhaven
        fakeStatsData = {
            money = 999999999,
            job = "CEO",
            rank = "GOD",
            title = "BILLIONAIRE",
            achievement = "RICHEST",
            skill = "MAX",
            houses = 999999,
            vehicles = 999999
        }
        fakeStatsRotation = {"money", "job", "rank", "title", "achievement", "skill", "houses", "vehicles"}
        
    elseif string.find(gameName, "murder mystery") or placeId == 142823291 then
        -- Murder Mystery 2
        fakeStatsData = {
            wins = 999999,
            losses = 0,
            kills = 999999,
            deaths = 0,
            rank = "GOD",
            title = "ASSASSIN",
            achievement = "PERFECT",
            skill = "MAX"
        }
        fakeStatsRotation = {"wins", "kills", "rank", "title", "achievement", "skill"}
        
    elseif string.find(gameName, "jailbreak") or placeId == 606849621 then
        -- Jailbreak
        fakeStatsData = {
            money = 999999999,
            rank = "GOD",
            title = "CRIMINAL MASTERMIND",
            achievement = "UNSTOPPABLE",
            skill = "MAX",
            arrests = 0,
            escapes = 999999
        }
        fakeStatsRotation = {"money", "rank", "title", "achievement", "skill", "escapes"}
        
    else
        -- Generic stats for unknown games
        fakeStatsData = {
            level = 999,
            score = 999999999,
            power = 999999999,
            rank = "GOD",
            title = "LEGEND",
            achievement = "PERFECT",
            skill = "MAX",
            wins = 999999,
            kills = 999999,
            money = 999999999,
            coins = 999999999,
            gems = 999999,
            diamonds = 999999,
            experience = 999999999,
            prestige = 999,
            mastery = 999999
        }
        fakeStatsRotation = {"level", "score", "power", "rank", "title", "achievement", "skill", "wins", "kills", "money", "coins", "gems", "diamonds", "experience", "prestige", "mastery"}
    end
    
    currentFakeStat = fakeStatsRotation[1] or "level"
    fakeStatsRotationIndex = 1
    
    notify("🎮 Auto-detected: " .. game.Name, Color3.fromRGB(0, 255, 255))
    notify("📊 Created " .. #fakeStatsRotation .. " fake stats", Color3.fromRGB(0, 255, 255))
end

-- Function to continuously ensure overlay stays on top
local function startOverlayProtection()
    task.spawn(function()
        while gui and gui.Parent do
            if (flying or freecam) and (joystickFrame or cameraControlFrame) then
                ensureOverlayOnTop()
            end
            task.wait(0.1) -- Check every 100ms
        end
    end)
end

-- Function to start admin monitoring
local function startAdminMonitoring()
    task.spawn(function()
        while gui and gui.Parent do
            if adminDetectionEnabled then
                checkForAdmins()
            end
            task.wait(5) -- Check every 5 seconds
        end
    end)
end

-- Create fake stats billboard (visible to all players)
local function createFakeStatsBillboard()
    if fakeStatsBillboard then
        fakeStatsBillboard:Destroy()
    end
    
    if not char or not char:FindFirstChild("Head") then
        notify("⚠️ Character not loaded for fake stats", Color3.fromRGB(255, 100, 100))
        return
    end
    
    -- Create BillboardGui that's visible to all players
    fakeStatsBillboard = Instance.new("BillboardGui")
    fakeStatsBillboard.Name = "FakeStatsBillboard"
    fakeStatsBillboard.Size = UDim2.new(0, 200, 0, 50)
    fakeStatsBillboard.StudsOffset = Vector3.new(0, 3, 0)
    fakeStatsBillboard.Adornee = char.Head
    fakeStatsBillboard.AlwaysOnTop = true
    fakeStatsBillboard.Enabled = false
    fakeStatsBillboard.Parent = char.Head
    
    fakeStatsText = Instance.new("TextLabel")
    fakeStatsText.Size = UDim2.new(1, 0, 1, 0)
    fakeStatsText.BackgroundTransparency = 1
    fakeStatsText.TextColor3 = Color3.fromRGB(255, 255, 0)
    fakeStatsText.TextSize = 16
    fakeStatsText.Font = Enum.Font.GothamBold
    fakeStatsText.Text = ""
    fakeStatsText.TextStrokeTransparency = 0
    fakeStatsText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    fakeStatsText.Parent = fakeStatsBillboard
    
    -- Create a RemoteEvent to sync with other players (optional)
    local remoteEvent = Instance.new("RemoteEvent")
    remoteEvent.Name = "FakeStatsSync"
    remoteEvent.Parent = char.Head
    
    notify("📊 Fake stats billboard created (visible to all)", Color3.fromRGB(0, 255, 255))
end

-- Update fake stats display
local function updateFakeStatsDisplay()
    if not fakeStatsBillboard or not fakeStatsText or not fakeStatsEnabled then return end
    
    if #fakeStatsRotation == 0 then
        fakeStatsText.Text = "No stats available"
        return
    end
    
    local currentStat = fakeStatsRotation[fakeStatsRotationIndex]
    local statValue = fakeStatsData[currentStat]
    
    if statValue then
        fakeStatsText.Text = string.upper(currentStat) .. ": " .. tostring(statValue)
    else
        fakeStatsText.Text = string.upper(currentStat) .. ": N/A"
    end
end

-- Rotate fake stats
local function rotateFakeStats()
    if not fakeStatsEnabled or #fakeStatsRotation == 0 then return end
    
    fakeStatsRotationIndex = fakeStatsRotationIndex + 1
    if fakeStatsRotationIndex > #fakeStatsRotation then
        fakeStatsRotationIndex = 1
    end
    
    currentFakeStat = fakeStatsRotation[fakeStatsRotationIndex]
    updateFakeStatsDisplay()
end

-- Start fake stats rotation
local function startFakeStatsRotation()
    task.spawn(function()
        while fakeStatsEnabled and gui and gui.Parent do
            rotateFakeStats()
            task.wait(fakeStatsRotationSpeed)
        end
    end)
end

-- Toggle fake stats
local function toggleFakeStats()
    fakeStatsEnabled = not fakeStatsEnabled
    
    if fakeStatsEnabled then
        if not fakeStatsBillboard then
            createFakeStatsBillboard()
        end
        
        if fakeStatsBillboard then
            fakeStatsBillboard.Enabled = true
            updateFakeStatsDisplay()
            startFakeStatsRotation()
            notify("📊 Fake Stats Enabled", Color3.fromRGB(0, 255, 0))
        else
            fakeStatsEnabled = false
            notify("⚠️ Failed to create fake stats billboard", Color3.fromRGB(255, 100, 100))
        end
    else
        if fakeStatsBillboard then
            fakeStatsBillboard.Enabled = false
        end
        notify("📊 Fake Stats Disabled", Color3.fromRGB(255, 100, 100))
    end
end

-- Edit fake stats dialog
local function showEditFakeStatsDialog()
    if #fakeStatsRotation == 0 then
        notify("⚠️ No fake stats available. Auto-detect game first!", Color3.fromRGB(255, 100, 100))
        return
    end
    
    -- Create edit dialog
    local editDialog = Instance.new("Frame")
    editDialog.Size = UDim2.new(0, 400, 0, 300)
    editDialog.Position = UDim2.new(0.5, -200, 0.5, -150)
    editDialog.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    editDialog.BorderSizePixel = 0
    editDialog.ZIndex = 100
    local editCorner = Instance.new("UICorner")
    editCorner.CornerRadius = UDim.new(0, 10)
    editCorner.Parent = editDialog
    editDialog.Parent = gui
    
    local editTitle = Instance.new("TextLabel")
    editTitle.Size = UDim2.new(1, 0, 0, 40)
    editTitle.BackgroundTransparency = 1
    editTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    editTitle.TextSize = 18
    editTitle.Font = Enum.Font.GothamBold
    editTitle.Text = "Edit Fake Stats"
    editTitle.ZIndex = 101
    editTitle.Parent = editDialog
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -20, 1, -80)
    scrollFrame.Position = UDim2.new(0, 10, 0, 50)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    scrollFrame.ZIndex = 101
    scrollFrame.ClipsDescendants = true
    scrollFrame.ScrollingEnabled = true
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.Parent = editDialog
    
    local scrollUIL = Instance.new("UIListLayout")
    scrollUIL.FillDirection = Enum.FillDirection.Vertical
    scrollUIL.Padding = UDim.new(0, 5)
    scrollUIL.Parent = scrollFrame
    
    -- Create input fields for each stat
    for _, statName in ipairs(fakeStatsRotation) do
        local statFrame = Instance.new("Frame")
        statFrame.Size = UDim2.new(1, 0, 0, 35)
        statFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        statFrame.BackgroundTransparency = 0.3
        statFrame.BorderSizePixel = 0
        statFrame.ZIndex = 102
        local statCorner = Instance.new("UICorner")
        statCorner.CornerRadius = UDim.new(0, 5)
        statCorner.Parent = statFrame
        statFrame.Parent = scrollFrame
        
        local statLabel = Instance.new("TextLabel")
        statLabel.Size = UDim2.new(0, 100, 1, 0)
        statLabel.Position = UDim2.new(0, 10, 0, 0)
        statLabel.BackgroundTransparency = 1
        statLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        statLabel.TextSize = 14
        statLabel.Font = Enum.Font.Gotham
        statLabel.Text = string.upper(statName) .. ":"
        statLabel.TextXAlignment = Enum.TextXAlignment.Left
        statLabel.ZIndex = 103
        statLabel.Parent = statFrame
        
        local statInput = Instance.new("TextBox")
        statInput.Size = UDim2.new(1, -120, 0, 25)
        statInput.Position = UDim2.new(0, 110, 0, 5)
        statInput.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        statInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        statInput.TextSize = 14
        statInput.Font = Enum.Font.Gotham
        statInput.Text = tostring(fakeStatsData[statName] or "")
        statInput.PlaceholderText = "Enter value..."
        statInput.ZIndex = 103
        local inputCorner = Instance.new("UICorner")
        inputCorner.CornerRadius = UDim.new(0, 3)
        inputCorner.Parent = statInput
        statInput.Parent = statFrame
        
        -- Save value when focus is lost
        statInput.FocusLost:Connect(function()
            local newValue = statInput.Text
            if newValue ~= "" then
                -- Try to convert to number if possible
                local numValue = tonumber(newValue)
                if numValue then
                    fakeStatsData[statName] = numValue
                else
                    fakeStatsData[statName] = newValue
                end
                updateFakeStatsDisplay()
            end
        end)
    end
    
    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(0, 80, 0, 30)
    saveBtn.Position = UDim2.new(0, 20, 1, -40)
    saveBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    saveBtn.TextSize = 14
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.Text = "Save"
    saveBtn.ZIndex = 101
    local saveCorner = Instance.new("UICorner")
    saveCorner.CornerRadius = UDim.new(0, 5)
    saveCorner.Parent = saveBtn
    saveBtn.MouseButton1Click:Connect(function()
        notify("💾 Fake stats saved", Color3.fromRGB(0, 255, 0))
        editDialog:Destroy()
    end)
    saveBtn.Parent = editDialog
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 80, 0, 30)
    closeBtn.Position = UDim2.new(0, 120, 1, -40)
    closeBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "Close"
    closeBtn.ZIndex = 101
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 5)
    closeCorner.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function()
        editDialog:Destroy()
    end)
    closeBtn.Parent = editDialog
end

-- Create mobile joystick
local function createJoystick()
    if joystickFrame then
        joystickFrame:Destroy()
    end
    
    joystickFrame = Instance.new("Frame")
    joystickFrame.Size = UDim2.new(0, 120, 0, 120)
    joystickFrame.Position = UDim2.new(0.1, 0, 0.65, 0)
    joystickFrame.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
    joystickFrame.BackgroundTransparency = 0.3
    joystickFrame.BorderSizePixel = 0
    joystickFrame.ZIndex = 50 -- Increased Z-Index for better interaction
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
    joystickKnob.ZIndex = 51 -- Increased Z-Index for better interaction
    
    -- Add joystick center indicator
    local joystickCenter = Instance.new("Frame")
    joystickCenter.Size = UDim2.new(0, 4, 0, 4)
    joystickCenter.Position = UDim2.new(0.5, -2, 0.5, -2)
    joystickCenter.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    joystickCenter.BackgroundTransparency = 0.5
    joystickCenter.BorderSizePixel = 0
    joystickCenter.ZIndex = 52
    local centerCorner = Instance.new("UICorner")
    centerCorner.CornerRadius = UDim.new(0, 2)
    centerCorner.Parent = joystickCenter
    joystickCenter.Parent = joystickFrame
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
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    joystickTouch = nil
                    joystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
                    moveDirection = Vector3.new(0, 0, 0)
                end
            end)
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
    cameraControlFrame.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
    cameraControlFrame.BackgroundTransparency = 0.3
    cameraControlFrame.BorderSizePixel = 0
    cameraControlFrame.ZIndex = 50 -- Increased Z-Index for better interaction
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
    camLabel.ZIndex = 51 -- Increased Z-Index for better interaction
    camLabel.Parent = cameraControlFrame
    
    -- Add camera control visual indicator
    local camIndicator = Instance.new("Frame")
    camIndicator.Size = UDim2.new(0, 8, 0, 8)
    camIndicator.Position = UDim2.new(0.5, -4, 0.5, -4)
    camIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    camIndicator.BackgroundTransparency = 0.3
    camIndicator.BorderSizePixel = 0
    camIndicator.ZIndex = 52
    local indicatorCorner = Instance.new("UICorner")
    indicatorCorner.CornerRadius = UDim.new(0, 4)
    indicatorCorner.Parent = camIndicator
    camIndicator.Parent = cameraControlFrame

    cameraControlFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            cameraTouch = input
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    cameraTouch = nil
                    cameraDelta = Vector2.new(0, 0)
                end
            end)
        end
    end)

    cameraControlFrame.InputChanged:Connect(function(input)
        if input == cameraTouch then
            cameraDelta = Vector2.new(input.Delta.X, input.Delta.Y) * 1.0 -- Increased sensitivity from 0.5
        end
    end)

    cameraControlFrame.InputEnded:Connect(function(input)
        if input == cameraTouch then
            cameraTouch = nil
            cameraDelta = Vector2.new(0, 0)
        end
    end)
end

-- Enhanced player list UI with live updates
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
            
            -- Live status update
            local function updateStatus()
                local isAlive = plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0
                infoLabel.Text = "ID: " .. plr.UserId .. " | " .. (isAlive and "🟢 Alive" or "🔴 Dead")
                infoLabel.TextColor3 = isAlive and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 100, 100)
            end
            
            -- Update status immediately
            updateStatus()
            
            -- Connect to character changes for live updates
            plr.CharacterAdded:Connect(function()
                task.wait(1) -- Wait for character to load
                updateStatus()
            end)
            
            if plr.Character and plr.Character:FindFirstChild("Humanoid") then
                plr.Character.Humanoid.Died:Connect(function()
                    updateStatus()
                end)
            end
            
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

    -- Make player list draggable
    local dragging, dragInput, dragStart, startPos
    local function updatePlayerListDrag(input)
        local delta = input.Position - dragStart
        playerListFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    
    playerTitle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = playerListFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    playerTitle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function()
        if dragInput and dragging then
            updatePlayerListDrag(dragInput)
        end
    end)
    
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
    
    -- Live update system for player list
    local function startPlayerListLiveUpdate()
        task.spawn(function()
            while playerListFrame and playerListFrame.Parent do
                if playerListFrame.Visible then
                    updatePlayerList()
                    playerTitle.Text = "Player List (" .. (#Players:GetPlayers() - 1) .. " players)"
                end
                task.wait(1) -- Update every second
            end
        end)
    end
    
    startPlayerListLiveUpdate()
    
    -- Update player list when players join/leave
    Players.PlayerAdded:Connect(function()
        if playerListFrame and playerListFrame.Visible then
            task.wait(0.5) -- Wait for player to load
            updatePlayerList()
            playerTitle.Text = "Player List (" .. (#Players:GetPlayers() - 1) .. " players)"
        end
        
        -- Check for admin when new player joins
        if adminDetectionEnabled then
            task.wait(1) -- Wait a bit for player to fully load
            checkForAdmins()
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
        notify(playerListFrame.Visible and "👥 Player List Opened" or "👥 Player List Closed")
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

        -- Define all categories with complete enhanced feature set
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
                createButton("Teleport to Selected Player", teleportToPlayer, function() return false end),
                createButton("Toggle Admin Detection", toggleAdminDetection, function() return adminDetectionEnabled end),
                createButton("Auto-Detect Game Stats", detectGameAndCreateStats, function() return false end),
                createButton("Toggle Fake Stats", toggleFakeStats, function() return fakeStatsEnabled end),
                createButton("Edit Fake Stats", showEditFakeStatsDialog, function() return false end)
            },
            Teleport = {
                createButton("Teleport to Spawn", teleportToSpawn, function() return false end),
                createButton("Save Current Position", function() 
                    -- Create save checkpoint dialog
                    local saveDialog = Instance.new("Frame")
                    saveDialog.Size = UDim2.new(0, 350, 0, 200)
                    saveDialog.Position = UDim2.new(0.5, -175, 0.5, -100)
                    saveDialog.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                    saveDialog.BorderSizePixel = 0
                    saveDialog.ZIndex = 35
                    local saveDialogCorner = Instance.new("UICorner")
                    saveDialogCorner.CornerRadius = UDim.new(0, 10)
                    saveDialogCorner.Parent = saveDialog
                    saveDialog.Parent = gui
                    
                    local saveTitle = Instance.new("TextLabel")
                    saveTitle.Size = UDim2.new(1, 0, 0, 40)
                    saveTitle.BackgroundTransparency = 1
                    saveTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
                    saveTitle.TextSize = 16
                    saveTitle.Font = Enum.Font.GothamBold
                    saveTitle.Text = "Save Checkpoint"
                    saveTitle.ZIndex = 36
                    saveTitle.Parent = saveDialog
                    
                    local nameLabel = Instance.new("TextLabel")
                    nameLabel.Size = UDim2.new(0, 80, 0, 25)
                    nameLabel.Position = UDim2.new(0, 10, 0, 50)
                    nameLabel.BackgroundTransparency = 1
                    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    nameLabel.TextSize = 14
                    nameLabel.Font = Enum.Font.Gotham
                    nameLabel.Text = "Name:"
                    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                    nameLabel.ZIndex = 36
                    nameLabel.Parent = saveDialog
                    
                    local nameBox = Instance.new("TextBox")
                    nameBox.Size = UDim2.new(1, -100, 0, 25)
                    nameBox.Position = UDim2.new(0, 100, 0, 50)
                    nameBox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    nameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                    nameBox.TextSize = 14
                    nameBox.Font = Enum.Font.Gotham
                    nameBox.PlaceholderText = "Enter checkpoint name..."
                    nameBox.ZIndex = 36
                    local nameBoxCorner = Instance.new("UICorner")
                    nameBoxCorner.CornerRadius = UDim.new(0, 5)
                    nameBoxCorner.Parent = nameBox
                    nameBox.Parent = saveDialog
                    
                    local categoryLabel = Instance.new("TextLabel")
                    categoryLabel.Size = UDim2.new(0, 80, 0, 25)
                    categoryLabel.Position = UDim2.new(0, 10, 0, 85)
                    categoryLabel.BackgroundTransparency = 1
                    categoryLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    categoryLabel.TextSize = 14
                    categoryLabel.Font = Enum.Font.Gotham
                    categoryLabel.Text = "Category:"
                    categoryLabel.TextXAlignment = Enum.TextXAlignment.Left
                    categoryLabel.ZIndex = 36
                    categoryLabel.Parent = saveDialog
                    
                    local categoryDropdown = Instance.new("TextButton")
                    categoryDropdown.Size = UDim2.new(1, -100, 0, 25)
                    categoryDropdown.Position = UDim2.new(0, 100, 0, 85)
                    categoryDropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    categoryDropdown.BackgroundTransparency = 0.3
                    categoryDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
                    categoryDropdown.TextSize = 14
                    categoryDropdown.Font = Enum.Font.Gotham
                    categoryDropdown.Text = currentCategory
                    categoryDropdown.ZIndex = 36
                    local categoryDropdownCorner = Instance.new("UICorner")
                    categoryDropdownCorner.CornerRadius = UDim.new(0, 5)
                    categoryDropdownCorner.Parent = categoryDropdown
                    categoryDropdown.Parent = saveDialog
                    
                    local selectedCategory = currentCategory
                    local dropdownOpen = false
                    local dropdownFrame = nil
                    
                    categoryDropdown.MouseButton1Click:Connect(function()
                        if dropdownOpen then
                            if dropdownFrame then
                                dropdownFrame:Destroy()
                                dropdownFrame = nil
                            end
                            dropdownOpen = false
                        else
                            if dropdownFrame then
                                dropdownFrame:Destroy()
                            end
                            
                            dropdownFrame = Instance.new("Frame")
                            dropdownFrame.Size = UDim2.new(1, -100, 0, 25 * #categories)
                            dropdownFrame.Position = UDim2.new(0, 100, 0, 110)
                            dropdownFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                            dropdownFrame.BorderSizePixel = 0
                            dropdownFrame.ZIndex = 38
                            local dropdownFrameCorner = Instance.new("UICorner")
                            dropdownFrameCorner.CornerRadius = UDim.new(0, 5)
                            dropdownFrameCorner.Parent = dropdownFrame
                            dropdownFrame.Parent = saveDialog
                            
                            local dropdownUIL = Instance.new("UIListLayout")
                            dropdownUIL.FillDirection = Enum.FillDirection.Vertical
                            dropdownUIL.Parent = dropdownFrame
                            
                            for _, category in ipairs(categories) do
                                local categoryBtn = Instance.new("TextButton")
                                categoryBtn.Size = UDim2.new(1, 0, 0, 25)
                                categoryBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                                categoryBtn.BackgroundTransparency = 0.3
                                categoryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                                categoryBtn.TextSize = 14
                                categoryBtn.Font = Enum.Font.Gotham
                                categoryBtn.Text = category
                                categoryBtn.ZIndex = 39
                                categoryBtn.MouseButton1Click:Connect(function()
                                    selectedCategory = category
                                    categoryDropdown.Text = category
                                    dropdownFrame:Destroy()
                                    dropdownFrame = nil
                                    dropdownOpen = false
                                end)
                                categoryBtn.Parent = dropdownFrame
                            end
                            
                            dropdownOpen = true
                        end
                    end)
                    
                    local saveBtn = Instance.new("TextButton")
                    saveBtn.Size = UDim2.new(0, 80, 0, 30)
                    saveBtn.Position = UDim2.new(0, 50, 0, 150)
                    saveBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
                    saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    saveBtn.TextSize = 14
                    saveBtn.Font = Enum.Font.Gotham
                    saveBtn.Text = "Save"
                    saveBtn.ZIndex = 36
                    local saveBtnCorner = Instance.new("UICorner")
                    saveBtnCorner.CornerRadius = UDim.new(0, 5)
                    saveBtnCorner.Parent = saveBtn
                    saveBtn.MouseButton1Click:Connect(function()
                        local checkpointName = nameBox.Text ~= "" and nameBox.Text or ("Checkpoint " .. (positionCounter + 1))
                        saveCheckpoint(checkpointName, selectedCategory)
                        saveDialog:Destroy()
                    end)
                    saveBtn.Parent = saveDialog
                    
                    local cancelBtn = Instance.new("TextButton")
                    cancelBtn.Size = UDim2.new(0, 80, 0, 30)
                    cancelBtn.Position = UDim2.new(0, 220, 0, 150)
                    cancelBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
                    cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    cancelBtn.TextSize = 14
                    cancelBtn.Font = Enum.Font.Gotham
                    cancelBtn.Text = "Cancel"
                    cancelBtn.ZIndex = 36
                    local cancelBtnCorner = Instance.new("UICorner")
                    cancelBtnCorner.CornerRadius = UDim.new(0, 5)
                    cancelBtnCorner.Parent = cancelBtn
                    cancelBtn.MouseButton1Click:Connect(function()
                        saveDialog:Destroy()
                    end)
                    cancelBtn.Parent = saveDialog
                    
                    -- Focus on name box
                    nameBox:CaptureFocus()
                end, function() return false end),
                createButton("Toggle Auto Save", toggleAutoSave, function() return autoSaveEnabled end),
                createButton("Open Position List", showPositionList, function() return false end)
            },
            Macro = {
                createButton("Toggle Record Macro", toggleRecordMacro, function() return macroRecording end),
                createButton("Toggle Play Macro", togglePlayMacro, function() return macroPlaying end)
            }
        }

        -- Add all buttons to scrollFrame
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

        -- Create sidebar category buttons
        for categoryName, _ in pairs(categories) do
            local categoryButton = Instance.new("TextButton")
            categoryButton.Size = UDim2.new(1, -20, 0, 45)
            categoryButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            categoryButton.BackgroundTransparency = 0.2
            categoryButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            categoryButton.TextSize = 16
            categoryButton.Font = Enum.Font.GothamBold
            categoryButton.Text = categoryName
            categoryButton.ZIndex = 12
            categoryButton.Name = categoryName
            local categoryCorner = Instance.new("UICorner")
            categoryCorner.CornerRadius = UDim.new(0, 8)
            categoryCorner.Parent = categoryButton
            
            categoryButton.MouseEnter:Connect(function()
                if currentCategory ~= categoryName then
                    categoryButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
                end
            end)
            categoryButton.MouseLeave:Connect(function()
                categoryButton.BackgroundColor3 = currentCategory == categoryName and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(50, 50, 50)
            end)
            categoryButton.MouseButton1Click:Connect(function()
                updateCategory(categoryName)
            end)
            categoryButton.Parent = sidebar
        end

        -- Initialize with Movement category
        updateCategory("Movement")

        logo.MouseButton1Click:Connect(function()
            frame.Visible = not frame.Visible
            notify(frame.Visible and "🖼️ Enhanced GUI Opened" or "🖼️ Enhanced GUI Closed")
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
        statusLabel.Text = "✅ Enhanced Krnl Mobile v2.0 | Checkpoints: " .. #savedPositions .. " | Attempts: " .. totalAttempts .. (adminDetectionEnabled and " | Admin Detection ON" or "") .. (fakeStatsEnabled and " | Fake Stats ON" or "")
        statusLabel.TextXAlignment = Enum.TextXAlignment.Left
        statusLabel.ZIndex = 12
        statusLabel.Parent = statusFrame
        
        -- Update status periodically
        task.spawn(function()
            while gui and gui.Parent do
                if statusLabel then
                    local macroStatus = ""
                    if macroRecording then
                        macroStatus = "🔴 Recording (" .. #macroActions .. " actions)"
                    elseif macroPlaying then
                        macroStatus = "▶️ Playing (" .. #macroPerfectActions .. " actions)"
                    elseif #macroPerfectActions > 0 then
                        macroStatus = "🎯 Perfect Run Ready"
                    end
                    
                    statusLabel.Text = "✅ Enhanced Krnl Mobile v2.0 | Checkpoints: " .. #savedPositions .. 
                                     " | Attempts: " .. totalAttempts .. 
                                     (macroStatus ~= "" and " | " .. macroStatus or "") ..
                                     (autoSaveEnabled and " | Auto Save ON" or "") ..
                                     (adminDetectionEnabled and " | Admin Detection ON" or "") ..
                                     (fakeStatsEnabled and " | Fake Stats ON" or "")
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
        loadSavedData()
        task.wait(1.5)
        createEnhancedGUI()
        createJoystick()
        createCameraControl()
        createPlayerListUI()
        createPositionListUI()
        createSpectateUI()
        startOverlayProtection()
        loadAdminList()
        startAdminMonitoring()
        detectGameAndCreateStats()
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