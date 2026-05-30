#!/usr/bin/env bash
# Prints the name of an available iOS Simulator for CI (stdout).
# Override by setting DEVICE before calling make.
set -euo pipefail

if [ -n "${DEVICE:-}" ]; then
  echo "$DEVICE"
  exit 0
fi

candidates=(
  "iPhone 16e"
  "iPhone 16"
  "iPhone 15"
  "iPhone 14"
)

for name in "${candidates[@]}"; do
  if xcrun simctl list devices available 2>/dev/null | grep -F "${name} (" >/dev/null 2>&1; then
    echo "$name"
    exit 0
  fi
done

echo "error: no supported iPhone simulator found on this runner" >&2
xcrun simctl list devices available 2>/dev/null | grep -E 'iPhone ' | head -20 >&2 || true
exit 1
