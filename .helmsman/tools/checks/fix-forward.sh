#!/usr/bin/env bash
# Open one low-priority GitHub issue for a Fix forward finding.
# Does nothing without gh auth, or unless File issues is yes and Issues is github.
# An open issue with the same title is not created again.
# shortcut: 200 open fix-forward issues, raise the limit when a repo holds more
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

title=""
body=""
body_file=""
dry=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)
      title="${2:-}"
      shift 2
      ;;
    --body)
      body="${2:-}"
      shift 2
      ;;
    --body-file)
      body_file="${2:-}"
      shift 2
      ;;
    --dry-run)
      dry=1
      shift
      ;;
    --help|-h)
      cat << 'EOF'
Open one fix-forward issue, or print that action and do nothing.

Examples:
  fix-forward.sh --title "A leftover" --body "Wait."
  fix-forward.sh --dry-run --title "A leftover" --body "Wait."
EOF
      exit 0
      ;;
    *)
      echo "helmsman: usage: fix-forward.sh [--dry-run] --title TEXT (--body TEXT | --body-file PATH)" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$title" ]]; then
  echo "helmsman: fix-forward needs --title." >&2
  exit 2
fi
if [[ -n "$body_file" ]]; then
  if [[ ! -f "$body_file" ]]; then
    echo "helmsman: fix-forward body file is missing." >&2
    exit 2
  fi
  body="$(cat "$body_file")"
fi
if [[ -z "$body" ]]; then
  echo "helmsman: fix-forward needs --body or --body-file." >&2
  exit 2
fi

setup=".helmsman/setup.md"
if [[ ! -f "$setup" ]]; then
  echo "helmsman: fix-forward skipped (no setup file)."
  exit 0
fi

field() {
  awk -F': ' -v key="$1" 'tolower($1) == key { sub(/^[^:]*: /, ""); print; exit }' "$setup"
}

issues="$(field "issues" | tr '[:upper:]' '[:lower:]')"
file_issues="$(field "file issues" | tr '[:upper:]' '[:lower:]')"
if [[ "$issues" != "github" || "$file_issues" != "yes" ]]; then
  echo "helmsman: fix-forward skipped (File issues is not yes)."
  exit 0
fi

if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
  echo "helmsman: fix-forward skipped (no GitHub auth)."
  exit 0
fi

if ! printf '%s\n' "$body" | grep -q '^\*\*Priority:\*\*'; then
  body="$(printf '%s\n\n%s\n' "**Source:** fix-forward" "**Priority:** P4" "$body")"
fi

existing="$(gh issue list --state open --label fix-forward --limit 200 --json number,title)"
match="$(FIX_FORWARD_TITLE="$title" python3 -c '
import json, os, sys
title = os.environ["FIX_FORWARD_TITLE"]
rows = json.load(sys.stdin)
for row in rows:
    if row.get("title") == title:
        print(row.get("number") or "")
        break
' <<<"$existing")"
if [[ -n "$match" ]]; then
  echo "helmsman: fix-forward already open (#${match})."
  exit 0
fi

if [[ "$dry" -eq 1 ]]; then
  echo "helmsman: dry-run would open: ${title}"
  exit 0
fi

if ! gh label list --limit 200 --search fix-forward --json name --jq '.[].name' | grep -qx 'fix-forward'; then
  gh label create fix-forward --description "Fix forward finding, deferred to a later change" --color "0E8A16"
fi

url="$(gh issue create --title "$title" --body "$body" --label fix-forward)"
echo "helmsman: fix-forward opened ${url}"
