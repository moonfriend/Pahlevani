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
    different target in every chat. target_amount // total_symbols gives the
    base cost per symbol; the leftover (target_amount % total_symbols) is
    spread one-extra-rep-each across the first `remainder` symbols, so the
    art reaches 100% exactly when total_reps reaches target_amount.
    """
    if total_symbols <= 0 or target_amount <= 0:
        return 0

    base = target_amount // total_symbols
    remainder = target_amount % total_symbols

    done = 0
    consumed = 0
    for i in range(total_symbols):
        required = base + (1 if i < remainder else 0)
        if consumed + required > total_reps:
            break
        consumed += required
        done += 1
    return done


def render_ascii_progress(
    template: str,
    fill_order: list[int],
    total_reps: int,
    target_amount: int,
    complete_art: str | None = None,
) -> str:
    offsets = offsets_of_fillable_cells(template)
    total_symbols = len(offsets)
    symbols_done = symbols_done_count(total_reps, target_amount, total_symbols)

    if symbols_done >= total_symbols and total_symbols > 0 and complete_art:
        return complete_art

    chars = list(template)
    for occurrence_index in fill_order[:symbols_done]:
        chars[offsets[occurrence_index]] = "+"
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
