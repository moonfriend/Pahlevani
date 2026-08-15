-- ═══════════════════════════════════════════════════════════════════════════
-- PROFILES + DATA-PRIVACY CONSENT — foundation for optional login.
--
-- One profiles row per auth.users row, auto-created via a trigger on signup.
-- Login stays opt-in app-wide: anonymous users never touch this table.
--
-- is_trainer is deliberately NOT writable by anon/authenticated — only the
-- service-role key (scripts/admin.py) can grant it. No self-serve trainer
-- promotion.
--
-- Lesson carried over from 0007_app_release_gate_v2.sql's production
-- incident (RLS enabled with zero attached policies silently returns
-- `200 + []` to anon/authenticated instead of an error — indistinguishable
-- from an empty table): every grant below is explicit and idempotent
-- alongside its policy, not left to implicit default privileges.
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.profiles (
  id               uuid primary key references auth.users(id) on delete cascade,
  email            text,
  is_trainer       boolean not null default false,
  consent_accepted boolean not null default false,
  consented_at     timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- Auto-populate a profile row on signup. The client also has an own-row
-- insert fallback (see policies below) in case this hasn't landed yet by
-- the time the client tries to read/write its own row.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Lets RLS policies (here and on later tables — training_session,
-- activity_log) check "is this uid a trainer?" without the self-referential
-- RLS recursion risk of a table policy subquerying its own table. Runs as
-- the migration-owning role (bypasses RLS internally); callable by anyone.
create or replace function public.is_trainer(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select p.is_trainer from public.profiles p where p.id = uid), false);
$$;

alter table public.profiles enable row level security;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    grant select on public.profiles to anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant select on public.profiles to authenticated;
    -- Fallback insert path only (the trigger is the primary path). Deliberately
    -- column-scoped: is_trainer/consent fields are not client-insertable.
    grant insert (id, email) on public.profiles to authenticated;
    -- consent_accepted/consented_at only — is_trainer is never client-writable,
    -- grantable only via the service-role key from scripts/admin.py.
    grant update (email, consent_accepted, consented_at) on public.profiles to authenticated;
    grant execute on function public.is_trainer(uuid) to anon, authenticated;
  end if;
end $$;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);

-- Lets a trainer list all trainees for the assign-session picker — no
-- roster-linking table needed while there's a single trainer (see plan).
drop policy if exists "profiles_select_trainer_all" on public.profiles;
create policy "profiles_select_trainer_all" on public.profiles
  for select using (public.is_trainer(auth.uid()));

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- No delete policy — profile rows are removed only via the auth.users
-- cascade. No policy or grant anywhere lets anon/authenticated write
-- is_trainer.
