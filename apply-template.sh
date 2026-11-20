#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
GENIEACS_DIR=""
for d in /usr/lib/node_modules/genieacs /usr/local/lib/node_modules/genieacs; do
  if [[ -d "$d/public" ]]; then GENIEACS_DIR="$d"; break; fi
done
[[ -n "$GENIEACS_DIR" ]] || { echo "[GAGAL] Direktori GenieACS tidak ditemukan."; exit 1; }
PUBLIC_DIR="$GENIEACS_DIR/public"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/var/backups/rf-media-genieacs-ui/$STAMP"

fail() { echo "[GAGAL] $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || fail "Jalankan sebagai root."
[[ -f /opt/genieacs/genieacs.env ]] || fail "Environment GenieACS tidak ditemukan."
[[ -f "$ROOT/scripts/merge_mongodb.py" ]] || fail "merge_mongodb.py tidak ditemukan."
[[ -s "$ROOT/public/app.js" ]] || fail "public/app.js tidak ditemukan."
[[ -s "$ROOT/public/app.css" ]] || fail "public/app.css tidak ditemukan."
python3 -c 'import pymongo, bson' 2>/dev/null || fail "Modul Python pymongo/bson belum tersedia."
node --check "$ROOT/public/app.js" || fail "Validasi app.js gagal."

echo "=============================================================="
echo " RF MEDIA - APPLY MULTI-TAB KE GENIEACS AKTIF"
echo "=============================================================="
echo "Target GenieACS : $GENIEACS_DIR"
echo "Backup UI       : $BACKUP"
echo "MongoDB         : merge upsert; tidak drop database/collection"
echo
read -r -p "Lanjutkan penerapan RF MEDIA? Ketik YA: " confirm
[[ "$confirm" == "YA" ]] || { echo "Dibatalkan."; exit 0; }

mkdir -p "$BACKUP"
chmod 700 "$BACKUP"

for f in app.js app.css chunk-CDG7S4P5.js donasi.html mywifi.html peta.html voice.html optical-rx.html qris.jpg; do
  if [[ -f "$PUBLIC_DIR/$f" ]]; then cp -a "$PUBLIC_DIR/$f" "$BACKUP/"; fi
done

echo "[1/2] Menerapkan konfigurasi MongoDB..."
python3 "$ROOT/scripts/merge_mongodb.py" --apply

echo "[2/2] Memasang file UI RF MEDIA..."
for f in app.js app.css chunk-CDG7S4P5.js donasi.html mywifi.html peta.html voice.html optical-rx.html qris.jpg; do
  if [[ -s "$ROOT/public/$f" ]]; then install -m 0644 "$ROOT/public/$f" "$PUBLIC_DIR/$f"; fi
done

echo
echo "[OK] File UI dan konfigurasi RF MEDIA telah diterapkan."
echo "Backup UI: $BACKUP"
echo "Restart GenieACS UI secara manual setelah pemeriksaan."
