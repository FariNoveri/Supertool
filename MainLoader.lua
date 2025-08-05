-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local DataStoreService = game:GetService("DataStoreService")

-- Player
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:FindFirstChildOfClass("Humanoid")
local RootPart = Character:FindFirstChild("HumanoidRootPart")

-- Variables
local flyEnabled = false
local noclipEnabled = false
local playerNoclipEnabled = false
local speedValue = 16
local jumpPower = 50
local spectateIndex = 1
local spectating = false
local godMode = false
local fullbright = false
local antiAFK = false
local savedPositions = {}
local spiderEnabled = false
local selectedPlayer = nil
local playersList = Players:GetPlayers()
local guiVisible = true
local minimized = false
local freecamEnabled = false
local freecamCamera = nil
local freecamCFrame = nil
local selectedPositionIndex = 1

-- DataStore for persistent storage
local PositionStore = DataStoreService:GetDataStore("SavedPositions")

-- Load saved positions
local success, loadedPositions = pcall(function()
    return PositionStore:GetAsync(Player.UserId .. "_positions") or {}
end)
if success then
    savedPositions = loadedPositions
end

-- Disable Previous Script
local guiName = "MobileCheatGUI"
local existingGui = Player:WaitForChild("PlayerGui"):FindFirstChild(guiName)
if existingGui then
    existingGui:Destroy()
end

-- UI Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = guiName
ScreenGui.Parent = Player:WaitForChild("PlayerGui")
ScreenGui.IgnoreGuiInset = true

local LogoButton = Instance.new("TextButton")
LogoButton.Size = UDim2.new(0.05, 0, 0.05, 0)
LogoButton.Position = UDim2.new(0.95, 0, 0.05, 0)
LogoButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
LogoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoButton.Text = "X"
LogoButton.TextScaled = true
LogoButton.Parent = ScreenGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0.7, 0, 0.5, 0)
MainFrame.Position = UDim2.new(0.3, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local CategoryFrame = Instance.new("Frame")
CategoryFrame.Size = UDim2.new(0.3, 0, 1, 0)
CategoryFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
CategoryFrame.BorderSizePixel = 0
CategoryFrame.Parent = MainFrame

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(0.7, 0, 1, 0)
ContentFrame.Position = UDim2.new(0.3, 0, 0, 0)
ContentFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
ContentFrame.BorderSizePixel = 0
ContentFrame.Parent = MainFrame

local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Size = UDim2.new(0.1, 0, 0.05, 0)
MinimizeButton.Position = UDim2.new(0.9, 0, 0, 0)
MinimizeButton.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.Text = "-"
MinimizeButton.TextScaled = true
MinimizeButton.Parent = MainFrame

-- Draggable UI
local dragging, dragInput, dragStart, startPos
local function updateDrag(input, frame)
    local delta = input.Position - dragStart
    frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

local function makeDraggable(frame)
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    frame.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        updateDrag(input, LogoButton)
        updateDrag(input, MainFrame)
    end
end)

makeDraggable(LogoButton)
makeDraggable(MainFrame)

local function createButton(parent, text, position, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.9, 0, 0.1, 0)
    button.Position = position
    button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Text = text
    button.TextScaled = true
    button.Parent = parent
    button.MouseButton1Click:Connect(callback)
    return button
end

-- GUI Toggle and Minimize
LogoButton.MouseButton1Click:Connect(function()
    guiVisible = not guiVisible
    MainFrame.Visible = guiVisible
end)

MinimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        MainFrame.Size = UDim2.new(0.7, 0, 0.05, 0)
        CategoryFrame.Visible = false
        ContentFrame.Visible = false
        MinimizeButton.Text = "+"
    else
        MainFrame.Size = UDim2.new(0.7, 0, 0.5, 0)
        CategoryFrame.Visible = true
        ContentFrame.Visible = true
        MinimizeButton.Text = "-"
    end
end)

-- Category Buttons
local categories = {"Movement", "Visual", "Player", "Teleport", "Camera"}
local currentCategory = "Movement"
local categoryButtons = {}

for i, category in ipairs(categories) do
    categoryButtons[category] = createButton(CategoryFrame, category, UDim2.new(0.05, 0, 0.05 + (i-1)*0.15, 0), function()
        currentCategory = category
        ContentFrame:ClearAllChildren()
        loadCategoryContent()
    end)
end

-- Content Functions
local function loadCategoryContent()
    ContentFrame:ClearAllChildren()
    if currentCategory == "Movement" then
        createButton(ContentFrame, "Toggle Fly", UDim2.new(0.05, 0, 0.05, 0), function()
            flyEnabled = not flyEnabled
            toggleFly()
        end)
        createButton(ContentFrame, "Toggle Noclip", UDim2.new(0.05, 0, 0.2, 0), function()
            noclipEnabled = not noclipEnabled
        end)
        createButton(ContentFrame, "Toggle Spider", UDim2.new(0.05, 0, 0.35, 0), function()
            spiderEnabled = not spiderEnabled
        end)
        createButton(ContentFrame, "Set Speed", UDim2.new(0.05, 0, 0.5, 0), function()
            speedValue = speedValue + 10
            if speedValue > 100 then speedValue = 16 end
            Humanoid.WalkSpeed = speedValue
        end)
        createButton(ContentFrame, "Set Jump", UDim2.new(0.05, 0, 0.65, 0), function()
            jumpPower = jumpPower + 10
            if jumpPower > 100 then jumpPower = 50 end
            Humanoid.JumpPower = jumpPower
        end)
        createButton(ContentFrame, "God Mode", UDim2.new(0.05, 0, 0.8, 0), function()
            godMode = not godMode
            toggleGodMode()
        end)
    elseif currentCategory == "Visual" then
        createButton(ContentFrame, "Toggle Fullbright", UDim2.new(0.05, 0, 0.05, 0), function()
            fullbright = not fullbright
            toggleFullbright()
        end)
        createButton(ContentFrame, "Toggle Anti AFK", UDim2.new(0.05, 0, 0.2, 0), function()
            antiAFK = not antiAFK
        end)
    elseif currentCategory == "Player" then
        createButton(ContentFrame, "Toggle Spectate", UDim2.new(0.05, 0, 0.05, 0), function()
            spectating = not spectating
            toggleSpectate()
        end)
        createButton(ContentFrame, "Next Spectate", UDim2.new(0.05, 0, 0.2, 0), function()
            spectateIndex = spectateIndex + 1
            if spectateIndex > #playersList then spectateIndex = 1 end
            toggleSpectate()
        end)
        createButton(ContentFrame, "Prev Spectate", UDim2.new(0.05, 0, 0.35, 0), function()
            spectateIndex = spectateIndex - 1
            if spectateIndex < 1 then spectateIndex = #playersList end
            toggleSpectate()
        end)
        createButton(ContentFrame, "TP to Spectate", UDim2.new(0.05, 0, 0.5, 0), function()
            if spectating and playersList[spectateIndex] then
                RootPart.CFrame = playersList[spectateIndex].Character.HumanoidRootPart.CFrame
            end
        end)
        createButton(ContentFrame, "Player Noclip", UDim2.new(0.05, 0, 0.65, 0), function()
            playerNoclipEnabled = not playerNoclipEnabled
        end)
    elseif currentCategory == "Teleport" then
        createButton(ContentFrame, "Save Position", UDim2.new(0.05, 0, 0.05, 0), function()
            local positionName = "Position " .. (#savedPositions + 1)
            table.insert(savedPositions, {name = positionName, cframe = RootPart.CFrame})
            pcall(function()
                PositionStore:SetAsync(Player.UserId .. "_positions", savedPositions)
            end)
        end)
        createButton(ContentFrame, "Next Position", UDim2.new(0.05, 0, 0.2, 0), function()
            selectedPositionIndex = selectedPositionIndex + 1
            if selectedPositionIndex > #savedPositions then selectedPositionIndex = 1 end
        end)
        createButton(ContentFrame, "Prev Position", UDim2.new(0.05, 0, 0.35, 0), function()
            selectedPositionIndex = selectedPositionIndex - 1
            if selectedPositionIndex < 1 then selectedPositionIndex = #savedPositions end
        end)
        createButton(ContentFrame, "TP to Saved Pos", UDim2.new(0.05, 0, 0.5, 0), function()
            if savedPositions[selectedPositionIndex] then
                RootPart.CFrame = savedPositions[selectedPositionIndex].cframe
            end
        end)
        local renameButton = createButton(ContentFrame, "Rename Position", UDim2.new(0.05, 0, 0.65, 0), function()
            if savedPositions[selectedPositionIndex] then
                local renameFrame = Instance.new("Frame")
                renameFrame.Size = UDim2.new(0.5, 0, 0.2, 0)
                renameFrame.Position = UDim2.new(0.25, 0, 0.4, 0)
                renameFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
                renameFrame.Parent = ContentFrame

                local renameTextBox = Instance.new("TextBox")
                renameTextBox.Size = UDim2.new(0.8, 0, 0.5, 0)
                renameTextBox.Position = UDim2.new(0.1, 0, 0.1, 0)
                renameTextBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
                renameTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
                renameTextBox.Text = savedPositions[selectedPositionIndex].name
                renameTextBox.TextScaled = true
                renameTextBox.Parent = renameFrame

                local confirmButton = Instance.new("TextButton")
                confirmButton.Size = UDim2.new(0.4, 0, 0.3, 0)
                confirmButton.Position = UDim2.new(0.3, 0, 0.6, 0)
                confirmButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
                confirmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                confirmButton.Text = "Confirm"
                confirmButton.TextScaled = true
                confirmButton.Parent = renameFrame
                confirmButton.MouseButton1Click:Connect(function()
                    savedPositions[selectedPositionIndex].name = renameTextBox.Text
                    pcall(function()
                        PositionStore:SetAsync(Player.UserId .. "_positions", savedPositions)
                    end)
                    renameFrame:Destroy()
                end)
            end
        end)
        createButton(ContentFrame, "Delete Position", UDim2.new(0.05, 0, 0.8, 0), function()
            if savedPositions[selectedPositionIndex] then
                table.remove(savedPositions, selectedPositionIndex)
                pcall(function()
                    PositionStore:SetAsync(Player.UserId .. "_positions", savedPositions)
                end)
                if selectedPositionIndex > #savedPositions then selectedPositionIndex = #savedPositions end
            end
        end)
        createButton(ContentFrame, "Select Player", UDim2.new(0.05, 0, 0.95, 0), function()
            selectedPlayer = playersList[spectateIndex]
        end)
        createButton(ContentFrame, "TP to Player", UDim2.new(0.05, 0, 1.1, 0), function()
            if selectedPlayer and selectedPlayer.Character then
                RootPart.CFrame = selectedPlayer.Character.HumanoidRootPart.CFrame
            end
        end)
    elseif currentCategory == "Camera" then
        createButton(ContentFrame, "Toggle Freecam", UDim2.new(0.05, 0, 0.05, 0), function()
            freecamEnabled = not freecamEnabled
            toggleFreecam()
        end)
        createButton(ContentFrame, "TP to Freecam", UDim2.new(0.05, 0, 0.2, 0), function()
            if freecamEnabled and freecamCFrame then
                RootPart.CFrame = freecamCFrame
            end
        end)
    end
end

-- Fly Function
local function toggleFly()
    if flyEnabled then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(0, math.huge, 0)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.Parent = RootPart
        while flyEnabled and RootPart do
            bodyVelocity.Velocity = UserInputService:GetLastInputType() == Enum.UserInputType.Touch and
                Vector3.new(0, 10, 0) or Vector3.new(0, 0, 0)
            RunService.Stepped:Wait()
        end
        bodyVelocity:Destroy()
    end
end

-- God Mode
local function toggleGodMode()
    if godMode then
        Humanoid.MaxHealth = math.huge
        Humanoid.Health = math.huge
        Humanoid.FallDamageEnabled = false
    else
        Humanoid.MaxHealth = 100
        Humanoid.Health = 100
        Humanoid.FallDamageEnabled = true
    end
end

-- Fullbright
local function toggleFullbright()
    if fullbright then
        Lighting.Brightness = 2
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
    else
        Lighting.Brightness = 1
        Lighting.FogEnd = 0
        Lighting.GlobalShadows = true
    end
end

-- Spectate
local function toggleSpectate()
    if spectating and playersList[spectateIndex] then
        workspace.CurrentCamera.CameraSubject = playersList[spectateIndex].Character.Humanoid
    else
        workspace.CurrentCamera.CameraSubject = Humanoid
    end
end

-- Freecam
local function toggleFreecam()
    if freecamEnabled then
        freecamCamera = workspace.CurrentCamera:Clone()
        freecamCamera.CameraType = Enum.CameraType.Scriptable
        freecamCamera.Parent = workspace
        freecamCFrame = workspace.CurrentCamera.CFrame
        workspace.CurrentCamera = freecamCamera
    else
        if freecamCamera then
            freecamCamera:Destroy()
            freecamCamera = nil
            workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
            workspace.CurrentCamera.CameraSubject = Humanoid
        end
    end
end

-- Freecam Joystick
local joystickFrame = Instance.new("Frame")
joystickFrame.Size = UDim2.new(0.3, 0, 0.3, 0)
joystickFrame.Position = UDim2.new(0.65, 0, 0.65, 0)
joystickFrame.BackgroundTransparency = 1
joystickFrame.Parent = ScreenGui

local joystickTouchId = nil
local joystickStartPos = nil
UserInputService.InputBegan:Connect(function(input)
    if freecamEnabled and input.UserInputType == Enum.UserInputType.Touch then
        local touchPos = input.Position
        if touchPos.X > joystickFrame.AbsolutePosition.X and touchPos.X < joystickFrame.AbsolutePosition.X + joystickFrame.AbsoluteSize.X and
           touchPos.Y > joystickFrame.AbsolutePosition.Y and touchPos.Y < joystickFrame.AbsolutePosition.Y + joystickFrame.AbsoluteSize.Y then
            joystickTouchId = input.UserInputId
            joystickStartPos = touchPos
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if freecamEnabled and input.UserInputType == Enum.UserInputType.Touch and input.UserInputId == joystickTouchId then
        local delta = (input.Position - joystickStartPos) / 100
        if freecamCamera then
            local lookVector = freecamCFrame.LookVector
            local rightVector = freecamCFrame.RightVector
            freecamCFrame = freecamCFrame * CFrame.new(-delta.X * rightVector + delta.Y * lookVector)
            freecamCamera.CFrame = freecamCFrame
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch and input.UserInputId == joystickTouchId then
        joystickTouchId = nil
        joystickStartPos = nil
    end
end)

-- Noclip
RunService.Stepped:Connect(function()
    if noclipEnabled or playerNoclipEnabled then
        for _, part in pairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

-- Spider
RunService.Stepped:Connect(function()
    if spiderEnabled and RootPart then
        local ray = Ray.new(RootPart.Position, RootPart.CFrame.LookVector * 2)
        local hit, pos = workspace:FindPartOnRay(ray, Character)
        if hit and not hit:IsDescendantOf(Character) then
            RootPart.Velocity = Vector3.new(0, 50, 0)
        end
    end
end)

-- Anti AFK
RunService.Stepped:Connect(function()
    if antiAFK then
        Player.Idled:Fire()
    end
end)

-- Player Updates
Players.PlayerAdded:Connect(function()
    playersList = Players:GetPlayers()
end)
Players.PlayerRemoving:Connect(function()
    playersList = Players:GetPlayers()
    if spectateIndex > #playersList then spectateIndex = 1 end
end)

-- Character Reset
Player.CharacterAdded:Connect(function(char)
    Character = char
    Humanoid = char:FindFirstChildOfClass("Humanoid")
    RootPart = char:FindFirstChild("HumanoidRootPart")
    Humanoid.WalkSpeed = speedValue
    Humanoid.JumpPower = jumpPower
    if godMode then
        toggleGodMode()
    end
end)

-- Initial Setup
Humanoid.WalkSpeed = speedValue
Humanoid.JumpPower = jumpPower
StarterGui:SetCore("ChatActive", true)
loadCategoryContent()