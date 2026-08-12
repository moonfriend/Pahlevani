-- ═══════════════════════════════════════════════════════════════════════════
-- CHALLENGE BOT — group fitness challenge tracking (Telegram bot subsystem).
--
-- Written to exclusively by challenge_bot/ (service-role key, long-polling
-- process). Never read by the Flutter app or the anon/authenticated
-- PostgREST roles — RLS is enabled with zero policies (default-deny); only
-- the service-role key (which bypasses RLS) can touch these tables.
--
-- v1 scope: one active challenge per Telegram group at a time (enforced via
-- the partial unique index below, not app logic) with a running rep tally.
-- Per-user leaderboards are out of scope for v1, but challenge_entry already
-- stores telegram_user_id per row, so a `group by` query can add that later
-- with zero schema change.
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.challenge (
  id                          bigserial   primary key,
  chat_id                     bigint      not null,
  title                       text,
  target_amount               int         not null check (target_amount > 0),
  unit                        text        not null default 'reps',
  status                      text        not null default 'active'
                                          check (status in ('active', 'completed', 'cancelled')),
  created_by_telegram_user_id bigint,
  ends_at                     timestamptz,
  completed_at                timestamptz,
  created_at                  timestamptz not null default now()
);

comment on table public.challenge is
  'One row per group fitness challenge (e.g. "300 pushups by tomorrow"). '
  'At most one active row per chat_id — enforced by challenge_one_active_per_chat.';

-- Enforces "one active challenge per group" at the DB layer, not in app
-- logic, so it's a real constraint rather than an assumption baked into
-- query code. Supporting concurrent challenges per group later is just
-- dropping this index — no table redesign needed.
create unique index if not exists challenge_one_active_per_chat
  on public.challenge (chat_id)
  where status = 'active';

create table if not exists public.challenge_entry (
  id                    bigserial   primary key,
  challenge_id          bigint      not null references public.challenge(id) on delete cascade,
  telegram_user_id      bigint      not null,
  telegram_username     text,
  telegram_display_name text,
  amount                int         not null check (amount > 0),
  source                text        not null default 'text' check (source in ('command', 'text')),
  raw_message_text      text,
  telegram_message_id   bigint,
  created_at            timestamptz not null default now()
);

comment on table public.challenge_entry is
  'One row per parsed rep report. Running total = sum(amount) per challenge_id. '
  'telegram_user_id is stored per row so per-user breakdowns/leaderboards can '
  'be added later via GROUP BY, without a schema change.';

create index if not exists challenge_entry_challenge_id_idx
  on public.challenge_entry (challenge_id);

create index if not exists challenge_entry_challenge_user_idx
  on public.challenge_entry (challenge_id, telegram_user_id);

-- RLS enabled, no policies added: unlike movement/exercise/training_session
-- (anon-readable content tables), this data is never queried by the Flutter
-- app's anon client — only the bot's service-role key touches it, which
-- bypasses RLS entirely. No anon/authenticated grants needed.
alter table public.challenge       enable row level security;
alter table public.challenge_entry enable row level security;
