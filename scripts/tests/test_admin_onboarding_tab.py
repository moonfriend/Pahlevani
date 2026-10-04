"""Drives admin.py's Onboarding tab with Streamlit's AppTest against an
in-memory fake Supabase client — no network, no credentials.

Run from the repo root (needs the scripts venv for streamlit):
  uv run --project scripts python -m unittest discover -s scripts/tests
"""

import unittest

from streamlit.testing.v1 import AppTest


def _script():
    # Runs inside AppTest's own script context.
    import sys
    from pathlib import Path

    import streamlit as st

    sys.path.insert(0, str(Path.cwd() / "scripts"))
    import admin

    class _Query:
        def __init__(self, store, op, payload=None):
            self.store, self.op, self.payload, self.filters = store, op, payload, {}

        def select(self, *_):
            return self

        def order(self, *_):
            return self

        def eq(self, column, value):
            self.filters[column] = value
            return self

        def execute(self):
            rows = self.store["rows"]
            match = [r for r in rows
                     if all(r.get(k) == v for k, v in self.filters.items())]
            if self.op == "insert":
                row = {**self.payload, "id": max([r["id"] for r in rows] or [0]) + 1}
                rows.append(row)
            elif self.op == "update":
                for r in match:
                    r.update({k: v for k, v in self.payload.items()
                              if k != "updated_at"})
            elif self.op == "delete":
                self.store["rows"] = [r for r in rows if r not in match]
            data = sorted(self.store["rows"], key=lambda r: (r["position"], r["id"]))
            return type("Resp", (), {"data": data})()

    class _Table:
        def __init__(self, store):
            self.store = store

        def select(self, *_):
            return _Query(self.store, "select")

        def insert(self, payload):
            return _Query(self.store, "insert", payload)

        def update(self, payload):
            return _Query(self.store, "update", payload)

        def delete(self):
            return _Query(self.store, "delete")

    class _Client:
        def table(self, _name):
            return _Table(st.session_state.store)

    if "store" not in st.session_state:
        st.session_state.store = {"rows": [
            {"id": 1, "position": 1, "title_en": "Train with your morshed",
             "body_en": "b", "title_fa": None, "body_fa": None, "image_url": None,
             "builtin_image": "figure", "is_active": True},
            {"id": 2, "position": 2, "title_en": "Count what matters",
             "body_en": "b", "title_fa": None, "body_fa": None, "image_url": None,
             "builtin_image": "figure_alt", "is_active": False},
        ]}
    admin.get_client = lambda: _Client()
    admin.load_onboarding_cards.clear()
    admin.tab_onboarding()


def _titles(at):
    return [r["title_en"] for r in sorted(at.session_state.store["rows"],
                                          key=lambda r: (r["position"], r["id"]))]


class OnboardingTab(unittest.TestCase):
    def setUp(self):
        self.at = AppTest.from_function(_script, default_timeout=30)
        self.at.run()
        self.assertFalse(self.at.exception, self.at.exception)

    def test_shows_every_card_and_the_active_count(self):
        labels = [e.label for e in self.at.expander]
        self.assertEqual(labels, ["🟢 1. Train with your morshed",
                                  "⚪ 2. Count what matters"])
        self.assertEqual(self.at.metric[0].value, "1")

    def test_adding_a_card_puts_it_at_the_end(self):
        self.at.text_input(key="onb_new_title_en").input("Lay a tile every session")
        self.at.selectbox(key="onb_new_builtin").select("shamseh")
        next(b for b in self.at.button if b.label == "➕ Add card").click()
        self.at.run()

        self.assertEqual(_titles(self.at)[-1], "Lay a tile every session")
        new = self.at.session_state.store["rows"][-1]
        self.assertEqual(new["position"], 3)
        self.assertEqual(new["builtin_image"], "shamseh")
        self.assertTrue(new["is_active"])

    def test_a_card_without_a_title_is_rejected(self):
        next(b for b in self.at.button if b.label == "➕ Add card").click()
        self.at.run()
        self.assertEqual(len(self.at.session_state.store["rows"]), 2)
        self.assertTrue(any("English title" in e.value for e in self.at.error))

    def test_moving_a_card_up_reorders(self):
        self.at.button(key="onb_move_2_-1").click()
        self.at.run()
        self.assertEqual(_titles(self.at),
                         ["Count what matters", "Train with your morshed"])

    def test_delete_needs_confirmation(self):
        self.assertTrue(self.at.button(key="onb_del_1").disabled)
        self.at.checkbox(key="onb_del_confirm_1").check()
        self.at.run()
        self.at.button(key="onb_del_1").click()
        self.at.run()
        self.assertEqual(_titles(self.at), ["Count what matters"])


if __name__ == "__main__":
    unittest.main()
