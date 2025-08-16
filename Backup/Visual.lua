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

-- Create virtual joystick for mobile Freecam (Fixed positioning)
local function createJoystick()
    joystickFrame = Instance.new("Frame")
    joystickFrame.Name = "FreecamJoystick"
    joystickFrame.Size = UDim2.new(0, 120, 0, 120) -- Slightly bigger for easier use
    joystickFrame.Position = UDim2.new(0.05, 0, 0.75, 0) -- Bottom left corner
    joystickFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    joystickFrame.BackgroundTransparency = 0.3 -- More visible
    joystickFrame.BorderSizePixel = 0
    joystickFrame.Visible = false
    joystickFrame.ZIndex = 10 -- Ensure it's on top
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
    joystickKnob.Size = UDim2.new(0, 50, 0, 50) -- Bigger knob
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
    instructionText.Text = "Move: Joystick | Look: Swipe screen"
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
            -- Start joystick control
            local delta = Vector2.new(touchPos.X - joystickCenter.X, touchPos.Y - joystickCenter.Y)
            local magnitude = delta.Magnitude
            local maxRadius = 35 -- Adjusted for bigger joystick
            if magnitude > maxRadius then
                delta = delta * (maxRadius / magnitude)
            end
            joystickKnob.Position = UDim2.new(0.5, delta.X - 25, 0.5, delta.Y - 25) -- Adjusted for bigger knob
            return delta / maxRadius
            
        elseif input.UserInputState == Enum.UserInputState.Change and isInJoystick then
            -- Update joystick
            local delta = Vector2.new(touchPos.X - joystickCenter.X, touchPos.Y - joystickCenter.Y)
            local magnitude = delta.Magnitude
            local maxRadius = 35 -- Adjusted for bigger joystick
            if magnitude > maxRadius then
                delta = delta * (maxRadius / magnitude)
            end
            joystickKnob.Position = UDim2.new(0.5, delta.X - 25, 0.5, delta.Y - 25) -- Adjusted for bigger knob
            return delta / maxRadius
            
        elseif input.UserInputState == Enum.UserInputState.End then
            -- Reset joystick
            joystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25) -- Adjusted for bigger knob
            return Vector2.new(0, 0)
        end
    end
    return Vector2.new(0, 0)
end

-- Handle swipe for Freecam rotation (Mobile only)
local function handleSwipe(input, processed)
    if not Visual.freecamEnabled or input.UserInputType ~= Enum.UserInputType.Touch or processed then return end
    
    local touchPos = input.Position
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
    
    if input.UserInputState == Enum.UserInputState.Begin then
        touchStartPos = touchPos
    elseif input.UserInputState == Enum.UserInputState.Change and touchStartPos then
        local delta = touchPos - touchStartPos
        local sensitivity = 0.005 -- Lower sensitivity for smoother control
        lastYaw = lastYaw - delta.X * sensitivity
        lastPitch = math.clamp(lastPitch - delta.Y * sensitivity, -math.rad(89), math.rad(89))
        touchStartPos = touchPos
    elseif input.UserInputState == Enum.UserInputState.End then
        touchStartPos = nil
    end
end

-- ESP (Optimized - No more lag!)
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
        
        -- Create highlights for existing players (one-time creation)
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local character = otherPlayer.Character
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
                
                local highlight = Instance.new("Highlight")
                highlight.Name = "ESPHighlight"
                highlight.FillColor = isInvisible and Color3.fromRGB(0, 0, 255) or Color3.fromRGB(255, 0, 0)
                highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                highlight.FillTransparency = isInvisible and 0.3 or 0.5
                highlight.OutlineTransparency = 0
                highlight.Adornee = character
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.Parent = character
                espHighlights[otherPlayer] = highlight
            end
        end
        
        -- Handle new players joining
        connections.espPlayerAdded = Players.PlayerAdded:Connect(function(newPlayer)
            if Visual.espEnabled and newPlayer ~= player then
                newPlayer.CharacterAdded:Connect(function(character)
                    wait(0.1) -- Small delay to ensure character is fully loaded
                    if Visual.espEnabled and character:FindFirstChild("HumanoidRootPart") then
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
                        
                        -- Remove old highlight if exists
                        if espHighlights[newPlayer] then
                            espHighlights[newPlayer]:Destroy()
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
                        espHighlights[newPlayer] = highlight
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
        
        -- Handle character respawning for existing players
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                connections["espCharAdded" .. otherPlayer.UserId] = otherPlayer.CharacterAdded:Connect(function(character)
                    wait(0.1)
                    if Visual.espEnabled and character:FindFirstChild("HumanoidRootPart") then
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
                        
                        -- Remove old highlight if exists
                        if espHighlights[otherPlayer] then
                            espHighlights[otherPlayer]:Destroy()
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
                        espHighlights[otherPlayer] = highlight
                    end
                end)
            end
        end
    else
        -- Clean up connections
        if connections.espPlayerLeaving then
            connections.espPlayerLeaving:Disconnect()
            connections.espPlayerLeaving = nil
        end
        if connections.espPlayerAdded then
            connections.espPlayerAdded:Disconnect()
            connections.espPlayerAdded = nil
        end
        
        -- Clean up character added connections
        for key, connection in pairs(connections) do
            if string.match(key, "espCharAdded") then
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

-- Freecam (Android Spectator Mode - Character stays still, camera flies free)
local function toggleFreecam(enabled)
    Visual.freecamEnabled = enabled
    print("Freecam:", enabled)
    
    if enabled then
        -- Freeze character completely
        if humanoid then
            humanoid.PlatformStand = true -- Prevents character from moving
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
            humanoid.JumpHeight = 0
            if rootPart then
                rootPart.Anchored = true -- Anchor the character in place
                rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0) -- Stop all movement
                rootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0) -- Stop all rotation
            end
        end
        
        -- Setup camera for free flight
        local camera = Workspace.CurrentCamera
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CameraSubject = nil -- Detach from character completely
        
        -- Initialize freecam position from current camera
        Visual.freecamCFrame = camera.CFrame
        Visual.freecamPosition = camera.CFrame.Position
        lastYaw, lastPitch = 0, 0
        
        -- Show mobile controls
        joystickFrame.Visible = true
        
        -- Main freecam update loop
        connections.freecam = RunService.RenderStepped:Connect(function(deltaTime)
            if Visual.freecamEnabled then
                local camera = Workspace.CurrentCamera
                local moveVector = Vector3.new()
                local speed = settings.FreecamSpeed and settings.FreecamSpeed.value or 50
                
                -- Calculate movement based on current camera rotation
                local currentCFrame = CFrame.new(Visual.freecamPosition) * CFrame.Angles(lastPitch, lastYaw, 0)
                
                -- Apply joystick movement (WASD-like controls)
                if Visual.joystickDelta.Magnitude > 0.1 then
                    local forward = -currentCFrame.LookVector * Visual.joystickDelta.Y
                    local right = currentCFrame.RightVector * Visual.joystickDelta.X
                    moveVector = (forward + right).Unit * speed * deltaTime * Visual.joystickDelta.Magnitude
                end
                
                -- Update position
                Visual.freecamPosition = Visual.freecamPosition + moveVector
                
                -- Apply final camera transform
                Visual.freecamCFrame = CFrame.new(Visual.freecamPosition) * CFrame.Angles(lastPitch, lastYaw, 0)
                camera.CFrame = Visual.freecamCFrame
                
                -- Keep character frozen in place
                if humanoid and rootPart then
                    humanoid.PlatformStand = true
                    rootPart.Anchored = true
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
        joystickFrame.Visible = false
        joystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25) -- Adjusted for bigger knob
        
        -- Reset camera to normal
        local camera = Workspace.CurrentCamera
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = humanoid
        
        -- Unfreeze character
        if humanoid and rootPart then
            humanoid.PlatformStand = false
            rootPart.Anchored = false
            humanoid.WalkSpeed = settings.WalkSpeed and settings.WalkSpeed.value or 16
            humanoid.JumpPower = (settings.JumpHeight and settings.JumpHeight.value * 2.4) or 50
            humanoid.JumpHeight = settings.JumpHeight and settings.JumpHeight.value or 7.2
            
            -- Reset camera position relative to character
            wait(0.1) -- Small delay to ensure character is unfrozen
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

-- Fullbright
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

-- Flashlight (Fixed)
local function toggleFlashlight(enabled)
    Visual.flashlightEnabled = enabled
    print("Flashlight:", enabled)
    
    if enabled then
        -- Create or reuse flashlight (SpotLight)
        if not flashlight then
            flashlight = Instance.new("SpotLight")
            flashlight.Name = "Flashlight"
            flashlight.Brightness = 15
            flashlight.Range = 100
            flashlight.Angle = 30
            flashlight.Face = Enum.NormalId.Front
            flashlight.Enabled = true
        end
        
        -- Create or reuse PointLight for broader illumination
        if not pointLight then
            pointLight = Instance.new("PointLight")
            pointLight.Name = "FlashlightPoint"
            pointLight.Brightness = 5
            pointLight.Range = 50
            pointLight.Enabled = true
        end
        
        -- Parent to player's head if available, else camera
        pcall(function()
            local head = Visual.character and Visual.character:FindFirstChild("Head")
            if head then
                flashlight.Parent = head
                pointLight.Parent = head
            else
                flashlight.Parent = Workspace.CurrentCamera
                pointLight.Parent = Workspace.CurrentCamera
            end
        end)
        
        -- Update flashlight direction
        connections.flashlight = RunService.RenderStepped:Connect(function()
            if Visual.flashlightEnabled and flashlight and flashlight.Parent then
                pcall(function()
                    local camera = Workspace.CurrentCamera
                    local head = Visual.character and Visual.character:FindFirstChild("Head")
                    local parent = head or camera
                    if parent then
                        -- Ensure lights are parented correctly
                        if flashlight.Parent ~= parent then
                            flashlight.Parent = parent
                        end
                        if pointLight.Parent ~= parent then
                            pointLight.Parent = parent
                        end
                        -- Align with camera or head direction
                        local cframe = parent:IsA("Camera") and camera.CFrame or CFrame.new(head.Position, head.Position + head.CFrame.LookVector)
                        flashlight.CFrame = cframe * CFrame.new(0, 0, -0.5)
                        pointLight.CFrame = cframe
                        flashlight.Enabled = true
                        pointLight.Enabled = true
                    else
                        flashlight.Enabled = false
                        pointLight.Enabled = false
                        warn("Flashlight parent (head or camera) not found!")
                    end
                end)
            elseif flashlight then
                flashlight.Enabled = false
                pointLight.Enabled = false
            end
        end)
    else
        -- Clean up
        if connections.flashlight then
            connections.flashlight:Disconnect()
            connections.flashlight = nil
        end
        if flashlight then
            flashlight.Enabled = false
            flashlight:Destroy()
            flashlight = nil
        end
        if pointLight then
            pointLight.Enabled = false
            pointLight:Destroy()
            pointLight = nil
        end
    end
end

-- Low Detail Mode (Optimized - No more lag!)
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
        
        -- Apply lighting changes (fast)
        Lighting.GlobalShadows = false
        Lighting.Brightness = 0.5
        Lighting.FogEnd = 300
        Lighting.FogStart = 0
        Lighting.FogColor = Color3.fromRGB(100, 100, 100)
        
        -- Set rendering quality (fast)
        pcall(function()
            local renderSettings = game:GetService("Settings").Rendering
            renderSettings.QualityLevel = Enum.QualityLevel.Level01
        end)
        pcall(function()
            local userSettings = UserSettings()
            local gameSettings = userSettings.GameSettings
            gameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
            gameSettings.RenderDistance = 100
        end)
        
        -- Process objects efficiently (avoid lag)
        spawn(function()
            local processCount = 0
            for _, obj in pairs(Workspace:GetDescendants()) do
                if not processedObjects[obj] then
                    processedObjects[obj] = true
                    
                    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or 
                       obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                        foliageStates[obj] = { Enabled = obj.Enabled }
                        obj.Enabled = false
                    elseif obj:IsA("Decal") or obj:IsA("Texture") then
                        foliageStates[obj] = { Transparency = obj.Transparency }
                        obj.Transparency = 1
                    elseif obj:IsA("BasePart") then
                        local isFoliage = obj.Name:lower():find("leaf") or obj.Name:lower():find("leaves") or 
                                          obj.Name:lower():find("foliage") or obj.Name:lower():find("grass") or
                                          obj:GetAttribute("IsFoliage")
                        if isFoliage then
                            foliageStates[obj] = { Transparency = obj.Transparency }
                            obj.Transparency = 1
                        else
                            foliageStates[obj] = { Material = obj.Material, Reflectance = obj.Reflectance, CastShadow = obj.CastShadow }
                            obj.Material = Enum.Material.SmoothPlastic
                            obj.Reflectance = 0
                            obj.CastShadow = false
                        end
                    elseif obj:IsA("MeshPart") then
                        local isFoliage = obj.Name:lower():find("leaf") or obj.Name:lower():find("leaves") or 
                                          obj.Name:lower():find("foliage") or obj:GetAttribute("IsFoliage")
                        if isFoliage then
                            foliageStates[obj] = { Transparency = obj.Transparency }
                            obj.Transparency = 1
                        else
                            foliageStates[obj] = { TextureID = obj.TextureID, Material = obj.Material }
                            obj.TextureID = ""
                            obj.Material = Enum.Material.SmoothPlastic
                        end
                    elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                        foliageStates[obj] = { Enabled = obj.Enabled }
                        obj.Enabled = false
                    end
                    
                    processCount = processCount + 1
                    -- Yield every 50 objects to prevent lag
                    if processCount % 50 == 0 then
                        RunService.Heartbeat:Wait()
                    end
                end
            end
        end)
        
        -- Streaming settings (fast)
        pcall(function()
            Workspace.StreamingEnabled = true
            Workspace.StreamingMinRadius = 16
            Workspace.StreamingTargetRadius = 32
        end)
        
        -- Terrain changes (fast)
        pcall(function()
            local terrain = Workspace.Terrain
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 0.8
            terrain.Decoration = false -- Remove grass/decorations
        end)
        
        -- Disable post-processing effects (fast)
        pcall(function()
            for _, effect in pairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") then
                    foliageStates[effect] = { Enabled = effect.Enabled }
                    effect.Enabled = false
                end
            end
        end)
        
    else
        -- Restore settings (fast)
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
        
        -- Restore objects (efficiently)
        spawn(function()
            local restoreCount = 0
            for obj, state in pairs(foliageStates) do
                pcall(function()
                    if obj and obj.Parent then
                        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or 
                           obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                            obj.Enabled = state.Enabled or true
                        elseif obj:IsA("Decal") or obj:IsA("Texture") then
                            obj.Transparency = state.Transparency or 0
                        elseif obj:IsA("BasePart") then
                            obj.Material = state.Material or Enum.Material.Plastic
                            obj.Reflectance = state.Reflectance or 0
                            obj.CastShadow = state.CastShadow ~= false
                            if state.Transparency then
                                obj.Transparency = state.Transparency
                            end
                        elseif obj:IsA("MeshPart") then
                            obj.TextureID = state.TextureID or ""
                            obj.Material = state.Material or Enum.Material.Plastic
                            if state.Transparency then
                                obj.Transparency = state.Transparency
                            end
                        elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                            obj.Enabled = state.Enabled ~= false
                        elseif obj:IsA("PostEffect") then
                            obj.Enabled = state.Enabled ~= false
                        end
                    end
                end)
                
                restoreCount = restoreCount + 1
                -- Yield every 50 objects to prevent lag
                if restoreCount % 50 == 0 then
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
    
    if Visual.freecamEnabled then
        toggleFreecam(true)
    end
    if Visual.fullbrightEnabled then
        toggleFullbright(true)
    end
    if Visual.flashlightEnabled then
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