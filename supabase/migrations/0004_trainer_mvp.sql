-- ═══════════════════════════════════════════════════════════════════════════
-- TRAINER MVP — adds the two columns needed for trainer-assigned sessions
-- and section-structured training items.
--
-- Safe to apply on top of 0001 + 0002 + 0003.
-- Applied to the local Docker stack immediately; apply to staging/prod via
-- the Supabase SQL Editor once those instances are ready.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. training_session.is_public ─────────────────────────────────────────
-- Controls whether a session is visible to all trainees (public library) or
-- only to the assigned trainee (assigned_to_user_id).
--   true  → shown in the public library (default for all existing sessions)
--   false → private; visible only to assigned_to_user_id and the trainer
--
-- Existing rows get DEFAULT true so the current library remains fully visible.

alter table public.training_session
  add column if not exists is_public boolean not null default true;

-- ── 2. training_session_item.section ──────────────────────────────────────
-- The training discipline this item belongs to within the session.
-- The seven Pahlevani disciplines, plus a generic fallback:
--   warm_up  — preparatory warm-up movement
--   sheno    — شنو  push-type exercises
--   mobility — joint mobility / stretching
--   meel     — میل  Indian club exercises
--   charkh   — چرخ  rotation / wheel movements
--   kabbade  — کباده cable / bow-pull exercises
--   sang     — سنگ  stone / weight work
--   other    — catch-all for future or uncategorised items
--
-- NULL is allowed so that existing rows (pre-MVP) are valid without backfill;
-- the app treats NULL the same as 'other'.

alter table public.training_session_item
  add column if not exists section text
  check (section in ('warm_up','sheno','mobility','meel','charkh','kabbade','sang','other'));

comment on column public.training_session_item.section is
  'Pahlevani discipline bucket: warm_up | sheno | mobility | meel | charkh | kabbade | sang | other';
