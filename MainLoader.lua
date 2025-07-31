local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid, hr, char
local gui, frame, logo
local selectedPlayer = nil -- For player selection

local flying, noclip, autoHeal, noFall, godMode = false, false, false, false, false
local flySpeed = 50
local speedEnabled, jumpEnabled, waterWalk, rocket, spin = false, false, false, false, false
local moveSpeed = 50
local jumpPower = 100
local spinSpeed = 20
local savedPositions = { [1] = nil, [2] = nil }
local followTarget = nil
local connections = {}
local antiRagdoll, antiSpectate, antiReport = false, false, false
local nickHidden, randomNick = false, false
local customNick = ""
local trajectoryEnabled = false
local macroRecording, macroPlaying, autoPlayOnRespawn = false, false, false
local macroActions = {}
local macroNoclip = false
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function notify(message, color)
	local success, errorMsg = pcall(function()
		if not gui then
			print("Notify failed: GUI not initialized")
			return
		end
		local notif = Instance.new("TextLabel")
		notif.Size = UDim2.new(0, 200, 0, 30)
		notif.Position = UDim2.new(0.5, -100, 0, 10)
		notif.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		notif.BackgroundTransparency = 0.5
		notif.TextColor3 = color or Color3.fromRGB(0, 255, 0)
		notif.TextScaled = true
		notif.Font = Enum.Font.Gotham
		notif.Text = message
		notif.BorderSizePixel = 0
		notif.ZIndex = 10
		notif.Parent = gui
		task.spawn(function()
			task.wait(3)
			notif:Destroy()
		end)
	end)
	if not success then
		print("Notify error: " .. tostring(errorMsg))
	end
end

local function clearConnections()
	for key, connection in pairs(connections) do
		if connection then
			connection:Disconnect()
			connections[key] = nil
		end
	end
end

local function isValidPosition(pos)
	return pos and not (pos.Y < -1000 or pos.Y > 10000 or math.abs(pos.X) > 10000 or math.abs(pos.Z) > 10000)
end

local function initChar()
	local success, errorMsg = pcall(function()
		char = player.Character or player.CharacterAdded:Wait()
		humanoid = char:WaitForChild("Humanoid", 10)
		hr = char:WaitForChild("HumanoidRootPart", 10)
		if not humanoid or not hr then
			error("Failed to find Humanoid or HumanoidRootPart")
		end
		print("Character initialized")
		
		-- Reapply active features
		if flying then toggleFly() toggleFly() end
		if noclip then toggleNoclip() toggleNoclip() end
		if speedEnabled then toggleSpeed() toggleSpeed() end
		if jumpEnabled then toggleJump() toggleJump() end
		if waterWalk then toggleWaterWalk() toggleWaterWalk() end
		if spin then toggleSpin() toggleSpin() end
		if autoHeal then toggleAutoHeal() toggleAutoHeal() end
		if godMode then toggleGodMode() toggleGodMode() end
		if noFall then toggleNoFall() toggleNoFall() end
		if antiRagdoll then toggleAntiRagdoll() toggleAntiRagdoll() end
		if followTarget then toggleFollowPlayer() toggleFollowPlayer() end
		if nickHidden then toggleHideNick() toggleHideNick() end
		if randomNick then toggleRandomNick() toggleRandomNick() end
		if customNick ~= "" then setCustomNick(customNick) end
		if antiSpectate then toggleAntiSpectate() toggleAntiSpectate() end
		if antiReport then toggleAntiReport() toggleAntiReport() end
		if trajectoryEnabled then toggleTrajectory() toggleTrajectory() end
		if macroRecording then toggleRecordMacro() toggleRecordMacro() end
		if macroPlaying then togglePlayMacro() togglePlayMacro() end
		if autoPlayOnRespawn then toggleAutoPlayMacro() toggleAutoPlayMacro() end
	end)
	if not success then
		print("initChar error: " .. tostring(errorMsg))
		notify("⚠️ Character init failed, retrying...", Color3.fromRGB(255, 100, 100))
		task.wait(5)
		initChar()
	end
end

local function toggleFly()
	flying = not flying
	if flying then
		local bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bv.Velocity = Vector3.new(0, 0, 0)
		bv.Parent = hr
		connections.fly = RunService.RenderStepped:Connect(function()
			if humanoid and humanoid.MoveDirection.Magnitude > 0 then
				bv.Velocity = humanoid.MoveDirection * flySpeed
			else
				bv.Velocity = Vector3.new(0, 0, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				bv.Velocity = bv.Velocity + Vector3.new(0, flySpeed, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				bv.Velocity = bv.Velocity - Vector3.new(0, flySpeed, 0)
			end
		end)
		notify("🛫 Fly Enabled")
	else
		if connections.fly then
			connections.fly:Disconnect()
			connections.fly = nil
		end
		if hr and hr:FindFirstChildOfClass("BodyVelocity") then
			hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
		end
		notify("🛬 Fly Disabled")
	end
end

local function toggleNoclip()
	noclip = not noclip
	if noclip then
		connections.noclip = RunService.Stepped:Connect(function()
			if char then
				for _, part in pairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
					end
				end
			end
		end)
		notify("🚶 Noclip Enabled")
	else
		if connections.noclip then
			connections.noclip:Disconnect()
			connections.noclip = nil
		end
		if char then
			for _, part in pairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = true
				end
			end
		end
		notify("🚶 Noclip Disabled")
	end
end

local function toggleSpeed()
	speedEnabled = not speedEnabled
	if speedEnabled then
		if humanoid then
			humanoid.WalkSpeed = moveSpeed
			notify("🏃 Speed Enabled")
		end
	else
		if humanoid then
			humanoid.WalkSpeed = 16
			notify("🏃 Speed Disabled")
		end
	end
end

local function toggleJump()
	jumpEnabled = not jumpEnabled
	if jumpEnabled then
		if humanoid then
			humanoid.JumpPower = jumpPower
			notify("🦘 Jump Enabled")
		end
	else
		if humanoid then
			humanoid.JumpPower = 50
			notify("🦘 Jump Disabled")
		end
	end
end

local function toggleWaterWalk()
	waterWalk = not waterWalk
	if waterWalk then
		local water = Instance.new("Part")
		water.Size = Vector3.new(1000, 1, 1000)
		water.Position = Vector3.new(0, 0, 0)
		water.Transparency = 0.5
		water.Anchored = true
		water.Parent = workspace
		connections.water = RunService.RenderStepped:Connect(function()
			if hr then
				water.Position = Vector3.new(hr.Position.X, 0, hr.Position.Z)
			end
		end)
		notify("🌊 Water Walk Enabled")
	else
		if connections.water then
			connections.water:Disconnect()
			connections.water = nil
		end
		for _, part in pairs(workspace:GetChildren()) do
			if part:IsA("Part") and part.Size == Vector3.new(1000, 1, 1000) then
				part:Destroy()
			end
		end
		notify("🌊 Water Walk Disabled")
	end
end

local function toggleRocket()
	rocket = not rocket
	if rocket then
		if hr then
			local bp = Instance.new("BodyPosition")
			bp.MaxForce = Vector3.new(0, math.huge, 0)
			bp.Position = hr.Position + Vector3.new(0, 100, 0)
			bp.Parent = hr
			task.spawn(function()
				task.wait(2)
				if bp then
					bp:Destroy()
				end
				rocket = false
				notify("🚀 Rocket Finished")
			end)
			notify("🚀 Rocket Launched")
		end
	else
		if hr and hr:FindFirstChildOfClass("BodyPosition") then
			hr:FindFirstChildOfClass("BodyPosition"):Destroy()
		end
		notify("🚀 Rocket Stopped")
	end
end

local function toggleSpin()
	spin = not spin
	if spin then
		if hr then
			local bg = Instance.new("BodyGyro")
			bg.MaxTorque = Vector3.new(0, math.huge, 0)
			bg.CFrame = hr.CFrame
			bg.Parent = hr
			connections.spin = RunService.RenderStepped:Connect(function()
				if bg then
					bg.CFrame = bg.CFrame * CFrame.Angles(0, math.rad(spinSpeed), 0)
				end
			end)
			notify("🌀 Spin Enabled")
		end
	else
		if connections.spin then
			connections.spin:Disconnect()
			connections.spin = nil
		end
		if hr and hr:FindFirstChildOfClass("BodyGyro") then
			hr:FindFirstChildOfClass("BodyGyro"):Destroy()
		end
		notify("🌀 Spin Disabled")
	end
end

local function toggleAutoHeal()
	autoHeal = not autoHeal
	if autoHeal then
		connections.autoHeal = RunService.RenderStepped:Connect(function()
			if humanoid and humanoid.Health < humanoid.MaxHealth then
				humanoid.Health = humanoid.MaxHealth
			end
		end)
		notify("❤️ Auto Heal Enabled")
	else
		if connections.autoHeal then
			connections.autoHeal:Disconnect()
			connections.autoHeal = nil
		end
		notify("❤️ Auto Heal Disabled")
	end
end

local function toggleGodMode()
	godMode = not godMode
	if godMode then
		if humanoid then
			humanoid.MaxHealth = math.huge
			humanoid.Health = math.huge
			notify("🛡️ God Mode Enabled")
		end
	else
		if humanoid then
			humanoid.MaxHealth = 100
			humanoid.Health = 100
			notify("🛡️ God Mode Disabled")
		end
	end
end

local function toggleNoFall()
	noFall = not noFall
	if noFall then
		connections.noFall = humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.FallingDown then
				humanoid:ChangeState(Enum.HumanoidStateType.Running)
			end
		end)
		notify("🪂 No Fall Damage Enabled")
	else
		if connections.noFall then
			connections.noFall:Disconnect()
			connections.noFall = nil
		end
		notify("🪂 No Fall Damage Disabled")
	end
end

local function toggleAntiRagdoll()
	antiRagdoll = not antiRagdoll
	if antiRagdoll then
		connections.antiRagdoll = humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Ragdoll then
				humanoid:ChangeState(Enum.HumanoidStateType.Running)
			end
		end)
		notify("🚫 Anti Ragdoll Enabled")
	else
		if connections.antiRagdoll then
			connections.antiRagdoll:Disconnect()
			connections.antiRagdoll = nil
		end
		notify("🚫 Anti Ragdoll Disabled")
	end
end

local function savePosition(slot)
	if hr then
		savedPositions[slot] = hr.CFrame
		notify("💾 Position " .. slot .. " Saved")
	else
		notify("⚠️ No HumanoidRootPart found", Color3.fromRGB(255, 100, 100))
	end
end

local function loadPosition(slot)
	if savedPositions[slot] and hr and isValidPosition(savedPositions[slot].Position) then
		hr.CFrame = savedPositions[slot]
		notify("📍 Position " .. slot .. " Loaded")
	else
		notify("⚠️ No saved position or invalid position", Color3.fromRGB(255, 100, 100))
	end
end

local function teleportToPlayer(target)
	if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and hr then
		local targetPos = target.Character.HumanoidRootPart.Position
		if isValidPosition(targetPos) then
			hr.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
			notify("👤 Teleported to " .. target.Name)
		else
			notify("⚠️ Invalid target position", Color3.fromRGB(255, 100, 100))
		end
	else
		notify("⚠️ No valid player selected", Color3.fromRGB(255, 100, 100))
	end
end

local function teleportToSpawn()
	if workspace:FindFirstChild("SpawnLocation") and hr then
		local spawnPos = workspace.SpawnLocation.Position + Vector3.new(0, 3, 0)
		if isValidPosition(spawnPos) then
			hr.CFrame = CFrame.new(spawnPos)
			notify("🏠 Teleported to Spawn")
		else
			notify("⚠️ Invalid spawn position", Color3.fromRGB(255, 100, 100))
		end
	else
		notify("⚠️ Spawn not found", Color3.fromRGB(255, 100, 100))
	end
end

local function toggleFollowPlayer(target)
	if followTarget then
		followTarget = nil
		if connections.follow then
			connections.follow:Disconnect()
			connections.follow = nil
		end
		notify("🚶 Stopped Following")
	else
		if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and hr then
			followTarget = target
			connections.follow = RunService.RenderStepped:Connect(function()
				if followTarget and followTarget.Character and followTarget.Character:FindFirstChild("HumanoidRootPart") then
					local targetPos = followTarget.Character.HumanoidRootPart.Position
					if isValidPosition(targetPos) then
						hr.CFrame = CFrame.new(targetPos + Vector3.new(3, 0, 3))
					else
						followTarget = nil
						connections.follow:Disconnect()
						connections.follow = nil
						notify("⚠️ Invalid target position", Color3.fromRGB(255, 100, 100))
					end
				else
					followTarget = nil
					connections.follow:Disconnect()
					connections.follow = nil
					notify("⚠️ Target lost", Color3.fromRGB(255, 100, 100))
				end
			end)
			notify("🚶 Following " .. target.Name)
		else
			notify("⚠️ No valid player selected", Color3.fromRGB(255, 100, 100))
		end
	end
end

local function pullPlayerToMe(target)
	if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and hr then
		local myPos = hr.Position
		if isValidPosition(myPos) then
			target.Character.HumanoidRootPart.CFrame = CFrame.new(myPos + Vector3.new(3, 0, 3))
			notify("👥 Pulled " .. target.Name .. " to you")
		else
			notify("⚠️ Invalid position", Color3.fromRGB(255, 100, 100))
		end
	else
		notify("⚠️ No valid player selected", Color3.fromRGB(255, 100, 100))
	end
end

local function pullPlayerToOther(puller, target)
	if puller and puller.Character and puller.Character:FindFirstChild("HumanoidRootPart") and
	   target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
		local pullerPos = puller.Character.HumanoidRootPart.Position
		if isValidPosition(pullerPos) then
			target.Character.HumanoidRootPart.CFrame = CFrame.new(pullerPos + Vector3.new(3, 0, 3))
			notify("👥 Pulled " .. target.Name .. " to " .. puller.Name)
		else
			notify("⚠️ Invalid puller position", Color3.fromRGB(255, 100, 100))
		end
	else
		notify("⚠️ Invalid players selected", Color3.fromRGB(255, 100, 100))
	end
end

local function toggleHideNick()
	nickHidden = not nickHidden
	if nickHidden then
		if char and char:FindFirstChild("Head") and char.Head:FindFirstChild("BillboardGui") then
			char.Head.BillboardGui.Enabled = false
		end
		notify("🙈 Nick Hidden")
	else
		if char and char:FindFirstChild("Head") and char.Head:FindFirstChild("BillboardGui") then
			char.Head.BillboardGui.Enabled = true
		end
		notify("🙉 Nick Visible")
	end
end

local function toggleRandomNick()
	randomNick = not randomNick
	if randomNick then
		local randomName = "User" .. math.random(1000, 9999)
		player.DisplayName = randomName
		notify("🎲 Random Nick: " .. randomName)
	else
		player.DisplayName = player.Name
		notify("🎲 Nick Reset")
	end
end

local function setCustomNick(nick)
	customNick = nick
	player.DisplayName = nick
	notify("✏️ Custom Nick: " .. nick)
end

local function toggleAntiSpectate()
	antiSpectate = not antiSpectate
	if antiSpectate then
		connections.antiSpectate = RunService.RenderStepped:Connect(function()
			for _, p in pairs(Players:GetPlayers()) do
				if p ~= player and p.CurrentCamera then
					p.CurrentCamera.CameraSubject = nil
				end
			end
		end)
		notify("👁️ Anti Spectate Enabled")
	else
		if connections.antiSpectate then
			connections.antiSpectate:Disconnect()
			connections.antiSpectate = nil
		end
		notify("👁️ Anti Spectate Disabled")
	end
end

local function toggleAntiReport()
	antiReport = not antiReport
	notify(antiReport and "🚫 Anti Report Enabled" or "🚫 Anti Report Disabled")
end

local function toggleTrajectory()
	trajectoryEnabled = not trajectoryEnabled
	if trajectoryEnabled then
		local line = Instance.new("Part")
		line.Anchored = true
		line.CanCollide = false
		line.Transparency = 0.5
		line.BrickColor = BrickColor.new("Bright red")
		line.Parent = workspace
		connections.trajectory = RunService.RenderStepped:Connect(function()
			if hr and humanoid and humanoid.MoveDirection.Magnitude > 0 then
				local start = hr.Position
				local endPos = start + humanoid.MoveDirection * 10
				line.Size = Vector3.new(0.2, 0.2, (endPos - start).Magnitude)
				line.CFrame = CFrame.new(start, endPos) * CFrame.new(0, 0, -(endPos - start).Magnitude / 2)
			else
				line.Size = Vector3.new(0, 0, 0)
			end
		end)
		notify("📏 Trajectory Enabled")
	else
		if connections.trajectory then
			connections.trajectory:Disconnect()
			connections.trajectory = nil
		end
		for _, part in pairs(workspace:GetChildren()) do
			if part:IsA("Part") and part.BrickColor == BrickColor.new("Bright red") then
				part:Destroy()
			end
		end
		notify("📏 Trajectory Disabled")
	end
end

local function toggleRecordMacro()
	if macroRecording then
		macroRecording = false
		if connections.macroRecord then
			connections.macroRecord:Disconnect()
			connections.macroRecord = nil
		end
		notify("⏹️ Macro Recording Stopped")
	else
		macroRecording = true
		macroActions = {}
		local startTime = tick()
		connections.macroRecord = RunService.RenderStepped:Connect(function()
			if hr then
				table.insert(macroActions, {
					time = tick() - startTime,
					position = hr.Position,
					velocity = hr.Velocity
				})
			end
		end)
		notify("⏺️ Macro Recording Started")
	end
end

local function togglePlayMacro()
	if macroPlaying then
		macroPlaying = false
		if connections.macroPlay then
			connections.macroPlay:Disconnect()
			connections.macroPlay = nil
		end
		notify("⏹️ Macro Playback Stopped")
	else
		if #macroActions == 0 then
			notify("⚠️ No macro recorded", Color3.fromRGB(255, 100, 100))
			return
		end
		macroPlaying = true
		local startTime = tick()
		local index = 1
		connections.macroPlay = RunService.RenderStepped:Connect(function()
			if index > #macroActions then
				macroPlaying = false
				connections.macroPlay:Disconnect()
				connections.macroPlay = nil
				notify("⏹️ Macro Playback Finished")
				return
			end
			local action = macroActions[index]
			if tick() - startTime >= action.time then
				if hr then
					hr.Position = action.position
					hr.Velocity = action.velocity
				end
				index = index + 1
			end
		end)
		notify("▶️ Macro Playback Started")
	end
end

local function toggleAutoPlayMacro()
	autoPlayOnRespawn = not autoPlayOnRespawn
	if autoPlayOnRespawn then
		connections.autoPlay = player.CharacterAdded:Connect(function()
			if #macroActions > 0 then
				togglePlayMacro()
			end
		end)
		notify("🔄 Auto Play Macro Enabled")
	else
		if connections.autoPlay then
			connections.autoPlay:Disconnect()
			connections.autoPlay = nil
		end
		notify("🔄 Auto Play Macro Disabled")
	end
end

local function resetCharacter()
	if humanoid then
		humanoid.Health = 0
		notify("🔄 Character Reset")
	end
end

local function cleanWorkspace()
	for _, obj in pairs(workspace:GetChildren()) do
		if not obj:IsA("Terrain") and not obj:IsA("Camera") and not Players:GetPlayerFromCharacter(obj) then
			obj:Destroy()
		end
	end
	notify("🧹 Workspace Cleaned")
end

local function optimizeGame()
	game.Lighting.Brightness = 1
	game.Lighting.GlobalShadows = false
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Material = Enum.Material.SmoothPlastic
		end
	end
	notify("⚙️ Game Optimized")
end

local function createGUI()
	local success, errorMsg = pcall(function()
		if gui then
			gui:Destroy()
			gui = nil
		end

		gui = Instance.new("ScreenGui")
		gui.Name = "SimpleUILibrary_Krnl"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.Enabled = true
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = player:WaitForChild("PlayerGui", 10)
		print("GUI parented to PlayerGui")

		logo = Instance.new("ImageButton")
		logo.Size = UDim2.new(0, 50, 0, 50)
		logo.Position = UDim2.new(1, -60, 0, 10)
		logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
		logo.BorderSizePixel = 0
		logo.Image = "rbxassetid://3570695787"
		logo.ZIndex = 10
		logo.Parent = gui
		print("Logo created")

		frame = Instance.new("Frame")
		frame.Size = isMobile and UDim2.new(0.8, 0, 0.6, 0) or UDim2.new(0, 600, 0, 400)
		frame.Position = UDim2.new(1, -610, 0.5, -200)
		frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		frame.BackgroundTransparency = 0.1
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.ZIndex = 10
		local uil = Instance.new("UIListLayout")
		uil.FillDirection = Enum.FillDirection.Horizontal
		uil.Padding = UDim.new(0, 5)
		uil.Parent = frame
		frame.Parent = gui
		print("Frame created")

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 40)
		title.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
		title.TextColor3 = Color3.new(1, 1, 1)
		title.Text = "Krnl UI"
		title.TextScaled = true
		title.Font = Enum.Font.Gotham
		title.ZIndex = 10
		title.Parent = frame
		print("Title created")

		local closeBtn = Instance.new("TextButton")
		closeBtn.Size = UDim2.new(0, 30, 0, 30)
		closeBtn.Position = UDim2.new(1, -35, 0, 5)
		closeBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
		closeBtn.Text = "✕"
		closeBtn.TextColor3 = Color3.new(1, 1, 1)
		closeBtn.TextScaled = true
		closeBtn.Font = Enum.Font.Gotham
		closeBtn.BorderSizePixel = 0
		closeBtn.ZIndex = 10
		closeBtn.Parent = frame
		closeBtn.Activated:Connect(function()
			frame.Visible = false
			notify("🖼️ UI Closed")
		end)
		print("Close button created")

		local function createCategory(name)
			local catFrame = Instance.new("ScrollingFrame")
			catFrame.Size = UDim2.new(0, 190, 1, -45)
			catFrame.Position = UDim2.new(0, 0, 0, 45)
			catFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			catFrame.BackgroundTransparency = 0.2
			catFrame.BorderSizePixel = 0
			catFrame.ZIndex = 10
			catFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
			catFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
			catFrame.ScrollBarThickness = 6
			catFrame.Parent = frame
			local catTitle = Instance.new("TextLabel")
			catTitle.Size = UDim2.new(1, 0, 0, 30)
			catTitle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			catTitle.TextColor3 = Color3.new(1, 1, 1)
			catTitle.Text = name
			catTitle.TextScaled = true
			catTitle.Font = Enum.Font.Gotham
			catTitle.ZIndex = 10
			catTitle.Parent = catFrame
			local catList = Instance.new("UIListLayout")
			catList.Padding = UDim.new(0, 5)
			catList.Parent = catFrame
			local catPadding = Instance.new("UIPadding")
			catPadding.PaddingLeft = UDim.new(0, 5)
			catPadding.PaddingTop = UDim.new(0, 35)
			catPadding.Parent = catFrame
			return catFrame
		end

		local function createButton(parent, text, callback)
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, -10, 0, 30)
			btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.Text = text
			btn.TextScaled = true
			btn.Font = Enum.Font.Gotham
			btn.BorderSizePixel = 0
			btn.ZIndex = 10
			btn.Parent = parent
			btn.Activated:Connect(callback)
			return btn
		end

		local function createTextBox(parent, placeholder, callback)
			local box = Instance.new("TextBox")
			box.Size = UDim2.new(1, -10, 0, 30)
			box.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			box.TextColor3 = Color3.new(1, 1, 1)
			box.PlaceholderText = placeholder
			box.TextScaled = true
			box.Font = Enum.Font.Gotham
			box.BorderSizePixel = 0
			box.ZIndex = 10
			box.Parent = parent
			box.FocusLost:Connect(function(enter)
				if enter then
					callback(box.Text)
				end
			end)
			return box
		end

		local function updatePlayerList(parent)
			-- Clear existing player buttons
			for _, child in pairs(parent:GetChildren()) do
				if child.Name:match("^Player_") then
					child:Destroy()
				end
			end
			-- Add buttons for each player
			local yOffset = 35
			for _, p in pairs(Players:GetPlayers()) do
				if p ~= player then
					local btn = Instance.new("TextButton")
					btn.Name = "Player_" .. p.Name
					btn.Size = UDim2.new(1, -10, 0, 30)
					btn.Position = UDim2.new(0, 5, 0, yOffset)
					btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
					btn.TextColor3 = selectedPlayer == p and Color3.fromRGB(0, 255, 0) or Color3.new(1, 1, 1)
					btn.Text = p.Name
					btn.TextScaled = true
					btn.Font = Enum.Font.Gotham
					btn.BorderSizePixel = 0
					btn.ZIndex = 10
					btn.Parent = parent
					btn.Activated:Connect(function()
						selectedPlayer = p
						updatePlayerList(parent)
						notify("👤 Selected " .. p.Name)
					end)
					yOffset = yOffset + 35
				end
			end
			parent.CanvasSize = UDim2.new(0, 0, 0, yOffset)
		end

		local movement = createCategory("Movement")
		createButton(movement, "Toggle Fly", toggleFly)
		createButton(movement, "Toggle Noclip", toggleNoclip)
		createButton(movement, "Toggle Speed", toggleSpeed)
		createButton(movement, "Toggle Jump", toggleJump)
		createButton(movement, "Toggle Water Walk", toggleWaterWalk)
		createButton(movement, "Toggle Rocket", toggleRocket)
		createButton(movement, "Toggle Spin", toggleSpin)

		local utility = createCategory("Utility")
		createButton(utility, "Toggle Auto Heal", toggleAutoHeal)
		createButton(utility, "Toggle God Mode", toggleGodMode)
		createButton(utility, "Toggle No Fall Damage", toggleNoFall)
		createButton(utility, "Toggle Anti Ragdoll", toggleAntiRagdoll)
		createButton(utility, "Save Position 1", function() savePosition(1) end)
		createButton(utility, "Load Position 1", function() loadPosition(1) end)
		createButton(utility, "Save Position 2", function() savePosition(2) end)
		createButton(utility, "Load Position 2", function() loadPosition(2) end)
		createButton(utility, "Teleport to Spawn", teleportToSpawn)
		createButton(utility, "Teleport to Player", function() teleportToPlayer(selectedPlayer) end)
		createButton(utility, "Toggle Follow Player", function() toggleFollowPlayer(selectedPlayer) end)
		createButton(utility, "Pull Player to Me", function() pullPlayerToMe(selectedPlayer) end)
		createButton(utility, "Pull Player to Other", function()
			if selectedPlayer then
				local otherPlayer = nil
				for _, p in pairs(Players:GetPlayers()) do
					if p ~= player and p ~= selectedPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
						otherPlayer = p
						break
					end
				end
				if otherPlayer then
					pullPlayerToOther(otherPlayer, selectedPlayer)
				else
					notify("⚠️ No other player found", Color3.fromRGB(255, 100, 100))
				end
			else
				notify("⚠️ No player selected", Color3.fromRGB(255, 100, 100))
			end
		end)

		local misc = createCategory("Misc")
		createButton(misc, "Toggle Hide Nick", toggleHideNick)
		createButton(misc, "Toggle Random Nick", toggleRandomNick)
		createTextBox(misc, "Enter Custom Nick", setCustomNick)
		createButton(misc, "Toggle Anti Spectate", toggleAntiSpectate)
		createButton(misc, "Toggle Anti Report", toggleAntiReport)
		createButton(misc, "Toggle Trajectory", toggleTrajectory)
		createButton(misc, "Toggle Record Macro", toggleRecordMacro)
		createButton(misc, "Toggle Play Macro", togglePlayMacro)
		createButton(misc, "Toggle Auto Play Macro", toggleAutoPlayMacro)
		createButton(misc, "Reset Character", resetCharacter)
		createButton(misc, "Clean Workspace", cleanWorkspace)
		createButton(misc, "Optimize Game", optimizeGame)

		-- Player selection category
		local playerSelect = createCategory("Player Select")
		updatePlayerList(playerSelect)
		Players.PlayerAdded:Connect(function() updatePlayerList(playerSelect) end)
		Players.PlayerRemoving:Connect(function(p)
			if selectedPlayer == p then
				selectedPlayer = nil
			end
			updatePlayerList(playerSelect)
		end)
	end)
	if not success then
		print("createGUI error: " .. tostring(errorMsg))
		notify("⚠️ UI creation failed, retrying...", Color3.fromRGB(255, 100, 100))
		task.wait(5)
		createGUI()
	end
end

local function makeDraggable(element)
	local dragging = false
	local dragStart = nil
	local startPos = nil

	element.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = element.Position
		end
	end)
	element.InputChanged:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
			local delta = input.Position - dragStart
			element.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
	element.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

local function setupUI()
	local success, errorMsg = pcall(function()
		createGUI()
		makeDraggable(logo)
		makeDraggable(frame)
		logo.Activated:Connect(function()
			frame.Visible = not frame.Visible
			notify("🖼️ UI " .. (frame.Visible and "ON" or "OFF"))
		end)
		initChar()
		
		-- Handle character respawn
		player.CharacterAdded:Connect(function()
			clearConnections()
			initChar()
		end)
	end)
	if not success then
		print("setupUI error: " .. tostring(errorMsg))
		notify("⚠️ UI setup failed, retrying...", Color3.fromRGB(255, 100, 100))
		task.wait(5)
		setupUI()
	end
end

setupUI()