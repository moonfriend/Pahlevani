"""
Supabase snapshot tool — dumps all table data and storage files.

Downloads:
  - All rows from all known tables as JSON
  - All files from every storage bucket

Output: supabase/dump/  (gitignored)
  supabase/dump/tables/<table>.json
  supabase/dump/storage/<bucket>/<path>

Reads credentials from scripts/.streamlit/secrets.toml (service role key gives
full read access without RLS restrictions).

Run: python3 scripts/dump_supabase.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# ── credentials ───────────────────────────────────────────────────────────
REPO_ROOT = Path(__file__).parent.parent
SECRETS_FILE = REPO_ROOT / "scripts" / ".streamlit" / "secrets.toml"

if not SECRETS_FILE.exists():
    sys.exit(f"❌  {SECRETS_FILE} not found. Copy secrets.toml.example and fill it in.")

# Python 3.11+ ships tomllib; use it for correct inline-comment handling.
import tomllib
with open(SECRETS_FILE, "rb") as _f:
    _creds = tomllib.load(_f)

SUPABASE_URL = _creds.get("SUPABASE_URL", "")
SUPABASE_KEY = _creds.get("SUPABASE_KEY", "")  # service_role key

if not SUPABASE_URL or not SUPABASE_KEY:
    sys.exit("❌  SUPABASE_URL or SUPABASE_KEY missing from secrets.toml")

# ── setup ─────────────────────────────────────────────────────────────────
try:
    from supabase import create_client
except ImportError:
    sys.exit("❌  supabase-py not installed.  Run: pip3 install supabase")

OUT_DIR = REPO_ROOT / "supabase" / "dump"
TABLES_DIR = OUT_DIR / "tables"
STORAGE_DIR = OUT_DIR / "storage"
TABLES_DIR.mkdir(parents=True, exist_ok=True)
STORAGE_DIR.mkdir(parents=True, exist_ok=True)

client = create_client(SUPABASE_URL, SUPABASE_KEY)

TABLES = [
    "training_session",
    "exercise",
    "training_session_item",
    "movement",
    "app_release_gate",
]

# ── dump tables ───────────────────────────────────────────────────────────
print("── Table data ─────────────────────────────────────────────────")
for table in TABLES:
    try:
        rows = client.table(table).select("*").execute().data
        out = TABLES_DIR / f"{table}.json"
        out.write_text(json.dumps(rows, indent=2, default=str))
        print(f"  ✅  {table}: {len(rows)} rows → {out.relative_to(REPO_ROOT)}")
    except Exception as exc:
        print(f"  ⚠️   {table}: {exc}")

# ── dump storage ──────────────────────────────────────────────────────────
print("\n── Storage files ──────────────────────────────────────────────")

def _list_all(bucket: str, prefix: str = "") -> list[dict]:
    """Recursively list all files in a bucket/prefix."""
    entries = client.storage.from_(bucket).list(prefix or "")
    files = []
    for e in entries:
        name = e["name"]
        path = f"{prefix}/{name}" if prefix else name
        if e.get("id") is None:
            # It's a folder — recurse
            files.extend(_list_all(bucket, path))
        else:
            files.append({"path": path, "size": e.get("metadata", {}).get("size"), "id": e.get("id")})
    return files


def _download_file(bucket: str, path: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    data: bytes = client.storage.from_(bucket).download(path)
    dest.write_bytes(data)


try:
    buckets = client.storage.list_buckets()
except Exception as exc:
    print(f"  ❌  Could not list buckets: {exc}")
    buckets = []

for bucket in buckets:
    bname = bucket.name
    print(f"\n  Bucket: {bname}  (public={bucket.public})")
    try:
        files = _list_all(bname)
    except Exception as exc:
        print(f"    ❌  Could not list: {exc}")
        continue

    if not files:
        print("    (empty)")
        continue

    total_bytes = 0
    for f in files:
        dest = STORAGE_DIR / bname / f["path"]
        try:
            _download_file(bname, f["path"], dest)
            size = f["size"] or dest.stat().st_size
            total_bytes += size or 0
            mb = (size or 0) / 1_048_576
            print(f"    ✅  {f['path']}  ({mb:.1f} MB)")
        except Exception as exc:
            print(f"    ❌  {f['path']}: {exc}")

    print(f"  Total: {len(files)} files, {total_bytes/1_048_576:.1f} MB")

print(f"\n✅  Dump complete. Output: {OUT_DIR.relative_to(REPO_ROOT)}/")
print("   Note: exercise audio files are stored in the 'tracks'/'sirvan' buckets above.")
print("   Note: app_release_gate not yet in prod — apply migration 0002 first.")
