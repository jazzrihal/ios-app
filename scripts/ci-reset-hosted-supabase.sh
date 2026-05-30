#!/usr/bin/env bash
# Resets the hosted Supabase test project, then applies the backend seed.sql.
set -euo pipefail

: "${CI_SUPABASE_DB_URL:?CI_SUPABASE_DB_URL must be set}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESET_SQL_FILE="$ROOT/scripts/ci-reset-hosted-supabase.sql"
BACKEND_SEED_SQL="${BACKEND_SEED_SQL:-}"
PSQL_BIN="${PSQL_BIN:-}"

if [ -z "$BACKEND_SEED_SQL" ]; then
  if [ -f "$ROOT/ios-app-backend/supabase/seed.sql" ]; then
    BACKEND_SEED_SQL="$ROOT/ios-app-backend/supabase/seed.sql"
  elif [ -f "$ROOT/ios-app-backend/seed.sql" ]; then
    BACKEND_SEED_SQL="$ROOT/ios-app-backend/seed.sql"
  else
    echo "Backend seed SQL not found under ios-app-backend." >&2
    exit 1
  fi
elif [ ! -f "$BACKEND_SEED_SQL" ]; then
  echo "Backend seed SQL not found at $BACKEND_SEED_SQL" >&2
  exit 1
fi

if [ -z "$PSQL_BIN" ]; then
  if command -v psql >/dev/null 2>&1; then
    PSQL_BIN="$(command -v psql)"
  elif [ -x /opt/homebrew/opt/libpq/bin/psql ]; then
    PSQL_BIN=/opt/homebrew/opt/libpq/bin/psql
  elif [ -x /usr/local/opt/libpq/bin/psql ]; then
    PSQL_BIN=/usr/local/opt/libpq/bin/psql
  else
    echo "psql not found. Install libpq or set PSQL_BIN." >&2
    exit 1
  fi
fi

PGSSLMODE="${PGSSLMODE:-require}" "$PSQL_BIN" "$CI_SUPABASE_DB_URL" \
  --set ON_ERROR_STOP=1 \
  --file "$RESET_SQL_FILE"

PGSSLMODE="${PGSSLMODE:-require}" "$PSQL_BIN" "$CI_SUPABASE_DB_URL" \
  --set ON_ERROR_STOP=1 \
  --file "$BACKEND_SEED_SQL"

echo "Hosted Supabase test data reset and backend seed applied."
