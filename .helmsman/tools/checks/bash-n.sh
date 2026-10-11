#!/usr/bin/env bash
# Fail when a tracked shell script has a syntax error.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

here="$(cd "$(dirname "$0")" && pwd)"
list="$here/tracked.sh"
if [[ ! -f "$list" ]]; then
  echo "helmsman: tracked.sh is missing beside bash-n.sh." >&2
  exit 1
fi

files="$("$list" '\.sh$')"
if [[ -z "$files" ]]; then
  echo "helmsman: no shell scripts. bash -n skipped."
  exit 0
fi

fail=0
while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  if ! bash -n "$file"; then
    echo "helmsman: bash -n failed: $file" >&2
    fail=1
  fi
done <<< "$files"

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "helmsman: bash -n ok."
