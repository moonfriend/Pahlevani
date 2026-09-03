# Challenge Bot

Telegram bot for group fitness challenges (e.g. "let's all do 300 push-ups by tomorrow").
Members log reps via `/log <amount>` or free text ("I did 30 push ups"); the bot keeps a
silent running tally per group and reports the total on `/total`.

Self-contained Python project — independent of the `scripts/` admin tooling elsewhere in
this repo. Managed with [uv](https://docs.astral.sh/uv/).

## Setup (local dev)

```bash
cd challenge_bot
uv sync
cp ../env/challenge_bot.env.example ../env/challenge_bot.env   # fill in TELEGRAM_BOT_TOKEN
```

`SUPABASE_URL`/`SUPABASE_SERVICE_ROLE_KEY` are sourced automatically from the admin
creds vault (`~/StudioProjects/pahlevani-admin-creds/`) when you run via `run.sh` — see
below. They're a **service-role key** — the bot writes to tables with RLS enabled and no
policies, so only the service-role key (which bypasses RLS) can use them.

Apply `supabase/migrations/0008_challenge_bot.sql`, `0009_challenge_story.sql`, and
`0010_challenge_story_cursor_glyph.sql` in order (see the repo-root `supabase/` setup)
before running the bot for the first time — they create the `challenge`,
`challenge_entry`, and `challenge_story` tables this project reads and writes.

### BotFather setup (required)

Telegram bots default to *privacy mode* in groups, meaning they only receive messages
that are commands or explicit mentions/replies — **not** plain text like "I did 30 push
ups". Without disabling this, the free-text logging path silently receives nothing.

1. Message [@BotFather](https://t.me/BotFather), `/mybots` → select your bot.
2. `Bot Settings` → `Group Privacy` → `Turn off` (or `/setprivacy` → select bot → `Disable`).
3. Re-add the bot to the group (or have it re-join) if it was already a member.

## Running the bot

```bash
bash run.sh
```

Long-polling — no webhook, no public HTTPS endpoint needed.

### Deployment

See [`DEPLOY.md`](DEPLOY.md) for a full VPS walkthrough (deploy key, systemd service,
updating, migration ordering).

## Commands

| Command | Effect |
|---|---|
| `/challenge <target> [unit]` | Start a group challenge, e.g. `/challenge 300 pushups` |
| `/start_challenge <slug> <target> [unit]` | Start a story-driven challenge bound to an admin-authored story, e.g. `/start_challenge khane_avval 300 pushups` — posts the story text plus starting ASCII art |
| `/log <amount> [unit]` | Log a rep count (silent ack via emoji reaction) |
| *free text* (e.g. "I did 30 push ups") | Same as `/log`, best-effort parsed |
| `/total` or `/status` | Report the running total, plus a per-user breakdown sorted highest first. For a story-driven challenge, also shows the current ASCII-art progress above the totals |
| `/end` | Close the active challenge |
| `/help` (or `/start`) | List commands |

Output is intentionally minimal: logging a rep count only triggers an emoji reaction, not
a text reply. Messages that don't parse are ignored entirely — no error replies.

### Story mode

A "story" is a reusable ASCII-art template (a paragraph of story text plus an art template
using `=` for fillable cells) authored once in the admin UI and given a slug. The same
story can be run against any number of groups via `/start_challenge <slug> <target> [unit]`
— each run gets its own target amount, so the conversion pace ("how many reps fill one
`=`") is computed per-run from that target and the template's symbol count, not stored on
the story itself. Nothing is posted anywhere until `/start_challenge` is actually run in a
group.

A story can optionally set a **cursor glyph** (e.g. 🧗) — shown in place of the
most-recently-converted `=` symbol, giving a lightweight sense of the current progress
position. It only appears once at least one symbol has converted (never on the zero-rep
kickoff announcement), and disappears once the art switches to the completion art.

## Admin UI

A Streamlit app with two tabs:
- **Challenges** — browse challenge data (list challenges, view entry logs, manually
  cancel/close a challenge).
- **Stories** — author story templates: paste the `=`-template, pick a fill-order preset
  (reading order / reverse-bottom-up / a custom comma-separated order) with a live preview,
  optionally set a cursor glyph, and save. Existing stories can also be edited here.

```bash
bash run.sh --admin
```

## Tests

```bash
uv run pytest
```

Unit tests only — no live Telegram bot or live Supabase required.
