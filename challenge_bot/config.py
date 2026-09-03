import os
from pathlib import Path

from dotenv import load_dotenv

# Telegram token only — SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY come from the
# admin creds vault via challenge_bot/run.sh, never persisted here.
load_dotenv(Path(__file__).parent.parent / "env" / "challenge_bot.env")


def _required_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(
            f"Missing required environment variable: {name}. "
            "Run via `bash challenge_bot/run.sh`, or copy "
            "env/challenge_bot.env.example to env/challenge_bot.env."
        )
    return value


def load_config() -> "Config":
    return Config(
        telegram_bot_token=_required_env("TELEGRAM_BOT_TOKEN"),
        supabase_url=_required_env("SUPABASE_URL"),
        supabase_key=_required_env("SUPABASE_SERVICE_ROLE_KEY"),
    )


class Config:
    def __init__(self, telegram_bot_token: str, supabase_url: str, supabase_key: str) -> None:
        self.telegram_bot_token = telegram_bot_token
        self.supabase_url = supabase_url
        self.supabase_key = supabase_key
