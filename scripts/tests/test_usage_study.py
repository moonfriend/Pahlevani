"""Tests for usage_study.py: turning usage_timeline rows into a readable
per-tester diary (admin.py's "Usage study" tab).

Run: uv run --project scripts python -m unittest discover -s scripts/tests
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from usage_study import (  # noqa: E402
    UsageEventRow,
    describe,
    first_use_steps,
    group_visits,
    timeline_lines,
)


def row(seq, minute, event, screen="home", props=None, visit="v1", second=0):
    return {
        "visit_id": visit,
        "seq": seq,
        "occurred_at": f"2026-11-10T08:{minute:02d}:{second:02d}+00:00",
        "local_time": f"2026-11-10T09:{minute:02d}:{second:02d}",
        "screen": screen,
        "event": event,
        "props": props or {},
        "platform": "android",
        "app_version": "1.7.0+17",
    }


class DescribeTest(unittest.TestCase):
    def d(self, event, props, screen="home"):
        return describe(UsageEventRow.from_row(row(1, 0, event, screen, props)))

    def test_screens_and_tabs(self):
        self.assertEqual(
            self.d("nav.screen_viewed",
                   {"screen": "session_preview", "previous": "home", "via": "button"}),
            "→ session_preview (from home, button)")
        self.assertEqual(
            self.d("nav.screen_left",
                   {"screen": "home", "seconds": 12.5, "scroll_depth_pct": 40}),
            "← left home after 12.5 s, scrolled 40%")

    def test_login(self):
        self.assertEqual(
            self.d("auth.result",
                   {"mode": "sign_in", "ok": False, "error": "wrong_credentials"}),
            "sign_in failed: wrong_credentials")
        self.assertEqual(self.d("auth.result", {"mode": "sign_in", "ok": True}),
                         "sign_in ok")

    def test_move_ended(self):
        self.assertEqual(
            self.d("player.move_ended",
                   {"index": 2, "movement_id": 31, "played_s": 12.4,
                    "planned_s": 30, "reached_pct": 41, "how": "next"},
                   screen="player"),
            "move 3 (#31) ended by next after 12.4 s of 30 s (41%)")

    def test_dead_tap(self):
        self.assertEqual(
            self.d("ui.dead_tap", {"element": "player.rep_counter", "cell": "c3r7"}),
            "dead tap on player.rep_counter")
        self.assertEqual(self.d("ui.dead_tap", {"element": None, "cell": "c3r7"}),
                         "dead tap at c3r7")

    def test_unknown_events_show_their_props(self):
        self.assertEqual(self.d("player.muted", {"on": True}),
                         "player.muted on=True")


class VisitsTest(unittest.TestCase):
    def test_groups_by_visit_in_order(self):
        rows = [row(2, 1, "nav.screen_viewed", visit="v1",
                    props={"screen": "home", "previous": None, "via": "gate"}),
                row(1, 0, "app.opened", visit="v1", props={"start": "cold"}),
                row(1, 30, "app.opened", visit="v2", props={"start": "warm"})]
        visits = group_visits(rows)
        self.assertEqual([v.visit_id for v in visits], ["v1", "v2"])
        self.assertEqual([e.seq for e in visits[0].events], [1, 2])
        self.assertEqual(visits[0].seconds, 60)

    def test_lines_have_local_time_and_screen(self):
        visit = group_visits([row(1, 5, "home.announcement_tapped", second=7)])[0]
        self.assertEqual(timeline_lines(visit),
                         ["09:05:07  [home]  home.announcement_tapped"])


class FirstUseTest(unittest.TestCase):
    def test_steps_with_gaps(self):
        steps = first_use_steps({
            "first_seen": "2026-11-10T08:00:00+00:00",
            "splash_begin": "2026-11-10T08:00:06+00:00",
            "onboarding_done": None,
            "account_view": "2026-11-10T08:01:00+00:00",
        })
        self.assertEqual([s.label for s in steps][:3],
                         ["First seen", "Splash → Begin", "Onboarding done"])
        self.assertEqual(steps[1].seconds_after_previous, 6)
        self.assertIsNone(steps[2].at)
        self.assertEqual(steps[3].seconds_after_previous, 54,
                         "a missed step doesn't break the chain")


if __name__ == "__main__":
    unittest.main()
