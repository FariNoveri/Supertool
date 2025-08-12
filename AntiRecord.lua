-- AntiRecord.lua
-- Simple Anti-Recording and Anti-Screenshot for MinimalHackGUI by Fari Noveri
-- Hides GUI from recording/screenshot but keeps it visible on your screen

-- Dependencies: These must be passed from mainloader.lua
local Players, UserInputService, RunService, ScreenGui, settings, connections

-- Initialize module
local AntiRecord = {}

-- State variables
local antiRecordEnabled = false
local antiScreenshotEnabled = false
local hideConnection = nil
local keyDetectionConnection = nil

-- Detection variables
local lastFPS = 60
local fpsDropCount = 0

-- Simple function to hide GUI from capture but keep it visible
local function hideFromCapture()
    if not ScreenGui then return end
    
    -- Method 1: Set GUI properties that typically hide from screen capture
    ScreenGui.DisplayOrder = -1000 -- Move to background
    
    -- Method 2: Brief transparency flicker (too fast for capture to catch)
    local originalTransparency = {}
    
    local function quickHide()
        for _, obj in pairs(ScreenGui:GetDescendants()) do
            if obj:IsA("GuiObject") then
                originalTransparency[obj] = obj.BackgroundTransparency
                obj.BackgroundTransparency = 1
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    obj.TextTransparency = 1
                end
            end
        end
    end
    
    local function quickShow()
        task.wait(0.016) -- Wait 1 frame (60fps = 16.67ms per frame)
        for obj, transparency in pairs(originalTransparency) do
            if obj and obj.Parent then
                obj.BackgroundTransparency = transparency
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    obj.TextTransparency = 0
                end
            end
        end
        ScreenGui.DisplayOrder = 1
    end
    
    quickHide()
    task.spawn(quickShow)
end

-- Detect FPS drops (common during recording/screenshot)
local function detectActivityByFPS()
    local currentFPS = math.floor(1 / game:GetService("RunService").Heartbeat:Wait())
    
    -- If FPS drops significantly
    if currentFPS < lastFPS - 10 then
        fpsDropCount = fpsDropCount + 1
        
        -- If multiple FPS drops detected
        if fpsDropCount >= settings.AntiRecordIntensity.value then
            hideFromCapture()
            fpsDropCount = 0 -- Reset counter
            print("AntiRecord: FPS drop detected - hiding GUI momentarily")
        end
    else
        fpsDropCount = math.max(0, fpsDropCount - 1) -- Gradually decrease if stable
    end
    
    lastFPS = currentFPS
end

-- Main AntiRecord toggle
local function toggleAntiRecord(enabled)
    antiRecordEnabled = enabled
    
    if enabled then
        print("AntiRecord: Enabled - GUI will hide from recordings")
        
        -- Start FPS-based detection
        if hideConnection then hideConnection:Disconnect() end
        hideConnection = RunService.Heartbeat:Connect(detectActivityByFPS)
        
        -- Detect common screenshot/recording keys
        if keyDetectionConnection then keyDetectionConnection:Disconnect() end
        keyDetectionConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            
            -- Common screenshot/recording hotkeys
            local captureKeys = {
                Enum.KeyCode.PrintScreen,    -- Print Screen
                Enum.KeyCode.F12,           -- Steam screenshot
                Enum.KeyCode.F9,            -- Some recording software
                Enum.KeyCode.F10,           -- Some recording software
                Enum.KeyCode.F11,           -- Some recording software
            }
            
            for _, key in pairs(captureKeys) do
                if input.KeyCode == key then
                    -- Hide GUI immediately when capture key is pressed
                    for i = 1, 30 do -- Hide for 30 frames (~0.5 seconds)
                        hideFromCapture()
                        RunService.Heartbeat:Wait()
                    end
                    print("AntiRecord: Screenshot key detected")
                    break
                end
            end
            
            -- Detect common recording software combinations
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
                if input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.Z then
                    -- OBS, Bandicam, etc hotkeys
                    for i = 1, 60 do -- Hide for 60 frames (~1 second)
                        hideFromCapture()
                        RunService.Heartbeat:Wait()
                    end
                    print("AntiRecord: Recording hotkey detected")
                end
            end
        end)
        
    else
        print("AntiRecord: Disabled")
        
        -- Cleanup connections
        if hideConnection then
            hideConnection:Disconnect()
            hideConnection = nil
        end
        
        if keyDetectionConnection then
            keyDetectionConnection:Disconnect()
            keyDetectionConnection = nil
        end
        
        -- Ensure GUI is fully visible
        if ScreenGui then
            ScreenGui.DisplayOrder = 1
            for _, obj in pairs(ScreenGui:GetDescendants()) do
                if obj:IsA("GuiObject") then
                    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                        obj.TextTransparency = 0
                    end
                end
            end
        end
    end
end

-- Anti-Screenshot (more aggressive hiding)
local function toggleAntiScreenshot(enabled)
    antiScreenshotEnabled = enabled
    
    if enabled then
        print("AntiScreenshot: Enabled - More aggressive hiding")
        
        -- More frequent random hiding
        if connections.screenshotHide then connections.screenshotHide:Disconnect() end
        connections.screenshotHide = RunService.RenderStepped:Connect(function()
            -- Random hide chance every few frames
            if math.random(1, 120) == 1 then -- ~1/120 chance per frame (once every 2 seconds at 60fps)
                hideFromCapture()
            end
        end)
        
    else
        print("AntiScreenshot: Disabled")
        
        if connections.screenshotHide then
            connections.screenshotHide:Disconnect()
            connections.screenshotHide = nil
        end
    end
end

-- Manual hide (instant hide for few seconds)
local function manualHide()
    print("AntiRecord: Manual hide activated")
    
    task.spawn(function()
        for i = 1, 180 do -- Hide for 3 seconds (180 frames at 60fps)
            hideFromCapture()
            RunService.Heartbeat:Wait()
        end
        print("AntiRecord: Manual hide ended")
    end)
end

-- Emergency show (restore GUI visibility)
local function manualShow()
    print("AntiRecord: Restoring GUI visibility")
    
    if ScreenGui then
        ScreenGui.DisplayOrder = 1
        for _, obj in pairs(ScreenGui:GetDescendants()) do
            if obj:IsA("GuiObject") then
                obj.BackgroundTransparency = obj.BackgroundTransparency < 0.95 and obj.BackgroundTransparency or 0
                if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    obj.TextTransparency = 0
                end
            end
        end
    end
end

-- Reset all states
function AntiRecord.resetStates()
    antiRecordEnabled = false
    antiScreenshotEnabled = false
    
    -- Disconnect all connections
    if hideConnection then
        hideConnection:Disconnect()
        hideConnection = nil
    end
    
    if keyDetectionConnection then
        keyDetectionConnection:Disconnect()
        keyDetectionConnection = nil
    end
    
    if connections.screenshotHide then
        connections.screenshotHide:Disconnect()
        connections.screenshotHide = nil
    end
    
    -- Restore GUI
    manualShow()
    
    fpsDropCount = 0
    lastFPS = 60
end

-- Get current states
function AntiRecord.getAntiRecordState()
    return antiRecordEnabled
end

function AntiRecord.getAntiScreenshotState()
    return antiScreenshotEnabled
end

-- Export functions
AntiRecord.toggleAntiRecord = toggleAntiRecord
AntiRecord.toggleAntiScreenshot = toggleAntiScreenshot
AntiRecord.manualHide = manualHide
AntiRecord.manualShow = manualShow

-- Initialize module
function AntiRecord.init(deps)
    Players = deps.Players
    UserInputService = deps.UserInputService
    RunService = deps.RunService
    ScreenGui = deps.ScreenGui
    settings = deps.settings
    connections = deps.connections
    
    print("AntiRecord module initialized - Ready to hide GUI from captures")
end

return AntiRecord