#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
# Tests the usage study's views (migration 0052) on a throwaway Postgres:
# seeds two testers' scripted journeys into usage_events (0051) and checks
# each research-question view tells that story. Also checks signed-in users
# can't read any view.
#
# Usage:  bash scripts/db/test_usage_views.sh      (needs Docker)
# ════════════════════════════════════════════════════════════════════════════
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIG="${REPO_ROOT}/supabase/migrations"
CONTAINER="pahlevani_usage_views_test"

cleanup() { docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup
docker run -d --name "${CONTAINER}" -e POSTGRES_PASSWORD=x postgres:15 >/dev/null
for _ in $(seq 1 30); do
  docker exec "${CONTAINER}" pg_isready -U postgres >/dev/null 2>&1 && break
  sleep 1
done
sleep 1

psql_file() { docker exec -i "${CONTAINER}" psql -U postgres -d postgres -q -v ON_ERROR_STOP=1 < "$1"; }
psql_sql()  { docker exec -i "${CONTAINER}" psql -U postgres -d postgres -q -v ON_ERROR_STOP=1; }

echo "── Supabase stand-ins"
psql_sql <<'SQL'
create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users (id uuid primary key, email text);
create function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth, public to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
alter default privileges in schema public grant all on tables to anon, authenticated;
insert into auth.users values
  ('00000000-0000-0000-0000-00000000000a', 'ali@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'sara@example.com');
SQL

echo "── Migrations 0051 + 0052 (0052 twice: re-runnable)"
psql_file "${MIG}/0051_usage_events.sql"
psql_file "${MIG}/0052_usage_views.sql"
psql_file "${MIG}/0052_usage_views.sql"

echo "── Seed: two testers"
psql_sql <<'SQL'
-- e(user, visit, seq, minutes after start, event, screen, props)
create function pg_temp.e(u text, v int, s int, m numeric, ev text, sc text, p jsonb)
returns void language sql as $$
  insert into public.usage_events
    (id, install_id, user_id, visit_id, seq, occurred_at, event, screen, props, app_version, platform)
  values (gen_random_uuid(),
          ('20000000-0000-4000-8000-00000000000' || right(u, 1))::uuid,
          ('00000000-0000-0000-0000-00000000000' || u)::uuid,
          ('30000000-0000-4000-8000-0000000000' || lpad(v::text, 2, '0'))::uuid,
          s, timestamptz '2026-11-10 08:00:00+00' + m * interval '1 minute',
          ev, sc, p, '1.7.0+17', 'android') $$;

-- Ali, day 1 (UTC+1): splash → onboarding → wrong password → sign in →
-- home → preview (opens a move) → start → Next after 12 s → leaves.
select pg_temp.e('a', 1, 1, 0,    'app.opened', 'loading', '{"start":"cold","utc_offset_min":60}');
select pg_temp.e('a', 1, 2, 0.1,  'nav.screen_viewed', 'splash', '{"screen":"splash","previous":null,"via":"gate"}');
select pg_temp.e('a', 1, 3, 0.2,  'splash.begin_tapped', 'splash', '{"seconds":6}');
select pg_temp.e('a', 1, 4, 0.2,  'nav.screen_left', 'splash', '{"screen":"splash","seconds":6,"scroll_depth_pct":null}');
select pg_temp.e('a', 1, 5, 0.2,  'nav.screen_viewed', 'onboarding', '{"screen":"onboarding","previous":"splash","via":"gate"}');
select pg_temp.e('a', 1, 6, 1,    'onboarding.skipped', 'onboarding', '{"at_card":1,"seconds":40}');
select pg_temp.e('a', 1, 7, 1,    'nav.screen_left', 'onboarding', '{"screen":"onboarding","seconds":48,"scroll_depth_pct":null}');
select pg_temp.e('a', 1, 8, 1,    'nav.screen_viewed', 'account', '{"screen":"account","previous":"onboarding","via":"gate"}');
select pg_temp.e('a', 1, 9, 1.5,  'auth.screen_mode', 'account', '{"mode":"sign_in"}');
select pg_temp.e('a', 1, 10, 2,   'auth.submit', 'account', '{"mode":"sign_in","attempt":1}');
select pg_temp.e('a', 1, 11, 2,   'auth.result', 'account', '{"mode":"sign_in","ok":false,"error":"wrong_credentials"}');
select pg_temp.e('a', 1, 12, 3,   'auth.submit', 'account', '{"mode":"sign_in","attempt":2}');
select pg_temp.e('a', 1, 13, 3,   'auth.result', 'account', '{"mode":"sign_in","ok":true,"error":null}');
select pg_temp.e('a', 1, 14, 3,   'nav.screen_left', 'account', '{"screen":"account","seconds":120,"scroll_depth_pct":40}');
select pg_temp.e('a', 1, 15, 3,   'nav.screen_viewed', 'home', '{"screen":"home","previous":"account","via":"gate"}');
select pg_temp.e('a', 1, 16, 3.5, 'ui.dead_tap', 'home', '{"element":"home.greeting","cell":"c1r1"}');
select pg_temp.e('a', 1, 17, 3.51,'ui.dead_tap', 'home', '{"element":"home.greeting","cell":"c1r1"}');
select pg_temp.e('a', 1, 18, 3.52,'ui.dead_tap', 'home', '{"element":"home.greeting","cell":"c1r1"}');
select pg_temp.e('a', 1, 19, 4,   'nav.screen_left', 'home', '{"screen":"home","seconds":60,"scroll_depth_pct":null}');
select pg_temp.e('a', 1, 20, 4,   'nav.screen_viewed', 'session_preview', '{"screen":"session_preview","previous":"home","via":"button"}');
select pg_temp.e('a', 1, 21, 4,   'session.previewed', 'session_preview', '{"session_id":5,"source":"home","moves":3}');
select pg_temp.e('a', 1, 22, 4.5, 'preview.move_opened', 'session_preview', '{"session_id":5,"movement_id":31,"position":0}');
select pg_temp.e('a', 1, 23, 5,   'preview.mode_tapped', 'session_preview', '{"session_id":5,"mode":"learning"}');
select pg_temp.e('a', 1, 24, 5,   'preview.left', 'session_preview', '{"session_id":5,"how":"start","seconds":60,"moves_opened":1}');
select pg_temp.e('a', 1, 25, 5,   'session.started', 'player', '{"session_id":5,"mode":"learning","moves":3}');
select pg_temp.e('a', 1, 26, 5.2, 'player.move_ended', 'player', '{"index":0,"movement_id":31,"played_s":12,"planned_s":30,"reached_pct":40,"reps_reached":4,"reps_planned":10,"pauses":0,"seeks":1,"how":"next"}');
select pg_temp.e('a', 1, 27, 6,   'player.move_ended', 'player', '{"index":1,"movement_id":32,"played_s":20,"planned_s":30,"reached_pct":66,"reps_reached":6,"reps_planned":10,"pauses":1,"seeks":0,"how":"left_session"}');
select pg_temp.e('a', 1, 28, 6,   'session.abandoned', 'player', '{"session_id":5,"last_index":1,"played_s":32,"how":"back"}');

-- Ali, day 2: opens, previews, leaves without starting.
select pg_temp.e('a', 2, 1, 1440, 'app.opened', 'loading', '{"start":"cold","utc_offset_min":60}');
select pg_temp.e('a', 2, 2, 1440, 'nav.screen_viewed', 'home', '{"screen":"home","previous":null,"via":"gate"}');
select pg_temp.e('a', 2, 3, 1441, 'session.previewed', 'session_preview', '{"session_id":5,"source":"home","moves":3}');
select pg_temp.e('a', 2, 4, 1442, 'preview.left', 'session_preview', '{"session_id":5,"how":"back","seconds":50,"moves_opened":0}');

-- Sara, day 1: create account (code wrong, then ok) → completes a session.
select pg_temp.e('b', 3, 1, 10,   'app.opened', 'loading', '{"start":"cold","utc_offset_min":0}');
select pg_temp.e('b', 3, 2, 10,   'nav.screen_viewed', 'account', '{"screen":"account","previous":null,"via":"gate"}');
select pg_temp.e('b', 3, 3, 11,   'auth.result', 'account', '{"mode":"create_account","ok":false,"error":"code_invalid"}');
select pg_temp.e('b', 3, 4, 12,   'auth.result', 'account', '{"mode":"create_account","ok":true,"error":null}');
select pg_temp.e('b', 3, 5, 12,   'nav.screen_viewed', 'home', '{"screen":"home","previous":"account","via":"gate"}');
select pg_temp.e('b', 3, 6, 13,   'session.previewed', 'session_preview', '{"session_id":5,"source":"library","moves":3}');
select pg_temp.e('b', 3, 7, 13,   'preview.left', 'session_preview', '{"session_id":5,"how":"start","seconds":20,"moves_opened":0}');
select pg_temp.e('b', 3, 8, 13,   'session.started', 'player', '{"session_id":5,"mode":"athlete","moves":3}');
select pg_temp.e('b', 3, 9, 14,   'player.move_ended', 'player', '{"index":0,"movement_id":31,"played_s":30,"planned_s":30,"reached_pct":100,"reps_reached":10,"reps_planned":10,"pauses":0,"seeks":0,"how":"played_to_end"}');
select pg_temp.e('b', 3, 10, 20,  'session.completed', 'complete', '{"session_id":5,"seconds":420,"played_s":400}');
SQL

echo "── Checks"
psql_sql <<'SQL'
create function pg_temp.check(ok boolean, what text) returns void language plpgsql as $$
begin
  if not ok then raise exception 'FAILED: %', what; end if;
  raise notice 'ok  %', what;
end $$;
create function pg_temp.refused(sql text, what text) returns void language plpgsql as $$
begin
  execute sql;
  raise exception 'FAILED (was allowed): %', what;
exception when others then
  if sqlerrm like 'FAILED%' then raise; end if;
  raise notice 'ok  refused: %', what;
end $$;

-- visits
select pg_temp.check((select count(*) from public.usage_visits) = 3, 'three visits');
select pg_temp.check((select seconds from public.usage_visits
  where visit_id = '30000000-0000-4000-8000-000000000001') = 360, 'visit length 6 min');
select pg_temp.check((select local_started_at from public.usage_visits
  where visit_id = '30000000-0000-4000-8000-000000000001') = timestamp '2026-11-10 09:00',
  'local time uses the device offset');

-- RQ1/RQ6
select pg_temp.check((select visits from public.usage_rq1_daily
  where user_id = '00000000-0000-0000-0000-00000000000a' and day = date '2026-11-10') = 1,
  'rq1: Ali one visit on day 1');
select pg_temp.check((select returned_day_1 from public.usage_rq1_return
  where user_id = '00000000-0000-0000-0000-00000000000a'), 'rq6: Ali came back on day 2');
select pg_temp.check(not (select returned_day_1 from public.usage_rq1_return
  where user_id = '00000000-0000-0000-0000-00000000000b'), 'rq6: Sara did not');
select pg_temp.check((select sum(visits) from public.usage_rq1_hours) = 3, 'rq1: hour heatmap counts visits');

-- RQ2
select pg_temp.check((select failed_results from public.usage_rq2_login
  where user_id = '00000000-0000-0000-0000-00000000000a') = 1, 'rq2: Ali failed once');
select pg_temp.check((select seconds_to_first_ok from public.usage_rq2_login
  where user_id = '00000000-0000-0000-0000-00000000000a') = 120, 'rq2: Ali in after 2 min');
select pg_temp.check((select failures from public.usage_rq2_login_errors
  where error = 'code_invalid') = 1, 'rq2: one wrong code');

-- RQ3
select pg_temp.check((select first_session_started is not null and first_session_completed is null
  from public.usage_rq3_first_use where user_id = '00000000-0000-0000-0000-00000000000a'),
  'rq3: Ali started but never completed');
select pg_temp.check((select first_session_completed is not null
  from public.usage_rq3_first_use where user_id = '00000000-0000-0000-0000-00000000000b'),
  'rq3: Sara completed');

-- RQ4
select pg_temp.check((select moves from public.usage_rq4_transitions
  where from_screen = 'account' and to_screen = 'home') = 2, 'rq4: account → home twice');
select pg_temp.check((select median_seconds from public.usage_rq4_screen_time
  where screen = 'splash') = 6, 'rq4: splash median 6 s');

-- RQ5
select pg_temp.check((select median_played_s from public.usage_rq5_moves
  where movement_id = 31) = 21, 'rq5: move 31 median played 21 s (12, 30)');
select pg_temp.check((select ended_by_next from public.usage_rq5_moves
  where movement_id = 31) = 1, 'rq5: move 31 ended by Next once');
select pg_temp.check((select completed from public.usage_rq5_sessions where session_id = 5) = 1
  and (select abandoned from public.usage_rq5_sessions where session_id = 5) = 1,
  'rq5: one completed, one abandoned run');
select pg_temp.check((select runs from public.usage_rq5_dropoff
  where session_id = 5 and last_index = 1) = 1, 'rq5: drop-off at move 1');
select pg_temp.check((select previews_without_start from public.usage_rq5_preview
  where user_id = '00000000-0000-0000-0000-00000000000a') = 1, 'rq5: Ali left one preview without starting');
select pg_temp.check((select previews_before_first_start from public.usage_rq5_preview
  where user_id = '00000000-0000-0000-0000-00000000000a') = 0, 'rq5: Ali started on his first preview');

-- friction
select pg_temp.check((select taps from public.usage_dead_taps
  where element = 'home.greeting') = 3, 'dead taps on the greeting');
select pg_temp.check((select count(*) from public.usage_rage_taps) = 1, 'one rage tap burst');

-- timeline
select pg_temp.check((select count(*) from public.usage_timeline
  where user_id = '00000000-0000-0000-0000-00000000000a') = 32, 'timeline has every event of Ali');

-- nobody but the admin reads the views
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
select pg_temp.refused($q$ select * from public.usage_visits $q$, 'a user reading usage_visits');
select pg_temp.refused($q$ select * from public.usage_timeline $q$, 'a user reading usage_timeline');
reset role;
SQL

echo "── All usage view checks passed"
