-- Visual-related features for MinimalHackGUI by Fari Noveri, including ESP, Freecam, Fullbright, Flashlight, and Low Detail Mode

-- Dependencies: These must be passed from mainloader.lua
local Players, UserInputService, RunService, Workspace, Lighting, RenderSettings, connections, buttonStates, ScrollFrame, settings, humanoid, rootPart, player

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
local flashlight
local espHighlights = {} -- Store Highlight instances for ESP
local defaultLightingSettings = {} -- Store default lighting settings

-- ESP (Wallhack)
local function toggleESP(enabled)
    Visual.espEnabled = enabled
    print("ESP:", enabled)
    
    if enabled then
        connections.esp = RunService.RenderStepped:Connect(function()
            if Visual.espEnabled then
                for _, otherPlayer in pairs(Players:GetPlayers()) do
                    if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local character = otherPlayer.Character
                        if not espHighlights[otherPlayer] then
                            local highlight = Instance.new("Highlight")
                            highlight.Name = "ESPHighlight"
                            highlight.FillColor = Color3.fromRGB(255, 0, 0) -- Red glow
                            highlight.OutlineColor = Color3.fromRGB(255, 255, 255) -- White outline
                            highlight.FillTransparency = 0.5
                            highlight.OutlineTransparency = 0
                            highlight.Adornee = character
                            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- Visible through walls
                            highlight.Parent = character
                            espHighlights[otherPlayer] = highlight
                        end
                    end
                end
            end
        end)
        
        -- Handle players leaving
        connections.espPlayerLeaving = Players.PlayerRemoving:Connect(function(leavingPlayer)
            if espHighlights[leavingPlayer] then
                espHighlights[leavingPlayer]:Destroy()
                espHighlights[leavingPlayer] = nil
            end
        end)
        
        -- Handle players joining or respawning
        connections.espPlayerAdded = Players.PlayerAdded:Connect(function(newPlayer)
            if Visual.espEnabled and newPlayer ~= player then
                newPlayer.CharacterAdded:Connect(function(character)
                    if Visual.espEnabled then
                        local highlight = Instance.new("Highlight")
                        highlight.Name = "ESPHighlight"
                        highlight.FillColor = Color3.fromRGB(255, 0, 0)
                        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        highlight.FillTransparency = 0.5
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

-- Freecam (Fixed)
local function toggleFreecam(enabled)
    Visual.freecamEnabled = enabled
    print("Freecam:", enabled)
    
    if enabled then
        if humanoid then
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
        end
        local camera = Workspace.CurrentCamera
        Visual.freecamCFrame = camera.CFrame -- Store full CFrame for rotation
        Visual.freecamPosition = camera.CFrame.Position
        camera.CameraType = Enum.CameraType.Scriptable
        
        connections.freecam = RunService.RenderStepped:Connect(function(deltaTime)
            if Visual.freecamEnabled then
                local moveVector = Vector3.new()
                local speed = settings.FreecamSpeed and settings.FreecamSpeed.value or 50
                local cameraCFrame = camera.CFrame
                
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveVector = moveVector + cameraCFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveVector = moveVector - cameraCFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveVector = moveVector + cameraCFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveVector = moveVector - cameraCFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveVector = moveVector + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveVector = moveVector - Vector3.new(0, 1, 0)
                end
                
                if moveVector.Magnitude > 0 then
                    moveVector = moveVector.Unit * speed * deltaTime * 60 -- Frame-rate independent
                    Visual.freecamPosition = Visual.freecamPosition + moveVector
                    Visual.freecamCFrame = CFrame.new(Visual.freecamPosition) * CFrame.new(cameraCFrame.Position) * cameraCFrame.Rotation
                end
                
                local mouseDelta = UserInputService:GetMouseDelta()
                local yaw = -math.rad(mouseDelta.X * 0.2)
                local pitch = math.clamp(-math.rad(mouseDelta.Y * 0.2), -math.rad(89), math.rad(89))
                Visual.freecamCFrame = Visual.freecamCFrame * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
                camera.CFrame = Visual.freecamCFrame
            end
        end)
    else
        if connections.freecam then
            connections.freecam:Disconnect()
            connections.freecam = nil
        end
        local camera = Workspace.CurrentCamera
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = humanoid
        if humanoid and rootPart then
            camera.CFrame = CFrame.new(rootPart.Position + Vector3.new(0, 2, 10)) * CFrame.lookAt(Vector3.new(0, 2, 10), rootPart.Position)
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

-- Flashlight (Fixed)
local function toggleFlashlight(enabled)
    Visual.flashlightEnabled = enabled
    print("Flashlight:", enabled)
    
    if enabled then
        flashlight = Instance.new("SpotLight")
        flashlight.Name = "Flashlight"
        flashlight.Brightness = 5
        flashlight.Range = 60
        flashlight.Angle = 60
        flashlight.Parent = Workspace.CurrentCamera
        
        connections.flashlight = RunService.RenderStepped:Connect(function()
            if Visual.flashlightEnabled and flashlight and flashlight.Parent then
                local cameraCFrame = Workspace.CurrentCamera.CFrame
                flashlight.Enabled = true
                flashlight.CFrame = CFrame.new(Vector3.new(0, 0, 0), cameraCFrame.LookVector)
            end
        end)
    else
        if connections.flashlight then
            connections.flashlight:Disconnect()
            connections.flashlight = nil
        end
        if flashlight then
            flashlight:Destroy()
            flashlight = nil
        end
    end
end

-- Low Detail Mode (Enhanced)
local function toggleLowDetail(enabled)
    Visual.lowDetailEnabled = enabled
    print("Low Detail Mode:", enabled)
    
    if enabled then
        -- Store default settings
        defaultLightingSettings.GlobalShadows = defaultLightingSettings.GlobalShadows or Lighting.GlobalShadows
        pcall(function()
            defaultLightingSettings.QualityLevel = game:GetService("Settings").Rendering.QualityLevel
            defaultLightingSettings.StreamingEnabled = workspace.StreamingEnabled
            defaultLightingSettings.StreamingMinRadius = workspace.StreamingMinRadius
            defaultLightingSettings.StreamingTargetRadius = workspace.StreamingTargetRadius
        end)
        
        -- Disable shadows and reduce lighting quality
        Lighting.GlobalShadows = false
        Lighting.Brightness = 1
        Lighting.FogEnd = 1000
        
        -- Set lowest render quality
        pcall(function()
            local renderSettings = game:GetService("Settings").Rendering
            renderSettings.QualityLevel = Enum.QualityLevel.Level01
        end)
        pcall(function()
            local userSettings = UserSettings()
            local gameSettings = userSettings.GameSettings
            gameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
        end)
        
        -- Disable particle effects, trails, decals, and other visual effects
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj.Enabled = false
            elseif obj:IsA("Decal") then
                obj.Transparency = 1
            elseif obj:IsA("BasePart") then
                obj.Material = Enum.Material.SmoothPlastic -- Low-quality material
                obj.Reflectance = 0
            elseif obj:IsA("MeshPart") then
                obj.TextureID = "" -- Remove textures
            end
        end
        
        -- Aggressive streaming settings
        pcall(function()
            workspace.StreamingEnabled = true
            workspace.StreamingMinRadius = 16
            workspace.StreamingTargetRadius = 32
        end)
        
        -- Disable terrain details
        pcall(function()
            local terrain = workspace.Terrain
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 1
        end)
    else
        -- Restore settings
        Lighting.GlobalShadows = defaultLightingSettings.GlobalShadows or true
        Lighting.Brightness = defaultLightingSettings.Brightness or 1
        Lighting.FogEnd = defaultLightingSettings.FogEnd or 1000
        
        pcall(function()
            local renderSettings = game:GetService("Settings").Rendering
            renderSettings.QualityLevel = defaultLightingSettings.QualityLevel or Enum.QualityLevel.Automatic
        end)
        pcall(function()
            local userSettings = UserSettings()
            local gameSettings = userSettings.GameSettings
            gameSettings.SavedQualityLevel = Enum.SavedQualitySetting.Automatic
        end)
        
        -- Re-enable visual effects
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj.Enabled = true
            elseif obj:IsA("Decal") then
                obj.Transparency = 0
            elseif obj:IsA("BasePart") then
                obj.Material = Enum.Material.Plastic -- Restore default material
                obj.Reflectance = 0.1 -- Reasonable default
            elseif obj:IsA("MeshPart") then
                obj.TextureID = obj:GetAttribute("OriginalTextureID") or ""
            end
        end
        
        -- Restore streaming settings
        pcall(function()
            workspace.StreamingEnabled = defaultLightingSettings.StreamingEnabled or false
            workspace.StreamingMinRadius = defaultLightingSettings.StreamingMinRadius or 128
            workspace.StreamingTargetRadius = defaultLightingSettings.StreamingTargetRadius or 256
        end)
        
        -- Restore terrain details
        pcall(function()
            local terrain = workspace.Terrain
            terrain.WaterWaveSize = 0.15
            terrain.WaterWaveSpeed = 10
            terrain.WaterReflectance = 0.3
            terrain.WaterTransparency = 0.5
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
    connections = deps.connections
    buttonStates = deps.buttonStates
    ScrollFrame = deps.ScrollFrame
    settings = deps.settings
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    player = deps.player
    
    -- Initialize state variables
    Visual.freecamEnabled = false
    Visual.freecamPosition = nil
    Visual.freecamCFrame = nil
    Visual.fullbrightEnabled = false
    Visual.flashlightEnabled = false
    Visual.lowDetailEnabled = false
    Visual.espEnabled = false
    espHighlights = {}
    
    -- Store default lighting settings
    defaultLightingSettings.Brightness = Lighting.Brightness
    defaultLightingSettings.ClockTime = Lighting.ClockTime
    defaultLightingSettings.FogEnd = Lighting.FogEnd
    defaultLightingSettings.GlobalShadows = Lighting.GlobalShadows
    defaultLightingSettings.Ambient = Lighting.Ambient
    
    print("Visual module initialized successfully")
    return true
end

-- Function to update references when character respawns
function Visual.updateReferences(newHumanoid, newRootPart)
    humanoid = newHumanoid
    rootPart = newRootPart
    
    -- Reapply active states
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