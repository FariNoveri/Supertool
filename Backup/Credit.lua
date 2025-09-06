-- Credit.lua - Credit module for MinimalHackGUI by Fari Noveri

local CreditModule = {}

function CreditModule.init(deps)
    print("Credit module initialized")
    return true
end

function CreditModule.createCreditDisplay(container)
    -- Clear existing content
    for _, child in pairs(container:GetChildren()) do
        if child:IsA("TextLabel") or child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    -- Main credit text with ASCII box
    local creditText = Instance.new("TextLabel")
    creditText.Name = "CreditText"
    creditText.Parent = container
    creditText.BackgroundTransparency = 1
    creditText.Size = UDim2.new(1, -10, 0, 250)
    creditText.Position = UDim2.new(0, 5, 0, 10)
    creditText.Font = Enum.Font.Code
    creditText.Text = [[
╔══════════════════════════════════════════════════╗
║                 MINIMALHACKGUI                   ║
║                  by Fari Noveri                  ║
╠══════════════════════════════════════════════════╣
║                                                  ║
║  Script ini dibuat oleh Fari Noveri, solo dev   ║
║  tanpa bantuan orang lain. Belum ada bypass,    ║
║  maklumin kalau ada bug.                         ║
║                                                  ║
║  Contact:                                        ║
║  • Instagram: @fariinoveri                       ║
║  • TikTok: @fari_noveri                          ║
║                                                  ║
║  Script masih dalam pengembangan, bersabar ya    ║
║  kalau ada bug atau kekurangan. Feedback dan     ║
║  laporan bug sangat diterima melalui kontak      ║
║  yang tersedia diatas.                           ║
║                                                  ║
╚══════════════════════════════════════════════════╝
]]
    creditText.TextColor3 = Color3.fromRGB(0, 255, 0)
    creditText.TextSize = 8
    creditText.TextXAlignment = Enum.TextXAlignment.Left
    creditText.TextYAlignment = Enum.TextYAlignment.Top
    creditText.TextWrapped = false
    
    print("Credit display created successfully")
end

function CreditModule.resetStates()
    -- Nothing to reset for credit module
end

function CreditModule.updateReferences()
    -- Nothing to update for credit module
end

return CreditModule