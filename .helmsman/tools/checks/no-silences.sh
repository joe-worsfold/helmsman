#!/usr/bin/env bash
# Fail when tracked source silences a lint, a test, or a hook.
# A make check recipe may already run this scan. When that recipe already
# runs it, languages.sh does not run this file a second time.
# Tokens are built from pieces so this file does not contain a diff-guard match.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

here="$(cd "$(dirname "$0")" && pwd)"
list="$here/tracked.sh"
if [[ ! -f "$list" ]]; then
  echo "helmsman: tracked.sh is missing beside no-silences.sh." >&2
  exit 1
fi

# Pieces stay split so this file does not contain a diff-guard token.
# Dots and brackets are escaped so a prose phrase is not a focused-test token.
pattern="$(
  printf '%s-%s|' eslint disable
  printf '%s-%s|' '@ts' ignore
  printf '%s-%s|' '@ts' 'expect-error'
  printf '%s-%s|' '@ts' nocheck
  printf '%s\\.%s|' it skip
  printf '%s\\.%s|' describe skip
  printf '%s\\.%s|' test skip
  printf '%s\\.%s|' it only
  printf '%s\\.%s|' describe only
  printf '%s\\.%s|' test only
  printf '%s::%s|' clippy allow
  printf '#\\[%s\\(|' allow
  printf '#\\[%s\\]|' ignore
  printf '# %s|' noqa
  printf 'type: %s|' ignore
  printf '%s-%s' '--no' verify
)"

files="$("$list" '\.(rs|go|py|js|jsx|ts|tsx|mjs|cjs|sh)$')"
if [[ -z "$files" ]]; then
  echo "helmsman: no source files for the silence scan."
  exit 0
fi

fail=0
while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  case "$file" in
    .helmsman/tools/checks/diff-guard.sh|.helmsman/tools/checks/no-silences.sh|.helmsman/tools/checks/gates.test.sh|eval/scenarios/*|.helmsman/tools/eslint/*|.helmsman/tools/clippy/*)
      continue
      ;;
  esac
  hits="$(grep -nIE -- "$pattern" "$file" || true)"
  if [[ -n "$hits" ]]; then
    echo "helmsman: silence in $file" >&2
    printf '%s\n' "$hits" >&2
    fail=1
  fi
done <<< "$files"

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "helmsman: no silences."
