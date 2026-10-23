#!/usr/bin/env bash
# Turn on the helmsman Claude Code plugin for this repo, pinned to one Helmsman commit.
#
#   .helmsman/tools/plugin/enable.sh <40-char sha>   write the pin into .claude/settings.json
#   .helmsman/tools/plugin/enable.sh --check         fail when the plugin is not enabled and pinned
#
# The pin is an inline catalog (marketplace source type "settings") whose one entry fetches
# joe-worsfold/helmsman at that sha, so every teammate's Claude Code loads the same commit.
# The plugin carries the watermark and lane cap hooks, so the project-level copies are removed.
# Other settings are kept. Running it again with the same sha changes nothing.
set -euo pipefail

case "${1:-}" in
  -h | --help | "")
    echo "helmsman: enable.sh <sha> | --check"
    echo "  .helmsman/tools/plugin/enable.sh 4b1c2362c58d7093fe0d5ab44281673f79ea7db4"
    [[ -n "${1:-}" ]] && exit 0
    exit 2
    ;;
esac

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

ARG="$1" python3 - << 'PY'
import json
import os
import re
import sys
from pathlib import Path

arg = os.environ["ARG"]
check = arg == "--check"
if not check and not re.fullmatch(r"[0-9a-f]{40}", arg):
    print(f"helmsman: {arg} is not a full 40-character commit sha.", file=sys.stderr)
    sys.exit(2)

path = Path(".claude/settings.json")
try:
    data = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
except json.JSONDecodeError as exc:
    print(f"helmsman: {path} is not valid JSON: {exc}", file=sys.stderr)
    sys.exit(1)

entry = data.get("extraKnownMarketplaces", {}).get("helmsman", {})
plugins = entry.get("source", {}).get("plugins", [])
pinned = next((p.get("source", {}).get("sha") for p in plugins if p.get("name") == "helmsman"), None)
enabled = data.get("enabledPlugins", {}).get("helmsman@helmsman") is True

if check:
    if not (enabled and pinned):
        print(f"helmsman: the helmsman plugin is not enabled and pinned in {path}. Run .helmsman/tools/plugin/enable.sh <sha>.", file=sys.stderr)
        sys.exit(1)
    print(f"helmsman: helmsman plugin pinned at {pinned}.")
    sys.exit(0)

data.setdefault("extraKnownMarketplaces", {})["helmsman"] = {
    "source": {
        "source": "settings",
        "name": "helmsman",
        "owner": {"name": "Joe Worsfold"},
        "plugins": [{"name": "helmsman", "source": {"source": "github", "repo": "joe-worsfold/helmsman", "sha": arg}}],
    }
}
data.setdefault("enabledPlugins", {})["helmsman@helmsman"] = True

pre = data.get("hooks", {}).get("PreToolUse", [])
for block in pre:
    block["hooks"] = [h for h in block.get("hooks", []) if not any(s in h.get("command", "") for s in ("watermark/hook.mjs", "lanes/lanes.sh"))]
pre[:] = [b for b in pre if b.get("hooks")]
if "hooks" in data and not pre:
    data["hooks"].pop("PreToolUse", None)
    if not data["hooks"]:
        data.pop("hooks")

path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
print(f"helmsman: helmsman plugin pinned at {arg} in {path}.")
PY
