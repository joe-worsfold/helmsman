#!/usr/bin/env bash
# Grade recorded patches against the Helmsman bar. See eval/README.md.
# The bash gate pins run first. They do not call a model.
set -euo pipefail
cd "$(dirname "$0")/.."
.helmsman/tools/checks/gates.test.sh
if ! command -v bats >/dev/null 2>&1; then
  echo "helmsman: bats is not installed." >&2
  exit 1
fi
bats .helmsman/tools/checks/migrate-layout.bats .helmsman/tools/checks/migrate-names.bats .helmsman/tools/checks/ci.bats .helmsman/tools/checks/review-current.bats .helmsman/tools/checks/fix-forward.bats .helmsman/tools/checks/decision-log.bats .helmsman/tools/checks/nightly-plan.bats .helmsman/tools/checks/docs-commands.bats .helmsman/tools/checks/env-example.bats .helmsman/tools/checks/prove-web.bats .helmsman/tools/checks/strict-ts.bats .helmsman/tools/checks/claude-emit.bats .helmsman/tools/checks/plugin.bats .helmsman/tools/checks/update.bats
node --test eval/failure-text.test.mjs eval/quarantine.test.mjs eval/readiness.test.mjs .helmsman/tools/watermark/gh.test.mjs
node eval/run.mjs
