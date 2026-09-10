-- Lets a trainer flag a training_session_item as one of a small set of
-- trackable movement types (e.g. 'sheno_sarnavazi', 'meel_aram') when
-- designing a session, so the app can prompt for a rep count on completion
-- and build local history/progress views. Nullable, no enum/check
-- constraint — mirrors the existing dormant exercise.type/movement.type
-- text columns. Keys are matched against the app's TrackedMovementType enum
-- (lib/domain/entities/tracking/tracked_movement_type.dart); keep both in
-- sync by hand.
alter table public.training_session_item
  add column if not exists tracked_movement_type text;
