#!/usr/bin/env bash
# Optional tsc gate. Does not install ESLint or Knip.
# A tsc-only app keeps make web-check. This script does not replace that command.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

strict_ts() {
  python3 - "$root" << 'PY'
import json, re, sys
from pathlib import Path

root = Path(sys.argv[1])
skip = {"node_modules", "dist", "build", "target", "coverage", "fixture", "fixtures", "upstream", ".git"}
found = False
problems = []

def walk(directory):
    for path in sorted(directory.iterdir()):
        if path.name in skip or path.name.startswith("."):
            continue
        if path.is_dir():
            yield from walk(path)
        elif path.is_file() and path.name.startswith("tsconfig") and path.suffix == ".json":
            yield path

def parse_tsconfig(text):
    # Comments are stripped in one string-aware pass: "@/*" and "src/**/*.ts" are strings, not a comment.
    out = []
    index = 0
    in_string = False
    escaped = False
    while index < len(text):
        char = text[index]
        if in_string:
            out.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue
        if char == '"':
            in_string = True
            out.append(char)
            index += 1
            continue
        if char == "/" and index + 1 < len(text) and text[index + 1] == "/":
            index = text.find("\n", index)
            if index == -1:
                break
            continue
        if char == "/" and index + 1 < len(text) and text[index + 1] == "*":
            end = text.find("*/", index + 2)
            if end == -1:
                break
            index = end + 2
            continue
        out.append(char)
        index += 1
    cleaned = re.sub(r",(\s*[}\]])", r"\1", "".join(out))
    return json.loads(cleaned)

for path in walk(root):
    found = True
    rel = path.relative_to(root).as_posix()
    try:
        data = parse_tsconfig(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        problems.append(f"{rel} is not valid JSON. {error}")
        continue
    if not isinstance(data, dict):
        problems.append(f"{rel} is not an object.")
        continue
    options = data.get("compilerOptions")
    if "references" in data and not isinstance(options, dict):
        continue
    if data.get("extends") and (not isinstance(options, dict) or "strict" not in options):
        continue
    if not isinstance(options, dict) or options.get("strict") is not True:
        problems.append(f"{rel} does not set compilerOptions.strict to true.")

if problems:
    for problem in problems:
        print(f"helmsman: {problem}", file=sys.stderr)
    sys.exit(1)
if not found:
    print("helmsman: no tsconfig. strict check skipped.")
else:
    print("helmsman: strict tsconfig ok.")
PY
}

if [[ "${1:-}" == "--strict" ]]; then
  strict_ts
  exit 0
fi

strict_ts

if [[ ! -f package.json ]]; then
  echo "helmsman: tsc adapter needs a package.json." >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "helmsman: tsc adapter needs node." >&2
  exit 1
fi

if [[ -d "$root/node_modules/.bin" ]]; then
  PATH="$root/node_modules/.bin:$PATH"
  export PATH
fi

node --input-type=module << 'PY'
import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

const manifest = JSON.parse(readFileSync("package.json", "utf8"));
const script = manifest.scripts && typeof manifest.scripts.typecheck === "string"
  ? manifest.scripts.typecheck.trim()
  : "";

let args;
if (script === "") {
  args = ["tsc", "--noEmit", "--pretty", "false"];
} else if (/^tsc(\s|$)/.test(script)) {
  args = script.split(/\s+/);
} else {
  console.error("helmsman: scripts.typecheck is not a tsc command.");
  process.exit(1);
}

const result = spawnSync(args[0], args.slice(1), { stdio: "inherit" });
if (result.error && result.error.code === "ENOENT") {
  console.error("helmsman: tsc is not installed. This adapter does not install ESLint.");
  process.exit(1);
}
if (result.status === null) {
  process.exit(1);
}
process.exit(result.status);
PY
