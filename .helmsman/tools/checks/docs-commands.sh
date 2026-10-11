#!/usr/bin/env bash
# Fail when a documented command is missing, or a stated runtime version
# disagrees with .nvmrc, engines, or rust-toolchain.toml.
# Fenced bash blocks are what a newcomer copies. Prose is not a command.
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
import json, re, sys
from pathlib import Path

root = Path(sys.argv[1])
problems = []

docs = []
for name in ("README.md", "AGENTS.md", "CONTRIBUTING.md", "eval/README.md"):
    path = root / name
    if path.is_file():
        docs.append(path)
docs_dir = root / "docs"
if docs_dir.is_dir():
    docs.extend(sorted(path for path in docs_dir.glob("*.md") if path.is_file()))

def read_pin(path):
    if not path.is_file():
        return ""
    text = path.read_text(encoding="utf-8").strip().lstrip("vV")
    return text.split()[0] if text else ""

nvmrc = read_pin(root / ".nvmrc")
engines = ""
scripts = None
pkg_path = root / "package.json"
if pkg_path.is_file():
    try:
        manifest = json.loads(pkg_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        problems.append(f"package.json is not valid JSON. {error}")
        manifest = {}
    node = manifest.get("engines", {}).get("node", "")
    if isinstance(node, str):
        engines = node
    raw_scripts = manifest.get("scripts", {})
    scripts = raw_scripts if isinstance(raw_scripts, dict) else {}

def parts(text):
    return tuple(int(item) for item in text.split("."))

def agrees(stated, pinned):
    got = parts(stated)
    want = parts(pinned)
    return want[: len(got)] == got

def first_version(text):
    match = re.search(r"\d+(?:\.\d+){0,2}", text)
    return match.group(0) if match else ""

engine_token = first_version(engines)
if nvmrc and engine_token and not agrees(engine_token, nvmrc):
    problems.append(f"engines node is {engines}. .nvmrc is {nvmrc}.")

pin = nvmrc or engine_token

rust_channel = ""
toolchain = root / "rust-toolchain.toml"
if toolchain.is_file():
    match = re.search(r'channel\s*=\s*"([^"]+)"', toolchain.read_text(encoding="utf-8"))
    if match:
        rust_channel = match.group(1)

node_re = re.compile(r"\bnode(?:\.js)?\s+v?(\d+(?:\.\d+){0,2})\b", re.IGNORECASE)
rust_re = re.compile(r"\brust\s+v?(\d+(?:\.\d+){0,2})\b", re.IGNORECASE)
fence_re = re.compile(r"```(?:bash|sh)\n(.*?)```", re.DOTALL)

builtins = {
    "install", "i", "add", "update", "up", "remove", "rm", "un", "unlink",
    "link", "ln", "import", "rebuild", "rb", "prune", "fetch", "dedupe",
    "list", "ls", "outdated", "why", "exec", "dlx", "create", "init",
    "publish", "pack", "config", "store", "root", "bin", "setup", "doctor",
    "approve-builds", "licenses", "audit", "deploy", "patch", "patch-commit",
    "pkg", "run",
}

def make_targets():
    makefile = root / "Makefile"
    if not makefile.is_file():
        return None
    found = set()
    for line in makefile.read_text(encoding="utf-8", errors="replace").splitlines():
        if not line or line[0] in " \t#":
            continue
        match = re.match(r"^([^:#]+):", line)
        if match:
            for name in match.group(1).split():
                found.add(name)
    return found

def positional(tokens):
    found = []
    index = 0
    while index < len(tokens):
        token = tokens[index]
        if token == "-C" and index + 1 < len(tokens):
            index += 2
            continue
        if token.startswith("-"):
            index += 1
            continue
        found.append(token)
        index += 1
    return found

def pnpm_command(tokens):
    args = tokens[1:]
    while args and args[0].startswith("-"):
        flag = args.pop(0)
        if flag in {"--dir", "--filter", "-C", "--workspace-root"} and args:
            args.pop(0)
    if not args:
        return None
    if args[0] == "run":
        args = args[1:]
        while args and args[0].startswith("-"):
            args.pop(0)
        if not args:
            return None
    return args[0]

def check_command(rel, part):
    if "<" in part:
        return
    tokens = part.split()
    if not tokens:
        return
    cmd = tokens[0]
    if cmd == "pnpm":
        name = pnpm_command(tokens)
        if name is None or name in builtins:
            return
        if scripts is None:
            problems.append(f"{rel} runs pnpm {name} and there is no package.json.")
        elif name not in scripts:
            problems.append(f"{rel} runs pnpm {name} and package.json has no {name} script.")
        return
    if cmd == "make":
        targets = make_targets()
        wanted = positional(tokens[1:])
        if targets is None:
            problems.append(f"{rel} runs make and there is no Makefile.")
            return
        if wanted and wanted[0] not in targets:
            problems.append(f"{rel} runs make {wanted[0]} and that target is missing.")
        return
    if cmd == "cargo":
        has_cargo = (root / "Cargo.toml").is_file() or any(root.glob("packages/*/rs/Cargo.toml")) or any(root.glob("apps/*/Cargo.toml"))
        if not has_cargo:
            problems.append(f"{rel} runs cargo and there is no Cargo.toml.")
        return
    if cmd == "uv":
        if not (root / "pyproject.toml").is_file() and not (root / "uv.lock").is_file():
            problems.append(f"{rel} runs uv and there is no pyproject.toml or uv.lock.")
        return
    if cmd.startswith("./"):
        rel_path = cmd[2:].split()[0]
        if not (root / rel_path).is_file():
            problems.append(f"{rel} documents {cmd} and that file is missing.")

for doc in docs:
    text = doc.read_text(encoding="utf-8", errors="replace")
    rel = doc.relative_to(root).as_posix()
    if pin:
        for match in node_re.finditer(text):
            if not agrees(match.group(1), pin):
                problems.append(f"{rel} says Node {match.group(1)}. The pin is {pin}.")
    if re.fullmatch(r"\d+(?:\.\d+)*", rust_channel):
        for match in rust_re.finditer(text):
            if not agrees(match.group(1), rust_channel):
                problems.append(f"{rel} says Rust {match.group(1)}. rust-toolchain.toml is {rust_channel}.")
    for block in fence_re.findall(text):
        buf = ""
        lines = []
        for raw in block.splitlines():
            stripped = raw.strip()
            if not buf and (not stripped or stripped.startswith("#")):
                continue
            buf = f"{buf} {stripped}".strip() if buf else stripped
            if buf.endswith("\\"):
                buf = buf[:-1].rstrip()
                continue
            if buf:
                lines.append(buf)
            buf = ""
        for line in lines:
            for part in re.split(r"\s*(?:&&|\|\||;)\s*", line):
                check_command(rel, part.strip())

if problems:
    print("helmsman: documented commands do not match the tree.", file=sys.stderr)
    for problem in problems:
        print(f"helmsman: {problem}", file=sys.stderr)
    sys.exit(1)
print("helmsman: docs commands ok.")
PY
