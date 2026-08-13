import re

_KEYWORDS = (
    "pushup",
    "push-up",
    "push up",
    "pushups",
    "push-ups",
    "push ups",
    "rep",
    "reps",
    "did",
    "done",
)

_MIN_AMOUNT = 1
_MAX_AMOUNT = 5000

# A number, optionally followed within a short window by a keyword, or
# preceded within a short window by one — keeps "I have 30 minutes" out
# while still catching "30 pushups done", "did 15", "done: 45 reps", etc.
_NUMBER_RE = re.compile(r"\b(\d{1,4})\b")


def parse_rep_count(text: str) -> int | None:
    """Extract a reported rep count from a free-text message, or None if unclear."""
    lowered = text.lower()
    if not any(keyword in lowered for keyword in _KEYWORDS):
        return None

    match = _NUMBER_RE.search(lowered)
    if not match:
        return None

    amount = int(match.group(1))
    if not (_MIN_AMOUNT <= amount <= _MAX_AMOUNT):
        return None

    return amount
