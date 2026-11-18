#!/usr/bin/env python3
import argparse
import json
import os
import re
import shlex
import sys
from datetime import datetime
from pathlib import Path

from pymongo import MongoClient
from bson import BSON

ROOT = Path(__file__).resolve().parents[1]
ENV_FILE = Path("/opt/genieacs/genieacs.env")
DATA_DIR = ROOT / "genieacs" / "mongodb"
BACKUP_ROOT = Path("/var/backups/rf-media-genieacs")

FILES = {
    "config": "ui-config.json",
    "provisions": "provisions.json",
    "presets": "presets.json",
    "virtualParameters": "virtualParameters.json",
}

PLACEHOLDERS = {
    "__RF_MEDIA_ACS_USERNAME__": "RF_MEDIA_ACS_USERNAME",
    "__RF_MEDIA_ACS_PASSWORD__": "RF_MEDIA_ACS_PASSWORD",
    "__RF_MEDIA_CONNREQ_USERNAME__": "RF_MEDIA_CONNREQ_USERNAME",
    "__RF_MEDIA_CONNREQ_PASSWORD__": "RF_MEDIA_CONNREQ_PASSWORD",
}

def read_env_file(path):
    env = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        try:
            parts = shlex.split(value, comments=True)
            env[key] = parts[0] if parts else ""
        except ValueError:
            raise RuntimeError(f"Format environment tidak valid pada variabel {key}")
    return env

def replace_values(value, env):
    if isinstance(value, str):
        for marker, key in PLACEHOLDERS.items():
            if marker in value:
                replacement = env.get(key) or os.environ.get(key)
                if not replacement:
                    raise RuntimeError(
                        f"Konfigurasi kredensial {key} belum disiapkan. "
                        "Merge dibatalkan tanpa perubahan database."
                    )
                value = value.replace(marker, replacement)
        if re.search(r"__RF_MEDIA_[A-Z0-9_]+__", value):
            raise RuntimeError("Masih ada placeholder RF MEDIA yang belum diisi.")
        return value
    if isinstance(value, list):
        return [replace_values(item, env) for item in value]
    if isinstance(value, dict):
        return {key: replace_values(item, env) for key, item in value.items()}
    return value

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true",
                        help="Lakukan backup dan upsert ke MongoDB")
    args = parser.parse_args()

    if not ENV_FILE.is_file():
        raise RuntimeError("File environment GenieACS tidak ditemukan.")

    env = read_env_file(ENV_FILE)
    uri = env.get("GENIEACS_MONGODB_CONNECTION_URL") or os.environ.get(
        "GENIEACS_MONGODB_CONNECTION_URL"
    )
    if not uri:
        raise RuntimeError("Variabel koneksi MongoDB tidak ditemukan.")

    documents = {}
    for collection, filename in FILES.items():
        path = DATA_DIR / filename
        data = json.loads(path.read_text())
        if not isinstance(data, list):
            raise RuntimeError(f"{filename} harus berupa array JSON.")
        ids = set()
        for doc in data:
            if not isinstance(doc, dict) or "_id" not in doc:
                raise RuntimeError(f"Dokumen tanpa _id ditemukan di {filename}.")
            if doc["_id"] in ids:
                raise RuntimeError(f"_id duplikat ditemukan di {filename}.")
            ids.add(doc["_id"])
        documents[collection] = [replace_values(doc, env) for doc in data]

    client = MongoClient(uri, serverSelectionTimeoutMS=10000)
    client.admin.command("ping")
    db = client.get_default_database(default="genieacs")

    print("Database terhubung. Pemeriksaan dokumen:")
    for collection, docs in documents.items():
        ids = [doc["_id"] for doc in docs]
        existing = db[collection].count_documents({"_id": {"$in": ids}})
        print(f"- {collection}: {len(docs)} dokumen; {existing} akan diperbarui; "
              f"{len(docs) - existing} akan ditambahkan.")

    if not args.apply:
        print("\nMODE PEMERIKSAAN: tidak ada perubahan database.")
        client.close()
        return

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_dir = BACKUP_ROOT / stamp
    backup_dir.mkdir(parents=True, mode=0o700)
    os.chmod(BACKUP_ROOT, 0o700)
    os.chmod(backup_dir, 0o700)

    # Simpan dokumen lama yang tepat akan disentuh sebelum upsert.
    for collection, docs in documents.items():
        ids = [doc["_id"] for doc in docs]
        old_docs = db[collection].find({"_id": {"$in": ids}})
        backup_file = backup_dir / f"{collection}.bson"
        with backup_file.open("wb") as stream:
            for old in old_docs:
                stream.write(BSON.encode(old))
        os.chmod(backup_file, 0o600)

    print(f"Backup dokumen lama tersimpan di: {backup_dir}")

    for collection, docs in documents.items():
        for doc in docs:
            db[collection].replace_one({"_id": doc["_id"]}, doc, upsert=True)
        print(f"[OK] {collection}: {len(docs)} dokumen di-upsert.")

    client.close()
    print("[SELESAI] Tidak ada dokumen lain yang dihapus.")

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"[GAGAL] {exc}", file=sys.stderr)
        sys.exit(1)
