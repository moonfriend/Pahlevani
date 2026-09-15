-- Data fix, not schema: exercise 55 ("Khamgiri", movement_id 55) was entered
-- pointing at the same audio file as exercise 54 ("Narmeshhaye Zorkhonei",
-- movement_id 54) — identical audio_url and duration_seconds, and both play
-- back-to-back in the "Full Pahlevani Training with Farid" session. The
-- correct, dedicated recording for Khamgiri already exists in the R2 bucket
-- (Sirvan/14 Khamgiri.mp3 — confirmed via its own ID3 title tag
-- "14-خمگیری ها" and by the numbered track sequence having a gap at 14
-- between 13 Narmeshhaye Zorkhanei and 15 Shomareshe Gardan) but was never
-- linked. duration_seconds below (69) is ffprobe's actual measured duration
-- of that file, rounded, matching the convention in
-- scripts/calculate_exercise_durations.py.
--
-- Depends on migration 0018 (exercise.url renamed to audio_url).

update public.exercise
set
  audio_url = 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/14%20Khamgiri.mp3',
  duration_seconds = 69
where id = 55;
