#!/usr/bin/env bash
# Run the Repo checks command from the setup file.
# A repo's own offline checks go here, not in a forked Helmsman script.
# Repo checks: none, or no Repo checks line, skips.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

file="${1:-.helmsman/setup.md}"
if [[ ! -f "$file" ]]; then
  echo "helmsman: no $file. Repo checks skipped."
  exit 0
fi

checks="$(awk -F': ' 'tolower($1) == "repo checks" { sub(/^[^:]*: /, ""); print; exit }' "$file")"
lower="$(printf '%s' "$checks" | tr '[:upper:]' '[:lower:]')"

if [[ -z "$checks" || "$lower" == "none" ]]; then
  echo "helmsman: no repo checks."
  exit 0
fi

echo "helmsman: repo checks: $checks"
bash -c "$checks"
