"""Tests for the integrity script's run() flow (fake DB + fake HTTP)."""

import io
from datetime import datetime, timezone

from check_media_integrity import run
from test_media_assets import FakeDb, _Http, _Resp


class _SizedHttp:
    """HEAD returns a per-URL size; unknown URLs 404."""

    def __init__(self, sizes):
        self.sizes = sizes

    def head(self, url, allow_redirects, timeout):
        if url in self.sizes:
            return _Resp(200, {"Content-Length": str(self.sizes[url])})
        return _Resp(404, {})


NOW = datetime(2026, 10, 5, tzinfo=timezone.utc)


def _db():
    return FakeDb(rows={
        "movement_audio_track": [{"audio_url": "https://cdn/ok.mp3"},
                                 {"audio_url": "https://cdn/wrong.mp3"},
                                 {"audio_url": "https://cdn/new.mp3"}],
        "media_asset": [{"url": "https://cdn/ok.mp3", "size_bytes": 10},
                        {"url": "https://cdn/wrong.mp3", "size_bytes": 10}],
    })


HTTP = _SizedHttp({"https://cdn/ok.mp3": 10, "https://cdn/wrong.mp3": 20,
                   "https://cdn/new.mp3": 30})


def test_report_only_changes_nothing_and_fails_when_dirty():
    db, out = _db(), io.StringIO()
    code = run(db, HTTP, fix=False, now=NOW, out=out)
    assert code == 1
    assert "media_asset" not in db.upserts
    text = out.getvalue()
    assert "wrong.mp3" in text and "new.mp3" in text


def test_fix_writes_actual_sizes_and_stamps_everything_verified():
    db, out = _db(), io.StringIO()
    code = run(db, HTTP, fix=True, now=NOW, out=out)
    assert code == 0
    written = {r["url"]: r for r in db.upserts["media_asset"]}
    assert written["https://cdn/wrong.mp3"]["size_bytes"] == 20
    assert written["https://cdn/new.mp3"]["size_bytes"] == 30
    assert written["https://cdn/ok.mp3"]["size_bytes"] == 10
    assert all(r["checked_at"] == NOW.isoformat() for r in written.values())


def test_unreachable_files_keep_the_run_failing_even_with_fix():
    db = FakeDb(rows={"movement": [{"media_src": "https://cdn/gone.mp4",
                                    "media_poster": None}]})
    out = io.StringIO()
    assert run(db, _SizedHttp({}), fix=True, now=NOW, out=out) == 1
    assert "gone.mp4" in out.getvalue()
