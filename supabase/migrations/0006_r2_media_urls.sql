-- ═══════════════════════════════════════════════════════════════════════════
-- CLOUDFLARE R2 MEDIA CUTOVER — point exercise/movement media at R2 instead
-- of Supabase Storage.
--
-- Prerequisite (already verified 2026-07-29): every exercise.url and
-- movement.media_src (photo type) has a same-named file in the R2 bucket
-- "morshed-sounds", under "Sirvan/" (audio) and "movement_images/" (images)
-- respectively — confirmed via `uv run python scripts/check_r2_completeness.py`
-- (0 missing).
--
-- Backup columns are added first so this is a single-UPDATE rollback if
-- anything looks wrong after cutover:
--   update exercise set url = url_supabase where url_supabase is not null;
--   update movement set media_src = media_src_supabase where media_src_supabase is not null;
--
-- Safe to re-run: the WHERE clauses only match rows still pointing at
-- supabase.co, so a second run is a no-op.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Back up current (Supabase) URLs.
alter table public.exercise add column if not exists url_supabase text;
update public.exercise set url_supabase = url where url_supabase is null;

alter table public.movement add column if not exists media_src_supabase text;
update public.movement set media_src_supabase = media_src where media_src_supabase is null;

-- 2. Rewrite to R2 public URLs.
-- Filename is taken from the existing (already percent-encoded) Supabase URL,
-- stripping any query string (signed-URL `?token=...`) and everything up to
-- the last '/' — works for both signed and public Supabase URL shapes.
update public.exercise
  set url = 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/'
            || regexp_replace(split_part(url, '?', 1), '^.*/', '')
  where url like '%supabase.co/storage/%';

update public.movement
  set media_src = 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/movement_images/'
                  || regexp_replace(split_part(media_src, '?', 1), '^.*/', '')
  where media_src like '%supabase.co/storage/%';
