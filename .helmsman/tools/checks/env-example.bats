#!/usr/bin/env bats
# .env.example lists every name product code reads, with no secret value.

setup() {
  repo="$(mktemp -d)"
  cd "$repo"
  git init -q
  git config user.email "gate@example.com"
  git config user.name "gate"
  checks="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  mkdir -p src
  git commit --allow-empty -q -m init
}

teardown() {
  cd /tmp
  if [[ -n "${repo:-}" && -d "$repo" ]]; then
    rm -rf "$repo"
  fi
}

@test "no env reads is not a failure" {
  printf '%s\n' 'export function tax(n) { return n; }' > src/tax.js
  run "$checks/env-example.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no env reads"* ]]
}

@test "a read without .env.example fails" {
  printf '%s\n' 'export function port() { return process.env.PORT; }' > src/listen.js
  run "$checks/env-example.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing PORT"* ]]
}

@test "a listed name passes and a secret value fails" {
  printf '%s\n' 'export function port() { return process.env.PORT; }' > src/listen.js
  printf '%s\n' 'PORT=' > .env.example
  run "$checks/env-example.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"env example ok."* ]]
  token="$(printf '%s_%s' 'ghp' 'abcdefghijklmnopqrstuvwxyz')"
  printf '%s\n' "PORT=${token}" > .env.example
  run "$checks/env-example.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"looks like a secret"* ]]
}

@test "vite and CI names are not example keys" {
  printf '%s\n' \
    'export const mode = import.meta.env.DEV;' \
    'export const ci = process.env.CI;' \
    'export const port = process.env.PORT;' > src/listen.js
  printf '%s\n' 'PORT=' > .env.example
  run "$checks/env-example.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"env example ok."* ]]
}

@test "tests and fixtures are not product reads" {
  mkdir -p test fixture/src
  printf '%s\n' 'process.env.ONLY_TEST' > test/listen.test.js
  printf '%s\n' 'process.env.ONLY_FIXTURE' > fixture/src/listen.js
  run "$checks/env-example.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no env reads"* ]]
}
