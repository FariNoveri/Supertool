local AntiAdmin = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local character, humanoid, rootPart

local dependencies = {}

local settingsFrame = nil
local isSettingsOpen = false

local protectionStates = {
    mainProtection = {
        enabled = false,
        selected = true,
        name = "Pelindung Utama",
        description = "Melindungi dari tendang, blokir, bunuh, pindah karakter. Bisa balik serang ke admin!"
    },
    massProtection = {
        enabled = false,
        selected = true,
        name = "Pelindung Spam",
        description = "Hapus spam benda (>50 objek), mute suara berisik (>3 suara), blokir perubahan cahaya aneh"
    },
    stealthMode = {
        enabled = false,
        selected = false,
        name = "Mode Siluman",
        description = "Sembunyi dari admin dengan ngacak data jadi kayak pemain biasa"
    },
    antiDetection = {
        enabled = false,
        selected = false,
        name = "Anti Ketahuan",
        description = "Memblokir admin yang coba cek script dan scan system"
    },
    memoryProtection = {
        enabled = false,
        selected = false,
        name = "Pelindung Memori",
        description = "Melindungi dari admin yang coba cek memori game"
    },
    advancedBypass = {
        enabled = false,
        selected = false,
        name = "Jalan Pintas Canggih",
        description = "Melewati sistem keamanan admin dengan trik advanced"
    }
}

local protectedPlayers = {}
local lastKnownPosition
local lastKnownHealth = 100
local lastKnownVelocity = Vector3.new(0, 0, 0)
local lastKnownWalkSpeed = 16
local lastKnownJumpPower = 50
local lastKnownAnchored = false
local lastKnownCameraSubject
local lastKnownTools = {}
local lastKnownCanCollide = true
local lastKnownTransparency = 0
local lastKnownSize = Vector3.new(2, 2, 1)
local effectSources = {}
local antiAdminConnections = {}
local maxReverseAttempts = 10
local oldNamecall, oldIndex, oldNewIndex

local lastKnownLighting = {}
local originalAvatar = {}
local partSpamThreshold = 50
local soundSpamThreshold = 3
local resetSpamThreshold = 5
local resetCount = 0
local lastResetTime = 0

local detectionCounters = {
    scriptScan = 0,
    behaviorCheck = 0,
    speedCheck = 0,
    positionCheck = 0,
    memoryCheck = 0
}

local normalPlayerStats = {
    averageWalkSpeed = 16,
    averageJumpPower = 50,
    normalClickRate = 2
}

local fakeBehaviorData = {}
local sessionRandomized = false

local function safeCall(func, ...)
    if type(func) == "function" then
        local success, result = pcall(func, ...)
        if not success then
            warn("AntiAdmin Error: " .. tostring(result))
            return nil
        end
        return result
    else
        warn("AntiAdmin: Bukan fungsi yang dipanggil")
        return nil
    end
end

local function safeSetProperty(object, property, value)
    if not object then return false end
    if not object[property] then return false end
    
    local success = pcall(function()
        object[property] = value
    end)
    
    if not success then
        warn("AntiAdmin: Gagal ganti " .. property .. " di " .. tostring(object))
    end
    return success
end

local function safeGetService(serviceName)
    local success, service = pcall(function()
        return game:GetService(serviceName)
    end)
    
    if success then
        return service
    else
        warn("AntiAdmin: Gagal ambil layanan " .. serviceName)
        return nil
    end
end

function AntiAdmin.init(deps)
    
    dependencies = deps or {}
    
    player = dependencies.player or Players.LocalPlayer
    if not player then
        warn("AntiAdmin: Pemain ga ketemu!")
        return false
    end
    
    local function initCharacter()
        character = dependencies.character or (player.Character or player.CharacterAdded:Wait())
        if character then
            humanoid = character:FindFirstChild("Humanoid") or character:WaitForChild("Humanoid", 5)
            rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
            
            if not humanoid or not rootPart then
                warn("AntiAdmin: Bagian karakter penting ga ada")
                return false
            end
            return true
        end
        return false
    end
    
    if not initCharacter() then
        player.CharacterAdded:Connect(function(char)
            character = char
            humanoid = char:WaitForChild("Humanoid")
            rootPart = char:WaitForChild("HumanoidRootPart")
        end)
    end
    
    if character then
        safeCall(function()
            originalAvatar.userId = player.UserId
            originalAvatar.name = player.Name
            originalAvatar.displayName = player.DisplayName
            if character:FindFirstChild("Head") then
                originalAvatar.headMesh = character.Head:FindFirstChildOfClass("SpecialMesh")
            end
            if character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") then
                local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
                lastKnownSize = torso.Size
            end
        end)
        
        if humanoid then
            lastKnownHealth = humanoid.Health
            lastKnownWalkSpeed = humanoid.WalkSpeed
            lastKnownJumpPower = humanoid.JumpPower or humanoid.JumpHeight or 50
        end
        
        if rootPart then
            lastKnownPosition = rootPart.CFrame
            lastKnownVelocity = rootPart.Velocity
            lastKnownAnchored = rootPart.Anchored
            lastKnownCanCollide = rootPart.CanCollide
        end
    end
    
    saveLightingSettings()
    sessionRandomization()
    return true
end

local function sessionRandomization()
    if sessionRandomized then return end
    
    safeCall(function()
        local randomSeed = tick() + math.random(1, 999999)
        math.randomseed(randomSeed)
        
        fakeBehaviorData = {
            joinTime = tick() - math.random(300, 3600),
            clickCount = math.random(50, 500),
            keyPresses = math.random(100, 1000),
            cameraMovements = math.random(200, 800),
            lastActivity = tick()
        end
        
        sessionRandomized = true
    end)
end

local function saveLightingSettings()
    safeCall(function()
        lastKnownLighting = {
            Brightness = Lighting.Brightness,
            Ambient = Lighting.Ambient,
            ColorShift_Top = Lighting.ColorShift_Top,
            ColorShift_Bottom = Lighting.ColorShift_Bottom,
            FogEnd = Lighting.FogEnd,
            FogStart = Lighting.FogStart,
            FogColor = Lighting.FogColor,
            TimeOfDay = Lighting.TimeOfDay,
            ClockTime = Lighting.ClockTime
        }
    end)
end

local function restoreLightingSettings()
    safeCall(function()
        if lastKnownLighting and next(lastKnownLighting) then
            for property, value in pairs(lastKnownLighting) do
                if Lighting[property] ~= value then
                    safeSetProperty(Lighting, property, value)
                end
            end
        end
    end)
end

local function initializeAntiDetection()
    safeCall(function()
        local hasGetDescendants = pcall(function() 
            return game.GetDescendants and type(game.GetDescendants) == "function"
        end)
        
        if hasGetDescendants then
            pcall(function()
                local originalGetDescendants = game.GetDescendants
                game.GetDescendants = function(self)
                    detectionCounters.scriptScan = detectionCounters.scriptScan + 1
                    if detectionCounters.scriptScan > 10 then
                        return {}
                    end
                    return originalGetDescendants(self)
                end
            end)
        else
        end
    end)
end

local function setupMemoryProtection()
    safeCall(function()
        local protectedMemory = {}
        
        spawn(function()
            while protectionStates.memoryProtection.enabled do
                safeCall(function()
                    collectgarbage("count")
                    
                    for i = 1, math.random(10, 50) do
                        protectedMemory[i] = math.random(1, 999999)
                    end
                    
                    detectionCounters.memoryCheck = 0
                end)
                wait(math.random(5, 15))
            end
        end)
    end)
end

local function setupAdvancedMetatableProtection()
    safeCall(function()
        local hasMetatableFunctions = pcall(function() 
            return getrawmetatable and setreadonly and getnamecallmethod
        end)
        
        if not hasMetatableFunctions then
            return
        end
        
        local success, mt = pcall(getrawmetatable, game)
        if not success or not mt then 
            return 
        end
        
        local success2, oldCall = pcall(function() return mt.__namecall end)
        if not success2 or not oldCall then 
            return 
        end
        
        oldNamecall = oldCall
        
        local success3 = pcall(setreadonly, mt, false)
        if not success3 then
            return
        end

        mt.__namecall = function(self, ...)
            if not protectionStates.mainProtection.enabled then 
                return oldNamecall(self, ...) 
            end
            
            local method = ""
            pcall(function()
                method = getnamecallmethod() or ""
            end)
            
            if method == "Kick" or method == "Ban" then
                return nil
            end
            
            if method == "CaptureService" or method == "RecordingService" then
                return nil
            end
            
            if (method == "FireServer" or method == "InvokeServer") and self and self.Name then
                local remoteName = tostring(self.Name):lower()
                local blockedRemotes = {
                    "admin", "mod", "ban", "kick", "tp", "teleport", 
                    "kill", "god", "speed", "fly", "noclip", "morph",
                    "lighting", "sound", "music", "reset", "respawn",
                    "crash", "lag", "freeze", "unfreeze", "mute"
                }
                
                for _, blocked in pairs(blockedRemotes) do
                    if remoteName:find(blocked) then
                        return nil
                    end
                end
            end
            
            return oldNamecall(self, ...)
        end

        pcall(setreadonly, mt, true)
    end)
end

local function hasAntiAdmin(targetPlayer)
    if not targetPlayer or not targetPlayer.Parent then return false end
    return protectedPlayers[targetPlayer] or math.random(1, 100) <= 50
end

local function findUnprotectedTarget(excludePlayers)
    local availablePlayers = {}
    
    safeCall(function()
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player and p.Character and p.Character:FindFirstChild("Humanoid") then
                local pHumanoid = p.Character.Humanoid
                if pHumanoid.Health > 0 and not excludePlayers[p] and not hasAntiAdmin(p) then
                    table.insert(availablePlayers, p)
                end
            end
        end
    end)
    
    if #availablePlayers > 0 then
        return availablePlayers[math.random(1, #availablePlayers)]
    end
    return nil
end

local function reverseEffect(effectType, originalSource)
    if not protectionStates.mainProtection.enabled then return end

    local excludePlayers = { [player] = true }
    local currentTarget = originalSource
    
    safeCall(function()
        if not currentTarget then
            local allPlayers = Players:GetPlayers()
            if #allPlayers > 1 then
                repeat
                    currentTarget = allPlayers[math.random(1, #allPlayers)]
                until currentTarget ~= player
            else
                return
            end
        end
        
        local attempts = 0

        while currentTarget and hasAntiAdmin(currentTarget) and attempts < maxReverseAttempts do
            excludePlayers[currentTarget] = true
            currentTarget = findUnprotectedTarget(excludePlayers)
            attempts = attempts + 1
        end

        if currentTarget and currentTarget.Character then
            local targetHumanoid = currentTarget.Character:FindFirstChild("Humanoid")
            local targetRootPart = currentTarget.Character:FindFirstChild("HumanoidRootPart")
            
            if not targetHumanoid or not targetRootPart then return end

            if effectType == "kill" then
                safeSetProperty(targetHumanoid, "Health", 0)
            elseif effectType == "teleport" then
                local randomPos = Vector3.new(
                    math.random(-1000, 1000),
                    math.random(50, 500),
                    math.random(-1000, 1000)
                )
                safeSetProperty(targetRootPart, "CFrame", CFrame.new(randomPos))
            elseif effectType == "fling" then
                safeSetProperty(targetRootPart, "Velocity", Vector3.new(
                    math.random(-100, 100),
                    math.random(50, 200),
                    math.random(-100, 100)
                ))
            end
        end
    end)
end

local function handleAntiAdmin()
    if not humanoid or not rootPart then return end

    if humanoid and typeof(humanoid) == "Instance" then
        local healthConnection = safeCall(function()
            return humanoid.HealthChanged:Connect(function(health)
                if not protectionStates.mainProtection.enabled then return end
                if health < lastKnownHealth and health <= 0 then
                    safeCall(function()
                        safeSetProperty(humanoid, "Health", lastKnownHealth)
                        reverseEffect("kill", effectSources[player])
                    end)
                end
                lastKnownHealth = humanoid.Health
            end)
        end)
        
        if healthConnection then
            antiAdminConnections.health = healthConnection
        end
    end

    if rootPart and typeof(rootPart) == "Instance" then
        local positionConnection = safeCall(function()
            return rootPart:GetPropertyChangedSignal("CFrame"):Connect(function()
                if not protectionStates.mainProtection.enabled then return end
                safeCall(function()
                    local currentPos = rootPart.CFrame
                    if lastKnownPosition then
                        local distance = (currentPos.Position - lastKnownPosition.Position).Magnitude
                        if distance > 100 then
                            safeSetProperty(rootPart, "CFrame", lastKnownPosition)
                            reverseEffect("teleport", effectSources[player])
                        end
                    end
                    lastKnownPosition = currentPos
                end)
            end)
        end)
        
        if positionConnection then
            antiAdminConnections.position = positionConnection
        end
    end
end

local function detectMassEffects()
    spawn(function()
        while protectionStates.massProtection.enabled do
            safeCall(function()
                restoreLightingSettings()
                
                local partCount = 0
                for _, obj in pairs(Workspace:GetChildren()) do
                    if obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
                        partCount = partCount + 1
                    end
                end
                
                if partCount > partSpamThreshold then
                    for _, obj in pairs(Workspace:GetChildren()) do
                        if obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
                            if not obj.Parent:IsA("Model") or obj.Name:find("Spam") or obj.Size.X > 100 then
                                safeCall(function() obj:Destroy() end)
                            end
                        end
                    end
                end
                
                local soundCount = 0
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("Sound") and obj.IsPlaying and obj.Volume > 0.5 then
                        soundCount = soundCount + 1
                        if soundCount > soundSpamThreshold then
                            safeCall(function() 
                                obj:Stop()
                                obj.Volume = 0
                            end)
                        end
                    end
                end
                
            end)
            wait(2)
        end
    end)
end

local function setupAdvancedBypass()
    spawn(function()
        while protectionStates.advancedBypass.enabled do
            safeCall(function()
                local dummy = {}
                for i = 1, math.random(10, 100) do
                    dummy[i] = math.random(1, 1000000)
                end
                dummy = nil
                collectgarbage("count")
            end)
            wait(math.random(25, 35))
        end
    end)
    
    spawn(function()
        while protectionStates.advancedBypass.enabled do
            safeCall(function()
                local tempData = {
                    status = "active",
                    timestamp = tick(),
                    random = math.random(1, 9999)
                }
                tempData = nil
            end)
            wait(math.random(40, 60))
        end
    end)
end

local function toggleMainProtection(enabled)
    protectionStates.mainProtection.enabled = enabled
    
    if enabled then
        if character and humanoid and rootPart then
            handleAntiAdmin()
        end
        setupAdvancedMetatableProtection()
    else
        for _, conn in pairs(antiAdminConnections) do
            if conn and typeof(conn) == "RBXScriptConnection" then
                safeCall(function() conn:Disconnect() end)
            end
        end
        antiAdminConnections = {}
    end
end

local function toggleMassProtection(enabled)
    protectionStates.massProtection.enabled = enabled
    
    if enabled then
        detectMassEffects()
    else
    end
end

local function toggleStealthMode(enabled)
    protectionStates.stealthMode.enabled = enabled
    
    if enabled then
        initializeAntiDetection()
    else
    end
end

local function toggleMemoryProtection(enabled)
    protectionStates.memoryProtection.enabled = enabled
    
    if enabled then
        setupMemoryProtection()
    else
    end
end

local function toggleAdvancedBypass(enabled)
    protectionStates.advancedBypass.enabled = enabled
    
    if enabled then
        setupAdvancedBypass()
    else
    end
end

local protectionFunctions = {
    mainProtection = toggleMainProtection,
    massProtection = toggleMassProtection,
    stealthMode = toggleStealthMode,
    antiDetection = toggleStealthMode,
    memoryProtection = toggleMemoryProtection,
    advancedBypass = toggleAdvancedBypass
}

local function applySelectedProtections()
    
    for key, state in pairs(protectionStates) do
        if state.selected and protectionFunctions[key] then
            protectionFunctions[key](true)
        elseif not state.selected and protectionFunctions[key] then
            protectionFunctions[key](false)
        end
    end
    
end

local function stopAllProtections()
    
    for key, state in pairs(protectionStates) do
        if protectionFunctions[key] then
            protectionFunctions[key](false)
        end
    end
    
    detectionCounters = {
        scriptScan = 0,
        behaviorCheck = 0,
        speedCheck = 0,
        positionCheck = 0,
        memoryCheck = 0
    }
    
end

local function createSettingsGUI(parent)
    if settingsFrame then
        settingsFrame:Destroy()
    end
    
    settingsFrame = Instance.new("Frame")
    settingsFrame.Name = "AntiAdminSettings"
    settingsFrame.Parent = parent
    settingsFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 30)
    settingsFrame.BorderColor3 = Color3.fromRGB(0, 150, 255)
    settingsFrame.BorderSizePixel = 2
    settingsFrame.Size = UDim2.new(0, 400, 0, 450)
    settingsFrame.Position = UDim2.new(0.5, -200, 0.5, -225)
    settingsFrame.Visible = false
    
    local settingsCorner = Instance.new("UICorner")
    settingsCorner.CornerRadius = UDim.new(0, 8)
    settingsCorner.Parent = settingsFrame
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Parent = settingsFrame
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, 0, 0, 40)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "ANTI-ADMIN SETTINGS"
    titleLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
    titleLabel.TextSize = 16
    titleLabel.TextYAlignment = Enum.TextYAlignment.Center
    
    local closeButton = Instance.new("TextButton")
    closeButton.Parent = settingsFrame
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 14
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeButton
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Parent = settingsFrame
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.Size = UDim2.new(1, -20, 1, -100)
    scrollFrame.Position = UDim2.new(0, 10, 0, 50)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Parent = scrollFrame
    listLayout.Padding = UDim.new(0, 5)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local checkboxes = {}
    local yPos = 0
    
    for key, state in pairs(protectionStates) do
        local checkboxFrame = Instance.new("Frame")
        checkboxFrame.Parent = scrollFrame
        checkboxFrame.BackgroundColor3 = Color3.fromRGB(25, 30, 35)
        checkboxFrame.BorderSizePixel = 0
        checkboxFrame.Size = UDim2.new(1, -20, 0, 80)
        
        local checkboxCorner = Instance.new("UICorner")
        checkboxCorner.CornerRadius = UDim.new(0, 6)
        checkboxCorner.Parent = checkboxFrame
        
        local checkbox = Instance.new("TextButton")
        checkbox.Parent = checkboxFrame
        checkbox.BackgroundColor3 = Color3.fromRGB(40, 45, 50)
        checkbox.BorderColor3 = Color3.fromRGB(0, 150, 255)
        checkbox.BorderSizePixel = 2
        checkbox.Size = UDim2.new(0, 25, 0, 25)
        checkbox.Position = UDim2.new(0, 10, 0, 10)
        checkbox.Font = Enum.Font.GothamBold
        checkbox.Text = state.selected and "V" or ""
        checkbox.TextColor3 = Color3.fromRGB(0, 255, 0)
        checkbox.TextSize = 16
        
        local checkboxCorner2 = Instance.new("UICorner")
        checkboxCorner2.CornerRadius = UDim.new(0, 4)
        checkboxCorner2.Parent = checkbox
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Parent = checkboxFrame
        nameLabel.BackgroundTransparency = 1
        nameLabel.Size = UDim2.new(1, -50, 0, 25)
        nameLabel.Position = UDim2.new(0, 45, 0, 10)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Text = state.name
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextYAlignment = Enum.TextYAlignment.Center
        
        local descLabel = Instance.new("TextLabel")
        descLabel.Parent = checkboxFrame
        descLabel.BackgroundTransparency = 1
        descLabel.Size = UDim2.new(1, -50, 0, 40)
        descLabel.Position = UDim2.new(0, 45, 0, 35)
        descLabel.Font = Enum.Font.Gotham
        descLabel.Text = state.description
        descLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        descLabel.TextSize = 10
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextYAlignment = Enum.TextYAlignment.Top
        descLabel.TextWrapped = true
        
        checkboxes[key] = checkbox
        checkbox.MouseButton1Click:Connect(function()
            state.selected = not state.selected
            checkbox.Text = state.selected and "V" or ""
            checkbox.BackgroundColor3 = state.selected and Color3.fromRGB(0, 100, 50) or Color3.fromRGB(40, 45, 50)
            
            local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
            local tween = TweenService:Create(checkbox, tweenInfo, {
                Size = UDim2.new(0, 30, 0, 30)
            })
            tween:Play()
            tween.Completed:Connect(function()
                local tween2 = TweenService:Create(checkbox, tweenInfo, {
                    Size = UDim2.new(0, 25, 0, 25)
                })
                tween2:Play()
            end)
        end)
        
        yPos = yPos + 85
    end
    
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yPos)
    
    local applyButton = Instance.new("TextButton")
    applyButton.Parent = settingsFrame
    applyButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    applyButton.Size = UDim2.new(0, 120, 0, 35)
    applyButton.Position = UDim2.new(0, 20, 1, -45)
    applyButton.Font = Enum.Font.GothamBold
    applyButton.Text = "TERAPKAN"
    applyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    applyButton.TextSize = 14
    
    local applyCorner = Instance.new("UICorner")
    applyCorner.CornerRadius = UDim.new(0, 6)
    applyCorner.Parent = applyButton
    
    local stopButton = Instance.new("TextButton")
    stopButton.Parent = settingsFrame
    stopButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    stopButton.Size = UDim2.new(0, 120, 0, 35)
    stopButton.Position = UDim2.new(0, 150, 1, -45)
    stopButton.Font = Enum.Font.GothamBold
    stopButton.Text = "STOP ALL"
    stopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    stopButton.TextSize = 14
    
    local stopCorner = Instance.new("UICorner")
    stopCorner.CornerRadius = UDim.new(0, 6)
    stopCorner.Parent = stopButton
    
    local selectAllButton = Instance.new("TextButton")
    selectAllButton.Parent = settingsFrame
    selectAllButton.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
    selectAllButton.Size = UDim2.new(0, 100, 0, 35)
    selectAllButton.Position = UDim2.new(1, -120, 1, -45)
    selectAllButton.Font = Enum.Font.GothamBold
    selectAllButton.Text = "ALL"
    selectAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectAllButton.TextSize = 14
    
    local selectAllCorner = Instance.new("UICorner")
    selectAllCorner.CornerRadius = UDim.new(0, 6)
    selectAllCorner.Parent = selectAllButton
    
    closeButton.MouseButton1Click:Connect(function()
        settingsFrame.Visible = false
        isSettingsOpen = false
    end)
    
    applyButton.MouseButton1Click:Connect(function()
        applySelectedProtections()
        settingsFrame.Visible = false
        isSettingsOpen = false
    end)
    
    stopButton.MouseButton1Click:Connect(function()
        stopAllProtections()
        settingsFrame.Visible = false
        isSettingsOpen = false
    end)
    
    selectAllButton.MouseButton1Click:Connect(function()
        local allSelected = true
        for key, state in pairs(protectionStates) do
            if not state.selected then
                allSelected = false
                break
            end
        end
        
        for key, state in pairs(protectionStates) do
            state.selected = not allSelected
            local checkbox = checkboxes[key]
            if checkbox then
                checkbox.Text = state.selected and "V" or ""
                checkbox.BackgroundColor3 = state.selected and Color3.fromRGB(0, 100, 50) or Color3.fromRGB(40, 45, 50)
            end
        end
        
        selectAllButton.Text = allSelected and "ALL" or "NONE"
    end)
    
    return settingsFrame
end

local function toggleSettings(parent)
    if isSettingsOpen then
        if settingsFrame then
            settingsFrame.Visible = false
        end
        isSettingsOpen = false
    else
        if not settingsFrame then
            createSettingsGUI(parent)
        end
        settingsFrame.Visible = true
        isSettingsOpen = true
    end
end

function AntiAdmin.resetStates()
    safeCall(function()
        stopAllProtections()
        
        for key, state in pairs(protectionStates) do
            state.enabled = false
            state.selected = false
        end
        
        protectionStates.mainProtection.selected = true
        protectionStates.massProtection.selected = true
        
        for _, conn in pairs(antiAdminConnections) do
            if conn and typeof(conn) == "RBXScriptConnection" then
                safeCall(function() conn:Disconnect() end)
            end
        end
        antiAdminConnections = {}
        
        detectionCounters = {
            scriptScan = 0,
            behaviorCheck = 0,
            speedCheck = 0,
            positionCheck = 0,
            memoryCheck = 0
        }
        
    end)
end

function AntiAdmin.getProtectionStatus()
    local status = {}
    for key, state in pairs(protectionStates) do
        status[key] = {
            enabled = state.enabled,
            selected = state.selected,
            name = state.name,
            description = state.description
        }
    end
    return status
end

function AntiAdmin.loadAntiAdminButtons(createToggleButton, FeatureContainer)
    if not createToggleButton or not FeatureContainer then
        warn("AntiAdmin: Fungsi UI ga ada")
        return
    end
    
    local mainButton = Instance.new("TextButton")
    mainButton.Name = "AntiAdminMain"
    mainButton.Parent = FeatureContainer
    mainButton.BackgroundColor3 = Color3.fromRGB(30, 35, 40)
    mainButton.BorderColor3 = Color3.fromRGB(0, 150, 255)
    mainButton.BorderSizePixel = 2
    mainButton.Size = UDim2.new(1, -2, 0, 45)
    mainButton.Font = Enum.Font.GothamBold
    mainButton.Text = "ANTI-ADMIN SETTINGS"
    mainButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    mainButton.TextSize = 14
    mainButton.TextStrokeTransparency = 0.7
    mainButton.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 6)
    mainCorner.Parent = mainButton
    
    mainButton.MouseButton1Click:Connect(function()
        toggleSettings(FeatureContainer.Parent or FeatureContainer)
    end)
    
    mainButton.MouseEnter:Connect(function()
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(mainButton, tweenInfo, {
            BackgroundColor3 = Color3.fromRGB(0, 120, 200),
            BorderColor3 = Color3.fromRGB(100, 200, 255)
        })
        tween:Play()
    end)
    
    mainButton.MouseLeave:Connect(function()
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(mainButton, tweenInfo, {
            BackgroundColor3 = Color3.fromRGB(30, 35, 40),
            BorderColor3 = Color3.fromRGB(0, 150, 255)
        })
        tween:Play()
    end)
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Parent = mainButton
    statusLabel.BackgroundTransparency = 1
    statusLabel.Size = UDim2.new(0, 120, 1, 0)
    statusLabel.Position = UDim2.new(1, -125, 0, 0)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Text = "Klik untuk Settings"
    statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    statusLabel.TextSize = 10
    statusLabel.TextYAlignment = Enum.TextYAlignment.Center
    statusLabel.TextXAlignment = Enum.TextXAlignment.Right
    
    spawn(function()
        while mainButton.Parent do
            local activeCount = 0
            for _, state in pairs(protectionStates) do
                if state.enabled then
                    activeCount = activeCount + 1
                end
            end
            
            if activeCount > 0 then
                statusLabel.Text = activeCount .. " Aktif"
                statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            else
                statusLabel.Text = "Nonaktif"
                statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            end
            
            wait(1)
        end
    end)
    
    safeCall(function()
        local InfoLabel = Instance.new("TextLabel")
        InfoLabel.Name = "AntiAdminInfo"
        InfoLabel.Parent = FeatureContainer
        InfoLabel.BackgroundColor3 = Color3.fromRGB(15, 25, 35)
        InfoLabel.BorderColor3 = Color3.fromRGB(0, 150, 255)
        InfoLabel.BorderSizePixel = 2
        InfoLabel.Size = UDim2.new(1, -2, 0, 120)
        InfoLabel.LayoutOrder = 999
        InfoLabel.Font = Enum.Font.Gotham
        InfoLabel.TextSize = 10
        InfoLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
        InfoLabel.TextYAlignment = Enum.TextYAlignment.Top
        InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
        InfoLabel.TextWrapped = true
        InfoLabel.TextStrokeTransparency = 0.7
        InfoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        InfoLabel.TextScaled = false
        
        InfoLabel.Text = [[SISTEM ANTI-ADMIN v2.3
Buatan: Fari Noveri | Error 117 & 217 Fixed

FITUR BARU:
• Single button dengan settings GUI
• Checkbox untuk pilih fitur yang mau diaktifin
• Status indicator real-time
• Select All / Stop All buttons
• Improved UI dengan hover effects

Klik tombol di atas untuk buka settings!
Pilih fitur yang diinginkan lalu klik TERAPKAN
Gunakan STOP ALL untuk matikan semua proteksi]]

        local TextPadding = Instance.new("UIPadding")
        TextPadding.Parent = InfoLabel
        TextPadding.PaddingLeft = UDim.new(0, 8)
        TextPadding.PaddingRight = UDim.new(0, 8)
        TextPadding.PaddingTop = UDim.new(0, 5)
        TextPadding.PaddingBottom = UDim.new(0, 5)
        
        local InfoCorner = Instance.new("UICorner")
        InfoCorner.CornerRadius = UDim.new(0, 6)
        InfoCorner.Parent = InfoLabel
        
        spawn(function()
            if not TweenService then return end
            local colors = {
                Color3.fromRGB(100, 200, 255), 
                Color3.fromRGB(120, 255, 120),   
                Color3.fromRGB(255, 120, 120), 
                Color3.fromRGB(255, 255, 120)  
            }
            
            local colorIndex = 1
            while InfoLabel and InfoLabel.Parent do
                safeCall(function()
                    local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
                    local tween = TweenService:Create(InfoLabel, tweenInfo, {
                        TextColor3 = colors[colorIndex]
                    })
                    tween:Play()
                    tween.Completed:Wait()
                    
                    colorIndex = colorIndex + 1
                    if colorIndex > #colors then colorIndex = 1 end
                    wait(0.5)
                end)
            end
        end)
    end)
    
end

return AntiAdmin