#!/usr/bin/env bash
# Move an already set-up repo from tools/helmsman to .helmsman/tools.
# Then rename old Helmsman paths and script keys. Both steps are idempotent.
# Idempotent. A second run leaves the tree and the references as they are.
# Run from the target repo root. The script may live outside that repo.
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

old_rel="$(printf '%s/%s' tools helmsman)"
new_rel="$(printf '%s/%s' .helmsman tools)"

if [[ -e "$new_rel" && ! -d "$new_rel" ]]; then
  echo "helmsman: $new_rel exists and is not a directory." >&2
  exit 1
fi

in_git=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  in_git=1
fi

python3 - "$root" "$old_rel" "$new_rel" << 'PY'
import pathlib, sys
root, old_rel, new_rel = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
path = root / ".gitignore"
if not path.is_file():
    sys.exit(0)
text = path.read_text()
ends_nl = text.endswith("\n")
lines = text.splitlines()
drop = {
    old_rel,
    old_rel + "/",
    "/" + old_rel,
    "/" + old_rel + "/",
    new_rel,
    new_rel + "/",
    "/" + new_rel,
    "/" + new_rel + "/",
}
kept = [line for line in lines if line.strip() not in drop]
stripped = [line.strip() for line in kept]
if ".helmsman/*" in stripped:
    for extra in ("!.helmsman/tools/", "!.helmsman/tools/**"):
        if extra not in stripped:
            kept.append(extra)
            stripped.append(extra)
# The last matching pattern wins. A tools exception after node_modules/
# would track a package install under the harness. Repeat that ignore after it.
def last_index(names):
    found = -1
    for index, line in enumerate(stripped):
        if line in names:
            found = index
    return found

tools_at = last_index({"!.helmsman/tools/", "!.helmsman/tools/**"})
modules_at = last_index({"node_modules", "node_modules/"})
if modules_at != -1 and modules_at < tools_at:
    kept.append("node_modules/")
    stripped.append("node_modules/")
updated = "\n".join(kept)
if updated and ends_nl:
    updated += "\n"
if updated != text:
    path.write_text(updated)
PY

if [[ -d "$old_rel" && ! -d "$new_rel" ]]; then
  mkdir -p .helmsman
  moved=0
  if [[ "$in_git" -eq 1 && -n "$(git ls-files -- "$old_rel")" ]]; then
    if git mv "$old_rel" "$new_rel"; then
      moved=1
    fi
  fi
  if [[ "$moved" -eq 0 ]]; then
    mv "$old_rel" "$new_rel"
  fi
elif [[ -d "$old_rel" && -d "$new_rel" ]]; then
  while IFS= read -r -d '' file; do
    rel="${file#"$old_rel"/}"
    dest="$new_rel/$rel"
    if [[ ! -e "$dest" ]]; then
      mkdir -p "$(dirname "$dest")"
      mv "$file" "$dest"
    fi
  done < <(find "$old_rel" -type f -print0)
  rm -rf "$old_rel"
fi

if [[ -d tools ]] && [[ -z "$(find tools -mindepth 1 -print -quit)" ]]; then
  rmdir tools
fi

changed="$(mktemp)"
trap 'rm -f "$changed"' EXIT
python3 - "$root" "$old_rel" "$new_rel" > "$changed" << 'PY'
import os, pathlib, sys
root = pathlib.Path(sys.argv[1])
old_rel, new_rel = sys.argv[2], sys.argv[3]
airbnb_old = old_rel + "/eslint-config-airbnb-base"
airbnb_new = "packages/eslint-config-airbnb-base"
skip_dirs = {".git", "node_modules"}

def skip(rel):
    if rel == ".gitignore":
        return True
    if rel.endswith("/migrate-layout.sh") or rel.endswith("/migrate-layout.bats"):
        return True
    if rel == ".cursor/skills/helmsman-setup/SKILL.md":
        return True
    if rel.startswith(".helmsman/tools/upstream/ponytail/") or rel.startswith(".helmsman/tools/upstream/cursor-plugins/"):
        return True
    if rel.endswith("pnpm-lock.yaml") or rel.endswith(".lock"):
        return True
    return False

for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [name for name in dirnames if name not in skip_dirs]
    for name in filenames:
        path = pathlib.Path(dirpath, name)
        rel = path.relative_to(root).as_posix()
        if skip(rel):
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        if "\0" in text or old_rel not in text:
            continue
        updated = text.replace(airbnb_old, airbnb_new).replace(old_rel, new_rel)
        if updated != text:
            path.write_text(updated, encoding="utf-8")
            sys.stdout.write(rel + "\0")
PY

if [[ "$in_git" -eq 1 ]]; then
  if [[ -f .gitignore ]]; then
    git add -- .gitignore
  fi
  if [[ -s "$changed" ]]; then
    git add --pathspec-from-file="$changed" --pathspec-file-nul
  fi
  if [[ -d "$new_rel" ]]; then
    git add -A -- "$new_rel"
  fi
  if git ls-files --error-unmatch -- tools >/dev/null 2>&1; then
    git add -A -- tools
  fi
fi

"$(cd "$(dirname "$0")" && pwd)/install-review-ready.sh"
"$(cd "$(dirname "$0")" && pwd)/install-root-scripts.sh"
"$(cd "$(dirname "$0")" && pwd)/migrate-names.sh"

echo "helmsman: layout is $new_rel"
