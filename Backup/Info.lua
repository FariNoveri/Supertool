-- Info.lua - Feature Information Display for MinimalHackGUI by Fari Noveri

local Info = {}
local initialized = false
local scrollFrame

-- Feature information organized by category
local featureInfo = {
    ["Movement"] = {
        {
            name = "Speed Hack",
            description = "Increases your walking/running speed beyond normal limits. Adjustable speed in settings."
        },
        {
            name = "Jump Hack", 
            description = "Modify jump height and power. Includes infinite jump capability."
        },
        {
            name = "Fly",
            description = "Enables flight with WASD controls. Mobile joystick support included."
        },
        {
            name = "NoClip",
            description = "Walk through walls and objects. Toggle on/off as needed."
        },
        {
            name = "Infinite Jump",
            description = "Jump unlimited times in mid-air without touching ground."
        },
        {
            name = "Walk on Water",
            description = "Walk on water surfaces instead of swimming through them."
        },
        {
            name = "Super Swim",
            description = "Enhanced swimming speed and underwater movement capabilities."
        },
        {
            name = "Moon Gravity",
            description = "Reduces gravity effects for floaty, moon-like movement."
        },
        {
            name = "Double Jump",
            description = "Perform a second jump while in mid-air for extra height."
        },
        {
            name = "Wall Climb",
            description = "Climb walls and vertical surfaces with mobile controls."
        },
        {
            name = "Float",
            description = "Hover in place without falling due to gravity effects."
        },
        {
            name = "Smooth Rewind",
            description = "Rewind your position smoothly to previous locations."
        },
        {
            name = "Boost (NOS)",
            description = "Temporary speed boost activation for quick movement bursts."
        },
        {
            name = "Slow Fall",
            description = "Reduces falling speed for safer landings and better control."
        },
        {
            name = "Fast Fall",
            description = "Increases falling speed for quicker ground contact."
        },
        {
            name = "Sprint",
            description = "Enhanced running speed with stamina-like mechanics."
        },
        {
            name = "Mobile Controls",
            description = "Touch-friendly joystick and button controls for mobile devices."
        },
        {
            name = "Chat Commands",
            description = "Use commands like /fly, /speed, /jump for quick feature access."
        }
    },
    
    ["Player"] = {
        {
            name = "Spectate",
            description = "Watch other players from their perspective or follow their movements."
        },
        {
            name = "Player List",
            description = "Browse and select players for various actions and interactions."
        },
        {
            name = "Freeze Players",
            description = "Temporarily freeze other players in place (admin required)."
        },
        {
            name = "Bring Player",
            description = "Teleport selected players to your current location."
        },
        {
            name = "Fling",
            description = "Launch players with physics forces for fun interactions."
        },
        {
            name = "Magnet Player",
            description = "Attract or pull players towards your position continuously."
        },
        {
            name = "Follow Player",
            description = "Automatically follow a selected player's movements."
        },
        {
            name = "Fast Respawn",
            description = "Quickly respawn without waiting for normal respawn timer."
        },
        {
            name = "No Death Animation",
            description = "Skip death animations for faster gameplay flow."
        },
        {
            name = "Physics Control",
            description = "Manipulate player physics properties and interactions."
        },
        {
            name = "Teleport to Player",
            description = "Instantly teleport to any selected player's location."
        },
        {
            name = "Back/Next Teleport",
            description = "Navigate between players using back and next buttons."
        },
        {
            name = "Emote Menu",
            description = "Access and play various character emotes and animations."
        },
        {
            name = "Chat Commands",
            description = "Player commands: /tp, /bring, /follow, /fling, /freeze, etc."
        }
    },
    
    ["Teleport"] = {
        {
            name = "Position Manager",
            description = "Save, load, and manage named teleport positions with JSON storage."
        },
        {
            name = "Save Positions",
            description = "Save current or freecam positions with custom names and numbers."
        },
        {
            name = "Auto Teleport",
            description = "Automatic teleportation with once/repeat modes and adjustable delays."
        },
        {
            name = "TP to Freecam",
            description = "Teleport your character to current freecam position."
        },
        {
            name = "TP to Spawn",
            description = "Return to the game's default spawn location instantly."
        },
        {
            name = "Directional TP",
            description = "Teleport in specific directions: Forward, Backward, Left, Right, Down."
        },
        {
            name = "Position Sync",
            description = "Synchronize saved positions across sessions with JSON files."
        },
        {
            name = "Position Sorting",
            description = "Organize positions with numbers and custom names for easy access."
        }
    },
    
    ["Utility"] = {
        {
            name = "Path Recording",
            description = "Record your movement path for later playback and analysis."
        },
        {
            name = "Path Manager",
            description = "Save, load, and manage recorded paths with JSON storage system."
        },
        {
            name = "Path Playback",
            description = "Play paths in single, loop, or auto-respawn modes with speed control."
        },
        {
            name = "Visual Markers",
            description = "See path points and movement types (walk, jump, fall, swim, idle)."
        },
        {
            name = "Undo System",
            description = "Undo to last marker with Ctrl+Z during path playback."
        },
        {
            name = "Path Search",
            description = "Search through saved paths with filtering and organization."
        },
        {
            name = "Kill Player",
            description = "Instantly eliminate your character (respawn trigger)."
        },
        {
            name = "Reset Character",
            description = "Reset character to default state and spawn location."
        },
        {
            name = "Clear Visuals",
            description = "Remove all visual effects, markers, and temporary objects."
        }
    },
    
    ["Visual"] = {
        {
            name = "Freecam",
            description = "Free camera movement with WASD/QEZC controls and mobile joystick support."
        },
        {
            name = "NoClipCamera",
            description = "Camera passes through walls and objects for unrestricted viewing."
        },
        {
            name = "Fullbright",
            description = "Brightens the entire environment for better visibility in dark areas."
        },
        {
            name = "Flashlight",
            description = "Adds spot and point lighting to player head for illumination."
        },
        {
            name = "Low Detail Mode",
            description = "Reduces shadows, effects, and textures for better performance."
        },
        {
            name = "Ultra Low Detail",
            description = "Hides environment objects and further reduces visual detail."
        },
        {
            name = "ESP",
            description = "Highlights players with health-based colors and detects invisible players."
        },
        {
            name = "Hide Nicknames",
            description = "Hide other players' nicknames or your own nickname display."
        },
        {
            name = "Character Transparency",
            description = "Make other players' characters or your own character transparent."
        },
        {
            name = "Time Control",
            description = "Change lighting to Morning, Day, Evening, or Night settings."
        },
        {
            name = "Self Highlight",
            description = "Add customizable outline colors to your character with color picker."
        }
    },
    
    ["AntiAdmin"] = {
        {
            name = "Main Protection",
            description = "Blocks admin attempts to kill, teleport, or modify your character."
        },
        {
            name = "Mass Protection",
            description = "Detects and cleans part spam, sound spam, and restores lighting."
        },
        {
            name = "Stealth Mode",
            description = "Anti-detection system to avoid script scanning and detection."
        },
        {
            name = "Memory Protection",
            description = "Simulates normal memory usage patterns to avoid detection."
        },
        {
            name = "Advanced Bypass",
            description = "Safe memory operations that simulate normal player behavior."
        },
        {
            name = "Protection Watermark",
            description = "Displays Anti-Admin protection status and information in UI."
        }
    }
}

-- Initialize the Info module
function Info.init(deps)
    if initialized then return true end
    
    scrollFrame = deps.ScrollFrame
    if not scrollFrame then
        warn("Info: ScrollFrame dependency not found")
        return false
    end
    
    initialized = true
    print("Info module initialized successfully")
    return true
end

-- Create a feature entry with name, description, and simple photo placeholder
local function createFeatureEntry(parent, feature, layoutOrder)
    -- Main container frame
    local container = Instance.new("Frame")
    container.Name = "FeatureEntry_" .. feature.name
    container.Parent = parent
    container.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    container.BorderColor3 = Color3.fromRGB(60, 60, 60)
    container.BorderSizePixel = 1
    container.Size = UDim2.new(1, -4, 0, 60)
    container.Position = UDim2.new(0, 2, 0, 0)
    container.LayoutOrder = layoutOrder

    -- Feature name label
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Parent = container
    nameLabel.BackgroundTransparency = 1
    nameLabel.Position = UDim2.new(0, 5, 0, 2)
    nameLabel.Size = UDim2.new(0.75, -5, 0, 15)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.Text = feature.name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 10
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextYAlignment = Enum.TextYAlignment.Center

    -- Description label
    local descLabel = Instance.new("TextLabel")
    descLabel.Name = "DescLabel"
    descLabel.Parent = container
    descLabel.BackgroundTransparency = 1
    descLabel.Position = UDim2.new(0, 5, 0, 17)
    descLabel.Size = UDim2.new(0.75, -5, 0, 40)
    descLabel.Font = Enum.Font.Gotham
    descLabel.Text = feature.description
    descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    descLabel.TextSize = 8
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.TextYAlignment = Enum.TextYAlignment.Top
    descLabel.TextWrapped = true

    -- Simple photo placeholder with actual image
    local imageFrame = Instance.new("Frame")
    imageFrame.Name = "ImageFrame"
    imageFrame.Parent = container
    imageFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    imageFrame.BorderColor3 = Color3.fromRGB(80, 80, 80)
    imageFrame.BorderSizePixel = 1
    imageFrame.Position = UDim2.new(0.78, 0, 0, 5)
    imageFrame.Size = UDim2.new(0, 50, 0, 50)

    -- Try to load the Shutterstock image, fallback to text if fails
    local imageLabel = Instance.new("ImageLabel")
    imageLabel.Name = "ActualImage"
    imageLabel.Parent = imageFrame
    imageLabel.BackgroundTransparency = 1
    imageLabel.Size = UDim2.new(1, 0, 1, 0)
    imageLabel.Image = defaultImageURL
    imageLabel.ScaleType = Enum.ScaleType.Fit

    -- Fallback text label if image fails to load
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "FallbackText"
    textLabel.Parent = imageFrame
    textLabel.BackgroundTransparency = 1
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.Font = Enum.Font.Gotham
    textLabel.Text = "[link foto]"
    textLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
    textLabel.TextSize = 7
    textLabel.TextXAlignment = Enum.TextXAlignment.Center
    textLabel.TextYAlignment = Enum.TextYAlignment.Center
    textLabel.Visible = false

    -- Show fallback if image fails
    task.spawn(function()
        task.wait(2) -- Wait for image to load
        if imageLabel.Image == "" or not imageLabel.IsLoaded then
            textLabel.Visible = true
            imageLabel.Visible = false
        end
    end)

    return container
end

-- Create category header
local function createCategoryHeader(parent, categoryName, layoutOrder)
    local header = Instance.new("Frame")
    header.Name = "CategoryHeader_" .. categoryName
    header.Parent = parent
    header.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    header.BorderColor3 = Color3.fromRGB(80, 80, 80)
    header.BorderSizePixel = 1
    header.Size = UDim2.new(1, -4, 0, 30)
    header.Position = UDim2.new(0, 2, 0, 0)
    header.LayoutOrder = layoutOrder

    local headerLabel = Instance.new("TextLabel")
    headerLabel.Name = "HeaderLabel"
    headerLabel.Parent = header
    headerLabel.BackgroundTransparency = 1
    headerLabel.Position = UDim2.new(0, 10, 0, 0)
    headerLabel.Size = UDim2.new(1, -20, 1, 0)
    headerLabel.Font = Enum.Font.GothamBold
    headerLabel.Text = "Kategori " .. categoryName
    headerLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    headerLabel.TextSize = 12
    headerLabel.TextXAlignment = Enum.TextXAlignment.Left
    headerLabel.TextYAlignment = Enum.TextYAlignment.Center

    return header
end

-- Create separator line
local function createSeparator(parent, layoutOrder)
    local separator = Instance.new("Frame")
    separator.Name = "Separator"
    separator.Parent = parent
    separator.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    separator.BorderSizePixel = 0
    separator.Size = UDim2.new(1, -10, 0, 2)
    separator.Position = UDim2.new(0, 5, 0, 0)
    separator.LayoutOrder = layoutOrder

    -- Add dashed line effect
    for i = 0, 20 do
        local dash = Instance.new("Frame")
        dash.Parent = separator
        dash.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        dash.BorderSizePixel = 0
        dash.Size = UDim2.new(0, 15, 1, 0)
        dash.Position = UDim2.new(0, i * 20, 0, 0)
    end

    return separator
end

-- Main function to create the info display
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

    -- Create title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "InfoTitle"
    titleLabel.Parent = container
    titleLabel.BackgroundTransparency = 1
    titleLabel.Size = UDim2.new(1, -4, 0, 25)
    titleLabel.Position = UDim2.new(0, 2, 0, 0)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "MinimalHackGUI - Informasi Fitur"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
    titleLabel.TextSize = 12
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.LayoutOrder = 1

    -- Create subtitle
    local subtitleLabel = Instance.new("TextLabel")
    subtitleLabel.Name = "InfoSubtitle"
    subtitleLabel.Parent = container
    subtitleLabel.BackgroundTransparency = 1
    subtitleLabel.Size = UDim2.new(1, -4, 0, 20)
    subtitleLabel.Position = UDim2.new(0, 2, 0, 0)
    subtitleLabel.Font = Enum.Font.Gotham
    subtitleLabel.Text = "Daftar lengkap semua fitur yang tersedia beserta deskripsinya"
    subtitleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    subtitleLabel.TextSize = 8
    subtitleLabel.TextXAlignment = Enum.TextXAlignment.Center
    subtitleLabel.LayoutOrder = 2

    local layoutOrder = 3

    -- Process each category
    for _, categoryData in ipairs({
        {name = "Movement", info = featureInfo["Movement"]},
        {name = "Player", info = featureInfo["Player"]},
        {name = "Teleport", info = featureInfo["Teleport"]},
        {name = "Utility", info = featureInfo["Utility"]},
        {name = "Visual", info = featureInfo["Visual"]},
        {name = "AntiAdmin", info = featureInfo["AntiAdmin"]}
    }) do
        
        if categoryData.info then
            -- Create category header
            createCategoryHeader(container, categoryData.name, layoutOrder)
            layoutOrder = layoutOrder + 1

            -- Create features for this category
            for _, feature in ipairs(categoryData.info) do
                createFeatureEntry(container, feature, layoutOrder)
                layoutOrder = layoutOrder + 1
            end

            -- Add separator after each category
            createSeparator(container, layoutOrder)
            layoutOrder = layoutOrder + 1
        end
    end

    -- Add footer information
    local footerLabel = Instance.new("TextLabel")
    footerLabel.Name = "InfoFooter"
    footerLabel.Parent = container
    footerLabel.BackgroundTransparency = 1
    footerLabel.Size = UDim2.new(1, -4, 0, 40)
    footerLabel.Position = UDim2.new(0, 2, 0, 0)
    footerLabel.Font = Enum.Font.Gotham
    footerLabel.Text = "Gunakan tombol kategori di sebelah kiri untuk mengakses fitur-fitur ini.\nTekan tombol HOME untuk toggle GUI.\n\nDibuat oleh Fari Noveri"
    footerLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    footerLabel.TextSize = 8
    footerLabel.TextXAlignment = Enum.TextXAlignment.Center
    footerLabel.TextYAlignment = Enum.TextYAlignment.Center
    footerLabel.TextWrapped = true
    footerLabel.LayoutOrder = layoutOrder

    print("Info display berhasil dibuat dengan " .. (
        #featureInfo["Movement"] + 
        #featureInfo["Player"] + 
        #featureInfo["Teleport"] + 
        #featureInfo["Utility"] + 
        #featureInfo["Visual"] + 
        #featureInfo["AntiAdmin"]
    ) .. " fitur")
    
    return true
end

-- Reset function
function Info.resetStates()
    -- Nothing to reset for info module
    return true
end

-- Update references function
function Info.updateReferences()
    -- Info module doesn't need reference updates
    return true
end

-- Check if module is initialized
function Info.isInitialized()
    return initialized
end

return Info