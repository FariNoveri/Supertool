local Player = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character, humanoid, rootPart

local selectedPlayer = nil
local spectating = false
local following = false
local followTarget = nil
local connections = {}

local antiAFKEnabled = false
local fastRespawnEnabled = false
local noDeathAnimationEnabled = false
local physicsEnabled = false
local magnetEnabled = false
local flingEnabled = false

local physicsPlayers = {}
local frozenPlayers = {}
local flungPlayers = {}

local playerListFrame
local playerListVisible = false
local spectateButtons = {}
local playerListItems = {}

local function initCharacter()
    character = player.Character or player.CharacterAdded:Wait()
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
end

local function notify(title, message)
    if Player.Fluent then
        Player.Fluent:Notify({
            Title = title,
            Content = message,
            Duration = 3
        })
    end
end

local function getPlayerList()
    local players = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            table.insert(players, p.Name)
        end
    end
    return players
end

local function findPlayer(name)
    if not name then return nil end
    local lowerName = string.lower(name)
    for _, p in pairs(Players:GetPlayers()) do
        if string.lower(p.Name):find(lowerName) or string.lower(p.DisplayName):find(lowerName) then
            return p
        end
    end
    return nil
end

local function toggleGodMode(enabled)
    if enabled then
        if humanoid then
            humanoid.MaxHealth = math.huge
            humanoid.Health = math.huge
        end
    else
        if humanoid then
            humanoid.MaxHealth = 100
            humanoid.Health = 100
        end
    end
end

local function toggleInvisible(enabled)
    if not character then return end
    
    if enabled then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("Decal") then
                part.Transparency = 1
            elseif part:IsA("Accessory") then
                local handle = part:FindFirstChild("Handle")
                if handle then
                    handle.Transparency = 1
                end
            end
        end
        if character:FindFirstChild("Head") then
            local face = character.Head:FindFirstChild("face")
            if face then
                face.Transparency = 1
            end
        end
    else
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0
            elseif part:IsA("Decal") then
                part.Transparency = 0
            elseif part:IsA("Accessory") then
                local handle = part:FindFirstChild("Handle")
                if handle then
                    handle.Transparency = 0
                end
            end
        end
        if character:FindFirstChild("Head") then
            local face = character.Head:FindFirstChild("face")
            if face then
                face.Transparency = 0
            end
        end
    end
end

local function teleportToPlayer(targetPlayer)
    if not targetPlayer or not rootPart then return end
    
    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        rootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
        notify("Teleport", "Teleported to " .. targetPlayer.Name)
    end
end

local function bringPlayer(targetPlayer)
    if not targetPlayer or not rootPart then return end
    
    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local targetRoot = targetPlayer.Character.HumanoidRootPart
        targetRoot:SetNetworkOwner(player)
        targetRoot.CFrame = rootPart.CFrame * CFrame.new(0, 0, -3)
        
        task.delay(0.5, function()
            targetRoot:SetNetworkOwner(nil)
        end)
        
        notify("Bring", "Brought " .. targetPlayer.Name)
    end
end

local function spectatePlayer(targetPlayer)
    if connections.spectate then
        connections.spectate:Disconnect()
        connections.spectate = nil
    end
    
    if not targetPlayer then
        Workspace.CurrentCamera.CameraSubject = humanoid
        spectating = false
        selectedPlayer = nil
        notify("Spectate", "Stopped spectating")
        return
    end
    
    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
        Workspace.CurrentCamera.CameraSubject = targetPlayer.Character.Humanoid
        spectating = true
        selectedPlayer = targetPlayer
        
        connections.spectate = targetPlayer.CharacterAdded:Connect(function(newChar)
            local newHum = newChar:WaitForChild("Humanoid")
            if spectating and selectedPlayer == targetPlayer then
                Workspace.CurrentCamera.CameraSubject = newHum
            end
        end)
        
        notify("Spectate", "Spectating " .. targetPlayer.Name)
    end
end

local function followPlayer(targetPlayer)
    if connections.follow then
        connections.follow:Disconnect()
        connections.follow = nil
    end
    
    if not targetPlayer then
        following = false
        followTarget = nil
        notify("Follow", "Stopped following")
        return
    end
    
    following = true
    followTarget = targetPlayer
    
    connections.follow = RunService.Heartbeat:Connect(function()
        if not following or not followTarget then return end
        if not humanoid or not rootPart then return end
        
        if followTarget.Character and followTarget.Character:FindFirstChild("HumanoidRootPart") then
            local targetPos = followTarget.Character.HumanoidRootPart.Position
            humanoid:MoveTo(targetPos)
        end
    end)
    
    notify("Follow", "Following " .. targetPlayer.Name)
end

local function killPlayer(targetPlayer)
    if not targetPlayer then return end
    
    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
        targetPlayer.Character.Humanoid.Health = 0
        notify("Kill", "Killed " .. targetPlayer.Name)
    end
end

local function flingPlayer(targetPlayer)
    if not targetPlayer or not rootPart then return end
    
    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local targetRoot = targetPlayer.Character.HumanoidRootPart
        targetRoot:SetNetworkOwner(player)
        
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bodyVelocity.Velocity = Vector3.new(0, 10000, 0)
        bodyVelocity.Parent = targetRoot
        
        task.delay(0.1, function()
            bodyVelocity:Destroy()
            targetRoot:SetNetworkOwner(nil)
        end)
        
        notify("Fling", "Flinged " .. targetPlayer.Name)
    end
end

local function freezePlayer(targetPlayer, enabled)
    if not targetPlayer then return end
    
    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local targetRoot = targetPlayer.Character.HumanoidRootPart
        
        if enabled then
            targetRoot.Anchored = true
            notify("Freeze", "Froze " .. targetPlayer.Name)
        else
            targetRoot.Anchored = false
            notify("Freeze", "Unfroze " .. targetPlayer.Name)
        end
    end
end

local function removeAccessories()
    if not character then return end
    
    for _, accessory in pairs(character:GetChildren()) do
        if accessory:IsA("Accessory") then
            accessory:Destroy()
        end
    end
    notify("Accessories", "Removed all accessories")
end

local function removeLimbs()
    if not character then return end
    
    for _, limb in pairs(character:GetChildren()) do
        if limb:IsA("BasePart") and limb.Name ~= "HumanoidRootPart" and limb.Name ~= "Head" then
            limb:Destroy()
        end
    end
    notify("Limbs", "Removed limbs")
end

local function resetCharacter()
    if character then
        character:BreakJoints()
        notify("Reset", "Character reset")
    end
end

local function sitStand()
    if humanoid then
        humanoid.Sit = not humanoid.Sit
        notify("Sit/Stand", humanoid.Sit and "Sitting" or "Standing")
    end
end

local function toggleAntiAFK(enabled)
    antiAFKEnabled = enabled
    
    if connections.antiAFK then
        connections.antiAFK:Disconnect()
        connections.antiAFK = nil
    end
    
    if enabled then
        connections.antiAFK = player.Idled:Connect(function()
            local VirtualUser = game:GetService("VirtualUser")
            VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
            VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
        end)
        notify("Anti-AFK", "Enabled")
    end
end

local function toggleFastRespawn(enabled)
    fastRespawnEnabled = enabled
    
    if connections.fastRespawn then
        connections.fastRespawn:Disconnect()
        connections.fastRespawn = nil
    end
    
    if enabled then
        connections.fastRespawn = player.CharacterRemoving:Connect(function()
            task.spawn(function()
                task.wait(0.1)
                player:LoadCharacter()
            end)
        end)
        notify("Fast Respawn", "Enabled")
    end
end

local function toggleNoDeathAnimation(enabled)
    noDeathAnimationEnabled = enabled
    
    if connections.noDeathAnim then
        connections.noDeathAnim:Disconnect()
        connections.noDeathAnim = nil
    end
    
    if enabled then
        local function setupNoDeath(char)
            local hum = char:WaitForChild("Humanoid")
            hum.Died:Connect(function()
                for _, sound in pairs(char:GetDescendants()) do
                    if sound:IsA("Sound") then
                        sound:Stop()
                        sound.Volume = 0
                    end
                end
                
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") or part:IsA("Decal") then
                        part.Transparency = 1
                    end
                end
                
                local animator = hum:FindFirstChild("Animator")
                if animator then
                    for _, track in pairs(animator:GetPlayingAnimationTracks()) do
                        track:Stop()
                    end
                end
            end)
        end
        
        if character then
            setupNoDeath(character)
        end
        
        connections.noDeathAnim = player.CharacterAdded:Connect(setupNoDeath)
        notify("No Death Animation", "Enabled")
    end
end

local function enablePhysicsForPlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then return end
    if not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local char = targetPlayer.Character
    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    
    if not hum or not root then return end
    
    root:SetNetworkOwner(player)
    root.Anchored = false
    root.CanCollide = true
    
    hum:ChangeState(Enum.HumanoidStateType.Physics)
    hum.WalkSpeed = 0
    hum.JumpPower = 0
    hum.HipHeight = 0
    
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part ~= root then
            part.Anchored = false
            part.CanCollide = true
        end
    end
    
    physicsPlayers[targetPlayer] = {
        humanoid = hum,
        rootPart = root,
        character = char
    }
end

local function disablePhysicsForPlayer(targetPlayer)
    if not physicsPlayers[targetPlayer] then return end
    
    local data = physicsPlayers[targetPlayer]
    if data.humanoid and data.humanoid.Parent then
        data.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        data.humanoid.WalkSpeed = 16
        data.humanoid.JumpPower = 50
        data.humanoid.HipHeight = 2
    end
    
    if data.rootPart then
        data.rootPart:SetNetworkOwner(nil)
    end
    
    physicsPlayers[targetPlayer] = nil
end

local function togglePhysicsControl(enabled)
    physicsEnabled = enabled
    
    if connections.physics then
        connections.physics:Disconnect()
        connections.physics = nil
    end
    
    if enabled then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player then
                enablePhysicsForPlayer(p)
            end
        end
        
        connections.physics = Players.PlayerAdded:Connect(function(newPlayer)
            if physicsEnabled and newPlayer ~= player then
                newPlayer.CharacterAdded:Connect(function()
                    task.wait(0.5)
                    enablePhysicsForPlayer(newPlayer)
                end)
            end
        end)
        
        notify("Physics Control", "Enabled")
    else
        for targetPlayer, _ in pairs(physicsPlayers) do
            disablePhysicsForPlayer(targetPlayer)
        end
        physicsPlayers = {}
    end
end

local function toggleMagnetPlayers(enabled)
    magnetEnabled = enabled
    
    if connections.magnet then
        connections.magnet:Disconnect()
        connections.magnet = nil
    end
    
    if enabled then
        connections.magnet = RunService.RenderStepped:Connect(function()
            if not magnetEnabled or not rootPart then return end
            
            local ourCFrame = rootPart.CFrame
            for _, targetPlayer in pairs(Players:GetPlayers()) do
                if targetPlayer ~= player and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = targetPlayer.Character.HumanoidRootPart
                    local targetPosition = (ourCFrame * CFrame.new(0, 0, -5)).Position
                    hrp.CFrame = CFrame.new(targetPosition) * ourCFrame.Rotation
                end
            end
        end)
        
        notify("Magnet Players", "Enabled")
    end
end

local function toggleFlingMode(enabled)
    flingEnabled = enabled
    
    if connections.fling then
        connections.fling:Disconnect()
        connections.fling = nil
    end
    
    if enabled then
        connections.fling = RunService.Heartbeat:Connect(function()
            if not flingEnabled or not rootPart then return end
            
            local ourBodyAngularVel = rootPart:FindFirstChild("FlingSpinVel")
            if not ourBodyAngularVel then
                ourBodyAngularVel = Instance.new("BodyAngularVelocity")
                ourBodyAngularVel.Name = "FlingSpinVel"
                ourBodyAngularVel.AngularVelocity = Vector3.new(0, 75, 0)
                ourBodyAngularVel.MaxTorque = Vector3.new(0, math.huge, 0)
                ourBodyAngularVel.Parent = rootPart
            end
            
            for _, targetPlayer in pairs(Players:GetPlayers()) do
                if targetPlayer ~= player and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local targetRoot = targetPlayer.Character.HumanoidRootPart
                    local distance = (rootPart.Position - targetRoot.Position).Magnitude
                    
                    if distance <= 10 then
                        targetRoot:SetNetworkOwner(player)
                        enablePhysicsForPlayer(targetPlayer)
                        
                        if not flungPlayers[targetPlayer] then
                            flungPlayers[targetPlayer] = true
                        end
                        
                        local direction = (targetRoot.Position - rootPart.Position).Unit
                        local flingVelocity = direction * 80 * 1.2
                        flingVelocity = flingVelocity + Vector3.new(0, 48, 0)
                        
                        targetRoot.Anchored = false
                        targetRoot.AssemblyLinearVelocity = flingVelocity
                        
                        local targetBodyAngularVel = targetRoot:FindFirstChild("TargetSpinVel")
                        if not targetBodyAngularVel then
                            targetBodyAngularVel = Instance.new("BodyAngularVelocity")
                            targetBodyAngularVel.Name = "TargetSpinVel"
                            targetBodyAngularVel.AngularVelocity = Vector3.new(
                                math.random(-100, 100),
                                math.random(-100, 100),
                                math.random(-100, 100)
                            )
                            targetBodyAngularVel.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                            targetBodyAngularVel.Parent = targetRoot
                        end
                    else
                        if flungPlayers[targetPlayer] then
                            local targetBodyAngularVel = targetRoot:FindFirstChild("TargetSpinVel")
                            if targetBodyAngularVel then
                                targetBodyAngularVel:Destroy()
                            end
                            
                            local targetHumanoid = targetPlayer.Character:FindFirstChild("Humanoid")
                            if targetHumanoid then
                                targetHumanoid.PlatformStand = false
                                targetHumanoid.WalkSpeed = 16
                                targetHumanoid.JumpPower = 50
                            end
                            if targetRoot then
                                targetRoot:SetNetworkOwner(nil)
                            end
                            disablePhysicsForPlayer(targetPlayer)
                            flungPlayers[targetPlayer] = nil
                        end
                    end
                end
            end
        end)
        
        notify("Fling Mode", "Enabled")
    else
        if rootPart then
            local ourSpinVel = rootPart:FindFirstChild("FlingSpinVel")
            if ourSpinVel then
                ourSpinVel:Destroy()
            end
        end
        
        for targetPlayer, _ in pairs(flungPlayers) do
            if targetPlayer.Character then
                local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetRoot then
                    local targetBodyAngularVel = targetRoot:FindFirstChild("TargetSpinVel")
                    if targetBodyAngularVel then
                        targetBodyAngularVel:Destroy()
                    end
                    targetRoot:SetNetworkOwner(nil)
                end
                
                local targetHumanoid = targetPlayer.Character:FindFirstChild("Humanoid")
                if targetHumanoid then
                    targetHumanoid.PlatformStand = false
                    targetHumanoid.WalkSpeed = 16
                    targetHumanoid.JumpPower = 50
                end
                
                disablePhysicsForPlayer(targetPlayer)
            end
        end
        flungPlayers = {}
    end
end

local function freezeAllPlayers(enabled)
    if connections.freezePlayers then
        connections.freezePlayers:Disconnect()
        connections.freezePlayers = nil
    end
    
    if enabled then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                frozenPlayers[p] = p.Character.HumanoidRootPart.CFrame
            end
        end
        
        connections.freezePlayers = RunService.RenderStepped:Connect(function()
            for targetPlayer, frozenCFrame in pairs(frozenPlayers) do
                if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    targetPlayer.Character.HumanoidRootPart.CFrame = frozenCFrame
                end
            end
        end)
        
        notify("Freeze Players", "All players frozen")
    else
        frozenPlayers = {}
    end
end

local function morphToPlayer(targetPlayer)
    if not targetPlayer then return end
    
    local success = pcall(function()
        local targetDescription = Players:GetHumanoidDescriptionFromUserId(targetPlayer.UserId)
        if humanoid then
            humanoid:ApplyDescription(targetDescription)
            notify("Morph", "Morphed to " .. targetPlayer.Name)
        end
    end)
    
    if not success then
        notify("Morph", "Failed to morph")
    end
end

local function clonePlayer(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    
    local success = pcall(function()
        local clone = targetPlayer.Character:Clone()
        clone.Name = targetPlayer.Name .. "_Clone"
        clone.Parent = Workspace
        
        if clone:FindFirstChild("HumanoidRootPart") then
            clone.HumanoidRootPart.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(3, 0, 0)
        end
        
        if clone:FindFirstChild("Humanoid") then
            clone.Humanoid:Destroy()
        end
        
        for _, script in pairs(clone:GetDescendants()) do
            if script:IsA("Script") or script:IsA("LocalScript") then
                script:Destroy()
            end
        end
        
        notify("Clone", "Cloned " .. targetPlayer.Name)
    end)
    
    if not success then
        notify("Clone", "Failed to clone")
    end
end

local function createPlayerListGUI()
    local ScreenGui = player.PlayerGui:FindFirstChild("PlayerListGUI")
    if ScreenGui then
        ScreenGui:Destroy()
    end
    
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PlayerListGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = player.PlayerGui
    
    playerListFrame = Instance.new("Frame")
    playerListFrame.Name = "PlayerListFrame"
    playerListFrame.Size = UDim2.new(0, 300, 0, 400)
    playerListFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
    playerListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    playerListFrame.BorderSizePixel = 0
    playerListFrame.Visible = false
    playerListFrame.Active = true
    playerListFrame.Draggable = true
    playerListFrame.Parent = ScreenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = playerListFrame
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 35)
    title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    title.BorderSizePixel = 0
    title.Text = "PLAYER LIST"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = playerListFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = title
    
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 2.5)
    closeButton.BackgroundTransparency = 1
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 16
    closeButton.Parent = playerListFrame
    
    closeButton.MouseButton1Click:Connect(function()
        playerListFrame.Visible = false
        playerListVisible = false
    end)
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -10, 1, -45)
    scrollFrame.Position = UDim2.new(0, 5, 0, 40)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.BorderSizePixel = 0
    scrollFrame.Parent = playerListFrame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 5)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = scrollFrame
    
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
    end)
    
    local function updatePlayerList()
        for _, item in pairs(scrollFrame:GetChildren()) do
            if item:IsA("Frame") then
                item:Destroy()
            end
        end
        
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player then
                local playerItem = Instance.new("Frame")
                playerItem.Size = UDim2.new(1, -5, 0, 100)
                playerItem.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                playerItem.BorderSizePixel = 0
                playerItem.Parent = scrollFrame
                
                local itemCorner = Instance.new("UICorner")
                itemCorner.CornerRadius = UDim.new(0, 6)
                itemCorner.Parent = playerItem
                
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Size = UDim2.new(1, -10, 0, 20)
                nameLabel.Position = UDim2.new(0, 5, 0, 5)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = p.DisplayName .. " (@" .. p.Name .. ")"
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                nameLabel.Font = Enum.Font.GothamBold
                nameLabel.TextSize = 11
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.Parent = playerItem
                
                local buttonLayout = Instance.new("UIGridLayout")
                buttonLayout.CellSize = UDim2.new(0.48, 0, 0, 22)
                buttonLayout.CellPadding = UDim2.new(0.04, 0, 0, 3)
                buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
                buttonLayout.Parent = playerItem
                
                local buttonContainer = Instance.new("Frame")
                buttonContainer.Size = UDim2.new(1, -10, 1, -30)
                buttonContainer.Position = UDim2.new(0, 5, 0, 28)
                buttonContainer.BackgroundTransparency = 1
                buttonContainer.Parent = playerItem
                
                buttonLayout.Parent = buttonContainer
                
                local buttons = {
                    {text = "TP", callback = function() teleportToPlayer(p) end},
                    {text = "Bring", callback = function() bringPlayer(p) end},
                    {text = "Spectate", callback = function() spectatePlayer(p) end},
                    {text = "Follow", callback = function() followPlayer(p) end},
                    {text = "Kill", callback = function() killPlayer(p) end},
                    {text = "Fling", callback = function() flingPlayer(p) end},
                    {text = "Freeze", callback = function() freezePlayer(p, true) end},
                    {text = "Unfreeze", callback = function() freezePlayer(p, false) end}
                }
                
                for i, btnData in ipairs(buttons) do
                    local btn = Instance.new("TextButton")
                    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                    btn.BorderSizePixel = 0
                    btn.Text = btnData.text
                    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    btn.Font = Enum.Font.Gotham
                    btn.TextSize = 10
                    btn.LayoutOrder = i
                    btn.Parent = buttonContainer
                    
                    local btnCorner = Instance.new("UICorner")
                    btnCorner.CornerRadius = UDim.new(0, 4)
                    btnCorner.Parent = btn
                    
                    btn.MouseButton1Click:Connect(btnData.callback)
                    
                    btn.MouseEnter:Connect(function()
                        btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
                    end)
                    
                    btn.MouseLeave:Connect(function()
                        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                    end)
                end
            end
        end
    end
    
    updatePlayerList()
    
    Players.PlayerAdded:Connect(function()
        task.wait(1)
        updatePlayerList()
    end)
    
    Players.PlayerRemoving:Connect(function()
        task.wait(0.5)
        updatePlayerList()
    end)
end

function Player.init(tab, deps)
    if not tab or not deps then
        warn("Player: Missing tab or dependencies")
        return false
    end
    
    Player.Fluent = deps.Fluent
    Player.Window = deps.Window
    
    initCharacter()
    player.CharacterAdded:Connect(initCharacter)
    createPlayerListGUI()
    
    local PlayerSection = tab:AddSection("Player Controls")
    
    tab:AddToggle("GodModeToggle", {
        Title = "God Mode",
        Description = "Infinite health",
        Default = false,
        Callback = function(Value)
            toggleGodMode(Value)
        end
    })
    
    tab:AddToggle("InvisibleToggle", {
        Title = "Invisible",
        Description = "Make yourself invisible",
        Default = false,
        Callback = function(Value)
            toggleInvisible(Value)
        end
    })
    
    tab:AddToggle("AntiAFKToggle", {
        Title = "Anti-AFK",
        Description = "Prevent being kicked for inactivity",
        Default = false,
        Callback = function(Value)
            toggleAntiAFK(Value)
        end
    })
    
    tab:AddToggle("FastRespawnToggle", {
        Title = "Fast Respawn",
        Description = "Respawn instantly when you die",
        Default = false,
        Callback = function(Value)
            toggleFastRespawn(Value)
        end
    })
    
    tab:AddToggle("NoDeathAnimToggle", {
        Title = "No Death Animation",
        Description = "Skip death animation and sounds",
        Default = false,
        Callback = function(Value)
            toggleNoDeathAnimation(Value)
        end
    })
    
    tab:AddButton({
        Title = "Remove Accessories",
        Description = "Remove all accessories",
        Callback = function()
            removeAccessories()
        end
    })
    
    tab:AddButton({
        Title = "Remove Limbs",
        Description = "Remove all limbs",
        Callback = function()
            removeLimbs()
        end
    })
    
    tab:AddButton({
        Title = "Reset Character",
        Description = "Respawn character",
        Callback = function()
            resetCharacter()
        end
    })
    
    tab:AddButton({
        Title = "Sit/Stand",
        Description = "Toggle sitting",
        Callback = function()
            sitStand()
        end
    })
    
    local OtherPlayersSection = tab:AddSection("Other Players")
    
    tab:AddButton({
        Title = "Open Player List",
        Description = "Show player list with actions",
        Callback = function()
            if playerListFrame then
                playerListFrame.Visible = not playerListFrame.Visible
                playerListVisible = playerListFrame.Visible
            end
        end
    })
    
    local PlayerDropdown = tab:AddDropdown("PlayerSelect", {
        Title = "Select Player",
        Description = "Choose a player",
        Values = getPlayerList(),
        Multi = false,
        Default = 1,
        Callback = function(Value)
            selectedPlayer = findPlayer(Value)
        end
    })
    
    tab:AddButton({
        Title = "Refresh Players",
        Description = "Update player list",
        Callback = function()
            PlayerDropdown:SetValues(getPlayerList())
            notify("Players", "Player list refreshed")
        end
    })
    
    tab:AddButton({
        Title = "Teleport to Player",
        Description = "Teleport to selected player",
        Callback = function()
            if selectedPlayer then
                teleportToPlayer(selectedPlayer)
            else
                notify("Error", "No player selected")
            end
        end
    })
    
    tab:AddButton({
        Title = "Bring Player",
        Description = "Bring selected player to you",
        Callback = function()
            if selectedPlayer then
                bringPlayer(selectedPlayer)
            else
                notify("Error", "No player selected")
            end
        end
    })
    
    tab:AddButton({
        Title = "Spectate Player",
        Description = "Spectate selected player",
        Callback = function()
            if selectedPlayer then
                spectatePlayer(selectedPlayer)
            else
                notify("Error", "No player selected")
            end
        end
    })
    
    tab:AddButton({
        Title = "Stop Spectate",
        Description = "Stop spectating",
        Callback = function()
            spectatePlayer(nil)
        end
    })
    
    tab:AddButton({
        Title = "Follow Player",
        Description = "Follow selected player",
        Callback = function()
            if selectedPlayer then
                followPlayer(selectedPlayer)
            else
                notify("Error", "No player selected")
            end
        end
    })
    
    tab:AddButton({
        Title = "Stop Follow",
        Description = "Stop following",
        Callback = function()
            followPlayer(nil)
        end
    })
    
    tab:AddButton({
        Title = "Kill Player",
        Description = "Kill selected player",
        Callback = function()
            if selectedPlayer then
                killPlayer(selectedPlayer)
            else
                notify("Error", "No player selected")
            end
        end
    })
    
    tab:AddButton({
        Title = "Fling Player",
        Description = "Fling selected player",
        Callback = function()
            if selectedPlayer then
                flingPlayer(selectedPlayer)
            else
                notify("Error", "No player selected")
            end
        end
    })
    
    tab:AddButton({
        Title = "Freeze Player",
        Description = "Freeze selected player",
        Callback = function()
            if selectedPlayer then
                freezePlayer(selectedPlayer, true)
            else
                notify("Error", "No player selected")
            end
        end
    })
    
    tab:AddButton({
        Title = "Unfreeze Player",
        Description = "Unfreeze selected player",
        Callback = function()
            if selectedPlayer then
                freezePlayer(selectedPlayer, false)
            else
                notify("Error", "No player selected")
            end
        end
    })
    
    tab:AddButton({
        Title = "Morph to Player",
        Description = "Copy selected player's appearance",
        Callback = function()
            if selectedPlayer then
                morphToPlayer(selectedPlayer)
            else
                notify("Error", "No player selected")
            end
        end
    })
    
    tab:AddButton({
        Title = "Clone Player",
        Description = "Create a clone of selected player",
        Callback = function()
            if selectedPlayer then
                clonePlayer(selectedPlayer)
            else
                notify("Error", "No player selected")
            end
        end
    })
    
    tab:AddButton({
        Title = "Clone Me",
        Description = "Create a clone of yourself",
        Callback = function()
            clonePlayer(player)
        end
    })
    
    local AllPlayersSection = tab:AddSection("All Players Controls")
    
    tab:AddToggle("PhysicsControlToggle", {
        Title = "Physics Control",
        Description = "Take physics control of all players",
        Default = false,
        Callback = function(Value)
            togglePhysicsControl(Value)
        end
    })
    
    tab:AddToggle("MagnetPlayersToggle", {
        Title = "Magnet Players",
        Description = "Attract all players to you",
        Default = false,
        Callback = function(Value)
            toggleMagnetPlayers(Value)
        end
    })
    
    tab:AddToggle("FlingModeToggle", {
        Title = "Fling Mode",
        Description = "Continuously fling nearby players",
        Default = false,
        Callback = function(Value)
            toggleFlingMode(Value)
        end
    })
    
    tab:AddToggle("FreezeAllToggle", {
        Title = "Freeze All Players",
        Description = "Freeze all other players in place",
        Default = false,
        Callback = function(Value)
            freezeAllPlayers(Value)
        end
    })
    
    return true
end

function Player.cleanup()
    for _, conn in pairs(connections) do
        if conn then conn:Disconnect() end
    end
    connections = {}
    
    spectating = false
    following = false
    selectedPlayer = nil
    followTarget = nil
    
    antiAFKEnabled = false
    fastRespawnEnabled = false
    noDeathAnimationEnabled = false
    physicsEnabled = false
    magnetEnabled = false
    flingEnabled = false
    
    for targetPlayer, _ in pairs(physicsPlayers) do
        disablePhysicsForPlayer(targetPlayer)
    end
    physicsPlayers = {}
    
    frozenPlayers = {}
    flungPlayers = {}
    
    if playerListFrame then
        playerListFrame:Destroy()
        playerListFrame = nil
    end
end

return Player