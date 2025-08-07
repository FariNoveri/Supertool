local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

local Visual = {}
Visual.fullbrightEnabled = false
Visual.flashlightEnabled = false
Visual.lowDetailEnabled = false
local connections = {}
local settings = {
    FlashlightBrightness = { value = 5, default = 5, min = 1, max = 10 },
    FlashlightRange = { value = 100, default = 100, min = 50, max = 200 },
    FullbrightBrightness = { value = 2, default = 2, min = 0, max = 5 }
}
local originalLighting = {
    Brightness = Lighting.Brightness,
    GlobalShadows = Lighting.GlobalShadows,
    FogEnd = Lighting.FogEnd,
    EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
    EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
}

function Visual.toggleFullbright(enabled)
    Visual.fullbrightEnabled = enabled
    if enabled then
        Lighting.Brightness = settings.FullbrightBrightness.value
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
    else
        Lighting.Brightness = originalLighting.Brightness
        Lighting.GlobalShadows = originalLighting.GlobalShadows
        Lighting.FogEnd = originalLighting.FogEnd
        Lighting.EnvironmentDiffuseScale = originalLighting.EnvironmentDiffuseScale
        Lighting.EnvironmentSpecularScale = originalLighting.EnvironmentSpecularScale
    end
end

function Visual.toggleFlashlight(enabled)
    Visual.flashlightEnabled = enabled
    if enabled then
        local flashlight = Instance.new("PointLight")
        flashlight.Name = "Flashlight"
        flashlight.Brightness = settings.FlashlightBrightness.value
        flashlight.Range = settings.FlashlightRange.value
        flashlight.Parent = rootPart
    else
        if rootPart and rootPart:FindFirstChild("Flashlight") then
            rootPart:FindFirstChild("Flashlight"):Destroy()
        end
    end
end

function Visual.toggleLowDetailMode(enabled)
    Visual.lowDetailEnabled = enabled
    if enabled then
        -- Reduce texture quality by setting MaterialVariant to a lower detail material
        for _, object in pairs(Workspace:GetDescendants()) do
            if object:IsA("BasePart") and object.Material ~= Enum.Material.ForceField then
                object.MaterialVariant = "LowDetail"
            end
        end
        -- Disable shadows
        Lighting.GlobalShadows = false
        -- Reduce particle effects
        for _, particle in pairs(Workspace:GetDescendants()) do
            if particle:IsA("ParticleEmitter") then
                particle.Enabled = false
            end
        end
        -- Lower render distance for fog
        Lighting.FogEnd = 50
    else
        -- Restore default materials
        for _, object in pairs(Workspace:GetDescendants()) do
            if object:IsA("BasePart") then
                object.MaterialVariant = ""
            end
        end
        -- Restore shadows
        Lighting.GlobalShadows = originalLighting.GlobalShadows
        -- Restore particle effects
        for _, particle in pairs(Workspace:GetDescendants()) do
            if particle:IsA("ParticleEmitter") then
                particle.Enabled = true
            end
        end
        -- Restore fog
        Lighting.FogEnd = originalLighting.FogEnd
    end
end

function Visual.cleanup()
    Visual.toggleFullbright(false)
    Visual.toggleFlashlight(false)
    Visual.toggleLowDetailMode(false)
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
end

-- Update character references when character respawns
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    rootPart = character:WaitForChild("HumanoidRootPart")
    Visual.cleanup() -- Reset all visual features on respawn
end)

return Visual