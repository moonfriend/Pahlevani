"""
check_r2_completeness.py
════════════════════════
Verifies that every audio and image file referenced in the Supabase database
is present in the Cloudflare R2 bucket. Run this after uploading files to R2
and before updating the DB URLs, so you know nothing was missed.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
QUICK START
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    cd scripts
    export SUPABASE_URL=https://<project-ref>.supabase.co
    export SUPABASE_KEY=<service-role-key>      # NOT the anon key
    export R2_ACCESS_KEY_ID=<r2-token-id>
    export R2_SECRET_ACCESS_KEY=<r2-token-secret>
    uv run python check_r2_completeness.py

Exit code 0 = all files present. Exit code 1 = one or more files missing.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ENVIRONMENT VARIABLES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Required:
    SUPABASE_URL          Full project URL, e.g. https://abc123.supabase.co
    SUPABASE_KEY          Service-role key (Settings → API → service_role).
                          Needs SELECT on 'exercise' and 'movement' tables.
    R2_ACCESS_KEY_ID      R2 API token ID with at least Object Read + List
                          permissions on the target bucket.
    R2_SECRET_ACCESS_KEY  Matching secret for the above token.

Optional (defaults already set for this project):
    R2_ACCOUNT_ID         Cloudflare account ID (default: 52a61783f2d01cd161e65ac58f130716)
    R2_BUCKET             R2 bucket name (default: morshed-sounds)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HOW TO GET R2 CREDENTIALS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Cloudflare Dashboard → R2 → Manage R2 API Tokens → Create API Token.
2. Set permissions: Object Read and List on the 'morshed-sounds' bucket.
3. Copy "Access Key ID" → R2_ACCESS_KEY_ID
   Copy "Secret Access Key" → R2_SECRET_ACCESS_KEY
   (The secret is shown only once — save it somewhere safe.)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WHAT IT CHECKS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    exercise.url         → audio files  (R2 bucket folder: "Sirvan/")
    movement.media_src   → image files  (R2 bucket folder: "movement_images/")

R2 files were uploaded manually into flat folders, not mirroring the Supabase
bucket/path structure — matching is by filename only. The script extracts the
filename from each Supabase Storage URL (handles both public and signed URL
shapes, stripping any `?token=...`) and looks for a same-named object under
the relevant R2 folder. Files that are missing are printed with their
original Supabase URL so you know exactly what to re-upload.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TYPICAL WORKFLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Upload audio/image files to R2 (already done manually: "Sirvan/" for
   audio, "movement_images/" for images).
2. Run this script. Fix any missing files reported.
3. Re-run until exit code 0.
4. Update the DB — see the SQL in supabase/migrations/ prepared alongside
   this check (uses filename-based matching, not the literal-substring
   replace this docstring used to suggest — that shape assumed public URLs,
   but production URLs are signed).
"""

import os
import sys
import tomllib
from pathlib import Path
from urllib.parse import urlparse, unquote

import boto3
from botocore.config import Config
from supabase import create_client


# ── Config ────────────────────────────────────────────────────────────────────

def _secret(key: str, default: str = "") -> str:
    """env var first, falling back to scripts/.streamlit/secrets.toml."""
    val = os.environ.get(key, "")
    if val:
        return val
    secrets_path = Path(__file__).parent / ".streamlit" / "secrets.toml"
    if secrets_path.exists():
        with open(secrets_path, "rb") as f:
            return tomllib.load(f).get(key, default)
    return default


SUPABASE_URL = _secret("SUPABASE_URL")
SUPABASE_KEY = _secret("SUPABASE_KEY")
R2_ACCOUNT_ID = _secret("R2_ACCOUNT_ID", "52a61783f2d01cd161e65ac58f130716")
R2_BUCKET = _secret("R2_BUCKET", "morshed-sounds")
R2_ACCESS_KEY_ID = _secret("R2_ACCESS_KEY_ID")
R2_SECRET_ACCESS_KEY = _secret("R2_SECRET_ACCESS_KEY")

R2_ENDPOINT = f"https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

# R2 bucket layout actually used (flat folders, not a mirror of the Supabase
# bucket/path structure): audio under "Sirvan/", images under "movement_images/".
# Matching is by filename (basename) within the relevant R2 prefix.
R2_AUDIO_PREFIX = "Sirvan/"
R2_IMAGE_PREFIX = "movement_images/"


def _require_env() -> None:
    missing = [name for name, val in (
        ("SUPABASE_URL", SUPABASE_URL), ("SUPABASE_KEY", SUPABASE_KEY),
        ("R2_ACCESS_KEY_ID", R2_ACCESS_KEY_ID),
        ("R2_SECRET_ACCESS_KEY", R2_SECRET_ACCESS_KEY),
    ) if not val]
    if missing:
        print(f"ERROR: missing credentials: {', '.join(missing)}")
        print("Set as env vars or add to scripts/.streamlit/secrets.toml")
        sys.exit(1)


# ── URL → filename ────────────────────────────────────────────────────────────

def _filename_from_url(url: str) -> str | None:
    """Extract just the filename (basename) from a Supabase Storage URL,
    stripping any query string (e.g. signed-URL `?token=...`).

    The R2 bucket uses flat folders ("Sirvan/" for audio, "movement_images/"
    for images) rather than mirroring the Supabase bucket/path structure, so
    matching is done by filename only, not full relative path.
    """
    if not url or not url.strip():
        return None
    try:
        parsed = urlparse(url)
        parts = [p for p in parsed.path.split("/") if p]
        return unquote(parts[-1]) if parts else None
    except Exception:
        return None


# ── Supabase queries ──────────────────────────────────────────────────────────

def fetch_db_files(supabase_url: str, supabase_key: str) -> tuple[dict, dict]:
    """Return two dicts: {filename: original_url} for audio and images."""
    client = create_client(supabase_url, supabase_key)

    audio: dict[str, str] = {}
    images: dict[str, str] = {}

    # Audio: exercise.url
    page, page_size = 0, 1000
    while True:
        rows = (
            client.table("exercise")
            .select("id, url")
            .not_.is_("url", "null")
            .range(page * page_size, (page + 1) * page_size - 1)
            .execute()
        ).data
        for row in rows:
            url = (row.get("url") or "").strip()
            name = _filename_from_url(url)
            if name:
                audio[name] = url
        if len(rows) < page_size:
            break
        page += 1

    # Images: movement.media_src (only photo type)
    page = 0
    while True:
        rows = (
            client.table("movement")
            .select("id, media_src, media_type")
            .not_.is_("media_src", "null")
            .eq("media_type", "photo")
            .range(page * page_size, (page + 1) * page_size - 1)
            .execute()
        ).data
        for row in rows:
            url = (row.get("media_src") or "").strip()
            name = _filename_from_url(url)
            if name:
                images[name] = url
        if len(rows) < page_size:
            break
        page += 1

    return audio, images


# ── R2 listing ────────────────────────────────────────────────────────────────

def list_r2_filenames(access_key: str, secret_key: str, prefix: str) -> set[str]:
    """List object keys under `prefix` in the R2 bucket, returned as bare filenames."""
    s3 = boto3.client(
        "s3",
        endpoint_url=R2_ENDPOINT,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(signature_version="s3v4"),
        region_name="auto",
    )

    names: set[str] = set()
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=R2_BUCKET, Prefix=prefix):
        for obj in page.get("Contents", []):
            key = obj["Key"]
            if key != prefix:  # skip the folder placeholder object itself, if any
                names.add(key[len(prefix):])

    return names


# ── Report ────────────────────────────────────────────────────────────────────

def report(label: str, db_keys: dict[str, str], r2_keys: set[str]) -> int:
    present = {k for k in db_keys if k in r2_keys}
    missing = {k: db_keys[k] for k in db_keys if k not in r2_keys}

    print(f"\n{'─' * 60}")
    print(f"  {label}")
    print(f"{'─' * 60}")
    print(f"  DB entries  : {len(db_keys)}")
    print(f"  In R2       : {len(present)}")
    print(f"  MISSING     : {len(missing)}")

    if missing:
        print("\n  ⚠  Missing from R2 — upload these files:")
        for key, orig_url in sorted(missing.items()):
            print(f"    key  : {key}")
            print(f"    from : {orig_url}")
            print()
    else:
        print("\n  ✓  All present in R2.")

    return len(missing)


def main() -> None:
    _require_env()

    print(f"Connecting to Supabase: {SUPABASE_URL}")
    print(f"Listing R2 bucket     : {R2_BUCKET} @ {R2_ENDPOINT}")

    print("\nFetching DB file references…")
    audio, images = fetch_db_files(SUPABASE_URL, SUPABASE_KEY)
    print(f"  Found {len(audio)} audio URLs and {len(images)} image URLs in DB.")

    print(f"\nListing R2 objects under '{R2_AUDIO_PREFIX}' and '{R2_IMAGE_PREFIX}'…")
    r2_audio = list_r2_filenames(R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_AUDIO_PREFIX)
    r2_images = list_r2_filenames(R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_IMAGE_PREFIX)
    print(f"  Found {len(r2_audio)} files under '{R2_AUDIO_PREFIX}', "
          f"{len(r2_images)} under '{R2_IMAGE_PREFIX}'.")

    total_missing = 0
    total_missing += report("AUDIO (exercise.url)", audio, r2_audio)
    total_missing += report("IMAGES (movement.media_src)", images, r2_images)

    print(f"\n{'═' * 60}")
    if total_missing == 0:
        print("  ✓  R2 bucket is complete. Ready to update DB URLs.")
    else:
        print(f"  ✗  {total_missing} file(s) missing from R2.")
        print("     Upload the files above, then re-run this script.")
    print(f"{'═' * 60}\n")

    sys.exit(1 if total_missing > 0 else 0)


if __name__ == "__main__":
    main()
