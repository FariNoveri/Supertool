-- antirecord.lua
-- Anti Screen Recording module for MinimalHackGUI by Fari Noveri
-- Modified version: Hides GUIs instead of overlay/sensor

-- Dependencies: These must be passed from mainloader.lua
local RunService, ScreenGui, settings

-- Initialize module
local AntiRecord = {}

-- Anti-record state
local antiRecordEnabled = false
local connections = {}
local protectedGuis = {} -- Store references to protected GUIs
local guiStates = {} -- Store original visibility states

-- Settings for anti-record
local antiRecordSettings = {
    Enabled = false,
    HideMethod = "Instant", -- "Instant", "Fade", "Smart"
    HideDelay = 0, -- Delay before hiding (in seconds)
    ProtectKRNL = true, -- Protect KRNL executor GUI
    ProtectOtherExecutors = true, -- Protect other executor GUIs
    ProtectCoreGuis = false, -- Protect Roblox core GUIs
    ShowWarning = true -- Show warning when GUIs are hidden
}

-- Function to find and catalog executor GUIs
local function findAndCatalogExecutorGUIs()
    local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui", 5)
    if not playerGui then return end
    
    -- Clear previous data
    protectedGuis = {}
    guiStates = {}
    
    -- Common executor GUI names/patterns
    local executorNames = {
        "KRNL", "krnl", "Krnl", "KrnlGui", "KRNLExecutor",
        "Synapse", "synapse", "SynapseX", "SynapseXen",
        "Script-Ware", "ScriptWare", "Ware", "SW",
        "Fluxus", "fluxus", "FluxusGui",
        "Oxygen", "oxygen", "OxygenU",
        "Sentinel", "sentinel", "SentinelV2",
        "ExecutorGui", "ScriptExecutor", "MainGUI", "Executor",
        "Injector", "ScriptHub", "LoaderGui", "HackGui"
    }
    
    -- Find GUIs by name
    for _, guiName in pairs(executorNames) do
        local gui = playerGui:FindFirstChild(guiName)
        if gui and gui:IsA("ScreenGui") and gui ~= ScreenGui then
            protectedGuis[#protectedGuis + 1] = gui
            guiStates[gui] = gui.Enabled -- Store original state
            print("Found executor GUI by name: " .. guiName)
        end
    end
    
    -- Find GUIs by pattern analysis
    for _, gui in pairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui ~= ScreenGui and gui.Name ~= "MinimalHackGUI" then
            local isExecutorGui = false
            
            -- Check for executor-like characteristics
            for _, child in pairs(gui:GetDescendants()) do
                if child:IsA("TextLabel") or child:IsA("TextButton") then
                    local text = child.Text:lower()
                    if string.find(text, "execute") or 
                       string.find(text, "inject") or 
                       string.find(text, "attach") or
                       string.find(text, "script") or
                       string.find(text, "exploit") or
                       string.find(text, "hack") then
                        isExecutorGui = true
                        break
                    end
                elseif child.Name:lower():find("execute") or 
                       child.Name:lower():find("script") or
                       child.Name:lower():find("inject") then
                    isExecutorGui = true
                    break
                end
            end
            
            -- Also check GUI structure (common executor patterns)
            if not isExecutorGui then
                local frames = 0
                local buttons = 0
                for _, child in pairs(gui:GetChildren()) do
                    if child:IsA("Frame") then frames = frames + 1 end
                    if child:IsA("TextButton") then buttons = buttons + 1 end
                end
                -- Executor GUIs typically have multiple frames and buttons
                if frames >= 2 and buttons >= 3 then
                    isExecutorGui = true
                end
            end
            
            if isExecutorGui then
                -- Check if already in list
                local alreadyAdded = false
                for _, existingGui in pairs(protectedGuis) do
                    if existingGui == gui then
                        alreadyAdded = true
                        break
                    end
                end
                
                if not alreadyAdded then
                    protectedGuis[#protectedGuis + 1] = gui
                    guiStates[gui] = gui.Enabled
                    print("Found executor GUI by pattern: " .. gui.Name)
                end
            end
        end
    end
    
    print("Total executor GUIs found: " .. #protectedGuis)
end

-- Function to hide GUIs instantly
local function hideGuisInstant()
    for _, gui in pairs(protectedGuis) do
        if gui and gui.Parent then
            gui.Enabled = false
        end
    end
end

-- Function to fade out GUIs
local function hideGuisFade()
    for _, gui in pairs(protectedGuis) do
        if gui and gui.Parent then
            local tween = game:GetService("TweenService"):Create(
                gui,
                TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Enabled = false}
            )
            tween:Play()
        end
    end
end

-- Function to smart hide (hide when recording detected)
local function hideGuisSmart()
    -- For now, same as instant. Can be enhanced with actual recording detection
    hideGuisInstant()
end

-- Function to show warning
local function showHideWarning()
    if not antiRecordSettings.ShowWarning then return end
    
    local warningGui = Instance.new("ScreenGui")
    warningGui.Name = "AntiRecordWarning"
    warningGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local warningFrame = Instance.new("Frame")
    warningFrame.Parent = warningGui
    warningFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
    warningFrame.BackgroundTransparency = 0.2
    warningFrame.BorderSizePixel = 2
    warningFrame.BorderColor3 = Color3.new(1, 0.5, 0)
    warningFrame.Position = UDim2.new(0.5, -150, 0.1, 0)
    warningFrame.Size = UDim2.new(0, 300, 0, 80)
    
    local warningText = Instance.new("TextLabel")
    warningText.Parent = warningFrame
    warningText.BackgroundTransparency = 1
    warningText.Position = UDim2.new(0, 5, 0, 5)
    warningText.Size = UDim2.new(1, -10, 1, -10)
    warningText.Font = Enum.Font.GothamBold
    warningText.Text = "🛡️ ANTI-RECORD ACTIVE\nExecutor GUIs Hidden (" .. #protectedGuis .. ")"
    warningText.TextColor3 = Color3.new(1, 0.8, 0)
    warningText.TextSize = 14
    warningText.TextStrokeTransparency = 0
    warningText.TextStrokeColor3 = Color3.new(0, 0, 0)
    warningText.TextWrapped = true
    
    -- Auto-remove warning after 3 seconds
    task.spawn(function()
        task.wait(3)
        if warningGui and warningGui.Parent then
            warningGui:Destroy()
        end
    end)
end

-- Function to restore GUIs
local function restoreGuis()
    for gui, originalState in pairs(guiStates) do
        if gui and gui.Parent then
            gui.Enabled = originalState
        end
    end
end

-- Function to apply anti-record (hide GUIs)
local function applyAntiRecord()
    if not antiRecordEnabled then return end
    
    task.spawn(function()
        if antiRecordSettings.HideDelay > 0 then
            task.wait(antiRecordSettings.HideDelay)
        end
        
        if antiRecordSettings.HideMethod == "Instant" then
            hideGuisInstant()
        elseif antiRecordSettings.HideMethod == "Fade" then
            hideGuisFade()
        elseif antiRecordSettings.HideMethod == "Smart" then
            hideGuisSmart()
        end
        
        showHideWarning()
        print("Hidden " .. #protectedGuis .. " executor GUIs")
    end)
end

-- Function to remove anti-record (restore GUIs)
local function removeAntiRecord()
    restoreGuis()
    
    -- Remove warning GUI if exists
    local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    local warningGui = playerGui:FindFirstChild("AntiRecordWarning")
    if warningGui then
        warningGui:Destroy()
    end
    
    for _, connection in pairs(connections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
    connections = {}
    
    print("Restored " .. #protectedGuis .. " executor GUIs")
end

-- Toggle anti-record
local function toggleAntiRecord(enabled)
    antiRecordEnabled = enabled
    antiRecordSettings.Enabled = enabled
    
    if enabled then
        -- Find and catalog GUIs before applying anti-record
        if antiRecordSettings.ProtectKRNL or antiRecordSettings.ProtectOtherExecutors then
            findAndCatalogExecutorGUIs()
        end
        
        print("Anti-Record enabled - Method: Hide GUIs (" .. antiRecordSettings.HideMethod .. ")")
        print("Will hide " .. #protectedGuis .. " executor GUIs")
        applyAntiRecord()
    else
        print("Anti-Record disabled - Restoring GUIs")
        removeAntiRecord()
    end
end

-- Change hide method
local function changeHideMethod(method)
    antiRecordSettings.HideMethod = method
    print("Anti-Record hide method changed to: " .. method)
    
    if antiRecordEnabled then
        -- Re-apply with new method
        removeAntiRecord()
        task.wait(0.1)
        applyAntiRecord()
    end
end

-- Change hide delay
local function changeHideDelay(delay)
    antiRecordSettings.HideDelay = math.max(0, delay)
    print("Anti-Record hide delay changed to: " .. antiRecordSettings.HideDelay .. "s")
end

-- Basic screen recording detection
local function detectScreenRecording()
    -- Simple heuristics for recording detection
    local success, result = pcall(function()
        local uis = game:GetService("UserInputService")
        local rs = game:GetService("RunService")
        
        -- Check for performance indicators that might suggest recording
        local fps = 1 / rs.Heartbeat:Wait()
        
        -- If FPS is consistently low, might be recording
        -- This is a very basic check and not reliable
        return fps < 30
    end)
    
    return success and result or false
end

-- Auto-enable when recording detected
local function startSmartDetection()
    if connections.smartDetection then
        connections.smartDetection:Disconnect()
    end
    
    connections.smartDetection = RunService.Heartbeat:Connect(function()
        if antiRecordSettings.HideMethod == "Smart" and detectScreenRecording() then
            if not antiRecordEnabled then
                toggleAntiRecord(true)
            end
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
            task.wait(0.1)
            findAndCatalogExecutorGUIs()
            applyAntiRecord()
        end
    end)
    
    createToggleButton("Protect Other Executors", function(enabled)
        antiRecordSettings.ProtectOtherExecutors = enabled
        if antiRecordEnabled then
            removeAntiRecord()
            task.wait(0.1)
            findAndCatalogExecutorGUIs()
            applyAntiRecord()
        end
    end)
    
    createToggleButton("Show Hide Warning", function(enabled)
        antiRecordSettings.ShowWarning = enabled
    end)
    
    -- Hide method selection
    createButton("Method: Instant Hide", function()
        changeHideMethod("Instant")
    end)
    
    createButton("Method: Fade Hide", function()
        changeHideMethod("Fade")
    end)
    
    createButton("Method: Smart Hide", function()
        changeHideMethod("Smart")
    end)
    
    -- Hide delay controls
    createButton("Delay: None", function()
        changeHideDelay(0)
    end)
    
    createButton("Delay: 1s", function()
        changeHideDelay(1)
    end)
    
    createButton("Delay: 3s", function()
        changeHideDelay(3)
    end)
    
    createButton("Delay: 5s", function()
        changeHideDelay(5)
    end)
    
    -- Utility buttons
    createButton("Refresh Protected GUIs", function()
        findAndCatalogExecutorGUIs()
        print("Refreshed protected GUIs. Found: " .. #protectedGuis)
        
        if antiRecordEnabled then
            removeAntiRecord()
            task.wait(0.1)
            applyAntiRecord()
        end
    end)
    
    createButton("List Protected GUIs", function()
        print("=== PROTECTED EXECUTOR GUIS ===")
        for i, gui in pairs(protectedGuis) do
            print(i .. ". " .. gui.Name .. " (Enabled: " .. tostring(gui.Enabled) .. ")")
        end
        print("Total: " .. #protectedGuis .. " GUIs")
    end)
    
    createButton("Force Hide All", function()
        if #protectedGuis > 0 then
            hideGuisInstant()
            print("Force hidden all " .. #protectedGuis .. " executor GUIs")
        else
            print("No executor GUIs found to hide")
        end
    end)
    
    createButton("Force Restore All", function()
        if #protectedGuis > 0 then
            restoreGuis()
            print("Force restored all " .. #protectedGuis .. " executor GUIs")
        else
            print("No executor GUIs found to restore")
        end
    end)
end

-- Function to reset Anti-Record states
function AntiRecord.resetStates()
    removeAntiRecord()
    protectedGuis = {}
    guiStates = {}
    antiRecordEnabled = false
    antiRecordSettings.Enabled = false
    antiRecordSettings.HideMethod = "Instant"
    antiRecordSettings.HideDelay = 0
    antiRecordSettings.ProtectKRNL = true
    antiRecordSettings.ProtectOtherExecutors = true
    antiRecordSettings.ProtectCoreGuis = false
    antiRecordSettings.ShowWarning = true
    
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
        settings.AntiRecordHideDelay = {value = 0, min = 0, max = 10, default = 0}
    end
    
    -- Start smart detection if enabled
    startSmartDetection()
    
    -- Auto-find and catalog GUIs on init
    task.spawn(function()
        task.wait(2) -- Wait for other GUIs to load
        if antiRecordSettings.ProtectKRNL or antiRecordSettings.ProtectOtherExecutors then
            findAndCatalogExecutorGUIs()
            print("Initial GUI scan complete. Found " .. #protectedGuis .. " executor GUIs")
        end
    end)
    
    -- Monitor for new GUIs being added
    local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    connections.guiMonitor = playerGui.ChildAdded:Connect(function(gui)
        if gui:IsA("ScreenGui") and gui ~= ScreenGui and gui.Name ~= "MinimalHackGUI" then
            task.wait(0.5) -- Wait for GUI to fully load
            if antiRecordSettings.ProtectKRNL or antiRecordSettings.ProtectOtherExecutors then
                local oldCount = #protectedGuis
                findAndCatalogExecutorGUIs()
                if #protectedGuis > oldCount then
                    print("New executor GUI detected: " .. gui.Name)
                    -- Auto-hide if anti-record is active
                    if antiRecordEnabled then
                        guiStates[gui] = gui.Enabled
                        gui.Enabled = false
                        print("Auto-hidden new executor GUI: " .. gui.Name)
                    end
                end
            end
        end
    end)
    
    -- Monitor for GUIs being removed
    connections.guiRemovedMonitor = playerGui.ChildRemoved:Connect(function(gui)
        if gui:IsA("ScreenGui") then
            -- Clean up references
            for i, protectedGui in pairs(protectedGuis) do
                if protectedGui == gui then
                    table.remove(protectedGuis, i)
                    guiStates[gui] = nil
                    print("Removed deleted GUI from protection list: " .. gui.Name)
                    break
                end
            end
        end
    end)
    
    print("Anti-Record module initialized - Hide GUI mode")
    print("Protection enabled for KRNL: " .. tostring(antiRecordSettings.ProtectKRNL))
    print("Protection enabled for Other Executors: " .. tostring(antiRecordSettings.ProtectOtherExecutors))
end

return AntiRecord