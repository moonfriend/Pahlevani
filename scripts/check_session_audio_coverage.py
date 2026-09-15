"""
check_session_audio_coverage.py
════════════════════════════════
Content-integrity gate: finds any training_session_item that would resolve
to NO audio at all, for ANY Morshed choice.

Why this is a single check per item, not "every item x every Morshed":
resolveAudioTrack() (lib/domain/usecases/audio_catalog/resolve_audio_track.dart)
always falls back to *any* curated track for the movement's type when the
athlete's chosen Morshed has none — it never goes silent just because one
specific Morshed is missing a recording. The only way an item has no audio
for literally any Morshed choice is:
  - its movement has no type_id curated yet, AND
  - its own legacy exercise.audio_url is also empty.
That's the one condition this script checks, mirroring resolveAudioTrack's
real fallback semantics exactly (not a naive re-check per Morshed, which
would just repeat the same answer for every Morshed and miss nothing extra).

QUICK START
    PAHLEVANI_ENV=staging bash scripts/run_admin.sh --script check_session_audio_coverage.py
    PAHLEVANI_ENV=production bash scripts/run_admin.sh --script check_session_audio_coverage.py

Exit code 0 = every session item has resolvable audio. Exit code 1 = at
least one broken item found (printed below, grouped by session) — safe to
wire into a release-gate check later.
"""

import os
import sys

from supabase import create_client

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

if not SUPABASE_URL or not SUPABASE_KEY:
    sys.exit("Missing SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY — run via scripts/run_admin.sh")

db = create_client(SUPABASE_URL, SUPABASE_KEY)


def main():
    sessions = {s["id"]: s for s in db.table("training_session").select("id,title").execute().data}
    items = db.table("training_session_item").select("training_session_id,exercise_id,position").execute().data
    exercises = {e["id"]: e for e in db.table("exercise").select("id,movement_id,audio_url").execute().data}
    movements = {m["id"]: m for m in db.table("movement").select("id,name,type_id").execute().data}

    curated_type_ids = {
        t["movement_type_id"]
        for t in db.table("movement_audio_track").select("movement_type_id").execute().data
    }

    broken = []  # (session_id, session_title, position, exercise_id, movement_name)
    for item in items:
        ex = exercises.get(item["exercise_id"])
        if ex is None:
            continue  # dangling reference — a different problem, not audio coverage
        has_legacy_audio = bool(ex.get("audio_url"))

        mov = movements.get(ex.get("movement_id"))
        type_id = mov.get("type_id") if mov else None
        has_curated_track = type_id is not None and type_id in curated_type_ids

        if not has_legacy_audio and not has_curated_track:
            broken.append((
                item["training_session_id"],
                sessions.get(item["training_session_id"], {}).get("title", "?"),
                item["position"],
                item["exercise_id"],
                mov.get("name") if mov else "(no movement)",
            ))

    if not broken:
        print(f"✅ All session items have resolvable audio ({len(items)} items checked).")
        return 0

    print(f"❌ {len(broken)} session item(s) would resolve to NO audio for any Morshed:\n")
    by_session: dict[int, list] = {}
    for row in broken:
        by_session.setdefault(row[0], []).append(row)
    for session_id, rows in sorted(by_session.items()):
        title = rows[0][1]
        print(f"Session {session_id} — {title}")
        for _, _, position, exercise_id, movement_name in sorted(rows, key=lambda r: r[2]):
            print(f"    position {position}: exercise {exercise_id} ({movement_name}) — "
                  f"no movement_type curated and no legacy audio_url")
        print()
    return 1


if __name__ == "__main__":
    sys.exit(main())
