local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local Movement = {}
Movement.flyEnabled = false
Movement.noclipEnabled = false
Movement.speedEnabled = false
Movement.jumpHighEnabled = false
Movement.spiderEnabled = false
Movement.playerPhaseEnabled = false
local connections = {}
local settings = {
    FlySpeed = { value = 50, default = 50, min = 10, max = 200 },
    JumpHeight = { value = 50, default = 50, min = 10, max = 150 },
    WalkSpeed = { value = 100, default = 100, min = 16, max = 300 }
}

function Movement.toggleFly(enabled)
    Movement.flyEnabled = enabled
    if enabled then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = rootPart
        
        connections.fly = RunService.Heartbeat:Connect(function()
            if Movement.flyEnabled then
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
        if rootPart and rootPart:FindFirstChild("BodyVelocity") then
            rootPart:FindFirstChild("BodyVelocity"):Destroy()
        end
    end
end

function Movement.toggleNoclip(enabled)
    Movement.noclipEnabled = enabled
    if enabled then
        connections.noclip = RunService.Stepped:Connect(function()
            if Movement.noclipEnabled and character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
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
                end
            end
        end
    end
end

function Movement.toggleSpeed(enabled)
    Movement.speedEnabled = enabled
    if enabled then
        humanoid.WalkSpeed = settings.WalkSpeed.value
    else
        humanoid.WalkSpeed = 16
    end
end

function Movement.toggleJumpHigh(enabled)
    Movement.jumpHighEnabled = enabled
    if enabled then
        humanoid.JumpHeight = settings.JumpHeight.value
        humanoid.JumpPower = settings.JumpHeight.value * 2.4
        connections.jumphigh = humanoid.Jumping:Connect(function()
            if Movement.jumpHighEnabled then
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

function Movement.toggleSpider(enabled)
    Movement.spiderEnabled = enabled
    if enabled then
        local bodyPosition = Instance.new("BodyPosition")
        bodyPosition.MaxForce = Vector3.new(4000, 4000, 4000)
        bodyPosition.Position = rootPart.Position
        bodyPosition.Parent = rootPart
        
        local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
        bodyAngularVelocity.MaxTorque = Vector3.new(4000, 4000, 4000)
        bodyAngularVelocity.AngularVelocity = Vector3.new(0, 0, 0)
        bodyAngularVelocity.Parent = rootPart
        
        connections.spider = RunService.Heartbeat:Connect(function()
            if Movement.spiderEnabled and rootPart then
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
        if rootPart and rootPart:FindFirstChild("BodyPosition") then
            rootPart:FindFirstChild("BodyPosition"):Destroy()
        end
        if rootPart and rootPart:FindFirstChild("BodyAngularVelocity") then
            rootPart:FindFirstChild("BodyAngularVelocity"):Destroy()
        end
    end
end

function Movement.togglePlayerPhase(enabled)
    Movement.playerPhaseEnabled = enabled
    if enabled then
        connections.playerphase = RunService.Heartbeat:Connect(function()
            if Movement.playerPhaseEnabled and character then
                for _, otherPlayer in pairs(Players:GetPlayers()) do
                    if otherPlayer ~= player and otherPlayer.Character then
                        for _, part in pairs(otherPlayer.Character:GetChildren()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
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
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.CanCollide = true
                    end
                end
            end
        end
    end
end

function Movement.cleanup()
    Movement.toggleFly(false)
    Movement.toggleNoclip(false)
    Movement.toggleSpeed(false)
    Movement.toggleJumpHigh(false)
    Movement.toggleSpider(false)
    Movement.togglePlayerPhase(false)
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
end

-- Update character references when character respawns
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    Movement.cleanup() -- Reset all movement features on respawn
end)

return Movement