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
-- MODULE LOADING SYSTEM
-- ============================================
local modules = {}
local moduleURLs = {
    Movement = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/FluentModules/Movement.lua",
    Player = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/FluentModules/Player.lua",
    Teleport = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/FluentModules/Teleport.lua",
    Visual = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/FluentModules/Visual.lua",
    Utility = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/FluentModules/Utility.lua",
    AntiAdmin = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/FluentModules/AntiAdmin.lua",
}

-- Dependencies for modules
local dependencies = {
    Fluent = Fluent,
    Window = Window,
    Players = Players,
    UserInputService = UserInputService,
    RunService = RunService,
    Workspace = Workspace,
    Lighting = Lighting,
    player = player,
    character = character,
    humanoid = humanoid,
    rootPart = rootPart,
    connections = connections,
    activeStates = activeStates
}

-- Load module from URL
local function loadModule(moduleName, tab)
    print("Loading module: " .. moduleName)
    
    local success, result = pcall(function()
        local response = game:HttpGet(moduleURLs[moduleName])
        if not response or response == "" then
            error("Failed to fetch module")
        end
        
        local moduleFunc = loadstring(response)
        if not moduleFunc then
            error("Failed to compile module")
        end
        
        local moduleTable = moduleFunc()
        if type(moduleTable) ~= "table" or type(moduleTable.init) ~= "function" then
            error("Invalid module structure")
        end
        
        return moduleTable
    end)
    
    if success and result then
        modules[moduleName] = result
        -- Initialize module with tab
        local initSuccess, initError = pcall(function()
            result.init(tab, dependencies)
        end)
        
        if initSuccess then
            print("✓ Module loaded: " .. moduleName)
        else
            warn("✗ Failed to initialize: " .. moduleName .. " - " .. tostring(initError))
        end
    else
        warn("✗ Failed to load: " .. moduleName .. " - " .. tostring(result))
    end
end

-- Load all modules
for moduleName, tab in pairs(Tabs) do
    if moduleURLs[moduleName] then
        task.spawn(function()
            loadModule(moduleName, tab)
        end)
    end
end

-- Settings Tab (built-in, no external module needed)
do
    local SettingsSection = Tabs.Settings:AddSection("GUI Settings")
    
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