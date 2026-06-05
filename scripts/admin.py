"""
Pahlevani Admin — data-entry tool for the exercise and session library.

Run:
    cd scripts
    uv run streamlit run admin.py

Credentials (pick any one):
  1. Set env vars:  SUPABASE_URL  SUPABASE_KEY
  2. Create .streamlit/secrets.toml with those two keys
  3. Nothing — falls back to the public anon key from config.dart (read-only writes may fail)
"""

import os
import pandas as pd
import streamlit as st
from supabase import create_client, Client

# ── Credentials ───────────────────────────────────────────────────────────────

def _secret(key: str) -> str:
    try:
        return st.secrets[key]
    except Exception:
        return ""

SUPABASE_URL = (
    os.getenv("SUPABASE_URL")
    or _secret("SUPABASE_URL")
    or "https://eudjdgjkrhrwvjfkutcg.supabase.co"
)
SUPABASE_KEY = (
    os.getenv("SUPABASE_KEY")
    or _secret("SUPABASE_KEY")
    or (
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        ".eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV1ZGpkZ2prcmhyd3ZqZmt1dGNnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDM5MjI0ODEsImV4cCI6MjA1OTQ5ODQ4MX0"
        ".a7-SBq-NiokUE0eMUCxdwYBqQC0nmRBB5yzMvZFuCjU"
    )
)

# ── DB client ─────────────────────────────────────────────────────────────────

@st.cache_resource
def get_client() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)

# ── Loaders ───────────────────────────────────────────────────────────────────

@st.cache_data(ttl=60)
def load_exercises() -> pd.DataFrame:
    rows = get_client().table("exercise").select("*").order("id").execute().data
    return pd.DataFrame(rows)

@st.cache_data(ttl=60)
def load_sessions() -> pd.DataFrame:
    rows = get_client().table("training_session").select("*").order("id").execute().data
    return pd.DataFrame(rows)

@st.cache_data(ttl=60)
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

def bust_cache():
    load_exercises.clear()
    load_sessions.clear()
    load_items.clear()

# ── Savers ────────────────────────────────────────────────────────────────────

def _changed_rows(original: pd.DataFrame, edited: pd.DataFrame, editable_cols: list[str]) -> list[dict]:
    """Return list of {id, col: new_val} dicts for rows that actually changed."""
    patches = []
    for _, erow in edited.iterrows():
        orow = original[original["id"] == erow["id"]]
        if orow.empty:
            continue
        patch = {}
        for col in editable_cols:
            new = erow[col] if pd.notna(erow[col]) and str(erow[col]).strip() != "" else None
            old = orow.iloc[0][col] if col in orow.columns else None
            old = old if pd.notna(old) and str(old).strip() != "" else None  # type: ignore[assignment]
            if new != old:
                patch[col] = new
        if patch:
            patches.append({"id": int(erow["id"]), **patch})
    return patches

def save_rows(table: str, patches: list[dict]) -> int:
    db = get_client()
    for p in patches:
        row_id = p.pop("id")
        db.table(table).update(p).eq("id", row_id).execute()
    return len(patches)

# ── Tab: Exercises ────────────────────────────────────────────────────────────

def tab_exercises():
    st.header("Exercises")
    st.caption(
        "Edit the Farsi title for each exercise. "
        "Rows with no Farsi name yet show a blank — fill them in and click **Save changes**."
    )

    col_reload, _ = st.columns([1, 8])
    with col_reload:
        if st.button("↺ Reload", key="reload_ex"):
            bust_cache()

    df = load_exercises()

    # Columns to show, in display order
    DISPLAY = ["id", "name", "author", "type", "repetitions", "duration_seconds", "url", "title_fa"]
    display_cols = [c for c in DISPLAY if c in df.columns]

    column_config = {
        "id":               st.column_config.NumberColumn("ID",             disabled=True, width=50),
        "name":             st.column_config.TextColumn("Name",             disabled=True, width=180),
        "author":           st.column_config.TextColumn("Author",           disabled=True, width=140),
        "type":             st.column_config.TextColumn("Type",             disabled=True, width=100),
        "repetitions":      st.column_config.NumberColumn("Default reps",   disabled=True, width=80),
        "duration_seconds": st.column_config.NumberColumn("Duration (s)",   disabled=True, width=90),
        "url":              st.column_config.TextColumn("Audio URL",        disabled=True, width=200),
        "title_fa":         st.column_config.TextColumn("Farsi title ✏️",   width=180),
    }

    edited = st.data_editor(
        df[display_cols].copy(),
        column_config=column_config,
        use_container_width=True,
        hide_index=True,
        num_rows="fixed",
        key="ex_editor",
    )

    col_save, col_status = st.columns([1, 6])
    with col_save:
        if st.button("💾 Save", type="primary", key="save_ex"):
            patches = _changed_rows(df, edited, editable_cols=["title_fa"])
            if patches:
                with st.spinner(f"Saving {len(patches)} row(s)…"):
                    n = save_rows("exercise", patches)
                col_status.success(f"Updated {n} exercise(s).")
                bust_cache()
            else:
                col_status.info("No changes to save.")

    # Progress indicator
    st.divider()
    filled = df["title_fa"].notna().sum() if "title_fa" in df.columns else 0
    total  = len(df)
    st.caption(f"Farsi titles: **{filled} / {total}** filled in")
    st.progress(filled / total if total else 0)

# ── Tab: Sessions ─────────────────────────────────────────────────────────────

def tab_sessions():
    st.header("Training Sessions")
    st.caption("Add a Farsi title to each session — shown on the card banner in the app.")

    col_reload, _ = st.columns([1, 8])
    with col_reload:
        if st.button("↺ Reload", key="reload_sess"):
            bust_cache()

    df = load_sessions()

    DISPLAY = ["id", "title", "difficulty", "description", "title_fa"]
    display_cols = [c for c in DISPLAY if c in df.columns]

    column_config = {
        "id":          st.column_config.NumberColumn("ID",           disabled=True, width=60),
        "title":       st.column_config.TextColumn("Title",          disabled=True, width=220),
        "difficulty":  st.column_config.NumberColumn("Difficulty",   disabled=True, width=80),
        "description": st.column_config.TextColumn("Description",    disabled=True, width=300),
        "title_fa":    st.column_config.TextColumn("Farsi title ✏️", width=180),
    }

    edited = st.data_editor(
        df[display_cols].copy(),
        column_config=column_config,
        use_container_width=True,
        hide_index=True,
        num_rows="fixed",
        key="sess_editor",
    )

    col_save, col_status = st.columns([1, 6])
    with col_save:
        if st.button("💾 Save", type="primary", key="save_sess"):
            patches = _changed_rows(df, edited, editable_cols=["title_fa"])
            if patches:
                with st.spinner(f"Saving {len(patches)} row(s)…"):
                    n = save_rows("training_session", patches)
                col_status.success(f"Updated {n} session(s).")
                bust_cache()
            else:
                col_status.info("No changes to save.")

    filled = df["title_fa"].notna().sum() if "title_fa" in df.columns else 0
    total  = len(df)
    st.caption(f"Farsi titles: **{filled} / {total}** filled in")
    st.progress(filled / total if total else 0)

# ── Tab: Session Builder ──────────────────────────────────────────────────────

def tab_session_builder():
    st.header("Session Inspector")
    st.caption("See the ordered exercises for each session with rep prescriptions and track durations.")

    exercises = load_exercises().set_index("id")
    sessions  = load_sessions()
    items     = load_items()

    if sessions.empty:
        st.warning("No sessions found.")
        return

    options = {f"{row['title']}  (id {sid})": sid for sid, row in sessions.set_index("id").iterrows()}
    choice  = st.selectbox("Session", list(options.keys()))
    if not choice:
        return

    sid   = options[choice]
    s_row = sessions[sessions["id"] == sid].iloc[0]
    s_items = items[items["training_session_id"] == sid].sort_values("position")

    # Session metadata
    c1, c2, c3 = st.columns(3)
    c1.metric("Exercises", len(s_items))
    c2.metric("Difficulty", s_row.get("difficulty", "—"))
    fa = s_row.get("title_fa") or "—"
    c3.metric("Farsi title", fa)

    if s_items.empty:
        st.warning("No items found for this session.")
        return

    rows = []
    total_seconds = 0
    for _, item in s_items.iterrows():
        eid = item["exercise_id"]
        ex  = exercises.loc[eid] if eid in exercises.index else None

        name       = ex["name"]             if ex is not None else f"exercise {eid}"
        title_fa   = (ex.get("title_fa") or "—") if ex is not None else "—"
        dur        = ex.get("duration_seconds") if ex is not None else None
        def_reps   = int(ex["repetitions"])  if ex is not None else 1
        reps_to_do = int(item["reps_to_do"])

        if dur and def_reps:
            track_sec = round(float(dur) / def_reps * reps_to_do)
            total_seconds += track_sec
            dur_str = f"{track_sec}s"
        else:
            dur_str = "—"

        rows.append({
            "#":              int(item["position"]),
            "Exercise":       name,
            "فارسی":          title_fa,
            "Default reps":   def_reps,
            "Prescribed":     reps_to_do,
            "Custom":         "🟠" if reps_to_do != def_reps else "🟢",
            "Track duration": dur_str,
        })

    st.dataframe(pd.DataFrame(rows), use_container_width=True, hide_index=True)

    m, s = divmod(total_seconds, 60)
    st.metric("Estimated session length", f"{m}m {s}s" if s else f"{m}m")

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    st.set_page_config(
        page_title="Pahlevani Admin",
        page_icon="🏛️",
        layout="wide",
    )

    st.title("🏛️  Pahlevani Admin")
    project_id = SUPABASE_URL.split("//")[-1].split(".")[0]
    st.caption(f"Supabase project: `{project_id}`")

    t_ex, t_sess, t_builder = st.tabs(["⚙️ Exercises", "📋 Sessions", "🔍 Session Inspector"])
    with t_ex:      tab_exercises()
    with t_sess:    tab_sessions()
    with t_builder: tab_session_builder()


if __name__ == "__main__":
    main()
