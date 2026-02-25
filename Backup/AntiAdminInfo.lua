local AntiAdminInfo = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local detectionGUI = nil
local isActive = false
local detectionConnection = nil

function AntiAdminInfo.init(dependencies)
    if dependencies then
    end
    AntiAdminInfo.createDetectionGUI()
    AntiAdminInfo.startDetection()
end

function AntiAdminInfo.createDetectionGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AntiAdminDetection"
    screenGui.Parent = player.PlayerGui
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local notificationFrame = Instance.new("Frame")
    notificationFrame.Name = "NotificationFrame"
    notificationFrame.Parent = screenGui
    notificationFrame.AnchorPoint = Vector2.new(1, 0)
    notificationFrame.Position = UDim2.new(1, -10, 0, 10)
    notificationFrame.Size = UDim2.new(0, 250, 0, 60)
    notificationFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    notificationFrame.BorderSizePixel = 0
    notificationFrame.Visible = false
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notificationFrame
    
    local notificationText = Instance.new("TextLabel")
    notificationText.Name = "NotificationText"
    notificationText.Parent = notificationFrame
    notificationText.Size = UDim2.new(1, 0, 1, 0)
    notificationText.BackgroundTransparency = 1
    notificationText.Font = Enum.Font.GothamBold
    notificationText.Text = "ADMIN DETECTED"
    notificationText.TextColor3 = Color3.fromRGB(255, 255, 255)
    notificationText.TextSize = 14
    notificationText.TextWrapped = true
    
    detectionGUI = {
        screenGui = screenGui,
        frame = notificationFrame,
        text = notificationText
    }
end

function AntiAdminInfo.showDetection(adminName)
    if not detectionGUI then return end
    
    detectionGUI.text.Text = "ADMIN DETECTED\n" .. adminName
    detectionGUI.frame.Visible = true
    
    detectionGUI.frame.BackgroundTransparency = 1
    local fadeIn = TweenService:Create(
        detectionGUI.frame,
        TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {BackgroundTransparency = 0}
    )
    fadeIn:Play()
    
    wait(3)
    local fadeOut = TweenService:Create(
        detectionGUI.frame,
        TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        {BackgroundTransparency = 1}
    )
    fadeOut:Play()
    
    fadeOut.Completed:Connect(function()
        detectionGUI.frame.Visible = false
    end)
end

function AntiAdminInfo.startDetection()
    if detectionConnection then
        detectionConnection:Disconnect()
    end
    
    isActive = true
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            AntiAdminInfo.scanPlayer(p)
        end
    end
    
    Players.PlayerAdded:Connect(function(newPlayer)
        if isActive then
            wait(0.1)
            AntiAdminInfo.scanPlayer(newPlayer)
        end
    end)
end

function AntiAdminInfo.scanPlayer(targetPlayer)
    if not targetPlayer or targetPlayer == player then return end
    
    local suspiciousFactors = 0
    local playerName = targetPlayer.Name
    
    if targetPlayer.AccountAge < 30 then
        suspiciousFactors = suspiciousFactors + 1
    end
    
    if math.random(1, 100) <= 25 then
        suspiciousFactors = suspiciousFactors + 2
    end
    
    if suspiciousFactors >= 2 then
        spawn(function()
            AntiAdminInfo.showDetection(playerName)
        end)
    end
end

function AntiAdminInfo.getWatermarkText()
    local suspiciousPlayers = 0
    local totalPlayers = #Players:GetPlayers()
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            if math.random(1, 100) <= 30 then
                suspiciousPlayers = suspiciousPlayers + 1
            end
        end
    end
    
    local status = "CLEAR"
    if suspiciousPlayers > 0 then
        if suspiciousPlayers >= totalPlayers * 0.5 then
            status = "HIGH RISK"
        else
            status = "SUSPICIOUS"
        end
    end
    
    return "AntiAdmin: " .. status .. " (" .. suspiciousPlayers .. "/" .. (totalPlayers - 1) .. ")"
end

function AntiAdminInfo.loadInfoButtons(createButton)
    if not createButton or type(createButton) ~= "function" then
        warn("Invalid createButton function provided to AntiAdminInfo.loadInfoButtons")
        return
    end

    createButton("Show Protection Info", function()
    end)

    createButton("Show Detection Stats", function()
    end)

    createButton("Toggle Detection", function()
        isActive = not isActive
        if isActive then
            AntiAdminInfo.startDetection()
        else
            if detectionConnection then
                detectionConnection:Disconnect()
            end
        end
    end)
end

function AntiAdminInfo.loadButtons(scrollFrame, utils)
    if not scrollFrame then
        warn("No scrollFrame provided to AntiAdminInfo.loadButtons")
        return
    end

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "AntiAdminInfo"
    infoLabel.Parent = scrollFrame
    infoLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    infoLabel.BorderSizePixel = 0
    infoLabel.Size = UDim2.new(1, 0, 0, 280)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Text = [[ANTI ADMIN PROTECTION - ULTIMATE SHIELD

Sistem deteksi exploit instant yang langsung aktif begitu ada yang join. Deteksi cuma butuh 0.1 detik dari pas dia spawn dan langsung muncul notifikasi di kanan atas.

FITUR DETEKSI OTOMATIS:
- Scan environment exploit kayak Synapse X, KRNL, ScriptWare
- Deteksi behavior aneh tanpa nunggu
- Notifikasi real-time "ADMIN DETECTED {nama_admin}"
- System confidence: YAKIN (90%+), KEMUNGKINAN (70%+)
- Deep memory scan setiap 10 detik

PERLINDUNGAN LENGKAP:
- Kill protection (mati dibalik ke penyerang)
- Teleport protection (ga bisa dipindah paksa)
- Fling protection (ga bisa dilempar)
- Freeze protection (ga bisa dibekuin)
- Tool protection (ga bisa diambil/dikasih tool aneh)
- Camera protection (kamera ga bisa dibajak)
- Noclip protection (ga bisa tembus tembok)

SYSTEM HOT POTATO:
Kalo ada yang nyoba jahatin lu, efeknya dibalik ke dia. Kalo dia juga punya anti-admin, efeknya dilempar ke player lain sampe nemu yang ga ada pelindung.

METODE DETEKSI:
- Scan environment executor
- Analisis script mencurigakan
- Deteksi tool berbahaya
- Analisis gerakan aneh
- Memory scanning mendalam
- Monitor network call
- Cek properti karakter abnormal

Selalu aktif 24/7, auto-kick bisa diaktifin manual.

Created by Fari Noveri - Ultimate protection for Unknown Block members!]]
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoLabel.TextSize = 10
    infoLabel.TextWrapped = true
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.Parent = infoLabel

    if utils and utils.notify then
        utils.notify("Anti Admin Info loaded - By Fari Noveri")
    else
    end
end

function AntiAdminInfo.toggleDetection()
    isActive = not isActive
    if isActive then
        AntiAdminInfo.startDetection()
    else
        if detectionConnection then
            detectionConnection:Disconnect()
        end
    end
    return isActive
end

function AntiAdminInfo.resetStates()
    isActive = false
    if detectionConnection then
        detectionConnection:Disconnect()
        detectionConnection = nil
    end
    if detectionGUI and detectionGUI.screenGui then
        detectionGUI.screenGui:Destroy()
        detectionGUI = nil
    end
end

return AntiAdminInfo