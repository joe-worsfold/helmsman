#!/usr/bin/env bash
# Fail when an added line brings a nautical term back.
# Allowed tokens: Helmsman and .helmsman. docs/renames.md is the history of the old names.
# The mapping scripts name those old names, so they are not scanned.
# Added lines only. Same range flags as diff-guard.sh.
set -euo pipefail

range=""
diff_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --range)
      range="${2:-}"
      shift 2
      ;;
    --diff)
      diff_file="${2:-}"
      shift 2
      ;;
    *)
      echo "helmsman: unknown argument $1" >&2
      exit 2
      ;;
  esac
done

paths=(
  .
  ':(exclude)docs/renames.md'
  ':(exclude).helmsman/tools/checks/plain-language.sh'
  ':(exclude).helmsman/tools/checks/migrate-names.sh'
  ':(exclude).helmsman/tools/checks/migrate-names.bats'
  ':(exclude).helmsman/tools/upstream'
)

if [[ -n "$diff_file" ]]; then
  diff_text="$(cat "$diff_file")"
elif [[ -n "$range" ]]; then
  diff_text="$(git diff --unified=0 "$range" -- "${paths[@]}")"
elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  diff_text="$(git diff --cached --unified=0 -- "${paths[@]}")"
  if [[ -z "$diff_text" ]]; then
    diff_text="$(git diff --unified=0 -- "${paths[@]}")"
  fi
else
  echo "helmsman: no diff to check." >&2
  exit 2
fi

if [[ -z "$diff_text" ]]; then
  echo "helmsman: plain language ok."
  exit 0
fi

printf '%s\n' "$diff_text" | python3 -c "$(cat << 'PY'
import re, sys

skip_prefixes = (
    "docs/renames.md",
    ".helmsman/tools/checks/plain-language.sh",
    ".helmsman/tools/checks/migrate-names.sh",
    ".helmsman/tools/checks/migrate-names.bats",
    ".helmsman/tools/upstream/",
)

words = (
    "helmsmans", "bilge", "caulking", "caulk", "rigging", "nightwatch",
    "beached", "keel", "reef", "gale", "lookout", "bearings", "mast",
    "bail", "wake", "hull", "oakum", "shipwright", "aboard", "waterline",
    "rig", "sail", "knot", "helm",
)
phrases = ("crows-nest", "crow's nest", "crows nest", "self-keel", "north star")
pattern = re.compile(
    r"\b(?:" + "|".join(words) + r")\b|" + "|".join(re.escape(item) for item in phrases),
    re.IGNORECASE,
)
allow_dot = re.compile(r"\.helmsman\b", re.IGNORECASE)
allow_name = re.compile(r"\bhelmsman\b", re.IGNORECASE)

def skipped(path):
    name = path[2:] if path.startswith("b/") or path.startswith("a/") else path
    if name.startswith("/"):
        return False
    return name == "docs/renames.md" or name.startswith(skip_prefixes) or name in skip_prefixes

file = ""
skip = False
hits = []
for raw in sys.stdin:
    line = raw.rstrip("\n")
    if line.startswith("diff --git "):
        parts = line.split(" b/", 1)
        file = parts[1] if len(parts) == 2 else ""
        skip = skipped(file)
        continue
    if line.startswith("+++ "):
        file = line[4:]
        if file.startswith("b/"):
            file = file[2:]
        skip = file == "/dev/null" or skipped(file)
        continue
    if skip or not line.startswith("+") or line.startswith("+++"):
        continue
    added = line[1:]
    cleaned = allow_name.sub("", allow_dot.sub("", added))
    if pattern.search(cleaned):
        hits.append(f"{file}:{added}")

if hits:
    print("helmsman: added lines use a nautical term:", file=sys.stderr)
    print("\n".join(hits), file=sys.stderr)
    raise SystemExit(1)
print("helmsman: plain language ok.")
PY
)"
