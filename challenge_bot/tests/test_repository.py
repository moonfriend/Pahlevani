import pytest
from postgrest.exceptions import APIError

from repository import ChallengeAlreadyActiveError, ChallengeRepository


class _FakeResponse:
    def __init__(self, data):
        self.data = data


class _FakeQuery:
    """Mimics only the supabase-py fluent chain shapes repository.py calls."""

    def __init__(self, rows):
        self._rows = rows
        self._filters = []
        self._mode = None
        self._payload = None
        self._limit = None

    def select(self, *_args, **_kwargs):
        self._mode = "select"
        return self

    def insert(self, payload):
        self._mode = "insert"
        self._payload = payload
        return self

    def update(self, payload):
        self._mode = "update"
        self._payload = payload
        return self

    def eq(self, column, value):
        self._filters.append((column, value))
        return self

    def limit(self, n):
        self._limit = n
        return self

    def _matches(self, row):
        return all(row.get(col) == val for col, val in self._filters)

    def execute(self):
        if self._mode == "select":
            rows = [row for row in self._rows if self._matches(row)]
            if self._limit is not None:
                rows = rows[: self._limit]
            return _FakeResponse(rows)

        if self._mode == "insert":
            row = dict(self._payload)
            row.setdefault("status", "active")
            row.setdefault("unit", "reps")
            if "chat_id" in row and row.get("status") == "active":
                clash = any(
                    r.get("chat_id") == row["chat_id"] and r.get("status") == "active"
                    for r in self._rows
                )
                if clash:
                    raise APIError(
                        {
                            "message": 'duplicate key value violates unique constraint '
                            '"challenge_one_active_per_chat"',
                            "code": "23505",
                            "details": None,
                            "hint": None,
                        }
                    )
            row["id"] = len(self._rows) + 1
            self._rows.append(row)
            return _FakeResponse([row])

        if self._mode == "update":
            updated = []
            for row in self._rows:
                if self._matches(row):
                    row.update(self._payload)
                    updated.append(row)
            return _FakeResponse(updated)

        raise AssertionError("execute() called with no operation set")


class FakeSupabaseClient:
    def __init__(self):
        self._store = {"challenge": [], "challenge_entry": []}

    def table(self, name):
        return _FakeQuery(self._store[name])


@pytest.fixture
def repo():
    return ChallengeRepository(FakeSupabaseClient())


def test_create_and_get_active_challenge(repo):
    created = repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=42)
    assert created["chat_id"] == 1
    assert created["status"] == "active"

    active = repo.get_active_challenge(chat_id=1)
    assert active["id"] == created["id"]


def test_get_active_challenge_returns_none_when_absent(repo):
    assert repo.get_active_challenge(chat_id=999) is None


def test_create_challenge_rejects_second_active_challenge(repo):
    repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=42)
    with pytest.raises(ChallengeAlreadyActiveError):
        repo.create_challenge(chat_id=1, target_amount=100, unit="situps", created_by=42)


def test_end_challenge_marks_completed(repo):
    created = repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=42)
    ended = repo.end_challenge(created["id"])
    assert ended["status"] == "completed"
    assert ended["completed_at"] is not None


def test_add_entry_and_get_total(repo):
    created = repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=42)
    repo.add_entry(
        created["id"], telegram_user_id=1, amount=30, source="text", raw_text="I did 30 push ups"
    )
    repo.add_entry(created["id"], telegram_user_id=2, amount=15, source="command")

    assert repo.get_total(created["id"]) == 45


def test_get_total_is_zero_for_challenge_with_no_entries(repo):
    created = repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=42)
    assert repo.get_total(created["id"]) == 0
