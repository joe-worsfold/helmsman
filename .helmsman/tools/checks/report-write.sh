#!/usr/bin/env bash
# Gate for overnight report files.
# Exit 0 and print a repo-relative path when the file may be written.
# Exit 10 when the chat reply is the report and no file is created.
#
#   .helmsman/tools/checks/report-write.sh readiness.md
#   .helmsman/tools/checks/report-write.sh --latest
#
# The stamp is HELMSMAN_REPORT_STAMP, or the current UTC minute (YYYY-MM-DDTHHMMZ).
# One nightly run sets the stamp so readiness, slop, and security share a directory.
#
# A write needs both of these:
#   git check-ignore -q accepts the path
#   and an allow env: HELMSMAN_WRITE_REPORTS=1, CURSOR_AGENT=1,
#   GITHUB_ACTIONS=true, or CI=true.
# A local shell sets none of those, so the default is chat-only.
# CURSOR_AGENT=1 is the Cursor cloud agent. GITHUB_ACTIONS=true and CI=true are CI.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

stamp_pattern='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{4}Z$'
name_pattern='^[a-z0-9][a-z0-9.-]*\.md$'

write_allowed() {
  if [[ "${HELMSMAN_WRITE_REPORTS:-}" == "1" ]]; then
    return 0
  fi
  if [[ "${CURSOR_AGENT:-}" == "1" ]]; then
    return 0
  fi
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    return 0
  fi
  if [[ "${CI:-}" == "true" ]]; then
    return 0
  fi
  return 1
}

latest_dir() {
  local dir stamp best=""
  if [[ ! -d .helmsman/reports ]]; then
    return 1
  fi
  for dir in .helmsman/reports/*/; do
    [[ -d "$dir" ]] || continue
    stamp="$(basename "$dir")"
    if [[ "$stamp" =~ $stamp_pattern ]]; then
      if [[ -z "$best" || "$stamp" > "$best" ]]; then
        best="$stamp"
      fi
    fi
  done
  if [[ -z "$best" ]]; then
    return 1
  fi
  printf '.helmsman/reports/%s\n' "$best"
}

if [[ "${1:-}" == "--latest" ]]; then
  if [[ -n "${2:-}" ]]; then
    echo "helmsman: unknown argument $2" >&2
    exit 2
  fi
  if ! latest_dir; then
    echo "helmsman: no report directory under .helmsman/reports." >&2
    exit 10
  fi
  exit 0
fi

if [[ -z "${1:-}" || -n "${2:-}" ]]; then
  echo "helmsman: usage: report-write.sh <name.md> | --latest" >&2
  exit 2
fi

name="$1"
if [[ ! "$name" =~ $name_pattern ]]; then
  echo "helmsman: report name must be a single markdown file name." >&2
  exit 2
fi

stamp="${HELMSMAN_REPORT_STAMP:-}"
if [[ -z "$stamp" ]]; then
  stamp="$(date -u +%Y-%m-%dT%H%MZ)"
fi
if [[ ! "$stamp" =~ $stamp_pattern ]]; then
  echo "helmsman: HELMSMAN_REPORT_STAMP must look like 2026-09-30T0629Z." >&2
  exit 2
fi

rel=".helmsman/reports/${stamp}/${name}"

if ! write_allowed; then
  echo "helmsman: report stays in the reply. Set HELMSMAN_WRITE_REPORTS=1 to write ${rel}." >&2
  exit 10
fi

if ! git check-ignore -q -- "$rel"; then
  echo "helmsman: ${rel} is not gitignored. The report stays in the reply." >&2
  exit 10
fi

mkdir -p ".helmsman/reports/${stamp}"
printf '%s\n' "$rel"
