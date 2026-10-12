#!/usr/bin/env bash
# Root package scripts. CI and a developer run the same names.
# HELMSMAN_FILTER selects one language. Unset runs every language this repo has.
# GITHUB_ACTIONS or HELMSMAN_AFFECTED=1 adds turbo --affected.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

cmd="${1:-}"
filter="${HELMSMAN_FILTER:-}"

want() {
  local name="$1"
  [[ -z "$filter" || "$filter" == "$name" ]]
}

harness_test() {
  if [[ ! -f eval/flake.sh ]]; then
    echo "helmsman: no harness suite."
    return 0
  fi
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    if ! command -v bats >/dev/null 2>&1; then
      sudo apt-get update
      sudo apt-get install -y bats
    fi
    ./eval/flake.sh
    ./eval/trials.sh 3
    return 0
  fi
  ./eval/run.sh
}

run_tsc() {
  local project="$1"
  echo "helmsman: tsc ${project}"
  if [[ -d node_modules/.bin ]]; then
    PATH="$root/node_modules/.bin:$PATH"
  fi
  tsc --noEmit -p "$project"
}

has_ts_package() {
  local dir
  shopt -s nullglob
  for dir in packages/*/ts apps/web apps/mobile; do
    if [[ -f "$dir/package.json" ]]; then
      shopt -u nullglob
      return 0
    fi
  done
  shopt -u nullglob
  return 1
}

case "$cmd" in
  lint)
    if want ts; then "$here/task.sh" ts lint; fi
    if want rust; then "$here/task.sh" rust lint; fi
    if want python; then "$here/task.sh" python lint; fi
    if want bash; then
      "$here/bash-n.sh"
      "$here/no-silences.sh"
    fi
    ;;
  format)
    if want ts; then "$here/task.sh" ts format; fi
    if want rust; then "$here/task.sh" rust format; fi
    if [[ "$filter" == "python" ]]; then "$here/task.sh" python lint; fi
    ;;
  typecheck)
    if want ts; then "$here/task.sh" ts typecheck; fi
    if want python; then "$here/task.sh" python typecheck; fi
    if [[ -f eval/tsconfig.json && ( -z "$filter" || "$filter" == "harness" ) ]]; then
      run_tsc eval/tsconfig.json
    elif ! has_ts_package && [[ -f tsconfig.json && ( -z "$filter" || "$filter" == "ts" ) ]]; then
      run_tsc tsconfig.json
    fi
    ;;
  unused)
    "$here/task.sh" ts unused
    ;;
  test)
    "$here/repo-checks.sh"
    if want ts; then "$here/task.sh" ts test; fi
    if want rust; then "$here/task.sh" rust test; fi
    if want python; then "$here/task.sh" python test; fi
    if want harness || [[ -z "$filter" ]]; then
      harness_test
    fi
    ;;
  integration)
    "$here/task.sh" integration
    ;;
  smoke)
    if [[ "${GITHUB_ACTIONS:-}" == "true" && -f .helmsman/setup.md ]] && grep -qi playwright .helmsman/setup.md; then
      if command -v pnpm >/dev/null 2>&1; then
        pnpm exec playwright install --with-deps chromium
      fi
    fi
    "$here/task.sh" smoke
    ;;
  audit)
    "$here/task.sh" audit
    ;;
  setup)
    "$here/task.sh" setup
    "$here/repo-checks.sh"
    ;;
  diff-guard)
    "$here/task.sh" diff-guard
    ;;
  plain)
    "$here/task.sh" plain
    ;;
  check)
    HELMSMAN_FILTER= "$here/pnpm-task.sh" lint
    HELMSMAN_FILTER= "$here/pnpm-task.sh" format
    HELMSMAN_FILTER= "$here/pnpm-task.sh" typecheck
    HELMSMAN_FILTER= "$here/pnpm-task.sh" unused
    HELMSMAN_FILTER= "$here/pnpm-task.sh" test
    ;;
  *)
    echo "helmsman: pnpm-task.sh lint|format|typecheck|unused|test|integration|smoke|audit|setup|diff-guard|plain|check" >&2
    exit 2
    ;;
esac
