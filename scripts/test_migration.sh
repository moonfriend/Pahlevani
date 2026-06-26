#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
# Pahlevani DB migration test runner
#
# Applies migration files in sequence to an isolated postgres:15 Docker
# container, then runs data layer tests. No live Supabase connection needed.
#
# Usage:
#   bash scripts/test_migration.sh
#     → Baseline only: applies 0001_initial_schema.sql + seed, runs tests.
#       Use this to confirm the data layer is healthy against the current schema.
#
#   bash scripts/test_migration.sh supabase/migrations/0002_app_release_gate.sql
#     → Baseline, then applies the given migration, then re-tests.
#       All green = safe to apply that migration to production.
#
# Prerequisites:
#   - Docker running
#   - psycopg2:  pip3 install -r scripts/db/requirements.txt
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATION_FILE="${1:-}"
CONTAINER="pahlevani_migration_test"
PG_PORT=54399
PG_PASS="pahlevani_test"
DSN="postgresql://postgres:${PG_PASS}@localhost:${PG_PORT}/postgres"
TEST_SCRIPT="${REPO_ROOT}/scripts/db/test_data_layer.py"
BASELINE="${REPO_ROOT}/supabase/migrations/0001_initial_schema.sql"
SEED="${REPO_ROOT}/supabase/seed.sql"

red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n'   "$*"; }
info()  { printf '\033[0;34m▶  %s\033[0m\n' "$*"; }

cleanup() {
  info "Stopping test container..."
  docker stop "${CONTAINER}" >/dev/null 2>&1 || true
  docker rm   "${CONTAINER}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# ── preflight ─────────────────────────────────────────────────────────────
bold ""
bold "════════════════════════════════════════════════"
bold " Pahlevani — DB migration test"
bold "════════════════════════════════════════════════"

if ! docker info &>/dev/null; then
  red "❌  Docker daemon is not running."; exit 1
fi
if ! python3 -c "import psycopg2" &>/dev/null; then
  red "❌  psycopg2 not installed. Run: pip3 install -r scripts/db/requirements.txt"; exit 1
fi
if [[ ! -f "${BASELINE}" ]]; then
  red "❌  Missing baseline migration: ${BASELINE}"; exit 1
fi

# ── start container ───────────────────────────────────────────────────────
info "Starting isolated postgres:15 container (port ${PG_PORT})..."
docker stop "${CONTAINER}" >/dev/null 2>&1 || true
docker rm   "${CONTAINER}" >/dev/null 2>&1 || true
docker run \
  --name "${CONTAINER}" --detach \
  --publish "${PG_PORT}:5432" \
  --env POSTGRES_PASSWORD="${PG_PASS}" \
  postgres:15 >/dev/null

info "Waiting for PostgreSQL..."
for i in $(seq 1 30); do
  docker exec "${CONTAINER}" pg_isready -U postgres -q 2>/dev/null && break
  [[ $i -eq 30 ]] && { red "❌  PostgreSQL did not start in 30s."; exit 1; }
  sleep 1
done
green "✅  Container ready."

# ── apply baseline schema ─────────────────────────────────────────────────
info "Applying baseline schema (0001_initial_schema.sql)..."
docker exec -i "${CONTAINER}" psql -U postgres -d postgres -q < "${BASELINE}"
green "✅  Baseline schema applied."

[[ -f "${SEED}" ]] && {
  info "Seeding test data..."
  docker exec -i "${CONTAINER}" psql -U postgres -d postgres -q < "${SEED}"
  green "✅  Seed data applied."
}

# ── Phase A ───────────────────────────────────────────────────────────────
bold ""
bold "── Phase A: data layer tests (baseline schema) ─────────────"
if python3 "${TEST_SCRIPT}" "${DSN}"; then
  green "✅  Phase A passed."
else
  red "❌  Phase A FAILED."
  exit 1
fi

[[ -z "${MIGRATION_FILE}" ]] && {
  bold ""
  bold "════════════════════════════════════════════════"
  green "✅  Done. No migration to test."
  exit 0
}

# ── Phase B ───────────────────────────────────────────────────────────────
MIGRATION_PATH="${MIGRATION_FILE}"
[[ "${MIGRATION_FILE}" != /* ]] && MIGRATION_PATH="${REPO_ROOT}/${MIGRATION_FILE}"
[[ ! -f "${MIGRATION_PATH}" ]] && { red "❌  File not found: ${MIGRATION_FILE}"; exit 1; }

bold ""
bold "── Applying $(basename "${MIGRATION_PATH}") ─────────────────"
docker exec -i "${CONTAINER}" psql -U postgres -d postgres -q < "${MIGRATION_PATH}"
green "✅  Migration applied."

bold ""
bold "── Phase B: data layer tests (post-migration) ──────────────"
if python3 "${TEST_SCRIPT}" "${DSN}"; then
  green "✅  Phase B passed."
else
  red "❌  Phase B FAILED — migration broke the data layer."
  exit 1
fi

bold ""
bold "════════════════════════════════════════════════"
green "✅  Safe to apply $(basename "${MIGRATION_PATH}") to production."
