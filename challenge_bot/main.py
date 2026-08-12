import logging

from supabase import create_client
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters

from config import load_config
from handlers import commands, messages
from logging_conf import configure_logging
from repository import ChallengeRepository

logger = logging.getLogger(__name__)


def build_application() -> Application:
    config = load_config()

    supabase_client = create_client(config.supabase_url, config.supabase_key)
    repository = ChallengeRepository(supabase_client)

    application = Application.builder().token(config.telegram_bot_token).build()
    application.bot_data["repository"] = repository

    application.add_handler(CommandHandler("challenge", commands.challenge_command))
    application.add_handler(CommandHandler("log", commands.log_command))
    application.add_handler(CommandHandler(["total", "status"], commands.total_command))
    application.add_handler(CommandHandler("end", commands.end_command))
    application.add_handler(CommandHandler(["help", "start"], commands.help_command))
    application.add_handler(
        MessageHandler(filters.TEXT & ~filters.COMMAND, messages.text_message_handler)
    )

    return application


def main() -> None:
    configure_logging()
    application = build_application()
    logger.info("Starting challenge bot (long polling)...")
    application.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
