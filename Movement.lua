-- Movement.lua
-- Movement features for MinimalHackGUI by Fari Noveri

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local PhysicsService = game:GetService("PhysicsService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Movement feature variables
local flyEnabled = false
local noclipEnabled = false
local speedEnabled = false
local jumpHighEnabled = false
local spiderEnabled = false
local playerPhaseEnabled = false

-- Connections table for movement features
local connections = {}

-- Button states for toggles
local buttonStates = {
    Fly = false,
    Noclip = false,
    Speed = false,
    ["Jump High"] = false,
    Spider = false,
    ["Player Phase"] = false
}

-- Setup collision group for Noclip and Player Phase
local function setupCollisionGroup()
    local success, error = pcall(function()
        PhysicsService:CreateCollisionGroup("Players")
        PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
    end)
    if not success then
        warn("Failed to setup collision group: " .. tostring(error))
    end
end

-- Fly (Android Touch Controls)
local function toggleFly(enabled, utils)
    flyEnabled = enabled
    if enabled then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Name = "FlyBodyVelocity"
        bodyVelocity.MaxForce = Vector3.new(2000, 2000, 2000) -- Reduced for mobile
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = rootPart
        
        connections.fly = RunService.Heartbeat:Connect(function()
            if flyEnabled then
                local camera = Workspace.CurrentCamera
                local moveVector = humanoid.MoveDirection
                
                local cameraCFrame = camera.CFrame
                local forwardVector = cameraCFrame.LookVector
                local rightVector = cameraCFrame.RightVector
                local upVector = Vector3.new(0, 1, 0)
                
                local velocity = Vector3.new(0, 0, 0)
                local speed = utils.settings.FlySpeed.value
                
                if moveVector.Magnitude > 0 then
                    velocity = velocity + (forwardVector * -moveVector.Z * speed)
                    velocity = velocity + (rightVector * moveVector.X * speed)
                end
                
                if humanoid.Jump then
                    velocity = velocity + (upVector * speed)
                    humanoid.Jump = false
                end
                
                bodyVelocity.Velocity = velocity
            end
        end)
        if utils.notify then
            utils.notify("Fly enabled")
        else
            print("Fly enabled")
        end
    else
        if connections.fly then
            connections.fly:Disconnect()
            connections.fly = nil
        end
        if rootPart:FindFirstChild("FlyBodyVelocity") then
            rootPart:FindFirstChild("FlyBodyVelocity"):Destroy()
        end
        if utils.notify then
            utils.notify("Fly disabled")
        else
            print("Fly disabled")
        end
    end
end

-- Noclip
local function toggleNoclip(enabled, utils)
    noclipEnabled = enabled
    if enabled then
        connections.noclip = RunService.Stepped:Connect(function()
            if noclipEnabled and character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                        pcall(function()
                            part.CollisionGroup = "Players"
                        end)
                    end
                end
            end
        end)
        if utils.notify then
            utils.notify("Noclip enabled")
        else
            print("Noclip enabled")
        end
    else
        if connections.noclip then
            connections.noclip:Disconnect()
            connections.noclip = nil
        end
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                    pcall(function()
                        part.CollisionGroup = "Default"
                    end)
                end
            end
        end
        if utils.notify then
            utils.notify("Noclip disabled")
        else
            print("Noclip disabled")
        end
    end
end

-- Speed
local function toggleSpeed(enabled, utils)
    speedEnabled = enabled
    if enabled then
        humanoid.WalkSpeed = utils.settings.WalkSpeed.value
        if utils.notify then
            utils.notify("Speed enabled")
        else
            print("Speed enabled")
        end
    else
        humanoid.WalkSpeed = 16
        if utils.notify then
            utils.notify("Speed disabled")
        else
            print("Speed disabled")
        end
    end
end

-- Jump High
local function toggleJumpHigh(enabled, utils)
    jumpHighEnabled = enabled
    if enabled then
        humanoid.JumpHeight = utils.settings.JumpHeight.value
        humanoid.JumpPower = utils.settings.JumpHeight.value * 2.4
        connections.jumphigh = humanoid.Jumping:Connect(function()
            if jumpHighEnabled then
                rootPart.Velocity = Vector3.new(rootPart.Velocity.X, utils.settings.JumpHeight.value * 2.4, rootPart.Velocity.Z)
            end
        end)
        if utils.notify then
            utils.notify("Jump High enabled")
        else
            print("Jump High enabled")
        end
    else
        humanoid.JumpHeight = 7.2
        humanoid.JumpPower = 50
        if connections.jumphigh then
            connections.jumphigh:Disconnect()
            connections.jumphigh = nil
        end
        if utils.notify then
            utils.notify("Jump High disabled")
        else
            print("Jump High disabled")
        end
    end
end

-- Spider (stick to walls)
local function toggleSpider(enabled, utils)
    spiderEnabled = enabled
    if enabled then
        local bodyPosition = Instance.new("BodyPosition")
        bodyPosition.Name = "SpiderBodyPosition"
        bodyPosition.MaxForce = Vector3.new(2000, 2000, 2000) -- Reduced for mobile
        bodyPosition.Position = rootPart.Position
        bodyPosition.Parent = rootPart
        
        local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
        bodyAngularVelocity.Name = "SpiderBodyAngularVelocity"
        bodyAngularVelocity.MaxTorque = Vector3.new(2000, 2000, 2000)
        bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
        bodyAngularVelocity.Parent = rootPart
        
        connections.spider = RunService.Heartbeat:Connect(function()
            if spiderEnabled and rootPart then
                local ray = Workspace:Raycast(rootPart.Position, rootPart.CFrame.LookVector * 5) -- Reduced range
                if ray then
                    bodyPosition.Position = ray.Position + ray.Normal * 3
                    local lookDirection = -ray.Normal
                    bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
                    rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + lookDirection)
                end
            end
        end)
        if utils.notify then
            utils.notify("Spider enabled")
        else
            print("Spider enabled")
        end
    else
        if connections.spider then
            connections.spider:Disconnect()
            connections.spider = nil
        end
        if rootPart:FindFirstChild("SpiderBodyPosition") then
            rootPart:FindFirstChild("SpiderBodyPosition"):Destroy()
        end
        if rootPart:FindFirstChild("SpiderBodyAngularVelocity") then
            rootPart:FindFirstChild("SpiderBodyAngularVelocity"):Destroy()
        end
        if utils.notify then
            utils.notify("Spider disabled")
        else
            print("Spider disabled")
        end
    end
end

-- Player Phase (pass through other players)
local function togglePlayerPhase(enabled, utils)
    playerPhaseEnabled = enabled
    if enabled then
        connections.playerphase = RunService.Heartbeat:Connect(function()
            if playerPhaseEnabled and character then
                for _, otherPlayer in pairs(Players:GetPlayers()) do
                    if otherPlayer ~= player and otherPlayer.Character then
                        for _, part in pairs(otherPlayer.Character:GetChildren()) do
                            if part:IsA("BasePart") then
                                pcall(function()
                                    part.CollisionGroup = "Players"
                                end)
                            end
                        end
                    end
                end
            end
        end)
        if utils.notify then
            utils.notify("Player Phase enabled")
        else
            print("Player Phase enabled")
        end
    else
        if connections.playerphase then
            connections.playerphase:Disconnect()
            connections.playerphase = nil
        end
        for _, otherPlayer in pairs(Players:GetPlayers()) do
            if otherPlayer ~= player and otherPlayer.Character then
                for _, part in pairs(otherPlayer.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        pcall(function()
                            part.CollisionGroup = "Default"
                        end)
                    end
                end
            end
        end
        if utils.notify then
            utils.notify("Player Phase disabled")
        else
            print("Player Phase disabled")
        end
    end
end

-- Initialize Movement
local function initializeMovement()
    local screenGui = CoreGui:FindFirstChild("MinimalHackGUI")
    if not screenGui then
        warn("MinimalHackGUI not found")
        return
    end
    setupCollisionGroup()
end

-- Load buttons for mainloader.lua
local function loadButtons(scrollFrame, utils)
    initializeMovement()

    utils.createToggle("Fly", buttonStates["Fly"], function(state)
        buttonStates["Fly"] = state
        toggleFly(state, utils)
    end).Parent = scrollFrame

    utils.createToggle("Noclip", buttonStates["Noclip"], function(state)
        buttonStates["Noclip"] = state
        toggleNoclip(state, utils)
    end).Parent = scrollFrame

    utils.createToggle("Speed", buttonStates["Speed"], function(state)
        buttonStates["Speed"] = state
        toggleSpeed(state, utils)
    end).Parent = scrollFrame

    utils.createToggle("Jump High", buttonStates["Jump High"], function(state)
        buttonStates["Jump High"] = state
        toggleJumpHigh(state, utils)
    end).Parent = scrollFrame

    utils.createToggle("Spider", buttonStates["Spider"], function(state)
        buttonStates["Spider"] = state
        toggleSpider(state, utils)
    end).Parent = scrollFrame

    utils.createToggle("Player Phase", buttonStates["Player Phase"], function(state)
        buttonStates["Player Phase"] = state
        togglePlayerPhase(state, utils)
    end).Parent = scrollFrame
end

-- Cleanup function
local function cleanup()
    toggleFly(false, { notify = print })
    toggleNoclip(false, { notify = print })
    toggleSpeed(false, { notify = print })
    toggleJumpHigh(false, { notify = print })
    toggleSpider(false, { notify = print })
    togglePlayerPhase(false, { notify = print })
    
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    connections = {}
end

-- Handle character reset
local characterConnection
characterConnection = player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    
    flyEnabled = false
    noclipEnabled = false
    speedEnabled = false
    jumpHighEnabled = false
    spiderEnabled = false
    playerPhaseEnabled = false
    
    toggleFly(false, { notify = print })
    toggleNoclip(false, { notify = print })
    toggleSpeed(false, { notify = print })
    toggleJumpHigh(false, { notify = print })
    toggleSpider(false, { notify = print })
    togglePlayerPhase(false, { notify = print })
    
    buttonStates["Fly"] = false
    buttonStates["Noclip"] = false
    buttonStates["Speed"] = false
    buttonStates["Jump High"] = false
    buttonStates["Spider"] = false
    buttonStates["Player Phase"] = false
end)

-- Cleanup on script destruction
local function onScriptDestroy()
    cleanup()
    if characterConnection then
        characterConnection:Disconnect()
        characterConnection = nil
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