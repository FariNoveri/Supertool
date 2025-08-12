-- Speed Hack feature for Movement module

local Speed = {}

-- Dependencies
local deps = {}
local Utils = nil

-- State
local enabled = false
local defaultWalkSpeed = 16

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
        warn("Failed to load Utils for Speed: " .. tostring(result))
        return nil
    end
end

-- Apply speed hack
local function applySpeed()
    local utils = loadUtils()
    if not utils or not utils.refreshReferences() then
        return false
    end
    
    local humanoid = utils.getReferences()
    if not humanoid then
        return false
    end
    
    local walkSpeed = utils.getSettingValue("WalkSpeed", 50)
    humanoid.WalkSpeed = walkSpeed
    return true
end

-- Reset speed to default
local function resetSpeed()
    local utils = loadUtils()
    if not utils or not utils.refreshReferences() then
        return false
    end
    
    local humanoid = utils.getReferences()
    if not humanoid then
        return false
    end
    
    humanoid.WalkSpeed = defaultWalkSpeed
    return true
end

-- Toggle speed hack
function Speed.toggle(enable)
    enabled = enable
    
    local utils = loadUtils()
    if not utils then return end
    
    if enabled then
        local success = utils.applyWithRetry(applySpeed, 3)
        if not success then
            warn("Failed to apply speed hack")
            enabled = false
        end
    else
        utils.applyWithRetry(resetSpeed, 2)
    end
    
    print("Speed hack", enabled and "enabled" or "disabled")
end

-- Initialize speed feature
function Speed.init(dependencies)
    if not dependencies then
        warn("Speed: No dependencies provided!")
        return false
    end
    
    deps = dependencies
    
    -- Get default walk speed
    if deps.humanoid then
        defaultWalkSpeed = deps.humanoid.WalkSpeed or 16
    end
    
    print("Speed feature initialized")
    return true
end

-- Update references
function Speed.updateReferences(newHumanoid, newRootPart)
    if newHumanoid then
        defaultWalkSpeed = newHumanoid.WalkSpeed or 16
    end
    
    if Utils then
        Utils.updateReferences(newHumanoid, newRootPart)
    end
    
    -- Reapply if enabled
    if enabled then
        local utils = loadUtils()
        if utils then
            utils.applyWithRetry(applySpeed, 2)
        end
    end
end

-- Reset state
function Speed.reset()
    if enabled then
        Speed.toggle(false)
    end
    enabled = false
    print("Speed feature reset")
end

-- Cleanup
function Speed.cleanup()
    Speed.reset()
    Utils = nil
    print("Speed feature cleaned up")
end

return Speed