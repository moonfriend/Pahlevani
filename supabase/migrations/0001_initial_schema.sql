-- ════════════════════════════════════════════════════════════════════════
-- BASELINE SCHEMA — derived from actual production data (verified 2026-06-26)
--
-- How this was verified: supabase/dump/tables/*.json was inspected to get
-- the union of all column names across all rows for each table.
--
-- Applied automatically by scripts/test_migration.sh (no live Supabase
-- connection needed — migration files are the source of truth).
-- ════════════════════════════════════════════════════════════════════════

-- ── movement ─────────────────────────────────────────────────────────────
create table if not exists public.movement (
  id           bigserial    primary key,
  name         text         not null,
  title_fa     text,
  gloss        text,
  type         text,
  media_type   text         not null default 'none',
  media_src    text,
  media_poster text,
  updated_at   timestamptz  default now()
);

-- ── exercise ──────────────────────────────────────────────────────────────
-- Note: name/title_fa/gloss/media_* live on movement, not exercise.
create table if not exists public.exercise (
  id               bigserial   primary key,
  movement_id      bigint      references public.movement(id),
  author           text,
  type             text,
  url              text,
  repetitions      int         not null default 1,
  duration_seconds int,
  updated_at       timestamptz default now()
);

-- ── training_session ──────────────────────────────────────────────────────
-- Note: id has no sequence — manually assigned in admin.py.
-- Note: is_user_created is a local-only Hive concept; not a server column.
create table if not exists public.training_session (
  id          int          primary key,
  title       text         not null,
  description text,
  difficulty  int          default 2,
  title_fa    text,
  created_at  timestamptz  default now(),
  updated_at  timestamptz  default now()
);

-- ── training_session_item ─────────────────────────────────────────────────
create table if not exists public.training_session_item (
  training_session_id int         not null references public.training_session(id) on delete cascade,
  exercise_id         bigint      not null references public.exercise(id),
  position            int         not null,
  reps_to_do          int         not null default 1,
  updated_at          timestamptz default now(),
  primary key (training_session_id, position)
);

-- ── Row-Level Security (anon-readable, no anon writes) ────────────────────
alter table public.movement              enable row level security;
alter table public.exercise              enable row level security;
alter table public.training_session      enable row level security;
alter table public.training_session_item enable row level security;

create policy "movement_select_all"              on public.movement              for select using (true);
create policy "exercise_select_all"              on public.exercise              for select using (true);
create policy "training_session_select_all"      on public.training_session      for select using (true);
create policy "training_session_item_select_all" on public.training_session_item for select using (true);
