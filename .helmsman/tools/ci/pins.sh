#!/usr/bin/env bash
# Move each pinned action to the commit its tag or branch points at now.
#
#   .helmsman/tools/ci/pins.sh            rewrite the pins, then regenerate the workflow
#   .helmsman/tools/ci/pins.sh --dry-run  print the pins that moved, write nothing
#
# A pin is `owner/repo@<40-char sha> # <ref>` in ci/emit.sh or .github/workflows/release.yml.
# The ref in the comment is what gets resolved, so a pin follows its major tag on purpose.
set -euo pipefail

dry=0
case "${1:-}" in
  "") ;;
  --dry-run) dry=1 ;;
  -h | --help)
    echo "helmsman: pins.sh [--dry-run]"
    echo "  .helmsman/tools/ci/pins.sh --dry-run"
    exit 0
    ;;
  *)
    echo "helmsman: pins.sh [--dry-run]" >&2
    exit 2
    ;;
esac

root="$(git rev-parse --show-toplevel)"
cd "$root"
here="$(cd "$(dirname "$0")" && pwd)"

files=("$here/emit.sh")
[[ -f .github/workflows/release.yml ]] && files+=(.github/workflows/release.yml)

DRY="$dry" python3 - "${files[@]}" << 'PY'
import os
import re
import subprocess
import sys
from pathlib import Path

pin = re.compile(r"([\w.-]+/[\w.-]+)@([0-9a-f]{40}) # ([\w.-]+)")
files = [Path(f) for f in sys.argv[1:]]
refs = {(m[0], m[2]) for f in files for m in pin.findall(f.read_text(encoding="utf-8"))}

latest = {}
for repo, ref in sorted(refs):
    out = subprocess.run(
        ["git", "ls-remote", f"https://github.com/{repo}", f"refs/tags/{ref}^{{}}", f"refs/tags/{ref}", f"refs/heads/{ref}"],
        capture_output=True, text=True, check=True,
    ).stdout.split("\n")
    lines = sorted((line.split("\t") for line in out if line), key=lambda x: x[1], reverse=True)
    if not lines:
        print(f"helmsman: {repo} has no ref {ref}.", file=sys.stderr)
        sys.exit(1)
    latest[(repo, ref)] = lines[0][0]

moved = 0
for f in files:
    text = f.read_text(encoding="utf-8")
    def swap(m):
        global moved
        new = latest[(m[1], m[3])]
        if new != m[2]:
            moved += 1
            print(f"helmsman: {m[1]} {m[3]}: {m[2][:7]} -> {new[:7]} ({f.name})")
        return f"{m[1]}@{new} # {m[3]}"
    text = pin.sub(swap, text)
    if os.environ["DRY"] != "1":
        f.write_text(text, encoding="utf-8")
print(f"helmsman: {moved} pin(s) moved." if moved else "helmsman: every pin is current.")
PY

if [[ "$dry" -eq 0 ]]; then
  "$here/emit.sh"
fi
