-- Movement utilities - Shared functions for all movement features

local Utils = {}

-- Dependencies (set by init)
local deps = {}

-- Reference refresh function
function Utils.refreshReferences()
    if not deps.player or not deps.player.Character then 
        return false 
    end
    
    local newHumanoid = deps.player.Character:FindFirstChildOfClass("Humanoid")
    local newRootPart = deps.player.Character:FindFirstChild("HumanoidRootPart")
    
    if newHumanoid ~= deps.humanoid then
        deps.humanoid = newHumanoid
    end
    if newRootPart ~= deps.rootPart then
        deps.rootPart = newRootPart
    end
    
    return deps.humanoid ~= nil and deps.rootPart ~= nil
end

-- Get current references
function Utils.getReferences()
    return deps.humanoid, deps.rootPart, deps.player, deps.character
end

-- Check if character is valid
function Utils.isCharacterValid()
    return deps.player and deps.player.Character and deps.humanoid and deps.rootPart
end

-- Safe task wait
function Utils.safeWait(duration)
    local success, result = pcall(function()
        task.wait(duration or 0.1)
    end)
    if not success then
        wait(duration or 0.1)
    end
end

-- Safe pcall with error handling
function Utils.safePcall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        warn("Error in safePcall: " .. tostring(result))
    end
    return success, result
end

-- Get default movement values
function Utils.getDefaults()
    local defaults = {
        walkSpeed = 16,
        jumpPower = 50,
        jumpHeight = 7.2,
        gravity = 196.2
    }
    
    if Utils.refreshReferences() and deps.humanoid then
        defaults.walkSpeed = deps.humanoid.WalkSpeed or 16
        if deps.humanoid:FindFirstChild("JumpHeight") then
            defaults.jumpHeight = deps.humanoid.JumpHeight or 7.2
        else
            defaults.jumpPower = deps.humanoid.JumpPower or 50
        end
    end
    
    if deps.Workspace then
        defaults.gravity = deps.Workspace.Gravity or 196.2
    end
    
    return defaults
end

-- Apply with retry mechanism
function Utils.applyWithRetry(applyFunction, maxRetries)
    maxRetries = maxRetries or 3
    
    for i = 1, maxRetries do
        local success = applyFunction()
        if success then
            return true
        end
        
        if i < maxRetries then
            Utils.safeWait(0.1)
        end
    end
    
    return false
end

-- Disconnect connection safely
function Utils.safeDisconnect(connection)
    if connection and connection.Connected then
        Utils.safePcall(function()
            connection:Disconnect()
        end)
    end
end

-- Destroy object safely
function Utils.safeDestroy(object)
    if object and object.Parent then
        Utils.safePcall(function()
            object:Destroy()
        end)
    end
end

-- Get settings value with fallback
function Utils.getSettingValue(settingName, fallback)
    if deps.settings and deps.settings[settingName] and deps.settings[settingName].value then
        return deps.settings[settingName].value
    end
    return fallback
end

-- Create raycast params for character
function Utils.createRaycastParams(character)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    return raycastParams
end

-- Check if part is water
function Utils.isWater(part)
    return part and (part.Material == Enum.Material.Water or 
                    string.lower(part.Name):find("water"))
end

-- Initialize utils
function Utils.init(dependencies)
    if not dependencies then
        warn("Utils: No dependencies provided!")
        return false
    end
    
    deps = dependencies
    print("Movement Utils initialized")
    return true
end

-- Update references
function Utils.updateReferences(newHumanoid, newRootPart)
    deps.humanoid = newHumanoid
    deps.rootPart = newRootPart
    deps.character = newHumanoid and newHumanoid.Parent or nil
end

-- Reset function (cleanup)
function Utils.reset()
    -- Utils doesn't need specific reset logic
    print("Movement Utils reset")
end

-- Cleanup function
function Utils.cleanup()
    print("Movement Utils cleaned up")
end

return Utils