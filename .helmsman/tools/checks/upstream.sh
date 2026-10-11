#!/usr/bin/env bash
# Fail when a pinned upstream copy does not match .helmsman/tools/upstream/upstream.json.
# No network. A tree with no pin skips, so a consumer that did not receive the snapshot still passes.
set -euo pipefail

root="${1:-}"
if [[ -n "$root" && "$root" == -* ]]; then
  echo "helmsman: unknown argument $root" >&2
  exit 2
fi
if [[ -z "$root" ]]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi
if [[ ! -d "$root" ]]; then
  echo "helmsman: upstream root is not a directory: $root" >&2
  exit 2
fi
cd "$root"

lock=".helmsman/tools/upstream/upstream.json"
if [[ ! -f "$lock" ]]; then
  echo "helmsman: no upstream pin. upstream check skipped."
  exit 0
fi

python3 - "$root" << 'PY'
import hashlib, json, sys
from pathlib import Path

root = Path(sys.argv[1])
lock_path = root / ".helmsman/tools/upstream/upstream.json"
try:
    lock = json.loads(lock_path.read_text())
except json.JSONDecodeError as error:
    print(f"helmsman: upstream.json is not valid JSON. {error}", file=sys.stderr)
    sys.exit(1)

entries = lock.get("entries")
if not isinstance(entries, list) or not entries:
    print("helmsman: upstream.json has no entries.", file=sys.stderr)
    sys.exit(1)

owned = {"upstream.json", "sync.sh"}
expected = set()
problems = []

for entry in entries:
    name = entry.get("name") or ""
    if not name or "/" in name or name.startswith("."):
        problems.append("an upstream entry has no usable name.")
        continue
    base = root / ".helmsman/tools/upstream" / name
    for row in entry.get("files") or []:
        rel = row.get("path") or ""
        want = row.get("sha256") or ""
        if not rel or rel.startswith("/") or ".." in Path(rel).parts:
            problems.append(f"{name}: bad path {rel!r}.")
            continue
        path = base / rel
        key = f"{name}/{rel}"
        expected.add(key)
        if not path.is_file():
            problems.append(f"{key} is missing.")
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != want:
            problems.append(f"{key} was edited. sha256 is {digest}, pin is {want}.")
    for adopted in entry.get("adopted_in") or []:
        if not (root / adopted).is_file():
            problems.append(f"{name} adopted_in missing: {adopted}")

snap = root / ".helmsman/tools/upstream"
for path in snap.rglob("*"):
    if not path.is_file():
        continue
    rel = path.relative_to(snap).as_posix()
    if rel in owned or Path(rel).name in owned and "/" not in rel:
        continue
    if rel not in expected:
        problems.append(f"{rel} is in the snapshot and not in the pin.")

if problems:
    for problem in problems:
        print(f"helmsman: {problem}", file=sys.stderr)
    sys.exit(1)

print("helmsman: upstream pin matches.")
PY
