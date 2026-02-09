local Movement = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local character, humanoid, rootPart

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local flySpeed = 50
local sprintSpeed = 100
local boostSpeed = 150
local swimSpeed = 100
local wallClimbSpeed = 30
local slowFallSpeed = -10
local fastFallSpeed = -100
local moonGravityMultiplier = 1/6
local maxDoubleJumps = 1
local jumpCount = 0

local flyBodyVelocity, flyBodyGyro
local flyKeys = {w = false, s = false, a = false, d = false, space = false, shift = false}
local floatKeys = {w = false, s = false, a = false, d = false, space = false, shift = false}
local sprintActive = false
local connections = {}

local defaultWalkSpeed = 16
local defaultJumpPower = 50
local defaultGravity = 196.2

local positionHistory = {}
local maxHistorySize = 300
local rewindActive = false
local persistFeatures = false

local flyJoystick, flyJoystickKnob, flyUpButton, flyDownButton
local joystickDelta = Vector2.new(0, 0)
local isTouchingJoystick = false
local joystickTouchId = nil

local function initCharacter()
    character = player.Character or player.CharacterAdded:Wait()
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    defaultWalkSpeed = humanoid.WalkSpeed
    defaultJumpPower = humanoid.JumpPower
end

local function createMobileControls()
    if not isMobile then return end
    
    local ScreenGui = player.PlayerGui:FindFirstChild("FluentMobileControls")
    if not ScreenGui then
        ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "FluentMobileControls"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.Parent = player.PlayerGui
    end
    
    if flyJoystick then flyJoystick:Destroy() end
    if flyUpButton then flyUpButton:Destroy() end
    if flyDownButton then flyDownButton:Destroy() end
    
    flyJoystick = Instance.new("Frame")
    flyJoystick.Name = "FlyJoystick"
    flyJoystick.Size = UDim2.new(0, 100, 0, 100)
    flyJoystick.Position = UDim2.new(0, 20, 1, -130)
    flyJoystick.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flyJoystick.BackgroundTransparency = 0.5
    flyJoystick.BorderSizePixel = 0
    flyJoystick.Visible = false
    flyJoystick.ZIndex = 10
    flyJoystick.Parent = ScreenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = flyJoystick
    
    flyJoystickKnob = Instance.new("Frame")
    flyJoystickKnob.Name = "Knob"
    flyJoystickKnob.Size = UDim2.new(0, 40, 0, 40)
    flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
    flyJoystickKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flyJoystickKnob.BackgroundTransparency = 0.1
    flyJoystickKnob.BorderSizePixel = 0
    flyJoystickKnob.ZIndex = 11
    flyJoystickKnob.Parent = flyJoystick
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0.5, 0)
    knobCorner.Parent = flyJoystickKnob
    
    flyUpButton = Instance.new("TextButton")
    flyUpButton.Name = "FlyUpButton"
    flyUpButton.Size = UDim2.new(0, 50, 0, 50)
    flyUpButton.Position = UDim2.new(0, 130, 1, -180)
    flyUpButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flyUpButton.BackgroundTransparency = 0.5
    flyUpButton.BorderSizePixel = 0
    flyUpButton.Text = "↑"
    flyUpButton.Font = Enum.Font.GothamBold
    flyUpButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    flyUpButton.TextSize = 20
    flyUpButton.Visible = false
    flyUpButton.ZIndex = 10
    flyUpButton.Parent = ScreenGui
    
    local upCorner = Instance.new("UICorner")
    upCorner.CornerRadius = UDim.new(0.2, 0)
    upCorner.Parent = flyUpButton
    
    flyDownButton = Instance.new("TextButton")
    flyDownButton.Name = "FlyDownButton"
    flyDownButton.Size = UDim2.new(0, 50, 0, 50)
    flyDownButton.Position = UDim2.new(0, 130, 1, -120)
    flyDownButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    flyDownButton.BackgroundTransparency = 0.5
    flyDownButton.BorderSizePixel = 0
    flyDownButton.Text = "↓"
    flyDownButton.Font = Enum.Font.GothamBold
    flyDownButton.TextColor3 = Color3.fromRGB(0, 0, 0)
    flyDownButton.TextSize = 20
    flyDownButton.Visible = false
    flyDownButton.ZIndex = 10
    flyDownButton.Parent = ScreenGui
    
    local downCorner = Instance.new("UICorner")
    downCorner.CornerRadius = UDim.new(0.2, 0)
    downCorner.Parent = flyDownButton
end

local function handleJoystick(input, gameProcessed)
    if not flyJoystick or not flyJoystick.Visible then return end
    
    if input.UserInputType == Enum.UserInputType.Touch then
        local joystickCenter = flyJoystick.AbsolutePosition + flyJoystick.AbsoluteSize * 0.5
        local inputPos = Vector2.new(input.Position.X, input.Position.Y)
        local distanceFromCenter = (inputPos - joystickCenter).Magnitude
        
        if input.UserInputState == Enum.UserInputState.Begin then
            if distanceFromCenter <= 50 and not isTouchingJoystick then
                isTouchingJoystick = true
                joystickTouchId = input
            end
        elseif input.UserInputState == Enum.UserInputState.Change and isTouchingJoystick and input == joystickTouchId then
            local delta = inputPos - joystickCenter
            local magnitude = delta.Magnitude
            local maxRadius = 30
            
            if magnitude > maxRadius then
                delta = delta * (maxRadius / magnitude)
            end
            
            flyJoystickKnob.Position = UDim2.new(0.5, delta.X - 20, 0.5, delta.Y - 20)
            joystickDelta = delta / maxRadius
        elseif input.UserInputState == Enum.UserInputState.End and input == joystickTouchId then
            isTouchingJoystick = false
            joystickTouchId = nil
            flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
            joystickDelta = Vector2.new(0, 0)
        end
    end
end

local function notify(title, message)
    if Movement.Fluent then
        Movement.Fluent:Notify({
            Title = title,
            Content = message,
            Duration = 3
        })
    end
end

local function sendServerMessage(message)
    local StarterGui = game:GetService("StarterGui")
    pcall(function()
        StarterGui:SetCore("ChatMakeSystemMessage", {
            Text = "[SERVER] " .. message,
            Color = Color3.fromRGB(0, 255, 0),
            Font = Enum.Font.GothamBold,
            FontSize = Enum.FontSize.Size18
        })
    end)
end

local function cleanupFly()
    if connections.fly then connections.fly:Disconnect() connections.fly = nil end
    if connections.flyInput then connections.flyInput:Disconnect() connections.flyInput = nil end
    if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
    if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end
    flyKeys = {w = false, s = false, a = false, d = false, space = false, shift = false}
end

local function toggleSpeed(enabled, speed)
    if enabled then
        if humanoid then
            humanoid.WalkSpeed = speed or 50
        end
    else
        if humanoid then
            humanoid.WalkSpeed = defaultWalkSpeed
        end
    end
end

local function toggleJump(enabled, power)
    if enabled then
        if humanoid then
            humanoid.JumpPower = power or 100
        end
    else
        if humanoid then
            humanoid.JumpPower = defaultJumpPower
        end
    end
end

local function toggleFly(enabled)
    cleanupFly()
    
    if enabled then
        sendServerMessage("FLY ACTIVATED")
        notify("Fly Enabled", "Use WASD, Space, Shift to fly")
        
        if not humanoid or not rootPart then return end
        
        humanoid.PlatformStand = true
        
        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        flyBodyVelocity.Parent = rootPart
        
        flyBodyGyro = Instance.new("BodyGyro")
        flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        flyBodyGyro.P = 10000
        flyBodyGyro.CFrame = rootPart.CFrame
        flyBodyGyro.Parent = rootPart
        
        if isMobile then
            if flyJoystick then flyJoystick.Visible = true end
            if flyUpButton then flyUpButton.Visible = true end
            if flyDownButton then flyDownButton.Visible = true end
        end
        
        connections.fly = RunService.Heartbeat:Connect(function()
            if not flyBodyVelocity or not flyBodyVelocity.Parent then
                flyBodyVelocity = Instance.new("BodyVelocity")
                flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                flyBodyVelocity.Parent = rootPart
            end
            
            if not flyBodyGyro or not flyBodyGyro.Parent then
                flyBodyGyro = Instance.new("BodyGyro")
                flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                flyBodyGyro.P = 10000
                flyBodyGyro.CFrame = rootPart.CFrame
                flyBodyGyro.Parent = rootPart
            end
            
            local camera = Workspace.CurrentCamera
            if not camera then return end
            
            flyBodyGyro.CFrame = camera.CFrame
            
            local moveVector = Vector3.new(0, 0, 0)
            
            if isMobile and joystickDelta.Magnitude > 0.05 then
                moveVector = moveVector + (camera.CFrame.RightVector * joystickDelta.X) + (camera.CFrame.LookVector * -joystickDelta.Y)
            end
            
            if flyKeys.w then moveVector = moveVector + camera.CFrame.LookVector end
            if flyKeys.s then moveVector = moveVector - camera.CFrame.LookVector end
            if flyKeys.a then moveVector = moveVector - camera.CFrame.RightVector end
            if flyKeys.d then moveVector = moveVector + camera.CFrame.RightVector end
            if flyKeys.space then moveVector = moveVector + Vector3.new(0, 1, 0) end
            if flyKeys.shift then moveVector = moveVector - Vector3.new(0, 1, 0) end
            
            if moveVector.Magnitude > 0 then
                flyBodyVelocity.Velocity = moveVector.Unit * flySpeed
            else
                flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end)
        
        connections.flyInput = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == Enum.KeyCode.W then flyKeys.w = true
            elseif input.KeyCode == Enum.KeyCode.S then flyKeys.s = true
            elseif input.KeyCode == Enum.KeyCode.A then flyKeys.a = true
            elseif input.KeyCode == Enum.KeyCode.D then flyKeys.d = true
            elseif input.KeyCode == Enum.KeyCode.Space then flyKeys.space = true
            elseif input.KeyCode == Enum.KeyCode.LeftShift then flyKeys.shift = true
            end
        end)
        
        UserInputService.InputEnded:Connect(function(input)
            if input.KeyCode == Enum.KeyCode.W then flyKeys.w = false
            elseif input.KeyCode == Enum.KeyCode.S then flyKeys.s = false
            elseif input.KeyCode == Enum.KeyCode.A then flyKeys.a = false
            elseif input.KeyCode == Enum.KeyCode.D then flyKeys.d = false
            elseif input.KeyCode == Enum.KeyCode.Space then flyKeys.space = false
            elseif input.KeyCode == Enum.KeyCode.LeftShift then flyKeys.shift = false
            end
        end)
        
        if isMobile then
            UserInputService.InputBegan:Connect(handleJoystick)
            UserInputService.InputChanged:Connect(handleJoystick)
            UserInputService.InputEnded:Connect(handleJoystick)
            
            flyUpButton.MouseButton1Down:Connect(function() flyKeys.space = true end)
            flyUpButton.MouseButton1Up:Connect(function() flyKeys.space = false end)
            flyDownButton.MouseButton1Down:Connect(function() flyKeys.shift = true end)
            flyDownButton.MouseButton1Up:Connect(function() flyKeys.shift = false end)
        end
    else
        sendServerMessage("FLY DEACTIVATED")
        if humanoid then
            humanoid.PlatformStand = false
        end
        if isMobile then
            if flyJoystick then flyJoystick.Visible = false end
            if flyUpButton then flyUpButton.Visible = false end
            if flyDownButton then flyDownButton.Visible = false end
        end
    end
end

local function toggleNoclip(enabled)
    if connections.noclip then connections.noclip:Disconnect() connections.noclip = nil end
    
    if enabled then
        connections.noclip = RunService.Stepped:Connect(function()
            if character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

local function toggleInfiniteJump(enabled)
    if connections.infiniteJump then connections.infiniteJump:Disconnect() connections.infiniteJump = nil end
    
    if enabled then
        connections.infiniteJump = UserInputService.JumpRequest:Connect(function()
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end

local function toggleSprint(enabled)
    if connections.sprint then connections.sprint:Disconnect() connections.sprint = nil end
    
    if enabled then
        connections.sprint = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == Enum.KeyCode.LeftShift then
                sprintActive = not sprintActive
                if humanoid then
                    humanoid.WalkSpeed = sprintActive and sprintSpeed or defaultWalkSpeed
                end
                notify("Sprint", sprintActive and "Enabled" or "Disabled")
            end
        end)
    else
        sprintActive = false
        if humanoid then
            humanoid.WalkSpeed = defaultWalkSpeed
        end
    end
end

local function toggleBoost()
    if humanoid and rootPart then
        local camera = Workspace.CurrentCamera
        if camera then
            local boostForce = Instance.new("BodyVelocity")
            boostForce.MaxForce = Vector3.new(4000, 0, 4000)
            boostForce.Velocity = Vector3.new(camera.CFrame.LookVector.X * boostSpeed, 0, camera.CFrame.LookVector.Z * boostSpeed)
            boostForce.Parent = rootPart
            game:GetService("Debris"):AddItem(boostForce, 0.5)
            notify("Boost", "Speed boost activated!")
        end
    end
end

local function toggleRewind(enabled)
    if connections.rewind then connections.rewind:Disconnect() connections.rewind = nil end
    if connections.rewindInput then connections.rewindInput:Disconnect() connections.rewindInput = nil end
    
    if enabled then
        positionHistory = {}
        
        connections.rewind = RunService.Heartbeat:Connect(function()
            if rootPart then
                table.insert(positionHistory, {
                    cframe = rootPart.CFrame,
                    time = tick()
                })
                
                while #positionHistory > maxHistorySize do
                    table.remove(positionHistory, 1)
                end
            end
        end)
        
        connections.rewindInput = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == Enum.KeyCode.R then
                if #positionHistory < 30 then return end
                
                rewindActive = true
                notify("Rewind", "Rewinding position...")
                
                local reversedHistory = {}
                for i = #positionHistory, 1, -1 do
                    table.insert(reversedHistory, positionHistory[i])
                end
                
                local startTime = tick()
                local rewindDuration = 2
                local historyLength = #reversedHistory
                
                local rewindConnection
                rewindConnection = RunService.Heartbeat:Connect(function()
                    if not rewindActive or not rootPart then
                        rewindConnection:Disconnect()
                        positionHistory = {}
                        return
                    end
                    
                    local elapsed = tick() - startTime
                    local progress = math.min(elapsed / rewindDuration, 1)
                    
                    local index = progress * (historyLength - 1) + 1
                    local floorIndex = math.floor(index)
                    local ceilIndex = math.ceil(index)
                    local frac = index - floorIndex
                    
                    local targetCFrame
                    if ceilIndex <= historyLength then
                        local c1 = reversedHistory[floorIndex].cframe
                        local c2 = reversedHistory[ceilIndex].cframe
                        targetCFrame = c1:Lerp(c2, frac)
                    else
                        targetCFrame = reversedHistory[historyLength].cframe
                    end
                    
                    rootPart.CFrame = targetCFrame
                    rootPart.Velocity = Vector3.new(0, 0, 0)
                    
                    if progress >= 1 then
                        rewindConnection:Disconnect()
                        positionHistory = {}
                        rewindActive = false
                        notify("Rewind", "Rewind complete!")
                    end
                end)
            end
        end)
    else
        positionHistory = {}
        rewindActive = false
    end
end

local function toggleFullbright(enabled)
    if enabled then
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    else
        Lighting.Ambient = Color3.new(0, 0, 0)
        Lighting.Brightness = 1
        Lighting.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)
    end
end

local function toggleMoonGravity(enabled)
    if enabled then
        Workspace.Gravity = defaultGravity * moonGravityMultiplier
    else
        Workspace.Gravity = defaultGravity
    end
end

local function toggleDoubleJump(enabled)
    if connections.doubleJump then connections.doubleJump:Disconnect() connections.doubleJump = nil end
    
    if enabled then
        connections.doubleJump = UserInputService.JumpRequest:Connect(function()
            if not humanoid then return end
            
            if humanoid:GetState() ~= Enum.HumanoidStateType.Jumping and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
                jumpCount = 0
            elseif jumpCount < maxDoubleJumps then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                jumpCount = jumpCount + 1
            end
        end)
    else
        jumpCount = 0
    end
end

local function toggleWallClimb(enabled)
    if connections.wallClimb then connections.wallClimb:Disconnect() connections.wallClimb = nil end
    
    if enabled then
        connections.wallClimb = RunService.Heartbeat:Connect(function()
            if not humanoid or not rootPart then return end
            
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            
            local directions = {
                rootPart.CFrame.RightVector,
                -rootPart.CFrame.RightVector,
                rootPart.CFrame.LookVector,
                -rootPart.CFrame.LookVector
            }
            
            local isNearWall = false
            for _, direction in ipairs(directions) do
                local raycast = Workspace:Raycast(rootPart.Position, direction * 3, raycastParams)
                if raycast and raycast.Instance and raycast.Normal.Y < 0.1 then
                    isNearWall = true
                    break
                end
            end
            
            if isNearWall then
                rootPart.Velocity = Vector3.new(rootPart.Velocity.X, wallClimbSpeed, rootPart.Velocity.Z)
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end

local function togglePlayerNoclip(enabled)
    if connections.playerNoclip then connections.playerNoclip:Disconnect() connections.playerNoclip = nil end
    if connections.antiFling then connections.antiFling:Disconnect() connections.antiFling = nil end
    
    if enabled then
        connections.playerNoclip = RunService.Heartbeat:Connect(function()
            if not character then return end
            
            for _, otherPlayer in pairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character then
                    for _, part in pairs(otherPlayer.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end
        end)
        
        connections.antiFling = RunService.Heartbeat:Connect(function()
            if not rootPart then return end
            
            local currentVelocity = rootPart.Velocity
            local maxNormalVelocity = 200
            
            if currentVelocity.Magnitude > maxNormalVelocity then
                rootPart.Velocity = Vector3.new(0, 0, 0)
            end
        end)
    else
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= player and otherPlayer.Character then
                for _, part in pairs(otherPlayer.Character:GetChildren()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end
    end
end

local function toggleWalkOnWater(enabled)
    if connections.walkOnWater then connections.walkOnWater:Disconnect() connections.walkOnWater = nil end
    
    if humanoid then
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, not enabled)
    end
    
    if enabled then
        connections.walkOnWater = RunService.Heartbeat:Connect(function()
            if not rootPart or not character then return end
            
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            
            local raycast = Workspace:Raycast(rootPart.Position, Vector3.new(0, -20, 0), raycastParams)
            if raycast and raycast.Instance and (raycast.Instance.Material == Enum.Material.Water or string.lower(raycast.Instance.Name):find("water")) then
                local waterWalkPart = rootPart:FindFirstChild("WaterWalkPart")
                if not waterWalkPart then
                    waterWalkPart = Instance.new("Part")
                    waterWalkPart.Name = "WaterWalkPart"
                    waterWalkPart.Anchored = true
                    waterWalkPart.CanCollide = true
                    waterWalkPart.Transparency = 1
                    waterWalkPart.Size = Vector3.new(15, 0.2, 15)
                    waterWalkPart.Parent = rootPart
                end
                waterWalkPart.Position = Vector3.new(rootPart.Position.X, raycast.Position.Y + 0.1, rootPart.Position.Z)
            end
        end)
    end
end

local function toggleSuperSwim(enabled)
    if connections.superSwim then connections.superSwim:Disconnect() connections.superSwim = nil end
    
    if enabled then
        connections.superSwim = RunService.Heartbeat:Connect(function()
            if not humanoid then return end
            
            if humanoid:GetState() == Enum.HumanoidStateType.Swimming then
                humanoid.WalkSpeed = swimSpeed
            else
                humanoid.WalkSpeed = sprintActive and sprintSpeed or defaultWalkSpeed
            end
        end)
    else
        if humanoid then
            humanoid.WalkSpeed = defaultWalkSpeed
        end
    end
end

local function toggleFloat(enabled)
    if connections.float then connections.float:Disconnect() connections.float = nil end
    if connections.floatInput then connections.floatInput:Disconnect() connections.floatInput = nil end
    
    floatKeys = {w = false, s = false, a = false, d = false, space = false, shift = false}
    
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    
    if enabled then
        if not humanoid or not rootPart then return end
        
        humanoid.PlatformStand = true
        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        flyBodyVelocity.Parent = rootPart
        
        if isMobile then
            if flyJoystick then flyJoystick.Visible = true end
            if flyUpButton then flyUpButton.Visible = true end
            if flyDownButton then flyDownButton.Visible = true end
        end
        
        connections.float = RunService.Heartbeat:Connect(function()
            if not rootPart or not humanoid then return end
            
            if not flyBodyVelocity or flyBodyVelocity.Parent ~= rootPart then
                flyBodyVelocity = Instance.new("BodyVelocity")
                flyBodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
                flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                flyBodyVelocity.Parent = rootPart
            end
            
            local camera = Workspace.CurrentCamera
            if not camera then return end
            
            local floatDirection = Vector3.new(0, 0, 0)
            
            if isMobile and joystickDelta.Magnitude > 0.05 then
                local forward = camera.CFrame.LookVector
                local right = camera.CFrame.RightVector
                forward = Vector3.new(forward.X, 0, forward.Z).Unit
                right = Vector3.new(right.X, 0, right.Z).Unit
                floatDirection = floatDirection + (right * joystickDelta.X) + (forward * -joystickDelta.Y)
            end
            
            local flatLook = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit
            local flatRight = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z).Unit
            
            if floatKeys.w then floatDirection = floatDirection + flatLook end
            if floatKeys.s then floatDirection = floatDirection - flatLook end
            if floatKeys.a then floatDirection = floatDirection - flatRight end
            if floatKeys.d then floatDirection = floatDirection + flatRight end
            if floatKeys.space then floatDirection = floatDirection + Vector3.new(0, 1, 0) end
            if floatKeys.shift then floatDirection = floatDirection - Vector3.new(0, 1, 0) end
            
            if floatDirection.Magnitude > 0 then
                flyBodyVelocity.Velocity = floatDirection.Unit * flySpeed
            else
                flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end)
        
        connections.floatInput = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == Enum.KeyCode.W then floatKeys.w = true
            elseif input.KeyCode == Enum.KeyCode.S then floatKeys.s = true
            elseif input.KeyCode == Enum.KeyCode.A then floatKeys.a = true
            elseif input.KeyCode == Enum.KeyCode.D then floatKeys.d = true
            elseif input.KeyCode == Enum.KeyCode.Space then floatKeys.space = true
            elseif input.KeyCode == Enum.KeyCode.LeftShift then floatKeys.shift = true
            end
        end)
        
        UserInputService.InputEnded:Connect(function(input)
            if input.KeyCode == Enum.KeyCode.W then floatKeys.w = false
            elseif input.KeyCode == Enum.KeyCode.S then floatKeys.s = false
            elseif input.KeyCode == Enum.KeyCode.A then floatKeys.a = false
            elseif input.KeyCode == Enum.KeyCode.D then floatKeys.d = false
            elseif input.KeyCode == Enum.KeyCode.Space then floatKeys.space = false
            elseif input.KeyCode == Enum.KeyCode.LeftShift then floatKeys.shift = false
            end
        end)
        
        if isMobile then
            UserInputService.InputBegan:Connect(handleJoystick)
            UserInputService.InputChanged:Connect(handleJoystick)
            UserInputService.InputEnded:Connect(handleJoystick)
            
            flyUpButton.MouseButton1Down:Connect(function() floatKeys.space = true end)
            flyUpButton.MouseButton1Up:Connect(function() floatKeys.space = false end)
            flyDownButton.MouseButton1Down:Connect(function() floatKeys.shift = true end)
            flyDownButton.MouseButton1Up:Connect(function() floatKeys.shift = false end)
        end
    else
        if humanoid then
            humanoid.PlatformStand = false
        end
        if isMobile then
            if flyJoystick then flyJoystick.Visible = false end
            if flyUpButton then flyUpButton.Visible = false end
            if flyDownButton then flyDownButton.Visible = false end
        end
        joystickDelta = Vector2.new(0, 0)
    end
end

local function toggleSlowFall(enabled)
    if connections.slowFall then connections.slowFall:Disconnect() connections.slowFall = nil end
    
    if enabled then
        connections.slowFall = RunService.Heartbeat:Connect(function()
            if not rootPart or not humanoid then return end
            
            if rootPart.Velocity.Y < 0 then
                local slowFallVelocity = Instance.new("BodyVelocity")
                slowFallVelocity.MaxForce = Vector3.new(0, 4000, 0)
                slowFallVelocity.Velocity = Vector3.new(0, slowFallSpeed, 0)
                slowFallVelocity.Parent = rootPart
                game:GetService("Debris"):AddItem(slowFallVelocity, 0.1)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            end
        end)
    else
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        end
    end
end

local function toggleFastFall(enabled)
    if connections.fastFall then connections.fastFall:Disconnect() connections.fastFall = nil end
    
    if enabled then
        connections.fastFall = RunService.Heartbeat:Connect(function()
            if not rootPart or not humanoid then return end
            
            if rootPart.Velocity.Y < 0 then
                local fastFallVelocity = Instance.new("BodyVelocity")
                fastFallVelocity.MaxForce = Vector3.new(0, 4000, 0)
                fastFallVelocity.Velocity = Vector3.new(0, fastFallSpeed, 0)
                fastFallVelocity.Parent = rootPart
                game:GetService("Debris"):AddItem(fastFallVelocity, 0.1)
                humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            end
        end)
    else
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
        end
    end
end

local function setupChatCommands()
    if connections.chatCommand then connections.chatCommand:Disconnect() connections.chatCommand = nil end
    
    if player and player.Chatted then
        connections.chatCommand = player.Chatted:Connect(function(message)
            local args = {}
            for word in message:gmatch("%S+") do
                table.insert(args, word)
            end
            local cmd = string.lower(args[1] or "")
            
            if cmd == "/fly" then
                toggleFly(true)
            elseif cmd == "/unfly" then
                toggleFly(false)
            elseif cmd == "/flyspeed" then
                local val = tonumber(args[2])
                if val then
                    flySpeed = val
                    sendServerMessage("Fly speed set to " .. val)
                end
            elseif cmd == "/speed" then
                local val = tonumber(args[2])
                if val then
                    toggleSpeed(true, val)
                    sendServerMessage("Speed set to " .. val)
                end
            elseif cmd == "/jump" then
                local val = tonumber(args[2])
                if val then
                    toggleJump(true, val)
                    sendServerMessage("Jump power set to " .. val)
                end
            elseif cmd == "/boost" then
                toggleBoost()
            end
        end)
    end
end

function Movement.init(tab, deps)
    if not tab or not deps then
        warn("Movement: Missing tab or dependencies")
        return false
    end
    
    Movement.Fluent = deps.Fluent
    Movement.Window = deps.Window
    
    initCharacter()
    player.CharacterAdded:Connect(function()
        initCharacter()
        if isMobile then
            createMobileControls()
        end
    end)
    setupChatCommands()
    
    if isMobile then
        createMobileControls()
    end
    
    local MovementSection = tab:AddSection("Movement Controls")
    
    local SpeedToggle = tab:AddToggle("SpeedToggle", {
        Title = "Speed Hack",
        Description = "Increase movement speed",
        Default = false,
        Callback = function(Value)
            toggleSpeed(Value, flySpeed)
        end
    })
    
    local SpeedSlider = tab:AddSlider("SpeedSlider", {
        Title = "Speed Amount",
        Description = "Adjust speed",
        Default = 50,
        Min = 16,
        Max = 500,
        Rounding = 0,
        Callback = function(Value)
            if SpeedToggle.Value then
                toggleSpeed(true, Value)
            end
        end
    })
    
    local JumpToggle = tab:AddToggle("JumpToggle", {
        Title = "Jump Hack",
        Description = "Increase jump power",
        Default = false,
        Callback = function(Value)
            toggleJump(Value, 100)
        end
    })
    
    local JumpSlider = tab:AddSlider("JumpSlider", {
        Title = "Jump Power",
        Description = "Adjust jump power",
        Default = 100,
        Min = 50,
        Max = 500,
        Rounding = 0,
        Callback = function(Value)
            if JumpToggle.Value then
                toggleJump(true, Value)
            end
        end
    })
    
    local FlyToggle = tab:AddToggle("FlyToggle", {
        Title = "Fly",
        Description = "Fly mode (WASD, Space, Shift)",
        Default = false,
        Callback = function(Value)
            toggleFly(Value)
        end
    })
    
    local FlySlider = tab:AddSlider("FlySlider", {
        Title = "Fly Speed",
        Description = "Adjust fly speed",
        Default = 50,
        Min = 10,
        Max = 300,
        Rounding = 0,
        Callback = function(Value)
            flySpeed = Value
        end
    })
    
    local NoclipToggle = tab:AddToggle("NoclipToggle", {
        Title = "Noclip",
        Description = "Walk through walls",
        Default = false,
        Callback = function(Value)
            toggleNoclip(Value)
        end
    })
    
    local InfiniteJumpToggle = tab:AddToggle("InfiniteJumpToggle", {
        Title = "Infinite Jump",
        Description = "Jump infinitely",
        Default = false,
        Callback = function(Value)
            toggleInfiniteJump(Value)
        end
    })
    
    local FloatSection = tab:AddSection("Advanced Movement")
    
    local FloatToggle = tab:AddToggle("FloatToggle", {
        Title = "Float Mode",
        Description = "Float in air with WASD controls",
        Default = false,
        Callback = function(Value)
            toggleFloat(Value)
        end
    })
    
    local MoonGravityToggle = tab:AddToggle("MoonGravityToggle", {
        Title = "Moon Gravity",
        Description = "Low gravity mode",
        Default = false,
        Callback = function(Value)
            toggleMoonGravity(Value)
        end
    })
    
    local MoonGravitySlider = tab:AddSlider("MoonGravitySlider", {
        Title = "Gravity Multiplier",
        Description = "Adjust gravity strength",
        Default = 0.166,
        Min = 0.1,
        Max = 1,
        Rounding = 3,
        Callback = function(Value)
            moonGravityMultiplier = Value
            if MoonGravityToggle.Value then
                toggleMoonGravity(true)
            end
        end
    })
    
    local DoubleJumpToggle = tab:AddToggle("DoubleJumpToggle", {
        Title = "Double Jump",
        Description = "Jump multiple times in air",
        Default = false,
        Callback = function(Value)
            toggleDoubleJump(Value)
        end
    })
    
    local DoubleJumpSlider = tab:AddSlider("DoubleJumpSlider", {
        Title = "Max Extra Jumps",
        Description = "Number of extra jumps",
        Default = 1,
        Min = 1,
        Max = 10,
        Rounding = 0,
        Callback = function(Value)
            maxDoubleJumps = Value
        end
    })
    
    local WallClimbToggle = tab:AddToggle("WallClimbToggle", {
        Title = "Wall Climb",
        Description = "Climb walls automatically",
        Default = false,
        Callback = function(Value)
            toggleWallClimb(Value)
        end
    })
    
    local WallClimbSlider = tab:AddSlider("WallClimbSlider", {
        Title = "Climb Speed",
        Description = "Adjust climbing speed",
        Default = 30,
        Min = 10,
        Max = 100,
        Rounding = 0,
        Callback = function(Value)
            wallClimbSpeed = Value
        end
    })
    
    local PlayerNoclipToggle = tab:AddToggle("PlayerNoclipToggle", {
        Title = "Player Noclip",
        Description = "Walk through other players",
        Default = false,
        Callback = function(Value)
            togglePlayerNoclip(Value)
        end
    })
    
    local WalkOnWaterToggle = tab:AddToggle("WalkOnWaterToggle", {
        Title = "Walk on Water",
        Description = "Walk on water surfaces",
        Default = false,
        Callback = function(Value)
            toggleWalkOnWater(Value)
        end
    })
    
    local SuperSwimToggle = tab:AddToggle("SuperSwimToggle", {
        Title = "Super Swim",
        Description = "Fast swimming speed",
        Default = false,
        Callback = function(Value)
            toggleSuperSwim(Value)
        end
    })
    
    local SuperSwimSlider = tab:AddSlider("SuperSwimSlider", {
        Title = "Swim Speed",
        Description = "Adjust swimming speed",
        Default = 100,
        Min = 50,
        Max = 300,
        Rounding = 0,
        Callback = function(Value)
            swimSpeed = Value
        end
    })
    
    local SlowFallToggle = tab:AddToggle("SlowFallToggle", {
        Title = "Slow Fall",
        Description = "Fall slowly",
        Default = false,
        Callback = function(Value)
            toggleSlowFall(Value)
        end
    })
    
    local SlowFallSlider = tab:AddSlider("SlowFallSlider", {
        Title = "Slow Fall Speed",
        Description = "Adjust slow fall speed",
        Default = -10,
        Min = -50,
        Max = -1,
        Rounding = 0,
        Callback = function(Value)
            slowFallSpeed = Value
        end
    })
    
    local FastFallToggle = tab:AddToggle("FastFallToggle", {
        Title = "Fast Fall",
        Description = "Fall quickly",
        Default = false,
        Callback = function(Value)
            toggleFastFall(Value)
        end
    })
    
    local FastFallSlider = tab:AddSlider("FastFallSlider", {
        Title = "Fast Fall Speed",
        Description = "Adjust fast fall speed",
        Default = -100,
        Min = -300,
        Max = -50,
        Rounding = 0,
        Callback = function(Value)
            fastFallSpeed = Value
        end
    })
    
    local SprintSection = tab:AddSection("Sprint & Boost")
    
    local SprintToggle = tab:AddToggle("SprintToggle", {
        Title = "Sprint Mode",
        Description = "Press Shift to sprint",
        Default = false,
        Callback = function(Value)
            toggleSprint(Value)
        end
    })
    
    local SprintSlider = tab:AddSlider("SprintSlider", {
        Title = "Sprint Speed",
        Description = "Adjust sprint speed",
        Default = 100,
        Min = 50,
        Max = 300,
        Rounding = 0,
        Callback = function(Value)
            sprintSpeed = Value
        end
    })
    
    tab:AddButton({
        Title = "Boost (B Key)",
        Description = "Instant speed boost forward",
        Callback = function()
            toggleBoost()
        end
    })
    
    local BoostSlider = tab:AddSlider("BoostSlider", {
        Title = "Boost Speed",
        Description = "Adjust boost power",
        Default = 150,
        Min = 50,
        Max = 500,
        Rounding = 0,
        Callback = function(Value)
            boostSpeed = Value
        end
    })
    
    local RewindSection = tab:AddSection("Time Control")
    
    local RewindToggle = tab:AddToggle("RewindToggle", {
        Title = "Rewind Mode",
        Description = "Press R to rewind position",
        Default = false,
        Callback = function(Value)
            toggleRewind(Value)
        end
    })
    
    local InfoSection = tab:AddSection("Information")
    
    tab:AddParagraph({
        Title = "Device Type",
        Content = isMobile and "Mobile - Touch controls enabled" or "PC - Keyboard controls enabled"
    })
    
    tab:AddParagraph({
        Title = "Chat Commands",
        Content = "/fly - Enable fly\n/unfly - Disable fly\n/flyspeed [value] - Set fly speed\n/speed [value] - Set walk speed\n/jump [value] - Set jump power\n/boost - Instant boost"
    })
    
    return true
end

function Movement.cleanup()
    for _, conn in pairs(connections) do
        if conn then conn:Disconnect() end
    end
    connections = {}
    cleanupFly()
    positionHistory = {}
end

return Movement