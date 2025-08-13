local SpeedHack = {}
local Players, humanoid, settings
SpeedHack.enabled = false
SpeedHack.defaultWalkSpeed = 16

local function refreshReferences()
    if not Players or not Players.LocalPlayer or not Players.LocalPlayer.Character then 
        return false 
    end
    humanoid = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil
end

function SpeedHack.init(deps)
    Players = deps.Players
    settings = deps.settings
    humanoid = deps.humanoid
    if humanoid then
        SpeedHack.defaultWalkSpeed = humanoid.WalkSpeed or 16
    end
end

function SpeedHack.toggle(enabled)
    SpeedHack.enabled = enabled
    
    -- Add nil check for settings
    if not settings then
        print("Warning: SpeedHack.toggle() called before SpeedHack.init(). Settings table is nil.")
        return
    end
    
    if enabled then
        local function applySpeed()
            if refreshReferences() and humanoid then
                humanoid.WalkSpeed = settings.WalkSpeed and settings.WalkSpeed.value or 50
                return true
            end
            return false
        end
        if not applySpeed() then
            task.wait(0.1)
            applySpeed()
        end
    else
        if refreshReferences() and humanoid then
            humanoid.WalkSpeed = SpeedHack.defaultWalkSpeed
        end
    end
end

function SpeedHack.updateReferences(newHumanoid, newRootPart)
    humanoid = newHumanoid
end

function SpeedHack.reset()
    SpeedHack.enabled = false
    if refreshReferences() and humanoid then
        humanoid.WalkSpeed = SpeedHack.defaultWalkSpeed
    end
end

function SpeedHack.debug()
    print("SpeedHack: enabled =", SpeedHack.enabled, "defaultWalkSpeed =", SpeedHack.defaultWalkSpeed, "humanoid =", humanoid ~= nil)
end

return SpeedHack