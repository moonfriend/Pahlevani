# Challenge Bot

Telegram bot for group fitness challenges (e.g. "let's all do 300 push-ups by tomorrow").
Members log reps via `/log <amount>` or free text ("I did 30 push ups"); the bot keeps a
silent running tally per group and reports the total on `/total`.

Self-contained Python project — independent of the `scripts/` admin tooling elsewhere in
this repo. Managed with [uv](https://docs.astral.sh/uv/).

## Setup

```bash
cd challenge_bot
uv sync
cp .env.example .env   # fill in TELEGRAM_BOT_TOKEN, SUPABASE_URL, SUPABASE_KEY
```

`SUPABASE_KEY` must be the **service-role key** — the bot writes to tables with RLS
enabled and no policies, so only the service-role key (which bypasses RLS) can use them.

Apply `supabase/migrations/0008_challenge_bot.sql` (see the repo-root `supabase/` setup)
before running the bot for the first time — it creates the `challenge` and
`challenge_entry` tables this project reads and writes.

### BotFather setup (required)

Telegram bots default to *privacy mode* in groups, meaning they only receive messages
that are commands or explicit mentions/replies — **not** plain text like "I did 30 push
ups". Without disabling this, the free-text logging path silently receives nothing.

1. Message [@BotFather](https://t.me/BotFather), `/mybots` → select your bot.
2. `Bot Settings` → `Group Privacy` → `Turn off` (or `/setprivacy` → select bot → `Disable`).
3. Re-add the bot to the group (or have it re-join) if it was already a member.

## Running the bot

```bash
uv run python main.py
```

Long-polling — no webhook, no public HTTPS endpoint needed.

### Deployment (systemd example)

```ini
[Unit]
Description=Challenge Bot (Telegram)
After=network.target

[Service]
WorkingDirectory=/path/to/Pahlevani/challenge_bot
EnvironmentFile=/path/to/Pahlevani/challenge_bot/.env
ExecStart=/path/to/uv run python main.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

## Commands

| Command | Effect |
|---|---|
| `/challenge <target> [unit]` | Start a group challenge, e.g. `/challenge 300 pushups` |
| `/log <amount> [unit]` | Log a rep count (silent ack via emoji reaction) |
| *free text* (e.g. "I did 30 push ups") | Same as `/log`, best-effort parsed |
| `/total` or `/status` | Report the running total |
| `/end` | Close the active challenge |
| `/help` (or `/start`) | List commands |

Output is intentionally minimal: logging a rep count only triggers an emoji reaction, not
a text reply. Messages that don't parse are ignored entirely — no error replies.

## Admin UI

A Streamlit app for browsing/managing challenge data (list challenges, view entry logs,
manually cancel/close a challenge):

```bash
uv run streamlit run bot_admin.py
```

## Tests

```bash
uv run pytest
```

Unit tests only — no live Telegram bot or live Supabase required.
