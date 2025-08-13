local NoClip = {}
local Players, RunService, humanoid, connections
NoClip.enabled = false

local function refreshReferences()
    if not Players or not Players.LocalPlayer or not Players.LocalPlayer.Character then 
        return false 
    end
    return true
end

function NoClip.init(deps)
    Players = deps.Players
    RunService = deps.RunService
    connections = deps.connections
    humanoid = deps.humanoid
end

function NoClip.toggle(enabled)
    NoClip.enabled = enabled
    if connections.noclip then
        connections.noclip:Disconnect()
        connections.noclip = nil
    end
    if enabled then
        connections.noclip = RunService.Stepped:Connect(function()
            if not NoClip.enabled then return end
            if not refreshReferences() then return end
            for _, part in pairs(Players.LocalPlayer.Character:GetChildren()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    else
        if refreshReferences() then
            for _, part in pairs(Players.LocalPlayer.Character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

function NoClip.reset()
    NoClip.enabled = false
    if connections.noclip then
        connections.noclip:Disconnect()
        connections.noclip = nil
    end
    if refreshReferences() then
        for _, part in pairs(Players.LocalPlayer.Character:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end
end

function NoClip.debug()
    print("NoClip: enabled =", NoClip.enabled)
end

return NoClip