#!/usr/bin/env bash
# Save a command's stdout, stderr, and exit code under
# .helmsman/reports/prove/<pr>/<phase>/.
# GitHub Actions skips the command. Screenshots are not taken here.
set -euo pipefail

pr=""
phase=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)
      pr="${2:-}"
      shift 2
      ;;
    --phase)
      phase="${2:-}"
      shift 2
      ;;
    --help | -h)
      echo "helmsman: prove-record.sh --pr <slug> --phase baseline|treatment -- <command>"
      echo "helmsman: example: prove-record.sh --pr 12 --phase treatment -- pnpm test"
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  echo "helmsman: prove capture skipped in CI."
  exit 0
fi

if [[ -z "$pr" || -z "$phase" || $# -eq 0 ]]; then
  echo "helmsman: prove-record.sh --pr <slug> --phase baseline|treatment -- <command>" >&2
  exit 2
fi

case "$phase" in
  baseline | treatment) ;;
  *)
    echo "helmsman: phase must be baseline or treatment." >&2
    exit 2
    ;;
esac

if [[ ! "$pr" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "helmsman: pr slug must be letters, numbers, dots, or dashes." >&2
  exit 2
fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
dir="${root}/.helmsman/reports/prove/${pr}/${phase}"
mkdir -p "$dir"

set +e
"$@" >"${dir}/stdout.txt" 2>"${dir}/stderr.txt"
code=$?
set -e
printf '%s\n' "$code" > "${dir}/exit-code.txt"
echo "helmsman: recorded ${phase} for ${pr} (exit ${code}) in ${dir}"
exit "$code"
