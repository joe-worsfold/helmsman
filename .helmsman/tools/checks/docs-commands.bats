#!/usr/bin/env bats
# Documented commands exist, and a stated Node version matches the pin.

setup() {
  repo="$(mktemp -d)"
  cd "$repo"
  git init -q
  git config user.email "gate@example.com"
  git config user.name "gate"
  checks="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  git commit --allow-empty -q -m init
}

teardown() {
  cd /tmp
  if [[ -n "${repo:-}" && -d "$repo" ]]; then
    rm -rf "$repo"
  fi
}

@test "a documented pnpm script must exist" {
  printf '%s\n' '{"scripts":{"test":"node --test"}}' > package.json
  printf '%s\n' '# Demo' '' '```bash' 'pnpm missing' '```' > README.md
  run "$checks/docs-commands.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no missing script"* ]]
}

@test "pnpm install and a real script pass" {
  printf '%s\n' '{"scripts":{"test":"node --test"}}' > package.json
  printf '%s\n' '# Demo' '' '```bash' 'pnpm install --frozen-lockfile' 'pnpm test' '```' > README.md
  run "$checks/docs-commands.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"docs commands ok"* ]]
}

@test "a stated Node version must match .nvmrc" {
  mkdir -p eval
  printf '%s\n' '26.11.1' > .nvmrc
  printf '%s\n' '# Demo' '' 'Use Node 20 or newer.' > eval/README.md
  run "$checks/docs-commands.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Node 20"* ]]
  printf '%s\n' '# Demo' '' 'Use Node 26.11.1.' > eval/README.md
  printf '%s\n' '{"engines":{"node":">=26.11.1"}}' > package.json
  run "$checks/docs-commands.sh"
  [ "$status" -eq 0 ]
}

@test "engines must name the .nvmrc version" {
  printf '%s\n' '26.11.1' > .nvmrc
  printf '%s\n' '{"engines":{"node":">=20"}}' > package.json
  run "$checks/docs-commands.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *".nvmrc is 26.11.1"* ]]
}

@test "a documented path and make target must exist" {
  printf '%s\n' '# Demo' '' '```bash' './missing.sh' '```' > README.md
  run "$checks/docs-commands.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing.sh"* ]]
  printf '%s\n' '#!/bin/sh' 'echo ok' > ok.sh
  printf '%s\n' 'check:' '	node --test' > Makefile
  printf '%s\n' '# Demo' '' '```bash' './ok.sh' 'make check' '```' > README.md
  run "$checks/docs-commands.sh"
  [ "$status" -eq 0 ]
}

@test "AGENTS.md above 900 words fails and above 400 warns" {
  words=""
  for i in $(seq 1 401); do words+="word "; done
  printf '%s\n' "$words" > AGENTS.md
  run "$checks/agents-words.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Warn above 400"* ]]
  [[ "$output" == *"words ok"* ]]
  words=""
  for i in $(seq 1 901); do words+="word "; done
  printf '%s\n' "$words" > AGENTS.md
  run "$checks/agents-words.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Fail above 900"* ]]
}
