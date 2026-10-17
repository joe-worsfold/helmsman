#!/usr/bin/env bats
# plugin/enable.sh pins the helmsman Claude Code plugin, and hooks-install.sh leaves the Claude hook to it.

setup() {
  repo="$(mktemp -d)"
  cd "$repo"
  git init -q
  tools="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  sha="4b1c2362c58d7093fe0d5ab44281673f79ea7db4"
}

teardown() {
  cd /tmp
  if [[ -n "${repo:-}" && -d "$repo" ]]; then
    rm -rf "$repo"
  fi
}

@test "enable pins the sha, keeps other settings, and drops the project watermark hook" {
  mkdir -p .claude
  printf '%s\n' '{"permissions":{"allow":["Bash(ls)"]},"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"node .helmsman/tools/watermark/hook.mjs"}]}]}}' > .claude/settings.json
  run "$tools/plugin/enable.sh" "$sha"
  [ "$status" -eq 0 ]
  grep -F -q "\"sha\": \"$sha\"" .claude/settings.json
  grep -F -q '"helmsman@helmsman": true' .claude/settings.json
  grep -F -q 'Bash(ls)' .claude/settings.json
  ! grep -F -q 'watermark/hook.mjs' .claude/settings.json
  run "$tools/plugin/enable.sh" --check
  [ "$status" -eq 0 ]
}

@test "enable refuses a short sha and check fails before it runs" {
  run "$tools/plugin/enable.sh" abc123
  [ "$status" -eq 2 ]
  run "$tools/plugin/enable.sh" --check
  [ "$status" -eq 1 ]
}

@test "with the plugin enabled, hooks-install registers only the Cursor hook" {
  "$tools/plugin/enable.sh" "$sha"
  run "$tools/watermark/hooks-install.sh"
  [ "$status" -eq 0 ]
  ! grep -F -q 'watermark/hook.mjs' .claude/settings.json
  grep -F -q 'watermark/hook.mjs' .cursor/hooks.json
  run "$tools/watermark/hooks-install.sh" --check
  [ "$status" -eq 0 ]
}
