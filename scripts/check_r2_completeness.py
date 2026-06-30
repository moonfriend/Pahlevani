"""
R2 completeness check — verifies that every audio and image URL stored in
the Supabase DB has a corresponding object in the Cloudflare R2 bucket.

Usage:
    cd scripts
    uv run python check_r2_completeness.py

Required environment variables:
    SUPABASE_URL          — e.g. https://REDACTED-PROJECT.supabase.co
    SUPABASE_KEY          — service-role key (needs SELECT on exercise + movement)
    R2_ACCESS_KEY_ID      — R2 API token with Object Read permissions
    R2_SECRET_ACCESS_KEY  — (paired with the above)

Optional:
    R2_ACCOUNT_ID         — defaults to 52a61783f2d01cd161e65ac58f130716
    R2_BUCKET             — defaults to morshed-sounds

What it checks:
    • exercise.url         → audio files (bucket was "tracks" in Supabase)
    • movement.media_src   → image files (bucket was "movement-media" in Supabase)

The script extracts the path segment from each Supabase Storage URL and
compares it to the list of R2 object keys. Files that are missing from R2
are printed so you can upload them.
"""

import os
import sys
from urllib.parse import urlparse, unquote

import boto3
from botocore.config import Config
from supabase import create_client


# ── Config ────────────────────────────────────────────────────────────────────

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "")
R2_ACCOUNT_ID = os.environ.get("R2_ACCOUNT_ID", "52a61783f2d01cd161e65ac58f130716")
R2_BUCKET = os.environ.get("R2_BUCKET", "morshed-sounds")
R2_ACCESS_KEY_ID = os.environ.get("R2_ACCESS_KEY_ID", "")
R2_SECRET_ACCESS_KEY = os.environ.get("R2_SECRET_ACCESS_KEY", "")

R2_ENDPOINT = f"https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

# Known Supabase bucket names — used to strip the bucket prefix from paths.
SUPABASE_BUCKETS = {"tracks", "movement-media", "morshed-sounds"}


def _require_env() -> None:
    missing = [k for k in ("SUPABASE_URL", "SUPABASE_KEY",
                            "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY")
               if not os.environ.get(k)]
    if missing:
        print(f"ERROR: missing env vars: {', '.join(missing)}")
        sys.exit(1)


# ── URL → R2 key ──────────────────────────────────────────────────────────────

def _url_to_r2_key(url: str) -> str | None:
    """Extract the object key from a Supabase Storage URL.

    Supabase Storage URL shapes:
      public:  .../storage/v1/object/public/<bucket>/<path>
      signed:  .../storage/v1/object/sign/<bucket>/<path>?token=...
      direct:  .../storage/v1/object/<bucket>/<path>

    Returns just <path> (the part after the bucket name), since that is
    what callers upload to R2 with the same relative structure.
    Returns None if the URL is empty or not parseable.
    """
    if not url or not url.strip():
        return None
    try:
        parsed = urlparse(url)
        parts = [p for p in parsed.path.split("/") if p]
        # Strip /storage/v1/object/[public|sign]/<bucket>/<rest>
        # Find the index of a known Supabase bucket name.
        for i, part in enumerate(parts):
            if part in SUPABASE_BUCKETS:
                rest = "/".join(parts[i + 1:])
                return unquote(rest) if rest else None
        # Fallback: just use the last path segment (filename only).
        return unquote(parts[-1]) if parts else None
    except Exception:
        return None


# ── Supabase queries ──────────────────────────────────────────────────────────

def fetch_db_files(supabase_url: str, supabase_key: str) -> tuple[dict, dict]:
    """Return two dicts: {r2_key: original_url} for audio and images."""
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
            key = _url_to_r2_key(url)
            if key:
                audio[key] = url
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
            key = _url_to_r2_key(url)
            if key:
                images[key] = url
        if len(rows) < page_size:
            break
        page += 1

    return audio, images


# ── R2 listing ────────────────────────────────────────────────────────────────

def list_r2_objects(access_key: str, secret_key: str) -> set[str]:
    """List all object keys in the R2 bucket."""
    s3 = boto3.client(
        "s3",
        endpoint_url=R2_ENDPOINT,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(signature_version="s3v4"),
        region_name="auto",
    )

    keys: set[str] = set()
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=R2_BUCKET):
        for obj in page.get("Contents", []):
            keys.add(obj["Key"])

    return keys


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

    print("\nListing R2 objects…")
    r2_keys = list_r2_objects(R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY)
    print(f"  Found {len(r2_keys)} objects in R2.")

    total_missing = 0
    total_missing += report("AUDIO (exercise.url)", audio, r2_keys)
    total_missing += report("IMAGES (movement.media_src)", images, r2_keys)

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
