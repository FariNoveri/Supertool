local AntiAdminInfo = {}

function AntiAdminInfo.loadButtons(scrollFrame, utils)
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "AntiAdminInfo"
    infoLabel.Parent = scrollFrame
    infoLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    infoLabel.BorderSizePixel = 0
    infoLabel.Size = UDim2.new(1, 0, 0, 300)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Text = [[
ANTI ADMIN PROTECTION - ULTIMATE SHIELD

Sistem deteksi exploit instant yang nggak perlu nunggu lama. Begitu ada yang join langsung ketahuan kalo dia pake exploit atau admin. Deteksi nya cuma butuh 0.1 detik doang dari pas dia spawn.

FITUR DETEKSI OTOMATIS:
- Langsung scan environment exploit kayak Synapse X, KRNL, ScriptWare
- Deteksi behavior aneh tanpa nunggu dia terbang atau speed hack
- Notifikasi real-time di pojok kanan atas pas ada exploit/admin
- System confidence: YAKIN (90%+), KEMUNGKINAN (70%+), MUNGKIN (50%+)
- Deep memory scan setiap 10 detik buat mastiin

PERLINDUNGAN LENGKAP:
- Kill protection (mati dibalik ke penyerang)
- Teleport protection (nggak bisa dipindah paksa)
- Fling protection (nggak bisa dilempar)
- Freeze protection (nggak bisa dibekuin)
- Speed protection (kecepatan tetep normal)
- Tool protection (nggak bisa diambil/dikasih tool aneh)
- Camera protection (kamera nggak bisa dibajak)
- Noclip protection (nggak bisa tembus tembok)

SYSTEM HOT POTATO:
Kalo ada yang nyoba jahatin lu, efeknya dibalik ke dia. Kalo dia juga punya anti-admin, efeknya dilempar ke player lain sampe nemu yang nggak ada pelindung.

METODE DETEKSI:
- Scan environment executor
- Analisis script mencurigakan
- Deteksi tool berbahaya
- Analisis gerakan aneh
- Memory scanning mendalam
- Monitor network call
- Cek properti karakter abnormal

Selalu aktif 24/7, nggak bisa dimatiin. Auto-kick bisa diaktifin pake script.toggleAutoKick(true/false).

Created by Fari Noveri - Nggak ada yang bisa ganggu member Unknown Block!
]]
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoLabel.TextSize = 10
    infoLabel.TextWrapped = true
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.TextYAlignment = Enum.TextYAlignment.Top

    if utils.notify then
        utils.notify("Anti Admin Info loaded - By Fari Noveri")
    else
        print("Anti Admin Info loaded - By Fari Noveri")
    end
end

return AntiAdminInfo