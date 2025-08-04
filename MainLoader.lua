-- Minimalist Roblox Script for Android with Spectate (Fluxus Optimized)
-- Black theme, left sidebar, watermark with HWID

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

-- Fallback to ScreenGui if CoreGui fails
local function createGui()
    local success, result = pcall(function()
        return CoreGui
    end)
    return success and result or Instance.new("ScreenGui")
end

local gui = createGui()
gui.Name = "MinimalistGUI"
gui.ResetOnSpawn = false

-- Main Frame (Black Minimalist Theme)
local mainFrame = Instance.new("Frame", gui)
mainFrame.Size = UDim2.new(0, 400, 0, 250)
mainFrame.Position = UDim2.new(0.5, -200, 0.5, -125)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true

-- Sidebar (Left)
local sidebar = Instance.new("Frame", mainFrame)
sidebar.Size = UDim2.new(0, 100, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
sidebar.BorderSizePixel = 0

-- Content Frame (Right)
local contentFrame = Instance.new("Frame", mainFrame)
contentFrame.Size = UDim2.new(0, 300, 1, 0)
contentFrame.Position = UDim2.new(0, 100, 0, 0)
contentFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
contentFrame.BorderSizePixel = 0

-- Watermark with HWID
local hwid = "Unknown"
pcall(function()
    hwid = gethwid and gethwid() or "No HWID"
end)
local watermark = Instance.new("TextLabel", mainFrame)
watermark.Size = UDim2.new(0, 200, 0, 20)
watermark.Position = UDim2.new(1, -200, 0, 5)
watermark.BackgroundTransparency = 1
watermark.Text = "unknown block - farinoveri | " .. hwid
watermark.TextColor3 = Color3.fromRGB(255, 255, 255)
watermark.TextSize = 12
watermark.Font = Enum.Font.SourceSans

-- Close Button
local closeButton = Instance.new("TextButton", mainFrame)
closeButton.Size = UDim2.new(0, 20, 0, 20)
closeButton.Position = UDim2.new(1, -25, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 14
closeButton.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

-- Main Button (⚡ Bottom Right)
local mainButton = Instance.new("TextButton")
mainButton.Size = UDim2.new(0, 50, 0, 50)
mainButton.Position = UDim2.new(1, -60, 1, -60)
mainButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainButton.Text = "⚡"
mainButton.TextColor3 = Color3.fromRGB(255, 255, 255)
mainButton.TextSize = 20
mainButton.Parent = gui
mainButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

-- Notification System
local function notify(message)
    local notif = Instance.new("TextLabel", gui)
    notif.Size = UDim2.new(0, 200, 0, 30)
    notif.Position = UDim2.new(0.5, -100, 0, 10)
    notif.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    notif.Text = message
    notif.TextColor3 = Color3.fromRGB(255, 255, 255)
    notif.TextSize = 14
    notif.ZIndex = 10
    wait(3)
    notif:Destroy()
end

-- Category System
local categories = {"Movement", "Teleport", "Player", "Misc"}
local currentCategory = "Movement"

-- Category Buttons
local function createCategoryButtons()
    for i, category in ipairs(categories) do
        local button = Instance.new("TextButton", sidebar)
        button.Size = UDim2.new(1, 0, 0, 30)
        button.Position = UDim2.new(0, 0, 0, (i-1)*30)
        button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        button.Text = category
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 14
        button.MouseButton1Click:Connect(function()
            currentCategory = category
            contentFrame:ClearAllChildren()
            loadCategoryContent(category)
        end)
    end
end

-- Saved Positions with Categories
local savedPositions = {
    General = {},
    Spawn = {},
    Checkpoint = {},
    Important = {},
    Custom = {}
}
local positionCategory = "General" -- Default category

-- Freecam Variables
local freecamEnabled = false
local lastFreecamPos = nil
local camera = game.Workspace.CurrentCamera

-- Admin Detection
local adminList = {}
local adminDetectionEnabled = false

-- Fake Stats
local fakeStatsEnabled = false
local fakeStats = {"Kills: 1000", "Level: 99", "Coins: 99999"}
local currentStatIndex = 1

-- Spectate Variables
local spectating = false
local spectateTarget = nil
local spectateIndex = 0

-- Create Button Helper
local function createButton(parent, text, callback)
    local button = Instance.new("TextButton", parent)
    button.Size = UDim2.new(0, 280, 0, 30)
    button.Position = UDim2.new(0, 10, 0, #parent:GetChildren() * 35)
    button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 14
    button.MouseButton1Click:Connect(callback)
end

-- Spectate Function
local function updateSpectate(target)
    if spectating and target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        camera.CameraType = Enum.CameraType.Follow
        camera.CameraSubject = target.Character.Humanoid
        spectateTarget = target
        notify("Spectating " .. target.Name)
    else
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        spectating = false
        spectateTarget = nil
        notify("Spectate Stopped")
    end
end

-- Content Loader
local function loadCategoryContent(category)
    if category == "Movement" then
        createButton(contentFrame, "🛫 Toggle Fly/Freecam", function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                freecamEnabled = not freecamEnabled
                if freecamEnabled then
                    lastFreecamPos = LocalPlayer.Character.HumanoidRootPart.Position
                    camera.CameraType = Enum.CameraType.Scriptable
                    notify("Fly/Freecam Enabled")
                    game:GetService("RunService").RenderStepped:Connect(function()
                        if freecamEnabled then
                            local moveVector = Vector3.new()
                            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                                moveVector = moveVector + camera.CFrame.LookVector * 50
                            end
                            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                                moveVector = moveVector - camera.CFrame.LookVector * 50
                            end
                            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                                moveVector = moveVector - camera.CFrame.RightVector * 50
                            end
                            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                                moveVector = moveVector + camera.CFrame.RightVector * 50
                            end
                            camera.CFrame = camera.CFrame + moveVector * game:GetService("RunService").Heartbeat:Wait()
                        end
                    end)
                else
                    camera.CameraType = Enum.CameraType.Custom
                    notify("Fly/Freecam Disabled")
                end
            end
        end)
        createButton(contentFrame, "🏃 Toggle Speed", function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                local humanoid = LocalPlayer.Character.Humanoid
                humanoid.WalkSpeed = humanoid.WalkSpeed == 16 and 100 or 16
                notify(humanoid.WalkSpeed == 100 and "Speed Enabled" or "Speed Disabled")
            end
        end)
        createButton(contentFrame, "🦘 Toggle Jump Power", function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                local humanoid = LocalPlayer.Character.Humanoid
                humanoid.JumpPower = humanoid.JumpPower == 50 and 100 or 50
                notify(humanoid.JumpPower == 100 and "Jump Power Enabled" or "Jump Power Disabled")
            end
        end)
        createButton(contentFrame, "🚪 Toggle Noclip", function()
            local isNoclip = false
            isNoclip = not isNoclip
            notify(isNoclip and "Noclip Enabled" or "Noclip Disabled")
            game:GetService("RunService").Stepped:Connect(function()
                if isNoclip and LocalPlayer.Character then
                    for _, part in pairs(LocalPlayer.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
        end)
        createButton(contentFrame, "🌊 Toggle Water Walk", function()
            notify("Water Walk not supported on Android")
        end)
    elseif category == "Teleport" then
        createButton(contentFrame, "🚪 Teleport to Spawn", function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, 10, 0)
                notify("Teleported to Spawn")
            end
        end)
        createButton(contentFrame, "💾 Save Current Position", function()
            contentFrame:ClearAllChildren()
            local categoryDropdown = Instance.new("TextButton", contentFrame)
            categoryDropdown.Size = UDim2.new(0, 280, 0, 30)
            categoryDropdown.Position = UDim2.new(0, 10, 0, 0)
            categoryDropdown.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            categoryDropdown.Text = "Category: " .. positionCategory
            categoryDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
            categoryDropdown.TextSize = 14
            categoryDropdown.MouseButton1Click:Connect(function()
                local catList = {"General", "Spawn", "Checkpoint", "Important", "Custom"}
                local index = table.find(catList, positionCategory) or 1
                positionCategory = catList[(index % #catList) + 1]
                categoryDropdown.Text = "Category: " .. positionCategory
            end)
            createButton(contentFrame, "Save Position", function()
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local pos = LocalPlayer.Character.HumanoidRootPart.Position
                    table.insert(savedPositions[positionCategory], {pos = pos, name = "Pos " .. #savedPositions[positionCategory] + 1})
                    pcall(function()
                        local saveData = {}
                        for cat, positions in pairs(savedPositions) do
                            saveData[cat] = positions
                        end
                        writefile("positions.txt", game:GetService("HttpService"):JSONEncode(saveData))
                    end)
                    notify("Saved to " .. positionCategory)
                end
            end)
        end)
        createButton(contentFrame, "📍 Show Position List", function()
            contentFrame:ClearAllChildren()
            for cat, positions in pairs(savedPositions) do
                local collapsed = true
                local catButton = Instance.new("TextButton", contentFrame)
                catButton.Size = UDim2.new(0, 280, 0, 30)
                catButton.Position = UDim2.new(0, 10, 0, #contentFrame:GetChildren() * 35)
                catButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                catButton.Text = cat .. " (" .. #positions .. ")"
                catButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                catButton.TextSize = 14
                catButton.MouseButton1Click:Connect(function()
                    collapsed = not collapsed
                    contentFrame:ClearAllChildren()
                    if not collapsed then
                        for i, posData in ipairs(positions) do
                            local posFrame = Instance.new("Frame", contentFrame)
                            posFrame.Size = UDim2.new(0, 280, 0, 30)
                            posFrame.Position = UDim2.new(0, 10, 0, #contentFrame:GetChildren() * 35)
                            posFrame.BackgroundTransparency = 1
                            local goButton = Instance.new("TextButton", posFrame)
                            goButton.Size = UDim2.new(0, 200, 0, 30)
                            goButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                            goButton.Text = posData.name
                            goButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                            goButton.TextSize = 14
                            goButton.MouseButton1Click:Connect(function()
                                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(posData.pos)
                                    notify("Teleported to " .. posData.name)
                                end
                            end)
                            local renameButton = Instance.new("TextButton", posFrame)
                            renameButton.Size = UDim2.new(0, 40, 0, 30)
                            renameButton.Position = UDim2.new(0, 205, 0, 0)
                            renameButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                            renameButton.Text = "Rename"
                            renameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                            renameButton.TextSize = 12
                            renameButton.MouseButton1Click:Connect(function()
                                posData.name = "Renamed Pos " .. i
                                notify("Renamed to " .. posData.name)
                            end)
                            local deleteButton = Instance.new("TextButton", posFrame)
                            deleteButton.Size = UDim2.new(0, 40, 0, 30)
                            deleteButton.Position = UDim2.new(0, 250, 0, 0)
                            deleteButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
                            deleteButton.Text = "Del"
                            deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                            deleteButton.TextSize = 12
                            deleteButton.MouseButton1Click:Connect(function()
                                table.remove(positions, i)
                                notify("Deleted " .. posData.name)
                                loadCategoryContent("Teleport")
                            end)
                        end
                    else
                        loadCategoryContent("Teleport")
                    end
                end)
            end
        end)
        createButton(contentFrame, "🚀 Auto Teleport All", function()
            for cat, positions in pairs(savedPositions) do
                for _, posData in ipairs(positions) do
                    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(posData.pos)
                        notify("Teleported to " .. posData.name)
                        wait(1)
                    end
                end
            end
        end)
        createButton(contentFrame, "📍 Teleport to Last Freecam", function()
            if lastFreecamPos and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(lastFreecamPos)
                notify("Teleported to Last Freecam Position")
            else
                notify("No Freecam Position Saved")
            end
        end)
    elseif category == "Player" then
        createButton(contentFrame, "👥 Show Player List", function()
            contentFrame:ClearAllChildren()
            for _, player in ipairs(Players:GetPlayers()) do
                createButton(contentFrame, player.Name, function()
                    if LocalPlayer.Character and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        LocalPlayer.Character.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame
                        notify("Teleported to " .. player.Name)
                    end
                end)
            end
        end)
        createButton(contentFrame, "🛡️ Toggle Admin Detection", function()
            adminDetectionEnabled = not adminDetectionEnabled
            notify(adminDetectionEnabled and "Admin Detection Enabled" or "Admin Detection Disabled")
            if adminDetectionEnabled then
                Players.PlayerAdded:Connect(function(player)
                    pcall(function()
                        local role = player:GetRoleInGroup(game.GroupId)
                        if role == "Admin" or role == "Moderator" then
                            if not table.find(adminList, player.Name) then
                                table.insert(adminList, player.Name)
                                notify("Admin Detected: " .. player.Name)
                            end
                        end
                    end)
                end)
            end
        end)
        createButton(contentFrame, "📜 Show Admin List", function()
            contentFrame:ClearAllChildren()
            for i, admin in ipairs(adminList) do
                createButton(contentFrame, "Admin: " .. admin, function() end)
            end
        end)
        createButton(contentFrame, "👁️ Toggle Spectate", function()
            spectating = not spectating
            if spectating then
                local playerList = Players:GetPlayers()
                spectateIndex = (spectateIndex % #playerList) + 1
                updateSpectate(playerList[spectateIndex])
            else
                updateSpectate(nil)
            end
        end)
        createButton(contentFrame, "⏮️ Previous Player", function()
            if spectating then
                local playerList = Players:GetPlayers()
                spectateIndex = spectateIndex - 1
                if spectateIndex < 1 then spectateIndex = #playerList end
                updateSpectate(playerList[spectateIndex])
            else
                notify("Spectate not active")
            end
        end)
        createButton(contentFrame, "⏭️ Next Player", function()
            if spectating then
                local playerList = Players:GetPlayers()
                spectateIndex = (spectateIndex % #playerList) + 1
                updateSpectate(playerList[spectateIndex])
            else
                notify("Spectate not active")
            end
        end)
        createButton(contentFrame, "🚀 Teleport to Spectated", function()
            if spectating and spectateTarget and spectateTarget.Character and spectateTarget.Character:FindFirstChild("HumanoidRootPart") then
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    LocalPlayer.Character.HumanoidRootPart.CFrame = spectateTarget.Character.HumanoidRootPart.CFrame
                    notify("Teleported to " .. spectateTarget.Name)
                end
            else
                notify("No player being spectated")
            end
        end)
    elseif category == "Misc" then
        createButton(contentFrame, "🛡️ Toggle God Mode", function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                local humanoid = LocalPlayer.Character.Humanoid
                humanoid.MaxHealth = math.huge
                humanoid.Health = math.huge
                notify("God Mode Enabled")
            end
        end)
        createButton(contentFrame, "📊 Toggle Fake Stats", function()
            fakeStatsEnabled = not fakeStatsEnabled
            if fakeStatsEnabled then
                local billboard = Instance.new("BillboardGui", LocalPlayer.Character:FindFirstChild("Head"))
                billboard.Size = UDim2.new(0, 100, 0, 50)
                billboard.StudsOffset = Vector3.new(0, 3, 0)
                local statLabel = Instance.new("TextLabel", billboard)
                statLabel.Size = UDim2.new(1, 0, 1, 0)
                statLabel.BackgroundTransparency = 1
                statLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                statLabel.TextSize = 14
                statLabel.Text = fakeStats[currentStatIndex]
                spawn(function()
                    while fakeStatsEnabled do
                        currentStatIndex = (currentStatIndex % #fakeStats) + 1
                        statLabel.Text = fakeStats[currentStatIndex]
                        wait(3)
                    end
                end)
                notify("Fake Stats Enabled")
            else
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head") then
                    local billboard = LocalPlayer.Character.Head:FindFirstChild("BillboardGui")
                    if billboard then billboard:Destroy() end
                end
                notify("Fake Stats Disabled")
            end
        end)
        createButton(contentFrame, "🎮 Auto-Detect Game Stats", function()
            notify("Game Stats Detection not supported on Android")
        end)
    end
end

-- Initialize
createCategoryButtons()
loadCategoryContent("Movement")