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

-- Refresh karakter dan komponen penting
local function refreshCharacter()
	char = player.Character or player.CharacterAdded:Wait()
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:WaitForChild("HumanoidRootPart")
end

function FeaturesModule.initFeatures()
	refreshCharacter()

	-- Fly
	Utilities.createStatusButton("🕊️ Fly", false, function(state)
		flying = state
	end)

	-- Fly - Naik
	Utilities.createStatusButton("⬆️ Naik Saat Fly", false, function(state)
		up = state
	end)

	-- Fly - Turun
	Utilities.createStatusButton("⬇️ Turun Saat Fly", false, function(state)
		down = state
	end)

	-- Noclip
	Utilities.createStatusButton("👻 Noclip", false, function(state)
		noclip = state
	end)

	-- Auto Heal
	Utilities.createStatusButton("❤️ Auto Heal", false, function(state)
		autoHeal = state
	end)

	-- No Fall Damage
	Utilities.createStatusButton("🛡️ No Fall Damage", false, function(state)
		noFall = state
		if humanoid then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, not state)
		end
	end)

	-- Perbarui ulang saat respawn
	player.CharacterAdded:Connect(function()
		task.wait(1)
		refreshCharacter()
		-- Jika noFall masih aktif, setel lagi
		if noFall and humanoid then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
		end
	end)

	-- Runtime loop
	RunService.RenderStepped:Connect(function()
		if flying and hrp and humanoid then
			local dir = humanoid.MoveDirection
			if up then dir += Vector3.new(0, 1, 0) end
			if down then dir -= Vector3.new(0, 1, 0) end
			hrp.Velocity = dir * 10  -- disesuaikan untuk HP agar tidak terlalu cepat
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
