#!/usr/bin/env bash
# Launches the Telegram challenge bot (or its Streamlit admin tool, with
# --admin) with admin-tier Supabase credentials from the vault. See
# scripts/with_admin_creds.sh for the sourcing mechanism. The Telegram token
# itself comes from env/challenge_bot.env (loaded by config.py directly, not
# vault-sourced — see CLAUDE.md's Credentials Setup section).
#
# Usage:
#   bash challenge_bot/run.sh            # run the bot
#   bash challenge_bot/run.sh --admin    # run its Streamlit admin tool
#   PAHLEVANI_ENV=staging bash challenge_bot/run.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
CREDS_SCRIPT="$DIR/../scripts/with_admin_creds.sh"

if [[ "${1:-}" == "--admin" ]]; then
  exec bash "$CREDS_SCRIPT" uv run --project "$DIR" streamlit run "$DIR/bot_admin.py"
fi

exec bash "$CREDS_SCRIPT" uv run --project "$DIR" python "$DIR/main.py"
