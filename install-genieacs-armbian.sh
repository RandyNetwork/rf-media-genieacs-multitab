#!/usr/bin/env bash
set -Eeuo pipefail

# RF MEDIA installer entry point.
# Default mode applies the RF MEDIA template to an existing GenieACS server.
# A fresh install is intentionally not performed by this script.

ROOT="$(cd "$(dirname "$0")" && pwd)"
MODE="${1:-apply}"

case "$MODE" in
  apply)
    echo "=============================================================="
    echo " RF MEDIA - QUICK APPLY PADA GENIEACS YANG SUDAH RUNNING"
    echo "=============================================================="
    exec bash "$ROOT/apply-template.sh"
    ;;
  fresh)
    echo "[DITAHAN] Fresh install belum dijadikan jalur default."
    echo "Installer ini diprioritaskan untuk server GenieACS aktif."
    echo "Gunakan apply-template.sh agar data devices/users tetap aman."
    exit 2
    ;;
  *)
    echo "Penggunaan: bash install-genieacs-armbian.sh [apply|fresh]"
    echo "  apply : pasang Multi-Tab RF MEDIA ke GenieACS yang sudah berjalan (default)"
    echo "  fresh : belum tersedia pada entry point aman ini"
    exit 2
    ;;
esac
