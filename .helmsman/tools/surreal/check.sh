#!/usr/bin/env bash
# Surreal schema presence. Does not start the database.
# A compose service or a tracked .surql file opts in.
# The integration command belongs on the setup file's Integration line.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

list="$(cd "$(dirname "$0")/../checks" && pwd)/tracked.sh"
if [[ ! -f "$list" ]]; then
  echo "helmsman: .helmsman/tools/checks/tracked.sh is missing." >&2
  exit 1
fi

surql="$("$list" '\.surql$')"
compose="$("$list" '(^|/)(docker-compose|compose)\.(yml|yaml)$')"

compose_surreal=0
if [[ -n "$compose" ]]; then
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    if grep -qi 'surrealdb' "$file"; then
      compose_surreal=1
      break
    fi
  done <<< "$compose"
fi

if [[ -z "$surql" && "$compose_surreal" -eq 0 ]]; then
  echo "helmsman: no Surreal schema or compose service. Surreal gate skipped."
  exit 0
fi

if [[ "$compose_surreal" -eq 1 && -z "$surql" ]]; then
  echo "helmsman: compose runs SurrealDB but no tracked .surql schema is present." >&2
  exit 1
fi

while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  if [[ ! -s "$file" ]]; then
    echo "helmsman: $file is an empty Surreal schema." >&2
    exit 1
  fi
done <<< "$surql"

setup_file=".helmsman/setup.md"
if [[ ! -f "$setup_file" ]]; then
  echo "helmsman: Surreal schema is present but .helmsman/setup.md is missing. Set Integration to the integration command. This package does not start the database." >&2
  exit 1
fi

integration="$(awk -F': ' 'tolower($1) == "integration" { sub(/^[^:]*: /, ""); print; exit }' "$setup_file")"
lower="$(printf '%s' "$integration" | tr '[:upper:]' '[:lower:]')"
if [[ -z "$integration" || "$lower" == "none" ]]; then
  echo "helmsman: Surreal schema is present. Set Integration in .helmsman/setup.md to the integration command (schema apply or the live-database tests). This package does not start the database." >&2
  exit 1
fi

echo "helmsman: surreal schema present. Integration stays on the setup file: $integration"
