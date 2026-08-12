import asyncio
import html
import logging

from telegram import Update
from telegram.ext import ContextTypes

from ascii_progress import render_ascii_progress
from handlers.commands import get_repository
from repository import ChallengeAlreadyActiveError

logger = logging.getLogger(__name__)

USAGE = "Usage: /start_challenge <slug> <target> [unit] — e.g. /start_challenge khane_avval 300 pushups"


async def start_challenge_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    message = update.effective_message
    args = context.args
    repository = get_repository(context)

    if len(args) < 2:
        await message.reply_text(USAGE)
        return

    slug = args[0]
    try:
        target_amount = int(args[1])
    except ValueError:
        await message.reply_text(f"Target must be a number. {USAGE}")
        return

    if target_amount <= 0:
        await message.reply_text("Target must be a positive number.")
        return

    unit = " ".join(args[2:]) or "reps"
    chat = update.effective_chat
    user = update.effective_user

    story = await asyncio.to_thread(repository.get_story_by_slug, slug)
    if story is None:
        await message.reply_text(f"No story found for slug '{slug}'. Check the slug and try again.")
        return

    try:
        await asyncio.to_thread(
            repository.create_challenge,
            chat_id=chat.id,
            target_amount=target_amount,
            unit=unit,
            created_by=user.id if user else None,
            title=story["title"],
            story_id=story["id"],
        )
    except ChallengeAlreadyActiveError:
        await message.reply_text(
            "There's already an active challenge in this group. Use /end to close it first."
        )
        return

    art = render_ascii_progress(
        story["template"],
        story["fill_order"],
        total_reps=0,
        target_amount=target_amount,
        complete_art=story.get("complete_art"),
    )
    story_text = html.escape(story["story_text"], quote=False)
    art_block = html.escape(art, quote=False)
    announcement = f"{story_text}\n\n<pre>{art_block}</pre>"
    await message.reply_text(announcement, parse_mode="HTML")
