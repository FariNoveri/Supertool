-- Fly feature for Movement module

local Fly = {}

-- Dependencies
local deps = {}
local Utils = nil
local MobileControls = nil

-- State
local enabled = false
local flyBodyVelocity = nil
local flySpeed = 50
local joystickDelta = Vector2.new(0, 0)
local flyVerticalInput = 0
local connections = {}

-- Load modules
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
        warn("Failed to load Utils for Fly: " .. tostring(result))
        return nil
    end
end

local function loadMobileControls()
    if MobileControls then return MobileControls end
    
    local success, result = pcall(function()
        local response = game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement/MobileControls.lua")
        local func = loadstring(response)
        local controls = func()
        controls.init(deps)
        return controls
    end)
    
    if success then
        MobileControls = result
        return MobileControls
    else
        warn("Failed to load MobileControls for Fly: " .. tostring(result))
        return nil
    end
end

-- Clean up fly connections
local function cleanupConnections()
    local utils = loadUtils()
    if not utils then return end
    
    for name, connection in pairs(connections) do
        utils.safeDisconnect(connection)
    end
    connections = {}
end

-- Clean up BodyVelocity
local function cleanupBodyVelocity()
    local utils = loadUtils()
    if not utils then return end
    
    if flyBodyVelocity then
        utils.safeDestroy(flyBodyVelocity)
        flyBodyVelocity = nil
    end
end

-- Main fly loop
local function flyLoop()
    local utils = loadUtils()
    if not utils or not enabled then return end
    
    if not utils.refreshReferences() then return end
    local humanoid, rootPart = utils.getReferences()
    if not rootPart then return end
    
    -- Recreate BodyVelocity if missing
    if not flyBodyVelocity or flyBodyVelocity.Parent ~= rootPart then
        cleanupBodyVelocity()
        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        flyBodyVelocity.Parent = rootPart
    end
    
    local camera = workspace.CurrentCamera
    if not camera then return end
    
    local flyDirection = Vector3.new(0, 0, 0)
    flySpeed = utils.getSettingValue("FlySpeed", 50)
    
    -- Get joystick input from mobile controls
    local mobileControls = loadMobileControls()
    if mobileControls then
        joystickD