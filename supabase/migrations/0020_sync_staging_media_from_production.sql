-- Data sync, not schema: staging was found to be missing real content that
-- already exists on production (staging never received these particular
-- content updates — nothing to do with the tracking feature in progress).
-- Written as idempotent upserts so it is safe to run on EITHER environment:
-- a no-op wherever the data already matches (production), and a real fill-in
-- wherever it's missing (staging).
--
-- Found via a full row-level diff between the two projects' `exercise`,
-- `movement`, `movement_info`, `video`, `training_session`, and
-- `training_session_item` tables. Excludes training_session_item's
-- is_tracked/tracked_movement_type columns (that's the in-development
-- tracking feature, staging-only by design) and the per-environment usage
-- tables (challenge_entry, invite_codes, profiles — expected to differ,
-- each environment accumulates its own real usage).

-- 1. video: 4 demonstration-video rows present on production, absent on
--    staging (ids 3-6). Explicit ids, so bump the sequence afterward or a
--    later admin.py upload (which lets Postgres assign the id) could try to
--    reuse one of these and collide.
insert into public.video (id, url, poster_url, width, height, duration_seconds, file_size_bytes, format, created_at, video_anchor_ms)
values
  (3, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/video/movements/1-vorod.mp4',
      'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/images/posters/1-vorod.jpg',
      1280, 720, 241.8, 53608414, 'h264/mp4', '2026-09-04T10:17:14.7604+00:00', 0),
  (4, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/video/movements/46-shenaye_shalaghi.mp4',
      'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/images/posters/46-shenaye_shalaghi.jpg',
      1280, 720, 49.8, 11981989, 'h264/mp4', '2026-09-04T10:17:19.239977+00:00', 0),
  (5, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/video/movements/54-narmeshhaye_zorkhonei.mp4',
      'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/images/posters/54-narmeshhaye_zorkhonei.jpg',
      1280, 720, 256.3, 61166898, 'h264/mp4', '2026-09-04T10:17:30.931192+00:00', 0),
  (6, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/video/movements/59-mile_aram_1st.mp4',
      'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/images/posters/59-mile_aram_1st.jpg',
      1280, 720, 56.9569, 13772279, 'h264/mp4', '2026-09-07T16:44:46.243165+00:00', 0)
on conflict (id) do nothing;

select setval(pg_get_serial_sequence('public.video', 'id'), (select max(id) from public.video));

-- 2. movement: point these 8 movements at their real demonstration video
--    (media_type/src/poster denormalized from `video`, per migration 0011's
--    write-through convention) with the correct sync anchor. Movements
--    59/60/61 (the Meel Aram trio) all share video_id 6 on production —
--    already-existing evidence they're meant to be one movement, consistent
--    with the merge already agreed on separately.
update public.movement set
  media_type = 'video',
  media_src = 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/video/movements/1-vorod.mp4',
  media_poster = 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/images/posters/1-vorod.jpg',
  video_id = 3, video_anchor_ms = 0
where id = 1;

update public.movement set video_anchor_ms = 571 where id = 4;

update public.movement set
  media_type = 'video',
  media_src = 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/video/movements/46-shenaye_shalaghi.mp4',
  media_poster = 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/images/posters/46-shenaye_shalaghi.jpg',
  video_id = 4, video_anchor_ms = 0
where id = 46;

update public.movement set
  media_type = 'video',
  media_src = 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/video/movements/54-narmeshhaye_zorkhonei.mp4',
  media_poster = 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/images/posters/54-narmeshhaye_zorkhonei.jpg',
  video_id = 5, video_anchor_ms = 0
where id = 54;

update public.movement set video_anchor_ms = 7600 where id = 57;

update public.movement set
  media_type = 'video',
  media_src = 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/video/movements/59-mile_aram_1st.mp4',
  media_poster = 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/images/posters/59-mile_aram_1st.jpg',
  video_id = 6, video_anchor_ms = 0
where id in (59, 60, 61);

-- 3. exercise: audio anchors set on production, missing on staging.
update public.exercise set audio_anchor_ms = 2800 where id = 4;
update public.exercise set audio_anchor_ms = 2000 where id = 45;
update public.exercise set audio_anchor_ms = 5000 where id = 57;

-- 4. movement_info: 7 rows of real description content present on
--    production, absent on staging. video_url is null on all of them on
--    production too (unused placeholder — see migration 0011's comment;
--    tracked separately as tech debt to move off of).
insert into public.movement_info (movement_id, description, video_url, updated_at)
values
  (2, 'Here we stay calm and focus. Get ready for the battle.', null, '2026-08-26T09:55:18.028754+00:00'),
  (1, 'Entry into the pit. You say loudly: "Rokhsat", you get the permission to enter the Gowd. You then symbolically kiss the earth (bend, touch the floor and kiss the hand that touched the floor). You do slight and smooth running around the pit and warm up.', null, '2026-08-26T12:40:14.44729+00:00'),
  (4, E'distance from board should be enough so that you can easily get up off the board onto your legs.\nthree cues for the shoulders: on top: scapular protraction, scapular depression and external rotation of the arms.\nThis Sheno has four counts, \nposition 1: Chest to the board, \nposition2: Up, stretch the left shoulder\nposition3: To the right, stretch the right shoulder\nposition4: To the middle and back, stretch both arms.\nall this time the head is slowly moving up and down with each move', null, '2026-08-26T09:51:57.421208+00:00'),
  (46, E'Continues push up. Feet together. \nUpper position: downward facing dog, \nLower position: straight body, chest to the board\n\nMore advanced version is a diving Persian push-up', null, '2026-08-26T12:43:03.45829+00:00'),
  (47, 'holding on the verse singing in the downward facing dog position with activated elevated scapula. At the end of the verse you do one push up and hold in Cobra position until the drumming is finished.', null, '2026-08-26T12:44:18.670313+00:00'),
  (48, 'holding on the verse singing in the downward facing dog position with activated elevated scapula. At the end of the verse you do TWO push ups and hold in Cobra position until the drumming is finished.', null, '2026-08-26T12:44:32.224761+00:00'),
  (49, E'holding on the verse singing in the downward facing dog position with activated elevated scapula. At the end of the verse you do Three push ups and hold in Cobra position until the drumming is finished.\n\nAlternatively: You can hold a plank position during the verse then switch to a side plank on the drumming part. Then back again to the standard plank and do other side plank on next round.', null, '2026-08-26T12:45:49.028872+00:00')
on conflict (movement_id) do nothing;
