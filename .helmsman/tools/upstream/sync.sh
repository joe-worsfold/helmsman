#!/usr/bin/env bash
# Fetch one pinned upstream at a new ref, rewrite its snapshot and the lock, and print the diff.
# Does not edit Helmsman skills. A person or helmsman-upstream runs it.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "helmsman: usage: sync.sh <name> <ref>" >&2
  exit 2
fi

name="$1"
ref="$2"
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

python3 - "$root" "$name" "$ref" << 'PY'
import hashlib, json, shutil, sys, tempfile, urllib.request
from pathlib import Path

root = Path(sys.argv[1])
name = sys.argv[2]
ref = sys.argv[3]
lock_path = root / ".helmsman/tools/upstream/upstream.json"
if not lock_path.is_file():
    print("helmsman: no upstream pin to sync.", file=sys.stderr)
    sys.exit(1)

lock = json.loads(lock_path.read_text())
entry = next((row for row in lock.get("entries") or [] if row.get("name") == name), None)
if entry is None:
    print(f"helmsman: no upstream entry named {name}.", file=sys.stderr)
    sys.exit(1)

repo = entry["repo"]

def fetch_json(url):
    request = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json", "User-Agent": "helmsman-upstream"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)

def fetch_bytes(url):
    request = urllib.request.Request(url, headers={"User-Agent": "helmsman-upstream"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()

commit = fetch_json(f"https://api.github.com/repos/{repo}/commits/{ref}")
sha = commit["sha"]
date = commit["commit"]["committer"]["date"][:10]
base = root / ".helmsman/tools/upstream" / name
old = Path(tempfile.mkdtemp(prefix="helmsman-upstream-"))
if base.is_dir():
    shutil.copytree(base, old / "old", dirs_exist_ok=True)
else:
    (old / "old").mkdir()
new = old / "new"
new.mkdir()

files = []
for row in entry.get("files") or []:
    rel = row["path"]
    url = f"https://raw.githubusercontent.com/{repo}/{sha}/{rel}"
    data = fetch_bytes(url)
    dest = new / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    files.append({"path": rel, "sha256": hashlib.sha256(data).hexdigest()})

# Show the snapshot diff before replacing it.
import subprocess
diff = subprocess.run(["diff", "-ru", str(old / "old"), str(new)], capture_output=True, text=True)
sys.stdout.write(diff.stdout)
if diff.returncode > 1:
    print(diff.stderr, file=sys.stderr)
    sys.exit(diff.returncode)

if base.exists():
    shutil.rmtree(base)
shutil.copytree(new, base)
entry["ref"] = ref
entry["commit"] = sha
entry["date"] = date
entry["files"] = files
lock_path.write_text(json.dumps(lock, indent=2) + "\n")
print(f"helmsman: {name} pinned at {sha} ({date}). Lock rewritten. Skills were not edited.")
PY
