# RF MEDIA GenieACS Multi-Tab — production snapshot branch

This branch stages the RF MEDIA production snapshot for review. It is **not merged to main**.

## Baseline
- Ubuntu 22.04.5 amd64
- Node.js 20 LTS
- MongoDB 4.4.18 (same version selected by the full ALIJAYA NET installer)
- GenieACS npm line 1.2.13; exact production build parity still requires validation

## Install candidate
On a disposable, clean Ubuntu 22.04 amd64 VM only:

```bash
git clone -b rfmedia-production-snapshot-2026-11-20 https://github.com/RandyNetwork/rf-media-genieacs-multitab.git
cd rf-media-genieacs-multitab
sudo bash install.sh
```

The installer refuses to run if GenieACS/MongoDB services or data already exist. It creates a unique database password and JWT secret, binds MongoDB to localhost, and imports seed documents insert-only. It does not import live customer data or activate the ZTE F672Y ACL bootstrap preset.

**Important:** this is an installation candidate, not yet a production-approved one-click release. The MongoDB 4.4.18 binary depends on the Ubuntu 20.04 build and libssl1.1 compatibility on Ubuntu 22.04; test this on a disposable VM. The exact GenieACS build hash and full feature parity with the live RF MEDIA server remain acceptance gates. Never run this on the existing production server.
