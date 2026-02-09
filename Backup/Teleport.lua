local module = {}

function module.init(tab, deps)
    -- Extract dependencies
    local Players = deps.Players
    local Workspace = deps.Workspace
    local Lighting = deps.Lighting
    local UserInputService = deps.UserInputService
    local RunService = deps.RunService
    local player = deps.player
    local character = deps.character
    local humanoid = deps.humanoid
    local rootPart = deps.rootPart
    local connections = deps.connections
    local activeStates = deps.activeStates
    local Fluent = deps.Fluent
    local Window = deps.Window

    -- HttpService for JSON
    local HttpService = game:GetService("HttpService")

    -- Module variables
    local positions = {}
    local positionLabels = {}
    local labelsVisible = true
    local autoTeleportActive = false
    local autoTeleportPaused = false
    local autoTeleportMode = "once"
    local autoTeleportDelay = 2
    local currentAutoIndex = 1
    local autoTeleportCoroutine = nil
    local smoothTeleportEnabled = true
    local smoothTeleportSpeed = 100
    local doubleClickTeleportEnabled = false
    local lastClickTime = 0
    local doubleClickThreshold = 0.5
    local undoStack = {}
    local sortMode = "order"
    local newestPosition = nil

    local TELEPORT_FOLDER_PATH = "Supertool/Teleport/"

    -- Helper functions (keep similar to original)

    local function sanitizeFileName(name)
        local sanitized = string.gsub(name, "[<>:\"/\\|?*]", "_")
        sanitized = string.gsub(sanitized, "^%s*(.-)%s*$", "%1")
        if sanitized == "" then
            sanitized = "unnamed_position"
        end
        return sanitized
    end

    local function saveToJSONFile(positionName, cframe, number, created)
        local success, errorMsg = pcall(function()
            local sanitizedName = sanitizeFileName(positionName)
            local fileName = sanitizedName .. ".json"
            local filePath = TELEPORT_FOLDER_PATH .. fileName
            
            local jsonData = {
                name = positionName,
                type = "teleport_position",
                created = created or os.time(),
                modified = os.time(),
                version = "1.0",
                x = cframe.X,
                y = cframe.Y,
                z = cframe.Z,
                orientation = {cframe:ToEulerAnglesXYZ()},
                number = number or 0
            }
            
            local jsonString = HttpService:JSONEncode(jsonData)
            writefile(filePath, jsonString)
            return true
        end)
        
        if not success then
            warn("[SUPERTOOL] Failed to save position to JSON: " .. tostring(errorMsg))
            return false
        end
        return true
    end

    local function loadFromJSONFile(positionName)
        local success, result = pcall(function()
            local sanitizedName = sanitizeFileName(positionName)
            local fileName = sanitizedName .. ".json"
            local filePath = TELEPORT_FOLDER_PATH .. fileName
            
            if isfile(filePath) then
                local jsonString = readfile(filePath)
                local jsonData = HttpService:JSONDecode(jsonString)
                
                local rx, ry, rz = unpack(jsonData.orientation or {0, 0, 0})
                local cframe = CFrame.new(jsonData.x, jsonData.y, jsonData.z) * CFrame.Angles(rx, ry, rz)
                
                return {
                    cframe = cframe,
                    number = jsonData.number or 0,
                    name = jsonData.name or positionName,
                    created = jsonData.created or os.time()
                }
            else
                return nil
            end
        end)
        
        if success then
            return result
        else
            warn("[SUPERTOOL] Failed to load position from JSON: " .. tostring(result))
            return nil
        end
    end

    local function deleteFromJSONFile(positionName)
        local success, errorMsg = pcall(function()
            local sanitizedName = sanitizeFileName(positionName)
            local fileName = sanitizedName .. ".json"
            local filePath = TELEPORT_FOLDER_PATH .. fileName
            
            if isfile(filePath) then
                delfile(filePath)
                return true
            else
                return false
            end
        end)
        
        if success then
            return errorMsg
        else
            warn("[SUPERTOOL] Failed to delete position JSON: " .. tostring(errorMsg))
            return false
        end
    end

    local function renameInJSONFile(oldName, newName)
        local success, errorMsg = pcall(function()
            local oldData = loadFromJSONFile(oldName)
            if not oldData then
                return false
            end
            
            oldData.name = newName
            oldData.modified = os.time()
            
            if saveToJSONFile(newName, oldData.cframe, oldData.number, oldData.created) then
                deleteFromJSONFile(oldName)
                return true
            else
                return false
            end
        end)
        
        if success then
            return errorMsg
        else
            warn("[SUPERTOOL] Failed to rename position: " .. tostring(errorMsg))
            return false
        end
    end

    local function loadAllPositionsFromFolder()
        local success, result = pcall(function()
            if not isfolder(TELEPORT_FOLDER_PATH) then
                makefolder(TELEPORT_FOLDER_PATH)
            end
            
            local loadedPositions = {}
            local files = listfiles(TELEPORT_FOLDER_PATH)
            
            for _, filePath in pairs(files) do
                if string.match(filePath, "%.json$") then
                    local fileName = string.match(filePath, "([^/\\]+)%.json$")
                    if fileName then
                        local positionData = loadFromJSONFile(fileName)
                        if positionData then
                            local originalName = positionData.name or fileName
                            loadedPositions[originalName] = positionData
                        end
                    end
                end
            end
            
            return loadedPositions
        end)
        
        if success then
            return result or {}
        else
            warn("[SUPERTOOL] Failed to load positions from folder: " .. tostring(result))
            return {}
        end
    end

    local function syncPositionsFromJSON()
        local jsonPositions = loadAllPositionsFromFolder()
        positions = {}
        for positionName, data in pairs(jsonPositions) do
            positions[positionName] = {cframe = data.cframe, number = data.number or 0, created = data.created or os.time()}
            createPositionLabel(positionName, data.cframe.Position)
        end
    end

    local function getRootPart()
        character = player.Character or player.CharacterAdded:Wait()
        rootPart = character:WaitForChild("HumanoidRootPart")
        return rootPart
    end

    local function getOrderedPositions()
        local ordered = {}
        for name, data in pairs(positions) do
            table.insert(ordered, {name = name, cframe = data.cframe, number = data.number, created = data.created})
        end
        
        if sortMode == "alpha" then
            table.sort(ordered, function(a, b) return a.name < b.name end)
        elseif sortMode == "time" then
            table.sort(ordered, function(a, b) return a.created < b.created end)
        else
            table.sort(ordered, function(a, b)
                if a.number == 0 and b.number == 0 then return a.name < b.name end
                if a.number == 0 then return false end
                if b.number == 0 then return true end
                if a.number == b.number then return a.name < b.name end
                return a.number < b.number
            end)
        end
        return ordered
    end

    local function safeTeleport(targetCFrame)
        local root = getRootPart()
        if not root then return false end
        if smoothTeleportEnabled then
            local TweenService = game:GetService("TweenService")
            local startPos = root.CFrame.Position
            local targetPos = targetCFrame.Position
            local distance = (targetPos - startPos).Magnitude
            local duration = distance / smoothTeleportSpeed
            local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
            local tween = TweenService:Create(root, tweenInfo, {CFrame = targetCFrame})
            tween:Play()
            tween.Completed:Wait()
        else
            root.CFrame = targetCFrame
        end
        return true
    end

    local function positionExists(name)
        return positions[name] ~= nil
    end

    local function generateUniqueName(base)
        if not positionExists(base) then return base end
        local counter = 1
        local new = base .. "_" .. counter
        while positionExists(new) do
            counter = counter + 1
            new = base .. "_" .. counter
        end
        return new
    end

    local function deletePosition(positionName)
        positions[positionName] = nil
        if positionLabels[positionName] then
            positionLabels[positionName].Parent:Destroy()
            positionLabels[positionName] = nil
        end
        deleteFromJSONFile(positionName)
    end

    local function deleteAllPositions()
        for name in pairs(positions) do
            deletePosition(name)
        end
        positions = {}
        newestPosition = nil
    end

    local function addPrefixToAll(prefix)
        if prefix == "" then return end
        local newPositions = {}
        for oldName, data in pairs(positions) do
            local newName = prefix .. oldName
            newName = generateUniqueName(newName)
            newPositions[newName] = data
            if positionLabels[oldName] then
                local label = positionLabels[oldName]
                positionLabels[newName] = label
                positionLabels[oldName] = nil
                local number = data.number
                local labelText = newName
                if number > 0 then labelText = "[" .. number .. "] " .. newName end
                label.TextLabel.Text = labelText
            end
            renameInJSONFile(oldName, newName)
        end
        positions = newPositions
    end

    local function doAutoTeleport()
        return coroutine.create(function()
            local orderedPositions = getOrderedPositions()
            if #orderedPositions == 0 then
                autoTeleportActive = false
                return
            end
            repeat
                for i = currentAutoIndex, #orderedPositions do
                    if not autoTeleportActive then return end
                    while autoTeleportPaused do wait(0.1) end
                    local pos = orderedPositions[i]
                    safeTeleport(pos.cframe)
                    currentAutoIndex = i + 1
                    if i < #orderedPositions or autoTeleportMode == "repeat" then
                        wait(autoTeleportDelay)
                    end
                end
                if autoTeleportMode == "repeat" and autoTeleportActive then
                    currentAutoIndex = 1
                end
            until autoTeleportMode ~= "repeat" or not autoTeleportActive
            autoTeleportActive = false
            currentAutoIndex = 1
        end)
    end

    local function startAutoTeleport()
        if autoTeleportActive then return end
        if #getOrderedPositions() == 0 then return end
        autoTeleportActive = true
        currentAutoIndex = 1
        autoTeleportCoroutine = doAutoTeleport()
        coroutine.resume(autoTeleportCoroutine)
    end

    local function stopAutoTeleport()
        if not autoTeleportActive then return end
        autoTeleportActive = false
        autoTeleportPaused = false
        currentAutoIndex = 1
        autoTeleportCoroutine = nil
    end

    local function toggleAutoMode()
        autoTeleportMode = autoTeleportMode == "once" and "repeat" or "once"
        return autoTeleportMode
    end

    local function saveCurrentPosition(name)
        local root = getRootPart()
        if not root then return false end
        name = name or "Position_" .. (os.time() % 10000)
        name = generateUniqueName(name)
        local cframe = root.CFrame
        local created = os.time()
        positions[name] = {cframe = cframe, number = 0, created = created}
        saveToJSONFile(name, cframe, 0, created)
        createPositionLabel(name, cframe.Position)
        newestPosition = name
        return true
    end

    local function teleportToSpawn()
        local spawn = Workspace:FindFirstChild("SpawnLocation")
        if spawn then
            safeTeleport(spawn.CFrame + Vector3.new(0, 5, 0))
        end
    end

    local function createPositionLabel(name, posVector)
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Transparency = 1
        part.Position = posVector + Vector3.new(0, 5, 0)
        part.Parent = Workspace

        local billboard = Instance.new("BillboardGui")
        billboard.Adornee = part
        billboard.Size = UDim2.new(0, 200, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 2, 0)
        billboard.AlwaysOnTop = true
        billboard.Enabled = labelsVisible

        local text = Instance.new("TextLabel")
        text.BackgroundTransparency = 1
        text.Size = UDim2.new(1, 0, 1, 0)
        local number = positions[name].number
        local labelText = name
        if number > 0 then labelText = "[" .. number .. "] " .. name end
        text.Text = labelText
        text.TextColor3 = Color3.fromRGB(255, 255, 255)
        text.TextSize = 14
        text.Font = Enum.Font.GothamBold
        text.Parent = billboard

        positionLabels[name] = billboard
    end

    local function toggleLabels()
        labelsVisible = not labelsVisible
        for _, label in pairs(positionLabels) do
            label.Enabled = labelsVisible
        end
    end

    -- Directional teleports
    local function teleportDirectional(direction, distance)
        local root = getRootPart()
        if not root then return end
        local current = root.CFrame
        table.insert(undoStack, current)
        if #undoStack > 50 then table.remove(undoStack, 1) end
        local vector
        if direction == "forward" then vector = current.LookVector end
        if direction == "backward" then vector = -current.LookVector end
        if direction == "right" then vector = current.RightVector end
        if direction == "left" then vector = -current.RightVector end
        if direction == "up" then vector = current.UpVector end
        if direction == "down" then vector = -current.UpVector end
        safeTeleport(current + vector * (distance or 10))
    end

    -- Undo
    local function undoTeleport()
        if #undoStack > 0 then
            local prev = table.remove(undoStack)
            safeTeleport(prev)
        end
    end

    -- Clean old labels
    local function cleanOldLabels()
        for _, child in ipairs(Workspace:GetChildren()) do
            if child:IsA("Part") and child:FindFirstChildWhichIsA("BillboardGui") then
                if child:FindFirstChild("BillboardGui").Name == "PositionLabel" then
                    child:Destroy()
                end
            end
        end
    end

    -- Init setup
    if not isfolder(TELEPORT_FOLDER_PATH) then
        makefolder(TELEPORT_FOLDER_PATH)
    end
    cleanOldLabels()
    syncPositionsFromJSON()

    player.CharacterAdded:Connect(function(char)
        character = char
        humanoid = char:WaitForChild("Humanoid")
        rootPart = char:WaitForChild("HumanoidRootPart")
        if autoTeleportActive then
            autoTeleportPaused = true
            wait(1)
            autoTeleportPaused = false
        end
    end)

    -- Input for double click and undo
    connections["teleport_input"] = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if not doubleClickTeleportEnabled then return end
            local current = tick()
            if current - lastClickTime < doubleClickThreshold then
                local mouse = player:GetMouse()
                local hit = mouse.Hit
                if hit then
                    local root = getRootPart()
                    if root then
                        local currCFrame = root.CFrame
                        table.insert(undoStack, currCFrame)
                        if #undoStack > 50 then table.remove(undoStack, 1) end
                        safeTeleport(hit)
                    end
                end
            end
            lastClickTime = current
        elseif input.KeyCode == Enum.KeyCode.Z and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            undoTeleport()
        end
    end)

    -- Fluent UI setup in tab

    local PositionSection = tab:AddSection("Positions")

    local positionNameInput = tab:AddInput("PositionName", {
        Title = "Position Name",
        Placeholder = "Enter name...",
        Callback = function(value) end
    })

    tab:AddButton({
        Title = "Save Current Position",
        Callback = function()
            saveCurrentPosition(positionNameInput.Value)
            Fluent:Notify({Title = "Saved", Content = "Position saved as " .. positionNameInput.Value or "default"})
            -- Refresh list
            refreshPositionList()
        end
    })

    local PositionsListSection = tab:AddSection("Saved Positions")

    local function refreshPositionList()
        -- Clear previous buttons, but since Fluent doesn't have dynamic remove, perhaps use a paragraph or separate sections, but for simplicity, we can assume reload or use a trick, but since module is loaded once, perhaps add all dynamically.
        -- For now, to simulate, we can add buttons each time, but that's not ideal. Perhaps use a dropdown for positions.
        -- To make it simple, use a dropdown for teleport, rename, delete.

        local positionNames = {}
        for name in pairs(positions) do
            table.insert(positionNames, name)
        end

        local teleportDropdown = tab:AddDropdown("TeleportTo", {
            Title = "Teleport to Position",
            Values = positionNames,
            Callback = function(value)
                if positions[value] then
                    safeTeleport(positions[value].cframe)
                end
            end
        })

        local deleteDropdown = tab:AddDropdown("DeletePosition", {
            Title = "Delete Position",
            Values = positionNames,
            Callback = function(value)
                deletePosition(value)
                Fluent:Notify({Title = "Deleted", Content = "Position " .. value .. " deleted"})
                refreshPositionList()
            end
        })

        -- For rename, need input
        local renameOld = tab:AddDropdown("RenameOld", {
            Title = "Rename Position - Select",
            Values = positionNames,
            Callback = function(value) end
        })

        local renameNew = tab:AddInput("RenameNew", {
            Title = "New Name",
            Callback = function(value) end
        })

        tab:AddButton({
            Title = "Rename Selected",
            Callback = function()
                local old = renameOld.Value
                local newN = renameNew.Value
                if old and newN and positions[old] and not positions[newN] then
                    local data = positions[old]
                    positions[newN] = data
                    positions[old] = nil
                    if positionLabels[old] then
                        local label = positionLabels[old]
                        positionLabels[newN] = label
                        positionLabels[old] = nil
                        local num = data.number
                        local text = newN
                        if num > 0 then text = "[" .. num .. "] " .. newN end
                        label.TextLabel.Text = text
                    end
                    renameInJSONFile(old, newN)
                    refreshPositionList()
                end
            end
        })
    end

    refreshPositionList()

    tab:AddButton({
        Title = "Teleport to Spawn",
        Callback = function()
            teleportToSpawn()
        end
    })

    local CoordSection = tab:AddSection("Coordinates")

    local coordX = tab:AddInput("CoordX", {Title = "X", Numeric = true, Callback = function() end})
    local coordY = tab:AddInput("CoordY", {Title = "Y", Numeric = true, Callback = function() end})
    local coordZ = tab:AddInput("CoordZ", {Title = "Z", Numeric = true, Callback = function() end})

    tab:AddButton({
        Title = "Teleport to Coords",
        Callback = function()
            local x = tonumber(coordX.Value) or 0
            local y = tonumber(coordY.Value) or 0
            local z = tonumber(coordZ.Value) or 0
            safeTeleport(CFrame.new(x, y, z))
        end
    })

    tab:AddButton({
        Title = "Save Coords as Position",
        Callback = function()
            local x = tonumber(coordX.Value) or 0
            local y = tonumber(coordY.Value) or 0
            local z = tonumber(coordZ.Value) or 0
            local cframe = CFrame.new(x, y, z)
            local name = positionNameInput.Value or "Coord_" .. (os.time() % 10000)
            name = generateUniqueName(name)
            local created = os.time()
            positions[name] = {cframe = cframe, number = 0, created = created}
            saveToJSONFile(name, cframe, 0, created)
            createPositionLabel(name, cframe.Position)
            newestPosition = name
            refreshPositionList()
        end
    })

    local AutoSection = tab:AddSection("Auto Teleport")

    tab:AddToggle("AutoMode", {
        Title = "Repeat Mode",
        Default = false,
        Callback = function(value)
            autoTeleportMode = value and "repeat" or "once"
        end
    })

    local delaySlider = tab:AddSlider("AutoDelay", {
        Title = "Delay (s)",
        Min = 0.5,
        Max = 10,
        Default = 2,
        Rounding = 1,
        Callback = function(value)
            autoTeleportDelay = value
        end
    })

    tab:AddButton({
        Title = "Start Auto Teleport",
        Callback = function()
            startAutoTeleport()
        end
    })

    tab:AddButton({
        Title = "Stop Auto Teleport",
        Callback = function()
            stopAutoTeleport()
        end
    })

    local SmoothSection = tab:AddSection("Smooth Teleport")

    tab:AddToggle("SmoothEnabled", {
        Title = "Enable Smooth TP",
        Default = true,
        Callback = function(value)
            smoothTeleportEnabled = value
        end
    })

    tab:AddSlider("SmoothSpeed", {
        Title = "Speed (studs/s)",
        Min = 10,
        Max = 500,
        Default = 100,
        Rounding = 0,
        Callback = function(value)
            smoothTeleportSpeed = value
        end
    })

    local DirectionalSection = tab:AddSection("Directional Teleport")

    tab:AddButton({
        Title = "Forward 10",
        Callback = function()
            teleportDirectional("forward")
        end
    })

    tab:AddButton({
        Title = "Backward 10",
        Callback = function()
            teleportDirectional("backward")
        end
    })

    tab:AddButton({
        Title = "Left 10",
        Callback = function()
            teleportDirectional("left")
        end
    })

    tab:AddButton({
        Title = "Right 10",
        Callback = function()
            teleportDirectional("right")
        end
    })

    tab:AddButton({
        Title = "Up 10",
        Callback = function()
            teleportDirectional("up")
        end
    })

    tab:AddButton({
        Title = "Down 10",
        Callback = function()
            teleportDirectional("down")
        end
    })

    local MiscSection = tab:AddSection("Misc")

    tab:AddToggle("DoubleClickTP", {
        Title = "Double Click TP to Mouse",
        Default = false,
        Callback = function(value)
            doubleClickTeleportEnabled = value
        end
    })

    tab:AddToggle("ShowLabels", {
        Title = "Show Position Labels",
        Default = true,
        Callback = function(value)
            labelsVisible = value
            toggleLabels()
        end
    })

    local sortOptions = {"order", "alpha", "time"}
    tab:AddDropdown("SortMode", {
        Title = "Sort Mode",
        Values = sortOptions,
        Default = 1,
        Callback = function(value)
            sortMode = value
            refreshPositionList()
        end
    })

    tab:AddButton({
        Title = "Delete All Positions",
        Callback = function()
            deleteAllPositions()
            refreshPositionList()
        end
    })

    local prefixInput = tab:AddInput("Prefix", {
        Title = "Add Prefix to All",
        Callback = function() end
    })

    tab:AddButton({
        Title = "Apply Prefix",
        Callback = function()
            addPrefixToAll(prefixInput.Value)
            refreshPositionList()
        end
    })

    -- End of init
end

return module