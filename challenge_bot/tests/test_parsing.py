import pytest

from parsing import parse_rep_count

POSITIVE_CASES = [
    ("I did 30 push ups", 30),
    ("30 pushups done", 30),
    ("did 15", 15),
    ("I did 15 push-ups today", 15),
    ("done: 45 reps", 45),
    ("just finished 100 push ups!", 100),
    ("1 pushup", 1),
]

NEGATIVE_CASES = [
    "I have 30 minutes",
    "pushups are great",
    "",
    "hello there",
    "did 0",
    "did 6000 pushups",
    "no numbers here at all",
]


@pytest.mark.parametrize("text,expected", POSITIVE_CASES)
def test_parses_valid_rep_reports(text: str, expected: int) -> None:
    assert parse_rep_count(text) == expected


@pytest.mark.parametrize("text", NEGATIVE_CASES)
def test_ignores_non_rep_reports(text: str) -> None:
    assert parse_rep_count(text) is None
