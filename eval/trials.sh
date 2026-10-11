#!/usr/bin/env bash
# Repeat ./eval/run.sh and report how many trials passed.
# CI runs this script. A failed trial still counts, then the job fails.
# This script does not retry. eval/flake.sh retries a single run once.
set -euo pipefail

cd "$(dirname "$0")/.."
n="${1:-3}"
if ! [[ "$n" =~ ^[1-9][0-9]*$ ]]; then
  echo "helmsman: trial count must be a positive integer." >&2
  exit 2
fi

ok=0
i=1
while [[ "$i" -le "$n" ]]; do
  set +e
  ./eval/run.sh
  status=$?
  set -e
  if [[ "$status" -eq 0 ]]; then
    ok=$((ok + 1))
    echo "helmsman: eval trial $i/$n passed"
  else
    echo "helmsman: eval trial $i/$n failed" >&2
  fi
  i=$((i + 1))
done

echo "helmsman: eval trials $ok/$n"
if [[ "$ok" -ne "$n" ]]; then
  exit 1
fi
