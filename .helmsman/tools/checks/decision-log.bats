#!/usr/bin/env bats
# Decision log rows stay on one line, and a formula cell is quoted.

setup() {
  repo="$(mktemp -d)"
  cd "$repo"
  checks="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
}

teardown() {
  cd /tmp
  if [[ -n "${repo:-}" && -d "$repo" ]]; then
    rm -rf "$repo"
  fi
}

@test "appends a header once and quotes a formula" {
  run "$checks/decision-log.sh" decisions.tsv phase "picked the check" "it fails the build" "a811a37" "tests passed"
  [ "$status" -eq 0 ]
  run "$checks/decision-log.sh" decisions.tsv phase "=cmd" "why" "evidence" "open"
  [ "$status" -eq 0 ]
  [ "$(wc -l < decisions.tsv | tr -d ' ')" -eq 3 ]
  grep -q $'ts\tphase\tdecision' decisions.tsv
  grep -q $'\t'"'"'=cmd'$'\t' decisions.tsv
}

@test "a second header is not written" {
  "$checks/decision-log.sh" decisions.tsv phase one why evidence result
  "$checks/decision-log.sh" decisions.tsv phase two why evidence result
  [ "$(grep -c $'^ts\t' decisions.tsv)" -eq 1 ]
}
