-- Merges the three "Meel Aram" movements (59 "Mile Aram 1st", 60 "Mile Aram
-- Avaz 1", 61 "Mile Aram Avaz 2") into one — they're the same physical
-- movement with three different audio variations, previously entered as
-- three separate movement rows, which broke history-tracking pooling (see
-- the earlier conversation finding: both 60 and 61 appear, tracked, in the
-- same "Morning Ritual" session). No movement_info rows reference 60/61
-- (verified before writing this), so there's nothing else to repoint.
--
-- Confirmed NOT yet applied on staging as of this writing, despite being
-- discussed/approved earlier — movements 59/60/61 still exist separately.

update public.exercise
  set movement_id = 59
  where movement_id in (60, 61);

delete from public.movement
  where id in (60, 61);
