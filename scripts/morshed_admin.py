"""
morshed_admin.py
════════════════
Admin-side Morshed operations kept out of admin.py's Streamlit code so they
can be unit-tested (scripts/tests/test_morshed_admin.py).
"""

from __future__ import annotations

import re
import uuid
from pathlib import Path


class DefaultMorshedError(RuntimeError):
    """Setting the default Morshed failed (e.g. migration 0041 not applied)."""


def set_default_morshed(db, morshed_id: int | None) -> None:
    """Makes [morshed_id] the default Morshed (None = no default).

    First-time users download the default Morshed's recordings before they
    choose one (migration 0041). The DB allows at most one default, so the
    current one is cleared before the new one is set.
    """
    try:
        db.table("morshed").update({"is_default": False}).eq(
            "is_default", True).execute()
        if morshed_id is not None:
            db.table("morshed").update({"is_default": True}).eq(
                "id", morshed_id).execute()
    except Exception as e:  # noqa: BLE001 — re-raised with context
        raise DefaultMorshedError(
            f"Couldn't set the default Morshed ({e}). If the is_default column "
            "is missing, apply migration 0041_media_asset_and_default_morshed.sql "
            "first."
        ) from e


def default_recording(
    movement_type_id: int | None,
    tracks: list[dict],
    default_morshed_id: int | None,
) -> dict | None:
    """The recording a first-time user hears for a movement type.

    Mirrors the app's resolveAudioTrack: the default Morshed's recording,
    else the first one recorded for the type (tracks in id order). None when
    the movement has no type or nothing is recorded for it.
    """
    if movement_type_id is None:
        return None
    for_type = [t for t in tracks if t.get("movement_type_id") == movement_type_id]
    if not for_type:
        return None
    return next(
        (t for t in for_type if default_morshed_id is not None
         and t.get("morshed_id") == default_morshed_id),
        for_type[0],
    )


def recording_reps(
    movement_type_id: int | None,
    tracks: list[dict],
    default_morshed_id: int | None,
) -> int | None:
    """Reps in [default_recording]. The old exercise.repetitions is
    deliberately not used — it no longer matches the recordings."""
    chosen = default_recording(movement_type_id, tracks, default_morshed_id)
    reps = chosen.get("repetitions_default") if chosen else None
    return int(reps) if reps is not None else None


def audio_track_r2_key(prefix: str, type_id: int, morshed_id: int,
                       filename: str, unique: str | None = None) -> str:
    """R2 key for an uploaded recording: type, Morshed, the file's own name and
    a random suffix.

    A Morshed may have several recordings of one movement type (variants,
    migration 0050), and the app caches files by URL, so a new upload must
    never overwrite a file already in use — hence the suffix ([unique], random
    unless given).
    """
    stem = re.sub(r"[^a-z0-9_]", "",
                  Path(filename).stem.lower().replace(" ", "_"))
    suffix = unique or uuid.uuid4().hex[:8]
    return f"{prefix}{type_id}-{morshed_id}-{stem}-{suffix}.mp3"
