#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
# Builds — and rehearses — the SQL that copies curated content from staging
# to production (see content_sync_generate.sql for what is and isn't copied).
#
# 1. Loads a staging dump (schema `stg`) and a production dump (`public`)
#    into a throwaway local Postgres.
# 2. Writes the sync SQL to <out.sql> (one transaction, reviewable).
# 3. Rehearses it on the local prod copy: applies it, checks a second run
#    generates nothing, applying it twice is harmless, and session contents
#    are untouched.
#
# Nothing here connects to Supabase. Take fresh dumps first (pg_dump via
# scripts/with_admin_creds.sh); they hold user data, so keep them outside the
# repo (~/StudioProjects/pahlevani-db-backups/). Then apply <out.sql> to prod.
#
# Usage:  bash scripts/db/build_content_sync.sh <staging.dump> <prod.dump> <out.sql>
# ════════════════════════════════════════════════════════════════════════════
set -euo pipefail

STAGING_DUMP="$(realpath "${1:?usage: build_content_sync.sh <staging.dump> <prod.dump> <out.sql>}")"
PROD_DUMP="$(realpath "${2:?missing <prod.dump>}")"
OUT="$(realpath -m "${3:?missing <out.sql>}")"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GENERATOR="${REPO_ROOT}/scripts/db/content_sync_generate.sql"
CONTAINER="pahlevani_content_sync"

cleanup() { docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup
docker run -d --name "${CONTAINER}" -e POSTGRES_PASSWORD=sync \
  -v "${STAGING_DUMP}:/staging.dump:ro" -v "${PROD_DUMP}:/prod.dump:ro" \
  postgres:17-alpine >/dev/null
for _ in $(seq 1 30); do
  docker exec "${CONTAINER}" pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 1
done
sleep 1

psql_sql() { docker exec -i "${CONTAINER}" psql -U postgres -d postgres -q -v ON_ERROR_STOP=1 "$@"; }
generate() { psql_sql -At < "${GENERATOR}"; }

echo "── Supabase stand-ins"
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
SQL

echo "── Load staging (as schema stg) and production (as public)"
# Staging is only read, so its FKs to auth.users may fail to restore; the
# data still loads. Production is restored strictly.
docker exec "${CONTAINER}" sh -c '
  pg_restore -U postgres -d postgres -n public --no-owner --no-privileges /staging.dump 2>/dev/null || true
  psql -U postgres -q -v ON_ERROR_STOP=1 -c "alter schema public rename to stg; create schema public"
  pg_restore -U postgres -d postgres -n auth -t users --no-owner --exit-on-error /prod.dump
  psql -U postgres -q -v ON_ERROR_STOP=1 -c "alter table auth.users add primary key (id)"
  pg_restore -U postgres -d postgres -n public --no-owner --exit-on-error /prod.dump'

echo "── Guards"
psql_sql -At <<'SQL'
do $$ begin
  if exists (select 1 from stg.movement s where not exists (select 1 from public.movement p where p.id = s.id)) then
    raise exception 'staging has movements prod lacks — the generator only updates existing ones';
  end if;
  if exists (select 1 from stg.movement_type s where not exists (select 1 from public.movement_type p where p.key = s.key)) then
    raise exception 'staging has movement types prod lacks';
  end if;
end $$;
create table public._items_before as
  select training_session_id, exercise_id, position, reps_to_do, is_tracked from public.training_session_item;
SQL

echo "── Generate → ${OUT}"
generate > "${OUT}"
echo "   $(grep -cE "^(insert|update|delete) " "${OUT}") statements"

echo "── Rehearse on the local prod copy"
psql_sql -o /dev/null < "${OUT}"
if [[ "$(generate | wc -l)" -ne 2 ]]; then
  echo "FAILED: a second run still finds differences:" >&2
  generate >&2
  exit 1
fi
echo "   ok  second run finds no differences"
psql_sql -o /dev/null < "${OUT}"
echo "   ok  applying it twice is harmless"
psql_sql -At <<'SQL'
do $$ begin
  if exists (select training_session_id, exercise_id, position, reps_to_do, is_tracked from public.training_session_item
             except select * from public._items_before)
     or (select count(*) from public.training_session_item) <> (select count(*) from public._items_before) then
    raise exception 'FAILED: session contents changed';
  end if;
  if exists (select 1 from public.movement m where m.video_id is not null
             and not exists (select 1 from public.video v where v.id = m.video_id)) then
    raise exception 'FAILED: a movement points at a missing video';
  end if;
  raise notice 'ok  session contents untouched; every movement video exists';
end $$;
SQL
echo "✅ content sync built and rehearsed: ${OUT}"
