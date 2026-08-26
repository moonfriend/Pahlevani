-- ═══════════════════════════════════════════════════════════════════════════
-- SESSION ASSIGNMENT — a trainer (public.profiles.is_trainer) can assign a
-- session to any number of trainees via session_assignments, a join table.
-- (Superseded design, safe to rewrite in place: this file was applied to
-- staging with a single assigned_to_user_id column on training_session,
-- allowing at most one assignee per session row. Every statement below is
-- idempotent against either a fresh database or that earlier state.)
--
-- First migration to change RLS behavior on training_session/
-- training_session_item, which have been blanket-public
-- (`for select using (true)`, from 0001) since day one.
--
-- Backward-compat guarantee: every existing row gets is_public = true by
-- this migration's backfill, and the new select policy's first clause is
-- `is_public = true` — for an anonymous request auth.uid() is null, so the
-- other clauses are unknown/false and every currently-public session stays
-- exactly as anon-readable as it is today. This must be live-verified (curl
-- the anon key for a known public session id) before/after applying, not
-- just assumed from reading this file — see 0007's incident for why.
--
-- Belt-and-suspenders grants alongside every policy, per the same lesson.
-- ═══════════════════════════════════════════════════════════════════════════

-- Drop policies that reference the columns being renamed/dropped below,
-- before touching the columns themselves.
drop policy if exists "training_session_select_all" on public.training_session;
drop policy if exists "training_session_trainer_insert" on public.training_session;
drop policy if exists "training_session_trainer_update" on public.training_session;
drop policy if exists "training_session_item_select_all" on public.training_session_item;
drop policy if exists "training_session_item_trainer_write" on public.training_session_item;

drop index if exists training_session_assigned_to_idx;

-- Carry forward any already-set ownership from the superseded
-- assigned_by_trainer_id column — no-op on a fresh database.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'training_session'
      and column_name = 'assigned_by_trainer_id'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'training_session'
      and column_name = 'owner_trainer_id'
  ) then
    alter table public.training_session
      rename column assigned_by_trainer_id to owner_trainer_id;
  end if;
end $$;

alter table public.training_session
  add column if not exists is_public boolean not null default true,
  -- The trainer who authored this private session, if any (null for public
  -- catalog sessions). Deliberately not paired with a single assignee —
  -- who can see it is session_assignments' job.
  add column if not exists owner_trainer_id uuid references auth.users(id) on delete set null,
  drop column if exists assigned_to_user_id;

create table if not exists public.session_assignments (
  id                     bigserial primary key,
  session_id             int not null references public.training_session(id) on delete cascade,
  trainee_user_id        uuid not null references auth.users(id) on delete cascade,
  assigned_by_trainer_id uuid references auth.users(id) on delete set null,
  assigned_at            timestamptz not null default now(),
  -- Free-text context from the trainee — often empty, sometimes a full
  -- paragraph (injury notes, goals, etc.). Trainee-writable on their own
  -- assignment row; see the column-scoped grant below.
  trainee_note           text,
  unique (session_id, trainee_user_id)
);

create index if not exists session_assignments_trainee_idx
  on public.session_assignments (trainee_user_id);

alter table public.session_assignments enable row level security;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    grant select on public.training_session, public.training_session_item to anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant select on public.training_session, public.training_session_item to authenticated;
    grant insert, update on public.training_session to authenticated;
    grant insert, update, delete on public.training_session_item to authenticated;
    -- session_assignments: no anon grant at all — this is private data with
    -- no anonymous use case. Trainees only ever update their own note.
    grant select, insert on public.session_assignments to authenticated;
    grant update (trainee_note) on public.session_assignments to authenticated;
  end if;
end $$;

create policy "training_session_select_all" on public.training_session
  for select using (
    is_public = true
    or owner_trainer_id = auth.uid()
    or exists (
      select 1 from public.session_assignments sa
      where sa.session_id = training_session.id and sa.trainee_user_id = auth.uid()
    )
  );

create policy "training_session_item_select_all" on public.training_session_item
  for select using (
    exists (
      select 1 from public.training_session ts
      where ts.id = training_session_item.training_session_id
        and (
          ts.is_public = true
          or ts.owner_trainer_id = auth.uid()
          or exists (
            select 1 from public.session_assignments sa
            where sa.session_id = ts.id and sa.trainee_user_id = auth.uid()
          )
        )
    )
  );

-- Trainer-only writes. Anon/regular-trainee still have no insert/update/
-- delete policy on either table, so the public catalog (admin.py-authored
-- rows) stays immutable from the app regardless of the grants above.
-- No explicit "to authenticated" — the predicate itself already excludes
-- anon (is_trainer(auth.uid()) is false when auth.uid() is null), and
-- "to authenticated" requires that role to exist at DDL time, which a bare
-- local Postgres (scripts/test_migration.sh) doesn't have.
create policy "training_session_trainer_insert" on public.training_session
  for insert
  with check (public.is_trainer(auth.uid()) and owner_trainer_id = auth.uid());

create policy "training_session_trainer_update" on public.training_session
  for update
  using (public.is_trainer(auth.uid()) and owner_trainer_id = auth.uid())
  with check (public.is_trainer(auth.uid()) and owner_trainer_id = auth.uid());

create policy "training_session_item_trainer_write" on public.training_session_item
  for all
  using (
    exists (
      select 1 from public.training_session ts
      where ts.id = training_session_item.training_session_id
        and ts.owner_trainer_id = auth.uid()
        and public.is_trainer(auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.training_session ts
      where ts.id = training_session_item.training_session_id
        and ts.owner_trainer_id = auth.uid()
        and public.is_trainer(auth.uid())
    )
  );

drop policy if exists "session_assignments_select" on public.session_assignments;
create policy "session_assignments_select" on public.session_assignments
  for select using (
    trainee_user_id = auth.uid() or public.is_trainer(auth.uid())
  );

-- A trainer may only assign sessions they own themselves.
drop policy if exists "session_assignments_trainer_insert" on public.session_assignments;
create policy "session_assignments_trainer_insert" on public.session_assignments
  for insert
  with check (
    public.is_trainer(auth.uid())
    and assigned_by_trainer_id = auth.uid()
    and exists (
      select 1 from public.training_session ts
      where ts.id = session_id and ts.owner_trainer_id = auth.uid()
    )
  );

-- Trainee edits only their own note (enforced further by the column-scoped
-- grant above — session_id/trainee_user_id aren't grantable at all).
drop policy if exists "session_assignments_trainee_update" on public.session_assignments;
create policy "session_assignments_trainee_update" on public.session_assignments
  for update
  using (trainee_user_id = auth.uid())
  with check (trainee_user_id = auth.uid());
