-- Jump Hack feature for Movement module

local Jump = {}

-- Dependencies
local deps = {}
local Utils = nil

-- State
local enabled = false
local defaultJumpPower = 50
local defaultJumpHeight = 7.2

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
        warn("Failed to load Utils for Jump: " .. tostring(result))
        return nil
    end
end

-- Apply jump hack
local function applyJump()
    local utils = loadUtils()
    if not utils or not utils.refreshReferences() then
        return false
    end
    
    local humanoid = utils.getReferences()
    if not humanoid then
        return false
    end
    
    local jumpHeight = utils.getSettingValue("JumpHeight", 50)
    
    if humanoid:FindFirstChild("JumpHeight") then
        humanoid.JumpHeight = jumpHeight
    else
        -- Convert jump height to jump power for older games
        humanoid.JumpPower = jumpHeight * 2.4
    end
    
    return true
end

-- Reset jump to default
local function resetJump()
    local utils = loadUtils()
    if not utils or not utils.refreshReferences() then
        return false
    end
    
    local humanoid = utils.getReferences()
    if not humanoid then
        return false
    end
    
    if humanoid:FindFirstChild("JumpHeight") then
        humanoid.JumpHeight = defaultJumpHeight
    else
        humanoid.JumpPower = defaultJumpPower
    end
    
    return true
end

-- Toggle jump hack
function Jump.toggle(enable)
    enabled = enable
    
    local utils = loadUtils()
    if not utils then return end
    
    if enabled then
        local success = utils.applyWithRetry(applyJump, 3)
        if not success then
            warn("Failed to apply jump hack")
            enabled = false
        end
    else
        utils.applyWithRetry(resetJump, 2)
    end
    
    print("Jump hack", enabled and "enabled" or "disabled")
end

-- Initialize jump feature
function Jump.init(dependencies)
    if not dependencies then
        warn("Jump: No dependencies provided!")
        return false
    end
    
    deps = dependencies
    
    -- Get default jump values
    if deps.humanoid then
        if deps.humanoid:FindFirstChild("JumpHeight") then
            defaultJumpHeight = deps.humanoid.JumpHeight or 7.2
        else
            defaultJumpPower = deps.humanoid.JumpPower or 50
        end
    end
    
    print("Jump feature initialized")
    return true
end

-- Update references
function Jump.updateReferences(newHumanoid, newRootPart)
    if newHumanoid then
        if newHumanoid:FindFirstChild("JumpHeight") then
            defaultJumpHeight = newHumanoid.JumpHeight or 7.2
        else
            defaultJumpPower = newHumanoid.JumpPower or 50
        end
    end
    
    if Utils then
        Utils.updateReferences(newHumanoid, newRootPart)
    end
    
    -- Reapply if enabled
    if enabled then
        local utils = loadUtils()
        if utils then
            utils.applyWithRetry(applyJump, 2)
        end
    end
end

-- Reset state
function Jump.reset()
    if enabled then
        Jump.toggle(false)
    end
    enabled = false
    print("Jump feature reset")
end

-- Cleanup
function Jump.cleanup()
    Jump.reset()
    Utils = nil
    print("Jump feature cleaned up")
end

return Jump