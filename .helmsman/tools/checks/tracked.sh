#!/usr/bin/env bash
# Print tracked paths that match the extended regex in $1, one per line.
# No match is success and prints nothing.
# git ls-files lists tracked files under .helmsman/tools. ripgrep skips
# hidden directories unless --hidden is set, so the gates that scan the
# harness use this list.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "helmsman: tracked.sh needs one regex." >&2
  exit 2
fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

git ls-files | grep -E -- "$1" || true
