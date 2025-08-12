-- God Mode feature for MinimalHackGUI by Fari Noveri

local GodMode = {}

-- Dependencies
local humanoid, connections

-- State
GodMode.enabled = false

-- Toggle God Mode
local function toggleGodMode(enabled)
    GodMode.enabled = enabled
    if enabled then
        if humanoid then
            connections.godmode = humanoid.HealthChanged:Connect(function()
                if GodMode.enabled then
                    humanoid.Health = humanoid.MaxHealth
                end
            end)
            print("God Mode enabled")
        else
            warn("Cannot enable God Mode: humanoid is nil")
        end
    else
        if connections.godmode then
            connections.godmode:Disconnect()
            connections.godmode = nil
        end
        print("God Mode disabled")
    end
end

-- Load buttons for this feature
function GodMode.loadButtons(createButton, createToggleButton)
    createToggleButton("God Mode", toggleGodMode, "Player")
end

-- Reset states
function GodMode.resetStates()
    GodMode.enabled = false
    toggleGodMode(false)
end

-- Initialize
function GodMode.init(deps)
    humanoid = deps.humanoid
    connections = deps.connections
    
    GodMode.enabled = false
    
    return true
end

return GodMode