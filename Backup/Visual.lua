-- Enhanced Visual-related features (Fixed NoClipCamera, Freecam, Flashlight, Low Detail Mode, Hide Nicknames + Added Ultra Low Detail)
-- Dependencies: These must be passed from mainloader.lua
local Players, UserInputService, RunService, Workspace, Lighting, RenderSettings, ContextActionService, connections, buttonStates, ScrollFrame, ScreenGui, settings, humanoid, rootPart, player, Chat

-- Initialize module
local Visual = {}

-- Variables
Visual.freecamEnabled = false
Visual.freecamConnection = nil
Visual.noClipCameraEnabled = false
Visual.noClipCameraConnection = nil
Visual.noClipCameraCFrame = nil
Visual.originalCameraType = nil
Visual.originalCameraSubject = nil
Visual.fullbrightEnabled = false
Visual.flashlightEnabled = false
Visual.lowDetailEnabled = false
Visual.ultraLowDetailEnabled = false
Visual.espEnabled = false
Visual.xrayEnabled = false
Visual.voidEnabled = false
Visual.hideAllNicknames = false
Visual.hideOwnNickname = false
Visual.hideAllCharactersExceptSelf = false
Visual.hideSelfCharacter = false
Visual.hideBubbleChat = false
Visual.currentTimeMode = "normal"
Visual.joystickDelta = Vector2.new(0, 0)
Visual.character = nil
local flashlight
local pointLight
local espHighlights = {}
local characterTransparencies = {}
local xrayTransparencies = {}
local voidStates = {}
local defaultLightingSettings = {}
local joystickFrame
local joystickKnob
local touchStartPos
local foliageStates = {}
local processedObjects = {}
local freecamSpeed = 50
local mouseDelta = Vector2.new(0, 0)
Visual.selfHighlightEnabled = false
Visual.selfHighlightColor = Color3.fromRGB(255, 255, 255)
local selfHighlight
local colorPicker = nil
local originalBubbleChatEnabled = true

-- Freecam variables for native-like behavior
local freecamCFrame = nil
local freecamLookVector = Vector3.new(0, 0, -1)
local freecamRightVector = Vector3.new(1, 0, 0)
local freecamUpVector = Vector3.new(0, 1, 0)
local freecamYaw = 0
local freecamPitch = 0
local freecamInputConnection = nil

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

-- Safe service accessor
local function safeGetService(serviceName)
    local success, service = pcall(function()
        return game:GetService(serviceName)
    end)
    if success then
        return service
    else
        warn("Failed to get service: " .. serviceName)
        return nil
    end
end

-- Safe rendering settings accessor
local function safeGetRenderSettings()
    local success, renderSettings = pcall(function()
        local settings = safeGetService("Settings")
        if settings then
            return settings:GetService("Rendering")
        end
        return nil
    end)
    if success and renderSettings then
        return renderSettings
    else
        -- Try alternative method
        success, renderSettings = pcall(function()
            return game:GetService("UserSettings"):GetService("GameSettings")
        end)
        if success then
            return renderSettings
        end
    end
    warn("Could not access render settings")
    return nil
end

-- Health color function for ESP
local function getHealthColor(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then
        return Color3.fromRGB(255, 255, 255)
    end
    
    local humanoidTarget = targetPlayer.Character:FindFirstChild("Humanoid")
    if not humanoidTarget then
        return Color3.fromRGB(255, 255, 255)
    end
    
    local healthPercent = humanoidTarget.Health / humanoidTarget.MaxHealth
    
    if healthPercent > 0.75 then
        return Color3.fromRGB(0, 255, 0)  -- Green (High health)
    elseif healthPercent > 0.5 then
        return Color3.fromRGB(255, 255, 0)  -- Yellow (Medium health)
    elseif healthPercent > 0.25 then
        return Color3.fromRGB(255, 165, 0)  -- Orange (Low health)
    else
        return Color3.fromRGB(255, 0, 0)  -- Red (Very low health)
    end
end

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
            local renderSettings = safeGetRenderSettings()
            if renderSettings then
                defaultLightingSettings.QualityLevel = renderSettings.QualityLevel
            end
            defaultLightingSettings.StreamingEnabled = Workspace.StreamingEnabled
            defaultLightingSettings.StreamingMinRadius = Workspace.StreamingMinRadius
            defaultLightingSettings.StreamingTargetRadius = Workspace.StreamingTargetRadius
        end)
        
        print("Original lighting settings stored")
    end
end

-- Create virtual joystick for mobile control
local function createJoystick()
    if not ScreenGui then
        warn("Cannot create joystick: ScreenGui is nil")
        return
    end
    
    joystickFrame = Instance.new("Frame")
    joystickFrame.Name = "Joystick"
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
    instructionText.Text = "Use joystick to move camera"
    instructionText.TextColor3 = Color3.fromRGB(255, 255, 255)
    instructionText.TextSize = 12
    instructionText.Font = Enum.Font.SourceSansBold
    instructionText.TextStrokeTransparency = 0.5
    instructionText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    instructionText.ZIndex = 12
    instructionText.Parent = joystickFrame
end

-- Handle joystick input for camera movement
local function handleJoystickInput(input, processed)
    if not (Visual.freecamEnabled or Visual.noClipCameraEnabled) or processed then return Vector2.new(0, 0) end
    
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

-- Hide All Nicknames - Hides all nicknames except player's own
local function toggleHideAllNicknames(enabled)
    Visual.hideAllNicknames = enabled
    print("Hide All Nicknames:", enabled)
    
    local function hideNickname(targetPlayer)
        if targetPlayer ~= player and targetPlayer.Character then
            local head = targetPlayer.Character:FindFirstChild("Head")
            if head then
                local billboard = head:FindFirstChildOfClass("BillboardGui")
                if billboard then
                    billboard.Enabled = not enabled
                end
            end
        end
    end
    
    for _, targetPlayer in pairs(Players:GetPlayers()) do
        hideNickname(targetPlayer)
    end
    
    if enabled then
        if connections.hideAllNickPlayerAdded then
            connections.hideAllNickPlayerAdded:Disconnect()
        end
        connections.hideAllNickPlayerAdded = Players.PlayerAdded:Connect(function(newPlayer)
            if newPlayer ~= player then
                newPlayer.CharacterAdded:Connect(function()
                    task.wait(0.3)
                    if Visual.hideAllNicknames then
                        hideNickname(newPlayer)
                    end
                end)
            end
        end)
        
        for _, targetPlayer in pairs(Players:GetPlayers()) do
            if targetPlayer ~= player then
                if connections["hideAllNickCharAdded" .. targetPlayer.UserId] then
                    connections["hideAllNickCharAdded" .. targetPlayer.UserId]:Disconnect()
                end
                connections["hideAllNickCharAdded" .. targetPlayer.UserId] = targetPlayer.CharacterAdded:Connect(function()
                    task.wait(0.3)
                    if Visual.hideAllNicknames then
                        hideNickname(targetPlayer)
                    end
                end)
            end
        end
    else
        if connections.hideAllNickPlayerAdded then
            connections.hideAllNickPlayerAdded:Disconnect()
            connections.hideAllNickPlayerAdded = nil
        end
        for key, conn in pairs(connections) do
            if string.match(key, "hideAllNickCharAdded") then
                conn:Disconnect()
                connections[key] = nil
            end
        end
    end
end

-- Hide Own Nickname - Hides only the player's nickname
local function toggleHideOwnNickname(enabled)
    Visual.hideOwnNickname = enabled
    print("Hide Own Nickname:", enabled)
    
    local function hideOwn()
        local character = player.Character
        if character then
            local head = character:FindFirstChild("Head")
            if head then
                local billboard = head:FindFirstChildOfClass("BillboardGui")
                if billboard then
                    billboard.Enabled = not enabled
                end
            end
        end
    end
    
    hideOwn()
    
    if enabled then
        if connections.hideOwnNickCharAdded then
            connections.hideOwnNickCharAdded:Disconnect()
        end
        connections.hideOwnNickCharAdded = player.CharacterAdded:Connect(function()
            task.wait(0.3)
            if Visual.hideOwnNickname then
                hideOwn()
            end
        end)
    else
        if connections.hideOwnNickCharAdded then
            connections.hideOwnNickCharAdded:Disconnect()
            connections.hideOwnNickCharAdded = nil
        end
    end
end

-- Hide Bubble Chat
local function toggleHideBubbleChat(enabled)
    Visual.hideBubbleChat = enabled
    print("Hide Bubble Chat:", enabled)
    if Chat then
        if enabled then
            Chat.BubbleChatEnabled = false
        else
            Chat.BubbleChatEnabled = originalBubbleChatEnabled
        end
        
        if connections.bubbleChatMonitor then
            connections.bubbleChatMonitor:Disconnect()
            connections.bubbleChatMonitor = nil
        end
        
        if enabled then
            connections.bubbleChatMonitor = RunService.Heartbeat:Connect(function()
                if Chat.BubbleChatEnabled then
                    Chat.BubbleChatEnabled = false
                end
            end)
        end
    else
        warn("Chat service not available")
    end
end

-- Hide Character function
local function hideCharacter(targetPlayer, hide)
    local char = targetPlayer.Character
    if not char then return end
    if hide then
        if not characterTransparencies[targetPlayer] then
            characterTransparencies[targetPlayer] = {}
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") or part:IsA("MeshPart") then
                    characterTransparencies[targetPlayer][part] = part.Transparency
                    part.Transparency = 1
                end
            end
        end
    else
        if characterTransparencies[targetPlayer] then
            for part, trans in pairs(characterTransparencies[targetPlayer]) do
                if part and part.Parent then
                    part.Transparency = trans
                end
            end
            characterTransparencies[targetPlayer] = nil
        end
    end
end

-- Toggle Hide All Characters Except Self
local function toggleHideAllCharactersExceptSelf(enabled)
    Visual.hideAllCharactersExceptSelf = enabled
    print("Hide All Characters Except Self:", enabled)
    
    local function hideOther(targetPlayer)
        if targetPlayer ~= player then
            hideCharacter(targetPlayer, enabled)
        end
    end
    
    for _, targetPlayer in pairs(Players:GetPlayers()) do
        hideOther(targetPlayer)
    end
    
    if enabled then
        if connections.hideAllCharsPlayerAdded then
            connections.hideAllCharsPlayerAdded:Disconnect()
        end
        connections.hideAllCharsPlayerAdded = Players.PlayerAdded:Connect(function(newPlayer)
            if newPlayer ~= player then
                newPlayer.CharacterAdded:Connect(function(char)
                    task.wait(0.3)
                    if Visual.hideAllCharactersExceptSelf then
                        hideCharacter(newPlayer, true)
                    end
                end)
            end
        end)
        
        if connections.hideAllCharsPlayerRemoving then
            connections.hideAllCharsPlayerRemoving:Disconnect()
        end
        connections.hideAllCharsPlayerRemoving = Players.PlayerRemoving:Connect(function(leavingPlayer)
            if characterTransparencies[leavingPlayer] then
                characterTransparencies[leavingPlayer] = nil
            end
        end)
        
        for _, targetPlayer in pairs(Players:GetPlayers()) do
            if targetPlayer ~= player then
                if connections["hideAllCharsCharAdded" .. targetPlayer.UserId] then
                    connections["hideAllCharsCharAdded" .. targetPlayer.UserId]:Disconnect()
                end
                if connections["hideAllCharsCharRemoving" .. targetPlayer.UserId] then
                    connections["hideAllCharsCharRemoving" .. targetPlayer.UserId]:Disconnect()
                end
                connections["hideAllCharsCharAdded" .. targetPlayer.UserId] = targetPlayer.CharacterAdded:Connect(function()
                    task.wait(0.3)
                    if Visual.hideAllCharactersExceptSelf then
                        hideOther(targetPlayer)
                    end
                end)
                connections["hideAllCharsCharRemoving" .. targetPlayer.UserId] = targetPlayer.CharacterRemoving:Connect(function()
                    if characterTransparencies[targetPlayer] then
                        characterTransparencies[targetPlayer] = nil
                    end
                end)
            end
        end
    else
        if connections.hideAllCharsPlayerAdded then
            connections.hideAllCharsPlayerAdded:Disconnect()
            connections.hideAllCharsPlayerAdded = nil
        end
        if connections.hideAllCharsPlayerRemoving then
            connections.hideAllCharsPlayerRemoving:Disconnect()
            connections.hideAllCharsPlayerRemoving = nil
        end
        for key, conn in pairs(connections) do
            if string.match(key, "hideAllCharsCharAdded") or string.match(key, "hideAllCharsCharRemoving") then
                conn:Disconnect()
                connections[key] = nil
            end
        end
    end
end

-- Toggle Hide Self Character
local function toggleHideSelfCharacter(enabled)
    Visual.hideSelfCharacter = enabled
    print("Hide Self Character:", enabled)
    
    hideCharacter(player, enabled)
    
    if enabled then
        if connections.hideSelfCharAdded then
            connections.hideSelfCharAdded:Disconnect()
        end
        connections.hideSelfCharAdded = player.CharacterAdded:Connect(function()
            task.wait(0.3)
            if Visual.hideSelfCharacter then
                hideCharacter(player, true)
            end
        end)
        
        if connections.hideSelfCharRemoving then
            connections.hideSelfCharRemoving:Disconnect()
        end
        connections.hideSelfCharRemoving = player.CharacterRemoving:Connect(function()
            if characterTransparencies[player] then
                characterTransparencies[player] = nil
            end
        end)
    else
        if connections.hideSelfCharAdded then
            connections.hideSelfCharAdded:Disconnect()
            connections.hideSelfCharAdded = nil
        end
        if connections.hideSelfCharRemoving then
            connections.hideSelfCharRemoving:Disconnect()
            connections.hideSelfCharRemoving = nil
        end
    end
end

-- NoClipCamera - Camera passes through objects while maintaining normal movement
local function toggleNoClipCamera(enabled)
    Visual.noClipCameraEnabled = enabled
    print("NoClipCamera:", enabled)
    
    local camera = Workspace.CurrentCamera
    
    if enabled then
        if Visual.freecamEnabled then
            Visual.toggleFreecam(false)
        end
        
        Visual.originalCameraType = camera.CameraType
        Visual.originalCameraSubject = camera.CameraSubject
        
        if connections and type(connections) == "table" and connections.noClipCameraConnection then
            connections.noClipCameraConnection:Disconnect()
            connections.noClipCameraConnection = nil
        end
        
        Visual.noClipCameraConnection = RunService.RenderStepped:Connect(function()
            if Visual.noClipCameraEnabled then
                local camera = Workspace.CurrentCamera
                local rayOrigin = camera.CFrame.Position
                local rayDirection = camera.CFrame.LookVector * 1000
                
                local raycastParams = RaycastParams.new()
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                raycastParams.FilterDescendantsInstances = {player.Character}
                
                local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
                
                if raycastResult and raycastResult.Distance < 5 then
                    local hitPart = raycastResult.Instance
                    if hitPart and hitPart:IsA("BasePart") then
                        local originalCanCollide = hitPart.CanCollide
                        hitPart.CanCollide = false
                        
                        task.wait(0.1)
                        pcall(function()
                            if hitPart and hitPart.Parent then
                                hitPart.CanCollide = originalCanCollide
                            end
                        end)
                    end
                end
            end
        end)
        if connections and type(connections) == "table" then
            connections.noClipCameraConnection = Visual.noClipCameraConnection
        end
        
    else
        if connections and type(connections) == "table" and connections.noClipCameraConnection then
            connections.noClipCameraConnection:Disconnect()
            connections.noClipCameraConnection = nil
        end
        Visual.noClipCameraConnection = nil
        
        local camera = Workspace.CurrentCamera
        if Visual.originalCameraType then
            camera.CameraType = Visual.originalCameraType
        end
        
        if Visual.originalCameraSubject then
            camera.CameraSubject = Visual.originalCameraSubject
        end
        
        Visual.noClipCameraCFrame = nil
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
        
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= player and otherPlayer.Character then
                createESPForCharacter(otherPlayer.Character, otherPlayer)
            end
        end
        
        if connections and type(connections) == "table" and connections.espHealthUpdate then
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
        
        if connections and type(connections) == "table" and connections.espPlayerAdded then
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
        
        if connections and type(connections) == "table" and connections.espPlayerLeaving then
            connections.espPlayerLeaving:Disconnect()
        end
        connections.espPlayerLeaving = Players.PlayerRemoving:Connect(function(leavingPlayer)
            if espHighlights[leavingPlayer] then
                espHighlights[leavingPlayer]:Destroy()
                espHighlights[leavingPlayer] = nil
            end
        end)
        
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= player then
                if connections and type(connections) == "table" and connections["espCharAdded" .. otherPlayer.UserId] then
                    connections["espCharAdded" .. otherPlayer.UserId]:Disconnect()
                end
                if connections and type(connections) == "table" and connections["espCharRemoving" .. otherPlayer.UserId] then
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
        
        if connections and type(connections) == "table" and connections.espBackupCheck then
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
        if connections and type(connections) == "table" then
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
        end
        
        for _, highlight in pairs(espHighlights) do
            if highlight and highlight.Parent then
                highlight:Destroy()
            end
        end
        espHighlights = {}
    end
end

-- XRay function similar to Infinite Yield
local function isCharacterPart(part)
    local model = part:FindFirstAncestorOfClass("Model")
    return model and Players:GetPlayerFromCharacter(model)
end

local function applyXRayToObject(obj)
    if (obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("UnionOperation")) and not isCharacterPart(obj) then
        if not xrayTransparencies[obj] then
            xrayTransparencies[obj] = obj.Transparency
            obj.Transparency = 0.7
        end
    end
end

local function toggleXRay(enabled)
    Visual.xrayEnabled = enabled
    print("XRay:", enabled)
    
    if enabled then
        xrayTransparencies = {}
        for _, obj in pairs(Workspace:GetDescendants()) do
            applyXRayToObject(obj)
        end
        
        if connections and type(connections) == "table" and connections.xrayDescendantAdded then
            connections.xrayDescendantAdded:Disconnect()
        end
        connections.xrayDescendantAdded = Workspace.DescendantAdded:Connect(function(obj)
            if Visual.xrayEnabled then
                applyXRayToObject(obj)
            end
        end)
    else
        for obj, trans in pairs(xrayTransparencies) do
            if obj and obj.Parent then
                obj.Transparency = trans
            end
        end
        xrayTransparencies = {}
        
        if connections and type(connections) == "table" and connections.xrayDescendantAdded then
            connections.xrayDescendantAdded:Disconnect()
            connections.xrayDescendantAdded = nil
        end
    end
end

-- Void function (XRay but destroy instead of opacity)
local function applyVoidToObject(obj)
    if (obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("UnionOperation")) and not isCharacterPart(obj) then
        if not voidStates[obj] then
            voidStates[obj] = obj.Parent
            obj.Parent = nil
        end
    end
end

local function toggleVoid(enabled)
    Visual.voidEnabled = enabled
    print("Void:", enabled)
    
    if enabled then
        voidStates = {}
        for _, obj in pairs(Workspace:GetDescendants()) do
            applyVoidToObject(obj)
        end
        
        if connections and type(connections) == "table" and connections.voidDescendantAdded then
            connections.voidDescendantAdded:Disconnect()
        end
        connections.voidDescendantAdded = Workspace.DescendantAdded:Connect(function(obj)
            if Visual.voidEnabled then
                applyVoidToObject(obj)
            end
        end)
    else
        for obj, parent in pairs(voidStates) do
            if obj then
                obj.Parent = parent
            end
        end
        voidStates = {}
        
        if connections and type(connections) == "table" and connections.voidDescendantAdded then
            connections.voidDescendantAdded:Disconnect()
            connections.voidDescendantAdded = nil
        end
    end
end

-- Freecam
local function toggleFreecam(enabled)
    Visual.freecamEnabled = enabled
    print("Freecam:", enabled)
    
    if enabled then
        if Visual.noClipCameraEnabled then
            toggleNoClipCamera(false)
        end
        
        local camera = Workspace.CurrentCamera
        local currentCharacter = player.Character
        local currentHumanoid = currentCharacter and currentCharacter:FindFirstChild("Humanoid")
        local currentRootPart = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart")
        
        if not currentRootPart then
            print("Warning: No character found for freecam")
            Visual.freecamEnabled = false
            return
        end
        
        Visual.originalCameraType = camera.CameraType
        Visual.originalCameraSubject = camera.CameraSubject
        
        freecamCFrame = camera.CFrame
        local x, y, z = freecamCFrame:ToEulerAnglesXYZ()
        freecamYaw = -y
        freecamPitch = -x
        
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CameraSubject = nil
        
        if UserInputService then
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
            UserInputService.MouseIconEnabled = false
        end
        
        freecamSpeed = (settings.FreecamSpeed and settings.FreecamSpeed.value) or 50
        
        if joystickFrame then
            joystickFrame.Visible = true
        end
        
        if connections and type(connections) == "table" and connections.freecamConnection then
            connections.freecamConnection:Disconnect()
        end
        
        Visual.freecamConnection = RunService.RenderStepped:Connect(function(deltaTime)
            if Visual.freecamEnabled then
                local camera = Workspace.CurrentCamera
                local moveSpeed = freecamSpeed * deltaTime
                
                local yawCFrame = CFrame.Angles(0, freecamYaw, 0)
                local pitchCFrame = CFrame.Angles(freecamPitch, 0, 0)
                local rotationCFrame = yawCFrame * pitchCFrame
                
                freecamLookVector = rotationCFrame.LookVector
                freecamRightVector = rotationCFrame.RightVector
                freecamUpVector = rotationCFrame.UpVector
                
                local movement = Vector3.new(0, 0, 0)
                local currentPos = freecamCFrame.Position
                
                if UserInputService then
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                        movement = movement + freecamLookVector
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                        movement = movement - freecamLookVector
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                        movement = movement - freecamRightVector
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                        movement = movement + freecamRightVector
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
                        movement = movement - freecamUpVector
                    end
                    if UserInputService:IsKeyDown(Enum.KeyCode.E) then
                        movement = movement + freecamUpVector
                    end
                end
                
                if Visual.joystickDelta.Magnitude > 0 then
                    movement = movement + (freecamRightVector * Visual.joystickDelta.X + freecamLookVector * -Visual.joystickDelta.Y)
                end
                
                if movement.Magnitude > 0 then
                    movement = movement.Unit * moveSpeed
                    currentPos = currentPos + movement
                end
                
                freecamCFrame = CFrame.new(currentPos) * CFrame.Angles(-freecamPitch, freecamYaw, 0)
                camera.CFrame = freecamCFrame
            end
        end)
        if connections and type(connections) == "table" then
            connections.freecamConnection = Visual.freecamConnection
        end
        
        if freecamInputConnection then
            freecamInputConnection:Disconnect()
        end
        
        if UserInputService then
            freecamInputConnection = UserInputService.InputChanged:Connect(function(input, processed)
                if not Visual.freecamEnabled or processed then return end
                
                if input.UserInputType == Enum.UserInputType.MouseMovement then
                    local sensitivity = 0.003
                    freecamYaw = freecamYaw - input.Delta.X * sensitivity
                    freecamPitch = math.clamp(freecamPitch - input.Delta.Y * sensitivity, -math.pi/2 + 0.1, math.pi/2 - 0.1)
                end
            end)
            if connections and type(connections) == "table" then
                connections.freecamInputConnection = freecamInputConnection
            end
        end
        
        if UserInputService then
            if connections and type(connections) == "table" and not connections.touchInput then
                connections.touchInput = UserInputService.InputChanged:Connect(function(input, processed)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        Visual.joystickDelta = handleJoystickInput(input, processed)
                    end
                end)
            end
            
            if connections and type(connections) == "table" and not connections.touchBegan then
                connections.touchBegan = UserInputService.InputBegan:Connect(function(input, processed)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        Visual.joystickDelta = handleJoystickInput(input, processed)
                    end
                end)
            end
            
            if connections and type(connections) == "table" and not connections.touchEnded then
                connections.touchEnded = UserInputService.InputEnded:Connect(function(input, processed)
                    if input.UserInputType == Enum.UserInputType.Touch then
                        Visual.joystickDelta = handleJoystickInput(input, processed)
                    end
                end)
            end
        end
        
        print("Freecam enabled - Mouse locked, WASD/QE to move")
        
    else
        if connections and type(connections) == "table" and connections.freecamConnection then
            connections.freecamConnection:Disconnect()
            connections.freecamConnection = nil
        end
        Visual.freecamConnection = nil
        
        if freecamInputConnection then
            freecamInputConnection:Disconnect()
            freecamInputConnection = nil
        end
        if connections and type(connections) == "table" then
            connections.freecamInputConnection = nil
        end
        
        if joystickFrame then
            joystickFrame.Visible = false
            joystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
        end
        
        local camera = Workspace.CurrentCamera
        
        if Visual.originalCameraType then
            camera.CameraType = Visual.originalCameraType
        else
            camera.CameraType = Enum.CameraType.Custom
        end
        
        local currentCharacter = player.Character
        local currentHumanoid = currentCharacter and currentCharacter:FindFirstChild("Humanoid")
        
        if Visual.originalCameraSubject then
            camera.CameraSubject = Visual.originalCameraSubject
        elseif currentHumanoid then
            camera.CameraSubject = currentHumanoid
        end
        
        if UserInputService then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end
        
        freecamCFrame = nil
        freecamYaw = 0
        freecamPitch = 0
        Visual.joystickDelta = Vector2.new(0, 0)
        mouseDelta = Vector2.new(0, 0)
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
    
    if connections and type(connections) == "table" and connections.timeModeMonitor then
        connections.timeModeMonitor:Disconnect()
        connections.timeModeMonitor = nil
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
            
            local character = player.Character
            local head = character and character:FindFirstChild("Head")
            
            if head then
                flashlight = Instance.new("SpotLight")
                flashlight.Name = "Flashlight"
                flashlight.Brightness = 15
                flashlight.Range = 100
                flashlight.Angle = 45
                flashlight.Face = Enum.NormalId.Front
                flashlight.Color = Color3.fromRGB(255, 255, 200)
                flashlight.Enabled = true
                flashlight.Parent = head
                
                pointLight = Instance.new("PointLight")
                pointLight.Name = "FlashlightPoint"
                pointLight.Brightness = 5
                pointLight.Range = 60
                pointLight.Color = Color3.fromRGB(255, 255, 200)
                pointLight.Enabled = true
                pointLight.Parent = head
                
                print("Flashlight attached to head")
            end
        end
        
        setupFlashlight()
        
        if connections and type(connections) == "table" and connections.flashlight then
            connections.flashlight:Disconnect()
            connections.flashlight = nil
        end
        
        connections.flashlight = RunService.Heartbeat:Connect(function()
            if Visual.flashlightEnabled then
                local character = player.Character
                local head = character and character:FindFirstChild("Head")
                
                if head then
                    if not flashlight or flashlight.Parent ~= head then
                        setupFlashlight()
                    end
                    
                    if flashlight then
                        flashlight.Enabled = true
                    end
                    if pointLight then
                        pointLight.Enabled = true
                    end
                end
            end
        end)
        
        if connections and type(connections) == "table" and connections.flashlightCharAdded then
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
        if connections and type(connections) == "table" then
            if connections.flashlight then
                connections.flashlight:Disconnect()
                connections.flashlight = nil
            end
            if connections.flashlightCharAdded then
                connections.flashlightCharAdded:Disconnect()
                connections.flashlightCharAdded = nil
            end
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
        Lighting.Brightness = 2
        Lighting.FogEnd = 100000
        Lighting.FogStart = 100000
        Lighting.FogColor = Color3.fromRGB(255, 255, 255)
        
        pcall(function()
            local sky = Lighting:FindFirstChildOfClass("Sky")
            if sky then
                foliageStates.sky = { Parent = sky.Parent }
                sky:Destroy()
            end
        end)
        
        pcall(function()
            for _, effect in pairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") then
                    foliageStates[effect] = { Enabled = effect.Enabled }
                    effect.Enabled = false
                end
            end
        end)
        
        pcall(function()
            local renderSettings = safeGetRenderSettings()
            if renderSettings and renderSettings.QualityLevel then
                renderSettings.QualityLevel = Enum.QualityLevel.Level01
            end
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
                        local isFoliage = name:find("leaf") or name:find("leaves") or name:find("foliage") or 
                                         name:find("grass") or name:find("tree") or name:find("plant") or 
                                         name:find("flower") or name:find("bush") or name:find("shrub") or
                                         name:find("fern") or name:find("moss") or name:find("vine") or
                                         parent:find("grass") or parent:find("foliage") or parent:find("decoration") or
                                         obj:GetAttribute("IsFoliage") or obj:GetAttribute("IsNature") or
                                         obj:GetAttribute("IsDecoration")
                        
                        if isFoliage and (obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("Model")) then
                            foliageStates[obj] = { Parent = obj.Parent }
                            obj:Destroy()
                        elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or 
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
                        elseif obj:IsA("MeshPart") then
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
                        elseif obj:IsA("SpecialMesh") then
                            foliageStates[obj] = { TextureId = obj.TextureId }
                            obj.TextureId = ""
                        elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                            if not (obj.Name == "Flashlight" or obj.Name == "FlashlightPoint") then
                                foliageStates[obj] = { Enabled = obj.Enabled, Brightness = obj.Brightness }
                                obj.Enabled = false
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
        
        if connections and type(connections) == "table" and connections.lowDetailMonitor then
            connections.lowDetailMonitor:Disconnect()
        end
        connections.lowDetailMonitor = RunService.Heartbeat:Connect(function()
            if Visual.lowDetailEnabled then
                pcall(function()
                    local terrain = Workspace.Terrain
                    if terrain.Decoration == true then
                        terrain.Decoration = false
                    end
                    if Lighting.FogEnd < 50000 then
                        Lighting.FogEnd = 100000
                        Lighting.FogStart = 100000
                    end
                    local sky = Lighting:FindFirstChildOfClass("Sky")
                    if sky then
                        foliageStates.sky = { Parent = sky.Parent }
                        sky:Destroy()
                    end
                end)
            end
        end)
        
    else
        if connections and type(connections) == "table" and connections.lowDetailMonitor then
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
            local renderSettings = safeGetRenderSettings()
            if renderSettings and renderSettings.QualityLevel then
                renderSettings.QualityLevel = defaultLightingSettings.QualityLevel or Enum.QualityLevel.Automatic
            end
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
                if obj ~= "terrainSettings" and obj ~= "sky" then
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
                            elseif obj:IsA("MeshPart") then
                                obj.TextureID = state.TextureID or ""
                                obj.Material = state.Material or Enum.Material.Plastic
                                obj.Color = state.Color or Color3.new(1, 1, 1)
                            elseif obj:IsA("SpecialMesh") then
                                obj.TextureId = state.TextureId or ""
                            elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                                obj.Enabled = state.Enabled ~= false
                                obj.Brightness = state.Brightness or 1
                            elseif obj:IsA("Sound") then
                                obj.Volume = state.Volume or 0.5
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

-- Ultra Low Detail Mode
local function toggleUltraLowDetail(enabled)
    Visual.ultraLowDetailEnabled = enabled
    print("Ultra Low Detail Mode:", enabled)
    
    storeOriginalLightingSettings()
    
    if enabled then
        toggleLowDetail(true)
        
        pcall(function()
            local renderSettings = safeGetRenderSettings()
            if renderSettings and renderSettings.QualityLevel then
                renderSettings.QualityLevel = Enum.QualityLevel.Level01
            end
        end)
        
        spawn(function()
            local processCount = 0
            
            for _, obj in pairs(Workspace:GetDescendants()) do
                if not processedObjects[obj] then
                    processedObjects[obj] = true
                    
                    pcall(function()
                        local name = obj.Name:lower()
                        local parent = obj.Parent and obj.Parent.Name:lower() or ""
                        local isEnvironment = name:find("terrain") or name:find("tree") or name:find("wood") or
                                            name:find("leaf") or name:find("leaves") or name:find("foliage") or 
                                            name:find("grass") or name:find("plant") or name:find("flower") or 
                                            name:find("bush") or name:find("shrub") or name:find("fern") or 
                                            name:find("moss") or name:find("vine") or
                                            parent:find("terrain") or parent:find("grass") or parent:find("foliage") or 
                                            parent:find("decoration") or
                                            obj:GetAttribute("IsFoliage") or obj:GetAttribute("IsNature") or
                                            obj:GetAttribute("IsDecoration")
                        
                        local isCharacterPart = false
                        local currentParent = obj.Parent
                        while currentParent do
                            if currentParent:IsA("Model") and Players:GetPlayerFromCharacter(currentParent) then
                                isCharacterPart = true
                                break
                            end
                            currentParent = currentParent.Parent
                        end
                        
                        if isEnvironment and not isCharacterPart then
                            if obj:IsA("BasePart") or obj:IsA("MeshPart") then
                                foliageStates[obj] = { 
                                    Transparency = obj.Transparency,
                                    Material = obj.Material,
                                    Color = obj.Color,
                                    CanCollide = obj.CanCollide,
                                    Anchored = obj.Anchored,
                                    TextureID = obj:IsA("MeshPart") and obj.TextureID or nil
                                }
                                obj.Transparency = 1
                                obj.CanCollide = false
                                obj.Material = Enum.Material.SmoothPlastic
                                obj.Color = Color3.fromRGB(128, 128, 128)
                                if obj:IsA("MeshPart") then
                                    obj.TextureID = ""
                                end
                            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                                foliageStates[obj] = { 
                                    Transparency = obj.Transparency, 
                                    Texture = obj.Texture,
                                    Color3 = obj.Color3
                                }
                                obj.Transparency = 1
                                obj.Texture = ""
                            elseif obj:IsA("SpecialMesh") then
                                foliageStates[obj] = { TextureId = obj.TextureId }
                                obj.TextureId = ""
                            end
                        end
                    end)
                    
                    processCount = processCount + 1
                    if processCount % 20 == 0 then
                        RunService.Heartbeat:Wait()
                    end
                end
            end
            print("Ultra Low Detail applied - Environment objects invisible but not destroyed")
        end)
        
        if connections and type(connections) == "table" and connections.ultraLowDetailMonitor then
            connections.ultraLowDetailMonitor:Disconnect()
        end
        connections.ultraLowDetailMonitor = RunService.Heartbeat:Connect(function()
            if Visual.ultraLowDetailEnabled then
                pcall(function()
                    local terrain = Workspace.Terrain
                    if terrain.Decoration == true then
                        terrain.Decoration = false
                    end
                    if Lighting.FogEnd < 50000 then
                        Lighting.FogEnd = 100000
                        Lighting.FogStart = 100000
                    end
                    local sky = Lighting:FindFirstChildOfClass("Sky")
                    if sky then
                        foliageStates.sky = { Parent = sky.Parent }
                        sky:Destroy()
                    end
                end)
            end
        end)
        
    else
        if connections and type(connections) == "table" and connections.ultraLowDetailMonitor then
            connections.ultraLowDetailMonitor:Disconnect()
            connections.ultraLowDetailMonitor = nil
        end
        
        spawn(function()
            local restoreCount = 0
            for obj, state in pairs(foliageStates) do
                if obj ~= "terrainSettings" and obj ~= "sky" then
                    pcall(function()
                        if obj and obj.Parent then
                            if obj:IsA("BasePart") or obj:IsA("MeshPart") then
                                obj.Transparency = state.Transparency or 0
                                obj.Material = state.Material or Enum.Material.Plastic
                                obj.Color = state.Color or Color3.new(1, 1, 1)
                                obj.CanCollide = state.CanCollide ~= false
                                if obj:IsA("MeshPart") then
                                    obj.TextureID = state.TextureID or ""
                                end
                            elseif obj:IsA("Decal") or obj:IsA("Texture") then
                                obj.Transparency = state.Transparency or 0
                                obj.Texture = state.Texture or ""
                                obj.Color3 = state.Color3 or Color3.fromRGB(255, 255, 255)
                            elseif obj:IsA("SpecialMesh") then
                                obj.TextureId = state.TextureId or ""
                            end
                        end
                    end)
                    
                    restoreCount = restoreCount + 1
                    if restoreCount % 20 == 0 then
                        RunService.Heartbeat:Wait()
                    end
                end
            end
        end)
        
        toggleLowDetail(false)
    end
end

-- Self Highlight
local function createSelfHighlight()
    if selfHighlight then
        selfHighlight:Destroy()
        selfHighlight = nil
    end
    
    local character = player.Character
    if character then
        selfHighlight = Instance.new("Highlight")
        selfHighlight.Name = "SelfHighlight"
        selfHighlight.OutlineColor = Visual.selfHighlightColor
        selfHighlight.FillTransparency = 1
        selfHighlight.OutlineTransparency = 0
        selfHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        selfHighlight.Adornee = character
        selfHighlight.Parent = character
        print("Self Highlight created")
    end
end

local function toggleSelfHighlight(enabled)
    Visual.selfHighlightEnabled = enabled
    print("Self Highlight:", enabled)
    
    if enabled then
        createSelfHighlight()
        
        if connections and type(connections) == "table" and connections.selfHighlightCharAdded then
            connections.selfHighlightCharAdded:Disconnect()
        end
        connections.selfHighlightCharAdded = player.CharacterAdded:Connect(function()
            if Visual.selfHighlightEnabled then
                task.wait(0.3)
                createSelfHighlight()
            end
        end)
        
    else
        if selfHighlight then
            selfHighlight:Destroy()
            selfHighlight = nil
        end
        if connections and type(connections) == "table" and connections.selfHighlightCharAdded then
            connections.selfHighlightCharAdded:Disconnect()
            connections.selfHighlightCharAdded = nil
        end
    end
end

-- Initialize module
function Visual.init(deps)
    print("Initializing Visual module")
    if not deps then
        warn("Error: No dependencies provided!")
        return false
    end
    
    -- Set dependencies with strict fallbacks and safe service access
    Players = deps.Players or safeGetService("Players")
    UserInputService = deps.UserInputService or safeGetService("UserInputService")
    RunService = deps.RunService or safeGetService("RunService")
    Workspace = deps.Workspace or safeGetService("Workspace")
    Lighting = deps.Lighting or safeGetService("Lighting")
    RenderSettings = deps.RenderSettings or safeGetRenderSettings()
    ContextActionService = safeGetService("ContextActionService")
    Chat = deps.Chat or safeGetService("Chat")
    connections = deps.connections or {}
    if type(connections) ~= "table" then
        warn("Warning: connections is not a table, initializing as empty table")
        connections = {}
    end
    buttonStates = deps.buttonStates or {}
    ScrollFrame = deps.ScrollFrame
    ScreenGui = deps.ScreenGui
    settings = deps.settings or {}
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    player = deps.player or (Players and Players.LocalPlayer)
    Visual.character = deps.character or (player and player.Character)
    
    -- Validate critical dependencies
    if not Players then
        warn("Error: Could not get Players service!")
        return false
    end
    if not player then
        warn("Error: Could not get LocalPlayer!")
        return false
    end
    if not UserInputService then
        warn("Error: Could not get UserInputService!")
        return false
    end
    if not RunService then
        warn("Error: Could not get RunService!")
        return false
    end
    if not Workspace then
        warn("Error: Could not get Workspace!")
        return false
    end
    if not Lighting then
        warn("Error: Could not get Lighting!")
        return false
    end
    
    -- Debug dependency initialization
    print("Dependencies initialized:")
    print("Players:", Players and "OK" or "FAILED")
    print("UserInputService:", UserInputService and "OK" or "FAILED")
    print("RunService:", RunService and "OK" or "FAILED")
    print("Workspace:", Workspace and "OK" or "FAILED")
    print("Lighting:", Lighting and "OK" or "FAILED")
    print("RenderSettings:", RenderSettings and "OK" or "FAILED")
    print("Chat:", Chat and "OK" or "FAILED")
    print("Connections:", connections and "OK" or "FAILED")
    print("Player:", player and "OK" or "FAILED")
    
    Visual.selfHighlightEnabled = false
    Visual.selfHighlightColor = Color3.fromRGB(255, 255, 255)
    if Chat then
        originalBubbleChatEnabled = Chat.BubbleChatEnabled
    end
    
    -- Create joystick if ScreenGui is available
    if ScreenGui then
        createJoystick()
        print("Joystick created successfully")
    else
        warn("Warning: ScreenGui is nil, joystick cannot be created")
    end
    
    -- Add freecam keybind
    if connections.keybindFreecam then
        connections.keybindFreecam:Disconnect()
    end
    connections.keybindFreecam = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.C and (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)) then
            toggleFreecam(not Visual.freecamEnabled)
        end
    end)
    
    print("Visual module initialized successfully")
    return true
end

-- Utility function to convert Color3 to hex
local function toHex(color)
    local r = math.floor(color.R * 255 + 0.5)
    local g = math.floor(color.G * 255 + 0.5)
    local b = math.floor(color.B * 255 + 0.5)
    return string.format("#%02X%02X%02X", r, g, b)
end

-- Utility function to create a color picker GUI
local function createColorPicker(name, initialColor, onColorChanged)
    if not ScreenGui then
        warn("Error: ScreenGui is nil, cannot create " .. name .. " color picker")
        return nil, nil
    end

    local picker = Instance.new("Frame")
    picker.Name = name .. "ColorPicker"
    picker.Size = UDim2.new(0, 300, 0, 350)
    picker.Position = UDim2.new(0.5, -150, 0.5, -175)
    picker.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    picker.BorderSizePixel = 0
    picker.Visible = false
    picker.ZIndex = 100
    picker.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = picker

    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 10, 1, 10)
    shadow.Position = UDim2.new(0, -5, 0, -5)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.6
    shadow.ZIndex = 99
    shadow.Parent = picker
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 8)
    shadowCorner.Parent = shadow

    local title = Instance.new("TextLabel")
    title.Text = "Choose " .. name .. " Color"
    title.Size = UDim2.new(1, -30, 0, 40)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 18
    title.Font = Enum.Font.SourceSansBold
    title.ZIndex = 101
    title.Parent = picker

    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 18
    closeButton.Font = Enum.Font.SourceSansBold
    closeButton.ZIndex = 102
    closeButton.Parent = picker

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeButton

    closeButton.MouseButton1Click:Connect(function()
        picker.Visible = false
    end)

    local presetFrame = Instance.new("ScrollingFrame")
    presetFrame.Name = "PresetFrame"
    presetFrame.Size = UDim2.new(0.8, 0, 0, 280)
    presetFrame.Position = UDim2.new(0.1, 0, 0.15, 0)
    presetFrame.BackgroundTransparency = 1
    presetFrame.ZIndex = 101
    presetFrame.ScrollBarThickness = 6
    presetFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    presetFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    presetFrame.Parent = picker

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0, 40, 0, 40)
    gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.Parent = presetFrame

    local presetColors = {
        Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0), Color3.fromRGB(128, 128, 128), Color3.fromRGB(192, 192, 192),
        Color3.fromRGB(255, 0, 0), Color3.fromRGB(139, 0, 0), Color3.fromRGB(128, 0, 0), Color3.fromRGB(200, 0, 0), Color3.fromRGB(150, 0, 0), Color3.fromRGB(100, 0, 0),
        Color3.fromRGB(255, 165, 0), Color3.fromRGB(255, 69, 0), Color3.fromRGB(255, 140, 0), Color3.fromRGB(200, 100, 0), Color3.fromRGB(150, 75, 0),
        Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 215, 0), Color3.fromRGB(218, 165, 32), Color3.fromRGB(200, 200, 0), Color3.fromRGB(150, 150, 0),
        Color3.fromRGB(0, 255, 0), Color3.fromRGB(0, 128, 0), Color3.fromRGB(50, 205, 50), Color3.fromRGB(0, 255, 127), Color3.fromRGB(128, 128, 0), Color3.fromRGB(0, 200, 0), Color3.fromRGB(0, 150, 0),
        Color3.fromRGB(0, 0, 255), Color3.fromRGB(0, 0, 139), Color3.fromRGB(0, 0, 128), Color3.fromRGB(0, 0, 200), Color3.fromRGB(0, 0, 150),
        Color3.fromRGB(0, 255, 255), Color3.fromRGB(0, 139, 139), Color3.fromRGB(64, 224, 208), Color3.fromRGB(0, 128, 128), Color3.fromRGB(0, 200, 200),
        Color3.fromRGB(255, 0, 255), Color3.fromRGB(139, 0, 139), Color3.fromRGB(128, 0, 128), Color3.fromRGB(75, 0, 130), Color3.fromRGB(238, 130, 238), Color3.fromRGB(200, 0, 200),
        Color3.fromRGB(255, 192, 203), Color3.fromRGB(255, 105, 180), Color3.fromRGB(255, 20, 147), Color3.fromRGB(200, 100, 150), Color3.fromRGB(150, 75, 100),
        Color3.fromRGB(165, 42, 42), Color3.fromRGB(139, 69, 19), Color3.fromRGB(210, 105, 30), Color3.fromRGB(255, 228, 196), Color3.fromRGB(255, 222, 173),
        Color3.fromRGB(250, 250, 210), Color3.fromRGB(240, 230, 140), Color3.fromRGB(200, 200, 200), Color3.fromRGB(150, 150, 150), Color3.fromRGB(100, 100, 100),
        Color3.fromRGB(255, 100, 100), Color3.fromRGB(255, 200, 200), Color3.fromRGB(100, 255, 100), Color3.fromRGB(200, 255, 200), Color3.fromRGB(100, 100, 255), Color3.fromRGB(200, 200, 255),
        Color3.fromRGB(255, 255, 100), Color3.fromRGB(255, 100, 255), Color3.fromRGB(100, 255, 255), Color3.fromRGB(255, 150, 150), Color3.fromRGB(150, 255, 150), Color3.fromRGB(150, 150, 255),
        Color3.fromRGB(255, 255, 150), Color3.fromRGB(255, 150, 255), Color3.fromRGB(150, 255, 255), Color3.fromRGB(200, 150, 100), Color3.fromRGB(100, 200, 150), Color3.fromRGB(150, 100, 200),
        Color3.fromRGB(50, 50, 50), Color3.fromRGB(75, 75, 75), Color3.fromRGB(100, 100, 100), Color3.fromRGB(125, 125, 125), Color3.fromRGB(150, 150, 150),
        Color3.fromRGB(175, 175, 175), Color3.fromRGB(200, 200, 200), Color3.fromRGB(225, 225, 225), Color3.fromRGB(250, 250, 250), Color3.fromRGB(240, 240, 240),
        Color3.fromRGB(230, 230, 230), Color3.fromRGB(220, 220, 220), Color3.fromRGB(210, 210, 210), Color3.fromRGB(190, 190, 190), Color3.fromRGB(180, 180, 180),
        Color3.fromRGB(170, 170, 170), Color3.fromRGB(160, 160, 160), Color3.fromRGB(140, 140, 140), Color3.fromRGB(130, 130, 130), Color3.fromRGB(110, 110, 110),
        Color3.fromRGB(90, 90, 90), Color3.fromRGB(80, 80, 80), Color3.fromRGB(70, 70, 70), Color3.fromRGB(60, 60, 60), Color3.fromRGB(40, 40, 40),
        Color3.fromRGB(30, 30, 30), Color3.fromRGB(20, 20, 20), Color3.fromRGB(10, 10, 10)
    }

    for _, color in ipairs(presetColors) do
        local presetButton = Instance.new("TextButton")
        presetButton.Size = UDim2.new(0, 40, 0, 40)
        presetButton.BackgroundColor3 = color
        presetButton.BorderSizePixel = 0
        presetButton.Text = ""
        presetButton.ZIndex = 102
        presetButton.Parent = presetFrame

        local presetCorner = Instance.new("UICorner")
        presetCorner.CornerRadius = UDim.new(0, 6)
        presetCorner.Parent = presetButton

        presetButton.MouseButton1Click:Connect(function()
            onColorChanged(color)
            picker.Visible = false
        end)
    end

    presetFrame.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y)

    if connections and type(connections) == "table" and connections[name .. "Close"] then
        connections[name .. "Close"]:Disconnect()
        connections[name .. "Close"] = nil
    end
    if UserInputService then
        connections[name .. "Close"] = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if picker and picker.Visible and not gameProcessedEvent then
                    local mousePos = input.Position
                    local pickerPos = picker.AbsolutePosition
                    local pickerSize = picker.AbsoluteSize
                    
                    if mousePos.X < pickerPos.X or mousePos.X > pickerPos.X + pickerSize.X or
                       mousePos.Y < pickerPos.Y or mousePos.Y > pickerPos.Y + pickerSize.Y then
                        picker.Visible = false
                    end
                end
            end
        end)
    else
        warn("Error: UserInputService is nil, cannot connect InputBegan for color picker close")
    end

    return picker
end

-- Function to create buttons for Visual features
function Visual.loadVisualButtons(createToggleButton)
    print("Loading visual buttons")
    
    if not createToggleButton then
        warn("Error: createToggleButton not provided! Buttons will not be created.")
        return
    end
    
    if not ScrollFrame then
        warn("Error: ScrollFrame is nil, cannot create buttons")
        return
    end
    
    if not connections or type(connections) ~= "table" then
        warn("Warning: connections is nil or not a table, initializing as empty table")
        connections = {}
    end
    
    createToggleButton("Freecam", toggleFreecam)
    createToggleButton("NoClipCamera", toggleNoClipCamera)
    createToggleButton("Fullbright", toggleFullbright)
    createToggleButton("Flashlight", toggleFlashlight)
    createToggleButton("Low Detail Mode", toggleLowDetail)
    createToggleButton("Ultra Low Detail Mode", toggleUltraLowDetail)
    createToggleButton("ESP", toggleESP)
    createToggleButton("XRay", toggleXRay)
    createToggleButton("Void", toggleVoid)
    createToggleButton("Hide All Nicknames", toggleHideAllNicknames)
    createToggleButton("Hide Own Nickname", toggleHideOwnNickname)
    createToggleButton("Hide All Characters Except Self", toggleHideAllCharactersExceptSelf)
    createToggleButton("Hide Self Character", toggleHideSelfCharacter)
    createToggleButton("Hide Bubble Chat", toggleHideBubbleChat)
    createToggleButton("Morning Mode", toggleMorning)
    createToggleButton("Day Mode", toggleDay)
    createToggleButton("Evening Mode", toggleEvening)
    createToggleButton("Night Mode", toggleNight)
    createToggleButton("Self Highlight", toggleSelfHighlight)

    -- Create self highlight color picker button
    local colorButton = Instance.new("TextButton")
    colorButton.Name = "SelfHighlightColorButton"
    colorButton.Size = UDim2.new(1, 0, 0, 30)
    colorButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    colorButton.Text = "Self Outline Color: " .. toHex(Visual.selfHighlightColor)
    colorButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    colorButton.TextSize = 14
    colorButton.Font = Enum.Font.SourceSans
    colorButton.BorderSizePixel = 0
    colorButton.Parent = ScrollFrame

    local colorCorner = Instance.new("UICorner")
    colorCorner.CornerRadius = UDim.new(0, 4)
    colorCorner.Parent = colorButton

    if not ScreenGui then
        warn("Error: ScreenGui is nil, cannot create color pickers")
        return
    end

    -- Create color pickers
    colorPicker = createColorPicker("Self Highlight", Visual.selfHighlightColor, function(newColor)
        Visual.selfHighlightColor = newColor
        if Visual.selfHighlightEnabled then
            createSelfHighlight()
        end
        colorButton.Text = "Self Outline Color: " .. toHex(newColor)
    end)

    colorButton.MouseButton1Click:Connect(function()
        if colorPicker then
            colorPicker.Visible = true
        end
    end)
end

-- Export functions for external access
Visual.toggleFreecam = toggleFreecam
Visual.toggleNoClipCamera = toggleNoClipCamera
Visual.toggleFullbright = toggleFullbright
Visual.toggleFlashlight = toggleFlashlight
Visual.toggleLowDetail = toggleLowDetail
Visual.toggleUltraLowDetail = toggleUltraLowDetail
Visual.toggleESP = toggleESP
Visual.toggleXRay = toggleXRay
Visual.toggleVoid = toggleVoid
Visual.toggleHideAllNicknames = toggleHideAllNicknames
Visual.toggleHideOwnNickname = toggleHideOwnNickname
Visual.toggleHideAllCharactersExceptSelf = toggleHideAllCharactersExceptSelf
Visual.toggleHideSelfCharacter = toggleHideSelfCharacter
Visual.toggleHideBubbleChat = toggleHideBubbleChat
Visual.toggleSelfHighlight = toggleSelfHighlight
Visual.setTimeMode = setTimeMode

-- Function to reset Visual states
function Visual.resetStates()
    Visual.freecamEnabled = false
    Visual.noClipCameraEnabled = false
    Visual.fullbrightEnabled = false
    Visual.flashlightEnabled = false
    Visual.lowDetailEnabled = false
    Visual.ultraLowDetailEnabled = false
    Visual.espEnabled = false
    Visual.xrayEnabled = false
    Visual.voidEnabled = false
    Visual.hideAllNicknames = false
    Visual.hideOwnNickname = false
    Visual.hideAllCharactersExceptSelf = false
    Visual.hideSelfCharacter = false
    Visual.hideBubbleChat = false
    Visual.currentTimeMode = "normal"
    Visual.selfHighlightEnabled = false
    
    if connections and type(connections) == "table" then
        for key, connection in pairs(connections) do
            if connection then
                pcall(function() connection:Disconnect() end)
                connections[key] = nil
            end
        end
    end
    connections = {}
    
    toggleFreecam(false)
    toggleNoClipCamera(false)
    toggleFullbright(false)
    toggleFlashlight(false)
    toggleLowDetail(false)
    toggleUltraLowDetail(false)
    toggleESP(false)
    toggleXRay(false)
    toggleVoid(false)
    toggleHideAllNicknames(false)
    toggleHideOwnNickname(false)
    toggleHideAllCharactersExceptSelf(false)
    toggleHideSelfCharacter(false)
    toggleHideBubbleChat(false)
    toggleSelfHighlight(false)
    setTimeMode("normal")
    
    if colorPicker then
        colorPicker:Destroy()
        colorPicker = nil
    end
end

-- Function to update references after character respawn
function Visual.updateReferences()
    print("Updating Visual module references")
    
    -- Update character, humanoid, and rootPart
    Visual.character = player and player.Character
    humanoid = Visual.character and Visual.character:FindFirstChild("Humanoid")
    rootPart = Visual.character and Visual.character:FindFirstChild("HumanoidRootPart")
    
    -- Debug references
    print("Updated character:", Visual.character and "OK" or "FAILED")
    print("Updated humanoid:", humanoid and "OK" or "FAILED")
    print("Updated rootPart:", rootPart and "OK" or "FAILED")
    
    -- Restore feature states
    local wasFreecamEnabled = Visual.freecamEnabled
    local wasNoClipCameraEnabled = Visual.noClipCameraEnabled
    local wasFullbrightEnabled = Visual.fullbrightEnabled
    local wasFlashlightEnabled = Visual.flashlightEnabled
    local wasLowDetailEnabled = Visual.lowDetailEnabled
    local wasUltraLowDetailEnabled = Visual.ultraLowDetailEnabled
    local wasEspEnabled = Visual.espEnabled
    local wasXRayEnabled = Visual.xrayEnabled
    local wasVoidEnabled = Visual.voidEnabled
    local wasHideAllNicknames = Visual.hideAllNicknames
    local wasHideOwnNickname = Visual.hideOwnNickname
    local wasHideAllCharactersExceptSelf = Visual.hideAllCharactersExceptSelf
    local wasHideSelfCharacter = Visual.hideSelfCharacter
    local wasHideBubbleChat = Visual.hideBubbleChat
    local wasSelfHighlightEnabled = Visual.selfHighlightEnabled
    local currentTimeMode = Visual.currentTimeMode
    
    -- Reset states to ensure clean slate
    Visual.resetStates()
    
    -- Re-enable features that were active
    if wasFreecamEnabled then
        print("Re-enabling Freecam after respawn")
        toggleFreecam(true)
    end
    if wasNoClipCameraEnabled then
        print("Re-enabling NoClipCamera after respawn")
        toggleNoClipCamera(true)
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
    if wasUltraLowDetailEnabled then
        print("Re-enabling Ultra Low Detail Mode after respawn")
        toggleUltraLowDetail(true)
    end
    if wasEspEnabled then
        print("Re-enabling ESP after respawn")
        toggleESP(true)
    end
    if wasXRayEnabled then
        print("Re-enabling XRay after respawn")
        toggleXRay(true)
    end
    if wasVoidEnabled then
        print("Re-enabling Void after respawn")
        toggleVoid(true)
    end
    if wasHideAllNicknames then
        print("Re-enabling Hide All Nicknames after respawn")
        toggleHideAllNicknames(true)
    end
    if wasHideOwnNickname then
        print("Re-enabling Hide Own Nickname after respawn")
        toggleHideOwnNickname(true)
    end
    if wasHideAllCharactersExceptSelf then
        print("Re-enabling Hide All Characters Except Self after respawn")
        toggleHideAllCharactersExceptSelf(true)
    end
    if wasHideSelfCharacter then
        print("Re-enabling Hide Self Character after respawn")
        toggleHideSelfCharacter(true)
    end
    if wasHideBubbleChat then
        print("Re-enabling Hide Bubble Chat after respawn")
        toggleHideBubbleChat(true)
    end
    if wasSelfHighlightEnabled then
        print("Re-enabling Self Highlight after respawn")
        toggleSelfHighlight(true)
    end
    if currentTimeMode ~= "normal" then
        print("Restoring Time Mode after respawn:", currentTimeMode)
        setTimeMode(currentTimeMode)
    end
    
    print("Visual module references updated")
end

-- Function to cleanup all resources
function Visual.cleanup()
    print("Cleaning up Visual module")
    
    -- Reset all states
    Visual.resetStates()
    
    -- Clean up joystick
    if joystickFrame then
        joystickFrame:Destroy()
        joystickFrame = nil
        joystickKnob = nil
    end
    
    -- Clean up flashlight
    if flashlight then
        flashlight:Destroy()
        flashlight = nil
    end
    if pointLight then
        pointLight:Destroy()
        pointLight = nil
    end
    
    -- Clean up self highlight
    if selfHighlight then
        selfHighlight:Destroy()
        selfHighlight = nil
    end
    
    -- Clean up ESP highlights
    for _, highlight in pairs(espHighlights) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    espHighlights = {}
    
    -- Clean up character transparencies
    characterTransparencies = {}
    
    -- Clean up xray transparencies
    xrayTransparencies = {}
    
    -- Clean up void states
    voidStates = {}
    
    -- Clean up foliage states
    foliageStates = {}
    processedObjects = {}
    
    -- Restore default lighting settings
    if defaultLightingSettings.stored then
        for property, value in pairs(defaultLightingSettings) do
            if property ~= "stored" then
                pcall(function()
                    Lighting[property] = value
                end)
            end
        end
        pcall(function()
            Workspace.StreamingEnabled = defaultLightingSettings.StreamingEnabled or false
            Workspace.StreamingMinRadius = defaultLightingSettings.StreamingMinRadius or 128
            Workspace.StreamingTargetRadius = defaultLightingSettings.StreamingTargetRadius or 256
            Workspace.Terrain.Decoration = defaultLightingSettings.TerrainDecoration or true
        end)
    end
    
    -- Restore bubble chat
    if Chat then
        Chat.BubbleChatEnabled = originalBubbleChatEnabled
    end
    
    -- Clean up color pickers
    if colorPicker then
        colorPicker:Destroy()
        colorPicker = nil
    end
    
    -- Disconnect any remaining connections
    if connections and type(connections) == "table" then
        for key, connection in pairs(connections) do
            if connection then
                pcall(function() connection:Disconnect() end)
                connections[key] = nil
            end
        end
    end
    connections = {}
    
    print("Visual module cleanup completed")
end

-- Function to check if module is initialized
function Visual.isInitialized()
    local isInitialized = Players and UserInputService and RunService and Workspace and Lighting and ScrollFrame and ScreenGui and player
    if not isInitialized then
        warn("Visual module not fully initialized. Missing dependencies:")
        print("Players:", Players and "OK" or "FAILED")
        print("UserInputService:", UserInputService and "OK" or "FAILED")
        print("RunService:", RunService and "OK" or "FAILED")
        print("Workspace:", Workspace and "OK" or "FAILED")
        print("Lighting:", Lighting and "OK" or "FAILED")
        print("ScrollFrame:", ScrollFrame and "OK" or "FAILED")
        print("ScreenGui:", ScreenGui and "OK" or "FAILED")
        print("player:", player and "OK" or "FAILED")
    end
    return isInitialized
end

-- Function to get current state of all features
function Visual.getState()
    return {
        freecamEnabled = Visual.freecamEnabled,
        noClipCameraEnabled = Visual.noClipCameraEnabled,
        fullbrightEnabled = Visual.fullbrightEnabled,
        flashlightEnabled = Visual.flashlightEnabled,
        lowDetailEnabled = Visual.lowDetailEnabled,
        ultraLowDetailEnabled = Visual.ultraLowDetailEnabled,
        espEnabled = Visual.espEnabled,
        xrayEnabled = Visual.xrayEnabled,
        voidEnabled = Visual.voidEnabled,
        hideAllNicknames = Visual.hideAllNicknames,
        hideOwnNickname = Visual.hideOwnNickname,
        hideAllCharactersExceptSelf = Visual.hideAllCharactersExceptSelf,
        hideSelfCharacter = Visual.hideSelfCharacter,
        hideBubbleChat = Visual.hideBubbleChat,
        selfHighlightEnabled = Visual.selfHighlightEnabled,
        currentTimeMode = Visual.currentTimeMode,
        selfHighlightColor = Visual.selfHighlightColor
    }
end

-- Function to set self highlight color programmatically
function Visual.setSelfHighlightColor(color)
    if typeof(color) == "Color3" then
        Visual.selfHighlightColor = color
        if Visual.selfHighlightEnabled then
            createSelfHighlight()
        end
        print("Self Highlight color set to:", toHex(color))
    else
        warn("Error: Invalid color provided for setSelfHighlightColor")
    end
end

-- Export the module
return Visual