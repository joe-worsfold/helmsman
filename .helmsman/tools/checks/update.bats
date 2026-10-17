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

fake_source() {
  fake="$(mktemp -d)"
  rsync -a --exclude node_modules --exclude upstream "$src/.helmsman/tools/" "$fake/.helmsman/tools/"
  mkdir -p "$fake/.github"
  cp "$src/lefthook.yml" "$fake/lefthook.yml"
  cp "$src/.github/PULL_REQUEST_TEMPLATE.md" "$fake/.github/PULL_REQUEST_TEMPLATE.md"
  printf '%s\n' 'one' 'two' 'three' 'four' 'five' 'six' > "$fake/.helmsman/tools/checks/forked.txt"
  git -C "$fake" init -q
  git -C "$fake" -c user.email=t@example.com -c user.name=t add -A
  git -C "$fake" -c user.email=t@example.com -c user.name=t commit -q -m base
}

fake_release() {
  sed -i.bak "s/^$1\$/$2/" "$fake/.helmsman/tools/checks/forked.txt" && rm -f "$fake/.helmsman/tools/checks/forked.txt.bak"
  git -C "$fake" -c user.email=t@example.com -c user.name=t commit -qam next
}

@test "a local fork keeps the repo's lines and takes the release's lines" {
  fake_source
  "$update" --from "$fake"
  sed -i.bak 's/^two$/two (repo)/' .helmsman/tools/checks/forked.txt && rm -f .helmsman/tools/checks/forked.txt.bak
  printf '%s\n' 'Local forks: .helmsman/tools/checks/forked.txt' >> .helmsman/setup.md
  fake_release five "five (release)"
  run "$update" --from "$fake"
  [ "$status" -eq 0 ]
  grep -qx 'two (repo)' .helmsman/tools/checks/forked.txt
  grep -qx 'five (release)' .helmsman/tools/checks/forked.txt
  [ "$(head -n 1 .helmsman/setup.md)" = "Helmsman: $(git -C "$fake" rev-parse HEAD)" ]
  rm -rf "$fake"
}

@test "a conflicting local fork stops the update and changes nothing" {
  fake_source
  "$update" --from "$fake"
  before="$(git -C "$fake" rev-parse HEAD)"
  sed -i.bak 's/^three$/three (repo)/' .helmsman/tools/checks/forked.txt && rm -f .helmsman/tools/checks/forked.txt.bak
  printf '%s\n' 'Local forks: .helmsman/tools/checks/forked.txt' >> .helmsman/setup.md
  fake_release three "three (release)"
  run "$update" --from "$fake"
  [ "$status" -eq 1 ]
  [[ "$output" == *"conflicts with the local fork .helmsman/tools/checks/forked.txt"* ]]
  grep -qx 'three (repo)' .helmsman/tools/checks/forked.txt
  [ "$(head -n 1 .helmsman/setup.md)" = "Helmsman: $before" ]
  rm -rf "$fake"
}

@test "a Helmsman line the source does not have stops the fork merge with a reason" {
  fake_source
  "$update" --from "$fake"
  sed -i.bak "s/^Helmsman:.*/Helmsman: $(printf 'a%.0s' {1..40})/" .helmsman/setup.md && rm -f .helmsman/setup.md.bak
  printf '%s\n' 'Local forks: .helmsman/tools/checks/forked.txt' >> .helmsman/setup.md
  run "$update" --from "$fake"
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not read Helmsman"* ]]
  rm -rf "$fake"
}
