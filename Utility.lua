local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Variabel untuk fitur Utility
local infiniteYieldEnabled = false
local commandEnabled = false

-- Connections untuk Utility
local connections = {}

-- GUI Creation untuk Command Input
local ScreenGui = Instance.new("ScreenGui")
local CommandFrame = Instance.new("Frame")
local CommandTitle = Instance.new("TextLabel")
local CloseCommandButton = Instance.new("TextButton")
local CommandInput = Instance.new("TextBox")
local ExecuteCommandButton = Instance.new("TextButton")

-- GUI Properties
ScreenGui.Name = "UtilityHackGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Command Frame
CommandFrame.Name = "CommandFrame"
CommandFrame.Parent = ScreenGui
CommandFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
CommandFrame.BorderColor3 = Color3.fromRGB(45, 45, 45)
CommandFrame.BorderSizePixel = 1
CommandFrame.Position = UDim2.new(0.4, 0, 0.3, 0)
CommandFrame.Size = UDim2.new(0, 300, 0, 150)
CommandFrame.Visible = false
CommandFrame.Active = true
CommandFrame.Draggable = true

-- Command Frame Title
CommandTitle.Name = "Title"
CommandTitle.Parent = CommandFrame
CommandTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
CommandTitle.BorderSizePixel = 0
CommandTitle.Position = UDim2.new(0, 0, 0, 0)
CommandTitle.Size = UDim2.new(1, 0, 0, 35)
CommandTitle.Font = Enum.Font.Gotham
CommandTitle.Text = "COMMAND EXECUTOR"
CommandTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
CommandTitle.TextSize = 12

-- Close Command Frame Button
CloseCommandButton.Name = "CloseButton"
CloseCommandButton.Parent = CommandFrame
CloseCommandButton.BackgroundTransparency = 1
CloseCommandButton.Position = UDim2.new(1, -30, 0, 5)
CloseCommandButton.Size = UDim2.new(0, 25, 0, 25)
CloseCommandButton.Font = Enum.Font.GothamBold
CloseCommandButton.Text = "X"
CloseCommandButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseCommandButton.TextSize = 12

-- Command Input
CommandInput.Name = "CommandInput"
CommandInput.Parent = CommandFrame
CommandInput.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
CommandInput.BorderSizePixel = 0
CommandInput.Position = UDim2.new(0, 10, 0, 45)
CommandInput.Size = UDim2.new(1, -20, 0, 30)
CommandInput.Font = Enum.Font.Gotham
CommandInput.PlaceholderText = "Enter command (e.g., :admin me)"
CommandInput.Text = ""
CommandInput.TextColor3 = Color3.fromRGB(255, 255, 255)
CommandInput.TextSize = 11

-- Execute Command Button
ExecuteCommandButton.Name = "ExecuteButton"
ExecuteCommandButton.Parent = CommandFrame
ExecuteCommandButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
ExecuteCommandButton.BorderSizePixel = 0
ExecuteCommandButton.Position = UDim2.new(0, 10, 0, 85)
ExecuteCommandButton.Size = UDim2.new(1, -20, 0, 30)
ExecuteCommandButton.Font = Enum.Font.Gotham
ExecuteCommandButton.Text = "EXECUTE"
ExecuteCommandButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ExecuteCommandButton.TextSize = 10

-- Infinite Yield
local function toggleInfiniteYield(enabled)
    infiniteYieldEnabled = enabled
    if enabled then
        connections.infiniteyield = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if infiniteYieldEnabled and humanoid.Health <= 0 then
                humanoid.Health = humanoid.MaxHealth
                print("Infinite Yield: Health restored")
            end
        end)
    else
        if connections.infiniteyield then
            connections.infiniteyield:Disconnect()
        end
    end
end

-- Command Admin Bypass
local function toggleCommand(enabled)
    commandEnabled = enabled
    CommandFrame.Visible = enabled
    if enabled then
        -- Mencari RemoteEvent/RemoteFunction yang mungkin terkait admin
        local potentialRemotes = {}
        for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                if obj.Name:lower():match("admin") or obj.Name:lower():match("command") or obj.Name:lower():match("execute") then
                    table.insert(potentialRemotes, obj)
                end
            end
        end
        print("Found " .. #potentialRemotes .. " potential admin remotes")
        
        -- Fungsi untuk mengeksekusi command
        local function executeCommand()
            local command = CommandInput.Text
            if command == "" then
                print("No command entered")
                return
            end
            
            -- Log command ke file untuk debugging
            if pcall(function() return writefile end) then
                pcall(function()
                    makefolder("DCIM/Supertool")
                    local logFile = "DCIM/Supertool/command_log.txt"
                    local logContent = (readfile(logFile) or "") .. os.date("[%Y-%m-%d %H:%M:%S] ") .. command .. "\n"
                    writefile(logFile, logContent)
                end)
            end
            
            -- Coba bypass admin dengan mengirimkan command ke setiap remote yang ditemukan
            for _, remote in pairs(potentialRemotes) do
                local success, result = pcall(function()
                    if remote:IsA("RemoteEvent") then
                        remote:FireServer(command)
                    elseif remote:IsA("RemoteFunction") then
                        return remote:InvokeServer(command)
                    end
                end)
                if success then
                    print("Sent command '" .. command .. "' to " .. remote.Name)
                else
                    warn("Failed to send command to " .. remote.Name .. ": " .. tostring(result))
                end
            end
            
            -- Coba spoofing data pemain untuk mendapatkan akses admin
            local adminCommands = {":admin me", ":setadmin", ":giveadmin", "admin", "give admin"}
            for _, cmd in pairs(adminCommands) do
                if command:lower():match(cmd:lower()) then
                    for _, remote in pairs(potentialRemotes) do
                        pcall(function()
                            if remote:IsA("RemoteEvent") then
                                remote:FireServer({player.UserId, "admin", true})
                            elseif remote:IsA("RemoteFunction") then
                                remote:InvokeServer({player.UserId, "admin", true})
                            end
                        end)
                    end
                    print("Attempted admin bypass with command: " .. command)
                end
            end
            
            CommandInput.Text = ""
        end
        
        ExecuteCommandButton.MouseButton1Click:Connect(executeCommand)
        CommandInput.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                executeCommand()
            end
        end)
        
        ExecuteCommandButton.MouseEnter:Connect(function()
            ExecuteCommandButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        end)
        
        ExecuteCommandButton.MouseLeave:Connect(function()
            ExecuteCommandButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end)
    else
        CommandFrame.Visible = false
    end
end

-- Event Connections
CloseCommandButton.MouseButton1Click:Connect(function()
    CommandFrame.Visible = false
end)

-- Handle character reset untuk Utility
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Reset fitur Utility saat karakter respawn
    infiniteYieldEnabled = false
    commandEnabled = false
    
    toggleInfiniteYield(false)
    toggleCommand(false)
end)

-- Cleanup saat script dihancurkan
local function cleanup()
    -- Matikan semua fitur Utility
    toggleInfiniteYield(false)
    toggleCommand(false)
    
    -- Putuskan semua koneksi
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    -- Hapus GUI
    if ScreenGui then
        ScreenGui:Destroy()
    end
end

-- Tangani penutupan game atau script
game:BindToClose(cleanup)

print("Utility Features Loaded")