#!/usr/bin/env bats
# Rename old Helmsman paths and words. Temp git repos. No harness marker, so
# a product README is left alone.

setup() {
  repo="$(mktemp -d)"
  cd "$repo"
  git init -q
  git config user.email "gate@example.com"
  git config user.name "gate"
  migrate="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/migrate-names.sh"
}

teardown() {
  cd /tmp
  if [[ -n "${repo:-}" && -d "$repo" ]]; then
    rm -rf "$repo"
  fi
}

seed_old() {
  mkdir -p .cursor/skills/helmsmans-rig .github/workflows .helmsman
  printf '%s\n' 'Run the rigging check. Crow'"'"'s nest and Sail stay on the file.' > .cursor/skills/helmsmans-rig/SKILL.md
  printf '%s\n' \
    '# Rigging' \
    "Crow's nest: pnpm exec playwright test" \
    'Watch: pnpm exec playwright test --ui' \
    'Sail: make test-integration' \
    'Bail: yes' \
    'Lookout PR: yes' > .helmsman/rigging.md
  printf '%s\n' \
    'pre-commit:' \
    '  commands:' \
    '    1_helmsman-rigging:' \
    '      run: pnpm rigging' > lefthook.yml
  printf '%s\n' '.helmsman/*' '!.helmsman/rigging.md' > .gitignore
  printf '%s\n' \
    '{' \
    '  "scripts": {' \
    '    "rigging": "bash .helmsman/tools/checks/pnpm-task.sh rigging",' \
    '    "test:sail": "bash .helmsman/tools/checks/pnpm-task.sh sail"' \
    '  }' \
    '}' > package.json
  printf '%s\n' \
    'name: test (sail)' \
    'run: pnpm test:sail' \
    'name: test (mast)' \
    'name: rigging' \
    'run: pnpm rigging' > .github/workflows/helmsman.yml
  printf '%s\n' 'The product can sail on Friday.' > README.md
  git add -A
  git commit -q -m init
}

@test "renames paths, keys, jobs, and scripts" {
  seed_old
  run "$migrate"
  [ "$status" -eq 0 ]
  [ ! -e .cursor/skills/helmsmans-rig ]
  [ ! -e .helmsman/rigging.md ]
  [ -f .cursor/skills/helmsman-setup/SKILL.md ]
  [ -f .helmsman/setup.md ]
  grep -F -q 'E2E smoke: pnpm exec playwright test' .helmsman/setup.md
  grep -F -q 'Watch: pnpm exec playwright test --ui' .helmsman/setup.md
  grep -F -q 'Integration: make test-integration' .helmsman/setup.md
  grep -F -q 'Fix: yes' .helmsman/setup.md
  grep -F -q 'Upstream PR: yes' .helmsman/setup.md
  grep -F -q 'Correct PR: no' .helmsman/setup.md
  grep -F -q 'Review model: none' .helmsman/setup.md
  grep -F -q 'Nightly fix: no' .helmsman/setup.md
  grep -F -q 'Nightly max PRs: 3' .helmsman/setup.md
  grep -F -q 'Nightly max tokens: 200000' .helmsman/setup.md
  grep -F -q 'Nightly max minutes: 30' .helmsman/setup.md
  grep -F -q 'CI integration: no' .helmsman/setup.md
  grep -F -q 'CI e2e smoke: no' .helmsman/setup.md
  grep -F -q '1_helmsman-setup' lefthook.yml
  grep -F -q 'pnpm setup:check' lefthook.yml
  grep -F -q '!.helmsman/setup.md' .gitignore
  grep -F -q 'test (integration)' .github/workflows/helmsman.yml
  grep -F -q 'pnpm test:integration' .github/workflows/helmsman.yml
  grep -F -q 'test (unit)' .github/workflows/helmsman.yml
  grep -F -q 'pnpm setup:check' .github/workflows/helmsman.yml
  python3 - << 'PY'
import json
scripts = json.load(open("package.json"))["scripts"]
assert "rigging" not in scripts
assert "test:sail" not in scripts
assert scripts["setup:check"] == "bash .helmsman/tools/checks/pnpm-task.sh setup"
assert scripts["test:integration"] == "bash .helmsman/tools/checks/pnpm-task.sh integration"
PY
  grep -F -q 'The product can sail on Friday.' README.md
}

@test "a second run changes nothing" {
  seed_old
  run "$migrate"
  [ "$status" -eq 0 ]
  before="$(find . -type f -not -path './.git/*' -print0 | sort -z | xargs -0 sha256sum | sha256sum)"
  run "$migrate"
  [ "$status" -eq 0 ]
  [ "$(find . -type f -not -path './.git/*' -print0 | sort -z | xargs -0 sha256sum | sha256sum)" = "$before" ]
}

@test "renames the slop score, the fixer, and protected tests" {
  mkdir -p .cursor/skills/helmsman-maintain .cursor/skills/helmsman-fix .helmsman
  printf '%s\n' 'name: helmsman-maintain' 'Write maintain.md.' 'The maintainability score.' 'A kept test stays.' 'kept_test and fail-kept.diff' > .cursor/skills/helmsman-maintain/SKILL.md
  printf '%s\n' 'name: helmsman-fix' 'See helmsman-fix.' > .cursor/skills/helmsman-fix/SKILL.md
  printf '%s\n' '# Setup' 'Issues: github' > .helmsman/setup.md
  git add -A
  git commit -q -m intermediate
  run "$migrate"
  [ "$status" -eq 0 ]
  [ ! -e .cursor/skills/helmsman-maintain ]
  [ ! -e .cursor/skills/helmsman-fix ]
  [ -f .cursor/skills/helmsman-slop/SKILL.md ]
  [ -f .cursor/skills/helmsman-fix-forward/SKILL.md ]
  grep -F -q 'name: helmsman-slop' .cursor/skills/helmsman-slop/SKILL.md
  grep -F -q 'Write slop.md.' .cursor/skills/helmsman-slop/SKILL.md
  grep -F -q 'The slop score.' .cursor/skills/helmsman-slop/SKILL.md
  grep -F -q 'A protected test stays.' .cursor/skills/helmsman-slop/SKILL.md
  grep -F -q 'protected_test and fail-protected.diff' .cursor/skills/helmsman-slop/SKILL.md
  grep -F -q 'name: helmsman-fix-forward' .cursor/skills/helmsman-fix-forward/SKILL.md
  ! grep -F -q 'helmsman-fix-forward-forward' .cursor/skills/helmsman-fix-forward/SKILL.md
  before="$(find . -type f -not -path './.git/*' -print0 | sort -z | xargs -0 sha256sum | sha256sum)"
  run "$migrate"
  [ "$status" -eq 0 ]
  [ "$(find . -type f -not -path './.git/*' -print0 | sort -z | xargs -0 sha256sum | sha256sum)" = "$before" ]
}

@test "keeps the new skill and removes the old directory" {
  seed_old
  mkdir -p .cursor/skills/helmsman-setup
  printf '%s\n' 'new skill body' > .cursor/skills/helmsman-setup/SKILL.md
  git add -A
  git commit -q -m both
  run "$migrate"
  [ "$status" -eq 0 ]
  [ ! -e .cursor/skills/helmsmans-rig ]
  [ "$(cat .cursor/skills/helmsman-setup/SKILL.md)" = "new skill body" ]
}
