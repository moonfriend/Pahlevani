"""
Challenge Bot Admin — browse and manage Telegram group-challenge data, and
author ASCII-art "story" templates.

Run:
    cd challenge_bot
    uv run streamlit run bot_admin.py

Credentials (required — use the service-role key, not the anon key):
  env vars, or challenge_bot/.env: SUPABASE_URL  SUPABASE_KEY
"""

import pandas as pd
import streamlit as st
from postgrest.exceptions import APIError
from supabase import Client, create_client

from ascii_progress import default_fill_order, offsets_of_fillable_cells, render_order_preview
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


@st.cache_data(ttl=30)
def load_stories() -> pd.DataFrame:
    rows = get_client().table("challenge_story").select("*").order("created_at", desc=True).execute().data
    return pd.DataFrame(rows)


st.title("Challenge Bot — Admin")

tab_challenges, tab_stories = st.tabs(["Challenges", "Stories"])

with tab_challenges:
    challenges = load_challenges()

    if challenges.empty:
        st.info("No challenges yet.")
    else:
        totals = totals_by_challenge(tuple(challenges["id"].tolist()))
        challenges["total"] = challenges["id"].map(totals).fillna(0).astype(int)

        stories_for_labels = load_stories()
        if not stories_for_labels.empty:
            slug_by_story_id = stories_for_labels.set_index("id")["slug"]
            challenges["story_slug"] = challenges["story_id"].map(slug_by_story_id)
        else:
            challenges["story_slug"] = None

        st.subheader("Challenges")
        st.dataframe(
            challenges[
                ["id", "chat_id", "title", "story_slug", "target_amount", "unit", "status", "total", "created_at"]
            ],
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
                    [
                        "id",
                        "telegram_user_id",
                        "telegram_username",
                        "amount",
                        "source",
                        "raw_message_text",
                        "created_at",
                    ]
                ],
                use_container_width=True,
                hide_index=True,
            )

with tab_stories:
    stories = load_stories()

    st.subheader("Stories")
    if stories.empty:
        st.info("No stories yet.")
    else:
        st.dataframe(
            stories[["id", "slug", "title", "created_at"]],
            use_container_width=True,
            hide_index=True,
        )

    st.subheader("Create a story")

    template = st.text_area("Template (use '=' for fillable cells)", height=200, key="story_template")
    fillable_count = len(offsets_of_fillable_cells(template))
    st.caption(f"{fillable_count} fillable '=' cells detected.")

    slug = st.text_input("Slug", key="story_slug")
    title = st.text_input("Title", key="story_title")
    story_text = st.text_area("Story text", key="story_text")
    complete_art = st.text_area("Completion art (optional)", key="story_complete_art")

    preset = st.radio(
        "Fill order",
        ["Reading order", "Reverse (bottom-up)", "Custom"],
        key="story_fill_order_preset",
    )

    default_order = default_fill_order(template)
    fill_order: list[int] = []
    if preset == "Reading order":
        fill_order = default_order
    elif preset == "Reverse (bottom-up)":
        fill_order = list(reversed(default_order))
    else:
        custom_text = st.text_input(
            "Custom order (comma-separated occurrence numbers, 0-based)",
            key="story_fill_order_custom",
        )
        try:
            fill_order = [int(token.strip()) for token in custom_text.split(",") if token.strip()]
        except ValueError:
            st.warning("Custom order must be a comma-separated list of numbers.")

    if template and fillable_count > 0:
        try:
            st.text(render_order_preview(template, fill_order))
        except (IndexError, KeyError):
            st.warning("Fill order doesn't match the template yet — keep editing.")

    if st.button("Save story"):
        if not slug or not title or not story_text or not template:
            st.error("Slug, title, story text, and template are all required.")
        elif sorted(fill_order) != list(range(fillable_count)):
            st.error(
                f"Fill order must be a permutation of 0..{fillable_count - 1} "
                f"(the template has {fillable_count} fillable '=' cells)."
            )
        else:
            try:
                get_client().table("challenge_story").insert(
                    {
                        "slug": slug,
                        "title": title,
                        "story_text": story_text,
                        "template": template,
                        "complete_art": complete_art or None,
                        "fill_order": fill_order,
                    }
                ).execute()
            except APIError as error:
                if error.code == "23505":
                    st.error(f"Slug '{slug}' is already in use — pick a different one.")
                else:
                    raise
            else:
                st.success(f"Story '{slug}' saved.")
                st.cache_data.clear()
                st.rerun()
