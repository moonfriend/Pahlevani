-- ═══════════════════════════════════════════════════════════════════════════
-- MOVEMENT INFO — per-move descriptive content for the item "info" page.
--
-- Holds the long-form description and (later) a demonstration video for each
-- movement, kept in its own table so the core `movement` row stays lean and the
-- info can grow independently. One row per movement.
--
-- Safe to apply on top of 0001–0004.
-- Applied to the local Docker stack immediately; apply to staging/prod via the
-- Supabase SQL Editor once those instances are ready.
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.movement_info (
  movement_id  bigint       primary key references public.movement(id) on delete cascade,
  description  text,
  video_url    text,
  updated_at   timestamptz  default now()
);

comment on table public.movement_info is
  'Per-move detail for the info page: long description + optional demo video.';

alter table public.movement_info enable row level security;

-- Public read, matching the rest of the content tables (movement, exercise).
create policy "movement_info_select_all"
  on public.movement_info for select using (true);
