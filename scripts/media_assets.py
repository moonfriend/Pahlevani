"""
media_assets.py
═══════════════
Sizes of uploaded media files (table public.media_asset, migration 0041).

The app shows a session's download size before downloading it, so every
media file's real size must be known up front. Two writers keep the table
correct:

  • admin.py records a row on every R2 upload (record_media_asset), and
  • scripts/check_media_integrity.py verifies every referenced file against
    the object actually stored on R2 and can repair rows (--fix).

Pure logic lives here (no Streamlit, no network) so it is unit-tested in
scripts/tests/test_media_assets.py.
"""

from __future__ import annotations

from dataclasses import dataclass, field

# Every column in the schema that holds a public media URL. The integrity
# check scans exactly these; a test pins the list so a new media column can't
# be added without the check knowing about it.
REFERENCE_COLUMNS: tuple[tuple[str, str], ...] = (
    ("movement_audio_track", "audio_url"),
    ("movement", "media_src"),
    ("movement", "media_poster"),
    ("movement_info", "video_url"),
    ("video", "url"),
    ("video", "poster_url"),
    ("path_node_item", "video_url"),
    ("morshed", "photo_url"),
)

TABLE = "media_asset"


class MediaAssetError(RuntimeError):
    """Recording a size failed — surfaced loudly so an upload never silently
    leaves a file whose size the app can't show."""


@dataclass(frozen=True, order=True)
class MediaAsset:
    url: str
    size_bytes: int
    content_type: str | None = None


def record_media_asset(db, asset: MediaAsset) -> None:
    """Upserts [asset] into media_asset (one row per URL).

    checked_at is reset to null: the size was taken from the uploaded bytes,
    and only the integrity check marks a row as verified against R2.
    """
    if asset.size_bytes <= 0:
        raise ValueError(f"size must be positive, got {asset.size_bytes} "
                         f"for {asset.url}")
    payload = {
        "url": asset.url,
        "size_bytes": asset.size_bytes,
        "content_type": asset.content_type,
        "checked_at": None,
    }
    try:
        db.table(TABLE).upsert(payload, on_conflict="url").execute()
    except Exception as e:  # noqa: BLE001 — re-raised with context
        raise MediaAssetError(
            f"Couldn't record the size of {asset.url} in {TABLE} ({e}). "
            "If the table is missing, apply migration "
            "0041_media_asset_and_default_morshed.sql first."
        ) from e


def _is_media_url(value) -> bool:
    return isinstance(value, str) and value.strip().startswith(
        ("http://", "https://"))


def collect_referenced_urls(db) -> set[str]:
    """Every distinct media URL referenced anywhere in REFERENCE_COLUMNS."""
    urls: set[str] = set()
    for table, column in REFERENCE_COLUMNS:
        rows = db.table(table).select(column).execute().data or []
        urls.update(r[column].strip() for r in rows if _is_media_url(r.get(column)))
    return urls


@dataclass
class IntegrityReport:
    ok: list[str] = field(default_factory=list)
    # (url, recorded size, actual size on R2)
    size_mismatches: list[tuple[str, int, int]] = field(default_factory=list)
    # (url, actual size) — referenced and on R2, but no media_asset row
    missing_rows: list[tuple[str, int]] = field(default_factory=list)
    # referenced, but the object couldn't be fetched (absent / unreachable)
    unreachable: list[str] = field(default_factory=list)
    # media_asset rows no table references any more (informational)
    orphan_rows: list[str] = field(default_factory=list)

    @property
    def is_clean(self) -> bool:
        """Orphans are informational (old uploads); everything else must be
        fixed for the app's download sizes to be right."""
        return not (self.size_mismatches or self.missing_rows or self.unreachable)

    def fixes(self) -> list[MediaAsset]:
        """Rows --fix writes: the actual R2 size for wrong or missing rows."""
        return [MediaAsset(u, actual) for u, _, actual in self.size_mismatches] + [
            MediaAsset(u, actual) for u, actual in self.missing_rows
        ]


def build_integrity_report(
    *,
    referenced: set[str],
    recorded: dict[str, int],
    actual: dict[str, int | None],
) -> IntegrityReport:
    """Classifies every referenced URL (pure; the caller does DB/HTTP).

    [actual] maps each referenced URL to its size on R2, or None when the
    object couldn't be fetched.
    """
    report = IntegrityReport()
    for url in sorted(referenced):
        real = actual.get(url)
        if real is None:
            report.unreachable.append(url)
        elif url not in recorded:
            report.missing_rows.append((url, real))
        elif recorded[url] != real:
            report.size_mismatches.append((url, recorded[url], real))
        else:
            report.ok.append(url)
    report.orphan_rows = sorted(set(recorded) - referenced)
    return report
