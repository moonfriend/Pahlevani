-- Seed data for migration tests.
-- Matches the real production schema (verified from supabase/dump 2026-06-26).
-- Uses ON CONFLICT DO NOTHING so the file is idempotent.

-- Movements (name/title_fa live here, not on exercise)
insert into public.movement (id, name, title_fa, media_type)
  values
    (1, 'Shena', 'شنا', 'none'),
    (2, 'Kabbadeh', 'کباده', 'none')
  on conflict (id) do nothing;

-- Exercises (no name/title_fa — those are on movement)
insert into public.exercise (id, movement_id, author, url, repetitions, duration_seconds)
  values
    (1, 1, 'Morshed A', 'https://example.com/shena.mp3',    10, 30),
    (2, 2, 'Morshed A', 'https://example.com/kabbadeh.mp3', 10, 45)
  on conflict (id) do nothing;

-- Sessions (manually assigned ids, no is_user_created column on server)
insert into public.training_session (id, title, description, difficulty, title_fa)
  values
    (1, 'Beginner Warm-up', 'A gentle intro session.',      1, 'گرم‌کردن مقدماتی'),
    (2, 'Advanced Drill',   'High-intensity compound work.', 3, 'تمرین پیشرفته')
  on conflict (id) do nothing;

-- Items
insert into public.training_session_item (training_session_id, exercise_id, position, reps_to_do)
  values
    (1, 1, 0, 10),
    (1, 2, 1, 10),
    (2, 2, 0, 20)
  on conflict (training_session_id, position) do nothing;
