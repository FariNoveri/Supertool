-- movement.lua: Main loader for movement features
-- Dependencies: Must be passed from mainloader.lua
local Players, RunService, Workspace, UserInputService, humanoid, rootPart, connections, buttonStates, ScrollFrame, ScreenGui, settings, player

local Movement = {}
Movement.features = {}

-- Load feature from URL
local function loadFeature(url)
    local success, featureFunc = pcall(loadstring, game:HttpGet(url))
    if success and featureFunc then
        local feature = featureFunc() -- Execute the function to get the feature table
        return feature
    else
        warn("Failed to load feature from " .. url)
        return nil
    end
end

-- Initialize module
function Movement.init(deps)
    print("Initializing Movement module")
    if not deps then
        warn("Error: No dependencies provided!")
        return false
    end

    -- Set dependencies
    Players = deps.Players
    RunService = deps.RunService
    Workspace = deps.Workspace
    UserInputService = deps.UserInputService
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    connections = deps.connections
    buttonStates = deps.buttonStates
    ScrollFrame = deps.ScrollFrame
    ScreenGui = deps.ScreenGui
    settings = deps.settings
    player = deps.player

    if not Players or not RunService or not Workspace or not UserInputService then
        warn("Critical services missing!")
        return false
    end

    if not player then
        player = Players.LocalPlayer
    end

    -- Load features
    local featureUrls = {
        SpeedHack = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement/SpeedHack.lua",
        JumpHack = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement/JumpHack.lua",
        MoonGravity = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement/MoonGravity.lua",
        DoubleJump = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement/DoubleJump.lua",
        InfiniteJump = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement/InfiniteJump.lua",
        WallClimb = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement/WallClimb.lua",
        Fly = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement/Fly.lua",
        NoClip = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement/NoClip.lua",
        WalkOnWater = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement/WalkOnWater.lua",
        SuperSwim = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement/SuperSwim.lua",
        PlayerNoClip = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement/PlayerNoClip.lua",
        MobileControls = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement/MobileControls.lua"
    }

    for name, url in pairs(featureUrls) do
        local feature = loadFeature(url)
        Movement.features[name] = feature
        if name == "Fly" and feature then
            -- Set禁止
            Movement.features["MobileControlls"]:setFlyModule(feature)
        end
    end

    -- Initialize features
    for name, feature in pairs(Movement.features) do
        if feature and feature.init then
            feature.init({
                Players = Players,
                RunService = RunService,
                Workspace = Workspace,
                UserInputService = UserInputService,
                humanoid = humanoid,
                rootPart = rootPart,
                connections = connections,
                buttonStates = buttonStates,
                ScrollFrame = ScrollFrame,
                ScreenGui = ScreenGui,
                settings = settings,
                player = player
            })
        end
    end

    print("Movement module initialized")
    return true
end

-- Load movement buttons
function Movement.loadMovementButtons(createButton, createToggleButton)
    for name, feature in pairs(Movement.features) do
        if feature and feature.toggle and name ~= "MobileControls" then
            createToggleButton(name, feature.toggle)
        end
    end
end

-- Update references
function Movement.updateReferences(newHumanoid, newRootPart)
    humanoid = newHumanoid
    rootPart = newRootPart
    for _, feature in pairs(Movement.features) do
        if feature and feature.updateReferences then
            feature.updateReferences(newHumanoid, newRootPart)
        end
    end
end

-- Reset states
function Movement.resetStates()
    for _, feature in pairs(Movement.features) do
        if feature and feature.reset then
            feature.reset()
        end
    end
end

-- Debug
function Movement.debug()
    print("=== Movement Module Debug ===")
    for name, feature in pairs(Movement.features) do
        if feature and feature.debug then
            print("Debugging " .. name)
            feature.debug()
        end
    end
end

-- Cleanup
function Movement.cleanup()
    for _, feature in pairs(Movement.features) do
        if feature and feature.cleanup then
            feature.cleanup()
        end
    end
    Movement.features = {}
end

return Movement