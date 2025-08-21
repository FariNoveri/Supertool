-- info.lua
-- Info-related features for MinimalHackGUI by Fari Noveri

-- Dependencies: These must be passed from mainloader.lua
local ScreenGui

-- Initialize module
local Info = {}

-- Function to create info display elements inside the feature container
function Info.loadInfoButtons(createButton)
    -- We need access to the FeatureContainer to create text labels directly
    -- This will be handled by the main loader by passing the container
end

-- Function to create info text display
function Info.createInfoDisplay(featureContainer)
    -- Clear any existing content first
    for _, child in pairs(featureContainer:GetChildren()) do
        if child:IsA("TextLabel") and string.find(child.Name, "InfoLabel") then
            child:Destroy()
        end
    end
    
    local infoTexts = {
        "═══════════════════════════════════",
        "      MinimalHackGUI v2.0 Info",
        "═══════════════════════════════════",
        "",
        "👑 Script Creator: Fari Noveri",
        "🔧 Status: Aktif & Terus Update",
        "📅 Last Update: August 2025",
        "",
        "⚠️  DISCLAIMER & RULES:",
        "• Belum ada bypass untuk anti-cheat",
        "• Gunakan dengan bijak dan hati-hati",
        "• Jika kena ban, tanggung sendiri",
        "• Jangan spam atau abuse features",
        "• Script ini GRATIS, jangan dijual",
        "",
        "🎮 FEATURES:",
        "• Movement Hacks (Fly, Speed, dll)",
        "• Player Tools (Teleport, ESP, dll)", 
        "• Visual Enhancements",
        "• Utility Functions",
        "",
        "📞 CONTACT & SUPPORT:",
        "• Instagram: @fariinoveri",
        "• TikTok: @fari_noveri",
        "• Untuk bug report & suggestions",
        "",
        "💝 CREDITS:",
        "• Thanks to all beta testers",
        "• Thanks to Roblox community",
        "",
        "═══════════════════════════════════",
        "    Enjoy the script responsibly!",
        "═══════════════════════════════════"
    }
    
    for i, text in ipairs(infoTexts) do
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Name = "InfoLabel" .. i
        infoLabel.Parent = featureContainer
        infoLabel.BackgroundTransparency = 1
        infoLabel.Size = UDim2.new(1, -2, 0, text == "" and 10 or 20)
        infoLabel.Font = Enum.Font.Gotham
        infoLabel.Text = text
        infoLabel.TextColor3 = text == "" and Color3.fromRGB(0, 0, 0) or 
                              (string.find(text, "═══") and Color3.fromRGB(100, 255, 255) or
                              (string.find(text, "MinimalHackGUI") and Color3.fromRGB(255, 215, 0) or
                              (string.find(text, "👑") and Color3.fromRGB(255, 215, 0) or
                              (string.find(text, "⚠️") or string.find(text, "ban") or string.find(text, "bijak")) and Color3.fromRGB(255, 100, 100) or
                              (string.find(text, "📞") or string.find(text, "CONTACT")) and Color3.fromRGB(100, 255, 100) or
                              (string.find(text, "🎮") or string.find(text, "FEATURES")) and Color3.fromRGB(150, 150, 255) or
                              (string.find(text, "💝") or string.find(text, "CREDITS")) and Color3.fromRGB(255, 150, 255) or
                              (string.find(text, "Instagram") or string.find(text, "TikTok")) and Color3.fromRGB(100, 255, 100) or
                              (string.find(text, "Enjoy")) and Color3.fromRGB(255, 215, 0) or
                              Color3.fromRGB(200, 200, 200))))
        infoLabel.TextSize = 10
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
        infoLabel.LayoutOrder = i
    end
end

-- Function to reset Info states
function Info.resetStates()
    -- No persistent states in Info, but included for consistency
end

-- Function to set dependencies
function Info.init(deps)
    ScreenGui = deps.ScreenGui
    print("Info module initialized")
end

return Info