-- Info.lua - GhostHub Style Profile Card for MinimalHackGUI by Fari Noveri

local Info = {}
local initialized = false
local scrollFrame

-- Initialize the Info module
function Info.init(deps)
    if initialized then return true end
    
    scrollFrame = deps.ScrollFrame
    if not scrollFrame then
        warn("Info: ScrollFrame dependency not found")
        return false
    end
    
    initialized = true
    print("Info module initialized successfully (GhostHub Style)")
    return true
end

-- Main function to create the profile display
function Info.createInfoDisplay(container)
    if not initialized then
        warn("Info module not initialized")
        return false
    end

    if not container then
        warn("Info: No container provided")
        return false
    end

    -- Clear existing content
    for _, child in pairs(container:GetChildren()) do
        if child:IsA("GuiObject") and child.Name ~= "UIListLayout" then
            child:Destroy()
        end
    end

    -- Main Profile Card Container
    local profileCard = Instance.new("Frame")
    profileCard.Name = "ProfileCard"
    profileCard.Parent = container
    profileCard.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    profileCard.BorderSizePixel = 0
    profileCard.Size = UDim2.new(1, -10, 0, 280)
    profileCard.Position = UDim2.new(0, 5, 0, 5)
    profileCard.LayoutOrder = 1
    
    -- Rounded corners
    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 12)
    cardCorner.Parent = profileCard
    
    -- Gradient background effect
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 50)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 25, 30))
    }
    gradient.Rotation = 135
    gradient.Parent = profileCard
    
    -- Profile Picture Frame
    local profilePicFrame = Instance.new("Frame")
    profilePicFrame.Name = "ProfilePicFrame"
    profilePicFrame.Parent = profileCard
    profilePicFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    profilePicFrame.BorderSizePixel = 0
    profilePicFrame.Position = UDim2.new(0.5, -45, 0, 15)
    profilePicFrame.Size = UDim2.new(0, 90, 0, 90)
    
    -- Circular profile picture
    local profileCorner = Instance.new("UICorner")
    profileCorner.CornerRadius = UDim.new(1, 0)
    profileCorner.Parent = profilePicFrame
    
    -- Profile border glow effect
    local profileBorder = Instance.new("UIStroke")
    profileBorder.Color = Color3.fromRGB(100, 150, 255)
    profileBorder.Thickness = 3
    profileBorder.Parent = profilePicFrame
    
    -- Profile Image
    local profileImage = Instance.new("ImageLabel")
    profileImage.Name = "ProfileImage"
    profileImage.Parent = profilePicFrame
    profileImage.BackgroundTransparency = 1
    profileImage.Size = UDim2.new(1, 0, 1, 0)
    profileImage.Image = "https://cdn.rafled.com/anime-icons/images/cADJDgHDli9YzzGB5AhH0Aa2dR8Bfu8w.jpg" -- Your logo/profile pic
    profileImage.ScaleType = Enum.ScaleType.Fit
    
    local imageCorner = Instance.new("UICorner")
    imageCorner.CornerRadius = UDim.new(1, 0)
    imageCorner.Parent = profileImage
    
    -- Creator Name
    local creatorName = Instance.new("TextLabel")
    creatorName.Name = "CreatorName"
    creatorName.Parent = profileCard
    creatorName.BackgroundTransparency = 1
    creatorName.Position = UDim2.new(0, 10, 0, 115)
    creatorName.Size = UDim2.new(1, -20, 0, 25)
    creatorName.Font = Enum.Font.GothamBold
    creatorName.Text = "Fari Noveri"
    creatorName.TextColor3 = Color3.fromRGB(255, 255, 255)
    creatorName.TextSize = 18
    creatorName.TextXAlignment = Enum.TextXAlignment.Center
    
    -- Title/Role
    local roleLabel = Instance.new("TextLabel")
    roleLabel.Name = "RoleLabel"
    roleLabel.Parent = profileCard
    roleLabel.BackgroundTransparency = 1
    roleLabel.Position = UDim2.new(0, 10, 0, 142)
    roleLabel.Size = UDim2.new(1, -20, 0, 18)
    roleLabel.Font = Enum.Font.Gotham
    roleLabel.Text = "Script Developer & Creator"
    roleLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
    roleLabel.TextSize = 11
    roleLabel.TextXAlignment = Enum.TextXAlignment.Center
    
    -- Divider Line
    local divider = Instance.new("Frame")
    divider.Name = "Divider"
    divider.Parent = profileCard
    divider.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    divider.BorderSizePixel = 0
    divider.Position = UDim2.new(0.1, 0, 0, 170)
    divider.Size = UDim2.new(0.8, 0, 0, 1)
    
    -- Stats Container
    local statsContainer = Instance.new("Frame")
    statsContainer.Name = "StatsContainer"
    statsContainer.Parent = profileCard
    statsContainer.BackgroundTransparency = 1
    statsContainer.Position = UDim2.new(0, 10, 0, 180)
    statsContainer.Size = UDim2.new(1, -20, 0, 90)
    
    -- Stat items
    local stats = {
        {label = "GUI Version", value = "v2.5"},
        {label = "Total Features", value = "60+"},
        {label = "Categories", value = "9"}
    }
    
    for i, stat in ipairs(stats) do
        local statFrame = Instance.new("Frame")
        statFrame.Name = "Stat" .. i
        statFrame.Parent = statsContainer
        statFrame.BackgroundTransparency = 1
        statFrame.Position = UDim2.new(0, 0, 0, (i-1) * 30)
        statFrame.Size = UDim2.new(1, 0, 0, 25)
        
        local statLabel = Instance.new("TextLabel")
        statLabel.Name = "Label"
        statLabel.Parent = statFrame
        statLabel.BackgroundTransparency = 1
        statLabel.Position = UDim2.new(0, 5, 0, 0)
        statLabel.Size = UDim2.new(0.5, -5, 1, 0)
        statLabel.Font = Enum.Font.Gotham
        statLabel.Text = stat.label .. ":"
        statLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        statLabel.TextSize = 10
        statLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local statValue = Instance.new("TextLabel")
        statValue.Name = "Value"
        statValue.Parent = statFrame
        statValue.BackgroundTransparency = 1
        statValue.Position = UDim2.new(0.5, 0, 0, 0)
        statValue.Size = UDim2.new(0.5, -5, 1, 0)
        statValue.Font = Enum.Font.GothamBold
        statValue.Text = stat.value
        statValue.TextColor3 = Color3.fromRGB(100, 200, 255)
        statValue.TextSize = 11
        statValue.TextXAlignment = Enum.TextXAlignment.Right
    end
    
    -- Description Card
    local descCard = Instance.new("Frame")
    descCard.Name = "DescriptionCard"
    descCard.Parent = container
    descCard.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    descCard.BorderSizePixel = 0
    descCard.Size = UDim2.new(1, -10, 0, 150)
    descCard.Position = UDim2.new(0, 5, 0, 0)
    descCard.LayoutOrder = 2
    
    local descCorner = Instance.new("UICorner")
    descCorner.CornerRadius = UDim.new(0, 12)
    descCorner.Parent = descCard
    
    -- Description Title
    local descTitle = Instance.new("TextLabel")
    descTitle.Name = "DescTitle"
    descTitle.Parent = descCard
    descTitle.BackgroundTransparency = 1
    descTitle.Position = UDim2.new(0, 15, 0, 10)
    descTitle.Size = UDim2.new(1, -30, 0, 20)
    descTitle.Font = Enum.Font.GothamBold
    descTitle.Text = "📝 About MinimalHackGUI"
    descTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    descTitle.TextSize = 12
    descTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Description Text
    local descText = Instance.new("TextLabel")
    descText.Name = "DescText"
    descText.Parent = descCard
    descText.BackgroundTransparency = 1
    descText.Position = UDim2.new(0, 15, 0, 35)
    descText.Size = UDim2.new(1, -30, 0, 105)
    descText.Font = Enum.Font.Gotham
    descText.Text = "MinimalHackGUI adalah script exploit yang powerful namun tetap ringan dan mudah digunakan. Dilengkapi dengan berbagai fitur seperti Movement, Player Control, Teleport, Visual Effects, dan Anti-Admin protection.\n\nDibuat dengan ❤️ untuk komunitas Roblox exploiting."
    descText.TextColor3 = Color3.fromRGB(200, 200, 200)
    descText.TextSize = 9
    descText.TextXAlignment = Enum.TextXAlignment.Left
    descText.TextYAlignment = Enum.TextYAlignment.Top
    descText.TextWrapped = true
    
    -- Features Highlight Card
    local featuresCard = Instance.new("Frame")
    featuresCard.Name = "FeaturesCard"
    featuresCard.Parent = container
    featuresCard.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    featuresCard.BorderSizePixel = 0
    featuresCard.Size = UDim2.new(1, -10, 0, 200)
    featuresCard.Position = UDim2.new(0, 5, 0, 0)
    featuresCard.LayoutOrder = 3
    
    local featCorner = Instance.new("UICorner")
    featCorner.CornerRadius = UDim.new(0, 12)
    featCorner.Parent = featuresCard
    
    -- Features Title
    local featTitle = Instance.new("TextLabel")
    featTitle.Name = "FeatTitle"
    featTitle.Parent = featuresCard
    featTitle.BackgroundTransparency = 1
    featTitle.Position = UDim2.new(0, 15, 0, 10)
    featTitle.Size = UDim2.new(1, -30, 0, 20)
    featTitle.Font = Enum.Font.GothamBold
    featTitle.Text = "⚡ Key Features"
    featTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    featTitle.TextSize = 12
    featTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Feature highlights list
    local highlights = {
        "🚀 Advanced Movement System (Fly, NoClip, Speed)",
        "👥 Player Interaction Tools (Spectate, Teleport)",
        "📍 Smart Teleport with Position Manager",
        "👁️ Visual Enhancements (ESP, Freecam, Fullbright)",
        "🛡️ Anti-Admin Protection System",
        "🎮 Mobile-Friendly Controls",
        "⚙️ Customizable GUI Settings",
        "💾 Save/Load System for Positions & Paths"
    }
    
    for i, highlight in ipairs(highlights) do
        local highlightLabel = Instance.new("TextLabel")
        highlightLabel.Name = "Highlight" .. i
        highlightLabel.Parent = featuresCard
        highlightLabel.BackgroundTransparency = 1
        highlightLabel.Position = UDim2.new(0, 20, 0, 30 + (i-1) * 20)
        highlightLabel.Size = UDim2.new(1, -40, 0, 18)
        highlightLabel.Font = Enum.Font.Gotham
        highlightLabel.Text = highlight
        highlightLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        highlightLabel.TextSize = 9
        highlightLabel.TextXAlignment = Enum.TextXAlignment.Left
    end
    
    -- Contact/Social Card
    local socialCard = Instance.new("Frame")
    socialCard.Name = "SocialCard"
    socialCard.Parent = container
    socialCard.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    socialCard.BorderSizePixel = 0
    socialCard.Size = UDim2.new(1, -10, 0, 120)
    socialCard.Position = UDim2.new(0, 5, 0, 0)
    socialCard.LayoutOrder = 4
    
    local socialCorner = Instance.new("UICorner")
    socialCorner.CornerRadius = UDim.new(0, 12)
    socialCorner.Parent = socialCard
    
    -- Social Title
    local socialTitle = Instance.new("TextLabel")
    socialTitle.Name = "SocialTitle"
    socialTitle.Parent = socialCard
    socialTitle.BackgroundTransparency = 1
    socialTitle.Position = UDim2.new(0, 15, 0, 10)
    socialTitle.Size = UDim2.new(1, -30, 0, 20)
    socialTitle.Font = Enum.Font.GothamBold
    socialTitle.Text = "🔗 Connect"
    socialTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    socialTitle.TextSize = 12
    socialTitle.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Social info
    local socialInfo = {
        {icon = "📧", text = "GitHub: FariNoveri"},
        {icon = "💬", text = "Discord: Available on request"},
        {icon = "🌐", text = "Repository: Supertool"}
    }
    
    for i, info in ipairs(socialInfo) do
        local infoLabel = Instance.new("TextLabel")
        infoLabel.Name = "Social" .. i
        infoLabel.Parent = socialCard
        infoLabel.BackgroundTransparency = 1
        infoLabel.Position = UDim2.new(0, 20, 0, 35 + (i-1) * 25)
        infoLabel.Size = UDim2.new(1, -40, 0, 20)
        infoLabel.Font = Enum.Font.Gotham
        infoLabel.Text = info.icon .. "  " .. info.text
        infoLabel.TextColor3 = Color3.fromRGB(180, 180, 220)
        infoLabel.TextSize = 9
        infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    end
    
    -- Footer
    local footer = Instance.new("TextLabel")
    footer.Name = "Footer"
    footer.Parent = container
    footer.BackgroundTransparency = 1
    footer.Size = UDim2.new(1, -10, 0, 40)
    footer.Position = UDim2.new(0, 5, 0, 0)
    footer.Font = Enum.Font.Gotham
    footer.Text = "Press HOME to toggle GUI\nMade with ❤️ by Fari Noveri © 2025"
    footer.TextColor3 = Color3.fromRGB(120, 120, 120)
    footer.TextSize = 8
    footer.TextXAlignment = Enum.TextXAlignment.Center
    footer.TextWrapped = true
    footer.LayoutOrder = 5
    
    print("✨ GhostHub style profile display created successfully")
    
    return true
end

-- Reset function
function Info.resetStates()
    return true
end

-- Update references function
function Info.updateReferences()
    return true
end

-- Check if module is initialized
function Info.isInitialized()
    return initialized
end

return Info