-- Drops the legacy per-exercise audio columns now that the Morshed audio-
-- catalog feature (movement_type / morshed / movement_audio_track) is live
-- on both staging and production and fully covers real content.
--
-- Readiness, confirmed (not assumed) against staging via
-- scripts/check_session_audio_coverage.py and scripts/compare_staging_production.py:
--   - 0 of 47 training_session_item rows rely on the legacy fallback.
--   - All 31 exercises actually referenced by real session items resolve
--     through a curated movement_audio_track.
--   - All 33 real movements have movement.type_id set (100%); movement.type
--     (the free-text column dropped below) is null on all of them —
--     confirmed dead weight, not just unpopulated.
--   - Production is caught up past 0022/0026 (the migrations that populate
--     movement_audio_track from these legacy columns) — safe to drop there
--     too once this has been verified on staging first.
--
-- This is the renumbered copy of 0023_drop_legacy_exercise_audio_columns.sql
-- (that file's gate condition is now satisfied). Requires a matching
-- Dart-side change in the same commit: Exercise.author/type and the
-- ExerciseRow/HiveExercise/mapExercise code paths that read these columns
-- are removed — Exercise.audioFileUrl/durationSeconds/audioAnchorMs stay as
-- domain fields but are populated only by audio_player_cubit.dart's
-- resolution step at playback time, never again from a raw DB column.

alter table public.exercise
  drop column if exists author,
  drop column if exists audio_url,
  drop column if exists duration_seconds,
  drop column if exists audio_anchor_ms;

alter table public.movement
  drop column if exists type;
