-- PRODUCTION-only content migration: populates Ali Eshaghi's real recordings
-- (all 41 movement types) using the R2 files already uploaded during staging
-- curation -- R2 is one shared bucket/account across environments (confirmed
-- earlier this session: same public base URL, same bucket, no re-upload needed).
--
-- Safe to run anywhere (idempotent via the existing unique constraint on
-- (movement_type_id, morshed_id)), but only actually needed on production --
-- staging already has this exact data from the real admin.py batch upload.
--
-- Depends on 0028 (musician -> morshed rename) already applied.

insert into public.morshed (name)
  select 'Ali Eshaghi'
  where not exists (select 1 from public.morshed where name = 'Ali Eshaghi');

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/2-1-01_vorod_01_vorod.mp3', 2, 131, null
  from public.movement_type mt, public.morshed m
  where mt.key = '01_vorod' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/3-1-02_salam_bastani_02_salam_bastani.mp3', 2, 135, null
  from public.movement_type mt, public.morshed m
  where mt.key = '02_salam_bastani' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/4-1-03_shomaresh_sang_03_shomaresh_sang.mp3', 117, 808, null
  from public.movement_type mt, public.morshed m
  where mt.key = '03_shomaresh_sang' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/5-1-04_shena_sar_navazi_04_shena_sar_navazi.mp3', 42, 213, null
  from public.movement_type mt, public.morshed m
  where mt.key = '04_shena_sar_navazi' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/6-1-05_shenaye_shalaghi_05_shenaye_shalaghi.mp3', 40, 58, null
  from public.movement_type mt, public.morshed m
  where mt.key = '05_shenaye_shalaghi' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/7-1-06_shenaye_shalaghi_1_06_shenaye_shalaghi_1.mp3', 4, 61, null
  from public.movement_type mt, public.morshed m
  where mt.key = '06_shenaye_shalaghi_1' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/8-1-07_shenaye_shalaghi_2_07_shenaye_shalaghi_2.mp3', 4, 64, null
  from public.movement_type mt, public.morshed m
  where mt.key = '07_shenaye_shalaghi_2' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/9-1-08_shenaye_shalaghi_3_08_shenaye_shalaghi_3.mp3', 4, 69, null
  from public.movement_type mt, public.morshed m
  where mt.key = '08_shenaye_shalaghi_3' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/10-1-09_shenaye_shalaghi_va_khondan_09_shenaye_shalaghi_va_khondan.mp3', 21, 103, null
  from public.movement_type mt, public.morshed m
  where mt.key = '09_shenaye_shalaghi_va_khondan' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/11-1-10_shomareshe_pich_10_shomareshe_pich.mp3', 50, 102, null
  from public.movement_type mt, public.morshed m
  where mt.key = '10_shomareshe_pich' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/12-1-11_jangali_11_jangali.mp3', 1, 50, null
  from public.movement_type mt, public.morshed m
  where mt.key = '11_jangali' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/13-1-12_paye_chapo_rast_12_paye_chapo_rast.mp3', 1, 66, null
  from public.movement_type mt, public.morshed m
  where mt.key = '12_paye_chapo_rast' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/14-1-13_narmeshhaye_zorkhanei_13_narmeshhaye_zorkhanei.mp3', 3, 176, null
  from public.movement_type mt, public.morshed m
  where mt.key = '13_narmeshhaye_zorkhanei' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/15-1-14_khamgiri_14_khamgiri.mp3', 1, 52, null
  from public.movement_type mt, public.morshed m
  where mt.key = '14_khamgiri' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/16-1-15_shomareshe_gardan_15_shomareshe_gardan.mp3', 50, 79, null
  from public.movement_type mt, public.morshed m
  where mt.key = '15_shomareshe_gardan' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/17-1-16_neshasto_barkhast_16_neshasto_barkhast.mp3', 40, 119, null
  from public.movement_type mt, public.morshed m
  where mt.key = '16_neshasto_barkhast' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/18-1-17_paye_hamrah_ba_takhteh_17_paye_hamrah_ba_takhteh.mp3', 2, 140, null
  from public.movement_type mt, public.morshed m
  where mt.key = '17_paye_hamrah_ba_takhteh' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/1-1-18_mile_aram_18_mile_aram.mp3', 65, 228, null
  from public.movement_type mt, public.morshed m
  where mt.key = '18_mile_aram' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/19-1-19_narmeshe_ba_mil_19_narmeshe_ba_mil.mp3', 1, 84, null
  from public.movement_type mt, public.morshed m
  where mt.key = '19_narmeshe_ba_mil' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/20-1-20_mil_shalaghi_20_mil_shalaghi.mp3', 30, 65, null
  from public.movement_type mt, public.morshed m
  where mt.key = '20_mil_shalaghi' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/21-1-21_paye_aval_21_paye_aval.mp3', 2, 101, null
  from public.movement_type mt, public.morshed m
  where mt.key = '21_paye_aval' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/22-1-22_paye_zarbdari_22_paye_zarbdari.mp3', 1, 20, null
  from public.movement_type mt, public.morshed m
  where mt.key = '22_paye_zarbdari' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/23-1-23_paye_shateri_1_2_3_23_paye_shateri_1_2_3.mp3', 1, 44, null
  from public.movement_type mt, public.morshed m
  where mt.key = '23_paye_shateri_1_2_3' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/24-1-24_jofti_24_jofti.mp3', 1, 10, null
  from public.movement_type mt, public.morshed m
  where mt.key = '24_jofti' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/25-1-25_tabrizi_25_tabrizi.mp3', 2, 102, null
  from public.movement_type mt, public.morshed m
  where mt.key = '25_tabrizi' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/26-1-26_ya_fatah_26_ya_fatah.mp3', 1, 49, null
  from public.movement_type mt, public.morshed m
  where mt.key = '26_ya_fatah' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/27-1-27_se_pa_zadan_27_se_pa_zadan.mp3', 1, 20, null
  from public.movement_type mt, public.morshed m
  where mt.key = '27_se_pa_zadan' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/28-1-28_chamani_28_chamani.mp3', 1, 87, null
  from public.movement_type mt, public.morshed m
  where mt.key = '28_chamani' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/29-1-29_charke_tiz_29_charke_tiz.mp3', 1, 17, null
  from public.movement_type mt, public.morshed m
  where mt.key = '29_charke_tiz' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/30-1-30_tak_fer_30_tak_fer.mp3', 1, 27, null
  from public.movement_type mt, public.morshed m
  where mt.key = '30_tak_fer' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/31-1-31_do_ta_yeki_31_do_ta_yeki.mp3', 1, 43, null
  from public.movement_type mt, public.morshed m
  where mt.key = '31_do_ta_yeki' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/32-1-32_paye_akhar_jangali_32_paye_akhar_jangali.mp3', 2, 96, null
  from public.movement_type mt, public.morshed m
  where mt.key = '32_paye_akhar_jangali' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/33-1-33_paye_shateri_33_paye_shateri.mp3', 1, 68, null
  from public.movement_type mt, public.morshed m
  where mt.key = '33_paye_shateri' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/34-1-34_shateri_tond_34_shateri_tond.mp3', 1, 64, null
  from public.movement_type mt, public.morshed m
  where mt.key = '34_shateri_tond' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/35-1-35_shirin_kari_kabadeh_35_shirin_kari_kabadeh.mp3', 1, 35, null
  from public.movement_type mt, public.morshed m
  where mt.key = '35_shirin_kari_kabadeh' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/36-1-36_shomareshe_kabade_36_shomareshe_kabade.mp3', 117, 228, null
  from public.movement_type mt, public.morshed m
  where mt.key = '36_shomareshe_kabade' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/37-1-37_zarbe_shirin_kari_37_zarbe_shirin_kari.mp3', 1, 45, null
  from public.movement_type mt, public.morshed m
  where mt.key = '37_zarbe_shirin_kari' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/38-1-38_gole_koshti_38_gole_koshti.mp3', 2, 96, null
  from public.movement_type mt, public.morshed m
  where mt.key = '38_gole_koshti' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/39-1-39_dar_heine_koshti_39_dar_heine_koshti.mp3', 1, 37, null
  from public.movement_type mt, public.morshed m
  where mt.key = '39_dar_heine_koshti' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/40-1-40_doa_40_doa.mp3', 1, 43, null
  from public.movement_type mt, public.morshed m
  where mt.key = '40_doa' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;

insert into public.movement_audio_track
    (movement_type_id, morshed_id, audio_url, repetitions_default, duration_seconds, audio_anchor_ms)
  select mt.id, m.id, 'https://pub-d26e099daad243af8e9221f16223fb95.r2.dev/audio/movement_tracks/41-1-41_khoroj_41_khoroj.mp3', 2, 141, null
  from public.movement_type mt, public.morshed m
  where mt.key = '41_khoroj' and m.name = 'Ali Eshaghi'
  on conflict (movement_type_id, morshed_id) do nothing;
