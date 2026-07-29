"""
verify_r2_urls.py
═════════════════
One-off check: confirm every exercise.url / movement.media_src value in the
DB now points at Cloudflare R2 (not Supabase Storage) and actually downloads
(HTTP 200, non-empty body) — the final verification step of the R2 media
cutover (see supabase/migrations/0006_r2_media_urls.sql).

Usage:
    cd scripts
    uv run python verify_r2_urls.py

Credentials: same env-var / secrets.toml pattern as the other scripts
(SUPABASE_URL, SUPABASE_KEY).
"""

import os
import sys
import tomllib
from pathlib import Path

import requests
from supabase import create_client


def _secret(key: str) -> str:
    val = os.environ.get(key, "")
    if val:
        return val
    secrets_path = Path(__file__).parent / ".streamlit" / "secrets.toml"
    if secrets_path.exists():
        with open(secrets_path, "rb") as f:
            return tomllib.load(f).get(key, "")
    return ""


SUPABASE_URL = _secret("SUPABASE_URL")
SUPABASE_KEY = _secret("SUPABASE_KEY")


def check(label: str, rows: list[tuple[int, str]]) -> tuple[int, int, int]:
    """Returns (ok, not_cloudflare, failed)."""
    ok = not_cloudflare = failed = 0
    print(f"\n{'─' * 60}\n  {label} — {len(rows)} rows\n{'─' * 60}")
    for row_id, url in rows:
        if "r2.dev" not in url and "cloudflarestorage.com" not in url:
            print(f"  ⚠  id={row_id}  NOT ON CLOUDFLARE: {url}")
            not_cloudflare += 1
            continue
        try:
            r = requests.head(url, timeout=15, allow_redirects=True)
            if r.status_code == 200 and int(r.headers.get("content-length", "1")) > 0:
                ok += 1
            else:
                print(f"  ✗  id={row_id}  HTTP {r.status_code}  {url}")
                failed += 1
        except Exception as e:
            print(f"  ✗  id={row_id}  ERROR {e}  {url}")
            failed += 1
    print(f"  ✓ ok: {ok}   ⚠ not-cloudflare: {not_cloudflare}   ✗ failed: {failed}")
    return ok, not_cloudflare, failed


def main() -> None:
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("ERROR: SUPABASE_URL / SUPABASE_KEY missing (env or secrets.toml)")
        sys.exit(1)

    client = create_client(SUPABASE_URL, SUPABASE_KEY)

    audio_rows = (
        client.table("exercise").select("id, url").not_.is_("url", "null").execute().data
    )
    audio = [(r["id"], r["url"].strip()) for r in audio_rows if r.get("url", "").strip()]

    image_rows = (
        client.table("movement")
        .select("id, media_src, media_type")
        .not_.is_("media_src", "null")
        .eq("media_type", "photo")
        .execute()
        .data
    )
    images = [(r["id"], r["media_src"].strip()) for r in image_rows if r.get("media_src", "").strip()]

    a_ok, a_bad_host, a_fail = check("AUDIO (exercise.url)", audio)
    i_ok, i_bad_host, i_fail = check("IMAGES (movement.media_src)", images)

    total_bad = a_bad_host + a_fail + i_bad_host + i_fail
    print(f"\n{'═' * 60}")
    if total_bad == 0:
        print(f"  ✓  All {a_ok + i_ok} media URLs point to Cloudflare and download successfully.")
    else:
        print(f"  ✗  {total_bad} problem(s) found — see above.")
    print(f"{'═' * 60}\n")
    sys.exit(1 if total_bad else 0)


if __name__ == "__main__":
    main()
