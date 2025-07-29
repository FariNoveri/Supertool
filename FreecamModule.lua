-- FreecamModule.lua
-- Dibuat oleh Fari Noveri untuk SuperTool - Mode Kamera Bebas Mobile

local FreecamModule = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local cam = workspace.CurrentCamera
local Utilities = require(script.Parent:WaitForChild("Utilities"))

local active = false
local speed = 2
local camUp, camDown = false, false
local savedCFrame = nil

function FreecamModule.initFreecam()
	Utilities.createStatusButton("📷 Freecam", false, function(state)
		active = state
		if state then
			savedCFrame = cam.CFrame
			if player.Character and player.Character:FindFirstChild("Humanoid") then
				player.Character.Humanoid.WalkSpeed = 0
			end
		else
			if savedCFrame then
				cam.CFrame = savedCFrame
			end
			if player.Character and player.Character:FindFirstChild("Humanoid") then
				player.Character.Humanoid.WalkSpeed = 16
			end
		end
	end)

	-- Tombol naik dan turun kamera
	Utilities.createToggleButton("⬆️ Kamera Naik", false, function(state)
		camUp = state
	end)
	Utilities.createToggleButton("⬇️ Kamera Turun", false, function(state)
		camDown = state
	end)

	-- Loop per frame
	RunService.RenderStepped:Connect(function()
		if active then
			local moveVec = Vector3.zero
			if UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)[1] then
				moveVec = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)[1].Position
			end

			local moveDirection = Vector3.new(moveVec.X, 0, -moveVec.Y)
			local delta = (cam.CFrame:VectorToWorldSpace(moveDirection) * speed)
			if camUp then delta += Vector3.new(0, speed, 0) end
			if camDown then delta -= Vector3.new(0, speed, 0) end

			cam.CFrame = cam.CFrame + delta * RunService.RenderStepped:Wait()
		end
	end)
end

return FreecamModule
