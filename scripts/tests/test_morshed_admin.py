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


# ── recording_reps ────────────────────────────────────────────────────────────

from morshed_admin import recording_reps  # noqa: E402

_TRACKS = [
    {"id": 1, "movement_type_id": 10, "morshed_id": 1, "repetitions_default": 20},
    {"id": 2, "movement_type_id": 10, "morshed_id": 2, "repetitions_default": 35},
    {"id": 3, "movement_type_id": 11, "morshed_id": 2, "repetitions_default": 12},
]


def test_recording_reps_uses_the_default_morsheds_recording():
    assert recording_reps(10, _TRACKS, default_morshed_id=2) == 35


def test_recording_reps_falls_back_to_the_first_recording_of_the_type():
    # Same rule as the app's resolveAudioTrack: no recording by the chosen
    # Morshed -> the first one recorded for that type.
    assert recording_reps(11, _TRACKS, default_morshed_id=1) == 12
    assert recording_reps(10, _TRACKS, default_morshed_id=None) == 20


def test_recording_reps_is_none_without_a_type_or_a_recording():
    assert recording_reps(None, _TRACKS, default_morshed_id=2) is None
    assert recording_reps(99, _TRACKS, default_morshed_id=2) is None


# ── default_recording ─────────────────────────────────────────────────────────

from morshed_admin import default_recording  # noqa: E402


def test_default_recording_returns_the_whole_chosen_track():
    # The session-length estimate needs the recording's duration too.
    assert default_recording(10, _TRACKS, default_morshed_id=2)["id"] == 2
    assert default_recording(11, _TRACKS, default_morshed_id=1)["id"] == 3


def test_default_recording_is_none_without_a_type_or_a_recording():
    assert default_recording(None, _TRACKS, default_morshed_id=2) is None
    assert default_recording(99, _TRACKS, default_morshed_id=2) is None
