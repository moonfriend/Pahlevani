-- ════════════════════════════════════════════════════════════════════════════
-- Generates the SQL that copies curated content from staging to production.
-- Run by scripts/db/build_content_sync.sh against a local database holding
-- staging in schema `stg` and production in `public`; prints one statement
-- per line. Only rows that differ are emitted, so re-running after the sync
-- prints nothing between BEGIN and COMMIT.
--
-- Rows are matched by stable keys, never by per-environment serial ids:
-- videos by url, movement types by key, morsheds by name.
--
-- Deliberately NOT copied (user decisions, 2026-10-20):
--   * training_session_item / exercise — staging reps are test values
--   * training_session titles — prod's Farsi titles are the curated ones
--   * movement_audio_track, morshed rows — prod has an extra real Morshed
--     and its own audio anchor; only the default Morshed flag is copied
--   * user data (profiles, invite_codes, activations, assignments, challenge*)
--   * path / fitness (hidden in Release 1), app_release_gate (cutover only)
-- ════════════════════════════════════════════════════════════════════════════

select stmt from (

select 0 as step, 'BEGIN;' as stmt

-- 1. File sizes of media (download progress). Keyed by url.
union all
select 1, format(
  'insert into public.media_asset (url, size_bytes, content_type, checked_at) values (%L, %s, %L, %L) '
  'on conflict (url) do update set size_bytes = excluded.size_bytes, content_type = excluded.content_type, checked_at = excluded.checked_at;',
  s.url, s.size_bytes, s.content_type, s.checked_at)
from stg.media_asset s
left join public.media_asset p using (url)
where p.url is null
   or (s.size_bytes, s.content_type) is distinct from (p.size_bytes, p.content_type)

-- 2. New videos (the -v2 follow-along videos). Prod assigns its own ids.
union all
select 2, format(
  'insert into public.video (url, poster_url, width, height, duration_seconds, file_size_bytes, format, video_anchor_ms) '
  'select %L, %L, %L, %L, %L, %L, %L, %L where not exists (select 1 from public.video where url = %L);',
  s.url, s.poster_url, s.width, s.height, s.duration_seconds, s.file_size_bytes, s.format, s.video_anchor_ms, s.url)
from stg.video s
where not exists (select 1 from public.video p where p.url = s.url)

-- 3. Movements: names, media, video (by url) and type (by key).
union all
select 3, format(
  'update public.movement set name = %L, title_fa = %L, gloss = %L, media_type = %L, media_src = %L, media_poster = %L, '
  'video_id = %s, video_anchor_ms = %L, type_id = %s where id = %s;',
  s.name, s.title_fa, s.gloss, s.media_type, s.media_src, s.media_poster,
  case when sv.url is null then 'null'
       else format('(select id from public.video where url = %L)', sv.url) end,
  s.video_anchor_ms,
  case when st.key is null then 'null'
       else format('(select id from public.movement_type where key = %L)', st.key) end,
  s.id)
from stg.movement s
join public.movement p on p.id = s.id
left join stg.video sv on sv.id = s.video_id
left join public.video pv on pv.id = p.video_id
left join stg.movement_type st on st.id = s.type_id
left join public.movement_type pt on pt.id = p.type_id
where (s.name, s.title_fa, s.gloss, s.media_type, s.media_src, s.media_poster, sv.url, s.video_anchor_ms, st.key)
      is distinct from
      (p.name, p.title_fa, p.gloss, p.media_type, p.media_src, p.media_poster, pv.url, p.video_anchor_ms, pt.key)

-- 4. Learning content per movement.
union all
select 4, format(
  'insert into public.movement_info (movement_id, description, video_url, cues, steps, variations) values (%s, %L, %L, %L, %L, %L) '
  'on conflict (movement_id) do update set description = excluded.description, video_url = excluded.video_url, '
  'cues = excluded.cues, steps = excluded.steps, variations = excluded.variations;',
  s.movement_id, s.description, s.video_url, s.cues, s.steps, s.variations)
from stg.movement_info s
left join public.movement_info p using (movement_id)
where p.movement_id is null
   or (s.description, s.video_url, s.cues, s.steps, s.variations)
      is distinct from (p.description, p.video_url, p.cues, p.steps, p.variations)

-- 5. Default Morshed, by name.
union all
select 5, format(
  'update public.morshed set is_default = (name = %L) where is_default is distinct from (name = %L);',
  d.name, d.name)
from (select name from stg.morshed where is_default) d
where exists (select 1 from public.morshed p where p.name = d.name)
  and exists (select 1 from public.morshed p where p.is_default is distinct from (p.name = d.name))

-- 6. Session Home slots and the needs-meel flag (nothing else on sessions).
union all
select 6, format(
  'update public.training_session set home_position = %L, needs_meel = %L where id = %s;',
  s.home_position, s.needs_meel, s.id)
from stg.training_session s
join public.training_session p using (id)
where (s.home_position, s.needs_meel) is distinct from (p.home_position, p.needs_meel)

-- 7. Onboarding cards: prod becomes exactly staging's set.
union all
select 7, 'delete from public.onboarding_cards;'
where exists (
  select position, title_en, body_en, title_fa, body_fa, image_url, builtin_image, is_active, links from stg.onboarding_cards
  except
  select position, title_en, body_en, title_fa, body_fa, image_url, builtin_image, is_active, links from public.onboarding_cards)
or exists (
  select position, title_en, body_en, title_fa, body_fa, image_url, builtin_image, is_active, links from public.onboarding_cards
  except
  select position, title_en, body_en, title_fa, body_fa, image_url, builtin_image, is_active, links from stg.onboarding_cards)
union all
select 8, format(
  'insert into public.onboarding_cards (position, title_en, body_en, title_fa, body_fa, image_url, builtin_image, is_active, links) values (%s, %L, %L, %L, %L, %L, %L, %L, %L);',
  s.position, s.title_en, s.body_en, s.title_fa, s.body_fa, s.image_url, s.builtin_image, s.is_active, s.links)
from stg.onboarding_cards s
where exists (
  select position, title_en, body_en, title_fa, body_fa, image_url, builtin_image, is_active, links from stg.onboarding_cards
  except
  select position, title_en, body_en, title_fa, body_fa, image_url, builtin_image, is_active, links from public.onboarding_cards)
or exists (
  select position, title_en, body_en, title_fa, body_fa, image_url, builtin_image, is_active, links from public.onboarding_cards
  except
  select position, title_en, body_en, title_fa, body_fa, image_url, builtin_image, is_active, links from stg.onboarding_cards)

-- 9. Locked-screen text and the Home card (single rows, id = 1).
union all
select 9, format(
  'update public.activation_gate set message = %L, link_label = %L, link_url = %L where id = 1;',
  s.message, s.link_label, s.link_url)
from stg.activation_gate s join public.activation_gate p using (id)
where (s.message, s.link_label, s.link_url) is distinct from (p.message, p.link_label, p.link_url)
union all
select 10, format(
  'update public.home_announcement set title = %L, description = %L, url = %L, is_active = %L where id = 1;',
  s.title, s.description, s.url, s.is_active)
from stg.home_announcement s join public.home_announcement p using (id)
where (s.title, s.description, s.url, s.is_active) is distinct from (p.title, p.description, p.url, p.is_active)

union all
select 99, 'COMMIT;'

) generated
order by step, stmt;
