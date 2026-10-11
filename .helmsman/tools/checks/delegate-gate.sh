#!/usr/bin/env bash
# Run the consumer's own check, then stop.
# make check wins when that target exists.
# Otherwise a root package.json "check" script is the same kind of gate.
# Prefer pnpm check when packageManager is pnpm@* or pnpm-lock.yaml exists.
# npm run check is the fallback when there is no pnpm signal and no yarn field or lock.
# yarn run check is an unsupported legacy fallback.
# Exit 0 when make check passes.
# Exit 11 when the package script passes. 11 is success, not a failure.
# Exit 10 when there is nothing to delegate.
# Any other status is the consumer command's status.
# --probe does not run a command. Exit 0 when make check or make lint exists.
# Exit 10 when neither Makefile target exists. The package script is not a probe hit:
# a script named check often omits cargo fmt and clippy, so rust-workspace must still see it.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

probe=0
if [[ "${1:-}" == "--probe" ]]; then
  probe=1
elif [[ -n "${1:-}" ]]; then
  echo "helmsman: unknown argument $1" >&2
  exit 2
fi

found=0
for name in Makefile makefile GNUmakefile; do
  if [[ -f "$name" ]]; then
    found=1
    break
  fi
done

# Prints 0 when the target exists, 10 when it does not, 1 when the Makefile cannot be read.
target_status() {
  local name="$1"
  local dry
  local dry_status
  set +e
  dry="$(make -n --no-print-directory "$name" 2>&1)"
  dry_status=$?
  set -e
  if [[ "$dry_status" -eq 0 ]]; then
    printf '0\n'
    return 0
  fi
  if printf '%s\n' "$dry" | grep -q "No rule to make target"; then
    printf '10\n'
    return 0
  fi
  echo "helmsman: cannot read the Makefile $name target." >&2
  printf '%s\n' "$dry" >&2
  printf '1\n'
}

# Exit 0 when scripts.check is a non-empty string.
package_check_exists() {
  if [[ ! -f package.json ]]; then
    return 1
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    echo "helmsman: package.json exists but python3 is not installed." >&2
    return 2
  fi
  python3 - << 'PY'
import json, sys
from pathlib import Path
manifest = json.loads(Path("package.json").read_text())
script = (manifest.get("scripts") or {}).get("check")
sys.exit(0 if isinstance(script, str) and script.strip() else 1)
PY
}

run_package_check() {
  local manager
  manager="$(python3 - << 'PY'
import json
from pathlib import Path
manifest = json.loads(Path("package.json").read_text())
raw = manifest.get("packageManager") or ""
pnpm_lock = Path("pnpm-lock.yaml").exists()
yarn_lock = Path("yarn.lock").exists()
if raw.startswith("pnpm@") or pnpm_lock:
    print("pnpm")
elif raw.startswith("yarn@") or (yarn_lock and not raw.startswith("npm@")):
    print("yarn")
else:
    print("npm")
PY
)"
  case "$manager" in
    pnpm)
      if ! command -v pnpm >/dev/null 2>&1; then
        echo "helmsman: package.json check exists but pnpm is not installed." >&2
        exit 1
      fi
      echo "helmsman: delegated to pnpm check."
      pnpm check
      ;;
    yarn)
      if ! command -v yarn >/dev/null 2>&1; then
        echo "helmsman: package.json check exists but yarn is not installed." >&2
        exit 1
      fi
      echo "helmsman: delegated to yarn run check."
      yarn run check
      ;;
    npm)
      if ! command -v npm >/dev/null 2>&1; then
        echo "helmsman: package.json check exists but npm is not installed." >&2
        exit 1
      fi
      echo "helmsman: delegated to npm run check."
      npm run check
      ;;
    *)
      echo "helmsman: unknown package manager $manager" >&2
      exit 1
      ;;
  esac
}

if [[ "$found" -eq 1 ]] && ! command -v make >/dev/null 2>&1; then
  echo "helmsman: Makefile exists but make is not installed." >&2
  exit 1
fi

check_status=10
if [[ "$found" -eq 1 ]]; then
  check_status="$(target_status check)"
  if [[ "$check_status" -eq 1 ]]; then
    exit 1
  fi
fi

if [[ "$probe" -eq 1 ]]; then
  if [[ "$check_status" -eq 0 ]]; then
    exit 0
  fi
  if [[ "$found" -eq 0 ]]; then
    exit 10
  fi
  lint_status="$(target_status lint)"
  if [[ "$lint_status" -eq 0 ]]; then
    exit 0
  fi
  if [[ "$lint_status" -eq 1 ]]; then
    exit 1
  fi
  exit 10
fi

if [[ "$check_status" -eq 0 ]]; then
  echo "helmsman: delegated to make check."
  make --no-print-directory check
  exit 0
fi

set +e
package_check_exists
package_status=$?
set -e
if [[ "$package_status" -eq 2 ]]; then
  exit 1
fi
if [[ "$package_status" -eq 0 ]]; then
  run_package_check
  exit 11
fi

if [[ "$found" -eq 0 ]]; then
  echo "helmsman: no Makefile and no package.json check script. Nothing delegated."
else
  echo "helmsman: no Makefile check target and no package.json check script. Nothing delegated."
fi
exit 10
