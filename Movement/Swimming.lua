-- Movement/Swimming.lua - Swimming-related features

local Swimming = {}

-- Dependencies
local Players, RunService, Workspace, UserInputService, humanoid, rootPart, connections, settings, player, Movement

-- Reference refresh function
local function refreshReferences()
    if not player or not player.Character then 
        return false 
    end
    
    local newHumanoid = player.Character:FindFirstChildOfClass("Humanoid")
    local newRootPart = player.Character:FindFirstChild("HumanoidRootPart")
    
    if newHumanoid ~= humanoid then
        humanoid = newHumanoid
    end
    if newRootPart ~= rootPart then
        rootPart = newRootPart
    end
    
    return humanoid ~= nil and rootPart ~= nil
end

-- Walk on Water toggle function
function Swimming.toggleWalkOnWater(enabled)
    print("Walk on Water:", enabled)
    
    if connections.walkOnWater then
        connections.walkOnWater:Disconnect()
        connections.walkOnWater = nil
    end
    
    if enabled then
        connections.walkOnWater = RunService.Heartbeat:Connect(function()
            if not Movement.walkOnWaterEnabled then return end
            if not refreshReferences() or not rootPart or not player.Character then return end
            
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {player.Character}
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

-- Super Swim toggle function
function Swimming.toggleSwim(enabled)
    print("Super Swim:", enabled)
    
    local function applySwim()
        if refreshReferences() and humanoid then
            if enabled then
                pcall(function()
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
                    humanoid.WalkSpeed = settings.SwimSpeed and settings.SwimSpeed.value or 50
                end)
            else
                pcall(function()
                    humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
                    humanoid.WalkSpeed = Movement.defaultWalkSpeed
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

-- Reset function
function Swimming.reset()
    -- Disconnect connections
    if connections.walkOnWater then
        connections.walkOnWater:Disconnect()
        connections.walkOnWater = nil
    end
    
    -- Clean up water walk parts
    for _, part in pairs(Workspace:GetChildren()) do
        if part.Name == "WaterWalkPart" then
            part:Destroy()
        end
    end
    
    -- Reset swim properties
    if refreshReferences() and humanoid then
        pcall(function()
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, true)
            humanoid.WalkSpeed = Movement.defaultWalkSpeed
        end)
    end
end

-- Update references
function Swimming.updateReferences(deps)
    Players = deps.Players
    RunService = deps.RunService
    Workspace = deps.Workspace
    UserInputService = deps.UserInputService
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    connections = deps.connections
    settings = deps.settings
    player = deps.player
    Movement = deps.Movement
end

-- Initialize
function Swimming.init(deps)
    Swimming.updateReferences(deps)
    print("Swimming features initialized")
    return true
end

-- Debug
function Swimming.debug()
    print("Swimming Features Debug:")
    print("  walkOnWater connection:", connections.walkOnWater ~= nil)
    print("  Current WalkSpeed:", humanoid and humanoid.WalkSpeed or "N/A")
    print("  Default WalkSpeed:", Movement.defaultWalkSpeed)
    
    -- Count water walk parts
    local waterWalkParts = 0
    for _, part in pairs(Workspace:GetChildren()) do
        if part.Name == "WaterWalkPart" then
            waterWalkParts = waterWalkParts + 1
        end
    end
    print("  Active WaterWalkParts:", waterWalkParts)
end

-- Cleanup
function Swimming.cleanup()
    Swimming.reset()
end

return Swimming