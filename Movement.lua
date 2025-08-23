```
--[[
╔══════════════════════════════════════════════════════════════════════════════════════╗
║                                PENJELASAN FITUR BARU                                ║
╠══════════════════════════════════════════════════════════════════════════════════════╣
║                                                                                      ║
║  🌟 GHOST MODE:                                                                      ║
║     • Membuat karakter invisible untuk pemain lain                                  ║
║     • Noclip otomatis untuk menembus objek                                         ║
║     • Sesekali "teleport" kembali ke posisi asli untuk sinkronisasi network        ║
║                                                                                      ║
║  ⚡ FAKE LAG:                                                                        ║
║     • Mensimulasikan lag jaringan dengan melompat balik ke posisi lama             ║
║     • Menyimpan history posisi selama 2 detik                                      ║
║     • Membuat efek "lag" yang realistis untuk mengelabui pemain lain               ║
║                                                                                      ║
║  ⏪ REWIND MOVEMENT:                                                                 ║
║     • Menyimpan 300 posisi terakhir (10 detik pada 30 fps)                        ║
║     • Tombol mobile-friendly untuk rewind 2 detik ke belakang                     ║
║     • Visual feedback saat digunakan dengan perubahan transparansi tombol         ║
║                                                                                      ║
║  👥 MIRROR CLONE:                                                                    ║
║     • Membuat clone statis dari karakter di posisi saat ini                       ║
║     • Clone tidak memiliki script dan tidak dapat bergerak                        ║
║     • Berguna untuk membingungkan pemain lain atau sebagai decoy                  ║
║                                                                                      ║
║  🔄 REVERSE WALK:                                                                    ║
║     • Sesekali membalik rotasi visual karakter untuk pemain lain                  ║
║     • Menciptakan efek berjalan mundur yang membingungkan                         ║
║     • Tidak mempengaruhi gerakan sebenarnya, hanya visual                         ║
║                                                                                      ║
║  🧗 FAST LADDER:                                                                     ║
║     • Deteksi otomatis tangga (TrussPart atau part dengan nama "ladder")          ║
║     • Memberikan kecepatan naik 50 studs/detik saat bergerak di dekat tangga     ║
║     • Bekerja dengan berbagai jenis tangga dan struktur climbing                  ║
║                                                                                      ║
║  🏗️ STICKY PLATFORM:                                                                ║
║     • Deteksi platform bergerak secara otomatis                                   ║
║     • Membuat WeldConstraint sementara untuk "menempel" ke platform               ║
║     • Otomatis menghilang setelah 0.5 detik untuk mencegah stuck                 ║
║                                                                                      ║
║  🏠 UNDERGROUND:                                                                     ║
║     • Teleport 4 studs di bawah permukaan tanah                                   ║
║     • Noclip otomatis untuk bergerak di dalam tanah                               ║
║     • Raycast untuk mendeteksi level tanah dan menjaga kedalaman konsisten        ║
║     • Tombol off akan teleport kembali ke permukaan                               ║
║                                                                                      ║
║  🎈 FLOAT (Enhanced):                                                               ║
║     • Movement horizontal-only menggunakan virtual joystick                       ║
║     • Tidak ada kontrol vertikal (berbeda dengan Fly)                            ║
║     • Menggunakan camera-relative movement untuk kontrol intuitif                 ║
║     • PlatformStand untuk mencegah jatuh                                          ║
║                                                                                      ║
║  🛡️ PLAYER NOCLIP (Enhanced):                                                       ║
║     • Membuat pemain lain tidak solid (bisa tembus)                               ║
║     • Anti-fling protection dengan deteksi velocity abnormal                      ║
║     • Otomatis menghancurkan BodyMover berbahaya dari pemain lain                 ║
║     • Reset velocity jika melebihi batas maksimal (200 studs/detik)               ║
║                                                                                      ║
╠══════════════════════════════════════════════════════════════════════════════════════╣
║                              KONTROL MOBILE-FRIENDLY                                ║
╠══════════════════════════════════════════════════════════════════════════════════════╣
║                                                                                      ║
║  📱 VIRTUAL JOYSTICK:                                                               ║
║     • Joystick kiri bawah untuk fly/float movement                                ║
║     • Knob visual dengan radius maksimal 30 pixel                                 ║
║     • Touch handling yang responsive dengan multi-touch support                   ║
║                                                                                      ║
║  🎮 TOMBOL KONTROL:                                                                  ║
║     • Wall Climb: Tombol kanan bawah untuk climbing                               ║
║     • Rewind: Tombol merah dengan icon ⏪                                          ║
║     • Fly Up/Down: Tombol tambahan untuk kontrol vertikal (coming soon)          ║
║                                                                                      ║
╠══════════════════════════════════════════════════════════════════════════════════════╣
║                                FITUR KEAMANAN                                       ║
╠══════════════════════════════════════════════════════════════════════════════════════╣
║                                                                                      ║
║  🔒 ROBUST RESPAWN HANDLING:                                                        ║
║     • Auto-refresh referensi character, humanoid, dan rootPart                    ║
║     • Reapply fitur aktif setelah respawn dengan delay 0.2 detik                 ║
║     • Error handling untuk mencegah crash saat character belum loaded             ║
║                                                                                      ║
║  ⚙️ SETTINGS INTEGRATION:                                                           ║
║     • Menggunakan nilai dari settings module (WalkSpeed, JumpHeight, FlySpeed)    ║
║     • Fallback ke default value jika setting tidak tersedia                       ║
║     • Real-time update saat setting berubah                                       ║
║                                                                                      ║
║  🧹 ENHANCED CLEANUP:                                                               ║
║     • Disconnect semua connection saat disable/reset                              ║
║     • Destroy semua GUI element dan clone                                         ║
║     • Restore collision dan properti karakter ke default                         ║
║     • Clear history dan cache data                                                ║
║                                                                                      ║
╚══════════════════════════════════════════════════════════════════════════════════════╝

CATATAN TEKNIS:
- Semua fitur menggunakan RunService.Heartbeat untuk performa optimal
- Raycast dengan FilterDescendantsInstances untuk menghindari self-collision
- BodyVelocity dengan MaxForce yang disesuaikan untuk setiap fitur
- Task.spawn() untuk operasi async dan mencegah yield di main thread
- Debris service untuk auto-cleanup temporary objects
- Error handling dengan pcall() untuk operasi yang mungkin gagal

KOMPATIBILITAS:
- Mendukung baik JumpPower (R6) maupun JumpHeight (R15)
- Cross-platform: PC, Mobile, dan Tablet
- Auto-detect berbagai jenis platform dan tangga
- Bekerja dengan semua jenis Humanoid states

PERFORMA:
- Minimal impact pada FPS dengan efficient connections
- Smart reference caching untuk mengurangi FindFirstChild calls
- Optimized raycast dengan parameter yang tepat
- Automatic cleanup untuk mencegah memory leak
]]
```