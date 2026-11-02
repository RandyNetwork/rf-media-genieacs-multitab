# RF MEDIA Modern Dashboard — Live NBI Bridge

Dashboard terpisah untuk GenieACS 1.2.x. Backend membaca NBI secara read-only dan tidak mengganti UI GenieACS aktif.

## Komponen
- `server.js`: Node.js backend + static server, default listen di 127.0.0.1:7568.
- `app.js`: browser client, refresh 30 detik.
- `index.html` / `style.css`: UI.
- API: `/api/health`, `/api/summary`, `/api/devices?q=&limit=100`.

## Keamanan
- NBI default `http://127.0.0.1:7557`.
- Projection hanya `_id,_lastInform,_deviceId`; tidak meminta parameter WAN, password PPPoE, atau Wi-Fi key.
- Backend default hanya bind ke loopback. Jangan ubah ke 0.0.0.0 atau membuka port 7557 ke LAN/Internet.
- Jika dipublikasikan melalui reverse proxy, aktifkan `RF_DASH_TOKEN` dan konfigurasi proxy untuk mengirim header `Authorization: Bearer <token>`. Gunakan HTTPS dan pembatasan akses.
- Status online adalah heuristik Last Inform (default 5 menit), bukan bukti link optik aktif. Sesuaikan `RF_ONLINE_MINUTES` dengan interval Inform perangkat.

## Uji aman di VM GenieACS

Sebelum instalasi, periksa perubahan repo lokal dan jangan menimpa folder atau file aktif:

```bash
git -C /root/genieacs-multitab-mod status --short
git -C /root/genieacs-multitab-mod pull --ff-only
ls -lah /root/genieacs-multitab-mod/rf-media-dashboard/
```

Jika folder sudah tersedia, jalankan backend manual terlebih dahulu:

```bash
cd /root/genieacs-multitab-mod/rf-media-dashboard
node --version
node server.js
```

Dari sesi terminal kedua pada VM yang sama:

```bash
curl -sS http://127.0.0.1:7568/api/health
curl -sS http://127.0.0.1:7568/api/summary
```

Buka dashboard dengan SSH tunnel dari komputer admin:
```bash
ssh -L 7568:127.0.0.1:7568 genieacs@IP_VM_GENIEACS
``
Lalu akses `http://127.0.0.1:7568` di browser komputer admin.

## Catatan
Dashboard saat ini menampilkan total, status berdasarkan Last Inform, distribusi manufacturer, dan tabel perangkat. Detail optical/WAN/WLAN belum diaktifkan karena memerlukan endpoint detail terpilih dan filter parameter yang aman. Provisioning/task queue juga belum dihitung.
