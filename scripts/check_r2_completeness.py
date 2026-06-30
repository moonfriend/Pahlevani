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

    exercise.url         → audio files  (source bucket in Supabase: "tracks")
    movement.media_src   → image files  (source bucket in Supabase: "movement-media")

The script extracts the path segment from each Supabase Storage URL
(the part after the bucket name) and looks for a matching object key in R2.
Files that are missing are printed with their original Supabase URL so you
know exactly what to re-upload.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TYPICAL WORKFLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Upload audio and image files to R2 (via Cloudflare dashboard or rclone).
2. Run this script. Fix any missing files reported.
3. Re-run until exit code 0.
4. Update DB: replace Supabase Storage URLs with R2 public URLs using SQL:

       UPDATE exercise
       SET url = replace(url,
         'https://<project>.supabase.co/storage/v1/object/public/tracks/',
         'https://pub-<token>.r2.dev/'
       )
       WHERE url LIKE '%supabase.co%';

       UPDATE movement
       SET media_src = replace(media_src,
         'https://<project>.supabase.co/storage/v1/object/public/movement-media/',
         'https://pub-<token>.r2.dev/'
       )
       WHERE media_src LIKE '%supabase.co%';

5. Run the app with staging Supabase (`SUPABASE_URL` + `SUPABASE_KEY` dart-
   defines) to verify playback before touching production.
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
