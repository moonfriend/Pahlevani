-- ═══════════════════════════════════════════════════════════════════════════
-- READ BEFORE RUNNING
--
-- This file is NOT applied automatically — no DB migration access was
-- available to the agent that wrote it (only the anon key in the app and a
-- service-role REST key in scripts/.streamlit/secrets.toml, neither of which
-- can run DDL). Paste this into the Supabase SQL Editor and run it yourself.
--
-- The one part that genuinely needs your judgment before running: section 3
-- enables Row Level Security on `training_session` for the first time (it
-- has never had RLS before — the app has always read it anonymously with
-- the anon key, unrestricted). If any *other* client/integration depends on
-- unrestricted anon-key reads of that table, this will break it. Given the
-- new app version requires login, this should be fine — but it's the one
-- irreversible-feeling step here, so check that assumption holds before
-- running.
--
-- Everything else (new tables, new nullable columns) is additive and safe —
-- existing rows in `training_session` get assigned_to_user_id = NULL, which
-- is exactly the correct "public/original training" meaning for them.
-- ═══════════════════════════════════════════════════════════════════════════


-- ── 1. profiles ───────────────────────────────────────────────────────────
-- One row per auth user. is_trainer is the *only* way a user becomes a
-- trainer — set manually by an admin (via scripts/admin.py), never by the
-- user themselves. consented_at records acceptance of the data-use notice
-- shown at signup.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  is_trainer boolean not null default false,
  consented_at timestamptz,
  created_at timestamptz not null default now()
);

create unique index if not exists profiles_email_idx on public.profiles (email);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);
-- No insert/delete policy for regular users — rows are created by the
-- trigger below; the admin tool uses the service-role key, which bypasses RLS.

-- Auto-create a profiles row whenever someone signs up.
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ── 2. trainer_roster ─────────────────────────────────────────────────────
-- Admin-managed only (via scripts/admin.py, service-role key). The app never
-- writes to this table — it only reads a trainer's own roster, or a
-- trainee's own trainer.

create table if not exists public.trainer_roster (
  id bigint generated always as identity primary key,
  trainer_id uuid not null references auth.users (id) on delete cascade,
  trainee_id uuid not null references auth.users (id) on delete cascade,
  -- Denormalized at link-creation time so the trainer's app can show who's
  -- on their roster without a separate cross-user read on `profiles` (RLS
  -- there only lets a user read their own row) — the admin already has this
  -- value, it's exactly what the trainee gave them to set up the link.
  trainee_email text not null,
  created_at timestamptz not null default now(),
  unique (trainer_id, trainee_id)
);

alter table public.trainer_roster enable row level security;

drop policy if exists "roster_select_own" on public.trainer_roster;
create policy "roster_select_own" on public.trainer_roster
  for select using (auth.uid() = trainer_id or auth.uid() = trainee_id);
-- No insert/update/delete policy for regular users — admin-only via service-role key.


-- ── 3. training_session: original vs. individualized ─────────────────────
-- assigned_to_user_id NULL  → "original training" (today's existing public
--   library — every existing row already satisfies this after the column is
--   added, no backfill needed).
-- assigned_to_user_id set   → visible only to that trainee; assigned_by_
--   trainer_id records which trainer built it, so a trainer's app can list
--   "sessions I assigned" via that column.

alter table public.training_session
  add column if not exists assigned_to_user_id uuid references auth.users (id) on delete set null,
  add column if not exists assigned_by_trainer_id uuid references auth.users (id) on delete set null;

create index if not exists training_session_assigned_to_idx
  on public.training_session (assigned_to_user_id);
create index if not exists training_session_assigned_by_idx
  on public.training_session (assigned_by_trainer_id);

-- First-time RLS enablement on this table — see the note at the top of this file.
alter table public.training_session enable row level security;

drop policy if exists "training_session_select_visible" on public.training_session;
create policy "training_session_select_visible" on public.training_session
  for select using (
    assigned_to_user_id is null
    or assigned_to_user_id = auth.uid()
    or assigned_by_trainer_id = auth.uid()
  );

drop policy if exists "training_session_trainer_write" on public.training_session;
create policy "training_session_trainer_write" on public.training_session
  for all using (assigned_by_trainer_id = auth.uid())
  with check (assigned_by_trainer_id = auth.uid());
-- Public/original-training rows (assigned_to_user_id IS NULL) are still
-- writable only via the service-role key (scripts/admin.py) — no policy
-- grants regular users insert/update/delete on those.
