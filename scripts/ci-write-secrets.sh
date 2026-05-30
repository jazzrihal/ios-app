#!/usr/bin/env bash
# Writes CameraApp/Secrets.plist for CI.
#
# Usage:
#   ./scripts/ci-write-secrets.sh placeholder   # non-empty dummy values (build / unit tests)
#   ./scripts/ci-write-secrets.sh local         # read API_URL and ANON_KEY from env (UI tests + Supabase)
#   ./scripts/ci-write-secrets.sh hosted        # read CI_SUPABASE_URL and CI_SUPABASE_ANON_KEY from env
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/CameraApp/Secrets.plist"
MODE="${1:-placeholder}"

mkdir -p "$(dirname "$OUT")"

case "$MODE" in
  placeholder)
    cp "$ROOT/Secrets.example.plist" "$OUT"
    /usr/libexec/PlistBuddy -c "Set :SUPABASE_URL http://127.0.0.1:54321" "$OUT"
    /usr/libexec/PlistBuddy -c "Set :SUPABASE_ANON_KEY ci-placeholder-anon-key" "$OUT"
    ;;
  local)
    : "${API_URL:?API_URL must be set (from: supabase status -o env)}"
    : "${ANON_KEY:?ANON_KEY must be set (from: supabase status -o env)}"
    cp "$ROOT/Secrets.example.plist" "$OUT"
    /usr/libexec/PlistBuddy -c "Set :SUPABASE_URL ${API_URL}" "$OUT"
    /usr/libexec/PlistBuddy -c "Set :SUPABASE_ANON_KEY ${ANON_KEY}" "$OUT"
    ;;
  hosted)
    : "${CI_SUPABASE_URL:?CI_SUPABASE_URL must be set}"
    : "${CI_SUPABASE_ANON_KEY:?CI_SUPABASE_ANON_KEY must be set}"
    cp "$ROOT/Secrets.example.plist" "$OUT"
    /usr/libexec/PlistBuddy -c "Set :SUPABASE_URL ${CI_SUPABASE_URL}" "$OUT"
    /usr/libexec/PlistBuddy -c "Set :SUPABASE_ANON_KEY ${CI_SUPABASE_ANON_KEY}" "$OUT"
    ;;
  *)
    echo "Usage: $0 {placeholder|local|hosted}" >&2
    exit 1
    ;;
esac

echo "Wrote $OUT (mode=$MODE)"
