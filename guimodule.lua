-- GuiModule.lua

local GuiModule = {}

function GuiModule.initUI()
	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- Buat ScreenGui utama
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SuperToolUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Buat Frame utama
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 260, 0, 400)
	mainFrame.Position = UDim2.new(0, 50, 0.2, 0)
	mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	mainFrame.BorderSizePixel = 0
	mainFrame.AnchorPoint = Vector2.new(0, 0)
	mainFrame.Parent = screenGui

	-- Buat UI corner (rounded)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
	uiCorner.Parent = mainFrame

	-- Judul
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "🧰 SuperTool Menu"
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.Parent = mainFrame

	-- Scrolling container
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ScrollArea"
	scrollFrame.Size = UDim2.new(1, -20, 1, -60)
	scrollFrame.Position = UDim2.new(0, 10, 0, 50)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.Parent = mainFrame

	-- Layout untuk tombol-tombol cheat
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scrollFrame

	-- Auto-update canvas height
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end)

	-- Simpan referensi UI di shared (biar modul lain bisa pakai)
	getgenv().SuperToolUI = {
		ScreenGui = screenGui,
		MainFrame = mainFrame,
		ScrollArea = scrollFrame
	}
end

return GuiModule
