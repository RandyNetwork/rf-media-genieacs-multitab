# RF MEDIA production baseline (verified)

This branch is a staging branch. It is not the production default branch and its installer is not approved for production use yet.

## Confirmed baseline
- OS: Ubuntu 22.04.5 LTS, amd64
- Node.js: 20.20.2
- GenieACS: 1.2.13+240606fc80
- MongoDB: 4.4.18
- Production MongoDB data must never be overwritten by an installer.

## ALIJAYA installer reference
The full ALIJAYA NET installer `install-genieacs-armbian.sh` downloads the MongoDB 4.4.18 Ubuntu 20.04 binary archive. This matches the reported RF MEDIA production MongoDB version. It does not justify using MongoDB 8.0 in a parity installer.

## Release gate
Do not label an installer one-click production-ready until all of the following pass on a disposable clean Ubuntu 22.04 amd64 VM:
1. MongoDB 4.4.18 starts and authenticates successfully with the generated local credentials.
2. GenieACS runtime build parity is confirmed, not merely the npm semver.
3. UI, agent, WhatsApp, extension, and systemd services pass health checks.
4. MongoDB seed import is non-destructive and has been reviewed for overwrite behavior.
5. No customer records, live credentials, tokens, session files, or Python bytecode are present in the release artifact.

## Safety
Never run the staging installer on the existing RF MEDIA production host. Keep production MongoDB and customer data untouched during build and validation.
