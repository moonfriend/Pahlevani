"""
Phase A: Baseline schema assertions (state after 0001_initial_schema.sql).

Verifies the 4-table schema that the running app depends on, including the
exact column names the Flutter DTOs read and the SELECT queries the remote
data source issues. A failure here means 0001_initial_schema.sql has drifted
from production — sync it before running further migration tests.

Run via: scripts/test_migration.sh  (not directly)
Direct:  python scripts/db/test_baseline.py "postgresql://postgres:test@localhost:54399/postgres"
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


def run(dsn: str) -> None:
    with psycopg2.connect(dsn) as conn:
        conn.autocommit = True
        with conn.cursor() as cur:
            _test_movement(cur)
            _test_exercise(cur)
            _test_training_session(cur)
            _test_training_session_item(cur)
            _test_seed_data(cur)
            _test_app_queries(cur)


# ── movement ─────────────────────────────────────────────────────────────────

def _test_movement(cur: psycopg2.cursor) -> None:
    assert_table_exists(cur, "movement")
    assert_columns_exist(
        cur, "movement",
        ["id", "name", "title_fa", "gloss", "type", "media_type", "media_src", "media_poster"],
    )
    assert_column_not_null_constraint(cur, "movement", "name")
    assert_column_not_null_constraint(cur, "movement", "media_type")


# ── exercise ─────────────────────────────────────────────────────────────────

def _test_exercise(cur: psycopg2.cursor) -> None:
    assert_table_exists(cur, "exercise")
    # These are every field in ExerciseRow.fromJson — if any is missing the
    # app will silently drop data or throw a type-cast error at runtime.
    assert_columns_exist(
        cur, "exercise",
        [
            "id", "movement_id", "name", "title_fa", "gloss",
            "author", "type", "url", "repetitions", "duration_seconds",
            "media_type", "media_src", "media_poster",
        ],
    )
    assert_column_not_null_constraint(cur, "exercise", "repetitions")


# ── training_session ─────────────────────────────────────────────────────────

def _test_training_session(cur: psycopg2.cursor) -> None:
    assert_table_exists(cur, "training_session")
    # TrainingSessionRow.fromJson reads every one of these.
    assert_columns_exist(
        cur, "training_session",
        ["id", "title", "description", "difficulty", "title_fa", "is_user_created", "created_at"],
    )
    assert_column_not_null_constraint(cur, "training_session", "id")
    assert_column_not_null_constraint(cur, "training_session", "title")


# ── training_session_item ─────────────────────────────────────────────────────

def _test_training_session_item(cur: psycopg2.cursor) -> None:
    assert_table_exists(cur, "training_session_item")
    # TrainingItemRow.fromJson
    assert_columns_exist(
        cur, "training_session_item",
        ["training_session_id", "exercise_id", "position", "reps_to_do"],
    )
    assert_column_not_null_constraint(cur, "training_session_item", "training_session_id")
    assert_column_not_null_constraint(cur, "training_session_item", "exercise_id")
    assert_column_not_null_constraint(cur, "training_session_item", "position")
    assert_column_not_null_constraint(cur, "training_session_item", "reps_to_do")


# ── seed data integrity ───────────────────────────────────────────────────────

def _test_seed_data(cur: psycopg2.cursor) -> None:
    assert_row_count(cur, "movement", 2)
    assert_row_count(cur, "exercise", 2)
    assert_row_count(cur, "training_session", 2)
    assert_row_count(cur, "training_session_item", 3)


# ── app query patterns ────────────────────────────────────────────────────────

def _test_app_queries(cur: psycopg2.cursor) -> None:
    """Mirror the exact SELECT calls in TrainingSessionRemoteDataSourceImpl."""
    assert_query_succeeds(
        cur,
        "SELECT id, title, title_fa, description, difficulty, is_user_created, created_at "
        "FROM public.training_session",
        "fetchTrainingSessionsTable",
    )
    assert_query_succeeds(
        cur,
        "SELECT id, movement_id, name, title_fa, gloss, author, type, url, "
        "repetitions, duration_seconds, media_type, media_src, media_poster "
        "FROM public.exercise",
        "fetchExerciseTable",
    )
    assert_query_succeeds(
        cur,
        "SELECT training_session_id, exercise_id, position, reps_to_do "
        "FROM public.training_session_item "
        "ORDER BY training_session_id, position",
        "fetchTrainingSessionItemTable",
    )
    # movement is optional — the app returns [] on error — but it must SELECT-able
    assert_query_succeeds(
        cur,
        "SELECT id, name, title_fa, gloss, type, media_type, media_src, media_poster "
        "FROM public.movement",
        "fetchMovementTable",
    )
    # Joined view that admin.py uses (JOIN smoke-test)
    assert_query_succeeds(
        cur,
        "SELECT e.id, e.url, e.repetitions, m.name, m.title_fa "
        "FROM public.exercise e "
        "LEFT JOIN public.movement m ON m.id = e.movement_id",
        "exercise-movement join",
    )


# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    dsn = (
        sys.argv[1]
        if len(sys.argv) > 1
        else "postgresql://postgres:pahlevani_test@localhost:54399/postgres"
    )
    try:
        run(dsn)
        print("✅  Baseline schema: all assertions passed")
        sys.exit(0)
    except AssertionError as exc:
        print(f"❌  {exc}")
        sys.exit(1)
    except Exception as exc:
        print(f"❌  Unexpected error: {exc}")
        sys.exit(1)
