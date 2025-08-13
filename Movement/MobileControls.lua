local MobileControls = {}
local ScreenGui, Fly
local flyJoystickFrame, flyJoystickKnob, flyUpButton, flyDownButton

function MobileControls.init(deps)
    ScreenGui = deps.ScreenGui
    createMobileControls()
end

local function createMobileControls()
    if flyJoystickFrame then flyJoystickFrame:Destroy() end
    if flyUpButton then flyUpButton:Destroy() end
    if flyDownButton then flyDownButton:Destroy() end
    flyJoystickFrame = Instance.new("Frame")
    flyJoystickFrame.Name = "FlyJoystick"
    flyJoystickFrame.Size = UDim2.new(0, 100, 0, 100)
    flyJoystickFrame.Position = UDim2.new(0, 20, 1, -130)
    flyJoystickFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    flyJoystickFrame.BackgroundTransparency = 0.3
    flyJoystickFrame.BorderSizePixel = 0
    flyJoystickFrame.Visible = false
    flyJoystickFrame.ZIndex = 10
    flyJoystickFrame.Parent = ScreenGui
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
    flyUpButton.Parent = ScreenGui
    local upCorner = Instance.new("UICorner")
    upCorner.CornerRadius = UDim.new(0.3, 0)
    upCorner.Parent = flyUpButton
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
    flyDownButton.Parent = ScreenGui
    local downCorner = Instance.new("UICorner")
    downCorner.CornerRadius = UDim.new(0.3, 0)
    downCorner.Parent = flyDownButton
    if Fly then
        Fly.setControls(flyJoystickFrame, flyJoystickKnob, flyUpButton, flyDownButton)
    end
end

function MobileControls.updateReferences(newHumanoid, newRootPart)
    createMobileControls()
end

function MobileControls.reset()
    if flyJoystickFrame then
        flyJoystickFrame.Visible = false
        flyJoystickKnob.Position = UDim2.new(0.5, -20, 0.5, -20)
    end
    if flyUpButton then
        flyUpButton.Visible = false
        flyUpButton.BackgroundTransparency = 0.3
    end
    if flyDownButton then
        flyDownButton.Visible = false
        flyDownButton.BackgroundTransparency = 0.3
    end
end

function MobileControls.cleanup()
    if flyJoystickFrame then flyJoystickFrame:Destroy() end
    if flyUpButton then flyUpButton:Destroy() end
    if flyDownButton then flyDownButton:Destroy() end
    flyJoystickFrame = nil
    flyJoystickKnob = nil
    flyUpButton = nil
    flyDownButton = nil
end

function MobileControls.debug()
    print("MobileControls: flyJoystickFrame =", flyJoystickFrame ~= nil, "flyUpButton =", flyUpButton ~= nil, "flyDownButton =", flyDownButton ~= nil)
end

function MobileControls.setFlyModule(flyModule)
    Fly = flyModule
    if flyJoystickFrame and flyJoystickKnob and flyUpButton and flyDownButton then
        Fly.setControls(flyJoystickFrame, flyJoystickKnob, flyUpButton, flyDownButton)
    end
end

return MobileControls