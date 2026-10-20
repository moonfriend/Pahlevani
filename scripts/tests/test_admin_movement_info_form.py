"""Drives admin.py's "Info page content" form (Movements tab) with
Streamlit's AppTest against an in-memory fake Supabase client — no network,
no credentials. Covers the learning content added by migration 0042.

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

    class _Upsert:
        def __init__(self, payload):
            self.payload = payload

        def execute(self):
            st.session_state.saved.append(self.payload)

    class _Table:
        def upsert(self, payload, on_conflict=None):
            return _Upsert(payload)

    class _Client:
        def table(self, _name):
            return _Table()

    if "saved" not in st.session_state:
        st.session_state.saved = []
    admin.get_client = lambda: _Client()
    admin.load_movement_info = type(
        "Cached",
        (),
        {
            "__call__": lambda self: {
                7: {
                    "movement_id": 7,
                    "description": "How to",
                    "cues": ["Back straight"],
                    "steps": ["Lower slowly"],
                    "variations": [
                        {"name": "Knee shena", "level": "EASIER", "reps": 12}
                    ],
                }
            },
            "clear": lambda self: None,
        },
    )()
    admin._render_movement_info_section(7)


class MovementInfoForm(unittest.TestCase):
    def setUp(self):
        self.at = AppTest.from_function(_script, default_timeout=30)
        self.at.run()
        self.assertFalse(self.at.exception, self.at.exception)

    def _area(self, label_start):
        return next(t for t in self.at.text_area if t.label.startswith(label_start))

    def _save(self):
        next(b for b in self.at.button if b.label == "💾 Save info").click()
        self.at.run()
        self.assertFalse(self.at.exception, self.at.exception)

    def test_prefills_the_stored_content(self):
        self.assertEqual(self._area("Pay attention to").value, "Back straight")
        self.assertEqual(self._area("Steps").value, "Lower slowly")

    def test_saving_writes_every_column(self):
        self._area("Pay attention to").input("Back straight\nElbows in")
        self._area("Steps").input("Hands under shoulders\n\nLower slowly")
        self._save()

        saved = self.at.session_state.saved[-1]
        self.assertEqual(saved["movement_id"], 7)
        self.assertEqual(saved["description"], "How to")
        self.assertEqual(saved["cues"], ["Back straight", "Elbows in"])
        self.assertEqual(saved["steps"], ["Hands under shoulders", "Lower slowly"])
        self.assertEqual(
            saved["variations"],
            [{"name": "Knee shena", "level": "EASIER", "reps": 12}],
        )

    def test_four_cues_are_refused_and_nothing_is_saved(self):
        self._area("Pay attention to").input("a\nb\nc\nd")
        self._save()
        self.assertEqual(self.at.session_state.saved, [])
        self.assertTrue(any("At most 3 cues" in e.value for e in self.at.error))


if __name__ == "__main__":
    unittest.main()
