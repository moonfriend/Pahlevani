import pytest

from ascii_progress import (
    default_fill_order,
    offsets_of_fillable_cells,
    render_ascii_progress,
    render_order_preview,
    symbols_done_count,
)

MINI_TEMPLATE = "/==\\\n/====\\"  # 6 fillable cells: occurrences 0,1 then 2,3,4,5


def test_offsets_of_fillable_cells_finds_all_equals_signs():
    offsets = offsets_of_fillable_cells(MINI_TEMPLATE)
    assert len(offsets) == 6
    assert all(MINI_TEMPLATE[i] == "=" for i in offsets)


def test_offsets_of_fillable_cells_empty_when_no_equals():
    assert offsets_of_fillable_cells("/****\\") == []


def test_default_fill_order_is_natural_reading_order():
    assert default_fill_order(MINI_TEMPLATE) == [0, 1, 2, 3, 4, 5]


def test_default_fill_order_empty_for_template_with_no_fillable_cells():
    assert default_fill_order("/****\\") == []


# ── symbols_done_count: the pacing formula ──────────────────────────────────


def test_symbols_done_count_exact_division():
    # target=200, total_symbols=25 -> 8 reps per symbol exactly
    assert symbols_done_count(total_reps=16, target_amount=200, total_symbols=25) == 2
    assert symbols_done_count(total_reps=8, target_amount=200, total_symbols=25) == 1
    assert symbols_done_count(total_reps=7, target_amount=200, total_symbols=25) == 0
    assert symbols_done_count(total_reps=200, target_amount=200, total_symbols=25) == 25


def test_symbols_done_count_distributes_remainder_via_mod():
    # target=205, total_symbols=25 -> base=8, remainder=5: first 5 symbols
    # cost 9 reps each, the rest cost 8 each. Total to fill all 25 == 205.
    total_to_fill_all = 5 * 9 + 20 * 8
    assert total_to_fill_all == 205
    assert symbols_done_count(total_reps=204, target_amount=205, total_symbols=25) == 24
    assert symbols_done_count(total_reps=205, target_amount=205, total_symbols=25) == 25
    # first symbol (index 0, in the "extra rep" group) needs 9, not 8
    assert symbols_done_count(total_reps=8, target_amount=205, total_symbols=25) == 0
    assert symbols_done_count(total_reps=9, target_amount=205, total_symbols=25) == 1


def test_symbols_done_count_zero_total_symbols_is_zero():
    assert symbols_done_count(total_reps=100, target_amount=200, total_symbols=0) == 0


def test_symbols_done_count_zero_or_negative_target_amount_is_zero():
    assert symbols_done_count(total_reps=100, target_amount=0, total_symbols=25) == 0
    assert symbols_done_count(total_reps=100, target_amount=-5, total_symbols=25) == 0


def test_symbols_done_count_zero_reps_is_zero():
    assert symbols_done_count(total_reps=0, target_amount=200, total_symbols=25) == 0


# ── render_ascii_progress ────────────────────────────────────────────────────


def test_render_ascii_progress_zero_reps_leaves_template_unfilled():
    art = render_ascii_progress(MINI_TEMPLATE, default_fill_order(MINI_TEMPLATE), 0, 60)
    assert art == MINI_TEMPLATE


def test_render_ascii_progress_partial_reps_converts_in_reading_order():
    # target=60, total_symbols=6 -> 10 reps per symbol
    art = render_ascii_progress(MINI_TEMPLATE, default_fill_order(MINI_TEMPLATE), 25, 60)
    # 25 // 10 = 2 symbols done -> occurrences 0 and 1 (row A) converted
    assert art == "/++\\\n/====\\"


def test_render_ascii_progress_overshoot_caps_at_total_symbols():
    art = render_ascii_progress(MINI_TEMPLATE, default_fill_order(MINI_TEMPLATE), 1000, 60)
    assert art == "/++\\\n/++++\\"


def test_render_ascii_progress_uses_custom_fill_order():
    reversed_order = list(reversed(default_fill_order(MINI_TEMPLATE)))
    # 10 reps per symbol; 25 reps -> 2 symbols done -> LAST two occurrences
    # (4 and 5, in row B) convert first under the reversed order.
    art = render_ascii_progress(MINI_TEMPLATE, reversed_order, 25, 60)
    assert art == "/==\\\n/==++\\"


def test_render_ascii_progress_returns_complete_art_verbatim_when_fully_filled():
    art = render_ascii_progress(
        MINI_TEMPLATE, default_fill_order(MINI_TEMPLATE), 60, 60, complete_art="\\o/"
    )
    assert art == "\\o/"


def test_render_ascii_progress_falls_back_to_filled_template_when_complete_art_none():
    art = render_ascii_progress(
        MINI_TEMPLATE, default_fill_order(MINI_TEMPLATE), 60, 60, complete_art=None
    )
    assert art == "/++\\\n/++++\\"


def test_render_ascii_progress_empty_template_returns_empty_string():
    assert render_ascii_progress("", [], 100, 60) == ""


def test_render_ascii_progress_template_with_no_equals_returns_unchanged():
    template = "/****\\"
    assert render_ascii_progress(template, [], 100, 60) == template


def test_render_ascii_progress_leaves_non_fillable_characters_untouched():
    art = render_ascii_progress(MINI_TEMPLATE, default_fill_order(MINI_TEMPLATE), 25, 60)
    assert art.startswith("/")
    assert "\n" in art


# ── render_order_preview ─────────────────────────────────────────────────────


def test_render_order_preview_labels_ranks_with_wraparound_mod_10():
    # 12 fillable cells -> ranks 0..9, then wrap to 0,1
    template = "=" * 12
    order = list(range(12))
    preview = render_order_preview(template, order)
    assert preview == "012345678901"


def test_render_order_preview_reflects_custom_fill_order():
    preview = render_order_preview(MINI_TEMPLATE, list(reversed(default_fill_order(MINI_TEMPLATE))))
    # occurrence 0 (first '=') now has rank 5, occurrence 5 (last '=') has rank 0
    assert preview == "/54\\\n/3210\\"
