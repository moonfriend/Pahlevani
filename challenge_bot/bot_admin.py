"""
Challenge Bot Admin — browse and manage Telegram group-challenge data.

Run:
    cd challenge_bot
    uv run streamlit run bot_admin.py

Credentials (required — use the service-role key, not the anon key):
  env vars, or challenge_bot/.env: SUPABASE_URL  SUPABASE_KEY
"""

import pandas as pd
import streamlit as st
from supabase import Client, create_client

from config import load_config

st.set_page_config(page_title="Challenge Bot Admin", layout="wide")


@st.cache_resource
def get_client() -> Client:
    try:
        config = load_config()
    except RuntimeError as error:
        st.error(str(error))
        st.stop()
    return create_client(config.supabase_url, config.supabase_key)


@st.cache_data(ttl=30)
def load_challenges() -> pd.DataFrame:
    rows = get_client().table("challenge").select("*").order("created_at", desc=True).execute().data
    return pd.DataFrame(rows)


@st.cache_data(ttl=30)
def load_entries(challenge_id: int) -> pd.DataFrame:
    rows = (
        get_client()
        .table("challenge_entry")
        .select("*")
        .eq("challenge_id", challenge_id)
        .order("created_at", desc=True)
        .execute()
        .data
    )
    return pd.DataFrame(rows)


@st.cache_data(ttl=30)
def totals_by_challenge(challenge_ids: tuple[int, ...]) -> dict[int, int]:
    if not challenge_ids:
        return {}
    rows = (
        get_client()
        .table("challenge_entry")
        .select("challenge_id, amount")
        .in_("challenge_id", list(challenge_ids))
        .execute()
        .data
    )
    totals: dict[int, int] = {}
    for row in rows:
        totals[row["challenge_id"]] = totals.get(row["challenge_id"], 0) + row["amount"]
    return totals


st.title("Challenge Bot — Admin")

challenges = load_challenges()

if challenges.empty:
    st.info("No challenges yet.")
    st.stop()

totals = totals_by_challenge(tuple(challenges["id"].tolist()))
challenges["total"] = challenges["id"].map(totals).fillna(0).astype(int)

st.subheader("Challenges")
st.dataframe(
    challenges[["id", "chat_id", "title", "target_amount", "unit", "status", "total", "created_at"]],
    use_container_width=True,
    hide_index=True,
)

st.subheader("Manage a challenge")
challenge_id = st.selectbox("Challenge ID", challenges["id"].tolist())
selected = challenges[challenges["id"] == challenge_id].iloc[0]

metric_col1, metric_col2, metric_col3 = st.columns(3)
metric_col1.metric("Total", f"{int(selected['total'])} / {selected['target_amount']} {selected['unit']}")
metric_col2.metric("Status", selected["status"])
metric_col3.metric("Chat ID", selected["chat_id"])

if selected["status"] == "active":
    action_col1, action_col2 = st.columns(2)
    if action_col1.button("Mark completed"):
        get_client().table("challenge").update({"status": "completed"}).eq("id", int(challenge_id)).execute()
        st.cache_data.clear()
        st.rerun()
    if action_col2.button("Cancel challenge"):
        get_client().table("challenge").update({"status": "cancelled"}).eq("id", int(challenge_id)).execute()
        st.cache_data.clear()
        st.rerun()

st.subheader("Entries")
entries = load_entries(int(challenge_id))
if entries.empty:
    st.info("No entries logged yet for this challenge.")
else:
    st.dataframe(
        entries[
            ["id", "telegram_user_id", "telegram_username", "amount", "source", "raw_message_text", "created_at"]
        ],
        use_container_width=True,
        hide_index=True,
    )
