-- Minimalist Roblox Script for Android (Fluxus Optimized)
-- Black theme, compact right-aligned rectangular GUI, draggable, scrollable, logo minimize, disables previous script

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

-- Disable previous script
local function disablePreviousScript()
    local oldGui = LocalPlayer.PlayerGui:FindFirstChild("MinimalistGUI")
    if oldGui then
        oldGui:Destroy()
    end
    -- Reset all feature states
    pcall(function()
        freecamEnabled = false
        wallClimbEnabled = false
        noPlayerCollisionEnabled = false
        freezeBlocksEnabled = false
        fakeStatsEnabled = false
        adminDetectionEnabled = false
        spectating = false
        isNoclip = false
        if LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = 16
                humanoid.JumpPower = 50
                humanoid.MaxHealth = 100
                humanoid.Health = 100
            end
            for _, part in pairs(LocalPlayer.Character:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                    PhysicsService:SetPartCollisionGroup(part, "Default")
                end
            end
            local billboard = LocalPlayer.Character:FindFirstChild("Head") and LocalPlayer.Character.Head:FindFirstChild("BillboardGui")
            if billboard then billboard:Destroy() end
        end
        for _, block in pairs(frozenBlocks) do
            if block.part and block.part.Parent then
                block.part.Anchored = false
                block.part.Velocity = block.originalVelocity
            end
        end
        frozenBlocks = {}
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        Workspace.CurrentCamera.CameraSubject = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    end)
end

disablePreviousScript()

-- Use ScreenGui for Fluxus compatibility
local gui = Instance.new("ScreenGui")
gui.Name = "MinimalistGUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Main Frame (Compact, Right-Aligned, Rectangular)
local mainFrame = Instance.new("Frame", gui)
mainFrame.Size = UDim2.new(0, 300, 0, 200)
mainFrame.Position = UDim2.new(1, -310, 0.5, -100)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.ZIndex = 10

-- Sidebar (Left within Frame)
local sidebar = Instance.new("Frame", mainFrame)
sidebar.Size = UDim2.new(0, 80, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
sidebar.BorderSizePixel = 0
sidebar.ZIndex = 11

-- Content Frame (Right within Frame, Scrollable)
local contentFrame = Instance.new("ScrollingFrame", mainFrame)
contentFrame.Size = UDim2.new(0, 220, 1, 0)
contentFrame.Position = UDim2.new(0, 80, 0, 0)
contentFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
contentFrame.BorderSizePixel = 0
contentFrame.ZIndex = 11
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
contentFrame.ScrollBarThickness = 5
contentFrame.ScrollBarImageColor3 = Color3.fromRGB(50, 50, 50)

-- Watermark with HWID
local hwid = "Unknown"
pcall(function()
    hwid = gethwid and gethwid() or "No HWID"
end)
local watermark = Instance.new("TextLabel", mainFrame)
watermark.Size = UDim2.new(0, 150, 0, 20)
watermark.Position = UDim2.new(1, -155, 0, 5)
watermark.BackgroundTransparency = 1
watermark.Text = "unknown block - farinoveri | " .. hwid
watermark.TextColor3 = Color3.fromRGB(255, 255, 255)
watermark.TextSize = 10
watermark.Font = Enum.Font.SourceSans
watermark.ZIndex = 12

-- Close Button
local closeButton = Instance.new("TextButton", mainFrame)
closeButton.Size = UDim2.new(0, 20, 0, 20)
closeButton.Position = UDim2.new(1, -25, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 14
closeButton.ZIndex = 12
closeButton.MouseButton1Click:Connect(function()
    gui:Destroy()
    disablePreviousScript()
end)

-- Logo Button (UB, Bottom Right)
local logoButton = Instance.new("TextButton")
logoButton.Size = UDim2.new(0, 40, 0, 40)
logoButton.Position = UDim2.new(1, -50, 1, -50)
logoButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
logoButton.Text = "UB"
logoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
logoButton.TextSize = 18
logoButton.Font = Enum.Font.SourceSansBold
logoButton.Parent = gui
logoButton.ZIndex = 10
logoButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

-- Notification System
local function notify(message)
    local notif = Instance.new("TextLabel", gui)
    notif.Size = UDim2.new(0, 150, 0, 25)
    notif.Position = UDim2.new(0.5, -75, 0, 10)
    notif.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    notif.Text = message
    notif.TextColor3 = Color3.fromRGB(255, 255, 255)
    notif.TextSize = 12
    notif.ZIndex = 15
    wait(3)
    notif:Destroy()
end

-- Initialize GUI and handle respawn
local function initializeGui()
    if not gui.Parent then
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        notify("GUI Initialized")
    end
end

initializeGui()
LocalPlayer.CharacterAdded:Connect(initializeGui)
Players.PlayerAdded:Connect(function(player)
    if player == LocalPlayer then
        initializeGui()
    end
end)

-- Category System
local categories = {"Movement", "Teleport", "Player", "Misc"}
local currentCategory = "Movement"

-- Category Buttons
local function createCategoryButtons()
    for i, category in ipairs(categories) do
        local button = Instance.new("TextButton", sidebar)
        button.Size = UDim2.new(1, 0, 0, 25)
        button.Position = UDim2.new(0, 0, 0, (i-1)*25)
        button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        button.Text = category
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 12
        button.ZIndex = 12
        button.MouseButton1Click:Connect(function()
            currentCategory = category
            contentFrame:ClearAllChildren()
            contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
            loadCategoryContent(category)
            notify("Loaded Category: " .. category)
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
local positionCategory = "General"

-- Feature States
local freecamEnabled = false
local lastFreecamPos = nil
local camera = Workspace.CurrentCamera
local adminList = {}
local adminDetectionEnabled = false
local fakeStatsEnabled = false
local fakeStats = {"Kills: 1000", "Level: 99", "Coins: 99999"}
local currentStatIndex = 1
local spectating = false
local spectateTarget = nil
local spectateIndex = 0
local wallClimbEnabled = false
local freezeBlocksEnabled = false
local frozenBlocks = {}
local noPlayerCollisionEnabled = false
local collisionGroupName = "NoPlayerCollision"
local isNoclip = false
local isGodMode = false

-- Setup Collision Group
pcall(function()
    PhysicsService:CreateCollisionGroup(collisionGroupName)
    PhysicsService:CollisionGroupSetCollidable(collisionGroupName, "Default", false)
end)

-- Create Button Helper
local function createButton(parent, text, callback)
    local button = Instance.new("TextButton", parent)
    button.Size = UDim2.new(0, 200, 0, 25)
    button.Position = UDim2.new(0, 10, 0, (#parent:GetChildren() * 30))
    button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 12
    button.ZIndex = 12
    button.MouseButton1Click:Connect(callback)
    parent.CanvasSize = UDim2.new(0, 0, 0, (#parent:GetChildren() * 30) + 30)
end

-- Spectate Function
local function updateSpectate(target)
    if spectating and target and target.Character and target.Character:FindFirstChild("Humanoid") then
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
    contentFrame:ClearAllChildren()
    contentFrame.CanvasPosition = Vector2.new(0, 0) -- Reset scroll position
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- Reset canvas size
    if category == "Movement" then
        createButton(contentFrame, freecamEnabled and "🛫 Fly/Freecam: ON" or "🛫 Fly/Freecam: OFF", function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                freecamEnabled = not freecamEnabled
                wallClimbEnabled = false
                noPlayerCollisionEnabled = false
                isNoclip = false
                if freecamEnabled then
                    lastFreecamPos = LocalPlayer.Character.HumanoidRootPart.Position
                    camera.CameraType = Enum.CameraType.Scriptable
                    notify("Fly/Freecam Enabled")
                    RunService.RenderStepped:Connect(function()
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
                            camera.CFrame = camera.CFrame + moveVector * RunService.Heartbeat:Wait()
                        end
                    end)
                else
                    camera.CameraType = Enum.CameraType.Custom
                    camera.CameraSubject = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
                    notify("Fly/Freecam Disabled")
                end
            end
            loadCategoryContent("Movement")
        end)
        createButton(contentFrame, LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.WalkSpeed == 100 and "🏃 Speed: ON" or "🏃 Speed: OFF", function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                local humanoid = LocalPlayer.Character.Humanoid
                humanoid.WalkSpeed = humanoid.WalkSpeed == 16 and 100 or 16
                notify(humanoid.WalkSpeed == 100 and "Speed Enabled" or "Speed Disabled")
            end
            loadCategoryContent("Movement")
        end)
        createButton(contentFrame, LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") and LocalPlayer.Character.Humanoid.JumpPower == 100 and "🦘 Jump Power: ON" or "🦘 Jump Power: OFF", function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                local humanoid = LocalPlayer.Character.Humanoid
                humanoid.JumpPower = humanoid.JumpPower == 50 and 100 or 50
                notify(humanoid.JumpPower == 100 and "Jump Power Enabled" or "Jump Power Disabled")
            end
            loadCategoryContent("Movement")
        end)
        createButton(contentFrame, isNoclip and "🚪 Noclip: ON" or "🚪 Noclip: OFF", function()
            isNoclip = not isNoclip
            wallClimbEnabled = false
            noPlayerCollisionEnabled = false
            notify(isNoclip and "Noclip Enabled" or "Noclip Disabled")
            RunService.Stepped:Connect(function()
                if isNoclip and LocalPlayer.Character then
                    for _, part in pairs(LocalPlayer.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            end)
            loadCategoryContent("Movement")
        end)
        createButton(contentFrame, wallClimbEnabled and "🕸️ Wall Climb: ON" or "🕸️ Wall Climb: OFF", function()
            wallClimbEnabled = not wallClimbEnabled
            noPlayerCollisionEnabled = false
            isNoclip = false
            notify(wallClimbEnabled and "Wall Climb Enabled" or "Wall Climb Disabled")
            if wallClimbEnabled then
                RunService.Stepped:Connect(function()
                    if wallClimbEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = LocalPlayer.Character.HumanoidRootPart
                        local ray = Ray.new(hrp.Position, hrp.CFrame.LookVector * 2)
                        local hit, pos = Workspace:FindPartOnRay(ray, LocalPlayer.Character)
                        if hit and UserInputService:IsKeyDown(Enum.KeyCode.W) then
                            hrp.Velocity = Vector3.new(0, 50, 0)
                        end
                    end
                end)
            end
            loadCategoryContent("Movement")
        end)
        createButton(contentFrame, noPlayerCollisionEnabled and "👻 No Player Collision: ON" or "👻 No Player Collision: OFF", function()
            noPlayerCollisionEnabled = not noPlayerCollisionEnabled
            wallClimbEnabled = false
            isNoclip = false
            if noPlayerCollisionEnabled then
                if LocalPlayer.Character then
                    for _, part in pairs(LocalPlayer.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            pcall(function()
                                PhysicsService:SetPartCollisionGroup(part, collisionGroupName)
                            end)
                        end
                    end
                end
                notify("No Player Collision Enabled")
            else
                if LocalPlayer.Character then
                    for _, part in pairs(LocalPlayer.Character:GetChildren()) do
                        if part:IsA("BasePart") then
                            pcall(function()
                                PhysicsService:SetPartCollisionGroup(part, "Default")
                            end)
                        end
                    end
                end
                notify("No Player Collision Disabled")
            end
            loadCategoryContent("Movement")
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
            categoryDropdown.Size = UDim2.new(0, 200, 0, 25)
            categoryDropdown.Position = UDim2.new(0, 10, 0, 0)
            categoryDropdown.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            categoryDropdown.Text = "Category: " .. positionCategory
            categoryDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
            categoryDropdown.TextSize = 12
            categoryDropdown.ZIndex = 12
            categoryDropdown.MouseButton1Click:Connect(function()
                local catList = {"General", "Spawn", "Checkpoint", "Important", "Custom"}
                local index = table.find(catList, positionCategory) or 1
                positionCategory = catList[(index % #catList) + 1]
                categoryDropdown.Text = "Category: " .. positionCategory
                loadCategoryContent("Teleport")
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
                catButton.Size = UDim2.new(0, 200, 0, 25)
                catButton.Position = UDim2.new(0, 10, 0, #contentFrame:GetChildren() * 30)
                catButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                catButton.Text = cat .. " (" .. #positions .. ")"
                catButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                catButton.TextSize = 12
                catButton.ZIndex = 12
                catButton.MouseButton1Click:Connect(function()
                    collapsed = not collapsed
                    contentFrame:ClearAllChildren()
                    if not collapsed then
                        for i, posData in ipairs(positions) do
                            local posFrame = Instance.new("Frame", contentFrame)
                            posFrame.Size = UDim2.new(0, 200, 0, 25)
                            posFrame.Position = UDim2.new(0, 10, 0, #contentFrame:GetChildren() * 30)
                            posFrame.BackgroundTransparency = 1
                            posFrame.ZIndex = 12
                            local goButton = Instance.new("TextButton", posFrame)
                            goButton.Size = UDim2.new(0, 140, 0, 25)
                            goButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                            goButton.Text = posData.name
                            goButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                            goButton.TextSize = 12
                            goButton.ZIndex = 12
                            goButton.MouseButton1Click:Connect(function()
                                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                    LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(posData.pos)
                                    notify("Teleported to " .. posData.name)
                                end
                            end)
                            local renameButton = Instance.new("TextButton", posFrame)
                            renameButton.Size = UDim2.new(0, 30, 0, 25)
                            renameButton.Position = UDim2.new(0, 145, 0, 0)
                            renameButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                            renameButton.Text = "Ren"
                            renameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                            renameButton.TextSize = 10
                            renameButton.ZIndex = 12
                            renameButton.MouseButton1Click:Connect(function()
                                posData.name = "Renamed Pos " .. i
                                notify("Renamed to " .. posData.name)
                            end)
                            local deleteButton = Instance.new("TextButton", posFrame)
                            deleteButton.Size = UDim2.new(0, 30, 0, 25)
                            deleteButton.Position = UDim2.new(0, 180, 0, 0)
                            deleteButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
                            deleteButton.Text = "Del"
                            deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                            deleteButton.TextSize = 10
                            deleteButton.ZIndex = 12
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
            notify("Auto Teleport Completed")
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
        createButton(contentFrame, adminDetectionEnabled and "🛡️ Admin Detection: ON" or "🛡️ Admin Detection: OFF", function()
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
            loadCategoryContent("Player")
        end)
        createButton(contentFrame, "📜 Show Admin List", function()
            contentFrame:ClearAllChildren()
            for i, admin in ipairs(adminList) do
                createButton(contentFrame, "Admin: " .. admin, function() end)
            end
        end)
        createButton(contentFrame, spectating and "👁️ Spectate: ON" or "👁️ Spectate: OFF", function()
            spectating = not spectating
            if spectating then
                local playerList = Players:GetPlayers()
                spectateIndex = (spectateIndex % #playerList) + 1
                updateSpectate(playerList[spectateIndex])
            else
                updateSpectate(nil)
            end
            loadCategoryContent("Player")
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
        createButton(contentFrame, isGodMode and "🛡️ God Mode: ON" or "🛡️ God Mode: OFF", function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                local humanoid = LocalPlayer.Character.Humanoid
                isGodMode = not isGodMode
                if isGodMode then
                    humanoid.MaxHealth = math.huge
                    humanoid.Health = math.huge
                    notify("God Mode Enabled")
                else
                    humanoid.MaxHealth = 100
                    humanoid.Health = 100
                    notify("God Mode Disabled")
                end
            end
            loadCategoryContent("Misc")
        end)
        createButton(contentFrame, fakeStatsEnabled and "📊 Fake Stats: ON" or "📊 Fake Stats: OFF", function()
            fakeStatsEnabled = not fakeStatsEnabled
            if fakeStatsEnabled then
                local billboard = Instance.new("BillboardGui", LocalPlayer.Character:FindFirstChild("Head"))
                billboard.Size = UDim2.new(0, 100, 0, 50)
                billboard.StudsOffset = Vector3.new(0, 3, 0)
                billboard.ZIndex = 10
                local statLabel = Instance.new("TextLabel", billboard)
                statLabel.Size = UDim2.new(1, 0, 1, 0)
                statLabel.BackgroundTransparency = 1
                statLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                statLabel.TextSize = 14
                statLabel.Text = fakeStats[currentStatIndex]
                statLabel.ZIndex = 10
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
            loadCategoryContent("Misc")
        end)
        createButton(contentFrame, freezeBlocksEnabled and "🧊 Freeze Blocks: ON" or "🧊 Freeze Blocks: OFF", function()
            freezeBlocksEnabled = not freezeBlocksEnabled
            if freezeBlocksEnabled then
                for _, obj in pairs(Workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and not obj.Anchored and obj.Velocity.Magnitude > 0 then
                        table.insert(frozenBlocks, {part = obj, originalVelocity = obj.Velocity})
                        obj.Velocity = Vector3.new(0, 0, 0)
                        obj.Anchored = true
                    end
                end
                notify("Moving Blocks Frozen")
            else
                for _, block in pairs(frozenBlocks) do
                    if block.part and block.part.Parent then
                        block.part.Anchored = false
                        block.part.Velocity = block.originalVelocity
                    end
                end
                frozenBlocks = {}
                notify("Moving Blocks Unfrozen")
            end
            loadCategoryContent("Misc")
        end)
    end
end

-- Initialize
createCategoryButtons()
loadCategoryContent("Movement")
notify("Script Initialized")