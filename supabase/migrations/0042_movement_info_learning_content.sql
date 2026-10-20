-- ═══════════════════════════════════════════════════════════════════════════
-- READ BEFORE RUNNING
--
-- Not applied automatically — paste into the Supabase SQL Editor (staging
-- first, then production). Verified against a throwaway Postgres with
-- scripts/test_migration.sh.
--
-- Purely additive: three columns on movement_info, each with a default, so
-- installed app versions (which select named columns or ignore unknown
-- ones) are unaffected. The Kashi screens hide a section whose list is
-- empty, so moves without this content still render.
-- ═══════════════════════════════════════════════════════════════════════════

-- The learning content the Kashi design shows for a move, edited from
-- scripts/admin.py's Movements tab ("Info page content"). English only:
-- Farsi arrives later through translation files, not per-column fields.

-- "Pay attention to": the points shown in the player and the learning sheet.
alter table public.movement_info
  add column if not exists cues text[] not null default '{}'
    check (coalesce(array_length(cues, 1), 0) <= 3);

-- Numbered how-to steps on the learning card.
alter table public.movement_info
  add column if not exists steps text[] not null default '{}';

-- Lighter → harder variants for the learning card's selector, ordered
-- lightest first: [{"name": "...", "level": "EASIER · 4 KG", "reps": 12}].
alter table public.movement_info
  add column if not exists variations jsonb not null default '[]'::jsonb
    check (jsonb_typeof(variations) = 'array');

comment on column public.movement_info.cues is
  'Up to 3 short "pay attention to" points (player + learning sheet).';
comment on column public.movement_info.steps is
  'Numbered how-to steps for the learning card.';
comment on column public.movement_info.variations is
  'Lighter→harder variants: array of {name, level, reps}, lightest first.';
