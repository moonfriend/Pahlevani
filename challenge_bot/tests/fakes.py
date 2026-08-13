"""Hand-written fakes used across the test suite — no live Supabase or Telegram."""

from postgrest.exceptions import APIError


class FakeResponse:
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
            return FakeResponse(rows)

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
            if "slug" in row:
                clash = any(r.get("slug") == row["slug"] for r in self._rows)
                if clash:
                    raise APIError(
                        {
                            "message": 'duplicate key value violates unique constraint '
                            '"challenge_story_slug_key"',
                            "code": "23505",
                            "details": None,
                            "hint": None,
                        }
                    )
            row["id"] = len(self._rows) + 1
            self._rows.append(row)
            return FakeResponse([row])

        if self._mode == "update":
            updated = []
            for row in self._rows:
                if self._matches(row):
                    row.update(self._payload)
                    updated.append(row)
            return FakeResponse(updated)

        raise AssertionError("execute() called with no operation set")


class FakeSupabaseClient:
    def __init__(self):
        self._store = {"challenge": [], "challenge_entry": [], "challenge_story": []}

    def table(self, name):
        return _FakeQuery(self._store[name])
