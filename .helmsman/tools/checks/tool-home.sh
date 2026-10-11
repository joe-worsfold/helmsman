#!/usr/bin/env bash
# Helmsman tools live in .helmsman/tools/ only.
# Fail when the old tools/helmsman tree, a root tools/ tree, or a root
# folder with the same name as a harness package is present.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
here="$(cd "$(dirname "$0")" && pwd)"
tools="$(cd "$here/.." && pwd)"

fail() {
  echo "helmsman: $*" >&2
  exit 1
}

if [[ -e "$root/tools/helmsman" ]]; then
  fail "tools/helmsman/ is the old layout. Tools live in .helmsman/tools/."
fi

if [[ -e "$root/tools" ]]; then
  fail "root tools/ is not a Helmsman tool home. Tools live in .helmsman/tools/."
fi

if [[ -e "$root/scripts/helmsman" ]]; then
  fail "scripts/helmsman/ is not a Helmsman tool home. Tools live in .helmsman/tools/."
fi

shopt -s nullglob
for dir in "$tools"/*/; do
  name="$(basename "$dir")"
  if [[ -d "$root/$name" ]]; then
    fail "$name/ is a root-level Helmsman tool folder. Put it in .helmsman/tools/$name/."
  fi
  if [[ -e "$root/scripts/$name" ]]; then
    fail "scripts/$name is a Helmsman tool path. Put it in .helmsman/tools/$name/."
  fi
done

for sh in "$here"/*.sh; do
  base="$(basename "$sh")"
  if [[ -e "$root/scripts/$base" ]]; then
    fail "scripts/$base belongs in .helmsman/tools/checks/."
  fi
done

echo "helmsman: tool home ok."
