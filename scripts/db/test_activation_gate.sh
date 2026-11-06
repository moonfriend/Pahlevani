#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
# Tests the activation gate (migration 0045) and Steady memberships (0051)
# on a throwaway Postgres: signed-out, not-activated, activated and trainer
# users, a used-up code, a revoked code, Steady members with and without a
# running membership, and account deletion.
#
# Supabase's auth schema is stubbed (auth.users + auth.uid() reading
# request.jwt.claim.sub), so no Supabase project or credentials are needed.
#
# Usage:  bash scripts/db/test_activation_gate.sh      (needs Docker)
# ════════════════════════════════════════════════════════════════════════════
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIG="${REPO_ROOT}/supabase/migrations"
CONTAINER="pahlevani_activation_gate_test"
PG_PASS="pahlevani_test"

cleanup() { docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup
docker run -d --name "${CONTAINER}" -e POSTGRES_PASSWORD="${PG_PASS}" postgres:15 >/dev/null
for _ in $(seq 1 30); do
  docker exec "${CONTAINER}" pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 1
done
sleep 1

psql_file() { docker exec -i "${CONTAINER}" psql -U postgres -d postgres -q -v ON_ERROR_STOP=1 < "$1"; }
psql_sql()  { docker exec -i "${CONTAINER}" psql -U postgres -d postgres -q -v ON_ERROR_STOP=1; }

echo "── Supabase stand-ins (roles, auth schema)"
psql_sql <<'SQL'
create role anon nologin;
create role authenticated nologin;
create role service_role nologin;
create schema auth;
create table auth.users (
  id uuid primary key,
  email text,
  raw_user_meta_data jsonb not null default '{}'::jsonb
);
create table auth.identities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null,
  identity_data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
create function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth to anon, authenticated, service_role;
-- Supabase's default: new functions are executable by anon/authenticated
-- unless revoked by name. Mirror it so the 0051 revokes are really tested.
alter default privileges in schema public
  grant execute on functions to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated;
SQL

echo "── Schema: 0001 + seed, then the migrations the gate builds on"
psql_file "${MIG}/0001_initial_schema.sql"
psql_file "${REPO_ROOT}/supabase/seed.sql"
for m in 0005_movement_info 0013_profiles_and_consent 0014_session_assignment \
         0016_invite_code_signup 0045_activation_gate 0051_steady_membership; do
  echo "   ${m}"
  psql_file "${MIG}/${m}.sql"
done
psql_sql <<'SQL'
grant usage on schema public to anon, authenticated, service_role;
grant select on all tables in schema public to anon, authenticated;
SQL

echo "── Users and codes"
psql_sql <<'SQL'
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'ali@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'sara@example.com'),
  ('00000000-0000-0000-0000-00000000000c', 'coach@example.com'),
  ('00000000-0000-0000-0000-00000000000d', 'reza@example.com'),
  ('00000000-0000-0000-0000-00000000000e', 'mina@example.com'),
  ('00000000-0000-0000-0000-00000000000f', 'omid@example.com');
-- mina signed in with Steady; omid has an email account only.
insert into auth.identities (user_id, provider, identity_data) values
  ('00000000-0000-0000-0000-00000000000e', 'custom:steady',
   '{"sub": "steady-123", "email": "mina@steady.example"}');
update public.profiles set is_trainer = true
  where id = '00000000-0000-0000-0000-00000000000c';
insert into public.invite_codes (code, max_uses) values ('ONCE-ONLY', 1);
insert into public.invite_codes (code, max_uses, revoked_at)
  values ('REVOKED', 5, now());
insert into public.invite_codes (code, max_uses) values ('GIFT', 10);
SQL

echo "── Checks"
psql_sql <<'SQL'
create function pg_temp.as_user(uid text) returns void language sql as
  $$ select set_config('request.jwt.claim.sub', coalesce(uid, ''), false) $$;
create function pg_temp.check(ok boolean, what text) returns void language plpgsql as $$
begin
  if not ok then raise exception 'FAILED: %', what; end if;
  raise notice 'ok  %', what;
end $$;

-- signed out
set role anon;
select pg_temp.as_user(null);
select pg_temp.check((select count(*) from public.training_session) = 0, 'signed out: no sessions');
select pg_temp.check((select count(*) from public.exercise) = 0, 'signed out: no exercises');
select pg_temp.check((select count(*) from public.activation_gate) = 1, 'signed out: locked-screen text readable');
reset role;

-- signed in, not activated
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select pg_temp.check((select count(*) from public.training_session) = 0, 'not activated: no sessions');
select pg_temp.check((select count(*) from public.training_session_item) = 0, 'not activated: no items');
select pg_temp.check((select count(*) from public.movement) = 0, 'not activated: no moves');
select pg_temp.check(not public.is_activated(), 'not activated: is_activated() false');
reset role;

-- a revoked code fails
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
do $$ begin
  perform public.redeem_activation_code('REVOKED');
  raise exception 'FAILED: a revoked code was accepted';
exception when others then
  if sqlerrm not like '%invalid_activation_code%' then raise; end if;
  raise notice 'ok  revoked code rejected';
end $$;

-- a good code activates; content appears
select pg_temp.check(public.redeem_activation_code('  ONCE-ONLY '), 'redeem (trimmed) succeeds');
select pg_temp.check(public.is_activated(), 'activated: is_activated() true');
select pg_temp.check((select count(*) from public.training_session) > 0, 'activated: sessions visible');
select pg_temp.check((select count(*) from public.training_session_item) > 0, 'activated: items visible');
select pg_temp.check((select count(*) from public.exercise) > 0, 'activated: exercises visible');
select pg_temp.check(public.redeem_activation_code('anything'), 'redeem again is a no-op');
select pg_temp.check(
  (select email from public.activations) = 'ali@example.com',
  'activation stores the email (own row only)');
reset role;
select pg_temp.check((select uses_count from public.invite_codes where code = 'ONCE-ONLY') = 1,
  'the code counted one use');

-- the code is used up for someone else
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
do $$ begin
  perform public.redeem_activation_code('ONCE-ONLY');
  raise exception 'FAILED: a used-up code was accepted';
exception when others then
  if sqlerrm not like '%invalid_activation_code%' then raise; end if;
  raise notice 'ok  used-up code rejected (max_uses)';
end $$;
select pg_temp.check((select count(*) from public.activations) = 0, 'cannot see others'' activations');
reset role;

-- trainers see content without a code
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select pg_temp.check((select count(*) from public.training_session) > 0, 'trainer: sessions visible');
reset role;

-- a user cannot write their own activation
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000d');
do $$ begin
  insert into public.activations (user_id, code) values (auth.uid(), 'fake');
  raise exception 'FAILED: a user inserted their own activation';
exception when insufficient_privilege then
  raise notice 'ok  activations are not client-writable';
end $$;
reset role;

-- ── Steady memberships (0051) ──────────────────────────────────────────
-- Only the server (service role) may read Steady identities or set access.
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000e');
do $$ begin
  perform public.steady_apply_membership(auth.uid(), true, now() + interval '1 year', 'active');
  raise exception 'FAILED: a user granted themselves a Steady membership';
exception when insufficient_privilege then
  raise notice 'ok  users cannot set their own Steady membership';
end $$;
do $$ begin
  perform public.steady_identity_email(auth.uid());
  raise exception 'FAILED: a user could call steady_identity_email';
exception when insufficient_privilege then
  raise notice 'ok  users cannot read Steady identities';
end $$;
do $$ begin
  perform * from public.steady_members();
  raise exception 'FAILED: a user could list Steady members';
exception when insufficient_privilege then
  raise notice 'ok  users cannot list Steady members';
end $$;
reset role;
set role anon;
do $$ begin
  perform public.steady_apply_membership('00000000-0000-0000-0000-00000000000e', true, now() + interval '1 year', 'active');
  raise exception 'FAILED: signed-out caller set a membership';
exception when insufficient_privilege then
  raise notice 'ok  signed out cannot set memberships';
end $$;
reset role;

set role service_role;
select pg_temp.check(public.steady_identity_email('00000000-0000-0000-0000-00000000000e') = 'mina@steady.example',
  'server reads the Steady email from the identity, not the account');
select pg_temp.check(public.steady_identity_email('00000000-0000-0000-0000-00000000000f') is null,
  'no Steady identity: no email');
select pg_temp.check((select count(*) from public.steady_members()) = 1
  and (select email from public.steady_members()) = 'mina@steady.example',
  'steady_members lists only Steady sign-ins');
reset role;

set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000e');
select pg_temp.check(not public.is_activated(), 'Steady sign-in without membership: locked');
reset role;

set role service_role;
select public.steady_apply_membership('00000000-0000-0000-0000-00000000000e', true, now() + interval '30 days', 'active');
reset role;
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000e');
select pg_temp.check(public.is_activated(), 'running Steady membership: activated');
select pg_temp.check((select count(*) from public.training_session) > 0, 'Steady member: sessions visible');
select pg_temp.check((select source from public.activations) = 'steady', 'activation source is steady');
do $$ begin
  update public.activations set expires_at = now() + interval '100 years';
  raise exception 'FAILED: a member extended their own membership';
exception when insufficient_privilege then
  raise notice 'ok  members cannot change their expiry';
end $$;
reset role;

set role service_role;
select public.steady_apply_membership('00000000-0000-0000-0000-00000000000e', true, now() - interval '1 minute', 'active');
reset role;
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000e');
select pg_temp.check(not public.is_activated(), 'membership end date passed: locked again');
reset role;

set role service_role;
select public.steady_apply_membership('00000000-0000-0000-0000-00000000000e', true, now() + interval '30 days', 'active');
select public.steady_apply_membership('00000000-0000-0000-0000-00000000000e', false, null, 'cancelled');
reset role;
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000e');
select pg_temp.check(not public.is_activated(), 'membership gone at Steady: locked at once');
select pg_temp.check((select steady_state from public.activations) = 'cancelled', 'Steady state recorded');
-- a gifted code still works after the membership ended, and lasts
select pg_temp.check(public.redeem_activation_code('GIFT'), 'expired member redeems a code');
select pg_temp.check(public.is_activated(), 'code after membership: activated');
select pg_temp.check((select source from public.activations) = 'code'
  and (select expires_at from public.activations) is null, 'code access has no end date');
reset role;

set role service_role;
select public.steady_apply_membership('00000000-0000-0000-0000-00000000000e', false, null, 'cancelled');
reset role;
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000e');
select pg_temp.check(public.is_activated(), 'Steady check never takes away code access');
reset role;

set role service_role;
do $$ begin
  perform public.steady_apply_membership('00000000-0000-0000-0000-00000000000f', true, null, 'active');
  raise exception 'FAILED: membership without an end date accepted';
exception when others then
  if sqlerrm not like '%expires_at_required%' then raise; end if;
  raise notice 'ok  a Steady membership always has an end date';
end $$;
reset role;

-- delete my account
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select public.delete_my_account();
reset role;
select pg_temp.check(not exists (select 1 from auth.users where email = 'ali@example.com'), 'account deleted');
select pg_temp.check(not exists (select 1 from public.activations
  where user_id = '00000000-0000-0000-0000-00000000000a'), 'its activation went with it');
select pg_temp.check(not exists (select 1 from public.profiles where email = 'ali@example.com'), 'its profile went with it');
SQL
echo "✅ activation gate: all checks passed"
