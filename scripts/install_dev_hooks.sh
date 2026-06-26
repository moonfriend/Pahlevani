#!/usr/bin/env bash
# One-time local dev setup:
#   1. Installs the psycopg2 Python dependency for DB migration tests.
#   2. Configures git to use the .githooks/ directory for local hooks.
#
# Run once after cloning: bash scripts/install_dev_hooks.sh

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "▶  Installing psycopg2-binary..."
pip3 install -r "${REPO_ROOT}/scripts/db/requirements.txt" --quiet
echo "✅  psycopg2-binary installed."

echo "▶  Configuring git hooks directory..."
git -C "${REPO_ROOT}" config core.hooksPath .githooks
chmod +x "${REPO_ROOT}/.githooks/pre-push"
echo "✅  Git hooks configured (.githooks/pre-push active)."

echo ""
echo "Setup complete. Run scripts/test_migration.sh before pushing migration files."
