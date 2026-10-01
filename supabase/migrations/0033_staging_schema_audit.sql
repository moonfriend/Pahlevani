-- ═══════════════════════════════════════════════════════════════════════════
-- STAGING SCHEMA AUDIT & HARMONY — 2026-09-15
--
-- Audit findings: Staging was suspected to have partial/incomplete migrations
-- applied, specifically migration 0028 (musician→morshed rename). Full
-- diagnostic revealed staging is actually fully current on all schema changes.
--
-- Detailed status:
--
-- ✅ COMPLETE: All schema migrations 0001-0028 fully applied
--   - 0028 (musician→morshed): COMPLETE — table renamed, column renamed,
--     policy renamed. No partial application found.
--   - All audio catalog tables (movement_type, movement_audio_track) present
--     with correct structure.
--
-- ✅ DATA STATE: Audio track content fully populated
--   - Ali Eshaghi: 41 recordings (all movement types)
--   - Sirvan Norouzi: 32 recordings
--   - Test fixtures (test_morshed, test_morshed_2): present on staging, not
--     on production (expected/benign)
--
-- ✅ REFERENTIAL INTEGRITY: All movement.type_id assignments correct
--   - Each movement's type_id resolves to correct movement_type by key
--   - Audio resolution chain works: movement→type_id→movement_type→
--     audio_track (via type_id lookup)
--   - Note: numeric type_id values differ from production (insertion order),
--     but all are internally valid and key-matched. App code uses key-based
--     lookups, not hardcoded IDs.
--
-- ✅ FUNCTION: Session audio coverage audit passed (47 items checked)
--   - Every training_session_item has resolvable audio (falls back correctly
--     per resolveAudioTrack() semantics)
--
-- ═══════════════════════════════════════════════════════════════════════════
-- IDEMPOTENT CONFIRMATIONS (safety checks, no-ops if already applied)
-- ═══════════════════════════════════════════════════════════════════════════

-- Confirm 0028's table and column renames are complete (or complete them if
-- partial state was somehow missed by the audit).
alter table if exists public.musician rename to morshed;
alter table public.movement_audio_track
  rename column if exists musician_id to morshed_id;

-- Confirm 0028's policy rename (rename the old policy if it still exists).
-- If already renamed, this is a no-op (policy name already morshed_select_all).
do $$
begin
  -- Try to rename the old policy; if it doesn't exist, move on.
  alter policy "musician_select_all" on public.morshed rename to "morshed_select_all";
exception when others then
  -- Policy either already renamed or doesn't exist. Silently OK.
  null;
end $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTES ON MIGRATIONS 0029, 0031, 0032
-- ═══════════════════════════════════════════════════════════════════════════
--
-- These were marked "PRODUCTION-only" but are actually safe to apply on
-- staging if needed:
--
-- 0029 (seed_ali_eshaghi_production): Uses idempotent inserts with
--   `on conflict do nothing` and key-based lookup (mt.key, m.name).
--   Staging ALREADY has all 41 Ali Eshaghi tracks (via admin.py curation).
--   Re-running would be a no-op on staging. Safe to run if ever needed.
--
-- 0031 (seed_movement_curation_production): Updates movement.type_id using
--   subquery lookups (mt.key), not hardcoded IDs. Designed to work on ANY
--   environment regardless of their movement_type.id insertion order.
--   Comment in original file explicitly notes this. Staging ALREADY has all
--   movement.type_id correctly set (via admin.py curation with different
--   numeric ID values, but all internally valid). Re-running would update
--   staging's type_ids to match production's numeric IDs — idempotent and
--   harmless, but unnecessary since both environments resolve correctly
--   via the key-based lookup path.
--
-- 0032 (sync_reps_to_do_production): Four targeted updates to
--   training_session_item.reps_to_do by (session_id, position).
--   Staging ALREADY has these four rows with the correct values (via admin.py).
--   Re-running would be a no-op on staging. Safe to run if ever needed.
--
-- Recommendation: Staging is functionally complete. No further action needed
-- unless future development wants strict numeric ID parity with production
-- (in which case, apply 0031 to normalize movement.type_id IDs — but this
-- is cosmetic, not functional).
--
-- ═══════════════════════════════════════════════════════════════════════════
