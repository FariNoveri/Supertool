
-- Visual-related features for MinimalHackGUI by Fari Noveri, including ESP, Freecam, Fullbright, Flashlight, Time Modes, and Low Detail Mode for mobile

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
Visual.currentTimeMode = "normal" -- normal, morning, day, evening, night
Visual.joystickDelta = Vector2.new(0, 0) -- Global for Freecam movement
Visual.character = nil
local flashlight
local pointLight -- Fallback for broader illumination
local espHighlights = {} -- Store Highlight instances for ESP
local defaultLightingSettings = {} -- Store default lighting settings
local joystickFrame -- Virtual joystick for mobile Freecam
local joystickKnob
local touchStartPos -- Track swipe for rotation
local lastYaw, lastPitch = 0, 0
local foliageStates = {} -- Store original foliage properties for restoration
local processedObjects = {} -- Track processed objects for low detail mode
local freecamSpeed = 50
local cameraSensitivity = 0.003

-- Time mode configurations
local timeModeConfigs = {
    normal = {
        ClockTime = nil, -- Use original
        Brightness = nil, -- Use original
        Ambient = nil, -- Use original
        OutdoorAmbient = nil, -- Use original
        ColorShift_Top = nil, -- Use original
        ColorShift_Bottom = nil, -- Use original
        SunAngularSize = nil, -- Use original
        FogColor = nil -- Use original
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

-- Store original lighting settings (improved)
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
        
        -- Store rendering settings
        pcall(function()
            defaultLightingSettings.QualityLevel = game:GetService("Settings").Rendering.QualityLevel
            defaultLightingSettings.StreamingEnabled = Workspace.StreamingEnabled
            defaultLightingSettings.StreamingMinRadius = Workspace.StreamingMinRadius
            defaultLightingSettings.StreamingTargetRadius = Workspace.StreamingTargetRadius
        end)
        
        print("Original lighting settings stored")
    end
end

-- Create virtual joystick for mobile Freecam (Fixed positioning)
local function createJoystick()
    joystickFrame = Instance.new("Frame")
    joystickFrame.Name = "FreecamJoystick"
    joystickFrame.Size = UDim2.new(0, 120, 0, 120)
    joystickFrame.Position = UDim2.new(0.05, 0, 0.75, 0) -- Bottom left corner
    joystickFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    joystickFrame.BackgroundTransparency = 0.3
    joystickFrame.BorderSizePixel = 0
    joystickFrame.Visible = false
    joystickFrame.ZIndex = 10
    joystickFrame.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = joystickFrame

    -- Add outer ring for better visibility
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
    joystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25) -- Centered
    joystickKnob.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
    joystickKnob.BackgroundTransparency = 0.1
    joystickKnob.BorderSizePixel = 0
    joystickKnob.ZIndex = 11
    joystickKnob.Parent = joystickFrame

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0.5, 0)
    knobCorner.Parent = joystickKnob
    
    -- Add movement instruction text
    local instructionText = Instance.new("TextLabel")
    instructionText.Name = "Instruction"
    instructionText.Size = UDim2.new(0, 200, 0, 30)
    instructionText.Position = UDim2.new(0, 0, 0, -40) -- Above joystick
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

-- Handle joystick input for Freecam movement (Mobile only - Fixed)
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
        
        -- Check if touch is within joystick area
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

-- Handle swipe for Freecam rotation (Mobile only - Fixed for right side)
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
    
    -- Check if touch is within joystick area (ignore swipe if in joystick)
    local isInJoystick = touchPos.X >= frameRect.X and touchPos.X <= frameRect.X + frameRect.Width and
                        touchPos.Y >= frameRect.Y and touchPos.Y <= frameRect.Y + frameRect.Height
    
    if isInJoystick then return end -- Don't handle swipe if touching joystick
    
    -- Only handle swipe on right side of screen (better for right-handed users)
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

-- ESP (Fixed to detect all players including dead/respawning ones)
local function toggleESP(enabled)
    Visual.espEnabled = enabled
    print("ESP:", enabled)
    
    if enabled then
        -- Clean existing highlights first
        for _, highlight in pairs(espHighlights) do
            if highlight and highlight.Parent then
                highlight:Destroy()
            end
        end
        espHighlights = {}
        
        -- Function to create ESP for a character
        local function createESPForCharacter(character, targetPlayer)
            if not character or not character:FindFirstChild("HumanoidRootPart") then return end
            
            local isInvisible = false
            
            -- Check for invisibility
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
            
            -- Remove old highlight if exists
            if espHighlights[targetPlayer] then
                espHighlights[targetPlayer]:Destroy()
                espHighlights[targetPlayer] = nil
            end
            
            local highlight = Instance.new("Highlight")
            highlight.Name = "ESPHighlight"
            highlight.FillColor = isInvisible and Color3.fromRGB(0, 0, 255) or Color3.fromRGB(255, 0, 0)
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
        
        -- Handle new players joining
        if connections.espPlayerAdded then
            connections.espPlayerAdded:Disconnect()
        end
        connections.espPlayerAdded = Players.PlayerAdded:Connect(function(newPlayer)
            if Visual.espEnabled and newPlayer ~= player then
                newPlayer.CharacterAdded:Connect(function(character)
                    task.wait(0.3) -- Longer delay to ensure character is fully loaded
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
        
        -- Handle character respawning for ALL players (including existing ones)
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                -- Disconnect old connections
                if connections["espCharAdded" .. otherPlayer.UserId] then
                    connections["espCharAdded" .. otherPlayer.UserId]:Disconnect()
                end
                if connections["espCharRemoving" .. otherPlayer.UserId] then
                    connections["espCharRemoving" .. otherPlayer.UserId]:Disconnect()
                end
                
                connections["espCharAdded" .. otherPlayer.UserId] = otherPlayer.CharacterAdded:Connect(function(character)
                    task.wait(0.3) -- Longer delay
                    if Visual.espEnabled then
                        createESPForCharacter(character, otherPlayer)
                    end
                end)
                
                -- Also handle character removing (death)
                connections["espCharRemoving" .. otherPlayer.UserId] = otherPlayer.CharacterRemoving:Connect(function()
                    if espHighlights[otherPlayer] then
                        espHighlights[otherPlayer]:Destroy()
                        espHighlights[otherPlayer] = nil
                    end
                end)
            end
        end
        
        -- Continuous check for missed characters (backup system)
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
        -- Clean up ALL connections
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
        
        -- Clean up character connections
        for key, connection in pairs(connections) do
            if string.match(key, "espCharAdded") or string.match(key, "espCharRemoving") then
                connection:Disconnect()
                connections[key] = nil
            end
        end
        
        -- Clean up highlights
        for _, highlight in pairs(espHighlights) do
            if highlight and highlight.Parent then
                highlight:Destroy()
            end
        end
        espHighlights = {}
    end
end

-- Freecam (Fixed - Character stays completely still, camera moves freely)
local function toggleFreecam(enabled)
    Visual.freecamEnabled = enabled
    print("Freecam:", enabled)
    
    if enabled then
        local camera = Workspace.CurrentCamera
        
        -- Get current character and humanoid references
        local currentCharacter = player.Character
        local currentHumanoid = currentCharacter and currentCharacter:FindFirstChild("Humanoid")
        local currentRootPart = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
        
        if not currentHumanoid or not currentRootPart then
            print("Warning: No character found for freecam")
            Visual.freecamEnabled = false
            return
        end
        
        -- Store original character position and completely freeze it
        Visual.originalWalkSpeed = currentHumanoid.WalkSpeed
        Visual.originalJumpPower = currentHumanoid.JumpPower
        Visual.originalJumpHeight = currentHumanoid.JumpHeight
        Visual.originalPosition = currentRootPart.CFrame
        
        -- Completely disable character movement
        currentHumanoid.PlatformStand = true
        currentHumanoid.WalkSpeed = 0
        currentHumanoid.JumpPower = 0
        currentHumanoid.JumpHeight = 0
        currentRootPart.Anchored = true
        currentRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        currentRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        
        -- Setup camera for free flight
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CameraSubject = nil
        
        -- Initialize freecam position and rotation
        Visual.freecamCFrame = camera.CFrame
        Visual.freecamPosition = camera.CFrame.Position
        
        -- Extract initial rotation from camera
        local _, yaw, pitch = camera.CFrame:ToEulerAnglesYXZ()
        lastYaw = yaw
        lastPitch = pitch
        
        -- Get speed from settings
        freecamSpeed = (settings.FreecamSpeed and settings.FreecamSpeed.value) or 50
        
        -- Show mobile controls
        if joystickFrame then
            joystickFrame.Visible = true
        end
        
        -- Main freecam update loop
        if connections.freecam then
            connections.freecam:Disconnect()
        end
        connections.freecam = RunService.RenderStepped:Connect(function(deltaTime)
            if Visual.freecamEnabled then
                -- Get current character references
                local char = player.Character
                local hum = char and char:FindFirstChild("Humanoid")
                local root = char and char:FindFirstChild("HumanoidRootPart")
                
                local moveVector = Vector3.new()
                
                -- Calculate movement based on camera direction
                local cameraCFrame = CFrame.new(Visual.freecamPosition) * CFrame.Angles(lastPitch, lastYaw, 0)
                
                -- Apply joystick movement (WASD-like controls)
                if Visual.joystickDelta.Magnitude > 0.1 then
                    local forward = -cameraCFrame.LookVector * Visual.joystickDelta.Y
                    local right = cameraCFrame.RightVector * Visual.joystickDelta.X
                    moveVector = (forward + right) * freecamSpeed * deltaTime * Visual.joystickDelta.Magnitude
                end
                
                -- Update position
                Visual.freecamPosition = Visual.freecamPosition + moveVector
                
                -- Apply final camera transform
                Visual.freecamCFrame = CFrame.new(Visual.freecamPosition) * CFrame.Angles(lastPitch, lastYaw, 0)
                camera.CFrame = Visual.freecamCFrame
                
                -- Ensure character stays completely frozen (use current character)
                if hum and root and Visual.originalPosition then
                    hum.PlatformStand = true
                    hum.WalkSpeed = 0
                    hum.JumpPower = 0
                    hum.JumpHeight = 0
                    root.Anchored = true
                    root.CFrame = Visual.originalPosition -- Force position back
                    root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
            end
        end)
        
        -- Mobile touch controls
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
        -- Cleanup connections
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
        
        -- Hide mobile controls
        if joystickFrame then
            joystickFrame.Visible = false
            joystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
        end
        
        -- Reset camera to normal
        local camera = Workspace.CurrentCamera
        camera.CameraType = Enum.CameraType.Custom
        
        -- Get current character references
        local currentCharacter = player.Character
        local currentHumanoid = currentCharacter and currentCharacter:FindFirstChild("Humanoid")
        local currentRootPart = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
        
        if currentHumanoid then
            camera.CameraSubject = currentHumanoid
        end
        
        -- Restore character movement
        if currentHumanoid and currentRootPart then
            currentHumanoid.PlatformStand = false
            currentRootPart.Anchored = false
            
            -- Restore original stats
            currentHumanoid.WalkSpeed = Visual.originalWalkSpeed or (settings.WalkSpeed and settings.WalkSpeed.value) or 16
            currentHumanoid.JumpPower = Visual.originalJumpPower or ((settings.JumpHeight and settings.JumpHeight.value * 2.4) or 50)
            currentHumanoid.JumpHeight = Visual.originalJumpHeight or (settings.JumpHeight and settings.JumpHeight.value) or 7.2
            
            -- Reset camera position relative to character
            task.wait(0.1)
            camera.CFrame = CFrame.lookAt(currentRootPart.Position + Vector3.new(0, 2, 10), currentRootPart.Position)
        end
        
        -- Reset freecam variables
        Visual.freecamPosition = nil
        Visual.freecamCFrame = nil
        Visual.joystickDelta = Vector2.new(0, 0)
        lastYaw, lastPitch = 0, 0
        touchStartPos = nil
    end
end

-- Time Mode Functions (Enhanced with persistence)
local function setTimeMode(mode)
    storeOriginalLightingSettings()
    Visual.currentTimeMode = mode
    print("Time Mode:", mode)
    
    local config = timeModeConfigs[mode]
    if not config then
        print("Invalid time mode:", mode)
        return
    end
    
    -- Apply settings
    for property, value in pairs(config) do
        if value ~= nil then
            pcall(function()
                Lighting[property] = value
            end)
        else
            -- Restore original value
            if defaultLightingSettings[property] ~= nil then
                pcall(function()
                    Lighting[property] = defaultLightingSettings[property]
                end)
            end
        end
    end
    
    -- Add persistent monitoring to prevent override
    if connections.timeModeMonitor then
        connections.timeModeMonitor:Disconnect()
    end
    
    if mode ~= "normal" then
        connections.timeModeMonitor = RunService.Heartbeat:Connect(function()
            if Visual.currentTimeMode == mode then
                -- Check if settings were overridden and restore them
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

-- Fullbright (Same as before)
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

-- Flashlight (Completely Fixed - Enhanced)
local function toggleFlashlight(enabled)
    Visual.flashlightEnabled = enabled
    print("Flashlight:", enabled)
    
    if enabled then
        -- Function to create/setup flashlight
        local function setupFlashlight()
            -- Clean up existing lights
            if flashlight then
                flashlight:Destroy()
                flashlight = nil
            end
            if pointLight then
                pointLight:Destroy()
                pointLight = nil
            end
            
            -- Create new flashlight (SpotLight)
            flashlight = Instance.new("SpotLight")
            flashlight.Name = "Flashlight"
            flashlight.Brightness = 20
            flashlight.Range = 150
            flashlight.Angle = 45
            flashlight.Face = Enum.NormalId.Front
            flashlight.Color = Color3.fromRGB(255, 255, 200)
            flashlight.Enabled = true
            
            -- Create PointLight for broader illumination
            pointLight = Instance.new("PointLight")
            pointLight.Name = "FlashlightPoint"
            pointLight.Brightness = 8
            pointLight.Range = 80
            pointLight.Color = Color3.fromRGB(255, 255, 200)
            pointLight.Enabled = true
            
            -- Parent to player's head
            local character = player.Character
            local head = character and character:FindFirstChild("Head")
            
            if head then
                flashlight.Parent = head
                pointLight.Parent = head
                print("Flashlight attached to head")
            else
                -- Fallback to camera
                local camera = Workspace.CurrentCamera
                flashlight.Parent = camera
                pointLight.Parent = camera
                print("Flashlight attached to camera (fallback)")
            end
        end
        
        -- Setup flashlight initially
        setupFlashlight()
        
        -- Update flashlight direction and ensure it stays attached
        if connections.flashlight then
            connections.flashlight:Disconnect()
        end
        connections.flashlight = RunService.Heartbeat:Connect(function()
            if Visual.flashlightEnabled then
                local character = player.Character
                local head = character and character:FindFirstChild("Head")
                local camera = Workspace.CurrentCamera
                
                -- Re-create flashlight if missing
                if not flashlight or not flashlight.Parent then
                    setupFlashlight()
                end
                
                -- Ensure proper parenting
                if head and (not flashlight.Parent or flashlight.Parent ~= head) then
                    flashlight.Parent = head
                    pointLight.Parent = head
                elseif not head and (not flashlight.Parent or flashlight.Parent ~= camera) then
                    flashlight.Parent = camera
                    pointLight.Parent = camera
                end
                
                -- Ensure lights are enabled
                if flashlight then
                    flashlight.Enabled = true
                end
                if pointLight then
                    pointLight.Enabled = true
                end
                
                -- Update light direction to follow camera
                pcall(function()
                    if head and flashlight.Parent == head then
                        -- Align head to camera direction for better flashlight
                        local cameraDirection = camera.CFrame.LookVector
                        head.CFrame = CFrame.lookAt(head.Position, head.Position + cameraDirection)
                    end
                end)
            end
        end)
        
        -- Handle character respawning
        if connections.flashlightCharAdded then
            connections.flashlightCharAdded:Disconnect()
        end
        if player then
            connections.flashlightCharAdded = player.CharacterAdded:Connect(function()
                if Visual.flashlightEnabled then
                    task.wait(1) -- Wait for character to fully load
                    setupFlashlight()
                end
            end)
        end
        
    else
        -- Clean up connections
        if connections.flashlight then
            connections.flashlight:Disconnect()
            connections.flashlight = nil
        end
        if connections.flashlightCharAdded then
            connections.flashlightCharAdded:Disconnect()
            connections.flashlightCharAdded = nil
        end
        
        -- Clean up lights
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

-- Low Detail Mode (Enhanced - Better optimization with proper grass removal)
local function toggleLowDetail(enabled)
    Visual.lowDetailEnabled = enabled
    print("Low Detail Mode:", enabled)
    
    storeOriginalLightingSettings()
    
    if enabled then
        -- Apply lighting changes for performance
        Lighting.GlobalShadows = false
        Lighting.Brightness = 0.3
        Lighting.FogEnd = 200
        Lighting.FogStart = 0
        Lighting.FogColor = Color3.fromRGB(80, 80, 80)
        
        -- Set rendering quality to lowest
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
        
        -- Enhanced terrain processing with proper grass/decoration removal
        pcall(function()
            local terrain = Workspace.Terrain
            -- Store original terrain settings
            if not foliageStates.terrainSettings then
                foliageStates.terrainSettings = {
                    Decoration = terrain.Decoration,
                    WaterWaveSize = terrain.WaterWaveSize,
                    WaterWaveSpeed = terrain.WaterWaveSpeed,
                    WaterReflectance = terrain.WaterReflectance,
                    WaterTransparency = terrain.WaterTransparency
                }
            end
            
            -- Apply low detail terrain settings
            terrain.Decoration = false -- This removes grass/decorations
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 0.9
            
            -- Force remove terrain decorations more aggressively
            spawn(function()
                pcall(function()
                    local success = pcall(function()
                        terrain:ReadVoxels(workspace.CurrentCamera.CFrame.Position - Vector3.new(100, 100, 100), Vector3.new(200, 200, 200))
                    end)
                    if success then
                        terrain.Decoration = false -- Re-apply to ensure it sticks
                    end
                end)
            end)
            
            print("Terrain decorations (grass) disabled")
        end)
        
        -- Process objects more aggressively for low detail
        spawn(function()
            local processCount = 0
            local pixelMaterial = Enum.Material.SmoothPlastic
            
            for _, obj in pairs(Workspace:GetDescendants()) do
                if not processedObjects[obj] then
                    processedObjects[obj] = true
                    
                    pcall(function()
                        -- Enhanced grass/foliage detection
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
                                obj.Transparency = 1 -- Hide foliage completely
                                obj.CanCollide = false -- Remove collision for performance
                                obj.Anchored = true -- Prevent physics calculations
                            else
                                -- Make regular parts pixelated/low detail
                                foliageStates[obj] = { 
                                    Material = obj.Material, 
                                    Reflectance = obj.Reflectance, 
                                    CastShadow = obj.CastShadow,
                                    Color = obj.Color
                                }
                                obj.Material = pixelMaterial
                                obj.Reflectance = 0
                                obj.CastShadow = false
                                -- Simplify colors to make it more pixelated
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
                                obj.Transparency = 1 -- Hide foliage
                                obj.TextureID = ""
                                obj.CanCollide = false
                                obj.Anchored = true
                            else
                                foliageStates[obj] = { 
                                    TextureID = obj.TextureID, 
                                    Material = obj.Material,
                                    Color = obj.Color
                                }
                                obj.TextureID = "" -- Remove detailed textures
                                obj.Material = pixelMaterial
                                -- Pixelate colors
                                local r = math.floor(obj.Color.R * 4) / 4
                                local g = math.floor(obj.Color.G * 4) / 4
                                local b = math.floor(obj.Color.B * 4) / 4
                                obj.Color = Color3.new(r, g, b)
                            end
                            
                        elseif obj:IsA("SpecialMesh") then
                            foliageStates[obj] = { TextureId = obj.TextureId }
                            obj.TextureId = "" -- Remove mesh textures
                            
                        elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                            -- Keep essential lights but reduce their intensity
                            if not (obj.Name == "Flashlight" or obj.Name == "FlashlightPoint") then
                                foliageStates[obj] = { Enabled = obj.Enabled, Brightness = obj.Brightness }
                                obj.Brightness = obj.Brightness * 0.3
                            end
                            
                        elseif obj:IsA("Sound") then
                            -- Reduce sound quality for performance
                            foliageStates[obj] = { Volume = obj.Volume }
                            obj.Volume = obj.Volume * 0.5
                        end
                    end)
                    
                    processCount = processCount + 1
                    -- Yield every 30 objects to prevent lag
                    if processCount % 30 == 0 then
                        RunService.Heartbeat:Wait()
                    end
                end
            end
        end)
        
        -- Enhanced streaming settings for better performance
        pcall(function()
            Workspace.StreamingEnabled = true
            Workspace.StreamingMinRadius = 8
            Workspace.StreamingTargetRadius = 16
        end)
        
        -- Disable post-processing effects
        pcall(function()
            for _, effect in pairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") then
                    foliageStates[effect] = { Enabled = effect.Enabled }
                    effect.Enabled = false
                end
            end
        end)
        
        -- Add persistent monitoring for terrain decorations
        if connections.lowDetailMonitor then
            connections.lowDetailMonitor:Disconnect()
        end
        connections.lowDetailMonitor = RunService.Heartbeat:Connect(function()
            if Visual.lowDetailEnabled then
                pcall(function()
                    local terrain = Workspace.Terrain
                    if terrain.Decoration == true then
                        terrain.Decoration = false -- Force disable grass
                        print("Re-disabled terrain decorations")
                    end
                end)
            end
        end)
        
    else
        -- Stop monitoring
        if connections.lowDetailMonitor then
            connections.lowDetailMonitor:Disconnect()
            connections.lowDetailMonitor = nil
        end
        
        -- Restore all settings efficiently
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
        
        -- Restore terrain settings
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
        
        -- Restore objects efficiently
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
                    -- Yield every 30 objects to prevent lag
                    if restoreCount % 30 == 0 then
                        RunService.Heartbeat:Wait()
                    end
                end
            end
            foliageStates = {} -- Clear after restoring
            processedObjects = {} -- Clear processed objects
        end)
        
        -- Restore streaming
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
    Visual.currentTimeMode = "normal"
    
    -- Disconnect monitoring connections
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
    setTimeMode("normal")
end

-- Function to get freecam state (for teleport.lua)
function Visual.getFreecamState()
    return Visual.freecamEnabled, Visual.freecamPosition
end

-- Function to toggle freecam (for teleport.lua)
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
    Visual.currentTimeMode = "normal"
    Visual.joystickDelta = Vector2.new(0, 0)
    espHighlights = {}
    foliageStates = {}
    processedObjects = {}
    
    -- Store original lighting settings immediately
    storeOriginalLightingSettings()
    
    -- Create joystick
    createJoystick()
    
    print("Visual module initialized successfully")
    return true
end

-- Function to update references when character respawns (Enhanced)
function Visual.updateReferences(newHumanoid, newRootPart)
    humanoid = newHumanoid
    rootPart = newRootPart
    Visual.character = newHumanoid and newHumanoid.Parent
    
    print("Updating Visual module references for respawn")
    
    -- Store current states
    local wasFreecamEnabled = Visual.freecamEnabled
    local wasFullbrightEnabled = Visual.fullbrightEnabled
    local wasFlashlightEnabled = Visual.flashlightEnabled
    local wasLowDetailEnabled = Visual.lowDetailEnabled
    local wasESPEnabled = Visual.espEnabled
    local currentTimeMode = Visual.currentTimeMode
    
    -- Temporarily disable all features
    if wasFreecamEnabled then
        toggleFreecam(false)
    end
    if wasFlashlightEnabled then
        toggleFlashlight(false)
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
    if currentTimeMode and currentTimeMode ~= "normal" then
        print("Re-enabling Time Mode after respawn:", currentTimeMode)
        setTimeMode(currentTimeMode)
    end
end

return Visual