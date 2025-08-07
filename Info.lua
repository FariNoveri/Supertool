local Info = {}

function Info.loadButtons(scrollFrame, utils)
    local watermarkLabel = Instance.new("TextLabel")
    watermarkLabel.Name = "WatermarkLabel"
    watermarkLabel.Parent = scrollFrame
    watermarkLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    watermarkLabel.BorderSizePixel = 0
    watermarkLabel.Size = UDim2.new(1, 0, 0, 300)
    watermarkLabel.Font = Enum.Font.Gotham
    watermarkLabel.Text = [[
--[ BACA DULU SEBELUM PAKE ]--

Dibuat oleh Fari Noveri khusus untuk member Unknown Block.
Jangan dijual, jangan buat pamer, jangan diedit sembarangan.

- Aturan Pakai:
- Jangan jual script ini. Bukan buat cari untung.
- Tetep tulis nama pembuat "by Fari Noveri".
- Jangan upload ulang ke platform lain tanpa izin.
- Jangan digabung sama script lain terus ngaku buatan sendiri.
- Ambil update cuma dari sumber asli biar nggak error.

- Kalo ketemu script ini di luar grup:
Kemungkinan udah bocor. Tolong jangan sebar lagi.

- Tujuan:
Script ini dibuat buat bantu sesama member, bukan buat bisnis.
Pake dengan bijak dan hormati tujuan awalnya.

- Buat saran, pertanyaan, atau feedback:
Kontak:
- Instagram: @fariinoveri
- TikTok: @fari_noveri

Makasih udah baca. Pake dengan bijak ya.

- Fari Noveri
]]
    watermarkLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    watermarkLabel.TextSize = 10
    watermarkLabel.TextWrapped = true
    watermarkLabel.TextXAlignment = Enum.TextXAlignment.Left
    watermarkLabel.TextYAlignment = Enum.TextYAlignment.Top

    if utils.notify then
        utils.notify("Info category loaded - By Fari Noveri")
    else
        print("Info category loaded - By Fari Noveri")
    end
end

return Info