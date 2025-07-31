local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid, hr, char
local gui, frame, logo
local selectedPlayer = nil
local defaultLogoPos = UDim2.new(1, -60, 0, 10)
local defaultFramePos = UDim2.new(1, -610, 0.5, -200)
local originalHumanoidDescription = nil

local flying, freecam, noclip, autoHeal, noFall, godMode = false, false, false, false, false, false
local flySpeed = 50
local freecamSpeed = 50
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
local macroRecording, macroPlaying, autoPlayOnRespawn, recordOnRespawn = false, false, false, false
local macroActions = {}
local macroNoclip = false
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local freecamCFrame = nil
local freecamVelocity = Vector3.new(0, 0, 0)
local mouseDelta = Vector2.new(0, 0)

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

local function ensureCharacterVisible()
	if char then
		for _, part in pairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 0
				part.LocalTransparencyModifier = 0
			end
		end
	end
end

local function resetCharacterState()
	if hr and humanoid then
		hr.Velocity = Vector3.new(0, 0, 0)
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
		ensureCharacterVisible()
	end
end

local function saveOriginalAvatar()
	local success, desc = pcall(function()
		return humanoid:GetDescription()
	end)
	if success and desc then
		originalHumanoidDescription = desc
		print("Original avatar saved")
	else
		notify("⚠️ Failed to save original avatar", Color3.fromRGB(255, 100, 100))
	end
end

local function initChar()
	local success, errorMsg = pcall(function()
		char = player.Character or player.CharacterAdded:Wait()
		humanoid = char:WaitForChild("Humanoid", 10)
		hr = char:WaitForChild("HumanoidRootPart", 10)
		if not humanoid or not hr then
			error("Failed to find Humanoid or HumanoidRootPart")
		end
		saveOriginalAvatar()
		print("Character initialized")
		ensureCharacterVisible()
		
		if flying then toggleFly() toggleFly() end
		if freecam then toggleFreecam() toggleFreecam() end
		if noclip then toggleNoclip() toggleNoclip() end
		if speedEnabled then toggleSpeed() toggleSpeed() end
		if jumpEnabled then toggleJump() toggleJump() end
		if waterWalk then toggleWaterWalk() toggleWaterWalk() end
		if spin then toggleSpin() toggleSpin() end
		if autoHeal then toggleAutoHeal() toggleAutoHeal() end
		if godMode then toggleGodMode() toggleGodMode() end
		if noFall then toggleNoFall() toggleNoFall() end
		if antiRagdoll then toggleAntiRagdoll() toggleAntiRagdoll() end
		if followTarget then toggleFollowPlayer(followTarget) toggleFollowPlayer(followTarget) end
		if nickHidden then toggleHideNick() toggleHideNick() end
		if randomNick then toggleRandomNick() toggleRandomNick() end
		if customNick ~= "" then setCustomNick(customNick) end
		if antiSpectate then toggleAntiSpectate() toggleAntiSpectate() end
		if antiReport then toggleAntiReport() toggleAntiReport() end
		if trajectoryEnabled then toggleTrajectory() toggleTrajectory() end
		if macroRecording then toggleRecordMacro() toggleRecordMacro() end
		if macroPlaying then togglePlayMacro() togglePlayMacro() end
		if autoPlayOnRespawn then toggleAutoPlayMacro() toggleAutoPlayMacro() end
		if recordOnRespawn then toggleRecordOnRespawn() toggleRecordOnRespawn() end
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
		if freecam then
			toggleFreecam()
			notify("📷 Freecam disabled to enable Fly", Color3.fromRGB(255, 100, 100))
		end
		local bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bv.Velocity = Vector3.new(0, 0, 0)
		bv.Parent = hr
		local bg = Instance.new("BodyGyro")
		bg.MaxTorque = Vector3.new(0, math.huge, 0)
		bg.P = 10000
		bg.Parent = hr
		connections.fly = RunService.RenderStepped:Connect(function()
			if not hr or not humanoid or not camera then
				return
			end
			local moveDir = Vector3.new(0, 0, 0)
			local forward = camera.CFrame.LookVector
			local right = camera.CFrame.RightVector
			local up = camera.CFrame.UpVector
			
			if UserInputService:IsKeyDown(Enum.KeyCode.W) or (isMobile and UserInputService:GetFocusedTextBox() == nil and UserInputService.TouchEnabled) then
				moveDir = moveDir + forward
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				moveDir = moveDir - forward
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				moveDir = moveDir + right
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				moveDir = moveDir - right
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				moveDir = moveDir + up
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				moveDir = moveDir - up
			end
			
			if moveDir.Magnitude > 0 then
				moveDir = moveDir.Unit * flySpeed
			end
			bv.Velocity = moveDir
			
			local flatLook = Vector3.new(forward.X, 0, forward.Z).Unit
			if flatLook.Magnitude > 0 then
				bg.CFrame = CFrame.new(Vector3.new(0, 0, 0), flatLook)
			end
		end)
		notify("🛫 Fly Enabled")
	else
		if connections.fly then
			connections.fly:Disconnect()
			connections.fly = nil
		end
		if hr then
			if hr:FindFirstChildOfClass("BodyVelocity") then
				hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
			end
			if hr:FindFirstChildOfClass("BodyGyro") then
				hr:FindFirstChildOfClass("BodyGyro"):Destroy()
			end
		end
		notify("🛬 Fly Disabled")
	end
end

local function toggleFreecam()
	freecam = not freecam
	if freecam then
		if flying then
			toggleFly()
			notify("🛫 Fly disabled to enable Freecam", Color3.fromRGB(255, 100, 100))
		end
		freecamCFrame = camera.CFrame
		freecamVelocity = Vector3.new(0, 0, 0)
		mouseDelta = Vector2.new(0, 0)
		camera.CameraType = Enum.CameraType.Scriptable
		connections.freecam = RunService.RenderStepped:Connect(function(dt)
			if not camera then
				return
			end
			local moveDir = Vector3.new(0, 0, 0)
			local forward = freecamCFrame.LookVector
			local right = freecamCFrame.RightVector
			local up = freecamCFrame.UpVector
			
			if UserInputService:IsKeyDown(Enum.KeyCode.W) or (isMobile and UserInputService:GetFocusedTextBox() == nil and UserInputService.TouchEnabled) then
				moveDir = moveDir + forward
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				moveDir = moveDir - forward
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				moveDir = moveDir + right
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				moveDir = moveDir - right
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				moveDir = moveDir + up
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				moveDir = moveDir - up
			end
			
			if moveDir.Magnitude > 0 then
				freecamVelocity = moveDir.Unit * freecamSpeed
			else
				freecamVelocity = Vector3.new(0, 0, 0)
			end
			
			freecamCFrame = freecamCFrame + freecamVelocity * dt
			camera.CFrame = freecamCFrame
		end)
		connections.mouse = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				mouseDelta = input.Delta
				local yaw = -mouseDelta.X * 0.002
				local pitch = -mouseDelta.Y * 0.002
				freecamCFrame = CFrame.new(freecamCFrame.Position) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
			end
		end)
		notify("📷 Freecam Enabled")
	else
		if connections.freecam then
			connections.freecam:Disconnect()
			connections.freecam = nil
		end
		if connections.mouse then
			connections.mouse:Disconnect()
			connections.mouse = nil
		end
		if camera and humanoid then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
			if hr then
				camera.CFrame = CFrame.new(hr.Position + Vector3.new(0, 5, 10), hr.Position)
			end
		end
		freecamCFrame = nil
		freecamVelocity = Vector3.new(0, 0, 0)
		mouseDelta = Vector2.new(0, 0)
		notify("📷 Freecam Disabled")
	end
end

local function returnToCharacter()
	if freecam and hr and humanoid then
		freecamCFrame = CFrame.new(hr.Position + Vector3.new(0, 5, 10), hr.Position)
		camera.CFrame = freecamCFrame
		notify("📷 Returned to Character")
	else
		notify("⚠️ Freecam not enabled or character not loaded", Color3.fromRGB(255, 100, 100))
	end
end

local function cancelFreecam()
	if freecam then
		toggleFreecam()
		notify("📷 Freecam Canceled")
	else
		notify("⚠️ Freecam not enabled", Color3.fromRGB(255, 100, 100))
	end
end

local function teleportCharacterToCamera()
	if freecam and hr and isValidPosition(freecamCFrame.Position) then
		local targetCFrame = CFrame.new(freecamCFrame.Position + Vector3.new(0, 3, 0))
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
		local tween = TweenService:Create(hr, tweenInfo, {CFrame = targetCFrame})
		tween:Play()
		tween.Completed:Connect(function()
			notify("👤 Character Teleported to Camera")
		end)
	else
		notify("⚠️ Freecam not enabled or invalid position", Color3.fromRGB(255, 100, 100))
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
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
		local tween = TweenService:Create(hr, tweenInfo, {CFrame = savedPositions[slot]})
		tween:Play()
		tween.Completed:Connect(function()
			notify("📍 Position " .. slot .. " Loaded")
		end)
	else
		notify("⚠️ No saved position or invalid position", Color3.fromRGB(255, 100, 100))
	end
end

local function teleportToPlayer(target)
	if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and hr then
		local targetPos = target.Character.HumanoidRootPart.Position
		if isValidPosition(targetPos) then
			local targetCFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
			local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
			local tween = TweenService:Create(hr, tweenInfo, {CFrame = targetCFrame})
			tween:Play()
			tween.Completed:Connect(function()
				notify("👤 Teleported to " .. target.Name)
			end)
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
			local spawnCFrame = CFrame.new(spawnPos)
			local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
			local tween = TweenService:Create(hr, tweenInfo, {CFrame = spawnCFrame})
			tween:Play()
			tween.Completed:Connect(function()
				notify("🏠 Teleported to Spawn")
			end)
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
		return
	end
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

local function cancelFollowPlayer()
	if followTarget then
		followTarget = nil
		if connections.follow then
			connections.follow:Disconnect()
			connections.follow = nil
		end
		notify("🚶 Follow Canceled")
	else
		notify("⚠️ Not following anyone", Color3.fromRGB(255, 100, 100))
	end
end

local function pullPlayerToMe(target)
	if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and hr then
		local myPos = hr.Position
		if isValidPosition(myPos) then
			local targetHR = target.Character.HumanoidRootPart
			local wasCollidable = {}
			for _, part in pairs(target.Character:GetDescendants()) do
				if part:IsA("BasePart") then
					wasCollidable[part] = part.CanCollide
					part.CanCollide = false
				end
			end
			local targetCFrame = CFrame.new(myPos + Vector3.new(3, 0, 3))
			connections.pull = RunService.RenderStepped:Connect(function()
				if target.Character and targetHR and isValidPosition(myPos) then
					targetHR.CFrame = targetCFrame
				else
					if connections.pull then
						connections.pull:Disconnect()
						connections.pull = nil
					end
				end
			end)
			task.spawn(function()
				task.wait(1)
				if connections.pull then
					connections.pull:Disconnect()
					connections.pull = nil
				end
				for _, part in pairs(target.Character:GetDescendants()) do
					if part:IsA("BasePart") and wasCollidable[part] ~= nil then
						part.CanCollide = wasCollidable[part]
					end
				end
			end)
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
			local targetHR = target.Character.HumanoidRootPart
			local wasCollidable = {}
			for _, part in pairs(target.Character:GetDescendants()) do
				if part:IsA("BasePart") then
					wasCollidable[part] = part.CanCollide
					part.CanCollide = false
				end
			end
			local targetCFrame = CFrame.new(pullerPos + Vector3.new(3, 0, 3))
			connections.pull = RunService.RenderStepped:Connect(function()
				if target.Character and targetHR and puller.Character and isValidPosition(pullerPos) then
					targetHR.CFrame = targetCFrame
				else
					if connections.pull then
						connections.pull:Disconnect()
						connections.pull = nil
					end
				end
			end)
			task.spawn(function()
				task.wait(1)
				if connections.pull then
					connections.pull:Disconnect()
					connections.pull = nil
				end
				for _, part in pairs(target.Character:GetDescendants()) do
					if part:IsA("BasePart") and wasCollidable[part] ~= nil then
						part.CanCollide = wasCollidable[part]
					end
				end
			end)
			notify("👥 Pulled " .. target.Name .. " to " .. puller.Name)
		else
			notify("⚠️ Invalid puller position", Color3.fromRGB(255, 100, 100))
		end
	else
		notify("⚠️ Invalid players selected", Color3.fromRGB(255, 100, 100))
	end
end

local function resetUIPosition()
	if logo and frame then
		logo.Position = defaultLogoPos
		frame.Position = defaultFramePos
		notify("🖼️ UI Position Reset")
	else
		notify("⚠️ UI not initialized", Color3.fromRGB(255, 100, 100))
	end
end

local function toggleHideNick()
	nickHidden = not nickHidden
	local success, errorMsg = pcall(function()
		if char and char:FindFirstChild("Head") then
			local head = char.Head
			local billboard = head:FindFirstChildOfClass("BillboardGui")
			if billboard then
				billboard.Enabled = not nickHidden
			end
			if humanoid then
				humanoid.NameDisplayDistance = nickHidden and 0 or 100
			end
			notify(nickHidden and "🙈 Nick Hidden" or "🙉 Nick Visible")
		else
			notify("⚠️ Head or BillboardGui not found", Color3.fromRGB(255, 100, 100))
		end
	end)
	if not success then
		notify("⚠️ Failed to toggle nick visibility: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
	end
end

local function toggleRandomNick()
	randomNick = not randomNick
	local success, errorMsg = pcall(function()
		if randomNick then
			local randomName = "User" .. math.random(1000, 9999)
			player.DisplayName = randomName
			if humanoid then
				humanoid.DisplayName = randomName
			end
			notify("🎲 Random Nick: " .. randomName)
		else
			player.DisplayName = player.Name
			if humanoid then
				humanoid.DisplayName = player.Name
			end
			notify("🎲 Nick Reset")
		end
	end)
	if not success then
		notify("⚠️ Failed to set random nick: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
	end
end

local function setCustomNick(nick)
	if nick == "" then
		notify("⚠️ Nick cannot be empty", Color3.fromRGB(255, 100, 100))
		return
	end
	local success, errorMsg = pcall(function()
		if #nick <= 32 then
			customNick = nick
			player.DisplayName = nick
			if humanoid then
				humanoid.DisplayName = nick
			end
			notify("✏️ Custom Nick: " .. nick)
		else
			notify("⚠️ Nick too long (max 32 chars)", Color3.fromRGB(255, 100, 100))
		end
	end)
	if not success then
		notify("⚠️ Failed to set custom nick: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
	end
end

local function setAvatar(target)
	if not target or not target:IsA("Player") then
		notify("⚠️ No valid player selected", Color3.fromRGB(255, 100, 100))
		return
	end
	local success, errorMsg = pcall(function()
		local desc = Players:GetHumanoidDescriptionFromUserId(target.UserId)
		if humanoid and desc then
			humanoid:ApplyDescription(desc)
			notify("🎭 Avatar set to " .. target.Name)
		else
			notify("⚠️ Failed to get avatar description", Color3.fromRGB(255, 100, 100))
		end
	end)
	if not success then
		notify("⚠️ Failed to set avatar: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
	end
end

local function resetAvatar()
	local success, errorMsg = pcall(function()
		if humanoid and originalHumanoidDescription then
			humanoid:ApplyDescription(originalHumanoidDescription)
			notify("🎭 Avatar Reset")
		else
			notify("⚠️ Original avatar not saved", Color3.fromRGB(255, 100, 100))
		end
	end)
	if not success then
		notify("⚠️ Failed to reset avatar: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
	end
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

local function startMacroRecording()
	if macroRecording then
		return
	end
	macroRecording = true
	macroActions = {}
	local startTime = tick()
	connections.macroRecord = RunService.RenderStepped:Connect(function()
		if hr and humanoid then
			table.insert(macroActions, {
				time = tick() - startTime,
				position = hr.Position,
				velocity = hr.Velocity,
				rotation = hr.CFrame - hr.CFrame.Position,
				state = humanoid:GetState()
			})
		end
	end)
	connections.macroInput = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if macroRecording and not gameProcessed then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				table.insert(macroActions, {
					time = tick() - startTime,
					inputType = "Keyboard",
					key = input.KeyCode,
					state = "Began"
				})
			end
		end
	end)
	connections.macroState = humanoid.StateChanged:Connect(function(oldState, newState)
		if macroRecording then
			table.insert(macroActions, {
				time = tick() - startTime,
				stateChange = newState
			})
		end
	end)
	notify("⏺️ Macro Recording Started")
end

local function toggleRecordMacro()
	if macroRecording then
		macroRecording = false
		if connections.macroRecord then
			connections.macroRecord:Disconnect()
			connections.macroRecord = nil
		end
		if connections.macroInput then
			connections.macroInput:Disconnect()
			connections.macroInput = nil
		end
		if connections.macroState then
			connections.macroState:Disconnect()
			connections.macroState = nil
		end
		notify("⏹️ Macro Recording Stopped")
	else
		startMacroRecording()
	end
end

local function stopRecordMacro()
	if macroRecording then
		macroRecording = false
		if connections.macroRecord then
			connections.macroRecord:Disconnect()
			connections.macroRecord = nil
		end
		if connections.macroInput then
			connections.macroInput:Disconnect()
			connections.macroInput = nil
		end
		if connections.macroState then
			connections.macroState:Disconnect()
			connections.macroState = nil
		end
		notify("⏹️ Macro Recording Stopped")
	else
		notify("⚠️ Not recording a macro", Color3.fromRGB(255, 100, 100))
	end
end

local function toggleRecordOnRespawn()
	recordOnRespawn = not recordOnRespawn
	if recordOnRespawn then
		connections.recordOnRespawn = player.CharacterAdded:Connect(function()
			if not macroRecording then
				startMacroRecording()
			end
		end)
		notify("🔄 Record on Respawn Enabled")
	else
		if connections.recordOnRespawn then
			connections.recordOnRespawn:Disconnect()
			connections.recordOnRespawn = nil
		end
		notify("🔄 Record on Respawn Disabled")
	end
end

local function togglePlayMacro()
	if macroPlaying then
		macroPlaying = false
		if connections.macroPlay then
			connections.macroPlay:Disconnect()
			connections.macroPlay = nil
		end
		if connections.macroNoclip then
			connections.macroNoclip:Disconnect()
			connections.macroNoclip = nil
		end
		if char then
			for _, part in pairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = true
				end
			end
		end
		resetCharacterState()
		notify("⏹️ Macro Playback Stopped")
	else
		if #macroActions == 0 then
			notify("⚠️ No macro recorded", Color3.fromRGB(255, 100, 100))
			return
		end
		if not hr or not humanoid or not char then
			notify("⚠️ Character not loaded", Color3.fromRGB(255, 100, 100))
			return
		end
		macroPlaying = true
		ensureCharacterVisible()
		connections.macroNoclip = RunService.Stepped:Connect(function()
			if char then
				for _, part in pairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
					end
				end
			end
		end)
		local startTime = tick()
		local index = 1
		local lastCFrame = hr.CFrame
		connections.macroPlay = RunService.RenderStepped:Connect(function()
			if index > #macroActions then
				macroPlaying = false
				connections.macroPlay:Disconnect()
				connections.macroPlay = nil
				if connections.macroNoclip then
					connections.macroNoclip:Disconnect()
					connections.macroNoclip = nil
				end
				if char then
					for _, part in pairs(char:GetDescendants()) do
						if part:IsA("BasePart") then
							part.CanCollide = true
						end
					end
				end
				resetCharacterState()
				notify("⏹️ Macro Playback Finished")
				return
			end
			local action = macroActions[index]
			if tick() - startTime >= action.time then
				if hr and humanoid and char then
					if action.position and action.velocity and action.rotation then
						local targetCFrame = CFrame.new(action.position) * action.rotation
						local tweenInfo = TweenInfo.new(0.05, Enum.EasingStyle.Linear)
						local tween = TweenService:Create(hr, tweenInfo, {CFrame = targetCFrame})
						tween:Play()
						hr.Velocity = action.velocity
						if action.state then
							humanoid:ChangeState(action.state)
						end
						ensureCharacterVisible()
					elseif action.inputType == "Keyboard" and action.state == "Began" then
						if action.key == Enum.KeyCode.Space then
							humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					elseif action.stateChange then
						humanoid:ChangeState(action.stateChange)
					end
				end
				index = index + 1
			end
		end)
		notify("▶️ Macro Playback Started")
	end
end

local function stopPlayMacro()
	if macroPlaying then
		macroPlaying = false
		if connections.macroPlay then
			connections.macroPlay:Disconnect()
			connections.macroPlay = nil
		end
		if connections.macroNoclip then
			connections.macroNoclip:Disconnect()
			connections.macroNoclip = nil
		end
		if char then
			for _, part in pairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = true
				end
			end
		end
		resetCharacterState()
		notify("⏹️ Macro Playback Stopped")
	else
		notify("⚠️ Not playing a macro", Color3.fromRGB(255, 100, 100))
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
		logo.Position = defaultLogoPos
		logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
		logo.BorderSizePixel = 0
		logo.Image = "rbxassetid://3570695787"
		logo.ZIndex = 10
		logo.Parent = gui
		print("Logo created")

		frame = Instance.new("Frame")
		frame.Size = isMobile and UDim2.new(0.8, 0, 0.6, 0) or UDim2.new(0, 600, 0, 400)
		frame.Position = defaultFramePos
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
			for _, child in pairs(parent:GetChildren()) do
				if child.Name:match("^Player_") then
					child:Destroy()
				end
			end
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
		createButton(movement, "Toggle Freecam", toggleFreecam)
		createButton(movement, "Return to Character", returnToCharacter)
		createButton(movement, "Cancel Freecam", cancelFreecam)
		createButton(movement, "Teleport Char to Cam", teleportCharacterToCamera)
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
		createButton(utility, "Save Position 2", function() savePosition(2) end)
		createButton(utility, "Load Position 1", function() loadPosition(1) end)
		createButton(utility, "Load Position 2", function() loadPosition(2) end)
		createButton(utility, "Teleport to Spawn", teleportToSpawn)
		createButton(utility, "Teleport to Player", function() teleportToPlayer(selectedPlayer) end)
		createButton(utility, "Toggle Follow Player", function() toggleFollowPlayer(selectedPlayer) end)
		createButton(utility, "Cancel Follow Player", cancelFollowPlayer)
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
		createButton(utility, "Reset UI Position", resetUIPosition)
		createButton(utility, "Toggle Record Macro", toggleRecordMacro)
		createButton(utility, "Stop Record Macro", stopRecordMacro)
		createButton(utility, "Toggle Play Macro", togglePlayMacro)
		createButton(utility, "Stop Play Macro", stopPlayMacro)
		createButton(utility, "Toggle Auto Play Macro", toggleAutoPlayMacro)
		createButton(utility, "Toggle Record on Respawn", toggleRecordOnRespawn)

		local misc = createCategory("Misc")
		createButton(misc, "Toggle Hide Nick", toggleHideNick)
		createButton(misc, "Toggle Random Nick", toggleRandomNick)
		createTextBox(misc, "Enter Custom Nick", setCustomNick)
		createButton(misc, "Set Avatar", function() setAvatar(selectedPlayer) end)
		createButton(misc, "Reset Avatar", resetAvatar)
		createButton(misc, "Toggle Anti Spectate", toggleAntiSpectate)
		createButton(misc, "Toggle Anti Report", toggleAntiReport)
		createButton(misc, "Toggle Trajectory", toggleTrajectory)
		createButton(misc, "Reset Character", resetCharacter)
		createButton(misc, "Clean Workspace", cleanWorkspace)
		createButton(misc, "Optimize Game", optimizeGame)

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
		
		player.CharacterAdded:Connect(function()
			clearConnections()
			if freecam then
				toggleFreecam()
				notify("📷 Freecam disabled due to respawn")
			end
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