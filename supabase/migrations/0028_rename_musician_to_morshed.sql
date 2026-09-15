-- Renames musician -> morshed throughout, to match what everyone (admin UI,
-- athletes) actually calls this concept. Purely a rename — no data changes,
-- no behavior changes. Existing rows (including the real Sirvan Norouzi /
-- Ali Eshaghi content and the test_morshed/test_morshed_2 fixtures) are
-- untouched, just now living under the new names.
--
-- Constraint/index auto-generated names (e.g.
-- movement_audio_track_movement_type_id_musician_id_key) are deliberately
-- left as-is — purely cosmetic, not worth the risk of guessing the exact
-- generated name wrong.

alter table public.musician rename to morshed;

alter table public.movement_audio_track rename column musician_id to morshed_id;

alter policy "musician_select_all" on public.morshed rename to "morshed_select_all";

comment on table public.morshed is
  'A "Morshed" — one reciter/musician whose recordings can be chosen by an athlete.';

comment on table public.movement_audio_track is
  'One Morshed''s recording of one movement type. Resolved at play time: exercise -> movement.type_id -> the athlete''s chosen Morshed''s track for that type, falling back to any track for that type if the chosen Morshed has none yet.';
