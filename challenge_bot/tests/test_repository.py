import pytest
from postgrest.exceptions import APIError

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


def test_get_totals_by_user_sums_per_user_and_sorts_descending(repo):
    created = repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=42)
    repo.add_entry(
        created["id"], telegram_user_id=1, amount=10, username="alice", display_name="Alice"
    )
    repo.add_entry(
        created["id"], telegram_user_id=2, amount=50, username="bob", display_name="Bob"
    )
    repo.add_entry(
        created["id"], telegram_user_id=1, amount=15, username="alice", display_name="Alice"
    )

    breakdown = repo.get_totals_by_user(created["id"])

    assert breakdown == [
        {"telegram_user_id": 2, "display_name": "Bob", "amount": 50},
        {"telegram_user_id": 1, "display_name": "Alice", "amount": 25},
    ]


def test_get_totals_by_user_falls_back_to_username_then_id(repo):
    created = repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=42)
    repo.add_entry(created["id"], telegram_user_id=1, amount=5, username="carol", display_name=None)
    repo.add_entry(created["id"], telegram_user_id=2, amount=5, username=None, display_name=None)

    breakdown = repo.get_totals_by_user(created["id"])
    names = {entry["telegram_user_id"]: entry["display_name"] for entry in breakdown}

    assert names[1] == "carol"
    assert names[2] == "2"


def test_get_totals_by_user_is_empty_for_challenge_with_no_entries(repo):
    created = repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=42)
    assert repo.get_totals_by_user(created["id"]) == []


# ── stories ───────────────────────────────────────────────────────────────


def _create_story(repo, slug="khane_avval", fill_order=None):
    template = "/==\\\n/====\\"
    return repo.create_story(
        slug=slug,
        title="The Dragon's Peak",
        story_text="The dragon sits at the summit...",
        template=template,
        fill_order=fill_order or [0, 1, 2, 3, 4, 5],
    )


def test_create_story_and_get_story_by_slug(repo):
    created = _create_story(repo)
    assert created["slug"] == "khane_avval"

    fetched = repo.get_story_by_slug("khane_avval")
    assert fetched["id"] == created["id"]


def test_get_story_by_slug_returns_none_when_absent(repo):
    assert repo.get_story_by_slug("does_not_exist") is None


def test_get_story_returns_by_id(repo):
    created = _create_story(repo)
    fetched = repo.get_story(created["id"])
    assert fetched["slug"] == "khane_avval"


def test_create_story_rejects_invalid_fill_order_permutation(repo):
    with pytest.raises(ValueError):
        repo.create_story(
            slug="bad_order",
            title="Bad",
            story_text="...",
            template="/==\\\n/====\\",
            fill_order=[0, 1, 2],  # wrong length — template has 6 fillable cells
        )


def test_create_story_rejects_duplicate_slug(repo):
    _create_story(repo)
    with pytest.raises(APIError) as exc_info:
        _create_story(repo)
    assert exc_info.value.code == "23505"


def test_create_challenge_with_story_id_links_challenge_to_story(repo):
    story = _create_story(repo)
    created = repo.create_challenge(
        chat_id=1, target_amount=300, unit="pushups", created_by=42, story_id=story["id"]
    )
    assert created["story_id"] == story["id"]


def test_create_challenge_without_story_id_defaults_to_none(repo):
    created = repo.create_challenge(chat_id=1, target_amount=300, unit="pushups", created_by=42)
    assert created["story_id"] is None
