-- Utilities.lua
-- Dibuat oleh Fari Noveri untuk SuperTool - Modul Utilitas UI

local Utilities = {}

local GuiModule = require(script.Parent:WaitForChild("GuiModule"))
local scroll = nil

function Utilities.setup()
	scroll = GuiModule.getScroll()
end

function Utilities.createButton(text, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -10, 0, 36)
	btn.Position = UDim2.new(0, 5, 0, 0)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamSemibold
	btn.Text = text
	btn.TextScaled = true
	btn.AutoButtonColor = true
	btn.Parent = scroll
	btn.MouseButton1Click:Connect(callback)
	return btn
end

function Utilities.createStatusButton(text, defaultState, callback)
	local current = defaultState
	local btn = Utilities.createButton(text, function()
		current = not current
		btn.Text = text .. (current and " ✅" or " ❌")
		callback(current)
	end)
	btn.Text = text .. (current and " ✅" or " ❌") -- update awal
	callback(current)
	return btn
end

function Utilities.createToggleButton(text, defaultState, callback)
	return Utilities.createStatusButton(text, defaultState, callback)
end

function Utilities.createDropdown(title, onSelect)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -10, 0, 26)
	label.Position = UDim2.new(0, 5, 0, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.Font = Enum.Font.GothamSemibold
	label.Text = title
	label.TextScaled = true
	label.Parent = scroll

	local dropdown = Instance.new("TextButton")
	dropdown.Size = UDim2.new(1, -10, 0, 36)
	dropdown.Position = UDim2.new(0, 5, 0, 0)
	dropdown.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	dropdown.TextColor3 = Color3.new(1, 1, 1)
	dropdown.Font = Enum.Font.Gotham
	dropdown.Text = "Klik untuk Pilih Pemain"
	dropdown.TextScaled = true
	dropdown.Parent = scroll

	dropdown.MouseButton1Click:Connect(function()
		local Players = game:GetService("Players")
		local playerList = Players:GetPlayers()

		local menu = Instance.new("Frame")
		menu.Size = UDim2.new(1, -10, 0, math.min(200, #playerList * 30 + 32))
		menu.Position = dropdown.AbsolutePosition - scroll.AbsolutePosition + Vector2.new(0, dropdown.AbsoluteSize.Y)
		menu.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		menu.BorderSizePixel = 0
		menu.ClipsDescendants = true
		menu.Parent = scroll.Parent  -- penting: di atas scroll, bukan di dalamnya

		local listLayout = Instance.new("UIListLayout", menu)
		listLayout.Padding = UDim.new(0, 2)

		for _, p in ipairs(playerList) do
			if p.Name ~= Players.LocalPlayer.Name then
				local opt = Instance.new("TextButton")
				opt.Size = UDim2.new(1, 0, 0, 28)
				opt.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
				opt.TextColor3 = Color3.new(1, 1, 1)
				opt.Font = Enum.Font.Gotham
				opt.Text = p.Name
				opt.TextScaled = true
				opt.Parent = menu

				opt.MouseButton1Click:Connect(function()
					dropdown.Text = "🎯 " .. p.Name
					menu:Destroy()
					onSelect(p.Name)
				end)
			end
		end

		local cancel = Instance.new("TextButton")
		cancel.Size = UDim2.new(1, 0, 0, 28)
		cancel.BackgroundColor3 = Color3.fromRGB(70, 0, 0)
		cancel.TextColor3 = Color3.new(1, 1, 1)
		cancel.Font = Enum.Font.Gotham
		cancel.Text = "Batal"
		cancel.TextScaled = true
		cancel.Parent = menu

		cancel.MouseButton1Click:Connect(function()
			menu:Destroy()
		end)
	end)

	return dropdown
end

return Utilities
