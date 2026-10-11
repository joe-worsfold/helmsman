#!/usr/bin/env bash
# Fail when a tracked Rust file is longer than 500 lines.
# STAR keeps Rust in apps/*/src, packages/<domain>/rs, and packages/platform/rs, so every tracked .rs file counts.
# Copy to scripts/check-file-length.sh and call it from `make lines`
# only when that target is absent. Do not replace an existing script.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

files="$(git ls-files '*.rs')"
if [[ -z "$files" ]]; then
  echo "helmsman: no tracked Rust files. File length skipped."
  exit 0
fi

limit=500
fail=0
while IFS= read -r file; do
  lines="$(wc -l < "$file" | tr -d ' ')"
  if (( lines > limit )); then
    echo "helmsman: $file has $lines lines (limit $limit)." >&2
    fail=1
  fi
done <<< "$files"

if (( fail != 0 )); then
  exit 1
fi

echo "helmsman: Rust file length ok."
