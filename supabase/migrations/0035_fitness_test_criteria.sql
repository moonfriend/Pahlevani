-- ═══════════════════════════════════════════════════════════════════════════
-- FITNESS TEST CRITERIA — the "Haft Khan" self-assessment rubric.
--
-- Two charts ("stages": Bodyweight & Midline, Athletics & Power), each with 7
-- axes; an axis is either a single 7-level ladder or the average of 2
-- sub-tests (each also a 7-level ladder). One row per level per subtest.
--
-- This migration only creates the tables — seeding the ~16 subtests × 7
-- levels of actual rubric content is a separate, manual step via the new
-- "Fitness Test Criteria" admin.py tab. The app (lib/features/fitness_test/)
-- treats this data as read-only; it is never written from the client.
--
-- Safe to apply on top of 0001–0034.
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.fitness_test_chart (
  id          serial primary key,
  chart_key   text        unique not null,
  title       text        not null,
  sort_order  int         not null
);

create table if not exists public.fitness_test_axis (
  id             serial primary key,
  chart_id       int         not null references public.fitness_test_chart(id) on delete cascade,
  axis_key       text        not null,
  display_name   text        not null,
  scoring_logic  text        not null check (scoring_logic in ('single', 'average')),
  sort_order     int         not null,
  unique (chart_id, axis_key)
);

create table if not exists public.fitness_test_subtest (
  id                serial primary key,
  axis_id           int         not null references public.fitness_test_axis(id) on delete cascade,
  subtest_key       text        not null,
  display_name      text        not null,
  sort_order        int         not null,
  needs_bodyweight  boolean     not null default false,
  needs_height      boolean     not null default false,
  unique (axis_id, subtest_key)
);

create table if not exists public.fitness_test_level (
  id                          serial primary key,
  subtest_id                  int         not null references public.fitness_test_subtest(id) on delete cascade,
  level_number                int         not null check (level_number between 1 and 7),
  requirement_label           text        not null,
  input_label                 text        not null,
  input_unit                  text        not null,
  threshold_value             numeric     not null,
  higher_is_better             boolean     not null default true,
  ratio_denominator           text        check (ratio_denominator in ('bodyweight', 'height')),
  ratio_offset                numeric     not null default 0,
  continuous_from_previous    boolean     not null default true,
  unique (subtest_id, level_number)
);

comment on table public.fitness_test_chart is
  'A fitness-test stage (e.g. Bodyweight & Midline). Test-takers can complete stages independently.';
comment on table public.fitness_test_axis is
  'One radar-chart spoke / wizard step. scoring_logic=average means its score is the mean of 2 subtests.';
comment on table public.fitness_test_subtest is
  'One independently-scored 7-level ladder. Most axes have exactly 1; average-scoring axes have 2.';
comment on table public.fitness_test_level is
  'One rung of a subtest ladder. ratio_denominator set means the real target is threshold_value * bodyweight/height + ratio_offset (e.g. Broad Jump''s "Height + 30cm" = threshold_value 1.0, ratio_offset 30); continuous_from_previous=false marks a level that switches exercise/unit from the one below it, where the app cannot fractionally interpolate.';

alter table public.fitness_test_chart enable row level security;
alter table public.fitness_test_axis enable row level security;
alter table public.fitness_test_subtest enable row level security;
alter table public.fitness_test_level enable row level security;

-- Public read, matching the rest of the content tables (movement, exercise,
-- movement_info). Writes are admin-only via the service-role key used by
-- scripts/admin.py — no insert/update/delete policy is defined here.
create policy "fitness_test_chart_select_all"
  on public.fitness_test_chart for select using (true);
create policy "fitness_test_axis_select_all"
  on public.fitness_test_axis for select using (true);
create policy "fitness_test_subtest_select_all"
  on public.fitness_test_subtest for select using (true);
create policy "fitness_test_level_select_all"
  on public.fitness_test_level for select using (true);
