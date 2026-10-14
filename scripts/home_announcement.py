"""Home card: the model and validation behind admin.py's "Home card" tab.

Kept apart from the Streamlit UI so it can be unit-tested
(scripts/tests/test_home_announcement.py). Mirrors the single-row
`home_announcement` table (supabase/migrations/0044_home_announcement.sql)
and what the app's AnnouncementRepositoryImpl reads.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class HomeAnnouncement:
    title: str
    description: str
    url: str
    is_active: bool = True

    @classmethod
    def from_row(cls, row: dict[str, Any]) -> "HomeAnnouncement":
        return cls(
            title=row.get("title") or "",
            description=row.get("description") or "",
            url=row.get("url") or "",
            is_active=bool(row.get("is_active", True)),
        )

    def cleaned(self) -> "HomeAnnouncement":
        return HomeAnnouncement(
            title=self.title.strip(),
            description=self.description.strip(),
            url=self.url.strip(),
            is_active=self.is_active,
        )

    def problems(self) -> list[str]:
        """Why this card can't be saved (empty when it can) — the same rules
        as the table's check constraints."""
        card = self.cleaned()
        found = []
        if not card.title:
            found.append("A title is needed.")
        if not card.url.startswith("https://"):
            found.append("The link must start with https://.")
        return found

    def to_row(self) -> dict[str, Any]:
        card = self.cleaned()
        return {
            "id": 1,
            "title": card.title,
            "description": card.description,
            "url": card.url,
            "is_active": card.is_active,
        }
