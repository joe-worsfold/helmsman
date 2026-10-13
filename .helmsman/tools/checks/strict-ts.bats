#!/usr/bin/env bats
# Product tsconfig strict mode. Comments, solution files, and extends are valid.

setup() {
  repo="$(mktemp -d)"
  cd "$repo"
  git init -q
  git config user.email "gate@example.com"
  git config user.name "gate"
  checks="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
}

teardown() {
  cd /tmp
  if [[ -n "${repo:-}" && -d "$repo" ]]; then
    rm -rf "$repo"
  fi
}

@test "comments, a solution file, and extends pass" {
  printf '%s\n' '{' '  "files": [],' '  "references": [{ "path": "./tsconfig.app.json" }]' '}' > tsconfig.json
  printf '%s\n' '{' '  // app' '  "extends": "./tsconfig.base.json",' '  "compilerOptions": { "target": "ES2022", }' '}' > tsconfig.app.json
  printf '%s\n' '{' '  "compilerOptions": { "strict": false }' '}' > tsconfig.loose.json
  run "$checks/../tsc/check.sh" --strict
  [ "$status" -eq 1 ]
  [[ "$output" == *"tsconfig.loose.json"* ]]
  rm tsconfig.loose.json
  run "$checks/../tsc/check.sh" --strict
  [ "$status" -eq 0 ]
  [[ "$output" == *"strict tsconfig ok"* ]]
}

@test "a glob or path alias inside a string is not a comment" {
  printf '%s\n' '{' '  /* real comment */' '  "compilerOptions": {' '    "strict": true,' '    "paths": { "@/*": ["./src/*"] }' '  },' '  "exclude": ["src/**/*.test.ts"]' '}' > tsconfig.json
  run "$checks/../tsc/check.sh" --strict
  [ "$status" -eq 0 ]
  [[ "$output" == *"strict tsconfig ok"* ]]
}
