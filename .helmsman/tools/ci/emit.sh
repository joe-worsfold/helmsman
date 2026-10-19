#!/usr/bin/env bash
# Write .github/workflows/helmsman.yml for the languages and features this repo has.
# A job's run line is a root pnpm script. Setup and cache steps are the rest.
# --check fails when the committed workflow is not this output.
# --stdout prints the workflow and writes nothing.
set -euo pipefail

mode="write"
case "${1:-}" in
  "") mode="write" ;;
  --check) mode="check" ;;
  --stdout) mode="stdout" ;;
  *)
    echo "helmsman: emit.sh [--check|--stdout]" >&2
    exit 2
    ;;
esac

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

field() {
  local key="$1"
  if [[ ! -f .helmsman/setup.md ]]; then
    return 0
  fi
  awk -F': ' -v key="$key" 'tolower($1) == key { sub(/^[^:]*: /, ""); print; exit }' .helmsman/setup.md
}

ci="$(field "ci")"
if [[ -n "$ci" && "$(lower "$ci")" != "github" ]]; then
  echo "helmsman: CI is ${ci}. Workflow not emitted."
  exit 0
fi

json_dep() {
  local name="$1"
  [[ -f package.json ]] || return 1
  python3 -c 'import json,sys; m=json.load(open("package.json")); d={**m.get("dependencies",{}),**m.get("devDependencies",{}),**m.get("optionalDependencies",{})}; sys.exit(0 if d.get(sys.argv[1]) else 1)' "$name"
}

ts_pkg=0
rust=0
python=0
eslint_cfg=0
prettier=0
vitest=0
knip=0
shopt -s nullglob
for dir in packages/*/ts apps/web apps/mobile; do
  if [[ -f "$dir/package.json" ]]; then
    ts_pkg=1
  fi
done
for manifest in Cargo.toml packages/*/rs/Cargo.toml apps/*/Cargo.toml; do
  if [[ -f "$manifest" ]]; then
    rust=1
  fi
done
shopt -u nullglob
if [[ -f pyproject.toml || -f uv.lock ]]; then
  python=1
fi
for candidate in eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts; do
  if [[ -f "$candidate" ]] && grep -q -E 'helmsman|\.helmsman/tools/eslint' "$candidate"; then
    eslint_cfg=1
  fi
done
for candidate in .prettierrc .prettierrc.json .prettierrc.yml .prettierrc.yaml .prettierrc.js .prettierrc.mjs .prettierrc.cjs prettier.config.js prettier.config.mjs; do
  if [[ -f "$candidate" ]]; then
    prettier=1
  fi
done
if json_dep prettier; then
  prettier=1
fi
if json_dep vitest; then
  vitest=1
fi
for candidate in knip.jsonc knip.json knip.ts knip.js knip.config.ts knip.config.js; do
  if [[ -f "$candidate" ]]; then
    knip=1
  fi
done
if [[ -f package.json ]] && python3 -c 'import json,sys; m=json.load(open("package.json")); sys.exit(0 if isinstance(m.get("knip"), dict) else 1)'; then
  knip=1
fi
if json_dep knip; then
  knip=1
fi

lint_eslint=0
format_prettier=0
test_vitest=0
if [[ "$ts_pkg" -eq 1 || "$eslint_cfg" -eq 1 ]]; then
  lint_eslint=1
fi
if [[ "$ts_pkg" -eq 1 || "$prettier" -eq 1 ]]; then
  format_prettier=1
fi
if [[ "$ts_pkg" -eq 1 || "$vitest" -eq 1 ]]; then
  test_vitest=1
fi

# CI suite: short omits prove-web, audit, eslint-package, and knip-package.
# Use short for early-stage repos and POCs where those checks slow iteration.
# A public repo with free minutes can leave this unset (default: extended).
ci_suite="$(lower "$(field "ci suite")")"
ci_extended=1
if [[ "$ci_suite" == "short" ]]; then
  ci_extended=0
fi

# CI integration and CI e2e smoke default to no when the line is missing.
# Integration and E2E smoke stay the local commands. They do not emit jobs.
integration=0
smoke=0
if [[ "$(lower "$(field "ci integration")")" == "yes" ]]; then
  integration=1
fi
if [[ "$(lower "$(field "ci e2e smoke")")" == "yes" ]]; then
  smoke=1
fi

harness_ts=0
if [[ -f eval/tsconfig.json ]]; then
  harness_ts=1
fi
root_ts=0
if [[ "$ts_pkg" -eq 0 && "$harness_ts" -eq 0 && -f tsconfig.json ]]; then
  root_ts=1
fi
harness_test=0
if [[ -f eval/flake.sh && -f eval/trials.sh ]]; then
  harness_test=1
fi
eslint_pkg=0
knip_pkg=0
if [[ -f .helmsman/tools/eslint/check.mjs ]]; then
  eslint_pkg=1
fi
if [[ -f .helmsman/tools/knip/check.mjs ]]; then
  knip_pkg=1
fi

pin_file="$(cd "$(dirname "$0")/../checks" && pwd)/actionlint.sh"
actionlint_sha="$(sed -n 's/^sha="\${ACTIONLINT_SHA:-\([0-9a-f]\{40\}\)}"$/\1/p' "$pin_file")"
actionlint_version="$(sed -n 's/^version="\${ACTIONLINT_VERSION:-\([0-9][0-9.]*\)}"$/\1/p' "$pin_file")"
if [[ ! "$actionlint_sha" =~ ^[0-9a-f]{40}$ || ! "$actionlint_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "helmsman: actionlint pin missing in ${pin_file}." >&2
  exit 1
fi

ready="(github.event_name != 'pull_request' || github.event.pull_request.draft == false)"

out="$(mktemp)"
trap 'rm -f "$out"' EXIT

emit() { printf '%s\n' "$1" >> "$out"; }

checkout() {
  emit "      - uses: actions/checkout@v7"
  if [[ "${1:-}" == "full" ]]; then
    emit "        with:"
    emit "          fetch-depth: 0"
  fi
}

# A job that never installs restores no pnpm store, and pnpm skips its
# install-before-run check. Its scripts use only bash, git, python3, and gh.
bare_pnpm="pnpm --config.verify-deps-before-run=false"
bare_setup() {
  emit "      - uses: pnpm/action-setup@v6"
  emit "      - uses: actions/setup-node@v7"
  emit "        with:"
  emit "          node-version-file: .nvmrc"
}

node_setup() {
  local cache_path="${1:-}"
  bare_setup
  if [[ -f pnpm-lock.yaml ]]; then
    emit "          cache: pnpm"
    if [[ -n "$cache_path" ]]; then
      emit "          cache-dependency-path: ${cache_path}"
    fi
  fi
}

install_root() {
  if [[ -f pnpm-lock.yaml ]]; then
    emit "      - name: Install"
    emit "        run: pnpm install --frozen-lockfile"
  fi
}

turbo_cache() {
  emit "      - uses: actions/cache@v6"
  emit "        with:"
  emit "          path: .turbo"
  emit '          key: turbo-${{ runner.os }}-${{ hashFiles('"'"'pnpm-lock.yaml'"'"') }}-${{ github.sha }}'
  emit "          restore-keys: |"
  emit '            turbo-${{ runner.os }}-${{ hashFiles('"'"'pnpm-lock.yaml'"'"') }}-'
  emit '            turbo-${{ runner.os }}-'
}

rust_setup() {
  emit "      - uses: dtolnay/rust-toolchain@v1"
  emit "        with:"
  emit "          components: clippy, rustfmt"
  emit "      - uses: Swatinem/rust-cache@v2.9.2"
}

uv_setup() {
  emit "      - uses: astral-sh/setup-uv@v10.3.0"
}

run_pnpm() {
  local script="$1"
  local filter="${2:-}"
  local scm="${3:-}"
  local runner="${4:-pnpm}"
  emit "      - name: ${script}"
  if [[ -n "$filter" || "$scm" == "yes" ]]; then
    emit "        env:"
    if [[ "$scm" == "yes" ]]; then
      emit '          TURBO_SCM_BASE: ${{ github.event_name == '"'"'pull_request'"'"' && github.event.pull_request.base.sha || github.event.before }}'
    fi
    if [[ -n "$filter" ]]; then
      emit "          HELMSMAN_FILTER: ${filter}"
    fi
  fi
  emit "        run: ${runner} ${script}"
}

begin_job() {
  local id="$1"
  local name="$2"
  local gate="$3"
  local timeout="$4"
  job_ids+=("$id")
  emit "  ${id}:"
  emit "    name: ${name}"
  emit "    needs: changes"
  if [[ "$id" == "prove-web" ]]; then
    emit "    if: always() && ${ready} && ((github.event.action == 'edited' && github.event.changes.body) || (needs.changes.result == 'success' && (${gate})))"
  elif [[ "$gate" == "always" ]]; then
    emit "    if: ${ready} && github.event.action != 'edited'"
  else
    emit "    if: ${ready} && github.event.action != 'edited' && (${gate})"
  fi
  emit "    runs-on: ubuntu-latest"
  emit "    timeout-minutes: ${timeout}"
  emit "    steps:"
}

pnpm_job() {
  local id="$1"
  local name="$2"
  local gate="$3"
  local timeout="$4"
  local script="$5"
  local filter="${6:-}"
  local scm="${7:-}"
  local kind="${8:-node}"
  local runner=pnpm
  begin_job "$id" "$name" "$gate" "$timeout"
  if [[ "$scm" == "yes" || "$id" == "diff-guard" || "$id" == "setup" ]]; then
    checkout full
  else
    checkout
  fi
  case "$kind" in
    rust)
      node_setup
      install_root
      rust_setup
      turbo_cache
      ;;
    python)
      node_setup
      install_root
      uv_setup
      ;;
    node)
      node_setup
      install_root
      if [[ "$scm" == "yes" ]]; then
        turbo_cache
      fi
      ;;
    bare)
      bare_setup
      runner="$bare_pnpm"
      ;;
  esac
  run_pnpm "$script" "$filter" "$scm" "$runner"
  emit ""
}

job_ids=()

emit "# Generated by .helmsman/tools/ci/emit.sh. Do not edit by hand."
emit "name: helmsman"
emit ""
emit "on:"
emit "  pull_request:"
emit "    types:"
emit "      - opened"
emit "      - ready_for_review"
emit "      - synchronize"
emit "      - reopened"
emit "      - edited"
emit "  push:"
emit "    branches:"
emit "      - main"
emit ""
emit "concurrency:"
emit "  group: \${{ github.workflow }}-\${{ github.ref }}-\${{ github.event.action == 'edited' && 'edited' || 'run' }}"
emit "  cancel-in-progress: true"
emit ""
emit "jobs:"
emit "  changes:"
emit "    name: changes"
emit "    if: ${ready} && github.event.action != 'edited'"
emit "    runs-on: ubuntu-latest"
emit "    timeout-minutes: 5"
emit "    outputs:"
emit '      eslint: ${{ steps.paths.outputs.eslint }}'
emit '      knip: ${{ steps.paths.outputs.knip }}'
emit '      ts: ${{ steps.paths.outputs.ts }}'
emit '      rust: ${{ steps.paths.outputs.rust }}'
emit '      python: ${{ steps.paths.outputs.python }}'
emit '      schema: ${{ steps.paths.outputs.schema }}'
emit '      web: ${{ steps.paths.outputs.web }}'
emit '      api: ${{ steps.paths.outputs.api }}'
emit '      docs: ${{ steps.paths.outputs.docs }}'
emit '      setup: ${{ steps.paths.outputs.setup }}'
emit '      harness: ${{ steps.paths.outputs.harness }}'
emit '      workflows: ${{ steps.paths.outputs.workflows }}'
emit '      audit: ${{ steps.paths.outputs.audit }}'
emit '      guard: ${{ steps.paths.outputs.guard }}'
emit "    steps:"
checkout full
bare_setup
emit "      - id: paths"
emit "        env:"
emit '          HELMSMAN_CI_BASE: ${{ github.event_name == '"'"'pull_request'"'"' && github.event.pull_request.base.sha || github.event.before }}'
emit "        run: ${bare_pnpm} ci:paths"
emit ""
job_ids+=(changes)

# Merge lint, format, typecheck, and test into one job when ts_pkg is set.
# One pnpm install and one Turbo cache instead of four. Steps run sequentially;
# a lint failure stops early, which is acceptable.
if [[ "$ts_pkg" -eq 1 ]]; then
  begin_job check-ts "check (ts)" "needs.changes.outputs.ts == 'true'" 20
  checkout full
  node_setup
  install_root
  turbo_cache
  [[ "$lint_eslint" -eq 1 ]] && run_pnpm lint ts yes
  [[ "$format_prettier" -eq 1 ]] && run_pnpm "format:check" ts yes
  run_pnpm typecheck ts yes
  [[ "$test_vitest" -eq 1 ]] && run_pnpm test ts yes
  [[ "$knip" -eq 1 ]] && run_pnpm unused "" no
  emit ""
elif [[ "$harness_ts" -eq 1 || "$root_ts" -eq 1 ]]; then
  # No package-level TS: emit separate jobs for harness/root edge cases.
  if [[ "$lint_eslint" -eq 1 ]]; then
    pnpm_job lint-eslint "lint (eslint)" "needs.changes.outputs.ts == 'true'" 15 lint ts yes node
  fi
  if [[ "$format_prettier" -eq 1 ]]; then
    pnpm_job format-prettier "format (prettier)" "needs.changes.outputs.ts == 'true'" 15 "format:check" ts yes node
  fi
  if [[ "$python" -eq 1 && "$harness_ts" -eq 1 ]]; then
    pnpm_job typecheck-tsc "typecheck (tsc)" "needs.changes.outputs.ts == 'true'" 15 typecheck harness no node
  elif [[ "$python" -eq 1 && "$root_ts" -eq 1 ]]; then
    pnpm_job typecheck-tsc "typecheck (tsc)" "needs.changes.outputs.ts == 'true'" 15 typecheck ts no node
  else
    pnpm_job typecheck-tsc "typecheck (tsc)" "needs.changes.outputs.ts == 'true'" 15 typecheck "" no node
  fi
  if [[ "$test_vitest" -eq 1 ]]; then
    pnpm_job test-vitest "test (vitest)" "needs.changes.outputs.ts == 'true'" 15 test ts yes node
  fi
  if [[ "$knip" -eq 1 ]]; then
    pnpm_job unused-knip "unused (knip)" "needs.changes.outputs.ts == 'true'" 15 unused "" no node
  fi
fi
if [[ "$harness_ts" -eq 1 && "$ts_pkg" -eq 1 ]]; then
  pnpm_job typecheck-harness "typecheck (harness)" "needs.changes.outputs.ts == 'true' && needs.changes.outputs.harness == 'true'" 15 typecheck harness no node
fi

# Merge lint, format, and test into one job when rust is set.
# One Rust toolchain install and one pnpm install instead of three.
if [[ "$rust" -eq 1 ]]; then
  begin_job check-rust "check (rust)" "needs.changes.outputs.rust == 'true'" 25
  checkout full
  node_setup
  install_root
  rust_setup
  turbo_cache
  run_pnpm lint rust yes
  run_pnpm "format:check" rust yes
  run_pnpm test rust yes
  emit ""
fi
if [[ "$python" -eq 1 ]]; then
  pnpm_job lint-ruff "lint (ruff)" "needs.changes.outputs.python == 'true'" 15 lint python no python
  pnpm_job typecheck-ty "typecheck (ty)" "needs.changes.outputs.python == 'true'" 15 typecheck python no python
  pnpm_job test-pytest "test (pytest)" "needs.changes.outputs.python == 'true'" 15 test python no python
fi
if [[ "$integration" -eq 1 ]]; then
  begin_job test-integration "test (integration)" "needs.changes.outputs.rust == 'true' || needs.changes.outputs.schema == 'true'" 20
  checkout
  if [[ "$rust" -eq 1 ]]; then
    rust_setup
  fi
  node_setup
  install_root
  if [[ "$python" -eq 1 ]]; then
    uv_setup
  fi
  run_pnpm test:integration
  emit ""
fi
if [[ "$smoke" -eq 1 ]]; then
  pnpm_job e2e-smoke "e2e smoke" "needs.changes.outputs.web == 'true' || needs.changes.outputs.api == 'true'" 20 e2e:smoke "" no node
fi
if [[ "$ci_extended" -eq 1 && -d apps/web ]]; then
  begin_job prove-web "prove (web)" "needs.changes.outputs.web == 'true'" 5
  checkout full
  bare_setup
  emit "      - name: prove:web"
  emit "        env:"
  emit '          HELMSMAN_DIFF_RANGE: "${{ github.event_name == '"'"'pull_request'"'"' && format('"'"'{0}...HEAD'"'"', github.event.pull_request.base.sha) || '"'"'HEAD~1...HEAD'"'"' }}"'
  emit "        run: ${bare_pnpm} prove:web"
  emit ""
fi
if [[ "$harness_test" -eq 1 ]]; then
  pnpm_job test-harness "test (harness)" "needs.changes.outputs.harness == 'true'" 20 test harness no node
fi

if [[ "$ci_extended" -eq 1 ]]; then
  begin_job audit audit "needs.changes.outputs.audit == 'true'" 15
  checkout
  node_setup
  install_root
  if [[ "$rust" -eq 1 ]]; then
    emit "      - uses: dtolnay/rust-toolchain@v1"
    emit "      - uses: taiki-e/install-action@v2"
    emit "        with:"
    emit "          tool: cargo-audit,cargo-deny"
  fi
  run_pnpm audit:all
  emit ""
fi

# Repo checks may call a root dev dependency, so the setup job installs then.
setup_kind=bare
repo_checks="$(lower "$(field "repo checks")")"
if [[ -n "$repo_checks" && "$repo_checks" != "none" ]]; then
  setup_kind=node
fi
pnpm_job setup setup "needs.changes.outputs.setup == 'true'" 10 setup:check "" no "$setup_kind"

begin_job diff-guard "diff guard" "needs.changes.outputs.guard == 'true'" 10
checkout full
bare_setup
emit "      - name: diff:guard"
emit "        env:"
emit '          HELMSMAN_DIFF_RANGE: "${{ github.event_name == '"'"'pull_request'"'"' && format('"'"'{0}...HEAD'"'"', github.event.pull_request.base.sha) || '"'"'HEAD~1...HEAD'"'"' }}"'
emit "        run: ${bare_pnpm} diff:guard"
emit "      - name: plain:language"
emit "        env:"
emit '          HELMSMAN_DIFF_RANGE: "${{ github.event_name == '"'"'pull_request'"'"' && format('"'"'{0}...HEAD'"'"', github.event.pull_request.base.sha) || '"'"'HEAD~1...HEAD'"'"' }}"'
emit "        run: ${bare_pnpm} plain:language"
emit ""

if [[ "$ci_extended" -eq 1 && "$eslint_pkg" -eq 1 ]]; then
  begin_job eslint-package eslint-package "needs.changes.outputs.eslint == 'true'" 15
  checkout
  node_setup .helmsman/tools/eslint/pnpm-lock.yaml
  emit "      - name: Install"
  emit "        working-directory: .helmsman/tools/eslint"
  emit "        run: pnpm install --frozen-lockfile"
  run_pnpm eslint:package
  emit ""
fi
if [[ "$ci_extended" -eq 1 && "$knip_pkg" -eq 1 ]]; then
  begin_job knip-package knip-package "needs.changes.outputs.knip == 'true'" 15
  checkout
  node_setup .helmsman/tools/knip/pnpm-lock.yaml
  emit "      - name: Install"
  emit "        working-directory: .helmsman/tools/knip"
  emit "        run: pnpm install --frozen-lockfile"
  run_pnpm knip:package
  emit ""
fi

begin_job lint-actionlint "lint (actionlint)" "needs.changes.outputs.workflows == 'true'" 10
checkout
bare_setup
emit "      - name: lint:actions"
emit "        env:"
emit "          ACTIONLINT_SHA: ${actionlint_sha}"
emit "          ACTIONLINT_VERSION: \"${actionlint_version}\""
emit "        run: ${bare_pnpm} lint:actions"
emit ""

emit "  ci-ok:"
emit "    name: ci-ok"
emit "    if: always() && ${ready} && github.event.action != 'edited'"
emit "    needs:"
for id in "${job_ids[@]}"; do
  emit "      - ${id}"
done
emit "    runs-on: ubuntu-latest"
emit "    timeout-minutes: 5"
emit "    permissions:"
emit "      contents: read"
emit "      issues: read"
emit "      pull-requests: read"
emit "    steps:"
checkout full
bare_setup
emit "      - name: ci:ok"
emit "        env:"
emit "          HELMSMAN_CI_RESULTS: >-"
for id in "${job_ids[@]}"; do
  printf '            %s=${{ needs.%s.result }}\n' "$id" "$id" >> "$out"
done
emit "        run: ${bare_pnpm} ci:ok"
emit "      - name: review:current"
emit "        env:"
emit "          GH_TOKEN: \${{ github.token }}"
emit "        run: ${bare_pnpm} review:current"

dest=".github/workflows/helmsman.yml"
if [[ "$mode" == "stdout" ]]; then
  cat "$out"
  exit 0
fi
if [[ "$mode" == "check" ]]; then
  if [[ ! -f "$dest" ]]; then
    echo "helmsman: missing ${dest}. Run .helmsman/tools/ci/emit.sh." >&2
    exit 1
  fi
  if ! diff -u "$dest" "$out" >&2; then
    echo "helmsman: ${dest} is not what emit.sh writes. Run .helmsman/tools/ci/emit.sh." >&2
    exit 1
  fi
  echo "helmsman: workflow matches emit.sh."
  exit 0
fi

mkdir -p .github/workflows
mv "$out" "$dest"
trap - EXIT
echo "helmsman: wrote ${dest}."
