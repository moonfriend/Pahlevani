-- ═══════════════════════════════════════════════════════════════════════════
-- READ BEFORE RUNNING
--
-- Not applied automatically — paste into the Supabase SQL Editor (staging
-- first, then production). Verified against a throwaway Postgres with
-- scripts/test_migration.sh.
--
-- Purely additive: one defaulted column. App versions that predate it
-- ignore it.
-- ═══════════════════════════════════════════════════════════════════════════

-- Up to three link buttons under an onboarding card's text, e.g. the meel
-- card's "Make your own / Order / Pre-order":
--   [{"label": "Order", "url": "https://rahaavi.com/meel/order"}, …]
-- Edited in scripts/admin.py's Onboarding tab.
alter table public.onboarding_cards
  add column if not exists links jsonb not null default '[]'::jsonb
    check (jsonb_typeof(links) = 'array' and jsonb_array_length(links) <= 3);
