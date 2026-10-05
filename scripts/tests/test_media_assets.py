"""Unit tests for scripts/media_assets.py (pure logic; no network, no DB).

Run:  cd scripts && uv run --with pytest pytest tests -q
"""

import pytest

from media_assets import (
    MediaAsset,
    MediaAssetError,
    REFERENCE_COLUMNS,
    build_integrity_report,
    collect_referenced_urls,
    record_media_asset,
)


# ── Minimal fake of the supabase-py query builder used by the module ──────────


class _FakeQuery:
    def __init__(self, db, table):
        self._db, self._table = db, table
        self._payload = None
        self._op = None
        self._columns = None

    def select(self, columns):
        self._op, self._columns = "select", columns
        return self

    def upsert(self, payload, on_conflict=None):
        self._op, self._payload = "upsert", payload
        return self

    def execute(self):
        if self._table in self._db.missing_tables:
            raise RuntimeError(f'relation "public.{self._table}" does not exist')
        if self._op == "upsert":
            self._db.upserts.setdefault(self._table, []).append(self._payload)
            return _Result([self._payload])
        rows = self._db.rows.get(self._table, [])
        return _Result([{self._columns: r.get(self._columns)} for r in rows])


class _Result:
    def __init__(self, data):
        self.data = data


class FakeDb:
    def __init__(self, rows=None, missing_tables=()):
        self.rows = rows or {}
        self.missing_tables = set(missing_tables)
        self.upserts = {}

    def table(self, name):
        return _FakeQuery(self, name)


# ── record_media_asset ────────────────────────────────────────────────────────


def test_record_media_asset_upserts_url_size_and_type():
    db = FakeDb()
    record_media_asset(
        db, MediaAsset("https://cdn/a.mp3", 1234, "audio/mpeg")
    )
    (row,) = db.upserts["media_asset"]
    assert row["url"] == "https://cdn/a.mp3"
    assert row["size_bytes"] == 1234
    assert row["content_type"] == "audio/mpeg"
    # A fresh upload is recorded, not yet re-verified by the integrity check.
    assert row["checked_at"] is None


def test_record_media_asset_rejects_a_non_positive_size():
    with pytest.raises(ValueError):
        record_media_asset(FakeDb(), MediaAsset("https://cdn/a.mp3", 0))


def test_record_media_asset_fails_loudly_when_the_table_is_missing():
    db = FakeDb(missing_tables={"media_asset"})
    with pytest.raises(MediaAssetError, match="0041"):
        record_media_asset(db, MediaAsset("https://cdn/a.mp3", 10))


# ── collect_referenced_urls ───────────────────────────────────────────────────


def test_collects_http_urls_from_every_reference_column_ignoring_blanks():
    db = FakeDb(
        rows={
            "movement_audio_track": [
                {"audio_url": "https://cdn/a.mp3"},
                {"audio_url": "https://cdn/a.mp3"},  # duplicate
            ],
            "movement": [
                {"media_src": "https://cdn/v.mp4", "media_poster": None},
                {"media_src": "", "media_poster": "https://cdn/p.jpg"},
            ],
            "movement_info": [{"video_url": "https://cdn/info.mp4"}],
            "video": [{"url": "https://cdn/v.mp4", "poster_url": "  "}],
            "path_node_item": [{"video_url": None}],
            "morshed": [{"photo_url": "not-a-url"}],
        }
    )
    assert collect_referenced_urls(db) == {
        "https://cdn/a.mp3",
        "https://cdn/v.mp4",
        "https://cdn/p.jpg",
        "https://cdn/info.mp4",
    }


def test_reference_columns_cover_every_media_column_in_the_schema():
    # Guards against a new media column being added without the integrity
    # check knowing about it — update both together.
    assert set(REFERENCE_COLUMNS) == {
        ("movement_audio_track", "audio_url"),
        ("movement", "media_src"),
        ("movement", "media_poster"),
        ("movement_info", "video_url"),
        ("video", "url"),
        ("video", "poster_url"),
        ("path_node_item", "video_url"),
        ("morshed", "photo_url"),
    }


# ── build_integrity_report ────────────────────────────────────────────────────


def test_report_classifies_each_url():
    report = build_integrity_report(
        referenced={
            "https://cdn/ok.mp3",
            "https://cdn/wrong.mp3",
            "https://cdn/norow.mp3",
            "https://cdn/gone.mp3",
        },
        recorded={
            "https://cdn/ok.mp3": 100,
            "https://cdn/wrong.mp3": 100,
            "https://cdn/gone.mp3": 100,
            "https://cdn/orphan.mp3": 5,  # recorded but referenced nowhere
        },
        actual={
            "https://cdn/ok.mp3": 100,
            "https://cdn/wrong.mp3": 250,
            "https://cdn/norow.mp3": 70,
            "https://cdn/gone.mp3": None,  # HEAD failed / not on R2
        },
    )
    assert report.ok == ["https://cdn/ok.mp3"]
    assert report.size_mismatches == [("https://cdn/wrong.mp3", 100, 250)]
    assert report.missing_rows == [("https://cdn/norow.mp3", 70)]
    assert report.unreachable == ["https://cdn/gone.mp3"]
    assert report.orphan_rows == ["https://cdn/orphan.mp3"]
    assert not report.is_clean


def test_report_is_clean_when_everything_matches():
    report = build_integrity_report(
        referenced={"https://cdn/a.mp3"},
        recorded={"https://cdn/a.mp3": 9},
        actual={"https://cdn/a.mp3": 9},
    )
    assert report.is_clean
    assert report.ok == ["https://cdn/a.mp3"]


def test_fixes_list_upserts_actual_sizes_for_missing_and_wrong_rows_only():
    report = build_integrity_report(
        referenced={"https://cdn/ok", "https://cdn/wrong", "https://cdn/norow"},
        recorded={"https://cdn/ok": 1, "https://cdn/wrong": 1},
        actual={"https://cdn/ok": 1, "https://cdn/wrong": 2, "https://cdn/norow": 3},
    )
    assert sorted(report.fixes()) == [
        MediaAsset("https://cdn/norow", 3),
        MediaAsset("https://cdn/wrong", 2),
    ]
