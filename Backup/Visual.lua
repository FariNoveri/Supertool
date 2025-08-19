-- Visual-related features for MinimalHackGUI by Fari Noveri, including ESP, Freecam, Fullbright, Flashlight, and Low Detail Mode for mobile

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
        connections.espPlayerAdded = Players.PlayerAdded:Connect(function(newPlayer)
            if Visual.espEnabled and newPlayer ~= player then
                newPlayer.CharacterAdded:Connect(function(character)
                    wait(0.3) -- Longer delay to ensure character is fully loaded
                    if Visual.espEnabled then
                        createESPForCharacter(character, newPlayer)
                    end
                end)
            end
        end)
        
        -- Handle players leaving
        connections.espPlayerLeaving = Players.PlayerRemoving:Connect(function(leavingPlayer)
            if espHighlights[leavingPlayer] then
                espHighlights[leavingPlayer]:Destroy()
                espHighlights[leavingPlayer] = nil
            end
        end)
        
        -- Handle character respawning for ALL players (including existing ones)
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                connections["espCharAdded" .. otherPlayer.UserId] = otherPlayer.CharacterAdded:Connect(function(character)
                    wait(0.3) -- Longer delay
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
        
        -- Store original character position and completely freeze it
        if humanoid and rootPart then
            Visual.originalWalkSpeed = humanoid.WalkSpeed
            Visual.originalJumpPower = humanoid.JumpPower
            Visual.originalJumpHeight = humanoid.JumpHeight
            Visual.originalPosition = rootPart.CFrame
            
            -- Completely disable character movement
            humanoid.PlatformStand = true
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
            humanoid.JumpHeight = 0
            rootPart.Anchored = true
            rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
        
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
        connections.freecam = RunService.RenderStepped:Connect(function(deltaTime)
            if Visual.freecamEnabled then
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
                
                -- Ensure character stays completely frozen
                if humanoid and rootPart then
                    humanoid.PlatformStand = true
                    humanoid.WalkSpeed = 0
                    humanoid.JumpPower = 0
                    humanoid.JumpHeight = 0
                    rootPart.Anchored = true
                    rootPart.CFrame = Visual.originalPosition -- Force position back
                    rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end
            end
        end)
        
        -- Mobile touch controls
        connections.touchInput = UserInputService.InputChanged:Connect(function(input, processed)
            if input.UserInputType == Enum.UserInputType.Touch then
                Visual.joystickDelta = handleJoystickInput(input, processed)
                handleSwipe(input, processed)
            end
        end)
        
        connections.touchBegan = UserInputService.InputBegan:Connect(function(input, processed)
            if input.UserInputType == Enum.UserInputType.Touch then
                Visual.joystickDelta = handleJoystickInput(input, processed)
                handleSwipe(input, processed)
            end
        end)
        
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
        camera.CameraSubject = humanoid
        
        -- Restore character movement
        if humanoid and rootPart then
            humanoid.PlatformStand = false
            rootPart.Anchored = false
            
            -- Restore original stats
            humanoid.WalkSpeed = Visual.originalWalkSpeed or (settings.WalkSpeed and settings.WalkSpeed.value) or 16
            humanoid.JumpPower = Visual.originalJumpPower or ((settings.JumpHeight and settings.JumpHeight.value * 2.4) or 50)
            humanoid.JumpHeight = Visual.originalJumpHeight or (settings.JumpHeight and settings.JumpHeight.value) or 7.2
            
            -- Reset camera position relative to character
            task.wait(0.1)
            camera.CFrame = CFrame.lookAt(rootPart.Position + Vector3.new(0, 2, 10), rootPart.Position)
        end
        
        -- Reset freecam variables
        Visual.freecamPosition = nil
        Visual.freecamCFrame = nil
        Visual.joystickDelta = Vector2.new(0, 0)
        lastYaw, lastPitch = 0, 0
        touchStartPos = nil
    end
end

-- Fullbright (Same as before)
local function toggleFullbright(enabled)
    Visual.fullbrightEnabled = enabled
    print("Fullbright:", enabled)
    
    if enabled then
        defaultLightingSettings.Brightness = Lighting.Brightness
        defaultLightingSettings.ClockTime = Lighting.ClockTime
        defaultLightingSettings.FogEnd = Lighting.FogEnd
        defaultLightingSettings.GlobalShadows = Lighting.GlobalShadows
        defaultLightingSettings.Ambient = Lighting.Ambient
        
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

-- Flashlight (Completely Fixed)
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
            local character = Visual.character or (player and player.Character)
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
        connections.flashlight = RunService.Heartbeat:Connect(function()
            if Visual.flashlightEnabled then
                local character = Visual.character or (player and player.Character)
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

-- Low Detail Mode (Enhanced - Better optimization)
local function toggleLowDetail(enabled)
    Visual.lowDetailEnabled = enabled
    print("Low Detail Mode:", enabled)
    
    if enabled then
        -- Store default settings (one-time)
        if not defaultLightingSettings.GlobalShadowsStored then
            defaultLightingSettings.GlobalShadowsStored = true
            defaultLightingSettings.GlobalShadows = Lighting.GlobalShadows
            defaultLightingSettings.TerrainDecoration = Workspace.Terrain.Decoration
            pcall(function()
                defaultLightingSettings.QualityLevel = game:GetService("Settings").Rendering.QualityLevel
                defaultLightingSettings.StreamingEnabled = Workspace.StreamingEnabled
                defaultLightingSettings.StreamingMinRadius = Workspace.StreamingMinRadius
                defaultLightingSettings.StreamingTargetRadius = Workspace.StreamingTargetRadius
            end)
        end
        
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
        
        -- Process objects more aggressively for low detail
        spawn(function()
            local processCount = 0
            local pixelMaterial = Enum.Material.SmoothPlastic
            
            for _, obj in pairs(Workspace:GetDescendants()) do
                if not processedObjects[obj] then
                    processedObjects[obj] = true
                    
                    pcall(function()
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
                            -- Check for foliage/nature objects
                            local name = obj.Name:lower()
                            local isFoliage = name:find("leaf") or name:find("leaves") or name:find("foliage") or 
                                              name:find("grass") or name:find("tree") or name:find("plant") or 
                                              name:find("flower") or name:find("bush") or name:find("shrub") or
                                              obj:GetAttribute("IsFoliage") or obj:GetAttribute("IsNature")
                            
                            if isFoliage then
                                foliageStates[obj] = { 
                                    Transparency = obj.Transparency,
                                    Material = obj.Material,
                                    Color = obj.Color,
                                    CanCollide = obj.CanCollide
                                }
                                obj.Transparency = 1 -- Hide foliage completely
                                obj.CanCollide = false -- Remove collision for performance
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
                            local name = obj.Name:lower()
                            local isFoliage = name:find("leaf") or name:find("leaves") or name:find("foliage") or 
                                              name:find("grass") or name:find("tree") or name:find("plant") or 
                                              name:find("flower") or name:find("bush") or name:find("shrub") or
                                              obj:GetAttribute("IsFoliage") or obj:GetAttribute("IsNature")
                            
                            if isFoliage then
                                foliageStates[obj] = { 
                                    Transparency = obj.Transparency,
                                    TextureID = obj.TextureID,
                                    Material = obj.Material,
                                    CanCollide = obj.CanCollide
                                }
                                obj.Transparency = 1 -- Hide foliage
                                obj.TextureID = ""
                                obj.CanCollide = false
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
                            foliageStates[obj] = { Enabled = obj.Enabled, Brightness = obj.Brightness }
                            obj.Brightness = obj.Brightness * 0.3
                            
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
            
            -- Process terrain more aggressively
            pcall(function()
                local terrain = Workspace.Terrain
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
                terrain.WaterReflectance = 0
                terrain.WaterTransparency = 0.9
                terrain.Decoration = false -- Remove all grass/decorations
                
                -- Reduce terrain quality
                if terrain.ReadVoxels then
                    -- Additional terrain optimizations could be added here
                end
            end)
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
        
        -- Disable expensive rendering features
        pcall(function()
            game:GetService("RunService"):Set3dRenderingEnabled(true) -- Keep rendering but optimize
            -- Disable some expensive features
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("Explosion") then
                    obj.Visible = false
                end
            end
        end)
        
    else
        -- Restore all settings efficiently
        Lighting.GlobalShadows = defaultLightingSettings.GlobalShadows or true
        Lighting.Brightness = defaultLightingSettings.Brightness or 1
        Lighting.FogEnd = defaultLightingSettings.FogEnd or 1000
        Lighting.FogStart = 0
        Lighting.FogColor = Color3.fromRGB(192, 192, 192)
        
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
        
        -- Restore objects efficiently
        spawn(function()
            local restoreCount = 0
            for obj, state in pairs(foliageStates) do
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
            foliageStates = {} -- Clear after restoring
            processedObjects = {} -- Clear processed objects
        end)
        
        -- Restore streaming
        pcall(function()
            Workspace.StreamingEnabled = defaultLightingSettings.StreamingEnabled or false
            Workspace.StreamingMinRadius = defaultLightingSettings.StreamingMinRadius or 128
            Workspace.StreamingTargetRadius = defaultLightingSettings.StreamingTargetRadius or 256
        end)
        
        -- Restore terrain
        pcall(function()
            local terrain = Workspace.Terrain
            terrain.WaterWaveSize = 0.15
            terrain.WaterWaveSpeed = 10
            terrain.WaterReflectance = 0.3
            terrain.WaterTransparency = 0.5
            terrain.Decoration = defaultLightingSettings.TerrainDecoration ~= false
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
    createToggleButton("Freecam", toggleFreecam)
    createToggleButton("Fullbright", toggleFullbright)
    createToggleButton("Flashlight", toggleFlashlight)
    createToggleButton("Low Detail Mode", toggleLowDetail)
    createToggleButton("ESP", toggleESP)
end

-- Function to reset Visual states
function Visual.resetStates()
    Visual.freecamEnabled = false
    Visual.fullbrightEnabled = false
    Visual.flashlightEnabled = false
    Visual.lowDetailEnabled = false
    Visual.espEnabled = false
    
    toggleFreecam(false)
    toggleFullbright(false)
    toggleFlashlight(false)
    toggleLowDetail(false)
    toggleESP(false)
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
    
    Visual.freecamEnabled = false
    Visual.freecamPosition = nil
    Visual.freecamCFrame = nil
    Visual.fullbrightEnabled = false
    Visual.flashlightEnabled = false
    Visual.lowDetailEnabled = false
    Visual.espEnabled = false
    Visual.joystickDelta = Vector2.new(0, 0)
    espHighlights = {}
    foliageStates = {}
    processedObjects = {}
    
    defaultLightingSettings.Brightness = Lighting.Brightness
    defaultLightingSettings.ClockTime = Lighting.ClockTime
    defaultLightingSettings.FogEnd = Lighting.FogEnd
    defaultLightingSettings.GlobalShadows = Lighting.GlobalShadows
    defaultLightingSettings.Ambient = Lighting.Ambient
    
    createJoystick()
    
    print("Visual module initialized successfully")
    return true
end

-- Function to update references when character respawns
function Visual.updateReferences(newHumanoid, newRootPart)
    humanoid = newHumanoid
    rootPart = newRootPart
    Visual.character = newHumanoid and newHumanoid.Parent
    
    -- Re-enable features if they were active
    if Visual.freecamEnabled then
        toggleFreecam(false)
        task.wait(0.1)
        toggleFreecam(true)
    end
    if Visual.fullbrightEnabled then
        toggleFullbright(true)
    end
    if Visual.flashlightEnabled then
        toggleFlashlight(false)
        task.wait(0.1)
        toggleFlashlight(true)
    end
    if Visual.lowDetailEnabled then
        toggleLowDetail(true)
    end
    if Visual.espEnabled then
        toggleESP(true)
    end
end

return Visual