#!/usr/bin/env bash
# Run ./eval/run.sh once. On failure, retry once and report.
# Exit 0 when the first run passes, or when the retry passes.
# Exit 1 when both fail. A pass on retry is still reported.
set -euo pipefail

cd "$(dirname "$0")/.."

report() {
  printf '%s\n' "$1"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '%s\n' "$1" >> "$GITHUB_STEP_SUMMARY"
  fi
}

set +e
./eval/run.sh
first=$?
set -e
if [[ "$first" -eq 0 ]]; then
  report "helmsman: flake: first run passed"
  exit 0
fi

report "helmsman: flake: first run failed; retrying once"
set +e
./eval/run.sh
second=$?
set -e
if [[ "$second" -eq 0 ]]; then
  report "helmsman: flake: retry passed. The first run failed."
  exit 0
fi

report "helmsman: flake: retry failed"
exit 1
