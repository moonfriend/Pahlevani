-- Stage D of the musician-audio-catalog feature. DO NOT APPLY until Stage C
-- (the Flutter resolver + "Choose your Morshed" picker) has shipped and been
-- verified working live, AND every movement that needs audio has a
-- movement_type assigned with at least one movement_audio_track recorded
-- for it.
--
-- Why the gate matters: until that point, the player's fallback path
-- (resolveAudioTrack returning null -> lib/presentation/bloc/player/
-- audio_player_cubit.dart uses the exercise's own fields directly) is what
-- keeps audio working for every movement that hasn't been curated yet.
-- Applying this migration first — before curation is complete — silently
-- breaks playback for every such movement, with no error, just missing
-- audio.
--
-- Applying this ALSO requires a matching Dart-side change, not included
-- here on purpose (making it requires the real curation state to decide
-- when it's safe): drop Exercise.audioFileUrl/author/durationSeconds/
-- audioAnchorMs and the ExerciseRow/HiveExercise/mapExercise code that
-- reads them, and drop the movement?.type fallback in mapExercise's `type`
-- mapping (movement.type_id / MovementType fully replaces it by then).
--
-- NOT applied to staging or production by this session — provided as a
-- ready-to-run file for whenever Stage C is confirmed live. Validated only
-- against a local Docker Postgres for syntax/dependency correctness.

alter table public.exercise
  drop column if exists author,
  drop column if exists audio_url,
  drop column if exists duration_seconds,
  drop column if exists audio_anchor_ms;

alter table public.movement
  drop column if exists type;
