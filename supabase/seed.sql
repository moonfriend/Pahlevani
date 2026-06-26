-- Seed data for migration tests.
-- Applied automatically by scripts/test_migration.sh after the baseline schema.
-- Uses INSERT ... ON CONFLICT DO NOTHING so the file is idempotent.

-- Movements
insert into public.movement (id, name, title_fa, media_type)
  values
    (1, 'Shena', 'شنا', 'none'),
    (2, 'Kabbadeh', 'کباده', 'none')
  on conflict (id) do nothing;

-- Exercises (audio recordings — url is intentionally a placeholder)
insert into public.exercise (id, movement_id, name, author, url, repetitions, duration_seconds)
  values
    (1, 1, 'Shena',    'Morshed A', 'https://example.com/shena.mp3',    10, 30),
    (2, 2, 'Kabbadeh', 'Morshed A', 'https://example.com/kabbadeh.mp3', 10, 45)
  on conflict (id) do nothing;

-- Sessions (manually assigned ids — no sequence on training_session.id)
insert into public.training_session (id, title, description, difficulty, title_fa, is_user_created)
  values
    (1, 'Beginner Warm-up',  'A gentle intro session.',      1, 'گرم‌کردن مقدماتی', false),
    (2, 'Advanced Drill',    'High-intensity compound work.', 3, 'تمرین پیشرفته',    true)
  on conflict (id) do nothing;

-- Items (session 1: Shena → Kabbadeh)
insert into public.training_session_item (training_session_id, exercise_id, position, reps_to_do)
  values
    (1, 1, 0, 10),
    (1, 2, 1, 10)
  on conflict (training_session_id, position) do nothing;

-- Items (session 2: Kabbadeh only)
insert into public.training_session_item (training_session_id, exercise_id, position, reps_to_do)
  values
    (2, 2, 0, 20)
  on conflict (training_session_id, position) do nothing;
