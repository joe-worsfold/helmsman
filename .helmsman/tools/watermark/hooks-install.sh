#!/usr/bin/env bash
# Register the watermark and lane cap pre-tool hooks for Claude Code and Cursor.
#
#   .claude/settings.json  hooks.PreToolUse: watermark on Bash and mcp__ tools, lane cap on Bash, Agent, EnterWorktree
#   .cursor/hooks.json     hooks.preToolUse: watermark on Shell and MCP: tools, lane cap on Shell
#
# Other settings and hooks are kept. Running it again changes nothing.
# --check fails when either file is missing a hook. It writes nothing.
#
# --user installs the watermark hook for every session on this machine. Claude Code loads a
# repo's .claude/settings.json only for a session started inside that repo, so an agent started
# in a parent folder, or in a bare repo that holds worktrees, posts with no watermark.
#
#   ~/.local/share/helmsman/watermark/    a copy of hook.mjs, gh.mjs, and bin/gh (HELMSMAN_HOME overrides the root)
#   ~/.claude/settings.json               hooks.PreToolUse: watermark on Bash and mcp__ tools (CLAUDE_CONFIG_DIR overrides)
#   ~/.cursor/hooks.json                  hooks.preToolUse: watermark on Shell and MCP: tools, when ~/.cursor exists
#
# Run it again after a Helmsman update to refresh the copy. --user --check fails when the copy
# differs from this checkout or a hook is missing.
set -euo pipefail

usage="helmsman: hooks-install.sh [--user] [--check]"
mode="write"
scope="repo"
for arg in "$@"; do
  case "$arg" in
    --check) mode="check" ;;
    --user) scope="user" ;;
    -h | --help)
      echo "$usage"
      echo "  bash .helmsman/tools/watermark/hooks-install.sh          register the hooks in .claude and .cursor"
      echo "  bash .helmsman/tools/watermark/hooks-install.sh --user   install the watermark hook for every session"
      exit 0
      ;;
    *)
      echo "$usage" >&2
      exit 2
      ;;
  esac
done

if [[ "$scope" == "user" ]]; then
  src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  dest="${HELMSMAN_HOME:-$HOME/.local/share/helmsman}/watermark"
  files=(hook.mjs gh.mjs bin/gh)
  if [[ "$mode" == "write" ]]; then
    mkdir -p "$dest/bin"
    for f in "${files[@]}"; do cp "$src/$f" "$dest/$f"; done
    chmod +x "$dest/bin/gh"
    echo "helmsman: copied the watermark hook to $dest"
  fi
  MODE="$mode" DEST="$dest" SRC="$src" FILES="${files[*]}" python3 - << 'PY'
import filecmp
import json
import os
import sys
from pathlib import Path

mode, dest, src = os.environ["MODE"], Path(os.environ["DEST"]), Path(os.environ["SRC"])
hook = dest / "hook.mjs"
problems = []

for f in os.environ["FILES"].split():
    if not (dest / f).exists() or not filecmp.cmp(src / f, dest / f, shallow=False):
        problems.append(f"{dest / f} does not match {src / f}")


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
    print(f"helmsman: wrote the watermark hook to {path}")


claude_path = Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude") / "settings.json"
claude = load(claude_path)
pre = claude.get("hooks", {}).get("PreToolUse", [])
if not any(str(hook) in h.get("command", "") for b in pre for h in b.get("hooks", [])):
    if mode == "check":
        problems.append(f"{claude_path} has no watermark hook")
    else:
        pre = claude.setdefault("hooks", {}).setdefault("PreToolUse", [])
        pre.append({"matcher": "^(Bash|mcp__.*)$", "hooks": [{"type": "command", "command": f'node "{hook}"', "timeout": 10}]})
        save(claude_path, claude)

cursor_path = Path.home() / ".cursor" / "hooks.json"
if cursor_path.parent.is_dir():
    cursor = load(cursor_path)
    if not any(str(hook) in h.get("command", "") for h in cursor.get("hooks", {}).get("preToolUse", [])):
        if mode == "check":
            problems.append(f"{cursor_path} has no watermark hook")
        else:
            cursor.setdefault("version", 1)
            cursor.setdefault("hooks", {}).setdefault("preToolUse", []).append(
                {"command": f'node "{hook}"', "matcher": "^(Shell|MCP:.*)$", "timeout": 10}
            )
            save(cursor_path, cursor)

if mode == "check":
    if problems:
        for p in problems:
            print(f"helmsman: {p}. Run .helmsman/tools/watermark/hooks-install.sh --user.", file=sys.stderr)
        sys.exit(1)
    print("helmsman: the user watermark hook is installed.")
PY
  exit
fi

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
cursor_hooks = [
    ("watermark", script, "^(Shell|MCP:.*)$", f"node {script}"),
    ("lane cap", lanes, "^Shell$", f"bash {lanes} hook"),
]
for name, path, matcher, command in cursor_hooks:
    if any(path in h.get("command", "") for h in pre):
        continue
    if mode == "check":
        problems.append(f"{cursor_path} has no {name} hook")
        continue
    pre.append({"command": command, "matcher": matcher, "timeout": 10})
    save(cursor_path, cursor)

if problems:
    for p in problems:
        print(f"helmsman: {p}. Run .helmsman/tools/watermark/hooks-install.sh.", file=sys.stderr)
    sys.exit(1)
if mode == "check":
    print("helmsman: hooks are registered.")
PY
