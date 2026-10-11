#!/usr/bin/env bash
# Optional tsc gate. Does not install ESLint or Knip.
# A tsc-only app keeps make web-check. This script does not replace that command.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

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
