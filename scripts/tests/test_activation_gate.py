"""Run: uv run --project scripts python -m unittest discover -s scripts/tests"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from activation_gate import Activation, LockedScreen, activations_csv  # noqa: E402


class LockedScreenTest(unittest.TestCase):
    def test_valid_text_saves_as_the_single_row(self):
        screen = LockedScreen(" Join us. ", "", " https://www.patreon.com/x ")
        self.assertEqual(screen.problems(), [])
        self.assertEqual(screen.to_row(), {
            "id": 1, "message": "Join us.",
            "link_label": "Get your code on Patreon",
            "link_url": "https://www.patreon.com/x",
        })

    def test_needs_a_message_and_an_https_link(self):
        self.assertEqual(LockedScreen(" ", "x", "http://x").problems(), [
            "A message is needed.", "The link must start with https://.",
        ])


class ActivationsCsvTest(unittest.TestCase):
    def test_exports_email_code_and_date(self):
        rows = [Activation.from_row({
            "email": "sara@example.com", "code": "ABC",
            "activated_at": "2026-10-14T12:30:00.123+00:00"})]
        self.assertEqual(
            activations_csv(rows).splitlines(),
            ["email,code,activated_at",
             "sara@example.com,ABC,2026-10-14 12:30:00"])


if __name__ == "__main__":
    unittest.main()
