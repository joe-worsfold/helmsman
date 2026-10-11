#!/usr/bin/env bash
# Give each Rust crate directory a package.json Turbo can run.
# packages/*/rs includes the shared kernel at packages/platform/rs.
# --check fails when a crate has no lint, format, and test scripts,
# and when a root platform/ crate is still present.
set -euo pipefail

check=0
if [[ "${1:-}" == "--check" ]]; then
  check=1
elif [[ -n "${1:-}" ]]; then
  echo "helmsman: ensure-rust-tasks.sh [--check]" >&2
  exit 2
fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

if [[ -f platform/Cargo.toml || -f platform/package.json ]]; then
  echo "helmsman: the shared kernel is packages/platform/rs, not a root platform/." >&2
  exit 1
fi

shopt -s nullglob
manifests=(packages/*/rs/Cargo.toml apps/*/Cargo.toml)
shopt -u nullglob

if [[ ${#manifests[@]} -eq 0 ]]; then
  echo "helmsman: no Rust package directories."
  exit 0
fi

fail=0
for manifest in "${manifests[@]}"; do
  dir="$(dirname "$manifest")"
  pkg="$dir/package.json"
  rel="$(python3 -c 'import os, sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' ".helmsman/tools/checks/cargo-package.sh" "$dir")"
  if [[ ! -f "$pkg" ]]; then
    if [[ "$check" -eq 1 ]]; then
      echo "helmsman: $dir has no package.json. Turbo cannot run this crate." >&2
      fail=1
      continue
    fi
  fi
  set +e
  python3 - "$pkg" "$dir" "$rel" "$check" "$manifest" << 'PY'
import json, pathlib, sys
path, directory, script, check, manifest = sys.argv[1:]
check = check == "1"
wanted = {
    "lint": f"bash {script} lint",
    "format": f"bash {script} format",
    "test": f"bash {script} test",
}
file = pathlib.Path(path)
data = {}
if file.is_file():
    data = json.loads(file.read_text())
scripts = data.get("scripts")
if not isinstance(scripts, dict):
    scripts = {}
missing = [name for name in wanted if name not in scripts]
if check:
    if missing:
        sys.stderr.write(
            f"helmsman: {directory} package.json is missing scripts: {', '.join(missing)}.\n"
        )
        sys.exit(1)
    sys.exit(0)
if not missing and file.is_file():
    sys.exit(0)
if "name" not in data:
    crate = directory.split("/")[-1]
    text = pathlib.Path(manifest).read_text()
    section = ""
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            section = stripped
            continue
        if section == "[package]" and stripped.startswith("name"):
            value = stripped.split("=", 1)[1].strip().strip('"').strip("'")
            if value:
                crate = value
            break
    data["name"] = crate
data["private"] = True
scripts.update({name: wanted[name] for name in missing})
data["scripts"] = scripts
file.write_text(json.dumps(data, indent=2) + "\n")
print(f"helmsman: wrote {path}")
PY
  status=$?
  set -e
  if [[ "$status" -ne 0 ]]; then
    fail=1
  fi
done

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "helmsman: rust turbo tasks ok."
