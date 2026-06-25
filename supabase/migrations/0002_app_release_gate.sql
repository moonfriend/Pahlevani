-- ═══════════════════════════════════════════════════════════════════════════
-- READ BEFORE RUNNING
--
-- Not applied automatically — no DB migration access was available to the
-- agent that wrote this (same constraint as migration 0001). Paste into the
-- Supabase SQL Editor and run yourself.
--
-- Purely additive: a new single-row table, nothing else touched. Safe to run
-- at any time — force_update defaults to false, so it has zero effect on any
-- installed app version until you deliberately flip it.
-- ═══════════════════════════════════════════════════════════════════════════

-- One row, always id = 1. The app reads this — via the anon key, since an
-- old/never-logged-in install must be able to check it before any auth
-- happens — to decide whether it must block usage until updated.
create table if not exists public.app_release_gate (
  id int primary key default 1,
  min_supported_build_number int not null default 1,
  update_message text not null default 'A new version is available. Please update to continue.',
  force_update boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint app_release_gate_single_row check (id = 1)
);

insert into public.app_release_gate (id) values (1)
  on conflict (id) do nothing;

alter table public.app_release_gate enable row level security;

-- Readable by anyone, including the anon key with no session — this check
-- must work before a user has ever signed in.
drop policy if exists "app_release_gate_select_all" on public.app_release_gate;
create policy "app_release_gate_select_all" on public.app_release_gate
  for select using (true);
-- No insert/update/delete policy for regular users — writable only via the
-- service-role key (scripts/admin.py's "Release Gate" tab).

-- ═══════════════════════════════════════════════════════════════════════════
-- HOW TO USE THIS FOR A FUTURE BREAKING MIGRATION
--
-- 1. Ship the new schema additively (new nullable columns/tables only —
--    existing clients ignore columns they don't know about, no version gate
--    needed for that alone).
-- 2. Ship the new app version that depends on the new schema; let it roll
--    out and get tested while old installs keep working untouched.
-- 3. Once you're confident old installs should stop being used (e.g. the
--    new schema is about to actually diverge in a way old code can't
--    tolerate), set force_update = true and min_supported_build_number to
--    the new version's build number, via scripts/admin.py's Release Gate
--    tab. Old installs show the blocking update screen on next launch;
--    nothing server-side needs to change again for the *next* migration —
--    just repeat from step 1.
-- ═══════════════════════════════════════════════════════════════════════════
