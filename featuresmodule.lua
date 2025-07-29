-- FeaturesModule.lua
-- Dibuat oleh Fari Noveri untuk SuperTool - Fitur Umum

local FeaturesModule = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local humanoid, hrp, char

local flying, noclip, noFall, autoHeal = false, false, false, false
local up, down = false, false

local Utilities = require(script.Parent:WaitForChild("Utilities"))

local function refreshCharacter()
	char = player.Character or player.CharacterAdded:Wait()
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:WaitForChild("HumanoidRootPart")
end

function FeaturesModule.initFeatures()
	refreshCharacter()

	Utilities.createStatusButton("🕊️ Fly", false, function(state)
		flying = state
	end)

	Utilities.createStatusButton("👻 Noclip", false, function(state)
		noclip = state
	end)

	Utilities.createStatusButton("❤️ Auto Heal", false, function(state)
		autoHeal = state
	end)

	Utilities.createStatusButton("🛡️ No Fall Damage", false, function(state)
		noFall = state
	end)

	-- Perbarui saat respawn
	player.CharacterAdded:Connect(function()
		task.wait(1)
		refreshCharacter()
	end)

	-- Loop runtime
	RunService.RenderStepped:Connect(function()
		if flying and hrp then
			local dir = humanoid.MoveDirection * 2
			if up then dir += Vector3.new(0, 2, 0) end
			if down then dir -= Vector3.new(0, 2, 0) end
			hrp.Velocity = dir * 30
		end
		if noclip and char then
			for _,v in pairs(char:GetDescendants()) do
				if v:IsA("BasePart") then
					v.CanCollide = false
				end
			end
		end
		if autoHeal and humanoid and humanoid.Health < humanoid.MaxHealth then
			humanoid.Health += 1
		end
	end)
end

return FeaturesModule
