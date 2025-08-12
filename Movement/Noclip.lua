-- Noclip feature for Movement module

local Noclip = {}

-- Dependencies
local deps = {}
local Utils = nil

-- State
local enabled = false
local connection = nil

-- Load Utils module
local function loadUtils()
    if Utils then return Utils end
    
    local success, result = pcall(function()
        local response = game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement/Utils.lua")
        local func = loadstring(response)
        local utils = func()
        utils.init(deps)
        return utils
    end)
    
    if success then
        Utils = result
        return Utils
    else
        warn("Failed to load Utils for Noclip: " .. tostring(result))
        return nil
    end
end

-- Noclip loop
local function noclipLoop()
    local utils = loadUtils()
    if not utils or not enabled then return end
    
    if not utils.refreshReferences() then return end
    local humanoid, rootPart, player, character = utils.getReferences()
    if not character then return end
    
    for _, part in pairs(character:GetChildren()) do
        if part:IsA("BasePart") and part.CanCollide then
            part.CanCollide = false
        end
    end
end

-- Enable noclip
local function enableNoclip()
    local utils = loadUtils()
    if not utils then return false end
    
    if not utils.refreshReferences() then
        warn("Failed to get character for noclip")
        return false
    end
    
    -- Start noclip loop
    connection = deps.RunService.Stepped:Connect(noclipLoop)
    
    print("Noclip enabled")
    return true
end

-- Disable noclip
local function disableNoclip()
    local utils = loadUtils()
    if not utils then return end
    
    -- Stop noclip loop
    if connection then
        utils.safeDisconnect(connection)
        connection = nil
    end
    
    -- Re-enable collision
    if utils.refreshReferences() then
        local humanoid, rootPart, player, character = utils.getReferences()
        if character then
            for _, part in pairs(character:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
    
    print("Noclip disabled")
end

-- Toggle noclip
function Noclip.toggle(enable)
    enabled = enable
    
    if enabled then
        local success = enableNoclip()
        if not success then
            enabled = false
            warn("Failed to enable noclip")
        end
    else
        disableNoclip()
    end
    
    print("Noclip", enabled and "enabled" or "disabled")
end

-- Initialize noclip feature
function Noclip.init(dependencies)
    if not dependencies then
        warn("Noclip: No dependencies provided!")
        return false
    end
    
    deps = dependencies
    
    print("Noclip feature initialized")
    return true
end

-- Update references
function Noclip.updateReferences(newHumanoid, newRootPart)
    if Utils then
        Utils.updateReferences(newHumanoid, newRootPart)
    end
    
    -- Reapply if enabled
    if enabled then
        disableNoclip()
        task.wait(0.1)
        enableNoclip()
    end
end

-- Reset state
function Noclip.reset()
    if enabled then
        Noclip.toggle(false)
    end
    enabled = false
    print("Noclip feature reset")
end

-- Cleanup
function Noclip.cleanup()
    Noclip.reset()
    
    local utils = loadUtils()
    if utils and connection then
        utils.safeDisconnect(connection)
        connection = nil
    end
    
    Utils = nil
    print("Noclip feature cleaned up")
end

return Noclip