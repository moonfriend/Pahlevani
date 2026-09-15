-- PRODUCTION-only fix: 4 training_session_item.reps_to_do values were
-- corrected on staging (calibrating them to the real per-recording pacing
-- now in movement_audio_track) after the earlier production migrations were
-- generated, so production still has the stale counts. Found via
-- scripts/compare_staging_production.py-style diffing, matched by
-- (training_session_id, position) since that pairing is identical on both
-- sides (confirmed: same 4 sessions, same structure).

update public.training_session_item set reps_to_do = 5 where training_session_id = 1 and position = 0; -- exercise_id 1
update public.training_session_item set reps_to_do = 98 where training_session_id = 1 and position = 1; -- exercise_id 60
update public.training_session_item set reps_to_do = 4 where training_session_id = 1 and position = 2; -- exercise_id 54
update public.training_session_item set reps_to_do = 30 where training_session_id = 1 and position = 4; -- exercise_id 57
