#!/usr/bin/env bash
# Fail when added lines suppress a check or focus or skip a test.
# A protected test stays as it is. This script does not grant a rewrite.
# The token list lives here. Standards point at this file.
set -euo pipefail

range=""
diff_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --range)
      range="${2:-}"
      shift 2
      ;;
    --diff)
      diff_file="${2:-}"
      shift 2
      ;;
    *)
      echo "helmsman: unknown argument $1" >&2
      exit 2
      ;;
  esac
done

# Recorded fail patches under eval/scenarios contain these tokens on purpose.
paths=(. ':(exclude).helmsman/tools/checks/diff-guard.sh' ':(exclude)eval/scenarios')

if [[ -n "$diff_file" ]]; then
  diff_text="$(cat "$diff_file")"
elif [[ -n "$range" ]]; then
  diff_text="$(git diff --unified=0 "$range" -- "${paths[@]}")"
elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  diff_text="$(git diff --cached --unified=0 -- "${paths[@]}")"
  if [[ -z "$diff_text" ]]; then
    diff_text="$(git diff --unified=0 -- "${paths[@]}")"
  fi
else
  echo "helmsman: no diff to check." >&2
  exit 2
fi

# Added lines only. The token is the whole added line, so a mention in prose can still match.
pattern='eslint-disable|@ts-ignore|@ts-expect-error|@ts-nocheck|it\.skip|describe\.skip|test\.skip|it\.only|describe\.only|test\.only|[[:space:]]xit\(|[[:space:]]xdescribe\(|clippy::allow|#\[allow\(|# noqa|type: ignore'

hits="$(printf '%s\n' "$diff_text" | awk '/^\+/ && !/^\+\+\+/ { print }' | grep -nE "$pattern" || true)"

if [[ -n "$hits" ]]; then
  echo "helmsman: added lines suppress a check or skip a test:" >&2
  printf '%s\n' "$hits" >&2
  exit 1
fi

echo "helmsman: diff guard ok."
