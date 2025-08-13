local InfiniteJump = {}
local Players, UserInputService, humanoid, connections
InfiniteJump.enabled = false

local function refreshReferences()
    if not Players or not Players.LocalPlayer or not Players.LocalPlayer.Character then 
        return false 
    end
    humanoid = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil
end

function InfiniteJump.init(deps)
    Players = deps.Players
    UserInputService = deps.UserInputService
    connections = deps.connections
    humanoid = deps.humanoid
end

function InfiniteJump.toggle(enabled)
    InfiniteJump.enabled = enabled
    
    -- Add nil check for connections
    if not connections then
        print("Warning: InfiniteJump.toggle() called before InfiniteJump.init(). Connections table is nil.")
        return
    end
    
    if connections.infiniteJump then
        connections.infiniteJump:Disconnect()
        connections.infiniteJump = nil
    end
    if enabled then
        connections.infiniteJump = UserInputService.JumpRequest:Connect(function()
            if not InfiniteJump.enabled then return end
            if not refreshReferences() or not humanoid then return end
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end

function InfiniteJump.updateReferences(newHumanoid, newRootPart)
    humanoid = newHumanoid
end

function InfiniteJump.reset()
    InfiniteJump.enabled = false
    
    -- Add nil check for connections
    if connections and connections.infiniteJump then
        connections.infiniteJump:Disconnect()
        connections.infiniteJump = nil
    end
end

function InfiniteJump.debug()
    print("InfiniteJump: enabled =", InfiniteJump.enabled, "humanoid =", humanoid ~= nil)
end

return InfiniteJump