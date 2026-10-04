"""Onboarding cards: the model and pure logic behind admin.py's Onboarding tab.

Kept apart from the Streamlit UI so it can be unit-tested
(scripts/tests/test_onboarding_cards.py). Mirrors the `onboarding_cards`
table (supabase/migrations/0040_onboarding_cards.sql) and what the app's
OnboardingCardRow DTO reads.
"""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any

# Visuals bundled in the app (must match the table's check constraint and the
# app's BuiltinOnboardingImage).
BUILTIN_IMAGES: tuple[str, ...] = ("figure", "figure_alt", "shamseh")
BUILTIN_IMAGE_LABELS: dict[str, str] = {
    "figure": "The session's figure",
    "figure_alt": "The other figure",
    "shamseh": "Shamseh rosette",
}

R2_ONBOARDING_PREFIX = "images/onboarding/"
_IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}


def _clean(value: str | None) -> str | None:
    """Trim; blank becomes None so optional columns stay NULL."""
    if value is None:
        return None
    value = value.strip()
    return value or None


@dataclass(frozen=True)
class OnboardingCard:
    """One onboarding card as stored in `onboarding_cards`."""

    title_en: str
    body_en: str = ""
    title_fa: str | None = None
    body_fa: str | None = None
    image_url: str | None = None
    builtin_image: str = "figure"
    is_active: bool = True
    position: int = 0
    id: int | None = None

    def __post_init__(self) -> None:
        if not self.title_en or not self.title_en.strip():
            raise ValueError("An onboarding card needs an English title.")
        if self.builtin_image not in BUILTIN_IMAGES:
            raise ValueError(f"Unknown built-in image {self.builtin_image!r}.")
        url = _clean(self.image_url)
        # The app loads this with Image.network — only https, never other
        # schemes an admin could paste by mistake.
        if url is not None and not url.startswith("https://"):
            raise ValueError("The image URL must start with https://")

    @classmethod
    def from_row(cls, row: dict[str, Any]) -> OnboardingCard:
        return cls(
            id=row.get("id"),
            position=int(row.get("position") or 0),
            title_en=row["title_en"],
            body_en=row.get("body_en") or "",
            title_fa=row.get("title_fa"),
            body_fa=row.get("body_fa"),
            image_url=row.get("image_url"),
            builtin_image=row.get("builtin_image") or "figure",
            is_active=bool(row.get("is_active", True)),
        )

    def to_row(self) -> dict[str, Any]:
        """Columns to insert/update (the database assigns `id`)."""
        return {
            "position": self.position,
            "title_en": self.title_en.strip(),
            "body_en": (self.body_en or "").strip(),
            "title_fa": _clean(self.title_fa),
            "body_fa": _clean(self.body_fa),
            "image_url": _clean(self.image_url),
            "builtin_image": self.builtin_image,
            "is_active": self.is_active,
        }

    def with_changes(self, **changes: Any) -> OnboardingCard:
        """A validated copy with [changes] applied."""
        return replace(self, **changes)


def next_position(cards: list[OnboardingCard]) -> int:
    """Position for a new card: after the last one."""
    return max((c.position for c in cards), default=0) + 1


def move_patches(
    cards: list[OnboardingCard], index: int, direction: int
) -> list[tuple[int, int]]:
    """(card id, new position) updates that move cards[index] one step up
    (direction -1) or down (+1) by swapping with its neighbour. Empty at the
    ends. When both share a position, the moved card is placed strictly on
    the correct side so the order actually changes."""
    other = index + direction
    if not 0 <= other < len(cards):
        return []
    moving, neighbour = cards[index], cards[other]
    assert moving.id is not None and neighbour.id is not None
    if moving.position != neighbour.position:
        return [(moving.id, neighbour.position), (neighbour.id, moving.position)]
    return [(moving.id, neighbour.position),
            (neighbour.id, neighbour.position - direction)]


def r2_key_for(title: str, filename: str, data: bytes) -> str:
    """R2 key for an uploaded card image. Content-hashed, so replacing an
    image yields a new URL instead of a stale cached one."""
    ext = Path(filename).suffix.lower()
    if ext not in _IMAGE_EXTENSIONS:
        raise ValueError(
            f"Upload a PNG, JPG or WebP image (got {ext or 'no extension'})."
        )
    slug = re.sub(r"[^a-z0-9_]", "", title.lower().replace(" ", "_"))[:40]
    digest = hashlib.sha256(data).hexdigest()[:10]
    return f"{R2_ONBOARDING_PREFIX}{slug or 'card'}-{digest}{ext}"
