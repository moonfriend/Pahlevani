#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
# Tests the usage study's event table (migration 0051) on a throwaway
# Postgres: a user inserts their own rows (also the way PostgREST upserts
# with ignore-duplicates), can't insert for someone else, can't read,
# update or delete, signed-out users get nothing, bad rows are refused, and
# deleting the account deletes its events.
#
# Supabase's auth schema is stubbed (auth.users + auth.uid() reading
# request.jwt.claim.sub), so no Supabase project or credentials are needed.
#
# Usage:  bash scripts/db/test_usage_events.sh      (needs Docker)
# ════════════════════════════════════════════════════════════════════════════
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIG="${REPO_ROOT}/supabase/migrations"
CONTAINER="pahlevani_usage_events_test"
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

echo "── Supabase stand-ins (roles, auth schema, default grants)"
psql_sql <<'SQL'
create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users (id uuid primary key, email text);
create function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
grant usage on schema public to anon, authenticated;
-- Supabase's default: every new public table is fully granted.
alter default privileges in schema public grant all on tables to anon, authenticated;
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'ali@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'sara@example.com');
SQL

echo "── Migration 0051 (twice: it must be re-runnable)"
psql_file "${MIG}/0051_usage_events.sql"
psql_file "${MIG}/0051_usage_events.sql"

echo "── Checks"
psql_sql <<'SQL'
create function pg_temp.as_user(uid text) returns void language sql as
  $$ select set_config('request.jwt.claim.sub', coalesce(uid, ''), false) $$;
create function pg_temp.check(ok boolean, what text) returns void language plpgsql as $$
begin
  if not ok then raise exception 'FAILED: %', what; end if;
  raise notice 'ok  %', what;
end $$;
-- Runs sql and expects it to fail.
create function pg_temp.refused(sql text, what text) returns void language plpgsql as $$
begin
  execute sql;
  raise exception 'FAILED (was allowed): %', what;
exception when others then
  if sqlerrm like 'FAILED%' then raise; end if;
  raise notice 'ok  refused: %', what;
end $$;

-- A signed-in user inserts their own rows, the way PostgREST upserts with
-- ignore-duplicates (on conflict do nothing).
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
insert into public.usage_events
  (id, install_id, user_id, visit_id, seq, occurred_at, event, screen, props, app_version, platform)
values
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
   '00000000-0000-0000-0000-00000000000a', '30000000-0000-4000-8000-000000000001',
   1, now(), 'app.opened', 'splash', '{"start":"cold"}', '1.7.0+17', 'android')
on conflict (id) do nothing;
-- The same id again (a retried upload): silently skipped.
insert into public.usage_events
  (id, install_id, user_id, visit_id, seq, occurred_at, event)
values
  ('10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001',
   '00000000-0000-0000-0000-00000000000a', '30000000-0000-4000-8000-000000000001',
   1, now(), 'app.opened')
on conflict (id) do nothing;
select pg_temp.check(true, 'own insert + duplicate id skipped');

-- user_id left out: the default takes the caller's id.
insert into public.usage_events (id, install_id, visit_id, seq, occurred_at, event)
values ('10000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001',
        '30000000-0000-4000-8000-000000000001', 2, now(), 'nav.screen_viewed');
select pg_temp.check(true, 'user_id defaults to auth.uid()');

select pg_temp.refused($q$
  insert into public.usage_events (id, install_id, user_id, visit_id, seq, occurred_at, event)
  values (gen_random_uuid(), gen_random_uuid(), '00000000-0000-0000-0000-00000000000b',
          gen_random_uuid(), 1, now(), 'app.opened') $q$,
  'insert for another user');
select pg_temp.check((select count(id) from public.usage_events) = 2, 'own ids readable (needed by on conflict)');
select pg_temp.refused($q$ select props from public.usage_events $q$, 'reading event details');
select pg_temp.refused($q$ select event from public.usage_events $q$, 'reading event names');
reset role;
set role authenticated;
select pg_temp.as_user('00000000-0000-0000-0000-00000000000b');
select pg_temp.check((select count(id) from public.usage_events) = 0, 'another user sees none of them');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select pg_temp.refused($q$ update public.usage_events set screen = 'x' $q$, 'updating events');
select pg_temp.refused($q$ delete from public.usage_events $q$, 'deleting events');
select pg_temp.refused($q$
  insert into public.usage_events (id, install_id, visit_id, seq, occurred_at, event)
  values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 1, now(), 'Not An Event') $q$,
  'a name outside area.action');
select pg_temp.refused($q$
  insert into public.usage_events (id, install_id, visit_id, seq, occurred_at, event, props)
  values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 1, now(), 'a.b',
          jsonb_build_object('x', repeat('y', 5000))) $q$,
  'props over 4 KB');
select pg_temp.refused($q$
  insert into public.usage_events (id, install_id, visit_id, seq, occurred_at, event, props)
  values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 1, now(), 'a.b', '[1]') $q$,
  'props that are not an object');
reset role;

-- Signed out: nothing at all.
set role anon;
select pg_temp.as_user(null);
select pg_temp.refused($q$
  insert into public.usage_events (id, install_id, visit_id, seq, occurred_at, event)
  values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 1, now(), 'app.opened') $q$,
  'signed-out insert');
select pg_temp.refused($q$ select id from public.usage_events $q$, 'signed-out read');
reset role;

-- The admin (service role / postgres) sees what was stored.
select pg_temp.check((select count(*) from public.usage_events) = 2, 'two rows stored');
select pg_temp.check(
  (select received_at is not null from public.usage_events limit 1), 'received_at filled');

-- Deleting the account deletes its events.
delete from auth.users where id = '00000000-0000-0000-0000-00000000000a';
select pg_temp.check((select count(*) from public.usage_events) = 0, 'account deletion cascades');
SQL

echo "── All usage_events checks passed"
