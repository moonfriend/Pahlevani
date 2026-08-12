import asyncio
from types import SimpleNamespace

import pytest

from handlers import commands, messages
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

    async def reply_text(self, text):
        self.replies.append(text)


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
