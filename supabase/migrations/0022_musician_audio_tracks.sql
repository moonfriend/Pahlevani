-- Stage A of the musician-audio-catalog feature (see the design/plan agreed
-- this session). Purely additive — nothing existing changes shape or
-- behavior. `exercise`'s audio columns (author, audio_url, duration_seconds,
-- audio_anchor_ms) are untouched here; the app keeps working exactly as
-- today until Stage C (Flutter) ships and Stage D (later) drops them.
--
-- movement_type and movement_audio_track start EMPTY on purpose — there is
-- no automatic way to decide which rhythm/category each of the 35 real
-- movements belongs to; that's a content-curation decision for a human via
-- the Stage B admin.py tooling, not something to infer here.

create table public.musician (
  id bigint generated always as identity primary key,
  name text not null,
  photo_url text,
  updated_at timestamptz default now()
);
comment on table public.musician is
  'A "Morshed" — one reciter/musician whose recordings can be chosen by an athlete. Stage A backfills the two authors already present in exercise.author.';

insert into public.musician (name)
  select distinct author from public.exercise where author is not null;

create table public.movement_type (
  id bigint generated always as identity primary key,
  key text not null unique,
  display_name text not null,
  display_name_fa text,
  updated_at timestamptz default now()
);
comment on table public.movement_type is
  'The rhythm/category a movement belongs to (e.g. "sarnavazi"). Curated by hand via admin.py — empty until a maintainer assigns movements to types (Stage B). Distinct from the pre-existing, unused movement.type free-text column, which this supersedes and which is dropped later (Stage D) once every movement has a type_id.';

alter table public.movement
  add column type_id bigint references public.movement_type(id);

create table public.movement_audio_track (
  id bigint generated always as identity primary key,
  movement_type_id bigint not null references public.movement_type(id),
  musician_id bigint not null references public.musician(id),
  audio_url text not null,
  repetitions_default integer not null default 1,
  duration_seconds integer,
  audio_anchor_ms integer,
  updated_at timestamptz default now(),
  unique (movement_type_id, musician_id)
);
comment on table public.movement_audio_track is
  'One musician''s recording of one movement type. Resolved at play time: exercise -> movement.type_id -> the athlete''s chosen musician''s track for that type, falling back to any track for that type if the chosen musician has none yet.';

-- RLS: same public-read-only shape as the other content tables (movement,
-- exercise) — see 0001_initial_schema.sql and 0015_drop_public_read_write.sql
-- for the established pattern this mirrors. No public write policy: content
-- is curated exclusively via the service-role admin tool, same as
-- movement/exercise/training_session today.
alter table public.musician enable row level security;
alter table public.movement_type enable row level security;
alter table public.movement_audio_track enable row level security;

create policy "musician_select_all" on public.musician for select using (true);
create policy "movement_type_select_all" on public.movement_type for select using (true);
create policy "movement_audio_track_select_all" on public.movement_audio_track for select using (true);
