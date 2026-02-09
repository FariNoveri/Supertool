-- MinimalHackGUI Clean Version with Fluent Library
-- by Fari Noveri

-- Load Fluent UI Library
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

-- Local Player
local player = Players.LocalPlayer
local character, humanoid, rootPart

-- State Management
local connections = {}
local activeStates = {}

-- Initialize Character
local function initCharacter()
    character = player.Character or player.CharacterAdded:Wait()
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
end

initCharacter()
player.CharacterAdded:Connect(initCharacter)

-- Create Main Window
local Window = Fluent:CreateWindow({
    Title = "SuperTool | " .. Fluent.Version,
    SubTitle = "by Fari Noveri",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.Home
})

-- Notification on load
Fluent:Notify({
    Title = "SuperTool Loaded",
    Content = "Made by Fari Noveri - Successfully loaded!",
    SubContent = "Press Home to toggle GUI",
    Duration = 5
})

-- Create Tabs
local Tabs = {
    Movement = Window:AddTab({ Title = "Movement", Icon = "person-running" }),
    Player = Window:AddTab({ Title = "Player", Icon = "user" }),
    Teleport = Window:AddTab({ Title = "Teleport", Icon = "map-pin" }),
    Visual = Window:AddTab({ Title = "Visual", Icon = "eye" }),
    Utility = Window:AddTab({ Title = "Utility", Icon = "wrench" }),
    AntiAdmin = Window:AddTab({ Title = "Anti-Admin", Icon = "shield" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- ============================================
-- MOVEMENT TAB
-- ============================================
do
    local MovementSection = Tabs.Movement:AddSection("Movement Controls")
    
    -- Speed Hack
    local SpeedEnabled = false
    local SpeedValue = 16
    local SpeedConnection
    
    local SpeedToggle = Tabs.Movement:AddToggle("SpeedToggle", {
        Title = "Speed Hack",
        Description = "Increase your movement speed",
        Default = false,
        Callback = function(Value)
            SpeedEnabled = Value
            if SpeedEnabled then
                SpeedConnection = RunService.Heartbeat:Connect(function()
                    if humanoid then
                        humanoid.WalkSpeed = SpeedValue
                    end
                end)
            else
                if SpeedConnection then
                    SpeedConnection:Disconnect()
                end
                if humanoid then
                    humanoid.WalkSpeed = 16
                end
            end
        end
    })
    
    local SpeedSlider = Tabs.Movement:AddSlider("SpeedSlider", {
        Title = "Speed Amount",
        Description = "Adjust movement speed",
        Default = 16,
        Min = 16,
        Max = 500,
        Rounding = 0,
        Callback = function(Value)
            SpeedValue = Value
        end
    })
    
    -- Jump Power
    local JumpEnabled = false
    local JumpValue = 50
    local JumpConnection
    
    local JumpToggle = Tabs.Movement:AddToggle("JumpToggle", {
        Title = "Jump Hack",
        Description = "Increase your jump power",
        Default = false,
        Callback = function(Value)
            JumpEnabled = Value
            if JumpEnabled then
                JumpConnection = RunService.Heartbeat:Connect(function()
                    if humanoid then
                        humanoid.JumpPower = JumpValue
                    end
                end)
            else
                if JumpConnection then
                    JumpConnection:Disconnect()
                end
                if humanoid then
                    humanoid.JumpPower = 50
                end
            end
        end
    })
    
    local JumpSlider = Tabs.Movement:AddSlider("JumpSlider", {
        Title = "Jump Power",
        Description = "Adjust jump power",
        Default = 50,
        Min = 50,
        Max = 500,
        Rounding = 0,
        Callback = function(Value)
            JumpValue = Value
        end
    })
    
    -- Fly
    local FlyEnabled = false
    local FlySpeed = 50
    local FlyConnection
    
    local function toggleFly(enabled)
        if enabled then
            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            bodyVelocity.Parent = rootPart
            
            FlyConnection = RunService.Heartbeat:Connect(function()
                if not rootPart or not humanoid or humanoid.Health <= 0 then
                    FlyEnabled = false
                    if bodyVelocity then bodyVelocity:Destroy() end
                    return
                end
                
                local moveDirection = Vector3.new(0, 0, 0)
                
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveDirection = moveDirection + (Workspace.CurrentCamera.CFrame.LookVector * FlySpeed)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveDirection = moveDirection - (Workspace.CurrentCamera.CFrame.LookVector * FlySpeed)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveDirection = moveDirection - (Workspace.CurrentCamera.CFrame.RightVector * FlySpeed)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveDirection = moveDirection + (Workspace.CurrentCamera.CFrame.RightVector * FlySpeed)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveDirection = moveDirection + Vector3.new(0, FlySpeed, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveDirection = moveDirection - Vector3.new(0, FlySpeed, 0)
                end
                
                bodyVelocity.Velocity = moveDirection
            end)
        else
            if FlyConnection then
                FlyConnection:Disconnect()
            end
            if rootPart then
                for _, v in pairs(rootPart:GetChildren()) do
                    if v:IsA("BodyVelocity") then
                        v:Destroy()
                    end
                end
            end
        end
    end
    
    local FlyToggle = Tabs.Movement:AddToggle("FlyToggle", {
        Title = "Fly",
        Description = "Fly around the map (WASD, Space, Shift)",
        Default = false,
        Callback = function(Value)
            FlyEnabled = Value
            toggleFly(Value)
        end
    })
    
    local FlySlider = Tabs.Movement:AddSlider("FlySlider", {
        Title = "Fly Speed",
        Description = "Adjust fly speed",
        Default = 50,
        Min = 10,
        Max = 300,
        Rounding = 0,
        Callback = function(Value)
            FlySpeed = Value
        end
    })
    
    -- Noclip
    local NoclipEnabled = false
    local NoclipConnection
    
    local NoclipToggle = Tabs.Movement:AddToggle("NoclipToggle", {
        Title = "Noclip",
        Description = "Walk through walls",
        Default = false,
        Callback = function(Value)
            NoclipEnabled = Value
            if NoclipEnabled then
                NoclipConnection = RunService.Stepped:Connect(function()
                    if character then
                        for _, part in pairs(character:GetDescendants()) do
                            if part:IsA("BasePart") then
                                part.CanCollide = false
                            end
                        end
                    end
                end)
            else
                if NoclipConnection then
                    NoclipConnection:Disconnect()
                end
                if character then
                    for _, part in pairs(character:GetDescendants()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            part.CanCollide = true
                        end
                    end
                end
            end
        end
    })
    
    -- Infinite Jump
    local InfiniteJumpEnabled = false
    local InfiniteJumpConnection
    
    local InfiniteJumpToggle = Tabs.Movement:AddToggle("InfiniteJumpToggle", {
        Title = "Infinite Jump",
        Description = "Jump infinitely in the air",
        Default = false,
        Callback = function(Value)
            InfiniteJumpEnabled = Value
            if InfiniteJumpEnabled then
                InfiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
                    if humanoid then
                        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                end)
            else
                if InfiniteJumpConnection then
                    InfiniteJumpConnection:Disconnect()
                end
            end
        end
    })
end

-- ============================================
-- PLAYER TAB
-- ============================================
do
    local PlayerSection = Tabs.Player:AddSection("Player Modifications")
    
    -- God Mode
    local GodModeToggle = Tabs.Player:AddToggle("GodMode", {
        Title = "God Mode",
        Description = "Infinite health",
        Default = false,
        Callback = function(Value)
            if Value then
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
    })
    
    -- Reset Character
    Tabs.Player:AddButton({
        Title = "Reset Character",
        Description = "Respawn your character",
        Callback = function()
            if character then
                character:BreakJoints()
            end
        end
    })
    
    -- Sit/Stand
    Tabs.Player:AddButton({
        Title = "Sit/Stand Toggle",
        Description = "Toggle sitting state",
        Callback = function()
            if humanoid then
                humanoid.Sit = not humanoid.Sit
            end
        end
    })
    
    -- Remove Accessories
    Tabs.Player:AddButton({
        Title = "Remove Accessories",
        Description = "Remove all accessories from character",
        Callback = function()
            if character then
                for _, accessory in pairs(character:GetChildren()) do
                    if accessory:IsA("Accessory") then
                        accessory:Destroy()
                    end
                end
                Fluent:Notify({
                    Title = "Accessories Removed",
                    Content = "All accessories have been removed",
                    Duration = 3
                })
            end
        end
    })
end

-- ============================================
-- TELEPORT TAB
-- ============================================
do
    local TeleportSection = Tabs.Teleport:AddSection("Teleportation")
    
    local SelectedPlayer = nil
    local PlayerDropdown
    
    local function getPlayerList()
        local players = {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player then
                table.insert(players, p.Name)
            end
        end
        return players
    end
    
    PlayerDropdown = Tabs.Teleport:AddDropdown("PlayerSelect", {
        Title = "Select Player",
        Description = "Choose a player to teleport to",
        Values = getPlayerList(),
        Multi = false,
        Default = 1,
        Callback = function(Value)
            SelectedPlayer = Players:FindFirstChild(Value)
        end
    })
    
    -- Refresh player list button
    Tabs.Teleport:AddButton({
        Title = "Refresh Players",
        Description = "Update the player list",
        Callback = function()
            PlayerDropdown:SetValues(getPlayerList())
            Fluent:Notify({
                Title = "Players Refreshed",
                Content = "Player list has been updated",
                Duration = 2
            })
        end
    })
    
    -- Teleport to selected player
    Tabs.Teleport:AddButton({
        Title = "Teleport to Player",
        Description = "Teleport to the selected player",
        Callback = function()
            if SelectedPlayer and SelectedPlayer.Character and rootPart then
                local targetRoot = SelectedPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetRoot then
                    rootPart.CFrame = targetRoot.CFrame
                    Fluent:Notify({
                        Title = "Teleported",
                        Content = "Teleported to " .. SelectedPlayer.Name,
                        Duration = 3
                    })
                end
            else
                Fluent:Notify({
                    Title = "Error",
                    Content = "Please select a valid player",
                    Duration = 3
                })
            end
        end
    })
    
    -- Teleport to spawn
    Tabs.Teleport:AddButton({
        Title = "Teleport to Spawn",
        Description = "Return to spawn point",
        Callback = function()
            if rootPart then
                local spawn = Workspace:FindFirstChild("SpawnLocation")
                if spawn then
                    rootPart.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
                else
                    rootPart.CFrame = CFrame.new(0, 50, 0)
                end
                Fluent:Notify({
                    Title = "Teleported",
                    Content = "Returned to spawn",
                    Duration = 2
                })
            end
        end
    })
end

-- ============================================
-- VISUAL TAB
-- ============================================
do
    local VisualSection = Tabs.Visual:AddSection("Visual Effects")
    
    -- Fullbright
    local FullbrightEnabled = false
    local OriginalAmbient
    local OriginalBrightness
    
    local FullbrightToggle = Tabs.Visual:AddToggle("Fullbright", {
        Title = "Fullbright",
        Description = "Make everything bright",
        Default = false,
        Callback = function(Value)
            FullbrightEnabled = Value
            if FullbrightEnabled then
                OriginalAmbient = Lighting.Ambient
                OriginalBrightness = Lighting.Brightness
                Lighting.Ambient = Color3.new(1, 1, 1)
                Lighting.Brightness = 2
                Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
            else
                if OriginalAmbient then
                    Lighting.Ambient = OriginalAmbient
                end
                if OriginalBrightness then
                    Lighting.Brightness = OriginalBrightness
                end
            end
        end
    })
    
    -- ESP (Simple Name ESP)
    local ESPEnabled = false
    local ESPConnections = {}
    
    local function createESP(player)
        if player == Players.LocalPlayer then return end
        if not player.Character then return end
        
        local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        -- Create BillboardGui
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ESP"
        billboard.Parent = humanoidRootPart
        billboard.AlwaysOnTop = true
        billboard.Size = UDim2.new(0, 100, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 2, 0)
        
        -- Create TextLabel
        local textLabel = Instance.new("TextLabel")
        textLabel.Parent = billboard
        textLabel.BackgroundTransparency = 1
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.Text = player.Name
        textLabel.TextColor3 = Color3.new(1, 1, 1)
        textLabel.TextStrokeTransparency = 0.5
        textLabel.TextScaled = true
        textLabel.Font = Enum.Font.GothamBold
    end
    
    local function removeESP(player)
        if player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local esp = hrp:FindFirstChild("ESP")
                if esp then
                    esp:Destroy()
                end
            end
        end
    end
    
    local ESPToggle = Tabs.Visual:AddToggle("ESP", {
        Title = "Player ESP",
        Description = "See player names through walls",
        Default = false,
        Callback = function(Value)
            ESPEnabled = Value
            if ESPEnabled then
                for _, p in pairs(Players:GetPlayers()) do
                    if p.Character then
                        createESP(p)
                    end
                end
                
                ESPConnections.PlayerAdded = Players.PlayerAdded:Connect(function(p)
                    p.CharacterAdded:Connect(function()
                        if ESPEnabled then
                            createESP(p)
                        end
                    end)
                end)
            else
                for _, p in pairs(Players:GetPlayers()) do
                    removeESP(p)
                end
                if ESPConnections.PlayerAdded then
                    ESPConnections.PlayerAdded:Disconnect()
                end
            end
        end
    })
end

-- ============================================
-- UTILITY TAB
-- ============================================
do
    local UtilitySection = Tabs.Utility:AddSection("Utility Tools")
    
    -- Remove Fog
    Tabs.Utility:AddButton({
        Title = "Remove Fog",
        Description = "Clear all fog from the game",
        Callback = function()
            Lighting.FogEnd = 100000
            Fluent:Notify({
                Title = "Fog Removed",
                Content = "All fog has been cleared",
                Duration = 2
            })
        end
    })
    
    -- Anti-AFK
    local AntiAFKEnabled = false
    local AntiAFKConnection
    
    local AntiAFKToggle = Tabs.Utility:AddToggle("AntiAFK", {
        Title = "Anti-AFK",
        Description = "Prevent being kicked for inactivity",
        Default = false,
        Callback = function(Value)
            AntiAFKEnabled = Value
            if AntiAFKEnabled then
                local VirtualUser = game:GetService("VirtualUser")
                AntiAFKConnection = player.Idled:Connect(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
                Fluent:Notify({
                    Title = "Anti-AFK Enabled",
                    Content = "You won't be kicked for being AFK",
                    Duration = 3
                })
            else
                if AntiAFKConnection then
                    AntiAFKConnection:Disconnect()
                end
            end
        end
    })
    
    -- Copy Game ID
    Tabs.Utility:AddButton({
        Title = "Copy Game ID",
        Description = "Copy current game's ID",
        Callback = function()
            setclipboard(tostring(game.PlaceId))
            Fluent:Notify({
                Title = "Copied!",
                Content = "Game ID: " .. game.PlaceId,
                Duration = 3
            })
        end
    })
    
    -- Rejoin Server
    Tabs.Utility:AddButton({
        Title = "Rejoin Server",
        Description = "Rejoin the current server",
        Callback = function()
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
        end
    })
end

-- ============================================
-- ANTI-ADMIN TAB
-- ============================================
do
    local AntiAdminSection = Tabs.AntiAdmin:AddSection("Anti-Admin Tools")
    
    -- Anti-Kick
    local AntiKickEnabled = false
    
    local AntiKickToggle = Tabs.AntiAdmin:AddToggle("AntiKick", {
        Title = "Anti-Kick",
        Description = "Prevent being kicked (may not work on all games)",
        Default = false,
        Callback = function(Value)
            AntiKickEnabled = Value
            if AntiKickEnabled then
                local mt = getrawmetatable(game)
                local oldNamecall = mt.__namecall
                setreadonly(mt, false)
                
                mt.__namecall = newcclosure(function(self, ...)
                    local method = getnamecallmethod()
                    if method == "Kick" then
                        return
                    end
                    return oldNamecall(self, ...)
                end)
                
                setreadonly(mt, true)
                
                Fluent:Notify({
                    Title = "Anti-Kick Enabled",
                    Content = "Kick protection is now active",
                    Duration = 3
                })
            end
        end
    })
    
    -- Info text
    Tabs.AntiAdmin:AddParagraph({
        Title = "Notice",
        Content = "Anti-admin features may not work on all games. Use at your own risk."
    })
end

-- ============================================
-- SETTINGS TAB
-- ============================================
do
    local SettingsSection = Tabs.Settings:AddSection("GUI Settings")
    
    -- Theme selector
    Tabs.Settings:AddDropdown("Theme", {
        Title = "Theme",
        Description = "Change GUI theme",
        Values = {"Dark", "Light", "Aqua", "Amethyst", "Rose"},
        Multi = false,
        Default = 1,
        Callback = function(Value)
            Fluent:SetTheme(Value)
        end
    })
    
    -- Transparency slider
    Tabs.Settings:AddSlider("Transparency", {
        Title = "Transparency",
        Description = "Adjust GUI transparency",
        Default = 0,
        Min = 0,
        Max = 1,
        Rounding = 2,
        Callback = function(Value)
            Window:SetTransparency(Value)
        end
    })
    
    -- About section
    local AboutSection = Tabs.Settings:AddSection("About")
    
    Tabs.Settings:AddParagraph({
        Title = "SuperTool",
        Content = "Clean version with Fluent UI\nCreated by Fari Noveri\n\nVersion: 2.0\nPress Home to toggle GUI"
    })
end

-- Save Manager
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})

InterfaceManager:SetFolder("SuperTool")
SaveManager:SetFolder("SuperTool/configs")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title = "Ready!",
    Content = "SuperTool is ready to use. Enjoy!",
    Duration = 5
})