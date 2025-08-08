-- visual.lua
-- Visual-related features for MinimalHackGUI by Fari Noveri, including Low Detail Mode

-- Dependencies: These must be passed from mainloader.lua
local Players, UserInputService, RunService, Workspace, Lighting, RenderSettings, connections, buttonStates, ScrollFrame, settings, humanoid, rootPart, player

-- Initialize module
local Visual = {}

-- Variables
Visual.freecamEnabled = false
Visual.freecamPosition = nil
Visual.fullbrightEnabled = false
Visual.flashlightEnabled = false
Visual.lowDetailEnabled = false
local flashlight

-- Freecam
local function toggleFreecam(enabled)
    Visual.freecamEnabled = enabled
    if enabled then
        if humanoid then
            humanoid.WalkSpeed = 0
            humanoid.JumpPower = 0
        end
        Visual.freecamPosition = rootPart and rootPart.Position or Workspace.CurrentCamera.CFrame.Position
        local camera = Workspace.CurrentCamera
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = CFrame.new(Visual.freecamPosition)
        
        connections.freecam = RunService.RenderStepped:Connect(function()
            if Visual.freecamEnabled then
                local moveVector = Vector3.new()
                local speed = settings.FreecamSpeed.value
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
                    moveVector = moveVector.Unit * speed
                    Visual.freecamPosition = Visual.freecamPosition + moveVector
                    camera.CFrame = CFrame.new(Visual.freecamPosition) * CFrame.Angles(cameraCFrame:ToEulerAnglesXYZ())
                end
                
                local mouseDelta = UserInputService:GetMouseDelta()
                local rotation = CFrame.Angles(0, -math.rad(mouseDelta.X * 0.2), 0)
                local pitch = math.rad(-mouseDelta.Y * 0.2)
                pitch = math.clamp(pitch, -math.rad(89), math.rad(89))
                camera.CFrame = CFrame.new(camera.CFrame.Position) * (CFrame.Angles(0, cameraCFrame:ToEulerAnglesXYZ()) * rotation * CFrame.Angles(pitch, 0, 0))
            end
        end)
    else
        if connections.freecam then
            connections.freecam:Disconnect()
        end
        Visual.freecamPosition = Workspace.CurrentCamera.CFrame.Position
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        Workspace.CurrentCamera.CameraSubject = humanoid
        if humanoid then
            humanoid.WalkSpeed = settings.WalkSpeed.value
            humanoid.JumpPower = settings.JumpHeight.value * 2.4 or 50
        end
    end
end

-- Fullbright
local function toggleFullbright(enabled)
    Visual.fullbrightEnabled = enabled
    if enabled then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    else
        Lighting.Brightness = 1
        Lighting.ClockTime = game:GetService("Lighting").ClockTime
        Lighting.FogEnd = game:GetService("Lighting").FogEnd
        Lighting.GlobalShadows = true
        Lighting.Ambient = game:GetService("Lighting").Ambient
    end
end

-- Flashlight
local function toggleFlashlight(enabled)
    Visual.flashlightEnabled = enabled
    if enabled then
        flashlight = Instance.new("SpotLight")
        flashlight.Name = "Flashlight"
        flashlight.Brightness = 5
        flashlight.Range = 60
        flashlight.Angle = 60
        flashlight.Parent = Workspace.CurrentCamera
        
        connections.flashlight = RunService.RenderStepped:Connect(function()
            if Visual.flashlightEnabled and flashlight.Parent then
                flashlight.CFrame = Workspace.CurrentCamera.CFrame
            end
        end)
    else
        if connections.flashlight then
            connections.flashlight:Disconnect()
        end
        if flashlight then
            flashlight:Destroy()
        end
    end
end

-- Low Detail Mode (Fixed version)
local function toggleLowDetail(enabled)
    Visual.lowDetailEnabled = enabled
    if enabled then
        -- Disable shadows and reduce lighting quality
        Lighting.GlobalShadows = false
        
        -- Use Settings service properly for render quality
        pcall(function()
            local renderSettings = game:GetService("Settings").Rendering
            renderSettings.QualityLevel = Enum.QualityLevel.Level01
        end)
        
        -- Alternative method using UserSettings if Settings doesn't work
        pcall(function()
            local userSettings = UserSettings()
            local gameSettings = userSettings.GameSettings
            gameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
        end)
        
        -- Disable particle effects and trails
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                obj.Enabled = false
            elseif obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj.Enabled = false
            end
        end
        
        -- Reduce texture quality
        pcall(function()
            workspace.StreamingEnabled = true
            workspace.StreamingMinRadius = 32
            workspace.StreamingTargetRadius = 64
        end)
        
    else
        -- Restore normal settings
        Lighting.GlobalShadows = true
        
        -- Restore render quality
        pcall(function()
            local renderSettings = game:GetService("Settings").Rendering
            renderSettings.QualityLevel = Enum.QualityLevel.Automatic
        end)
        
        -- Alternative method
        pcall(function()
            local userSettings = UserSettings()
            local gameSettings = userSettings.GameSettings
            gameSettings.SavedQualityLevel = Enum.SavedQualitySetting.Automatic
        end)
        
        -- Re-enable particle effects and trails
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                obj.Enabled = true
            elseif obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                obj.Enabled = true
            end
        end
        
        -- Restore streaming settings
        pcall(function()
            workspace.StreamingEnabled = false
        end)
    end
end

-- Function to create buttons for Visual features
function Visual.loadVisualButtons(createToggleButton)
    createToggleButton("Freecam", toggleFreecam)
    createToggleButton("Fullbright", toggleFullbright)
    createToggleButton("Flashlight", toggleFlashlight)
    createToggleButton("Low Detail Mode", toggleLowDetail)
end

-- Function to reset Visual states
function Visual.resetStates()
    Visual.freecamEnabled = false
    Visual.fullbrightEnabled = false
    Visual.flashlightEnabled = false
    Visual.lowDetailEnabled = false
    
    toggleFreecam(false)
    toggleFullbright(false)
    toggleFlashlight(false)
    toggleLowDetail(false)
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
    Visual.fullbrightEnabled = false
    Visual.flashlightEnabled = false
    Visual.lowDetailEnabled = false
end

return Visual