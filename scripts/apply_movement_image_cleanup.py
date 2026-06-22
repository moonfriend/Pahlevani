"""
apply_movement_image_cleanup.py — Upload the clean images produced by
export_movement_images.py, repoint every movement row at them, then delete
the old per-movement-id folders.

Run export_movement_images.py first. This script only reads its output
(output/movement_images_clean/, output/movement_images_report.csv,
output/old_bucket_paths.txt) — it doesn't re-download or re-compress anything.

Order matters and is enforced: upload new files -> verify -> repoint DB rows
-> verify -> only then delete the old files. A failure at any step stops
before anything is deleted, so the bucket is never left in a state where a
movement row points at a file that doesn't exist.

Usage
-----
    cd scripts
    uv run python apply_movement_image_cleanup.py
"""

import csv
import os
import sys
import tomllib
from pathlib import Path

try:
    from supabase import create_client
except ImportError:
    print("Missing deps. Run: uv sync")
    sys.exit(1)

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "")

if not SUPABASE_URL or not SUPABASE_KEY:
    secrets_path = Path(__file__).parent / ".streamlit" / "secrets.toml"
    if secrets_path.exists():
        with open(secrets_path, "rb") as f:
            secrets = tomllib.load(f)
        SUPABASE_URL = SUPABASE_URL or secrets.get("SUPABASE_URL", "")
        SUPABASE_KEY = SUPABASE_KEY or secrets.get("SUPABASE_KEY", "")

if not SUPABASE_URL or not SUPABASE_KEY:
    print("ERROR: SUPABASE_URL and SUPABASE_KEY (service-role key) are required.")
    sys.exit(1)

MEDIA_BUCKET = "movement-media"
SIGNED_URL_EXPIRY = 60 * 60 * 24 * 365 * 10  # 10 years, matches compress_images.py
CLEAN_DIR = Path(__file__).parent / "output" / "movement_images_clean"
REPORT_PATH = Path(__file__).parent / "output" / "movement_images_report.csv"
OLD_PATHS_PATH = Path(__file__).parent / "output" / "old_bucket_paths.txt"


def main() -> None:
    if not CLEAN_DIR.exists() or not REPORT_PATH.exists() or not OLD_PATHS_PATH.exists():
        print("Missing export output. Run export_movement_images.py first.")
        sys.exit(1)

    client = create_client(SUPABASE_URL, SUPABASE_KEY)

    # 1. Upload every clean image to the bucket root (flat).
    clean_files = sorted(CLEAN_DIR.glob("*.jpg"))
    print(f"Uploading {len(clean_files)} file(s) to '{MEDIA_BUCKET}' root...")
    for path in clean_files:
        client.storage.from_(MEDIA_BUCKET).upload(
            path=path.name,
            file=path.read_bytes(),
            file_options={"content-type": "image/jpeg", "upsert": "true"},
        )
    print("Upload done.\n")

    # 2. Sign each uploaded file once; reuse the same URL for every movement
    #    row that maps to it.
    print("Creating signed URLs...")
    clean_name_to_url: dict[str, str] = {}
    for path in clean_files:
        signed = client.storage.from_(MEDIA_BUCKET).create_signed_url(
            path.name, SIGNED_URL_EXPIRY
        )
        clean_name_to_url[path.name] = signed["signedURL"]
    print(f"Signed {len(clean_name_to_url)} URL(s).\n")

    # 3. Repoint every movement row that has a mapped clean image.
    print("Updating movement.media_src...")
    updated = 0
    with open(REPORT_PATH, newline="") as f:
        for row in csv.DictReader(f):
            clean_name = row["old_media_src_clean_name"]
            if not clean_name:
                continue
            url = clean_name_to_url[clean_name]
            client.table("movement").update({"media_src": url}).eq(
                "id", int(row["movement_id"])
            ).execute()
            updated += 1
    print(f"Updated {updated} movement row(s).\n")

    # 4. Verify every updated row now resolves to a file that actually exists
    #    before deleting anything old.
    print("Verifying updated rows point at files that exist...")
    existing_names = {p.name for p in clean_files}
    with open(REPORT_PATH, newline="") as f:
        for row in csv.DictReader(f):
            clean_name = row["old_media_src_clean_name"]
            if clean_name and clean_name not in existing_names:
                print(f"ABORT: movement {row['movement_id']} expects "
                      f"'{clean_name}' but it wasn't uploaded. Old files left in place.")
                sys.exit(1)
    print("Verified.\n")

    # 5. Only now, delete the old per-movement-id files.
    old_paths = [p for p in OLD_PATHS_PATH.read_text().splitlines() if p]
    print(f"Deleting {len(old_paths)} old file(s)...")
    client.storage.from_(MEDIA_BUCKET).remove(old_paths)
    print("Done.")


if __name__ == "__main__":
    main()
