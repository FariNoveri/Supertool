-- MainLoader.lua (Versi Android Full Tombol + Scroll + God Mode)
-- Dibuat oleh Fari Noveri - UI & kontrol khusus Android

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local humanoid, hr, char
local flying, noclip, autoHeal, noFall, godMode = false, false, false, false, false
local savedPos = nil
local followTarget = nil
local up, down = false, false

local gui = Instance.new("ScreenGui")
gui.Name = "SuperToolUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local logo = Instance.new("ImageButton")
logo.Size = UDim2.new(0, 50, 0, 50)
logo.Position = UDim2.new(0, 10, 0, 10)
logo.BackgroundTransparency = 1
logo.Image = "rbxassetid://3570695787"
logo.Parent = gui

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(0, 280, 0, 420)
scrollFrame.Position = UDim2.new(0, 70, 0, 60)
scrollFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
scrollFrame.BackgroundTransparency = 0.1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = gui

local layoutList = Instance.new("UIListLayout")
layoutList.Padding = UDim.new(0, 4)
layoutList.SortOrder = Enum.SortOrder.LayoutOrder
layoutList.Parent = scrollFrame

layoutList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layoutList.AbsoluteContentSize.Y + 10)
end)

local function createButton(text, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -10, 0, 36)
	btn.Position = UDim2.new(0, 5, 0, 0)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamSemibold
	btn.Text = text
	btn.TextScaled = true
	btn.Parent = scrollFrame
	btn.MouseButton1Click:Connect(callback)
	return btn
end

local function createToggle(text, stateRef, callback)
	local btn = createButton(text .. " ❌", function()
		stateRef[1] = not stateRef[1]
		btn.Text = text .. (stateRef[1] and " ✅" or " ❌")
		callback(stateRef[1])
	end)
	callback(stateRef[1])
end

local function refreshCharacter()
	char = player.Character or player.CharacterAdded:Wait()
	humanoid = char:WaitForChild("Humanoid")
	hr = char:WaitForChild("HumanoidRootPart")
end
refreshCharacter()
player.CharacterAdded:Connect(function()
	task.wait(1)
	refreshCharacter()
	if savedPos then hr.CFrame = CFrame.new(savedPos) end
end)

-- Tombol Fitur
createToggle("🕊️ Fly", {flying}, function(val) flying = val end)
createButton("⬆️ Naik", function() up = true wait(0.3) up = false end)
createButton("⬇️ Turun", function() down = true wait(0.3) down = false end)
createToggle("👻 Noclip", {noclip}, function(val) noclip = val end)
createToggle("🛡️ No Fall", {noFall}, function(val) noFall = val end)
createToggle("❤️ Auto Heal", {autoHeal}, function(val) autoHeal = val end)
createToggle("💀 God Mode", {godMode}, function(val) godMode = val end)
createButton("📍 Simpan Lokasi", function() if hr then savedPos = hr.Position end end)
createButton("🚀 Teleport ke Lokasi", function() if savedPos and hr then hr.CFrame = CFrame.new(savedPos) end end)

-- Tarik Pemain
createButton("🧲 Tarik Pemain", function()
	local menu = Instance.new("Frame")
	menu.Size = UDim2.new(0, 260, 0, 120)
	menu.Position = UDim2.new(0, 10, 0, 480)
	menu.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	menu.Parent = gui

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.Parent = menu

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local opt = Instance.new("TextButton")
			opt.Size = UDim2.new(1, 0, 0, 28)
			opt.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
			opt.TextColor3 = Color3.new(1, 1, 1)
			opt.Font = Enum.Font.Gotham
			opt.Text = p.Name
			opt.TextScaled = true
			opt.Parent = menu
			opt.MouseButton1Click:Connect(function()
				menu:Destroy()
				p.Character.HumanoidRootPart.CFrame = hr.CFrame + Vector3.new(0, 5, 0)
			end)
		end
	end
end)

-- Teleport ke Pemain
createButton("🌍 Teleport ke Pemain", function()
	local menu = Instance.new("Frame")
	menu.Size = UDim2.new(0, 260, 0, 120)
	menu.Position = UDim2.new(0, 10, 0, 610)
	menu.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	menu.Parent = gui

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.Parent = menu

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			local opt = Instance.new("TextButton")
			opt.Size = UDim2.new(1, 0, 0, 28)
			opt.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
			opt.TextColor3 = Color3.new(1, 1, 1)
			opt.Font = Enum.Font.Gotham
			opt.Text = p.Name
			opt.TextScaled = true
			opt.Parent = menu
			opt.MouseButton1Click:Connect(function()
				menu:Destroy()
				hr.CFrame = p.Character.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0)
			end)
		end
	end
end)

-- Follow Pemain
createButton("🎯 Follow Pemain", function()
	local menu = Instance.new("Frame")
	menu.Size = UDim2.new(0, 260, 0, 120)
	menu.Position = UDim2.new(0, 10, 0, 740)
	menu.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	menu.Parent = gui

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.Parent = menu

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			local opt = Instance.new("TextButton")
			opt.Size = UDim2.new(1, 0, 0, 28)
			opt.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
			opt.TextColor3 = Color3.new(1, 1, 1)
			opt.Font = Enum.Font.Gotham
			opt.Text = p.Name
			opt.TextScaled = true
			opt.Parent = menu
			opt.MouseButton1Click:Connect(function()
				menu:Destroy()
				followTarget = p
			end)
		end
	end
end)

logo.MouseButton1Click:Connect(function()
	scrollFrame.Visible = not scrollFrame.Visible
end)

RunService.RenderStepped:Connect(function()
	if flying and hr then
		local dir = humanoid.MoveDirection * 2
		if up then dir += Vector3.new(0, 2, 0) end
		if down then dir -= Vector3.new(0, 2, 0) end
		hr.Velocity = dir * 30
	end
	if noclip and char then
		for _,v in ipairs(char:GetDescendants()) do
			if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end
		end
	end
	if autoHeal and humanoid and humanoid.Health < humanoid.MaxHealth then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 0.5)
	end
	if godMode and humanoid then
		humanoid.Health = humanoid.MaxHealth
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	end
	if noFall and humanoid then
		if humanoid:GetState() == Enum.HumanoidStateType.Freefall then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
	if followTarget and followTarget.Character and followTarget.Character:FindFirstChild("HumanoidRootPart") and hr then
		hr.CFrame = followTarget.Character.HumanoidRootPart.CFrame + Vector3.new(0, 0, -3)
	end
end)

print("✅ SuperTool Android + Scroll + GodMode Loaded")