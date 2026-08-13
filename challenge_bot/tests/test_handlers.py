import asyncio
from types import SimpleNamespace

import pytest

from handlers import commands, messages, story_commands
from repository import ChallengeRepository
from tests.fakes import FakeSupabaseClient


class FakeBot:
    def __init__(self):
        self.reactions = []

    async def set_message_reaction(self, chat_id, message_id, reaction=None):
        self.reactions.append((chat_id, message_id, reaction))


class FakeMessage:
    def __init__(self, text=None, message_id=1):
        self.text = text
        self.message_id = message_id
        self.replies = []
        self.parse_modes = []

    async def reply_text(self, text, parse_mode=None, **_kwargs):
        self.replies.append(text)
        self.parse_modes.append(parse_mode)


def make_update(text=None, chat_id=1, user_id=7, username="bob"):
    message = FakeMessage(text=text)
    chat = SimpleNamespace(id=chat_id)
    user = SimpleNamespace(id=user_id, username=username, full_name="Bob")
    update = SimpleNamespace(effective_chat=chat, effective_message=message, effective_user=user)
    return update, message


def make_context(repository, args=None, bot=None):
    return SimpleNamespace(args=args or [], bot_data={"repository": repository}, bot=bot or FakeBot())


def run(coro):
    return asyncio.run(coro)


@pytest.fixture
def repo():
    return ChallengeRepository(FakeSupabaseClient())


def test_challenge_command_starts_a_challenge(repo):
    update, message = make_update()
    context = make_context(repo, args=["300", "pushups"])

    run(commands.challenge_command(update, context))

    assert "Challenge started" in message.replies[-1]
    assert repo.get_active_challenge(1) is not None


def test_challenge_command_rejects_duplicate(repo):
    update1, message1 = make_update()
    run(commands.challenge_command(update1, make_context(repo, args=["300", "pushups"])))

    update2, message2 = make_update()
    run(commands.challenge_command(update2, make_context(repo, args=["100"])))

    assert "already an active challenge" in message2.replies[-1]


def test_challenge_command_rejects_target_over_upper_bound(repo):
    update, message = make_update()
    context = make_context(repo, args=[str(commands.MAX_TARGET_AMOUNT + 1)])

    run(commands.challenge_command(update, context))

    assert "too large" in message.replies[-1].lower()
    assert repo.get_active_challenge(1) is None


def test_challenge_command_accepts_target_at_upper_bound(repo):
    update, message = make_update()
    context = make_context(repo, args=[str(commands.MAX_TARGET_AMOUNT)])

    run(commands.challenge_command(update, context))

    assert "Challenge started" in message.replies[-1]


def test_log_command_records_silently_with_reaction(repo):
    repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=7)
    update, message = make_update()
    bot = FakeBot()
    context = make_context(repo, args=["30"], bot=bot)

    run(commands.log_command(update, context))

    assert message.replies == []
    assert len(bot.reactions) == 1
    challenge = repo.get_active_challenge(1)
    assert repo.get_total(challenge["id"]) == 30


def test_log_command_with_no_active_challenge_stays_silent(repo):
    update, message = make_update()
    bot = FakeBot()
    context = make_context(repo, args=["30"], bot=bot)

    run(commands.log_command(update, context))

    assert message.replies == []
    assert bot.reactions == []


def test_total_command_reports_running_total(repo):
    repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=7)
    challenge = repo.get_active_challenge(1)
    repo.add_entry(challenge["id"], telegram_user_id=7, amount=30)

    update, message = make_update()
    context = make_context(repo)

    run(commands.total_command(update, context))

    assert "30" in message.replies[-1]
    assert "300" in message.replies[-1]


def test_total_command_includes_per_user_leaderboard_sorted_descending(repo):
    repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=7)
    challenge = repo.get_active_challenge(1)
    repo.add_entry(challenge["id"], telegram_user_id=1, amount=10, display_name="Alice")
    repo.add_entry(challenge["id"], telegram_user_id=2, amount=50, display_name="Bob")

    update, message = make_update()
    context = make_context(repo)

    run(commands.total_command(update, context))

    reply = message.replies[-1]
    assert reply.index("Bob") < reply.index("Alice")
    assert "50" in reply
    assert "10" in reply


def test_total_command_omits_leaderboard_when_no_entries(repo):
    repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=7)

    update, message = make_update()
    context = make_context(repo)

    run(commands.total_command(update, context))

    assert message.replies[-1] == "Total: 0 / 300 pushups (0%)"
    # Regression guard: a plain (non-story) challenge must reply with the
    # exact same call shape as before story mode existed — no parse_mode.
    assert message.parse_modes[-1] is None


def test_end_command_closes_challenge(repo):
    repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=7)
    challenge = repo.get_active_challenge(1)
    repo.add_entry(challenge["id"], telegram_user_id=7, amount=30)

    update, message = make_update()
    context = make_context(repo)

    run(commands.end_command(update, context))

    assert "30" in message.replies[-1]
    assert repo.get_active_challenge(1) is None


def test_text_message_handler_parses_and_records(repo):
    repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=7)
    update, message = make_update(text="I did 30 push ups")
    bot = FakeBot()
    context = make_context(repo, bot=bot)

    run(messages.text_message_handler(update, context))

    assert message.replies == []
    assert len(bot.reactions) == 1
    challenge = repo.get_active_challenge(1)
    assert repo.get_total(challenge["id"]) == 30


def test_text_message_handler_ignores_unparseable_text(repo):
    repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=7)
    update, message = make_update(text="hello there")
    bot = FakeBot()
    context = make_context(repo, bot=bot)

    run(messages.text_message_handler(update, context))

    assert message.replies == []
    assert bot.reactions == []


# ── /start_challenge and story-aware /total ─────────────────────────────────


def _create_story(repo, slug="khane_avval", cursor_glyph=None):
    template = "/==\\\n/====\\"
    return repo.create_story(
        slug=slug,
        title="The Dragon's Peak",
        story_text="The dragon sits at the summit. Together, we must climb to face it.",
        template=template,
        fill_order=[0, 1, 2, 3, 4, 5],
        cursor_glyph=cursor_glyph,
    )


def test_start_challenge_command_creates_story_bound_challenge_and_posts_art(repo):
    _create_story(repo)
    update, message = make_update()
    context = make_context(repo, args=["khane_avval", "60", "pushups"])

    run(story_commands.start_challenge_command(update, context))

    assert "dragon" in message.replies[-1]
    assert "<pre>" in message.replies[-1]
    assert message.parse_modes[-1] == "HTML"
    challenge = repo.get_active_challenge(1)
    assert challenge["story_id"] is not None


def test_start_challenge_command_unknown_slug_replies_with_error(repo):
    update, message = make_update()
    context = make_context(repo, args=["no_such_slug", "60"])

    run(story_commands.start_challenge_command(update, context))

    assert "no story found" in message.replies[-1].lower()
    assert repo.get_active_challenge(1) is None


def test_start_challenge_command_missing_args_shows_usage(repo):
    update, message = make_update()
    context = make_context(repo, args=["khane_avval"])

    run(story_commands.start_challenge_command(update, context))

    assert "usage" in message.replies[-1].lower()


def test_start_challenge_command_rejects_target_over_upper_bound(repo):
    _create_story(repo)
    update, message = make_update()
    context = make_context(
        repo, args=["khane_avval", str(story_commands.MAX_TARGET_AMOUNT + 1)]
    )

    run(story_commands.start_challenge_command(update, context))

    assert "too large" in message.replies[-1].lower()
    assert repo.get_active_challenge(1) is None


def test_start_challenge_command_rejects_duplicate_active_challenge(repo):
    _create_story(repo)
    update1, message1 = make_update()
    run(story_commands.start_challenge_command(update1, make_context(repo, args=["khane_avval", "60"])))

    update2, message2 = make_update()
    run(story_commands.start_challenge_command(update2, make_context(repo, args=["khane_avval", "60"])))

    assert "already an active challenge" in message2.replies[-1]


def test_total_command_prepends_ascii_art_when_story_bound(repo):
    story = _create_story(repo)
    challenge = repo.create_challenge(
        chat_id=1, target_amount=60, unit="pushups", created_by=7, story_id=story["id"]
    )
    repo.add_entry(challenge["id"], telegram_user_id=7, amount=25)

    update, message = make_update()
    context = make_context(repo)

    run(commands.total_command(update, context))

    reply = message.replies[-1]
    assert "<pre>" in reply
    assert "Total: 25 / 60 pushups" in reply


def test_total_command_shows_cursor_glyph_when_story_has_one_configured(repo):
    story = _create_story(repo, cursor_glyph="🧗")
    challenge = repo.create_challenge(
        chat_id=1, target_amount=60, unit="pushups", created_by=7, story_id=story["id"]
    )
    repo.add_entry(challenge["id"], telegram_user_id=7, amount=25)

    update, message = make_update()
    context = make_context(repo)

    run(commands.total_command(update, context))

    assert "🧗" in message.replies[-1]


def test_start_challenge_command_kickoff_shows_no_cursor_glyph_at_zero_reps(repo):
    _create_story(repo, cursor_glyph="🧗")
    update, message = make_update()
    context = make_context(repo, args=["khane_avval", "60", "pushups"])

    run(story_commands.start_challenge_command(update, context))

    assert "🧗" not in message.replies[-1]
    assert message.parse_modes[-1] == "HTML"
