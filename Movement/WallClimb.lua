local WallClimb = {}
local Players, RunService, Workspace, humanoid, rootPart, connections, ScreenGui
WallClimb.enabled = false
local wallClimbButton

-- Initialize connections as empty table to prevent nil errors
connections = connections or {}

local function refreshReferences()
    if not Players or not Players.LocalPlayer or not Players.LocalPlayer.Character then 
        return false 
    end
    humanoid = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    rootPart = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    return humanoid ~= nil and rootPart ~= nil
end

function WallClimb.init(deps)
    -- Validate dependencies
    if not deps then
        warn("WallClimb.init: deps parameter is nil")
        return false
    end
    
    Players = deps.Players
    RunService = deps.RunService
    Workspace = deps.Workspace
    connections = deps.connections or {} -- Use provided connections or create empty table
    ScreenGui = deps.ScreenGui
    humanoid = deps.humanoid
    rootPart = deps.rootPart
    
    -- Validate required services
    if not Players or not RunService or not Workspace then
        warn("WallClimb.init: Missing required services")
        return false
    end
    
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
    
    return true
end

function WallClimb.toggle(enabled)
    -- Check if module is properly initialized
    if not connections then
        warn("WallClimb: Module not initialized properly - connections is nil")
        return
    end
    
    WallClimb.enabled = enabled
    
    -- Safely disconnect existing connections
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
        
        -- Main wall climbing logic
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
        
        -- Button input handling
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
    
    -- Safely disconnect connections
    if connections and connections.wallClimb then
        connections.wallClimb:Disconnect()
        connections.wallClimb = nil
    end
    if connections and connections.wallClimbInput then
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
    print("WallClimb Debug Info:")
    print("  enabled =", WallClimb.enabled)
    print("  wallClimbButton =", wallClimbButton ~= nil)
    print("  humanoid =", humanoid ~= nil)
    print("  rootPart =", rootPart ~= nil)
    print("  connections =", connections ~= nil)
    print("  Players =", Players ~= nil)
    print("  RunService =", RunService ~= nil)
    print("  Workspace =", Workspace ~= nil)
    
    if connections then
        print("  connections.wallClimb =", connections.wallClimb ~= nil)
        print("  connections.wallClimbInput =", connections.wallClimbInput ~= nil)
    end
end

-- Helper function to check if module is properly initialized
function WallClimb.isInitialized()
    return connections ~= nil and Players ~= nil and RunService ~= nil and Workspace ~= nil
end

return WallClimb