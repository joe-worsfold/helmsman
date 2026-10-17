#!/usr/bin/env bats
# .helmsman/tools/release/release.sh picks the next helmsman-v* tag from commit subjects.

setup() {
  repo="$(mktemp -d)"
  cd "$repo"
  git init -q
  git config user.email t@example.com
  git config user.name t
  release="$(cd "$(dirname "$BATS_TEST_FILENAME")/../release" && pwd)/release.sh"
}

teardown() {
  cd /tmp
  if [[ -n "${repo:-}" && -d "$repo" ]]; then
    rm -rf "$repo"
  fi
}

commit() { git commit -q --allow-empty -m "$1"; }

@test "the first feat releases 0.1.0" {
  commit "feat(plugin): ship it"
  run "$release" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"would release helmsman-v0.1.0 (minor)"* ]]
}

@test "a fix after a release moves the patch" {
  commit "feat: one"
  git tag helmsman-v0.1.0
  commit "fix(watermark): two"
  run "$release" --dry-run
  [[ "$output" == *"helmsman-v0.1.1 (patch)"* ]]
}

@test "docs and chore release nothing" {
  commit "feat: one"
  git tag helmsman-v0.1.0
  commit "docs(readme): words"
  commit "chore(toolchain): pins"
  run "$release" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to release"* ]]
}

@test "a breaking change moves the minor before 1.0 and the major after" {
  commit "feat: one"
  git tag helmsman-v0.3.2
  commit "feat(setup)!: drop the copy path"
  run "$release" --dry-run
  [[ "$output" == *"helmsman-v0.4.0 (breaking)"* ]]
  git tag helmsman-v1.2.3
  commit "$(printf 'fix: x\n\nBREAKING CHANGE: renamed')"
  run "$release" --dry-run
  [[ "$output" == *"helmsman-v2.0.0 (breaking)"* ]]
}

@test "the pull request title decides, not the commit list inside a squash" {
  commit "feat: one"
  git tag helmsman-v0.1.0
  commit "$(printf 'chore: squash title\n\n* fix(update): a commit inside the pull request')"
  run "$release" --dry-run
  [[ "$output" == *"Nothing to release"* ]]
}
