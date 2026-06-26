"""
Data layer integration tests for the Pahlevani DB.

Mirrors every function in:
  - TrainingSessionRemoteDataSourceImpl  (fetchTrainingSessionsTable,
                                          fetchExerciseTable,
                                          fetchTrainingSessionItemTable,
                                          fetchMovementTable)
  - SupabaseVersionGateRepository        (fetchConfig)

Each test:
  1. Runs the same SQL the Dart function issues (SELECT * via PostgREST = SELECT *).
  2. For each returned row, performs the same field-access pattern as the Dart
     fromJson() — required casts raise on wrong type; optional fields use .get()
     matching Dart's null-safe pattern.
  3. Fails if a non-optional field is missing or has an incompatible type.

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
    """Assert field is present and non-null with a compatible Python type."""
    assert field in row, f"Required field '{field}' missing from row keys: {sorted(row)}"
    v = row[field]
    assert v is not None, f"Required field '{field}' is NULL (expected {expected_type.__name__})"
    assert isinstance(v, expected_type), (
        f"Field '{field}' expected {expected_type.__name__}, got {type(v).__name__} = {v!r}"
    )


def _optional(row: dict, field: str, expected_type: type) -> None:
    """Assert field is present; if non-null, type must match. Missing key = OK."""
    v = row.get(field)
    if v is not None:
        assert isinstance(v, expected_type), (
            f"Field '{field}' expected {expected_type.__name__}, "
            f"got {type(v).__name__} = {v!r}"
        )


# ─── per-function tests ───────────────────────────────────────────────────────

def test_fetch_training_sessions(cur: psycopg2.cursor) -> None:
    """
    Dart: TrainingSessionRemoteDataSourceImpl.fetchTrainingSessionsTable()
    DTO:  TrainingSessionRow.fromJson()

    Production columns: id, title, description, difficulty, title_fa,
                        created_at, updated_at
    Note: is_user_created is NOT a server column — it's Hive-only for local sessions.
    """
    rows = _rows(cur, "training_session")
    assert rows, "training_session returned no rows — seed data missing?"
    for row in rows:
        _require(row, "id", int)                  # json['id'] as int? ?? 1
        _optional(row, "title", str)              # json['title'] as String?
        _optional(row, "description", str)
        _optional(row, "difficulty", int)
        _optional(row, "title_fa", str)
        # created_at / updated_at: DateTime.tryParse — just needs to not crash
        assert "created_at" in row or "updated_at" in row, \
            "training_session: expected at least one timestamp column"


def test_fetch_exercises(cur: psycopg2.cursor) -> None:
    """
    Dart: TrainingSessionRemoteDataSourceImpl.fetchExerciseTable()
    DTO:  ExerciseRow.fromJson()

    Production columns: id, movement_id, author, type, url,
                        repetitions, duration_seconds, updated_at
    Note: name/title_fa/gloss/media_* are on the movement table, not exercise.
    """
    rows = _rows(cur, "exercise")
    assert rows, "exercise returned no rows — seed data missing?"
    for row in rows:
        _require(row, "id", int)                  # (m['id'] as num).toInt() — hard cast
        _optional(row, "movement_id", int)
        _optional(row, "author", str)
        _optional(row, "type", str)
        _optional(row, "url", str)
        # (m['repetitions'] as num?)?.toInt() ?? 0 — optional but schema has NOT NULL
        assert "repetitions" in row, "exercise.repetitions column missing"
        _optional(row, "duration_seconds", int)


def test_fetch_training_session_items(cur: psycopg2.cursor) -> None:
    """
    Dart: TrainingSessionRemoteDataSourceImpl.fetchTrainingSessionItemTable()
    DTO:  TrainingItemRow.fromJson()

    Production columns: training_session_id, exercise_id, position, reps_to_do, updated_at
    """
    rows = _rows(cur, "training_session_item")
    assert rows, "training_session_item returned no rows — seed data missing?"
    for row in rows:
        _require(row, "training_session_id", int)   # hard cast in fromJson
        _require(row, "exercise_id", int)
        _require(row, "position", int)
        _optional(row, "reps_to_do", int)           # ?? 1 fallback


def test_fetch_movements(cur: psycopg2.cursor) -> None:
    """
    Dart: TrainingSessionRemoteDataSourceImpl.fetchMovementTable()
    DTO:  MovementRow.fromJson()

    Fails open in Dart (returns [] if table absent) — we mirror that here.
    Production columns: id, name, title_fa, gloss, type, media_type,
                        media_src, media_poster, updated_at
    """
    try:
        rows = _rows(cur, "movement")
    except psycopg2.errors.UndefinedTable:
        return  # pre-migration state — matches Dart's fail-open behaviour

    for row in rows:
        _require(row, "id", int)          # (m['id'] as num).toInt()
        _require(row, "name", str)        # m['name'] as String? ?? 'Movement ${id}'
        _optional(row, "title_fa", str)
        _optional(row, "gloss", str)
        _optional(row, "type", str)
        _optional(row, "media_type", str) # ?? 'none'
        _optional(row, "media_src", str)
        _optional(row, "media_poster", str)


def test_version_gate_fetch_config(cur: psycopg2.cursor) -> None:
    """
    Dart: SupabaseVersionGateRepository.fetchConfig()
    Queries app_release_gate WHERE id = 1 — skips if table not yet in schema.
    """
    try:
        cur.execute("SELECT * FROM public.app_release_gate WHERE id = 1")
    except psycopg2.errors.UndefinedTable:
        return  # pre-migration — migration 0002 not yet applied

    row_tuple = cur.fetchone()
    assert row_tuple is not None, (
        "app_release_gate: no row with id=1 — migration should have inserted it"
    )
    cols = [d[0] for d in cur.description]
    row = dict(zip(cols, row_tuple))

    _require(row, "min_supported_build_number", int)
    _require(row, "update_message", str)
    _require(row, "force_update", bool)


# ─── runner ───────────────────────────────────────────────────────────────────

_TESTS = [
    ("fetchTrainingSessionsTable()",    test_fetch_training_sessions),
    ("fetchExerciseTable()",            test_fetch_exercises),
    ("fetchTrainingSessionItemTable()", test_fetch_training_session_items),
    ("fetchMovementTable()",            test_fetch_movements),
    ("VersionGateRepository.fetchConfig()", test_version_gate_fetch_config),
]


def run(dsn: str) -> bool:
    conn = psycopg2.connect(dsn)
    try:
        passed = failed = 0
        for name, fn in _TESTS:
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
                print(f"  ❌  {name}  [{type(exc).__name__}: {exc}]")
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
    sys.exit(0 if run(dsn) else 1)
