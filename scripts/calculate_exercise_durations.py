#!/usr/bin/env python3
"""
Fetch all exercises from Supabase, probe each audio URL for duration,
and print SQL UPDATE statements ready to paste into the Supabase SQL editor.

Requirements:
    pip install requests
    ffprobe must be on PATH (install via: sudo apt install ffmpeg)

Usage:
    python3 scripts/calculate_exercise_durations.py [--env staging]

Credentials: reads SUPABASE_URL/SUPABASE_ANON_KEY straight from
env/supabase.<env>.env at the repo root (JSON, same file Flutter builds use).
The anon key is sufficient — exercise table is public-read.
"""

import json
import os
import subprocess
import sys
import requests

_env_name = "staging" if "--env" in sys.argv and "staging" in sys.argv else "prod"
_env_path = os.path.join(
    os.path.dirname(__file__), "..", "env", f"supabase.{_env_name}.env"
)
with open(_env_path) as _f:
    _creds = json.load(_f)

SUPABASE_URL = _creds["SUPABASE_URL"]
SUPABASE_ANON_KEY = _creds["SUPABASE_ANON_KEY"]

HEADERS = {
    "apikey": SUPABASE_ANON_KEY,
    "Authorization": f"Bearer {SUPABASE_ANON_KEY}",
}


def fetch_exercises() -> list[dict]:
    url = f"{SUPABASE_URL}/rest/v1/exercise?select=id,url&url=not.is.null"
    resp = requests.get(url, headers=HEADERS, timeout=10)
    resp.raise_for_status()
    return resp.json()


def probe_duration(audio_url: str) -> float | None:
    """Return duration in seconds using ffprobe, or None on failure."""
    cmd = [
        "ffprobe",
        "-v", "quiet",
        "-print_format", "json",
        "-show_format",
        audio_url,
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode != 0:
            return None
        data = json.loads(result.stdout)
        return float(data["format"]["duration"])
    except (subprocess.TimeoutExpired, KeyError, json.JSONDecodeError, ValueError):
        return None


def main():
    print("Fetching exercises from Supabase...", file=sys.stderr)
    exercises = fetch_exercises()
    print(f"Found {len(exercises)} exercises with audio URLs.", file=sys.stderr)

    print("-- SQL: add duration_seconds column and populate it")
    print("-- Run this block in the Supabase SQL editor\n")
    print("ALTER TABLE exercise ADD COLUMN IF NOT EXISTS duration_seconds integer;\n")

    failed = []
    for ex in exercises:
        ex_id = ex["id"]
        url = ex["url"]
        print(f"  Probing exercise {ex_id}: {url[:60]}...", file=sys.stderr)
        duration = probe_duration(url)
        if duration is None:
            print(f"  FAILED: exercise {ex_id}", file=sys.stderr)
            failed.append(ex_id)
            continue
        print(f"UPDATE exercise SET duration_seconds = {round(duration)} WHERE id = {ex_id};")

    print(file=sys.stderr)
    if failed:
        print(f"Failed to probe {len(failed)} exercise(s): {failed}", file=sys.stderr)
    else:
        print("All exercises probed successfully.", file=sys.stderr)


if __name__ == "__main__":
    main()
