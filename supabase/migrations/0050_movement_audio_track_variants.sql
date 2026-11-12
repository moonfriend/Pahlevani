-- ════════════════════════════════════════════════════════════════════════════
-- Several recordings per movement type and Morshed ("variants").
--
-- Some movements have more than one recording by the same Morshed (e.g.
-- Mile Aram, Mile Aram avaz, Mile Aram avaz2). The app now picks one at random
-- when a move starts and, when the move needs more reps than that recording
-- holds, plays another one it hasn't played yet in that move.
--
-- Until now (type, Morshed) was unique (0022). That constraint kept its
-- pre-0028 auto-generated name, which is dropped here; a plain index keeps the
-- per-type lookup fast. Older app versions keep working: they play the first
-- recording they find for the type.
--
-- Note: seed migrations 0024–0031 use `on conflict (movement_type_id,
-- morshed_id)`. They have already run everywhere and must never be re-run
-- after this one.
--
-- Safe to run twice.
-- ════════════════════════════════════════════════════════════════════════════

alter table public.movement_audio_track
  drop constraint if exists movement_audio_track_movement_type_id_musician_id_key;

create index if not exists movement_audio_track_type_morshed_idx
  on public.movement_audio_track (movement_type_id, morshed_id);

comment on table public.movement_audio_track is
  'One recording of one movement type by one Morshed. A Morshed may have several recordings of the same type (variants); the app picks among them at random. Resolved at play time: exercise -> movement.type_id -> the athlete''s chosen Morshed''s tracks for that type, falling back to another Morshed''s tracks if the chosen one has none yet.';
