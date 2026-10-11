#!/usr/bin/env bats
# Migration from tools/helmsman to .helmsman/tools. Temp git repos.

setup() {
  repo="$(mktemp -d)"
  cd "$repo"
  git init -q
  git config user.email "gate@example.com"
  git config user.name "gate"
  migrate="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/migrate-layout.sh"
}

teardown() {
  cd /tmp
  if [[ -n "${repo:-}" && -d "$repo" ]]; then
    rm -rf "$repo"
  fi
}

seed_old() {
  mkdir -p tools/helmsman/checks .helmsman .cursor/skills/helmsman-setup
  printf '%s\n' 'echo tools/helmsman/checks/setup-check.sh' > tools/helmsman/checks/setup-check.sh
  printf '%s\n' 'run: tools/helmsman/checks/setup-check.sh' > lefthook.yml
  printf '%s\n' '.helmsman/*' '!.helmsman/setup.md' > .gitignore
  printf '%s\n' '# Setup' > .helmsman/setup.md
  printf '%s\n' 'keep tools/helmsman in the skill' > .cursor/skills/helmsman-setup/SKILL.md
  printf '%s\n' '{"scripts":{"gate":"tools/helmsman/checks/languages.sh"}}' > package.json
  git add -A
  git commit -q -m init
}

@test "moves the old tree, rewrites references, and keeps reports ignored" {
  seed_old
  run "$migrate"
  [ "$status" -eq 0 ]
  [ ! -e tools/helmsman ]
  [ ! -e tools ]
  [ -f .helmsman/tools/checks/setup-check.sh ]
  grep -F -q '.helmsman/tools/checks/setup-check.sh' lefthook.yml
  grep -F -q '.helmsman/tools/checks/setup-check.sh' .helmsman/tools/checks/setup-check.sh
  grep -F -q '.helmsman/tools/checks/languages.sh' package.json
  grep -F -q 'keep tools/helmsman in the skill' .cursor/skills/helmsman-setup/SKILL.md
  [ -z "$(git ls-files -- tools/helmsman)" ]
  git ls-files -- .helmsman/tools/checks/setup-check.sh | grep -q setup-check.sh
  run git check-ignore -q -- .helmsman/tools/checks/setup-check.sh
  [ "$status" -eq 1 ]
  run git check-ignore -q -- .helmsman/setup.md
  [ "$status" -eq 1 ]
  mkdir -p .helmsman/reports
  printf 'x\n' > .helmsman/reports/readiness.md
  run git check-ignore -q -- .helmsman/reports/readiness.md
  [ "$status" -eq 0 ]
}

@test "a second run changes nothing" {
  seed_old
  run "$migrate"
  [ "$status" -eq 0 ]
  before="$(sha256sum lefthook.yml .gitignore .helmsman/tools/checks/setup-check.sh package.json | sha256sum)"
  run "$migrate"
  [ "$status" -eq 0 ]
  [ "$(sha256sum lefthook.yml .gitignore .helmsman/tools/checks/setup-check.sh package.json | sha256sum)" = "$before" ]
  [ "$(grep -c -F -x '!.helmsman/tools/' .gitignore)" -eq 1 ]
  [ "$(grep -c -F -x '!.helmsman/tools/**' .gitignore)" -eq 1 ]
  [[ "$output" == *"layout is .helmsman/tools"* ]]
}

@test "keeps the new tree and removes the old directory" {
  seed_old
  mkdir -p .helmsman/tools/checks
  printf 'new\n' > .helmsman/tools/checks/setup-check.sh
  printf 'only-old\n' > tools/helmsman/checks/extra.sh
  run "$migrate"
  [ "$status" -eq 0 ]
  [ ! -e tools/helmsman ]
  [ "$(cat .helmsman/tools/checks/setup-check.sh)" = "new" ]
  [ "$(cat .helmsman/tools/checks/extra.sh)" = "only-old" ]
}

@test "a tools exception does not un-ignore node_modules" {
  seed_old
  printf '%s\n' 'node_modules/' 'target/' > .gitignore
  printf '%s\n' '.helmsman/*' '!.helmsman/setup.md' >> .gitignore
  run "$migrate"
  [ "$status" -eq 0 ]
  mkdir -p .helmsman/tools/eslint/node_modules/pkg .helmsman/reports
  printf 'x\n' > .helmsman/tools/eslint/node_modules/pkg/index.js
  printf 'x\n' > .helmsman/reports/readiness.md
  run git check-ignore -q -- .helmsman/tools/checks/setup-check.sh
  [ "$status" -eq 1 ]
  run git check-ignore -q -- .helmsman/tools/eslint/node_modules/pkg/index.js
  [ "$status" -eq 0 ]
  run git check-ignore -q -- .helmsman/reports/readiness.md
  [ "$status" -eq 0 ]
}

@test "an ignore of the old directory does not ignore the new one" {
  seed_old
  printf '%s\n' 'tools/helmsman/' >> .gitignore
  run "$migrate"
  [ "$status" -eq 0 ]
  run git check-ignore -q -- .helmsman/tools/checks/setup-check.sh
  [ "$status" -eq 1 ]
  run grep -F -x 'tools/helmsman/' .gitignore
  [ "$status" -eq 1 ]
  run grep -F -x '.helmsman/tools/' .gitignore
  [ "$status" -eq 1 ]
}

@test "an airbnb url that contains the old path is not turned into the harness path" {
  seed_old
  printf '%s\n' 'https://github.com/airbnb/javascript/blob/master/tools/helmsman/eslint-config-airbnb-base/rules/style.js' > note.md
  git add note.md
  run "$migrate"
  [ "$status" -eq 0 ]
  grep -F -q 'packages/eslint-config-airbnb-base' note.md
  run grep -F '.helmsman/tools/eslint-config' note.md
  [ "$status" -eq 1 ]
}
