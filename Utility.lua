-- Utility.lua
-- Utility features for MinimalHackGUI by Fari Noveri

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local commandPrefix = ";"
local commands = {}
local commandConnections = {}
local prankConnections = {}
local prankDuration = 5

-- Helper function to find player by name or partial name
local function findPlayer(name)
    name = name:lower()
    for _, p in pairs(Players:GetPlayers()) do
        if p.Name:lower():find(name) or p.DisplayName:lower():find(name) then
            return p
        end
    end
    return nil
end

-- Command System Setup
local function setupCommandSystem(utils)
    commands["rejoin"] = {
        description = "Rejoins the current server",
        execute = function(args)
            TeleportService:Teleport(game.PlaceId, player)
            return "Rejoining server..."
        end
    }

    commands["serverhop"] = {
        description = "Joins a new server",
        execute = function(args)
            local success, servers = pcall(function()
                return game:GetService("HttpService"):JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
            end)
            if success and servers and servers.data then
                local server = servers.data[math.random(1, #servers.data)]
                if server and server.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, player)
                    return "Hopping to new server..."
                else
                    return "No other servers found"
                end
            else
                return "Failed to fetch server list"
            end
        end
    }

    commands["fpscap"] = {
        description = "Sets FPS cap (30-240)",
        execute = function(args)
            local fps = tonumber(args[1])
            if fps and fps >= 30 and fps <= 240 then
                setfpscap(fps)
                return "FPS cap set to " .. fps
            else
                return "Invalid FPS value (use 30-240)"
            end
        end
    }

    commands["ping"] = {
        description = "Displays your ping",
        execute = function(args)
            local ping = player:GetNetworkPing() * 1000
            return string.format("Your ping: %.2f ms", ping)
        end
    }

    commands["time"] = {
        description = "Sets game time (0-24)",
        execute = function(args)
            local timeValue = tonumber(args[1])
            if timeValue and timeValue >= 0 and timeValue <= 24 then
                Lighting.ClockTime = timeValue
                return "Game time set to " .. timeValue
            else
                return "Invalid time value (use 0-24)"
            end
        end
    }

    commands["spin"] = {
        description = "Spins a player's character rapidly",
        execute = function(args)
            local targetName = args[1]
            if not targetName then
                return "Please provide a player name"
            end
            local targetPlayer = findPlayer(targetName)
            if not targetPlayer then
                return "Player not found: " .. targetName
            end
            if targetPlayer == player then
                return "Cannot prank yourself"
            end
            if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                return "Target player has no character"
            end

            local rootPart = targetPlayer.Character.HumanoidRootPart
            local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
            bodyAngularVelocity.MaxTorque = Vector3.new(0, math.huge, 0)
            bodyAngularVelocity.AngularVelocity = Vector3.new(0, 20, 0)
            bodyAngularVelocity.Parent = rootPart

            prankConnections[targetPlayer.UserId] = prankConnections[targetPlayer.UserId] or {}
            table.insert(prankConnections[targetPlayer.UserId], bodyAngularVelocity)

            task.spawn(function()
                task.wait(prankDuration)
                if bodyAngularVelocity then
                    bodyAngularVelocity:Destroy()
                end
                prankConnections[targetPlayer.UserId] = nil
            end)

            return "Spinning " .. targetPlayer.Name
        end
    }

    commands["fling"] = {
        description = "Flings a player into the air",
        execute = function(args)
            local targetName = args[1]
            if not targetName then
                return "Please provide a player name"
            end
            local targetPlayer = findPlayer(targetName)
            if not targetPlayer then
                return "Player not found: " .. targetName
            end
            if targetPlayer == player then
                return "Cannot prank yourself"
            end
            if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                return "Target player has no character"
            end

            local rootPart = targetPlayer.Character.HumanoidRootPart
            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bodyVelocity.Velocity = Vector3.new(math.random(-50, 50), 100, math.random(-50, 50))
            bodyVelocity.Parent = rootPart

            prankConnections[targetPlayer.UserId] = prankConnections[targetPlayer.UserId] or {}
            table.insert(prankConnections[targetPlayer.UserId], bodyVelocity)

            task.spawn(function()
                task.wait(prankDuration)
                if bodyVelocity then
                    bodyVelocity:Destroy()
                end
                prankConnections[targetPlayer.UserId] = nil
            end)

            return "Flinging " .. targetPlayer.Name
        end
    }

    commands["shake"] = {
        description = "Shakes a player's character position",
        execute = function(args)
            local targetName = args[1]
            if not targetName then
                return "Please provide a player name"
            end
            local targetPlayer = findPlayer(targetName)
            if not targetPlayer then
                return "Player not found: " .. targetName
            end
            if targetPlayer == player then
                return "Cannot prank yourself"
            end
            if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                return "Target player has no character"
            end

            local rootPart = targetPlayer.Character.HumanoidRootPart
            local connection
            connection = RunService.Heartbeat:Connect(function()
                if rootPart then
                    rootPart.CFrame = rootPart.CFrame + Vector3.new(
                        math.random(-1, 1) * 0.5,
                        0,
                        math.random(-1, 1) * 0.5
                    )
                end
            end)

            prankConnections[targetPlayer.UserId] = prankConnections[targetPlayer.UserId] or {}
            table.insert(prankConnections[targetPlayer.UserId], connection)

            task.spawn(function()
                task.wait(prankDuration)
                if connection then
                    connection:Disconnect()
                end
                prankConnections[targetPlayer.UserId] = nil
            end)

            return "Shaking " .. targetPlayer.Name
        end
    }

    commands["drop"] = {
        description = "Drops a player by removing their floor",
        execute = function(args)
            local targetName = args[1]
            if not targetName then
                return "Please provide a player name"
            end
            local targetPlayer = findPlayer(targetName)
            if not targetPlayer then
                return "Player not found: " .. targetName
            end
            if targetPlayer == player then
                return "Cannot prank yourself"
            end
            if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                return "Target player has no character"
            end

            local rootPart = targetPlayer.Character.HumanoidRootPart
            local floor = Instance.new("Part")
            floor.Size = Vector3.new(10, 0.2, 10)
            floor.Position = rootPart.Position - Vector3.new(0, 2, 0)
            floor.Anchored = true
            floor.CanCollide = true
            floor.Transparency = 1
            floor.Parent = Workspace

            task.spawn(function()
                rootPart.CFrame = rootPart.CFrame + Vector3.new(0, 5, 0)
                task.wait(0.5)
                floor:Destroy()
            end)

            prankConnections[targetPlayer.UserId] = prankConnections[targetPlayer.UserId] or {}
            table.insert(prankConnections[targetPlayer.UserId], floor)

            task.spawn(function()
                task.wait(prankDuration)
                prankConnections[targetPlayer.UserId] = nil
            end)

            return "Dropping " .. targetPlayer.Name
        end
    }

    local function spoofChat(message)
        if utils.notify then
            utils.notify(message)
        else
            print(message)
        end
    end

    local function processCommand(message)
        if message:sub(1, #commandPrefix) == commandPrefix then
            local args = message:sub(#commandPrefix + 1):split(" ")
            local cmdName = args[1]:lower()
            table.remove(args, 1)
            
            if commands[cmdName] then
                local result = commands[cmdName].execute(args)
                spoofChat(result)
            else
                spoofChat("Unknown command: " .. cmdName)
            end
        end
    end

    if player.Chatted then
        commandConnections.chat = player.Chatted:Connect(processCommand)
    end
end

-- Cleanup function
local function cleanup()
    for _, connection in pairs(commandConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    for userId, pranks in pairs(prankConnections) do
        for _, prank in pairs(pranks) do
            if prank then
                if typeof(prank) == "Instance" then
                    prank:Destroy()
                elseif typeof(prank) == "RBXScriptConnection" then
                    prank:Disconnect()
                end
            end
        end
    end
    prankConnections = {}
end

-- Handle player leaving
local playerRemovingConnection
playerRemovingConnection = Players.PlayerRemoving:Connect(function(p)
    if prankConnections[p.UserId] then
        for _, prank in pairs(prankConnections[p.UserId]) do
            if prank then
                if typeof(prank) == "Instance" then
                    prank:Destroy()
                elseif typeof(prank) == "RBXScriptConnection" then
                    prank:Disconnect()
                end
            end
        end
        prankConnections[p.UserId] = nil
    end
end)

-- Load buttons for mainloader.lua
local function loadButtons(scrollFrame, utils)
    setupCommandSystem(utils)

    utils.createButton("Show Commands", function()
        local commandList = "Available Commands:\n"
        for cmdName, cmdData in pairs(commands) do
            commandList = commandList .. commandPrefix .. cmdName .. ": " .. cmdData.description .. "\n"
        end
        if utils.notify then
            utils.notify(commandList)
        else
            print(commandList)
        end
    end).Parent = scrollFrame

    -- Add input for prank commands
    local prankFrame = Instance.new("Frame")
    prankFrame.Name = "PrankFrame"
    prankFrame.Parent = scrollFrame
    prankFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    prankFrame.BorderSizePixel = 0
    prankFrame.Size = UDim2.new(1, 0, 0, 60)

    local prankInput = Instance.new("TextBox")
    prankInput.Name = "PrankInput"
    prankInput.Parent = prankFrame
    prankInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    prankInput.BorderSizePixel = 0
    prankInput.Position = UDim2.new(0, 5, 0, 5)
    prankInput.Size = UDim2.new(1, -10, 0, 25)
    prankInput.Font = Enum.Font.Gotham
    prankInput.Text = ""
    prankInput.PlaceholderText = "Enter player name for prank..."
    prankInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    prankInput.TextSize = 11

    local prankButtonsFrame = Instance.new("Frame")
    prankButtonsFrame.Name = "PrankButtonsFrame"
    prankButtonsFrame.Parent = prankFrame
    prankButtonsFrame.BackgroundTransparency = 1
    prankButtonsFrame.Position = UDim2.new(0, 5, 0, 35)
    prankButtonsFrame.Size = UDim2.new(1, -10, 0, 25)

    local prankButtonsLayout = Instance.new("UIListLayout")
    prankButtonsLayout.Parent = prankButtonsFrame
    prankButtonsLayout.FillDirection = Enum.FillDirection.Horizontal
    prankButtonsLayout.Padding = UDim.new(0, 5)

    local prankCommands = {"spin", "fling", "shake", "drop"}
    for _, cmdName in ipairs(prankCommands) do
        local button = Instance.new("TextButton")
        button.Name = cmdName .. "Button"
        button.Parent = prankButtonsFrame
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        button.BorderSizePixel = 0
        button.Size = UDim2.new(0, 80, 0, 20)
        button.Font = Enum.Font.Gotham
        button.Text = cmdName:upper()
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 10
        button.MouseButton1Click:Connect(function()
            local targetName = prankInput.Text
            if targetName == "" then
                if utils.notify then
                    utils.notify("Please enter a player name")
                end
                return
            end
            local result = commands[cmdName].execute({targetName})
            if utils.notify then
                utils.notify(result)
            end
        end)
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        end)
        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end)
    end
end

-- Cleanup on script destruction
local function onScriptDestroy()
    cleanup()
    if playerRemovingConnection then
        playerRemovingConnection:Disconnect()
        playerRemovingConnection = nil
    end
end

-- Connect cleanup to GUI destruction
local screenGui = CoreGui:FindFirstChild("MinimalHackGUI")
if screenGui then
    screenGui.AncestryChanged:Connect(function(_, parent)
        if not parent then
            onScriptDestroy()
        end
    end)
end

-- Return module
return {
    loadButtons = loadButtons,
    cleanup = cleanup,
    reset = cleanup
}