-- Test fixtures for manually verifying the musician-audio-catalog feature on staging.
-- Uses real, already-uploaded Sirvan recordings — the three original Mile Aram exercises
-- (59/60/61), merged into one movement by 0021 but never deleted, each with its own
-- genuinely distinct audio. Turns that pre-existing duplication into the test case itself:
-- one movement_type, three musicians (the real one + two throwaway test ones), so the
-- Morshed picker has three real, audibly different recordings to switch between.
--
-- Test-only scaffolding, not real curation — safe to leave (adds data, touches nothing
-- existing) but should be reviewed/removed before any real release.
--
-- Requires 0022_musician_audio_tracks.sql already applied.

insert into public.movement_type (key, display_name, display_name_fa)
  values ('mile_aram', 'Mile Aram', null)
  on conflict (key) do nothing;

update public.movement
  set type_id = (select id from public.movement_type where key = 'mile_aram')
  where id = 59;

-- musician.name has no unique constraint, so a plain `on conflict do nothing`
-- here wouldn't actually prevent duplicates on a re-run (and every insert
-- below keys off musician name) — guard with `where not exists` instead.
insert into public.musician (name)
  select v.name from (values ('test_morshed'), ('test_morshed_2')) as v(name)
  where not exists (select 1 from public.musician m where m.name = v.name);

-- Sirvan (real musician) — the "original" recording (exercise 59).
insert into public.movement_audio_track
    (movement_type_id, musician_id, audio_url, repetitions_default, duration_seconds)
  values (
    (select id from public.movement_type where key = 'mile_aram'),
    (select id from public.musician where name = 'Sirvan Norouzi'),
    'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/03%201_mil_1st.mp3',
    100, 202
  )
  on conflict (movement_type_id, musician_id) do nothing;

-- test_morshed — a "copy" of Sirvan, but with the avaz2 recording (exercise 61) for this type.
insert into public.movement_audio_track
    (movement_type_id, musician_id, audio_url, repetitions_default, duration_seconds)
  values (
    (select id from public.movement_type where key = 'mile_aram'),
    (select id from public.musician where name = 'test_morshed'),
    'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/18%2003_Mile%20Aram_avaz2.mp3',
    100, 268
  )
  on conflict (movement_type_id, musician_id) do nothing;

-- test_morshed_2 — deliberately incomplete: only this one recording exists for them at all
-- (the remaining "avaz" track, exercise 60), to exercise the any-musician fallback for
-- every other movement type once curated.
insert into public.movement_audio_track
    (movement_type_id, musician_id, audio_url, repetitions_default, duration_seconds)
  values (
    (select id from public.movement_type where key = 'mile_aram'),
    (select id from public.musician where name = 'test_morshed_2'),
    'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/18%2002_Mile%20Aram_avaz.mp3',
    100, 271
  )
  on conflict (movement_type_id, musician_id) do nothing;
