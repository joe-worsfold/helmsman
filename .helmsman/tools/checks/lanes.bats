#!/usr/bin/env bats
# Lanes: the budget sets the lane count, and the hook refuses a worktree past it.

setup() {
  base="$(mktemp -d)"
  root="$base/code"
  mkdir -p "$root"
  lanes="$(cd "$(dirname "$BATS_TEST_FILENAME")/../lanes" && pwd)/lanes.sh"
  export HELMSMAN_LANES_FILE="$base/lanes"
  git init -q -b main "$root/app"
  git -C "$root/app" -c user.email=gate@example.com -c user.name=gate commit -q --allow-empty -m init
  git -C "$root/app" worktree add -q "$root/app-one" -b agent/one/task
  git -C "$root/app" worktree add -q "$root/app-two" -b agent/two/task
}

teardown() {
  cd /tmp
  if [[ -n "${base:-}" && -d "$base" ]]; then
    rm -rf "$base"
  fi
}

@test "no budget means no cap" {
  run bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cd x && git -C app worktree add ../three\"}}' | '$lanes' hook"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "budget with no built lane uses the default lane size" {
  run "$lanes" budget 30 "$root"
  [ "$status" -eq 0 ]
  grep -q '^Lane size: 10G$' "$HELMSMAN_LANES_FILE"
  grep -q '^Lanes: 3$' "$HELMSMAN_LANES_FILE"
}

@test "budget measures the largest lane that has built" {
  mkdir -p "$root/app-one/target"
  "$lanes" budget 30 "$root"
  grep -q '^Lane size: 1G$' "$HELMSMAN_LANES_FILE"
  grep -q '^Lanes: 30$' "$HELMSMAN_LANES_FILE"
}

@test "dry run writes nothing" {
  run "$lanes" budget 30 "$root" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"would write"* ]]
  [ ! -f "$HELMSMAN_LANES_FILE" ]
}

@test "the repo's own checkout is not a lane" {
  "$lanes" budget 30 "$root"
  run "$lanes"
  [[ "$output" == *"2 of 3 in use"* ]]
  [[ "$output" != *"app [main]"* ]]
}

@test "hook denies a worktree when every lane is in use" {
  "$lanes" budget 20 "$root"
  run bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cd app && git -C . worktree add ../three\"}}' | '$lanes' hook"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
  [[ "$output" == *"app-one [agent/one/task]"* ]]
}

@test "hook allows a worktree while a lane is free" {
  "$lanes" budget 30 "$root"
  run bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git worktree add ../three\"}}' | '$lanes' hook"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hook ignores other commands and agents without a worktree" {
  "$lanes" budget 20 "$root"
  run bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git worktree list\"}}' | '$lanes' hook"
  [ -z "$output" ]
  run bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo run git worktree add later\"}}' | '$lanes' hook"
  [ -z "$output" ]
  run bash -c "printf '%s' '{\"tool_name\":\"Agent\",\"tool_input\":{\"prompt\":\"look at the worktree\"}}' | '$lanes' hook"
  [ -z "$output" ]
  run bash -c "printf '%s' '{\"tool_name\":\"Agent\",\"tool_input\":{\"isolation\":\"worktree\"}}' | '$lanes' hook"
  [[ "$output" == *'"deny"'* ]]
}
