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
  want harness || return 0
  if [[ ! -f eval/flake.sh ]]; then
    echo "helmsman: no harness suite."
    return 0
  fi
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
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

shell_lint() {
  want bash || return 0
  "$here/bash-n.sh"
  "$here/no-silences.sh"
}

run_languages() {
  local task="$1" lang
  shift
  for lang in "$@"; do
    if want "$lang"; then "$here/task.sh" "$lang" "$task"; fi
  done
}

# Root or harness tsc, for a repo whose TypeScript is not in a package.
typecheck_root() {
  if [[ -f eval/tsconfig.json ]] && want harness; then
    run_tsc eval/tsconfig.json
  elif ! has_ts_package && [[ -f tsconfig.json ]] && want ts; then
    run_tsc tsconfig.json
  fi
}

# The CI smoke job installs the Playwright browser only when the setup file names Playwright.
install_playwright() {
  [[ "${GITHUB_ACTIONS:-}" == "true" && -f .helmsman/setup.md ]] || return 0
  grep -qi playwright .helmsman/setup.md || return 0
  if command -v pnpm >/dev/null 2>&1; then
    pnpm exec playwright install --with-deps chromium
  fi
}

case "$cmd" in
  lint)
    run_languages lint ts rust python
    shell_lint
    ;;
  format)
    run_languages format ts rust
    # Ruff format is part of the Python lint, so only a Python-only run asks for it here.
    if [[ "$filter" == "python" ]]; then "$here/task.sh" python lint; fi
    ;;
  typecheck)
    run_languages typecheck ts python
    typecheck_root
    ;;
  unused)
    "$here/task.sh" ts unused
    ;;
  test)
    "$here/repo-checks.sh"
    run_languages test ts rust python
    harness_test
    ;;
  integration | audit | diff-guard | plain)
    "$here/task.sh" "$cmd"
    ;;
  smoke)
    install_playwright
    "$here/task.sh" smoke
    ;;
  setup)
    "$here/task.sh" setup
    "$here/repo-checks.sh"
    ;;
  check)
    for step in lint format typecheck unused test; do
      HELMSMAN_FILTER= "$here/pnpm-task.sh" "$step"
    done
    ;;
  *)
    echo "helmsman: pnpm-task.sh lint|format|typecheck|unused|test|integration|smoke|audit|setup|diff-guard|plain|check" >&2
    exit 2
    ;;
esac
