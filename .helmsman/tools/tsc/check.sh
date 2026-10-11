#!/usr/bin/env bash
# Optional tsc gate. Does not install ESLint or Knip.
# A tsc-only app keeps make web-check. This script does not replace that command.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

strict_ts() {
  python3 - "$root" << 'PY'
import json, sys
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

for path in walk(root):
    found = True
    rel = path.relative_to(root).as_posix()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        problems.append(f"{rel} is not valid JSON. {error}")
        continue
    options = data.get("compilerOptions") if isinstance(data, dict) else None
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
