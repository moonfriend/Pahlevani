-- Content-model cleanup pass. `exercise.url_supabase` is already gone
-- (dropped by 0013, applied to staging just before this migration was
-- written) — nothing to do for it here. This migration handles the rest:
--
-- 1. Rename exercise.url -> exercise.audio_url. The bare "url" name was
--    ambiguous once the table grew a second URL-shaped column history
--    (url_supabase); "audio_url" says what it actually holds. The app and
--    admin tooling are updated in the same change to read/write the new
--    name (lib/data/dtos/exercise_row.dart, scripts/admin.py,
--    scripts/calculate_exercise_durations.py,
--    scripts/check_r2_completeness.py, scripts/verify_r2_urls.py).
--
-- 2. Drop exercise.type. It duplicated the movement's name as free text
--    from before the movement_id FK existed, is never read by any app or
--    admin code path, and movement.type (kept — see below) already covers
--    the concept for whoever eventually populates it.
--
-- 3. Drop training_session_item.tracked_movement_type. Orphaned leftover
--    from a design reworked to training_session_item.is_tracked (migration
--    0017) — zero code references it anymore.
--
-- movement.type is deliberately KEPT (per product decision) even though it
-- is 100% null today and not yet read downstream — it's the intended future
-- home for a movement category/type concept.

alter table public.exercise
  rename column url to audio_url;

alter table public.exercise
  drop column if exists type;

alter table public.training_session_item
  drop column if exists tracked_movement_type;
