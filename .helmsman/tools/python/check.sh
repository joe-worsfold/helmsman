#!/usr/bin/env bash
# Python gate for a uv project: lock, ruff, ty, pytest.
# Shaped from a data-science repo that uses those four tools and Postgres beside them.
# Does not start a database. A project ruff config is not replaced.
# A number above this package's floor fails. A lower number stays.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

here="$(cd "$(dirname "$0")" && pwd)"
floor="$here/ruff.toml"

if [[ ! -f pyproject.toml && ! -f uv.lock ]]; then
  echo "helmsman: no pyproject.toml or uv.lock. Python gate skipped."
  exit 0
fi

if [[ ! -f "$floor" ]]; then
  echo "helmsman: missing $floor" >&2
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "helmsman: pyproject.toml or uv.lock exists but uv is not installed." >&2
  exit 1
fi

python3 - << 'PY'
import re, sys
from pathlib import Path

def section(text, header):
    lines = []
    grab = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("["):
            grab = stripped == header or stripped.startswith(header + ".")
            continue
        if grab:
            lines.append(line)
    return "\n".join(lines)

def has_header(text, header):
    return any(line.strip() == header or line.strip().startswith(header + ".") for line in text.splitlines())

def is_strict(body):
    if re.search(r"(?m)^\s*strict\s*=\s*true\b", body):
        return True
    return re.search(r'(?m)^\s*typeCheckingMode\s*=\s*"strict"', body) is not None

problems = []
watched = False
pyproject = Path("pyproject.toml")
if pyproject.is_file():
    text = pyproject.read_text(encoding="utf-8")
    for label, header in (("mypy", "[tool.mypy]"), ("pyright", "[tool.pyright]")):
        if has_header(text, header):
            watched = True
            if not is_strict(section(text, header)):
                problems.append(f"{label} is not strict.")

mypy_ini = Path("mypy.ini")
if mypy_ini.is_file():
    ini = mypy_ini.read_text(encoding="utf-8")
    if has_header(ini, "[mypy]"):
        watched = True
        if not is_strict(section(ini, "[mypy]")):
            problems.append("mypy.ini is not strict.")

pyright_json = Path("pyrightconfig.json")
if pyright_json.is_file():
    watched = True
    raw = pyright_json.read_text(encoding="utf-8")
    if '"strict": true' not in raw and '"typeCheckingMode": "strict"' not in raw:
        problems.append("pyrightconfig.json is not strict.")

if problems:
    for problem in problems:
        print(f"helmsman: {problem}", file=sys.stderr)
    sys.exit(1)
if watched:
    print("helmsman: python strict ok.")
PY

python3 - "$floor" pyproject.toml ruff.toml .ruff.toml << 'PY'
import re, sys
from pathlib import Path

ceilings = {
    "max-complexity": 10,
    "max-args": 6,
    "max-statements": 50,
}

def values(path: Path):
    if not path.is_file():
        return {}
    found = {}
    for line in path.read_text().splitlines():
        for key, ceiling in ceilings.items():
            match = re.match(rf"^\s*{re.escape(key)}\s*=\s*(\d+)\s*(?:#.*)?$", line)
            if match:
                found[key] = int(match.group(1))
    return found

floor = Path(sys.argv[1])
for key, value in values(floor).items():
    if value > ceilings[key]:
        sys.stderr.write(f"helmsman: package {key} is {value}. Floor is {ceilings[key]}.\n")
        sys.exit(1)

for name in sys.argv[2:]:
    path = Path(name)
    for key, value in values(path).items():
        if value > ceilings[key]:
            sys.stderr.write(
                f"helmsman: {path} sets {key} to {value}. Floor is {ceilings[key]}. A lower number stays.\n"
            )
            sys.exit(1)
PY

mode="${1:-all}"
case "$mode" in
  all|lint|ruff|ceilings|typecheck|test) ;;
  *)
    echo "helmsman: python check mode must be all, lint, ruff, ceilings, typecheck, or test." >&2
    exit 2
    ;;
esac

run_ceilings=0
run_ruff=0
run_ty=0
run_pytest=0
case "$mode" in
  all)
    run_ceilings=1
    run_ruff=1
    run_ty=1
    run_pytest=1
    ;;
  lint)
    run_ceilings=1
    run_ruff=1
    ;;
  ceilings) run_ceilings=1 ;;
  ruff) run_ruff=1 ;;
  typecheck) run_ty=1 ;;
  test) run_pytest=1 ;;
esac

if [[ "$run_ceilings" -eq 1 && -f uv.lock ]]; then
  uv lock --check
  echo "helmsman: uv lock ok."
fi

if [[ "$run_ruff" -eq 0 && "$run_ty" -eq 0 && "$run_pytest" -eq 0 ]]; then
  exit 0
fi

project_ruff=0
if [[ -f ruff.toml || -f .ruff.toml ]]; then
  project_ruff=1
elif [[ -f pyproject.toml ]] && grep -q '^\[tool\.ruff' pyproject.toml; then
  project_ruff=1
fi

if [[ "$run_ruff" -eq 1 ]]; then
  if [[ "$project_ruff" -eq 1 ]]; then
    uv run ruff check .
    uv run ruff format --check .
  else
    uv run ruff check --config "$floor" .
    uv run ruff format --config "$floor" --check .
  fi
  echo "helmsman: ruff ok."
fi

names_ty=0
if [[ -f pyproject.toml ]] && grep -Eq '(^|[^A-Za-z0-9_-])ty([^A-Za-z0-9_-]|$)' pyproject.toml; then
  names_ty=1
fi
if [[ -f uv.lock ]] && grep -Eq '^name = "ty"$' uv.lock; then
  names_ty=1
fi
if [[ "$run_ty" -eq 1 ]]; then
  if [[ "$names_ty" -eq 1 ]]; then
    uv run ty check
    echo "helmsman: ty ok."
  else
    echo "helmsman: ty is not a project dependency. ty skipped."
  fi
fi

if [[ "$run_pytest" -eq 1 ]]; then
  list="$(cd "$(dirname "$0")/../checks" && pwd)/tracked.sh"
  tests=""
  if [[ -f "$list" ]]; then
    tests="$("$list" '(^|/)(tests?/|test_.+\.py|.+_test\.py)')"
  fi
  if [[ -n "$tests" ]]; then
    uv run pytest
    echo "helmsman: pytest ok."
  else
    echo "helmsman: no Python tests. pytest skipped."
  fi
fi
