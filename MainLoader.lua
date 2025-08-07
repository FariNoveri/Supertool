local Players = game:GetService("Players")
local player = Players.LocalPlayer

print("[Supertool] Starting script")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MinimalHackGUI"
screenGui.Parent = player.PlayerGui
screenGui.ResetOnSpawn = false
print("[Supertool] ScreenGui created")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 100)
frame.Position = UDim2.new(0.5, -100, 0.5, -50)
frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- Merah biar gampang kelihatan
frame.Parent = screenGui
print("[Supertool] Frame created")