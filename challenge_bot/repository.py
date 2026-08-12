from datetime import datetime, timezone

from postgrest.exceptions import APIError
from supabase import Client

_UNIQUE_VIOLATION = "23505"


class ChallengeAlreadyActiveError(Exception):
    """Raised by create_challenge when the group already has an active challenge."""

    def __init__(self, chat_id: int):
        super().__init__(f"chat {chat_id} already has an active challenge")
        self.chat_id = chat_id


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class ChallengeRepository:
    def __init__(self, client: Client) -> None:
        self._client = client

    def get_active_challenge(self, chat_id: int) -> dict | None:
        response = (
            self._client.table("challenge")
            .select("*")
            .eq("chat_id", chat_id)
            .eq("status", "active")
            .limit(1)
            .execute()
        )
        rows = response.data
        return rows[0] if rows else None

    def create_challenge(
        self,
        chat_id: int,
        target_amount: int,
        unit: str = "reps",
        created_by: int | None = None,
        title: str | None = None,
    ) -> dict:
        payload = {
            "chat_id": chat_id,
            "target_amount": target_amount,
            "unit": unit,
            "created_by_telegram_user_id": created_by,
            "title": title,
        }
        try:
            response = self._client.table("challenge").insert(payload).execute()
        except APIError as error:
            if error.code == _UNIQUE_VIOLATION:
                raise ChallengeAlreadyActiveError(chat_id) from error
            raise
        return response.data[0]

    def end_challenge(self, challenge_id: int) -> dict:
        response = (
            self._client.table("challenge")
            .update({"status": "completed", "completed_at": _now_iso()})
            .eq("id", challenge_id)
            .execute()
        )
        return response.data[0]

    def add_entry(
        self,
        challenge_id: int,
        telegram_user_id: int,
        amount: int,
        *,
        username: str | None = None,
        display_name: str | None = None,
        source: str = "text",
        raw_text: str | None = None,
        message_id: int | None = None,
    ) -> dict:
        payload = {
            "challenge_id": challenge_id,
            "telegram_user_id": telegram_user_id,
            "telegram_username": username,
            "telegram_display_name": display_name,
            "amount": amount,
            "source": source,
            "raw_message_text": raw_text,
            "telegram_message_id": message_id,
        }
        response = self._client.table("challenge_entry").insert(payload).execute()
        return response.data[0]

    def get_total(self, challenge_id: int) -> int:
        response = (
            self._client.table("challenge_entry")
            .select("amount")
            .eq("challenge_id", challenge_id)
            .execute()
        )
        return sum(row["amount"] for row in response.data)

    def get_totals_by_user(self, challenge_id: int) -> list[dict]:
        response = (
            self._client.table("challenge_entry")
            .select("telegram_user_id, telegram_username, telegram_display_name, amount")
            .eq("challenge_id", challenge_id)
            .execute()
        )
        totals: dict[int, dict] = {}
        for row in response.data:
            user_id = row["telegram_user_id"]
            entry = totals.setdefault(
                user_id,
                {
                    "telegram_user_id": user_id,
                    "display_name": row.get("telegram_display_name")
                    or row.get("telegram_username")
                    or str(user_id),
                    "amount": 0,
                },
            )
            entry["amount"] += row["amount"]
        return sorted(totals.values(), key=lambda entry: entry["amount"], reverse=True)
