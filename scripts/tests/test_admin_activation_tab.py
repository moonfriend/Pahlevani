"""Drives admin.py's Activation tab with Streamlit's AppTest against an
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
        def __init__(self, store, table, payload=None):
            self.store, self.table, self.payload = store, table, payload

        def select(self, *_):
            return self

        def eq(self, *_):
            return self

        def order(self, *_):
            return self

        def execute(self):
            if self.payload is not None:
                self.store[self.table] = [dict(self.payload)]
            return type("Resp", (), {"data": list(self.store[self.table])})()

    class _Table:
        def __init__(self, store, name):
            self.store, self.name = store, name

        def select(self, *_):
            return _Query(self.store, self.name)

        def upsert(self, payload):
            return _Query(self.store, self.name, payload)

    class _Client:
        def table(self, name):
            return _Table(st.session_state.store, name)

    if "store" not in st.session_state:
        st.session_state.store = {
            "activation_gate": [{
                "id": 1, "message": "Join on Patreon.",
                "link_label": "Get your code on Patreon",
                "link_url": "https://www.patreon.com/",
            }],
            "activations": [{
                "email": "sara@example.com", "code": "ABC",
                "activated_at": "2026-10-14T12:30:00+00:00",
            }],
        }
    admin.get_client = lambda: _Client()
    admin.load_locked_screen.clear()
    admin.load_activations.clear()
    admin.tab_activation()


class ActivationTab(unittest.TestCase):
    def setUp(self):
        self.at = AppTest.from_function(_script, default_timeout=30)
        self.at.run()
        self.assertFalse(self.at.exception, self.at.exception)

    def test_lists_activations(self):
        self.assertIn("Activations (1)", [s.value for s in self.at.subheader])

    def test_saving_the_patreon_link(self):
        self.at.text_input(key="locked_link_url").input("https://www.patreon.com/rahaavi")
        self.at.button(key="locked_save").click()
        self.at.run()
        self.assertEqual(
            self.at.session_state.store["activation_gate"][0]["link_url"],
            "https://www.patreon.com/rahaavi")

    def test_a_non_https_link_cannot_be_saved(self):
        self.at.text_input(key="locked_link_url").input("www.patreon.com")
        self.at.run()
        self.assertTrue(self.at.button(key="locked_save").disabled)


if __name__ == "__main__":
    unittest.main()
