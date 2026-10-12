#!/usr/bin/env bash
# Point the root package.json scripts at the same commands CI runs.
# Missing keys are added. A key already set to that command is left alone.
# Other scripts, including build and generate, stay as they are.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

if [[ ! -f package.json ]]; then
  echo "helmsman: no package.json. Root scripts skipped."
  exit 0
fi

python3 - << 'PY'
import json
from pathlib import Path

wanted = {
    "lint": "bash .helmsman/tools/checks/pnpm-task.sh lint",
    "lint:actions": "bash .helmsman/tools/checks/actionlint.sh",
    "format:check": "bash .helmsman/tools/checks/pnpm-task.sh format",
    "typecheck": "bash .helmsman/tools/checks/pnpm-task.sh typecheck",
    "unused": "bash .helmsman/tools/checks/pnpm-task.sh unused",
    "test": "bash .helmsman/tools/checks/pnpm-task.sh test",
    "test:integration": "bash .helmsman/tools/checks/pnpm-task.sh integration",
    "e2e:smoke": "bash .helmsman/tools/checks/pnpm-task.sh smoke",
    "audit:all": "bash .helmsman/tools/checks/pnpm-task.sh audit",
    "setup:check": "bash .helmsman/tools/checks/pnpm-task.sh setup",
    "diff:guard": "bash .helmsman/tools/checks/pnpm-task.sh diff-guard",
    "plain:language": "bash .helmsman/tools/checks/pnpm-task.sh plain",
    "prove:web": "bash .helmsman/tools/checks/prove-web.sh",
    "review:current": "bash .helmsman/tools/checks/review-current.sh",
    "fix:forward": "bash .helmsman/tools/checks/fix-forward.sh",
    "ci:paths": "bash .helmsman/tools/checks/ci-paths.sh",
    "ci:ok": "bash .helmsman/tools/checks/ci-ok.sh",
    "eslint:package": "node .helmsman/tools/eslint/check.mjs",
    "knip:package": "node .helmsman/tools/knip/check.mjs",
    "check": "bash .helmsman/tools/checks/pnpm-task.sh check",
}

path = Path("package.json")
data = json.loads(path.read_text())
scripts = data.get("scripts")
if not isinstance(scripts, dict):
    scripts = {}
changed = False
for name, command in wanted.items():
    if scripts.get(name) != command:
        scripts[name] = command
        changed = True
if not changed:
    print("helmsman: root scripts already match.")
    raise SystemExit(0)
data["scripts"] = scripts
path.write_text(json.dumps(data, indent=2) + "\n")
print("helmsman: wrote root scripts.")
PY
