#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
# Rehearses the Release 1 production migrations on a local copy of a real
# prod backup, so nothing is tried on prod for the first time.
#
# 1. Restores auth.users + the public schema from a prod pg_dump (-Fc) into a
#    throwaway Postgres, with stand-ins for the Supabase roles/extensions.
# 2. Records what the CURRENT app sees (anon + a signed-in, not-activated
#    user) on every content table it reads.
# 3. Applies the release migrations in prod order (0033 and 0039 skipped)
#    plus the 0047 bridge, and checks the current app still sees exactly the
#    same rows, can't write, and that the activation flow works on prod data.
# 4. Applies 0048 (cutover) and checks the gate is then really enforced.
#
# The dump holds user data — keep it outside the repo
# (~/StudioProjects/pahlevani-db-backups/). Nothing here touches Supabase.
#
# Usage:  bash scripts/db/rehearse_prod_migrations.sh <prod_full.dump>   (needs Docker)
# ════════════════════════════════════════════════════════════════════════════
set -euo pipefail

DUMP="${1:?usage: rehearse_prod_migrations.sh <prod_full.dump>}"
DUMP="$(cd "$(dirname "${DUMP}")" && pwd)/$(basename "${DUMP}")"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIG="${REPO_ROOT}/supabase/migrations"
CONTAINER="pahlevani_prod_rehearsal"

# Order matters; 0033 (staging-only) and 0039 (fitness, on no env) are skipped.
RELEASE_MIGRATIONS=(0035 0036 0037 0038 0040 0041 0042 0043 0044 0045 0046 0047)

cleanup() { docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup
docker run -d --name "${CONTAINER}" -e POSTGRES_PASSWORD=rehearsal \
  -v "$(dirname "${DUMP}"):/dump:ro" postgres:17-alpine >/dev/null
for _ in $(seq 1 30); do
  docker exec "${CONTAINER}" pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 1
done
sleep 1

psql_file() { docker exec -i -e PGOPTIONS="-c client_min_messages=warning" "${CONTAINER}" psql -U postgres -d postgres -q -v ON_ERROR_STOP=1 < "$1"; }
psql_sql()  { docker exec -i "${CONTAINER}" psql -U postgres -d postgres -q -v ON_ERROR_STOP=1 -o /dev/null; }
migration() { ls "${MIG}/$1"_*.sql; }

echo "── Supabase stand-ins (roles, extensions, auth.uid())"
psql_sql 2>/dev/null <<'SQL'
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create role supabase_admin nologin;
create role dashboard_user nologin;
create schema extensions;
create extension "uuid-ossp" schema extensions;
create extension pgcrypto schema extensions;
create extension moddatetime schema extensions;
create publication supabase_realtime;
create schema auth;
create function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
SQL

echo "── Restore prod backup (auth.users + public)"
docker exec "${CONTAINER}" sh -c '
  pg_restore -U postgres -d postgres -n auth -t users --no-owner --exit-on-error /dump/'"$(basename "${DUMP}")"' &&
  psql -U postgres -q -v ON_ERROR_STOP=1 -c "alter table auth.users add primary key (id)" &&
  pg_restore -U postgres -d postgres -n public --no-owner --exit-on-error /dump/'"$(basename "${DUMP}")"
psql_sql <<'SQL'
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();
SQL

echo "── Test helpers + what the current app sees before migrating"
psql_sql <<'SQL'
create schema rehearsal;
create function rehearsal.as_user(uid text) returns void language sql as
  $$ select set_config('request.jwt.claim.sub', coalesce(uid, ''), false) $$;
create function rehearsal.check(ok boolean, what text) returns void language plpgsql as $$
begin
  if not ok then raise exception 'FAILED: %', what; end if;
  raise notice 'ok  %', what;
end $$;
-- The tables the current (main) app reads: training_session_remote_datasource
-- and audio_catalog_remote_datasource.
create function rehearsal.visible_counts() returns table (tbl text, n bigint)
language plpgsql as $$
declare t text;
begin
  foreach t in array array['training_session', 'training_session_item', 'exercise',
    'movement', 'movement_info', 'movement_type', 'morshed', 'movement_audio_track',
    'video', 'app_release_gate'] loop
    tbl := t;
    execute format('select count(*) from public.%I', t) into n;
    return next;
  end loop;
end $$;
grant usage on schema rehearsal to anon, authenticated;
grant execute on all functions in schema rehearsal to anon, authenticated;

create table rehearsal.baseline (who text, tbl text, n bigint);
grant insert, select on rehearsal.baseline to anon, authenticated;

-- A signed-in, not-activated user, as a current-app user would be.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000aa', 'rehearsal-user@example.com'),
  ('00000000-0000-0000-0000-0000000000bb', 'rehearsal-activated@example.com');

set role anon;
select rehearsal.as_user(null);
insert into rehearsal.baseline select 'anon', * from rehearsal.visible_counts();
reset role;
set role authenticated;
select rehearsal.as_user('00000000-0000-0000-0000-0000000000aa');
insert into rehearsal.baseline select 'user', * from rehearsal.visible_counts();
reset role;
select rehearsal.check((select n from rehearsal.baseline where who = 'anon' and tbl = 'movement') > 0,
  'baseline: the current app sees content (grants restored)');
SQL

echo "── Apply release migrations"
for m in "${RELEASE_MIGRATIONS[@]}"; do
  echo "   ${m}"
  psql_file "$(migration "${m}")"
done

echo "── Bridge: the current app still sees exactly the same, and can't write"
psql_sql <<'SQL'
set role anon;
select rehearsal.as_user(null);
select rehearsal.check(not exists (
  select 1 from rehearsal.baseline b join rehearsal.visible_counts() v using (tbl)
  where b.who = 'anon' and b.n <> v.n), 'signed out: same rows on every table as before');
reset role;

set role authenticated;
select rehearsal.as_user('00000000-0000-0000-0000-0000000000aa');
select rehearsal.check(not exists (
  select 1 from rehearsal.baseline b join rehearsal.visible_counts() v using (tbl)
  where b.who = 'user' and b.n <> v.n), 'not activated: same rows on every table as before');
select rehearsal.check(not public.is_activated(), 'not activated: is_activated() false');
reset role;

set role anon;
do $$ begin
  update public.movement set name = 'hacked';
  if exists (select 1 from public.movement where name = 'hacked') then
    raise exception 'FAILED: anon changed a movement';
  end if;
  raise notice 'ok  signed out: cannot change content';
exception when insufficient_privilege then
  raise notice 'ok  signed out: cannot change content';
end $$;
reset role;

-- Activation works on prod data.
insert into public.invite_codes (code, max_uses) values ('REHEARSAL-CODE', 1);
set role authenticated;
select rehearsal.as_user('00000000-0000-0000-0000-0000000000bb');
select rehearsal.check(public.redeem_activation_code('REHEARSAL-CODE'), 'activation: code redeems');
select rehearsal.check(public.is_activated(), 'activation: is_activated() true');
reset role;
SQL

echo "── Cutover: apply 0048, the gate is enforced"
psql_file "$(migration 0048)"
psql_sql <<'SQL'
set role anon;
select rehearsal.as_user(null);
select rehearsal.check((select count(*) from public.training_session) = 0, 'after 0048, signed out: no sessions');
select rehearsal.check((select count(*) from public.movement) = 0, 'after 0048, signed out: no moves');
select rehearsal.check((select count(*) from public.app_release_gate) = 1, 'after 0048, signed out: release gate still readable');
reset role;

set role authenticated;
select rehearsal.as_user('00000000-0000-0000-0000-0000000000aa');
select rehearsal.check((select count(*) from public.exercise) = 0, 'after 0048, not activated: no exercises');
select rehearsal.as_user('00000000-0000-0000-0000-0000000000bb');
select rehearsal.check(not exists (
  select 1 from rehearsal.baseline b join rehearsal.visible_counts() v using (tbl)
  where b.who = 'user' and b.n <> v.n), 'after 0048, activated: sees everything the app saw before');
reset role;
SQL
echo "✅ prod migration rehearsal: all checks passed"
