"""
check_session_audio_coverage.py
════════════════════════════════
Content-integrity gate: finds any training_session_item that would resolve
to NO audio at all, for ANY Morshed choice.

Why this is a single check per item, not "every item x every Morshed":
resolveAudioTrack() (lib/domain/usecases/audio_catalog/resolve_audio_track.dart)
always falls back to *any* curated track for the movement's type when the
athlete's chosen Morshed has none — it never goes silent just because one
specific Morshed is missing a recording. Since migration
0034_drop_legacy_exercise_audio_columns.sql removed the legacy per-exercise
audio fallback entirely, the one remaining condition for "no audio for any
Morshed choice" is simply: the item's movement has no type_id curated, or
its type has zero movement_audio_track rows.

QUICK START (command line)
    PAHLEVANI_ENV=staging bash scripts/run_admin.sh --script check_session_audio_coverage.py
    PAHLEVANI_ENV=production bash scripts/run_admin.sh --script check_session_audio_coverage.py

Exit code 0 = every session item has resolvable audio. Exit code 1 = at
least one broken item found (printed below, grouped by session).

Also available inside the admin UI itself, under the "🧰 Utility" tab, which
calls run_coverage_check() directly and renders the same result as a report.
"""

import os
import sys

from supabase import create_client


def run_coverage_check(db) -> dict:
    """Runs the check against an already-constructed Supabase client and
    returns a structured report — no printing, no client construction, so
    this is safe to call from both the CLI entry point below and the admin
    UI's Utility tab, against whichever environment `db` points at."""
    sessions = {s["id"]: s for s in db.table("training_session").select("id,title").execute().data}
    items = db.table("training_session_item").select("training_session_id,exercise_id,position").execute().data
    exercises = {e["id"]: e for e in db.table("exercise").select("id,movement_id").execute().data}
    movements = {m["id"]: m for m in db.table("movement").select("id,name,type_id").execute().data}

    curated_type_ids = {
        t["movement_type_id"]
        for t in db.table("movement_audio_track").select("movement_type_id").execute().data
    }

    broken = []
    for item in items:
        ex = exercises.get(item["exercise_id"])
        if ex is None:
            continue  # dangling reference — a different problem, not audio coverage

        mov = movements.get(ex.get("movement_id"))
        type_id = mov.get("type_id") if mov else None
        has_curated_track = type_id is not None and type_id in curated_type_ids

        if not has_curated_track:
            broken.append({
                "session_id": item["training_session_id"],
                "session_title": sessions.get(item["training_session_id"], {}).get("title", "?"),
                "position": item["position"],
                "exercise_id": item["exercise_id"],
                "movement_name": mov.get("name") if mov else "(no movement)",
                "reason": "no movement_type curated with any recording",
            })

    return {
        "sessions_checked": len(sessions),
        "items_checked": len(items),
        "exercises_checked": len(exercises),
        "movements_checked": len(movements),
        "curated_type_count": len(curated_type_ids),
        "broken": sorted(broken, key=lambda b: (b["session_id"], b["position"])),
    }


def print_report(report: dict) -> int:
    """CLI rendering of run_coverage_check()'s result. Returns the process
    exit code (0 = clean, 1 = broken items found)."""
    broken = report["broken"]
    if not broken:
        print(f"✅ All session items have resolvable audio "
              f"({report['items_checked']} items checked).")
        return 0

    print(f"❌ {len(broken)} session item(s) would resolve to NO audio for any Morshed:\n")
    by_session: dict[int, list] = {}
    for row in broken:
        by_session.setdefault(row["session_id"], []).append(row)
    for session_id, rows in sorted(by_session.items()):
        title = rows[0]["session_title"]
        print(f"Session {session_id} — {title}")
        for row in rows:
            print(f"    position {row['position']}: exercise {row['exercise_id']} "
                  f"({row['movement_name']}) — {row['reason']}")
        print()
    return 1


def main() -> int:
    supabase_url = os.environ.get("SUPABASE_URL", "")
    supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not supabase_url or not supabase_key:
        sys.exit("Missing SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY — run via scripts/run_admin.sh")

    db = create_client(supabase_url, supabase_key)
    report = run_coverage_check(db)
    return print_report(report)


if __name__ == "__main__":
    sys.exit(main())
