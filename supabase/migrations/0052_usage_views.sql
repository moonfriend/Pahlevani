-- ═══════════════════════════════════════════════════════════════════════════
-- READ BEFORE RUNNING
--
-- Not applied automatically — paste into the Supabase SQL Editor after 0051
-- (staging first, then production). Verified with
-- scripts/db/test_usage_views.sh (two seeded tester journeys) on a
-- throwaway Postgres.
--
-- Purely additive: read-only views over usage_events, one or more per
-- research question (RQ1–RQ6, see docs/usage_study/event_catalogue.md).
-- Re-runnable: every view is dropped and recreated, so later versions of
-- this file can change columns.
--
-- Only the admin reads them (service role). They run with the caller's
-- rights (security_invoker) and are revoked from anon/authenticated.
-- Times: `occurred_at` is UTC; `local_*` columns shift it by the device's
-- offset from that visit's app.opened. Days and hours are local.
-- ═══════════════════════════════════════════════════════════════════════════

drop view if exists
  public.usage_timeline,
  public.usage_rage_taps,
  public.usage_dead_taps,
  public.usage_rq5_preview,
  public.usage_rq5_dropoff,
  public.usage_rq5_sessions,
  public.usage_rq5_moves,
  public.usage_rq4_screen_time,
  public.usage_rq4_transitions,
  public.usage_rq3_first_use,
  public.usage_rq2_login_errors,
  public.usage_rq2_login,
  public.usage_rq1_return,
  public.usage_rq1_hours,
  public.usage_rq1_daily,
  public.usage_visits
  cascade;

-- ── Visits ─────────────────────────────────────────────────────────────────
-- One row per visit (foreground until 30 min in the background).
create view public.usage_visits with (security_invoker = true) as
select
  visit_id,
  user_id,
  install_id,
  min(occurred_at)                                             as started_at,
  max(occurred_at)                                             as ended_at,
  extract(epoch from max(occurred_at) - min(occurred_at))::int as seconds,
  count(*)                                                     as events,
  count(distinct screen)                                       as screens,
  coalesce(max((props->>'utc_offset_min')::int)
             filter (where event = 'app.opened'), 0)           as utc_offset_min,
  (min(occurred_at) at time zone 'UTC')
    + coalesce(max((props->>'utc_offset_min')::int)
                 filter (where event = 'app.opened'), 0) * interval '1 minute'
                                                               as local_started_at,
  max(platform)                                                as platform,
  max(app_version)                                             as app_version
from public.usage_events
group by visit_id, user_id, install_id;

-- ── RQ1 Entry / RQ6 Return ─────────────────────────────────────────────────
create view public.usage_rq1_daily with (security_invoker = true) as
select
  user_id,
  local_started_at::date        as day,
  count(*)                      as visits,
  sum(seconds)                  as seconds,
  min(extract(hour from local_started_at))::int as first_hour
from public.usage_visits
group by user_id, local_started_at::date;

-- Time-of-day heatmap: ISO weekday (1 = Monday) × local hour.
create view public.usage_rq1_hours with (security_invoker = true) as
select
  extract(isodow from local_started_at)::int as weekday,
  extract(hour from local_started_at)::int   as hour,
  count(*)                                   as visits,
  count(distinct user_id)                    as users
from public.usage_visits
group by 1, 2;

-- Return curve: did each tester come back the next day, in week 1, week 2?
create view public.usage_rq1_return with (security_invoker = true) as
with days as (
  select user_id, local_started_at::date as day from public.usage_visits
), firsts as (
  select user_id, min(day) as first_day from days group by user_id
)
select
  f.user_id,
  f.first_day,
  count(distinct d.day)                                               as active_days,
  bool_or(d.day = f.first_day + 1)                                    as returned_day_1,
  bool_or(d.day between f.first_day + 1 and f.first_day + 7)          as returned_week_1,
  bool_or(d.day between f.first_day + 8 and f.first_day + 14)         as returned_week_2
from firsts f
join days d using (user_id)
group by f.user_id, f.first_day;

-- ── RQ2 Login ──────────────────────────────────────────────────────────────
create view public.usage_rq2_login with (security_invoker = true) as
with per_user as (
  select
    user_id,
    count(*) filter (where event = 'auth.submit')                       as submits,
    count(*) filter (where event = 'auth.result'
                       and (props->>'ok')::boolean)                     as ok_results,
    count(*) filter (where event = 'auth.result'
                       and not (props->>'ok')::boolean)                 as failed_results,
    count(*) filter (where event = 'auth.screen_mode')                  as mode_switches,
    min(occurred_at) filter (where event = 'nav.screen_viewed'
                               and props->>'screen' = 'account')        as first_account_view,
    min(occurred_at) filter (where event = 'auth.result'
                               and (props->>'ok')::boolean)             as first_ok
  from public.usage_events
  group by user_id
)
select
  *,
  extract(epoch from first_ok - first_account_view)::int as seconds_to_first_ok
from per_user;

create view public.usage_rq2_login_errors with (security_invoker = true) as
select
  props->>'mode'          as mode,
  props->>'error'         as error,
  count(*)                as failures,
  count(distinct user_id) as users
from public.usage_events
where event = 'auth.result' and not (props->>'ok')::boolean
group by 1, 2;

-- ── RQ3 First use ──────────────────────────────────────────────────────────
-- When each tester first reached each step (null = never).
create view public.usage_rq3_first_use with (security_invoker = true) as
select
  user_id,
  min(occurred_at)                                                       as first_seen,
  min(occurred_at) filter (where event = 'splash.begin_tapped')          as splash_begin,
  min(occurred_at) filter (where event in ('onboarding.finished',
                                           'onboarding.skipped'))        as onboarding_done,
  min(occurred_at) filter (where event = 'nav.screen_viewed'
                             and props->>'screen' = 'account')           as account_view,
  min(occurred_at) filter (where event = 'auth.result'
                             and (props->>'ok')::boolean)                as signed_in,
  min(occurred_at) filter (where event = 'auth.consent_accepted')        as consent_accepted,
  min(occurred_at) filter (where (event = 'access.code_entered'
                                  and props->>'result' = 'ok')
                              or (event = 'auth.result'
                                  and props->>'mode' = 'create_account'
                                  and (props->>'ok')::boolean))          as activated,
  min(occurred_at) filter (where event = 'nav.screen_viewed'
                             and props->>'screen' = 'home')              as first_home,
  min(occurred_at) filter (where event = 'session.previewed')            as first_preview,
  min(occurred_at) filter (where event = 'session.started')              as first_session_started,
  min(occurred_at) filter (where event = 'session.completed')            as first_session_completed
from public.usage_events
group by user_id;

-- ── RQ4 Navigation ─────────────────────────────────────────────────────────
create view public.usage_rq4_transitions with (security_invoker = true) as
select
  coalesce(props->>'previous', '(start)') as from_screen,
  props->>'screen'                        as to_screen,
  count(*)                                as moves,
  count(distinct user_id)                 as users,
  count(*) filter (where props->>'via' = 'back') as by_back,
  count(*) filter (where props->>'via' = 'tab')  as by_tab
from public.usage_events
where event = 'nav.screen_viewed'
group by 1, 2;

create view public.usage_rq4_screen_time with (security_invoker = true) as
select
  props->>'screen'                                                    as screen,
  count(*)                                                            as visits,
  count(distinct user_id)                                             as users,
  percentile_cont(0.5) within group (order by (props->>'seconds')::numeric)
                                                                      as median_seconds,
  round(avg((props->>'scroll_depth_pct')::numeric), 1)                as avg_scroll_depth_pct,
  count(*) filter (where (props->>'seconds')::numeric < 2)            as under_2s
from public.usage_events
where event = 'nav.screen_left'
group by 1;

-- ── RQ5 Training and learning ──────────────────────────────────────────────
-- Per move: how long it really plays before people move on, and how.
create view public.usage_rq5_moves with (security_invoker = true) as
select
  (props->>'movement_id')::int                                         as movement_id,
  count(*)                                                             as plays,
  count(distinct user_id)                                              as users,
  percentile_cont(0.5) within group (order by (props->>'played_s')::numeric)
                                                                       as median_played_s,
  round(avg((props->>'reached_pct')::numeric), 1)                      as avg_reached_pct,
  count(*) filter (where props->>'how' = 'played_to_end')              as played_to_end,
  count(*) filter (where props->>'how' = 'next')                       as ended_by_next,
  count(*) filter (where props->>'how' = 'prev')                       as ended_by_prev,
  count(*) filter (where props->>'how' = 'replay')                     as ended_by_replay,
  count(*) filter (where props->>'how' = 'list_jump')                  as ended_by_list_jump,
  count(*) filter (where props->>'how' in ('left_session', 'app_killed')) as session_left_here,
  sum((props->>'seeks')::int)                                          as seeks,
  sum((props->>'pauses')::int)                                         as pauses
from public.usage_events
where event = 'player.move_ended'
group by 1;

create view public.usage_rq5_sessions with (security_invoker = true) as
select
  (props->>'session_id')::int                                         as session_id,
  count(*) filter (where event = 'session.started')                   as runs,
  count(*) filter (where event = 'session.completed')                 as completed,
  count(*) filter (where event = 'session.abandoned')                 as abandoned,
  count(*) filter (where event = 'session.started'
                     and props->>'mode' = 'learning')                 as learning_runs,
  count(*) filter (where event = 'session.started'
                     and props->>'mode' = 'athlete')                  as athlete_runs,
  count(*) filter (where event = 'session.started'
                     and props->>'mode' = 'zoorkhaneh')               as zoorkhaneh_runs,
  count(distinct user_id)                                             as users
from public.usage_events
where event in ('session.started', 'session.completed', 'session.abandoned')
group by 1;

-- Where sessions are left: the move index of each abandoned run.
create view public.usage_rq5_dropoff with (security_invoker = true) as
select
  (props->>'session_id')::int as session_id,
  (props->>'last_index')::int as last_index,
  count(*)                    as runs,
  count(*) filter (where props->>'how' = 'killed') as killed
from public.usage_events
where event = 'session.abandoned'
group by 1, 2;

-- "Lost before Start": previews per tester, how many ended without a start,
-- and how many they left before their first start.
create view public.usage_rq5_preview with (security_invoker = true) as
with per_user as (
  select
    user_id,
    count(*) filter (where event = 'session.previewed')                     as previews,
    count(*) filter (where event = 'preview.left' and props->>'how' = 'start') as starts,
    count(*) filter (where event = 'preview.left' and props->>'how' = 'back')  as previews_without_start,
    min(occurred_at) filter (where event = 'preview.left'
                               and props->>'how' = 'start')                 as first_start
  from public.usage_events
  group by user_id
)
select
  p.*,
  (select count(*) from public.usage_events e
    where e.user_id = p.user_id
      and e.event = 'preview.left' and e.props->>'how' = 'back'
      and (p.first_start is null or e.occurred_at < p.first_start))         as previews_before_first_start
from per_user p
where p.previews > 0;

-- ── Friction ───────────────────────────────────────────────────────────────
create view public.usage_dead_taps with (security_invoker = true) as
select
  screen,
  props->>'element'                                         as element,
  props->>'cell'                                            as cell,
  count(*)                                                  as taps,
  count(distinct user_id)                                   as users,
  count(*) filter (where (props->>'disabled_control')::boolean) as on_disabled
from public.usage_events
where event = 'ui.dead_tap'
group by 1, 2, 3;

-- Rage taps: 3+ dead taps on the same spot of a screen within 2 seconds.
-- One row per burst (the moment the third tap lands).
create view public.usage_rage_taps with (security_invoker = true) as
select user_id, visit_id, screen, element, cell, occurred_at
from (
  select
    user_id, visit_id, screen, occurred_at,
    props->>'element' as element,
    props->>'cell'    as cell,
    count(*) over (partition by visit_id, screen, props->>'cell'
                   order by occurred_at
                   range between interval '2 seconds' preceding and current row) as recent
  from public.usage_events
  where event = 'ui.dead_tap'
) t
where recent = 3;

-- ── Per-tester timeline ────────────────────────────────────────────────────
create view public.usage_timeline with (security_invoker = true) as
select
  e.user_id,
  e.visit_id,
  e.seq,
  e.occurred_at,
  (e.occurred_at at time zone 'UTC') + v.utc_offset_min * interval '1 minute' as local_time,
  e.screen,
  e.event,
  e.props,
  e.platform,
  e.app_version
from public.usage_events e
join public.usage_visits v using (visit_id, user_id, install_id);

-- ── Admin only ─────────────────────────────────────────────────────────────
do $$
declare
  v text;
begin
  foreach v in array array[
    'usage_visits', 'usage_rq1_daily', 'usage_rq1_hours', 'usage_rq1_return',
    'usage_rq2_login', 'usage_rq2_login_errors', 'usage_rq3_first_use',
    'usage_rq4_transitions', 'usage_rq4_screen_time', 'usage_rq5_moves',
    'usage_rq5_sessions', 'usage_rq5_dropoff', 'usage_rq5_preview',
    'usage_dead_taps', 'usage_rage_taps', 'usage_timeline'
  ] loop
    if exists (select 1 from pg_roles where rolname = 'anon') then
      execute format('revoke all on public.%I from anon', v);
    end if;
    if exists (select 1 from pg_roles where rolname = 'authenticated') then
      execute format('revoke all on public.%I from authenticated', v);
    end if;
  end loop;
end $$;
