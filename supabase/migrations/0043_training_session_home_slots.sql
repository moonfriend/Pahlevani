-- ═══════════════════════════════════════════════════════════════════════════
-- READ BEFORE RUNNING
--
-- Not applied automatically — paste into the Supabase SQL Editor (staging
-- first, then production). Verified against a throwaway Postgres with
-- scripts/test_migration.sh.
--
-- Purely additive: two nullable/defaulted columns on training_session, so
-- installed app versions (which ignore unknown columns) are unaffected.
-- ═══════════════════════════════════════════════════════════════════════════

-- Which sessions Home shows, set from scripts/admin.py's Session builder:
-- 1 = the main card, 2 and 3 = the two small cards, null = not on Home.
-- A trainer-assigned session overrides slot 1 for its trainee (app side).
alter table public.training_session
  add column if not exists home_position smallint
    check (home_position between 1 and 3);

-- One session per slot.
create unique index if not exists training_session_home_position_key
  on public.training_session (home_position)
  where home_position is not null;

-- The session uses meel, so Home tags it for people who don't have meel yet.
alter table public.training_session
  add column if not exists needs_meel boolean not null default false;
