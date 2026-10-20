"""
morshed_admin.py
════════════════
Admin-side Morshed operations kept out of admin.py's Streamlit code so they
can be unit-tested (scripts/tests/test_morshed_admin.py).
"""

from __future__ import annotations


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
