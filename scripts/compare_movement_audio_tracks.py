"""
compare_movement_audio_tracks.py
═════════════════════════════════
Targeted staging vs production comparison for movement_audio_track, keyed
by the real natural identity (movement_type.key, musician/morshed name) —
not by `id`, which diverges between environments (different insert order).
This is the comparison scripts/compare_staging_production.py deliberately
skips for this table; use this one instead when checking recording content
specifically (audio_url, repetitions_default, duration_seconds).

USAGE
    uv run --project scripts python scripts/compare_movement_audio_tracks.py
"""

from __future__ import annotations

from pathlib import Path

from supabase import create_client

CREDS_DIR = Path.home() / "StudioProjects" / "pahlevani-admin-creds"


def load_env_file(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        env[key.strip()] = value.strip().strip('"').strip("'")
    return env


def load_client(env_name: str, musician_table: str):
    # Plain separate queries + a Python-side join, not a PostgREST embed —
    # the embed (movement_type(key), musician(name)/morshed(name)) fails
    # with PGRST200 "no relationship found" on staging as of this run, most
    # likely a stale PostgREST schema-relationship cache; this sidesteps it
    # entirely rather than depending on that cache being fresh.
    env = load_env_file(CREDS_DIR / f"{env_name}.env")
    client = create_client(env["SUPABASE_URL"], env["SUPABASE_SERVICE_ROLE_KEY"])
    musician_id_col = "musician_id" if musician_table == "musician" else "morshed_id"

    type_key_by_id = {t["id"]: t["key"] for t in client.table("movement_type").select("id,key").execute().data}
    musician_name_by_id = {m["id"]: m["name"] for m in client.table(musician_table).select("id,name").execute().data}

    rows = client.table("movement_audio_track").select("*").execute().data
    by_key: dict[tuple[str, str], dict] = {}
    for r in rows:
        type_key = type_key_by_id.get(r["movement_type_id"])
        musician_name = musician_name_by_id.get(r[musician_id_col])
        by_key[(type_key, musician_name)] = {
            "audio_url": r["audio_url"],
            "repetitions_default": r["repetitions_default"],
            "duration_seconds": r["duration_seconds"],
            "audio_anchor_ms": r.get("audio_anchor_ms"),
        }
    return by_key


def main():
    staging = load_client("staging", "morshed")
    prod = load_client("production", "morshed")

    only_staging = sorted(set(staging) - set(prod))
    only_prod = sorted(set(prod) - set(staging))
    common = set(staging) & set(prod)

    print(f"staging: {len(staging)} tracks, production: {len(prod)} tracks\n")

    if only_staging:
        print(f"Only on staging ({len(only_staging)}):")
        for k in only_staging:
            print(f"  {k}")
        print()
    if only_prod:
        print(f"Only on production ({len(only_prod)}):")
        for k in only_prod:
            print(f"  {k}")
        print()

    differing = []
    for k in sorted(common):
        s, p = staging[k], prod[k]
        diff = {col: (s[col], p[col]) for col in s if s[col] != p[col]}
        if diff:
            differing.append((k, diff))

    if differing:
        print(f"⚠️  {len(differing)} matching (type, musician) pair(s) with different content:")
        for k, diff in differing:
            print(f"  {k}: {diff}")
    else:
        print(f"✅ All {len(common)} shared (type, musician) pairs have identical content.")


if __name__ == "__main__":
    main()
