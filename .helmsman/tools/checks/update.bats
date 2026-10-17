#!/usr/bin/env bats
# .helmsman/tools/update.sh copies one Helmsman checkout into a repo and moves the pin.

setup() {
  repo="$(mktemp -d)"
  cd "$repo"
  git init -q
  src="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
  update="$src/.helmsman/tools/update.sh"
  mkdir -p .helmsman .cursor/rules .cursor/skills/my-skill .cursor/skills/helmsman-gone
  printf '%s\n' 'Helmsman: old' 'CI: github' > .helmsman/setup.md
  printf '%s\n' 'own' > .cursor/rules/my-rule.mdc
  printf '%s\n' 'own' > .cursor/skills/my-skill/SKILL.md
  printf '%s\n' 'old' > .cursor/skills/helmsman-gone/SKILL.md
  printf '%s\n' '{}' > package.json
}

teardown() {
  cd /tmp
  if [[ -n "${repo:-}" && -d "$repo" ]]; then
    rm -rf "$repo"
  fi
}

@test "update copies helmsman files, keeps the repo's own, and moves the pin" {
  run "$update" --from "$src"
  [ "$status" -eq 0 ]
  [ "$(head -n 1 .helmsman/setup.md)" = "Helmsman: $(git -C "$src" rev-parse HEAD)" ]
  [ -f .cursor/skills/helmsman-review/SKILL.md ]
  [ -f .cursor/skills/my-skill/SKILL.md ]
  [ -f .cursor/rules/my-rule.mdc ]
  [ ! -e .cursor/skills/helmsman-gone ]
  [ -f .helmsman/tools/update.sh ]
  [ ! -e .helmsman/tools/upstream ]
  [ -f .github/workflows/helmsman.yml ]
}

@test "dry run writes nothing" {
  run "$update" --dry-run --from "$src"
  [ "$status" -eq 0 ]
  [ "$(head -n 1 .helmsman/setup.md)" = "Helmsman: old" ]
  [ ! -e .helmsman/tools ]
  [ -d .cursor/skills/helmsman-gone ]
}

@test "a second run changes nothing" {
  "$update" --from "$src"
  before="$(find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 shasum | shasum)"
  "$update" --from "$src"
  after="$(find . -path ./.git -prune -o -type f -print0 | sort -z | xargs -0 shasum | shasum)"
  [ "$before" = "$after" ]
}
