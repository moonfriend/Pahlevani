#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# Pahlevani DB migration test runner
#
# What it does:
#   1. Spins up an isolated postgres:15 Docker container (matches Supabase's PG
#      major version; entirely separate from any running Supabase instance).
#   2. Applies the baseline schema (0001_initial_schema.sql) + seed data.
#   3. Runs Phase A assertions: verifies the 4-table production schema is intact.
#   4. Auto-detects "pending" migrations (SQL files in supabase/migrations/ that
#      exist in the current branch but NOT in origin/main).
#   5. For each pending migration: applies it, then runs its matching test file
#      from scripts/db/ (test_migration_<name>.py where <name> matches the
#      migration file stem).
#   6. On overall success, touches supabase/.migration_test_ok so the git
#      pre-push hook knows the tests passed.
#   7. Stops the container (unless --keep-running is passed).
#
# Usage:
#   scripts/test_migration.sh                 # auto-detect pending migrations
#   scripts/test_migration.sh --keep-running  # leave DB up for manual Flutter testing
#   scripts/test_migration.sh --skip-pending  # baseline only, ignore pending
#   scripts/test_migration.sh --help
#
# Prerequisites (one-time setup):
#   - Docker running (already confirmed on this machine)
#   - psycopg2 installed:  pip3 install -r scripts/db/requirements.txt
#     Or run scripts/install_dev_hooks.sh which does this for you.
#
# Local Supabase URL for manual Flutter testing (with --keep-running):
#   docker exec pahlevani_migration_test psql -U postgres -c "\dt public.*"
#   Connection string: postgresql://postgres:pahlevani_test@localhost:54399/postgres
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── config ────────────────────────────────────────────────────────────────
CONTAINER_NAME="pahlevani_migration_test"
PG_PORT=54399
PG_PASSWORD="pahlevani_test"
PG_IMAGE="postgres:15"
DSN="postgresql://postgres:${PG_PASSWORD}@localhost:${PG_PORT}/postgres"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIGRATIONS_DIR="${REPO_ROOT}/supabase/migrations"
SEED_FILE="${REPO_ROOT}/supabase/seed.sql"
TESTS_DIR="${REPO_ROOT}/scripts/db"
SENTINEL="${REPO_ROOT}/supabase/.migration_test_ok"

KEEP_RUNNING=false
SKIP_PENDING=false

# ── parse args ────────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --keep-running) KEEP_RUNNING=true ;;
    --skip-pending) SKIP_PENDING=true ;;
    --help)
      grep '^#' "${BASH_SOURCE[0]}" | sed 's/^# \?//' | head -30
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg  (use --help)" >&2
      exit 1
      ;;
  esac
done

# ── helpers ───────────────────────────────────────────────────────────────
red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }
green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
info()  { printf '\033[0;34m▶  %s\033[0m\n' "$*"; }
ok()    { green "✅  $*"; }
fail()  { red   "❌  $*"; }

cleanup() {
  if [[ "$KEEP_RUNNING" == true ]]; then
    echo ""
    bold "Container left running (--keep-running)."
    echo "  DSN:       ${DSN}"
    echo "  Stop with: docker stop ${CONTAINER_NAME}"
    return
  fi
  info "Stopping test container..."
  docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# ── preflight checks ──────────────────────────────────────────────────────
bold ""
bold "═══════════════════════════════════════════════════"
bold " Pahlevani — DB migration test"
bold "═══════════════════════════════════════════════════"

if ! command -v docker &>/dev/null; then
  fail "Docker not found. Install Docker Desktop or Docker Engine."
  exit 1
fi
if ! docker info &>/dev/null; then
  fail "Docker daemon is not running. Start it first."
  exit 1
fi
if ! python3 -c "import psycopg2" &>/dev/null; then
  fail "psycopg2 not installed. Run:  pip3 install -r scripts/db/requirements.txt"
  exit 1
fi

# ── start container ───────────────────────────────────────────────────────
info "Starting isolated postgres:15 container..."

# Stop any lingering container from a previous crashed run.
docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
docker rm   "${CONTAINER_NAME}" >/dev/null 2>&1 || true

docker run \
  --name "${CONTAINER_NAME}" \
  --detach \
  --publish "${PG_PORT}:5432" \
  --env POSTGRES_PASSWORD="${PG_PASSWORD}" \
  "${PG_IMAGE}" \
  >/dev/null

# Wait for PG to accept connections (up to 30 seconds).
info "Waiting for PostgreSQL to be ready..."
WAIT=0
until docker exec "${CONTAINER_NAME}" pg_isready -U postgres -q 2>/dev/null; do
  WAIT=$((WAIT + 1))
  if [[ $WAIT -gt 30 ]]; then
    fail "PostgreSQL did not become ready within 30 seconds."
    exit 1
  fi
  sleep 1
done
ok "PostgreSQL ready."

# ── apply baseline schema (0001) ──────────────────────────────────────────
info "Applying baseline schema (0001_initial_schema.sql)..."
BASELINE="${MIGRATIONS_DIR}/0001_initial_schema.sql"
if [[ ! -f "$BASELINE" ]]; then
  fail "Missing: ${BASELINE}"
  echo "  Reconstruct from production: supabase db dump --schema public -f supabase/migrations/0001_initial_schema.sql"
  exit 1
fi
docker exec -i "${CONTAINER_NAME}" \
  psql -U postgres -d postgres \
  < "${BASELINE}"
ok "Baseline schema applied."

# ── seed ──────────────────────────────────────────────────────────────────
if [[ -f "${SEED_FILE}" ]]; then
  info "Seeding test data..."
  docker exec -i "${CONTAINER_NAME}" \
    psql -U postgres -d postgres \
    < "${SEED_FILE}"
  ok "Seed data applied."
fi

# ── Phase A: baseline assertions ──────────────────────────────────────────
bold ""
bold "── Phase A: Baseline schema assertions ──────────────────"
if python3 "${TESTS_DIR}/test_baseline.py" "${DSN}"; then
  ok "Phase A passed."
else
  fail "Phase A FAILED — baseline schema does not match expectations."
  echo "  Check supabase/migrations/0001_initial_schema.sql against production."
  exit 1
fi

# ── detect pending migrations ─────────────────────────────────────────────
if [[ "$SKIP_PENDING" == true ]]; then
  ok "Skipping pending migration check (--skip-pending)."
  touch "${SENTINEL}"
  exit 0
fi

# "Pending" = migration files that exist here but not in origin/main.
# Works on feature branches; on main itself, PENDING will be empty (correct).
PENDING=()
if git -C "${REPO_ROOT}" remote get-url origin &>/dev/null 2>&1; then
  # Fetch remote refs without modifying the working tree.
  git -C "${REPO_ROOT}" fetch origin main --quiet 2>/dev/null || true
  while IFS= read -r file; do
    [[ -n "$file" ]] && PENDING+=("${REPO_ROOT}/${file}")
  done < <(git -C "${REPO_ROOT}" diff origin/main HEAD --name-only --diff-filter=A -- 'supabase/migrations/*.sql' 2>/dev/null || true)
fi

if [[ ${#PENDING[@]} -eq 0 ]]; then
  bold ""
  bold "── No pending migrations detected ───────────────────────"
  ok "All migrations match origin/main. Nothing to validate."
  touch "${SENTINEL}"
  exit 0
fi

bold ""
bold "── Pending migrations detected: ${#PENDING[@]} file(s) ──"
for f in "${PENDING[@]}"; do
  echo "   • $(basename "$f")"
done

# ── Phase B: apply + test each pending migration ──────────────────────────
ALL_PASSED=true
for migration_path in "${PENDING[@]}"; do
  migration_file="$(basename "$migration_path")"
  # Strip leading 4-digit timestamp + underscore to get the stem.
  # e.g.  0002_app_release_gate.sql  →  app_release_gate
  stem="${migration_file#[0-9][0-9][0-9][0-9]_}"
  stem="${stem%.sql}"
  test_script="${TESTS_DIR}/test_migration_${stem}.py"

  bold ""
  bold "── Migration: ${migration_file} ─────────────────────────"

  info "Applying ${migration_file}..."
  docker exec -i "${CONTAINER_NAME}" \
    psql -U postgres -d postgres \
    < "${migration_path}"
  ok "Migration applied."

  if [[ -f "${test_script}" ]]; then
    info "Running assertions ($(basename "${test_script}"))..."
    if python3 "${test_script}" "${DSN}"; then
      ok "Phase B passed: ${migration_file}"
    else
      fail "Phase B FAILED: ${migration_file}"
      ALL_PASSED=false
    fi
  else
    printf '\033[0;33m⚠️   No test file found for %s\033[0m\n' "${migration_file}"
    echo "   Create ${test_script} to add assertions for this migration."
    echo "   (Skipping — migration still applied to container for manual inspection.)"
  fi
done

# ── final result ──────────────────────────────────────────────────────────
bold ""
bold "═══════════════════════════════════════════════════"
if [[ "$ALL_PASSED" == true ]]; then
  ok "All migration tests passed."
  touch "${SENTINEL}"
  bold ""
  bold "Safe to apply to production:"
  bold "  Paste each pending migration into the Supabase SQL Editor and run."
  if [[ "$KEEP_RUNNING" == true ]]; then
    bold ""
    bold "Container is still running for manual testing:"
    bold "  flutter run  (app will need LOCAL_SUPABASE_URL set — see docs)"
    bold "  DSN: ${DSN}"
  fi
else
  fail "One or more migration tests FAILED. Fix the issues before pushing."
  exit 1
fi
