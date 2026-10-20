"""Unit tests for scripts/movement_learning_content.py — the parsing behind
the Movements tab's cues / steps / variations fields (migration 0042).

Run from the repo root:
  uv run --project scripts python -m unittest discover -s scripts/tests
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from movement_learning_content import (  # noqa: E402
    MAX_CUES,
    LearningContent,
    MoveVariation,
    lines_from_text,
    text_from_lines,
    variations_from_rows,
)


class LinesFromTextTest(unittest.TestCase):
    def test_one_entry_per_non_blank_line_trimmed(self):
        self.assertEqual(
            lines_from_text("  Back straight \n\n Elbows in\n   \n"),
            ["Back straight", "Elbows in"],
        )

    def test_empty_or_none_is_empty(self):
        self.assertEqual(lines_from_text(""), [])
        self.assertEqual(lines_from_text(None), [])

    def test_round_trip_through_text(self):
        lines = ["One", "Two"]
        self.assertEqual(lines_from_text(text_from_lines(lines)), lines)
        self.assertEqual(text_from_lines(None), "")


class VariationsFromRowsTest(unittest.TestCase):
    def test_rows_become_variations_in_order(self):
        rows = [
            {"name": "Knee shena", "level": "EASIER", "reps": 12},
            {"name": "Shena", "level": "", "reps": None},
        ]
        self.assertEqual(
            variations_from_rows(rows),
            [
                MoveVariation(name="Knee shena", level="EASIER", reps=12),
                MoveVariation(name="Shena"),
            ],
        )

    def test_rows_without_a_name_are_dropped(self):
        rows = [{"name": "  ", "level": "X", "reps": 3}, {"name": None}]
        self.assertEqual(variations_from_rows(rows), [])

    def test_float_and_nan_reps(self):
        # st.data_editor hands back floats, and NaN for an empty number cell.
        rows = [
            {"name": "A", "reps": 12.0},
            {"name": "B", "reps": float("nan")},
        ]
        self.assertEqual(
            variations_from_rows(rows),
            [MoveVariation(name="A", reps=12), MoveVariation(name="B")],
        )

    def test_negative_reps_rejected(self):
        with self.assertRaises(ValueError):
            variations_from_rows([{"name": "A", "reps": -1}])


class LearningContentTest(unittest.TestCase):
    def test_payload_matches_the_table_columns(self):
        content = LearningContent(
            cues=["Back straight"],
            steps=["Lower slowly"],
            variations=[MoveVariation(name="Knee shena", level="EASIER", reps=12)],
        )
        self.assertEqual(
            content.to_payload(),
            {
                "cues": ["Back straight"],
                "steps": ["Lower slowly"],
                "variations": [
                    {"name": "Knee shena", "level": "EASIER", "reps": 12}
                ],
            },
        )

    def test_too_many_cues_rejected(self):
        with self.assertRaises(ValueError):
            LearningContent(cues=["a"] * (MAX_CUES + 1)).validate()

    def test_from_row_tolerates_a_row_before_0042(self):
        content = LearningContent.from_row({"movement_id": 1, "description": "x"})
        self.assertEqual(content, LearningContent())

    def test_from_row_reads_the_columns(self):
        content = LearningContent.from_row(
            {
                "cues": ["A"],
                "steps": ["B"],
                "variations": [{"name": "V", "level": None, "reps": 4}],
            }
        )
        self.assertEqual(
            content,
            LearningContent(
                cues=["A"], steps=["B"], variations=[MoveVariation("V", None, 4)]
            ),
        )


if __name__ == "__main__":
    unittest.main()
