from telegram import Update
from telegram.ext import ContextTypes

from handlers.commands import record_entry
from parsing import parse_rep_count


async def text_message_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    message = update.effective_message
    if message is None or not message.text:
        return

    amount = parse_rep_count(message.text)
    if amount is None:
        return

    await record_entry(update, context, amount, source="text", raw_text=message.text)
