-- ═══════════════════════════════════════════════════════════════════════════
-- INVITE-CODE SIGNUP — admin-managed username/password accounts for
-- students, gated by a trainer-issued code instead of email verification.
--
-- Rationale: real email-based signup + manual approval doesn't fit
-- Supabase's model — auth.users gets its row immediately regardless of
-- confirmation state, and there's no built-in "pending approval". An
-- invite code enforced by a database trigger gives a hard, unbypassable
-- gate instead: no valid code, no account, full stop — checked before the
-- auth.users row is even allowed to exist.
--
-- "Username" accounts still use Supabase's real email/password auth under
-- the hood (see AuthRepositoryImpl.signUpWithInviteCode) — the client
-- synthesizes a fake address from the username. This requires "Confirm
-- email" to be OFF for this project (a confirmation link to a synthetic
-- inbox can never be clicked) — already coordinated with the user;
-- AuthPage doesn't expose plain email signup to real users, so this has no
-- effect on any other flow.
-- ═══════════════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto;

create table if not exists public.invite_codes (
  id          bigserial primary key,
  -- sha256 hex digest of the plaintext code — the plaintext is shown to
  -- the trainer exactly once at creation time (scripts/admin.py) and never
  -- stored. May be trainer-chosen (e.g. a class name) rather than randomly
  -- generated — admin.py warns about the guessability trade-off when that
  -- option is used, but the schema/trigger don't distinguish the two.
  code_hash   text not null unique,
  -- Trainer's own label for the code — "Fall 2026 Class A", a specific
  -- student's name, etc. Purely for the trainer's own bookkeeping.
  label       text,
  created_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  -- Null = still valid. Revoking never deletes the row, so
  -- profiles.signed_up_via_invite_code_id keeps resolving for existing
  -- signups.
  revoked_at  timestamptz,
  -- Null = unlimited. Quota is fixed at creation time — raising it later
  -- isn't supported; revoke and issue a new code instead, to keep this
  -- simple.
  max_uses    integer,
  -- Incremented atomically by check_invite_code() below, in the same
  -- statement that validates the code — see that function's comment for
  -- why this has to be one atomic UPDATE rather than a separate
  -- check-then-increment (a race between two simultaneous signups right at
  -- the quota boundary).
  uses_count  integer not null default 0,
  constraint invite_codes_max_uses_positive check (max_uses is null or max_uses > 0)
);

-- No anon/authenticated grants at all, deliberately — the trainer manages
-- these exclusively via the service-role key (scripts/admin.py), same
-- pattern as challenge/challenge_entry/challenge_story in
-- 0008_challenge_bot.sql. Neither the client app nor RLS ever reads this
-- table directly; the trigger below (security definer) is the only thing
-- that touches it during signup.
alter table public.invite_codes enable row level security;

-- Tracks which code (if any) a profile signed up with — null for Google
-- sign-ins and any other non-invite-code auth method.
alter table public.profiles
  add column if not exists signed_up_via_invite_code_id bigint
    references public.invite_codes(id) on delete set null;

-- Hard gate: rejects the auth.users insert outright if this is an
-- invite-code signup (raw_user_meta_data.signup_method = 'invite_code')
-- and the submitted code doesn't match a live, non-revoked, under-quota
-- row. Scoped to that one metadata flag specifically — Google sign-in and
-- any other auth method never sets it, so they pass through untouched
-- here.
--
-- The validity check and the usage-count increment happen in one atomic
-- UPDATE ... RETURNING, not a separate SELECT-then-UPDATE — Postgres takes
-- a row lock for the UPDATE, so two signups racing for the last slot on a
-- quota-limited code serialize correctly instead of both reading
-- uses_count before either increments it (which would let a quota=1 code
-- be used twice). If the whole transaction later fails for an unrelated
-- reason, this increment rolls back with it, same as everything else in
-- the transaction.
create or replace function public.check_invite_code()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  matched_id bigint;
begin
  if new.raw_user_meta_data->>'signup_method' is distinct from 'invite_code' then
    return new;
  end if;

  if new.raw_user_meta_data->>'invite_code' is null then
    raise exception 'invalid_invite_code';
  end if;

  update public.invite_codes
  set uses_count = uses_count + 1
  where code_hash = encode(digest(new.raw_user_meta_data->>'invite_code', 'sha256'), 'hex')
    and revoked_at is null
    and (max_uses is null or uses_count < max_uses)
  returning id into matched_id;

  if matched_id is null then
    raise exception 'invalid_invite_code';
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_check_invite_code on auth.users;
create trigger on_auth_user_created_check_invite_code
  before insert on auth.users
  for each row execute function public.check_invite_code();

-- Client-side pre-check, called via RPC before attempting signUp() at all.
-- The trigger above is the actual enforced gate (a client could skip this
-- and still be rejected) — this exists so the app can show a friendly
-- "invalid code" error immediately, rather than relying on parsing
-- whatever error text GoTrue wraps a rejected-trigger Postgres exception
-- in, which isn't a documented/stable format. Same anon-executable,
-- security-definer pattern as is_trainer() — never exposes the
-- invite_codes table itself, just a yes/no answer.
create or replace function public.is_invite_code_valid(code text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.invite_codes
    where code_hash = encode(digest(code, 'sha256'), 'hex')
      and revoked_at is null
      and (max_uses is null or uses_count < max_uses)
  );
$$;

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'anon') then
    grant execute on function public.is_invite_code_valid(text) to anon;
  end if;
  if exists (select 1 from pg_roles where rolname = 'authenticated') then
    grant execute on function public.is_invite_code_valid(text) to authenticated;
  end if;
end $$;

-- Extends the existing profile-creation trigger (0013_profiles_and_consent.sql)
-- to also record which invite code was used, if any. Runs strictly after
-- check_invite_code() above (a before-insert trigger, so it's already
-- vetted the code by the time this after-insert trigger fires) — the
-- lookup here can't fail to find a match for a genuine invite-code signup,
-- but is written defensively (stores null rather than erroring) in case
-- that assumption is ever wrong.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  used_code_id bigint;
begin
  if new.raw_user_meta_data->>'signup_method' = 'invite_code' then
    select id into used_code_id
    from public.invite_codes
    where code_hash = encode(digest(new.raw_user_meta_data->>'invite_code', 'sha256'), 'hex')
      and revoked_at is null
    limit 1;
  end if;

  insert into public.profiles (id, email, signed_up_via_invite_code_id)
  values (new.id, new.email, used_code_id)
  on conflict (id) do nothing;
  return new;
end;
$$;
