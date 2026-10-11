#!/usr/bin/env bash
# When product code reads an environment name, .env.example lists it.
# A value that matches the secret scan fails. Tests and fixtures are not product code.
# No reads: this check does not apply.
set -euo pipefail

root="${1:-}"
if [[ -z "$root" ]]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    root="$(git rev-parse --show-toplevel)"
  else
    root="$(pwd)"
  fi
fi
cd "$root"

python3 - "$root" << 'PY'
import os, re, sys
from pathlib import Path

root = Path(sys.argv[1])
skip_dirs = {
    "node_modules", "dist", "build", "target", "coverage", "fixture", "fixtures",
    "upstream", ".git",
}
skip_parents = {"test", "tests", "__tests__", "e2e"}
extensions = {".js", ".jsx", ".mjs", ".cjs", ".ts", ".tsx", ".mts", ".cts", ".py", ".rs"}
patterns = [
    re.compile(r"process\.env\.([A-Za-z_][A-Za-z0-9_]*)"),
    re.compile(r"process\.env\[\s*['\"]([A-Za-z_][A-Za-z0-9_]*)['\"]\s*\]"),
    re.compile(r"import\.meta\.env\.([A-Za-z_][A-Za-z0-9_]*)"),
    re.compile(r"import\.meta\.env\[\s*['\"]([A-Za-z_][A-Za-z0-9_]*)['\"]\s*\]"),
    re.compile(r"std::env::var(?:_os)?\(\s*\"([A-Za-z_][A-Za-z0-9_]*)\""),
    re.compile(r"os\.environ\[\s*['\"]([A-Za-z_][A-Za-z0-9_]*)['\"]\s*\]"),
    re.compile(r"os\.environ\.get\(\s*['\"]([A-Za-z_][A-Za-z0-9_]*)['\"]"),
    re.compile(r"os\.getenv\(\s*['\"]([A-Za-z_][A-Za-z0-9_]*)['\"]"),
    re.compile(r"\bgetenv\(\s*\"([A-Za-z_][A-Za-z0-9_]*)\""),
]
# Same shapes as .helmsman/tools/secrets/check.sh.
secret = re.compile(
    r"AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|ghp_[A-Za-z0-9]{20,}|"
    r"github_pat_[A-Za-z0-9_]{20,}|sk_live_[0-9A-Za-z]{10,}|xox[baprs]-[0-9A-Za-z-]{10,}"
)

def skipped(path):
    parts = path.parts
    if any(part in skip_dirs for part in parts):
        return True
    if "eval" in parts and "scenarios" in parts:
        return True
    name = path.name
    if ".test." in name or ".spec." in name or name.endswith("_test.py") or name.startswith("test_"):
        return True
    if any(part in skip_parents for part in parts[:-1]):
        return True
    return False

# Vite and the shell set these. They are not names a developer lists.
builtin_env = {"CI", "NODE_ENV", "MODE", "DEV", "PROD", "SSR", "BASE_URL"}
names = set()

def files():
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [name for name in dirnames if name not in skip_dirs and not name.startswith(".")]
        for filename in filenames:
            yield Path(dirpath) / filename

for path in files():
    if path.suffix not in extensions or skipped(path.relative_to(root)):
        continue
    text = path.read_text(encoding="utf-8", errors="replace")
    for pattern in patterns:
        names.update(pattern.findall(text))

names -= builtin_env

if not names:
    print("helmsman: env example ok (no env reads).")
    sys.exit(0)

example = root / ".env.example"
if not example.is_file():
    print(
        "helmsman: .env.example is missing "
        + ", ".join(sorted(names))
        + ".",
        file=sys.stderr,
    )
    sys.exit(1)

keys = set()
bad_values = []
for line in example.read_text(encoding="utf-8", errors="replace").splitlines():
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        continue
    match = re.match(r"^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$", stripped)
    if not match:
        continue
    keys.add(match.group(1))
    value = match.group(2).strip().strip("'\"")
    if value and secret.search(value):
        bad_values.append(match.group(1))

missing = sorted(names - keys)
if missing or bad_values:
    if missing:
        print("helmsman: .env.example is missing " + ", ".join(missing) + ".", file=sys.stderr)
    for key in bad_values:
        print(f"helmsman: .env.example {key} looks like a secret.", file=sys.stderr)
    sys.exit(1)
print("helmsman: env example ok.")
PY
