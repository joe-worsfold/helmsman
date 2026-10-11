#!/usr/bin/env bash
# One command per CI check. The same command runs locally.
# task.sh <family> <task>
# task.sh all
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"
here="$(cd "$(dirname "$0")" && pwd)"

filters=()

package_filters() {
  local pattern dir
  filters=()
  shopt -s nullglob
  for pattern in "$@"; do
    for dir in $pattern; do
      if [[ -f "$dir/package.json" ]]; then
        filters+=(--filter="./$dir")
      fi
    done
  done
  shopt -u nullglob
}

run_turbo() {
  local task="$1"
  shift
  if [[ ! -f turbo.json ]]; then
    echo "helmsman: no turbo.json. ${task} skipped."
    return 0
  fi
  if [[ $# -eq 0 ]]; then
    echo "helmsman: no package defines ${task}."
    return 0
  fi
  if ! command -v pnpm >/dev/null 2>&1; then
    echo "helmsman: turbo.json exists but pnpm is not installed." >&2
    return 1
  fi
  local affected=()
  if [[ "${GITHUB_ACTIONS:-}" == "true" || "${HELMSMAN_AFFECTED:-}" == "1" ]]; then
    affected+=(--affected)
  fi
  echo "helmsman: turbo run ${task} ${affected[*]} $*"
  pnpm exec turbo run "$task" --output-logs=errors-only "${affected[@]}" "$@"
}

root_eslint() {
  local candidate repo_eslint=""
  for candidate in eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts; do
    if [[ -f "$candidate" ]]; then
      repo_eslint="$candidate"
      break
    fi
  done
  if [[ -z "$repo_eslint" ]]; then
    echo "helmsman: no ESLint config. ESLint is not installed."
    return 0
  fi
  if ! grep -q -E 'helmsman|\.helmsman/tools/eslint' "$repo_eslint"; then
    echo "helmsman: ESLint config does not reference the Helmsman gate. ESLint is not installed."
    return 0
  fi
  if ! command -v npx >/dev/null 2>&1; then
    echo "helmsman: ESLint config is present but npx is not installed." >&2
    return 1
  fi
  if ! npx --no-install eslint --version >/dev/null 2>&1; then
    echo "helmsman: ESLint config is present but eslint is not installed." >&2
    return 1
  fi
  echo "helmsman: eslint $repo_eslint"
  npx --no-install eslint .
}

ts_lint() {
  package_filters "packages/*/ts" "apps/web" "apps/mobile"
  if [[ ${#filters[@]} -gt 0 ]]; then
    run_turbo lint "${filters[@]}"
    return 0
  fi
  root_eslint
}

ts_format() {
  package_filters "packages/*/ts" "apps/web" "apps/mobile"
  if [[ ${#filters[@]} -eq 0 ]]; then
    echo "helmsman: no TypeScript package. prettier skipped."
    return 0
  fi
  run_turbo format "${filters[@]}"
}

ts_typecheck() {
  package_filters "packages/*/ts" "apps/web" "apps/mobile"
  if [[ ${#filters[@]} -gt 0 ]]; then
    run_turbo typecheck "${filters[@]}"
    return 0
  fi
  if [[ ! -f package.json ]]; then
    echo "helmsman: no typecheck script."
    return 0
  fi
  local script
  script="$(python3 -c 'import json; s=json.load(open("package.json")).get("scripts", {}).get("typecheck", ""); print(s if isinstance(s, str) else "")')"
  if [[ "$script" =~ ^tsc([[:space:]]|$) ]]; then
    echo "helmsman: tsc adapter"
    "$root/.helmsman/tools/tsc/check.sh"
    return 0
  fi
  if [[ "$script" == turbo\ * || "$script" == *"turbo run typecheck"* || "$script" == *pnpm-task.sh* || "$script" == *task.sh* ]]; then
    echo "helmsman: no TypeScript package. package typecheck skipped."
    return 0
  fi
  if [[ -n "$script" ]]; then
    echo "helmsman: pnpm run typecheck"
    pnpm run typecheck
    return 0
  fi
  echo "helmsman: no typecheck script."
}

ts_test() {
  package_filters "packages/*/ts" "apps/web" "apps/mobile"
  if [[ ${#filters[@]} -eq 0 ]]; then
    echo "helmsman: no TypeScript package. vitest skipped."
    return 0
  fi
  run_turbo test "${filters[@]}"
}

ts_unused() {
  local wired=0
  local candidate
  for candidate in knip.jsonc knip.json knip.ts knip.js knip.config.ts knip.config.js; do
    if [[ -f "$candidate" ]]; then
      wired=1
      break
    fi
  done
  if [[ "$wired" -eq 0 && -f package.json ]] && python3 -c 'import json,sys; m=json.load(open("package.json")); sys.exit(0 if isinstance(m.get("knip"), dict) else 1)'; then
    wired=1
  fi
  if [[ "$wired" -eq 0 && -f package.json ]] && python3 -c 'import json,sys; m=json.load(open("package.json")); d={**m.get("dependencies",{}),**m.get("devDependencies",{}),**m.get("optionalDependencies",{})}; sys.exit(0 if d.get("knip") else 1)'; then
    wired=1
  fi
  if [[ "$wired" -eq 0 ]]; then
    echo "helmsman: Knip is opt-in. Not wired."
    return 0
  fi
  if ! npx --no-install knip --version >/dev/null 2>&1; then
    echo "helmsman: Knip is configured but knip is not installed." >&2
    return 1
  fi
  echo "helmsman: knip"
  npx --no-install knip --no-config-hints
}

rust_ready() {
  local found=0
  shopt -s nullglob
  local manifests=(Cargo.toml packages/*/rs/Cargo.toml apps/*/Cargo.toml)
  shopt -u nullglob
  if [[ ${#manifests[@]} -gt 0 ]]; then
    found=1
  fi
  if [[ "$found" -eq 0 ]]; then
    echo "helmsman: no Cargo.toml. Rust skipped."
    return 1
  fi
  "$here/ensure-rust-tasks.sh" --check
  return 0
}

rust_lint() {
  if ! rust_ready; then
    return 0
  fi
  if [[ -f "$root/.helmsman/tools/clippy/floor.sh" ]]; then
    "$root/.helmsman/tools/clippy/floor.sh"
  fi
  package_filters "packages/*/rs" "apps/api" "apps/mcp"
  run_turbo lint "${filters[@]}"
  if [[ -f "$root/.helmsman/tools/clippy/check-file-length.sh" ]]; then
    "$root/.helmsman/tools/clippy/check-file-length.sh"
  fi
}

rust_format() {
  if ! rust_ready; then
    return 0
  fi
  package_filters "packages/*/rs" "apps/api" "apps/mcp"
  run_turbo format "${filters[@]}"
}

rust_test() {
  if ! rust_ready; then
    return 0
  fi
  package_filters "packages/*/rs" "apps/api" "apps/mcp"
  run_turbo test "${filters[@]}"
}

python_task() {
  local mode="$1"
  local turbo_task="$2"
  if [[ ! -f pyproject.toml && ! -f uv.lock ]]; then
    echo "helmsman: no Python project. ${mode} skipped."
    return 0
  fi
  package_filters "packages/*/py"
  if [[ ${#filters[@]} -gt 0 && "$mode" != "typecheck" ]]; then
    "$root/.helmsman/tools/python/check.sh" ceilings
    run_turbo "$turbo_task" "${filters[@]}"
    return 0
  fi
  "$root/.helmsman/tools/python/check.sh" "$mode"
}

integration_task() {
  "$here/integration.sh"
}

audit_task() {
  if [[ -f pnpm-lock.yaml ]]; then
    if ! command -v pnpm >/dev/null 2>&1; then
      echo "helmsman: pnpm-lock.yaml exists but pnpm is not installed." >&2
      return 1
    fi
    pnpm audit --audit-level=high
  else
    echo "helmsman: no pnpm-lock.yaml. pnpm audit skipped."
  fi
  if [[ -f .helmsman/tools/eslint/pnpm-lock.yaml ]]; then
    pnpm --dir .helmsman/tools/eslint audit --audit-level=high
  fi
  if [[ -f .helmsman/tools/knip/pnpm-lock.yaml ]]; then
    pnpm --dir .helmsman/tools/knip audit --audit-level=high
  fi
  if [[ -f Cargo.toml ]]; then
    if ! cargo audit --version >/dev/null 2>&1; then
      echo "helmsman: Cargo.toml exists but cargo-audit is not installed." >&2
      return 1
    fi
    cargo audit
    local deny_config=""
    if [[ -f deny.toml ]]; then
      deny_config="deny.toml"
    elif [[ -f .helmsman/tools/deny/deny.toml ]]; then
      deny_config=".helmsman/tools/deny/deny.toml"
    else
      echo "helmsman: Cargo.toml exists but deny.toml is not installed." >&2
      return 1
    fi
    if ! cargo deny --version >/dev/null 2>&1; then
      echo "helmsman: Cargo.toml exists but cargo-deny is not installed." >&2
      return 1
    fi
    cargo deny --manifest-path "$root/Cargo.toml" --config "$root/$deny_config" check advisories bans sources
  fi
  "$root/.helmsman/tools/secrets/check.sh"
  "$here/toolchain-latest.sh"
}

setup_task() {
  "$here/setup-check.sh"
  "$here/upstream.sh"
  "$here/pnpm-lock.sh"
  "$here/web-drift.sh"
  "$here/bash-n.sh"
  "$here/no-silences.sh"
  "$root/.helmsman/tools/surreal/check.sh"
  "$root/.helmsman/tools/postgres/check.sh"
  "$root/.helmsman/tools/dynamodb/check.sh"
  "$root/.helmsman/tools/opensearch/check.sh"
  "$root/.helmsman/tools/secrets/check.sh"
  if [[ -f "$root/.helmsman/tools/ci/emit.sh" ]]; then
    "$root/.helmsman/tools/ci/emit.sh" --check
  fi
}

diff_task() {
  if [[ -n "${HELMSMAN_DIFF_RANGE:-}" ]]; then
    "$here/diff-guard.sh" --range "$HELMSMAN_DIFF_RANGE"
    return 0
  fi
  "$here/diff-guard.sh"
}

plain_task() {
  if [[ -n "${HELMSMAN_DIFF_RANGE:-}" ]]; then
    "$here/plain-language.sh" --range "$HELMSMAN_DIFF_RANGE"
    return 0
  fi
  "$here/plain-language.sh"
}

dispatch() {
  local family="$1"
  local task="${2:-}"
  case "$family" in
    ts)
      case "$task" in
        lint) ts_lint ;;
        format) ts_format ;;
        typecheck) ts_typecheck ;;
        test) ts_test ;;
        unused) ts_unused ;;
        *) echo "helmsman: ts task must be lint, format, typecheck, test, or unused." >&2; return 2 ;;
      esac
      ;;
    rust)
      case "$task" in
        lint) rust_lint ;;
        format) rust_format ;;
        test) rust_test ;;
        *) echo "helmsman: rust task must be lint, format, or test." >&2; return 2 ;;
      esac
      ;;
    python)
      case "$task" in
        lint) python_task lint lint ;;
        typecheck) python_task typecheck typecheck ;;
        test) python_task test test ;;
        *) echo "helmsman: python task must be lint, typecheck, or test." >&2; return 2 ;;
      esac
      ;;
    integration) integration_task ;;
    smoke) "$here/e2e-smoke.sh" ;;
    audit) audit_task ;;
    setup) setup_task ;;
    diff-guard) diff_task ;;
    plain) plain_task ;;
    *)
      echo "helmsman: unknown task family $family" >&2
      return 2
      ;;
  esac
}

if [[ "${1:-}" == "all" ]]; then
  dispatch ts lint
  dispatch ts format
  dispatch ts typecheck
  dispatch ts unused
  dispatch ts test
  dispatch rust lint
  dispatch rust format
  dispatch rust test
  dispatch python lint
  dispatch python typecheck
  dispatch python test
  dispatch setup
  dispatch audit
  exit 0
fi

if [[ $# -lt 1 ]]; then
  echo "helmsman: task.sh <family> <task>" >&2
  exit 2
fi

dispatch "$@"
