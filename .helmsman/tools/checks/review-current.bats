#!/usr/bin/env bats
# The review comment records a sha. A later patch with a different patch-id fails.

setup() {
  repo="$(mktemp -d)"
  cd "$repo"
  git init -q
  git config user.email "gate@example.com"
  git config user.name "gate"
  checks="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  mkdir -p bin
  cat > bin/gh << 'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "${GH_LOG}"
if [[ "$1" == "auth" ]]; then
  exit "${GH_AUTH_EXIT:-0}"
fi
if [[ "$1" == "pr" ]]; then
  exit "${GH_PR_EXIT:-1}"
fi
if [[ "$1" == "api" ]]; then
  cat "${GH_COMMENTS}"
  exit 0
fi
exit 0
EOF
  chmod +x bin/gh
  export PATH="$repo/bin:$PATH"
  export GH_LOG="$repo/gh.log"
  export GH_COMMENTS="$repo/comments.json"
  printf '%s\n' '[]' > "$GH_COMMENTS"
  unset GITHUB_ACTIONS GITHUB_EVENT_PATH GITHUB_EVENT_NAME GITHUB_REPOSITORY || true
  export GITHUB_REPOSITORY="example/repo"
}

teardown() {
  cd /tmp
  if [[ -n "${repo:-}" && -d "$repo" ]]; then
    rm -rf "$repo"
  fi
}

commit_file() {
  printf '%s\n' "$2" > "$1"
  git add "$1"
  git commit -q -m "$3"
}

write_event() {
  local base="$1"
  python3 - "$base" << 'PY'
import json, os, sys
path = os.environ["GITHUB_EVENT_PATH"]
json.dump({"pull_request": {"number": 6, "base": {"sha": sys.argv[1]}}}, open(path, "w"))
PY
}

write_comment() {
  local sha="$1"
  local verdict="${2-Approve}"
  python3 - "$sha" "$verdict" << 'PY'
import json, os, sys
path = os.environ["GH_COMMENTS"]
sha, verdict = sys.argv[1], sys.argv[2]
lines = []
if verdict:
    lines.append("Verdict: %s" % verdict)
lines.append("Reviewed: %s" % sha)
lines.append("Base: ignored")
lines.append("Patch: abc")
body = "\n".join(lines) + "\n"
json.dump([{"body": body, "updated_at": "2026-10-11T00:00:00Z"}], open(path, "w"))
PY
}

@test "no pull request passes" {
  commit_file note.txt one init
  run "$checks/review-current.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no pull request"* ]]
}

@test "matching sha passes" {
  commit_file note.txt one init
  local base head
  base="$(git rev-parse HEAD)"
  commit_file note.txt two reviewed
  head="$(git rev-parse HEAD)"
  export GITHUB_EVENT_PATH="$repo/event.json"
  write_event "$base"
  write_comment "$head"
  run "$checks/review-current.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"review current ok."* ]]
}

@test "same patch after a new commit message passes" {
  commit_file note.txt one init
  local base reviewed
  base="$(git rev-parse HEAD)"
  commit_file note.txt two reviewed
  reviewed="$(git rev-parse HEAD)"
  git commit --amend -q -m "same patch"
  export GITHUB_EVENT_PATH="$repo/event.json"
  write_event "$base"
  write_comment "$reviewed"
  run "$checks/review-current.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"same patch"* ]]
}

@test "a changed patch fails" {
  commit_file note.txt one init
  local base reviewed
  base="$(git rev-parse HEAD)"
  commit_file note.txt two reviewed
  reviewed="$(git rev-parse HEAD)"
  commit_file note.txt three changed
  export GITHUB_EVENT_PATH="$repo/event.json"
  write_event "$base"
  write_comment "$reviewed"
  run "$checks/review-current.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"review is stale"* ]]
}

@test "request changes with a matching sha passes" {
  commit_file note.txt one init
  local base head
  base="$(git rev-parse HEAD)"
  commit_file note.txt two reviewed
  head="$(git rev-parse HEAD)"
  export GITHUB_EVENT_PATH="$repo/event.json"
  write_event "$base"
  write_comment "$head" "Request changes"
  run "$checks/review-current.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"review current ok."* ]]
}

@test "an old answer word is not a verdict" {
  commit_file note.txt one init
  local base head
  base="$(git rev-parse HEAD)"
  commit_file note.txt two reviewed
  head="$(git rev-parse HEAD)"
  export GITHUB_EVENT_PATH="$repo/event.json"
  write_event "$base"
  write_comment "$head" "pass"
  run "$checks/review-current.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no Verdict"* ]]
}

@test "a review without a verdict fails" {
  commit_file note.txt one init
  local base head
  base="$(git rev-parse HEAD)"
  commit_file note.txt two reviewed
  head="$(git rev-parse HEAD)"
  export GITHUB_EVENT_PATH="$repo/event.json"
  write_event "$base"
  write_comment "$head" ""
  run "$checks/review-current.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no Verdict"* ]]
}

@test "no reviewed sha passes" {
  commit_file note.txt one init
  local base
  base="$(git rev-parse HEAD)"
  export GITHUB_EVENT_PATH="$repo/event.json"
  write_event "$base"
  run "$checks/review-current.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no reviewed sha"* ]]
}
