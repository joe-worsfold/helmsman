#!/usr/bin/env bash
# DynamoDB table JSON. Parses tracked JSON under a dynamodb path.
# Does not call AWS. An SST or CDK mention with no JSON skips.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

list="$(cd "$(dirname "$0")/../checks" && pwd)/tracked.sh"
if [[ ! -f "$list" ]]; then
  echo "helmsman: .helmsman/tools/checks/tracked.sh is missing." >&2
  exit 1
fi

files="$("$list" '(^|/)([^/]*dynamo[^/]*\.json|dynamodb/.+\.json)$')"

mention=0
for candidate in sst.config.ts sst.config.js; do
  if [[ -f "$candidate" ]] && grep -qi 'dynamo' "$candidate"; then
    mention=1
  fi
done
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    case "$file" in
      infra/*.ts|infra/*.go|lib/*.ts|stacks/*.ts)
        if grep -qi 'dynamo' "$file"; then
          mention=1
        fi
        ;;
    esac
  done < <(git ls-files)
fi

if [[ -z "$files" && "$mention" -eq 0 ]]; then
  echo "helmsman: no DynamoDB JSON or SST/CDK mention. DynamoDB gate skipped."
  exit 0
fi

if [[ -z "$files" && "$mention" -eq 1 ]]; then
  echo "helmsman: SST or CDK mentions DynamoDB and no table JSON is tracked. The source is the definition. JSON gate skipped."
  exit 0
fi

python3 - "$files" << 'PY'
import json, sys
from pathlib import Path

need = ("TableName", "AttributeDefinitions", "KeySchema", "Resources")
fail = 0
for name in sys.argv[1].splitlines():
    if not name:
        continue
    path = Path(name)
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"helmsman: {name} is not JSON: {exc}\n")
        fail = 1
        continue
    if not isinstance(data, dict) or not any(key in data for key in need):
        sys.stderr.write(
            f"helmsman: {name} needs one of {', '.join(need)}.\n"
        )
        fail = 1
if fail:
    sys.exit(1)
PY

echo "helmsman: dynamodb JSON ok."
