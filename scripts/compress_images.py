"""
compress_images.py — Compress movement photos stored in Supabase.

Background
----------
Images are stored as full-resolution PNGs (6–9 MB each).  Flutter's image
cache is in-memory only so every app restart re-downloads them.  Compressing
to JPEG 75 / max 800 px cuts them to ~50–150 KB — a 50–100× reduction.

Because we overwrite files at the same storage path the existing 10-year
signed URLs in the DB remain valid; no database update is needed.

Usage
-----
    cd scripts
    uv run python compress_images.py            # compress & upload
    uv run python compress_images.py --dry-run  # show sizes, no upload

Credentials
-----------
Requires the SERVICE ROLE key (not the anon key) for storage writes.
Set via env vars or .streamlit/secrets.toml:
    SUPABASE_URL=https://xxx.supabase.co
    SUPABASE_KEY=<service-role-key>
"""

import argparse
import io
import os
import sys
import tomllib
from pathlib import Path

try:
    import requests
    from PIL import Image
    from supabase import create_client
except ImportError:
    print("Missing deps. Run: uv sync")
    sys.exit(1)

# ── Credentials ───────────────────────────────────────────────────────────────

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
    print(
        "ERROR: SUPABASE_URL and SUPABASE_KEY (service-role key) are required.\n"
        "Add them to scripts/.streamlit/secrets.toml or set as env vars."
    )
    sys.exit(1)

MEDIA_BUCKET = "movement-media"
SIGNED_URL_EXPIRY = 60 * 60 * 24 * 365 * 10  # 10 years
MAX_DIMENSION = 800  # max width or height in pixels
JPEG_QUALITY = 75
SIZE_THRESHOLD_KB = 300  # skip files already below this size


# ── Helpers ───────────────────────────────────────────────────────────────────

def extract_storage_path(signed_url: str) -> str | None:
    """Extract 'folder/file.ext' from a Supabase signed URL."""
    marker = f"/storage/v1/object/sign/{MEDIA_BUCKET}/"
    if marker not in signed_url:
        return None
    path_with_query = signed_url.split(marker, 1)[1]
    return path_with_query.split("?")[0]


def compress_image(data: bytes) -> bytes:
    """Resize to MAX_DIMENSION×MAX_DIMENSION (contain) and encode as JPEG."""
    img = Image.open(io.BytesIO(data)).convert("RGB")
    img.thumbnail((MAX_DIMENSION, MAX_DIMENSION), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=JPEG_QUALITY, optimize=True)
    return buf.getvalue()


def human(n: int) -> str:
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f} MB"
    if n >= 1_000:
        return f"{n / 1_000:.0f} KB"
    return f"{n} B"


# ── Main ──────────────────────────────────────────────────────────────────────

def main(dry_run: bool) -> None:
    client = create_client(SUPABASE_URL, SUPABASE_KEY)
    http = requests.Session()

    # Fetch all movements with photo media
    rows = (
        client.table("movement")
        .select("id, name, media_src")
        .eq("media_type", "photo")
        .not_.is_("media_src", "null")
        .execute()
        .data
    )

    if not rows:
        print("No photo movements found.")
        return

    mode = "[DRY RUN] " if dry_run else ""
    print(f"\n{mode}Compressing {len(rows)} movement images\n")
    print(f"  Target: max {MAX_DIMENSION}px, JPEG quality {JPEG_QUALITY}")
    print(f"  Skip threshold: files already < {SIZE_THRESHOLD_KB} KB\n")
    print(f"{'#':<4} {'Name':<35} {'Before':>9}  {'After':>9}  {'Saved':>7}  {'Status'}")
    print("-" * 80)

    total_before = 0
    total_after = 0
    skipped = 0
    errors = 0

    for i, row in enumerate(rows, 1):
        name = (row.get("name") or "")[:34]
        src = row.get("media_src") or ""
        mov_id = row["id"]

        storage_path = extract_storage_path(src)
        if not storage_path:
            print(f"{i:<4} {name:<35} {'(non-Supabase URL — skip)':>30}")
            skipped += 1
            continue

        # Download original
        try:
            r = http.get(src, timeout=30)
            r.raise_for_status()
            original = r.content
        except Exception as e:
            print(f"{i:<4} {name:<35} {'':>9}  {'':>9}  {'':>7}  ERROR download: {e}")
            errors += 1
            continue

        orig_size = len(original)
        total_before += orig_size

        if orig_size < SIZE_THRESHOLD_KB * 1000:
            total_after += orig_size
            print(
                f"{i:<4} {name:<35} {human(orig_size):>9}  {'(already small)':>9}  {'':>7}  skip"
            )
            skipped += 1
            continue

        # Compress
        try:
            compressed = compress_image(original)
        except Exception as e:
            print(f"{i:<4} {name:<35} {human(orig_size):>9}  {'':>9}  {'':>7}  ERROR compress: {e}")
            errors += 1
            total_after += orig_size
            continue

        comp_size = len(compressed)
        total_after += comp_size
        saved_pct = (1 - comp_size / orig_size) * 100

        if dry_run:
            print(
                f"{i:<4} {name:<35} {human(orig_size):>9}  {human(comp_size):>9}  {saved_pct:>6.0f}%  [would upload]"
            )
            continue

        # Upload (upsert — overwrites the existing file at the same path)
        try:
            client.storage.from_(MEDIA_BUCKET).upload(
                path=storage_path,
                file=compressed,
                file_options={"content-type": "image/jpeg", "upsert": "true"},
            )
            print(
                f"{i:<4} {name:<35} {human(orig_size):>9}  {human(comp_size):>9}  {saved_pct:>6.0f}%  uploaded"
            )
        except Exception as e:
            print(
                f"{i:<4} {name:<35} {human(orig_size):>9}  {human(comp_size):>9}  {saved_pct:>6.0f}%  ERROR upload: {e}"
            )
            errors += 1

    print("-" * 80)
    total_saved_pct = (1 - total_after / total_before) * 100 if total_before else 0
    print(
        f"{'TOTAL':<39} {human(total_before):>9}  {human(total_after):>9}  {total_saved_pct:>6.0f}%"
    )
    if skipped:
        print(f"  Skipped: {skipped}  |  Errors: {errors}")

    if dry_run:
        print("\nRe-run without --dry-run to apply changes.")
    elif errors == 0:
        print(
            "\n✓ All files replaced in-place. Existing signed URLs in the database\n"
            "  continue to work — no DB update needed."
        )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Compress movement images in Supabase")
    parser.add_argument("--dry-run", action="store_true", help="Show sizes only, no upload")
    args = parser.parse_args()
    main(dry_run=args.dry_run)
