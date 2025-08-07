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

-- Settings for movement features
local settings = {
    FlySpeed = { value = 50, default = 50, min = 10, max = 200 },
    JumpHeight = { value = 50, default = 50, min = 10, max = 150 },
    WalkSpeed = { value = 100, default = 100, min = 16, max = 300 }
}

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
    pcall(function()
        PhysicsService:CreateCollisionGroup("Players")
        PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
    end)
end

-- Fly (Android Touch Controls)
local function toggleFly(enabled)
    flyEnabled = enabled
    if enabled then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Name = "FlyBodyVelocity"
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
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
                local speed = settings.FlySpeed.value
                
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
    else
        if connections.fly then
            connections.fly:Disconnect()
        end
        if rootPart:FindFirstChild("FlyBodyVelocity") then
            rootPart:FindFirstChild("FlyBodyVelocity"):Destroy()
        end
    end
end

-- Noclip
local function toggleNoclip(enabled)
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
    else
        if connections.noclip then
            connections.noclip:Disconnect()
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
    end
end

-- Speed
local function toggleSpeed(enabled)
    speedEnabled = enabled
    if enabled then
        humanoid.WalkSpeed = settings.WalkSpeed.value
    else
        humanoid.WalkSpeed = 16
    end
end

-- Jump High
local function toggleJumpHigh(enabled)
    jumpHighEnabled = enabled
    if enabled then
        humanoid.JumpHeight = settings.JumpHeight.value
        humanoid.JumpPower = settings.JumpHeight.value * 2.4
        connections.jumphigh = humanoid.Jumping:Connect(function()
            if jumpHighEnabled then
                rootPart.Velocity = Vector3.new(rootPart.Velocity.X, settings.JumpHeight.value * 2.4, rootPart.Velocity.Z)
            end
        end)
    else
        humanoid.JumpHeight = 7.2
        humanoid.JumpPower = 50
        if connections.jumphigh then
            connections.jumphigh:Disconnect()
        end
    end
end

-- Spider (stick to walls)
local function toggleSpider(enabled)
    spiderEnabled = enabled
    if enabled then
        local bodyPosition = Instance.new("BodyPosition")
        bodyPosition.Name = "SpiderBodyPosition"
        bodyPosition.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyPosition.Position = rootPart.Position
        bodyPosition.Parent = rootPart
        
        local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
        bodyAngularVelocity.Name = "SpiderBodyAngularVelocity"
        bodyAngularVelocity.MaxTorque = Vector3.new(4000, 4000, 4000)
        bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
        bodyAngularVelocity.Parent = rootPart
        
        connections.spider = RunService.Heartbeat:Connect(function()
            if spiderEnabled and rootPart then
                local ray = Workspace:Raycast(rootPart.Position, rootPart.CFrame.LookVector * 10)
                if ray then
                    bodyPosition.Position = ray.Position + ray.Normal * 3
                    local lookDirection = -ray.Normal
                    bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
                    rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + lookDirection)
                end
            end
        end)
    else
        if connections.spider then
            connections.spider:Disconnect()
        end
        if rootPart:FindFirstChild("SpiderBodyPosition") then
            rootPart:FindFirstChild("SpiderBodyPosition"):Destroy()
        end
        if rootPart:FindFirstChild("SpiderBodyAngularVelocity") then
            rootPart:FindFirstChild("SpiderBodyAngularVelocity"):Destroy()
        end
    end
end

-- Player Phase (pass through other players)
local function togglePlayerPhase(enabled)
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
    else
        if connections.playerphase then
            connections.playerphase:Disconnect()
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
    end
end

-- Initialize Movement
local function initializeMovement()
    setupCollisionGroup()
end

-- Load buttons for mainloader.lua
local function loadButtons(scrollFrame, utils)
    initializeMovement()

    utils.createToggle("Fly", buttonStates["Fly"], function(state)
        buttonStates["Fly"] = state
        toggleFly(state)
        if utils.notify then
            utils.notify("Fly " .. (state and "enabled" or "disabled"))
        else
            print("Fly " .. (state and "enabled" or "disabled"))
        end
    end).Parent = scrollFrame

    utils.createToggle("Noclip", buttonStates["Noclip"], function(state)
        buttonStates["Noclip"] = state
        toggleNoclip(state)
        if utils.notify then
            utils.notify("Noclip " .. (state and "enabled" or "disabled"))
        else
            print("Noclip " .. (state and "enabled" or "disabled"))
        end
    end).Parent = scrollFrame

    utils.createToggle("Speed", buttonStates["Speed"], function(state)
        buttonStates["Speed"] = state
        toggleSpeed(state)
        if utils.notify then
            utils.notify("Speed " .. (state and "enabled" or "disabled"))
        else
            print("Speed " .. (state and "enabled" or "disabled"))
        end
    end).Parent = scrollFrame

    utils.createToggle("Jump High", buttonStates["Jump High"], function(state)
        buttonStates["Jump High"] = state
        toggleJumpHigh(state)
        if utils.notify then
            utils.notify("Jump High " .. (state and "enabled" or "disabled"))
        else
            print("Jump High " .. (state and "enabled" or "disabled"))
        end
    end).Parent = scrollFrame

    utils.createToggle("Spider", buttonStates["Spider"], function(state)
        buttonStates["Spider"] = state
        toggleSpider(state)
        if utils.notify then
            utils.notify("Spider " .. (state and "enabled" or "disabled"))
        else
            print("Spider " .. (state and "enabled" or "disabled"))
        end
    end).Parent = scrollFrame

    utils.createToggle("Player Phase", buttonStates["Player Phase"], function(state)
        buttonStates["Player Phase"] = state
        togglePlayerPhase(state)
        if utils.notify then
            utils.notify("Player Phase " .. (state and "enabled" or "disabled"))
        else
            print("Player Phase " .. (state and "enabled" or "disabled"))
        end
    end).Parent = scrollFrame

    utils.createSlider("Fly Speed", settings.FlySpeed.min, settings.FlySpeed.max, settings.FlySpeed.value, function(value)
        settings.FlySpeed.value = value
        if flyEnabled then
            toggleFly(false)
            toggleFly(true)
        end
        if utils.notify then
            utils.notify("Fly Speed set to " .. value)
        else
            print("Fly Speed set to " .. value)
        end
    end).Parent = scrollFrame

    utils.createSlider("Jump Height", settings.JumpHeight.min, settings.JumpHeight.max, settings.JumpHeight.value, function(value)
        settings.JumpHeight.value = value
        if jumpHighEnabled then
            toggleJumpHigh(false)
            toggleJumpHigh(true)
        end
        if utils.notify then
            utils.notify("Jump Height set to " .. value)
        else
            print("Jump Height set to " .. value)
        end
    end).Parent = scrollFrame

    utils.createSlider("Walk Speed", settings.WalkSpeed.min, settings.WalkSpeed.max, settings.WalkSpeed.value, function(value)
        settings.WalkSpeed.value = value
        if speedEnabled then
            toggleSpeed(false)
            toggleSpeed(true)
        end
        if utils.notify then
            utils.notify("Walk Speed set to " .. value)
        else
            print("Walk Speed set to " .. value)
        end
    end).Parent = scrollFrame
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
    
    toggleFly(false)
    toggleNoclip(false)
    toggleSpeed(false)
    toggleJumpHigh(false)
    toggleSpider(false)
    togglePlayerPhase(false)
    
    buttonStates["Fly"] = false
    buttonStates["Noclip"] = false
    buttonStates["Speed"] = false
    buttonStates["Jump High"] = false
    buttonStates["Spider"] = false
    buttonStates["Player Phase"] = false
end)

-- Cleanup function
local function cleanup()
    toggleFly(false)
    toggleNoclip(false)
    toggleSpeed(false)
    toggleJumpHigh(false)
    toggleSpider(false)
    togglePlayerPhase(false)
    
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    if characterConnection then
        characterConnection:Disconnect()
    end
end

-- Cleanup on script destruction
local function onScriptDestroy()
    cleanup()
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