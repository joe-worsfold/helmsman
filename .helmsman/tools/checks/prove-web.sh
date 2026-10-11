#!/usr/bin/env bash
# A feature pull request that touches apps/web needs a Playwright spec in the
# diff and a prove section in the pull request body.
# This check does not run Playwright and does not write screenshots.
set -euo pipefail

if [[ "${GITHUB_EVENT_NAME:-}" == "push" ]]; then
  echo "helmsman: prove web skipped on push."
  exit 0
fi

root="${1:-}"
if [[ -z "$root" ]]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    root="$(git rev-parse --show-toplevel)"
  else
    root="$(pwd)"
  fi
fi
cd "$root"

if [[ -n "${HELMSMAN_DIFF_RANGE:-}" ]]; then
  range="$HELMSMAN_DIFF_RANGE"
elif git rev-parse --verify --quiet origin/main >/dev/null; then
  range="origin/main...HEAD"
elif git rev-parse --verify --quiet main >/dev/null && [[ "$(git rev-parse main)" != "$(git rev-parse HEAD)" ]]; then
  range="main...HEAD"
elif git rev-parse --verify --quiet HEAD~1 >/dev/null; then
  range="HEAD~1...HEAD"
else
  echo "helmsman: prove web has no diff range." >&2
  exit 1
fi

if ! files="$(git diff --name-status --diff-filter=ACMR "$range")"; then
  echo "helmsman: prove web could not read ${range}." >&2
  exit 1
fi

web=0
spec=0
while IFS=$'\t' read -r status path extra; do
  [[ -z "$status" ]] && continue
  file="$path"
  if [[ "$status" == R* && -n "$extra" ]]; then
    file="$extra"
  fi
  case "$file" in
    apps/web | apps/web/*) web=1 ;;
  esac
  case "$file" in
    apps/web/*.spec.ts | apps/web/*.spec.tsx | apps/web/*.spec.js | apps/web/*.spec.mjs | apps/web/*.test.ts | apps/web/*.test.tsx | apps/web/*.test.js | apps/web/*.test.mjs) spec=1 ;;
    e2e/* | */e2e/* | playwright/* | */playwright/*) spec=1 ;;
  esac
done <<< "$files"

if git diff --name-only "$range" -- apps/web | grep -q .; then
  web=1
fi

if [[ "$web" -eq 0 ]]; then
  echo "helmsman: prove web ok (no apps/web changes)."
  exit 0
fi

probe="$(python3 - << 'PY'
import json, os, re
from pathlib import Path

def feat(text):
    line = (text or "").splitlines()[0] if text else ""
    return bool(re.match(r"^feat(\([^)]*\))?!?([: ]|$)", line))

title = os.environ.get("HELMSMAN_PR_TITLE", "")
body_set = "HELMSMAN_PR_BODY" in os.environ
body = os.environ.get("HELMSMAN_PR_BODY", "")
event_path = os.environ.get("GITHUB_EVENT_PATH", "")
if event_path and Path(event_path).is_file():
    event = json.loads(Path(event_path).read_text(encoding="utf-8"))
    pr = event.get("pull_request") or {}
    if pr:
        if not title:
            title = pr.get("title") or ""
        if not body_set:
            body = pr.get("body") or ""
            body_set = True

if not body_set:
    state = "no-source"
else:
    match = re.search(r"(?m)^## (?:How to verify locally|Prove)\s*$", body)
    if not match:
        state = "absent"
    else:
        rest = body[match.end():]
        nxt = re.search(r"(?m)^## ", rest)
        chunk = rest[: nxt.start()] if nxt else rest
        if not chunk.strip():
            state = "empty"
        elif re.search(
            r"\.helmsman/reports/prove/[A-Za-z0-9._-]+/(?:baseline|treatment)/\S+",
            chunk,
        ):
            state = "ok"
        else:
            state = "no-evidence"

print("yes" if feat(title) else "no", state)
PY
)"
read -r feature body_state <<< "$probe"

if [[ "$feature" != "yes" ]]; then
  while IFS= read -r subject; do
    [[ -z "$subject" ]] && continue
    if printf '%s\n' "$subject" | grep -Eq '^feat(\([^)]*\))?!?([: ]|$)'; then
      feature="yes"
      break
    fi
  done < <(git log --format=%s "$range")
fi

if [[ "$feature" != "yes" ]]; then
  echo "helmsman: prove web ok (not a feature)."
  exit 0
fi

if [[ "$spec" -eq 0 ]]; then
  echo "helmsman: a feature diff touches apps/web and has no Playwright spec." >&2
  exit 1
fi

in_ci=0
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  in_ci=1
fi

case "$body_state" in
  ok)
    echo "helmsman: prove web ok."
    exit 0
    ;;
  no-source)
    if [[ "$in_ci" -eq 1 ]]; then
      echo "helmsman: prove section is missing from the pull request body." >&2
      exit 1
    fi
    echo "helmsman: prove section is checked on the pull request."
    exit 0
    ;;
  empty)
    echo "helmsman: the prove section is empty." >&2
    exit 1
    ;;
  no-evidence)
    echo "helmsman: the prove section must name a file under .helmsman/reports/prove/<pr>/baseline or treatment." >&2
    exit 1
    ;;
  *)
    echo "helmsman: prove section is missing from the pull request body." >&2
    exit 1
    ;;
esac
