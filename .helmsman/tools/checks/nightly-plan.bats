#!/usr/bin/env bats
# The nightly fixer stays off unless the setup file says yes.

setup() {
  repo="$(mktemp -d)"
  cd "$repo"
  git init -q
  git config user.email "gate@example.com"
  git config user.name "gate"
  checks="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  mkdir -p bin .helmsman
  cat > bin/gh << 'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "${GH_LOG}"
if [[ "$1" == "auth" ]]; then
  exit "${GH_AUTH_EXIT:-0}"
fi
if [[ "$1" == "issue" && "$2" == "list" ]]; then
  cat "${GH_ISSUES}"
  exit 0
fi
exit 0
EOF
  chmod +x bin/gh
  export PATH="$repo/bin:$PATH"
  export GH_LOG="$repo/gh.log"
  export GH_ISSUES="$repo/issues.json"
  printf '%s\n' '[]' > "$GH_ISSUES"
  git add -A
  git commit -q -m init
}

teardown() {
  cd /tmp
  if [[ -n "${repo:-}" && -d "$repo" ]]; then
    rm -rf "$repo"
  fi
}

@test "no setup file is off" {
  rm -rf .helmsman
  run "$checks/nightly-plan.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no setup file"* ]]
  [ ! -s "$GH_LOG" ]
}

@test "nightly fix no does not call gh" {
  printf '%s\n' '# Setup' 'Nightly fix: no' > .helmsman/setup.md
  run "$checks/nightly-plan.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"nightly fix is off."* ]]
  [ ! -s "$GH_LOG" ]
}

@test "nightly fix yes prints the caps and the issue list" {
  cat > .helmsman/setup.md << 'EOF'
# Setup
Nightly fix: yes
Nightly max PRs: 2
Nightly max tokens: 1000
Nightly max minutes: 15
EOF
  printf '%s\n' '[{"number":4,"title":"A leftover"},{"number":9,"title":"Another"}]' > "$GH_ISSUES"
  run "$checks/nightly-plan.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"nightly fix is on."* ]]
  [[ "$output" == *"max_prs: 2"* ]]
  [[ "$output" == *"max_tokens: 1000"* ]]
  [[ "$output" == *"max_minutes: 15"* ]]
  [[ "$output" == *"issue: #4 A leftover"* ]]
  grep -q "limit 2" "$GH_LOG"
}

@test "a bad cap fails" {
  printf '%s\n' '# Setup' 'Nightly fix: yes' 'Nightly max PRs: 0' > .helmsman/setup.md
  run "$checks/nightly-plan.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"positive integer"* ]]
}
