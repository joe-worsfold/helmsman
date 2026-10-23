#!/usr/bin/env bash
# Register the watermark pre-tool hook for Claude Code and Cursor, and the lane cap hook for Claude Code.
#
#   .claude/settings.json  hooks.PreToolUse, matcher Bash and mcp__ tools
#   .cursor/hooks.json     hooks.preToolUse, matcher Shell and MCP: tools
#
# Other settings and hooks are kept. Running it again changes nothing.
# --check fails when either file is missing the hook. It writes nothing.
set -euo pipefail

mode="write"
case "${1:-}" in
  "") mode="write" ;;
  --check) mode="check" ;;
  -h | --help)
    echo "helmsman: hooks-install.sh [--check]"
    echo "  bash .helmsman/tools/watermark/hooks-install.sh   register the hook in .claude and .cursor"
    exit 0
    ;;
  *)
    echo "helmsman: hooks-install.sh [--check]" >&2
    exit 2
    ;;
esac

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

MODE="$mode" python3 - << 'PY'
import json
import os
import sys
from pathlib import Path

mode = os.environ["MODE"]
script = ".helmsman/tools/watermark/hook.mjs"
problems = []


def load(path):
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"helmsman: {path} is not valid JSON: {exc}", file=sys.stderr)
        sys.exit(1)


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print(f"helmsman: wrote the hooks to {path}")


claude_path = Path(".claude/settings.json")
claude = load(claude_path)
# The helmsman plugin carries these hooks, so a repo that enables it needs no project copy.
plugin = claude.get("enabledPlugins", {}).get("helmsman@helmsman") is True
lanes = ".helmsman/tools/lanes/lanes.sh"
claude_hooks = [
    ("watermark", script, "^(Bash|mcp__.*)$", f'node "$CLAUDE_PROJECT_DIR"/{script}'),
    ("lane cap", lanes, "^(Bash|Agent|EnterWorktree)$", f'bash "$CLAUDE_PROJECT_DIR"/{lanes} hook'),
]
for name, path, matcher, command in [] if plugin else claude_hooks:
    pre = claude.get("hooks", {}).get("PreToolUse", [])
    if any(path in h.get("command", "") for b in pre for h in b.get("hooks", [])):
        continue
    if mode == "check":
        problems.append(f"{claude_path} has no {name} hook")
        continue
    pre = claude.setdefault("hooks", {}).setdefault("PreToolUse", [])
    pre.append({"matcher": matcher, "hooks": [{"type": "command", "command": command, "timeout": 10}]})
    save(claude_path, claude)

cursor_path = Path(".cursor/hooks.json")
cursor = load(cursor_path)
cursor.setdefault("version", 1)
pre = cursor.setdefault("hooks", {}).setdefault("preToolUse", [])
if not any(script in h.get("command", "") for h in pre):
    if mode == "check":
        problems.append(f"{cursor_path} has no watermark hook")
    else:
        pre.append({"command": f"node {script}", "matcher": "^(Shell|MCP:.*)$", "timeout": 10})
        save(cursor_path, cursor)

if problems:
    for p in problems:
        print(f"helmsman: {p}. Run .helmsman/tools/watermark/hooks-install.sh.", file=sys.stderr)
    sys.exit(1)
if mode == "check":
    print("helmsman: hooks are registered.")
PY
