"""Drives admin.py's Usage study tab with Streamlit's AppTest against an
in-memory fake Supabase client — no network, no credentials.

Run from the repo root (needs the scripts venv for streamlit):
  uv run --project scripts python -m unittest discover -s scripts/tests
"""

import unittest

from streamlit.testing.v1 import AppTest


def _script():
    import sys
    from pathlib import Path

    sys.path.insert(0, str(Path.cwd() / "scripts"))
    import admin

    tables = {
        "profiles": [
            {"id": "u-a", "email": "ali@example.com", "created_at": "2026-11-01"},
            {"id": "u-b", "email": "sara@example.com", "created_at": "2026-11-02"},
        ],
        "usage_timeline": [
            {"user_id": "u-a", "visit_id": "v1", "seq": 1,
             "occurred_at": "2026-11-10T08:00:00+00:00",
             "local_time": "2026-11-10T09:00:00", "screen": "loading",
             "event": "app.opened",
             "props": {"start": "cold", "device_class": "phone", "network": "wifi"}},
            {"user_id": "u-a", "visit_id": "v1", "seq": 2,
             "occurred_at": "2026-11-10T08:00:30+00:00",
             "local_time": "2026-11-10T09:00:30", "screen": "home",
             "event": "ui.dead_tap",
             "props": {"element": "home.greeting", "cell": "c1r1"}},
        ],
        "usage_rq3_first_use": [
            {"user_id": "u-a", "first_seen": "2026-11-10T08:00:00+00:00"},
        ],
    }

    class _Query:
        def __init__(self, rows):
            self.rows = rows

        def select(self, *_):
            return self

        def eq(self, column, value):
            return _Query([r for r in self.rows if r.get(column) == value])

        def order(self, *_, **__):
            return self

        def limit(self, *_):
            return self

        def execute(self):
            return type("Resp", (), {"data": list(self.rows)})()

    class _Client:
        def table(self, name):
            return _Query(tables.get(name, []))

    admin.get_client = lambda: _Client()
    admin.load_profiles.clear()
    admin.tab_usage_study()


class UsageStudyTab(unittest.TestCase):
    def setUp(self):
        self.at = AppTest.from_function(_script, default_timeout=30)
        self.at.run()
        self.assertFalse(self.at.exception, self.at.exception)

    def test_lists_testers_by_email(self):
        options = self.at.selectbox(key="usage_user").options
        self.assertIn("ali@example.com", options)

    def test_shows_the_chosen_testers_diary(self):
        self.at.selectbox(key="usage_user").select("ali@example.com")
        self.at.run()
        diary = " ".join(c.value for c in self.at.code)
        self.assertIn("opened the app (cold, phone, wifi)", diary)
        self.assertIn("dead tap on home.greeting", diary)

    def test_a_tester_without_events_says_so(self):
        self.at.selectbox(key="usage_user").select("sara@example.com")
        self.at.run()
        self.assertTrue(any("No usage events" in i.value for i in self.at.info))


if __name__ == "__main__":
    unittest.main()
