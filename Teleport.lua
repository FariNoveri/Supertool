local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

local Teleport = {}
Teleport.freecamEnabled = false
Teleport.savedPositions = {}
Teleport.freecamPosition = nil
local connections = {}
local settings = {
    FreecamSpeed = { value = 80, default = 80, min = 20, max = 300 }
}
local directory = "dcim/supertool"

-- Ensure directory exists
if not isfolder(directory) then
    makefolder(directory)
end

-- Load saved positions from dcim/supertool
function Teleport.loadSavedPositions()
    Teleport.savedPositions = {}
    local files = listfiles(directory)
    for _, file in pairs(files) do
        local success, content = pcall(readfile, file)
        if success then
            local success, data = pcall(function() return HttpService:JSONDecode(content) end)
            if success and data.name and data.position then
                Teleport.savedPositions[data.name] = {
                    position = Vector3.new(data.position.x, data.position.y, data.position.z),
                    file = file
                }
            end
        end
    end
    Teleport.updatePositionList()
end

-- Save position to file
function Teleport.savePositionToFile(name, position)
    local data = {
        name = name,
        position = { x = position.X, y = position.Y, z = position.Z }
    }
    local json = HttpService:JSONEncode(data)
    local filename = directory .. "/" .. HttpService:GenerateGUID(false) .. ".json"
    writefile(filename, json)
    Teleport.savedPositions[name] = { position = position, file = filename }
    Teleport.updatePositionList()
end

-- Rename position
function Teleport.renamePosition(oldName, newName)
    if Teleport.savedPositions[oldName] and not Teleport.savedPositions[newName] then
        local data = Teleport.savedPositions[oldName]
        local newData = {
            name = newName,
            position = { x = data.position.X, y = data.position.Y, z = data.position.Z }
        }
        local json = HttpService:JSONEncode(newData)
        writefile(data.file, json)
        Teleport.savedPositions[newName] = { position = data.position, file = data.file }
        Teleport.savedPositions[oldName] = nil
        Teleport.updatePositionList()
    end
end

-- Delete position
function Teleport.deletePosition(name)
    if Teleport.savedPositions[name] then
        local file = Teleport.savedPositions[name].file
        delfile(file)
        Teleport.savedPositions[name] = nil
        Teleport.updatePositionList()
    end
end

-- Update position list GUI
function Teleport.updatePositionList()
    local PositionScrollFrame = Teleport.PositionScrollFrame
    local PositionLayout = Teleport.PositionLayout
    if not (PositionScrollFrame and PositionLayout) then
        return
    end
    for _, child in pairs(PositionScrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    local index = 0
    for name, data in pairs(Teleport.savedPositions) do
        index = index + 1
        local posFrame = Instance.new("Frame")
        posFrame.Name = name
        posFrame.Parent = PositionScrollFrame
        posFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        posFrame.BorderSizePixel = 0
        posFrame.Size = UDim2.new(1, -5, 0, 90)
        posFrame.LayoutOrder = index

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.Parent = posFrame
        nameLabel.BackgroundTransparency = 1
        nameLabel.Position = UDim2.new(0, 5, 0, 5)
        nameLabel.Size = UDim2.new(1, -10, 0, 20)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Text = name
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize = 12
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left

        local teleportButton = Instance.new("TextButton")
        teleportButton.Name = "TeleportButton"
        teleportButton.Parent = posFrame
        teleportButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
        teleportButton.BorderSizePixel = 0
        teleportButton.Position = UDim2.new(0, 5, 0, 30)
        teleportButton.Size = UDim2.new(0, 70, 0, 25)
        teleportButton.Font = Enum.Font.Gotham
        teleportButton.Text = "TELEPORT"
        teleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        teleportButton.TextSize = 10

        local renameInput = Instance.new("TextBox")
        renameInput.Name = "RenameInput"
        renameInput.Parent = posFrame
        renameInput.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        renameInput.BorderSizePixel = 0
        renameInput.Position = UDim2.new(0, 80, 0, 30)
        renameInput.Size = UDim2.new(0, 100, 0, 25)
        renameInput.Font = Enum.Font.Gotham
        renameInput.Text = "Rename..."
        renameInput.TextColor3 = Color3.fromRGB(200, 200, 200)
        renameInput.TextSize = 10

        local deleteButton = Instance.new("TextButton")
        deleteButton.Name = "DeleteButton"
        deleteButton.Parent = posFrame
        deleteButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
        deleteButton.BorderSizePixel = 0
        deleteButton.Position = UDim2.new(0, 185, 0, 30)
        deleteButton.Size = UDim2.new(0, 70, 0, 25)
        deleteButton.Font = Enum.Font.Gotham
        deleteButton.Text = "DELETE"
        deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        deleteButton.TextSize = 10

        teleportButton.MouseButton1Click:Connect(function()
            Teleport.teleportToPosition(data.position)
        end)

        renameInput.FocusLost:Connect(function(enterPressed)
            if enterPressed and renameInput.Text ~= "" and renameInput.Text ~= "Rename..." then
                Teleport.renamePosition(name, renameInput.Text)
                renameInput.Text = "Rename..."
            end
        end)

        deleteButton.MouseButton1Click:Connect(function()
            Teleport.deletePosition(name)
        end)

        teleportButton.MouseEnter:Connect(function()
            teleportButton.BackgroundColor3 = Color3.fromRGB(50, 50, 100)
        end)
        teleportButton.MouseLeave:Connect(function()
            teleportButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
        end)
        deleteButton.MouseEnter:Connect(function()
            deleteButton.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
        end)
        deleteButton.MouseLeave:Connect(function()
            deleteButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
        end)
    end
    wait(0.1)
    PositionScrollFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(PositionLayout.AbsoluteContentSize.Y + 10, 30))
end

-- Freecam
function Teleport.toggleFreecam(enabled)
    Teleport.freecamEnabled = enabled
    if enabled then
        Teleport.freecamPosition = Workspace.CurrentCamera.CFrame
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
        connections.freecam = RunService.RenderStepped:Connect(function()
            if Teleport.freecamEnabled then
                local camera = Workspace.CurrentCamera
                local moveVector = Vector3.new(0, 0, 0)
                local speed = settings.FreecamSpeed.value
                
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveVector = moveVector + camera.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveVector = moveVector - camera.CFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveVector = moveVector + camera.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveVector = moveVector - camera.CFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveVector = moveVector + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveVector = moveVector - Vector3.new(0, 1, 0)
                end
                
                if moveVector.Magnitude > 0 then
                    moveVector = moveVector.Unit * speed
                    Teleport.freecamPosition = Teleport.freecamPosition + moveVector * RunService.RenderStepped:Wait()
                    camera.CFrame = Teleport.freecamPosition
                end
            end
        end)
    else
        if connections.freecam then
            connections.freecam:Disconnect()
        end
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
        Workspace.CurrentCamera.CameraSubject = character:WaitForChild("Humanoid")
        Teleport.freecamPosition = nil
    end
end

-- Teleport to Freecam
function Teleport.teleportToFreecam()
    if Teleport.freecamEnabled and Teleport.freecamPosition and rootPart then
        rootPart.CFrame = Teleport.freecamPosition
        print("Teleported to freecam position")
    else
        print("Cannot teleport: Freecam not enabled or no valid position")
    end
end

-- Save Freecam Position
function Teleport.saveFreecamPosition(name)
    if Teleport.freecamEnabled and Teleport.freecamPosition then
        local position = Teleport.freecamPosition.Position
        Teleport.savePositionToFile(name, position)
        print("Saved freecam position: " .. name)
    else
        print("Cannot save freecam position: Freecam not enabled")
    end
end

-- Save Player Position
function Teleport.savePlayerPosition(name)
    if rootPart then
        local position = rootPart.Position
        Teleport.savePositionToFile(name, position)
        print("Saved player position: " .. name)
    else
        print("Cannot save player position: No valid player position")
    end
end

-- Teleport to Position
function Teleport.teleportToPosition(position)
    if rootPart then
        rootPart.CFrame = CFrame.new(position)
        print("Teleported to position: " .. tostring(position))
    else
        print("Cannot teleport: No valid player root part")
    end
end

-- Cleanup
function Teleport.cleanup()
    Teleport.toggleFreecam(false)
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
end

-- Set GUI elements
function Teleport.setGuiElements(elements)
    Teleport.PositionFrame = elements.PositionFrame
    Teleport.PositionScrollFrame = elements.PositionScrollFrame
    Teleport.PositionLayout = elements.PositionLayout
    Teleport.PositionInput = elements.PositionInput
end

-- Initialize saved positions
Teleport.loadSavedPositions()

-- Update character references on respawn
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    rootPart = character:WaitForChild("HumanoidRootPart")
    Teleport.cleanup() -- Reset freecam on respawn
end)

return Teleport