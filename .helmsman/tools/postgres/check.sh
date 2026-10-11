#!/usr/bin/env bash
# Postgres files. Does not start the database.
# sqlfluff runs when it is installed.
# A sqlfluff config, or a migrate config, without the binary fails.
# Tracked SQL with neither config nor binary skips, and says so.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

list="$(cd "$(dirname "$0")/../checks" && pwd)/tracked.sh"
if [[ ! -f "$list" ]]; then
  echo "helmsman: .helmsman/tools/checks/tracked.sh is missing." >&2
  exit 1
fi

sql="$("$list" '\.sql$')"
compose="$("$list" '(^|/)(docker-compose|compose)\.(yml|yaml)$')"

compose_pg=0
if [[ -n "$compose" ]]; then
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    if grep -qi 'postgres' "$file"; then
      compose_pg=1
      break
    fi
  done <<< "$compose"
fi

opted=0
if [[ -f .sqlfluff || -f .sqlfluffignore ]]; then
  opted=1
fi
if [[ -f pyproject.toml ]] && grep -q '^\[tool\.sqlfluff' pyproject.toml; then
  opted=1
fi
if [[ -f atlas.hcl || -f dbmate.yml || -f .dbmate ]]; then
  opted=1
fi

if [[ -z "$sql" && "$compose_pg" -eq 0 && "$opted" -eq 0 ]]; then
  echo "helmsman: no Postgres SQL, compose service, or sql config. Postgres gate skipped."
  exit 0
fi

if [[ "$compose_pg" -eq 1 ]]; then
  echo "helmsman: Postgres is in compose. Do not start it here. Put the integration command on the Integration line in `.helmsman/setup.md`."
fi

if [[ -n "$sql" ]]; then
  if command -v sqlfluff >/dev/null 2>&1; then
    args=()
    while IFS= read -r file; do
      [[ -n "$file" ]] || continue
      args+=("$file")
    done <<< "$sql"
    sqlfluff lint "${args[@]}"
    echo "helmsman: sqlfluff ok."
  elif [[ "$opted" -eq 1 ]]; then
    echo "helmsman: SQL is tracked and a sqlfluff or migrate config is present, but sqlfluff is not installed." >&2
    exit 1
  else
    echo "helmsman: SQL is tracked and sqlfluff is not installed. No sqlfluff config, so this is a skip, not a pass. Add a config to opt in, or install sqlfluff."
  fi
fi

if [[ -f atlas.hcl ]]; then
  if command -v atlas >/dev/null 2>&1; then
    echo "helmsman: atlas.hcl is present. migrate status needs a running database, so it stays on the Integration line. Not started here."
  else
    echo "helmsman: atlas.hcl is present but atlas is not installed." >&2
    exit 1
  fi
fi

if [[ -f dbmate.yml || -f .dbmate ]]; then
  if ! command -v dbmate >/dev/null 2>&1; then
    echo "helmsman: dbmate config is present but dbmate is not installed." >&2
    exit 1
  fi
  echo "helmsman: dbmate config is present. Status needs a running database, so it stays on the Integration line. Not started here."
fi

echo "helmsman: postgres gate finished."
