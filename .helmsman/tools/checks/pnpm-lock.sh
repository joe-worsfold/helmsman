#!/usr/bin/env bash
# Fail when pnpm/action-setup pins a version other than packageManager.
# A shorter pin disagrees (9 versus 9.15.4). That mismatch deadlocks CI.
# Omit the version input to use packageManager, or pin the same version.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

if [[ ! -f package.json ]]; then
  echo "helmsman: no package.json. pnpm lock check skipped."
  exit 0
fi

if ! grep -q '"packageManager"' package.json; then
  echo "helmsman: no packageManager field. pnpm lock check skipped."
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "helmsman: package.json sets packageManager but python3 is not installed." >&2
  exit 1
fi

python3 - << 'PY'
import json, pathlib, re, sys

pkg = json.loads(pathlib.Path("package.json").read_text())
raw = pkg.get("packageManager") or ""
match = re.match(r"pnpm@(\d+(?:\.\d+)*)", raw)
if not match:
    print("helmsman: packageManager is not pnpm. pnpm lock check skipped.")
    sys.exit(0)
declared = match.group(1).split(".")

def agrees(pinned: str) -> bool:
    pin = pinned.strip()
    if pin.startswith("pnpm@"):
        pin = pin[5:]
    if pin.startswith("v"):
        pin = pin[1:]
    pin = pin.split("+", 1)[0]
    return pin.split(".") == declared

pins = []
root = pathlib.Path(".github/workflows")
files = []
if root.is_dir():
    files = sorted(root.glob("*.yml")) + sorted(root.glob("*.yaml"))

for path in files:
    lines = path.read_text().splitlines()
    index = 0
    while index < len(lines):
        line = lines[index]
        if re.search(r"pnpm/action-setup(?:@|\s|$)", line):
            indent = len(line) - len(line.lstrip(" "))
            index += 1
            while index < len(lines):
                nxt = lines[index]
                if nxt.strip() == "":
                    index += 1
                    continue
                nxt_indent = len(nxt) - len(nxt.lstrip(" "))
                if nxt_indent <= indent:
                    break
                found = re.match(r"\s*version:\s*['\"]?([^'\"#\s]+)", nxt)
                if found:
                    pins.append((str(path), found.group(1)))
                index += 1
            continue
        index += 1

if not pins:
    print("helmsman: no pnpm/action-setup version pin. pnpm lock check ok.")
    sys.exit(0)

clashes = [(path, pin) for path, pin in pins if not agrees(pin)]
if clashes:
    print("helmsman: pnpm/action-setup version disagrees with packageManager pnpm@" + ".".join(declared) + ". That mismatch deadlocks CI.", file=sys.stderr)
    for path, pin in clashes:
        print(f"helmsman: {path} pins {pin}.", file=sys.stderr)
    sys.exit(1)

print("helmsman: pnpm action pin matches packageManager.")
PY
