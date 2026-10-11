#!/usr/bin/env bash
# Run the E2E smoke command from the setup file.
# setup-check.sh checks that an app named one. This script runs it.
# E2E smoke: none, or no command, skips.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

file="${1:-.helmsman/setup.md}"
if [[ ! -f "$file" ]]; then
  echo "helmsman: missing $file" >&2
  exit 1
fi

smoke="$(awk -F': ' -v key="e2e smoke" 'tolower($1) == key { sub(/^[^:]*: /, ""); print; exit }' "$file")"
lower="$(printf '%s' "$smoke" | tr '[:upper:]' '[:lower:]')"

if [[ -z "$smoke" || "$lower" == "none" ]]; then
  echo "helmsman: no e2e smoke command."
  exit 0
fi

if printf '%s\n' "$smoke" | grep -Eq 'maestro|mobile:e2e'; then
  echo "helmsman: e2e smoke runner is Maestro."
fi

echo "helmsman: e2e smoke: $smoke"
bash -lc "$smoke"
