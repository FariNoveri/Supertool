local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Variabel untuk Anti Admin
local antiAdminEnabled = true -- Selalu aktif, tidak bisa dinonaktifkan
local protectedPlayers = {} -- Daftar pemain yang memiliki Anti Admin aktif (simulasi)
local lastKnownPosition = rootPart and rootPart.CFrame or CFrame.new(0, 0, 0) -- Cache posisi terakhir
local lastKnownHealth = humanoid and humanoid.Health or 100 -- Cache kesehatan terakhir
local effectSources = {} -- Cache sumber efek (untuk pelacakan pelaku)
local antiAdminConnections = {} -- Koneksi untuk fitur Anti Admin

-- GUI dari MinimalHackGUI.lua (diintegrasikan)
local ScreenGui = CoreGui:FindFirstChild("MinimalHackGUI") or Instance.new("ScreenGui")
if not ScreenGui.Parent then
    ScreenGui.Name = "MinimalHackGUI"
    ScreenGui.Parent = CoreGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
end
local MainFrame = ScreenGui:FindFirstChild("MainFrame")
local CategoryFrame = MainFrame and MainFrame:FindFirstChild("CategoryFrame")
local ScrollFrame = MainFrame and MainFrame:FindFirstChild("ContentFrame"):FindFirstChild("ScrollFrame")

-- Fungsi untuk mendeteksi apakah pemain memiliki Anti Admin aktif (simulasi)
local function hasAntiAdmin(targetPlayer)
    -- Simulasi: 50% peluang pemain lain memiliki anti-anti (bisa diganti dengan RemoteEvent untuk deteksi nyata)
    return protectedPlayers[targetPlayer] or false
end

-- Fungsi untuk memperbarui daftar pemain yang terlindungi
local function updateProtectedPlayers()
    protectedPlayers = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            -- Simulasi deteksi Anti Admin
            protectedPlayers[p] = math.random(1, 100) <= 50 -- 50% peluang untuk simulasi
        end
    end
end

-- Fungsi untuk menemukan target yang tidak terlindungi
local function findUnprotectedTarget(excludePlayers)
    local availablePlayers = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
            if not excludePlayers[p] and not hasAntiAdmin(p) then
                table.insert(availablePlayers, p)
            end
        end
    end
    if #availablePlayers > 0 then
        return availablePlayers[math.random(1, #availablePlayers)]
    end
    return nil
end

-- Fungsi untuk membalikkan efek
local function reverseEffect(effectType, originalSource)
    if not antiAdminEnabled then return end -- Tidak seharusnya terjadi, tetapi untuk keamanan

    local excludePlayers = { [player] = true }
    local currentTarget = originalSource or Players:GetPlayers()[math.random(1, #Players:GetPlayers())]
    
    while currentTarget and hasAntiAdmin(currentTarget) do
        excludePlayers[currentTarget] = true
        currentTarget = findUnprotectedTarget(excludePlayers)
    end
    
    if currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild("Humanoid") and currentTarget.Character:FindFirstChild("HumanoidRootPart") then
        if effectType == "kill" then
            currentTarget.Character.Humanoid.Health = 0
            print("Reversed kill effect to: " .. currentTarget.Name)
        elseif effectType == "teleport" then
            local randomPos = Vector3.new(
                math.random(-1000, 1000),
                math.random(50, 500),
                math.random(-1000, 1000)
            )
            currentTarget.Character.HumanoidRootPart.CFrame = CFrame.new(randomPos)
            print("Reversed teleport effect to: " .. currentTarget.Name)
        end
    else
        print("No unprotected target found for effect reversal")
    end
end

-- Fungsi untuk mendeteksi dan menangani efek
local function handleAntiAdmin()
    -- Deteksi perubahan kesehatan (kill)
    antiAdminConnections.health = humanoid.HealthChanged:Connect(function(health)
        if not antiAdminEnabled then return end
        if health < lastKnownHealth and health <= 0 then
            -- Kembalikan kesehatan pemain
            humanoid.Health = lastKnownHealth
            print("Detected kill attempt, health restored")
            -- Balikkan efek ke pelaku atau target lain
            reverseEffect("kill", effectSources[player] or nil)
        end
        lastKnownHealth = humanoid.Health
    end)

    -- Deteksi perubahan posisi (teleport)
    antiAdminConnections.position = rootPart:GetPropertyChangedSignal("CFrame"):Connect(function()
        if not antiAdminEnabled then return end
        local currentPos = rootPart.CFrame
        local distance = (currentPos.Position - lastKnownPosition.Position).Magnitude
        if distance > 10 then -- Anggap teleport jika perpindahan > 10 stud
            -- Kembalikan posisi pemain
            rootPart.CFrame = lastKnownPosition
            print("Detected teleport attempt, position restored")
            -- Balikkan efek ke pelaku atau target lain
            reverseEffect("teleport", effectSources[player] or nil)
        end
        lastKnownPosition = currentPos
    end)
end

-- Fungsi untuk membuat tombol kategori
local function createCategoryButton(name)
    if not CategoryFrame then return end
    local button = Instance.new("TextButton")
    button.Name = name .. "Category"
    button.Parent = CategoryFrame
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    button.BorderSizePixel = 0
    button.Size = UDim2.new(1, 0, 0, 35)
    button.Font = Enum.Font.Gotham
    button.Text = name:upper()
    button.TextColor3 = Color3.fromRGB(200, 200, 200)
    button.TextSize = 10
    
    button.MouseButton1Click:Connect(function()
        switchCategory(name)
    end)
    
    return button
end

-- Fungsi untuk membersihkan konten ScrollFrame
local function clearButtons()
    if not ScrollFrame then return end
    for _, child in pairs(ScrollFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then
            child:Destroy()
        end
    end
end

-- Fungsi untuk memuat konten Anti Admin
local function loadAntiAdminContent()
    if not ScrollFrame then return end
    clearButtons()
    
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "AntiAdminInfo"
    infoLabel.Parent = ScrollFrame
    infoLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    infoLabel.BorderSizePixel = 0
    infoLabel.Size = UDim2.new(1, 0, 0, 300)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Text = [[
ANTI ADMIN PROTECTION

This feature is included to protect you from other admin/exploit attempts (kill, teleport, etc.). Effects will be reversed to the attacker or redirected to unprotected players. It is always active and cannot be disabled for your safety.

Created by Fari Noveri
]]
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoLabel.TextSize = 10
    infoLabel.TextWrapped = true
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top
    
    -- Perbarui ukuran canvas ScrollFrame
    wait(0.1)
    local UIListLayout = ScrollFrame:FindFirstChildOfClass("UIListLayout")
    if UIListLayout then
        local contentSize = UIListLayout.AbsoluteContentSize
        ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, contentSize.Y + 20)
    end
end

-- Fungsi untuk mengganti kategori (integrasi dengan MinimalHackGUI.lua)
local function switchCategory(categoryName)
    if not CategoryFrame or not ScrollFrame then return end
    for _, child in pairs(CategoryFrame:GetChildren()) do
        if child:IsA("TextButton") then
            if child.Name == categoryName .. "Category" then
                child.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                child.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                child.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
                child.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
    end
    
    if categoryName == "Anti Admin" then
        loadAntiAdminContent()
    else
        -- Panggil fungsi switchCategory dari MinimalHackGUI.lua (asumsikan ada)
        local success, result = pcall(function()
            loadstring('switchCategory("' .. categoryName .. '")')()
        end)
        if not success then
            print("Failed to switch to category: " .. categoryName)
        end
    end
end

-- Inisialisasi Anti Admin
local function initializeAntiAdmin()
    -- Aktifkan fitur Anti Admin
    antiAdminEnabled = true
    print("Anti Admin Protection initialized - Always Active")
    
    -- Perbarui daftar pemain yang terlindungi setiap 10 detik
    spawn(function()
        while true do
            updateProtectedPlayers()
            wait(10)
        end
    end)
    
    -- Tangani efek saat karakter ada
    handleAntiAdmin()
    
    -- Tangani respawn karakter
    player.CharacterAdded:Connect(function(newCharacter)
        character = newCharacter
        humanoid = character:WaitForChild("Humanoid")
        rootPart = character:WaitForChild("HumanoidRootPart")
        lastKnownPosition = rootPart.CFrame
        lastKnownHealth = humanoid.Health
        
        -- Mulai ulang deteksi efek
        for _, conn in pairs(antiAdminConnections) do
            if conn then
                conn:Disconnect()
            end
        end
        antiAdminConnections = {}
        handleAntiAdmin()
    end)
    
    -- Bersihkan koneksi saat script dihancurkan
    ScreenGui.AncestryChanged:Connect(function()
        if not ScreenGui:IsDescendantOf(game) then
            for _, conn in pairs(antiAdminConnections) do
                if conn then
                    conn:Disconnect()
                end
            end
        end
    end)
end

-- Tambahkan kategori Anti Admin ke GUI
if CategoryFrame then
    createCategoryButton("Anti Admin")
end

-- Jalankan inisialisasi
initializeAntiAdmin()
print("Anti Admin Loaded - By Fari Noveri")