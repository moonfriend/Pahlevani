"""R2 keys for uploaded recordings. A Morshed can have several recordings of
the same movement type (variants), so a key must never overwrite another
recording's file.

Run from the repo root:
  uv run --project scripts python -m unittest discover -s scripts/tests
"""

import unittest

from morshed_admin import audio_track_r2_key


class AudioTrackR2KeyTest(unittest.TestCase):
    def test_holds_type_morshed_and_file_name(self):
        key = audio_track_r2_key("tracks/", 18, 2, "18 02_Mile Aram_avaz.mp3",
                                 unique="ab12cd34")
        self.assertEqual(key, "tracks/18-2-18_02_mile_aram_avaz-ab12cd34.mp3")

    def test_two_variants_of_one_type_get_different_keys(self):
        first = audio_track_r2_key("tracks/", 18, 2, "18 Mile Aram.mp3")
        second = audio_track_r2_key("tracks/", 18, 2, "18 Mile Aram.mp3")
        self.assertNotEqual(first, second,
                            "re-uploading must not replace a file in use")


if __name__ == "__main__":
    unittest.main()
