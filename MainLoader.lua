-- KILL ALL PREVIOUS SCRIPTS FIRST
local function killPreviousScripts()
    debugPrint("Killing previous scripts...")
    
    -- Kill all running connections in shared environment
    if getgenv and getgenv().krnl_connections then
        for _, connection in pairs(getgenv().krnl_connections) do
            if connection and connection.Disconnect then
                connection:Disconnect()
            end
        end
        getgenv().krnl_connections = {}
    end
    
    -- Kill all UI instances with similar names
    for _, gui in pairs(player:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, obj in pairs(gui:GetDescendants()) do
                if obj:IsA("TextLabel") and (obj.Text:find("Krnl") or obj.Text:find("Enhanced")) then
                    gui:Destroy()
                    debugPrint("Destroyed previous GUI: " .. gui.Name)
                    break
                end
            end
        end
    end
    
    if player.PlayerGui then
        for _, gui in pairs(player.PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") then
                for _, obj in pairs(gui:GetDescendants()) do
                    if obj:IsA("TextLabel") and (obj.Text:find("Krnl") or obj.Text:find("Enhanced")) then
                        gui:Destroy()
                        debugPrint("Destroyed previous PlayerGui: " .. gui.Name)
                        break
                    end
                end
            end
        end
    end
    
    -- Kill any script that might be creating adornments
    pcall(function()
        for _, connection in pairs(getconnections(workspace.DescendantAdded)) do
            if connection and connection.Function then
                local info = debug.getinfo(connection.Function)
                if info and info.source and (info.source:find("krnl") or info.source:find("exploit")) then
                    connection:Disable()
                    debugPrint("Disabled conflicting DescendantAdded connection")
                end
            end
        end
    end)
    
    -- Clear any global variables that might conflict
    if getgenv then
        getgenv().krnl_ui = nil
        getgenv().krnl_char = nil
        getgenv().krnl_running = nil
    end
    
    -- Wait a moment for cleanup
    task.wait(1)
    debugPrint("Previous scripts killed")
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid, hr, char
local savedPositions = {} -- {slot = {name = "string", cframe = CFrame}}
local maxSlots = 10
local macroRecording, macroPlaying = false, false
local macroActions = {}
local macroSuccessfulEndTime = nil
local ui
local connections = {}

-- Store connections globally to kill them later
if getgenv then
    getgenv().krnl_connections = connections
    getgenv().krnl_running = true
end

-- Debug print
local function debugPrint(message)
    print("[KrnlDebug] " .. message)
end

-- File I/O for persistent storage
local function saveTeleportSlots()
    local success, errorMsg = pcall(function()
        local data = {}
        for slot, info in pairs(savedPositions) do
            data[tostring(slot)] = {name = info.name, cframe = {info.cframe:GetComponents()}}
        end
        writefile("krnl/teleport_slots.json", HttpService:JSONEncode(data))
        debugPrint("Teleport slots saved")
    end)
    if not success then
        notify("⚠️ Gagal menyimpan slot teleport: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function loadTeleportSlots()
    local success, result = pcall(function()
        if isfile("krnl/teleport_slots.json") then
            local data = HttpService:JSONDecode(readfile("krnl/teleport_slots.json"))
            savedPositions = {}
            for slot, info in pairs(data) do
                slot = tonumber(slot)
                if slot and info.name and info.cframe and #info.cframe == 12 then
                    savedPositions[slot] = {
                        name = info.name,
                        cframe = CFrame.new(table.unpack(info.cframe))
                    }
                end
            end
            debugPrint("Teleport slots loaded")
        end
    end)
    if not success then
        notify("⚠️ Gagal memuat slot teleport: " .. tostring(result), Color3.fromRGB(255, 100, 100))
    end
end

-- Notify function
local function notify(message, color)
    local success, errorMsg = pcall(function()
        local notif = Instance.new("TextLabel")
        notif.Size = UDim2.new(0, 400, 0, 60)
        notif.Position = UDim2.new(0.5, -200, 0.1, 0)
        notif.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        notif.BackgroundTransparency = 0.5
        notif.TextColor3 = color or Color3.fromRGB(0, 255, 0)
        notif.TextScaled = true
        notif.Font = Enum.Font.Gotham
        notif.Text = message
        notif.BorderSizePixel = 0
        notif.ZIndex = 20
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = notif
        notif.Parent = player:WaitForChild("PlayerGui", 10)
        task.spawn(function()
            task.wait(3)
            notif:Destroy()
        end)
    end)
    if not success then
        debugPrint("Notify error: " .. tostring(errorMsg))
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
    debugPrint("Connections cleared")
end

-- Enhanced adornment cleaning function with script detection
local function cleanAdornments()
    local success, errorMsg = pcall(function()
        -- List of adornment types to remove
        local adornmentTypes = {
            "SelectionBox", "BoxHandleAdornment", "SurfaceGui", "GuiObject",
            "Highlight", "SelectionLasso", "SelectionPointLight", 
            "SelectionSphere", "Handles", "ArcHandles", "SurfaceSelection"
        }
        
        -- Clean character thoroughly
        if char then
            for _, obj in pairs(char:GetDescendants()) do
                for _, adornmentType in pairs(adornmentTypes) do
                    if obj:IsA(adornmentType) then
                        debugPrint("Removed character adornment: " .. obj.ClassName .. " (" .. obj.Name .. ")")
                        obj:Destroy()
                    end
                end
                
                -- Remove any BillboardGui or SurfaceGui that might create boxes
                if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                    obj:Destroy()
                end
                
                -- Remove any Part with specific names that might be selection boxes
                if obj:IsA("Part") and (obj.Name:lower():find("selection") or obj.Name:lower():find("box") or obj.Name:lower():find("highlight")) then
                    obj:Destroy()
                end
            end
        end
        
        -- Clean workspace more thoroughly
        for _, obj in pairs(workspace:GetDescendants()) do
            for _, adornmentType in pairs(adornmentTypes) do
                if obj:IsA(adornmentType) and (obj.Adornee == char or (char and obj.Parent == char)) then
                    debugPrint("Removed workspace adornment: " .. obj.ClassName .. " (" .. obj.Name .. ")")
                    obj:Destroy()
                end
            end
        end
        
        -- Clean all GUI services
        local guiServices = {
            game:GetService("CoreGui"),
            game:GetService("StarterGui"),
            player:FindFirstChild("PlayerGui")
        }
        
        for _, service in pairs(guiServices) do
            if service then
                for _, obj in pairs(service:GetDescendants()) do
                    for _, adornmentType in pairs(adornmentTypes) do
                        if obj:IsA(adornmentType) and (obj.Adornee == char or (char and obj.Parent == char)) then
                            debugPrint("Removed GUI service adornment: " .. obj.ClassName .. " (" .. obj.Name .. ")")
                            obj:Destroy()
                        end
                    end
                end
            end
        end
        
        -- Force remove any remaining selection boxes globally
        for _, obj in pairs(game:GetDescendants()) do
            if obj:IsA("SelectionBox") or obj:IsA("BoxHandleAdornment") then
                if obj.Adornee == char or (char and obj.Parent == char) then
                    obj:Destroy()
                end
            end
        end
        
        -- Kill any scripts that might be adding adornments
        pcall(function()
            for _, connection in pairs(getconnections(workspace.DescendantAdded)) do
                if connection and connection.Function then
                    local success, result = pcall(function()
                        local info = debug.getinfo(connection.Function)
                        return info and info.source
                    end)
                    if success and result and result ~= debug.getinfo(1).source then
                        -- This is not our script, check if it's creating adornments
                        local envCheck = debug.getfenv(connection.Function)
                        if envCheck and (envCheck.script or envCheck._G) then
                            connection:Disable()
                            debugPrint("Disabled potentially conflicting script connection")
                        end
                    end
                end
            end
        end)
    end)
    if not success then
        debugPrint("cleanAdornments error: " .. tostring(errorMsg))
    end
end

-- Ensure character visibility and remove any transparency effects
local function ensureCharacterVisible()
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0
                part.LocalTransparencyModifier = 0
                -- Remove any highlight effects
                for _, highlight in pairs(part:GetChildren()) do
                    if highlight:IsA("Highlight") or highlight:IsA("SelectionBox") then
                        highlight:Destroy()
                    end
                end
            end
        end
    end
end

-- Disable any selection services that might create boxes
local function disableSelectionServices()
    pcall(function()
        -- Disable Studio selection service if it exists
        local Selection = game:GetService("Selection")
        if Selection then
            Selection:Set({})
        end
    end)
    
    -- Remove any studio-related selection tools
    pcall(function()
        game:GetService("CoreGui").RobloxGui.SelectionHighlight.Enabled = false
    end)
end

-- Initialize character
local function initChar()
    local success, errorMsg = pcall(function()
        local retryCount = 0
        while not player.Character and retryCount < 15 do
            debugPrint("Waiting for character, attempt " .. (retryCount + 1))
            notify("⏳ Menunggu karakter muncul... Attempt " .. (retryCount + 1), Color3.fromRGB(255, 255, 0))
            player.CharacterAdded:Wait()
            task.wait(2)
            retryCount = retryCount + 1
        end
        if not player.Character then
            error("Karakter gagal dimuat setelah 15 kali coba")
        end
        char = player.Character
        humanoid = char:WaitForChild("Humanoid", 10)
        hr = char:WaitForChild("HumanoidRootPart", 10)
        if not humanoid or not hr then
            error("Gagal menemukan Humanoid atau HumanoidRootPart setelah 10 detik")
        end
        
        -- Disable selection services
        disableSelectionServices()
        
        -- Initial cleanup
        cleanAdornments()
        ensureCharacterVisible()
        
        debugPrint("Character initialized")
        
        -- More aggressive cleanup - run every frame
        connections.adornmentCleaner = RunService.Heartbeat:Connect(cleanAdornments)
        connections.renderCleaner = RunService.RenderStepped:Connect(cleanAdornments)
        connections.steppedCleaner = RunService.Stepped:Connect(cleanAdornments)
        
        -- Additional cleanup when character moves
        connections.characterMoved = hr:GetPropertyChangedSignal("CFrame"):Connect(function()
            cleanAdornments()
            ensureCharacterVisible()
        end)
        
        -- Cleanup when humanoid state changes
        connections.humanoidStateChanged = humanoid.StateChanged:Connect(function()
            cleanAdornments()
            ensureCharacterVisible()
        end)
    end)
    if not success then
        debugPrint("initChar error: " .. tostring(errorMsg))
        notify("⚠️ Inisialisasi karakter gagal: " .. tostring(errorMsg) .. ", mencoba ulang...", Color3.fromRGB(255, 100, 100))
        task.wait(5)
        initChar()
    end
end

-- Validate position
local function isValidPosition(pos)
    return pos and not (pos.Y < -1000 or pos.Y > 10000 or math.abs(pos.X) > 10000 or math.abs(pos.Z) > 10000)
end

-- Teleport functions
local function savePosition()
    local success, errorMsg = pcall(function()
        if hr then
            local slot = 1
            while savedPositions[slot] and slot <= maxSlots do
                slot = slot + 1
            end
            if slot > maxSlots then
                notify("⚠️ Maksimum " .. maxSlots .. " slot telah tercapai", Color3.fromRGB(255, 100, 100))
                return
            end
            savedPositions[slot] = {name = "Slot " .. slot, cframe = hr.CFrame}
            saveTeleportSlots()
            notify("💾 Posisi disimpan ke Slot " .. slot)
            updateUI()
            -- Clean after saving
            cleanAdornments()
        else
            notify("⚠️ Karakter belum dimuat", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Gagal menyimpan posisi: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function loadPosition(slot)
    local success, errorMsg = pcall(function()
        if hr and savedPositions[slot] and isValidPosition(savedPositions[slot].cframe.Position) then
            hr.CFrame = savedPositions[slot].cframe
            notify("📍 Berpindah ke " .. savedPositions[slot].name)
            -- Clean after teleporting
            task.wait(0.1)
            cleanAdornments()
            ensureCharacterVisible()
        else
            notify("⚠️ Tidak ada posisi tersimpan di slot " .. slot .. " atau posisi tidak valid", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Gagal memuat posisi: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function renamePosition(slot, newName)
    local success, errorMsg = pcall(function()
        if savedPositions[slot] then
            newName = newName:sub(1, 20) -- Limit name length
            savedPositions[slot].name = newName
            saveTeleportSlots()
            notify("✏️ Slot " .. slot .. " diganti nama menjadi " .. newName)
            updateUI()
        else
            notify("⚠️ Tidak ada posisi tersimpan di slot " .. slot, Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Gagal mengganti nama: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- Macro functions
local function toggleRecordMacro()
    macroRecording = not macroRecording
    local success, errorMsg = pcall(function()
        if macroRecording then
            macroActions = {}
            macroSuccessfulEndTime = nil
            local startTime = tick()
            connections.macroRecord = RunService.RenderStepped:Connect(function()
                if hr and humanoid then
                    local action = {
                        time = tick() - startTime,
                        position = hr.CFrame,
                        velocity = hr.Velocity,
                        state = humanoid:GetState(),
                        health = humanoid.Health
                    }
                    table.insert(macroActions, action)
                end
            end)
            notify("🎥 Mulai merekam macro")
        else
            if connections.macroRecord then
                connections.macroRecord:Disconnect()
                connections.macroRecord = nil
            end
            notify("🎥 Perekaman macro dihentikan (" .. #macroActions .. " aksi direkam)")
        end
    end)
    if not success then
        macroRecording = false
        if connections.macroRecord then
            connections.macroRecord:Disconnect()
            connections.macroRecord = nil
        end
        notify("⚠️ Gagal merekam macro: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function markSuccessfulRun()
    local success, errorMsg = pcall(function()
        if macroRecording then
            macroSuccessfulEndTime = tick() - (macroActions[1] and macroActions[1].time or tick())
            notify("✅ Menandai run sukses pada " .. string.format("%.2f", macroSuccessfulEndTime) .. " detik")
        else
            notify("⚠️ Tidak sedang merekam macro", Color3.fromRGB(255, 100, 100))
        end
    end)
    if not success then
        notify("⚠️ Gagal menandai run sukses: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

local function togglePlayMacro()
    macroPlaying = not macroPlaying
    local success, errorMsg = pcall(function()
        if macroPlaying then
            if #macroActions == 0 then
                macroPlaying = false
                error("Tidak ada aksi macro yang direkam")
            end
            if not hr or not humanoid then
                macroPlaying = false
                error("Karakter belum dimuat")
            end
            local startTime = tick()
            local index = 1
            connections.macroPlay = RunService.RenderStepped:Connect(function()
                if not hr or not humanoid then
                    macroPlaying = false
                    if connections.macroPlay then
                        connections.macroPlay:Disconnect()
                        connections.macroPlay = nil
                    end
                    notify("⚠️ Pemutaran macro gagal: Karakter hilang", Color3.fromRGB(255, 100, 100))
                    return
                end
                local currentTime = tick() - startTime
                while index <= #macroActions and macroActions[index].time <= currentTime do
                    local action = macroActions[index]
                    if action.health > 0 and action.state ~= Enum.HumanoidStateType.Dead and (not macroSuccessfulEndTime or action.time <= macroSuccessfulEndTime) then
                        hr.CFrame = action.position
                        hr.Velocity = action.velocity
                        humanoid:ChangeState(action.state)
                    end
                    index = index + 1
                end
                if index > #macroActions or (macroSuccessfulEndTime and currentTime >= macroSuccessfulEndTime) then
                    togglePlayMacro()
                    notify("▶️ Pemutaran macro selesai")
                end
            end)
            notify("▶️ Mulai memutar macro")
        else
            if connections.macroPlay then
                connections.macroPlay:Disconnect()
                connections.macroPlay = nil
            end
            notify("▶️ Pemutaran macro dihentikan")
        end
    end)
    if not success then
        macroPlaying = false
        if connections.macroPlay then
            connections.macroPlay:Disconnect()
            connections.macroPlay = nil
        end
        notify("⚠️ Gagal memutar macro: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
    end
end

-- UI Creation
local function createButton(parent, text, onClick, toggleState, slot, isSave)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.95, 0, 0, 70)
    button.Position = UDim2.new(0.025, 0, 0, 0)
    button.BackgroundColor3 = toggleState and toggleState() and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
    button.BackgroundTransparency = 0.3
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextScaled = true
    button.Font = Enum.Font.Gotham
    button.Text = text
    button.ZIndex = 12
    button.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = button
    local holdStart
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            holdStart = tick()
        end
    end)
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if holdStart and tick() - holdStart >= 2 and slot then
                local renameFrame = ui:FindFirstChild("RenameFrame")
                if renameFrame then
                    renameFrame.Visible = true
                    local inputBox = renameFrame:FindFirstChild("Input")
                    inputBox.Text = savedPositions[slot] and savedPositions[slot].name or ""
                    inputBox.FocusLost:Connect(function(enterPressed)
                        if enterPressed and inputBox.Text ~= "" then
                            renamePosition(slot, inputBox.Text)
                            renameFrame.Visible = false
                        end
                    end)
                    local confirm = renameFrame:FindFirstChild("Confirm")
                    confirm.MouseButton1Click:Connect(function()
                        if inputBox.Text ~= "" then
                            renamePosition(slot, inputBox.Text)
                            renameFrame.Visible = false
                        end
                    end)
                end
            else
                local success, err = pcall(onClick)
                if not success then
                    notify("⚠️ Error pada " .. text .. ": " .. tostring(err), Color3.fromRGB(255, 100, 100))
                end
            end
            holdStart = nil
        end
    end)
    button.Parent = parent
    if toggleState then
        connections["button_" .. text] = RunService.RenderStepped:Connect(function()
            button.BackgroundColor3 = toggleState() and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
        end)
    end
end

local function createCategory(parent, title, buttons)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.95, 0, 0, 70 + #buttons * 78)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.ZIndex = 11
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 70)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = title
    titleLabel.ZIndex = 12
    titleLabel.Parent = frame
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(0.95, 0, 0, #buttons * 78)
    buttonFrame.Position = UDim2.new(0.025, 0, 0, 75)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.ZIndex = 12
    buttonFrame.ClipsDescendants = true
    local uil = Instance.new("UIListLayout")
    uil.FillDirection = Enum.FillDirection.Vertical
    uil.Padding = UDim.new(0, 8)
    uil.Parent = buttonFrame
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 5)
    padding.PaddingBottom = UDim.new(0, 5)
    padding.Parent = buttonFrame
    for _, button in ipairs(buttons) do
        button.Parent = buttonFrame
    end
    buttonFrame.Parent = frame
    frame.Parent = parent
end

local function updateUI()
    if not ui then
        debugPrint("UI not found in updateUI")
        return
    end
    local scrollFrame = ui:FindFirstChild("ScrollFrame")
    if not scrollFrame then
        debugPrint("ScrollFrame not found")
        return
    end
    scrollFrame:ClearAllChildren()
    local uil = Instance.new("UIListLayout")
    uil.FillDirection = Enum.FillDirection.Vertical
    uil.Padding = UDim.new(0, 8)
    uil.Parent = scrollFrame
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 5)
    padding.PaddingBottom = UDim.new(0, 20)
    padding.Parent = scrollFrame
    local buttons = {
        Teleport = {
            {text = "Simpan Posisi", onClick = savePosition},
        },
        Macro = {
            {text = "Toggle Rekam Macro", onClick = toggleRecordMacro, toggleState = function() return macroRecording end},
            {text = "Tandai Run Sukses", onClick = markSuccessfulRun},
            {text = "Toggle Putar Macro", onClick = togglePlayMacro, toggleState = function() return macroPlaying end},
        }
    }
    for slot = 1, maxSlots do
        if savedPositions[slot] then
            table.insert(buttons.Teleport, {text = "Simpan " .. savedPositions[slot].name, onClick = savePosition, slot = slot, isSave = true})
            table.insert(buttons.Teleport, {text = "Muat " .. savedPositions[slot].name, onClick = function() loadPosition(slot) end, slot = slot, isSave = false})
        end
    end
    for category, buttonList in pairs(buttons) do
        local buttonInstances = {}
        for _, button in ipairs(buttonList) do
            local btn = Instance.new("TextButton")
            createButton(nil, button.text, button.onClick, button.toggleState, button.slot, button.isSave)
            table.insert(buttonInstances, btn)
        end
        createCategory(scrollFrame, category, buttonInstances)
    end
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, uil.AbsoluteContentSize.Y + 30)
    debugPrint("UI updated, CanvasSize: " .. tostring(scrollFrame.CanvasSize))
end

local function createUI()
    local retryCount = 0
    local maxRetries = 15
    local function tryCreateUI()
        local success, errorMsg = pcall(function()
            ui = Instance.new("ScreenGui")
            ui.ResetOnSpawn = false
            ui.IgnoreGuiInset = true
            ui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            ui.Parent = player:WaitForChild("PlayerGui", 10)
            if not ui.Parent then
                error("Gagal mengakses PlayerGui")
            end
            debugPrint("ScreenGui created")
            local scale = Instance.new("UIScale")
            scale.Scale = math.min(1.3, math.min(camera.ViewportSize.X / 720, camera.ViewportSize.Y / 1280))
            scale.Parent = ui
            local logo = Instance.new("ImageButton")
            logo.Size = UDim2.new(0, 80, 0, 80)
            logo.Position = UDim2.new(0.95, -90, 0.05, 10)
            logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
            logo.BackgroundTransparency = 0.3
            logo.BorderSizePixel = 0
            logo.Image = "rbxassetid://3570695787"
            logo.ZIndex = 20
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = logo
            logo.MouseButton1Click:Connect(function()
                local frame = ui:FindFirstChild("Frame")
                if frame then
                    frame.Visible = not frame.Visible
                    notify(frame.Visible and "🖼️ GUI Dibuka" or "🖼️ GUI Ditutup")
                    debugPrint("GUI toggled, Visible: " .. tostring(frame.Visible))
                else
                    debugPrint("Frame not found in toggle")
                end
            end)
            logo.Parent = ui
            local frame = Instance.new("Frame")
            frame.Name = "Frame"
            frame.Size = UDim2.new(0, 800, 0, 900)
            frame.Position = UDim2.new(1, -810, 0, 60)
            frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            frame.BackgroundTransparency = 0.1
            frame.BorderSizePixel = 0
            frame.ZIndex = 10
            frame.ClipsDescendants = true
            frame.Visible = false
            local dragStart, startPos
            frame.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragStart = input.Position
                    startPos = frame.Position
                end
            end)
            frame.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragStart = nil
                end
            end)
            frame.InputChanged:Connect(function(input)
                if dragStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local delta = input.Position - dragStart
                    frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                end
            end)
            corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 12)
            corner.Parent = frame
            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, 0, 0, 70)
            title.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            title.BackgroundTransparency = 0.5
            title.TextColor3 = Color3.fromRGB(255, 255, 255)
            title.TextScaled = true
            title.Font = Enum.Font.GothamBold
            title.Text = "Krnl Enhanced UI - No Box"
            title.ZIndex = 11
            corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = title
            title.Parent = frame
            local scrollFrame = Instance.new("ScrollingFrame")
            scrollFrame.Name = "ScrollFrame"
            scrollFrame.Size = UDim2.new(1, -10, 1, -80)
            scrollFrame.Position = UDim2.new(0, 5, 0, 75)
            scrollFrame.BackgroundTransparency = 1
            scrollFrame.ScrollBarThickness = 12
            scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
            scrollFrame.ZIndex = 11
            scrollFrame.ClipsDescendants = true
            scrollFrame.Parent = frame
            local renameFrame = Instance.new("Frame")
            renameFrame.Name = "RenameFrame"
            renameFrame.Size = UDim2.new(0.95, 0, 0, 70)
            renameFrame.Position = UDim2.new(0.025, 0, 0, 0)
            renameFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            renameFrame.BackgroundTransparency = 0.2
            renameFrame.ZIndex = 15
            renameFrame.Visible = false
            local inputBox = Instance.new("TextBox")
            inputBox.Name = "Input"
            inputBox.Size = UDim2.new(0.8, -10, 0, 70)
            inputBox.Position = UDim2.new(0, 5, 0, 5)
            inputBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
            inputBox.TextScaled = true
            inputBox.Font = Enum.Font.Gotham
            inputBox.Text = ""
            inputBox.ZIndex = 16
            corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = inputBox
            inputBox.Parent = renameFrame
            local confirm = Instance.new("TextButton")
            confirm.Name = "Confirm"
            confirm.Size = UDim2.new(0.2, -10, 0, 70)
            confirm.Position = UDim2.new(0.8, 5, 0, 5)
            confirm.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
            confirm.TextColor3 = Color3.fromRGB(255, 255, 255)
            confirm.TextScaled = true
            confirm.Font = Enum.Font.Gotham
            confirm.Text = "OK"
            confirm.ZIndex = 16
            corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = confirm
            confirm.Parent = renameFrame
            renameFrame.Parent = frame
            frame.Parent = ui
            updateUI()
            debugPrint("UI created successfully")
        end)
        if not success then
            retryCount = retryCount + 1
            if retryCount < maxRetries then
                debugPrint("UI creation failed, retrying " .. retryCount .. "/" .. maxRetries .. ": " .. tostring(errorMsg))
                notify("⚠️ Gagal membuat UI: " .. tostring(errorMsg) .. ", retry ke-" .. retryCount, Color3.fromRGB(255, 100, 100))
                task.wait(2)
                tryCreateUI()
            else
                debugPrint("UI creation failed after " .. maxRetries .. " retries: " .. tostring(errorMsg))
                notify("⚠️ Gagal membuat UI setelah " .. maxRetries .. " coba: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
            end
        end
    end
    tryCreateUI()
end

-- Initialize
loadTeleportSlots()
initChar()
createUI()

-- Character respawn handler
player.CharacterAdded:Connect(function()
    clearConnections()
    task.wait(2) -- Wait for character to fully load
    initChar()
    updateUI()
    debugPrint("Character respawned, UI updated")
end)

-- Additional periodic cleanup every 5 seconds
task.spawn(function()
    while true do
        task.wait(5)
        if char then
            cleanAdornments()
            ensureCharacterVisible()
            disableSelectionServices()
        end
    end
end)

-- Monitor for new adornments being added and remove them immediately
workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("SelectionBox") or descendant:IsA("BoxHandleAdornment") or descendant:IsA("Highlight") then
        task.wait() -- Wait one frame
        if descendant.Adornee == char or (char and descendant.Parent == char) then
            descendant:Destroy()
            debugPrint("Instantly removed new adornment: " .. descendant.ClassName)
        end
    end
end)

-- Monitor CoreGui for new adornments
game:GetService("CoreGui").DescendantAdded:Connect(function(descendant)
    if descendant:IsA("SelectionBox") or descendant:IsA("BoxHandleAdornment") or descendant:IsA("Highlight") then
        task.wait() -- Wait one frame
        if descendant.Adornee == char or (char and descendant.Parent == char) then
            descendant:Destroy()
            debugPrint("Instantly removed CoreGui adornment: " .. descendant.ClassName)
        end
    end
end)

-- Cleanup on script end
game:BindToClose(function()
    if ui then
        ui:Destroy()
    end
    clearConnections()
    if char then
        cleanAdornments()
    end
    debugPrint("Script cleanup completed")
end)