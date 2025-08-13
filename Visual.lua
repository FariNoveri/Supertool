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

-- Create virtual joystick for mobile Freecam
local function createJoystick()
    joystickFrame = Instance.new("Frame")
    joystickFrame.Name = "FreecamJoystick"
    joystickFrame.Size = UDim2.new(0, 100, 0, 100)
    joystickFrame.Position = UDim2.new(0.1, 0, 0.7, 0)
    joystickFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    joystickFrame.BackgroundTransparency = 0.5
    joystickFrame.BorderSizePixel = 0
    joystickFrame.Visible = false
    joystickFrame.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = joystickFrame

    joystickKnob = Instance.new("Frame")
    joystickKnob.Name = "Knob"
    joystickKnob.Size = UDim2.new(0, 40, 0, 40)
    joystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
    joystickKnob.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    joystickKnob.BackgroundTransparency = 0.3
    joystickKnob.BorderSizePixel = 0
    joystickKnob.Parent = joystickFrame

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0.5, 0)
    knobCorner.Parent = joystickKnob
end

-- Handle joystick input for Freecam movement
local function handleJoystickInput(input)
    if not Visual.freecamEnabled or not joystickFrame.Visible then return end
    if input.UserInputType == Enum.UserInputType.Touch then
        if input.UserInputState == Enum.UserInputState.Begin then
            joystickFrame.Visible = true
            joystickFrame.Position = UDim2.new(0, input.Position.X - 50, 0, input.Position.Y - 50)
        elseif input.UserInputState == Enum.UserInputState.Change then
            local center = joystickFrame.AbsolutePosition + joystickFrame.AbsoluteSize * 0.5
            local delta = Vector2.new(input.Position.X - center.X, input.Position.Y - center.Y)
            local magnitude = delta.Magnitude
            local maxRadius = 30
            if magnitude > maxRadius then
                delta = delta * (maxRadius / magnitude)
            end
            joystickKnob.Position = UDim2.new(0.5, delta.X - 20, 0.5, delta.Y - 20)
            return delta / maxRadius -- Normalized movement vector
        elseif input.UserInputState == Enum.UserInputState.End then
            joystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
            joystickFrame.Visible = false
            return Vector2.new(0, 0)
        end
    end
    return Vector2.new(0, 0)
end

-- Handle swipe for Freecam rotation
local function handleSwipe(input)
    if not Visual.freecamEnabled or input.UserInputType ~= Enum.UserInputType.Touch then return end
    if input.UserInputState == Enum.UserInputState.Begin then
        touchStartPos = input.Position
    elseif input.UserInputState == Enum.UserInputState.Change and touchStartPos then
        local delta = input.Position - touchStartPos
        lastYaw = lastYaw - math.rad(delta.X * 0.1)
        lastPitch = math.clamp(lastPitch - math.rad(delta.Y * 0.1), -math.rad(89), math.rad(89))
        touchStartPos = input.Position
    elseif input.UserInputState == Enum.UserInputState.End then
        touchStartPos = nil
    end
end

-- ESP (Wallhack with Invisible Player Detection)
local function toggleESP(enabled)
    Visual.espEnabled = enabled
    print("ESP:", enabled)
    
    if enabled then
        connections.esp = RunService.RenderStepped:Connect(function()
            if Visual.espEnabled then
                for _, otherPlayer in pairs(Players:GetPlayers()) do
                    if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local character = otherPlayer.Character
                        local isInvisible = false
                        
                        -- Check for invisibility (transparent parts or custom attributes)
                        pcall(function()
                            for _, part in pairs(character:GetDescendants()) do
                                if part:IsA("BasePart") and part.Transparency >= 0.9 then
                                    isInvisible = true
                                    break
                                end
                            end
                            -- Check for custom invisibility attributes (game-specific)
                            if character:GetAttribute("IsInvisible") or character:GetAttribute("AdminInvisible") then
                                isInvisible = true
                            end
                        end)
                        
                        if not espHighlights[otherPlayer] then
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
                end
            end
        end)
        
        connections.espPlayerLeaving = Players.PlayerRemoving:Connect(function(leavingPlayer)
            if espHighlights[leavingPlayer] then
                espHighlights[leavingPlayer]:Destroy()
                espHighlights[leavingPlayer] = nil
            end
        end)
        
        connections.espPlayerAdded = Players.PlayerAdded:Connect(function(newPlayer)
            if Visual.espEnabled and newPlayer ~= player then
                newPlayer.CharacterAdded:Connect(function(character)
                    if Visual.espEnabled then
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
    else
        if connections.esp then
            connections.esp:Disconnect()
            connections.esp = nil
        end
        if connections.espPlayerLeaving then
            connections.espPlayerLeaving:Disconnect()
            connections.espPlayerLeaving = nil
        end
        if connections.espPlayerAdded then
            connections.espPlayerAdded:Disconnect()
            connections.espPlayerAdded = nil
        end
        for _, highlight in pairs(espHighlights) do
            highlight:Destroy()
        end
        espHighlights = {}
    end
end

-- Freecam (Mobile)
local function toggleFreecam(enabled)
    Visual.freecamEnabled = enabled
    print("Freecam:", enabled)
    
    if enabled then
        if humanoid then
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
        end
        local camera = Workspace.CurrentCamera
        Visual.freecamCFrame = camera.CFrame
        Visual.freecamPosition = camera.CFrame.Position
        camera.CameraType = Enum.CameraType.Scriptable
        joystickFrame.Visible = true
        
        connections.freecam = RunService.RenderStepped:Connect(function(deltaTime)
            if Visual.freecamEnabled then
                local moveVector = Vector3.new()
                local speed = settings.FreecamSpeed and settings.FreecamSpeed.value or 50
                local cameraCFrame = Visual.freecamCFrame
                
                -- Apply joystick movement
                if joystickFrame.Visible then
                    moveVector = moveVector + cameraCFrame.RightVector * Visual.joystickDelta.X
                    moveVector = moveVector - cameraCFrame.LookVector * Visual.joystickDelta.Y
                end
                
                if moveVector.Magnitude > 0 then
                    moveVector = moveVector.Unit * speed * deltaTime * 60 -- Frame-rate independent
                    Visual.freecamPosition = Visual.freecamPosition + moveVector
                    Visual.freecamCFrame = CFrame.new(Visual.freecamPosition) * Visual.freecamCFrame.Rotation
                end
                
                -- Apply rotation from swipe
                Visual.freecamCFrame = CFrame.new(Visual.freecamPosition) * CFrame.Angles(lastPitch, lastYaw, 0)
                camera.CFrame = Visual.freecamCFrame
            end
        end)
        
        connections.touchInput = UserInputService.TouchMoved:Connect(function(input, processed)
            if not processed then
                Visual.joystickDelta = handleJoystickInput(input) or Vector2.new(0, 0)
                handleSwipe(input)
            end
        end)
        connections.touchBegan = UserInputService.TouchStarted:Connect(function(input, processed)
            if not processed then
                Visual.joystickDelta = handleJoystickInput(input) or Vector2.new(0, 0)
                handleSwipe(input)
            end
        end)
        connections.touchEnded = UserInputService.TouchEnded:Connect(function(input, processed)
            if not processed then
                Visual.joystickDelta = handleJoystickInput(input) or Vector2.new(0, 0)
                handleSwipe(input)
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
        joystickFrame.Visible = false
        joystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
        lastYaw, lastPitch = 0, 0
        touchStartPos = nil
        Visual.joystickDelta = Vector2.new(0, 0)
        
        local camera = Workspace.CurrentCamera
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = humanoid
        if humanoid and rootPart then
            camera.CFrame = CFrame.lookAt(rootPart.Position + Vector3.new(0, 2, 10), rootPart.Position)
            humanoid.WalkSpeed = settings.WalkSpeed and settings.WalkSpeed.value or 16
            humanoid.JumpPower = (settings.JumpHeight and settings.JumpHeight.value * 2.4) or 50
        end
        Visual.freecamPosition = nil
        Visual.freecamCFrame = nil
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

-- Flashlight (Fixed and Improved)
local function toggleFlashlight(enabled)
    Visual.flashlightEnabled = enabled
    print("Flashlight:", enabled)
    
    if enabled then
        -- Clean up existing lights first
        if flashlight and flashlight.Parent then
            flashlight:Destroy()
        end
        if pointLight and pointLight.Parent then
            pointLight:Destroy()
        end
        
        -- Create new flashlight (SpotLight)
        flashlight = Instance.new("SpotLight")
        flashlight.Name = "Flashlight"
        flashlight.Brightness = 20
        flashlight.Range = 150
        flashlight.Angle = 45
        flashlight.Color = Color3.fromRGB(255, 255, 255)
        flashlight.Enabled = true
        
        -- Create new PointLight for broader illumination
        pointLight = Instance.new("PointLight")
        pointLight.Name = "FlashlightPoint"
        pointLight.Brightness = 10
        pointLight.Range = 80
        pointLight.Color = Color3.fromRGB(255, 255, 255)
        pointLight.Enabled = true
        
        -- Update flashlight direction and position
        connections.flashlight = RunService.Heartbeat:Connect(function()
            if Visual.flashlightEnabled and flashlight and pointLight then
                pcall(function()
                    local camera = Workspace.CurrentCamera
                    local head = Visual.character and Visual.character:FindFirstChild("Head")
                    
                    -- Prefer head, fallback to camera
                    local parent = head or camera
                    
                    if parent then
                        -- Re-parent if needed
                        if flashlight.Parent ~= parent then
                            flashlight.Parent = parent
                        end
                        if pointLight.Parent ~= parent then
                            pointLight.Parent = parent
                        end
                        
                        -- Update light properties
                        flashlight.Enabled = true
                        pointLight.Enabled = true
                        
                        -- For head, align with head direction
                        if head then
                            flashlight.Face = Enum.NormalId.Front
                        end
                    else
                        -- No valid parent found, disable lights
                        flashlight.Enabled = false
                        pointLight.Enabled = false
                    end
                end)
            end
        end)
        
        -- Initial parent assignment
        pcall(function()
            local head = Visual.character and Visual.character:FindFirstChild("Head")
            local camera = Workspace.CurrentCamera
            local parent = head or camera
            
            if parent then
                flashlight.Parent = parent
                pointLight.Parent = parent
                
                if head then
                    flashlight.Face = Enum.NormalId.Front
                end
                
                print("Flashlight attached to:", parent.Name)
            else
                warn("No valid parent found for flashlight!")
            end
        end)
    else
        -- Clean up
        if connections.flashlight then
            connections.flashlight:Disconnect()
            connections.flashlight = nil
        end
        
        if flashlight then
            pcall(function()
                flashlight.Enabled = false
                flashlight:Destroy()
            end)
            flashlight = nil
        end
        
        if pointLight then
            pcall(function()
                pointLight.Enabled = false
                pointLight:Destroy()
            end)
            pointLight = nil
        end
        
        print("Flashlight disabled and cleaned up")
    end
end

-- Low Detail Mode (Brutally Low for Mobile with No Grass and No Leaves) - FIXED
local function toggleLowDetail(enabled)
    Visual.lowDetailEnabled = enabled
    print("Low Detail Mode:", enabled)
    
    if enabled then
        -- Store default settings
        defaultLightingSettings.GlobalShadows = defaultLightingSettings.GlobalShadows or Lighting.GlobalShadows
        
        -- Store terrain decoration setting safely
        pcall(function()
            if Workspace:FindFirstChild("Terrain") then
                defaultLightingSettings.TerrainDecoration = Workspace.Terrain.Decoration
            end
        end)
        
        pcall(function()
            local settings = game:GetService("Settings")
            if settings and settings:FindFirstChild("Rendering") then
                defaultLightingSettings.QualityLevel = settings.Rendering.QualityLevel
            end
            defaultLightingSettings.StreamingEnabled = Workspace.StreamingEnabled
            defaultLightingSettings.StreamingMinRadius = Workspace.StreamingMinRadius
            defaultLightingSettings.StreamingTargetRadius = Workspace.StreamingTargetRadius
        end)
        
        -- Disable all shadows and set minimal lighting
        Lighting.GlobalShadows = false
        Lighting.Brightness = 0.5
        Lighting.FogEnd = 500
        Lighting.FogStart = 0
        Lighting.FogColor = Color3.fromRGB(100, 100, 100)
        
        -- Set absolute minimum rendering quality
        pcall(function()
            local settings = game:GetService("Settings")
            if settings and settings:FindFirstChild("Rendering") then
                local renderSettings = settings.Rendering
                renderSettings.QualityLevel = Enum.QualityLevel.Level01
                if renderSettings:FindFirstChild("EnableFRM") then
                    renderSettings.EnableFRM = false
                end
                if renderSettings:FindFirstChild("EnableParticles") then
                    renderSettings.EnableParticles = false
                end
                if renderSettings:FindFirstChild("EnableClouds") then
                    renderSettings.EnableClouds = false
                end
            end
        end)
        
        pcall(function()
            local userSettings = UserSettings()
            if userSettings then
                local gameSettings = userSettings.GameSettings
                if gameSettings then
                    gameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
                    if gameSettings:FindFirstChild("RenderDistance") then
                        gameSettings.RenderDistance = 50
                    end
                end
            end
        end)
        
        -- Disable all visual effects and simplify objects, including foliage
        for _, obj in pairs(Workspace:GetDescendants()) do
            pcall(function()
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or 
                   obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                    if not foliageStates[obj] then
                        foliageStates[obj] = { Enabled = obj.Enabled }
                    end
                    obj.Enabled = false
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    if not foliageStates[obj] then
                        foliageStates[obj] = { Transparency = obj.Transparency }
                    end
                    obj.Transparency = 1
                elseif obj:IsA("BasePart") then
                    -- Check for leaf-related parts (by name or tag)
                    local isFoliage = obj.Name:lower():match("leaf") or obj.Name:lower():match("leaves") or 
                                      obj.Name:lower():match("foliage") or obj:GetAttribute("IsFoliage")
                    if isFoliage then
                        if not foliageStates[obj] then
                            foliageStates[obj] = { Transparency = obj.Transparency }
                        end
                        obj.Transparency = 1
                    else
                        if not foliageStates[obj] then
                            foliageStates[obj] = { 
                                Material = obj.Material, 
                                Reflectance = obj.Reflectance, 
                                CastShadow = obj.CastShadow, 
                                Transparency = obj.Transparency 
                            }
                        end
                        obj.Material = Enum.Material.SmoothPlastic
                        obj.Reflectance = 0
                        obj.CastShadow = false
                    end
                elseif obj:IsA("MeshPart") then
                    local isFoliage = obj.Name:lower():match("leaf") or obj.Name:lower():match("leaves") or 
                                      obj.Name:lower():match("foliage") or obj:GetAttribute("IsFoliage")
                    if isFoliage then
                        if not foliageStates[obj] then
                            foliageStates[obj] = { Transparency = obj.Transparency }
                        end
                        obj.Transparency = 1
                    else
                        if not foliageStates[obj] then
                            foliageStates[obj] = { TextureID = obj.TextureID, Material = obj.Material }
                        end
                        obj.TextureID = ""
                        obj.Material = Enum.Material.SmoothPlastic
                    end
                elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                    -- Skip our own flashlight
                    if obj.Name ~= "Flashlight" and obj.Name ~= "FlashlightPoint" then
                        if not foliageStates[obj] then
                            foliageStates[obj] = { Enabled = obj.Enabled }
                        end
                        obj.Enabled = false
                    end
                elseif obj:IsA("Model") and obj ~= Visual.character then
                    -- Check if model is a tree or foliage
                    local isTreeModel = obj.Name:lower():match("tree") or obj.Name:lower():match("bush") or 
                                        obj.Name:lower():match("foliage") or obj:GetAttribute("IsTree")
                    if isTreeModel then
                        for _, part in pairs(obj:GetDescendants()) do
                            if part:IsA("BasePart") or part:IsA("MeshPart") then
                                if not foliageStates[part] then
                                    foliageStates[part] = { Transparency = part.Transparency }
                                end
                                part.Transparency = 1
                            end
                        end
                    end
                    local animator = obj:FindFirstChildOfClass("Animator")
                    if animator then
                        animator:Destroy()
                    end
                end
            end)
        end
        
        -- Ultra-low streaming settings
        pcall(function()
            Workspace.StreamingEnabled = true
            Workspace.StreamingMinRadius = 8
            Workspace.StreamingTargetRadius = 16
        end)
        
        -- Disable all terrain details, including grass - FIXED
        pcall(function()
            local terrain = Workspace:FindFirstChild("Terrain")
            if terrain then
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
                terrain.WaterReflectance = 0
                terrain.WaterTransparency = 1
                terrain.Decoration = false -- Disable grass and foliage
                
                -- Remove terrain decorations safely
                for _, child in pairs(terrain:GetChildren()) do
                    if child.Name:lower():match("decoration") or child.Name:lower():match("grass") then
                        child:Destroy()
                    end
                end
            end
        end)
        
        -- Disable post-processing effects
        pcall(function()
            for _, effect in pairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") then
                    if not foliageStates[effect] then
                        foliageStates[effect] = { Enabled = effect.Enabled }
                    end
                    effect.Enabled = false
                end
            end
        end)
        
    else
        -- Restore default settings
        Lighting.GlobalShadows = defaultLightingSettings.GlobalShadows or true
        Lighting.Brightness = defaultLightingSettings.Brightness or 1
        Lighting.FogEnd = defaultLightingSettings.FogEnd or 1000
        Lighting.FogStart = defaultLightingSettings.FogStart or 0
        Lighting.FogColor = defaultLightingSettings.FogColor or Color3.fromRGB(192, 192, 192)
        
        pcall(function()
            local settings = game:GetService("Settings")
            if settings and settings:FindFirstChild("Rendering") then
                local renderSettings = settings.Rendering
                renderSettings.QualityLevel = defaultLightingSettings.QualityLevel or Enum.QualityLevel.Automatic
                if renderSettings:FindFirstChild("EnableFRM") then
                    renderSettings.EnableFRM = true
                end
                if renderSettings:FindFirstChild("EnableParticles") then
                    renderSettings.EnableParticles = true
                end
                if renderSettings:FindFirstChild("EnableClouds") then
                    renderSettings.EnableClouds = true
                end
            end
        end)
        
        pcall(function()
            local userSettings = UserSettings()
            if userSettings then
                local gameSettings = userSettings.GameSettings
                if gameSettings then
                    gameSettings.SavedQualityLevel = Enum.SavedQualitySetting.Automatic
                    if gameSettings:FindFirstChild("RenderDistance") then
                        gameSettings.RenderDistance = 500
                    end
                end
            end
        end)
        
        -- Restore objects
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
                        obj.Reflectance = state.Reflectance or 0.1
                        obj.CastShadow = state.CastShadow or true
                        obj.Transparency = state.Transparency or 0
                    elseif obj:IsA("MeshPart") then
                        obj.TextureID = state.TextureID or ""
                        obj.Material = state.Material or Enum.Material.Plastic
                        obj.Transparency = state.Transparency or 0
                    elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                        obj.Enabled = state.Enabled or true
                    elseif obj:IsA("PostEffect") then
                        obj.Enabled = state.Enabled or true
                    end
                end
            end)
        end
        foliageStates = {} -- Clear stored states
        
        -- Restore streaming settings
        pcall(function()
            Workspace.StreamingEnabled = defaultLightingSettings.StreamingEnabled or false
            Workspace.StreamingMinRadius = defaultLightingSettings.StreamingMinRadius or 128
            Workspace.StreamingTargetRadius = defaultLightingSettings.StreamingTargetRadius or 256
        end)
        
        -- Restore terrain - FIXED
        pcall(function()
            local terrain = Workspace:FindFirstChild("Terrain")
            if terrain then
                terrain.WaterWaveSize = 0.15
                terrain.WaterWaveSpeed = 10
                terrain.WaterReflectance = 0.3
                terrain.WaterTransparency = 0.5
                terrain.Decoration = defaultLightingSettings.TerrainDecoration or true -- Restore grass
            end
        end)
        
        -- Restore post-processing effects
        pcall(function()
            for _, effect in pairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") then
                    effect.Enabled = true
                end
            end
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
    
    -- Re-apply active features after respawn
    if Visual.freecamEnabled then
        toggleFreecam(false)
        wait(0.1)
        toggleFreecam(true)
    end
    if Visual.fullbrightEnabled then
        toggleFullbright(true)
    end
    if Visual.flashlightEnabled then
        toggleFlashlight(false)
        wait(0.1)
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