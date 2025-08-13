local PlayerNoClip = {}
local Players, RunService, connections
PlayerNoClip.enabled = false

local function refreshReferences()
    if not Players or not Players.LocalPlayer or not Players.LocalPlayer.Character then 
        return false 
    end
    return true
end

function PlayerNoClip.init(deps)
    Players = deps.Players
    RunService = deps.RunService
    connections = deps.connections
end

function PlayerNoClip.toggle(enabled)
    PlayerNoClip.enabled = enabled
    if connections.playerNoclip then
        connections.playerNoclip:Disconnect()
        connections.playerNoclip = nil
    end
    if enabled then
        connections.playerNoclip = RunService.Heartbeat:Connect(function()
            if not PlayerNoClip.enabled then return end
            if not refreshReferences() then return end
            for _, otherPlayer in pairs(Players:GetPlayers()) do
                if otherPlayer ~= Players.LocalPlayer and otherPlayer.Character then
                    for _, part in pairs(otherPlayer.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end
        end)
    else
        if refreshReferences() then
            for _, otherPlayer in pairs(Players:GetPlayers()) do
                if otherPlayer ~= Players.LocalPlayer and otherPlayer.Character then
                    for _, part in pairs(otherPlayer.Character:GetChildren()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            part.CanCollide = true
                        end
                    end
                end
            end
        end
    end
end

function PlayerNoClip.updateReferences(newHumanoid, newRootPart)
    -- No references to update
end

function PlayerNoClip.reset()
    PlayerNoClip.enabled = false
    if connections.playerNoclip then
        connections.playerNoclip:Disconnect()
        connections.playerNoclip = nil
    end
    if refreshReferences() then
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= Players.LocalPlayer and otherPlayer.Character then
                for _, part in pairs(otherPlayer.Character:GetChildren()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end
    end
end

function PlayerNoClip.debug()
    print("PlayerNoClip: enabled =", PlayerNoClip.enabled)
end

return PlayerNoClip