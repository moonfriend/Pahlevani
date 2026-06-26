"""
Shared assertion helpers for DB migration tests.

Each function raises AssertionError with a descriptive message on failure
so the caller can catch and report cleanly.
"""

from __future__ import annotations
from typing import Sequence
import psycopg2


def assert_table_exists(cur: "psycopg2.cursor", table: str) -> None:
    cur.execute(
        """
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = %s
        """,
        (table,),
    )
    assert cur.fetchone(), f"Table 'public.{table}' does not exist"


def assert_column_exists(cur: "psycopg2.cursor", table: str, column: str) -> None:
    cur.execute(
        """
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = %s AND column_name = %s
        """,
        (table, column),
    )
    assert cur.fetchone(), f"Column '{table}.{column}' does not exist"


def assert_columns_exist(
    cur: "psycopg2.cursor", table: str, columns: Sequence[str]
) -> None:
    for col in columns:
        assert_column_exists(cur, table, col)


def assert_query_succeeds(cur: "psycopg2.cursor", sql: str, label: str) -> None:
    """Run a SELECT and assert it executes without raising."""
    try:
        cur.execute(sql)
    except Exception as exc:
        raise AssertionError(f"Query failed [{label}]: {exc}") from exc


def assert_row_count(
    cur: "psycopg2.cursor", table: str, expected: int, where: str = ""
) -> None:
    where_clause = f"WHERE {where}" if where else ""
    cur.execute(f"SELECT COUNT(*) FROM public.{table} {where_clause}")
    actual = cur.fetchone()[0]
    assert actual == expected, (
        f"public.{table} ({where or 'all rows'}): expected {expected} rows, got {actual}"
    )


def assert_column_not_null_constraint(
    cur: "psycopg2.cursor", table: str, column: str
) -> None:
    cur.execute(
        """
        SELECT is_nullable FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = %s AND column_name = %s
        """,
        (table, column),
    )
    row = cur.fetchone()
    assert row, f"Column '{table}.{column}' not found"
    assert row[0] == "NO", f"Column '{table}.{column}' should be NOT NULL but is nullable"
