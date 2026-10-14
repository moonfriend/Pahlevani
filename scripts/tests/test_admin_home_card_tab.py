"""Drives admin.py's Home card tab with Streamlit's AppTest against an
in-memory fake Supabase client — no network, no credentials.

Run from the repo root (needs the scripts venv for streamlit):
  uv run --project scripts python -m unittest discover -s scripts/tests
"""

import unittest

from streamlit.testing.v1 import AppTest


def _script():
    import sys
    from pathlib import Path

    import streamlit as st

    sys.path.insert(0, str(Path.cwd() / "scripts"))
    import admin

    class _Query:
        def __init__(self, store, payload=None):
            self.store, self.payload = store, payload

        def select(self, *_):
            return self

        def eq(self, *_):
            return self

        def execute(self):
            if self.payload is not None:
                self.store["row"] = dict(self.payload)
            data = [self.store["row"]] if self.store["row"] else []
            return type("Resp", (), {"data": data})()

    class _Table:
        def __init__(self, store):
            self.store = store

        def select(self, *_):
            return _Query(self.store)

        def upsert(self, payload):
            return _Query(self.store, payload)

    class _Client:
        def table(self, _name):
            return _Table(st.session_state.store)

    if "store" not in st.session_state:
        st.session_state.store = {"row": {
            "id": 1, "title": "How to get your meel",
            "description": "Make your own, order, or pre-order.",
            "url": "https://rahaavi.com", "is_active": True,
        }}
    admin.get_client = lambda: _Client()
    admin.load_home_announcement.clear()
    admin.tab_home_card()


class HomeCardTab(unittest.TestCase):
    def setUp(self):
        self.at = AppTest.from_function(_script, default_timeout=30)
        self.at.run()
        self.assertFalse(self.at.exception, self.at.exception)

    def test_shows_the_current_card(self):
        self.assertEqual(self.at.text_input(key="home_card_title").value,
                         "How to get your meel")

    def test_saving_a_new_link(self):
        self.at.text_input(key="home_card_url").input("https://rahaavi.com/meel")
        self.at.button(key="home_card_save").click()
        self.at.run()
        self.assertEqual(self.at.session_state.store["row"]["url"],
                         "https://rahaavi.com/meel")

    def test_a_non_https_link_cannot_be_saved(self):
        self.at.text_input(key="home_card_url").input("http://rahaavi.com")
        self.at.run()
        self.assertTrue(self.at.button(key="home_card_save").disabled)


if __name__ == "__main__":
    unittest.main()
