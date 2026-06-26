-- ═══════════════════════════════════════════════════════════════════════════
-- BASELINE SCHEMA — reconstructed from application DTOs and admin.py.
--
-- ⚠️  SYNC FROM PRODUCTION BEFORE FIRST RUN:
--
--   1. Install Supabase CLI:  https://supabase.com/docs/guides/local-development
--   2. Link project:          supabase link --project-ref <your-project-ref>
--   3. Dump production schema: supabase db dump --schema public -f /tmp/prod.sql
--   4. Compare /tmp/prod.sql against this file and reconcile any differences.
--
-- This file is the single source of truth for migration tests. Differences
-- between this file and production will cause test failures — that is the
-- desired behaviour (the tests are telling you the truth diverged).
--
-- How to use: this file is applied automatically by scripts/test_migration.sh
-- to spin up an isolated PostgreSQL container for schema validation.
-- ═══════════════════════════════════════════════════════════════════════════

-- ------------------------------------------------------------------
-- movement  (reusable exercise movements — parent of exercise)
-- ------------------------------------------------------------------
create table if not exists public.movement (
  id          bigserial   primary key,
  name        text        not null,
  title_fa    text,
  gloss       text,
  type        text,
  media_type  text        not null default 'none',
  media_src   text,
  media_poster text
);

-- ------------------------------------------------------------------
-- exercise  (an audio recording of a movement, by one author)
-- ------------------------------------------------------------------
create table if not exists public.exercise (
  id               bigserial primary key,
  movement_id      bigint    references public.movement(id),
  name             text,
  title_fa         text,
  gloss            text,
  author           text,
  type             text,
  url              text,
  repetitions      integer   not null default 1,
  duration_seconds integer,
  media_type       text,
  media_src        text,
  media_poster     text
);

-- ------------------------------------------------------------------
-- training_session  (session metadata — no sequence: id is manually assigned)
-- ------------------------------------------------------------------
create table if not exists public.training_session (
  id              integer   primary key,
  title           text      not null,
  description     text,
  difficulty      integer   default 2,
  title_fa        text,
  is_user_created boolean   default false,
  created_at      timestamptz default now()
);

-- ------------------------------------------------------------------
-- training_session_item  (ordered join: session + exercise + prescription)
-- ------------------------------------------------------------------
create table if not exists public.training_session_item (
  training_session_id integer   not null references public.training_session(id) on delete cascade,
  exercise_id         bigint    not null references public.exercise(id),
  position            integer   not null,
  reps_to_do          integer   not null default 1,
  primary key (training_session_id, position)
);

-- ------------------------------------------------------------------
-- Row-Level Security (match production: anon-readable, no anon writes)
-- ------------------------------------------------------------------
alter table public.movement              enable row level security;
alter table public.exercise              enable row level security;
alter table public.training_session      enable row level security;
alter table public.training_session_item enable row level security;

create policy "movement_select_all"              on public.movement              for select using (true);
create policy "exercise_select_all"              on public.exercise              for select using (true);
create policy "training_session_select_all"      on public.training_session      for select using (true);
create policy "training_session_item_select_all" on public.training_session_item for select using (true);
