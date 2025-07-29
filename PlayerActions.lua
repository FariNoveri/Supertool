-- PlayerActions.lua
-- Dibuat oleh Fari Noveri untuk SuperTool - Aksi Antar Pemain

local PlayerActions = {}

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local Utilities = require(script.Parent:WaitForChild("Utilities"))

local hrp = nil
local savedPos = nil

local function refreshRootPart()
	local char = player.Character or player.CharacterAdded:Wait()
	hr = char:WaitForChild("HumanoidRootPart")
end

function PlayerActions.initPlayerActions()
	refreshRootPart()

	-- Simpan lokasi
	Utilities.createButton("📍 Simpan Lokasi", function()
		if hr then
			savedPos = hr.Position
		end
	end)

	-- Teleport ke lokasi
	Utilities.createButton("🚀 Teleport ke Lokasi", function()
		if savedPos and hr then
			hr.CFrame = CFrame.new(savedPos)
		end
	end)

	-- Dropdown daftar pemain
	local selectedName = nil
	local dropdown = Utilities.createDropdown("🎯 Pilih Pemain", function(name)
		selectedName = name
	end)

	-- Tombol teleport ke pemain
	Utilities.createButton("🌍 Teleport ke Pemain", function()
		local target = Players:FindFirstChild(selectedName)
		if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and hr then
			hr.CFrame = target.Character.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
		end
	end)

	-- Tombol tarik pemain ke kamu
	Utilities.createButton("🧲 Tarik Pemain", function()
		local target = Players:FindFirstChild(selectedName)
		if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and hr then
			target.Character.HumanoidRootPart.CFrame = hr.CFrame + Vector3.new(0, 5, 0)
		end
	end)

	-- Follow pemain secara real-time
	local following = false
	Utilities.createStatusButton("👣 Ikuti Pemain", false, function(state)
		following = state
		if state then
			spawn(function()
				while following and selectedName do
					local target = Players:FindFirstChild(selectedName)
					if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and hr then
						hr.CFrame = target.Character.HumanoidRootPart.CFrame + Vector3.new(0, 0, -3)
					end
					wait(0.2)
				end
			end)
		end
	end)

	-- Update root part saat respawn
	player.CharacterAdded:Connect(function()
		wait(1)
		refreshRootPart()
	end)
end

return PlayerActions
