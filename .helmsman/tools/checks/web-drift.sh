#!/usr/bin/env bash
# Fail when a generated Makefile path is missing or older than its inputs.
# Question mode only: make -q does not run the recipe.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

found=0
for name in Makefile makefile GNUmakefile; do
  if [[ -f "$name" ]]; then
    found=1
    break
  fi
done

if [[ "$found" -eq 0 ]]; then
  echo "helmsman: no Makefile. generated-path check skipped."
  exit 0
fi

if ! command -v make >/dev/null 2>&1; then
  echo "helmsman: Makefile exists but make is not installed." >&2
  exit 1
fi

set +e
db="$(make -qp --no-print-directory 2>&1)"
status=$?
set -e
if [[ "$status" -eq 2 && "$db" != *"# Files"* ]]; then
  echo "helmsman: make -qp failed." >&2
  exit 1
fi

targets="$(printf '%s\n' "$db" | awk '
  /^# Files$/ { in_files = 1; next }
  in_files != 1 { next }
  /^# Not a target:$/ { skip = 1; next }
  /^# / {
    if (name != "" && index($0, "Phony target") > 0) phony = 1
    if (name != "" && index($0, "Builtin rule") > 0) builtin = 1
    if (name != "" && index($0, "recipe to execute (from ") > 0) from_make = 1
    next
  }
  /^[^ \t#]/ && /:/ {
    if (name != "" && from_make && !phony && !builtin) print name
    name = ""
    from_make = 0
    phony = 0
    builtin = 0
    if (skip) { skip = 0; next }
    line = $0
    sub(/:.*/, "", line)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
    name = line
    next
  }
  END {
    if (name != "" && from_make && !phony && !builtin) print name
  }
')"

if [[ -z "$targets" ]]; then
  echo "helmsman: no generated Makefile paths."
  exit 0
fi

drifted=0
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  # A rule can name more than one target.
  for target in $line; do
    case "$target" in
      *%*|.*) continue ;;
    esac
    if [[ "$target" != */* && "$target" != *.* ]]; then
      continue
    fi
    set +e
    make -q --no-print-directory "$target" >/dev/null 2>&1
    q=$?
    set -e
    if [[ "$q" -eq 0 ]]; then
      continue
    fi
    echo "helmsman: generated path is out of date: $target" >&2
    drifted=1
  done
done <<< "$targets"

if [[ "$drifted" -ne 0 ]]; then
  exit 1
fi

echo "helmsman: generated paths are current."
