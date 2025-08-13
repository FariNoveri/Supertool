local JumpHack = {}
local Players, humanoid, settings
JumpHack.enabled = false
JumpHack.defaultJumpPower = 50
JumpHack.defaultJumpHeight = 7.2

local function refreshReferences()
    if not Players or not Players.LocalPlayer or not Players.LocalPlayer.Character then 
        return false 
    end
    humanoid = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil
end

function JumpHack.init(deps)
    Players = deps.Players
    settings = deps.settings
    humanoid = deps.humanoid
    if humanoid then
        if humanoid:FindFirstChild("JumpHeight") then
            JumpHack.defaultJumpHeight = humanoid.JumpHeight or 7.2
        else
            JumpHack.defaultJumpPower = humanoid.JumpPower or 50
        end
    end
end

function JumpHack.toggle(enabled)
    JumpHack.enabled = enabled
    
    -- Add nil check for settings
    if not settings then
        print("Warning: JumpHack.toggle() called before JumpHack.init(). Settings table is nil.")
        return
    end
    
    if enabled then
        local function applyJump()
            if refreshReferences() and humanoid then
                if humanoid:FindFirstChild("JumpHeight") then
                    humanoid.JumpHeight = settings.JumpHeight and settings.JumpHeight.value or 50
                else
                    humanoid.JumpPower = (settings.JumpHeight and settings.JumpHeight.value * 2.4) or 150
                end
                return true
            end
            return false
        end
        if not applyJump() then
            task.wait(0.1)
            applyJump()
        end
    else
        if refreshReferences() and humanoid then
            if humanoid:FindFirstChild("JumpHeight") then
                humanoid.JumpHeight = JumpHack.defaultJumpHeight
            else
                humanoid.JumpPower = JumpHack.defaultJumpPower
            end
        end
    end
end

function JumpHack.updateReferences(newHumanoid, newRootPart)
    humanoid = newHumanoid
end

function JumpHack.reset()
    JumpHack.enabled = false
    if refreshReferences() and humanoid then
        if humanoid:FindFirstChild("JumpHeight") then
            humanoid.JumpHeight = JumpHack.defaultJumpHeight
        else
            humanoid.JumpPower = JumpHack.defaultJumpPower
        end
    end
end

function JumpHack.debug()
    print("JumpHack: enabled =", JumpHack.enabled, "defaultJumpPower =", JumpHack.defaultJumpPower, "defaultJumpHeight =", JumpHack.defaultJumpHeight, "humanoid =", humanoid ~= nil)
end

return JumpHack