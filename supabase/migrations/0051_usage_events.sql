-- ═══════════════════════════════════════════════════════════════════════════
-- READ BEFORE RUNNING
--
-- Not applied automatically — paste into the Supabase SQL Editor (staging
-- first, then production). Verified with scripts/db/test_usage_events.sh
-- (own insert, someone else's insert, reads, signed out, duplicates) on a
-- throwaway Postgres.
--
-- Purely additive: one new table. Older app versions never touch it.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Usage study events ────────────────────────────────────────────────────
-- One row per event the app logged (catalogue: docs/usage_study/
-- event_catalogue.md). Testers agreed to full behaviour analysis.
--
-- Write-only for the app: a signed-in user can insert rows for their own
-- account and see only their own rows' ids — no details, no changes. The admin
-- (Streamlit, service role) reads it, through the views in 0052.
create table if not exists public.usage_events (
  id           uuid primary key,              -- made on the device: retries can't double-count
  install_id   uuid not null,                 -- links events from before sign-in
  user_id      uuid not null default auth.uid()
                 references auth.users(id) on delete cascade,
  visit_id     uuid not null,
  seq          integer not null check (seq > 0),
  occurred_at  timestamptz not null,          -- device clock
  received_at  timestamptz not null default now(),
  event        text not null check (event ~ '^[a-z_]+\.[a-z_]+$' and length(event) <= 64),
  screen       text check (length(screen) <= 64),
  props        jsonb not null default '{}'::jsonb
                 check (jsonb_typeof(props) = 'object' and pg_column_size(props) <= 4096),
  app_version  text check (length(app_version) <= 32),
  platform     text check (length(platform) <= 16)
);

create index if not exists usage_events_user_time_idx
  on public.usage_events (user_id, occurred_at);
create index if not exists usage_events_event_time_idx
  on public.usage_events (event, occurred_at);
create index if not exists usage_events_visit_seq_idx
  on public.usage_events (visit_id, seq);

alter table public.usage_events enable row level security;

drop policy if exists "usage_events_insert_own" on public.usage_events;
create policy "usage_events_insert_own" on public.usage_events
  for insert to authenticated
  with check (user_id = auth.uid());

-- Postgres checks a row against SELECT policies whenever an insert names a
-- conflict target (`on conflict (id) do nothing`, which PostgREST sends for
-- the app's duplicate-safe upload). So own rows pass a select policy — but
-- the column grant below exposes only `id`: a user can see the ids of their
-- own events and nothing else.
drop policy if exists "usage_events_select_own_ids" on public.usage_events;
create policy "usage_events_select_own_ids" on public.usage_events
  for select to authenticated
  using (user_id = auth.uid());
-- No update/delete policy: no row can be changed or removed by the app.

-- Supabase grants everything on new public tables to anon/authenticated by
-- default; narrow that to inserting, for signed-in users only, plus reading
-- the `id` column (needed by `on conflict (id)`, see above).
do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    revoke all on public.usage_events from anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    revoke all on public.usage_events from authenticated;
    grant insert on public.usage_events to authenticated;
    grant select (id) on public.usage_events to authenticated;
  end if;
end $$;
