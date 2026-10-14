-- ═══════════════════════════════════════════════════════════════════════════
-- READ BEFORE RUNNING
--
-- Not applied automatically — paste into the Supabase SQL Editor (staging
-- first, then production). Verified with scripts/db/test_activation_gate.sh
-- (activated / not-activated / signed-out users on a throwaway Postgres).
--
-- ⚠️ NOT purely additive: after this, the training content (sessions, moves,
-- recordings, media, path, fitness test) is readable ONLY by activated
-- accounts and trainers. Every app version without the activation step —
-- including the Play Store build and anyone signed out — sees no content.
-- On production, apply it together with the release and raise the release
-- gate (app_release_gate) so old versions are asked to update.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── Activations: which account redeemed which code ────────────────────────
-- One row per activated account. The email is copied here at redemption
-- time so the monthly "still a Patreon member?" check reads one table.
create table if not exists public.activations (
  user_id        uuid primary key references auth.users(id) on delete cascade,
  invite_code_id bigint references public.invite_codes(id) on delete set null,
  code           text not null,
  email          text,
  activated_at   timestamptz not null default now()
);

alter table public.activations enable row level security;

drop policy if exists "activations_select_own" on public.activations;
create policy "activations_select_own" on public.activations
  for select using (user_id = auth.uid());
-- No insert/update/delete policy: rows are written only by
-- redeem_activation_code() below (security definer) or the service role.

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant select on public.activations to authenticated;
  end if;
end $$;

-- ── Is the signed-in user allowed to see the content? ─────────────────────
-- Activated accounts, plus trainers (our inner team), who build and assign
-- sessions without a code.
create or replace function public.is_activated()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null and (
    exists (select 1 from public.activations a where a.user_id = auth.uid())
    or exists (select 1 from public.profiles p
               where p.id = auth.uid() and p.is_trainer)
  );
$$;

-- ── Redeem a code for the signed-in account ───────────────────────────────
-- Counts one use of the code (respecting max_uses and revocation, like the
-- sign-up trigger in 0016) and records code + email. Redeeming again once
-- activated is a no-op, so a retry after a dropped connection is safe.
create or replace function public.redeem_activation_code(input_code text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  cleaned text := trim(input_code);
  matched_id bigint;
  user_email text;
begin
  if uid is null then
    raise exception 'not_signed_in';
  end if;
  if exists (select 1 from public.activations where user_id = uid) then
    return true;
  end if;

  update public.invite_codes
  set uses_count = uses_count + 1
  where code = cleaned
    and revoked_at is null
    and (max_uses is null or uses_count < max_uses)
  returning id into matched_id;

  if matched_id is null then
    raise exception 'invalid_activation_code';
  end if;

  select email into user_email from auth.users where id = uid;
  insert into public.activations (user_id, invite_code_id, code, email)
  values (uid, matched_id, cleaned, user_email);
  return true;
end;
$$;

-- ── Delete my account ─────────────────────────────────────────────────────
-- Deletes the signed-in user. Their profile, activation and assignments go
-- with it (on delete cascade); sessions they authored stay, unowned.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_signed_in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

do $$
begin
  revoke all on function public.is_activated() from public;
  revoke all on function public.redeem_activation_code(text) from public;
  revoke all on function public.delete_my_account() from public;
  if exists (select 1 from pg_roles where rolname = 'anon') then
    grant execute on function public.is_activated() to anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.is_activated() to authenticated;
    grant execute on function public.redeem_activation_code(text) to authenticated;
    grant execute on function public.delete_my_account() to authenticated;
  end if;
end $$;

-- ── Locked screen: message and link, set in admin ─────────────────────────
create table if not exists public.activation_gate (
  id         smallint primary key default 1 check (id = 1),
  message    text not null check (length(trim(message)) > 0),
  link_label text not null default 'Get your code on Patreon',
  link_url   text not null check (link_url ~ '^https://'),
  updated_at timestamptz not null default now()
);

alter table public.activation_gate enable row level security;
-- Readable by anyone: the locked screen shows before activation.
drop policy if exists "activation_gate_select_all" on public.activation_gate;
create policy "activation_gate_select_all" on public.activation_gate
  for select using (true);

insert into public.activation_gate (id, message, link_url)
values (1,
  'Pahlevani is for our Patreon members. Join on Patreon and you''ll get '
  'your activation code within a day.',
  'https://www.patreon.com/')
on conflict (id) do nothing;

-- ── Consent: which terms version, and marketing emails (optional) ─────────
alter table public.profiles
  add column if not exists terms_version integer,
  add column if not exists marketing_opt_in boolean not null default false;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant update (terms_version, marketing_opt_in) on public.profiles to authenticated;
  end if;
end $$;

-- ── The gate: content readable only when activated ────────────────────────
-- Replaces every SELECT policy on the content tables (whatever they are
-- named on this database) with one that also requires is_activated().
-- `(select public.is_activated())` is evaluated once per query, not per row.
-- Tables that don't exist on this database (e.g. path before 0035) are
-- skipped.
do $$
declare
  t text;
  p record;
begin
  foreach t in array array[
    'exercise', 'movement', 'movement_info', 'movement_type',
    'movement_audio_track', 'morshed', 'video', 'media_asset',
    'path', 'path_node', 'path_node_item',
    'fitness_test_chart', 'fitness_test_axis', 'fitness_test_subtest',
    'fitness_test_level'
  ] loop
    if to_regclass('public.' || t) is null then
      continue;
    end if;
    for p in select policyname from pg_policies
             where schemaname = 'public' and tablename = t and cmd = 'SELECT'
    loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format(
      'create policy %I on public.%I for select using ((select public.is_activated()))',
      t || '_select_activated', t);
  end loop;
end $$;

-- Sessions keep their visibility rules (public, mine, or assigned to me)
-- and add the activation requirement.
drop policy if exists "training_session_select_all" on public.training_session;
drop policy if exists "training_session_select_activated" on public.training_session;
create policy "training_session_select_activated" on public.training_session
  for select using (
    (select public.is_activated())
    and (
      is_public = true
      or owner_trainer_id = auth.uid()
      or exists (
        select 1 from public.session_assignments sa
        where sa.session_id = training_session.id
          and sa.trainee_user_id = auth.uid()
      )
    )
  );

drop policy if exists "training_session_item_select_all" on public.training_session_item;
drop policy if exists "training_session_item_select_activated" on public.training_session_item;
create policy "training_session_item_select_activated" on public.training_session_item
  for select using (
    (select public.is_activated())
    and exists (
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
