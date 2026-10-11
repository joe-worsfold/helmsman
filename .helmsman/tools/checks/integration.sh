#!/usr/bin/env bash
# Run the Integration command from the setup file.
# Put `make test-integration` or a compose command on the Integration line.
# Integration: none, or no Integration line, skips.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

file="${1:-.helmsman/setup.md}"
if [[ ! -f "$file" ]]; then
  echo "helmsman: missing $file. Integration skipped." >&2
  exit 1
fi

integration="$(awk -F': ' 'tolower($1) == "integration" { sub(/^[^:]*: /, ""); print; exit }' "$file")"
lower="$(printf '%s' "$integration" | tr '[:upper:]' '[:lower:]')"

if [[ -z "$integration" || "$lower" == "none" ]]; then
  echo "helmsman: no integration command."
  exit 0
fi

echo "helmsman: integration: $integration"
bash -lc "$integration"
