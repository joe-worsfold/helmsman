#!/usr/bin/env bats
# .helmsman/tools/claude/emit.sh writes .claude/ from .cursor/, and --check fails on drift.

setup() {
  repo="$(mktemp -d)"
  cd "$repo"
  git init -q
  emit="$(cd "$(dirname "$BATS_TEST_FILENAME")/../claude" && pwd)/emit.sh"
  mkdir -p .cursor/rules .cursor/skills/helmsman-review
  printf '%s\n' '---' 'description: Always.' 'alwaysApply: true' '---' '' '# Standards' 'Body.' > .cursor/rules/helmsman-standards.mdc
  printf '%s\n' '---' 'description: Rust.' 'globs:' '  - "**/*.rs"' '  - "**/Cargo.toml"' 'alwaysApply: false' '---' '' '# Rust' > .cursor/rules/helmsman-rust.mdc
  printf '%s\n' '---' 'description: Loaded by review only.' 'alwaysApply: false' '---' '' '# Checklist' > .cursor/rules/helmsman-checklist.mdc
  printf '%s\n' '---' 'description: Writing.' 'globs:' '  - "**/*.md"' 'alwaysApply: false' '---' '' '# Writing' > .cursor/rules/helmsman-writing.mdc
  printf '%s\n' '---' 'name: helmsman-review' 'description: Review.' '---' > .cursor/skills/helmsman-review/SKILL.md
  printf '%s\n' '# Agents' > AGENTS.md
}

teardown() {
  cd /tmp
  if [[ -n "${repo:-}" && -d "$repo" ]]; then
    rm -rf "$repo"
  fi
}

@test "an always rule loses its frontmatter and a glob rule gets paths" {
  run "$emit"
  [ "$status" -eq 0 ]
  [ "$(head -n 1 .claude/rules/helmsman-standards.md)" != "---" ]
  grep -F -q '# Standards' .claude/rules/helmsman-standards.md
  [ "$(head -n 1 .claude/rules/helmsman-rust.md)" = "---" ]
  grep -F -q 'paths:' .claude/rules/helmsman-rust.md
  grep -F -q '  - "**/Cargo.toml"' .claude/rules/helmsman-rust.md
  ! grep -F -q 'alwaysApply' .claude/rules/helmsman-rust.md
}

@test "the checklist is not emitted and writing loads every session" {
  run "$emit"
  [ "$status" -eq 0 ]
  [ ! -e .claude/rules/helmsman-checklist.md ]
  [ "$(head -n 1 .claude/rules/helmsman-writing.md)" != "---" ]
}

@test "a skill is a relative link and CLAUDE.md imports AGENTS.md" {
  run "$emit"
  [ "$status" -eq 0 ]
  [ -L .claude/skills/helmsman-review ]
  [ "$(readlink .claude/skills/helmsman-review)" = "../../.cursor/skills/helmsman-review" ]
  [ -f .claude/skills/helmsman-review/SKILL.md ]
  [ "$(cat CLAUDE.md)" = "@AGENTS.md" ]
}

@test "a second run changes nothing and check passes" {
  "$emit"
  before="$(find .claude CLAUDE.md -exec ls -ld {} + | shasum)"
  "$emit"
  after="$(find .claude CLAUDE.md -exec ls -ld {} + | shasum)"
  [ "$before" = "$after" ]
  run "$emit" --check
  [ "$status" -eq 0 ]
}

@test "check fails when a generated rule was edited by hand" {
  "$emit"
  printf '%s\n' 'hand edit' >> .claude/rules/helmsman-rust.md
  run "$emit" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"helmsman-rust.md is not what emit.sh writes"* ]]
}

@test "check fails when the source changed and nothing was emitted" {
  "$emit"
  printf '%s\n' 'New line.' >> .cursor/rules/helmsman-standards.mdc
  run "$emit" --check
  [ "$status" -eq 1 ]
}

@test "a rule the repo wrote itself is left alone" {
  mkdir -p .claude/rules
  printf '%s\n' '# Our own rust rule' > .claude/rules/helmsman-rust.md
  run "$emit"
  [ "$status" -eq 0 ]
  [ "$(cat .claude/rules/helmsman-rust.md)" = "# Our own rust rule" ]
  run "$emit" --check
  [ "$status" -eq 0 ]
}

@test "a generated rule whose source is gone is removed" {
  "$emit"
  rm .cursor/rules/helmsman-rust.mdc
  run "$emit" --check
  [ "$status" -eq 1 ]
  "$emit"
  [ ! -e .claude/rules/helmsman-rust.md ]
}

@test "a CLAUDE.md that does not import AGENTS.md fails" {
  printf '%s\n' '# Our notes' > CLAUDE.md
  run "$emit" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not import @AGENTS.md"* ]]
  [ "$(cat CLAUDE.md)" = "# Our notes" ]
}

@test "a CLAUDE.md that imports ./AGENTS.md passes" {
  printf '%s\n' '# Our notes' '@./AGENTS.md' > CLAUDE.md
  "$emit"
  run "$emit" --check
  [ "$status" -eq 0 ]
  [ "$(head -n 1 CLAUDE.md)" = "# Our notes" ]
}

@test "a repo with no Cursor rules or skills is skipped" {
  rm -rf .cursor
  run "$emit" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"not emitted"* ]]
}
