"""Activation gate: the model and validation behind admin.py's Activation
tab — the locked screen's text (the single `activation_gate` row) and the
activations export for the monthly Patreon check.

Kept apart from the Streamlit UI so it can be unit-tested
(scripts/tests/test_activation_gate.py). Mirrors
supabase/migrations/0045_activation_gate.sql.
"""

from __future__ import annotations

import csv
import io
from dataclasses import dataclass
from datetime import date
from typing import Any


@dataclass(frozen=True)
class LockedScreen:
    message: str
    link_label: str
    link_url: str

    @classmethod
    def from_row(cls, row: dict[str, Any]) -> "LockedScreen":
        return cls(
            message=row.get("message") or "",
            link_label=row.get("link_label") or "Get your code on Patreon",
            link_url=row.get("link_url") or "",
        )

    def problems(self) -> list[str]:
        """Why this can't be saved (empty when it can) — the table's checks."""
        found = []
        if not self.message.strip():
            found.append("A message is needed.")
        if not self.link_url.strip().startswith("https://"):
            found.append("The link must start with https://.")
        return found

    def to_row(self) -> dict[str, Any]:
        return {
            "id": 1,
            "message": self.message.strip(),
            "link_label": self.link_label.strip() or "Get your code on Patreon",
            "link_url": self.link_url.strip(),
        }


@dataclass(frozen=True)
class TermsSetting:
    """The terms version users must have agreed to (migration 0049). Raising
    it asks every account to agree again, with a notice naming the date."""

    version: int
    updated_on: date

    # Before migration 0049 the row has no such columns: the app's own value.
    DEFAULT_VERSION = 2
    DEFAULT_UPDATED_ON = date(2026, 10, 25)

    @classmethod
    def from_row(cls, row: dict[str, Any]) -> "TermsSetting":
        updated = row.get("terms_updated_on")
        return cls(
            version=int(row.get("terms_version") or cls.DEFAULT_VERSION),
            updated_on=date.fromisoformat(updated) if updated else cls.DEFAULT_UPDATED_ON,
        )

    def problems(self, current: "TermsSetting") -> list[str]:
        """Why this can't be saved over [current] (empty when it can)."""
        if self.version < current.version:
            return [f"The version can only go up (it is {current.version} now)."]
        return []

    def asks_everyone_again(self, current: "TermsSetting") -> bool:
        return self.version > current.version

    def to_row(self) -> dict[str, Any]:
        return {"terms_version": self.version,
                "terms_updated_on": self.updated_on.isoformat()}


@dataclass(frozen=True)
class Activation:
    email: str
    code: str
    activated_at: str

    @classmethod
    def from_row(cls, row: dict[str, Any]) -> "Activation":
        return cls(
            email=row.get("email") or "",
            code=row.get("code") or "",
            activated_at=(row.get("activated_at") or "")[:19].replace("T", " "),
        )


def activations_csv(activations: list[Activation]) -> str:
    """email,code,activated_at — for comparing against Patreon's members."""
    out = io.StringIO()
    writer = csv.writer(out)
    writer.writerow(["email", "code", "activated_at"])
    for a in activations:
        writer.writerow([a.email, a.code, a.activated_at])
    return out.getvalue()
