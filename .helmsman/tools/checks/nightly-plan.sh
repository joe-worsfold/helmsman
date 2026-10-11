#!/usr/bin/env bash
# Print the nightly fixer plan. Off unless Nightly fix is yes.
# Does not open a pull request.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

setup=".helmsman/setup.md"
if [[ ! -f "$setup" ]]; then
  echo "helmsman: nightly fix is off (no setup file)."
  exit 0
fi

field() {
  awk -F': ' -v key="$1" 'tolower($1) == key { sub(/^[^:]*: /, ""); print; exit }' "$setup"
}

nightly="$(field "nightly fix" | tr '[:upper:]' '[:lower:]')"
if [[ "$nightly" != "yes" ]]; then
  echo "helmsman: nightly fix is off."
  exit 0
fi

positive() {
  local name="$1"
  local raw="$2"
  local fallback="$3"
  if [[ -z "$raw" ]]; then
    printf '%s\n' "$fallback"
    return
  fi
  if [[ ! "$raw" =~ ^[1-9][0-9]*$ ]]; then
    echo "helmsman: nightly ${name} must be a positive integer." >&2
    exit 1
  fi
  printf '%s\n' "$raw"
}

max_prs="$(positive "max PRs" "$(field "nightly max prs")" 3)"
max_tokens="$(positive "max tokens" "$(field "nightly max tokens")" 200000)"
max_minutes="$(positive "max minutes" "$(field "nightly max minutes")" 30)"

echo "helmsman: nightly fix is on."
echo "max_prs: ${max_prs}"
echo "max_tokens: ${max_tokens}"
echo "max_minutes: ${max_minutes}"

if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
  echo "issues: skipped (no GitHub auth)."
  exit 0
fi

existing="$(gh issue list --state open --label fix-forward --limit "$max_prs" --json number,title)"
count="$(FIX_FORWARD_ISSUES="$existing" python3 -c '
import json, os
rows = json.loads(os.environ["FIX_FORWARD_ISSUES"] or "[]")
for row in rows:
    number = row.get("number") or ""
    title = row.get("title") or ""
    print(f"issue: #{number} {title}")
print(f"count: {len(rows)}")
')"
if [[ "$count" == *$'\ncount: 0' || "$count" == "count: 0" ]]; then
  echo "issues: none."
  exit 0
fi
printf '%s\n' "$count"
