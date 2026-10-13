#!/usr/bin/env bash
# Tell CI which jobs this diff needs.
# Unknown range fails open: every filtered job runs.
# audit, setup, harness, workflows, and the diff guard are outputs too.
# A lockfile-only diff sets audit and leaves the diff guard false.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

eslint=false
knip=false
ts=false
rust=false
python=false
schema=false
web=false
api=false
docs=false
setup=false
harness=false
workflows=false
audit=false
guard=false

emit_all() {
  local key line
  for key in eslint knip ts rust python schema web api docs setup harness workflows audit guard; do
    line="${key}=${!key}"
    printf '%s\n' "$line"
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
      printf '%s\n' "$line" >> "$GITHUB_OUTPUT"
    fi
  done
}

open_all() {
  eslint=true
  knip=true
  ts=true
  rust=true
  python=true
  schema=true
  web=true
  api=true
  docs=true
  setup=true
  harness=true
  workflows=true
  audit=true
  guard=true
}

base="${HELMSMAN_CI_BASE:-}"
if [[ -z "$base" || "$base" =~ ^0+$ ]]; then
  echo "helmsman: CI path range is unknown. Filtered jobs run." >&2
  open_all
  emit_all
  exit 0
fi

if ! git cat-file -e "${base}^{commit}" >/dev/null 2>&1; then
  echo "helmsman: CI base is not in this clone. Filtered jobs run." >&2
  open_all
  emit_all
  exit 0
fi

while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  base="${file##*/}"
  case "$file" in
    .helmsman/tools/eslint | .helmsman/tools/eslint/* | .github/workflows/helmsman.yml | .helmsman/tools/checks/ci-paths.sh)
      eslint=true
      ;;
  esac
  case "$file" in
    .helmsman/tools/knip | .helmsman/tools/knip/* | .github/workflows/helmsman.yml | .helmsman/tools/checks/ci-paths.sh)
      knip=true
      ;;
  esac
  case "$file" in
    .helmsman/tools/* | eval/* | .cursor/rules/* | .cursor/skills/* | .cursor/automations/* | .claude/rules/* | .claude/skills/* | CLAUDE.md)
      harness=true
      ;;
  esac
  case "$file" in
    .github/workflows/* | .github/actions/*)
      workflows=true
      ;;
  esac
  case "$base" in
    package.json | pnpm-lock.yaml | Cargo.toml | Cargo.lock | pyproject.toml | uv.lock | deny.toml)
      audit=true
      ;;
  esac
  case "$file" in
    pnpm-workspace.yaml | rust-toolchain.toml | .nvmrc)
      audit=true
      ;;
  esac
  case "$base" in
    pnpm-lock.yaml | Cargo.lock | uv.lock) ;;
    *) guard=true ;;
  esac
  case "$file" in
    .helmsman/* | .github/* | lefthook.yml | turbo.json | pnpm-workspace.yaml | package.json | pnpm-lock.yaml | .nvmrc | .python-version | rust-toolchain.toml | *.sh | *.bash | *.rs | *.py | *.js | *.jsx | *.ts | *.tsx | *.mjs | *.cjs | *.mts | *.cts | *.surql | *.sql | *.toml | *.yml | *.yaml | *.json)
      setup=true
      ;;
  esac
  case "$file" in
    eval/*.ts | eval/*.tsx | eval/*.mts | eval/*.mjs | eval/tsconfig.json | tsconfig.json)
      ts=true
      ;;
  esac
  case "$file" in
    .helmsman/* | eval/*) continue ;;
  esac
  case "$file" in
    apps/web/* | apps/mobile/* | *playwright* | *cypress*)
      web=true
      ts=true
      ;;
    apps/api/* | apps/mcp/*)
      api=true
      rust=true
      ;;
  esac
  case "$file" in
    *.ts | *.tsx | *.js | *.jsx | *.mts | *.cts | packages/*/ts/*)
      ts=true
      ;;
  esac
  case "$file" in
    *.rs | Cargo.toml | Cargo.lock | */Cargo.toml | */Cargo.lock | clippy.toml | .clippy.toml | rustfmt.toml | .rustfmt.toml | packages/*/rs/*)
      rust=true
      ;;
  esac
  case "$file" in
    *.py | pyproject.toml | uv.lock | */pyproject.toml | */uv.lock | packages/*/py/*)
      python=true
      ;;
  esac
  case "$file" in
    *.surql | *.sql | schema/* | */schema/* | docker-compose.yml | docker-compose.yaml | compose.yml | compose.yaml)
      schema=true
      ;;
  esac
  case "$file" in
    *.md | docs/*)
      docs=true
      ;;
  esac
done < <(git diff --name-only "$base" HEAD)

echo "helmsman: CI paths eslint=$eslint knip=$knip ts=$ts rust=$rust python=$python schema=$schema web=$web api=$api docs=$docs setup=$setup harness=$harness workflows=$workflows audit=$audit guard=$guard" >&2
emit_all
