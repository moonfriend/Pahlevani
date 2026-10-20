-- ═══════════════════════════════════════════════════════════════════════════
-- READ BEFORE RUNNING
--
-- Not applied automatically — paste into the Supabase SQL Editor (staging
-- first, then production). Verified against a throwaway Postgres with
-- scripts/test_migration.sh.
--
-- Purely additive: one new single-row table. Installed app versions that
-- predate it never read it.
-- ═══════════════════════════════════════════════════════════════════════════

-- Home's info card: a short announcement linking to a page on our website
-- (first use: the meel guide). Edited from scripts/admin.py's "Home card"
-- tab. The app re-reads it on every start and every few hours, and shows it
-- raised ("NEW") until the user opens a version they haven't seen yet — so
-- changing the text or link here reaches everyone without an app release.
create table if not exists public.home_announcement (
  id smallint primary key default 1 check (id = 1),
  title text not null check (length(trim(title)) > 0),
  description text not null default '',
  url text not null check (url ~ '^https://'),
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.home_announcement enable row level security;

-- Readable by anyone, including the anon key with no session; an inactive
-- card is invisible, so Home simply shows none.
drop policy if exists "home_announcement_select_active" on public.home_announcement;
create policy "home_announcement_select_active" on public.home_announcement
  for select using (is_active);
-- No insert/update/delete policy — writable only with the service-role key
-- (scripts/admin.py).

-- First card: the meel guide (the page itself lives on rahaavi.com).
insert into public.home_announcement (id, title, description, url)
values (1, 'How to get your meel',
        'Make your own, order, or pre-order.', 'https://rahaavi.com')
on conflict (id) do nothing;
