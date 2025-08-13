local WallClimb = {}
local Players, RunService, Workspace, humanoid, rootPart, connections, ScreenGui
WallClimb.enabled = false
local wallClimbButton

local function refreshReferences()
    if not Players or not Players.LocalPlayer or not Players.LocalPlayer.Character then 
        return false 
    end
    humanoid = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    rootPart = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    return humanoid ~= nil and rootPart ~= nil
end

function WallClimb.init(deps)
    Players = deps.Players
    RunService = deps.RunService
    Workspace = deps.Workspace
    connections = deps.connections
    ScreenGui = deps.ScreenGui
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    if ScreenGui then
        wallClimbButton = Instance.new("TextButton")
        wallClimbButton.Name = "WallClimbButton"
        wallClimbButton.Size = UDim2.new(0, 60, 0, 60)
        wallClimbButton.Position = UDim2.new(1, -80, 1, -130)
        wallClimbButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        wallClimbButton.BackgroundTransparency = 0.3
        wallClimbButton.BorderSizePixel = 0
        wallClimbButton.Text = "Climb"
        wallClimbButton.Font = Enum.Font.GothamBold
        wallClimbButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        wallClimbButton.TextSize = 12
        wallClimbButton.Visible = false
        wallClimbButton.ZIndex = 10
        wallClimbButton.Parent = ScreenGui
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0.2, 0)
        buttonCorner.Parent = wallClimbButton
    end
end

function WallClimb.toggle(enabled)
    WallClimb.enabled = enabled
    if connections.wallClimb then
        connections.wallClimb:Disconnect()
        connections.wallClimb = nil
    end
    if connections.wallClimbInput then
        connections.wallClimbInput:Disconnect()
        connections.wallClimbInput = nil
    end
    if enabled and wallClimbButton then
        wallClimbButton.Visible = true
        connections.wallClimb = RunService.Heartbeat:Connect(function()
            if not WallClimb.enabled then return end
            if not refreshReferences() or not humanoid or not rootPart then return end
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {Players.LocalPlayer.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            local directions = {
                rootPart.CFrame.RightVector,
                -rootPart.CFrame.RightVector,
                rootPart.CFrame.LookVector,
                -rootPart.CFrame.LookVector
            }
            local isNearWall = false
            for _, direction in ipairs(directions) do
                local raycast = Workspace:Raycast(rootPart.Position, direction * 3, raycastParams)
                if raycast and raycast.Instance and raycast.Normal.Y < 0.1 then
                    isNearWall = true
                    break
                end
            end
            if isNearWall and wallClimbButton.Text == "Climbing" then
                rootPart.Velocity = Vector3.new(rootPart.Velocity.X, 30, rootPart.Velocity.Z)
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
        connections.wallClimbInput = wallClimbButton.MouseButton1Click:Connect(function()
            wallClimbButton.Text = wallClimbButton.Text == "Climb" and "Climbing" or "Climb"
        end)
    else
        if wallClimbButton then
            wallClimbButton.Visible = false
            wallClimbButton.Text = "Climb"
        end
    end
end

function WallClimb.updateReferences(newHumanoid, newRootPart)
    humanoid = newHumanoid
    rootPart = newRootPart
end

function WallClimb.reset()
    WallClimb.enabled = false
    if connections.wallClimb then
        connections.wallClimb:Disconnect()
        connections.wallClimb = nil
    end
    if connections.wallClimbInput then
        connections.wallClimbInput:Disconnect()
        connections.wallClimbInput = nil
    end
    if wallClimbButton then
        wallClimbButton.Visible = false
        wallClimbButton.Text = "Climb"
    end
end

function WallClimb.cleanup()
    if wallClimbButton then
        wallClimbButton:Destroy()
        wallClimbButton = nil
    end
    WallClimb.reset()
end

function WallClimb.debug()
    print("WallClimb: enabled =", WallClimb.enabled, "wallClimbButton =", wallClimbButton ~= nil, "humanoid =", humanoid ~= nil, "rootPart =", rootPart ~= nil)
end

return WallClimb