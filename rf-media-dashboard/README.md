# RF MEDIA Modern Dashboard — UI Preview

Ini adalah **prototipe visual terpisah**, bukan pengganti UI GenieACS aktif dan belum membaca data perangkat.

## Preview
Buka `index.html` melalui GitHub Pages atau unduh folder ini lalu buka di browser.

## Fitur visual
- Header RF MEDIA dan sidebar navigasi
- Kartu ringkasan Total / Online / Offline / Provisioning
- Grafik status perangkat 24 jam (ilustrasi)
- Distribusi vendor (ilustrasi)
- Tabel perangkat terbaru (placeholder)

## Penting sebelum produksi
Angka grafik dan statistik adalah data contoh, bukan data pelanggan. Integrasi produksi harus dilakukan melalui backend/proxy yang mengakses GenieACS NBI (port 7557) secara server-side. Jangan menaruh kredensial GenieACS atau API key di JavaScript browser. Implementasi berikutnya harus menghubungkan endpoint aman, menghitung status online/offline dari `lastInform`, dan memvalidasi respons API sebelum mengganti UI utama.

**Tidak mengubah** `genieacs_ui_mod.tar.gz`, provisioning, database, atau service GenieACS.
