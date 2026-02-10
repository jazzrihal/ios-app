#!/usr/bin/env bash
# Installs the Git pre-commit hook. Run once after cloning.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cp "$ROOT/scripts/pre-commit" "$ROOT/.git/hooks/pre-commit"
chmod +x "$ROOT/.git/hooks/pre-commit"
echo "Pre-commit hook installed."
