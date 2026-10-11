#!/usr/bin/env bats
# Feature web diffs need a Playwright spec and a prove section.
# The check does not run Playwright.

setup() {
  repo="$(mktemp -d)"
  cd "$repo"
  git init -q
  git config user.email "gate@example.com"
  git config user.name "gate"
  checks="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
  git commit --allow-empty -q -m init
  mkdir -p apps/web
  printf '%s\n' 'export const page = 1;' > apps/web/App.tsx
}

teardown() {
  cd /tmp
  if [[ -n "${repo:-}" && -d "$repo" ]]; then
    rm -rf "$repo"
  fi
}

range() {
  export HELMSMAN_DIFF_RANGE="HEAD~1...HEAD"
}

@test "a feature web diff without a spec fails" {
  git add apps/web/App.tsx
  git commit -q -m "feat(web): add a page"
  range
  run "$checks/prove-web.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no Playwright spec"* ]]
}

@test "a fix that touches apps/web does not fail" {
  git add apps/web/App.tsx
  git commit -q -m "fix(web): adjust the page"
  range
  run "$checks/prove-web.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not a feature"* ]]
}

@test "a spec lets a local run skip the body" {
  printf '%s\n' 'test("home", () => {});' > apps/web/home.spec.ts
  git add apps/web
  git commit -q -m "feat(web): add a page"
  range
  run env -u HELMSMAN_PR_BODY -u GITHUB_ACTIONS -u GITHUB_EVENT_PATH "$checks/prove-web.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"checked on the pull request"* ]]
}

@test "an e2e path counts as the spec" {
  mkdir -p apps/web/e2e
  printf '%s\n' 'test("home", () => {});' > apps/web/e2e/home.ts
  git add apps/web
  git commit -q -m "feat(web): add a page"
  range
  run env -u HELMSMAN_PR_BODY -u GITHUB_ACTIONS "$checks/prove-web.sh"
  [ "$status" -eq 0 ]
}

@test "the prove section must name the evidence" {
  printf '%s\n' 'test("home", () => {});' > apps/web/home.spec.ts
  git add apps/web
  git commit -q -m "feat(web): add a page"
  range
  run env HELMSMAN_PR_TITLE="feat(web): add a page" \
    HELMSMAN_PR_BODY="$(printf '%s\n' '## How to verify locally' '' 'Looked at it.')" \
    "$checks/prove-web.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"baseline or treatment"* ]]
  run env HELMSMAN_PR_TITLE="feat(web): add a page" \
    HELMSMAN_PR_BODY="$(printf '%s\n' '## How to verify locally' '' 'Screenshots: .helmsman/reports/prove/12/treatment/home.png')" \
    "$checks/prove-web.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"prove web ok."* ]]
}

@test "CI without a body fails" {
  printf '%s\n' 'test("home", () => {});' > apps/web/home.spec.ts
  git add apps/web
  git commit -q -m "feat(web): add a page"
  range
  run env -u HELMSMAN_PR_BODY -u GITHUB_EVENT_PATH \
    GITHUB_ACTIONS=true GITHUB_EVENT_NAME=pull_request \
    "$checks/prove-web.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"missing from the pull request body"* ]]
}

@test "template text and a deleted spec do not pass" {
  printf '%s\n' 'test("home", () => {});' > apps/web/home.spec.ts
  git add apps/web
  git commit -q -m "feat(web): add a page"
  git rm -q apps/web/home.spec.ts
  printf '%s\n' 'export const page = 2;' > apps/web/App.tsx
  git add apps/web/App.tsx
  git commit -q -m "feat(web): drop the spec"
  range
  boilerplate="$(printf '%s\n' '## How to verify locally' '' 'List the screenshot paths under `.helmsman/reports/prove/`.')"
  run env HELMSMAN_PR_BODY="$boilerplate" "$checks/prove-web.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no Playwright spec"* ]]
}

@test "a test file and a breaking feature title pass" {
  mkdir -p apps/web/tests
  printf '%s\n' 'test("home", () => {});' > apps/web/tests/home.test.ts
  git add apps/web
  git commit -q -m "feat!: redo the page"
  range
  run env HELMSMAN_PR_BODY="$(printf '%s\n' '## Prove' '' '.helmsman/reports/prove/12/treatment/home.png')" \
    "$checks/prove-web.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"prove web ok."* ]]
}

@test "push skips the check" {
  git add apps/web/App.tsx
  git commit -q -m "feat(web): add a page"
  range
  run env GITHUB_EVENT_NAME=push "$checks/prove-web.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped on push"* ]]
}

@test "prove-record saves output and skips in CI" {
  run "$checks/prove-record.sh" --pr 12 --phase treatment -- bash -c 'echo hi; echo err >&2; exit 3'
  [ "$status" -eq 3 ]
  [ "$(cat .helmsman/reports/prove/12/treatment/stdout.txt)" = "hi" ]
  [ "$(cat .helmsman/reports/prove/12/treatment/stderr.txt)" = "err" ]
  [ "$(cat .helmsman/reports/prove/12/treatment/exit-code.txt)" = "3" ]
  run env GITHUB_ACTIONS=true "$checks/prove-record.sh" --pr 12 --phase baseline -- bash -c 'echo no; exit 9'
  [ "$status" -eq 0 ]
  [[ "$output" == *"prove capture skipped in CI."* ]]
  [ ! -d .helmsman/reports/prove/12/baseline ]
}
