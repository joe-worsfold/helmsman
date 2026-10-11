#!/usr/bin/env bash
# Fail when a needed CI job failed. Skipped is success: a path filter did not run it.
# Usage: ci-ok.sh name=result ...
set -euo pipefail

if [[ $# -eq 0 && -n "${HELMSMAN_CI_RESULTS:-}" ]]; then
  read -r -a ci_items <<< "$HELMSMAN_CI_RESULTS"
  set -- "${ci_items[@]}"
fi

if [[ $# -eq 0 ]]; then
  echo "helmsman: ci-ok needs name=result arguments." >&2
  exit 2
fi

fail=0
for item in "$@"; do
  name="${item%%=*}"
  result="${item#*=}"
  if [[ -z "$name" || "$name" == "$item" ]]; then
    echo "helmsman: ci-ok argument must be name=result." >&2
    exit 2
  fi
  case "$result" in
    success | skipped) ;;
    *)
      echo "helmsman: $name $result" >&2
      fail=1
      ;;
  esac
done

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "helmsman: ci-ok."
