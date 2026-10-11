#!/usr/bin/env bash
# Fail when a Helmsman-owned JS toolchain pin is not the publisher's latest stable.
# Versions come from the provider during this run: npm dist-tags and the Node release index.
# Do not bake a version number into this script.
# --expect DECLARED LATEST checks the comparison and does not use the network.
set -euo pipefail

if [[ "${1:-}" == "--expect" ]]; then
  if [[ -z "${2:-}" || -z "${3:-}" || -n "${4:-}" ]]; then
    echo "helmsman: usage: toolchain-latest.sh --expect DECLARED LATEST" >&2
    exit 2
  fi
  exec python3 - "$2" "$3" << 'PY'
import re, sys

def classify(text):
    full = re.search(r"(\d+)\.(\d+)\.(\d+)", text)
    if full:
        return ("full", tuple(int(part) for part in full.groups()))
    major = re.search(r"(?:^|[^\d])(\d+)(?:\.x)?(?:$|[^\d])", text)
    if major:
        return ("major", int(major.group(1)))
    return ("none", None)

def matches(declared, latest):
    kind, value = classify(declared)
    latest_kind, latest_value = classify(latest)
    if kind == "none" or latest_kind != "full":
        return False
    if kind == "major":
        return value == latest_value[0]
    return value == latest_value

sys.exit(0 if matches(sys.argv[1], sys.argv[2]) else 1)
PY
fi

if [[ -n "${1:-}" ]]; then
  echo "helmsman: unknown argument $1" >&2
  exit 2
fi

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

if [[ ! -f .helmsman/tools/eslint/package.json ]] || ! grep -q '"@helmsman/eslint"' .helmsman/tools/eslint/package.json; then
  echo "helmsman: toolchain latest check skipped. This tree does not own the Helmsman JS toolchain."
  exit 0
fi

python3 - << 'PY'
import json, pathlib, re, shutil, subprocess, sys, urllib.request

def fetch(url):
    request = urllib.request.Request(url, headers={"Accept": "application/json", "User-Agent": "helmsman-toolchain-latest"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)
    except Exception as error:
        print(f"helmsman: could not read {url}. {error}", file=sys.stderr)
        sys.exit(1)

def classify(text):
    full = re.search(r"(\d+)\.(\d+)\.(\d+)", text)
    if full:
        return ("full", tuple(int(part) for part in full.groups()))
    major = re.search(r"(?:^|[^\d])(\d+)(?:\.x)?(?:$|[^\d])", text)
    if major:
        return ("major", int(major.group(1)))
    return ("none", None)

def matches(declared, latest):
    kind, value = classify(declared)
    latest_kind, latest_value = classify(latest)
    if kind == "none" or latest_kind != "full":
        return False
    if kind == "major":
        return value == latest_value[0]
    return value == latest_value

def version_key(text):
    return tuple(int(part) for part in text.split("."))

def in_range(version, peer):
    value = version_key(version)
    for part in peer.split():
        match = re.match(r"(>=|>|<=|<)?(\d+)\.(\d+)\.(\d+)", part)
        if not match:
            print(f"helmsman: cannot read peer range {peer}.", file=sys.stderr)
            sys.exit(1)
        op, bound = match.group(1) or "=", version_key(".".join(match.group(2, 3, 4)))
        if op == ">=" and not value >= bound:
            return False
        if op == ">" and not value > bound:
            return False
        if op == "<=" and not value <= bound:
            return False
        if op == "<" and not value < bound:
            return False
        if op == "=" and value != bound:
            return False
    return True

def newest_in_range(peer):
    pack = fetch("https://registry.npmjs.org/typescript")
    stable = [name for name in pack["versions"] if "-" not in name and in_range(name, peer)]
    if not stable:
        print(f"helmsman: no stable TypeScript satisfies {peer}.", file=sys.stderr)
        sys.exit(1)
    return max(stable, key=version_key)

node_index = fetch("https://nodejs.org/dist/index.json")
node_stable = []
for row in node_index:
    name = row["version"].lstrip("v")
    if "-" in name:
        continue
    node_stable.append(name)
if not node_stable:
    print("helmsman: the Node release index has no stable version.", file=sys.stderr)
    sys.exit(1)
node_latest = max(node_stable, key=version_key)

typescript_latest = fetch("https://registry.npmjs.org/typescript/latest")["version"]
types_latest = fetch("https://registry.npmjs.org/@types%2Fnode/latest")["version"]
pnpm_latest = fetch("https://registry.npmjs.org/pnpm/latest-12")["version"]
if not pnpm_latest.startswith("12.") or "-" in pnpm_latest:
    print(f"helmsman: pnpm latest-12 is {pnpm_latest}, not a stable 12.x release.", file=sys.stderr)
    sys.exit(1)

problems = []

def expect(label, declared, latest):
    if matches(str(declared), str(latest)):
        print(f"helmsman: {label} matches publisher latest stable {latest}.")
        return
    problems.append(f"{label} is {declared}, publisher latest stable is {latest}.")

def typescript_expected(manifest):
    deps = {}
    for field in ("dependencies", "devDependencies", "peerDependencies"):
        deps.update(manifest.get(field) or {})
    spec = deps.get("typescript-eslint")
    if not spec or spec.startswith("^") or spec.startswith("~") or " " in spec or spec.startswith(">") or spec.startswith("<"):
        return typescript_latest
    peer = (fetch(f"https://registry.npmjs.org/typescript-eslint/{spec}").get("peerDependencies") or {}).get("typescript")
    if not peer or in_range(typescript_latest, peer):
        return typescript_latest
    capped = newest_in_range(peer)
    print(f"helmsman: typescript-eslint@{spec} allows TypeScript {peer}. Newest stable in that range is {capped}.")
    return capped

def read_manifest(path):
    return json.loads(pathlib.Path(path).read_text())

manifests = [("root package.json", pathlib.Path("package.json"))]
for path in sorted(pathlib.Path(".helmsman/tools").glob("*/package.json")):
    manifests.append((str(path), path))

for label, path in manifests:
    if not path.is_file():
        continue
    manifest = read_manifest(path)
    manager = manifest.get("packageManager") or ""
    if manager.startswith("pnpm@"):
        expect(f"{label} packageManager", manager, pnpm_latest)
    engines = (manifest.get("engines") or {}).get("node")
    if engines:
        expect(f"{label} engines.node", engines, node_latest)
    dev = manifest.get("devDependencies") or {}
    if "typescript" in dev:
        expect(f"{label} devDependencies.typescript", dev["typescript"], typescript_expected(manifest))
    if "@types/node" in dev:
        expect(f"{label} devDependencies.@types/node", dev["@types/node"], types_latest)

nvmrc = pathlib.Path(".nvmrc")
if nvmrc.is_file():
    expect(".nvmrc", nvmrc.read_text().strip(), node_latest)

workflow_dir = pathlib.Path(".github/workflows")
if workflow_dir.is_dir():
    for path in sorted(workflow_dir.glob("*.yml")) + sorted(workflow_dir.glob("*.yaml")):
        for line in path.read_text().splitlines():
            if "node-version-file:" in line:
                continue
            found = re.search(r"node-version:\s*['\"]?([^'\"#\s]+)", line)
            if found:
                expect(f"{path} node-version", found.group(1), node_latest)

devcontainer = pathlib.Path(".devcontainer/devcontainer.json")
if devcontainer.is_file():
    image = json.loads(devcontainer.read_text()).get("image") or ""
    if image:
        expect(f"{devcontainer} image", image, node_latest)

def installed_version(path):
    file = pathlib.Path(path)
    if not file.is_file():
        return None
    return json.loads(file.read_text()).get("version")

root_typescript = installed_version("node_modules/typescript/package.json")
if root_typescript:
    expect("installed root typescript", root_typescript, typescript_latest)
eslint_typescript = installed_version(".helmsman/tools/eslint/node_modules/typescript/package.json")
if eslint_typescript:
    expect("installed .helmsman/tools/eslint typescript", eslint_typescript, typescript_expected(read_manifest(pathlib.Path(".helmsman/tools/eslint/package.json"))))

if shutil.which("pnpm"):
    version = subprocess.check_output(["pnpm", "-v"], text=True).strip()
    expect("installed pnpm", version, pnpm_latest)
else:
    problems.append("pnpm is not installed.")

if shutil.which("node"):
    version = subprocess.check_output(["node", "-v"], text=True).strip().lstrip("v")
    expect("installed node", version, node_latest)
else:
    problems.append("node is not installed.")

if problems:
    for problem in problems:
        print(f"helmsman: {problem}", file=sys.stderr)
    sys.exit(1)

print("helmsman: JS toolchain matches the publisher latest stable.")
PY
