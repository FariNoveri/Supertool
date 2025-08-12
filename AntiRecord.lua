-- antirecord.lua
-- Simple Anti Screenshot/Record module for MinimalHackGUI by Fari Noveri
-- Android-friendly version - makes screenshots/recordings appear blank

-- Dependencies: These must be passed from mainloader.lua
local RunService, ScreenGui, settings

-- Initialize module
local AntiRecord = {}

-- Anti-record state
local antiProtectionEnabled = false
local connections = {}
local protectedGuis = {} -- Store references to protected GUIs
local guiStates = {} -- Store original visibility states
local blackOverlay = nil -- Black overlay for protection

-- Settings for anti-protection
local antiRecordSettings = {
    Enabled = false,
    ProtectKRNL = true, -- Protect KRNL executor GUI
    ProtectOtherExecutors = true, -- Protect other executor GUIs
    ShowWarning = false, -- Show warning (keep false for stealth)
    BlackoutMethod = "Overlay" -- "Overlay" or "Hide" - Overlay recommended for Android
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
                       string.find(text, "script") then
                        isExecutorGui = true
                        break
                    end
                elseif child.Name:lower():find("execute") or 
                       child.Name:lower():find("script") then
                    isExecutorGui = true
                    break
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
                end
            end
        end
    end
end

-- Create black overlay (makes screenshot/recording appear black)
local function createBlackOverlay()
    if blackOverlay then
        blackOverlay:Destroy()
    end
    
    -- Create main black overlay
    blackOverlay = Instance.new("Frame")
    blackOverlay.Name = "AntiRecordBlackOverlay"
    blackOverlay.Parent = ScreenGui
    blackOverlay.BackgroundColor3 = Color3.new(0, 0, 0) -- Pure black
    blackOverlay.BackgroundTransparency = 0 -- Completely opaque
    blackOverlay.BorderSizePixel = 0
    blackOverlay.Position = UDim2.new(0, 0, 0, 0)
    blackOverlay.Size = UDim2.new(1, 0, 1, 0)
    blackOverlay.ZIndex = 999999 -- Very high ZIndex to cover everything
    blackOverlay.Visible = true
    
    -- Make it cover the entire screen
    blackOverlay.Active = false -- Don't block input
    blackOverlay.Selectable = false
    
    print("Black overlay created - Screenshots/recordings will appear blank")
end

-- Hide GUIs method (alternative to black overlay)
local function hideProtectedGuis()
    for _, gui in pairs(protectedGuis) do
        if gui and gui.Parent then
            gui.Enabled = false
        end
    end
end

-- Restore GUIs
local function restoreProtectedGuis()
    for gui, originalState in pairs(guiStates) do
        if gui and gui.Parent then
            gui.Enabled = originalState
        end
    end
end

-- Apply anti-protection
local function applyAntiProtection()
    if not antiProtectionEnabled then return end
    
    if antiRecordSettings.BlackoutMethod == "Overlay" then
        createBlackOverlay()
        print("Anti-protection active: Black overlay method")
    elseif antiRecordSettings.BlackoutMethod == "Hide" then
        hideProtectedGuis()
        print("Anti-protection active: Hide GUIs method")
    end
    
    -- Optional warning (usually keep disabled for stealth)
    if antiRecordSettings.ShowWarning then
        showProtectionWarning()
    end
end

-- Remove anti-protection
local function removeAntiProtection()
    -- Remove black overlay
    if blackOverlay then
        blackOverlay:Destroy()
        blackOverlay = nil
    end
    
    -- Restore GUIs if they were hidden
    if antiRecordSettings.BlackoutMethod == "Hide" then
        restoreProtectedGuis()
    end
    
    -- Remove warning if exists
    local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    local warningGui = playerGui:FindFirstChild("AntiProtectionWarning")
    if warningGui then
        warningGui:Destroy()
    end
    
    for _, connection in pairs(connections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
    connections = {}
    
    print("Anti-protection disabled - GUIs restored")
end

-- Show protection warning (optional, usually disabled)
local function showProtectionWarning()
    if not antiRecordSettings.ShowWarning then return end
    
    local warningGui = Instance.new("ScreenGui")
    warningGui.Name = "AntiProtectionWarning"
    warningGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local warningFrame = Instance.new("Frame")
    warningFrame.Parent = warningGui
    warningFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
    warningFrame.BackgroundTransparency = 0.2
    warningFrame.BorderSizePixel = 2
    warningFrame.BorderColor3 = Color3.new(0, 1, 0)
    warningFrame.Position = UDim2.new(0.5, -150, 0.9, -50)
    warningFrame.Size = UDim2.new(0, 300, 0, 40)
    
    local warningText = Instance.new("TextLabel")
    warningText.Parent = warningFrame
    warningText.BackgroundTransparency = 1
    warningText.Position = UDim2.new(0, 5, 0, 5)
    warningText.Size = UDim2.new(1, -10, 1, -10)
    warningText.Font = Enum.Font.Gotham
    warningText.Text = "🛡️ Protection Active (" .. #protectedGuis .. " GUIs)"
    warningText.TextColor3 = Color3.new(0, 1, 0)
    warningText.TextSize = 12
    warningText.TextWrapped = true
    
    -- Auto-remove after 2 seconds
    task.spawn(function()
        task.wait(2)
        if warningGui and warningGui.Parent then
            warningGui:Destroy()
        end
    end)
end

-- Toggle anti-protection
local function toggleAntiProtection(enabled)
    antiProtectionEnabled = enabled
    antiRecordSettings.Enabled = enabled
    
    if enabled then
        -- Find and catalog GUIs before applying protection
        if antiRecordSettings.ProtectKRNL or antiRecordSettings.ProtectOtherExecutors then
            findAndCatalogExecutorGUIs()
        end
        
        print("Anti-protection enabled - Method: " .. antiRecordSettings.BlackoutMethod)
        print("Protected GUIs: " .. #protectedGuis)
        applyAntiProtection()
    else
        print("Anti-protection disabled")
        removeAntiProtection()
    end
end

-- Change protection method
local function changeBlackoutMethod(method)
    antiRecordSettings.BlackoutMethod = method
    print("Protection method changed to: " .. method)
    
    if antiProtectionEnabled then
        removeAntiProtection()
        task.wait(0.1)
        applyAntiProtection()
    end
end

-- Get current settings
function AntiRecord.getSettings()
    return antiRecordSettings
end

-- Function to create buttons for Anti-Protection features
function AntiRecord.loadAntiRecordButtons(createButton, createToggleButton)
    -- Main toggle
    createToggleButton("Enable Anti-Protection", function(enabled)
        toggleAntiProtection(enabled)
    end)
    
    -- Protection options
    createToggleButton("Protect KRNL GUI", function(enabled)
        antiRecordSettings.ProtectKRNL = enabled
        if antiProtectionEnabled then
            removeAntiProtection()
            task.wait(0.1)
            findAndCatalogExecutorGUIs()
            applyAntiProtection()
        end
    end)
    
    createToggleButton("Protect Other Executors", function(enabled)
        antiRecordSettings.ProtectOtherExecutors = enabled
        if antiProtectionEnabled then
            removeAntiProtection()
            task.wait(0.1)
            findAndCatalogExecutorGUIs()
            applyAntiProtection()
        end
    end)
    
    createToggleButton("Show Warning", function(enabled)
        antiRecordSettings.ShowWarning = enabled
    end)
    
    -- Method selection
    createButton("Method: Black Overlay", function()
        changeBlackoutMethod("Overlay")
    end)
    
    createButton("Method: Hide GUIs", function()
        changeBlackoutMethod("Hide")
    end)
    
    -- Utility buttons
    createButton("Refresh Protected GUIs", function()
        findAndCatalogExecutorGUIs()
        print("Refreshed. Found " .. #protectedGuis .. " executor GUIs")
        
        if antiProtectionEnabled then
            removeAntiProtection()
            task.wait(0.1)
            applyAntiProtection()
        end
    end)
    
    createButton("List Protected GUIs", function()
        print("=== PROTECTED EXECUTOR GUIS ===")
        for i, gui in pairs(protectedGuis) do
            print(i .. ". " .. gui.Name)
        end
        print("Total: " .. #protectedGuis .. " GUIs")
    end)
    
    createButton("Test Protection", function()
        if antiProtectionEnabled then
            print("Protection is active - screenshots should appear blank")
        else
            print("Protection is disabled - enable it first")
        end
    end)
end

-- Function to reset states
function AntiRecord.resetStates()
    removeAntiProtection()
    protectedGuis = {}
    guiStates = {}
    antiProtectionEnabled = false
    
    -- Reset settings
    antiRecordSettings.Enabled = false
    antiRecordSettings.ProtectKRNL = true
    antiRecordSettings.ProtectOtherExecutors = true
    antiRecordSettings.ShowWarning = false
    antiRecordSettings.BlackoutMethod = "Overlay"
    
    -- Clean up black overlay
    if blackOverlay then
        blackOverlay:Destroy()
        blackOverlay = nil
    end
    
    for _, connection in pairs(connections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end
    connections = {}
    
    print("Anti-protection states reset")
end

-- Function to set dependencies and initialize
function AntiRecord.init(deps)
    RunService = deps.RunService
    ScreenGui = deps.ScreenGui
    settings = deps.settings
    
    -- Auto-find and catalog GUIs on init
    task.spawn(function()
        task.wait(2) -- Wait for other GUIs to load
        if antiRecordSettings.ProtectKRNL or antiRecordSettings.ProtectOtherExecutors then
            findAndCatalogExecutorGUIs()
            print("Found " .. #protectedGuis .. " executor GUIs to protect")
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
                    -- Apply protection to new GUI if active
                    if antiProtectionEnabled then
                        guiStates[gui] = gui.Enabled
                        if antiRecordSettings.BlackoutMethod == "Hide" then
                            gui.Enabled = false
                        end
                        -- Black overlay already covers everything
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
                    break
                end
            end
        end
    end)
    
    print("Anti-Protection module initialized (Android-friendly)")
    print("KRNL protection: " .. tostring(antiRecordSettings.ProtectKRNL))
    print("Other executors protection: " .. tostring(antiRecordSettings.ProtectOtherExecutors))
    print("Method: " .. antiRecordSettings.BlackoutMethod)
end

return AntiRecord