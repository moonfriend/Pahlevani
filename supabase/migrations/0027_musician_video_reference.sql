-- Exercise-demonstration videos are timed (via video_anchor_ms/audio_anchor_ms
-- "sarzarb" sync) against Sirvan Norouzi's own recordings specifically — the
-- only performer the video library was ever calibrated to. Choosing a
-- different Morshed can leave video and audio out of sync, so the app needs
-- to know which musician that reference actually is, rather than hardcoding
-- a name in Flutter code.

alter table public.musician
  add column is_video_reference boolean not null default false;

update public.musician
  set is_video_reference = true
  where name = 'Sirvan Norouzi';
