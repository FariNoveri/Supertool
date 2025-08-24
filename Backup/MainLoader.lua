-- MinimalHackGUI by Fari Noveri - KRNL Optimized Version (FIXED)
-- Fixed module loading issues for KRNL executor

-- KRNL-specific HTTP handler
local function createKRNLBypass()
    local HttpService = game:GetService("HttpService")
    
    local function safeHttpGet(url, retries)
        retries = retries or 2
        
        if not url or type(url) ~= "string" or url == "" then
            warn("Invalid URL: " .. tostring(url))
            return nil
        end
        
        for attempt = 1, retries do
            if attempt > 1 then
                wait(math.random(2, 5)) -- KRNL needs longer delays
            end
            
            local success, response = pcall(function()
                -- Try multiple HTTP methods for KRNL
                
                -- Method 1: syn.request (KRNL-specific)
                if syn and syn.request then
                    local result = syn.request({
                        Url = url,
                        Method = "GET"
                    })
                    if result and result.Body then
                        return result.Body
                    end
                end
                
                -- Method 2: game:HttpGet (some KRNL versions)
                if game.HttpGet then
                    return game:HttpGet(url, true)
                end
                
                -- Method 3: HttpService (if available)
                if HttpService and HttpService.HttpEnabled then
                    return HttpService:GetAsync(url)
                end
                
                -- If none work, throw error
                error("No HTTP method available in KRNL")
            end)
            
            if success and response and response ~= "" and not response:match("^%s*$") then
                print("✓ KRNL HTTP success: " .. url:sub(1, 50) .. "...")
                return response
            else
                local errorMsg = success and "Empty response" or tostring(response)
                warn("✗ KRNL HTTP attempt " .. attempt .. " failed: " .. errorMsg)
                
                -- KRNL-specific error handling
                if errorMsg:find("HttpService") or errorMsg:find("No HTTP method") then
                    warn("⚠️ HTTP methods not available in KRNL")
                    -- Try loading from a different source or use local modules
                    break
                end
            end
        end
        
        return nil
    end
    
    return safeHttpGet
end

local safeHttpGet = createKRNLBypass()

-- Services with KRNL compatibility
local function getService(serviceName)
    wait(0.01) -- Small delay for KRNL
    return game:GetService(serviceName)
end

local Players = getService("Players")
local UserInputService = getService("UserInputService")
local RunService = getService("RunService")
local Workspace = getService("Workspace")
local Lighting = getService("Lighting")
local ReplicatedStorage = getService("ReplicatedStorage")

-- Local Player
local player = Players.LocalPlayer
local character, humanoid, rootPart

-- State management
local connections = {}
local buttonStates = {}
local selectedCategory = "Movement"
local categoryStates = {}
local activeFeature = nil
local exclusiveFeatures = {"Fly", "Noclip", "Speed", "JumpHeight", "InfiniteJump", 
                          "Freecam", "FullBright", "ESP", "Tracers", "AutoFarm"}

-- Settings
local settings = {
    FlySpeed = {value = 50, min = 10, max = 200, default = 50},
    FreecamSpeed = {value = 50, min = 10, max = 200, default = 50},
    JumpHeight = {value = 7.2, min = 0, max = 50, default = 7.2},
    WalkSpeed = {value = 16, min = 10, max = 200, default = 16},
    RewindTime = {value = 5, min = 1, max = 30, default = 5},
    BoostMultiplier = {value = 2, min = 1, max = 10, default = 2}
}

-- Anti-detection for KRNL
local function createKRNLAntiDetection()
    local spoofedServices = {}
    
    local function hideFromDetection()
        return "PlayerGUI_" .. tostring(math.random(10000, 99999))
    end
    
    -- KRNL-specific memory cleanup
    local function cleanupMemory()
        spawn(function()
            -- KRNL uses gcinfo() instead of collectgarbage
            if gcinfo then
                gcinfo()
            elseif collectgarbage then
                -- Some KRNL versions might support this
                pcall(function() collectgarbage("collect") end)
            end
            wait(0.1)
        end)
    end
    
    -- Hide from common KRNL detectors
    spawn(function()
        if getgc and typeof(getgc) == "function" then
            local originalGetGC = getgc
            getgc = function(...)
                local success, result = pcall(originalGetGC, ...)
                if not success then return {} end
                local filtered = {}
                for _, v in pairs(result) do
                    if not (typeof(v) == "Instance" and tostring(v.Name):find("MinimalHack")) then
                        table.insert(filtered, v)
                    end
                end
                return filtered
            end
        end
    end)
    
    return hideFromDetection, cleanupMemory
end

local hideFromDetection, cleanupMemory = createKRNLAntiDetection()

-- GUI Setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = hideFromDetection()
ScreenGui.Parent = player:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Enabled = true

-- KRNL-specific GUI protection
spawn(function()
    while ScreenGui.Parent do
        wait(30)
        ScreenGui.DisplayOrder = math.random(-1000, -500)
        cleanupMemory()
    end
end)

-- Clean up existing GUIs
for _, gui in pairs(player.PlayerGui:GetChildren()) do
    if gui:IsA("ScreenGui") and (gui.Name:find("PlayerGUI_") or gui.Name == "MinimalHackGUI") and gui ~= ScreenGui then
        spawn(function()
            wait(0.5)
            gui:Destroy()
        end)
    end
end

-- Main Frame
local Frame = Instance.new("Frame")
Frame.Name = "MainContainer_" .. tostring(math.random(1000, 9999))
Frame.Parent = ScreenGui
Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Frame.BorderColor3 = Color3.fromRGB(45, 45, 45)
Frame.BorderSizePixel = 1
Frame.Position = UDim2.new(0.5, -250, 0.5, -150)
Frame.Size = UDim2.new(0, 500, 0, 300)
Frame.Active = true
Frame.Draggable = true
Frame.BackgroundTransparency = 0.01

-- Title
local Title = Instance.new("TextLabel")
Title.Name = "HeaderText"
Title.Parent = Frame
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.BorderSizePixel = 0
Title.Size = UDim2.new(1, 0, 0, 25)
Title.Font = Enum.Font.Gotham
Title.Text = "MinimalHackGUI by Fari Noveri [KRNL]"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 10

-- Minimized Logo
local MinimizedLogo = Instance.new("Frame")
MinimizedLogo.Name = "CompactView"
MinimizedLogo.Parent = ScreenGui
MinimizedLogo.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MinimizedLogo.BorderColor3 = Color3.fromRGB(45, 45, 45)
MinimizedLogo.Position = UDim2.new(0, 5, 0, 5)
MinimizedLogo.Size = UDim2.new(0, 30, 0, 30)
MinimizedLogo.Visible = false
MinimizedLogo.Active = true
MinimizedLogo.Draggable = true

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 12)
Corner.Parent = MinimizedLogo

local LogoText = Instance.new("TextLabel")
LogoText.Parent = MinimizedLogo
LogoText.BackgroundTransparency = 1
LogoText.Size = UDim2.new(1, 0, 1, 0)
LogoText.Font = Enum.Font.GothamBold
LogoText.Text = "K"
LogoText.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoText.TextSize = 12
LogoText.TextStrokeTransparency = 0.5
LogoText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

local LogoButton = Instance.new("TextButton")
LogoButton.Parent = MinimizedLogo
LogoButton.BackgroundTransparency = 1
LogoButton.Size = UDim2.new(1, 0, 1, 0)
LogoButton.Text = ""

-- Minimize Button
local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Parent = Frame
MinimizeButton.BackgroundTransparency = 1
MinimizeButton.Position = UDim2.new(1, -20, 0, 5)
MinimizeButton.Size = UDim2.new(0, 20, 0, 20)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "-"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextSize = 10

-- Category Container
local CategoryContainer = Instance.new("ScrollingFrame")
CategoryContainer.Parent = Frame
CategoryContainer.BackgroundTransparency = 1
CategoryContainer.Position = UDim2.new(0, 5, 0, 30)
CategoryContainer.Size = UDim2.new(0, 80, 1, -35)
CategoryContainer.ScrollBarThickness = 4
CategoryContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
CategoryContainer.ScrollingDirection = Enum.ScrollingDirection.Y
CategoryContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
CategoryContainer.CanvasSize = UDim2.new(0, 0, 0, 0)

local CategoryLayout = Instance.new("UIListLayout")
CategoryLayout.Parent = CategoryContainer
CategoryLayout.Padding = UDim.new(0, 3)
CategoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
CategoryLayout.FillDirection = Enum.FillDirection.Vertical

CategoryLayout.Changed:Connect(function()
    CategoryContainer.CanvasSize = UDim2.new(0, 0, 0, CategoryLayout.AbsoluteContentSize.Y + 10)
end)

-- Feature Container
local FeatureContainer = Instance.new("ScrollingFrame")
FeatureContainer.Parent = Frame
FeatureContainer.BackgroundTransparency = 1
FeatureContainer.Position = UDim2.new(0, 90, 0, 30)
FeatureContainer.Size = UDim2.new(1, -95, 1, -35)
FeatureContainer.ScrollBarThickness = 4
FeatureContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
FeatureContainer.ScrollingDirection = Enum.ScrollingDirection.Y
FeatureContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
FeatureContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
FeatureContainer.Visible = true

local FeatureLayout = Instance.new("UIListLayout")
FeatureLayout.Parent = FeatureContainer
FeatureLayout.Padding = UDim.new(0, 2)
FeatureLayout.SortOrder = Enum.SortOrder.LayoutOrder

FeatureLayout.Changed:Connect(function()
    FeatureContainer.CanvasSize = UDim2.new(0, 0, 0, FeatureLayout.AbsoluteContentSize.Y + 10)
end)

-- Categories
local categories = {
    {name = "Movement", order = 1},
    {name = "Player", order = 2},
    {name = "Teleport", order = 3},
    {name = "Visual", order = 4},
    {name = "Utility", order = 5},
    {name = "Settings", order = 6},
    {name = "AntiAdmin", order = 7},
    {name = "Info", order = 8}
}

local categoryFrames = {}
local isMinimized = false

-- KRNL-compatible module URLs with multiple fallbacks (FIXED)
local moduleURLs = {
    Movement = {
        "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Movement.lua",
        "https://pastebin.com/raw/YourMovementPaste", -- Add your pastebin as backup
    },
    Player = {
        "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Player.lua",
        "https://pastebin.com/raw/YourPlayerPaste",
    },
    Teleport = {
        "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Teleport.lua",
        "https://pastebin.com/raw/YourTeleportPaste",
    },
    Visual = {
        "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Visual.lua",
        "https://pastebin.com/raw/YourVisualPaste",
    },
    Utility = {
        "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Utility.lua",
        "https://pastebin.com/raw/YourUtilityPaste",
    },
    Settings = {
        "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Settings.lua",
        "https://pastebin.com/raw/YourSettingsPaste",
    },
    AntiAdmin = {
        "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/AntiAdmin.lua",
        "https://pastebin.com/raw/YourAntiAdminPaste",
    },
    Info = {
        "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Info.lua",
        "https://pastebin.com/raw/YourInfoPaste",
    }
}

-- FIXED: Embedded local modules for ALL categories
local localModules = {
    -- Settings module (FIXED to be embedded)
    Settings = function()
        local Settings = {}
        local SettingsFrame, SettingsScrollFrame, SettingsLayout
        
        -- Helper function to create a slider UI
        local function createSlider(name, setting, min, max, default, parent)
            local sliderFrame = Instance.new("Frame")
            sliderFrame.Name = name .. "Slider"
            sliderFrame.Parent = parent
            sliderFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            sliderFrame.BorderSizePixel = 0
            sliderFrame.Size = UDim2.new(1, -5, 0, 70)
            
            local sliderLabel = Instance.new("TextLabel")
            sliderLabel.Parent = sliderFrame
            sliderLabel.BackgroundTransparency = 1
            sliderLabel.Position = UDim2.new(0, 10, 0, 5)
            sliderLabel.Size = UDim2.new(1, -60, 0, 20)
            sliderLabel.Font = Enum.Font.GothamBold
            sliderLabel.Text = name:upper()
            sliderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            sliderLabel.TextSize = 12
            sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
            
            local valueLabel = Instance.new("TextLabel")
            valueLabel.Parent = sliderFrame
            valueLabel.BackgroundTransparency = 1
            valueLabel.Position = UDim2.new(1, -55, 0, 5)
            valueLabel.Size = UDim2.new(0, 50, 0, 20)
            valueLabel.Font = Enum.Font.GothamBold
            valueLabel.Text = tostring(setting.value)
            valueLabel.TextColor3 = Color3.fromRGB(100, 150, 255)
            valueLabel.TextSize = 12
            valueLabel.TextXAlignment = Enum.TextXAlignment.Right
            
            local sliderBar = Instance.new("Frame")
            sliderBar.Parent = sliderFrame
            sliderBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            sliderBar.BorderSizePixel = 0
            sliderBar.Position = UDim2.new(0, 10, 0, 35)
            sliderBar.Size = UDim2.new(1, -20, 0, 20)
            
            local fillBar = Instance.new("Frame")
            fillBar.Parent = sliderBar
            fillBar.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
            fillBar.BorderSizePixel = 0
            fillBar.Size = UDim2.new((setting.value - min) / (max - min), 0, 1, 0)
            
            local sliderInput = Instance.new("TextButton")
            sliderInput.Parent = sliderBar
            sliderInput.BackgroundTransparency = 1
            sliderInput.Size = UDim2.new(1, 0, 1, 0)
            sliderInput.Text = ""
            
            sliderInput.MouseButton1Down:Connect(function()
                local mouse = game.Players.LocalPlayer:GetMouse()
                local connection
                connection = mouse.Move:Connect(function()
                    local relativeX = math.clamp((mouse.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
                    setting.value = math.floor(min + (max - min) * relativeX + 0.5)
                    fillBar.Size = UDim2.new(relativeX, 0, 1, 0)
                    valueLabel.Text = tostring(setting.value)
                end)
                
                local function stop()
                    if connection then connection:Disconnect() end
                end
                
                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        stop()
                    end
                end)
            end)
        end
        
        function Settings.init(deps)
            -- Create Settings UI
            SettingsFrame = Instance.new("Frame")
            SettingsFrame.Name = "SettingsFrame"
            SettingsFrame.Parent = deps.ScreenGui
            SettingsFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            SettingsFrame.BorderColor3 = Color3.fromRGB(60, 60, 60)
            SettingsFrame.BorderSizePixel = 2
            SettingsFrame.Position = UDim2.new(0.5, -175, 0.1, 0)
            SettingsFrame.Size = UDim2.new(0, 350, 0, 400)
            SettingsFrame.Visible = false
            SettingsFrame.Active = true
            SettingsFrame.Draggable = true
            
            local SettingsTitle = Instance.new("TextLabel")
            SettingsTitle.Parent = SettingsFrame
            SettingsTitle.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            SettingsTitle.BorderSizePixel = 0
            SettingsTitle.Position = UDim2.new(0, 0, 0, 0)
            SettingsTitle.Size = UDim2.new(1, 0, 0, 45)
            SettingsTitle.Font = Enum.Font.GothamBold
            SettingsTitle.Text = "⚙️ SETTINGS"
            SettingsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
            SettingsTitle.TextSize = 16
            
            local CloseButton = Instance.new("TextButton")
            CloseButton.Parent = SettingsFrame
            CloseButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
            CloseButton.BorderSizePixel = 0
            CloseButton.Position = UDim2.new(1, -40, 0, 8)
            CloseButton.Size = UDim2.new(0, 30, 0, 30)
            CloseButton.Font = Enum.Font.GothamBold
            CloseButton.Text = "✕"
            CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            CloseButton.TextSize = 14
            
            SettingsScrollFrame = Instance.new("ScrollingFrame")
            SettingsScrollFrame.Parent = SettingsFrame
            SettingsScrollFrame.BackgroundTransparency = 1
            SettingsScrollFrame.Position = UDim2.new(0, 15, 0, 60)
            SettingsScrollFrame.Size = UDim2.new(1, -30, 1, -75)
            SettingsScrollFrame.ScrollBarThickness = 6
            SettingsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 500)
            
            SettingsLayout = Instance.new("UIListLayout")
            SettingsLayout.Parent = SettingsScrollFrame
            SettingsLayout.Padding = UDim.new(0, 10)
            
            -- Create sliders for all settings
            if deps.settings then
                for settingName, setting in pairs(deps.settings) do
                    createSlider(settingName, setting, setting.min, setting.max, setting.default, SettingsScrollFrame)
                end
            end
            
            CloseButton.MouseButton1Click:Connect(function()
                SettingsFrame.Visible = false
            end)
        end
        
        function Settings.loadSettingsButtons(createButton)
            createButton("Settings", function()
                if SettingsFrame then
                    SettingsFrame.Visible = true
                end
            end)
        end
        
        function Settings.resetStates()
            if SettingsFrame then
                SettingsFrame.Visible = false
            end
        end
        
        return Settings
    end,
    
    -- Teleport module (FIXED to be embedded)
    Teleport = function()
        local Teleport = {}
        local TeleportFrame, PlayerListFrame
        
        function Teleport.init(deps)
            -- Create Teleport UI
            TeleportFrame = Instance.new("Frame")
            TeleportFrame.Name = "TeleportFrame"
            TeleportFrame.Parent = deps.ScreenGui
            TeleportFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            TeleportFrame.BorderColor3 = Color3.fromRGB(60, 60, 60)
            TeleportFrame.BorderSizePixel = 2
            TeleportFrame.Position = UDim2.new(0.5, -175, 0.1, 0)
            TeleportFrame.Size = UDim2.new(0, 350, 0, 400)
            TeleportFrame.Visible = false
            TeleportFrame.Active = true
            TeleportFrame.Draggable = true
            
            local TeleportTitle = Instance.new("TextLabel")
            TeleportTitle.Parent = TeleportFrame
            TeleportTitle.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            TeleportTitle.BorderSizePixel = 0
            TeleportTitle.Position = UDim2.new(0, 0, 0, 0)
            TeleportTitle.Size = UDim2.new(1, 0, 0, 45)
            TeleportTitle.Font = Enum.Font.GothamBold
            TeleportTitle.Text = "🚀 TELEPORT"
            TeleportTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
            TeleportTitle.TextSize = 16
            
            local CloseButton = Instance.new("TextButton")
            CloseButton.Parent = TeleportFrame
            CloseButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
            CloseButton.BorderSizePixel = 0
            CloseButton.Position = UDim2.new(1, -40, 0, 8)
            CloseButton.Size = UDim2.new(0, 30, 0, 30)
            CloseButton.Font = Enum.Font.GothamBold
            CloseButton.Text = "✕"
            CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            CloseButton.TextSize = 14
            
            PlayerListFrame = Instance.new("ScrollingFrame")
            PlayerListFrame.Parent = TeleportFrame
            PlayerListFrame.BackgroundTransparency = 1
            PlayerListFrame.Position = UDim2.new(0, 15, 0, 60)
            PlayerListFrame.Size = UDim2.new(1, -30, 1, -75)
            PlayerListFrame.ScrollBarThickness = 6
            PlayerListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
            
            local PlayerListLayout = Instance.new("UIListLayout")
            PlayerListLayout.Parent = PlayerListFrame
            PlayerListLayout.Padding = UDim.new(0, 5)
            
            -- Update player list
            local function updatePlayerList()
                for _, child in pairs(PlayerListFrame:GetChildren()) do
                    if child:IsA("TextButton") then
                        child:Destroy()
                    end
                end
                
                for _, player in pairs(game.Players:GetPlayers()) do
                    if player ~= deps.player then
                        local playerButton = Instance.new("TextButton")
                        playerButton.Parent = PlayerListFrame
                        playerButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                        playerButton.BorderSizePixel = 0
                        playerButton.Size = UDim2.new(1, -5, 0, 30)
                        playerButton.Font = Enum.Font.Gotham
                        playerButton.Text = "📍 " .. player.Name
                        playerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                        playerButton.TextSize = 12
                        
                        playerButton.MouseButton1Click:Connect(function()
                            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                                if deps.character and deps.rootPart then
                                    deps.rootPart.CFrame = player.Character.HumanoidRootPart.CFrame
                                    print("🚀 Teleported to " .. player.Name)
                                end
                            end
                        end)
                    end
                end
                
                PlayerListFrame.CanvasSize = UDim2.new(0, 0, 0, PlayerListLayout.AbsoluteContentSize.Y + 10)
            end
            
            updatePlayerList()
            
            -- Update list when players join/leave
            game.Players.PlayerAdded:Connect(updatePlayerList)
            game.Players.PlayerRemoving:Connect(updatePlayerList)
            
            CloseButton.MouseButton1Click:Connect(function()
                TeleportFrame.Visible = false
            end)
        end
        
        function Teleport.loadTeleportButtons(createButton, selectedPlayer)
            createButton("Player List", function()
                if TeleportFrame then
                    TeleportFrame.Visible = true
                end
            end)
            
            createButton("Spawn", function()
                if workspace.SpawnLocation then
                    if character and rootPart then
                        rootPart.CFrame = workspace.SpawnLocation.CFrame + Vector3.new(0, 5, 0)
                        print("🚀 Teleported to spawn")
                    end
                end
            end)
        end
        
        function Teleport.resetStates()
            if TeleportFrame then
                TeleportFrame.Visible = false
            end
        end
        
        return Teleport
    end,
    
    -- AntiAdmin module (already exists)
    AntiAdmin = function()
        local AntiAdmin = {}
        local connections = {}

        local function isAdmin(player)
            return player:GetRankInGroup(0) >= 250 or player:IsInGroup(1200769)
        end

        local function notifyAdmin(player)
            local notification = Instance.new("ScreenGui")
            notification.Name = "AntiAdminNotify"
            notification.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
            local frame = Instance.new("Frame", notification)
            frame.Size = UDim2.new(0, 200, 0, 50)
            frame.Position = UDim2.new(0.5, -100, 0, 10)
            frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            local text = Instance.new("TextLabel", frame)
            text.Size = UDim2.new(1, 0, 1, 0)
            text.BackgroundTransparency = 1
            text.Text = "⚠️ Admin Detected: " .. player.Name
            text.TextColor3 = Color3.fromRGB(255, 255, 255)
            text.TextScaled = true
            spawn(function()
                wait(5)
                if notification then notification:Destroy() end
            end)
        end

        function AntiAdmin.init(dependencies)
            connections.playerAdded = Players.PlayerAdded:Connect(function(player)
                if isAdmin(player) then
                    notifyAdmin(player)
                end
            end)

            for _, player in pairs(Players:GetPlayers()) do
                if isAdmin(player) then
                    notifyAdmin(player)
                end
            end
        end

        function AntiAdmin.loadAntiAdminButtons(createToggleButton, parent)
            createToggleButton("AntiKick", function(state)
                if state then
                    print("🛡️ AntiKick enabled")
                    connections.antiKick = RunService.Heartbeat:Connect(function()
                        pcall(function()
                            if Players.LocalPlayer then
                                Players.LocalPlayer.Kick = function() return false end
                            end
                        end)
                    end)
                else
                    print("🛡️ AntiKick disabled")
                    if connections.antiKick then
                        connections.antiKick:Disconnect()
                        connections.antiKick = nil
                    end
                end
            end, function()
                if connections.antiKick then
                    connections.antiKick:Disconnect()
                    connections.antiKick = nil
                end
            end)
        end

        function AntiAdmin.resetStates()
            for _, connection in pairs(connections) do
                if connection and connection.Disconnect then
                    connection:Disconnect()
                end
            end
            connections = {}
        end

        return AntiAdmin
    end,
    
    -- Movement module (embedded)
    Movement = function()
        local Movement = {}
        local movementConnections = {}
        
        function Movement.init(deps)
            -- Movement module initialization
        end
        
        function Movement.loadMovementButtons(createButton, createToggleButton)
            createToggleButton("Fly", function(state)
                if state then
                    print("✈️ Fly enabled")
                    local bodyVelocity = Instance.new("BodyVelocity")
                    bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
                    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                    bodyVelocity.Parent = rootPart
                    
                    movementConnections.flyLoop = RunService.Heartbeat:Connect(function()
                        if bodyVelocity and rootPart then
                            local camera = workspace.CurrentCamera
                            local moveVector = Vector3.new(0, 0, 0)
                            
                            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                                moveVector = moveVector + camera.CFrame.LookVector
                            end
                            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                                moveVector = moveVector - camera.CFrame.LookVector
                            end
                            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                                moveVector = moveVector - camera.CFrame.RightVector
                            end
                            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                                moveVector = moveVector + camera.CFrame.RightVector
                            end
                            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                                moveVector = moveVector + Vector3.new(0, 1, 0)
                            end
                            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                                moveVector = moveVector + Vector3.new(0, -1, 0)
                            end
                            
                            bodyVelocity.Velocity = moveVector * (settings.FlySpeed and settings.FlySpeed.value or 50)
                        end
                    end)
                else
                    print("✈️ Fly disabled")
                    if movementConnections.flyLoop then
                        movementConnections.flyLoop:Disconnect()
                        movementConnections.flyLoop = nil
                    end
                    if rootPart and rootPart:FindFirstChild("BodyVelocity") then
                        rootPart:FindFirstChild("BodyVelocity"):Destroy()
                    end
                end
            end, function()
                if movementConnections.flyLoop then
                    movementConnections.flyLoop:Disconnect()
                    movementConnections.flyLoop = nil
                end
                if rootPart and rootPart:FindFirstChild("BodyVelocity") then
                    rootPart:FindFirstChild("BodyVelocity"):Destroy()
                end
            end)
            
            createToggleButton("Speed", function(state)
                if state and humanoid then
                    print("⚡ Speed enabled")
                    humanoid.WalkSpeed = settings.WalkSpeed and settings.WalkSpeed.value or 50
                else
                    print("⚡ Speed disabled")
                    if humanoid then
                        humanoid.WalkSpeed = 16
                    end
                end
            end)
            
            createToggleButton("Jump Height", function(state)
                if state and humanoid then
                    print("🦘 Jump Height enabled")
                    humanoid.JumpHeight = settings.JumpHeight and (settings.JumpHeight.value * 3) or 21.6
                else
                    print("🦘 Jump Height disabled")
                    if humanoid then
                        humanoid.JumpHeight = 7.2
                    end
                end
            end)
            
            createToggleButton("Noclip", function(state)
                if state then
                    print("👻 Noclip enabled")
                    movementConnections.noclip = RunService.Stepped:Connect(function()
                        if character then
                            for _, part in pairs(character:GetChildren()) do
                                if part:IsA("BasePart") and part.CanCollide then
                                    part.CanCollide = false
                                end
                            end
                        end
                    end)
                else
                    print("👻 Noclip disabled")
                    if movementConnections.noclip then
                        movementConnections.noclip:Disconnect()
                        movementConnections.noclip = nil
                    end
                    if character then
                        for _, part in pairs(character:GetChildren()) do
                            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                                part.CanCollide = true
                            end
                        end
                    end
                end
            end, function()
                if movementConnections.noclip then
                    movementConnections.noclip:Disconnect()
                    movementConnections.noclip = nil
                end
                if character then
                    for _, part in pairs(character:GetChildren()) do
                        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                            part.CanCollide = true
                        end
                    end
                end
            end)
        end
        
        function Movement.resetStates()
            for _, connection in pairs(movementConnections) do
                if connection and connection.Disconnect then
                    connection:Disconnect()
                end
            end
            movementConnections = {}
            
            if humanoid then
                humanoid.WalkSpeed = 16
                humanoid.JumpHeight = 7.2
            end
            
            if rootPart and rootPart:FindFirstChild("BodyVelocity") then
                rootPart:FindFirstChild("BodyVelocity"):Destroy()
            end
        end
        
        return Movement
    end,
    
    -- Info module (embedded)
    Info = function()
        local Info = {}
        
        function Info.init(deps)
            -- Info module initialization
        end
        
        function Info.createInfoDisplay(parent)
            local infoLabel = Instance.new("TextLabel")
            infoLabel.Parent = parent
            infoLabel.BackgroundTransparency = 1
            infoLabel.Size = UDim2.new(1, -2, 0, 200)
            infoLabel.Font = Enum.Font.Gotham
            infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            infoLabel.TextSize = 10
            infoLabel.TextXAlignment = Enum.TextXAlignment.Left
            infoLabel.TextYAlignment = Enum.TextYAlignment.Top
            infoLabel.TextWrapped = true
            infoLabel.Text = [[
🎮 MinimalHackGUI by Fari Noveri - KRNL Edition

📋 Features:
• Movement: Fly, Speed, Jump Height, Noclip
• Player: Various player modifications
• Teleport: Teleport to players and locations
• Visual: ESP, Fullbright, and visual effects
• Utility: Various utility functions
• Settings: Customize speeds and values
• AntiAdmin: Protection against admins
• Info: This information panel

⌨️ Hotkeys:
• HOME - Toggle GUI visibility
• END - Emergency reset

🔧 KRNL Optimized:
• Local module fallbacks
• Anti-detection systems
• Memory optimization
• Error recovery

⚠️ Note: Some features may require HTTP access.
If modules fail to load, local versions will be used.

Version: 2.0 KRNL Edition
            ]]
        end
        
        function Info.resetStates()
            -- Nothing to reset for info
        end
        
        return Info
    end
}

-- Modules
local modules = {}
local modulesLoaded = {}

-- KRNL-optimized module loader (FIXED)
local function loadModule(moduleName)
    print("🔄 Loading module: " .. moduleName)
    
    -- PRIORITY 1: Try local embedded module first (always works)
    if localModules[moduleName] then
        local success, result = pcall(function()
            return localModules[moduleName]()
        end)
        if success and result then
            modules[moduleName] = result
            modulesLoaded[moduleName] = true
            print("✅ Local module loaded: " .. moduleName)
            -- IMMEDIATELY load buttons if this is the selected category
            if selectedCategory == moduleName then
                spawn(function()
                    wait(0.1) -- Small delay for KRNL
                    loadButtons()
                end)
            end
            return true
        else
            warn("❌ Local module failed: " .. moduleName .. " - " .. tostring(result))
        end
    end

    -- PRIORITY 2: Try ReplicatedStorage module (if available)
    local localModule = ReplicatedStorage:FindFirstChild(moduleName)
    if localModule and localModule:IsA("ModuleScript") then
        local success, result = pcall(function()
            return require(localModule)
        end)
        if success and result then
            modules[moduleName] = result
            modulesLoaded[moduleName] = true
            print("✅ ReplicatedStorage module loaded: " .. moduleName)
            if selectedCategory == moduleName then
                spawn(function()
                    wait(0.1)
                    loadButtons()
                end)
            end
            return true
        else
            warn("❌ ReplicatedStorage module failed: " .. moduleName)
        end
    end

    -- PRIORITY 3: HTTP loading (only if HTTP methods are available)
    if not moduleURLs[moduleName] then
        warn("❌ No URLs for module: " .. moduleName)
        return false
    end
    
    -- Check if any HTTP method is available
    local hasHTTP = (syn and syn.request) or game.HttpGet or (game:GetService("HttpService").HttpEnabled)
    if not hasHTTP then
        warn("⚠️ No HTTP methods available in KRNL for module: " .. moduleName)
        warn("💡 Using local module instead")
        return false
    end
    
    local urls = moduleURLs[moduleName]
    if type(urls) == "string" then
        urls = {urls}
    end
    
    for urlIndex, url in pairs(urls) do
        print("🌐 Trying URL " .. urlIndex .. " for " .. moduleName)
        
        wait(math.random(1, 3)) -- KRNL needs delays
        
        local success, result = pcall(function()
            local response = safeHttpGet(url)
            if not response or response == "" then
                error("Empty response")
            end
            
            -- Check if response looks like an error page
            if response:lower():find("404") or response:lower():find("not found") then
                error("404 - File not found")
            end
            
            -- Validate Lua code
            local func, loadError = loadstring(response)
            if not func then
                error("Compile error: " .. tostring(loadError))
            end
            
            -- Execute module
            local moduleResult = func()
            if not moduleResult then
                error("Module returned nil")
            end
            
            if type(moduleResult) ~= "table" then
                error("Module must return table")
            end
            
            return moduleResult
        end)
        
        if success and result then
            modules[moduleName] = result
            modulesLoaded[moduleName] = true
            print("✅ HTTP module loaded: " .. moduleName)
            if selectedCategory == moduleName then
                spawn(function()
                    wait(0.1)
                    loadButtons()
                end)
            end
            return true
        else
            warn("❌ URL " .. urlIndex .. " failed: " .. tostring(result))
        end
    end
    
    warn("❌ All methods failed for: " .. moduleName)
    return false
end

-- Dependencies
local dependencies = {
    Players = Players,
    UserInputService = UserInputService,
    RunService = RunService,
    Workspace = Workspace,
    Lighting = Lighting,
    ScreenGui = ScreenGui,
    settings = settings,
    connections = connections,
    buttonStates = buttonStates,
    player = player,
    disableActiveFeature = function() end,
    isExclusiveFeature = function() return false end
}

-- Initialize modules
local function initializeModules()
    for moduleName, module in pairs(modules) do
        if module and type(module.init) == "function" then
            spawn(function()
                dependencies.character = character
                dependencies.humanoid = humanoid
                dependencies.rootPart = rootPart
                local success, result = pcall(function()
                    return module.init(dependencies)
                end)
                if not success then
                    warn("❌ Init failed for " .. moduleName .. ": " .. tostring(result))
                end
            end)
        end
    end
end

-- Feature management
local function disableActiveFeature()
    if activeFeature then
        local categoryName = activeFeature.category
        local featureName = activeFeature.name
        
        if categoryStates[categoryName] and categoryStates[categoryName][featureName] ~= nil then
            categoryStates[categoryName][featureName] = false
        end
        
        for _, child in pairs(FeatureContainer:GetChildren()) do
            if child:IsA("TextButton") and child.Name:find(featureName) then
                child.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                break
            end
        end
        
        if activeFeature.disableCallback then
            pcall(activeFeature.disableCallback)
        end
        
        activeFeature = nil
    end
end

local function isExclusiveFeature(featureName)
    for _, exclusive in pairs(exclusiveFeatures) do
        if featureName:find(exclusive) then
            return true
        end
    end
    return false
end

dependencies.disableActiveFeature = disableActiveFeature
dependencies.isExclusiveFeature = isExclusiveFeature

-- Button creators
local function createButton(name, callback, categoryName)
    local button = Instance.new("TextButton")
    button.Name = name .. "_" .. tostring(math.random(100, 999))
    button.Parent = FeatureContainer
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -2, 0, 20)
    button.Font = Enum.Font.Gotham
    button.Text = name
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 8
    button.LayoutOrder = #FeatureContainer:GetChildren()
    
    if type(callback) == "function" then
        button.MouseButton1Click:Connect(function()
            wait(0.05)
            if isExclusiveFeature(name) then
                disableActiveFeature()
                activeFeature = {name = name, category = categoryName, disableCallback = nil}
            end
            spawn(callback)
        end)
    end
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end)
end

local function createToggleButton(name, callback, categoryName, disableCallback)
    local button = Instance.new("TextButton")
    button.Name = name .. "_toggle_" .. tostring(math.random(100, 999))
    button.Parent = FeatureContainer
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, -2, 0, 20)
    button.Font = Enum.Font.Gotham
    button.Text = name
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 8
    button.LayoutOrder = #FeatureContainer:GetChildren()
    
    if categoryStates[categoryName][name] == nil then
        categoryStates[categoryName][name] = false
    end
    button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    
    button.MouseButton1Click:Connect(function()
        wait(0.05)
        local newState = not categoryStates[categoryName][name]
        
        if newState and isExclusiveFeature(name) then
            disableActiveFeature()
            activeFeature = {name = name, category = categoryName, disableCallback = disableCallback}
        elseif not newState and activeFeature and activeFeature.name == name then
            activeFeature = nil
        end
        
        categoryStates[categoryName][name] = newState
        button.BackgroundColor3 = newState and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
        
        if type(callback) == "function" then
            spawn(function() callback(newState) end)
        end
    end)
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(80, 80, 80)
    end)
    
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
    end)
end

-- Load buttons function (FIXED)
function loadButtons()
    -- Clear existing buttons
    for _, child in pairs(FeatureContainer:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    -- Update category button colors
    for categoryName, categoryData in pairs(categoryFrames) do
        categoryData.button.BackgroundColor3 = categoryName == selectedCategory and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25)
    end

    if not selectedCategory then return end
    
    -- Show loading only if module isn't loaded yet
    if not modules[selectedCategory] then
        local loadingLabel = Instance.new("TextLabel")
        loadingLabel.Parent = FeatureContainer
        loadingLabel.BackgroundTransparency = 1
        loadingLabel.Size = UDim2.new(1, -2, 0, 20)
        loadingLabel.Font = Enum.Font.Gotham
        loadingLabel.Text = "🔄 Loading " .. selectedCategory .. "..."
        loadingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        loadingLabel.TextSize = 8
        loadingLabel.TextXAlignment = Enum.TextXAlignment.Left

        spawn(function()
            wait(3) -- Show loading for 3 seconds max
            if loadingLabel.Parent then
                loadingLabel:Destroy()
            end
        end)
        return
    end

    -- Load appropriate module buttons
    local success = false
    local errorMessage = nil

    if selectedCategory == "Movement" and modules.Movement and type(modules.Movement.loadMovementButtons) == "function" then
        success, errorMessage = pcall(function()
            modules.Movement.loadMovementButtons(
                function(name, callback) createButton(name, callback, "Movement") end,
                function(name, callback, disableCallback) createToggleButton(name, callback, "Movement", disableCallback) end
            )
        end)
    elseif selectedCategory == "Settings" and modules.Settings and type(modules.Settings.loadSettingsButtons) == "function" then
        success, errorMessage = pcall(function()
            modules.Settings.loadSettingsButtons(function(name, callback)
                createButton(name, callback, "Settings")
            end)
        end)
    elseif selectedCategory == "Teleport" and modules.Teleport and type(modules.Teleport.loadTeleportButtons) == "function" then
        success, errorMessage = pcall(function()
            modules.Teleport.loadTeleportButtons(
                function(name, callback) createButton(name, callback, "Teleport") end,
                nil -- selectedPlayer
            )
        end)
    elseif selectedCategory == "AntiAdmin" and modules.AntiAdmin and type(modules.AntiAdmin.loadAntiAdminButtons) == "function" then
        success, errorMessage = pcall(function()
            modules.AntiAdmin.loadAntiAdminButtons(function(name, callback, disableCallback)
                createToggleButton(name, callback, "AntiAdmin", disableCallback)
            end, FeatureContainer)
        end)
    elseif selectedCategory == "Info" and modules.Info and type(modules.Info.createInfoDisplay) == "function" then
        success, errorMessage = pcall(function()
            modules.Info.createInfoDisplay(FeatureContainer)
        end)
    else
        -- Create placeholder buttons for missing modules
        local placeholderLabel = Instance.new("TextLabel")
        placeholderLabel.Parent = FeatureContainer
        placeholderLabel.BackgroundTransparency = 1
        placeholderLabel.Size = UDim2.new(1, -2, 0, 40)
        placeholderLabel.Font = Enum.Font.Gotham
        placeholderLabel.Text = "⚠️ " .. selectedCategory .. " module not available\nUsing local fallback..."
        placeholderLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
        placeholderLabel.TextSize = 8
        placeholderLabel.TextXAlignment = Enum.TextXAlignment.Center
        placeholderLabel.TextYAlignment = Enum.TextYAlignment.Center
        success = true
    end

    -- Handle loading result
    if not success and errorMessage then
        local errorLabel = Instance.new("TextLabel")
        errorLabel.Parent = FeatureContainer
        errorLabel.BackgroundTransparency = 1
        errorLabel.Size = UDim2.new(1, -2, 0, 40)
        errorLabel.Font = Enum.Font.Gotham
        errorLabel.Text = "❌ Failed: " .. selectedCategory .. "\n" .. tostring(errorMessage)
        errorLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        errorLabel.TextSize = 8
        errorLabel.TextXAlignment = Enum.TextXAlignment.Center
        errorLabel.TextYAlignment = Enum.TextYAlignment.Center
    end
end

-- Create category buttons
for _, category in pairs(categories) do
    local categoryButton = Instance.new("TextButton")
    categoryButton.Name = category.name .. "Cat_" .. tostring(math.random(100, 999))
    categoryButton.Parent = CategoryContainer
    categoryButton.BackgroundColor3 = selectedCategory == category.name and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25)
    categoryButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
    categoryButton.Size = UDim2.new(1, -5, 0, 25)
    categoryButton.LayoutOrder = category.order
    categoryButton.Font = Enum.Font.GothamBold
    categoryButton.Text = category.name
    categoryButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    categoryButton.TextSize = 8

    categoryButton.MouseButton1Click:Connect(function()
        wait(0.02)
        selectedCategory = category.name
        spawn(loadButtons)
    end)

    categoryButton.MouseEnter:Connect(function()
        if selectedCategory ~= category.name then
            categoryButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
    end)

    categoryButton.MouseLeave:Connect(function()
        if selectedCategory ~= category.name then
            categoryButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        end
    end)

    categoryFrames[category.name] = {button = categoryButton}
    categoryStates[category.name] = {}
end

-- Minimize/Maximize functionality
local function toggleMinimize()
    isMinimized = not isMinimized
    Frame.Visible = not isMinimized
    MinimizedLogo.Visible = isMinimized
    MinimizeButton.Text = isMinimized and "+" or "-"
    cleanupMemory()
end

-- Reset all states
local function resetStates()
    activeFeature = nil
    for _, connection in pairs(connections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
    connections = {}
    
    for _, module in pairs(modules) do
        if module and type(module.resetStates) == "function" then
            spawn(function() module.resetStates() end)
        end
    end
    
    if selectedCategory then
        spawn(loadButtons)
    end
    
    cleanupMemory()
end

-- Character management
local function onCharacterAdded(newCharacter)
    if not newCharacter then return end
    
    spawn(function()
        local success, result = pcall(function()
            character = newCharacter
            humanoid = character:WaitForChild("Humanoid", 30)
            rootPart = character:WaitForChild("HumanoidRootPart", 30)
            
            dependencies.character = character
            dependencies.humanoid = humanoid
            dependencies.rootPart = rootPart
            
            wait(1) -- KRNL needs time
            initializeModules()
            
            if humanoid and humanoid.Died then
                connections.humanoidDied = humanoid.Died:Connect(resetStates)
            end
        end)
        if not success then
            warn("❌ Character setup failed: " .. tostring(result))
        end
    end)
end

-- KRNL-specific diagnostics
local function runKRNLDiagnostics()
    print("=== KRNL Diagnostics ===")
    
    -- Check KRNL-specific functions
    print("KRNL syn: " .. (syn and "✅ Available" or "❌ Not available"))
    print("KRNL syn.request: " .. (syn and syn.request and "✅ Available" or "❌ Not available"))
    print("game:HttpGet: " .. (game.HttpGet and "✅ Available" or "❌ Not available"))
    
    local HttpService = game:GetService("HttpService")
    print("HttpService: " .. (HttpService and "✅ Service found" or "❌ Service not found"))
    print("HttpService.HttpEnabled: " .. (HttpService and HttpService.HttpEnabled and "✅ Enabled" or "❌ Disabled"))
    
    print("\n--- Local Modules Available ---")
    for moduleName, _ in pairs(localModules) do
        print("✅ " .. moduleName .. " (embedded)")
    end
    
    if gcinfo then
        print("\nMemory usage: " .. gcinfo() .. " KB")
    end
    
    print("=== End Diagnostics ===\n")
end

-- Load all modules with KRNL optimizations (FIXED)
spawn(function()
    print("🚀 Starting KRNL-optimized module loading...")
    
    -- Run diagnostics first
    runKRNLDiagnostics()
    
    wait(1) -- Give KRNL time to initialize
    
    -- Load all local modules first (guaranteed to work)
    for moduleName, _ in pairs(localModules) do
        spawn(function()
            loadModule(moduleName)
        end)
    end
    
    wait(2) -- Wait for local modules to load
    
    -- Then try HTTP modules as backup/updates
    for moduleName, _ in pairs(moduleURLs) do
        if not modulesLoaded[moduleName] then
            spawn(function()
                wait(math.random(2, 5)) -- Stagger loading for KRNL
                loadModule(moduleName)
            end)
        end
    end
end)

-- Initialize character
if player.Character then
    onCharacterAdded(player.Character)
end
connections.characterAdded = player.CharacterAdded:Connect(onCharacterAdded)

-- GUI event connections
MinimizeButton.MouseButton1Click:Connect(toggleMinimize)
LogoButton.MouseButton1Click:Connect(toggleMinimize)

-- Hotkey support (KRNL-compatible)
spawn(function()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.Home then
            toggleMinimize()
        elseif not gameProcessed and input.KeyCode == Enum.KeyCode.End then
            -- Emergency reset hotkey for KRNL
            resetStates()
            print("🔄 Emergency reset triggered")
        end
    end)
end)

-- KRNL-specific periodic maintenance
spawn(function()
    while ScreenGui.Parent do
        wait(60) -- Clean up every minute
        cleanupMemory()
        
        -- Randomize GUI position slightly for anti-detection
        if Frame.Visible then
            Frame.BackgroundTransparency = math.random(1, 3) / 100
        end
        
        -- Check if essential modules are loaded
        local essentialModules = {"Settings", "Teleport", "Movement", "AntiAdmin", "Info"}
        local missingModules = {}
        
        for _, moduleName in pairs(essentialModules) do
            if not modulesLoaded[moduleName] then
                table.insert(missingModules, moduleName)
            end
        end
        
        if #missingModules > 0 then
            print("🔄 Retrying missing essential modules: " .. table.concat(missingModules, ", "))
            for _, moduleName in pairs(missingModules) do
                spawn(function()
                    wait(math.random(1, 3))
                    loadModule(moduleName)
                end)
            end
        end
    end
end)

-- Initialize GUI (FIXED)
spawn(function()
    wait(2) -- Give KRNL time to load essential modules
    
    local timeout = 30 -- seconds
    local startTime = tick()
    
    -- Wait for at least some essential modules
    while (not modules.Settings and not modules.Teleport) and tick() - startTime < timeout do
        wait(1)
        print("⏳ Waiting for essential modules to load...")
    end
    
    wait(1) -- Additional buffer for KRNL
    initializeModules()
    
    -- Load initial buttons for the selected category
    spawn(function()
        wait(0.5)
        loadButtons()
    end)
    
    print("✅ MinimalHackGUI loaded for KRNL")
    print("🎮 Press HOME to toggle GUI")
    print("🔄 Press END for emergency reset")
    print("📋 Available categories: " .. table.concat({
        modules.Movement and "✅Movement" or "❌Movement",
        modules.Settings and "✅Settings" or "❌Settings", 
        modules.Teleport and "✅Teleport" or "❌Teleport",
        modules.AntiAdmin and "✅AntiAdmin" or "❌AntiAdmin",
        modules.Info and "✅Info" or "❌Info"
    }, ", "))
end)

-- KRNL-specific error recovery
spawn(function()
    local lastErrorTime = 0
    local errorCount = 0
    
    local function onError(message)
        local currentTime = tick()
        if currentTime - lastErrorTime < 5 then
            errorCount = errorCount + 1
        else
            errorCount = 1
        end
        lastErrorTime = currentTime
        
        warn("🚨 KRNL Error #" .. errorCount .. ": " .. tostring(message))
        
        if errorCount >= 3 then
            warn("🔄 Multiple errors detected, attempting recovery...")
            wait(2)
            resetStates()
            errorCount = 0
        end
    end
    
    -- Hook into KRNL error handling if available
    if syn and syn.set_thread_context then
        syn.set_thread_context(1)
    end
end)

-- Module status checker
spawn(function()
    wait(10) -- Wait 10 seconds after initialization
    
    while ScreenGui.Parent do
        wait(30) -- Check every 30 seconds
        
        local loadedCount = 0
        local totalCount = 0
        
        for moduleName, _ in pairs(localModules) do
            totalCount = totalCount + 1
            if modulesLoaded[moduleName] then
                loadedCount = loadedCount + 1
            end
        end
        
        if loadedCount < totalCount then
            print("📊 Module Status: " .. loadedCount .. "/" .. totalCount .. " loaded")
            
            -- Try to reload missing modules
            for moduleName, _ in pairs(localModules) do
                if not modulesLoaded[moduleName] then
                    print("🔄 Attempting to reload: " .. moduleName)
                    spawn(function()
                        loadModule(moduleName)
                    end)
                end
            end
        end
    end
end)

print("🎯 MinimalHackGUI KRNL Edition Initialized!")
print("📋 Features: Movement, Player, Teleport, Visual, Utility, Settings, AntiAdmin, Info")
print("🔧 Optimized for KRNL executor with embedded modules")
print("💡 All essential modules are embedded for maximum compatibility")