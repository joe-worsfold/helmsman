#!/usr/bin/env bash
# Root and nested AGENTS.md stay readable.
# Above 400 words warns. Above 900 fails. Fixture trees are not this repo's guidance.
set -euo pipefail

root="${1:-}"
if [[ -z "$root" ]]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    root="$(git rev-parse --show-toplevel)"
  else
    root="$(pwd)"
  fi
fi
cd "$root"

python3 - "$root" << 'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
skip = {"node_modules", "fixture", "fixtures", "upstream", "dist", "target", "coverage", ".git"}
warn_at = 400
fail_at = 900
failed = False
found = False

def walk(directory):
    for path in sorted(directory.iterdir()):
        if path.name in skip or (path.name.startswith(".") and path.name != ".cursor"):
            continue
        if path.is_dir():
            yield from walk(path)
        elif path.name == "AGENTS.md":
            yield path

for path in walk(root):
    found = True
    count = len(path.read_text(encoding="utf-8", errors="replace").split())
    rel = path.relative_to(root).as_posix()
    if count > fail_at:
        print(f"helmsman: {rel} is {count} words. Fail above {fail_at}.", file=sys.stderr)
        failed = True
    elif count > warn_at:
        print(f"helmsman: {rel} is {count} words. Warn above {warn_at}.")
    else:
        print(f"helmsman: {rel} is {count} words.")

if failed:
    sys.exit(1)
if not found:
    print("helmsman: no AGENTS.md. word count skipped.")
else:
    print("helmsman: AGENTS.md words ok.")
PY
