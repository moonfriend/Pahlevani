#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# Pahlevani DB migration test runner
#
# Pulls the current production schema from Supabase, applies it to an isolated
# postgres:15 Docker container, runs data layer tests against it, then
# optionally applies a migration file and re-runs the tests.
#
# Usage:
#   bash scripts/test_migration.sh
#     → Baseline check only: is the current data layer working against prod schema?
#
#   bash scripts/test_migration.sh supabase/migrations/0002_app_release_gate.sql
#     → Baseline check, then apply the migration, then re-check.
#       All green = safe to apply the migration to production.
#
# Prerequisites:
#   1. Docker running (docker ps should work)
#   2. psycopg2:  pip3 install -r scripts/db/requirements.txt
#   3. Supabase DB credentials in supabase/.db.env  (copy from .db.env.example)
#
# The postgres:15 image is downloaded once on first run and cached by Docker.
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATION_FILE="${1:-}"
CONTAINER="pahlevani_migration_test"
PG_PORT=54399
PG_PASS="pahlevani_test"
DSN="postgresql://postgres:${PG_PASS}@localhost:${PG_PORT}/postgres"
TEST_SCRIPT="${REPO_ROOT}/scripts/db/test_data_layer.py"
DB_ENV="${REPO_ROOT}/supabase/.db.env"
SEED="${REPO_ROOT}/supabase/seed.sql"

# ── colour helpers ────────────────────────────────────────────────────────
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n'   "$*"; }
info()   { printf '\033[0;34m▶  %s\033[0m\n' "$*"; }

cleanup() {
  info "Stopping test container..."
  docker stop "${CONTAINER}" >/dev/null 2>&1 || true
  docker rm   "${CONTAINER}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# ── preflight ─────────────────────────────────────────────────────────────
bold ""
bold "═══════════════════════════════════════════════════════════════"
bold " Pahlevani — DB migration test"
bold "═══════════════════════════════════════════════════════════════"

if ! docker info &>/dev/null; then
  red "❌  Docker daemon is not running."; exit 1
fi
if ! python3 -c "import psycopg2" &>/dev/null; then
  red "❌  psycopg2 not installed.  Run: pip3 install -r scripts/db/requirements.txt"; exit 1
fi
if [[ ! -f "${DB_ENV}" ]]; then
  red "❌  supabase/.db.env not found."
  echo "   Copy supabase/.db.env.example → supabase/.db.env and fill in your"
  echo "   Supabase DB credentials (Dashboard → Settings → Database)."
  exit 1
fi

# shellcheck disable=SC1090
source "${DB_ENV}"
if [[ -z "${SUPABASE_DB_HOST:-}" || -z "${SUPABASE_DB_PASSWORD:-}" ]]; then
  red "❌  SUPABASE_DB_HOST or SUPABASE_DB_PASSWORD not set in supabase/.db.env"; exit 1
fi

# ── start container ───────────────────────────────────────────────────────
info "Starting isolated postgres:15 container (port ${PG_PORT})..."
docker stop "${CONTAINER}" >/dev/null 2>&1 || true
docker rm   "${CONTAINER}" >/dev/null 2>&1 || true
docker run \
  --name "${CONTAINER}" \
  --detach \
  --publish "${PG_PORT}:5432" \
  --env POSTGRES_PASSWORD="${PG_PASS}" \
  postgres:15 \
  >/dev/null

info "Waiting for PostgreSQL to accept connections..."
for i in $(seq 1 30); do
  docker exec "${CONTAINER}" pg_isready -U postgres -q 2>/dev/null && break
  [[ $i -eq 30 ]] && { red "❌  PostgreSQL did not start in 30s."; exit 1; }
  sleep 1
done
green "✅  Container ready."

# ── pull production schema from Supabase ──────────────────────────────────
info "Pulling production schema from Supabase (${SUPABASE_DB_HOST})..."
SUPABASE_PG_URL="postgresql://postgres:${SUPABASE_DB_PASSWORD}@${SUPABASE_DB_HOST}:5432/postgres"

SCHEMA_SQL=$(
  docker run --rm postgres:15 \
    pg_dump \
      --schema-only \
      --schema=public \
      --no-owner \
      --no-acl \
      "${SUPABASE_PG_URL}" 2>/dev/null \
  | grep -v "^-- Dumped" \
  | grep -v "^SET " \
  | grep -v "^SELECT pg_catalog"
) || {
  red "❌  pg_dump failed. Check that SUPABASE_DB_HOST and SUPABASE_DB_PASSWORD are correct."
  echo "   Test the connection string manually:"
  echo "   docker run --rm postgres:15 psql '${SUPABASE_PG_URL}' -c '\\dt public.*'"
  exit 1
}

echo "${SCHEMA_SQL}" | docker exec -i "${CONTAINER}" psql -U postgres -d postgres -q
green "✅  Production schema applied."

# ── seed test data ─────────────────────────────────────────────────────────
if [[ -f "${SEED}" ]]; then
  info "Seeding test data..."
  docker exec -i "${CONTAINER}" psql -U postgres -d postgres -q < "${SEED}"
  green "✅  Seed data applied."
fi

# ── Phase A: data layer tests on current prod schema ──────────────────────
bold ""
bold "── Phase A: data layer tests (current production schema) ──────"
if python3 "${TEST_SCRIPT}" "${DSN}"; then
  green "✅  Phase A: all data layer functions pass."
else
  red "❌  Phase A FAILED — current production schema does not satisfy the data layer."
  exit 1
fi

# ── Phase B: apply migration + re-test ────────────────────────────────────
if [[ -z "${MIGRATION_FILE}" ]]; then
  bold ""
  bold "═══════════════════════════════════════════════════════════════"
  green "✅  Done. No migration file given — baseline only."
  exit 0
fi

if [[ ! -f "${REPO_ROOT}/${MIGRATION_FILE}" ]] && [[ ! -f "${MIGRATION_FILE}" ]]; then
  red "❌  Migration file not found: ${MIGRATION_FILE}"; exit 1
fi
MIGRATION_PATH="${MIGRATION_FILE}"
[[ "${MIGRATION_FILE}" != /* ]] && MIGRATION_PATH="${REPO_ROOT}/${MIGRATION_FILE}"

bold ""
bold "── Phase B: applying $(basename "${MIGRATION_PATH}") ──────────"
info "Applying migration..."
docker exec -i "${CONTAINER}" psql -U postgres -d postgres -q < "${MIGRATION_PATH}"
green "✅  Migration applied."

bold ""
bold "── Phase B: data layer tests (post-migration) ─────────────────"
if python3 "${TEST_SCRIPT}" "${DSN}"; then
  green "✅  Phase B: all data layer functions still pass."
else
  red "❌  Phase B FAILED — migration broke one or more data layer functions."
  exit 1
fi

bold ""
bold "═══════════════════════════════════════════════════════════════"
green "✅  All tests passed. Safe to apply $(basename "${MIGRATION_PATH}") to production."
bold "   Paste it into the Supabase SQL Editor and run."
