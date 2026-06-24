"""
Pahlevani Admin — data-entry tool for the exercise and session library.

Run:
    cd scripts
    uv run streamlit run admin.py

Credentials (required — use the service-role key, not the anon key):
  • env vars:  SUPABASE_URL  SUPABASE_KEY
  • .streamlit/secrets.toml with those two keys (preferred)

Storage:
  Set BUCKET_PUBLIC = True once you make the 'tracks' bucket public in Supabase
  Dashboard (Storage → tracks → Make public).  Until then, new uploads generate
  a 10-year signed URL and store that.
"""

import io
import os
import re
import tempfile
import uuid
from pathlib import Path

import pandas as pd
import streamlit as st
from mutagen.mp3 import MP3
from supabase import create_client, Client

# ── Config ────────────────────────────────────────────────────────────────────

def _secret(key: str) -> str:
    try:
        return st.secrets[key]
    except Exception:
        return ""

SUPABASE_URL = os.getenv("SUPABASE_URL") or _secret("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY") or _secret("SUPABASE_KEY")

STORAGE_BUCKET = "tracks"
# Bucket for movement photos / poster images.
MEDIA_BUCKET = "movement-media"
# Set True after making the bucket public in Supabase Dashboard.
# False → generate a 10-year signed URL on upload.
BUCKET_PUBLIC = False
MEDIA_BUCKET_PUBLIC = False
SIGNED_URL_EXPIRY = 60 * 60 * 24 * 365 * 10  # 10 years in seconds

# ── DB / Storage client ───────────────────────────────────────────────────────

@st.cache_resource
def get_client() -> Client:
    if not SUPABASE_URL or not SUPABASE_KEY:
        st.error(
            "Supabase credentials not configured. "
            "Add SUPABASE_URL and SUPABASE_KEY (service-role key) to "
            "scripts/.streamlit/secrets.toml"
        )
        st.stop()
    return create_client(SUPABASE_URL, SUPABASE_KEY)

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
def load_movements() -> pd.DataFrame:
    try:
        rows = get_client().table("movement").select("*").order("id").execute().data
        return pd.DataFrame(rows) if rows else pd.DataFrame()
    except Exception as e:
        st.warning(f"Could not load movement table ({e}). Run the DB migration first.")
        return pd.DataFrame()

@st.cache_data(ttl=30)
def load_profiles() -> pd.DataFrame:
    try:
        rows = get_client().table("profiles").select("*").order("email").execute().data
        return pd.DataFrame(rows) if rows else pd.DataFrame()
    except Exception as e:
        st.warning(f"Could not load profiles table ({e}). Run the DB migration first.")
        return pd.DataFrame()

@st.cache_data(ttl=30)
def load_roster() -> pd.DataFrame:
    try:
        rows = get_client().table("trainer_roster").select("*").order("trainer_id").execute().data
        return pd.DataFrame(rows) if rows else pd.DataFrame()
    except Exception as e:
        st.warning(f"Could not load trainer_roster table ({e}). Run the DB migration first.")
        return pd.DataFrame()

def bust_cache():
    load_exercises.clear()
    load_sessions.clear()
    load_items.clear()
    load_movements.clear()
    load_profiles.clear()
    load_roster.clear()

def make_media_url(storage_path: str) -> str:
    if MEDIA_BUCKET_PUBLIC:
        return f"{SUPABASE_URL}/storage/v1/object/public/{MEDIA_BUCKET}/{storage_path}"
    r = get_client().storage.from_(MEDIA_BUCKET).create_signed_url(
        storage_path, SIGNED_URL_EXPIRY
    )
    return r.get("signedURL") or r.get("signed_url") or ""

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

def make_url(storage_path: str) -> str:
    if BUCKET_PUBLIC:
        return f"{SUPABASE_URL}/storage/v1/object/public/{STORAGE_BUCKET}/{storage_path}"
    # Generate a signed URL
    r = get_client().storage.from_(STORAGE_BUCKET).create_signed_url(
        storage_path, SIGNED_URL_EXPIRY
    )
    return r.get("signedURL") or r.get("signed_url") or ""

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

def find_profile_by_email(email: str) -> dict | None:
    """profiles is read via the service-role key, which bypasses RLS — that's
    intentional here, this tool is the only place a trainer/trainee gets
    looked up by email."""
    rows = (
        get_client().table("profiles").select("*")
        .eq("email", email.strip().lower()).execute().data
    )
    return rows[0] if rows else None

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
        "Edit movement names and reps in the table before inserting."
    )

    if not BUCKET_PUBLIC:
        st.info(
            "🔒 Bucket is **private** — uploads will generate 10-year signed URLs. "
            "To use permanent public URLs, make the `tracks` bucket public in "
            "Supabase Dashboard and set `BUCKET_PUBLIC = True` in admin.py."
        )

    # ── Batch settings ────────────────────────────────────────────────────────
    c1, c2, c3 = st.columns([2, 1, 2])
    with c1:
        batch_author = st.text_input(
            "Morshed / Author (for whole batch)",
            placeholder="e.g. Morshed Karimi",
        )
    with c2:
        batch_reps = st.number_input("Default reps (batch)", min_value=1, max_value=999, value=1)
    with c3:
        subfolder = st.text_input(
            "Storage subfolder",
            value=slugify(batch_author) if batch_author else "",
            placeholder="e.g. morshed_karimi",
            help="Files will be stored as: tracks/{subfolder}/{filename}",
        )

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
                    "storage_path":     f"{subfolder}/{fname}" if subfolder else fname,
                }
            )
        st.session_state.batch_preview = pd.DataFrame(rows)

    preview_df = st.session_state.batch_preview.copy()

    # ── Editable preview ──────────────────────────────────────────────────────
    st.subheader("Preview — edit before inserting")

    cfg = {
        "filename":         st.column_config.TextColumn("File",           disabled=True, width=200),
        "movement_name":    st.column_config.TextColumn("Movement name ✏️", width=200),
        "author":           st.column_config.TextColumn("Author ✏️",       width=150),
        "default_reps":     st.column_config.NumberColumn("Default reps ✏️", min_value=1, max_value=999, width=100),
        "duration_seconds": st.column_config.NumberColumn("Duration (s)",  disabled=True, width=100),
        "storage_path":     st.column_config.TextColumn("Storage path ✏️", width=250),
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
    if st.button("🚀 Upload to Storage + Insert exercises", type="primary", key="do_import"):
        db = get_client()
        progress = st.progress(0)
        status   = st.empty()
        errors   = []

        for i, (_, row) in enumerate(edited.iterrows()):
            fname   = row["filename"]
            s_path  = row["storage_path"].strip("/")
            data    = file_map.get(fname, b"")
            status.text(f"Uploading {fname}…")

            try:
                # Upload to Supabase Storage
                db.storage.from_(STORAGE_BUCKET).upload(
                    path=s_path,
                    file=data,
                    file_options={"content-type": "audio/mpeg", "upsert": "true"},
                )
                url = make_url(s_path)

                # Insert exercise row
                payload = {
                    "name":             row["movement_name"],
                    "author":           row["author"] or None,
                    "repetitions":      int(row["default_reps"]),
                    "url":              url,
                }
                if pd.notna(row["duration_seconds"]):
                    payload["duration_seconds"] = int(row["duration_seconds"])

                db.table("exercise").insert(payload).execute()

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

    tab_upload, tab_url, tab_clear = st.tabs(["📤 Upload image", "🔗 Set URL", "🗑️ Clear"])

    # ── Upload image ──────────────────────────────────────────────────────────
    with tab_upload:
        if not MEDIA_BUCKET_PUBLIC:
            st.info(
                "🔒 `movement-media` bucket is **private** — uploads will use "
                "10-year signed URLs. Make it public in Supabase Dashboard and "
                "set `MEDIA_BUCKET_PUBLIC = True` in admin.py for permanent links."
            )
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
            storage_path = f"{movement_id}/{uploaded.name}"
            st.caption(f"Will upload to: `{MEDIA_BUCKET}/{storage_path}`")

            if st.button("Upload & save", type="primary", key="mm_up_btn"):
                data = uploaded.getvalue()
                try:
                    with st.spinner("Uploading…"):
                        get_client().storage.from_(MEDIA_BUCKET).upload(
                            path=storage_path,
                            file=data,
                            file_options={"content-type": mime, "upsert": "true"},
                        )
                        url = make_media_url(storage_path)
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
# Tab: Trainer Role
# ─────────────────────────────────────────────────────────────────────────────

def tab_roles():
    st.header("Trainer Role")
    st.caption(
        "Flip is_trainer for a user, looked up by their signup email. "
        "This is the only way a user becomes a trainer — the app has no "
        "self-serve 'become a trainer' flow."
    )

    email = st.text_input("User email", key="roles_email").strip().lower()
    if st.button("Look up", key="roles_lookup") and email:
        profile = find_profile_by_email(email)
        st.session_state["roles_found_profile"] = profile
        st.session_state["roles_found_email"] = email

    profile = st.session_state.get("roles_found_profile")
    if st.session_state.get("roles_found_email") == email and email:
        if profile is None:
            st.error(f"No profile found for {email}.")
        else:
            status = "a trainer" if profile.get("is_trainer") else "a trainee"
            st.write(f"**{profile['email']}** — currently {status}.")
            col1, col2 = st.columns(2)
            with col1:
                if not profile.get("is_trainer") and st.button("Make trainer", key="roles_make"):
                    get_client().table("profiles").update({"is_trainer": True}).eq("id", profile["id"]).execute()
                    st.success(f"{profile['email']} is now a trainer.")
                    bust_cache()
                    st.session_state.pop("roles_found_profile", None)
                    st.rerun()
            with col2:
                if profile.get("is_trainer") and st.button("Revoke trainer", key="roles_revoke"):
                    get_client().table("profiles").update({"is_trainer": False}).eq("id", profile["id"]).execute()
                    st.success(f"{profile['email']} is no longer a trainer.")
                    bust_cache()
                    st.session_state.pop("roles_found_profile", None)
                    st.rerun()

    st.divider()
    st.caption("All trainers")
    profiles = load_profiles()
    if profiles.empty or "is_trainer" not in profiles.columns:
        st.info("No profiles yet — they're created automatically when someone signs up.")
    else:
        trainers = profiles[profiles["is_trainer"] == True]  # noqa: E712
        cols = [c for c in ["email", "created_at"] if c in trainers.columns]
        st.dataframe(trainers[cols], use_container_width=True, hide_index=True)

# ─────────────────────────────────────────────────────────────────────────────
# Tab: Trainer ↔ Trainee Roster
# ─────────────────────────────────────────────────────────────────────────────

def tab_roster():
    st.header("Trainer ↔ Trainee Roster")
    st.caption(
        "Link a trainee to a trainer after the trainee gives the trainer "
        "(and you) their signup email. The app only ever reads this table — "
        "links are created here, never in-app."
    )

    col1, col2 = st.columns(2)
    with col1:
        trainer_email = st.text_input("Trainer email", key="roster_trainer_email").strip().lower()
    with col2:
        trainee_email = st.text_input("Trainee email", key="roster_trainee_email").strip().lower()

    if st.button("Link trainee to trainer", key="roster_link"):
        trainer = find_profile_by_email(trainer_email) if trainer_email else None
        trainee = find_profile_by_email(trainee_email) if trainee_email else None
        if trainer is None:
            st.error(f"No account found for trainer email {trainer_email}.")
        elif trainee is None:
            st.error(f"No account found for trainee email {trainee_email}.")
        elif not trainer.get("is_trainer"):
            st.error(f"{trainer_email} is not flagged as a trainer yet — set that in the Trainer Role tab first.")
        else:
            try:
                get_client().table("trainer_roster").insert({
                    "trainer_id": trainer["id"],
                    "trainee_id": trainee["id"],
                    "trainee_email": trainee["email"],
                }).execute()
                st.success(f"Linked {trainee_email} to trainer {trainer_email}.")
                bust_cache()
            except Exception as e:
                st.error(f"Failed to link (already linked?): {e}")

    st.divider()
    st.caption("Existing roster links")
    roster = load_roster()
    if roster.empty:
        st.info("No roster links yet.")
    else:
        profiles = load_profiles()
        display = roster.copy()
        if not profiles.empty:
            id_to_email = dict(zip(profiles["id"], profiles["email"]))
            display["trainer_email"] = display["trainer_id"].map(id_to_email)
        cols = [c for c in ["trainer_email", "trainee_email", "created_at"] if c in display.columns]
        st.dataframe(display[cols], use_container_width=True, hide_index=True)

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    st.set_page_config(page_title="Pahlevani Admin", page_icon="🏛️", layout="wide")
    st.title("🏛️  Pahlevani Admin")
    project_id = SUPABASE_URL.split("//")[-1].split(".")[0]
    st.caption(f"Supabase · `{project_id}`")

    t1, t2, t3, t4, t5, t6, t7, t8 = st.tabs([
        "⚙️  Exercises",
        "📋  Sessions",
        "📥  Batch Import",
        "🏗️  Session Builder",
        "🔍  Inspector",
        "📸  Movement Media",
        "🧑‍🏫  Trainer Role",
        "🔗  Roster",
    ])
    with t1: tab_exercises()
    with t2: tab_sessions()
    with t3: tab_batch_import()
    with t4: tab_session_builder()
    with t5: tab_inspector()
    with t6: tab_movement_media()
    with t7: tab_roles()
    with t8: tab_roster()


if __name__ == "__main__":
    main()
