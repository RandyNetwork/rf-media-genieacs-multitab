#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
fail() { echo "[GAGAL] $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || fail "Jalankan sebagai root."
[[ -f /etc/os-release ]] || fail "OS tidak dikenali."
. /etc/os-release
[[ "$ID" == ubuntu ]] || fail "Installer ini ditujukan untuk Ubuntu."
[[ ! -d /usr/lib/node_modules/genieacs ]] || fail "GenieACS sudah terpasang. Gunakan apply-template.sh."
for s in genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui; do
  ! systemctl cat "$s" >/dev/null 2>&1 || fail "Service $s sudah ada."
done
command -v node >/dev/null || fail "Node.js belum terpasang."
command -v npm >/dev/null || fail "NPM belum terpasang."
command -v mongosh >/dev/null 2>&1 || command -v mongod >/dev/null || fail "MongoDB belum terpasang."
systemctl is-active --quiet mongod || fail "MongoDB belum aktif."
node -e 'const [major, minor] = process.versions.node.split(".").map(Number); if (major < 12 || (major === 12 && minor < 13)) process.exit(1)' || fail "Node.js minimal versi 12.13 diperlukan."

echo "Instalasi GenieACS 1.2.16 + RF MEDIA"
echo "Database MongoDB harus sudah aktif."
read -r -p "Ketik INSTALL untuk melanjutkan: " confirm
[[ "$confirm" == INSTALL ]] || { echo "Dibatalkan."; exit 0; }

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y python3-pymongo

id genieacs >/dev/null 2>&1 || useradd --system --no-create-home --user-group genieacs
mkdir -p /opt/genieacs/ext /var/log/genieacs
chown -R genieacs:genieacs /opt/genieacs /var/log/genieacs

npm install -g genieacs@1.2.16

JWT="$(node -e "process.stdout.write(require('crypto').randomBytes(128).toString('hex'))")"
ACS_USER="rfacs$(openssl rand -hex 4)"
ACS_PASS="$(openssl rand -hex 20)"
CR_USER="rfconn$(openssl rand -hex 4)"
CR_PASS="$(openssl rand -hex 20)"

cat > /opt/genieacs/genieacs.env <<EOF
GENIEACS_MONGODB_CONNECTION_URL=mongodb://127.0.0.1:27017/genieacs
GENIEACS_UI_JWT_SECRET=$JWT
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_DEBUG_FILE=/var/log/genieacs/genieacs-debug.yaml
GENIEACS_EXT_DIR=/opt/genieacs/ext
RF_MEDIA_ACS_USERNAME=$ACS_USER
RF_MEDIA_ACS_PASSWORD=$ACS_PASS
RF_MEDIA_CONNREQ_USERNAME=$CR_USER
RF_MEDIA_CONNREQ_PASSWORD=$CR_PASS
EOF
chown genieacs:genieacs /opt/genieacs/genieacs.env
chmod 600 /opt/genieacs/genieacs.env

for service in cwmp nbi fs ui; do
cat > "/etc/systemd/system/genieacs-$service.service" <<EOF
[Unit]
Description=GenieACS ${service^^}
After=network.target mongod.service
Wants=mongod.service

[Service]
User=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/usr/bin/genieacs-$service
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
done

systemctl daemon-reload
systemctl enable --now genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui

echo "[OK] GenieACS dasar terpasang."
echo "Sekarang menerapkan konfigurasi RF MEDIA..."
bash "$ROOT/apply-template.sh"

echo
echo "===== STATUS LAYANAN ====="
systemctl --no-pager --full status genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui || true
echo "[SELESAI] Instalasi dasar RF MEDIA selesai."
echo "Kredensial ACS dan Connection Request tersimpan di /opt/genieacs/genieacs.env."
