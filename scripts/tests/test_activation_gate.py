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
        screen = LockedScreen(" Join us. ", "", " https://steady.page/x ")
        self.assertEqual(screen.problems(), [])
        self.assertEqual(screen.to_row(), {
            "id": 1, "message": "Join us.",
            "link_label": "Join on Steady",
            "link_url": "https://steady.page/x",
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
            ["email,source,code,activated_at,expires_at,steady_state",
             "sara@example.com,code,ABC,2026-10-14 12:30:00,,"])

    def test_steady_rows_show_their_end_date_and_state(self):
        a = Activation.from_row({
            "email": "mina@example.com", "code": None, "source": "steady",
            "activated_at": "2026-11-07T10:00:00+00:00",
            "expires_at": "2026-12-07T10:00:00+00:00",
            "steady_state": "active"})
        self.assertEqual((a.source, a.code, a.expires_at, a.steady_state),
                         ("steady", "", "2026-12-07 10:00:00", "active"))
        self.assertEqual(activations_csv([a]).splitlines()[1],
                         "mina@example.com,steady,,2026-11-07 10:00:00,"
                         "2026-12-07 10:00:00,active")

    def test_rows_from_before_0053_count_as_codes(self):
        a = Activation.from_row({"email": "x@example.com", "code": "C",
                                 "activated_at": "2026-10-01T00:00:00Z"})
        self.assertEqual((a.source, a.expires_at), ("code", ""))


if __name__ == "__main__":
    unittest.main()
