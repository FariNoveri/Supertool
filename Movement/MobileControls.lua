-- Mobile Controls for Movement features

local MobileControls = {}

-- Dependencies
local deps = {}
local Utils = nil

-- UI Elements
local flyJoystickFrame, flyJoystickKnob
local wallClimbButton
local flyUpButton, flyDownButton

-- State variables
local joystickDelta = Vector2.new(0, 0)
local flyVerticalInput = 0
local isTouchingJoystick = false
local joystickTouchId = nil
local connections = {}

-- Load Utils module
local function loadUtils()
    if Utils then return Utils end
    
    local success, result = pcall(function()
        local response = game:HttpGet("https://raw.githubusercontent.com/FariNoveri/Supertool/main/Movement/Utils.lua")
        local func = loadstring(response)
        local utils = func()
        utils.init(deps)
        return utils
    end)
    
    if success then
        Utils = result
        return Utils
    else
        warn("Failed to load Utils for MobileControls: " .. tostring(result))
        return nil
    end
end

-- Create virtual controls
local function createMobileControls()
    print("Creating mobile controls")
    
    -- Clean up existing controls
    local utils = loadUtils()
    if not utils then return end
    
    if flyJoystickFrame then utils.safeDestroy(flyJoystickFrame) end
    if wallClimbButton then utils.safeDestroy(wallClimbButton) end
    if flyUpButton then utils.safeDestroy(flyUpButton) end
    if flyDownButton then utils.safeDestroy(flyDownButton) end

    -- Fly Joystick
    flyJoystickFrame = Instance.new("Frame")
    flyJoystickFrame.Name = "FlyJoystick"
    flyJoystickFrame.Size = UDim2.new(0, 100, 0, 100)
    flyJoystickFrame.Position = UDim2.new(0, 20, 1, -130)
    flyJoystickFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    flyJoystickFrame.BackgroundTransparency = 0.3
    flyJoystickFrame.BorderSizePixel = 0
    flyJoystickFrame.Visible = false
    flyJoystickFrame.ZIndex = 10
    flyJoystickFrame.Parent = deps.ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = flyJoystickFrame

    flyJoystickKnob = Instance.new("Frame")
    flyJoystickKnob.Name = "Knob"
    flyJoystickKnob.Size = UDim2.new(0, 40, 0, 40)
    flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
    flyJoystickKnob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    flyJoystickKnob.BackgroundTransparency = 0.1
    flyJoystickKnob.BorderSizePixel = 0
    flyJoystickKnob.ZIndex = 11
    flyJoystickKnob.Parent = flyJoystickFrame

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0.5, 0)
    knobCorner.Parent = flyJoystickKnob

    -- Wall Climb Button
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
    wallClimbButton.Parent = deps.ScreenGui

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0.2, 0)
    buttonCorner.Parent = wallClimbButton

    -- Fly Up Button
    flyUpButton = Instance.new("TextButton")
    flyUpButton.Name = "FlyUpButton"
    flyUpButton.Size = UDim2.new(0, 50, 0, 50)
    flyUpButton.Position = UDim2.new(1, -70, 1, -200)
    flyUpButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    flyUpButton.BackgroundTransparency = 0.3
    flyUpButton.BorderSizePixel = 0
    flyUpButton.Text = "▲"
    flyUpButton.Font = Enum.Font.GothamBold
    flyUpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    flyUpButton.TextSize = 16
    flyUpButton.Visible = false
    flyUpButton.ZIndex = 10
    flyUpButton.Parent = deps.ScreenGui

    local upCorner = Instance.new("UICorner")
    upCorner.CornerRadius = UDim.new(0.3, 0)
    upCorner.Parent = flyUpButton

    -- Fly Down Button
    flyDownButton = Instance.new("TextButton")
    flyDownButton.Name = "FlyDownButton"
    flyDownButton.Size = UDim2.new(0, 50, 0, 50)
    flyDownButton.Position = UDim2.new(1, -70, 1, -140)
    flyDownButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    flyDownButton.BackgroundTransparency = 0.3
    flyDownButton.BorderSizePixel = 0
    flyDownButton.Text = "▼"
    flyDownButton.Font = Enum.Font.GothamBold
    flyDownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    flyDownButton.TextSize = 16
    flyDownButton.Visible = false
    flyDownButton.ZIndex = 10
    flyDownButton.Parent = deps.ScreenGui

    local downCorner = Instance.new("UICorner")
    downCorner.CornerRadius = UDim.new(0.3, 0)
    downCorner.Parent = flyDownButton

    print("Mobile controls created successfully")
end

-- Improved joystick handling
local function handleFlyJoystick(input, gameProcessed)
    if not flyJoystickFrame or not flyJoystickFrame.Visible then 
        return 
    end
    
    if input.UserInputType == Enum.UserInputType.Touch then
        local joystickCenter = flyJoystickFrame.AbsolutePosition + flyJoystickFrame.AbsoluteSize * 0.5
        local inputPos = Vector2.new(input.Position.X, input.Position.Y)
        local distanceFromCenter = (inputPos - joystickCenter).Magnitude
        
        if input.UserInputState == Enum.UserInputState.Begin then
            if distanceFromCenter <= 50 and not isTouchingJoystick then
                isTouchingJoystick = true
                joystickTouchId = input
            end
        elseif input.UserInputState == Enum.UserInputState.Change and isTouchingJoystick and input == joystickTouchId then
            local delta = inputPos - joystickCenter
            local magnitude = delta.Magnitude
            local maxRadius = 30
            
            if magnitude > maxRadius then
                delta = delta * (maxRadius / magnitude)
            end
            
            flyJoystickKnob.Position = UDim2.new(0.5, delta.X - 20, 0.5, delta.Y - 20)
            joystickDelta = delta / maxRadius
            
        elseif input.UserInputState == Enum.UserInputState.End and input == joystickTouchId then
            isTouchingJoystick = false
            joystickTouchId = nil
            flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
            joystickDelta = Vector2.new(0, 0)
        end
    end
end

-- Setup input connections
local function setupInputConnections()
    local utils = loadUtils()
    if not utils then return end
    
    -- Clean up existing connections
    for name, connection in pairs(connections) do
        utils.safeDisconnect(connection)
    end
    connections = {}
    
    -- Joystick input connections
    connections.flyInput = deps.UserInputService.InputChanged:Connect(handleFlyJoystick)
    connections.flyBegan = deps.UserInputService.InputBegan:Connect(handleFlyJoystick)
    connections.flyEnded = deps.UserInputService.InputEnded:Connect(handleFlyJoystick)
    
    -- Up/Down button connections
    if flyUpButton then
        connections.flyUp = flyUpButton.MouseButton1Down:Connect(function()
            flyVerticalInput = 1
            flyUpButton.BackgroundTransparency = 0.1
        end)
        connections.flyUpEnd = flyUpButton.MouseButton1Up:Connect(function()
            flyVerticalInput = 0
            flyUpButton.BackgroundTransparency = 0.3
        end)
    end
    
    if flyDownButton then
        connections.flyDown = flyDownButton.MouseButton1Down:Connect(function()
            flyVerticalInput = -1
            flyDownButton.BackgroundTransparency = 0.1
        end)
        connections.flyDownEnd = flyDownButton.MouseButton1Up:Connect(function()
            flyVerticalInput = 0
            flyDownButton.BackgroundTransparency = 0.3
        end)
    end
end

-- Show/Hide fly controls
function MobileControls.showFlyControls(show)
    if flyJoystickFrame then flyJoystickFrame.Visible = show end
    if flyUpButton then flyUpButton.Visible = show end
    if flyDownButton then flyDownButton.Visible = show end
    
    if show then
        setupInputConnections()
    else
        -- Reset joystick position
        if flyJoystickKnob then
            flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
        end
        -- Reset button transparency
        if flyUpButton then flyUpButton.BackgroundTransparency = 0.3 end
        if flyDownButton then flyDownButton.BackgroundTransparency = 0.3 end
        -- Reset state
        joystickDelta = Vector2.new(0, 0)
        flyVerticalInput = 0
        isTouchingJoystick = false
        joystickTouchId = nil
    end
end

-- Show/Hide wall climb controls
function MobileControls.showWallClimbControls(show, callback)
    if wallClimbButton then
        wallClimbButton.Visible = show
        
        -- Clean up existing connection
        local utils = loadUtils()
        if utils and connections.wallClimbInput then
            utils.safeDisconnect(connections.wallClimbInput)
            connections.wallClimbInput = nil
        end
        
        if show and callback then
            connections.wallClimbInput = wallClimbButton.MouseButton1Click:Connect(callback)
        end
        
        if not show then
            wallClimbButton.Text = "Climb"
        end
    end
end

-- Get current joystick delta
function MobileControls.getJoystickDelta()
    return joystickDelta
end

-- Get current vertical input
function MobileControls.getVerticalInput()
    return flyVerticalInput
end

-- Get wall climb button reference
function MobileControls.getWallClimbButton()
    return wallClimbButton
end

-- Initialize mobile controls
function MobileControls.init(dependencies)
    if not dependencies then
        warn("MobileControls: No dependencies provided!")
        return false
    end
    
    deps = dependencies
    connections = {}
    
    createMobileControls()
    
    print("Mobile Controls initialized")
    return true
end

-- Update references
function MobileControls.updateReferences(newHumanoid, newRootPart)
    if Utils then
        Utils.updateReferences(newHumanoid, newRootPart)
    end
    
    -- Recreate controls to ensure they work with new character
    createMobileControls()
end

-- Reset state
function MobileControls.reset()
    -- Hide all controls
    MobileControls.showFlyControls(false)
    MobileControls.showWallClimbControls(false)
    
    -- Reset state variables
    joystickDelta = Vector2.new(0, 0)
    flyVerticalInput = 0
    isTouchingJoystick = false
    joystickTouchId = nil
    
    print("Mobile Controls reset")
end

-- Cleanup
function MobileControls.cleanup()
    local utils = loadUtils()
    if not utils then return end
    
    MobileControls.reset()
    
    -- Clean up connections
    for name, connection in pairs(connections) do
        utils.safeDisconnect(connection)
    end
    connections = {}
    
    -- Destroy UI elements
    if flyJoystickFrame then utils.safeDestroy(flyJoystickFrame) end
    if wallClimbButton then utils.safeDestroy(wallClimbButton) end
    if flyUpButton then utils.safeDestroy(flyUpButton) end
    if flyDownButton then utils.safeDestroy(flyDownButton) end
    
    -- Clear references
    flyJoystickFrame = nil
    flyJoystickKnob = nil
    wallClimbButton = nil
    flyUpButton = nil
    flyDownButton = nil
    Utils = nil
    
    print("Mobile Controls cleaned up")
end

return MobileControls