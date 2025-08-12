-- antirecord.lua
-- Anti Screen Recording module for MinimalHackGUI by Fari Noveri

-- Dependencies: These must be passed from mainloader.lua
local RunService, ScreenGui, settings

-- Initialize module
local AntiRecord = {}

-- Anti-record state
local antiRecordEnabled = false
local overlayFrame = nil
local connections = {}
local protectedGuis = {} -- Store references to protected GUIs

-- Settings for anti-record
local antiRecordSettings = {
    Enabled = false,
    Method = "Overlay", -- "Overlay", "Flicker", "BlackScreen"
    Intensity = 5, -- 1-10 scale
    FlickerSpeed = 0.1 -- For flicker method
}

-- Settings for anti-record
local antiRecordSettings = {
    Enabled = false,
    Method = "Overlay", -- "Overlay", "Flicker", "BlackScreen"
    Intensity = 5, -- 1-10 scale
    FlickerSpeed = 0.1, -- For flicker method
    ProtectKRNL = true, -- Protect KRNL executor GUI
    ProtectOtherExecutors = true -- Protect other executor GUIs
}

-- Function to find and protect KRNL GUI
local function findAndProtectKRNLGUI()
    local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui", 5)
    if not playerGui then return end
    
    -- Common KRNL GUI names/patterns
    local krnlNames = {
        "KRNL", "krnl", "Krnl", "KrnlGui", "KRNLExecutor", 
        "ExecutorGui", "ScriptExecutor", "MainGUI", "Executor"
    }
    
    for _, guiName in pairs(krnlNames) do
        local krnlGui = playerGui:FindFirstChild(guiName)
        if krnlGui and krnlGui:IsA("ScreenGui") then
            -- Protect this GUI
            protectedGuis[#protectedGuis + 1] = krnlGui
            print("Found and protecting KRNL GUI: " .. guiName)
        end
    end
    
    -- Also check for GUIs with common executor characteristics
    for _, gui in pairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Name ~= "MinimalHackGUI" then
            -- Look for common executor GUI patterns
            local hasExecutorPattern = false
            
            -- Check for frames with executor-like names
            for _, child in pairs(gui:GetDescendants()) do
                if child:IsA("Frame") or child:IsA("TextLabel") then
                    local text = child.Name:lower()
                    if string.find(text, "execute") or 
                       string.find(text, "script") or 
                       string.find(text, "inject") or
                       string.find(text, "attach") then
                        hasExecutorPattern = true
                        break
                    end
                end
            end
            
            if hasExecutorPattern then
                protectedGuis[#protectedGuis + 1] = gui
                print("Found and protecting executor GUI: " .. gui.Name)
            end
        end
    end
end

-- Create overlay method with GUI protection
local function createOverlay()
    if overlayFrame then
        overlayFrame:Destroy()
    end
    
    -- Create main overlay
    overlayFrame = Instance.new("Frame")
    overlayFrame.Name = "AntiRecordOverlay"
    overlayFrame.Parent = ScreenGui
    overlayFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    overlayFrame.BackgroundTransparency = 0.3
    overlayFrame.BorderSizePixel = 0
    overlayFrame.Position = UDim2.new(0, 0, 0, 0)
    overlayFrame.Size = UDim2.new(1, 0, 1, 0)
    overlayFrame.ZIndex = 999
    overlayFrame.Visible = true
    
    -- Add noise pattern
    local noisePattern = Instance.new("ImageLabel")
    noisePattern.Name = "NoisePattern"
    noisePattern.Parent = overlayFrame
    noisePattern.BackgroundTransparency = 1
    noisePattern.Position = UDim2.new(0, 0, 0, 0)
    noisePattern.Size = UDim2.new(1, 0, 1, 0)
    noisePattern.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    noisePattern.ImageTransparency = 0.7
    noisePattern.ImageColor3 = Color3.new(1, 1, 1)
    
    -- Add random colored squares
    for i = 1, antiRecordSettings.Intensity * 10 do
        local square = Instance.new("Frame")
        square.Parent = overlayFrame
        square.BackgroundColor3 = Color3.new(math.random(), math.random(), math.random())
        square.BackgroundTransparency = math.random(0.5, 0.9)
        square.BorderSizePixel = 0
        square.Position = UDim2.new(math.random(), 0, math.random(), 0)
        square.Size = UDim2.new(0, math.random(10, 50), 0, math.random(10, 50))
    end
    
    -- Protect other executor GUIs if enabled
    if antiRecordSettings.ProtectKRNL or antiRecordSettings.ProtectOtherExecutors then
        for _, protectedGui in pairs(protectedGuis) do
            if protectedGui and protectedGui.Parent then
                -- Create overlay specifically for this GUI
                local guiOverlay = Instance.new("Frame")
                guiOverlay.Name = "AntiRecordGUIOverlay"
                guiOverlay.Parent = protectedGui
                guiOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
                guiOverlay.BackgroundTransparency = 0.1
                guiOverlay.BorderSizePixel = 0
                guiOverlay.Position = UDim2.new(0, 0, 0, 0)
                guiOverlay.Size = UDim2.new(1, 0, 1, 0)
                guiOverlay.ZIndex = 1000
                
                -- Add smaller noise pattern for GUI
                for i = 1, antiRecordSettings.Intensity * 3 do
                    local miniSquare = Instance.new("Frame")
                    miniSquare.Parent = guiOverlay
                    miniSquare.BackgroundColor3 = Color3.new(math.random(), math.random(), math.random())
                    miniSquare.BackgroundTransparency = math.random(0.7, 0.95)
                    miniSquare.BorderSizePixel = 0
                    miniSquare.Position = UDim2.new(math.random(), 0, math.random(), 0)
                    miniSquare.Size = UDim2.new(0, math.random(5, 20), 0, math.random(5, 20))
                end
            end
        end
    end
end

-- Create flicker method
local function createFlicker()
    if connections.flickerConnection then
        connections.flickerConnection:Disconnect()
    end
    
    local flickerFrame = Instance.new("Frame")
    flickerFrame.Name = "AntiRecordFlicker"
    flickerFrame.Parent = ScreenGui
    flickerFrame.BackgroundColor3 = Color3.new(1, 1, 1)
    flickerFrame.BackgroundTransparency = 1
    flickerFrame.BorderSizePixel = 0
    flickerFrame.Position = UDim2.new(0, 0, 0, 0)
    flickerFrame.Size = UDim2.new(1, 0, 1, 0)
    flickerFrame.ZIndex = 998
    
    overlayFrame = flickerFrame
    
    connections.flickerConnection = RunService.Heartbeat:Connect(function()
        if antiRecordEnabled then
            flickerFrame.BackgroundTransparency = math.random() < antiRecordSettings.FlickerSpeed and 0.1 or 1
            flickerFrame.BackgroundColor3 = Color3.new(math.random(), math.random(), math.random())
        end
    end)
end

-- Create black screen method
local function createBlackScreen()
    if overlayFrame then
        overlayFrame:Destroy()
    end
    
    overlayFrame = Instance.new("Frame")
    overlayFrame.Name = "AntiRecordBlackScreen"
    overlayFrame.Parent = ScreenGui
    overlayFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    overlayFrame.BackgroundTransparency = 0
    overlayFrame.BorderSizePixel = 0
    overlayFrame.Position = UDim2.new(0, 0, 0, 0)
    overlayFrame.Size = UDim2.new(1, 0, 1, 0)
    overlayFrame.ZIndex = 997
    
    -- Add warning text
    local warningText = Instance.new("TextLabel")
    warningText.Name = "WarningText"
    warningText.Parent = overlayFrame
    warningText.BackgroundTransparency = 1
    warningText.Position = UDim2.new(0, 0, 0.4, 0)
    warningText.Size = UDim2.new(1, 0, 0.2, 0)
    warningText.Font = Enum.Font.GothamBold
    warningText.Text = "SCREEN RECORDING DETECTED\nPLEASE DISABLE RECORDING TO CONTINUE"
    warningText.TextColor3 = Color3.new(1, 0, 0)
    warningText.TextSize = 24
    warningText.TextStrokeTransparency = 0
    warningText.TextStrokeColor3 = Color3.new(0, 0, 0)
    
    -- Blinking effect
    connections.blinkConnection = RunService.Heartbeat:Connect(function()
        if antiRecordEnabled then
            warningText.TextTransparency = math.sin(tick() * 5) * 0.5 + 0.5
        end
    end)
end

-- Apply anti-record method
local function applyAntiRecord()
    if not antiRecordEnabled then
        return
    end
    
    if antiRecordSettings.Method == "Overlay" then
        createOverlay()
    elseif antiRecordSettings.Method == "Flicker" then
        createFlicker()
    elseif antiRecordSettings.Method == "BlackScreen" then
        createBlackScreen()
    end
end

-- Remove anti-record effects
local function removeAntiRecord()
    if overlayFrame then
        overlayFrame:Destroy()
        overlayFrame = nil
    end
    
    -- Remove overlays from protected GUIs
    for _, protectedGui in pairs(protectedGuis) do
        if protectedGui and protectedGui.Parent then
            local overlay = protectedGui:FindFirstChild("AntiRecordGUIOverlay")
            if overlay then
                overlay:Destroy()
            end
        end
    end
    
    for _, connection in pairs(connections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
    connections = {}
end

-- Toggle anti-record
local function toggleAntiRecord(enabled)
    antiRecordEnabled = enabled
    antiRecordSettings.Enabled = enabled
    
    if enabled then
        -- Find and protect executor GUIs before applying anti-record
        if antiRecordSettings.ProtectKRNL or antiRecordSettings.ProtectOtherExecutors then
            findAndProtectKRNLGUI()
        end
        
        print("Anti-Record enabled with method: " .. antiRecordSettings.Method)
        print("Protected GUIs count: " .. #protectedGuis)
        applyAntiRecord()
    else
        print("Anti-Record disabled")
        removeAntiRecord()
    end
end

-- Change anti-record method
local function changeMethod(method)
    antiRecordSettings.Method = method
    if antiRecordEnabled then
        removeAntiRecord()
        applyAntiRecord()
    end
    print("Anti-Record method changed to: " .. method)
end

-- Change intensity
local function changeIntensity(intensity)
    antiRecordSettings.Intensity = math.clamp(intensity, 1, 10)
    if antiRecordEnabled and antiRecordSettings.Method == "Overlay" then
        removeAntiRecord()
        applyAntiRecord()
    end
    print("Anti-Record intensity changed to: " .. antiRecordSettings.Intensity)
end

-- Change flicker speed
local function changeFlickerSpeed(speed)
    antiRecordSettings.FlickerSpeed = math.clamp(speed, 0.01, 1)
    print("Anti-Record flicker speed changed to: " .. antiRecordSettings.FlickerSpeed)
end

-- Screen recording detection (basic)
local function detectScreenRecording()
    -- This is a basic detection method
    -- In practice, it's very difficult to reliably detect screen recording
    local success, result = pcall(function()
        return game:GetService("UserInputService").GamepadEnabled
    end)
    
    -- Simple heuristic: if certain properties are being accessed frequently
    -- it might indicate recording software
    return false -- Always return false for now as reliable detection is complex
end

-- Auto-enable anti-record when recording detected
local function startDetectionLoop()
    if connections.detectionLoop then
        connections.detectionLoop:Disconnect()
    end
    
    connections.detectionLoop = RunService.Heartbeat:Connect(function()
        if detectScreenRecording() and not antiRecordEnabled then
            toggleAntiRecord(true)
        end
    end)
end

-- Get current settings
function AntiRecord.getSettings()
    return antiRecordSettings
end

-- Function to create buttons for Anti-Record features  
function AntiRecord.loadAntiRecordButtons(createButton, createToggleButton)
    -- Main toggle
    createToggleButton("Enable Anti-Record", function(enabled)
        toggleAntiRecord(enabled)
    end)
    
    -- Protection options
    createToggleButton("Protect KRNL GUI", function(enabled)
        antiRecordSettings.ProtectKRNL = enabled
        if antiRecordEnabled then
            removeAntiRecord()
            findAndProtectKRNLGUI()
            applyAntiRecord()
        end
    end)
    
    createToggleButton("Protect Other Executors", function(enabled)
        antiRecordSettings.ProtectOtherExecutors = enabled
        if antiRecordEnabled then
            removeAntiRecord()
            findAndProtectKRNLGUI()
            applyAntiRecord()
        end
    end)
    
    -- Method selection buttons
    createButton("Method: Overlay", function()
        changeMethod("Overlay")
    end)
    
    createButton("Method: Flicker", function()
        changeMethod("Flicker") 
    end)
    
    createButton("Method: BlackScreen", function()
        changeMethod("BlackScreen")
    end)
    
    -- Intensity controls
    createButton("Intensity: Low", function()
        changeIntensity(3)
    end)
    
    createButton("Intensity: Medium", function()
        changeIntensity(5)
    end)
    
    createButton("Intensity: High", function()
        changeIntensity(8)
    end)
    
    createButton("Intensity: Maximum", function()
        changeIntensity(10)
    end)
    
    -- Refresh protected GUIs
    createButton("Refresh Protected GUIs", function()
        protectedGuis = {}
        findAndProtectKRNLGUI()
        if antiRecordEnabled then
            removeAntiRecord()
            applyAntiRecord()
        end
        print("Refreshed protected GUIs. Count: " .. #protectedGuis)
    end)
end

-- Function to reset Anti-Record states
function AntiRecord.resetStates()
    removeAntiRecord()
    protectedGuis = {} -- Clear protected GUIs list
    antiRecordEnabled = false
    antiRecordSettings.Enabled = false
    antiRecordSettings.Method = "Overlay"
    antiRecordSettings.Intensity = 5
    antiRecordSettings.FlickerSpeed = 0.1
    antiRecordSettings.ProtectKRNL = true
    antiRecordSettings.ProtectOtherExecutors = true
    
    for _, connection in pairs(connections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
    connections = {}
    
    print("Anti-Record states reset")
end

-- Function to set dependencies and initialize
function AntiRecord.init(deps)
    RunService = deps.RunService
    ScreenGui = deps.ScreenGui
    settings = deps.settings
    
    -- Add anti-record settings to main settings
    if settings then
        settings.AntiRecordIntensity = {value = 5, min = 1, max = 10, default = 5}
        settings.AntiRecordFlickerSpeed = {value = 0.1, min = 0.01, max = 1, default = 0.1}
    end
    
    -- Start detection loop
    startDetectionLoop()
    
    -- Auto-find and protect GUIs on init
    task.spawn(function()
        task.wait(2) -- Wait a bit for other GUIs to load
        if antiRecordSettings.ProtectKRNL or antiRecordSettings.ProtectOtherExecutors then
            findAndProtectKRNLGUI()
        end
    end)
    
    -- Monitor for new GUIs being added
    local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    connections.guiMonitor = playerGui.ChildAdded:Connect(function(gui)
        if gui:IsA("ScreenGui") and gui.Name ~= "MinimalHackGUI" then
            task.wait(0.5) -- Wait for GUI to fully load
            if antiRecordSettings.ProtectKRNL or antiRecordSettings.ProtectOtherExecutors then
                local oldCount = #protectedGuis
                findAndProtectKRNLGUI()
                if #protectedGuis > oldCount then
                    print("New executor GUI detected and protected: " .. gui.Name)
                    -- Refresh anti-record if active
                    if antiRecordEnabled then
                        removeAntiRecord()
                        applyAntiRecord()
                    end
                end
            end
        end
    end)
    
    print("Anti-Record module initialized with GUI protection")
end

return AntiRecord