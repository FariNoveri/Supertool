local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local humanoid, hr, char
local gui, frame, logo, joystickFrame
local selectedPlayer = nil
local spectatingPlayer = nil
local carriedPlayer = nil
local defaultLogoPos = UDim2.new(0.95, -60, 0.05, 10)
local defaultFramePos = UDim2.new(0.5, -150, 0.5, -200)
local flying, freecam, noclip, godMode = false, false, false, false
local flySpeed = 50
local freecamSpeed = 30
local rotationSensitivity = 0.015
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
local macroSuccessfulRun = nil
local isMobile = UserInputService.TouchEnabled
local freecamCFrame = nil
local hrCFrame = nil
local joystickTouch = nil
local joystickRadius = 50
local moveDirection = Vector3.new(0, 0, 0)
local mouseDelta = Vector2.new(0, 0)

-- Cleanup old script instance
local function cleanupOldInstance()
	local oldGui = player.PlayerGui:FindFirstChild("SimpleUILibrary_Krnl")
	if oldGui then
		oldGui:Destroy()
		notify("🛠️ Old script instance terminated", Color3.fromRGB(255, 255, 0))
	end
end

-- Notify function with error handling
local function notify(message, color)
	local success, errorMsg = pcall(function()
		if not gui then
			print("Notify: " .. message)
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

-- Clear all connections
local function clearConnections()
	for key, connection in pairs(connections) do
		if connection then
			connection:Disconnect()
			connections[key] = nil
		end
	end
end

-- Validate position
local function isValidPosition(pos)
	return pos and not (pos.Y < -1000 or pos.Y > 10000 or math.abs(pos.X) > 10000 or math.abs(pos.Z) > 10000)
end

-- Ensure character visibility
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

-- Clean adornments
local function cleanAdornments(character)
	local success, errorMsg = pcall(function()
		for _, obj in pairs(character:GetDescendants()) do
			if obj:IsA("SelectionBox") or obj:IsA("BoxHandleAdornment") or obj:IsA("SurfaceGui") then
				obj:Destroy()
			end
		end
	end)
	if not success then
		print("cleanAdornments error: " .. tostring(errorMsg))
	end
end

-- Reset character state
local function resetCharacterState()
	if hr and humanoid then
		hr.Velocity = Vector3.new(0, 0, 0)
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
		humanoid.Health = humanoid.MaxHealth
		ensureCharacterVisible()
		cleanAdornments(char)
	end
end

-- Find stat
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

-- Initialize character
local function initChar()
	local success, errorMsg = pcall(function()
		while not player.Character do
			notify("⏳ Waiting for character to spawn...", Color3.fromRGB(255, 255, 0))
			player.CharacterAdded:Wait()
			task.wait(1)
		end
		char = player.Character
		humanoid = char:WaitForChild("Humanoid", 20)
		hr = char:WaitForChild("HumanoidRootPart", 20)
		if not humanoid or not hr then
			error("Failed to find Humanoid or HumanoidRootPart after 20s")
		end
		cleanAdornments(char)
		ensureCharacterVisible()
		-- Reapply states after respawn
		if flying then toggleFly() toggleFly() end
		if freecam then toggleFreecam() toggleFreecam() end
		if noclip then toggleNoclip() toggleNoclip() end
		if speedEnabled then toggleSpeed() toggleSpeed() end
		if jumpEnabled then toggleJump() toggleJump() end
		if waterWalk then toggleWaterWalk() toggleWaterWalk() end
		if spin then toggleSpin() toggleSpin() end
		if godMode then toggleGodMode() toggleGodMode() end
		if nickHidden then toggleHideNick() toggleHideNick() end
		if randomNick then toggleRandomNick() toggleRandomNick() end
		if recordOnRespawn and macroRecording then toggleRecordMacro() toggleRecordMacro() end
		if autoPlayOnRespawn and macroPlaying then togglePlayMacro() togglePlayMacro() end
	end)
	if not success then
		print("initChar error: " .. tostring(errorMsg))
		notify("⚠️ Character init failed: " .. tostring(errorMsg) .. ", retrying...", Color3.fromRGB(255, 100, 100))
		task.wait(5)
		initChar()
	end
end

-- Create joystick for mobile
local function createJoystick()
	if joystickFrame then
		joystickFrame:Destroy()
	end
	joystickFrame = Instance.new("Frame")
	joystickFrame.Size = UDim2.new(0, 100, 0, 100)
	joystickFrame.Position = UDim2.new(0.1, 0, 0.7, 0)
	joystickFrame.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	joystickFrame.BackgroundTransparency = 0.5
	joystickFrame.BorderSizePixel = 0
	joystickFrame.ZIndex = 15
	joystickFrame.Visible = false
	joystickFrame.Parent = gui

	local joystickKnob = Instance.new("Frame")
	joystickKnob.Size = UDim2.new(0, 40, 0, 40)
	joystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
	joystickKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	joystickKnob.BackgroundTransparency = 0.2
	joystickKnob.BorderSizePixel = 0
	joystickKnob.ZIndex = 16
	joystickKnob.Parent = joystickFrame

	local function updateJoystick(input)
		local center = Vector2.new(joystickFrame.AbsolutePosition.X + joystickFrame.AbsoluteSize.X / 2, joystickFrame.AbsolutePosition.Y + joystickFrame.AbsoluteSize.Y / 2)
		local delta = Vector2.new(input.Position.X, input.Position.Y) - center
		local magnitude = delta.Magnitude
		local maxRadius = joystickRadius
		if magnitude > maxRadius then
			delta = delta.Unit * maxRadius
		end
		joystickKnob.Position = UDim2.new(0.5, delta.X - 20, 0.5, delta.Y - 20)
		moveDirection = Vector3.new(delta.X / maxRadius, 0, -delta.Y / maxRadius)
	end

	connections.joystickBegan = UserInputService.TouchStarted:Connect(function(input)
		if not UserInputService:GetFocusedTextBox() and (flying or freecam) then
			local touchPos = Vector2.new(input.Position.X, input.Position.Y)
			local joystickPos = Vector2.new(joystickFrame.AbsolutePosition.X + joystickFrame.AbsoluteSize.X / 2, joystickFrame.AbsolutePosition.Y + joystickFrame.AbsoluteSize.Y / 2)
			if (touchPos - joystickPos).Magnitude <= joystickRadius * 2 then
				joystickTouch = input
				updateJoystick(input)
			end
		end
	end)

	connections.joystickMoved = UserInputService.TouchMoved:Connect(function(input)
		if input == joystickTouch then
			updateJoystick(input)
		end
	end)

	connections.joystickEnded = UserInputService.TouchEnded:Connect(function(input)
		if input == joystickTouch then
			joystickTouch = nil
			joystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
			moveDirection = Vector3.new(0, 0, 0)
		end
	end)
end

-- Fly toggle
local function toggleFly()
	flying = not flying
	local success, errorMsg = pcall(function()
		if flying then
			if freecam then
				toggleFreecam()
				notify("📷 Freecam disabled to enable Fly", Color3.fromRGB(255, 100, 100))
			end
			if not hr or not humanoid or not camera then
				flying = false
				error("Character or camera not loaded")
			end
			joystickFrame.Visible = isMobile
			local bv = Instance.new("BodyVelocity")
			bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			bv.Velocity = Vector3.new(0, 0, 0)
			bv.Parent = hr
			connections.fly = RunService.RenderStepped:Connect(function()
				if not hr or not humanoid or not camera then
					flying = false
					connections.fly:Disconnect()
					connections.fly = nil
					joystickFrame.Visible = false
					notify("⚠️ Fly failed: Character or camera lost", Color3.fromRGB(255, 100, 100))
					return
				end
				local forward = camera.CFrame.LookVector
				local right = camera.CFrame.RightVector
				local up = Vector3.new(0, 1, 0)
				local moveDir = Vector3.new(0, 0, 0)
				if isMobile then
					moveDir = moveDirection.X * right + moveDirection.Z * forward
				else
					if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + forward end
					if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - forward end
					if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - right end
					if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + right end
					if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + up end
					if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir = moveDir - up end
				end
				if moveDir.Magnitude > 0 then
					moveDir = moveDir.Unit * flySpeed
				end
				bv.Velocity = moveDir
				hr.CFrame = CFrame.new(hr.Position) * camera.CFrame.Rotation
			end)
			notify("🛫 Fly Enabled" .. (isMobile and " (Joystick)" or " (WASD, Space, Shift)"))
		else
			if connections.fly then
				connections.fly:Disconnect()
				connections.fly = nil
			end
			if hr and hr:FindFirstChildOfClass("BodyVelocity") then
				hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
			end
			joystickFrame.Visible = false
			notify("🛬 Fly Disabled")
		end
	end)
	if not success then
		flying = false
		if connections.fly then
			connections.fly:Disconnect()
			connections.fly = nil
		end
		if hr and hr:FindFirstChildOfClass("BodyVelocity") then
			hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
		end
		joystickFrame.Visible = false
		notify("⚠️ Fly error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
	end
end

-- Freecam toggle
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
			joystickFrame.Visible = isMobile
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
					joystickFrame.Visible = false
					notify("⚠️ Character lost, Freecam disabled", Color3.fromRGB(255, 100, 100))
				end
			end)
			connections.freecamMouse = UserInputService.InputChanged:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement then
					mouseDelta = Vector2.new(input.Delta.X, input.Delta.Y)
				end
			end)
			connections.freecam = RunService.RenderStepped:Connect(function()
				if not camera or not freecamCFrame then
					return
				end
				local forward = freecamCFrame.LookVector
				local right = freecamCFrame.RightVector
				local up = Vector3.new(0, 1, 0)
				local moveDir = Vector3.new(0, 0, 0)
				if isMobile then
					moveDir = moveDirection.X * right + moveDirection.Z * forward
				else
					if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + forward end
					if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - forward end
					if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - right end
					if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + right end
					if UserInputService:IsKeyDown(Enum.KeyCode.E) then moveDir = moveDir + up end
					if UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveDir = moveDir - up end
				end
				if moveDir.Magnitude > 0 then
					moveDir = moveDir * freecamSpeed
					freecamCFrame = CFrame.new(freecamCFrame.Position + moveDir) * freecamCFrame.Rotation
				end
				if not isMobile then
					local rotation = CFrame.Angles(0, -mouseDelta.X * rotationSensitivity, 0) * CFrame.Angles(-mouseDelta.Y * rotationSensitivity, 0, 0)
					freecamCFrame = CFrame.new(freecamCFrame.Position) * (freecamCFrame.Rotation * rotation)
					mouseDelta = Vector2.new(0, 0)
				end
				camera.CFrame = freecamCFrame
			end)
			notify("📷 Freecam Enabled" .. (isMobile and " (Joystick)" or " (WASD, QE, Mouse)"))
		else
			if connections.freecam then
				connections.freecam:Disconnect()
				connections.freecam = nil
			end
			if connections.freecamLock then
				connections.freecamLock:Disconnect()
				connections.freecamLock = nil
			end
			if connections.freecamMouse then
				connections.freecamMouse:Disconnect()
				connections.freecamMouse = nil
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
			joystickFrame.Visible = false
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
		if connections.freecamMouse then
			connections.freecamMouse:Disconnect()
			connections.freecamMouse = nil
		end
		if hr and hr:FindFirstChildOfClass("BodyVelocity") then
			hr:FindFirstChildOfClass("BodyVelocity"):Destroy()
		end
		joystickFrame.Visible = false
		notify("⚠️ Freecam error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
	end
end

-- Freecam utilities
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

-- Spectate
local function toggleSpectate(target)
	if spectatingPlayer == target then
		spectatingPlayer = nil
		if connections.spectate then
			connections.spectate:Disconnect()
			connections.spectate = nil
		end
		if camera and humanoid then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
			if hr then
				camera.CFrame = CFrame.new(hr.CFrame.Position + Vector3.new(0, 5, 10), hr.CFrame.Position)
			end
		end
		notify("👁️ Stopped Spectating")
		return
	end
	if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
		spectatingPlayer = target
		camera.CameraType = Enum.CameraType.Scriptable
		connections.spectate = RunService.RenderStepped:Connect(function()
			if spectatingPlayer and spectatingPlayer.Character and spectatingPlayer.Character:FindFirstChild("HumanoidRootPart") then
				local targetPos = spectatingPlayer.Character.HumanoidRootPart.Position
				if isValidPosition(targetPos) then
					camera.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 10), targetPos)
				else
					spectatingPlayer = nil
					connections.spectate:Disconnect()
					connections.spectate = nil
					if camera and humanoid then
						camera.CameraType = Enum.CameraType.Custom
						camera.CameraSubject = humanoid
						if hr then
							camera.CFrame = CFrame.new(hr.CFrame.Position + Vector3.new(0, 5, 10), hr.CFrame.Position)
						end
					end
					notify("⚠️ Invalid spectate target position", Color3.fromRGB(255, 100, 100))
				end
			else
				spectatingPlayer = nil
				connections.spectate:Disconnect()
				connections.spectate = nil
				if camera and humanoid then
					camera.CameraType = Enum.CameraType.Custom
					camera.CameraSubject = humanoid
					if hr then
						camera.CFrame = CFrame.new(hr.CFrame.Position + Vector3.new(0, 5, 10), hr.CFrame.Position)
					end
				end
				notify("⚠️ Spectate target lost", Color3.fromRGB(255, 100, 100))
			end
		end)
		notify("👁️ Spectating " .. target.Name)
	else
		notify("⚠️ No valid player selected", Color3.fromRGB(255, 100, 100))
	end
end

local function teleportToSpectated()
	if spectatingPlayer and spectatingPlayer.Character and spectatingPlayer.Character:FindFirstChild("HumanoidRootPart") and hr then
		local targetPos = spectatingPlayer.Character.HumanoidRootPart.Position
		if isValidPosition(targetPos) then
			local targetCFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
			local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
			local tween = TweenService:Create(hr, tweenInfo, {CFrame = targetCFrame})
			tween:Play()
			tween.Completed:Connect(function()
				notify("👤 Teleported to Spectated Player")
			end)
		else
			notify("⚠️ Invalid spectate target position", Color3.fromRGB(255, 100, 100))
		end
	else
		notify("⚠️ No player being spectated", Color3.fromRGB(255, 100, 100))
	end
end

local function cancelSpectate()
	if spectatingPlayer then
		spectatingPlayer = nil
		if connections.spectate then
			connections.spectate:Disconnect()
			connections.spectate = nil
		end
		if camera and humanoid then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
			if hr then
				camera.CFrame = CFrame.new(hr.CFrame.Position + Vector3.new(0, 5, 10), hr.CFrame.Position)
			end
		end
		notify("👁️ Spectate Canceled")
	else
		notify("⚠️ Not spectating anyone", Color3.fromRGB(255, 100, 100))
	end
end

-- Carry player
local function carryPlayer(target)
	if carriedPlayer then
		stopCarryPlayer()
	end
	if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and hr then
		carriedPlayer = target
		connections.carry = RunService.RenderStepped:Connect(function()
			if carriedPlayer and carriedPlayer.Character and carriedPlayer.Character:FindFirstChild("HumanoidRootPart") and hr then
				local targetHR = carriedPlayer.Character.HumanoidRootPart
				local targetPos = hr.Position + Vector3.new(0, 3, 0)
				if isValidPosition(targetPos) then
					local wasCollidable = {}
					for _, part in pairs(carriedPlayer.Character:GetDescendants()) do
						if part:IsA("BasePart") then
							wasCollidable[part] = part.CanCollide
							part.CanCollide = false
						end
					end
					targetHR.CFrame = CFrame.new(targetPos)
					task.spawn(function()
						task.wait(0.1)
						for _, part in pairs(carriedPlayer.Character:GetDescendants()) do
							if part:IsA("BasePart") and wasCollidable[part] ~= nil then
								part.CanCollide = wasCollidable[part]
							end
						end
					end)
				else
					stopCarryPlayer()
					notify("⚠️ Invalid carry position", Color3.fromRGB(255, 100, 100))
				end
			else
				stopCarryPlayer()
				notify("⚠️ Carry target lost", Color3.fromRGB(255, 100, 100))
			end
		end)
		notify("🏋️ Carrying " .. target.Name)
	else
		notify("⚠️ No valid player selected", Color3.fromRGB(255, 100, 100))
	end
end

local function stopCarryPlayer()
	if carriedPlayer then
		carriedPlayer = nil
		if connections.carry then
			connections.carry:Disconnect()
			connections.carry = nil
		end
		notify("🏋️ Stopped Carrying")
	else
		notify("⚠️ Not carrying anyone", Color3.fromRGB(255, 100, 100))
	end
end

-- Noclip
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

-- Speed
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

-- Jump
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

-- Water walk
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

-- Rocket
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

-- Spin
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

-- God mode with anti-thirst and anti-hunger
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
				local thirstStat = findStat("Thirst")
				local hungerStat = findStat("Hunger")
				if thirstStat then
					local maxThirst = thirstStat.Value >= 100 and thirstStat.Value or 100
					connections.antiThirst = RunService.RenderStepped:Connect(function()
						if thirstStat and thirstStat.Parent then
							thirstStat.Value = maxThirst
						end
					end)
				end
				if hungerStat then
					local maxHunger = hungerStat.Value >= 100 and hungerStat.Value or 100
					connections.antiHunger = RunService.RenderStepped:Connect(function()
						if hungerStat and hungerStat.Parent then
							hungerStat.Value = maxHunger
						end
					end)
				end
				local statMsg = ""
				if thirstStat and hungerStat then
					statMsg = " (Anti-Thirst, Anti-Hunger)"
				elseif thirstStat then
					statMsg = " (Anti-Thirst)"
				elseif hungerStat then
					statMsg = " (Anti-Hunger)"
				end
				notify("🛡️ God Mode Enabled" .. statMsg)
			else
				godMode = false
				notify("⚠️ Humanoid not found", Color3.fromRGB(255, 100, 100))
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
			if connections.antiThirst then
				connections.antiThirst:Disconnect()
				connections.antiThirst = nil
			end
			if connections.antiHunger then
				connections.antiHunger:Disconnect()
				connections.antiHunger = nil
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
		for _, key in pairs({"godModeHealth", "godModeState", "godModeDamage", "antiThirst", "antiHunger"}) do
			if connections[key] then
				connections[key]:Disconnect()
				connections[key] = nil
			end
		end
		if humanoid then
			humanoid.MaxHealth = 100
			humanoid.Health = 100
		end
		notify("⚠️ God Mode error: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
	end
end

-- Save and load positions
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

-- Teleport to player
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

-- Teleport to spawn
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

-- Follow player
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

-- Pull player to me
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

-- Reset UI position
local function resetUIPosition()
	if logo and frame then
		logo.Position = defaultLogoPos
		frame.Position = defaultFramePos
		notify("🖼️ UI Position Reset")
	else
		notify("⚠️ UI not initialized", Color3.fromRGB(255, 100, 100))
	end
end

-- Find text label in billboard
local function findTextLabel(billboard)
	for _, child in pairs(billboard:GetChildren()) do
		if child:IsA("TextLabel") then
			return child
		end
	end
	return nil
end

-- Hide nickname
local function toggleHideNick()
	nickHidden = not nickHidden
	local success, errorMsg = pcall(function()
		if char and char:FindFirstChild("Head") and humanoid then
			local head = char.Head
			local billboard = head:FindFirstChild("Nametag") or head:FindFirstChildOfClass("BillboardGui")
			if billboard then
				billboard.Enabled = not nickHidden
			end
			humanoid.NameDisplayDistance = nickHidden and 0 or 100
			humanoid.DisplayDistanceType = nickHidden and Enum.HumanoidDisplayDistanceType.None or Enum.HumanoidDisplayDistanceType.Viewer
		end
		if nickHidden then
			connections.hideNickNew = player.CharacterAdded:Connect(function(newChar)
				task.wait(1)
				char = newChar
				humanoid = char:WaitForChild("Humanoid", 10)
				local head = char:WaitForChild("Head", 10)
				if head and humanoid then
					local billboard = head:FindFirstChild("Nametag") or head:FindFirstChildOfClass("BillboardGui")
					if billboard then
						billboard.Enabled = false
					end
					humanoid.NameDisplayDistance = 0
					humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				end
			end)
			notify("🙈 Your Nick Hidden from Others")
		else
			if connections.hideNickNew then
				connections.hideNickNew:Disconnect()
				connections.hideNickNew = nil
			end
			notify("🙉 Your Nick Visible to Others")
		end
	end)
	if not success then
		nickHidden = false
		if connections.hideNickNew then
			connections.hideNickNew:Disconnect()
			connections.hideNickNew = nil
		end
		notify("⚠️ Failed to toggle your nick visibility: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
	end
end

-- Random nickname
local function toggleRandomNick()
	randomNick = not randomNick
	local success, errorMsg = pcall(function()
		if randomNick then
			local randomName = "User" .. math.random(1000, 9999)
			customNick = randomName
			if char and char:FindFirstChild("Head") then
				local head = char.Head
				local billboard = head:FindFirstChild("Nametag") or head:FindFirstChildOfClass("BillboardGui")
				if billboard then
					local textLabel = findTextLabel(billboard)
					if textLabel then
						textLabel.Text = nickHidden and "" or randomName
					end
				end
			end
			if humanoid then
				humanoid.DisplayName = nickHidden and "" or randomName
			end
			notify("🎲 Random Nick: " .. randomName)
		else
			customNick = ""
			if char and char:FindFirstChild("Head") then
				local head = char.Head
				local billboard = head:FindFirstChild("Nametag") or head:FindFirstChildOfClass("BillboardGui")
				if billboard then
					local textLabel = findTextLabel(billboard)
					if textLabel then
						textLabel.Text = nickHidden and "" or player.Name
					end
				end
			end
			if humanoid then
				humanoid.DisplayName = nickHidden and "" or player.Name
			end
			notify("🎲 Nick Reset")
		end
	end)
	if not success then
		randomNick = false
		notify("⚠️ Failed to set random nick: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
	end
end

-- Set custom nickname
local function setCustomNick(nick)
	if nick == "" then
		notify("⚠️ Nick cannot be empty", Color3.fromRGB(255, 100, 100))
		return
	end
	local success, errorMsg = pcall(function()
		if #nick <= 32 then
			customNick = nick
			if char and char:FindFirstChild("Head") then
				local head = char.Head
				local billboard = head:FindFirstChild("Nametag") or head:FindFirstChildOfClass("BillboardGui")
				if billboard then
					local textLabel = findTextLabel(billboard)
					if textLabel then
						textLabel.Text = nickHidden and "" or nick
					end
				end
			end
			if humanoid then
				humanoid.DisplayName = nickHidden and "" or nick
			end
			if randomNick then
				randomNick = false
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

-- Macro recording
local function startMacroRecording()
	if macroRecording then
		return
	end
	macroRecording = true
	macroActions = {}
	local startTime = tick()
	local isSuccessfulRun = true
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
	connections.macroDeath = humanoid.Died:Connect(function()
		isSuccessfulRun = false
		notify("💀 Macro run failed (death detected)", Color3.fromRGB(255, 100, 100))
	end)
	connections.macroStopCheck = player.CharacterAdded:Connect(function()
		if macroRecording and not recordOnRespawn then
			macroRecording = false
			if connections.macroRecord then
				connections.macroRecord:Disconnect()
				connections.macroRecord = nil
			end
			if isSuccessfulRun then
				macroSuccessfulRun = macroActions
				notify("✅ Macro run saved as successful", Color3.fromRGB(0, 255, 0))
			end
			macroActions = {}
			isSuccessfulRun = true
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
		if connections.macroDeath then
			connections.macroDeath:Disconnect()
			connections.macroDeath = nil
		end
		if connections.macroStopCheck then
			connections.macroStopCheck:Disconnect()
			connections.macroStopCheck = nil
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
		if connections.macroDeath then
			connections.macroDeath:Disconnect()
			connections.macroDeath = nil
		end
		if connections.macroStopCheck then
			connections.macroStopCheck:Disconnect()
			connections.macroStopCheck = nil
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

-- Macro playback
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
		local actionsToPlay = macroSuccessfulRun or macroActions
		if #actionsToPlay == 0 then
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
		connections.macroPlay = RunService.RenderStepped:Connect(function()
			if index > #actionsToPlay then
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
			local action = actionsToPlay[index]
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
		notify("▶️ Macro Playback Started (Using " .. (macroSuccessfulRun and "successful" or "last") .. " run)")
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
			if #macroActions > 0 or macroSuccessfulRun then
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

-- Create GUI
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
		gui.Parent = player:WaitForChild("PlayerGui", 20)

		logo = Instance.new("ImageButton")
		logo.Size = UDim2.new(0, 60, 0, 60)
		logo.Position = defaultLogoPos
		logo.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
		logo.BorderSizePixel = 0
		logo.Image = "rbxassetid://3570695787"
		logo.ZIndex = 10
		logo.Parent = gui

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

		local scrollFrame = Instance.new("ScrollingFrame")
		scrollFrame.Size = UDim2.new(1, 0, 1, -60)
		scrollFrame.Position = UDim2.new(0, 0, 0, 60)
		scrollFrame.BackgroundTransparency = 1
		scrollFrame.ScrollBarThickness = 5
		scrollFrame.CanvasSize = UDim2.new(0, 0, 4, 0)
		scrollFrame.ZIndex = 10
		local scrollUIL = Instance.new("UIListLayout")
		scrollUIL.FillDirection = Enum.FillDirection.Vertical
		scrollUIL.Padding = UDim.new(0, 5)
		scrollUIL.Parent = scrollFrame
		scrollFrame.Parent = frame

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0, 50)
		title.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		title.BackgroundTransparency = 0.5
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.TextScaled = true
		title.Font = Enum.Font.GothamBold
		title.Text = "Krnl UI"
		title.ZIndex = 10
		title.Parent = frame

		local function createButton(text, callback)
			local button = Instance.new("TextButton")
			button.Size = UDim2.new(0.9, 0, 0, 40)
			button.Position = UDim2.new(0.05, 0, 0, 0)
			button.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			button.BackgroundTransparency = 0.3
			button.TextColor3 = Color3.fromRGB(255, 255, 255)
			button.TextScaled = true
			button.Font = Enum.Font.Gotham
			button.Text = text
			button.ZIndex = 10
			button.Parent = scrollFrame
			button.MouseButton1Click:Connect(function()
				local success, err = pcall(callback)
				if not success then
					notify("⚠️ Error in " .. text .. ": " .. tostring(err), Color3.fromRGB(255, 100, 100))
				end
			end)
			return button
		end

		local function createTextBox(placeholder, callback)
			local textBox = Instance.new("TextBox")
			textBox.Size = UDim2.new(0.9, 0, 0, 40)
			textBox.Position = UDim2.new(0.05, 0, 0, 0)
			textBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			textBox.BackgroundTransparency = 0.3
			textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
			textBox.TextScaled = true
			textBox.Font = Enum.Font.Gotham
			textBox.PlaceholderText = placeholder
			textBox.ZIndex = 10
			textBox.Parent = scrollFrame
			textBox.FocusLost:Connect(function(enterPressed)
				if enterPressed then
					local success, err = pcall(function()
						callback(textBox.Text)
						textBox.Text = ""
					end)
					if not success then
						notify("⚠️ Error in TextBox: " .. tostring(err), Color3.fromRGB(255, 100, 100))
					end
				end
			end)
			return textBox
		end

		local function createPlayerDropdown()
			local dropdownFrame = Instance.new("Frame")
			dropdownFrame.Size = UDim2.new(0.9, 0, 0, 40)
			dropdownFrame.Position = UDim2.new(0.05, 0, 0, 0)
			dropdownFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			dropdownFrame.BackgroundTransparency = 0.3
			dropdownFrame.ZIndex = 10
			dropdownFrame.Parent = scrollFrame

			local dropdownButton = Instance.new("TextButton")
			dropdownButton.Size = UDim2.new(1, 0, 1, 0)
			dropdownButton.BackgroundTransparency = 1
			dropdownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			dropdownButton.TextScaled = true
			dropdownButton.Font = Enum.Font.Gotham
			dropdownButton.Text = "Select Player"
			dropdownButton.ZIndex = 11
			dropdownButton.Parent = dropdownFrame

			local dropdownList = Instance.new("ScrollingFrame")
			dropdownList.Size = UDim2.new(1, 0, 0, 120)
			dropdownList.Position = UDim2.new(0, 0, 1, 0)
			dropdownList.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			dropdownList.BackgroundTransparency = 0.2
			dropdownList.ScrollBarThickness = 5
			dropdownList.Visible = false
			dropdownList.ZIndex = 12
			local dropdownUIL = Instance.new("UIListLayout")
			dropdownUIL.FillDirection = Enum.FillDirection.Vertical
			dropdownUIL.Padding = UDim.new(0, 5)
			dropdownUIL.Parent = dropdownList
			dropdownList.Parent = dropdownFrame

			local function updateDropdown()
				for _, child in pairs(dropdownList:GetChildren()) do
					if child:IsA("TextButton") then
						child:Destroy()
					end
				end
				dropdownList.CanvasSize = UDim2.new(0, 0, 0, #Players:GetPlayers() * 45)
				for _, p in pairs(Players:GetPlayers()) do
					local playerButton = Instance.new("TextButton")
					playerButton.Size = UDim2.new(1, 0, 0, 40)
					playerButton.BackgroundTransparency = 1
					playerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
					playerButton.TextScaled = true
					playerButton.Font = Enum.Font.Gotham
					playerButton.Text = p.Name
					playerButton.ZIndex = 13
					playerButton.Parent = dropdownList
					playerButton.MouseButton1Click:Connect(function()
						selectedPlayer = p
						dropdownButton.Text = p.Name
						dropdownList.Visible = false
						notify("👤 Selected " .. p.Name)
					end)
				end
			end

			dropdownButton.MouseButton1Click:Connect(function()
				dropdownList.Visible = not dropdownList.Visible
				updateDropdown()
			end)

			Players.PlayerAdded:Connect(updateDropdown)
			Players.PlayerRemoving:Connect(updateDropdown)
			updateDropdown()
			return dropdownFrame
		end

		-- Create GUI buttons
		createButton("Toggle Fly", toggleFly)
		createButton("Toggle Freecam", toggleFreecam)
		createButton("Return to Character", returnToCharacter)
		createButton("Cancel Freecam", cancelFreecam)
		createButton("Teleport Character to Camera", teleportCharacterToCamera)
		createPlayerDropdown()
		createButton("Teleport to Player", function()
			if selectedPlayer then
				teleportToPlayer(selectedPlayer)
			else
				notify("⚠️ No player selected", Color3.fromRGB(255, 100, 100))
			end
		end)
		createButton("Spectate Player", function()
			if selectedPlayer then
				toggleSpectate(selectedPlayer)
			else
				notify("⚠️ No player selected", Color3.fromRGB(255, 100, 100))
			end
		end)
		createButton("Teleport to Spectated", teleportToSpectated)
		createButton("Cancel Spectate", cancelSpectate)
		createButton("Carry Player", function()
			if selectedPlayer then
				carryPlayer(selectedPlayer)
			else
				notify("⚠️ No player selected", Color3.fromRGB(255, 100, 100))
			end
		end)
		createButton("Stop Carrying", stopCarryPlayer)
		createButton("Follow Player", function()
			if selectedPlayer then
				toggleFollowPlayer(selectedPlayer)
			else
				notify("⚠️ No player selected", Color3.fromRGB(255, 100, 100))
			end
		end)
		createButton("Cancel Follow", cancelFollowPlayer)
		createButton("Pull Player to Me", function()
			if selectedPlayer then
				pullPlayerToMe(selectedPlayer)
			else
				notify("⚠️ No player selected", Color3.fromRGB(255, 100, 100))
			end
		end)
		createButton("Teleport to Spawn", teleportToSpawn)
		createButton("Toggle Noclip", toggleNoclip)
		createButton("Toggle Speed", toggleSpeed)
		createButton("Toggle Jump", toggleJump)
		createButton("Toggle Water Walk", toggleWaterWalk)
		createButton("Toggle Rocket", toggleRocket)
		createButton("Toggle Spin", toggleSpin)
		createButton("Toggle God Mode", toggleGodMode)
		createButton("Save Position 1", function() savePosition(1) end)
		createButton("Save Position 2", function() savePosition(2) end)
		createButton("Load Position 1", function() loadPosition(1) end)
		createButton("Load Position 2", function() loadPosition(2) end)
		createButton("Toggle Hide Nick", toggleHideNick)
		createButton("Toggle Random Nick", toggleRandomNick)
		createTextBox("Enter Custom Nick", setCustomNick)
		createButton("Toggle Record Macro", toggleRecordMacro)
		createButton("Stop Record Macro", stopRecordMacro)
		createButton("Toggle Record on Respawn", toggleRecordOnRespawn)
		createButton("Toggle Play Macro", togglePlayMacro)
		createButton("Stop Play Macro", stopPlayMacro)
		createButton("Toggle Auto Play Macro", toggleAutoPlayMacro)
		createButton("Reset UI Position", resetUIPosition)
		createButton("Close", function() frame.Visible = false end)

		logo.MouseButton1Click:Connect(function()
			frame.Visible = not frame.Visible
		end)

		local dragging, dragInput, dragStart, startPos
		local function update(input)
			local delta = input.Position - dragStart
			logo.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
		logo.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = logo.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)
		logo.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				dragInput = input
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if input == dragInput and dragging then
				update(input)
			end
		end)

		local frameDragging, frameDragInput, frameDragStart, frameStartPos
		local function frameUpdate(input)
			local delta = input.Position - frameDragStart
			frame.Position = UDim2.new(frameStartPos.X.Scale, frameStartPos.X.Offset + delta.X, frameStartPos.Y.Scale, frameStartPos.Y.Offset + delta.Y)
		end
		frame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				frameDragging = true
				frameDragStart = input.Position
				frameStartPos = frame.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						frameDragging = false
					end
				end)
			end
		end)
		frame.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				frameDragInput = input
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if input == frameDragInput and frameDragging then
				frameUpdate(input)
			end
		end)

		createJoystick()
		frame.Parent = gui
	end)
	if not success then
		notify("⚠️ GUI creation failed: " .. tostring(errorMsg), Color3.fromRGB(255, 100, 100))
	end
end

-- Initialize script
cleanupOldInstance()
createGUI()
initChar()
player.CharacterAdded:Connect(initChar)
notify("✅ Krnl UI Loaded Successfully", Color3.fromRGB(0, 255, 0))