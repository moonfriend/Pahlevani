import asyncio
import html
import logging

from telegram import Update
from telegram.ext import ContextTypes

from ascii_progress import render_ascii_progress
from repository import ChallengeAlreadyActiveError, ChallengeRepository

logger = logging.getLogger(__name__)

HELP_TEXT = (
    "/challenge <target> [unit] — start a group challenge, e.g. /challenge 300 pushups\n"
    '/log <amount> [unit] — log a rep count (or just say it: "I did 30 push ups")\n'
    "/start_challenge <slug> <target> [unit] — start a story-driven challenge, "
    "e.g. /start_challenge khane_avval 300 pushups\n"
    "/total or /status — show the running total\n"
    "/end — close the active challenge"
)


def get_repository(context: ContextTypes.DEFAULT_TYPE) -> ChallengeRepository:
    return context.bot_data["repository"]


async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await update.effective_message.reply_text(HELP_TEXT)


async def challenge_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    message = update.effective_message
    args = context.args

    if not args:
        await message.reply_text("Usage: /challenge <target> [unit] — e.g. /challenge 300 pushups")
        return

    try:
        target_amount = int(args[0])
    except ValueError:
        await message.reply_text("Target must be a number, e.g. /challenge 300 pushups")
        return

    if target_amount <= 0:
        await message.reply_text("Target must be a positive number.")
        return

    unit = " ".join(args[1:]) or "reps"
    chat = update.effective_chat
    user = update.effective_user

    try:
        await asyncio.to_thread(
            get_repository(context).create_challenge,
            chat_id=chat.id,
            target_amount=target_amount,
            unit=unit,
            created_by=user.id if user else None,
        )
    except ChallengeAlreadyActiveError:
        await message.reply_text(
            "There's already an active challenge in this group. Use /end to close it first."
        )
        return

    await message.reply_text(
        f"Challenge started: {target_amount} {unit}. Log yours with /log or just tell me!"
    )


async def log_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    message = update.effective_message
    args = context.args

    if not args:
        return

    try:
        amount = int(args[0])
    except ValueError:
        return

    if amount <= 0:
        return

    await record_entry(update, context, amount, source="command", raw_text=message.text)


async def total_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    chat = update.effective_chat
    message = update.effective_message
    repository = get_repository(context)

    challenge = await asyncio.to_thread(repository.get_active_challenge, chat.id)
    if challenge is None:
        await message.reply_text("No active challenge in this group. Start one with /challenge <target> [unit].")
        return

    total = await asyncio.to_thread(repository.get_total, challenge["id"])
    breakdown = await asyncio.to_thread(repository.get_totals_by_user, challenge["id"])
    target = challenge["target_amount"]
    unit = challenge["unit"]
    percent = min(100, round(100 * total / target)) if target else 0

    lines = [f"Total: {total} / {target} {unit} ({percent}%)"]
    if breakdown:
        lines.append("")
        lines.extend(f"{entry['display_name']}: {entry['amount']}" for entry in breakdown)
    status_text = "\n".join(lines)

    story_id = challenge.get("story_id")
    if story_id is None:
        await message.reply_text(status_text)
        return

    story = await asyncio.to_thread(repository.get_story, story_id)
    art = render_ascii_progress(
        story["template"],
        story["fill_order"],
        total_reps=total,
        target_amount=target,
        complete_art=story.get("complete_art"),
    )
    html_message = f"<pre>{html.escape(art, quote=False)}</pre>\n{html.escape(status_text, quote=False)}"
    await message.reply_text(html_message, parse_mode="HTML")


async def end_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    chat = update.effective_chat
    message = update.effective_message
    repository = get_repository(context)

    challenge = await asyncio.to_thread(repository.get_active_challenge, chat.id)
    if challenge is None:
        await message.reply_text("No active challenge in this group.")
        return

    total = await asyncio.to_thread(repository.get_total, challenge["id"])
    await asyncio.to_thread(repository.end_challenge, challenge["id"])
    target = challenge["target_amount"]
    unit = challenge["unit"]
    await message.reply_text(f"Challenge closed. Final total: {total} / {target} {unit}")


async def record_entry(
    update: Update,
    context: ContextTypes.DEFAULT_TYPE,
    amount: int,
    *,
    source: str,
    raw_text: str | None,
) -> None:
    """Silently log a rep report against the group's active challenge, if any.

    No text reply on success (only a reaction) or on a missing active
    challenge — matches the "minimal output" requirement.
    """
    chat = update.effective_chat
    message = update.effective_message
    user = update.effective_user
    repository = get_repository(context)

    challenge = await asyncio.to_thread(repository.get_active_challenge, chat.id)
    if challenge is None:
        return

    await asyncio.to_thread(
        repository.add_entry,
        challenge["id"],
        telegram_user_id=user.id if user else 0,
        amount=amount,
        username=user.username if user else None,
        display_name=user.full_name if user else None,
        source=source,
        raw_text=raw_text,
        message_id=message.message_id,
    )
    await _react(context, chat.id, message.message_id)


async def _react(context: ContextTypes.DEFAULT_TYPE, chat_id: int, message_id: int) -> None:
    try:
        await context.bot.set_message_reaction(chat_id=chat_id, message_id=message_id, reaction="👍")
    except Exception:
        logger.debug(
            "Failed to set reaction on message %s in chat %s", message_id, chat_id, exc_info=True
        )
