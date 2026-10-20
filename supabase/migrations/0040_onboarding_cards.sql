-- ═══════════════════════════════════════════════════════════════════════════
-- READ BEFORE RUNNING
--
-- Not applied automatically — paste into the Supabase SQL Editor (staging
-- first, then production). Verified against a throwaway Postgres with
-- scripts/test_migration.sh.
--
-- Numbering: 0035–0039 are reserved by the unmerged Path / Fitness branches,
-- so this is 0040.
--
-- Purely additive: one new table, nothing else touched. Installed app
-- versions that predate it never read it; versions that do read it fall back
-- to their built-in cards until this table exists and has active rows.
-- ═══════════════════════════════════════════════════════════════════════════

-- The first-open onboarding cards, edited from scripts/admin.py's
-- "Onboarding" tab. The app fetches the active rows (ordered by position) on
-- launch and caches them, so cards can change without an app update.
create table if not exists public.onboarding_cards (
  id bigint generated always as identity primary key,
  position int not null default 0,
  title_en text not null check (length(trim(title_en)) > 0),
  body_en text not null default '',
  title_fa text,
  body_fa text,
  -- Picture: an uploaded image (R2 public URL) wins; otherwise a visual
  -- bundled in the app — works offline and costs nothing:
  --   figure      the figure the app picked for this session
  --   figure_alt  the other figure
  --   shamseh     a shamseh rosette
  image_url text,
  builtin_image text not null default 'figure'
    check (builtin_image in ('figure', 'figure_alt', 'shamseh')),
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

create index if not exists onboarding_cards_position_idx
  on public.onboarding_cards (position);

alter table public.onboarding_cards enable row level security;

-- Readable by anyone, including the anon key with no session — onboarding
-- runs before anyone signs in. Only active cards are visible, so drafts and
-- retired cards never reach the app.
drop policy if exists "onboarding_cards_select_active" on public.onboarding_cards;
create policy "onboarding_cards_select_active" on public.onboarding_cards
  for select using (is_active);
-- No insert/update/delete policy — writable only with the service-role key
-- (scripts/admin.py).

-- Seed with the cards the app ships with, so the table starts out matching
-- what users already see. Only when the table is empty (safe to re-run).
insert into public.onboarding_cards
  (position, title_en, body_en, title_fa, body_fa, builtin_image)
select * from (values
  (1, 'Train with your morshed',
      'Each session is a video led by the morshed’s voice and the beat of the zarb.',
      'با مرشد تمرین کن', 'هر جلسه ویدیویی است با صدای مرشد و ضرب.', 'figure'),
  (2, 'Count what matters',
      'Your trainers mark the moves worth counting. Log your reps as you go.',
      'آنچه مهم است را بشمار',
      'مربیان حرکت‌هایی را که باید شمرد مشخص می‌کنند. تکرارهایت را ثبت کن.',
      'figure_alt'),
  (3, 'Lay a tile every session',
      'Your shamseh grows ring by ring. It never resets, so a missed week costs you nothing.',
      'هر جلسه، یک کاشی',
      'شمسه‌ی تو حلقه به حلقه بزرگ می‌شود و هیچ‌وقت صفر نمی‌شود.', 'shamseh')
) as seed(position, title_en, body_en, title_fa, body_fa, builtin_image)
where not exists (select 1 from public.onboarding_cards);
