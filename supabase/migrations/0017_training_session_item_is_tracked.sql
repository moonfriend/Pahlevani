-- Lets a trainer flag any training_session_item for movement-history
-- tracking when designing a session — a plain per-item toggle, not a fixed
-- taxonomy. The app groups tracked items by their exercise's underlying
-- movement (exercise.movement_id) at completion time, so different
-- recordings/narrators of the same movement pool into one running total;
-- see lib/domain/usecases/tracking/detect_tracked_movements.dart.
alter table public.training_session_item
  add column if not exists is_tracked boolean not null default false;
