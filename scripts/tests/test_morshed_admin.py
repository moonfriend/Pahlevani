"""Unit tests for scripts/morshed_admin.py."""

import pytest

from morshed_admin import DefaultMorshedError, set_default_morshed


class _Q:
    def __init__(self, db, table):
        self.db, self.table, self.payload, self.filters = db, table, None, []

    def update(self, payload):
        self.payload = payload
        return self

    def eq(self, column, value):
        self.filters.append((column, value))
        return self

    def execute(self):
        if self.db.fail:
            raise RuntimeError('column "is_default" does not exist')
        self.db.calls.append((self.table, self.payload, tuple(self.filters)))
        return self


class FakeDb:
    def __init__(self, fail=False):
        self.calls, self.fail = [], fail

    def table(self, name):
        return _Q(self, name)


def test_clears_the_old_default_before_setting_the_new_one():
    # The DB allows at most one default (partial unique index), so the order
    # matters: clear first, then set.
    db = FakeDb()
    set_default_morshed(db, 7)
    assert db.calls == [
        ("morshed", {"is_default": False}, (("is_default", True),)),
        ("morshed", {"is_default": True}, (("id", 7),)),
    ]


def test_none_just_clears_the_default():
    db = FakeDb()
    set_default_morshed(db, None)
    assert db.calls == [
        ("morshed", {"is_default": False}, (("is_default", True),)),
    ]


def test_fails_loudly_with_a_migration_hint():
    with pytest.raises(DefaultMorshedError, match="0041"):
        set_default_morshed(FakeDb(fail=True), 7)
