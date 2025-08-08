-- utility.lua
-- Utility-related features for MinimalHackGUI by Fari Noveri

-- Dependencies: These must be passed from mainloader.lua
local Players, humanoid, rootPart, ScrollFrame, buttonStates

-- Initialize module
local Utility = {}

-- Kill Player
local function killPlayer()
    if humanoid then
        humanoid.Health = 0
        print("Player killed")
    else
        print("Cannot kill player: No valid humanoid")
    end
end

-- Reset Character
local function resetCharacter()
    if player and player.Character then
        player:LoadCharacter()
        print("Character reset")
    else
        print("Cannot reset character: No valid player or character")
    end
end

-- Function to create buttons for Utility features
function Utility.loadUtilityButtons(createButton)
    createButton("Kill Player", killPlayer)
    createButton("Reset Character", resetCharacter)
end

-- Function to reset Utility states (if any)
function Utility.resetStates()
    -- No persistent states in Utility, but included for consistency
end

-- Function to set dependencies
function Utility.init(deps)
    Players = deps.Players
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    ScrollFrame = deps.ScrollFrame
    buttonStates = deps.buttonStates
    player = deps.player
    
    -- Initialize state variables (none needed currently)
end

return Utility