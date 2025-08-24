--[[
┌──────────────────────────────────────────────────┐
│ Persiapan dan Kebutuhan                          │
├──────────────────────────────────────────────────┤
│ Modul ini mengambil bagian penting dari Roblox    │
│ seperti Players, RunService, Workspace, dan       │
│ Lighting untuk mengatur karakter, lingkungan, dan │
│ suara. Informasi seperti pemain, karakter, dan    │
│ bagian tubuh disimpan untuk memantau keadaan      │
│ pemain. Modul juga bisa menerima tambahan data    │
│ dari luar saat mulai. Data awal seperti posisi,   │
│ kesehatan, dan kecepatan disimpan untuk mengecek  │
│ perubahan yang tidak wajar akibat ulah admin.     │
└──────────────────────────────────────────────────┘
]]

--[[
┌──────────────────────────────────────────────────┐
│ Pengaturan Perlindungan                          │
├──────────────────────────────────────────────────┤
│ Modul menyimpan daftar pengaturan perlindungan    │
│ seperti mainProtection, massProtection,           │
│ stealthMode, antiDetection, memoryProtection, dan │
│ advancedBypass. Setiap perlindungan bisa          │
│ dihidupkan atau dimatikan satu per satu, sehingga │
│ pengguna bisa memilih perlindungan mana yang      │
│ ingin digunakan.                                 │
└──────────────────────────────────────────────────┘
]]

--[[
┌──────────────────────────────────────────────────┐
│ Penyamaran Aktivitas                             │
├──────────────────────────────────────────────────┤
│ Fungsi sessionRandomization membuat data palsu    │
│ seperti waktu masuk, jumlah klik, dan gerakan     │
│ kamera untuk membuat aktivitas pemain terlihat    │
│ normal. Data ini dibuat secara acak berdasarkan   │
│ waktu agar sulit terdeteksi oleh sistem anti-cheat│
│ atau admin.                                      │
└──────────────────────────────────────────────────┘
]]

--[[
┌──────────────────────────────────────────────────┐
│ Simpan dan Kembalikan Pengaturan Pencahayaan     │
├──────────────────────────────────────────────────┤
│ Fungsi saveLightingSettings menyimpan pengaturan  │
│ pencahayaan seperti kecerahan dan kabut untuk     │
│ mengecek apakah ada perubahan aneh oleh admin.    │
│ Fungsi restoreLightingSettings mengembalikan      │
│ pengaturan ke kondisi awal jika ada perubahan.    │
└──────────────────────────────────────────────────┘
]]

--[[
┌──────────────────────────────────────────────────┐
│ Sistem Anti-Pendeteksian                         │
├──────────────────────────────────────────────────┤
│ Fungsi initializeAntiDetection mengawasi upaya    │
│ admin untuk memindai skrip dengan mengubah cara   │
│ kerja GetDescendants. Jika pemindaian terlalu     │
│ sering (lebih dari 10 kali), modul mengembalikan  │
│ data kosong untuk mencegah skrip terdeteksi.      │
└──────────────────────────────────────────────────┘
]]

--[[
┌──────────────────────────────────────────────────┐
│ Perlindungan Memori                              │
├──────────────────────────────────────────────────┤
│ Fungsi setupMemoryProtection membuat data acak    │
│ secara rutin untuk mengelabui sistem anti-cheat   │
│ yang memeriksa memori. Modul menggunakan          │
│ collectgarbage("count") agar penggunaan memori    │
│ tetap aman dan tidak terdeteksi.                 │
└──────────────────────────────────────────────────┘
]]

--[[
┌──────────────────────────────────────────────────┐
│ Perlindungan Metatable Tingkat Lanjut            │
├──────────────────────────────────────────────────┤
│ Fungsi setupAdvancedMetatableProtection mengubah  │
│ metatable game untuk memblokir perintah admin     │
│ seperti Kick, Ban, atau perekaman. Modul juga     │
│ memblokir panggilan remote yang mencurigakan,     │
│ seperti yang mengandung kata "admin" atau "ban",  │
│ dengan memeriksa nama dan argumennya.             │
└──────────────────────────────────────────────────┘
]]

--[[
┌──────────────────────────────────────────────────┐
│ Deteksi dan Balik Efek Admin                    │
├──────────────────────────────────────────────────┤
│ Fungsi hasAntiAdmin dan findUnprotectedTarget     │
│ mencari pemain yang tidak dilindungi untuk        │
│ membalikkan efek admin seperti membunuh,         │
│ teleportasi, atau melempar. Fungsi reverseEffect  │
│ menerapkan efek serupa ke pemain lain, misalnya   │
│ mengubah posisi atau kesehatan, untuk mengelabui  │
│ admin.                                           │
└──────────────────────────────────────────────────┘
]]

--[[
┌──────────────────────────────────────────────────┐
│ Perlindungan Anti-Noclip dan Anti-Terbang        │
├──────────────────────────────────────────────────┤
│ Fungsi setupAntiNoclip memantau properti          │
│ CanCollide pada bagian karakter untuk mencegah    │
│ pemain menembus dinding. Fungsi setupAntiFly      │
│ memeriksa kecepatan vertikal untuk mendeteksi dan │
│ memblokir upaya terbang. Jika terdeteksi, efek    │
│ dibalikkan ke pemain lain.                       │
└──────────────────────────────────────────────────┘
]]

--[[
┌──────────────────────────────────────────────────┐
│ Perlindungan Utama                               │
├──────────────────────────────────────────────────┤
│ Fungsi handleAntiAdmin memantau perubahan         │
│ kesehatan dan posisi karakter untuk mendeteksi    │
│ upaya membunuh atau teleportasi massal. Jika      │
│ terdeteksi, modul mengembalikan nilai awal dan    │
│ membalikkan efek ke pemain lain untuk menjaga     │
│ keamanan pemain.                                 │
└──────────────────────────────────────────────────┘
]]

--[[
┌──────────────────────────────────────────────────┐
│ Deteksi Efek Massal                             │
├──────────────────────────────────────────────────┤
│ Fungsi detectMassEffects memantau jumlah objek    │
│ seperti Part atau suara di Workspace untuk        │
│ mendeteksi spam oleh admin. Jika jumlahnya       │
│ melebihi batas, modul menghapus objek berlebih    │
│ atau mematikan suara untuk menjaga permainan      │
│ tetap stabil.                                    │
└──────────────────────────────────────────────────┘
]]

--[[
┌──────────────────────────────────────────────────┐
│ Cara Bypass Tingkat Lanjut                       │
├──────────────────────────────────────────────────┤
│ Fungsi setupAdvancedBypass membuat data memori    │
│ acak dan simulasi data sementara untuk menyamarkan│
│ aktivitas dari sistem anti-cheat, tanpa           │
│ menggunakan DataStore atau HTTP agar lebih aman   │
│ dan sulit dilacak.                               │
└──────────────────────────────────────────────────┘
]]

--[[
┌──────────────────────────────────────────────────┐
│ Pengaturan Perlindungan                          │
├──────────────────────────────────────────────────┤
│ Fungsi toggleMainProtection, toggleMassProtection,│
│ toggleStealthMode, toggleMemoryProtection, dan    │
│ toggleAdvancedBypass digunakan untuk menghidupkan │
│ atau mematikan fitur perlindungan. Setiap fungsi  │
│ mengatur koneksi dan status terkait saat diubah.  │
└──────────────────────────────────────────────────┘
]]

--[[
┌──────────────────────────────────────────────────┐
│ Mengatur Ulang Status                           │
├──────────────────────────────────────────────────┤
│ Fungsi resetStates mematikan semua fitur          │
│ perlindungan, memutus koneksi, dan mengatur ulang │
│ penghitung deteksi untuk memulai sistem dari awal.│
└──────────────────────────────────────────────────┘
]]

--[[
┌──────────────────────────────────────────────────┐
│ Membuat Tombol Anti-Admin                        │
├──────────────────────────────────────────────────┤
│ Fungsi loadAntiAdminButtons membuat tombol pada   │
│ antarmuka untuk menghidupkan atau mematikan fitur │
│ seperti Main Protection dan Mass Protection.      │
│ Tanda permanen dihapus, informasi hanya muncul    │
│ saat kategori AntiAdmin dipilih agar antarmuka    │
│ lebih rapi.                                      │
└──────────────────────────────────────────────────┘
]]