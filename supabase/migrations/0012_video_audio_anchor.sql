-- ═══════════════════════════════════════════════════════════════════════════
-- VIDEO/AUDIO ANCHOR — a shared "sarzarb" (main beat) timestamp for syncing
-- an exercise's demonstration video to its audio narration.
--
-- Each anchor is a property of its own media asset, not of a pairing:
-- exercise.audio_anchor_ms marks the beat in that audio recording;
-- video.video_anchor_ms marks the same beat in that video file. The player
-- computes a constant start offset at runtime as the difference between the
-- two for whichever (exercise, movement) pair is currently playing — no N×M
-- pairing table needed, since a movement has one video and each exercise
-- recording has its own independent narration pace.
--
-- movement.video_anchor_ms is a write-through copy of video.video_anchor_ms,
-- same pattern as movement.media_type/media_src/media_poster mirroring the
-- video table's admin-side metadata: the app reads movement directly and
-- never joins video, so the copy keeps that read path unchanged.
--
-- All nullable — absence just means "no sync anchor set for this asset yet",
-- degrading to today's decoupled-loop behavior.
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.exercise
  add column if not exists audio_anchor_ms integer;

comment on column public.exercise.audio_anchor_ms is
  'Timestamp (ms) of the "sarzarb"/main beat in this exercise''s audio '
  'recording, for video/audio sync. Null = no anchor set.';

alter table public.video
  add column if not exists video_anchor_ms integer;

comment on column public.video.video_anchor_ms is
  'Timestamp (ms) of the "sarzarb"/main beat in this video file, for '
  'video/audio sync. Null = no anchor set.';

alter table public.movement
  add column if not exists video_anchor_ms integer;

comment on column public.movement.video_anchor_ms is
  'Write-through copy of video.video_anchor_ms — the app reads this '
  'directly, same pattern as media_type/media_src/media_poster.';
