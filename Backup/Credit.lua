local CreditModule = {}

function CreditModule.init(deps)
    return true
end

function CreditModule.createCreditDisplay(container)
    for _, child in pairs(container:GetChildren()) do
        if child:IsA("TextLabel") or child:IsA("Frame") then
            child:Destroy()
        end
    end
    
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
    
end

function CreditModule.resetStates()
end

function CreditModule.updateReferences()
end

return CreditModule