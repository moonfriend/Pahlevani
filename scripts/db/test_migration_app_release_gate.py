"""
Phase B: Schema assertions after migration 0002_app_release_gate.sql.

Verifies that:
  1. The migration applied cleanly (idempotent CREATE TABLE IF NOT EXISTS).
  2. The app_release_gate table has the exact columns VersionGateRepository reads.
  3. The singleton row exists (INSERT ... ON CONFLICT DO NOTHING in the migration).
  4. The SELECT query VersionGateRepository.fetchConfig() issues succeeds.
  5. The baseline tables are untouched (migration is purely additive).

Run via: scripts/test_migration.sh  (not directly)
Direct:  python scripts/db/test_migration_0002.py "postgresql://postgres:test@localhost:54399/postgres"
"""

from __future__ import annotations
import sys
import psycopg2
from assertions import (
    assert_table_exists,
    assert_columns_exist,
    assert_query_succeeds,
    assert_row_count,
    assert_column_not_null_constraint,
)

# Re-run the full baseline to confirm the migration didn't touch existing tables.
import test_baseline


def run(dsn: str) -> None:
    with psycopg2.connect(dsn) as conn:
        conn.autocommit = True
        with conn.cursor() as cur:
            _test_release_gate_table(cur)
            _test_release_gate_seed(cur)
            _test_release_gate_queries(cur)
            _test_baseline_tables_intact(cur)


# ── app_release_gate table ─────────────────────────────────────────────────

def _test_release_gate_table(cur: psycopg2.cursor) -> None:
    assert_table_exists(cur, "app_release_gate")
    # Exact fields read by SupabaseVersionGateRepository.fetchConfig()
    assert_columns_exist(
        cur, "app_release_gate",
        ["id", "min_supported_build_number", "update_message", "force_update", "updated_at"],
    )
    assert_column_not_null_constraint(cur, "app_release_gate", "min_supported_build_number")
    assert_column_not_null_constraint(cur, "app_release_gate", "update_message")
    assert_column_not_null_constraint(cur, "app_release_gate", "force_update")
    assert_column_not_null_constraint(cur, "app_release_gate", "updated_at")


def _test_release_gate_seed(cur: psycopg2.cursor) -> None:
    # The migration inserts the singleton row (id=1) with safe defaults.
    assert_row_count(cur, "app_release_gate", 1)

    cur.execute(
        "SELECT min_supported_build_number, force_update FROM public.app_release_gate WHERE id = 1"
    )
    row = cur.fetchone()
    assert row is not None, "app_release_gate singleton row (id=1) missing"
    min_build, force = row
    assert min_build == 1, f"Expected default min_supported_build_number=1, got {min_build}"
    assert force is False, f"Expected default force_update=false, got {force}"


def _test_release_gate_queries(cur: psycopg2.cursor) -> None:
    # Mirror SupabaseVersionGateRepository.fetchConfig() exactly:
    # .from('app_release_gate').select().eq('id', 1).single()
    assert_query_succeeds(
        cur,
        "SELECT min_supported_build_number, update_message, force_update "
        "FROM public.app_release_gate WHERE id = 1",
        "VersionGateRepository.fetchConfig()",
    )


def _test_baseline_tables_intact(cur: psycopg2.cursor) -> None:
    """Guard: the migration must not have dropped or altered baseline tables."""
    test_baseline._test_movement(cur)
    test_baseline._test_exercise(cur)
    test_baseline._test_training_session(cur)
    test_baseline._test_training_session_item(cur)


# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    dsn = (
        sys.argv[1]
        if len(sys.argv) > 1
        else "postgresql://postgres:pahlevani_test@localhost:54399/postgres"
    )
    try:
        run(dsn)
        print("✅  Migration 0002 (app_release_gate): all assertions passed")
        sys.exit(0)
    except AssertionError as exc:
        print(f"❌  {exc}")
        sys.exit(1)
    except Exception as exc:
        print(f"❌  Unexpected error: {exc}")
        sys.exit(1)
