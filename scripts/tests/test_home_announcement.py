"""Run: uv run --project scripts python -m unittest discover -s scripts/tests"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from home_announcement import HomeAnnouncement  # noqa: E402


class HomeAnnouncementTest(unittest.TestCase):
    def test_a_valid_card_saves_trimmed_as_the_single_row(self):
        card = HomeAnnouncement(" Meel ", " Order yours ", " https://rahaavi.com ")
        self.assertEqual(card.problems(), [])
        self.assertEqual(card.to_row(), {
            "id": 1, "title": "Meel", "description": "Order yours",
            "url": "https://rahaavi.com", "is_active": True,
        })

    def test_needs_a_title_and_an_https_link(self):
        card = HomeAnnouncement("  ", "", "http://rahaavi.com")
        self.assertEqual(card.problems(), [
            "A title is needed.", "The link must start with https://.",
        ])

    def test_reads_a_row(self):
        card = HomeAnnouncement.from_row(
            {"title": "T", "description": None, "url": "https://x.com",
             "is_active": False})
        self.assertEqual(card, HomeAnnouncement("T", "", "https://x.com", False))


if __name__ == "__main__":
    unittest.main()
