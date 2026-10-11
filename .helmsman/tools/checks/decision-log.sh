#!/usr/bin/env bash
# Append one decision row to a TSV log.
# Usage: decision-log.sh <file> <phase> <decision> <why> <evidence> <result>
set -euo pipefail

if [[ $# -ne 6 ]]; then
  echo "helmsman: usage: decision-log.sh <file> <phase> <decision> <why> <evidence> <result>" >&2
  exit 2
fi

logfile="$1"
shift

logdir="$(dirname "$logfile")"
if [[ -n "$logdir" && "$logdir" != "." && ! -d "$logdir" ]]; then
  mkdir -p "$logdir"
fi

# Append the header. Never truncate. A failed test on a network disk must not wipe the rows.
if [[ ! -s "$logfile" ]]; then
  printf '%s\n' $'ts\tphase\tdecision\twhy\tevidence\tresult' >> "$logfile"
fi

clean() {
  local value
  value="$(printf '%s' "$1" | tr '\t\n\r' '   ')"
  case "$value" in
    =*|+*|-*|@*) printf "'%s" "$value" ;;
    *) printf '%s' "$value" ;;
  esac
}

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$ts" "$(clean "$1")" "$(clean "$2")" "$(clean "$3")" "$(clean "$4")" "$(clean "$5")" \
  >> "$logfile"
