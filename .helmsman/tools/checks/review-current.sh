#!/usr/bin/env bash
# Fail when the latest review comment records a sha and the pull request patch changed after it.
# That comment must also say Verdict: Approve or Verdict: Request changes.
# A rebase that keeps the same patch-id still passes.
# No pull request, no review line, or no GitHub auth outside CI: pass.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

say_ok() {
  local why="${1:-}"
  if [[ -n "$why" ]]; then
    echo "helmsman: review current ok (${why})."
  else
    echo "helmsman: review current ok."
  fi
  exit 0
}

say_fail() {
  echo "helmsman: review is stale. $1" >&2
  exit 1
}

if ! command -v gh >/dev/null 2>&1; then
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    echo "helmsman: review current needs gh." >&2
    exit 1
  fi
  say_ok "gh is not installed"
fi

if ! gh auth status >/dev/null 2>&1; then
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    echo "helmsman: review current has no GitHub auth." >&2
    exit 1
  fi
  say_ok "no GitHub auth"
fi

number=""
base=""
if [[ -n "${GITHUB_EVENT_PATH:-}" && -f "${GITHUB_EVENT_PATH}" ]]; then
  parsed="$(python3 - "${GITHUB_EVENT_PATH}" << 'PY'
import json, sys
event = json.load(open(sys.argv[1]))
pr = event.get("pull_request") or {}
number = pr.get("number") or ""
base = ((pr.get("base") or {}).get("sha")) or ""
print(f"{number}\t{base}")
PY
)"
  number="${parsed%%$'\t'*}"
  base="${parsed#*$'\t'}"
fi

if [[ -z "$number" ]]; then
  if [[ "${GITHUB_EVENT_NAME:-}" == "push" ]]; then
    say_ok "push has no pull request"
  fi
  if ! view="$(gh pr view --json number,baseRefOid 2>/dev/null)"; then
    say_ok "no pull request"
  fi
  parsed="$(printf '%s' "$view" | python3 -c '
import json, sys
data = json.load(sys.stdin)
print("%s\t%s" % (data.get("number") or "", data.get("baseRefOid") or ""))
')"
  number="${parsed%%$'\t'*}"
  base="${parsed#*$'\t'}"
fi

if [[ -z "$number" || -z "$base" ]]; then
  say_ok "pull request has no base"
fi

repo="${GITHUB_REPOSITORY:-}"
if [[ -z "$repo" ]]; then
  repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
fi

err_file="$(mktemp)"
if ! comments="$(gh api --paginate "repos/${repo}/issues/${number}/comments" 2>"$err_file")"; then
  err="$(cat "$err_file" 2>/dev/null || true)"
  rm -f "$err_file"
  echo "helmsman: review current could not read comments. ${err}" >&2
  exit 1
fi
rm -f "$err_file"
recorded="$(printf '%s' "$comments" | python3 -c '
import json, sys
comments = json.load(sys.stdin)
hits = []
for comment in comments:
    body = comment.get("body") or ""
    reviewed = recorded_base = patch = verdict = ""
    for line in body.splitlines():
        text = line.strip().replace("**", "")
        if text.startswith("Reviewed: "):
            reviewed = text.split(" ", 1)[1].strip()
        elif text.startswith("Base: "):
            recorded_base = text.split(" ", 1)[1].strip()
        elif text.startswith("Patch: "):
            patch = text.split(" ", 1)[1].strip()
        elif text.startswith("Verdict: "):
            verdict = text.split(" ", 1)[1].strip()
    if len(reviewed) == 40 and all(c in "0123456789abcdef" for c in reviewed):
        stamp = comment.get("updated_at") or comment.get("created_at") or ""
        hits.append((stamp, reviewed, recorded_base, patch, verdict))
if not hits:
    print("NONE")
else:
    hits.sort()
    print("\t".join(hits[-1][1:]))
')"

if [[ "$recorded" == "NONE" ]]; then
  say_ok "no reviewed sha"
fi

reviewed="${recorded%%$'\t'*}"
rest="${recorded#*$'\t'}"
recorded_base="${rest%%$'\t'*}"
rest="${rest#*$'\t'}"
recorded_patch="${rest%%$'\t'*}"
verdict="${rest#*$'\t'}"
head="$(git rev-parse HEAD)"

if [[ "$verdict" != "Approve" && "$verdict" != "Request changes" ]]; then
  say_fail "review comment has no Verdict. Post Verdict: Approve or Verdict: Request changes."
fi

if [[ "$reviewed" == "$head" ]]; then
  say_ok
fi

previous_from="$base"
if [[ "$recorded_base" =~ ^[0-9a-f]{40}$ ]]; then
  previous_from="$recorded_base"
fi

patch_id() {
  local from="$1"
  local to="$2"
  local line
  if ! git cat-file -e "${to}^{commit}" 2>/dev/null; then
    printf '%s\n' missing
    return
  fi
  if ! git cat-file -e "${from}^{commit}" 2>/dev/null; then
    printf '%s\n' missing
    return
  fi
  line="$(git diff --no-ext-diff "$from" "$to" | git patch-id --stable || true)"
  if [[ -z "$line" ]]; then
    printf '%s\n' empty
    return
  fi
  printf '%s\n' "${line%% *}"
}

current="$(patch_id "$base" "$head")"
if [[ "$current" == "missing" ]]; then
  say_fail "base ${base} is not in this clone."
fi

previous="$(patch_id "$previous_from" "$reviewed")"
if [[ "$previous" == "missing" ]]; then
  if [[ -n "$recorded_patch" && "$recorded_patch" == "$current" ]]; then
    say_ok "recorded patch matches"
  fi
  say_fail "reviewed sha ${reviewed} is not in this clone and the patch does not match."
fi

if [[ "$previous" == "$current" ]]; then
  say_ok "same patch"
fi

say_fail "head ${head} differs from reviewed ${reviewed} and the patch changed. Post a new review comment."
