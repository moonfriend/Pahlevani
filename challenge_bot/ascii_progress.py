def offsets_of_fillable_cells(template: str) -> list[int]:
    """String-index positions of every '=' character, in reading order."""
    return [i for i, ch in enumerate(template) if ch == "="]


def default_fill_order(template: str) -> list[int]:
    """Natural reading order: occurrence-indices 0..N-1 for N '=' cells."""
    return list(range(len(offsets_of_fillable_cells(template))))


def symbols_done_count(total_reps: int, target_amount: int, total_symbols: int) -> int:
    """How many '=' cells are converted given total_reps against target_amount.

    Pacing is derived per-run from the challenge's own target_amount rather
    than a fixed "reps per symbol", since the same story can run with a
    different target in every chat. Each symbol represents an equal
    *proportion* of the goal (total_reps / target_amount, scaled to
    total_symbols and floored), so the art reaches 100% exactly when
    total_reps reaches target_amount.

    When target_amount isn't a clean multiple of total_symbols, this still
    keeps the fill rate visually consistent throughout: the "costs one extra
    rep" symbols implied by the remainder are spread evenly across the whole
    sequence rather than front-loaded onto the first few symbols (which
    would look like a slow start followed by a sudden speed-up).
    """
    if total_symbols <= 0 or target_amount <= 0 or total_reps <= 0:
        return 0

    return min(total_symbols, (total_reps * total_symbols) // target_amount)


def render_ascii_progress(
    template: str,
    fill_order: list[int],
    total_reps: int,
    target_amount: int,
    complete_art: str | None = None,
    cursor_glyph: str | None = None,
) -> str:
    offsets = offsets_of_fillable_cells(template)
    total_symbols = len(offsets)
    symbols_done = symbols_done_count(total_reps, target_amount, total_symbols)

    if symbols_done >= total_symbols and total_symbols > 0 and complete_art:
        return complete_art

    chars = list(template)
    for occurrence_index in fill_order[:symbols_done]:
        chars[offsets[occurrence_index]] = "+"

    if cursor_glyph and symbols_done > 0:
        frontier_occurrence = fill_order[symbols_done - 1]
        chars[offsets[frontier_occurrence]] = cursor_glyph

    return "".join(chars)


def render_order_preview(template: str, fill_order: list[int]) -> str:
    """Human-readable rank preview (mod 10) — preview only, never the source of truth."""
    offsets = offsets_of_fillable_cells(template)
    rank_by_offset = {
        offsets[occurrence_index]: rank for rank, occurrence_index in enumerate(fill_order)
    }
    chars = list(template)
    for offset, rank in rank_by_offset.items():
        chars[offset] = str(rank % 10)
    return "".join(chars)
