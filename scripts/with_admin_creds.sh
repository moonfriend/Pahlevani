#!/usr/bin/env bash
# Sources admin-tier Supabase/R2 credentials from the vault, then execs
# whatever command was passed — nothing is persisted inside the repo tree.
# Shared by scripts/run_admin.sh, challenge_bot/run.sh, and any of the
# scripts/*.py one-off tools that need the service-role key or R2 writes.
#
# Usage: bash scripts/with_admin_creds.sh <command> [args...]
#   PAHLEVANI_ENV=staging bash scripts/with_admin_creds.sh uv run python scripts/dump_supabase.py
set -euo pipefail

ENV_NAME="${PAHLEVANI_ENV:-production}"
CREDS_DIR="${PAHLEVANI_CREDS_DIR:-$HOME/StudioProjects/pahlevani-admin-creds}"
CREDS_FILE="$CREDS_DIR/$ENV_NAME.env"

if [[ ! -f "$CREDS_FILE" ]]; then
  echo "Missing $CREDS_FILE — expected admin-tier credentials there." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$CREDS_FILE"
set +a

exec "$@"
