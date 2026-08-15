-- ═══════════════════════════════════════════════════════════════════════════
-- SESSION ASSIGNMENT — a trainer (public.profiles.is_trainer) can assign an
-- individualized session to a specific trainee. First migration to change
-- RLS behavior on training_session/training_session_item, which have been
-- blanket-public (`for select using (true)`, from 0001) since day one.
--
-- Backward-compat guarantee: every existing row gets is_public = true by
-- this migration's backfill, and the new select policy's first clause is
-- `is_public = true` — for an anonymous request auth.uid() is null, so the
-- other two clauses are unknown/false and every currently-public session
-- stays exactly as anon-readable as it is today. This must be live-verified
-- (curl the anon key for a known public session id) before/after applying,
-- not just assumed from reading this file — see 0007's incident for why.
--
-- Belt-and-suspenders grants alongside every policy, per the same lesson.
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.training_session
  add column if not exists is_public boolean not null default true,
  add column if not exists assigned_to_user_id uuid references auth.users(id) on delete set null,
  add column if not exists assigned_by_trainer_id uuid references auth.users(id) on delete set null;

create index if not exists training_session_assigned_to_idx
  on public.training_session (assigned_to_user_id);

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    grant select on public.training_session, public.training_session_item to anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant select on public.training_session, public.training_session_item to authenticated;
    grant insert, update on public.training_session to authenticated;
    grant insert, update, delete on public.training_session_item to authenticated;
  end if;
end $$;

drop policy if exists "training_session_select_all" on public.training_session;
create policy "training_session_select_all" on public.training_session
  for select using (
    is_public = true
    or assigned_to_user_id = auth.uid()
    or assigned_by_trainer_id = auth.uid()
  );

drop policy if exists "training_session_item_select_all" on public.training_session_item;
create policy "training_session_item_select_all" on public.training_session_item
  for select using (
    exists (
      select 1 from public.training_session ts
      where ts.id = training_session_item.training_session_id
        and (
          ts.is_public = true
          or ts.assigned_to_user_id = auth.uid()
          or ts.assigned_by_trainer_id = auth.uid()
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
drop policy if exists "training_session_trainer_insert" on public.training_session;
create policy "training_session_trainer_insert" on public.training_session
  for insert
  with check (public.is_trainer(auth.uid()) and assigned_by_trainer_id = auth.uid());

drop policy if exists "training_session_trainer_update" on public.training_session;
create policy "training_session_trainer_update" on public.training_session
  for update
  using (public.is_trainer(auth.uid()) and assigned_by_trainer_id = auth.uid())
  with check (public.is_trainer(auth.uid()) and assigned_by_trainer_id = auth.uid());

drop policy if exists "training_session_item_trainer_write" on public.training_session_item;
create policy "training_session_item_trainer_write" on public.training_session_item
  for all
  using (
    exists (
      select 1 from public.training_session ts
      where ts.id = training_session_item.training_session_id
        and ts.assigned_by_trainer_id = auth.uid()
        and public.is_trainer(auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.training_session ts
      where ts.id = training_session_item.training_session_id
        and ts.assigned_by_trainer_id = auth.uid()
        and public.is_trainer(auth.uid())
    )
  );
