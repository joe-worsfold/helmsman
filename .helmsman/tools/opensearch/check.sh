#!/usr/bin/env bash
# OpenSearch mapping and index JSON. Parse only. Does not call a cluster.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

list="$(cd "$(dirname "$0")/../checks" && pwd)/tracked.sh"
if [[ ! -f "$list" ]]; then
  echo "helmsman: .helmsman/tools/checks/tracked.sh is missing." >&2
  exit 1
fi

files="$("$list" '(^|/)(opensearch|elasticsearch)/.+\.json$|[^/]*(opensearch|elasticsearch)[^/]*\.json$|(^|/)(mappings?|index-templates?)/.+\.json$')"

if [[ -z "$files" ]]; then
  echo "helmsman: no OpenSearch JSON. OpenSearch gate skipped."
  exit 0
fi

python3 - "$files" << 'PY'
import json, sys
from pathlib import Path

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
    if not isinstance(data, dict):
        sys.stderr.write(f"helmsman: {name} must be a JSON object.\n")
        fail = 1
        continue
    lower = name.lower()
    if "mapping" in lower and "mappings" not in data:
        sys.stderr.write(f"helmsman: {name} is a mapping file and has no mappings object.\n")
        fail = 1
if fail:
    sys.exit(1)
PY

echo "helmsman: opensearch JSON ok."
