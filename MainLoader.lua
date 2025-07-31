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
local defaultLogoPos = UDim2.new(0.95, -60, 0.05, 10)
local defaultFramePos = UDim2.new(0.5, -150, 0.5, -200)
local originalHumanoidDescription = nil

local flying, freecam, noclip, godMode, antiThirst, antiHunger = false, false, false, false, false, false
local flySpeed = 50
local freecamSpeed = 50
local rotationSensitivity = 0.1 -- Radian per pixel for camera rotation
local speedEnabled, jumpEnabled, waterWalk, rocket, spin = false, false, false, false, false
local moveSpeed = 50
local jumpPower = 100
local spinSpeed = 20
local savedPositions = { [1] = nil, [2] = nil }
local followTarget = nil
local connections = {}
local nickHidden, randomNick = false, false
local customNick = ""
local macroRecording, macroPlaying, autoPlayOnRespawn, recordOnRespawn = false, false, false, false
local macroActions = {}
local isMobile = UserInputService.TouchEnabled
local freecamCFrame = nil
local hrCFrame = nil
local moveTouchInput = nil
local rotateTouchInput = nil
local moveStartPos = nil
local rotateStartPos = nil
local moveDirection = Vector3.new(0, 0, 0)
local deltaRotation = Vector2.new(0, 0)

local function notify(message, color)
	local success, errorMsg = pcall(function()
		if not gui then
			print("Notify failed: GUI not initialized")
			return
		end
		local notif = Instance.new("TextLabel")
		notif.Size = UDim2.new(0, 250, 0, 40)
		notif.Position = UDim2.new(0.5, -125, 0.1, 0)
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
	local retries = 3
	local success, desc = false, nil
	for i = 1, retries do
		success, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		if success and desc then
			originalHumanoidDescription = desc
			print("Original avatar saved")
			return
		end
		task.wait(1)
	end
	notify("⚠️ Failed to save avatar after retries", Color3.fromRGB(255, 100, 100))
end

local function findStat(statName)
	local locations = { player, char, player.PlayerGui }
	for _, loc in pairs(locations) do
		if loc then
			for _, obj in pairs(loc:GetDescendants()) do
				if (obj:IsA("NumberValue") or obj:IsA("IntValue")) and obj.Name:lower():find(statName:lower()) then
					return obj
				end
			end
		end
	end
	return nil
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
		if godMode then toggleGodMode() toggleGodMode() end
		if antiThirst then toggleAntiThirst() toggleAntiThirst() end
		if antiHunger then toggleAntiHunger() toggleAntiHunger() end
		if nickHidden then toggleHideNick() toggleHideNick() end
		if randomNick then toggleRandomNick() toggleRandomNick() end
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

local function setupTouchInput()
	if connections.moveTouchBegan then connections.moveTouchBegan:Disconnect() end
	if connections.moveTouchMoved then connections.moveTouchMoved:Disconnect() end
	if connections.moveTouchEnded then connections.moveTouchEnded:Disconnect() end
	if connections.rotateTouchBegan then connections.rotateTouchBegan:Disconnect() end
	if connections.rotateTouchMoved then connections.rotateTouchMoved:Disconnect() end
	if connections.rotateTouchEnded then connections.rotateTouchEnded:Disconnect() end

	local touchCount = 0
	connections.moveTouchBegan = UserInputService.TouchStarted:Connect(function(input)
		if not UserInputService:GetFocusedTextBox() then
			touchCount = touchCount + 1
			if touchCount == 1 then
				moveTouchInput = input
				moveStartPos = input.Position
				moveDirection = Vector3.new(0, 0, 0)
			elseif touchCount == 2 then
				rotateTouchInput = input
				rotateStartPos = input.Position
				deltaRotation = Vector2.new(0, 0)
			end
		end
	end)
	connections.moveTouchMoved = UserInputService.TouchMoved:Connect(function(input)
		if input == moveTouchInput and not UserInputService:GetFocusedTextBox() then
			local delta = input.Position - moveStartPos
			local screenSize = camera.ViewportSize
			local x = math.clamp(delta.X / (screenSize.X * 0.3), -1, 1)
			local y = math.clamp(-delta.Y / (screenSize.Y * 0.3), -1, 1)
			moveDirection = Vector3.new(x, y, 0)
		elseif input == rotateTouchInput then
			local delta = input.Position - rotateStartPos
			deltaRotation = Vector2.new(delta.X * rotationSensitivity, delta.Y * rotationSensitivity)
			rotateStartPos = input.Position
		end
	end)
	connections.moveTouchEnded = UserInputService.TouchEnded:Connect(function(input)
		if input == moveTouchInput then
			moveTouchInput = nil
			moveStartPos = nil
			moveDirection = Vector3.new(0, 0, 0)
			touchCount = touchCount - 1
		elseif input == rotateTouchInput then
			rotateTouchInput = nil
			rotateStartPos = nil
			deltaRotation = Vector2.new(0, 0)
			touchCount = touchCount - 1
		end
	end)
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
			local forward = camera.CFrame.LookVector
			local right = camera.CFrame.RightVector
			local up = Vector3.new(0, 1, 0)
			local moveDir = moveDirection.X * right + moveDirection.Y * forward
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
	local success, errorMsg = pcall(function()
		if freecam then
			if flying then
				toggleFly()
				notify("🛫 Fly disabled to enable Freecam", Color3.fromRGB(255, 100, 100))
			end
			if not hr or not humanoid or not camera then
				freecam = false
				error("Character or camera not loaded")
			end
			hrCFrame = hr.CFrame
			freecamCFrame = camera.CFrame
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CameraSubject = nil
			local bv = Instance.new("BodyVelocity")
			bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			bv.Velocity = Vector3.new(0, 0, 0)
			bv.Parent = hr
			connections.freecamLock = RunService.Stepped:Connect(function()
				if hr and hrCFrame then
					hr.CFrame = hrCFrame
				else
					freecam = false
					connections.freecamLock:Disconnect()
					connections.freecamLock = nil
					notify("⚠️ Character lost, Freecam disabled", Color3.fromRGB(255, 100, 100))
				end
			end)
			connections.freecam = RunService.RenderStepped:Connect(function(dt)
				if not camera or not freecamCFrame then
					return
				end
				-- Handle rotation
				if deltaRotation.Magnitude > 0 then
					local yaw = -deltaRotation.X
					local pitch = -deltaRotation.Y
					freecamCFrame = freecamCFrame * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
					print("Freecam Rotation: Yaw=" .. yaw .. ", Pitch=" .. pitch)
				end
				-- Handle movement
				local forward = freecamCFrame.LookVector
				local right = freecamCFrame.RightVector
				local up = Vector3.new(0, 1, 0)
				local moveDir = moveDirection.X * right + moveDirection.Y * forward
				if moveDir.Magnitude > 0 then
					moveDir = moveDir.Unit * freecamSpeed * dt
					freecamCFrame = freecamCFrame + moveDir
				end
				camera.CFrame = freecamCFrame
				print("Freecam: CameraType=" .. tostring(camera.CameraType) .. ", Pos=" .. tostring(freecamCFrame.Position) .. ", CharPos=" .. tostring(hr and hr.CFrame.Position or "nil"))
			end)
			notify("📷 Freecam Enabled (Swipe to rotate)")
		else
			if connections.freecam then
				connections.freecam:Disconnect()
				connections.freecam = nil
			end
			if connections.freecamLock then
				connections.freecamLock:Disconnect()
				connections.freecamLock = nil
			end
			if hr and hr:FindFirstChildOfClass("BodyVelocity") then
				hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
			end
			if camera and humanoid then
				camera.CameraType = Enum.CameraType.Custom
				camera.CameraSubject = humanoid
				if hr then
					camera.CFrame = CFrame.new(hr.CFrame.Position + Vector3.new(0, 5, 10), hr.CFrame.Position)
				end
			end
			freecamCFrame = nil
			hrCFrame = nil
			notify("📷 Freecam Disabled")
		end
	end)
	if not success then
		freecam = false
		if connections.freecam then
			connections.freecam:Disconnect()
			connections.freecam = nil
		end
		if connections.freecamLock then
			connections.freecamLock:Disconnect()
			connections.freecamLock = nil
		end
		if hr and hr:FindFirstChildOfClass("BodyVelocity") then
			hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
		end
		notify("⚠️ Freecam error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
	end
end

local function returnToCharacter()
	if freecam and hr and humanoid then
		freecamCFrame = CFrame.new(hr.CFrame.Position + Vector3.new(0, 5, 10), hr.CFrame.Position)
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
		hrCFrame = CFrame.new(freecamCFrame.Position + Vector3.new(0, 3, 0))
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
		local tween = TweenService:Create(hr, tweenInfo, {CFrame = hrCFrame})
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

local function toggleGodMode()
	godMode = not godMode
	local success, errorMsg = pcall(function()
		if godMode then
			if humanoid then
				humanoid.MaxHealth = math.huge
				humanoid.Health = math.huge
				connections.godModeHealth = RunService.RenderStepped:Connect(function()
					if humanoid then
						humanoid.Health = math.huge
					end
				end)
				connections.godModeState = humanoid.StateChanged:Connect(function(_, new)
					if new == Enum.HumanoidStateType.FallingDown or new == Enum.HumanoidStateType.Ragdoll then
						humanoid:ChangeState(Enum.HumanoidStateType.Running)
					end
				end)
				connections.godModeDamage = humanoid.HealthChanged:Connect(function(health)
					if health < math.huge then
						humanoid.Health = math.huge
					end
				end)
				notify("🛡️ God Mode Enabled (Health, No Fall, Anti Ragdoll)")
			else
				notify("⚠️ Humanoid not found", Color3.fromRGB(255, 100, 100))
				godMode = false
			end
		else
			if connections.godModeHealth then
				connections.godModeHealth:Disconnect()
				connections.godModeHealth = nil
			end
			if connections.godModeState then
				connections.godModeState:Disconnect()
				connections.godModeState = nil
			end
			if connections.godModeDamage then
				connections.godModeDamage:Disconnect()
				connections.godModeDamage = nil
			end
			if humanoid then
				humanoid.MaxHealth = 100
				humanoid.Health = 100
			end
			notify("🛡️ God Mode Disabled")
		end
	end)
	if not success then
		godMode = false
		notify("⚠️ God Mode error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
	end
end

local function toggleAntiThirst()
	antiThirst = not antiThirst
	local success, errorMsg = pcall(function()
		if antiThirst then
			local thirstStat = findStat("Thirst")
			if thirstStat then
				local maxValue = thirstStat.Value >= 100 and thirstStat.Value or 100
				connections.antiThirst = RunService.RenderStepped:Connect(function()
					if thirstStat and thirstStat.Parent then
						thirstStat.Value = maxValue
					else
						antiThirst = false
						connections.antiThirst:Disconnect()
						connections.antiThirst = nil
						notify("⚠️ Thirst stat lost", Color3.fromRGB(255, 100, 100))
					end
				end)
				notify("💧 Anti Thirst Enabled")
			else
				antiThirst = false
				notify("⚠️ Thirst stat not found", Color3.fromRGB(255, 100, 100))
			end
		else
			if connections.antiThirst then
				connections.antiThirst:Disconnect()
				connections.antiThirst = nil
			end
			notify("💧 Anti Thirst Disabled")
		end
	end)
	if not success then
		antiThirst = false
		notify("⚠️ Anti Thirst error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
	end
end

local function toggleAntiHunger()
	antiHunger = not antiHunger
	local success, errorMsg = pcall(function()
		if antiHunger then
			local hungerStat = findStat("Hunger")
			if hungerStat then
				local maxValue = hungerStat.Value >= 100 and hungerStat.Value or 100
				connections.antiHunger = RunService.RenderStepped:Connect(function()
					if hungerStat and hungerStat.Parent then
						hungerStat.Value = maxValue
					else
						antiHunger = false
						connections.antiHunger:Disconnect()
						connections.antiHunger = nil
						notify("⚠️ Hunger stat lost", Color3.fromRGB(255, 100, 100))
					end
				end)
				notify("🍽️ Anti Hunger Enabled")
			else
				antiHunger = false
				notify("⚠️ Hunger stat not found", Color3.fromRGB(255, 100, 100))
			end
		else
			if connections.antiHunger then
				connections.antiHunger:Disconnect()
				connections.antiHunger = nil
			end
			notify("🍽️ Anti Hunger Disabled")
		end
	end)
	if not success then
		antiHunger = false
		notify("⚠️ Anti Hunger error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
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
				humanoid.DisplayDistanceType = nickHidden and Enum.HumanoidDisplayDistanceType.None or Enum.HumanoidDisplayDistanceType.Viewer
			end
			notify(nickHidden and "🙈 Nick Hidden" or "🙉 Nick Visible")
		else
			nickHidden = false
			notify("⚠️ Head or BillboardGui not found", Color3.fromRGB(255, 100, 100))
		end
	end)
	if not success then
		nickHidden = false
		notify("⚠️ Failed to toggle nick visibility: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
	end
end

local function toggleRandomNick()
	randomNick = not randomNick
	local success, errorMsg = pcall(function()
		if randomNick then
			local randomName = "User" .. math.random(1000, 9999)
			if humanoid then
				humanoid.DisplayName = randomName
			end
			notify("🎲 Random Nick: " .. randomName)
		else
			if humanoid then
				humanoid.DisplayName = player.Name
			end
			notify("🎲 Nick Reset")
		end
	end)
	if not success then
		randomNick = false
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
	notify("⏺️ Macro Recording Started")
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
		logo.Size = UDim2.new(0, 60, 0, 60)
		logo.Position = defaultLogoPos
		logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
		logo.BorderSizePixel = 0
		logo.Image = "rbxassetid://3570695787"
		logo.ZIndex = 10
		logo.Parent = gui
		print("Logo created")

		frame = Instance.new("Frame")
		frame.Size = UDim2.new(0.5, 0, 0.6, 0)
		frame.Position = defaultFramePos
		frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		frame.BackgroundTransparency = 0.1
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.ZIndex = 10
		local uil = Instance.new("UIListLayout")
		uil.FillDirection = Enum.FillDirection.Vertical
		uil.Padding = UDim.new(0, 10)
		uil.Parent = frame
		frame.Parent = gui
		print("Frame created")

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 50)
		title.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
		title.TextColor3 = Color3.new(1, 1, 1)
		title.Text = "Krnl UI (Mobile)"
		title.TextScaled = true
		title.Font = Enum.Font.Gotham
		title.ZIndex = 10
		title.Parent = frame
		print("Title created")

		local closeBtn = Instance.new("TextButton")
		closeBtn.Size = UDim2.new(0, 40, 0, 40)
		closeBtn.Position = UDim2.new(1, -45, 0, 5)
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

		local tabFrame = Instance.new("Frame")
		tabFrame.Size = UDim2.new(1, 0, 0, 40)
		tabFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		tabFrame.BackgroundTransparency = 0.2
		tabFrame.ZIndex = 10
		local tabList = Instance.new("UIListLayout")
		tabList.FillDirection = Enum.FillDirection.Horizontal
		tabList.Padding = UDim.new(0, 5)
		tabList.Parent = tabFrame
		tabFrame.Parent = frame

		local categories = {}
		local function createCategory(name)
			local catFrame = Instance.new("ScrollingFrame")
			catFrame.Size = UDim2.new(1, 0, 1, -95)
			catFrame.Position = UDim2.new(0, 0, 0, 95)
			catFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			catFrame.BackgroundTransparency = 0.2
			catFrame.BorderSizePixel = 0
			catFrame.ZIndex = 10
			catFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
			catFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
			catFrame.ScrollBarThickness = 8
			catFrame.Visible = false
			catFrame.Parent = frame
			local catList = Instance.new("UIListLayout")
			catList.Padding = UDim.new(0, 10)
			catList.Parent = catFrame
			local catPadding = Instance.new("UIPadding")
			catPadding.PaddingLeft = UDim.new(0, 10)
			catPadding.PaddingTop = UDim.new(0, 10)
			catPadding.Parent = catFrame
			categories[name] = catFrame
			return catFrame
		end

		local function createTabButton(name, catFrame)
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0.25, -5, 0, 40)
			btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			btn.TextColor3 = Color3.new(1, 1, 1)
			btn.Text = name
			btn.TextScaled = true
			btn.Font = Enum.Font.Gotham
			btn.BorderSizePixel = 0
			btn.ZIndex = 10
			btn.Parent = tabFrame
			btn.Activated:Connect(function()
				for _, cat in pairs(categories) do
					cat.Visible = false
				end
				catFrame.Visible = true
				notify("📑 Switched to " .. name)
			end)
		end

		local function createButton(parent, text, callback)
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, -10, 0, 50)
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
			box.Size = UDim2.new(1, -10, 0, 50)
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
			local yOffset = 10
			for _, p in pairs(Players:GetPlayers()) do
				if p ~= player then
					local btn = Instance.new("TextButton")
					btn.Name = "Player_" .. p.Name
					btn.Size = UDim2.new(1, -10, 0, 50)
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
					yOffset = yOffset + 55
				end
			end
			parent.CanvasSize = UDim2.new(0, 0, 0, yOffset)
		end

		local movement = createCategory("Movement")
		createTabButton("Movement", movement)
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
		createTabButton("Utility", utility)
		createButton(utility, "Toggle God Mode", toggleGodMode)
		createButton(utility, "Toggle Anti Thirst", toggleAntiThirst)
		createButton(utility, "Toggle Anti Hunger", toggleAntiHunger)
		createButton(utility, "Save Position 1", function() savePosition(1) end)
		createButton(utility, "Save Position 2", function() savePosition(2) end)
		createButton(utility, "Load Position 1", function() loadPosition(1) end)
		createButton(utility, "Load Position 2", function() loadPosition(2) end)
		createButton(utility, "Teleport to Spawn", teleportToSpawn)
		createButton(utility, "Teleport to Player", function() teleportToPlayer(selectedPlayer) end)
		createButton(utility, "Toggle Follow Player", function() toggleFollowPlayer(selectedPlayer) end)
		createButton(utility, "Cancel Follow Player", cancelFollowPlayer)
		createButton(utility, "Pull Player to Me", function() pullPlayerToMe(selectedPlayer) end)
		createButton(utility, "Reset UI Position", resetUIPosition)
		createButton(utility, "Toggle Record Macro", toggleRecordMacro)
		createButton(utility, "Stop Record Macro", stopRecordMacro)
		createButton(utility, "Toggle Play Macro", togglePlayMacro)
		createButton(utility, "Stop Play Macro", stopPlayMacro)
		createButton(utility, "Toggle Auto Play Macro", toggleAutoPlayMacro)
		createButton(utility, "Toggle Record on Respawn", toggleRecordOnRespawn)

		local misc = createCategory("Misc")
		createTabButton("Misc", misc)
		createButton(misc, "Toggle Hide Nick", toggleHideNick)
		createButton(misc, "Toggle Random Nick", toggleRandomNick)
		createTextBox(misc, "Enter Custom Nick", setCustomNick)
		createButton(misc, "Set Avatar", function() setAvatar(selectedPlayer) end)
		createButton(misc, "Reset Avatar", resetAvatar)
		createButton(misc, "Reset Character", resetCharacter)

		local playerSelect = createCategory("Player Select")
		createTabButton("Player Select", playerSelect)
		updatePlayerList(playerSelect)
		Players.PlayerAdded:Connect(function() updatePlayerList(playerSelect) end)
		Players.PlayerRemoving:Connect(function(p)
			if selectedPlayer == p then
				selectedPlayer = nil
			end
			updatePlayerList(playerSelect)
		end)

		-- Show Movement tab by default
		categories["Movement"].Visible = true
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
		if input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = element.Position
		end
	end)
	element.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch and dragging then
			local delta = input.Position - dragStart
			element.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
	element.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
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
		setupTouchInput()
		
		player.CharacterAdded:Connect(function()
			clearConnections()
			if freecam then
				toggleFreecam()
				notify("📷 Freecam disabled due to respawn")
			end
			initChar()
			setupTouchInput()
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