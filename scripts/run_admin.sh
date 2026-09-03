#!/usr/bin/env bash
# Launches the Streamlit admin tool with admin-tier credentials from the
# vault. See scripts/with_admin_creds.sh for the sourcing mechanism.
#
# Usage:
#   bash scripts/run_admin.sh                              # the admin UI
#   bash scripts/run_admin.sh --script compress_images.py  # any other script
#   PAHLEVANI_ENV=staging bash scripts/run_admin.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ "${1:-}" == "--script" ]]; then
  exec bash "$DIR/with_admin_creds.sh" uv run --project "$DIR" python "$DIR/${2:?script name required}"
fi

exec bash "$DIR/with_admin_creds.sh" uv run --project "$DIR" streamlit run "$DIR/admin.py"
