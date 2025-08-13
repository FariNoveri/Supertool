local DoubleJump = {}
local Players, UserInputService, humanoid, connections
DoubleJump.enabled = false
DoubleJump.jumpCount = 0
DoubleJump.maxJumps = 2

local function refreshReferences()
    if not Players or not Players.LocalPlayer or not Players.LocalPlayer.Character then 
        return false 
    end
    humanoid = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    return humanoid ~= nil
end

function DoubleJump.init(deps)
    Players = deps.Players
    UserInputService = deps.UserInputService
    connections = deps.connections
    humanoid = deps.humanoid
end

function DoubleJump.toggle(enabled)
    DoubleJump.enabled = enabled
    if connections.doubleJump then
        connections.doubleJump:Disconnect()
        connections.doubleJump = nil
    end
    if enabled then
        connections.doubleJump = UserInputService.JumpRequest:Connect(function()
            if not DoubleJump.enabled then return end
            if not refreshReferences() or not humanoid then return end
            if humanoid:GetState() ~= Enum.HumanoidStateType.Jumping and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
                DoubleJump.jumpCount = 0
            elseif DoubleJump.jumpCount < DoubleJump.maxJumps then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                DoubleJump.jumpCount = DoubleJump.jumpCount + 1
            end
        end)
    else
        DoubleJump.jumpCount = 0
    end
end

function DoubleJump.updateReferences(newHumanoid, newRootPart)
    humanoid = newHumanoid
end

function DoubleJump.reset()
    DoubleJump.enabled = false
    DoubleJump.jumpCount = 0
    if connections.doubleJump then
        connections.doubleJump:Disconnect()
        connections.doubleJump = nil
    end
end

function DoubleJump.debug()
    print("DoubleJump: enabled =", DoubleJump.enabled, "jumpCount =", DoubleJump.jumpCount, "maxJumps =", DoubleJump.maxJumps, "humanoid =", humanoid ~= nil)
end

return DoubleJump