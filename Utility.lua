local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local Utility = {}
Utility.adminAccessEnabled = false
local connections = {}

-- Load AntiAdmin.lua
function Utility.loadAntiAdmin()
    local success, errorMsg = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/main/AntiAdmin.lua", true))()
    end)
    if not success then
        warn("Failed to load AntiAdmin.lua: " .. tostring(errorMsg))
    else
        print("Anti Admin Loaded - By Fari Noveri")
    end
end

-- Admin Access
function Utility.toggleAdminAccess(enabled)
    Utility.adminAccessEnabled = enabled
    if enabled then
        -- Attempt to grant admin access by hooking into common admin systems
        local success, errorMsg = pcall(function()
            -- Check for common admin scripts (e.g., Kohl's Admin, HD Admin)
            local adminScripts = {
                "KohlsAdmin",
                "HDAdmin",
                "Adonis_Client",
                "CommandBar"
            }
            
            for _, scriptName in pairs(adminScripts) do
                local adminModule = game:GetService("ReplicatedStorage"):FindFirstChild(scriptName) or
                                    game:GetService("ServerScriptService"):FindFirstChild(scriptName) or
                                    game:GetService("CoreGui"):FindFirstChild(scriptName)
                if adminModule then
                    -- Attempt to override admin checks
                    local success, module = pcall(require, adminModule)
                    if success and type(module) == "table" then
                        -- Hook into command execution
                        if module.ExecuteCommand then
                            local oldExecute = module.ExecuteCommand
                            module.ExecuteCommand = function(...)
                                local args = {...}
                                -- Ensure player has admin privileges
                                if args[1] == player or args[1] == player.Name then
                                    return oldExecute(...)
                                else
                                    -- Simulate admin privilege
                                    args[1] = player
                                    return oldExecute(unpack(args))
                                end
                            end
                        end
                    end
                end
            end
            
            -- Create a command bar if none exists
            local commandBar = Instance.new("ScreenGui")
            commandBar.Name = "CustomCommandBar"
            commandBar.Parent = game:GetService("CoreGui")
            local commandInput = Instance.new("TextBox")
            commandInput.Name = "CommandInput"
            commandInput.Parent = commandBar
            commandInput.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            commandInput.BorderSizePixel = 0
            commandInput.Position = UDim2.new(0, 10, 0, 10)
            commandInput.Size = UDim2.new(0, 200, 0, 30)
            commandInput.Font = Enum.Font.Gotham
            commandInput.Text = "Enter command..."
            commandInput.TextColor3 = Color3.fromRGB(255, 255, 255)
            commandInput.TextSize = 12
            
            connections.commandBar = commandInput.FocusLost:Connect(function(enterPressed)
                if enterPressed and commandInput.Text ~= "" and commandInput.Text ~= "Enter command..." then
                    local command = commandInput.Text
                    -- Execute common admin commands
                    local commandMap = {
                        ["fly"] = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/main/movement.lua", true))().toggleFly(true) end,
                        ["noclip"] = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/main/movement.lua", true))().toggleNoclip(true) end,
                        ["speed"] = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/main/movement.lua", true))().toggleSpeed(true) end,
                        ["god"] = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/main/player.lua", true))().toggleGodMode(true) end
                    }
                    if commandMap[command:lower()] then
                        commandMap[command:lower()]()
                        print("Executed command: " .. command)
                    else
                        print("Unknown command: " .. command)
                    end
                    commandInput.Text = "Enter command..."
                end
            end)
        end)
        if not success then
            warn("Failed to enable admin access: " .. tostring(errorMsg))
        else
            print("Admin access enabled")
        end
    else
        if connections.commandBar then
            connections.commandBar:Disconnect()
        end
        if game:GetService("CoreGui"):FindFirstChild("CustomCommandBar") then
            game:GetService("CoreGui").CustomCommandBar:Destroy()
        end
        print("Admin access disabled")
    end
end

-- Cleanup
function Utility.cleanup()
    Utility.toggleAdminAccess(false)
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
end

-- Initialize AntiAdmin
Utility.loadAntiAdmin()

return Utility