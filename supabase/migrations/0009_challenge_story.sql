-- ═══════════════════════════════════════════════════════════════════════════
-- CHALLENGE BOT — story mode: reusable ASCII-art "story" templates that a
-- running challenge can optionally bind to (challenge.story_id).
--
-- Written to exclusively by challenge_bot/ (service-role key): the admin UI
-- (bot_admin.py) authors challenge_story rows, the bot's /start_challenge
-- command reads them by slug. Never read by the Flutter app or the
-- anon/authenticated PostgREST roles — RLS enabled, zero policies, same
-- pattern as 0008_challenge_bot.sql.
--
-- Design: challenge_story is a reusable "design" (slug + story text + ASCII
-- template); challenge (existing table) is the per-chat *running instance*,
-- optionally bound to one story via the new nullable story_id column. The
-- same story can run concurrently in many chats — each challenge row already
-- carries its own chat_id/target_amount/unit, so a nullable FK is enough; no
-- restructuring of the existing challenge table. No users/invite-list
-- concept — a story is a template, not a roster.
--
-- Pacing ("how many reps convert one '=' symbol") is deliberately NOT stored
-- here — it's derived at render time from the running challenge's own
-- target_amount divided by the story's symbol count (challenge_bot/
-- ascii_progress.py:symbols_done_count), since the same story can run with a
-- different target in every chat.
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.challenge_story (
  id               bigserial   primary key,
  slug             text        not null unique,
  title            text        not null,
  story_text       text        not null,
  template         text        not null,
  complete_art     text,
  fill_order       int[]       not null,
  created_at       timestamptz not null default now()
);

comment on table public.challenge_story is
  'Reusable story "design" authored in the Streamlit admin UI: story text plus '
  'an ASCII-art template using `=` as fillable/progress cells. No per-story '
  'users/invite-list — a story is a template, not a running challenge.';

comment on column public.challenge_story.template is
  'ASCII art with `=` marking fillable cells. Rendered progressively by '
  'challenge_bot/ascii_progress.py:render_ascii_progress().';

comment on column public.challenge_story.complete_art is
  'Optional alternate ASCII art shown verbatim once every `=` cell has been '
  'converted to `+`. Falls back to the fully-filled template when null.';

comment on column public.challenge_story.fill_order is
  'Permutation of range(count of "=" in template): fill_order[i] is the '
  'occurrence-index (0-based, template reading order) of the cell converted '
  'to "+" at rank i. Defaults to natural reading order '
  '(ascii_progress.default_fill_order); the admin UI may override with a '
  'custom path (e.g. bottom-up), validated as a full permutation before save.';

-- One running challenge instance may optionally be bound to a reusable story
-- design. Nullable and additive: existing plain challenges (story_id null)
-- are unaffected, and the same story can be bound to many concurrent
-- challenge rows (one per chat) since target_amount/unit already live on
-- challenge, not on challenge_story.
alter table public.challenge
  add column if not exists story_id bigint references public.challenge_story(id);

comment on column public.challenge.story_id is
  'Optional FK to challenge_story. Null = plain /challenge (today''s behavior, '
  'unchanged). Set = story-driven challenge started via /start_challenge; '
  '/total and /status prepend the rendered ASCII-art progress in that case.';

create index if not exists challenge_story_id_idx
  on public.challenge (story_id);

-- RLS enabled, no policies added — same rationale as 0008_challenge_bot.sql:
-- only the bot's/admin UI's service-role key touches this table.
alter table public.challenge_story enable row level security;
