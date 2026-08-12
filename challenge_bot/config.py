import os

from dotenv import load_dotenv

load_dotenv()


def _required_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(
            f"Missing required environment variable: {name}. "
            "Copy challenge_bot/.env.example to challenge_bot/.env and fill it in."
        )
    return value


def load_config() -> "Config":
    return Config(
        telegram_bot_token=_required_env("TELEGRAM_BOT_TOKEN"),
        supabase_url=_required_env("SUPABASE_URL"),
        supabase_key=_required_env("SUPABASE_KEY"),
    )


class Config:
    def __init__(self, telegram_bot_token: str, supabase_url: str, supabase_key: str) -> None:
        self.telegram_bot_token = telegram_bot_token
        self.supabase_url = supabase_url
        self.supabase_key = supabase_key
