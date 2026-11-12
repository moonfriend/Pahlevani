"""Usage study: the model behind admin.py's "Usage study" tab.

Turns rows of the `usage_timeline` view (supabase/migrations/0052) into a
readable diary per tester — visits, one line per event — and the first-use
steps of `usage_rq3_first_use`. Kept apart from the Streamlit UI so it can
be unit-tested (scripts/tests/test_usage_study.py). Event names and props
are documented in docs/usage_study/event_catalogue.md.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Callable


def _parse(value: str | None) -> datetime | None:
    return None if value is None else datetime.fromisoformat(value)


@dataclass(frozen=True)
class UsageEventRow:
    visit_id: str
    seq: int
    occurred_at: datetime
    local_time: datetime
    screen: str | None
    event: str
    props: dict[str, Any]

    @classmethod
    def from_row(cls, row: dict[str, Any]) -> "UsageEventRow":
        occurred = _parse(row["occurred_at"])
        assert occurred is not None
        return cls(
            visit_id=row["visit_id"],
            seq=int(row["seq"]),
            occurred_at=occurred,
            local_time=_parse(row.get("local_time")) or occurred,
            screen=row.get("screen"),
            event=row["event"],
            props=row.get("props") or {},
        )


@dataclass(frozen=True)
class Visit:
    visit_id: str
    events: list[UsageEventRow] = field(default_factory=list)

    @property
    def started(self) -> datetime:
        return self.events[0].local_time

    @property
    def seconds(self) -> int:
        return int((self.events[-1].occurred_at
                    - self.events[0].occurred_at).total_seconds())


def group_visits(rows: list[dict[str, Any]]) -> list[Visit]:
    """Rows → visits in time order, each with its events in `seq` order."""
    by_visit: dict[str, list[UsageEventRow]] = {}
    for event in map(UsageEventRow.from_row, rows):
        by_visit.setdefault(event.visit_id, []).append(event)
    visits = [Visit(visit_id, sorted(events, key=lambda e: e.seq))
              for visit_id, events in by_visit.items()]
    return sorted(visits, key=lambda v: v.events[0].occurred_at)


def _move(p: dict[str, Any]) -> str:
    return f"move {int(p.get('index', 0)) + 1} (#{p.get('movement_id')})"


def _move_ended(p: dict[str, Any]) -> str:
    planned = p.get("planned_s")
    of = "" if planned is None else f" of {planned:g} s ({p.get('reached_pct')}%)"
    return f"{_move(p)} ended by {p.get('how')} after {p.get('played_s'):g} s{of}"


def _screen_left(p: dict[str, Any]) -> str:
    depth = p.get("scroll_depth_pct")
    scrolled = "" if depth is None else f", scrolled {depth}%"
    return f"← left {p.get('screen')} after {p.get('seconds'):g} s{scrolled}"


def _auth_result(p: dict[str, Any]) -> str:
    if p.get("ok"):
        return f"{p.get('mode')} ok"
    return f"{p.get('mode')} failed: {p.get('error')}"


def _dead_tap(p: dict[str, Any]) -> str:
    element = p.get("element")
    return f"dead tap on {element}" if element else f"dead tap at {p.get('cell')}"


_DESCRIBERS: dict[str, Callable[[dict[str, Any]], str]] = {
    "app.opened": lambda p: f"opened the app ({p.get('start')}, "
                            f"{p.get('device_class')}, {p.get('network')})",
    "app.backgrounded": lambda p: f"app to background after {p.get('visit_s')} s",
    "app.foregrounded": lambda p: f"back after {p.get('away_s')} s away",
    "nav.screen_viewed": lambda p: f"→ {p.get('screen')} "
                                   f"(from {p.get('previous') or 'start'}, {p.get('via')})",
    "nav.screen_left": _screen_left,
    "nav.tab_selected": lambda p: f"tab {p.get('from')} → {p.get('to')}"
                                  + (" (again)" if p.get("reselected") else ""),
    "nav.back": lambda p: f"back ({p.get('kind')}) from {p.get('from')}",
    "nav.link_opened": lambda p: f"opened link {p.get('link')} ({p.get('url_host')})",
    "auth.submit": lambda p: f"{p.get('mode')} submit #{p.get('attempt')} after "
                             f"{p.get('seconds_on_screen')} s, "
                             f"{p.get('corrections')} corrections",
    "auth.result": _auth_result,
    "access.code_entered": lambda p: f"code try #{p.get('attempt')}: {p.get('result')}",
    "session.previewed": lambda p: f"previewed session {p.get('session_id')} "
                                   f"(from {p.get('source')})",
    "preview.move_opened": lambda p: f"opened {_move({'index': p.get('position'), 'movement_id': p.get('movement_id')})} in the preview",
    "preview.left": lambda p: f"left the preview by {p.get('how')} after "
                              f"{p.get('seconds')} s, {p.get('moves_opened')} moves opened",
    "session.started": lambda p: f"started session {p.get('session_id')} "
                                 f"in {p.get('mode')} mode",
    "session.completed": lambda p: f"completed session {p.get('session_id')} "
                                   f"({p.get('played_s')} s played)",
    "session.abandoned": lambda p: f"left session {p.get('session_id')} at move "
                                   f"{int(p.get('last_index', 0)) + 1} ({p.get('how')})",
    "player.move_reached": lambda p: f"→ {_move(p)}"
                                     + (" (waits for Go)" if p.get("waiting_for_go") else ""),
    "player.move_ended": _move_ended,
    "player.paused": lambda p: f"paused at {p.get('position_s')} s ({p.get('source')})",
    "player.resumed": lambda p: f"resumed ({p.get('source')})",
    "player.seek": lambda p: f"seek {p.get('from_s')} → {p.get('to_s')} s",
    "ui.dead_tap": _dead_tap,
    "ui.error_shown": lambda p: f"saw {p.get('kind')}: {p.get('message_key')}",
}


def describe(event: UsageEventRow) -> str:
    """One readable phrase for an event; unknown events show their props."""
    describer = _DESCRIBERS.get(event.event)
    if describer is not None:
        return describer(event.props)
    details = " ".join(f"{k}={v}" for k, v in event.props.items())
    return f"{event.event} {details}".strip()


def timeline_lines(visit: Visit) -> list[str]:
    """`09:05:07  [home]  …` — the diary lines of one visit."""
    return [f"{e.local_time:%H:%M:%S}  [{e.screen or '-'}]  {describe(e)}"
            for e in visit.events]


@dataclass(frozen=True)
class FirstUseStep:
    label: str
    at: datetime | None
    seconds_after_previous: int | None


FIRST_USE_COLUMNS: list[tuple[str, str]] = [
    ("first_seen", "First seen"),
    ("splash_begin", "Splash → Begin"),
    ("onboarding_done", "Onboarding done"),
    ("account_view", "Account screen"),
    ("signed_in", "Signed in"),
    ("consent_accepted", "Consent accepted"),
    ("activated", "Activated"),
    ("first_home", "First Home"),
    ("first_preview", "First preview"),
    ("first_session_started", "First session started"),
    ("first_session_completed", "First session completed"),
]


def first_use_steps(row: dict[str, Any]) -> list[FirstUseStep]:
    """The RQ3 funnel of one tester, with the time since the last step
    reached (missed steps are skipped when measuring)."""
    steps: list[FirstUseStep] = []
    last: datetime | None = None
    for column, label in FIRST_USE_COLUMNS:
        at = _parse(row.get(column))
        gap = None if at is None or last is None else int((at - last).total_seconds())
        steps.append(FirstUseStep(label, at, gap))
        if at is not None:
            last = at
    return steps


# The research-question views shown as tables, in tab order.
RQ_VIEWS: list[tuple[str, str, str]] = [
    ("Visits", "usage_visits", "One row per visit (30 min in the background ends one)."),
    ("RQ1 daily", "usage_rq1_daily", "Visits and time per tester per local day."),
    ("RQ1 hours", "usage_rq1_hours", "Visits by weekday (1 = Monday) and local hour."),
    ("RQ6 return", "usage_rq1_return", "Did each tester come back: next day, week 1, week 2."),
    ("RQ2 login", "usage_rq2_login", "Submits, failures, mode switches, time to get in."),
    ("RQ2 errors", "usage_rq2_login_errors", "Why logins failed."),
    ("RQ4 transitions", "usage_rq4_transitions", "Screen → screen moves."),
    ("RQ4 time", "usage_rq4_screen_time", "Time per screen, scroll depth, visits under 2 s."),
    ("RQ5 moves", "usage_rq5_moves", "Seconds played per move before people move on, and how."),
    ("RQ5 sessions", "usage_rq5_sessions", "Runs, completions, abandons, modes."),
    ("RQ5 drop-off", "usage_rq5_dropoff", "At which move sessions are left."),
    ("RQ5 preview", "usage_rq5_preview", "Previews that ended without Start."),
    ("Dead taps", "usage_dead_taps", "Taps on things that don't react."),
    ("Rage taps", "usage_rage_taps", "3+ dead taps on one spot within 2 s."),
]
