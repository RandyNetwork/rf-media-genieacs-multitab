#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
GENIEACS_DIR="/usr/lib/node_modules/genieacs"
PUBLIC_DIR="$GENIEACS_DIR/public"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="/var/backups/rf-media-genieacs-ui/$STAMP"

fail() { echo "[GAGAL] $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || fail "Jalankan sebagai root."
[[ -d "$PUBLIC_DIR" ]] || fail "Direktori GenieACS tidak ditemukan: $PUBLIC_DIR"
[[ -f /opt/genieacs/genieacs.env ]] || fail "Environment GenieACS tidak ditemukan."
[[ -f "$ROOT/scripts/merge_mongodb.py" ]] || fail "merge_mongodb.py tidak ditemukan."

for f in app.js app.css chunk-CDG7S4P5.js; do
  [[ -s "$ROOT/public/$f" ]] || fail "File UI tidak ditemukan: $ROOT/public/$f"
done

python3 -c 'import pymongo, bson' 2>/dev/null || fail "Modul Python pymongo/bson belum tersedia."
node --check "$ROOT/public/app.js" || fail "Validasi app.js gagal."

echo "Target GenieACS : $GENIEACS_DIR"
echo "Backup UI       : $BACKUP"
echo "Database        : merge upsert, tanpa penghapusan"
echo
read -r -p "Lanjutkan penerapan RF MEDIA? Ketik YA: " confirm
[[ "$confirm" == "YA" ]] || { echo "Dibatalkan."; exit 0; }

mkdir -p "$BACKUP"
chmod 700 "$BACKUP"

for f in app.js app.css chunk-CDG7S4P5.js; do
  if [[ -f "$PUBLIC_DIR/$f" ]]; then
    cp -a "$PUBLIC_DIR/$f" "$BACKUP/"
  fi
done

echo "[1/2] Menerapkan konfigurasi MongoDB..."
python3 "$ROOT/scripts/merge_mongodb.py" --apply

echo "[2/2] Memasang file UI RF MEDIA..."
for f in app.js app.css chunk-CDG7S4P5.js; do
  install -m 0644 "$ROOT/public/$f" "$PUBLIC_DIR/$f"
done

echo
echo "[OK] File UI dan konfigurasi RF MEDIA telah diterapkan."
echo "Backup UI: $BACKUP"
echo "Restart GenieACS UI secara manual setelah pemeriksaan."
