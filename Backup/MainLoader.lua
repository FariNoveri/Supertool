-- =====================================================
-- MinimalHackGUI by Fari Noveri [Firebase Edition]
-- Firebase: user tracking, blacklist, owner highlight
-- =====================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

-- =====================================================
-- FIRESTORE CONFIG
-- =====================================================
local FIRESTORE_PROJECT = "supertool-18bae"
local FIREBASE_API_KEY = "AIzaSyAICeLezq9zrxKzIH2iQMpQVLhzeaebxKg"
local FIRESTORE_BASE = "https://firestore.googleapis.com/v1/projects/" .. FIRESTORE_PROJECT .. "/databases/(default)/documents"
local OWNER_NAME = "FariNoveri_2"

-- =====================================================
-- FIRESTORE HELPER FUNCTIONS
-- =====================================================

-- Convert Lua value ke Firestore field value format
local function toFirestoreValue(val)
    local t = type(val)
    if t == "boolean" then
        return {booleanValue = val}
    elseif t == "number" then
        if val == math.floor(val) then
            return {integerValue = tostring(val)}
        else
            return {doubleValue = val}
        end
    elseif t == "string" then
        return {stringValue = val}
    end
    return {nullValue = "NULL_VALUE"}
end

-- Convert Lua table ke Firestore fields format
local function toFirestoreFields(data)
    local fields = {}
    for k, v in pairs(data) do
        fields[k] = toFirestoreValue(v)
    end
    return fields
end

-- Extract nilai dari Firestore document fields
local function fromFirestoreDoc(doc)
    if not doc or not doc.fields then return nil end
    local result = {}
    for k, v in pairs(doc.fields) do
        if v.booleanValue ~= nil then
            result[k] = v.booleanValue
        elseif v.integerValue ~= nil then
            result[k] = tonumber(v.integerValue)
        elseif v.doubleValue ~= nil then
            result[k] = v.doubleValue
        elseif v.stringValue ~= nil then
            result[k] = v.stringValue
        else
            result[k] = nil
        end
    end
    return result
end

-- GET document dari Firestore
local function firestoreGet(collection, docId)
    local url = FIRESTORE_BASE .. "/" .. collection .. "/" .. docId .. "?key=" .. FIREBASE_API_KEY
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)
    if not success or not response then
        warn("[Firestore GET failed]: " .. tostring(response))
        return nil
    end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, response)
    if not ok then warn("[Firestore GET decode failed]: " .. tostring(data)) return nil end
    if data and data.error then warn("[Firestore GET error]: " .. tostring(data.error.message)) return nil end
    return fromFirestoreDoc(data)
end

-- CREATE / OVERWRITE document di Firestore (PATCH = upsert)
local function firestoreSet(collection, docId, data)
    local url = FIRESTORE_BASE .. "/" .. collection .. "/" .. docId .. "?key=" .. FIREBASE_API_KEY
    local body = HttpService:JSONEncode({fields = toFirestoreFields(data)})
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = url,
            Method = "PATCH",
            Headers = {["Content-Type"] = "application/json"},
            Body = body
        })
    end)
    if not success then
        warn("[Firestore SET failed]: " .. tostring(response))
    elseif response and response.Body then
        local ok, parsed = pcall(HttpService.JSONDecode, HttpService, response.Body)
        if ok and parsed and parsed.error then
            warn("[Firestore SET error]: " .. tostring(parsed.error.message))
        else
            warn("[Firestore SET ok] " .. collection .. "/" .. docId)
        end
    end
    return success
end

-- UPDATE sebagian field saja (updateMask)
local function firestoreUpdate(collection, docId, data)
    local fieldPaths = {}
    for k, _ in pairs(data) do
        table.insert(fieldPaths, "updateMask.fieldPaths=" .. k)
    end
    local maskQuery = table.concat(fieldPaths, "&")
    local url = FIRESTORE_BASE .. "/" .. collection .. "/" .. docId .. "?" .. maskQuery .. "&key=" .. FIREBASE_API_KEY
    local body = HttpService:JSONEncode({fields = toFirestoreFields(data)})
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = url,
            Method = "PATCH",
            Headers = {["Content-Type"] = "application/json"},
            Body = body
        })
    end)
    if not success then
        warn("[Firestore UPDATE failed]: " .. tostring(response))
    elseif response and response.Body then
        local ok, parsed = pcall(HttpService.JSONDecode, HttpService, response.Body)
        if ok and parsed and parsed.error then
            warn("[Firestore UPDATE error]: " .. tostring(parsed.error.message))
        else
            warn("[Firestore UPDATE ok] " .. collection .. "/" .. docId)
        end
    end
    return success
end

-- =====================================================
-- BLACKLIST CHECK — jalankan PERTAMA sebelum GUI load
-- =====================================================

local isBlacklisted = false

task.spawn(function()
    local userData = firestoreGet("users", player.Name)

    -- Cek blacklist
    if userData and (userData.blacklisted == true or userData.blacklisted == "true") then
        isBlacklisted = true
        for _, gui in pairs(player.PlayerGui:GetChildren()) do
            if gui.Name == "MinimalHackGUI" then
                gui:Destroy()
            end
        end
        warn("[SuperTool] Akses ditolak untuk: " .. player.Name)
        return
    end

    -- Register / update user di Firestore
    if userData then
        -- User sudah ada, update last_online & map_id saja
        firestoreUpdate("users", player.Name, {
            last_online = os.time(),
            map_id = tostring(game.PlaceId)
        })
    else
        -- User baru, buat dokumen lengkap
        firestoreSet("users", player.Name, {
            username = player.Name,
            last_online = os.time(),
            map_id = tostring(game.PlaceId),
            blacklisted = false
        })
    end

    -- Update last_online setiap 60 detik
    task.spawn(function()
        while task.wait(60) do
            if not isBlacklisted then
                pcall(function()
                    firestoreUpdate("users", player.Name, {
                        last_online = os.time(),
                        map_id = tostring(game.PlaceId)
                    })
                end)
            end
        end
    end)
end)

-- Guard: kalau blacklist check butuh waktu, tunggu sebentar
-- GUI build akan tetap jalan, tapi kalau blacklist = true, GUI akan dihapus

-- =====================================================
-- RAINBOW OWNER HIGHLIGHT SYSTEM
-- Hanya aktif kalau local player = OWNER_NAME
-- =====================================================

if player.Name == OWNER_NAME then
    local activeHighlights = {}
    local rainbowConnections = {}
    local colorIndex = 0
    local colorAlpha = 0

    local RAINBOW = {
        Color3.fromRGB(255, 0, 0),
        Color3.fromRGB(255, 127, 0),
        Color3.fromRGB(255, 255, 0),
        Color3.fromRGB(0, 255, 0),
        Color3.fromRGB(0, 150, 255),
        Color3.fromRGB(100, 0, 255),
        Color3.fromRGB(220, 0, 220),
    }

    local function getRainbow()
        colorAlpha = colorAlpha + 0.015
        if colorAlpha >= 1 then
            colorAlpha = 0
            colorIndex = (colorIndex + 1) % #RAINBOW
        end
        local c1 = RAINBOW[colorIndex + 1]
        local c2 = RAINBOW[((colorIndex + 1) % #RAINBOW) + 1]
        return c1:Lerp(c2, colorAlpha)
    end

    local function addHighlight(targetPlayer)
        if not targetPlayer or activeHighlights[targetPlayer.Name] then return end
        local char = targetPlayer.Character
        if not char then return end

        -- SelectionBox = rainbow outline di seluruh karakter
        local selBox = Instance.new("SelectionBox")
        selBox.Name = "OwnerRainbow"
        selBox.Adornee = char
        selBox.LineThickness = 0.07
        selBox.SurfaceTransparency = 0.8
        selBox.SurfaceColor3 = Color3.fromRGB(255, 255, 255)
        selBox.Color3 = Color3.fromRGB(255, 0, 0)
        selBox.Parent = game:GetService("CoreGui")

        -- Billboard label di atas kepala
        local bb = Instance.new("BillboardGui")
        bb.Name = "OwnerTag_" .. targetPlayer.Name
        bb.Size = UDim2.new(0, 140, 0, 28)
        bb.StudsOffset = Vector3.new(0, 3.2, 0)
        bb.AlwaysOnTop = true
        bb.Adornee = char:FindFirstChild("Head") or char:FindFirstChildWhichIsA("BasePart")
        bb.Parent = game:GetService("CoreGui")

        local bg = Instance.new("Frame")
        bg.Parent = bb
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bg.BackgroundTransparency = 0.5
        bg.BorderSizePixel = 0
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)

        local lbl = Instance.new("TextLabel")
        lbl.Parent = bg
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextStrokeTransparency = 0.3
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.Text = "⚙ " .. targetPlayer.Name

        activeHighlights[targetPlayer.Name] = {
            box = selBox,
            bb = bb,
            label = lbl
        }

        -- Update adornee kalau respawn
        local conn = targetPlayer.CharacterAdded:Connect(function(newChar)
            task.wait(1)
            if activeHighlights[targetPlayer.Name] then
                activeHighlights[targetPlayer.Name].box.Adornee = newChar
                local h = newChar:FindFirstChild("Head")
                if h then activeHighlights[targetPlayer.Name].bb.Adornee = h end
            end
        end)
        rainbowConnections[targetPlayer.Name] = conn
    end

    local function removeHighlight(pName)
        if activeHighlights[pName] then
            pcall(function() activeHighlights[pName].box:Destroy() end)
            pcall(function() activeHighlights[pName].bb:Destroy() end)
            activeHighlights[pName] = nil
        end
        if rainbowConnections[pName] then
            pcall(function() rainbowConnections[pName]:Disconnect() end)
            rainbowConnections[pName] = nil
        end
    end

    local function checkAndHighlight(p)
        if p == player then return end
        task.spawn(function()
            local userData = firestoreGet("users", p.Name)
            if userData and type(userData) == "table" then
                local lastOn = userData.last_online or 0
                -- Aktif kalau last_online dalam 3 menit terakhir
                if os.time() - lastOn < 180 then
                    addHighlight(p)
                end
            end
        end)
    end

    -- Scan semua player yang sudah ada
    for _, p in ipairs(Players:GetPlayers()) do
        checkAndHighlight(p)
    end

    -- Player baru join
    Players.PlayerAdded:Connect(function(p)
        task.wait(8) -- tunggu dia load dan register ke Firebase
        checkAndHighlight(p)
    end)

    -- Player leave
    Players.PlayerRemoving:Connect(function(p)
        removeHighlight(p.Name)
    end)

    -- Rainbow animation
    RunService.Heartbeat:Connect(function()
        local col = getRainbow()
        for _, data in pairs(activeHighlights) do
            if data.box and data.box.Parent then
                data.box.Color3 = col
                data.box.SurfaceColor3 = col
            end
            if data.label and data.label.Parent then
                data.label.TextColor3 = col
            end
        end
    end)

    -- Re-scan setiap 45 detik (untuk player yang baru load script)
    task.spawn(function()
        while task.wait(45) do
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player and not activeHighlights[p.Name] then
                    checkAndHighlight(p)
                end
            end
        end
    end)
end

-- =====================================================
-- GUI SETUP — sama seperti sebelumnya
-- =====================================================

local character, humanoid, rootPart

local connections = {}
local buttonStates = {}
local selectedCategory = "Movement"
local categoryStates = {}
local activeFeature = nil
local exclusiveFeatures = {}

local settings = {
    GuiWidth = {value = 500, min = 300, max = 800, default = 500},
    GuiHeight = {value = 300, min = 200, max = 600, default = 300},
    GuiOpacity = {value = 1.0, min = 0.1, max = 1.0, default = 1.0}
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MinimalHackGUI"
ScreenGui.Parent = player:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Enabled = true

for _, gui in pairs(player.PlayerGui:GetChildren()) do
    if gui:IsA("ScreenGui") and gui.Name == "MinimalHackGUI" and gui ~= ScreenGui then
        gui:Destroy()
    end
end

local Frame = Instance.new("Frame")
Frame.Name = "MainFrame"
Frame.Parent = ScreenGui
Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Frame.BorderColor3 = Color3.fromRGB(45, 45, 45)
Frame.BorderSizePixel = 1
Frame.Position = UDim2.new(0.5, -250, 0.5, -150)
Frame.Size = UDim2.new(0, settings.GuiWidth.value, 0, settings.GuiHeight.value)
Frame.Active = true
Frame.Draggable = true

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Parent = Frame
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.BorderSizePixel = 0
Title.Size = UDim2.new(1, 0, 0, 25)
Title.Font = Enum.Font.Gotham
Title.Text = "MinimalHackGUI by Fari Noveri [Fixed Loader]"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 10

local MinimizedLogo = Instance.new("Frame")
MinimizedLogo.Name = "MinimizedLogo"
MinimizedLogo.Parent = ScreenGui
MinimizedLogo.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MinimizedLogo.BorderColor3 = Color3.fromRGB(45, 45, 45)
MinimizedLogo.Position = UDim2.new(0, 5, 0, 5)
MinimizedLogo.Size = UDim2.new(0, 30, 0, 30)
MinimizedLogo.Visible = false
MinimizedLogo.Active = true
MinimizedLogo.Draggable = true

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 12)
Corner.Parent = MinimizedLogo

local LogoText = Instance.new("TextLabel")
LogoText.Parent = MinimizedLogo
LogoText.BackgroundTransparency = 1
LogoText.Size = UDim2.new(1, 0, 1, 0)
LogoText.Font = Enum.Font.GothamBold
LogoText.Text = "H"
LogoText.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoText.TextSize = 12
LogoText.TextStrokeTransparency = 0.5
LogoText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

local LogoButton = Instance.new("TextButton")
LogoButton.Parent = MinimizedLogo
LogoButton.BackgroundTransparency = 1
LogoButton.Size = UDim2.new(1, 0, 1, 0)
LogoButton.Text = ""

local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Parent = Frame
MinimizeButton.BackgroundTransparency = 1
MinimizeButton.Position = UDim2.new(1, -20, 0, 5)
MinimizeButton.Size = UDim2.new(0, 20, 0, 20)
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "-"
MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextSize = 10

local function createSlideNotification()
    local NotificationFrame = Instance.new("Frame")
    NotificationFrame.Name = "SlideNotification"
    NotificationFrame.Parent = ScreenGui
    NotificationFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    NotificationFrame.BorderSizePixel = 0
    NotificationFrame.Size = UDim2.new(0, 200, 0, 70)
    NotificationFrame.Position = UDim2.new(1, 0, 1, -80)
    NotificationFrame.ZIndex = 1000
    NotificationFrame.Active = true
    
    local NotificationCorner = Instance.new("UICorner")
    NotificationCorner.CornerRadius = UDim.new(0, 8)
    NotificationCorner.Parent = NotificationFrame
    
    local Shadow = Instance.new("Frame")
    Shadow.Name = "Shadow"
    Shadow.Parent = ScreenGui
    Shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Shadow.BackgroundTransparency = 0.8
    Shadow.BorderSizePixel = 0
    Shadow.Size = UDim2.new(0, 204, 0, 74)
    Shadow.Position = UDim2.new(1, 2, 1, -78)
    Shadow.ZIndex = 999
    
    local ShadowCorner = Instance.new("UICorner")
    ShadowCorner.CornerRadius = UDim.new(0, 8)
    ShadowCorner.Parent = Shadow
    
    local LogoImage = Instance.new("ImageLabel")
    LogoImage.Name = "Logo"
    LogoImage.Parent = NotificationFrame
    LogoImage.BackgroundTransparency = 1
    LogoImage.Position = UDim2.new(0, 8, 0, 8)
    LogoImage.Size = UDim2.new(0, 35, 0, 35)
    LogoImage.Image = "https://cdn.rafled.com/anime-icons/images/cADJDgHDli9YzzGB5AhH0Aa2dR8Bfu8w.jpg"
    LogoImage.ScaleType = Enum.ScaleType.Fit
    
    local LogoCorner2 = Instance.new("UICorner")
    LogoCorner2.CornerRadius = UDim.new(0, 6)
    LogoCorner2.Parent = LogoImage
    
    local MainText = Instance.new("TextLabel")
    MainText.Parent = NotificationFrame
    MainText.BackgroundTransparency = 1
    MainText.Position = UDim2.new(0, 50, 0, 8)
    MainText.Size = UDim2.new(1, -58, 0, 20)
    MainText.Font = Enum.Font.GothamBold
    MainText.Text = "Made by fari noveri"
    MainText.TextColor3 = Color3.fromRGB(30, 30, 30)
    MainText.TextSize = 10
    MainText.TextXAlignment = Enum.TextXAlignment.Left
    MainText.TextYAlignment = Enum.TextYAlignment.Center
    
    local SubText = Instance.new("TextLabel")
    SubText.Parent = NotificationFrame
    SubText.BackgroundTransparency = 1
    SubText.Position = UDim2.new(0, 50, 0, 28)
    SubText.Size = UDim2.new(1, -58, 0, 15)
    SubText.Font = Enum.Font.Gotham
    SubText.Text = "SuperTool"
    SubText.TextColor3 = Color3.fromRGB(100, 100, 100)
    SubText.TextSize = 9
    SubText.TextXAlignment = Enum.TextXAlignment.Left
    SubText.TextYAlignment = Enum.TextYAlignment.Center
    
    local StatusText = Instance.new("TextLabel")
    StatusText.Parent = NotificationFrame
    StatusText.BackgroundTransparency = 1
    StatusText.Position = UDim2.new(0, 50, 0, 43)
    StatusText.Size = UDim2.new(1, -58, 0, 15)
    StatusText.Font = Enum.Font.Gotham
    StatusText.Text = "Successfully loaded!"
    StatusText.TextColor3 = Color3.fromRGB(0, 150, 0)
    StatusText.TextSize = 8
    StatusText.TextXAlignment = Enum.TextXAlignment.Left
    StatusText.TextYAlignment = Enum.TextYAlignment.Center
    
    local DismissButton = Instance.new("TextButton")
    DismissButton.Name = "DismissButton"
    DismissButton.Parent = NotificationFrame
    DismissButton.BackgroundTransparency = 1
    DismissButton.Size = UDim2.new(1, 0, 1, 0)
    DismissButton.Text = ""
    DismissButton.ZIndex = 1001
    
    local slideInTime = 0.4
    local stayTime = 4.5
    local slideOutTime = 0.3
    local slideInPosition = UDim2.new(1, -210, 1, -80)
    local slideOutPosition = UDim2.new(1, 0, 1, -80)
    local shadowSlideInPosition = UDim2.new(1, -208, 1, -78)
    local shadowSlideOutPosition = UDim2.new(1, 2, 1, -78)
    
    local slideInInfo = TweenInfo.new(slideInTime, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local slideOutInfo = TweenInfo.new(slideOutTime, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
    
    local slideInTween = TweenService:Create(NotificationFrame, slideInInfo, {Position = slideInPosition})
    local shadowSlideInTween = TweenService:Create(Shadow, slideInInfo, {Position = shadowSlideInPosition})
    
    local function slideOut()
        local slideOutTween = TweenService:Create(NotificationFrame, slideOutInfo, {Position = slideOutPosition})
        local shadowSlideOutTween = TweenService:Create(Shadow, slideOutInfo, {Position = shadowSlideOutPosition})
        slideOutTween:Play()
        shadowSlideOutTween:Play()
        slideOutTween.Completed:Connect(function()
            NotificationFrame:Destroy()
            Shadow:Destroy()
        end)
    end
    
    DismissButton.MouseButton1Click:Connect(slideOut)
    slideInTween:Play()
    shadowSlideInTween:Play()
    slideInTween.Completed:Connect(function()
        task.spawn(function()
            task.wait(stayTime)
            slideOut()
        end)
    end)
end

local CategoryContainer = Instance.new("ScrollingFrame")
CategoryContainer.Parent = Frame
CategoryContainer.BackgroundTransparency = 1
CategoryContainer.Position = UDim2.new(0, 5, 0, 30)
CategoryContainer.Size = UDim2.new(0, 80, 1, -35)
CategoryContainer.ScrollBarThickness = 4
CategoryContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
CategoryContainer.ScrollingDirection = Enum.ScrollingDirection.Y
CategoryContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
CategoryContainer.CanvasSize = UDim2.new(0, 0, 0, 0)

local CategoryLayout = Instance.new("UIListLayout")
CategoryLayout.Parent = CategoryContainer
CategoryLayout.Padding = UDim.new(0, 3)
CategoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
CategoryLayout.FillDirection = Enum.FillDirection.Vertical

CategoryLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    CategoryContainer.CanvasSize = UDim2.new(0, 0, 0, CategoryLayout.AbsoluteContentSize.Y + 10)
end)

local FeatureContainer = Instance.new("ScrollingFrame")
FeatureContainer.Parent = Frame
FeatureContainer.BackgroundTransparency = 1
FeatureContainer.Position = UDim2.new(0, 90, 0, 30)
FeatureContainer.Size = UDim2.new(1, -95, 1, -35)
FeatureContainer.ScrollBarThickness = 4
FeatureContainer.ScrollBarImageColor3 = Color3.fromRGB(60, 60, 60)
FeatureContainer.ScrollingDirection = Enum.ScrollingDirection.Y
FeatureContainer.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
FeatureContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
FeatureContainer.Visible = true

local FeatureLayout = Instance.new("UIListLayout")
FeatureLayout.Parent = FeatureContainer
FeatureLayout.Padding = UDim.new(0, 2)
FeatureLayout.SortOrder = Enum.SortOrder.LayoutOrder

FeatureLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    FeatureContainer.CanvasSize = UDim2.new(0, 0, 0, FeatureLayout.AbsoluteContentSize.Y + 10)
end)

local categories = {
    {name = "Movement", order = 1},
    {name = "Player", order = 2},
    {name = "Teleport", order = 3},
    {name = "Visual", order = 4},
    {name = "Utility", order = 5},
    {name = "AntiAdmin", order = 6},
    {name = "Settings", order = 7},
    {name = "Info", order = 8},
    {name = "Credit", order = 9}
}

local categoryFrames = {}
local isMinimized = false
local previousMouseBehavior

local modules = {}
local modulesLoaded = {}

local moduleURLs = {
    Movement = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Movement.lua",
    Player = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Player.lua",
    Teleport = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Teleport.lua",
    Visual = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Visual.lua",
    Utility = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Utility.lua",
    AntiAdmin = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/AntiAdmin.lua",
    Settings = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Settings.lua",
    Info = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Info.lua",
    Credit = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/Credit.lua"
}

local function loadModule(moduleName)
    if not moduleURLs[moduleName] then
        warn("No URL defined for module: " .. moduleName)
        return false
    end
    local success, result = pcall(function()
        local response = game:HttpGet(moduleURLs[moduleName])
        if not response or response == "" or response:find("404") then
            error("Failed to fetch module or got 404")
        end
        local moduleFunc, loadError = loadstring(response)
        if not moduleFunc then
            error("Failed to compile module: " .. tostring(loadError))
        end
        local moduleTable = moduleFunc()
        if not moduleTable then error("Module function returned nil") end
        if type(moduleTable) ~= "table" then
            error("Module must return a table, got: " .. type(moduleTable))
        end
        return moduleTable
    end)
    if success and result then
        modules[moduleName] = result
        modulesLoaded[moduleName] = true
        if selectedCategory == moduleName then
            task.wait(0.1)
            loadButtons()
        end
        return true
    else
        warn("Failed to load module " .. moduleName .. ": " .. tostring(result))
        return false
    end
end

for moduleName, _ in pairs(moduleURLs) do
    task.spawn(function()
        loadModule(moduleName)
    end)
end

local dependencies = {
    Players = Players,
    UserInputService = UserInputService,
    RunService = RunService,
    Workspace = Workspace,
    Lighting = Lighting,
    ScreenGui = ScreenGui,
    ScrollFrame = FeatureContainer,
    settings = settings,
    connections = connections,
    buttonStates = buttonStates,
    player = player
}

local function initializeModules()
    for moduleName, module in pairs(modules) do
        if module and type(module.init) == "function" then
            local success, errorMsg = pcall(function()
                dependencies.character = character
                dependencies.humanoid = humanoid
                dependencies.rootPart = rootPart
                dependencies.ScrollFrame = FeatureContainer
                module.init(dependencies)
            end)
            if not success then
                warn("Failed to initialize module " .. moduleName .. ": " .. tostring(errorMsg))
            end
        end
    end
end

local function isExclusiveFeature(featureName)
    local exclusives = {"Fly", "Noclip", "Freecam", "Speed Hack", "Jump Hack"}
    for _, exclusive in ipairs(exclusives) do
        if featureName:find(exclusive) then return true end
    end
    return false
end

local function disableActiveFeature()
    if activeFeature and activeFeature.disableCallback and type(activeFeature.disableCallback) == "function" then
        pcall(activeFeature.disableCallback, false)
        if categoryStates[activeFeature.category] then
            categoryStates[activeFeature.category][activeFeature.name] = false
        end
    end
    activeFeature = nil
end

local function createButton(name, callback, categoryName)
    local success, result = pcall(function()
        local button = Instance.new("TextButton")
        button.Name = name
        button.Parent = FeatureContainer
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        button.BorderSizePixel = 0
        button.Size = UDim2.new(1, -2, 0, 20)
        button.Font = Enum.Font.Gotham
        button.Text = name
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 8
        button.LayoutOrder = #FeatureContainer:GetChildren()
        if type(callback) == "function" then
            button.MouseButton1Click:Connect(function()
                pcall(callback)
            end)
        end
        button.MouseEnter:Connect(function() button.BackgroundColor3 = Color3.fromRGB(80, 80, 80) end)
        button.MouseLeave:Connect(function() button.BackgroundColor3 = Color3.fromRGB(60, 60, 60) end)
        return button
    end)
    if not success then
        warn("Failed to create button " .. name .. ": " .. tostring(result))
        return nil
    end
    return result
end

local function createToggleButton(name, callback, categoryName, disableCallback)
    local success, result = pcall(function()
        local button = Instance.new("TextButton")
        button.Name = name
        button.Parent = FeatureContainer
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        button.BorderSizePixel = 0
        button.Size = UDim2.new(1, -2, 0, 20)
        button.Font = Enum.Font.Gotham
        button.Text = name
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 8
        button.LayoutOrder = #FeatureContainer:GetChildren()
        if not categoryStates[categoryName] then categoryStates[categoryName] = {} end
        if categoryStates[categoryName][name] == nil then categoryStates[categoryName][name] = false end
        button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
        button.MouseButton1Click:Connect(function()
            local newState = not categoryStates[categoryName][name]
            if newState and isExclusiveFeature(name) then
                disableActiveFeature()
                activeFeature = {name = name, category = categoryName, disableCallback = disableCallback}
            elseif not newState and activeFeature and activeFeature.name == name then
                activeFeature = nil
            end
            categoryStates[categoryName][name] = newState
            button.BackgroundColor3 = newState and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
            if type(callback) == "function" then
                pcall(callback, newState)
            end
        end)
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(80, 80, 80)
        end)
        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = categoryStates[categoryName][name] and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(60, 60, 60)
        end)
        return button
    end)
    if not success then
        warn("Failed to create toggle button " .. name .. ": " .. tostring(result))
        return nil
    end
    return result
end

local function getModuleFunctions(module)
    local functions = {}
    if type(module) == "table" then
        for key, value in pairs(module) do
            if type(value) == "function" then table.insert(functions, key) end
        end
    end
    return functions
end

function loadButtons()
    pcall(function()
        for _, child in pairs(FeatureContainer:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then
                child:Destroy()
            end
        end
    end)
    pcall(function()
        for categoryName, categoryData in pairs(categoryFrames) do
            if categoryData and categoryData.button then
                categoryData.button.BackgroundColor3 = categoryName == selectedCategory and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25)
            end
        end
    end)
    if not selectedCategory then return end
    if not modules[selectedCategory] then
        local loadingLabel = Instance.new("TextLabel")
        loadingLabel.Parent = FeatureContainer
        loadingLabel.BackgroundTransparency = 1
        loadingLabel.Size = UDim2.new(1, -2, 0, 20)
        loadingLabel.Font = Enum.Font.Gotham
        loadingLabel.Text = "Loading " .. selectedCategory .. " module..."
        loadingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        loadingLabel.TextSize = 8
        loadingLabel.TextXAlignment = Enum.TextXAlignment.Left
        if not modulesLoaded[selectedCategory] then
            task.spawn(function() loadModule(selectedCategory) end)
        end
        return
    end
    local module = modules[selectedCategory]
    local success, errorMessage = false, nil

    if selectedCategory == "Credit" and module.createCreditDisplay then
        success, errorMessage = pcall(function() module.createCreditDisplay(FeatureContainer) end)
    elseif selectedCategory == "Visual" and module.loadVisualButtons then
        success, errorMessage = pcall(function()
            if not module.isInitialized or not module.isInitialized() then
                error("Visual module is not properly initialized")
            end
            module.loadVisualButtons(function(name, callback, disableCallback)
                return createToggleButton(name, callback, "Visual", disableCallback)
            end)
        end)
    elseif selectedCategory == "Movement" and module.loadMovementButtons then
        success, errorMessage = pcall(function()
            module.loadMovementButtons(
                function(name, callback) return createButton(name, callback, "Movement") end,
                function(name, callback, disableCallback) return createToggleButton(name, callback, "Movement", disableCallback) end
            )
        end)
    elseif selectedCategory == "Player" and module.loadPlayerButtons then
        success, errorMessage = pcall(function()
            local selectedPlayer = module.getSelectedPlayer and module.getSelectedPlayer() or nil
            module.loadPlayerButtons(
                function(name, callback) return createButton(name, callback, "Player") end,
                function(name, callback, disableCallback) return createToggleButton(name, callback, "Player", disableCallback) end,
                selectedPlayer
            )
        end)
    elseif selectedCategory == "Teleport" and module.loadTeleportButtons then
        success, errorMessage = pcall(function()
            local selectedPlayer = modules.Player and modules.Player.getSelectedPlayer and modules.Player.getSelectedPlayer() or nil
            local freecamEnabled = modules.Visual and modules.Visual.getFreecamState and modules.Visual.getFreecamState() or false
            local freecamPosition = freecamEnabled and select(2, modules.Visual.getFreecamState()) or nil
            local toggleFreecam = modules.Visual and modules.Visual.toggleFreecam or function() end
            module.loadTeleportButtons(
                function(name, callback) return createButton(name, callback, "Teleport") end,
                selectedPlayer, freecamEnabled, freecamPosition, toggleFreecam
            )
        end)
    elseif selectedCategory == "Utility" and module.loadUtilityButtons then
        success, errorMessage = pcall(function()
            module.loadUtilityButtons(function(name, callback)
                return createButton(name, callback, "Utility")
            end)
        end)
    elseif selectedCategory == "AntiAdmin" and module.loadAntiAdminButtons then
        success, errorMessage = pcall(function()
            module.loadAntiAdminButtons(function(name, callback, disableCallback)
                return createToggleButton(name, callback, "AntiAdmin", disableCallback)
            end, FeatureContainer)
        end)
    elseif selectedCategory == "Settings" and module.loadSettingsButtons then
        success, errorMessage = pcall(function()
            module.loadSettingsButtons(function(name, callback)
                return createButton(name, callback, "Settings")
            end)
        end)
    elseif selectedCategory == "Info" and module.createInfoDisplay then
        success, errorMessage = pcall(function() module.createInfoDisplay(FeatureContainer) end)
    else
        local fallbackLabel = Instance.new("TextLabel")
        fallbackLabel.Parent = FeatureContainer
        fallbackLabel.BackgroundTransparency = 1
        fallbackLabel.Size = UDim2.new(1, -2, 0, 40)
        fallbackLabel.Font = Enum.Font.Gotham
        fallbackLabel.Text = selectedCategory .. " module loaded but missing required function.\nFunctions: " .. table.concat(getModuleFunctions(module), ", ")
        fallbackLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        fallbackLabel.TextSize = 8
        fallbackLabel.TextXAlignment = Enum.TextXAlignment.Left
        fallbackLabel.TextYAlignment = Enum.TextYAlignment.Top
        fallbackLabel.TextWrapped = true
        return
    end

    if not success and errorMessage then
        local errorLabel = Instance.new("TextLabel")
        errorLabel.Parent = FeatureContainer
        errorLabel.BackgroundTransparency = 1
        errorLabel.Size = UDim2.new(1, -2, 0, 60)
        errorLabel.Font = Enum.Font.Gotham
        errorLabel.Text = "Error loading " .. selectedCategory .. ":\n" .. tostring(errorMessage)
        errorLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        errorLabel.TextSize = 8
        errorLabel.TextXAlignment = Enum.TextXAlignment.Left
        errorLabel.TextYAlignment = Enum.TextYAlignment.Top
        errorLabel.TextWrapped = true
    end
end

for _, category in ipairs(categories) do
    local categoryButton = Instance.new("TextButton")
    categoryButton.Name = category.name .. "Category"
    categoryButton.Parent = CategoryContainer
    categoryButton.BackgroundColor3 = selectedCategory == category.name and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(25, 25, 25)
    categoryButton.BorderColor3 = Color3.fromRGB(45, 45, 45)
    categoryButton.Size = UDim2.new(1, -5, 0, 25)
    categoryButton.LayoutOrder = category.order
    categoryButton.Font = Enum.Font.GothamBold
    categoryButton.Text = category.name
    categoryButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    categoryButton.TextSize = 8
    categoryButton.MouseButton1Click:Connect(function()
        selectedCategory = category.name
        loadButtons()
    end)
    categoryButton.MouseEnter:Connect(function()
        if selectedCategory ~= category.name then
            categoryButton.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        end
    end)
    categoryButton.MouseLeave:Connect(function()
        if selectedCategory ~= category.name then
            categoryButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        end
    end)
    categoryFrames[category.name] = {button = categoryButton}
    categoryStates[category.name] = {}
end

local function toggleMinimize()
    isMinimized = not isMinimized
    Frame.Visible = not isMinimized
    MinimizedLogo.Visible = isMinimized
    MinimizeButton.Text = isMinimized and "+" or "-"
    if isMinimized then
        if previousMouseBehavior then
            UserInputService.MouseBehavior = previousMouseBehavior
        end
    else
        previousMouseBehavior = UserInputService.MouseBehavior
        if previousMouseBehavior == Enum.MouseBehavior.LockCenter or previousMouseBehavior == Enum.MouseBehavior.LockCurrent then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
    end
end

local function resetStates()
    for key, connection in pairs(connections) do
        pcall(function()
            if connection and connection.Disconnect then connection:Disconnect() end
        end)
        connections[key] = nil
    end
    for moduleName, module in pairs(modules) do
        if module and type(module.resetStates) == "function" then
            pcall(function() module.resetStates() end)
        end
    end
    if selectedCategory then
        task.spawn(function()
            task.wait(0.5)
            loadButtons()
        end)
    end
end

local function onCharacterAdded(newCharacter)
    if not newCharacter then return end
    local success, result = pcall(function()
        character = newCharacter
        humanoid = character:WaitForChild("Humanoid", 30)
        rootPart = character:WaitForChild("HumanoidRootPart", 30)
        if not humanoid or not rootPart then error("Failed to find Humanoid or HumanoidRootPart") end
        dependencies.character = character
        dependencies.humanoid = humanoid
        dependencies.rootPart = rootPart
        dependencies.ScrollFrame = FeatureContainer
        for moduleName, module in pairs(modules) do
            if module and type(module.updateReferences) == "function" then
                pcall(function() module.updateReferences() end)
            end
        end
        initializeModules()
        if humanoid and humanoid.Died then
            connections.humanoidDied = humanoid.Died:Connect(function()
                pcall(resetStates)
            end)
        end
        if selectedCategory and modules[selectedCategory] then
            task.spawn(function()
                task.wait(1)
                loadButtons()
            end)
        end
    end)
    if not success then
        warn("Failed to set up character: " .. tostring(result))
        character = newCharacter
        dependencies.character = character
        dependencies.ScrollFrame = FeatureContainer
    end
end

if player.Character then onCharacterAdded(player.Character) end
connections.characterAdded = player.CharacterAdded:Connect(onCharacterAdded)

MinimizeButton.MouseButton1Click:Connect(function() pcall(toggleMinimize) end)
LogoButton.MouseButton1Click:Connect(function() pcall(toggleMinimize) end)

connections.toggleGui = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Home then
        pcall(toggleMinimize)
    end
end)

task.spawn(function()
    local timeout = 45
    local startTime = tick()
    while tick() - startTime < timeout do
        local loadedCount = 0
        local criticalModulesLoaded = 0
        local criticalModules = {"Movement", "Visual", "Player"}
        for moduleName, _ in pairs(moduleURLs) do
            if modulesLoaded[moduleName] then
                loadedCount = loadedCount + 1
                for _, critical in ipairs(criticalModules) do
                    if moduleName == critical then
                        criticalModulesLoaded = criticalModulesLoaded + 1
                        break
                    end
                end
            end
        end
        if criticalModulesLoaded >= 2 or loadedCount >= 4 then break end
        task.wait(1)
    end

    local loadedModules, failedModules = {}, {}
    for moduleName, _ in pairs(moduleURLs) do
        if modulesLoaded[moduleName] then
            table.insert(loadedModules, moduleName)
        else
            table.insert(failedModules, moduleName)
        end
    end

    if #loadedModules > 0 then initializeModules() end

    task.wait(0.5)
    local buttonLoadSuccess, buttonLoadError = pcall(loadButtons)
    if not buttonLoadSuccess then
        warn("Failed to load initial buttons: " .. tostring(buttonLoadError))
        local fallbackLabel = Instance.new("TextLabel")
        fallbackLabel.Parent = FeatureContainer
        fallbackLabel.BackgroundTransparency = 1
        fallbackLabel.Size = UDim2.new(1, -2, 0, 60)
        fallbackLabel.Font = Enum.Font.Gotham
        fallbackLabel.Text = "GUI Initialized but some modules failed to load.\nLoaded: " .. (#loadedModules > 0 and table.concat(loadedModules, ", ") or "None")
        fallbackLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        fallbackLabel.TextSize = 8
        fallbackLabel.TextXAlignment = Enum.TextXAlignment.Left
        fallbackLabel.TextYAlignment = Enum.TextYAlignment.Top
        fallbackLabel.TextWrapped = true
    end

    task.wait(1)
    pcall(function() createSlideNotification() end)

    if #failedModules > 0 then
        task.spawn(function()
            task.wait(5)
            for _, failedModule in ipairs(failedModules) do
                if not modulesLoaded[failedModule] then
                    task.spawn(function() loadModule(failedModule) end)
                end
                task.wait(2)
            end
        end)
    end
end)

RunService.Heartbeat:Connect(function()
    if ScreenGui and ScreenGui.Parent ~= player.PlayerGui then
        pcall(function() ScreenGui.Parent = player.PlayerGui end)
    end
end)

task.spawn(function()
    task.wait(10)
    if not ScreenGui or not ScreenGui.Parent then
        pcall(function()
            if ScreenGui then ScreenGui.Parent = player.PlayerGui end
        end)
    end
end)