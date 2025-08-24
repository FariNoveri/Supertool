-- MinimalHackGUI by Fari Noveri - KRNL Optimized Version
-- Fixed for KRNL executor with better HTTP handling

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
                -- KRNL sometimes needs this check
                if not HttpService or not HttpService.HttpEnabled then
                    error("HttpService not available or disabled")
                end
                
                -- KRNL-specific: Use game:HttpGet if available
                if game.HttpGet then
                    return game:HttpGet(url, true)
                else
                    return HttpService:GetAsync(url)
                end
            end)
            
            if success and response and response ~= "" and not response:match("^%s*$") then
                print("✓ Loaded from: " .. url)
                return response
            else
                local errorMsg = success and "Empty response" or tostring(response)
                warn("✗ Attempt " .. attempt .. " failed: " .. errorMsg)
                
                -- KRNL-specific error handling
                if errorMsg:find("HttpService") then
                    warn("HttpService issue - trying alternative method")
                    -- Try alternative HTTP method for KRNL
                    local altSuccess, altResponse = pcall(function()
                        return syn and syn.request and syn.request({Url = url, Method = "GET"}).Body or nil
                    end)
                    if altSuccess and altResponse then
                        return altResponse
                    end
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
    WalkSpeed = {value = 16, min = 10, max = 200, default = 16}
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
            if collectgarbage then
                collectgarbage("collect")
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

-- KRNL-compatible module URLs with multiple fallbacks
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

-- Local AntiAdmin Module (embedded for KRNL)
local localModules = {
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
    end
}

-- Modules
local modules = {}
local modulesLoaded = {}

-- KRNL-optimized module loader
local function loadModule(moduleName)
    print("🔄 Loading module: " .. moduleName)
    
    -- Try local module first
    if localModules[moduleName] then
        local success, result = pcall(function()
            return localModules[moduleName]()
        end)
        if success and result then
            modules[moduleName] = result
            modulesLoaded[moduleName] = true
            print("✅ Local module loaded: " .. moduleName)
            if selectedCategory == moduleName then
                spawn(loadButtons)
            end
            return true
        else
            warn("❌ Local module failed: " .. moduleName .. " - " .. tostring(result))
        end
    end

    -- Try ReplicatedStorage module
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
                spawn(loadButtons)
            end
            return true
        else
            warn("❌ ReplicatedStorage module failed: " .. moduleName)
        end
    end

    -- HTTP loading with KRNL optimizations
    if not moduleURLs[moduleName] then
        warn("❌ No URLs for module: " .. moduleName)
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
                spawn(loadButtons)
            end
            return true
        else
            warn("❌ URL " .. urlIndex .. " failed: " .. tostring(result))
        end
    end
    
    warn("❌ All URLs failed for: " .. moduleName)
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

-- Load buttons function
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
    
    -- Loading indicator
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
        wait(0.3)
        
        local success = false
        local errorMessage = nil

        -- Load appropriate module buttons
        if selectedCategory == "Movement" and modules.Movement and type(modules.Movement.loadMovementButtons) == "function" then
            success, errorMessage = pcall(function()
                modules.Movement.loadMovementButtons(
                    function(name, callback) createButton(name, callback, "Movement") end,
                    function(name, callback, disableCallback) createToggleButton(name, callback, "Movement", disableCallback) end
                )
            end)
        elseif selectedCategory == "Player" and modules.Player and type(modules.Player.loadPlayerButtons) == "function" then
            success, errorMessage = pcall(function()
                local selectedPlayer = modules.Player.getSelectedPlayer and modules.Player.getSelectedPlayer() or nil
                modules.Player.loadPlayerButtons(
                    function(name, callback) createButton(name, callback, "Player") end,
                    function(name, callback, disableCallback) createToggleButton(name, callback, "Player", disableCallback) end,
                    selectedPlayer
                )
            end)
        elseif selectedCategory == "Teleport" and modules.Teleport and type(modules.Teleport.loadTeleportButtons) == "function" then
            success, errorMessage = pcall(function()
                local selectedPlayer = modules.Player and modules.Player.getSelectedPlayer and modules.Player.getSelectedPlayer() or nil
                modules.Teleport.loadTeleportButtons(
                    function(name, callback) createButton(name, callback, "Teleport") end,
                    selectedPlayer
                )
            end)
        elseif selectedCategory == "Visual" and modules.Visual and type(modules.Visual.loadVisualButtons) == "function" then
            success, errorMessage = pcall(function()
                modules.Visual.loadVisualButtons(function(name, callback, disableCallback)
                    createToggleButton(name, callback, "Visual", disableCallback)
                end)
            end)
        elseif selectedCategory == "Utility" and modules.Utility and type(modules.Utility.loadUtilityButtons) == "function" then
            success, errorMessage = pcall(function()
                modules.Utility.loadUtilityButtons(function(name, callback)
                    createButton(name, callback, "Utility")
                end)
            end)
        elseif selectedCategory == "Settings" and modules.Settings and type(modules.Settings.loadSettingsButtons) == "function" then
            success, errorMessage = pcall(function()
                modules.Settings.loadSettingsButtons(function(name, callback)
                    createButton(name, callback, "Settings")
                end)
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
        end

        -- Handle loading result
        if loadingLabel and loadingLabel.Parent then
            if not success then
                loadingLabel.Text = "❌ Failed: " .. selectedCategory .. " - " .. tostring(errorMessage)
                loadingLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
                wait(3)
                if loadingLabel.Parent then loadingLabel:Destroy() end
            else
                loadingLabel:Destroy()
            end
        end
    end)
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
    print("KRNL Environment: " .. (syn and "✅ Detected" or "❌ Not detected"))
    print("HttpService: " .. (game:GetService("HttpService").HttpEnabled and "✅ Enabled" or "❌ Disabled"))
    
    -- Test HTTP
    local testSuccess = pcall(function()
        local response = safeHttpGet("https://httpbin.org/get")
        return response and response ~= ""
    end)
    print("HTTP Test: " .. (testSuccess and "✅ Working" or "❌ Failed"))
    
    -- Test GitHub
    local githubSuccess = pcall(function()
        local response = safeHttpGet("https://raw.githubusercontent.com/octocat/Hello-World/master/README")
        return response and response ~= ""
    end)
    print("GitHub Access: " .. (githubSuccess and "✅ Working" or "❌ Failed"))
    
    print("=== End Diagnostics ===")
end

-- Load all modules with KRNL optimizations
spawn(function()
    print("🚀 Starting KRNL-optimized module loading...")
    
    -- Run diagnostics first
    runKRNLDiagnostics()
    
    wait(2) -- Give KRNL time to initialize
    
    for moduleName, _ in pairs(moduleURLs) do
        spawn(function()
            wait(math.random(2, 5)) -- Stagger loading for KRNL
            loadModule(moduleName)
        end)
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
        
        -- Check if modules need reloading
        local failedModules = {}
        for moduleName, _ in pairs(moduleURLs) do
            if not modulesLoaded[moduleName] then
                table.insert(failedModules, moduleName)
            end
        end
        
        if #failedModules > 0 then
            print("🔄 Retrying failed modules: " .. table.concat(failedModules, ", "))
            for _, moduleName in pairs(failedModules) do
                spawn(function()
                    wait(math.random(1, 3))
                    loadModule(moduleName)
                end)
            end
        end
    end
end)

-- Initialize GUI
spawn(function()
    wait(3) -- Give KRNL time to load
    
    local timeout = 60 -- seconds
    local startTime = tick()
    
    -- Wait for essential modules
    while (not modules.AntiAdmin) and tick() - startTime < timeout do
        wait(1)
    end
    
    wait(2) -- Additional buffer for KRNL
    initializeModules()
    spawn(loadButtons)
    
    print("✅ MinimalHackGUI loaded for KRNL")
    print("🎮 Press HOME to toggle GUI")
    print("🔄 Press END for emergency reset")
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

print("🎯 MinimalHackGUI KRNL Edition Initialized!")
print("📋 Features: Movement, Player, Teleport, Visual, Utility, Settings, AntiAdmin, Info")
print("🔧 Optimized for KRNL executor")