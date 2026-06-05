"""
Pahlevani Admin — data-entry tool for the exercise and session library.

Run:
    cd scripts
    uv run streamlit run admin.py

Environment variables (or .streamlit/secrets.toml):
    SUPABASE_URL      — your project URL
    SUPABASE_KEY      — anon or service-role key (service-role needed for writes)

Streamlit Community Cloud:
    Add the two vars in the app's Secrets panel, no code change required.
"""

import os
import json

import pandas as pd
import streamlit as st
from supabase import create_client, Client

# ── Config ────────────────────────────────────────────────────────────────────
SUPABASE_URL = os.getenv("SUPABASE_URL") or st.secrets.get("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_KEY") or st.secrets.get("SUPABASE_KEY", "")

# Fall back to the values already in config.dart so local dev works without
# any extra setup — these are the public anon keys, safe to include here.
if not SUPABASE_URL:
    SUPABASE_URL = "https://eudjdgjkrhrwvjfkutcg.supabase.co"
if not SUPABASE_KEY:
    SUPABASE_KEY = (
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV1ZGpkZ2prcmhyd3ZqZmt1dGNnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDM5MjI0ODEsImV4cCI6MjA1OTQ5ODQ4MX0"
        ".a7-SBq-NiokUE0eMUCxdwYBqQC0nmRBB5yzMvZFuCjU"
    )

MEDIA_TYPES = ["none", "photo", "video"]


@st.cache_resource
def get_client() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)


# ── Data loaders ─────────────────────────────────────────────────────────────

def load_exercises() -> pd.DataFrame:
    rows = get_client().table("exercise").select("*").order("id").execute().data
    df = pd.DataFrame(rows)
    # Ensure expected columns exist even before DB migration
    for col in ["title_fa", "gloss", "media_type", "media_src", "media_poster"]:
        if col not in df.columns:
            df[col] = None
    df["media_type"] = df["media_type"].fillna("none")
    return df


def load_sessions() -> pd.DataFrame:
    rows = get_client().table("training_session").select("*").order("id").execute().data
    df = pd.DataFrame(rows)
    if "title_fa" not in df.columns:
        df["title_fa"] = None
    return df


def load_items() -> pd.DataFrame:
    rows = (
        get_client()
        .table("training_session_item")
        .select("*")
        .order("training_session_id,position")
        .execute()
        .data
    )
    return pd.DataFrame(rows)


# ── Savers ────────────────────────────────────────────────────────────────────

def save_exercises(original: pd.DataFrame, edited: pd.DataFrame):
    changed = 0
    edit_cols = ["title_fa", "gloss", "media_type", "media_src", "media_poster", "duration_seconds"]
    for _, row in edited.iterrows():
        orig_row = original[original["id"] == row["id"]]
        if orig_row.empty:
            continue
        patch = {}
        for col in edit_cols:
            if col not in edited.columns:
                continue
            new_val = row[col] if pd.notna(row[col]) and row[col] != "" else None
            old_val = orig_row.iloc[0][col] if col in orig_row.columns else None
            old_val = old_val if pd.notna(old_val) and old_val != "" else None  # type: ignore[assignment]
            if new_val != old_val:
                patch[col] = new_val
        if patch:
            get_client().table("exercise").update(patch).eq("id", int(row["id"])).execute()
            changed += 1
    return changed


def save_sessions(original: pd.DataFrame, edited: pd.DataFrame):
    changed = 0
    for _, row in edited.iterrows():
        orig_row = original[original["id"] == row["id"]]
        if orig_row.empty:
            continue
        new_val = row["title_fa"] if pd.notna(row["title_fa"]) and row["title_fa"] != "" else None
        old_val = orig_row.iloc[0].get("title_fa")
        old_val = old_val if pd.notna(old_val) and old_val != "" else None  # type: ignore[assignment]
        if new_val != old_val:
            get_client().table("training_session").update({"title_fa": new_val}).eq("id", int(row["id"])).execute()
            changed += 1
    return changed


# ── Page: Exercises ───────────────────────────────────────────────────────────

def page_exercises():
    st.header("Exercises")
    st.caption("Edit Farsi names, English gloss, and media metadata. Click **Save changes** when done.")

    if st.button("↺ Reload from database", key="reload_ex"):
        st.cache_data.clear()

    @st.cache_data(ttl=60)
    def _load():
        return load_exercises()

    df = _load()

    # Columns to display in the editor
    display_cols = ["id", "name", "repetitions", "duration_seconds",
                    "title_fa", "gloss", "media_type", "media_src", "media_poster"]
    display_cols = [c for c in display_cols if c in df.columns]

    column_config = {
        "id":               st.column_config.NumberColumn("ID", disabled=True, width="small"),
        "name":             st.column_config.TextColumn("Name (Latin)", disabled=True, width="medium"),
        "repetitions":      st.column_config.NumberColumn("Default reps", disabled=True, width="small"),
        "duration_seconds": st.column_config.NumberColumn("Duration (s)", width="small"),
        "title_fa":         st.column_config.TextColumn("Farsi title", width="medium"),
        "gloss":            st.column_config.TextColumn("Gloss (English description)", width="large"),
        "media_type":       st.column_config.SelectboxColumn("Media type", options=MEDIA_TYPES, width="small"),
        "media_src":        st.column_config.TextColumn("Media URL", width="large"),
        "media_poster":     st.column_config.TextColumn("Poster URL (video only)", width="large"),
    }

    edited = st.data_editor(
        df[display_cols],
        column_config=column_config,
        use_container_width=True,
        hide_index=True,
        num_rows="fixed",
        key="exercise_editor",
    )

    col1, col2 = st.columns([1, 5])
    with col1:
        if st.button("💾 Save changes", type="primary", key="save_ex"):
            with st.spinner("Saving…"):
                n = save_exercises(df, edited)
            if n:
                st.success(f"Updated {n} exercise(s).")
                st.cache_data.clear()
            else:
                st.info("No changes detected.")

    # Live preview of media URLs
    st.divider()
    st.subheader("Media preview")
    preview_rows = edited[
        edited["media_type"].isin(["photo", "video"]) &
        edited["media_src"].notna() &
        (edited["media_src"] != "")
    ]
    if preview_rows.empty:
        st.caption("No exercises with media URLs yet.")
    else:
        cols = st.columns(min(4, len(preview_rows)))
        for i, (_, row) in enumerate(preview_rows.iterrows()):
            with cols[i % 4]:
                label = row.get("title_fa") or row["name"]
                st.caption(label)
                if row["media_type"] == "photo":
                    try:
                        st.image(row["media_src"], use_container_width=True)
                    except Exception:
                        st.text(row["media_src"])
                else:
                    st.markdown(f"🎬 [{row['name']}]({row['media_src']})")


# ── Page: Sessions ────────────────────────────────────────────────────────────

def page_sessions():
    st.header("Training Sessions")
    st.caption("Add Farsi titles for the session cards.")

    if st.button("↺ Reload", key="reload_sess"):
        st.cache_data.clear()

    @st.cache_data(ttl=60)
    def _load():
        return load_sessions()

    df = _load()
    display_cols = ["id", "title", "difficulty", "is_user_created", "title_fa"]
    display_cols = [c for c in display_cols if c in df.columns]

    column_config = {
        "id":              st.column_config.NumberColumn("ID", disabled=True, width="small"),
        "title":           st.column_config.TextColumn("Title", disabled=True, width="large"),
        "difficulty":      st.column_config.NumberColumn("Difficulty", disabled=True, width="small"),
        "is_user_created": st.column_config.CheckboxColumn("User-created", disabled=True, width="small"),
        "title_fa":        st.column_config.TextColumn("Farsi title", width="large"),
    }

    edited = st.data_editor(
        df[display_cols],
        column_config=column_config,
        use_container_width=True,
        hide_index=True,
        num_rows="fixed",
        key="session_editor",
    )

    col1, _ = st.columns([1, 5])
    with col1:
        if st.button("💾 Save changes", type="primary", key="save_sess"):
            with st.spinner("Saving…"):
                n = save_sessions(df, edited)
            if n:
                st.success(f"Updated {n} session(s).")
                st.cache_data.clear()
            else:
                st.info("No changes detected.")


# ── Page: Session builder ─────────────────────────────────────────────────────

def page_session_builder():
    st.header("Session Builder")
    st.caption("Inspect which exercises are in each session, and their rep prescriptions.")

    @st.cache_data(ttl=60)
    def _load():
        exercises = load_exercises().set_index("id")
        sessions  = load_sessions().set_index("id")
        items     = load_items()
        return exercises, sessions, items

    exercises, sessions, items = _load()

    session_options = {row["title"]: sid for sid, row in sessions.iterrows()}
    chosen_title = st.selectbox("Session", list(session_options.keys()))
    if not chosen_title:
        return

    sid = session_options[chosen_title]
    session_items = items[items["training_session_id"] == sid].sort_values("position")

    if session_items.empty:
        st.warning("No items found for this session.")
        return

    rows = []
    total_seconds = 0
    for _, item in session_items.iterrows():
        ex = exercises.loc[item["exercise_id"]] if item["exercise_id"] in exercises.index else None
        name    = ex["name"] if ex is not None else f"(exercise {item['exercise_id']})"
        fa      = ex["title_fa"] if ex is not None and pd.notna(ex.get("title_fa")) else "—"
        dur     = int(ex["duration_seconds"]) if ex is not None and pd.notna(ex.get("duration_seconds")) else None
        def_rep = int(ex["repetitions"]) if ex is not None and pd.notna(ex.get("repetitions")) else 1
        reps    = int(item["reps_to_do"])
        if dur and def_rep:
            track_dur = round(dur / def_rep * reps)
            total_seconds += track_dur
            dur_str = f"{track_dur}s"
        else:
            dur_str = "—"
        rows.append({
            "Pos": int(item["position"]),
            "Exercise": name,
            "Farsi": fa,
            "Default reps": def_rep,
            "Prescribed reps": reps,
            "Custom": "🟠" if reps != def_rep else "🟢",
            "Track duration": dur_str,
        })

    st.dataframe(pd.DataFrame(rows), use_container_width=True, hide_index=True)

    mins = total_seconds // 60
    secs = total_seconds % 60
    st.metric("Total session duration", f"{mins}m {secs}s" if secs else f"{mins}m")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    st.set_page_config(
        page_title="Pahlevani Admin",
        page_icon="🏛️",
        layout="wide",
    )

    st.title("🏛️ Pahlevani Admin")
    st.caption(f"Connected to `{SUPABASE_URL.split('//')[1].split('.')[0]}` · Supabase")

    tab_ex, tab_sess, tab_builder = st.tabs([
        "Exercises",
        "Sessions",
        "Session Builder",
    ])

    with tab_ex:
        page_exercises()
    with tab_sess:
        page_sessions()
    with tab_builder:
        page_session_builder()


if __name__ == "__main__":
    main()
