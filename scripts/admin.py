"""
Pahlevani Admin — data-entry tool for the exercise and session library.

Run (from repo root — sources admin-tier credentials from the vault, see
scripts/run_admin.sh):
    bash scripts/run_admin.sh

Credentials (required — use the service-role key, not the anon key):
  Read from process environment only — SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY,
  R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY. scripts/run_admin.sh
  exports all of these from ~/StudioProjects/pahlevani-admin-creds/<env>.env
  before launching Streamlit — nothing is persisted inside the repo tree.

Storage:
  All new uploads (audio, images, video) go to Cloudflare R2 — see
  R2_ACCOUNT_ID/R2_BUCKET/R2_*_PREFIX below. The legacy Supabase Storage
  buckets ('tracks', 'movement-media') were fully migrated off and deleted
  2026-08-26 — nothing in this tool writes to Supabase Storage any more.
"""

import io
import json
import os
import re
import secrets
import subprocess
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path

import boto3
import pandas as pd
import streamlit as st
from botocore.config import Config as BotoConfig
from mutagen.mp3 import MP3
from supabase import create_client, Client

# ── Config ────────────────────────────────────────────────────────────────────
# Every value below comes from the process environment only — see the module
# docstring. scripts/run_admin.sh is the one place that populates it.

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")


# R2 — demonstration videos. Same account/bucket as the rest of the app's
# media (photos/audio).
#
# Storage layout (new content only — see note below):
#   audio/exercises/<id>-<slug>.<ext>   — exercise audio (NOT migrated yet;
#                                          existing audio stays under the
#                                          legacy Sirvan/ prefix for now)
#   images/movements/<id>-<slug>.<ext>  — movement photos (NOT migrated yet;
#                                          existing photos stay under the
#                                          legacy movement_images/ prefix)
#   images/posters/<id>-<slug>.jpg      — video poster frames (new)
#   video/movements/<id>-<slug>.mp4     — movement demonstration videos (new)
#
# Top-level grouping is by media type (mirrors how cache-control/lifecycle
# rules would realistically ever need to differ — e.g. images vs video —
# and makes the bucket browsable by content kind). Second level is semantic
# role. Filenames are "<movement id>-<slug>" rather than a bare slug so a
# renamed movement never orphans its file, and so two similarly-named
# movements can never collide.
#
# The two ORIGINAL flat prefixes (Sirvan/ for audio, movement_images/ for
# photos) hold 66 files already live in production, referenced by real DB
# rows — deliberately left untouched here. Migrating them to the new layout
# is a separate, one-time, zero-urgency task if ever wanted; this app's
# caching is fully URL-based (DJB2 hash of the full URL), so nothing in the
# Flutter app cares what the path looks like either way.
R2_ACCOUNT_ID = os.environ.get("R2_ACCOUNT_ID", "")
R2_BUCKET = os.environ.get("R2_BUCKET", "") or "morshed-sounds"
# Note: R2_ACCESS_KEY_ID/R2_SECRET_ACCESS_KEY are the S3-compatible API key
# pair from R2 > Manage API Tokens — NOT a general Cloudflare account API
# token (those are single bearer-token values and cannot be used for the
# S3-compatible signature boto3 computes).
R2_ACCESS_KEY_ID = os.environ.get("R2_ACCESS_KEY_ID", "")
R2_SECRET_ACCESS_KEY = os.environ.get("R2_SECRET_ACCESS_KEY", "")
R2_ENDPOINT = f"https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
R2_PUBLIC_BASE = os.environ.get(
    "R2_PUBLIC_BASE", "https://pub-d26e099daad243af8e9221f16223fb95.r2.dev"
)
R2_VIDEO_PREFIX = "video/movements/"
R2_VIDEO_POSTER_PREFIX = "images/posters/"
R2_IMAGE_MOVEMENT_PREFIX = "images/movements/"
R2_AUDIO_EXERCISE_PREFIX = "audio/exercises/"

# ── DB / Storage client ───────────────────────────────────────────────────────

@st.cache_resource
def get_client() -> Client:
    if not SUPABASE_URL or not SUPABASE_KEY:
        st.error(
            "Supabase credentials not configured. Run this via "
            "`bash scripts/run_admin.sh`, which exports SUPABASE_URL and "
            "SUPABASE_SERVICE_ROLE_KEY from the admin creds vault."
        )
        st.stop()
    return create_client(SUPABASE_URL, SUPABASE_KEY)

@st.cache_resource
def get_r2_client():
    if not R2_ACCOUNT_ID or not R2_ACCESS_KEY_ID or not R2_SECRET_ACCESS_KEY:
        st.error(
            "R2 credentials not configured. Run this via "
            "`bash scripts/run_admin.sh`, which exports R2_ACCOUNT_ID, "
            "R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY from the admin creds "
            "vault (Cloudflare Dashboard → R2 → Manage API Tokens → Object "
            "Read & Write, scoped to the 'morshed-sounds' bucket)."
        )
        st.stop()
    return boto3.client(
        "s3",
        endpoint_url=R2_ENDPOINT,
        aws_access_key_id=R2_ACCESS_KEY_ID,
        aws_secret_access_key=R2_SECRET_ACCESS_KEY,
        config=BotoConfig(signature_version="s3v4"),
        region_name="auto",
    )

# ── Loaders ───────────────────────────────────────────────────────────────────

@st.cache_data(ttl=60)
def load_exercises() -> pd.DataFrame:
    rows = get_client().table("exercise").select("*, movement(name, title_fa)").order("id").execute().data
    if not rows:
        return pd.DataFrame()
    df = pd.DataFrame(rows)
    if "movement" in df.columns:
        df["name"]     = df["movement"].apply(lambda m: m.get("name")     if isinstance(m, dict) else None)
        df["title_fa"] = df["movement"].apply(lambda m: m.get("title_fa") if isinstance(m, dict) else None)
        df = df.drop(columns=["movement"])
    return df

@st.cache_data(ttl=60)
def load_sessions() -> pd.DataFrame:
    rows = (
        get_client().table("training_session")
        .select("*").order("id").execute().data
    )
    return pd.DataFrame(rows) if rows else pd.DataFrame()

@st.cache_data(ttl=60)
def load_items() -> pd.DataFrame:
    rows = (
        get_client().table("training_session_item")
        .select("*").order("training_session_id,position").execute().data
    )
    return pd.DataFrame(rows) if rows else pd.DataFrame()

@st.cache_data(ttl=60)
def load_release_gate() -> dict | None:
    rows = get_client().table("app_release_gate").select("*").eq("id", 1).execute().data
    return rows[0] if rows else None

@st.cache_data(ttl=30)
def load_profiles() -> list[dict]:
    """All signed-up users. Service-role key bypasses RLS, so this sees
    every row regardless of the profiles_select_own/profiles_select_trainer_all
    policies (supabase/migrations/0013_profiles_and_consent.sql)."""
    return get_client().table("profiles").select("*").order("created_at").execute().data

@st.cache_data(ttl=30)
def load_invite_codes() -> list[dict]:
    """Trainer-issued signup codes (supabase/migrations/0016_invite_code_signup.sql).
    Only the sha256 hash is ever stored — the plaintext is shown once, at
    creation time, and never persisted anywhere."""
    return get_client().table("invite_codes").select("*").order("created_at", desc=True).execute().data

@st.cache_data(ttl=60)
def load_movements() -> pd.DataFrame:
    try:
        rows = get_client().table("movement").select("*").order("id").execute().data
        return pd.DataFrame(rows) if rows else pd.DataFrame()
    except Exception as e:
        st.warning(f"Could not load movement table ({e}). Run the DB migration first.")
        return pd.DataFrame()

@st.cache_data(ttl=30)
def load_movement_info() -> dict[int, dict]:
    """Per-move info-page content, keyed by movement_id. Empty if 0005 not applied."""
    try:
        rows = get_client().table("movement_info").select("*").execute().data
        return {int(r["movement_id"]): r for r in (rows or [])}
    except Exception:
        # movement_info table may not exist yet (pre-0005) — treat as no content.
        return {}


def bust_cache():
    load_exercises.clear()
    load_sessions.clear()
    load_items.clear()
    load_movements.clear()
    load_release_gate.clear()

# ── Video processing (ffmpeg/ffprobe) ──────────────────────────────────────────
# Source clips are typically 4K/huge-bitrate camera dumps, unsuitable for
# mobile delivery as-is. The crop needs eyeballing per clip — a wide plank
# pose needs more width than a standing squat — hence the preview step below
# rather than baking in one fixed crop ratio.

def probe_video(path: str) -> dict:
    """Return {width, height, duration} via ffprobe, or {} on failure."""
    cmd = ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", path]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode != 0:
            return {}
        data = json.loads(result.stdout)
        video_stream = next((s for s in data.get("streams", []) if s.get("codec_type") == "video"), None)
        if not video_stream:
            return {}
        return {
            "width": int(video_stream.get("width", 0)),
            "height": int(video_stream.get("height", 0)),
            "duration": float(data.get("format", {}).get("duration", 0)),
        }
    except (subprocess.TimeoutExpired, KeyError, json.JSONDecodeError, ValueError):
        return {}

def format_mmss(seconds: float) -> str:
    """1.4 -> '00:01.400' — for reading an anchor timestamp precisely, since
    a plain seconds number is hard to eyeball against a video's own scrubber."""
    m, s = divmod(max(seconds, 0.0), 60)
    return f"{int(m):02d}:{s:06.3f}"

def extract_frame_at(src_path_or_url: str, timestamp: float) -> bytes | None:
    """Extract one full (uncropped) frame as JPEG bytes — for confirming an
    anchor's exact frame on an already-processed video (local path or R2
    URL; ffmpeg reads both natively). No crop, unlike extract_preview_frame,
    which is for eyeballing framing on a raw source before encoding."""
    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
        out_path = tmp.name
    cmd = [
        "ffmpeg", "-y", "-ss", str(timestamp), "-i", src_path_or_url,
        "-frames:v", "1", "-update", "1", "-q:v", "3",
        out_path,
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, timeout=30)
        if result.returncode != 0:
            return None
        return Path(out_path).read_bytes()
    except subprocess.TimeoutExpired:
        return None
    finally:
        Path(out_path).unlink(missing_ok=True)

def extract_audio_snippet_at(
    src_url: str, timestamp: float, pad: float = 0.6, duration: float = 1.5
) -> bytes | None:
    """Extract a short MP3 snippet centered a bit before [timestamp] — for
    hearing exactly what's at a candidate audio anchor point. A browser
    audio player's scrubber (unlike video's) has no frame-level analogue to
    confirm against visually, so this is the audio equivalent of
    extract_frame_at: play back just the moment, not the whole track."""
    start = max(timestamp - pad, 0.0)
    with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
        out_path = tmp.name
    cmd = [
        "ffmpeg", "-y", "-ss", str(start), "-i", src_url, "-t", str(duration),
        "-c:a", "libmp3lame", "-q:a", "4",
        out_path,
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, timeout=30)
        if result.returncode != 0:
            return None
        return Path(out_path).read_bytes()
    except subprocess.TimeoutExpired:
        return None
    finally:
        Path(out_path).unlink(missing_ok=True)

def extract_preview_frame(src_path: str, crop_w: int, crop_h: int, crop_x: int, crop_y: int, timestamp: float) -> bytes | None:
    """Extract one cropped preview frame as JPEG bytes, for eyeballing before a full encode."""
    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
        out_path = tmp.name
    cmd = [
        "ffmpeg", "-y", "-ss", str(timestamp), "-i", src_path,
        "-frames:v", "1", "-update", "1",
        "-vf", f"crop={crop_w}:{crop_h}:{crop_x}:{crop_y}",
        out_path,
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, timeout=30)
        if result.returncode != 0:
            return None
        return Path(out_path).read_bytes()
    except subprocess.TimeoutExpired:
        return None
    finally:
        Path(out_path).unlink(missing_ok=True)

def encode_video(
    src_path: str, out_path: str, crop_w: int, crop_h: int, crop_x: int, crop_y: int,
    target_height: int, trim_start: float, trim_duration: float | None, strip_audio: bool,
) -> bool:
    scale_w = max(round((crop_w / crop_h) * target_height / 2) * 2, 2)  # even width, h264-friendly
    vf = f"crop={crop_w}:{crop_h}:{crop_x}:{crop_y},scale={scale_w}:{target_height}"
    cmd = ["ffmpeg", "-y"]
    if trim_start:
        cmd += ["-ss", str(trim_start)]
    cmd += ["-i", src_path]
    if trim_duration:
        cmd += ["-t", str(trim_duration)]
    cmd += [
        "-vf", vf,
        "-c:v", "libx264", "-crf", "24", "-preset", "medium",
        "-maxrate", "2M", "-bufsize", "4M",
        "-movflags", "+faststart",
    ]
    if strip_audio:
        cmd += ["-an"]
    cmd += [out_path]
    result = subprocess.run(cmd, capture_output=True, timeout=600)
    return result.returncode == 0

def extract_poster(video_path: str, out_path: str, timestamp: float = 1.0) -> bool:
    cmd = ["ffmpeg", "-y", "-ss", str(timestamp), "-i", video_path,
           "-frames:v", "1", "-update", "1", "-q:v", "3", out_path]
    result = subprocess.run(cmd, capture_output=True, timeout=30)
    return result.returncode == 0

def upload_asset_to_r2(local_path: str, r2_key: str, content_type: str) -> str:
    """Upload a file already on disk (video/poster output from ffmpeg)."""
    get_r2_client().upload_file(
        local_path, R2_BUCKET, r2_key, ExtraArgs={"ContentType": content_type}
    )
    return f"{R2_PUBLIC_BASE}/{r2_key}"

def upload_bytes_to_r2(data: bytes, r2_key: str, content_type: str) -> str:
    """Upload in-memory bytes straight from a Streamlit file_uploader — no
    temp file needed (unlike upload_asset_to_r2, which is for ffmpeg output
    that's already on disk)."""
    get_r2_client().put_object(
        Bucket=R2_BUCKET, Key=r2_key, Body=data, ContentType=content_type
    )
    return f"{R2_PUBLIC_BASE}/{r2_key}"

# ── Helpers ───────────────────────────────────────────────────────────────────

def duration_from_bytes(data: bytes) -> int | None:
    try:
        audio = MP3(io.BytesIO(data))
        return round(audio.info.length)
    except Exception:
        return None

def slugify(text: str) -> str:
    """Lower-case, spaces to underscores, strip non-alphanumeric."""
    return re.sub(r"[^a-z0-9_]", "", text.lower().replace(" ", "_"))

def guess_movement_name(filename: str) -> str:
    """Strip leading track numbers and extension from a filename."""
    stem = Path(filename).stem
    stem = re.sub(r"^[\d\s_\-]+", "", stem)   # strip leading numbers
    stem = stem.replace("_", " ").strip()
    return stem or filename

def find_or_create_movement(name: str, known: dict[str, int]) -> tuple[int, bool]:
    """Case-insensitive-exact match against `known` (name.lower() -> id); inserts
    a new bare `movement` row (name only) if there's no match. `known` is
    mutated in place so later rows in the same batch reuse a movement just
    created by an earlier row. Returns (movement_id, created)."""
    key = name.strip().lower()
    if key in known:
        return known[key], False
    row = get_client().table("movement").insert({"name": name.strip()}).execute().data[0]
    known[key] = row["id"]
    return row["id"], True

def exercise_label(row: pd.Series) -> str:
    dur   = f"{int(row['duration_seconds'])}s" if pd.notna(row.get("duration_seconds")) else "—"
    reps  = int(row["repetitions"]) if pd.notna(row.get("repetitions")) else "?"
    auth  = row.get("author") or "unknown"
    return f"{row['name']}  ·  {auth}  ·  {dur}  ·  {reps} reps"

def recording_label(row: pd.Series) -> str:
    """Label for a specific exercise recording (author + duration + reps, no movement name)."""
    dur  = f"{int(row['duration_seconds'])}s" if pd.notna(row.get("duration_seconds")) else "—"
    reps = int(row["repetitions"]) if pd.notna(row.get("repetitions")) else "?"
    auth = row.get("author") or "unknown"
    return f"{auth}  ·  {dur}  ·  {reps} reps"

# ── Savers ────────────────────────────────────────────────────────────────────

def _changed_rows(
    original: pd.DataFrame, edited: pd.DataFrame, editable_cols: list[str]
) -> list[dict]:
    patches = []
    for _, erow in edited.iterrows():
        orow = original[original["id"] == erow["id"]]
        if orow.empty:
            continue
        patch = {}
        for col in editable_cols:
            nv = erow[col] if pd.notna(erow[col]) and str(erow[col]).strip() != "" else None
            ov = orow.iloc[0][col] if col in orow.columns else None
            ov = ov if pd.notna(ov) and str(ov).strip() != "" else None  # type: ignore[assignment]
            if nv != ov:
                patch[col] = nv
        if patch:
            patches.append({"id": int(erow["id"]), **patch})
    return patches

def save_rows(table: str, patches: list[dict]) -> int:
    db = get_client()
    for p in patches:
        row_id = p.pop("id")
        db.table(table).update(p).eq("id", row_id).execute()
    return len(patches)

# ─────────────────────────────────────────────────────────────────────────────
# Tab: Exercises
# ─────────────────────────────────────────────────────────────────────────────

def tab_exercises():
    st.header("Exercises")
    st.caption("Edit Farsi titles. Locked columns (grey) are read-only.")

    if st.button("↺ Reload", key="rel_ex"):
        bust_cache()

    df = load_exercises()
    if df.empty:
        st.warning("No exercises found.")
        return

    SHOW = ["id", "name", "author", "type", "repetitions", "duration_seconds", "url", "title_fa"]
    show = [c for c in SHOW if c in df.columns]

    cfg = {
        "id":               st.column_config.NumberColumn("ID",           disabled=True, width=55),
        "name":             st.column_config.TextColumn("Name",           disabled=True, width=190),
        "author":           st.column_config.TextColumn("Author",         disabled=True, width=130),
        "type":             st.column_config.TextColumn("Type",           disabled=True, width=100),
        "repetitions":      st.column_config.NumberColumn("Def. reps",    disabled=True, width=75),
        "duration_seconds": st.column_config.NumberColumn("Duration (s)", disabled=True, width=90),
        "url":              st.column_config.LinkColumn("Audio URL",      disabled=True, width=200),
        "title_fa":         st.column_config.TextColumn("Farsi title ✏️", width=190),
    }

    edited = st.data_editor(
        df[show].copy(), column_config=cfg,
        use_container_width=True, hide_index=True,
        num_rows="fixed", key="ex_ed",
    )

    c1, c2 = st.columns([1, 7])
    with c1:
        if st.button("💾 Save", type="primary", key="sv_ex"):
            # title_fa now lives on the movement table — map each changed exercise
            # row to its movement_id and update there instead of the exercise table.
            ex_to_mov = {
                int(r["id"]): int(r["movement_id"])
                for _, r in df.iterrows()
                if pd.notna(r.get("movement_id"))
            }
            mov_patches = []
            for _, erow in edited.iterrows():
                ex_id   = int(erow["id"])
                orig    = df[df["id"] == ex_id]
                if orig.empty:
                    continue
                orig_fa = orig.iloc[0].get("title_fa")
                orig_fa = orig_fa if pd.notna(orig_fa) and str(orig_fa).strip() else None
                new_fa  = erow.get("title_fa")
                new_fa  = new_fa  if pd.notna(new_fa)  and str(new_fa).strip()  else None
                if new_fa != orig_fa:
                    mov_id = ex_to_mov.get(ex_id)
                    if mov_id:
                        mov_patches.append({"id": mov_id, "title_fa": new_fa})
            if mov_patches:
                with st.spinner(f"Saving {len(mov_patches)} row(s)…"):
                    save_rows("movement", mov_patches)
                c2.success(f"Updated {len(mov_patches)} Farsi title(s).")
                bust_cache()
            else:
                c2.info("No changes.")

    filled = df["title_fa"].notna().sum() if "title_fa" in df.columns else 0
    st.caption(f"Farsi titles: **{filled} / {len(df)}**")
    st.progress(filled / len(df) if len(df) else 0)

    st.divider()
    st.subheader('Audio anchor — "sarzarb"/main beat sync')
    st.caption(
        "Sets the beat moment (e.g. the bottom of a push-up) used to sync "
        "this exercise's audio to its movement's video demonstration, if one "
        "exists. The full clip below is only for finding the rough area — "
        "its scrubber isn't precise. Nudge the timestamp and use \"Preview "
        "snippet\" to hear just that moment until it's exactly on the beat."
    )
    ex_opts = {f"{exercise_label(r)}  (id {r['id']})": r["id"] for _, r in df.iterrows()}
    if ex_opts:
        chosen_ex = st.selectbox("Exercise", list(ex_opts.keys()), key="anchor_ex_sel")
        ex_id = ex_opts[chosen_ex]
        ex_row = df[df["id"] == ex_id].iloc[0]
        if ex_row.get("url"):
            st.audio(ex_row["url"])
        current_ms = ex_row.get("audio_anchor_ms")
        current_s = float(current_ms) / 1000 if pd.notna(current_ms) else 0.0
        audio_col1, audio_col2 = st.columns([2, 1])
        anchor_s = audio_col1.number_input(
            "Audio anchor (s)", min_value=0.0, value=current_s, step=0.05,
            format="%.3f", key="audio_anchor_s",
        )
        audio_col2.markdown(f"**{format_mmss(anchor_s)}**")
        if st.button("🔊 Preview snippet", key="audio_anchor_preview_btn"):
            snippet = extract_audio_snippet_at(ex_row["url"], anchor_s)
            if snippet:
                st.audio(snippet, format="audio/mp3")
                st.caption(
                    f"~0.6s of lead-in, so the anchor moment lands shortly "
                    f"after the snippet starts (not at 0:00)."
                )
            else:
                st.error("Snippet extraction failed.")
        if st.button("💾 Save anchor", key="sv_audio_anchor"):
            save_rows("exercise", [{"id": int(ex_id), "audio_anchor_ms": round(anchor_s * 1000)}])
            st.success("Anchor saved.")
            bust_cache()

# ─────────────────────────────────────────────────────────────────────────────
# Tab: Sessions
# ─────────────────────────────────────────────────────────────────────────────

def tab_sessions():
    st.header("Training Sessions")
    st.caption("Add Farsi titles shown on the card banners.")

    if st.button("↺ Reload", key="rel_sess"):
        bust_cache()

    df = load_sessions()
    if df.empty:
        st.warning("No sessions found.")
        return

    SHOW = ["id", "title", "difficulty", "description", "title_fa"]
    show = [c for c in SHOW if c in df.columns]

    cfg = {
        "id":          st.column_config.NumberColumn("ID",           disabled=True, width=60),
        "title":       st.column_config.TextColumn("Title",          disabled=True, width=220),
        "difficulty":  st.column_config.NumberColumn("Difficulty",   disabled=True, width=80),
        "description": st.column_config.TextColumn("Description",    disabled=True, width=300),
        "title_fa":    st.column_config.TextColumn("Farsi title ✏️", width=200),
    }

    edited = st.data_editor(
        df[show].copy(), column_config=cfg,
        use_container_width=True, hide_index=True,
        num_rows="fixed", key="sess_ed",
    )

    c1, c2 = st.columns([1, 7])
    with c1:
        if st.button("💾 Save", type="primary", key="sv_sess"):
            patches = _changed_rows(df, edited, ["title_fa"])
            if patches:
                with st.spinner(f"Saving {len(patches)} row(s)…"):
                    save_rows("training_session", patches)
                c2.success(f"Updated {len(patches)} session(s).")
                bust_cache()
            else:
                c2.info("No changes.")

    filled = df["title_fa"].notna().sum() if "title_fa" in df.columns else 0
    st.caption(f"Farsi titles: **{filled} / {len(df)}**")
    st.progress(filled / len(df) if len(df) else 0)

# ─────────────────────────────────────────────────────────────────────────────
# Tab: Batch Import
# ─────────────────────────────────────────────────────────────────────────────

def tab_batch_import():
    st.header("Batch Import — Audio Tracks")
    st.caption(
        "Upload multiple MP3 files. Duration is auto-detected. "
        "Edit movement names and reps in the table before inserting. "
        "Each row's movement name is matched case-insensitively against "
        "existing movements (reused if found) or created fresh — check the "
        "**Movement** column below before inserting."
    )

    # ── Batch settings ────────────────────────────────────────────────────────
    c1, c2 = st.columns([2, 1])
    with c1:
        batch_author = st.text_input(
            "Morshed / Author (for whole batch)",
            placeholder="e.g. Morshed Karimi",
        )
    with c2:
        batch_reps = st.number_input("Default reps (batch)", min_value=1, max_value=999, value=1)

    # ── File uploader ─────────────────────────────────────────────────────────
    uploads = st.file_uploader(
        "Drop MP3 files here",
        type=["mp3"],
        accept_multiple_files=True,
        key="batch_uploader",
    )

    if not uploads:
        st.caption("Upload files above to continue.")
        return

    # ── Build preview dataframe ───────────────────────────────────────────────
    # Keep file bytes keyed by filename so we can upload later
    file_map: dict[str, bytes] = {f.name: f.getvalue() for f in uploads}

    if "batch_preview" not in st.session_state or set(
        st.session_state.batch_preview["filename"]
    ) != set(file_map.keys()):
        rows = []
        for fname, data in file_map.items():
            dur = duration_from_bytes(data)
            rows.append(
                {
                    "filename":         fname,
                    "movement_name":    guess_movement_name(fname),
                    "author":           batch_author,
                    "default_reps":     batch_reps,
                    "duration_seconds": dur,
                }
            )
        st.session_state.batch_preview = pd.DataFrame(rows)

    preview_df = st.session_state.batch_preview.copy()

    # ── Existing-movement lookup, for the preview column below ──────────────────
    existing_names = {
        str(n).strip().lower()
        for n in load_movements().get("name", pd.Series(dtype=str)).dropna()
    }
    preview_df["movement"] = preview_df["movement_name"].apply(
        lambda n: "existing" if str(n).strip().lower() in existing_names else "new"
    )

    # ── Editable preview ──────────────────────────────────────────────────────
    st.subheader("Preview — edit before inserting")

    cfg = {
        "filename":         st.column_config.TextColumn("File",           disabled=True, width=200),
        "movement_name":    st.column_config.TextColumn("Movement name ✏️", width=200),
        "movement":         st.column_config.TextColumn("Movement",       disabled=True, width=90),
        "author":           st.column_config.TextColumn("Author ✏️",       width=150),
        "default_reps":     st.column_config.NumberColumn("Default reps ✏️", min_value=1, max_value=999, width=100),
        "duration_seconds": st.column_config.NumberColumn("Duration (s)",  disabled=True, width=100),
    }

    edited = st.data_editor(
        preview_df, column_config=cfg,
        use_container_width=True, hide_index=True,
        num_rows="fixed", key="batch_ed",
    )

    # Check for issues
    missing_author   = edited["author"].isna() | (edited["author"] == "")
    missing_movement = edited["movement_name"].isna() | (edited["movement_name"] == "")
    if missing_author.any() or missing_movement.any():
        st.warning("⚠️ Some rows are missing Author or Movement name — fill them in before inserting.")

    # ── Upload & Insert ───────────────────────────────────────────────────────
    if st.button("🚀 Upload to R2 + Insert exercises", type="primary", key="do_import"):
        db = get_client()
        progress = st.progress(0)
        status   = st.empty()
        errors   = []
        known_movements = {
            str(n).strip().lower(): int(mid)
            for mid, n in load_movements().set_index("id")["name"].items()
        }
        # exercise.id has no sequence — compute next id manually, same
        # workaround already used for training_session in tab_session_builder.
        max_row = db.table("exercise").select("id").order("id", desc=True).limit(1).execute()
        next_exercise_id = (max_row.data[0]["id"] + 1) if max_row.data else 1

        for i, (_, row) in enumerate(edited.iterrows()):
            fname = row["filename"]
            data  = file_map.get(fname, b"")
            status.text(f"Importing {fname}…")

            try:
                movement_id, _ = find_or_create_movement(row["movement_name"], known_movements)

                # Insert the exercise row first (url set after upload) so the
                # R2 key can be ID-prefixed the same way video/photo assets
                # are — immune to a later rename, never collides with a
                # sibling recording of the same movement.
                payload = {
                    "id":          next_exercise_id,
                    "movement_id": movement_id,
                    "author":      row["author"] or None,
                    "repetitions": int(row["default_reps"]),
                }
                next_exercise_id += 1
                if pd.notna(row["duration_seconds"]):
                    payload["duration_seconds"] = int(row["duration_seconds"])
                exercise = db.table("exercise").insert(payload).execute().data[0]

                slug = slugify(row["movement_name"] or f"exercise-{exercise['id']}")
                r2_key = f"{R2_AUDIO_EXERCISE_PREFIX}{exercise['id']}-{slug}.mp3"
                url = upload_bytes_to_r2(data, r2_key, "audio/mpeg")
                db.table("exercise").update({"url": url}).eq("id", exercise["id"]).execute()

            except Exception as e:
                errors.append(f"{fname}: {e}")

            progress.progress((i + 1) / len(edited))

        status.empty()
        if errors:
            st.error("Some files failed:\n" + "\n".join(errors))
        else:
            st.success(f"✅ Imported {len(edited)} exercise(s).")
            bust_cache()
            del st.session_state["batch_preview"]

# ─────────────────────────────────────────────────────────────────────────────
# Tab: Session Builder
# ─────────────────────────────────────────────────────────────────────────────

_SB_ITEMS         = "sb_items"        # list[{exercise_id, reps_to_do, uid}]
_SB_META          = "sb_meta"         # {title, title_fa, description, difficulty}
_SB_MODE          = "sb_mode"         # "new" | "edit"
_SB_SID           = "sb_sid"          # session id being edited
_SB_PENDING_OP    = "sb_pending_op"   # deferred list op applied before next render
_SB_PENDING_RESET = "sb_pending_reset"  # deferred metadata reset applied before text_inputs

def _sb_reset():
    # Directly set widget state so the fields visibly clear on the next render.
    st.session_state["sb_title"]   = ""
    st.session_state["sb_titlefa"] = ""
    st.session_state["sb_desc"]    = ""
    st.session_state["sb_diff"]    = 2
    _clear_rep_keys()
    st.session_state[_SB_ITEMS] = []
    st.session_state[_SB_META]  = {"title": "", "title_fa": "", "description": "", "difficulty": 2}
    st.session_state[_SB_SID]   = None

def _clear_rep_keys():
    for key in list(st.session_state.keys()):
        if key.startswith("reps_"):
            del st.session_state[key]

def tab_session_builder():
    st.header("Session Builder")
    st.caption("Compose a training session by choosing audio tracks for each exercise.")

    exercises = load_exercises()
    if exercises.empty:
        st.warning("No exercises in the database yet.")
        return

    # ── Mode selector ─────────────────────────────────────────────────────────
    mode = st.radio("", ["Create new session", "Edit existing session"], horizontal=True, key="sb_mode_radio")

    sessions = load_sessions()

    if mode == "Edit existing session":
        if sessions.empty:
            st.warning("No sessions yet.")
            return
        opts = {f"{r['title']}  (id {sid})": sid for sid, r in sessions.set_index("id").iterrows()}
        chosen = st.selectbox("Select session to edit", list(opts.keys()), key="sb_sess_select")
        sid = opts[chosen]

        if st.session_state.get(_SB_SID) != sid:
            _clear_rep_keys()
            s_row = sessions[sessions["id"] == sid].iloc[0]
            items_df = load_items()
            session_items = items_df[items_df["training_session_id"] == sid].sort_values("position")
            def _str(val): return "" if (val is None or (isinstance(val, float) and pd.isna(val))) else str(val)
            _title   = _str(s_row.get("title"))
            _titlefa = _str(s_row.get("title_fa"))
            _desc    = _str(s_row.get("description"))
            _diff    = int(s_row.get("difficulty") or 2)
            # Directly set widget state BEFORE the widgets render so the fields
            # reflect the newly selected session without needing an extra rerun.
            st.session_state["sb_title"]   = _title
            st.session_state["sb_titlefa"] = _titlefa
            st.session_state["sb_desc"]    = _desc
            st.session_state["sb_diff"]    = _diff
            st.session_state[_SB_META] = {
                "title": _title, "title_fa": _titlefa,
                "description": _desc, "difficulty": _diff,
            }
            st.session_state[_SB_ITEMS] = [
                {"exercise_id": int(r["exercise_id"]), "reps_to_do": int(r["reps_to_do"]), "uid": str(i)}
                for i, (_, r) in enumerate(session_items.iterrows())
            ]
            st.session_state[_SB_SID] = sid
    else:
        if st.session_state.get(_SB_SID) is not None:
            _sb_reset()
        if _SB_META not in st.session_state:
            _sb_reset()

    # Apply pending reset (triggered by save) before metadata widgets render.
    if st.session_state.pop(_SB_PENDING_RESET, False):
        _sb_reset()

    # ── Session metadata ──────────────────────────────────────────────────────
    meta = st.session_state.get(_SB_META, {})
    st.subheader("Session details")
    c1, c2 = st.columns(2)
    with c1:
        title    = st.text_input("Title",       value=meta.get("title", ""),    key="sb_title")
        title_fa = st.text_input("Farsi title", value=meta.get("title_fa", ""), key="sb_titlefa",
                                 help="Displayed on the card banner in the app")
    with c2:
        desc       = st.text_area("Description", value=meta.get("description", ""), key="sb_desc", height=100)
        difficulty = st.slider("Difficulty", 1, 5, value=meta.get("difficulty", 2), key="sb_diff")

    st.session_state[_SB_META] = {
        "title": title, "title_fa": title_fa,
        "description": desc, "difficulty": difficulty,
    }

    # ── Exercise list ─────────────────────────────────────────────────────────
    st.subheader("Exercises")
    items: list[dict] = st.session_state.get(_SB_ITEMS, [])

    # Namespace widget keys by session id so switching sessions uses fresh keys
    # (browser-side widget state is keyed by widget key, not session state).
    _kns = st.session_state.get(_SB_SID, "new")

    # Apply any pending list operation BEFORE widgets are instantiated.
    # (Streamlit forbids modifying widget-keyed session state after instantiation,
    # so we defer move/remove ops to the top of the next render pass.)
    # Reps widgets use uid-based keys (not position-based), so keys travel with
    # items on move — no session-state key manipulation needed.
    pending = st.session_state.pop(_SB_PENDING_OP, None)
    if pending:
        op = pending["op"]
        if op == "move":
            a, b = pending["a"], pending["b"]
            items[a], items[b] = items[b], items[a]
        elif op == "remove":
            items.pop(pending["i"])
        st.session_state[_SB_ITEMS] = items

    # Build a lookup for display
    ex_by_id: dict[int, pd.Series] = {
        int(r["id"]): r for _, r in exercises.iterrows()
    }

    # Ensure every item has a uid so widget keys are stable across position changes.
    for idx, it in enumerate(items):
        if "uid" not in it:
            it["uid"] = f"legacy_{idx}"

    # Show current list
    for i, item in enumerate(items):
        ex = ex_by_id.get(item["exercise_id"])
        label = exercise_label(ex) if ex is not None else f"exercise {item['exercise_id']}"

        c_name, c_reps, c_up, c_dn, c_rm = st.columns([5, 1.5, 0.5, 0.5, 0.5])
        c_name.markdown(f"**{i+1}.** {label}")
        new_reps = c_reps.number_input(
            "Reps", min_value=1, max_value=999,
            value=item["reps_to_do"],
            key=f"reps_{_kns}_{item['uid']}",
            label_visibility="collapsed",
        )
        items[i]["reps_to_do"] = new_reps

        if c_up.button("↑", key=f"up_{_kns}_{i}", disabled=i == 0):
            st.session_state[_SB_PENDING_OP] = {"op": "move", "a": i, "b": i - 1}
            st.rerun()
        if c_dn.button("↓", key=f"dn_{_kns}_{i}", disabled=i == len(items) - 1):
            st.session_state[_SB_PENDING_OP] = {"op": "move", "a": i, "b": i + 1}
            st.rerun()
        if c_rm.button("✕", key=f"rm_{_kns}_{i}"):
            st.session_state[_SB_PENDING_OP] = {"op": "remove", "i": i}
            st.rerun()

    st.session_state[_SB_ITEMS] = items

    # ── Add exercise (movement → recording) ───────────────────────────────────
    st.divider()
    st.markdown("**Add exercise**")

    movements = load_movements()
    if movements.empty:
        st.info("No movements found — run the DB migration first.")
    else:
        # Only show movements that actually have exercises in the DB
        mov_ids_with_ex = set(exercises["movement_id"].dropna().astype(int))
        available_movs = (
            movements[movements["id"].isin(mov_ids_with_ex)]
            .sort_values("name")
        )
        mov_opts = {
            str(r.get("name") or f"id {mid}"): mid
            for mid, r in available_movs.set_index("id").iterrows()
        }

        chosen_mov_label = st.selectbox(
            "Movement", list(mov_opts.keys()), key="sb_mov_select"
        )
        chosen_mov_id = mov_opts[chosen_mov_label]

        # Filter exercises to this movement
        mov_exercises = exercises[exercises["movement_id"] == chosen_mov_id]

        if mov_exercises.empty:
            st.warning("No recordings for this movement.")
        else:
            c_rec, c_rep, c_add = st.columns([5, 1.5, 1])
            rec_opts = {
                recording_label(r): int(r["id"])
                for _, r in mov_exercises.iterrows()
            }
            chosen_rec_label = c_rec.selectbox(
                "Recording", list(rec_opts.keys()),
                key="sb_rec_select", label_visibility="collapsed",
            )
            chosen_id = rec_opts[chosen_rec_label]
            chosen_ex = ex_by_id.get(chosen_id)
            chosen_def = int(chosen_ex["repetitions"]) if chosen_ex is not None and pd.notna(chosen_ex.get("repetitions")) else 1

            add_reps = c_rep.number_input(
                "Reps", min_value=1, max_value=999,
                value=chosen_def, key=f"sb_add_reps_{chosen_id}",
                label_visibility="collapsed",
            )
            if c_add.button("＋ Add", key="sb_add_btn"):
                st.session_state[_SB_ITEMS].append({"exercise_id": chosen_id, "reps_to_do": add_reps, "uid": uuid.uuid4().hex[:8]})
                st.rerun()

    # ── Duration estimate ─────────────────────────────────────────────────────
    if items:
        total = 0
        all_known = True
        for item in items:
            ex = ex_by_id.get(item["exercise_id"])
            dur     = ex.get("duration_seconds") if ex is not None else None
            def_rep = int(ex["repetitions"]) if ex is not None and pd.notna(ex.get("repetitions")) else 1
            if pd.notna(dur) and dur and def_rep:
                total += round(float(dur) / def_rep * item["reps_to_do"])
            else:
                all_known = False
        label = f"{total // 60}m {total % 60}s" if all_known else f"~{total // 60}m (some durations unknown)"
        st.metric("Estimated session length", label)

    # ── Save ──────────────────────────────────────────────────────────────────
    st.divider()
    can_save = bool(title.strip()) and len(items) > 0
    if not can_save:
        st.caption("⚠️ Add a title and at least one exercise to save.")

    if st.button("💾 Save session", type="primary", disabled=not can_save, key="sb_save"):
        db = get_client()
        with st.spinner("Saving…"):
            meta_payload = {
                "title":       title.strip(),
                "title_fa":    title_fa.strip() or None,
                "description": desc.strip(),
                "difficulty":  difficulty,
            }

            sid = st.session_state.get(_SB_SID)
            if mode == "Edit existing session" and sid:
                # Update session metadata
                db.table("training_session").update(meta_payload).eq("id", sid).execute()
                # Replace all items
                db.table("training_session_item").delete().eq("training_session_id", sid).execute()
            else:
                # id column has no sequence — compute next id manually.
                max_row = db.table("training_session").select("id").order("id", desc=True).limit(1).execute()
                next_id = (max_row.data[0]["id"] + 1) if max_row.data else 1
                result = db.table("training_session").insert({**meta_payload, "id": next_id}).execute()
                sid = result.data[0]["id"]

            # Insert items
            item_rows = [
                {
                    "training_session_id": sid,
                    "exercise_id":         item["exercise_id"],
                    "position":            pos,
                    "reps_to_do":          item["reps_to_do"],
                }
                for pos, item in enumerate(items)
            ]
            db.table("training_session_item").insert(item_rows).execute()

        st.success(f"✅ Session **{title}** saved (id {sid}).")
        bust_cache()
        st.session_state[_SB_PENDING_RESET] = True
        st.rerun()

# ─────────────────────────────────────────────────────────────────────────────
# Tab: Session Inspector
# ─────────────────────────────────────────────────────────────────────────────

def tab_inspector():
    st.header("Session Inspector")
    st.caption("Read-only view — check rep prescriptions and track durations for any session.")

    exercises = load_exercises().set_index("id")
    sessions  = load_sessions()
    items     = load_items()

    if sessions.empty:
        st.warning("No sessions.")
        return

    opts = {f"{r['title']}  (id {sid})": sid for sid, r in sessions.set_index("id").iterrows()}
    chosen = st.selectbox("Session", list(opts.keys()), key="insp_sel")
    sid    = opts[chosen]
    s_row  = sessions[sessions["id"] == sid].iloc[0]
    s_items = items[items["training_session_id"] == sid].sort_values("position")

    c1, c2, c3 = st.columns(3)
    c1.metric("Exercises", len(s_items))
    c2.metric("Difficulty", s_row.get("difficulty", "—"))
    c3.metric("Farsi title", s_row.get("title_fa") or "—")

    if s_items.empty:
        st.warning("No items.")
        return

    rows, total = [], 0
    for _, item in s_items.iterrows():
        eid = item["exercise_id"]
        ex  = exercises.loc[eid] if eid in exercises.index else None
        name    = ex["name"] if ex is not None else f"ex {eid}"
        fa      = ex.get("title_fa") or "—" if ex is not None else "—"
        dur     = ex.get("duration_seconds") if ex is not None else None
        def_rep = int(ex["repetitions"]) if ex is not None and pd.notna(ex.get("repetitions")) else 1
        reps    = int(item["reps_to_do"])
        if dur and def_rep:
            t = round(float(dur) / def_rep * reps)
            total += t
            dur_str = f"{t}s"
        else:
            dur_str = "—"
        rows.append({
            "#": int(item["position"]),
            "Exercise": name, "فارسی": fa,
            "Default": def_rep, "Prescribed": reps,
            "Custom": "🟠" if reps != def_rep else "🟢",
            "Track time": dur_str,
        })

    st.dataframe(pd.DataFrame(rows), use_container_width=True, hide_index=True)
    m, s = divmod(total, 60)
    st.metric("Estimated total", f"{m}m {s}s" if s else f"{m}m")

# ─────────────────────────────────────────────────────────────────────────────
# Tab: Movement Media
# ─────────────────────────────────────────────────────────────────────────────

def tab_movement_media():
    st.header("Movement Media")
    st.caption(
        "Assign a photo or video to each movement. "
        "The player shows this in the stage card while the exercise is playing."
    )

    if st.button("↺ Reload", key="rel_mov"):
        load_movements.clear()

    movements = load_movements()
    if movements.empty:
        st.info(
            "No movements found. Run the DB migration to create the `movement` table, "
            "then refresh."
        )
        return

    # ── Thumbnail grid ────────────────────────────────────────────────────────
    st.subheader(f"All movements ({len(movements)})")
    n_cols = 4
    cols = st.columns(n_cols)
    for i, (_, row) in enumerate(movements.iterrows()):
        with cols[i % n_cols]:
            media_type = row.get("media_type") or "none"
            media_src  = row.get("media_src")  or ""
            name       = row.get("name") or f"id {row['id']}"
            if media_type == "photo" and media_src:
                try:
                    st.image(media_src, use_container_width=True)
                except Exception:
                    st.caption("⚠️ image failed")
            elif media_type == "video" and media_src:
                st.caption("🎬 video")
            else:
                st.markdown(
                    "<div style='background:#2a2a2a;height:80px;border-radius:8px;"
                    "display:flex;align-items:center;justify-content:center;"
                    "color:#888;font-size:22px'>📷</div>",
                    unsafe_allow_html=True,
                )
            st.caption(f"**{name}**")

    st.divider()

    # ── Edit form ─────────────────────────────────────────────────────────────
    st.subheader("Upload or update media")

    mov_opts = {
        f"{r.get('name', '?')}  (id {mid})": mid
        for mid, r in movements.set_index("id").iterrows()
    }
    chosen_label = st.selectbox("Movement", list(mov_opts.keys()), key="mm_sel")
    movement_id  = mov_opts[chosen_label]
    mov_row      = movements[movements["id"] == movement_id].iloc[0]

    cur_type = mov_row.get("media_type") or "none"
    cur_src  = mov_row.get("media_src")  or ""
    cur_post = mov_row.get("media_poster") or ""

    # Show current media
    if cur_type == "photo" and cur_src:
        st.image(cur_src, caption="Current photo", width=280)
    elif cur_type == "video" and cur_src:
        try:
            st.video(cur_src)
        except Exception:
            st.caption(f"Video URL: {cur_src}")
    else:
        st.info("No media currently assigned to this movement.")

    # ── Info-page content (movement_info) ─────────────────────────────────────
    st.subheader("Info page content")
    st.caption(
        "Shown on the in-app move info page (opened via the ⓘ on a track). "
        "Video is optional — a placeholder is shown until the app plays it."
    )
    info_map = load_movement_info()
    cur_info = info_map.get(int(movement_id), {})
    with st.form(f"movement_info_{movement_id}"):
        desc = st.text_area(
            "Description",
            value=cur_info.get("description") or "",
            height=160,
            help="How to perform the move — cues, technique, breathing, etc.",
        )
        video_url = st.text_input(
            "Video URL (optional)",
            value=cur_info.get("video_url") or "",
        )
        if st.form_submit_button("💾 Save info"):
            try:
                get_client().table("movement_info").upsert(
                    {
                        "movement_id": int(movement_id),
                        "description": desc.strip() or None,
                        "video_url": video_url.strip() or None,
                    },
                    on_conflict="movement_id",
                ).execute()
                load_movement_info.clear()
                st.success("Saved move info.")
            except Exception as e:
                st.error(f"Could not save (is migration 0005 applied?): {e}")

    st.divider()

    tab_upload, tab_url, tab_clear = st.tabs(["📤 Upload image", "🔗 Set URL", "🗑️ Clear"])

    # ── Upload image ──────────────────────────────────────────────────────────
    with tab_upload:
        uploaded = st.file_uploader(
            "Choose image (jpg / png / webp)",
            type=["jpg", "jpeg", "png", "webp"],
            key="mm_uploader",
        )
        if uploaded:
            st.image(uploaded, caption="Preview", width=280)
            ext = Path(uploaded.name).suffix.lower()
            mime_map = {".jpg": "image/jpeg", ".jpeg": "image/jpeg",
                        ".png": "image/png", ".webp": "image/webp"}
            mime = mime_map.get(ext, "image/jpeg")
            slug = slugify(mov_row.get("name") or f"movement-{movement_id}")
            r2_key = f"{R2_IMAGE_MOVEMENT_PREFIX}{movement_id}-{slug}{ext}"
            st.caption(f"Will upload to R2: `{r2_key}`")

            if st.button("Upload & save", type="primary", key="mm_up_btn"):
                data = uploaded.getvalue()
                try:
                    with st.spinner("Uploading…"):
                        url = upload_bytes_to_r2(data, r2_key, mime)
                        get_client().table("movement").update(
                            {"media_type": "photo", "media_src": url, "media_poster": None}
                        ).eq("id", movement_id).execute()
                    st.success(
                        f"✅ Photo uploaded and linked to **{mov_row.get('name')}**."
                    )
                    load_movements.clear()
                    st.rerun()
                except Exception as e:
                    st.error(f"Upload failed: {e}")

    # ── Set URL directly ──────────────────────────────────────────────────────
    with tab_url:
        url_type = st.radio(
            "Media type", ["photo", "video"],
            index=0 if cur_type != "video" else 1,
            key="mm_url_type",
        )
        url_input    = st.text_input("Media URL", value=cur_src,  key="mm_url_in")
        poster_input = st.text_input(
            "Poster image URL (video only)", value=cur_post, key="mm_post_in"
        )
        if st.button("Save URL", type="primary", key="mm_url_btn"):
            get_client().table("movement").update({
                "media_type":   url_type,
                "media_src":    url_input.strip() or None,
                "media_poster": poster_input.strip() or None,
            }).eq("id", movement_id).execute()
            st.success("✅ Saved.")
            load_movements.clear()
            st.rerun()

    # ── Clear ─────────────────────────────────────────────────────────────────
    with tab_clear:
        st.warning("This removes the media link from the movement (the file in Storage is kept).")
        if st.button("Clear media", type="secondary", key="mm_clr_btn"):
            get_client().table("movement").update(
                {"media_type": "none", "media_src": None, "media_poster": None}
            ).eq("id", movement_id).execute()
            st.success("Cleared.")
            load_movements.clear()
            st.rerun()


# ─────────────────────────────────────────────────────────────────────────────
# Tab: Video Upload
# ─────────────────────────────────────────────────────────────────────────────

def tab_video_upload():
    st.header("Video Upload")
    st.caption(
        "Upload a raw source clip and publish it as a movement's demonstration video "
        "(stored on Cloudflare R2), scaled down to a smaller size. Defaults to the "
        "source's original framing (no crop) — like watching a normal video, not a "
        "portrait reel. Narrow the crop width below only if a specific clip needs it "
        "(e.g. to trim empty space beside the subject); preview before committing."
    )

    movements = load_movements()
    if movements.empty:
        st.info("No movements found. Run the DB migration first.")
        return

    mov_opts = {
        f"{r.get('name', '?')}  (id {mid})": mid
        for mid, r in movements.set_index("id").iterrows()
    }
    chosen_label = st.selectbox("Movement", list(mov_opts.keys()), key="vid_mov_sel")
    movement_id = mov_opts[chosen_label]
    mov_row = movements[movements["id"] == movement_id].iloc[0]

    if (mov_row.get("media_type") or "none") == "video" and mov_row.get("media_src"):
        st.caption("Current video:")
        try:
            st.video(mov_row["media_src"])
        except Exception:
            st.caption(f"Video URL: {mov_row['media_src']}")

        st.markdown('**Video anchor — "sarzarb"/main beat**')
        st.caption(
            "The player's scrubber only shows whole seconds, which isn't "
            "precise enough — nudge the timestamp below in ~1-frame steps "
            "and check the preview frame until it's exactly on the beat "
            "(e.g. the bottom of a push-up), then save."
        )
        current_anchor_ms = mov_row.get("video_anchor_ms")
        default_anchor_s = float(current_anchor_ms) / 1000 if pd.notna(current_anchor_ms) else 0.0
        anchor_col1, anchor_col2 = st.columns([2, 1])
        cur_anchor_s = anchor_col1.number_input(
            "Anchor (s)", min_value=0.0, value=default_anchor_s, step=1 / 30,
            format="%.3f", key="cur_vid_anchor_s",
        )
        anchor_col2.markdown(f"**{format_mmss(cur_anchor_s)}**")
        if st.button("🔍 Preview frame", key="cur_vid_anchor_preview_btn"):
            frame = extract_frame_at(mov_row["media_src"], cur_anchor_s)
            if frame:
                st.image(frame, caption=f"Frame @ {format_mmss(cur_anchor_s)}", width=300)
            else:
                st.error("Preview extraction failed.")
        if st.button("💾 Save anchor", type="primary", key="cur_vid_anchor_save_btn"):
            anchor_ms = round(cur_anchor_s * 1000)
            try:
                if mov_row.get("video_id"):
                    get_client().table("video").update(
                        {"video_anchor_ms": anchor_ms}
                    ).eq("id", int(mov_row["video_id"])).execute()
                get_client().table("movement").update(
                    {"video_anchor_ms": anchor_ms}
                ).eq("id", movement_id).execute()
            except Exception as e:
                st.error(f"Save failed: {e}")
            else:
                st.success(f"Anchor saved: {format_mmss(cur_anchor_s)}")
                load_movements.clear()

    uploaded = st.file_uploader(
        "Source video (raw clip, any resolution)", type=["mp4", "mov", "mkv"], key="vid_uploader"
    )
    if not uploaded:
        return

    # ffmpeg needs a real file on disk — persist the upload to a stable temp path.
    tmp_dir = Path(tempfile.gettempdir()) / "pahlevani_admin_video"
    tmp_dir.mkdir(exist_ok=True)
    src_path = tmp_dir / f"src_{movement_id}_{uploaded.name}"
    if not src_path.exists() or st.session_state.get("vid_src_name") != uploaded.name:
        src_path.write_bytes(uploaded.getvalue())
        st.session_state["vid_src_name"] = uploaded.name
        st.session_state.pop("vid_encoded_path", None)  # new source invalidates any prior encode

    info = probe_video(str(src_path))
    if not info:
        st.error("Could not read this video (ffprobe failed). Is ffmpeg installed and the file valid?")
        return
    src_w, src_h, src_duration = info["width"], info["height"], info["duration"]
    st.caption(f"Source: {src_w}×{src_h}, {src_duration:.1f}s")

    st.subheader("Crop (optional)")
    default_crop_w = src_w  # full width by default — preserve the source's own aspect ratio
    col1, col2, col3 = st.columns(3)
    crop_w = col1.number_input(
        "Crop width (px)", min_value=100, max_value=src_w, value=default_crop_w, step=10, key="vid_crop_w"
    )
    crop_x = col2.number_input(
        "Crop x-offset (px)", min_value=0, max_value=max(src_w - crop_w, 0),
        value=min(max((src_w - crop_w) // 2, 0), max(src_w - crop_w, 0)), step=10, key="vid_crop_x",
    )
    preview_t = col3.number_input(
        "Preview timestamp (s)", min_value=0.0, max_value=max(src_duration - 0.1, 0.0),
        value=min(5.0, max(src_duration - 0.1, 0.0)), step=1.0, key="vid_preview_t",
    )
    crop_h = src_h  # full source height — every crop used so far keeps full height

    if st.button("🔍 Preview crop", key="vid_preview_btn"):
        frame = extract_preview_frame(str(src_path), int(crop_w), int(crop_h), int(crop_x), 0, preview_t)
        if frame:
            st.image(frame, caption=f"Preview @ {preview_t}s — {int(crop_w)}×{int(crop_h)}", width=300)
        else:
            st.error("Preview extraction failed.")

    st.subheader("Trim & output")
    col4, col5, col6 = st.columns(3)
    trim_start = col4.number_input(
        "Trim start (s)", min_value=0.0, max_value=src_duration, value=0.0, step=1.0, key="vid_trim_start"
    )
    trim_end = col5.number_input(
        "Trim end (s, 0 = full length)", min_value=0.0, max_value=src_duration, value=0.0, step=1.0,
        key="vid_trim_end",
    )
    target_height = col6.number_input(
        "Output height (px)", min_value=240, max_value=1920, value=720, step=60, key="vid_target_h"
    )
    strip_audio = st.checkbox("Strip audio", value=True, key="vid_strip_audio")

    if st.button("🚀 Process", type="primary", key="vid_process_btn"):
        trim_duration = (trim_end - trim_start) if trim_end > trim_start else None
        out_path = tmp_dir / f"out_{movement_id}.mp4"
        poster_path = tmp_dir / f"poster_{movement_id}.jpg"
        with st.spinner("Encoding…"):
            ok = encode_video(
                str(src_path), str(out_path), int(crop_w), int(crop_h), int(crop_x), 0,
                int(target_height), trim_start, trim_duration, strip_audio,
            )
        if not ok:
            st.error("ffmpeg encode failed.")
        else:
            out_info = probe_video(str(out_path))
            with st.spinner("Extracting poster…"):
                extract_poster(str(out_path), str(poster_path))
            st.session_state["vid_encoded_path"] = str(out_path)
            st.session_state["vid_poster_path"] = str(poster_path)
            st.session_state["vid_out_info"] = out_info
            st.session_state["vid_file_size"] = out_path.stat().st_size

    if st.session_state.get("vid_encoded_path"):
        out_info = st.session_state["vid_out_info"]
        file_size = st.session_state["vid_file_size"]
        st.success(
            f"Encoded: {out_info.get('width')}×{out_info.get('height')}, "
            f"{out_info.get('duration', 0):.1f}s, {file_size / 1_000_000:.1f}MB"
        )
        st.video(st.session_state["vid_encoded_path"])

        st.markdown('**Video anchor — "sarzarb"/main beat**')
        st.caption(
            "The player's scrubber only shows whole seconds — nudge in "
            "~1-frame steps and check the preview frame until it's exactly "
            "on the beat (e.g. the bottom of a push-up)."
        )
        anchor_col1, anchor_col2 = st.columns([2, 1])
        anchor_s = anchor_col1.number_input(
            "Anchor (s)", min_value=0.0, max_value=float(out_info.get("duration") or 999.0),
            value=0.0, step=1 / 30, format="%.3f", key="vid_anchor_s",
        )
        anchor_col2.markdown(f"**{format_mmss(anchor_s)}**")
        if st.button("🔍 Preview frame", key="vid_anchor_preview_btn"):
            frame = extract_frame_at(st.session_state["vid_encoded_path"], anchor_s)
            if frame:
                st.image(frame, caption=f"Frame @ {format_mmss(anchor_s)}", width=300)
            else:
                st.error("Preview extraction failed.")

        if st.button("✅ Confirm — upload to R2 & link to movement", type="primary", key="vid_confirm_btn"):
            slug = slugify(mov_row.get("name") or f"movement-{movement_id}")
            video_key = f"{R2_VIDEO_PREFIX}{movement_id}-{slug}.mp4"
            poster_key = f"{R2_VIDEO_POSTER_PREFIX}{movement_id}-{slug}.jpg"
            try:
                video_anchor_ms = round(anchor_s * 1000)
                with st.spinner("Uploading to R2…"):
                    video_url = upload_asset_to_r2(
                        st.session_state["vid_encoded_path"], video_key, "video/mp4"
                    )
                    poster_url = upload_asset_to_r2(
                        st.session_state["vid_poster_path"], poster_key, "image/jpeg"
                    )

                    video_row = get_client().table("video").insert({
                        "url": video_url,
                        "poster_url": poster_url,
                        "width": out_info.get("width"),
                        "height": out_info.get("height"),
                        "duration_seconds": out_info.get("duration"),
                        "file_size_bytes": file_size,
                        "format": "h264/mp4",
                        "video_anchor_ms": video_anchor_ms,
                    }).execute().data[0]

                    get_client().table("movement").update({
                        "media_type": "video",
                        "media_src": video_url,
                        "media_poster": poster_url,
                        "video_id": video_row["id"],
                        # Write-through copy — the app reads movement directly
                        # and never joins video (see migration 0012).
                        "video_anchor_ms": video_anchor_ms,
                    }).eq("id", movement_id).execute()
            except Exception as e:
                st.error(f"Upload failed: {e}")
            else:
                st.success(f"✅ Video uploaded and linked to **{mov_row.get('name')}**.")
                for key in ("vid_encoded_path", "vid_poster_path", "vid_out_info", "vid_file_size"):
                    st.session_state.pop(key, None)
                load_movements.clear()
                st.rerun()


# ─────────────────────────────────────────────────────────────────────────────
# Tab: Release Gate
# ─────────────────────────────────────────────────────────────────────────────

def tab_release_gate():
    st.header("Release Gate")
    st.caption(
        "Controls whether old app builds are blocked from running. "
        "The app reads this table on every launch via the anon key — no auth required."
    )

    if st.button("↺ Reload", key="rel_rg"):
        load_release_gate.clear()

    cfg = load_release_gate()

    if cfg is None:
        st.error(
            "⚠️ `app_release_gate` table not found. "
            "Run `supabase/migrations/0002_app_release_gate.sql` in the Supabase SQL Editor first."
        )
        return

    # ── Current state summary ─────────────────────────────────────────────────
    force = cfg.get("force_update", False)
    min_build = cfg.get("min_supported_build_number", 1)
    msg = cfg.get("update_message", "")
    updated_at = cfg.get("updated_at", "—")

    col1, col2, col3 = st.columns(3)
    col1.metric("Min supported build", min_build)
    col2.metric("Force update", "🔴 YES" if force else "🟢 No")
    col3.metric("Last updated", str(updated_at)[:19])

    if force:
        st.warning(
            f"⚠️  **Force update is ON.** All installs with build number < {min_build} "
            "are blocked from using the app."
        )

    st.divider()

    # ── Edit form ─────────────────────────────────────────────────────────────
    st.subheader("Edit gate settings")

    new_min_build = st.number_input(
        "Minimum supported build number",
        min_value=1,
        value=int(min_build),
        help="Any installed app with a build number below this will see the update screen.",
        key="rg_min_build",
    )

    new_force = st.toggle(
        "Force update (blocks app until updated)",
        value=bool(force),
        key="rg_force",
    )

    if new_force:
        st.warning(
            "With force update **ON**, any install with build < "
            f"{new_min_build} is **fully blocked** — they see the update screen and "
            "cannot proceed until they install a newer build."
        )

    new_msg = st.text_area(
        "Update message shown to the user",
        value=msg,
        height=90,
        key="rg_msg",
    )

    st.divider()

    if st.button("💾 Save release gate", type="primary", key="rg_save"):
        with st.spinner("Saving…"):
            get_client().table("app_release_gate").update({
                "min_supported_build_number": int(new_min_build),
                "force_update": bool(new_force),
                "update_message": new_msg.strip(),
                "updated_at": "now()",
            }).eq("id", 1).execute()
        st.success("✅ Release gate updated.")
        load_release_gate.clear()
        st.rerun()


# ─────────────────────────────────────────────────────────────────────────────
# Tab: Trainer Role
# ─────────────────────────────────────────────────────────────────────────────

def tab_grant_trainer():
    st.header("Trainer Role")
    st.caption(
        "Grants/revokes is_trainer on a profile — the only way this ever "
        "changes, no self-serve flow in the app. A trainer can assign "
        "individualized sessions to any signed-up trainee."
    )

    if st.button("↺ Reload", key="trainer_reload"):
        load_profiles.clear()

    try:
        profiles = load_profiles()
    except Exception:
        st.error(
            "⚠️ `profiles` table not found. "
            "Run `supabase/migrations/0013_profiles_and_consent.sql` in the "
            "Supabase SQL Editor first."
        )
        return

    trainers = [p for p in profiles if p.get("is_trainer")]

    col1, col2 = st.columns(2)
    col1.metric("Trainees", len(profiles) - len(trainers))
    col2.metric("Trainers", len(trainers))

    st.divider()

    if trainers:
        st.subheader("Current trainers")
        st.dataframe(
            pd.DataFrame(trainers)[["email", "id", "created_at"]],
            hide_index=True,
            use_container_width=True,
        )

    st.divider()
    st.subheader("Grant / revoke")

    if not profiles:
        st.info("No signed-up accounts yet.")
        return

    options = {f"{p.get('email') or p['id']}": p for p in profiles}
    selected_label = st.selectbox("Account", options=list(options.keys()), key="trainer_select")
    selected = options[selected_label]
    is_trainer_now = bool(selected.get("is_trainer"))

    st.write(f"Currently: {'🔴 Trainer' if is_trainer_now else '🟢 Trainee'}")

    label = "Revoke trainer" if is_trainer_now else "✅ Make trainer"
    if st.button(label, type="primary", key="trainer_toggle"):
        get_client().table("profiles").update(
            {"is_trainer": not is_trainer_now}
        ).eq("id", selected["id"]).execute()
        st.success(f"✅ {selected_label} is now {'a trainee' if is_trainer_now else 'a trainer'}.")
        load_profiles.clear()
        st.rerun()


def tab_invite_codes():
    st.header("Invite Codes")
    st.caption(
        "Trainer-issued codes gating student signup (username/password, no "
        "email involved) — supabase/migrations/0016_invite_code_signup.sql. "
        "Codes are stored in plain text (the table isn't reachable through "
        "the app's API either way) so you can look one back up any time — "
        "see the table below."
    )

    if st.button("↺ Reload", key="invite_codes_reload"):
        load_invite_codes.clear()
        load_profiles.clear()

    try:
        codes = load_invite_codes()
    except Exception:
        st.error(
            "⚠️ `invite_codes` table not found. "
            "Run `supabase/migrations/0016_invite_code_signup.sql` in the "
            "Supabase SQL Editor first."
        )
        return

    st.subheader("Generate a new code")

    # Outside the form so it reruns immediately (form-internal widgets only
    # rerun on submit) — needed so the warning + custom-code field actually
    # appear/disappear as this is toggled, not just after submitting.
    use_custom = st.checkbox("Use a custom code instead of auto-generating one")
    if use_custom:
        st.warning(
            "⚠️ A custom code (e.g. a class or event name) is far easier to "
            "guess than a random one — anyone who figures it out can create "
            "an account with it. Best paired with a usage limit below, and "
            "revoked once you're done handing it out."
        )

    with st.form("new_invite_code"):
        label = st.text_input(
            "Label",
            placeholder="e.g. Fall 2026 Class A, or a specific student's name",
            help="Your own bookkeeping only — not shown to whoever uses the code.",
        )
        custom_code = (
            st.text_input("Custom code", placeholder="e.g. PahlevaniFall2026")
            if use_custom
            else None
        )
        max_uses = st.number_input(
            "Max uses",
            min_value=0,
            value=0,
            step=1,
            help="0 = unlimited. Fixed at creation — to raise a quota later, revoke this code and issue a new one.",
        )
        submitted = st.form_submit_button("Generate", type="primary")

    if submitted:
        if use_custom:
            if not custom_code or not custom_code.strip():
                st.error("Enter a custom code, or uncheck 'Use a custom code'.")
                return
            plaintext = custom_code.strip()
        else:
            plaintext = secrets.token_urlsafe(9)  # short, readable, ~12 chars

        get_client().table("invite_codes").insert({
            "code": plaintext,
            "label": label or None,
            "max_uses": int(max_uses) or None,
        }).execute()
        load_invite_codes.clear()
        st.success("✅ Code created:")
        st.code(plaintext, language=None)

    st.divider()
    st.subheader("Existing codes")

    if not codes:
        st.info("No invite codes yet.")
        return

    rows = [
        {
            "code": c["code"],
            "label": c.get("label") or "(untitled)",
            "created_at": c["created_at"],
            "status": "🔴 revoked" if c.get("revoked_at") else "🟢 active",
            "uses": f"{c.get('uses_count', 0)} / {c['max_uses'] if c.get('max_uses') else '∞'}",
        }
        for c in codes
    ]
    st.dataframe(pd.DataFrame(rows), hide_index=True, use_container_width=True)

    st.divider()
    st.subheader("Revoke a code")
    active = [c for c in codes if not c.get("revoked_at")]
    if not active:
        st.info("No active codes to revoke.")
        return

    options = {
        f"{c.get('label') or '(untitled)'} (created {c['created_at'][:10]})": c
        for c in active
    }
    selected_label = st.selectbox(
        "Code", options=list(options.keys()), key="invite_code_revoke_select"
    )
    selected = options[selected_label]
    if st.button("Revoke", key="invite_code_revoke_button"):
        get_client().table("invite_codes").update(
            {"revoked_at": datetime.now(timezone.utc).isoformat()}
        ).eq("id", selected["id"]).execute()
        st.success(f"✅ Revoked '{selected_label}'.")
        load_invite_codes.clear()
        st.rerun()


def tab_users():
    st.header("Users")
    st.caption(
        "Every signed-up account (Google and invite-code both). Deleting "
        "or resetting a password here goes through the Supabase Admin API "
        "and takes effect immediately — there is no undo."
    )

    if st.button("↺ Reload", key="users_reload"):
        load_profiles.clear()
        load_invite_codes.clear()

    try:
        profiles = load_profiles()
    except Exception:
        st.error(
            "⚠️ `profiles` table not found. "
            "Run `supabase/migrations/0013_profiles_and_consent.sql` in the "
            "Supabase SQL Editor first."
        )
        return

    if not profiles:
        st.info("No signed-up accounts yet.")
        return

    # invite_codes may not exist on older projects (pre-0016) — a signed-up
    # user list shouldn't depend on that migration having run.
    try:
        code_labels = {c["id"]: (c.get("label") or c["code"]) for c in load_invite_codes()}
    except Exception:
        code_labels = {}

    st.subheader(f"All accounts ({len(profiles)})")
    rows = [
        {
            "email": p.get("email") or "(no email)",
            "role": "🧑‍🏫 Trainer" if p.get("is_trainer") else "Trainee",
            "consent": "✅" if p.get("consent_accepted") else "—",
            "signed up via": code_labels.get(
                p.get("signed_up_via_invite_code_id"), "Google / email"
            ) if p.get("signed_up_via_invite_code_id") else "Google / email",
            "created_at": p.get("created_at"),
            "id": p["id"],
        }
        for p in profiles
    ]
    st.dataframe(pd.DataFrame(rows), hide_index=True, use_container_width=True)

    st.divider()
    st.subheader("Manage a user")

    options = {f"{p.get('email') or p['id']}": p for p in profiles}
    selected_label = st.selectbox("Account", options=list(options.keys()), key="users_manage_select")
    selected = options[selected_label]
    user_id = selected["id"]
    st.caption(f"ID: `{user_id}`")

    st.markdown("**Set a new password**")
    with st.form("users_set_password"):
        new_password = st.text_input("New password", type="password")
        submitted_pw = st.form_submit_button("Set password", type="primary")
    if submitted_pw:
        if not new_password or len(new_password) < 6:
            st.error("Password must be at least 6 characters.")
        else:
            try:
                get_client().auth.admin.update_user_by_id(user_id, {"password": new_password})
                st.success(f"✅ Password updated for {selected_label}.")
            except Exception as e:
                st.error(f"Could not update password: {e}")

    st.divider()
    st.markdown("**Delete this account**")
    st.warning(
        "⚠️ Permanently deletes the auth account and profile — cannot be "
        "undone. Any invite code they signed up with keeps its usage count "
        "as-is (not refunded), so it can't be replayed to dodge a quota."
    )
    confirm = st.checkbox(
        f"I understand this permanently deletes {selected_label}",
        key="users_delete_confirm",
    )
    if st.button("🗑️ Delete account", key="users_delete_button", disabled=not confirm):
        try:
            get_client().auth.admin.delete_user(user_id)
            st.success(f"✅ Deleted {selected_label}.")
            load_profiles.clear()
            st.rerun()
        except Exception as e:
            st.error(f"Could not delete account: {e}")


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    st.set_page_config(page_title="Pahlevani Admin", page_icon="🏛️", layout="wide")
    st.title("🏛️  Pahlevani Admin")
    project_id = SUPABASE_URL.split("//")[-1].split(".")[0]
    st.caption(f"Supabase · `{project_id}`")

    t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11 = st.tabs([
        "⚙️  Exercises",
        "📋  Sessions",
        "📥  Batch Import",
        "🏗️  Session Builder",
        "🔍  Inspector",
        "📸  Movement Media",
        "🎬  Video Upload",
        "🚦  Release Gate",
        "🧑‍🏫  Trainer Role",
        "🎟️  Invite Codes",
        "👤  Users",
    ])
    with t1: tab_exercises()
    with t2: tab_sessions()
    with t3: tab_batch_import()
    with t4: tab_session_builder()
    with t5: tab_inspector()
    with t6: tab_movement_media()
    with t7: tab_video_upload()
    with t8: tab_release_gate()
    with t9: tab_grant_trainer()
    with t10: tab_invite_codes()
    with t11: tab_users()


if __name__ == "__main__":
    main()
