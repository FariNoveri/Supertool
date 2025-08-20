-- Enhanced Visual-related features with Penetration, Auto-aim, and Health-based ESP
-- Enhanced by request for penetration through objects, auto-aim, and health-based ESP colors

-- Dependencies: These must be passed from mainloader.lua
local Players, UserInputService, RunService, Workspace, Lighting, RenderSettings, ContextActionService, connections, buttonStates, ScrollFrame, ScreenGui, settings, humanoid, rootPart, player

-- Initialize module
local Visual = {}

-- Variables
Visual.freecamEnabled = false
Visual.freecamPosition = nil
Visual.freecamCFrame = nil
Visual.fullbrightEnabled = false
Visual.flashlightEnabled = false
Visual.lowDetailEnabled = false
Visual.espEnabled = false
Visual.penetrationEnabled = false -- New feature
Visual.autoAimEnabled = false -- New feature
Visual.currentTimeMode = "normal"
Visual.joystickDelta = Vector2.new(0, 0)
Visual.character = nil
local flashlight
local pointLight
local espHighlights = {}
local defaultLightingSettings = {}
local joystickFrame
local joystickKnob
local touchStartPos
local lastYaw, lastPitch = 0, 0
local foliageStates = {}
local processedObjects = {}
local freecamSpeed = 50
local cameraSensitivity = 0.003

-- New variables for enhanced features
local penetrationConnections = {}
local autoAimConnections = {}
local lastAutoAimTarget = nil
local autoAimCooldown = 0

-- Function to get enemy health and determine color
local function getHealthColor(enemy)
    if not enemy or not enemy.Character then
        return Color3.fromRGB(0, 0, 0) -- Black for dead/no character
    end
    
    local humanoid = enemy.Character:FindFirstChild("Humanoid")
    if not humanoid then
        return Color3.fromRGB(0, 0, 0) -- Black for no humanoid
    end
    
    local healthPercent = humanoid.Health / humanoid.MaxHealth
    
    if humanoid.Health <= 0 then
        return Color3.fromRGB(0, 0, 0) -- Black for dead
    elseif healthPercent >= 0.8 then
        return Color3.fromRGB(0, 100, 255) -- Blue for full health
    elseif healthPercent >= 0.4 then
        return Color3.fromRGB(255, 255, 0) -- Yellow for half health
    else
        return Color3.fromRGB(255, 0, 0) -- Red for low health
    end
end

-- Function to check if enemy is behind cover
local function isEnemyBehindCover(enemyPosition)
    if not Visual.penetrationEnabled then
        return false -- If penetration is disabled, don't ignore cover
    end
    
    local camera = workspace.CurrentCamera
    local rayDirection = (enemyPosition - camera.CFrame.Position).Unit * 1000
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {player.Character}
    
    local raycastResult = workspace:Raycast(camera.CFrame.Position, rayDirection, raycastParams)
    
    if raycastResult then
        local hitPart = raycastResult.Instance
        local hitCharacter = hitPart.Parent
        
        -- If we hit the enemy directly, they're not behind cover
        if hitCharacter and hitCharacter:FindFirstChild("Humanoid") then
            return false
        end
        
        -- If we hit something else first, enemy is behind cover
        return true
    end
    
    return false
end

-- Function to find nearest visible enemy for auto-aim
local function findNearestEnemy()
    if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    
    local playerPosition = player.Character.HumanoidRootPart.Position
    local nearestEnemy = nil
    local nearestDistance = math.huge
    
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local enemyPosition = otherPlayer.Character.HumanoidRootPart.Position
            local distance = (playerPosition - enemyPosition).Magnitude
            
            -- Check if enemy is closer and either not behind cover or penetration is enabled
            if distance < nearestDistance then
                local behindCover = isEnemyBehindCover(enemyPosition)
                
                -- Include enemy if penetration is enabled or they're not behind cover
                if Visual.penetrationEnabled or not behindCover then
                    nearestDistance = distance
                    nearestEnemy = otherPlayer
                end
            end
        end
    end
    
    return nearestEnemy
end

-- Function to create penetrating projectile
local function createPenetratingProjectile(startPos, targetPos)
    if not Visual.penetrationEnabled then
        return
    end
    
    local direction = (targetPos - startPos).Unit
    local distance = (targetPos - startPos).Magnitude
    
    -- Create visual effect for penetrating shot
    local beam = Instance.new("Beam")
    local attachment1 = Instance.new("Attachment")
    local attachment2 = Instance.new("Attachment")
    
    -- Create temporary parts for beam attachments
    local part1 = Instance.new("Part")
    part1.Anchored = true
    part1.CanCollide = false
    part1.Transparency = 1
    part1.Size = Vector3.new(0.1, 0.1, 0.1)
    part1.Position = startPos
    part1.Parent = workspace
    
    local part2 = Instance.new("Part")
    part2.Anchored = true
    part2.CanCollide = false
    part2.Transparency = 1
    part2.Size = Vector3.new(0.1, 0.1, 0.1)
    part2.Position = targetPos
    part2.Parent = workspace
    
    attachment1.Parent = part1
    attachment2.Parent = part2
    
    beam.Attachment0 = attachment1
    beam.Attachment1 = attachment2
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 0))
    beam.Width0 = 0.5
    beam.Width1 = 0.5
    beam.Transparency = NumberSequence.new(0)
    beam.Parent = workspace
    
    -- Damage all enemies in line
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {player.Character}
    
    -- Multiple raycasts to hit through objects
    local currentPos = startPos
    local remainingDistance = distance
    
    while remainingDistance > 0 do
        local rayDirection = direction * math.min(remainingDistance, 50)
        local raycastResult = workspace:Raycast(currentPos, rayDirection, raycastParams)
        
        if raycastResult then
            local hitPart = raycastResult.Instance
            local hitCharacter = hitPart.Parent
            
            -- Check if we hit an enemy
            if hitCharacter and hitCharacter:FindFirstChild("Humanoid") then
                local enemyHumanoid = hitCharacter:FindFirstChild("Humanoid")
                if enemyHumanoid and enemyHumanoid ~= humanoid then
                    -- Deal damage (simulated)
                    pcall(function()
                        enemyHumanoid.Health = enemyHumanoid.Health - 50
                        print("Penetrating hit on", hitCharacter.Name)
                    end)
                end
            end
            
            -- Continue through the object
            currentPos = raycastResult.Position + direction * 0.1
            remainingDistance = remainingDistance - (raycastResult.Position - currentPos).Magnitude
        else
            break
        end
    end
    
    -- Clean up visual effect after delay
    game:GetService("Debris"):AddItem(part1, 0.5)
    game:GetService("Debris"):AddItem(part2, 0.5)
    game:GetService("Debris"):AddItem(beam, 0.5)
end

-- Auto-aim function
local function performAutoAim()
    if not Visual.autoAimEnabled or autoAimCooldown > 0 then
        return
    end
    
    local nearestEnemy = findNearestEnemy()
    if not nearestEnemy or not nearestEnemy.Character or not nearestEnemy.Character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local camera = workspace.CurrentCamera
    local enemyPosition = nearestEnemy.Character.HumanoidRootPart.Position
    local playerPosition = camera.CFrame.Position
    
    -- Calculate aim direction
    local aimDirection = (enemyPosition - playerPosition).Unit
    local newCFrame = CFrame.lookAt(playerPosition, enemyPosition)
    
    -- Smoothly adjust camera to target
    camera.CFrame = camera.CFrame:Lerp(newCFrame, 0.3)
    
    -- If penetration is enabled, create penetrating shot
    if Visual.penetrationEnabled then
        createPenetratingProjectile(playerPosition, enemyPosition)
    end
    
    lastAutoAimTarget = nearestEnemy
    autoAimCooldown = 0.5 -- Cooldown to prevent spam
    
    print("Auto-aimed at", nearestEnemy.Name)
end

-- Toggle penetration
local function togglePenetration(enabled)
    Visual.penetrationEnabled = enabled
    print("Penetration Mode:", enabled)
    
    if enabled then
        -- Monitor for shooting to enable penetration
        if connections.penetrationMonitor then
            connections.penetrationMonitor:Disconnect()
        end
        
        connections.penetrationMonitor = UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            
            -- Detect shooting (left mouse button or touch)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or 
               input.UserInputType == Enum.UserInputType.Touch then
                
                local camera = workspace.CurrentCamera
                local nearestEnemy = findNearestEnemy()
                
                if nearestEnemy and nearestEnemy.Character and nearestEnemy.Character:FindFirstChild("HumanoidRootPart") then
                    createPenetratingProjectile(camera.CFrame.Position, nearestEnemy.Character.HumanoidRootPart.Position)
                end
            end
        end)
    else
        if connections.penetrationMonitor then
            connections.penetrationMonitor:Disconnect()
            connections.penetrationMonitor = nil
        end
    end
end

-- Toggle auto-aim
local function toggleAutoAim(enabled)
    Visual.autoAimEnabled = enabled
    print("Auto-Aim:", enabled)
    
    if enabled then
        -- Monitor for continuous auto-aim
        if connections.autoAimUpdate then
            connections.autoAimUpdate:Disconnect()
        end
        
        connections.autoAimUpdate = RunService.Heartbeat:Connect(function(deltaTime)
            if Visual.autoAimEnabled then
                -- Reduce cooldown
                if autoAimCooldown > 0 then
                    autoAimCooldown = autoAimCooldown - deltaTime
                end
                
                -- Auto-aim when shooting
                if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                    performAutoAim()
                end
            end
        end)
        
        -- Also trigger on touch for mobile
        if connections.autoAimTouch then
            connections.autoAimTouch:Disconnect()
        end
        
        connections.autoAimTouch = UserInputService.TouchTap:Connect(function(touchPositions, processed)
            if not processed and Visual.autoAimEnabled then
                performAutoAim()
            end
        end)
    else
        if connections.autoAimUpdate then
            connections.autoAimUpdate:Disconnect()
            connections.autoAimUpdate = nil
        end
        if connections.autoAimTouch then
            connections.autoAimTouch:Disconnect()
            connections.autoAimTouch = nil
        end
    end
end

-- Time mode configurations
local timeModeConfigs = {
    normal = {
        ClockTime = nil,
        Brightness = nil,
        Ambient = nil,
        OutdoorAmbient = nil,
        ColorShift_Top = nil,
        ColorShift_Bottom = nil,
        SunAngularSize = nil,
        FogColor = nil
    },
    morning = {
        ClockTime = 6.5,
        Brightness = 1.5,
        Ambient = Color3.fromRGB(150, 120, 80),
        OutdoorAmbient = Color3.fromRGB(255, 200, 120),
        ColorShift_Top = Color3.fromRGB(255, 180, 120),
        ColorShift_Bottom = Color3.fromRGB(255, 220, 180),
        SunAngularSize = 25,
        FogColor = Color3.fromRGB(200, 180, 150)
    },
    day = {
        ClockTime = 12,
        Brightness = 2,
        Ambient = Color3.fromRGB(180, 180, 180),
        OutdoorAmbient = Color3.fromRGB(255, 255, 255),
        ColorShift_Top = Color3.fromRGB(255, 255, 255),
        ColorShift_Bottom = Color3.fromRGB(240, 240, 255),
        SunAngularSize = 21,
        FogColor = Color3.fromRGB(220, 220, 255)
    },
    evening = {
        ClockTime = 18,
        Brightness = 1,
        Ambient = Color3.fromRGB(120, 80, 60),
        OutdoorAmbient = Color3.fromRGB(255, 150, 100),
        ColorShift_Top = Color3.fromRGB(255, 120, 80),
        ColorShift_Bottom = Color3.fromRGB(255, 180, 140),
        SunAngularSize = 30,
        FogColor = Color3.fromRGB(180, 120, 80)
    },
    night = {
        ClockTime = 0,
        Brightness = 0.3,
        Ambient = Color3.fromRGB(30, 30, 60),
        OutdoorAmbient = Color3.fromRGB(80, 80, 120),
        ColorShift_Top = Color3.fromRGB(50, 50, 80),
        ColorShift_Bottom = Color3.fromRGB(20, 20, 40),
        SunAngularSize = 21,
        FogColor = Color3.fromRGB(40, 40, 80)
    }
}

-- Store original lighting settings
local function storeOriginalLightingSettings()
    if not defaultLightingSettings.stored then
        defaultLightingSettings.stored = true
        defaultLightingSettings.Brightness = Lighting.Brightness
        defaultLightingSettings.ClockTime = Lighting.ClockTime
        defaultLightingSettings.FogEnd = Lighting.FogEnd
        defaultLightingSettings.FogStart = Lighting.FogStart
        defaultLightingSettings.FogColor = Lighting.FogColor
        defaultLightingSettings.GlobalShadows = Lighting.GlobalShadows
        defaultLightingSettings.Ambient = Lighting.Ambient
        defaultLightingSettings.OutdoorAmbient = Lighting.OutdoorAmbient
        defaultLightingSettings.ColorShift_Top = Lighting.ColorShift_Top
        defaultLightingSettings.ColorShift_Bottom = Lighting.ColorShift_Bottom
        defaultLightingSettings.SunAngularSize = Lighting.SunAngularSize
        defaultLightingSettings.TerrainDecoration = Workspace.Terrain.Decoration
        
        pcall(function()
            defaultLightingSettings.QualityLevel = game:GetService("Settings").Rendering.QualityLevel
            defaultLightingSettings.StreamingEnabled = Workspace.StreamingEnabled
            defaultLightingSettings.StreamingMinRadius = Workspace.StreamingMinRadius
            defaultLightingSettings.StreamingTargetRadius = Workspace.StreamingTargetRadius
        end)
        
        print("Original lighting settings stored")
    end
end

-- Create virtual joystick for mobile Freecam
local function createJoystick()
    joystickFrame = Instance.new("Frame")
    joystickFrame.Name = "FreecamJoystick"
    joystickFrame.Size = UDim2.new(0, 120, 0, 120)
    joystickFrame.Position = UDim2.new(0.05, 0, 0.75, 0)
    joystickFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    joystickFrame.BackgroundTransparency = 0.3
    joystickFrame.BorderSizePixel = 0
    joystickFrame.Visible = false
    joystickFrame.ZIndex = 10
    joystickFrame.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = joystickFrame

    local outerRing = Instance.new("Frame")
    outerRing.Name = "OuterRing"
    outerRing.Size = UDim2.new(1, -4, 1, -4)
    outerRing.Position = UDim2.new(0, 2, 0, 2)
    outerRing.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    outerRing.BackgroundTransparency = 0.5
    outerRing.BorderSizePixel = 0
    outerRing.ZIndex = 9
    outerRing.Parent = joystickFrame
    
    local outerCorner = Instance.new("UICorner")
    outerCorner.CornerRadius = UDim.new(0.5, 0)
    outerCorner.Parent = outerRing

    joystickKnob = Instance.new("Frame")
    joystickKnob.Name = "Knob"
    joystickKnob.Size = UDim2.new(0, 50, 0, 50)
    joystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
    joystickKnob.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
    joystickKnob.BackgroundTransparency = 0.1
    joystickKnob.BorderSizePixel = 0
    joystickKnob.ZIndex = 11
    joystickKnob.Parent = joystickFrame

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0.5, 0)
    knobCorner.Parent = joystickKnob
    
    local instructionText = Instance.new("TextLabel")
    instructionText.Name = "Instruction"
    instructionText.Size = UDim2.new(0, 200, 0, 30)
    instructionText.Position = UDim2.new(0, 0, 0, -40)
    instructionText.BackgroundTransparency = 1
    instructionText.Text = "Move: Left joystick | Look: Right side swipe"
    instructionText.TextColor3 = Color3.fromRGB(255, 255, 255)
    instructionText.TextSize = 12
    instructionText.Font = Enum.Font.SourceSansBold
    instructionText.TextStrokeTransparency = 0.5
    instructionText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    instructionText.ZIndex = 12
    instructionText.Parent = joystickFrame
end

-- Handle joystick input for Freecam movement
local function handleJoystickInput(input, processed)
    if not Visual.freecamEnabled or processed then return Vector2.new(0, 0) end
    
    if input.UserInputType == Enum.UserInputType.Touch then
        local touchPos = input.Position
        local joystickCenter = joystickFrame.AbsolutePosition + joystickFrame.AbsoluteSize * 0.5
        local frameRect = {
            X = joystickFrame.AbsolutePosition.X,
            Y = joystickFrame.AbsolutePosition.Y,
            Width = joystickFrame.AbsoluteSize.X,
            Height = joystickFrame.AbsoluteSize.Y
        }
        
        local isInJoystick = touchPos.X >= frameRect.X and touchPos.X <= frameRect.X + frameRect.Width and
                            touchPos.Y >= frameRect.Y and touchPos.Y <= frameRect.Y + frameRect.Height
        
        if input.UserInputState == Enum.UserInputState.Begin and isInJoystick then
            local delta = Vector2.new(touchPos.X - joystickCenter.X, touchPos.Y - joystickCenter.Y)
            local magnitude = delta.Magnitude
            local maxRadius = 35
            if magnitude > maxRadius then
                delta = delta * (maxRadius / magnitude)
            end
            joystickKnob.Position = UDim2.new(0.5, delta.X - 25, 0.5, delta.Y - 25)
            return delta / maxRadius
            
        elseif input.UserInputState == Enum.UserInputState.Change and isInJoystick then
            local delta = Vector2.new(touchPos.X - joystickCenter.X, touchPos.Y - joystickCenter.Y)
            local magnitude = delta.Magnitude
            local maxRadius = 35
            if magnitude > maxRadius then
                delta = delta * (maxRadius / magnitude)
            end
            joystickKnob.Position = UDim2.new(0.5, delta.X - 25, 0.5, delta.Y - 25)
            return delta / maxRadius
            
        elseif input.UserInputState == Enum.UserInputState.End then
            joystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
            return Vector2.new(0, 0)
        end
    end
    return Vector2.new(0, 0)
end

-- Handle swipe for Freecam rotation
local function handleSwipe(input, processed)
    if not Visual.freecamEnabled or input.UserInputType ~= Enum.UserInputType.Touch or processed then return end
    
    local touchPos = input.Position
    local screenSize = workspace.CurrentCamera.ViewportSize
    local joystickCenter = joystickFrame.AbsolutePosition + joystickFrame.AbsoluteSize * 0.5
    local frameRect = {
        X = joystickFrame.AbsolutePosition.X,
        Y = joystickFrame.AbsolutePosition.Y,
        Width = joystickFrame.AbsoluteSize.X,
        Height = joystickFrame.AbsoluteSize.Y
    }
    
    local isInJoystick = touchPos.X >= frameRect.X and touchPos.X <= frameRect.X + frameRect.Width and
                        touchPos.Y >= frameRect.Y and touchPos.Y <= frameRect.Y + frameRect.Height
    
    if isInJoystick then return end
    
    local isRightSide = touchPos.X > screenSize.X * 0.5
    if not isRightSide then return end
    
    if input.UserInputState == Enum.UserInputState.Begin then
        touchStartPos = touchPos
    elseif input.UserInputState == Enum.UserInputState.Change and touchStartPos then
        local delta = touchPos - touchStartPos
        lastYaw = lastYaw - delta.X * cameraSensitivity
        lastPitch = math.clamp(lastPitch - delta.Y * cameraSensitivity, -math.rad(89), math.rad(89))
        touchStartPos = touchPos
    elseif input.UserInputState == Enum.UserInputState.End then
        touchStartPos = nil
    end
end

-- Enhanced ESP with health-based colors
local function toggleESP(enabled)
    Visual.espEnabled = enabled
    print("ESP:", enabled)
    
    if enabled then
        for _, highlight in pairs(espHighlights) do
            if highlight and highlight.Parent then
                highlight:Destroy()
            end
        end
        espHighlights = {}
        
        local function createESPForCharacter(character, targetPlayer)
            if not character or not character:FindFirstChild("HumanoidRootPart") then return end
            
            local isInvisible = false
            
            pcall(function()
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Transparency >= 0.9 then
                        isInvisible = true
                        break
                    end
                end
                if character:GetAttribute("IsInvisible") or character:GetAttribute("AdminInvisible") then
                    isInvisible = true
                end
            end)
            
            if espHighlights[targetPlayer] then
                espHighlights[targetPlayer]:Destroy()
                espHighlights[targetPlayer] = nil
            end
            
            local highlight = Instance.new("Highlight")
            highlight.Name = "ESPHighlight"
            
            -- Set color based on health
            local healthColor = getHealthColor(targetPlayer)
            highlight.FillColor = healthColor
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
            highlight.FillTransparency = isInvisible and 0.3 or 0.5
            highlight.OutlineTransparency = 0
            highlight.Adornee = character
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = character
            espHighlights[targetPlayer] = highlight
        end
        
        -- Create highlights for existing players
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= player and otherPlayer.Character then
                createESPForCharacter(otherPlayer.Character, otherPlayer)
            end
        end
        
        -- Update ESP colors based on health continuously
        if connections.espHealthUpdate then
            connections.espHealthUpdate:Disconnect()
        end
        connections.espHealthUpdate = RunService.Heartbeat:Connect(function()
            if Visual.espEnabled then
                for targetPlayer, highlight in pairs(espHighlights) do
                    if targetPlayer and targetPlayer.Character and highlight and highlight.Parent then
                        local newColor = getHealthColor(targetPlayer)
                        highlight.FillColor = newColor
                    end
                end
            end
        end)
        
        -- Handle new players joining
        if connections.espPlayerAdded then
            connections.espPlayerAdded:Disconnect()
        end
        connections.espPlayerAdded = Players.PlayerAdded:Connect(function(newPlayer)
            if Visual.espEnabled and newPlayer ~= player then
                newPlayer.CharacterAdded:Connect(function(character)
                    task.wait(0.3)
                    if Visual.espEnabled then
                        createESPForCharacter(character, newPlayer)
                    end
                end)
            end
        end)
        
        -- Handle players leaving
        if connections.espPlayerLeaving then
            connections.espPlayerLeaving:Disconnect()
        end
        connections.espPlayerLeaving = Players.PlayerRemoving:Connect(function(leavingPlayer)
            if espHighlights[leavingPlayer] then
                espHighlights[leavingPlayer]:Destroy()
                espHighlights[leavingPlayer] = nil
            end
        end)
        
        -- Handle character respawning
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                if connections["espCharAdded" .. otherPlayer.UserId] then
                    connections["espCharAdded" .. otherPlayer.UserId]:Disconnect()
                end
                if connections["espCharRemoving" .. otherPlayer.UserId] then
                    connections["espCharRemoving" .. otherPlayer.UserId]:Disconnect()
                end
                
                connections["espCharAdded" .. otherPlayer.UserId] = otherPlayer.CharacterAdded:Connect(function(character)
                    task.wait(0.3)
                    if Visual.espEnabled then
                        createESPForCharacter(character, otherPlayer)
                    end
                end)
                
                connections["espCharRemoving" .. otherPlayer.UserId] = otherPlayer.CharacterRemoving:Connect(function()
                    if espHighlights[otherPlayer] then
                        espHighlights[otherPlayer]:Destroy()
                        espHighlights[otherPlayer] = nil
                    end
                end)
            end
        end
        
        -- Backup check for missed characters
        if connections.espBackupCheck then
            connections.espBackupCheck:Disconnect()
        end
        connections.espBackupCheck = RunService.Heartbeat:Connect(function()
            if Visual.espEnabled then
                for _, otherPlayer in pairs(Players:GetPlayers()) do
                    if otherPlayer ~= player and otherPlayer.Character and 
                       otherPlayer.Character:FindFirstChild("HumanoidRootPart") and 
                       not espHighlights[otherPlayer] then
                        createESPForCharacter(otherPlayer.Character, otherPlayer)
                    end
                end
            end
        end)
        
    else
        -- Clean up connections
        if connections.espHealthUpdate then
            connections.espHealthUpdate:Disconnect()
            connections.espHealthUpdate = nil
        end
        if connections.espPlayerLeaving then
            connections.espPlayerLeaving:Disconnect()
            connections.espPlayerLeaving = nil
        end
        if connections.espPlayerAdded then
            connections.espPlayerAdded:Disconnect()
            connections.espPlayerAdded = nil
        end
        if connections.espBackupCheck then
            connections.espBackupCheck:Disconnect()
            connections.espBackupCheck = nil
        end
        
        for key, connection in pairs(connections) do
            if string.match(key, "espCharAdded") or string.match(key, "espCharRemoving") then
                connection:Disconnect()
                connections[key] = nil
            end
        end
        
        for _, highlight in pairs(espHighlights) do
            if highlight and highlight.Parent then
                highlight:Destroy()
            end
        end
        espHighlights = {}
    end
end

-- Freecam (keeping the same implementation as before)
local function toggleFreecam(enabled)
    Visual.freecamEnabled = enabled
    print("Freecam:", enabled)
    
    if enabled then
        local camera = Workspace.CurrentCamera
        
        local currentCharacter = player.Character
        local currentHumanoid = currentCharacter and currentCharacter:FindFirstChild("Humanoid")
        local currentRootPart = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
        
        if not currentHumanoid or not currentRootPart then
            print("Warning: No character found for freecam")
            Visual.freecamEnabled = false
            return
        end
        
        Visual.originalWalkSpeed = currentHumanoid.WalkSpeed
        Visual.originalJumpPower = currentHumanoid.JumpPower
        Visual.originalJumpHeight = currentHumanoid.JumpHeight
        Visual.originalPosition = currentRootPart.CFrame
        
        currentHumanoid.PlatformStand = true
        currentHumanoid.WalkSpeed = 0
        currentHumanoid.JumpPower = 0
        currentHumanoid.JumpHeight = 0
        currentRootPart.Anchored = true
        currentRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        currentRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CameraSubject = nil
        
        Visual.freecamCFrame = camera.CFrame
        Visual.freecamPosition = camera.CFrame.Position
        
        local _, yaw, pitch = camera.CFrame:ToEulerAnglesYXZ()
        lastYaw = yaw
        lastPitch = pitch
        
        freecamSpeed = (settings.FreecamSpeed and settings.FreecamSpeed.value) or 50
        
        if joystickFrame then
            joystickFrame.Visible = true
        end
        
        if connections.freecam then
            connections.freecam:Disconnect()
        end
        connections.freecam = RunService.RenderStepped:Connect(function(deltaTime)
            if Visual.freecamEnabled then
                local char = player.Character
                local hum = char and char:FindFirstChild("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                
                local moveVector = Vector3.new()
                
                local cameraCFrame = CFrame.new(Visual.freecamPosition) * CFrame.Angles(lastPitch, lastYaw, 0)
                
                if Visual.joystickDelta.Magnitude > 0.1 then
                    local forward = -cameraCFrame.LookVector * Visual.joystickDelta.Y
                    local right = cameraCFrame.RightVector * Visual.joystickDelta.X
                    moveVector = (forward + right) * freecamSpeed * deltaTime * Visual.joystickDelta.Magnitude
                end
                
                Visual.freecamPosition = Visual.freecamPosition + moveVector
                
                Visual.freecamCFrame = CFrame.new(Visual.freecamPosition) * CFrame.Angles(lastPitch, lastYaw, 0)
                camera.CFrame = Visual.freecamCFrame
                
                if hum and root and Visual.originalPosition then
                    hum.PlatformStand = true
                    hum.WalkSpeed = 0
                    hum.JumpPower = 0
                    hum.JumpHeight = 0
                    root.Anchored = true
                    root.CFrame = Visual.originalPosition
                    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
            end
        end)
        
        if connections.touchInput then
            connections.touchInput:Disconnect()
        end
        connections.touchInput = UserInputService.InputChanged:Connect(function(input, processed)
            if input.UserInputType == Enum.UserInputType.Touch then
                Visual.joystickDelta = handleJoystickInput(input, processed)
                handleSwipe(input, processed)
            end
        end)
        
        if connections.touchBegan then
            connections.touchBegan:Disconnect()
        end
        connections.touchBegan = UserInputService.InputBegan:Connect(function(input, processed)
            if input.UserInputType == Enum.UserInputType.Touch then
                Visual.joystickDelta = handleJoystickInput(input, processed)
                handleSwipe(input, processed)
            end
        end)
        
        if connections.touchEnded then
            connections.touchEnded:Disconnect()
        end
        connections.touchEnded = UserInputService.InputEnded:Connect(function(input, processed)
            if input.UserInputType == Enum.UserInputType.Touch then
                Visual.joystickDelta = handleJoystickInput(input, processed)
                handleSwipe(input, processed)
            end
        end)
        
    else
        if connections.freecam then
            connections.freecam:Disconnect()
            connections.freecam = nil
        end
        if connections.touchInput then
            connections.touchInput:Disconnect()
            connections.touchInput = nil
        end
        if connections.touchBegan then
            connections.touchBegan:Disconnect()
            connections.touchBegan = nil
        end
        if connections.touchEnded then
            connections.touchEnded:Disconnect()
            connections.touchEnded = nil
        end
        
        if joystickFrame then
            joystickFrame.Visible = false
            joystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
        end
        
        local camera = Workspace.CurrentCamera
        camera.CameraType = Enum.CameraType.Custom
        
        local currentCharacter = player.Character
        local currentHumanoid = currentCharacter and currentCharacter:FindFirstChild("Humanoid")
        local currentRootPart = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
        
        if currentHumanoid then
            camera.CameraSubject = currentHumanoid
        end
        
        if currentHumanoid and currentRootPart then
            currentHumanoid.PlatformStand = false
            currentRootPart.Anchored = false
            
            currentHumanoid.WalkSpeed = Visual.originalWalkSpeed or (settings.WalkSpeed and settings.WalkSpeed.value) or 16
            currentHumanoid.JumpPower = Visual.originalJumpPower or ((settings.JumpHeight and settings.JumpHeight.value * 2.4) or 50)
            currentHumanoid.JumpHeight = Visual.originalJumpHeight or (settings.JumpHeight and settings.JumpHeight.value) or 7.2
            
            task.wait(0.1)
            camera.CFrame = CFrame.lookAt(currentRootPart.Position + Vector3.new(0, 2, 10), currentRootPart.Position)
        end
        
        Visual.freecamPosition = nil
        Visual.freecamCFrame = nil
        Visual.joystickDelta = Vector2.new(0, 0)
        lastYaw, lastPitch = 0, 0
        touchStartPos = nil
    end
end

-- Time Mode Functions
local function setTimeMode(mode)
    storeOriginalLightingSettings()
    Visual.currentTimeMode = mode
    print("Time Mode:", mode)
    
    local config = timeModeConfigs[mode]
    if not config then
        print("Invalid time mode:", mode)
        return
    end
    
    for property, value in pairs(config) do
        if value ~= nil then
            pcall(function()
                Lighting[property] = value
            end)
        else
            if defaultLightingSettings[property] ~= nil then
                pcall(function()
                    Lighting[property] = defaultLightingSettings[property]
                end)
            end
        end
    end
    
    if connections.timeModeMonitor then
        connections.timeModeMonitor:Disconnect()
    end
    
    if mode ~= "normal" then
        connections.timeModeMonitor = RunService.Heartbeat:Connect(function()
            if Visual.currentTimeMode == mode then
                local currentConfig = timeModeConfigs[mode]
                for property, expectedValue in pairs(currentConfig) do
                    if expectedValue ~= nil then
                        pcall(function()
                            if Lighting[property] ~= expectedValue then
                                Lighting[property] = expectedValue
                            end
                        end)
                    end
                end
            end
        end)
    else
        if connections.timeModeMonitor then
            connections.timeModeMonitor:Disconnect()
            connections.timeModeMonitor = nil
        end
    end
end

local function toggleMorning(enabled)
    if enabled then
        setTimeMode("morning")
    else
        setTimeMode("normal")
    end
end

local function toggleDay(enabled)
    if enabled then
        setTimeMode("day")
    else
        setTimeMode("normal")
    end
end

local function toggleEvening(enabled)
    if enabled then
        setTimeMode("evening")
    else
        setTimeMode("normal")
    end
end

local function toggleNight(enabled)
    if enabled then
        setTimeMode("night")
    else
        setTimeMode("normal")
    end
end

-- Fullbright
local function toggleFullbright(enabled)
    Visual.fullbrightEnabled = enabled
    print("Fullbright:", enabled)
    
    storeOriginalLightingSettings()
    
    if enabled then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    else
        Lighting.Brightness = defaultLightingSettings.Brightness or 1
        Lighting.ClockTime = defaultLightingSettings.ClockTime or 12
        Lighting.FogEnd = defaultLightingSettings.FogEnd or 1000
        Lighting.GlobalShadows = defaultLightingSettings.GlobalShadows or true
        Lighting.Ambient = defaultLightingSettings.Ambient or Color3.fromRGB(100, 100, 100)
    end
end

-- Flashlight
local function toggleFlashlight(enabled)
    Visual.flashlightEnabled = enabled
    print("Flashlight:", enabled)
    
    if enabled then
        local function setupFlashlight()
            if flashlight then
                flashlight:Destroy()
                flashlight = nil
            end
            if pointLight then
                pointLight:Destroy()
                pointLight = nil
            end
            
            flashlight = Instance.new("SpotLight")
            flashlight.Name = "Flashlight"
            flashlight.Brightness = 20
            flashlight.Range = 150
            flashlight.Angle = 45
            flashlight.Face = Enum.NormalId.Front
            flashlight.Color = Color3.fromRGB(255, 255, 200)
            flashlight.Enabled = true
            
            pointLight = Instance.new("PointLight")
            pointLight.Name = "FlashlightPoint"
            pointLight.Brightness = 8
            pointLight.Range = 80
            pointLight.Color = Color3.fromRGB(255, 255, 200)
            pointLight.Enabled = true
            
            local character = player.Character
            local head = character and character:FindFirstChild("Head")
            
            if head then
                flashlight.Parent = head
                pointLight.Parent = head
                print("Flashlight attached to head")
            else
                local camera = Workspace.CurrentCamera
                flashlight.Parent = camera
                pointLight.Parent = camera
                print("Flashlight attached to camera (fallback)")
            end
        end
        
        setupFlashlight()
        
        if connections.flashlight then
            connections.flashlight:Disconnect()
        end
        connections.flashlight = RunService.Heartbeat:Connect(function()
            if Visual.flashlightEnabled then
                local character = player.Character
                local head = character and character:FindFirstChild("Head")
                local camera = Workspace.CurrentCamera
                
                if not flashlight or not flashlight.Parent then
                    setupFlashlight()
                end
                
                if head and (not flashlight.Parent or flashlight.Parent ~= head) then
                    flashlight.Parent = head
                    pointLight.Parent = head
                elseif not head and (not flashlight.Parent or flashlight.Parent ~= camera) then
                    flashlight.Parent = camera
                    pointLight.Parent = camera
                end
                
                if flashlight then
                    flashlight.Enabled = true
                end
                if pointLight then
                    pointLight.Enabled = true
                end
                
                pcall(function()
                    if head and flashlight.Parent == head then
                        local cameraDirection = camera.CFrame.LookVector
                        head.CFrame = CFrame.lookAt(head.Position, head.Position + cameraDirection)
                    end
                end)
            end
        end)
        
        if connections.flashlightCharAdded then
            connections.flashlightCharAdded:Disconnect()
        end
        if player then
            connections.flashlightCharAdded = player.CharacterAdded:Connect(function()
                if Visual.flashlightEnabled then
                    task.wait(1)
                    setupFlashlight()
                end
            end)
        end
        
    else
        if connections.flashlight then
            connections.flashlight:Disconnect()
            connections.flashlight = nil
        end
        if connections.flashlightCharAdded then
            connections.flashlightCharAdded:Disconnect()
            connections.flashlightCharAdded = nil
        end
        
        if flashlight then
            flashlight:Destroy()
            flashlight = nil
        end
        if pointLight then
            pointLight:Destroy()
            pointLight = nil
        end
    end
end

-- Low Detail Mode
local function toggleLowDetail(enabled)
    Visual.lowDetailEnabled = enabled
    print("Low Detail Mode:", enabled)
    
    storeOriginalLightingSettings()
    
    if enabled then
        Lighting.GlobalShadows = false
        Lighting.Brightness = 0.3
        Lighting.FogEnd = 200
        Lighting.FogStart = 0
        Lighting.FogColor = Color3.fromRGB(80, 80, 80)
        
        pcall(function()
            local renderSettings = game:GetService("Settings").Rendering
            renderSettings.QualityLevel = Enum.QualityLevel.Level01
        end)
        pcall(function()
            local userSettings = UserSettings()
            local gameSettings = userSettings.GameSettings
            gameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
            gameSettings.RenderDistance = 50
        end)
        
        pcall(function()
            local terrain = Workspace.Terrain
            if not foliageStates.terrainSettings then
                foliageStates.terrainSettings = {
                    Decoration = terrain.Decoration,
                    WaterWaveSize = terrain.WaterWaveSize,
                    WaterWaveSpeed = terrain.WaterWaveSpeed,
                    WaterReflectance = terrain.WaterReflectance,
                    WaterTransparency = terrain.WaterTransparency
                }
            end
            
            terrain.Decoration = false
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 0.9
            
            spawn(function()
                pcall(function()
                    local success = pcall(function()
                        terrain:ReadVoxels(workspace.CurrentCamera.CFrame.Position - Vector3.new(100, 100, 100), Vector3.new(200, 200, 200))
                    end)
                    if success then
                        terrain.Decoration = false
                    end
                end)
            end)
            
            print("Terrain decorations (grass) disabled")
        end)
        
        spawn(function()
            local processCount = 0
            local pixelMaterial = Enum.Material.SmoothPlastic
            
            for _, obj in pairs(Workspace:GetDescendants()) do
                if not processedObjects[obj] then
                    processedObjects[obj] = true
                    
                    pcall(function()
                        local name = obj.Name:lower()
                        local parent = obj.Parent and obj.Parent.Name:lower() or ""
                        local isGrassOrFoliage = name:find("leaf") or name:find("leaves") or name:find("foliage") or 
                                               name:find("grass") or name:find("tree") or name:find("plant") or 
                                               name:find("flower") or name:find("bush") or name:find("shrub") or
                                               name:find("fern") or name:find("moss") or name:find("vine") or
                                               parent:find("grass") or parent:find("foliage") or parent:find("decoration") or
                                               obj:GetAttribute("IsFoliage") or obj:GetAttribute("IsNature") or
                                               obj:GetAttribute("IsDecoration")
                        
                        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or 
                           obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                            foliageStates[obj] = { Enabled = obj.Enabled }
                            obj.Enabled = false
                            
                        elseif obj:IsA("Decal") or obj:IsA("Texture") then
                            foliageStates[obj] = { Transparency = obj.Transparency, Texture = obj.Texture }
                            obj.Transparency = 1
                            obj.Texture = ""
                            
                        elseif obj:IsA("SurfaceGui") or obj:IsA("BillboardGui") then
                            foliageStates[obj] = { Enabled = obj.Enabled }
                            obj.Enabled = false
                            
                        elseif obj:IsA("BasePart") then
                            if isGrassOrFoliage then
                                foliageStates[obj] = { 
                                    Transparency = obj.Transparency,
                                    Material = obj.Material,
                                    Color = obj.Color,
                                    CanCollide = obj.CanCollide,
                                    Anchored = obj.Anchored
                                }
                                obj.Transparency = 1
                                obj.CanCollide = false
                                obj.Anchored = true
                            else
                                foliageStates[obj] = { 
                                    Material = obj.Material, 
                                    Reflectance = obj.Reflectance, 
                                    CastShadow = obj.CastShadow,
                                    Color = obj.Color
                                }
                                obj.Material = pixelMaterial
                                obj.Reflectance = 0
                                obj.CastShadow = false
                                local r = math.floor(obj.Color.R * 4) / 4
                                local g = math.floor(obj.Color.G * 4) / 4
                                local b = math.floor(obj.Color.B * 4) / 4
                                obj.Color = Color3.new(r, g, b)
                            end
                            
                        elseif obj:IsA("MeshPart") then
                            if isGrassOrFoliage then
                                foliageStates[obj] = { 
                                    Transparency = obj.Transparency,
                                    TextureID = obj.TextureID,
                                    Material = obj.Material,
                                    CanCollide = obj.CanCollide,
                                    Anchored = obj.Anchored
                                }
                                obj.Transparency = 1
                                obj.TextureID = ""
                                obj.CanCollide = false
                                obj.Anchored = true
                            else
                                foliageStates[obj] = { 
                                    TextureID = obj.TextureID, 
                                    Material = obj.Material,
                                    Color = obj.Color
                                }
                                obj.TextureID = ""
                                obj.Material = pixelMaterial
                                local r = math.floor(obj.Color.R * 4) / 4
                                local g = math.floor(obj.Color.G * 4) / 4
                                local b = math.floor(obj.Color.B * 4) / 4
                                obj.Color = Color3.new(r, g, b)
                            end
                            
                        elseif obj:IsA("SpecialMesh") then
                            foliageStates[obj] = { TextureId = obj.TextureId }
                            obj.TextureId = ""
                            
                        elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                            if not (obj.Name == "Flashlight" or obj.Name == "FlashlightPoint") then
                                foliageStates[obj] = { Enabled = obj.Enabled, Brightness = obj.Brightness }
                                obj.Brightness = obj.Brightness * 0.3
                            end
                            
                        elseif obj:IsA("Sound") then
                            foliageStates[obj] = { Volume = obj.Volume }
                            obj.Volume = obj.Volume * 0.5
                        end
                    end)
                    
                    processCount = processCount + 1
                    if processCount % 30 == 0 then
                        RunService.Heartbeat:Wait()
                    end
                end
            end
        end)
        
        pcall(function()
            Workspace.StreamingEnabled = true
            Workspace.StreamingMinRadius = 8
            Workspace.StreamingTargetRadius = 16
        end)
        
        pcall(function()
            for _, effect in pairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") then
                    foliageStates[effect] = { Enabled = effect.Enabled }
                    effect.Enabled = false
                end
            end
        end)
        
        if connections.lowDetailMonitor then
            connections.lowDetailMonitor:Disconnect()
        end
        connections.lowDetailMonitor = RunService.Heartbeat:Connect(function()
            if Visual.lowDetailEnabled then
                pcall(function()
                    local terrain = Workspace.Terrain
                    if terrain.Decoration == true then
                        terrain.Decoration = false
                        print("Re-disabled terrain decorations")
                    end
                end)
            end
        end)
        
    else
        if connections.lowDetailMonitor then
            connections.lowDetailMonitor:Disconnect()
            connections.lowDetailMonitor = nil
        end
        
        if defaultLightingSettings.stored then
            Lighting.GlobalShadows = defaultLightingSettings.GlobalShadows or true
            Lighting.Brightness = defaultLightingSettings.Brightness or 1
            Lighting.FogEnd = defaultLightingSettings.FogEnd or 1000
            Lighting.FogStart = defaultLightingSettings.FogStart or 0
            Lighting.FogColor = defaultLightingSettings.FogColor or Color3.fromRGB(192, 192, 192)
        end
        
        pcall(function()
            local renderSettings = game:GetService("Settings").Rendering
            renderSettings.QualityLevel = defaultLightingSettings.QualityLevel or Enum.QualityLevel.Automatic
        end)
        pcall(function()
            local userSettings = UserSettings()
            local gameSettings = userSettings.GameSettings
            gameSettings.SavedQualityLevel = Enum.SavedQualitySetting.Automatic
            gameSettings.RenderDistance = 500
        end)
        
        if foliageStates.terrainSettings then
            pcall(function()
                local terrain = Workspace.Terrain
                terrain.Decoration = foliageStates.terrainSettings.Decoration
                terrain.WaterWaveSize = foliageStates.terrainSettings.WaterWaveSize
                terrain.WaterWaveSpeed = foliageStates.terrainSettings.WaterWaveSpeed
                terrain.WaterReflectance = foliageStates.terrainSettings.WaterReflectance
                terrain.WaterTransparency = foliageStates.terrainSettings.WaterTransparency
            end)
            foliageStates.terrainSettings = nil
        end
        
        spawn(function()
            local restoreCount = 0
            for obj, state in pairs(foliageStates) do
                if obj ~= "terrainSettings" then
                    pcall(function()
                        if obj and obj.Parent then
                            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or 
                               obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                                obj.Enabled = state.Enabled ~= false
                                
                            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                                obj.Transparency = state.Transparency or 0
                                obj.Texture = state.Texture or ""
                                
                            elseif obj:IsA("SurfaceGui") or obj:IsA("BillboardGui") then
                                obj.Enabled = state.Enabled ~= false
                                
                            elseif obj:IsA("BasePart") then
                                obj.Material = state.Material or Enum.Material.Plastic
                                obj.Reflectance = state.Reflectance or 0
                                obj.CastShadow = state.CastShadow ~= false
                                obj.Color = state.Color or Color3.new(1, 1, 1)
                                if state.Transparency then
                                    obj.Transparency = state.Transparency
                                end
                                if state.CanCollide ~= nil then
                                    obj.CanCollide = state.CanCollide
                                end
                                if state.Anchored ~= nil then
                                    obj.Anchored = state.Anchored
                                end
                                
                            elseif obj:IsA("MeshPart") then
                                obj.TextureID = state.TextureID or ""
                                obj.Material = state.Material or Enum.Material.Plastic
                                obj.Color = state.Color or Color3.new(1, 1, 1)
                                if state.Transparency then
                                    obj.Transparency = state.Transparency
                                end
                                if state.CanCollide ~= nil then
                                    obj.CanCollide = state.CanCollide
                                end
                                if state.Anchored ~= nil then
                                    obj.Anchored = state.Anchored
                                end
                                
                            elseif obj:IsA("SpecialMesh") then
                                obj.TextureId = state.TextureId or ""
                                
                            elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                                obj.Enabled = state.Enabled ~= false
                                obj.Brightness = state.Brightness or 1
                                
                            elseif obj:IsA("Sound") then
                                obj.Volume = state.Volume or 0.5
                                
                            elseif obj:IsA("PostEffect") then
                                obj.Enabled = state.Enabled ~= false
                            end
                        end
                    end)
                    
                    restoreCount = restoreCount + 1
                    if restoreCount % 30 == 0 then
                        RunService.Heartbeat:Wait()
                    end
                end
            end
            foliageStates = {}
            processedObjects = {}
        end)
        
        pcall(function()
            Workspace.StreamingEnabled = defaultLightingSettings.StreamingEnabled or false
            Workspace.StreamingMinRadius = defaultLightingSettings.StreamingMinRadius or 128
            Workspace.StreamingTargetRadius = defaultLightingSettings.StreamingTargetRadius or 256
        end)
    end
end

-- Function to create buttons for Visual features
function Visual.loadVisualButtons(createToggleButton)
    print("Loading visual buttons")
    if not createToggleButton then
        warn("Error: createToggleButton not provided! Buttons will not be created.")
        return
    end
    
    -- Core visual features
    createToggleButton("Freecam", toggleFreecam)
    createToggleButton("Fullbright", toggleFullbright)
    createToggleButton("Flashlight", toggleFlashlight)
    createToggleButton("Low Detail Mode", toggleLowDetail)
    createToggleButton("ESP", toggleESP)
    
    -- New enhanced features
    createToggleButton("Penetration Mode", togglePenetration)
    createToggleButton("Auto-Aim", toggleAutoAim)
    
    -- Time mode features
    createToggleButton("Morning Mode", toggleMorning)
    createToggleButton("Day Mode", toggleDay)
    createToggleButton("Evening Mode", toggleEvening)
    createToggleButton("Night Mode", toggleNight)
end

-- Function to reset Visual states
function Visual.resetStates()
    Visual.freecamEnabled = false
    Visual.fullbrightEnabled = false
    Visual.flashlightEnabled = false
    Visual.lowDetailEnabled = false
    Visual.espEnabled = false
    Visual.penetrationEnabled = false
    Visual.autoAimEnabled = false
    Visual.currentTimeMode = "normal"
    
    if connections.timeModeMonitor then
        connections.timeModeMonitor:Disconnect()
        connections.timeModeMonitor = nil
    end
    if connections.lowDetailMonitor then
        connections.lowDetailMonitor:Disconnect()
        connections.lowDetailMonitor = nil
    end
    
    toggleFreecam(false)
    toggleFullbright(false)
    toggleFlashlight(false)
    toggleLowDetail(false)
    toggleESP(false)
    togglePenetration(false)
    toggleAutoAim(false)
    setTimeMode("normal")
end

-- Function to get freecam state
function Visual.getFreecamState()
    return Visual.freecamEnabled, Visual.freecamPosition
end

-- Function to toggle freecam
function Visual.toggleFreecam(enabled)
    toggleFreecam(enabled)
end

-- Function to set dependencies
function Visual.init(deps)
    print("Initializing Visual module")
    if not deps then
        warn("Error: No dependencies provided!")
        return false
    end
    
    Players = deps.Players
    UserInputService = deps.UserInputService
    RunService = deps.RunService
    Workspace = deps.Workspace
    Lighting = deps.Lighting
    RenderSettings = deps.RenderSettings
    ContextActionService = game:GetService("ContextActionService")
    connections = deps.connections
    buttonStates = deps.buttonStates
    ScrollFrame = deps.ScrollFrame
    ScreenGui = deps.ScreenGui
    settings = deps.settings
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    player = deps.player
    Visual.character = deps.character or (player and player.Character)
    
    -- Initialize states
    Visual.freecamEnabled = false
    Visual.freecamPosition = nil
    Visual.freecamCFrame = nil
    Visual.fullbrightEnabled = false
    Visual.flashlightEnabled = false
    Visual.lowDetailEnabled = false
    Visual.espEnabled = false
    Visual.penetrationEnabled = false
    Visual.autoAimEnabled = false
    Visual.currentTimeMode = "normal"
    Visual.joystickDelta = Vector2.new(0, 0)
    espHighlights = {}
    foliageStates = {}
    processedObjects = {}
    lastAutoAimTarget = nil
    autoAimCooldown = 0
    
    -- Store original lighting settings immediately
    storeOriginalLightingSettings()
    
    -- Create joystick
    createJoystick()
    
    print("Enhanced Visual module initialized successfully with Penetration and Auto-Aim features")
    return true
end

-- Function to update references when character respawns
function Visual.updateReferences(newHumanoid, newRootPart)
    humanoid = newHumanoid
    rootPart = newRootPart
    Visual.character = newHumanoid and newHumanoid.Parent
    
    print("Updating Enhanced Visual module references for respawn")
    
    -- Store current states
    local wasFreecamEnabled = Visual.freecamEnabled
    local wasFullbrightEnabled = Visual.fullbrightEnabled
    local wasFlashlightEnabled = Visual.flashlightEnabled
    local wasLowDetailEnabled = Visual.lowDetailEnabled
    local wasESPEnabled = Visual.espEnabled
    local wasPenetrationEnabled = Visual.penetrationEnabled
    local wasAutoAimEnabled = Visual.autoAimEnabled
    local currentTimeMode = Visual.currentTimeMode
    
    -- Temporarily disable all features
    if wasFreecamEnabled then
        toggleFreecam(false)
    end
    if wasFlashlightEnabled then
        toggleFlashlight(false)
    end
    if wasPenetrationEnabled then
        togglePenetration(false)
    end
    if wasAutoAimEnabled then
        toggleAutoAim(false)
    end
    
    -- Wait a moment for character to fully load
    task.wait(0.5)
    
    -- Re-enable features that were active
    if wasFreecamEnabled then
        print("Re-enabling Freecam after respawn")
        toggleFreecam(true)
    end
    if wasFullbrightEnabled then
        print("Re-enabling Fullbright after respawn")
        toggleFullbright(true)
    end
    if wasFlashlightEnabled then
        print("Re-enabling Flashlight after respawn")
        toggleFlashlight(true)
    end
    if wasLowDetailEnabled then
        print("Re-enabling Low Detail Mode after respawn")
        toggleLowDetail(true)
    end
    if wasESPEnabled then
        print("Re-enabling ESP after respawn")
        toggleESP(true)
    end
    if wasPenetrationEnabled then
        print("Re-enabling Penetration Mode after respawn")
        togglePenetration(true)
    end
    if wasAutoAimEnabled then
        print("Re-enabling Auto-Aim after respawn")
        toggleAutoAim(true)
    end
    if currentTimeMode and currentTimeMode ~= "normal" then
        print("Re-enabling Time Mode after respawn:", currentTimeMode)
        setTimeMode(currentTimeMode)
    end
end

return Visual