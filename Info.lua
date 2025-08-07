-- Info Category (Simplified Watermark)
local isIndonesian = true -- Default ke bahasa Indonesia

local function updateWatermarkText(watermarkLabel)
    watermarkLabel.Text = isIndonesian and [[
--[ PEMBERITAHUAN SEBELUM MENGGUNAKAN ]--

Dibuat oleh Fari Noveri untuk anggota Unknown Block.
Tidak untuk dijual, tidak untuk pamer, tidak untuk dirusak.

- Aturan Penggunaan:
- Jangan menjual skrip ini. Ini bukan untuk keuntungan.
- Pertahankan nama pembuat sebagai "by Fari Noveri".
- Jangan unggah ulang ke platform publik tanpa izin.
- Jangan gabungkan dengan skrip lain dan klaim sebagai milik Anda.
- Hanya dapatkan pembaruan dari sumber asli untuk menghindari kesalahan.

- Jika Anda menemukan skrip ini di luar grup:
Mungkin telah bocor. Harap jangan membagikannya lebih lanjut.

- Tujuan:
Skrip ini dibuat untuk membantu sesama anggota, bukan untuk keuntungan.
Harap gunakan dengan bertanggung jawab dan hormati tujuannya.

- Untuk saran, pertanyaan, atau umpan balik:
Kontak:
- Instagram: @fariinoveri
- TikTok: @fari_noveri

Terima kasih telah membaca. Gunakan dengan bijak.

- Fari Noveri
]] or [[
--[ NOTICE BEFORE USING ]--

Created by Fari Noveri for Unknown Block members.
Not for sale, not for showing off, not for tampering.

- Rules of Use:
- Do not sell this script. It's not for profit.
- Keep the creator's name as "by Fari Noveri".
- Do not re-upload to public platforms without permission.
- Do not combine with other scripts and claim as your own.
- Only get updates from the original source to avoid errors.

- If you find this script outside the group:
It may have been leaked. Please don't share it further.

- Purpose:
This script is made to help fellow members, not for profit.
Please use it responsibly and respect its purpose.

- For suggestions, questions, or feedback:
Contact:
- Instagram: @fariinoveri
- TikTok: @fari_noveri

Thank you for reading. Use it wisely.

- Fari Noveri
]]
end

local function loadInfoButtons()
    local watermarkLabel = Instance.new("TextLabel")
    watermarkLabel.Name = "WatermarkLabel"
    watermarkLabel.Parent = ScrollFrame
    watermarkLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    watermarkLabel.BorderSizePixel = 0
    watermarkLabel.Size = UDim2.new(1, 0, 0, 300)
    watermarkLabel.Font = Enum.Font.Gotham
    watermarkLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    watermarkLabel.TextSize = 10
    watermarkLabel.TextWrapped = true
    watermarkLabel.TextXAlignment = Enum.TextXAlignment.Left
    watermarkLabel.TextYAlignment = Enum.TextYAlignment.Top

    updateWatermarkText(watermarkLabel) -- Set teks awal

    -- Tombol untuk mengubah bahasa
    local languageButton = Instance.new("TextButton")
    languageButton.Name = "LanguageButton"
    languageButton.Parent = ScrollFrame
    languageButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    languageButton.BorderSizePixel = 0
    languageButton.Position = UDim2.new(0, 5, 0, 310)
    languageButton.Size = UDim2.new(1, -10, 0, 30)
    languageButton.Font = Enum.Font.Gotham
    languageButton.Text = isIndonesian and "Ubah ke Bahasa Inggris" or "Ubah ke Bahasa Indonesia"
    languageButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    languageButton.TextSize = 11

    languageButton.MouseButton1Click:Connect(function()
        isIndonesian = not isIndonesian
        languageButton.Text = isIndonesian and "Ubah ke Bahasa Inggris" or "Ubah ke Bahasa Indonesia"
        updateWatermarkText(watermarkLabel)
    end)

    languageButton.MouseEnter:Connect(function()
        languageButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end)

    languageButton.MouseLeave:Connect(function()
        languageButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end)
end