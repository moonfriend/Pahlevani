"""
upload_ali_eshaghi_recordings.py
═════════════════════════════════
One-off fix + full curation for Ali Eshaghi's recordings.

Background: every "Ali Eshaghi" exercise/movement_audio_track row currently
in the database points at the WRONG audio file — 4 are exact duplicates of
Sirvan's own recordings, one is unrelated — a historical data-entry mistake
that predates this tool. The real, complete 41-track Ali Eshaghi set exists
locally and was never uploaded. This script uploads it and fixes the DB.

For each of the 41 real local files (matched to a movement_type by its own
leading track number, same convention as Sirvan's set):
  - Uploads it to R2 under audio/movement_tracks/ali_eshaghi/<type_key>.mp3
  - If a movement_audio_track row already exists for (type, Ali Eshaghi),
    corrects its audio_url + duration_seconds in place (repetitions_default
    is left untouched — it already matches the real file for all 5 existing
    rows, verified by hand before writing this script).
  - Otherwise inserts a new row (repetitions_default defaults to 1 — no
    exercise ever existed for these 36, so there's no historical rep count
    to carry over; correct it in the Recordings tab once someone has an
    authoritative count).
  - Also corrects the matching legacy `exercise` row's audio_url +
    duration_seconds, for the 5 movements that have one (ids 1, 2, 4, 40,
    41) — keeps the legacy fallback path honest too, even though it's no
    longer what actually plays once a type is curated.

QUICK START
    PAHLEVANI_ENV=staging bash scripts/run_admin.sh --script upload_ali_eshaghi_recordings.py
    PAHLEVANI_ENV=production bash scripts/run_admin.sh --script upload_ali_eshaghi_recordings.py

Safe to re-run: re-uploads (R2 overwrite by same key) and re-applies the
same corrections idempotently.
"""

import io
import os
import re
import sys
from pathlib import Path

import boto3
from botocore.config import Config as BotoConfig
from mutagen.mp3 import MP3
from supabase import create_client

LOCAL_DIR = Path("/home/mamito/01excercise/0_Pahlevani/pahlavani/soti/01 ali eshaghi")
MUSICIAN_NAME = "Ali Eshaghi"
R2_PREFIX = "audio/movement_tracks/ali_eshaghi/"

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
R2_ACCOUNT_ID = os.environ.get("R2_ACCOUNT_ID", "")
R2_BUCKET = os.environ.get("R2_BUCKET", "") or "morshed-sounds"
R2_ACCESS_KEY_ID = os.environ.get("R2_ACCESS_KEY_ID", "")
R2_SECRET_ACCESS_KEY = os.environ.get("R2_SECRET_ACCESS_KEY", "")
R2_PUBLIC_BASE = os.environ.get(
    "R2_PUBLIC_BASE", "https://pub-d26e099daad243af8e9221f16223fb95.r2.dev"
)

if not SUPABASE_URL or not SUPABASE_KEY:
    sys.exit("Missing SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY — run via scripts/run_admin.sh")
if not R2_ACCOUNT_ID or not R2_ACCESS_KEY_ID or not R2_SECRET_ACCESS_KEY:
    sys.exit("Missing R2 credentials — run via scripts/run_admin.sh")
if not LOCAL_DIR.is_dir():
    sys.exit(f"Local folder not found: {LOCAL_DIR}")

db = create_client(SUPABASE_URL, SUPABASE_KEY)
r2 = boto3.client(
    "s3",
    endpoint_url=f"https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com",
    aws_access_key_id=R2_ACCESS_KEY_ID,
    aws_secret_access_key=R2_SECRET_ACCESS_KEY,
    config=BotoConfig(signature_version="s3v4"),
)


def duration_from_bytes(data: bytes) -> int | None:
    try:
        return round(MP3(io.BytesIO(data)).info.length)
    except Exception:
        return None


def upload_to_r2(data: bytes, key: str) -> str:
    r2.put_object(Bucket=R2_BUCKET, Key=key, Body=data, ContentType="audio/mpeg")
    return f"{R2_PUBLIC_BASE}/{key}"


def main():
    types = db.table("movement_type").select("id,key").execute().data
    type_by_prefix = {}
    for t in types:
        m = re.match(r"^(\d+)_", t["key"])
        if m:
            type_by_prefix[m.group(1)] = t

    musicians = db.table("musician").select("id,name").execute().data
    musician = next((m for m in musicians if m["name"] == MUSICIAN_NAME), None)
    if musician is None:
        sys.exit(f"No musician named '{MUSICIAN_NAME}' found — add them in admin.py first.")
    musician_id = musician["id"]

    existing_tracks = {
        (t["movement_type_id"], t["musician_id"]): t
        for t in db.table("movement_audio_track").select("*").eq("musician_id", musician_id).execute().data
    }
    legacy_exercises = {
        e["movement_id"]: e
        for e in db.table("exercise").select("*").eq("author", MUSICIAN_NAME).execute().data
    }
    movements = db.table("movement").select("id,type_id").execute().data
    movement_id_by_type_id: dict[int, int] = {}
    for mv in movements:
        if mv.get("type_id") is not None:
            movement_id_by_type_id.setdefault(mv["type_id"], mv["id"])

    files = sorted(LOCAL_DIR.glob("*.mp3"))
    print(f"Found {len(files)} local files, {len(types)} movement types, "
          f"musician_id={musician_id}, {len(existing_tracks)} existing track(s), "
          f"{len(legacy_exercises)} legacy exercise row(s) to also fix.\n")

    inserted, updated, skipped = 0, 0, 0
    for f in files:
        m = re.match(r"^(\d+)", f.stem)
        prefix = f"{int(m.group(1)):02d}" if m else None
        movement_type = type_by_prefix.get(prefix)
        if movement_type is None:
            print(f"SKIP {f.name}: no movement_type matches prefix {prefix!r}")
            skipped += 1
            continue

        data = f.read_bytes()
        duration = duration_from_bytes(data)
        url = upload_to_r2(data, f"{R2_PREFIX}{movement_type['key']}.mp3")

        key = (movement_type["id"], musician_id)
        if key in existing_tracks:
            db.table("movement_audio_track").update({
                "audio_url": url,
                "duration_seconds": duration,
            }).eq("id", existing_tracks[key]["id"]).execute()
            updated += 1
            print(f"FIXED  {f.name:<40} -> type={movement_type['key']} duration={duration}s")
        else:
            db.table("movement_audio_track").insert({
                "movement_type_id": movement_type["id"],
                "musician_id": musician_id,
                "audio_url": url,
                "repetitions_default": 1,
                "duration_seconds": duration,
            }).execute()
            inserted += 1
            print(f"NEW    {f.name:<40} -> type={movement_type['key']} duration={duration}s")

        # Also fix the legacy exercise row, if this movement has one.
        mov_id = movement_id_by_type_id.get(movement_type["id"])
        legacy = legacy_exercises.get(mov_id) if mov_id else None
        if legacy is not None:
            db.table("exercise").update({
                "audio_url": url,
                "duration_seconds": duration,
            }).eq("id", legacy["id"]).execute()
            print(f"       also fixed legacy exercise id={legacy['id']}")

    print(f"\nDone. {inserted} inserted, {updated} corrected, {skipped} skipped.")


if __name__ == "__main__":
    main()
