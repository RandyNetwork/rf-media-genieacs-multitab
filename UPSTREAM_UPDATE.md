# Kebijakan Update Upstream — RF MEDIA

## Tujuan

Repository ini adalah fork yang dipelihara oleh RF MEDIA. Repository upstream ALIJAYA NET tetap menjadi sumber kode asli dan referensi pembaruan fitur. Upstream tidak boleh menjadi sumber instalasi langsung untuk pengguna RF MEDIA.

- Repository resmi RF MEDIA: https://github.com/RandyNetwork/rf-media-genieacs-multitab
- Repository upstream: https://github.com/alijayanet/genieacs-multitab-mod
- Branch rilis: `main`
- Kontak RF MEDIA: 082210383000

## Aturan wajib

1. Instalasi baru dan pembaruan pengguna hanya mengambil kode dari repository RF MEDIA.
2. Jangan mengubah remote `origin` instalasi RF MEDIA ke repository upstream.
3. Jangan menjalankan `git pull` upstream langsung pada branch `main` atau server produksi.
4. Pembaruan upstream dilakukan pada branch staging terpisah, kemudian ditinjau dan dipindahkan secara selektif.
5. Pertahankan identitas RF MEDIA, logo, tautan dukungan, nomor 082210383000, konfigurasi branding, serta penghapusan halaman donasi AliJaya.
6. Pertahankan atribusi dan lisensi pengembang upstream sesuai ketentuan lisensi. Jangan mengklaim kode upstream sebagai karya asli RF MEDIA.
7. Jangan pernah memasukkan database pelanggan, kredensial, token, konfigurasi rahasia, atau backup produksi ke repository.

## Prosedur setiap ada update upstream

1. Catat commit upstream yang menjadi dasar pembaruan.
2. Buat branch baru dari branch RF MEDIA yang terakhir stabil, misalnya `upstream-sync/YYYY-MM-DD`.
3. Ambil perubahan upstream ke staging saja. Jangan force-push atau menimpa branch `main`.
4. Bandingkan perubahan file satu per satu. Pilih hanya perbaikan fitur dan keamanan yang dibutuhkan.
5. Terapkan ulang lapisan branding RF MEDIA dari `branding/config.json` dan aset di folder `branding/`.
6. Pastikan menu/route/halaman donasi AliJaya tidak muncul kembali.
7. Audit string ALIJAYA: atribusi upstream boleh ada; identitas produk, menu, kontak, logo, dan default operasional harus tetap RF MEDIA.
8. Jalankan pemeriksaan sintaks untuk JavaScript/Python/shell yang berubah, lalu uji di lingkungan staging dengan satu perangkat uji.
9. Buat Pull Request ke `main`, sertakan ringkasan perubahan, hasil tes, risiko, dan daftar file yang berubah.
10. Merge hanya setelah pemeriksaan dan persetujuan maintainer RF MEDIA. Setelah merge, rilis dan dokumentasikan nomor versi.

## Checklist sebelum merge

- [ ] Clone, installer, dan dokumentasi mengarah ke repository RF MEDIA.
- [ ] Tidak ada unduhan file UI atau script operasional langsung dari upstream.
- [ ] Logo, judul, footer, dan identitas UI tetap RF MEDIA.
- [ ] Kontak dukungan tetap 082210383000.
- [ ] Menu, route, halaman donasi, dan QRIS upstream tidak ikut masuk.
- [ ] Fungsi Multi-Tab, Summon, TR-069, WAN, WLAN, LAN, dan bot tetap diuji.
- [ ] Tidak ada kredensial, token, data pelanggan, atau backup produksi.
- [ ] Lisensi dan atribusi upstream tetap dipertahankan.

## Catatan penting

File arsip frontend seperti `genieacs_ui_mod.tar.gz` adalah artefak rilis. Arsip harus dibangun ulang dari sumber yang telah diaudit, kemudian diuji dan disimpan di repository RF MEDIA. Jangan menganggap arsip lama otomatis ikut berubah hanya karena file sumber JavaScript atau HTML diperbarui.

Perubahan upstream tidak boleh otomatis diterapkan ke server produksi. Selalu gunakan backup dan uji staging terlebih dahulu.
