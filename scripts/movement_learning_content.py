"""Learning content of a move: the model and pure logic behind the cues /
steps / variations fields in admin.py's Movements tab.

Kept apart from the Streamlit UI so it can be unit-tested
(scripts/tests/test_movement_learning_content.py). Mirrors the columns added
to `movement_info` by supabase/migrations/0042_movement_info_learning_content.sql
and what the app's MovementInfoRow DTO reads. English only — Farsi arrives
later through translation files.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Any, Iterable

# Matches the table's check constraint and the design's three cue lines.
MAX_CUES = 3


def lines_from_text(text: str | None) -> list[str]:
    """One entry per non-blank line, trimmed (cues and steps text areas)."""
    if not text:
        return []
    return [line.strip() for line in text.splitlines() if line.strip()]


def text_from_lines(lines: Iterable[str] | None) -> str:
    """The text-area value for a stored list."""
    return "\n".join(lines or [])


@dataclass(frozen=True)
class MoveVariation:
    """One step of the learning card's Lighter ↔ Harder selector."""

    name: str
    level: str | None = None
    reps: int | None = None

    def to_json(self) -> dict[str, Any]:
        return {"name": self.name, "level": self.level, "reps": self.reps}


def _clean_text(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    return value.strip() or None


def _clean_reps(value: Any) -> int | None:
    """data_editor gives floats, and NaN for an empty number cell."""
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, float):
        if math.isnan(value):
            return None
        value = int(value)
    if not isinstance(value, int):
        return None
    if value < 0:
        raise ValueError(f"Reps can't be negative (got {value}).")
    return value


def variations_from_rows(rows: Iterable[dict[str, Any]]) -> list[MoveVariation]:
    """Editor rows → variations, lightest first; rows without a name are
    dropped (that is how a row is deleted in the editor)."""
    variations = []
    for row in rows:
        name = _clean_text(row.get("name"))
        if name is None:
            continue
        variations.append(
            MoveVariation(
                name=name,
                level=_clean_text(row.get("level")),
                reps=_clean_reps(row.get("reps")),
            )
        )
    return variations


@dataclass(frozen=True)
class LearningContent:
    """The three learning-content columns of one `movement_info` row."""

    cues: list[str] = field(default_factory=list)
    steps: list[str] = field(default_factory=list)
    variations: list[MoveVariation] = field(default_factory=list)

    def validate(self) -> None:
        if len(self.cues) > MAX_CUES:
            raise ValueError(
                f"At most {MAX_CUES} cues (got {len(self.cues)}) — the player "
                "shows three lines."
            )

    def to_payload(self) -> dict[str, Any]:
        """Columns for a movement_info upsert."""
        self.validate()
        return {
            "cues": list(self.cues),
            "steps": list(self.steps),
            "variations": [v.to_json() for v in self.variations],
        }

    @classmethod
    def from_row(cls, row: dict[str, Any]) -> "LearningContent":
        """From a movement_info row; a row from before 0042 gives empty content."""
        return cls(
            cues=list(row.get("cues") or []),
            steps=list(row.get("steps") or []),
            variations=variations_from_rows(row.get("variations") or []),
        )
