-- ═══════════════════════════════════════════════════════════════════════════
-- MOVEMENT VIDEO — richer demonstration-video metadata for a movement.
--
-- Photo media already lives on movement.media_type/media_src/media_poster.
-- Video attaches the same way (movement is the shared "move" concept —
-- exercise is a specific recorded instance of one, and doesn't carry media).
-- `video` holds richer bookkeeping metadata (dimensions, duration, file
-- size) than a bare URL column ever could; movement.video_id is primarily an
-- admin-side audit reference — the app itself continues to read
-- movement.media_type/media_src/media_poster exactly as it does for photos,
-- since the admin upload tool writes those fields directly on success.
--
-- Public content, same as movement/exercise/movement_info — RLS enabled with
-- a public select policy (unlike challenge_bot's private/service-role-only
-- tables), since the Flutter app's anon client needs to read it.
--
-- Supersedes the never-used movement_info.video_url placeholder (left in
-- place, unused — a cheap no-op to clean up later if desired).
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.video (
  id                bigserial   primary key,
  url               text        not null,
  poster_url        text,
  width             int,
  height            int,
  duration_seconds  numeric,
  file_size_bytes   bigint,
  format            text,
  created_at        timestamptz not null default now()
);

comment on table public.video is
  'Demonstration-video metadata (R2-hosted). movement.video_id references '
  'the row that produced that movement''s current media_src/media_poster.';

alter table public.movement
  add column if not exists video_id bigint references public.video(id);

comment on column public.movement.video_id is
  'Optional FK to video — admin-side bookkeeping/audit reference. The app '
  'reads media_type/media_src/media_poster directly, not this join.';

alter table public.video enable row level security;

create policy "video_select_all" on public.video for select using (true);
