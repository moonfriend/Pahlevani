"""Unit tests for scripts/onboarding_cards.py (the admin Onboarding tab's logic).

Run from the repo root:  python3 -m unittest discover -s scripts/tests
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from onboarding_cards import (  # noqa: E402
    BUILTIN_IMAGES,
    OnboardingCard,
    move_patches,
    next_position,
    r2_key_for,
)


class OnboardingCardValidation(unittest.TestCase):
    def test_a_minimal_card_is_valid(self):
        card = OnboardingCard(title_en="Train with your morshed")
        self.assertEqual(card.builtin_image, "figure")
        self.assertTrue(card.is_active)

    def test_title_is_required(self):
        with self.assertRaises(ValueError):
            OnboardingCard(title_en="   ")

    def test_builtin_image_must_be_known(self):
        with self.assertRaises(ValueError):
            OnboardingCard(title_en="T", builtin_image="sunset")
        for name in BUILTIN_IMAGES:
            OnboardingCard(title_en="T", builtin_image=name)

    def test_image_url_must_be_https(self):
        with self.assertRaises(ValueError):
            OnboardingCard(title_en="T", image_url="ftp://example.com/a.png")
        with self.assertRaises(ValueError):
            OnboardingCard(title_en="T", image_url="javascript:alert(1)")
        OnboardingCard(title_en="T", image_url="https://pub.r2.dev/a.webp")


class RowMapping(unittest.TestCase):
    def test_to_row_trims_and_nulls_blank_optionals(self):
        row = OnboardingCard(
            title_en="  Count what matters ",
            body_en=" Log your reps. ",
            title_fa="  ",
            body_fa="",
            image_url="",
        ).to_row()
        self.assertEqual(row["title_en"], "Count what matters")
        self.assertEqual(row["body_en"], "Log your reps.")
        self.assertIsNone(row["title_fa"])
        self.assertIsNone(row["body_fa"])
        self.assertIsNone(row["image_url"])
        self.assertNotIn("id", row, "the database assigns ids")

    def test_from_row_round_trips(self):
        row = {
            "id": 7,
            "position": 2,
            "title_en": "Lay a tile",
            "body_en": "Your shamseh grows.",
            "title_fa": "هر جلسه، یک کاشی",
            "body_fa": None,
            "image_url": None,
            "builtin_image": "shamseh",
            "is_active": False,
            "updated_at": "2026-10-04T10:00:00+00:00",
        }
        card = OnboardingCard.from_row(row)
        self.assertEqual(card.id, 7)
        self.assertFalse(card.is_active)
        out = card.to_row()
        for key in ("position", "title_en", "title_fa", "builtin_image",
                    "is_active"):
            self.assertEqual(out[key], row[key], key)


class Ordering(unittest.TestCase):
    def cards(self):
        return [
            OnboardingCard(id=1, position=1, title_en="A"),
            OnboardingCard(id=2, position=2, title_en="B"),
            OnboardingCard(id=3, position=5, title_en="C"),
        ]

    def test_next_position_goes_after_the_last(self):
        self.assertEqual(next_position(self.cards()), 6)
        self.assertEqual(next_position([]), 1)

    def test_moving_up_swaps_with_the_previous_card(self):
        self.assertEqual(move_patches(self.cards(), 2, -1),
                         [(3, 2), (2, 5)])

    def test_moving_down_swaps_with_the_next_card(self):
        self.assertEqual(move_patches(self.cards(), 0, +1),
                         [(1, 2), (2, 1)])

    def test_moving_past_either_end_does_nothing(self):
        self.assertEqual(move_patches(self.cards(), 0, -1), [])
        self.assertEqual(move_patches(self.cards(), 2, +1), [])

    def test_equal_positions_still_reorder(self):
        same = [OnboardingCard(id=1, position=0, title_en="A"),
                OnboardingCard(id=2, position=0, title_en="B")]
        self.assertEqual(move_patches(same, 1, -1), [(2, 0), (1, 1)])


class R2Keys(unittest.TestCase):
    def test_key_is_slugged_under_the_onboarding_prefix(self):
        key = r2_key_for("Count what matters!", "Photo One.PNG", b"abc")
        self.assertTrue(key.startswith("images/onboarding/count_what_matters-"))
        self.assertTrue(key.endswith(".png"))

    def test_different_content_gets_a_different_key(self):
        # A changed image must not be served from a stale CDN/app cache.
        a = r2_key_for("T", "x.webp", b"one")
        b = r2_key_for("T", "x.webp", b"two")
        self.assertNotEqual(a, b)

    def test_only_image_extensions_are_allowed(self):
        with self.assertRaises(ValueError):
            r2_key_for("T", "script.html", b"<html>")


if __name__ == "__main__":
    unittest.main()
