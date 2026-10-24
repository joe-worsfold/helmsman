#!/usr/bin/env bats
# plugin/enable.sh pins the helmsman Claude Code plugin, and hooks-install.sh leaves the Claude hooks to it.

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

@test "enable drops the project lane cap hook" {
  mkdir -p .claude
  printf '%s\n' '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"bash .helmsman/tools/lanes/lanes.sh hook"}]}]}}' > .claude/settings.json
  run "$tools/plugin/enable.sh" "$sha"
  [ "$status" -eq 0 ]
  ! grep -F -q 'lanes/lanes.sh' .claude/settings.json
}

@test "without the plugin, hooks-install registers the lane cap hook for both tools" {
  run "$tools/watermark/hooks-install.sh"
  [ "$status" -eq 0 ]
  grep -F -q 'lanes/lanes.sh hook' .claude/settings.json
  grep -F -q 'lanes/lanes.sh hook' .cursor/hooks.json
  run "$tools/watermark/hooks-install.sh" --check
  [ "$status" -eq 0 ]
}

@test "check fails when the lane cap hook is missing" {
  mkdir -p .claude .cursor
  printf '%s\n' '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"node .helmsman/tools/watermark/hook.mjs"}]}]}}' > .claude/settings.json
  printf '%s\n' '{"version":1,"hooks":{"preToolUse":[{"command":"node .helmsman/tools/watermark/hook.mjs"}]}}' > .cursor/hooks.json
  run "$tools/watermark/hooks-install.sh" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"has no lane cap hook"* ]]
}

@test "--user copies the hook and registers it in the user's Claude and Cursor settings" {
  export HOME="$repo/home" CLAUDE_CONFIG_DIR="" HELMSMAN_HOME=""
  mkdir -p "$HOME/.claude" "$HOME/.cursor"
  printf '%s\n' '{"model":"opus","hooks":{"PreToolUse":[{"hooks":[{"type":"command","command":"status"}]}]}}' > "$HOME/.claude/settings.json"
  run "$tools/watermark/hooks-install.sh" --user
  [ "$status" -eq 0 ]
  dest="$HOME/.local/share/helmsman/watermark"
  [ -x "$dest/bin/gh" ] && [ -f "$dest/gh.mjs" ] && [ -f "$dest/hook.mjs" ]
  grep -F -q "node \\\"$dest/hook.mjs\\\"" "$HOME/.claude/settings.json"
  grep -F -q '"model": "opus"' "$HOME/.claude/settings.json"
  grep -F -q "$dest/hook.mjs" "$HOME/.cursor/hooks.json"
  run "$tools/watermark/hooks-install.sh" --user
  [ "$(grep -c "$dest/hook.mjs" "$HOME/.claude/settings.json")" -eq 1 ]
  run "$tools/watermark/hooks-install.sh" --user --check
  [ "$status" -eq 0 ]
}

@test "--user --check fails on a stale copy, and skips Cursor when it is not installed" {
  export HOME="$repo/home" CLAUDE_CONFIG_DIR="" HELMSMAN_HOME=""
  run "$tools/watermark/hooks-install.sh" --user
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/.cursor" ]
  printf '// old\n' >> "$HOME/.local/share/helmsman/watermark/gh.mjs"
  run "$tools/watermark/hooks-install.sh" --user --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"gh.mjs does not match"* ]]
}
