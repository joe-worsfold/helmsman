#!/usr/bin/env bats
# Fix-forward issues: off without auth, off when filing is disabled, no duplicate title.

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
if [[ "$1" == "label" && "$2" == "list" ]]; then
  printf '%s\n' "${GH_LABELS:-}"
  exit 0
fi
if [[ "$1" == "label" && "$2" == "create" ]]; then
  exit 0
fi
if [[ "$1" == "issue" && "$2" == "create" ]]; then
  printf '%s\n' "https://example.com/issues/9"
  exit 0
fi
exit 0
EOF
  chmod +x bin/gh
  export PATH="$repo/bin:$PATH"
  export GH_LOG="$repo/gh.log"
  export GH_ISSUES="$repo/issues.json"
  printf '%s\n' '[]' > "$GH_ISSUES"
  cat > .helmsman/setup.md << 'EOF'
# Setup
Issues: github
File issues: yes
EOF
  git add -A
  git commit -q -m init
}

teardown() {
  cd /tmp
  if [[ -n "${repo:-}" && -d "$repo" ]]; then
    rm -rf "$repo"
  fi
}

@test "file issues no skips before gh" {
  printf '%s\n' 'File issues: no' >> .helmsman/setup.md
  # The seeded file already has File issues: yes. Replace it.
  cat > .helmsman/setup.md << 'EOF'
# Setup
Issues: github
File issues: no
EOF
  run "$checks/fix-forward.sh" --title "A leftover" --body "Wait."
  [ "$status" -eq 0 ]
  [[ "$output" == *"not yes"* ]]
  [ ! -s "$GH_LOG" ]
}

@test "no auth skips" {
  export GH_AUTH_EXIT=1
  run "$checks/fix-forward.sh" --title "A leftover" --body "Wait."
  [ "$status" -eq 0 ]
  [[ "$output" == *"no GitHub auth"* ]]
  ! grep -q "issue create" "$GH_LOG"
}

@test "an open title is not created again" {
  printf '%s\n' '[{"number":4,"title":"A leftover"}]' > "$GH_ISSUES"
  run "$checks/fix-forward.sh" --title "A leftover" --body "Wait."
  [ "$status" -eq 0 ]
  [[ "$output" == *"already open (#4)"* ]]
  ! grep -q "issue create" "$GH_LOG"
}

@test "a missing label describes a Fix forward finding" {
  export GH_LABELS=""
  run "$checks/fix-forward.sh" --title "A leftover" --body "Wait."
  [ "$status" -eq 0 ]
  grep -q "label create" "$GH_LOG"
  grep -q "Fix forward" "$GH_LOG"
}

@test "a new title is created with the label" {
  export GH_LABELS="fix-forward"
  run "$checks/fix-forward.sh" --title "A leftover" --body "Wait."
  [ "$status" -eq 0 ]
  [[ "$output" == *"fix-forward opened https://example.com/issues/9"* ]]
  grep -q "issue create" "$GH_LOG"
  grep -q "fix-forward" "$GH_LOG"
}
