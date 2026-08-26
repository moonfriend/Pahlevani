-- ═══════════════════════════════════════════════════════════════════════════
-- DROP R2-MIGRATION BACKUP COLUMNS — exercise.url_supabase and
-- movement.media_src_supabase were added by 0006_r2_media_urls.sql purely as
-- a rollback path (pre-cutover Supabase Storage URLs), in case the R2 cutover
-- needed to be reverted.
--
-- That monitoring period is over: the R2 cutover has been confirmed working
-- since 2026-07-29, and the underlying Supabase Storage objects these columns
-- pointed at (the `tracks` and `movement-media` buckets) were deleted on
-- 2026-08-26 — so the URLs in these columns are now dead links anyway, and
-- rolling back to them is no longer possible regardless of whether the
-- columns exist. Nothing reads or writes these columns: no app code
-- (lib/), no admin tooling (scripts/), and no RLS policy, index, or
-- constraint references either one (verified against schema.sql before
-- writing this migration).
--
-- Safe to apply on top of 0001-0012.
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.exercise drop column if exists url_supabase;
alter table public.movement drop column if exists media_src_supabase;
