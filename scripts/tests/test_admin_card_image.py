"""Drives admin.py's "Card image" section (Movements tab) with Streamlit's
AppTest against an in-memory fake Supabase client and stubbed ffmpeg/R2 —
no network, no credentials. The card image is the still the app's learning
card shows (movement.media_poster for a video move); changing it must never
touch the move's video.

Run from the repo root (needs the scripts venv for streamlit):
  uv run --project scripts python -m unittest discover -s scripts/tests
"""

import sys
import unittest
from datetime import datetime
from pathlib import Path

from streamlit.testing.v1 import AppTest


def _script():
    # Runs inside AppTest's own script context.
    import sys
    from pathlib import Path

    import pandas as pd
    import streamlit as st

    sys.path.insert(0, str(Path.cwd() / "scripts"))
    import admin

    class _Update:
        def __init__(self, table, payload):
            self.table, self.payload = table, payload

        def eq(self, column, value):
            st.session_state.updates.append(
                (self.table, self.payload, column, value))
            return self

        def execute(self):
            return self

    class _Table:
        def __init__(self, name):
            self.name = name

        def update(self, payload):
            return _Update(self.name, payload)

    class _Client:
        def table(self, name):
            return _Table(name)

    if "updates" not in st.session_state:
        st.session_state.updates = []
        st.session_state.frames = []
    admin.get_client = lambda: _Client()
    admin.bust_cache = lambda: None

    def fake_extract(video_path, out_path, timestamp=1.0):
        st.session_state.frames.append((video_path, timestamp))
        from PIL import Image

        Image.new("RGB", (4, 4)).save(out_path, "JPEG")
        return True

    admin.extract_poster = fake_extract
    admin.upload_asset_to_r2 = (
        lambda local, key, mime: f"https://media.example/{key}")

    row = pd.Series({
        "id": 4,
        "name": "Shena Sar Navazi",
        "media_type": "video",
        "media_src": "https://media.example/video/movements/4-v2.mp4",
        "media_poster": "https://media.example/images/posters/4-v2.jpg",
        "video_id": 12,
    })
    admin._render_movement_card_image_section(4, row)


class CardImageSection(unittest.TestCase):
    def setUp(self):
        self.at = AppTest.from_function(_script, default_timeout=30)
        self.at.run()
        self.assertFalse(self.at.exception, self.at.exception)

    def _click(self, label):
        next(b for b in self.at.button if b.label == label).click()
        self.at.run()
        self.assertFalse(self.at.exception, self.at.exception)

    def test_a_frame_from_the_video_becomes_the_card_image_only(self):
        self.at.number_input[0].set_value(7.5)
        self._click("🎞️ Preview frame")
        self.assertEqual(
            self.at.session_state.frames,
            [("https://media.example/video/movements/4-v2.mp4", 7.5)])

        self._click("✅ Use this frame")

        updates = self.at.session_state.updates
        movement = [u for u in updates if u[0] == "movement"]
        self.assertEqual(len(movement), 1)
        payload, column, value = movement[0][1:]
        self.assertEqual((column, value), ("id", 4))
        self.assertEqual(list(payload), ["media_poster"],
                         "the video and media type stay as they are")
        self.assertRegex(payload["media_poster"],
                         r"/images/posters/4-shena_sar_navazi-card-\d{14}\.jpg$")
        video = [u for u in updates if u[0] == "video"]
        self.assertEqual(video, [("video",
                                  {"poster_url": payload["media_poster"]},
                                  "id", 12)])


class CardImageKey(unittest.TestCase):
    def test_a_new_key_each_time_so_cached_copies_refresh(self):
        sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
        import admin

        key = admin.card_image_key(
            4, "Shena Sar Navazi", ".jpg", datetime(2026, 10, 16, 19, 5, 3))
        self.assertEqual(
            key, "images/posters/4-shena_sar_navazi-card-20261016190503.jpg")


if __name__ == "__main__":
    unittest.main()
