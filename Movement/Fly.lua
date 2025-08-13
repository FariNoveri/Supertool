local UserInputService, humanoid, rootPart, settings
local Fly = {}
local flying = false
local speed = 50
local bodyVelocity = nil
local bodyGyro = nil

function Fly.init(deps)
    UserInputService = deps.UserInputService or game:GetService("UserInputService")
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    settings = deps.settings
end

local function startFlying()
    if not humanoid or not rootPart then
        warn("Humanoid or RootPart not found!")
        return
    end
    flying = true
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Parent = rootPart
    
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.CFrame = rootPart.CFrame -- Pastikan rootPart valid
    bodyGyro.Parent = rootPart
    
    humanoid.PlatformStand = true
end

local function stopFlying()
    flying = false
    if bodyVelocity then bodyVelocity:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end
    bodyVelocity = nil
    bodyGyro = nil
    if humanoid then humanoid.PlatformStand = false end
end

function Fly.toggle(state)
    if not humanoid or not rootPart then
        warn("Cannot toggle fly: Humanoid or RootPart missing!")
        return
    end
    if state then
        startFlying()
    else
        stopFlying()
    end
end

function Fly.handleTouchInput(touch, processedByUI)
    if flying and not processedByUI and rootPart and bodyVelocity and bodyGyro then
        local camera = workspace.CurrentCamera
        local moveDirection = Vector3.new(touch.Position.X - 0.5, touch.Position.Y - 0.5, 0).Unit * speed
        bodyVelocity.Velocity = camera.CFrame:VectorToWorldSpace(moveDirection)
        bodyGyro.CFrame = camera.CFrame
    end
end

function Fly.handleTouchEnd()
    if flying and bodyVelocity then
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    end
end

function Fly.updateReferences(newHumanoid, newRootPart)
    humanoid = newHumanoid
    rootPart = newRootPart
end

function Fly.reset()
    stopFlying()
end

function Fly.debug()
    print("Fly feature - Flying: ", flying, "Humanoid: ", humanoid, "RootPart: ", rootPart)
end

function Fly.cleanup()
    stopFlying()
end

return Fly