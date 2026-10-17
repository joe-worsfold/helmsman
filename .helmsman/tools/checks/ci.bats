#!/usr/bin/env bats
# Workflow emitter, tool home, ci-ok, and rust turbo wrappers.

setup() {
  repo="$(mktemp -d)"
  cd "$repo"
  git init -q
  git config user.email "gate@example.com"
  git config user.name "gate"
  checks="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  root="$(cd "$checks/../../.." && pwd)"
}

teardown() {
  cd /tmp
  if [[ -n "${repo:-}" && -d "$repo" ]]; then
    rm -rf "$repo"
  fi
}

write_setup() {
  local languages="$1"
  local integration="${2:-none}"
  local nest="${3:-none}"
  mkdir -p .helmsman
  cat > .helmsman/setup.md << EOF
# Setup

Languages: ${languages}
Surfaces: none
E2E smoke: ${nest}
Watch: none
Integration: ${integration}
Issues: github
CI: github
File issues: no
Fix: no
EOF
  git add -A
  git commit -q -m init
}

@test "tool home passes a repo with an unrelated script" {
  mkdir -p scripts
  printf '%s\n' 'echo ok' > scripts/build.sh
  git add -A
  git commit -q -m init
  run "$checks/tool-home.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tool home ok."* ]]
}

@test "tool home fails the old tools/helmsman layout" {
  mkdir -p tools/helmsman
  git commit --allow-empty -q -m init
  run "$checks/tool-home.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"old layout"* ]]
}

@test "tool home fails a root tools directory" {
  mkdir -p tools
  git commit --allow-empty -q -m init
  run "$checks/tool-home.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"root tools/"* ]]
}

@test "tool home fails a root directory named like a harness package" {
  mkdir -p checks
  git commit --allow-empty -q -m init
  run "$checks/tool-home.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"root-level Helmsman tool folder"* ]]
}

@test "tool home fails scripts/helmsman" {
  mkdir -p scripts/helmsman
  git commit --allow-empty -q -m init
  run "$checks/tool-home.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"scripts/helmsman"* ]]
}

@test "setup fails when the old tool layout is present" {
  mkdir -p tools/helmsman .helmsman
  printf '%s\n' '# Setup' > .helmsman/setup.md
  git add -A
  git commit -q -m init
  run "$checks/setup-check.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"old layout"* ]]
  [[ "$output" != *"setup ok"* ]]
}

@test "python emit has ruff and not clippy or eslint" {
  write_setup python
  printf '%s\n' '[project]' 'name = "demo"' > pyproject.toml
  git add pyproject.toml
  git commit -q -m py
  run "$checks/../ci/emit.sh"
  [ "$status" -eq 0 ]
  grep -q 'name: lint (ruff)' .github/workflows/helmsman.yml
  run grep -F 'name: lint (clippy)' .github/workflows/helmsman.yml
  [ "$status" -eq 1 ]
  run grep -F 'name: lint (eslint)' .github/workflows/helmsman.yml
  [ "$status" -eq 1 ]
  grep -q 'HELMSMAN_FILTER: python' .github/workflows/helmsman.yml
  grep -q 'run: pnpm lint' .github/workflows/helmsman.yml
}

@test "a repo without python does not emit ruff" {
  write_setup "rust, typescript"
  run "$checks/../ci/emit.sh"
  [ "$status" -eq 0 ]
  run grep -F 'name: lint (ruff)' .github/workflows/helmsman.yml
  [ "$status" -eq 1 ]
  run grep -F 'name: lint (clippy)' .github/workflows/helmsman.yml
  [ "$status" -eq 1 ]
  run grep -F 'name: e2e smoke' .github/workflows/helmsman.yml
  [ "$status" -eq 1 ]
  run grep -F 'name: test (integration)' .github/workflows/helmsman.yml
  [ "$status" -eq 1 ]
}

@test "local integration and e2e commands do not emit CI jobs" {
  write_setup rust "cargo test -- --ignored" "pnpm exec playwright test"
  printf '%s\n' '[package]' 'name = "demo"' 'version = "0.0.0"' > Cargo.toml
  git add Cargo.toml
  git commit -q -m cargo
  run "$checks/../ci/emit.sh"
  [ "$status" -eq 0 ]
  run grep -F 'name: test (integration)' .github/workflows/helmsman.yml
  [ "$status" -eq 1 ]
  run grep -F 'name: e2e smoke' .github/workflows/helmsman.yml
  [ "$status" -eq 1 ]
}

@test "CI integration and CI e2e smoke yes emit those jobs" {
  write_setup rust "cargo test -- --ignored" "pnpm exec playwright test"
  printf '%s\n' 'CI integration: yes' 'CI e2e smoke: yes' >> .helmsman/setup.md
  printf '%s\n' '[package]' 'name = "demo"' 'version = "0.0.0"' > Cargo.toml
  git add -A
  git commit -q -m cargo
  run "$checks/../ci/emit.sh"
  [ "$status" -eq 0 ]
  grep -q 'name: test (integration)' .github/workflows/helmsman.yml
  grep -q 'run: pnpm test:integration' .github/workflows/helmsman.yml
  grep -q 'name: e2e smoke' .github/workflows/helmsman.yml
  grep -q 'run: pnpm e2e:smoke' .github/workflows/helmsman.yml
  run grep -F 'playwright install' .github/workflows/helmsman.yml
  [ "$status" -eq 1 ]
}

@test "CI integration no stays off when the local command is set" {
  write_setup rust "cargo test -- --ignored" "pnpm exec playwright test"
  printf '%s\n' 'CI integration: no' 'CI e2e smoke: no' >> .helmsman/setup.md
  git add -A
  git commit -q -m keys
  run "$checks/../ci/emit.sh"
  [ "$status" -eq 0 ]
  run grep -F 'name: test (integration)' .github/workflows/helmsman.yml
  [ "$status" -eq 1 ]
  run grep -F 'name: e2e smoke' .github/workflows/helmsman.yml
  [ "$status" -eq 1 ]
}

@test "apps/web emits a prove job that does not take screenshots" {
  write_setup bash
  mkdir -p apps/web
  run "$checks/../ci/emit.sh"
  [ "$status" -eq 0 ]
  grep -q 'name: prove (web)' .github/workflows/helmsman.yml
  grep -q 'run: pnpm --config.verify-deps-before-run=false prove:web' .github/workflows/helmsman.yml
  grep -q "needs.changes.outputs.web == 'true'" .github/workflows/helmsman.yml
  grep -q '      - edited' .github/workflows/helmsman.yml
  prove_if="$(awk '
    $0 ~ "^  prove-web:$" { on=1; next }
    on && /^  [^ ]/ { exit }
    on { print }
  ' .github/workflows/helmsman.yml)"
  [[ "$prove_if" == *"action == 'edited'"* ]]
  [[ "$prove_if" == *"github.event.changes.body"* ]]
  [[ "$prove_if" == *"always()"* ]]
  run grep -F "action != 'edited'" <<< "$prove_if"
  [ "$status" -eq 1 ]
  run grep -F 'playwright' .github/workflows/helmsman.yml
  [ "$status" -eq 1 ]
}

@test "emitted workflows push main only and run pnpm" {
  write_setup bash
  run "$checks/../ci/emit.sh"
  [ "$status" -eq 0 ]
  grep -A3 '^  push:' .github/workflows/helmsman.yml | grep -q 'main'
  bad="$(grep -E '^[[:space:]]*run:' .github/workflows/helmsman.yml | grep -v -E 'run: pnpm ' || true)"
  [ -z "$bad" ]
}

@test "setup job installs only when Repo checks is set" {
  printf '%s\n' "lockfileVersion: '9.0'" > pnpm-lock.yaml
  write_setup bash
  run "$checks/../ci/emit.sh"
  [ "$status" -eq 0 ]
  job="$(sed -n '/^  setup:/,/setup:check/p' .github/workflows/helmsman.yml)"
  [[ -n "$job" && "$job" != *"pnpm install"* ]]
  printf '%s\n' 'Repo checks: pnpm exec bats test' >> .helmsman/setup.md
  run "$checks/../ci/emit.sh"
  [ "$status" -eq 0 ]
  job="$(sed -n '/^  setup:/,/setup:check/p' .github/workflows/helmsman.yml)"
  [[ "$job" == *"pnpm install --frozen-lockfile"* ]]
}

@test "jobs that never install skip the pnpm store and the pre-run install" {
  printf '%s\n' "lockfileVersion: '9.0'" > pnpm-lock.yaml
  write_setup bash
  run "$checks/../ci/emit.sh"
  [ "$status" -eq 0 ]
  wf=.github/workflows/helmsman.yml
  for id in changes setup diff-guard lint-actionlint ci-ok; do
    job="$(awk -v id="  ${id}:" '$0 == id { on=1; next } on && /^  [^ ]/ { exit } on { print }' "$wf")"
    [[ -n "$job" ]]
    [[ "$job" != *"cache: pnpm"* ]]
    [[ "$job" != *"pnpm install"* ]]
    bad="$(grep -E '^[[:space:]]*run:' <<< "$job" | grep -v -F 'run: pnpm --config.verify-deps-before-run=false ' || true)"
    [ -z "$bad" ]
  done
  job="$(awk '$0 == "  audit:" { on=1; next } on && /^  [^ ]/ { exit } on { print }' "$wf")"
  [[ "$job" == *"cache: pnpm"* ]]
  [[ "$job" == *"run: pnpm audit:all"* ]]
}

@test "this repo workflow matches the emitter" {
  cd "$root"
  run "$checks/../ci/emit.sh" --check
  [ "$status" -eq 0 ]
}

@test "ci-ok accepts success and skipped" {
  run "$checks/ci-ok.sh" changes=success audit=skipped
  [ "$status" -eq 0 ]
  run "$checks/ci-ok.sh" changes=failure
  [ "$status" -eq 1 ]
  run "$checks/ci-ok.sh"
  [ "$status" -eq 2 ]
  run env HELMSMAN_CI_RESULTS="changes=success audit=skipped" "$checks/ci-ok.sh"
  [ "$status" -eq 0 ]
}

@test "ensure-rust-tasks writes package scripts and rejects a root platform" {
  mkdir -p packages/orders/rs
  printf '%s\n' '[package]' 'name = "orders"' 'version = "0.0.0"' > packages/orders/rs/Cargo.toml
  git add -A
  git commit -q -m crate
  run "$checks/ensure-rust-tasks.sh"
  [ "$status" -eq 0 ]
  grep -q 'cargo-package.sh lint' packages/orders/rs/package.json
  run "$checks/ensure-rust-tasks.sh" --check
  [ "$status" -eq 0 ]
  mkdir -p platform
  printf '%s\n' '[package]' 'name = "platform"' > platform/Cargo.toml
  run "$checks/ensure-rust-tasks.sh" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"packages/platform/rs"* ]]
}

@test "root scripts are installed once and keep build" {
  printf '%s\n' '{"scripts":{"lint":"turbo run lint","build":"turbo run build"}}' > package.json
  git add package.json
  git commit -q -m pkg
  run "$checks/install-root-scripts.sh"
  [ "$status" -eq 0 ]
  grep -q 'pnpm-task.sh lint' package.json
  grep -q 'ci-paths.sh' package.json
  grep -q 'turbo run build' package.json
  before="$(cat package.json)"
  run "$checks/install-root-scripts.sh"
  [ "$status" -eq 0 ]
  [ "$(cat package.json)" = "$before" ]
}

@test "review before ready appends once" {
  printf '%s\n' '# Product' > AGENTS.md
  git add AGENTS.md
  git commit -q -m agents
  run "$checks/install-review-ready.sh"
  [ "$status" -eq 0 ]
  before="$(cat AGENTS.md)"
  grep -q '^## Review before ready$' AGENTS.md
  grep -q '^# Product$' AGENTS.md
  grep -q 'Agents work in draft\.' AGENTS.md
  run "$checks/install-review-ready.sh"
  [ "$status" -eq 0 ]
  [ "$(cat AGENTS.md)" = "$before" ]
}

@test "review before ready adds the draft sentence to an existing section" {
  printf '%s\n' '# Product' '' '## Review before ready' '' 'Already reviewed.' > AGENTS.md
  git add AGENTS.md
  git commit -q -m agents
  run "$checks/install-review-ready.sh"
  [ "$status" -eq 0 ]
  grep -q 'Agents work in draft\.' AGENTS.md
  grep -q 'Already reviewed\.' AGENTS.md
  before="$(cat AGENTS.md)"
  run "$checks/install-review-ready.sh"
  [ "$status" -eq 0 ]
  [ "$(cat AGENTS.md)" = "$before" ]
}

@test "review before ready rewrites the old CI green step" {
  cat > AGENTS.md << 'EOF'
# Product

## Review before ready

Every agent PR finishes in order: (1) run helmsman-review on the full diff against base, (2) fix every block and revise finding, (3) pre-commit and CI green, (4) post the review as a PR comment saying what was fixed and what remains minor or deferred and why, (5) mark ready only after that comment. The review catches what the standards missed, including when the change was written to them.

Agents work in draft. Prove the change locally with `pnpm check` and the pre-commit hook before pushing. CI runs when the pull request is marked ready, and on push to main. A draft pull request does not run CI.
EOF
  git add AGENTS.md
  git commit -q -m agents
  run "$checks/install-review-ready.sh"
  [ "$status" -eq 0 ]
  grep -q 'Marking ready is when CI runs\.' AGENTS.md
  grep -q 'fix every Blocker, unjustified Judo, High, and Medium finding' AGENTS.md
  grep -q 'what remains Fix forward or Nit and why' AGENTS.md
  run grep -F 'pre-commit and CI green' AGENTS.md
  [ "$status" -eq 1 ]
  run grep -F 'fix every block and revise finding' AGENTS.md
  [ "$status" -eq 1 ]
  before="$(cat AGENTS.md)"
  run "$checks/install-review-ready.sh"
  [ "$status" -eq 0 ]
  [ "$(cat AGENTS.md)" = "$before" ]
}

@test "jobs wait on changes and drafts do not run" {
  write_setup bash
  mkdir -p eval
  printf '%s\n' '{}' > eval/tsconfig.json
  printf '%s\n' '#!/bin/sh' 'echo ok' > eval/flake.sh
  printf '%s\n' '#!/bin/sh' 'echo ok' > eval/trials.sh
  git add -A
  git commit -q -m eval
  run "$checks/../ci/emit.sh"
  [ "$status" -eq 0 ]
  grep -q 'ready_for_review' .github/workflows/helmsman.yml
  grep -q '      - edited' .github/workflows/helmsman.yml
  grep -q "action == 'edited' && 'edited'" .github/workflows/helmsman.yml
  grep -q 'pull_request.draft == false' .github/workflows/helmsman.yml
  grep -q "github.event.action != 'edited'" .github/workflows/helmsman.yml
  run grep -F "action == 'edited' && github.event.changes.body" .github/workflows/helmsman.yml
  [ "$status" -eq 1 ]
  grep -q 'needs.changes.outputs.harness' .github/workflows/helmsman.yml
  grep -q 'needs.changes.outputs.audit' .github/workflows/helmsman.yml
  grep -q 'needs.changes.outputs.guard' .github/workflows/helmsman.yml
  grep -q 'needs.changes.outputs.workflows' .github/workflows/helmsman.yml
  grep -q 'needs.changes.outputs.ts' .github/workflows/helmsman.yml
  grep -q 'name: lint (actionlint)' .github/workflows/helmsman.yml
  grep -q '914e7df21a07ef503a81201c76d2b11c789d3fca' .github/workflows/helmsman.yml
  awk '/name: typecheck \(tsc\)/,/timeout-minutes/' .github/workflows/helmsman.yml | grep -q 'needs: changes'
  awk '/name: test \(harness\)/,/timeout-minutes/' .github/workflows/helmsman.yml | grep -q 'outputs.harness'
  awk '/name: audit$/,/timeout-minutes/' .github/workflows/helmsman.yml | grep -q 'outputs.audit'
}

@test "ci paths run setup when a Cursor rule or the Claude copy changes" {
  mkdir -p .cursor/rules .claude/rules
  printf '%s\n' '# docs' > README.md
  git add -A
  git commit -q -m base

  for file in .cursor/rules/helmsman-rust.mdc .claude/rules/helmsman-rust.md CLAUDE.md AGENTS.md; do
    base="$(git rev-parse HEAD)"
    printf '%s\n' "# $file" > "$file"
    git add -A
    git commit -q -m "$file"
    run env HELMSMAN_CI_BASE="$base" "$checks/ci-paths.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"setup=true"* ]]
  done
}

@test "ci paths skip a docs-only diff and keep a harness diff" {
  mkdir -p eval .github/workflows .helmsman/tools/checks
  printf '%s\n' '# docs' > README.md
  git add -A
  git commit -q -m base

  base="$(git rev-parse HEAD)"
  printf '%s\n' '# more' >> README.md
  git add -A
  git commit -q -m docs
  run env HELMSMAN_CI_BASE="$base" "$checks/ci-paths.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"docs=true"* ]]
  [[ "$output" == *"setup=false"* ]]
  [[ "$output" == *"guard=true"* ]]
  [[ "$output" == *"audit=false"* ]]
  [[ "$output" == *"harness=false"* ]]
  [[ "$output" == *"workflows=false"* ]]

  base="$(git rev-parse HEAD)"
  printf '%s\n' '# tool' > .helmsman/tools/checks/actionlint.sh
  git add -A
  git commit -q -m tool
  run env HELMSMAN_CI_BASE="$base" "$checks/ci-paths.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"harness=true"* ]]
  [[ "$output" == *"ts=false"* ]]

  base="$(git rev-parse HEAD)"
  printf '%s\n' 'export const a = 1' > eval/failure-text.mjs
  git add -A
  git commit -q -m evaljs
  run env HELMSMAN_CI_BASE="$base" "$checks/ci-paths.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"harness=true"* ]]
  [[ "$output" == *"ts=true"* ]]

  base="$(git rev-parse HEAD)"
  printf '%s\n' 'name: x' > .github/workflows/helmsman.yml
  git add -A
  git commit -q -m wf
  run env HELMSMAN_CI_BASE="$base" "$checks/ci-paths.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"workflows=true"* ]]

  base="$(git rev-parse HEAD)"
  printf '%s\n' 'lock: true' > pnpm-lock.yaml
  git add -A
  git commit -q -m lock
  run env HELMSMAN_CI_BASE="$base" "$checks/ci-paths.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"audit=true"* ]]
  [[ "$output" == *"guard=false"* ]]

  run env HELMSMAN_CI_BASE= "$checks/ci-paths.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"harness=true"* ]]
  [[ "$output" == *"workflows=true"* ]]
  [[ "$output" == *"audit=true"* ]]
  [[ "$output" == *"guard=true"* ]]
}

@test "rust jobs install the toolchain the repo pins" {
  write_setup rust
  printf '%s\n' '[workspace]' 'members = []' > Cargo.toml
  printf '%s\n' '[toolchain]' 'channel = "1.99.0"' 'components = ["clippy"]' > rust-toolchain.toml
  run "$checks/../ci/emit.sh"
  [ "$status" -eq 0 ]
  [ "$(grep -c 'toolchain: 1.99.0' .github/workflows/helmsman.yml)" -eq "$(grep -c 'dtolnay/rust-toolchain' .github/workflows/helmsman.yml)" ]
  run grep -F 'toolchain: stable' .github/workflows/helmsman.yml
  [ "$status" -eq 1 ]
}

@test "rust jobs fall back to stable with no toolchain file" {
  write_setup rust
  printf '%s\n' '[workspace]' 'members = []' > Cargo.toml
  run "$checks/../ci/emit.sh"
  [ "$status" -eq 0 ]
  grep -q 'toolchain: stable' .github/workflows/helmsman.yml
}

@test "a single-quoted toolchain channel is read too" {
  write_setup rust
  printf '%s\n' '[workspace]' 'members = []' > Cargo.toml
  printf '%s\n' '[toolchain]' "channel = '1.98.1'" > rust-toolchain.toml
  run "$checks/../ci/emit.sh"
  [ "$status" -eq 0 ]
  grep -q 'toolchain: 1.98.1' .github/workflows/helmsman.yml
}

@test "every emitted action is pinned to a commit with its ref in a comment" {
  write_setup "rust, python"
  printf '%s\n' '[workspace]' 'members = []' > Cargo.toml
  printf '%s\n' '[project]' 'name = "demo"' > pyproject.toml
  mkdir -p apps/web
  run "$checks/../ci/emit.sh"
  [ "$status" -eq 0 ]
  run grep -E 'uses: ' .github/workflows/helmsman.yml
  [ "$status" -eq 0 ]
  run bash -c "grep -E 'uses: ' .github/workflows/helmsman.yml | grep -vE '@[0-9a-f]{40} # [A-Za-z0-9.-]+$'"
  [ "$status" -eq 1 ]
}
