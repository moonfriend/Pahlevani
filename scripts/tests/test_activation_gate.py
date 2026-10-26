"""Run: uv run --project scripts python -m unittest discover -s scripts/tests"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from datetime import date  # noqa: E402

from activation_gate import (  # noqa: E402
    Activation, LockedScreen, TermsSetting, activations_csv)


class TermsSettingTest(unittest.TestCase):
    def test_reads_the_row_and_defaults_before_migration_0049(self):
        self.assertEqual(
            TermsSetting.from_row({"terms_version": 3, "terms_updated_on": "2026-12-01"}),
            TermsSetting(3, date(2026, 12, 1)))
        self.assertEqual(TermsSetting.from_row({}), TermsSetting(2, date(2026, 10, 25)))

    def test_saves_only_its_own_columns(self):
        self.assertEqual(TermsSetting(3, date(2026, 12, 1)).to_row(),
                         {"terms_version": 3, "terms_updated_on": "2026-12-01"})

    def test_raising_the_version_asks_everyone_again(self):
        current = TermsSetting(2, date(2026, 10, 25))
        self.assertTrue(TermsSetting(3, date(2026, 12, 1)).asks_everyone_again(current))
        self.assertFalse(TermsSetting(2, date(2026, 11, 1)).asks_everyone_again(current))

    def test_the_version_never_goes_down(self):
        current = TermsSetting(3, date(2026, 12, 1))
        self.assertEqual(TermsSetting(2, date(2026, 12, 1)).problems(current),
                         ["The version can only go up (it is 3 now)."])
        self.assertEqual(TermsSetting(3, date(2026, 12, 2)).problems(current), [])


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
