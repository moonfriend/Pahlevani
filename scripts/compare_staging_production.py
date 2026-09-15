"""
compare_staging_production.py
══════════════════════════════
Side-by-side staging vs production comparison: table list, columns per
table, row counts, and (for small tables) row-by-row content diffs keyed by
`id`. Reusable — rerun any time to sanity-check the two environments.

Credentials: reads both `~/StudioProjects/pahlevani-admin-creds/staging.env`
and `.../production.env` directly (service-role tier) — needs both at once,
unlike scripts/with_admin_creds.sh which only sources one. No repo-tracked
secrets are used or printed.

Table list: fetched from each project's PostgREST root document
(`GET {url}/rest/v1/`), which lists every table/view it exposes — no direct
Postgres connection needed (the direct-DB password for production is known
to be stale as of this session; this approach sidesteps that entirely).

Column list per table: taken from the keys of a `select("*").limit(1)`
response on each side — this is what PostgREST actually returns, so it's
exactly the columns a client can see. Column *types* aren't compared (would
need a real information_schema query via direct Postgres, which the known
password issue makes unreliable) — noted as a gap, not silently assumed.

Row comparison: full-table row counts always; for tables under
ROW_DIFF_THRESHOLD rows, a row-by-row diff keyed by `id`, printed as
staging-only / production-only / differing-columns. Larger tables only get
counts — extend ROW_DIFF_THRESHOLD or add a --table filter if a full diff
on a big table is ever needed.

USAGE
    uv run --project scripts python scripts/compare_staging_production.py
    uv run --project scripts python scripts/compare_staging_production.py --table movement_audio_track
"""

from __future__ import annotations

import sys
from pathlib import Path

import requests
from supabase import create_client

CREDS_DIR = Path.home() / "StudioProjects" / "pahlevani-admin-creds"
ROW_DIFF_THRESHOLD = 200  # tables at or below this row count get a full row-by-row diff

# Row identity for the diff below defaults to the `id` primary key, which
# only means "the same logical row" when both environments received rows in
# the same insert order. That's false for tables curated independently on
# each side (e.g. via admin.py clicks on staging, migrations on
# production) — their auto-increment ids diverge even when the *content* is
# the same. Override the identity column per table here where `id` isn't
# meaningful; leave tables out entirely (see SKIP_ROW_DIFF) where even a
# natural key isn't a single column.
NATURAL_KEY = {
    "movement_type": "key",
}
SKIP_ROW_DIFF = {
    "movement_audio_track": (
        "insert order differs per environment (admin.py UI clicks on "
        "staging vs. migrations on production), so ids aren't comparable "
        "and there's no single natural-key column (it's movement_type.key "
        "+ musician/morshed.name) — compare by hand via the Recordings tab "
        "or a dedicated query instead of this script's generic row diff."
    ),
}


def load_env_file(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        value = value.strip().strip('"').strip("'")
        env[key.strip()] = value
    return env


def load_creds(env_name: str) -> tuple[str, str]:
    path = CREDS_DIR / f"{env_name}.env"
    if not path.exists():
        sys.exit(f"Missing {path}")
    env = load_env_file(path)
    url = env.get("SUPABASE_URL", "")
    key = env.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        sys.exit(f"{path} is missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY")
    return url, key


def fetch_table_list(url: str, key: str) -> set[str]:
    r = requests.get(
        f"{url}/rest/v1/",
        headers={"apikey": key, "Authorization": f"Bearer {key}"},
        timeout=15,
    )
    r.raise_for_status()
    return set(r.json().get("definitions", {}).keys())


def main():
    only_table = None
    if "--table" in sys.argv:
        only_table = sys.argv[sys.argv.index("--table") + 1]

    staging_url, staging_key = load_creds("staging")
    prod_url, prod_key = load_creds("production")
    staging = create_client(staging_url, staging_key)
    prod = create_client(prod_url, prod_key)

    print("═" * 78)
    print("TABLE LIST")
    print("═" * 78)
    staging_tables = fetch_table_list(staging_url, staging_key)
    prod_tables = fetch_table_list(prod_url, prod_key)

    staging_only = staging_tables - prod_tables
    prod_only = prod_tables - staging_tables
    common = staging_tables & prod_tables

    if staging_only:
        print(f"⚠️  Staging-only tables: {sorted(staging_only)}")
    if prod_only:
        print(f"⚠️  Production-only tables: {sorted(prod_only)}")
    if not staging_only and not prod_only:
        print("✅ Identical table sets.")
    print()

    tables_to_check = [only_table] if only_table else sorted(common)

    for table in tables_to_check:
        if table not in common:
            print(f"⚠️  {table}: not present on both sides, skipping column/row check.")
            continue

        print("─" * 78)
        print(f"TABLE: {table}")
        print("─" * 78)

        try:
            s_sample = staging.table(table).select("*").limit(1).execute().data
            p_sample = prod.table(table).select("*").limit(1).execute().data
        except Exception as e:
            print(f"  ⚠️  Failed to sample columns: {e}")
            continue

        s_cols = set(s_sample[0].keys()) if s_sample else None
        p_cols = set(p_sample[0].keys()) if p_sample else None

        if s_cols is None or p_cols is None:
            print("  (one or both sides have 0 rows — column check needs a non-empty sample; skipped)")
        else:
            s_only_cols = s_cols - p_cols
            p_only_cols = p_cols - s_cols
            if s_only_cols:
                print(f"  ⚠️  Columns only on staging: {sorted(s_only_cols)}")
            if p_only_cols:
                print(f"  ⚠️  Columns only on production: {sorted(p_only_cols)}")
            if not s_only_cols and not p_only_cols:
                print(f"  ✅ Same columns ({len(s_cols)}).")

        try:
            s_count = staging.table(table).select("id", count="exact").execute().count
            p_count = prod.table(table).select("id", count="exact").execute().count
        except Exception as e:
            print(f"  ⚠️  Failed to count rows (no 'id' column?): {e}")
            continue

        count_marker = "✅" if s_count == p_count else "⚠️ "
        print(f"  {count_marker} Row count — staging: {s_count}, production: {p_count}")

        if table in SKIP_ROW_DIFF:
            print(f"  (skipping row-by-row diff — {SKIP_ROW_DIFF[table]})")
            print()
            continue

        if max(s_count, p_count) > ROW_DIFF_THRESHOLD:
            print(f"  (skipping row-by-row diff — over {ROW_DIFF_THRESHOLD} rows; "
                  f"use --table {table} to focus on just this one if needed)")
            print()
            continue

        key_col = NATURAL_KEY.get(table, "id")
        s_rows = {r[key_col]: r for r in staging.table(table).select("*").execute().data}
        p_rows = {r[key_col]: r for r in prod.table(table).select("*").execute().data}

        only_staging_keys = sorted(set(s_rows) - set(p_rows))
        only_prod_keys = sorted(set(p_rows) - set(s_rows))
        common_keys = set(s_rows) & set(p_rows)

        if only_staging_keys:
            print(f"  Rows only on staging ({key_col}): {only_staging_keys}")
        if only_prod_keys:
            print(f"  Rows only on production ({key_col}): {only_prod_keys}")

        # `id` itself is never a meaningful content diff when it's not the
        # identity column being matched on (e.g. matching by `key`, the two
        # sides' surrogate `id`s legitimately differ) — exclude it too.
        ignore_cols = {"updated_at"} | ({"id"} if key_col != "id" else set())

        differing = []
        for k in sorted(common_keys):
            s_row, p_row = s_rows[k], p_rows[k]
            shared_keys = set(s_row) & set(p_row)
            diff_cols = {
                col: (s_row[col], p_row[col])
                for col in shared_keys
                if col not in ignore_cols and s_row[col] != p_row[col]
            }
            if diff_cols:
                differing.append((k, diff_cols))

        if differing:
            print(f"  ⚠️  {len(differing)} row(s) with differing content (excluding updated_at):")
            for k, diff_cols in differing:
                print(f"    {key_col}={k}: {diff_cols}")
        elif not only_staging_keys and not only_prod_keys:
            print(f"  ✅ All {len(common_keys)} shared rows are identical.")

        print()


if __name__ == "__main__":
    main()
