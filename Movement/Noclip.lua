local NoClip = {}
local Players, RunService, connections
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
end

function NoClip.toggle(enabled)
    NoClip.enabled = enabled
    
    -- Add nil check for connections
    if not connections then
        print("Warning: NoClip.toggle() called before NoClip.init(). Connections table is nil.")
        return
    end
    
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

function NoClip.updateReferences(newHumanoid, newRootPart)
    -- No references to update
end

function NoClip.reset()
    NoClip.enabled = false
    
    -- Add nil check for connections
    if connections and connections.noclip then
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