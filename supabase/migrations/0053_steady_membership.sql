-- ═══════════════════════════════════════════════════════════════════════════
-- READ BEFORE RUNNING
--
-- Not applied automatically — paste into the Supabase SQL Editor (staging
-- first, then production). Verified with scripts/db/test_activation_gate.sh.
--
-- Steady memberships unlock the app (Sign in with Steady). Additive for
-- existing users: code activations keep working and never expire.
--
--   * activations gets source (code | steady), expires_at, steady_state and
--     checked_at. A Steady activation always has an end date; codes have none.
--   * is_activated() ignores activations whose end date has passed.
--   * Three server-only functions (service role, used by the steady-sync Edge
--     Function): read a user's Steady email from their Steady identity, list
--     all Steady sign-ins (daily re-check), and set a user's Steady access.
--     Clients can call none of them.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── activations: where the access comes from, and until when ──────────────
alter table public.activations alter column code drop not null;
alter table public.activations
  add column if not exists source text not null default 'code',
  add column if not exists expires_at timestamptz,
  add column if not exists steady_state text,
  add column if not exists checked_at timestamptz;

alter table public.activations drop constraint if exists activations_source_check;
alter table public.activations add constraint activations_source_check
  check (source in ('code', 'steady'));
-- Codes are permanent and named; Steady access always ends unless renewed.
alter table public.activations drop constraint if exists activations_source_shape;
alter table public.activations add constraint activations_source_shape check (
  (source = 'code' and code is not null and expires_at is null)
  or (source = 'steady' and expires_at is not null)
);

-- ── Is the signed-in user allowed to see the content? ─────────────────────
-- As in 0045, plus: an activation counts only until its end date.
create or replace function public.is_activated()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null and (
    exists (select 1 from public.activations a
            where a.user_id = auth.uid()
              and (a.expires_at is null or a.expires_at > now()))
    or exists (select 1 from public.profiles p
               where p.id = auth.uid() and p.is_trainer)
  );
$$;

-- ── Redeem a code ─────────────────────────────────────────────────────────
-- As in 0045, but a lapsed Steady membership no longer blocks a code: the
-- code replaces it and lasts. A still-running activation stays a no-op.
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
  if exists (select 1 from public.activations
             where user_id = uid
               and (expires_at is null or expires_at > now())) then
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
  insert into public.activations (user_id, invite_code_id, code, email, source)
  values (uid, matched_id, cleaned, user_email, 'code')
  on conflict (user_id) do update
    set invite_code_id = excluded.invite_code_id,
        code           = excluded.code,
        email          = excluded.email,
        source         = 'code',
        expires_at     = null,
        steady_state   = null,
        activated_at   = now();
  return true;
end;
$$;

-- ── Server only: the email of a user's Steady identity ────────────────────
-- Taken from the identity Steady itself reported, never from anything the
-- app sends, so nobody can claim someone else's membership.
create or replace function public.steady_identity_email(p_user uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select i.identity_data ->> 'email'
  from auth.identities i
  where i.user_id = p_user and i.provider = 'custom:steady'
  order by i.updated_at desc
  limit 1;
$$;

-- ── Server only: everyone who signed in with Steady (daily re-check) ──────
create or replace function public.steady_members()
returns table (user_id uuid, email text)
language sql
stable
security definer
set search_path = public
as $$
  select distinct on (i.user_id) i.user_id, i.identity_data ->> 'email'
  from auth.identities i
  where i.provider = 'custom:steady' and i.identity_data ? 'email'
  order by i.user_id, i.updated_at desc;
$$;

-- ── Server only: record what Steady said about a user's membership ────────
-- p_has_access: Steady lists a current subscription for the user's email.
-- Code activations are never touched: a Steady check can't take them away.
create or replace function public.steady_apply_membership(
  p_user uuid,
  p_has_access boolean,
  p_expires_at timestamptz,
  p_state text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (select 1 from public.activations
             where user_id = p_user and source = 'code') then
    return;
  end if;

  if p_has_access then
    if p_expires_at is null then
      raise exception 'expires_at_required';
    end if;
    insert into public.activations
      (user_id, source, email, expires_at, steady_state, checked_at)
    values
      (p_user, 'steady', (select email from auth.users where id = p_user),
       p_expires_at, p_state, now())
    on conflict (user_id) do update
      set expires_at   = excluded.expires_at,
          steady_state = excluded.steady_state,
          email        = excluded.email,
          checked_at   = now();
  else
    update public.activations
    set expires_at   = least(expires_at, now()),
        steady_state = p_state,
        checked_at   = now()
    where user_id = p_user and source = 'steady';
  end if;
end;
$$;

-- Supabase lets anon/authenticated execute new functions by default; revoke
-- by name so only the service role (Edge Functions) can use these three.
do $$
declare
  fn text;
begin
  foreach fn in array array[
    'public.steady_identity_email(uuid)',
    'public.steady_members()',
    'public.steady_apply_membership(uuid, boolean, timestamptz, text)'
  ] loop
    execute format('revoke all on function %s from public', fn);
    if exists (select 1 from pg_roles where rolname = 'anon') then
      execute format('revoke all on function %s from anon', fn);
    end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
      execute format('revoke all on function %s from authenticated', fn);
    end if;
    if exists (select 1 from pg_roles where rolname = 'service_role') then
      execute format('grant execute on function %s to service_role', fn);
    end if;
  end loop;
end $$;
