local Fly = {}
local Players, RunService, Workspace, UserInputService, humanoid, rootPart, connections, ScreenGui, settings
Fly.enabled = false
local flyBodyVelocity, flyJoystickFrame, flyJoystickKnob, flyUpButton, flyDownButton
local flySpeed = 50
local joystickDelta = Vector2.new(0, 0)
local flyVerticalInput = 0
local isTouchingJoystick = false
local joystickTouchId = nil

local function refreshReferences()
    if not Players or not Players.LocalPlayer or not Players.LocalPlayer.Character then 
        return false 
    end
    humanoid = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    rootPart = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    return humanoid ~= nil and rootPart ~= nil
end

local function handleFlyJoystick(input, gameProcessed)
    if not Fly.enabled or not flyJoystickFrame or not flyJoystickFrame.Visible then 
        return 
    end
    if input.UserInputType == Enum.UserInputType.Touch then
        local joystickCenter = flyJoystickFrame.AbsolutePosition + flyJoystickFrame.AbsoluteSize * 0.5
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

function Fly.init(deps)
    Players = deps.Players
    RunService = deps.RunService
    Workspace = deps.Workspace
    UserInputService = deps.UserInputService
    connections = deps.connections
    ScreenGui = deps.ScreenGui
    settings = deps.settings
    humanoid = deps.humanoid
    rootPart = deps.rootPart
end

function Fly.toggle(enabled)
    Fly.enabled = enabled
    local flyConnections = {"fly", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", "flyDown", "flyDownEnd"}
    for _, connName in ipairs(flyConnections) do
        if connections[connName] then
            connections[connName]:Disconnect()
            connections[connName] = nil
        end
    end
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if enabled then
        task.wait(0.1)
        if not refreshReferences() then
            Fly.enabled = false
            return
        end
        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        flyBodyVelocity.Parent = rootPart
        if flyJoystickFrame then flyJoystickFrame.Visible = true end
        if flyUpButton then flyUpButton.Visible = true end
        if flyDownButton then flyDownButton.Visible = true end
        connections.fly = RunService.Heartbeat:Connect(function()
            if not Fly.enabled then return end
            if not refreshReferences() then return end
            if not flyBodyVelocity or flyBodyVelocity.Parent ~= rootPart then
                if flyBodyVelocity then flyBodyVelocity:Destroy() end
                flyBodyVelocity = Instance.new("BodyVelocity")
                flyBodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
                flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                flyBodyVelocity.Parent = rootPart
            end
            local camera = Workspace.CurrentCamera
            if not camera then return end
            local flyDirection = Vector3.new(0, 0, 0)
            flySpeed = settings.FlySpeed and settings.FlySpeed.value or 50
            if joystickDelta.Magnitude > 0.05 then
                local forward = camera.CFrame.LookVector
                local right = camera.CFrame.RightVector
                forward = Vector3.new(forward.X, 0, forward.Z).Unit
                right = Vector3.new(right.X, 0, right.Z).Unit
                flyDirection = flyDirection + (right * joystickDelta.X) + (forward * -joystickDelta.Y)
            end
            if flyVerticalInput ~= 0 then
                flyDirection = flyDirection + Vector3.new(0, flyVerticalInput, 0)
            end
            if flyDirection.Magnitude > 0 then
                flyBodyVelocity.Velocity = flyDirection.Unit * flySpeed
            else
                flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        end)
        connections.flyInput = UserInputService.InputChanged:Connect(handleFlyJoystick)
        connections.flyBegan = UserInputService.InputBegan:Connect(handleFlyJoystick)
        connections.flyEnded = UserInputService.InputEnded:Connect(handleFlyJoystick)
        if flyUpButton then
            connections.flyUp = flyUpButton.MouseButton1Down:Connect(function()
                flyVerticalInput = 1
                flyUpButton.BackgroundTransparency = 0.1
            end)
            connections.flyUpEnd = flyUpButton.MouseButton1Up:Connect(function()
                flyVerticalInput = 0
                flyUpButton.BackgroundTransparency = 0.3
            end)
        end
        if flyDownButton then
            connections.flyDown = flyDownButton.MouseButton1Down:Connect(function()
                flyVerticalInput = -1
                flyDownButton.BackgroundTransparency = 0.1
            end)
            connections.flyDownEnd = flyDownButton.MouseButton1Up:Connect(function()
                flyVerticalInput = 0
                flyDownButton.BackgroundTransparency = 0.3
            end)
        end
    else
        if flyJoystickFrame then 
            flyJoystickFrame.Visible = false
            flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
        end
        if flyUpButton then 
            flyUpButton.Visible = false
            flyUpButton.BackgroundTransparency = 0.3
        end
        if flyDownButton then 
            flyDownButton.Visible = false
            flyDownButton.BackgroundTransparency = 0.3
        end
        flyVerticalInput = 0
        joystickDelta = Vector2.new(0, 0)
        isTouchingJoystick = false
        joystickTouchId = nil
    end
end

function Fly.updateReferences(newHumanoid, newRootPart)
    humanoid = newHumanoid
    rootPart = newRootPart
end

function Fly.reset()
    Fly.enabled = false
    local flyConnections = {"fly", "flyInput", "flyBegan", "flyEnded", "flyUp", "flyUpEnd", "flyDown", "flyDownEnd"}
    for _, connName in ipairs(flyConnections) do
        if connections[connName] then
            connections[connName]:Disconnect()
            connections[connName] = nil
        end
    end
    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end
    if flyJoystickFrame then 
        flyJoystickFrame.Visible = false
        flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
    end
    if flyUpButton then 
        flyUpButton.Visible = false
        flyUpButton.BackgroundTransparency = 0.3
    end
    if flyDownButton then 
        flyDownButton.Visible = false
        flyDownButton.BackgroundTransparency = 0.3
    end
    flyVerticalInput = 0
    joystickDelta = Vector2.new(0, 0)
    isTouchingJoystick = false
    joystickTouchId = nil
end

function Fly.debug()
    print("Fly: enabled =", Fly.enabled, "flyBodyVelocity =", flyBodyVelocity ~= nil, "joystickDelta =", joystickDelta, "flyVerticalInput =", flyVerticalInput)
end

function Fly.setControls(joystickFrame, joystickKnob, upButton, downButton)
    flyJoystickFrame = joystickFrame
    flyJoystickKnob = joystickKnob
    flyUpButton = upButton
    flyDownButton = downButton
end

return Fly