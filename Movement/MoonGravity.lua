local MoonGravity = {}
local Workspace
MoonGravity.enabled = false
MoonGravity.defaultGravity = 196.2

function MoonGravity.init(deps)
    Workspace = deps.Workspace
    MoonGravity.defaultGravity = Workspace.Gravity or 196.2
end

function MoonGravity.toggle(enabled)
    MoonGravity.enabled = enabled
    if Workspace then
        if enabled then
            Workspace.Gravity = MoonGravity.defaultGravity / 6
        else
            Workspace.Gravity = MoonGravity.defaultGravity
        end
    end
end

function MoonGravity.updateReferences(newHumanoid, newRootPart)
    -- No references to update
end

function MoonGravity.reset()
    MoonGravity.enabled = false
    if Workspace then
        Workspace.Gravity = MoonGravity.defaultGravity
    end
end

function MoonGravity.debug()
    print("MoonGravity: enabled =", MoonGravity.enabled, "defaultGravity =", MoonGravity.defaultGravity, "Workspace =", Workspace ~= nil)
end

return MoonGravity