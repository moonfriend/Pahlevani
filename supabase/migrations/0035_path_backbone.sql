-- Path backbone: the Khan / Darvazeh / Godar progression system.
--
-- A single overall "path" is an ordered, flat sequence of nodes. A "Godar"
-- is a small waypoint station with an ordered checklist of items (a video,
-- a training session done N times, a quote, ...). "Darvazeh" (the Gate,
-- level zero) and "Khan" (Khan 1, Khan 2, ...) are bigger milestone nodes
-- along the same route -- modeled as the SAME node concept (path_node.kind)
-- rather than separate tables, so they can hold their own checklist items
-- too (currently unused for darvazeh/khan until that content is authored,
-- but the shape supports it from day one).
--
-- Content is authored exclusively via scripts/admin.py's service-role
-- client, same as movement/morshed/movement_audio_track -- see RLS below.
--
-- Deliberately out of scope here: sequential locking/gating (every node is
-- freely navigable; status is derived client-side from item completion, not
-- stored, so gating later is a pure read, no schema change), and progress
-- sync (progress lives in local Hive storage for now, not a table here).

create table public.path (
  id bigserial primary key,
  name text not null default 'Main Path',
  name_fa text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.path is
  'A single named progression path. Only one row exists for now (seeded by 0036) -- kept as a real table rather than hardcoding "there is only one path" so multiple named paths are a data change, not a migration, if ever wanted.';

create table public.path_node (
  id bigserial primary key,
  path_id bigint not null references public.path(id) on delete cascade,
  kind text not null check (kind in ('godar', 'darvazeh', 'khan')),
  position int not null,
  khan_number int,
  title text not null,
  title_fa text,
  subtitle text,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (path_id, position)
);
comment on table public.path_node is
  'One stop on the path: a Godar waypoint, or a Darvazeh/Khan milestone (kind). position is dense and zero-based within path_id, fully rewritten on every admin save -- same convention as training_session_item.position. khan_number is only meaningful when kind=''khan'' (e.g. display "Khan 2") and is nullable so a khan node can be authored before it''s numbered.';

create index path_node_path_id_idx on public.path_node (path_id);

create table public.path_node_item (
  id bigserial primary key,
  path_node_id bigint not null references public.path_node(id) on delete cascade,
  position int not null,
  item_type text not null check (item_type in ('session', 'video', 'quote')),
  training_session_id bigint references public.training_session(id) on delete restrict,
  repeat_count int not null default 1,
  video_url text,
  video_title text,
  quote_text text,
  quote_author text,
  created_at timestamptz not null default now(),
  unique (path_node_id, position)
);
comment on table public.path_node_item is
  'One checklist entry on a path_node. item_type selects which of the per-type columns apply (session: training_session_id + repeat_count; video: video_url/video_title; quote: quote_text/quote_author) -- inline nullable columns on one table rather than a normalized per-type table, matching this schema''s existing tolerance for nullable per-concern columns and keeping admin CRUD/Flutter mapping to a single insert/select with no joins. training_session_id is ON DELETE RESTRICT (not cascade/set null): a referenced session must be deliberately unlinked before it can be deleted, rather than silently leaving a broken item or dropping someone''s progress data.';

create index path_node_item_path_node_id_idx on public.path_node_item (path_node_id);
create index path_node_item_training_session_id_idx
  on public.path_node_item (training_session_id)
  where training_session_id is not null;

-- RLS: same public-read-only shape as movement/morshed/movement_audio_track
-- (see 0022_musician_audio_tracks.sql) -- content is curated exclusively via
-- the service-role admin tool, no public write policy.
alter table public.path enable row level security;
alter table public.path_node enable row level security;
alter table public.path_node_item enable row level security;

create policy "path_select_all" on public.path for select using (true);
create policy "path_node_select_all" on public.path_node for select using (true);
create policy "path_node_item_select_all" on public.path_node_item for select using (true);
