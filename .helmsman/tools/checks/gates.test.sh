#!/usr/bin/env bash
# Pins for the bash gates. Temp git repos. No network and no database.
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
tmp=""

cleanup() {
  cd "$root"
  if [[ -n "${tmp}" && -d "${tmp}" ]]; then
    rm -rf "$tmp"
  fi
}
trap cleanup EXIT

new_repo() {
  cleanup
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  git -C "$tmp" config user.email "gate@example.com"
  git -C "$tmp" config user.name "gate"
  cd "$tmp"
}

track() {
  git -C "$tmp" add -A
}

expect_exit() {
  local want="$1"
  shift
  local out
  local status
  set +e
  out="$("$@" 2>&1)"
  status=$?
  set -e
  if [[ "$status" -ne "$want" ]]; then
    echo "helmsman: want exit $want, got $status for: $*" >&2
    printf '%s\n' "$out" >&2
    exit 1
  fi
  printf '%s\n' "$out"
}

echo "delegate: nothing"
new_repo
out="$(expect_exit 10 "$root/.helmsman/tools/checks/delegate-gate.sh")"
printf '%s\n' "$out" | grep -q "Nothing delegated"
out="$(expect_exit 10 "$root/.helmsman/tools/checks/delegate-gate.sh" --probe)"

echo "delegate: package check passes as 11"
new_repo
cat > "$tmp/package.json" << 'EOF'
{"name":"gate-test","private":true,"scripts":{"check":"node -e \"process.exit(0)\""}}
EOF
out="$(expect_exit 11 "$root/.helmsman/tools/checks/delegate-gate.sh")"
printf '%s\n' "$out" | grep -q "delegated to npm run check"
expect_exit 10 "$root/.helmsman/tools/checks/delegate-gate.sh" --probe >/dev/null

echo "delegate: pnpm field wins"
new_repo
cat > "$tmp/package.json" << 'EOF'
{"name":"gate-test","private":true,"packageManager":"pnpm@12.8.2","scripts":{"check":"node -e \"process.exit(0)\""}}
EOF
out="$(expect_exit 11 "$root/.helmsman/tools/checks/delegate-gate.sh")"
printf '%s\n' "$out" | grep -q "delegated to pnpm check"

echo "delegate: pnpm lock beats a yarn lock"
new_repo
cat > "$tmp/package.json" << 'EOF'
{"name":"gate-test","private":true,"scripts":{"check":"node -e \"process.exit(0)\""}}
EOF
: > "$tmp/pnpm-lock.yaml"
: > "$tmp/yarn.lock"
out="$(expect_exit 11 "$root/.helmsman/tools/checks/delegate-gate.sh")"
printf '%s\n' "$out" | grep -q "delegated to pnpm check"

echo "delegate: yarn lock is a legacy fallback"
new_repo
cat > "$tmp/package.json" << 'EOF'
{"name":"gate-test","private":true,"scripts":{"check":"node -e \"process.exit(0)\""}}
EOF
: > "$tmp/yarn.lock"
if command -v yarn >/dev/null 2>&1; then
  out="$(expect_exit 11 "$root/.helmsman/tools/checks/delegate-gate.sh")"
  printf '%s\n' "$out" | grep -q "delegated to yarn run check"
else
  out="$(expect_exit 1 "$root/.helmsman/tools/checks/delegate-gate.sh")"
  printf '%s\n' "$out" | grep -q "yarn is not installed"
fi

echo "delegate: package check failure is the script status"
new_repo
cat > "$tmp/package.json" << 'EOF'
{"name":"gate-test","private":true,"scripts":{"check":"node -e \"process.exit(4)\""}}
EOF
expect_exit 4 "$root/.helmsman/tools/checks/delegate-gate.sh" >/dev/null

echo "delegate: make check wins over package.json"
new_repo
printf '%s\n' 'check:' '	true' > "$tmp/Makefile"
cat > "$tmp/package.json" << 'EOF'
{"name":"gate-test","private":true,"scripts":{"check":"node -e \"process.exit(4)\""}}
EOF
out="$(expect_exit 0 "$root/.helmsman/tools/checks/delegate-gate.sh")"
printf '%s\n' "$out" | grep -q "delegated to make check"
expect_exit 0 "$root/.helmsman/tools/checks/delegate-gate.sh" --probe >/dev/null

quiet_report() {
  env -u HELMSMAN_WRITE_REPORTS -u CURSOR_AGENT -u GITHUB_ACTIONS -u CI "$@"
}

echo "reports: local default is chat only"
new_repo
printf '%s\n' '.helmsman/*' '!.helmsman/setup.md' > "$tmp/.gitignore"
out="$(expect_exit 10 quiet_report HELMSMAN_REPORT_STAMP=2026-09-30T0629Z "$root/.helmsman/tools/checks/report-write.sh" readiness.md)"
printf '%s\n' "$out" | grep -q "report stays in the reply"
if [[ -d "$tmp/.helmsman/reports" ]]; then
  echo "helmsman: report directory was created without a write env" >&2
  exit 1
fi

echo "reports: explicit env writes a gitignored path"
new_repo
printf '%s\n' '.helmsman/*' '!.helmsman/setup.md' > "$tmp/.gitignore"
out="$(expect_exit 0 quiet_report HELMSMAN_WRITE_REPORTS=1 HELMSMAN_REPORT_STAMP=2026-09-30T0629Z "$root/.helmsman/tools/checks/report-write.sh" readiness.md)"
printf '%s\n' "$out" | grep -q ".helmsman/reports/2026-09-30T0629Z/readiness.md"
test -d "$tmp/.helmsman/reports/2026-09-30T0629Z"

echo "reports: cloud agent env writes when the path is ignored"
new_repo
printf '%s\n' '.helmsman/*' '!.helmsman/setup.md' > "$tmp/.gitignore"
out="$(expect_exit 0 quiet_report CURSOR_AGENT=1 HELMSMAN_REPORT_STAMP=2026-09-30T0629Z "$root/.helmsman/tools/checks/report-write.sh" slop.md)"
printf '%s\n' "$out" | grep -q ".helmsman/reports/2026-09-30T0629Z/slop.md"

echo "reports: a tracked path is not written"
new_repo
out="$(expect_exit 10 quiet_report HELMSMAN_WRITE_REPORTS=1 HELMSMAN_REPORT_STAMP=2026-09-30T0629Z "$root/.helmsman/tools/checks/report-write.sh" security.md)"
printf '%s\n' "$out" | grep -q "is not gitignored"
if [[ -d "$tmp/.helmsman/reports" ]]; then
  echo "helmsman: report directory was created for a path git would track" >&2
  exit 1
fi

echo "reports: latest stamp directory"
new_repo
mkdir -p "$tmp/.helmsman/reports/2026-09-30T0629Z" "$tmp/.helmsman/reports/2026-09-30T0700Z"
out="$(expect_exit 0 "$root/.helmsman/tools/checks/report-write.sh" --latest)"
printf '%s\n' "$out" | grep -q ".helmsman/reports/2026-09-30T0700Z"

echo "reports: bad stamp is rejected"
new_repo
expect_exit 2 quiet_report HELMSMAN_WRITE_REPORTS=1 HELMSMAN_REPORT_STAMP='../x' "$root/.helmsman/tools/checks/report-write.sh" readiness.md >/dev/null

echo "secrets: clean tree"
new_repo
printf '%s\n' 'plain' > "$tmp/notes.txt"
track
expect_exit 0 "$root/.helmsman/tools/secrets/check.sh" >/dev/null

echo "secrets: key fails"
new_repo
printf '%s%s\n' 'AKIA' 'IOSFODNN7EXAMPLE' > "$tmp/leaked.txt"
track
expect_exit 1 "$root/.helmsman/tools/secrets/check.sh" >/dev/null

echo "silences: clean tree"
new_repo
printf '%s\n' 'export const n = 1;' > "$tmp/ok.js"
track
expect_exit 0 "$root/.helmsman/tools/checks/no-silences.sh" >/dev/null

echo "silences: token fails"
new_repo
printf '%s\n' "// $(printf '%s-%s' eslint disable)" > "$tmp/bad.js"
track
expect_exit 1 "$root/.helmsman/tools/checks/no-silences.sh" >/dev/null

echo "surreal: skip"
new_repo
track
expect_exit 0 "$root/.helmsman/tools/surreal/check.sh" >/dev/null

echo "surreal: empty schema fails"
new_repo
: > "$tmp/schema.surql"
track
expect_exit 1 "$root/.helmsman/tools/surreal/check.sh" >/dev/null

echo "surreal: schema without Integration fails"
new_repo
mkdir -p "$tmp/.helmsman"
printf '%s\n' 'DEFINE TABLE item SCHEMAFULL;' > "$tmp/schema.surql"
printf '%s\n' '# Setup' 'Surfaces: none' 'Integration: none' > "$tmp/.helmsman/setup.md"
track
expect_exit 1 "$root/.helmsman/tools/surreal/check.sh" >/dev/null

echo "surreal: schema and Integration pass"
new_repo
mkdir -p "$tmp/.helmsman"
printf '%s\n' 'DEFINE TABLE item SCHEMAFULL;' > "$tmp/schema.surql"
printf '%s\n' '# Setup' 'Integration: echo integration' > "$tmp/.helmsman/setup.md"
track
expect_exit 0 "$root/.helmsman/tools/surreal/check.sh" >/dev/null

echo "repo checks: no line skips"
new_repo
mkdir -p "$tmp/.helmsman"
printf '%s\n' '# Setup' 'Integration: none' > "$tmp/.helmsman/setup.md"
out="$(expect_exit 0 "$root/.helmsman/tools/checks/repo-checks.sh")"
printf '%s\n' "$out" | grep -q "no repo checks"

echo "repo checks: a failing command fails"
new_repo
mkdir -p "$tmp/.helmsman"
printf '%s\n' '# Setup' 'Repo checks: echo ran && exit 3' > "$tmp/.helmsman/setup.md"
out="$(expect_exit 3 "$root/.helmsman/tools/checks/repo-checks.sh")"
printf '%s\n' "$out" | grep -q "^ran$"

echo "postgres: sql without a config skips"
new_repo
mkdir -p "$tmp/migrations"
printf '%s\n' 'select 1;' > "$tmp/migrations/001.sql"
track
out="$(expect_exit 0 "$root/.helmsman/tools/postgres/check.sh")"
printf '%s\n' "$out" | grep -q "skip"

echo "postgres: config without sqlfluff fails"
new_repo
mkdir -p "$tmp/migrations"
printf '%s\n' 'select 1;' > "$tmp/migrations/001.sql"
printf '%s\n' '[sqlfluff]' 'dialect = postgres' > "$tmp/.sqlfluff"
track
expect_exit 1 "$root/.helmsman/tools/postgres/check.sh" >/dev/null

echo "dynamodb: bad json fails"
new_repo
mkdir -p "$tmp/dynamodb"
printf '%s\n' '{' > "$tmp/dynamodb/table.json"
track
expect_exit 1 "$root/.helmsman/tools/dynamodb/check.sh" >/dev/null

echo "dynamodb: table json passes"
new_repo
mkdir -p "$tmp/dynamodb"
printf '%s\n' '{"TableName":"item","KeySchema":[{"AttributeName":"id","KeyType":"HASH"}]}' > "$tmp/dynamodb/table.json"
track
expect_exit 0 "$root/.helmsman/tools/dynamodb/check.sh" >/dev/null

echo "opensearch: mapping without mappings fails"
new_repo
mkdir -p "$tmp/opensearch"
printf '%s\n' '{"settings":{}}' > "$tmp/opensearch/mapping.json"
track
expect_exit 1 "$root/.helmsman/tools/opensearch/check.sh" >/dev/null

echo "opensearch: mapping passes"
new_repo
mkdir -p "$tmp/opensearch"
printf '%s\n' '{"mappings":{"properties":{"title":{"type":"text"}}}}' > "$tmp/opensearch/mapping.json"
track
expect_exit 0 "$root/.helmsman/tools/opensearch/check.sh" >/dev/null

echo "python: uv missing fails"
new_repo
printf '%s\n' '[project]' 'name = "gate"' 'version = "0.0.0"' > "$tmp/pyproject.toml"
track
no_uv="$tmp/no-uv-bin"
mkdir "$no_uv"
for tool in bash git dirname; do ln -s "$(command -v "$tool")" "$no_uv/$tool"; done
expect_exit 1 env PATH="$no_uv" "$root/.helmsman/tools/python/check.sh" >/dev/null

echo "ci paths: unknown range runs both"
new_repo
git commit --allow-empty -q -m init
out="$(expect_exit 0 "$root/.helmsman/tools/checks/ci-paths.sh")"
printf '%s\n' "$out" | grep -q '^eslint=true$'
printf '%s\n' "$out" | grep -q '^knip=true$'
printf '%s\n' "$out" | grep -q '^ts=true$'

echo "ci paths: zero base runs both"
out="$(HELMSMAN_CI_BASE=0000000000000000000000000000000000000000 expect_exit 0 "$root/.helmsman/tools/checks/ci-paths.sh")"
printf '%s\n' "$out" | grep -q '^eslint=true$'

echo "ci paths: untouched files skip both"
printf '%s\n' 'note' > "$tmp/README.md"
git add README.md
git commit -q -m readme
out="$(HELMSMAN_CI_BASE="$(git rev-parse HEAD~1)" expect_exit 0 "$root/.helmsman/tools/checks/ci-paths.sh")"
printf '%s\n' "$out" | grep -q '^eslint=false$'
printf '%s\n' "$out" | grep -q '^knip=false$'
printf '%s\n' "$out" | grep -q '^docs=true$'
printf '%s\n' "$out" | grep -q '^rust=false$'
printf '%s\n' "$out" | grep -q '^ts=false$'
printf '%s\n' "$out" | grep -q '^harness=false$'

echo "ci paths: eslint tree"
mkdir -p "$tmp/.helmsman/tools/eslint"
printf '%s\n' 'x' > "$tmp/.helmsman/tools/eslint/note"
git add .helmsman/tools/eslint/note
git commit -q -m eslint
out="$(HELMSMAN_CI_BASE="$(git rev-parse HEAD~1)" expect_exit 0 "$root/.helmsman/tools/checks/ci-paths.sh")"
printf '%s\n' "$out" | grep -q '^eslint=true$'
printf '%s\n' "$out" | grep -q '^knip=false$'

echo "ci paths: knip tree"
new_repo
git commit --allow-empty -q -m init
mkdir -p "$tmp/.helmsman/tools/knip"
printf '%s\n' 'x' > "$tmp/.helmsman/tools/knip/note"
git add .helmsman/tools/knip/note
git commit -q -m knip
out="$(HELMSMAN_CI_BASE="$(git rev-parse HEAD~1)" expect_exit 0 "$root/.helmsman/tools/checks/ci-paths.sh")"
printf '%s\n' "$out" | grep -q '^eslint=false$'
printf '%s\n' "$out" | grep -q '^knip=true$'

echo "ci paths: workflow runs both"
mkdir -p "$tmp/.github/workflows"
printf '%s\n' 'name: helmsman' > "$tmp/.github/workflows/helmsman.yml"
git add .github/workflows/helmsman.yml
git commit -q -m workflow
out="$(HELMSMAN_CI_BASE="$(git rev-parse HEAD~1)" expect_exit 0 "$root/.helmsman/tools/checks/ci-paths.sh")"
printf '%s\n' "$out" | grep -q '^eslint=true$'
printf '%s\n' "$out" | grep -q '^knip=true$'

echo "ci paths: a rule change runs the harness"
new_repo
git commit --allow-empty -q -m init
mkdir -p "$tmp/.cursor/rules"
printf '%s\n' 'rule' > "$tmp/.cursor/rules/example.mdc"
git add .cursor/rules/example.mdc
git commit -q -m rule
out="$(HELMSMAN_CI_BASE="$(git rev-parse HEAD~1)" expect_exit 0 "$root/.helmsman/tools/checks/ci-paths.sh")"
printf '%s\n' "$out" | grep -q '^harness=true$'

echo "ci paths: a skill change runs the harness"
new_repo
git commit --allow-empty -q -m init
mkdir -p "$tmp/.cursor/skills/example"
printf '%s\n' 'skill' > "$tmp/.cursor/skills/example/SKILL.md"
git add .cursor/skills/example/SKILL.md
git commit -q -m skill
out="$(HELMSMAN_CI_BASE="$(git rev-parse HEAD~1)" expect_exit 0 "$root/.helmsman/tools/checks/ci-paths.sh")"
printf '%s\n' "$out" | grep -q '^harness=true$'

echo "ci paths: rust file is rust only"
new_repo
git commit --allow-empty -q -m init
printf '%s\n' 'fn main() {}' > "$tmp/lib.rs"
git add lib.rs
git commit -q -m rust
out="$(HELMSMAN_CI_BASE="$(git rev-parse HEAD~1)" expect_exit 0 "$root/.helmsman/tools/checks/ci-paths.sh")"
printf '%s\n' "$out" | grep -q '^rust=true$'
printf '%s\n' "$out" | grep -q '^ts=false$'

echo "expo doctor stays opt-in"
cd "$root"
expect_exit 0 "$root/.helmsman/tools/expo/doctor.sh" >/dev/null

echo "bash -n on this repo"
expect_exit 0 "$root/.helmsman/tools/checks/bash-n.sh" >/dev/null

echo "toolchain: declared version matches"
expect_exit 0 "$root/.helmsman/tools/checks/toolchain-latest.sh" --expect ">=26.10.0" "26.10.0" >/dev/null
expect_exit 0 "$root/.helmsman/tools/checks/toolchain-latest.sh" --expect "^7.0.2" "7.0.2" >/dev/null
expect_exit 0 "$root/.helmsman/tools/checks/toolchain-latest.sh" --expect "26" "26.10.0" >/dev/null

echo "toolchain: older pin fails"
expect_exit 1 "$root/.helmsman/tools/checks/toolchain-latest.sh" --expect ">=26.9.0" "26.10.0" >/dev/null
expect_exit 1 "$root/.helmsman/tools/checks/toolchain-latest.sh" --expect "25" "26.10.0" >/dev/null

echo "toolchain: bad args"
expect_exit 2 "$root/.helmsman/tools/checks/toolchain-latest.sh" --expect only-one >/dev/null

echo "upstream: this tree matches its pin"
expect_exit 0 "$root/.helmsman/tools/checks/upstream.sh" >/dev/null

echo "upstream: no pin skips"
new_repo
out="$(expect_exit 0 "$root/.helmsman/tools/checks/upstream.sh" "$tmp")"
printf '%s\n' "$out" | grep -q "upstream check skipped"

echo "upstream: a hand edit fails"
mkdir -p "$tmp/.helmsman/tools/upstream/sample"
printf '%s\n' 'pinned' > "$tmp/.helmsman/tools/upstream/sample/NOTE"
hash="$(sha256sum "$tmp/.helmsman/tools/upstream/sample/NOTE" | awk '{print $1}')"
mkdir -p "$tmp/.cursor/rules"
printf '%s\n' 'rule' > "$tmp/.cursor/rules/keep.mdc"
python3 - "$tmp" "$hash" << 'PY'
import json, sys
from pathlib import Path
root, digest = Path(sys.argv[1]), sys.argv[2]
lock = {
    "entries": [{
        "name": "sample",
        "repo": "example/sample",
        "ref": "v0",
        "commit": "abc",
        "date": "2026-10-11",
        "license": "MIT",
        "files": [{"path": "NOTE", "sha256": digest}],
        "adopted_in": [".cursor/rules/keep.mdc"],
    }]
}
path = root / ".helmsman/tools/upstream/upstream.json"
path.write_text(json.dumps(lock, indent=2) + "\n")
PY
expect_exit 0 "$root/.helmsman/tools/checks/upstream.sh" "$tmp" >/dev/null
printf '%s\n' 'edited' > "$tmp/.helmsman/tools/upstream/sample/NOTE"
out="$(expect_exit 1 "$root/.helmsman/tools/checks/upstream.sh" "$tmp")"
printf '%s\n' "$out" | grep -q "was edited"

echo "plain language: brand and folder pass"
new_repo
printf '%s\n' 'Helmsman checks .helmsman/setup.md' > "$tmp/note.md"
track
expect_exit 0 "$root/.helmsman/tools/checks/plain-language.sh" >/dev/null

echo "plain language: old word fails"
new_repo
banned="$(printf '%s%s' sa il)"
printf '%s\n' "use the ${banned} script" > "$tmp/note.md"
track
expect_exit 1 "$root/.helmsman/tools/checks/plain-language.sh" >/dev/null

echo "plain language: history file is allowed"
new_repo
mkdir -p "$tmp/docs"
printf '%s\n' "old name ${banned}" > "$tmp/docs/renames.md"
track
expect_exit 0 "$root/.helmsman/tools/checks/plain-language.sh" >/dev/null

echo "plain language: committed lines are not scanned"
new_repo
printf '%s\n' "use the ${banned} script" > "$tmp/old.md"
track
git -C "$tmp" commit -q -m old
printf '%s\n' 'a plain sentence' > "$tmp/new.md"
track
expect_exit 0 "$root/.helmsman/tools/checks/plain-language.sh" >/dev/null

echo "lint filter: bash still syntax-checks"
out="$(cd "$root" && HELMSMAN_FILTER=bash "$root/.helmsman/tools/checks/pnpm-task.sh" lint)"
printf '%s\n' "$out" | grep -q 'bash -n ok.'

echo "lint filter: typescript does not syntax-check shell"
out="$(cd "$root" && HELMSMAN_FILTER=ts "$root/.helmsman/tools/checks/pnpm-task.sh" lint)"
printf '%s\n' "$out" | grep -q 'no ESLint config'
if printf '%s\n' "$out" | grep -q 'bash -n ok.'; then
  echo "helmsman: typescript filter ran bash -n" >&2
  exit 1
fi

echo "lint filter: an empty filter still syntax-checks shell"
out="$(cd "$root" && HELMSMAN_FILTER= "$root/.helmsman/tools/checks/pnpm-task.sh" lint)"
printf '%s\n' "$out" | grep -q 'bash -n ok.'

echo "gates: ok"
