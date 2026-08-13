-- ═══════════════════════════════════════════════════════════════════════════
-- CHALLENGE BOT — optional "cursor glyph" for story-mode ascii art.
--
-- Written to exclusively by challenge_bot/ (service-role key), same as
-- 0009_challenge_story.sql — RLS enabled, zero policies.
--
-- When set, the bot renders this glyph in place of the most-recently
-- converted '=' symbol (the current progress "frontier"), giving a
-- lightweight moving-marker effect (e.g. a climber emoji) without requiring
-- the admin to author multi-frame or multi-row art. Null (the default)
-- means no cursor — existing stories are unaffected.
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.challenge_story
  add column if not exists cursor_glyph text;

comment on column public.challenge_story.cursor_glyph is
  'Optional glyph (e.g. an emoji) shown at the most-recently-converted "="
  cell instead of "+", to mark the current progress position. Null = no
  cursor. Rendered by challenge_bot/ascii_progress.py:render_ascii_progress().';
