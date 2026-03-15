-- =====================================================
-- SuperTool Key System Loader by FariNoveri_2
-- Validasi key sebelum load main script
-- =====================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

local PROXY_URL = "https://script.google.com/macros/s/AKfycbwCAJScwQg_mvWwX0mUTc5sOQlblZDy-W9iO8T8ssE4eb-bTHIEbH5vrO_D6gKBK8Yz/exec"
local MAIN_SCRIPT_URL = "https://raw.githubusercontent.com/FariNoveri/Supertool/main/Backup/MainLoader.lua"

local FIREBASE_PROJECT = "supertool-18bae"
local API_KEY = "AIzaSyAICeLezq9zrxKzIH2iQMpQVLhzeaebxKg"
local FIRESTORE_BASE = "https://firestore.googleapis.com/v1/projects/" .. FIREBASE_PROJECT .. "/databases/(default)/documents"

-- =====================================================
-- CEK KEY VIA FIRESTORE LANGSUNG
-- =====================================================
local function validateKey(inputKey)
    local url = FIRESTORE_BASE .. "/keys?key=" .. API_KEY .. "&pageSize=200"
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)
    if not success or not response then return false, "Gagal koneksi ke server" end

    local ok, data = pcall(HttpService.JSONDecode, HttpService, response)
    if not ok or not data then return false, "Gagal decode response" end

    local docs = data.documents or {}
    for _, doc in pairs(docs) do
        local f = doc.fields or {}
        local keyVal = f.key and f.key.stringValue or ""
        local assignedTo = f.assigned_to and f.assigned_to.stringValue or ""
        local isActive = f.active and f.active.booleanValue
        local expiry = f.expiry and tonumber(f.expiry.integerValue) or 0
        local userLimit = f.user_limit and tonumber(f.user_limit.integerValue) or 0
        local usedCount = f.used_count and tonumber(f.used_count.integerValue) or 0

        if keyVal == inputKey then
            -- Cek assigned ke username ini
            if assignedTo ~= "" and assignedTo ~= player.Name then
                return false, "Key ini khusus untuk " .. assignedTo
            end
            -- Cek active
            if isActive == false then
                return false, "Key ini sudah dinonaktifkan"
            end
            -- Cek expiry
            if expiry ~= 0 and os.time() > expiry then
                return false, "Key sudah expired"
            end
            -- Cek user limit
            if userLimit > 0 and usedCount >= userLimit then
                return false, "Key sudah mencapai batas " .. userLimit .. " user"
            end
            -- Valid! Update via GAS
            local docId = doc.name:match("([^/]+)$")
            pcall(function()
                game:HttpGet(PROXY_URL .. "?action=usekey&keyid=" .. docId .. "&username=" .. player.Name)
            end)
            return true, "OK"
        end
    end

    return false, "Key tidak valid atau tidak ditemukan"
end

-- =====================================================
-- CEK APAKAH PLAYER SUDAH PUNYA KEY VALID TERSIMPAN
-- =====================================================
local function checkSavedKey()
    -- Cek di Firestore: player sudah verified + cek key masih valid (tidak expired/disabled)
    local url = FIRESTORE_BASE .. "/users/" .. player.Name .. "?key=" .. API_KEY
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)
    if not success or not response then return false end

    local ok, data = pcall(HttpService.JSONDecode, HttpService, response)
    if not ok or not data or not data.fields then return false end

    local keyVerified = data.fields.key_verified
    if not keyVerified or keyVerified.booleanValue ~= true then return false end

    -- Ambil key yang dipakai player ini
    local savedKey = data.fields.verified_key and data.fields.verified_key.stringValue or ""
    if savedKey == "" then return false end

    -- Cek key masih valid di collection keys
    local keyUrl = FIRESTORE_BASE .. "/keys/" .. savedKey .. "?key=" .. API_KEY
    local ks, kr = pcall(function() return game:HttpGet(keyUrl) end)
    if not ks or not kr then return false end

    local ko, kd = pcall(HttpService.JSONDecode, HttpService, kr)
    if not ko or not kd or not kd.fields then return false end

    local kf = kd.fields
    -- Cek masih active
    if kf.active and kf.active.booleanValue == false then
        return false
    end
    -- Cek belum expired
    local expiry = kf.expiry and tonumber(kf.expiry.integerValue) or 0
    if expiry ~= 0 and os.time() > expiry then
        return false
    end

    return true
end

-- =====================================================
-- SAVE KEY VERIFIED KE FIRESTORE
-- =====================================================
local function saveKeyVerified(keyVal)
    pcall(function()
        game:HttpGet(PROXY_URL 
            .. "?action=setkeyverified&username=" .. player.Name
            .. "&keyval=" .. (keyVal or ""))
    end)
end

-- =====================================================
-- LOAD MAIN SCRIPT
-- =====================================================
local function loadMainScript()
    local success, result = pcall(function()
        local code = game:HttpGet(MAIN_SCRIPT_URL)
        local fn, err = loadstring(code)
        if not fn then error("Compile error: " .. tostring(err)) end
        fn()
    end)
    if not success then
        warn("[SuperTool] Gagal load main script: " .. tostring(result))
    end
end

-- =====================================================
-- BUILD KEY GUI
-- =====================================================

-- Cek dulu kalau player sudah verified sebelumnya
local alreadyVerified = checkSavedKey()
if alreadyVerified then
    -- Langsung load tanpa perlu input key lagi
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "SuperTool",
        Text = "Key terverifikasi. Loading...",
        Duration = 3,
        Icon = "https://www.roblox.com/headshot-thumbnail/image?userId=7740869755&width=150&height=150&format=png",
    })
    task.wait(0.5)
    loadMainScript()
    return
end

-- Belum verified — tampilkan GUI input key
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KeySystemGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = player:WaitForChild("PlayerGui")

-- Blur background
local blur = Instance.new("BlurEffect")
blur.Size = 20
blur.Parent = game:GetService("Lighting")

-- Overlay gelap
local overlay = Instance.new("Frame")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.4
overlay.BorderSizePixel = 0
overlay.ZIndex = 1
overlay.Parent = ScreenGui

-- Main container
local container = Instance.new("Frame")
container.Size = UDim2.new(0, 380, 0, 260)
container.Position = UDim2.new(0.5, -190, 0.5, -130)
container.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
container.BorderSizePixel = 0
container.ZIndex = 10
container.Parent = ScreenGui

Instance.new("UICorner", container).CornerRadius = UDim.new(0, 12)

-- Top accent bar
local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(1, 0, 0, 3)
accentBar.Position = UDim2.new(0, 0, 0, 0)
accentBar.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
accentBar.BorderSizePixel = 0
accentBar.ZIndex = 11
accentBar.Parent = container
Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 12)

-- Logo / Title
local logoFrame = Instance.new("Frame")
logoFrame.Size = UDim2.new(1, 0, 0, 80)
logoFrame.Position = UDim2.new(0, 0, 0, 20)
logoFrame.BackgroundTransparency = 1
logoFrame.ZIndex = 11
logoFrame.Parent = container

local logoIcon = Instance.new("TextLabel")
logoIcon.Size = UDim2.new(0, 50, 0, 50)
logoIcon.Position = UDim2.new(0.5, -25, 0, 0)
logoIcon.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
logoIcon.BorderSizePixel = 0
logoIcon.Font = Enum.Font.GothamBold
logoIcon.Text = "ST"
logoIcon.TextColor3 = Color3.fromRGB(0, 0, 0)
logoIcon.TextSize = 18
logoIcon.ZIndex = 12
logoIcon.Parent = logoFrame
Instance.new("UICorner", logoIcon).CornerRadius = UDim.new(0, 8)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 20)
titleLabel.Position = UDim2.new(0, 0, 0, 56)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "SuperTool Key System"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 14
titleLabel.ZIndex = 11
titleLabel.Parent = logoFrame

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(1, 0, 0, 16)
subLabel.Position = UDim2.new(0, 0, 0, 76)
subLabel.BackgroundTransparency = 1
subLabel.Font = Enum.Font.Gotham
subLabel.Text = "by FariNoveri_2  •  " .. player.Name
subLabel.TextColor3 = Color3.fromRGB(80, 80, 80)
subLabel.TextSize = 10
subLabel.ZIndex = 11
subLabel.Parent = logoFrame

-- Divider
local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -40, 0, 1)
divider.Position = UDim2.new(0, 20, 0, 108)
divider.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
divider.BorderSizePixel = 0
divider.ZIndex = 11
divider.Parent = container

-- Key input label
local inputLabel = Instance.new("TextLabel")
inputLabel.Size = UDim2.new(1, -40, 0, 16)
inputLabel.Position = UDim2.new(0, 20, 0, 120)
inputLabel.BackgroundTransparency = 1
inputLabel.Font = Enum.Font.GothamBold
inputLabel.Text = "MASUKKAN KEY"
inputLabel.TextColor3 = Color3.fromRGB(60, 60, 60)
inputLabel.TextSize = 9
inputLabel.TextXAlignment = Enum.TextXAlignment.Left
inputLabel.ZIndex = 11
inputLabel.Parent = container

-- Key input box
local inputBox = Instance.new("TextBox")
inputBox.Size = UDim2.new(1, -40, 0, 38)
inputBox.Position = UDim2.new(0, 20, 0, 140)
inputBox.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
inputBox.BorderSizePixel = 0
inputBox.Font = Enum.Font.GothamBold
inputBox.PlaceholderText = "ST-XXXX-XXXX-XXXX"
inputBox.PlaceholderColor3 = Color3.fromRGB(50, 50, 50)
inputBox.Text = ""
inputBox.TextColor3 = Color3.fromRGB(0, 255, 136)
inputBox.TextSize = 13
inputBox.ClearTextOnFocus = false
inputBox.ZIndex = 11
inputBox.Parent = container
Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 8)

-- Padding inside input
local inputPadding = Instance.new("UIPadding")
inputPadding.PaddingLeft = UDim.new(0, 12)
inputPadding.Parent = inputBox

-- Error / status label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -40, 0, 14)
statusLabel.Position = UDim2.new(0, 20, 0, 182)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = ""
statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
statusLabel.TextSize = 10
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.ZIndex = 11
statusLabel.Parent = container

-- Submit button
local submitBtn = Instance.new("TextButton")
submitBtn.Size = UDim2.new(1, -40, 0, 38)
submitBtn.Position = UDim2.new(0, 20, 0, 200)
submitBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
submitBtn.BorderSizePixel = 0
submitBtn.Font = Enum.Font.GothamBold
submitBtn.Text = "VERIFY KEY"
submitBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
submitBtn.TextSize = 12
submitBtn.ZIndex = 11
submitBtn.Parent = container
Instance.new("UICorner", submitBtn).CornerRadius = UDim.new(0, 8)

-- Animate container masuk
container.Position = UDim2.new(0.5, -190, 0.6, -130)
container.BackgroundTransparency = 1
TweenService:Create(container, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
    Position = UDim2.new(0.5, -190, 0.5, -130),
    BackgroundTransparency = 0
}):Play()

-- =====================================================
-- SUBMIT LOGIC
-- =====================================================
local isVerifying = false

local function doVerify()
    if isVerifying then return end
    local key = inputBox.Text:match("^%s*(.-)%s*$") -- trim
    if key == "" then
        statusLabel.Text = "⚠ Key tidak boleh kosong"
        statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        return
    end

    isVerifying = true
    submitBtn.Text = "MEMVERIFIKASI..."
    submitBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    submitBtn.TextColor3 = Color3.fromRGB(100, 100, 100)
    statusLabel.Text = "Menghubungi server..."
    statusLabel.TextColor3 = Color3.fromRGB(100, 100, 100)

    task.spawn(function()
        local valid, message = validateKey(key)

        if valid then
            -- Key valid!
            statusLabel.Text = "✓ Key valid! Loading SuperTool..."
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 136)
            submitBtn.Text = "✓ VERIFIED"
            submitBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
            submitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)

            -- Simpan verified ke Firestore (simpan juga key-nya untuk re-validasi)
            saveKeyVerified(inputBox.Text:match("^%s*(.-)%s*$"))

            task.wait(1)

            -- Slide out container
            TweenService:Create(container, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                Position = UDim2.new(0.5, -190, 0.4, -130),
                BackgroundTransparency = 1
            }):Play()

            task.wait(0.4)

            -- Hapus blur dan GUI
            blur:Destroy()
            ScreenGui:Destroy()

            -- Load main script
            loadMainScript()
        else
            -- Key invalid
            statusLabel.Text = "✗ " .. message
            statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
            submitBtn.Text = "VERIFY KEY"
            submitBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
            submitBtn.TextColor3 = Color3.fromRGB(0, 0, 0)

            -- Shake animasi
            local origPos = container.Position
            for i = 1, 4 do
                TweenService:Create(container, TweenInfo.new(0.05), {
                    Position = UDim2.new(0.5, -190 + (i % 2 == 0 and 8 or -8), 0.5, -130)
                }):Play()
                task.wait(0.06)
            end
            TweenService:Create(container, TweenInfo.new(0.1), {
                Position = origPos
            }):Play()

            isVerifying = false
        end
    end)
end

submitBtn.MouseButton1Click:Connect(doVerify)
inputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then doVerify() end
end)

-- Hover effect tombol
submitBtn.MouseEnter:Connect(function()
    if not isVerifying then
        TweenService:Create(submitBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(0, 220, 110)
        }):Play()
    end
end)
submitBtn.MouseLeave:Connect(function()
    if not isVerifying then
        TweenService:Create(submitBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(0, 255, 136)
        }):Play()
    end
end)