local UserInputService, humanoid, rootPart, settings
local Fly = {}
local flying = false
local speed = 50
local bodyVelocity = nil
local bodyGyro = nil

-- Initialize fly feature
function Fly.init(deps)
    UserInputService = deps.UserInputService
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    settings = deps.settings
end

-- Start flying
local function startFlying()
    flying = true
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Parent = rootPart
    
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.CFrame = rootPart.CFrame
    bodyGyro.Parent = rootPart
    
    humanoid.PlatformStand = true
end

-- Stop flying
local function stopFlying()
    flying = false
    if bodyVelocity then bodyVelocity:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end
    humanoid.PlatformStand = false
end

-- Toggle fly feature
function Fly.toggle(state)
    if state then
        startFlying()
    else
        stopFlying()
    end
end

-- Handle touch input for mobile
function Fly.handleTouchInput(touch, processedByUI)
    if flying and not processedByUI then
        local camera = workspace.CurrentCamera
        local direction = (camera.CFrame:PointToWorldSpace(Vector3.new(0, 0, -1)) - camera.CFrame.Position).Unit
        local moveDirection = Vector3.new(touch.Position.X - 0.5, touch.Position.Y - 0.5, 0).Unit * speed
        bodyVelocity.Velocity = camera.CFrame:VectorToWorldSpace(moveDirection)
        bodyGyro.CFrame = camera.CFrame
    end
end

-- Handle touch end
function Fly.handleTouchEnd()
    if flying and bodyVelocity then
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    end
end

-- Update references
function Fly.updateReferences(newHumanoid, newRootPart)
    humanoid = newHumanoid
    rootPart = newRootPart
end

-- Reset fly state
function Fly.reset()
    stopFlying()
end

-- Debug
function Fly.debug()
    print("Fly feature - Flying: ", flying)
end

-- Cleanup
function Fly.cleanup()
    stopFlying()
end

return Fly