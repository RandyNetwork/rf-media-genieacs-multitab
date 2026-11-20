#!/usr/bin/env bash
# RF MEDIA fresh-install candidate. Ubuntu 22.04 amd64 only.
# MongoDB 4.4.18 matches the original ALIJAYA full installer and RF MEDIA baseline.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG=/var/log/rfmedia-install.log
mkdir -p /var/log
exec > >(tee -a "$LOG") 2>&1
die(){ echo "[ERROR] $*" >&2; exit 1; }
info(){ echo "[INFO] $*"; }
ok(){ echo "[OK] $*"; }
[[ $EUID -eq 0 ]] || die "Run as root: sudo bash install.sh"
. /etc/os-release
[[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 22.04 ]] || die "Only Ubuntu 22.04 supported"
[[ "$(dpkg --print-architecture)" == amd64 ]] || die "Only amd64 supported"
for f in agent/agent.py agent/whatsapp-bot.mjs agent/waLidStore.mjs agent/package-lock.json public/app.js public/app.css genieacs-ui/app.js genieacs-ui/app.css hsgq.js mongodb-seed/ui.json mongodb-seed/cwmp.json mongodb-seed/virtualParameters.json; do
  [[ -s "$ROOT/$f" ]] || die "Missing payload: $f"
done
for svc in mongod genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui genieacs-agent genieacs-whatsapp; do
  systemctl list-unit-files "${svc}.service" --no-legend 2>/dev/null | grep -q "${svc}.service" && die "Existing service $svc found; refusing to overwrite"
done
[[ ! -s /var/lib/mongodb/WiredTiger ]] || die "MongoDB data exists; refusing to overwrite"
[[ ! -e /usr/lib/node_modules/genieacs && ! -e /opt/genieacs/genieacs.env && ! -e /opt/genieacs-agent ]] || die "Existing GenieACS installation found"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl wget gnupg python3 python3-venv python3-pip build-essential libssl1.1 || true
# Ubuntu 22.04 no longer ships libssl1.1; MongoDB 4.4 Ubuntu 20.04 binary needs it.
if ! ldconfig -p | grep -q 'libssl.so.1.1'; then
  wget -q https://security.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.24_amd64.deb -O /tmp/libssl1.1.deb || die "Could not obtain libssl1.1 dependency"
  dpkg -i /tmp/libssl1.1.deb || apt-get -f install -y
  rm -f /tmp/libssl1.1.deb
fi
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get update
apt-get install -y nodejs
[[ "$(node -p 'process.versions.node.split(".")[0]')" == 20 ]] || die "Node.js 20 required"

info "Installing MongoDB 4.4.18 binary (ALJAYA baseline)"
wget -q https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-ubuntu2004-4.4.18.tgz -O /tmp/mongodb.tgz
mkdir -p /tmp/mongodb-extract
tar -xzf /tmp/mongodb.tgz -C /tmp/mongodb-extract
install -m 0755 /tmp/mongodb-extract/mongodb-linux-x86_64-ubuntu2004-4.4.18/bin/mongod /usr/local/bin/mongod
install -m 0755 /tmp/mongodb-extract/mongodb-linux-x86_64-ubuntu2004-4.4.18/bin/mongo /usr/local/bin/mongo
rm -rf /tmp/mongodb.tgz /tmp/mongodb-extract
mongod --version | grep -q '4.4.18' || die "MongoDB binary version check failed"
getent group mongodb >/dev/null || groupadd --system mongodb
id mongodb >/dev/null 2>&1 || useradd --system --gid mongodb --no-create-home --shell /usr/sbin/nologin mongodb
install -d -o mongodb -g mongodb /var/lib/mongodb /var/log/mongodb /run/mongodb
cat >/etc/mongod.conf <<'EOF'
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 1
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
net:
  port: 27017
  bindIp: 127.0.0.1
processManagement:
  fork: false
security:
  authorization: enabled
EOF
cat >/etc/systemd/system/mongod.service <<'EOF'
[Unit]
Description=MongoDB 4.4.18 RF MEDIA
After=network-online.target
Wants=network-online.target
[Service]
User=mongodb
Group=mongodb
ExecStartPre=/usr/bin/install -d -o mongodb -g mongodb -m 0755 /run/mongodb /var/lib/mongodb /var/log/mongodb
ExecStart=/usr/local/bin/mongod --config /etc/mongod.conf
Restart=on-failure
RestartSec=5
LimitNOFILE=64000
[Install]
WantedBy=multi-user.target
EOF
# Initialize DB user before enabling authorization, using a temporary loopback-only instance.
sed -i '/^security:/,$d' /etc/mongod.conf
systemctl daemon-reload
systemctl enable --now mongod
for n in $(seq 1 30); do /usr/local/bin/mongo --quiet --eval 'db.adminCommand({ping:1}).ok' 127.0.0.1:27017/admin 2>/dev/null | grep -q 1 && break; sleep 1; done
DB_USER=rfmedia_genieacs
DB_PASS="$(openssl rand -hex 32)"
/usr/local/bin/mongo --quiet 127.0.0.1:27017/admin --eval "db.getSiblingDB('genieacs').createUser({user:'$DB_USER',pwd:'$DB_PASS',roles:[{role:'readWrite',db:'genieacs'},{role:'dbAdmin',db:'genieacs'}]})"
cat >>/etc/mongod.conf <<'EOF'
security:
  authorization: enabled
EOF
systemctl restart mongod
for n in $(seq 1 30); do /usr/local/bin/mongo --quiet --username "$DB_USER" --password "$DB_PASS" --authenticationDatabase genieacs 127.0.0.1:27017/genieacs --eval 'db.adminCommand({ping:1}).ok' 2>/dev/null | grep -q 1 && break; sleep 1; done
/usr/local/bin/mongo --quiet --username "$DB_USER" --password "$DB_PASS" --authenticationDatabase genieacs 127.0.0.1:27017/genieacs --eval 'db.adminCommand({ping:1}).ok' | grep -q 1 || die "MongoDB auth test failed"
ok "MongoDB 4.4.18 running with local auth"

getent group genieacs >/dev/null || groupadd --system genieacs
id genieacs >/dev/null 2>&1 || useradd --system --gid genieacs --home-dir /opt/genieacs --shell /usr/sbin/nologin genieacs
install -d -o genieacs -g genieacs /opt/genieacs/ext /var/log/genieacs
install -d -o root -g root /opt/genieacs-agent
npm install -g --unsafe-perm genieacs@1.2.13
JWT="$(openssl rand -hex 32)"
cat >/opt/genieacs/genieacs.env <<EOF
GENIEACS_MONGODB_CONNECTION_URL=mongodb://$DB_USER:$DB_PASS@127.0.0.1:27017/genieacs?authSource=genieacs
GENIEACS_UI_JWT_SECRET=$JWT
GENIEACS_CWMP_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-cwmp-access.log
GENIEACS_NBI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-nbi-access.log
GENIEACS_FS_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-fs-access.log
GENIEACS_UI_ACCESS_LOG_FILE=/var/log/genieacs/genieacs-ui-access.log
GENIEACS_EXT_DIR=/opt/genieacs/ext
AGENT_API_URL=http://127.0.0.1:7558
WA_HTTP_PORT=7559
WA_AUTH_FOLDER=/opt/genieacs-agent/auth_info_baileys
WA_LID_STORE=/opt/genieacs-agent/wa_lid_store.json
EOF
chmod 640 /opt/genieacs/genieacs.env
chown root:genieacs /opt/genieacs/genieacs.env
cp -a "$ROOT/agent/." /opt/genieacs-agent/
rm -rf /opt/genieacs-agent/__pycache__
cp -a "$ROOT/public" /opt/genieacs-agent/public
cp -a "$ROOT/genieacs-ui/." /usr/lib/node_modules/genieacs/public/
install -m 0644 "$ROOT/hsgq.js" /opt/genieacs/ext/hsgq.js
chown -R genieacs:genieacs /opt/genieacs /var/log/genieacs
python3 -m venv /opt/genieacs-agent/venv
/opt/genieacs-agent/venv/bin/pip install --disable-pip-version-check pymongo requests gTTS
(cd /opt/genieacs-agent && npm ci --omit=dev)

# Seed is insert-only: never replace an existing document or delete collections.
export RF_MONGO_URI="mongodb://$DB_USER:$DB_PASS@127.0.0.1:27017/genieacs?authSource=genieacs"
python3 - "$ROOT" <<'PY'
import json,sys,os
from pathlib import Path
from pymongo import MongoClient, InsertOne
root=Path(sys.argv[1]); db=MongoClient(os.environ['RF_MONGO_URI'],serverSelectionTimeoutMS=10000)['genieacs']
for fn,col in [('ui.json','config'),('cwmp.json','config'),('virtualParameters.json','virtualParameters')]:
    docs=json.loads((root/'mongodb-seed'/fn).read_text())
    ops=[InsertOne(d) for d in docs if '_id' in d and db[col].find_one({'_id':d['_id']}, {'_id':1}) is None]
    if ops: db[col].bulk_write(ops,ordered=False)
db.command('ping')
PY
unset RF_MONGO_URI
for svc in cwmp nbi fs ui; do
cat >"/etc/systemd/system/genieacs-$svc.service" <<EOF
[Unit]
Description=GenieACS $svc
After=network.target mongod.service
Wants=mongod.service
[Service]
User=genieacs
Group=genieacs
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStartPre=/usr/bin/install -d -m 0775 -o genieacs -g genieacs /var/log/genieacs /opt/genieacs/ext
ExecStart=/usr/bin/genieacs-$svc
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
done
cat >/etc/systemd/system/genieacs-agent.service <<'EOF'
[Unit]
Description=RF MEDIA GenieACS Agent
After=network.target mongod.service genieacs-nbi.service
[Service]
User=root
WorkingDirectory=/opt/genieacs-agent
EnvironmentFile=/opt/genieacs/genieacs.env
ExecStart=/opt/genieacs-agent/venv/bin/python /opt/genieacs-agent/agent.py
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF
cat >/etc/systemd/system/genieacs-whatsapp.service <<'EOF'
[Unit]
Description=RF MEDIA WhatsApp Bot
After=network.target mongod.service genieacs-agent.service
[Service]
User=root
WorkingDirectory=/opt/genieacs-agent
EnvironmentFile=/opt/genieacs/genieacs.env
Environment=NODE_ENV=production
ExecStart=/usr/bin/node --experimental-global-webcrypto /opt/genieacs-agent/whatsapp-bot.mjs
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui genieacs-agent genieacs-whatsapp
sleep 8
for svc in mongod genieacs-cwmp genieacs-nbi genieacs-fs genieacs-ui genieacs-agent genieacs-whatsapp; do systemctl is-active --quiet "$svc" || die "$svc failed; inspect $LOG"; done
ok "Service startup checks passed"
echo "Install complete. MongoDB 4.4.18. Check logs: $LOG"
echo "This is a fresh-install candidate; verify UI/build parity on a disposable VM before production."
