-- ═══════════════════════════════════════════════════════════════════════════
-- 0041 — media file sizes + a default Morshed (download-before-play, M1)
--
-- The app will download a session's media completely before first play and
-- show the download size up front (see docs/ download-before-play plan).
-- That needs, without hardcoding anything in the app:
--
--   1. media_asset — one row per uploaded media file (audio, video, poster,
--      photo), keyed by its public URL, holding the file's real size in
--      bytes. Written by every admin upload; verified/repaired by
--      scripts/check_media_integrity.py (which also backfills existing
--      files). Keyed by URL rather than adding a size column to every table
--      that references media (movement_audio_track, movement, movement_info,
--      video, path_node_item ...): one place to write, one place to check,
--      and the app looks sizes up by the URL it is about to download.
--
--   2. morshed.is_default — which Morshed's recordings a first-time user
--      gets before choosing one. At most one row may be true (partial
--      unique index). Nothing in the app hardcodes a Morshed id.
--
-- Depends on: 0022 (morshed, then named musician) + 0028 (rename to morshed).
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.media_asset (
  url           text        primary key,
  size_bytes    bigint      not null check (size_bytes > 0),
  content_type  text,
  -- Last time the integrity script confirmed size_bytes against the object
  -- actually stored on R2 (null = recorded at upload, not yet re-verified).
  checked_at    timestamptz,
  updated_at    timestamptz not null default now()
);

comment on table public.media_asset is
  'Size (bytes) of every uploaded media file, keyed by its public URL. '
  'Written on admin upload; verified by scripts/check_media_integrity.py. '
  'Read by the app to show download sizes before a session is downloaded.';

alter table public.media_asset enable row level security;

-- The URLs themselves are public, so their sizes are too. Writes happen only
-- with the service role (admin tool / integrity script), which bypasses RLS.
drop policy if exists "media_asset_select_all" on public.media_asset;
create policy "media_asset_select_all" on public.media_asset
  for select using (true);

alter table public.morshed
  add column if not exists is_default boolean not null default false;

comment on column public.morshed.is_default is
  'The Morshed whose recordings a first-time user downloads before choosing '
  'one. At most one row may be true.';

create unique index if not exists morshed_single_default
  on public.morshed (is_default) where is_default;
