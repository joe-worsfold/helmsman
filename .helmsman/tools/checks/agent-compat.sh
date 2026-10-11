#!/usr/bin/env bash
# Presence scan for the readiness report. Not a gate.
# The readiness skill and the nightly report run it. CI and setup:check do not.
# agent-compatibility@0.1.7 makes no network calls. npm exec --offline does not download it.
# Integrity: sha512-ZAViWvlUuhyV38KM+iExdld2w7x0QjkJkmCzLXZDsq4USRiq+BkjgsNfaM+v4htSDtAsHM90jsfYKmRGR/ivog==
set -euo pipefail

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "cross-check unavailable (tool environment)"
  exit 0
fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"
config="$(cd "$(dirname "$0")" && pwd)/agent-compat.json"
package="agent-compatibility@0.1.7"

if ! npm exec --offline --yes --package="$package" -- agent-compatibility --version >/dev/null 2>&1; then
  echo "cross-check unavailable (tool environment)"
  exit 0
fi

report="$(npm exec --offline --yes --package="$package" -- agent-compatibility "$root" --json --config "$config")"
SCORE_JSON="$report" python3 - << 'PY'
import json, os, sys

raw = os.environ["SCORE_JSON"]
start = raw.find("{")
end = raw.rfind("}")
if start == -1 or end == -1:
    print("cross-check unavailable (tool environment)")
    sys.exit(0)
report = json.loads(raw[start : end + 1])
score = report.get("baseScore")
maturity = report.get("maturity") or "unknown"
fails = []
for pillar in report.get("pillars") or []:
    for check in pillar.get("checks") or []:
        if check.get("status") == "fail":
            fails.append(check.get("id") or check.get("name") or "unknown")
print(f"helmsman: agent compatibility {score}/100 deterministic, {maturity}.")
print("helmsman: source agent-compatibility@0.1.7 --json, fixtures ignored.")
if fails:
    print("helmsman: presence fails: " + ", ".join(fails))
else:
    print("helmsman: presence fails: none")
PY
