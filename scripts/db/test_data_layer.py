"""
Data layer integration tests for the Pahlevani DB.

Mirrors every function in:
  - TrainingSessionRemoteDataSourceImpl  (fetchTrainingSessionsTable,
                                          fetchExerciseTable,
                                          fetchTrainingSessionItemTable,
                                          fetchMovementTable)
  - SupabaseVersionGateRepository        (fetchConfig)

Each test:
  1. Runs the same SQL the Dart function would (supabase-py / PostgREST translates
     .select() to SELECT *; we do the same directly via psycopg2).
  2. Parses every returned row using the exact field-access pattern from the
     corresponding Dart fromJson() — fails if a field is missing or has an
     incompatible type.
  3. Verifies any non-nullable contract the Dart code assumes (e.g. 'id' is never
     null, 'repetitions' is always an int).

Run via:  scripts/test_migration.sh  (do not call directly in normal workflow)
Direct:   python scripts/db/test_data_layer.py "postgresql://postgres:pw@localhost:54399/postgres"
"""

from __future__ import annotations

import sys
from typing import Any
import psycopg2
from psycopg2 import sql as psql


# ─── helpers ─────────────────────────────────────────────────────────────────

def _rows(cur: psycopg2.cursor, table: str) -> list[dict[str, Any]]:
    """SELECT * from public.<table>, return list of column-keyed dicts."""
    cur.execute(psql.SQL("SELECT * FROM public.{}").format(psql.Identifier(table)))
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, row)) for row in cur.fetchall()]


def _require(row: dict, field: str, expected_type: type) -> None:
    """Assert field is present and has a compatible Python type (None = nullable)."""
    assert field in row, f"Missing field '{field}' in row: {list(row.keys())}"
    v = row[field]
    if v is not None:
        assert isinstance(v, expected_type), (
            f"Field '{field}' expected {expected_type.__name__}, got {type(v).__name__} = {v!r}"
        )


# ─── per-function tests ───────────────────────────────────────────────────────

def test_fetch_training_sessions(cur: psycopg2.cursor) -> None:
    """
    Dart: TrainingSessionRemoteDataSourceImpl.fetchTrainingSessionsTable()
    DTO:  TrainingSessionRow.fromJson()
    """
    rows = _rows(cur, "training_session")
    assert rows, "training_session returned no rows — seed data missing?"
    for row in rows:
        # fromJson: json['id'] as int? ?? 1
        _require(row, "id", int)
        assert row["id"] is not None, "training_session.id must not be NULL"
        # fromJson: json['title'] as String? ?? 'Unknown TrainingSession'
        _require(row, "title", str)
        # nullable
        _require(row, "title_fa", str)
        _require(row, "description", str)
        _require(row, "difficulty", int)
        _require(row, "is_user_created", bool)
        # created_at: DateTime.tryParse — just needs to be present
        assert "created_at" in row, "training_session.created_at column missing"


def test_fetch_exercises(cur: psycopg2.cursor) -> None:
    """
    Dart: TrainingSessionRemoteDataSourceImpl.fetchExerciseTable()
    DTO:  ExerciseRow.fromJson()
    """
    rows = _rows(cur, "exercise")
    assert rows, "exercise returned no rows — seed data missing?"
    for row in rows:
        # fromJson: (m['id'] as num).toInt()
        _require(row, "id", int)
        assert row["id"] is not None, "exercise.id must not be NULL"
        # nullable FK
        _require(row, "movement_id", int)
        # nullable strings
        _require(row, "name", str)
        _require(row, "title_fa", str)
        _require(row, "gloss", str)
        _require(row, "author", str)
        _require(row, "type", str)
        _require(row, "url", str)
        # fromJson: (m['repetitions'] as num?)?.toInt() ?? 0  — NOT NULL in schema
        _require(row, "repetitions", int)
        assert row["repetitions"] is not None, "exercise.repetitions must not be NULL"
        # nullable
        _require(row, "duration_seconds", int)
        _require(row, "media_type", str)
        _require(row, "media_src", str)
        _require(row, "media_poster", str)


def test_fetch_training_session_items(cur: psycopg2.cursor) -> None:
    """
    Dart: TrainingSessionRemoteDataSourceImpl.fetchTrainingSessionItemTable()
    DTO:  TrainingItemRow.fromJson()
    """
    rows = _rows(cur, "training_session_item")
    assert rows, "training_session_item returned no rows — seed data missing?"
    for row in rows:
        # fromJson: (json['training_session_id'] as num).toInt()  — NOT NULL
        _require(row, "training_session_id", int)
        assert row["training_session_id"] is not None, "training_session_item.training_session_id must not be NULL"
        # fromJson: (json['exercise_id'] as num).toInt()  — NOT NULL
        _require(row, "exercise_id", int)
        assert row["exercise_id"] is not None, "training_session_item.exercise_id must not be NULL"
        # fromJson: (json['position'] as num).toInt()  — NOT NULL
        _require(row, "position", int)
        assert row["position"] is not None, "training_session_item.position must not be NULL"
        # fromJson: (json['reps_to_do'] as num?)?.toInt() ?? 1
        _require(row, "reps_to_do", int)


def test_fetch_movements(cur: psycopg2.cursor) -> None:
    """
    Dart: TrainingSessionRemoteDataSourceImpl.fetchMovementTable()
    DTO:  MovementRow.fromJson()

    The Dart implementation returns [] if the table doesn't exist (graceful
    degradation) — so we also skip without failure if the table is absent.
    """
    try:
        rows = _rows(cur, "movement")
    except psycopg2.errors.UndefinedTable:
        # Movement table not yet in this schema state — matches Dart's fail-open behaviour.
        return

    for row in rows:
        # fromJson: (m['id'] as num).toInt()  — NOT NULL
        _require(row, "id", int)
        assert row["id"] is not None, "movement.id must not be NULL"
        # fromJson: m['name'] as String? ?? 'Movement ${m['id']}'
        _require(row, "name", str)
        # nullable
        _require(row, "title_fa", str)
        _require(row, "gloss", str)
        _require(row, "type", str)
        # fromJson: m['media_type'] as String? ?? 'none'  — schema enforces NOT NULL DEFAULT 'none'
        _require(row, "media_type", str)
        _require(row, "media_src", str)
        _require(row, "media_poster", str)


def test_version_gate_fetch_config(cur: psycopg2.cursor) -> None:
    """
    Dart: SupabaseVersionGateRepository.fetchConfig()
    The repository calls .select().eq('id', 1).single() — errors if row absent.

    If app_release_gate doesn't exist yet (pre-migration), skip gracefully.
    """
    try:
        cur.execute(
            "SELECT * FROM public.app_release_gate WHERE id = 1"
        )
    except psycopg2.errors.UndefinedTable:
        # Pre-migration state — version gate not yet installed. Skip.
        return

    row = cur.fetchone()
    assert row is not None, (
        "app_release_gate has no row with id=1 — migration should have inserted it"
    )
    cols = [d[0] for d in cur.description]
    d = dict(zip(cols, row))

    # fetchConfig() reads exactly these three fields:
    _require(d, "min_supported_build_number", int)
    assert d["min_supported_build_number"] is not None
    _require(d, "update_message", str)
    assert d["update_message"] is not None
    _require(d, "force_update", bool)
    assert d["force_update"] is not None


# ─── runner ───────────────────────────────────────────────────────────────────

_TESTS = [
    ("fetchTrainingSessionsTable()", test_fetch_training_sessions),
    ("fetchExerciseTable()",          test_fetch_exercises),
    ("fetchTrainingSessionItemTable()", test_fetch_training_session_items),
    ("fetchMovementTable()",           test_fetch_movements),
    ("VersionGateRepository.fetchConfig()", test_version_gate_fetch_config),
]


def run(dsn: str) -> bool:
    """Run all data layer tests. Returns True if all passed."""
    conn = psycopg2.connect(dsn)
    try:
        passed = failed = 0
        for name, fn in _TESTS:
            # Each test runs in its own transaction so a failure in one test
            # (which raises a DB exception and aborts the transaction) cannot
            # poison subsequent tests. `with conn:` commits on success and
            # rolls back on any exception, restoring a clean connection state.
            try:
                with conn:
                    with conn.cursor() as cur:
                        fn(cur)
                print(f"  ✅  {name}")
                passed += 1
            except AssertionError as exc:
                print(f"  ❌  {name}")
                print(f"      {exc}")
                failed += 1
            except Exception as exc:
                print(f"  ❌  {name}  [unexpected: {type(exc).__name__}: {exc}]")
                failed += 1
    finally:
        conn.close()
    return failed == 0


if __name__ == "__main__":
    dsn = (
        sys.argv[1]
        if len(sys.argv) > 1
        else "postgresql://postgres:pahlevani_test@localhost:54399/postgres"
    )
    ok = run(dsn)
    sys.exit(0 if ok else 1)
