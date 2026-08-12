import pytest

from repository import ChallengeAlreadyActiveError, ChallengeRepository
from tests.fakes import FakeSupabaseClient


@pytest.fixture
def repo():
    return ChallengeRepository(FakeSupabaseClient())


def test_create_and_get_active_challenge(repo):
    created = repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=42)
    assert created["chat_id"] == 1
    assert created["status"] == "active"

    active = repo.get_active_challenge(chat_id=1)
    assert active["id"] == created["id"]


def test_get_active_challenge_returns_none_when_absent(repo):
    assert repo.get_active_challenge(chat_id=999) is None


def test_create_challenge_rejects_second_active_challenge(repo):
    repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=42)
    with pytest.raises(ChallengeAlreadyActiveError):
        repo.create_challenge(chat_id=1, target_amount=100, unit="situps", created_by=42)


def test_end_challenge_marks_completed(repo):
    created = repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=42)
    ended = repo.end_challenge(created["id"])
    assert ended["status"] == "completed"
    assert ended["completed_at"] is not None


def test_add_entry_and_get_total(repo):
    created = repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=42)
    repo.add_entry(
        created["id"], telegram_user_id=1, amount=30, source="text", raw_text="I did 30 push ups"
    )
    repo.add_entry(created["id"], telegram_user_id=2, amount=15, source="command")

    assert repo.get_total(created["id"]) == 45


def test_get_total_is_zero_for_challenge_with_no_entries(repo):
    created = repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=42)
    assert repo.get_total(created["id"]) == 0
