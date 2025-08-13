local SuperSwim = {}
local Players, humanoid
SuperSwim.enabled = false
SuperSwim.defaultWalkSpeed = 16

local function refreshReferences()
    if not Players or not Players.LocalPlayer or not Players.LocalPlayer.Character then 
        return false 
    end
    humanoid = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil
end

function SuperSwim.init(deps)
    Players = deps.Players
    humanoid = deps.humanoid
    if humanoid then
        SuperSwim.defaultWalkSpeed = humanoid.WalkSpeed or 16
    end
end

function SuperSwim.toggle(enabled)
    SuperSwim.enabled = enabled
    local function applySwim()
        if refreshReferences() and humanoid then
            if enabled then
                pcall(function()
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
                    humanoid.WalkSpeed = 50
                end)
            else
                pcall(function()
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
                    humanoid.WalkSpeed = SuperSwim.defaultWalkSpeed
                end)
            end
            return true
        end
        return false
    end
    if not applySwim() then
        task.wait(0.1)
        applySwim()
    end
end

function SuperSwim.updateReferences(newHumanoid, newRootPart)
    humanoid = newHumanoid
end

function SuperSwim.reset()
    SuperSwim.enabled = false
    if refreshReferences() and humanoid then
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
            humanoid.WalkSpeed = SuperSwim.defaultWalkSpeed
        end)
    end
end

function SuperSwim.debug()
    print("SuperSwim: enabled =", SuperSwim.enabled, "defaultWalkSpeed =", SuperSwim.defaultWalkSpeed, "humanoid =", humanoid ~= nil)
end

return SuperSwim