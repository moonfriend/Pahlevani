-- PRODUCTION-only fix: the migration catch-up (0017-0029) brought over
-- schema and Ali Eshaghi's content, but movement.type_id was never
-- migrated -- it only ever existed as manual curation via admin.py's
-- 'Assign movements to a type' on staging, never captured in a migration.
-- Without it, resolveAudioTrack() can't find ANY track for ANY movement,
-- so the Morshed picker currently has zero effect on production --
-- confirmed via scripts/compare_staging_production.py.
--
-- This also explains why movement_audio_track only got Ali Eshaghi's 41
-- rows from 0029: migration 0026's Sirvan auto-curation requires
-- movement.type_id to already be set, so it silently matched 0 rows on
-- production. This migration seeds Sirvan's 32 real tracks directly
-- instead (same approach as 0029 -- reusing the already-live R2 URLs,
-- no re-upload), rather than depending on 0026 to be re-run.
--
-- Depends on 0028 (morshed rename) and 0029 (Ali Eshaghi seed) already applied.

-- ── movement.type_id, matched by movement_type.key (not by raw staging id --
-- the two environments' movement_type rows have different auto-generated
-- ids due to differing insert history, confirmed via the comparison script) ──

update public.movement set type_id = (select id from public.movement_type where key = '01_vorod') where id = 1;
update public.movement set type_id = (select id from public.movement_type where key = '02_salam_bastani') where id = 2;
update public.movement set type_id = (select id from public.movement_type where key = '04_shena_sar_navazi') where id = 4;
update public.movement set type_id = (select id from public.movement_type where key = '40_doa') where id = 40;
update public.movement set type_id = (select id from public.movement_type where key = '41_khoroj') where id = 41;
update public.movement set type_id = (select id from public.movement_type where key = '03_shomaresh_sang') where id = 44;
update public.movement set type_id = (select id from public.movement_type where key = '05_shenaye_shalaghi') where id = 46;
update public.movement set type_id = (select id from public.movement_type where key = '06_shenaye_shalaghi_1') where id = 47;
update public.movement set type_id = (select id from public.movement_type where key = '07_shenaye_shalaghi_2') where id = 48;
update public.movement set type_id = (select id from public.movement_type where key = '08_shenaye_shalaghi_3') where id = 49;
update public.movement set type_id = (select id from public.movement_type where key = '09_shenaye_shalaghi_va_khondan') where id = 50;
update public.movement set type_id = (select id from public.movement_type where key = '10_shomareshe_pich') where id = 51;
update public.movement set type_id = (select id from public.movement_type where key = '11_jangali') where id = 52;
update public.movement set type_id = (select id from public.movement_type where key = '12_paye_chapo_rast') where id = 53;
update public.movement set type_id = (select id from public.movement_type where key = '13_narmeshhaye_zorkhanei') where id = 54;
update public.movement set type_id = (select id from public.movement_type where key = '14_khamgiri') where id = 55;
update public.movement set type_id = (select id from public.movement_type where key = '15_shomareshe_gardan') where id = 56;
update public.movement set type_id = (select id from public.movement_type where key = '16_neshasto_barkhast') where id = 57;
update public.movement set type_id = (select id from public.movement_type where key = '17_paye_hamrah_ba_takhteh') where id = 58;
update public.movement set type_id = (select id from public.movement_type where key = '18_mile_aram') where id = 59;
update public.movement set type_id = (select id from public.movement_type where key = '19_narmeshe_ba_mil') where id = 62;
update public.movement set type_id = (select id from public.movement_type where key = '20_mil_shalaghi') where id = 63;
update public.movement set type_id = (select id from public.movement_type where key = '21_paye_aval') where id = 64;
update public.movement set type_id = (select id from public.movement_type where key = '22_paye_zarbdari') where id = 65;
update public.movement set type_id = (select id from public.movement_type where key = '23_paye_shateri_1_2_3') where id = 66;
update public.movement set type_id = (select id from public.movement_type where key = '24_jofti') where id = 67;
update public.movement set type_id = (select id from public.movement_type where key = '25_tabrizi') where id = 68;
update public.movement set type_id = (select id from public.movement_type where key = '26_ya_fatah') where id = 69;
update public.movement set type_id = (select id from public.movement_type where key = '27_se_pa_zadan') where id = 70;
update public.movement set type_id = (select id from public.movement_type where key = '28_chamani') where id = 71;
update public.movement set type_id = (select id from public.movement_type where key = '29_charke_tiz') where id = 72;
update public.movement set type_id = (select id from public.movement_type where key = '30_tak_fer') where id = 73;
update public.movement set type_id = (select id from public.movement_type where key = '36_shomareshe_kabade') where id = 74;

-- ── Sirvan Norouzi's real recordings (32 of 41 types -- the rest are
-- movements not yet curated with a type on staging either) ──

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/01%202_Vorod.mp3', 4, 246, null
  from public.movement_type mt, public.morshed m
  where mt.key = '01_vorod' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/02%20Salam%20Bastani.mp3', 4, 254, null
  from public.movement_type mt, public.morshed m
  where mt.key = '02_salam_bastani' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/01%201_Shomaresh%20Sang.mp3', 117, 792, null
  from public.movement_type mt, public.morshed m
  where mt.key = '03_shomaresh_sang' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/04%20Shena%20Sar%20Navazi_A60_rep.mp3', 60, 328, 2000
  from public.movement_type mt, public.morshed m
  where mt.key = '04_shena_sar_navazi' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/05%20Shenaye%20Shalaghi_A25_rep.mp3', 25, 51, null
  from public.movement_type mt, public.morshed m
  where mt.key = '05_shenaye_shalaghi' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/06%20Shenaye%20Shalaghi%201.mp3', 12, 160, null
  from public.movement_type mt, public.morshed m
  where mt.key = '06_shenaye_shalaghi_1' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/07%20Shenaye%20Shalaghi%202.mp3', 12, 196, null
  from public.movement_type mt, public.morshed m
  where mt.key = '07_shenaye_shalaghi_2' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/08%20Shenaye%20Shalaghi%203.mp3', 12, 218, null
  from public.movement_type mt, public.morshed m
  where mt.key = '08_shenaye_shalaghi_3' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/09%20Shenaye%20Shalaghi%20Va%20Khondan.mp3', 50, 198, null
  from public.movement_type mt, public.morshed m
  where mt.key = '09_shenaye_shalaghi_va_khondan' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/10%20Shomareshe%20Pich.mp3', 50, 96, null
  from public.movement_type mt, public.morshed m
  where mt.key = '10_shomareshe_pich' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/11%20Jangali.mp3', 1, 84, null
  from public.movement_type mt, public.morshed m
  where mt.key = '11_jangali' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/12%20Paye%20Chapo%20Rast.mp3', 1, 42, null
  from public.movement_type mt, public.morshed m
  where mt.key = '12_paye_chapo_rast' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/13%20Narmeshhaye%20Zorkhanei.mp3', 4, 261, null
  from public.movement_type mt, public.morshed m
  where mt.key = '13_narmeshhaye_zorkhanei' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/14%20Khamgiri.mp3', 1, 69, null
  from public.movement_type mt, public.morshed m
  where mt.key = '14_khamgiri' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/15%20Shomareshe%20Gardan.mp3', 50, 84, null
  from public.movement_type mt, public.morshed m
  where mt.key = '15_shomareshe_gardan' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/16%20Neshasto%20Barkhast.mp3', 30, 94, 5000
  from public.movement_type mt, public.morshed m
  where mt.key = '16_neshasto_barkhast' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/17%20Paye%20Hamrah%20Ba%20Takhteh.mp3', 1, 24, null
  from public.movement_type mt, public.morshed m
  where mt.key = '17_paye_hamrah_ba_takhteh' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/03%201_mil_1st.mp3', 117, 202, null
  from public.movement_type mt, public.morshed m
  where mt.key = '18_mile_aram' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/19%20Narmeshe%20Ba%20Mil.mp3', 1, 18, null
  from public.movement_type mt, public.morshed m
  where mt.key = '19_narmeshe_ba_mil' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/20%20Mil%20Shalaghi.mp3', 100, 101, null
  from public.movement_type mt, public.morshed m
  where mt.key = '20_mil_shalaghi' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/21%20Paye%20Aval.mp3', 5, 299, null
  from public.movement_type mt, public.morshed m
  where mt.key = '21_paye_aval' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/22%20Paye%20Zarbdari.mp3', 1, 18, null
  from public.movement_type mt, public.morshed m
  where mt.key = '22_paye_zarbdari' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/23%2000Paye%20Shateri.mp3', 1, 41, null
  from public.movement_type mt, public.morshed m
  where mt.key = '23_paye_shateri_1_2_3' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/24%20Jofti.mp3', 1, 8, null
  from public.movement_type mt, public.morshed m
  where mt.key = '24_jofti' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/25%20Tabrizi.mp3', 2, 148, null
  from public.movement_type mt, public.morshed m
  where mt.key = '25_tabrizi' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/26%20Ya%20Fatah.mp3', 1, 44, null
  from public.movement_type mt, public.morshed m
  where mt.key = '26_ya_fatah' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/27%20Se%20Pa%20Zadan.mp3', 1, 26, null
  from public.movement_type mt, public.morshed m
  where mt.key = '27_se_pa_zadan' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/28%20Chamani.mp3', 1, 88, null
  from public.movement_type mt, public.morshed m
  where mt.key = '28_chamani' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/29%20Charke%20Tiz.mp3', 1, 25, null
  from public.movement_type mt, public.morshed m
  where mt.key = '29_charke_tiz' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/32%20Paye%20Akhar%20Jangali%20.mp3', 1, 88, null
  from public.movement_type mt, public.morshed m
  where mt.key = '30_tak_fer' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/36%20Shomareshe%20Kabade.mp3', 117, 162, null
  from public.movement_type mt, public.morshed m
  where mt.key = '36_shomareshe_kabade' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/Sirvan/41%20Khoroj.mp3', 6, 356, null
  from public.movement_type mt, public.morshed m
  where mt.key = '41_khoroj' and m.name = 'Sirvan Norouzi'
  on conflict (movement_type_id, morshed_id) do nothing;
