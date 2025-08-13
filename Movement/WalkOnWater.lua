local WalkOnWater = {}
local Players, RunService, Workspace, humanoid, rootPart, connections
WalkOnWater.enabled = false

local function refreshReferences()
    if not Players or not Players.LocalPlayer or not Players.LocalPlayer.Character then 
        return false 
    end
    humanoid = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    rootPart = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    return humanoid ~= nil and rootPart ~= nil
end

function WalkOnWater.init(deps)
    Players = deps.Players
    RunService = deps.RunService
    Workspace = deps.Workspace
    connections = deps.connections
    humanoid = deps.humanoid
    rootPart = deps.rootPart
end

function WalkOnWater.toggle(enabled)
    WalkOnWater.enabled = enabled
    if connections.walkOnWater then
        connections.walkOnWater:Disconnect()
        connections.walkOnWater = nil
    end
    if enabled then
        connections.walkOnWater = RunService.Heartbeat:Connect(function()
            if not WalkOnWater.enabled then return end
            if not refreshReferences() then return end
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {Players.LocalPlayer.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            local raycast = Workspace:Raycast(rootPart.Position, Vector3.new(0, -10, 0), raycastParams)
            if raycast and raycast.Instance and (raycast.Instance.Material == Enum.Material.Water or raycast.Instance.Name:lower():find("water")) then
                if not rootPart:FindFirstChild("WaterWalkPart") then
                    local waterWalkPart = Instance.new("Part")
                    waterWalkPart.Name = "WaterWalkPart"
                    waterWalkPart.Anchored = true
                    waterWalkPart.CanCollide = true
                    waterWalkPart.Transparency = 1
                    waterWalkPart.Size = Vector3.new(10, 0.2, 10)
                    waterWalkPart.Position = Vector3.new(rootPart.Position.X, raycast.Position.Y + 0.1, rootPart.Position.Z)
                    waterWalkPart.Parent = Workspace
                    game:GetService("Debris"):AddItem(waterWalkPart, 0.5)
                end
            end
        end)
    end
end

function WalkOnWater.updateReferences(newHumanoid, newRootPart)
    humanoid = newHumanoid
    rootPart = newRootPart
end

function WalkOnWater.reset()
    WalkOnWater.enabled = false
    if connections.walkOnWater then
        connections.walkOnWater:Disconnect()
        connections.walkOnWater = nil
    end
end

function WalkOnWater.debug()
    print("WalkOnWater: enabled =", WalkOnWater.enabled)
end

return WalkOnWater