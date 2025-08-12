-- Anti AFK feature for MinimalHackGUI by Fari Noveri

local AntiAFK = {}

-- Dependencies
local Players, Workspace, connections

-- State
AntiAFK.enabled = false

-- Toggle Anti AFK
local function toggleAntiAFK(enabled)
    AntiAFK.enabled = enabled
    if enabled then
        connections.antiafk = Players.LocalPlayer.Idled:Connect(function()
            if AntiAFK.enabled then
                game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
                game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame)
            end
        end)
        print("Anti AFK enabled")
    else
        if connections.antiafk then
            connections.antiafk:Disconnect()
            connections.antiafk = nil
        end
        print("Anti AFK disabled")
    end
end

-- Load buttons for this feature
function AntiAFK.loadButtons(createButton, createToggleButton)
    createToggleButton("Anti AFK", toggleAntiAFK, "Player")
end

-- Reset states
function AntiAFK.resetStates()
    AntiAFK.enabled = false
    toggleAntiAFK(false)
end

-- Initialize
function AntiAFK.init(deps)
    Players = deps.Players
    Workspace = deps.Workspace
    connections = deps.connections
    
    AntiAFK.enabled = false
    
    return true
end

return AntiAFK