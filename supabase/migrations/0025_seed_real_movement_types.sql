-- Auto-curates the real movement_type catalog from Sirvan's numbered master
-- recording list (41 tracks, "NN Name.mp3") — each file corresponds to one
-- rhythm/category. The number is preserved in both `key` and `display_name`
-- so the catalog sorts in the same order as the source recordings; admin.py's
-- movement-type list is expected to be ordered by `key` for this reason.
--
-- Movement-to-type assignment and any Farsi names are deliberately left for
-- manual curation via admin.py afterward — this migration only seeds the
-- type catalog itself.
--
-- 0024's throwaway 'mile_aram' test type is the same real category as file
-- 18 ("Mile Aram") — renamed in place (same id, so the movement/track rows
-- already pointing at it keep working) rather than left as a duplicate.

update public.movement_type
  set key = '18_mile_aram', display_name = '18 Mile Aram'
  where key = 'mile_aram';

insert into public.movement_type (key, display_name)
  values
    ('01_vorod', '01 Vorod'),
    ('02_salam_bastani', '02 Salam Bastani'),
    ('03_shomaresh_sang', '03 Shomaresh Sang'),
    ('04_shena_sar_navazi', '04 Shena Sar Navazi'),
    ('05_shenaye_shalaghi', '05 Shenaye Shalaghi'),
    ('06_shenaye_shalaghi_1', '06 Shenaye Shalaghi 1'),
    ('07_shenaye_shalaghi_2', '07 Shenaye Shalaghi 2'),
    ('08_shenaye_shalaghi_3', '08 Shenaye Shalaghi 3'),
    ('09_shenaye_shalaghi_va_khondan', '09 Shenaye Shalaghi Va Khondan'),
    ('10_shomareshe_pich', '10 Shomareshe Pich'),
    ('11_jangali', '11 Jangali'),
    ('12_paye_chapo_rast', '12 Paye Chapo Rast'),
    ('13_narmeshhaye_zorkhanei', '13 Narmeshhaye Zorkhanei'),
    ('14_khamgiri', '14 Khamgiri'),
    ('15_shomareshe_gardan', '15 Shomareshe Gardan'),
    ('16_neshasto_barkhast', '16 Neshasto Barkhast'),
    ('17_paye_hamrah_ba_takhteh', '17 Paye Hamrah Ba Takhteh'),
    ('19_narmeshe_ba_mil', '19 Narmeshe Ba Mil'),
    ('20_mil_shalaghi', '20 Mil Shalaghi'),
    ('21_paye_aval', '21 Paye Aval'),
    ('22_paye_zarbdari', '22 Paye Zarbdari'),
    ('23_paye_shateri_1_2_3', '23 Paye Shateri 1 2 3'),
    ('24_jofti', '24 Jofti'),
    ('25_tabrizi', '25 Tabrizi'),
    ('26_ya_fatah', '26 Ya Fatah'),
    ('27_se_pa_zadan', '27 Se Pa Zadan'),
    ('28_chamani', '28 Chamani'),
    ('29_charke_tiz', '29 Charke Tiz'),
    ('30_tak_fer', '30 Tak Fer'),
    ('31_do_ta_yeki', '31 Do Ta Yeki'),
    ('32_paye_akhar_jangali', '32 Paye Akhar Jangali'),
    ('33_paye_shateri', '33 Paye Shateri'),
    ('34_shateri_tond', '34 Shateri Tond'),
    ('35_shirin_kari_kabadeh', '35 Shirin Kari Kabadeh'),
    ('36_shomareshe_kabade', '36 Shomareshe Kabade'),
    ('37_zarbe_shirin_kari', '37 Zarbe Shirin Kari'),
    ('38_gole_koshti', '38 Gole Koshti'),
    ('39_dar_heine_koshti', '39 Dar Heine Koshti'),
    ('40_doa', '40 Doa'),
    ('41_khoroj', '41 Khoroj')
  on conflict (key) do nothing;
