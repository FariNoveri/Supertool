local CoreGui = game:GetService("CoreGui")

-- Debug Label: Start
local DebugStart = Instance.new("TextLabel")
DebugStart.Name = "DebugStart"
DebugStart.Parent = CoreGui
DebugStart.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
DebugStart.Size = UDim2.new(0, 200, 0, 30)
DebugStart.Position = UDim2.new(0.5, -100, 0.3, -15)
DebugStart.Font = Enum.Font.Gotham
DebugStart.Text = "DEBUG: Script Started"
DebugStart.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugStart.TextSize = 12
DebugStart.Visible = true

-- Test Players service
local PlayersSuccess, PlayersResult = pcall(function()
    return game:GetService("Players")
end)

-- Debug Label: Players Service
local DebugPlayers = Instance.new("TextLabel")
DebugPlayers.Name = "DebugPlayers"
DebugPlayers.Parent = CoreGui
DebugPlayers.BackgroundColor3 = PlayersSuccess and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
DebugPlayers.Size = UDim2.new(0, 200, 0, 30)
DebugPlayers.Position = UDim2.new(0.5, -100, 0.35, -15)
DebugPlayers.Font = Enum.Font.Gotham
DebugPlayers.Text = PlayersSuccess and "DEBUG: Players Success" or "DEBUG: Players Failed"
DebugPlayers.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugPlayers.TextSize = 12
DebugPlayers.Visible = true

-- Test HttpService
local HttpSuccess, HttpResult = pcall(function()
    return game:GetService("HttpService")
end)

-- Debug Label: HttpService
local DebugHttpService = Instance.new("TextLabel")
DebugHttpService.Name = "DebugHttpService"
DebugHttpService.Parent = CoreGui
DebugHttpService.BackgroundColor3 = HttpSuccess and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
DebugHttpService.Size = UDim2.new(0, 200, 0, 30)
DebugHttpService.Position = UDim2.new(0.5, -100, 0.4, -15)
DebugHttpService.Font = Enum.Font.Gotham
DebugHttpService.Text = HttpSuccess and "DEBUG: HttpService Success" or "DEBUG: HttpService Failed"
DebugHttpService.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugHttpService.TextSize = 12
DebugHttpService.Visible = true